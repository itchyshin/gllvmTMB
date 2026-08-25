# Ultra Plan — Family-wide mixed-family predictor-informed LV

Date: 2026-08-25
Platform: Codex
Planning checkout: `codex/lv-family-evidence-reconcile` at
`503ea66716ddd739f4bce1f444e1218b98f7dd79`
Planning-time `origin/main`: `482c9d372c7dc100f988f41f80d1b4cc3ce8a8e4`
Implementation branch: `codex/lv-mixed-family-all-native`
Exact implementation base: `origin/main@854d75a4b65b0f9eeb2b5fc5b121af90932bc86d`
Predecessor landing: PR #1210, merge commit
`854d75a4b65b0f9eeb2b5fc5b121af90932bc86d`
Durable plan: `docs/dev-log/plans/2026-08-25-lv-mixed-family-all-native-ultra-plan.md`

## GOAL

Solo platform: Codex
Deliverable: a source-pinned native-TMB programme in which every currently
fit-admitted response family is independently adjudicated for ordinary
predictor-informed latent scores and, where the model is coherent, can
participate in a named mixed-family fit with tested extraction, recovery
evidence, documentation, and honest inference boundaries.
Headline: make mixed-family
`latent(..., unique = FALSE, lv = ~ x)` a real family-wide capability rather
than a broad guard lift.
In parallel: provenance reconciliation, symbolic family-contract work,
simulation-harness design, and disjoint documentation preparation.
Defer: arbitrary family combinations; rank `K > 1`; default `+ Psi`; response
masks; factor or missing LV predictors; fixed `X + X_lv`; REML;
VA/AGHQ/MSPL; structured sources/tiers; Julia/GLLVM.jl changes;
profile/bootstrap; constructor-only families.
Discipline: verification is Unlazy `--reverify` plus fresh D-43 panels;
compute is local smoke followed by Totoro only after a measured pre-run and
explicit approval; closure requires all 17 native family IDs to have
evidence-backed verdicts, every admitted claim to be tested and documented,
residual blocks to remain explicit, CI to be green, and the lane to be handed
over.

## 1. Destination and locked decisions

The target is the ordinary unit-tier, loadings-only, rank-1 model

\[
x_i \sim N(0,1),\qquad
u_i = \alpha x_i + e_i,\qquad e_i\sim N(0,1),
\]

\[
\eta_{it} = \beta_{0t} + \lambda_t u_i,
\qquad B_{lv,t}=\lambda_t\alpha,
\qquad \Sigma=\Lambda\Lambda^\top.
\]

For mixed families, each trait keeps its own response distribution, link,
dispersion, thresholds, trial count, or hurdle/zero-mass block. The shared
latent score and `B_lv` live on the linear-predictor scale. Raw `alpha` and
`Lambda` are not cross-fit recovery targets. Trait-scale `B_lv` and
`Sigma = Lambda Lambda^T` are the rotation/sign-invariant scientific targets.

The programme is restricted to explicit
`latent(1 | unit, d = 1, unique = FALSE, lv = ~ x)`. The default ordinary
`+ Psi` model is not silently widened. Each admitted mixed combination is
named and tested; the programme does not claim that every arbitrary pairing
or larger mixture is healthy.

The 17 currently fit-admitted native family IDs to adjudicate are:

1. Gaussian.
2. Binomial with logit, probit, and cloglog links as separate link cells.
3. Poisson.
4. Lognormal.
5. Gamma.
6. Negative binomial 2.
7. Tweedie.
8. Beta.
9. Beta-binomial.
10. Student-t.
11. Truncated Poisson.
12. Truncated negative binomial 2.
13. Delta-lognormal.
14. Delta-Gamma.
15. Ordinal probit.
16. Negative binomial 1.
17. Multinomial.

Constructor-only or unwired families are excluded. Any discrepancy between
this list and current `family_to_id()` / TMB dispatch is a provenance finding,
not permission to invent an eighteenth cell.

