# After Task: PR slice contract

**Branch**: `codex/pr-slice-contract`
**Date**: 2026-05-18
**Scope**: process-only. No public R API, likelihood, formula
grammar, family, NAMESPACE, generated Rd, vignette, article, or
pkgdown navigation change.
**Lead personas**: Ada (coordination), Shannon (PR/lane discipline),
Rose (process drift), Grace (CI/pacing), Pat (reviewer burden).

## 1. Goal

Implement the first small drmTMB-inspired discipline slice for
`gllvmTMB`: make every future PR state its slice goal, intentional
file scope, checks, review roles, and next slice before review.

## 2. What changed

- `.github/pull_request_template.md`: added a GitHub PR template with
  sections for slice goal, scope, contract/evidence, checks, engaged
  review roles, and next slice.
- `CONTRIBUTING.md`: added a short "PR slice contract" pointer so the
  template is part of contributor workflow, not only GitHub UI.
- `docs/dev-log/coordination-board.md`: moved #184 to resolved state
  and recorded this branch as the active Slice 1 lane.
- `docs/dev-log/check-log.md`: appended the durable lesson that
  discipline starts with the PR surface itself.

## 3. Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE,
generated Rd, vignette, article, or pkgdown navigation change.

## 4. Checks Run

- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,mergeStateStatus --limit 10`:
  returned `[]` before branch edits.
- `git log --all --oneline --since="6 hours ago"`: confirmed #184
  merged before this branch started.
- `git diff --check`: clean.
- `rg -n "Slice Goal|PR Slice Contract|Slice 1|codex/pr-slice-contract|The PR surface" .github/pull_request_template.md CONTRIBUTING.md docs/dev-log/coordination-board.md docs/dev-log/check-log.md docs/dev-log/after-task/2026-05-18-pr-slice-contract.md`:
  confirmed the new slice-contract surfaces are present.

## 5. Tests Of The Tests

N/A. This is a process-template change and adds no package test.

## 6. Consistency Audit

This process-only PR deliberately does not touch R code, roxygen,
generated Rd, README, NEWS, pkgdown navigation, vignettes, formula
grammar, likelihoods, families, or validation-debt status.

Exact audit pattern:

```sh
rg -n "Slice Goal|PR Slice Contract|Slice 1|codex/pr-slice-contract|The PR surface" .github/pull_request_template.md CONTRIBUTING.md docs/dev-log/coordination-board.md docs/dev-log/check-log.md docs/dev-log/after-task/2026-05-18-pr-slice-contract.md
```

Verdict: found the new PR template, CONTRIBUTING pointer, active-lane
board update, check-log lesson, and after-task report.

## 7. What Did Not Go Smoothly

The first attempted merge of #184 through the GitHub connector failed
with a permissions error; the authenticated `gh pr merge` path
worked. CI on #184 took about 38 minutes on Windows, which confirms
that CI duration remains a real pacing constraint for `gllvmTMB`.

## 8. Team Learning

- Ada: kept the first discipline implementation intentionally small
  rather than bundling PR template, after-task template, readiness
  matrix, and pkgdown navigation.
- Shannon: required #184 to merge and the open PR count to return to
  zero before this branch started.
- Rose: kept the change on process surfaces and avoided new feature
  policy.
- Grace: treated the 3-OS #184 run as a hard gate before opening this
  lane.
- Pat: kept the template short enough that future contributors can
  complete it without turning every small PR into a paperwork task.

## 9. Design-Doc Updates

None.

## 10. Pkgdown / Documentation Updates

None.

## 11. Roadmap Tick

N/A. No roadmap feature status changes.

## 12. Known Limitations And Next Actions

- This is a manual discipline gate, not CI automation.
- Next slice should be the after-task template, unless the maintainer
  prefers to inspect this PR first.
