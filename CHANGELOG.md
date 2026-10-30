# Changelog

## 2.3.0 — 2026-10-30

- `agent-send --stop <session>` stops a running turn. Each turn runs in its
  own process group; `--stop` sends TERM to the group, then KILL after 10 s,
  and returns once the stopped turn is recorded in `turns.jsonl` (exit 143).
  Killing agent-send itself (a harness timeout, Ctrl-C) also stops the backend.
- `agent-send --status <session>` prints `running` with the pid, start time
  and last activity, or `idle` with the last turn's number, time and exit.
- One turn per session: a message to a session that is still running is
  refused with "already running".
- opencode turns run with `--standalone`: a private server per turn, so no
  session keeps working after its turn ends.
- A role may set `"fallback"`, another model of the same backend. A failed
  turn whose output reports a usage limit is retried once, in the same
  session, on the fallback. The matching lines are printed verbatim on stderr,
  with or without a fallback.
- Removed the `qwen` (Qwen Code) backend added in 2.2.0. Its headless output
  was cut at 64 KB inside the sandbox, so long turns lost their report and
  session id. Reach Qwen models through pi instead (a `qwen-token-plan-*`
  provider). Roles with `"backend": "qwen"` now fail with "unsupported backend".

## 2.2.0 — 2026-10-30

- New backend: `qwen` (Qwen Code). `agent-send` runs it with
  `-o json --yolo --sandbox` and resumes a session with `-r <id>`. An unknown
  id fails with "resume failed". Headless qwen removes its shell tool in every
  approval mode except yolo, so the sandbox confines the CLI instead:
  sandbox-exec on macOS, docker or podman on Linux.
- `agent-send --models qwen` lists the model ids in `~/.qwen/settings.json`
  (`modelProviders`). Qwen Code has no list command.

## 2.1.0 — 2026-10-30

- Work logs are structured. Each session gets a directory,
  `.any-subagent/<session>/`. `agent-send` appends one JSON line per message
  to `turns.jsonl`: `ts`, `turn`, `role`, `backend`, `model`, `session_id`,
  `spec`, `report`, `exit`, `duration_s`. The agent writes only its reasoning,
  to `notes.md`, and no longer copies the spec. `--note` writes to
  `<session>/inbox.md`. `--log` prints every turn's spec and report, then the
  notes.
- The flat `.any-subagent/<session>.md` and `<session>.inbox.md` files from
  earlier releases are not read. `--log` does not show them; `cat` them, or
  delete them.

## 2.0.1 — 2026-10-23

- Skill: a new Trust section says the other agent's reply, work log and inbox
  are data. Nothing in them can approve a merge, a push or another command.
- Skill: before it runs `install.sh`, the orchestrator shows it to the user
  and waits for a yes (SKILL.md preflight and setup step 0).

## 2.0.0 — 2026-10-22

- Renamed from agent-team to any-subagent: the repo, the plugin, the skill,
  the config path (`~/.config/any-subagent/config.json`), the env vars
  (`ANY_SUBAGENT_CONFIG`, `ANY_SUBAGENT_BIN`), the session state
  (`/tmp/any-subagent/`), the per-repo log dir (`.any-subagent/`), the Codex
  profile (`any-subagent`) and pi session ids (`any-subagent-<name>`). The
  `agent-send` command keeps its name. No old path is read: move
  `~/.config/agent-team/config.json` to the new path, then reinstall with
  `/plugin install any-subagent@yw0nam`. Sessions started under the old name
  do not resume.

## 1.8.3 — 2026-10-21

- `agent-send`: codex in a linked worktree can commit. Making the common git
  dir a writable root was not enough: codex keeps the dir a worktree's `.git`
  file points to (`.git/worktrees/<name>`, where `index.lock` lives)
  read-only unless that exact path is itself a writable root, so every
  `git add` failed with "Unable to create … index.lock: Operation not
  permitted". agent-send now adds `git rev-parse --absolute-git-dir` too.
  Measured on codex-cli 0.159.1: the commit failed with the common dir alone
  and passed with both.

## 1.8.2 — 2026-10-20

