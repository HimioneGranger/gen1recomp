import importlib.util
import io
import json
from pathlib import Path
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('stage', ROOT / 'stage.py')
stage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(stage)

class StagingInputs(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.old_root, self.old_pins = stage.ROOT, stage.PINS
        self.addCleanup(self.restore)
        stage.ROOT = self.root
        for folder in ('game', 'probe', 'vrbridge', 'tools', 'sources'):
            (self.root / folder).mkdir()
        for name in ('README.md', 'LICENSE-FRAME', 'PLAY.sh', 'PLAY.desktop',
                     'INSTALL-TO-STEAM.sh', 'INSTALL.desktop'):
            (self.root / name).write_text('synthetic source fixture\n')
        self.official = self.root / 'publisher.love'
        self.official.write_bytes(b'synthetic publisher boundary')
        self.native = self.root / 'native.tar.gz'
        self.native_bytes = b'synthetic native boundary'
        self.write_native(self.native_bytes)
        stage.PINS = dict(publisher=dict(version='test', sha256=stage.digest(self.official.read_bytes())),
                          accepted_native_archives={stage.digest(self.native.read_bytes()): 'fixture'},
                          native_files={'runtime/bin/love': stage.digest(self.native_bytes)})

    def restore(self):
        stage.ROOT, stage.PINS = self.old_root, self.old_pins

    def write_native(self, data, duplicate=False):
        with tarfile.open(self.native, 'w:gz') as tar:
            for _ in range(2 if duplicate else 1):
                member = tarfile.TarInfo('kit/runtime/bin/love')
                member.mode = 0o755; member.size = len(data)
                tar.addfile(member, io.BytesIO(data))

    def test_valid_inputs_keep_payload_and_native_identity(self):
        files, modes = stage.read_inputs(self.official, self.native)
        self.assertEqual(files['game/official.dat'], self.official.read_bytes())
        self.assertEqual(files['runtime/bin/love'], self.native_bytes)
        self.assertEqual(modes['runtime/bin/love'], 0o755)
        meta = json.loads(files['PACKAGE-METADATA.json'])
        self.assertFalse(meta['official_payload_modified'])
        self.assertEqual(meta['bundled_mods'], [])
        for line in files['SHA256SUMS'].decode().splitlines():
            digest, name = line.split(None, 1)
            self.assertEqual(stage.digest(files[name.strip()]), digest)

    def test_publisher_mismatch_fails_before_output(self):
        self.official.write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'Publisher'):
            stage.read_inputs(self.official, self.native)

    def test_native_archive_mismatch(self):
        self.native.write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'Native archive'):
            stage.read_inputs(self.official, self.native)

    def test_native_member_mismatch_even_after_container_pin(self):
        self.write_native(b'changed member')
        stage.PINS['accepted_native_archives'] = {stage.digest(self.native.read_bytes()): 'fixture'}
        with self.assertRaisesRegex(ValueError, 'member checksum'):
            stage.read_inputs(self.official, self.native)

    def test_duplicate_native_member_rejected(self):
        self.write_native(self.native_bytes, duplicate=True)
        stage.PINS['accepted_native_archives'] = {stage.digest(self.native.read_bytes()): 'fixture'}
        with self.assertRaisesRegex(ValueError, 'duplicate'):
            stage.read_inputs(self.official, self.native)

if __name__ == '__main__': unittest.main()
