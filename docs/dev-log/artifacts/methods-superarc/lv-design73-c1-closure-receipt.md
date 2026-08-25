# Design 73 C1 predictor-informed latent-variable closure receipt

Date: 2026-08-25
Branch: `codex/lv-family-evidence-reconcile`
Audited gllvmTMB HEAD: `93020c790728462c4f27f86a82fc6b9e80d370ec`
Exact lane base / audited `origin/main`: `482c9d372c7dc100f988f41f80d1b4cc3ce8a8e4`
GLLVM.jl treatment: strictly read-only; no checkout, branch, worktree, index,
file, fit, simulation, benchmark, or commit was changed

## Sister-evidence verdict

`LV_COMMON_FAMILY_HOLD__RAW_OR_LINEAGE_GAP`

The GLLVM.jl common-family implementation, corrected generator, and Wald
endpoint are reusable engineering inputs. Its historical recovery and coverage
tables are not independently reusable claim-bearing evidence: seed-level
all-attempt results, failure records, earned MCSEs, and a retained complete
all-family K = 2 driver are absent. No replacement campaign was launched.

This HOLD does not prevent a bounded, native gllvmTMB status reconciliation.
The native evidence retained in this repository closes the named Design 73 C1
cells below. It does not promote the broader predictor-informed latent-variable
surface.

## Model, covariance, and estimand

For unit (i), latent rank (K), and unit-level predictor design (M_i), the
audited native model is

[
z_i=M_i\alpha+e_i,\qquad e_i\sim N(0,I_K),
]

[
\eta_{it}=X_{it}\beta+\lambda_t^\top z_i+q_{it},\qquad
\Sigma_{\rm unit}=\Lambda\Lambda^\top+\Psi,
]

[
B_{lv}=\Lambda\alpha^\top.
]

The unit innovation has identity covariance. Its scale is carried by
(\Lambda). The ordinary native `latent()` route includes its diagonal
(\Psi) companion by default. In the current implementation
(\Psi=\operatorname{diag}(\mathrm{sd}_B^2)), because the diagonal
parameters are log standard deviations.

(B_{lv}) is the scientific cross-fit target. Under an orthogonal rotation
(Q), ((\Lambda Q)(\alpha Q)^\top=\Lambda\alpha^\top). Raw
(\alpha) and raw (\Lambda) depend on the fitted axis convention and are
not cross-fit recovery, coverage, or parity targets. The total-score identity
`total = mean + innovation` is a model check, not a substitute for
(B_{lv}) recovery.

Source pins:

- R design construction and parameter packing:
  `R/fit-multi.R`, `R/lv-predictor.R`.
- Unit innovation, score mean, total score, loadings, diagonal companion, and
  `REPORT` / `ADREPORT(B_lv_unit)`: `src/gllvmTMB.cpp`.
- Trait-scale and score extractors: `R/extractors.R`.
- Rotation-invariance checks:
  `tests/testthat/test-lv-effects-rotation.R`.
- Rank-1 and rank-2 Gaussian recovery:
  `tests/testthat/test-lv-gaussian-recovery.R`.

The internal TMB field `report$Sigma_B` contains only
(\Lambda\Lambda^\top). The documented total covariance is obtained from
`extract_Sigma(..., part = "total")`, which adds (Psi).

## Native C1 evidence matrix

