# GBIF effort recoverability-frontier campaign -- ADEMP design

**Status: DESIGN ONLY.  Nothing here authorises execution.**  The campaign
launches only after (i) maintainer approval of this design, and (ii) a pre-run
test on the target host whose results are shown and approved first (D-139).
Framework: **ADEMP** (Morris, White & Crowther 2019, *Stat. Med.* 38:2074-2102);
reporting against the 11 items of Williams et al. (2024, *MEE* 15:1926-1939).

**Downstream consumers.**  This lane exists so gllvmTMB can fit **integrated
JSDMs** -- in the maintainer's words (2026-08-15): *"it is our final prize and
data integration is where we are heading."*  Two empirical papers sit above it: the
GBIF-only global insect-gradients GLLVM analysis, and the North-American
integrated distribution model combining GBIF, literature, checklist, and
monitoring sources against one shared ecological process.  The synthetic
two-source fixture used here (structured PA + opportunistic GBIF, shared
ecological field, GBIF-only bias field) is the minimal instance of that
integrated model.  The campaign's product -- a recoverability frontier in
GBIF information -- is direct design guidance for both: *how much opportunistic
data per source must a cell-species design carry before source-specific fields
are identifiable?*

**Evidence base.**  The one-seed pilot
(`2026-08-15-paper1-gbif-effort-ladder-pilot.md`, commit `73ead7d9`): byte-exact
DGP reconstruction from the sealed V2 truth; collapse replicates at E=1
(||lambda_hat|| = 0.07 vs truth 16.15, pdHess FALSE); clean recovery by E=4-16
(cos 0.996, PD Hessian).  The frontier is bracketed in (1, 4]; this campaign
locates it with uncertainty.

---

## A -- Aims (Williams 1)

**Primary.**  Locate the GBIF-information recoverability frontier of the
two-source spatial iJSDM design -- the effort multiplier E* (equivalently,
expected GBIF detections N*) at which the GBIF-only spatial field becomes
identifiable -- with Monte Carlo uncertainty.

**Secondary.**  (S1) Quantify bias/RMSE of ||lambda_bias||, its direction, and
gamma as functions of E.  (S2) Estimate the rate of the sign-symmetry fixed
point (pdHess failure) as a function of E -- the operating characteristic of
the failure mode that consumed 24 estimator routes.  (S3) Quantify the
log-range bias (q_hat drift seen in the pilot; candidate cause: the
intercept-block range-amplitude ridge, corr -0.955).  (S4) Wald coverage of
lambda_bias and gamma where the Hessian is PD.

## D -- Data-generating mechanism (Williams 2)

The sealed generator (`paper1-matched-spde-fixture.R`), byte-validated today.
Stated as maths, levels explicit:

1. **Structure.**  Cells c = 1..360 on the frozen 20x18 unit-square grid;
   species s = 1..3; sources: 3 PA visits per cell-species + 1 GBIF row
   (4,320 rows).  Frozen design covariates x_c, b_c (drawn once by the sealed
   skeleton; part of the design, not redrawn).
2. **Random fields.**  Two independent Matern (nu=1) SPDE fields on the frozen
   118-node mesh: g_eco, g_bias ~ N(0, Q(kappa)^-1),
   Q = kappa^4 M0 + 2 kappa^2 M1 + M2, kappa = sqrt(8)/0.22.  Unit fields
   u = c_ref * A_unique g with c_ref = sqrt(4 pi) kappa.  Trait residuals
   eps_cs ~ N(0, psi_s^2).  **Redrawn every replicate** -- the campaign
   estimates a property of the design, not of one realisation (the pilot's
   fixed-realisation result stands separately).
3. **Linear predictors.**  eta^E_cs = alpha_s + x_c beta_s + u^eco_c v^eco_s +
   eps_cs;  GBIF adds b_c gamma_s + u^bias_c v^bias_s.
4. **Responses.**  PA: y ~ Bernoulli(1 - exp(-support * exp(eta^E)));
   GBIF: y ~ Poisson(E * support * exp(eta^E + b gamma + eta^bias)),
   support in {0.8, 2} frozen; the fitted offset carries log(E * support).
5. **Conditions varied.**  ONE factor:

   | factor | levels |
   | --- | --- |
   | GBIF effort E | 0.5, 1, 1.5, 2, 3, 4, 8, 16 |

   0.5 anchors the deep-collapse side; 1.5-3 resolve the pilot's (1, 4]
   bracket; 8 and 16 anchor the identified plateau.  Truth constants (beta,
   v_eco, v_bias, psi, kappa, gamma) frozen at the sealed values across all
   cells -- amplitude and geometry axes are deliberately out of scope (see
   Boundaries).
6. **Replicates.**  n_sim = 200 per level (1,600 fits).  MCSE justification:
   the headline pdHess-rate and coverage proportions carry
   MCSE = sqrt(p(1-p)/200) <= 3.5% (at p = 0.5), and <= 1.5% for coverage at
   0.95 -- sufficient to separate the pilot's observed 0-vs-100% rate contrast
   across adjacent levels by > 3 MCSE.  Continuous metrics ship sd/sqrt(200).

## E -- Estimands (Williams 3)

Truth is known per replicate from the DGP; stored with every row.

| estimand | true value | estimator output |
| --- | --- | --- |
| GBIF-field amplitude ||lambda_bias|| | 16.1478 (fixed) | sqrt(sum(theta_hat[20:22]^2)), sign-aligned |
| GBIF-field direction | v_bias/||v_bias|| | cos(theta_hat[20:22], lambda_bias) after sign alignment |
| bias coefficients gamma | (0.30, -0.20, 0.15) | theta_hat[10:12] |
| log range q | 2.5538 | theta_hat[16] |
| identifiability event | -- | pdHess(FD Hessian of exact gradient) |
| frontier E*_pd | -- | E at which smoothed P(pdHess) crosses 0.5 |
| frontier E*_rec | -- | E at which median relative amplitude error crosses 0.25 |