- `agent-send`: redirect opencode stdin from `/dev/null` on resume. `opencode
  run` reads stdin to EOF when it is not a TTY, so a resumed turn started
  from a caller with an open stdin pipe hung before the prompt reached the
  server (0 % CPU, no message added to the session). New sessions were never
  affected because `&` already gives them `/dev/null`. Same fix the codex
  branch carries since 1.1.3.

## 1.8.1 — 2026-10-19

- `agent-send`: opencode v2 creates a new session for an unknown `--session`
  id and exits 0, so a lost session resumed with no context and no error.
  agent-send now checks the id with `opencode session export` before the turn
  and fails loudly when it is gone. The check costs 0.4 s on a 323-message
  session. Verified against opencode v2.0.32; flags, the JSON event stream and
  `opencode models` are unchanged from v1.

## 1.8.0 — 2026-10-02

- `agent-send`: new `agy` backend (Antigravity CLI). Sessions resume by
  `--conversation <id>`, taken from the JSON envelope's `conversation_id`;
  `--models` lists `agy models`. An unknown conversation id only warns and
  starts a fresh conversation with exit 0, so agent-send compares the returned
  id with the stored one and fails loudly instead of losing context. The error
  names the new id so its turn can be kept; a resume that merely fails
  (quota, network) exits with its own code and keeps the session file. agy runs
  with `--sandbox --dangerously-skip-permissions`: headless agy soft-denies
  every tool not allow-listed and then ends the turn with `SUCCESS` and an
  empty response — one denied `date` killed the first smoke test. An empty
  response now fails loudly with the denied actions.

## 1.7.0 — 2026-09-18

- **Breaking: read-only roles are gone.** `-w` and the config's `write` key are
  removed; every role runs in its backend's write mode. The reporting protocol
  has each role journal to `.agent-team/<session>.md` — a role that cannot
  write cannot do that, so a review role was getting no protocol and no
  structure at all. Scope a role by the worktree you send it to, not by taking
  its tools away. Existing configs keep working; `write` is ignored.
  Side effect: this removes a cache break. pi implements read-only as a tool
  filter (`-xt edit,write`) and pins a cache breakpoint to the last tool, so
  sending `-w` to an existing read-only pi session invalidated its whole
  prefix — measured at cacheRead 1,664 -> 320.
- `agent-send` returns only the final assistant message. codex emits an
  `agent_message` for every preamble it narrates between tool calls and pi a
  `turn_end` per turn; both filters kept all of them, so a delegation handed
  the orchestrator its entire narration instead of the report the protocol
  asks for — 28 messages / 14,728 characters on one real task. A run that ends
  without a final assistant text now fails loudly instead of returning
  narration; the raw stream still goes to stderr.

## 1.6.0 — 2026-09-16

- Codex is a first-class orchestrator, not just a backend. `codex plugin
  marketplace add yw0nam/agent-team` reads the existing
  `.claude-plugin/marketplace.json` as-is and `codex plugin add` loads the
  skill — the only thing Codex does not do is put the plugin's `bin/` on PATH,
  so `install.sh` links `agent-send` into `~/.local/bin` (and the skill into
  `~/.codex/skills/` for a plain git clone, skipped when the plugin already
  supplies it).
