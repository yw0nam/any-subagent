<!-- Title in English, conventional-commit format (becomes the squash-merge subject), with `!` for a breaking change. e.g. "feat: agent-send reads the message from a file or stdin" -->

## Summary
<!-- What and why. Lead with the smallest picture that shows the change: a call tree, a file tree, or a diff sketch. For every new constant, threshold, or special-cased status, add a line: why this value / branch and not the alternative. For a breaking change, name what was removed and what replaces it. -->

## Related issues
<!-- `Closes #N` or `Part of #N`, on its own line -->

## Related decisions
<!-- The decision issues this change implements or relies on: #N -->

## Runtime evidence
<!-- Unit tests are not runtime verification. For any behavioral change, paste
     the `agent-send` reply and its `turns.jsonl` record from a run against the real backend CLI, from the live acceptance checks in `docs/adding-a-backend.md`
     proving the behavior, before and after. Write "N/A: no runtime behavior
     change" only when the diff is non-runtime (docs, config, tooling). -->

## Merge danger
<!-- Door: one-way (hard to undo: a released flag, config key, environment variable, `turns.jsonl` field or state path changes; a session state file is deleted) or two-way (a revert undoes it).
     Blast radius: what a defect breaks, in one line. -->

## Checklist
- [ ] New or changed behavior ships a test in this PR, committed failing first as its own `test:` commit (or the `skip-tests` label justified)
- [ ] Runtime evidence attached above, or N/A justified
- [ ] No unverified assumptions: upstream docs and the running behavior checked first
- [ ] A breaking change carries `!` in the title and the `breaking` label
- [ ] `bin/agent-send` runs on macOS bash 3.2 (CI job `test-macos` passes)
- [ ] A release bumps `.claude-plugin/plugin.json` and adds a `CHANGELOG.md` entry
