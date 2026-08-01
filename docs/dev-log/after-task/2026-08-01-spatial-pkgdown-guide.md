# After Task: Spatial pkgdown guide and licensing acknowledgement

## 1. Goal

Give applied ecology, evolution, and environmental-science users one public
Tier-1 page that shows how to build and inspect a gllvmTMB SPDE mesh, fit the
same Gaussian spatial model from long and wide data, interpret the isotropic
practical range, and understand the exact sdmTMB acknowledgement and GPL-3
code-provenance boundary.

## 2. Implemented

- Added `vignettes/articles/spatial-models.Rmd` as a Tier-1 worked guide.
- Added the guide to the Model Guides navbar and article index.
- Linked the guide from the README status table, README acknowledgement,
  get-started vignette, and neighbouring joint-SDM article.
- Rendered and visually inspected the opening and the
  independence/acknowledgement/licensing section.
- Stated the dependency boundary directly: sdmTMB inspired the original
  user-facing spatial interface, but gllvmTMB does not import, link to, or
  include sdmTMB and does not adapt sdmTMB source code.

### Mathematical Contract

The worked model is

\[
y_{it} = \alpha_t + u_t(s_i) + \varepsilon_{it},
\]

where `spatial_indep()` gives each trait an independent field and fixes
cross-trait spatial covariance to zero. The article maps the mesh matrices to

\[
Q(\kappa) = \kappa^4 M_0 + 2\kappa^2 M_1 + M_2
\]

and maps the practical range to `sqrt(8) / kappa`. The long syntax is
`spatial_indep(0 + trait | site)` with an explicit `trait = "trait"`; the wide
`traits(...)` syntax is `spatial_indep(1 | site)`. The rendered example reports
convergence zero for both calls and identical log likelihoods
(`-431.4045`). It reports a true practical range of `0.3` and fitted point
estimate `0.2216269`, explicitly without claiming unbiasedness or calibrated
coverage.

## 3a. Decisions and Rejected Alternatives

> **Decision**: publish one dedicated Tier-1 spatial model guide now.
> **Rationale**: the independent helper implementation is already merged and
> tested, while the public site previously exposed only scattered reference
> syntax and acknowledgements. A worked page makes the existing capability and
> its boundary usable from the reader's seat.
> **Rejected alternative**: a licensing-only page, because it would explain
> provenance without teaching the mesh and model that make the provenance
> relevant.
> **Confidence**: high.

> **Decision**: keep sdmTMB as a courtesy acknowledgement, not a bibliography
> requirement or code-provenance statement.
> **Rationale**: `DESCRIPTION`, `NAMESPACE`, the independently authored helper
> sources, and `inst/COPYRIGHTS` show that sdmTMB is not a runtime/build
> dependency and no sdmTMB source is included or adapted.
> **Rejected alternative**: removing every sdmTMB mention, because that would
> erase honest interface inspiration and the single-response sister-package
> boundary.
> **Confidence**: high.

> **Decision**: document the existing row-aligned mesh projection contract for
> wide data rather than changing `make_mesh()` or fitting code in a docs PR.
> **Rationale**: the explicit stacked coordinate frame is correct and was
> exercised during rendering; changing mesh ingestion would be a separate API
> and implementation task.
> **Rejected alternative**: silently construct the mesh on one-row-per-site
> wide data, which produces a projection-row mismatch against the internally
> stacked responses.
> **Confidence**: high.

## 4. Files Touched

Public reader surface:

- `vignettes/articles/spatial-models.Rmd` -- new Tier-1 worked guide.
- `_pkgdown.yml` -- Model Guides navbar and article-index registration.
- `README.md` -- spatial-guide status row and acknowledgement cross-link.
- `vignettes/gllvmTMB.Rmd` -- next-guide route and explicit dependency wording.
- `vignettes/articles/joint-sdm.Rmd` -- forward link from the non-spatial JSDM
  boundary to the spatial guide.

Closure records:

- `docs/dev-log/check-log.md`.
- `docs/dev-log/after-task/2026-08-01-spatial-pkgdown-guide.md`.

