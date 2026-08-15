# After Task and Programme: LA-MSPL as a Parallel Laplace Estimator

```text
🎯 GOAL
Solo platform: Codex
Deliverable: one committed, reviewable LA-MSPL estimator programme document
HEADLINE: separate Laplace integration from the outer criterion and build a boundary-by-family research programme
IN PARALLEL: brain and primary-paper review, current-code audit, skeptical prior-art synthesis, architecture review, validation design, and claim-boundary review
DEFER: package code, API/default changes, simulations, version/release claims, and the active MSPL uncertainty lane
DISCIPLINE: verify=primary papers + origin/main + qualified branch evidence · compute=n/a · closure=Shinichi approves one bounded Phase 1A implementation slice
```

## 1. Outcome and recommendation

**Programme decision:** treat Laplace-approximated maximum softly penalized likelihood (LA-MSPL) as a serious, potentially major estimator programme parallel to Laplace-approximated maximum likelihood (LA-ML). Both use the same Laplace integration engine. They differ in the outer objective optimized over model parameters.

This is a research-programme decision, not a claim that LA-MSPL is already a general solution for GLLVM boundary problems. LA-ML remains the package default and scientific reference. The current binary LA-MSPL route remains an experimental, explicitly requested point estimator within its existing fences. No automatic fallback, public recommendation, general-family claim, interval claim, model-comparison claim, or release promotion is admitted by this document.

The central engineering recommendation is **not** to add one universal “MSPL mode.” Build a registry in which each admitted route is a separately proved and validated combination of:

1. a response family and link;
2. a precisely named boundary mechanism;
3. a covariance structure and parameterization;
4. a penalty atom and asymptotic scale;
5. a retained evidence status.

The first bounded implementation slice should be a no-numerical-change separation of integration, criterion, numerical kernel, and penalty provenance. The first genuinely new scientific route should then be the Gaussian factor/Heywood boundary, because it has the closest primary-theory match. Poisson and negative-binomial routes follow after that matched Gaussian test; they do not inherit its proof.

## 2. Status, audience, and non-claim

This is an internal programme constitution for maintainers, statistical reviewers, TMB engineers, and simulation reviewers. It consolidates current source, retained evidence, two supplied primary papers, Ask Brain retrieval, a skeptical Notebook research pass, and independent specialist reviews.

It does **not**:

- modify R, TMB, tests, public documentation, defaults, or release state;
- claim that softly penalized estimation repairs Laplace-approximation error;
- claim that all boundary estimates are caused by separation;
- claim that an interior estimate is identifiable, accurate, predictive, or inferentially calibrated;
- transfer evidence among Bernoulli, Gaussian, count, ordinal, multinomial, or structured-source models;
- authorize compute; or
- authorize merging the active MSPL interval-feasibility branch.

## 3. Immutable orientation receipt

The programme was audited in an isolated worktree from `origin/main` commit `882a6acb77c0a01471a0e8546023594b82e04e2b`, on branch `codex/mspl-estimator-programme-roadmap`. The normal checkout contained foreign work and was not used for edits. The exact target file was absent from all refs and had no recent collision. Other Codex lanes, including `codex/lane-b-mspl-interval-feasibility`, were treated as read-only evidence sources.

Open pull requests were re-read live. PR #955 contains useful cross-repository `drmTMB` non-logit findings, but it is unmerged and is evidence to consider rather than a controlling `gllvmTMB` contract. No design number was allocated because duplicate design slots remain across active refs.

Ask Brain was queried across all projects for MSPL, separation, factor-analysis boundaries, and prior estimator decisions. It pointed to the engineering notebook's existing MSPL bridge and the Kosmidis–Firth line of work. The two user-supplied primary PDFs were then read directly, so primary text—not the older brain synopsis—controls the literature statements below.

The grounded Notebook review used notebook `10f82316-704f-465e-8a8e-ff67352efd95`, with both supplied papers uploaded as trusted sources. Auto-imported sources were used only after relevance checks; duplicate records and an irrelevant abstract book were excluded from the synthesis. Notebook output remains literature triage until a statement is checked against the paper itself.

## 4. The key conceptual separation

Let \(y\) be the observed responses, \(u\) the integrated latent/random variables, and \(\theta\) the outer parameters. The exact marginal log likelihood is

\[
\ell_{\mathrm{marg}}(\theta)
=
\log \int \exp\{\ell_c(y,u;\theta)\}\,du.
\]

Let \(\widehat u_\theta\) be the conditional mode and
\(H_u(\widehat u_\theta;\theta)=-\partial^2\ell_c/\partial u\partial u^\top\)
the negative conditional Hessian. The shared engine uses the Laplace approximation

\[
\ell_{\mathrm{LA}}(\theta)
=
\ell_c(y,\widehat u_\theta;\theta)
+\frac{d_u}{2}\log(2\pi)
-\frac{1}{2}\log\det H_u(\widehat u_\theta;\theta)
\approx
\ell_{\mathrm{marg}}(\theta).
\]

LA-ML and LA-MSPL then optimize different outer criteria:

\[
\widehat\theta_{\mathrm{LA\text{-}ML}}
=
\arg\max_\theta \ell_{\mathrm{LA}}(\theta),
\]

\[
\widehat\theta_{\mathrm{LA\text{-}MSPL}}
=
\arg\max_\theta
\left\{\ell_{\mathrm{LA}}(\theta)+P_n(\theta)\right\}.
\]

