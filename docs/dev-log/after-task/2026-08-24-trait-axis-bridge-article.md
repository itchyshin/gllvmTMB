# After Task: Trait-axis bridge article

**Branch**: `codex/trait-axis-bridge`
**Date**: 2026-08-24
**Roles (engaged)**: Ada, Boole, Noether, Curie, Florence, Pat, Rose, Grace

## 1. Goal

Add a Tier-1, visual, reproducible article that lets an ecology graduate student decide whether a phylogeny relates species units, species response columns, or neither. The shared simulated montane-bird story connects a comparative trait model, a Gaussian community-gradient model, and a compact three-source iSDM declaration without claiming a new model capability.

## 2. Implemented

`where-does-the-tree-go.Rmd` is a visual bridge article with four rendered figures: an axis decision map, comparative trajectories, response-column slopes plus predictor-basis covariance, and source-specific observation models. A seeded installed fixture supplies the trees and data. The article uses a source-current stable comparative formula and the covered Gaussian multi-predictor `phylo_slope()` route; it keeps iSDM source labels out of phylogenetic geometry. Pkgdown now links the article in Model Guides.

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE, roxygen, or generated Rd changes. The article documents the already-covered Gaussian long-format response-column slope route (validation-debt rows FG-15 and RE-03) and its existing Gaussian-only boundary.

## 3. Files Changed

- `data-raw/examples/make-trait-axis-bridge.R`: deterministic fixture generator.
- `inst/extdata/examples/trait-axis-bridge.rds`: installed simulated data and trees.
- `dev/trait-axis-bridge/verify-formulas.R`: three source-current smoke gates.
- `dev/trait-axis-bridge/verify-article.R`: render, navigation, and pkgdown gate.
- `dev/trait-axis-bridge/verify-scope.R`: reader-surface boundary scan.
- `vignettes/articles/where-does-the-tree-go.Rmd`: article and four figures.
- `_pkgdown.yml`: Model Guides navigation entry.
- `docs/dev-log/check-log.md` and this report: durable closeout receipt.

`README.md`, `NEWS.md`, `ROADMAP.md`, design documents, roxygen, `man/`, and `NAMESPACE` were inspected and intentionally not changed: this PR adds teaching material, not an API or implementation.

## 3a. Decisions and Rejected Alternatives

**Decision:** use `phylo_indep(0 + trait | species, tree = tree) + phylo_slope(elevation | species, tree = tree)` for the PCM example. **Rationale:** it converges cleanly and says exactly what the article needs: trait-specific phylogenetic intercept variation plus one shared phylogenetically structured species-slope variance. **Rejected:** the initially proposed augmented `phylo_indep(0 + trait + (0 + trait):elevation | species, ...)` beginner formula. It is parser-valid, but estimates four separate intercept--slope covariance blocks and gave an `nlminb` false-convergence warning on this fixture. Teaching it would obscure the axis question. **Confidence:** high, from source-current smoke fits and formula review.

## 4. Checks Run

```sh
Rscript --vanilla dev/trait-axis-bridge/verify-formulas.R --pcm
# PASS: PCM_FORMULA_GATE_OK
Rscript --vanilla dev/trait-axis-bridge/verify-formulas.R --column-slope
# PASS: COLUMN_SLOPE_FORMULA_GATE_OK
Rscript --vanilla dev/trait-axis-bridge/verify-formulas.R --isdm-source
# PASS: ISDM_SOURCE_GATE_OK
Rscript --vanilla dev/trait-axis-bridge/verify-scope.R
# PASS: SCOPE SCAN PASS
Rscript --vanilla -e 'devtools::test(filter = "phylo-column-slope-indep")'
# PASS: 39 tests; 0 failures and warnings; 2 intentionally skipped heavy tests.
Rscript --vanilla dev/trait-axis-bridge/verify-article.R
# PASS: pkgdown::check_pkgdown() reports "No problems found"; ARTICLE BUILD PASS.
git diff --check
# PASS: no whitespace errors.
```

