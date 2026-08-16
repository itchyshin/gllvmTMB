# After-task — documentation lane: diagnostics article, Cox–Reid proposal, slope-article staging

Lane: `claude/doc-lane-diag-reml-slopes-20260816` (Claude, off `origin/main`
@ `ab75dea3`). Ultra-planned; three team lenses (statistical, usability,
sequencing) consulted before scoping; maintainer chose the scope (all three
documentation slices in one lane, no engine code, no compute).

## 1. Goal

Answer "lanes cover MSPL / missing data / iSDM — should random slopes,
diagnostics, or non-Gaussian REML start next?" with a lane that ships the
cheap top slice of each candidate while routing every compute-shaped
follow-on into one Design 66 scoping conversation.

## 2. Implemented

1. **`vignettes/articles/fit-diagnostics.Rmd` extended** (prose/tables only,
   zero new code chunks): pre-fit screening pointer with the threshold
   checks framed advisory and the separation module framed as a formal
   fixed-design certificate; `optimizer_convergence` / `pd_hessian` honesty
   paragraph ("optimizer stopped appropriately", not "near truth");
   ordinal-degeneracy caveat (no calibrated detector exists; points to
   Current limits); family-exactness table for `residuals()` (exact RQR:
   Gaussian/Poisson/NB2; NB1 implemented with shallower evidence; every
   other family retained with `status = "unsupported_family"` — no
   automatic fallback); "Coming From DHARMa" conceptual mapping with
   explicit non-equivalence language.
2. **`docs/design/121-coxreid-validation-slice.md`** (new): pre-registered
   PROPOSAL for the non-Gaussian Cox–Reid REML validation slice — 3 arms
   (Laplace-ML / Laplace+Cox–Reid / AGHQ-ML), ridge asymmetry named and
   pinned, binomial + `ordinal_probit`, 8 cells × ~100 seeds ≈ 2,400 fits,
   kill criteria K1–K4 with an MCSE governance clause, a pre-registered
   non-convergence rule, a redesigned nuisance-reparametrisation probe
   (arm D reparametrises `b_fix`, the actual nuisance block), and the
   D-139 pre-run test spec. Explicitly NOT an authorised campaign; cells
   are candidates for the Design 66 grid.
3. **Slope article recovered + staged:**
   `dev/held-articles/random-slopes-nongaussian.Rmd` (490 lines, recovered
   from `eacbd0f6^`; parked, not in the build), README provenance entry,
   and `docs/dev-log/2026-08-16-slope-article-reader-path-staging.md` — an
   11-claim audit (4 KEEP / 6 REWORD / 1 CUT) against RE-14/PHY-11/PHY-16/
   RE-03/CI-08/CI-10, a cross-link audit (one dead link), and a decision
   list for the joint unhide review.

## 3a. Decisions and Rejected Alternatives

- **Extend `fit-diagnostics.Rmd`, not a new article** — a new
  `model-checking.Rmd` collided with the existing 29-article estate
  (Rose plan-review, BLOCKING); integrate-before-adding rule.
