# 211 — OpenRouter latchkey connector: full session (build → ship → CI-green → verify)

The complete write-up of the OpenRouter connector session. A mid-session cut of the
build lives in `210-openrouter-latchkey-connector`; this one is the whole arc,
including the tail that 210 predates: pushing that summary, checking CI to green,
fixing the changelog gate, and closing an end-to-end verification gap the operator
caught. Second latchkey connector after 209 (Hugging Face); same
hot-mod-the-Mac-from-a-container loop.

---

## 1. Original Ask & Evolution

- **Starting ask:** "read your docs on how to set up and test e2e and create code and
  PRs for a new latchkey connector to another service. then i'll tell you which
  service." The e2e target was named up front: a `POST` to the v1 chat-completions API.
- **Service:** OpenRouter, revealed the next turn, with demo credentials
  (`bowei@imbue.com` + a password) explicitly scoped to **local browser recon only** —
  never committed, never part of the token flow.
- **Three flags requested before building:** (a) note that a demo user/password smooths
  connector-automation dev, and that this was *missing* from the input docs; (b) confirm
  the real token flow (browser login mints the key server-side; the password never
  touches the connector) *is* documented; (c) treat the creds as a dev aid only.
- **"Do you have the local-CDP-with-user/pass section?"** The operator pressed on whether
  my input docs contained the step for driving a local browser with the creds. They did
  **not** — confirmed by grepping the workbench and reading the 209 summary, where the
  same gap had been caught. That browser-recon step became explicit.
- **Evolution:** read docs + fresh notes dir → recon → connector + scopes + catalog →
  hot-mod + e2e → (mint kept failing) build a headless harness to debug → (operator
  warning) verify scopes against the real API → three PRs + Slack → session summary →
  **wait for CI green** → fix the changelog gate → **close the e2e verification gap** →
  this final write-up.

---

## 2. Questions Asked & Answered

| Who | Question | Answer | How discovered |
|---|---|---|---|
| Operator → me | "Do you have the local-CDP-with-user/pass section?" | No — absent from the input docs; it's the browser-recon step. | grepped the workbench + read 209 |
| Me → operator | Which service? | OpenRouter; e2e = POST v1 chat completions. | asked directly |
| Operator → me | "Can you use the gmail latchkey connector to fetch the 6-digit sign-in code yourself?" | Yes — requested `google-gmail-read-messages`, queried `from:openrouter newer_than:1h`, read the code from the newest message. No hand-off. | probed the Gmail API |
| Operator → me | "Another agent hit this [scope] error… don't fall into the same trap." | Drove Detent's matcher over OpenRouter's real OpenAPI spec (72 paths): no side-effecting GETs, and the inference surface is far larger than chat/completions — fixed. | fetched openapi.json |
| Operator → me | "Did you test e2e after your latest change?" | The latest change (changelog rename) had no runtime surface; but I'd only live-tested chat/completions after widening the inference scope — so I then live-tested `POST /embeddings` (200). | ran it live |
| Me (internal) | Why does the mint time out on `[role="dialog"]`? | The bare selector matches 3 dialogs — a hidden verify-email dialog, the real one, AND a 1Password modal. Strict mode can't resolve it. Scope by name. | headless harness dump |
| Me (internal) | Why does mngr-internal CI's `check-changelog` fail? | The gate requires the entry file be named after the branch (`<branch>.md`); I'd named it `add-openrouter-service.md`. | read the checker script |
| Me (internal) | Is `build-minds-snapshot` my fault? | No — the log shows OpenRouter registers fine; the failure is a pre-existing template drift (`Unknown fields in agent_types.claude: ['append_system_prompt']`). | read the CI log |

---

## 3. Thought Process & What I Did (think → do → observe → conclude)

Chronological, as I worked it:

1. **Read docs, make a fresh notes dir.** Read the workbench PROGRESS journal and both
   latchkey skills; created `openrouter/NOTES.md` with no existing docs edited. Flagged
   the user/pass-smooths-dev gap and confirmed the token flow is documented.
2. **Probe the bridge** — `deskrun` answered in ~1s. (Should have been step 1; the
   operator flagged it, now a process lesson.)
3. **Map topology.** latchkey checkout `3.4.1`, app bundle `3.3.0` (both v3, so
   `getAccount` required — no skew this time), node 26 + tmux present, `gh` authed, all
   three repos still on their HF branches → branch OpenRouter off `origin/main`.
4. **Recon.** A headless Playwright login hit an email OTP (new-device); a headless
   browser can't read it, so I pivoted to the shared browser fleet and **fetched the OTP
   from Gmail via the latchkey connector**. Captured the mint selectors — the key
   difference from HF: OpenRouter reveals the key as **plain text** in the dialog, not in
   an `<input>`. Deleted the recon key.
