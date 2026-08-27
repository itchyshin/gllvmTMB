# After Task: Internal fixed-rho phylogenetic response-column coefficient engine

**Branch:** `codex/phylo-coef-fixed-rho-plan`
**Date:** 2026-08-27
**Roles engaged:** Ada, Gauss, Noether, Curie, Fisher, Rose, Grace

## 1. Goal

Admit a private Gaussian fixed-rho `phylo_coef()` engine for tree, dense
covariance, and sparse precision sources. Prove exact `rho = 1` no-intercept
identity to released `phylo_slope()` while keeping every public `*_slope()`
helper current, warning-free, and non-deprecated.

## 2. Implemented

- Added a private fixed-rho phylogenetic rewrite that leaves the public formula
  fence intact.
- Added covariance-scale source resolution for labelled trees, dense
  covariances, and sparse precisions.
- Preserved exact released `phylo_slope()` routing at `rho = 1` for
  no-intercept bases and reused the matrix-normal coefficient engine elsewhere.
- Added independent algebra, malformed-input, exact-identity, finite-gradient,
  and deterministic recovery gates.

## 3. Mathematical Contract

For response column `t` and sampled row `i`,

```text
eta_it,coef = z_i^T b_t,
B = [b_1^T; ...; b_T^T],
B ~ MN(0, K_rho, Sigma_coef),
K_rho = rho K + (1 - rho) diag(K),  0 <= rho <= 1.
```

The engine mixes the labelled phylogenetic source on the covariance scale,
then computes `Q_rho = K_rho^-1` and `log|K_rho|`. It does not interpolate
precisions or determinants. This is response-column coefficient covariance,
not observation residual covariance, unit-tier phylogenetic covariance, or a
new TMB likelihood. `rho` is fixed R-side data in this slice; no estimated-rho
parameter is added.

The no-intercept dense-VCV endpoint is a declared compatibility exception:
exact `rho = 1` dispatch inherits released `phylo_slope()` conditioning
`K0 = K + 1e-8 I`. Interior rho and intercept-bearing `rho = 1` use raw
`K_rho` without a ridge. This slice does not claim endpoint continuity.

## 4. Files Touched

- Engine: `R/column-coef-foundation.R`, `R/fit-multi.R`.
- Tests and deterministic verifiers:
  `tests/testthat/test-column-coef-phylo-fixed-rho.R` and
  `dev/phylo-coef-fixed-rho/`.
- Contracts: `docs/design/131-response-column-coefficient-foundation.md` and
  validation row FG-20 in `docs/design/35-validation-debt-register.md`.
- Closeout: this report, the paired plan-actual and handover records,
  `.unlazy/phylo-coef-fixed-rho/GATES.md`, and
  `docs/dev-log/check-log.md`.
- No C++, `NAMESPACE`, generated Rd, `_pkgdown.yml`, README, NEWS, ROADMAP,
  known-limitations page, vignette, or article source changed.

## 3a. Decisions and Rejected Alternatives

**Decision:** hard-dispatch the no-intercept `rho = 1` spelling to released
`phylo_slope()`, including its dense-VCV `K + 1e-8 I` conditioning.
**Rationale:** exact lifecycle and fitted-object identity with the current
warning-free helper is stronger than an approximately equivalent duplicate.
**Rejected alternative:** silently use raw `K` at the dense endpoint, which
would break exact slope identity; changing the released slope ridge is outside
this slice. **Confidence:** high for the internal compatibility contract,
conditional on resolving or disclosing the endpoint seam before public use.

**Decision:** mix covariance matrices before inversion. **Rationale:** this is
the declared matrix-normal model. **Rejected alternatives:** precision or
log-determinant interpolation, and adding a ridge to new interior mixtures.
**Confidence:** high, supported by independent covariance/precision/determinant
oracles and malformed-source tests.

## 5. Checks Run

