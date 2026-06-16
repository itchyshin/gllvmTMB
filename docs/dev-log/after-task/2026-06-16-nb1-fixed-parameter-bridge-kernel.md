# After Task: NB1 Fixed-Parameter Bridge Kernel Evidence

## Goal

Add the first objective NB1 bridge evidence below fitted-object parity: a
fixed-parameter likelihood identity that proves Julia grouped NB1 uses the
native linear-variance kernel.

## Implemented

Added a live Julia test to `tests/testthat/test-julia-bridge.R`:

```text
NB1 grouped likelihood matches the native linear-variance kernel at fixed parameters
```

The test calls `GLLVM.nb1_grouped_marginal_loglik_laplace()` directly with zero
loadings and compares it to the R/native NB1 kernel
`stats::dnbinom(mu = mu, size = mu / phi, log = TRUE)`.

Updated `JUL-01`, the NB1/Gamma audit, the coordination board, the check-log,
and a recovery checkpoint to record that this is kernel evidence, not
fitted-object parity.

## Mathematical Contract

For NB1:

```text
Var(y) = mu * (1 + phi)
size   = mu / phi
```

With zero loadings, the Julia Laplace likelihood has no latent contribution and
should equal the independent NB1 observation likelihood. The test uses two
traits, four units, per-trait `beta`, and per-trait `phi`, then compares Julia
against the native linear-variance kernel to `1e-10`.

## Files Changed

- `tests/testthat/test-julia-bridge.R`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/2026-06-16-nb1-gamma-bridge-parameterisation-audit.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/coordination-board.md`
- `docs/dev-log/recovery-checkpoints/2026-06-16-091743-codex-checkpoint.md`
- `docs/dev-log/after-task/2026-06-16-nb1-fixed-parameter-bridge-kernel.md`

## Checks Run

- Rehydration:
  `git status --short --branch && git log --oneline -8`
  -> clean on `codex/r-bridge-grouped-dispersion`, tip `1e7e3c4`.
  `git -C ../GLLVM.jl-integration status --short --branch && git -C ../GLLVM.jl-integration log --oneline -8`
  -> clean on `codex/julia-per-trait-dispersion`, tip `2a07745`.
- Pre-edit lane check:
  `gh pr list --state open --limit 30 --json number,title,headRefName,updatedAt,isDraft,mergeable,url`
  -> `[]`.
  `git log --all --oneline --since="6 hours ago" -- tests/testthat/test-julia-bridge.R docs/design/35-validation-debt-register.md docs/dev-log/check-log.md docs/dev-log/after-task docs/dev-log/recovery-checkpoints docs/dev-log/coordination-board.md R/julia-bridge.R src/gllvmTMB.cpp`
  -> current Codex programme commits only.
- Exploratory fixed-parameter check:
  `GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration' JULIA_HOME='/Users/z3437171/.juliaup/bin' Rscript --vanilla - <<'RS' ...`
  -> `delta = -7.105427e-15`.
- Targeted live bridge test:
  `GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration' JULIA_HOME='/Users/z3437171/.juliaup/bin' Rscript --vanilla -e 'devtools::test(filter = "julia-bridge")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 178` in 30.9 s.

- Targeted no-Julia bridge test:
  `GLLVM_JL_PATH='' JULIA_HOME='' Rscript --vanilla -e 'options(gllvmTMB.GLLVM.jl.path = NULL, gllvmTMB.julia_home = NULL); devtools::test(filter = "julia-bridge")'`
  -> `FAIL 0 | WARN 0 | SKIP 5 | PASS 59` in 5.2 s.
- Stale-claim scans:
  `rg -n "NB1.*full parity|full native parity|full parity|complete bridge|CRAN-ready bridge|NB1.*covered.*Julia|NB1.*fitted-object parity|Gamma.*native parity|native parity.*Gamma|Gamma.*covered.*Julia" R/julia-bridge.R tests/testthat/test-julia-bridge.R docs/design/35-validation-debt-register.md docs/dev-log/2026-06-16-nb1-gamma-bridge-parameterisation-audit.md docs/dev-log/check-log.md docs/dev-log/coordination-board.md docs/dev-log/after-task/2026-06-16-nb1-fixed-parameter-bridge-kernel.md`
  -> expected negative-scope and scan-history hits only.
  `rg -n "nb1_grouped_marginal_loglik_laplace|dnbinom\\(|mu / phi|phi_nbinom1|sigma_eps|alpha_t|Gamma|NB1" tests/testthat/test-julia-bridge.R docs/design/35-validation-debt-register.md docs/dev-log/2026-06-16-nb1-gamma-bridge-parameterisation-audit.md docs/dev-log/check-log.md docs/dev-log/after-task/2026-06-16-nb1-fixed-parameter-bridge-kernel.md | head -180`
  -> expected NB1 kernel and Gamma boundary hits.
- Whitespace:
  `git diff --check` -> clean.

Deliberately not run:

- Full `devtools::test()`, `devtools::check()`, `devtools::document()`,
  `pkgdown::check_pkgdown()`, and article renders. This slice changes one
  targeted bridge test plus validation/dev-log prose; no roxygen, NAMESPACE,
  generated Rd, README, NEWS, vignette, or pkgdown navigation file changed.

## Tests Of The Tests

This is a likelihood cross-check against an independent calculation, not merely
a route smoke. It would fail if Julia used an NB2-style reciprocal scale, treated
`phi` as size, dropped per-trait `phi`, or changed the zero-loading Laplace
calculation away from the independent NB1 likelihood.

## Consistency Audit

`JUL-01` remains `partial`: NB1 now has route/shape evidence and fixed-parameter
kernel evidence, but fitted-object objective parity is not yet proven. Gamma
remains a separate decision because native ordinary Gamma uses shared
`sigma_eps`.

AGENTS.md convention-change cascade is not triggered. No public function,
argument, formula grammar, roxygen, generated Rd, README, NEWS, vignette, or
pkgdown navigation file changed.

## What Did Not Go Smoothly

The first Julia expression used during editing was built with `paste()`, which
could insert whitespace before the function call parenthesis. It was corrected
to `paste0()` before tests ran.

## Team Learning

- Gauss/Noether: NB1's fixed-parameter kernel is aligned; optimizer/Laplace fit
  parity is now the remaining question.
- Curie: direct likelihood checks are the right depth between route smoke and
  fitted-object parity.
- Rose: the validation row now separates kernel evidence from fitted parity.
- Hopper/Karpinski: the bridge can keep NB1 grouped `phi` routing while the next
  fixture targets fitted-object evidence.

## Known Limitations

This test does not prove native-vs-Julia fitted-object log-likelihood parity.
It fixes the scale/kernel question only.

## Next Actions

1. Build a stable NB1 no-X fitted-object fixture and record a defensible
   tolerance.
2. Keep Gamma out of native parity wording until Ada chooses shared bridge
   grouping or native per-trait Gamma expansion.
