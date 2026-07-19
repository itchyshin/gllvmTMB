# Local sister inventory — high-dimensional non-Gaussian inference

**Date:** 2026-07-19
**Scope:** read-only inventory for the 1.0 high-dimensional non-Gaussian
inference decision. This note uses only local repository material. It does not
make an external-literature claim, recommend a source change, or promote an
unvalidated capability.

## Current gllvmTMB truth

### What the shipped path actually integrates

`gllvmTMB` is Laplace-only at the live TMB seam. `R/fit-multi.R` constructs a
`random` vector containing all active latent blocks — ordinary reduced-rank and
diagonal blocks, phylogenetic and SPDE fields, structured slope fields, and
missing-data fields — then supplies it to `TMB::MakeADFun()`.

* Current seam: the random-block construction begins at `R/fit-multi.R:4504`
  and `MakeADFun(..., random = random)` is at `R/fit-multi.R:4571-4578`.
* The C++ template holds the sparse phylogenetic precision as
  `Ainv_phy_rr` (`src/gllvmTMB.cpp:295-299`) and represents a full
  phylogenetic augmented-slope covariance by `theta_dep_chol`
  (`src/gllvmTMB.cpp:593-600`). The family is selected per response row by
  `family_id_vec` (`src/gllvmTMB.cpp:225-252`). These are the relevant
  high-dimensional seams; an alternative integrator must preserve their
  stacked-trait eta/family contract.
* `gllvmTMB_check_consistency()` is already the appropriate *diagnostic*, not
  a certificate: it checks centring of TMB's approximate marginal score and
  explicitly links non-centring to a non-Gaussian or weakly constrained
  random-effect posterior (`R/check-consistency.R:26-66, 132-240`).

### Present inference objects are not posterior objects

The current route vocabulary is profile, Wald, bootstrap, and a labelled
`wald(numeric)` fallback; estimated-likelihood/fixed-nuisance LR is not
implemented (`docs/design/75-inference-route-truth-matrix.md:12-56`). Route
tests do not establish empirical coverage (`docs/design/75-inference-route-truth-matrix.md:58-92`). Thus
neither the existing profile nor bootstrap surface supplies a Bayesian
posterior reference for a new variational path.

Gaussian REML is a separate Laplace fold of `b_fix` and the live fit path
rejects non-Gaussian REML (`R/fit-multi.R:2315-2321, 4504-4511`). Do not
relabel a non-Gaussian VA, AGHQ, or
observed-information path as REML/AI-REML.

## Design 72: retained VA evidence and candidate q forms

Design 72 is a **parked** feasibility/Phase-1 record, not an implementation
authorization. The original experimental files were on
`claude/va-phase1-proof` and are absent from this checkout; the after-task
report records a separate DLL and explicitly says not to merge
(`docs/dev-log/after-task/2026-06-03-va-phase1-proof.md:1-23`). The current
design records the outcome as parked and defers Phase 2 pending an explicit
maintainer decision (`docs/design/72-variational-approximation-feasibility.md:59-98`).

The design specifies the following Gaussian variational candidates:

| Label | Candidate q / prior | Local rationale and status |
|---|---|---|
| Q1: mean-field anchor | `q(u)=N(a, S)` with diagonal `S` | Cheapest Phase-1 scaffold. It is the archived proof form, not a structured-GLLVM solution. It captures the general KL `0.5[tr(Qp S)+a'Qp a-logdet(Qp S)-m]` (`docs/design/72-variational-approximation-feasibility.md:278-292`). |
| Q2: phylogenetic Kronecker | `S = S_b (x) A_phy` against `Qp = Sigma_b^{-1} (x) A_phy^{-1}` | The only candidate that retains the exact tree structure at scalable cost. It is an untested Phase-3 hypothesis and may be inaccurate for non-Gaussian likelihood coupling (`docs/design/72-variational-approximation-feasibility.md:294-325`). |
| Q3: spatial sparse precision | a GMRF variational posterior whose `S^{-1}` shares SPDE `Q` sparsity | Natural structural target because the template already uses sparse GMRF machinery; SPA-10 is proposed as the first *structured* test, not as a covered capability (`docs/design/72-variational-approximation-feasibility.md:327-341`). |
| Q4: known-V | Gaussian q with fixed `Qp=V^{-1}` | Algebraically lowest risk but not aligned with the current convergence pain; Design 72 says park it (`docs/design/72-variational-approximation-feasibility.md:343-351`). |

For Gaussian, Poisson-log, NB, and probit binary/ordinal, Design 72 records
closed-form expected likelihood terms. It records an EVA second-order route
for logit binomial and several other families
(`docs/design/72-variational-approximation-feasibility.md:353-375`). Design 85
does not claim that route is closed form: it proposes a separately gated,
one-dimensional Gauss--Hermite evaluation of the Gaussian logit expectation.
This is a family-specific numerical likelihood build, not a parameter-map-only
change.

### What Phase 1 actually established

The archived standalone prototype used a mean-field diagonal q with Gaussian
and Poisson terms, a dense per-group prior, no TMB `random=` block, and a
byte-identical minimal LA comparator
(`docs/dev-log/after-task/2026-06-03-va-phase1-proof.md:24-50`). Its toy
results show joint collapse of LA and VA at small group counts, and agreement
once the model is identifiable (`docs/dev-log/after-task/2026-06-03-va-phase1-proof.md:72-139`). Therefore its reusable contribution is the **falsification
template** — Gaussian anchor + LA/VA/truth comparison + a collapse sentinel —
not evidence that mean-field VA fixes high-dimensional phylo/SPDE inference.

