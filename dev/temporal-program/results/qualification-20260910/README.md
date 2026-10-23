# Temporal-phylogenetic optimizer qualification: fixed-fixture pre-runs

These files retain every output from the fixed-fixture pre-runs for the
post-campaign optimizer qualification. They are diagnostic evidence only; they
are neither a replacement for Fir job `59096255` nor recovery evidence.

| Receipt | Code state | Result |
|---|---|---|
| `local-phi0-seed2609188-c9a185414-runsqrt-eps.rds` | committed `c9a185414`; finite-difference step `sqrt(eps)` | Fit completed in 69.1 seconds. Fresh-state checks passed, but finite-difference cancellation was about 0.05, so this step was not usable. |
| `local-phi0-seed2609188-uncommitted-step1e-5.rds` | source reported `c9a185414`, but the worktree contained an uncommitted `1e-5` step repair | Retained for completeness only. Its recorded commit is not an exact source identifier and it must not support a claim. |
| `local-phi0-seed2609188-19756f2a-step1e-5.rds` | committed `19756f2a5`; finite-difference step `1e-5` | Fit completed in 68.2 seconds; both fresh-state checks passed and finite-difference errors were `2.47e-5` and `3.82e-5`. The local final gradient was `1.37e-4`, unlike Fir's retained `1.61e-3` for this seed. This is a platform/runtime difference to investigate, not an improved recovery result. |
| `fir-59103979-phi0-seed2609188-19756f2a-step1e-5.rds` | Fir job `59103979`, isolated R 4.5.0 runtime built in job `59103778`, committed `19756f2a5`; finite-difference step `1e-5` | Fit completed in 14.6 seconds with the same final objective and convergence zero as the local receipt. Both fresh-state checks passed and finite-difference errors were `5.24e-5` and `5.47e-5`; its final gradient was `1.61452497e-3`, reproducing the original Fir campaign's failing gradient for this fixture. |

All three receipts regenerate `phi = 0`, `seed = 2609188` through the frozen
DGP. They retain the DGP data, covariance, control, labelled pass histories,
and final outer coordinates. The stable 68.2-second measurement estimates a
six-fixture diagnostic replay at about seven minutes on this host, below the
30-minute compute approval threshold. The exact-source Fir replay shows that
the local/Fir gradient difference survives a clean isolated source build and
identical DGP, control, objective, and terminal fit. It does not by itself
identify the platform-level numerical cause or change the frozen strict gate.
