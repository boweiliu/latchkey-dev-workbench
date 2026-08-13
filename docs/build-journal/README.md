# Build journal

This directory is the working history behind the **Latchkey Dev Workbench**
inspiration. It collects the author's session write-ups from the work that
built the ngrok worked example and then extended the workbench to Hugging Face
and OpenRouter, kept verbatim so the hard-won gotchas survive alongside the
toolkit.

These are case studies, not part of the inspiration's boot contract. The
inspiration's manifest is
[`inspiration-latchkey-dev-workbench.md`](../../inspiration-latchkey-dev-workbench.md);
nothing here is loaded at adopt time, and the toolkit itself lives at
[`.agents/skills/latchkey-dev-workbench/`](../../.agents/skills/latchkey-dev-workbench/).
Read these to understand *why* the included tooling and the ngrok example look
the way they do, and to skip the traps the author already hit.

Each entry follows the same structure: original ask and how it evolved, the
questions asked and answered, the thought process, what was observed, the
hiccups, what's next, reflections, and future improvements.

## Entries

1. **[01 — ngrok connector: scope verification, trim, and upstreaming](01-ngrok-connector-scope-verify-and-trim.md)**
   Proving the Detent scopes against ngrok's real OpenAPI surface (all 241
   operations) by driving Detent's real matcher, then trimming 7 scopes down
   to the 5 that are actually useful at runtime. The `/ssh_credentials` resource
   (name contains "credentials") is correctly rejected by the
   `^`-anchored path. Includes the expensive lesson: a live hot-mod of a
   running gateway is a debt that compounds when you walk away — the durable
   uv-cache patch reprovisioned into a broken schema days later and bricked
   *every* permission check with `references unknown schema "#/$defs/ngrok-api"`.

2. **[02 — Hugging Face connector: build, seal, refine scopes, upstream](02-huggingface-connector-build.md)**
   Building HF as a first-class latchkey service from scratch: browser-recon,
   the Playwright mint of a sealed read token, granular read/write/inference
   scopes, a live hot-mod, and three upstream PRs. Two outages: a
   self-inflicted one from killing `mngr latchkey forward` (the reliable
   reload is `restart_minds.sh`, not the process-kill) and a laptop-sleep
   outage that looked identical to a crash. The expensive bug was a bundle
   vs. checkout **version skew** (bundle 3.3.0 calls `getAccount`, checkout
   2.20.2 doesn't) — login failed *after* the token minted.

3. **[03 — OpenRouter connector: full session (build, ship, CI-green, verify)](03-openrouter-connector-full-session.md)**
   The whole arc of the OpenRouter connector. Key differences from HF: the key
   is revealed as **plain text** in the dialog (not an `<input>`), and a bare
   `[role="dialog"]` selector is a trap — it matches a hidden verify-email
   dialog, the real dialog, *and* a 1Password modal, so strict mode hangs; scope
   every locator by accessible name. The single biggest unlock was a headless
   mint harness that pulls the email OTP from Gmail via the latchkey connector
   — a multi-minute human-in-the-loop loop became a ~30s self-serve one. Also
   the recurring scope near-miss: theorizing an API is "OpenAI-shaped" instead
   of enumerating its real operations.

4. **[04 — HF PR review and scope fixes](04-hf-pr-review-and-scope-fixes.md)**
   A real PR review that found the HF scopes were **functionally broken**: a
   read-only grant couldn't download models, because `huggingface_hub` issues a
   `HEAD resolve` before every download and `read = method:GET` blocked it.
   Redesigned to one `huggingface-api` scope with three method-constrained
   permissions. Also: after opening PRs, **check the CI runs** — running tests
   locally is not the same; and the mngr-internal changelog entry must be named
   after the branch, not the feature.

5. **[05 — HF write token and the Detent boundary note](05-hf-write-token-and-detent-note.md)**
   Switching the HF connector from a read-only token to a classic `write` token
   (read+write+inference) so it backs every Detent HF scope, across the
   latchkey and detent repos. The e2e loop mints a real write-capable token on
   the operator's account and creates/deletes a real repo. Includes two helper
   scripts (`hf_patch_and_restart.sh`, `hf_e2e_verify.sh`). Prose-discipline
   lesson: before declaring a revision satisfies a comment, open the file at
   the changed lines and read them cold.

## Themes across the entries

- **Verify, never theorize.** Drive Detent's matcher over the service's real
  OpenAPI spec; probe the live API rather than re-reading the code. Every
  scope bug in this journal came from assuming an API "looks RESTful" /
  "OpenAI-shaped" instead of enumerating its real operations.
- **The schema must exist before the grant.** Granting a scope whose Detent
  schema is missing (or unresolvable after reprovision drift) bricks the
  *entire* permission set, not just that scope. The brick is global.
- **A live hot-mod is a debt that compounds when you walk away.** The
  durable uv-cache patch is exactly what reprovisioned into a broken state
  and locked the agent out days later. Prove a connector live, then remove the
  patch; the durable path is the three upstream PRs (Detent -> latchkey ->
  mngr-internal, in that dependency order).
- **Detect bundle-vs-checkout version skew up front.** The bundle's latchkey
  version can differ from the compile checkout's; diff the bundle's base class
  for `this.service.<method>` calls before modeling a connector, or the login
  fails after the mint with `this.service.getAccount is not a function`.
- **Never use a bare `[role="dialog"]` / generic role selector** on a page that
  can host a password-manager modal or a leftover dialog; scope every locator
  by accessible name.
- **After opening PRs, check the CI runs.** And run repo-specific checks
  (prettier, changelog-named-after-branch) locally before pushing.
