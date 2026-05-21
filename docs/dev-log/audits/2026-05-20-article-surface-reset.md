# Article Surface Reset And Infrastructure-First Plan

**Date:** 2026-05-20
**Branch:** `codex/article-audit-2026-05-20`
**Issue ledger:** #230 (`Article surface reset and user-first tooling gate`)
**Maintained by:** Ada
**Active review lenses:** Pat (applied reader), Rose (claim hygiene),
Darwin (biology), Grace (pkgdown navigation), Florence (figure readiness).

## Decision

Article production is paused. The project should not add or reveal more
articles until the corresponding infrastructure, modelling functions,
simulation fixtures, extraction paths, profile/bootstrap uncertainty, and
plotting defaults are tested and ready.

The immediate job is planning and public-surface control:

- keep all article source files on disk;
- hide premature pages from the visible pkgdown article dropdown;
- classify every current page honestly;
- rebuild the roadmap around infrastructure-first gates;
- reveal pages one at a time only after rendered HTML review with the
  maintainer.

No article should be uploaded or promoted from this point onward without a
joint HTML review.

## Joint HTML Review Protocol

Every new or restored public article must pass this loop before launch:

1. Build the rendered HTML locally.
2. Show the maintainer the HTML, not only the Rmd source.
3. Walk through the examples together.
4. Confirm every Tier-1 worked example shows both:
   - the canonical long-format call,
     `gllvmTMB(value ~ ..., data = df_long, trait = "...")`; and
   - the wide data-frame formula call,
     `gllvmTMB(traits(...) ~ ..., data = df_wide)`.
5. Check that simulated examples compare truth and fitted estimates, and
   say when recovery is weak because the sample size is too small.
6. Check wording, scope boundaries, validation-row references, and all
   figures.
7. Only then publish, open a PR, or make the page visible in the navbar.

This is now a hard gate, not a style preference.

## Current Inventory

The repository currently has:

- 1 Get Started vignette: `vignettes/gllvmTMB.Rmd`
- 24 files under `vignettes/articles/`
- `README.md` as the pkgdown landing page source
- 25 entries under `_pkgdown.yml` `articles:` when counting the hidden
  `roadmap` wrapper
- 24 non-roadmap article pages in the visible article dropdown before this
  reset

The problem is not only count. The site presents pages as if they are
equally ready, but they differ sharply in evidence, reader quality, and
validation status.

## Article Classification

Categories:

- **Ready candidate**: may remain in the minimal public set, but still needs
  the joint HTML review before any new launch.
- **Halfway**: useful draft, but must be rewritten or reorganised before
  public reveal.
- **Technical reference**: useful lookup page, not a Tier-1 worked example.
  It should live under a later technical-reference dropdown only after
  status labels and examples are checked.
- **Infrastructure-blocked**: should stay hidden until the underlying model,
  simulation, extraction, plotting, or validation path is ready.
- **Project/internal**: not a user article.

