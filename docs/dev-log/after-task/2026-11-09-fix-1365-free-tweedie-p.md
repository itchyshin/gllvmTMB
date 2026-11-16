# After Task: Smooth bound on an estimated Tweedie power

**Branch**: `cursor/fix-1365-free-tweedie-p-ea44`
**Date**: `2026-11-09`
**Roles (engaged)**: Ada (implementation), Gauss and Noether (the map, its derivative, and the density grid), Curie (the new tests), Rose (the cross-file formula scan)

## 1. Goal

Issue #1365: an estimated Tweedie power could walk into the region where TMB's `dtweedie` is wrong and then NaN. Shinichi's decision on 9 Nov 2026 was a smooth bound that keeps the estimate away from 1 and 2, plus a warning when a free fit ends at that bound. A hard clamp had already been rejected because the gradient is zero outside it.

## 2. Implemented

The stored parameter `logit_p_tweedie` is no longer `p = 1 + invlogit(theta)`. It is

    p = p_lo + (p_hi - p_lo) * (1/2) * (1 + theta / sqrt(1 + theta^2))

with `p_lo = 1 + invlogit(-12)` and `p_hi = 1 + invlogit(12)`, about 1.000006144 and 1.999993856. The factor `(1 + theta^2)^(-3/2) / 2` is positive for every finite theta, so there is no flat region. Theta 0 is still p = 1.5.

The same expression is `gll_tweedie_p` (Laplace density, `REPORT(p_tweedie)`, and the MSPL family-6 weight), `va_r3_tweedie_p` (variational quadrature and its report), and `.gllvmTMB_tweedie_p` (the pin inverse, Wald and profile transforms). A pinned power inside `(p_lo, p_hi)` is the exact inverse, so the reported power is the requested power. `p_tweedie` stays a `REPORT`, not an `ADREPORT`.

A free fit whose reported power is within 1e-5 of either end warns with class `gllvmTMB_tweedie_p_boundary`. The message names the estimate and that end, to 12 decimal places. A mapped-off power, including a user pin, does not warn.

This is not a new family, not a change to the 6 x 3 keyword grid, and not a change to the MSPL working logistic weight. The weight still does not depend on p. It forms p only so that path cannot drift from the density.

## 3. Files Changed

- `src/gllvmTMB.cpp` — `gll_tweedie_p`; Laplace density; REPORT; MSPL weight.
- `inst/tmb/gllvmTMB_va_r3.cpp` — `va_r3_tweedie_p`; quadrature power; REPORT.
- `R/families.R` — forward map, inverse, boundary warning.
- `R/fit-multi.R` — pin, start comment, warning on the Laplace/MSPL return.
- `R/va-r3-proto.R` — variational pin.
- `R/va-routing.R` — warning on a variational return.
- `R/z-confint-gllvmTMB.R`, `R/profile-targets.R`, `R/confint-inspect.R` — Wald and profile transform.
- `man/families.Rd` — `p` argument, edited by hand to match the roxygen. roxygen2 8.0.0 is not installed here, so `devtools::document()` was not run.
- `NEWS.md`, `docs/design/03-likelihoods.md`, `docs/design/35-validation-debt-register.md` (FAM-13 note), `docs/dev-log/known-limitations.md`.
- `tests/testthat/test-fix-1365-free-p.R` — new.
- `tests/testthat/test-va-all-family-compiled.R` — the 1e-12 pin check uses the new map. The tolerance is unchanged.
- `tests/testthat/test-tweedie-fixed-p.R`, `tests/testthat/test-mixed-dispersion-pinning-1117.R` — comments only.
- `docs/dev-log/check-log.d/2026-11-09-fix-1365-free-p.md`.

`README.md`, `ROADMAP.md`, `_pkgdown.yml` and vignettes do not state the old formula. No example syntax changed: `tweedie(p = ...)` still accepts one number strictly between 1 and 2.

## 3a. Decisions and Rejected Alternatives

**Decision.** Algebraic map onto logit ±12, warning distance 1e-5 in p.

**Rationale.** On the declared grid (phi at least 0.1, mu up to 50, y up to 100, 616 cells) logit ±12 stays within relative error 1e-6 of `tweedie::dtweedie`. Logit 12.4 fails (73 of 546 cells, max relative loglik error 1.14e-5). Logit −14 fails (3 of 404). The table is in `docs/design/03-likelihoods.md`. A logistic squash, `p = p_lo + (p_hi - p_lo) * invlogit(theta)`, has a derivative that rounds to 0 by `|theta| ≈ 37`, which is the same cliff the bug already has, so an extreme start would not keep a non-zero gradient. The algebraic derivative at theta = 1000 is still about 5e-10 and the fit gradient there was finite and non-zero (about 100 on the interior fixture).