## Sister reference artefacts

### Reference Q1 — drmTMB O3 is a scalar oracle pattern only

`drmTMB/R/aghq-coxreid.R:1-15` implements nested external AGHQ over **one
scalar random effect per cluster**, followed by a Cox--Reid fixed-effect
adjustment. The inner marginalization, curvature recentering, and
`nq=1 == Laplace` identity are explicit in
`drmTMB/R/aghq-coxreid.R:49-94`; the outer restricted objective profiles
fixed effects only after AGHQ marginalization
(`drmTMB/R/aghq-coxreid.R:103-116, 159-172`). Its profile leaves a non-finite
boundary endpoint explicit rather than fabricating a bound
(`drmTMB/R/aghq-coxreid.R:175-194`). Deterministic comparator tests check
`glmer(nAGQ=k)`, `nq=1`, the AGHQ/Cox--Reid ladder, and finite profiles
(`drmTMB/tests/testthat/test-aghq-coxreid.R:25-53`).

This is reusable as an independent **low-dimensional oracle and test design**.
It does not compose with gllvmTMB's multi-dimensional latent vector: a product
AGHQ grid has the usual dimensional explosion. It must not be copied into
`random=` or called a high-dimensional implementation.

### Reference Q2 — DRM.jl contains scalar mean-field ELBO kernels, not a GLLVM engine

`DRM.jl/src/variational.jl:1-45` exposes an internal LA/VA method surface and
currently errors for the generic dispatcher outside its listed scalar
random-intercept cases. The Poisson kernel gives a compact, differentiable
mean-field ELBO/KL reference and marks the returned log likelihood as a lower
bound (`DRM.jl/src/variational.jl:55-147`). The binomial kernel instead uses
Gauss--Hermite integration *inside the scalar q expectation*
(`DRM.jl/src/variational.jl:151-278`). Its public scaffold test still contains
skipped numerical anchors, including ELBO-vs-dense-quadrature
(`DRM.jl/test/test_variational.jl:1-20`).

This is reusable as scalar algebra and adversarial test motifs: zero-variance
limit, ELBO no greater than an independent low-dimensional quadrature
reference, and NB-to-Poisson family limit. It is not direct code for a
stacked-trait, structured-prior GLLVM.

`GLLVM.jl` supplies a current non-Gaussian Laplace/profile reference, not a
VA/AGHQ implementation; its mode workspace and safeguarded mode stepping are
in `GLLVM.jl/src/families/laplace.jl:36-73`. It should inform Laplace
comparators/gradient checks only.

## Prohibitions and live unresolved claims

1. Do not restart Phase 2/3 merely because Phase 1 converged. Design 72
   requires a real skip cell and rejects a VA "success" produced by
   variance collapse (`docs/design/72-variational-approximation-feasibility.md:440-486`).
2. Do not advertise VA, compare VA ELBO AIC/LRT with LA, or promote it before
   VA-vs-LA recovery is registered (`docs/design/72-variational-approximation-feasibility.md:379-408, 492-516`).
3. Do not treat binomial undercoverage as established Laplace error. This arc
   supplies no coverage mechanism claim and does not use it to justify
   AGHQ/Cox--Reid work.
4. The merged `test-aghq-o3-scalar-spike.R` is a reusable package test: it
   sources `tests/testthat/helper-aghq-o3.R`, and the O3 after-task records the
   source-build repair (`tests/testthat/test-aghq-o3-scalar-spike.R:1-13`;
   `docs/dev-log/after-task/2026-07-19-aghq-o3-gllvmtmb-hooks.md:77-90`).

## Stage-map correction

This inventory does **not** define a separate probit R3 diagnostic. The
approved stage map is: R0 evidence synthesis, R1 Design 85 formal contract,
R2 fixed-coordinate q=1/2 reference harness, then R3 only if those gates pass:
the non-exported full-covariance, complete multi-trial binomial-logit VA
prototype specified in Design 85. It uses
`latent(..., unique = FALSE)` and targets shared
`Sigma_B = Lambda Lambda^T`; no `Psi`, link residual, or interpretation-scale
total covariance is silently introduced. A future probit diagnostic would need
its own estimand, formula, and approval rather than borrowing this arc's R3
label.

## Primary-source questions for the NotebookLM gate

1. For GLLVMs with structured phylogenetic/SPDE precision, what variational
   covariance structures are actually used, and is the KL exact under the
   claimed Kronecker/sparse parameterisation?
2. For non-Gaussian GLLVM VA/EVA, what correction (if any) makes variance/
   covariance uncertainty usable, and which quantities remain downward biased?
3. What independent low-dimensional quadrature/MCMC reference is accepted for
   probit/logit GLLVM latent-covariance and boundary-profile checks?
4. What are valid restricted-likelihood/Cox--Reid objectives when the latent
   field is multivariate and variationally or quadrature marginalized; in
   particular, can the fixed-effect adjustment be nested without changing the
   estimand?
5. What dimensional/sparsity regimes make adaptive or sparse-grid quadrature
   competitive with Laplace or structured VA for latent dimensions 1--3 versus
   larger stacked-trait fields?
