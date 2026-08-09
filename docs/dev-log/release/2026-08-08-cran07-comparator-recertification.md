# CRAN 0.7 candidate-cell comparator recertification

Date: 2026-08-08  
Status: **LOCAL RECERTIFICATION PASS — 6/6 glmmTMB rows and 9/9 Stan points; exact-aa production remained HOLD**  
Purpose: earn the claim-matrix requirement for independent comparators at the
same parameterisation after the authorized warm-`nlminb` repair.

## Decision

Use the strict comparator design: six exact same-parameterisation candidate rows,
two supplemental `gllvm` factor-skeleton rows, and the existing nine-point Stan
fixed-coordinate Gaussian density oracle. This is test-only recertification,
not a new family, covariance mode, integration method, or public capability.

The subsequent exact-aa production study did not earn a broad dependable-core
claim. Its implemented pair gates passed for Gaussian `indep()`, Gaussian
`dep()`, Poisson-log rank-1 latent, and Binomial(10)-logit rank-1 latent, while
Gaussian latent and NB2 latent were characterization-only. Independent
adjudication further limited the four passing rows to narrow tested-regime
point evidence because production eligibility was incomplete, robustness cells
failed, and detector sensitivity was 0.2375. Comparator agreement validates
the matched likelihood and parameterization; it does not rescue failed
recovery, robustness, or diagnostic gates.

The repaired source must be used for every `gllvmTMB` fit. Comparator results
from the pre-repair source remain historical and are not pooled with these
results. A skip (including a nested `testthat` skip condition), nonfinite
objective, nonzero optimizer code, non-positive-definite Hessian, boundary
flag, unassessed boundary diagnostic, or incomplete target is a HOLD rather
than a passing omission.

## Exact six-row candidate matrix

| Candidate cell | Independent fit | Shared data/model | Exact gate |
|---|---|---|---|
| Gaussian `indep()` | `glmmTMB::diag()` | Canonical ordinary `indep()` syntax; Gaussian ML; healthy large fixture | Absolute log-likelihood difference `<= 1e-4`; fixed effects `<= 0.05`; covariance difference `<= 0.10`; residual `sigma_eps` SD difference `<= 0.05` |
| Gaussian `dep()` | `glmmTMB::us()` | Same full unstructured trait covariance and Gaussian residual model | Same gates, including residual-SD comparison; no reference skip |
| Gaussian `latent(unique = TRUE)` | `glmmTMB::rr() + diag()` | Same rank, diagonal Psi, fixed effects, and residual model | Same gates, including residual-SD comparison; each trait's Psi variance difference `<= 0.10`; no reference skip |
| Poisson-log `latent(unique = TRUE)` | `glmmTMB::rr() + diag()` | Same counts, log link, rank, diagonal Psi, and fixed effects | Absolute log-likelihood difference `<= 1e-4`; fixed effects `<= 0.05`; covariance difference `<= 0.10`; each trait's Psi variance difference `<= 0.10` |
| NB2-log `latent(unique = TRUE)` | `glmmTMB::rr() + diag()` with trait-specific `dispformula` | Same counts, NB2 `Var(Y)=mu+mu^2/phi`, rank, diagonal Psi, and fixed effects | Objective/log-likelihood `<= 1e-4`; fixed effects `<= 0.05`; covariance `<= 0.10`; each trait's `phi` relative difference `<= 0.25` |
| Binomial-logit `latent(unique = TRUE)` | `glmmTMB::rr() + diag()` | One frozen integer-success draw; `gllvmTMB` receives successes plus `weights = n_trials`, while `glmmTMB` receives `successes / n_trials` plus the same weights; logit link, rank, diagonal Psi, and fixed effects are identical | Absolute log-likelihood difference `<= 1e-4`; fixed effects `<= 0.05`; covariance difference `<= 0.10`; each trait's Psi variance difference `<= 0.10` |

Use healthy `n = 240` or `n = 300` fixtures for exact certification. Gaussian
latent `n = 60` and NB2 latent `n = 100` remain v4 characterization cells and
cannot be used to make an exact comparator fail merely because their known weak
identification was deliberately retained. Before seeing final results, each
test records trait ordering, rank, formula, link, trial/weight convention,
dispersion scale, fixed-effect names, objective definition, and covariance
extractor.

