# After-task — SDM collection audit, repeated-visits article, Paper × Items re-aim

Date: 2026-08-16 · Platform: Claude · Lane: `claude/sdm-repeated-survey-20260816`.

## Scope

Maintainer-directed continuation of the SDM collection: (1) a fifth article
(repeated survey visits); (2) a four-lens editorial audit of every article
under the Species Distribution Models menu, with fixes; (3) site cleanup
(labels, titles, menus); (4) a maintainer-directed rewrite of the LA-MSPL
Paper × Items article around ridge and MSPL as matched remedies.

## Outcome

### New article: `integrated-repeated-visits.Rmd`

Visit-varying conditions on the survey branch (cloglog scale), probed before
writing: the machinery fits and all three coefficient families recover
(β 0.05 / γ 0.09 / δ 0.11 max abs err, PASS/PASS). Includes the
4-visits-vs-1-visit demonstration (one-draw, hedged as such) and the
occupancy-model boundary (MacKenzie et al. 2002; Royle & Nichols 2003;
Guillera-Arroita 2017 — all publisher-verified). The two-source article is
renamed "…with a designed survey" to keep subjects distinct.

### The audit (Pat · Rose · Fisher · Florence · Ada, 7 articles)

Four read-only Sonnet children + one inline coherence pass. 11 blockers and
~20 should-fixes found; all fixed in this lane. Highlights:

- **Fisher (re-ran every article's code):** the two-source and survey-design
  articles' displayed equations omitted the per-species reporting level
  `rho_s` (`trait:isdm_gbif`) that their code fits — the identification
  device the package itself warns about. Equations and prose corrected.
  Verified clean: all cloglog thinning forms, offsets, gating columns, seeds;
  the repeated-visits "δ acts as support scaling" claim proven algebraically.
- **Rose:** two articles still claimed "more than two sources: not available"
  — false since #1030; corrected with cross-links. The WARN-fit maintainer
  comment (internal apparatus) replaced by a neutral guard; the decision
  record stays in `docs/dev-log/decisions.md`. Experimental banner added to
  the new article; interval-bucket taxonomy normalised.
- **Pat:** `pd_hessian`, "support", `cloglog`, Fisher-z now glossed at first
  use everywhere; health-check outcomes stated after every
  `check_gllvmTMB()` chunk; the worst run-on sentences split; survey-design
  gains a See-also.
- **Florence:** joint-sdm's two `caption = NULL` calls deleted the notes
  explaining the significance outlines and display-scaled arrows — restored
  in captions; spatial-models' two uncaptioned figures captioned with alt
  text; fig.alt added across 8 chunks; `asp = 1` and non-overlapping labels
  on identity-line plots; the design-curve legend uses plain words.

### The Paper × Items re-aim (`mspl-binary-jsdm.Rmd`, same URL)

Maintainer-directed (a Site × Species duplicate was declined as too
similar). Grounded in an evidence-map-shaped corpus (60 papers × 8 binary
items, probit, d = 2 — mirroring the original urbanisation_map application).
Structure decided by probing, not assumption:

- Loading-runaway demo: at this design, plain LA-ML converged (code 0) with
  max|Λ̂| 61–144 against a true max ~4–6 on **all 8 seeds tried**;
  `loading_ridge = 2` returned every one to truth scale with clean
  convergence. Article shows one median seed and cites the internal probit
  calibration with its regime (the logit small-p corner stated).
- Separation demo: `screen_gllvmTMB()` certificate, then three routes on the
  same corpus — ML slope runaway, **ridge slope still runaway (the negative
  result: remedies don't cross)**, MSPL finite.
- MSPL fences restated from the original article; ridge+MSPL refusal noted;
  AGHQ mentioned with its large-n boundary ("at this corpus size it is the
  ridge doing the visible work").
- Check-log note posted to the cursor MSPL lanes (their article; rewrite was
  maintainer-directed; their R/, tests, and the source-pin issue untouched).

## Checks

- All 8 touched articles re-render end-to-end, chunks evaluated
  (joint-sdm 12 s · gbif 5 s · two-source 12 s · survey-design 4 s ·
  multi-source 4 s · repeated-visits 72 s · spatial 7 s · mspl 20 s).
- `pkgdown::check_pkgdown()`: no problems found.
- Rose re-check dispatched on the re-aimed article (claims vs recorded
  ridge/AGHQ evidence); findings folded in before commit.
- No `R/`, `src/`, or test changes anywhere in this lane.

## Merge plan

Two commits: (i) docs-class (new article + audit fixes + menus + NEWS) —
self-merge on CI green per the repo rule; (ii) the `mspl-binary-jsdm.Rmd`
rewrite — a broad article rewrite, 🔴 held for the maintainer's merge
decision in the PR.

## Follow-ups

- The MSPL source-pin test remains red on `main` (cursor lanes'; flagged
  twice now).
- Florence's suggestion to expose axis labels in `plot.gllvmTMBmesh()` is an
  R/-side change — left for a package-code lane.
- Terminology nit ("relative intensity" vs "relative ecological intensity")
  left as-is; a global normalisation pass is low-value churn.
