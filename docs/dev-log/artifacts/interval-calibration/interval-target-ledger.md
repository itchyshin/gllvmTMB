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
| CI-08 | `V_t = Sigma_unit[t,t] = (Lambda Lambda^T)[t,t] + psi_t^2`; intended two-sided 95% LR profile on `log(V_t)` | The historical `n_units=150,d=1/2` and PVT-02 `n_units=400,d=2` cells passed their numerical gates, but all use the same penalty-profile mechanism and none retains endpoint evidence sufficient to verify constrained-refit convergence and exact target attainment. | limited everywhere; former exact-cell certificates withdrawn fail-closed |
| CI-08 comparator | Same `V_t`, parametric percentile bootstrap | Available but not certified; excluded from PVT-02. | limited |
| CI-09 | Ordinary Gaussian pairwise `rho_12`, Fisher-z interval using realised `n_eff` | The six-cell campaign retained every row but used one pair per site while fitting both `Sigma_B` and free Gaussian `sigma_eps^2`. The scored unit-tier `rho_B` is not identified from the planted total covariance. | blocked -- DGP/estimand identifiability |
| CI-10 | Mixed-family Sigma/correlation Wald route | Heuristic route only; nonlinear mixed-family profile remains withdrawn. | limited / blocked profile |
| CI-10 | Cross-family `multiple_r` bootstrap and contrast-correlation profile | Family-preserving plumbing exists. All 18 approved cost-preflight base fits failed before the 499-bootstrap stage, so successful nested-bootstrap cost remains unmeasured and no promotional campaign ran. The two methods are not interchangeable. | limited; full campaign blocked |
| CI-11/12 | Nonlinear repeatability, communality, correlation, and proportion profiles | Typed public refusals; internal curves are regression machinery only. | refused |
| CI-13 | Confirmatory mapped-free standardized loading `Lambda[t,k] / sqrt(Sigma[t,t])` | All structurally free strict-lower targets in `n=150,d=1` failed the lower-band gate. Every such target in `n=150,d=2`, `n=400,d=1`, and `n=400,d=2` passed and cleared the independent D-43 panel. These are symmetric joint-delta Wald intervals in native, pinned, unrotated lower-triangular cells only; pinned diagnostic rows are not promotional targets. | three exact cells certified; limited globally |
| CI-14 | Unique-Psi slope SD and separately labelled total marginal slope SD | The corrected exact manifest retained 10,000 source-guard failures and zero scientific rows. | blocked -- source provenance |
| CI-15 | Phylogenetic Cholesky marginal slope SD | The corrected sequence stopped after CI-14; CI-15 did not run. | blocked -- predecessor |
| CI-15 | Ordinary loadings-only marginal slope SD with `Psi=0` in DGP and fit | The corrected sequence stopped after CI-14; CI-15 did not run. The former positive-Psi fixture remains a negative control, not recovery evidence. | blocked -- predecessor |

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

## 2026-08-25 terminal review findings

The full retained evidence is in `2026-08-25-terminal-campaign-evidence.md`,
with 150,019 operational rows in `2026-08-25-all-attempt-ledger.csv.gz` and 18
recomputed target rows in `2026-08-25-target-recomputation.csv`.

- PVT-02's target identity, lower-triangular reconstruction, `psi^2`
  transform, coverage, MCSE, and all-target arithmetic are correct. Promotion
  is nevertheless blocked because the production scalar penalty profile can
  accept a non-converged constrained refit, allows a 0.05 discrepancy on the
  requested `log(V_t)`, and can interpolate after failed refits. The retained
  payload lacks the diagnostics needed to remove or rescore those endpoints.
- CI-09's flattening, seed map, and realised `n_eff` plumbing are correct. Its
  campaign design is not: one pair per site identifies
  `Sigma_B + sigma_eps^2 I`, whereas the scored extractor reports the
  correlation of `Sigma_B`. The extreme retained coverage is therefore
  invalid calibration evidence, not a clean Fisher-z failure.
- CI-13's native standardized-loading estimand, full joint-delta gradient, and
  replicate-clustered MCSE passed mathematical review for the structurally
  free strict-lower targets. Pinned anchor rows remain diagnostic. Cell-specific
  results remain separate; no Fisher-z Wald, arbitrary constraint, rotated,
  unconstrained, or neighbouring cell inherits them. The independent D-43
  panel certified exactly `(n=150,d=2)`,
  `(n=400,d=1)`, and `(n=400,d=2)`; `(n=150,d=1)` remains a measured failure.
- CI-14 and CI-15 are terminal operational blocks, not coverage failures.
