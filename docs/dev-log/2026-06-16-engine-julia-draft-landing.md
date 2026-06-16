# Engine Julia Draft Landing Readout

Date: 2026-06-16 06:26 MDT

Branch under preparation: `origin/engine-julia` at `9aed58566b09`

Base checked: `origin/main` at `9fc9b7f094e6`

Local preparation branch: `codex/engine-julia-draft-landing`

## Purpose

This note prepares, but does not open or merge, the draft PR for the
R-side `engine = "julia"` bridge. The bridge branch is useful, but it is
not a CRAN-main merge candidate until the conflict plan, validation rows,
and release timing agree.

The current programme decision remains:

- keep CRAN-main lean unless the maintainer explicitly chooses the larger
  bridge merge;
- treat `GLLVM.jl-integration` at `1dc9e98` as the bridge runtime truth;
- treat the main `GLLVM.jl` checkout on `codex/non-gaussian-fitter-gradients`
  as salvage-only for this landing pass;
- keep native `gllvmTMB` as the R/TMB oracle for per-trait dispersion,
  cutpoints, `df`, `logLik`, prediction, residuals, covariance extractors,
  and fitted-object contracts.

## Live State

Read-only checks run before this note:

```sh
git fetch --prune origin
gh pr list --state open --json number,title,headRefName,baseRefName,isDraft,mergeStateStatus,updatedAt,url --repo itchyshin/gllvmTMB
git log --all --oneline --since="6 hours ago"
git rev-parse --short=12 origin/main
git rev-parse --short=12 origin/engine-julia
git rev-list --left-right --count origin/main...origin/engine-julia
git log --oneline --left-right --cherry-pick --max-count=40 origin/main...origin/engine-julia
git diff --stat origin/main...origin/engine-julia
git diff --name-status origin/main...origin/engine-julia
git merge-tree --write-tree origin/main origin/engine-julia
gh run list --repo itchyshin/gllvmTMB --branch engine-julia --limit 10 --json databaseId,displayTitle,workflowName,status,conclusion,createdAt,updatedAt,url,headSha,event
gh run list --repo itchyshin/gllvmTMB --branch main --limit 10 --json databaseId,displayTitle,workflowName,status,conclusion,createdAt,updatedAt,url,headSha,event
gh issue view 483 --repo itchyshin/gllvmTMB --json number,title,state,updatedAt,url,labels
gh issue view 485 --repo itchyshin/gllvmTMB --json number,title,state,updatedAt,url,labels
gh issue view 486 --repo itchyshin/gllvmTMB --json number,title,state,updatedAt,url,labels
gh issue view 488 --repo itchyshin/gllvmTMB --json number,title,state,updatedAt,url,labels
git -C "/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" status --short --branch
git -C "/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" rev-parse --short=12 HEAD
git -C "/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" log -1 --oneline
git -C "/Users/z3437171/Dropbox/Github Local/GLLVM.jl" status --short --branch
git -C "/Users/z3437171/Dropbox/Github Local/GLLVM.jl" rev-parse --short=12 HEAD
git -C "/Users/z3437171/Dropbox/Github Local/GLLVM.jl" log -1 --oneline
```

Current evidence:

- open PRs: none;
- recent local commits: Codex truth map `33287b1`, Codex bridge-gate
  registry `2324646`, and the handover commits on `engine-julia`
  (`9aed585`, `99aadb1`, `7c5bcde`);
- branch distance: `origin/main...origin/engine-julia` is `18 74`
  by `git rev-list --left-right --count`;
- changed surface from merge base to `origin/engine-julia`: 106 files,
  14,367 insertions, 1,086 deletions;
- `engine-julia` CI: the latest visible branch runs were pull-request
  R-CMD-check runs on 2026-06-12, both successful, at older heads
  `7a7e209` and `87db8e0`; no current open PR exists;
- `main` CI: scheduled `full-check` and `Power pilot sweep` were in
  progress at the time of the readout, with earlier scheduled runs green;
- `GLLVM.jl-integration`: clean at `1dc9e98`, branch
  `codex/high-rate-poisson-safeguard`, last commit
  `feat(bridge): emit ordinal cutpoints + n_categories in the bridge payload`;
- `GLLVM.jl`: branch `codex/non-gaussian-fitter-gradients` at `1b42e35`,
  ahead of remote by 50 commits. This is salvage-only for this pass.

## Merge Conflict Plan

`git merge-tree --write-tree origin/main origin/engine-julia` reports
content/add conflicts in:

| File | Conflict type | Resolution rule |
| --- | --- | --- |
| `NAMESPACE` | content | Regenerate with `devtools::document()` after resolving roxygen sources. Do not hand-edit as final truth. |
| `NEWS.md` | content | Keep CRAN-main release notes separate from post-0.2.0 bridge notes. Bridge wording must say IN / PARTIAL / PLANNED / UNSUPPORTED and cite validation rows. |
| `cran-comments.md` | add/add | Treat `origin/main` CRAN comments as current release truth. Bridge-specific CRAN risk belongs in the draft PR body unless the maintainer chooses bridge-for-CRAN. |
| `docs/dev-log/check-log.md` | content | Append both histories chronologically; do not drop either CRAN-main or bridge evidence. |
| `man/gllvm_julia_fit.Rd` | add/add | Regenerate from roxygen after choosing exported bridge surface. Do not resolve by selecting one generated file. |

