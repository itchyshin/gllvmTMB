# Discussion draft: evidence-led development principles

**Status:** discussion draft; not yet policy, a release criterion, or a
requirement for existing code.  It proposes a practical shared doctrine for
`drmTMB` and `gllvmTMB`.

## Purpose

The aim is not to make every hierarchical or latent-variable model
theoretically solved in complete generality.  It is to make the strongest
claim justified for an exact model, estimand, and operating regime—and no
stronger.

The central rule is:

> A converged fit is evidence that an algorithm returned a numerical result.
> It is not, by itself, evidence of identification, accurate estimation, or
> calibrated inference.

This doctrine would make mathematical derivation, recovery simulation,
independent comparison, stress testing, diagnostics, and public limitations
complementary rather than competing forms of evidence.

## Six proposed principles

### 1. State the model and the target before validating it

For a substantial new model, response family, approximation, or estimator,
write a compact specification before making a broad claim.  It should name:

- the likelihood or objective, parameterisation, links, and constraints;
- latent/random-effect distributions and any penalty or prior;
- the approximation or optimisation route (for example Laplace, AGHQ, VA, or
  EVA);
- the estimand being assessed: fixed effects, `Sigma`, `Psi`, correlations,
  ordination, likelihood values, standard errors, or intervals; and
- the intended asymptotic regime, if an asymptotic claim is made.

The word *large* is not enough.  A statement such as
`sqrt(n) (theta_hat - theta) -> N(0, V)` must specify whether the relevant
limit is more units, observations per unit, traits, groups, or some defined
combination.  These regimes are not interchangeable.

Where theory is unavailable, say so directly.  Absence of a general theorem
is a boundary to document, not a reason to imply one.

### 2. Separate mathematical facts, assumptions, and empirical evidence

Each public or internal capability claim should record its evidence as a
**set**, rather than assigning one supposedly superior grade:

| Code | Evidence | What it can support |
| --- | --- | --- |
| A | Mathematical result for this exact model | The stated result, with its assumptions |
| B | Result for a related model or stated limiting regime | A conditional, qualified extrapolation only |
| C | Simulation with known truth | Performance for the preregistered cells and targets |
| D | Independent implementation or oracle comparison | Agreement for the precisely matched objective/quantity |
| E | Design assumption or plausible extrapolation | A hypothesis for testing, not a capability claim |
| U | Unknown/not established | No affirmative inference claim |

These codes are not a ladder.  A model may have A + C + D evidence for point
estimates while its interval calibration remains U.  A Stan fixed-parameter
`log_prob` match, for example, is strong D evidence for a joint-density
implementation; it does **not** validate optimisation, Laplace error,
parameter recovery, standard errors, posterior sampling, or coverage.

### 3. Validate the estimand, not merely the fitted object

Simulation and comparator work should be preregistered around the quantity a
reader intends to report.  A successful optimisation code is insufficient.

For each cell, retain all attempts and report the denominators for numerical
health, stationary usable fits, and estimable targets.  Do not average away
failed cells.  Use rotation-invariant quantities (`Sigma`, correlations,
communality, prediction, or aligned ordination) for latent models unless a
loading orientation has been explicitly fixed.

Point recovery, standard-error accuracy, interval coverage, model selection,
and approximation fidelity are separate questions.  Evidence for one is not
an automatic certificate for another.

### 4. Stress the mechanism expected to fail

Routine simulation cells establish a baseline.  Deliberate stress cells find
the boundary: small samples, rare outcomes, missingness, weak information,
near-zero or near-boundary variance, high correlations, separation, low
latent rank, increasing latent/random-effect dimension, sparse groups, and
the difficult dimensions of an approximation.

The desired result is not “the method always works.”  It is a reproducible
answer to: **where does this model/estimator/claim stop working?**

A finite estimate caused by regularisation, a penalty, or a numerical clamp
does not by itself show that the data identify that parameter.

### 5. Select comparators deliberately and package by package

There is no universal external comparator.  A comparator is selected for a
specified claim only after aligning the likelihood, parameterisation, data
representation, constraints, and optimisation target.  When these do not
coincide, the result is a *related check*, not numerical equivalence.

Each substantial validation plan should use the strongest available mix of:

1. an **exact comparator** for the same objective;
2. a **reduction comparator** obtained by switching off structure until a
   simpler established model remains; and
3. an independently written **density or algebra oracle** when an external
   fitted-model comparator does not exist.

