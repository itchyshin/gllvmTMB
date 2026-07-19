# High-dimensional inference pre-code claim audit

**Date:** 2026-07-19
**Role:** Rose (systems audit)
**Scope:** read-only review of Design 83b, the local-sister inventory, the R2
reference-harness specification, and current public surfaces. No implementation,
test, CI, coverage, Bartlett, CI-11, tier-2a, or Ayumi work was performed.

## Verdict: STOP before R3

The three planning documents preserve the public-API, `q >= 3` AGHQ, and
Gaussian-only REML fences, but they do not yet define one executable R3. They
assign R3 to incompatible experiments, one proposed negative fixture cannot
arise under the stated model, and several load-bearing references are stale or
absent from this branch. These are pre-code contract failures, not matters to
resolve while implementing.

## What is coherent

1. **No public capability has been promoted.** Design 83b is explicitly
   research-only and non-exported (`docs/design/83-highdim-nongaussian-va-formal-contract.md:3-16,
   321-325, 416-421`); the R2 harness is fixed-coordinate and `q <= 2`
   (`docs/dev-log/research/2026-07-19-highdim-inference-reference-harness-spec.md:3-7,
   127-139`). Current README prose still describes `gllvmTMB` as the
   TMB-Laplace alternative and reserves non-Gaussian REML
   (`README.md:210-211, 255-265`). No NEWS, public reference, vignette, or
   `_pkgdown.yml` claim advertises a shipped VA/AGHQ route.
2. **The non-Gaussian REML fence is stated correctly.** All three documents
   prohibit relabelling ELBO/AGHQ work as REML or AI-REML. The live guard is in
   `R/fit-multi.R:2315-2321`, and the Gaussian REML fold is at
   `R/fit-multi.R:4504-4511`.
3. **The ordinary loadings-only covariance is correctly fenced as**
   `Sigma_B = Lambda Lambda^T` **when `unique = FALSE`.** Design 83b does not
   add `Psi` or the logistic link residual to that model covariance
   (`docs/design/83-highdim-nongaussian-va-formal-contract.md:67-86`). It also
   honestly records the existing discrepancy between Design 04's positive
   loading diagonal and the live engine's raw diagonal
   (`docs/design/04-random-effects.md:125-145`; `src/gllvmTMB.cpp:773-805`).

## Stop findings and required remediation

### 1. R3 has three incompatible meanings

- The sister inventory defines R3 as one **probit**, `d = 1`, diagnostic-only
  n-ladder with a Gaussian control, before AGHQ/VA
  (`...local-sister-inventory.md:143-159`).
- The reference-harness specification defines R3 as a **logit**, q=1/q=2 O3
  fixture expansion and then makes R4 a 50-seed q<=2 numerical campaign
  (`...reference-harness-spec.md:59-75, 94-96, 119-139`).
- Design 83b says the only admissible next high-dimensional experiment is a
  jointly optimised **logit VA**, with later q=4/q=6 stress cells
  (`...formal-contract.md:11-16, 100-108, 398-414`).

**Remediation:** the maintainer must choose and record one ordered stage map
before code. A safe map would give distinct names to (a) the probit estimator
diagnostic, (b) the q<=2 fixed-coordinate O3 harness, and (c) the later joint-VA
prototype. No document may call a different one “R3,” “the only admissible
next experiment,” or a prerequisite-free next step.

### 2. The proposed q=2 curvature rejection cannot be generated as written

For binomial-logit observations with `u_i ~ N(0, I_q)`, the negative
conditional Hessian is

\[
H_i = I_q + \sum_t n_{it}p_{it}(1-p_{it})\lambda_t\lambda_t^T,
\]

so it is positive definite for every finite loading matrix. The current O3
helper implements exactly that structure (`tests/testthat/helper-aghq-o3.R:135-145`).
Making the loading columns nearly collinear and reducing trial information
makes the data term lower rank/smaller but leaves the identity prior; it cannot
create the specified “non-positive/ill-conditioned conditional Hessian.” Thus
`curvature_reject_q2` is not a realizable acceptance/rejection pair under the
declared DGP (`...reference-harness-spec.md:73-81`).

