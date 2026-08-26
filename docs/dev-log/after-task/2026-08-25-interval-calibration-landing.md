# After Task: Interval-calibration landing

**Branch**: `codex/interval-calibration-landing`  
**Date**: 2026-08-25  
**Roles (engaged)**: Ada, Fisher, Grace, Rose, Shannon, Melissa

## 1. Goal

Reconcile the completed interval-calibration programme onto a fresh local
branch based on current `origin/main`, while preserving the active random-slope
and latent-variable lanes. The landing had to reproduce every scientific claim
and evidence hash, account for every replayed commit and path, and remain local.

### Mathematical Contract

No public R API, likelihood, formula grammar, family, C++, NAMESPACE,
generated-Rd, vignette, or pkgdown-navigation change was designed in this
landing arc. It transports the already completed interval-calibration
programme without changing its estimands or terminal dispositions. In
particular, CI-08 remains `route-only`; exactly three frozen CI-13 regimes are
certified; CI-09, CI-14, and CI-15 remain blocked; CI-10 remains
limited/blocked by route; and CI-11/12 remain refused.

## 2. Implemented

- Created the local-only branch `codex/interval-calibration-landing` from exact
  current-main snapshot `1bacee9a808b4106ce681502463baa317dcb9d9b`.
- Replayed all 34 interval-calibration commits in chronological order from the
  completed source branch. Thirty-three were patch-equivalent; one required a
  check-log reconciliation because current main contained later LV and
  random-slope history.
- Accounted for all 103 source-delta paths. Ninety-eight have exact source blob
  equality; the five shared surfaces have a three-parent reconciliation receipt.
- Preserved all frozen foreign-lane paths. The deliberate negative control
  failed on the old source base and passed on the landing branch.
- Reverified the 19-route census, the 150,019-row all-attempt ledger, the
  18-row target table, exact SHA-256 hashes, claim oracle, and focused interval
  tests.
- Kept the source branch unchanged at
  `4ba533949d7dae264268ae55f3c7fc801ee87da5` and performed no push, PR,
  merge, release, workflow edit, or science compute.

## 4. Files Touched

The complete per-path inventory is the 103-row
`docs/dev-log/artifacts/interval-calibration/landing-path-accounting.csv`.
That machine-readable file is the authoritative exhaustive list and records
source, landing, and reconciliation status for every path.

Landing-specific tracked files are:

- `docs/dev-log/artifacts/interval-calibration/landing-commit-map.csv`
- `docs/dev-log/artifacts/interval-calibration/landing-path-accounting.csv`
- `docs/dev-log/artifacts/interval-calibration/landing-replay-tip.txt`
- `docs/dev-log/artifacts/interval-calibration/landing-shared-file-reconciliation.csv`
- `docs/dev-log/after-task/2026-08-25-interval-calibration-landing.md`
- `docs/dev-log/plan-actual/2026-08-25-interval-calibration-landing.md`
- `docs/dev-log/handover/2026-08-25-interval-calibration-landing.md`
- `docs/dev-log/check-log.md`

The five reconciled shared surfaces are `.gitignore`, `NEWS.md`,
`_pkgdown.yml`, `docs/design/35-validation-debt-register.md`, and
`docs/dev-log/check-log.md`. No example source was newly designed or edited
beyond the exact replay.

### 3a. Decisions and Rejected Alternatives

**Decision:** land into an isolated nested clone with writable Git metadata.
**Rationale:** the desktop worktree could not create its linked-worktree
`index.lock`, and app-level task/worktree creation did not complete. The nested
clone is ignored, local, exact-base bound, and exportable as a Git bundle.
**Rejected alternative:** edit the completed source branch or bypass the failed
metadata lock. **Confidence:** high.

**Decision:** reconcile only the five audited shared paths and retain current
main history in full. **Rationale:** all other replayed paths were exact, while
the check log had legitimate newer LV and random-slope entries. **Rejected
alternative:** take the source side wholesale or manually widen the replay.
**Confidence:** high, supported by the structured reconciliation receipt.

