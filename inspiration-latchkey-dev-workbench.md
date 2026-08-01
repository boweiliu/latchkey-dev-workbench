---
title: Latchkey Dev Workbench
description: Toolkit and playbook for building and live-testing a custom latchkey connector (with a Playwright browser-login flow) from a Minds agent, including how to hot-mod a running Minds gateway to prove it end-to-end.
thumbnail: inspiration-latchkey-dev-workbench.svg
version: v3
format: v1
---

# Latchkey Dev Workbench

This file is the manifest for the **Latchkey Dev Workbench** inspiration (slug:
`latchkey-dev-workbench`). It is the one document a future agent reads to understand,
present, and adapt this inspiration. If you are an agent in a mind that was
created from this inspiration, this file is your script: read all of it, then
follow "How to adapt it" below.

## What it is

Toolkit and playbook for building and live-testing a custom latchkey connector (with a Playwright browser-login flow) from a Minds agent, including how to hot-mod a running Minds gateway to prove it end-to-end.

This is a developer TOOLKIT and playbook, not a user-facing app -- its "user"
is a developer (working through a Minds agent) who wants to add a new latchkey
connector for some third-party service and test it against a real Minds gateway
before shipping it. Adding a connector normally touches three separate layers
that all have to line up, and a mistake in the wrong order can lock the agent
out of its own permissions entirely; there is also no easy way to iterate,
because the running desktop app reverts hand-edits on every restart and its app
bundle is protected by the OS. This workbench solves both problems. It provides
a connector template (a latchkey TypeScript `Service` with URL matching,
credential injection, and an optional Playwright browser-login flow), the
catalog and Detent enforcement-schema pieces that make a permission grant
actually work, and a set of tools for driving and hot-modding a live gateway
from the agent: a shell channel to the developer's Mac, a one-call remote-command
helper, a self-restart loop, and cache/bundle patch scripts that make dev edits
survive restarts. The worked example, ngrok, is carried all the way through --
browser login, a stored credential, an authenticated `latchkey curl` returning
200, a minted tunnel authtoken, and a real public tunnel -- so the whole loop is
demonstrated end-to-end. When it is "running," what you get is a live iteration
loop: change the connector, push it into the gateway, restart, and re-test,
all driven from the agent, plus a build journal (`PROGRESS.md`) that records the
exact procedure, the hard-won gotchas, and the durable upstream path.

## How it works

The snapshot includes these paths (each is a repo-root-relative path copied
from the original mind onto a clean default-workspace-template base):

- `.agents/skills/latchkey-dev-workbench`

The single included path is `.agents/skills/latchkey-dev-workbench` -- a
committed Minds skill that IS the workbench. It runs nothing on boot: there are
no supervisord programs, no ports, and no `forward_port.py` registration. It is
a bundle of code templates, tooling scripts, and documentation that an agent
reads and runs on demand. Its contents:

- `SKILL.md` -- the quick index and entry point.
- `PROGRESS.md` -- the full build journal and reproducible playbook (status
  table, the exact winning changes, the desktop topology, the critical gotchas,
  and the step-by-step procedure for the next connector). Read it first.
- `README.md` -- the skill's own overview.
- `services/ngrok.ts` + `docs/ngrok.md` -- the worked-example connector (a
  latchkey `Service` mirroring the Linear connector) and its usage notes.
- `catalog/services.json.snippet` + `mngr-catalog.patch` -- the catalog entry
  and the `additional_services.json` Detent enforcement-schema change.
- `bridge/` -- a file-share shell channel to the developer's Mac (a launchd
  helper, `com.minds.printbridge`, that polls a `cmd/` inbox roughly once a
  second and writes results to `cmd_done/`; `agent.sh`/`core.src.sh`/
  `bootstrap.sh` implement the fast bounded poll loop and the
  `Set Up Minds Printing.terminal` one-click installer). Repurposed from an
  existing local-print-bridge project.
