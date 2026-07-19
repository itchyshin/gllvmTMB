# Gaussian REML 0.6 certificate — execution record

## Scope locked on this branch

The 0.6 claim is limited to the exact Gaussian restricted likelihood used by
`gllvmTMB(REML = TRUE)`. It is not a non-Gaussian REML or AGHQ claim. Candidate
latent rank remains an ML AIC/BIC decision; REML is a covariance-summary refit
after that choice.

The admitted engine contract is all-Gaussian, unweighted data, dropped rather
than retained responses, a full-rank observed fixed design with positive
residual degrees of freedom, and no `mi()`, `Xcoef_fixed`, or
predictor-informed `latent(..., lv = ~ x)` block. The latter is guarded because
`alpha_lv_B` is not yet included in the restricted fixed-effect block.

## Evidence ladder

1. Deterministic unit tests compare the TMB restricted likelihood with a dense
   Patterson--Thompson oracle for ordinary `indep()`, `dep()`, rank-1 and
   rank-2 `latent() + Psi`, including one perturbed outer-parameter point.
2. `dev/reml-paired-funnel.R` records ML and REML rows from exactly the same
   DGP draw and seed. Certificate candidates are `diag3` and `latent1_psi3`;
   the 100-replicate screen adds only the non-certificate small-​unit
   `latent1_psi3_stress` cell. Source, spatial, phylogenetic, slope, rank-2
   coverage, and near-boundary regimes are not 0.6 certificate cells. Production runs compute
   standard errors by default so each row carries `pd_hessian`, the maximum
   gradient, and the declared gradient tolerance; aggregation distinguishes
   mere paired completion from optimizer-health completion.
3. The staged ladder is local deterministic seeds, 25/50 Totoro pilot,
   100-replicate screen, then 500-replicate recovery. A fixture advances only
   when complete paired rows, convergence, boundary diagnostics, and recovery
   criteria are recorded.
4. A later, separately predeclared profile-interval campaign may certify at
   most two promoted targets. Its 15,000-replicate maximum, stopping rule,
   denominators, MCSE, raw-output recomputation, and D-43 review are not
   satisfied by the point-recovery funnel.

## Predeclared profile targets

The paired certificate has exactly two natural-scale total between-unit
variance targets, profiled internally with
`.profile_ci_total_variance(..., tier = "unit", trait_idx = ...)` rather than
the direct `sd_B` profile:

- `diag3`, `trait_2`: \(V_2 = \psi_{B,2} = 0.55\);
- `latent1_psi3`, `trait_1`: \(V_1 = \lambda_{B,1}^2 + \psi_{B,1} = 0.94\).

The profile runner records a row only for the predeclared profile target,
requires ordered finite endpoints that bracket its own point estimate and
match `extract_Sigma(..., part = "total")` to `1e-6`, and reports both
conditional (available profiles) and unconditional (all attempted fits)
denominators, MCSE, and an exact 95% lower confidence bound. The 0.94 rule is
evaluated only after the 15,000-replicate raw-shard recomputation.

## Measured gates (not a certificate)

On Totoro from source commit `6d25ee3c`, the 25-replicate point pilot, the
100-replicate point screen (including the stress fixture), and the
500-replicate point-recovery run all had convergence 0, PD Hessians, gradients
below 0.01, and no flagged diagonal boundary. At 500 repetitions and 50 units,
mean ML/REML variance-to-truth ratios were respectively 0.971/0.996 for
`diag3` trait 1 and 0.980/1.001 for `latent1_psi3` trait 1. This supports
promotion to a profile measurement; it is not interval coverage evidence.

The parallel 25-replicate, 150-unit profile pilot returned finite, ordered,
estimate-matching intervals on every predeclared target. Its conditional
coverage was 1.00 for the `diag3` target under both estimators and 0.92/0.96
for the latent target under ML/REML. With only 25 repetitions, its exact lower
bounds are far below 0.94; it is a route-health/timing receipt only, not a
certificate or a public REML-improvement claim.

The subsequent parallel 100-replicate profile screen is a **stop** under the
predeclared 0.01 maximum-gradient rule: all 400 predeclared profile intervals
were available and ordered, but optimizer-health counts were 98/100 for
latent-ML, 100/100 for latent-REML, 98/100 for diagonal-ML, and 98/100 for
diagonal-REML. The six exceptions had convergence 0 and PD Hessians but maximum
gradients 0.0101--0.0150. The rule is not relaxed after seeing these data. Both
certificate fixtures therefore stop before the profile 500/15,000 stages;
their profile coverage at 100 (ML/REML: latent 0.95/0.97, diagonal 0.96/0.94)
is descriptive only. The raw-shard audit must reproduce this WITHHELD status
before closeout.

Grace's independent recomputation found complete repetitions and no duplicate
keys, profile failures, boundary flags, nonzero convergence codes, or false PD
Hessians. It also found a provenance defect: the old raw rows name source SHA
`459e130f`, but the installed Totoro package recorded no matching SHA. Those
rows are therefore sufficient to support the negative stop but not an
evidence-certified rerun. The funnel now requires an explicit installed-package
SHA, records it beside the source SHA, and the raw audit rejects disagreement;
the official launcher requires an explicit clean `REMOTE_WORKDIR` rather than
a stale default path.

## Compute and claim fences

The Totoro launcher caps parallelism at 100 cores, requires its existing
ControlMaster socket, and uses a branch-installed package for every worker.
DRAC is only considered after the Totoro timing pilot. Outputs remain local and
are not GitHub Actions artifacts.

No public capability, NEWS, validation-row promotion, or release claim follows
from this branch without Fisher, Grace, and Noether D-43 admission. The 1.0
AGHQ/Cox--Reid spike remains a separate post-0.6 research arc.
