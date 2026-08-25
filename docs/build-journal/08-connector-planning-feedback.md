# 08 — Connector planning feedback: doc discovery, procedure gaps, and the layman explanation

Feedback from the operator (2026-08-23) on a planning exercise: "write a new
latchkey connector from scratch for, e.g. outlook — which docs, what procedure,
then explain it in layman's terms." The first attempt missed on all three axes.
This doc records the corrections so the next attempt (and the next agent) does
better. It belongs in the build journal because these are process lessons, not
session findings.

## 1. Doc discovery — where the metaprocess doc does NOT belong

**Mistake:** I wrote the discovery metaprocess doc as `working-sessions/README.md`
in `bowei-thoughts-2`. The operator: *"don't put this in the working-session of
bowei-thoughts, that contains a bunch of mixed projects."*

**Why it's wrong:** `working-sessions/` is a journal of *many unrelated projects*
(factorio, orchard, ideas-server, printing, ...). A connector-work discovery doc
buried there is unfindable by the next agent doing connector work — they'd have
to already know to look in a mixed-project journal. The doc's own lesson ("one
obvious entry point") was violated by its placement.

**Correct placement:** the metaprocess doc belongs in the **latchkey-dev-workbench
repo** (the project it serves), at the top level or in the skill — where an agent
doing connector work actually starts. The session journal should *link* to it,
not host it.

**Also missed:** the workbench repo has **branches other than main**
(`docs/build-journal`, `playbook-and-huggingface-example`). I cloned main and
stopped. The operator: *"check on more recent branches other than main, there's
probably updates."* (In this case main was current, but the *check* is the
obligation — the branches exist and have diverged before.)

**And:** the session notes have **indexes/manifests** I didn't read in full —
`docs/build-journal/README.md` (the entry index) and
`docs/build-journal/SYMPTOM-FIX-MAP.md` (the symptom→fix ledger). The operator:
*"are there also more helpful indexes/manifests? i assume you haven't read all of
those in full yet."* I had grepped for keywords; I had not read the indexes that
would have told me which entries mattered.

## 2. Procedure gaps — what the first plan missed

The first procedure (classify → recon → build → schema → catalog → hot-mod →
upstream → teardown) was the happy path. The operator's corrections, by phase:

- **P1 (classify/recon):** missing a step to **check the current hot-mod status**
  and **whether other agents are simultaneously editing/hotmodding**. Session 246
  had the operator's explicit "watch out for simul hotmod actions" warning; the
  playbook's pane-idle check exists precisely because two agents patching the same
  bundle clobber each other. The plan must start with "is the gateway already
  hot-modded, and is anyone else mid-hot-mod right now."

- **P2–P4 (build/schema/catalog):** missing **how to test locally (on this box)
  before hotmod testing on the deskrun + minds-deploy path**. The isolated-gateway
  e2e pattern (entry 07: throwaway `/tmp/lk-e2e` on `localhost:19890`, scopes
  inline in `permissions.json`) exists precisely so you can prove the connector
  and the scope enforcement *without* touching the Mac at all. The first plan
  jumped straight from "build" to "hot-mod the live gateway."

- **P5 (prove live):** missing **how to avoid pestering/repeatedly blocking on the
  operator** — what to do when the initial live-proof fails, how to gracefully
  debug and recover. Session 248's `recap.md` is the retro doc for exactly this
  (the operator had to say "pause here, i dont think you know what you should be
  doing"). I skipped it. The lessons: the operator's approval + SSO is a scarce,
  one-shot resource — don't burn it on an untested flow; debug with
  `LATCHKEY_DISABLE_SPINNER=1` + screenshots, not by asking the operator to retry;
  and recover from gateway outages with patience (`restart_minds.sh`, poll
  ~35-45s), not escalation (session 02's self-inflicted outage + the
  laptop-sleep outage that looked identical to a crash).

- **P6 (upstream):** missing **how to self-review and get it past the upstream
  reviewer**. Entry 07's order mistake: reply → self-review → correct your own
  reply is churn; the right order is **address feedback → self-review (re-read
  the diff critically) → reply**. Plus the standing rules: check CI after every
  push, pre-trim prose when past-session notes call out the reviewer's prose
  preferences, author commits as the operator.

- **Overall:** missing **contingency info for how to debug, how to log and trace,
  how to repair and recover**. The SYMPTOM-FIX-MAP is the ledger for this — every
  symptom either has a shipped fix at a `file:line` or is a deliberate non-fix.
  The plan should point at it, not rediscover symptoms.

## 3. The layman explanation — what was wrong

The first attempt used a "key cabinet" analogy and it failed on five counts:

1. **Inconsistent analogies.** "Key cabinet," "spare key," "ceremony at the front
   desk," "doorman's badge" — three different metaphors in one paragraph. The
   operator: *"these aren't good analogies, i'm still confused. explain using a
   consistent analogy."* Pick ONE and carry it through.

2. **Missing the password.** The explanation never mentioned that the flow is
   driven with a **real username and password** — and that the password is only
   for **bootstrapping** (the first sign-in that mints the stored credential),
   not something the connector keeps or re-uses. A layman reading it would
   reasonably ask "wait, does this thing have my password?"

3. **"Connector" is jargon.** *"connector is confusing, idk what that means."*
   Name the thing by what it does, not by the codebase's term for it.

4. **The "rules before keys" analogy didn't explain the WHY** — because there
   isn't a good why. *"also confusing analogy that doesn't explain they WHY --
   cuz there isn't a good why. just acknowledge that."* The honest answer: the
   rules system has a bug-shaped behavior where a key without rules jams every
   other key, and we work around it by writing rules first. Don't dress it up as
   a principled design decision; it isn't one.

5. **"Sneak it into the building" is the wrong image for the hot-mod.** *"also
   wrong analogy, 'into the building' is not where the hotmod is going (it's not
   hotmodding the target webapp)."* The hot-mod patches *our own* app (the Minds
   app on the operator's Mac), not the service's webapp. The analogy made it sound
   like we were modifying Outlook/DocuSign itself.

**Meta-lesson on explaining:** the layman version is not a decoration on the
technical version — it's a separate deliverable that has to survive a reader who
will not meet you halfway. Spend the time. One analogy, honest about the parts
that are workarounds, no unexplained jargon, and no step that only makes sense if
you already understood the technical version.
