# Coding standards

Judgement rules for `bin/agent-send`, its tests and docs. CI enforces the mechanical
ones (`shellcheck`, the stub tests on Linux bash 5 and macOS bash 3.2); a reviewer
enforces these.

## Design

- Look at how the backend CLI documents its machine-readable output (JSON events,
  session flags) before writing an extraction. Parse the documented contract, never a
  human-readable banner.
- Write the least code that fully meets the requirement. A flag, config key or helper
  exists because a current caller needs it. A helper has two or more callers.
- Context loss is loud. A dead session exits non-zero through `die_stale`, which names
  the state file to delete; agent-send never starts a fresh session in its place.
- agent-send's own bookkeeping (the turn record) warns only and keeps the reply: a
  non-zero exit there invites a re-send that costs another turn. A lost session still
  exits non-zero.
- Every backend can write and runs non-interactively. A sandboxed backend still needs
  network and the repo's git dirs, including a linked worktree's (see the codex branch).

## Portability

The script runs on macOS `/bin/bash` 3.2 with BSD userland and on Linux bash 5 with GNU
userland. Traps CI does not always catch:

- `case` inside `$( )` misparses on bash 3.2; run the branch in a `( )` subshell.
- No `declare -A`, `mapfile`, `wait -n`, `${x,,}`, `setsid`.
- `stat` flags differ; read a file's mtime with `date -r <file>`. `sed -i` differs; avoid it in the script.

## Compatibility

A change that drops or replaces a flag, config key, backend or log format deletes the
old path outright, with no compat layer, fallback, warning or migration code. CHANGELOG
marks it as breaking and gives the one-line migration (2.0.0 and 2.3.0 are examples).

## Tests

- Tests run against stub CLIs on PATH, never a real backend.
- One numbered check per behaviour. The failing test is its own
  `test:` commit before the `feat:` or `fix:` commit.
- A claim that a change prevents a bug cites a measured RED.

## Comments and docs

- A comment says what the code cannot: the reason, the backend quirk, the measured
  failure. One line where it fits, present tense.
- A deliberate shortcut carries a `ponytail:` comment that names its ceiling.
- README and skill docs describe the current state. CHANGELOG describes each release
  in short sentences, one fact each.

## Commits and PRs

- Commits and PRs are in English, with no AI attribution trailer.
- Specs and decision notes stay out of the repo; a decision lives in the code, the PR
  body and CHANGELOG.
