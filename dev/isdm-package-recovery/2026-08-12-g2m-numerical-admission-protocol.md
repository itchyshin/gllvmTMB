# G2m prospective numerical-admission protocol

**Status:** design-only, pending explicit approval.
**Predecessor:** G2k diagnostic commit `5c15da39`; G2k remains
`G2K_CALIBRATION_HOLD`; G2c remains `G2C_SMOKE_ADMISSION_HOLD`.

## 1. Purpose and non-goals

G2m resolves a prospective admission-rule ambiguity exposed by G2k.  It does
not repair an estimator, refit an attempt, recompute a G2k classification, or
change the locked six-species model.  In particular, it does **not** alter the
raw-gradient threshold \(10^{-3}\), likelihood, DGP, seed grid, GBIF-only
source gate, rank-one \(\Lambda\), diagonal \(\Psi\), map, or known-truth
metrics.

The sole design question is whether a same-objective polish record is
conditional evidence of a repair, or a universal requirement that can reject a
fit already satisfying the raw numerical gate.  The G2k record has 15
raw-gradient-passing, all-metric-passing but polish-ineligible holds, so the
old universal interpretation is not a defensible prospective admission rule.

## 2. Locked model and symbolic-to-implementation alignment

The ecological/observation model remains

\[
\eta_{cs}=x_c^\top\beta_s+\lambda_s z_c+e_{cs},\quad
e_{cs}\sim N(0,\psi_s^2),\quad \psi_s=\exp(\theta_{\rm diag,s}),
\]
\[
Y^G_{cs}\sim\mathrm{Poisson}\{a_c^G\exp(\eta_{cs}+\delta_s+b_c\gamma_s)\},
\quad
Y^S_{csv}\sim\mathrm{Bernoulli}\{1-\exp[-a^S_{cv}\exp(\eta_{cs})]\}.
\]

G2m adds no DGP draw or recovery extractor.  It only makes the numerical
admission evidence around the unchanged outer vector \(\theta\) explicit.

