# After-task — #813: steps 1 and 2 landed; the fix did NOT land, and that is the finding

**2026-07-30 · Claude (Fable 5) · lane `claude/813-instrument-20260730`, off `main` @ `11310590`**

Plan: `~/.claude/plans/drifting-scribbling-truffle.md`. Rehydrated from
`docs/dev-log/handover/2026-07-30-handover-docs-arc-and-813.md` §4.

**Bottom line.** Steps 1 (instrument) and 2 (measure) are done and shipped, and they **reorder the
issue**. Two candidate fixes were built and measured; **neither passes the pre-registered gate**, so
**no fix is claimed and none is shipped**. What ships is the evidence, the instrumentation, the
corrected metric, and a decision for the maintainer.

**No public route, no export, no coverage claim. Issue #813 stays OPEN.**

## 1 · Step 2 — the withdrawal reason is half right, and the half it gets right is not the big one

`.fix_and_refit_nll()` already computed the achieved constraint value and the refit's convergence
status, then discarded both. Instrumented and measured on the #824 fixture (Gaussian d=1, n=120, 4
traits, 60 constrained refits, seed 42):

| the stated reason (`R/extractors.R:267`) | verdict |
|---|---|
| "accepts **loose constraints**" | **NOT SUPPORTED.** Median abs constraint error 1.1e-5, max 1.4e-3, against the **0.05** tolerance the route accepts. Zero of 60 points rejected for missing the constraint. |
| "and **unconverged refits**" | **SUPPORTED.** 3 of 60 refits had `nlminb` convergence != 0 yet contributed points to the curve. |
| *(named by neither half)* | Adjacent *converged*, *constraint-satisfied* points landed on different local optima; `delta_deviance` fell while moving AWAY from the MLE. |

**Step 4 (exact-constraint solver) targets a problem that measurement says is not there.**

**And the package already knew about row 3.** `.invert_profile_derived()` detects a non-monotone side
and applies `smooth.spline(spar = 0.6)`; its own comment (`R/profile-derived-curves.R:256`) calls it
*"the boundary-case signature of a noisy Lagrange refit at a near-degenerate ridge"*. The drift was
**smoothed over, not handled** — so a bound there is an average across optimiser failures. That is
why fixing the cause has to precede calibration, not follow it.

## 2 · Candidate A — sequential continuation. Built, then withdrawn.

Warm-start each grid point from its neighbour's constrained optimum, relaxed iteratively, keeping
only strict improvements. **It met the plan's pre-registered criterion exactly: non-monotone steps
8 -> 0.** An independent adversarial review (Opus, fresh context, briefed to refute, running its own
probes) withdrew it:

1. **The criterion was Goodharted.** The audit flagged a step at a drop of **1e-6 deviance** — six
   orders of magnitude below the 3.84 chi-square_1 cutoff — and the relaxation's fixed point is
   nearly the condition that removes such drops. *The fix was being scored on the metric it
   optimises.*
2. **The selection rule compared the wrong quantity:** raw `nll` between candidates at *different*
   achieved constraint values. Since the profile falls toward the MLE, that rewards drifting toward
   it. Measured: constraint error **grew at 20 of 28** wins; the winner sat on the MLE side at 25/28.
3. **The relaxed curve never reached the reported interval.** `.invert_profile_derived()`
   short-circuits to bounds from `.profile_ci_via_refit()`, which had no continuation — so
   `plot.profile_derived()` would draw a relaxed curve against un-relaxed bounds. A self-
   contradicting plot is a regression in a user-facing artifact.
4. The termination argument was wrong (a strictly decreasing bounded sequence need not terminate; a
   kept "improvement" of 2.65e-8 was observed), and the result was order-dependent.

## 3 · Candidate B — raise the refit budget. Better, and still not shippable.

`eval.max`/`iter.max` 100 -> 5000, `rel.tol` 1e-7 -> 1e-10 in `.fix_and_refit_nll()`'s default
`control`. Head-to-head on the same fixture and seed:

| metric | baseline | continuation (~17 min) | budget only (~4 min) |
|---|---|---|---|
| unconverged refits accepted | 3 | 0 | **0** |
| max abs constraint error | 1.36e-3 | 4.56e-4 | **4.56e-4** |
| t2 upper chi-square_1 crossing | 0.64481 | 0.65356 | **0.65356** |
| non-monotone steps (>1e-3 dev) | 8 | 0 | 7 |