No R function, TMB likelihood, formula grammar, generated Rd file, package
metadata, validation-register status, NEWS capability claim, or roadmap status
changed. `devtools::document()` regenerated one trailing blank line in
`man/plot_anisotropy.Rd`; that mechanical difference was removed, leaving the
Rd file byte-identical to `origin/main`.

## 5. Checks Run

```sh
Rscript --vanilla -e 'pkgdown::build_article("articles/spatial-models", lazy = FALSE, new_process = TRUE, quiet = FALSE)'
```

PASS. Both fitted models converged; the article produced
`pkgdown-site/articles/spatial-models.html`.

```sh
Rscript --vanilla -e 'devtools::test(filter = "article-prescribed-calls|mesh|utm-conversions", stop_on_failure = TRUE)'
```

PASS: 60 expectations, zero failures, warnings, or skips.

```sh
Rscript --vanilla -e 'pkgdown::check_pkgdown()'
Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE, quiet = TRUE)'
```

PASS: pkgdown reported no problems and the complete article set rebuilt.

```sh
Rscript --vanilla -e 'devtools::document(quiet = TRUE)'
```

PASS with the repository's existing AIC/BIC S3 roxygen notices. No generated
documentation remains changed.

```sh
Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'
```

PASS in 12m13.9s: 0 errors, 0 warnings, and two environment notes (remote clock
verification unavailable and macOS `xcrun_db` temp detritus).

```sh
/Users/z3437171/miniconda3/bin/playwright screenshot --viewport-size='1440,1200' <local-page> <output.png>
```

PASS after browser sandbox escalation. The opening and licensing-anchor
screenshots were inspected; text, tables, navbar, code blocks, headings, and
links were readable. Screenshots are temporary verification artefacts and are
not committed.

## 6. Tests of the Tests

No new unit test was added because this PR changes documentation and navigation,
not package behaviour. The existing article-call test is the relevant
prophylactic contract: it parsed the new article's evaluated calls and would
catch misspelled or unsupported arguments. The mesh and UTM tests retain their
existing malformed-input and feature-combination coverage.

The article render is the integration test. It caught two real documentation
issues before push: the first command used the bare article slug instead of the
configured `articles/spatial-models` route, and the first range table relied on
an optional returned geometry column. The final article instead uses the
documented Matérn relation `sqrt(8) / kappa`. The render also demonstrated that
the long and compact-wide calls both converge and give identical likelihoods.

## 7a. Issue Ledger

No relevant gllvmTMB issue is closed and no new issue is needed. This is the
public documentation follow-up to merged PR #886. The separate future drmTMB
mesh/SPDE work remains tracked in drmTMB issue #881; this PR does not change
that issue's scope or status.

## 8. Consistency Audit

```sh
rg -n "sdmTMB" DESCRIPTION NAMESPACE R/mesh.R R/crs.R R/plot.R inst/COPYRIGHTS README.md vignettes/gllvmTMB.Rmd vignettes/articles/spatial-models.Rmd
```

PASS. Matches are the explicit no-dependency acknowledgement, sister-package
scope, temporary legacy `sdmTMBmesh` class bridge, and `inst/COPYRIGHTS`
boundary. There is no package dependency or included-source claim.

```sh
rg -n "inherits|inherited|derived from sdmTMB|adapted from sdmTMB|depends on sdmTMB" README.md vignettes _pkgdown.yml DESCRIPTION inst/COPYRIGHTS
```

PASS: no matches.

```sh
rg -n "gllvmTMB\\(" vignettes/articles/spatial-models.Rmd vignettes/articles/joint-sdm.Rmd vignettes/gllvmTMB.Rmd README.md
```

PASS after manual classification. Every touched long-format call supplies
`trait = "trait"`; the wide `traits(...)` call correctly omits it.

```sh
rg -n "\\bS_B\\b|\\bS_W\\b|\\\\bf S|meta_known_V|gllvmTMB_wide" vignettes/articles/spatial-models.Rmd README.md vignettes/gllvmTMB.Rmd vignettes/articles/joint-sdm.Rmd
```

PASS: no matches.

