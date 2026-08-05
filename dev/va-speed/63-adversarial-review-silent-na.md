# Adversarial review — "a fit without standard errors no longer answers silently"

**Reviewer:** Rose (closeout / claims lens, adversarial posture — default "this is broken").
**Date:** 2026-08-04.
**Worktree:** `/private/tmp/gllvmtmb-va-lane2`, branch `claude/va-lane2`.
**Basis of review:** commit `0a280205` *"fix(se): a fit without standard errors no longer answers silently"*. Working tree is clean against it (`git diff --stat` empty).

**State caveat, recorded because it affects reproducibility of this review.** The change was
*uncommitted* when I started and was edited under me mid-review:
`R/z-confint-gllvmTMB.R` mtime moved to 09:18:14 while I was probing, then everything was
committed. The edit I observed corrected a real cosmetic bug in the first version — the
`%||%` fallback read `"the fit carries no {.field sd_report}"`, and because that string is
interpolated into `cli_abort()` as a **value**, cli would not evaluate the inline markup and
`{.field sd_report}` would have printed literally. That bug is **gone** in `0a280205`
(fallback now reads `"no standard errors were computed for this fit"`, with a comment
explaining why). Verified: no raw markup leaks. **All verdicts below are against `0a280205`.**

Everything marked "verified" was **run**, not reasoned about. Scripts are in the session
scratchpad; the reproducible fit recipes are inlined per section.

---

## Fits used

```r
# F1 "minimal": 80 rows, 2 traits, gaussian, obs-level unit — no covariance tiers
gllvmTMB(value ~ 0 + trait, data = g, family = gaussian(), unit = "obs_id",
         control = gllvmTMBcontrol(se = <TRUE|FALSE>))

# F2 "covariance-bearing": simulate_site_trait(n_sites=25, n_species=3, n_traits=3, seed=42)
gllvmTMB(value ~ 0 + trait + latent(0 + trait | site, d = 1) + unique(0 + trait | site),
         data = s$data, control = gllvmTMBcontrol(se = <TRUE|FALSE>))

# F3 "ordinal": 200 individuals x 2 traits, ordinal_probit(), K = 4 / K = 3
gllvmTMB(value ~ 0 + trait + unique(0 + trait | individual), data = df,
         unit = "individual", family = ordinal_probit(),
         control = gllvmTMBcontrol(se = <TRUE|FALSE>))
```

Confirmed precondition: `se = FALSE` ⇒ `fit$sd_report` is `NULL` and
`fit$sdreport_error == "standard-error calculation skipped by gllvmTMBcontrol(se = FALSE)"`
(set at `R/fit-multi.R:6083`).

---

## A. Did a legitimate workflow break?

### VERDICT: **PASS** — no regression found.

Every one of these **returned normally** on the `se = FALSE` fit (F1 unless noted):

`summary()` · `print(summary())` · `print(fit)` · `tidy(fit, "fixed")` ·
`tidy(fit, "fixed", conf.int = TRUE)` · `predict()` (no se) · `getLoadings()` ·
`extract_Sigma()` · `extract_Sigma_B()` · `extract_ICC_site()` ·
`extract_communality()` · `logLik()` · `AIC()` · `residuals()` · `fitted()` ·
`simulate(nsim = 1)` · `profile_targets()` · `standard_errors()`.

On F2 (`se = FALSE`), additionally: `confint(parm = "Sigma_unit", method = "bootstrap")`,
`confint(parm = "Sigma_unit", method = "wald")`, `confint(parm = "Lambda", method = "profile")`,
`confint(parm = "rho:unit:1,2")`, `summary()` — all returned.

Errors observed that are **NOT** regressions from this diff (each checked against the diff
and/or against the `se = TRUE` control):

