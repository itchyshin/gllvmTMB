# After Task: Response-column slope post-merge article closure

## 1. Goal

Correct and republish the Tier-1 *Where does the phylogeny belong?* article so
it teaches the merged response-column slope family without changing the API,
the implementation, or existing fits.

## 2. Implemented

The community example now asks how C3 and C4 plant species differ in their
average latitude response. It uses continuous Gaussian log-biomass intensity
in a site × species layout and separates three model components:

```r
log_biomass ~ 0 + trait + latitude:pathway +
  phylo_slope(latitude | trait, tree = tree) +
  latent(0 + trait | site_id, d = 2, unique = FALSE)
```

The article shows that `pathway` is response-column metadata, while `latitude`
is a site-level predictor whose coefficient varies across species columns. It
prints the fitted C3 and C4 slopes plus their descriptive difference, labels
the planted figure gradients as simulated-by-design, makes the reproducible
data construction visible, and hides plot-construction mechanics. The wide
data figure attaches C3/C4 metadata to species columns rather than site rows.

## 3a. Decisions and Rejected Alternatives

The closure preserves the shipped meaning of `*_slope()`: a site-level
predictor has coefficients that vary across response columns. It rejects
reinterpreting the helper as a column-metadata term, rejects silently adding a
response-column random intercept, and rejects widening this documentation PR
into the deferred coefficient-block design. Species metadata such as C3/C4
pathway therefore enters the fixed `latitude:pathway` interaction, while
`phylo_slope(latitude | trait)` supplies the residual species slope deviations.
The public article now labels this fixed-versus-random split explicitly. It
also states that `column_coef()` is not a current API helper, so a future
random-coefficient block cannot be mistaken for either an existing helper or
an ordinary fixed-effect term. It also makes the implemented covariance
boundary explicit: `phylo_slope()` uses the supplied tree covariance directly
and does not estimate gllvm's IID-versus-phylogenetic signal mixture.

The simulation uses the exact draw
`b = 0.18 * t(chol(A)) %*% z`, `z ~ N(0, I)`. Post-draw standardisation was
rejected because it would contradict the stated `N(0, 0.18^2 A)` data-generating
contract. Confidence: high; the fitted-object verifier checks the resulting
design and random blocks rather than relying only on article text.

### Mathematical Contract

No public R API, likelihood, TMB parameterization, formula grammar, family,
NAMESPACE, generated Rd, or pkgdown navigation changed.

For site `i` and species response column `t`, the documented decomposition is

```text
eta_it = alpha_t
       + latitude_i * beta_pathway[t]
       + latitude_i * b_t
       + u_i' lambda_t,

b ~ N(0, K_phylo * sigma_latitude^2).
```

`0 + trait` supplies fixed species intercepts `alpha_t`.
`latitude:pathway` supplies the fixed C3/C4 mean gradients.
`phylo_slope(latitude | trait)` supplies phylogenetically correlated residual
species slope deviations `b_t`. `latent(... | site_id)` supplies residual
within-site species association. The helper remains slope-only and does not
add a phylogenetic response-column random intercept.

## 4. Files Touched

- `vignettes/articles/where-does-the-tree-go.Rmd` — replaced the community
  teaching example; exposed reproducible data construction; hid plot code;
  revised prose, output, captions, alt text, and figures.
- `dev/trait-axis-bridge/verify-article.R` — added regression guards for the
  three-component example, descriptive contrast, simulated-by-design title,
  visible data chunks, hidden plot mechanics, removed old teaching text, and
  wrapped subtitles.
- `docs/dev-log/handover/2026-08-24-codex-column-slope-family.md` — reconciled
  the handover with merged PR #1208 and classified the correction as DONE,
  OWED, RETRACTED, or PROTECTED.
- `docs/dev-log/after-task/2026-08-25-column-slope-postmerge-visual-closure.md`
  — this report.

No function, roxygen block, `man/*.Rd`, README, NEWS, ROADMAP, design document,
validation-register row, `_pkgdown.yml`, or other example changed. This is not
a convention change, so AGENTS.md Rule 10's convention cascade is N/A.

## 5. Checks Run

