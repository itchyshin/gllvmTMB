# Design 66 -- Capstone power / accuracy / coverage simulation study

**Status:** APPROVED design contract (build contract). Pre-spec for the
end-of-road capstone (issue #349, milestone `power-study`). The seven open
questions of the original draft (former section 12) are now RESOLVED by
the maintainer; the locked plan is section 12. Compute is phased: Phase 1
is a local pilot at n_sim ~= 200 (this week, free local compute); Phase 2
is the core grid at n_sim = 2000 on HPC (later). The Phase-1 pilot is
driven by `dev/m3-pilot-launch.R` (a thin resumable driver over the
validated `dev/m3-grid.R` harness).

**Maintained by:** (to assign). **Reviewers:** Fisher (validation design),
Curie (DGP fixtures), Noether (identifiability), Rose (scope honesty),
Ada (coordinator).

**Parent issues / board:** umbrella #349 ("[roadmap] Power-simulation
capstone"); feeder #346 ("Simulation / coverage framework"); capability
board #340; live register `docs/design/35-validation-debt-register.md`.

**Parent designs:** Design 42 (M3 DGP grid -- the engine this reuses),
Design 48 (M3.4 boundary regimes -- the convergence/start machinery),
Design 50 (M3.3b surface admission -- target-explicit promotion gates),
Design 35 (validation-debt register -- rows CI-08, CI-10, FAM-*, RE-*,
ANI-*), Design 65 (cross-lineage coevolution kernel -- Gamma; scope
question in section 12).

**2026-06-23 scaling gate:** the current pilot is diagnostic only. Do
not launch a broad Totoro/DRAC campaign or promote `CI-08` / `CI-10`
until the pilot audit and metric-repair slices resolve the remaining
issues: pre-2026-06-24 binary logit-harness artifacts must not be read
as true `binomial_probit` evidence, ordinal-probit cells must produce
primary coverage rows or be excluded from the confirmatory core,
`signal = 0` diagnostics must not be described as Type-I error for
positive `Sigma_unit_diag` targets, and decision aggregates must report
MCSE with explicit fit-health denominators. The first compute step after that
audit is an immutable-chunk smoke ladder, not the full `n_sim = 2000`
grid.

**2026-07-13 amendment (maintainer, 0.5→0.6 gap-closure ultra-plan;
solo Claude).** The scaling gate is cleared for execution with these
locked decisions:

- **Confirmatory core for the 0.6 coverage certificate = `gaussian`,
  `nbinom2`, `binomial_probit`** (true-probit DGP/fit). **`ordinal_probit`
  is EXCLUDED from the confirmatory core** — this resolves the scaling
  gate's "ordinal-probit cells must produce primary coverage rows *or be
  excluded*" clause by exclusion. Ordinal stays point-only; a calibrated
  ordinal variance component is Bar-3 (AGHQ) work per Design 80, deferred
  to 1.0. `mixed` likewise stays out of the confirmatory core (CI-10).
- **Repair status (code-verified 2026-07-13):** #3 (signal=0 as
  zero-exclusion, not Type-I) DONE in `dev/m3-pilot-report.R`; #4 (MCSE +
  fit-health denominators) IMPLEMENTED in the report reducer
  (`pilot_collect_cell`, `pilot_binomial_mcse`) but NOT wired into the
  live decision surface (`run_next_pilot_batch` → `m3_summarise` →
  `pilot_status`) — **the campaign decision surface must read the report
  reducer**; #1 (logit-artifact quarantine) mechanism DONE (true-probit
  path + `evidence_family` labels), **campaign consumes true-probit runs
  only**; #2 resolved by the ordinal exclusion above.
- **Compute is SOLO CLAUDE on Totoro (≤100 cores), not GitHub Actions**
  (D-50): the `.github/workflows/m3-production-grid.yaml` dispatch pattern
  is a shape reference only — campaigns run on Totoro/DRAC, outputs stay
  local. Order: metric repairs → 48-cell pilot → immutable-chunk smoke
  ladder → pilot `PASS_TO_SCALE` gate → `n_sim = 2000` core grid.

Punch-list detail: `docs/dev-log/2026-07-13-A0-design66-scaling-gate-punchlist.md`.

**2026-07-15 EXECUTION RESULT (the campaign RAN — this supersedes the "gate blocks
the grid" framing above for status purposes).** The metric repairs, the n_sim=200
pilot (n_boot=100), and the **n_sim=2000 core grid** all ran on Totoro. Result
detail: `docs/dev-log/2026-07-13-A2-pilot-coverage-HOLD.md`; reconciliation +
next-arc handover: `docs/dev-log/handover/2026-07-17-claude-handover-capstone-reconciliation.md`.

- **Confirmatory core executed = `gaussian` + `binomial_probit`** (core-2). A gaussian
  DGP bug was found and fixed (0.54 → ~0.91). **`nbinom2` is FENCED** (excluded from the
  certificate core) as a documented weak-identifiability limit: the NB-dispersion(φ) ↔
  latent/unique-variance ridge under-recovers `Sigma_unit_diag` to ~0.5× truth, flat with n;
  the fix (`disp_group`, shared/grouped φ) is **deferred to 1.0**. `ordinal` stays excluded (Repair #2).
- **n_sim=2000 grid verdict = HOLD** (adjudication-grade, MCSE ~0.006): the nominal-0.95
  coverage certificate is **NOT earned** on the parametric-bootstrap route (gaussian ~0.91,
  binomial n=150 high-signal ~0.836–0.853 genuinely under-cover).
- **DECIDED conclusion:** the point estimate is near-unbiased (Σ̂/truth ≈ 1.007), so the
  under-coverage is the small-sample **variance-component right-skew**, and the parametric
  **bootstrap is the WRONG route** for this location-axis estimand. The certificate path is
  **profile likelihood / log-SD-Wald-with-t-df** (Design 73, nominal-certified in drmTMB) — NOT
  another bootstrap grid. **The real next coverage arc is a profile-route re-measurement of the
  same core cells.** CI-08 / CI-10 stay `partial`; no promotion without the D-43 adversarial panel.

**Backed by (verified on origin/main):** PR #364 (merged 2026-05-31,
`fix(m3): coverage gate keys on Sigma_unit_diag bootstrap, not psi
proxy`); PR #366 (merged 2026-05-31, RE-09 within-unit latent()+unique()
recovery test). The capstone reuses the `dev/m3-grid.R` engine and the
`.github/workflows/m3-production-grid.yaml` dispatch pattern.

