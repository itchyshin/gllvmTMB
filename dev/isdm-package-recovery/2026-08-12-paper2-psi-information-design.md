# Paper 2 Psi-information design: fixed recovery cells

**Status:** A3 design only; no fit, profile, simulation, implementation, or
compute is authorised.  This packet applies the ADEMP distinction between
estimands and performance measures (Morris, White & Crowther, 2019) to the
frozen Paper 2 cells.  It is not a causal experiment, a power calculation, or
an amendment to the G2 numerical or recovery contract.

`G2N_LOCAL_PRERUN_HOLD`, `G2K_CALIBRATION_HOLD`, and
`G2C_SMOKE_ADMISSION_HOLD` remain protected.  In particular, this design does
not turn the retained G2k pattern into a threshold change, a Case-C candidate,
or a reason to rerun a campaign.

## 1. Fixed object and aim

For cell (c), species (s), and visit (v), all future approved cells use
the A2/G2d model without alteration:

\[
z_c\sim N(0,1),\quad e_{cs}\sim N(0,\psi_s^2),\quad
\eta_{cs}=\alpha_s+x_c\beta_s+z_c\lambda_s+e_{cs},
\]
\[
Y^G_{cs}\sim\operatorname{Poisson}\{a_c^G
\exp(\eta_{cs}+\delta_s+b_c\gamma_s)\},\qquad
D_{csv}\sim\operatorname{Bernoulli}\{1-\exp[-a_c^S\exp(\eta_{cs})]\}.
\]

The estimator is exactly the private Laplace/TMB, three-start, rank-one
\(\Lambda\), free-diagonal \(\Psi\), `nlminb`, no-AGHQ, no-ridge route.  Its
outer coordinates and maps remain `b_fix`, `theta_rr_B`, and
`theta_diag_B`; the GBIF-only bias column remains absent (`NA`) from PA rows.
No candidate/retry/polish is admitted for a Case-C non-boundary residual in
`b_fix` or `theta_rr_B`.

The sole aim is descriptive and pre-registered: across the three fixed species
dimensions, measure whether the *unchanged* estimator's diagonal-Psi
calibration pattern is distinct from its numerical-admission pattern.  It must
not be described as the causal effect of species number, an identification
proof, or a comparison of estimators.

## 2. Cells, units, and estimands

The replicate is the unit of inference and reporting.  Species within a
replicate are correlated coordinates of one fitted multivariate model; they
are never treated as \(S\) independent simulations.

| Cell | C | r | b | d | N | P | R | Fixed meaning |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| S = 6 | 360 | 3 | 1 | 1 | 8,640 | 36 | 20 | Retained-model recovery cell. |
| S = 20 | 360 | 3 | 1 | 1 | 28,800 | 120 | 20 | Species dimension changes only. |
| S = 60 | 360 | 3 | 1 | 1 | 86,400 | 360 | 20 | Species dimension changes only. |

For replicate \(i\) in cell \(S\), define the diagonal target and estimate on
the frozen variance scale:

\[
\Psi_{ss}=\psi_s^2=\exp(2\theta_{\mathrm{diag},s}),\qquad
\widehat\Psi_{i,ss}=\exp(2\widehat\theta_{\mathrm{diag},i,s}),\qquad
E_{i,s}=\widehat\Psi_{i,ss}-\Psi_{i,ss}.
\]

The primary Psi estimand is the all-attempt probability

\[
p_{\Psi}(S)=\Pr\{\max_s |E_{i,s}|\leq0.20\},
\]

where an error, missing fitted coordinate, invalid transform, or absent ledger
is a failure, not an omitted value.  The pre-existing diagonal-Psi criterion
is therefore unchanged.  Secondary, descriptive Psi estimands are the
replicate-level maximum absolute error \(M_{\Psi,i}=\max_s|E_{i,s}|\), the
signed per-species errors \(E_{i,s}\), and the full within-replicate vector
\((E_{i,1},\ldots,E_{i,S})\).  The latter are reported as distributions within
each cell, not pooled across cells or promoted to species-level replication.

Numerical admission is a distinct joint indicator \(A_i(S)\): finite
objective; code 0; finite maximum raw gradient at most \(10^{-3}\); positive
definite fixed Hessian; no boundary flag; and six named, finite, converged
`theta_diag_B` five-offset profiles with both endpoint
\(\Delta\mathrm{NLL}\geq2\).  It is not replaced by a scaled gradient, a
covariance-scaled score, or a Psi recovery statistic.

The remaining fixed estimands are the all-attempt probabilities of the four
other known-truth criteria (beta, GBIF-bias gamma, relative map, and shared
covariance), their joint known-truth indicator \(K_i(S)\), and the strict
joint indicator \(J_i(S)=A_i(S)K_i(S)\).  All use their frozen A2 thresholds.

## 3. Mandatory all-attempt ledger and summaries

Before any run, a manifest must bind the independent seed block for each cell,
the exact code/DLL hashes, fixture hash, maps, transform, profile-offset grid,
and the `R = 20` requested starts.  A started replicate remains in that cell's
denominator.  There is no retry, replacement, cross-cell transfer, or
post-result candidate selection.

For every requested replicate, retain raw starts and selected start; objective;
raw and scaled gradient; optimiser code; Hessian/SE state; named boundary flags;
all six profile tables; maps; warnings/errors; the five recovery metrics;
\(\widehat\theta_{\rm rr}\), \(\widehat\theta_{\rm diag}\),
\(\widehat\Psi\); package/DLL/session provenance; and elapsed stage records.
An unavailable field is retained with its reason.  It is never converted to a
passing value, silently dropped, or filled with an arbitrary large error.

