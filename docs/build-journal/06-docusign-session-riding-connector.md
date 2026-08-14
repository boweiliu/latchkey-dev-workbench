---
source_repo: boweiliu/bowei-thoughts
source_path: working-sessions/237-docusign-connector-session-summary/session.md
pulled: verbatim
modifications: none
---

# Session 237 — DocuSign latchkey connector: full session summary

The definitive summary of the DocuSign connector session (build → e2e → three PRs →
design deep-dive → review round → Slack). An earlier interim reflection lives at
`working-sessions/236-*`; this doc is the canonical write-up in the standard format and
carries the helper scripts.

- **latchkey PR:** https://github.com/imbue-ai/latchkey/pull/122 — the connector
- **detent PR:** https://github.com/imbue-ai/detent/pull/27 — the `docusign-api` schema
- **mngr-internal PR (draft):** https://github.com/imbue-ai/mngr-internal/pull/371 — catalog
- **Slack notify:** `#project-latchkey` (`C0AAG6UQU57`), ts `1786693685.053129`

---

## 1. Original Ask & Evolution

**Starting ask:** understand latchkey connectors, then plan and build a **DocuSign**
connector so an agent can "send out contracts via DocuSign and ask for them to be
signed."

**How it evolved:**
1. Researched auth. Rejected the OAuth **integration-key** path — it needs a DocuSign
   developer account + **go-live** review, gated behind payment/procedure, and shows a
   third-party consent screen. Operator: "keep working a non-oauth-go-live approach as
   long as we can."
2. Chose **session-riding** (Track B): store the user's web-session cookies, mint the
   short-lived (8h) bearer from them — modeled on the Slack connector.
3. Built the connector, proved it end-to-end on the live Minds gateway (sent a real
   envelope).
4. Opened the three upstream PRs; pushed via the latchkey git proxy.
5. Long design discussion about the **30-day refresh** (the hard part): Brave vs
   Fortress, where the mint code can live, and the discovery that handing the container
   the bearer breaks Detent access control. Landed on: ship the **8-hour unit now**,
   defer silent 30-day behind `refreshCredentials` returning null.
6. Operator's **first review round** — 5 inline comments — all addressed.
7. Notified the reviewer on Slack.

## 2. Questions Asked & Answered

| # | Who | Question | Answer / action | Discovery |
|---|-----|----------|-----------------|-----------|
| 1 | operator | "so we minted an integration key but can't use it? try it anyways" | Prod forbids IK creation via old UI, but the new Dev Console mints one from a prod login — demo-only until go-live. Confirmed by trying it. | live browser + Dev Console |
| 2 | operator | support 8h for latchkey-only but 30-day with Fortress in Minds? | Yes in principle: connector degrades to 8h re-login without a stealth browser, 30-day with one. Built both sides. | connector design + live test |
| 3 | operator | "why not the mac's Brave / bundled Fortress?" | Brave was a *test* (proves a non-Chrome browser mints); production answer is our Fortress. But Fortress is container-side, gateway is Mac-side — the mismatch is the whole problem. | probed Mac via deskrun; read apps/minds |
| 4 | operator | "hand the container the bearer — doesn't Detent access control break?" | **Yes, it breaks it** — a raw bearer bypasses per-request enforcement. Killed that design; bearer must stay gateway-side. | reasoning + read gateway/utils source |
| 5 | operator | detent PR base: dev or main? | The repo **default is `main`** (checked the API); session 233's `dev` was a one-off. Our PR is correctly on `main`. | GitHub API `default_branch` |
| 6 | reviewer (self-review, boweiliu) | 5 inline PR comments | See §4. Trim prose, drop demo/sandbox, add avoid-dev-path guidance. | GitHub PR comments API |

## 3. Thought Process & What I Did (think → do → observe → conclude)

