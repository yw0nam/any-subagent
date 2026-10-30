#!/usr/bin/env bash
# Stub-CLI tests for agent-send: first call, resume by name, stale session, codex, qwen,
# roles, work logs, stopping a running turn.
set -u

# resolve the repo from this test's own path
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
AGENT_SEND="$SCRIPT_DIR/../bin/agent-send"
[[ -x $AGENT_SEND ]] || { echo "FAIL: agent-send not executable at $AGENT_SEND" >&2; exit 1; }

T=$(mktemp -d)
mkdir -p "$T/bin" "$T/work"
# hash agent-send derives from its cwd, so EXIT cleanup removes its state dir too
state_key=$(cd "$T/work" && pwd -P | sha1sum | cut -c1-12)
trap 'rm -rf "$T" "/tmp/any-subagent/$state_key"' EXIT
STATE="/tmp/any-subagent/$state_key"

fail() { # first failing check aborts the run
  echo "FAIL: $1" >&2
  exit 1
}

# stub claude: dead-id resumes fail like an expired session, a SLOW turn hangs with a
# descendant that ignores TERM, the rest return fixed JSON
cat >"$T/bin/claude" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$*" >>'$T/calls.log'
if [[ " \$* " == *' --resume dead-id '* ]]; then
  echo 'No conversation found' >&2
  exit 1
fi
if [[ " \$* " == *SLOW* ]]; then
  ( trap '' TERM; sleep 30 ) &
  echo \$! >'$T/slow.pid'
  wait
  exit 0
fi
echo '{"session_id":"claude-sid-1","result":"stub reply"}'
STUB

# stub codex: dead-id resumes fail like an expired thread, the rest emit the JSONL event stream
cat >"$T/bin/codex" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$*" >>'$T/calls.log'
if [[ "\$*" == 'exec resume dead-id'* ]]; then
  echo 'No thread found' >&2
  exit 1
fi
echo '{"type":"thread.started","thread_id":"codex-tid-1"}'
echo '{"type":"item.completed","item":{"type":"agent_message","text":"stub reply"}}'
STUB
# stub qwen: dead-id resumes fail like a missing session, the rest print the -o json event array
cat >"$T/bin/qwen" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$*" >>'$T/calls.log'
if [[ " \$* " == *' -r dead-id '* ]]; then
  echo 'No saved session found with ID dead-id' >&2
  exit 1
fi
echo '[{"type":"system","session_id":"qwen-sid-1"},{"type":"result","session_id":"qwen-sid-1","is_error":false,"result":"stub reply"}]'
STUB
chmod +x "$T/bin/claude" "$T/bin/codex" "$T/bin/qwen"

printf '%s\n' '{"roles":{"impl":{"backend":"claude","model":"m1"}}}' >"$T/config.json"

run() { # every call happens in $T/work, stubs first on PATH
  (cd "$T/work" && PATH="$T/bin:$PATH" ANY_SUBAGENT_CONFIG="$T/config.json" "$AGENT_SEND" "$@")
}

bg_run() { # run in the background; exec so that $! is agent-send itself, not a wrapper
  (cd "$T/work" && PATH="$T/bin:$PATH" ANY_SUBAGENT_CONFIG="$T/config.json" exec "$AGENT_SEND" "$@") >/dev/null 2>&1 &
}

wait_for() { # $1: file, $2: tenths of a second to wait for it to appear
  local n=0
  while [[ ! -f $1 && $n -lt $2 ]]; do sleep 0.1; n=$((n + 1)); done
  [[ -f $1 ]]
}

# 1. first call creates the session
out=$(run claude s1 hi) || fail "check 1: agent-send claude s1 exited non-zero"
[[ $out == 'stub reply' ]] || fail "check 1: expected 'stub reply', got: $out"
[[ $(cat "$STATE/claude-s1") == 'claude-sid-1' ]] ||
  fail "check 1: state file claude-s1 does not hold claude-sid-1"

# 2. follow-up resumes by name
out=$(run claude s1 again) || fail "check 2: follow-up exited non-zero"
[[ $out == 'stub reply' ]] || fail "check 2: expected 'stub reply', got: $out"
grep -q -- '--resume claude-sid-1' "$T/calls.log" ||
  fail "check 2: calls.log has no '--resume claude-sid-1'"

# 3. expired session fails loudly and keeps its id
printf 'dead-id\n' >"$STATE/claude-s2"
err=$(run claude s2 x 2>&1 >/dev/null) && fail "check 3: expired session exited zero"
grep -q 'resume failed' <<<"$err" || fail "check 3: stderr lacks 'resume failed'"
[[ $(cat "$STATE/claude-s2") == 'dead-id' ]] ||
  fail "check 3: state file claude-s2 no longer holds dead-id"

# 4. codex sessions: thread id on first call, exec resume on follow-up
out=$(run codex c1 hi) || fail "check 4: codex new session exited non-zero"
[[ $out == 'stub reply' ]] || fail "check 4: expected 'stub reply', got: $out"
[[ $(cat "$STATE/codex-c1") == 'codex-tid-1' ]] ||
  fail "check 4: state file codex-c1 does not hold codex-tid-1"