---

## 0. Why this doc exists (and what it is not)

The capstone is the **final validation milestone** before CRAN + paper:
the large, pre-registered power/accuracy/coverage study that converts the
package's per-capability recovery tests into one defensible, paper-ready
evidence surface. Issue #349 is currently a one-line stub. This doc
turns that stub into an ADEMP pre-specification (Morris, White & Crowther
2019) so the headline claims are falsifiable, the grid is sized by Monte
Carlo arithmetic rather than convenience, and the compute budget is
costed before any cluster time is spent.

This is a **refinement of #349, not a parallel artefact.** The M3 grid
(Design 42) already validates *coverage* for a `family x d` slice at the
`psi`/`Sigma_unit_diag` estimand. The capstone is broader on three axes
the M3 grid does not currently exercise:

1. **Power and Type-I error**, not only coverage. M3 fixes a single
   signal level; the capstone varies signal strength to map a power
   curve and to estimate the false-positive rate when the structure is
   absent.
2. **The random-effect-structure axis.** M3 varies `family x d` only.
   The capstone must additionally vary the *between-unit structure*
   (phylo / spatial / animal x scalar/unique/indep/dep/latent/slope),
   which is the package's signature surface.
3. **n_sim sized for adjudication.** M3's R = 200 has a coverage MCSE of
   ~1.54 pp, which cannot distinguish a 94 % gate from 95 % nominal
   (section 7). The capstone raises n_sim to a defended floor.

