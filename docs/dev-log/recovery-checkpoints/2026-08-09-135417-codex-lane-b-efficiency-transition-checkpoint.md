# Lane B efficiency-transition checkpoint — 2026-08-09 13:54 UTC

## Lifecycle decision

This task has crossed the requested efficiency-transition boundary after more
than one context compaction. The smallest safe in-flight action—the installed
source `R CMD check`—was allowed to finish. No remote job, feeder, branch,
permission boundary, Codex configuration, or model setting was changed. The
next work belongs in a fresh task that resolves to GPT-5.6 Terra at medium
effort.

Current runtime identity visible to this task: Codex, GPT-5 family. The exact
model label and reasoning-effort setting are not exposed by the available
runtime tools, so they are not asserted more narrowly.

## Updated goal

The maintainer narrowed the primary 0.7 target to complete-Bernoulli ordinary
latent Paper × Items GLLVMs with logit, probit, and first-class cloglog at
`q = 1:2`. The ordinary latent block retains residual item dependence through
`Lambda Lambda^T`. Spatial MSPL is secondary and explicitly experimental; it
cannot block the primary ordinary claim. FIML/missing cells, grouped binomial,
mixed families, `q > 2`, phylo/animal/kernel MSPL, VA/AGHQ/Julia MSPL, rank
selection, and general inference remain deferred.

## Repository state

- Repository: `/private/tmp/gllvmtmb-lane-b-mspl`
- Canonical project: `/Users/z3437171/Dropbox/Github Local/gllvmTMB`
- Branch: `codex/lane-b-mspl-20260808`
- HEAD: `7af5cf00d5f14b1988b84a42a5fed7dde2b62748`
- Upstream comparison shown by git: `origin/main`
- `git diff --check`: PASS at checkpoint
- No commit, push, PR, branch switch, or permission-boundary change was made.
- The attempted Paper × Items article patch failed apply-patch verification and
  changed no bytes. The article still begins `Keep rare species in a binary
  JSDM with LA-MSPL` and must be converted in the fresh task.

Dirty files owned by this Lane B task:

```text
 M DESCRIPTION
 M NEWS.md
 M R/aghq-report.R
 M R/bootstrap-sigma.R
 M R/check-consistency.R
 M R/check-identifiability.R
 M R/confint-inspect.R
 M R/diagnose.R
 M R/extract-correlations.R
 M R/extract-omega.R
 M R/extract-repeatability.R
 M R/extractors.R
 M R/fit-multi.R
 M R/gllvmTMB.R
 M R/loading-ci.R
 M R/loading-profile.R
 M R/methods-gllvmTMB.R
 M R/output-methods.R
 M R/plot-gllvmTMB.R
 M R/profile-ci.R
 M R/profile-derived-curves.R
 M R/profile-derived.R
 M R/profile-targets.R
 M R/proportions-ci.R
 M R/re-uncertainty.R
 M R/screen-gllvmTMB.R
 M R/standard-errors.R
 M R/vcov-coef.R
 M R/z-confint-gllvmTMB.R
 M _pkgdown.yml
 M docs/design/03-likelihoods.md
 M docs/design/05-testing-strategy.md
 M docs/design/35-validation-debt-register.md
 M docs/dev-log/check-log.md
 M inst/CITATION
 M man/gllvmTMB.Rd
 M man/gllvmTMB_multi-methods.Rd
 M man/gllvmTMBcontrol.Rd
 M man/screen_control.Rd
 M man/screen_gllvmTMB.Rd
 M man/screen_table.Rd
 M src/gllvmTMB.cpp
 M vignettes/articles/behavioural-syndromes.Rmd
 M vignettes/articles/pre-fit-response-screening.Rmd
?? R/mspl.R
?? R/screen-separation.R
?? docs/design/88-binary-mspl-estimator.md
?? docs/dev-log/after-task/2026-08-08-lane-b-binary-mspl.md
?? docs/dev-log/recovery-checkpoints/2026-08-08-202656-codex-lane-b-mspl-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-08-08-214650-codex-lane-b-b2-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-08-09-010041-codex-lane-b-mspl-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-08-09-033522-codex-lane-b-b2-distributed-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-08-09-135417-codex-lane-b-efficiency-transition-checkpoint.md
?? inst/sim/
?? src/lane_b_jeffreys_maxvol_atomic_v8.h
?? tests/testthat/test-mspl-api.R
?? tests/testthat/test-mspl-simulation-contract.R
?? tests/testthat/test-screen-separation.R
?? vignettes/articles/mspl-binary-jsdm.Rmd
```

