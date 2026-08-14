# ARC CARD — Lane B LA-MSPL interval feasibility

**Mode:** size  
**Requested outcome:** establish whether a finite, stable *experimental* interval can be constructed for selected binary LA-MSPL point-estimation fits; not a calibrated confidence-interval claim.  
**Mechanism authority:** isolated branch; read and edit only the experimental MSPL/profile implementation, local fixtures, tests, and internal design/log records. No remote simulation campaign, public API promotion, release claim, or removal of the existing fail-closed inference fence.  
**Recommended arc:** 2.5 hours, after a 15-minute informal orientation probe.  
**Time contract:** ceiling 2.5 hours; the first probe may stop the arc early.  
**Estimate confidence:** inferred. Existing B2 measured point-fit costs but does not provide a close timing analogue for nuisance-reoptimised MSPL profiles.  
**Arc 0 outcome:** a source-level feasibility decision and, if admitted, one finite profile prototype for one fixed-effect target.  
**State transition:** point-estimation-only MSPL -> one retained interval-feasibility prototype, or an explicit typed blocker.  
**Executable rung and evidence:** hold a selected fixed-effect target at a grid of values, reoptimise all remaining penalised nuisance parameters, and retain the profile trace, convergence diagnostics, and finite-bound check.

## Capacity ladder

| Order | Budget | Outcome | Trigger / definition of done |
| --- | ---: | --- | --- |
| Informal probe | 15 min | Map existing MSPL fences and ordinary binary profile machinery. | Decide whether a minimum viable profile can reuse an existing safe optimisation route. |
| Arc 0 | 75 min | One local logit q1 feasibility prototype or typed refusal. | Target, grid, nuisance reoptimisation, trace, and finite-bound diagnostic retained. |
| Rung 1 | 40 min | Link-symmetry design check. | Determine whether standard and mirrored complementary-log-log must be separate fixtures. |
| Rung 2 | 25 min | Focused regression test and fence audit. | Prototype stays opt-in/internal and all ordinary inference methods remain fail-closed. |
| Integrate/close | 15 min | Internal record and calibrated next estimate. | Commit an artefact or checkpoint with actual timings and a clear next decision. |
| **Total capacity** | **170 min** | | |

## Budget

| Segment | Minutes | Output / stop point |
| --- | ---: | --- |
| Orient | 25 | Existing profile routes, MSPL fences, and a candidate fixture identified. |
| Core | 90 | One nuisance-reoptimised prototype or a diagnosis showing why it is unsafe. |
| Verify | 25 | Finite trace/bounds, convergence checks, and focused regression check. |
| Repair reserve | 15 | Repair a local implementation error; otherwise retain the stop finding. |
| Closeout | 15 | Checkpoint, result, and timing calibration. |
| **Total** | **170** | |

**In scope:** ordinary complete-Bernoulli LA-MSPL, q = 1 initially; one fixed-effect target; local profile feasibility; the design requirement to keep logit, probit, and complementary-log-log logically distinct.

**Not in this arc:** coverage, standard-error calibration, nominal 95% claims, bootstrap, a broad simulation, spatial/phylogenetic/random-slope structures, rank selection, any public `confint()`/`profile()` enablement, or release work.

**Evidence used:** merged Lane B B2 partial report records 64,650 completed point-estimation replicates but no uncertainty evidence; the experimental MSPL contract deliberately refuses `vcov()`, profiles, and confidence intervals.

**Risk branch:** If holding a target and reoptimising nuisance parameters is not compatible with the current TMB/MSPL contract within the first 75 minutes, stop implementation, retain a typed feasibility diagnosis, and prepare the smallest separate profiling-design arc rather than approximating a Wald SE.

**Done when:** a retained local prototype produces finite, stable bounds for one selected target with its profile trace, or the exact technical blocker is demonstrated and recorded. Neither outcome changes the public inference fence.

**First action:** inspect the existing `profile*()` dispatch and the MSPL fail-closed methods, then select the smallest ordinary logit q1 fixture.

## Actuals (complete at close)