```sh
Rscript --vanilla -e 'devtools::test(filter = "column-coef-phylo-fixed-rho", stop_on_failure = TRUE); cat("PHYLO_COEF_FIXED_RHO_FOCUSED_OK\n")'
# PASS after exact-review repairs: 99 expectations, zero failures or warnings.

Rscript --vanilla dev/phylo-coef-fixed-rho/verify-rho-one-identity.R
# PASS: PHYLO_COEF_RHO_ONE_IDENTITY_OK.

Rscript --vanilla dev/phylo-coef-fixed-rho/verify-fixed-rho-recovery.R
# PASS: PHYLO_COEF_FIXED_RHO_RECOVERY_OK.

Rscript --vanilla dev/phylo-coef-fixed-rho/verify-internal-boundary.R
# PASS: PHYLO_COEF_INTERNAL_BOUNDARY_OK.

Rscript --vanilla -e 'devtools::test(filter = "column-coef-engine-iid|fixed-column-slope-family|phylo-column-slope-indep|phylo-slope|column-coef-phylo-fixed-rho", stop_on_failure = TRUE); cat("PHYLO_COEF_REGRESSION_OK\n")'
# PASS after exact-review repairs: 306 expectations, zero failures; two declared heavy skips and 17
# pre-existing unused-cluster warnings in neighbouring fixtures. Clean
# representative phylo_slope() calls remained warning-free.
```

Full package, pkgdown, exact-candidate review, Unlazy, CI, merge, and exact-main
receipts are appended before terminal closure.

```sh
Rscript --vanilla -e 'devtools::test(stop_on_failure = TRUE); pkgdown::check_pkgdown(); cat("PHYLO_COEF_LOCAL_PACKAGE_OK\n")'
# PASS on fresh frozen bytes: 17,811 passes, 52 existing warnings, 879 declared
# skips, zero failures; pkgdown reported "No problems found".

Rscript --vanilla -e 'Sys.setenv(NOT_CRAN="true"); devtools::check(args = "--no-manual", quiet = TRUE); cat("PHYLO_COEF_R_CMD_CHECK_OK\n")'
# PASS in 19m43.9s: 0 errors, 0 warnings, 3 unchanged notes (clock
# verification, pre-existing logLik namespace note, xcrun_db detritus).
```

## 6. Tests of the Tests

The first valid fixed-rho tests failed before implementation because both
private engine helpers were absent. Independent covariance oracles cover
`rho = 0`, `0.37`, and `0.999` with non-unit diagonals and reject missing
labels, asymmetry, and non-positive-definite sources. Feature-combination
tests cover trees, permuted dense covariance, sparse precision, both bars,
intercept-plus-slope bases, and exact optimized-object identity to
`phylo_slope()` at `rho = 1`. The deterministic whitened recovery fixture
separates the covariance contract from Monte Carlo luck.

## 8. Consistency Audit

```sh
rg -n "column_coef|phylo_coef|animal_coef|kernel_coef|spatial_coef" README.md NEWS.md vignettes _pkgdown.yml NAMESPACE man
# Verdict: no new public coefficient-helper claim; the existing tree article
# still correctly says column_coef() is unavailable.

rg -n -i "deprecat.*(_slope|slope\\()|(_slope|slope\\().*deprecat" R README.md NEWS.md vignettes man docs/design
# Verdict: no runtime or reader-facing slope deprecation or warning was added;
# historical future proposals remain historical.

rg -n "internal.*fixed-rho|fixed-rho.*internal|estimated.*rho|public.*phylo_coef|phylo_coef.*public" docs/design/131-response-column-coefficient-foundation.md docs/design/35-validation-debt-register.md docs/dev-log
# Verdict: current records consistently separate internal fixed-rho evidence
# from the deferred estimated-rho and public API slices.

rg -n "column_coef|response-column coefficient" ROADMAP.md NEWS.md docs/dev-log/known-limitations.md _pkgdown.yml README.md
# Verdict: no public status surface advertises this internal engine.
```

### Roadmap Tick

N/A. This is an internal engine slice and no public roadmap row changed.

## 7a. Issue Ledger

Issue #1212, “design: estimate structured-source strength across the covariance
grid,” was inspected. This slice proves one fixed-rho response-column
coefficient block but does not implement estimated rho or change the 5 x 3
grid, so the issue stays open. Issues #943 and #945 appeared in the targeted
search but concern unrelated integrated-GLLVM simulation and per-row family
routing. No issue was commented, closed, or created.

## 9. What Did Not Go Smoothly

