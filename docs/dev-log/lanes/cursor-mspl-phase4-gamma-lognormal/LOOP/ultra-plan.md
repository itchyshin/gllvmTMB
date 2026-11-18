# Ultra-plan (frozen) — Gamma(log) + lognormal(log) Phase-4-style prep

Binding detail for this lane. Not an admission plan.

## In

- Pure-R oracles for Gamma(log) and lognormal(log).
- Derivation notes under `docs/dev-log/research/`.
- Registry rows `status = "planned"`, `evidence = "phase4_prep"`,
  ordinary q=1 and q=2 only.
- Lane LOOP under `docs/dev-log/lanes/cursor-mspl-phase4-gamma-lognormal/LOOP/`.
- After-task + check-log. DRAFT PR.

## Out

- `admitted`
- NEWS covered
- `src/` tape
- `.gllvmTMB_mspl_prepare()` widen to family_id 3 or 4
- `R/fit-multi.R` SE withhold
- `R/mspl-curvature-pin.R`
- Poisson admit tests
- public `se=TRUE`
- repo-root `LOOP/`
- Dropbox
- shared worktree `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap`

## Science lock

- Gamma: \(W=\phi_{\gamma}\), mean-inert; not Poisson; not Tweedie \(p\to 2\).
- Lognormal: \(W=1/\sigma_{\varepsilon}^2\) on \(\log y\);
  \(\mathrm{E}[Y]=\mathrm{e}^{\eta+\sigma^2/2}\); shared `sigma_eps`
  is not a Gaussian Phase-3 transfer.
