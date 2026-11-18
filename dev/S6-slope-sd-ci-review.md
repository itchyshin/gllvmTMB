# S6 — Adversarial review of `slope_sd_ci()` (PR #1166, `claude/slope-sd-ci-20260818`)

**Reviewer:** Rose (claims auditor), fresh context, adversarial.
**Worktree:** `/private/tmp/gllvmtmb-slopeci` @ `8d252109`, off `origin/main`.
**Artifacts read:** `git diff origin/main...HEAD`, `R/slope-sd-ci.R`,
`tests/testthat/test-slope-sd-ci.R`, `man/slope_sd_ci.Rd`,
`docs/design/35-validation-debt-register.md` (CI-14/CI-15),
`docs/dev-log/check-log.md`, `docs/dev-log/after-task/2026-08-18-slope-sd-ci-slice1.md`.
**Independently verified against:** `src/gllvmTMB.cpp:1550-1620, 2484-2502`,
`R/fit-multi.R:2185-2245, 4060-4125, 7106-7115`, `_pkgdown.yml`,
and a live run of the shipped function on `dev/fitB_cache.rds`.

## VERDICT: **CHANGES REQUIRED**

The mechanics are right. I re-derived the packing independently and it holds:
`theta_diag_B_slope` interleaves `(intercept, slope)` per trait
(`R/fit-multi.R:4118-4121`, `base = 2 * trait_id` with 0-based `trait_id`), so
the slope coordinates are positions `2, 4, ..., 2T` and
`slope_pos <- seq(2L, 2L * n_traits, by = 2L)` selects them correctly.
`sd_B_slope = exp(theta_diag_B_slope)` (`src/gllvmTMB.cpp:1606`) is a genuine
univariate log-SD, so `exp(theta ± z·se)` is an exact transformed Wald interval
with no Jacobian. `fit$opt$par` and `fit$sd_report$cov.fixed` were confirmed to
share names, order and values on a real fit, so the positional indexing into
`cov.fixed` is sound. The claim-fencing vocabulary (`interval_status =
"wald_uncalibrated"`, hard-coded `calibrated = FALSE`, fence-first print citing
D-112 and CI-08/CI-10) is thorough and I found **no coverage or calibration
claim anywhere** in the diff.

What blocks the PR is not the arithmetic. It is that the function ships a
column named `estimate`, in a function named `slope_sd_ci()`, whose value is a
*component* of the slope SD and which — on the package's own default
`latent()` grammar — understates the quantity the name promises by up to 45%;
that the caveat is carried only by a print method I was able to strip in three
ordinary operations; that `pkgdown::check_pkgdown()` hard-errors; that the
tracked `check-log.md` asserts a check that was never awaited; that both
provenance documents cited from the permanent register do not exist on `main`;
and that the full test suite — the one check the builder launched and did not
await — returns **FAIL 1**, with that single failure caused by this PR.

---

## PRIORITY 1 — the `rr_B_slope` scope decision

### (a) Is the returned quantity actually the Psi-only component?

**Yes. Verified from the code, then confirmed empirically.**

The two blocks enter the linear predictor **additively on the same design
column**, not as alternatives:

```cpp
// src/gllvmTMB.cpp:2484-2502
if (use_rr_B_slope == 1)   { ... u_B_aug      += Z_B_lat(o, j)  * coef_j;      eta(o) += u_B_aug;      }
if (use_diag_B_slope == 1) { ... u_B_diag_aug += Z_B_diag(o, j) * s_B_slope(j, s); eta(o) += u_B_diag_aug; }
```

and `R/fit-multi.R:4094-4096` states, and `4118-4121` implements, that
`Z_B_diag` uses **the same 2T interleaved coefficient ordering as `Z_B_lat`**.
Both design matrices put trait `t`'s slope in column `2t`. Therefore for
coordinate `j = 2t`:

```
Var(slope coefficient for trait t) = (Lambda_B_slope Lambda_B_slope')[j,j] + exp(theta_diag_B_slope[j])^2
                                   = Sigma_B_slope[j,j]                    + Sigma_B_unique_slope[j,j]
```

