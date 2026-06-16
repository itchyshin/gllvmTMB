# Recovery Checkpoint: NB1 No-Latent Bridge Parity

## Current Branches

R package:

```text
## codex/r-bridge-grouped-dispersion
 M docs/design/35-validation-debt-register.md
 M docs/dev-log/2026-06-16-nb1-gamma-bridge-parameterisation-audit.md
 M docs/dev-log/check-log.md
 M docs/dev-log/coordination-board.md
 M tests/testthat/test-julia-bridge.R
?? docs/dev-log/after-task/2026-06-16-nb1-no-latent-fitted-parity.md
?? docs/dev-log/recovery-checkpoints/2026-06-16-093919-codex-checkpoint.md
```

Paired Julia runtime:

```text
## codex/julia-per-trait-dispersion
 M docs/dev-log/check-log.md
 M src/bridge.jl
 M test/test_bridge_grouped_dispersion.jl
?? docs/dev-log/after-task/2026-06-16-bridge-no-latent-nb1.md
```

## Diff Stat

R package:

```text
docs/design/35-validation-debt-register.md         |  2 +-
docs/dev-log/2026-06-16-nb1-gamma-bridge-parameterisation-audit.md | 21 +++++---
docs/dev-log/check-log.md                          | 60 ++++++++++++++++++++++
docs/dev-log/coordination-board.md                 | 10 ++--
tests/testthat/test-julia-bridge.R                 | 31 +++++++++++
```

Julia runtime:

```text
docs/dev-log/check-log.md              | 74 ++++++++++++++++++++++++++++++++++
src/bridge.jl                          |  2 +-
test/test_bridge_grouped_dispersion.jl | 16 ++++++++
```

## Commands Already Run

- `gh pr list ...` in R repo -> no open R PRs.
- `gh pr list ...` in Julia repo -> older draft PRs `#95` and `#94`, no active
  branch collision for this local slice.
- Direct Julia grouped NB1 `K = 0` probe -> finite fit, `_nparams = 4`,
  `size(loadings) = (2, 0)`, `converged = true`.
- `julia --project=. test/test_bridge_grouped_dispersion.jl` in
  `GLLVM.jl-integration` -> `49/49 pass`.
- Exploratory R native-vs-Julia NB1 no-latent fixture -> both logLik
  `-53.17549`, both `df = 4`, logLik delta `4.253763e-08`, max phi delta
  `5.42191e-05`.
- Live R bridge test:
  `GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration' JULIA_HOME='/Users/z3437171/.juliaup/bin' Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> completed cleanly.
- No-Julia R bridge test:
  `GLLVM_JL_PATH='' JULIA_HOME='' Rscript --vanilla -e 'options(gllvmTMB.GLLVM.jl.path = NULL, gllvmTMB.julia_home = NULL); devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> completed cleanly with 6 expected skips.
- R and Julia stale-claim scans -> expected historical/negative-scope hits only.
- `git diff --check` in both repos -> clean at the time of scan.

## Commands Still Needed

- Re-run `git diff --check` after this checkpoint is added.
- Optionally re-run the R live bridge test if any source test changes occur after
  this checkpoint.
- Stage named files only and commit separately in each repo.
- Refresh the local status widget after commits.

## Next Safest Action

Run final whitespace/status checks, then commit Julia first (`bridge_fit d = 0`
admission), then R second (NB1 no-latent parity evidence and ledgers).

## Blocking Question

None. Reduced-rank NB1 parity and Gamma native-parity policy remain next-lane
decisions, not blockers for this scoped slice.
