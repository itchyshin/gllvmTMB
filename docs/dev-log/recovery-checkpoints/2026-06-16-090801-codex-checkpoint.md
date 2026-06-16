# Recovery Checkpoint: NB1/Gamma Bridge Parameterisation Audit

Date: 2026-06-16 09:08 local

Agent: Codex

## Current Branch And Status

```sh
git status --short --branch
```

Result before edits:

```text
## codex/r-bridge-grouped-dispersion
```

Paired Julia runtime checkout:

```text
/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration
branch: codex/julia-per-trait-dispersion
tip: 2a07745 feat(bridge): add per-trait ordinal cutpoints
```

## Changed Files

No tracked files had been changed before this checkpoint.

## Commands Already Run

- `git status --short --branch && git log --oneline -5`
  -> clean on `codex/r-bridge-grouped-dispersion`, tip `b1ebce7`.
- `git -C ../GLLVM.jl-integration status --short --branch && git -C ../GLLVM.jl-integration log --oneline -5`
  -> clean on `codex/julia-per-trait-dispersion`, tip `2a07745`.
- `gh pr list --state open --limit 30 --json number,title,headRefName,updatedAt,isDraft,mergeable,url`
  -> `[]`.
- `git log --all --oneline --since="6 hours ago" -- ROADMAP.md NEWS.md NAMESPACE docs/design docs/dev-log/check-log.md docs/dev-log/after-task docs/dev-log/recovery-checkpoints R/julia-bridge.R tests/testthat/test-julia-bridge.R`
  -> current Codex programme commits only.
- `gh issue view 488 --json number,title,state,updatedAt,labels,assignees,url,body`
  -> open bridge gate-vs-engine drift issue.
- `gh issue view 340 --json number,title,state,updatedAt,labels,assignees,url,body`
  -> open capability matrix issue, refreshed 2026-06-16.
- Source reads in `../GLLVM.jl-integration`:
  `src/families/negbin1.jl`, `src/families/gamma.jl`,
  `src/families/grouped_dispersion.jl`, and `src/bridge.jl`.
- Source reads in this repo:
  `src/gllvmTMB.cpp`, `R/julia-bridge.R`,
  `R/methods-gllvmTMB.R`, `tests/testthat/test-julia-bridge.R`,
  `docs/dev-log/2026-06-16-julia-per-trait-dispersion-cutpoints-spec.md`,
  and `docs/design/35-validation-debt-register.md`.

## Findings Before Edit

- NB1 native `gllvmTMB` and Julia use the same model scale:
  `Var = mu * (1 + phi)`. Native reports per-trait `phi_nbinom1`;
  Julia grouped NB1 carries per-trait/grouped `phi`.
- Ordinary native Gamma in `gllvmTMB` currently uses scalar
  `sigma_eps` as a coefficient of variation:
  `shape = 1 / sigma_eps^2`.
- Julia grouped Gamma carries per-trait/grouped `alpha`, with
  `Var = mu^2 / alpha`, and the R bridge maps that to
  `sigma = 1 / sqrt(alpha)`.
- Therefore Gamma cannot honestly be called native R/TMB parity until
  either native `gllvmTMB` gets per-trait Gamma CV/shape support or
  the Julia bridge uses shared grouping for Gamma when claiming
  oracle parity.

## Commands Still Needed

- Add a focused audit note.
- Update the per-trait nuisance spec, cross-twin wording contract,
  coordination board, validation row, check-log, and after-task report.
- Run stale wording/source scans and `git diff --check`.
- Refresh the ignored local widget if the tracked status changes.

## Next Safest Action

Keep this as a docs/governance slice. Do not change bridge behavior or
claim Gamma parity until the maintainer chooses between shared-Gamma
bridge parity and native per-trait Gamma expansion.

