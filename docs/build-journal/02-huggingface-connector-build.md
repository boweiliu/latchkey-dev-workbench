# 209 — Hugging Face latchkey connector: build, seal, refine scopes, upstream

Building Hugging Face as a first-class latchkey service from scratch, driven from
a Minds agent that hot-mods the desktop app on the Mac. Started from the
latchkey-dev-workbench inspiration, ended with three upstream PRs, a live gateway
enforcing granular scopes, and a Slack status post — with two self-inflicted-ish
gateway outages along the way.

---

## 1. Original Ask & Evolution

- **Starting ask:** "We're going to use this inspiration
  (`boweiliu/latchkey-dev-workbench`) to develop some new latchkey connectors.
  Import it." (Operator authored the inspiration, so trust was pre-granted.)
- **First concrete target:** a **Hugging Face** connector. The stated goal
  crystallized over a few turns: *mint a read-only HF token that stays sealed in
  the latchkey gateway, so API requests can be funneled through it* — the
  motivating workload being a `whisperx` diarization call that downloads the
  gated `pyannote/speaker-diarization-3.0` model.
- **Key correction mid-conversation:** the operator first said "the agent is the
  only requester" (token sealed), then gave the `whisperx` snippet, which reads
  `os.environ['HF_TOKEN']` directly — a contradiction. Resolved by confirming the
  gateway stays the sole token holder and the local library is pointed at the
  gateway (or the token is a placeholder the gateway overrides); the `whisperx`
  bit was "just the code that actually runs," not a literal transport spec.
- **Evolution of scope:**
  1. Import the inspiration → get the Mac bridge working.
  2. Build the connector, mint a sealed read-only token, verify end-to-end.
  3. **Refine** the single coarse scope into granular
     `read` / `write` / `inference` (operator asked "shouldn't we refine the
     scope names?").
  4. **Live-flip** the gateway to the granular scopes and prove enforcement.
  5. **Upstream:** three PRs (Detent, latchkey, mngr-internal), audited against
     the ngrok precedent and each repo's contribution rules.
  6. Draft + send a Slack status update; distill the operator's wording review
     into a reusable guidelines doc.

---

## 2. Questions Asked & Answered

| Who | Question | Answer | How discovered |
|---|---|---|---|
| Me → operator | Read-only or write? Hub-only or +inference? | Read-only; both domains (Hub + Inference router) | asked directly |
| Me → operator | Sealed token vs. handed-out token? | Sealed — gateway is the only holder | asked; then reconciled against the `whisperx` snippet |
| Operator → me | "Are you missing a step re: locally driving a browser to determine the HF web flow?" | Yes — added an explicit browser-recon step before writing selectors | operator caught a real gap in my plan |
| Operator → me | "Do you know which steps run here vs. the OSX bridge?" | Produced a table; gateway is the Mac's Minds.app, container reaches it via a forwarded `127.0.0.1:1989` | traced env + config paths |
| Me (internal) | Can `huggingface_hub` be routed through the gateway with the token sealed? | Yes in principle — the gateway is a reverse proxy any client can use with the password header; injects creds for matched domains | probed the local gateway directly |
| Operator → me | "Should we refine the scope names? there's just 'all'?" | Keep method-based read/write (correct for a RESTful API), **add** an `inference` scope to isolate the paid router; skip per-resource scopes | reasoned from the ngrok precedent |
| Operator → me | "Why was mngr-internal#281 also necessary?" | It's the **release + roll-up**: bumps Minds + `mngr_latchkey` to a released Latchkey and regenerates `services.json` — the step that actually ships it | fetched the PR via `gh` |
| Operator → me | "Can you revoke your own perms, for next time?" | Yes — no API endpoint, but the grant lives in a permissions JSON on the Mac I can edit via the bridge (backup + validate). Filed as a TODO | inspected the permissions file |
| Operator → me | "Where should usage instructions live (a few key places)?" | Connector `info` field (code) + both PR descriptions + the catalog permission descriptions | mapped the discoverable surfaces |

---

## 3. Thought Process & What I Did (think → do → observe → conclude)

Chronological, as I worked it:

1. **Import the inspiration.** Tried a straight git merge → 200+ add/add
   conflicts (the inspiration is a whole-workspace snapshot on a different base).
   Concluded: don't merge; `comm -23` the file lists and cherry-pick only the
   **19 files unique to the inspiration** (the skill dir + manifest + thumbnail).
   Clean.
2. **Stand up the Mac bridge.** Requested a file-sharing WRITE grant to
   `~/tmp/minds_data`; the launchd bridge was already installed from prior runs
   and answered a `deskrun` probe in ~1s. Fixed one real bug: `deskrun` built the
   Mac path from the *container's* `$HOME`; generalized it to resolve
   `MINDS_MAC_HOME` / a config file / `$HOME`.
3. **Plan, then recon.** Wrote the connector plan; the operator flagged I'd
   skipped browser recon. Drove the agentic-browser-fleet through HF login →
   `settings/tokens/new?tokenType=read` → captured every selector and the
   one-time reveal `<dialog>`.
4. **Write the connector.** Read latchkey's base classes; discovered the
   workbench's `ngrok.ts` template targeted a *different* latchkey version than
   the local checkout, so I modeled on the checkout's live `linear.ts`. Wrote
   `huggingface.ts` (bearer injection, Playwright mint, scrape reveal), wired it
   into the registry, typechecked + built on the Mac.
5. **Catalog + enforcement schema.** Added a catalog entry and an inline Detent
   scope schema (`additional_services.json`, multi-domain via `pattern`), patched
   durably into every uv-cache copy so a restart reprovisions them.
6. **Hot-mod the live gateway.** Bundle is App-Management-protected → wrote it
   from a Terminal-backed tmux session (which inherits the grant). Restarted
   Minds; catalog + schema + connector all materialized.
7. **First approval → failure.** The browser login minted the token but then
   threw `this.service.getAccount is not a function`. Root cause: the **bundle is
   latchkey 3.3.0**, the compile checkout is **2.20.2** — v3's base calls
   `getAccount`. Added the method (no `override`, to still compile against v2),
   rebuilt, re-patched.
8. **Verify e2e.** Approval → sealed read token → `whoami-v2` 200 (`role: read`),
   gated model reachable through the gateway (401 direct), token absent from the
   container env.
9. **Refine scopes.** Split the coarse permission into `huggingface-read` (GET),
   `huggingface-write` (writes), `huggingface-inference` (router domain).
10. **Live-flip (carefully).** Revoke-first (operator disconnected in the app to
    avoid a dangling-grant brick) → swapped the schema → reliable full restart →
    re-granted `read` → proved GET 200 / POST 403. Later granted `inference` →
    real chat completion from the router.
11. **Upstream.** Opened Detent #23 (scopes + tests + regenerated docs), Latchkey
    #117 (connector), and a draft mngr-internal #324 (catalog). Audited each
    against ngrok's merged PRs and `AGENTS.md`; fixed gaps (SKILL.md listing,
    recordings-test blacklist, locale-independent selector).
