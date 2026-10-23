#!/usr/bin/env python3
"""Run actual publisher launcher/GPU regressions with only the XR boundary faked."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

def main():
    root = Path(__file__).resolve().parent
    port = root.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--love', default='love')
    parser.add_argument('--official', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--suite', choices=('controls', 'focus-quality'), default='controls')
    args = parser.parse_args()
    pins = json.loads((port / 'inputs.json').read_text())
    if hashlib.sha256(args.official.read_bytes()).hexdigest() != pins['publisher']['sha256']:
        raise SystemExit('Publisher checksum mismatch')
    output = args.output.resolve()
    if output.exists(): raise SystemExit('Use a fresh test output directory')
    output.mkdir(parents=True)
    fixture = output / 'fixture'
    shutil.copytree(port / 'game', fixture)
    shutil.copy2(root / 'fixture-conf.lua', fixture / 'conf.lua')
    for path in root.glob('*.lua'):
        shutil.copy2(path, output / path.name)
    driver = 'driver.lua'
    if args.suite == 'focus-quality':
        driver = 'focus-quality-driver.lua'
        bridge = output / 'fake-api2.lua'
        bridge.write_text(bridge.read_text().replace('focused=true,render=true', 'focused=false,render=true'))
    env = os.environ.copy()
    env.update(POKEPORT_HANDHELD='1', POKEPORT_VR='1',
               POKEPORT_XRBRIDGE='fake-api2-fixture',
               FRAME_TEST_BRIDGE=str(output / 'fake-api2.lua'),
               FRAME_TEST_DRIVER=str(output / driver), FRAME_TEST_OUTPUT=str(output),
               FRAME_TEST_OFFICIAL=str(args.official.resolve()),
               GEN1_FRAME_STARTUP_FILE=str(output / 'startup-signals.txt'),
               GEN1_FRAME_TEST_ID='steamframe-proposal-' + args.suite + '-' + str(time.time_ns()))
    startup = None
    if os.name == 'nt':
        startup = subprocess.STARTUPINFO()
        startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startup.wShowWindow = 0
    with (output / 'love-output.txt').open('wb') as log:
        process = subprocess.Popen([args.love, str(fixture)], env=env, stdout=log,
                                   stderr=subprocess.STDOUT, startupinfo=startup)
        try: code = process.wait(timeout=60)
        except subprocess.TimeoutExpired:
            process.terminate(); process.wait(timeout=10); code = 'timeout'
    result = dict(exit=code, suite=args.suite, physical_headset=False,
                  results=(output / 'gpu-results.txt').read_text() if (output / 'gpu-results.txt').exists() else None)
    (output / 'run-result.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result))
    raise SystemExit(0 if code == 0 and result['results'] else 1)

if __name__ == '__main__': main()
