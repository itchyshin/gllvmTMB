# After Task: RE-03 non-Gaussian s=2 sweep retry prep

**Branch**: `codex/re03-nongaussian-s2-sweep-2026-06-05`
**Date**: `2026-06-05`
**Roles (engaged)**: Ada, Boole, Fisher, Curie, Rose, Grace

## 1. Goal

Prepare the next RE-03 evidence run without advertising a new capability.
Gaussian `phylo_dep(1 + x1 + x2 | species)` is already covered, but
non-Gaussian `s >= 2` full-unstructured dependent slopes still need an
identifiability sweep before any allowlist relaxation. This branch adds a
dedicated runtime guard and gives the existing dep-slope sweep a real `s = 2`
path so GitHub Actions can collect that evidence.

## 2. Implemented

- `R/fit-multi.R` now aborts non-Gaussian `phylo_dep` fits with two or more
  random slopes. The single-slope non-Gaussian `phylo_dep(1 + x | species)`
  path remains admitted by the existing PHY-18 evidence.
- `tests/testthat/test-phylo-dep-slope-s2-gaussian.R` adds a boundary test that
  checks the new fail-loud message for a Poisson `s = 2` fit.
- `.github/workflows/dep-slope-identifiability-sweep.yaml` adds workflow input
  `s_grid` and forwards it to the sweep script as `GLLVMTMB_SWEEP_SGRID`.
- `docs/dev-log/spikes/2026-06-01-phylo-dep-slope-identifiability-N-sweep.R`
  now supports `s = 1` and `s = 2`, carries `n_slope` in the result schema,
  computes all slope-variance ratios for `(1+s)T`, and reports both PD and
  recovery fractions in the cumulative table.
- `NEWS.md` and `docs/design/35-validation-debt-register.md` now describe the
  non-Gaussian RE-03 boundary as a dedicated runtime guard rather than the
  older wording that implied the old Gaussian-only dep-slope guard was still
  the mechanism.

## 3. Mathematical Contract

No TMB likelihood, C++ parameterisation, or formula grammar changed. The model
boundary is:

`Sigma_b` for `phylo_dep(1 + x1 + ... + xs | species)` has dimension
`(1+s)T x (1+s)T`, with per-trait intercept and slope columns stored in the
same interleaved order as the Gaussian RE-03 test. This branch does not claim
non-Gaussian identifiability for that full unstructured covariance. The sweep
harness deliberately bypasses the public guard only to test whether the same
family-agnostic dep contribution can recover under non-Gaussian likelihoods.

## 4. Files Changed

- `.github/workflows/dep-slope-identifiability-sweep.yaml`
- `R/fit-multi.R`
- `tests/testthat/test-phylo-dep-slope-s2-gaussian.R`
- `tests/testthat/test-matrix-slope-phylo-dep.R`
- `docs/dev-log/spikes/2026-06-01-phylo-dep-slope-identifiability-N-sweep.R`
- `docs/design/35-validation-debt-register.md`
- `NEWS.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-05-re03-nongaussian-s2-sweep.md`

## 5. Checks Run

- `gh pr list --repo itchyshin/gllvmTMB --state open --limit 20 --json number,title,headRefName,baseRefName,author,updatedAt,url`
  -> `[]`; no open PR collision.
- `git log --all --oneline --since="6 hours ago"`
  -> no output; no recent same-file collision.
- `Rscript --vanilla -e 'devtools::test(filter = "phylo-dep-slope-s2-gaussian")'`
  -> `FAIL 0 | WARN 0 | SKIP 4 | PASS 1`.
- `Rscript --vanilla -e 'devtools::test(filter = "matrix-slope-phylo-dep")'`
  -> `FAIL 0 | WARN 0 | SKIP 14 | PASS 0`.
- `git diff --check`
  -> clean.
- `GLLVMTMB_SWEEP_FAMILIES=gaussian GLLVMTMB_SWEEP_SGRID=2 GLLVMTMB_SWEEP_NGRID=6 GLLVMTMB_SWEEP_SEEDS=101 GLLVMTMB_SWEEP_NREP=2 GLLVMTMB_SWEEP_OUT=/tmp/gllvmtmb-re03-s2-tiny.csv Rscript --vanilla docs/dev-log/spikes/2026-06-01-phylo-dep-slope-identifiability-N-sweep.R`
  -> completed with `IDENTIFIABILITY_SWEEP_DONE`; the tiny underpowered
  Gaussian control cell reported `conv = 1`, `pdHess = FALSE`, which is not a
  recovery claim. It only verifies the new `s = 2` script path.