| Page | Category | Public action now | Main blocker before reveal |
|---|---|---|---|
| `README.md` landing page | Halfway | Revise before treating as launch-ready | Links to pages that should be hidden; status matrix is too large for a first screen and has stale milestone language. |
| `vignettes/gllvmTMB.Rmd` | Halfway | Keep as intro only after HTML review | It has long + wide code, but opens with too much mechanics and needs a cleaner landing path. |
| `morphometrics.Rmd` | Ready candidate | Keep as one of the few visible examples | Strongest Tier-1 candidate: long + wide fits, truth-vs-fit recovery, and a real worked path. Needs HTML/figure review. |
| `covariance-correlation.Rmd` | Ready candidate | Keep visible if HTML passes | Focused concept, early code, long + wide framing, truth-vs-recovered comparison. Needs figure and wording check. |
| `pitfalls.Rmd` | Ready candidate / near-ready | Keep visible only after quick HTML pass | Useful failure-mode article. It mentions wide form, but individual pitfall examples still need a stricter long + wide audit. |
| `choose-your-model.Rmd` | Halfway | Hide | Already rewrite-prep; should return only after the infrastructure roadmap stabilises and hidden-link targets are clean. |
| `data-shape-flowchart.Rmd` | Halfway | Hide | Useful map, but it is not a worked example and should be redesigned with the landing page. |
| `animal-model.Rmd` | Halfway / infrastructure-blocked | Hide | Small pedigree fixture and weak recovery story; no wide companion; quantitative-genetics example needs slower design. |
| `behavioural-syndromes.Rmd` | Halfway | Hide | Long page, first fit appears late, only one main fit call; needs long + wide paired workflow and clearer recovery claims. |
| `joint-sdm.Rmd` | Halfway / infrastructure-blocked | Hide | Long + wide appears, but binary/JSDM validation and figure semantics need stronger M2/M3 evidence before public claim. |
| `phylogenetic-gllvm.Rmd` | Halfway / technical reference | Hide | Long + wide appears, but the page needs a clearer reader question and stricter validation-status framing. |
| `functional-biogeography.Rmd` | Infrastructure-blocked | Hide | Capstone composite story depends on M3 evidence and can easily overclaim. |
| `psychometrics-irt.Rmd` | Infrastructure-blocked | Hide | Explicit rewrite-prep; should wait for binary IRT validation and comparison evidence. |
| `mixed-family-extractors.Rmd` | Technical reference | Hide | Extractor reference, not a worked article; no wide companion and should wait for a compact status-labelled reference section. |
| `simulation-recovery-validated.Rmd` | Infrastructure-blocked / internal validation | Hide | M3.3 production grid failed the statistical gate; no public validation article until target-explicit surfaces pass. |
| `simulation-verification.Rmd` | Technical/internal | Hide | Useful methodology note, but not a public worked example; no wide companion. |
| `cross-package-validation.Rmd` | Infrastructure-blocked | Hide | Cross-package validation belongs to Phase 5.5; current comparisons are not enough for public navigation. |
| `api-keyword-grid.Rmd` | Technical reference | Keep visible under Concepts | Good lookup topic, not a Tier-1 worked example. Needs status labels and a shorter reader path. |
| `response-families.Rmd` | Technical reference | Keep visible under Concepts | Useful family lookup if per-family validation status remains harmonised with the register. |
| `ordinal-probit.Rmd` | Infrastructure-blocked / technical | Hide | Preview article; ordinal-probit remains partial in the register. |
| `lambda-constraint.Rmd` | Halfway / technical | Hide | Long + wide appears, but the confirmatory example needs post-M2 evidence and wording cleanup. |
| `profile-likelihood-ci.Rmd` | Technical reference | Hide | Useful but should wait behind profile/bootstrap roadmap cleanup and HTML review. |
| `convergence-start-values.Rmd` | Technical reference / methods guide | Keep visible under Methods | Useful hard-fit guidance if `pdHess = FALSE` stays framed as an uncertainty warning and bootstrap/profile caveats remain explicit. |
| `gllvm-vocabulary.Rmd` | Technical reference | Hide | Glossary material; should be integrated into a smaller learning path. |
| `stacked-trait-gllvm.Rmd` | Halfway / older concept draft | Hide | Older broad article; no wide companion; overlaps landing/Get Started. |
| `troubleshooting-profile.Rmd` | Technical reference | Hide | Likely merge or cross-link from profile CI docs after profile roadmap stabilises. |
| `roadmap.Rmd` | Project/internal | Keep hidden from article dropdown | It is surfaced by the dedicated Roadmap navbar entry, not as a tutorial. |

## Minimal Public Surface Draft

The conservative public surface is:

1. `README.md` / pkgdown home, after landing-page cleanup.
2. Get Started, after HTML review.
3. `morphometrics.Rmd`.
4. `covariance-correlation.Rmd`.
5. `api-keyword-grid.Rmd`.
6. `response-families.Rmd`.
7. `convergence-start-values.Rmd`.
8. `pitfalls.Rmd`.
9. Roadmap via the dedicated Roadmap navbar entry.