Every trait-indexed target must carry exactly the frozen trait names. Sigma,
Psi, and NB2 `phi` are reordered by exact name before comparison; missing,
duplicate, or foreign names are a failure. Rank, link, and `n_trials` are read
from the manifest and asserted against the generated formula, family, and TMB
data rather than duplicated as unchecked literals.

## Ordinary tests versus the release runner

The ordinary `testthat` rows may skip on CRAN or when the suggested
`glmmTMB` package is unavailable. Such a skip is normal package-test behaviour
and is never release evidence. The fail-closed recertification run is separate:

```sh
GLLVMTMB_CRAN07_RECERTIFY=true Rscript --vanilla -e \
  'devtools::test(filter = "cran07-core-comparators")'
```

In that mode the six ordinary row tests yield to one release runner. The runner
preallocates all six manifest rows as `HOLD`, treats missing `glmmTMB`, any
unexecuted row, a caught `skip` condition at any nesting depth, any fit/gate
error, any unassessed boundary, and any incomplete or mislabelled result as
`HOLD`. It succeeds only when all six rows were attempted and returned `PASS`.
This command remains unauthorized until the warm-`nlminb` repair and its
focused/heavy gates are green.

If the two packages differ by a provable parameter-independent normalising
constant, change the objective estimand and design version before inspecting
the final comparator verdict; do not relax the tolerance after results.

## Supplemental `gllvm` skeleton checks

`gllvm::gllvm(..., num.lv = 2)` does not fit the release cell's separate
diagonal Psi. Retain it only as independent loadings/ordination evidence using
`latent(..., unique = FALSE)`:

| Family | Frozen gate | Boundary |
|---|---|---|
| Poisson-log | Relative likelihood difference `< 1%`; each Procrustes factor correlation `> 0.95`; shared-covariance relative Frobenius difference `< 0.10` | Factor skeleton only; not evidence for Psi |
| Bernoulli-logit | Relative likelihood difference `< 1%`; each Procrustes factor correlation `> 0.95`; shared-covariance relative Frobenius difference `< 0.25` | Supplemental orientation check; not the Binomial(10)+Psi release cell |

The binary row must report every attempted seed because the historical wider
sweep passed only 10/14 seeds. A deterministic seed-42 pass is not rewritten as
broad cross-seed equivalence.

## Stan fixed-coordinate density regression

Mechanically repair the stale absolute repository roots in the two existing
drivers, without changing either Stan density. Each TMB driver must express
the audited decomposition explicitly as
`latent(..., unique = FALSE) + unique(...)`. Rerun in this order:

```sh
export GLLVMTMB_STAN_ORACLE_RUN_TOKEN="cran07-$(date -u +%Y%m%dT%H%M%SZ)"
Rscript --vanilla dev/stan-oracle/gauss-reconcile.R
Rscript --vanilla dev/stan-oracle/gauss-reconcile-k2.R
```

- K=1 balanced/ragged: six fixed parameter points;
- K=2 packing: three fixed parameter points.

The K=1 driver must fail before writing output unless its mapping audit is
complete, its six point labels are unique, every compared value is finite, and
all six relative discrepancies are `<= 1e-12`. The K=2 driver requires that
six-point output, applies the same mapping/finite/point-count checks to three
packing points, and fails unless the combined point count is exactly nine and
all nine relative discrepancies are `<= 1e-12`. This validates the Gaussian
latent-plus-Psi joint density at fixed coordinates. It does not validate
optimization, Laplace integration, uncertainty, or non-Gaussian families.

The K=1 receipt records the shared run token plus MD5 hashes of both current R
drivers, the unchanged Stan density, and `src/gllvmTMB.cpp`. K=2 checks its
environment token and freshly recomputed hashes against that receipt before it
loads the package source, compiles the Stan model, or fits anything. A missing
provenance field, token mismatch, source change, driver change, or stale K=1
JSON therefore fails before the nine-point result can be assembled. The K=2
receipt also records the exact K=1 JSON hash used in that combined verdict.

## Implementation and evidence rules

1. Reuse the existing Stage-2 Gaussian, `gllvm`, NB2 dispersion, and Stan
   machinery where its parameterisation matches.
2. Replace compatibility syntax in new `gllvmTMB` rows with canonical
   `indep()`, `dep()`, and `latent(..., unique = TRUE)` calls.
