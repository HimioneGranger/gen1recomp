#!/usr/bin/env python3
"""One startup-only dashboard dismissal via Steam's existing local UI bridge.

Compatibility reference: FramePort agent/frameport_agent.py at
459c62ba2deb3164b9ab4838132f5a24841486d5 (steam_js/dashboard_worker).
Independent implementation; no FramePort code or service is bundled.
Never enables debugging, changes Steam preferences or injects controller input.
"""
import argparse
import base64
import hashlib
import json
import os
import re
from pathlib import Path
import socket
import struct
import time
import urllib.parse
import urllib.request

LIMIT=1024*1024
VISIBLE='SteamClient.OpenVR.VROverlay.IsDashboardVisible()'
HIDE='SteamClient.OpenVR.VROverlay.HideDashboard()'

def evaluate(expression, timeout=0.5):
    # Use only the already-running loopback Steam CEF endpoint. Ignore proxies.
    opener=urllib.request.build_opener(urllib.request.ProxyHandler({}))
    with opener.open('http://127.0.0.1:8080/json',timeout=timeout) as response:
        data=response.read(LIMIT+1)
    if len(data)>LIMIT: raise ValueError('oversized target list')
    targets=json.loads(data)
    matches=[t for t in targets if t.get('title')=='SharedJSContext']
    if len(matches)!=1: raise ValueError('Steam UI context unavailable')
    url=urllib.parse.urlparse(matches[0]['webSocketDebuggerUrl'])
    if (url.scheme,url.hostname,url.port)!=('ws','127.0.0.1',8080) or url.query or url.fragment or url.username:
        raise ValueError('non-local UI target refused')
    if not re.fullmatch(r'/devtools/page/[A-Za-z0-9_-]+',url.path): raise ValueError('unexpected UI target')
    end=time.monotonic()+timeout
    with socket.create_connection(('127.0.0.1',8080),timeout=timeout) as sock:
        def exact(n):
            if n>LIMIT: raise ValueError('oversized UI frame')
            result=bytearray()
            while len(result)<n:
                remaining=end-time.monotonic()
                if remaining<=0: raise TimeoutError('UI timeout')
                sock.settimeout(remaining)
                part=sock.recv(n-len(result))
                if not part: raise ValueError('UI connection closed')
                result.extend(part)
            return bytes(result)
        def send(opcode,payload):
            mask=os.urandom(4)
            length=len(payload)
            size=bytes([0x80|length]) if length<126 else b'\xfe'+struct.pack('!H',length)
            sock.sendall(bytes([0x80|opcode])+size+mask+bytes(b^mask[i%4] for i,b in enumerate(payload)))
        key=base64.b64encode(os.urandom(16)).decode('ascii')
        request=('GET '+url.path+' HTTP/1.1\r\nHost: 127.0.0.1:8080\r\nUpgrade: websocket\r\n'
                 'Connection: Upgrade\r\nSec-WebSocket-Version: 13\r\nSec-WebSocket-Key: '+key+'\r\n\r\n')
        sock.sendall(request.encode('ascii'))
        header=bytearray()
        while not header.endswith(b'\r\n\r\n'):
            header.extend(exact(1))
            if len(header)>16384: raise ValueError('oversized UI handshake')
        rows=header.decode('ascii').split('\r\n')
        fields={line.split(':',1)[0].lower():line.split(':',1)[1].strip() for line in rows[1:] if ':' in line}
        accept=base64.b64encode(hashlib.sha1((key+'258EAFA5-E914-47DA-95CA-C5AB0DC85B11').encode()).digest()).decode()
        if ' 101 ' not in rows[0] or fields.get('sec-websocket-accept','')!=accept:
            raise ValueError('UI handshake rejected')
        payload=json.dumps({'id':1,'method':'Runtime.evaluate','params':{
            'expression':expression,'awaitPromise':True,'returnByValue':True}}).encode()
        send(1,payload)
        message=bytearray()
        while True:
            a,b=exact(2)
            opcode=a&15
            if b&128: raise ValueError('masked server frame refused')
            length=b&127
            if length==126: length=struct.unpack('!H',exact(2))[0]
            elif length==127: length=struct.unpack('!Q',exact(8))[0]
            part=exact(length)
            if opcode==8: raise ValueError('UI closed')
            if opcode==9: send(10,part); continue
            if opcode==10: continue
            if opcode not in (0,1): raise ValueError('unexpected UI frame')
            message.extend(part)
            if len(message)>LIMIT: raise ValueError('oversized UI message')
            if not a&128: continue
            reply=json.loads(message); message.clear()
            if reply.get('id')!=1: continue
            result=reply.get('result',{})
            if 'exceptionDetails' in result or 'error' in reply: raise ValueError('UI method unavailable')
            return result.get('result',{}).get('value')