**Remediation:** replace it with a mathematically attainable failure contract.
For example, use an explicitly extreme but finite held-coordinate fixture that
exceeds a predeclared condition-number threshold, or test malformed/non-finite
input rejection separately. Do not claim a non-positive Hessian from ordinary
finite binomial-logit plus an identity Gaussian prior. Retain both a difficult
accepted fixture and a genuinely reachable rejected fixture.

### 3. Load-bearing references are absent, stale, or point at the wrong lines

- `R/reml-bridge.R:99-109` does not exist in this branch; the actual family
  guard is `R/fit-multi.R:2315-2321`.
- The claimed random/`MakeADFun()` seam at `R/fit-multi.R:4473-4548` is stale:
  the random vector begins at 4504 and `MakeADFun()` is at 4571-4578.
- Both profile handovers cited at inventory lines 132-137 are absent from this
  branch. One exists only on another branch/commit and cannot be used as a
  repo-relative current-branch source without an explicit branch/SHA receipt.
- The inventory says `test-aghq-o3-scalar-spike.R` is absent and still broken by
  a `dev/` dependency (`...local-sister-inventory.md:138-141`). It is present,
  sources `tests/testthat/helper-aghq-o3.R`, and the O3 after-task report records
  the tarball repair (`tests/testthat/test-aghq-o3-scalar-spike.R:1-13`;
  `docs/dev-log/after-task/2026-07-19-aghq-o3-gllvmtmb-hooks.md:77-90`).

**Remediation:** refresh all current-repo citations against this branch. Either
land the profile evidence first or cite it explicitly as external branch state
with commit SHA and non-authoritative status. Remove the obsolete O3 test claim.

### 4. The ELBO prose has a sign error

In the boxed objective, the KL bracket is subtracted. Therefore the second line
of `mathcal L_H` is **minus** `sum_i KL(q_i || p_i)`, not the KL itself. Design
83b currently says “The second line is exactly `sum_i KL`”
(`...formal-contract.md:169-188`).

**Remediation:** change that sentence to “the bracketed half-term is the KL;
the second line contributes its negative to the ELBO,” and include an algebra
test that checks the ELBO and negative-objective signs independently.

### 5. The probit R3 syntax does not enforce its stated no-Psi model

The inventory writes `latent(0 + trait | unit, d = 1)` while saying `Psi` is
pinned at zero (`...local-sister-inventory.md:143-147`). Under the current
grammar, ordinary `latent()` includes its diagonal `Psi` companion by default;
the explicit loadings-only request is `unique = FALSE`. The same paragraph then
asks for truth on the “total covariance” scale, whereas Design 83b's target is
the shared `Sigma_B = Lambda Lambda^T` and excludes link residual variance.

**Remediation:** write `latent(..., unique = FALSE)` if that is the intended
model, and name the exact target: shared `Sigma_B`, latent-plus-Psi covariance,
or interpretation-scale total covariance including the probit residual. Do not
use “pinned at zero” without specifying and testing the actual parameter map.

### 6. The logit VA derivation silently supersedes the local predecessor

The inventory repeats Design 72's statement that logit binomial requires an
EVA second-order surrogate (`...local-sister-inventory.md:65-69`), while Design
83b defines a direct one-dimensional Gauss-Hermite evaluation of the Gaussian
expectation and explicitly says it is not EVA (`...formal-contract.md:150-188`).
The newer route can be coherent, but it is deterministic quadrature of an
otherwise non-closed-form expectation, not a closed-form result.

**Remediation:** add an explicit supersession note to both documents: Design
72's “EVA required” statement is not authoritative for this bounded logit
contract; the expectation is evaluated numerically by 1-D GH. Require an
independent high-precision scalar integration comparison before relying on it.

### 7. Design numbering still collides

Both the filename/title and internal references use Design 83 even though
Design 83 is the live multinomial contract and Design 84 is already allocated
(`docs/design/83-multinomial-response-family.md`; `docs/design/84-phylogenetic-multinomial-tier2.md`).
The provisional “83b” label is not a merge-safe identifier
(`...formal-contract.md:1-9`).

