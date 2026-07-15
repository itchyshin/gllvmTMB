# Doc-honesty review checklist — turnkey prep for the Phase F pass with Shinichi

**Date:** 2026-07-15 · **Author:** Claude (Lane 2, parallel work menu) · **Purpose:**
Phase F of `docs/dev-log/2026-07-13-gap-closure-ultraplan.md` ("doc-honesty one-by-one
review WITH Shinichi... Not codeable — a deliberate session with Shinichi, page by
page") is the standing gate before any 0.6 CRAN submission. This file turns that
cold-start review into an approve/tweak pass: every article and every honesty-sensitive
export is enumerated with its current claim, a fence assessment, and (where a gap
exists) exact proposed wording. **This file does not rewrite any article** — it is
input to the session, not a substitute for it.

**Headline finding:** the existing prose is already extensively fenced — most rows
below are "fence needed: N" because the honesty language the three rules below call
for is already present, in force, and consistent across articles. There are **three
concrete gaps** (all nbinom2-related, all downstream of Lane A's 2026-07-13
dispersion-confound diagnosis, which post-dates the current prose) and **one
pre-existing maintainer decision** (the animal-model article cut). See §4 for the
gaps and §6 for the decision queue.

## 1. The three fencing rules applied

1. **Intervals — recovery-only, not coverage-certified.** No surface may state or
   imply calibrated repeated-sampling coverage until the Design-66 coverage grid
   earns a certificate for that cell. "Recovery" language (point estimate close to a
   known simulated truth) is fine; "calibrated," "coverage-certified," or an
   unqualified "confidence interval" without a recovery/calibration caveat is not.
2. **nbinom2 — known dispersion/latent-variance confound, recovery-only.** Per
   `docs/dev-log/2026-07-13-nbinom2-dispersion-literature.md` (grounded synthesis) and
   `docs/dev-log/handover/2026-07-15-parallel-lane-handover.md` §2 Item 1: NB2
   dispersion (phi) and latent/random-effect variance are a documented weak-identifiability
   pair (Lawless 1987; Bolker's GLMM FAQ) with a literature-corroborated small-sample
   upward bias in phi (Lloyd-Smith 2007; Saha & Paul 2005). Lane A's mitigation ladder
   shows default per-trait phi recovers Sigma at median 0.45-0.52x truth; this is a
   known, literature-grounded confound, not a bug, and not yet resolved for the
   package's default (per-trait) parameterization. **Any nbinom2-adjacent claim about
   Sigma/covariance recovery needs this caveat**; nbinom2 intervals stay recovery-only
   until Item 1 (shared/pooled dispersion) lands and re-earns a coverage cell.
3. **delta/hurdle latent-scale correlation — do not advertise as a response-scale
   claim.** The package computes and returns a latent-scale correlation for delta/hurdle
   families (tagged `interval_status = "conditional_on_occurrence"` in
   `extract_correlations()`), but this is a route-only / computed-quantity claim, not
   a covered or calibrated one, and it must never be described as a correlation of the
   observed two-part response (e.g. "correlation of total biomass").
4. **Standing rule — no internal register codes on reader-facing surfaces.** No
   `CI-08`, `CI-10`, `validation_status` slugs, or other internal validation-register
   codes may appear in articles, roxygen/reference pages, NEWS, or printed output.

## 2. Register-code leak scan (done; clean)

```
grep -rniE "CI-0[0-9]|CI-1[0-9]|validation_status|register.?tier" \
  vignettes/*.Rmd vignettes/articles/*.Rmd man/*.Rd NEWS.md
```

Result: **no leaks**. The register codes (`CI-08`, `CI-10`, `RE-12;CI-11`, etc.) live
only in `R/profile-route-matrix.R` (an internal routing table, never printed to the
user) and one code comment in `R/extract-correlations.R:96` (`## ... (validation-register
CI-08 / CI-10) ...`, a comment, not a string surfaced to users). This row needs no
maintainer action; re-run the grep above as a final pre-submission gate (see §7).

## 3. Article-by-article checklist (18 surfaces: 1 main vignette + 17 articles)

Legend: **Fence needed** = does this page need new/changed honesty language beyond
what is already there. **Decision** = does landing the fence (or not) require a
maintainer call rather than being a mechanical wording tweak.

| # | File | Topic (one line) | Current claim (representative quote) | Fence needed | Decision needed |
|---|---|---|---|---|---|
| 1 | `vignettes/gllvmTMB.Rmd` | Getting-started Gaussian model + numerical health + covariance read | "a general summary because interval calibration depends on the fitted target and \[is not\] calibrated" (L323-326); cor-plot/cor-matrix captions state points are descriptive, "interval routes are target-specific and opt-in" | N — already fenced | N |
| 2 | `vignettes/articles/api-keyword-grid.Rmd` | Formula keyword grid (long + `traits()` wide) | No interval/coverage claims (a syntax-translation reference); one incidental "coverage" use (L331) is about *design* replication, not statistical interval coverage — no ambiguity risk | N | N |
| 3 | `vignettes/articles/behavioural-syndromes.Rmd` | Repeated-measures Gaussian: between/within covariance + repeatability | "does not establish confidence-interval calibration" (L29); "does not establish interval coverage" (L314); "article does not establish interval calibration" (L389) | N — already fenced | N |
| 4 | `vignettes/articles/convergence-start-values.Rmd` | Diagnosing hard fits, start/optimiser strategies | "this article does not claim uniform interval coverage... treat those intervals as an audit trail until the relevant family and target have coverage evidence" (L275-278) | N — already fenced | N |
| 5 | `vignettes/articles/covariance-correlation.Rmd` | Technical reference: Sigma/Lambda/Psi, liability-scale conventions | "empirical coverage has not been calibrated and they do not establish repeated-sampling coverage" (L429-430) for Fisher-z bounds | N — already fenced | N |
| 6 | `vignettes/articles/fit-diagnostics.Rmd` | Fit-health signals before interpreting covariance/uncertainty | "not a formal calibration test" (L244); "not... a certificate that every inferential target is calibrated" (L36); predictive-check table explicitly excludes "interval calibration" from what the check covers (L332-334) | N — already fenced | N |
| 7 | `vignettes/articles/fixed-effect-zero-constraints.Rmd` | Response-specific predictor effects, intentional zero coefficients | No interval/coverage claims found (fixed-effect structure only, not a covariance/interval page) | N | N |
| 8 | `vignettes/articles/gllvm-vocabulary.Rmd` | Glossary: covariance pieces, grouping tiers, uncertainty language | Wald/profile/bootstrap/Fisher-z glossary entries each carry "treat this as a sensitivity interval... not... a repeated-sampling... coverage guarantee" (L269-277) | N — already fenced | N |
| 9 | `vignettes/articles/joint-sdm.Rmd` | Binary JSDM, residual co-occurrence, liability-scale correlation | "package-wide calibrated-coverage work is still open... no binary or mixed-family covariance interval has reached nominal coverage" (L238-241); "do not present these intervals as coverage-certified" (L400-401) | N — already fenced (this is the strongest existing template for the nbinom2 wording below) | N |
| 10 | `vignettes/articles/missing-data.Rmd` | omitted / retained / `mi()`-modelled missing-value workflows | "posterior interval, or evidence of calibrated interval coverage" explicitly disclaimed (L195); open scope note names "interval coverage across missingness mechanisms, response families, covariance..." as future work (L288) | N — already fenced | N |
| 11 | `vignettes/articles/model-selection-latent-rank.Rmd` | Choosing latent rank via ML/IC + fit-health, not by AIC alone | "not backed by a repeated-sampling coverage" claim (L42); "coverage is not yet calibrated for these models, so treat them as indicative rather than a calibrated decision rule" (L436-437) | N — already fenced | N |
| 12 | `vignettes/articles/morphometrics.Rmd` | Simplest Gaussian GLLVM, cached bootstrap confidence-eye figure | "do not establish calibrated coverage across other sample sizes or model structures" (L36); "Use a larger bootstrap run before making a final interval-calibration claim" (fig caption L322) | N — already fenced | N |
| 13 | `vignettes/articles/phylogenetic-gllvm.Rmd` | Phylogenetically structured trait covariance | "calibrated confidence-interval coverage for source-specific covariance... \[is open\]" (L344); "not a coverage study" for the split-depth example (L669) | N — already fenced | N |
| 14 | `vignettes/articles/pitfalls.Rmd` | Six common data/formula/covariance/interpretation mistakes | No interval/coverage claims in the pitfalls list itself (troubleshooting page, not an inference-target page) — spot-check during the live session that none of the six pitfalls implicitly overclaims calibration | N (spot-check only) | N |
| 15 | `vignettes/articles/pre-fit-response-screening.Rmd` | Prevalence/sparse-outcome screening before fitting binary traits | One incidental "interval" use is a prevalence display interval, not a statistical CI (L131) — no fencing needed | N | N |
| 16 | `vignettes/articles/profile-likelihood-ci.Rmd` | Profile/Wald/bootstrap route selection, `confint_inspect()` | Whole-article frame: "keeping returned bounds separate from coverage claims" (subtitle); "not currently... a claim about empirical coverage" (L51); "has not been broadly calibrated for every boundary regime" (L179) — the best-built fencing page in the set | N — already fenced (reference template) | N |
| 17 | `vignettes/articles/random-regression-reaction-norms.Rmd` | Random-slope reaction norms, intercept-slope covariance | "does not establish calibrated intervals or a general rank-selection" claim (L29) | N — already fenced | N |
| 18 | `vignettes/articles/response-families.Rmd` | Choosing a response family; specialist boundaries | Hurdle boundary already fenced: "do not describe fitted-tier correlations as correlations of total biomass, abundance, or another observed two-part response" (L314-316). **nbinom2 row (L124) carries NO dispersion-confound caveat** — see gap G1 below | **Y — G1 (nbinom2)** | N (mechanical addition, template exists at row 9/16) |

## 4. Concrete gaps found (3, all nbinom2; all new since Lane A's 2026-07-13 diagnosis)

None of these are disagreements with existing fencing — the existing fencing is sound.
These are additions the diagnosis surfaced that the prose has not caught up to yet.

### G1 — `vignettes/articles/response-families.Rmd`, L124 (family-selection table row)

**Current:** `| Overdispersion that grows approximately quadratically with the mean |`
`nbinom2()`; log | `Var(Y) = mu + mu^2 / phi` |` — no caveat.

**Recommended addition** (new sentence after the family table, following the existing
"Specialist boundary" pattern used for hurdle families at L302-316):

> ### Specialist note for `nbinom2()` with latent covariance
>
> When `nbinom2()` is combined with a latent covariance term, the per-trait NB
> dispersion (phi) and the latent/random-effect variance are a documented
> weak-identifiability pair (Lawless 1987; the GLMM FAQ's residual/random-effect
> confounding warning) with a literature-corroborated small-sample upward bias in the
> dispersion MLE (Lloyd-Smith 2007; Saha & Paul 2005). With the package's default
> per-trait dispersion, Sigma recovery is attenuated at practical sample sizes; this is
> a known confound, not a defect, and it is not yet resolved for the default
> parameterization. Treat nbinom2 covariance/correlation estimates as recovery-only and
> do not present nbinom2 intervals as coverage-certified.

Fence needed: **Y**. Decision needed: **N** — this is a mechanical, template-matched
addition (mirrors row 9/16's already-approved fencing language); no new editorial
judgment call for the maintainer, just landing it.

### G2 — `man/families.Rd` (roxygen for `nbinom2()`, L166-167)

**Current:** `The \code{nbinom2} negative binomial parameterization is the NB2 where the`
`variance grows quadratically with the mean (Hilbe 2011).` — statistical definition
only, no caveat, no cross-reference to G1.

**Recommended addition** (append to the `nbinom2` paragraph in `families.Rd`):

> When combined with a latent covariance term, per-trait NB dispersion and latent
> variance are weakly identifiable and covariance recovery is attenuated at practical
> sample sizes (see the response-families article's nbinom2 specialist note). Treat
> nbinom2-adjacent covariance/correlation output as recovery-only.

Fence needed: **Y**. Decision needed: **N** — same mechanical addition, roxygen mirror
of G1; regenerate via `devtools::document()`, do not hand-edit `man/families.Rd`.

### G3 — `man/extract_Sigma.Rd`, L172 (per-family sigma-derivation table)

**Current:** `\code{nbinom2(link = "log")} \tab \eqn{\sigma^2_d = \psi'(\hat\phi)} where`
`\eqn{\hat\phi} is the per-trait NB2 dispersion \cr` — states the derivation formula
only, no caveat that phi itself is the confounded quantity.

**Recommended addition** (one sentence in the Details section, near the existing
non-Gaussian caveat block at L139-151, which already says "interval calibration has
been established across covariance tiers" is not the case generally):

> For `nbinom2`, `phi_hat` is itself subject to the known dispersion/latent-variance
> identifiability confound (see `families.Rd` / the response-families article); the
> derived `sigma^2_d` inherits that attenuation and should be read as recovery-only.

Fence needed: **Y**. Decision needed: **N** — mechanical, template-matched (this Rd
already has the surrounding non-Gaussian caveat infrastructure; this just extends it
to name nbinom2 specifically).

**Ship order for G1-G3:** land G1 (article) first as the canonical statement, then G2
and G3 as roxygen cross-references to it — avoids three independently-worded versions
of the same caveat drifting apart. All three become moot (or get upgraded to
"recovery-demonstrated, shared-dispersion mode") if/when Item 1 (shared `disp.formula`,
per the parallel-lane handover) lands and re-earns a coverage cell for nbinom2.

## 5. Honesty-sensitive export checklist (14 exports)

All 14 already carry adequate fencing; no wording gaps found. Listed for completeness
so the review session confirms rather than re-derives this.

| Export | man page | Current claim (representative) | Fence needed |
|---|---|---|---|
| `extract_correlations()` | `extract_correlations.Rd` | Returns `interval_status` claim-boundary marker (`"none"`, `"heuristic_unvalidated"`, `"target_specific_uncalibrated"`, `"conditional_on_occurrence"` for delta/hurdle); "interval calibration has been established across covariance tiers" explicitly negated (L143); Fisher-z bounds flagged "not a calibrated mixed-model standard error" (L151) | N |
| `extract_Sigma()` | `extract_Sigma.Rd` | Per-family sigma-derivation table; non-Gaussian caveat block present | **Y — G3** (see §4) |
| `extract_Sigma_B()` / `extract_Sigma_W()` | resp. `.Rd` | Thin wrappers over `extract_Sigma()`; no independent interval claims | N |
| `extract_Sigma_table()` | `extract_Sigma_table.Rd` | Documents the `interval_status` column it passes through | N |
| `extract_communality()` | `extract_communality.Rd` | "is not automatically coverage-calibrated" (L43) | N |
| `extract_lv_effects()` | `extract_lv_effects.Rd` | "Broad repeated-sampling coverage has not been established, so finite bounds remain experimental rather than nominally calibrated" (L64-65) | N |
| `extract_repeatability()` | `extract_repeatability.Rd` | Wald route documented as delta-method Gaussian approximation, no overclaim | N |
| `bootstrap_Sigma()` | `bootstrap_Sigma.Rd` | "Non-Gaussian bootstrap calibration remains experimental until the M3 target-explicit grid is rerun" (L97-98) | N |
| `confint.gllvmTMB_multi()` | `confint.gllvmTMB_multi.Rd` | "reference distribution and coverage remain target-specific" (L142); "derived-target coverage are not universally calibrated" (L159) | N |
| `confint_inspect()` | `confint_inspect.Rd` | "does not establish empirical interval coverage" (L91); explicitly excludes nbinom2 example target (`"phi_nbinom2[2]"`) from "goodness or calibration certificate" framing (L21, L85) | N |
| `predictive_check()` | `predictive_check.Rd` | "interval-calibration, or Bayesian posterior-predictive tests. PLANNED" — explicitly scoped out (L78-79) | N |
| `diagnostic_table()` | `diagnostic_table.Rd` | "or calibrate uncertainty. PLANNED" (L39) | N |
| `profile_targets()` | `profile_targets.Rd` | "Broader target-explicit profile calibration remains future work" (L61) | N |
| `Families()` / `nbinom2()` | `families.Rd` | Statistical definition only, no dispersion-confound cross-reference | **Y — G2** (see §4) |

## 6. Maintainer decision queue

Only the rows below need a human call — everything else in §3-§5 is either already
correct or a mechanical wording landing with a pre-approved template.

1. **QG `animal-model` article — cut vs. keep.** Per `CLAUDE.md`: open PR #746 proposes
   cutting the animal-model article (2 cut, 26 improved, pkgdown reorganised); the file
   is already absent from this working tree's `vignettes/articles/` (no
   `animal-model.Rmd` present), consistent with the PR's cut, but the PR itself is open
   / not merged, so the decision is not yet ratified. `animal_latent()` /
   `animal_slope()` / `animal_dep()` / `animal_indep()` remain live exports referenced
   from `api-keyword-grid.Rmd` and the reference index ("Source-specific covariance
   keywords") regardless of the article's fate — confirm whether losing the dedicated
   walkthrough leaves those exports adequately discoverable via the keyword-grid +
   reference-page route, or whether the article should be restored/rewritten instead of
   cut.
2. **G1-G3 nbinom2 wording — approve the exact sentence, not just the fact.** The facts
   (weak identifiability, small-sample bias direction, current per-trait
   parameterization) are literature-grounded per
   `docs/dev-log/2026-07-13-nbinom2-dispersion-literature.md`, but the *phrasing* and
   *placement* (new "Specialist note" subsection vs. folding into the existing hurdle
   specialist-boundary section; article-first vs. roxygen-first) is a voice/structure
   call for the maintainer, not a mechanical one — flagged Y above only for
   "fence needed," not "decision needed," but worth a quick look together since it is
   new prose rather than a copy of an approved template.
3. **Timing relative to Item 1 (shared dispersion).** If the parallel-lane's Item 1
   (`disp_group=` shared dispersion, per
   `docs/dev-log/handover/2026-07-15-parallel-lane-handover.md`) lands before the
   Phase F session, G1-G3 wording should describe the *default* (per-trait,
   confounded) mode and the *opt-in* (shared, potentially coverage-earning) mode
   separately rather than a single blanket caveat — confirm sequencing with the
   maintainer before landing G1-G3 if Item 1's timeline is close.

## 7. How to run this review

Work through §3 top to bottom with the rendered pkgdown site open next to the source
`.Rmd` (`pkgdown::build_article("articles/<name>")` per page, or the full
`pkgdown::build_site()` if several pages are queued) so the maintainer reads the same
prose a CRAN user would see, not raw R Markdown. For each row, the fast path is:
confirm the quoted fencing still matches the live text (articles are 0.5-cycle "cover
everything" work and may have moved since this audit), approve or tweak in place, and
tick it off. For the three G1-G3 gaps, land the article version (G1) first, get it
approved, then mechanically mirror the same sentence into `families.Rd` (G2) and
`extract_Sigma.Rd` (G3) via `roxygen2::roxygenise()` / `devtools::document()` rather
than hand-editing the generated `man/*.Rd` files. Close with the register-code grep in
§2 one more time as the final pre-submission gate, and file the outcome as an
after-task report in `docs/dev-log/after-task/` per the repo's closure rule.
