# Building a latchkey connector: the recon-first playbook

The plan and execution map that `PROGRESS.md` (an ngrok build-journal) never
spelled out. Read this before starting a new connector. Two things it adds:
(1) an explicit **browser-recon step** that must come before you write any
selectors, and (2) a **here-vs-Mac execution split** so you know which side each
step runs on.

## Two connector patterns

The worked examples (ngrok, HuggingFace) use the **mint-and-reveal** pattern:
the connector drives a browser login, navigates to a "create token" page,
creates the token, and scrapes its value from a one-time reveal dialog. The
credential is long-lived and stored sealed in the gateway.

A second pattern — **session-riding** (entry 06, DocuSign) — applies when the
service has no long-lived token: store the user's web-session cookies, mint a
short-lived bearer (e.g. 8h) from them by loading the app in a non-Chrome
browser and capturing the `Authorization: Bearer` off the SPA's own calls.
`refreshCredentials` returns null to mean "re-login required" (do NOT hand the
container the bearer to self-refresh — it bypasses Detent). Modeled on the
Slack connector.

---

## The step that's easy to skip: map the live web flow first (and classify the session type)

You cannot write correct Playwright selectors for the connector's login/mint
flow without first driving the service's *live* pages and reading them. Do this
as its own step, **before** writing `services/<svc>.ts`:

- Drive the fleet browser (or a local CDP browser you control) through the real
  flow: **login → the token/key creation page → create the token → capture the
  one-time reveal**.
- It needs a real sign-in, so it's a **control-handoff** (or you drive it with a
  user/password the operator provides — worth asking for up front; it smooths
  automation development a lot).
- **Output:** the exact selectors + navigation the connector will replay — login
  field/button selectors, the create-token URL and form fields, and where the
  minted value is revealed (input vs. `<pre>` vs. span; prefix if any).
- **Prefer locale-independent selectors** (form-scoped `button[type=submit]`,
  `input[name=...]`), not text like `hasText: 'Create token'` — latchkey's
  `AGENTS.md` requires it.
- **Classify the connector's session type while you recon.** If the service
  needs a real browser login (a `BrowserFollowupServiceSession` — `linear`,
  `dropbox`, `github`, `ngrok`, `todoist`, ...), it **must be added to the
  recordings blacklist** or the browser-login recording leaks the minted
  credential. ngrok was initially missing, wrongly reverted, then re-added — the
  revert is the easy mistake; re-add it. Map every connector's session type
  before you decide; don't blacklist only the ones you happen to remember.
- **Scope every Playwright locator by accessible name, never a bare
  `[role="dialog"]` or generic role.** A bare role on a heavy client-rendered
  page can match several elements at once — a hidden leftover verify-email
  dialog, the real dialog, *and* a password-manager modal (1Password etc.) — and
  strict mode then hangs with a generic timeout instead of telling you why. The
  mint-timeout you'll see is the symptom; named scoping is the fix.
- **Some services reveal the minted key as plain text** (a `<pre>` or span), not
  in an `<input>` — check the recon output before assuming `input[value]`. The
  OpenRouter connector reads the reveal out of the dialog text, not a field.
- **Bring the login tab to the front before interacting**
  (`page.bringToFront()`). A browser-followup login page that ends up backgrounded
  can type into a sudo password prompt or the wrong tab entirely; this is a
  real wrong-tab UX nit across every browser-followup connector.
- **Clicks before hydration are no-ops on heavy client-rendered pages** (the
  keys table on OpenRouter, etc.). Retry-until-open rather than click-once; the
  first click can land before the listener is attached and silently do nothing.

## The connector-centric plan (ordered)

1. **Map the live web flow in a real browser** *(the step above)* → selectors.
2. **Write the connector** — `services/<svc>.ts`, modeled on a *current in-tree*
   service (e.g. `linear.ts`), **not** the workbench's bundled template (it may
   target a different latchkey version). Wire it into `services/index.ts` +
   `serviceRegistry.ts`; typecheck + build.
3. **Prove standalone** *(optional, if you can)* — exercise URL-match + injection
   without a live gateway restart.
