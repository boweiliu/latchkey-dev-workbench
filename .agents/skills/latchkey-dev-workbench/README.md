# Latchkey Dev Workbench

A toolkit + playbook for building **and live-testing** a new [latchkey](https://github.com/imbue-ai/latchkey)
service — including a Playwright browser-login flow — from a Minds AI agent that
drives a Mac. The worked example is **ngrok**, taken all the way to a working,
restart-durable connector on a real Minds gateway.

> Status: proven end-to-end and durable. `latchkey curl https://api.ngrok.com` →
> 200 through a real Minds gateway, a real ngrok tunnel opened with a
> gateway-minted authtoken, and everything survives an app restart. See
> **[PROGRESS.md](./PROGRESS.md)** for the full build journal.

## Upstreaming — the hot-mod is a DEV shortcut; a service needs THREE PRs

Everything the workbench does on a running gateway (patching the bundle, uv-cache
catalog patches, the shared-schemas write) is a **development hot-patch** that a
Minds app update reverts. To land a service for real, submit three PRs, in this
dependency order (the worked ngrok example is linked as a reference):

1. **Detent** — the permission *scope schema* (`<svc>-api` + read/write + any
   granular per-resource permissions). This is the source the catalog is
   generated from, and a grant with no Detent schema **bricks the agent's whole
   permission set**, so it must land first. Example: `imbue-ai/detent#22`.
2. **latchkey** — the *connector* (`src/services/<svc>.ts` + registration): URL
   match, credential injection, the browser login. Example: `imbue-ai/latchkey#113`.
3. **mngr** (`mngr_latchkey`) — the *catalog*: `services.json` regenerates from
   Detent (`generate_services_json.py`), plus a curated display name; custom
   services with no Detent schema instead go in `additional_services.json`.
   Example: `imbue-ai/mngr-internal#235`.

Then the Minds side bumps the Latchkey/Detent dependency and the service ships
with no hot-patching. See `mngr-catalog.patch` and PROGRESS.md's "Upstreaming"
section.

## What's here

| Path | What |
|---|---|
| `PROGRESS.md` | **The build journal & playbook** — status, exact changes, desktop topology, what did/didn't work, and the reproducible procedure. Start here. |
| `services/ngrok.ts` | The latchkey connector (mirrors Linear; browser login → API key; injects Bearer + `ngrok-version`). Upstream: latchkey PR #113. |
| `docs/ngrok.md` | Connector usage + how to derive a tunnel authtoken. |
| `catalog/services.json.snippet` | The permission-catalog entry (`ngrok-api` scope). |
| `mngr-catalog.patch` | The mngr-side change (catalog entry + the Detent `ngrok-api` scope schema via `additional_services.json`). Apply in the private mngr repo. |
| `bridge/` | The file-share **shell channel** to the Mac (launchd helper, fast poll loop, one-click installer). |
| `bin/deskrun` | Run a Mac command in one call via the bridge. |
| `tools/restart_minds.sh` | Self-serve force-restart of the Minds app (force-quit + verified reopen). |
| `tools/patch_ngrok.js` | Register a compiled connector into a latchkey `dist`. |
| `tools/patch_catalog_uv_cache.sh` | Make a catalog edit survive restarts (patch uv's cache, not the output). |
| `tools/patch_wheel.py` | Patch a bundled wheel (earlier approach). |

## The three layers a connector touches

1. **Connector** (latchkey TS `Service`) — URL match, credential injection,
   optional browser login. → `services/ngrok.ts`, latchkey PR #113.
2. **Catalog** (`services.json`) — lets the request be filed/approved. Reprovisioned
   from uv's cache on every boot, so the durable dev-hot-mod is
   `tools/patch_catalog_uv_cache.sh`.
3. **Enforcement schema** (Detent `<svc>-api` scope) — required at *call* time, and
   **must exist before any grant** or the grant bricks the agent's whole
   permission set. Provided via `additional_services.json` (see the patch).

## Key lessons

- **Order: schema before grant.** Granting a scope with no Detent schema 403s
  *everything* until revoked.
- **Patch the install source, not the output.** The Minds venv reprovisions from
  uv's cache each boot; editing installed/materialized files reverts.
- **`chflags`/immutability is a trap** — it breaks uv provisioning on boot.
- **SIP** blocks writing `Minds.app`; a **Terminal-backed tmux** inherits App
  Management and can.

macOS-only for the Mac-side steps. The connector code is portable.