| Symbol / rule | Current implementation field | DGP draw | Recovery extractor / admission record | Truth / invariant |
| --- | --- | --- | --- | --- |
| \(g=\nabla_\theta\ell(\theta)\) | `tmb_obj$gr(opt$par)`; `fit_health$max_gradient` | unchanged G2k fixture; no new draw | `final_gradient` | \(\|g\|_\infty\le10^{-3}\) is unchanged |
| `theta_diag_B` / \(\psi_s\) | `theta_diag_B`; `sd_B`; boundary helper | unchanged; no new draw | named `near_zero_sd_B` class and coordinate | one named diagonal boundary only for existing polish |
| `theta_rr_B` / \(\Lambda\) | rank-one random-regression block | unchanged; no new draw | maximum-gradient block/index | not a substitute boundary coordinate |
| `b_fix` / \(\beta,\delta,\gamma\) | fixed-effect block | unchanged; no new draw | maximum-gradient block/index | no existing candidate is declared |
| candidate \(\theta'\) | `run_one()` and the boundary-only covariance-Newton primitive | none | raw/candidate objective, gradient, Hessian, map, boundary, and method record | same objective/map; no non-boundary candidate is admitted at G2m |
| recovery metrics | unchanged G2i metric extractor | existing truth only | separate from admission decision | no G2k reclassification |

The scaled score \(\|g\|_\infty/(1+|\ell|)\) remains descriptive only.  It
may be retained in provenance but cannot admit a fit, because its denominator
depends on objective scaling.

## 3. Prospective decision table

This table applies only to a future, separately approved G2m estimator and
only after ordinary prerequisites: exactly three restarts, finite objective and
raw gradient, optimizer code zero, positive-definite fixed Hessian, valid
profiles, and valid GBIF-only source gate.  Known-truth recovery metrics remain
a separate, unchanged decision stage.

| Case | Exact predicate | `polish_status` | Prospective numerical admission | Rationale |
| --- | --- | --- | --- | --- |
| A. Raw pass / polish ineligible | \(\|g\|_\infty\le10^{-3}\) and existing boundary predicate false | `NOT_REQUIRED` | PASS numerical admission | A repair record is not logically required after the raw gate already passes. |
| B. Boundary repair candidate | \(10^{-3}<\|g\|_\infty<10^{-2}\), exactly one `near_zero_sd_B`, maximum score is not `theta_diag_B`, and all existing G2i eligibility conditions | `ELIGIBLE`, then `ACCEPTED` or `REJECTED` | PASS only if accepted candidate meets the unchanged raw gate and existing acceptance invariants; otherwise HOLD | Preserves the one named, same-objective G2i repair envelope. |
| C. Non-boundary residual | \(10^{-3}<\|g\|_\infty<10^{-2}\), no named boundary, and a unique maximum block `b_fix` or `theta_rr_B` | `NO_CANDIDATE` | HOLD | G2k supplies no predeclared, identifiable, validated same-objective candidate for this geometry. |
| D. Other raw failure | raw gate fails but Case B/C do not hold, including tied maxima, invalid/non-PD/nonfinite states, other boundary patterns, wrong optimizer/ridge/AGHQ state | `INVALID` or `NO_CANDIDATE` | HOLD | No fallback, tolerance change, random restart, map change, or objective rebuild is authorized. |
| E. Impossible overlap | raw gate passes and Case-B eligibility is true | `INVALID_RULE_STATE` | HOLD and fail validation | Case-B eligibility explicitly requires a raw failure; this detects a predicate bug. |

The decision is therefore **conditional repair evidence**, not universal
admission evidence.  `NOT_REQUIRED` is a valid state, not an absent or failed
polish record.  This prospective rule may not be applied retrospectively to
the 150 G2k ledgers.

## 4. Candidate determination: `NO_CANDIDATE`

G2m records `NO_CANDIDATE` for Case C.  This is a bounded conclusion about
the present code and evidence, not a claim that no future method can exist.

The existing iJSDM candidate is intentionally confined to the named
near-zero-diagonal geometry.  The generic warm-restart route requires no
boundary and \(\|g\|_\infty\ge10^{-2}\), so it cannot supply an existing
candidate for Case C's strict interval.  The code also contains the algebraic
proposal \(\theta^+=\theta-\widehat{\mathrm{Cov}}(\theta)g\), evaluated with
the same objective, but it is invoked only after the same boundary-only
predicate.  Its helper verifies only finite dimensions: it does not establish
covariance symmetry, positive-definiteness, conditioning, or dimname alignment
with `opt$par`.  In addition, rank-one `theta_rr_B` has loading-sign symmetry,
so a positive-definite Hessian provides local curvature rather than global
coordinate uniqueness.

G2k shows that 58 of the 69 all-metric/raw-fail cases have maximum block
`b_fix` and 11 have `theta_rr_B`; neither is a diagonal-boundary case.
Selecting an extra retry, changing controls, or applying the current
covariance-Newton primitive to those cases would define a new estimator.  No
predeclared, identifiable, validated choice can be determined from the G2k
evidence, so G2m must not invent one.

## 5. Required no-fit and compiled-unit validation

No test in this design task builds a TMB objective, invokes `nlminb`, or calls
the iJSDM fitter.  Before a separate implementation task can request a local
pre-run, its test protocol must include:

1. a pure-logic, mutually exclusive/exhaustive decision-table test over Cases
   A–E, including the raw-pass/polish-ineligible G2k pattern;
2. a negative test proving Case E is rejected;
3. a boundary fixture proving that the existing Case-B predicate retains its
   one named diagonal coordinate and rejects a maximum in `theta_diag_B`;
4. a no-candidate fixture proving `b_fix` and `theta_rr_B` in Case C invoke no
   candidate/optimizer route and remain HOLD;
5. acceptance tests that preserve same `obj$fn`, `obj$gr`, parameter map,
   bounds, scale, controls, data, random effects, objective non-increase,
   positive-definite Hessian, named boundary, and raw \(10^{-3}\) gate;
   they must also retain an explicit `candidate_method` (`nlminb_retry` or
   `covariance_newton`) rather than treating both as the same unlabelled call;
6. a compiled-unit tier only for an already specified Case-B candidate, with
   raw/candidate gradients and provenance visible.  It cannot manufacture or
   test a Case-C candidate while `NO_CANDIDATE` is in force;
7. a static guard demonstrating that G2m's design-only files do not call
   `nlminb`, `TMB::MakeADFun`, `.gll_isdm_fit`, or `gllvmTMB()`.

If a future task proposes covariance-Newton beyond Case B, it additionally
needs adversarial rejection of non-symmetric, non-PD, ill-conditioned, or
dimname-misaligned covariance; any map/data/random/bounds/scale/control
mismatch; tied maximum-gradient coordinates; and changed boundary class.

## 6. Immutable provenance contract

Any later pre-run root must be fresh and bind the exact source SHA, the G2m
protocol and decision hashes, runner and test hashes, locked G2i fixture hash,
source-gate contract hash, parameter-map signature, raw/candidate decision
record, ordered `opt$par`, gradient and `cov.fixed` with dimnames and
conditioning, DLL/TMB/R versions, and a file manifest/final closure.  It must
preserve the raw fit even when a candidate is accepted.  Candidate status must
be one of
`NOT_REQUIRED`, `ACCEPTED`, `REJECTED`, `NO_CANDIDATE`, or
`INVALID_RULE_STATE`; missing/empty fields cannot be recoded as acceptance.
Every attempted candidate must also retain its `candidate_method`, acceptance
reason, and exact map/data/random/bounds/scale/control signatures.

The retained G2k campaign root is evidence-only: no G2k seed, ledger,
denominator, classification, or result file may be changed or reclassified.

## 7. Local pre-run decision gate

A local pre-run is **not approved by this protocol**.  It requires all of the
following in a separate approval:

1. implemented and reviewed prospective decision-table logic;
2. all seven validation requirements above pass, including compiled-unit
   validation for Case B and no-candidate protection for Case C;
3. an independent Gauss/Noether numerical review and Fisher claim review;
4. a fresh SHA-bound root and one new seed distinct from all G2k seeds;
5. a stated runtime estimate.  If the estimate exceeds 30 minutes, a measured
   pre-run plan and another explicit approval are required before the run;
6. no campaign, Totoro, FIR, DRAC, detection, public-surface, or promotion
   authority is inferred from local-pre-run approval.

## 8. Approval request

Approve only the next design/implementation slice if you accept that
`NOT_REQUIRED` is valid for Case A, the existing boundary polish stays
conditional in Case B, and Case C remains `NO_CANDIDATE`/HOLD until a future
estimator is separately specified and validated.