- Red phase: `Rscript --vanilla dev/trait-axis-bridge/verify-article.R` failed
  before the semantic rewrite because `latitude:pathway`,
  `phylo_slope(latitude | trait, tree = tree)`, and the latent site term were
  absent. A second red phase failed until the fitted pathway contrast,
  simulated-by-design title, and hidden plot chunks were added.
- Green phase: `Rscript --vanilla dev/trait-axis-bridge/verify-article.R` —
  `ARTICLE BUILD PASS`; `pkgdown::check_pkgdown()` reported no problems. The
  verifier also asserted the two fixed pathway columns, exact latitude-only
  `Z_phy_aug`, `z_B` plus `b_phy_aug` random blocks, phylogenetic extractor
  metadata, optimizer code 0, and maximum gradient below `1e-2`.
- Source-current pkgdown render, using a temporary installed library:
  `R_LIBS=/private/tmp/gllvmtmb-doclib:... Rscript --vanilla -e
  'pkgdown::build_article("articles/where-does-the-tree-go", lazy = FALSE)'` —
  PASS, all 19 chunks processed and all three deferred expressions ran.
- Focused tests:
  `Rscript --vanilla -e 'devtools::test(filter =
  "fixed-column-slope-family|ordinary-column-slope-phylo-coexistence|phylo-column-slope-indep|phylo-slope-rhs-routing",
  reporter = "summary")'` — PASS; two heavy recovery cells skipped by their
  explicit environment gate; 17 pre-existing unused-`cluster` warnings.
- `git diff --check` — PASS.
- Four generated PNGs inspected at original 1612-pixel width. Florence verdict:
  PASS after the community title explicitly identified planted gradients as
  simulated-by-design. No clipping, unreadable labels, default-grey panels, or
  misleading uncertainty geometry remained.
- Generated HTML scan found no lifecycle, automatic-residual, or other warning
  block after `unique = FALSE` was made explicit.

## 6. Tests of the Tests

The verifier satisfies the failure-before-fix rule. Its first failure reproduced
the exact semantic defect: a valid but reader-misleading moisture/canopy model
without fixed column-metadata moderation or residual site association. Its
second failure reproduced Pat's Tier-1 presentation defect: hidden data,
visible plotting mechanics, no descriptive pathway contrast, and an
overclaiming figure title. The acceptance path then rendered and fitted the
complete formula using deterministic simulated data.

## 7a. Issue Ledger

Issue #1161 was inspected because it records the distinction between phylogeny
on species grouping rows and on response columns. The slope subproblem is now
implemented, while its broader response-column covariance/random-intercept
question remains open. Issue #347 was inspected; this correction does not
change the umbrella article-promotion order, so no status change or closure is
appropriate. No new issue was created.

## 8. Consistency Audit

- `rg -n '\bS_B\b|\bS_W\b|\\bf S'
  vignettes/articles/where-does-the-tree-go.Rmd
  pkgdown-site/articles/where-does-the-tree-go.html` — no legacy notation.
- `rg -n 'gllvmTMB\(' vignettes/articles/where-does-the-tree-go.Rmd` — two
  long-format calls; both explicitly pass `trait = "trait"` and `unit =`.
- `rg -n 'in prep|in preparation'
  vignettes/articles/where-does-the-tree-go.Rmd` — no matches.
- `rg -n '\bphylo\(|\bgr\(|\bmeta\(|block_V\(|phylo_rr\('
  vignettes/articles/where-does-the-tree-go.Rmd` — the only match is the
  intentional `ape::vcv.phylo()` calculation, not an obsolete package keyword.
- `rg -n 'meta_known_V|gllvmTMB_wide'
  vignettes/articles/where-does-the-tree-go.Rmd` — no matches.
- `rg -n 'moisture|canopy|while the rows remain independent plots|phylo_slope\(moisture'
  vignettes/articles/where-does-the-tree-go.Rmd` — no superseded story remains.
- `rg -n 'Gaussian|long-format|Wide column-slope|non-Gaussian|latent predictor covariance|intervals|slope-only|random intercepts'
  vignettes/articles/where-does-the-tree-go.Rmd` — found only the intentional
  Gaussian/long-format admission and explicit deferred boundaries.
