# COE-04 near-orthogonal recovery slice

Date: 2026-06-18 11:06 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

This slice advances the Paper 2 coevolution model from "fixed latent-only
two-component extraction works" toward recovery evidence. It does not finish
Paper 2 scientific coverage.

The implemented gate is deliberately narrow:

- two named latent-only dense kernels over the same species level set;
- a predeclared off-diagonal Frobenius-style kernel-similarity diagnostic;
- a near-orthogonal Gaussian DGP;
- component-specific `Gamma_shape` recovery through `extract_Gamma()`;
- one-component log-likelihood checks.

The Paper 2 path remains latent-only. Explicit `kernel_unique()` / `*_unique()`
Psi stays compatibility syntax outside this multi-kernel recovery gate and
should move to post-arc lifecycle/deprecation planning.

## Files changed

- `tests/testthat/test-coevolution-two-kernel.R`
- `NEWS.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/65-cross-lineage-coevolution-kernel.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## Evidence

`COE-04` moved from `blocked` to `partial`.

The new heavy DGP fits:

```r
kernel_latent(species, K = K_phy, d = 1, name = "phy") +
kernel_latent(species, K = K_non, d = 1, name = "non")
```

Evidence:

- kernel overlap diagnostic classifies the DGP as `near_orthogonal`;
- full two-component model beats either one-component model by >50 log-likelihood units;
- `extract_Gamma(level = "phy")` recovers `Gamma_shape_phy` with correlation >0.95;
- `extract_Gamma(level = "non")` recovers `Gamma_shape_non` with correlation >0.95;
- neither component matches the other component's truth.

## Commands run

- `/opt/homebrew/bin/gh pr list --state open`
  -> only draft PR #489 open.
- `git log --all --oneline --since="6 hours ago"`
  -> recent commits were current mission-control/article/kernel commits.
- Exploratory checkout-loaded R run over seeds 2001..2005
  -> all converged; component-specific `Gamma_shape` recovery stable.
- `/usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  -> `FAIL 0 | WARN 0 | SKIP 2 | PASS 28`.
- `GLLVMTMB_HEAVY_TESTS=1 /usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 41`.
- `/usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution")'`
  -> `FAIL 0 | WARN 0 | SKIP 5 | PASS 114`.
- `GLLVMTMB_HEAVY_TESTS=1 /usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 150`.

## Review perspectives

Boole: formula grammar stayed within the existing `kernel_latent()` surface.
No `kernel_unique()` teaching or new Psi grammar was added to the Paper 2
multi-kernel path.

Gauss / Noether: no new TMB likelihood parameterisation was added in this
slice; the test exercises the already-landed fixed multi-kernel latent block.

Fisher / Curie: the first recovery gate is real but narrow. The row is partial
because the ADEMP grid still needs moderate/high overlap, selective absence,
null calibration, `rho`, and intervals.

Rose: the dashboard, NEWS, Design 65, validation register, and check-log all
carry the same guard: this is evidence progress, not scientific coverage or
release readiness.

## Still open

- Moderate-overlap component recovery.
- High-overlap failure language and user-facing diagnostic behavior.
- Block-null and selective-absence calibration.
- `rho` profiling or estimation.
- Interval coverage.
- Mixed/non-Gaussian coevolution gates.
- Explicit Psi grammar redesign and `*_unique()` lifecycle/deprecation arc.
- Bridge completion, release readiness, and scientific coverage completion.
