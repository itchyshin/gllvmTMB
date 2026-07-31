# After-task — the three AGHQ engine fixes (#843, #871, #874)

**2026-07-31 · Claude (Fable 5) · branch `claude/aghq-engine-fixes-20260731` · PR #875**
**Slice 3 of the lane. The first two produced evidence; this one acts on it.**

## 1. Goal

Maintainer authorised acting on the lane's findings: merge #870, then make the engine
changes it argued for — #874 (a scale-aware convergence tolerance, and a gradient on the
stalled branch), #843 (ungate the start selection), and #871, which #843 depends on.

## 2. Implemented

- **#871** — `aghq_multistart` added to `gllvmTMBcontrol()`'s signature and returned list.
  It was read by the engine but never produced, so `...` swallowed it and the documented
  off-switch was unreachable. **This had to land first**: it is the opt-out for #843, and
  changing a default without a working off-switch is not something to ship.
- **#843** — the start selection is ungated and restructured. Both starts now run **to
  convergence** and the better **final** objective wins (penalised when a ridge is in force,
  since that is what the arm optimised). The old start-point proxy is removed.
- **#874** — a **relative** gradient leg (`aghq_grad_tol_rel`, `max|grad|/max(1,|F|)`)
  OR-ed with the absolute test; every stop now reports its gradient, including
  `stalled at cap 1`, which reported none; and seven machine-readable fields added
  (`converged`, `grad_max`, `grad_rel`, `grad_tol`, `grad_tol_rel`, `n_starts`,
  `start_used`).
- Tests, NEWS, and roxygen for both new arguments.

## 3a. Decisions and Rejected Alternatives

- **Selection on the final objective, not the start point.** The in-source objection —
  "without a penalty there is nothing to choose on" — is true of two *starting points* and
  false of two *converged fits*. That distinction is the whole fix.
- **The relative tolerance is an OR, not a replacement.** So nothing that converged before
  stops converging; the new leg can only ever *add* convergent cases. That makes the change
  monotone and much easier to reason about than a swapped criterion.
- **Rejected inventing a scaling law.** I measured gradient growth at three n and it looked
  like ~√n, but three points is not a rate. A relative-gradient criterion is the standard,
  dimensionally sensible construction and does not require me to be right about the exponent.
- **Rejected re-indenting the adaptation loop.** The #843 change wraps ~250 intricate lines
  in a per-start loop. Re-indenting would have made every line of a delicate optimiser show
  up in the diff. The body is unchanged and a comment says the indentation is deliberate.
- **Rejected lowering the convergence bar to make cells "converge".** The relative leg is
  principled; tuning a threshold until the campaign looks better would be the exact
  post-hoc move this lane exists to prevent.
- **Changed one test — and treated that as a finding, not a chore.** See §8.

## 4. Files Touched

| file | change |
|---|---|
| `R/gllvmTMB.R` | two new control arguments + roxygen |
| `R/fit-multi.R` | per-start loop, final-objective selection, relative tolerance, gradient reporting, new fields |
| `tests/testthat/test-aghq-multistart-convergence.R` | new — 27 assertions |
| `tests/testthat/test-aghq-surface.R` | exactness test corrected + one new assertion |
| `NEWS.md`, `man/gllvmTMBcontrol.Rd` | user-facing documentation |
| `dev/aghq-evidence/26-verify-874.R` | the paired before/after measurement |

## 5. Checks Run

- **New tests: 27 assertions, 0 failures, 0 skipped** — run with `NOT_CRAN=true`, because
  the first run showed 5 of 7 tests silently **skipped** on `skip_on_cran()` and *skipped is
  not passing*.
- **AGHQ suite: 105 assertions, 0 failures** (up from 103 — the two added assertions).
- **Full suite: see PR #875** — re-run against the final state, after an earlier run was
  invalidated by my own test correction mid-flight and stopped rather than left to mislead.
- `devtools::document()` clean; no NAMESPACE change, so no pkgdown index risk (a break this
  repo has hit four times).
- **Behavioural verification, which is the real check:**
  - #843 on the known-bad seed 2003: ‖Λ̂‖/‖Λ‖ **29.70 → 2.365**, objective
    **379.7134 → 375.179**; `aghq_multistart = FALSE` reproduces `379.7134` exactly.
  - #874 paired on identical data: convergence n=100 **8.3% → 25.0%**, n=400 **0% → 58.3%**,
    with median ‖Λ̂‖/‖Λ‖ **byte-identical** (9.0131/9.0131, 1.1647/1.1647).

## 6. Tests of the Tests

The load-bearing check is the **byte-identical estimate** under the #874 change. A
convergence-criterion fix must change the *verdict* and not the *answer*; if the estimates
had moved, the tolerance would have been steering the optimiser. That property is now a
test, not just an observation.

The second is **backward compatibility as an assertion on a measured number**:
`aghq_multistart = FALSE` must return `379.7134` on seed 2003 — the pre-#843 value. A
regression in the off-switch fails loudly rather than silently drifting.

The third is the **prose/field agreement** test: `aghq$converged` must equal
`grepl("^converged", stop_reason)`. The two could drift apart, and a caller trusting the
field while a reader trusts the prose is exactly how this lane's first measurement went
wrong.