- **REML roxygen honesty note: deferred, then landed on maintainer
  direction** — `R/gllvmTMB.R` is hot (7 foreign non-doc commits in 2
  weeks), so the first commit staged the text in Design 121 §7 only; the
  maintainer then directed it applied, and a follow-up commit adds the
  comment-block-only paragraph to `@param REML` with `man/gllvmTMB.Rd`
  regenerated (`devtools::document()`; the unrelated `predict_missing.Rd`
  regeneration it also produced was reverted — pre-existing drift, another
  lane's to land).
- **No numeric false-positive rate in the article** — the "25 %" separation
  figure is an internal, non-audited measurement; qualitative framing only.
- **Rejected:** any #897 detector work (NO-SHIP 2026-08-14 respected); any
  slope evidence campaign or Cox–Reid run (routed to Design 66); unhiding
  the slope article in this lane (gated on joint review).

## 4. Files Touched

- `vignettes/articles/fit-diagnostics.Rmd` (extended, ~49 lines net + review fixes)
- `docs/design/121-coxreid-validation-slice.md` (new)
- `dev/held-articles/random-slopes-nongaussian.Rmd` (recovered, parked)
- `dev/held-articles/README.md` (provenance entry)
- `docs/dev-log/2026-08-16-slope-article-reader-path-staging.md` (new)
- `docs/dev-log/after-task/2026-08-16-doc-lane-diag-reml-slopes.md` (this report)
- `R/gllvmTMB.R` (follow-up commit: `@param REML` roxygen paragraph only) +
  `man/gllvmTMB.Rd` (regenerated)
- NOT touched: `_pkgdown.yml`, any code path, any test, any export.

## 5. Checks Run

- `rmarkdown::render("fit-diagnostics.Rmd")` — clean, all 25 chunks
  executed, twice (after the build slice and again after review fixes).
- Mechanical verify (Haiku): 6/6 PASS — files non-empty, fence greps
  (DHARMa non-equivalence, no FP percentage, ordinal honesty, convergence
  honesty), `git status` scoped to intended files, recovered article absent
  from `_pkgdown.yml`/`vignettes/`, cited paths resolve.
- Opus adversarial review: SHIP-WITH-FIXES on all three artifacts; all 18
  findings applied (see §9) or dispositioned (fix 5 → flagged to owning
  lane; fix 6 → render artifact excluded from commit).

## 6. Tests of the Tests

The claim-audit itself was spot-verified: the reviewer independently
confirmed 5 of 11 checklist verdicts against source, including the CUT
(the recovered article's "300 sites … BLUPs correlate > 0.8" sentence is
fabricated — the cited test asserts only structural wiring at 150 sites).

## 7a. Issue Ledger

- #897: untouched, fence respected; the article now states the ordinal
  detector gap honestly.
- Register drift flagged (not fixed, other lane owns it): DIA-12 and the
  `residuals()` roxygen still say Gaussian/Poisson/NB2 while
  `R/predictive-diagnostics.R:426-440` implements an exact NB1 route with a
  smoke test — register-behind-code, surfaced via check-log.
- New maintainer decisions needed: see Known Residuals.

## 8. Consistency Audit

Article claims cross-checked against DIA-11/DIA-12/DIA-14 verbatim; Design
121 citations re-derived against the worktree with anchor+quote style;
checklist rewords carry no register codes on proposed reader-facing prose
(standing rule; maintainer removed 14 such sites at `42d7452f`).

## 9. What Did Not Go Smoothly

- The Opus review found real defects the builders missed: a "fallback"
  claim the code does not implement; a named `converged` row that does not
  exist in `check_gllvmTMB()`'s table; an ordinal prescription pointing at
  unevidenced tools; and — the strongest catch — Design 121's arm D
  reparametrised the *interest* block while claiming to test Reid–Fraser
  *nuisance* non-invariance, a guaranteed-null probe that pre-registration
  would have baked in. All fixed. Lesson recorded in §11.
- Session resume dropped the named builder agents, so review fixes were
  applied by the orchestrator directly.
- The plan's premise of "two held slope articles" was wrong — there is one,
  and it was deleted rather than held; recovered from history instead.

## 10. Known Residuals

- 🔴 **Needs Shinichi (three items):** (1) Design 66 scoping — Design 121's
  cells + the slope evidence cells + the VA-vs-Laplace study compete for
  one seed budget; (2) the slope-article joint reader review (decision list
  in the staging checklist; recommended option: unhide with rewordings);
  (3) whether the Design 121 pre-run test (48 fits) is approved.
- `fit-diagnostics.Rmd` has 5 unlanded foreign refs touching it (two
  condense the same sections); merge-order to reconcile at landing.
- NB1 register/roxygen drift (flagged, unowned).
- `man/predict_missing.Rd` is regeneration-stale on main (documenting
  reorders it); left for the owning lane.

## 11. Team Learning

When an article describes what a function does, *read the function* — the
review's two article catches were mechanism-description errors, not
evidence-hedging errors. And a pre-registered design deserves adversarial
statistical review *before* it reaches the maintainer: pre-registration
converts a wrong probe from "fixable later" into "baked in."

## 11b. Same-day follow-on (maintainer-directed, autonomous)

Shinichi approved all three staged decisions in order:

1. **Design 121 pre-run test RAN** (48/48 fits, 21.8 min, smoke-first,
   ridge pinned `Inf` — `aghq_ridge = 0` is invalid in the live package, a
   §2 correction). Findings: full-run estimate **18.2 h** (not 3–10 h),
   driven by arm C (AGHQ k=7: 69.9 s/fit mean, 345 s max, **9/16
   converged — below the 70% bar**); arms A/B ~6 s/fit, 100% convergence;
   2-seed medians show Cox–Reid nudging bias *away* from zero (direction
   only, not evidence); one reproducible degenerate binomial cell
   (T=8, n=100, seed 2, ratio ~7.7, identical in A and B —
   Cox–Reid-orthogonal). `dev/coxreid-prerun/RESULTS.md`; Design 121
   §4/§8 updated to MEASURED.
2. **Slope article unhidden with rewordings** (option 2 executed): 6
   rewords + 1 cut applied verbatim from the checklist, dead link
   retargeted to `spatial-models.html`, moved into `vignettes/articles/`
   + Model Guides index/navbar (append-only), renders clean (<1 min —
   heavy grid chunks are `eval = FALSE` by the article's chunk policy).
3. **Design 66 scoping one-pager written**
   (`docs/dev-log/2026-08-16-design66-scoping-onepager.md`): three
   claimants, one seed budget, decision boxes; recommends VA-vs-Laplace
   first, the Cox–Reid **A+B half at 100 seeds (~2.7 h Totoro)** second
   with arm C held pending a ridge/k decision, slope cells third.

## 12. Cross-Product Coverage

drmTMB's Cox–Reid measurement is cited as prior only; nothing here claims
transfer. GLLVM.jl untouched (Julia bridge remains ML-only).
