# After Task: G2n prospective numerical-admission gate

## 1. Goal

Implement the private G2m prospective numerical-admission table for the
six-species iJSDM Article 1 path, retain raw/candidate provenance, validate it
without a full iJSDM fit, and return only for a separately approved local
pre-run.

## 2. Implemented

The private iJSDM fit route now stores an admission record.  A raw gradient at
or below `1e-3` is `NOT_REQUIRED`; only the pre-existing single named
`near_zero_sd_B` geometry can use the existing conditional polish; a
non-boundary, unique `b_fix` or `theta_rr_B` residual is
`NO_CANDIDATE`/HOLD.  Raw convergence is retained and required to be zero.
Every invoked Newton candidate is recorded, including failed direct evaluations.

**Mathematical contract:** no likelihood, DGP, parameter map, threshold,
source gate, seed grid, recovery metric, formula grammar, public R API, or
package documentation changed.  G2n only classifies the existing raw optimizer
state and records the existing Case-B candidate mechanism.

## 4. Files Touched

- `R/fit-multi.R`: private classification and provenance only.
- `tests/testthat/test-g2n-numerical-admission.R`: pure decision-table tests.
- `tests/testthat/test-g2n-compiled-cloglog-unit.R`: compiled no-optimizer
  Case-B candidate/provenance unit.
- `dev/isdm-package-recovery/2026-08-12-g2n-numerical-admission-decision.md`:
  private reconciliation decision.
- `docs/dev-log/plan-actual/2026-08-12-g2n-numerical-admission-reconciliation.md`:
  plan-versus-actual receipt.
- `docs/dev-log/check-log.md`: G2n command/decision entry.
- This report.

Unchanged by design: `README.md`, `NEWS.md`, `ROADMAP.md`, `_pkgdown.yml`,
`vignettes/`, `man/`, `src/`, public API, and Issue #953.

## 3a. Decisions and Rejected Alternatives

**Decision:** preserve the existing boundary-only polish and record
non-boundary residuals as `NO_CANDIDATE`.
**Rationale:** G2m establishes no validated same-objective estimator for those
blocks; independent review confirmed no Case-C route was added.
**Rejected alternative:** an additional retry, relaxed threshold, or
covariance-Newton Case-C branch would define a new estimator.
**Confidence:** high.

**Decision:** retain an attempted Newton evaluation even when it produces an
error or nonfinite derivative.
**Rationale:** otherwise a failed attempt disappears behind the selected retry
and violates immutable provenance.
**Rejected alternative:** retain only accepted or finite candidates.
**Confidence:** high.

## 5. Checks Run

- `git diff --check` — PASS.
- `Rscript --vanilla -e 'devtools::test(filter = "g2n-numerical-admission", reporter = "summary")'` — PASS (29 expectations).
- `Rscript --vanilla -e 'devtools::test(filter = "g2n-compiled-cloglog-unit", reporter = "summary")'` — PASS (9 expectations); Apple Clang emitted three upstream Eigen unused-variable warnings.
- `Rscript --vanilla -e 'devtools::test(filter = "warm-nlminb-restart", reporter = "summary")'` — PASS; six pre-existing heavy tests skipped by their explicit `GLLVMTMB_HEAVY_TESTS=1` guard.
- `gh pr list --state open --limit 30` — network unavailable; no GitHub state was changed.

## 6. Tests of the Tests

The raw-convergence Case-D test is a failure-before-fix regression test: the
first independent review showed that a nonzero raw optimizer code could be
silently replaced with `0L`.  Case-B/C/D fixtures are boundary tests.  The
compiled test is a feature-combination test: production TMB cloglog objective
plus the production covariance-Newton helper plus explicit provenance.  The
compiled test has no `nlminb` or fitter call.

## 7a. Issue Ledger

No issue was opened, updated, or closed. Issue #953 was explicitly out of
scope. `gh pr list --state open --limit 30` was attempted for shared-file
coordination but could not reach GitHub; `git log --all --oneline
--since="6 hours ago"` showed no competing G2n implementation commit.

## 8. Consistency Audit

- `rg -n "G2K_CALIBRATION_HOLD|G2C_SMOKE_ADMISSION_HOLD|G2n|G2N" dev/isdm-package-recovery docs/dev-log` — confirmed both historical HOLD states remain explicit and G2n is private.
- `rg -n "integrated_jsdm|iJSDM|GBIF Poisson|repeated survey" README.md ROADMAP.md NEWS.md docs/design vignettes _pkgdown.yml` — no public iJSDM capability claim found.
- `rg -n "gllvmTMB\\(" R vignettes README.md NEWS.md docs/design` — inspected representative existing public calls; no G2n public syntax exists.

## 7. Roadmap Tick

N/A — private numerical admission evidence only; no public roadmap row changed.

## 9. What Did Not Go Smoothly

The sandboxed R process could not create a temporary file, so the no-fit unit
checks were rerun with an approved external temporary directory.  Independent
review caught a real raw-convergence omission and two provenance-test gaps;
all were repaired before closure.

## 11. Team Learning (per AGENTS.md Standing Review Roles)

**Gauss/Noether:** independent numerical review prevented an invalid raw
optimizer exit from being admitted and required all attempted candidates to be
observable.  Future optimizer provenance must retain failed evaluations, not
only selected candidates.

**Curie:** the compiled unit now uses the real candidate helper, avoiding a
synthetic gradient step mislabeled as covariance-Newton.

**Rose:** the private decision record separates implementation admission from
recovery evidence and prevents accidental G2k reclassification or public
promotion.

## 10. Known Residuals

G2n proves only that the prospective classification/provenance implementation
and no-fit/compiled-unit gates pass.  It does not prove fit convergence,
profile behavior, known-truth recovery, Article 1 results, or detection-model
recovery.  `G2K_CALIBRATION_HOLD` and `G2C_SMOKE_ADMISSION_HOLD` remain in
force.  The sole next execution step is a separately approved, one fresh local
G2n pre-run.  Article 2 remains design-only; neither staged article is a
Tier-1 or public pkgdown article.

## 12. Cross-Product Coverage

**Covered:** private `nlminb` iJSDM raw-admission classification, named
boundary-polish provenance, Case-C no-candidate protection, and the compiled
cloglog/covariance-Newton unit.

**This does NOT cover:** a full iJSDM fit, profiles, recovery, spatial fields,
repeated-visit detection implementation, empirical data, source expansion,
count outcomes, generic zero inflation, public API, public articles, package
comparisons, or Article 1/2 scientific claims.