`slope_sd_ci()` returns `exp(theta_diag_B_slope[j])` — the **second term
only**. The comment at `R/slope-sd-ci.R:33-39` is accurate.

### (b) By how much can it understate the total? — MEASURED

Not reasoned about; measured, on the exact fixture the happy-path test uses
(`dev/fitB_cache.rds` reproduces the feasibility doc's Route B `theta` table to
six decimals: `-1.993085, -1.549038, ...`, so it is the same fit). The C++
already `REPORT()`s both pieces, so this needed no new machinery:

| trait | `slope_sd_ci()$estimate` (Psi-only) | omitted loadings SD | **TOTAL slope SD** | estimate as % of total | Psi share of variance |
|---|---|---|---|---|---|
| t1 | 0.2125 | 0.3245 | **0.3879** | **54.8%** | 30.0% |
| t2 | 0.2426 | 0.1634 | **0.2925** | **82.9%** | 68.8% |
| t3 | 0.2015 | 0.2607 | **0.3294** | **61.2%** | 37.4% |

**The reported `estimate` understates the total slope SD by 17–45% on the very
fixture that demonstrates the feature.** This is not a pathological corner: the
true-DGP ratios are 0.545 / 0.697 / 0.680, i.e. the fixture was *constructed*
with the Psi component as roughly half to two-thirds of the total. The
intercept coordinates are worse still (Psi is 26–44% of the total there),
though those rows are not returned.

The published interval does happen to contain the total on all three traits
here (`upper` = 0.402 / 0.343 / 0.468 vs total 0.388 / 0.293 / 0.329) — but on
t1 only barely, and that is an accident of this fit's SEs, not a property.
**The defect is the estimand, not the interval width.**

The magnitude is bounded only by the loadings, which are free parameters: there
is no ceiling on the understatement. As `d` or the loading magnitudes grow, the
Psi share `→ 0` and `estimate` → an arbitrarily small fraction of the truth.

### (c) Is the labelling sufficient? — **No. Demonstrated, not asserted.**

The caveat lives in exactly two places, both bypassable:
`print.gllvmTMB_slope_ci()` (an attribute-driven `cat()`), and the roxygen.
Nothing in the returned **data** marks the restriction. Columns are
`trait, term, estimate, lower, upper, theta, se_theta, method,
interval_status, status, scale` — `method` is the constant
`"wald_log_scale"` and `interval_status` the constant `"wald_uncalibrated"`
regardless of whether `rr_B_slope` is active. A reader of the data frame has
**zero in-band signal**.

I stripped the caveat three ways on the real object:

| operation | caveat still shown? |
|---|---|
| `print(ci)` | yes |
| `ci$estimate` | **no** — a bare numeric vector |
| `subset(ci, status == "ok")` | **no** — `subset.data.frame` drops `attr(x, "rr_B_slope_present")` |
| `knitr::kable(ci[, c("trait","estimate","lower","upper")])` | **no** — column selection drops the class; renders a clean table of understated numbers |

`ci[1:2, ]` and `head(ci, 2)` happen to preserve the attribute in this R
version; `subset()` does not. Relying on which base-R subsetting verbs happen
to preserve a custom attribute is not a fence.

### (d) RULE

**The current behaviour is NOT acceptable, but the fix is NOT refusal.**

Refusing whenever `rr_B_slope` is TRUE would refuse the package's own default
`latent()` grammar and the only verified case — that trades a labelling defect
for a usability defect, which the house principle does not permit (usability is
the one principle that does not bend). The builder's reasoning for computing
was right; its mitigation was insufficient.

Required, and all three are cheap:

1. **Add an in-band `component` column** — `"unique_psi"` when `rr_B_slope` is
   TRUE, `"total"` when it is FALSE. This is the only mitigation that survives
   `$estimate`, `subset()`, column-selection and `knitr`. The restriction must
   travel with the *data*, not with the print method.
2. **Warn on the call, not on the print.** `cli::cli_warn()` when
   `rr_B_slope` is TRUE. A warning fires regardless of how the result is
   consumed; `print()` does not.
