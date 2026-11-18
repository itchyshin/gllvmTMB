# After Task: G2c package-native replicated-PA smoke admission

**Branch**: `codex/isdm-g2c-replicated-pa`
**Date**: `2026-08-10`
**Roles (engaged)**: Ada, Fisher, Rose

## 1. Goal

Prepare and admit-or-hold a private G2c three-linked-PA-event recovery campaign
for the package-native GBIF plus PA route, without changing its estimand,
thresholds, public interface, or deferred scopes.

## 2. Implemented

Added a private G2c protocol, decision note, three-visit paired fixture runner,
dormant Totoro launcher, and no-fit event-contract test.  The runner preserves
GBIF and visit-1 rows while adding exactly two conditionally independent
Bernoulli-cloglog PA events at the same `(cell_id, trait)` state.  It records
the native unit-tier diagonal log-SD (`theta_diag_B`) five-point ledgers.

The one local smoke completed as `SMOKE_HOLD`, so the campaign was not admitted
to Totoro.  The G2c final disposition is a **smoke-admission HOLD**, not a
20-fixture recovery verdict.

### Mathematical Contract

For shared cell/species predictor \(\eta_{cs}\), the three survey visits are
\(D_{csv}\sim\mathrm{Bernoulli}\{1-\exp[-a_c^S\exp(\eta_{cs})]\}\),
conditionally independent only through their fresh Bernoulli uniforms.  GBIF
remains \(Y^G_{cs}\sim\mathrm{Poisson}\{a_c^G\exp(\eta_{cs}+\delta_s+
b_c\gamma_s)\}\).  The unit covariance remains
\(\Lambda\Lambda^\top+\Psi\) with rank one and free diagonal \(\Psi\).

No public R API, likelihood, formula grammar, family, NAMESPACE, generated Rd,
vignette, or pkgdown navigation change occurred.

## 4. Files Touched

- Private protocol/decisions/comparator readiness:
  `dev/isdm-package-recovery/2026-08-10-g2c-*.md`.
- Private runner/launcher: `run-g2c-replicated-pa-recovery.R` and
  `run-g2c-replicated-pa-totoro.sh`.
- Private test: `tests/testthat/test-g2c-replicated-pa-harness.R`.
- Durable evidence: the two recovery checkpoints, this report, the plan-vs-
  actual record, and `docs/dev-log/check-log.md`.
- Examples touched: none.  No convention change occurred, so no roxygen/Rd or
  article cascade was required.

## 3a. Decisions and Rejected Alternatives

**Decision:** stop at `G2C_SMOKE_ADMISSION_HOLD` and do not request S5.
**Rationale:** the predeclared two-sided profile gate failed, even though the
three-visit fit had a finite gradient.  **Rejected:** threshold relaxation,
retrying the same root, treating the smoke as a recovery verdict, or launching
Totoro.  **Confidence:** high for this fixture-specific admission decision.

## 5. Checks Run

```sh
Rscript --vanilla dev/isdm-package-recovery/run-g2c-replicated-pa-recovery.R \
  --mode=validate --output=... --pkg="$PWD"
# PASS: no-fit event contract.

Rscript --vanilla -e 'devtools::test(filter = "g2c-replicated-pa-harness")'
# PASS: 3 assertions.

Rscript --vanilla dev/isdm-package-recovery/run-g2c-replicated-pa-recovery.R \
  --mode=smoke --scenario=ordinary --replicate=1 \
  --output=dev/isdm-package-recovery/results/g2c-smoke-20260810-retry1 \
  --pkg="$PWD" --campaign-sha=2041684f044303c0fe26d5dde2b83f38d882f05d
# SMOKE_HOLD.

shasum -a 256 <each retained smoke artifact>
# Recorded in 2026-08-10-164500-codex-g2c-smoke-provenance.md.
```

## 6. Tests of the Tests

The no-fit test is a feature-combination test: it exercises three repeated
survey events with mixed GBIF Poisson and survey cloglog family routing, common
cell predictors, and the structural-zero GBIF-bias gate.  The fixture validator
also rejects duplicate event IDs and a disconnected attack with source-support
overlap.  It does not prove recovery; the smoke was the first optimisation
check and failed closed.

### Mechanical Contract and Scope Audit

```sh
rg -n "G2C_REPLICATED_PA|G2c|replicated-PA|three-visit" README.md ROADMAP.md NEWS.md docs vignettes R tests
rg -n "GBIF|Artportalen|empirical|absolute intensity|scampr|spOccupancy" README.md ROADMAP.md NEWS.md docs/dev-log/known-limitations.md docs/design dev/isdm-package-recovery
rg -n "gllvmTMB\\(" R vignettes README.md NEWS.md docs/design
```

The first search found only private G2c records and its test; no reader-facing
surface advertises it.  The second confirms explicit deferred boundaries.  The
third is inventory only: G2c adds no public `gllvmTMB()` syntax.

## 7. Roadmap Tick

**Roadmap tick:** N/A — this is private developer evidence only.

## 7a. Issue Ledger

Inspected Issue #953 and unrelated PR #952.  No comment, update, closure, or
new issue: the approved G2c plan explicitly deferred public work.

## 8. Consistency Audit

The exact searches in section 6 found no public G2c capability claim and only
intentional deferred-scope references.  No reader-facing or generated surface
needed rebuilding.

## 9. What Did Not Go Smoothly

The terminal wrapper initially returned before the first local process’s final
output was observed, so a conservative fresh retry root was used.  Both roots
completed and are now reconciled by a committed SHA-256 ledger.  The smoke also
showed the intended scientific gate failure: diagonal profiles were one-sided
or flat despite finite gradients.

## 10. Known Residuals

The root receipt is now provenance-reconciled through a committed external
ledger, but its original ignored files were not retroactively modified.  The
current runner should be hardened before any fresh design to retain named
profile verdicts, explicitly test finite objective, and validate the exact
five fixed offsets.  This phase did not run a campaign, independent campaign
summary, full D-43 panel, count/comparator/spatial recovery, or empirical fit.

## 11. Team Learning

**Fisher** approved the substantive HOLD, while identifying two future-harness
repairs: retain an explicit per-coordinate profile verdict and check finite
objective/complete fixed-offset grids before eligibility.

**Rose** approved the scope fence but required the committed two-root digest
ledger and this closeout.  A full D-43 panel was not fired because it was
conditional on S5, which the smoke did not admit.

## 12. Cross-Product Coverage

The frozen G2c protocol remains unchanged at its manifested hash; outcome and
provenance live in separate companion records to avoid retroactively changing
a protocol after execution.  README, NEWS, ROADMAP, known limitations,
validation-debt register, `_pkgdown.yml`, vignettes, man pages, and public API
were inspected and intentionally unchanged.  No capability was advertised, so
no validation-debt row applies.  This phase covers only a private synthetic
three-event fixture, its package-native row routing, and its local admission
receipt; it does NOT cover count recovery, any comparator execution, spatial
controls or two-field separation, source admission, empirical fitting,
detection calibration, absolute intensity, public syntax, or article readiness.

### Next Actions

Do not launch G2c S5.  A new, separately approved G2d design may increase the
number of species while keeping the same free-\(\Psi\) relative-intensity
estimand.  It must first repair the listed future-harness controls, freeze a
new protocol and seeds, and use a fresh result root.
