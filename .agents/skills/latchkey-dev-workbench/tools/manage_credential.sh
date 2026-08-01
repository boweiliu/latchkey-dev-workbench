#!/bin/sh
# Manage a latchkey credential from the AGENT side -- clear or re-mint one without
# the Minds Connectors UI. macOS.
#
# Why this works: the running Minds gateway does NOT keep its credential-store
# encryption key in the macOS Keychain (a bare shell can't decrypt the store that
# way -- you get "the encryption key may have changed"). It keeps the key as a
# FILE at $LATCHKEY_DIRECTORY/encryption_key (0600), deliberately, to avoid a
# Keychain prompt. So a shell running AS THE USER (e.g. via the print-bridge) can
# read that key and drive `latchkey auth ...` against the real store. The gateway
# reads the store per request, so a clear / re-mint takes effect IMMEDIATELY --
# no gateway restart needed. The key never has to leave the Mac.
#
# Usage (run on the Mac, e.g. via deskrun):
#   manage_credential.sh list                 # list stored credentials
#   manage_credential.sh clear   <service>    # clear a credential (e.g. ngrok)
#   manage_credential.sh browser <service>    # open the headful login to re-mint
#
# NOTE: `clear` removes only the credential, not the permission grant. `browser`
# opens a real Chrome window the user signs into; it re-mints and stores the
# credential in the real gateway store.
set -eu
LATCHKEY_DIR="${LATCHKEY_DIRECTORY:-$HOME/.minds/latchkey}"
CLI="/Applications/Minds.app/Contents/Resources/latchkey/node_modules/latchkey/dist/src/cli.js"
NODE="${NODE:-/opt/homebrew/bin/node}"
KEY_FILE="$LATCHKEY_DIR/encryption_key"
[ -f "$KEY_FILE" ] || { echo "no encryption_key file at $KEY_FILE" >&2; exit 1; }
export LATCHKEY_DIRECTORY="$LATCHKEY_DIR"
export LATCHKEY_ENCRYPTION_KEY="$(cat "$KEY_FILE")"
# Ensure we are NOT in gateway-proxy mode (that refuses auth subcommands).
unset LATCHKEY_GATEWAY LATCHKEY_GATEWAY_PASSWORD LATCHKEY_GATEWAY_PERMISSIONS_OVERRIDE
action="${1:-}"; service="${2:-}"
case "$action" in
  list)    exec "$NODE" "$CLI" auth list ;;
  clear)   [ -n "$service" ] || { echo "usage: $0 clear <service>" >&2; exit 2; }
           exec "$NODE" "$CLI" auth clear "$service" --all ;;
  browser) [ -n "$service" ] || { echo "usage: $0 browser <service>" >&2; exit 2; }
           exec "$NODE" "$CLI" auth browser "$service" ;;
  *) echo "usage: $0 <list|clear|browser> [service]" >&2; exit 2 ;;
esac
