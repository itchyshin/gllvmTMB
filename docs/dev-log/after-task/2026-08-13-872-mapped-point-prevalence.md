# #872-B mapped-point prevalence — fence retained, no diagnostic admitted

## 1. Goal

Measure the prevalence of the #872 mapped-point objective gap after PR #959,
then decide whether the evidence supports one bounded diagnostic. The intended
reader is a method developer deciding whether to change package behaviour.

## 2. Implemented

Added a private 20-pair receipt for the exact ordinary Gaussian native-ML/
Laplace fixture: rank-1 `latent(0 + trait | site, d = 1)` plus diagonal
`unique(0 + trait | site_species)`, `p = 4`, `q = 1`, response scale
`k = 5000`, ten seeds at each of `n_sites = 150` and `400`. No public R API,
likelihood, formula grammar, family, defaults, NEWS, README, vignette, Rd, or
pkgdown navigation changed.

## 4. Files Touched

- `dev/872-mapped-point-prevalence.R` — private runner with retained failures.
- `docs/dev-log/simulation-artifacts/2026-08-13-872-mapped-point-prevalence-totoro-cells.csv`
  and `2026-08-13-872-mapped-point-prevalence-totoro.rds` — immutable local
  copies of the Totoro receipt. Totoro used source checkout `cd527af1`; its
  diff to merged main `2942b654` is confined to the earlier #959 dev-log and
  artifact receipt, with no package source change.
- This report, the matching plan-versus-actual note, and `check-log.md`.

No status-inventory or reader-facing file changed because no capability was
admitted. No example file was touched.

## 3a. Decisions and Rejected Alternatives

**Decision:** retain #872 as `park/research`; do not admit a warning,
convergence criterion, optimizer-control change, or release claim.

**Rationale:** all 19 executable pairs had a valid mapped lower-objective
point, so the narrow flatness observation is reproducible. But 3/20 attempts
were not strictly healthy (one error; three non-PD scaled fits, including one
nonzero convergence code), and the observed gaps do not yield a calibrated,
estimand-relevant threshold. The study has no single-tier false-alarm control,
does not establish recovery, and the historical issue's 0.197 distance recipe
was not retained.

**Rejected alternative:** a non-default warning based on `convergence`,
`pdHess`, raw gradient, objective gap, or a newly invented parameter distance.
None separates harmless numerical variation from meaningful estimand error in
this evidence.

## 4. Mathematical Contract

For `y* = k y`, the runner maps the fitted outer parameters by
`b_fix* = k b_fix`, `theta_rr_B* = k theta_rr_B`, and
`theta_diag_B* = theta_diag_B + log(k)`,
`theta_diag_W* = theta_diag_W + log(k)`. It then checks the native
Laplace-marginal identity
`F_k(T_k theta) = F_1(theta) + N_obs log(k)` at every retained pair.

The historical #872 issue reported a 0.197 relative parameter distance but did
not record its formula. This runner deliberately labels its two alternatives
`outer_distance_959` and `mapped_back_outer_distance`; neither is called the
historical metric.

## 5. Checks Run

- `OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 GRID_WORKERS=12 Rscript --vanilla dev/872-mapped-point-prevalence.R ...` on Totoro: 20 retained rows,
  19 executable, 16 strictly healthy endpoints; 12 workers, each single
  threaded, below the 150-core cap.
- Exact mapped marginal-identity check: all executable rows passed; maximum
  absolute residual `3.58e-08` (gate `1e-06`).
- `Rscript --vanilla -e '<campaign summaries>'`: 19/19 executable gaps were
  positive; median reached-minus-mapped gap `0.05793` nll overall and
  `0.05935` among the 16 healthy endpoint pairs. Healthy-pair median relative
  error was `0.04586` for unit-tier `Sigma` and `0.000405` for nested
  unit-observation `Sigma`.
- `git diff --check`: passed before commit.

Not run: package tests, `R CMD check`, pkgdown, CI, or a diagnostic/warning
test. This private dev receipt changes no installed package byte.

## 6. Tests of the Tests

This is a private campaign rather than a package test. Its active failure path
is retained rather than discarded: the one failed objective evaluation remains
as an `ERROR` row, and non-PD/non-converged endpoints remain in the CSV. The
mapped identity is independently checked at every executable pair, so an
objective gap cannot be reported when the scale map itself fails.

## 8. Consistency Audit

`rg "#872|two-tier|flatness|park/research" docs/design/35-validation-debt-register.md docs/dev-log/release/2026-08-09-pre-0.7-issue-disposition-ledger.md docs/dev-log/after-task/2026-08-13-872-two-tier-flatness-admission.md`

Verdict: the new decision agrees with MIS-35's single-tier-only #851 scope and
the release ledger's #872 `park/research` disposition. No stale release or
diagnostic-promotion wording was introduced.

## 7. Roadmap Tick

N/A — the package roadmap and release surface do not change.

## 7a. Issue Ledger

Inspected open [#872](https://github.com/itchyshin/gllvmTMB/issues/872): it
remains open and `park/research`. PR #959 was merged at
`2942b6547ecdda7b6993cdcc49a35d6a4db27db2` before this study. No issue comment
or state change was made: this receipt strengthens the internal fence but does
not justify closure or a public claim. #851 was inspected only as the distinct
single-tier starting-value boundary and was not changed.

## 9. What Did Not Go Smoothly

The desktop foreground-command wrapper made local completion opaque, so the
authoritative run used the already authorised Totoro route; a later local
duplicate receipt was deliberately removed to retain one unambiguous campaign
artifact. The first remote launch lacked the package library and failed before
a fit; the successful rerun pinned `R_LIBS=/home/snakagaw/R/library`. These are
execution receipts, not excluded model attempts. The campaign's one model
error and three unhealthy scaled endpoints are retained.

## 11. Team Learning

**Ada:** objective-gap prevalence can be measured cleanly only after mapping
by named TMB blocks and retaining map failures. A repeatable lower objective is
not by itself a usable user diagnostic.

**Gauss:** the marginal objective identity is the mathematical validity gate;
raw parameter-vector distances depend on parameterisation and cannot be
retroactively substituted for the issue's undocumented 0.197 measure.

**Rose:** do not write “all successful” for executable rows. The receipt keeps
the distinction among executable, strictly healthy, and failed attempts.

## 10. Known Residuals

This result covers only ordinary Gaussian native ML/Laplace with rank-1
unit-tier `latent()` and diagonal nested `unique()` at the stated sizes and
scale. It does not cover AGHQ, VA/EVA, REML, non-Gaussian, source-specific,
structured, two-latent-tier, recovery, calibration, intervals, or the #851
single-tier start defect.

No next implementation slice is admitted. A future research arc would first
need a preregistered estimand-level recovery target, a single-tier false-alarm
control, and an explicit parameter-distance definition before proposing any
warning threshold.

## 12. Cross-Product Coverage

Covered only the stated Gaussian native-Laplace nested two-tier fixture across
the two sample sizes and ten seeds. It does NOT cover REML, AGHQ, VA/EVA,
penalised fits, missing data, response aggregation, non-Gaussian families,
source-specific/spatial/kernel tiers, two latent tiers, higher rank, recovery,
intervals, or a user-facing diagnostic threshold.
