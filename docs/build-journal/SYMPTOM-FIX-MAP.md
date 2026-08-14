# Symptom -> fix map (paper trail)

For every symptom, hole, or lesson in each `docs/build-journal/` entry, this
file records whether a **concrete artifact fix** (a script, a code path, a
config, or a shipped instruction) exists in the shipped tree, and the exact
`file:line` where it lives. Symptoms with only a journal narrative and no
shipped fix are marked **NO SHIPPED FIX** and explained.

The purpose is to make "described but not included" gaps grep-able: a lesson
in the skill or manifest must either point at a shipped artifact recorded
here, or be marked as a deliberate non-fix (a future-improvement, an upstream
ask, or a platform limitation outside this inspiration's scope).

Format per item:

```
- [LNN-x] <symptom, one line>  (entry NN)
  - fix: <SHIPPED FIX file:line> | <NO SHIPPED FIX -- reason>
```

Convention: the shipped-tree paths are relative to the repo root of the
inspiration repo this file lives in (i.e. `.agents/skills/latchkey-dev-workbench/`
for the skill, plus top-level files for the manifest).

---

## latchkey-dev-workbench

### Entry 01 -- ngrok connector: scope verification, trim, upstreaming

- [L01-1] ngrok scopes verified against the real OpenAPI (241 ops) and trimmed (7 -> 5)
  - fix: SHIPPED -- `catalog/services.json.snippet:4` (`ngrok-api` scope), `:9` (`ngrok-read-all`), `:13` (`ngrok-write-all`), `:17` (`ngrok-read-credentials`), `:21` (`ngrok-write-credentials`) -- the trimmed 5-scope set; `api_keys` dropped
- [L01-2] schema-before-grant (a missing schema bricks every permission)
  - fix: SHIPPED (doc) -- `SKILL.md:46`, `docs/connector-build-playbook.md:63`, `PROGRESS.md:178`
- [L01-3] a live hot-mod is a debt that bricks days later (reprovision drift)
  - fix: SHIPPED (doc) -- `SKILL.md:48`, `docs/connector-build-playbook.md:157`
- [L01-4] recordings blacklist for browser-followup services (ngrok was missing, wrongly reverted)
  - fix: SHIPPED (doc) -- `SKILL.md:77`, `docs/connector-build-playbook.md:29-34` (recon classifies session type), `:80` (request step)
- [L01-5] `workbench teardown` command to remove a hot-mod
  - fix: NO SHIPPED FIX -- `TODO.md:14` (tracked TODO; not implemented)
- [L01-6] exhaustive matcher check as a committed, data-driven Detent test
  - fix: NO SHIPPED FIX -- the throwaway was deleted; the idea is kept as narrative at `PROGRESS.md:20-21`. Would live in the detent repo, not this skill.
- [L01-7] gateway self-heal / safe-mode (skip one bad schema, not the whole eval)
  - fix: NO SHIPPED FIX -- upstream detent/mngr ask; outside this skill.
- [L01-8] `additional_services` inline schema vs Detent builtin duality (two sources of truth)
  - fix: NO SHIPPED FIX -- upstream investigation; outside this skill.
- [L01-9] blacklist flip-flop (the revert was the mistake)
  - fix: SHIPPED (doc) -- `docs/connector-build-playbook.md:32-34` ("the revert is the easy mistake; re-add it")
- [L01-10] stale credential / bridge died / latchkey bricked (operational)
  - fix: NO SHIPPED FIX -- operational recovery; lessons captured as L01-2/L01-3.

### Entry 02 -- Hugging Face connector: build, seal, refine scopes, upstream

- [L02-1] `deskrun` targeted the wrong home (container `$HOME` vs Mac)
  - fix: SHIPPED -- `bin/deskrun:7-9` (`MINDS_MAC_HOME` -> config file -> `$HOME` fallback chain)
- [L02-2] stale connector template (`ngrok.ts` targets a different latchkey version)
  - fix: SHIPPED (doc) -- `docs/connector-build-playbook.md:56-57` (model on a current in-tree `linear.ts`, not the bundled template)
- [L02-3] bundle-vs-checkout version skew (`getAccount` missing -> login fails after mint)
  - fix: SHIPPED -- `services/huggingface.ts:132-133` (`getAccount` added to compile against v3); documented at `docs/connector-build-playbook.md:164-168`
- [L02-4] self-inflicted gateway outage (killing `mngr latchkey forward`)
  - fix: SHIPPED (doc) -- `docs/connector-build-playbook.md:140` (reload with `restart_minds.sh`, not the process-kill)
- [L02-5] brick-avoidance on the scope swap (revoke-first)
  - fix: SHIPPED (doc) -- `docs/connector-build-playbook.md:143` (revoke-before-schema-swap)
- [L02-6] the HF connector + catalog + patch tools (the worked example)
  - fix: SHIPPED -- `services/huggingface.ts`, `catalog/huggingface.services.json.snippet`, `catalog/huggingface.additional_services.snippet.json`, `tools/patch_bundle_hf.js`, `tools/patch_hf_catalog_schema.py`, `tools/patch_hf_granular.py`
- [L02-F1] generalize the patch tools (`patch_bundle.js <service>`)
  - fix: NO SHIPPED FIX -- per-service copies still live in `tools/` (`patch_ngrok.js`, `patch_bundle_hf.js`). Future improvement.
- [L02-F2] standalone connector smoke test (no human browser login)
  - fix: NO SHIPPED FIX -- future improvement.
- [L02-F3] multi-domain scope schema helper (`pattern`/`enum` on `domain`)
  - fix: SHIPPED -- `catalog/huggingface.additional_services.snippet.json` (`"pattern": "^(huggingface\\.co|router\\.huggingface\\.co)$"`); documented at `docs/connector-build-playbook.md:101`
- [L02-F4] reusable Slack helpers
  - fix: NO SHIPPED FIX -- operational.

### Entry 03 -- OpenRouter connector: full session (build, ship, CI-green, verify)

- [L03-1] the OpenRouter connector itself
  - fix: NO SHIPPED FIX in this skill -- upstreamed to `imbue-ai/latchkey#118`. The workbench ships ngrok + huggingface as worked examples; OpenRouter is intentionally not a third. The *lessons* from building it are shipped (see below).
- [L03-2] headless mint harness (Gmail OTP) -- the biggest iteration-speed unlock
  - fix: NO SHIPPED FIX (as a script) -- documented as a dev-loop accelerator at `docs/connector-build-playbook.md:173`. The harness was a one-off under `data/`, not committed to the skill.
- [L03-3] scope selectors by accessible name (bare `[role="dialog"]` trap)
  - fix: SHIPPED (doc) -- `docs/connector-build-playbook.md:36`, `SKILL.md:65`
- [L03-4] clicks before hydration are no-ops (retry-until-open)
  - fix: SHIPPED (doc) -- `docs/connector-build-playbook.md:49`
- [L03-5] verify against the spec, don't theorize (the scope near-miss)
  - fix: SHIPPED (doc) -- `SKILL.md:70`, the refine-scopes step at `docs/connector-build-playbook.md:62`
- [L03-6] changelog entry named after the branch
  - fix: SHIPPED (doc) -- `docs/connector-build-playbook.md:114`, `SKILL.md:76`
- [L03-7] `deskrun`/zsh gotchas
  - fix: SHIPPED (doc) -- `SKILL.md:96`, `docs/connector-build-playbook.md:184`

### Entry 04 -- HF PR review and scope fixes

- [L04-1] scopes functionally broken -- `read = method:GET` blocks the `HEAD` before download
  - fix: SHIPPED (doc) -- `docs/connector-build-playbook.md:93` (read must include `HEAD`/`OPTIONS`), `SKILL.md:67`. The actual method constraints live in the upstream Detent schema (`detent#23`/`#26`); the workbench's `catalog/huggingface.services.json.snippet` carries the 3-permission structure.
- [L04-2] modeling inconsistency -- `huggingface-inference` domain-only, mislabeled as a scope
  - fix: SHIPPED -- the method constraint (`POST` for inference) lives upstream (Detent); the workbench's snippet carries the 3-permission structure (`catalog/huggingface.services.json.snippet`); documented at `docs/connector-build-playbook.md:99` (method-constrained permissions under one scope)
- [L04-3] catalog is single-scope (one scope per service)
  - fix: SHIPPED (doc) -- `docs/connector-build-playbook.md:90`, `SKILL.md:93`
- [L04-4] latchkey CI red = unformatted `serviceRegistry.ts`
  - fix: SHIPPED (doc) -- `SKILL.md:76` (prettier on every touched file), `docs/connector-build-playbook.md:113`
- [L04-5] mngr `check-changelog` red = wrong filename
  - fix: SHIPPED (doc) -- `docs/connector-build-playbook.md:114` (named after the branch)
- [L04-F1] verify scopes against the real API by construction (a harness)
  - fix: NO SHIPPED FIX -- future improvement; the throwaway was deleted.
- [L04-F2] a post-push CI gate in the agent's own flow
  - fix: NO SHIPPED FIX -- operational habit; not a script.
- [L04-F3] reusable Slack helper + markdown->HTML->tab one-liner
  - fix: NO SHIPPED FIX -- operational.

### Entry 05 -- HF write token and the Detent boundary note

- [L05-1] HF connector mints a WRITE token (a read token cannot back `-write-all`)
  - fix: SHIPPED -- `services/huggingface.ts:35` (`HF_NEW_TOKEN_URL` with `tokenType=write`), `:87` (navigates to it), `:6-9` (docstring explains write token covers read+write+inference); also `:85` adds `page.bringToFront()` (the L05-4 lesson). The worked example now embodies the "token capability must cover every granted scope" lesson at `docs/connector-build-playbook.md:104` / `SKILL.md:71`. (Previously `tokenType=read`; fixed in the same push that adds this file.)
- [L05-2] a Minds restart wipes pending permission requests
  - fix: SHIPPED (doc) -- `docs/connector-build-playbook.md:78`, `:154`, `SKILL.md:88`
- [L05-3] SIP blocks direct bundle writes (osascript into Terminal.app)
  - fix: SHIPPED (doc) -- `SKILL.md:57-64`, `docs/connector-build-playbook.md:146-153`
- [L05-4] `page.bringToFront()` on browser-followup connectors (wrong-tab UX)
  - fix: SHIPPED (doc) -- `SKILL.md:84`, `docs/connector-build-playbook.md:46`
- [L05-5] agent-side credential clear/re-mint (no Connectors UI, no restart)
  - fix: SHIPPED -- `tools/manage_credential.sh` (reads the on-disk `encryption_key`, runs `latchkey auth clear|browser` against the real store)
- [L05-F1] request read scopes upfront for "find a thread" tasks
  - fix: NO SHIPPED FIX -- operational (Slack workflow).
- [L05-F2] latchkey meta-tests raise the hardcoded caps
  - fix: NO SHIPPED FIX -- upstream latchkey test; not in this skill.
- [L05-F3] "verify connector loads + mint dry-run" without a full restart
  - fix: NO SHIPPED FIX -- future improvement.
- [L05-F4] Detent schema materialization is restart-coupled
  - fix: NO SHIPPED FIX -- upstream detent/mngr ask.

### Entry 06 -- DocuSign session-riding connector

- [L06-1] session-riding connector pattern (store cookies, mint short-lived bearer)
  - fix: SHIPPED -- `docs/connector-build-playbook.md:9-22` (the "Two connector patterns" section: mint-and-reveal vs session-riding; `refreshCredentials` null = re-login)
- [L06-2] `refreshCredentials` returning null = "re-login required" (defer silent refresh)
  - fix: SHIPPED -- `docs/connector-build-playbook.md:20`, `:204`; `SKILL.md:115`
- [L06-3] a raw bearer handed to the container bypasses Detent (per-request enforcement)
  - fix: SHIPPED -- `SKILL.md:113`; `docs/connector-build-playbook.md:200-206`
- [L06-4] plain Chrome is blocked; a non-Chrome browser (Fortress/Brave) mints
  - fix: SHIPPED -- `docs/connector-build-playbook.md:207-210`
- [L06-5] `GIT_AUTHOR_NAME`/`GIT_COMMITTER_NAME` env overrides override repo-scoped git config
  - fix: NO SHIPPED FIX -- operational (commit-authorship gotcha); not a connector-build lesson.
- [L06-6] pre-trim prose before review (same lesson as entry 05)
  - fix: SHIPPED -- `docs/connector-build-playbook.md:216` (self-review before replying)
- [L06-7] gateway flapped mid-push (operational)
  - fix: NO SHIPPED FIX -- operational recovery.
- [L06-F1] base-hook for browser-at-refresh in latchkey (future improvement)
  - fix: NO SHIPPED FIX -- upstream latchkey ask.
- [L06-F2] gateway->container mint delegation (future improvement)
  - fix: NO SHIPPED FIX -- upstream design ask.
- [L06-F3] meta-test timeouts (same as entry 05)
  - fix: NO SHIPPED FIX -- upstream latchkey test.

### Entry 07 -- Tailscale connector and isolated-gateway e2e

- [L07-1] data-driven scope coverage regression test (drive Detent's real matcher over the full OpenAPI inventory)
  - fix: SHIPPED -- `SKILL.md:107`; `docs/connector-build-playbook.md:109-116` (step 9 refine-scopes); references entry 07's `tailscaleOpenapiCoverage.test.ts` as the template. The fixture/test itself lives upstream (detent #28), not in this workbench.
- [L07-2] isolated-gateway e2e (throwaway `/tmp/lk-e2e`, not hot-mod)
  - fix: SHIPPED -- `SKILL.md:101`; `docs/connector-build-playbook.md:96-100` (step 8 e2e test: prefer isolated-gateway over hot-mod)
- [L07-3] self-review before replying to review comments
  - fix: SHIPPED -- `docs/connector-build-playbook.md:216`
- [L07-4] `checkApiCredentials` must use a full URL, not a relative path
  - fix: SHIPPED -- `docs/connector-build-playbook.md:211-213`
- [L07-5] granular scopes mapped to the service's own OAuth scope taxonomy (not role hierarchy)
  - fix: SHIPPED -- `docs/connector-build-playbook.md:116-118`
- [L07-6] `getAccount` returns a meaningful identifier (tailnet) -- multi-credential pattern
  - fix: SHIPPED (example) -- `services/huggingface.ts:132-133` (`getAccount` returns null; the tailscale connector (upstream latchkey#123) returns the tailnet). The pattern is documented in the playbook's "Two connector patterns" section.
- [L07-7] OAuth-client vs API-access-token decision (design)
  - fix: NO SHIPPED FIX -- a per-service design decision; the playbook's "Two connector patterns" section covers the two credential shapes, not the OAuth-vs-token choice (which is service-specific).
- [L07-8] recordings blacklist with paper-trail comment
  - fix: SHIPPED (doc) -- `SKILL.md:77` (already from the prior pass)
- [L07-9] `check-changelog` CI gate (mngr-internal)
  - fix: SHIPPED (doc) -- `docs/connector-build-playbook.md:144` (already from the prior pass)
- [L07-10] no `deskrun` doc exists (the fuller process lives in session 195)
  - fix: SHIPPED -- `docs/connector-build-playbook.md` IS the doc (this playbook, built from session 195 + the journals).
- [L07-F1] exhaustive matcher check for every service (not just tailscale)
  - fix: NO SHIPPED FIX -- upstream detent ask; the tailscale test is the template, the pattern is documented.
- [L07-F2] gateway self-heal / safe-mode (same as entry 01)
  - fix: NO SHIPPED FIX -- upstream detent/mngr ask.
- [L07-F3] `workbench teardown` command (same as entry 01)
  - fix: NO SHIPPED FIX -- `TODO.md:14` (tracked TODO).
- [L07-F4] capture dashboard raw network calls to prove it uses the public API
  - fix: NO SHIPPED FIX -- low-priority investigation.
- [L07-F5] OAuth-client connector follow-up (`tailscale-oauth`)
  - fix: NO SHIPPED FIX -- future connector; not in this workbench.

---

## Summary of gaps found by this pass

- **L05-1 (latchkey): `services/huggingface.ts` still mints a read token.** The
  playbook teaches "mint a write token so it backs every granted scope," but the
  worked example mints a read token. Fixed by switching `tokenType=read` ->
  `tokenType=write` and `HF_NEW_READ_TOKEN_URL` -> `HF_NEW_TOKEN_URL` (and adding
  `page.bringToFront()` for the L05-4 lesson) in the same push that adds this file.

- **Entries 06 + 07 (latchkey): 9 new lessons missing from the skill.** All 9
  folded in this push: isolated-gateway e2e (`SKILL.md:101`), data-driven scope
  coverage test (`SKILL.md:107`), bearer-out breaks Detent (`SKILL.md:113`),
  refreshCredentials null (`SKILL.md:115`), session-riding pattern
  (`connector-build-playbook.md:9-22`), Chrome-blocked/Fortress-mints
  (`:207`), checkApiCredentials full URL (`:211`), self-review before replying
  (`:216`), OAuth scope taxonomy (`:116`).

All other symptoms either have a shipped artifact fix (code, config, or shipped
instruction) recorded above, or are deliberate non-fixes (upstream asks,
future-improvement TODOs, or operational lessons outside this inspiration's
scope). The foreman-repo pass lives in
`glm-pi-foreman/docs/build-journal/SYMPTOM-FIX-MAP.md`.