**Remediation:** allocate the next free canonical design number and update the
filename, title, inbound references, and any stage documents before merge.

## Missing feedback loops

- **Noether/Gauss:** sign-check the ELBO/KL, GH normalization, small-variance
  derivative, live loading unpacker, and the impossibility/replacement of the
  curvature fixture before implementation.
- **Curie/Fisher:** predeclare the actual diagnostic question, denominators,
  recovery target, failure categories, and whether the probit diagnostic is a
  prerequisite to the logit VA experiment. Optimizer convergence remains
  insufficient evidence.
- **Boole/Emmy:** confirm there is no public method/object dispatch leakage and
  that an internal result cannot inherit likelihood methods.
- **Rose:** rerun this claim audit after the documents converge on one stage
  map and all references resolve. Only then may R3 move from STOP to
  CONDITIONAL/PASS.

## Reproducible scans used

```sh
rg -n -i "high[- ]dim|variational|VA\\b|q ?[>=]+ ?3|q>=3|R3\\b|non[- ]Gaussian.*REML|AI[- ]REML|REML|implicit.*adjoint|reference harness|sandwich|Godambe|Laplace" README.md NEWS.md ROADMAP.md _pkgdown.yml R man vignettes docs
rg -n '^# Design 83|Design 83' docs/design docs/dev-log/research README.md NEWS.md ROADMAP.md _pkgdown.yml
rg -n -i 'high[- ]dimensional|high[- ]d|variational approximation|\\bVA\\b|q ?[>=]+ ?3|q>=3|non-Gaussian REML|AI-REML' README.md NEWS.md ROADMAP.md _pkgdown.yml vignettes R man docs/design docs/dev-log/known-limitations.md docs/dev-log/capability-surface.html
rg -n "MakeADFun\\(" R/fit-multi.R
rg -n "non-Gaussian|Gaussian-only|REML.*family|family.*REML|REML is" R
```

No tests, fits, simulation, package checks, pkgdown builds, CI operations, or
external literature searches were run; this was a pre-code contract and
current-surface audit only.

---

## Re-audit addendum after remediation

**Re-audit verdict: CONDITIONAL.** The original STOP findings are resolved at
the claim-and-mathematics level, so the documents may proceed to a bounded R2
implementation. R3 remains blocked until R2 passes and the exact
held-coordinate/objective contract below is frozen. This is not authorization
for R3 code, compute, or a public capability.

### Resolved findings

1. **One stage map now exists.** The inventory assigns R0 to synthesis, R1 to
   Design 85, R2 to the fixed-coordinate q=1/2 harness, and R3 to the internal
   full-covariance binomial-logit VA prototype only
   (`...local-sister-inventory.md:143-154`). The former probit R3 has been
   removed from this arc.
2. **The impossible non-positive-Hessian fixture is retired.** R2 now states
   the correct identity-prior geometry and specifies a finite, threshold-based
   condition-number rejection paired with an admissible near-collinear case
   (`...reference-harness-spec.md:68-82`).
3. **References are current in this branch.** The REML guard and fold now point
   to `R/fit-multi.R:2315-2321, 4504-4511`; `MakeADFun()` points to
   `R/fit-multi.R:4571-4578`; unavailable profile handovers are no longer used;
   and the inventory correctly records the packaged O3 helper repair
   (`...local-sister-inventory.md:13-25, 41-44, 135-141`).
4. **The ELBO sign is corrected.** Design 85 distinguishes the positive KL
   bracket from its negative contribution to the ELBO and requires separate
   algebra/sign checks (`docs/design/85-highdim-nongaussian-va-formal-contract.md:168-190,
   346-360`).
5. **The model and covariance target now agree.** All stage-map and harness
   syntax uses `unique = FALSE`, and the target is explicitly shared
   `Sigma_B = Lambda Lambda^T`, excluding `Psi` and link-residual variance
   (`...local-sister-inventory.md:145-153`; Design 85:66-85).
6. **The EVA/GH relationship and numbering are explicit.** Design 85 describes
   deterministic one-dimensional GH evaluation as a bounded alternative to
   Design 72's EVA route, without calling it closed form
   (`docs/design/85-highdim-nongaussian-va-formal-contract.md:183-190`), and
   Designs 83/84 remain assigned to multinomial work (`ibid.:1-8`).