4. **Detent / enforcement schema FIRST** — the `<svc>-api` scope schema. It must
   exist before any grant references it, or granting bricks the whole permission
   set. For the live dev hot-mod, an inline schema in `additional_services.json`
   (patched durably into uv's cache) works without a Detent release.
5. **Catalog entry** — make the scope requestable (`extensions/services.json`),
   patched durably into uv's cache.
6. **Hot-mod the live gateway** — patch the compiled connector into the
   SIP-protected `Minds.app` bundle. The bridge's launchd helper **lacks** the
   App-Management TCC grant, so `cp`/`deskrun` directly into the bundle gets
   "Operation not permitted." Run the patch+restart inside **Terminal.app's
   context** (Terminal has the grant) — either a tmux session started inside
   Terminal.app (the "Terminal-backed tmux trick" PROGRESS.md describes) or
   `osascript` into Terminal.app — then reload with `restart_minds.sh`.
7. **Request → approve → verify** — request the scope, approve (browser login
   mints the sealed credential), then verify with `latchkey curl`. **File the
   request *after* the gateway has fully recovered from any restart, not
   before** — a Minds restart wipes pending permission requests, and the mint
   then silently fails (you poll forever, no credential). Also: if the service
   is a `BrowserFollowupServiceSession`, **add it to the recordings blacklist**
   in this same step (see the recon note above / SKILL.md), or the login
   recording leaks the minted credential.
8. **e2e test** — a real call that proves the point (a `POST` to the service's
   chat/completions or its canonical read endpoint). Have this ready from the
   start; it's the definition of done, not an afterthought. **Prefer an
   isolated throwaway gateway** (`/tmp/lk-e2e` on `localhost:19890`, scopes
   inline in `permissions.json`) over hot-modding the workspace gateway -- no
   residue, nothing to brick. Use the workspace-gateway hot-mod only to prove the
   connector *loads* in the real gateway; scope-enforcement e2e (read vs write,
   granular boundaries) belongs in the isolated gateway (entry 07).
9. **Refine scopes** *(if warranted)* — method-based `read`/`write` is correct for
   a RESTful API; add a granular scope only for a distinct/costly action (e.g.
   isolate paid `inference`). Skip per-resource scopes. But:
   - **Ship a data-driven scope coverage regression test.** Vendor the service's
     full OpenAPI endpoint inventory as a fixture and drive Detent's real matcher
     over all of it, asserting each scope matches its independently computed
     intended set (0 side-effecting GETs, 0 read-only writes, lookalike paths like
     `/ssh_credentials` correctly rejected). This is entry-01's Future
     Improvement #1, paid down in entry 07; the tailscale PR's
     `tailscaleOpenapiCoverage.test.ts` is the template.
   - **Map granular scopes to the service's own OAuth scope taxonomy**, not its
     role hierarchy (roles are a user-identity concept; OAuth scopes are the API
     scope taxonomy). entry 07.
   - **The catalog exposes exactly one scope per service** (`additional_services`
     allows one scope per service), so multi-domain or multi-capability services
     use **one `<svc>-api` scope with method-constrained *permissions* under it**,
     not multiple scopes. The constraint forces this design, and it's cleaner.
   - **`read` must include `HEAD` and `OPTIONS`, not just `GET`.** Many download
     clients (e.g. `huggingface_hub`) issue a `HEAD resolve/...` before every
     download; a `read = method:GET` scope blocks it and a read-only grant can't
     download the very model it's for. A live `HEAD` returning 403 is the tell.
   - **Some APIs do reads via `POST`.** (HuggingFace's `paths-info` is a
     POST-based read.) Method-based classification misses them — enumerate the
     real operations against the spec, don't assume REST shape.
   - **Multi-domain services** (e.g. HuggingFace Hub + the inference router) need
     a `pattern`/`enum` on `domain` in the scope schema, not a single `const`.
     The ngrok example only showed single-domain `const`; the HF example shows
     the multi-domain shape.
   - **The token's capability must cover every scope you grant.** A read-only
     service token cannot back a `-write-all` permission. For HuggingFace a
     classic `write` token (read+write+inference) backs all three scopes; a `read`
     token does not. Mint the token type that covers the grant set.
10. **Upstream** — Detent scopes PR, latchkey connector PR, mngr-internal catalog
    PR; then a release + roll-up bump ships it to users. **After opening the PRs,
    check the CI runs** (`gh pr checks`) — running the tests locally is not the
    same, and a red you didn't notice is the most common miss. Run the
    repo-specific gates locally *before* pushing too: latchkey wants `prettier`
    on every file your register script touched (not just the connector), and the
    mngr-internal changelog entry must be named **after the branch**
    (`<branch>.md`), not the feature.

## Which steps run here (container) vs. on the Mac (bridge)

The gateway that actually serves requests is the **Mac's Minds.app** (the
container reaches it via a forwarded `127.0.0.1:1989`). That's why the connector
has to be patched into the Mac bundle, not something container-local.

| Step | Runs | Why |
|---|---|---|
| Map the live web flow (recon) | **Here** (browser fleet / local CDP) | You drive it; operator hands off for sign-in |
| Write + compile the connector | **Here** (or a Mac checkout) | Code work in the repo |
| Detent schema + catalog content | authored **here**, applied on **Mac** | uv cache lives at `~/.minds/.uv-cache` on the Mac |
| Patch the app bundle + restart Minds | **Mac** (bridge → `osascript` into Terminal.app) | Bundle is SIP/App-Management-protected; the bridge's launchd helper lacks the grant, so escalate via Terminal.app |
| Request the scope | **Here** (`latchkey curl`) | Container talks to the gateway |
| Approve + browser mint | **Mac** (Minds opens the login browser) | Runtime login is Mac-side |
| Verify `latchkey curl` / e2e | **Here** | Gateway injects the sealed credential |

