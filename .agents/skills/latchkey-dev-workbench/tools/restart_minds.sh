#!/bin/sh
# Force-restart the Minds desktop app from the Terminal-backed tmux (GUI session).
# SIGTERM makes Minds show a quit-confirmation dialog and hang, so we SIGKILL,
# wait for it to actually die, then reopen with retries until a process appears.
LOG="$HOME/tmp/minds_data/printbridge/restart.log"
echo "restart start $(date '+%H:%M:%S')" >> "$LOG"
sleep 2

# Force-quit (bypasses the quit-confirmation dialog).
killall -9 Minds 2>/dev/null

# Wait until it is actually gone.
i=0
while [ "$i" -lt 15 ]; do
  pgrep -x Minds >/dev/null 2>&1 || break
  i=$((i + 1)); sleep 1
done
sleep 2

# Reopen, retrying until a Minds process is running.
i=0
while [ "$i" -lt 10 ]; do
  open -a Minds 2>>"$LOG" || open /Applications/Minds.app 2>>"$LOG"
  sleep 3
  if pgrep -x Minds >/dev/null 2>&1; then
    echo "reopened ok $(date '+%H:%M:%S')" >> "$LOG"
    exit 0
  fi
  i=$((i + 1))
done
echo "REOPEN FAILED $(date '+%H:%M:%S')" >> "$LOG"
exit 1
