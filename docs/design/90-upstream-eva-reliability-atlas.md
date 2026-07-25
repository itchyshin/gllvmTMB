# Design 90 — upstream EVA reliability atlas

## Gate-0 decision

The target is the released ordinary `gllvm` EVA path:
`gllvm(Y, family = "binomial", link = "logit", method = "EVA", num.lv = 2,
num.lv.c = 0)`.  CRAN `gllvm` 2.0.13 exposes `num.lv` as the unconstrained
latent rank, passes `EVA` as TMB method code 2, and its C++ template builds the
unconstrained q=2 loading block.  The constrained `num.lv.c = 2` path is
excluded: upstream directly regression-tests only its q=1 EVA form.

This is an upstream health atlas.  It is not a gllvmTMB objective, parity,
recovery, calibration, or package-integration design.

## Gate-1 frozen contract

The prospective atlas has 72 cells:

\[
n \in \{60,120,240\},\quad T \in \{12,30\},\quad
p \in \{0.10,0.25,0.50\},\quad s \in \{0.35,0.70\},\quad
\rho \in \{0,0.5\}.
\]

For every cell, (U_i \sim N_2(0,R_\rho)), where
\(R_\rho = [[1,\rho],[\rho,1]]\), and
\(Y_{it}\sim\operatorname{Bernoulli}(\operatorname{logit}^{-1}(b_t+
\lambda_t^T U_i))\).  The q=2 loading matrix has fixed lower-triangular
orientation: its first two rows are `(s, 0)` and `(0, s)`; later rows use a
deterministic evenly-spaced unit-circle direction times `s`.  Each intercept
is solved by deterministic two-dimensional Gaussian quadrature so the
* marginal* probability is `p`; `qlogis(p)` alone is prohibited.

There are 16 predeclared gllvm start seeds per cell (1,152 attempts).  The DGP
seed, response ordering, generator rejection count, `gllvm` controls, source
and binary hashes, realised input hash, messages, warnings, raw convergence
value/type, raw TMB gradient, finite-field flags, elapsed time, and health
classification are mandatory telemetry.  The target uses only trait
intercepts, so every realised matrix must have both outcomes in every trait;
otherwise it is recorded `SEPARATION_EXCLUDED` and never fitted.  Rejection is
part of the frozen generator, never a post-hoc selection.

`HEALTHY` requires logical `fit$convergence == TRUE`, finite objective,
parameters, and raw gradient, no warning/error, and `max(abs(gradient)) <=
0.05`.  Hessian status is telemetry, not a universal requirement.  Per-cell
labels are `HEALTHY_16_OF_16`, `MIXED_HEALTH_k_OF_16`, and
`UNHEALTHY_0_OF_16`; they do not support recovery, accuracy, calibration, or
cross-package claims.

## Gate-1 checkpoint and deferred compute

No fixture has been generated and no gllvm fit has been run.  Gate 1 freezes
the contract, source lock, and empty non-overwrite output root only.  A
maintainer checkpoint is required before the four-cell Totoro smoke and the
maximum 64-core / 10-hour atlas.  Any failed source lock, malformed fixture,
missing telemetry, smoke failure, or health breach stops the relevant gate;
there is no retry by changing starts, seeds, controls, thresholds, or inputs.

Designs 86--89 are quarantined references only.  This design modifies no
gllvmTMB package code, API, C++, documentation, or public claim.

## Gate-2 result — terminal smoke stop

The four predeclared Totoro smoke attempts completed on the locked source and
all returned logical `convergence = TRUE`.  None was healthy under the frozen
contract.  Three received the prohibited `There are rows full of zeros in y`
warning; their maximum absolute gradients were 0.002283541, 0.455567475, and
1.252887510.  The fourth had no warning but `max(abs(gradient)) = 54.348989836`.
The 10-hour campaign is therefore not run.

This is a Design-90 smoke result, not a diagnosis of EVA, an explanation of
Designs 86--89, or evidence about gllvmTMB.  The all-zero-row warning exposes
a missing *row*-support predicate in the prospective fixture contract; it may
be considered only in a separately approved new design with new fixtures and
new evidence, never by modifying or rescoring this packet.