The first Unlazy approval used the wrong working-directory arguments and ran
checks beside the ledger; the correctly rooted repeat established the intended
RED state. The first sandboxed lease command printed a grant although it could
not persist the registry; the escalated repeat was verified in the live lease
list. Both incidents are tooling evidence, not model failures. The source
validator was then tightened so an indefinite supplied `K` fails even when a
small rho could make `K_rho` positive definite.

Rose's first exact-tree review caught that the closeout prose omitted the
released dense-VCV endpoint ridge even though implementation and identity tests
intentionally inherited it. Rose and Gauss/Noether also found that the endpoint
rewrite bypassed typed dense-source validation and augmented sparse precisions
were not validated in full. The contract, endpoint oracle, rewrite guard, and
sparse finite/symmetry/SPD tests were strengthened without changing
`phylo_slope()`.

The first broad test process was already running when review changed the
private rewrite signature. It later loaded the edited test file against its
stale in-memory package and reported unused arguments. The mixed-byte run was
interrupted, preserved, and excluded; the exact-candidate full gate starts in
a fresh R process.

The later Unlazy duplicate of the already-passed full package/pkgdown command
was also stopped when it crossed its declared 30-minute ceiling without a
terminal marker. It emitted no failure but is excluded. G6 now verifies the
fresh direct on-disk package/pkgdown/R-CMD-check receipts plus whitespace,
rather than silently extending a second fit-heavy replay.

The revised receipt verifier passed under Unlazy. The ledger is 8/9 met before
push; only the protected CI/merge/exact-main G9 remains open.

## 11. Team Learning

**Ada:** Waiting for the LV release and rebasing once preserved both lanes and
kept this slice narrow.

**Gauss:** The numerical review must distinguish covariance mixing from
precision mixing and retain the exact released endpoint route.

**Noether:** Exact objective, gradient, map, report, and fitted-value identity
at `rho = 1` is stronger than tolerance-based parameter recovery.

**Curie:** Deterministic whitening and boundary/malformed-source tests make the
recovery and validation gates reproducible.

**Fisher:** The evidence earns fixed-rho Gaussian point fitting only; it says
nothing about estimating rho or interval calibration.

**Rose:** The internal/public boundary is encoded in source, tests, Design 131,
FG-20, the check log, and the handover rather than left as a chat promise.
Rose's amended-tree terminal review passed after independently replaying the
99-expectation focused gate, 306-expectation regression gate, standalone
verifiers, closeout contract, and whitespace check.

**Grace:** Source and portability review passed after typed sparse-source
validation was added. The fresh local full package/pkgdown gate and
`R CMD check` passed; the exact reviewed head still requires routine and manual
three-OS CI, normal protected merge, and exact-main verification.

### Design and documentation updates

Design 131 now describes the internal fixed-rho phylogenetic engine and its
covariance-scale mixture. FG-20 remains `partial` and lists the new tests while
keeping estimated rho, public helpers, other structured sources, intervals,
and article teaching unclaimed. Prose review removed ambiguous claims that all
structured engines remained fenced. No example file changed; the convention-
change cascade is therefore not triggered.

## 10. Known Residuals

- Complete exact-candidate reviews and local package/pkgdown gates.
- Push once with CI pacing, obtain routine and manual Ubuntu/macOS/Windows
  evidence, merge normally, and verify exact main.
- Start a fresh Ultra Plan for estimated rho plus the public long/wide
  `column_coef()` / `phylo_coef()` API and article cascade.
- Keep `*_slope()` warning-free and non-deprecated. Animal, kernel, and spatial
  coefficient helpers remain deferred by maintainer choice.
- Resolve or explicitly retain the dense-VCV `K + 1e-8 I` endpoint seam before
  public admission; this internal slice makes no continuity claim.

## 12. Cross-Product Coverage

This slice covers Gaussian point estimation for one response-column
coefficient block with a fixed numeric rho and a tree, dense covariance, or
sparse precision source. It covers both bars, no-intercept endpoint identity,
intercept-plus-slope interior fits, label permutation, source validation, and
the existing IID/slope neighbourhood.

It does NOT cover estimated rho, non-Gaussian or mixed families, multiple
simultaneous response-column coefficient sources, intervals, REML-specific
behaviour, missing responses, extractor/public API surfaces, article examples,
or animal/kernel/spatial providers. It does not transfer fixed-rho evidence to
the existing 5 x 3 trait-covariance grid.
