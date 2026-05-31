# DRAFT issue body -- DO NOT POST

**This file is a drafted body for the EXISTING umbrella issue #349**
(`[roadmap] Power-simulation capstone (power / accuracy / coverage)`,
milestone `power-study`). It is a *refinement* of that stub, not a new
issue. The maintainer reviews this and either (a) replaces/extends the
#349 body with it, or (b) posts the sub-slices below as children of #349.
Proposed labels for #349 and all sub-slices: `roadmap`, `simulation`.

DO NOT create a parallel umbrella issue -- #349 already exists.

---

## Body (proposed for #349)

Umbrella for the **end-of-road** power / accuracy / coverage study. Gated
on all other tracks (capabilities, functions, families, articles).
Pre-spec: **Design 66** (`docs/design/66-capstone-power-study.md`), an
ADEMP pre-registration (Morris et al. 2019). Board #340; feeder #346
(M3 coverage framework, CI-08/CI-10). Gate into CRAN + paper (#345).

**What is new vs the M3 grid (#346 / Design 42):** the M3 grid validates
*coverage* for a `family x d` slice on the rotation-invariant
`Sigma_unit_diag` estimand (gate fixed by PR #364). The capstone adds the
three axes M3 does not exercise:
1. **Power + Type-I error** (vary signal strength incl. a null level), not
   only coverage.
2. **The RE-structure axis** (phylo / spatial / animal x
   scalar/unique/indep/dep/latent/slope), the package's signature surface.
3. **n_sim sized for adjudication** (R=200 has coverage MCSE ~1.54 pp and
   cannot resolve the 94 % gate; floor = 2000, min defensible = 1000;
   Design 66 sec.7).

**Estimand discipline (non-negotiable):** rotation-INVARIANT targets only
-- `Sigma_unit_diag` + total off-diagonal correlation (and Gamma iff the
coevolution kernel is in scope). Raw `psi` / loadings are diagnostics. This
inherits PR #364, which fixed the CI-08/CI-10 confound (the 2026-05-19 run
gated on rotation-variant `psi`).

**Build = thin (reuse, do not reinvent):** the `dev/m3-grid.R` engine
already provides the DGP, cell runner, the `Sigma_unit_diag` bootstrap
gate, signal knobs (`lambda_scale`/`psi_scale`/`phi`/`n_units`/`d`),
convergence/PD-Hessian filtering, and RDS persistence. New surface is only:
a between-unit-`K` DGP extension, a signal-strength + null factor, a
power/Type-I decision rule, and a cluster array-job driver. **The engine
lane (R/fit-multi.R, R/brms-sugar.R, R/parse-multi-formula.R, src/*.cpp)
is untouched.**

**Compute:** embarrassingly parallel but NOT a GitHub Actions job (core
spoke design at n_sim=1000, n_boot=100 ~= 5e6 fits ~ 1 cluster-day on
~128 cores; full 192-cell x n_sim=2000 is multi-CPU-year). Stage Tier 0
first; GHA only for pilot + aggregation. See Design 66 sec.8.

### Proposed sub-slices (children of #349)

- **66.1 -- ADEMP pre-spec (THIS, write EARLY).** Design 66 lands +
  review. *Status: draft in flight.* Labels: `roadmap`, `simulation`.
- **66.2 -- DGP extension: between-unit `K` + signal-strength + null
  factor.** Extend `m3_make_truth()`/`m3_simulate_response()` to inject a
  phylo/spatial/animal between-unit covariance and a signal level
  (incl. 0). Test-first smoke (n_sim=10) asserting the null cell yields
  ~alpha rejections. Labels: `roadmap`, `simulation`.
- **66.3 -- Power / Type-I decision rule.** Add the "structure present"
  rejection rule + its MCSE to `m3_run_cell()` summary columns (the one
  genuinely new performance measure). Labels: `roadmap`, `simulation`.
- **66.4 -- Cluster array-job driver + dispatch.** Replace the GHA matrix
  with a cluster array job for production; keep GHA for pilot +
  aggregation. Labels: `roadmap`, `simulation`, `CI`.
- **66.5 -- Tier 0 core sweep + adjudication.** Run the agreed core grid
  at the agreed n_sim; adjudicate H1-H4. Labels: `roadmap`, `simulation`.
- **66.6 -- Tier 1-2 extensions (family completion + Gaussian slopes).**
  Gated on 66.5 passing. Feeds #348 (families) and #341 (slopes). Labels:
  `roadmap`, `simulation`.
- **66.7 -- Paper-ready report + register update.** Tables + power curves;
  move CI-08/CI-10 and exercised FAM-*/RE-*/ANI-* register rows. Gate into
  #345 (CRAN + paper). Labels: `roadmap`, `simulation`, `documentation`.

### Definition of Done

Core grid run at agreed n_sim/subset/compute with all six M3 quality gates
+ reported fit-exclusion rate; H1 (coverage>=94 %, MCSE<0.5 pp), H2
(|rel bias|<5 %), H3 (power curve per RE source), H4 (Type-I~=alpha) each
adjudicated; artefacts+seeds archived; register rows updated; paper-ready
report produced. (Design 66 sec.10.)

### Open questions blocking freeze (need maintainer decision)

- **Q-a:** HPC cluster available, or GHA-only? (whole budget branches here)
- **Q-b:** core = ~50-cell spoke fraction or full 192-cell cross?
- **Q-c:** exact headline claims; gate 94 % or strict 95 %?
- **Q-d:** n_sim final (floor 2000 / min defensible 1000)?
- **Q-e:** coevolution / Gamma (Design 65 / #361) in scope or deferred?
- **Q-f:** core 4-family subset or all 14 wired families (+nbinom1,
  +mixed)?
- **Q-g:** operational definition of "moderate"/"strong" signal per RE
  source.

(Full reasoning + MCSE tables + compute arithmetic in Design 66.)
