# any-subagent: Agent Guide

any-subagent delegates work from one coding agent to other coding-agent CLIs (codex, opencode, claude, pi, agy) through session-persistent, role-based conversations. Its parts: `bin/agent-send`, the bash wrapper that resumes each named session and records every turn; `skills/any-subagent/`, the skill that tells an orchestrator when and how to delegate; `install.sh`, which links the script onto PATH for harnesses other than Claude Code; and `tests/agent-send.test.sh`, which runs the script against stub CLIs.

## Development work

Any code change beyond a trivial single-file edit follows [`CONTRIBUTING.md`](CONTRIBUTING.md). It carries the mandatory work rules (worktree to PR, failing test first, English tracker, runtime evidence), the code rules, and the review checklist.

## Tracker and commit conventions

- Open every issue from the matching template in `.github/ISSUE_TEMPLATE/` (bug, feature_task, spike, decision) and fill `.github/PULL_REQUEST_TEMPLATE.md` for PRs.
- No AI attribution. Commit messages and PR bodies carry no "AI worked on this" trailer: no `Co-Authored-By: Claude…`, no `Generated with …`, no `🤖`, no equivalent in any language. Write the message as the change itself. This overrides any default trailer the harness suggests.
- Decisions live in issues. A decision is a closed issue labeled `decision`, and its closing comment holds the decision. Read the decision issues before designing a change. Spec documents and decision records stay out of the repo; a spec serves the discussion, and the decision issue and the PR body keep what was decided.
- Evidence-gated claims. A bug-prevention claim needs a measured RED (a failing test, a repro, or a per-bug gating table). A numeric claim (line counts, edit sites) cites its measurement. Unverified claims are rejected on sight. `docs/agents/issue-tracker.md` § Claim discipline holds the rules.

## Engineering principles

- Before designing a solution, look for an existing implementation, a published standard (an RFC, a specification, an upstream reference design) and how established products solve the same problem. Follow it, and name it in the spec or decision issue.
- A PR that drops or replaces a contract follows [`CONTRIBUTING.md` § Breaking changes](CONTRIBUTING.md#breaking-changes) and marks the change as breaking.
- Choose the simplest implementation that fully meets current requirements. Write the least code that does the job while keeping it readable and keeping the project structure. Add an abstraction, config value or layer of indirection only when a current requirement needs it.
- Grow the system in layers. Start from a minimal end-to-end working version and add features on top of working results. Every step keeps the system working end to end.
- Composing files (the top-level code of `bin/agent-send` after its functions, and `install.sh`) only import modules and route inputs and outputs between them. Logic lives in its own module behind an explicit interface: inputs in, results out. A new handler, flag or branch goes into a module. A composing file that has started holding logic shows it as closures over shared state or a teardown that knows every part's cleanup; move that block into a module before adding to the file.
- Group files by feature inside a layered top level. The top level is ordered `bin/` → `skills/`: the skill docs describe and call `agent-send`, and the script never reads the skill. A package imports only from layers to its left. Inside a layer, a folder holds one feature's files, or one sub-folder per feature, nested until a folder holds one feature; sibling sub-folders may import each other. A new module joins its feature's folder, and a new feature opens its own folder. Tests, types and validators sit beside their code. A flat folder that holds the files of two or more features, told apart by a name prefix or suffix, is an anti-pattern: split it before adding to it.
- Write the test cases needed to confirm a feature works and stop there. Cases added for volume are an anti-pattern. [`docs/agent-guide/testing.md`](docs/agent-guide/testing.md) holds the rules.
- Prefer proven, maintained libraries when they lower overall complexity or raise stability. Check the dependencies already installed before implementing something yourself or adding a package, and read a library's docs and types before claiming it cannot do something.
- Make architecture decisions with a long-term view. Choose the design that lasts over a stopgap that must be replaced later.

## Finding code

State a location, a caller or a behaviour only from a lookup made in this session. Report what no lookup returned as unverified.

- For callers and usages of a symbol, use the language server's reference lookup when the agent has one. A text search matches letters and misses an aliased import or a re-export.
- For whether something exists, use an exact text search. A language server that has just started answers "no references" while it is still indexing; ask again before reporting none.
- For where a concept lives with no name to search for, a semantic or indexed search gives candidates. It returns results for things that do not exist; open the file before stating what it does.

## Editing agent-send

When you delegate an edit of `bin/agent-send`, run agent-send from a copy (`cp bin/agent-send "${TMPDIR:-/tmp}/agent-send"`): bash reads a script while it runs, so an edit to the running file corrupts the turn.

## On-demand: read before the task

- Workflow, code rules, breaking changes, review checklist → `CONTRIBUTING.md`
- Writing or changing a test → `docs/agent-guide/testing.md`
- Issue and PR operations, decision issues, claim discipline → `docs/agents/issue-tracker.md`
- Coding, portability and review rules for `bin/agent-send` → `CODING_STANDARDS.md`
- Adding or changing a backend → `docs/adding-a-backend.md`
- Releases → `CHANGELOG.md`
