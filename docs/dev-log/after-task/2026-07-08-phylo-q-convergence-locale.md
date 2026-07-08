# After-task — `test-phylo-q-decomposition.R` convergence failure: a locale-dependent optimiser status code

**Date:** 2026-07-08 · **Agent:** Claude (Ada) · **Branch:** `claude/fix-phylo-q-convergence` (off `origin/main`)
**Status:** fixed + tested; **not merged**.

---

## 1. Goal

`tests/testthat/test-phylo-q-decomposition.R:172` failed on `main`
(`expect_equal(fit$opt$convergence, 0L)` → `1`). Establish whether this was a genuine
non-convergence (bad fit) or a cosmetic status, fix it honestly, get it into CI, and rule on
whether the register rows citing it may stay `covered`.

## 2. Implemented

- `tests/testthat/setup.R`: new test helper **`expect_converged(fit, grad_tol = 0.1)`**. Accepts
  `convergence == 0`; accepts PORT's `"false convergence (8)"` **only when the gradient is small**;
  rejects everything else. The full evidence is recorded in the comment above it so nobody
  re-derives it.
- `tests/testthat/test-phylo-q-decomposition.R:172`: `expect_equal(..., 0L)` → `expect_converged(fit)`,
  with an inline note so it cannot be silently "fixed" back.
- `tests/testthat/test-expect-converged.R` (new): 10 power tests for the helper — no model fits.
- `.github/workflows/phylo-q-decomposition-recovery.yaml` (new): the gate that was missing.

## 3a. Decisions and Rejected Alternatives

- **Rejected — raise `iter.max` / `maxit`.** Proven a **no-op**: the default run and a 10× budget run
  are byte-identical (objective `36622.10886176` both, `206` iterations both). The task brief (which I
  wrote) suggested this. It would have appeared to fix the test while changing nothing.
- **Rejected — `expect_true(convergence %in% c(0L, 1L))`.** Accepts genuine non-convergence
  (`"iteration limit reached without convergence (10)"` is also `1`).
- **Rejected — assert only the gradient, dropping the status entirely.** Loses the signal when PORT
  reports something we have never seen and should look at.
- **Chosen — accept `0`, or `"false convergence (8)"` with a small gradient.** This is the repo's own
  standing discipline: *trust recovery-to-truth over second-order flags.*
- **Rejected — migrate all 377 sibling assertions.** Out of scope, and a broad change. Flagged instead.
- **Rejected — pin the test's locale** with `withr::local_locale()`. `testthat` and `R CMD check`
  already set `LC_COLLATE = C`; pinning would hide the real lesson rather than record it.

## 4. Files Touched

- **Modified:** `tests/testthat/setup.R`, `tests/testthat/test-phylo-q-decomposition.R`
- **Created:** `tests/testthat/test-expect-converged.R`,
  `.github/workflows/phylo-q-decomposition-recovery.yaml`,
  `docs/dev-log/after-task/2026-07-08-phylo-q-convergence-locale.md` (this file)
- **Created and NOT deleted (permission denied):** `tests/testthat/test-zzz-qdebug.R` — a temporary
  instrumentation probe. **Untracked; must be removed by the maintainer:** `rm tests/testthat/test-zzz-qdebug.R`

## 5. Checks Run

| check | result |
|---|---|
| `test-expect-converged.R` | ✅ **10 PASS / 0 FAIL** (includes 6 `expect_failure()` power checks) |
| `test-phylo-q-decomposition.R` (heavy) | ✅ **14 PASS / 0 FAIL** (was `1 FAIL / 13 PASS`) |
| Diagnostic A: default `nlminb` | `conv 0` · `obj 36622.10886176` · `|grad| 4.694e-02` · `206 iters` |
| Diagnostic B: `nlminb`, 10× budget | `conv 0` · `obj 36622.10886176` · **byte-identical to A** |
| Diagnostic C: `optim`/BFGS | `conv 0` · `obj 36622.15263169` (slightly *worse*) · `|grad| 5.35e-01` |
| Inside `testthat` | `conv 1` · `"false convergence (8)"` · `obj 36622.108861` · `|grad| 1.950e-02` · `198 iters` |
| Standalone with `LC_COLLATE = "C"` | **identical to `testthat`**, byte for byte |
| `sigma2_Q` recovery | `mean rel err 0.1266` under **every** configuration (band: `< 0.50`) |