- `bin/deskrun` -- runs any shell command on the Mac in a single call by writing
  a command file through the bridge and waiting for the archived original as the
  done-signal (the `.out` exists mid-run and would read back partial).
- `tools/restart_minds.sh` -- a self-serve force-restart of the Minds desktop
  app (`killall -9`, since SIGTERM hangs on the quit dialog, then reopen with
  retries), driven from a Terminal-backed tmux window so it survives the gateway
  dying.
- `tools/patch_ngrok.js` -- registers a compiled connector into a latchkey
  `dist` (drops the `.js`, edits `serviceRegistry.js` and `services/index.js`).
- `tools/patch_catalog_uv_cache.sh` -- makes a catalog/schema edit durable by
  patching every cached build in uv's archive cache (the reprovision source),
  not the installed output.
- `tools/patch_wheel.py` -- an earlier approach that patched the bundled wheel.

How the pieces wire together at *use* time (there is no runtime service): the
agent installs the bridge on the Mac, then uses `bin/deskrun` (through the
bridge) to run Mac-side commands -- including the Terminal-backed tmux session
that can write the SIP-protected `Minds.app` bundle. It patches the compiled
connector into the app's bundled latchkey `dist` (`patch_ngrok.js`), patches the
catalog and the `additional_services.json` enforcement schema into uv's cache
(`patch_catalog_uv_cache.sh`) so they survive the app's on-boot reprovision,
force-restarts the app (`restart_minds.sh`), and polls
`permissions/self` until the gateway recovers. From the container it then
requests the new scope, the user approves it (triggering the connector's
Playwright browser login), and an authenticated `latchkey curl` returns 200.
The three layers a connector must satisfy -- the connector `Service`, the
catalog `services.json` entry (so the permission can be requested/approved), and
the Detent `<svc>-api` enforcement schema via `additional_services.json` (so
granted calls resolve instead of 403-bricking every permission) -- are the spine
the rest of the tooling exists to install and prove.

## Recipe

This inspiration is version `v3` (front-matter `version:`).
It is not a fork of the workspace it came from -- it is DERIVED from it by the
recipe below: include these paths, leave these out, apply these
published-version rules. An update re-runs the recipe against the current
workspace and publishes the result as the next version, so anything excluded
here stays excluded even though it still exists in the source workspace. This
block is the durable home of that recipe -- a later update reads it back from
here.

```yaml
version: v3
include:
  - .agents/skills/latchkey-dev-workbench
data_include: []
exclude: []
modification_rules:
  - generalize the hardcoded developer home path to $HOME
  - generalize the hardcoded machine hostname to $HOSTNAME
```

## Prerequisites

Activation requirements: what the adopting agent must SET UP -- and must
INITIATE ITSELF during setup, before asking how to adapt -- for this
inspiration to run against the new user's own accounts/data. One line per
requirement, in this machine-readable form (greppable by `requires_`):

No prerequisites -- runs with no external permissions or secrets. This is
developer tooling; nothing here runs on boot or calls a service, so an ADOPTER
grants nothing to install it. There is no `requires_permission`, no
`requires_secret`, and no `requires_llm` (no code here calls Claude).