Each family receives exactly one verdict:

- `ADMIT_RECOVERY`: named mixed route has healthy extraction and retained
  recovery evidence.
- `ADMIT_UNCALIBRATED`: point/recovery route is admitted but Wald calibration
  is not claimed.
- `HOLD_NUMERICAL`: the model is coherent but the frozen health/recovery gate
  fails or is too weak.
- `BLOCK_MODEL_CONTRACT`: the response construction or estimand is not
  coherent under the frozen rank-1 ordinary contract.

## 2. Prior-work and anti-duplication receipt

The bounded predecessor at commits `93020c79` and `503ea667` closed the named
native Gaussian and pure binomial Design 73 C1 cells. Its source-pinned receipt
is `docs/dev-log/artifacts/methods-superarc/lv-design73-c1-closure-receipt.md`.
It establishes `B_lv = Lambda alpha^T`, rejects raw-axis cross-fit targets,
keeps REML/fixed-`X`/source-tier expansions closed, and records the sister
GLLVM.jl verdict
`LV_COMMON_FAMILY_HOLD__RAW_OR_LINEAGE_GAP`.

Ask-Brain was run with `search_all_projects = true`. It returned existing
mixed-family latent-scale, family-registry, simulation-pipeline, link-residual,
and interval-status records. These are leads to reconcile against the current
repository, not substitutes for source or retained artifacts.

The current native TMB likelihood block is expected to be family-neutral with
respect to the latent-score mean; the known blocker is the R-side family guard.
This expectation must be proved from current source before implementation.
No C++ edit is planned. If TMB source must change, stop, apply the dedicated
likelihood review, revise the estimate, and seek scope approval.

`/Users/z3437171/Dropbox/Github Local/GLLVM.jl` remains strictly read-only and
out of scope. Do not branch, edit, clean, fit, simulate, commit, or create a
worktree there.

## 3. Landing and ownership sequence

1. Persist this plan and its ignored Unlazy ledger under the exact G0 lease.
2. Reverify the predecessor C1 candidate. The 2026-08-25 refresh passed all
   13 existing gates.
3. Push `codex/lv-family-evidence-reconcile` and open one narrow C1 PR when
   GitHub is reachable.
4. Stop for explicit merge authority. Do not stack mixed-family code on an
   unmerged documentation branch.
5. After the C1 PR merges, fetch the exact new `origin/main`, record its SHA,
   and create a fresh branch, proposed name
   `codex/lv-mixed-family-all-native`.
6. Run lane preflight and claim exact implementation paths only after the new
   branch exists. Re-measure every shared file immediately before editing.

No other lane's changes may be reverted. A refused overlapping lease pauses
only the colliding slice; disjoint read-only work may continue.

## 4. Work decomposition

| Slice | Lens | Output | Dependency |
| --- | --- | --- | --- |
| G0 activation | Ada/Shannon | durable plan, lease receipt, Unlazy ledger, C1 landing preparation | active goal |
| S1 provenance | Jason | source-pinned 17-family dispatch/parameterisation matrix and prior-artifact map | post-merge branch |
| S2 symbolic contract | Gauss + Noether | math-to-R-to-TMB-to-extractor alignment table; family residual blocks | S1 |
| S3 first proof cell | Gauss + Curie | Gaussian + multi-trial binomial-logit mixed fit, negative controls, extractor tests | S2 |
| S4 regular families | Curie | Poisson, lognormal, Gamma, NB2, Tweedie, Beta, beta-binomial, Student-t, NB1 named cells | S3 |
| S5 special families | Gauss + Fisher | truncated, delta, ordinal, multinomial contracts and named cells | S3 |
| S6 recovery harness | Curie | frozen ADEMP driver, all-attempt schema, deterministic truth checks | S2, S3 |
| S7 retained recovery | Curie + Ada | approved Totoro r200 evidence for admitted cells | measured pre-run + approval |
| S8 API/docs | Boole + Pat + Emmy | extraction contract, errors, Tier-1 reader path, capability/status boundaries | S3–S7 |
| S9 inference | Fisher | eight-archetype Wald calibration adjudication; no profile/bootstrap | recovery admission + approval |
| S10 verification | Grace | focused tests, package checks, pkgdown, stale scans, Unlazy `--reverify` | frozen candidate |
| S11 D-43 panel | 2 Terra + 1 Sol | frozen-diff reviews for math/API, evidence, scope/reproducibility | S10 |
| S12 closeout | Rose + Melissa + Ada | after-task, plan-vs-actual, handover, narrow commits, clean landing | S11 |