3. **Expose the omitted piece as a point estimate.** `fit$report$Sigma_B_slope`
   (`= Lambda_B_slope %*% t(Lambda_B_slope)`) is **already `REPORT()`ed by the
   C++** — I used it for the table above. Add `total_sd` (point estimate only,
   `lower`/`upper` deliberately `NA`) and/or `rr_sd_omitted`. Slice 2's
   multivariate delta method is needed for an **interval** on the total, not
   for its **point estimate**. Presenting the smaller component under the name
   `estimate` while silently withholding a number the package already holds is
   the actual defect here — and the fence stays intact because the new column
   ships interval-free by construction.

Optionally also rename `estimate` → `sd` and let `component` disambiguate;
that is a maintainer taste call, but (1)–(3) are not.

---

## PRIORITY 2 — do the kill-switch guards discriminate?

The builder's blanket claim is that each guard has a test which first shows the
naive computation returns a plausible finite value, then shows the guard
suppresses it. **That is true for one of the three, partly true for one, and
overstated for one.**

### Guard 1 — `no_pd_hessian`: **GENUINE.**
The mock (`test-slope-sd-ci.R:175-200`) carries a perfectly healthy
`cov.fixed = diag(c(.3,.32,.3,.31)^2)` and flips `pdHess = FALSE` alone. The
test computes `exp(par[slope_ix] - 1.96 * se)` from the same SEs and asserts it
is finite before invoking the guard. Removing the guard would return finite,
entirely plausible intervals. This is a real failure-before-fix demonstration.
*(Nit: the test hard-codes `[c(2L, 4L)]`, duplicating the packing assumption
rather than deriving it — harmless for a finiteness demo, but it means the
"naive" branch is not an independent check of the packing.)*

