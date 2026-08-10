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
   isolate paid `inference`). Skip per-resource scopes.
10. **Upstream** — Detent scopes PR, latchkey connector PR, mngr-internal catalog
    PR; then a release + roll-up bump ships it to users.

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
- **Check bundle-vs-checkout version skew** — diff the bundle's
  `dist/src/services/core/base.js` for `this.service.<method>` calls before
  assuming your checkout's base is authoritative (e.g. v3 requires `getAccount`).
