🎯 GOAL
Solo platform: Codex
Deliverable: public, reviewed, merged, and live `kernel_coef()` Gaussian point models in long and `traits(...)` wide forms
HEADLINE: exact warning-free `kernel_slope()` identity at the no-intercept `rho = 1` endpoint
IN PARALLEL: released-slope surface map, implementation gap map, and symbolic/API review
DEFER: `spatial_coef()` to the next fresh lane; intervals, non-Gaussian, multiple sources, latent-coefficient rho, releases
DISCIPLINE: verify=Unlazy plus exact-fit and D-43 reviews · compute=local deterministic fits under 30 minutes · closure=protected merge, exact-main CI/pkgdown, live page, lease release

## Prior-work sweep receipt

- Repo git state: `git status -sb`, `git log --all -S kernel_coef`,
  `git branch -a`, `git worktree list`, `git stash list`, and
  `branch_drift_check.sh` found a clean branch at `2d4c275b0`, zero ahead/behind,
  and no hidden kernel coefficient implementation. Reuse the merged coefficient
  foundation and released kernel slope engine; do not resume another branch.
- Sister repo: `rg -n "kernel_coef|kernel_slope|response-column coefficient"
  GLLVM.jl` found no twin implementation to port.
- Brain: MCP `search_notes(search_all_projects=true)` for `kernel_coef`,
  `kernel_slope`, response-column coefficients, and dense kernels found the
  established dense-kernel equivalence work and column-axis motivation, but no
  completed engine. Deterministic greps of the agent log, journal, decisions,
  open questions, and deep-research index found no additional decision.
- Verdict: **build the gap**. Reuse raw dense-`K` validation and matrix-normal
  likelihood; add only the public marker, kernel-specific endpoint/rewrite,
  fixed/estimated source routing, extraction, tests, and documentation cascade.

## Route and coordination

The destination and every output are concrete, with no undecided slice: the
route is knowable. Lane preflight found only disjoint or expired ownership.
Live PR #1209 changes one handover file only. Lease
`codex:kernel-column-coef` owns this lane's paths and will be refreshed.

## Slice table

| Slice | Member / tier | Output | Dependency | Estimate |
|---|---|---|---|---|
| Recon | three bounded read-only scouts | endpoint, gap, and math reports | none | 20 min |
| Contract | Ada / orchestration | alignment, Design 132, Unlazy gates | recon | 30 min |
| RED tests | Codex implementation | kernel helper and four test files | contract | 45 min |
| Engine/API | Codex implementation | marker, rewrite, routing, extractor | RED | 2–4 h |
| Public cascade | Boole/Pat lenses | Rd, NEWS, grid, Design 01/35 | engine | 1–2 h |
| Verify | Curie/Gauss/Rose/Grace lenses | tests, recovery, package/pkgdown, reviews | candidate | 2–4 h |
| Land | Ada/Grace | CI-paced PR, three OS, merge, exact-main/pkgdown | verify | 2–4 h CI |
| Reconcile | Melissa-equivalent audit | plan-actual and closeout | land | 20 min |

## Locked decisions

- API: `kernel_coef(formula, K, name = "kernel", rho = NULL)`.
- Numeric `rho` fixes `[0,1]`; `NULL` estimates one interior value.
- Dense covariance `K` only; sparse input is rejected to avoid precision ambiguity.
- Preserve raw marginal scale and report `scale = "as_supplied"`.
- `|` full coefficient covariance; `||` diagonal.
- Gaussian native-Laplace point models only, one coefficient source.
- No change, warning, or deprecation for any `*_slope()` helper.

## Pre-authorised execution

Scoped edits; local checks/fits under 30 minutes; documentation and article
render; checkpoints; commits; one CI-paced branch push and PR; normal protected
merge after exact-head three-OS success; exact-main CI/pkgdown verification.
Stop for bypass/release, overlap, a run above 30 minutes, or changed mathematics.
