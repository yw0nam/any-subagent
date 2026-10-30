# any-subagent — agent guide

- Coding, review and test rules → `CODING_STANDARDS.md`.
- Adding or changing a backend → `docs/adding-a-backend.md`.
- When you delegate an edit of `bin/agent-send`, run agent-send from a copy
  (`cp bin/agent-send "${TMPDIR:-/tmp}/agent-send"`): bash reads a script while it runs,
  so an edit to the running file corrupts the turn.
