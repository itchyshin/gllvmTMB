# Recovery Checkpoint: NB1 Fixed-Parameter Bridge Evidence

Date: 2026-06-16 09:17 local

Agent: Codex

## Current Branch And Status

```sh
git status --short --branch
```

State after adding the NB1 fixed-parameter test and before ledger edits:

```text
## codex/r-bridge-grouped-dispersion
 M tests/testthat/test-julia-bridge.R
```

Paired Julia runtime checkout:

```text
/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration
branch: codex/julia-per-trait-dispersion
tip: 2a07745 feat(bridge): add per-trait ordinal cutpoints
```

## Commands Already Run

- `git status --short --branch && git log --oneline -8`
  -> clean before this slice on `codex/r-bridge-grouped-dispersion`,
  tip `1e7e3c4`.
- `git -C ../GLLVM.jl-integration status --short --branch && git -C ../GLLVM.jl-integration log --oneline -8`
  -> clean on `codex/julia-per-trait-dispersion`, tip `2a07745`.
- `gh pr list --state open --limit 30 --json number,title,headRefName,updatedAt,isDraft,mergeable,url`
  -> `[]`.
- `git log --all --oneline --since="6 hours ago" -- tests/testthat/test-julia-bridge.R docs/design/35-validation-debt-register.md docs/dev-log/check-log.md docs/dev-log/after-task docs/dev-log/recovery-checkpoints docs/dev-log/coordination-board.md R/julia-bridge.R src/gllvmTMB.cpp`
  -> current Codex programme commits only.
- Read `testing-r-packages` and `after-task-audit` skills.
- Source inspection:
  `tests/testthat/test-julia-bridge.R`;
  `R/julia-bridge.R`;
  `../GLLVM.jl-integration/src/families/negbin1.jl`;
  `../GLLVM.jl-integration/src/families/grouped_dispersion.jl`;
  `src/gllvmTMB.cpp`.
- Exploratory fixed-parameter check:
  `GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration' JULIA_HOME='/Users/z3437171/.juliaup/bin' Rscript --vanilla - <<'RS' ...`
  -> Julia NB1 grouped Laplace log-likelihood with zero loadings matched
  `stats::dnbinom(mu = mu, size = mu / phi, log = TRUE)` to
  `delta = -7.105427e-15`.
- Added test:
  `NB1 grouped likelihood matches the native linear-variance kernel at fixed parameters`.
- Targeted live bridge test:
  `GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration' JULIA_HOME='/Users/z3437171/.juliaup/bin' Rscript --vanilla -e 'devtools::test(filter = "julia-bridge")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 178` in 30.9 s.

## Next Safest Action

Update `JUL-01`, the NB1/Gamma audit, check-log, after-task report, and widget
to say NB1 now has fixed-parameter kernel evidence but not fitted-object parity.

