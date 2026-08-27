# Ultra Plan — Cross-family LV correlation + predictor bridge

Date: 2026-08-27  
Platform: Codex  
Branch: `codex/cross-family-lv-predictor-bridge`  
Initial base: `a7b75f75dac2b5c23525afdfec26abbaf59aab16` (verified post-PR #1217 main)  
Required integration base: the eventual verified main SHA after PR #1216 and the ordered random-slope release merge.

## Goal

Preserve the existing cross-family latent-correlation capability and connect it
to predictor-informed ordinary latent scores. A supported joint fit must return
both the existing rotation-invariant shared covariance/correlation

\[
\Sigma_{shared}=\Lambda\Lambda^\top,
\qquad R_{shared}=\operatorname{cov2cor}(\Sigma_{shared}),
\]

and the predictor-induced trait effect

\[
u_i=M_i\alpha+e_i,\quad e_i\sim N(0,I_d),\qquad
B_{lv}=\Lambda\alpha^\top.
\]

Observed responses retain their registered family, link, support, and nuisance
parameters. Raw `alpha`, raw `Lambda`, and signed scores are not cross-fit
targets.

## Prior-work receipt and correction

- The public cross-family article already fits Gaussian, binomial, Poisson,
  ordinal-probit, and multinomial traits on a rank-3 ordinary latent block and
  recovers signed correlations from `extract_Sigma(..., part = "shared",
  link_residual = "none")`. This implementation is reused unchanged.
- PR #1217 landed the predictor-informed family-wide programme at main
  `a7b75f75...`: 19/19 named mixed/sentinel point cells passed across 3,800
  retained attempts; eight named Gaussian-anchor cells passed target-wise
  `B_lv` Wald calibration across 4,000 attempts. Those attempts are not rerun.
- The landed programme deliberately gates family-wide predictor-informed fits
  to rank 1, `unique = FALSE`, one exact binomial link per fit, and named
  family combinations. Pure Beta and ordinal-probit retain honest HOLDs.
- The TMB template already represents `alpha_lv_B` as `n_lv_B x d_B`, forms
  `U_B_total` for every axis, and reports `B_lv_unit`; rank 2/3 is therefore an
  R admission/evidence gap unless failing tests expose an engine defect.
- Gaussian and lognormal currently share one scalar `sigma_eps`. A joint route
  cannot be advertised as general until that equality is either made explicit
  as a constrained model or replaced by separately identified scales. This is
  a likelihood change and requires its own TMB review and tests; it is not
  hidden inside a guard relaxation.
- Ask-Brain (`search_all_projects=true`) retrieved `[[02-family-registry]]`,
  `[[03-likelihoods]]`, and `[[05-testing-strategy]]`: they confirm that
  cross-family dependence is already a package headline and that new work must
  be family/mechanism evidenced, not inferred from one article fit.

Verdict: **reuse the correlation implementation; build only the predictor
bridge and the exact family-composition gaps.**

## Locked first milestone

The first implementation milestone is deliberately smaller than the eventual
all-route evidence campaign but is not a substitute for it:

1. Admit an already-supported five-family correlation fixture with one numeric
   `lv` predictor at ranks 2 and 3, first with `unique = FALSE`.
2. Prove the fitted object returns finite, correctly labelled
   `Sigma_shared`, `R_shared`, and `B_lv`, and preserves
   `total = mean + innovation`.
3. Replace family-ID-set admission with logical response descriptors only where
   existing family routing is compositional. Retain all unsupported geometry
   fences.
4. Test `unique = TRUE` separately. Promote it only if identified partner Psi
   components and the mapped-off nominal component behave as the existing
   correlation route specifies.
5. Keep Gaussian + lognormal jointly gated until separate-scale likelihood
   work passes TMB review and planted-scale recovery.

This milestone does not add a new correlation extractor. The existing
`extract_Sigma()` and `extract_correlations()` contracts remain authoritative.

## Execution slices

| Slice | Owner | Output | Dependency |
|---|---|---|---|
| G0 coordination | Ada | branch/base/lease receipt and Unlazy ledger | current main |
| S1 engine audit | Gauss + Emmy | guard-only versus TMB-gap map | G0 |
| S2 estimand/evidence audit | Noether + Fisher | smallest honest recovery/calibration grid | G0 |
| S3 TDD bridge | Ada/Gauss | failing then passing rank-2/3 joint-fit tests | S1 |
| S4 scale repair | Gauss | separate Gaussian/lognormal scale path if required | S3 |
| S5 evidence canaries | Curie + Grace | measured pre-run receipt | S3/S4 |
| S6 retained evidence | Curie + Fisher | all-attempt artifacts and verdicts | explicit >30 min approval |
| S7 reader/status cascade | Boole + Pat + Rose | existing article updated at earned scope | retained evidence |
| S8 closeout | Rose + Grace + Melissa | reverify, after-task, plan/actual, handover | frozen candidate |

The final D-43 panel is two Terra-high reviews plus one Sol-xhigh review of the
same frozen candidate SHA.

## Evidence ladder

Before any fit, record a wall-time estimate and a correctness smoke. Local work
projected at no more than 30 minutes may run; longer or Totoro work stops after
the measured receipt for explicit approval.

The old 3,800/4,000-attempt campaigns are immutable inputs. New claim-bearing
work is limited to:

- a rank-2 and rank-3 five-family joint recovery cell;
- one all-admitted-route stress cell after every incompatibility is resolved;
- pure Beta and ordinal-probit repair/confirmation without changing old
  verdicts or denominators;
- mechanism-stratified correlation and `B_lv` calibration only where public
  interval wording is proposed.

Every campaign retains planned, started, failed, point-eligible,
interval-eligible, non-PD, and CI-unavailable denominators, plus target-specific
MCSE and artifact hashes. GitHub Actions is never used for science compute.

## Stop conditions

- Do not edit PR #1216 or random-slope-owned paths before their explicit merge
  and lease-release receipts.
- Do not claim arbitrary family combinations from a guard-only change.
- Do not admit Gaussian + lognormal with an unexplained shared residual scale.
- Do not weaken the Beta or ordinal gates, discard failures, or change retained
  seeds after seeing results.
- Stop after a measured pre-run receipt for any projection above 30 minutes.
- Never exceed 150 one-thread Totoro workers and never mutate GLLVM.jl.

## Completion

Completion requires Unlazy `--reverify`, focused and full package verification,
evaluated article render, pkgdown check, independent scientific and
reproducibility review, after-task validation, Melissa plan-vs-actual,
handover, protected PR/three-OS CI, normal merge, exact-main verification, and
lease release. Until then the active goal remains open.
