#!/usr/bin/env python3
"""Stage an isolated Steam Frame host around a checksum-pinned publisher payload."""
import argparse
import gzip
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import tarfile

ROOT = Path(__file__).resolve().parent
PINS = json.loads((ROOT / 'inputs.json').read_text())

def digest(data):
    return hashlib.sha256(data).hexdigest()

def read_inputs(official, native):
    payload = official.read_bytes()
    if digest(payload) != PINS['publisher']['sha256']:
        raise ValueError('Publisher payload checksum mismatch')
    if digest(native.read_bytes()) not in PINS['accepted_native_archives']:
        raise ValueError('Native archive checksum mismatch; use an inputs.json pinned review base')
    files = {}
    modes = {}
    with tarfile.open(native, 'r:*') as archive:
        for member in archive:
            parts = PurePosixPath(member.name).parts
            if len(parts) < 2:
                continue
            rel = str(PurePosixPath(*parts[1:]))
            if rel not in PINS['native_files']:
                continue
            if not member.isfile() or '..' in parts or rel in files:
                raise ValueError('Invalid/duplicate native member: ' + rel)
            data = archive.extractfile(member).read()
            if digest(data) != PINS['native_files'][rel]:
                raise ValueError('Native member checksum mismatch: ' + rel)
            files[rel] = data
            modes[rel] = member.mode
    if set(files) != set(PINS['native_files']):
        raise ValueError('Missing native runtime members')
    files['game/official.dat'] = payload
    for folder in ('game', 'probe', 'vrbridge', 'tools', 'sources'):
        for path in (ROOT / folder).rglob('*'):
            if path.is_file():
                if path.is_symlink():
                    raise ValueError('Refusing symlink input')
                rel = path.relative_to(ROOT).as_posix()
                files[rel] = path.read_bytes()
    for name in ('README.md', 'LICENSE-FRAME', 'PLAY.sh', 'PLAY.desktop',
                 'INSTALL-TO-STEAM.sh', 'INSTALL.desktop'):
        files[name] = (ROOT / name).read_bytes()
    # Included sources must continue to describe the pinned native binary.
    for rel, expected in PINS['native_files'].items():
        if digest(files[rel]) != expected:
            raise ValueError('Source differs from pinned native runtime: ' + rel)
    metadata = dict(format='steamframe-experimental-source-proposal-v1',
                    official_version=PINS['publisher']['version'],
                    official_sha256=PINS['publisher']['sha256'],
                    official_payload_modified=False, bundled_mods=[],
                    native_files=PINS['native_files'],
                    hardware_acceptance='pending', maintainer_acceptance='pending',
                    save_identity='gen1recomp-frame-vanilla',
                    default_xdg_root='~/.local/share/Gen1RecompFrameVanilla')
    metadata['files'] = {name: digest(data) for name, data in sorted(files.items())}
    files['PACKAGE-METADATA.json'] = (json.dumps(metadata, indent=2) + '\n').encode()
    files['SHA256SUMS'] = ''.join(digest(data) + '  ' + name + '\n'
                                for name, data in sorted(files.items())).encode()
    return files, modes

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--official', type=Path, required=True)
    parser.add_argument('--native-base', type=Path, required=True)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    files, native_modes = read_inputs(args.official, args.native_base)
    if args.dry_run:
        print(json.dumps(dict(dry_run=True, files=len(files),
                              official_sha256=PINS['publisher']['sha256'],
                              native_members=len(PINS['native_files']))))
        return
    if args.output is None:
        parser.error('--output is required unless --dry-run')
    output = args.output.resolve()
    archive = output.parent / (output.name + '.tar.gz')
    if output.exists() or archive.exists():
        raise SystemExit('Refusing to overwrite a stage or archive')
    # The output belongs to the operator; no Steam registration or install runs.
    output.mkdir(parents=True)
    (output / 'roms').mkdir()
    for name, data in files.items():
        target = output / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        executable = name.endswith(('.sh', '.desktop')) or name == 'runtime/bin/love'
        target.chmod(native_modes.get(name, 0o755 if executable else 0o644))
    with archive.open('wb') as raw:
        with gzip.GzipFile(filename='', mode='wb', fileobj=raw, mtime=0) as stream:
            with tarfile.open(fileobj=stream, mode='w') as tar:
                for path in [output] + sorted(output.rglob('*')):
                    name = output.name if path == output else output.name + '/' + path.relative_to(output).as_posix()
                    info = tar.gettarinfo(str(path), arcname=name)
                    info.uid = info.gid = 0
                    info.uname = info.gname = ''
                    info.mtime = 0
                    if path.is_dir(): info.mode = 0o755
                    elif path.relative_to(output).as_posix() in native_modes:
                        info.mode = native_modes[path.relative_to(output).as_posix()]
                    elif path.suffix in ('.sh', '.desktop'): info.mode = 0o755
                    else: info.mode = 0o644
                    if path.is_file(): tar.addfile(info, io.BytesIO(path.read_bytes()))
                    else: tar.addfile(info)
    # Verify final compressed bytes rather than assuming the writer succeeded.
    with tarfile.open(archive) as tar:
        actual = {m.name.split('/', 1)[1]: tar.extractfile(m).read() for m in tar if m.isfile()}
    if actual != files:
        raise SystemExit('Final archive member verification failed')
    print(json.dumps(dict(archive=str(archive), sha256=digest(archive.read_bytes()), files=len(files))))

if __name__ == '__main__':
    main()
