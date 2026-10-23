#!/usr/bin/env python3
"""Read-only structural preflight; optional native frontend check. No package/install."""
from pathlib import Path
import argparse, os, subprocess

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source-root',type=Path,default=Path(__file__).resolve().parents[1])
    p.add_argument('--ndk',type=Path,help='optional Android NDK root; use with --openxr-headers')
    p.add_argument('--openxr-headers',type=Path,help='public include directory containing openxr/openxr.h')
    a=p.parse_args();r=a.source_root.resolve()
    def read(n): return (r/n).read_text(encoding='utf-8')
    source=read('mobile/android/love/src/jni/questxr_bridge/questxr_bridge.c')
    assert 'glClearColor(0.0f, 0.0f, 0.0f, 1.0f);' in source
    assert 'questxr_poll_panel_input_state' in source and 'questxr_poll_panel_scroll_y' in source
    mk=read('mobile/android/love/src/jni/questxr_bridge/Android.mk')
    assert 'ifeq ($(QUEST_XR),1)' in mk and '$(QUEST_OPENXR_INCLUDE)' in mk
    lib=read('mobile/android/love/build.gradle');app=read('mobile/android/app/build.gradle')
    assert 'prepareQuestOpenXRHeaders' in lib and '1.1.60@aar' in lib
    assert "questVrImplementation 'org.khronos.openxr:openxr_loader_for_android:1.1.60'" in app
    assert "applicationIdSuffix '.questreview'" in app
    assert 'ACTIVITY:"org.love2d.android.GameActivity"' in app
    graphics=read('mobile/android/love/src/jni/love/src/modules/graphics/opengl/Graphics.cpp')
    body=graphics[graphics.index('void Graphics::present('):]
    assert body.index('flushStreamDraws();') < body.index('notifyAndroidHostPresentedFrame(') < body.index('window->swapBuffers();')
    assert '#ifdef LOVE_ANDROID' in graphics and 'love_android_set_presented_frame_observer' in graphics
    java=read('mobile/android/love/src/questVr/java/org/love2d/android/QuestGameActivity.java')
    assert 'extends GameActivity' in java and 'getHostLibraries()' in java
    for n in ['main.lua','src/import/RomImporter.lua']: assert 'QUEST_PANEL_ACTIVE' in read(n)
    if bool(a.ndk)!=bool(a.openxr_headers): p.error('provide both --ndk and --openxr-headers')
    if a.ndk:
        assert (a.openxr_headers/'openxr/openxr.h').is_file()
        prebuilt=next((a.ndk/'toolchains/llvm/prebuilt').iterdir())
        compiler=prebuilt/'bin'/('clang.exe' if os.name=='nt' else 'clang')
        subprocess.run([str(compiler),'--target=aarch64-linux-android24','--sysroot='+str(prebuilt/'sysroot'),'-I'+str(a.openxr_headers),'-std=c11','-DGL_GLEXT_PROTOTYPES','-fsyntax-only',str(r/'mobile/android/love/src/jni/questxr_bridge/questxr_bridge.c')],check=True)
        print('Quest ARM64 native frontend: PASS (no binary emitted)')
    print('Quest structural preflight: PASS; full Gradle/hardware acceptance separate')

if __name__=='__main__': main()