| Cell | Point / recovery evidence | Interval evidence | C1 classification |
| --- | --- | --- | --- |
| Gaussian, complete response, rank 1, ordinary unit tier | `test-lv-gaussian-recovery.R` targets (B_{lv}), total (Sigma), and (Psi) | r500 cells `gaussian-d1-n72-t3` and `gaussian-d1-n144-t3` | Named cell closed; `LV-02` remains covered |
| Gaussian, complete response, rank 2, ordinary unit tier | Heavy recovery targets rotation-stable (B_{lv}) and (Sigma), not raw axes | r500 cells `gaussian-d2-n96-t4` and `gaussian-d2-n160-t4` | Named cell closed; `LV-02` remains covered |
| Binomial logit, probit, or cloglog, multi-trial, rank 1 | Standard-link recovery and algebra checks | Three r500 `n=160`, three-trait, 18-trial cells | Named subcells closed inside partial `LV-05` |
| Binomial Bernoulli, rank 1 | Recovery/algebra and separation diagnostics | No production interval campaign | Point/recovery subcell only; `LV-05` remains partial |
| Gaussian response mask with complete observed unit-level LV predictor | Compatibility and recovery checks | No separately calibrated masked interval cell | `LV-03` remains partial |
| Gaussian factor-valued LV predictor | Trait-by-level (B_{lv}) recovery, rare-level runtime, empty-level refusal | No factor-predictor interval calibration | `LV-04` remains partial |
| Native counts, positive continuous families, nonstandard binomial links, ordinal, mixed families, or unlisted ranks | Fail-loud guard or no admission | None | Not C1 support; broader rows remain partial/blocked |
| REML with predictor-informed `lv` | Rejected before fitting | None | Not admitted |
| Within-unit, cluster, source-specific, spatial, kernel, phylogenetic, or animal `lv` | Rejected or planned | None | `LV-06`, `LV-07`, and `LV-08` remain blocked |

The umbrella rows `FG-18`, `RE-13`, `LV-01`, `LV-04`, and
`LV-05` remain partial. `LV-06`, `LV-07`, and `LV-08` remain
blocked. Only `LV-02` remains covered as an umbrella cell. “C1 closed” in
this receipt means the named ordinary native cells and their reader path are
complete; it is not a package-wide LV promotion.

## Native Gaussian r500 denominator and MCSE audit

Retained source:

- Driver: `dev/lv-wald-coverage.R`.
- Summary:
  `docs/dev-log/artifacts/lv-wald-coverage/2026-06-28-local-r500-summary.csv`.
- Exclusion table:
  `docs/dev-log/artifacts/lv-wald-coverage/2026-06-28-local-r500-excluded-replicates.csv`.
- Paired critical-value comparison:
  `docs/dev-log/artifacts/lv-wald-coverage/2026-06-28-local-r500-t-vs-z.csv`.

The retained summary carries explicit `n_attempted`, `n_converged`,
`n_pd_hessian`, `n_sdreport_ok`, `n_ci_available`, and
`n_eligible` fields.

| Cell | Attempted | Converged | PD Hessian | CI available / eligible | Non-PD or unavailable |
| --- | ---: | ---: | ---: | ---: | ---: |
| `gaussian-d1-n72-t3` | 500 | 500 | 487 | 487 | 13 |
| `gaussian-d1-n144-t3` | 500 | 500 | 500 | 500 | 0 |
| `gaussian-d2-n96-t4` | 500 | 500 | 487 | 487 | 13 |
| `gaussian-d2-n160-t4` | 500 | 500 | 479 | 479 | 21 |

Across 28 target/method rows, conditional-on-eligible coverage was
0.9269–0.9610 and coverage MCSE was 0.0088–0.0119. All rows passed the
predeclared 0.92–0.98 audit band. The coverage and MCSE denominator is
`n_eligible`, where eligibility requires convergence, a positive-definite
Hessian, usable `sdreport()`, and finite interval endpoints. Therefore this
is conditional-on-eligible calibration with availability recorded beside it,
not unconditional procedure coverage.

## Native binomial r500 denominator and MCSE audit

Retained source:

- Driver: `dev/lv-wald-coverage.R`.
- Summary:
  `docs/dev-log/artifacts/lv-wald-coverage/2026-06-30-local-binomial-r500-summary.csv`.
- Exclusion table:
  `docs/dev-log/artifacts/lv-wald-coverage/2026-06-30-local-binomial-r500-excluded-replicates.csv`.
- Paired critical-value comparison:
  `docs/dev-log/artifacts/lv-wald-coverage/2026-06-30-local-binomial-r500-t-vs-z.csv`.
- Runtime provenance:
  `docs/dev-log/artifacts/lv-wald-coverage/2026-06-30-local-binomial-r500-session-info.txt`.

| Link cell | Trials | Rank | Attempted | Converged / PD / sdreport / CI / eligible |
| --- | ---: | ---: | ---: | ---: |
| logit | 18 | 1 | 500 | 500 / 500 / 500 / 500 / 500 |
| probit | 18 | 1 | 500 | 500 / 500 / 500 / 500 / 500 |
| cloglog | 18 | 1 | 500 | 500 / 500 / 500 / 500 / 500 |