What this doc is **not**: it is not a re-derivation of the DGP (that is
Design 42), not a new engine (the engine lane R/fit-multi.R,
R/brms-sugar.R, R/parse-multi-formula.R, src/*.cpp is untouched), and not
a coverage *re-run* of the existing `family x d` cells (those are tracked
by #346 / CI-08 / CI-10).

---

## 1. ADEMP at a glance

| ADEMP element | This study |
|---|---|
| **A**ims | Falsifiable claims (section 2) about coverage, bias, and power across the capability matrix. |
| **D**ata-generating mechanisms | Tiered factorial grid (section 4): family x RE-structure x source x d x n x signal x replication. |
| **E**stimands | Rotation-invariant targets (section 5): `Sigma_unit_diag`, total off-diagonal correlation; raw `psi`/loadings are diagnostic only. |
| **M**ethods | TMB Laplace ML; profile vs parametric-bootstrap CIs; convergence + PD-Hessian filtering (section 6). |
| **P**erformance measures | Coverage, bias, relative bias, empirical SE, RMSE, CI width, power, Type-I error -- each with an MCSE formula (section 7). |

The M3 grid is already reported in ADEMP terms (Design 42 sec.1) and
follows the transparent-reporting items of Williams et al. (2024, MEE);
the capstone inherits both conventions.

---

## 2. Aims -- the headline claims (falsifiable targets)

The capstone exists to support, or refute, the claims the paper and the
CRAN submission will make. Each is stated as a falsifiable target with a
pass/fail rule. The maintainer must confirm the exact claim set (section
12, Q-c) before the grid is frozen, because the grid must be sized to
support whichever gate is chosen.

**Claim H1 (coverage).** Across the core confirmatory grid, the 95 %
parametric-bootstrap CIs on the rotation-invariant estimand
`Sigma_unit_diag` attain empirical coverage >= 94 % (the audit-1 gate,
Design 42 sec.1; M3_PASS_GATE = 0.94 in `dev/m3-grid.R`). *Falsified* if
any core cell's coverage point estimate, with its MCSE, lies materially
below 0.94.

**Claim H2 (accuracy).** Across the core grid, the point estimator
recovers `Sigma_unit_diag` and the total off-diagonal correlation with
negligible relative bias (target |rel bias| < 5 %) and RMSE that shrinks
with n. *Falsified* if relative bias exceeds the threshold beyond MCSE in
any core cell.

**Claim H3 (power).** For each RE structure (phylo / spatial / animal),
gllvmTMB detects a present between-unit signal with documented power at a
realistic field-study n; the power curve is monotone in signal strength
and in n. The deliverable is the *curve*, not a single pass/fail -- the
paper reports the n and signal level at which power crosses, e.g., 0.80.

**Claim H4 (calibration of the null / Type-I error).** When the
between-unit structure is absent (signal = 0), the rejection rate of the
"structure present" decision is at or below the nominal alpha (target ~=
0.05 within MCSE). *Falsified* if the false-positive rate is materially
inflated.

**Current audit caveat (2026-06-23).** The existing pilot's
`signal = 0` cells should not yet be interpreted as H4 evidence for
`Sigma_unit_diag`, because total diagonal variance can remain positive
when the shared latent loading signal is absent. The Type-I target must
be a pre-specified structure-present decision, such as off-diagonal
correlation, a variance-share component, or another explicitly defined
null, before the metric is used in the capstone.

**Non-claims (state explicitly in the paper).** (i) We do not claim
asymptotic coverage at n = 10,000; the anchor is the moderate field-study
regime (Design 42 sec.2). (ii) We do not claim recovery of
rotation-variant loadings `Lambda` or raw `psi` as estimands -- those are
identified only up to rotation and are reported as diagnostics (section
5; EXT-09/EXT-14/EXT-15 carry rotation advisories). (iii) Power to detect
phylogenetic signal is fundamentally limited by the number of tips;
Boettiger, Coop & Ralph (2012, Evolution 66:2240) show likelihood
surfaces for OU/BM-type processes are often flat with few tips, so low
power at small n_species is an honest finding, not a defect.

---

## 3. Estimands (stated before Methods, on purpose)

The estimand choice is the single most consequential decision in this
study, and it is the one the package got wrong once already. The
2026-05-19 M3.3 production run gated on **profile CIs of per-trait `psi`**
(`theta_diag_B`), a *rotation-variant* proxy. 13/15 cells "failed" the
94 % gate (CI-08) and the mixed-family cells looked badly miscalibrated
(CI-10: d=1 0.820, d=2 0.685, d=3 0.550). PR #364 (merged 2026-05-31)
corrected this: the promotion gate now keys on `coverage_primary` /
`primary_gate_status`, evaluated on the **bootstrap CI of total
`Sigma_unit_diag`** -- the rotation-invariant estimand the coverage claim
is actually about. `psi` is retained only as a diagnostic
(`coverage_prof` / `profile_gate_status`) and for the binomial-`psi`=0
regression check.

**The capstone inherits PR #364's estimand discipline without exception.**

Primary estimands (rotation-invariant; the claims in section 2 are about
these):

- **`Sigma_unit_diag`** -- the diagonal of the implied between-unit trait
  covariance `Sigma_unit` (T x T). This is the canonical rotation-free
  target (Design 42 sec.1; constructed in `m3_make_truth()` in
  `dev/m3-grid.R`). Primary CI method: parametric bootstrap.
- **Total off-diagonal correlation of `Sigma_unit`** -- the cross-trait
  correlation structure (the "shared latent axis" signal). Surfaced via
  `extract_Sigma(level, part)` (EXT-01, rotation-invariant).
- **(Conditional) Gamma = Lambda_H Lambda_P^T** -- the host-trait x
  partner-trait coevolution block, *only if* the coevolution kernel
  (Design 65 / #361) is in scope for the capstone (section 12, Q-e).
  Default assumption in this draft: **deferred** to a follow-up, because
  the `kernel_*()` engine is not yet built on origin/main.

Diagnostic-only quantities (reported, never gated):

- raw `psi` (per-trait unique variance) -- rotation-variant proxy;
- raw loadings `Lambda` -- identified up to rotation (EXT-14);
- `sigma_eps` -- needs replicate structure to separate from unique-`psi`
  (RE-09; section 4.6).

**Rationale for stating estimands before methods:** Morris et al. (2019)
place E before M precisely so the target is fixed independently of what
the estimator finds convenient to report. The CI-08/CI-10 confound is the
textbook failure of doing it the other way round (the run profiled what
`theta_diag_B` made available, then discovered the claim was about a
different quantity).

---

## 4. Data-generating mechanisms -- the tiered grid

### 4.1 The infeasibility of full factorial

The capability surface (enumerated from `NAMESPACE` + the Design 35
register on origin/main) is:

- **Sources x modes (between-unit RE structure):**
  - phylo: scalar, unique, indep, dep, latent, slope, rr (`R/brms-sugar.R`)
  - spatial: scalar, unique, indep, dep, latent (slope via augmented form)
  - animal: scalar, unique, indep, dep, latent, slope (`R/animal-keyword.R`)
  - (`relmat` is realized via `phylo_*(vcv=)` / `animal_*(A=/Ainv=)` and is
    soft-deprecated toward `kernel_*()` per Design 65; not a separate live
    keyword family. `kernel_*()` is NOT built on origin/main -- #361.)
- **Families wired:** gaussian, poisson, nbinom2, binomial(logit/probit/
  cloglog), betabinomial, gamma, beta, lognormal, student-t, tweedie,
  ordinal_probit (register FAM-01..14 = covered). nbinom1 is fid 15,
  test-skip-gated / review-branch-wired (FAM-07). delta/hurdle = fixed-
  effect-only by design (FAM-17, Design 62) -- excluded from the RE grid.
- **Tiers:** unit / unit_obs / cluster (covered); cluster2 planned (#342).
- **Latent rank d:** 1, 2, 3.
- **n axes:** n_species/units, n_traits, observations.
- **Signal strength:** `lambda_scale`, `psi_scale`, `phi`, plus a phylo/
  spatial signal ratio.
- **Replication:** with / without within-cell replicates (RE-09).

A naive product is well over 10^4 cells before n_sim and bootstrap are
applied; at the per-fit cost in section 8 this is not affordable. The
study is therefore **tiered**: a small core confirmatory grid that *must*
pass to support the paper/CRAN claims, plus extension grids that are
nice-to-have and can be staged or dropped under budget pressure.

### 4.2 Tier 0 -- Core confirmatory grid (MUST pass)

The minimal grid that supports H1-H4. Design principle: vary one
"hard" axis at a time against a fixed, well-understood backbone rather
than crossing everything.

| Factor | Core levels | n |
|---|---|---|
| Family | gaussian, nbinom2, binomial(probit), ordinal_probit | 4 |
| RE source x mode | phylo_dep, spatial_dep, animal_dep, phylo_latent | 4 |
| Latent rank d | 1, 2 | 2 |
| n_species/units | 50, 150 (moderate field-study anchor; Design 42) | 2 |
| Signal strength | {absent (0), moderate, strong} | 3 |
| Replicates per unit | 1 vs >=2 (RE-09: required to separate sigma_eps) | included as a within-cell design property, not a cross factor |

Cross-product as written = 4 x 4 x 2 x 2 x 3 = **192 cells**. This is the
"everything crossed" reading and is itself near the budget ceiling at
n_sim = 1000+ (section 8). The recommended core is a **fractional**
slice (vary one hard axis at a time off a backbone): hold the backbone at
`gaussian, phylo_dep, d=1, n=150, moderate signal` and walk each factor
singly. That backbone-plus-spokes design is **~40-60 core cells**,
which is the affordable target. The exact fraction (full 192 vs the
~50-cell spoke design) is RESOLVED in section 12 L-b: the Phase-2
confirmatory grid is the core-4 cross; the Phase-1 PILOT is a bounded
48-cell subset (`pilot_grid()`).

Rationale for the level choices:

- **Families:** gaussian (baseline), nbinom2 (the hardest M3 cell --
  0.38 smoke coverage, Design 48; if it passes at scale the count path is
  trustworthy), binomial-probit (link-residual machinery, `psi`=0 invariant
  per PR #263), ordinal-probit (cutpoints). This is the representative
  subset; "all wired families" is the extension (section 4.3). Final
  family set is RESOLVED in section 12 L-f: the core 4 (gaussian,
  nbinom2, binomial(probit), ordinal_probit).
- **RE modes:** `*_dep` exercises the full between-unit correlated tier
  (the off-diagonal estimand); `phylo_latent` exercises the reduced-rank
  path. `scalar`/`unique`/`indep` are simpler and move to the extension.
  `slope` is the structured random-slope surface and is its own extension
  (section 4.4) because the engine guards non-Gaussian slopes to
  `gaussian()` (board #340 "Random slopes (non-Gaussian) -- deferred").
- **n_species 50/150:** brackets the Boettiger et al. (2012) low-power
  regime (n=50) and a comfortable regime (n=150) so H3's power curve has
  a visible rise.
- **Signal {0, moderate, strong}:** the 0 level is the signal-absent
  condition needed for the future H4 Type-I target, but the current
  Phase-1 `Sigma_unit_diag` pilot reports it only as a signal-zero
  coverage diagnostic. It is not a Type-I error estimate until a
  structure-detection rejection rule is specified.

### 4.3 Tier 1 -- Family-completion extension (nice-to-have)

Re-run the core RE/d/n/signal backbone across the remaining wired
families (gamma, beta, lognormal, student-t, tweedie, betabinomial,
poisson, binomial-logit/cloglog, mixed-family). Mixed-family is the
package's signature differentiator (Design 42) and is high-value but was
the worst-calibrated M3 cell (CI-10); include it if budget allows.
Approx **+80-150 cells** depending on how many families x how much of the
backbone. Feeds register FAM-* promotions and #348 (Family-validation
completion).

### 4.4 Tier 2 -- Structured random-slope extension (nice-to-have)

The Gaussian structured-slope surface is COMPLETE on the board
(#326/#327/#328: phylo/spatial/animal/relmat x unique/indep/dep/latent
all C, plus augmented correlated intercept+slope + SPDE). The capstone
slope extension validates *power + coverage* for slope-variance recovery
(`*_slope`, RE-02) at Gaussian only, since non-Gaussian slopes are
engine-deferred. Approx **+20-40 cells**. Feeds #341 (Random-slope
completion).

### 4.5 Tier 3 -- Coevolution / Gamma extension (DEFERRED by default)

If and only if the `kernel_*()` engine (Design 65 / #361) lands before
the capstone runs, add a coevolution grid with `Gamma` as estimand.
Default in this draft: **out of scope** (section 12, Q-e). Listed so the
grid schema reserves the slot.

### 4.6 Replication structure (do not skip)

RE-09 established that within-cell replicates are **required** to separate
the diagonal `Psi` tier from `sigma_eps` in the unit_obs / explicit-Psi
compatibility configuration (register RE-09; `test-mixed-response-unique-nongaussian.R`,
`test-tiers-*.R`). The core grid therefore treats "replicates per unit"
as a *design property of each cell* (>= 2 observations per unit where the
estimand requires the separation), not merely a free knob. Cells whose
estimand is unidentifiable without replicates must be generated with
them; this is a correctness constraint, not a power-tuning choice.

### 4.7 Seeds and reproducibility

Reuse the M3 seed discipline: a per-dispatch `seed_base` (distinct per
run to avoid collision, per the workflow input help) plus deterministic
per-cell/per-rep derivation inside `m3_run_cell()`. The Phase-1
accumulation driver writes a per-shard manifest before fitting. Each
manifest row records the source SHA, workflow run id/number, shard,
cell, current accumulated-store path, future immutable chunk path,
planned replicate count, batch seed base, and `rep_seed` range. The
persist/status path validates the merged manifest for duplicate output
paths, duplicate chunk paths, overlapping per-cell replicate windows,
and overlapping seed ranges before treating the store as auditable.
For future immutable-chunk array jobs, `--mode=chunk` runs the active
rows in a chunk manifest and writes one RDS per planned chunk, while
`--mode=chunk-audit` reads the written manifests and requires every
planned chunk file to exist and be non-empty before any aggregation
step proceeds. `--mode=chunk-aggregate` is the derived single-writer
step: it rereads the validated chunks, checks that each file's `rep`
values match the manifest window, rejects duplicate
`cell_id`/`rep`/`trait_id`/`target` rows, and writes per-cell aggregate
RDS files under `_chunk-aggregate/`. Effective per-cell seed blocks are
separated by a fixed stride larger than the intended batch size after
the harness family/d seed offset is applied, so same-run cells do not
share `rep_seed` values.

Persist the long per-replicate grid (`<cell-id>.rds`) and rebuild
`pilot-index.rds` as a derived cache from those per-cell files. The
manifest plus per-cell grids, not the shared index, are the audit trail
for every failed fit, seed, and CI (Williams et al. 2024 transparency
items; Design 42 sec.1). The first Totoro/DRAC smoke step is
manifest-only: `dev/power-pilot-smoke.sh` runs with
`SMOKE_STAGE=manifest`, or `dev/power-pilot-slurm-smoke.sh` writes and
optionally submits the same manifest-only smoke as a SLURM job. It
parses the fixed audit-mini grid, writes the manifest, validates unique
immutable chunk destinations, and exits before fitting. Before any real
SLURM submission, prepare the remote checkout on the login node with
`dev/power-pilot-drac-setup.sh`: it creates a version-pinned user R
library, installs this checkout into that library, and verifies
`library(gllvmTMB)`. The default library convention is project storage
when `$PROJECT` is set, otherwise a scratch smoke library when
`$SCRATCH` is set, with `$HOME/.local/R/<R version>` as the final
fallback. Scratch libraries are purgeable and are for smoke setup only;
private account and quota paths are deliberately not recorded in this
public design note.

---

## 5. Estimands -- see section 3

(Stated before Methods on purpose; not repeated here.)

---

## 6. Methods -- the estimator and the intervals

- **Estimator:** TMB Laplace-approximate marginal ML, as fitted by
  `gllvmTMB()` through `R/fit-multi.R` (untouched by this study). The
  reduced-rank loadings + structured between-unit covariance are the
  fitted objects; the estimands in section 3 are derived from them via
  the rotation-invariant extractors (EXT-01).
- **Interval methods:**
  - **Primary: parametric bootstrap** on total `Sigma_unit_diag` and the
    off-diagonal correlation. This is the M3 PRIMARY method (PR #364);
    `m3_target_method("Sigma_unit_diag", n_boot)` returns `"bootstrap"`
    when `n_boot > 0`. Bootstrap support is gated by
    `m3_bootstrap_supported(fit)`.
  - **Diagnostic: profile likelihood** on per-trait `psi`
    (`theta_diag_B`) -- reported, not gated (PR #364 demotion).
  - Wald / Fisher-z intervals exist for some family paths (register
    FAM-02, CI-10) and may be reported as a third diagnostic where
    cheap, but the gate is the bootstrap.
- **Convergence + identifiability filtering (reuse M3 machinery,
  Design 48):** each replicate records optimizer convergence,
  `median_max_gradient`, `sdreport_ok_rate`, `pd_hessian_rate`,
  `median_restart_count`, `boot_fail_rate`. The M3 stop/quality gates
  carry over verbatim:
  1. empirical coverage on `Sigma_unit_diag` >= 0.94;
  2. CI-missing rate <= 10 %;
  3. fit-failure rate <= 20 % (<= 30 % for mixed-family cells);
  4. bootstrap-failure rate <= the same family limit;
  5. no one-sided miss pattern (>= 80 % of misses on one side);
  6. `pilot_status == "PASS_TO_SCALE"` achieved at the pilot scale first.
  Replicates that fail to converge or lack a PD Hessian are excluded from
  the coverage numerator/denominator using the existing column logic, and
  the *exclusion rate is itself a reported performance measure* (a cell
  that only "passes" by discarding 40 % of fits is not a pass).
- **Start strategy:** `single_trait_warmup` is the M3 production default
  (Design 43/48); residual starts (McGillycuddy et al. 2025, JSS 112(1))
  and multi-start are available for the count cells that need them. The
  start policy is a *fixed method per family*, recorded per cell, not a
  per-replicate search that could bias coverage optimistically.

---

## 7. Performance measures and Monte Carlo SE (n_sim sizing)

Let n_sim be replicates per cell, p the true coverage, theta the
estimand, theta_hat the estimate, and emp_SD the empirical SD of
theta_hat across replicates. All measures and their MCSEs follow Morris
et al. (2019, Table 6).

| Measure | Estimator | Monte Carlo SE |
|---|---|---|
| Coverage | mean(CI contains theta) = p_hat | sqrt(p_hat(1 - p_hat) / n_sim) |
| Bias | mean(theta_hat) - theta | emp_SD / sqrt(n_sim) |
| Relative bias | (mean(theta_hat) - theta) / theta | (emp_SD / sqrt(n_sim)) / |theta| |
| Empirical SE | emp_SD | emp_SD / sqrt(2 (n_sim - 1)) |
| RMSE | sqrt(mean((theta_hat - theta)^2)) | (approx) involves 4th moment; report bootstrap MCSE |
| CI width | mean(upper - lower) | SD(width) / sqrt(n_sim) |
| Power | mean(reject H0 | signal present) = pow_hat | sqrt(pow_hat(1 - pow_hat) / n_sim) |
| Type-I error | mean(reject H0 | signal absent) = a_hat | sqrt(a_hat(1 - a_hat) / n_sim) |

### 7.1 Why R = 200 (the M3 pilot) is inadequate for the gate

Coverage MCSE at the worst case p = 0.95:

| n_sim | Coverage MCSE at p=0.95 | Can it adjudicate 94 % vs 95 % (1 pp gap)? |
|---|---|---|
| 200 (M3 pilot)  | sqrt(0.95*0.05/200)  = 0.0154 (1.54 pp) | No -- MCSE > the gap |
| 500             | sqrt(0.95*0.05/500)  = 0.0097 (0.97 pp) | Marginal |
| 1000            | sqrt(0.95*0.05/1000) = 0.0069 (0.69 pp) | Yes, with a ~0.7 pp margin |
| 2000            | sqrt(0.95*0.05/2000) = 0.0049 (0.49 pp) | Yes -- MCSE < half the gap |
| 5000            | sqrt(0.95*0.05/5000) = 0.0031 (0.31 pp) | Comfortable; usually unaffordable |

At R = 200 the coverage estimate's two-MCSE interval is +-3.1 pp -- it
cannot distinguish "94 % gate met" from "95 % nominal" from "92 % under-
covered". This is *exactly* why Design 42's own gate language is "nominal
up to Monte Carlo noise at R = 200": at the pilot scale the gate is a
smoke check, not an adjudication.

### 7.2 Recommended n_sim

- **Floor for gate adjudication: n_sim = 2000** per core cell (coverage
  MCSE 0.49 pp at p=0.95; resolves the 94/95 gap to within half the gap).
- **Minimum defensible: n_sim = 1000** per core cell (0.69 pp) if budget
  forces it -- acceptable for a binary pass/fail with an explicit ~0.7 pp
  margin, but state the looser MCSE in the paper.
- **Power cells:** at pow ~ 0.80, MCSE = sqrt(0.8*0.2/n_sim) -> 0.89 pp at
  n_sim = 2000, which resolves a power curve to ~+-1.8 pp (two MCSE) --
  ample for reporting the crossing point. Power does not need more than
  the coverage floor.
- **Extension tiers:** n_sim = 1000 is acceptable (these inform register
  promotions, not the headline CRAN gate).

The MCSE arithmetic gives the **floor**; the ceiling is the compute
budget (section 8). Final n_sim is Q-d.

---

## 8. Compute budget

Total model fits, primary (bootstrap) path:

    fits = cells x n_sim x (1 + n_boot)

The `+1` is the point fit; `n_boot` is the parametric-bootstrap refits per
replicate. Worked estimates (wall-clock uses a nominal mean fit time;
calibrate against `mean_runtime_s` from a pilot before committing):

| Scenario | cells | n_sim | n_boot | fits | at 2 s/fit | at 20 s/fit |
|---|---|---|---|---|---|---|
| Core, spoke design | 50  | 1000 | 100 | 5.05e6 | ~117 days(1 core) | ~3.2 yr(1 core) |
| Core, spoke design | 50  | 2000 | 100 | 1.01e7 | ~234 days(1core)  | ~6.4 yr(1core) |
| Core, full 192     | 192 | 2000 | 100 | 3.88e7 | ~2.5 yr(1 core)   | ~25 yr(1 core)  |

These are *single-core* figures to make the scale unmistakable: the
capstone is **embarrassingly parallel** but **not a GitHub Actions job**.
The M3 workflow already shards `family x d` into 4 shards x 5 max-parallel
on `ubuntu-latest` with a 120-min job cap; that is fine for R = 200 smoke
but cannot absorb 10^6-10^7 fits. Concretely, the core spoke design at
n_sim = 1000, n_boot = 100, 2 s/fit is ~117 single-core-days -> roughly a
day on ~128 cores, or a few days on a modest cluster allocation. The full
192-cell x n_sim = 2000 reading is a multi-CPU-year job and is only
realistic on HPC.

**Levers to cut the bill (in priority order):**

1. **Stage it:** run Tier 0 first; gate Tiers 1-3 on Tier 0 passing.
2. **Reduce n_boot:** bootstrap dominates the cost (the `(1+n_boot)`
   factor). The M3 production default is n_boot = 25; the capstone needs
   enough bootstrap reps for a stable interval but n_boot = 100 is a
   reasonable target and n_boot = 50 halves the bill versus 100. (The
   bootstrap-replication count trades against interval noise, *not*
   against the coverage MCSE, which is set by n_sim.)
3. **Fractional core (spoke vs full 192):** the single biggest lever.
4. **Family subset** (Q-f): 4 core families, not 14.

**Recommendation:** budget the core (Tier 0) explicitly, run it on a
cluster (or a large cloud spot allocation), and treat GHA only for the
*pilot* and for *aggregation/reporting*, not the production sweep. Whether
a cluster is available is Q-a -- the rest of the budget plan branches on
it.

---

## 9. Reuse of the M3 grid engine (build = thin)

The capstone is mostly *configuration*, because `dev/m3-grid.R` already
provides the pieces. Explicit reuse map (verified on origin/main):

| Capstone need | Existing M3 component | Gap to build |
|---|---|---|
| DGP / truth | `m3_make_truth()`, `m3_simulate_response()` | extend to phylo/spatial/animal between-unit structure (M3 currently builds the within-trait `Sigma_unit` truth; the RE-source axis needs a between-unit covariance `K` injected) |
| Cell runner | `m3_run_cell()` (targets, n_boot, seeds) | parametrize the RE source/mode + signal-strength axes |
| Estimands + gate | `coverage_primary` / `primary_gate_status` on `Sigma_unit_diag` bootstrap (PR #364) | add a target-aligned detection / false-positive decision rule (reject "structure present") -- the one genuinely new performance measure |
| Signal knobs | `--lambda-scale`, `--psi-scale`, `--phi`, `--n-units`, `--n-traits`, `--d` (precompute CLI) | wire a signal-strength factor (incl. the 0 / null level for H4) |
| Convergence filtering | `pd_hessian_rate`, `sdreport_ok_rate`, `boot_fail_rate`, restart cols | none (reuse) |
| Persistence | `*-grid.rds` + `*-summary.rds` writers | none (reuse) |
| Dispatch | `.github/workflows/m3-production-grid.yaml` (matrix shards) | replace GHA matrix with a cluster array job for production; keep GHA for pilot + aggregation |

The new code surface is: (a) a between-unit-`K` DGP extension, (b) a
signal-strength + null factor, (c) a target-aligned detection /
false-positive decision rule, (d) a
cluster array-job driver. None of it touches the engine lane.

**Build it test-first** (the repo's TDD discipline): a smoke at n_sim =
10 per new cell type that asserts the new axes wire through and the
null-signal cell produces ~alpha rejections, before any production sweep.

---

## 10. Definition of Done

The capstone is DONE when:

1. The core (Tier 0) grid has run at the agreed n_sim with the agreed
   family/RE subset, on the agreed compute, with all six M3 quality
   gates (section 6) satisfied *and* the fit-exclusion rate reported per
   cell.
2. H1 (coverage >= 94 % on `Sigma_unit_diag`, MCSE < 0.5 pp), H2
   (|rel bias| < 5 %), H3 (a power curve per RE source, monotone in n and
   signal), and H4 (Type-I ~= alpha) are each adjudicated -- supported or
   honestly reported as partial -- on the core grid.
3. The long per-replicate artefacts + seeds + failed-fit rows are
   archived (Williams et al. 2024 transparency).
4. The register rows are updated: CI-08 and CI-10 move from `partial`
   toward `covered` (or stay partial with the new evidence), and the
   exercised FAM-*/RE-*/ANI-* rows cite the capstone artefact.
5. A paper-ready report (tables + power curves) is produced.

CRAN + paper (milestone #3) gate on this being DONE; the capstone itself
gates on all other tracks being done (issue #349: "Gated on all other
tracks").

---

## 11. References (verified against repo usage where possible)

- Morris TP, White IR, Crowther MJ (2019). Using simulation studies to
  evaluate statistical methods. *Statistics in Medicine* 38:2074-2102.
  (ADEMP; MCSE table. Already cited in Design 42 sec.1.)
- Williams CJ et al. (2024). Reporting standards for simulation studies.
  *Methods in Ecology and Evolution*. (Transparent-reporting items;
  already cited in Design 42 sec.1.)  *[Exact author list / volume not
  re-verified here -- confirm at write-up; cited as used in Design 42.]*
- Burton A, Altman DG, Royston P, Holder RL (2006). The design of
  simulation studies in medical statistics. *Statistics in Medicine*
  25:4279-4292. (Design-of-simulation framing.)  *[Citation not verified
  against an external source in this draft -- confirm at write-up.]*
- Boettiger C, Coop G, Ralph P (2012). Is your phylogeny informative?
  Measuring the power of comparative methods. *Evolution* 66:2240-2251.
  (Tip-count limits on phylo power -- grounds the n_species axis and the
  H3 non-claim.)  *[Citation not verified against an external source in
  this draft -- confirm at write-up.]*
- Niku J, Hui FKC, Taskinen S, Warton DI (2019). gllvm: Fast analysis of
  multivariate abundance data. *Methods in Ecology and Evolution*
  10:2173-2182. (GLLVM reference method.)  *[Confirm at write-up.]*
- Warton DI et al. (2015). So many variables: joint modeling in
  community ecology. *Trends in Ecology & Evolution* 30:766-779.  *[Confirm
  at write-up.]*
- McGillycuddy M, Popovic G, Bolker BM, Warton DI (2025). Parsimoniously
  fitting large multivariate random effects in glmmTMB. *Journal of
  Statistical Software* 112(1). (Residual starts for reduced-rank fits;
  already cited in Design 48.)
- White IR (2010); Skrondal A (2000) -- performance-measure reporting in
  simulation studies. *[Named in the capstone brief; not independently
  verified here. Confirm at write-up.]*

**Verification note:** Morris (2019), Williams (2024), and McGillycuddy
(2025) are confirmed in use elsewhere in this repo's docs (Design 42, 48).
Burton (2006), Boettiger (2012), Niku (2019), Warton (2015), White (2010),
Skrondal (2000) are cited from the capstone brief and standard knowledge
and are flagged for verification at paper write-up; do not treat the
volume/page details as checked.

---

## 12. LOCKED PLAN (maintainer decisions -- supersedes the open questions)

The seven open questions of the original draft are RESOLVED. The plan
below is the build contract. Each item records the decision and its
direct consequence for the grid and the compute.

- **L-a (compute) -- PHASED, local pilot then HPC core (resolves Q-a +
  Q-d).** Phase 1 is a LOCAL pilot at `n_sim ~= 200` on the maintainer's
  Mac, run in bounded batches (free compute while the maintainer is
  away); it sizes wall-time and surfaces gross miscalibration / failure
  modes before any cluster time is spent. Phase 2 is the core grid at
  `n_sim = 2000` on HPC (MCSE 0.49 pp at p = 0.95; section 7.2 floor),
  run on the maintainer's return. The pilot is local-only and is NOT a
  GitHub Actions job. At `n_sim = 200` the coverage MCSE is ~1.54 pp
  (section 7.1) -- the pilot is a SMOKE/sizing instrument, not the gate
  adjudication; the 94/95 adjudication belongs to the n_sim = 2000 HPC
  Phase 2.
- **L-b (core grid) -- core-4 confirmatory grid; PILOT is a bounded
  subset (resolves Q-b).** The Phase-2 confirmatory grid is the core-4
  cross (section 4.2). The Phase-1 PILOT is a deliberately bounded
  enumeration of **48 cells**: core-4 family (4) x latent rank d {1, 2}
  (2) x n_units {50, 150} (2) x signal {0, 0.2, 0.5} (3) = 4 x 2 x 2 x 3
  = 48. This is "a few dozen" cells -- smaller than the full 192-cell
  core grid -- chosen so the pilot completes locally in bounded batches
  while still touching every family, both ranks, both n, and all three
  signal levels at least once. The exact pilot enumeration is the
  `pilot_grid()` data.frame in `dev/m3-pilot-launch.R`.
- **L-c (coverage gate) -- report BOTH 94% and 95%; size to the stricter
  95% (resolves Q-c).** CIs are constructed at 95% nominal
  (`ci_level = 0.95`). Both the 94% audit-1 gate (`M3_PASS_GATE`, the
  existing `passes_94pct_primary`) AND the stricter 95% gate are reported
  per cell. The n_sim FLOOR is sized to adjudicate the stricter 95% gate
  (this is why Phase 2 uses n_sim = 2000, section 7.2). `pilot_status()`
  reports both gates side by side.
- **L-d (n_sim) -- pilot ~= 200, core = 2000 (resolves Q-d; folded into
  L-a).** Pilot `n_sim ~= 200` (sizing only); core `n_sim = 2000` (gate
  adjudication at MCSE < 0.5 pp). The minimum-defensible 1000 is NOT
  used for the headline core grid.
- **L-e (coevolution / Gamma) -- DEFERRED (resolves Q-e).** Design 65 /
  #361 (`kernel_*()`, Gamma coevolution) is OUT of scope for this
  capstone. The `kernel_*()` engine is not built on origin/main; the
  Gamma estimand and the Tier-3 coevolution grid (section 4.5) are a
  follow-up study, not part of the core-4 confirmatory campaign. The
  grid schema reserves the slot but no Gamma cells are run here.
- **L-f (families) -- core 4 (resolves Q-f).** The confirmatory grid is
  the 4-family representative subset: gaussian, nbinom2,
  binomial(probit), ordinal_probit. All-14-families and mixed-family
  (CI-10) are the Tier-1 family-completion EXTENSION (section 4.3), not
  the core. nbinom1 (FAM-07) stays out (review-branch-wired).

  *Pilot harness note (binomial link).* The current `m3_run_cell`
  harness has a true `binomial_probit` path: the DGP uses `pnorm()` and
  the fit uses `stats::binomial(link = "probit")`. Older Phase-1 pilot
  artifacts, including the first fir scheduled smoke jobs recorded on
  2026-06-24, used the existing binary LOGIT harness behind
  `binomial_probit` cell IDs and saved
  `evidence_family = "binomial_logit_harness"` for traceability. Those
  older artifacts remain scheduler/plumbing evidence only and must not
  be reinterpreted as true binomial-probit validation evidence.

- **L-g (signal parametrization) -- between-unit variance share; levels
  0 / 0.2 / 0.5 (resolves Q-g).** "Signal" is operationalized as the
  **between-unit (latent) variance share of total latent variance**:
  `share = trace(Lambda Lambda^T) / (trace(Lambda Lambda^T) + trace(Psi))`
  per trait, in expectation. The three levels are **0.0 (signal-zero
  coverage diagnostic for the positive `Sigma_unit_diag` target, not
  Type-I error), 0.2 (moderate), 0.5 (strong)**. In the
  M3 DGP this maps to `lambda_scale` via
  `lambda_scale = sqrt( (s/(1-s)) / (d * 0.75) )` (derivation in
  `dev/m3-pilot-launch.R::pilot_signal_to_lambda_scale`), holding the
  share constant across d. The null (s = 0) collapses to a tiny
  `lambda_scale` floor (1e-6; the harness rejects `lambda_scale <= 0`),
  making `Lambda Lambda^T ~= 0` so the between-unit signal is effectively
  absent -- the H4 null cell. This gives the power curve an interpretable
  x-axis (a variance share, not an opaque loading scale).

### 12.1 Phase-1 pilot driver (build summary)

The pilot is driven by `dev/m3-pilot-launch.R`, a thin RESUMABLE driver
over `dev/m3-grid.R` (it reuses `m3_run_cell()` for the DGP/estimand/CI
machinery and `m3_summarise()` for per-cell coverage; it does NOT
reimplement any of it). Entry points:

- `pilot_grid()` -- the enumerated 48-cell core-4 pilot grid (L-b).
- `run_next_pilot_batch(k, n_sim = 200, results_dir)` -- runs the next
  `k` PENDING cells, writes each result to `<results_dir>/<cell-id>.rds`,
  updates an index RDS, and prints a one-line progress summary. Designed
  to be invoked in bounded batches (e.g. every ~2 h locally). It is
  idempotent (re-running skips done cells), failure-tolerant (a cell
  that errors is logged + marked failed + skipped, never crashing the
  batch), and ASCII-logging.
- `pilot_status(results_dir)` -- summarizes done / pending / failed and
  the preliminary 94%/95% coverage (signal > 0) plus the signal-zero
  coverage diagnostic (signal = 0) available so far. The signal-zero
  diagnostic is not a Type-I error or power claim for `Sigma_unit_diag`.
- `pilot_build_manifest()` / `pilot_assert_manifest()` -- record and
  validate the planned per-shard chunks before fitting. The manifest
  catches duplicate output paths, duplicate chunk paths, overlapping
  per-cell replicate windows, and overlapping seed ranges before the
  store is persisted or summarized.
- `pilot_audit_mini_cell_ids()` / `dev/power-pilot-run.R
  --mode=audit-mini` -- write a manifest-only four-cell smoke for
  gaussian, nbinom2, true `binomial_probit`, and ordinal-probit. It
  uses the moderate `d = 1`, `n_units = 50`, `signal = 0.2` row for
  each family, plans two chunk reps with `n_boot = 0` by default, and
  launches no fits. This is the audit-mini gate before broader local or
  DRAC volume; it is still smoke evidence until the corrected harness is
  rerun at the intended replication depth.
- `pilot_run_audit_mini_manifest()` / `dev/power-pilot-run.R
  --mode=audit-mini-run` -- run the same fixed four-cell manifest as
  immutable chunk outputs, with `n_boot = 0` by default. Use this only
  as a tiny local execution smoke after the manifest-only gate; it still
  does not mutate `pilot-index.rds`, submit DRAC/SLURM work, or start a
  production campaign.
- `dev/power-pilot-smoke.sh` -- wrap the audit-mini ladder in one
  shell entry point for humans and future job scripts. The default
  `SMOKE_STAGE=all` path runs a one-rep, no-bootstrap local/Totoro
  smoke through manifest, immutable chunk writing, chunk audit, chunk
  aggregation, and chunk-aggregate reporting. `SMOKE_STAGE=manifest` is
  the DRAC-login-safe step: it parses and validates the fixed four-cell
  manifest but launches no fits. Fit-running stages (`run` and `all`)
  are for local/Totoro or scheduled compute jobs, not DRAC login nodes.
  The wrapper sets `OMP_NUM_THREADS`, `OPENBLAS_NUM_THREADS`, and
  `MKL_NUM_THREADS` to 1 by default and still does not submit SLURM
  work, use GPUs, mutate `pilot-index.rds`, or start the production
  campaign.
- `dev/power-pilot-drac-setup.sh` -- login-node setup for the first
  DRAC/fir smoke checkout. It loads the selected R and Julia modules,
  creates a version-pinned user R library, installs the current checkout
  with Depends/Imports/LinkingTo dependencies, and verifies
  `gllvmTMB` is visible from `.libPaths()`. `DRAC_EXTRA_MODULES` carries
  cluster-specific system libraries such as udunits/GDAL/GEOS/PROJ when
  `fmesher`/`sf` need them. It submits no jobs and records no private
  allocation/account path in the repository.
- `dev/power-pilot-slurm-smoke.sh` -- write, validate, or submit a
  conservative SLURM wrapper around `dev/power-pilot-smoke.sh`. The
  default `SLURM_ACTION=test` calls `sbatch --test-only`; actual
  submission requires `SLURM_ACTION=submit`. The default
  `SLURM_STAGE=manifest` is the first DRAC-safe smoke and launches no
  fits. Fit-running stages such as `SLURM_STAGE=all` are only for
  scheduled compute jobs after the manifest smoke passes. The wrapper is
  CPU-only, loads R and Julia modules explicitly, prepends the prepared
  user R library, checks that `gllvmTMB` is installed before running the
  smoke, sets BLAS/OpenMP threads to one, and does not start the
  production `n_sim = 2000` campaign.

  Fir scheduled smoke evidence (2026-06-24, source
  `7c675dd33d58f4dfd633cacfbf05e62c0e168d61`) now covers the first two
  CPU-only scheduled fit steps after the manifest-only gate. Job
  `45626865` ran `SLURM_STAGE=all`, `N_SIM_STEP=1`, `N_SIM_CAP=1`,
  `N_BOOT=0` against
  `$SCRATCH/gllvmtmb-power-pilot-smoke-fit-nboot0-20260624T164759Z`;
  it completed with exit code 0, four active manifest rows, four chunk
  files, four aggregate files, and no `pilot-index.rds`. Job `45627388`
  repeated the same ladder with `N_BOOT=2` against
  `$SCRATCH/gllvmtmb-power-pilot-smoke-fit-nboot2-20260624T165402Z`;
  it also completed with exit code 0 and the same immutable artifact
  shape. This is reproducibility / scheduler plumbing evidence only:
  these jobs pre-date the true probit harness swap, so their
  `binomial_probit` cell remains labelled by `binomial_logit_harness`;
  the `N_BOOT=2` report flagged non-PD diagnostics for the binomial and
  nbinom2 cells, ordinal-probit still lacked a primary interval row, and
  `CI-08` / `CI-10` remain partial.
- `pilot_run_chunk_manifest()` / `dev/power-pilot-run.R --mode=chunk`
  -- run the active rows from a chunk manifest, reindex each chunk's
  `rep` column into the planned per-cell window, add chunk provenance
  fields, and write one immutable RDS file per planned chunk. This is
  the future array-task writer; it does not update `pilot-index.rds` or
  combine chunks.
- `pilot_assert_chunk_outputs()` / `dev/power-pilot-run.R
  --mode=chunk-audit` -- validate the future immutable-chunk output
  set after array tasks finish and before aggregation. This requires
  every planned active chunk file to exist and be non-empty; it does
  not launch fits and does not replace the current accumulated-store
  driver.
- `pilot_collect_chunk_aggregates()` / `dev/m3-pilot-report.R
  --emit-issues --chunk-aggregate` -- read the per-cell RDS files
  written under `_chunk-aggregate/` after immutable chunks have been
  validated and aggregated. This is an explicit report source, not an
  automatic scan, so legacy accumulated stores and derived chunk
  aggregates cannot be double-counted by accident. It reuses the same
  MCSE, denominator, fit-health, and evidence-label reducer as
  `pilot_collect()`, and still does not mutate `pilot-index.rds`.
- For manifest-only compute smoke tests, `dev/power-pilot-run.R
  --mode=preflight --output-mode=chunk` validates the future immutable
  chunk destinations without launching fits.

Phase 2 (HPC, n_sim = 2000, the full core grid)
reuses the same harness with a cluster array-job driver (section 9); the
pilot driver and its results directory are the bridge.
