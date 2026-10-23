#!/usr/bin/env bash
set -uo pipefail
kit_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
printf 'Opening Gen1Recomp VR through Steam...\n'
bash "$kit_dir/PLAY.sh" "$@"
status=$?
if [[ "$status" != 0 ]]; then
  printf '\nLaunch failed (status %s). Use Devkit Game: Gen1RecompVR in Steam.\n' "$status"
  printf 'If setup has not finished, run INSTALL.desktop and send INSTALL-LOG.txt.\n'
  if [[ -t 0 ]]; then read -r -p 'Press Enter to close. ' ignored || true; fi
fi
exit "$status"
