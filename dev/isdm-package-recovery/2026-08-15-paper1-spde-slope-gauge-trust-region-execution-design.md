# Paper 1 gauge-coordinate trust-region execution design

**Status:** source implementation and pure/synthetic lifecycle tests are in
progress.  No clean-commit preflight, TMB build, fit, smoke, recovery
calculation, campaign, or public claim has occurred.  The one-shot numerical
attempt remains prohibited until the source/test gate, independent review, and
fresh no-build preflight are complete.

## Boundary and predecessor

The immutable MSPDE V3 packet, named in
`2026-08-15-paper1-spde-slope-gauge-coordinate-design.md`, is the sole
scientific predecessor.  The MNCB, BFGS, and gauge no-fit V1/V2 roots are
forensic infrastructure records only.  Their partial traces, values, reasons,
and timings must not select a chart, finite-difference step, shift, radius,
or acceptance threshold here.  This is therefore neither a retry nor a
continuation of any of those estimators.

The estimator has the distinct source gate

```
PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1
```

and a new root, receipt, claim, marker, ledger, manifest, and terminal schema.
It consumes the complete sealed MSPDE V3 packet, including its empty claim
directory, receipt, marker, ledger, ordered manifest, state, session, and time
estimate.  It must reread the packet and obtain the historical production
terminal success before it may claim its own root.  The no-fit V2 failure does
not supply an additional predecessor or a licence to reuse its callback trace.

## Fixed coordinate system and callback object

Let `phi0` be the full 22-vector formed by applying the gauge inverse only to
raw positions 20--22 of the immutable V3 `theta`; positions 1--19 are raw
coordinates.  Let `T(phi)`, `F(phi)`, and `G(phi)` be exactly the map,
objective, and chain-rule gradient in the gauge-coordinate design.  Define the
fixed diagonal standardisation

\[
D_{jj}=\max(1,|\phi_{0j}|),\quad z=D^{-1}(\phi-\phi_0),\quad
\widetilde F(z)=F(\phi_0+Dz),\quad
\widetilde G(z)=D G(\phi_0+Dz).
\]

`D` is constructed once from the immutable start and is retained.  It is not
updated from a trial.  This is a linear standardisation after the declared
nonlinear gauge map; it changes neither the chart nor inertia under the
congruence transformation.

Before claim, the parent launches a disposable `Rscript --vanilla` V3-validation
child.  That child activates the retained DLL and invokes the historical V3
terminal validator, writes a typed child receipt, then exits cleanly.  The
parent rereads and validates that receipt before it launches the separate
trust-region worker.  The trust-region worker therefore starts without any
inherited ADFun external pointer; it uses one exact retained DLL and one fresh
marginal-Laplace `MakeADFun` object.  It rejects a preloaded same-basename DLL
rather than unloading or replacing one.  The object remains resident through
all required gauge identity, sign-orbit, transformed-gradient, Hessian, trial,
and candidate-covariance calls, and is explicitly released and garbage-collected
while that DLL remains loaded.  There is no `dyn.unload`, outer optimiser,
retry, factory rebuild, or adaptive rerun.

The V3 child writes only into a parent-authenticated disposable sibling stage
whose initial inventory is exactly its stage token.  Its validated receipt is
then copied atomically into the distinct scientific packet stage.  The child
must never write into a preflight or claimed scientific root directly.

Before any numerical step, that object must pass the already declared live
identity and sign-orbit gates: exact state/order/DLL replay, `T(phi0)` identity,
full random-effect sign-operator invariance, live sign-orbit objective replay,
and the 22-coordinate chain-gradient finite-difference ledger.  A failure is
a typed estimator infrastructure HOLD, never a numerical
conclusion.  These checks are part of the future worker evidence; they do not
create a third gauge no-fit root.

The sign-orbit record is constructed from the actual full random-effect packing:
the conditional Hessian at the signed full state is compared with
`S^T Q S`, where `Q = obj$env$spHess(full, random = TRUE)` and `S` flips only
the second `g_spde_slope` LHS field and its corresponding GBIF fixed loading
column (raw positions 20--22).  The worker also compares
`obj$report(full)$eta` under that same full-vector sign operation and the
marginal objectives at the two signed fixed vectors.  It retains the exact
full/random axis names, sign indices, all three errors, and the field dimensions
`n_lhs_cols_spde_lat = 2`, `d_spde_slope = 1`; it does not infer this symmetry
from a single-field quadratic or from `cov.fixed`.

## Transformed Hessian: a numerical stability certificate

At `z=0`, retain the exact transformed gradient `Gz0 = D G(phi0)`.  For each
coordinate `j` and each multiplier `c` in `(1/2, 1, 2)`, set

\[
h_{cj}=c\,10^{-4}\max(1,|z_{0j}|)=c\,10^{-4},\qquad
H^{(c)}_{:j}=\frac{\widetilde G(h_{cj}e_j)-\widetilde G(-h_{cj}e_j)}{2h_{cj}}.
\]

