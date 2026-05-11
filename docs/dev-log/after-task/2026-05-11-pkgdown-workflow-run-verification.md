# After-Task: Post-PR-#8-Merge pkgdown workflow_run Verification

## Goal

Confirm that the `workflow_run`-triggered `pkgdown` sequencing
landed in PR #8 actually fires (a) only after `R-CMD-check` on
`main` / `master` completes successfully, and (b) without spawning
a parallel pkgdown run on the push event itself.

This closes the "Next Actions" item recorded in
`docs/dev-log/after-task/2026-05-11-ci-site-team-repair.md`:

> After the next main push, confirm pkgdown starts only after the
> green R-CMD-check workflow_run event.

## Implemented

A check-log entry under
`docs/dev-log/check-log.md` that records the concrete CI evidence
gathered from `gh run list` and `gh run view` for the
PR-#8-merge push. No code, NAMESPACE, generated Rd, vignette, or
pkgdown navigation changed.

## Mathematical Contract

No public R API, likelihood, formula grammar, estimator, family,
NAMESPACE, or generated Rd changed. CI verification only.

## Files Changed

- `docs/dev-log/check-log.md` (M -- new entry
  "post-PR-#8-merge pkgdown workflow_run verification")
- `docs/dev-log/after-task/2026-05-11-pkgdown-workflow-run-verification.md`
  (new -- this file)

## Checks Run

```sh
gh run list --repo itchyshin/gllvmTMB --workflow pkgdown --limit 5 \
  --json databaseId,status,conclusion,createdAt,updatedAt,headBranch,event

gh run list --repo itchyshin/gllvmTMB --workflow R-CMD-check \
  --branch main --limit 5 \
  --json databaseId,status,conclusion,createdAt,updatedAt,event

gh run view 25676207810 --repo itchyshin/gllvmTMB --json jobs \
  --jq '.jobs[] | {name, startedAt, completedAt}'
```

Output (extracted):

| Workflow | Run ID | Event | Wall |
|---|---|---|---|
| `R-CMD-check` on `main` | 25676207810 | `push` | 34 min 27 s |
| `pkgdown` on `main` | 25678157733 | **`workflow_run`** | 10 min 34 s |

Sequencing: pkgdown started 7 s after R-CMD-check completed.
**No parallel pkgdown run** appeared on the PR #8 push event.

## Tests Of The Tests

- The pkgdown run's `event` field is **`workflow_run`** (verified
  via `gh run list --workflow pkgdown --json event`), not `push`.
  This is direct evidence that the trigger was the
  `workflow_run` event after `R-CMD-check` completed, not the
  PR #8 merge push itself.
- The pkgdown run's start time (15:00:07Z) is 7 s after the
  R-CMD-check completion time (15:00:00Z). Pre-repair, the
  pkgdown run would have started simultaneously with the
  R-CMD-check run (compare PR #6 merge at 02:56:20Z where both
  fired at the same second).

## Consistency Audit

- Decision recorded in `docs/dev-log/decisions.md` "2026-05-11
  Sequence pkgdown after green R-CMD-check" is now validated.
- The CI Pacing Discipline section in `AGENTS.md` ("pkgdown runs
  only after a successful R-CMD-check on main / master") matches
  observed behaviour.
- The "Known Limitations" section in PR #8's after-task report
  ("R-CMD-check is still expected to take roughly 30-35 minutes")
  matches the observed 34 min 27 s wall. The repair did not promise
  to reduce R-CMD-check runtime; only to sequence pkgdown after it.

## What Did Not Go Smoothly

Nothing for this verification itself. One adjacent observation:
the deployed pkgdown site
(https://itchyshin.github.io/gllvmTMB/) currently shows the
post-PR-#8 README + Fisher-z fix, but **not** the legacy hex logo
or favicons. The reason is that **PR #9 (logo + favicons) has not
merged yet**. Once PR #9 lands on main, the next workflow_run
cycle will redeploy the site with the assets. Reported to the
maintainer in chat.

## Team Learning

- The `workflow_run` event field on `gh run list` is the
  authoritative signal that pkgdown was triggered correctly. A
  short `gh run list --workflow pkgdown --json event,createdAt`
  is the canonical Shannon-style verification for future
  pkgdown-sequencing changes.
- Verification of a CI policy transplant can be recorded against
  one concrete merge cycle. Future CI sequencing changes should
  produce a similar one-shot verification check-log entry against
  the first relevant post-merge cycle.

## Known Limitations

- This verification covers one post-merge cycle (PR #8). The
  workflow_run sequencing should be revisited as part of routine
  monitoring -- Shannon's "Branch / PR census" check covers
  this on an ongoing basis once Shannon is in place
  (PR #15).

## Next Actions

- Merge PR #9 to deploy the logo + favicons.
- After PR #9 merges, the next workflow_run cycle should be
  observed for one more verification point (informally, no
  separate after-task report needed; the same pattern is now
  validated).
- After PR #12 + PR #15 land, run Shannon retroactively per the
  follow-up section in
  `docs/dev-log/after-task/2026-05-11-shannon-coordination-audit.md`.
