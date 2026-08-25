# The connector-build procedure (with contingencies)

The full procedure for building a new latchkey connector, including the phases
that are easy to skip and the failure recoveries. Ordered; each phase lists its
exit criterion and its known traps. Companion docs:
`connector-docs-to-read.md` (what to read first) and the `docs/build-journal/`
entries this draws from (02, 03, 07, 246, 248).

## Phase 0 — Classify the auth shape AND check the live state

- **Classify**: mint-and-reveal (ngrok/HF — scrape a long-lived token), OAuth
  (Linear — auth-code flow), or session-riding (DocuSign/Slack — store cookies,
  mint a short-lived bearer). Read the service's auth docs, but decide by
  *probing*, not by docs alone (DocuSign's "can't create a key in production"
  doc page was wrong; the Dev Console could).
- **Check the live state, before writing anything**: is the gateway already
  hot-modded, and is another agent mid-hot-mod *right now*?
  `deskrun 'tmux ls'`, `latchkey services list`, and grep the bundle's
  `services/index.js` for existing custom services. Session 246's standing
  warning: "watch out for simul hotmod actions" — two agents patching the same
  bundle clobber each other. Serialize; capture the `minds-deploy` pane and
  confirm it's idle before every `send-keys`.

**Exit**: auth shape chosen with evidence (not docs); live hot-mod state known;
no other agent active on the Mac.

## Phase 1 — Recon the live web flow

Drive the real login in the browser fleet (or a local CDP browser you control):
login → token/key page → create → capture the one-time reveal. Output: exact
selectors, consent-screen behavior, reveal shape (`<input>` vs plain text).
Rules: locale-independent selectors only; scope every locator by accessible
name (a bare `[role="dialog"]` matches hidden leftovers + password-manager
modals and hangs strict mode); bring the login tab to front; retry
click-before-hydration. Classify the session type here — a
`BrowserFollowupServiceSession` must go on the recordings blacklist the same
day or the login recording leaks the minted credential.

**Ask for the operator's username/password (or a control handoff) up front** —
it converts the recon loop from human-in-the-loop to self-serve. If the login
issues an email OTP, build the headless mint harness FIRST (fetch the code from
Gmail via the latchkey connector — entry 03's biggest unlock: ~30s iterations
instead of multi-minute ones).

**Exit**: a replayable selector script and the session-type classification.

## Phase 2 — Build the connector AND test it locally, no Mac involved

