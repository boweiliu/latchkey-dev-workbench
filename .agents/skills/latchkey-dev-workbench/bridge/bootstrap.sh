#!/bin/sh
# Minds Print Bridge -- one-time bootstrap, run via the .terminal double-click.
# Lays down the durable core + launcher + logic, then starts the agent. Idempotent.
# After this, agent.sh keeps every copy in sync from the bridge, so no reinstall
# is ever needed to fix a mistake -- only agent.sh (editable via the bridge) matters.
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
LABEL="com.minds.printbridge"
SUPPORT="$HOME/Library/Application Support/MindsPrintBridge"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
BASE="$HOME/tmp/minds_data/printbridge"
mkdir -p "$SUPPORT" "$HOME/Library/LaunchAgents" "$BASE/queue" "$BASE/done" "$BASE/receipts"
LOG="$BASE/install.log"; RECEIPT="$BASE/install-receipt.txt"; : > "$LOG"
log(){ echo "$@"; echo "$@" >> "$LOG"; }
log "Minds Print Bridge install: $(date '+%Y-%m-%d %H:%M:%S %Z')"

# durable core + durable logic backup (from the staged bridge files)
cp "$BASE/core.src.sh" "$SUPPORT/core.sh"          2>>"$LOG" && log "installed durable core"
cp "$BASE/agent.sh"    "$SUPPORT/agent.default.sh" 2>>"$LOG" && log "installed durable logic backup"

cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>/bin/sh</string><string>$SUPPORT/core.sh</string></array>
  <key>RunAtLoad</key><true/>
  <key>StartInterval</key><integer>15</integer>
  <key>WatchPaths</key><array><string>$BASE/queue</string></array>
  <key>StandardOutPath</key><string>$BASE/agent.out.log</string>
  <key>StandardErrorPath</key><string>$BASE/agent.err.log</string>
</dict>
</plist>
PLIST
log "wrote launcher: $PLIST"

U=$(id -u)
launchctl bootout "gui/$U/$LABEL" 2>/dev/null
if launchctl bootstrap "gui/$U" "$PLIST" 2>>"$LOG"; then log "bootstrap ok"; else log "bootstrap nonzero; legacy load"; launchctl load -w "$PLIST" 2>>"$LOG" || true; fi
launchctl enable "gui/$U/$LABEL" 2>/dev/null
launchctl kickstart -k "gui/$U/$LABEL" 2>>"$LOG" || true
log "started agent"
sleep 3

STATUS="not-loaded"; launchctl print "gui/$U/$LABEL" >/dev/null 2>&1 && STATUS="loaded"
{
  echo "=== MINDS PRINT BRIDGE INSTALL RECEIPT ==="
  echo "when: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "agent_status: $STATUS"
  echo "durable_core: $SUPPORT/core.sh"
  echo "launcher: $PLIST"
  echo "editable_logic: $BASE/agent.sh"
  echo "durable_backup: $SUPPORT/agent.default.sh"
  echo "--- printers (lpstat -p -d) ---"; lpstat -p -d 2>&1
  echo "--- default (lpstat -d) ---";     lpstat -d 2>&1
  echo "=== END ==="
} > "$RECEIPT" 2>&1
log "receipt written; status=$STATUS"

echo
echo "============================================================"
echo "  Minds Print Bridge installed and running ($STATUS)."
echo "  You never need to run this again. You can close this window."
echo "============================================================"
