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

---

## Amendment A1 (2026-08-15, post-campaign): the replication axis

**Trigger.**  The effort campaign measured E*_pd = 1.85 [1.43, 3.17] but found
the amplitude frontier unreached at every effort (median relative error 0.58
at E = 16; PD plateau ~0.68).  The standing diagnosis says spatial replication
is the binding constraint.  This amendment measures that axis.  Launch
pre-approved by the maintainer ("go -- launch the replication-axis campaign");
the pre-run smoke gate is retained as an internal stop condition.

**A1-D (DGP change -- surgical).**  Replication is varied by shrinking the
Matern practical range on the FROZEN 360-cell grid and 118-node mesh -- no new
geometry.  For range r: kappa(r) = sqrt(8)/r, c_ref(r) = sqrt(4 pi) kappa(r).
Because c_ref normalises the node field to ~unit marginal variance, the
predictor-scale truth (v_eco, v_bias, psi, beta, gamma) is IDENTICAL across
levels; only the estimand vector lambda(r) = c_ref(r) v and q(r) = log kappa(r)
rescale, both known exactly.  Factor table:

| r (range) | patches/side (unit domain) | kappa | q_true | ||lambda_bias(r)|| |
| --- | --- | --- | --- | --- |
| 0.22 (anchor) | 4.5 | 12.856 | 2.5538 | 16.148 |
| 0.165 | 6.1 | 17.141 | 2.8414 | 21.530 |
| 0.132 | 7.6 | 21.427 | 3.0646 | 26.913 |
| 0.11  | 9.1 | 25.712 | 3.2470 | 32.295 |

**Ceiling stated honestly:** mesh node spacing is ~0.11, so r = 0.11 is the
floor at which the SPDE representation remains marginally adequate; a stronger
push needs a denser mesh (new geometry -- the deferred robustness arm).  The
axis therefore spans a factor ~2 in patches/side (~4x in patches).

**A1 factors.**  r in {0.22, 0.165, 0.132, 0.11} x E in {1, 2, 4} (bracketing
E*_pd) x 200 seeds = **2,400 fits**, ~7 core-h at the measured ~10.5 s/fit,
~8-10 min wall at 120 workers.  Seeds: base = 20260816 + 100000*r_index +
10000*E_index + rep (a stream disjoint from the effort campaign's).

**A1-E/P.**  Estimands and metrics as in E/P above, computed against the
per-level truth lambda(r), q(r); relative amplitude error and direction cosine
are invariant to the c_ref rescaling by construction.  Primary readout: the
E*_pd crossing and median amplitude error **as functions of r** -- does the
frontier move with replication at fixed effort?  Same MCSE budget (200/cell).

**A1 validation gate (new fixture levels have no sealed reference).**  At the
anchor r = 0.22 the G1 byte gate applies unchanged.  At each new r the worker
must verify, before any fit: (i) chol succeeds on Q(r) built from the sealed
spde_M0/M1/M2; (ii) the unit-field marginal SD across nodes is within [0.8,
1.25] of 1 (the c_ref normalisation check; boundary nodes excluded is not
attempted -- the tolerance absorbs them); (iii) the per-level truth vector is
recomputed from constants, never transcribed.  Gate failure at any level
aborts that level, not the campaign.

**A1 kill rules.**  As the parent design, plus: if the anchor level's E in
{1, 2, 4} cells fail to reproduce the effort campaign's corresponding
pd-rates within 3 MCSE, stop -- the pipeline has drifted.

---

## Amendment A2 (2026-08-15, post-A1): the domain-growth axis

**Trigger.**  A1 REFUTED replication-via-finer-patches: on a fixed grid it
monotonically degrades identifiability, because per-patch information falls
exactly as patch count rises.  Domain growth -- more cells at FIXED range and
FIXED cell size -- raises patch count without diluting per-patch sampling, and
is the last surviving design lever.  Launch pre-approved by the maintainer
(the third-axis goal); the fit-cost scaling pre-run is the internal gate.

**A2-D (DGP).**  The sealed skeleton recipe, scaled: grid `n_lon = 20s`,
`n_lat = 18s` over `[0,s]^2`, cell size constant; covariates from the sealed
formulas (`x = scale(lon)`, `b = scale(sin 2 pi lat + 0.35 cos 2 pi lon)` --
note b's unit period repeats across larger domains, a stated design feature);
support sequences the sealed log-ramps over n_cell.  Mesh per level:
`make_mesh(cutoff = 0.085)` -- node DENSITY constant by construction.  Fields
per replicate from Q(kappa = sqrt(8)/0.22) on the level's mesh, scale
`c_use(s) = target_SD / sd_cell(s)` with the anchor's exact discrete target
(0.926998), so the predictor-scale truth is constant across levels (measured
truth ||lambda_bias(s)||: 16.148 / 16.551 / 16.644 / 16.516 -- within 3%).

| s | cells | mesh nodes | truth ||lambda_bias|| |
| --- | --- | --- | --- |
| 1 (anchor) | 360 | 118 | 16.148 |
| 1.5 | 810 | 254 | 16.551 |
| 2 | 1,440 | 444 | 16.644 |
| 2.5 | 2,250 | 681 | 16.516 |

**A2 construction gates, all PASSED at build.**  (i) **Anchor rebuild**: the
per-level builder goes through the sealed lineage's own developer entry
(`.gll_isdm_fit`), and rebuilding the anchor from the sealed `rows/X/B`
reproduced the sealed objective at the sealed theta to **5.5e-12**.  (ii) Row-map
gate per level: `tmb_data$y` bitwise-equals the skeleton's `value` column.
(iii) Discrete normalisation as in A1, exact (`sd_cell` 0.0198-0.0203 across
levels -- node density genuinely constant).

**A2 factors.**  s in {1, 1.5, 2, 2.5} x E in {1, 2} x 200 seeds = **1,600
fits**.  Seeds: base = 20260817 + 100000*s_index + 10000*E_index + rep
(disjoint from A0/A1 streams).  E capped at 2 because A1 showed E=4 adds
little discrimination near the frontier and the top level's fits are the
expensive ones.

**A2-E/P.**  As the parent design against per-level truth; primary readout:
pd_rate and median relative amplitude error **as functions of n_cell** at
fixed per-cell effort -- the N_cells frontier.  Anchor-consistency kill rule:
s=1 cells must reproduce the A1 anchor (E=1, E=2) within 3 MCSE.

**A2 pre-run (fit-cost scaling gate).**  Two fits per level at E=1 on Totoro,
timed; the campaign estimate and per-level chunking are set from those
timings before launch.  Declared wall budget: 45 min, kill at 2x.
