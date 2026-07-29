# After-task — docs-honesty lane (lane 2), 2026-07-28

`PLATFORM: claude | LANE: docs-honesty | FOREIGN LANE: none detected in 12h (weak evidence, D-87)`
Branch `claude/docs-honesty-20260728`, worktree `/private/tmp/gllvmtmb-docs-honesty`, off
`origin/main` @ `869e92b5`. Pushed, not merged, no PR opened.

## 1. Goal

Audit reader-facing documentation on two axes — does it *claim* more than the evidence supports,
and does the code it *prescribes* actually work — minus lane 1's fenced set (PR #802) and minus
`missing-data.Rmd` (assigned to lane 3).

## 2. Implemented

The first axis returned a **negative result**; the second found a **blocker**.

**Honesty-fencing was largely already correct.** All 4 `certified` and effectively all 27
`calibrated` hits across 21 articles + README are *negative* constructions ("no cell's interval
coverage is certified"; "do not present these intervals as coverage-certified"). Register-code
leaks on rendered surfaces: **zero**. Version stamps consistent (`DESCRIPTION` and README both
0.6.0). The surface is broadly consistent with the WITHHELD disposition.

> 🔴 **Corrected 2026-07-29.** This section originally read "No positive assertion anywhere."
> That was an overstatement: polarity was verified for `certified` and `calibrated` only, and
> generalised to the other three words without checking them. A separate lane (PR #803) then
> found `multinomial.Rmd:234` — *"The fixed-effect route demonstrated above is **validated**"*,
> bolded and unqualified — a genuine positive overclaim in the one word I had skipped. The
> completed sweep is in §8.

**Executable honesty was not.** 15 candidates → 13 confirmed, 2 refuted. Fixed 5:

* `joint-sdm.Rmd` — cut the dead `method = "profile"` chunk and the stale prose describing the
  withdrawn behaviour; replaced with a short note in the abort's own wording; removed `"profile"`
  from the available-alternatives list and the scale caveat that applied only to it; corrected
  the "three CI methods" framing my own edit invalidated.
* `covariance-correlation.Rmd:411` — added `method = "fisher-z"` so the call produces the bounds
  four separate pieces of surrounding prose already promise.
* `convergence-start-values.Rmd:381` — checklist no longer teaches the soft-deprecated residual
  start that the same article's own §222 declares deprecated.

Added `tests/testthat/test-article-prescribed-calls.R` as the compensating static guard.

## 3. Decisions

Redirected the lane from adjective-hunting to executable honesty once the adjective sweep came
back clean — making the deliverable the measurement rather than the result. **That redirect was
right in outcome but premature in basis:** the sweep was two-thirds unfinished when I called it
clean (see §2's correction). The executable-honesty axis was still the higher-yield one, but the
decision rested on less evidence than I claimed for it. Assigned the
contested `missing-data.Rmd` to lane 3. Fixed only defects with a single defensible answer.

## 3a. Decisions and Rejected Alternatives

| Decision | Rejected alternative | Why |
|---|---|---|
| Cut the withdrawn-API section, keep a short note | Keep it marked "withdrawn"; or cut with no note | Shinichi's call. Cutting silently leaves a reader who sees `"profile"` still in the function's own choices vector with no explanation |
| Add `method = "fisher-z"` | Rewrite the prose as point-only | Shinichi's call: fix-forward. Fisher-z is genuinely available here, and the existing text already frames the bounds honestly as nominal |
| Static guard test | A CI job building articles on PRs | Standing local-checks-over-Actions rule. A static resolve-check runs in seconds; a site build is a new billable matrix job |
| Left findings 4 and 5 unfixed | Fix for completeness | Runtime claims; verifying needed a fit. 🔴 **The stated justification was WRONG** — see the correction below |
| Fixed `R/diagnose.R:1081` **after** flagging it | Fix it silently while in the area; or leave it | Printed output is a reader surface, but a message change is behaviour, not documentation — so it was surfaced as a decision rather than absorbed. Shinichi ruled it in, and it then shipped with its own guard test |
| CLAUDE.md rewritten to 0.6.0, historical references left | Replace every `0.5.0` string | The branch name `claude/release-0.5.0` and the `1.0.0 → 0.5.0` correction in PR #748 are accurate *history*. Only the forward-looking claims were wrong |

> 🔴 **Correction, 2026-07-29.** The row above originally justified deferring findings 4 and 5
> with: *"`extract_communality()` does accept `method = \"profile\"` and does not abort
> (`R/extractors.R:207,214`) — unlike `extract_correlations()`."* **That is false.**
> `extract_communality()` aborts on `method = "profile"` at **`R/extractors.R:268`**, with the
> same `gllvmTMB_nonlinear_profile_withdrawn` class as `extract_correlations()`. I read the
> formals at `:207` and the class check at `:214`/`:219`, saw no profile abort, and stopped —
> the abort is ~50 lines further down. Confirmed by running a real single-trial binary JSDM fit
> on 2026-07-29: `method = "profile"` errors, it does not return `NA`.
>
> The decision to defer was still right (both findings genuinely needed a fit), but the reason
> given for it was not. Same failure as §9 item 4: read far enough to confirm the expected
> answer, then stopped. Follow-up filed as issue #813.

## 4. Files Touched

Articles: `joint-sdm.Rmd`, `covariance-correlation.Rmd`, `convergence-start-values.Rmd`.
Code: `R/diagnose.R` (one hint string). Project doc: `CLAUDE.md`.
Tests (new): `test-article-prescribed-calls.R`, `test-no-deprecated-recommendations.R`.
Records: the verification-gap note, the ledger, this report, and the lane-3 starter.

No fenced file touched — in particular `NEWS.md`, `R/gllvmTMB.R`, `R/fit-multi.R`, and
`R/profile-ci.R` were read but never edited. `missing-data.Rmd` untouched (lane 3). Never
`git add -A`.

## 5. Checks Run

* `devtools::test(filter = "article-prescribed-calls")` → **2 passed, 0 failed**, against 0.6.0
  source via `load_all`, after the fixes.
* `devtools::test(filter = "no-deprecated-recommendations")` → **1 passed** after the
  `R/diagnose.R` fix; verified failing on exactly one offender before it.
* `devtools::test(filter = "diagnose")` → **10 passed**, covering the edited file.
* **Full `devtools::test()` → 6,372 passed, 773 skipped, 0 failed** (`EXIT=0`; zero
  `Failure (`/`Error (` markers; no `══ Failed` section). The 773 skips are the standing
  heavy-test gate (`GLLVMTMB_HEAVY_TESTS` unset). Two warnings are pre-existing and unrelated —
  "rows full of zeros in y" in `test-comparator-gllvm.R:418,449`.
* Chunk-fence balance in the edited article: 22 (even).
* `tools/lane_preflight.sh .` at lane open.

**NOT run:** `rcmdcheck`; any article knit; any model fit. The article fixes are verified by
source reading and the static guards, **not** by a build — the full suite passing says the
package is healthy, not that the articles render.

### Lane-hygiene note

`lane_preflight.sh` reported "no codex lane detected in the last 12h" and marked it *weak*
evidence. A live Codex lane was in fact running throughout (`tools/run-lane-b-phylo-dens…`,
PIDs 91194/91195) — in **drmTMB**, not this repo, so no collision. Found by `ps aux | grep
exec/R` while checking suite progress, not by the preflight. D-87 holds: silence is not proof
of sole ownership.

## 6. Tests of the Tests

The guard test was verified to **fail before the fix** (driver run, exactly 1 finding:
`joint-sdm.Rmd:318 extract_correlations(method="profile") WITHDRAWN`) and pass after.

Non-vacuity measured, not assumed: the scan parses **20 articles, 204 chunks, 3,238 calls, 303
of them gllvmTMB calls**. It is not passing on an empty set.

This section earned its place. The test passed vacuously **three separate ways** before it
worked — see §9. A guard that silently passes is worse than no guard, because it converts an
unknown into a false assurance.

## 7a. Issue Ledger

Full detail in `docs/dev-log/2026-07-28-article-executable-honesty-ledger.md`.

| Severity | Finding | Status |
|---|---|---|
| BLOCKER | `joint-sdm.Rmd:318` teaches a withdrawn API that aborts unconditionally | fixed `9ca80ba9` |
| HIGH | `covariance-correlation.Rmd:411` promises Fisher-z bounds the call cannot produce; renders empty labels under a caption asserting them | fixed `1bb5a827` |
| HIGH | `joint-sdm.Rmd:216` lists `"profile"` as available | fixed `9ca80ba9` |
| HIGH | `joint-sdm.Rmd:390` Wald/communality claim | open (runtime) |
| MEDIUM ×5 | `joint-sdm:393`, `response-families:206` (`mixed_long` never defined anywhere in the repo), `covariance-correlation:194`, `api-keyword-grid:303`, `:330` | open |
| LOW ×4 | `joint-sdm:178`, `response-families:329`, `covariance-correlation:331`, `convergence-start-values:381` | 1 fixed, 3 open |
| refuted ×2 | `api-keyword-grid:269`; `gllvm-vocabulary:342` | not defects |

## 8. Consistency Audit

* Overclaim vocabulary across `vignettes/` + `README.md`. **Polarity now verified for all five
  words** (originally only two were checked — see the correction in §2):
  * `certified` 4 — all negative.
  * `calibrated` 27 — all negative.
  * `guarantee` 10 — all negative ("does not guarantee", "not recovery guarantees").
  * `coverage` 42 — **no positive interval-coverage claim.** Most apparent bare hits are
    line-wrap fragments whose negation sits on the previous line, or a different sense entirely
    (design coverage — "repeated within-individual context coverage"). Three checked in
    context and all honest: `fit-diagnostics.Rmd:339` describes what a validation study *would
    need*, not one that exists; `convergence-start-values.Rmd:319` and
    `function-map-cheatsheet.Rmd:236` are explicit negations.
  * `validated` 6 — **one genuine positive overclaim**, `multinomial.Rmd:234` (fixed by PR
    #803, a separate lane). `multinomial.Rmd:255` is a *scoped* positive ("validated only for
    the fixed-effect route") and honest; the `cross-family-correlations.Rmd` pair say
    "partially-validated"; `profile-likelihood-ci.Rmd:232` is `heuristic_unvalidated`.
* Register codes (`CI-xx`, `D-xx`, `Design NN`, `Phase NN`) on rendered surfaces: **0**. Two
  hits exist in `_pkgdown.yml:7,390` but are YAML *comments*, never rendered.
* Version stamps: `DESCRIPTION` 0.6.0, `README.md:232` 0.6.0 — consistent.
* Residual `method = "profile"` mentions after the fix: all remaining hits are `confint()`,
  a different function where the value is valid, plus `behavioural-syndromes.Rmd:389`, which
  already states the request stops rather than silently substituting.

## 9. What Did Not Go Smoothly

Three of my own errors, all the same shape — **a check that silently reported "clean"**:

1. **`\b` in `grep -E` on macOS.** BSD grep ignores it and returns zero matches. I reported
   "zero overclaims, zero register-code leaks" from a broken pattern; the real counts were 107
   and 0. Caught only because "zero `coverage` across 21 articles including
   `profile-likelihood-ci.Rmd`" was implausible on its face.
2. **The guard test passed vacuously, three ways.** `parse()` returns an `expression`, for which
   `is.call()` is FALSE, so the walker never descended; `as.list()` on a call yields the empty
   symbol for missing arguments, which errors on *any* evaluation including a predicate written
   to detect it; and `formals()` entries without defaults are that same empty symbol.
3. **I mis-attributed a finding in my own ledger** to `function-map-cheatsheet.Rmd:381`, a
   280-line file, because one auditor covered three files and my extraction took the last path
   from a comma-joined string.
4. **I generalised a two-word polarity check into a five-word claim** (added 2026-07-29). I
   verified `certified` and `calibrated`, then wrote "No positive assertion anywhere" and
   "polarity swept, all negative" across all five words. The single genuine overclaim on the
   whole surface — `multinomial.Rmd:234`, bolded and unqualified — sat in `validated`, one of
   the three I never opened. Found by a *different lane* (PR #803), not by me, and only because
   they went to the primary evidence.

   This is the worst of the four, because the other three were caught by my own checking and
   this one was not. It is also the same mechanism as §2 of the lane-starter's own warning: an
   agreeable result stopped the checking. "The docs are already honest" was the answer I
   expected and wanted, so I stopped one word short of the one that wasn't.

Also: the starter I was pointed at did not exist at the given path (it lives only on PR #802's
branch; `main` carries a differently-named file describing a different PR), and lane D's premise
in that starter was factually wrong in the opposite direction from what it claimed.

## 10. Known Residuals

8 article findings remain open (see the ledger) — each needs either a fit or a content
judgement, and none was guessed at.

Closed after this report's first draft, on Shinichi's instruction:

* **`CLAUDE.md` corrected to 0.6.0.** It claimed the first CRAN release is `0.5.0` and that
  `DESCRIPTION`/`NEWS` "still read 0.5.0". Both files already read **0.6.0** (verified). D-42
  established the "first release is a 0.x" principle and named 0.5.0; the *number* was
  superseded by the 0.6 strategy (issue #772). Historical references — the
  `claude/release-0.5.0` branch name, the `1.0.0 → 0.5.0` correction in PR #748 — were left
  alone as accurate history.
* **`R/diagnose.R:1081` fixed**, with a guard test. Printed output is a reader surface.

## 11. Team Learning

* **The structural finding outlives the individual fixes.** `.Rbuildignore:29` excludes
  `^vignettes/articles$`, so `R CMD check` never builds 20 of 21 reader documents; `pkgdown.yaml`
  triggers on `workflow_run` with `branches: [main, master]`, so the site builds only *after* a
  merge, never on a PR; and 27 chunks are `eval = FALSE`, executed by nothing at all. The
  concentration is the concerning part — `api-keyword-grid.Rmd`, the canonical statement of the
  4×5 keyword grid, has 7 of 8 chunks unexecuted. Fixing 5 defects does not change that; the
  guard test is the first thing that does, for one class.
* **Querying the brain first paid immediately.** drmTMB's `2026-07-11-docs-accuracy-audit.md`
  had run this exact audit, and its lesson — the surface errs toward *under*-claiming; the real
  damage is broken examples, not adjectives — is what redirected this lane. Inventing a method
  would have produced the adjective sweep and stopped at "clean".
* **The adversarial pass is not ceremony.** Across both audits, 22 candidates → 16 confirmed,
  6 refuted. The clearest case is a refuted finding citing `gllvm-vocabulary.Rmd:342` — a
  confident, specific, plausible `file:line` in a **318-line file**. It would have been believed
  without a verifier defaulting to *refuted*.

## 12. Cross-Product Coverage

**Covers:** rendered reader surfaces of 20 articles + README + `_pkgdown.yml` for (a) overclaim
vocabulary, (b) internal register codes, (c) version stamps, and (d) static resolvability of
prescribed gllvmTMB calls — function existence, argument names against formals, literal values
against declared choices, and withdrawn values.

**Does NOT cover:**

* `missing-data.Rmd` — fenced out; lane 3 owns it. Not audited on any axis.
* The 136 unfenced `man/*.Rd` pages — swept for register codes only, **not** for executable
  honesty or overclaims. `\examples{}` blocks not checked at all.
* Lane 1's fenced files, including `NEWS.md`, on every axis.
* **Whether any article actually knits.** Nothing was rendered. A call can resolve statically
  and still fail at runtime.
* Prose accuracy generally. The guard adjudicates the invalid-call class only — 1 of 13
  findings. The other 12 are prose claims no static parser can settle.
* Runtime behaviour: the two ICC claims, and the AGHQ/`predict_missing` interaction (lane 3).
* `README.Rmd` → `README.md` regeneration, and the rendered pkgdown site.
