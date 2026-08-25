# Docs to read before building a latchkey connector

The reading order for an agent about to build a new connector. Not "read
everything" — read these, in this order, and know why each exists.

## The indexes (read first, in full)

- **`docs/build-journal/README.md`** — what each journal entry covers. Use it
  to decide which entries matter for your task instead of reading all of them.
- **`docs/build-journal/SYMPTOM-FIX-MAP.md`** — every symptom from every entry,
  mapped to either a shipped fix at an exact `file:line` or a deliberate
  non-fix (with the reason). This is the debugging ledger: when you hit a
  symptom, check here before investigating from scratch.

## The skill (the operational core)

- **`.agents/skills/latchkey-dev-workbench/SKILL.md`** — the checklist: the
  three layers (connector / catalog / enforcement schema), the safety rules,
  the dev-loop accelerators.
- **`.agents/skills/latchkey-dev-workbench/docs/connector-build-playbook.md`** —
  the recon-first procedure: which steps run on the container vs the Mac, the
  browser-recon step that must come before writing selectors, the SIP /
  uv-cache / Terminal-tmux mechanics, and the lessons folded in from every
  shipped connector.
- **`.agents/skills/latchkey-dev-workbench/PROGRESS.md`** — the ngrok build
  journal: the fully worked example, including the desktop topology (where the
  gateway actually runs, what reprovisions what) and the "what did NOT work"
  list.
- **`.agents/skills/latchkey-dev-workbench/TODO.md`** — known sharp edges and
  tracked gaps (e.g. no `workbench teardown` command yet).

## The journal entries that matter for a new connector

Read these in full — they're the failure modes you'll otherwise repeat:

- **02 (HuggingFace)** — bundle-vs-checkout version skew (`getAccount` missing
  → login fails *after* the mint), the self-inflicted gateway outage (use
  `restart_minds.sh`, not the process-kill), and the laptop-sleep outage that
  looked identical to a crash.
- **03 (OpenRouter)** — the headless mint harness that fetches the email OTP
  from Gmail (the biggest iteration-speed unlock; build it first), the bare
  `[role="dialog"]` selector trap, and the scope near-miss (verify against the
  real OpenAPI spec, never theorize).
- **07 (Tailscale)** — the isolated-gateway e2e pattern (throwaway
  `/tmp/lk-e2e`, no hot-mod), the data-driven scope-coverage regression test,
  and the reply-order lesson (address feedback → self-review → reply, not
  reply → self-review → correct yourself).
- **08 (planning feedback)** — the meta-lessons: where the metaprocess doc
  belongs, which procedure phases are easy to skip, and how to write the
  layman explanation.

## The session notes (bowei-thoughts working-sessions)

These are the raw journal behind the journal entries. Read the ones the
indexes point at for your task; for a connector build the load-bearing ones
are:

- **218** (DocuSign planning) — how to classify the auth approach *before*
  building (the OAuth integration-key path was rejected with evidence).
- **226** (auth-shape guides) — the auth-shape taxonomy.
- **246** (final acceptance) — the simul-hotmod pane-idle check and the
  permission-request payload (`agent_id` and `rationale` are both required).
- **248 `recap.md`** — the failure-modes retro: what a realistic-flow test
  needs, what can go wrong (selector timeouts, "scope not in catalog"), and
  how to debug without pestering the operator.

## Upstream sources

- **`imbue-ai/latchkey`** — model the connector on a *current in-tree* service
  (e.g. `linear.ts` for OAuth, `slack.ts` for cookie-riding), not the
  workbench's bundled template (it may target a different latchkey version).
- **`imbue-ai/detent`** — schema conventions (`src/schemas/builtin/`).
- **`imbue-ai/mngr-internal`** — the catalog generator
  (`generate_services_json.py`) and the changelog-entry naming rule (named
  after the branch).

## Notes on the metaprocess itself

- The discovery metaprocess doc lives in **this repo** (the project it
  serves), not in the mixed-project session journal. If you're looking for it,
  start here.
- Check **all branches** of this repo (`git ls-remote`), not just main — the
  journal and playbook have diverged before.