The new tests were also verified to actually *run* — the `skip_on_cran()` discovery above
means the suite's headline count had been flattering.

## 7a. Issue Ledger

- **#843, #871, #874** — fixed in PR #875; each issue updated with the measured result.
- **#871 remains partly open by design**: correcting `19-warmstart-vs-flatness.R`'s arm
  labels, and promoting `sweep-control-fields.R` to `tests/`. Both are separate from the
  engine change.
- **#874 step 3** — adding `aghq_grad_tol` to the **#857** scale-constant inventory belongs
  with that inventory, not here.
- **#847** — unchanged, but its τ recalibration should now be sequenced *after* this, since
  the runaway rate it would calibrate against has moved.

## 8. Consistency Audit

**The one test I changed deserves scrutiny, so here is the reasoning in full.**
`GAUSSIAN EXACTNESS` asserts `AGHQ objective == Laplace objective`, and it began failing.
It runs with the **default ridge (τ = 2)** — so it was comparing a MAP fit against an MLE.
That equality was never something that *should* hold; it held only because the optimiser
was not finding the better penalised point, which is precisely the non-movement the repo
already records as a defect (audit §5, `decisions.md:1927-1938`). The integrator was never
implicated: with the penalty off it reproduces Laplace to **~1e-10 at k = 3 and k = 9,
single- or multi-start**. The test now isolates the integrator, **and** gains a new
assertion that with the ridge on the objectives must differ — so the discovery is guarded
rather than merely explained. Net: strictly stronger. Flagged in the PR for review anyway,
because "my change broke a test so I changed the test" deserves a second pair of eyes
regardless of how good the reasoning feels from the inside.

Walking the neighbourhood: the `opt$convergence` trap is now stated in **three** places
that a user or agent might actually read — NEWS, the `aghq_grad_tol_rel` roxygen, and a
test — rather than only in a dev-log audit. That is deliberate; the audit is where I found
it and the last place anyone would look.

## 9. What Did Not Go Smoothly

- **My first version of the new test file silently skipped 5 of its 7 tests** (`skip_on_cran`
  with `NOT_CRAN` unset) and reported "Your tests rock". Caught only because the count
  looked too small. Skipped is not passing.
- **The test helper `.aghq_smoke_ok()` lives inside another test file**, so it was not
  visible; the first run errored rather than skipping. Replaced with a local equivalent.
- **A stale full-suite run was left competing for cores** with its replacement after I
  corrected the tests mid-flight. Stopped it rather than let two runs fight and one mislead.
- The gaussian regression cost real time to diagnose, and the first hypothesis (that #874
  caused it) was wrong — isolating it required running the two changes independently.

## 10. Known Residuals

- **Convergence at n = 400 is now 58%, not ~100%.** The remaining stalls are a *separate*
  question about the continuation schedule, and the new gradient reporting shows why: stalls
  sit at ~50× tolerance, so they are genuinely not near-misses. Worth its own issue if the
  campaign needs them.
- **This corrects my own earlier claim in #874.** I called the counterfactual a *lower*
  bound on the assumption stalls might be near-misses. With gradients now reported, they are
  not — so the original estimate was optimistic about the mechanism, though the direction
  and the fix both hold. Corrected in the issue thread rather than left standing.
- **n = 1600 convergence is not re-measured** post-fix. Expected to improve on the same
  mechanism, but expected is not measured.
- **The campaign has still not run.** #874 was its blocker and is now fixed, but the
  converged-only population should be re-checked before committing 16,000 fits.
- **`aghq_multistart = TRUE` costs one extra adaptation run** — roughly double the AGHQ
  time. Measured for poisson n=1600: 18 s → 268 s for the alternative start alone.

## 11. Team Learning

- **"There is nothing to choose on" was true of the wrong object.** The in-source reasoning
  was sound about *starting points* and simply did not transfer to *converged fits*. Worth
  remembering as a shape: a correct argument applied to the wrong noun.
- **A criterion fix must be provably estimate-neutral**, and that is cheap to test. If a
  convergence change moves the answer, it was never a convergence change.
- **Make the off-switch work before changing the default.** #871 looked cosmetic until #843
  needed it.
- **Skipped tests inflate confidence.** Any new test file should be run once with
  `NOT_CRAN=true` and its skip count read, not just its failure count.

## 12. Cross-Product Coverage

The `opt$convergence`-means-the-iteration-cap trap generalises to any TMB package with a
capped inner loop — **drmTMB** if it adopts a similar adaptation schedule. The
fixed-absolute-tolerance class is already tracked cross-repo in the #857 inventory, and
`aghq_grad_tol` belongs on it.

**Memory receipt.** Loaded and used: CLAUDE.md's merge authority (this is a
likelihood/engine change, so it went to a PR for review rather than self-merge, even with
the maintainer's go-ahead on the arc); "tests ship with implementation"; the local-checks-
over-CI rule (full suite run locally before relying on GitHub Actions); D-50; and the Rose
principle, which drove §8 — putting the `opt$convergence` trap in three reader-facing places
rather than only the audit where I happened to find it. I did **not** query the brain MCP:
the work was repo-local and its inputs were this lane's own measurements.
