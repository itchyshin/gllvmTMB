# Interval target ledger — rehydrated release packet

Date: 2026-08-25
Source: `git show codex/methods-superarc-plan:docs/dev-log/artifacts/methods-superarc/interval-target-ledger.md`

This copy makes the route evidence available on the execution branch. It
preserves the source ledger's core rule: an interval being callable is not
evidence that its repeated-sampling coverage is calibrated. Every campaign
must retain all outer attempts, count an interval failure inside an otherwise
eligible fit as a miss, report base-fit failures separately, and apply the
coverage rule to each frozen target and cell rather than to a pooled average.

## Current terminal boundaries

| CI row | Exact estimand or route | Evidence boundary before new campaigns | Terminal state |
| --- | --- | --- | --- |
| CI-08 | `V_t = Sigma_unit[t,t] = (Lambda Lambda^T)[t,t] + psi_t^2`; two-sided 95% LR profile on `log(V_t)` | Existing certificate is only Gaussian ordinary unit tier, `n_units=150`, `d=1/2`. Every other sample size, including 400, is route-only. | limited |
| CI-08 comparator | Same `V_t`, parametric percentile bootstrap | Available but not certified; excluded from PVT-02. | limited |
| CI-09 | Ordinary Gaussian pairwise `rho_12`, Fisher-z interval using realised `n_eff` | Dispatch and unavailable-`n_eff` guards exist; no coverage campaign. | limited |
| CI-10 | Mixed-family Sigma/correlation Wald route | Heuristic route only; nonlinear mixed-family profile remains withdrawn. | limited / blocked profile |
| CI-10 | Cross-family `multiple_r` bootstrap and contrast-correlation profile | Family-preserving plumbing exists; no promotional campaign. The two methods are not interchangeable. | limited |
| CI-11/12 | Nonlinear repeatability, communality, correlation, and proportion profiles | Typed public refusals; internal curves are regression machinery only. | refused |
| CI-13 | Confirmatory mapped-free standardized loading `Lambda[t,k] / sqrt(Sigma[t,t])` | Joint-delta algebra and routing exist; no repeated-sampling certificate. Pinned diagonal anchors are diagnostics, not promotional targets. | limited |
| CI-14 | Unique-Psi slope SD and separately labelled total marginal slope SD | One recovery cell, with every returned row marked uncalibrated; no campaign. | limited |
| CI-15 | Phylogenetic Cholesky marginal slope SD | One recovery cell; no campaign. | limited |
| CI-15 | Ordinary loadings-only marginal slope SD with `Psi=0` in DGP and fit | Route exists; the former positive-Psi fixture is a negative control, not recovery evidence. | limited |

## Frozen campaign extensions

- PVT-02: one Gaussian ordinary `d=2`, `n_units=400`, three-trait cell;
  traits 1 and 2 are separate promotional targets; 5,000 outer attempts.
- CI-09: two sample sizes by three interior correlations; 5,000 attempts per
  cell.
- CI-10: the retained 18-cell XFI grid; 5,000 attempts per cell and 499 inner
  bootstrap draws for `multiple_r`.
- CI-13: `n_units={150,400}` by `d={1,2}`; only lower-triangular coordinates
  left free after the confirmatory diagonal-anchor map are promotional.
- CI-14: `n_ind={50,100}` with six repeats; unique and total slope SDs remain
  separate targets.
- CI-15: phylogenetic Cholesky at `n_sp={70,140}` and ordinary loadings-only at
  `n_ind={100,200}`, both with six repeats.

For every promotional target, coverage and `coverage - 2 * clustered_MCSE`
must each be at least 0.94. Availability and all failure mechanisms are
reported but impose no additional promotion threshold. A result stays
`MEASURED, NOT CERTIFIED` until the independent review panel verifies its
estimand, retention ledger, reproducibility, and claim boundary.