Provisional comparator map for discussion:

| Package and claim | Primary comparator | Reduction/oracle | Boundary |
| --- | --- | --- | --- |
| `drmTMB`: ordinary Gaussian/GLMM fixed and random effects | `lme4` or base `stats`, where the likelihood matches | Reduced GLM/LMM; direct objective/gradient comparison | Matching estimates do not establish profile/bootstrap coverage |
| `drmTMB`: location-scale and related GLMM structures | `glmmTMB` when parameterisation is reconciled | Fixed-scale or no-random-effect reductions | Check the exact variance/dispersion parameter definition |
| `drmTMB`: known-variance/covariance meta-analysis | `metafor` | Analytic GLS / simple intercept-only case | Do not generalise to untested covariance structures |
| `gllvmTMB`: Gaussian ordinary covariance modes | `glmmTMB` for matched `rr`/diagonal/unstructured structures | Gaussian likelihood and covariance algebra oracle | Compare `Sigma` and residual scales, not raw loading signs |
| `gllvmTMB`: Poisson/binomial ordinary latent models | `gllvm` for matched Laplace models | Aligned/rotation-invariant covariance and factor geometry | Agreement is cell-specific; it is not VA/EVA calibration evidence |
| `gllvmTMB`: NB2 ordinary latent models | `glmmTMB` after exact NB2 reconciliation | Direct likelihood, dispersion, and covariance comparison | Require matching dispersion convention and weights treatment |
| `gllvmTMB`: phylogenetic/spatial/other structured routes | No assumed universal package comparator | Structure-off reductions, independent sparse/dense algebra, fixed-coordinate density oracle | A density match does not certify optimiser or Laplace behaviour |

This table is a starting map, not a promise that every row is already
validated.  Comparator choice must be recorded per cell and estimand.

### 6. Make the failure domain visible to users and developers

Keep the three statements distinct:

```
computational success != statistical identification != validated inference
```

Where evidence finds a problematic regime, document it and detect it where
feasible.  Diagnostics should explain the actionable risk rather than offer
generic reassurance—for example, a near-boundary variance component, a
collapsed latent geometry, an unvalidated approximation dimension, or
insufficient outcome information.

The preferred status is an explicit “unknown/not validated for this claim”
instead of an unsupported positive statement.  Public wording should tell a
reader what can be reported, what uncertainty claim is not justified, and
what diagnostic or alternative route comes next.

## A feasible operating model

This need not turn every bug fix into a theorem project.  Apply the full
record only to a new likelihood, response family, covariance/latent structure,
approximation/estimator, or a widened public inference claim.  Routine bugs,
documentation repairs, and mechanical refactors retain ordinary tests and a
scope check.

For a substantial change, the smallest workable artefact could be a one-page
**validation card**:

1. exact route, target, and intended public wording;
2. A–U evidence set and links to theory/assumptions;
3. comparator(s), parameterisation map, and expected tolerance;
4. recovery and stress cells, all-attempt accounting, and preregistered
   pass/HOLD criteria;
5. known failure domain, diagnostic protection, and explicit non-claims.

The existing validation register can remain the package-wide index.  The
card supplies the missing local contract; campaign receipts, comparator
outputs, and reader-facing limitations pages then point back to that contract.

## Incremental adoption proposal

1. **Discuss and refine the doctrine first.** It is not yet binding and does
   not retroactively invalidate existing work.
2. **Pilot it on one new or currently active scientific route** in each
   package, measuring overhead and finding where the template is too heavy.
3. **Backfill only important public claims** at the next natural revision,
   using `U` or a narrow boundary where evidence is missing—not a forced
   simulation campaign for every historical feature.
4. **Promote only after the pilot works.** If adopted, add a concise
   developer checklist, a validation-card template, and a public-language
   rule.

## Questions for discussion

- What exactly counts as “substantial” in each package?
- Should A–U remain internal only, while reader-facing pages use plain-language
  statuses such as dependable core, experimental/partial, and not recommended
  for this claim?
- Which two active routes make the best pilots: one direct comparator case and
  one structured/no-universal-comparator case?
- What minimum all-attempt accounting and stress design is practical before
  the doctrine becomes counterproductive?
- Who owns the validation card at each stage: implementation author, simulation
  reviewer, and release reviewer?

## Non-action statement

This document does not alter defaults, APIs, package claims, release status,
or the active B2 campaign.  Adoption requires an explicit later decision.
