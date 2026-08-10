# latchkey-dev-workbench — TODO / follow-ups

- **Agent self-revoke of its own latchkey permissions.** Right now removing a
  grant requires the user to disconnect the service in the Minds app. There is no
  latchkey/minds-api revoke *endpoint*, but the grant lives in a permissions JSON
  on the Mac (`~/.minds/latchkey/mngr_latchkey/permissions/<id>.json`, the
  `rules` + `schemas` for the scope) that the agent can edit through the bridge.
  Add a small, safe helper (back up the file, remove just the target scope's rule
  and schema, validate JSON, let the next gateway read/restart pick it up) so the
  agent can revoke-before-schema-change on its own instead of gating on the user.
  Motivating case: swapping a service's live scope schema (e.g. coarse `any` ->
  granular read/write) must remove the old grant first, or it dangles and bricks
  the whole permission set. See `docs/huggingface-worklog.md`.
