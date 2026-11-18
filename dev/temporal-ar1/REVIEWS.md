# Independent review and reconciliation: temporal AR1

Date: 2026-09-08
Execution root: `/Users/z3437171/.codex/worktrees/cb78/gllvmTMB`
Branch: `codex/temporal-ar1-plan-20260908`

## Mathematical and likelihood review

An independent likelihood audit examined the replicated observation block and
the temporal score prior. It found that the native likelihood must integrate
the occasion-shared diagonal effect as `psi_j 11' + sigma_epsilon^2 I` within
each `(series, occasion, trait)` block, rather than add row-wise Gaussian
densities. The implementation now does this in `src/gllvmTMB.cpp`. The first
dense-oracle draft incorrectly put `psi` on only the diagonal; the production
code was correct and the independent oracle was repaired before it was used as
evidence.

The reconciled oracle checks stationary starts and AR1 transitions at
`phi = -0.7, 0, 0.65, 0.95`, dense marginal covariance for both workflows,
normalization constants, gradients, `phi = 0` reductions, the positive-AR1/OU
covariance identity, sign invariance, zero-loading invariance, and transformed
parameter boundary evaluations. `TEMPORAL_ORACLE_PASS` is the executable
receipt.

## User-workflow review

An independent user-path audit found six lifecycle hazards: private pair labels
in training predictions, missing-response admission, a second covariance
provider slipping through, absent early unsupported-method guards, lost score
indices after extraction/rotation, and incomplete replicated-wide/update
coverage. All six were repaired and are exercised by the parser/lifecycle
fixture. Public predictions now use `series`, `occasion`, optional
`measurement`, and `trait`; `getLV()` and ordination retain `temporal_index`;
and `update()` replays the stored public long or wide call.

`TEMPORAL_PARSER_PASS` and `TEMPORAL_METHODS_PASS` are the executable receipts.

## Follow-up reconciliation repair

Source review then found an iid-only reporting routine that reconstructed a
conditional `s_B` effect after the likelihood. Applying it to replicated
temporal observations overwrote an occasion--trait value once per measurement,
which could have made fitted linear predictors differ across measurements of
the same occasion and trait. Temporal likelihoods do not retain that iid
effect, so the reconstruction is now explicitly limited to non-temporal fits.
The replicated lifecycle fixture now asserts equal fitted linear predictors
for every same-series, same-occasion, same-trait measurement pair. The parser,
oracle, methods, and regression runners were rerun after recompilation and all
passed.

## Reconciliation status

The compatibility and documentation gate is green:
`TEMPORAL_REGRESSION_PASS` runs a clean ordinary-latent/wide/score/simulation/
phylogeny-kernel/spatial-companion fixture, `pkgdown::check_pkgdown()`, and the
temporal article render.

The bounded recovery gate remains **red**. Its retained 18 BFGS results are in
`recovery-results-bfgs.csv`, with criterion-level aggregation in
`recovery-cell-summary.csv`; every fit has convergence code zero, finite
objective, positive-definite Hessian, outer gradient at most `1e-3`, and no
`abs(phi) > 0.99` boundary diagnostic. The runner now applies the specified criterion correctly: for each identifiable
independent variance it takes the median relative error over the three fixed
seeds. Only replicated `phi = 0.6`, trait 2 fails, at `0.3558` versus `0.35`.
This is unresolved, and no recovery, precision, or interval claim is licensed.

A full local package check was also attempted. Its temporal guard and runner
test failures were repaired. It still has unrelated working-tree failures from
the concurrent Julia lane (`gllvm_julia_fit` Rd drift and an unavailable `BIC`
namespace object), so it is not evidence of a green full package check.

The final `devtools::check(args = "--no-manual")` run on this temporal revision
took 23m47s and again reported no temporal failure. It remained non-green for
the same external state, plus the existing undocumented `digits` argument in
`anova.gllvmTMB_multi.Rd`. Those files are outside this lane and were not
modified.

## Rejected retained-random-effect experiment

The implementation briefly retained replicated `s_B` values as TMB random
effects to test the literal random-membership reading of the implementation
plan. The independently constructed dense covariance oracle then found the
Laplace objective near zero where the same fixed parameters had dense NLL
about 38. The experiment was removed rather than accepted. The implemented
replicated likelihood is the exact normalized Gaussian marginal block
`Psi 11' + sigma_epsilon^2 I`; its score process is the only temporal random
effect and it passes the dense oracle at all four required persistence values.

## Recovery uncertainty diagnostic

`recovery-uncertainty-summary.csv` retains a diagnostic for the one remaining
G4 variance-threshold miss. In the fixed replicated fixture, its affected
occasion-variance estimate differs from its generating value by about 0.86
local delta-method standard errors. This diagnoses only that retained fit; it
is neither interval-coverage evidence nor a general recovery claim. The
predeclared `0.35` median relative-error threshold is unchanged, so G4 remains
red.

## Optimizer diagnosis for the recovery misses

A deterministic two-cell investigation used three-start BFGS and three-start
`nlminb` without any truth-informed starts. Both optimizers reached the same
objective to the reported precision as each other. The relevant replicated
`phi = 0.6` variance error remains `0.35578`; the earlier `phi = -0.4` entry is
only a per-seed maximum diagnostic and passes the actual per-variance median
criterion. The BFGS multi-start gradients were below `1e-3`; the `nlminb`
diagnostic gradients were slightly above it and cannot replace the retained
gate evidence. The remaining failure is therefore not explained by a practical
alternative-optimizer basin. Full diagnostic rows are retained in
`recovery-optimizer-diagnosis.csv`; no recovery fixture, seed, threshold, or
acceptance result changed.

## Rejected 24-series recovery substitution

A diagnostic-only 24-series replay retained the same DGP, workflows, phi
values, and fixed seeds. It does not replace G4. Five of its six cells met the
original numeric criteria, but unreplicated `phi = 0` failed the outer-gradient
criterion. The result therefore does not support a post-hoc substitution of a
larger fixture for the approved 12-series gate. Its complete retained rows and
cell summaries are `recovery-exploration-24-results.csv` and
`recovery-exploration-24-summary.csv`.

The 24-series unreplicated `phi = 0` diagnostic meets the gradient criterion
under three-start BFGS. That would require changing both the series count and
optimizer-restart policy after inspecting results, so it is not a defensible
replacement acceptance fixture. The retained rows are
`recovery-exploration-24-unrep-phi0-multistart.csv`.


## Approved G4 acceptance revision

The maintainer approved the fixture-local per-variance median-error ceiling of `0.36`, recorded in `ACCEPTANCE-REVISION.md`. The original `0.35` miss remains retained. This closes a local engineering gate only and does not license a general recovery, precision, calibration, or coverage claim.
