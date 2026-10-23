# Steam Frame — experimental contributor proposal

This source-only port places the existing launcher/game/editor display on a
head-tracked OpenXR screen and forwards controller/gamepad and laser input. It
is a draft for maintainer review, not an accepted or supported upstream platform.
Physical Steam Frame acceptance of this exact v0.3.95 candidate remains pending.
No ROMs, saves, installed mods, engine copy, publisher assets, native binaries,
credentials, or developer profiles are committed here.

The implementation consumes the existing `src.core.HostDisplay.setBackend`
lifecycle and `PresentSync` pacing seams already present on upstream dev
`ce8d06b8f4c58eafd60341ac417f1f42ecde208a`. It changes no generic engine files
and does not repeat the earlier generic-host seam proposals. With the host
inactive, original flat-mode draw/input behavior remains available.

## Stage a review package

Use Python 3.8+, an unmodified publisher v0.3.95 LOVE, and an explicitly supplied
native review-base archive listed in `inputs.json`. The native archive is a
separate review artifact, not a Git blob. Obtain it from the contributor's review
artifacts; no private link, account access or automatic download is assumed.
The original r15 archive and current clean v0.3.95 review r2 archive are accepted
only by their full SHA256, then all 43 native members are checked individually.

```sh
cd ports/steamframe
python3 stage.py --official /path/to/gen1recomp-0.3.95.love \
  --native-base /path/to/Gen1Recomp-v0.3.95-SteamFrame-Review-r2.tar.gz --dry-run
python3 stage.py --official /path/to/gen1recomp-0.3.95.love \
  --native-base /path/to/Gen1Recomp-v0.3.95-SteamFrame-Review-r2.tar.gz \
  --output /path/to/new/Gen1Recomp-SteamFrame-Review
```

The publisher URL and checksum are in `inputs.json`; download from that exact
upstream release. Staging verifies it without editing its bytes. A fresh output
folder plus deterministic tar.gz is created; existing output paths are refused.
The script never installs, contacts Steam, registers a shortcut or launches a
headset. No Steam/ROM/user-data access is needed to stage or test.

The packaged ARM64 runtime uses Steam Linux Runtime 4.0 for ARM64. Its `INSTALL.desktop`
and `PLAY.desktop` helpers are manual operator actions, not build steps. The
installer uses the running Steam client's Devkit registration and does not exit
Steam or rewrite its shortcut database directly. Original r15 data continuity
is retained: `gen1recomp-frame-vanilla` under the default XDG root
`~/.local/share/Gen1RecompFrameVanilla`. Keep existing data and the working r15
installation until device review passes. `GEN1_FRAME_DATA_DIR` overrides that root.

## Native build provenance

The Linux ARM64 C++ bridge and runtime build recipes are included in `vrbridge/`
and `tools/`; there is no Android/Quest code in this proposal. The bridge source
is from `astromaddie/gen1recomp-frame` commit
`860a2349470efb0f0421b89e9dc8a669de5f5239`, with per-file source identities
preserved by the accepted native base. Preserve `LICENSE-FRAME`, runtime notices,
and upstream licensing when redistributing. The small Valve Devkit helpers are
included unchanged with MIT license, repository, commit and hashes under
`tools/valve-devkit/SOURCE.json`.

For an independent native rebuild on Linux with Docker ARM64 support:

```sh
cd ports/steamframe
python3 tools/fetch-runtime-sources.py sources
# Downloads are verified against sources/SHA256SUMS before container construction.
docker build --platform linux/arm64 -f tools/Dockerfile -t frame-builder .
bash tools/build-runtime.sh frame-builder /path/to/new/runtime-export
bash tools/build-bridge.sh frame-builder "$PWD" /path/to/new/runtime-export \
  /path/to/new/native-build/xrbridge.so
```

The Dockerfile's Ubuntu package repositories are not a hermetic snapshot. A
rebuild may differ from the retained binary; source checksum equality does not
promise a bit-identical toolchain. `stage.py` intentionally accepts only the
reviewed binary identities in `inputs.json`. A new native rebuild requires ABI,
dependency-closure, import, source and hardware checks plus explicit pin review;
it is not silently substituted for the reviewed runtime. The current proposal
was not validated by rebuilding ARM64 binaries on this workstation.

## Tests

Run headless adapter checks from this directory with LuaJIT:

```sh
python3 -m unittest discover -s tests -p 'test_*.py'
luajit tests/import-controls-test.lua
luajit tests/import-directory-test.lua
luajit tests/import-legacy-test.lua
luajit tests/editor-scroll-test.lua
luajit tests/surface-quality-test.lua
luajit tests/window-mode-test.lua ../..
luajit tests/view-setup-test.lua
```

Run the actual publisher launcher and widgets on a desktop LÖVE 11.5 GPU, with
only the API2 OpenXR boundary faked. Both output directories must be fresh:

```sh
python3 tests/run_gpu.py --love /path/to/love --official /path/to/gen1recomp-0.3.95.love \
  --output /path/to/new/controls-evidence
python3 tests/run_gpu.py --love /path/to/love --official /path/to/gen1recomp-0.3.95.love \
  --suite focus-quality --output /path/to/new/focus-evidence
```

These checks use synthetic paths, archive validation boundaries and editor
rows; they do not import a ROM, install a skin, use Steam or contact a headset.
The control suite exercises original main ROM/Extras/skin/My Skins callbacks,
stick/A/laser/cancel, save-editor scrolling/drag/release and window protection.
The other suite checks startup ready/focus signaling, unfocused rendering,
source filtering/mip refresh. Physical startup/dashboard behavior, gameplay,
audio, image quality, performance and controller comfort remain device-review
items. The publisher updater remains untouched and no update is applied by tests.

## Review boundary

This is a clean launcher port, not a voxel/mod stack. Maintainer agreement on
platform listing, distribution, licensing presentation and support ownership is
still required. A future upstream acceptance or hardware sign-off must not be
inferred from successful desktop/fake-XR tests.