3. New exact rows are required for Gaussian `dep()`, Poisson+Psi,
   Binomial(10)+Psi, and NB2+Psi; no comparator skip may count as evidence.
4. Report package/version, optimizer code/message/iterations/evaluations,
   gradient, Hessian, boundary status, call/formula, warm-restart provenance,
   objective, beta, covariance, Psi, Gaussian residual SD, and dispersion where
   applicable. Warm restart is explicitly not applicable to the independent
   `glmmTMB` fit. The `glmmTMB` boundary field is derived, never filled with an
   assumed empty vector: component types must agree between `blockCode` and
   `vcmat_*` metadata, and rr loading scales, diagonal Psi scales, unstructured
   eigenvalues, Gaussian residual SD, and NB2 `phi` are checked. Any component
   whose type or scale cannot be assessed holds the row.
5. Run locally first. Totoro may be used for a multi-seed repetition only after
   the deterministic matrix passes. Never use GitHub Actions for a comparator
   campaign.
6. Store raw fit objects outside the repository. Commit only the frozen design,
   exact attempt manifest, compact tables, hashes, and a cell-specific verdict.

No comparator result may promote broad intervals, raw loading orientation,
VA/AGHQ/EVA, ordinal, mixed-family, slope, or structured-source claims.

## Local execution receipt

Execution date: 2026-08-08 America/Edmonton (2026-08-09 UTC). All commands ran
from `/private/tmp/gllvmtmb-cran-0.7-20260807`; no remote compute was used.

The installed `testthat` API does not accept `info` in `expect_length()`,
`expect_s3_class()`, `expect_setequal()`, or `expect_type()`. The comparator
test now uses compatible expectations while retaining cell-specific labels.
The focused default file completed all six fit rows and skipped only the
explicitly env-gated release test. The fail-closed release invocation skipped
the six ordinary duplicates, executed all six rows through its ledger, and
returned 6 `PASS`, 0 `HOLD`.

```sh
Rscript --vanilla -e \
  'devtools::test(filter = "cran07-core-comparators", stop_on_failure = FALSE, reporter = "summary")'

GLLVMTMB_CRAN07_RECERTIFY=true Rscript --vanilla -e \
  'devtools::test(filter = "cran07-core-comparators", stop_on_failure = FALSE, reporter = "summary")'
```

### Six exact glmmTMB rows

All objectives below are negative marginal Laplace log-likelihoods with
constants. `grad` is the maximum absolute raw gradient. Every optimizer code
was zero, every Hessian was positive definite, and every derived glmmTMB
boundary assessment was complete with no flag or unassessed component.

| Cell | Objective gllvmTMB / glmmTMB | abs d logLik | max abs d beta | max abs d Sigma | max abs d Psi variance | abs d sigma_eps SD | max rel d phi | grad gllvmTMB / glmmTMB | Verdict |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Gaussian indep | 1568.0988537625 / 1568.0988537556 | 6.968e-09 | 1.128e-06 | 6.511e-06 | n/a | 2.427e-06 | n/a | 4.574e-03 / 3.685e-03 | PASS |
| Gaussian dep | 1557.8596616864 / 1557.8596616943 | 7.977e-09 | 1.687e-06 | 5.127e-06 | n/a | 1.333e-06 | n/a | 1.016e-03 / 3.342e-03 | PASS |
| Gaussian latent+Psi | 1635.9635628498 / 1635.9635628230 | 2.680e-08 | 8.939e-06 | 5.085e-06 | 1.036e-05 | 9.519e-07 | n/a | 2.464e-03 / 1.186e-03 | PASS |
| Poisson latent+Psi | 2964.1771388326 / 2964.1771388254 | 7.250e-09 | 5.773e-06 | 6.628e-06 | 1.112e-05 | n/a | n/a | 1.005e-03 / 9.027e-04 | PASS |
| NB2 latent+Psi | 2987.5359717531 / 2987.5359717199 | 3.318e-08 | 1.890e-05 | 4.167e-05 | 6.871e-05 | n/a | 3.483e-05 | 2.469e-03 / 1.719e-03 | PASS |
| Binomial(10) latent+Psi | 7169.4602604753 / 7169.4602604667 | 8.566e-09 | 4.580e-06 | 3.579e-06 | 2.231e-06 | n/a | n/a | 2.027e-03 / 1.242e-03 | PASS |

