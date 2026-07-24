# Design 91 — row-support-conditioned upstream EVA/VA envelope

## Purpose and boundary

Design 91 asks a deliberately new, upstream-only question: for ordinary
Bernoulli-logit GLLVMs with latent rank two, is released `gllvm` numerically
healthy under each requested approximation when the realised response matrix is
conditioned to contain both outcomes in every row and every trait?  The paired
methods are `method = "EVA"` and `method = "VA"`.

This is not a retry, amendment, rescore, or diagnosis of Design 90.  Design 90
remains immutable evidence for its unconditional, lower-support grid.  The
conditioning here changes the estimand: the target is the explicitly named
row-and-trait-support-conditioned generator, not unconditional Bernoulli
sampling.  No Design 86--90 input, seed, runner, threshold, output, or result
is evidence for this design.

Neither arm is a correctness oracle.  EVA and VA have different variational
objectives, so raw objectives, loadings, and latent scores are not compared.
VA is a diagnostic companion only: an EVA failure with a healthy VA receipt
supports an approximation-specific numerical observation for that frozen
fixture; two failures are unresolved shared evidence; a healthy EVA receipt is
not rescued or invalidated by VA.

This packet makes no gllvmTMB, parity, recovery, calibration, coverage,
performance, public API, C++, structured-prior, or release claim.

## Frozen mathematical contract

For a cell \((n,T,p,s,\rho)\), generate independent latent rows

\[
U_i \sim N_2(0,R_\rho), \qquad
R_\rho = \begin{pmatrix}1&\rho\\\rho&1\end{pmatrix},
\]

and, conditional on \(U_i\), generate

\[
Y_{it}\sim\operatorname{Bernoulli}\{\operatorname{logit}^{-1}(b_t+
\lambda_t^\top U_i)\}.
\]

`lambda` has rank two with its first two rows `(s, 0)` and `(0, s)`; later
rows follow deterministic evenly spaced unit-circle directions.  Each `b_t`
is solved using deterministic two-dimensional Gaussian quadrature so that
\(E(Y_{it})=p\); `qlogis(p)` alone is not an admissible intercept.

The candidate is accepted only when every row and every trait has at least one
zero and one one.  Rejected draw seeds and reasons are retained.  This is
rejection sampling conditional on support, not post-fit selection.

The fixed grid is

\[
n\in\{60,120,240\},\quad T\in\{30,60\},\quad
p\in\{.25,.50\},\quad s\in\{.35,.70\},\quad \rho\in\{0,.5\}.
\]

There are 48 fixtures.  The future atlas would use 16 fresh initialization
seeds per fixture and method (1,536 attempted fits), subject to the ten-hour
Totoro ceiling.  This is not authorization to run it.

## Gate 0/1 implementation status

Gate 0 and Gate 1 create only the independent source lock, immutable config,
producer, telemetry schema, method-paired non-overwrite runner, and empty
result roots.  The smoke driver requires `D91_AUTHORIZE_SMOKE=YES`; no fixture
is materialised and no model is fitted until the maintainer explicitly opens
Gate 2.

Health is newly declared, although its gradient tolerance deliberately matches
the released upstream `gradient.check` warning convention: logical
`convergence == TRUE`, finite objective/parameters/gradient, no warning or
error, and raw `max(abs(gradient)) <= 0.05`.  Hessian availability and
conditioning are telemetry, not universal acceptance criteria.

Any source-lock mismatch, malformed support-conditioned fixture, missing
receipt field, forbidden output overwrite, smoke error/warning/nonconvergence,
or health breach stops the relevant gate.  No later run may alter a stopped
fixture, seed, method control, or threshold.

## Gate 2 result — terminal paired-smoke stop

The four predeclared support-conditioned fixtures completed on Totoro, yielding
eight immutable method-labelled receipts.  Every fixture passed the row and
trait support checks without a rejected candidate draw.  The all-healthy smoke
criterion nevertheless failed: EVA was healthy in 2/4 attempts and VA was
healthy in 2/4 attempts.  The frozen 10-hour atlas is not launched.

The paired outcomes are observational only.  On `n060_t30_p25_s35_r00`, EVA
returned `convergence = FALSE`, a prohibited maximum-iterations warning, and
raw gradient 9.2998, while VA was healthy (0.0107).  On
`n060_t60_p50_s35_r50`, both methods were unhealthy by gradient (EVA 6.7994;
VA 0.9509).  On `n240_t30_p25_s70_r00`, EVA was healthy (0.0321) and VA was
unhealthy (0.2642).  Both were healthy on `n240_t60_p50_s70_r50` (EVA 0.0263;
VA 0.0223).  These facts do not establish a cause, comparative accuracy, or
general reliability of either approximation.

Design 91 therefore closes as a terminal private smoke stop.  The only durable
next step would be a separately approved research design with a new estimand,
new fixtures, source lock, and stop rule; it cannot alter or rescore this one.