## 6. Tests of the Tests

`expect_converged()` is a guard, so it was checked for **power**, not just correctness. It must fail on:

- `"false convergence (8)"` with a **large** gradient (`5.0`) → fails ✓
- `"iteration limit reached without convergence (10)"` with a tiny gradient → fails ✓ *(same status code `1`, different message — the discriminating case)*
- any other non-zero status (`2`, `51`) → fails ✓
- a fit whose `gr()` **throws** → `gmax` is `NA`; `isTRUE(NA < tol)` is `FALSE`, so it fails rather than
  passing silently ✓
- `grad_tol` is honoured in both directions ✓

The failing/passing behaviour of the real test was established by **direct comparison against pristine
`main`**, not by inference: stash → reinstall → rerun.

## 7a. Issue Ledger

- **FIXED** — the failing assertion, by replacing a second-order flag with a criterion about the optimum.
- **FIXED** — no CI workflow referenced this test file at all (12 workflows set `GLLVMTMB_HEAVY_TESTS`;
  none ran it). New workflow added, and it **fails if any cell is skipped** — a gate that silently skips
  is not a gate, which is exactly how this went unnoticed.
- **OPEN, reported not fixed — the class.** `expect_equal(fit$opt$convergence, 0L)` appears **377 times
  across 184 test files**. Only 11 files ever inspect a gradient. Every one of the 377 asserts PORT's
  stopping code and is therefore locale-fragile on a flat likelihood. `expect_converged()` is the
  migration target. **Needs maintainer approval** — it is a broad sweep.
- **OPEN, informational — `gllvmTMB` results are collation-sensitive.** Character factor levels order
  the random effects, which orders the sparse Cholesky, which changes rounding. Same data, same model,
  different arithmetic path. Benign here (same optimum), but it means a user's locale can change the
  last digits and the optimiser's reported status. Worth a documentation note.

## 8. Consistency Audit

**Register verdict (task step 4): FG-12, PHY-02 and PHY-03 stay `covered`.**

The failing assertion was never the evidence. `expect_equal()` records a failure and *continues*, so the
recovery assertion at `:181` (`mean(rel_err) < 0.5`) ran and **passed** in every run, including the
failing one (`FAIL 1 | PASS 13`). `sigma2_Q` recovers to `12.7%` mean relative error against a declared
`50%` band, under both locales, both optimisers, and both iteration budgets. The claim those rows make
was always supported.

**I therefore withdraw my own earlier framing.** In the task brief I wrote that this was *"a
claims-integrity problem"* — a `covered` row whose evidence test does not pass. That was **overstated**:
the evidence passed; an auxiliary assertion about the optimiser's exit code did not. The *process*
concern was real and is now fixed (the evidence is CI-executed).

Noted but not acted on: **PHY-03 rests on a single test file.** Single-source evidence for a `covered`
row is worth a second look, separately.

**Neighbour check — the same disease, opposite symptom.** `tests/testthat/test-matrix-gamma-unit.R:81`
defines `expect_converged_pd()`, which **`skip()`s** when `fit$opt$convergence != 0` *or* when
`fit$sd_report$pdHess` is `FALSE`, with the comment *"Skips honestly instead of fake-passing."* That
converts a failure into a **silent loss of coverage** rather than a red test. It is also gated on
`pdHess` — the very flag that the aliased-diagonal defect (fixed the same day on
`claude/blv-coverage-breadth`) forced to `FALSE` for an entire class of fits. Any test using this helper
on such a fit was skipping, not passing. **Not investigated here; flagged.** Verified name-distinct from
the new `expect_converged()`, so there is no shadowing.

