# After Task: Animal response-column coefficients

**Branch**: `codex/structured-column-coef-family`  
**Date**: `2026-08-28`  
**Status**: IN PROGRESS — branch-start skeleton  
**Roles (engaged)**: Ada, Boole, Gauss, Noether, Curie, Emmy, Pat, Rose, Grace, Shannon

## 1. Goal

Admit public Gaussian `animal_coef()` response-column random intercepts and
slopes in long and `traits(...)` wide formats, while preserving the released,
warning-free `animal_slope()` API exactly.

## 2. Mathematical Contract

For response column `t` and unit `i`,

```text
y_it = x_it^T beta + z_i^T b_t + epsilon_it
B ~ MN(0, K_rho, Sigma_coef)
K_rho = rho A + (1-rho) diag(A),  0 <= rho <= 1
epsilon_it ~ N(0, sigma_e^2)
```

This is response-column coefficient covariance, not an observation-group
animal random effect and not residual covariance. The full symbolic alignment
is in `LOOP/animal-coef-alignment.md`.

## 3. Implemented

IN PROGRESS.

## 4. Files Changed

IN PROGRESS.

## 4a. Decisions And Rejected Alternatives

- **Decision**: V1 estimates `Sigma_coef` but accepts only fixed numeric animal
  source strength, default `rho = 1`.
- **Rationale**: this first proves the exact released animal-slope endpoint and
  fixed covariance-scale mixtures without adding a weakly identified parameter.
- **Rejected**: estimating `rho = NULL` in the first public animal slice.
- **Confidence**: high; estimated animal rho remains a separately testable slice.

## 5. Checks Run

IN PROGRESS.

## 6. Tests Of The Tests

IN PROGRESS. Every new behavior test will retain its pre-fix RED result.

## 7. Consistency Audit

IN PROGRESS.

## 8. Roadmap Tick

IN PROGRESS.

## 8a. GitHub Issue Ledger

IN PROGRESS.

## 9. What Did Not Go Smoothly

- The installed goal wrapper pointed to a missing `~/.codex/tools/lane_launch.sh`;
  the lane was created safely with the verified repository worktree machinery.
- The first lease attempt used an unsupported `--lane` option and changed no
  state; the supported `LANE_ID` identity then produced a live narrow lease.

## 10. Team Learning

IN PROGRESS.

## 11. Documentation And Pkgdown

IN PROGRESS.

## 12. Known Limitations And Next Actions

Estimated animal rho, interval inference, non-Gaussian coefficient models,
`kernel_coef()`, and `spatial_coef()` are outside this first serial arc.