The worker retains all 132 gradient evaluations in the fixed order
`scale -> coordinate 1:22 -> minus -> plus`, with raw and transformed
parameter vectors, exact gradient values, DLL/object identity, and the
original supplied gradient names.  It forms
`Hsym[c] = (H[c] + t(H[c])) / 2` only after checking raw finiteness and records
the raw relative antisymmetry

\[
\|H^{(c)}-H^{(c)\top}\|_F/\max(\|H^{(c)}\|_F,\sqrt\epsilon).
\]

The default model is `H = Hsym[1]`; it is accepted for trial construction only
when every scale is finite, every raw antisymmetry is at most `1e-6`, and both

\[
\max_{c\in\{1/2,2\}}
\frac{\|H^{(c)}-H\|_F}{\max(\|H\|_F,\sqrt\epsilon)}\le10^{-5}
\]

and the corresponding ordered-eigenvalue relative discrepancies are at most
`1e-5`.  These are a **three-scale finite-difference stability certificate**,
not a bound on the unobserved exact Hessian and not a claim of Weyl
certification.  Failure is `GAUGE_TRUST_REGION_CURVATURE_VALIDATION_HOLD`.

This construction is deliberately of the transformed exact gradient.  It
therefore includes the nonlinear map term
\(\sum_k g_{\theta,k}\nabla^2_\phi T_k\) without treating a raw covariance
inverse or a congruence transform alone as a transformed Hessian.

## One fixed shifted trust-region grid

Let `lambda_min` be the smallest eigenvalue of `H`, and let

\[
a=\max(1,\|H\|_2),\qquad
\mu_0=\max(10^{-8}a,-\lambda_{\min}+10^{-8}a),\qquad
\mu_k=2^k\mu_0\ (k=0,\ldots,5).
\]

For each `k`, solve

\[
q_k=-(H+\mu_kI)^{-1}G_{z0}.
\]

Every solve must be finite and have a positive-definite shifted matrix by
Cholesky; otherwise that candidate is retained as a deterministic rejection.
For radii

\[
\Delta\in(0.50,0.25,0.125,0.0625)
\]

in that order, construct

\[
d_{k,\Delta}=q_k\min(1,\Delta/\|q_k\|_2),\qquad
\phi_{k,\Delta}=\phi_0+Dd_{k,\Delta}.
\]

The complete order is shift `k=0:5`, then the four radii above: exactly 24
trial positions.  No trial changes a shift, radius, direction, step, callback
count, or future trial.  A trial outside the gauge domain is retained as a
domain rejection without evaluating the objective.

For every in-domain trial, retain the exact `F`, `G`, raw `fn/gr`, and the
unshifted quadratic prediction

\[
p_{k,\Delta}= -G_{z0}^{\top}d_{k,\Delta}
                -\tfrac12d_{k,\Delta}^{\top}Hd_{k,\Delta},\quad
\rho_{k,\Delta}=\{F(\phi_0)-F(\phi_{k,\Delta})\}/p_{k,\Delta}.
\]

`p`, actual reduction, and `rho` must be finite.  A trial passes its
objective/gradient gate exactly when `p > 0`,
`F(phi_trial) <= F(phi0) + 64*.Machine$double.eps*max(1, abs(F(phi0)))`,
`rho >= 0.10`, and the maximum absolute **raw** gradient is at most `1e-3`.
Only then does it call candidate-specific `sdreport` on the same worker object
and parameter vector.

Candidate covariance is assessed only in raw coordinates.  The raw
`par.fixed` names must be exactly the sealed 22-coordinate order.  Raw
`cov.fixed` must be finite 22-by-22.  Its raw row and column axes must either
both be absent or both be exactly the sealed order; mixed, partial, or
permuted axes are rejected before any relabelling.  The both-absent case is
canonicalised only through the already verified `par.fixed` positional map.
It must have relative asymmetry at most `1e-10`, then be symmetrised as
`Vsym=(V+t(V))/2`.  Cholesky,
eigenvalues, positive-definiteness, and the exact condition number
`max(eigen(Vsym))/min(eigen(Vsym))` are all calculated from `Vsym`; admission
requires `pdHess` exactly `TRUE`, all eigenvalues positive, and condition at
most `1e8`.

All 24 positions are retained unless an infrastructure failure occurs.  Among
trials passing every gate, select the largest actual reduction; ties within
`64*.Machine$double.eps*max(1, abs(F(phi0)))` break by earlier fixed grid
position.  This is a predeclared estimator rule, not post-hoc selection.  If
none pass, the terminal is
`GAUGE_TRUST_REGION_NO_ADMISSIBLE_CANDIDATE` and it earns no recovery or Paper
1 claim.

## Admission, terminal taxonomy, and bounded execution

