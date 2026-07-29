# Handover — missing-data lane (lane 3), gllvmTMB, 2026-07-28

Claude → next session (Claude or Codex). Written at lane close.

## State: LANDED except two carried-over items

Branch `claude/missing-data-20260728`, worktree `/private/tmp/gllvmtmb-missing-data`, cut from
`origin/main` @ `869e92b5`. **Not yet pushed** — see "Before you push" below.

This lane was an **audit of an existing subsystem**, not a build. It is essentially complete: the
central question is settled empirically, two reader-facing defects are fixed, and the contract now
has an always-run test guard.

## What the audit established (all by live fits, not by reading)

The lane brief expected "silent row-dropping that changes the estimand." **That is not what ships.**

- The default (`miss_control(response = "drop")`) is **cell-wise**: a unit with one missing trait
  still contributes every trait it does have. `nobs` 80 → 79 on one `NA`, not 78. Confirmed twice
  independently, including against hand-built controls (remove-the-cell Δ=1.4e-14 vs
  remove-the-unit Δ=0.66).
- It is **reported at call time**, and the runtime message is more precise than the documentation
  was: *"dropped 1 (trait, row) **cell** with `NA` response."*
- `drop` and `include` reach **the same optimum** — gaussian and poisson, long and wide
  (\|ΔlogLik\| 1e-9…1e-8, equal `nobs`). The repo's own test covered only gaussian/wide.
- The article's untested wide-vs-long parity claim is **true** (Δ=1.07e-14, `nobs` 44 both — the 44
  the article states).
- Missing **predictors** abort by default; the one-`mi()` scope guard is enforced.

Ledger: `docs/dev-log/2026-07-28-missing-data-accuracy-audit.md`.
After-task report: `docs/dev-log/after-task/2026-07-28-missing-data-audit.md`.

## Files changed (scoped; no `git add -A` was used)

| File | Change |
|---|---|
| `vignettes/articles/missing-data.Rmd` | 2 prose edits — the default-behaviour sentence (L46) and the article description (L3). No code chunk touched. |
| `tests/testthat/test-missing-response-cellwise.R` | **new** — 4 fast, un-gated pins |
| `docs/dev-log/2026-07-28-missing-data-accuracy-audit.md` | **new** — the ledger |
| `docs/dev-log/after-task/2026-07-28-missing-data-audit.md` | **new** — after-task report |
| this file | **new** — handover |

## 🔴🔴 READ FIRST — three findings from the adversarial pass, none fixable here

These came from the refutation pass, were each **independently re-verified**, and are **more severe
than anything the main audit found**. All three sit outside this lane's files or outside its remit.

**B1 (BLOCKER) — `README.md:174-177` states a fail-loud guarantee that does not hold.**
It says missing "grouping variables, offsets, weights, or design-matrix values still **error**".
Weights and design-matrix values do error. **Grouping variables and offsets do not** — they fit
silently with a materially different result (logLik −34.49161 clean → −35.95859 with an `NA`
grouping level; `nobs` unchanged; zero messages). The sentence invites a reader to treat a clean run
as proof their grouping variable was clean. `README.md` belongs to the reader-surfaces lane.

**B2 (HIGH) — `offset()` is silently ignored, everywhere.**
Varying offset, wide and long: logLik **−36.261352 with and without**, difference **exactly 0**, same
`npar`, no error, no warning. Ecological count models routinely carry an effort offset, so a user can
get a different model than the one they wrote with no signal. Two shipped articles nonetheless tell
readers to "revisit … offsets".

**The intent is documented and the guard already exists — for `lv` only.**
`R/lv-predictor.R:156-161` aborts on `offset()` inside an `lv` formula, and the design docs list
offsets among terms that "still reject" (`docs/design/01-formula-grammar.md:403`,
`docs/design/35-validation-debt-register.md:102`). Confirmed live:

| call | result |
|---|---|
| `offset()` inside `lv` | `ERROR: 'lv' formulas cannot contain 'offset()' terms.` |
| `offset()` at top level | **no error — fits**, logLik −76.5653 |

So this is an **oversight, not a design decision**: the top-level fixed-effect formula never received
the guard that the `lv` sub-formula has. The fix is to extend the existing pattern
(`gll_lv_rhs_functions()` + a membership test), not to invent one.

*(An earlier draft of this handover said "0 guards in `R/`" — that was wrong, from a grep requiring
both tokens on one line. Corrected above.)*

**B3 (HIGH/MEDIUM) — `NA` in a grouping/unit identifier silently changes the fit.**
Not dropped, not reported, not rejected: `nobs` stays 60 while logLik moves −34.49161 → −35.83823.
A silent third category of missingness beyond "responses omitted / predictors rejected".
Deliberately **not** written into the article — documenting it would enshrine what is probably a
defect; the right fix is likely to make it error, which is a runtime change and the maintainer's call.

## 🔴 CARRIED OVER — two further items, neither safe for this lane to do alone

