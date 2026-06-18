# Master Finish Plan: Psi, Coevolution, Articles, Bridge, And Release

**Date:** 2026-06-18 09:55 MDT
**Status:** first implementation slice started; this is an evidence ledger, not
a release gate.

Guard:

```text
PR green != bridge complete != release ready != scientific coverage passed
```

## Current Truth

`unique()` and the source-specific `*_unique()` keywords are not deprecated in
the current package. The cleanup is a public-story correction, not an API
removal. New public teaching should use `indep()` for standalone diagonal
models and reserve `unique()` for the explicit `Psi` component in
`latent() + unique()` decompositions, or for source-specific Psi examples that
have matching validation-row evidence.

The coevolution path is real but bounded. `KER-01`, `KER-02`, and `COE-02`
cover the one-kernel fixed-`rho` point-estimate workflow. `COE-03` remains
partial because true Paper 2 Option B needs multiple independent named kernel
tiers, each with its own `K`, latent field, loading matrix, optional `Psi`,
likelihood contribution, extractor level, and validation rows.

## Team Dispatch

| Member | Role in this slice |
|---|---|
| Ada | Sequence the slice and keep the release/bridge/science gates separate. |
| Boole | Check formula grammar around `unique()`, `indep()`, and `kernel_*()`. |
| Emmy | Keep future extractor and tier-registry work out of prose-only edits. |
| Gauss | Confirm no TMB likelihood or parameterization changed in this slice. |
| Noether | Keep `Sigma = Lambda Lambda^T + Psi` and `Gamma` wording aligned. |
| Fisher | Prevent interval, rho, and scientific-coverage overclaiming. |
| Curie | Keep simulation and recovery gates explicit before row promotion. |
| Jason/Raman | Reserve literature/source-map work for the Paper 2 design slice. |
| Rose | Scan for stale standalone-`unique()` teaching and row drift. |
| Shannon | Pre-edit lane check and check-log trace. |
| Grace | Render/pkgdown/check evidence before calling the slice closed. |
| Pat | Keep public articles readable as a first-time applied path. |
| Darwin | Keep biological examples tied to actual ecological questions. |
| Florence | Review figures when plot-bearing articles are rewritten. |

## Psi Article Sweep Ledger

