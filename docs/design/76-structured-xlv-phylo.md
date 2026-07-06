# Design 76 -- Structured x X_lv (phylo_* first): Predictor-Informed Latent Betas Under Phylogeny

Date: 2026-07-06

Owners (persona lenses for this sign-off): **Noether** (math-vs-implementation
consistency), **Fisher** (identifiability and inference), **Curie** (simulation
recovery / ADEMP). Row-owners on promotion: **Boole** (parser), **Gauss** (TMB
likelihood), **Rose** (scope audit), **Shannon** (cross-team coordination).

**Status: DESIGN SIGN-OFF ONLY. No engine code, no likelihood change, no
grammar exposure is authorized by this document.** The target grammar
`phylo_*(..., lv = ~ x)` is currently **fail-loud by design** (Section 3) and
the arc is **PARKED / authorization-gated** on the mission-control board
(`docs/dev-log/dashboard/status.json`, `lv_arc` rows "GLLVM.jl phylo Model A"
and "gllvmTMB phylo grammar/bridge", both `blocked`; validation-debt row
`LV-07`, `blocked`). This is a **HIGH-RISK likelihood change** and its correct
next step is a maintainer authorization decision (Section 7), not
implementation.

This document is the pre-implementation target map that Design 73 requires of
any structured-source `lv` extension, and that AGENTS.md Design rule 5 requires
of any new variance-share axis (simulation recovery on a known DGP + design-doc
updates before the axis is added). It reconciles the frozen GLLVM.jl phylo
Model A evidence, states precisely what that evidence does and does not
license, and lays out the ADEMP recovery/coverage gate that a Gaussian
`phylo_*(..., lv = ~ x)` implementation would have to clear.

---

## 1. Purpose -- the biological question first

A comparative-methods user has one row unit per species (or one row per
`(species, trait)` in long format) and several traits per species. Ordinary
`latent()` already lets predictors inform the shared latent axes:
`z_i = M_i alpha + e_i`, with the trait-scale effect `B_lv = Lambda alpha^T`
(Design 73). The phylogenetic tier already lets the *unstructured* latent
innovation carry phylogenetic covariance: `g_phy ~ MVN(0, Sigma_phy (x) A)`,
`Sigma_phy = Lambda_phy Lambda_phy^T + Psi_phy`
(`docs/design/03-phylogenetic-gllvm.md`).

The headline want (maintainer, 2026-06-27; recorded in the mission-control
`source` field of `docs/dev-log/dashboard/status.json` and in the maintainer
research context) is the **combination of the two**: predictor-informed latent
betas whose *innovation* is phylogenetically structured. The biological
question is:

> After accounting for shared phylogenetic history among species, do measured
> predictors (environment, life-history, treatment) explain where species sit
> on the shared latent ecological axes -- and what is the trait-scale effect
> `B_lv` of those predictors, with honest uncertainty?

Concretely, the grammar target is

```r
phylo_latent(0 + trait | species, d = K, lv = ~ x)
```

meaning: a reduced-rank latent block over species with a **phylogenetic**
score innovation `e_species ~ MVN(0, A)` per axis (rather than
`e_i ~ N(0, I_K)`), whose axis mean is `M_species alpha`, and whose reported
public estimand remains the trait-scale `B_lv = Lambda alpha^T`. This is
predictor-informed constrained/concurrent ordination *conditioned on the
phylogeny*.

This is distinct from -- and must not be conflated with -- the following, which
are separate arcs with their own derivations:

- `phylo_slope()` / `phylo_dep(1 + x | sp)` augmented random-**slope** models,
  which put covariates on the random-effect design, not on the latent-axis
  mean (already covered for Gaussian and several non-Gaussian families:
  register `PHY-11..PHY-18`). Design rule 5's own note is that `phy` is a
  variance-share shortcut, not a peer grouping level; structured `X_lv` is a
  *mean* model on the latent axis, a third thing again.
