# Final Pat audit — 13 retained articles

Date: 2026-07-12  
Lens: applied reader, rendered desktop/mobile surface  
Method: forced-render timestamps, rendered DOM/output, local-link and fragment checks, figure/alt-text inspection, and source/render anchor comparison. No article source was edited in this pass.

| Rendered page | Verdict | Applied-reader finding |
|---|---|---|
| `fit-diagnostics` | **PASS** | Purpose and next decision are immediate; both long and wide fits run and agree. Fit-health, lifecycle/parser, no-SE, Q-Q, and rootogram warnings are visible and bounded. Both figures have useful alt text and retain the mobile `wide-scientific-figure` class. Links, headings, and render are current. |
| `convergence-start-values` | **PASS** | Clearly separates point stationarity from Hessian/Wald inference, runs matching long/wide fits, displays `pd_hessian = FALSE` and no-SE warnings, and gives a practical escalation ladder. The latent `unique =` argument is explained as an argument, not a fifth mode. Links and render are current; no mobile blocker found. |
| `pre-fit-response-screening` | **PASS** | The wide and canonical long screens run and agree. Every `FAIL`, `WARN`, recommendation, denominator, and retained-warning decision is visible with a next action. Scope limits are explicit, code-output tables scroll, and links/render are current. |
| `pitfalls` | **PASS** | Metadata and body now agree on six checks. The page routes readers to optimiser status and raw gradient, with scaled gradient secondary; errors and rules of thumb are concrete. Long-only use is justified with a link to side-by-side syntax. No deprecated covariance function or stale render remains. |
| `profile-likelihood-ci` | **PASS** | Starts from the reader's route question, runs equivalent long/wide fits, inventories direct targets, labels Wald fallbacks and unavailable bounds honestly, and supplies a troubleshooting table with safe actions. Boundary and coverage limitations are explicit. All local links/fragments resolve; tables remain usable on desktop and mobile. |
| `missing-data` | **PASS** | Separates missing responses from one modelled missing predictor, states the ignorability assumption before code, and runs wide/long versions of both workflows. Extractor outputs preserve row provenance and uncertainty limits. Unsupported routes and alternatives are plainly named; links and render are current. |
| `gllvm-vocabulary` | **PASS** | Functions as a glossary rather than pretending to be a worked tutorial. Long/wide formula shapes, covariance tiers/modes, scale, identification, fit health, and missingness terms are defined in applied language with forward links. No internal validation codes or deprecated covariance teaching appears. |
| `api-keyword-grid` | **PASS** | Visibly teaches exactly four modes—Scalar, Independent, Dependent, and Latent—using a horizontally scrollable grid. Deprecated `unique()` helpers are absent; the current `unique =` latent argument is explicitly distinguished from a fifth mode/deprecated function. Long/wide syntax and incompatibility rules are clear; all links resolve. |
| `fixed-effect-zero-constraints` | **PASS** | Names the structural-zero question, distinguishes exact constraints from shrinkage/selection, runs matching long/wide fits, and shows fixed-row output plus error-specific next actions. Unsupported non-zero/REML cases are explicit. No stale API or mobile obstruction found. |
| `response-families` | **PASS** | Family choice begins from response support and sampling process, uses responsive lookup tables, runs equivalent long/wide Poisson fits, and clearly marks when mixed families require long data. Hurdle/covariance and uncertainty boundaries are explicit, with diagnostic next steps and current links. |
| `phylogenetic-gllvm` | **PASS** | Both the 150- and 500-species long/wide examples visibly use `phylo_latent(..., unique = TRUE)`. Shared Lambda-Lambda-transpose, diagonal Psi, and total covariance are aligned term-by-term; no `phylo_dep()`/`phylo_indep()` main-route wording or internal codes remain. Recovery is honestly framed: the 150-species total recovers better than its pieces, while the 500-species phylogenetic shared and Psi errors (`0.732`, `0.862`) are explicitly called weak separation despite healthy numerics. Both five-column alignment tables now render inside `.table-responsive` containers, preserving readable horizontal scrolling on narrow screens. Source and forced render are synchronized. |
| `behavioural-syndromes` | **PASS** | The scientific purpose, replicated design, long/wide equivalence, full warning table, covariance/repeatability recovery, and alt text all pass. The two-panel covariance chunk now uses `fig.class="wide-scientific-figure"`; the rebuilt DOM retains that class, so the 680-pixel mobile drawing width remains readable inside the horizontally scrollable figure container. |
| `random-regression-reaction-norms` | **PASS** | The design requirement, long/wide equivalence, complete health table, blockwise recovery, pointwise repeatability, reporting limits, and alt text all pass. The recovery chunk now retains `wide-scientific-figure` in the rebuilt DOM. Its two-row legend shows `intercept-intercept`, `intercept-slope`, and `slope-slope` completely in the generated desktop PNG, with no right-edge clipping. |

## Cross-estate result

- **PASS:** 13 pages.
- **FAIL:** 0 pages.
- All 13 HTML files are newer than their sources after the forced non-lazy rebuild.
- All relative page/reference links and the checked profile fragment resolve.
- No internal validation IDs/register prose or deprecated covariance-function teaching appears outside explicit deprecation clarification.

## Remaining blockers

None. The final phylogenetic article passed a fresh
`pkgdown::build_article(..., lazy = FALSE)` render. Both responsive wrappers,
their five-column tables, statistical route, recovery framing, API wording, and
source/render timestamps were checked after the rebuild.
