# Plan vs Actual: Family-Wide Mixed-Family Predictor-Informed LV

Date: 2026-08-25
Plan: `docs/dev-log/plans/2026-08-25-lv-mixed-family-all-native-ultra-plan.md`
Branch: `codex/lv-mixed-family-all-native`
Reviewer lens: Melissa
Status: **REVIEW REPAIRS IN PROGRESS — retained compute and status
reconciliation are complete; the first frozen review returned bounded FAIL
findings before landing**

## Summary

The implementation, all three retained campaigns, source contract, reader path,
documentation cascade, focused/full tests, article render, pkgdown, and local
package check are complete locally. The exact family-wide allow-list is live
without changing TMB likelihood code or widening arbitrary mixtures. The pure
r200 passed 17/19 cells and retained two honest HOLDs; all eight preregistered
mixed r500 archetypes passed target-wise Wald calibration. This report does not
declare landing complete until the frozen panel, reverify, validators, and
single local commit pass.

## Scope reconciliation

| Planned scope | Actual | Classification |
| --- | --- | --- |
| All 17 fit-admitted native family IDs independently adjudicated | IDs 0--16 and the three binomial links are source-pinned; 19/19 mixed/sentinel point cells pass; 17/19 pure cells pass and two retain HOLDs | aligned and complete |
| Named mixed cells, not arbitrary mixtures | Exact 18 mixed anchors plus one three-family sentinel are admitted and tested; arbitrary combinations still reject | aligned |
| Rank 1, `unique = FALSE`, complete response, native ML | Implemented exactly; rank/default-Psi/mask/REML/source-tier negatives pass | aligned |
| Rotation-invariant `B_lv` and shared `Sigma` | Harness and evidence use `B_lv = Lambda alpha^T` and `Lambda Lambda^T`; raw axes are forbidden targets | aligned |
| Reader-ready long and wide workflow | Gaussian + Poisson article route runs both forms; live equality test matches family order, labels, and estimates | adaptive, required reader repair |
| Preserve all deferred surfaces | No C++, Julia, GLLVM.jl, profile/bootstrap, source-tier, mask, rank>1, REML, or arbitrary-family widening | aligned |

## Evidence reconciliation

| Planned evidence | Actual evidence | Classification |
| --- | --- | --- |
| Source-pinned family contract | Complete 17-ID matrix, current hashes, model alignment, and exact route verdicts | aligned |
| Mixed/sentinel r200, 3,800 attempts | 3,800/3,800 retained; 3,800 converged; 3,789 strict point eligible; 11 gradient exclusions; 19/19 gates pass | aligned and complete |
| Pure r200, 3,800 attempts | 3,800/3,800 retained; 3,770 converged; 3,762 point eligible; 17 PASS, Beta HOLD, ordinal-probit HOLD | aligned and complete |
| Eight-archetype r500 Wald calibration | 4,000/4,000 retained; 4,000 converged/point eligible; 3,999 interval eligible; all eight target-wise calibration gates pass | aligned and complete |
| Failed-attempt and all-denominator policy | Development, TDD, overwrite, manifest, invocation, and interrupted-candidate failures preserved; collectors distinguish planned, started, interrupted, and final rows | aligned |

## Routing and team reconciliation

| Planned slice | Actual | Classification |
| --- | --- | --- |
| S1 Jason provenance | Source-pinned family/route matrix completed | aligned |
| S2 Gauss/Noether contract | Symbolic, R, TMB, extractor, and family nuisance alignment completed | aligned |
| S3 first proof cell | Gaussian + multi-trial binomial logit and negative controls pass | aligned |
| S4/S5 family waves | Exact allow-list and named cells tested; mixed r200 passes all cells | aligned |
| S6/S7 recovery | Harness, mixed/sentinel, and pure retained evidence complete with cell-specific verdicts | aligned and complete |
| S8 API/docs | Long/wide mixed-family repair, generated help, Design 01/02/03/05/35/57/61/73, and Tier-1 article completed | adaptive and aligned |
| S9 inference | All eight frozen mixed archetypes pass target-wise Wald calibration; simultaneous coverage remains unclaimed | aligned and complete |
| S10 verification | Focused/full tests, article, pkgdown, stale scans, and local check green | aligned |
| S11/S12 panel and closeout | Preparatory reviews pass; final frozen panel, reverify, validators, commit, and handover remain open | correctly deferred |