**Recommended / actual:** 170 / under 90 minutes of observed local work ·
**Requested / used:** N/A / local only · **Rungs/cohorts completed:** Arc 0,
link check, fence regression, and closeout.

**Under-run event:** the admitted q = 1 test fixture and Arc 0 internal seam
made the cross-link extension a deterministic test-harness change rather than a
new profiling implementation.

**Calibration:** the focused MSPL suite increased from 238 to 276 expectations
and remained below one minute; individual profile probes completed below the
30-minute local compute gate.

**Metric movement:** point-only -> private finite-feasibility matrix with one
typed blocker.

**Result:** 11 of 12 q = 1 cells had a matched centre and two finite crossed
sides. The base-probit third fixed-effect target had a finite, converged upper
trace but no crossing in the fixed six-step budget, so its terminal status is
`truncated`. No public inference surface changed.

**Next arc:** only if separately approved, diagnose the finite probit
non-crossing geometry without widening the grid or promoting a confidence
interval claim.

## Arc 2 continuation actuals

**Recommended / actual:** 90 / under 60 minutes of observed local work · **Mode:** size ·
**Metric movement:** 11/12 -> 12/12 finite-stable q = 1 fixture cells.

The separately approved continuation changed the fixed profile budget only for
the base-probit third resolved `b_fix` coordinate: `step = 0.5` and
`max_steps = 12L`. Every other matrix cell retained `max_steps = 6L`. The
first added upper point crossed the existing internal objective-delta threshold
(`2.620057 > 1.920729`) with convergence code zero and a finite objective.

**Result:** PASS. The focused MSPL suite had 307 expectations with zero
failures, warnings, or skips (38.4 seconds). A read-only scope review found no
P0/P1/P2 issue; a separate mechanical fence audit confirmed that `R/mspl.R`,
the unexported helper, and all public MSPL refusals were unchanged.

## Handoff condition

This is a multi-file, TMB-adjacent, inference-boundary task with a consequential approval gate. It requires an Ultra Plan before implementation. The plan must preserve the fail-closed public interface unless a later, separately evidenced promotion decision is made.

## Regime-matrix continuation actuals

**Recommended / actual:** 5.5--6 hours / approximately 3 hours of local
implementation, profile execution, and review receipt collection. **Mode:**
size. **Metric movement:** one selected 12-cell q = 1 link matrix -> one
predeclared 36-cell q = 1 regime map.

The continuation held the complete-Bernoulli, ordinary `latent(..., d = 1,
unique = FALSE)` fixture class fixed. It varied one DGP feature at a time:
baseline; all three fixed-effect intercepts shifted by -1.5 or +1.5; or the
q = 1 loading vector multiplied by 1.75. Each regime used logit, probit, and
standard cloglog generation/fitting and all three resolved `b_fix` coordinates.
Every profile used the active penalised `fit$tmb_obj`, `step = 0.5`,
`max_steps = 12L`, `level = 0.95`, and the fixed `100/100` optimisation budget.

**Result:** 32 of 36 cells are `matched/crossed/crossed` with finite traces and
zero convergence codes. Four standard-cloglog cells retain finite traces and a
matched centre but terminate at a lower-side `optimizer_failed` status:
baseline `b_fix[2]`; low-prevalence `b_fix[1]` and `b_fix[3]`; and strong-signal
`b_fix[2]`. These are typed finite-grid blockers, not a reason to widen a grid,
substitute a Wald interval, or claim calibrated uncertainty.

**Verification:** the focused `mspl-api` suite passed 617 expectations with no
failures, warnings, or skips in 161.6 seconds. Public MSPL inference remained
fail-closed; no export, profile/confint/vcov dispatch, user documentation, or
remote-compute surface changed.

## Private uncertainty-method admission actuals

**Recommended / actual:** a short local admission stage / under one hour of
local implementation and deterministic verification. **Mode:** method
admission, not calibration. The active TMB tape does not provide an analytic
Hessian for models with random effects, so this stage records that exact
limitation and uses `stats::optimHess()` only on the active penalised outer
objective as a private numerical-curvature candidate.

