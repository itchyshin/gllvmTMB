# After Task: NB1/Gamma Bridge Parameterisation Audit

## Goal

Resolve the open NB1/Gamma follow-up from the grouped-dispersion main-dispatch
smoke without promoting an unsupported capability.

## Implemented

Added `docs/dev-log/2026-06-16-nb1-gamma-bridge-parameterisation-audit.md` and
updated the per-trait nuisance spec, cross-twin wording contract, coordination
board, validation register row `JUL-01`, check-log, and recovery checkpoint.

The audit records two different outcomes:

- NB1 is parameterisation-aligned between native `gllvmTMB` and Julia
  (`Var = mu * (1 + phi)`), but fitted-object objective parity still needs
  evidence.
- Gamma is not native-parity aligned today: Julia grouped Gamma estimates
  per-trait/grouped `alpha`, while native ordinary Gamma uses shared scalar
  `sigma_eps` as the coefficient of variation.

## Mathematical Contract

No likelihood, formula grammar, public API, examples, generated Rd, NAMESPACE,
vignettes, or pkgdown navigation changed.

Source-map conclusion:

- NB1 native route: `src/gllvmTMB.cpp` `fid == 15`, per-trait
  `phi_nbinom1`, `Var = mu * (1 + phi)`.
- NB1 Julia route: `src/families/negbin1.jl` and grouped NB1 use the same
  `phi` scale.
- Gamma native route: `src/gllvmTMB.cpp` `fid == 4` uses scalar
  `sigma_eps`, with `shape = 1 / sigma_eps^2`.
- Gamma Julia route: grouped Gamma uses `alpha_g` / `alpha_t`, with
  `Var = mu^2 / alpha_t`, then the R bridge maps to
  `sigma_t = 1 / sqrt(alpha_t)`.

## Files Changed

- `docs/dev-log/2026-06-16-nb1-gamma-bridge-parameterisation-audit.md`
- `docs/dev-log/2026-06-16-julia-per-trait-dispersion-cutpoints-spec.md`
- `docs/dev-log/2026-06-16-cross-twin-argument-wording-contract.md`
- `docs/dev-log/coordination-board.md`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/recovery-checkpoints/2026-06-16-090801-codex-checkpoint.md`
- `docs/dev-log/after-task/2026-06-16-nb1-gamma-bridge-parameterisation-audit.md`

## Checks Run

- Rehydration:
  `git status --short --branch && git log --oneline -5`
  -> clean on `codex/r-bridge-grouped-dispersion`, tip `b1ebce7`.
  `git -C ../GLLVM.jl-integration status --short --branch && git -C ../GLLVM.jl-integration log --oneline -5`
  -> clean on `codex/julia-per-trait-dispersion`, tip `2a07745`.
- Pre-edit lane check:
  `gh pr list --state open --limit 30 --json number,title,headRefName,updatedAt,isDraft,mergeable,url`
  -> `[]`.
  `git log --all --oneline --since="6 hours ago" -- ROADMAP.md NEWS.md NAMESPACE docs/design docs/dev-log/check-log.md docs/dev-log/after-task docs/dev-log/recovery-checkpoints R/julia-bridge.R tests/testthat/test-julia-bridge.R`
  -> current Codex programme commits only.
- Live issue reads:
  `gh issue view 488 --json number,title,state,updatedAt,labels,assignees,url,body`
  -> `#488` open.
  `gh issue view 340 --json number,title,state,updatedAt,labels,assignees,url,body`
  -> `#340` open.
- Source reads:
  `src/families/negbin1.jl`, `src/families/gamma.jl`,
  `src/families/grouped_dispersion.jl`, and `src/bridge.jl` in
  `../GLLVM.jl-integration`;
  `src/gllvmTMB.cpp`, `R/julia-bridge.R`, `R/methods-gllvmTMB.R`,
  and `tests/testthat/test-julia-bridge.R` in this repo.
