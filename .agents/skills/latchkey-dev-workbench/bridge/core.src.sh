#!/bin/sh
# Minds Print Bridge -- durable core (the ONLY fixed-in-place piece).
# Deliberately minimal: restore the editable logic if the bridge folder was wiped,
# then run it. All real work + all self-updating lives in agent.sh, which the mind
# can edit through the file bridge -- so a mistake anywhere else is fixable remotely.
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
SUPPORT="$HOME/Library/Application Support/MindsPrintBridge"
BASE="$HOME/tmp/minds_data/printbridge"
mkdir -p "$BASE/queue" "$BASE/done" "$BASE/receipts" "$SUPPORT"
[ -f "$BASE/agent.sh" ] || { [ -f "$SUPPORT/agent.default.sh" ] && cp "$SUPPORT/agent.default.sh" "$BASE/agent.sh"; }
[ -f "$BASE/agent.sh" ] && exec /bin/sh "$BASE/agent.sh"
exit 0