All 1,500 attempts remained eligible. Across the 18 target/method rows,
coverage was 0.920–0.952 and coverage MCSE was 0.0096–0.0121. The
excluded-replicate artifact is header-only. These results close only the three
rank-1, multi-trial, standard-link interval subcells. They do not transfer to
Bernoulli, rank 2, cauchit, ordinal, mixed-family, masked, structured, or bridge
fits.

## R-to-Julia bridge boundary

The bridge and native rows deliberately use different covariance models:

- Native ordinary `latent(..., lv = ~ x)` uses
  \(\Lambda\Lambda^\top+\Psi\) by default.
- The Julia bridge fits this route as loadings-only. Explicit
  `latent(..., unique = FALSE, lv = ~ x)` is the canonical spelling; a
  default ordinary `latent()` call is warning-demoted to that same
  loadings-only fitted model rather than gaining a \(\Psi\) companion.

Current R-side admission is complete-response Gaussian, Poisson, NB2, Gamma,
Beta, and binomial logit/probit/cloglog, with no fixed-effect `X`, no response
mask, and no source/tier expansion. `R/julia-bridge.R` routes
`X_lv`, `lv_effects`, `alpha_lv`, `scores_mean`, and
`scores_innovation`; `tests/testthat/test-julia-bridge.R` verifies the
pure-R capability guards, payload labels, total/mean/innovation identity, and
Wald status.

The exact reader-facing bridge claim is:

> Complete-response, loadings-only point-estimate support with optional
> uncalibrated Wald plumbing; no profile, bootstrap, calibrated bridge
> interval, or native–Julia parity claim.

NB1, ordinal, mixed-family `X_lv`, fixed `X + X_lv`, response masks with
`X_lv`, and source/tier-expanded `lv` remain gated.

## GLLVM.jl lineage and raw-evidence audit

The dirty checked-out GLLVM.jl branch
`claude/jl-bridge-capabilities-20260619` at
`9f8378aa9fb9bf73f2501c65f9e91ffc6ddc1243` was not a live candidate.
The source-pinned clean candidate was the local `origin/main` git tree at
`8c9acc76c5b81e40a228ba11060394cbac5cf13c`. No fetch occurred.

| Historical commit | Full hash | Candidate relationship and retained role |
| --- | --- | --- |
| `1dc42d57` | `1dc42d5798e0f9a4e61fbc7953080de9b44745e6` | Branch-only K = 1 common-family narrative; later content squashed |
| `b7bc2acb` | `b7bc2acb167855ec70537f875477846a60ff0578` | Branch-only Gaussian addition; later content squashed |
| `2b44b6a9` | `2b44b6a92708b65147af49b4eb00706be8dd0e71` | Branch-only all-family K = 2 narrative; no retained complete driver |
| `4e4a9547` | `4e4a954706bceb76575f37ceea19aac51e0eaea1` | Branch Wald payload wiring; later content squashed |
| `6c96b758` | `6c96b7581da8827ca0dea34cf9aa8de9de0210d7` | Candidate-ancestral CI/bridge/coverage squash |
| `cd3c110f` | `cd3c110f0d7626e0804fe3c7bb1faa7d85590446` | Branch point-recovery form |
| `2ce6e29f` | `2ce6e29ff031a2be25fa0ea034e5c3b4d9ca6126` | Candidate-ancestral point-recovery squash |

The candidate retains `bench/lv_recovery.jl` and
`bench/lv_coverage.jl`, tests, and narrative tables. It does not retain
per-replicate common-family CSV, JSON, JLD2, RDS, or equivalent all-attempt
output. Historical scripts skip unsuccessful attempts and print summaries
without retaining seed, error class/message, fitted (B_{lv}), or an explicit
claim-bearing denominator policy. The K = 1 coverage script is hard-coded to
rank 1; the all-family K = 2 narrative lacks its complete retained driver.
Consequently, the narrative coverage ranges cannot supply earned MCSEs or
auditable failure denominators.

