# After-task — `offset()` support, gated to count families (#833)

**Date:** 2026-07-30
**Platform:** Claude Code
**Lane:** `claude/offset-support-20260730` (worktree `/private/tmp/gllvmtmb-offset`)
**Foreign lane:** none detected (`lane_preflight.sh`: 3 open Claude PRs #832 / #839 / #840,
no Codex lane in 12 h — silence is weak evidence, not proof of sole ownership, D-87)

## 1. Goal

Replace the outright rejection of `offset()` (added in #807 after offsets were found to be
silently ignored) with a working implementation, scoped to count families, so the standard
ecological exposure/effort adjustment is available.

## 2. Implemented

- `DATA_VECTOR(offset_vec)` in `src/gllvmTMB.cpp` and `eta(o) = eta_fix(o) + offset_vec(o)`.
  Zeros by default, so a fit without an offset is unchanged.
- The parser now **extracts** a top-level `offset(...)` into `parsed$offset_expr` instead of
  aborting. It is deliberately kept out of `parsed$fixed`, because `model.matrix()` drops
  offset terms — that drop is precisely how the original bug happened.
- The `traits()` expander passes `offset()` through un-interacted (it was being rewritten to
  `(0 + trait):offset(w)`), and collapses the per-trait wide form `offset(e1, e2, ...)` into
  one synthetic `.offset_wide_` column stacked row-major to match the response pivot.
- `gll_prepare_offset()` (new `R/offset.R`) evaluates the offset to a per-row vector,
  validates it (numeric, length, finite), and applies the count-family gate.
- The gate admits family ids 2 (poisson), 5 (nbinom2), 10 (truncated_poisson),
  11 (truncated_nbinom2), 15 (nbinom1) — every count family the engine has.
- Downstream paths that rebuild the predictor on the R side were fixed: `simulate()`'s
  unconditional redraw, and `predict(newdata = )` (which re-evaluates the offset against the
  new rows). `engine = "julia"` refuses an offset rather than dropping it.
- `offset()` inside an `impute` formula now gives a real diagnosis instead of the raw base-R
  `undefined columns selected`.

## 3a. Decisions and Rejected Alternatives

| decision | rationale | rejected alternative |
|---|---|---|
| Grammar is **formula-only** | Matches `glmmTMB` and the sibling `drmTMB`, which is the gap #833 names. Not a new public API surface, so not an API change under CLAUDE.md's high-risk list. Adding `offset =` later stays purely additive. | An `offset =` argument (gllvm/Hmsc style), or both. Maintainer chose formula. |
| Wide per-trait form is **`offset(e1, e2, ...)`** | Mirrors the `traits()` LHS, reuses the existing row-major pivot, and is the only way to write a wide mixed-family offset. | Erroring and pointing users to long format. Rejected because mixed families are the package's headline capability and wide is the shape most users write. |
| Gate on **family, not link** | The set stays small and enumerable, and it matches the use case. A link gate would sweep in Gamma, lognormal and Tweedie on log links, each needing its own semantics decision. | Link gating. |
| Gate fires on a **nonzero** offset only | Zero is a multiplier of one — a genuine no-op, not a loophole. It is what makes a mixed-family fit expressible at all. | Rejecting any `offset()` in a fit containing a non-count trait, which would make the feature useless in exactly the models this package exists for. |
| All 5 count families, including the truncated pair | The offset enters `eta` identically for all of them, so the gate is a set-membership test rather than per-family code; the only cost is test cells. Excluding truncated would make the message incoherent ("count families only" refusing `truncated_poisson`). | poisson/nbinom1/nbinom2 only. Maintainer chose all five. |
| Template applies the offset **unconditionally** | The R side has already gated; gating again in C++ would silently discard a value R accepted — the same failure class being fixed. | A family conditional in the template. |

## 4. Files Touched

Modified:
- `src/gllvmTMB.cpp`
- `R/parse-multi-formula.R`
- `R/traits-keyword.R`
- `R/fit-multi.R`
- `R/methods-gllvmTMB.R`
- `R/gllvmTMB.R`
- `R/missing-predictor.R`
- `man/gllvmTMB.Rd` (regenerated)
- `NEWS.md`
- `docs/design/01-formula-grammar.md`
- `tests/testthat/test-offset-guard.R`

Created:
- `R/offset.R`
- `tests/testthat/test-offset-support.R`
- this report

## 5. Checks Run