- After adding this report and the check-log entry, the same smoke was rerun
  with `GLLVMTMB_SWEEP_OUT=/tmp/gllvmtmb-re03-s2-tiny-after-log.csv`
  -> same expected underpowered-cell outcome and `IDENTIFIABILITY_SWEEP_DONE`.
- `gh workflow run dep-slope-identifiability-sweep.yaml --repo itchyshin/gllvmTMB --ref codex/re03-nongaussian-s2-sweep-2026-06-05 -f families=gaussian,poisson,nbinom2,Gamma,Beta,binomial,ordinal_probit -f s_grid=2 -f n_grid=300,600 -f seeds_per_run=3 -f n_rep=10 -f end_date=2026-06-08`
  -> dispatched <https://github.com/itchyshin/gllvmTMB/actions/runs/27050546985>.
- `gh run watch 27050546985 --repo itchyshin/gllvmTMB --exit-status --interval 30`
  -> run succeeded in 55m31s.
- `gh run download 27050546985 --repo itchyshin/gllvmTMB --name dep-slope-campaign-run-20 --dir /tmp/gllvmtmb-re03-run-27050546985-artifact`
  -> downloaded `dep-slope-campaign.log` and `dep-slope-sweep-accumulated.csv`.
- `Rscript --vanilla -e ...` summariser over
  `/tmp/gllvmtmb-re03-run-27050546985-artifact/dep-slope-sweep-accumulated.csv`
  (exact one-line command recorded in `docs/dev-log/check-log.md`)
  -> see outcome table below.

Remote `s = 2` outcome from run 20:

| family | n_sp=300 PD | n_sp=300 recovery | n_sp=600 PD | n_sp=600 recovery |
|---|---:|---:|---:|---:|
| gaussian | 3/3 | 3/3 | 3/3 | 3/3 |
| poisson | 3/3 | 2/3 | 3/3 | 3/3 |
| Gamma | 3/3 | 1/3 | 3/3 | 3/3 |
| Beta | 3/3 | 1/3 | 3/3 | 3/3 |
| binomial | 3/3 | 2/3 | 3/3 | 3/3 |
| nbinom2 | 2/3 | 1/3 | 3/3 | 2/3 |
| ordinal_probit | 1/3 | 0/3 | 3/3 | 2/3 |

The result store was committed to `dep-slope-sweep-results` at `643f7a9`
(`dep-slope campaign: accumulate seeds (run 20)`), and the accumulated CSV now
has 1,659 data rows.

## 6. Tests of the Tests

The new test is a boundary/prophylactic guard test: it asserts that a
non-Gaussian `phylo_dep` fit with two slopes aborts with RE-03 language rather
than silently entering an unvalidated full unstructured covariance path. The
heavy Gaussian recovery tests in the same file are unchanged and remain gated
behind `GLLVMTMB_HEAVY_TESTS=1`.

The sweep smoke is a harness test, not a recovery test. It verifies that the
new `n_slope` result schema and aggregation can process an `s = 2` cell.

## 7. Consistency Audit

- `rg -n "RE-03|PHY-18|s >= 2|s ≥ 2|phylo_dep\\(1 \\+ x1|non-Gaussian s" README.md ROADMAP.md NEWS.md docs vignettes R tests/testthat`
  -> expected RE-03 reservation language and new guard/sweep text found. Older
  capability-status prose outside this RE-03 lane was not broadened into this
  PR.
- `rg -n "GLLVMTMB_SWEEP_SGRID|s_grid|n_slope|slope_var_ratio_min|recovery_frac" .github/workflows/dep-slope-identifiability-sweep.yaml docs/dev-log/spikes/2026-06-01-phylo-dep-slope-identifiability-N-sweep.R`
  -> workflow input and script schema are aligned.
- `rg -n "Gaussian-only family guard|gaussian-only|non-Gaussian s >= 2|non-Gaussian s ≥ 2|RE-03 runtime guard|two or more random slopes" NEWS.md docs/design/35-validation-debt-register.md R/fit-multi.R tests/testthat/test-phylo-dep-slope-s2-gaussian.R tests/testthat/test-matrix-slope-phylo-dep.R docs/dev-log/spikes/2026-06-01-phylo-dep-slope-identifiability-N-sweep.R`
  -> the stale RE-03 mechanism wording was replaced in the touched files;
  unrelated guard comments stayed out of scope.

## 8. Roadmap Tick

N/A. RE-03 remains `partial`: Gaussian `s = 2` is covered; non-Gaussian
`s >= 2` remains reserved pending sweep evidence.

## 9. GitHub Issue Ledger

- #340 (`Capability matrix -- live status board`) inspected. Its board already
  records non-Gaussian `s >= 2` multi-slope as reserved.