Everything else stays on disk but hidden from the article dropdown until its
infrastructure and reader gates pass.

The detailed row-by-row gate table is now
`docs/dev-log/audits/2026-05-20-article-gate-matrix.md`.

## drmTMB Lessons To Copy

The `drmTMB` site is not careful because it has few articles. It is careful
because the navigation and articles separate purpose:

- **Model Guides** answer "what can I fit today?" and keep implemented,
  first-slice, planned, and blocked status explicit.
- **Tutorials** are worked examples. They start with a biological or
  statistical question, then show the model equation, matching R syntax, fit,
  diagnostics, and interpretation.
- **Simulation & Comparison** is separate from tutorials, so validation
  evidence does not pretend to be a beginner example.
- **Developer Notes** are not in the ordinary reader path.
- **Visualization** has a named figure audit standard. A figure is evidence
  and explanation, not decoration.

For `gllvmTMB`, copy the discipline but not the exact number of articles. The
package has higher-dimensional latent covariance, so every public article
needs more validation pressure than a simpler univariate/bivariate example.

## New Article Anatomy

Each article should treat one model as precious. A public worked example should
have this anatomy:

1. **Plain-language biological question.** For example: behaviours covary
   because some individuals are consistently bold and exploratory; which
   behaviours share that latent axis?
2. **Named simulation helper.** Use a small exported or internal helper such
   as `simulate_behavioural_syndrome()` rather than a page-long DGP block.
   The article should explain the simulated world, not bury the reader in
   construction code.
3. **Truth table.** Name the true slopes, loadings, trait-specific variances,
   correlations, repeatabilities, or other estimands the model should recover.
4. **Long + wide fit pair.** Fit the same model in canonical long format and
   wide `traits(...)` format, then show that the log-likelihood or target
   estimates agree.
5. **Diagnostic check before interpretation.** Use `check_gllvmTMB()` or the
   relevant diagnostic table before discussing biological meaning.
6. **Estimate-vs-truth comparison.** Use a compact table or figure for the
   actual estimands, not vague prose that says recovery is good. If the sample
   size is too small, say so and use the page as a failure-mode lesson.
7. **Interpretation table.** Explain each fitted coefficient, loading,
   covariance component, or slope in ecological/evolutionary language.
8. **One next step.** Point to the next article or helper only after the model
   has been interpreted.

No broad "tour" article should return to the public site until its model
anatomy is this clear.

## Infrastructure Readiness Map

The validation-debt register is the controlling evidence source. A quick
current scan found 150 register rows, with many covered paths but important
publication-facing partials still active.