Note (not an install-time requirement, but what actually *using* the toolkit
needs, on the developer's own side): a Mac, because all the hot-mod steps run
against the macOS Minds desktop app; the file-sharing bridge installed on that
Mac (a one-time double-click of `bridge/Set Up Minds Printing.terminal`, which
needs a file-sharing WRITE grant to `~/tmp/minds_data` so the agent can drive
the Mac); and, to test a connector end-to-end, an account on whatever target
service the connector is for (the worked example needs an ngrok account to sign
into during the browser-login flow).

## How to adapt it

Instructions for the NEXT agent -- the one adapting this inspiration into a
new mind. This is the `use-inspiration` skill's template path; in short:

1. Read this entire file first, especially "Prerequisites" and "Holes"
   below -- Prerequisites are your SETUP agenda, Holes are your ADAPTATION
   agenda.
2. Present the inspiration to the user in plain, non-technical language: what
   it is, what it does, and what it needs from them (name the Prerequisites).
3. Ask whether they want to use the same connectors (e.g. their own Slack).
   If YES: ACTIVATE FIRST -- initiate every `requires_permission` line NOW
   via a latchkey permission request (see the `latchkey` skill; the request
   opens the approval/login flow in the minds app), wire up any
   `requires_secret` values, start the services, and get the app showing
   THE USER'S OWN DATA. Done for a data-backed app means the user can open it
   and see their own data -- NOT that a service starts or an endpoint returns
   200. Then tell them it is live and to take a look.
4. Only AFTER that (or immediately, if they chose different connectors -- the
   swap is then the first adaptation) ask: "How do you want to adapt it?"
5. Work through each hole interactively, one at a time. Translate each into
   plain language, ask for a decision only when you genuinely need one, and
   resolve the obvious ones yourself.
6. When done, append a dated entry to "Adaptation history" below (never
   rewrite earlier entries) and commit.

## Holes

- **macOS-only for the Mac-side steps.** Everything that drives, patches, or
  restarts the desktop app (the bridge, `bin/deskrun`, `restart_minds.sh`, the
  Terminal-backed tmux App-Management trick, the uv-cache and bundle patches)
  assumes a Mac and the macOS Minds desktop app. On any other host the Mac-side
  half does not apply, and an adapter would have to find the equivalent
  install-source and app-bundle locations for that platform.
- **The hot-mod path is dev-only and does not survive a Minds app update.** The
  cache/bundle patches (`patch_catalog_uv_cache.sh`, `patch_ngrok.js`,
  `patch_wheel.py`) mutate a specific installed layout; they are how you prove a
  connector live, not how you ship it. A Minds app update reprovisions from a
  fresh package and reverts them. The durable path is the upstream PRs -- the
  latchkey connector PR plus the `mngr` catalog / `additional_services.json`
  change (see `mngr-catalog.patch`) rolled into a new wheel and release -- which
  an adapter must carry through for their own service.
- **The connector template is ngrok-specific and must be adapted per service.**
  `services/ngrok.ts`, the `services.json` catalog entry, and the `ngrok-api`
  Detent scope schema all hardcode ngrok's domain (`api.ngrok.com`), its login
  page, and its API-key flow. For a different service, an adapter rewrites the
  connector's URL match, credential injection, and Playwright browser-login
  selectors against that service's live dashboard, and swaps the catalog entry
  and the `<svc>-api` enforcement schema accordingly. Critically, the schema must
  exist BEFORE the grant, or granting the scope bricks the agent's entire
  permission set (see PROGRESS.md's gotcha).
- **Exact locations still open.** PROGRESS.md's reproducible procedure flags one
  unpinned spot (where the gateway loads Detent schemas for a fresh service on a
  given app version); an adapter on a newer app build may need to re-confirm the
  install-source paths (uv cache archive, bundled `dist`, materialized
  extensions) before the patches land.

## Publication history

This inspiration's changelog: what each published version changed. The PUBLISHER
appends one entry per version (newest last); earlier entries are never rewritten.
This is distinct from "Adaptation history" below, which is the ADOPTERS' log.

### v1 (2026-07-30) -- initial workbench: ngrok connector + bridge/deskrun tooling + self-restart loop + hot-mod playbook

### v2 (2026-07-31) -- docs: the hot-mod is a dev shortcut needing three upstream PRs (Detent -> latchkey -> mngr); added agent-side credential clear/re-mint via the on-disk encryption key (new `tools/manage_credential.sh`)

### v3 (2026-07-31) -- ngrok scopes verified against the full ngrok OpenAPI surface (241 ops) and trimmed to the useful set (dropped api_keys granularity); catalog snippet updated to the real 4-permission entry

## Adaptation history

Each mind that adapts this inspiration appends one dated entry below. Earlier
entries are never rewritten.