Parallelism is limited to disjoint paths: S1 and S2 research can proceed in
parallel; S4 and S5 can use separate test/driver paths after S3 freezes the
contract; documentation drafting can start after the first healthy public
surface is known. Shared source, register, NEWS, pkgdown, and check-log edits
remain serialized under exact leases.

## 5. Family admission protocol

Every family row must record:

- runtime family ID and constructor/link;
- response support and DGP generator;
- likelihood and dispersion/threshold/zero-mass parameterisation;
- current R guard and current TMB dispatch;
- whether `X_lv_B`, `alpha_lv_B`, score mean, `B_lv`, and covariance reports
  are reached without family-specific reinterpretation;
- the named Gaussian-anchor mixed cell or justified non-Gaussian sentinel;
- attempted fits, convergence, finite estimability, Hessian/CI availability,
  exclusions, failures, and elapsed time;
- recovery/coverage metrics with MCSE where applicable;
- final verdict and exact claim boundary.

The primary named grid uses a Gaussian anchor plus one candidate family.
Binomial logit, probit, and cloglog are separate link cells, yielding 18
Gaussian-anchor cells. One non-Gaussian sentinel—Poisson + Gamma + Beta—is
required to show that the implementation is not merely a Gaussian-special
case. Total planned recovery grid: 19 cells.

Special-family interpretation is frozen before data are seen:

- binomial and beta-binomial retain explicit trial counts;
- lognormal and Student-t keep their native residual/scale parameters;
- Gamma/Tweedie/NB1/NB2 retain their current mean-dispersion conventions;
- truncated families use the correctly normalized zero-truncated likelihood;
- delta families retain separate presence and positive-response blocks;
- ordinal probit retains ordered thresholds and latent-probit scale;
- multinomial retains its reference/category-identifiability contract.

If a special family cannot express a trait-level `B_lv` on the same
linear-predictor scale without changing the model, it receives
`BLOCK_MODEL_CONTRACT`; the programme does not force admission.

## 6. Frozen ADEMP design

Aim: determine whether the named mixed route recovers the shared
predictor-informed latent effect and covariance for each family.

Base DGP:

\[
x_i\sim N(0,1),\quad e_i\sim N(0,1),\quad
u_i=0.60x_i+e_i,
\]

\[
\Lambda=(0.70,-0.55,0.45,-0.35)^\top,
\quad B_{lv}=\Lambda(0.60),
\quad \Sigma=\Lambda\Lambda^\top.
\]

There is no `Psi`. Gaussian observation SD is 0.30. Multi-trial binomial uses
20 trials. Family-specific intercepts and dispersion settings must be chosen
before the first retained run to avoid degeneracy while keeping the estimand
fixed. The base sample size is `max(240, current healthy fixture n)` and any
family-specific increase must be justified and frozen before retained results.

Recovery campaign: 19 cells × 200 attempts = 3,800 planned attempts. Every
attempt remains in the retained denominator. Gates per cell:

- `n_attempted = 200`;
- at least 95% optimizer convergence;
- at least 90% finite, estimable `B_lv`;
- absolute `B_lv` bias no greater than 0.10;
- `B_lv` RMSE no greater than 0.20;
- maximum absolute bias in reported `Sigma` no greater than 0.15;
- algebra and score-decomposition identities within `1e-8`.

