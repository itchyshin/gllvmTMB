# Retained articles batch C — systems audit

**Date:** 2026-07-12  
**Mode:** article audit followed by the three bounded warning-visibility repairs  
**Reader:** an applied ecology or behavioural-science user choosing a response
family or fitting repeated-measures covariance

## Verdict

**PASS (3 of 3 pages).** The source and rendered pages are synchronized; API
names, long/wide examples, statistical boundaries, outputs, figures, links, and
navigation are consistent. The three initial global `warning = FALSE` blockers
and the response-family lifecycle quieting were removed. All three articles
then rebuilt without emitting a warning, error, or deprecation message.

| Page | Verdict | Evidence |
|---|---|---|
| `response-families.Rmd` | **PASS** | Source and render are synchronized. The family table matches the current response constructors and distinguishes response families from specialist or missing-predictor families. Poisson long/wide calls are paired; mixed-family data are correctly kept long because family selection is row-aligned. The link-residual and mixed-family interval boundaries are explicit. All three wide lookup tables use a horizontally scrollable wrapper with a declared minimum width. Both local links resolve and the page is indexed. Global warning and lifecycle suppression were removed; the fresh render emitted no warning. |
| `behavioural-syndromes.Rmd` | **PASS** | Source and render are synchronized. The article pairs long and `traits(...)` wide fits, separates between-individual and within-occasion covariance, avoids naming rotation-dependent axes, and limits inference to point recovery for one known Gaussian example. The fitted-versus-true figure has a specific caption and non-empty content alt text; the table and 7.2-inch figure have no obvious desktop/mobile overflow. All four local links resolve and navigation is present. Warning visibility now agrees with the section “Inspect every numerical warning”; the fresh render emitted no warning. |
| `random-regression-reaction-norms.Rmd` | **PASS** | Source and render are synchronized. The article makes within-individual environmental coverage a prerequisite, pairs long and wide fits, declares the supplied rank, reports optimizer/Hessian checks, separates intercept, slope, and cross-block recovery, and labels repeatability curves as point estimates without intervals. All three content figures render with non-empty alt text; the 9-inch recovery figure uses the wide-figure class and the other figures remain within the standard article width. Four local links and the external data-generation link resolve; navigation and sitemap entries are present. Global warning suppression was removed and the fresh render emitted no warning. |

## Cross-page checks

- **Source/render synchronization:** every HTML file is newer than its Rmd
  source and contains the current title, evidence-boundary prose, examples, and
  figure captions.
- **Internal/process prose:** no validation IDs, validation-register links,
  agent/process language, or `IN` / `PARTIAL` / `PLANNED` ledgers occur in the
  sources or rendered pages.
- **Current/deprecated API:** no deprecated covariance functions,
  `gllvmTMB_wide()`, or deprecated meta-analysis aliases occur. The
  `unique()` call in the reaction-norm guide is `base::unique()` applied to a
  data frame, not covariance syntax.
- **Long/wide teaching:** all three guides show the two data shapes where the
  model is runnable. The response-family guide explains why a per-row
  mixed-family selector requires long data.
- **Statistical boundaries:** each article says what one fitted example does
  not establish. Mixed-family covariance intervals remain point-only;
  behavioural syndrome and reaction-norm recovery do not claim interval
  calibration or automatic rank selection.
- **Examples and tests:** rendered examples are current. The focused test run
  passed all non-skipped behavioural-reaction-norm checks; mixed-family and
  within-occasion recovery tests were honestly skipped behind the heavy-test
  gate.
- **Figures and responsive layout:** behavioural syndromes has one content
  figure with explicit alt text. Reaction norms has three content figures; all
  rendered with non-empty alt text, and the widest uses
  `wide-scientific-figure`. Response-family lookup tables are wrapped in
  `overflow-x: auto` with touch scrolling. The only empty image alt belongs to
  the shared decorative pkgdown logo.
- **Links and navigation:** every local target exists; the reaction-norm
  source link returned HTTP 200. All three pages appear in the rendered article
  index and sitemap.