The historical parameterisations actually exercised were Gaussian identity
with observation SD 0.3; 40-trial binomial logit/probit/cloglog; Poisson log
with variance (mu); NB2 log with shared size (r=10) and
(\operatorname{Var}(Y)=mu+mu^2/r); Gamma log with shared shape
(\alpha=6) and variance (mu^2/\alpha); and Beta logit-mean with shared
precision (phi=15). These are engine-specific common-family cells, not
native gllvmTMB family or dispersion evidence.

## Historical bug controls

### Poisson generator

The failed historical Poisson coverage attempts evaluated the shared latent
predictor inside a per-cell comprehension, redrawing a supposed unit
innovation. Reported coverage was 0.463 for K = 1 and 0.611 for K = 2. After
hoisting `eta = eta_matrix(...)` outside the comprehension, the narrative
values became 0.917 and 0.961.

The source-pinned negative control matched a synthetic buggy
`Poisson(exp(eta_matrix(...)))` comprehension, rejected that pattern in
`origin/main:bench/lv_coverage.jl`, and confirmed that
`eta = eta_matrix` precedes the Poisson draw:
`POISSON_GENERATOR_NEGATIVE_CONTROL_PASS`.
This verifies the candidate fix but does not recreate missing raw attempts.

### Finite-difference Hessian

The historical diagonal stencil used `f(xp) - 2f0 + f(xm)`. Julia parses
`2f0` as the Float32 literal `2.0f0`, not `2 * f0`, so the centre
objective was discarded and non-Gaussian Wald SEs collapsed. The branch fix
was `c7db1aef`; candidate-ancestral PR form `c38c586c` uses
`f(xp) - 2 * f0 + f(xm)` in
`origin/main:src/confint_family.jl`.

The source-pinned negative control matched the synthetic broken stencil,
rejected it in the candidate, and required the corrected stencil:
`FD_HESSIAN_NEGATIVE_CONTROL_PASS`.

## Historical Model-A profile and bootstrap boundary

`docs/dev-log/artifacts/lv-effects-ci-coverage/README.md` concerns an
orthogonal Model A: ordinary predictor-informed rank-1 Gaussian $B_{lv}$
with a separate `phylo_latent()` term. Its retained profile campaign used
historical REML assumptions. Current `R/lv-predictor.R` rejects
`REML = TRUE` for predictor-informed `lv`, and
`extract_lv_effects()` publicly rejects `method = "profile"` and
`method = "bootstrap"`.

The Model-A profile evidence remains historical evidence for `LV-09` only.
It does not validate current ML-only ordinary C1, the interacting structured
`LV-08` estimand, Julia bridge intervals, non-Gaussian intervals, or rank-2
profile/bootstrap performance. Bootstrap code is retained as prototype
plumbing without a production C1 coverage claim.

## R bridge endpoint exposure

The gllvmTMB bridge admission commits are present in this lane's ancestry:

- `4812ec276e7dc5880e5615a9a43d1ff313bfc5f1`: Poisson predictor-informed
  bridge route.
- `9fd0967bec7d74defdf4150a865de6425bf846ac`: NB2, Gamma, Beta, and
  common-family bridge expansion.

Current `R/julia-bridge.R` dispatches to
`GLLVM.bridge_fit(X_lv = ...)` only after the complete-response,
loadings-only, family, link, mask, fixed-effect, and interval guards pass.
`tests/testthat/test-julia-bridge.R` checks the capability payloads and
Wald labelling without requiring a live Julia fit. The validated GLLVM
endpoint is therefore exposed as guarded experimental plumbing, not as a
calibrated cross-engine interval claim.

## Closure decision and negative space

The native ordinary Gaussian rank-1/rank-2 and named rank-1 multi-trial
binomial standard-link cells have sufficient retained recovery/coverage
evidence for a bounded reader-facing C1 closure. The article may demonstrate
the native Gaussian Wald route while stating its exact eligibility boundary.

This receipt does **not** cover Julia interval calibration; structured-source
LV; within-unit or cluster tiers; native count, Gamma, Beta, ordinal,
nonstandard binomial, or mixed-family LV; broader response masks; missing LV
predictors; fixed `X + X_lv`; REML/AI-REML; profile/bootstrap promotion; or
native–Julia parity. Each is a distinct future programme.
