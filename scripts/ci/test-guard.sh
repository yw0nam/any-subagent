#!/usr/bin/env bash
# Fails when a PR adds more than THRESHOLD source lines and changes no test file.
# Bypass: the skip-tests PR label (TEST_GUARD_SKIP=1).
# Usage: test-guard.sh <base-ref>   (run from the repo root)
set -u

BASE="${1:-origin/main}"
THRESHOLD="${TEST_GUARD_THRESHOLD:-20}"

if [ "${TEST_GUARD_SKIP:-}" = "1" ]; then
  echo "test-guard: skipped (skip-tests label)"
  exit 0
fi

is_test_path() {
  case "$1" in
    tests/*) return 0 ;;
    *) return 1 ;;
  esac
}

is_source_path() {
  case "$1" in
    bin/* | install.sh | scripts/*) return 0 ;;
    *) return 1 ;;
  esac
}

src_added=0
test_changed=0

# Three-dot diff: only what this branch adds over the merge base. --no-renames prints the new
# path in place of "{old => new}"; quotePath=false keeps non-ASCII names unquoted.
diff=$(git -c core.quotePath=false diff --numstat --no-renames "$BASE"...HEAD) || {
  echo "test-guard: cannot diff against $BASE" >&2
  exit 2
}

while read -r added _ f; do
  [ -z "$f" ] && continue
  if is_test_path "$f"; then
    test_changed=1
  elif is_source_path "$f"; then
    case "$added" in '-') added=0 ;; esac
    src_added=$((src_added + added))
  fi
done <<< "$diff"

if [ "$src_added" -le "$THRESHOLD" ] || [ "$test_changed" = "1" ]; then
  echo "test-guard: ${src_added} source line(s) added, test changed: ${test_changed} - ok"
  exit 0
fi

cat >&2 <<MSG
test-guard: ${src_added} source line(s) added with no test change. New or changed
behavior ships a test in the same PR (CONTRIBUTING.md). Add the test, or apply
the 'skip-tests' label for a justified exception (rename, config-only, generated code).
MSG
exit 1