Large hot-file overlap also exists in `R/julia-bridge.R`,
`tests/testthat/test-julia-bridge.R`, generated `man/*.Rd`,
`_pkgdown.yml`, `README.md`, `vignettes/articles/response-families.Rmd`,
and many after-task reports. These are not all textual conflicts, but
they are review hot spots.

## Safe Claims For Draft PR

Draft PR language may say:

- the bridge branch introduces an experimental `engine = "julia"` route
  through the default paired `GLLVM.jl` fitting path;
- current local bridge evidence covers Gaussian, Poisson, and Binomial
  no-dispersion point parity, selected fixed-effect-X point rows,
  selected mask rows, method/status accessors, ordinal probability/class
  prediction, and explicit CI-status strings for several unsupported cells;
- mixed-family and dispersion-family rows are point-fit/status work in
  progress, not full parity;
- JuliaCall and `GLLVM.jl` remain optional bridge dependencies and should
  not affect default `engine = "tmb"` checks when the bridge is unavailable.

Draft PR language must not say:

- full bridge parity;
- CRAN-ready bridge;
- user-selectable Julia-side algorithms through `gllvmTMBcontrol()`;
- non-Gaussian REML or AI-REML support;
- per-trait NB/Beta/Gamma dispersion parity in Julia;
- per-trait ordinal cutpoint parity in Julia;
- structured `phylo_*`, `animal_*`, `spatial_*`, or `kernel_*` Julia bridge
  support;
- calibrated CI coverage for bridge rows whose evidence is only point
  parity or CI-status plumbing.

## Issue Map For Draft Landing

| Issue | Current state | Landing implication |
| --- | --- | --- |
| `#483` | open, release blocker for generated docs / exports | Conflict in `NAMESPACE` and `man/gllvm_julia_fit.Rd` confirms this remains a required resolve step. |
| `#485` | open, release blocker for NEWS wording | Conflict in `NEWS.md` confirms this must be rewritten after CRAN timing is chosen. |
| `#486` | open, first `--as-cran` punch list | Do not merge the bridge branch into CRAN-main until this issue says the bridge is in scope. |
| `#488` | open, gate-vs-engine drift audit | The gate registry slice starts this work locally, but it is not on `origin/engine-julia` yet. Draft PR should link it as required follow-up. |

## Draft PR Body Skeleton

Title:

```text
Draft: experimental engine = "julia" bridge to GLLVM.jl
```

Body:

```markdown
## Scope

Draft PR for the experimental `gllvmTMB(..., engine = "julia")` bridge.
This branch routes selected multivariate GLLVM fits through a paired
`GLLVM.jl` checkout using the default Julia fitting path. The native TMB
engine remains the default and remains the oracle for R release claims.

## Current Evidence

- Base: `origin/main` 9fc9b7f.
- Head: `origin/engine-julia` 9aed585.
- Paired Julia runtime: `GLLVM.jl-integration` 1dc9e98.
- Latest visible branch R-CMD-check evidence: 2026-06-12 PR runs green at
  older bridge heads; current head needs rerun after conflict resolution.

## In Scope

- Experimental bridge setup and admission ledger.
- Selected Gaussian / Poisson / Binomial point-parity rows.
- Selected fixed-effect-X and response-mask point rows.
- Post-fit methods and CI-status strings where explicitly tested.

## Partial / Planned / Unsupported

- Dispersion-family parity is partial because Julia currently uses shared
  nuisance parameters where native `gllvmTMB` uses per-trait quantities.
- Ordinal cutpoint parity is partial for the same per-trait-vs-shared reason.
- Structured dependence, multi-rr, mixed-family CIs, masked CIs/simulations,
  non-Gaussian REML, and REML CIs remain unsupported/planned.

## Merge Blockers Before Ready-For-Review

- Resolve conflicts in `NAMESPACE`, `NEWS.md`, `cran-comments.md`,
  `docs/dev-log/check-log.md`, and `man/gllvm_julia_fit.Rd`.
- Regenerate roxygen docs rather than hand-resolving generated files.
- Re-run bridge tests with and without live Julia.
- Run `pkgdown::check_pkgdown()` and at least `devtools::check(args =
  "--no-manual")` after generated docs settle.
- Link or land the gate-registry evidence for `#488`.

## CRAN Boundary

This draft does not decide whether the bridge belongs in the next CRAN
submission. If CRAN timing stays lean, keep this PR draft/open and land
only release-hygiene fixes on `main`.
```

## Next Safe Action

Do not merge `origin/engine-julia` into `main` as-is. The next safe
implementation action is one of:

1. if the maintainer wants the bridge PR opened now: push a conflict-free
   draft branch and open the PR with the body above;
2. if CRAN stays lean: keep the branch unmerged, land the gate registry and
   per-trait Julia specs in narrow branches first;
3. if the branch must be rebased: start with generated-doc conflict policy
   (`devtools::document()` wins after source resolution), then rerun local
   bridge checks before publishing.
