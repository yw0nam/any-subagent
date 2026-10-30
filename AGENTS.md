# any-subagent — agent guide

- Coding, review and test rules → `CODING_STANDARDS.md`.
- Adding or changing a backend → `docs/adding-a-backend.md`.
- A delegated agent that edits `bin/agent-send` runs through a copy of the script
  (`cp bin/agent-send "$TMPDIR/agent-send" && "$TMPDIR/agent-send" ...`): bash reads a
  script while it runs, so an edit to the running file corrupts the turn.
