# Jason scout: MultiTraits visualization and public-learning borrow-map

**Date:** 2026-06-16
**Lead lens:** Jason (landscape and source-map scout)
**Supporting lenses:** Pat, Florence, Rose, Fisher, Boole, Shannon
**Status:** Scout card. No implementation, no public claim, no issue closure.
**Trigger:** maintainer asked whether `biodiversity-monitoring/MultiTraits`
offers examples or visualizations that `gllvmTMB` / `GLLVM.jl` can borrow.

## 1. Scout Question

Can `MultiTraits` teach the twin finish programme something useful about
examples, figures, or applied user flow, and if yes, what can be borrowed
without weakening the gllvmTMB/GLLVM.jl statistical boundary?

## 2. Sources Checked

- GitHub: `biodiversity-monitoring/MultiTraits`, default branch `main`, repo
  description "Analyzing and Visualizing Multidimensional Plant Traits",
  updated 2026-04-11.
- Local shallow clone: `/tmp/codex-multitraits-scout`, commit `920adcd`
  dated 2026-03-22, message `v1.0.0`.
- Package metadata: `DESCRIPTION` reports `Version: 1.0.0`,
  `Date: 2026-3-22`, `License: GPL-3`, `NeedsCompilation: no`.
- CRAN page and CRAN vignette: public package and tutorial surfaces describe
  CSR, LHS, NPT, PTN, and PTMN modules for multidimensional plant traits.
- Package files inspected: `README.md`, `NEWS.md`,
  `vignettes/MultiTraits_tutorial.Rmd`, `R/CSR_plot.R`, `R/LHS_plot.R`,
  `R/NPT_continuous_plot.R`, `R/NPT_discrete_plot.R`, `R/PTN_corr.R`,
  `R/PTMN.R`, and `R/PTMN_plot.R`.

## 3. Short Verdict

`MultiTraits` is a good **public-learning and visualization reference**. It is
not a numerical comparator for `gllvmTMB` likelihoods, `GLLVM.jl` engine parity,
or bridge speed claims.

The borrowable part is its applied teaching grammar: named ecological modules,
fast bundled examples, trait-space figures, ordination-style displays, and
trait-network / multilayer-network views. The non-borrowable part is treating
raw trait correlations, phylogenetic independent contrasts, PCA/clustering, or
thresholded networks as if they were equivalent to fitted GLLVM likelihood
targets.

## 4. Comparator Card

| Field | MultiTraits reading | gllvmTMB / GLLVM.jl consequence |
| --- | --- | --- |
| Package role | Applied plant-trait analysis and visualization package. | UX / visualization scout, not inference oracle. |
| Version pinned | CRAN / repo version `1.0.0`, local clone commit `920adcd`. | Cite version in any future design note that borrows the pattern. |
| Equivalent model | No faithful GLLVM likelihood comparator. | Record "no faithful comparator" rather than forcing logLik or parameter parity. |
| Estimands | CSR/LHS classifications, NPT PCA/clustering summaries, raw or PIC-adjusted trait correlations, thresholded trait networks, multilayer edge lists. | Different from fitted `Sigma`, `Lambda`, `psi`, cutpoints, response-family likelihood, and CI/status payloads. |
| Scale conversion | None that turns MultiTraits outputs into GLLVM parameter targets. | Use qualitative/source-map comparison only. |
| Borrowable visual grammar | Ternary strategy space, 3D LHS space, PCA biplot with arrows, correlation heatmap, network graph, multilayer network with within/cross-layer edges. | Rebuild from model-estimated objects: `extract_Sigma()`, `getResidualCov()`, `getResidualCor()`, `extract_ordination()`, fitted values, residuals, and CI/status metadata. |
| Provenance risk | GPL-3 source, bundled data, hand-coded plotting helpers. | Prefer independent implementation. If code or data is ported, document provenance in `inst/COPYRIGHTS` before treating the change as complete. |

## 5. What To Borrow

### 5.1 Named applied lenses before matrices

MultiTraits teaches with named ecological modules first: CSR, LHS, NPT, PTN,
and PTMN. That helps applied users understand why they are looking at a figure
before they see implementation details.

For `gllvmTMB`, the analogous lenses should be model-output lenses, not copied
methods:

- **Trait covariance map:** model-estimated `Sigma` / residual-correlation
  heatmap, optionally with uncertainty/status annotations.
