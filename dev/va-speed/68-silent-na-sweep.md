# Silent-NA sweep — the Rose principle applied, on the right tree this time

**Date:** 2026-08-04 · **Tree swept:** `/private/tmp/gllvmtmb-va-lane2` @ `d80f308e`
(branch `claude/va-lane2`)

## 🔴 The first attempt at this sweep was INVALID — recorded, not quietly redone

A dispatched agent reported *"0 new SILENT-DEFECT cases, 15+ guarded, 12+ legitimate-NA, sweep
result: Pass."* Its headline happens to match the one below, but **its evidence does not support
it**, on two counts found by checking rather than by reading its summary:

1. **It swept the wrong tree.** Every path it cited was under
   `/Users/z3437171/Dropbox/Github Local/gllvmTMB/R/…` — the protected Dropbox checkout, which sits
   on branch `claude/profile-coverage-remeasure-20260718` @ `ab49638b`. `diff -rq` puts that tree
   **76 files apart** from this lane's `R/`, including every file this workstream changed. A
   "0 defects" verdict about a different branch is not evidence about this one.
2. **It never wrote its artefact.** Its own reply said the file *"would report"* the result. The
   path did not exist.

Neither failure was harmful — the read was read-only — but a matching headline from the wrong
inputs is exactly the kind of result that gets accepted because it says what you hoped. Redone
by hand below.

## The sweep

**Target class:** a prerequisite is missing or a computation failed, and the function returns
`NA`/`NaN`/`NULL` with no error, no warning, and no status field a caller can read — D-33's
*"an error handler that converts 'cannot check' into 'fine' is the defect itself."*

**Primary probe** — the pattern that most reliably produces the defect:

```
grep -rn "error = function(e) NA" R/     ->  21 sites
```

**Classification of the 21:**

| class | count | basis |
|---|---:|---|
| Internal value, **checked immediately downstream** | majority | the `NA` is tested with `is.na()`/`is.finite()` within a few lines and drives a branch — e.g. `profile-derived.R:298`, `:352`, `missing-predictor.R:2768` |
| **Diagnostic only** | 1 | `fit-multi.R:5786` — `g_last` has no `is.na` check, but its *only* use is an `sprintf` in a stall message, which then prints `max |grad| = NA`. Honest, not a silent wrong answer |
| Already fixed this session | 2 | `.gllvmTMB_b_fix_se()`, `extract_cutpoints()` `tau_se` |
| Already correct | 1 | `.lv_sdreport_effect_se()` (`extractors.R:760`) returns `list(std.error, status)` |
| Dead code, marked | 1 | `.wald_block()` (`profile-ci.R:487`) |

**The one worth naming:** `z-confint-gllvmTMB.R:1365`, inside `.confint_wald_targets()` — a
`tryCatch → NA_real_` on the SE lookup, followed by `if (is.na(se) || !is.finite(se))` setting that
target's bounds to `NA`. This *was* the third live defect. It is now unreachable in its dangerous
form: `.confint_require_sdreport()` gates the function at entry for both a **missing** `sd_report`
and an **all-non-finite** covariance. What survives is the **partial** case — one target's SE
non-finite while others are fine — and that is deliberately left as `NA`, on the same reasoning as
a mapped-out `Xcoef_fixed` coefficient: per-parameter `NA` is the correct answer when that
parameter alone has no standard error.

## Verdict

**0 new silent-defect sites beyond the three already fixed.** The codebase's prevailing idiom is
either an immediate downstream check or an explicit status field, and the three defects found this
session were genuine outliers rather than the tip of a pattern.

## Scope — what this sweep does NOT cover

- **One probe pattern.** `error = function(e) NA` is the highest-yield signature, not the only one.
  A function that silently returns an empty data frame, or `NULL`, or a zero-length vector on a
  missing prerequisite would not appear here.
- **Only `R/`.** Not `src/`, not `inst/`, not the Julia bridge.
- **Classification by local reading**, not by executing each path. The "checked downstream" calls
  rest on the check being within a few lines of the assignment; a check twenty lines away in a
  different branch could have been missed.

So: *this specific defect class, via this specific probe, in `R/`* — clean. Not "the package has no
silent failures."