## Safety and compute reconciliation

- Mixed r200 was previously approved and retained with 3,800 attempts.
- Final pure canary: 26.96787 seconds; projected 1.45 CPU-hours and roughly
  5--15 minutes at 40 one-thread workers.
- Final calibration canary: 17.56942 seconds; projected 2.36 CPU-hours and
  roughly 10--20 minutes at 40 one-thread workers.
- Both launchers cap workers at 40, pin BLAS/OpenMP/MKL to one thread, enforce
  a 1,800-second process-group stop, and collect partial denominators.
- Totoro ran only the two explicitly approved production campaigns at 40
  one-thread workers each. No DRAC job, GitHub Actions science compute,
  duplicate campaign, or GLLVM.jl mutation occurred.
- Local package check completed inside estimate at 20m56.6s with 0 errors and
  0 warnings.

Safety classification: **aligned; approved remote execution completed within
the 40-worker and 30-minute envelopes**.

## Public-claim reconciliation

The public article teaches only a named Gaussian + Poisson mixed route. The
code remains point-oriented, while the boundary now states that this exact
archetype is among eight with target-wise Wald calibration. It distinguishes
Gaussian mean change from Poisson log-rate change, uses associational language,
carries no internal row IDs, and lists excluded surfaces plainly. Internal
umbrella rows remain `partial`, with the two pure HOLDs and calibration limits
explicit.

Public-claim classification: **aligned with currently earned evidence**.

## Deviations

### Adaptive

- The initially documented `traits()` claim was not executable for named mixed
  families. TDD produced a bounded pre-pivot selector repair plus long/wide
  equality and explicit-selector tests.
- The Rose sweep found stale universal-rejection wording in FG-18, RE-13, and
  canonical Design 01 after LV-05 had moved. Those surfaces were reconciled
  without changing umbrella status.
- The frozen mathematical review found three evidence-fence gaps not exercised
  by the retained formula: transformed/factor/multi-column LV designs,
  multiple binomial links within one fit, and extra covariance tiers. All were
  repaired fail-loud with test-first negative controls; the evidence-bearing
  route was not widened or rerun.
- The final mathematical sweep found two narrower variants: a matrix-valued
  numeric column could expand to multiple predictor columns, and the
  pre-existing pure-binomial C1 route sat outside the programme-only
  single-link fence. Both were repaired test-first. The already effective
  public-path family validator remains the single owner of within-trait
  family/link consistency.
- A full package check was added because exported reader behavior changed. It
  completed within the local gate.
- The managed sandbox initially denied 285/285 exact-socket probes. Explicitly
  approved escalated attachment later worked. Two zero-attempt remote failures
  were preserved: missing `artifacts/` for `nohup` redirection, then Linux
  compilation of macOS AppleDouble `._gllvmTMB.cpp`. A source-identical Linux
  extraction excluded only 4,636 `._*` metadata files and passed the frozen
  source manifest before either successful campaign.
- Lease persistence degraded because the registry lies outside the managed
  writable sandbox. Repeated live-census and exact-path checks substituted for
  the unavailable write, with no live overlap detected.

### Drift

- None accepted. No implementation or claim crossed a deferred boundary.

### Unclear

- None. The two pure HOLDs and eight mixed calibration PASS verdicts are direct
  retained results, not inferences from canaries.

## Acceptance-ledger reconciliation

G1--G10 are supported by current evidence, including independent verification
of all 15,614 pure/calibration raw-manifest entries. G11 and G12 remain open for
the final exact-candidate panel, after-task validation, handover, commit, clean
tree, and lease release. Final mode will be `--reverify`, never `--status`.

## Landing reconciliation

Not landed. No commit, push, PR, merge, release, external message, or public
announcement has been made for this mixed-LV branch. The branch remains ahead
1 and behind the current local `origin/main`; integration waits until the
source-pinned campaign receipts exist.
