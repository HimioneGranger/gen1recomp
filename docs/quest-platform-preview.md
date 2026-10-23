# Quest platform preview (draft integration)

This opt-in `questVr` Android flavor presents the existing launcher and game as a flat panel in an OpenXR headset. It does not bundle VR world mods, ROMs, saves, private assets, credentials, headers or prebuilt native libraries. This is an upstream review proposal, not official platform support, platform-list acceptance, store readiness or physical headset acceptance.

Based on the Pokemon Gen 1 Recompilation Project by BOIS CLUB GAMES, LLC (https://github.com/bryanthaboi/gen1recomp). Existing notices, proprietary launcher terms and upstream branding remain. This proposal targets the upstream author for review; it does not assert permission for unrelated public launcher redistribution.

## Implementation boundaries

Existing `HostDisplay` scene callbacks and Android `GameActivity` host hooks are reused rather than recreated. Packaged detection remains inert without a matching Quest native bridge. The regular `normal` and `embed` flavors retain their activity, libraries and update behavior. The preview uses API24 minimum and ARM64 only, with `.questreview` app identity suffix and `-quest-preview` version suffix.

A generic Android observer in LÖVE runs after draw flush/default framebuffer binding and before swap, and does nothing without a registered callback. Its callback runs on the rendering thread; this host remains loaded for the process lifetime. The bridge captures completed panel pixels and starts with a black background. This is a flat panel launcher, not a stereo gameplay renderer.

Both controller rays/triggers route into existing launcher/editor input. Right-stick editor scrolling accelerates; left stick is fallback; scrollbar tracks seek/drag. Focus, tracking and scene-owner changes release held input. Generic downloaded Lua payloads and their update button are disabled only while this Quest bridge is active: those generic payloads do not include this backend. A signed APK update channel remains future work.

## Build

Use JDK17, Android SDK36, NDK25.2.9519653, Python3 and the existing Android dependency tree. Use a source path without spaces for ndk-build. See `mobile/ANDROID.md` for setup, notices and signing policy.

```sh
# From the repository root. Choose the actual source version for your build.
bash scripts/build_android.sh --package-only --version 0.3.95
cd mobile/android
./gradlew --no-daemon :app:assembleQuestVrNoRecordDebug
```

On Windows use the existing supported shell for packaging, then `gradlew.bat`. The version is a packaging input; passing0.3.95 does not turn arbitrary dev source into the stable release.

Gradle resolves the public Khronos `org.khronos.openxr:openxr_loader_for_android:1.1.60` AAR and verifies SHA256 `9a21ecea6b308d3a7fcf261412bec4cb1ae9148ba053d6b24da468fef96029c7` before extracting its header-only prefab tree under `love/build/quest-openxr/`. The computed generated include path is passed to ndk-build. The flavor-only app dependency also supplies the native runtime loader and its OpenXR permissions/broker queries. Stock flavors do not resolve or build this optional module. No dependency header or loader binary is committed here.

Output is under `mobile/android/app/build/outputs/apk/questVrNoRecord/debug/`. Keep signing keys outside the repository. Debug success does not establish release/store readiness.

## ROM-free checks and status

```sh
luajit tests/engine/host_display_test.lua
luajit tests/engine/android_host_extension_test.lua
luajit tests/quest/host_detection_test.lua
luajit tests/quest/editor_scroll_test.lua
luajit tests/quest/panel_input_test.lua
python scripts/check_quest_platform.py
```

The read-only preflight can also frontend-check ARM64 C with explicit `--ndk` and `--openxr-headers` arguments. It emits no binary and never installs anything.

The related publisher0.3.95 review APK passed signed-package and actual-launcher GPU checks: both rays open/cancel ImportROM; synthetic actual editor widgets traverse155 entries, jump354 and drag60. Those are Windows LÖVE/mocked-native results, not Quest hardware acceptance. This dev-rebased proposal is checked separately with ROM-free Lua regressions, native C frontend and structural preflight. A complete fresh Gradle APK build and physical Quest focus/picker/keyboard/editor/gameplay tests remain required before official platform acceptance. No complete-source-build or CI-ready claim is made yet.

Private review builds/source companion: https://drive.google.com/drive/folders/1U8ZpyFZXw94Jii5URl7izDUJVhv7mwqc (restricted; owner must grant access). This is review material, not an official release feed.