| check | result |
|---|---|
| `devtools::test()`, `NOT_CRAN=true`, full suite | **0 failed, 0 errors, 8092 passed**, 2 warnings, 784 skipped |
| the 2 warnings | both from the external `gllvm` comparator (`There are rows full of zeros in y`), pre-existing, unrelated |
| `test-offset-support.R` + `test-offset-guard.R` on the final tree | all pass |
| `rcmdcheck(args = "--as-cran")` | see the PR — run on the committed tree |

Measured engagement (not merely "no error"):

```
logLik  no-offset = -187.996678
logLik with-offset = -175.566733
difference        =   12.429946      # the #807 signature was exactly 0
npar: no-offset = 4, with-offset = 4  # an offset adds no parameter
```

Rendered gate message:

```
offsets are supported for count families (poisson, nbinom) only; trait
`t2` uses `gaussian`.
```

## 6. Tests of the Tests

The template was **sabotaged on purpose** — `eta(o) = eta_fix(o) + offset_vec(o)` reverted to
`eta(o) = eta_fix(o)` — recompiled, and the suite re-run:

```
SABOTAGED RUN: failed=22 error=0 passed=40
  a varying offset changes a poisson fit and adds no parameters        2
  a poisson offset recovers the slope that omitting it biases          2
  gllvmTMB and glmmTMB agree on a poisson offset fit (cross-package)   4
  wide traits() offset(w) engages and matches the equivalent long fit  1
  a zero offset on a non-count trait is a legal no-op                  1
  wide offset(e1, e2) gives one offset column per trait                1
  all five supported count families accept an offset                  10
  the offset composes with a random effect and reaches the SE path     1
```

So a reintroduced silently-ignored offset is caught in both shapes, in all five families, and
against an external oracle. The gate tests correctly stayed green — they are R-side and do not
depend on the template. The sabotage was reverted and the template diff re-verified.

Every test uses a **varying** offset. A constant one is absorbed by the intercept and would
pass even if the offset were ignored.

## 7a. Issue Ledger

- **#833** — implemented as specified. The one open question (grammar) was settled by the
  maintainer during this session; recorded in §3a and in `docs/design/01-formula-grammar.md`.
- **#836** (opaque rejections) — the `impute`-formula offset surface named there now has a real
  diagnosis. The rest of #836 is untouched.
- **#807** — its guard is replaced, not removed: gaussian fits still refuse a varying offset,
  now on the family gate with a better message.
- **#834** (skip-gated tests) — respected: none of the new tests are behind
  `skip_if_not_heavy()`. The suite's 784 skips are pre-existing and not addressed here.

## 8. Consistency Audit

The failure class is "an R-side path rebuilds `eta` and misses the new term". A read-only sweep
of all 90 files in `R/` was run for that pattern. Findings and dispositions:

| site | disposition |
|---|---|
| `.simulate_eta_unconditional()` | **fixed** — reads the stored `offset_vec`. `bootstrap_Sigma()` and `coverage_study()` redraw through it, so this one omission would have quietly corrupted both. |
| `.gllvmTMB_predict_fixed_eta()` via `predict(newdata = )` | **fixed** — the offset is re-evaluated against `newdata`, with a clear error when the column is absent. |
| `engine = "julia"` bridge | **fixed (fail-closed)** — refuses rather than dropping. |
| `R/missing-predictor.R` covariate-model `eta` | separate regression (the imputation model), not the response predictor; unaffected. |
| `eva-proto.R`, `va-r3-proto.R`, `va-vgh.R` | research-only prototypes on their own DLLs; unaffected. |
| `simulate_site_trait()`, `simulate_unit_trait()` | standalone data generators with no fit object; unaffected. |
| sites reading `fit$report$eta` (`diagnose.R`, `extract-sigma.R`, `predictive-diagnostics.R`, `predict(newdata = NULL)`, `.predict_multinomial()`) | already correct — `REPORT(eta)` carries the offset. |

`eta` is `REPORT`ed but not `ADREPORT`ed, which is why the three fixed sites reconstruct it.

## 9. What Did Not Go Smoothly

- `git checkout src/gllvmTMB.cpp` to undo the deliberate sabotage reverted the **entire**
  uncommitted template change, not just the sabotage. Caught by re-reading the diff rather than
  assuming; both edits were reapplied and the diff verified line by line. The lesson is to
  sabotage/restore with a targeted edit, or commit first.