## 9. What Did Not Go Smoothly

Nearly every step of my own brief was wrong, and each had to be disproved by measurement:

- *"optimiser iteration limit"* → it is `"false convergence (8)"`, a PORT **stopping rule**. The budget is
  not binding. **Inference dressed as fact:** I read `convergence = 1` and named a cause.
- *"deterministic, not flaky"* → deterministic **given the locale**. It flips with `LC_COLLATE`.
- *"the recovery assertion is never reached"* → `expect_equal()` does not abort; it ran and passed.
- First hypothesis (**BLAS threading**) died on inspection: R links `libRblas.0.dylib`, single-threaded,
  so my `OPENBLAS_NUM_THREADS=1` was a **no-op** — meaning the run I thought was a controlled comparison
  was simply the test again.
- Second hypothesis (**preceding fits contaminate the session**) died on measurement: the seed-103 fit is
  byte-identical whether it runs first or second.
- Only instrumenting *inside* `testthat` (`LC_COLLATE = C`) and then reproducing it standalone closed it.
- `rm` of my temporary probe was denied by the sandbox; the file is untracked and must be removed by hand.

## 10. Known Residuals

- ✅ `test-phylo-q-decomposition.R` is now `14 PASS / 0 FAIL` (was `1 FAIL / 13 PASS`). The extra pass is
  the new criterion, not a suppressed check.
- ❌ `devtools::check()` not run on this branch (test-only + workflow change; no R code touched).
- **377 sibling assertions unmigrated.** Named, not fixed.
- **`grad_tol = 0.1` is an absolute tolerance on the negative-log-likelihood gradient.** It is right for
  this model (`nll ≈ 3.7e4`, `|grad| ≈ 2e-2`) but it is **not scale-free**. A small model with a tiny
  `nll` would want a tighter tolerance. The helper takes `grad_tol` per call for exactly this reason, but
  no scale-aware default has been derived.
- **The new CI workflow has never run.** It will first execute on the PR.
- `tests/testthat/test-zzz-qdebug.R` still on disk (untracked).

## 11. Team Learning

1. **A status code is not a verdict.** `nlminb`'s `convergence` answers *"did my stopping rule fire
   cleanly?"*, not *"is this a good optimum?"* On a flat likelihood PORT says `"false convergence (8)"`
   while sitting on a **smaller** gradient than the run it calls a success. 377 assertions in this repo
   ask the optimiser how it feels instead of measuring the fit.
2. **Locale is an input to the arithmetic.** `LC_COLLATE` orders character factor levels → orders random
   effects → orders the sparse Cholesky → changes rounding → changes the optimiser's path. `testthat` and
   `R CMD check` set `C`; your shell probably doesn't. A test can therefore report a different status
   from the identical fit you just ran by hand. This is the second time in one day that a *second-order
   flag* (`pdHess`, now `convergence`) sent a diagnosis in the wrong direction.
3. **Write the brief's claims as hypotheses.** I authored this task's brief and stated three inferences
   as established facts (`"iteration limit"`, `"deterministic"`, `"never reached"`). All three were
   wrong, and a less suspicious agent would have raised `iter.max` — a change that alters nothing — and
   closed the ticket green.
4. **A gate that can skip is not a gate.** This test had `skip_if_not_heavy()` and no workflow. The new
   workflow **fails on skip**.

**Memory receipt.** Loaded: `CLAUDE.md`, `AGENTS.md` hub guards, the task brief, the validation-debt
register. The guard that actually shaped the work: *trust recovery-to-truth over second-order flags* —
it named the bug (`convergence` is the flag; the gradient and the recovery are the truth) and it wrote
the fix. Also *run the ladder before condemning* (three optimiser configurations before any verdict) and
*never trust a self-report* — every claim in my own brief was re-measured, and three of them fell.
