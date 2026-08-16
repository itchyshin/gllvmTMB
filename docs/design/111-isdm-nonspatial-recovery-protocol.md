# Frozen nonspatial iSDM recovery protocol

## Status and boundary

**Developer-only; frozen protocol; no execution is authorized by this file.**
This is a package-focused known-data-generating-process (DGP) recovery design
for the nonspatial integrated species-distribution-model (iSDM) route.  It is
not an empirical analysis plan, a spatial-model specification, or a
user-facing capability claim.

The pre-existing **G2 HOLD remains in force**.  This protocol neither changes
the G2 decision nor authorizes a rerun, replacement, editing, or selective
re-reading of the private G2 evidence.  A later recovery campaign can begin
only after the owner records a separate release from that HOLD and freezes its
implementation commit, fixtures, truth manifest, and acceptance thresholds.

## Separate branches, not pooled evidence

Recovery must be planned, run, summarized, and adjudicated separately for:

1. **PA branch:** presence--absence observations, with its stated occurrence
   and observation process.
2. **Count branch:** count observations, with its stated count distribution,
   link, and any dispersion or observation-process parameters.

The two branches may share a fixture generator only where their DGP components
are literally identical.  They must retain different fixture identifiers,
truth rows, attempt ledgers, denominators, and verdicts.  A pass in either
branch is not evidence for the other, and convergence of a pooled fit is not a
substitute for branch-specific recovery.

## Frozen truth and estimands

Before any fit, write a versioned machine-readable truth manifest for every
fixture.  Each row must identify the branch, seed, fixture, implementation
commit, and the exact target scale.  The manifest and recovery summaries must
cover, where present in that branch:

| Target class | Required recovery target |
| --- | --- |
| Slopes | Each ecological and implemented GBIF-bias slope on its declared link scale; the current PA route has known support only, not fitted PA-observation covariates. Do not replace individual slopes with an omnibus fit metric. |
| Relative maps | The latent/expected occurrence or intensity map after the predeclared within-fixture scale and location normalization.  Compare its shape (for example correlation and normalized error), not an unidentified absolute level. |
| Trait covariance | `Sigma` on the declared trait scale, including diagonal and off-diagonal entries or a predeclared invariant comparison when the parameterization does not identify entries directly. |
| Residual trait variation | `Psi` (or its per-trait `psi` entries) separately from `Sigma`; do not credit recovery of one to the other. |
| GBIF bias | Every simulated nonspatial GBIF sampling-bias coefficient, on the generating scale, separately from ecological slopes and relative maps. Spatial bias fields belong only to the later separately approved two-field gate. |

If latent factors are used, the manifest must also state the sign, ordering, or
rotation-invariant map used for comparison before fitting.  Post-hoc relabeling
to make estimates look recovered is prohibited.  A target not identified by
the DGP or fit must be labelled `not_estimable`, not omitted from the summary.

## Fixture ladder and adversarial cases

Each branch requires ordinary fixtures plus explicitly labelled attacks.  The
minimum attack set is:

- **Disconnected-support attack:** PA/count and GBIF records occupy disconnected
  covariate or unit-support components.  Report whether the implementation
  rejects, warns, or fits; a numerically converged fit is not automatically a
  recovery success.
- **Weak-overlap attack:** overlap between PA/count and GBIF covariate support
  is deliberately weak but nonzero.  Report target-specific degradation,
  especially separation of ecological slopes/relative maps from GBIF bias.
- Any boundary, low-information, or near-zero covariance fixture justified by
  the implemented parameterization must be retained with its declared role.

The protocol must state the expected outcome of every attack in advance:
recovery, diagnostic warning/rejection, or retained failure.  An attack that
was not generated, fitted, or adjudicated remains missing evidence rather than
a pass by implication.

## Fitting and failure ledger

Use a predeclared multistart schedule for every fixture: deterministic starts,
the number and construction of dispersed starts, optimizer controls, maximum
iterations, and a deterministic seed policy.  Use the same schedule for all
replicates within a branch unless a documented, pre-fit numerical exception is
approved.

Retain **every attempted fit**, including invalid starts, non-convergence,
non-finite objective/gradient, non-positive-definite covariance, failed
post-fit extraction, and fits that converge but miss a recovery target.  The
attempt ledger must preserve start identifier, seed, exit classification,
warnings, objective value where available, and the reason an attempt did not
enter a target summary.  Never select only the best converged start or delete
failed replicates.  Report both all-attempt and eligible-fit denominators.

## Recovery gates

A branch can be labelled `point_fit_recovery` only if its frozen campaign
shows, on the declared ordinary fixtures:

1. correct branch-specific data encoding and fixture-to-truth binding;
2. target-specific slope recovery on the declared link scale;
3. normalized relative-map recovery using the predeclared alignment;
4. separate recovery assessments for `Sigma` and `Psi`/`psi` where they are
   estimable;
5. GBIF-bias recovery that is not confounded in the summary with ecological
   slopes or maps;
6. the predeclared multistart and retained-failure ledger; and
7. explicit verdicts for the disconnected-support and weak-overlap attacks.

Thresholds, aggregation rules, allowable failure rates, and the rule for
disagreement among starts must be frozen before execution.  Convergence,
`pdHess`, a finite objective, or qualitative-looking maps alone do not satisfy
any recovery gate.  A failure of one required target or attack prevents branch
promotion; record the narrow failed target and keep the other results without
upgrading the branch.

## Claim fence

This protocol earns no empirical result, no spatial result, no interval or
coverage evidence, and no public/package capability statement.  It does not
support claims about real GBIF records, field sampling, spatial transfer,
prediction quality, or scientific distributions.  Any later public statement
requires separately reviewed implementation evidence, recovery evidence at its
claimed scope, and the package documentation/validation-debt gates.