**Rejected.** The hard clamp in #1506 and #1747: zero gradient outside the clamp, silent boundary, singular Hessian. Also rejected: claiming 1e-6 for every phi > 0. Phi = 0.02 already fails at logit 11 (relative loglik error 1.48e-3 at y = 1, mu = 1). TMB caps the series at 20000 terms.

**Confidence.** High on the declared grid and on the round-trip of pins. The interior nlminb stop moved by about 2.5e-6 in p because the gradient scale changed. The objective matched main to about 1e-11 relative.

## 4. Checks Run

See `docs/dev-log/check-log.d/2026-11-09-fix-1365-free-p.md`. Tweedie-related files passed. Shard 4 of 4 was `FAIL 50 | WARN 16 | SKIP 305 | PASS 4933`. The failures are missing packages and one pre-existing source regex, not this bound.

`rg -n "1 \+ (stats::)?plogis\(logit_p|qlogis\(p_pin|invlogit\(logit_p_tweedie" R src inst tests man docs NEWS.md` — no matches.

`devtools::document()` was not run (roxygen2 8.0.0 is not installed). `man/families.Rd` was edited to match the roxygen `@param p` text. `pkgdown::build_articles` was not run; no article or parser example changed.

## 5. Tests of the Tests

`test-fix-1365-free-p.R` would fail if the forward map reverted to `1 + invlogit`: a theta of 20 would then report a different p, and the test requires the Laplace, MSPL and VA reports to equal `.gllvmTMB_tweedie_p(20)` and to differ from `1 + plogis(20)` by more than 1e-4. It would fail if the warning class or the printed estimate and bound disappeared. It would fail if an extreme theta (±40, ±100, ±1000) made the objective non-finite or the `logit_p_tweedie` gradient exactly 0. The pinned-power loop would fail if 1.7, 1.99999 or 1.00001 did not round-trip to 1e-12. The density test would fail if the one-row objective at 1e-8 inside either end disagreed with `tweedie::dtweedie` by more than 1e-6 relative. That last test is the only `skip_if_not_installed("tweedie")` in the file.

The variational compiled test still requires the pinned power 1.7 to 1e-12. The assertion now uses the new map. The tolerance was not loosened. No `# nocov` was added.

## 6. Consistency Audit

`rg -n "1 \+ (stats::)?plogis\(logit_p|qlogis\(p_pin|invlogit\(logit_p_tweedie" R src inst tests man docs NEWS.md` — no matches. The old formula is not still described as current.

`rg -n "gll_tweedie_p|va_r3_tweedie_p|\\.gllvmTMB_tweedie_p" R src inst tests` — the three copies and the R callers are the sites listed in section 3. No fourth formula remains.

`rg -n "gllvmTMB_tweedie_p_clamp" R tests NEWS.md` — the clamp warning is the #1747 class, retargeted at `[p_lo, p_hi]`. In-range pins go through `.gllvmTMB_tweedie_theta`.

## 7. Roadmap Tick

N/A. No roadmap row describes this numerical bound.

## 7a. GitHub Issue Ledger

Inspected #1365 (this fix), #1747 (pinned-p warning) and #1506 (rejected hard clamp, left untouched). #1365 was not closed. No comment was posted on #1747 or #1506. This branch is rebased onto #1747 (`cursor/fix-1365-tweedie-p-clamp-fae3`) and must merge after it. The fixed-power interval is the same `[p_lo, p_hi]` as the estimated power.

## 8. What Did Not Go Smoothly

`1 + invlogit(theta)` is already a poor density well before it returns NaN. On TMB 1.9.25 the declared grid breaks between logit 12.3 and 12.4, not at logit 37. Phi = 0.02 breaks earlier still. The interior optimum in p moved by a few millionths under nlminb even though the objective matched, because the new map changes the gradient scale. Shard 4 on this machine failed 50 tests for missing `tidyr` and `ape`, for `tools::sha256sum` on R 4.3.3, and for a beta-clamp regex that does not match main.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Gauss: the likelihood in p is unchanged inside the interval. The parameterisation is what keeps theta finite and the density inside the checked region. Noether: the C++ helper, the variational copy and `.gllvmTMB_tweedie_p` are the same expression, and the inverse is exact on the open interval, including at p = 1.5 where theta is 0. Curie: the new file separates the interior match, the boundary warning, the three engines, and the density check, and it does not weaken an existing tolerance. Rose: the old `1 + plogis` formula is gone from the pin, the reports and the four R transforms together.

## 10. Known Limitations And Next Actions

Phi below 0.1 is outside the density grid. A free fit that ends on the bound and has fitted dispersion below 0.1 says so in `gllvmTMB_tweedie_p_boundary`. A fixed power outside `[p_lo, p_hi]` and still in (1, 2) is kept at the nearer end and warns with `gllvmTMB_tweedie_p_clamp` on the Laplace and VA paths. The public MSPL door for Tweedie stays closed. The heavy recovery files were not re-run. Code is on a draft PR and is not merged. This PR must merge after #1747.
