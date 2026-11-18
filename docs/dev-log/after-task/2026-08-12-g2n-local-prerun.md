# After Task: G2n one fresh local pre-run

## 1. Goal

Run one approved fresh private six-species, nonspatial iJSDM diagnostic fit
from the G2n implementation, retaining the frozen G2i/G2m fixture, source
gate, profiles, metrics, raw/candidate provenance, and a PASS/HOLD decision.

## 2. Implemented

A dedicated private G2n wrapper delegates exactly one frozen G2i fit and
profiles to a fresh child root, then makes the prospective decision from
`fit$isdm_numerical_admission`.  It recognises `NOT_REQUIRED` without requiring
an attempted polish, preserves all candidate attempts, and writes a recursive
manifest/final closure.  The one actual result is a valid
`G2N_LOCAL_PRERUN_HOLD`, not an evidence pass.

**Mathematical contract:** no likelihood, DGP, parameter map, source gate,
raw-gradient threshold, seed grid, profile offsets, recovery metric, grammar,
or public interface changed.  The new wrapper only routes the pre-existing
G2i fit through the frozen G2n decision table.

## 3a. Decisions and Rejected Alternatives

**Decision:** use a new G2n wrapper around the retained G2i runner.
**Rationale:** the old runner required an accepted polish and could not
correctly admit a G2n raw-pass `NOT_REQUIRED` state.
**Rejected alternative:** change the historical G2i runner and risk altering
the interpretation of preserved G2i evidence.
**Confidence:** high.

**Decision:** stop at Case C / `NO_CANDIDATE`.
**Rationale:** the unique maximum is `b_fix` at `0.002726537` without a named
boundary; G2m forbids creating an optimizer here.
**Rejected alternative:** another retry, changed controls, or Newton update.
**Confidence:** high.

## 4. Files Touched

- `dev/isdm-package-recovery/run-g2n-local-prerun.R`: private one-run wrapper.
- `dev/isdm-package-recovery/finalize-g2n-local-prerun-provenance.R`: no-fit
  closure finalizer for the completed root.
- `tests/testthat/test-g2n-local-prerun.R`: no-fit validation.
- `dev/isdm-package-recovery/2026-08-12-g2n-local-prerun-decision.md`: result.
- `docs/dev-log/plan-actual/2026-08-12-g2n-local-prerun-reconciliation.md`:
  plan-versus-actual receipt.
- This report and `docs/dev-log/check-log.md`.

Unchanged: `README.md`, `NEWS.md`, `ROADMAP.md`, `_pkgdown.yml`, `vignettes/`,
`man/`, `src/`, public API, and Issue #953.  The private results root is
ignored and retained locally, not committed.

## 5. Checks Run

- `devtools::test(filter = "g2n-local-prerun")` — PASS; wrapper validation
  performed no fit.
- `run-g2n-local-prerun.R --mode=validate` — PASS; frozen fixture/contracts.
- One `--mode=prerun` execution, SHA `7a819639`, seed `86122` — completed in
  444.587 seconds with a retained G2N HOLD root.
- No-fit post-run provenance finalizer — PASS: recomputed source-gate evidence
  and bound map/data/random/bounds/scale/control, ordered parameters, gradient,
  covariance diagnostics, and DLL/TMB/R details.
- Manifest self-consistency repair — PASS: manifest V3 excludes its own
  mutable bytes and final closure; the higher-level closure still binds it.
- Recursive final-provenance closure V3 hash check — PASS (20 files).
- `git diff --check` — PASS.

## 6. Tests of the Tests

The no-fit test is a boundary test: it proves the validation path validates
frozen inputs but creates no output root.  The result-root closure check is a
feature-combination test: nested retained G2i artifacts plus G2n source receipt
plus recursive hashes.  The pre-run itself is the only authorized fit.

## 7a. Issue Ledger

No issue was opened, edited, or closed. Issue #953 was explicitly out of
scope. No campaign was requested or launched.

## 8. Consistency Audit

- `rg -n "G2K_CALIBRATION_HOLD|G2C_SMOKE_ADMISSION_HOLD|G2N_LOCAL_PRERUN" dev/isdm-package-recovery docs/dev-log` — historical G2k/G2c HOLDs remain present; G2n is private.
- `rg -n "integrated_jsdm|iJSDM|GBIF Poisson|repeated survey" README.md ROADMAP.md NEWS.md docs/design vignettes _pkgdown.yml` — no public iJSDM capability claim.
- `rg -n "gllvmTMB\\(" R vignettes README.md NEWS.md docs/design` — no G2n public syntax or article workflow exists.

## 9. What Did Not Go Smoothly

The first wrapper invocation stopped before fitting because it populated the
root before the retained G2i fresh-root guard.  The wrapper was corrected to
delegate into a fresh child root, validated again, committed, and then one
actual fit was run.  This was a wrapper sequencing defect, not a model failure.
Independent closure review also found a self-referential manifest hash; V3
corrected it without running another fit.

## 10. Known Residuals

The result does not meet numerical or full recovery admission.  It has Case C
`NO_CANDIDATE` and a diagonal-Psi variance miss.  Its valid profiles and four
passing recovery metrics do not override either failure.  No campaign is
eligible.

## 11. Team Learning

**Ada:** immutable execution roots need a nested delegate whenever a retained
runner has its own fresh-root guard.

**Gauss/Noether:** G2n correctly prevents a `b_fix` residual from being relabelled
as a named-boundary numerical repair.

**Curie:** a local pre-run must retain all failures, not only the numerical
summaries that passed.

**Rose:** the result is a HOLD with an auditable provenance closure, not a
partial recovery claim or reason to promote the private articles.

## 12. Cross-Product Coverage

**Covered:** one frozen six-species nonspatial GBIF-plus-replicated-PA local
fit, source-gate validation, three restarts, 30 profile optimizations, G2n
admission classification, five frozen recovery metrics, and retained hashes.

**This does NOT cover:** a recovery campaign, alternate fixtures/seeds,
spatial fields, repeated-visit detection extension, empirical data, count
outcomes, additional sources, generic zero inflation, a Case-C estimator,
public API/docs/pkgdown, Tier-1 article results, package comparison, or a
Paper 2 scientific claim.
