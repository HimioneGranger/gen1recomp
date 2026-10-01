"""Run production Android picker copy helpers with javac (no Android SDK required).

The worker's stream/file implementation is extracted unchanged; only Log is stubbed.
Fixtures verify streaming publication, failure cleanup and destination allowlisting.
"""
from pathlib import Path
import argparse
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'mobile/android/love/src/main/java/org/love2d/android/GameActivity.java'


def method(text, anchor):
    start = text.index(anchor)
    brace = text.index('{', start)
    depth = 1
    end = brace + 1
    while depth:
        depth += (text[end] == '{') - (text[end] == '}')
        end += 1
    return text[start:end]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path, default=SOURCE)
    parser.add_argument('--javac', default='javac')
    parser.add_argument('--java', default='java')
    parser.add_argument('--work-dir', default=None)
    args = parser.parse_args()
    src = args.source.read_text()
    # Routing assertions guard against accidentally keeping importer copies on
    # the UI-thread path or signalling generic copies as required mod imports.
    assert 'if (directRequired || isImporterDestination(destName)) {' in src
    worker = src[src.index('if (directRequired ||'):src.index('if (!copyAssetFile(pickedSource')]
    assert 'new Thread(new Runnable()' in worker
    assert 'if (directRequired) {' in worker
    assert 'writeFlagFile(pickedRoot, PICK_ERROR_FILENAME, destName)' in worker
    assert 'getCanonicalFile()' in src and '!destFile.getPath().startsWith(rootPrefix)' in src
    helpers = '\n'.join(method(src, anchor) for anchor in (
        'private static boolean isImporterDestination',
        'private static final class PickCopyResult',
        'private static String hex(',
        'private static PickCopyResult copyRequiredImport(',
    ))
    fixture = r'''
    static void check(boolean value, String label) {
        if (!value) throw new AssertionError(label);
    }
    static class Log { static void d(String tag, String message) {} }
    static class CheckedInput extends InputStream {
        final byte[] data; final File target; int cursor; boolean closed;
        CheckedInput(byte[] data, File target) { this.data=data; this.target=target; }
        public int read() {
            check(!target.exists(), "final basename published before source EOF");
            return cursor < data.length ? data[cursor++] & 255 : -1;
        }
        public int read(byte[] b, int offset, int count) {
            check(!target.exists(), "final basename visible during copy");
            if (cursor == data.length) return -1;
            int n=Math.min(Math.min(count, 32771), data.length-cursor);
            System.arraycopy(data,cursor,b,offset,n); cursor+=n; return n;
        }
        public void close() { closed=true; }
    }
    public static void main(String[] args) throws Exception {
        File root=new File(args[0]); root.mkdirs();
        check(isImporterDestination("picked_importer_gen5_bw.bin"),"gen5 accepted");
        check(isImporterDestination("picked_importer_test-2.bin"),"safe identifier accepted");
        for (String bad : new String[]{"picked_importer_.bin", "picked_importer_GEN5.bin",
            "../picked_importer_gen5_bw.bin", "x/picked_importer_gen5_bw.bin",
            "picked_importer_a\\b.bin", "picked_importer_gen5_bwXbin", "picked_rom.gb"})
            check(!isImporterDestination(bad),"unsafe/non-importer rejected: "+bad);
        byte[] data=new byte[3*1024*1024+17];
        for(int i=0;i<data.length;i++) data[i]=(byte)(i*31);
        File target=new File(root,"picked_importer_gen5_bw.bin");
        CheckedInput input=new CheckedInput(data,target);
        PickCopyResult ok=copyRequiredImport(input,target);
        check(ok.ok && ok.bytes==data.length,"successful stream copy size");
        check(input.closed,"successful stream closed");
        check(ok.md5.equals(hex(MessageDigest.getInstance("MD5").digest(data))),"MD5 exact");
        check(java.util.Arrays.equals(data,java.nio.file.Files.readAllBytes(target.toPath())),"bytes exact");
        check(!new File(target+".part").exists(),"success has no partial");
        byte[] old=java.nio.file.Files.readAllBytes(target.toPath());
        InputStream broken=new InputStream(){public int read() throws IOException {throw new IOException("fixture read failure");}};
        PickCopyResult fail=copyRequiredImport(broken,target);
        check(!fail.ok,"failure reported");
        check(java.util.Arrays.equals(old,java.nio.file.Files.readAllBytes(target.toPath())),"read failure preserves prior final");
        check(!new File(target+".part").exists(),"failure partial removed");
        File missing=new File(root,"missing.bin");
        check(!copyRequiredImport(new InputStream(){public int read() throws IOException {throw new IOException();}},missing).ok,"missing failure");
        check(!missing.exists() && !new File(missing+".part").exists(),"failure never publishes final");
        File blocked=new File(root,"blocked.bin"); blocked.mkdir();
        new FileOutputStream(new File(blocked,"prevent-delete")).close();
        check(!copyRequiredImport(new ByteArrayInputStream(data),blocked).ok,"publish failure reported");
        check(blocked.isDirectory() && !new File(blocked+".part").exists(),"publication failure cleanup");
        System.out.println("PASS Android importer copy: allowlist, async routing, atomic publication, exact bytes/MD5, read/publish failure cleanup");
    }
'''
    code='import java.io.*; import java.security.*; import java.util.*; public class PickerCopyFixture {\n'+helpers+fixture+'\n}'
    with tempfile.TemporaryDirectory(prefix='android-picker-copy-', dir=args.work_dir) as directory:
        work=Path(directory)
        (work/'PickerCopyFixture.java').write_text(code)
        subprocess.run([args.javac,'-encoding','UTF-8',str(work/'PickerCopyFixture.java')],check=True)
        subprocess.run([args.java,'-cp',str(work),'PickerCopyFixture',str(work/'fixtures')],check=True)


if __name__ == '__main__':
    main()