5. **Write the connector.** Mirrored the HF bearer connector (single `Authorization:
   Bearer sk-or-v1-…`, single domain, `getAccount` → null). Registered it; lint + tsc +
   build green.
6. **Scopes + catalog.** Detent `openrouter-api` (+ read/write/inference) with matcher
   tests; mngr `additional_services.json` entry + changelog.
7. **Hot-mod the live gateway.** Patched catalog + schema into every uv-cache copy; wrote
   the compiled connector into the SIP-protected bundle from the Terminal-backed
   `minds-deploy` tmux; restarted; polled to recovery. **Verified the enforcement schema
   materialized before approving** — brick-avoidance.
8. **First two live logins → mint timed out** on `[role="dialog"]`. A hydration retry
   didn't fix it.
9. **Built a headless repro harness** (`mint_harness.py`): local Fortress Chromium runs
   the whole login+mint in the container, pulling the OTP from Gmail — no user, no
   gateway. It surfaced the real error: `[role="dialog"]` matches **three** elements
   (hidden verify-email dialog + real dialog + 1Password modal). Scoped to the named
   dialog; the harness then minted cleanly in ~30s.
10. **Final live login → success.** Sealed key; `POST /chat/completions` → 200; read →
    200; non-inference write → 403; direct call → 401; zero `sk-or` in container env.
11. **Scope near-miss, caught by the operator.** I'd written inference as
    `chat/completions|completions` (OpenAI shape). Drove the OpenAPI spec: no bare
    `/completions`, and the real surface is `chat/completions`, `messages`, `responses`,
    `embeddings`, `rerank`, `images`, `videos`, `audio/{speech,transcriptions}`. Fixed the
    pattern + tests; re-patched live; re-verified (chat 200, write 403).
12. **Upstream + communicate.** Opened Detent #24, latchkey #118, mngr-internal #326;
    cross-linked with merge order; posted to `#project-latchkey` tagging hynek, per the
    reusable writing guidelines.
13. **Session summary (210).** Wrote and pushed the mid-session write-up to bowei-thoughts.
14. **Wait for CI green.** Detent #24 and latchkey #118 went green. mngr-internal #326 had
    two reds: `check-changelog` (mine — entry must be named after the branch; renamed
    `add-openrouter-service.md` → `add-openrouter-catalog.md`, now passing) and
    `build-minds-snapshot` (pre-existing `append_system_prompt` template drift, not mine).
15. **Close the e2e gap.** Operator asked if I re-tested e2e after the latest change. The
    changelog rename has no runtime surface, but I'd only live-tested chat/completions
    after the scope widening — so I live-tested `POST /embeddings` → 200 (a newly-covered
    path), with chat 200 and non-inference write 403 as controls.
16. **This write-up.** Fresh-cloned bowei-thoughts and wrote the full session summary.

---

## 4. Results Observed

**The connector, live and verified through the real gateway:**

| Check | Result |
|---|---|
| Browser login mints an API key, sealed | ✅ credential `authorizationBearer, valid`; `0` `sk-or` in container env |
| `POST /api/v1/chat/completions` (inference) | ✅ 200, content `pong` (~$0.0000027) |
| `POST /api/v1/embeddings` (inference, newly covered) | ✅ 200, real embedding vector |
| `GET /api/v1/key` (read) | ✅ 200 |
| `POST /api/v1/keys` (non-inference write, not granted) | ✅ 403 at the gateway |
| Same completion **direct** (no gateway) | 401 — proves the funnel |

**Three PRs, CI status:**

| Repo | PR | CI | Contents |
|---|---|---|---|
| imbue-ai/detent | #24 | ✅ green | scopes (spec-verified) + tests + regenerated docs — 368 tests |
| imbue-ai/latchkey | #118 | ✅ green | connector + registry + SKILL.md + recordings blacklist — 758 tests |
| imbue-ai/mngr-internal | #326 | changelog ✅; `build-minds-snapshot` ❌ pre-existing | catalog entry + changelog |

**Slack:** posted to `#project-latchkey` (`C0AAG6UQU57`), tagging hynek (`U050P057ZB4`).

**Committed to the workbench:** connector, Detent scope schema, catalog snippet +
changelog, the durable catalog/schema and bundle hot-mod tools, and a `NOTES.md` worklog.

---

## 5. Hiccups

- **Login email-OTP on every fresh browser.** New-device 6-digit code; a headless browser
  can't read it → fetched from Gmail via the latchkey connector (no user hand-off).
- **Mint timed out twice on an ambiguous `[role="dialog"]`.** The bare role selector
  matched a 1Password modal and a hidden leftover verify-email dialog; strict mode hung.
  Scope every locator by accessible name.
