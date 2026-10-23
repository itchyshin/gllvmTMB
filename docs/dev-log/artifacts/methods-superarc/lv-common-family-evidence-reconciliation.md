# LV common-family sister-evidence reconciliation

Date: 2026-08-25
gllvmTMB branch: `codex/lv-family-evidence-reconcile`
gllvmTMB base: `482c9d372c7dc100f988f41f80d1b4cc3ce8a8e4` = audited `origin/main`
GLLVM.jl treatment: read-only; no checkout, branch, worktree, file, index, or fit was changed

## Verdict

`LV_COMMON_FAMILY_HOLD__RAW_OR_LINEAGE_GAP`

The common-family predictor-informed latent-variable implementation, corrected
generator, and Wald endpoint are reusable engineering inputs. The historical
coverage and recovery summaries are not independently reusable claim-bearing
evidence because seed-level results, failure records, MCSEs, and a retained K=2
driver are absent. No new family campaign is warranted. The smallest missing-
evidence pre-run is frozen below and was not launched.

## Audit boundary

This receipt audits the complete-response ordinary reduced-rank `X_lv` route,
the `latent(..., unique = FALSE)` cell whose conditional covariance is
`Sigma = Lambda Lambda^T`,
for Gaussian, binomial logit/probit/cloglog, Poisson, NB2, Gamma, and Beta.
It does not admit native-TMB count/Gamma/Beta `lv` fits, masks, fixed `X + X_lv`,
mixed families, source tiers, profile/bootstrap inference, or public coverage
claims. All GLLVM.jl reads used git objects or the current working tree without
mutation. No fit, simulation, benchmark, Totoro/DRAC job, or GitHub Actions run
occurred.

## Commit ancestry and supported candidate

The GLLVM.jl checkout is dirty and owned by another lane. Its checked-out
branch, `claude/jl-bridge-capabilities-20260619`, is at
`9f8378aa9fb9bf73f2501c65f9e91ffc6ddc1243` and does not contain the requested
common-family commits. It is therefore not a clean candidate and was not used
for a live bridge call.

The audited supported candidate is the local `origin/main` git tree at
`8c9acc76c5b81e40a228ba11060394cbac5cf13c` (commit date 2026-08-25). No network
fetch was performed, so this is a source-pinned local candidate, not a claim
about a newer remote state.

| Historical commit | Full hash and role | Ancestry against candidate |
| --- | --- | --- |
| `1dc42d57` | `1dc42d5798e0f9a4e61fbc7953080de9b44745e6`; K=1 seven-GLM coverage script/table | not an ancestor; branch history incorporated into later squash |
| `b7bc2acb` | `b7bc2acb167855ec70537f875477846a60ff0578`; Gaussian added to K=1 coverage | not an ancestor; branch history incorporated into later squash |
| `2b44b6a9` | `2b44b6a92708b65147af49b4eb00706be8dd0e71`; K=2 all-family narrative table | not an ancestor; branch-only narrative history |
| `4e4a9547` | `4e4a954706bceb76575f37ceea19aac51e0eaea1`; bridge Wald payload wiring | not an ancestor; bridge content incorporated into later squash |
| `6c96b758` | `6c96b7581da8827ca0dea34cf9aa8de9de0210d7`; CI/bridge/coverage PR squash | direct candidate ancestor containing the squashed CI/bridge/coverage package |
| `cd3c110f` | `cd3c110f0d7626e0804fe3c7bb1faa7d85590446`; branch point-recovery evidence | not an ancestor; duplicated by PR-form squash |
| `2ce6e29f` | `2ce6e29ff031a2be25fa0ea034e5c3b4d9ca6126`; point-recovery PR squash | direct candidate ancestor |

The ancestry audit used `git show -s --format`, `git merge-base
--is-ancestor`, `git branch -a --contains`, and `git diff-tree --name-status`.
The short hashes alone are not treated as a linear chain: `1dc42d57`,
`b7bc2acb`, `2b44b6a9`, and `4e4a9547` live on the historical
`xlv-wald-ci` branch, while `6c96b758` is the candidate-ancestral squash whose
tree contains their retained CI source, tests, bench script, and prose. The
same distinction holds for `cd3c110f` versus candidate-ancestral `2ce6e29f`.

