# After Task: Clamp Tweedie p and warn when a pinned p hits the bound

**Branch**: `cursor/fix-1365-tweedie-p-clamp-fae3`
**Date**: 2026-11-09
**Roles (engaged)**: Gauss, Noether, Pat, Rose, Curie (checklists applied in this session; no separate reviewer process)

## 1. Goal

Issue #1365: `p = 1 + invlogit(logit_p_tweedie)` rounds onto 1 or 2 once
`|logit_p|` is above about 36.7, and `dtweedie` then returns NaN. Draft
#1506 clamps the logit to [-5, 5] and would silently change a user-pinned
power such as 1.001. Shinichi's decision on 9 Nov 2026 is to keep that
clamp and warn when a pinned power falls outside it, naming the requested
power and the power actually used.

## 2. Implemented

The density and `REPORT(p_tweedie)` both use

`p = 1 + invlogit(clamp(logit_p, -5, 5))`.

Inside the bound the map is unchanged. Outside it the likelihood is flat
in `logit_p` and `p` stays at about 1.006693 or 1.993307. `tweedie(p = ...)`
still accepts any single finite power strictly between 1 and 2. When the
pinned power's logit is outside [-5, 5], the stored pin is the bound and
the fit warns, for example:

```
Requested Tweedie power `p = 1.001000` is outside [1.006693, 1.993307].
ℹ The fit uses `p = 1.006693`.
ℹ Pass a power inside that range, or omit `p` to estimate it.
```

A pinned power inside the range does not warn, and the reported power
equals the requested power. The warning class is `gllvmTMB_tweedie_p_clamp`.

## 3. Files Changed

- `src/gllvmTMB.cpp` — clamp helper; density and report use it.
- `R/families.R` — same bound, warning text, `tweedie()` `@param p`.
- `R/fit-multi.R` — pinned logit is stored at the bound when it would
  otherwise lie outside [-5, 5].
- `man/families.Rd` — `@param p` text kept in step with the roxygen.
- `tests/testthat/test-fix-1365.R` — new regression file.
- `NEWS.md` — Development bullet.
- `docs/design/03-likelihoods.md` — Tweedie numerical note.
- `docs/dev-log/check-log.d/2026-11-09-fix-1365-tweedie-p-clamp.md`
- this report.

No example file, vignette, README, or formula-grammar file was edited.
`tweedie()`'s arguments and the accepted interval (1, 2) are unchanged, so
the convention-change cascade does not apply. `src` near the
`censored_poisson` branch was not edited.

## 3a. Decisions and Rejected Alternatives

Decision: keep #1506's bound of 5, and warn only for a user-pinned power
that hits it. Rationale: Shinichi, 9 Nov 2026. The template clamp still
covers a free `logit_p` that the optimiser drives past the bound; that
case does not warn, because the user did not pin a power. Rejected: silent
clamping of a pinned power (#1506), and rejecting `p` outside [1.0067,
1.9933] at `tweedie()` construction. Confidence: high. The variational
prototype template was left unclamped on purpose; it is not the #1365 path.

## 4. Checks Run

See `docs/dev-log/check-log.d/2026-11-09-fix-1365-tweedie-p-clamp.md`.
Targeted Tweedie and family-constructor tests passed. A full `test_check()`
was started and stopped after a segfault inside `lme4::glmer` on this
image's mixed lme4/Matrix install. That is recorded as not a valid suite
result.

## 5. Tests of the Tests

`test-fix-1365.R` fails if the clamp is removed: at `logit_p = 1000` the
unclamped power is exactly 2, and the test requires it to equal
`1 + plogis(5)` and to stay strictly inside (1, 2). The interior case
fails if `tweedie(p = 1.5)` warns or if the reported power is not 1.5.
The exterior case fails if 1.001 or 1.999 is silent, if the message omits
either the requested power or the power used, or if the reported power is
not the bound. The unclamped template was not recompiled in this session
to watch that first failure; the assertion is the one the issue's
arithmetic breaks.

## 6. Consistency Audit

Patterns and verdicts are in the check-log entry. New reader-facing prose
states the in-range behaviour, the warning at the bound, and that powers
of 1 or below and of 2 or above are not admitted. No register codes on
NEWS or the help page. FAM-13 is unchanged.

## 7. Roadmap Tick

N/A. No roadmap row.

## 7a. GitHub Issue Ledger

Inspected #1365 and draft #1506. This PR supersedes the approach in #1506.
#1506 and its branch were not edited, pushed, or closed. #1365 was not closed.

## 8. What Did Not Go Smoothly

The image had no R. After installing R and Suggests from apt, a full
`test_check()` segfaulted in `lme4`, so the package-wide suite was not
completed here. CI is the run that covers the fast suite on a consistent
library.

## 9. Team Learning

- Gauss: the bound is inside the region where `dtweedie` gradients were
  measured to degrade, which is why 5 is tighter than the double-rounding
  limit near 36.7.
- Noether: reported `p_tweedie`, the density, and a pinned parameter use
  the same clamped logit. The MSPL penalty still sees the raw logit and
  does not form `p`.
- Pat: the warning names both powers and says to pass an interior power
  or omit `p`.
- Rose: help, NEWS, and the likelihood note describe the same bound.
  Older NEWS entries that mention deprecated aliases were not rewritten.
- Curie: the new file is the regression. Existing Tweedie tests were not
  loosened.

## 10. Known Limitations And Next Actions

A free power that the optimiser drives onto the bound does not warn; the
likelihood is flat there and the Hessian can be non-positive-definite, as
in #1506. `inst/tmb/gllvmTMB_va_r3.cpp` still forms an unclamped power.
Powers of 1 or below, and of 2 or above, remain refused. Do not merge this
draft over #1506 without choosing one branch.
