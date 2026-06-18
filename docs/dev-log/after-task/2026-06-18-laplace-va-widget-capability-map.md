# After-task report -- Laplace / VA widget capability map

Date: 2026-06-18 13:52 MDT
Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

The task was to answer whether Laplace and variational approximation (VA) are
current or planned across the R and Julia halves of the GLLVM twin, and to add
that capability/gap map to the local mission-control widget.

This was a dashboard/evidence update only. No package code, likelihood code,
formula grammar, roxygen, pkgdown article source, or GitHub issue/PR state was
mutated.

## Evidence

- `gllvmTMB` currently has the production TMB Laplace estimator route for
  latent/random-effect models. That is estimator evidence, not an all-family
  scientific coverage claim.
- `gllvmTMB` VA remains parked in
  `docs/design/72-variational-approximation-feasibility.md`: Phase 1 was a
  separate-DLL prototype and no production `method = "VA"` API is merged.
- Current `GLLVM.jl` documents exact Gaussian fits, Laplace one-part
  non-Gaussian fits for Binomial, Poisson, NegativeBinomial, Beta, Ordinal, and
  Gamma, plus dedicated two-part Laplace fitters for Delta-lognormal,
  Hurdle-Poisson, and Hurdle-NB.
- Current `GLLVM.jl` source exposes no production VA/ELBO estimator.
- `gllvm_julia_capabilities()` confirms the R bridge remains partial by family
  and feature surface, especially for mixed-family, ordinal CI/residual/simulate,
  masks, fixed-effect X, CI payloads, and richer extractor parity.

## Files changed

- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-18-laplace-va-widget-capability-map.md`

## Review roles

- Ada: kept the active goal and guard intact.
- Rose: prevented Laplace estimator evidence from becoming a broad coverage
  claim.
- Grace: mapped the bridge and widget evidence without mutating GitHub state.
- Fisher: kept VA and interval/coverage claims gated.
- Boole: kept method-surface language separate from formula/API claims.

## Not done

- No production VA implementation was added.
- No `GLLVM.jl` #101 mutation was made.
- No bridge, release, or scientific-coverage gate was closed.
- No public article or pkgdown navigation was changed.

## Verification

- JSON validation with `python3 -m json.tool` on the two dashboard files.
- `git diff --check`.

Both checks passed before commit.
