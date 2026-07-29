# After-task — R CMD check to 0/0/0

Date: 2026-07-29 · Platform: Claude Code · Branch: `claude/green-check-20260729`
Base: `origin/main` @ `f9a127fe`

## 1. Goal

Get `R CMD check` clean locally. It is the CRAN gate for 0.6.0, and everything else is downstream.

## 2. Implemented

`R CMD check` went **1 ERROR / 0 WARNINGS / 0 NOTES → 0 / 0 / 0**.

Two installed-path fixes plus one policy change:

- `R/eva-proto.R` — `.eva_gate1_file()` and `.eva_find_source()` now fall back to `system.file()`.
- `inst/extdata/86-eva-gate1-parameters.json` — the 3.3 KB fixture now ships.
- `skip_on_cran()` on the 12 prototype blocks that build a TMB objective.

## 3a. Decisions and rejected alternatives

- **Rejected: `skip_if()` guards as the fix for the ERROR.** That clears the error by hiding 7 tests
  — the pattern that already leaves 80 of 109 missing-data blocks unexercised by default. Making
  them *run* was the point.
- **Reversed mid-task, on the maintainer's information:** VA/EVA development is paused; LA and AGHQ
  are the active engines. My first fix therefore had CRAN's machines compiling a DLL for parked
  work — the wrong trade. `skip_on_cran()` corrects it **without** hiding anything locally.
- **Kept the path fixes anyway.** They are genuine bugs whether or not the prototype is active, and
  they are cheap. The cheap path tests run unguarded so they stay honest.
- **Rejected: dropping the shipped fixture** once the tests skip on CRAN. 3.3 KB, and it is what
  makes the tests runnable from an installed package at all rather than only skippable.

## 4. Files touched

Modified: `R/eva-proto.R`, `tests/testthat/test-eva-gate1.R`, `tests/testthat/test-va-r3-prototype.R`
Created: `inst/extdata/86-eva-gate1-parameters.json`,
`tests/testthat/test-eva-gate1-fixture.R`, this report

## 5. Checks run

| Check | Result |
|---|---|
| `rcmdcheck` before | 1 ERROR / 0 W / 0 N |
| `rcmdcheck` after fix 1 | 1 ERROR (a *different* one — see §9) |
| `rcmdcheck` after fix 2 | **0 / 0 / 0** |
| `rcmdcheck` after `skip_on_cran` | **0 / 0 / 0** |
| full suite | **5383 pass / 0 fail / 0 warn** |
| prototype gates, `NOT_CRAN=true` | eva **23 pass / 0 skip**, va **352 pass / 0 skip** |
| prototype gates, `NOT_CRAN` unset | eva 4 blocks skip, va 8 blocks skip |

The last two rows were measured in both directions rather than assumed — the whole point of
`skip_on_cran()` is that local development is unaffected, and that claim needed evidence.

## 6. Tests of the tests

`test-eva-gate1-fixture.R` pins the defect directly: it resolves both paths from a temp directory
with **no repo above it**, which is exactly the condition that broke under check and that
`load_all()` never reproduces. It also md5-compares the shipped fixture against the source copy, so
the two-copy hazard the fix introduces cannot drift silently.

## 7a. Issue ledger

Check is clean locally. Two of the three problems originally scoped for this lane had already been
fixed by other lanes — see §9.

## 8. Consistency audit

- Swept `R/eva-proto.R` for the whole defect class rather than fixing the reported instance:
  **exactly two** source-layout resolutions (`:8`, `:95`), both fixed and pinned. The `setwd()` at
  `:141` is a build directory, not a resolution. The class is closed.
- Swept both prototype files for objective-building blocks, not just the one that failed: 4 + 8.
- Re-measured `main` before recommending work, which is how the stale items were caught.

## 9. What did not go smoothly

**Two of my own three recommendations were already fixed.** I had proposed starting with the
`.onLoad` `object 'AIC' not found` failure and a codoc mismatch. Re-measuring on merged `main`
showed both gone — `R/aghq-report.R:208` now passes `envir = asNamespace("stats")`, and the comment
there documents the entire diagnosis. Recommending from a check run against a superseded tree would
have wasted a lane.

**My codoc script produced a false positive.** It reported an argument `"shared"` documented but not
in the code; my regex had truncated the usage block at the `)` inside `c("per_trait", "shared")`.
`rcmdcheck` reports 0 warnings and is authoritative. Discarded my own output.

**Fixing the first path exposed a second.** The check could not reach `.eva_find_source()` until the
JSON resolved. Fix-and-rerun would have found it eventually; sweeping the file found it immediately
and bounded the class.

**The first AGHQ probe did not exercise AGHQ.** It fell back to Laplace with a warning because the
model was ineligible (ordinary `latent()` puts `s_B` in the random vector; Stage 1a is
loadings-only). Reporting composition from that run would have been a false-clean finding.

## 10. Known residuals

- **A clean local check is not a clean CRAN check.** One platform (macOS), and
  `--no-manual --no-build-vignettes`. The 3-OS matrix and a manual/vignette build are still required
  before submission. 0.6.0 should not be called check-ready on this evidence alone.
- `response = "include"` composes with AGHQ without error, but **Gaussian cannot discriminate AGHQ
  from Laplace** (Laplace is exact there), so AGHQ engagement on the masked likelihood is
  **unverified**. A non-Gaussian AGHQ × `include` test is the honest next step.
- `REML = TRUE` still rejects `response = "include"` outright — a real gap in the FIML story under
  REML, unaddressed here.
- The prototype gates now skip on CRAN. If VA/EVA is resumed, that decision should be revisited.

## 11. Team learning

**`devtools::test()`-green is not evidence for anything path- or namespace-related.** Three defects
this session shared one shape — green under `load_all()`, red under `R CMD check`: the two paths
here, and the `AIC` `.onLoad` failure whose own source comment says the same thing. `load_all()`
short-circuits installation, so any bug that only exists in an *installed* package is invisible to it.

**Re-measure before recommending.** Two of three recommendations were stale within hours, on a repo
with several concurrent lanes.

**A fix that clears an error by hiding tests is not a fix** — unless the tests genuinely should not
run there. Both judgments appear in this lane, and the distinction is *why* the tests are skipped:
hiding a user-facing contract is a defect; sparing CRAN a parked prototype's compile is policy.

## 12. Cross-product coverage — the negative space

- Not a CRAN readiness claim: single platform, no manual, no vignettes.
- No coverage or interval claim anywhere.
- Does not resume, fix, or validate VA/EVA — it only stops CRAN building them.
- Does not verify AGHQ against a masked likelihood for any non-Gaussian family.
- Does not audit other packages' path helpers beyond `R/eva-proto.R`.
