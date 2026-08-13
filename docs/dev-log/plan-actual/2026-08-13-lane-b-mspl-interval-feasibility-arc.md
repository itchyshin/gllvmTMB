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

**Recommended / actual:** 170 / pending minutes · **Requested / used:** N/A / pending minutes · **Rungs/cohorts completed:** pending  
**Under-run event:** pending  
**Calibration:** pending  
**Metric movement:** point-only -> pending  
**Result:** pending · **Next arc:** pending

## Handoff condition

This is a multi-file, TMB-adjacent, inference-boundary task with a consequential approval gate. It requires an Ultra Plan before implementation. The plan must preserve the fail-closed public interface unless a later, separately evidenced promotion decision is made.
