# After Task: Warn when a pinned Tweedie p hits the bound

**Branch**: `cursor/fix-1365-tweedie-p-clamp-fae3`
**Date**: 2026-11-09
**Roles (engaged)**: Gauss, Noether, Pat, Rose, Curie (checklists applied in this session; no separate reviewer process)

## 1. Goal

Issue #1365: `p = 1 + invlogit(logit_p_tweedie)` rounds onto 1 or 2 once
`|logit_p|` is above about 36.7, and `dtweedie` then returns NaN. Draft
#1506 clamps the logit in the template. That also bounds a free power, and
a pinned power such as 1.001 would change with no warning. The review on
#1747 blocked a template clamp for the same reason: free-p fits were not
part of the decision.

Option (a), this revision: keep the bound on the pinned path only. When a
user pins `p`, store `logit_p` inside [-5, 5] (so `p` stays in
[1.006693, 1.993307]), warn once with the requested power and the power
used, and pass that fixed value through the existing map. Free `p` is
unchanged, and `src/` matches main.

## 2. Implemented

`tweedie(p = ...)` still accepts any single finite power strictly between
1 and 2. The constructors do not warn. At fit time,
`.tweedie_pinned_logits()` maps a pin whose logit is outside [-5, 5] onto
that endpoint and emits one `gllvmTMB_tweedie_p_clamp` warning per distinct
requested power. For `p = 1.001` the warning is:

```
Requested Tweedie power `p = 1.001000` is outside [1.006693, 1.993307].
ℹ The fit uses `p = 1.006693`.
ℹ Pass a power inside that range, or omit `p` to estimate it.
```

Laplace and MSPL store that logit on `logit_p_tweedie` and map it off in
`R/fit-multi.R`. VA does the same in `.va_r3_make_objective()`, so a
multi-start fit warns on the first start only. A pin inside the interval
is `qlogis(p - 1)`, with no warning. Omitting `p` does not call the helper.

The first commit on this branch clamped inside `src/gllvmTMB.cpp`. That
change is reverted. The density and `REPORT(p_tweedie)` are main's
`p = 1 + invlogit(logit_p)`.

## 3. Files Changed

- `R/families.R` — pin helper, warning, `tweedie()` `@param p`.
- `R/fit-multi.R` — Laplace and MSPL store the pinned logit.
- `R/va-r3-proto.R` — VA stores the same pinned logit.
- `man/families.Rd` — `@param p` text kept in step with the roxygen.
- `tests/testthat/test-fix-1365.R` — pinned-power tests, plus a free
  interior power compared with the unclamped objective and `p`.
- `NEWS.md` — Development bullet.
- `docs/design/03-likelihoods.md` — Tweedie numerical note.
- `docs/dev-log/check-log.d/2026-11-09-fix-1365-tweedie-p-clamp.md`
- this report.

`src/` is unchanged against main. No example file, vignette, README, or
formula-grammar file was edited. `tweedie()`'s arguments and the accepted
interval (1, 2) are unchanged, so the convention-change cascade does not
apply.

## 3a. Decisions and Rejected Alternatives

Decision: option (a), R pin only. Rationale: review of #1747 at
`1748f9c9`; a template clamp changes free-p fits, which was not decided.
Rejected: the template clamp in the first commit on this branch, and the
silent template clamp in #1506. Confidence: high. Bounding a free power
stays open.

## 4. Checks Run

See `docs/dev-log/check-log.d/2026-11-09-fix-1365-tweedie-p-clamp.md`.
`git diff origin/main -- src/` is empty.

## 5. Tests of the Tests

`test-fix-1365.R` fails if a pinned `p = 1.001` or `1.999` is silent, if
the message omits either power, or if the reported power is not the
endpoint. It fails if `tweedie(p = 1.5)` warns or the reported power is
not 1.5. The free-p test fails if the fitted power is not interior, if
the reported power is not `1 + plogis(logit_p)` within 1e-10, or if the
stored objective is not the template objective within 1e-10. It does not
assert that an estimated power is bounded.

## 6. Consistency Audit

New reader-facing prose states the pin, the warning, and that estimation
is unchanged. No register codes on NEWS or the help page. FAM-13 is
unchanged. The likelihood note no longer says the template clamps.

## 7. Roadmap Tick

N/A. No roadmap row.

## 7a. GitHub Issue Ledger

Inspected #1365 and draft #1506. This PR supersedes the approach in #1506
and then narrows it to the pinned path. #1506 and its branch were not
edited, pushed, or closed. #1365 was not closed.

## 8. What Did Not Go Smoothly

The first commit clamped the template. The review blocked that because it
changes free-p fits. This revision reverts `src/`. A full `test_check()`
on this image still is not a valid suite result: an earlier attempt
segfaulted inside `lme4::glmer`.

## 9. Team Learning

- Gauss: the endpoint is the same ±5 bound as #1506, applied only to a
  stored pin. The free parameter can still reach the `dtweedie` NaN.
- Noether: Laplace, MSPL and VA read one fixed logit. The template formula
  is unchanged.
- Pat: the warning names both powers and says to pass an interior power
  or omit `p`.
- Rose: help, NEWS, and the likelihood note describe the pin and leave
  estimation unchanged.
- Curie: the extreme-logit assertion was removed. The free-p check is an
  interior comparison with main's unclamped formula.

## 10. Known Limitations And Next Actions

A free power is not bounded. `|logit_p|` past about 36.7 can still make
`p` exactly 1 or 2 and the density non-finite. Whether to bound an
estimated power is an open decision. Powers of 1 or below, and of 2 or
above, remain refused.