NB2 `phi` estimates, in frozen trait order, were
`[0.9316294, 1.2730158, 0.9625753]` for gllvmTMB and
`[0.9315970, 1.2729843, 0.9625890]` for glmmTMB. Their traitwise relative
differences were `[3.483e-05, 2.472e-05, 1.423e-05]`. No row used a warm
restart: each initial fit already had optimizer code zero, a positive-definite
Hessian, no boundary flag, and raw gradient below `0.01`.

### Nine-point fixed-coordinate Stan oracle

The successful shared nonsecret token was
`cran07-20260809T015214Z-codex`:

```sh
GLLVMTMB_STAN_ORACLE_RUN_TOKEN=cran07-20260809T015214Z-codex \
  Rscript --vanilla dev/stan-oracle/gauss-reconcile.R
GLLVMTMB_STAN_ORACLE_RUN_TOKEN=cran07-20260809T015214Z-codex \
  Rscript --vanilla dev/stan-oracle/gauss-reconcile-k2.R
```

| Point | abs density difference | relative density difference | Additional gate |
|---|---:|---:|---|
| A/P1 published | 2.274e-13 | 5.293e-16 | R-spec abs 5.684e-14; Jacobian abs 1.954e-14 |
| A/P2 fresh | 1.137e-13 | 2.980e-16 | R-spec abs 1.705e-13; Jacobian abs 9.770e-15 |
| A/P3 negative leading loading | 0 | 0 | R-spec abs 0; Jacobian abs 2.389e-12 |
| A/P4 fresh | 1.137e-13 | 2.152e-16 | R-spec abs 0; Jacobian abs 4.974e-14 |
| B/P1 ragged | 1.705e-13 | 4.636e-16 | R-spec abs 1.137e-13; Jacobian abs 1.954e-14 |
| B/P5 ragged fresh | 4.547e-13 | 4.010e-16 | R-spec abs 0; Jacobian abs 3.997e-14 |
| Q1 K=2 | 2.274e-13 | 1.384e-16 | broken-zero shift -193.034 |
| Q2 K=2 | 1.137e-13 | 1.537e-16 | broken-zero shift 5.648 |
| Q3 K=2 | 1.091e-11 | 8.062e-16 | broken-zero shift -1608.869 |

Combined result: exactly nine finite points, maximum relative discrepancy
`8.062e-16` (`<= 1e-12`) and maximum absolute discrepancy `1.091e-11`.
Balanced and ragged K=1 trait/site/X mappings, active rr+diag flags, parameter
block counts, Gaussian family/identity link, and diagonal-Psi mappings all
passed. K=2 repeated the data/parameter mapping audit and its packed Lambda
matched the lower-triangular convention. The maximum K=1 R-spec absolute
difference was `1.705e-13`; the maximum Jacobian absolute difference was
`2.389e-12` (`<= 1e-10`). All three broken-triangular-zero shifts were
nonzero and exceeded `1e-8` in magnitude.

The output receipts and SHA-256 hashes are:

- `dev/stan-oracle/gauss-reconcile.json`:
  `3334fdb44e85f9e9bcb4033a53f546b243539e2a657b06e0abb2a5f8d6438fb0`;
- `dev/stan-oracle/gauss-reconcile-k2.json`:
  `67a5ac91338d60d99e11e43ea4c96eb0dcdcc5c13c1e0ba379b561d0dad5fcd7`.

Both receipts contain the same token and current MD5 provenance:
K1 driver `909b4b5e683dcd0c409a2d8b3e676c4a`, K2 driver
`cca084bc19d2eec88ea31c91e54ff1a6`, Stan density
`b5b0e2ada7d785a62166e3ec08bca95b`, and TMB source
`64e928d6c914e0478733f56c5368eec8`. K2 additionally records the exact K1
JSON MD5 `b636f20b72c574d0f4012de8c2b93fa8` used for the combined verdict.

An earlier token, `cran07-20260809T015051Z-codex`, was retired after K1 stopped
before density evaluation because a new mapping guard compared equal count
values with different name attributes. Both drivers now compare unnamed
integer counts. That failed attempt contributes no scientific evidence.