- Phylogenetic location-scale models for trait mean and variance
  (Nakagawa, Mizuno et al. 2025), which are explicitly **out of scope** for
  `gllvmTMB` (`docs/design/04-sister-package-scope.md`, "What `gllvmTMB` does
  NOT do": "Current `gllvmTMB` phylogenetic rows are covariance models across
  stacked traits / units, not predictor-dependent phylogenetic scale models").

---

## 2. What the frozen GLLVM.jl Gate 0-3 B_eta_realized evidence licenses -- and does NOT

The Julia twin `GLLVM.jl` ran a multi-gate diagnostic campaign on a phylo
Model A route. This section is the scrupulous accounting. **The short version:
the frozen evidence is diagnostic / non-v1 evidence for a REVISED
`eta`-scale target on the Julia side. It is NOT public source-specific R
support, it does NOT license grammar exposure, and it does NOT license
inheriting Gaussian evidence into non-Gaussian or broader structural models.**

### 2.1 The target was revised: population-`B_lv` was RETIRED; `B_eta_realized` is the survivor

The **original** population-`B_lv` target and its bootstrap/Wald/percentile
rescue routes were **retired with negative evidence** (all from
`docs/dev-log/dashboard/status.json`, `truth_cards` "Coverage gap" /
"Phylo DRAC coverage" and `active_work`/`blockers`):

- `bootstrap_basic` at p=80, K=2, lambda=0.5: **591/720 = 0.821** entry
  coverage on valid observed rows; even granting the cancelled task a perfect
  denominator reaches only **671/800 = 0.839**. Not a rescue route.
- Local seed-matched task-8 entry-71 `profile_truth` canary **missed truth**:
  **LR 9.9918 > 3.8415** (`chi^2_{1,0.95}`).
- K=1 20-replicate `profile_truth` covered only **98/100** selected entries
  (converged misses task 15 entry 10, task 19 entry 20).
- `profile_direct_slope` strict K=1 no-miss gate failed at **96/100**
  (misses at four converged entries).

The maintainer/council decision that followed
(`active_work` "Phylo Model A v1 parking", 2026-06-30) is explicit: **public
source-specific phylo lv is retired/parked for v1**, `PR #127` stays
closed/parked, and `phylo_latent(..., lv = ~ x)` stays fail-loud. Any restart
"must authorize a changed realized/sampling-conditional target with a fresh
ADEMP gate."

The **restart candidate** that cleared its gates is a *different, revised*
estimand: `B_eta_realized`, a realized / design-conditional **`eta`-scale**
target (not the population trait-scale `B_lv`). The `active_work`
"Phylo Model A next target" row states the only candidate restart was
"`eta`-scale realized `B_eta_realized` with selected-entry profile-LR". The
retirement/revision distinction is the single most important honesty point in
this document.

### 2.2 What `B_eta_realized` actually cleared (Gates 0-3)

All figures from `docs/dev-log/dashboard/status.json` (`active_work` Gate
rows, `phases` LV-4, `truth_cards` "Coverage gap"). Each gate is
**diagnostic evidence for the revised `eta`-scale target only**:

| Gate | Where | Result | Boundary wording (verbatim from status.json) |
|---|---|---|---|
| Gate 0 | GLLVM.jl local | truth helper + orientation unit test 7/7, one tiny `profile_eta_realized` smoke LR 0.4156 < 3.8415 | implemented locally; not a full-suite-green claim |
| Gate 1 (original) | GLLVM.jl local | **failed** strict no-miss: 84/100 planned covered | superseded |
| Gate 1 (corrected) | GLLVM.jl local, budgets 1000 | 20/20 fits, 100/100 usable, **97/100** covered, MCSE 0.0171, Wilson 95% 0.915481-0.989745; 3 real LR misses remain (tasks 7/8/11) | "The original no-miss rule still fails" |
| Gate 2 | Totoro, GLLVM.jl commit 41a4120 | 20/20 fits, 100/100 usable, **100/100 covered**, Wilson 95% 0.9630-1.0000, max LR 2.6733 < 3.8415 | "Gate 2 is diagnostic evidence only, not public source-specific support" |
| Gate 3 | DRAC Nibi job **17049809_[1-500%100]** | 500/500 fits, 2500/2500 usable, **2495/2500 = 0.998 covered**, MCSE 0.000890835, Wilson 95% 0.995326484-0.999145426, 5 LR misses, 0 non-empty error logs | "This is DRAC-only evidence for the non-v1 `B_eta_realized` target; source-specific R grammar, PR #127 reopening, and public support wording still require explicit maintainer authorization" |

### 2.3 The four hard limits on that evidence

1. **Wrong scale for the public estimand.** The gate coverage is for
   `B_eta_realized` (a realized `eta`-scale / design-conditional target). The
   public estimand this arc would ultimately advertise is the trait-scale
   `B_lv = Lambda alpha^T` (Design 73's non-negotiable estimand). Coverage of a
   realized `eta`-scale quantity is not coverage of the population trait-scale
   `B_lv`; the population-`B_lv` route is exactly what was retired (2.1).
2. **Diagnostic, not v1 / not public.** Every gate row and the
   `claim_guard` in status.json label this "diagnostic evidence only, not
   public source-specific support" and "DRAC-only evidence for the non-v1
   target". No capability may be promoted from it.
3. **No R side, no grammar.** All of this is `GLLVM.jl` (Julia). The gllvmTMB R
   grammar `phylo_*(..., lv = ~ x)` remains fail-loud (Section 3). `PR #127`
   (GLLVM.jl) is **closed/parked** (title
   "[BLOCKED] phylo Model A X_lv interval gate -- parked pending redesign",
   closed 2026-06-30T22:27:16Z), and the GLLVM.jl v1 capability matrix directs:
   "**Do not reopen PR #127 from this arc**"
   (`GLLVM.jl/docs/dev-log/v1-contract/r-julia-v1-capability-matrix.md`). The
   same matrix states the gate evidence "exists for changed `B_eta_realized`,
   **not public grammar**", and source-specific structural `B_lv` intervals are
   `blocked` "without explicit maintainer authorization".
4. **No inheritance.** The `serial_gates` "before non-Gaussian/source-specific
   expansion" entry (owner Fisher + Curie + Rose, `blocked`) is explicit: "Do
   not inherit Gaussian Gate 3 evidence into non-Gaussian or broader structural
   models. Each family/source combination needs a named estimand, derivation,
   ADEMP gate, and claim audit." The Gaussian phylo evidence buys the Gaussian
   phylo cell only, and only on the revised target, and only on the Julia side.

**Net license:** the frozen evidence licenses *continued private Julia
diagnostic work on the revised `B_eta_realized` target* and *nothing on the R
public surface*. It is a proof-of-life that a realized-target profile route can
be calibrated at DRAC scale for the Gaussian phylo cell -- useful de-risking
for the design below, not a capability.

---

## 3. The R grammar target `phylo_*(..., lv = ~ x)`: current fail-loud behavior and what a change entails

### 3.1 Current behavior: fail-loud BY DESIGN

Two guards make `phylo_*(..., lv = ~ x)` (and every other source-specific
`lv`) abort before fitting. Both are confirmed in source, not merely docs:

- **Source-specific keyword guard** (the PR #573 boundary). In
  `R/brms-sugar.R` (approx. lines 2195-2227), `.abort_unsupported_lv_keyword()`
  rejects `lv = ~ x` on any non-ordinary source keyword. The rejected-keyword
  list explicitly includes `phylo`, `phylo_scalar`, `phylo_unique`,
  `phylo_indep`, `phylo_latent`, `phylo_dep`, `phylo_rr`, `phylo_slope`, the
  `spatial_*` / `spde` set, the `animal_*` set, and the `kernel_*` set. Error
  text (verbatim): "`lv` is reserved for ordinary `latent` only. ... does not
  support predictor-informed latent-score means. ... Design 73 C1 is limited to
  ordinary unit-tier `latent(..., lv = ~ x)`; only Gaussian and pure binomial
  logit/probit/cloglog fits are admitted. ... Remove `lv` ... until validation
  row `LV-07` moves." (register `FG-18`, `LV-07`; status.json
  "Source-specific lv grammar guard").
- **Native non-Gaussian family guard** (the PR #577 boundary). In
  `R/lv-predictor.R` (approx. lines 119-128),
  `gll_prepare_lv_predictor_setup()` rejects any row outside Gaussian or pure
  binomial standard-link: "`lv` currently admits only Gaussian and pure
  binomial fits with standard links. ... Other non-Gaussian predictor-informed
  latent scores remain blocked under `LV-05`." (register `LV-05`; status.json
  "Native non-Gaussian guard").

These are **fail-loud boundaries, not partial support**. The design intent
(Design 73 tier grammar table) is that `phylo_latent(..., lv = ~ x)` is
"Reject as planned" until its own derivation and evidence land.

### 3.2 What a parser + TMB change would entail (scope of the HIGH-RISK change)

Reaching a Gaussian `phylo_latent(0 + trait | species, d = K, lv = ~ x)` fit
would require, at minimum:

- **Parser (Boole).** Remove `phylo_latent` from the
  `.abort_unsupported_lv_keyword()` reject list *for the Gaussian path only*;
  store `extra$lv_formula` on the phylo reduced-rank term; build the
  species-level `M_species` (`X_lv_phy`) design; keep the auto-added
  `Psi_phy` companion free of `lv` metadata; preserve every *other*
  source-specific and non-Gaussian rejection. This is a **formula-grammar
  change** -- a Discussion-Checkpoint / high-risk item per `ROADMAP.md` and
  CLAUDE.md merge authority.
- **TMB (Gauss).** This is the **likelihood change**. The ordinary path uses
  the score innovation prior `z_B ~ N(0, I)`; the phylo path must instead
  give the axis innovation the phylogenetic prior. In the notation of
  `docs/design/03-phylogenetic-gllvm.md`, the per-axis innovation over species
  becomes `e_{.,k} ~ MVN(0, A)` (sparse `A^{-1}` via the Hadfield-Nakagawa
  route, `PHY-01`), with the axis mean `M_species alpha` added before the
  loading map:

  ```cpp
  // ordinary (Design 73):        score_k = z_B(k,s) + sum_h X_lv_B(s,h)*alpha_lv_B(h,k);
  // phylo structured X_lv target: score_k = e_phy(k,s) + sum_h X_lv_phy(s,h)*alpha_lv_phy(h,k);
  //                               with e_phy(.,k) ~ MVN(0, A)  [sparse A^{-1} GMRF prior]
  eta(o) += sum_k Lambda_phy(t,k) * score_k;
  ```

  and `ADREPORT(B_lv_phy = Lambda_phy %*% t(alpha_lv_phy))`.
- **Identifiability review (Fisher / Noether).** The interaction of
  `Lambda_phy Lambda_phy^T + Psi_phy` (the phylo covariance decomposition) with
  a predictor-informed axis mean must be checked for the same rotation and
  Psi-vs-loading identifiability issues that motivate Design 73's
  "recovery targets must be rotation-invariant" rule, now compounded by the
  phylogenetic prior.

Because this changes both the **formula grammar** and the **likelihood /
TMB template**, it sits squarely in the high-risk set (CLAUDE.md "Merge
authority"; `ROADMAP.md` Discussion Checkpoints). It **requires explicit
maintainer authorization and Gauss/Noether sign-off** before any code, and it
requires the ADEMP gate in Section 5 to pass before any public wording.

---

## 4. Symbolic <-> R syntax <-> TMB implementation alignment

Per the add-simulation-test / symbolic-alignment discipline, the target model
for `B_lv` under a phylogenetic latent covariance `Sigma_phylo` is specified as
a 5-row alignment table. **This is the target contract for a future
implementation; no row is implemented today** (every row's current runtime
behavior is "fail-loud", Section 3).

Conventions: `t` indexes trait, `k` indexes latent axis (`k = 1..K`), `s`
indexes species (the grouping level of `phylo_latent`), `h` indexes columns of
the `lv` design. `A` is the phylogenetic correlation matrix (sparse `A^{-1}`
from the tree, `PHY-01`).

| # | Object | Symbolic (math) | R syntax / user surface | TMB implementation (target) |
|---|---|---|---|---|
| 1 | Latent score, phylo tier | `z_s = M_s alpha + e_s`, with axis innovation `e_{.,k} ~ MVN(0, A)` (replaces ordinary `e_i ~ N(0, I_K)`) | `phylo_latent(0 + trait \| species, d = K, lv = ~ x)`; long and `traits(...)` wide forms both admitted | `score(k,s) = e_phy(k,s) + sum_h X_lv_phy(s,h) * alpha_lv_phy(h,k)`; `e_phy(.,k)` carries the sparse `A^{-1}` GMRF density (`PHY-01` path), NOT `dnorm(0,1)` |
| 2 | Linear predictor | `eta_{st} = X_{st} beta + lambda_t^T z_s + q_{st}` | fixed-effect RHS is **rejected** alongside `lv` in C1 (Design 73 `X + X_lv` guard, `FG-18`); `q` is the `Psi_phy` companion | `eta(o) += sum_k Lambda_phy(t,k) * score(k,s)`; `Psi_phy` diagonal added per `03-phylogenetic-gllvm.md` |
| 3 | Phylo covariance decomposition | `Sigma_phylo = Lambda_phy Lambda_phy^T + Psi_phy`; tier law `g_phy ~ MVN(0, Sigma_phy (x) A)` | `phylo_latent(..., unique = TRUE)` gives the folded `Lambda Lambda^T + Psi` form (source unique/Psi contract, PR #706); `unique = FALSE` is loadings-only | `Sigma_phy` assembled from `Lambda_phy` + `diag(psi_phy)`; three-piece fallback `Omega = Lambda_phy Lambda_phy^T + Lambda_non Lambda_non^T + Psi` when `Psi_phy` is not separately identifiable |
| 4 | Predictor-to-axis coefficients | `alpha` (`p_lv x K`); axis-convention-dependent, NOT the public estimand | not surfaced as the primary table; `extract_lv_effects(..., type = "axis_effect")` reports `alpha` with a rotation warning | parameter `alpha_lv_phy[p_lv, K]`, unconstrained, mapped off when inactive |
| 5 | Public trait-scale effect (the estimand) | `B_lv = Lambda_phy alpha^T` (`T x p_lv`); rotation-invariant, primary | `extract_lv_effects(fit, type = "trait_effect")` returns `B_lv` with SE/CI when `sdreport()` is PD | `ADREPORT(B_lv_phy = Lambda_phy %*% t(alpha_lv_phy))`; delta-method SE for the coverage gate (Section 5) |

Consistency checks the alignment must satisfy before any promotion (Noether):

- **Phylo-off reduction:** with `A = I` (star tree), row 1 must reduce exactly
  to the ordinary Design 73 score `z_i = M_i alpha + e_i`, `e_i ~ N(0, I_K)`;
  the fit must be byte-identical to the ordinary `latent(..., lv = ~ x)` fit on
  the same data (mirrors the wide/long byte-identity discipline used
  throughout the register).
- **Predictor-off reduction:** with `alpha = 0`, row 1 must reduce to the
  existing `phylo_latent` innovation-only model (`Sigma_phy (x) A`), i.e. the
  already-covered `PHY-02` path.
- **`B_lv` invariance:** `B_lv = Lambda_phy alpha^T` must be stable under the
  latent-axis rotation, exactly as Design 73 requires for the ordinary case;
  raw `alpha` / raw `Lambda_phy` are not pass/fail targets for `K > 1`.

---

## 5. ADEMP recovery/coverage gate (Gaussian first)

Following Morris, White & Crowther (2019, *Statist. Med.* 38:2074-2102) and
AGENTS.md Design rule 5 (new variance-share axis => simulation recovery on a
known DGP before the axis is added). **Gaussian is the mandatory first cell**;
non-Gaussian phylo `X_lv` is explicitly *not* covered by this gate and does not
inherit it (Section 2.3, point 4).

### Aims

1. Confirm the native TMB Gaussian `phylo_latent(..., lv = ~ x)` fit **recovers**
   the trait-scale `B_lv = Lambda_phy alpha^T` and the phylo covariance
   `Sigma_phylo = Lambda_phy Lambda_phy^T + Psi_phy` on a known DGP.
2. Confirm the **interval** for `B_lv` attains nominal coverage, with **profile
   as the hero method** (maintainer doctrine D-12; see below).

### Data-generating mechanism

Complete-response Gaussian `phylo_latent(0 + trait | species, d = K,
lv = ~ x)`: a fixed known `Lambda_phy`, `alpha`, `Psi_phy`; species innovation
`e_{.,k} ~ MVN(0, A)` drawn on a fixed tree `A` (start with a star tree for the
phylo-off reduction check, then a non-degenerate ultrametric tree); one
species-level predictor `x` constant within species. Grid over
`(n_species, K, phylo-signal lambda)` -- explicitly including the weak-signal /
small-`n_species` regime where `Psi_phy` vs `Lambda_phy Lambda_phy^T` is poorly
identified and the three-piece fallback applies (row 3 of Section 4). The
retired route's failure was "finite-sample data-level slope/interval
calibration" at p=80, K=2, lambda=0.5 (status.json "Phylo DRAC coverage"), so
that cell must be in the grid as a known-hard point.

### Estimand

**Primary:** the trait-scale `B_lv = Lambda_phy alpha^T` entries (rotation-
invariant). **Secondary:** `Sigma_phylo` off-diagonal pattern; per-trait
`Psi_phy` (broad band). Raw `alpha` and raw `Lambda_phy` are **not** coverage
targets (Design 73). Note the honest scope boundary: this gate targets the
population trait-scale `B_lv`, which is *harder* than the realized
`B_eta_realized` the Julia gates cleared -- the gate must not be quietly
weakened to a realized/`eta`-scale target without a fresh maintainer decision
(that weakening is exactly the 2.1 retirement history).

### Methods (the Wald / profile / bootstrap trio; profile is the hero)

Per maintainer doctrine **D-12 (2026-06-27, accepted): profile is the
featured/hero CI method; Wald only in the easy interior; bootstrap is the
calibration layer.** The trio:

- **Wald** (`wald_z`, and the `wald_t_unit` small-`n` comparator that was never
  worse than `wald_z` in the ordinary Gaussian grid, register `LV-02`): cheap
  default, from `ADREPORT(B_lv_phy)` delta-method SE. Expected to be *suspect*
  here because the phylo-variance parameters live near their boundary.
- **Profile** (hero): invert the likelihood-ratio test for selected `B_lv`
  entries via constrained refit -- the "one missing trio member" D-12 names for
  `B_lv` (gllvmTMB task #22), extending the existing constrained-refit
  derived-quantity machinery. Follow the Design 74 profile gate discipline:
  parse-stable target name, a pure test that the token maps to the intended
  entry, a small known-DGP truth-inclusion test, finite/labelled/one-sided-
  honest endpoints, explicit boundary handling, and move only the tested route.
- **Bootstrap** (calibration layer): parametric bootstrap as the fallback where
  a profile will not close or the Hessian is not PD, and -- per D-12 Q1/Q2 --
  as the calibration reference at the boundary.

**D-12 boundary correction (load-bearing for a phylo-variance profile).** At
the variance->0 / correlation->+/-1 / loading->0 boundaries that a phylogenetic
latent model routinely sits near, the LR reference is a **chi-bar-square
mixture, not `chi^2_1`** (Self & Liang 1987). The plain `qchisq(level, 1)`
cutoff mis-covers in profile's own showcase regime. The gate must use a
boundary-corrected reference (or an (R)LRT bootstrap calibration) at those
edges, and must gate non-Gaussian extensions on `TMB::checkConsistency()`
(D-12 Q3, Laplace bias). This is marked in D-12 as an accepted maintainer
qualification, not optional polish.

### Performance targets

Per Morris et al. (2019) performance measures, each with Monte Carlo SE
reported (not a side note):

- **Bias** of `B_lv` entries, with bias MCSE; recovery band max-abs-error
  `< 0.25` for rank 1 (Design 73 convention), correlation `> 0.90` (CRAN) /
  `> 0.95` (heavy) for the `Sigma_phylo` off-diagonal pattern.
- **Interval coverage** of nominal 95% intervals for `B_lv`, with coverage
  MCSE; audit band 0.92-0.98 (the ordinary Gaussian LV convention, register
  `LV-02`). Report per method (`wald_z`, `wald_t_unit`, profile, bootstrap) so
  the hero-vs-Wald comparison is explicit.
- **CI width** (efficiency) and the failure-accounting denominators:
  convergence, PD Hessian, `sdreport()` availability, CI availability, wall
  time. Production admission requires >= 500 reps/cell, one recorded seed per
  replicate / SLURM array task, per-replicate outputs, `sessionInfo()`, and
  failed-fit denominators (the register `LV-02` bar; a one-rep smoke or a dev
  harness pass is **not** coverage evidence).

Compute: the Gaussian ADEMP campaign is a one-seed-per-array-task SLURM job
(DRAC / Totoro), mirroring the `dev/lv-wald-coverage-slurm.sh` pattern already
used for the ordinary Gaussian and binomial grids.

---

## 6. Proposed validation-debt register row

Add to `docs/design/35-validation-debt-register.md`, Section 14
(Predictor-informed latent scores), a new row that is **more specific than the
existing catch-all `LV-07`** (which covers all of `phylo_* / animal_* /
spatial_* / kernel_*`). `LV-07` remains the umbrella; the new row scopes the
phylo Gaussian `X_lv` cell that this design targets.

| ID | Capability | Status | Test evidence | Notes |
|----|------------|--------|---------------|-------|
| **LV-08** | Structured `X_lv` under phylogeny: Gaussian `phylo_latent(0 + trait \| species, d = K, lv = ~ x)` with phylogenetic score innovation `e ~ MVN(0, A)`, estimand `B_lv = Lambda_phy alpha^T` | **`blocked`** | evidence path **TBD** (planned: `test-lv-phylo-structured-recovery.R` + a `dev/lv-phylo-xlv-*` ADEMP campaign artifact under `docs/dev-log/artifacts/`) | Planned only, authorization-gated. Currently fail-loud via `.abort_unsupported_lv_keyword()` (`R/brms-sugar.R`, PR #573) and the native non-Gaussian guard (`R/lv-predictor.R`, PR #577). Frozen GLLVM.jl Gate 0-3 evidence is for the revised `eta`-scale `B_eta_realized` target on the Julia side (DRAC Nibi 17049809), NOT the population trait-scale `B_lv`, and does not transfer (status.json `serial_gates` "before non-Gaussian/source-specific expansion"). Requires: maintainer authorization (Section 7), Gauss/Noether likelihood sign-off, and the Section 5 ADEMP gate (profile = hero, Self-Liang boundary reference) before any grammar exposure, `PR #127` reopen, or public wording. No inheritance from the ordinary `LV-01..LV-05` Gaussian evidence. |

Initial status = **`blocked`** (advertised-nowhere target that is currently
fail-loud; per the register vocabulary `blocked` = "advertised but currently
broken/undefined/requires removal from public surface", and here the public
surface deliberately rejects it). If the maintainer authorizes the Gaussian
arc, the row moves `blocked -> partial` only when the Section 5 gate delivers
recovery + a first interval subclaim, exactly as `LV-01..LV-05` were staged.

---

## 7. DECISION MEMO -- the maintainer-authorization gate

**This section is a decision for Shinichi. Nothing here is self-approved. The
default state is PARKED; no option below is enacted without an explicit
maintainer instruction.**

### The gate

Two coupled, currently-closed doors:

1. **R side:** reopen source-specific `lv` grammar exposure for the Gaussian
   phylo cell (remove `phylo_latent` from the Section 3 reject list for the
   Gaussian path; ship the parser + TMB + extractor + ADEMP arc). This is a
   **HIGH-RISK likelihood + grammar change** (Section 3.2).
2. **Julia side:** reopen `GLLVM.jl` `PR #127` (currently closed/parked as
   "[BLOCKED] phylo Model A X_lv interval gate -- parked pending redesign") to
   carry the twin phylo route. Note the GLLVM.jl v1 matrix's standing directive
   "Do not reopen PR #127 from this arc" -- a reopen is itself a maintainer
   decision, not a routine follow-on.

The frozen evidence (Section 2) **de-risks** the Gaussian phylo cell on the
Julia side for a realized `eta`-scale target, but **licenses neither door** by
itself.

### Options

- **Option A -- Proceed to Gaussian `phylo_*(..., lv = ~ x)` behind the ADEMP
  gate.** Authorize the Gaussian-only arc: parser change (Gaussian phylo path
  only, all other rejections preserved), TMB likelihood change with Gauss/
  Noether sign-off, extractor, and the Section 5 ADEMP campaign with profile as
  the hero method and the Self-Liang boundary reference. Public wording waits
  until the ADEMP gate passes and Rose audits the claim. `PR #127` reopened in
  lockstep. **Pro:** directly serves the maintainer's stated research want; the
  Julia gates show the Gaussian phylo cell is calibratable at scale.
  **Con:** highest-risk path (grammar + likelihood); the gate targets the
  *population* `B_lv`, which is harder than the realized target the Julia gates
  cleared, so there is real re-derivation and re-calibration risk -- the
  original population-`B_lv` route failed exactly here (2.1).

- **Option B -- Stay parked.** Keep `phylo_*(..., lv = ~ x)` fail-loud, keep
  `PR #127` closed, keep the frozen evidence as internal Julia diagnostics.
  Ship nothing on the public surface. **Pro:** zero new risk; honors the
  standing v1 parking decision; the ordinary `latent(..., lv = ~ x)` surface
  and the `phylo_slope` / `phylo_dep` random-slope surfaces already serve many
  adjacent needs. **Con:** the maintainer's headline want stays unmet.

- **Option C -- Narrow scope: Julia-first / private, no R grammar.** Authorize
  only continued `GLLVM.jl` private work on the revised target (reopen `PR #127`
  as a *private/diagnostic* route, not a public fitter), plus land this design
  doc and the `LV-08` register row, but keep the R grammar fail-loud. Revisit R
  exposure only after a *population*-`B_lv` (not realized `eta`-scale) profile
  route clears an ADEMP gate on the Julia side. **Pro:** makes forward progress
  on the hard calibration question where the toolchain (DRAC/Totoro + Julia)
  already lives, without touching the R public surface or the likelihood.
  **Con:** slower to a user-facing feature; two-package coordination overhead.

### Recommendation (Noether + Fisher + Curie; **Shinichi decides**)

**Recommend Option C as the immediate next step, with Option A as the explicit
follow-on once a population-`B_lv` profile route clears the Julia-side ADEMP
gate.** Reasoning:

1. The single largest honesty gap is scale: the frozen evidence covers a
   *realized `eta`-scale* target, and the *population* `B_lv` route is the one
   that was retired with negative evidence (2.1). Re-earning population-`B_lv`
   coverage on the Julia side first -- where the DRAC/Totoro harness and the
   proven `B_eta_realized` tooling already exist -- de-risks the R likelihood
   change before we touch the grammar. This respects Design rule 5 (evidence on
   a known DGP *before* the axis is added) and the `serial_gates`
   no-inheritance rule.
2. Option C ships durable artifacts now (this design doc, the `LV-08` row, the
   alignment contract) without any high-risk change, keeping the maintainer's
   want on an explicit, gated path rather than parked-and-forgotten.
3. Option A remains the destination; it should be enacted the moment the
   population-`B_lv` Julia gate passes and the maintainer authorizes the R
   grammar + likelihood change with Gauss/Noether sign-off.

Whichever option the maintainer chooses, the non-negotiables are: profile is
the hero interval method with a boundary-corrected reference (D-12); Gaussian
is the mandatory first cell; no Gaussian-to-non-Gaussian inheritance; and no
public wording before the ADEMP gate and a Rose claim audit.

---

## Reviewer checklist

- **Noether:** the Section 4 alignment reduces correctly phylo-off (to Design
  73) and predictor-off (to `PHY-02`); `B_lv` is rotation-invariant.
- **Fisher:** identifiability of `Lambda_phy Lambda_phy^T + Psi_phy` under a
  predictor-informed mean is checked; the Self-Liang boundary reference is
  used for the profile.
- **Gauss:** any TMB change preserves the phylo `A^{-1}` GMRF prior and only
  shifts the axis mean; `checkConsistency()` gates non-Gaussian.
- **Curie:** the ADEMP gate targets `B_lv` / `Sigma_phylo` recovery + coverage
  with MCSE and >= 500 reps/cell, not a smoke.
- **Rose:** this doc claims no capability; `LV-07` stays the umbrella and
  `LV-08` stays `blocked` until the gate passes; no public wording is added.
- **Shannon:** the R and Julia doors (`PR #127`) move only together and only on
  maintainer authorization.

## References and cross-links

- `docs/design/73-predictor-informed-latent-scores.md` -- ordinary
  `latent(..., lv = ~ x)` contract; `phylo_latent(..., lv = ~ x)` = "Reject as
  planned".
- `docs/design/74-augmented-profile-target-table.md` -- the profile-gate
  discipline this design's Section 5 profile route must follow.
- `docs/design/03-phylogenetic-gllvm.md` -- `g_phy ~ MVN(0, Sigma_phy (x) A)`,
  `Sigma_phy = Lambda_phy Lambda_phy^T + Psi_phy`, three-piece fallback.
- `docs/design/04-sister-package-scope.md` -- phylo location-scale is out of
  scope.
- `docs/design/35-validation-debt-register.md` -- `FG-18`, `RE-13`, `EXT-31`,
  `LV-01..LV-07`; add `LV-08` (Section 6).
- `docs/dev-log/dashboard/status.json` -- `lv_arc` rows, Gate 0-3 chronology,
  `serial_gates`, `blockers`.
- GLLVM.jl v1 contract (the Julia-side frozen evidence):
  `GLLVM.jl/docs/dev-log/v1-contract/r-julia-v1-capability-matrix.md`
  ("not public grammar"; "Do not reopen PR #127 from this arc"),
  `.../2026-07-03-bridge-drift-gates.md` (phylo Model A grammar parked unless
  authorized), `.../r-julia-v1-contract-orientation.md` (predictor-informed
  `X_lv` blocked for structured sources). Per-gate after-task records under
  `gllvmTMB/docs/dev-log/after-task/2026-07-01-lv-arc-gate{0,1,2,3}-*.md` and
  `.../2026-07-01-lv-arc-post-gate3-hardening.md` (population-`B_lv` retired;
  `B_eta_realized` is the survivor). PR #127 close recorded in
  `gllvmTMB/docs/dev-log/check-log.md`.
- `AGENTS.md` Design rule 5 -- new variance-share axis => known-DGP simulation
  recovery + design-doc updates.
- `memory/DECISIONS.md` D-12 (2026-06-27) -- profile = hero CI method; `B_lv`
  gets a `:profile` method; Self-Liang boundary correction. *(Maintainer
  doctrine; the specific task-#22 / freqTLS-implementation details are from the
  brain and are UNVERIFIED against the current gllvmTMB source in this pass.)*
- Morris, White & Crowther (2019). Using simulation studies to evaluate
  statistical methods. *Statistics in Medicine* 38(11):2074-2102.
- Self & Liang (1987). Asymptotic properties of MLEs and LR tests under
  nonstandard conditions. *JASA* 82(398):605-610.
