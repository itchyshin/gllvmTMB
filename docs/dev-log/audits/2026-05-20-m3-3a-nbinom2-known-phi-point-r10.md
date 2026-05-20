# M3.3a `nbinom2` Known-Phi Point Diagnostic

Date: 2026-05-20  
Branch: `codex/m3-3a-nbinom2-known-phi-diagnostic-2026-05-20`  
Artifact: `/tmp/gllvmtmb-m3-3a-known-phi-point-r10/nbinom2-known-phi-point-r10.rds`

## Purpose

The corrected r20/b20 stress grid showed that the M3 primary target,
`Sigma_unit_diag = diag(Lambda Lambda^T + Psi)`, is underestimated for
`nbinom2` even after the target scale was fixed. The fitted-diagnostic
lane then showed fitted `phi_nbinom2` was often below truth, inflating
the theoretical link-residual increment and making response-scale
summaries diverge from the latent+unique target.

This audit asks a narrower question: if `log_phi_nbinom2` is fixed at
the known DGP value in the point fit, does the fitted latent+unique
`Sigma_unit_diag` move toward truth?

## Method

The dev-grid now supports `fit_phi_mode = "estimated"` and
`fit_phi_mode = "known"` for `family = "nbinom2"`. The known-phi mode is
a development diagnostic only: it rebuilds the TMB object from the
ordinary fit, maps `log_phi_nbinom2` off, fixes it at the DGP value, and
re-optimizes the remaining parameters. It does not change the public
`gllvmTMB()` API.

Bootstrap was intentionally disabled with `n_boot = 0`. Current
`bootstrap_Sigma()` refits through the ordinary public API, so a
known-phi point fit would otherwise get estimated-phi bootstrap refits.
This audit therefore interprets point-estimate ratios only, not
coverage or `pilot_status`.

Settings:

- `family = "nbinom2"`, `d = 1`, `n_traits = 5`
- `n_reps = 10` per scenario and fit mode
- `targets = "Sigma_unit_diag"`, `link_residual = "none"`
- `init_strategy = "single_trait_warmup"`
- `start_method = list(method = "res", jitter.sd = 0.2)`
- `optimizer = "optim"`, `optArgs = list(method = "BFGS")`
- `n_init = 3`, `init_jitter = 0.05`, `se = FALSE`
- `n_boot = 0` point-estimate-only diagnostic

## Results

| Scenario | Fit `phi` mode | Fits | Median estimate/truth | Median fitted phi/truth | Median fitted link residual | Median max gradient |
|---|---:|---:|---:|---:|---:|---:|
| `baseline_phi1_n60` | estimated | 10/10 | 0.557 | 0.596 | 3.682 | 0.000289 |
| `baseline_phi1_n60` | known | 10/10 | 0.697 | 1.000 | 1.645 | 0.000372 |
| `lowphi_n120` | estimated | 10/10 | 0.649 | 0.932 | 30.100 | 0.000486 |
| `lowphi_n120` | known | 10/10 | 0.856 | 1.000 | 26.267 | 0.000231 |
| `weakvar_phi1_n60` | estimated | 10/10 | 0.701 | 0.737 | 2.614 | 0.001649 |
| `weakvar_phi1_n60` | known | 10/10 | 0.942 | 1.000 | 1.645 | 0.000749 |

## Interpretation

Fixing `phi_nbinom2` at its known DGP value materially improves the
latent+unique `Sigma_unit_diag` point estimates:

- baseline: 0.557 -> 0.697 median estimate/truth;
- low-dispersion: 0.649 -> 0.856;
- weak latent+unique variance: 0.701 -> 0.942.

This means NB2 dispersion estimation is a major contributor to the
M3.3a underestimation pattern. It is not the only contributor: the
baseline scenario remains below truth even with known `phi`. The weak
variance scenario looks close to unbiased under known `phi`, so the next
modeling slice should focus on the interaction between NB2 dispersion,
latent+unique variance scale, and the unit-tier covariance estimate
before another expensive bootstrap coverage grid.

Scope status remains unchanged:

- EXT-13: partial
- CI-08: partial
- CI-10: partial

This is point-estimate evidence only; it does not repair the coverage
claim.