- Stale-claim scans:
  `rg -n "full native parity|full parity|complete bridge|CRAN-ready bridge|Gamma.*native parity|native parity.*Gamma|Gamma.*covered.*Julia|per-trait nuisance parameters for NB2, NB1, Beta, and Gamma" R/julia-bridge.R tests/testthat/test-julia-bridge.R docs/design/35-validation-debt-register.md docs/dev-log/2026-06-16-julia-per-trait-dispersion-cutpoints-spec.md docs/dev-log/2026-06-16-cross-twin-argument-wording-contract.md docs/dev-log/2026-06-16-nb1-gamma-bridge-parameterisation-audit.md docs/dev-log/coordination-board.md`
  -> expected wording-guard and negative-scope hits only.
  `rg -n "Gamma|gamma|sigma_eps|alpha_t|alpha|phi_nbinom1|NB1|nb1" R/julia-bridge.R tests/testthat/test-julia-bridge.R docs/design/35-validation-debt-register.md docs/dev-log/2026-06-16-julia-per-trait-dispersion-cutpoints-spec.md docs/dev-log/2026-06-16-cross-twin-argument-wording-contract.md docs/dev-log/2026-06-16-nb1-gamma-bridge-parameterisation-audit.md docs/dev-log/coordination-board.md | head -160`
  -> expected NB1/Gamma source-map hits.
  `rg -n "engine = \"julia\"|engine_control|gllvmTMBcontrol|drm_control|control =|REML|AI-REML|pdHess|full parity|complete bridge|CRAN-ready bridge" README.md NEWS.md ROADMAP.md R docs vignettes tests/testthat | head -200`
  -> broad historical/guard hits only; no touched public-page overclaim.
- Whitespace:
  `git diff --check` -> clean.

Deliberately not run:

- `devtools::test()`, `devtools::check()`, `devtools::document()`,
  `pkgdown::check_pkgdown()`, and article renders were not run. This slice is
  docs/governance only and changes no executable R code, generated Rd, README,
  NEWS, vignette, or pkgdown navigation file.
- No GitHub issue was commented on or closed.

## Tests Of The Tests

No new executable test was added. The audit identifies the next tests that
would turn this from governance into promotion evidence:

- NB1 fixed-parameter likelihood check on a shared `beta`, `Lambda`, and `phi`.
- NB1 stable no-X fitted fixture after the kernel check.
- Gamma decision test: shared `G = 1` grouping for current-oracle parity, or
  native per-trait Gamma recovery if the R/TMB oracle expands.

## Consistency Audit

`JUL-01` remains `partial`. The cross-twin wording contract now says NB2, NB1,
and Beta can use per-trait grouped-dispersion parity wording when evidence
supports it, while ordinary Gamma must be labelled planned/experimental/non-
oracle-matching unless native Gamma changes or the bridge uses shared grouping.

AGENTS.md convention-change cascade is not triggered because no public argument,
formula keyword, function signature, examples, roxygen, generated Rd, README,
NEWS, vignette, or article changed.

## What Did Not Go Smoothly

The earlier per-trait nuisance spec had over-generalised from NB2/NB1/Beta to
Gamma. Source inspection showed Gamma is the exception: the current native
oracle is scalar-CV. The correction is now explicit so later agents do not turn
a useful Julia grouped fit into a false R/TMB parity claim.

## Team Learning

- Ada: keep the native oracle rule, even when it changes the near-term route.
- Hopper: bridge rows need scale labels and group-shape labels, not only family
  names.
- Karpinski: Julia grouped Gamma remains valuable, but it needs a bridge label
  that says whether it is oracle-matching.
- Gauss/Noether: NB1 is a source-map alignment case; Gamma is an oracle-shape
  decision.
- Fisher/Curie: the next promotion evidence is fixed-parameter likelihood first,
  fitted-object comparison second.
- Rose: `JUL-01` stays partial and now names the Gamma boundary.
- Shannon: no issue was closed; live issue reads were used before linking the
  audit to `#488` / `#340`.

## Known Limitations

NB1 objective parity is still unproven. Gamma parity is blocked on a maintainer
decision: shared bridge grouping for current native parity, native per-trait
Gamma expansion, or leaving the current route as partial route/shape evidence.

## Next Actions

1. Build the NB1 fixed-parameter likelihood check.
2. Ask Ada to choose the Gamma path before any bridge parity claim.
3. If shared Gamma is chosen, change the Julia bridge Gamma route to `G = 1`
   and add exact `df` / log-likelihood parity tests.
4. If native per-trait Gamma is chosen, open a separate TMB/R family-change lane
   with Gauss/Noether/Fisher review and recovery tests.