Strictly better than A on cost and on mechanism: same CI-relevant effect at a quarter of the price,
no selection rule, no termination question, and — verified — `.profile_ci_via_refit()` calls
`.fix_and_refit_nll()` **without** a `control` argument, so curve and bounds move **together**.

**But it fails the gate.** In file context it moves
`profile_communality(): grid-inverted bounds agree with profile_ci_communality() to 1e-2` from
**pass to fail**, at **0.01053 against 0.01000** — over by 5.3%. Confirmed by re-running the same
file with the old budget restored, where only the pre-existing #837 failure appears.

Diagnostic, not excuse: **in isolation, on a fresh fit, the two paths agree to 6.3e-06** — three
orders of magnitude inside the tolerance. The file-context number comes from the *cached, shared,
mutated* fixture (`build_curve_fixture()`), and the test's own comment already records 0.0103 on
Ubuntu and 0.18 on Windows, which is why it carries `skip_on_ci()`. So the budget change appears to
push macOS onto the failure mode the other two platforms already show. **That is a hypothesis with
supporting evidence, not a cleared verdict — and "it was already fragile" is exactly the
rationalisation that should not be allowed to carry a merge.**

## 4 · Why nothing was shipped as a fix

The plan's DISCIPLINE line was: *the audit's non-monotone count must fall to ~0 **and**
`test-profile-derived-curves.R` must not regress.*

- **A** met the count (but the count was the wrong instrument) and was refuted on method.
- **B** does not reach ~0 (7 residual) **and** regresses one test.

Neither passes. Tuning `rel.tol` until the test passes, or widening the tolerance, would be fitting
the fix to the gate; the test's own comment and #837's diagnosis both forbid the latter. So the
budget change is carried as a **separate, clearly-labelled commit** for the maintainer to accept or
drop, and this document claims no fix.

## 5 · What did ship

| item | status |
|---|---|
| `.details = TRUE` instrumentation (achieved value, constraint error, convergence, status) | `c9fe5db3` |
| `dev/profile-communality-constraint-audit.R` — two monotonicity thresholds, 1e-6 labelled a noise detector; reports the chi-square_1 crossing directly | this commit |
| `tests/testthat/test-profile-refit-instrumentation.R` — 12 light-tier tests | this commit |
| budget change | **separate commit, flagged as failing the gate** |

The instrumentation tests are deliberately **fit-free and light-tier**: every curve test is
`skip_if_not_heavy()`, and #837 is live proof that heavy-gated tests do not get run.

The audit's corrected metric matters as much as the numbers — the 1e-6 threshold can no longer be
quoted as a quality score.

## 6 · Side findings (both requested)

**S5 — a real regression on `main`, filed as #837.** `bb4862bb` (2026-07-28) moved
`.profile_bounds()` to zeta-scale interpolation on the *reference* path without updating the *curve*
path; they disagree by **0.163**, deterministically. Invisible to CI (`skip_if_not_heavy()` +
`skip_on_ci()`); that commit's own evidence line reads "117 passed, 0 failed, **99 skipped**".

**S6 — CI-06 is NOT an over-claim; the scan that prompted the slice was wrong.** The row reads
**`blocked`**, not `covered`, which the register's legend defines as "advertised but currently
broken… or requires removal from public surface" — accurate. `NEWS.md`, the profile vignette and
`capability-surface.html` all correctly state the route is unavailable. **No defect, no action.**

## 7 · NOT done — deliberately

No public route (`extract_communality(method = "profile")` still aborts) · no export · no coverage or
calibration claim · #813 open · no boundary semantics for `c2 -> 1` (step 3) · exact-constraint
solver deferred on evidence (step 4) · calibration untouched (step 5) · the far-tail local-optimum
drift **not fixed** · the shared-fixture TMB-state contamination in `test-profile-derived-curves.R`
diagnosed but not fixed.

## 8 · The lesson

The impressive fix and the correct fix were different, and **the pre-registered criterion could not
tell them apart** — it was authored before the reviewer existed to challenge it, and it counted a
pathology without stating the scale at which that pathology matters. What caught it was an
independent agent briefed to *refute*, with the ability to run its own probes; a self-check would
have shared the priors that produced the metric.

## 9 · Landing state

| branch | committed | pushed | merged |
|---|---|---|---|
| `claude/813-instrument-20260730` | instrumentation `c9fe5db3` + this arc's evidence commits | yes | **n — maintainer's act** |