- #341 (`[roadmap] Random-slope completion`) inspected. Its latest roll-up
  records the structured non-Gaussian single-slope grid as complete but leaves
  multi-slope `s >= 2` outside the completed evidence.
- #341 commented with the successful dispatch result and recovery table:
  <https://github.com/itchyshin/gllvmTMB/issues/341#issuecomment-4637270995>.
- No issue closed. No new issue created; this branch is the direct next action
  for the RE-03 residual item already named on #340/#341.

## 10. What Did Not Go Smoothly

The prior wording around "Gaussian-only family guard unchanged" became stale
after PHY-18 admitted non-Gaussian single-slope `phylo_dep`. The fix is not to
re-reserve single slopes, but to add the correct narrower guard: non-Gaussian
`s >= 2` only.

The local `s = 2` smoke used a deliberately tiny Gaussian cell and therefore
did not recover. That result should not be read as evidence for or against
RE-03; it only proves the harness runs.

## 11. Team Learning

Ada: The right next step is evidence collection, not capability promotion. This
branch keeps the public surface conservative while making the remote sweep
possible.

Boole: Formula grammar did not change. The guard sits after parser
classification and only narrows the runtime admissibility boundary for
non-Gaussian multi-slope `phylo_dep`.

Fisher: The sweep now reports recovery fractions in addition to PD fractions,
so a future "covered" decision cannot rest on convergence alone.

Curie: The guard test is cheap and always-on; the recovery evidence remains in
heavy / dispatched workflows where the sample sizes are realistic.

Rose: The stale wording was the main consistency risk. The register, NEWS, test
comments, and spike comments now use the same RE-03 boundary.

Grace: The workflow default remains `s_grid = 1` for scheduled runs, so the
existing campaign behavior is preserved. Manual dispatch can opt into `s_grid =
2` for the RE-03 feasibility sweep.

## 12. Known Limitations And Next Actions

- Add more high-N `s = 2` seeds at `n_sp = 600` for `nbinom2` and
  `ordinal_probit`, or dispatch an `n_sp = 1200` check if the 600-seed
  recovery rate stays below the no-fake-pass threshold.
- Do not relax the non-Gaussian `s >= 2` guard unless at least one family has a
  non-skipped recovery cell with the same discipline used for PHY-18 and
  SPA-10.

## 13. Follow-Up Retry And Store Hardening

After the first remote dispatch, a narrower `n_sp = 600`, `s = 2` retry was
run on the same branch:

- Run: <https://github.com/itchyshin/gllvmTMB/actions/runs/27051802506>
- Head SHA: `c99b5dad222ccdf07973a3598efedc6ee64d62d8`
- Result: success in 42m50s
- Artifact: `/tmp/gllvmtmb-re03-run-27051802506-artifact/dep-slope-campaign-run-22/`
- Result-store commit: `c4c1325 dep-slope campaign: accumulate seeds (run 22)`

Run 22 added seeds `2201,2202,2203` for `s = 2`, `n_sp = 600`. Its fresh
seed evidence was:

| family | n_sp=600 PD | n_sp=600 recovery |
|---|---:|---:|
| gaussian | 3/3 | 3/3 |
| poisson | 3/3 | 3/3 |
| Gamma | 3/3 | 3/3 |
| Beta | 3/3 | 2/3 |
| binomial | 3/3 | 3/3 |
| nbinom2 | 3/3 | 2/3 |
| ordinal_probit | 2/3 | 2/3 |

Combining the run-20 and run-22 artifacts, deduplicated by
`family, n_slope, n_sp, seed`, gives this `s = 2` evidence table:

| family | n_sp=300 PD | n_sp=300 recovery | n_sp=600 PD | n_sp=600 recovery |
|---|---:|---:|---:|---:|
| gaussian | 3/3 | 3/3 | 6/6 | 6/6 |
| poisson | 3/3 | 2/3 | 6/6 | 6/6 |
| Gamma | 3/3 | 1/3 | 6/6 | 6/6 |
| Beta | 3/3 | 1/3 | 6/6 | 5/6 |
| binomial | 3/3 | 2/3 | 6/6 | 6/6 |
| nbinom2 | 2/3 | 1/3 | 6/6 | 4/6 |
| ordinal_probit | 1/3 | 0/3 | 5/6 | 4/6 |

The combined artifact evidence strengthens the feasibility signal at
`n_sp = 600`, but it still does not justify relaxing the public non-Gaussian
`s >= 2` guard. The weak cells remain `nbinom2` and `ordinal_probit`, with
Beta also below the full recovery threshold in the fresh retry.