| Article | Tier | Nav status | unique/Psi use | Family regime | Action | Validation rows | Risky wording | Exact edit | Render command | Reviewers |
|---|---|---|---|---|---|---|---|---|---|---|
| `api-keyword-grid.Rmd` | Tier 2 | public Concepts | Defines grammar surface | cross-family reference | reword | FG-01..FG-17 plus row-specific notes | standalone `unique()` sounded like a first-choice diagonal model | Make `indep()` the standalone diagonal recommendation and `unique()` the explicit `Psi` component | `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'` | Boole, Rose, Grace |
| `covariance-correlation.Rmd` | Tier 1 concept/worked | public Concepts | Teaches `latent() + unique()` | Gaussian first | reword | FG-02, FG-03, FG-06, EXT rows | title framed the page as broadly "when you need unique" | Rename toward explicit Psi and add standalone-`indep()` boundary | same | Pat, Fisher, Florence, Rose, Grace |
| `model-selection-latent-rank.Rmd` | Tier 1 narrow | public Model guide | Candidate models compare ranks | Gaussian | replace-standalone | FG-04, FG-06, DIA rows | `d = 0` baseline used standalone `unique()` | Use `indep()` for the diagonal baseline while retaining `unique()` as Psi for `d >= 1` | same | Fisher, Pat, Boole, Rose, Grace |
| `gllvm-vocabulary.Rmd` | Tier 2 | public Technical reference | Defines unique variance | cross-family vocabulary | keep/reword later if stale scan finds drift | terminology only | Low risk in current text: already defines `unique()` as Psi | No edit in this slice unless render/stale scan flags it | same | Boole, Pat, Rose |
| `gllvmTMB.Rmd` | Tier 1 entry | public intro | Gaussian `latent() + unique()` | Gaussian | keep | FG/FAM/EXT entry rows | Must not imply all families need explicit Psi | No edit in this slice; revisit after anchor pages render | same | Pat, Rose, Grace |
| `morphometrics.Rmd` | Tier 1 exemplar | public Model guide | Gaussian `latent() + unique()` | Gaussian | keep | FG-02, FG-03, FG-06, EXT rows | Low risk because it is the Gaussian exemplar | No edit in this slice | same | Pat, Darwin, Florence |
| `joint-sdm.Rmd` | Tier 1 | public Model guide | Binary caveats | binomial/probit/logit | add-caveat later if stale scan finds drift | FAM-02/FAM-03, LAM rows | Must not teach explicit `unique()` as binary default | No edit in this slice; keep binary caveat in council queue | same | Fisher, Pat, Rose |
| `cross-lineage-coevolution.Rmd` | Tier 3 internal | internal drafts | `kernel_latent()` plus optional `kernel_unique()` | Gaussian fixture | reword | KER-01, KER-02, COE-02, COE-03 partial | `kernel_unique()` sounded central to Gamma and Option B | Center `kernel_latent()`/`extract_Gamma()` and describe `kernel_unique()` as explicit Psi in the fixture | same | Jason/Raman, Boole, Fisher, Rose |
| `phylogenetic-gllvm.Rmd` | candidate Tier 1 | internal | source-specific Psi | phylogenetic | queued | PHY rows | `phylo_unique()` must stay conditional | Future article-council decision after public anchors | same | Darwin, Noether, Fisher |
| `animal-model.Rmd` | candidate Tier 1 | internal | genetic diagonal vs residual diagonal | pedigree | queued | ANI rows | Must separate genetic and residual diagonal claims | Future article-council decision | same | Darwin, Noether, Curie |
| `functional-biogeography.Rmd` | capstone | internal | component Psi language | mixed advanced | queued/internal | M3/component rows | Too broad for current evidence | Leave internal until component evidence passes | same | Ada, Darwin, Fisher |
| `behavioural-syndromes.Rmd` | candidate Tier 1 | internal | Gaussian two-level Psi | Gaussian/repeated | queued | RE/EXT/DIA rows | Needs reader path and figure review first | Already gated as Tier 3 candidate; no edit in this slice | same | Pat, Darwin, Florence |
| `random-regression-reaction-norms.Rmd` | Tier 3 | internal | guarded augmented unique | Gaussian/non-Gaussian slopes | queued | RE/CI rows | Plain-language path not passed | Leave guarded | same | Pat, Fisher, Rose |
| `random-slopes-nongaussian.Rmd` | internal | internal | structured dependence | non-Gaussian | queued | PHY/SPA/ANI/RE/FAM/MIX rows | No CI calibration claims | Leave internal | same | Fisher, Noether, Rose |
| `profile-likelihood-ci.Rmd` | Tier 2 | public Technical reference | interval wording only | methods | queued scan | CI rows | Avoid coverage overclaim | No edit in this slice | same | Fisher, Grace, Rose |
| `troubleshooting-profile.Rmd` | Tier 2 | public Technical reference | interval troubleshooting | methods | queued scan | CI rows | Avoid guaranteed profile success | No edit in this slice | same | Fisher, Grace, Rose |

## Coevolution Option B Roadmap

Option A remains the publishable fallback: one supplied cross-kernel, fixed
`rho` inside `K_star`, point `Gamma`, block-diagonal null comparison, and a
fixed-`rho` sensitivity grid.

Option B promotion requires all of the following before public claims widen:

1. Multiple independent named `kernel_latent()` tiers with their own dense
   kernels and parameter offsets.
2. Component-specific `Lambda`, optional `Psi`, and likelihood contribution.
3. Extractor resolution by kernel tier, including `Gamma_shape` and
   `Gamma_effect` only when the API can distinguish supplied `rho` from
   estimated or profiled `rho`.
4. Kernel-separation diagnostics for overlapping phylogenetic and
   non-phylogenetic cross kernels.
5. Gaussian recovery first, then mixed-family smoke and recovery gates.
6. Interval/profile/bootstrap evidence before uncertainty or inference claims.

`kernel_*()` is the canonical general API for this roadmap. `relmat` remains
compatibility sugar. Do not expand `relmat_*()` and do not soft-deprecate
`relmat` until the shared drmTMB/gllvmTMB ledger explicitly agrees.

## Dashboard And Release Gates

Dashboard cards must keep these as separate states:

- `COE-02 covered`: one fixed dense kernel, fixed `rho` in `K_star`, point
  `Gamma`.
- `COE-03 partial`: true two-kernel support waits for a second engine slot.
- `Psi cleanup`: article anchor sweep in progress until public anchors render
  and stale scans are clean.
- `Article council`: ledger in progress, one article decision at a time.
- `Bridge`: #489, GLLVM.jl #101, release #486, full-check, and power-pilot
  evidence remain separate.

No release-ready statement is allowed until validation rows, article decisions,
rendered pages, local checks, GitHub CI, dashboard, check-log, and after-task
reports all agree.