- The first test run failed on my own fixtures, not the implementation: a single-level `trait`
  factor cannot form contrasts. Two tests were rewritten to use two traits.
- The interim full-suite run loaded the namespace before the last two R edits, so it could not
  be the authoritative evidence; `rcmdcheck` on the committed tree is.

## 10. Known Residuals

Stated plainly, without hedging:

- **Recovery evidence is poisson-only.** `nbinom1`, `nbinom2`, `truncated_poisson` and
  `truncated_nbinom2` have *engagement* evidence (the fit demonstrably moves) but no
  parameter-recovery cell. The offset enters `eta` identically for all five, so the risk is low
  — but low risk is not verification.
- **No coverage claim is made** for any offset cell.
- The **glmmTMB cross-check is fixed-effects poisson only**; no cross-package check exists for
  the negative-binomial or truncated families.
- `predict(newdata = )` on a fit that used the **wide per-trait** form requires the caller to
  supply a `.offset_wide_` column. The error says so, but it is an awkward surface.
- `offset()` inside `lv = ~ ...` and inside `impute` formulas remain **unsupported** — now both
  with clear messages rather than one clear and one opaque.

## 11. Team Learning

**A feature whose bug was "silently ignored" must be tested by sabotage, not by green.** The
whole suite passed before the sabotage run, and the sabotage run is the only thing that proves
the tests would notice the bug coming back. Twenty-two assertions moved; had that number been
small, the tests would have been decorative.

**When a term enters a shared quantity like `eta`, the diff is not the change.** The template
edit was two lines; the *change* included three R-side reconstructions of `eta` that would each
have produced a plausible wrong number. Sweeping for "who else rebuilds this?" found all three,
and two of them fed `bootstrap_Sigma()` and `coverage_study()`.

**A gate that admits a subset needs an escape hatch that is semantically real, not a
workaround.** Zero passes the count-family gate because zero genuinely does nothing on the log
scale. That single property is what lets mixed-family models — the package's whole point — use
the feature at all.

## 12. Cross-Product Coverage

`offset()` is cross-cutting: a per-row addition to `eta` that silently changes every downstream
surface. The product grid:

**Covers ✓**

| surface | evidence |
|---|---|
| long format, per `(unit, trait)` | engagement + recovery |
| wide `traits()`, single recycled column | engagement + wide/long logLik agreement |
| wide `traits()`, per-trait `offset(e1, e2)` | engagement + arity guard |
| poisson | recovery, and agreement with glmmTMB to < 1e-3 |
| nbinom1, nbinom2, truncated_poisson, truncated_nbinom2 | engagement only |
| mixed families, zero on non-count rows | fits, and differs from an all-zero offset |
| the family gate + trait-naming message | asserted on diagnosis, not on "did it error" |
| `simulate()` | high/low offset means differ by the expected factor |
| `predict(newdata = )` | a +1 offset shift moves every prediction by exactly 1 |
| `predict(newdata = )` with the column missing | clear error |
| composition with `(1 | site)` | engagement with a random effect present |
| the SE / `sdreport` path | finite standard errors on an offset fit |
| `engine = "julia"` | refuses |
| `offset()` in `lv = ~` | still rejects, keeps its own message |
| `offset()` in `impute` | now rejects clearly |
| fits with **no** offset | byte-unchanged (`offset_vec` all zeros; full suite green) |

**Does NOT cover ✗**

| surface | status |
|---|---|
| parameter recovery for nbinom1 / nbinom2 / truncated_poisson / truncated_nbinom2 | ✗ engagement only |
| interval **coverage** for any offset cell | ✗ no claim made |
| `bootstrap_Sigma()` / `coverage_study()` with an offset | ✗ inherit the `simulate()` fix but are not directly tested |
| `REML = TRUE` with an offset | ✗ untested |
| AGHQ with an offset | ✗ untested |
| profile intervals (`profile_ci_*`) with an offset | ✗ untested |
| `miss_control(response = "include")` masking with an offset | ✗ untested |
| `weights` combined with an offset | ✗ untested |
| `phylo_*` / `spatial_*` / `kernel_*` covstructs with an offset | ✗ untested (the offset enters `eta` before every RE contribution, and the `(1 \| site)` cell is covered, but the structured tiers are not) |
| the legacy `gllvmTMB_wide(Y, ...)` wrapper with an offset | ✗ untested |
| cross-package agreement for any family other than poisson | ✗ untested |
