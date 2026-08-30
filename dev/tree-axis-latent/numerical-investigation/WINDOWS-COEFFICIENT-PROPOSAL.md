# Proposed next repair after the Windows coefficient failure

Status: proposal only, 2026-08-30. No production implementation or new fit
allowance is authorized by this document. The full two-example article goal
remains open; landing still needs separate approval.

## What the retained evidence establishes

At diagnostic commit `d1e2ce3fc9a4c79d620680949eca074367f15119`, manual run
33335896752 passed macOS and Ubuntu but repeated the two Windows warning
failures. The full-bar animal coefficient fit and its legacy slope spelling
followed exactly the same invalid trajectory: convergence code 1, false
convergence (8), and maximum gradient 0.963. Their agreement does not make
either fit valid. Suppressing the warning would not repair this failure.

The saved nonfinite trial is a valid Gaussian model. Its exact marginal NLL
is about 50.71574, with maximum exact gradient 9.70e-5 and minimum marginal
covariance eigenvalue about 0.199. Both retained native libraries return NaN
at that same point. The coefficient Cholesky factor has condition number
2.28e11. At the returned Windows endpoint, the exact NLL is about 50.71682
and exact gradient is about 0.799; the current native evaluator differs by
-0.00315 locally and the old evaluator by -0.10321. The Windows evaluator
reported an even lower value, 50.69653. These results establish numerical
failure in the centred native calculation; they do not identify one exclusive
floating-point operation or certify the endpoint as an optimum.

The old negative-prior inversion defect remains separately repaired by
triangular whitening. The new evidence shows that whitening the quadratic
alone does not cure the badly scaled latent Hessian near a coefficient
covariance boundary. Ordinary Gaussian cell integration is inactive in this
animal fixture. No article model or stabilizer was changed to diagnose it.

Exact coordinates, values, gradients, hashes and failed attempts are retained
in `../evidence/2026-08-30-windows-saved-points.json`,
`windows-coefficient-trial.R.txt`, and the
external `cell-integration-7c88/windows-trial-2/` evidence directory.
Gauss/Noether review of the independent Gaussian algebra passed. There were
four native value calls, two native gradient calls, two inner-score calls and
four exact value/gradient calls; zero outer optimizers. Two preliminary
signature checks stopped before constructing tapes and are also retained.

## One recommended change

Standardize the coefficient random effects internally within the existing
native engine. For coefficient covariance `Sigma = L L'` and the unchanged
source covariance `K_rho`, use

\[
B = U L^\top,\qquad U\sim MN(0,K_\rho,I).
\]

The prior on U retains the source normalization and quadratic, but contains
no inverse L or coefficient log-determinant. Reconstruct physical B for the
linear predictor and reports. Conditional on outer parameters, the Gaussian
random Hessian becomes

\[
I\otimes K_\rho^{-1}+Z_L^\top R^{-1}Z_L,
\]

which removes the extreme coefficient-covariance scaling from the prior
precision. This is a same-model change of internal coordinates, not a new
likelihood, rank restriction, estimator, or dense marginal engine.

Use one consistent, narrowly admitted nonspatial Gaussian response-column
coefficient path, including existing IID, animal, phylogenetic and kernel
sources and supported legacy spellings. Fixed and estimated rho retain the
same K_rho, including its diagonal scaling. An animal-only numerical branch
would leave identical coefficient algebra dependent on the source label.
Leave spatial coefficients, non-Gaussian models, unrelated augmented-slope
paths and the morphology model unchanged. Start with complete, unit-weight
Gaussian identity ML compositions; keep unsupported compositions on the
existing path rather than expand this repair's claim.

## Files and compatibility obligations

- `src/gllvmTMB.cpp`: narrowly admit the new coordinates in the column-coefficient
  prior near line 2055 and reconstruct physical B before its predictor use near
  line 2788. Retain Sigma, rho and source reports. Keep the private whitening
  helper for unaffected paths and its negative-quadratic regression.
- `R/fit-multi.R`: preserve outer parameters, fixed stabilizers and every frozen
  outer start. Convert physical B starts to U exactly once. Detect incompatible
  fixed or tied B maps; do not reinterpret them as constraints on U.
- `R/init-warmstart.R`: copy physical B from a standardized source fit before
  initializing a target. Preserve existing start_from behavior and shapes.
- Output audit: fitted values and predictions must use physical B. Preserve
  existing covariance/ordination extractors. Report physical coefficient modes
  and propagate their uncertainty through ADREPORT(B), including covariance with
  outer parameters. No conditional-variance add-on is needed: U is retained,
  unlike the analytically eliminated s_B. Do not relabel raw U precision as B
  precision or add a new getREsd block/API. Review generic consumers in
  `R/methods-gllvmTMB.R`, `R/output-methods.R`, `R/standard-errors.R` and
  `R/re-uncertainty.R`; edit only where existing behavior actually requires it.
- Tests: retain both Windows failures and every original warning assertion.
  Add saved-point Gaussian and output/uncertainty checks. Update private-coordinate
  tests such as `test-column-coef-phylo-estimated-rho.R:500` to inspect physical B.
  No seed, truth, model, tolerance or start adjustment is a remedy.
- Update `docs/design/03-likelihoods.md`, focused evidence, check-log and after-task
  report. No formula grammar, exported API, NEWS capability promotion or new
  source family is part of this proposal.

## Requested bounded validation authority

Before any standalone fit, require saved-point value/gradient agreement with
existing Gaussian oracles, compatible physical outputs/uncertainty and starts,
map fences, and no-outer morphology continuity under the final source. Failure
stops fitting and interpretation.

Then allow exactly eight new standalone attempts, raising the cumulative
ceiling from 33 to 41: three unchanged deterministic nlminb starts for each
community long model, followed by one wide fit per model only if both long
families pass. Keep finite objectives, convergence 0, gradient <1e-2, objective
spread <=1e-6, covariance/shared/unique agreement <=10%, and original long/wide
NLL and fitted-value gates. Do not select a favorite start or borrow new slots.
All earlier receipts remain immutable. No standalone morphology optimization.

From the preceding fitted block, estimate roughly 2–5 minutes total for these
eight calls after compilation, retaining the five-minute external cap per model
call and estimates before every call. Re-estimate and stop on overruns. Routine
focused package tests are separate from standalone article attempts; this is
not a recovery or benchmark campaign.

Also approve one revised primary article render with its three exact first-start
fits, separately recorded, after the eight-fit block passes. Presentation-only
rebuilds must reuse those objects. Finish local package/docs checks (previously
about 23 minutes), exact-final-head three-OS CI (20–75 minutes), reviews and PR1229
preparation. Normal deployment rendering is part of the later landing decision;
no merge or public deployment is authorized here.

Copy-ready approval if accepted:

> Approve the scoped noncentred Gaussian coefficient repair, its compatibility
> checks, eight staged standalone fits (ceiling 41), and one revised primary
> article render. Preserve every frozen model, start, stabilizer and acceptance
> gate. Landing still requires separate approval.