## Completed milestone and verification

The implementation milestone is complete enough for evidence collection:

- B0 fixed-design separation screening is implemented and its exact campaign
  is complete: 2,880 shards / 72,000 datasets, with no `NOT_CHECKED` rows.
- B1 opt-in `estimator = "mspl"` is implemented for admitted complete-Bernoulli
  logit, probit, and cloglog models. Default `estimator = "ml"` is unchanged.
- The ordinary `q = 1:2` TMB objective, penalty decomposition, fixed-only
  Jeffreys path, numerical guard, divergent rays, and independent positive
  Cauchy–Binet oracle have passed the recorded reviews/oracles.
- Public likelihood/inference methods fail closed for MSPL where calibration
  is not earned.
- The focused suite
  `devtools::test(filter = "(mspl-api|screen-separation|mspl-simulation-contract)")`
  passed.
- A complete local `devtools::test()` passed after about 32 minutes with only
  declared heavy-test skips and two pre-existing `gllvm` all-zero-row warnings.
- `pkgdown::check_pkgdown()` returned `No problems found`.
- The current source package was installed into isolated library
  `/private/tmp/gllvmtmb-pkgdown-lib.dGMmJV`; with that library prepended to the
  normal dependency libraries, `pkgdown::build_articles(lazy = FALSE)` rendered
  the complete article set successfully, including the MSPL and screening
  articles.
- `devtools::document()` completed and regenerated the current Rd files. It
  emitted existing unresolved internal-CV-link warnings plus roxygen warnings
  for the existing AIC/BIC/anova S3 definitions; these were not widened into a
  repair in this bounded milestone.

The installed-source check is the one incomplete local gate:

```text
Rscript --vanilla -e 'devtools::check(
  args = "--no-manual", quiet = TRUE, error_on = "never"
)'
```

finished in 16m 37.5s with:

```text
1 error, 0 warnings, 0 notes
[ FAIL 1 | WARN 2 | SKIP 839 | PASS 10161 ]
```

The two testthat warnings are the known `gllvm` comparator warnings. The sole
error is packaging-context specific, not an MSPL fit failure:

```text
test-mspl-simulation-contract.R:812
archived quasi provenance validates without the current runtime
Error in lane_b_harness_dir(): Cannot resolve the Lane B harness directory.
```

The source-tree full suite passes because `lane_b_harness_dir()` can find
`inst/sim/lane-b`; the built tarball test cannot. The check saved the failure
as `_problems/test-mspl-simulation-contract-812.R` inside its temporary check
tree, which is not a worktree change.

## Remote compute that must remain untouched

Authoritative roots and hashes remain those in
`2026-08-09-033522-codex-lane-b-b2-distributed-checkpoint.md`:

- Totoro campaign root:
  `/home/snakagaw/gllvmtmb_lane_b_b2_20260808_v1`
- DRAC campaign root on each cluster:
  `/scratch/snakagaw/lane_b_main_20260809`
- Source checkout on Totoro:
  `/home/snakagaw/gllvmtmb_lane_b_20260808_v1`
- Source HEAD: `b1341c29d174b744e45e1082379d72555b683a45`
- Frozen campaign SHA-256:
  `1147ea898b37720e393b9acaf524675d4ca805bf497d1038291027705869db98`