Rule of thumb: **authoring** (code, JSON, selectors) happens here; **anything
touching the running desktop app** (bundle, uv cache, restart, the real login)
happens on the Mac via the bridge. Files move to arbitrary Mac paths by PUT-ing
to `~/tmp/minds_data` (the file-sharing grant) then `deskrun cp`.

## Safety notes carried over from hard experience

- **Reload with `restart_minds.sh`, not by killing the forward process.** The
  process-kill "respawns" but can take minutes, during which the container loses
  `latchkey`, `deskrun`, and file-sharing entirely.
- **Schema-before-grant, and revoke-before-schema-swap.** A grant referencing a
  missing/removed scope schema bricks every permission. To change a live scope,
  revoke the old grant first.
- **SIP bundle writes need a Terminal.app context, not a bare `deskrun`/`cp`.**
  The bridge's launchd helper lacks the App-Management TCC grant, so `cp`/
  `deskrun` directly into `Minds.app` gets "Operation not permitted." Run the
  patch+restart inside Terminal.app's context (Terminal has the grant): a
  tmux session started inside Terminal.app (the "Terminal-backed tmux trick"
  PROGRESS.md describes) or `osascript` into Terminal.app both work. The costly
  miss is assuming a bridge-driven `cp`/`deskrun` inherits the grant -- it
  does not; only a Terminal.app-context process does.
- **A Minds restart wipes pending permission requests.** Filing a request right
  before a restart means it disappears and the mint silently fails (poll
  forever, no credential). File after the gateway has recovered.
- **A live hot-mod is a debt that compounds when you walk away.** The durable
  uv-cache patch is exactly what reprovisioned into a broken state days later and
  bricked *every* permission check with `references unknown schema
  "#/$defs/<svc>-api"` — the agent is locked out and only the operator can clear
  it (revoke the grant in Connectors). Prove a connector live, then **remove the
  hot-mod**; the durable path is the three upstream PRs. Leaving a resident
  hot-mod is asking for exactly this.
- **Check bundle-vs-checkout version skew** — diff the bundle's
  `dist/src/services/core/base.js` for `this.service.<method>` calls before
  assuming your checkout's base is authoritative. The expensive symptom: v3's base
  calls `this.service.getAccount`, which a v2-modeled connector lacks, so the
  browser login mints the token and *then* throws `this.service.getAccount is not
  a function` — you get the mint, fail the save, and the credential never lands.
- **A raw bearer handed to the container bypasses Detent.** Keep the bearer
  gateway-side. A connector that mints a short-lived token (e.g. an 8h session
  bearer from stored cookies) must store it in the gateway, not hand it to the
  agent — a raw bearer in the container skips per-request enforcement.
  `refreshCredentials` returning null means "re-login required" (the
  defer-silent-refresh pattern for short-lived tokens); do NOT hand the container
  the bearer to self-refresh (entry 06).
- **Plain Chrome may be blocked; a non-Chrome browser (Fortress/Brave) mints.**
  Some services block Chrome (headless AND headed) from their mint endpoint. The
  bundled Fortress browser (or Brave on the Mac) mints fine. If a browser mint
  fails with a blocked/forbidden response, try a non-Chrome Chromium (entry 06).
- **`checkApiCredentials` must use a full URL, not a relative path.**
  `runCapturedAsync` can't reach a relative path with no host — a relative
  `checkUrl` returns invalid even for a valid token. Use the full
  `https://api.<svc>.com/...` prefix. Unit tests with mocked curl don't catch
  this; live-verify the built connector (entry 07).
- **Self-review *before* replying to review comments.** Order: address feedback
  → self-review (re-read the diff critically) → reply. Replying then
  self-reviewing then correcting your own reply is churn a single careful
  ordering avoids (entry 07).

## Dev-loop accelerators (worth setting up before the first mint)

- **A headless mint harness that pulls the email OTP from Gmail via the latchkey
  connector.** A fresh-browser login often needs a 6-digit email code a headless
  browser can't read; fetching it from the user's inbox (read-only Gmail grant)
  turns a multi-minute human-in-the-loop approve-sign-in-wait loop into a ~30s
  self-serve one, and surfaces the real strict-mode error the gateway only shows
  as a generic mint timeout. This was the single biggest iteration-speed unlock
  on the OpenRouter connector; build it first.
- **Run repo gates locally before pushing** (prettier, the branch-named
  changelog). The mngr-internal `check-changelog` runs locally; finding the
  filename rule there is far faster than spelunking a CI log through a flaky
  bridge.
- **`deskrun`/zsh gotchas** (the bridge runs zsh): `unsetopt equals` or zsh
  eats `=word`; quote parens in `echo` or trigger a glob error; `node`/`tmux`
  need `zsh -lc` or absolute paths; the workspace hook blocks `head`/`tail`
  even inside uploaded scripts; and `deskrun` times out after ~60s, so split
  long CI poll-loops into shorter calls.
