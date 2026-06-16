# After Task: NB1 No-Latent Fitted-Object Parity

## Goal

Promote NB1 bridge evidence from fixed-parameter kernel identity to one
native-vs-Julia fitted-object parity cell, without overclaiming reduced-rank or
CI support.

## Implemented

Added a live Julia bridge test:

```text
engine = 'julia' NB1 no-latent fitted object matches native TMB objective
```

The test fits the same small NB1 fixture with `value ~ 0 + trait` through
`engine = "julia"` and `engine = "tmb"`, then checks class, labels, no-loading
shape, grouped `phi`, native convergence, `df`, log-likelihood, and `phi` scale.

The paired Julia runtime was updated in `GLLVM.jl-integration` so
`GLLVM.bridge_fit(..., d = 0)` is admitted and covered for grouped NB1.

## Mathematical Contract

For the no-latent NB1 fixture:

```text
eta_ti = beta_t
Var(y_ti) = mu_t * (1 + phi_t)
df = p beta values + p phi values = 4
```

Observed exploratory parity after the Julia admission edit:

```text
logLik_julia = -53.17549
logLik_tmb   = -53.17549
delta        = 4.253763e-08
max |phi_julia - phi_tmb| = 5.42191e-05
```

## Files Changed

R package:

- `tests/testthat/test-julia-bridge.R`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/2026-06-16-nb1-gamma-bridge-parameterisation-audit.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/coordination-board.md`
- `docs/dev-log/after-task/2026-06-16-nb1-no-latent-fitted-parity.md`
- `docs/dev-log/recovery-checkpoints/2026-06-16-093919-codex-checkpoint.md`

Paired Julia runtime:

- `../GLLVM.jl-integration/src/bridge.jl`
- `../GLLVM.jl-integration/test/test_bridge_grouped_dispersion.jl`
- `../GLLVM.jl-integration/docs/dev-log/check-log.md`
- `../GLLVM.jl-integration/docs/dev-log/after-task/2026-06-16-bridge-no-latent-nb1.md`

## Checks Run

- R rehydration:
  `git status --short --branch && git log --oneline -10`
  -> clean on `codex/r-bridge-grouped-dispersion`, tip `bc705bb`.
- Julia rehydration:
  `git -C ../GLLVM.jl-integration status --short --branch && git -C ../GLLVM.jl-integration log --oneline -5`
  -> clean on `codex/julia-per-trait-dispersion`, tip `2a07745` before edits.
- R pre-edit lane check:
  `gh pr list --state open --json number,title,headRefName,baseRefName,updatedAt,isDraft --limit 20`
  -> `[]`.
- Julia pre-edit lane check:
  `gh pr list --state open --json number,title,headRefName,baseRefName,updatedAt,isDraft --limit 20`
  -> older draft PRs `#95` and `#94`, no active branch collision.
- Julia targeted test:
  `julia --project=. test/test_bridge_grouped_dispersion.jl`
  -> `49/49 pass`.
- R targeted live bridge test:
  `GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration' JULIA_HOME='/Users/z3437171/.juliaup/bin' Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> completed cleanly.
- R targeted no-Julia bridge test:
  `GLLVM_JL_PATH='' JULIA_HOME='' Rscript --vanilla -e 'options(gllvmTMB.GLLVM.jl.path = NULL, gllvmTMB.julia_home = NULL); devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> completed cleanly with 6 expected Julia-runtime skips.
- Stale-claim scan:
  `rg -n "NB1.*full parity|full native parity|full parity|complete bridge|CRAN-ready bridge|NB1.*covered.*Julia|NB1 still needs fitted-object objective parity|NB1 stable no-X fitted-object fixture|Gamma.*native parity|native parity.*Gamma|Gamma.*covered.*Julia" tests/testthat/test-julia-bridge.R docs/design/35-validation-debt-register.md docs/dev-log/2026-06-16-nb1-gamma-bridge-parameterisation-audit.md docs/dev-log/check-log.md docs/dev-log/coordination-board.md docs/dev-log/after-task/2026-06-16-nb1-no-latent-fitted-parity.md docs/dev-log/after-task/2026-06-16-nb1-fixed-parameter-bridge-kernel.md`
  -> expected historical scan strings and negative-scope Gamma hits only.
- Whitespace:
  `git diff --check` -> clean.

## Tests Of The Tests

The new R test is a feature-combination and boundary test: it combines the
R bridge main dispatch, Julia `d = 0` admission, grouped NB1 dispersion, native
TMB comparison, and a no-latent lower-rank boundary. It would fail if the bridge
silently reintroduced a positive-rank requirement, changed NB1 `phi` scale,
dropped trait labels, or counted loading parameters in the no-latent row.

## Consistency Audit

`JUL-01` remains `partial`. The row now records no-latent NB1 fitted-object
parity, but not reduced-rank NB1 parity, grouped-dispersion CIs, masks,
non-Gaussian X, mixed families, structured terms, or broad post-fit extractor
parity.

AGENTS.md convention-change cascade is not triggered. No public function,
argument name, formula grammar, roxygen block, generated Rd, README, NEWS,
vignette, or pkgdown navigation file changed.

## What Did Not Go Smoothly

The intended R fixture first exposed a paired Julia bridge gate:
`bridge_fit()` rejected `d = 0` with `d must be a positive integer`. The inner
Julia grouped NB1 fitter already supported `K = 0`, so the fix belonged in the
Julia bridge admission gate, not in the NB1 likelihood.

## Team Learning

- Hopper: R no-latent rows need explicit Julia bridge admission, even when the
  underlying fitters already support `K = 0`.
- Karpinski: grouped NB1 `K = 0` has clean zero-column loading semantics.
- Gauss/Noether: NB1 is now checked at source-kernel and no-latent fitted-object
  levels on the same `phi` scale.
- Rose: keep the public status as `partial`; this is one strong cell, not a
  bridge-wide parity claim.

## Known Limitations

Reduced-rank (`K > 0`) NB1 fitted-object parity remains unpromoted. Gamma remains
route/shape evidence only until Ada chooses shared bridge grouping or native
per-trait Gamma expansion.

## Next Actions

1. Add reduced-rank NB1 fitted-object evidence with a stable tolerance.
2. Resolve the Gamma decision before any Gamma native-parity wording.
3. Keep grouped-dispersion CIs and masked grouped rows gated until their own
   status rows and tests exist.
