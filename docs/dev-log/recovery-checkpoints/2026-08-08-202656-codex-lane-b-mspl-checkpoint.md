# Lane B LA-MSPL recovery checkpoint

Date: 2026-08-08 20:26 MDT
Owner: Codex
Branch: `codex/lane-b-mspl-20260808`
Base: `origin/main` at `7af5cf00` when the worktree was created

## Working-tree state

`git status --short --branch` reports the expected uncommitted Lane B changes.
The main implementation surfaces are `R/mspl.R`, `R/screen-separation.R`,
`R/fit-multi.R`, `R/gllvmTMB.R`, `R/methods-gllvmTMB.R`,
`src/gllvmTMB.cpp`, and
`src/lane_b_jeffreys_maxvol_atomic_v8.h`. Tests, simulation machinery,
reference documentation, two articles, NEWS, design documents, and generated Rd
files are also modified or new. `git diff --check` passed. The current tracked
diff is 24 files, 1,178 insertions and 83 deletions; untracked Lane B files are
not included in that count.

The pre-edit shared-file check found no open GitHub pull requests. Recent
six-hour commits on other refs concern the distinct integrated-SDM lane; no
Lane B file collision was found. The separate CRAN worktree at
`/private/tmp/gllvmtmb-cran-0.7-20260807` remains untouched.

## Commands completed

- `devtools::test(reporter = "summary")`: PASS; no failures, two known
  comparator warnings, 800 deliberate heavy/optional skips.
- `devtools::test(filter = "mspl", reporter = "summary")`: PASS after the
  private-header packaging rename.
- `devtools::document(quiet = TRUE)`: completed; only pre-existing unresolved
  internal-CV links and existing AIC/BIC/anova S3-tag warnings.
- `pkgdown::check_pkgdown()`: PASS.
- `pkgdown::build_article("articles/mspl-binary-jsdm", new_process = FALSE)`:
  PASS after explicitly naming `unit` and `trait` in long-format examples.
- The affected pre-fit screening article rendered successfully earlier.
- `devtools::load_all(recompile = TRUE, quiet = TRUE)`: PASS after renaming the
  private C++ header from `.hpp` to CRAN-recognised `.h`.
- B0 fixed-design screen tests, B1 compiled objective/oracle tests, B2 harness
  tests, local five-cell smoke, and nine-cell spatial construction/oracle grid:
  PASS at their stated scopes.
- An initial `R CMD build . --no-build-vignettes` succeeded. Its check is still
  running against the pre-header-rename tarball; it exposed the now-repaired
  `.hpp` filename warning and the expected no-build-vignettes warning.

## Running external evidence

The frozen B2 campaign is running on Totoro at
`/home/snakagaw/gllvmtmb_lane_b_b2_20260808_v1`, using 120 processes and one
BLAS thread per process. Frozen manifest: 192 cells, 130,800 data sets, 561,600
primary fits, 8,472 shards; source receipt SHA-256
`1147ea898b37720e393b9acaf524675d4ca805bf497d1038291027705869db98`.
At this checkpoint: 116 shards complete, zero failed, 120 locks active. Raw
campaign output remains on Totoro. The subsequent local `.hpp` to `.h` rename
is packaging-only; the header bytes and compiled estimator are unchanged, but
the path change must be recorded with the final evidence receipt.

## Still to run

1. Monitor the frozen Totoro queue; do not alter or restart completed shards.
2. Aggregate only when all 8,472 shards are complete; retain every failed fit
   and apply the frozen cellwise promotion gates without threshold changes.
3. Rebuild with the normal vignette path and run `R CMD check --no-manual` on
   the exact final source after the campaign-driven scope wording is settled.
4. Complete Rose pre-publish, Gauss/Noether/Fisher, after-task, and Shannon
   audits; update the validation register and article strictly from B2 results.
5. Add the required check-log and 11-section after-task report, then perform
   three-OS checks and a clean handoff. Do not claim the estimator finished
   before these gates pass.

## Next safest action

Let the Totoro queue continue unchanged. In parallel, finish read-only public
surface audits and the exact-source package check. If the B2 campaign exposes a
cell failure, narrow the advertised surface rather than changing a frozen gate
or discarding attempts.

## Blocking question

None. The remaining dependency is completion and honest aggregation of the
frozen Totoro campaign.