| Call | Why it is not a regression |
|---|---|
| `predict(fit, se.fit = TRUE)` | Aborts `gllvmTMB_predict_se_no_sdreport`. Pre-existing; `R/` predict code is untouched by this diff. This is the sibling behaviour the change is modelled on. |
| `vcov(fit)` | No method exists for `gllvmTMB_multi`. Pre-existing gap, already flagged in the EXT-36 register row itself. |
| `fixef()` / `ranef()` / `diagnose()` | Not exported under those names in this package. Probe error, not package error. |
| `extract_proportions(F1)` | "No identifiable variance components in this fit." Fails **identically on the `se = TRUE` fit**; a property of F1's model shape, not of `sd_report`. Returns fine on F2 with `se = TRUE`. |

**Test-suite check:** `testthat::test_file()` on `test-confint-bootstrap.R`,
`test-confint-derived.R`, `test-confint-inspect.R`, `test-confint-lambda.R` — **zero failures**
(heavy Lambda cases skipped by the existing `GLLVMTMB_HEAVY_TESTS` gate).
`test-standard-errors.R` passes clean (17 expectations).

---

## B. Is the abort too broad?

### VERDICT: **DEFECT FOUND** — the guard is not too broad; it is too *narrow* for the claim made about it. Two findings.

### B0 — the literal question: no, the guard blocks nothing that could have worked.

Every earlier routing branch `return()`s, so none can reach the guard. Verified empirically on
`se = FALSE` fits that the following still behave exactly as on the `se = TRUE` control:

| Path | Intercepts at | `se = FALSE` result |
|---|---|---|
| `parm = "Sigma_unit"`, `method = "bootstrap"` | `:1660` → `.confint_sigma` | finite bootstrap bounds — **works** |
| `parm = "rho:unit:1,2"` (fisher-z) | `:1632` | returns `[0.4359857, 0.8624922]` — **numerically identical to the `se = TRUE` fit** |
| `parm = "Lambda"`, `method = "profile"` | `:1567` | returns |
| `parm = "Lambda"` (default wald) | `:1567` | errors on `lambda_constraint`, same as `se = TRUE` |
| `icc` / `communality:*` / `proportion` | `:1596`/`:1620`/`:1644` | already abort with their own `sd_report` messages |

Only two things reach the guard: the terminal fixed-effects path, and the deliberate
`method = "bootstrap"` fall-through from the `profile_targets` block (`:1696-1699`). Both
genuinely require SEs. **No regression.**

Mutation check (see §F, M5): making the guard over-broad (dropping the
`is.null(object$sd_report)` conjunct) is caught by the shipped test T2.

### B1 — DEFECT: `.confint_wald_targets` keeps the identical defect, and it returns *before* the guard.

`R/z-confint-gllvmTMB.R:1278-1329`, specifically the D-33 anti-pattern at **`:1309-1312`**:

```r
    se <- tryCatch(
      sqrt(diag(object$sd_report$cov.fixed))[idx],
      error = function(e) NA_real_
    )
    if (is.na(se) || !is.finite(se)) {
      lower[i] <- NA_real_
      upper[i] <- NA_real_
```

`confint()` reaches this via `:1694`, **nineteen lines before** the new guard at `:1713`.
Verified on F2 (`se = FALSE`) — every non-`b_fix` `profile_targets()` label returns a
**silent all-NA interval, no error, no warning**:

```
confint(sF, parm='sigma_eps',            method='wald')  -> ALL-NA
confint(sF, parm='Lambda_B_packed[1]',   method='wald')  -> ALL-NA
confint(sF, parm='Lambda_B_packed[2]',   method='wald')  -> ALL-NA
confint(sF, parm='Lambda_B_packed[3]',   method='wald')  -> ALL-NA
confint(sF, parm='sd_B[1]',              method='wald')  -> ALL-NA
confint(sF, parm='sd_B[2]',              method='wald')  -> ALL-NA
confint(sF, parm='sd_B[3]',              method='wald')  -> ALL-NA
```

7 of 7. These are not obscure tokens — they are the exact labels
`profile_targets(fit, ready_only = FALSE)` hands the user. `sigma_eps` exists on **every**
Gaussian fit, including the trivial F1.

