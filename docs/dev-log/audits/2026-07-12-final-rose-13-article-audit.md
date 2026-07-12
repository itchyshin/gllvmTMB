# Final Rose audit — 13 retained articles

**Date:** 2026-07-12  
**Mode:** read-only Rose pre-publish consistency gate after one forced,
non-lazy rebuild of all 13 pages  
**Reader:** an applied ecology, evolution, or behavioural-science user entering
the package through the public pkgdown site

## Verdict

**PASS (13 of 13).** All 13 source/render pairs rebuilt successfully and are
synchronized. No global warning or lifecycle suppression, internal
validation/process prose, stale covariance terminology, broken local links,
navigation gaps, missing generated images, fatal rendered output, or
long-format trait-naming violation remains. The three initial Option-A naming
blockers were repaired and both affected pages then rebuilt successfully.

| Page | Verdict | Rose evidence |
|---|---|---|
| `fit-diagnostics.Rmd` | **PASS** | Fresh HTML is newer than source; title, code, output, links, index, sitemap, and generated figures are intact. Current long/wide syntax, fit-health thresholds, warning visibility, and inference boundaries are mutually consistent. |
| `convergence-start-values.Rmd` | **PASS** | Fresh HTML is synchronized and complete. Raw-gradient, Hessian, profile, bootstrap, and `latent(..., unique = FALSE)` statements agree with the other retained guides; the latter is a current argument, not deprecated covariance syntax. |
| `pre-fit-response-screening.Rmd` | **PASS** | Fresh HTML is synchronized and complete. Long/wide screening calls follow the current naming convention, retained warnings are visible, and screening limits are not promoted into fit guarantees. |
| `pitfalls.Rmd` | **PASS** | Fresh HTML is synchronized and complete. Current covariance syntax, warning visibility, diagnostic hierarchy, links, and generated output pass the cross-page sweep. |
| `profile-likelihood-ci.Rmd` | **PASS** | Fresh HTML is synchronized and complete. Direct-profile, Wald-fallback, Fisher-z, bootstrap, and coverage-boundary wording does not conflict with the diagnostic or vocabulary pages. |
| `missing-data.Rmd` | **PASS** | Source and render are synchronized, complete, warning-visible, linked, and indexed. Both canonical long-format calls now pass `trait = "trait"` explicitly; the fresh non-lazy rebuild completed without warning or error. |
| `gllvm-vocabulary.Rmd` | **PASS** | Fresh HTML is synchronized and complete. The four current covariance modes, ordinary/source-specific latent defaults, long/wide entry points, and interval definitions remain consistent across the estate. |
| `api-keyword-grid.Rmd` | **PASS** | Fresh HTML is synchronized and complete. The public grid uses `indep()` rather than deprecated `unique()` constructors. `meta_known_V()` appears only once in an explicit soft-deprecation migration note followed by `meta_V()`. |
| `fixed-effect-zero-constraints.Rmd` | **PASS** | Source and render are synchronized, complete, warning-visible, linked, and indexed. The canonical long-format `fit_long` call now passes `trait = "trait"` explicitly; the fresh non-lazy rebuild completed without warning or error. |
| `response-families.Rmd` | **PASS** | Fresh HTML is synchronized and complete. Family boundaries, long/wide teaching, warning visibility, wide-table wrappers, links, and generated output pass. Its `unique(x)` call is a base-R data operation, not covariance syntax. |
| `phylogenetic-gllvm.Rmd` | **PASS** | Targeted post-rewrite recheck passed. Fresh HTML is newer than source and uses `phylo_latent(..., unique = TRUE)` as the main route in both examples; neither `phylo_dep()` nor `phylo_indep()` remains in source or render. All four long/wide fits preserve the required explicit grouping arguments, and long calls pass `trait = "trait"`. The sole covariance `unique()` mention explicitly labels the standalone function deprecated and distinguishes it from the current latent-term argument. The 150-species truth-checked example and the 500-species split example, including the rendered `Why this example uses 500 species` heading, are present. Thirteen local body links resolve; the one content figure exists and has non-empty alt text. |
| `behavioural-syndromes.Rmd` | **PASS** | Fresh HTML is synchronized and complete. Between/within covariance, long/wide calls, warning visibility, point-recovery boundaries, links, and generated figure assets agree. |
| `random-regression-reaction-norms.Rmd` | **PASS** | Fresh HTML is synchronized and complete. The long call passes the trait name through `rr$fit_args$trait`; the wide call correctly omits it. Design, rank, health, recovery, uncertainty boundaries, links, and generated figures pass. Its `unique()` call is a base-R data operation. |

