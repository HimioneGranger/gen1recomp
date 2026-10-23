#!/usr/bin/env python3
"""Register through Valve's running-client Devkit protocol; never exit Steam."""
import argparse
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys

GAME_ID='Gen1RecompVR'
OWNER='gen1recomp-frame-live-host'
RUNTIME='SteamLinuxRuntime_4-arm64' # Valve Devkit RUNTIME_ALIASES, not guessed.

def invoke(kit,helper,args,runner=subprocess.run):
    command=[sys.executable,str(kit/'tools/valve-devkit'/helper),*args]
    try:
        result=runner(command,capture_output=True,text=True,timeout=20)
    except subprocess.TimeoutExpired:
        raise ValueError('Steam did not confirm the request within 20 seconds. Leave Steam open and retry setup. No Steam restart is required.')
    if result.returncode:
        # Valve's RPC helper can include its authenticated IPC command in debug
        # stderr. Never copy that stream into a user-shareable installer log.
        raise ValueError('Steam Devkit request failed (status '+str(result.returncode)+'). Leave Steam open; check that Devkit support is enabled, or use the working PC Devkit upload route.')
    return result.stdout

def install(kit,home,runner=subprocess.run):
    for rel in ('game/official.dat','runtime/bin/love','tools/LAUNCH-STEAM-FRAME.sh',
                'tools/valve-devkit/steam-client-create-shortcut'):
        if not (kit/rel).is_file(): raise ValueError('Extract the complete package: missing '+rel)
    # Validate the official IPC prerequisites before writing our owned files.
    for name in ('steam.pid','steam.pipe','steam.token'):
        if not (home/'.steam'/name).exists():
            raise ValueError('Open Steam and leave it running, then run INSTALL.desktop again. Missing Steam Devkit IPC: '+name)
    root=home/'devkit-game'
    game=root/GAME_ID
    marker=game/'.gen1recomp-owner.json'
    if marker.is_symlink() or (game/'LAUNCH.sh').is_symlink():
        raise ValueError('Refusing symlinked ownership marker or launcher.')
    config_paths=[root/(GAME_ID+suffix) for suffix in ('-argv.json','-env.json','-settings.json')]
    if game.is_symlink() or any(p.is_symlink() for p in config_paths):
        raise ValueError('Refusing symlinked Devkit installation/config paths.')
    if game.exists() or any(p.exists() for p in config_paths):
        if not marker.is_file() or json.loads(marker.read_text()).get('owner')!=OWNER:
            raise ValueError('An unrelated Gen1RecompVR Devkit entry already exists. Nothing was overwritten; keep the working entry.')
    game.mkdir(parents=True,exist_ok=True)
    marker.write_text(json.dumps({'owner':OWNER,'kit':str(kit)},indent=2)+'\n',encoding='utf-8')
    proxy=game/'LAUNCH.sh'
    with proxy.open('w',encoding='utf-8',newline='\n') as f:
        f.write('#!/usr/bin/env bash\nexec bash '+shlex.quote(str(kit/'tools/LAUNCH-STEAM-FRAME.sh'))+' "$@"\n')
    proxy.chmod(0o755)
    parameters={'gameid':GAME_ID,'directory':str(game),'argv':['./LAUNCH.sh'],'env':{},
                'settings':{'compat_tool':RUNTIME},'force_appid':'','lepton_args':''}
    output=invoke(kit,'steam-client-create-shortcut',['--parms',json.dumps(parameters)],runner)
    try: result=json.loads(output)
    except ValueError: raise ValueError('Steam registration returned an unreadable response; setup has not confirmed success.')
    if not isinstance(result,dict):
        raise ValueError('Steam registration returned an unexpected response type; success is unconfirmed.')
    # Valve acknowledges registration by creating a response file. Its contents
    # can be empty: the helper then returns {"success": ""}. Presence/type, not
    # string truthiness, distinguishes this from no response or an error file.
    if 'error' in result or 'success' not in result or not isinstance(result['success'],str):
        raise ValueError('Steam did not confirm shortcut registration: '+str(result.get('error','missing success response')))
    receipt={'method':'steam-devkit','devkit_gameid':GAME_ID,'kit':str(kit),
             'runtime_tool':RUNTIME,'steam_confirmation':True,'launcher':str(proxy)}
    (kit/'.steam-registration.json').write_text(json.dumps(receipt,indent=2)+'\n')
    return receipt

def launch(kit,runner=subprocess.run):
    receipt=json.loads((kit/'.steam-registration.json').read_text())
    if receipt.get('method')!='steam-devkit' or receipt.get('devkit_gameid')!=GAME_ID:
        raise ValueError('Run this package INSTALL.desktop first; its live registration is missing.')
    invoke(kit,'steam-devkit-rpc',['run-game','gameid='+GAME_ID],runner)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('kit',type=Path)
    ap.add_argument('--launch',action='store_true')
    args=ap.parse_args(); kit=args.kit.resolve()
    if args.launch: launch(kit); return
    print('Registering with the running Steam client. Steam will stay open.',flush=True)
    install(kit,Path.home())
    print('Steam confirmed registration. Find Devkit Game: Gen1RecompVR in Steam and launch it.')
    print('Runtime requested: Steam Linux Runtime 4.0 for ARM64. Let Steam install it if prompted.')
    print('If needed, check Properties > Compatibility shows Runtime 4.0 for ARM64.')

if __name__=='__main__':
    try: main()
    except (OSError,ValueError,subprocess.SubprocessError) as error:
        print('Setup/launch failed: '+str(error),file=sys.stderr)
        raise SystemExit(2)