- **Think:** DocuSign's REST API needs an 8h bearer, not cookies, and the SPA gets no
  refresh token. **Do:** probed cookie-direct, pure-HTTP mint, and browser mints.
  **Observe:** cookie-direct and HTTP mint fail; a browser mint works but **plain Chrome
  is blocked** (headless AND headed); **Fortress mints fine** (`userinfo` 200).
  **Conclude:** store cookies, mint the bearer by loading the app in a non-Chrome browser
  and capturing the `Authorization: Bearer` off the SPA's own calls.
- **Do:** wrote `docusign.ts` (custom `DocusignSessionCredentials`; `refreshCredentials`
  mints just-in-time via `LATCHKEY_REFRESH_BROWSER_PATH`, else returns null → re-login);
  registered it; added the detent `docusign-api` schema and the mngr catalog entry.
  **Observe:** typecheck/lint/tests green.
- **Do:** proved e2e through the live gateway with only the stored session — sent a real
  envelope. **Observe:** **HTTP 201**, envelope `7a8b84c0-…`.
- **Think:** how does Minds get 30-day? **Do:** probed the Mac (no Fortress there; Brave
  present and *does* mint) and read `apps/minds`. **Observe:** the mint's three
  ingredients (cookies in the gateway, stealth browser in the container, Detent
  enforcement at the gateway) live in three places; convenient shortcuts break access
  control. **Conclude:** no small change gives clean 30-day; **ship 8h now**, defer.
- **Do:** opened the three PRs via the git proxy; wrote the mint-problem + full-picture
  docs. **Observe:** operator left 5 inline comments. **Do:** addressed each (see §4),
  authored as `boweiliu`, pushed, replied per-thread. **Do:** notified the reviewer on
  Slack following the channel convention.

## 4. Results Observed

### Built + shipped
| Repo | Change | State |
|---|---|---|
| latchkey #122 | session-riding connector + `DocusignSessionCredentials` + registration + tests | open, green |
| detent #27 | `docusign-api` schema (GET=read / mutating=write), production-only | open, green |
| mngr-internal #371 | catalog entry (generator display-name/order + `services.json`) | **draft** (waits on the other two + a version bump) |

### Proven live
| Check | Result |
|---|---|
| Fortress mint from stored cookies | `userinfo` 200 |
| Brave mint on the Mac (via deskrun) | valid bearer, len 1970 |
| E2E send via gateway, stored session only | **HTTP 201**, envelope `7a8b84c0-…` |
| latchkey preserves cred when refresh→null | verified in `apiCredentials/utils.ts` |

### Review round (all addressed)
| PR:line | Comment | Fix (commit) |
|---|---|---|
| latchkey `docusign.ts:321` | steer agents off the paywalled dev/OAuth path | `info` says do NOT set up an IK/OAuth/go-live; dropped dev docs link (`cc8ab95`) |
| latchkey `docusign.ts:3` | header comments excessive | trimmed ~28→13 lines (`cc8ab95`) |
| detent test `:2971` | no sandbox/demo support | dropped `account-d`, removed demo test, production-only (`a1daddd`) |
| detent test `:2980` | redundant / merge-overflow tests | consolidated the block (`a1daddd`) |
| mngr changelog `:7` | human-facing text verbose | one-line changelog + tightened catalog descriptions (`a188d0e`) |

### Slack
Posted top-level in `#project-latchkey` tagging the reviewer, three PR links + the 8h/30-day caveat, signed `_sent from minds_` (ts `1786693685.053129`).

## 5. Hiccups

- **Bearer-out breaks Detent.** The tempting "give the container the 8h bearer to use
  directly" bypasses per-request access control — the operator caught it; I only saw it
  after the pushback. Killed that branch of the design.
- **Commit authorship env override.** `GIT_AUTHOR_NAME`/`GIT_COMMITTER_NAME` are set in
  the environment to the agent identity and **override repo-scoped `git config`**. Had to
  export `GIT_AUTHOR_*`/`GIT_COMMITTER_*` per commit to author as `boweiliu`.
- **Gateway flapped mid-push.** The Minds gateway restarted: primary `1989` went down,
  secondary `1990` returned 400 for the git proxy. Polled ~10s for `1989` to recover,
  repointed, pushed cleanly.