## Global pattern counts

| Pattern | Count | Interpretation |
|---|---:|---|
| Forced build headers | 13 | Every requested article entered the rebuild. |
| `Output created:` records | 13 | Every build completed and wrote HTML. |
| Fatal build-log matches | 0 | No warning, error, deprecation, failed render, or halted execution was emitted. The chunk label `fit-health-warnings` was excluded from the word-boundary scan. |
| HTML newer than source | 13 / 13 | Every source/render pair is synchronized by modification time. |
| Source-title / rendered-H1 matches | 13 / 13 | Every page has the intended current title. |
| Internal validation IDs or process-prose matches | 0 source; 0 render | No register IDs, internal ledgers, agent/process labels, or dev-log prose leaked into the public pages. |
| Global `warning = FALSE` matches | 0 | Knitr warnings remain visible. |
| Global lifecycle quieting or suppression wrappers | 0 | Lifecycle and ordinary warnings are not globally hidden. |
| Deprecated covariance-constructor teaching calls | 0 | No deprecated constructor is used in example code. |
| Explicit deprecated-name migration notes | 2 | One `unique()` note and one `meta_known_V()` note; both are clearly labelled deprecated and point to current syntax. |
| Base-R `unique()` data operations | 3 | Response-family lookup, phylogenetic label extraction, and reaction-norm design deduplication; none is covariance syntax. |
| Other stale terminology matches | 0 | No obsolete trio, alias-as-primary, old covariance notation, removed-wide-API, or profile-default claim was found. |
| Long-format calls missing explicit `trait =` | 0 | The repeated Option-A convention violation was repaired. |
| Local body links checked | 163 | All resolve to generated files. The targeted phylogenetic rewrite reduced that page from 15 to 13 local links. |
| Index entries | 13 / 13 | Every retained page is listed. |
| Sitemap entries | 13 / 13 | Every retained page is indexed for publication. |
| Missing local generated images | 0 | All body image paths resolve. |
| Rendered fatal-output markers | 0 | No `Execution halted`, `Quitting from`, `Error in`, missing-object, failed-render, or 404 marker appears. |

## Option-A repair evidence

1. `vignettes/articles/missing-data.Rmd:111` now passes `trait = "trait"` to
   `fit_response_long`.
2. `vignettes/articles/missing-data.Rmd:214` now passes `trait = "trait"` to
   `fit_predictor_long`.
3. `vignettes/articles/fixed-effect-zero-constraints.Rmd:110` now passes
   `trait = "trait"` to `fit_long`.

The wide calls remain unchanged and correctly omit the long-format trait-column
argument. Existing `unit`, `unit_obs`, and `cluster` arguments were preserved.

## Commands and outcomes

