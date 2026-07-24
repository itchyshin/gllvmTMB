# After-task report — Design 96 JJ recovery smoke stop

## 1. Purpose

Run the separately approved, private, six-attempt local recovery discriminator
for the Design 95 free q=2 JJ objective.

## 2. Scope

Two fixed complete Bernoulli-logit fixtures (`strong`, `moderate`) and three
predeclared starts each were run exactly once.  No external comparator,
package path, remote compute, or campaign was used.

## 3. Contract

The complete ADEMP and symbolic alignment contract is
`docs/design/96-jj-recovery-smoke.md`.  It uses only invariant covariance,
fixed-effect, and population-marginal probability targets, never raw latent
coordinates or posterior-mean plug-in probabilities.

## 4. Implementation

`dev/design96-jj-recovery/` contains a private copied TMB objective, DGP/oracle
helpers, and an exclusive-create runner.  The runner refuses a nonempty result
root, so it cannot overwrite or rerun evidence.

## 5. Commands and outputs

`Rscript --vanilla dev/design96-jj-recovery/run-smoke.R` compiled with Apple
clang/TMB 1.9.21 and wrote all ten expected JSON files: manifest, two fixtures,
six attempts, and final summary.  `summary.json` verdict: `SMOKE_STOP`.

## 6. Predeclared outcome

All six attempts returned optimizer code zero for both phases.  Only
`strong/A` met the post-BFGS gradient health threshold (`9.588e-05`).  The
remaining five gradients were `1.214e-04` to `2.717e-04`, exceeding the fixed
`1e-4` limit.  In addition, all moderate-fixture attempts had first-eigenvalue
relative error about `1.8425`, above the fixed `0.75` limit.  Therefore both
fixture verdicts are `HEALTH_FAIL` and the smoke correctly stops.

## 7. Evidence retained

The result root is immutable.  Its final summary SHA-256 is
`a1533486b3f19b3cb07cb144d44dd098283faf88ca562b1ad85a4e083932f3ef`.
The six start-level JSON records retain all objective, gradient, target, and
warning fields.

## 8. What this does not mean

It does not establish that every JJ fit is numerically bad; the point estimates
were closely similar across starts.  It does establish that this predeclared
two-fixture, six-start recovery smoke did not clear its all-start health and
invariant recovery contract.  It does not justify changing thresholds, adding
starts, rerunning, starting a campaign, or integrating the prototype.

## 9. Scope audit

`git diff 8b76a9db -- src R man NAMESPACE DESCRIPTION inst vignettes README.md
NEWS.md _pkgdown.yml` was empty.  Designs 72/85/86/90/91/94/95 were unchanged.

## 10. Review

Fisher/Gauss first rejected the incomplete recovery design, then passed it
after the target, DGP, start, and rank-sensitive corrections. Rose passed the
output-immutability and scope contract. Final adjudication is recorded in the
result packet and is still subject to the closeout review.

## 11. Next safe action

Design 96 is terminal at `SMOKE_STOP`. A future investigation must be a
separately approved new research design that asks a different question; it
cannot amend or replay this smoke.
