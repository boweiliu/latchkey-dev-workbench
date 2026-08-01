---
name: latchkey-dev-workbench
description: Toolkit and playbook for building AND live-testing a new latchkey connector (with a Playwright browser-login flow) from a Minds agent that drives a Mac -- plus how to hot-mod a running Minds gateway so the new service works end-to-end before it ships. Use when adding a custom latchkey service/connector, or when you need to drive/patch/restart the Minds desktop app from an agent. macOS-only for the Mac-side steps.
---

# Latchkey Dev Workbench

Add a new [latchkey](https://github.com/imbue-ai/latchkey) service end-to-end,
and prove it live on a real Minds gateway before it ships. The worked example is
**ngrok** (browser login -> API key -> REST calls -> tunnel authtoken), taken all
the way to a restart-durable connector.

**Read [PROGRESS.md](./PROGRESS.md) first** -- it's the full build journal:
status, the exact changes, the desktop topology, what did and didn't work, the
critical gotchas, and the reproducible procedure. This file is the quick index.

## The three layers a connector touches

1. **Connector** -- a latchkey TypeScript `Service` (URL match, credential
   injection, optional Playwright browser login). Template: `services/ngrok.ts`
   (mirrors Linear). Upstream via a latchkey PR.
2. **Catalog** (`services.json`) -- lets the permission request be filed/approved.
3. **Enforcement schema** -- a Detent `<svc>-api` scope schema, provided for a
   custom service via `additional_services.json`. **Must exist BEFORE any grant**
   or the grant bricks the agent's whole permission set. `catalog/` +
   `mngr-catalog.patch` show the shape.

## What's here

- `PROGRESS.md` -- the build journal & playbook (start here).
- `services/ngrok.ts`, `docs/ngrok.md` -- the connector + usage.
- `catalog/services.json.snippet`, `mngr-catalog.patch` -- the catalog + schema change.
- `bridge/` -- a file-share **shell channel** to the Mac (launchd helper, ~1s
  poll loop, one-click installer). Repurposed from `boweiliu/local-print-bridge`.
- `bin/deskrun` -- run a Mac command in one call via the bridge.
- `tools/restart_minds.sh` -- self-serve force-restart of the Minds app.
- `tools/patch_ngrok.js` -- register a compiled connector into a latchkey `dist`.
- `tools/patch_catalog_uv_cache.sh` -- make a catalog/schema edit survive
  restarts by patching uv's cache (the reprovision source), not the output.
- `tools/patch_wheel.py` -- patch a bundled wheel (earlier approach).
- `tools/manage_credential.sh` -- clear or re-mint a latchkey credential from the
  agent side (no Connectors UI, no gateway restart). See the note below.

## Hard-won lessons (see PROGRESS.md for detail)

- **Schema before grant.** Granting a scope with no Detent schema 403s
  *everything* until revoked.
- **Patch the install source, not the output.** The Minds venv reprovisions the
  catalog + schema from uv's cache on every boot; editing installed files reverts.
- **`chflags`/immutability is a trap** -- it breaks uv provisioning on boot.
- **SIP** blocks writing `Minds.app`; a **Terminal-backed tmux** inherits App
  Management and can. Use it to patch the bundle, then restart via the loop above.
- **Clear / re-mint a credential from the agent side (no Connectors UI).** The
  gateway's credential-store encryption key is NOT in the macOS Keychain -- it's a
  file at `~/.minds/latchkey/encryption_key` (0600), deliberately, to avoid a
  Keychain prompt. So a shell running as the user (via the bridge) can read it and
  run `latchkey auth clear|browser <svc>` against the real store
  (`LATCHKEY_DIRECTORY=~/.minds/latchkey`, `LATCHKEY_ENCRYPTION_KEY=$(cat that
  file)`, and **unset** the `LATCHKEY_GATEWAY*` vars so it's not in proxy mode).
  The gateway reads the store per-request, so a clear/re-mint takes effect
  immediately -- no restart. `tools/manage_credential.sh` wraps this. (A bare CLI
  run without that env falls through to the Keychain and fails with "the
  encryption key may have changed" -- that's the tell.)
