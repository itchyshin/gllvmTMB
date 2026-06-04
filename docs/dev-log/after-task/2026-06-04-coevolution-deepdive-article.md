# Coevolution Article Deep-Dive

Date: 2026-06-04

Branch: `claude/article-coevolution-deepdive`

Scope: deepen the existing `cross-lineage-coevolution` article (the
Design 65 C2 worked example) into a methods-paper-grade example. Read-path
and prose only -- no TMB code, formula grammar, exported signature, or
`_pkgdown.yml` change. Draft PR for maintainer rendered-HTML review (#230).

## What I Read First

- `vignettes/articles/cross-lineage-coevolution.Rmd` (the shipped #361 C2
  article on origin/main).
- `docs/design/65-cross-lineage-coevolution-kernel.md` (the design contract +
  the "novel bipartite stacked-Y PGLLVM, frame as methods contribution"
  positioning, and the C2.4 single-`W` / loading-orientation mandate).
- `tests/testthat/test-coevolution-recovery.R` (exact API calls, the
  Procrustes-tolerant `> 0.9` recovery gate, the `max(abs(Gamma_null)) < 1e-8`
  null assertion, the `> 1` logLik separation, the lower-triangular loading
  checks, and the sparse-vs-dense `richness` sweep).
- The fixture generator `data-raw/examples/make-coevolution-kernel-example.R`
  to confirm fixture field names (`truth$rho`, `truth$Gamma`, `truth$psi`,
  `truth$host_traits`, `truth$partner_traits`, `truth$n_rep`, `K_star`,
  `K_null`, `A_H`, `A_P`, `W`).
- `man/extract_Gamma.Rd` for the documented PARTIAL/PLANNED scope.
- `vignettes/articles/missing-data.Rmd` for the house `eval = FALSE` build
  policy and honest-uncertainty conventions, and the prose-style-review skill
  (`.agents/skills/prose-style-review/SKILL.md`).

## Gaps Filled (what was thin -> what I added)

1. **Biology / mechanism was thin.** Added "Why coevolution lives in an
   off-diagonal block": the stacked `Y*`, the structural argument that `A_H` /
   `A_P` cannot link a host trait to a partner trait, so all coupling is
   forced through `K_HP`; the `Cov(eta_H, eta_P) = Gamma_ab * K_HP,ij`
   identity; and the species-level (`K_HP`) versus trait-level (`Gamma`)
   separation. This is the paper-grade motivation the old article lacked.
2. **Methods-contribution framing absent.** Added the novelty positioning from
   Design 65 (vs HMSC's no-cross-coupling, vs the dyadic Rafferty-Ives /
   Hadfield-Nakagawa interaction-strength-as-response lineage) in the lead, and
   a References section.
3. **Null comparison was a bare logLik vector.** Added a dedicated section
   explaining the null is `K*` with `rho = 0`, the nesting, why `Gamma_null`
   collapses to zero, and the honest framing that the workflow lets the null
   win when the data warrant it.
4. **`rho` profile was a bare `lapply`.** Kept the exact syntax but added a
   precomputed illustrative profile table (logLik peak + `gamma_cor`
   stabilisation) and a two-way reading of it; restated that `rho` is supplied,
   not fitted, and in-engine estimation is PLANNED.
5. **Single-`W` sensitivity was one paragraph.** Promoted to its own section
   tied to Boettiger et al. 2012 ("one shared `W` is one replicate"), with the
   exact sparse-thinning code mirroring the C2 test's `richness = "sparse"`
   path and illustrative dense-vs-sparse recovery numbers + SE-inflation note.
6. **Honest-uncertainty (#230) was implicit.** Added an explicit checklist:
   `pdHess = FALSE` framing, the loading-orientation identifiability caveat for
   `Gamma` (lower-triangular `Lambda_H`, positive pivots, "quote the block not
   the cell"), no-calibrated-intervals scope, and data-condition warnings.
7. **No interpretation of a recovered `Gamma`.** Added a cell-by-cell
   biological reading of the planted truth (size-matching, size-vs-attack,
   defence row).

## Eval Strategy (kept light for pkgdown)

Mirrors the missing-data article. Light chunks that touch only matrices and
the portable RDS fixture run at build time: `setup`, fixture load/preview,
`make_cross_kernel()` + PSD/fixture-agreement checks, the null-kernel check,
and the `Gamma` heatmap. The heatmap's fitted panel is an explicit
illustrative stand-in (truth plus small noise) so it renders without a fit.

Every heavy chunk is `eval = FALSE` with exact shipped syntax and
precomputed/illustrative numbers drawn from the planted truth and
representative `test-coevolution-recovery.R` recovery values: `fit-wide`,
`fit-long`, `fit-null`, `extract-gamma`, the `rho-grid` profile, and the
`w-sensitivity` sweep. A header comment records the no-`eval = TRUE`-flip
policy. Both long (`value ~ 0 + trait`) and wide (`traits(...)`) calls are
shown per #230 / CLAUDE.md.

## Constraints Honoured

- No `_pkgdown.yml` edit (PR #447 owns the taxonomy; article already indexed).
- No TMB / formula-grammar / exported-signature change.
- Preserved the existing article's correct content (kernel math, fixture
  loader, heatmap recipe) and extended/restructured for depth.
- Prose-style-review applied manually: stable terms (`Sigma`, `Lambda`,
  `psi`/`Psi`, `Gamma`, `kernel_latent`/`kernel_unique`, `traits()`), no
  flagged filler, pair of equation + syntax + interpretation, paragraph-end
  takeaways.

## Verification

- No R available in this environment, so no local render or `devtools::test()`.
  The heavy fits are `eval = FALSE` by design; the light chunks reuse the exact
  fixture-loader and heatmap code already shipped and rendered in the prior
  article, plus pure-matrix `make_cross_kernel()` calls already covered by
  `test-example-coevolution-kernel.R` and `make_cross_kernel`'s own examples.
- Maintainer rendered-HTML review is the gate (#230 / #347 / #230 article
  gate). This is a DRAFT PR; do not merge until the rendered article is
  reviewed.

## Follow-up

- Maintainer renders the article and confirms the figure, the precomputed
  tables, and the prose read well.
- If desired later, the illustrative `rho` profile / dense-vs-sparse numbers
  could be replaced by a committed precomputed RDS (a small results object) so
  the tables are reproducible rather than illustrative -- out of scope for this
  light-build slice.