**Consequence for the claim, not just the code.** `NEWS.md` says the old behaviour was that
`confint()` "return[ed] a matrix of `NA` bounds with no error and no warning — a non-answer
that looks like an answer," and presents that as fixed. After `0a280205` that sentence is
**still literally true** of `confint()` for a documented parm set. `docs/design/35-…md`
EXT-35 is marked "**→ CLOSED 2026-08-04 by EXT-36**"; EXT-36 titles itself "Missing standard
errors are reported, never returned as a silent all-`NA` answer." Both overclaim.

### B2 — DEFECT (justification): the comment at `:1707-1709` is false about its own file.

> "Every sibling consumer of `sd_report` in this package already aborts here
> (`getREsd()`, `getLV(se = TRUE)`, `predict(se.fit = TRUE)`); this path was the outlier."

The three functions named do abort. But the relevant siblings are the ones **inside
`confint()`**, and they do not:

- `.confint_wald_targets` — returns NA (B1 above).
- `.confint_sigma_wald` — returns NA bounds. Verified: `confint(parm = "Sigma_unit",
  method = "wald")` returns `lower = NA, upper = NA` on **both** the `se = FALSE` **and the
  `se = TRUE`** fit. (Unrelated pre-existing defect, larger than the one being fixed, but it
  is the same file and the same sentence's subject.)
- `.confint_lambda` — deliberately returns NA **with `pd_hessian` and `ci_status` marker
  columns** (`:338`, `:365`, `:458`, `:499`), and that is a *tested contract*:
  `tests/testthat/test-confint-lambda.R:356` — *"pdHess = FALSE: Wald paths return NA +
  pd_hessian = FALSE"*.

So the package already has an established in-`confint()` convention for this exact situation:
**marked** NA, not abort and not bare NA. The change makes `confint()` internally
inconsistent — same object, same missing-SE condition, `parm = "Lambda"` returns flagged NA
while the fixed-effects path aborts. I am not arguing abort is wrong; I am recording that the
stated rationale does not survive contact with the file it is written in, and that the
flagged-NA route was available and arguably better (it composes; an abort does not).

---

## C. Is `method = "bootstrap"` now wrongly blocked?

### VERDICT: **PASS** (one wording nit).

Bootstrap has **no** legitimate no-`sd_report` route on the path the guard sits on. The
fixed-effects bootstrap branch (`:1729-1735`) prints *"Bootstrap on fixed effects is not
implemented; falling back to `method = "wald"`"* and then calls
`tidy(object, "fixed", conf.int = TRUE)` — which is exactly the all-NA producer. Verified
directly:

```
tidy(fitF, "fixed", conf.int = TRUE)
    term  estimate std.error     link conf.low conf.high
1 traita 0.9429109        NA identity       NA        NA
2 traitb 2.0013388        NA identity       NA        NA
```

So `method != "profile"` is the right predicate for **this** path: gating bootstrap here
replaces an all-NA with an error. Confirmed `confint(fitF, method = "bootstrap")` now aborts
`gllvmTMB_confint_no_sdreport`, and `confint(fitT, method = "bootstrap")` is unchanged.

Bootstrap **where it has a real implementation** — `parm = "Sigma_*"` — intercepts at `:1660`
and never reaches the guard. Verified finite bootstrap bounds on the F2 `se = FALSE` fit.
Nothing wrongly blocked.

**Nit (not a defect):** a user who typed `method = "bootstrap"` is told *"cannot compute a
**Wald** interval"*. True (the fallback is Wald) but oblique, and the message does not mention
that `parm = "Sigma_*"` bootstrap is a live route on this very fit.

---

## D. Does the error message tell the truth?

### VERDICT: **PASS.** Both remedies verified end to end.

The message claims two things. Both hold.

**Claim 1 — `method = "profile"` works without SEs.** Verified on F1 `se = FALSE`:

```
confint(fitF, method = "profile")     ->  traita [0.8253839, 1.060438]
                                          traitb [1.8838119, 2.118866]
confint(fitT, method = "profile")     ->  identical to the above
confint(fitF)   # default is "profile" ->  identical
```

Finite, and bit-identical to the `se = TRUE` control. Mechanism checks out:
`.confint_fixef_profile` (`:2049`) drives `tmbprofile_wrapper` off `fit$tmb_obj` / `fit$opt`
and only uses `tidy()` for the estimate column, overwriting `conf.low`/`conf.high` with
profile bounds. **Also note `method` defaults to `"profile"`**, so the plain `confint(fit)`
call is untouched by this change.

**Claim 2 — `fit <- standard_errors(fit)` fixes it.** Verified:

```
f2 <- standard_errors(fitF); confint(f2, method = "wald")
           2.5 %   97.5 %
traita 0.8267995 1.059022
traitb 1.8852274 2.117450
```

and the `summary()` note correctly disappears on `f2`.

**Robustness of the message text**, verified separately:
- Rendered message is clean; no raw cli markup leaks (the pre-commit bug is fixed).
- Fallback branch (`sd_report` NULL **and** `sdreport_error` NULL, reachable by hand-editing a
  fit) renders "no standard errors were computed for this fit". Clean.
- **Glue-injection safe:** setting `fit$sdreport_error <- "sdreport failed at {nrow(x)} rows"`
  prints the braces literally and does not error or evaluate. Good.

---

## E. Did the note become noise?

### VERDICT: **DEFECT FOUND** — not noise (it is correctly silent), but it keys on the wrong predicate and hunk 3 leaks onto a surface that has no `tau_se` column.

### E0 — the literal question: no, it is not noise.

- `se = TRUE` (F1 and F2): note **absent**. Verified.
- `se = FALSE`: note present, once, under the fixed-effects table.
- **No fixed effects at all:** the note lives inside `if (!is.null(x$fixef))`
  (`R/methods-gllvmTMB.R:810`), and `summary()` only sets `out$fixef` when `nrow(df) > 0L`
  (`:726`). Verified by setting `sm$fixef <- NULL` and printing: note absent.
- Backward-compatible: an older summary object has no `se_status`, and
  `isFALSE(NULL$available)` is `FALSE`, so no note. Safe.
- `extract_cutpoints()` on an `se = TRUE` ordinal fit: **0 messages**. On `se = FALSE`: 1.

### E1 — DEFECT: `se_status` asks "is `sd_report` NULL?", not "are the SEs usable?"

`R/methods-gllvmTMB.R:766` keys on `is.null(object$sd_report)`. That covers the *deliberate*
way SEs go missing (`se = FALSE`) and misses the *involuntary* one (non-PD Hessian /
`sdreport()` returning non-finite `cov.fixed`), which is the case a user is far more likely to
hit without knowing why. Verified by forcing `cov.fixed` non-finite on an `se = TRUE` fit:

```
se_status$available : TRUE
note fires          : FALSE
Fixed effects:
             Estimate Std.Err
traittrait_1    1.536     NaN      <- exactly the wall of bare non-numbers the change exists to prevent
...
confint(bad, method = "wald")  ->  all NaN, returned silently, straight through the new guard
```

This is not only synthetic. On the **real** `se = TRUE` ordinal fit F3, `extract_cutpoints()`
returns `tau_se = NaN` for trait `b` with **no message at all**:

```
                   trait cutpoint_label tau_estimate   tau_se
ordinal_cutpoints      a     cutpoint_2    0.6243088 0.139964
ordinal_cutpoints1     a     cutpoint_3    1.4429097 0.292063
ordinal_cutpoints2     b     cutpoint_2    0.6150408      NaN   <- unexplained
```

So the headline — "a fit without standard errors no longer returns a silent all-`NA` answer" —
holds for `se = FALSE` and fails for a failed Hessian, on all three surfaces the change
touches. It also **falsifies the register's stated reason** for descoping the
`.gllvmTMB_b_fix_se()` `{value, status}` refactor: EXT-36 says it became "unnecessary once no
user-facing surface reports its NA silently." A user-facing surface still does.

### E2 — DEFECT (minor): hunk 3's `cli_inform` fires on `print(fit)`, which shows no `tau_se`.

`extract_cutpoints()` has internal callers. `R/methods-gllvmTMB.R:687` calls it from
`print.gllvmTMB_multi`. Verified on the F3 `se = FALSE` fit:

```
print(ordinal fit, se = FALSE)   messages = 1
  > i tau_se is `NA`: this fit has no sd_report. -> fit <- standard_errors(fit)

what print() actually shows:
  Cutpoints (ordinal_probit, tau_1 = 0 fixed):
   trait cutpoint_label tau_estimate      <- there is no tau_se column here
```

The message names a column the reader cannot see on that surface. `tidy()` (the other caller,
`:1051`) does **not** leak — verified 0 messages for `tidy(oF)` and `tidy(oF, "fixed")`; nor
does `print(summary(oF))`. Also fires once per call (3 consecutive
`extract_cutpoints()` calls → 3 messages), which is normal `cli_inform` behaviour but noisy in
a loop.

---

## F. Read the tests critically — would each actually fail if the fix were reverted?

### VERDICT: **PASS on all four tests** (none is vacuous) — but coverage is narrower than the register claims.

Method: I did not reason about this. I captured the shipped `confint.gllvmTMB_multi` and
`summary.gllvmTMB_multi` from the loaded namespace, built mutants by **surgically deleting the
new hunk from the function body** (i.e. reverting it), reinstalled each mutant with
`assignInNamespace()`, and re-ran the four tests transcribed assertion-for-assertion.

Mutants:
- **M1** — delete the guard statement from `confint()` body (= revert hunk 1). Confirmed
  exactly 1 matching statement found and removed.
- **M2** — `summary()` returns with `se_status` stripped (= revert hunk 2; makes
  `isFALSE(NULL$available)` FALSE, so the print note cannot fire).
- **M3** — `se_status` always `available = FALSE` (over-firing note).
- **M4** — M1 + M2 (full revert of hunks 1–2).
- **M5** — guard rewritten as `if (method != "profile")`, dropping the
  `is.null(object$sd_report)` conjunct (= the "abort too broad" error from §B).

| | T1 abort | T2 se=TRUE unchanged | T3 summary works+explains | T4 no note on se=TRUE |
|---|---|---|---|---|
| SHIPPED | PASS | PASS | PASS | PASS |
| M1 revert guard | **FAIL** | PASS | PASS | PASS |
| M2 revert note | PASS | PASS | **FAIL** | PASS |
| M3 note always fires | PASS | PASS | PASS | **FAIL** |
| M4 revert both | **FAIL** | PASS | **FAIL** | PASS |
| M5 over-broad guard | — | **FAIL** | — | — |

**Per test:**

1. **T1 `confint(method='wald')` aborts — REAL.** Dies under M1. Both assertions carry weight:
   the class check and the separate `regexp = "standard_errors"` check (the remedy text is the
   thing that makes the abort actionable, and it is asserted independently).
2. **T2 `confint()` unchanged on a fit that has SEs — REAL, but one-sided; describe it
   correctly.** It cannot fail on a *revert* (M1/M2/M4 all pass) — a reviewer skimming it would
   reasonably call it vacuous. It is not: it **fails under M5**, the over-broad-guard error,
   which is precisely the §B failure mode. It is a guard against a *wrong implementation of the
   new code*, not against its absence. Worth saying so in the comment, which currently only
   says "the abort must key on a NULL sd_report, never on 'some bound happens to be NA'."
   *Fragility note:* `ci[vapply(ci, is.numeric, logical(1))]` was written for a data.frame.
   The fixed-effects path returns a **matrix** (`class(ci)` verified `matrix/array`), so
   `vapply` iterates over *elements*, not columns, returns all-TRUE, and the subset happens to
   be the whole matrix. Correct by accident. Harmless today; silently wrong the day the return
   type changes.
3. **T3 `summary()` survives and explains — REAL.** Dies under M2. Both halves matter
   (`expect_no_error` locks the deliberate non-abort; `expect_match` locks the explanation).
4. **T4 no note on an `se = TRUE` fit — REAL, but one-sided.** Cannot fail on revert; **fails
   under M3**. It is an over-firing guard, and its comment ("A note that always prints is not a
   note") describes it accurately. Fine as written.

**Reconciliation of the register's "3 failures → 0" claim:** a full revert (M4) kills 2 *tests*
but 3 *expectations* (T1's two `expect_error`s + T3's `expect_match`). testthat counts
expectations. **Consistent — claim holds.**

**Coverage gaps, all verified:**

- **Hunk 3 (`R/extract-cutpoints.R`) has ZERO test coverage.** `grep -rn "tau_se" tests/`
  returns **nothing**; no test in the repo asserts the new `cli_inform` or its absence. Yet
  register row EXT-36 lists `test-standard-errors.R` as the evidence for
  "`summary()` and `extract_cutpoints()` keep working but report why". The `extract_cutpoints()`
  half of that sentence is untested. **Overclaim.** (I verified the behaviour by hand — see §E —
  so the code is right; the *coverage claim* is not.)
- No test covers the `.confint_wald_targets` hole (§B1) — so the defect can silently persist.
- No test covers the non-finite-SE case (§E1) — same.
- The register describes the row as "4 gates". Three of the four bear on `confint`/`summary`;
  none touches the third file changed.

---

## Summary of defects, in priority order

| # | Where | Severity | What |
|---|---|---|---|
| 1 | `R/z-confint-gllvmTMB.R:1309-1312`, reached at `:1694` | **Blocking for the claim** | `.confint_wald_targets` still returns a silent all-NA interval for every non-`b_fix` `profile_targets()` label (7/7 verified). `NEWS.md`'s headline and EXT-35's "→ CLOSED" are falsified by a one-line call. |
| 2 | `R/methods-gllvmTMB.R:766` (and the guard's predicate) | **High** | `se_status` / the guard key on `is.null(sd_report)`, not on the SEs being usable. A non-PD Hessian gives bare `NaN` in `summary()`, `NaN` in `extract_cutpoints()`, and an all-`NaN` `confint()` — all silent. Also falsifies the register's reason for dropping the `.gllvmTMB_b_fix_se()` refactor. |
| 3 | `docs/design/35-…md` EXT-36 | **High** | Claims `test-standard-errors.R` covers `extract_cutpoints()`. It does not — no test in the repo mentions `tau_se`. |
| 4 | `R/z-confint-gllvmTMB.R:1707-1709` | Medium | Comment claims "every sibling consumer already aborts". Three siblings inside `confint()` itself return NA instead; one of them (`.confint_lambda`) does so as a *tested contract* with marker columns. |
| 5 | `R/extract-cutpoints.R:82-88` | Low | The inform fires from `print(fit)`, whose cutpoint table has no `tau_se` column. |
| 6 | `tests/testthat/test-standard-errors.R` T2 | Low | `vapply(ci, is.numeric, ...)` written for a data.frame; return is a matrix. Correct by accident. |

**Not defects (checked and cleared):** no legitimate workflow regressed; the abort is not too
broad; bootstrap-with-a-real-route is untouched; the error message tells the truth on both
remedies; the note is correctly silent when SEs exist and when there is no fixed-effects table;
all four tests can fail; glue injection is safe; no raw cli markup leaks; the confint test
suite is green.

---

## Overall

**DO NOT SHIP AS WRITTEN — the code may ship; the closure claim may not.**

The engineering is sound and I could not break it. What I can break is the sentence written
around it. `NEWS.md` says `confint()` no longer returns an unmarked NA matrix, and the register
marks EXT-35 "→ CLOSED"; but on this branch, on a two-line fit,
`confint(fit, parm = "sigma_eps", method = "wald")` still returns

```
          2.5 % 97.5 %
sigma_eps    NA     NA
```

with no error and no warning. Minimum to ship: either extend the guard to
`.confint_wald_targets` (`:1309-1312`, the same D-33 `tryCatch`-to-NA pattern), or narrow the
NEWS/register wording to the fixed-effects Wald path it actually closes and open a row for the
rest. The second is cheap and honest; the first is better. Do not leave the current wording
standing — it is the kind of claim a reader can falsify in one call.