```sh
# Forced rebuild evidence supplied by the final estate run
rg -c '^=== BUILD ' /tmp/gllvmtmb-13-article-rebuild.log
rg -c '^Output created:' /tmp/gllvmtmb-13-article-rebuild.log
# Outcome: 13 and 13.

rg -n -i '(^|[^[:alpha:]])(warning|error|execution halted|deprecated|failed)([^[:alpha:]]|$)' \
  /tmp/gllvmtmb-13-article-rebuild.log
# Outcome: zero matches.

# Rebuild the two repaired pages with warnings visible.
set -o pipefail
Rscript --vanilla -e 'for (x in c("articles/missing-data", "articles/fixed-effect-zero-constraints")) { message("BUILD ", x); pkgdown::build_article(x, pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE) }' \
  2>&1 | tee /tmp/gllvmtmb-final-option-a-render.log
rg -n -i '(^|[^[:alpha:]])(warning|error|execution halted|deprecated|failed)([^[:alpha:]]|$)' \
  /tmp/gllvmtmb-final-option-a-render.log
# Outcome: two builds and two outputs; exit 0; zero warning/error/deprecation matches.

pages=(fit-diagnostics convergence-start-values pre-fit-response-screening \
  pitfalls profile-likelihood-ci missing-data gllvm-vocabulary \
  api-keyword-grid fixed-effect-zero-constraints response-families \
  phylogenetic-gllvm behavioural-syndromes random-regression-reaction-norms)

# Source/render synchronization and public-content sweeps.
for slug in $pages; do
  stat -f '%m %N' "vignettes/articles/$slug.Rmd" \
    "pkgdown-site/articles/$slug.html"
  rg --pcre2 -n '\b(?!UTF-)[A-Z]{2,5}-[0-9]{2,3}\b|validation-debt register|register row|Scope boundary|Claim boundary|\bIN:|\bPARTIAL:|\bPLANNED:|agent role|dev-log|development phase|after-task|Rose|Shannon' \
    "vignettes/articles/$slug.Rmd" "pkgdown-site/articles/$slug.html"
done
# Outcome: 13 of 13 HTML files newer than source; zero internal/process matches.

for slug in $pages; do
  rg -n 'warning\s*=\s*FALSE|lifecycle_verbosity|suppressWarnings\(|suppressMessages\(' \
    "vignettes/articles/$slug.Rmd"
done
# Outcome: zero matches.

for slug in $pages; do
  rg -n 'unique\(|_unique\(|gllvmTMB_wide\(|meta_known_V\(|phylo\(|gr\(|meta\(|block_V\(|phylo_rr\(' \
    "vignettes/articles/$slug.Rmd"
done
# Outcome: three base-R unique() operations; one explicit deprecated unique()
# note; one explicit meta_known_V() migration note; zero deprecated teaching calls.

# Parsed every executable gllvmTMB()/screen_gllvmTMB() call from knitr::purl()
# and flagged non-traits() calls without a named trait argument.
# Outcome: three true omissions in two pages, plus one correctly omitted trait
# argument on the reaction-norm wide formula stored in rr$formula_wide.

# xml2 body-link and generated-image checks
# Outcome: 165 local links checked, zero broken; zero missing local images;
# every page had a non-empty H1 and generated code/output blocks.

for slug in $pages; do
  rg -n "href=\"$slug\\.html\"" pkgdown-site/articles/index.html
  rg -n "/articles/$slug\\.html" pkgdown-site/sitemap.xml
done
# Outcome: 13 of 13 index entries and 13 of 13 sitemap entries.

for slug in $pages; do
  rg -n -i 'execution halted|quitting from|error in |object .* not found|pandoc document conversion failed|failed to render|404 not found' \
    "pkgdown-site/articles/$slug.html"
done
# Outcome: zero matches.
```

## Targeted phylogenetic latent-focus recheck

After the user-directed rewrite of `phylogenetic-gllvm.Rmd`, Rose reran the
narrow source/render gate on that pair only:

- rendered HTML is 145 seconds newer than source, and its H1 matches the YAML
  title;
- source and render contain zero internal validation IDs, process prose,
  developer-note language, global warning suppression, or lifecycle quieting;
- `phylo_latent(..., unique = TRUE)` is the main and only fitted phylogenetic
  covariance route; `phylo_dep()` and `phylo_indep()` have zero source/render
  matches;
- standalone `unique()` occurs once in prose, where it is explicitly labelled
  deprecated; the executable `unique()` call is the base-R species-label data
  operation;
- parsed executable calls comprise two long and two wide `gllvmTMB()` fits.
  Both long calls pass `trait`, `unit`, and `cluster`; both wide calls pass
  `unit` and `cluster`; the split pair also preserves `unit_obs`;
- the rendered first-example H2 is `Simulate one truth-checked example`, with
  the 150-species design stated in the opening and generated code. The second
  rendered section is `Add a non-phylogenetic species component`, with the H3
  `Why this example uses 500 species` and the generated 500-species example;
- all 13 local body links resolve, the article remains in the article index and
  sitemap, and the one non-logo figure exists with non-empty, specific alt
  text; and
- no fatal-output marker occurs in the rendered HTML.

## Publication blockers

None. The final 13-page estate passes this Rose gate.
