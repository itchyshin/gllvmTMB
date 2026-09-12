# Temporal dependent-kernel optimizer diagnostic contract

## Purpose

The retained long-occasion qualification failed because one frozen cell had a
native outer gradient above the fixed threshold despite two accepted BFGS
passes.  This contract diagnoses that endpoint.  It does not rerun, replace,
or reinterpret the failed qualification, and it does not test a changed model
or optimizer.

The model remains the additive Gaussian covariance

\[
\operatorname{Cov}(y_i,y_{i'}) =
1_{g_i=g_{i'}}\phi^{|t_i-t_{i'}|}\Sigma_T[j_i,j_{i'}]
+ K[g_i,g_{i'}]1_{j_i=j_{i'}}v_{K,j_i}
+ 1_{i=i'}\sigma_\epsilon^2.
\]

The first diagnostic target is the retained failing design point
`phi = 0`, seed `2609373`, with 80 series, 32 occasions, three traits, two
measurements, the direct generator, and the exact two-pass BFGS controls in
the qualification contract.  Any replay is diagnostic-only and gets a new
receipt; it cannot replace `cell-p00-seed-2609373.rds`.

## Required retained fields

Each diagnostic receipt must include:

- source commit, R version, platform, TMB version, start/end UTC timestamps;
- named outer parameter vector and named outer gradient at each retained
  optimizer-pass endpoint;
- both pass records, objective values, convergence codes, acceptance flags,
  warnings, and elapsed times;
- parameter blocks reconstructed at the final endpoint, the residual scale,
  and the temporal and kernel parameters;
- Hessian status and its error message when a Hessian cannot be obtained; and
- an independently authored dense Gaussian likelihood and finite-difference
  gradient check at one fixed parameter vector.  This oracle must not call
  the production temporal simulator or objective.

## Decision rule

The diagnostic has three possible outcomes.

1. If the native and independent objective/gradient agree within prespecified
   numerical tolerances, retain a numerical-endpoint finding only.  A later
   coordinate-scaling proposal must be algebraically equivalent, fixed before
   fitting, and qualified on new seeds across all three persistence values.
2. If they disagree, stop the optimizer work and investigate the native
   likelihood or derivative before any recovery campaign.
3. If the endpoint evidence is inconclusive, retain that result and do not
   infer that the zero-persistence coordinate caused the breach.

No outcome passes or weakens the failed long-occasion qualification.  No
gradient threshold, fixture, seed, or acceptance rule changes under this
contract.

## Compute boundary

Time one diagnostic replay before any multi-cell diagnostic.  A campaign
projected beyond 30 minutes needs a separate measured pre-run and approval.
Use at most four local single-thread workers; use Totoro or DRAC only under a
separate approved campaign plan.
