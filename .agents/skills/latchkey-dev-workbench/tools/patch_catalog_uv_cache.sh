#!/bin/sh
# Make a hand-added services.json catalog entry SURVIVE Minds restarts.
#
# The Minds app reprovisions its Python venv on every boot, COPYING the latchkey
# permission catalog (services.json) from uv's package cache. So editing the
# installed/materialized copy reverts on restart. The durable hot-mod is to
# patch every cached build of the catalog in uv's archive cache; the reprovision
# then copies YOUR version into the venv on its own (normal mutable file, no
# crash -- unlike chflags/immutability, which breaks provisioning).
#
# Run this ON THE MAC (e.g. via the bridge deskrun). Edit SERVICE_JSON to inject
# your own scope entry.
UVCACHE="$HOME/.minds/.uv-cache/archive-v0"
NEW_ENTRY='{"scope":"ngrok-api","display_name":"ngrok","description":"All requests to the ngrok API.","permissions":[]}'
SERVICE_NAME="ngrok"
n=0
for f in $(find "$UVCACHE" -maxdepth 6 -path "*mngr_latchkey/extensions/services.json" 2>/dev/null); do
  /opt/homebrew/bin/python3 - "$f" "$SERVICE_NAME" "$NEW_ENTRY" <<'PY'
import json, sys
path, name, entry = sys.argv[1], sys.argv[2], json.loads(sys.argv[3])
d = json.load(open(path))
if name not in d:
    d[name] = [entry]
    json.dump(d, open(path, "w"), indent=2)
PY
  n=$((n + 1))
done
echo "patched $n cached catalog copies; restart Minds to reprovision"