- **`auth.test` "not permitted".** A red herring — that Slack method isn't in the granted
  scopes, but `conversations.history` (read) and `chat.postMessage` (write) were, so
  posting worked.
- **Prose discipline — the same lesson as session 233.** The reviewer flagged verbose
  comments again; 233's notes warned about exactly this. Should have pre-trimmed.
- **Meta-test timeouts** (`lint.test.ts` 10s / `typecheck.test.ts` 5s) fail locally in
  the container but pass in CI — same environmental flake as 228/233.

## 6. What's Next

- **Operator re-reviews** the five fixes (done: all pushed + replied); reviewer notified.
- **Ship the 8h unit:** merge detent #27 → release; merge latchkey #122 → release; bump
  mngr-internal to those releases + un-draft #371.
- **30-day (deferred):** needs the gateway↔container mint plumbing (gateway delegates only
  the browser step, bearer returns to the gateway), or a non-Chrome browser co-located
  with the gateway. Fully documented in the workbench docs.
- **Optional decay polish (untested):** seed the stored cookies into the login browser at
  re-login so the ~8h re-prompt is "click continue" instead of "type password."

## 7. Reflections & Gut Feelings

The connector is clean and proven; the honest story is the *refresh*, and I'm glad we
resisted shipping a hand-wavy 30-day mechanism. Writing the mint-problem doc from scratch
(evidence → options → the two walls) is what made "ship 8h, defer 30-day behind a null
return" obviously right. Anti-sycophancy paid off repeatedly: the operator's "this seems
wrong" was correct each time (Brave framing, bearer-out breaking Detent) — I should make
those my own checks rather than wait for the pushback. The git-over-gateway-proxy trick
(custom `x-latchkey-gateway-*` headers, no token in the container) is worth remembering.

## 8. Future Improvements (TODO to investigate)

- **Base-hook for browser-at-refresh in latchkey** — a managed launcher handed to
  `refreshCredentials` would let a user with their own stealth browser self-refresh with
  no env-var; small, generic, benefits any browser-at-refresh connector. TODO.
- **Gateway→container mint delegation** — the clean 30-day design. Worth prototyping the
  channel (gateway asks the container's Fortress to run the browser step, bearer returns).
- **Meta-test timeouts** — bump `lint.test.ts` (10s) / `typecheck.test.ts` (5s) so
  `npm test` is reliable on slow machines. Same TODO flagged in 228/233; still open.
- **Pre-trim prose before review** when past-session notes call out a reviewer's prose
  preferences — don't make them ask twice.

## 9. Helpful Scripts (copied into this directory)

All read credentials from the gateway store / env at runtime; none embed secrets.

- **`send_via_gateway.py`** — e2e proof: sends a real envelope for signature using only
  the gateway's stored session (`latchkey curl`), no token/password in the container.
  Generates a tiny PDF, POSTs the envelope, asserts 201. `uv run python send_via_gateway.py`.
- **`refresh_gateway_docusign.py`** — the container-side 30-day refresher: dumps the
  gateway cred's cookies (Mac, via `deskrun`), mints a fresh bearer with container
  Fortress, writes it back to the Mac store. `uv run python refresh_gateway_docusign.py`.
- **`mint_with_brave.mjs`** — Mac-side probe: mints a bearer with Brave (proves a
  non-Chrome Chromium isn't blocked). Run on the Mac via `deskrun` + node.
- **`dump_docusign_cookies.mjs` / `update_docusign_token.mjs`** — Mac helpers used by the
  refresher to read cookies from / write the bearer to the gateway's docusign credential.

## 10. Long-Running Servers / Processes

None left running. The Minds desktop gateway restarted on its own once mid-session
(unrelated to my work; recovered on its own — this is what caused the push flap). No
background processes on the container. An earlier session had scheduled a container cron
for the refresher; it was **removed** at the operator's request, so nothing is on a timer.