**C1 — two roxygen blocks in `R/gllvmTMB.R` (FENCED to another lane).**
`:1312` (→ `man/miss_control.Rd`) and `:239` (→ `man/gllvmTMB.Rd`) call the default *"the historical
complete-case behaviour"* and say it *"keeps rows"*. Same imprecision as the article defect that was
fixed here: "complete-case" is the standard name for listwise deletion, which is the behaviour this
default avoids.

`R/gllvmTMB.R` belongs to the interval-machinery lane (PR #802). **Do not edit it from here.**
Route by either commenting on #802, or landing after it merges. Suggested replacement text:

> …is cell-wise omission: each missing response cell is dropped, and a unit keeps every trait it
> does have.

**C2 — `gllvmTMB_wide()` drops NA cells silently.** `R/gllvmTMB-wide.R:218-221` strips the cells
before `gllvmTMB()` can report them; measured 120 → 116 cells with **no** message. Every other path
reports. The wrapper is soft-deprecated but still exported (`NAMESPACE:107`), and no test covers
`NA` in `Y` there. The drop is still cell-wise, so this is a **transparency** defect, not an estimand
defect. Adding a message is a runtime behaviour change to a shipped export — it was written up as a
proposal rather than shipped, per the agreed change authority. **Maintainer's call.**

## Before you push

1. `devtools::test()` on the touched files locally (not CI-first). Last measured: default run
   133 pass / 80 skip / **0 fail**; heavy run (`GLLVMTMB_HEAVY_TESTS=1`) **665 pass / 0 skip /
   0 fail** / 1 warn.
2. `rcmdcheck` — **run, and it is NOT clean. None of it is this lane's.** Read this before you
   conclude the branch broke something:

   `1 ERROR / 4 WARNINGS / 2 NOTES`, all pre-existing on `origin/main`:
   - **ERROR — `tests/testthat.R` fails** (`FAIL 7 | SKIP 1060 | PASS 4996`). The visible failure is
     `test-eva-gate1.R:101` — *"Cannot find docs/design/86-eva-gate1-parameters.json"*. `docs/` is
     excluded from the build (`.Rbuildignore:18` = `^docs$`), so any test resolving a `docs/design`
     path **cannot** pass under `R CMD check`. That file has 6 blocks and belongs to the VA/EVA
     lane; a further ~15 test files read `docs/design` the same way.
   - **WARNINGS ×3 — `.onLoad` fails: `object 'AIC' not found`.** A namespace-load problem.
   - **WARNING — codoc mismatch in `man/gllvmTMBcontrol.Rd`**, which is one of **lane 1's fenced
     files** and is actively being changed by PR #802.

   **Attribution is decisive:** `git diff --name-only origin/main HEAD -- R/ src/ NAMESPACE` returns
   **0 files**. This branch changes only 4 dev-log documents, 1 test file, and 1 pkgdown article
   (itself build-excluded). It cannot have caused a namespace-load or codoc failure. The new test
   file appears **nowhere** in the check log (verified two ways).

   The lane's own verification: default run 133 pass / 80 skip / **0 fail**; heavy run
   (`GLLVMTMB_HEAVY_TESTS=1`) **665 pass / 0 skip / 0 fail**; the new file 8 pass / 0 skip / 0 fail.

   **Do not treat the tree as check-clean.** The `AIC` `.onLoad` warning in particular looks like it
   deserves its own look by whoever owns the namespace.
3. Re-run `tools/lane_preflight.sh .` — three lanes were concurrent on 2026-07-28 and lane 1's
   PR #802 was open.

## Do NOT re-attempt (settled elsewhere; carried forward from the lane brief)

- The chi-bar-square boundary correction (points the wrong way, 2.706 vs 3.841).
- Boundary detection (unimplementable under log-SD).
- Any claim that a coverage certificate exists — the disposition is WITHHELD. Read the after-task
  record, not `decisions.md:2130-2135`, which overstates it.
- Any "first to profile a low-rank covariance" novelty claim — SAS GLIMMIX COVTEST TYPE=PLR
  predates it.

## Traps this lane actually hit (cost real time — do not repeat)

- **BSD `grep -E` silently ignores `\b`** and returns zero matches. Never use it; verify every zero
  a second way.
- **`grepl(..., ignore.case = TRUE)` for "NA" matches the letters in "diagonal".** This produced a
  false "the message mentions the drop" verdict that was the opposite of the truth. **Read the
  matched text; never trust the boolean.**
- **An env var set in the shell may not reach the test runner.** A first skip-count measurement
  reported identical default and heavy runs because of this. Set it inside the R session.
- **Agent file:line citations were wrong** while the substance was right (a default at `:1355` was
  cited as `:15-16`). Reopen every citation.
- Verify R jobs with `ps aux | grep exec/R`, never `pgrep -f Rscript`.

## What this lane does NOT cover

No coverage claim, anywhere. Not an MNAR study. Gaussian and poisson only, long and wide — ordinal,
categorical, delta/hurdle and `cbind()` binomial were **not** exercised for drop/include equivalence.
The 2,859 lines of `R/missing-predictor.R` were audited only for the contracts their four exports
advertise, not as an implementation review.
