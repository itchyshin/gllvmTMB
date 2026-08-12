# Paper 2 Case-C estimator/Psi information specification

**Status:** A2 preregistration.  It freezes what a later approved A3 may
measure; it authorizes no fit, implementation, simulation, profile, or compute.

## 1. Frozen private model and transform

For cell \(c\), species \(s\), and PA visit \(v\), retain the G2d law:

\[
z_c\sim N(0,1),\quad e_{cs}\sim N(0,\psi_s^2),\quad
\eta_{cs}=\alpha_s+x_c\beta_s+z_c\lambda_s+e_{cs},
\]
\[
Y^G_{cs}\sim\operatorname{Poisson}\{a_c^G
\exp(\eta_{cs}+\delta_s+b_c\gamma_s)\},\qquad
D_{csv}\sim\operatorname{Bernoulli}\{1-\exp[-a_c^S\exp(\eta_{cs})]\}.
\]

The estimator remains the private Laplace/TMB route with `nlminb`, no AGHQ,
no ridge, exactly three retained restarts, rank \(d=1\), and free maps for all
outer coordinates.  GBIF has one bias column \(b\); PA rows retain `NA` there
and never acquire a bias term.  The outer parameter blocks are
\((\alpha,\beta,\delta,\gamma)\) (`b_fix`, \(4S\) coordinates),
\(\theta_{rr,B}=\lambda\) (\(S\)), and
\(\theta_{diag,B}=\log\psi\) (\(S\)).  Thus
\(\widehat\psi_s=\exp(\widehat\theta_{diag,B,s})\),
\(\widehat\Psi=\operatorname{diag}(\widehat\psi_s^2)\), and
\(\widehat\Sigma_B=\widehat\Lambda\widehat\Lambda^T\); no alternative
parameterisation is admitted.

The DGP, support laws, source map, transforms, profiles, and recovery thresholds
are byte-for-byte successors of the G2d/G2n record.  At S = 6 the retained
Case-C reference is C = 360 cells, r = 3 PA visits, b = 1 GBIF-only bias
covariate, d = 1, N = (1+r)CS = 8,640 observations, and P = 6S = 36 outer
parameters.  The retained maximum raw gradient is 0.002726537 in `b_fix`, with
no named boundary; this is Case C / `NO_CANDIDATE`, not evidence for a repair.

## 2. Frozen numerical and recovery admission

Every attempt is retained, including errors, warnings, all three raw starts,
selected start, profile rows, maps, objective, gradient, Hessian status,
boundary flags, and known-truth metrics.  Eligibility requires finite objective,
optimizer code 0, finite gradient with \(\max|g|\le10^{-3}\), PD fixed Hessian,
and no boundary flag, plus six named `theta_diag_B` five-offset profiles with
finite converged values and both endpoint \(\Delta\mathrm{NLL}\ge2\).

Recovery metrics and thresholds remain: maximum absolute beta error <= 0.30;
maximum absolute GBIF-bias gamma error <= 0.30; minimum relative-map
correlation >= 0.70; shared covariance relative Frobenius error <= 0.50; and
maximum absolute diagonal-Psi variance error <= 0.20.  A successful attempt
must pass both the numerical and all five known-truth criteria.  All-attempt
denominators are mandatory; eligible-only summaries are descriptive.

The frozen Case-A through Case-D decision table remains in
`2026-08-12-g2n-numerical-admission-decision.md`.  This protocol adds no Case-C
candidate, does not relax a threshold, and does not reclassify G2n, G2k, or G2c.

## 3. Recovery information cells

The only proposed recovery species dimensions are S = 6, 20, and 60.  Each uses
C = 360, r = 3, b = 1, d = 1, N = 1,440S, P = 6S, and R = 20 ordinary,
seed-pinned replicates.  The existing G2d adversarial support attacks remain
separate retained failures/holds rather than substitutes for ordinary cells.

| S | C | r | b | d | N | P | R | Meaning |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| 6 | 360 | 3 | 1 | 1 | 8,640 | 36 | 20 | Exact retained-model recovery cell. |
| 20 | 360 | 3 | 1 | 1 | 28,800 | 120 | 20 | Same estimand; species dimension changes only. |
| 60 | 360 | 3 | 1 | 1 | 86,400 | 360 | 20 | Same estimand; species dimension changes only. |

No cell is approved to run by this specification.  Any future campaign must
first run a pre-run test, report its estimate, retain all attempts, and obtain
the required approval.

## 4. Measured implementation scale gates

S = 250 and S = 1,000 are one-fixture measured implementation gates, **not**
recovery cells and not scalability claims.  Both retain C = 360, r = 3, b = 1,
d = 1, N = 1,440S, P = 6S, and R = 1.  They record data/model-matrix build,
`MakeADFun`, first `fn+gr`, full fit, `sdreport`, and one fixed
`theta_diag_B` profile timing, each with wall time and peak RSS.  The profile
is one preselected coordinate and one predeclared offset grid; it cannot be
used as an interval or as a substitute for the six-coordinate recovery profile
contract.

| S | C | r | b | d | N | P | R | Wall budget | RAM budget |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |
| 250 | 360 | 3 | 1 | 1 | 360,000 | 1,500 | 1 | 60 min | 32 GiB |
| 1,000 | 360 | 3 | 1 | 1 | 1,440,000 | 6,000 | 1 | 8 h | 128 GiB |

A scale row passes only if every named stage is measured, the objective is
finite, optimizer code is 0, \(\max|g|<10^{-2}\), `pdHess` is true wherever
SEs are requested, and no boundary flags occur.  The S = 1,000 row additionally
requires empirical ratios
\(\mathrm{RSS}_{1000}/\mathrm{RSS}_{250}\le2\) and
\(t_{1000}/t_{250}\le2\), calculated separately for each named stage and for
the full measured workflow.  A budget overrun, missing stage, or failed
predicate is a HOLD; it is not repaired or rerun under this protocol.

S = 10,000 is an architecture HOLD.  It needs later explicit approval for a
matrix-free or block trait-separable fixed-effect representation, limited-memory
optimiser, sparse/block-Schur Laplace calculation, and selected/low-rank rather
than dense S-by-S output/inference before any measurement is proposed.

## 5. Non-claims and approval gate

This is neither a performance ranking nor support for spatial, count-survey,
empirical, absolute-abundance, generic-zero-inflation, arbitrary-source, or
10,000-species modelling.  It does not claim recovery, calibration, practical
scalability, or a public Paper 2 workflow.  A3 requires explicit approval
after the independent Gate-A review below.
