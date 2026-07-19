# R0 evidence synthesis — high-dimensional non-Gaussian inference

**Date:** 2026-07-19
**Scope:** formal-contract inputs only; this note does not establish a package
implementation, performance claim, or a public-facing capability.

## Evidence status

| ID | Source and quality | What it can support here |
| --- | --- | --- |
| P1 | Niku J, Brooks W, Herliansyah R, Hui FKC, Taskinen S, Warton DI (2019), *Efficient estimation of generalized linear latent variable models*, *PLOS ONE* 14:e0216129, doi:[10.1371/journal.pone.0216129](https://doi.org/10.1371/journal.pone.0216129). **Primary, peer-reviewed, open full text.** | The GLLVM variational distribution, lower-bound objective, general quadrature-scaling warning, and the paper's own inference caveat. |
| O1 | [`gllvm` reference: `gllvm()`](https://jenniniku.github.io/gllvm/reference/gllvm.html). **Official package documentation.** | The documented fitting menu: LA, VA, and EVA; no documented AGHQ or REML/Cox--Reid route in this reference. |
| Q1 | *Computational Approaches for Frequentist GLLVMs in High-Dimensional Latent Spaces* (NotebookLM source `a84780d8`; no bibliographic provenance/primary text established). **Secondary, unverified.** | Quarantine only. It asserts a `q >= 4` AGHQ cutoff, diagonal VA, and Cox--Reid/ELBO distinctions, but is not load-bearing evidence. |
| X1 | Hui et al., *Variational Approximations for Generalized Linear Latent Variable Models* (NotebookLM source `c6aa61c8`, ResearchGate mirror). **Unavailable.** | No support: indexed content is an access-denied page, not the article. Retrieve a publisher/author copy before relying on the original VA paper directly. |

## R0 contract statements

1. **A full per-unit variational covariance is literature-supported.** P1 uses
   independent variational densities across observational units and specifies
   `q(u_i^*) = N(a_i, A_i)`, with `A_i` an *unstructured* covariance matrix for
   the per-unit combined random-effect/latent vector. Thus, for a pure
   `q`-dimensional latent vector, the published construction permits a full
   `q x q` variational covariance; it is not intrinsically mean-field. Do not
   confuse `A_i` with the GLLVM prior covariance: P1 fixes latent-variable
   scale with `u_i ~ N(0, I)` (and uses a block-diagonal prior when it includes
   a random row effect).

2. **The VA objective is an ELBO/variational log likelihood, not the exact
   marginal likelihood.** P1 calls it a strict lower bound to the marginal
   log likelihood, maximised over model and variational parameters, equivalently
   minimising KL divergence from the true posterior to the variational density.
   Its practical attraction is a closed-form or almost-closed-form marginal
   likelihood approximation; P1 notes that the expectation term is not
   guaranteed closed form for every exponential-family response. Therefore
   contract wording must say *ELBO (variational lower-bound) optimisation*,
   never “exact ML”.

3. **Uncertainty is conditional on the approximation and remains incomplete.**
   P1 describes prediction intervals from the estimated variational covariance
   plus the assumed variational density, and asymptotic parameter standard
   errors from the appropriate block inverse of the negative Hessian of the
   variational lower bound. The same paper explicitly says that large-sample
   properties of VA estimates and inference had not been thoroughly studied.
   R0 consequently permits reporting Hessian-based approximate uncertainty only
   with that qualification; it does not support calibrated-coverage, exact-
   likelihood, or posterior-variance claims. Claims that VA *necessarily*
   underestimates variance belong in quarantine until a suitable primary source
   and package-specific recovery/coverage study are supplied.

4. **AGHQ at `q >= 4`: retain only as an operational boundary, not a primary-
   literature threshold.** P1 says Gauss--Hermite quadrature becomes
   computationally impractical with a larger number of latent variables, and
   O1 does not document AGHQ at all. Neither gives the numerical `q >= 4`
   cutoff. Q1 gives the usual tensor-product rationale (`k^q` evaluations per
   unit) and recommends that cutoff, but Q1 is secondary/unverified. The formal
   contract may use `q >= 4` as a conservative **package design guard** (with
   LA/VA as the permitted routes), but must not attribute that exact number to
   Niku et al. (2019) or present it as a settled literature theorem.

5. **No Cox--Reid or non-Gaussian REML support is established.** P1 describes
   likelihood, Laplace, and variational-lower-bound estimation; O1 documents
   LA, VA, and EVA. Searches of O1 find no `REML`, restricted likelihood,
   Cox--Reid, or conditional-likelihood route. Hence this R0 contract supports
   an explicit negative scope statement: *Cox--Reid adjustment and
   non-Gaussian REML are not supported by the evidence/route documented here.*
   This is an implementation-and-evidence boundary, not a claim that such
   methods are impossible; a source-code audit is still required before saying
   “not implemented” about a particular package version.

## Quarantine and remaining gaps

- **Do not cite Q1 publicly.** Its `q >= 4` threshold, diagonal-VA recommendation,
  claimed post-hoc correction, and Cox--Reid comparison need primary sources or
  a reproducible package study.
- **Recover the original VA article from a primary host.** The current
  ResearchGate entry is unusable; P1 cites the VA lineage but cannot replace a
  direct check of the source paper's assumptions and scope.
- **Validate the numerical guard empirically.** A node-count/time/accuracy grid
  over `q`, quadrature nodes, response family, and sample size is needed before
  claiming that `q = 4` is a universal computational frontier.
- **Establish package-specific frequentist uncertainty.** Require simulation
  coverage for fixed effects, loadings/covariance parameters, and derived
  quantities under both full- and diagonal-`A_i` VA, plus comparator fits where
  low-dimensional AGHQ is feasible.
- **Keep the two covariance roles separate in design/prose.** A full `A_i`
  concerns the variational posterior approximation for each unit; it does not
  itself prove support for every marginal residual/trait covariance structure
  a package may expose.

## Query provenance

NotebookLM notebook: `9b5e85d7-5fbd-4c8b-b493-95cfbc9a61fb`; only ready sources
were queried. Direct P1 extraction established the unstructured `A_i`, the
variational lower-bound/KL relation, the Hessian statement, and the explicit
large-sample-inference caveat. O1 supplied official documented-method and
absence checks. Q1 and X1 are deliberately quarantined above.