## DGP and estimand

The retained correctly specified model is

\[
u_i = X_{lv,i}\alpha + e_i,\qquad e_i\sim N(0,I_K),
\]

\[
\eta_{ti}=\beta_t+\lambda_t^\top u_i,
\qquad B_{lv}=\Lambda\alpha^\top.
\]

The unit innovation is standard normal; its scale belongs in `Lambda`. This is
explicit in candidate-ancestral `2ce6e29f:bench/lv_recovery.jl` and
`6c96b758:bench/lv_coverage.jl`. The historical recovery checkpoint documents
why the older `0.2 * randn` fixture was misspecified and cannot support magnitude
recovery.

`B_lv` is the cross-fit estimand. For any orthogonal rotation `Q`,
`(Lambda Q)(alpha Q)^T = Lambda alpha^T`. Raw `alpha` and raw `Lambda` depend on
axis constraints and are not independent recovery or coverage targets. Score
decomposition (`total = mean + innovation`) and conditional covariance are
implementation checks, not substitutes for `B_lv` recovery.

## Family and dispersion parameterisations

The candidate-ancestral scripts use one ordinary latent block and complete
responses:

| Route | Link / response parameterisation | Historical DGP value | Candidate endpoint |
| --- | --- | --- | --- |
| Gaussian | identity, Gaussian observation SD `0.3` in the DGP | `0.3` | `fit_gaussian_gllvm(..., X_lv=)` |
| Binomial logit | `N=40`, logit | 40 trials | `fit_binomial_gllvm(..., link=LogitLink(), X_lv=)` |
| Binomial probit | `N=40`, probit | 40 trials | `fit_binomial_gllvm(..., link=ProbitLink(), X_lv=)` |
| Binomial cloglog | `N=40`, complementary log-log | 40 trials | `fit_binomial_gllvm(..., link=CLogLogLink(), X_lv=)` |
| Poisson | log link, `Var(Y)=mu` | no dispersion | `fit_poisson_gllvm(..., X_lv=)` |
| NB2 | log link, `Var(Y)=mu+mu^2/r` | shared size `r=10` | shared-dispersion `fit_nb_gllvm(..., X_lv=)` |
| Gamma | log link, `Var(Y)=mu^2/alpha` | shared shape `alpha=6` | shared-shape `fit_gamma_gllvm(..., X_lv=)` |
| Beta | logit mean, precision parameterisation | shared precision `phi=15` | shared-precision `fit_beta_gllvm(..., X_lv=)` |

These are the GLLVM.jl common-family parameterisations actually exercised.
The positive Gaussian SD, NB2 size `r`, Gamma shape `alpha`, and Beta precision
`phi` are optimized on log scales and exponentiated by their fitters. The
loading vector is unpacked under GLLVM.jl's lower-triangular identification
constraint. Those transforms identify the implemented endpoint; they do not
make raw loading axes comparable across fits.

They do not justify grouped/per-trait dispersion claims, and they do not imply
native gllvmTMB likelihood parity. In particular, the current GLLVM.jl bridge
comments explicitly distinguish the shared NB2/Beta/Gamma `X_lv` fitters from
the newer grouped/per-trait no-`X_lv` paths.

## Raw evidence and all-attempt denominators

Candidate-ancestral `2ce6e29f` retains `bench/lv_recovery.jl` and narrative
Markdown tables. Candidate-ancestral `6c96b758` retains `bench/lv_coverage.jl`,
tests, and narrative Markdown tables. A full `git ls-tree -r` search found no
per-replicate CSV, JSON, JLD2, RDS, or equivalent common-family `X_lv` result
artifact. The ignored local `bench/results/` files belong to phylogenetic
Poisson work, not this common-family programme.

### K=1 point recovery

- `p=5`, `K=1`, `q_lv=1`.
- Headline: `n=160`, `S=40` per route; eight routes, 320 attempted fits.
- Scaling narrative: `n=160,320,640`, `S=40`, which would be 960 attempts.
- Seed formula in source: `20260 + 991*s + 7*n`.
- The source catches every error, increments `nfail`, drops the failed attempt,
  and prints only `ok/S`. It does not retain seed, error class/message, fitted
  `B_lv`, or a machine-readable all-attempt row.