**Result:** the deterministic ordinary q = 1 logit fixture has a finite,
positive-definite numerical outer Hessian and finite nuisance-reoptimised
penalised-profile threshold brackets for `b_fix[1]`. Both candidates are
private diagnostics. They establish neither calibrated standard errors nor
confidence intervals. The penalty-off provenance tape is poisoned in the test
and cannot be called. Public MSPL `vcov()`, profile, `confint()`,
`profile_targets()`, and `tmbprofile_wrapper()` refusals remain unchanged.

## Private repeated-sampling pilot actuals

**Campaign:** four predeclared complete-Bernoulli q = 1 cells, 100 seeded data
sets per cell and all three fixed-effect coordinates (1,200 candidate records).
The active penalised objective supplied both candidates. The campaign retained
every fit/Hessian/profile outcome and used no substitution or adaptive grid.

**Result:** numerical-Hessian availability was 1.00 in the three baseline
cells and 0.98 for every low-prevalence cloglog target. Profile availability
was 0.93--1.00 in the baseline cells but only 0.73, 0.86, and 0.88 for the
three low-prevalence cloglog targets. Corresponding profile unconditional
coverage was 0.73, 0.85, and 0.85. This is a private typed-blocker result for
public profile intervals, not a confidence-interval claim. The 100-replicate
pilot is operational evidence, not a calibrated-coverage decision.

## Private numerical-Hessian calibration actuals

**Recommended / actual:** up to ten hours including a 500-replicate gate and
conditional 1,000-replicate confirmation / approximately 18 minutes, dominated
by the exact-source Totoro build. **Mode:** private candidate adjudication.
The runner was hardened before compute: it has a `hessian_only` route which
does not invoke profile code, atomic three-target receipts, retained fit errors,
an exact manifest-bijection check, and a disjoint confirmation seed stream.

The initial four-cell x 500-replicate campaign returned all 2,000 receipts.
Every target cleared the declared continuation gate (availability >= 0.98 and
unconditional diagnostic-band coverage >= 0.92), so a disjoint four-cell x
1,000-replicate confirmation ran to completion (4,000 receipts). The active
penalised package source was `3a905b4f`; the confirmation runner source was
`a0f26cb1`; manifest/summary SHA-256 receipts remain on Totoro.

**Verdict:** the numerical outer-Hessian route is operationally available in
these four fixtures (0.991--0.999 at confirmation) and its unconditional
diagnostic-band coverage is 0.950--0.979. It is nevertheless **blocked from
public SE or confidence-interval promotion**: the low-prevalence cloglog
fixture has mean-SE / empirical-SD ratios of 1.07--1.35, including 1.35 for
its first fixed effect. These are private diagnostic bands from the active
penalised objective, not calibrated standard errors or confidence intervals.
The profile candidate remains separately blocked; no public MSPL refusal changed.

## Private Godambe/sandwich feasibility actuals

**Mode:** mathematical/TMB admission, not a covariance implementation.
The active LA-MSPL criterion is TMB's Laplace marginal objective. Its C++
`joint_nll_penalized` report deliberately excludes the outer Laplace
log-determinant, while its Jeffreys and loading/covariance penalties depend on
global `N_eff` and the full `X_mspl` design. The fitted object provides only
the total outer gradient and exposes no validated per-site or per-row
active-objective score decomposition.

**Verdict:** `score_decomposition_unavailable`. A conventional
Godambe/sandwich covariance would need additive scores from exactly the active
penalised Laplace criterion. Neither the reported joint NLL nor a penalty-off
provenance tape meets that requirement. A delete-one-site refit would define a
new jackknife-type candidate and is outside this arc.

**Four-fixture contract:** logit, probit, standard cloglog, and
low-prevalence standard cloglog all return the same typed blocker after
verifying `fit$tmb_obj`, `estimator_id = 1`, and no reported per-unit score
field. No covariance, interval, simulation, remote compute, or public method
was activated.
