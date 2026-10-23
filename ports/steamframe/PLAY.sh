#!/usr/bin/env bash
set -euo pipefail
kit_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# Desktop sessions can inherit Steam's app IDs without the game's container.
# The Steam shortcut targets the native wrapper directly; this helper always
# asks Steam to launch that registered shortcut with its compatibility settings.
if [[ ! -f "$kit_dir/.steam-registration.json" ]]; then
  bash "$kit_dir/INSTALL-TO-STEAM.sh"
fi
method="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("method","legacy"))' "$kit_dir/.steam-registration.json")"
if [[ "$method" == steam-devkit ]]; then
  exec python3 "$kit_dir/tools/live-steam.py" "$kit_dir" --launch
fi
game_id="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["gameid"])' "$kit_dir/.steam-registration.json")"
exec steam "steam://rungameid/$game_id"
