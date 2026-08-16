# After Task: G2d six-species private recovery harness and local-smoke HOLD

**Branch**: `codex/isdm-g2d-six-species`  
**Date**: `2026-08-10`  
**Roles (engaged)**: Ada, Gauss, Noether, Curie, Rose

## 1. Goal

Implement the approved private G2d six-species known-truth recovery harness,
validate it without fitting, and make exactly one fresh ordinary local smoke.
G2c remains `G2C_SMOKE_ADMISSION_HOLD`; Totoro and every public or widened
lane were excluded.

## 2. Implemented

The private runner freezes the six-species truth, `86101:86120` ordinary
seeds, three paired PA-cloglog visits, GBIF-only bias, rank-one shared
covariance, free diagonal Psi, six named log-SD profiles, and support attacks.
The no-fit gate passed. The one local smoke reached post-fit serialisation but
ended `G2D_SMOKE_HOLD` before retaining numerical output because result-parent
creation occurred too late. The ordering defect is repaired but not rerun.

Mathematical contract: no public R API, likelihood, formula grammar, family,
NAMESPACE, generated Rd, vignette, or pkgdown navigation changed. The private
DGP is `eta_cs = alpha_s + x_c beta_s + z_c lambda_s + e_cs`, with
`e_cs ~ N(0, psi_s^2)`, GBIF Poisson quadrature, and three PA cloglog events.
`theta_diag_B` is log-SD, so its diagnostic diagonal variance is `exp(2 theta)`.

## 4. Files Touched

- Private harness: `dev/isdm-package-recovery/run-g2d-six-species-recovery.R`,
  `dev/isdm-package-recovery/run-g2d-six-species-totoro.sh`, protocol, and
  decision memo under `dev/isdm-package-recovery/`.
- Private test: `tests/testthat/test-g2d-six-species-harness.R`.
- Closure: the ignored `g2d-smoke-20260810-write-hold` receipt, this report,
  the recovery checkpoint, and `docs/dev-log/check-log.md`.
- Untouched: `README.md`, `NEWS.md`, `ROADMAP.md`, public R/src, vignettes,
  generated Rd, pkgdown configuration, and Issue #953.

## 3a. Decisions and Rejected Alternatives

- **Decision**: retain the failed smoke as a named HOLD and do not rerun it.
  **Rationale**: the approved goal permits one fresh local smoke only; absent
  serialised output cannot support a numerical claim. **Rejected alternative**:
  a retry after repair would be a second fit outside authority. **Confidence**: high.
- **Decision**: create the fresh root before fitting. **Rationale**: receipt
  provenance must be writable before the expensive step. **Rejected
  alternative**: leave the known harness defect. **Confidence**: high.

## 5. Checks Run

```sh
Rscript --vanilla dev/isdm-package-recovery/run-g2d-six-species-recovery.R --mode=validate --output=/private/tmp/gllvmtmb-isdm-g2d-six-species/dev/isdm-package-recovery/results/g2d-validate-probe --pkg=/private/tmp/gllvmtmb-isdm-g2d-six-species
# PASS: G2D fixture/support/profile contract validation PASS (no fit)

Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-g2d-six-species-harness.R", reporter = "summary")'
# PASS: 10 expectations.

Rscript --vanilla dev/isdm-package-recovery/run-g2d-six-species-recovery.R --mode=smoke --scenario=ordinary --replicate=1 --output=/private/tmp/gllvmtmb-isdm-g2d-six-species/dev/isdm-package-recovery/results/g2d-smoke-20260810 --pkg=/private/tmp/gllvmtmb-isdm-g2d-six-species --campaign-sha=ffe52ab1974ac26e3551f3b10f59fd37a672f24c
# HOLD: post-fit write-path error; no output serialised; no rerun.
```

The initial no-fit probe failed on row-name-sensitive paired identity and then
on weak-overlap correlation; both failures were corrected before the successful
gate rerun. No package test suite, check, document, pkgdown, panel, or Totoro
command was run.

## 6. Tests of the Tests

The no-fit test is a boundary/provenance test: it invokes validation only and
would catch fixture-contract drift. The two manual no-fit failures demonstrate
that paired-identity and weak-overlap assertions exercise failure paths.

## 8. Consistency Audit

```sh
rg -n 'G2D|G2c|isdm' README.md ROADMAP.md NEWS.md docs/dev-log/known-limitations.md docs/design
```

Verdict: no public-surface G2d claim exists; G2c is preserved solely as the
protected HOLD boundary. Standard public-prose scans and pkgdown checks were
not applicable because no public prose, syntax, or docs changed.

## 7. Roadmap Tick

N/A — this private developer-only HOLD changes no roadmap row.

## 7a. Issue Ledger

Issue #953 was deliberately not inspected or updated because the approved
scope forbade it. `gh pr list --state open` could not reach `api.github.com`;
local `git log --all --oneline --since='6 hours ago'` showed only the G2d
handover and archived snapshot. No issue was created.

## 9. What Did Not Go Smoothly

The original runner checked an absent result parent only after its fits. This
prevented all serialisation, so the outcome is a harness/provenance HOLD rather
than an estimator conclusion.

## 11. Team Learning

**Ada** kept the attempt inside one-smoke authority. **Gauss** required six
untied log-SD profiles and finite objectives. **Noether** checked the Psi
variance transform and frozen truth. **Curie** required direct support and
pairing assertions. **Rose** required an honest retained HOLD rather than
treating missing output as evidence.

## 10. Known Residuals

G2d has no retained numerical smoke evidence, recovery panel, or Totoro
admission. A retry requires explicit new approval, a new fresh root, and a
pre-run check that its receipt path is writable before any fit.

## 12. Cross-Product Coverage

This arc covers only the private, nonspatial, six-species fixture contract and
one unsuccessful local smoke attempt. It does NOT cover a retained estimator
result, recovery frequency, attack-panel performance, Totoro admission,
absolute intensity, detection, counts, comparators, spatial terms,
source-admission, empirical data, public API, public documentation, or Issue
#953.