### Guard 2 — `se_nonfinite`: **WEAK; the after-task overstates it.**
The test uses `se_theta = NaN`, and `NaN` propagates through `exp()` to `NaN`
with or without the guard. The guard's contribution is the `status` label and
the warning, not the suppression of a plausible number. **The test comment
concedes exactly this** (`test-slope-sd-ci.R:209-211`: *"not a
'plausible-looking' number"*) — but the after-task §5 asserts, without
qualification, that *"All three guard tests are genuine failure-before-fix
demonstrations … None is a fixture that would pass 'for the wrong reason' —
each degenerate value is chosen so the naive path visibly misbehaves."* The
test is honest; the report is not. This is precisely the PR #1154 test-7
hazard, in the prose rather than the code.

There **is** a branch where guard 2 suppresses a finite number — `se_theta =
Inf`, for which the naive lower bound is `exp(-Inf) = 0`, a finite,
publishable-looking zero. **That branch is untested.** Add it; it converts
guard 2's test from near-vacuous to genuine.

### Guard 3 — `boundary` (`se_theta > 10`): **the guard does not do what it is named for.**

Is 10 defensible? Two separate questions, and they have opposite answers.

**What it excludes: essentially nothing legitimate.** `se_theta = 10` on a
log-SD means a 95% interval spanning `exp(2 × 1.96 × 10) ≈ 1.06e17`. Observed
well-identified SEs on this very fixture are 0.176–0.430; the feasibility
probe's six entries span 0.176–0.475. Even a badly identified variance
component rarely exceeds 2–3. So the false-positive risk is nil. Good.

**What it lets through: almost everything.** I ran the shipped function on
mocks:

| `theta` | `se_theta` | shipped `status` | returned interval | upper/lower |
|---|---|---|---|---|
| -13.548 | 2.0 | `ok` | [2.59e-08, 6.59e-05] | 2.5e+03 |
| -13.548 | 3.0 | `ok` | [3.65e-09, 4.68e-04] | 1.3e+05 |
| -13.548 | 5.0 | `ok` | [7.25e-11, 2.36e-02] | 3.3e+08 |
| -13.548 | 9.9 | `ok` | [4.89e-15, 3.49e+02] | 7.1e+16 |

Every one of those is finite, plausible-looking, and information-free, and
every one passes as `"ok"` with no warning. The cut at 10 catches only the
catastrophic `se ≈ 6e4` case, which is the one case that is obvious anyway
(`upper = Inf`).

**And the guard is not a boundary detector at all.** It is keyed on `se_theta`
and never inspects `theta`. A boundary/Heywood collapse is defined by
`theta → -∞` (`sd → 0`), not by a large SE. Concretely:

```
theta = -20, se_theta = 0.5   →   status = "ok"
estimate = 2.06e-09,  CI = [7.74e-10, 5.49e-09]
```

That is an unambiguous collapsed variance component returned as a clean, tight,
`"ok"` interval with no warning — the exact pathology the package elsewhere
detects *relative to siblings* (`psi_rel_thresh`, `near_zero_psi_*` in
`R/diagnose.R`). So the `status` value `"boundary"` and the roxygen phrase
*"`se_theta > 10` on the log scale — a boundary/Heywood collapse"*
(`R/slope-sd-ci.R:120-122`) both **mischaracterise what the guard tests**,
which is numerical SE blow-up.

The guard is also independent of `level`: at `level = 0.999` with `se = 9` it
returns `[1.80e-19, 9.50e+06]` as `"ok"`.

Required: rename the status/roxygen to what the guard actually tests
(e.g. `"se_blowup"`), **and** add a genuine near-zero-SD check consistent with
the package's existing `psi_rel_thresh` / `near_zero_psi_*` convention.
Tightening 10 → ~2 is defensible on the observed SE distribution but is a
maintainer call; the naming defect is not.

---

## PRIORITY 3 — full test suite

`NOT_CRAN=true OPENBLAS_NUM_THREADS=1 devtools::test()` on the full package,
run to completion (~40 min, 517 test files). **Verbatim tail:**

```
SKIP: 'test-zz-mspl-tweedie-beta-se-feasibility.R:175:3' ----------
Reason: tweedie MSPL family door is missing
SKIP: 'test-zz-mspl-tweedie-beta-se-feasibility.R:181:3' ----------
Reason: tweedie MSPL family door is missing
SKIP: 'test-zz-mspl-tweedie-beta-se-feasibility.R:199:3' ----------
Reason: Beta Q_P/Q_0 NLLs match on this cell; tapes are named but nll-difference is not informative
[ FAIL 1 | WARN 9 | SKIP 876 | PASS 16251 ]
```

### The one failure is caused by this PR

```
FAILURE: 'test-reader-facing-no-register-codes.R:80:3' ----------
Expected `length(offenders) == 0L` to be TRUE.
Differences:
`actual`:   FALSE
`expected`: TRUE

Internal register codes found on reader-facing surfaces (1 file(s)). A reader cannot resolve these.
man/slope_sd_ci.Rd:57,68: campaign has been run for this estimand, and \code{interval_status = "wald_uncalibrated"}

Restate the MEANING in plain words; do not simply delete a scope caveat.
For man/*.Rd, fix the roxygen source in R/ and re-run devtools::document().
```

Confirmed against the committed PR state in isolation — `git show
8d252109:man/slope_sd_ci.Rd` matched against the guard's own pattern gives
**2 hits, at exactly the reported lines**: line 57 *"See register row CI-14"*
and line 68 *"CI-15, \code{blocked})"*.

`man/slope_sd_ci.Rd` is generated from `R/slope-sd-ci.R`'s roxygen, which cites
`CI-14` and `CI-15` in the `@section Scope boundary` prose. This is the
CLAUDE.md standing rule — *"reader-facing content shows only what makes sense
to the reader — no internal register codes on any surface"* — and the guard
exists precisely because manual sweeps kept failing to enforce it.

**This directly refutes the after-task's justification for not awaiting the
run.** §10 argues: *"If that run surfaces any unrelated failure, it is not
attributable to this change by construction (no existing file was edited)."*
The reasoning is wrong in kind, not merely in outcome: the guard scans
generated `man/*.Rd`, so **adding a new documented export is exactly the
operation that can trip it**, and "the NAMESPACE delta is purely additive" is
not the relevant property. The one check the builder declined to wait for is
the one that caught the defect. Everything else is green: **0 unrelated
failures across 16,251 passes.**

The fix is the one the guard itself prescribes: restate the limit in plain
words in the roxygen, re-run `devtools::document()`, and keep the codes in
`docs/design/`, `dev/`, `docs/dev-log/` and `tests/`, where the guard's own
SCOPE note says they belong. **Do not delete the caveat to silence the test.**

### The guard has a blind spot this PR lands three instances in

The guard scans `vignettes/*.Rmd`, `man/*.Rd`, `NEWS.md` and `README.md`. It
does **not** scan message strings in `R/`. But CLAUDE.md's rule names
**printed output** as a reader-facing surface, and `slope_sd_ci()` puts
register codes into three runtime messages a user will actually see:

- `R/slope-sd-ci.R:163` (committed) — `cli_abort`: *"deliberately deferred
  (register row CI-15, docs/design/35-validation-debt-register.md)"*
- `R/slope-sd-ci.R:171` (committed) — `cli_abort`: *"deliberately deferred
  (register row CI-15)"*
- `print.gllvmTMB_slope_ci()` — *"recovery-only (D-112). Coverage is NOT
  certified for any family (CI-08/CI-10,
  docs/design/35-validation-debt-register.md)"*

A user who hits the refusal is told to consult "register row CI-15", which they
cannot resolve. Restate these in plain words too. They are still present in the
working tree as of this review, and the guard will never catch them.

---

## PRIORITY 4 — claims audit

| item | verdict |
|---|---|
| No coverage/calibration claim (D-112, Design 80) | **PASS.** No coverage claim in `R/`, `man/`, register, print, or NEWS. Fencing is consistent and load-bearing: `interval_status = "wald_uncalibrated"` on every row; `attr(out, "calibrated") <- FALSE` set once, never read as an argument, never conditional; print leads with the D-112 / CI-08 / CI-10 fence. |
| CI-14 `partial` for the diagonal route | **PASS on status; text needs an update after Priority 1.** Row present, ID unique. But the row's closing sentence — *"flagged in the print method and roxygen, not silently omitted"* — is now demonstrably an incomplete mitigation (see 1c). |
| CI-15 `blocked` for Cholesky/loadings routes | **PASS, and well-aimed.** The row explicitly states its purpose is to stop a future session widening slice 1 with a hand-indexed Jacobian, and the typed error class `gllvmTMB_slope_sd_ci_unsupported_route` backs it with tested behaviour. Good work. |
| Roxygen scope-boundary statement | **PASS.** `@section Scope boundary` is explicit about instrument, estimand, and what will error. |
| **RUNNABLE example** | **FAIL against the brief.** `man/slope_sd_ci.Rd` wraps the example in `\dontrun{}`, so it never executes under `R CMD check` and its `df_long` / `x` / `individual` are undefined placeholders. *Mitigating:* the named sibling `loading_ci()` does exactly the same, so this is house-consistent — but the brief asked for runnable and it is not. |
| No DESCRIPTION bump | **PASS** (not in the diff). |
| No NEWS capability headline | **PASS** (not in the diff). |
| `src/` untouched | **PASS** (not in the diff). |
| Files changed | `NAMESPACE`, `R/slope-sd-ci.R`, `docs/design/35-validation-debt-register.md`, `docs/dev-log/after-task/…`, `docs/dev-log/check-log.md`, `man/slope_sd_ci.Rd`, `tests/testthat/test-slope-sd-ci.R`. Additive only. |

### Two further claims that do not check out

**A. `pkgdown::check_pkgdown()` hard-errors.** Verified:

```
Error in `pkgdown::check_pkgdown()`:
! In _pkgdown.yml, 1 topic missing from index: "slope_sd_ci".
```

`_pkgdown.yml` carries an explicit 17-section `reference:` index with **no**
catch-all (`matches()` / `starts_with()` / `everything()` are all absent), and
lists the sibling `loading_ci` at line 383. A new export must be added or the
site build fails. This is one of the named local checks.

**B. `docs/dev-log/check-log.md` asserts a check that was never awaited.**
The tracked entry reads *"Full-package `devtools::test()` was also run; see the
after-task report for its result."* The after-task report says the opposite:
§4 records it as *"launched in background"*, and §10 states *"this session did
not block on its multi-hundred-file completion"* and *"it has not been
independently re-confirmed pass/fail in this report."* The after-task is
honest; the tracked check-log overstates it. Fix the permanent record.

### Provenance: both cited design documents are absent from this branch

`R/slope-sd-ci.R:41-45`, the test header, the after-task, **and register rows
CI-14 and CI-15** all cite:

- `dev/fable-extractor-recommendation.md` — **untracked**. Exists only in the
  working tree of a *different* worktree (`/private/tmp/gllvmtmb-randslope`,
  branch `claude/rand-slope-surface-20260818`), `git status` shows `??`. It
  will never reach `main` by any merge.
- `dev/slope-interval-feasibility-RESULTS.md` — **tracked, but only on
  `claude/rand-slope-surface-20260818`**. `git cat-file -e
  origin/main:dev/slope-interval-feasibility-RESULTS.md` → *does not exist in
  `origin/main`*.

`docs/design/35-validation-debt-register.md` is a permanent, tracked design
doc. Merging #1166 alone lands **two dangling citations in the register**,
including CI-15's load-bearing provenance note (*"exactly the computation a
first attempt got wrong … indexed entries 2/5/8 instead of the correct
2/4/6"*), whose supporting file a future reader cannot open.

*For the record, I read the feasibility document out of the sibling worktree
and it does substantiate every technical claim made against it* — the 2/5/8 vs
2/4/6 indexing bug, the `Var(slope_t) = L21² + exp(diag_slope)²` result, and
the Route B `theta` table. The provenance is real; it is only unreachable.

### One claim that DOES check out and deserves saying so

The after-task §10 justifies the absence of non-Gaussian evidence by asserting
`diag_B_slope` is Gaussian-gated at `R/fit-multi.R ~2203-2209`. **Verified —
it is a hard abort**, not a default:

```r
if (use_diag_B_slope && any(family_id_vec != 0L))
  cli::cli_abort("Augmented ordinary diagonal-compatibility random-regression slopes are currently implemented for Gaussian responses only.")
```

So the non-Gaussian gap is structurally unreachable and needs no family gate in
`slope_sd_ci()`. The citation is accurate.

---

## Minor findings (non-blocking)

1. `R/slope-sd-ci.R:197` — `slope_col <- fit$use$diag_B_slope_col %||% fit$use$rr_B_slope_col %||% "x"`. The final fallback silently labels the `term` column with the literal string `"x"`. If both are ever `NULL` this ships a wrong label rather than failing. Abort instead.
2. `attr(out, "level")` is set but not documented in `@return`.
3. `se_theta` is read by position from `cov.fixed`; alignment with `opt$par` was verified on a real fit (identical names, order and values), but the function does not assert it. A one-line `identical(names(fit$opt$par), rownames(fit$sd_report$cov.fixed))` check is cheap hardening against a future `map`/profile route.
4. `sqrt()` of a negative `cov.fixed` diagonal emits an uncaught base-R *"NaNs produced"* warning — the `tryCatch` at `R/slope-sd-ci.R:209-212` catches only errors. The `NaN` is then handled correctly by guard 2, but the stray warning reaches the user.
5. `interval_status` is a constant even on suppressed rows, diverging from the design doc's `"unavailable"` proposal. Defensible (the `status` column carries availability and `lower`/`upper` are `NA`), and the divergence is recorded in after-task §3a. No action.

## Required changes — ordered

1. **[Priority 1]** Add an in-band `component` column (`"unique_psi"` / `"total"`); fire `cli::cli_warn()` on the *call* when `rr_B_slope` is TRUE; add a point-estimate-only `total_sd` (and/or `rr_sd_omitted`) column from the already-`REPORT()`ed `fit$report$Sigma_B_slope`, with `lower`/`upper` left `NA`. Do **not** refuse.
2. **[Priority 4]** Add `slope_sd_ci` to `_pkgdown.yml`'s `reference:` index — `pkgdown::check_pkgdown()` currently hard-errors.
3. **[Priority 4]** Correct `docs/dev-log/check-log.md`: full-package `devtools::test()` was *launched and not awaited*, not "also run".
4. **[Priority 4]** Resolve the provenance: either land `dev/slope-interval-feasibility-RESULTS.md` (and a tracked form of `dev/fable-extractor-recommendation.md`) on this branch, or rewrite CI-14/CI-15 and `R/slope-sd-ci.R`'s header to cite only documents that reach `main`.
5. **[Priority 2]** Rename the `"boundary"` status and its roxygen to what the guard tests (SE blow-up), and add a genuine near-zero-`theta` check aligned with `R/diagnose.R`'s `psi_rel_thresh` / `near_zero_psi_*` convention. Evidence: `theta = -20, se = 0.5` returns `status = "ok"` with `estimate = 2.06e-09`.
6. **[Priority 2]** Add the `se_theta = Inf` case to the guard-2 test — the only branch where that guard suppresses a finite number — and soften after-task §5's blanket "all three are genuine failure-before-fix demonstrations", which the guard-2 test's own comment contradicts.
7. **[Priority 1/4]** Update CI-14's closing sentence once (1) lands; *"flagged in the print method and roxygen"* is not a sufficient mitigation as measured.
8. **[Minor]** Items 1–4 of the Minor findings above.
9. **[Optional, brief-vs-house]** The example is `\dontrun{}` and therefore not runnable as the brief required. House-consistent with `loading_ci()`; maintainer's call whether the brief or the house convention wins.

---

## Addendum 1 — the full-suite failure changes the required-change list

Insert as required change **0**; it is the only hard red gate in the list.

**0. [Priority 3]** `man/slope_sd_ci.Rd` trips
`test-reader-facing-no-register-codes.R`. Restate the `CI-14` / `CI-15`
citations in plain words in `R/slope-sd-ci.R`'s roxygen and re-run
`devtools::document()`. Then do the same for the three runtime messages (two
`cli_abort`s and the print method), which the guard cannot see.

## Addendum 2 — the worktree changed underneath this audit

**Scope of this review: commit `8d252109`, i.e. PR #1166 as committed.**

At 15:28, partway through the full-suite run, `/private/tmp/gllvmtmb-slopeci`
acquired uncommitted modifications to `R/slope-sd-ci.R` (+212 lines),
`tests/testthat/test-slope-sd-ci.R` (+114), `man/slope_sd_ci.Rd`,
`_pkgdown.yml` and `docs/design/35-validation-debt-register.md`, and both
previously-missing provenance documents appeared as untracked files. Another
lane is working this worktree concurrently.

Consequences, stated rather than buried:

- **Every measurement above was taken against `8d252109`**, and re-verified
  against it where the worktree had already moved (the `git show` check in
  Priority 3). The findings stand for the PR.
- **The full-suite run spanned the edit window.** `devtools::test()` loads the
  package once at start, so the R code under test was the committed version;
  but `test-reader-facing-no-register-codes.R` reads `man/*.Rd` from disk at
  test time, so it saw a partially-edited file. I therefore re-ran the guard's
  pattern against the committed `.Rd` in isolation (2 hits, at exactly the
  reported lines 57 and 68). **The failure is real for the PR as committed.**
- **The uncommitted work appears to address Priority 1 and required change 2**
  — a `component` column, a `total_sd` point estimate read from
  `fit$report$Sigma_B_slope`, a `cli::cli_warn()` on the call, a reference to
  `psi_rel_thresh` / `near_zero_psi_*`, and the `_pkgdown.yml` entry. **I have
  not audited any of it.** It is not in PR #1166, no test run covers it, and
  auditing a tree that is being written to is not an audit. If it is intended
  for this PR it must be committed and re-reviewed.
- **Lane hygiene:** two agents writing one worktree is the condition the
  lane-preflight discipline exists to prevent. This review file
  (`dev/S6-slope-sd-ci-review.md`) is itself untracked in a tree someone else
  is mutating.