7. **The public and terminology fences still pass.** R2 forbids q>=3 AGHQ,
   refitting, public switches, C++ changes, and campaign artifacts; Design 85
   forbids public API/method claims and non-Gaussian REML/AI-REML wording. No
   current README, NEWS, vignette, Rd, ROADMAP, or pkgdown navigation surface
   advertises VA/AGHQ as shipped.

### Exact remaining blockers

1. **Freeze how every perturbed R2 fixture obtains its matching TMB objective.**
   The one-node identity compares reconstructed AGHQ with
   `fit$opt$objective` (`...reference-harness-spec.md:33-37`). The fixture table
   then says to multiply loadings, shift intercepts, and use an extreme
   *held-coordinate* configuration (`ibid.:68-82`). If these perturbations are
   applied after fitting only to the extracted coordinates, `fit$opt$objective`
   is no longer the objective at those coordinates and the identity must fail
   for the wrong reason. Before R2 code, the spec must choose one reproducible
   route for each row:
   - perturb the DGP, refit, and use the resulting fitted coordinates and
     objective; or
   - perturb the held parameter vector and evaluate the live TMB objective at
     that exact vector (not `fit$opt$objective`).

   Record the route and objective source in `manifest.csv`. For
   `condition_reject_q2`, also freeze the finite coordinate construction and
   seed before reading its result; “pre-screened to exceed” must not become a
   post-result tuning loop.
2. **Clarify the R4 ordering before any campaign.** The inventory's stage map
   ends R2 -> R3, while the harness names a future q<=2 reference screen “R4”
   and requires only an R2 smoke pass (`...reference-harness-spec.md:128-135`).
   State whether R4 is (a) required before R3, (b) deliberately after R3, or
   (c) an out-of-arc future screen with a different label. This does not block
   bounded R2 implementation, but it blocks campaign dispatch and any claim
   that the whole stage sequence is closed.
3. **R3 still requires evidence and explicit authority.** Design 85 remains
   pre-code and says it authorises neither implementation nor compute
   (`docs/design/85-highdim-nongaussian-va-formal-contract.md:3-5`). R3 may begin
   only after R2's fixed-coordinate identities and rejection/acceptance pair
   pass, the remaining contract ambiguity above is closed, and the maintainer
   gives the separate implementation decision required by the document.

No tests or fits were run in this re-audit because the remediated artefacts are
still design documents. `git diff --check` on this audit file is the only
write-verification required for this addendum.

### Final narrow re-audit: R2 contract closure

**The two remaining documentary blockers are resolved.** The R2 specification
now makes the objective provenance unambiguous:

- baseline, signal, intercept-shift, and near-collinear acceptance rows perturb
  the DGP, refit through ordinary ML, and compare one-node reconstruction with
  that refit's `fit$opt$objective`;
- `condition_reject_q2` uses the fully declared finite held coordinate
  (`n = 100`, `y = 50`, `beta = 0`,
  `Lambda = ((50000,0),(50000,1))`), emits Hessian telemetry, and stops with
  `condition_exceeds_limit` before TMB-objective or quadrature evaluation; and
- `objective_source` records `refit_opt` versus `prequadrature_guard`
  (`...reference-harness-spec.md:68-90`).

The optional q<=2 campaign is now **R2b**, not R4, and is explicitly downstream
of a passing R2 smoke (`...reference-harness-spec.md:128-143`). It is an
optional numerical reference screen, not an R3 prerequisite or an inference
claim.

**Final admission status: CONDITIONAL; R3 remains blocked.** No mathematical,
reference, numbering, scope, or stage-map discrepancy now blocks bounded R2.
R3 is not admitted merely because the documents are coherent: R2 must first
pass its predeclared identities and acceptance/rejection pair, and Design 85's
predeclared separate-authority gate still applies because it explicitly
authorises neither implementation nor compute
(`docs/design/85-highdim-nongaussian-va-formal-contract.md:3-5`). A fresh,
explicit maintainer GO is therefore still required before R3 code or compute.
