# Session Handoff: public iSDM fitting interface + example article

Meta: 2026-08-15 · from Claude (frontier session, context-deep) · target Claude
(fresh lane) · maintainer-directed reprioritisation

```text
🎯 GOAL
Solo platform: Claude. Maintainer has ALREADY authorised the API change in
  principle ("we just want to be able to fit a model"); final name/signature
  ratified at this lane's first checkpoint.
Deliverable: (1) an EXPORTED, documented, lifecycle-experimental user route
  for the two-source integrated fit, wrapping the internal developer entry
  without changing the likelihood or the 5x3 formula grammar; (2) the small
  worked example article rewired to the public route.
HEADLINE: users must be able to fit the integrated model through a public,
  documented front door -- not gllvmTMB:::.gll_isdm_fit.
IN PARALLEL: none -- single focused lane.
DEFER: A3 crossing campaign (pre-run done, launch PARKED by maintainer);
  Kristen's articles and storyboard framings (hers alone); frontier/methods
  writing; Paper 2; detector R/ integration.
DISCIPLINE: verify=focused tests + document() locally, full check routed to
  Totoro, D-43 panel before any capability-promotion wording · compute=Mac
  LIGHT (other lanes loaded), Totoro for anything heavy · closure=exported
  route + green tests + article renders through the public interface.
LANE: NEW branch off codex/isdm-range-amplitude-orthogonal (carries the
  article draft + all evidence), e.g. claude/isdm-public-api-20260815.
```

## Alignment record (maintainer, this evening -- binding)

1. **Public interface FIRST**; the article demonstrates it. The `:::` call in
   the current article draft is the thing being eliminated.
2. **Article framings stay AWAY from Kristen's storyboards** (global insect
   gradients / NA integrated insects are HER projects). Our articles are
   small simulated "cousin" examples -- the songbird-guild framing is
   approved. Same later for the article-2 counterpart: NA is fine, questions
   must differ, data simulated/hybrid/inspired.
3. gllvmTMB's role: ship engines that can RUN her projects; upload related
   smaller versions only.
4. A3 crossing campaign parked (bundles + pre-run intact on Totoro).

## Design sketch (ratify at first checkpoint, then build)

- **Shape**: exported wrapper `fit_isdm(data, covariates, bias, mesh, d = 1,
  spatial = TRUE, control = gllvmTMBcontrol(), ...)` over
  `.gll_isdm_fit()` (R/isdm-developer-fit.R). A separate entry point, NOT a
  new keyword: the 5x3 grammar stays untouched (highest-risk class avoided).
  Alternative name `gllvmTMB_isdm()`; maintainer picks.
- The internal route's exact two-source contract and validators stay; error
  messages become reader-facing (no internal register vocabulary). The
  "not admitted here" fence text in R/fit-multi.R:149-156 is updated so the
  exported wrapper is the sanctioned public path.
- **Docs**: roxygen with lifecycle::badge("experimental"), the
  relative-intensity boundaries (no absolute abundance/occupancy/
  detectability), the rows/X/B schema, a small runnable example.
- **Tests**: schema-validation errors; one small smoke fit
  (skip_if_not_installed("TMB")); article-level render is the integration
  test.
- **NEWS**: experimental-entry note, honest scope.
- **Article**: vignettes/articles/integrated-two-source-example.Rmd exists
  (this branch, registered in _pkgdown.yml under "Data integration
  (experimental)"). Rewire the fit chunk to the public route. Known state:
  renders clean, converges; gamma recovery on the single seed is noisy
  (signs right, magnitudes rough) -- the surrounding prose already reads the
  output honestly. Do NOT keep tuning the seed; smallness is the point.
- **Checks**: devtools::document() + focused testthat locally (LIGHT on this
  Mac -- other lanes are loaded); R CMD check on Totoro if wanted before
  merge. Merge needs maintainer (API class).

## Rehydrate (in order)

1. This handover.
2. R/isdm-developer-fit.R (the wrapped entry; note the unforgeable spatial
   admission token -- the wrapper must go THROUGH .gll_isdm_fit, never
   re-implement it).
3. vignettes/articles/integrated-two-source-example.Rmd + _pkgdown.yml:123.
4. dev/isdm-package-recovery/2026-08-15-domain-growth-results.md (the design
   guidance the article's caution #1 cites).

## Do not touch

Kristen's staging articles (dev/isdm-package-recovery/article-staging/ and
two-paper-staging/ narrative docs); sealed roots; the A3 bundles/pre-run on
Totoro; the 5x3 keyword grid; anything in the frontier campaign machinery.

Paste-ready prompt:

```text
cd "/Users/z3437171/Dropbox/Github Local/gllvmTMB" && claude "Read docs/dev-log/handover/2026-08-15-claude-handover-isdm-public-api.md from branch codex/isdm-range-amplitude-orthogonal (fetch origin). Create the new lane branch it names, run lane preflight, ratify the API name/signature with me at the first checkpoint, then build the exported route, tests, docs, and rewire the example article."
```