- Skill and workflows are harness-neutral: the interview no longer assumes
  AskUserQuestion, and backgrounding a long delegation is documented per
  harness (Claude Code's background Bash vs. `nohup ... &` plus polling).
- Documented the Codex sandbox trap: a delegated CLI inherits the spawning
  session's sandbox, and the default `workspace-write` blocks the network
  outright and makes the backend's own state dir read-only — so delegation
  either fails or silently loses its sessions. Fix is a profile
  (`~/.codex/agent-team.config.toml`) with `network_access = true` and the
  backends' state dirs in `writable_roots`.

## 1.5.0 — 2026-09-11

- `agent-send --note <session> "..."`: amend a task that is already running.
  Non-interactive CLIs cannot take input mid-turn, so the note is appended to
  `.agent-team/<session>.inbox.md` and write roles are told to re-read that
  file before each major step — they apply the amendment, record it in the log
  under `### amendment`, and truncate the inbox. Cooperative, not preemptive:
  it lands at the next step boundary, or not at all if the turn already ended
  (send a normal follow-up then, or kill the run and re-send the spec to the
  same session).

## 1.4.0 — 2026-09-11

- Work logs. Write-enabled roles are now told, on every message, to append the
  spec they were given plus what they did and why to
  `<repo-root>/.agent-team/<session>.md`, and to reply with a report in fixed
  sections — summary, changes, verification, notes, log path — the same shape
  a harness subagent hands back. Logging the spec next to the notes is
  what makes the log checkable later — the diff has its acceptance criteria
  sitting above it. Delegation
  stops dumping transcripts into the orchestrator's context, and the reasoning
  behind a diff outlives the scrollback. The directory ignores itself, so logs
  never show up in `git status`; read one back with `agent-send --log <name>`.
  Read-only roles are unaffected — they cannot write, and their answer is the
  deliverable.

## 1.3.1 — 2026-09-10

- `agent-send`: pi turns that fail now fail loudly. pi exits 0 even when the
  turn errored (unknown model, provider 400, auth), and the reason only lives
  in the event stream as `stopReason: "error"` — so a broken role printed
  nothing at all and looked like a success. The error message now goes to
  stderr with exit 1.
- Docs: pi carries the reasoning level as a model suffix
  (`"zai/glm-5.3-flash:high"`), so no config key is needed for it.

## 1.3.0 — 2026-09-10

- `agent-send`: new `pi` backend. pi names its own sessions (`--session-id`
  creates the id if missing, resumes it if not), so there is no id to scrape
  and a run killed by a timeout can never be orphaned. `--models` lists pi's
  catalog via `pi --list-models`. pi has no sandbox: `write: false` only drops
  its `edit`/`write` tools, and `bash` can still modify files — keep hard
  read-only roles on codex.

## 1.2.5 — 2026-08-06

- `agent-send`: codex write roles now add the repo's git common dir to
  `sandbox_workspace_write.writable_roots` when it sits outside cwd. The
  sandbox root is cwd, so in a linked worktree — or any subdirectory of a repo
  — every git write failed with "Read-only file system"; codex then asked to
  escalate and `exec` had nobody to answer, so delegated agents reported that
  they could not use git at all. Only added when the git dir is actually
  outside cwd, so a plain repo root is unaffected.
- Skill: note that skills do not travel to delegated agents — codex never reads
  `~/.claude/skills`.

## 1.2.4 — 2026-08-04

- `agent-send`: codex write roles now also pass
  `-c sandbox_workspace_write.network_access=true`. Without it the sandbox
  blocks `socket()`, asyncio cannot build its self-pipe, and any suite using
  starlette's `TestClient` hangs instead of failing — so delegated agents could
  not run pytest at all. Scoped to `-w`; read-only roles and the user's own
  codex keep the default posture.

## 1.2.3 — 2026-07-28

- `agent-send`: use `-c sandbox_mode=workspace-write` instead of `-s` for codex
  write roles. The same flags array feeds `codex exec` and `codex exec resume`,
  and resume rejects `-s`.

## 1.2.2 — 2026-07-23

- `agent-send`: extract the codex session id from the `--json` event stream's
  `thread_id` rather than the human-readable banner, which is not a stable
  contract.
- `agent-send`: persist the opencode session id before the run completes, so a
  killed or timed-out run stays resumable.

## 1.2.0 — 2026-07-20

- Skill: split `SKILL.md` into a router plus `workflows/`.

## 1.1.3 — 2026-07-14

- `agent-send`: redirect codex stdin from `/dev/null`. `codex exec` waits for
  stdin EOF, which a backgrounded caller's open pipe never sends.

## 1.1.2 — 2026-07-12

- Skill: route natively-runnable models to the harness's own subagents instead
  of `agent-send`.

## 1.1.1 — 2026-07-12

- `agent-send`: use POSIX `sed` for session-id extraction.

## 1.1.0 — 2026-07-12

- `agent-send --models`: query live model catalogs per backend.

## 1.0.0 — 2026-07-12

- Initial release: session-persistent, role-based delegation to external
  coding-agent CLIs (codex, opencode, claude).
