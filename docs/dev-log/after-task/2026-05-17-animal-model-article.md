# After Task: animal-model.Rmd worked-example article (PR #170)

**Branch**: `agent/animal-model-article` (merged via PR #170)
**Slice**: Worked-example article for the `animal_*()` keyword family (M2.8 follow-on; not part of the original M2 7-slice plan)
**PR type tag**: `article` (one new article + 5 cross-link edits + `_pkgdown.yml`; no R/, NAMESPACE, generated Rd, family-registry, formula-grammar, or extractor change)
**Lead persona**: Pat (article narrative + tutorial pedagogy) + Darwin (biology-first framing + canonical evolutionary-ecology anchors)
**Maintained by**: Pat + Darwin; reviewers: Boole (formula-grammar accuracy), Fisher (variance-component extraction), Rose (pre-publish + scope honesty), Ada (coordinator)

## 1. Goal

The `animal_*()` keyword family landed in M2.8 + M2.8b + M2.8c
(PRs #167–#169) with engine path, soft-deprecation of the phylo
sibling's `vcv =` arg, and a five-article cross-link cascade.
What was still missing was the user-facing **worked example** —
the one article a quantitative-genetics reader can open to see
a simulated pedigree, a fit, and a heritability estimate from
start to finish.

This PR closes that gap.

The maintainer sent three foundational papers during the work
(Kruuk 2004 *Phil. Trans. R. Soc. B*; Wilson et al. 2010 *J. Anim.
Ecol.*; Runcie & Mukherjee 2013 *Genetics*) to anchor the article
in the canonical literature. All three are cited prominently
and the article's three-tutorial structure mirrors Wilson 2010.

**Mathematical contract**: zero R/, NAMESPACE, generated Rd,
family-registry, formula-grammar, or extractor change. The
article exercises existing v0.2.0 machinery — `animal_scalar()`,
`animal_latent()`, `animal_unique()`, `pedigree_to_A()`,
`extract_Sigma(level = "phy")` — without adding new surface.

## 2. Implemented

### File 1 (NEW): `vignettes/articles/animal-model.Rmd`

A ~330-line worked-example article with three tutorials in
complexity order:

**Tutorial 1 — Heritability of a single trait.** Uses
`animal_scalar(id, pedigree = ped)` on a 20-individual half-sib
fixture (4 founders + 16 offspring). Demonstrates the V_A + V_R
partition and h² = V_A / V_P. Extracts V_A from
`fit$report$lam_phy` (the canonical phy-tier scalar variance for
the animal_scalar engine path).

**Tutorial 2 — Bivariate G matrix.** Adds a second trait,
simulates with known G = `[[0.5, 0.3], [0.3, 0.45]]` (true
r_G ≈ 0.632), fits with `animal_latent(d = 1) + animal_unique() +
unique(0 + trait | id)`, and extracts G via
`extract_Sigma(level = "phy")$Sigma` and r_G via the `$R`
component. Demonstrates the genetic correlation as the
standardised parameter.

**Tutorial 3 — Factor-analytic G for higher dimensions.**
Extends to 3 traits with a rank-1 shared genetic axis +
trait-specific genetic + non-genetic noise. Anchored in
**Runcie & Mukherjee 2013 BSFG** (Bayesian Sparse Factor analysis
of G-matrices); `animal_latent()` framed as the frequentist
(TMB Laplace) counterpart to BSFG — faster on moderate-dim
problems, applicable to mixed-family responses, no sparsity
penalty in v0.2.0.

Plus an **Adding non-genetic random effects** section showing
how `(1 | mother)` for V_M and `(1 | id)` for V_PE compose with
`animal_*()` for the V_A part (per Kruuk 2004 §4; Wilson 2010
Table 1). Then an honest **What's not yet supported** section
naming the v0.3.0 follow-ups:
- Multi-matrix maternal-genetic V_C (ANI-09)
- Sparse A⁻¹ direct engine path (ANI-08; bigger n_species speed)
- Random regression / heritable slopes via `animal_slope()`
  parser support

### Files 2-6 (EDITS): cross-links from sibling articles

- `_pkgdown.yml` — Model guides nav (between `morphometrics` and
  `phylogenetic-gllvm`).
- `choose-your-model.Rmd` 3a pedigree branch — points to the
  worked example.
- `data-shape-flowchart.Rmd` "Pedigree available" paragraph —
  refines the "v0.3.0 work" sentence to "covered in
  `animal-model.html`; multi-matrix v0.3.0".
- `gllvm-vocabulary.Rmd` G-matrix entry — adds the Runcie &
  Mukherjee 2013 citation + worked-example link.
- `phylogenetic-gllvm.Rmd` See-also — reciprocal cross-link.
- `pitfalls.Rmd` See-also — post the §7 A-vs-V section.

## 3. Files Changed

| File | Type | Lines |
|---|---|---|
| `vignettes/articles/animal-model.Rmd` | NEW | +332 |
| `_pkgdown.yml` | EDIT | +1 |
| `vignettes/articles/choose-your-model.Rmd` | EDIT | +2 |
| `vignettes/articles/data-shape-flowchart.Rmd` | EDIT | +6 |
| `vignettes/articles/gllvm-vocabulary.Rmd` | EDIT | +5 |
| `vignettes/articles/phylogenetic-gllvm.Rmd` | EDIT | +3 |
| `vignettes/articles/pitfalls.Rmd` | EDIT | +3 |

Total: 7 files, +352 lines / −6 lines.

## 4. Checks Run

- ✅ Full local `rcmdcheck --as-cran` PASSED: 0 errors, 1 env-only
  WARNING (macOS clang `-Wfixed-enum-extension`), 5 pre-existing
  NOTEs (none from this PR).
- ✅ Tests pass in 52s (no test changes; vignette re-build verified).
- ✅ Article renders cleanly via `rmarkdown::render()`.
- ✅ 3-OS CI green; self-merged.

## 5. Tests of the Tests

Three iterations were needed to get all R chunks executing:

1. **First render failed at Tutorial 1 fit** with "contrasts can be
   applied only to factors with 2 or more levels". The
   `value ~ 0 + trait` parameterisation with a single-level `trait`
   factor errors at `model.matrix()`. **Fix**: switch single-trait
   Tutorial 1 to `value ~ 1 + animal_scalar(id, pedigree = ped)`
   (intercept-only fixed effects).
2. **Second render failed at Tutorial 1 extraction** with
   "Fit has no `phylo_latent()` or `phylo_unique()` term". The
   `extract_Sigma(level = "phy")` extractor requires the
   `latent + unique` paired form, but `animal_scalar()` (single
   shared variance) produces only `fit$report$lam_phy`. **Fix**:
   extract V_A from `fit$report$lam_phy` directly and V_R from
   `fit$report$sigma_eps^2`. Documented this as the canonical
   single-trait single-shared-variance extraction pattern.
3. **Third render failed at Tutorial 3 loadings** with
   "non-numeric argument to mathematical function" on
   `round(fit3$report$Lambda_B, 3)`. The Lambda field for phy-tier
   loadings is `fit$report$Lambda_phy`, not `Lambda_B`. **Fix**:
   use `Lambda_phy`.

These three fixes are now baked into the article and serve as
the "tests" against future engine refactors: if the canonical
extraction patterns change, this article's chunks will fail at
vignette re-build and surface the regression.

## 6. Consistency Audit

- **Naming**: A (relatedness) vs V (sampling variance) boundary
  honoured throughout. Article uses **A** for the relatedness
  matrix; never says "V" for it.
- **Citations**: all foundational refs current and well-known:
  - Henderson (1976) — A⁻¹ recursive formula
  - Kruuk (2004) — evolutionary-ecology anchor (maintainer-sent)
  - Wilson et al. (2010) — three-tutorial structure
    (maintainer-sent)
  - Runcie & Mukherjee (2013) — BSFG; factor-analytic G in high
    dim (maintainer-sent, "more relevant")
  - Smith, Cullis & Gilmour (2001); Kirkpatrick & Meyer (2004) —
    factor-analytic G provenance
  - Cheverud (1996); Wagner & Altenberg (1996) — modularity
    biological justification
- **Cross-doc reciprocity**: 5 articles + `_pkgdown.yml` updated
  with bidirectional cross-links. A reader landing on any of
  `choose-your-model`, `data-shape-flowchart`, `gllvm-vocabulary`,
  `phylogenetic-gllvm`, or `pitfalls` can navigate to the worked
  example in one click.

## 7. Roadmap Tick

- No ROADMAP M-row tick from this PR alone; the row update
  bundled into PR #171 (M3.1 + ASReml + ROADMAP) lists this PR
  as a parallel slice under M2.
- No validation-debt register changes — the worked example
  doesn't add new advertised capabilities, it surfaces the M2.8
  shipment to user-facing pedagogy.

## 8. What Did Not Go Smoothly

- **Stale installed gllvmTMB caught the first render**. The
  installed package on the dev machine was pre-M2.8;
  `pedigree_to_A` wasn't exported. **Fix**: `devtools::install()`
  the local source before rendering. **Lesson**: When working on
  any vignette that uses recently-added exports, install the
  local source first; otherwise `library(gllvmTMB)` resolves to
  the stale CRAN-or-previous version. Logged as a precision
  reminder for the precision feedback memory.
- **Single-trait `0 + trait` doesn't form a contrast**. Caught in
  test render 1; documented in Section 5 above as a fix.
  Worth a code-comment in `R/animal-keyword.R` future v0.3.0 work
  noting that `animal_scalar` (which doesn't need the
  `latent + unique` paired form) is the natural single-trait
  entry point — but the formula must use `~ 1` rather than
  `~ 0 + trait` when trait has one level.
- **`Lambda_B` vs `Lambda_phy` field naming**. The phy-tier
  loadings are in `report$Lambda_phy`, not `report$Lambda_B`.
  This is consistent with the phylogenetic-gllvm article's
  pattern (which already uses `Lambda_phy`), but it tripped me
  during drafting. Worth flagging in a future
  `gllvm-vocabulary.Rmd` enhancement: which `fit$report` field
  holds which tier's loadings?

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Pat** (lead — reader UX): the three-tutorial structure mirrors
Wilson 2010's pedagogy; readers familiar with that paper will
have minimal cognitive switching cost. Single-trait, bivariate,
factor-analytic — each tutorial builds on the previous.

**Darwin** (lead — biology-first framing): the article opens
with **the biological question** ("how much of the phenotypic
variance is additive genetic?") before introducing any
machinery. Kruuk 2004 is the canonical evolutionary-ecology
anchor; Wilson 2010 is the canonical practical guide. Both
cited prominently in the intro.

**Boole** (review — formula-grammar accuracy): three call
patterns are exercised and shown to differ in the right ways —
`animal_scalar(id, pedigree = ped)` (no `0 + trait` for single
trait), `animal_latent(d = 1, pedigree = ped) + animal_unique()`
(paired form for multi-trait G), and the `unique(0 + trait | id)`
addition for non-genetic per-trait residual covariance.

**Fisher** (review — variance-component extraction): the
extraction is correct: V_A from `lam_phy` (single-shared) or
the diagonal of `extract_Sigma(level = "phy")$Sigma` (paired
form). The rotation-invariance disclaimer for Tutorial 3's
Lambda_phy is the right framing — entries are not directly
interpretable.

**Rose** (review — pre-publish + scope honesty): the
**What's not yet supported** section explicitly enumerates
v0.3.0 follow-ups (ANI-08, ANI-09, animal_slope parser support).
No overpromise. The Bayesian alternatives (MCMCglmm, ASReml-R,
WOMBAT) are named honestly as alternatives for those needs.

**Ada** (coordinator): closes the M2.8 deliverable end-to-end
with a user-facing worked example. M2.8 → M2.8b → M2.8c → animal-
model.Rmd is the full delivery arc. Next: M3.2 pipeline +
M3.6 article (sim-recovery-validated) per the M3 dispatch.

## 10. Known Limitations and Next Actions

- **Multi-matrix V_C maternal-genetic** example is queued as
  v0.3.0 (ANI-09). Requires two simultaneous A-matrix terms in
  the same fit; engine support is post-CRAN.
- **Sparse A⁻¹ direct path** for n_species > 500 is queued as
  v0.3.0 (ANI-08). Documented in Design 43 Section 4 Tier A.
- **Random regression / heritable slopes** via `animal_slope()`
  exists as a parser-side stub but engine support is v0.3.0.
  Documented in the article's "Not yet supported" section.
- **PR #170 was the first article PR** to land after M2.8's
  keyword family + the maintainer-sent foundational papers.
  This sets the template for any future quantitative-genetics
  worked examples (e.g. ANI-09 multi-matrix article in v0.3.0).