12. **Communicate.** Drafted a Slack status message; iterated three passes on the
    operator's wording review; posted to `#project-latchkey` tagging hynek.

---

## 4. Results Observed

**The connector, live and verified:**

| Check | Result |
|---|---|
| Browser login mints read token, sealed | ✅ token never in container env (`0` hf_ hits) |
| `GET /api/whoami-v2` | ✅ 200, `auth.accessToken.role: read` |
| Gated `pyannote/speaker-diarization-3.0` metadata (through gateway) | ✅ 200 |
| Same call **direct** (no gateway) | 401 — proves the funnel |
| `read` grant: `POST /api/repos/create` | ✅ 403 blocked at the gateway |
| `inference` grant: `POST router.huggingface.co/v1/chat/completions` | ✅ 200, real completion ("Hello", ~$0.0000004) |

**Three PRs opened:**

| Repo | PR | State | Contents |
|---|---|---|---|
| imbue-ai/detent | #23 | open | `huggingface.json` scopes (api/read/write/inference), tests, regenerated docs — 368 tests pass |
| imbue-ai/latchkey | #117 | open | connector + registry + SKILL.md + recordings blacklist — lint/typecheck/758 tests pass |
| imbue-ai/mngr-internal | #324 | **draft** | catalog entry in `additional_services.json` |

**Slack:** posted to `#project-latchkey` (`C0AAG6UQU57`), tagging hynek
(`U050P057ZB4`).

**Committed to the workbench:** the connector, catalog/schema snippets, the
granular-patch and bundle-patch tools, a `PROGRESS.md` learnings section, a
work-log doc, a self-revoke TODO, and a reusable status-update writing-guidelines
doc.

---

## 5. Hiccups

- **200+ merge conflicts on import.** The inspiration is a whole-workspace
  snapshot; a straight merge collides on nearly every shared file. Fix:
  cherry-pick only the 19 unique files.
- **`deskrun` targeted the wrong home.** Built the Mac path from the container's
  `$HOME` (`/home/user`) vs the Mac's `/Users/bowei`. Fixed with a
  `MINDS_MAC_HOME` resolution chain.
- **Stale connector template.** The workbench's `ngrok.ts` was written for a
  different latchkey version; modeling on it would have failed. Switched to the
  live `linear.ts`.