The only numerical-admission terminal is
`GAUGE_TRUST_REGION_NUMERICAL_ADMISSION`.  It requires the complete identity,
sign-orbit, transformed-gradient, and Hessian evidence; all 24 trial records;
the selected candidate; and the candidate raw objective/gradient/covariance
gates above.  It is estimator-specific and cannot upgrade any MNCB/BFGS/no-fit
record.

The mutually exclusive non-admission terminals are:

| Terminal | Required evidence boundary |
| --- | --- |
| `GAUGE_TRUST_REGION_CURVATURE_VALIDATION_HOLD` | all completed identity/sign/gradient and 132-Hessian prefix records; no trial inference |
| `GAUGE_TRUST_REGION_NO_ADMISSIBLE_CANDIDATE` | complete 24-trial grid with no admitted candidate |
| `GAUGE_TRUST_REGION_INFRASTRUCTURE_HOLD` | typed process/DLL/factory/no-fit/domain/callback/release/manifest/time-limit failure with the exact completed prefix only; an out-of-domain trial is a retained deterministic rejection, not a terminal of its own |
| `GAUGE_TRUST_REGION_TERMINAL_EVIDENCE_HOLD` | materialised evidence fails independent schema/recomputation; it cannot relabel valid numerical evidence |

The terminal validator derives admission, curvature validation, and no-candidate
statuses from a retained trust-region result by independent replay.  A valid
numerical non-admission therefore retains its complete result and has
`infrastructure = TRUE, numerical = FALSE`; only process/callback/release
failures use `GAUGE_TRUST_REGION_INFRASTRUCTURE_HOLD` with either the exact
partial result or a typed null-result fallback.

Every reporting worker has one ordered receipt containing its parent/child PID
pair, start/end/elapsed fields, predecessor projection, state MD5, observed DLL
pair, created/released object counts, the retained no-fit replay, sign-orbit
evidence, trust-region result, callback audit, status/reason/stage, and error.
Early predecessor, DLL, and
factory failures retain no later evidence; a release failure may retain only
the completed sign/trust/audit prefix with `created = 1, released = 0`.  The
parent may not invent a full worker result from a killed or non-reporting child.

The parent enforces an 1800-second deadline using a supervised child process,
not only `setTimeLimit` in R.  It writes a same-directory temporary artifact,
atomically replaces each completed artifact, rereads the final root, recomputes
the full terminal status, and prints only after validation.  A hard crash may
leave a claimed unsealed root; it earns no terminal, retry, or numerical claim.
The terminal validator must call the same pure trust-region result
recomputation against the retained fixed start/callback evidence and reject a
non-identical result before it derives any status; checking a status label or a
selected covariance in isolation is insufficient.

The fresh root receipt binds the predecessor's complete V3 packet, current
runner/contract/design/map-helper/TMB-source hashes, the actual DLL path and
MD5, all controls in this document, child command/arguments/PIDs/exit boundary,
and all raw/transformed candidate evidence.  The initial inventory, claim-only
fallback, marker fallback, normal, and evidence-HOLD inventories must be
separately exact and tested for missing, extra, nested, non-regular, and
symlink artifacts.

The terminal ledger has the ordered fields `schema`, `gate`, `root`, `commit`,
`terminal`, `receipt`, `marker`, `worker`, `v3_live_child`, `processes`,
`predecessor`, `controls`, `trust_region`, `checks`, `status`, `reason`,
`error`, and `timing`; its checks are ordered `predecessor`,
`infrastructure`, `numerical`, and `terminal_evidence`.  The separate
`v3_live_child` and `processes` fields bind the clean predecessor-replay child
and both observed parent-child process boundaries.  A normal admission retains
non-NULL `worker` and `trust_region` evidence.  A typed infrastructure fallback
retains those names as actual NULL list slots—never deleted list components—so
the terminal validator can distinguish a deliberately incomplete prefix from
malformed evidence.

## Required implementation evidence before any smoke approval

1. Pure map/inverse/full-22 Jacobian/chain-gradient tests, including the
   quadratic transformed-Hessian harness and all fixed FD scale/order checks.
2. A compiled, no-outer-optimiser fixture establishing exact raw-gradient
   names, full sign-operator invariance, and the transformed live replay
   receipts.
3. Contract tests for every terminal, every partial prefix, covariance axes,
   candidate selection tie, source/receipt/manifest/process tampering, and
   disk-reread atomic lifecycle.
4. An independent mathematical and systems review of the implementation and
   terminal validator.
5. A time estimate immediately before execution.  The intended one-shot smoke
   is expected to be under 30 minutes, but the measured estimate—not this
   design—governs whether a further approval is needed.

The first admitted result, if any, may be considered for a separately approved
recovery calculation.  If this one attempt is infrastructure, curvature, or
numerical non-admission, the estimator closes: there is no V2 retune, retry, or
recovery under this design.