out=$(run codex c1 again) || fail "check 4: codex follow-up exited non-zero"
[[ $out == 'stub reply' ]] || fail "check 4: follow-up expected 'stub reply', got: $out"
grep -q 'exec resume codex-tid-1' "$T/calls.log" ||
  fail "check 4: calls.log has no 'exec resume codex-tid-1'"

# 5. roles resolve backend and model; unknown roles fail loudly
out=$(run impl r1 hi) || fail "check 5: role impl exited non-zero"
[[ $out == 'stub reply' ]] || fail "check 5: expected 'stub reply', got: $out"
grep -q -- '--model m1' "$T/calls.log" || fail "check 5: claude stub not called with '--model m1'"
err=$(run nosuchrole r1 hi 2>&1 >/dev/null) && fail "check 5: unknown role exited zero"
grep -q 'unknown role' <<<"$err" || fail "check 5: stderr lacks 'unknown role'"

# 6. the wrapper records every turn per session; --log renders it; --note fills the inbox
L="$T/work/.any-subagent"
[[ $(wc -l <"$L/r1/turns.jsonl") -eq 1 ]] || fail "check 6: r1/turns.jsonl does not hold exactly one turn"
jq -e '.spec == "hi" and .report == "stub reply\n" and .exit == 0 and .role == "impl" and .backend == "claude"' \
  "$L/r1/turns.jsonl" >/dev/null || fail "check 6: r1 turn record is wrong: $(cat "$L/r1/turns.jsonl")"
jq -e '.exit != 0' "$L/s2/turns.jsonl" >/dev/null || fail "check 6: expired-session turn not recorded with non-zero exit"
run --log r1 | grep -q 'stub reply' || fail "check 6: --log r1 lacks the report"
run --log nosuch 2>/dev/null && fail "check 6: --log of an unknown session exited zero"
run --note s9 amend 2>/dev/null
grep -q 'amend' "$L/s9/inbox.md" || fail "check 6: --note did not write s9/inbox.md"
printf 'n1\n' >"$L/s9/notes.md"
run --log s9 | grep -q 'n1' || fail "check 6: --log of a notes-only session lacks the notes"

# 7. qwen sessions: session id on first call, -r on follow-up, loud failure on a dead id
out=$(run qwen q1 hi) || fail "check 7: qwen new session exited non-zero"
[[ $out == 'stub reply' ]] || fail "check 7: expected 'stub reply', got: $out"
[[ $(cat "$STATE/qwen-q1") == 'qwen-sid-1' ]] || fail "check 7: state file qwen-q1 does not hold qwen-sid-1"
run qwen q1 again >/dev/null || fail "check 7: qwen follow-up exited non-zero"
grep -q -- '-r qwen-sid-1' "$T/calls.log" || fail "check 7: calls.log has no '-r qwen-sid-1'"
printf 'dead-id\n' >"$STATE/qwen-q2"
err=$(run qwen q2 x 2>&1 >/dev/null) && fail "check 7: dead qwen session exited zero"
grep -q 'resume failed' <<<"$err" || fail "check 7: stderr lacks 'resume failed'"

# 8. a running turn can be stopped, refuses a second turn, and reports its status
bg_run claude slow1 SLOW
slow1=$!
wait_for "$L/slow1/pid" 50 || fail "check 8: slow1/pid never appeared"
out=$(run --status slow1) || fail "check 8: --status of a running session exited non-zero"
[[ $out == running* ]] || fail "check 8: --status of a running session: $out"
err=$(run claude slow1 again 2>&1 >/dev/null) && fail "check 8: a second turn on a running session exited zero"
grep -q 'already running' <<<"$err" || fail "check 8: stderr lacks 'already running'"
run --stop slow1 2>/dev/null || fail "check 8: --stop of a running session exited non-zero"
wait "$slow1"
rc=$?
[[ $rc -eq 143 ]] || fail "check 8: the stopped agent-send exited $rc, expected 143"
desc=$(cat "$T/slow.pid")
kill -0 "$desc" 2>/dev/null && fail "check 8: the TERM-ignoring descendant $desc outlived --stop"

# killing agent-send itself (a harness timeout) takes the backend's group with it
bg_run claude slow2 SLOW
slow2=$!
wait_for "$L/slow2/pid" 50 || fail "check 8: slow2/pid never appeared"
kill -TERM "$slow2"
wait "$slow2"
rc=$?
[[ $rc -eq 143 ]] || fail "check 8: agent-send killed by TERM exited $rc, expected 143"
desc=$(cat "$T/slow.pid")
kill -0 "$desc" 2>/dev/null && fail "check 8: the descendant outlived agent-send"
[[ -f $L/slow2/pid ]] && fail "check 8: slow2/pid outlived agent-send"

jq -e '.exit == 143' <<<"$(tail -1 "$L/slow1/turns.jsonl")" >/dev/null ||
  fail "check 8: the stopped turn is not recorded with exit 143: $(tail -1 "$L/slow1/turns.jsonl")"
out=$(run --status slow1) || fail "check 8: --status of a stopped session exited non-zero"
[[ $out == idle* ]] || fail "check 8: --status of a stopped session: $out"
err=$(run --stop slow1 2>&1 >/dev/null) || fail "check 8: --stop of an idle session exited non-zero"
grep -q 'not running' <<<"$err" || fail "check 8: stderr lacks 'not running'"
run --status nosuch 2>/dev/null && fail "check 8: --status of an unknown session exited zero"

echo "all checks passed"