| Infrastructure area | Current state | Planning consequence |
|---|---|---|
| Long + wide formula grammar | Covered: long stacked data, explicit `trait =`, and wide `traits(...)` formula paths have tests. | Documentation examples are the problem, not the parser. Every Tier-1 article needs paired long + wide examples. |
| Core Gaussian GLLVM | Covered for the main `latent + unique` workflow. | This is the safest basis for the first public examples. |
| Response families | Gaussian, binomial, Poisson, and NB2 have stronger evidence; many other families remain partial or blocked. | Family showcase articles should wait until per-family status is compact and honest. |
| Simulation functions | `simulate_site_trait()` is well tested but is functional-biogeography-shaped and can force long DGP chunks into articles; `simulate.gllvmTMB_multi()` is covered for selected family-aware redraws, but newdata and full-family paths remain limited. | Build scenario helpers before more examples: morphometrics, behavioural syndrome, animal model, phylogenetic GLLVM, spatial JSDM, meta-analysis. |
| Extraction | Core extractors are covered; mixed-family rows improved in M1; profile/bootstrap and non-Gaussian paths still have partials. | Extractor articles should be technical reference until row-by-row claims are stable. |
| Profile/bootstrap uncertainty | Wald/profile/bootstrap routes are tested, but M3.3 coverage did not pass the statistical gate. | Do not publish validation articles that imply coverage success. Keep CI pages technical and status-labelled. |
| Diagnostics / hard-fit support | `check_gllvmTMB()`, `sanity_multi()`, `se = FALSE`, restart provenance, and related diagnostics are in good shape; predictive diagnostics remain prototype/#228. | Diagnostics can be planned, but public predictive-check plotting waits until #228 resumes. |
| Plotting | `plot.gllvmTMB_multi()` has 5 tested plot types, but the register still marks plotting partial and Florence-quality publication defaults are not complete. | Visualization work is infrastructure, not article polish. Figure-heavy articles wait. |
| Phylogenetic and animal keywords | Parser and core keyword equivalence are covered; animal article quality is not ready. | The article needs a better fixture and recovery story before reveal. |
| Spatial keywords | Mesh/orientation/dispatch are covered; several spatial model variants remain partial. | Spatial articles should wait behind validation and plotting. |
| `meta_V()` | Parser and block-V helper are covered/partial; proportional mode is blocked. | Meta-analysis article work should wait for exact/proportional design and validation. |
| Landing page / pkgdown nav | Home page and dropdown currently overexpose premature pages. | Public site should be minimal until the infrastructure rows catch up. |

## Roadmap Rewrite Shape

The roadmap should be reorganised around infrastructure before examples:

1. **I0 Public-surface reset**: hide premature articles, keep a minimal
   public set, and add the HTML review protocol.
2. **I1 Data-shape contract**: enforce long + wide examples and tests for
   every public model workflow.
3. **I2 Simulation fixtures**: build larger, reusable DGP fixtures and
   reader-facing scenario helpers for Gaussian, binary, count, animal, phylo,
   spatial, behavioural-syndrome, and meta-analysis paths. The helper should
   return data, truth, wide data when possible, and a compact estimand table.
4. **I3 Extraction and uncertainty**: stabilise `extract_*()`,
   profile-likelihood, bootstrap, and coverage evidence before article
   claims.
5. **I4 Plotting and diagnostics**: complete publication-quality plot
   helpers and fitted-model diagnostic APIs before figure-heavy tutorials.
6. **I5 Article reveal sequence**: restore one article per PR, after HTML
   review and user sign-off.

Issue #228 should remain parked until I0/I1 are clear. The local recovery
checkpoint for #228 is:

`docs/dev-log/recovery-checkpoints/2026-05-20-165700-codex-checkpoint.md`

Issue #230 owns the article-surface reset, scenario-helper, plotting,
extraction, diagnostics, and article-reveal gate.

## Evidence Gathered In This Audit

Commands run:

```sh
rg --files vignettes | sort
sed -n '1,190p' _pkgdown.yml
Rscript --vanilla - <<'RS'
# article metric inventory
RS
rg -n "Preview|REWRITE-PREP|traits\\(|value ~|gllvmTMB\\(" vignettes/articles/*.Rmd vignettes/gllvmTMB.Rmd
rg -n "^###|covered|partial|blocked" docs/design/35-validation-debt-register.md
```

Findings:

- There are 24 article Rmd files plus Get Started.
- Before the reset, 24 non-roadmap article pages were visible in the article
  dropdown.
- Many pages are drafts, technical references, validation reports, or
  preview/rewrite-prep pages rather than Tier-1 worked examples.
- The current landing page links to pages that should be hidden during the
  reset.
- The long + wide requirement is not consistently followed across articles.
- The validation register supports an infrastructure-first roadmap: there is
  real tested machinery, but several article-facing claims remain partial.

## Bottom Line

The package needs fewer public pages and more infrastructure work. The next
honest move is not another article. It is a roadmap reset: finish modelling,
simulation, extraction, uncertainty, plotting, and diagnostics infrastructure
first; then reveal articles one by one with rendered HTML and maintainer
sign-off.
