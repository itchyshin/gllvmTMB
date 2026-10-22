# Continuous-scale canary pre-run receipt

Date: 2026-08-27
Candidate: `78530fcc78878a8c1234448f95dab11903dd92db` plus the leased working diff
Host: local macOS worktree
Authority: approved Ultra Plan; local work at or below 30 minutes

## Intended work

Run three small deterministic fits after the pure-logic GREEN gate:

1. pure Gaussian, retaining the historical length-one `log_sigma_eps` route;
2. pure lognormal, retaining the historical length-one route;
3. joint Gaussian + lognormal, using a raw-scale Gaussian slot and a log-scale
   lognormal slot with an ordinary rank-1 predictor-informed latent block.

The canary is route-health evidence, not a recovery or interval campaign.

## Estimate

Compilation is already complete through `devtools::load_all()`. Similar small
ordinary latent fits in this repository take seconds to low minutes. Estimated
wall time is 2--8 minutes total, with a hard stop at 30 minutes. No parallel
workers, remote host, or GitHub Actions science compute are involved.

## Correctness smoke

The run passes only if:

- all three optimizers return convergence code zero;
- every objective and gradient diagnostic is finite;
- pure fits report exactly one positive `sigma_eps` value;
- the joint fit reports exactly two positive values in Gaussian/lognormal order;
- the joint fit reports a finite rotation-invariant `B_lv_unit` payload; and
- the Gaussian and lognormal family CDF helpers select their matching slots.

Every failed attempt and the exact command will be retained. If the projection
or run exceeds 30 minutes, execution stops and a new approval receipt is needed.

## Attempts

### Attempt 1 — retained failure

Wall time: 10.66 seconds. Pure Gaussian and pure lognormal converged and the
joint fit reported two positive slots (`0.1786755`, `0.4863379`) plus finite
`B_lv_unit`, but the joint optimizer returned singular convergence. Diagnostic
replay showed the scale gradients were negligible while the two loadings were
near zero, `alpha_lv_B` was about 2,590, and the largest loading gradient was
8.38. The fixture had independent deterministic waves per trait and supplied no
shared innovation beyond `x`; it therefore invited the
`Lambda -> 0, alpha -> infinity` boundary. No engine code changed in response.

### Attempt 2 — fixture diagnosis

Wall time: 4.66 seconds. Exact joint replay confirmed convergence code 1,
objective 19.70793, `pdHess = TRUE`, and max gradient 8.375272. A component-wise
gradient replay confirmed the two `log_sigma_eps` gradients were below
`3e-6`; the defect was localized to the canary's latent DGP.

### Attempt 3 — passing route-health canary

The fixture was changed only to add a shared deterministic unit innovation to
`z = 0.7 x + e`, with separate within-family residual waves. Wall time was 9.21
seconds. All ten checks passed. Pure fits retained one scale each
(`0.1577515`, `0.3941278`); the joint fit converged and reported two positive
slots (`0.2722093`, `0.3159199`), finite `B_lv_unit`, and correct Gaussian and
lognormal CDF slot dispatch.