Thus:

- **Laplace** is the integration approximation;
- **ML or MSPL** is the outer estimation criterion;
- an MSPL penalty on outer parameters does not change the conditional random-effect mode or random-effect Hessian at a fixed \(\theta\); and
- LA-MSPL can become a major alternative estimator without replacing the Laplace engine or making LA-ML obsolete.

This distinction also exposes a current API problem: an explicit `estimator = "ml"` can coexist with a non-Laplace integration route even though its documentation describes Laplace ML. Phase 1A will record the currently resolved integration, criterion, numerical kernel, and objective provenance without changing accepted calls. Phase 1B must later choose and separately approve a user-visible compatibility policy; only that slice may reject, deprecate, or reinterpret an existing combination.

| Integration route | Admissible outer criterion | Required interpretation |
|---|---|---|
| Laplace | ML or admitted MSPL cell | LA-ML or LA-MSPL |
| VA/EVA | its variational objective | Explicit `estimator = "ml"` must not pretend this is LA-ML |
| AGHQ | separately named approximate-likelihood route | No inheritance from the LA-MSPL programme |
| Gaussian REML | separately resolved legacy criterion | No implicit ML/MSPL label |

## 5. Current implemented estimator

The controlling current design is [Design 88](../../design/88-binary-mspl-estimator.md). The public API and release boundary are summarized in [NEWS](../../../NEWS.md), and the evidence statuses are recorded in the [validation-debt register](../../design/35-validation-debt-register.md).

For the currently admitted binary route, the implemented criterion is

\[
Q_{\mathrm{LA}}(\theta)
=
\ell_{\mathrm{LA}}(\theta)
+c_n\frac{1}{2}\log\det\{X_*^\top W_g(\beta)X_*\}
-c_nV_\Lambda(\Lambda)
-c_nV_{\mathrm{cov}}(\phi),
\]

with

\[
c_n=2\sqrt{p_{\mathrm{free}}/N_{\mathrm{eff}}}.
\]

Here `X_*` is the free mapped fixed-effect design after ties and pins, \(W_g\) is link-specific expected information, \(V_\Lambda\) is a rotation-invariant loading-row penalty, and \(V_{\mathrm{cov}}\) contains admitted covariance-coordinate penalties. C++ minimizes the sign-reversed form. Static review found the symbolic, R, and TMB signs and scaling internally aligned.

| Component | Current implementation | Evidence status | Generalization warning |
|---|---|---|---|
| Fixed effects | Jeffreys-type half log determinant on mapped `X_*` | Implemented for fenced Bernoulli links | Link- and design-specific; not generic Firth regression |
| Loading rows | Rotation-invariant radial pseudo-Huber atom | Implemented on the current admitted surface | A novel GLLVM extension, not proved by either supplied paper |
| Spatial coordinates | Dimensionless radial/log-scale atoms | Experimental structure-specific route | No transfer to animal, phylogenetic, or kernel coordinates |
| Scaling | `2 * sqrt(p_free / N_eff)` | Internally aligned | Need not vanish when dimension grows with information |
| Penalty-off evaluation | Stable-kernel objective at the MSPL point | Fit provenance only | It is not a maximized ML likelihood |

The composite estimator must not be called an ordinary MAP estimator or simply “Firth.” Only one atom is Jeffreys-based; other atoms and their data-dependent soft scaling have different interpretations.

## 6. What current evidence earns

The retained binary B2 campaign is substantial but incomplete: 2,586 of 2,880 shards and 64,650 of 72,000 replicates completed. Missingness is concentrated in hard, high-dimensional, mixed-extreme-prevalence cells, including five cells with zero completion. On the paired usable subset, every reported link-by-rank stratum favored MSPL over ML for conditional log loss and fixed-effect mean-squared error, and MSPL had materially higher usable-fit rates. That is strong positive evidence for continued research, not a failure-inclusive global verdict. See the [B2 partial-evidence report](2026-08-12-lane-b-b2-partial-evidence.md).

The active interval-feasibility branch is provisional evidence only. Its deterministic feasibility work constructed all 36 requested penalized-profile crossings and retained 12,000 bootstrap refits for 36,000 target rows. Penalty-off Hessian Wald construction was available for 21 of 36 targets and blocked by non-positive-definite curvature for 15. No schema-v2 repeated-sampling coverage verdict is complete. Penalized profiles, penalty-off curvature, and estimator-refit bootstrap are distinct inferential constructions and must never be reported as interchangeable.

Current earned claim:

> Within its exact experimental binary and structure fences, LA-MSPL is an implemented opt-in point estimator with encouraging but incomplete comparative evidence. It is not yet a general recommendation, an automatic fallback, an inference-ready estimator, or a model-selection criterion.

## 7. What the primary papers support

### 7.1 Mixed-effects logistic MSPL