- **Trait ordination:** fitted latent scores and loadings, with rotation status
  and convergence diagnostics visible.
- **Trait module network:** graph built from fitted covariance or residual
  covariance, with edge inclusion and sign rules stated.
- **Layered trait modules:** user-supplied layer annotation such as leaf, root,
  stem, reproductive, behavioural, or functional-system groups; summarize
  within-layer and cross-layer fitted covariance.

### 5.2 Dataset-first worked examples

MultiTraits gets users moving with small bundled trait datasets and a phylogeny.
The gllvmTMB article analogue should use a small, fast fixture that can be shown
both as long data and wide `traits(...)` data through the single `gllvmTMB()`
entry point. This preserves the project rule that public worked examples show
long and wide calls side by side when meaningful.

### 5.3 Trait-network and multilayer-network figures

The PTN/PTMN pattern is promising for public diagnostics and interpretation:

- nodes are traits;
- edges come from fitted model summaries, not raw correlations;
- edge color can encode sign;
- edge width or opacity can encode estimate magnitude;
- edge linetype or alpha can encode CI/status;
- layer color can encode user-supplied trait groups;
- a caption must state whether the plotted quantity is `Sigma`, residual
  covariance/correlation, or a transformed response-scale summary.

This is a Florence/Pat-friendly interpretation layer, not a new estimator.

## 6. What Not To Borrow

- Do not make `MultiTraits` a parity comparator in `gllvm_julia_capabilities()`
  or `GLLVM.bridge_capabilities()`.
- Do not compare GLLVM logLik, df, dispersion, cutpoints, CI endpoints, or
  speed against MultiTraits; it does not fit the same likelihood.
- Do not call raw thresholded trait correlations "model-estimated residual
  correlations" unless they were computed from a fitted `gllvmTMB` object.
- Do not port GPL-3 plotting code, bundled data, or exact visual assets without
  an explicit provenance entry and maintainer approval.
- Do not let "LHS" drift: in gllvmTMB docs, LHS usually means left-hand side of
  a formula; in MultiTraits, LHS means Leaf-Height-Seed.

## 7. Cross-Twin Wording Rules

This scout should use the same bridge/status wording as the R/Julia and
DRM/GLLVM bridge plans:

- `engine = "julia"` means the default `GLLVM.jl` fitting path. Do not imply a
  user-selectable Julia optimizer, estimator, sparse algorithm, or
  `engine_control` surface until one exists.
- Use `admitted`, `gated`, `partial`, `planned`, and `unsupported` consistently
  across R, Julia, DRM, and GLLVM notes.
- Keep "oracle" language scoped: native `gllvmTMB` is the R/TMB oracle for the
  current bridge parity rows; MultiTraits is a visualization/source-map scout.
- Keep REML / AI-REML language Gaussian-only unless a later derivation and
  validation explicitly proves a broader non-Gaussian route.
- Treat `pdHess = FALSE` as an inference/status warning. A future visualization
  should surface this status rather than discard all fitted summaries.

## 8. Candidate Future Slice

**Slice name:** `codex/public-learning-trait-network-visuals`

**Goal:** create a design note and one prototype article figure that translates
the MultiTraits teaching grammar into a model-based `gllvmTMB` visual.

**Minimum acceptable scope:**

1. One small built-in or test fixture with long and wide `gllvmTMB()` calls.
2. One fitted covariance/correlation visual from `extract_Sigma()` or
   `getResidualCor()`.
3. Optional user-supplied trait-layer metadata.
4. A clear caption stating the estimand and whether uncertainty/status is
   shown.
5. Validation-register row links and explicit `IN / PARTIAL / PLANNED /
   UNSUPPORTED` wording.
6. No speed, likelihood-parity, or CRAN-readiness claim.

This slice should wait until the current bridge draft PR state is settled, or
land as a docs-only public-learning path PR with Rose/Pat/Florence review.

## 9. Issue Links

- `gllvmTMB#347` / `gllvmTMB#230`: public article learning path.
- `gllvmTMB#340`: capability matrix / public truth board, if a visual claims
  any bridge support row.
- `gllvmTMB#488`: bridge gate-vs-engine drift, if a visual uses
  `engine = "julia"` output.

No issue was closed or commented from this scout card.