class UserMenu:
    def __init__(self,path):
        self.path=path
        stat=path.stat()
        self.identity=(stat.st_dev,stat.st_ino)
        self.position=stat.st_size
        self.tail=b''
    def changed(self):
        stat=self.path.stat()
        if (stat.st_dev,stat.st_ino)!=self.identity or stat.st_size<self.position:
            raise ValueError('UI log rotated')
        with self.path.open('rb') as f:
            f.seek(self.position); data=f.read(262145); self.position=f.tell()
        if len(data)>262144: raise ValueError('UI log gap too large')
        text=self.tail+data
        self.tail=text[-64:]
        return b'toggle_dashboard_action' in text

def parent_identity(pid):
    # Survives exec(bash -> love), but not reuse of the PID after game exit.
    text=Path('/proc/'+str(pid)+'/stat').read_text()
    return text.rsplit(')',1)[1].split()[19]

def run(request, menu, alive, evaluate_ui=evaluate, clock=time.monotonic, sleep=time.sleep,
        boot_timeout=60, startup_window=3):
    end=clock()+boot_timeout
    startup_end=None
    while alive() and clock()<end:
        if menu.changed(): return 'player opened menu; startup helper stopped'
        if request.exists():
            data=request.read_bytes()
            if len(data)>4096: return 'invalid startup signals; manual Resume retained'
            signals=data.splitlines()
            if b'focused' in signals: return 'VR focus already granted; helper stopped'
            if b'ready' in signals and startup_end is None:
                startup_end=clock()+startup_window
                end=min(end,startup_end)
        if startup_end is not None:
            visible=evaluate_ui(VISIBLE)
            if visible is not False and visible is not True:
                return 'Steam dashboard interface unavailable; manual Resume retained'
            if visible:
                # Recheck signals/player intent after the read-only IPC query.
                if not alive() or menu.changed(): return 'player/game state changed; helper stopped'
                if b'focused' in request.read_bytes().splitlines(): return 'VR focus already granted; helper stopped'
                if clock()>=end: break
                evaluate_ui(HIDE)
                return 'startup dashboard resume requested once; helper stopped'
        sleep(0.1)
    return 'startup window ended; manual Resume retained'

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--pid',type=int,required=True)
    parser.add_argument('--request',type=Path,required=True)
    args=parser.parse_args()
    # Missing/rotating player-intent log means no action, never blind hiding.
    home=Path.home()
    candidates=[home/'.steam/steam/logs/vrwebhelper_systemui.txt',
                home/'.local/share/Steam/logs/vrwebhelper_systemui.txt']
    try:
        menu=UserMenu(next(p for p in candidates if p.is_file()))
        identity=parent_identity(args.pid)
        def alive():
            try: return parent_identity(args.pid)==identity
            except OSError: return False
        result=run(args.request,menu,alive)
    except Exception as error:
        # No target URLs, UI content or raw IPC details in shareable game logs.
        result='startup helper unavailable ('+type(error).__name__+'); manual Resume retained'
    print('[frame-startup] r15 '+result,flush=True)

if __name__=='__main__': main()
