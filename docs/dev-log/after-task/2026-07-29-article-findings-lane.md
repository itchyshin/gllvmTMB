# After-task — article-findings lane, 2026-07-29

`PLATFORM: claude | LANE: article-findings | FOREIGN LANE: none in this repo (a Codex lane was
live in drmTMB throughout — different repo, no collision)`

Branch `claude/article-findings-20260729`, merged as **PR #814** (`7c4ceca9`). Follow-up to
#805. Closes the 8 findings that lane left open.

## 1. Goal

Adjudicate — not merely fix — the 8 open findings in
`docs/dev-log/2026-07-28-article-executable-honesty-ledger.md`, each against the primary source,
running a fit where the claim was about runtime behaviour.

## 2. Implemented

**8 adjudicated: 6 fixed, 2 refuted.**

| # | Finding | Outcome |
|---|---|---|
| 6 | `response-families.Rmd` operated on `mixed_long`, defined **nowhere in the repo** | fixed — built it in the article's own idiom |
| 8 | `api-keyword-grid.Rmd` prescribed `level = "kernel"` | fixed — kernel tiers are addressed by the tier's `name` |
| 9 | `api-keyword-grid.Rmd` claimed `||` for all four sources | fixed — `kernel_latent` is the one exception |
| 7 | `covariance-correlation.Rmd` printed `residual = FALSE` (deprecated alias) | fixed — notes the current spelling |
| 12 | `covariance-correlation.Rmd` called `part = "unique"` "a named numeric vector" | fixed — it returns a **list**; the vector is `$s` |
| 11 | `response-families.Rmd` said rootograms support "Poisson and NB2" | fixed — NB1 too; an **under-claim** |
| 10 | `joint-sdm.Rmd` pointed at "the fit message" | fixed — the article sets `message = FALSE`, so it is never shown. Replaced the pointer with the reason |
| 4 | `joint-sdm.Rmd`: "Wald is not implemented for communality… falls back to bootstrap" | **REFUTED** — it is implemented and does not fall back |
| 5 | `joint-sdm.Rmd`: "profile bounds… return `NA`" | conclusion right, **mechanism wrong** — it *errors* |

Two **code** changes, both message-only:

* `R/brms-sugar.R` — the `||` rejection message restated its supported list by hand and had
  **drifted**, omitting `kernel_indep`, `kernel_dep`, `spatial_indep`, `spatial_dep`, all present
  in `.uncorr_marked` eight lines above. It now derives from the same vectors as the guard.
* (from the prior lane, same class) `R/diagnose.R` — recommended a soft-deprecated start.

## 3. Decisions

Front-loaded nothing; worked the findings in order, one at a time, at Shinichi's instruction.
Ran a real single-trial binary JSDM for the ICC pair rather than reasoning about them.

## 3a. Decisions and Rejected Alternatives

| Decision | Rejected alternative | Why |
|---|---|---|
| Build `mixed_long` in the article | Note it as a reader-supplied placeholder | The chunk's first statement *operates on* the object (`mixed_long$family <- ...`), which errors immediately. That is a broken example, not a sketch |
| Verify the new example **by running it** | Ship it as `eval = FALSE` and trust it | Shipping an unverified `eval = FALSE` chunk is precisely the defect being fixed |
| Derive the `||` message from the guard vectors | Restate the corrected list | A hand-written list drifted once and would drift again. Derivation makes it impossible, not merely fixed |
| Guard only "operated on", not "passed as `data =`" | Flag both | `df_wide` / `dat_long` in syntax sketches are placeholders the reader substitutes. Flagging them made the guard noisy enough to ignore |
| Rewrote findings 4 and 5 as one accurate limitation | Leave them; or fix 5 only | 4 was false in the *under*-claiming direction — leaving it would keep telling readers a working method does not work |
| Did **not** fix the profile route itself | Implement it here | Out of scope for a documentation lane and a real piece of work. Filed as issue #813 |

## 4. Files Touched

Articles: `response-families.Rmd`, `api-keyword-grid.Rmd`, `covariance-correlation.Rmd`,
`joint-sdm.Rmd`. Code: `R/brms-sugar.R` (message text only). Tests (new):
`test-uncorrelated-bar-support.R`, plus a third `test_that` in
`test-article-prescribed-calls.R`. Records: the ledger and #805's after-task report, both
corrected.

No lane collision: zero file overlap with #803, #804, #807, or #812. Never `git add -A`.

## 5. Checks Run

* Full `devtools::test()` → **6,454 passed, 773 skipped, 0 failed** (zero `Failure (`/`Error (`
  markers; no `══ Failed` section).
