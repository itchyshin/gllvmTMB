---
name: shannon-coordination-audit
description: Run Shannon's read-only cross-team coordination audit for gllvmTMB branches, pull requests, working-tree state, dev-log handoffs, and after-task report coverage before handoffs, merges, or multi-PR fan-out.
---

# Shannon Coordination Audit

Use this skill when Codex, Claude Code, or the maintainer needs to
check cross-team state: before a working-tree switch, before merge
sequencing, after several agents opened PRs, or at the end of a work
session.

Shannon is read-only. Do not edit files, merge PRs, rerun CI, or
resolve conflicts. Report `PASS`, `WARN`, or `FAIL` with concrete
evidence and the smallest recommended next action.

## Checks

1. **Working tree**: current branch, uncommitted files, untracked
   files, and whether local changes belong to the active branch.
2. **PR census**: open PR count, branch names, authorship signal when
   available, mergeability, CI state, and likely merge order.
3. **File overlap**: PRs touching the same coordination files
   (`AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `ROADMAP.md`,
   `docs/dev-log/check-log.md`, `docs/dev-log/decisions.md`,
   `docs/dev-log/after-task/`) or the same implementation files.
4. **After-task coverage**: every completed task PR should include an
   after-task report in the same branch unless it is a read-only audit
   whose report is the audit document itself.
5. **Message bus**: important handoffs should appear in PR comments,
   `docs/dev-log/check-log.md`, `docs/dev-log/decisions.md`, or an
   after-task report, not only in chat.
6. **Rule drift**: current practice should be compared with stated
   rules, especially WIP limits, CI pacing, after-task reports, and
   maintainer checkpoints before deletions or API changes.

## Suggested Commands

```sh
git status --short --branch
git branch -vv --all
gh pr list --repo itchyshin/gllvmTMB --state open \
  --json number,title,headRefName,baseRefName,mergeStateStatus,statusCheckRollup,updatedAt,url
gh run list --repo itchyshin/gllvmTMB --limit 12 \
  --json databaseId,displayTitle,workflowName,status,conclusion,headBranch,headSha,url
rg -n "after-task|handoff|checkpoint|Shannon|Rose|Codex|Claude" \
  AGENTS.md CLAUDE.md CONTRIBUTING.md ROADMAP.md docs/dev-log
```

For file overlap, inspect each relevant PR:

```sh
gh pr view <number> --repo itchyshin/gllvmTMB --json files,headRefName,title,url
```

## Output

Return:

- `PASS`: cross-team state is consistent and the next action is clear.
- `WARN`: work can continue, but merge order, CI state, missing notes,
  or open-PR fan-out should be acknowledged.
- `FAIL`: a branch switch, merge, deletion, NAMESPACE edit, or broad
  implementation would risk losing work or violating the project
  rules.

Include:

- current branch and dirty/clean state;
- open PR summary and suggested merge order;
- file-overlap or after-task-report gaps;
- one short next-action recommendation.