## 5. Checks Run

- `Rscript --vanilla .unlazy/interval-calibration-landing/verify-local-lease.R`
  -> `LANDING_LEASE_RECEIPT_OK paths=110`.
- `Rscript --vanilla .unlazy/interval-calibration-landing/verify-foreign-leases.R`
  -> `FOREIGN_LANE_PATHS_CLEAR lanes=2 delta=107`.
- `Rscript --vanilla .unlazy/interval-calibration-landing/verify-lineage.R`
  -> `LANDING_LINEAGE_OK commits=34 paths=103`.
- `Rscript --vanilla .unlazy/interval-calibration-landing/verify-shared-reconciliation.R`
  -> `SHARED_RECONCILIATION_RECEIPT_OK rows=5`.
- Unlazy branch leaf `--reverify` -> `ALL MET (6 met)`.
- Unlazy evidence leaf `--reverify` -> `ALL MET (4 met)`; route census,
  hashes, claims, and focused tests passed.
- Unlazy integration leaf `--reverify` -> `ALL MET (3 met)`.
- Focused interval suite -> `LANDING_FOCUSED_TESTS_OK`.
- Claim verifier -> `INTERVAL_CLAIMS_OK`.
- Route census -> `LANDING_ROUTE_CENSUS_OK` (19 routes; three certified).
- Evidence read-back -> `LANDING_EVIDENCE_HASHES_OK`: all-attempt ledger
  150,019 rows, SHA-256
  `f8c1f33308b0ccb9bed684a99a746f415d79f090875756a6eba752e577dfbe4a`;
  target table 18 rows, SHA-256
  `3d204c754d9cada7858c656341a7d8234c018af9a7c874772b666632018f9047`.
- `git diff --check` -> `LANDING_DIFF_CLEAN`.
- Rose, Grace, and the statistical reviewer independently returned PASS at
  exact reconciliation SHA
  `c342c5e266e29ac108419e9085fe9beec288a7fa`. Grace independently reran
  lineage, reconciliation, foreign-lane, seed, claim, evidence-count, and
  focused-test checks. No P0--P3 or load-bearing finding remained.
- `gh pr list --state open --limit 20` was attempted before the shared-file
  closure edit but network access to `api.github.com` was unavailable. The
  frozen global lease snapshot and six-hour all-branch log were therefore used
  fail-closed; they showed no overlapping unaccounted owner.

The source programme already ran the complete 523-file ordinary suite,
documentation generation, two affected article renders, and
`pkgdown::check_pkgdown()`. This landing reran the affected focused tests and
exact evidence/claim oracles because it changes no implementation relative to
that source programme.

## 6. Tests of the Tests

No new package test was added in this landing arc. The landing verifier's
negative control was executed on the old source base and rejected it because
five current-main LV paths were absent. The same frozen oracle passed only
after replay onto current main. Existing interval tests retain boundary,
malformed-input, duplicate-row, failed-endpoint, and fail-closed promotion
controls; the exact claim oracle also rejects widening beyond the three CI-13
certificate rows.

## 8. Consistency Audit

Exact landing-specific scans and verdicts:

```sh
rg -n "^<<<<<<<|^=======$|^>>>>>>>" .gitignore NEWS.md _pkgdown.yml docs/design/35-validation-debt-register.md docs/dev-log/check-log.md
# No conflict markers.

rg -n "certified|limited|blocked|refused|route-only" docs/dev-log/artifacts/interval-calibration docs/design/35-validation-debt-register.md docs/design/75-inference-route-truth-matrix.md docs/dev-log/known-limitations.md
# The public and internal status surfaces retain the terminal route ledger; only three CI-13 rows are certified.

rg -n "CI-08|CI-09|CI-10|CI-11|CI-12|CI-13|CI-14|CI-15" docs/dev-log/artifacts/interval-calibration/public-route-census.csv docs/design/75-inference-route-truth-matrix.md
# Every CI-08--CI-15 identifier is present in both the census and truth matrix.

rg -n "random.slope|column.slope|mixed.family|latent.variable|LV" NEWS.md docs/design/35-validation-debt-register.md docs/dev-log/check-log.md
# Current-main random-slope and LV history remains present; the landing did not replace those entries.
```