Running state at the last authenticated observations:

- Totoro: paused launcher `3384266` must never be resumed. Its 48 original R
  children were still live and CPU-active; last authoritative merged count was
  1,640 complete, zero failures. Terminate the stopped launcher only after its
  48 children finish and ownership is reconciled.
- Nibi: local feeder PID `83639` is alive, lock
  `/private/tmp/lane-b-nibi-feeder-v1.lock` is present, and it remains the sole
  submission owner. At checkpoint its atomic next index is 665. Latest job
  `19399449` covers exact future-list indices 652--664; its last poll reported
  617 complete, 997 submitted user elements, and zero failures. Do not submit
  manually or restart the feeder while PID/lock are live.
- Rorqual: all 2,115 shards are scheduled. Last observation was 1,498 complete,
  215 running locks, zero failures. Main arrays include `18702102`; keeper
  `18707978` remains dependency-held and must run before collection.
- Trillium: main job `2075245` and dependency-held keeper `2075452` remain
  active. Last observation was 414 complete, 150 running locks, zero failures.
- Fir main and quasi archives are already authenticated and installed at the
  Totoro root. The quasi supplement withheld promotion for all six link × rank
  families under its frozen multistart gate; do not relax that evidence.

The installed `/Users/z3437171/.codex/tools/totoro-campaign-status` wrapper has
no local profile file and therefore was not reconfigured or used. No permission
or configuration change was made to force it.

## Exact next action

First repair only the installed-tarball provenance test:

1. Inspect `lane_b_harness_dir()` and
   `lane_b_quasi_source_receipt()` in `inst/sim/lane-b`, plus
   `tests/testthat/test-mspl-simulation-contract.R:800-820`.
2. Make the smallest source/install-aware resolution, preferably using the
   installed `system.file("sim", "lane-b", package = "gllvmTMB")` path when a
   source checkout is absent. Do not weaken exact archived-receipt comparison
   and do not skip the installed-package case merely to make check green.
3. Run the focused test from the source tree, then install to an isolated
   library and run the same test from the installed package context.
4. Re-run `devtools::check(args = "--no-manual", error_on = "never")`.

After that atomic repair, continue external monitoring without repartitioning:
let the Nibi feeder finish, authenticate each keeper archive, merge only raw and
completion receipts into Totoro, run ordinary-first strict adjudication, then
convert `vignettes/articles/mspl-binary-jsdm.Rmd` to the approved Paper × Items
cloglog-first story. Spatial wording remains experimental/partial and cannot
block the ordinary claim.

## Fresh-task prompt

```text
Use GPT-5.6 Terra at medium effort. Continue the active gllvmTMB Lane B goal
from:
/private/tmp/gllvmtmb-lane-b-mspl/docs/dev-log/recovery-checkpoints/2026-08-09-135417-codex-lane-b-efficiency-transition-checkpoint.md

Repository: /private/tmp/gllvmtmb-lane-b-mspl
Branch: codex/lane-b-mspl-20260808
HEAD: 7af5cf00d5f14b1988b84a42a5fed7dde2b62748

Read that checkpoint and the earlier distributed checkpoint before acting.
Do not stop/restart/repartition remote compute. Do not manually submit Nibi
while feeder PID 83639 and its lock are alive. First fix the single installed-
tarball R CMD check failure at test-mspl-simulation-contract.R:812 without
weakening archived provenance validation, prove it in source and installed
contexts, and rerun the source check. Then resume authenticated keeper
collection/adjudication. The primary 0.7 claim is ordinary complete-Bernoulli
Paper × Items latent GLLVMs, q=1:2, all logit/probit/cloglog with cloglog first-
class; spatial is experimental and cannot block ordinary promotion. The
Paper × Items article conversion has not yet been applied.
```

START A FRESH TASK — checkpoint is complete; ongoing external compute remains untouched.
