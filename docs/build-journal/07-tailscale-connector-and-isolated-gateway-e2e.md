---
source_repo: boweiliu/bowei-thoughts
source_path: working-sessions/242-tailscale-latchkey-connector/session.md
pulled: verbatim
modifications: none
---

# 242 — Tailscale latchkey connector: research, build, upstream, harden

Built a Tailscale connector for Latchkey from scratch — research, design decision (API access token vs OAuth client), the connector + paired detent scopes + mngr catalog, scope verification, gateway e2e, upstream PRs, review responses, self-review, and a Slack handoff. The full session-195 hardening loop applied.

---

## 1. Original Ask & Evolution

- **Starting ask:** "find docs and pull in skills into here if not present. do you know how to make latchkey connectors WITH the latest process and PR adjustments?" — i.e. establish the current connector-build process and apply it to a **Tailscale admin dashboard connector**.
- **Goal clarification:** the operator wasn't sure which Tailscale credential to mint. Primary e2e goal: admin-dashboard actions like toggling member permissions/role states. Secondary: enough token minting to drive the `tailscale` CLI.
- **Exploration path offered:** I could drive a browser and the operator would auth via Google SSO so I could do read-only actions on their real tailnet.
- **Pivot to the clean approach:** after the first exploration, the operator pushed back — "maybe there is an even cleaner approach since the api is well documented and token minting is as well? did you read tailscale docs?" — which surfaced the **OAuth client / client-credentials flow** (long-lived, no 90-day re-login). I verified that flow e2e too, but ultimately shipped the **API access token** connector first because its mint is autonomous (no scope/tag handoff) and serves both goals.
- **Ship-it instruction:** "if straightforward — make your own judgements and get to shipping all the PRs."
- **Process-depth nudge:** after I shipped three PRs at the lint+test bar, the operator recalled a fuller process doc ("there should have been a latchkey doc which had more steps, including testing e2e and deskrun and stuff"). I found it in `bowei-thoughts` session 195 (the ngrok connector hardening) and applied its loop: scope-verify against the real OpenAPI surface, evidence/paper-trail comments, gateway e2e.
- **Review cycle:** operator left 3 review comments on the detent PR (granular scopes? fixture's point? test duplication?). I addressed all three, added 6 granular scopes, self-reviewed (caught two real issues), re-ran e2e on the reworked scopes, and rereviewed.
- **Final ask:** post in Slack `#project-latchkey` tagging Hynek that the PRs are up for review, with a "sent by minds" signoff, then summarize the session here.

## 2. Questions Asked & Answered

| Raised by | Question | Answer | How discovered |
|---|---|---|---|
| Operator → me | How do you make latchkey connectors with the latest process? | `docs/development.md` is the baseline; the fuller loop (scope-verify, e2e, evidence comments) lives in `bowei-thoughts` session 195, plus the conventions visible in recent merged PRs (#117 HF, #118 OpenRouter, #111 generic login flows). | Read the latchkey repo docs + PR history + the session-195 notes |
| Me → operator | Which Tailscale credential — API access token or OAuth client? | Operator wasn't sure; told me to explore. | Explored both via the dashboard + API |
| Me (self) | Is the Tailscale API documented/public? | Yes — OpenAPI 3.1 spec at `api.tailscale.com/api/v2?outputOpenapiSchema=true`, 60 paths / 93 ops, Bearer auth. Reference page is client-rendered Next.js so I read it in the browser. | Fetched the spec; decoded the RSC payload of the docs page to find the spec URL |
| Me (self) | Does the dashboard use the same public API? | Inferred yes: interactive docs generated from `api.tailscale.com`, the mint dialog calls it, and the minted token authorized every admin action. Did not capture raw dashboard network calls (fleet CLI has no network/DOM-eval hook). | Live verification with a minted token |
| Me (self) | Is the API access token reveal-once? | Yes — `tskey-api-<id>-<secret>`, "It won't be shown in full again", 1–90 day expiry. Exact `BrowserFollowupServiceSession` mint-and-reveal pattern (Linear/HF/OpenRouter). | Drove the dashboard mint dialog with the browser fleet |
| Me (self) | Is the OAuth client cleaner? | Yes operationally (long-lived client_id+secret, 1-hour client-credentials flow, no re-login), but its mint needs scope+tag selection so a followup session can't pick them autonomously; `auth_keys` write scope needs org-specific tags. Decided to ship API access token first, OAuth client as a follow-up. | Created an OAuth client in the dashboard, ran the token endpoint, confirmed `tskey-token` + 3600s + scope `users users:read` |
| Operator → me (review) | More granular scopes? Mirror the role hierarchy? | Added 6 granular scopes (users/devices/keys read+write) mapped to Tailscale's **OAuth client scope taxonomy**, not the role hierarchy (which is a user-identity concept, not an API scope taxonomy). | Read the dashboard Trust-credentials scope list; mapped OpenAPI endpoints to areas |
| Operator → me (review) | What's the point of the fixture endpoint list? | It's the full 93-op OpenAPI inventory — the ground truth the coverage test drives the real matcher over. Vendored to keep the test hermetic. | Self-evident from the test, but the question was fair — explained it in a reply |
| Operator → me (review) | Are the coverage tests duplicate with the latchkey PR? | Not duplicate: detent tests scopes (does the schema carve the surface correctly), latchkey tests the connector (URL match, injection, serialization). Same split as the ngrok pair. | Compared the two test files |
| Me (self, self-review) | Is `tailscale-write-keys` just auth keys? | No — `POST /tailnet/{tailnet}/keys` is shared across auth keys, API tokens, OAuth clients, federated identities (keyType in the body, which detent can't see). The scope is broader than Tailscale's `auth_keys` OAuth scope. Fixed the comments. | Re-read my own diff critically |
| Me (self, self-review) | Is `credentialCheckCurlArguments` correct? | It was a misleading partial URL placeholder (dead code, since `checkApiCredentials` is overridden). Changed to `[]` to match `RegisteredService`. | Re-read my own diff |

## 3. Thought Process & What I Did (chronological, as observed)

1. **Process research.** Pulled the latchkey repo docs (`docs/development.md`, `docs/extensions.md`, `AGENTS.md`), read the recent merged connector PRs (#117 HF, #118 OpenRouter, #111 login flows) for current conventions, and read the `bowei-thoughts` session-195 notes only after the operator nudged — a sequencing mistake I flag in reflections.

2. **Tailscale docs exploration.** Plain curl couldn't reach `tailscale.com` through the gateway (not a configured service); used plain `curl` to fetch the docs pages. The API reference page is client-rendered Next.js with no server-side content, so I decoded the RSC `__next_f.push` payloads and the `__NEXT_DATA__` to find the OpenAPI spec URL (`api.tailscale.com/api/v2?outputOpenapiSchema=true`). Pulled the full 60-path / 93-op OpenAPI 3.1 spec and saved it.

3. **Browser login + live exploration.** Opened a fleet browser, handed off to the operator for Google SSO, then explored the dashboard (Machines 127, Users 45). Minted an API access token (`tskey-api-...`) from the Keys page reveal dialog; proved it authorized `GET /tailnet/imbue.com/users` and `POST /tailnet/.../keys` (minted a CLI auth key). Revoked both test credentials and confirmed 401.

4. **Cleaner-approach check.** Read the OAuth-clients KB (`kb/1215/oauth-clients`) — found the client-credentials flow (`POST /api/v2/oauth/token` → `tskey-token`, 3600s). Created an OAuth client in the dashboard Trust-credentials page, ran the flow, used the token to list users, revoked the client (401). Operationally cleaner but not autonomous; decided to ship API-access-token first.

5. **Connector build.** Refreshed the latchkey clone to current `main` (3.5.0, #121). Studied `openrouter.ts` (mint-and-reveal template), `dropbox.ts` (OAuth-refresh template), `OAuthCredentials`, the base `Service`/`BrowserFollowupServiceSession` classes, and the serialization union. Wrote `src/services/tailscale.ts`: a `BrowserFollowupServiceSession` that signs in, navigates to the Keys page, opens the "Generate API access token" dialog, fills a description, submits, scrapes the `tskey-api-...` from the "Generated new key" reveal dialog, and captures the tailnet from `#app-root a`. New `TailscaleCredentials` (token + tailnet) added to the serialization union; registered in `services/index.ts` + `serviceRegistry.ts`; listed in both SKILL.md files; blacklisted in `servicesAgainstRecordings.test.ts`; `tests/tailscale.test.ts` for URL match, injection, account, serialization round-trip, and the credential check (valid/401/404/unknown).

6. **Live verification of the built connector.** Built the dist, minted a fresh token, and exercised `checkApiCredentials` against the real API. Caught a bug: my `checkUrl` used a relative path (`/api/v2/tailnet/`) with no host — `runCapturedAsync` hit a relative URL and returned invalid even for a valid token. Fixed by using the full `https://api.tailscale.com/api/v2/tailnet/` prefix. Re-verified: valid→valid, wrong-tailnet→invalid, bad-token→invalid, non-tailscale→unknown.

7. **Three paired PRs.** Pushed feature branches directly to the upstream `imbue-ai/*` repos (no fork needed — the operator's account has write access, same `imbue-ai:dev` flow the maintainers use) and opened same-repo PRs: latchkey #123, detent #28, mngr-internal #379. Each PR body cross-references the other two.

8. **Detent scopes PR.** Wrote `src/schemas/builtin/tailscale.json` (`tailscale-api` + read-all/write-all), regenerated the builtin-schemas module + docs, added `tests/builtinSchemas.test.ts` tests, and a data-driven `tests/tailscaleOpenapiCoverage.test.ts` + vendored `tests/fixtures/tailscale-openapi-endpoints.json` driving the real matcher over all 93 ops.

9. **mngr-internal catalog.** Regenerated `services.json` from detent via `generate_services_json.py`, added the curated display name "Tailscale". The `check-changelog` CI job failed (this repo requires a changelog entry per touched project) — caught in the rereview pass, not in local tests (the check only runs in CI with a real base ref). Added the changelog entry; green.

10. **Scope verification (session-195 step).** Drove Detent's real matcher over the full 93-op inventory for each scope, comparing to an independently computed intended set. 0 side-effecting GETs, 0 read-only writes. Committed as a data-driven regression test (session-195's "Future Improvement #1", paid down here). Posted an evidence comment on detent #28.

11. **Gateway e2e (session-195 step).** Stood up an **isolated** latchkey gateway in a throwaway `/tmp/lk-e2e` dir on `localhost:19890` (not the workspace gateway — per session-195's brick lesson, no hot-mod). Provided the tailscale scopes inline in `permissions.json`. Verified: GET /users 200 (read), POST /keys 403 (write denied under read-only), POST /keys 200 with write grant (minted a real `tskey-auth`), then revoked everything. Posted an e2e evidence comment on latchkey #123.

12. **Review responses.** Operator left 3 review comments on detent #28. I added 6 granular scopes (users/devices/keys read+write), updated the coverage test, regenerated the mngr catalog, and replied inline to all three. **Order mistake:** I replied *before* self-review, then self-review caught that my reply (and the code comments) mis-described `tailscale-write-keys` as auth-keys-only. Fixed the code, then posted a correction to my own reply.

13. **Self-review.** Re-read all three diffs critically (not just CI). Found two real issues: the misleading keys-scope comments (security-relevant — a granter could under-estimate the scope), and a dead `credentialCheckCurlArguments` partial-URL placeholder. Fixed both, pushed, CI green.

14. **E2e re-test on reworked scopes.** Stood up the isolated gateway again with the granular scopes. Tested reads from each category (users/devices/keys 200) + scope-narrowing boundaries (403 across areas), and the one safe write (`write-keys` mint + revoke a 1-hour auth key). Skipped `write-users`/`write-devices` — no safe write on a real tailnet. All passed.

15. **Slack handoff.** Posted to `#project-latchkey` tagging Hynek, with the three PR links, merge order, and "sent by minds" signoff.

## 4. Results Observed

**Three paired PRs, all open, cross-linked, CI green:**

| PR | Repo | What | CI |
|---|---|---|---|
| #123 | imbue-ai/latchkey | connector + blacklist paper trail + e2e evidence comments | test x2 success |
| #28 | imbue-ai/detent | 9 scopes + data-driven coverage regression test + scope-verification evidence comment | test success |
| #379 | imbue-ai/mngr-internal | regenerated services catalog (8 permissions) + changelog entry | check-changelog success |

**Connector (latchkey #123):**
- `src/services/tailscale.ts` — `BrowserFollowupServiceSession` minting `tskey-api` from the Keys-page reveal dialog; `TailscaleCredentials` (token + tailnet) in the serialization union; `checkApiCredentials` overridden to `GET /tailnet/{tailnet}/settings`; `getAccount` returns the tailnet.
- `tests/tailscale.test.ts` — URL matching, injection, account, serialization round-trip, credential check (valid/401/404/unknown). 9 tests.
- Registered; both SKILL.md files; recordings blacklist with paper-trail comment.

**Detent scopes (#28):**
- 9 scopes: `tailscale-api`, `read-all`/`write-all`, and 6 granular (`read-users`/`write-users` 12 ops, `read-devices`/`write-devices` 21 ops, `read-keys`/`write-keys` 5 ops). Remaining 55 ops under read-all/write-all.
- `tests/tailscaleOpenapiCoverage.test.ts` + `tests/fixtures/tailscale-openapi-endpoints.json` — real matcher over all 93 ops; each scope verified against its independently computed intended set; 0 anomalies.

**Scope verification table:**

| scope | matched | intended | result |
|---|---|---|---|
| tailscale-api | 93 | 93 | all on api.tailscale.com under /api/ |
| tailscale-read-all | 35 | 35 | exactly the GETs |
| tailscale-write-all | 58 | 58 | exactly the writes (POST 36, PUT 5, PATCH 6, DELETE 11) |
| granular areas | partition | no overlap | users 12 / devices 21 / keys 5 |

**Gateway e2e (first run, read-only vs write grant):**

| request | grant | result |
|---|---|---|
| GET /users | read-all | 200 |
| POST /keys | read-all | 403 (denied) |
| POST /keys | read+write | 200 (minted tskey-auth) |

**Gateway e2e (re-test with granular scopes):**

| grant | request | result |
|---|---|---|
| read-users | GET /users | 200 |
| read-users | GET /devices | 403 (wrong area) |
| read-users | GET /keys | 403 (wrong area) |
| read-devices | GET /devices | 200 |
| read-devices | GET /users | 403 |
| read-keys | GET /keys | 200 |
| read-keys | GET /devices | 403 |
| write-keys | GET /keys | 403 (write has no read) |
| write-keys | POST /keys | 200 (minted 1h auth key) |
| write-keys | DELETE /keys/{id} | 200 (revoked it) |

**Slack:** posted to `#project-latchkey` tagging `<@U050P057ZB4>` (Hynek); `ok: true`, ts `1786694272.444459`.

## 5. Hiccups

- **`checkApiCredentials` returned invalid for a valid token.** My `checkUrl` was a relative path (`/api/v2/tailnet/...`) with no host; `runCapturedAsync` couldn't reach it. Caught by live verification before pushing. Fixed by using the full `https://api.tailscale.com/api/v2/tailnet/` prefix. Lesson: live-verify the built artifact, not just the unit tests (the unit tests mocked curl and didn't catch it).
- **mngr-internal `check-changelog` CI failed.** That repo requires a changelog entry per touched project; the check only runs in CI (needs a real base ref), so local tests didn't catch it. Caught in the rereview pass; added the entry; green. Lesson: this repo's CI has a gate local tests can't see.
- **I replied to a review comment *before* self-review**, then self-review found the reply (and the code) was misleading about `tailscale-write-keys`. Had to post a correction to my own reply. Lesson: self-review *before* replying; replying is part of "notifying".
- **The `github-write-issues` permission was needed** to post PR comments — my `github-write-pulls` grant didn't cover the issues/PR-comments API. Operator approved the permission request; then both evidence comments posted.
- **Fork blocker that never materialized.** I initially assumed I needed a fork of `imbue-ai/latchkey` (the `boweiliu/latchkey` that exists is a stale standalone copy, not a fork) and that fork creation was permission-gated. Then realized the operator's account has direct write access to `imbue-ai/*`, so I pushed feature branches straight to the upstream repos and opened same-repo PRs — no fork needed. Wasted a little time on the fork assumption.
- **No `deskrun` doc exists.** The operator recalled a doc with "more steps, including testing e2e and deskrun and stuff." I searched all of `imbue-ai` (code search) — zero hits for "deskrun"/"desk run"/"desk-run". The fuller process lives in `bowei-thoughts` session 195 (the ngrok connector hardening). I treated that as the reference.

## 6. What's Next

- [ ] **Operator: land the three PRs** in dependency order: detent #28 → latchkey #123 → mngr-internal #379.
- [ ] **OAuth-client connector follow-up (`tailscale-oauth`).** A second connector using the client-credentials flow for a no-90-day-re-login, read/automation workload. Its mint needs a mid-flow human for scope+tag selection, so it can't be as autonomous as the API-access-token connector.
- [ ] **Finer detent scopes for the long tail** if wanted (e.g. `tailscale-policy`, `tailscale-dns`) — I shipped only users/devices/keys as the most common agent action shapes.
- [ ] **The `auth browser` flow through latchkey's own Playwright** was verified in parts (dashboard mint + standalone connector check), not as one unbroken `latchkey auth browser tailscale` run, because this container has no GUI for the user's Google SSO. Closes naturally when a user runs it on their own machine.

## 7. Reflections & Gut Feelings

- **I should have found session 195 before opening the PRs, not after the operator nudged.** `docs/development.md`'s "lint + test + format" bar is the baseline, not the full connector loop. The real definition-of-done (scope-verify against the real OpenAPI surface → commit as a regression test → evidence/paper-trail comments → gateway e2e) lives in the working notes. I treated the baseline doc as the whole process and shipped early. The nudge was justified.
- **Self-review means re-reading the diff critically, not confirming CI is green.** My first "self-reread + rereview pass" was shallow — I checked CI and fixed the changelog but didn't re-read the code. The operator called it out; the second pass found two real issues, one of them security-relevant (a misleading scope comment a granter could under-estimate).
- **Replying is part of notifying.** I replied to review comments, then self-reviewed, then had to correct my own reply. The order should be: address feedback → self-review → reply. The correction worked, but it's churn a single careful ordering would have avoided.
- **The verification work feels good.** Going from "the scopes look right" to driving the real matcher over the real 93-op surface, and then e2e through a live gateway with the granular grants, is the kind of evidence that should ship with every connector. The data-driven regression test (session-195's Future Improvement #1) is a small piece of upstream process debt paid down here.
- **The isolated-gateway e2e pattern is the right one.** Running e2e in a throwaway `/tmp/lk-e2e` dir, not hot-modding the workspace gateway, is exactly session-195's brick lesson applied. No residue; nothing to brick.

## 8. Future Improvements (TODOs to investigate)

- [ ] **Ship the exhaustive matcher check as a committed, data-driven detent test for *every* service's scopes**, not just tailscale. I did it for tailscale; the pattern generalizes — vendor each service's OpenAPI inventory as a fixture and drive the real matcher. This is session-195's Future Improvement #1, half-done (tailscale only).
- [ ] **A `latchkey`/`detent` lint that fails when a catalog grant references a scope with no resolvable schema** — turn session-195's "schema-before-grant" brick into a build-time error instead of a runtime lockout.
- [ ] **Gateway self-heal / safe-mode:** if Detent can't resolve a scope at request time, skip/deny *that one rule* and keep evaluating the rest, not fail the entire permission check. One bad schema shouldn't lock out GitHub.
- [ ] **A `workbench teardown` command** that removes a hot-mod from every uv-cache copy + materialized file + grant, so proving-live can't leave residue (session-195 TODO).
- [ ] **Capture the dashboard's raw network calls** to prove it uses `api.tailscale.com/api/v2`. I inferred it; a Playwright script against the session (or a network/DOM-eval hook in the browser fleet) would give hard proof. Low priority — the inference is well-supported.
- [ ] **Consider an OAuth-client connector (`tailscale-oauth`)** as a follow-up for the long-lived, no-re-login read/automation workload, since the API access token caps at 90 days.

## 9. Helpful scripts from this session

None worth committing. The verification scripts (`/tmp/verify_tailscale.mjs`, `/tmp/verify_tailscale2.mjs`) were throwaway node scripts that imported the built dist and exercised `checkApiCredentials` against the real API; they contained ephemeral token values and were deleted after use. The OpenAPI endpoint inventory that *was* worth committing is vendored as a fixture inside the detent PR itself (`tests/fixtures/tailscale-openapi-endpoints.json`), not as a standalone script.

## 10. Long-running servers / processes

No long-running processes were left running. During the session I started two **isolated, throwaway** latchkey gateways for e2e testing, both now torn down:

- `localhost:19890` — `/tmp/lk-e2e` dir (first e2e run). Gateway process killed; dir removed.
- `localhost:19891` — `/tmp/lk-e2e2` dir (granular-scopes re-test). Gateway process killed; dir removed.

Both used a one-shot `LATCHKEY_ENCRYPTION_KEY` (saved to a temp env file, deleted with the dir). No hot-mods were applied to the workspace's own gateway — per session-195's brick lesson. All test credentials (the minted `tskey-api` API access tokens and the `tskey-auth` CLI keys minted during e2e) were revoked and confirmed dead (401) before teardown.