One process issue was found: run 21 was a default single-slope campaign run
and rewrote the single global results CSV without the run-20 `s = 2` rows. The
artifacts from runs 20 and 22 remain intact, but the results branch cannot be
treated as a complete `s = 2` cumulative source until an s-specific store is
used. The workflow now keeps the default/scheduled single-slope store at
`dep-slope-sweep-accumulated.csv` and routes non-default `s_grid` runs to
`dep-slope-sweep-s<grid>-accumulated.csv`.

Additional checks for this follow-up:

- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/dep-slope-identifiability-sweep.yaml"); puts "yaml-ok"'`
  -> `yaml-ok`.
- `rg -n "dep-slope-sweep-accumulated|dep-slope-sweep-s|GLLVMTMB_SWEEP_STORE|GLLVMTMB_SWEEP_OUT|RESULTS_BRANCH|STORE" .github/workflows/dep-slope-identifiability-sweep.yaml docs/dev-log/check-log.md docs/dev-log/after-task/2026-06-05-re03-nongaussian-s2-sweep.md docs/dev-log/spikes/2026-06-01-phylo-dep-slope-identifiability-N-sweep.R`
  -> found the intended default store, new s-specific store route, spike
  environment variables, and the follow-up log/report text; no stale
  alternative store path found.
- `gh pr list --repo itchyshin/gllvmTMB --state open --limit 20 --json number,title,headRefName,baseRefName,author,updatedAt`
  -> `[]`; no open PR collision.
- `git log --all --oneline --since="6 hours ago"`
  -> only this RE-03 branch and results-branch workflow commits appeared; no
  competing shared-file edit detected.

Next safe action: seed the new `dep-slope-sweep-s2-accumulated.csv` store from
the run-20/run-22 artifacts, then dispatch a narrow high-N `s = 2` batch for
the weak families before considering any guard relaxation.

## 14. Dedicated s2 Store And High-N Weak-Family Run

The dedicated s2 store was seeded from the run-20 and run-22 artifacts:

- Store file: `dep-slope-sweep-s2-accumulated.csv`
- Seed-store commit on `dep-slope-sweep-results`:
  `d8814be dep-slope campaign: seed s2 store`
- Seeded rows: 63 `s = 2` data rows, deduplicated by
  `family, n_slope, n_sp, seed`

A follow-up run used the hardened workflow and the dedicated s2 store:

- Run: <https://github.com/itchyshin/gllvmTMB/actions/runs/27052868265>
- Head SHA: `74cdf17dbc66000acd8dacab07d5870bf0fcbab5`
- Result: success in 1h15m58s
- Artifact:
  `/tmp/gllvmtmb-re03-run-27052868265-artifact/dep-slope-campaign-run-23/`
- Result-store commit:
  `2c4f5df dep-slope campaign: accumulate seeds (run 23)`
- Issue update:
  <https://github.com/itchyshin/gllvmTMB/issues/341#issuecomment-4637607671>

Run 23 verified the store hardening: it restored, wrote, uploaded, and
persisted `dep-slope-sweep-s2-accumulated.csv`, not the default
single-slope CSV.

Cumulative `s = 2` evidence after run 23:

| family | n_sp=300 PD | n_sp=300 recovery | n_sp=600 PD | n_sp=600 recovery | n_sp=1200 PD | n_sp=1200 recovery |
|---|---:|---:|---:|---:|---:|---:|
| gaussian | 3/3 | 3/3 | 6/6 | 6/6 | - | - |
| poisson | 3/3 | 2/3 | 6/6 | 6/6 | - | - |
| Gamma | 3/3 | 1/3 | 6/6 | 6/6 | - | - |
| Beta | 3/3 | 1/3 | 9/9 | 8/9 | 3/3 | 2/3 |
| binomial | 3/3 | 2/3 | 6/6 | 6/6 | - | - |
| nbinom2 | 2/3 | 1/3 | 9/9 | 7/9 | 3/3 | 2/3 |
| ordinal_probit | 1/3 | 0/3 | 8/9 | 6/9 | 3/3 | 2/3 |

Fresh run-23 cells were all PD. At `n_sp = 600`, Beta and nbinom2 were 3/3
recovered and ordinal_probit was 2/3 recovered. At `n_sp = 1200`, Beta,
nbinom2, and ordinal_probit were each 2/3 recovered.

Final interpretation for this phase: the evidence argues strongly against a
structural no-go for non-Gaussian `phylo_dep` with `s = 2`, but it still does
not justify relaxing the public guard. RE-03 remains `partial`; non-Gaussian
`s >= 2` stays reserved pending stronger family-specific recovery evidence.
