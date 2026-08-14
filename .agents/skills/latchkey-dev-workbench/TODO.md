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
- **A `workbench teardown` command that removes a hot-mod.** Proving a connector
  live leaves residue in every uv-cache copy, the materialized gateway files,
  and the granted permission. Today none of that is cleaned up, so a durable
  uv-cache patch can reprovision into a broken state days later and brick every
  permission check (`references unknown schema "#/$defs/<svc>-api"`). A
  `teardown <svc>` that removes the connector from the bundle `dist`, the
  catalog/schema from every uv-cache copy, the materialized extensions, and the
  granted scope would make "prove live, then remove" one command instead of an
  error-prone manual undo. Motivating case: the ngrok hot-mod bricked the desktop
  gateway after the operator walked away from it (see
  `docs/build-journal/01-ngrok-connector-scope-verify-and-trim.md`).
