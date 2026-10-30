# Workflow: setup / reconfigure the roles

Run this when `~/.config/any-subagent/config.json` is missing, or the user asks
to set up or change their roles.

0. Make sure `agent-send` runs: `command -v agent-send`. If it is missing, show
   the user `install.sh` at the plugin root and run it only after they say yes
   (Claude Code links it for you; no other harness does).
1. Detect installed CLIs: `for c in codex opencode claude pi agy; do command -v $c; done`
2. Query the models each installed backend can use right now:
   `agent-send --models`. Model catalogs change too often to trust memory —
   only offer names from this live list.
3. Interview the user — with your harness's structured-question tool if it has
   one (Claude Code: AskUserQuestion), otherwise by asking in plain text: which
   roles they want (names are free-form, e.g. `spec-review`, `impl`, `docs`),
   which backend serves each role, model per role picked from the step-2 list
   (omit to use the CLI's own default).
   If a proposed role targets a model the current harness runs natively, steer
   it to the harness's own subagent mechanism instead of configuring it here.
4. Write the config and confirm with `agent-send --roles`:

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

   For pi, a reasoning level can be appended to the model —
   `"zai/glm-5.3-flash:high"` (off/minimal/low/medium/high/xhigh/max). agy
   picks it by model id instead (no `--effort`): `gemini-3.8-flash-high`.
   A role may set `"fallback"` — another model of the same backend, used for one
   retry in the same session when a turn fails on a usage limit.
   Every role can write — the reporting protocol has each one journal to
   `.any-subagent/<session>/notes.md`, which a read-only role could not do. Scope a
   role by the worktree you send it to, not by taking its tools away.

5. Smoke-test each role with a trivial prompt — some models still fail only
   at call time (e.g. ChatGPT-account codex rejects some catalog models with
   a 400).

## If Codex is the orchestrator

A delegated CLI is a normal subprocess, so it inherits the sandbox of the
session that spawned it. Codex's default `workspace-write` blocks exactly what
a delegated agent needs:

| Under default `workspace-write` | Result | Effect on delegation |
|---|---|---|
| write `/tmp/any-subagent/...` | allowed | agent-send's own session state survives |
| network | **blocked** | the delegated CLI never reaches its provider |
| write `~/.codex`, `~/.claude`, `~/.local/share/opencode`, `~/.pi`, `~/.gemini` | **blocked** | the delegated CLI cannot persist its own session — resume breaks |

Interactively, Codex will offer to re-run the failed command outside the
sandbox, so a run survives on approval — but every `agent-send` call asks
again. Give the session network plus the state dirs of the backends you use
instead. Codex 0.154+ keeps each profile in its own file — write
`~/.codex/any-subagent.config.toml` (a `[profiles.x]` table inside `config.toml`
is the legacy form and is now rejected):

```toml
sandbox_mode = "workspace-write"

[sandbox_workspace_write]
network_access = true
# only the backends you actually delegate to; ~ is expanded
writable_roots = ["~/.codex", "~/.claude", "~/.local/share/opencode", "~/.pi", "~/.gemini"]
```

Then run `codex --profile any-subagent`. Full access
(`--dangerously-bypass-approvals-and-sandbox`) also works and is what you get
in a container, but it drops the sandbox for the orchestrator's own commands
too; the profile keeps that protection.

Codex has no background-task tool, so a long delegation blocks the turn. Run
it with `nohup ... > out.log 2>&1 &` and poll the log, or accept the wait.
