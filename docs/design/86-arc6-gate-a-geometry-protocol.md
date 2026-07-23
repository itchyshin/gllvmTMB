# Design 86 Arc 6 — Gate-A geometry protocol

**Status:** frozen controlled-diagnostic protocol; not a runner or amendment authority.

For the q=1 EVA block, write `lambda' = c lambda`, `a_i' = a_i/c`, and
`d_i' = d_i/c`, where `d_i = exp(log_A_diag_i)` and `c > 0`. This preserves
`lambda a_i` and `lambda^2 d_i^2`. Its per-unit KL term changes to

`0.5 * ((a_i^2 + d_i^2)/c^2 - 2 log(d_i/c) - 1)`.

It diverges as `c` tends to zero or infinity, so this path is not an unbounded
objective-preserving escape. Arc 6 tests that algebraic prediction numerically
on fixed, non-random Gate-1 binary arrays and separately screens those arrays
for response-geometry dependence.

The fixed scale grid is `10^seq(-3, 3, length.out = 13)`. At every point the
ledger records the TMB and scalar objective, AD gradient, central finite
differences at `1e-4`, `1e-5`, and `1e-6`, a raw/symmetrised Hessian summary,
and the ray directional derivative. The four-stage trace retains every stage,
message, count, parameter digest, and gradient digest.

The only candidate numerical change is a diagonal optimizer-coordinate map
formed from the absolute diagonal of the reference observed Hessian; it maps
exactly back to physical coordinates. It may support Gate-A `GO` only if every
ledger check passes, no response-geometry control establishes separation, and
the mapped preconditioned trace becomes healthy at the same target (`1e-8`).

Any coercive ray, response-geometry dependence, derivative failure, missing
ledger field, or failed reviewer verdict is `PARK`; sound but nondiscriminating
results are `INCONCLUSIVE`. Neither outcome authorizes V2 or a runner.
