#!/usr/bin/env bash
set -euo pipefail
kit_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# Keep the first candidate's save/cache location so existing imports survive.
data_dir="${GEN1_FRAME_DATA_DIR:-$HOME/.local/share/Gen1RecompFrameVanilla}"
export XDG_DATA_HOME="$data_dir"
export POKEPORT_IDENTITY=gen1recomp-frame-vanilla
export POKEPORT_DEV=0
export POKEPORT_HANDHELD=1
export LD_LIBRARY_PATH="$kit_dir/runtime/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export LUA_CPATH="$kit_dir/?.so;;"
export POKEPORT_XRBRIDGE="$kit_dir/xrbridge.so"
export SDL_VIDEODRIVER=x11
export POKEPORT_VR="${POKEPORT_VR:-1}"
export POKEPORT_VR_REQUIRED="${POKEPORT_VR_REQUIRED:-1}"
# Keep this text/pixel-art screen at full shading rate for the clarity pass.
# Explicit developer overrides remain available; no global SteamVR settings.
export POKEPORT_XR_FOVEATION="${POKEPORT_XR_FOVEATION:-off}"
if [[ -f /opt/steamvr/steamxr_linuxarm64.json && -z "${XR_RUNTIME_JSON:-}" ]]; then
  export XR_RUNTIME_JSON=/opt/steamvr/steamxr_linuxarm64.json
fi
mode=game
if [[ "${1:-}" == --flat ]]; then
  mode=flat; shift
  export POKEPORT_VR=0 POKEPORT_VR_REQUIRED=0
elif [[ "${1:-}" == --probe ]]; then
  mode=probe; shift
fi
if [[ "$mode" == probe ]]; then
  app="$kit_dir/probe"
else
  app="$kit_dir/game"
  [[ -f "$app/official.dat" ]] || { echo 'Game files are missing. Extract the complete package and use PLAY.sh.' >&2; exit 2; }
fi
mkdir -p "$data_dir/logs" "$kit_dir/roms"
log="$data_dir/logs/${mode}-$(date -u +%Y%m%dT%H%M%SZ)-$$.log"
printf '[frame-quality] r14 app foveation request=%s\n' "$POKEPORT_XR_FOVEATION" >> "$log"
printf 'Gen1Recomp original launcher log: %s\n' "$log" >&2
love_bin="$kit_dir/runtime/bin/love"
if [[ ! -f "$love_bin" ]]; then
  printf 'Bundled runtime is missing. Extract the complete package.\n' | tee -a "$log" >&2
  exit 2
fi
# Folder transfers through Windows/import tools can lose Unix executable bits.
# Repair only our bundled runtime, and only when it is not already executable.
if ! test -x "$love_bin"; then
  if [[ -L "$love_bin" ]]; then
    printf 'Refusing to change permissions on a symlinked runtime.\n' | tee -a "$log" >&2
    exit 126
  fi
  printf '[frame-runtime] Restoring owner execute permission on bundled LÖVE.\n' >> "$log"
  if ! chmod u+x -- "$love_bin" >> "$log" 2>&1; then
    printf 'Could not restore runtime permission. Use a writable folder on the Frame.\n' | tee -a "$log" >&2
    exit 126
  fi
  if ! test -x "$love_bin"; then
    printf 'Runtime still cannot execute after permission repair. The folder may be on a noexec filesystem; move the complete package to a normal writable home folder and rerun INSTALL.desktop.\n' | tee -a "$log" >&2
    exit 126
  fi
fi
if [[ "$mode" == game && "$POKEPORT_VR" == 1 && "${GEN1_FRAME_KEEP_STARTUP_MENU:-0}" != 1 ]]; then
  if command -v python3 >/dev/null && [[ -f "$kit_dir/tools/startup-focus.py" ]]; then
    export GEN1_FRAME_STARTUP_FILE="${log%.log}.startup"
    : > "$GEN1_FRAME_STARTUP_FILE"
    python3 "$kit_dir/tools/startup-focus.py" --pid "$$" --request "$GEN1_FRAME_STARTUP_FILE" >> "$log" 2>&1 < /dev/null &
  else
    printf '[frame-startup] r15 helper unavailable; manual Resume retained\n' >> "$log"
  fi
fi
cd "$app"
exec "$love_bin" "$app" "$@" >>"$log" 2>&1