Each cell's report must contain, with denominator `20` printed on every
all-attempt proportion:

1. Counts and proportions for every atomic numerical predicate, the joint
   admission indicator \(A\), each of the five recovery criteria, \(K\), the
   Psi criterion, and \(J\), plus binomial MCSE
   \(\sqrt{\widehat p(1-\widehat p)/20}\).
2. The four-way all-attempt table \((A,\;I[M_\Psi\le0.20])\), including
   numerical-only, Psi-only, both-pass, and both-fail counts.  This is the
   primary separation display.
3. For all available diagnostic ledgers, the median, IQR, maximum, and missing
   count of \(M_\Psi\); signed per-species error table; profile lower/upper
   endpoint deltas; number of weak lower profiles; and loading--Psi local
   covariance/correlation diagnostics when retained.  Every such table names
   its available-ledger denominator separately from the all-attempt denominator.
4. A failure ledger by the first recorded state (fixture/runner failure,
   objective/optimiser/Hessian/gradient/profile/boundary failure, recovery
   failure, or complete pass), with raw error text retained.  Categories may be
   tabulated but may not overwrite the underlying multiple failures.

Conditional summaries such as \(\Pr(M_\Psi\le0.20\mid A=1)\) are permitted
only as labelled selection diagnostics with denominator \(\sum_i A_i\).
They are not primary recovery probabilities and are not comparable to an
all-attempt rate without displaying both denominators.

## 4. Predeclared contrasts and interpretation rules

The only across-cell contrasts are adjacent, all-attempt differences:

\[
\Delta_{20-6}^{q}=\widehat p_q(20)-\widehat p_q(6),\qquad
\Delta_{60-20}^{q}=\widehat p_q(60)-\widehat p_q(20),
\]

for \(q\in\{\Psi,A,K,J\}\), with the unpaired binomial MCSE
\(\sqrt{\mathrm{MCSE}(\widehat p_q(S_1))^2+
\mathrm{MCSE}(\widehat p_q(S_2))^2}\).  Report the same adjacent contrasts
for the available-ledger median \(M_\Psi\), but label them descriptive; no
null-hypothesis test, p-value, or post-hoc cutoff is authorised at \(R=20\).

Within a cell, report the predeclared association displays: the four-way
\((A,I[M_\Psi\le0.20])\) table; distribution of weak-profile counts by Psi
criterion status; and the loading--Psi diagnostic by Psi criterion status.
These displays ask whether the retained numerical and variance-partition
signals travel together.  They do not estimate the effect of passing the
optimiser gate on Psi recovery, or vice versa.

The required narrative has exactly three possible descriptive readings:

- a Psi pattern can be reported as **co-occurring with** numerical non-admission;
- it can be reported as **also occurring among** numerically admitted fits;
- or the cell can be reported as **inconclusive at R = 20**.

It may not say that a raw gradient causes a Psi error, that profile weakness
causes the allocation error, or that increasing \(S\) improves/worsens
information.  The latter changes both the number of trait outcomes and the
outer parameter dimension, so it is not a single-factor intervention.

## 5. What these cells can and cannot identify

If executed under a later approval, the cells can measure the realised
all-attempt frequency of frozen numerical and recovery states in their own
fixed DGPs; expose whether Psi failures occur only, mostly, or not at all with
numerical non-admission; and describe the finite-sample allocation pattern
between rank-one \(\Lambda\Lambda^\mathsf T\) and diagonal \(\Psi\).

They cannot identify a likelihood defect, prove a mechanism for a Psi miss,
separate Laplace approximation effects from finite-information effects,
calibrate a new threshold, validate a Case-C repair, establish an S-gradient or
scalability law, or support spatial, detection, count-survey, empirical,
absolute-abundance, generic-zero-inflation, arbitrary-source, or 10,000-species
claims.  In particular, a better or worse rate at a larger \(S\) is an
association across bundled design dimensions, not causal evidence about adding
species.

The evidence promotion rule remains conservative: any failed frozen numerical
or known-truth criterion is retained as a HOLD for that replicate; no
eligible-only result may substitute for the cell's all-attempt result.  A
future decision can use this design to diagnose, but cannot relax, repair, or
reclassify the locked contract without a new approved design and an independent
method review.

## References and retained evidence

- Morris TP, White IR, Crowther MJ (2019). Using simulation studies to
  evaluate statistical methods. *Statistics in Medicine* 38, 2074–2102.
- Williams DR, et al. (2024). Transparent reporting items for simulation
  studies evaluating statistical methods. *Methods in Ecology and Evolution*
  15, 1926–1939.
- Frozen model, thresholds, cells, and scale distinction:
  `2026-08-12-paper2-case-c-psi-information-specification.md`.
- Transform and retained six-species component-allocation evidence:
  `2026-08-11-g2j-psi-diagnostic-certificate.md`.
- All-attempt calibration and numerical/Psi interaction evidence:
  `2026-08-11-g2k-calibration-reconciliation.md` and
  `2026-08-12-g2k-gradient-diagnostic-certificate.md`.
- No-fit causal boundary and protected HOLDs:
  `2026-08-12-g2o-postmortem-certificate.md`.