- Write `services/<svc>.ts` modeled on a **current in-tree** connector
  (`linear.ts` for OAuth, `slack.ts` for cookie-riding) — not the workbench's
  bundled template (version skew). Wire into `services/index.ts`,
  `serviceRegistry.ts`, `apiCredentials/serialization.ts`. Include `getAccount`
  even if it returns null (v3's base class calls it; a v2-modeled connector
  fails *after* minting — entry 02's expensive bug).
- **Test locally: stand up an isolated throwaway gateway** (`/tmp/lk-e2e` on
  `localhost:19890`, scopes inline in its `permissions.json` — entry 07's
  pattern). Exercise the real flows there: URL matching (service recognized),
  credential injection, serialization round-trip, `checkApiCredentials` against
  the real API (full URL, never a relative path), and scope enforcement
  (read 200 / write 403 / cross-area 403 with granular scopes). Unit tests +
  typecheck + lint in the repo too.
- This phase replaces most of what used to require hot-modding. **Do not touch
  the Mac until all of it passes.**

**Exit**: isolated-gateway e2e green, including enforcement boundaries;
container env provably free of the credential.

## Phase 3 — Enforcement schema (detent), before any grant exists

- Vendor the service's real OpenAPI endpoint inventory as a fixture; drive
  Detent's actual matcher over every operation; compare against an
  independently computed intended set. Commit it as a data-driven regression
  test (template: `tailscaleOpenapiCoverage.test.ts`). Never theorize the API
  shape (entry 03's inference-scope near-miss).
- Gotchas: `read` must include `HEAD` and `OPTIONS`, not just `GET` (a
  read-only grant that can't `HEAD resolve` can't download); some APIs do reads
  via POST (enumerate the real ops); multi-domain services need
  `pattern`/`enum` on `domain`, not one `const`; the token's capability must
  cover every scope you grant (a read-only token can't back `-write-all`); one
  scope with method-constrained permissions (the catalog allows exactly one
  scope per service); granular scopes map to the service's OAuth scope
  taxonomy, not its role hierarchy.
- **Schema before grant, always.** A grant referencing an unresolvable schema
  bricks the agent's entire permission set. To change a live scope:
  revoke-first, then swap.

**Exit**: coverage test green in detent; zero anomalies against the spec.

## Phase 4 — Catalog (mngr-internal)

Regenerate `services.json` from the detent schema via
`generate_services_json.py` + a curated display name. Changelog entry named
**after the branch** (`<branch>.md`), not the feature. Run `check-changelog`
locally before pushing.

**Exit**: catalog regen diff contains exactly your service; changelog gate
passes locally.

## Phase 5 — Prove live on the Mac (one shot at the operator's attention)

The operator's approval + SSO is a scarce, one-shot resource. Everything below
is designed to spend it exactly once.

- **Pre-flight**: the connector already passed Phase 2 locally. Re-check the
  live state (Phase 0's concurrency check) — the world may have moved.
- **Hot-mod**: compile the connector to JS; upload via deskrun; run the patch
  through the `minds-deploy` Terminal-backed tmux (capture-pane idle check
  before every send-keys; a bare `cp` gets "Operation not permitted" — SIP).
  Patch `index.js` / `serviceRegistry.js` / `serialization.js` in-place and
  **idempotently**, alongside any existing custom services (do not replace
  files wholesale — another agent's hot-mods may share those files). Patch the
  catalog + schema into **every uv-cache copy** (the app reprovisions from the
  cache on boot; editing live copies reverts).
- **Restart + recover**: `restart_minds.sh` (never kill the forward process —
  it respawns but takes minutes with `latchkey`/`deskrun`/file-sharing all
  down). Poll `permissions/self` ~35-45s for recovery. Gateway flaps and even
  the operator's laptop sleeping look identical to real crashes — be patient
  before escalating (entries 02's two outages).
- **File the permission request only AFTER the gateway recovers** — a restart
  wipes pending requests and the mint then silently fails. Payload requires
  `type`, `agent_id`, `rationale`, and `payload{scope, permissions, account}`.
- **If the live-proof fails** (selector timeout, mint error): debug yourself —
  `LATCHKEY_DISABLE_SPINNER=1` + a Playwright screenshot of the real DOM,
  `manage_credential.sh browser <svc>` against the bundled CLI (the approval
  flow may invoke the *system* latchkey, which doesn't know hot-modded
  services — session 247's trap). Do NOT ask the operator to retry until you
  have a root cause and a fix already verified in the isolated gateway.
- **Acceptance**: one real end-to-end call through the gateway (the canonical
  one for the service), proven sealed (the same call direct, without the
  gateway, fails).

**Exit**: e2e green on the real gateway with the operator interrupted exactly
once (approval + SSO).

## Phase 6 — Upstream: self-review before anything goes out

- Three PRs in dependency order: detent → latchkey → mngr-internal (draft until
  the others land).
- **Order for every review round: address feedback → self-review → reply.**
  Self-review means re-reading the diff critically — not confirming CI is
  green (entry 07: the shallow pass missed a security-relevant scope comment).
  Replying then correcting your own reply is churn.
- Pre-trim prose before review when past notes flag the reviewer's prose
  preferences (flagged twice; don't make them ask a third time).
- Authorship: export `GIT_AUTHOR_NAME/EMAIL` + `GIT_COMMITTER_NAME/EMAIL` as
  the operator — the environment's agent identity overrides repo config.
- **After EVERY push: check CI** (`gh pr checks` or the check-runs API).
  Mergeable ≠ green. Run repo gates locally pre-push: prettier on every touched
  file (not just the connector), the changelog filename gate.
- Evidence comments travel with the PRs (scope-verification + e2e results) —
  they pre-answer the reviewer's "did you check" questions.

**Exit**: three PRs open, CI green on the head commits, review comments
replied-to after self-review.

## Phase 7 — Teardown

Remove the hot-mod once the live proof is accepted: restore the bundle files
from the `.pre*-fix.bak` backups (or the patcher's revert), clean the uv-cache
copies, remove the test grant + test credential. A live hot-mod is debt that
reprovisions into a brick days later (twice journaled). Note: until the PRs
merge and Minds bumps its latchkey/detent dependency, every Minds app update
silently reverts the hot-mod anyway — and can desync stored grants/credentials
into a full latchkey brick (the repair procedure is in the desync memory note,
sessions 256/263).

---

## When something breaks mid-flight

1. Check `SYMPTOM-FIX-MAP.md` first — most symptoms are already ledgered with a
   shipped fix or a known non-fix.
2. Reproduce in the isolated gateway — never debug against the live one when
   you can avoid it.
3. If latchkey traffic dies entirely: desync playbook (sessions 256/263) —
   grants scan + credential-store scan + full Minds restart.
4. Escalate to the operator only with: symptom, what you've ruled out (with
   evidence), and the exact action you need from them — never a bare "it
   failed, try again."