```sh
rg -n "spatial-models" _pkgdown.yml README.md vignettes/gllvmTMB.Rmd vignettes/articles/joint-sdm.Rmd pkgdown-site/articles/index.html pkgdown-site/articles/gllvmTMB.html pkgdown-site/articles/joint-sdm.html
```

PASS. Source navigation and all rebuilt neighbouring pages contain the guide.

```sh
rg -n "not a runtime or build dependency|independently authored|courtesy acknowledgement|GPL-3|SPA-01|FG-13" vignettes/articles/spatial-models.Rmd pkgdown-site/articles/spatial-models.html
```

PASS. The source and rendered page contain the same independence, licensing,
and evidence-boundary claims.

Prose-style review: PASS for the named applied reader. The page opens with a
user question, shows working code before the equation, defines each spatial
term at first use, names the coordinate/mesh failure modes, and ends with
forward links. Article-tier audit: Tier 1 PASS. Rose pre-publish: PASS; the
claims map to covered SPA-01 and partial FG-13/SPA-02, exported function names
and arguments match source, and unsupported anisotropy/barrier/spatiotemporal
states remain explicit.

### Roadmap tick

N/A. This is a public teaching and provenance page for already-merged spatial
helpers. It does not change feature status or a roadmap milestone.

No relevant gllvmTMB issue is closed and no new issue is needed. The separate
future drmTMB mesh/SPDE work remains tracked in drmTMB issue #881.

## 9. What Did Not Go Smoothly

The bare pkgdown article slug was not the configured route, so the first render
command could not locate the article. The next render reached the range summary
and exposed that its geometry return shape was not a stable display contract in
the isolated pkgdown process. Both were corrected before the complete article
rebuild. The first full-page screenshot was too tall to inspect, so verification
used two normal viewports at the opening and licensing anchor.

The after-task report was added at closeout rather than as the first branch
change. This is a process WARN under the Shannon checklist, although no work was
lost and the report is included in the same PR.

Shannon's final pre-publish census initially found one foreign lane, PR #887
(`claude/slope-per-family-20260801`), with its configured R CMD check in
progress. That check completed green and the PR merged before this branch was
published. Its only file overlap was the append-only
`docs/dev-log/check-log.md`; both complete receipts were preserved while
reconciling `origin/main`. There was no implementation, article, navigation,
or after-task-file overlap. Final Shannon verdict: PASS.

## 10. Known Residuals

This PR does **not** add or validate directional anisotropy, barriers,
spatiotemporal fields, new likelihoods, or interval calibration. The worked
fit is Gaussian `spatial_indep()` on normalized equal-distance coordinates.
The broader spatial-family evidence remains partial under FG-13 and SPA-02.

The current wide workflow requires a mesh projection aligned to the internal
row-major trait stack; the article shows how to build that coordinate frame.
Automatic one-row-per-site wide mesh expansion would require a separate API,
implementation, and test decision.

Next action: open the focused documentation PR, wait for its configured R CMD
check, merge only if green, and verify the downstream pkgdown deployment.

## 11. Team Learning

**Pat**: classified the new page as Tier 1 because it answers a first-time
reader's data/model question, fits the model early, interprets one point
estimate, shows the failure mode, and routes the next question.

**Boole**: verified the long `spatial_indep(0 + trait | site)` and compact-wide
`spatial_indep(1 | site)` syntax against the live parser rather than copying a
plausible-looking formula.

**Rose**: kept three statements distinct: independent code authorship, courtesy
for interface inspiration, and sdmTMB's sister-package scope. This avoids both
false code attribution and discourteous erasure.

**Grace**: required focused tests, article render, full article rebuild,
pkgdown consistency, visual inspection, and a no-manual package check before
the page could be called ready.

## 12. Cross-Product Coverage

This documentation arc covers the Gaussian intercept-only
`spatial_indep()` teaching cell in both long and wide data interfaces, the
`make_mesh()` projection contract, the isotropic practical-range display, and
the acknowledgement/licensing surface. It **does NOT cover** directional
anisotropy, barriers, spatiotemporal fields, random spatial slopes, non-Gaussian
recovery, interval calibration, automatic one-row-per-site wide mesh expansion,
or any change to the TMB engine. Those cells retain their existing validation
register status.