- **Click-before-hydration no-op** on the heavy client-rendered keys table; retry-until-open.
- **Scope near-miss (the important one).** Theorized the inference scope; the real spec has
  no bare `/completions` and a far larger inference surface. Caught only by the operator's
  warning. Verify against the spec; never theorize.
- **Changelog gate failure.** The entry file must be named after the branch, not the
  feature. Renamed to `add-openrouter-catalog.md`.
- **`build-minds-snapshot` red, but not mine.** A DEFAULT_WORKSPACE_TEMPLATE drift
  (`Unknown fields in agent_types.claude: ['append_system_prompt']`) that fails any current
  mngr-internal PR; OpenRouter registered fine in that same build.
- **deskrun/zsh gotchas.** zsh eats `=word` (`unsetopt equals`); unquoted parens in `echo`
  trigger a glob error; `node`/`tmux` need `zsh -lc` or absolute paths; the workspace hook
  blocks `head`/`tail` (even inside uploaded scripts) and deskrun times out after ~60s so
  long CI poll-loops must be split.
- **`generatedBuiltinSchemas.ts` is gitignored** in Detent — regenerated, not committed.

---

## 6. What's Next

- **Land the chain:** Detent #24 → cut a Detent release → bump latchkey's detent dep +
  merge #118 → cut a Latchkey release → the mngr-internal roll-up ships it.
- **`build-minds-snapshot`:** needs the `append_system_prompt` template/agent-config drift
  resolved by its owner (a template bump or adding the field to the allowed
  `agent_types.claude` set) — out of scope for a catalog PR, but it blocks that PR's snapshot
  job.
- **Per-endpoint inference coverage:** live-verified `chat/completions` and `embeddings`; the
  rest (`messages`, `responses`, `rerank`, `images`, `videos`, `audio/*`) are covered by the
  Detent matcher tests, not a live call each.
- **The live gateway is on the dev hot-mod** (bundle + uv-cache patches); it reverts on the
  next app update. The three PRs are the durable path.

---

## 7. Reflections & Gut Feelings

- **The headless mint harness was the single biggest unlock.** Local browser + a
  Gmail-fetched OTP turned a multi-minute human-in-the-loop iteration (approve, sign in,
  ~30s restart) into a ~30s self-serve loop — and it surfaced the real strict-mode error the
  gateway only showed as a generic timeout. Build it FIRST next time.
- **The scope near-miss is the lesson to keep.** Same trap as 209: I scoped by assuming the
  API "looks OpenAI-shaped" instead of enumerating its real operations. The operator's
  mid-run warning is the only reason it didn't ship. Drive the matcher over the real spec.
- **Fetching the OTP from Gmail to avoid blocking the user** was the right instinct: the code
  is in the user's inbox, I have a read-only Gmail connector, so read it rather than stall.
- **Being honest about the e2e gap paid off.** When asked "did you test e2e after your latest
  change," the truthful answer distinguished a no-runtime-surface change (changelog) from an
  under-tested one (the widened inference scope), and closing it with a live embeddings call
  was a two-minute confirmation, not a hand-wave.
- **Both big time sinks were environment/verification, not connector logic.** The TypeScript
  was ~160 lines modeled on HF and essentially right; the cost was the dialog ambiguity and
  the scope verification.

---

## 8. Future Improvements (TODOs to investigate)

- **Promote the headless mint+Gmail-OTP harness into the workbench** as a first-class,
  parameterized dev loop (`<service> login+mint, headless, OTP-via-Gmail`). It's the biggest
  iteration-speed win here and is currently a one-off script under `data/`.
- **Never use a bare `[role="dialog"]` / generic role selector** on pages that can host
  password-manager or leftover modals — always scope by accessible name. Document it in the
  workbench connector-writing guidance.
- **Generalize the per-service patch tools.** `patch_bundle_openrouter.js` /
  `patch_openrouter_catalog_schema.py` are the third hand-written copy of the same logic
  (after ngrok and HF). A parameterized `patch_bundle.js <service> <symbol>` +
  `patch_catalog.py <service> <entry>` would end the copy-paste.
- **Bake spec-verification into the scope step.** A helper that fetches a service's OpenAPI
  spec and reports side-effecting GETs / read-only POSTs / the full credit-consuming path set
  would make "verify, don't theorize" the default rather than a thing you remember.
- **Name changelog entries after the branch by default.** The mngr-internal gate expects
  `<branch>.md`; the workbench's catalog step should generate the entry with the branch name
  so the gate passes first try.
- **Detect bundle-vs-checkout version skew up front** (still relevant from 209): diff the
  bundle base for `this.service.<method>` calls before the first approval.