The full stale-wording scan from the source programme remains recorded in
`docs/dev-log/after-task/2026-08-25-interval-calibration-release.md`; no new
reader-facing wording was authored in this landing arc.

### Roadmap Tick

N/A. This landing changes no `ROADMAP.md` row or progress bar.

## 7a. Issue Ledger

No relevant open issue was identified from the completed source packet, and no
issue was created, commented on, or closed. Live issue/PR inspection was not
possible because outbound GitHub access was unavailable. Public tracker action
was also outside the approved local-only authority.

## 9. What Did Not Go Smoothly

The linked desktop worktree could not create its Git `index.lock`. A real
isolated clone under the ignored landing root provided writable metadata
without touching another lane. The first focused-test wrapper was interrupted
during compilation and left a transient untracked object; the file disappeared
after the compiler stopped, the clean-tree gate passed, and the full focused
test was then rerun to completion. The global lease registry was read-only in
the sandbox, so the lane used a verified local exact-path lease, four Unlazy
ownership locks, a frozen foreign-lease snapshot, and a fail-closed delta
oracle. These are recorded as fallback controls, not as evidence that the
global registry was written.

## 11. Team Learning

**Ada** kept landing separate from science and constrained post-replay changes
to eight named receipt paths. The key lesson is that a landing arc needs its
own path/commit oracle; a clean cherry-pick alone is not proof.

**Fisher** checked that the landing preserved the terminal estimands and
status boundaries rather than reopening calibration. Future statistical work
must start a new arc; landing cannot manufacture stronger evidence.

**Grace** required exact-base ancestry, immutable evidence hashes, complete
path accounting, no upstream, and a bundle-based handoff. The sandbox lease
fallback is acceptable only because the clone is local-only and the
foreign-path oracle fails closed. Grace's exact-SHA PASS retains three residual
risks: no fresh full check/three-OS run, external campaign archives were not
rehashed in the nested clone, and the global lease registry remained read-only.

**Rose** required current-main history to survive the shared-file
reconciliation and every reader-facing status to remain no stronger than the
terminal ledger. Rose returned exact-SHA PASS after the five-row reconciliation
matrix, claim oracle, and foreign-lane sentinels all passed.

**Shannon** found no unaccounted path collision in the frozen lease snapshot
or recent all-branch log. Live GitHub coordination could not be refreshed, so
that limitation remains explicit.

**Melissa** found the landing on scope across science, compute, review,
claims, and handoff. The nested clone is an implementation deviation, not a
scientific or public-scope deviation.

## 10. Known Residuals

The branch is local and unmerged; local tests do not establish three-OS CI or
release readiness. The nested clone must be imported from the verified Git
bundle before any later PR, and push/PR/merge/release still require explicit
authority. CI-08 exact constrained profiles, an identified CI-09 design, a
successful CI-10 cost preflight, and repaired CI-14/15 provenance remain
separate future science arcs. The already active random-slope and LV arcs were
not part of this work and should continue under their current owners.

## 12. Cross-Product Coverage

This landing covers the exact CI-08--CI-15 source delta, its retained
all-attempt and target evidence, the five current-main shared surfaces, and the
public terminal claim ledger. It does NOT cover new interval estimators,
alternative DGPs, another family/rank/sample-size/rotation cell, MSPL,
prediction or missing-data intervals, random-slope recovery, LV expansion,
three-OS CI, merge readiness, or release readiness.
