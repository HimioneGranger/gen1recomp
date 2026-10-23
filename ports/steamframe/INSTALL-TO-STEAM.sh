#!/usr/bin/env bash
set -euo pipefail
kit_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
log="$kit_dir/INSTALL-LOG.txt"
if ! touch "$log"; then
  printf 'Cannot write setup log. Extract the package into a writable folder and retry.\n' >&2
  exit 2
fi
exec > >(tee -a "$log") 2>&1
finish() {
  status=$?
  trap - EXIT
  printf '\nSetup exit status: %s\nLog: %s\n' "$status" "$log"
  if [[ -t 0 && "${GEN1_FRAME_NO_PAUSE:-0}" != 1 ]]; then
    read -r -p 'Press Enter to close this window. ' ignored || true
  fi
  exit "$status"
}
trap finish EXIT
printf '\n=== Gen1Recomp VR setup: %s ===\n' "$(date -u +%FT%TZ)"
printf 'Folder: %s\n' "$kit_dir"
if ! command -v python3 >/dev/null 2>&1; then
  printf 'Python 3 is unavailable. No Steam files were changed. Use the documented Devkit route; do not install LOVE.\n'
  exit 2
fi
status=0
python3 "$kit_dir/tools/live-steam.py" "$kit_dir" || status=$?
if [[ "$status" != 0 ]]; then
  printf '\nSetup did not finish. Send INSTALL-LOG.txt to troubleshoot.\n'
  exit "$status"
fi
printf '\nSetup finished. Launch Devkit Game: Gen1RecompVR from Steam. Steam stays open.\n'
printf 'The Install Gen1Recomp VR icon runs setup again; it is not the game.\n'