The 2023 mixed-effects logistic paper, [DOI 10.1007/s11222-023-10217-3](https://doi.org/10.1007/s11222-023-10217-3), combines a fixed-effect Jeffreys penalty with negative Huber penalties on covariance coordinates. It establishes interior fixed and covariance estimates for its stated mixed-logistic model and studies Laplace-approximated fitting.

It directly supports:

- the idea of a softly scaled, vanishing penalty preserving a likelihood-centered estimand;
- separate boundary treatments for fixed and covariance parameters;
- explicit coercivity/interiority arguments; and
- the need to account for approximation-score error when using an approximate likelihood.

It does not directly establish:

- reduced-rank GLLVM loading penalties;
- probit or cloglog theory;
- free \(\Psi\) in a latent decomposition;
- spatial, phylogenetic, animal, or kernel tiers;
- high-dimensional trait/rank asymptotics; or
- calibrated GLLVM inference.

Its exact-likelihood finiteness result and its bounded non-adaptive approximation argument do not automatically cover Laplace or adaptive quadrature. For those routes the paper gives an additional approximation-gradient condition and reports numerical investigation rather than a general Laplace theorem. This distinction is load-bearing for `gllvmTMB`: sharing a Laplace engine is an implementation fact, not proof that the exact-likelihood MSPL theory transfers.

Cross-repository `drmTMB` findings sharpen these cautions: Jeffreys information must be verified link by link; cloglog's two tails are not symmetric; event counts can be more informative than prevalence; optimizer completion and finite output must be separate denominators; and a converged penalized fit can still lack usable standard errors.

### 7.2 Gaussian factor-analysis MSPL

The 2026 paper, [*Maximum softly penalized likelihood in factor analysis*](https://doi.org/10.1017/psy.2026.10092), studies the matched Gaussian factor model

\[
\Sigma=\Lambda\Lambda^\top+\Psi
\]

with Akaike/Hirose-type penalties involving \(\Psi^{-1/2}\Lambda\Lambda^\top\Psi^{-1/2}\) or \(\Psi^{-1/2}S\Psi^{-1/2}\). Its main contribution for this programme is a proof template: continuity, boundedness above, divergence of the penalized criterion on the targeted \(\Psi\to0\) boundary, identifiability conditions, and a vanishing penalty rate.

It directly supports making a precisely matched Gaussian Heywood route the first new-family test. It does not prove the current binary GLLVM estimator, logistic factor analysis, arbitrary latent tiers, or growing-dimension asymptotics. The paper explicitly leaves logistic factor analysis as future work.

### 7.3 Skeptical counter-literature

The grounded literature pass included work on weakly informative penalties for variance components, bias-reduced structural-equation estimation, and critiques of treating Jeffreys/Firth penalization as a universally preferred scientific prior. Together they reinforce five design constraints:

1. “Boundary” can mean weak information, parameterization dependence, model misspecification, or a genuine scientific near-zero—not one universal defect.
2. A penalty can improve numerical existence while changing bias, uncertainty, or scientific interpretation.
3. Invariance under reparameterization is not automatic for coordinatewise penalties.
4. Frequentist bias reduction and Bayesian prior justification are different claims.
5. A method should be judged on risk, prediction, calibration, sensitivity, and usability—not merely finite estimates.

Specific counterpoints are Chung et al.'s demonstration that forcing an interior variance estimate creates upward bias when the true variance is zero and that posterior modes can depend on parameterization; Jamil et al.'s implicit/explicit reduced-bias M-estimation as a distinct Gaussian-SEM objective that can improve bias and coverage without guaranteeing interiority; and Greenland and Mansournia's warning that Firth/Jeffreys penalization prevents separation but does not automatically minimize scientific loss and can produce opaque design-dependent shrinkage. These are not direct GLLVM comparators yet, but they rule out “interior therefore preferable” as a programme premise.

The verified corpus contained no theorem, implementation, or empirical validation for Poisson, negative-binomial, ordinal, or multinomial GLLVM MSPL under Laplace integration. Absence in this bounded search is not proof that none exists, but it means every such route begins as a new methods derivation rather than a routine software extension.

## 8. Hao's skepticism as a falsification charter

Hao's skepticism is methodologically useful. This programme will treat LA-MSPL as a hypothesis to try to falsify, not a feature to defend.

| Skeptical question | Mandatory falsification test | Stop condition |
|---|---|---|
| Is the pathology really the claimed boundary? | Label the boundary from truth and observables; include weak-information and misspecification controls | Retire the causal story if the label does not predict the ML pathology |
| Is the finite estimate scientifically better? | Compare recovery, covariance estimands, held-out log score, and calibration | No promotion if finiteness is the only improvement |
| Does the penalty harm healthy fits? | Paired ML/MSPL healthy-regime noninferiority | No recommendation if ordinary-regime risk is materially worse |
| Is the result penalty-determined? | Prespecified atom and scale sensitivity | Label as penalty-determined or reject if conclusions change materially |
| Is it invariant? | Trait order, contrasts, signs/rotations, response scale, and source-coordinate checks | Stop on unexplained representation dependence |
| Is apparent stability optimizer-specific? | Multistart agreement, gradients, Hessian state, and retained failures | Stop on start-sensitive or nonstationary “successes” |
| Does Laplace error dominate? | Matched low-dimensional comparator or higher-accuracy integration where feasible | Do not attribute an integration error to ML or claim MSPL repairs it |
| Is the method usable? | Runtime, certification, interpretable failure messages, and workflow burden | Do not admit a route that is impractical for its intended users |

Overcoverage is a calibration failure, not a conservative success. A non-positive-definite Hessian remains a retained failure. Empty, nonfinite, timed-out, and nonconverged attempts remain in every denominator.

## 9. Modular architecture

### 9.1 Family/link information registry

Each homogeneous family/link cell must declare:

```text
family_id and link_id
stable log-likelihood atom
expected-information atom
effective-information rule
admissible weights, offsets, trials, response masks, and missingness
fixed-effect boundary theorem status
numerical tail policy
```

Mixed-family composition is deferred until every connected free fixed-effect direction is covered by compatible, proved information atoms.

### 9.2 Boundary registry

Each penalty targets one named limit:

```text
boundary_id
outer parameter block
unconstrained coordinate construction
penalty atom and scale
targeted limit: zero, infinity, singularity, correlation ±1, or cutpoint collision
invariance contract
proof status and counterexample tests
```

Initial boundary classes are fixed-predictor divergence; loading-row divergence; covariance log-scale divergence; covariance singularity/correlation limits; \(\Psi\to0\) and \(\Psi\to\infty\); family dispersion/shape limits; ordinal cutpoint collision/infinity; and mixture/hurdle probability limits.

### 9.3 Route and evidence registry

The unit of admission is

```text
family/link × boundary × covariance structure × parameterization
```

Each cell records expected outer and random blocks, atom composition, scale rule, eligibility predicate, tests, and independent statuses:

```text
theory candidate
implemented
interiority passed
recovery passed
prediction passed
calibration passed
scientifically useful
```

A route can be blocked or rejected at any stage. “Interiority passed” never implies a later status.

### 9.4 TMB and fitted-object separation

The current overloaded `estimator_id` should eventually be represented by orthogonal, data-constant controls while retaining a compatibility adapter:

```text
criterion_id       = LA-ML or LA-MSPL
numeric_kernel_id  = legacy or audited stable kernel
penalty_eval_id    = off, on, or provenance evaluation
family_atom_id[]   = row-level information atoms
boundary_plan[]    = admitted boundary atoms
atom_scale[]       = separately derived soft scales
```

The fitted object should retain resolved integration, outer criterion, numerical kernel, penalty plan, atom values, and penalty-off provenance. This is an internal architecture proposal, not approval for a public API change.

## 10. Symbolic-to-implementation contract

Every new route must supply the following table before TMB code is changed.

| Layer | Required content | Gate |
|---|---|---|
| Scientific model | Response distribution, link, latent structure, target covariance, and boundary | Exact estimand and DGP named |
| Symbolic criterion | \(\ell_c\), Laplace marginal criterion, every penalty atom, signs, and scale | Independent derivation review |
| R assembly | Formula grammar, maps/ties/pins, free design, parameter count, eligibility | Named-block tests; no vector-position mapping |
| TMB implementation | Parameter transforms, stable likelihood, information, random set, reports | Value/gradient/Hessian oracle |
| User interpretation | What changes relative to LA-ML and what does not | Plain-language boundary and non-claim |

Pure-math tests include likelihood and information atoms; coordinate transforms; QR/Cauchy–Binet determinant checks; mapped `X_*`; penalty-on/off decomposition; random-mode parity at fixed outer parameters; and rank-deficient, nonfinite, and direct-TMB bypass rejection.

Invariance tests include invertible fixed-effect contrasts, row and trait permutations, factor sign/column/rotation where appropriate, packing round trips, Gaussian response rescaling, and structure-specific coordinate units.

## 11. Phased programme

### Phase 0 — Programme constitution and current-state lock

**Purpose:** freeze terminology, evidence boundaries, and falsifiers.

**Output:** this document; no code or compute.

**Exit gate:** Gauss confirms the objective; Noether/Rose confirm scope and nonclaims; Ranga confirms the literature map; Shinichi approves one Phase 1A slice.

### Phase 1 — Separate internal provenance from public compatibility policy

**Purpose:** make the two-axis architecture truthful without hiding a user-visible policy change inside a parity refactor.

**Phase 1A — approved next-slice candidate:** introduce internal resolved provenance and a descriptive compatibility table; preserve current integer data encoding through an adapter; add parity tests for implicit ML, explicit Laplace ML, current MSPL, and currently accepted non-Laplace combinations. This slice records what happened but does not reject or reinterpret an accepted call.

**Phase 1B — separate approval required:** decide the user-visible compatibility policy for explicit `estimator = "ml"` outside Laplace. Alternatives include a typed error, lifecycle deprecation followed by an error, or a redesigned criterion argument. This is an API/semantic behavior change and requires its own docs, tests, release note, and user review.

**Tests for 1A:** objective/gradient/report equality for every existing admitted route and currently accepted call, plus fitted-object provenance snapshots. Typed failures for newly invalid combinations belong only to 1B.

**Compute:** none beyond package unit tests; expected implementation/review time 8–12 hours.

**Exit gate for 1A:** exact numerical and accepted-call parity. Any change in fitted values, objective, gradient, warnings/errors, or accepted syntax stops the slice for separate review.

### Phase 2 — Re-express the current Bernoulli surface in registries

**Purpose:** replace hard-coded admission with explicit existing cells while freezing the guarded determinant atom.

**Work:** register logit, probit, and cloglog separately; retain current `q`, missingness, weights, offsets, free-\(\Psi\), ordinary/spatial, and complete-response fences. Complete or explicitly rescope B2 failure-inclusive adjudication. Keep inference work isolated.

**Exit gate:** no change to current admitted results; all current exclusions remain exclusions; the evidence registry exposes incomplete hard cells rather than averaging them away.

### Phase 3 — Matched Gaussian factor/Heywood route

**Purpose:** test the strongest direct prior-theory bridge.

**Model:** ordinary Gaussian native-Laplace factor model with the exact \(\Sigma=\Lambda\Lambda^\top+\Psi\) parameterization and a separately derived Akaike/Hirose-type penalty.

**Work:** prove the boundary limit under the implemented parameterization; test response-scale equivariance, rotation-invariant covariance recovery, healthy controls, genuine near-zero \(\Psi\), misspecified rank, and penalty sensitivity. Do not transplant the current Bernoulli loading atom by convenience.

**Exit gate:** interiority plus covariance-recovery and healthy-regime no-harm evidence. Gaussian success earns only the exact Gaussian route.

### Phase 4 — Poisson, then NB2 and NB1

**Purpose:** extend to counts one family and one boundary at a time.

**Poisson first:** derive its information atom and coercivity for all-zero and near-zero count designs; distinguish exposure/offset structure from information size.

**Negative binomial next:** separate mean-boundary penalties from dispersion \(0\) or \(\infty\) boundaries. NB1 and NB2 do not inherit each other's scale or theorem.

**Exit gate:** family-specific symbolic/TMB oracles, healthy and boundary DGPs, recovery, prediction, and penalty sensitivity. Finite count fits alone do not pass.

### Phase 5 — Ordinal, multinomial, and other distribution parameters

**Purpose:** address cutpoints, contrasts, bounded means, point masses, and shape parameters explicitly.

**Order:** ordinal-probit/logit cells; multinomial contrast cells; beta/beta-binomial; Tweedie; truncated and delta/hurdle components. Each gets a separate boundary definition and evidence row. The ordinal #897 diagnostic programme cannot be used as MSPL evidence without a new MSPL-specific calibration.

**Exit gate:** no shared-family claim; every category/contrast/shape boundary has its own theorem or explicit empirical-only status.

### Phase 6 — Covariance structures and mixed-family composition

**Purpose:** extend only proved homogeneous ordinary cells.

**Order:** ordinary `indep`, `dep`, and `latent` with free \(\Psi\); then animal, phylogenetic, kernel, and spatial structures with their own invariant coordinates. Mixed families come last, with a connected-design check proving every free coefficient direction is covered.

**Exit gate:** structure-specific recovery and invariance. Ordinary evidence never promotes a structured-source route.

### Phase 7 — Inference and model comparison

**Purpose:** decide what uncertainty and comparison mean for an MSPL estimator.

| Construction | Target | Current interpretation |
|---|---|---|
| Penalized-objective profile | Curvature of the active penalized criterion | Feasibility only until coverage is calibrated |
| Penalty-off likelihood curvature at MSPL point | Local approximate-likelihood curvature away from an MLE | Not ordinary ML Wald inference |
| Estimator-refit bootstrap | Repeated behavior of the complete MSPL algorithm | Requires known-DGP coverage, failure, and width evidence |
| Sandwich/Godambe | Estimating-equation variability | Blocked until valid additive score units exist |

Model comparison is a separate derivation. The penalty-off likelihood at an MSPL point is not maximized, and dimension-dependent penalty scales invalidate naive comparison of penalized objectives across ranks. `logLik`, AIC, BIC, and LRT remain prohibited unless a route-specific theory and validation programme earns them.

### Phase 8 — Recommendation, fallback, or default policy

| Status | Minimum evidence |
|---|---|
| Experimental opt-in | Correct objective, fail-closed scope, recovery smoke, explicit nonclaims |
| Conditionally recommended | Failure-inclusive superiority or noninferiority in named boundary and healthy regimes; stable optimization; recovery, prediction, and penalty-sensitivity gates |
| Explicit fallback policy | Validated observable trigger, acceptable false-positive/negative behavior, same estimand, user opt-in, recorded reason and both attempts |
| Default | Broad intended-surface compatibility, calibrated inference or a separately approved point-only redesign, valid model selection, ordinary-case noninferiority, usability, and backward compatibility |

Automatic silent fallback is presumptively rejected. It can be reconsidered only after a trigger is validated for the latent design—not merely the fixed-effects design.

## 12. Validation programme

Each family-by-boundary route uses a paired ADEMP design: identical generated data, starts, optimizer, Laplace settings, and retained attempts for LA-ML and LA-MSPL.

### Aims

1. Does MSPL produce a finite, stationary, reproducible interior estimate at the targeted boundary?
2. Does it improve estimand-relevant risk or prediction where ML fails?
3. Does it avoid material harm in healthy regimes?
4. Are results stable across defensible atoms, scales, starts, orderings, and parameterizations?
5. If inference is proposed, is repeated-sampling coverage calibrated with usable width and availability?

### Data-generating mechanisms

- healthy interior controls;
- known targeted-boundary cells;
- scientific near-boundary values that are valid truths;
- weak-information controls without the named boundary;
- misspecified rank/structure controls;
- negative controls where a different mechanism creates instability;
- n, trait-count, rank, event-count, missingness, offset, and structure ladders introduced one axis at a time.

### Estimands

- fixed effects and linear predictors;
- rotation-invariant shared covariance \(\Lambda\Lambda^\top\);
- diagonal \(\Psi\) and total \(\Sigma\) where identified;
- source-specific covariance and range/variance coordinates;
- distribution parameters;
- held-out log score and calibration;
- interval coverage, width, and availability only in inference phases.

### Measures and denominators

Every attempted fit contributes to completion, finiteness, convergence, stationarity, Hessian, and runtime denominators. Accuracy and prediction summaries must state the conditioning set. Paired summaries cannot hide cells where one estimator failed. Failures, warnings, nonfinite values, exclusions, and timeouts are immutable rows.

Provisional numerical no-harm thresholds must be preregistered and separately approved before a campaign. Candidate starting points—not decisions—are healthy-regime RMSE no more than 10% worse than ML, predictive loss no more than 2% worse, and usable-rate lower-bound loss no more than 2 percentage points. Boundary-route absolute and comparative gates must be calibrated by a pre-run receipt rather than chosen after seeing campaign results.

### Compute discipline

Pure-logic and one-cell smoke tests run locally after an explicit time estimate. Campaigns use Totoro or DRAC, never GitHub Actions. A pre-run test must prove the DGP, schema, retention, and elapsed time. Any estimate above 30 minutes requires a frozen grid and fresh approval. Totoro stays at or below 150 cores with threaded libraries pinned to one thread.

## 13. Ranked risks and stop rules

1. **Objective mismatch:** stop on any symbolic/R/TMB sign, map, count, transform, gradient, or decomposition mismatch.
2. **Wrong asymptotic story:** stop “soft and ML-equivalent” claims if the scale does not vanish in the intended dimensional regime or Laplace score-error conditions are absent.
3. **Selective evidence:** stop promotion if failure-inclusive evidence removes the paired-subset advantage or leaves hard cells unidentified.
4. **Mechanism failure:** retire the separation or Heywood explanation if its label does not predict the pathology; the estimator may remain a different empirical candidate.
5. **Healthy-regime harm:** stop recommendation if risk, prediction, calibration, or usability is materially worse than LA-ML.
6. **Penalty determination:** stop scientific interpretation if defensible atoms or scales yield materially different conclusions.
7. **Inference failure:** stop interval promotion on miscoverage, overcoverage, unavailable intervals, excessive width, or non-positive-definite curvature.
8. **Representation dependence:** stop on trait-order, rotation, contrast, response-unit, or source-coordinate dependence outside the declared contract.
9. **Silent criterion switching:** stop any fallback that hides model misspecification or changes criterion without explicit user authorization and provenance.
10. **Scope transfer:** stop any promotion based solely on a different family, link, rank, missingness pattern, covariance tier, or integration route.

## 14. Team review and reconciled judgments

### TEAM RAISED — Gauss, TMB architecture

Gauss found the current two-criterion architecture mathematically sound, but the internal `estimator_id` overloads public criterion, numerical kernel, and provenance evaluation. He recommends orthogonal internal controls and a three-registry design. He initially placed Poisson before Gaussian as the simplest new likelihood atom.

### TEAM RAISED — Curie and Fisher, validation

Curie and Fisher require paired, failure-inclusive ADEMP evidence and independent gates for interiority, recovery, prediction, calibration, and scientific usefulness. They recommend Gaussian factor/Heywood as the first new route because it has a directly matched primary theory, followed by Poisson and NB families.

### TEAM RAISED — Rose and Noether, claims and alignment

Rose and Noether found no current static objective-alignment defect, but warned that the programme must not call the composite estimator MAP or Firth, must distinguish the exact marginal likelihood from its Laplace approximation, and must not hide resolution of the integration/criterion API ambiguity inside a no-change refactor. They regard automatic fallback as unjustified and the active interval branch as evidence-bearing but not merge-ready.

### TEAM RAISED — Ranga, literature landscape

Ranga used the grounded notebook as a skeptical prior-art map, not as authority. He verified the two supplied primary papers and three counterpoint sources, excluded duplicate MSPL records and an irrelevant abstract book, and found no readable third-party MSPL evidence for Poisson, negative-binomial, ordinal, or multinomial GLLVMs under Laplace integration. His strongest defensible current formulation is: **LA-MSPL is a theoretically motivated experimental binary-logit estimator whose GLLVM and Laplace properties require independent validation.** The current `gllvmTMB` probit and cloglog routes therefore remain implementation cells with internal evidence, not consequences of the mixed-logistic theorem.

Ranga recommends Gaussian factor analysis as a penalty/rotation validation anchor, current Bernoulli/binomial-logit as opt-in and point-estimation-first, probit and cloglog as separate link proofs, Poisson as a new derivation, NB only after its dispersion boundaries are solved, and ordinal/multinomial last. He also recommends fixed-only, covariance/loading-only, and scale ablations; high-order AGHQ or direct low-dimensional integration as a Laplace falsification benchmark; weak-prior/log-F comparators where meaningful; and large-sample no-harm tests in which MSPL should approach ML.

### Ada's reconciliation

Both scientific sequences are reasonable. The programme chooses **Gaussian Heywood first, then Poisson**, because the first new route should maximize theory-to-implementation alignment rather than coding simplicity. Poisson remains the next family because it offers a simple one-sided boundary stress test. Existing Bernoulli stabilization and evidence completion precede both.

## 15. The next 10-hour slice

**Recommended Phase 1A slice: internal criterion/integration provenance, with no numerical or accepted-call change.**

| Work block | Estimate | Deliverable |
|---|---:|---|
| Re-read live lane/PR state and freeze baseline | 0.5 h | Immutable source and collision receipt |
| Specify descriptive compatibility and provenance objects | 1.5 h | Internal table and resolved-state contract |
| Add a provenance adapter around current integer IDs | 2.5 h | No-change R/TMB plumbing slice |
| Add implicit/explicit ML, MSPL, and accepted-call parity tests | 2.5 h | Objective, gradient, report, warning/error, and routing parity |
| Run targeted tests and no-change fit checks | 1.5 h | Exact receipt; no campaign |
| Gauss/Noether/Rose review and reconcile | 1.0 h | PASS/HOLD verdict and after-task update |

**Approval requested:** one fresh task may implement **Phase 1A only** from current `origin/main`. It may edit internal R/TMB provenance and parity tests only. It may not reject or reinterpret an accepted integration/estimator call, widen the MSPL family/structure surface, change numerical atoms, change defaults, expose new public API, start a campaign, or merge the interval-feasibility branch. Phase 1B returns as a separate API-policy proposal.

## 16. Decisions locked and decisions still open

### Locked by this programme

- Laplace is the shared integration layer; ML and MSPL are distinct outer criteria.
- LA-MSPL is a serious parallel research estimator; LA-ML remains default and reference.
- The programme is boundary-by-family-by-structure, not one universal penalty.
- Finiteness is necessary but not sufficient.
- Healthy-regime no-harm and penalty sensitivity are compulsory.
- Inference, model comparison, automatic fallback, and default status are separate later admissions.
- Gaussian Heywood is the first new-family route; Poisson and NB follow.
- No active provisional branch is merged wholesale.

### Open for later evidence

- The Phase 1B compatibility policy for explicit estimator requests outside Laplace.
- The exact public wording, if any, for a conditionally recommended MSPL route.
- Route-specific penalty atoms and rates beyond the current binary surface.
- Whether a latent-design diagnostic can ever support an explicit fallback policy.
- Which inferential construction, if any, is useful and calibrated by target.
- Whether model-comparison criteria can be derived on a common target across ranks.
- Whether any route is sufficiently general and usable to justify eventual default consideration.

## 17. Files changed

- `docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md` — added this single consolidated programme and after-task record.

No package source, tests, generated documentation, NEWS, validation-register status, version, release artifact, or GitHub issue state changed.

## 18. Checks run

- Read the current `origin/main` MSPL API, R assembly, TMB objective, Design 88, NEWS entry, validation-debt rows, and B2 partial-evidence receipt.
- Read both supplied primary papers directly.
- Queried Ask Brain across all projects and checked the returned engineering-notebook context against primary sources.
- Ran a grounded Notebook literature pass with trusted supplied PDFs and a skeptical counter-literature search.
- Re-read live open pull requests and branch state.
- Ran the lane preflight and exact-file collision check before editing.
- Obtained independent architecture, validation, literature, and claim-boundary reviews.
- Ran `git diff --check`, exact stale-claim searches, and local-link existence checks after drafting; all passed. A final Rose/Noether read was then requested on the consolidated document.

No simulation, fit, benchmark, package test, compilation, `R CMD check`, pkgdown build, CI run, or external compute was appropriate for this documentation-only phase.

## 19. Tests of tests

No test code changed. The programme nevertheless requires future tests to fail before implementation on the targeted boundary, exercise healthy and negative controls, verify numerical derivatives against an independent oracle, retain all failed fits, and separate execution success from scientific success. Final review must confirm that every proposed gate can produce a HOLD or rejection rather than merely documenting success.

## 20. Consistency and Rose audit

- The recommendation is consistent with current NEWS and validation-register fences.
- The 5 × 3 covariance keyword grid is unchanged; `estimator` is not a covariance mode.
- `latent` retains the package-wide \(\Sigma=\Lambda\Lambda^\top+\Psi\) meaning; the current binary no-free-\(\Psi\) fence is not generalized.
- Separation screening remains a separate diagnostic and never selects the estimator automatically.
- LA-MSPL is not described as ordinary MAP, generic Firth regression, a repair for Laplace error, or a release-ready default.
- The active uncertainty branch is cited only as provisional evidence and not as a merge vehicle.

## 21. What did not go smoothly

The normal checkout was occupied by unrelated work, the repository had many active same-platform lanes, and duplicate design IDs made a new numbered design unsafe. A fresh worktree and dated unnumbered document resolved those coordination risks. Notebook authentication initially failed under restricted network access and succeeded after an authorized connectivity check. The B2 evidence and interval evidence were both substantial but incomplete, requiring explicit separation of encouraging results from admissible claims.

## 22. Team learning

The most useful general lesson is that “Laplace versus MSPL” is the wrong comparison. Laplace answers how latent variables are integrated; ML versus MSPL answers which outer criterion is optimized. Once separated, the programme becomes modular and falsifiable: the package can share one integration engine while admitting—or rejecting—penalty atoms one family and boundary at a time.

The second lesson is that direct theory match should outrank implementation convenience when choosing the first new estimator route. The Gaussian factor paper does not justify a general GLLVM claim, but it supplies the cleanest place to test whether the programme's proof-to-code discipline works at all.

## 23. Roadmap reconciliation

No existing numbered roadmap item is marked complete. This document supersedes no design contract. Design 88 remains controlling for the current binary estimator, while this programme governs proposed research sequencing. Any later implementation must update the validation-debt register only after its own evidence gate passes.

## 24. GitHub issue ledger

Issue #345 was inspected because it tracks the first bounded CRAN path. Its existing boundary is unchanged: LA-MSPL is separate estimator work and is not a prerequisite for the bounded first CRAN submission. No issue comment, label, closure, or status change was made. Future family routes should receive issue-linked evidence only when an implementation slice is approved.

## 25. Known limitations

- The current comparative binary campaign is incomplete in selectively hard cells.
- The interval lane has feasibility results but no complete repeated-sampling coverage verdict.
- Neither supplied paper proves the full implemented GLLVM estimator.
- Current high-dimensional soft-penalty rates lack a general theorem.
- Family-specific information, dispersion, cutpoint, mixture, and structured-source boundaries remain to be derived.
- The integration/criterion API ambiguity is identified but not repaired here.
- Notebook auto-imported sources are supporting triage; primary papers control claims.

## 26. Next actions and closure gate

1. Shinichi reviews and approves, revises, or rejects the bounded Phase 1A slice.
2. Start a fresh Codex task from current `origin/main`; do not continue implementation in this compacted planning task.
3. Re-run lane and exact-file collision checks.
4. Implement only the no-numerical-change and no-accepted-call-change provenance slice.
5. Run targeted parity tests and independent Gauss/Noether/Rose review.
6. Stop and present evidence before any family expansion or compute proposal.

**Closure:** this planning phase is complete when this single document is committed and independently reviewed. It does not close the estimator programme; it opens a disciplined, falsifiable route for LA-MSPL to earn the role of a major alternative to LA-ML.

## Protocol closeout crosswalk

The sections below preserve the exact after-task protocol labels. They summarize and point to the analytical record above rather than creating a second report.

## 1. Goal

Create one reviewable programme that decides how LA-MSPL could earn a role parallel to LA-ML while keeping current evidence, theory, API, inference, compute, and release boundaries explicit. The copy-ready goal is at the top of this document; the substantive decision is in Sections 1–2.

## 2. Implemented

Added this documentation-only programme, completed Ask Brain and primary-paper review, ran the skeptical Notebook/Ranga literature slice, reconciled Gauss/Curie/Fisher/Rose/Noether reviews, specified the architecture and validation phases, and filed the required Notebook research receipt. No package implementation or runtime behavior changed.

## 3a. Decisions and Rejected Alternatives

Accepted LA-MSPL as a serious parallel research estimator while retaining LA-ML as default/reference. Chose family-by-boundary registries over a universal penalty; chose Gaussian Heywood before Poisson as the first new route; rejected ordinary-MAP/Firth wording, automatic fallback, finiteness-only admission, wholesale interval-branch merge, family transfer, and inference/model-comparison promotion.

## 4. Files Touched

In `gllvmTMB`, only this file was added. The Notebook skill separately required a durable brain distillation and registry/index entries; those are supporting research metadata, not package design contracts. No R, TMB, test, Rd, article, NEWS, DESCRIPTION, validation-register, or release file changed.

## 5. Checks Run

See Section 18. Live source/PR/lane state, primary papers, current contracts, branch evidence, specialist reviews, `git diff --check`, claim searches, local links, and this formal validator were checked. No fit or package check was appropriate.

## 6. Tests of the Tests

No executable tests changed. Section 19 states the required future failure-before-fix, negative-control, oracle, failure-retention, and genuine-HOLD behavior for every implementation phase.

## 7a. Issue Ledger

Issue #345 was read and left unchanged. LA-MSPL remains separate from the bounded first-CRAN route. No issue was opened, closed, labelled, or commented on.

## 8. Consistency Audit

See Sections 14, 20, and 23. The programme preserves Design 88, NEWS and register fences; the 5 × 3 grid and `latent` meaning; the distinction between diagnostics and estimator selection; and the separation among point estimation, inference, and model comparison.

## 9. What Did Not Go Smoothly

See Section 21. The occupied checkout, many concurrent lanes, duplicate design numbers, restricted Notebook network access, and incomplete evidence receipts required isolation and explicit claim qualification. The first formal validator pass also found noncanonical headings; this crosswalk repairs that presentation defect without changing substance.

## 10. Known Residuals

See Section 25. The main residuals are incomplete hard-cell binary evidence, uncalibrated uncertainty, lack of general Laplace/GLLVM theory, unresolved high-dimensional rates, unimplemented family registries, and the current integration/criterion API ambiguity.

## 11. Team Learning

See Section 22. Integration and outer criterion are distinct axes; direct theory match should precede convenient family expansion; and every boundary intervention must be judged on estimand risk and usability as well as existence.

## 12. Cross-Product Coverage

This phase changes no product surface. It covers the internal `gllvmTMB` LA-ML/LA-MSPL terminology, current Bernoulli MSPL objective, ordinary/spatial evidence fences, family-boundary research sequencing, and relevant unmerged `drmTMB` non-logit lessons as qualified prior evidence. It **does NOT cover** GLLVM.jl or drmTMB runtime code; non-Laplace engines; REML, VA/EVA, or AGHQ estimators; package documentation sites; missing-response or aggregation support; public inference or model comparison; CRAN artifacts; CI; or external compute. None of those providers or surfaces was changed or used as admission evidence. Any later cross-package port requires its own symbolic alignment, implementation review, and validation receipt.
