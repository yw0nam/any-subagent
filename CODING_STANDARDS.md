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
- Context loss is loud. A dead session, a missing id or an empty report exits non-zero
  and names the file to delete; agent-send never starts a fresh session in its place.
- A failure after a billable turn warns and keeps the reply. A non-zero exit invites a
  re-send that costs another turn.
- Every backend gets the same posture: it can write, it runs non-interactively, and its
  sandbox (when it has one) keeps network and the repo's git dirs.

## Portability

The script runs on macOS `/bin/bash` 3.2 with BSD userland and on Linux bash 5 with GNU
userland. Traps CI does not always catch:

- `case` inside `$( )` misparses on bash 3.2; run the branch in a `( )` subshell.
- No `declare -A`, `mapfile`, `wait -n`, `${x,,}`, `setsid`.
- `stat` flags differ; use `date -r <file>`. `sed -i` differs; avoid it in the script.

## Compatibility

The plugin is public. Released behaviour (a flag, a config key, a backend, the log
format) keeps working until a release that announces its removal: the code carries a
comment naming that release, the path prints a warning on stderr, and CHANGELOG lists
it. Code no release has shipped is deleted outright. The owner can decide an
exception; the PR body states it.

## Tests

- Tests run against stub CLIs on PATH, never a real backend.
- One check per behaviour, named for the behaviour. The failing test is its own
  `test:` commit before the `feat:` or `fix:` commit.
- A claim that a change prevents a bug cites a measured RED.

## Comments and docs

- A comment says what the code cannot: the reason, the backend quirk, the measured
  failure. One line where it fits, present tense.
- A deliberate shortcut carries a `ponytail:` comment that names its ceiling.
- README and skill docs describe the current state. CHANGELOG describes each release
  in short sentences, one fact each.

## Commits and PRs

- Conventional commit titles, in English, with no AI attribution trailer.
- Specs and decision notes stay out of the repo; a decision lives in the code, the PR
  body and CHANGELOG.