- **Repeated blocker resolved:** all three global `warning = FALSE` settings
  and the response-family lifecycle quieting were removed. All pages now retain
  warning visibility through knitr's default behavior.

## Commands and outcomes

```sh
# Page structure, examples, warnings, and claim boundaries
rg -n '^#{1,3} |gllvmTMB\(|traits\(|warning|error|coverage|calibrat|limitation' \
  vignettes/articles/{response-families,behavioural-syndromes,random-regression-reaction-norms}.Rmd

# Internal/process language and deprecated teaching syntax
rg --pcre2 -n '\b(?!UTF-)[A-Z]{2,5}-[0-9]{2,3}\b|validation-debt register|register row|Scope boundary|Claim boundary|\bIN:|\bPARTIAL:|\bPLANNED:|agent role|dev-log|development phase' \
  vignettes/articles/{response-families,behavioural-syndromes,random-regression-reaction-norms}.Rmd \
  pkgdown-site/articles/{response-families,behavioural-syndromes,random-regression-reaction-norms}.html
rg -n 'unique\(\)|_unique\(|gllvmTMB_wide\(|meta_known_V\(' \
  vignettes/articles/{response-families,behavioural-syndromes,random-regression-reaction-norms}.Rmd
# Outcome: zero internal/process matches. The only unique() match is the
# base-R data operation in random-regression-reaction-norms.Rmd.

# Source/render modification times and page-specific rendered markers
stat -f '%Sm %N' -t '%Y-%m-%d %H:%M:%S' \
  vignettes/articles/{response-families,behavioural-syndromes,random-regression-reaction-norms}.Rmd \
  pkgdown-site/articles/{response-families,behavioural-syndromes,random-regression-reaction-norms}.html
rg -n '<title>|<h1|Evidence boundary|Specialist boundary' \
  pkgdown-site/articles/{response-families,behavioural-syndromes,random-regression-reaction-norms}.html

# Figure, alt-text, table, and responsive-wrapper checks
rg -n '^```\{r .*fig\.|fig.cap|fig.alt|out.extra' \
  vignettes/articles/{behavioural-syndromes,random-regression-reaction-norms}.Rmd
rg -n '<img |table-responsive|wide-scientific-figure|overflow-x|min-width' \
  pkgdown-site/articles/{response-families,behavioural-syndromes,random-regression-reaction-norms}.html

# Focused contract tests
Rscript --vanilla -e 'devtools::test(filter = "example-behavioural-reaction-norm|re09-latent-unique-unit|m1-2-mixed-family-fixture", reporter = "summary")'
# Outcome: exit 0; 64 non-skipped behavioural-reaction-norm expectations
# passed. Seven recovery/fixture checks skipped behind the declared heavy gate.

# Links and navigation
for page in fit-diagnostics api-keyword-grid model-selection-latent-rank \
  missing-data convergence-start-values behavioural-syndromes; do
  test -f "pkgdown-site/articles/${page}.html"
done
curl -L -sS -o /dev/null -w '%{http_code}\n' \
  https://github.com/itchyshin/gllvmTMB/blob/main/data-raw/examples/make-behavioural-reaction-norm-example.R
rg -n 'response-families|behavioural-syndromes|random-regression-reaction-norms' \
  pkgdown-site/articles/index.html pkgdown-site/sitemap.xml

# Rebuild the three repaired pages with warnings and lifecycle notices visible
set -o pipefail
Rscript --vanilla -e 'for (x in c("articles/response-families", "articles/behavioural-syndromes", "articles/random-regression-reaction-norms")) { message("BUILD ", x); pkgdown::build_article(x, pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE) }' \
  2>&1 | tee /tmp/gllvmtmb-batch-c-render.log
rg -n -i 'warning|error|execution halted|deprecated' \
  /tmp/gllvmtmb-batch-c-render.log
# Outcome: build exit 0 for all three pages; the final scan returned no matches.
```

## Blocker resolution

Removed global `warning = FALSE` from all three source articles and removed
`options(lifecycle_verbosity = "quiet")` from `response-families.Rmd`. No local
suppression was needed: every article rendered successfully with both warning
channels visible, and the captured output contained no warning, error, or
deprecation message.
