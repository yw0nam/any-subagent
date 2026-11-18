# Contributing to any-subagent

This is the single contributor guide. [`AGENTS.md`](AGENTS.md) carries the project orientation, the engineering principles and the on-demand docs index.

## Workflow

- All work lands through a PR from a worktree. `main` takes no direct commits. From the main checkout:

  ```bash
  git worktree add ../any-subagent-<name> -b <branch> main
  ```

- New or changed behaviour ships its test in the same PR. Commit the failing test first as its own `test:` commit, then the implementation (`feat:` or `fix:`), then any `refactor:`. [`docs/agent-guide/testing.md`](docs/agent-guide/testing.md) holds the test rules.
  The `test-guard` CI job fails a PR that adds more than 20 source lines and changes no test file. The `skip-tests` label bypasses it for a test-free change (rename, config-only, generated code).
- Write issues, issue comments, PR titles and PR bodies in English. Chat in any language.
- Verify observable behaviour yourself (the `agent-send` reply and its `turns.jsonl` record from a run against the real backend CLI, from the live acceptance checks in `docs/adding-a-backend.md`) and paste the output in the PR's Runtime evidence section. Ask the user only for what requires them.

## Code rules

- Comments are one line, in the present tense, and state only what the code cannot say itself. A numeric constant's comment may name the measurement it came from. Decision history, spec citations and issue numbers belong in the issue and the PR body.
- Docs state the current system declaratively and match the code. Change narrative, PR or issue numbers as prose and future or unbuilt work belong in the tracker. `CHANGELOG.md` is the release notes: one entry per release, short sentences, one fact each.

## Breaking changes

The contracts are the `agent-send` command line (flags, arguments, exit codes, stdout as the reply), the config keys in `~/.config/any-subagent/config.json`, the `ANY_SUBAGENT_*` environment variables, the work-log formats (`turns.jsonl` fields, `notes.md`, `inbox.md`), and the state paths under `/tmp/any-subagent/` and `<repo>/.any-subagent/`. `main` moves; releases are the stable surface.

A contract that no release has shipped is deleted outright when a PR drops or replaces it: no compat layer, fallback, warning or migration. The PR:

- marks its title with `!` (`feat!:`, `fix!:`) and carries the `breaking` label;
- names in its body what was removed and what replaces it;
- updates every doc that describes the path, in the same PR.

A contract that a release shipped keeps working through a deprecation period. A PR that replaces it:

- keeps the old path working;
- logs a warning when a caller uses the old path;
- marks the old path deprecated and names its replacement in every doc that describes it;
- names the release that deletes the old path in a one-line comment at the old path and in the release notes.

The removal ships at least one release later, through a PR that follows the first list and deletes the comment and the warning.

Internal modules, names and file layout change freely.

## Review checklist

A review checks every diff against the rules in `AGENTS.md`, the rules above, and these traps:

- Value completeness. A diff that adds a field, a status, an event name or an enum value reaches every consumer of that value. A value one switch, allowlist or fallback leaves unhandled is a blocker.
- Outside input is untrusted. Input from users, the network or another process reaches the core only after a shape and vocabulary check. An unknown value takes a defined fallback.
- Races. Async, poll and teardown code is checked at the entry and the exit of every state: a poll that fires after shutdown, a waiter that never settles, a worker that writes after release.
- One source for the contract. Every consumer reads the one definition of a contract.
- No hardcoding. Endpoints, credentials, models and paths come from the role config (`~/.config/any-subagent/config.json`) and the `ANY_SUBAGENT_*` environment variables.
- Portability. `bin/agent-send` runs on macOS `/bin/bash` 3.2 with BSD userland and on Linux bash 5 with GNU userland; `CODING_STANDARDS.md` § Portability lists the traps.
- Backend contracts. A session id or a report is read from the backend CLI's documented machine-readable output, never a human-readable banner.
- Loud context loss. A dead session exits non-zero through `die_stale`; agent-send never starts a fresh session in its place.

## Finding your way

To learn why code is the way it is, start with `git blame <file>`. When blame lands on a move or refactor commit, find where the token first appeared:

```bash
git log -S'<token>' --reverse
```

## Reporting issues

Open an issue with the matching template in `.github/ISSUE_TEMPLATE/`: bug, feature / task, spike or decision.

## Commits and PRs

- The `pr-title` CI job checks the conventional type and an ASCII subject, and fails a PR body with a line starting with `Co-Authored-By:` or `Generated with`.
- Use conventional commits: `feat:`, `fix:`, `docs:`, `style:`, `refactor:`, `perf:`, `test:`, `build:`, `ci:`, `chore:`, `revert:`. The PR title is the squash-merge subject and uses the same format.
- Fill the [PR template](.github/PULL_REQUEST_TEMPLATE.md): Summary (with a why-this-value line for every new constant, threshold or special-cased status), related issues, related decisions, Runtime evidence, Merge danger and the checklist.

## Before you open a PR

Run the checks CI runs:

```bash
shellcheck bin/agent-send install.sh tests/agent-send.test.sh scripts/ci/test-guard.sh
bash tests/agent-send.test.sh
PATH="/bin:$PATH" bash tests/agent-send.test.sh   # macOS: bash 3.2
```
