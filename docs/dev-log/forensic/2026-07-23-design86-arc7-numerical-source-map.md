# Design 86 Arc 7 — bounded numerical source map

This note maps diagnostics to their limited interpretation. It supports no
novelty or public-method claim.

| Diagnostic | Source | Allowed interpretation | Excluded interpretation |
| --- | --- | --- | --- |
| TMB AD and `obj$he()` | [TMB Introduction](https://kaskr.github.io/adcomp/Introduction.html); [Kristensen et al. (2016)](https://www.jstatsoft.org/article/view/v070i05) | Agreement with stable central differences at a fixed q=2 point is local derivative QA. | Objective correctness, convergence, identifiability, or global optimality. |
| Termination telemetry | [R `nlminb`](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/nlminb.html); [R `optim`](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/optim.html) | Code, message, counts, recomputed physical gradient, and same target jointly describe a trace. | Code zero alone proves stationarity or success. |
| Stationary curvature | [Nocedal and Wright, *Numerical Optimization*](https://link.springer.com/book/10.1007/978-0-387-40065-5) | At a finite near-zero-gradient point, the Hessian is local curvature evidence. | A reference-point eigenvalue establishes a saddle, historical cause, or recovery. |
| Fixed-effect separation | [Albert and Anderson (1984)](https://doi.org/10.1093/biomet/71.1.1) | Separation needs a certificate on the actual fixed-effect design and outcomes; rank deficiency is separately reported. | A label, sparse outcomes, large coefficient, or latent objective behaviour proves separation. |
| Rays and profiles | [Venzon and Moolgavkar (1988)](https://doi.org/10.2307/2347496) | A fixed ray is a slice; a profile requires verified conditional stationary nuisance values. | A finite ray gives global coercivity or a profile interval. |

Arc 7 retains these sources only to delimit its deterministic diagnostic claims.