- Validation-register cross-check: FG-15 and PHY-06 cover the phylogenetic
  helper; FG-19 records the family as partial at exactly Gaussian long-format
  point-estimation depth and defers the wider regimes named in the article.
- Rose pre-publish verdict: PASS. Exported names, arguments, the 5 × 3 grid,
  formula calls, navigation, and validation status agree with source.

**Roadmap tick:** N/A; no ROADMAP row changed.

## 9. What Did Not Go Smoothly

The first article version was algebraically valid but answered the wrong
teaching question. It blurred a site predictor (`latitude`, previously
moisture/canopy), a species attribute (`pathway`), and a residual species slope.
The source-only verifier also missed a long warning block printed by the
default `latent()` behavior; inspecting generated HTML exposed it. Finally, a
direct pkgdown child process initially loaded an older globally installed
package. Installing the current source into `/private/tmp/gllvmtmb-doclib`
gave the child process the correct extractor without changing the user's global
R library.

## 10. Known Residuals

- The article demonstrates Gaussian long-format point estimation only.
- It does not provide inference for the C3-minus-C4 contrast; the printed
  difference is descriptive.
- `*_slope()` contains no response-column random intercept.
- Wide column-slope grammar, non-Gaussian/mixed-family slopes, latent predictor
  covariance, simultaneous response-column slope sources, and intervals remain
  deferred.
- The latent term is a nuisance adjustment in this article; its covariance is
  not interpreted.

### Closure receipts

PR [#1211](https://github.com/itchyshin/gllvmTMB/pull/1211) merged the focused
documentation correction at article head `10b8b046` and merge commit
`633085ed`. Its final routine PR check
[32916653930](https://github.com/itchyshin/gllvmTMB/actions/runs/32916653930),
post-merge `main` check
[32919449668](https://github.com/itchyshin/gllvmTMB/actions/runs/32919449668),
and pkgdown deployment
[32921933388](https://github.com/itchyshin/gllvmTMB/actions/runs/32921933388)
all passed. The live article text and all four native-resolution figure assets
were inspected after deployment. No action remains in this article lane.

The future intercept-plus-slope response-column coefficient block remains a
fresh design lane, now tracked in
[#1212](https://github.com/itchyshin/gllvmTMB/issues/1212).

## 11. Team Learning

**Ranga / Jason.** Reading current `gllvm` source resolved the conceptual
boundary. `randomX = ~latitude` plus `colMat` is slope-only and corresponds to
`phylo_slope(latitude | trait)`; fixed fourth-corner moderation and latent
association are separate components. Future intercept-plus-slope work must be
a separately named coefficient-block design.

**Noether.** The mathematical review confirmed the fitted decomposition but
caught that post-draw `scale()` made the simulated phylogenetic slopes differ
from the exact `N(0, 0.18^2 A)` contract, and that the verifier checked strings
more strongly than the fit. The scaling was removed and the verifier now
inspects the integrated fitted object's design, random blocks, extractor,
convergence, and gradient. Any future article must name and verify the estimand
for each term before showing syntax.

**Pat.** The first independent user review returned REVISE because the data
were hidden, plotting code was exposed, and planted lines looked like fitted
evidence. After the corrections, Pat returned PASS with no remaining blocking
or important issue.

**Florence.** Native-resolution review caught the earlier subtitle clipping and
then required the community line plot to state that its thick and thin lines
are planted simulation values. Figure review must inspect both geometry and
the claim encoded in the title.

**Rose.** A valid formula is not enough for a public tutorial. The closure
verifier now guards the scientific decomposition and the reader presentation,
not only successful rendering.

**Grace.** Pkgdown must render against the current package build. A temporary
library is a safer local proof than relying on whatever package version is
installed globally.

## 12. Cross-Product Coverage

This documentation-only correction covers the Gaussian long-format
phylogenetic slope, fixed pathway interaction, and ordinary latent-site
combination shown in the article. It does NOT cover wide column-slope grammar,
non-Gaussian or mixed families, response-column intercept-plus-slope blocks,
latent predictor covariance, simultaneous response-column sources, or
intervals.
