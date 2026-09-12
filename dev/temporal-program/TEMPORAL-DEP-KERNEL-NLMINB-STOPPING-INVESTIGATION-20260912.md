# Temporal dependent-kernel `nlminb` stopping investigation

The diagnostic replay retained `false convergence (8)` for both passes of the
frozen timing fixture. The first pass had maximum native gradient `.0004793725`;
the second pass made no material move. This proves the candidate failed its
*declared code-zero* acceptance rule. It does not prove a bad optimum or an
identified numerical defect.

The package's test setup documents that `nlminb`/PORT code 1 is a relative-
reduction stopping rule and can change with collation-dependent sparse
factorization ordering at essentially the same optimum. It specifically warns
that a code-zero requirement and a small-gradient recovery diagnostic answer
different questions. The temporal candidate also bundled strict controls,
including `rel.tol = 1e-14`, so the present evidence cannot identify a single
control as causal.

Consequently, no tolerance relaxation, scale change, budget increase, or
solver retry is justified by this result alone. A next temporal source-pair
contract must first decide whether its purpose is a public fit-health claim
(requiring code-zero and appropriate curvature evidence) or a bounded
fixed-DGP recovery diagnostic (which may use a separately justified,
platform-robust stationarity rule). It must state that distinction before any
new seeds or fits are chosen. The failed BFGS and `nlminb` campaigns remain
separate retained evidence.
