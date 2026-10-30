# any-subagent

![CI](https://img.shields.io/github/actions/workflow/status/yw0nam/any-subagent/ci.yml?branch=main&style=flat-square&label=ci)
![License](https://img.shields.io/github/license/yw0nam/any-subagent.svg?style=flat-square)
![Version](https://img.shields.io/badge/version-2.2.0-blue.svg?style=flat-square)
![Backends](https://img.shields.io/badge/backends-codex%20%C2%B7%20opencode%20%C2%B7%20claude%20%C2%B7%20pi%20%C2%B7%20agy%20%C2%B7%20qwen-8A2BE2?style=flat-square)
![Harness](https://img.shields.io/badge/harness-Claude%20Code%20%C2%B7%20Codex-2ea44f?style=flat-square)

**Run other coding-agent CLIs as background subagents.** any-subagent lets
your orchestrator — Claude Code or Codex — delegate work to
[codex](https://github.com/openai/codex),
[opencode](https://opencode.ai), [pi](https://github.com/earendil-works/pi),
[agy](https://antigravity.google/docs/cli/using/) (Antigravity CLI),
[qwen](https://github.com/QwenLM/qwen-code) (Qwen Code), or
another `claude` through **session-persistent, role-based conversations**. The
orchestrator writes the spec, farms out execution, sends review feedback to
the *same* conversation, and keeps the final quality gate.

Think of it as `SendMessage` for external CLIs: every delegated conversation
gets a durable name, and every follow-up resumes it with full context intact.

![Claude Code sends fizzbuzz.py to impl (pi) and its tests to impl2 (opencode), both in the background, then runs the tests once both finish](docs/demo.gif)

```
You ──► Claude Code / Codex  (orchestrator: spec, judgment, quality gate)
              │
              │  agent-send spec-review parser-spec "Review this spec ..."
              ├────► codex      session "parser-spec"
              │  agent-send impl parser "Implement per SPEC ..."
              ├────► codex      session "parser"
              │  agent-send docs parser-docs "Document the module ..."
              └────► opencode   session "parser-docs"
```

## Why

Multi-agent setups usually break down in one of three ways: the delegated
agent forgets everything between messages, parallel tasks race each other, or
the orchestrator quietly outsources its judgment. any-subagent is built around
fixes for all three:

- **Conversations, not fire-and-forget prompts.** Session ids are persisted on
  disk per working directory, so "tests failed, fix it" reaches the agent that
  wrote the code — with its context.
- **Sessions are addressed by name, never by "last".** Parallel delegations
  can't hijack each other's threads. Git worktrees isolate automatically.
- **Delegate execution, never judgment.** The skill hard-codes the cycle:
  the orchestrator writes the spec, external agents execute, the orchestrator
  verifies. An expired session fails loudly instead of silently starting a
  fresh one.

## How it works

You just talk to your orchestrator. A typical session:

> **You:** Build the tokenizer module. Get the spec reviewed first, then
> implement it, and have the docs written up.

The orchestrator, with this plugin enabled:

1. Writes the spec itself, then sends it to your review role:
   `agent-send spec-review tokenizer-spec "Review this spec: ..."`
2. Folds feedback in and re-asks **in the same session** until it passes —
   the reviewer remembers its previous objections.
3. Delegates implementation and docs **in parallel, in the background**: `agent-send impl tokenizer "..."`,
   `agent-send docs tokenizer-docs "..."`
4. Runs the tests itself. On failure, sends the failing output back to the
   `impl` session — the agent that wrote the code debugs it with full context.

Which CLI plays which role is **your configuration, not hardcoded** — roles
are free-form names you define once, per user.

## What's inside

| Component | What it does |
|---|---|
| `skills/any-subagent/` | The skill: `SKILL.md` routes to `workflows/setup.md` (config interview) or `workflows/delegate.md` (cycle, quick reference, common mistakes) |
| `<repo>/.any-subagent/<session>/` | Per-session work log: `turns.jsonl` (one line per message, written by agent-send: spec, report, role, backend, model, exit code, duration), `notes.md` (the agent's reasoning) and `inbox.md`; read it back with `agent-send --log <session>` |
| `bin/agent-send` | ~450-line bash wrapper; Claude Code puts it on the Bash tool's PATH automatically, elsewhere `install.sh` links it |
| `install.sh` | Links `agent-send` onto PATH (and the skill into `~/.codex/skills` for a plain git clone) — needed by every harness except Claude Code |
| `tests/agent-send.test.sh` | Runs `agent-send` against stub `claude` and `codex` CLIs: session create, resume by name, loud failure on an expired session, roles, per-session work logs. CI runs it with shellcheck |
| `docs/demo.tape` | Renders `docs/demo.gif` with [VHS](https://github.com/charmbracelet/vhs) inside Claude Code, against your `impl` and `impl2` roles |
| `.claude-plugin/marketplace.json` | This repo doubles as its own plugin marketplace; Codex reads the same manifest |

Write roles report like a colleague, not a transcript: every message tells
them to append their reasoning to `<repo-root>/.any-subagent/<session>/notes.md`,
and to reply with a structured report (summary, changes, verification, notes,
log path) instead of a transcript. `agent-send` itself appends one JSON line per
message to `turns.jsonl` next to it — the spec sent, the report, role, backend,
model, exit code and duration — so the record does not depend on the agent, and
`jq` can query it. The orchestrator's context stays clean and the
detail is one `agent-send --log <session>` away. The directory ignores itself,
so the logs never appear in `git status`.

Changed your mind mid-run? `agent-send --note <session> "..."` queues an
amendment in the session's inbox; write roles re-read it between steps, apply
it, and record it in their notes. The CLIs cannot be interrupted mid-turn, so this
is cooperative — it lands at the agent's next step boundary.

No MCP server, no daemon, no polling. `agent-send` maps each
`(cwd, backend, session-name)` to the backend's native session id and resumes
it — the CLIs themselves keep the real conversation history.

## Requirements

- An orchestrator with a shell tool: [Claude Code](https://code.claude.com) v2.x+
  or [Codex](https://github.com/openai/codex) v0.154+
- At least one backend installed and authenticated:
  `codex` · `opencode` · `claude` · `pi` · `agy` · `qwen`
- `jq` 1.6 or later

## Installation

### Claude Code

```
/plugin marketplace add yw0nam/any-subagent
/plugin install any-subagent@yw0nam
```

Or from the shell: `claude plugin marketplace add yw0nam/any-subagent && claude plugin install any-subagent@yw0nam`.
Nothing else to do — the plugin's `bin/` lands on the Bash tool's PATH.

### Codex

Codex reads the same marketplace manifest:

```bash
codex plugin marketplace add yw0nam/any-subagent
codex plugin add any-subagent@yw0nam
~/.codex/plugins/cache/yw0nam/any-subagent/*/install.sh   # puts agent-send on PATH
```

The last step is the one Codex doesn't do for you: plugins contribute skills,
not PATH entries, so `agent-send` has to be linked once (into `~/.local/bin`,
or `ANY_SUBAGENT_BIN=<dir>` elsewhere). Re-run it after upgrading the plugin.

### Any harness, from a clone

```bash
git clone https://github.com/yw0nam/any-subagent && ./any-subagent/install.sh
```

Links `agent-send` onto PATH, plus the skill into `~/.codex/skills/` when Codex
is installed and the plugin isn't.

### Codex sandbox

A delegated CLI inherits the sandbox of the session that spawned it, and
Codex's default `workspace-write` denies both the network and writes to the
backend's own state dir — so delegation fails or loses its sessions. Write
`~/.codex/any-subagent.config.toml`:

```toml
sandbox_mode = "workspace-write"

[sandbox_workspace_write]
network_access = true
# only the backends you delegate to
writable_roots = ["~/.codex", "~/.claude", "~/.local/share/opencode", "~/.pi", "~/.gemini", "~/.qwen"]
```

and run `codex --profile any-subagent`. Claude Code needs no equivalent.

## Setup

Ask your orchestrator:

> set up any-subagent roles

It detects installed CLIs, queries the models each backend can use
**right now** (`agent-send --models` — codex, opencode, pi and agy expose live
catalogs, so new releases show up without a plugin update), interviews you —
which roles you want, which backend and model per role — writes
`~/.config/any-subagent/config.json`, and smoke-tests each role.
Example:

```json
{
  "roles": {
    "spec-review": { "backend": "codex",    "model": "gpt-5.5" },
    "impl":        { "backend": "codex",    "model": "gpt-5.5" },
    "docs":        { "backend": "opencode", "model": "opencode-go/qwen3.7-plus" },
    "research":    { "backend": "pi",       "model": "anthropic/claude-sonnet-5" }
  }
}
```

Role names are free-form. `model` is optional (backend default when omitted).
For pi, the model string also carries the reasoning level as a suffix —
`"zai/glm-5.3-flash:high"` (`off`, `minimal`, `low`, `medium`, `high`, `xhigh`,
`max`). agy picks it by model id instead (no `--effort`) — `gemini-3.8-flash-high`,
straight from `agent-send --models agy`. qwen takes the model ids configured
in `~/.qwen/settings.json` (`modelProviders`), e.g. `qwen3.8-max`.
Every role can write, because every role journals its work to
`.any-subagent/<session>/notes.md` — codex runs with sandbox `workspace-write`
plus the repository's git dirs as writable roots (the common `.git` and, in
a linked worktree, its own `.git/worktrees/<name>`), so it can commit from a
worktree; opencode `--auto`, claude `--permission-mode acceptEdits`, pi with its
`edit`/`write` tools, agy with `--sandbox --dangerously-skip-permissions`
(headless agy denies any tool not allow-listed, and one denied command ends
the turn with no report; the sandbox confines its terminal instead), qwen
with `--yolo --sandbox` (headless qwen drops its shell tool in every other
approval mode; the sandbox is sandbox-exec on macOS, docker or podman on Linux). Scope a
role by the worktree you send it to, not by taking its tools away.

## Usage

Mostly you don't touch `agent-send` yourself — the orchestrator drives it. The
command, for when you do:

```bash
# Send as a role; first call creates the session
agent-send impl parser "Implement the tokenizer per /abs/path/SPEC.md ..."

# Follow-up to the SAME conversation: same role + same session name
agent-send impl parser "Tests fail: expected X got Y. Fix it."

# Introspection
agent-send --roles     # configured roles
agent-send --list      # sessions for this directory
agent-send --models    # models each backend can use right now

# Escape hatch: bypass roles, talk to a backend directly
agent-send -m gpt-5.5 codex quickfix "..."
```

## Design notes

- **Session state** lives in `/tmp/any-subagent/<cwd-hash>/` — one plain-text
  file per conversation holding the backend's session id. Delete a file to
  start that conversation over; delete the directory to reset everything.
- **Worktree-safe by construction.** State is keyed on the working directory,
  so parallel git worktrees get independent sessions with zero setup.
- **Failures don't poison state.** A failed first call writes no session
  file; a failed resume exits non-zero and tells you which file to delete.
  Context loss is always visible, never silent.
- **Completion notification is free.** Each `agent-send` call is a normal
  process that exits when the reply is complete — background it and a harness
  that watches processes (Claude Code) wakes you up; one that doesn't (Codex)
  just polls the log. No hooks, no marker files.

## Philosophy

- **Delegate execution, never judgment** — the spec and the merge decision stay with the orchestrator
- **Conversations over prompts** — feedback goes to the agent that did the work
- **Fail loud** — an expired session is an error, not a fresh start
- **No infrastructure** — a few CLIs, one bash script, files on disk

## Uninstall

```
/plugin uninstall any-subagent@yw0nam      # Claude Code
codex plugin remove any-subagent@yw0nam    # Codex
```

Then `rm ~/.local/bin/agent-send` if `install.sh` linked it. Config
(`~/.config/any-subagent/`) and session state (`/tmp/any-subagent/`) are plain
files — delete them anytime.

## License

[MIT](LICENSE)