The article was also rendered from current source with `devtools::load_all()` to `/private/tmp/trait-axis-bridge-render-v4`; Florence inspected the four PNG files, not just the R code.

**Deliberately not run:** a full package check or recovery campaign (the PR does not change an estimator); Totoro/DRAC; non-Gaussian multi-predictor fits; or any new wide-format/slope-only implementation.

## 5. Tests of the Tests

The three formula scripts exercise the exact calls printed in the article, including their intended axes. `verify-scope.R` refuses the old survey `0 +` workaround, internal validation IDs, and missing scope boundaries. The article gate renders in a new R environment after `load_all()`, so an installed package cannot accidentally stand in for the branch under review. The existing `phylo-column-slope-indep` regression suite remains green against the example syntax.

## 6. Consistency Audit

```sh
rg -n 'phylo_slope\(.*\| trait|Gaussian only|non-Gaussian multi-predictor|0 \+ observer|po_source\(' vignettes/articles/where-does-the-tree-go.Rmd
# PASS: the article names only the covered Gaussian helper and its deferred non-Gaussian boundary; no old survey workaround or po_source() surface.
rg -n 'FG-[0-9]|FAM-[0-9]|RE-[0-9]|ISDM-[0-9]' vignettes/articles/where-does-the-tree-go.Rmd
# PASS: no internal validation-register identifiers appear on the reader surface.
rg -n 'phylo_slope\(elevation \+ forest_cover|phylo_slope\(.*\| trait|0 \+ observer|non-Gaussian.*multi-predictor|Gaussian only' README.md NEWS.md ROADMAP.md docs vignettes
# PASS: surrounding public and internal surfaces agree that the route is Gaussian and long-format; the article does not change their status.
```

## 7. Roadmap Tick

**Roadmap tick**: N/A. This is a documentation bridge for an already-landed capability; no `ROADMAP.md` delivery row changed.

## 7a. GitHub Issue Ledger

Inspected [#1196](https://github.com/itchyshin/gllvmTMB/issues/1196), which is closed and supplied the already-landed column-slope scope. No issue was created, commented on, or closed: this PR adds a teaching bridge without advancing the deferred wide or non-Gaussian work.

## 8. What Did Not Go Smoothly

The first article render exposed two failures that code-only review missed: the axis/source diagrams were cramped, and the PCM plot mixed incomparable raw trait scales in domain facets. The figures were redesigned as direct flows and four within-column-standardised small multiples. The first rich PCM formula also converged poorly; the final formula is smaller and matches the stated shared-slope scientific contract.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Ada:** preserved the isolated worktree boundary and turned visual requirements into explicit gates rather than treating a successful render as completion.

**Boole:** verified public formula paths and caught that a parser-valid augmented formula would communicate a different covariance model from the article's intended one.

**Noether:** checked the distinction between tree-among-species units, tree-among-response columns, predictor-basis `Sigma_slope`, and source-masked observation effects.

**Curie:** supplied the seeded fixture and executable smoke gates so printed calls are live regression checks rather than pseudocode.

**Florence:** rejected the first render on visual evidence: clipping and scale conflation changed the scientific reading. The revised figures pass only after inspection at rendered article size.

**Pat:** confirmed that the repeated front-door question and final three-way rule make the tree axis recoverable before a reader interprets a formula.

**Rose:** kept the capability boundary visible—Gaussian, long-format response-column slopes only; iSDM declarations do not identify abundance, occupancy, or detectability.

**Grace:** verified source-current rendering and pkgdown navigation; no compiled code, dependency, or generated-reference surface changed.

## 10. Known Limitations And Next Actions

The article deliberately does not provide block-specific morphology versus life-history slope covariance, a wide-column predictor grammar, spatial/kernel or latent slope-only variants, or non-Gaussian multi-predictor response-column slopes. A later issue must decide those APIs before this article is extended. The immediate next action is PR review and three-OS CI; after merge, record its SHA and CI receipt in the handover.
