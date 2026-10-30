# Adding a backend

A backend is one branch of the `case "$backend"` in `bin/agent-send` plus its
docs. It ships only after it passes the live acceptance checks below with the real
CLI; the stub tests prove the wrapper, not the CLI.

## Code

1. Add the name to `BACKENDS` and a branch to `--models` (a live list, or a line that
   says there is none).
2. Add the branch to the turn's `case`. It runs the CLI non-interactively, writes the
   session id to `$sf` as early as the CLI exposes it, prints
   only the final report on stdout, and exits non-zero when the turn produced no report.
3. Resuming an unknown id must fail. When the CLI silently starts a new session
   instead, detect it (compare ids, or check the id exists before the turn) and call
   `die_stale`.
4. Add a stub CLI and a check to `tests/agent-send.test.sh`: first call, resume by
   name, dead id fails loud.

## Live acceptance checks

Run each with the real CLI from a linked worktree (`git worktree add`), through
`agent-send`:

- [ ] A new session, then a follow-up that recalls a word from the first message.
- [ ] For a backend that resumes a stored id: a dead id
  (`echo dead > "/tmp/any-subagent/$(pwd -P | sha1sum | cut -c1-12)/<backend>-<name>"`)
  exits non-zero with `resume failed`.
- [ ] The agent runs `git commit --allow-empty -m probe` in the linked worktree and the
  commit lands (sandboxes often block the worktree's git dir).
- [ ] A turn whose JSON output exceeds 64 KB (have it read and quote a large file)
  still returns its report and session id.
- [ ] `agent-send --stop` during a long shell loop stops the loop, and `--status`
  then says `idle`.
- [ ] Note the model's default reasoning level and the cost of one typical turn.

## Docs

README (badge, intro list, requirements, the permission paragraph, the Codex
sandbox `writable_roots`), `skills/any-subagent/SKILL.md` (description,
compatibility), `skills/any-subagent/workflows/setup.md` (detect loop, writable
roots), `.claude-plugin/plugin.json` and `marketplace.json` (description, keywords),
CHANGELOG.