- **Version skew (the expensive one).** Bundle = latchkey **3.3.0**, checkout =
  **2.20.2**; v3's base calls `getAccount`, which a v2-modeled connector lacks →
  login failed *after* the token minted. Added `getAccount`.
- **Self-inflicted gateway outage.** Killed `mngr latchkey forward` to reload
  without an app blink, trusting a PROGRESS note that it "auto-respawns." It did —
  but took ~3–4 minutes, during which `latchkey`, `deskrun`, and file-sharing
  were all down. Nearly over-escalated after a 90s poll; the right move was
  patience. **The reliable reload is `restart_minds.sh`, not the process-kill.**
- **Second outage was the laptop sleeping** — cut the tunnel; looked identical to
  a crash. Cleared up when the operator woke the machine. (I'd wrongly guessed
  "flaky forward.")
- **Brick-avoidance on the scope swap.** Changing the live schema under the broad
  `any` grant risked dangling → bricking the whole permission set. Handled with
  revoke-first ordering.
- **mngr push rejected.** `imbue-ai/mngr` blocks branch creation (rule) and
  `boweiliu/mngr` isn't a real fork; the catalog PR belongs on
  **`imbue-ai/mngr-internal`** (like ngrok's #235). Cloned that and pushed there.
- **`users.lookupByEmail` denied** (`not_allowed_token_type`) — fell back to
  paginating `users.list` to resolve hynek; the channel was on page 16 of
  `conversations.list` (needed URL-encoded cursors).

---

## 6. What's Next

- **Land the chain:** Detent #23 → cut a Detent release → bump latchkey's detent
  dep + merge #117 → cut a Latchkey release → the mngr-internal roll-up ships it.
- **Finish the mngr-internal catalog PR (#324)** out of draft once the upstream
  order is agreed.
- **Stage the latchkey `@imbue-ai/detent` dependency bump** ourselves once Detent
  releases (blocked on the release existing).
- **Add agent self-revoke** of its own latchkey grants (edit the on-disk
  permissions JSON via the bridge) so schema swaps don't gate on the operator —
  filed as `TODO.md` in the workbench.
- **Optionally** widen the live grant to `inference`/`write`, or leave it
  read-only until the real release ships.

---

## 7. Reflections & Gut Feelings

- The workbench genuinely works — going from "import an inspiration" to a live,
  enforced, upstreamed connector in one session is a strong signal. The
  hot-mod-the-desktop-from-a-container loop is wild but effective.
- The two things that cost the most time were both **version/infra skew**, not
  the connector logic: the v2/v3 `getAccount` gap and the gateway
  reload/outage dance. The actual TypeScript was ~150 lines modeled on Linear and
  basically worked first try.
- I was too eager killing the gateway to avoid a UI blink — that impulse to
  optimize the happy path caused a real outage. The boring reliable path
  (`restart_minds.sh`) would've been faster overall. Lesson logged.
- The operator's wording review was sharp and worth crystallizing: a status post
  to peers should assume shared context, say *why* in a clause, link everything,
  stage the whole chain first, and sign off — nothing more.
- Satisfying to end with the granular scopes actually *enforcing* live (POST 403,
  inference 200) rather than just "tests pass."

---

## 8. Future Improvements (TODOs to investigate)

- **Generalize the workbench's connector tooling.** `patch_ngrok.js` /
  `patch_catalog_uv_cache.sh` are ngrok-hardcoded; every connector reimplements
  them. A parameterized `patch_bundle.js <service> <symbol>` +
  `patch_catalog.py <service> <entry>` would remove copy-paste. (I hand-wrote
  `patch_bundle_hf.js` / `patch_hf_*.py` this session — those should be folded
  into a generic tool.)
- **Detect bundle-vs-checkout version skew up front.** A quick step that diffs
  the bundle's `dist/src/services/core/base.js` for `this.service.<method>` calls
  vs. the checkout base would have caught `getAccount` before a failed approval.
  Worth baking into the workbench playbook.
- **A standalone connector smoke test that avoids the human browser login** —
  something that exercises URL-match + injection + `getAccount` without a live
  mint, to shorten the iterate loop (right now every attempt needs an approval).
- **Reconsider the gateway reload primitive.** Instead of full app restart *or*
  the flaky forward-kill, investigate whether there's a supported "reload
  extensions / respawn gateway" path that's fast *and* reliable.
- **Multi-domain scope schema helper.** Confirmed a `pattern`/`enum` on `domain`
  works; the workbench should document it (ngrok only ever showed single-domain
  `const`).
- **Slack helpers.** `conversations.list` pagination + `users.list` name lookup
  is fiddly; a tiny reusable "resolve channel + user by name" helper would save
  time next time a session ends with a Slack post.
