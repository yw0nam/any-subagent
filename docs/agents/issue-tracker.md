# Issue tracker: GitHub

Issues for this repo live as GitHub issues. Use the `gh` CLI for all operations; run inside a clone, it infers the repo from `git remote -v`.

## Conventions

- Create an issue: `gh issue create --title "..." --body "..."`, with a heredoc for multi-line bodies. Open every issue from the matching template in `.github/ISSUE_TEMPLATE/` (bug, feature_task, spike, decision).
- Read an issue: `gh issue view <number> --comments`, filtering comments with `jq` and fetching labels.
- List issues: `gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'` with `--label` and `--state` filters.
- Comment on an issue: `gh issue comment <number> --body "..."`
- Apply or remove labels: `gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- Close: `gh issue close <number> --comment "..."`

## Decision issues

A decision is a closed issue labeled `decision`, and its closing comment holds the decision.

- Open it from the decision template with the context and the options.
- Close it with a comment holding a `## Decision` section and a `## Consequences` section: `gh issue close <number> --comment "..."`.
- List decisions: `gh issue list --label decision --state closed`. Read one with `gh issue view <number> --comments`; the closing comment is the last comment.
- A later decision that replaces an earlier one is a new decision issue that names the one it replaces.

## Claim discipline (evidence-gated claims)

Issue and PR bodies carry two kinds of claims, and each has an evidence gate. An unverified claim is grounds for immediate rejection of the issue or PR.

- Prevention claims ("this refactor stops X-class bugs", "catches future bugs early") are admissible only with a measured RED: a failing test committed or linked, a reproduced defect, or a per-bug table over the cited past incidents showing the change would have gated each one. Without a RED, state the counted structural fact instead ("X is decided in N places").
- Quantitative claims (line counts, edit-site counts, blast radius, "N modules to add one value") are measured, with the measurement named: `wc -l`, `git show --name-only <commit>`, a grep count. A number without its measurement is rejected.
- Outcome promises ("bug class Y stops recurring") stay out of issue bodies and PR descriptions. Promise mechanisms and deletions verifiable at PR time.

## When a skill says "publish to the issue tracker"

Create a GitHub issue.

## When a skill says "fetch the relevant ticket"

Run `gh issue view <number> --comments`.