* `rcmdcheck(args = "--as-cran")` on **merged `main`** (`2a6f4c49`, i.e. after #812 too) →
  **0 errors / 0 warnings / 1 note**, the note being the unavoidable `New submission`.
* **`pkgdown::build_site()` → exit 0, 20 articles rendered, zero errors.** This is the first
  execution of any article edited in this lane or #805 — `vignettes/articles` is
  `.Rbuildignore`d and the pkgdown workflow only fires post-merge.
* The Fisher-z fix from #805 **verified in the rendered HTML**: `lower`/`upper` are finite
  (`0.752…`, `0.855…`, `method = fisher-z`) where they were `NA` before.
* The `mixed_long` example verified by running it — `logLik -212.107`.

**NOT run:** cross-OS checks. Everything above is macOS-local.

## 6. Tests of the Tests

The undefined-object guard took **four iterations, each caught by insisting it fail on the known
defect first**:

1. A general undefined-symbol lint flagged **162** chunk-lines — unusable, mostly NSE column
   names inside `data.frame()`/`aes()`.
2. Narrowing to data objects gave 8, but scored **zero on the pre-fix file**: it treated
   `x$col <- v` as *defining* `x`, when in R that **errors** if `x` is absent. Vacuous for
   exactly the defect it targeted.
3. Flagging "used before defined" re-added noise — a weaker, separate defect.
4. Dropped `data = x` as a syntax-sketch placeholder; tracked function formals.

Final: **2 flags on the pre-fix file, 0 after, no false positives across all 20 articles.**

Counting the prior lane, that is **five guard tests in two days that passed vacuously before
being made to fail first.** A static check over a corpus defaults toward finding nothing, and
"no findings" is indistinguishable from "clean". Fail-first should be treated as mandatory for
this class, not as good practice.

## 7a. Issue Ledger

All 8 closed. Filed **#813** — implement profile-likelihood intervals for communality.
`profile_communality()` already exists (`R/profile-derived-curves.R:542`, unexported); #679's
delta_deviance baseline defect is already fixed; what remains is an exact constraint solver,
convergence propagation, boundary semantics, and calibration.

## 8. Consistency Audit

* Rendered `main` site: 20/20 articles build; no residual `method = "profile"` prescription on
  any correlation call.
* `||` message and `.uncorr_marked` now agree by construction (11 keywords), pinned by test.
* Rootogram doc and `R/enum.R` agree: poisson (2L), nbinom2 (5L), nbinom1 (15L).

## 9. What Did Not Go Smoothly

**I recorded a false justification in #805's after-task report**, and it was load-bearing. I
wrote that `extract_communality()` "does accept `method = "profile"` and does not abort
(`R/extractors.R:207,214`)" — used to argue the article "may be right". The abort is at
**`R/extractors.R:268`**, ~50 lines below where I stopped reading. The deferral decision was
right (the findings genuinely needed a fit); the reason given for it was wrong.

That is the **second** instance in two days of the same failure: read far enough to confirm the
expected answer, then stop. The first was generalising a two-word polarity check into a
five-word claim, where the one genuine overclaim on the whole surface sat in a word I never
opened — and was found by a different lane, not by me. Both are now corrected in the merged
record rather than only noted in chat.

## 10. Known Residuals

* **VA/R3 prototype tests on CRAN.** #812's stated goal — "stop CRAN building parked
  prototypes" — is delivered for the EVA template but only partly for VA/R3: **8 of 27
  `test_that` blocks** in `test-va-r3-prototype.R` carry `skip_on_cran()`. Not a correctness
  problem (merged `main` checks clean); it is CRAN build time spent on explicitly parked code.
  **Maintainer decision, 2026-07-29: deferred — "we will deal with this later, not implemented
  generally for now."** No issue filed, by that instruction.
* #813 open.
* No cross-OS verification of anything in this lane.

## 11. Team Learning

* **Doc investigation is a good probe for code defects.** Two of the four articles examined
  turned up a *code* defect underneath the documentation one — the drifted `||` support list and
  (prior lane) the `R/diagnose.R` hint. Asking "is what this says true?" reaches places that
  asking "does this run?" does not.
* **This surface under-claims more than it over-claims.** Three of eight findings were the
  package describing itself as less capable than it is: the rootogram NB1 omission, the refuted
  Wald claim, and a message naming four fewer supported keywords than the guard allows. That
  matches drmTMB's audit exactly and is worth carrying as a prior for the next doc pass.
* **A green pkgdown build proves execution, not truth.** All 20 articles rendered clean both
  before and after — every one of the 13 findings was a claim that *ran fine* and said something
  false. The build is necessary and not remotely sufficient.

## 12. Cross-Product Coverage

**Covers:** the 8 open findings from #805's ledger, each adjudicated against the primary source;
static resolvability and undefined-object guards over all 20 articles; the `||` support set;
merged-state `R CMD check --as-cran`; a full pkgdown build.

**Does NOT cover:**

* **Prose accuracy generally.** The two guards adjudicate the invalid-call and undefined-object
  classes only. Most of the 13 findings across both lanes were prose claims no static parser can
  settle — they were caught by reading and by fitting, neither of which is automated.
* `missing-data.Rmd` — lane 3's (#804), untouched here.
* The 136 unfenced `man/*.Rd` pages: swept for register codes only in #805; `\examples{}`
  blocks never checked in either lane.
* **Cross-OS.** macOS only. The 3-OS matrix is a release-time step and was not run.
* Whether the *rendered numbers* in any article are scientifically right — the build proves the
  code executes and the Fisher-z bounds are finite, not that any estimate is correct.
* The VA/R3 CRAN-skip gap above, deferred by maintainer decision.
