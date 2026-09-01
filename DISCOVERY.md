# Latchkey Dev Workbench — DISCOVERY (START HERE)

The one entry point for an agent arriving fresh on latchkey connector work
(new workspace, vague task, or a topic that feels familiar). Read this file
fully before doing anything else.

This is the cross-repo map: where each kind of knowledge lives, how to reach
the capabilities (deskrun, the git proxy) everything hangs off, and the
standing rules learned the expensive way. It is NOT the build procedure — the
canonical how-to is `docs/connector-build-procedure.md` + the skill's
`docs/connector-build-playbook.md`. This doc exists because three sessions
needed operator rescue for knowledge that already existed (see "Why this doc
exists" at the bottom).

## 1. The map: where things actually live

| What | Where | How to reach it |
|---|---|---|
| This discovery doc (you are here) | `latchkey-dev-workbench` repo → `DISCOVERY.md` | top-level of this repo |
| Connector build procedure (with contingencies) | `latchkey-dev-workbench` repo → `docs/connector-build-procedure.md` | this repo |
| Docs to read before building | `docs/connector-docs-to-read.md` | this repo |
| Layman explanation | `docs/connector-explained-layman.md` | this repo |
| Build journal + symptom->fix map | `docs/build-journal/` (README + SYMPTOM-FIX-MAP + entries 01-08) | this repo |
| The skill (operational core) | `.agents/skills/latchkey-dev-workbench/SKILL.md` + `docs/connector-build-playbook.md` + `PROGRESS.md` | this repo |
| Session journals (the raw history behind the journal entries) | `boweiliu/bowei-thoughts-2` repo → `working-sessions/NNN-*/session.md` | git proxy (§3) |
| The live workbench checkout (most current, may be ahead of the published repo) | Mac: `~/code/latchkey-dev-workbench` | via deskrun (§2) |
| Mac-side hot-mod tooling (patchers, refresher, probe scripts) | Mac: `~/tmp/minds_data/` (+ `xfer/`) | via deskrun (§2) |
| Repair scanners (latchkey desync doctor) | `bowei-thoughts-2` → `working-sessions/256-*/repair_latchkey_credentials.mjs`, `263-*/scan_latchkey_grants.mjs` | git proxy (§3) |
| Other notes repo | `boweiliu/bowei-thoughts` (older) | git proxy (§3) |
| Chat transcripts (every agent, this host, present or destroyed) | `$MNGR_HOST_DIR/agents/*/events/*/common_transcript/events.jsonl` + `$MNGR_HOST_DIR/preserved/` | `find-transcripts` skill |
| Other workspaces | via the `minds-api` skill | per-workspace grants |

**Lesson baked into this table:** the newest knowledge is often NOT in the
published repos — it's in the live checkout on the Mac or in the newest session
folders. If the repos disagree with the session notes, the session notes win.

## 2. deskrun: running commands on the operator's Mac (from ANY workspace)

The single most missed capability. `deskrun` runs a shell command on the
operator's Mac in one call. It is **self-contained** — no SSH, no other
workspace, no pre-existing setup on your side:

1. The print bridge (`com.minds.printbridge`) is a launchd agent **already
   running on the Mac**; it polls `~/tmp/minds_data/printbridge/cmd/` and
   executes what lands there.
2. The `deskrun` script is checked in at
   `.agents/skills/latchkey-dev-workbench/bin/deskrun` in the
   `latchkey-dev-workbench` repo (also copied to `system/scripts/deskrun` on
   workbench workspaces). It just PUTs a `.cmd` file through the latchkey
   file-sharing proxy and polls for the result.
3. The only grant you need: **file-sharing WRITE to `~/tmp/minds_data`**.
   Request it like any permission:

```bash
latchkey curl -XPOST http://latchkey-self.invalid/permission-requests \
  -H 'Content-Type: application/json' \
  -d "{\"agent_id\": \"$MNGR_AGENT_ID\", \"type\": \"file-sharing\", \"payload\": {\"path\": \"~/tmp/minds_data\", \"access\": \"WRITE\"}, \"rationale\": \"...\"}"
```

4. Point the script at the Mac's home (container `$HOME` ≠ Mac home):
   `echo /Users/bowei > ~/.config/latchkey-dev-workbench/mac_home`
   (or export `MINDS_MAC_HOME=/Users/bowei`).
5. Verify: `deskrun 'echo CONNECT_OK; hostname'`.

Caveats (hard-won): the bridge runs **zsh** (quote carefully; `unsetopt equals`
matters); it times out ~60s so split long polls; the channel dies while the
Mac's gateway is down; writing into the SIP-protected `Minds.app` bundle needs
the **Terminal-backed `minds-deploy` tmux** (App Management TCC grant) — drive
it via `deskrun 'tmux send-keys ...'`, never a bare `cp` (see the playbook).

**Restarting Minds itself is a special case of "the channel dies while the
Mac's gateway is down": every deskrun/file-sharing call is proxied through
`minds-api-proxy`, which the Minds backend itself hosts (`127.0.0.1:53741`).
Quitting Minds kills that proxy, so a *second* deskrun call to relaunch it has
no channel to travel over.** Never split a Minds restart into two calls (quit,
then relaunch). Use the existing `restart_minds.sh` (on the Mac at
`~/tmp/minds_data/restart_minds.sh`) in ONE deskrun call — it force-quits
(`killall -9`, since a graceful quit can hang on an undismissable confirmation
dialog), waits for the process to actually die, then loops on `open -a Minds`
with retries until a process reappears, all locally on the Mac with no
round-trip back to the container in between. By the time the script finishes
and print-bridge reports completion, the gateway is already back up. Learned
the expensive way during e2e testing of mngr-internal PR #760: an agent split
the restart into two calls, stranded itself with no channel, and needed the
operator to manually relaunch the app.

**Do NOT** reach for `minds-api`/SSH to another workspace just to run Mac
commands — deskrun is strictly simpler and already running.

## 3. Git and API access from a fresh workspace

- The local latchkey gateway proxies GitHub git smart-HTTP: clone/push with
  `git -c "http.extraHeader=X-Latchkey-Gateway-Password: $LATCHKEY_GATEWAY_PASSWORD" \
  clone "$LATCHKEY_GATEWAY/gateway/https://github.com/<owner>/<repo>.git"`.
  Gated by `github-git-read` / `github-git-write` — request them like any
  permission. No token ever enters the container.
- REST API: `latchkey curl https://api.github.com/...` (scope `github-rest-api`).
- The gateway's primary port can flap (1989↔1990); poll for recovery, don't
  fight the secondary.

## 4. Standing process rules (each was learned the expensive way)

- **After EVERY push, check CI** (`gh pr checks` or the check-runs API).
  "Mergeable" ≠ green. A red you didn't notice is the most common miss — it
  happened on latchkey#122 and sat red in front of the reviewer for 9 days.
- **Posting evidence ≠ finishing the review.** A topic is open until the
  reviewer is satisfied or the PR merges. Report honestly what's *done* vs
  *attempted*.
- **Hot-mods are ephemeral.** Any Minds app update reverts them; stored grants
  and credentials can desync and brick ALL latchkey traffic. The repair is
  journaled: `256-*/latchkey-hotmod-desync.memory.md` (+ the two scanner
  scripts). If `Unknown schema X` / `Invalid credential data` appears, go there
  first.
- **Schema before grant; revoke before schema swap.** Granting a scope Detent
  can't resolve 403s everything.
- **Commits on the PR branches are authored as the operator:** export
  `GIT_AUTHOR_NAME=boweiliu GIT_AUTHOR_EMAIL=boweiliu@users.noreply.github.com`
  (+ COMMITTER variants) — the environment's agent identity overrides repo
  config otherwise.
- **Probe first, plan second.** When a task touches the Mac/gateway, the first
  action is a ~1s `deskrun` probe (is the bridge alive? what version is
  installed?) — not after planning (session 210 process lesson).

## 5. The search playbook ("I suspect we've done/found this before")

In order — stop as soon as you hit paydirt:

```bash
# 1. This repo's docs + build journal by keyword:
grep -rln "<keyword>" docs/ .agents/skills/latchkey-dev-workbench/ | sort
# 2. The session journals in bowei-thoughts-2 (the raw history):
#    clone it (§3), then: grep -rln "<keyword>" working-sessions/ | sort
#    Read the NEWEST hit first; every session doc ends with a
#    "Prior session summary docs" section — follow the chain backwards.
# 3. The live checkout + tooling on the Mac (may be ahead of all repos):
deskrun 'ls ~/tmp/minds_data; ls ~/code/latchkey-dev-workbench'
# 4. Transcripts of past agents on this host (find-transcripts skill).
# 5. Only then: minds-api / SSH to another workspace, or ask the operator.
```

Two failure modes this ordering prevents: re-deriving something journaled
(wasted session), and assuming a capability is unreachable because the obvious
path is down (the deskrun bridge is usually still up).

## 6. Conventions that keep this discoverable (maintain them)

- Every session folder (in `bowei-thoughts-2/working-sessions/`) gets a
  `session.md` in the standard format, ending with a **"Prior session summary
  docs"** link list (backward chain) and a **scripts/artifacts** section with
  full paths.
- When a session produces a *reusable procedure* (not just findings), promote
  it: into this workbench repo (published) AND link it from the relevant
  session docs. Journals rot; playbooks compound.
- When you discover the map above is wrong or incomplete, **fix this DISCOVERY.md
  in the same commit** as your session doc.
- Name docs so they sort and grep well: topic-first (`docusign-*.md`,
  `latchkey-*.md`), never clever.

## Why this doc exists

Three times, an agent needed operator rescue for knowledge that already existed:

1. **Session 248** — the operator had to interrupt: "go back and reread the
   original task and the docs you're supposed to know." The agent hadn't found
   the workbench playbook and was reinventing (wrongly) how to reach the
   gateway.
2. **Sessions 256 → 263** — the positive proof: a well-journaled repair
   (memory note + scripts) turned a brick that took a long session to diagnose
   into a minutes-long replay on a different machine.
3. **Session 264 (kimi-k3-1 on latchkey-workbench-minds041)** — a fresh
   workspace continued the DocuSign review work. The agent searched session
   notes + 5 repos and still missed that (a) deskrun works from any workspace
   with one file-sharing grant, and (b) latchkey#122's CI had been red for 9
   days. Both facts were in the docs it had read — but not stated where a
   fresh agent starts, and no index pointed at them.

The metaprocess fix is not "write more docs" — it's this: **one obvious entry
point (this file), a small map of where each kind of knowledge lives, and the
bootstrap recipes for the capabilities (deskrun, git proxy) that everything
else hangs off of.** If you're reading this because you were lost: it worked.
Update it.