Failure policy is fixed: construction failure, optimizer failure, non-finite
target, non-PD uncertainty, and unavailable CI remain separately counted.
Nothing is silently redrawn or tuned away. A family may be held even if the
aggregate grid looks healthy.

Wald calibration is a later, separate admission layer for eight archetypes:

1. Gaussian + binomial logit.
2. Gaussian + Poisson.
3. Gaussian + NB2.
4. Gaussian + Gamma.
5. Gaussian + Beta.
6. Gaussian + ordinal probit.
7. Gaussian + delta-Gamma.
8. Gaussian + multinomial.

Each archetype plans 500 attempts, for 4,000 total. Required evidence is at
least 450 eligible intervals, coverage between 0.92 and 0.98, exact attempted
and eligible denominators, CI-unavailable counts, and binomial MCSE. Failure
of interval calibration does not erase a healthy point route: it yields
`ADMIT_UNCALIBRATED` and explicit public fencing.

## 7. Compute and approval gates

No fit, simulation, recovery run, or benchmark starts without a stated time
estimate.

Local route-health wave:

- maximum four live fits per wave;
- first compilation plus fit estimate: 10–25 minutes locally;
- one correctness smoke must prove finite `B_lv`, correct trait/predictor
  labels, `Sigma = Lambda Lambda^T`, and total score = mean + innovation;
- if the projection exceeds 30 minutes, or a run overruns 30 minutes, stop
  with the measured receipt.

Retained compute:

1. Run a three-attempt local canary for the exact frozen driver.
2. Report runtime projection, correctness checks, output schema, failure
   partition, and artifact path.
3. Stop and obtain explicit approval before Totoro.
4. Totoro is the only planned remote target, capped at 150 cores with
   `OPENBLAS_NUM_THREADS=1`.
5. Do not use DRAC unless a new explicit routing decision is made.
6. Never use GitHub Actions for science compute or store science artifacts
   there.

The r200 recovery and r500 coverage campaigns are not pre-authorized by this
plan. Only local smokes at or below 30 minutes may run after their pre-run
gates.

## 8. Unlazy acceptance ledger

Run state lives in `.unlazy/lv-mixed-family-all-native/` and remains ignored.
The ledger contains a root `GATES.md` and leaf ledgers for landing,
provenance, symbolic contract, first proof cell, regular families, special
families, recovery, documentation, calibration, verification, and closeout.

Required root gates:

- G1: exact branch/base/lease receipts exist; C1 lands before the new branch.
- G2: all 17 runtime family IDs map to source, parameterisation, and verdict.
- G3: the symbolic contract matches parser, R data, TMB parameters/reports,
  extractor labels, and documentation.
- G4: no cross-fit acceptance criterion uses raw `alpha` or `Lambda`.
- G5: the first Gaussian + binomial-logit mixed route passes positive and
  negative controls.
- G6: every admitted family has a named mixed cell and focused tests.
- G7: every attempted fit is retained and failure denominators are explicit.
- G8: inference claims are no broader than earned calibration evidence.
- G9: all deferred surfaces still fail loudly or remain explicitly outside
  the claim.
- G10: focused tests, full appropriate package checks, article render,
  pkgdown, and stale-wording scans pass.
- G11: the fresh D-43 panel reviews the exact frozen candidate SHA/diff.
- G12: after-task, Melissa plan-vs-actual, handover, commits, clean tree, and
  lease release validate.

Every runnable `CHECK:` command is inspected before `--approve`. Final
verification uses `--reverify`, never `--status`.

## 9. Public interface and documentation

The implementation may lift only the family/mixed-family guard needed for the
frozen ordinary loadings-only rank-1 contract. It must preserve current
fail-loud behavior for default `+ Psi`, rank `K > 1`, masks, factor/missing LV
predictors, fixed `X + X_lv`, REML, structured tiers/sources, Julia, and
profile/bootstrap.