Both frontier definitions are **predeclared here**; neither may be revised
post-hoc.  Sign alignment (lambda_hat vs -lambda_hat by inner product with
truth) is the sealed sign-orbit convention, applied before any metric.

## M -- Methods (Williams 4)

**One estimator**: the shipped gllvmTMB Laplace objective, `MakeADFun` with the
sealed template (`parameters`, `map`, `random = c("s_B","g_spde_slope")`),
`nlminb` from the template start, exactly the pilot's procedure.  No comparator
arm: the campaign evaluates a design property of one estimator, not an
estimator contest.  Explicitly excluded (each would be its own designed study):
the sign-quotiented parameterisation (review 1b.2), AGHQ, VA, and any
consumed-route machinery.  Non-convergent or errored fits are **retained as
rows** with their status; never silently dropped (Williams 10b).

## P -- Performance measures (Williams 5)

Per level, each with its MCSE (Williams 11):

- bias and RMSE of ||lambda_hat||, gamma_s, q_hat: mean(x - truth),
  sqrt(mean((x - truth)^2)); MCSE sd/sqrt(n) (RMSE MCSE by delta method).
- median relative amplitude error, IQR.
- direction: mean cos, share cos > 0.95.
- **pdHess rate** and min-eigenvalue distribution (the S2 aim).
- Wald 95% coverage of lambda_bias components and gamma_s, computed on the
  pdHess subset, reported WITH the subset fraction (conditional coverage,
  labelled as such).
- convergence rate; wall time per fit.
- E*_pd and E*_rec by monotone (isotonic) interpolation across levels, with
  bootstrap CIs over replicates (B = 1000 resamples of the per-level fits).

## Logistics, compute, and provenance

- **Host: Totoro** (D-50: campaigns never on GitHub Actions).  <= 120 cores
  (D-143 cap 150), `OPENBLAS_NUM_THREADS=1` per worker.
- **Estimate (D-139).**  Pilot fit times 12-17 s on the Mac; budget 25 s/fit
  on Totoro => 1,600 x 25 s ~ 11 core-h => **~10-15 min wall at 100 workers**,
  plus one-time package build (~10 min) and I/O.  Total wall budget declared:
  **45 min**.  A run exceeding 2x its estimate stops and re-reports; it does
  not quietly continue.
- **Inputs bundle** exported from the sealed roots (read-only) to the campaign
  directory: truth constants, frozen skeleton covariates, M0/M1/M2, A_unique,
  sealed template (`parameters`, `map`, `random`), support vector.  The bundle
  ships with the MD5s of its source files.
- **Seeds.**  Master seed 20260815; replicate seed = master + 10000*level_index
  + rep, recorded per row.  Field draws and response draws use separate
  derived streams.
- **Output**: one RDS per fit (`results/frontier/E{level}/rep{r}.rds` under the
  gitignored results root), bound at collection; `sessionInfo()` saved beside
  the results (Williams 6).  Summary CSV + the analysis note are what get
  committed.
- **Layout**: `0_prepare_bundle.R -> 1_run_frontier.R -> 2_summarise_frontier.R`.

## Pre-run test (D-139 gate -- results shown BEFORE the campaign)

On Totoro: build the package, then run **one level (E = 2) x 3 seeds**.
PASS requires: 3 non-empty rows with finite theta, recorded timing within
2x the 25 s/fit budget, at least one row inspected past the guards
(`str()` of the full row), and the E=2 behaviour qualitatively between the
pilot's E=1 and E=4 outcomes.  FAIL on any of: empty/NA rows, invocation
error, timing blowout -- fix before any scale-up.  The pre-run result is
posted for approval; **the 1,600-fit campaign does not start until Shinichi
approves it against this design.**

## Kill rules (predeclared)

- Wall time > 2x estimate at any checkpoint: stop, re-report.
- > 5% errored fits in the first completed level: stop, diagnose.
- Any evidence the bundle drifted from the sealed MD5s: stop; nothing from
  that run is evidence.

## Boundaries -- what this campaign does NOT do

No claim about: other amplitudes or geometries (S/C axes frozen), the
empirical GBIF datasets themselves, the sign-quotient or any alternative
estimator, model admission for the consumed synthetic lineage, or Paper 2
inheritance.  It yields exactly: the frontier E* (both definitions, with CIs),
the operating curves of S1-S4, and design guidance for the two empirical
papers stated in expected-detections units.

## Williams et al. (2024) self-audit

| # | item | where |
| --- | --- | --- |
| 1 | aims | A |
| 2 | DGP incl. conditions + n_sim justification | D |
| 3 | estimands, replicate-level truth stored | E |
| 4 | methods + inclusion rationale | M |
| 5 | performance measures with formulas | P |
| 6 | software/versions recorded | sessionInfo per run; DLL + package MD5s in bundle |
| 7-8 | code availability | scripts committed in this directory; raw results gitignored, summary committed |
| 9 | worked case study | the two empirical papers are the case studies; pilot serves as the worked example meanwhile |
| 10 | full per-cell table incl. convergence; failures never dropped | P; M |
| 11 | MCSE on every aggregate | P; D6 |

**Next action if approved:** implement `0_prepare_bundle.R` + `1_run_frontier.R`,
ship to Totoro, run the pre-run test, and post its results for the launch
decision.
