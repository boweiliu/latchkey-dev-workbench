# Building a latchkey connector: the recon-first playbook

The plan and execution map that `PROGRESS.md` (an ngrok build-journal) never
spelled out. Read this before starting a new connector. Two things it adds:
(1) an explicit **browser-recon step** that must come before you write any
selectors, and (2) a **here-vs-Mac execution split** so you know which side each
step runs on.

---

## The step that's easy to skip: map the live web flow first

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
- **Scope every Playwright locator by accessible name, never a bare
  `[role="dialog"]` or generic role.** A bare role on a heavy client-rendered
  page can match several elements at once — a hidden leftover verify-email
  dialog, the real dialog, *and* a password-manager modal (1Password etc.) — and
  strict mode then hangs with a generic timeout instead of telling you why. The
  mint-timeout you'll see is the symptom; named scoping is the fix.
- **Some services reveal the minted key as plain text** (a `<pre>` or span), not
  in an `<input>` — check the recon output before assuming `input[value]`. The
  OpenRouter connector reads the reveal out of the dialog text, not a field.

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
   SIP-protected `Minds.app` bundle (from a Terminal-backed tmux session, which
   inherits the App-Management grant), then reload with `restart_minds.sh`.
7. **Request → approve → verify** — request the scope, approve (browser login
   mints the sealed credential), then verify with `latchkey curl`.
8. **e2e test** — a real call that proves the point (a `POST` to the service's
   chat/completions or its canonical read endpoint). Have this ready from the
   start; it's the definition of done, not an afterthought.
9. **Refine scopes** *(if warranted)* — method-based `read`/`write` is correct for
   a RESTful API; add a granular scope only for a distinct/costly action (e.g.
   isolate paid `inference`). Skip per-resource scopes. But:
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
| Patch the app bundle + restart Minds | **Mac** (bridge, Terminal-tmux) | Bundle is the SIP/App-Management-protected `Minds.app` |
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
