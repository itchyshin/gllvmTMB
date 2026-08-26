# Handover: interval-calibration landing

Date: 2026-08-25
Platform: Codex
Repository: `gllvmTMB`
Branch: `codex/interval-calibration-landing`
Exact base: `1bacee9a808b4106ce681502463baa317dcb9d9b`

## 1. Goal and result

This lane landed the completed interval-calibration programme on the current
main snapshot without changing its science. All 34 source commits and 103
paths are accounted. The terminal route census still has 19 rows and exactly
three certified CI-13 regimes; every other CI-08--CI-15 disposition is
unchanged.

## 2. Where the branch lives

The desktop linked worktree could not write its Git metadata, so the branch is
in this isolated ignored clone:

`/Users/z3437171/.codex/worktrees/d899/gllvmTMB/.unlazy/interval-calibration-landing/repo`

The completed source worktree remains clean on
`codex/interval-calibration-release` at
`4ba533949d7dae264268ae55f3c7fc801ee87da5`.

An importable bundle is produced outside the nested repository at:

`/Users/z3437171/.codex/worktrees/d899/gllvmTMB/.unlazy/interval-calibration-landing/codex-interval-calibration-landing.bundle`

Verify the bundle before import with `git bundle verify <path>`. No remote
landing branch or upstream is configured.

The expected final branch/bundle tip and bundle SHA-256 are pinned after the
final commit in
`/Users/z3437171/.codex/worktrees/d899/gllvmTMB/.unlazy/interval-calibration-landing/bundle-receipt.md`.
The receipt is deliberately post-commit: a commit cannot truthfully embed its
own as-yet-unknown object id.

## 3. Read first

1. `docs/dev-log/artifacts/interval-calibration/landing-commit-map.csv`
2. `docs/dev-log/artifacts/interval-calibration/landing-path-accounting.csv`
3. `docs/dev-log/artifacts/interval-calibration/landing-shared-file-reconciliation.csv`
4. `docs/dev-log/after-task/2026-08-25-interval-calibration-landing.md`
5. `docs/dev-log/after-task/2026-08-25-interval-calibration-release.md`

The replay tip before landing-specific receipts is
`06c3f5d91a9f66d8d7b7bb8ea3cf7b9910eb424f`; the reconciliation receipt commit
is `c342c5e2`.

## 4. Verification state

- Branch leaf: six gates met and reverified.
- Evidence leaf: four gates met and reverified.
- Integration leaf: three gates met and reverified.
- `LANDING_LINEAGE_OK commits=34 paths=103`.
- `SHARED_RECONCILIATION_RECEIPT_OK rows=5`.
- `FOREIGN_LANE_PATHS_CLEAR lanes=2 delta=110` at the final receipt tip (the
  three additional paths are the tracked landing closure documents).
- `LANDING_ROUTE_CENSUS_OK`: 19 routes, three certified.
- `LANDING_EVIDENCE_HASHES_OK`: 150,019 all-attempt rows and 18 target rows
  at the source hashes.
- `INTERVAL_CLAIMS_OK` and `LANDING_FOCUSED_TESTS_OK`.
- Rose, Grace, and the statistical landing reviewer returned PASS at exact
  reconciliation SHA `c342c5e266e29ac108419e9085fe9beec288a7fa`;
  the closure commit changes receipts only. Grace's residual risks are explicit:
  no fresh full check or three-OS run at this SHA, external raw Totoro/Fir
  archives were not rehashed from this clone, and the global lease registry was
  sandbox-read-only.

## 5. Scientific boundary

CI-08 remains callable but `route-only`, not calibrated. Exactly three native,
pinned, unrotated CI-13 standardized-loading regimes retain certification for
one frozen DGP conditional on eligible fits. CI-09/14/15 remain blocked;
CI-10 remains limited/blocked by route; CI-11/12 remain refused. The landing
does not authorize a new campaign or expand any target, family, rank, sample
size, rotation, or method.

## 6. Coordination boundary

The active random-slope and LV lanes are preserved. Their frozen leased paths
were checked against the complete landing delta. Do not use this branch to
continue either arc. No science compute, GitHub Actions science job, push, PR,
merge, release, deployment, issue comment, or public message occurred.

## 7. Resume/import command

From a writable clone of `gllvmTMB`, fetch the bundle into a new local ref and
inspect it before any integration action:

```sh
git fetch /Users/z3437171/.codex/worktrees/d899/gllvmTMB/.unlazy/interval-calibration-landing/codex-interval-calibration-landing.bundle codex/interval-calibration-landing:codex/interval-calibration-landing
git log --oneline --decorate origin/main..codex/interval-calibration-landing
git diff --check origin/main..codex/interval-calibration-landing
```

Push, PR, merge, or release requires new explicit maintainer authority.

## 8. Terminal disposition

`CARRIED-OVER`: the work is locally committed and bundle-exported, but
deliberately unpushed and unmerged. The next safe action is import-and-review,
not further interval science. Random-slope and LV work remain with their
existing lanes.

FINDINGS-OF-RECORD: none. This landing adds no scientific finding beyond the
terminal CI-08--CI-15 findings already recorded in the source programme's
after-task report and handover.

The pre-closure handoff gate correctly returned non-zero while the three
closure documents and check-log entry were uncommitted; it also could not find
`node` on its default path. Closure reruns it with the explicit node and gate
paths after commit. An unpushed local branch remains an intentional
`CARRIED-OVER` finding, not a landing pass.