Extraction must return family-aware trait labels and the rotation-invariant
`B_lv` on the linear-predictor scale. Delta, ordinal, and multinomial payloads
must not be flattened into misleading Gaussian-shaped claims. Existing
return-type contracts and generated documentation are updated only if the
actual public object changes.

Reader-facing documentation will:

- lead with a biological question about a shared environmental gradient;
- show long and `traits(...)` wide calls through `gllvmTMB()`;
- demonstrate one healthy named mixed-family route;
- explain family-specific response scales and common latent-predictor scale;
- interpret `B_lv`, never compare raw axes across fits;
- state admitted named combinations and uncalibrated/held/blocked families in
  plain language without internal row IDs;
- avoid claims about arbitrary combinations or deferred surfaces.

Internal Design 73, capability status, validation register, NEWS, check-log,
and after-task surfaces will carry exact row/evidence traceability.

## 10. Verification and independent review

Verification expands with the implementation risk:

1. Static parser/guard/dispatch/source scans.
2. Pure-logic DGP and truth-oracle tests that fail against planted defects.
3. First mixed route construction, fit, extraction, algebra, and negative
   controls.
4. One focused test file per admitted family or tightly justified family
   group, with failures preserved.
5. Recovery artifact schema and all-attempt denominator checks.
6. Inference-boundary tests for calibrated versus uncalibrated families.
7. Evaluated article render and reader-seat inspection.
8. `devtools::document()`, focused tests, `pkgdown::check_pkgdown()`, and a
   full package check when implementation/exported behavior changes.
9. Unlazy `--reverify` over every runnable leaf.
10. Fresh frozen-diff D-43 panel:
    - Terra: Gauss + Emmy on parameterisation, payloads, and API boundaries;
    - Terra: Rose + Grace on scope, reproducibility, files, CI, and landing;
    - Sol: Noether + Fisher on estimand, recovery/coverage denominators,
      special-family contracts, and claim limits.

Any failure returns to the original producer. Material repair creates a new
frozen candidate and all affected gates and panel reviews rerun.

## 11. Closeout and landing

Rose's after-task report must enumerate decisions, rejected alternatives,
every file touched, exact checks and failures, tests of the tests, issue
ledger, consistency audit, known residuals, and explicit negative space.
Melissa writes a plan-vs-actual reconciliation classifying every deviation as
adaptive, drift, or unclear. Run the after-task validator and
`handoff_gate.sh`, then create narrow local commits, prove the tree clean,
release all leases, and leave a source-pinned handover.

Push/PR actions may occur only within the approved landing sequence. Merge,
release, capability announcement, remote science compute, destructive action,
and GLLVM.jl mutation always require a stop or remain prohibited.

The full programme is complete only when all 17 family IDs have independently
auditable verdicts and every admitted mixed route has the promised tests,
evidence, extraction, documentation, CI, and closeout. A plan, guard lift,
single healthy mixed fit, or aggregate recovery table is not completion.

## 12. Pre-authorisation envelope

Authorized reversible work after activation:

- persist this plan and ignored Unlazy ledgers;
- perform read-only source/history/provenance reconciliation;
- push/open the already verified narrow C1 branch when GitHub is available;
- after explicit C1 merge authority, create the fresh implementation branch;
- make scoped implementation, test, driver, extractor, and documentation
  edits under exact leases;
- run local route-health fits at or below 30 minutes after stating estimates;
- repair in-scope failures; run verification/review/closeout; create narrow
  local commits.

Must stop for:

- C1 merge authority;
- any projected or actual local fit/simulation/benchmark above 30 minutes;
- the three-attempt canary receipt before any Totoro campaign;
- any DRAC work;
- any need to change the estimand, rank, `Psi` contract, response-mask
  contract, family registry, TMB likelihood, exported API, or deferred scope;
- a required lease refusal;
- push/merge/release beyond the specifically approved landing step;
- any GLLVM.jl mutation, destructive action, credential change, or public
  capability announcement.

This active Codex goal authorizes carrying the reversible envelope through;
it does not authorize the stop-gated actions above.