- The Markdown reports 40/40 for each route, but no raw output proves those
  denominators independently.

### K=1 Wald coverage

- `p=5`, `K=1`, `q_lv=1`, `n=200`, `S=80`, level 0.95.
- Eight routes, 640 attempted fits and up to 3,200 trait intervals.
- Seed formula in source: `31415 + 977*s + 13*n`.
- The runner silently continues after exceptions, non-convergence,
  a false `pd_hessian` flag, or nonfinite endpoints. In this historical code,
  `pd_hessian` means that the Hessian inverse was obtained; it is an
  invertibility proxy, not a positive-definiteness test. The runner prints
  `ok`, `PD`, and usable interval totals but does not retain exclusion reasons
  or rows.
- The Markdown reports 80/80 fits and 80/80 PD for all routes and coverage
  0.915--0.955. Those are narrative-only summaries.
- No MCSE is calculated or retained. For orientation only, a binomial MCSE
  based on 400 independent trait intervals would be about 0.011 at 0.95, but
  traits within a fitted dataset are not independent replicates; this plug-in
  number is not an earned MCSE for the reported aggregate.

### K=2 coverage

- The narrative in `2b44b6a9` reports `n=240`, `p=6`, `K=2`, `S=60`, eight
  routes, 60/60 converged and labelled `PD` under the successful-inverse proxy,
  and coverage 0.925--0.964.
- The retained candidate script is hard-coded `K=1`. No K=2 driver, seed-level
  output, or failure table was found.
- `6c96b758:docs/dev-log/after-task/2026-06-27-xlv-k2-tier-expansion.md`
  describes direct K=2 Poisson point/coverage work more narrowly than the
  all-family narrative table. Without raw outputs or the generating driver,
  that difference cannot be independently reconciled.

### Failure and MCSE policy verdict

The scripts implement a usable exploratory skip policy but not a claim-bearing
failure policy. They do not preserve every failed attempt, do not partition
failures by mechanism, and do not predeclare whether coverage uses attempted,
converged, successful-inverse-proxy, or finite-CI denominators. They also omit MCSEs. This is
the load-bearing reason for HOLD even though every narrative denominator is
reported as complete.

## Poisson generator bug

The coverage checkpoint records two failed attempts:

- K=1 Poisson coverage 0.463 when `eta_matrix(...)` was evaluated inside the
  per-cell comprehension, redrawing the supposed shared unit innovation.
- K=2 Poisson coverage 0.611 under the same mistake.

After hoisting `eta = eta_matrix(...)` once outside the comprehension, the
narrative values became 0.917 and 0.961. This is a DGP failure, not an engine
failure. The broken source and first-run raw outputs were not committed.

A static positive/negative-control check was run on the source-pinned candidate:
the detector matched a synthetic `Poisson(exp(eta_matrix(...)))` buggy
comprehension, rejected that pattern in `origin/main:bench/lv_coverage.jl`, and
confirmed `eta = eta_matrix` precedes the Poisson draw. It printed
`POISSON_GENERATOR_NEGATIVE_CONTROL_PASS`. This proves the current script has the
fix; it cannot recreate the missing historical raw attempts.

## Finite-difference Hessian fix

The historical bug was Julia syntax, not numerical theory:

```julia
f(xp) - 2f0 + f(xm)
```

parses `2f0` as the Float32 literal `2.0f0`, not `2 * f0`. It discarded the
centre objective from the diagonal second difference and drove non-Gaussian
Wald SEs toward zero. Commit `c38c586c` is the candidate-ancestral PR form of
the fix; its branch form is `c7db1aef`. The candidate source at
`origin/main:src/confint_family.jl` uses `f(xp) - 2 * f0 + f(xm)` and carries the
regression comment. The after-task records an analytic-Hessian regression test
and an end-to-end Poisson SE sanity check.

A static positive/negative-control check matched the synthetic broken stencil,
rejected it in the candidate, and required the corrected stencil. It printed
`FD_HESSIAN_NEGATIVE_CONTROL_PASS`. The common-family coverage narratives were
generated after this fix, but their raw results remain absent.

## R bridge endpoint

The gllvmTMB admission commits are candidate-ancestral:

- `4812ec27` / `4812ec276e7dc5880e5615a9a43d1ff313bfc5f1` adds Poisson.
- `9fd0967b` / `9fd0967bec7d74defdf4150a865de6425bf846ac` adds NB2, Gamma,
  and Beta.

Current `R/julia-bridge.R` includes Gaussian, Poisson, the three standard
binomial keys, NB2 (`negbinomial`), Beta, and Gamma in
`.GLLVM_JULIA_XLV_FAMILIES`. It rejects masks and simultaneous fixed `X`, admits
only `ci_method = "none"` or `"wald"`, passes `X_lv` to the top-level
`GLLVM.bridge_fit` JuliaCall endpoint, and normalises `lv_effects`,
`alpha_lv`, `scores_mean`, `scores_innovation`, and optional Wald fields.

The supported GLLVM.jl candidate exposes the same endpoint and family keys for
the `latent(..., unique = FALSE)` bridge cell:
`origin/main:src/bridge.jl` defines `bridge_fit(..., X_lv=nothing, ...)`, routes
the four common hard families to `fit_poisson_gllvm`, `fit_nb_gllvm`,
`fit_gamma_gllvm`, and `fit_beta_gllvm`, and returns `lv_effects =
Lambda*alpha_lv'` plus the score components. Optional Wald payloads call
`confint_lv_effects`.

Therefore the source-pinned R and supported-candidate endpoint contracts match
for the loadings-only conditional covariance `Sigma = Lambda Lambda^T`. This
receipt does not transfer the Julia evidence to ordinary gllvmTMB `latent()`'s
default `Sigma = Lambda Lambda^T + diag(psi)` contract.
The dirty checked-out GLLVM.jl branch does not expose `X_lv`; pointing
`GLLVM_JL_PATH` at that owned checkout would be unsafe, but that local path
hazard is not evidence that the supported `origin/main` contract is broken.
No live route-health fit was needed to decide this source-level endpoint audit.

## Frozen smallest missing-evidence pre-run

Purpose: prove that a raw-retention wrapper records every attempt on the clean
supported candidate before considering any new coverage evidence. This is not a
coverage campaign and does not promote a status row.

Frozen design:

1. Obtain a new explicit owner decision permitting a clean GLLVM.jl worktree at
   `8c9acc76c5b81e40a228ba11060394cbac5cf13c`; do not use or mutate the dirty
   owned checkout.
2. Run exactly four complete-response K=1 route-health fits: Poisson, shared-r
   NB2, shared-shape Gamma, and shared-precision Beta, one deterministic seed
   each, using the corrected unit-innovation DGP and `ci_method="wald"`.
3. Before fitting, run the two static positive/negative controls above and
   assert the full candidate hash plus `GLLVM.bridge_fit` `X_lv` capability.
4. Write one immutable row per attempted fit, including candidate and script
   hashes, seed, DGP parameters, family/dispersion parameterisation, start/end
   times, convergence, gradient/optimizer status, the exact historical
   `pd_hessian`/successful-inverse proxy, CI availability,
   `B_lv` truth/estimate/SE/bounds, and error class/message. Four attempts must
   yield four rows even when all fail.
5. Stop after four. Do not compute a coverage proportion or generalise to K=2.

Estimate before run: 8--20 minutes wall clock locally based on the historical
`n=200` family sweep, plus less than one minute for static guards. This is an
unmeasured estimate because the required clean candidate checkout does not yet
exist; time the first route and stop/re-report if the total projects above 30
minutes. Any clean-worktree creation, fit, remote work, or wider campaign needs
new explicit approval. No pre-run was launched in this lane.

## Scope conclusion

Reusable now: model equations, unit innovation, `B_lv` estimand, family-specific
shared-dispersion parameterisations, corrected Poisson generator, corrected
finite-difference Hessian, candidate endpoint, R payload plumbing, and the
historical scripts as pre-run design inputs.

Not reusable as claim-bearing evidence: the narrative coverage/recovery tables,
K=2 all-family statement, failure denominators beyond prose, or any implied
calibration status. The absence of raw attempts and MCSE/failure policy is not
repaired by rerunning 500 replicates; it is repaired first by the frozen four-fit
raw-retention pre-run under a separately owned clean candidate.
