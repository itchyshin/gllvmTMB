# Design 123 — the full multinomial() structured-dependency surface

**Status: FINAL (post-Slice-4 consolidation, 2026-08-16).** Five build
slices (0-4) plus signed recovery campaigns for every admitted cell are
complete. `R/multinomial-fence.R`'s `.mn_admission_table` is the
**single source of truth** for the exact classifier verdict on any
covstruct shape; the table below is a human-readable restatement of it,
folded together with the campaign evidence that decided each admitted
cell's `partial` status. Nothing in this document overrides
`.mn_admission_table` — if the two ever disagree, the R table is right
and this document is stale and should be corrected to match it.

Slice 3 (spatial) landed chronologically after Slice 4 in this worktree;
the numbering below is by DESIGN SLICE, not commit order (see each
section's own timestamp note).

## 1. The admitted set — per-cell table

Legend: **admitted** = a real fit reaches TMB; **refused** = classified,
typed, and will not be revisited without a new identifiability argument
(a scalar collapse across the `(I+J)` contrast geometry has no natural
null); **blocked** = deferred, no decision made either way, may be
admitted in a future slice. Every non-admitted cell aborts with the
shared classed condition `gllvmTMB_multinomial_structured_not_admitted`
(the OLRE guard uses a separate class, `gllvmTMB_multinomial_
olre_not_admitted`, since it is a whole-fit degeneracy check layered on
an individually-admitted classification, not an admission-boundary
refusal).

| Source | Mode | Tier / grouping | Status | Evidence |
|---|---|---|---|---|
| none | `latent()` (default `unique = TRUE`) | unit (shared cross-family) | **admitted** | FAM-20B. Connects a multinomial trait to other-family traits through its `K-1` contrast pseudo-traits; the contrast `Psi` is mapped off (unidentified with one draw per unit). |
| none | `dep()` / explicit `unique()` / `indep()` | unit | blocked | Only the default-`unique=TRUE` `latent()` cell above works at the unit tier; explicit alternates untested. |
| none | augmented (intercept + slope) `latent()` | unit | blocked | Augmented-slope forms of every keyword in this table are blocked, no exceptions. |
| none | `(1 \| group)` | any grouping factor | **admitted** | FAM-20F. **PASSED** the signed s4 gate: 20/20 seeds converged with a PD Hessian, median `sigma_re` ratio 0.947, range [0.60, 1.51] ⊂ [0.5, 2.0]. Baseline-vs-rest semantics (`sigma_re` reference-category-specific); subject to the OLRE guard. |
| none | `indep()` / standalone `unique()` | `cluster` (the `cluster =` argument) | **admitted** | FAM-20F. **NOT covered by the s4 campaign** (a correction to an earlier draft of this row, which wrongly claimed "same s4 gate" — the s4 summary CSV fit `re_int` exclusively, zero `cluster`/`cluster2` rows). `use_diag_species` engine route, per-contrast independent variances; evidenced only at CONSTRUCTION level (`test-matrix-multinomial-unit.R`: the fit constructs, `extract_Sigma(level = "cluster")` returns a well-formed per-contrast diagonal) against a DGP with no cluster-tier structure to recover against. **The recovery axis is OPEN, `partial`** — see `pass-criteria-s4.md`'s own "Non-degenerate diagonal cell" section. Subject to the OLRE guard. |
| none | `indep()` / standalone `unique()` | `cluster2` (the `cluster2 =` argument) | **admitted** | FAM-20F. `use_diag_cluster2` — verified LITERALLY IDENTICAL engine math to `use_diag_species` on a second grouping column (maintainer decision, 2026-08-16: co-admission approved on that identity), so the SAME construction-level-only, recovery-axis-open status as the `cluster` row above applies here too. |
| none | `common = TRUE` (the `scalar()` modifier) | `cluster` / `cluster2` | blocked | No `common`-pooling TMB map exists for `use_diag_species`/`use_diag_cluster2` (unlike the unit/unit_obs `diag_B_common`/`diag_W_common` tricks); admitting it would silently ignore the request rather than pool. |
| none | `latent()` / `dep()` | `cluster` / `cluster2` | blocked | No reduced-rank slot exists at these tiers — diagonal-only. |
| none | any mode | `unit_obs` (`site_species`) | blocked | Out of scope for this arc; see the out-of-scope list below. |
| none | `meta_V()` / `equalto()` | any | **refused** | Confirmed Gaussian-only known-sampling-covariance route; no established route on a categorical-contrast pseudo-trait (fail-closed by design, not merely untested). |
| phylo / animal / kernel¹ | `latent()` (loadings-only, `unique = FALSE`) | among-category | **admitted** | FAM-20C. Equivalence to `phylo_latent()` proven for `animal_latent()`/single-name `kernel_latent()` (matched TMB objective to double precision, matched `V` to 1e-4). One-categorical-draw-per-species gate **FAILED**: rail rate 8/20 (>6/20 threshold), IDENTICALLY for all three keywords by proven engine identity; non-railed median rho 0.695. Pre-registered **replication rescue PASSED**: `n_sp = 300`, `n_rep = 5` draws/species → rails 4/20, median rho 0.680 (the non-railed median per criterion 4's filter) ∈ [0.35, 0.75], SD ratios 0.89/0.85, direction-correct 15/16 of non-railed (94% — the strict-count reading, "≥16/20", falls one short by one seed; both readings recorded). **Disclosed for the same reason: median over ALL 20 conv+PD seeds (unfiltered by the rail exclusion) is 0.696, also inside the [0.35, 0.75] band** -- the filtered (0.680) and unfiltered (0.696) medians agree closely, so the choice of which one to headline does not change the PASS verdict. Tree-vs-star check: Δ logLik 29.7 (phylogeny genuinely enters the fit, not decorative). Register statement: **"one categorical draw per species does not identify V; five draws per species does."** |
| phylo / animal / kernel¹ | `dep()` (full unstructured `V`) | among-category | **admitted** | FAM-20D. The IDENTICAL unconstrained packed-triangular parameterisation as `phylo_latent(d = K - 1)` (`gll_unpack_rr_loadings()`), not merely V-equivalent. `phylo_dep()` gate **FAILED**: rails 8/20, median rho 0.781. The s1b replication rescue **transfers EXACTLY** to this cell (`phylo_latent(d = 2)` under s1b IS the identical parameterisation to `phylo_dep()`). |
| phylo / animal / kernel¹ | `indep()` / standalone `unique()` (diagonal `V`) | among-category | **admitted** | FAM-20D. Diagonal Lambda_phy, `D` independent per-contrast variances, no among-category correlation. **A DGP CORRECTION was made mid-campaign and is recorded openly**: the as-run cell first fed correlated truth into this diagonal-truth cell; the corrected rerun (diagonal truth, sd 0.8/0.5) **FAILED**: larger variance recovers fine (median ratio 0.78, 17/20 in band), but smaller variance collapses (median ratio 0.24, 9/20 in band) -- **7 of the 20 seeds collapse the smaller contrast variance to NUMERICAL ZERO (ratio ≤1e-9: e.g. 2.2e-17, 2.7e-13, 9.5e-13, 7.5e-12, 4.3e-14, 1.2e-10, 7.1e-10), each with `convergence = 0` AND a PD Hessian, and no runtime degeneracy detector currently fires for this** (`R/diagnose.R`'s Heywood/degeneracy gate checks `family_id == 1` only, i.e. binomial -- issue #897's class of gap, not yet extended to fid 16) -- and the planted-zero criterion fails — a full-`V` `phylo_latent()` refit on this diagonal-truth data rails to a median rho magnitude of 1.0. The replication rescue is **untested for this diagonal-V mode** (s1b only fit the full-rank `phylo_latent(d=2)` parameterisation). |
| phylo / animal | `scalar()` | among-category | **refused** | Routes through the unrelated `propto` engine (blocked since Slice 0, unaffected by Slices 1-2's admissions). Null-probe evidence (`dev/multinomial-structured/probe-scalar-null.R`, `V_true = 0`): `phylo_indep()` correctly recovers near-zero variance in 5/5 seeds; `phylo_dep()`'s rho_hat rails toward ±1 in 4/5 seeds DESPITE a PD Hessian — a scalar collapse across the `(I+J)` contrast geometry has no natural null to check against. |
| kernel | `scalar()` (incl. `kernel_indep(..., common = TRUE)`) | among-category | **refused** | Shares the SAME `phylo_rr` covstruct markers as the now-admitted `kernel_indep()`, distinguished ONLY by `.kernel_mode == "scalar"` — a load-bearing classifier carve-out (Slice 2). Same null-probe rationale as the propto-routed `phylo_scalar()`/`animal_scalar()` above. |
| phylo / animal / kernel¹ | `*_latent(unique = TRUE)` (the auto-emitted Psi companion) | among-category | blocked | A free phylogenetic Psi is deliberately unsupported for multinomial — `phylo_latent()`'s documented default (`unique = FALSE`) emits no Psi companion at all. |
| phylo / animal / kernel¹ | augmented (intercept + slope) `*_latent`/`*_dep` | among-category | blocked | Augmented-slope forms are blocked everywhere in this table. |
| kernel | multi-kernel (> 1 distinct `kernel_latent`/`kernel_dep`/`kernel_indep` name in one fit) | among-category | blocked | Whole-fit override — each individual kernel cell classifies admitted on its own, then this check overrides every kernel-sourced classification back to blocked if more than one distinct name is present. |
| spatial | `latent()` (loadings-only, `unique = FALSE`) | SPDE field | **admitted** | FAM-20E. **PASSED** the signed kappa/tau gate: median practical-range ratio 1.75 among the 14 conv+PD seeds (band 0.33-3.0), rails 0 of those 14 (frozen threshold: >6/20, the pre-registered denominator — restored here after an earlier draft wrongly re-expressed it as ">6/14"). Non-PD 6/20 per cell, reported and excluded from the ratio band per the frozen criteria. Dispersion caveat: see the per-seed note below the table. |
| spatial | `dep()` | SPDE field (full field covariance) | **admitted** | FAM-20E. Verified (parser desugar) to literally set `.spatial_latent = TRUE, d = n_traits, .dep = TRUE` — IS `spatial_latent(d = n_traits)` under a documentary keyword; confirmed on real fits (matched TMB objective both directions, tolerance 1e-6, identical `kappa_hat`/`range_hat`). Same gate, median ratio 1.75 among 14 conv+PD seeds, rails 0 of those 14 (frozen threshold >6/20). |
| spatial | `indep()` | SPDE field (per-contrast independent fields) | **admitted** | FAM-20E. Same gate, median ratio 1.12 among 14 conv+PD seeds, rails 3 of those 14 (frozen threshold >6/20, so well under FAIL). `extract_Sigma(level = "spatial")` on an `indep()`-only fit still aborts — a PRE-EXISTING, family-agnostic gap (every family shares it), not introduced or fixed by this slice; read `fit$report$kappa`/`log_tau_spde` directly. |
| spatial | `scalar()` | SPDE field | blocked | One shared level across contrasts, the same `(I+J)` carve-out as the phylo/animal/kernel scalar refusal. |
| spatial | `unique = TRUE`'s paired Psi_spde companion | SPDE field | blocked | Architecturally a SINGLE marker (`.spatial_unique_diag`) on the SAME covstruct as `spatial_latent()`, unlike phylo/animal/kernel's separate-companion-covstruct pattern — needed an explicit classifier carve-out. |
| spatial | standalone `spatial_unique()` / deprecated bare `spatial()` | SPDE field | blocked | Desugars with NO markers at all — it is the PAIRED-COMPANION alias mechanism (Design 60), not an independent diagonal term. **Unlike Slice 2's phylo mode axis, this is NOT admitted as a deprecated alias of `spatial_indep()`.** |
| spatial | augmented (intercept + slope) `spatial_*(1 + x \| coords)` | SPDE field | blocked | Augmented-slope forms are blocked everywhere in this table. |

¹ "phylo / animal / kernel" rows apply IDENTICALLY to all three source
keywords because `animal_*()` and single-name `kernel_*()` are PURE ENGINE
SUGAR: `R/brms-sugar.R` desugars both onto the identical `phylo_rr`
covstruct `phylo_*()` itself produces (verified: matched TMB objective to
double precision, matched `V` to 1e-4/1e-6 depending on cell). The
recovery numbers transfer by this proven engine identity, not by separate
per-keyword campaigns — see §2.

**Spatial per-seed dispersion (D-43 completion panel R9, 2026-08-16;
computed directly from
`dev/multinomial-structured/results/s3-summary-20260816-190701.csv`,
disclosed because the median alone understates spread):** for
`spatial_latent()`/`spatial_dep()`, 4 of the 14 conv+PD seeds fall
OUTSIDE the [0.33, 3.0] practical-range-ratio band despite the median
(1.75) sitting comfortably inside it, with the worst individual ratio
4.56. For `spatial_indep()`, using the frozen criterion's own rail
definition (`range_hat < 0.02`) applied to ALL 20 seeds (not just the
conv+PD subset), 6 of 20 seeds rail low; restricted to the 14 conv+PD
seeds this is the reported 3/14, at range-ratios 2.3e-4, 3.2e-4, and
3.4e-4 -- and **all three of those 3 rails have `pdHess = TRUE`**, i.e.
a collapsed field passes the Hessian check exactly as `phylo_indep()`'s
zero-collapse does (§1's `indep()`/`unique()` row above), the same
pattern noted for the phylogenetic surface. None of this changes the
PASS verdict (the frozen criterion is on the median among non-railed PD
seeds, and both are inside band), but the dispersion itself is real and
should not be read out of a bare median.

## 2. Engine identities (why one campaign covers three-to-nine keywords)

- **`phylo_dep(0 + trait | species)` ≡ `phylo_latent(species, d = K - 1)`,
  the IDENTICAL parameterisation**, not merely V-equivalent. Both resolve
  `d = n_traits` and populate the SAME `phylo_rr`/`theta_rr_phy` slot,
  unpacked by the SAME `gll_unpack_rr_loadings()` (src/gllvmTMB.cpp),
  whose diagonal is unconstrained for every caller. This is why the s1b
  replication-rescue result (fit `phylo_latent(d = 2)`) transfers to
  `phylo_dep()` EXACTLY, with no separate campaign needed.
- **`spatial_dep(0 + trait | coords)` ≡ `spatial_latent(d = n_traits)`**,
  confirmed the same way: parser-desugar identity (`R/brms-sugar.R`
  literally sets `.spatial_latent = TRUE, d = n_traits, .dep = TRUE`) plus
  a real-fit check (matched TMB objective both directions, tolerance
  1e-6, identical `kappa_hat`/`range_hat` at every campaign seed).
- **`animal_*()` = `phylo_*()` with a pedigree/known-relatedness `A`
  matrix instead of a phylogenetic correlation matrix; single-name
  `kernel_*()` = `phylo_*()` with an arbitrary dense supplied `K` matrix**
  (Design 65 C1 phylo-equivalence). All three sources share one engine
  path per mode (latent/dep/indep); the classifier tells them apart only
  by which raw parser marker survives the desugar
  (`.animal_source`/`.kernel_name`), never by a different `use_*` flag.
  `kernel_scalar()` needed an explicit carve-out (§1) because it shares
  its markers with the now-admitted `kernel_indep()`, distinguished only
  by `.kernel_mode == "scalar"`.
- **`use_diag_species` (cluster) ≡ `use_diag_cluster2` (cluster2)**,
  literally identical engine math on two different grouping columns
  (`eta(o) += q_sp(t, species_id(o))` vs `eta(o) += r_c2(t,
  cluster2_id(o))`, `src/gllvmTMB.cpp`) — the basis for the maintainer's
  cluster2 co-admission decision.

## 3. The identification frame

An unordered categorical response with `K` categories spans `K-1` latent
liability dimensions, not one. Two structural facts shape every cell
above:

- **The `(I+J)` null.** The multinomial softmax's implicit link residual
  is the FIXED matrix `(pi^2/6)(I+J)` on each `K-1` contrast block
  (McFadden 1974) — a diagonal covariance estimate is NOT independence on
  this scale; the null contrast covariance already has off-diagonal
  structure before any fitted term is added. `extract_Sigma(...,
  link_residual = "auto")` adds this residual at extraction time; `"none"`
  returns the fitted latent-scale covariance alone.
- **The softmax latent scale is fixed, not free.** Unlike a Gaussian or
  count response, there is no residual-dispersion parameter to trade off
  against a random-intercept variance. This is why a per-observation
  random intercept combined with a multinomial trait is unidentifiable —
  the OLRE guard (§1, `(1 | group)`/cluster/cluster2 rows) exists because
  of this fact specifically, not as a generic robustness precaution.
  **Known boundary (D-43 completion panel R10, 2026-08-16, no code
  change):** `.multinomial_reint_group_olre_guard()` fires only when
  EVERY level of the grouping factor covers exactly one categorical
  observation (`all(n_obs_per_level == 1L)`). A grouping where MOST
  levels are singletons but a few are not passes the guard silently —
  the guard is an all-or-nothing structural check, not a partial-
  degeneracy detector. Whether (and how) to flag that intermediate case
  is an open follow-up, not resolved by this arc; see the after-task
  report's Known Limitations section.
- **The default `latent()` contrast Psi is mapped off**, deliberately,
  at the unit tier: one categorical draw per unit does not identify a
  free per-contrast residual variance there. Replication could identify
  it in principle (§4 shows exactly this mechanism rescuing the
  among-category surface), but the current engine's conservative default
  still suppresses it rather than fit an unidentified free parameter.

## 4. Data-hunger and the replication rescue

Every among-category structured cell (phylo/animal/kernel, §1) shares one
finding: **one categorical draw per species does not identify `V`.**
The signed recovery gates for both the loadings-only route (FAM-20C) and
the full-`V` mode-axis route (FAM-20D) FAILED at the native one-draw
design — rail rates of 8/20, exceeding the pre-registered 6/20 threshold,
for `phylo_latent()`/`animal_latent()`/`kernel_latent()` (identically, by
proven engine identity) and for `phylo_dep()` separately.

A pre-registered replication rescue (s1b, approved by Shinichi in session
BEFORE running: *"Yes go ahead"*) tests the DOCUMENTED mechanism for this
failure mode (Design 84/FAM-20A: "V recovers with per-species replication
or large N"): `n_sp = 300` species, `n_rep = 5` independent categorical
draws per species from the SAME species-level liability. This
**PASSED** every frozen criterion: rail rate 4/20 (≤ 6/20), median rho
0.680 ∈ [0.35, 0.75] (true 0.6), SD ratios 0.89/0.85 ∈ [0.5, 2.0],
direction-correct 15/16 of non-railed seeds (94% — one short of the
strict "≥16/20" count reading; both readings are recorded rather than
picking the favourable one). A tree-vs-star comparison confirms the
phylogeny genuinely enters the fit (Δ logLik 29.7 on the SAME data) —
the recovered signal is not an artefact of the replication alone.

**Scope of the rescue.** Because `phylo_dep()` is the IDENTICAL
parameterisation to the `phylo_latent(d = 2)` cell s1b actually fit (§2),
the rescue transfers EXACTLY to `phylo_dep()` with no separate campaign.
It does **not** cover `phylo_indep()` (the diagonal-`V` mode) — that cell
was run separately (with a DGP correction recorded openly, §1) and
FAILED even without the one-draw confound: larger contrast variances
recover fine (median ratio 0.78, 17/20 in band) but smaller ones collapse
(median ratio 0.24, 9/20), and the planted-zero criterion fails outright
(a full-`V` `phylo_latent()` refit on diagonal-truth data rails to median
|rho| = 1.0).

**The diagonal-V replication question is now MEASURED, and the answer is
no (2026-08-17).** The cell was pre-registered at `1925bc24` BEFORE any
results (`dev/multinomial-structured/pass-criteria-diagonal-v-replication.md`)
and the verdict landed at `5e745dcd`: at `n_rep = 5` the collapse rate is
**7/20 — IDENTICAL to the unreplicated baseline of 7/20** (gate ≤ 2/20,
FAIL), with 20/20 conv+PD and per-seed in-band counts 16/20 and 12/20
(gate ≥ 14/20 each, FAIL on the second contrast). The failure is the
finding: replication rescues the FULL-RANK cell (s1b, rails 8/20 → 4/20)
and does nothing for the DIAGONAL one, because the two cells fail by
different mechanisms — *correlation railing*, which more information per
species fixes, versus *small-variance collapse*, which it does not. An
amendment is recorded rather than silently applied: the pre-registered
`sd_true = c(0.8, 0)` is unrunnable (singular `V`, Cholesky fails), so
`c(0.8, 0.05)` was substituted. The planted-near-zero sub-cell PASSES its
variance criterion (ratio 0.0175 against a true 0.0039 — the model does
not invent variance where there is none) and FAILS its rail criterion as
scored (10/10), with the honest reading attached: a correlation over a
~zero variance is undefined, so railing is the expected numerical
consequence — the same signature as the Arc-1 null probe that grounds the
`*_scalar` refusal in §5, and the criterion is NOT retro-fitted.
**The register must not extrapolate the s1b rescue to the diagonal mode.**

The spatial surface does not share this data-hunger pattern at the
tested scale: the kappa/tau gate PASSED all three cells outright at
`n_site = 300` with no replication rescue needed (§1), though `n_site =
300` itself was not calibrated against a prior spike (unlike S1/S2's
`n_sp = 800`) — see the out-of-scope / follow-up list.

## 5. The scalar refusal

`phylo_scalar()`/`animal_scalar()`/`kernel_scalar()`/`spatial_scalar()`
and `common = TRUE` on the cluster/cluster2 diagonal tier are **refused**,
not merely deferred — a status this document distinguishes deliberately
from "blocked" (§1's legend). The rationale is structural, not merely
"untested": tying the `K-1` per-contrast variances to ONE shared level
collapses the `(I+J)` contrast geometry to a single scalar, and that
scalar has no natural null value to check identifiability against. The
null-DGP probe (`dev/multinomial-structured/probe-scalar-null.R`,
`V_true = 0`, 5 seeds) evidences this without deciding it on its own:
`phylo_indep()` (the admitted diagonal-`V` cell) correctly recovers
near-zero variance in 5/5 seeds, while `phylo_dep()` (the admitted
full-`V` cell) rails its correlation estimate toward ±1 in 4/5 seeds
DESPITE a PD Hessian — a genuinely null-signal fit still reports a
railed, confident-looking correlation. A scalar summary sits at the same
degenerate point as the full-`V` cell's failure mode, with no diagonal
cell's escape hatch (there is no "smaller-than-what" baseline for one
pooled number). `common = TRUE` at the cluster/cluster2 tier is refused
for the separate, purely mechanical reason that no `common`-pooling TMB
map exists for `use_diag_species`/`use_diag_cluster2` (§1) — admitting it
would silently ignore the request rather than genuinely pool.

## 6. Out of scope for this arc

Recorded explicitly so "not mentioned" is never read as "admitted."
None of the following are touched by Slices 0-4, and none abort with a
DIFFERENT message that would suggest otherwise unless noted:

- **AGHQ.** Orthogonal to this fence — an integration-method choice
  acting on `z_B` downstream of admission, not a structured/latent term.
  A request is not rejected by this fence; whatever AGHQ itself decides
  (adapt, or decline to Laplace because the fit is not AGHQ-eligible) is
  out of this fence's scope (`test-multinomial-fence.R`'s AGHQ pin).
- **Multiple multinomial traits** in one fit — still rejected before TMB
  construction (`expand_multinomial_response()`).
- **Random slopes** on any admitted keyword — every augmented
  (intercept + slope) form stays blocked (§1, repeated per source).
- **Explicit contrast Psi** at the unit tier (`dep()`, explicit
  `unique()`/`indep()`) and the free phylogenetic Psi
  (`*_latent(unique = TRUE)`) — both blocked, distinct reasons (§1, §3).
- **`integration = "va"`** — a separate fence (`R/va-routing.R`) rejects
  multinomial outright; this is DR-31 in the validation-debt register, not
  part of this arc.
- **`mi()` predictor terms** combined with a multinomial trait.
- **The `unit_obs` grouping tier** (`site_species`) — no cell of any
  source admits it.
- **Multi-kernel** (more than one `kernel_latent()`/`kernel_dep()`/
  `kernel_indep()` name in one fit).
- **Calibrated intervals** on any admitted structured cell — every
  recovery number in §1/§4 is a point-estimate campaign verdict; no
  coverage-checked interval exists for any admitted structured tier.
- **Julia parity** for any admitted structured cell.
- **Missing responses combined with a newly-admitted structured term.**
  Fixed-effects-only missing-response support for multinomial is already
  tested and unaffected (`test-multinomial-missing-response.R`,
  `miss_control(response = "include")`, group-uniform masking) — what is
  untested is a masked categorical response fitted ALONGSIDE any of
  Slices 1-4's structured terms.
- **`weights`** combined with a multinomial trait and any admitted
  structured term — untested.

## 7. Build log (historical, by design slice)

The sections below are the as-built record of each slice, kept for the
detailed engine/classifier reasoning that motivated each admission.
Chronological landing order in this worktree was Slice 0, 1, 2, 4, 3 —
Slice 4's own section (written before Slice 3 landed) originally said
Slice 3 "is reserved for future work"; that note is superseded by
Slice 3's section below.

### Status (Slice 1, 2026-08-16)

Two more cells moved from deferred to admitted, both loadings-only
(`unique = FALSE`) and both pure engine sugar over the already-admitted
`phylo_latent()` `phylo_rr` route (no engine/C++ change):

- `animal_latent(species, A = A, d = k)` — admitted. Numerically verified
  identical to `phylo_latent()` (matched TMB objective, matched `V`); see
  `tests/testthat/test-matrix-multinomial-phylo.R` and register row FAM-20C.
- Single-name `kernel_latent(species, K = K, d = k, name = nm)` — admitted.
  Same verification. Multiple `kernel_latent()` names in one fit
  (multi-kernel) stay BLOCKED — that check is whole-fit, not per-cell.

`unique = TRUE` on either keyword and every other `animal_*`/`kernel_*` mode
(`*_indep`, `*_dep`, `*_scalar`, `kernel_unique`) remain deferred, along with
everything else this stub's Scope section lists. See
`R/multinomial-fence.R`'s `.mn_admission_table` for the authoritative
per-cell status.

### Status (Slice 2, 2026-08-16)

The phylo MODE axis (dep = full unstructured V, indep/standalone unique =
diagonal V) and its animal/kernel twins move from deferred to admitted, for
all three sources (phylo/animal/kernel; single-name only for kernel):

- **Admitted:** `phylo_dep()`, `animal_dep()`, `kernel_dep()` -- intercept-only
  `*_dep(0 + trait | id)`, resolving `d = n_traits` and populating the SAME
  `phylo_rr`/`theta_rr_phy` slot as `phylo_latent(d = n_traits)`. This is the
  IDENTICAL unconstrained packed-triangular parameterisation
  (`gll_unpack_rr_loadings()`, src/gllvmTMB.cpp), not merely V-equivalent --
  the genuinely `exp()`-transformed Cholesky diagonal belongs to the
  AUGMENTED `*_dep(1 + x | ...)` slope engine (`theta_dep_chol`), a different
  covstruct kind that stays BLOCKED. **Correction to the original task
  brief for this slice:** the brief characterised `*_dep()`'s diagonal as
  exp()-positive in contrast to `phylo_latent()`'s unconstrained diagonal;
  that description is only true of the blocked augmented-slope engine, not
  the intercept-only cell admitted here. Verified numerically identical to
  `phylo_latent(d = K - 1)` at the V level (tolerance 1e-4, 3 DGP seeds; see
  `test-matrix-multinomial-phylo.R` and register row FAM-20D).
- **Admitted:** `phylo_indep()`, `animal_indep()`, `kernel_indep()`, and their
  soft-deprecated standalone `*_unique()` aliases -- diagonal Lambda_phy (the
  strict lower triangle pinned to 0 via a TMB map), giving D independent
  per-contrast phylogenetic variances with NO among-category correlation.
  Confirmed on a real fit that `extract_Sigma(level = "phy")` returns the
  per-contrast diagonal explicitly (off-diagonal < 1e-8), never a collapsed
  scalar.
- **Stays BLOCKED:** `phylo_scalar()`/`animal_scalar()` (route through the
  unrelated `propto` engine, blocked since Slice 0) and `kernel_scalar()`
  (shares the SAME `phylo_rr` markers as the now-admitted `kernel_indep()`,
  distinguished only by `.kernel_mode == "scalar"` -- a load-bearing
  distinction this slice's classifier now carries explicitly). A null-DGP
  probe (`dev/multinomial-structured/probe-scalar-null.R`) evidences the
  refusal's motivation without deciding it: on `V_true = 0` data,
  `phylo_indep()` correctly recovers near-zero variance (5/5 seeds), but
  `phylo_dep()`'s `rho_hat` rails toward ±1 in 4/5 seeds despite a PD
  Hessian -- a naive scalar collapse across the (I+J) contrast geometry has
  no natural null value to check against. Augmented-slope forms,
  `*_latent(unique = TRUE)`, and multi-kernel also remain BLOCKED, along
  with everything else in the Scope section above.

Recovery campaign (`dev/multinomial-structured/campaign-s2-phylo-dep-indep.R`)
ran to completion under `dev/multinomial-structured/pass-criteria-s2.md`
(signed): see §1/§4 above for the final verdict (FAILED, both cells), and
§1's phylo_indep row for the DGP correction made mid-campaign.

### Status (Slice 3, 2026-08-16)

**Landed after Slice 4 chronologically in this worktree** (Slice 4's own
Status section below predates this one and still says Slice 3 "is reserved
for future work" -- that note is now superseded by this section). The
spatial (SPDE) mode axis moves from deferred to admitted:

- **GATE CHECK (done FIRST, before any admission edit):**
  `expand_multinomial_response()` (`R/gllvmTMB.R`) duplicates each
  observation into `K-1` contrast rows BEFORE mesh/`A_proj` construction. Not
  a bug: `make_mesh()` is a pure per-row function of whatever coordinate
  frame it is given, and the engine's `nrow(mesh$A_st) == n_obs` check (`n_obs`
  measured on the ALREADY-expanded data) fails LOUD on a naively-built mesh
  rather than silently misaligning rows. VERIFIED on a real fit (this
  environment has fmesher but NOT INLA, confirmed sufficient for both
  `make_mesh()` and the base SPDE engine): a mesh built on the user's
  original per-site data aborts with `make_mesh() projection has <n_site>
  rows but the long-format data has <n_site*(K-1)>`; a mesh built on a
  coordinate frame pre-expanded with the SAME `rep(seq_len(n), each = K-1)`
  convention `expand_multinomial_response()` uses internally aligns
  EXACTLY -- 0/40 mismatched site-blocks, every contrast row of a site
  carrying the identical `A_proj` row (`dev/multinomial-structured/
  gate-check-a-proj.R`). This IS a real usability burden (the required
  pre-expansion step is undocumented and the internal expansion function is
  not exported), recorded here rather than silently patched.
- **Admitted:** `spatial_latent(0 + trait | coords, d = k)` (loadings-only,
  default `unique = FALSE`) -- the shared cross-contrast SPDE ordination.
- **Admitted:** `spatial_indep(0 + trait | coords)` -- per-contrast
  independent SPDE fields, no cross-contrast field correlation.
- **Admitted:** `spatial_dep(0 + trait | coords)` -- VERIFIED (parser
  desugar, `R/brms-sugar.R`) to literally set `.spatial_latent = TRUE, d =
  n_traits, .dep = TRUE`, i.e. it IS `spatial_latent(d = n_traits)` under a
  documentary keyword (the package's own roxygen already stated this
  identity; now confirmed on real fits -- matched TMB objective at each
  other's converged parameters both directions, tolerance 1e-6, and
  IDENTICAL `kappa_hat`/`range_hat` at every campaign smoke-mode seed).
- **`extract_Sigma(level = "spatial")` bug fixed alongside this admission:**
  the top-level fixed-effects-only multinomial refusal (`.mn_has_latent`,
  `R/extract-sigma.R`) did not recognise ANY spatial term (`use$spde`), so a
  multinomial fit with ONLY a spatial term (no phylo/unit/cluster tier)
  incorrectly tripped the "fixed-effects-only" abort for EVERY requested
  level, not just an unsupported one. Fixed by adding `use$spde` to the
  check. `link_residual = "auto"` correctly adds the `(pi^2/6)(I+J)` softmax
  residual on the total surface at this level too (the generic code path is
  not level-gated), matching the `phy`/FAM-20A contract.
- **PARTIAL, pre-existing, NOT fixed here:**
  `extract_Sigma(level = "spatial")` on a `spatial_indep()`-ONLY fit still
  aborts ("Fit has no `spatial_latent()` term") -- this gap exists for EVERY
  family, not just multinomial (e.g. `test-matrix-ordinal-spatial.R`'s own
  `spatial_indep` cell reads `fit$report$kappa`/`log_tau_spde` directly
  rather than through `extract_Sigma()`, for the same reason). Building a
  new diagonal-SPDE extraction surface is out of this slice's scope.
- **Stays BLOCKED:** `spatial_scalar()` (one shared level across contrasts,
  the (I+J) carve-out, mirroring `phylo_scalar()`/`animal_scalar()`/
  `kernel_scalar()`); `spatial_latent(unique = TRUE)`'s paired diagonal
  Psi_spde companion -- architecturally a SINGLE marker
  (`.spatial_unique_diag`) on the SAME covstruct, unlike phylo/animal/kernel's
  separate-companion-covstruct pattern, so it needed an explicit carve-out;
  standalone `spatial_unique()`/deprecated bare `spatial()` -- desugars with
  NO markers at all, and is the PAIRED-COMPANION alias mechanism (meant to
  pair with `spatial_latent()`, Design 60), not an independent diagonal term
  the way `phylo_unique()`/`phylo_indep()` are, so **unlike Slice 2's phylo
  mode axis it is NOT admitted as a deprecated alias of `spatial_indep()`**;
  and every augmented (intercept + slope) `spatial_*(1 + x | coords)` form.

Recovery campaign (`dev/multinomial-structured/campaign-s3-spatial.R`) ran to
completion under `dev/multinomial-structured/pass-criteria-s3.md` (signed):
**PASSED all three cells** -- see §1/§4 above for the final verdict. `n_site
= 300` was NOT calibrated against a prior spike, unlike S1/S2's `n_sp = 800`
(recorded as a follow-up, not a defect in the result). Register row FAM-20E.

### Status (Slice 4, 2026-08-16)

Ordinary GROUP random intercepts move from deferred to admitted -- a
different axis from Slices 1-2 (source/mode of the phylogenetic surface):
this slice is about ordinary, non-phylogenetic grouping structure. (This
section originally said Slice 3, the spatial mode axis, was reserved for
future work; Slice 3 has since landed -- see its own Status section above,
inserted before this one for numeric ordering even though it was written
after this section chronologically.)

- **Admitted:** a generic `(1 | group)` random intercept (engine kind
  `re_int`, `src/gllvmTMB.cpp`'s `re_int` block). Verified against the
  engine's own indexing: the group id is read off the AFTER-expansion
  pseudo-trait data (`R/fit-multi.R`), so every one of a multinomial
  observation's `K-1` baseline-contrast rows carries the SAME group id and
  gets the SAME additive draw. This is a **baseline-vs-rest** group effect,
  not a per-category one: the shared shift moves `P(y = baseline)` versus
  `P(y != baseline)` and leaves the odds between any two NON-baseline
  categories unchanged -- WITHIN one fit, across groups (pinned empirically:
  the log-odds between the two non-baseline categories has sd = 0 across all
  900 observations of a `G = 20`, `n_per_g = 5` fixture, tolerance 1e-6;
  `test-matrix-multinomial-unit.R`). `sigma_re`'s substantive interpretation
  is therefore **reference-category-specific**. **Correction to an earlier
  draft of this section (this task, caught by a failing test):**
  re-labelling `baseline` is **NOT** a reparameterisation of the same
  model, so it is not only `sigma_re` that changes under a different
  baseline -- the fitted response-scale probabilities change too. Under
  `baseline = 1`, `eta = (0, b0_2 + u_g, b0_3 + u_g)` constrains the
  log-odds *between categories 2 and 3* to be constant across groups (no
  `u_g` term in `eta_3 - eta_2`); under `baseline = 3` the SAME engine
  instead shares a (new) `u_g` between categories 1 and 2, constraining
  *their* log-odds to be constant instead -- a genuinely different
  parametric restriction on the model space, not the same distribution
  under two labels (unlike the fixed-effects-only case, where relabelling
  really is a reparameterisation; see `test-multinomial.R`'s existing
  baseline-invariance tests, which have no random-effect term).
- **Admitted:** the non-phylogenetic `cluster`/`cluster2` diagonal tier --
  `indep(0 + trait | g)` via the `cluster =`/`cluster2 =` arguments, and the
  soft-deprecated standalone `unique()` alias (the SAME engine path, only the
  printed label differs). `use_diag_species` (cluster) and `use_diag_cluster2`
  (cluster2) are LITERALLY IDENTICAL engine math (`eta(o) += q_sp(t,
  species_id(o))` vs `eta(o) += r_c2(t, cluster2_id(o))`,
  `src/gllvmTMB.cpp`) on two different grouping columns, so both are admitted
  together. This gives `D` independent per-CONTRAST (pseudo-trait) variances
  at that grouping -- the per-category random intercept most users actually
  want.
- **New: an OLRE guard.** For a fid-16 fit, if EVERY level of an admitted
  `(1 | g)` or cluster/cluster2 `indep()` grouping covers exactly one
  categorical observation (`.multinom_group_`), the term is an
  observation-level random effect (OLRE) in disguise: the softmax latent
  scale is fixed (no free residual-dispersion parameter, unlike a
  Gaussian/count response), so a per-observation intercept shared across its
  own `K-1` contrast rows is not identifiable from the fixed effects. This is
  a WHOLE-FIT check against `data` (needs the observation-to-group mapping,
  not just the covstruct shape), so it is a SEPARATE typed guard
  (`gllvmTMB_multinomial_olre_not_admitted`), layered on top of an
  individually-admitted classification -- mirroring how the multi-kernel
  override (Slice 1) sits on top of an individually-admitted kernel cell.
- **Stays BLOCKED:** `common = TRUE` (the `scalar()` modifier) at the
  cluster/cluster2 tier -- the generic engine has no common-pooling map for
  `use_diag_species`/`use_diag_cluster2` (unlike the unit/unit_obs
  `diag_B_common`/`diag_W_common` map tricks), so admitting it would silently
  ADMIT the term while silently IGNORING the `common = TRUE` request rather
  than actually pooling to one shared level -- refused explicitly, matching
  `phylo_scalar()`/`animal_scalar()`/`kernel_scalar()`. The `unit_obs`
  grouping tier and `latent()`/`dep()` at the cluster/cluster2 tiers also
  stay BLOCKED (no engine slot).

Recovery campaign (`dev/multinomial-structured/campaign-s4-group-intercepts.R`)
ran to completion under `dev/multinomial-structured/pass-criteria-s4.md`
(signed): **PASSED** -- see §1/§4 above for the final verdict. Register row
FAM-20F.

## 8. Detector coverage — what `check_gllvmTMB()` screens on a categorical fit

Every campaign in §1 and §4 produced fits that converged (`convergence == 0`)
with a positive-definite Hessian while reporting a degenerate quantity, and
none of them was flagged: `R/diagnose.R`'s Heywood/degeneracy gate tested
`family_id == 1L` (binomial) only. That is issue #897's class of gap
(`ordinal_probit`: **0/239** degenerate fits flagged, where the binomial
screen caught **272/272**). This section records what the detector covers
now, at what thresholds, and with what measured sensitivity and specificity.

**All of it is `check_gllvmTMB()` surface only. Fit-time warnings are NOT
wired for either categorical family.** No `gllvmTMB()` call warns differently
than it did before this arc; turning any of these rows into an automatic
warning is a behaviour change and is deliberately left to the maintainer.

### 8.1 The mechanism question #897 left open, settled

#897 flagged the mechanism behind ordinal degeneracy as unknown, naming link
saturation (cutpoint underflow in `gll_log_pnorm_diff`) as the suspect. The
pre-registered S1 probe (`dev/ordinal-degeneracy/probe-criteria.md`, decision
rule frozen at `e932cf37`, verdict at `b33d3b90`; 60-fit grid, 24 fits
degenerate by per-fit truth) measured three things and the verdict is
**category-level separation, not link saturation**:

1. **Flat-row share is EXACTLY 0 on all 24 degenerate fits** — the cutpoint
   underflow condition (both bracketing cutpoints more than 8.2924 from
   `eta` on the same side) is never reached on any observed row. Saturation
   is refuted, not merely unsupported.
2. **24/24 dichotomised refits fire the EXISTING binomial detector** —
   collapsing each degenerate fit's response to binary at the middle
   cutpoint and refitting as `binomial(link = "probit")` reproduces the
   pathology under a screen that already works, which is what identifies
   the mechanism as the same quasi-complete separation geometry.
3. **The pathology is a SINGLE-COLUMN runaway** — worked example: one
   trait's loading 44.2 against a true `max|Lambda| = 4.79`, with sibling
   traits near truth.

The directional-derivative arm landed in the pre-registered "mixed" bucket,
for a disclosed reason rather than a silent one: a uniform whole-matrix
rescale masks a single-column pathology, so that arm cannot see what arms 1-3
see. Consequence for the build: **a flat-fit/saturation arm has no empirical
basis and was deliberately not built**; the ordinal row is modelled on the
binomial loading arms instead.

### 8.2 Ordinal (`ordinal_probit()`, fid 14) — `ordinal_liability_loading`

Two loading arms, both armed at **40** after the S2b calibration campaign
(`dev/ordinal-degeneracy/pass-criteria-ordinal.md`, verdict 2026-08-17; 315
fits, `n = 100/400`, four pre-registered arms, per-fit truth
`rel_frob > 10`).

| Arm | Statistic | Threshold | Sensitivity | False positives |
|---|---|---|---|---|
| O1 `runaway_loading` | trait's largest loading / typical loading among the fit's OTHER ordinal traits (family-scoped denominator) | 40 | 37.8% | **0.0% on every arm** |
| O2 `extreme_magnitude` | trait's largest unit-tier loading, liability scale (never the SPDE tier) | 40 | 60.2% overall, **70.0% homogeneous** | 0.9% overall; **0.0% plain healthy, 0.0% transport**, 2.7% mixed |

**The frozen conjunction (sensitivity ≥ 90% AND zero false positives) was NOT
achieved at any threshold, and is reported rather than fudged.**
`max_loading_unit` separates the classes in the middle (degenerate median
49.68 vs healthy median 1.23) but the tails overlap (degenerate minimum 10.2,
healthy maximum 52.3). The full trade-off curve:

| O2 threshold | sensitivity | FP (all healthy) |
|---|---|---|
| 6 (binomial's own) | 100.0% | **24.0%** |
| 20 | 90.8% | 10.6% |
| 40 (**shipped**) | 60.2% | 0.9% |

Two measured facts decided the operating point. First, **at binomial's own
threshold of 6 the ordinal screen reaches 100% sensitivity but 24% false
positives — reproducing on ordinal exactly the defect #897 reports in
binomial (25%)**; borrowing binomial's number would have shipped the very
failure the issue asks us to fix, which is why the thresholds were set on
ordinal's own evidence. Second, **every false alarm at any threshold comes
from heterogeneous-scale designs** (the adversarial transport arm: 78.6% FP
at 6, 35.7% at 20, 0.0% at 40); **the plain healthy arm has ZERO false
positives at EVERY threshold from 6 to 40**. An absolute liability-scale
threshold cannot transport across heterogeneous trait scales, because a
legitimately large loading on a wide-cutpoint trait is indistinguishable from
a runaway.

Arming at 40 rather than taking the pre-registered ship-disarmed fallback
follows #897's own stated priority — *"a check that cries wolf a quarter of
the time gets switched off"* — so specificity is the binding constraint.
Against the status quo of 0/239 detection, a screen that never cries wolf on
a healthy fit and still catches ~60-70% of degenerate ones is a strict
improvement.

Grid trim, stated rather than silent: the pre-registered grid was
`n in {100, 400, 1600}`; **`n = 1600` was DROPPED and the `n = 400` seed
count halved** to stay inside the D-139 budget (315 fits, 9.0 min on 10
cores; the full grid projected past 30 minutes). The healthy pool is 217
fits, so the rule-of-three FPR bound is **~1.4%**, not the ~0.6% a 500-fit
pool would have given. The `cutpoint_span` / `loading_over_span` variant is
computed and reported for the campaign but is **NOT** wired into `flag` or
`status`: its circularity precondition (is the span confounded with the
label it screens for?) was not tested, so it stays calibration-only.

Why this row is the whole of a default ordinal fit's coverage: fid 14 traits
drop the auto-Psi at parse time (`auto_unique_off_family`, `R/fit-multi.R`),
so a pure-ordinal fit has no `report$sd_B` and every `near_zero_psi_*` row is
dark by design.

### 8.3 Multinomial (`multinomial()`, fid 16) — `multinomial_contrast_degeneracy`

Three arms over the `K-1` baseline-contrast pseudo-traits of one response
(`dev/multinomial-structured/pass-criteria-detector-mn.md`, criteria frozen
at `f6552ee9` BEFORE results, verdict at `6f34568e`, M3 re-measurement after
the scope fix at `860a91c0`; 128 fits, 122 conv+PD).

| Arm | Statistic | Armed default | Measured against the labeled cells |
|---|---|---|---|
| M1 `contrast_variance_collapse` | a contrast's fitted loading energy at or below an absolute floor | `multinomial_collapse_floor = 1e-10` | **6/7** labeled collapses (target ≥ 6/7) **plus 7/7 fully out-of-sample** on the diagonal-V replication cell (0/13 FP there) |
| M2 `contrast_rail` | largest `|rho|` between two contrasts of the same response, evaluated **only where the tier's rank is ≥ 2** | `multinomial_rail_thresh = 0.99` | **8/8** labeled rails (target ≥ 7/8), **plus 4/4 individually-railed fits hidden inside a cell whose AGGREGATE gate passed** |
| M3 `spatial_range_collapse` | fitted spatial practical range relative to the coordinate domain | `multinomial_range_collapse_thresh = 0.02` | **3/3** after the scope fix (**0/3** before it) |

The M1 sibling/relative sub-arm (`multinomial_collapse_rel_thresh`) stays
**disarmed (`Inf`)** — untested in this campaign.

**M2's four "false positives" were TRUE positives, verified by refitting.**
M2 fired on four seeds of the s1b cell whose aggregate gates had PASSED;
refitting those exact seeds gives `rho = +1.00000, -1.00000, +1.00000,
+1.00000`, while two non-firing controls give 0.48997 and -0.14534. The
cell-level "healthy" label was the artifact, not the detector — an aggregate
gate can pass while containing individually railed fits.

**Rank-1 suppression is proven out-of-sample:** on 20 healthy `d = 1` fits M2
never fires, despite `rho = ±1` holding on every one of them by row
proportionality (a single shared loading column). This was the statistical
review's blocking objection to the arm and it is now empirically closed.

**Zero false positives on 40 informative healthy fits — with the honest
denominator.** The naive denominator was 56; the s4 `re_int` cell's 20 fits
are EXCLUDED because a bare `(1 | group)` multinomial fit has no loading tier
at all, so the detector row never appears (`det_present` 0/20) and those fits
carry zero information about specificity. The informative pool is 20 `d = 1`
fits plus s1b's 16 non-railed fits, giving a rule-of-three bound of **3/40 ≈
7.5%** at 95% confidence. This is a real improvement on binomial's measured
25% but is **NOT a verified zero**; bounding it near 0.6% needs a ≥ 500-fit
healthy arm, which is outstanding, not done.

**M1 fires 8/8 on a null DGP (`V_true = 0`), counted separately and BY
DESIGN:** a truly zero variance component is indistinguishable from a
collapsed one at the fit level, which is why the row's action text says
"intentionally mapped off, boundary-pinned, or genuinely collapsed" rather
than asserting a defect.

**M3's original 0/3 was a keyword-scope bug, not a calibration miss.** The
arm gated on `Lambda_spde`, which the engine REPORTs only on the low-rank
`spatial_latent()`/`spatial_dep()` route (`spde_lv_k > 0`); the labeled
collapse cell is `spatial_indep()`, whose per-trait fields carry no loading
matrix — so the arm never evaluated the fits it was built for and emitted no
row at all. The fix branches on the engine route (the diagonal branch reads
`log_tau_spde`, populated for every trait unconditionally on that route).
Re-running the same 20 seeds: detector row emitted **0/20 → 20/20**,
sensitivity on the labeled collapse seeds **0/3 → 3/3**, false positives on
that cell's healthy fits **0/11**.

### 8.4 A structural false positive that predates this arc, fixed

`check_gllvmTMB()`'s `near_zero_psi_unit` screen WARNed on a healthy mixed
`multinomial()` + `gaussian()` fit purely because `R/fit-multi.R`'s
`skip_psi_b_t` block pins each multinomial contrast pseudo-trait's
`theta_diag_B` at `log(1e-6)` while `src/gllvmTMB.cpp` still `REPORT`s `sd_B`
for the pinned entries — so the pinned `1e-6` always cleared both the
absolute and the relative collapse thresholds. Live-confirmed on a fit whose
free gaussian trait had sd 0.312 (healthy). The screen now drops pinned
entries (via `tmb_data$diag_B_skip`) before evaluating the row; a genuine
collapse among the remaining free traits is still caught. Fixed at
`120fc58c`; this predates the Design 123 arc and affected every fit with a
single-trial-Bernoulli or multinomial trait sharing a `latent()` term with a
free partner trait.

### 8.5 What the detector still does NOT cover

- **Fit-time warnings**, for either family (see the top of this section).
- **Binomial's own 25% false-positive rate** (#897 point 2): measured and
  diagnosed by the ordinal campaign — the same absolute-threshold transport
  failure — but its re-calibration is a separate slice, deliberately not
  rushed into this arc.
- **Ordinal at `n = 1600`**: no evidence.
- **The `cutpoint_span` variant**: calibration-only, circularity untested.
- **The M1 relative/sibling sub-arm**: disarmed, untested.
- **FPR bounds, not verified zeros**: ~1.4% (ordinal, 217 healthy fits) and
  ~7.5% (multinomial, 40 informative healthy fits).

## See also

- `docs/design/02-family-registry.md` — the unordered categorical family
  registry entry and its current admitted-set statement.
- `docs/design/35-validation-debt-register.md` — FAM-20/FAM-20A-F, the
  register rows this design's evidence feeds.
- `docs/design/84-*` (Tier-2a `phylo_latent()`) and the Tier-2b item 2a-ii
  shared-`latent()` cross-family work, both referenced from
  `R/families.R`'s `multinomial()` roxygen.
- `R/multinomial-fence.R` — the admission fence this design documents;
  `.mn_admission_table` there is the single source of truth (see the
  header note above).
- `docs/dev-log/after-task/2026-08-16-multinomial-structured-arc.md` — the
  arc-level after-task report (scope, all five slices, campaign verdicts,
  corrections made along the way, follow-ups).
- `docs/dev-log/after-task/2026-08-17-categorical-paper-alignment-and-detector.md`
  — the after-task report for the paper-alignment (PA1-PA4) + detector
  (§8) arc, including its known limits.
- `dev/ordinal-degeneracy/` and `dev/multinomial-structured/pass-criteria-detector-mn.md`
  — the pre-registered criteria and verdicts behind every §8 number.

## Paper alignment — Mizuno, Drobniak, Williams, Lagisz & Nakagawa (2025) J. Evol. Biol. 38:1699-1715 (doi 10.1093/jeb/voaf116)

This section is the authoritative equation-by-equation map from Mizuno et al.
(2025) — the methods reference for phylogenetic ordinal and nominal PGLMMs,
with a companion tutorial (ayumi-495.github.io/multinomial-GLMM-tutorial) and
code (Zenodo 10.5281/zenodo.17038830) implemented in MCMCglmm and brms — onto
the equivalent `gllvmTMB()` call, with a per-cell status verified against this
worktree's code and tests (not the paper's Bayesian implementations). Every
status claim below was checked against `R/families.R`, `R/multinomial-fence.R`,
`R/extract-cutpoints.R`, `R/extract-sigma.R`, `R/extract-omega.R`,
`R/extract-repeatability.R`, `docs/design/35-validation-debt-register.md`, and
the cited test files in this worktree; none is aspirational, and cells with no
in-repo evidence are marked accordingly rather than assumed to work.

### Alignment table

| Paper eq | Model | `gllvmTMB` call | Status | Evidence pointer |
|---|---|---|---|---|
| 1-5 | Univariate continuous PMM: y = beta0 + Xbeta + a + e, a ~ N(0, sigma_a^2 A) | `gllvmTMB(value ~ 0 + trait + phylo_indep(0 + trait \| species, tree = tree), data = df, trait = "trait", unit = "species", cluster = "species", family = gaussian())` | covered | Register PHY-01/PHY-02/PHY-03 (`covered`); `test-phylo-hadfield.R`, `test-stage35-phylo-rr.R`, `test-phylo-q-decomposition.R`. `animal_indep()`/single-name `kernel_indep()` inherit by the proven parser-desugar engine identity onto the same `phylo_rr` covstruct (Design 123 §2; Design 65 C1). |
| 6-11 | Multivariate/bivariate PMM: cross-trait Kronecker Sigma_a (x) A | `gllvmTMB(value ~ 0 + trait + phylo_dep(0 + trait \| species, tree = tree), data = df, trait = "trait", unit = "species", cluster = "species", family = gaussian())` | covered | Register PHY-02/PHY-05 (`covered`, gaussian); `phylo_dep(0 + trait \| species)` is verified the IDENTICAL unconstrained packed-triangular parameterisation as `phylo_latent(species, d = n_traits)` (`gll_unpack_rr_loadings()`, `src/gllvmTMB.cpp`), documented generically in §2 above (the identity is not multinomial-specific — it is the shared phylo-tier engine). |
| 12-21 | Binary PGLMM, probit liability: H^2 = sigma_a^2 / (sigma_a^2 + 1) | `gllvmTMB(value ~ 0 + trait + phylo_indep(0 + trait \| species, tree = tree), data = df, trait = "trait", unit = "species", cluster = "species", family = binomial(link = "probit"))` | covered | Register PHY-04 (`covered`, `phylo_scalar` shared-variance recovery + CI smoke), PHY-05 (`covered`, `phylo_indep`/`phylo_dep` structural + recovery); `test-phyloscalar-binary.R`, `test-phylodepindep-binary.R` — both fit `binomial(link = "probit")` specifically, matching the paper's probit-liability H^2 denominator `sigma_a^2 + 1` exactly (`R/extract-sigma.R` has no separate probit branch — probit's link residual is fixed at 1 by the same construction as `ordinal_probit`, see the fid == 14 branch below). Logit-link H^2 = sigma_a^2/(sigma_a^2 + pi^2/3) uses the fid == 0 branch of `link_residual_per_trait()`; general-family construction is covered by the family registry but a dedicated logit-link phylo recovery cell was not located in this pass — do not extend the "covered" verdict to logit without checking further. |
| 27-32 | Ordinal (threshold) PGLMM, probit cutpoints, latent residual fixed at 1, no source structure (unit tier only) | `gllvmTMB(value ~ 0 + trait + latent(0 + trait \| unit, d = 1), data = df, trait = "trait", unit = "unit", family = ordinal_probit())` (also `indep()`/`dep()`/`scalar` at the unit tier) | admitted, recovery skip-honest (not a settled `covered` claim) | Register FG-07/08/09 rows referenced directly in the test file's own skip messages ("ordinal ... stays partial"); `test-matrix-ordinal-unit.R` walks `latent`, `unique`, `latent+unique` paired, `indep`, `dep`, and `scalar` cells, each one `test_that`, each with an honest `skip()` on non-convergence/non-PD rather than a relaxed assertion — fits construct and are family-checked (`family_id_vec[1] == 14L`) and `extract_cutpoints()` returns finite estimates, but no cell is unconditionally green. |
| 27-32 | Ordinal PGLMM with phylogenetic/relatedness source: liability = beta0 + a_phy + e | `gllvmTMB(value ~ 0 + trait + phylo_latent(species, tree = tree, d = 1), data = df, trait = "trait", unit = "unit", cluster = "species", family = ordinal_probit())` (also `phylo_scalar`, `phylo_indep`, `phylo_dep`) | admitted, recovery skip-honest | `tests/testthat/test-matrix-ordinal-phylo.R`, header comment: "Walks PHY-04 / PHY-05 ... from `partial` toward `covered` for the ordinal-probit branch." Fits assert `family_id_vec[1] == 14L`, finite cutpoints, and non-degenerate `extract_correlations(tier = "phy")`; each `test_that`'s own skip message states explicitly "PHY-04 stays partial pending bigger n / different seed" / "PHY-05 stays partial pending bigger n / different seed". The register rows PHY-04/PHY-05 as currently worded describe binary-probit evidence only — the ordinal-probit branch's pass/skip counts are not yet folded into the register prose; treat this cell as evidenced-but-not-registered rather than silently covered. |
| 27-32 | Ordinal PGLMM with pedigree/relatedness source (`animal_*`) | `gllvmTMB(value ~ 0 + trait + animal_dep(0 + trait \| id, A = A), data = df, ..., family = ordinal_probit())` | admitted, engine identity MEASURED (latent, T = 3) + dep byte-equivalence (T = 2) + recovery smoke PASSED | PA3 (2026-08-17): `tests/testthat/test-matrix-ordinal-kernel-animal.R` — `animal_latent(A = vcv(tree, corr = TRUE), d = 1)` vs `phylo_latent(tree = tree, d = 1)` on a T = 3, n_sp = 48, K = 4 ordinal fixture passed the S1 identity check (matched TMB objective at each other's converged parameters BOTH directions, tol 1e-6; matched phy-tier `extract_Sigma` to 1e-4; cross-route: sparse tree A^-1 vs dense `A =`); `animal_indep(0 + trait \| species, A =)` construct+converge+diagonal-Sigma smoke passed; and an `animal_latent` recovery smoke against a rank-1 DGP passed its deliberately LOOSE 3x total-phy-variance band — all non-skipped in the 2026-08-17 local heavy run (5 cells, 0 fail, 0 skip). The pre-existing `animal_dep` byte-equivalence + CI smoke (T <= 2) in `test-matrix-animal-nongaussian.R` "Cell 5" stands unchanged (ordinal `dep` remains BLOCKED at T >= 4 per that file's comments). The loose-band smoke is NOT a calibrated recovery gate — no rho/variance recovery claim tighter than the 3x band is admissible from these cells. |
| 27-32 | Ordinal PGLMM with an arbitrary dense-kernel source (`kernel_*`) | `gllvmTMB(value ~ 0 + trait + kernel_latent(species, K = K, name = "k1", d = 1), data = df, ..., family = ordinal_probit())` | admitted, engine identity MEASURED (latent + indep modes) | PA3 (2026-08-17): `tests/testthat/test-matrix-ordinal-kernel-animal.R` — the equivalence this row previously carried only as an architecture INFERENCE (Design 65 C1) is now measured for `ordinal_probit()`: `kernel_latent(species, K = vcv(tree, corr = TRUE), d = 1, name = "k1")` vs `phylo_latent(species, tree = tree, d = 1)` AND `kernel_indep(species, K =, name = "k1")` vs `phylo_indep(0 + trait \| species, tree =)` both passed the S1 identity check (matched TMB objective at each other's converged parameters BOTH directions, tol 1e-6; matched phy-tier `extract_Sigma` to 1e-4) on a T = 3, n_sp = 48, K = 4 ordinal fixture, cross-route (sparse tree A^-1 vs dense `K =`), non-skipped in the 2026-08-17 local heavy run (0 fail, 0 skip). `kernel_dep`, `kernel_unique`, multi-kernel, and every augmented form remain UNMEASURED for ordinal — this row's evidence covers exactly the latent and indep modes tested. |
| 27-32 | Ordinal PGLMM with spatial (SPDE) source | `gllvmTMB(value ~ 0 + trait + spatial_latent(0 + trait \| coords, d = 1), data = df, ..., mesh = mesh, family = ordinal_probit())` (also `spatial_scalar`, `spatial_indep`, `spatial_dep`) | admitted, recovery skip-honest | `tests/testthat/test-matrix-ordinal-spatial.R`, header comment: "Walks SPA-02 ... SPA-03 ... SPA-04 ... from `partial` toward `covered` for the ordinal-probit branch." Each cell's own skip message states "SPA-0N(ordinal) stays partial pending bigger n / different seed" for exactly the same skip-honest reasons as the phylo branch above. |
| 33-37 | Nominal (unordered) PGLMM, unit-tier shared ordination, K-1 baseline-contrast logits | `gllvmTMB(value ~ 0 + trait + latent(0 + trait \| unit, d = K - 1), data = df, trait = "trait", unit = "unit", family = multinomial())` | admitted | FAM-20B (this document's §1, unit-tier default `latent()` row). Full per-cell detail lives in §1 above; not repeated here to avoid drift between two tables in the same file. |
| 33-37 | Nominal PGLMM, non-phylogenetic group / within-species replication tier (`(1 \| group)` or `indep(cluster)`) | `gllvmTMB(value ~ 0 + trait + (1 \| group), data = df, ..., family = multinomial())` | admitted, `(1 \| group)` PASSED recovery; `indep(cluster)` construction-only | FAM-20F (this document's §1). `(1 \| group)` 20/20 seeds converged PD, `sigma_re` ratio median 0.947; `indep(0 + trait \| cluster)` is construction-verified only, recovery axis explicitly OPEN per `pass-criteria-s4.md`. |
| 33-37 | Nominal PGLMM, per-contrast phylogenetic/relatedness variances AND correlations, Sigma_a (x) A over the K-1 contrasts | `gllvmTMB(value ~ 0 + trait + phylo_latent(species, tree = tree, d = K - 1), data = df, ..., cluster = "species", family = multinomial())` (loadings-only) or `phylo_dep(0 + trait \| species)` (full unstructured V) | admitted, ONE-DRAW gate FAILED, replication rescue PASSED | FAM-20C/FAM-20D (this document's §1/§4). One categorical draw per species: rail rate 8/20 (FAIL, threshold 6/20). Pre-registered replication rescue (`n_sp = 300`, `n_rep = 5`): rail rate 4/20 (PASS), median rho 0.680, direction-correct 15/16 non-railed. Register statement: "one categorical draw per species does not identify V; five draws per species does." This is the direct gllvmTMB analogue of the paper's own stated data requirement (see the replication-model note below). |
| 33-37 | Nominal PGLMM, diagonal per-contrast phylogenetic variances only (no among-category correlation) | `gllvmTMB(value ~ 0 + trait + phylo_indep(0 + trait \| species, tree = tree), data = df, ..., cluster = "species", family = multinomial())` | admitted, FAILED (both draw regimes) | FAM-20D (this document's §1). Diagonal-truth DGP: larger contrast variance recovers (median ratio 0.78, 17/20 in band), smaller one collapses to numerical zero in 7/20 seeds with `convergence == 0` and a PD Hessian. That silent-collapse gap is now CLOSED on the detector side (§8): the M1 arm of the `multinomial_contrast_degeneracy` row flags 7/7 of those collapse seeds and 0/13 of the non-collapsed fits of the same cell, out-of-sample. The replication rescue is no longer untested: the pre-registered diagonal-V replication cell (`dev/multinomial-structured/pass-criteria-diagonal-v-replication.md`, criteria frozen at `1925bc24` BEFORE results, verdict at `5e745dcd`) **FAILED** — collapse 7/20 at `n_rep = 5`, IDENTICAL to the unreplicated baseline of 7/20. Replication does NOT transfer to this mode. |
| 33-37 | Nominal PGLMM, spatial (SPDE) source over the K-1 contrasts | `gllvmTMB(value ~ 0 + trait + spatial_latent(0 + trait \| coords, d = K - 1), data = df, ..., mesh = mesh, family = multinomial())` | admitted, PASSED | FAM-20E (this document's §1). Median practical-range ratio 1.75 (14 conv+PD seeds), 0 rails against the frozen >6/20 threshold; per-seed dispersion caveat recorded in §1's dedicated note (4/14 seeds outside the nominal band despite the passing median). |
| 33-37 | Nominal PGLMM, scalar / single shared level across contrasts (any source) | `gllvmTMB(value ~ 0 + trait + phylo_scalar(species), ..., family = multinomial())` | refused (structural, not merely untested) | §5 above. Null-DGP probe: `phylo_dep()`'s rho_hat rails toward magnitude 1 in 4/5 seeds even when the true signal is zero, DESPITE a PD Hessian — a scalar summary has no natural null on the `(I+J)` contrast geometry. |
| 38-46 | PGLMM with BOTH a phylogenetic species effect a_i (A-structured) and a non-phylogenetic species effect s_i (I-structured) plus residual, for continuous/other core families | `gllvmTMB(value ~ 0 + trait + phylo_indep(0 + trait \| species, tree = tree) + indep(0 + trait \| species), data = df, trait = "trait", unit = "species", cluster = "species", family = <core family>)` | covered (for the families it is documented against — NOT ordinal/multinomial) | `docs/design/03-phylogenetic-gllvm.md` ("The non-phylogenetic species tier is `g_non ~ MVN(0, Sigma_non (x) I)`"), `docs/design/13-phylo-signal-partition.md` (the "full4" `extract_communality()` partition requires exactly `phylo_unique()` + an ordinary non-phylogenetic `latent(species)`), and the worked recipe in `docs/design/78-functional-phylogeography-recipe.md` combining `phylo_indep(species, tree = tree)` with `indep(0 + trait \| species)` in one formula. This is the general-family analogue of the paper's eq 38-46 decomposition and is an established, documented gllvmTMB pattern — just never exercised for a categorical trait. |
| 38-46 | Same combined phylo + non-phylo species effect, for `multinomial()` (fid 16) | `gllvmTMB(value ~ 0 + trait + phylo_latent(species, d = K - 1, tree = tree) + indep(0 + trait \| species), data = df, ..., unit = "obs", cluster = "species", family = multinomial())` (replicated data, both terms co-located on the `species` cluster column per the Design 78 routing rule) | admitted, campaign RUN (2026-08-17): **components recover, rail gate FAILED — components-only claim, no rho claim** | **PA4 VERDICT (criteria signed at `6db3296d`, results at `f9fe7d3c`; `pass-criteria-pa4.md` Cell B, `n_sp = 300` x 5 reps, 20 seeds):** 20/20 conv+PD and all four component medians (est/true) in the frozen [0.33, 3.0] band — phy1 0.97, phy2 0.56, sp1 0.90, sp2 0.69 — but **12/20 seeds railed `|rho_hat| > 0.99` against a frozen threshold of >6/20 = FAIL.** Recorded, not softened: the variance components separate and recover under the combined model, but the among-category correlation — which plain `n_rep = 5` replication had rescued in s1b (4/20 rails) — destabilises again once a non-phylogenetic species tier competes for the same liability variance at this design. **No rho recovery claim for the combined multinomial model.** Construction evidence (unchanged): `dev/categorical-replication/verify-admission-pa4.R` cell M1 — the combined fit RUNS on replicated probe data (conv = 0, PD Hessian) with BOTH engine tiers live (`use_phylo_rr = 1` AND `use_diag_species = 1`, separate `theta_rr_phy`/`theta_diag_species` parameter blocks); the fence does not block the combination (its only whole-fit overrides remain the multi-kernel count and the OLRE guard). Both extraction routes verified live (`extract_Sigma(level = "phy", part = "shared")` and `level = "cluster"`). Full-size D-139 timing fit (n_sp = 300 x 5 reps): 2.6 s, conv = 0, PD, rho_hat 0.555 (single seed, NOT evidence). Recovery evidence: `dev/categorical-replication/pass-criteria-pa4.md` Cell B (DRAFT — frozen bands committed BEFORE any results, commit `78507518`) + `campaign-pa4-multinomial.R --mode full` (20 seeds), gated on Shinichi's sign-off of that criteria file. |
| 38-46 | Same combined phylo + non-phylo species effect, for `ordinal_probit()` (fid 14) | `gllvmTMB(value ~ 0 + trait + phylo_indep(0 + trait \| species, tree = tree) + indep(0 + trait \| species), data = df, ..., unit = "obs", cluster = "species", family = ordinal_probit())` (replicated data) | admitted, campaign RUN (2026-08-17): **PASSED all four component gates** | **PA4 VERDICT (criteria signed at `6db3296d`, results at `f9fe7d3c`; `pass-criteria-pa4.md` Cell A, `n_sp = 150` x 5 reps, T = 2, K = 4, 20 seeds):** 20/20 conv+PD; component medians (est/true) phy1 0.77, phy2 0.82, sp1 1.04, sp2 0.96 — all four inside the frozen [0.33, 3.0] band separately. The paper's eq 38-46 combined phylogenetic + non-phylogenetic species model is EVIDENCED for `ordinal_probit()` at this design. Construction evidence (unchanged): `ordinal_probit()` is not gated by `R/multinomial-fence.R` at all (that fence checks `family_id_vec == 16L` only), and `dev/categorical-replication/verify-admission-pa4.R` cells O1 (`phylo_indep` + `indep`, the shape at left) and O2 (`phylo_latent(species, d = 2)` + `indep`) both RUN on replicated probe data (conv = 0, PD Hessian) with both engine tiers live (`use_phylo_rr = 1` AND `use_diag_species = 1`) and both extraction routes returning finite estimates. Full-size D-139 timing fit (n_sp = 150 x 5 reps, T = 2, K = 4): 13.4 s, conv = 0, PD (single seed, NOT evidence). Recovery evidence: `pass-criteria-pa4.md` Cell A (DRAFT, frozen bands pre-committed at `78507518`) + `campaign-pa4-ordinal.R --mode full` (20 seeds), gated on sign-off. Still distinct from — and narrower than — the single-source `partial` rows tracked under PHY-04/PHY-05/FG-07/08/09 above. |
| 4, 18, 19 | Estimand: per-trait / per-contrast phylogenetic heritability H^2 = sigma_a^2 / (sigma_a^2 + sigma_e^2) | `extract_phylo_signal(fit, link_residual = "auto")` | fid 14/16 **covered by PA2** (liability denominator, see the PA2 outcome note below); gaussian/binomial/poisson covered as before via the default denominator | `R/extract-omega.R:421-` implements exactly this ratio (`H2 = phylo_parts[, "H2"]`, `R/extract-omega.R:531`) over `extract_Sigma(level = "phy")`; `tests/testthat/test-m1-7-extract-omega-phylo-signal-mixed-family.R` exercises it across a mixed gaussian/binomial/poisson fit. **MEASURED and FIXED by PA2 (2026-08-17)**: the pre-PA2 extractor was not merely untested on fid 14/16, it returned `H2 = 1.0` for EVERY categorical trait and contrast (the fixed liability residual never entered the denominator — technically the species-level-latent proportion, silently nonsense against the paper's estimand, whose own values for these data are ~0.37/0.35/0.27/0.41). `link_residual = "auto"` now puts `1` (ordinal, eq 18) or `pi^2/3` (multinomial per contrast, eq 19) into the denominator, hand-verified to 1e-10 against mocked cells, never collapsed to a scalar for multinomial; the default (`"none"`) is byte-identical to the old behaviour. Live MCMCglmm `family = "ordinal"` comparator on a shared fixture: 0.357 (gllvmTMB) vs 0.436 (MCMCglmm), band 0.15, truth 0.5. Evidence: `tests/testthat/test-phylo-signal-categorical.R`. (`extract_repeatability()`, by contrast, computes a DIFFERENT unit-vs-unit_obs ratio, not this paper's phylogenetic H^2 — do not conflate the two extractors when scoping PA2.) |
| 27-32 estimand | Ordinal fixed link-residual variance sigma_d^2 = 1 (the denominator term of the binary/ordinal H^2 formulas) | n/a (internal constant) | covered | `R/extract-sigma.R:327-337` (fid == 14 branch, `out[t] <- 1`, "the ordinal latent scale ... probit-liability convention"). |
| 33-37 estimand | Nominal fixed link-residual matrix (pi^2/6)(I + J): pi^2/3 diagonal, pi^2/6 off-diagonal per McFadden (1974) | n/a (internal constant) | covered | `R/extract-sigma.R:365-374` (fid == 16 branch, diagonal `pi^2/3`); `R/extract-sigma.R:406` (`.multinomial_link_residual_offdiag()`, the full `(K-1)x(K-1)` off-diagonal block). |
| 8 | Estimand: phylogenetic correlation between traits/contrasts | `extract_correlations(fit, tier = "phy")` / `extract_cross_correlations(fit)` | covered for admitted phylo tiers, including ordinal and multinomial | `R/extract-correlations.R` (`extract_correlations` at line 392, `extract_cross_correlations` at line 884); exercised directly against `ordinal_probit()` phylo/spatial fits in `test-matrix-ordinal-phylo.R`'s `expect_phy_correlations_nondegenerate()` helper and against `multinomial()` in the FAM-20C/20D campaigns above. |
| — | Estimand: ancestral state reconstruction | not provided | out of scope | gllvmTMB has no ancestral-state extractor of any kind; this is a modelling target the paper's MCMCglmm/brms implementations support that gllvmTMB does not attempt. |
| A.1-A.9 | Appendix contrast-matrix (Delta) reparameterisation of the softmax | n/a | no action | Equivalent reparameterisation of the identical baseline-category-logit softmax `gllvmTMB` already fits directly (`multinomial(link = "logit", baseline = NULL)`, `R/families.R:797-808`); no functional gap, nothing to build. |

### The Box-2 parameterisation translation (ordinal cutpoints)

The paper's Box 2 distinguishes two equivalent-but-differently-labelled
threshold parameterisations for an ordinal PGLMM: MCMCglmm's convention
(intercept free, first cutpoint fixed at 0, and the *second* cutpoint is
what a user coming from `MCMCglmm::MCMCglmm()` reads off as "the reported
threshold") versus brms's convention (intercept fixed at 0, all cutpoints
free). `gllvmTMB`'s `ordinal_probit()` follows Hadfield (2015)'s own
convention directly: tau_1 = 0 is FIXED for identifiability and the K - 2
free cutpoints tau_2, ..., tau_{K-1} are estimated per trait and returned by
`extract_cutpoints()` as `cutpoint_2`, `cutpoint_3`, ... (`R/extract-cutpoints.R:3-20`,
`:66-`). This is the SAME fixed-first-cutpoint convention MCMCglmm uses, not
brms's zero-intercept convention — a user translating an MCMCglmm ordinal
PGLMM into `gllvmTMB` maps `MCMCglmm`'s free intercept directly onto
`gllvmTMB`'s trait intercept and MCMCglmm's second-cutpoint report onto
`gllvmTMB`'s `cutpoint_2`, with no re-anchoring needed. A user translating a
brms fit (zero intercept, all cutpoints free) must instead re-express brms's
`Intercept[1]` as `gllvmTMB`'s trait intercept plus `tau_1 = 0`, and shift
every subsequent brms cutpoint by that same additive constant to land on
`gllvmTMB`'s `cutpoint_2`, `cutpoint_3`, ... — the two parameterisations
differ by a location shift, not a distributional one, but the shift is not
performed automatically by either package.

### The H^2 gap (PA2)

Every admitted phylogenetic tier for `ordinal_probit()` and `multinomial()`
(the ordinal and nominal rows above) has NO tested route to the paper's
headline estimand, phylogenetic heritability H^2 (eq 4, 18, 19). The
extractor that computes this ratio for every other admitted family,
`extract_phylo_signal()`, is family-agnostic in its own code (no fid switch,
built on the equally family-agnostic `extract_Sigma()`) but has zero test
coverage against a fid 14 or fid 16 fit — `R/extract-omega.R` never mentions
`ordinal`, `multinomial`, `14`, or `16`, and no test file pairs
`extract_phylo_signal()` with either family. The two fixed link-residual
denominators this formula would need for categorical traits already exist
and are unit-tested (`R/extract-sigma.R:327-337` for ordinal's sigma_d^2 = 1,
`R/extract-sigma.R:365-374` + `:406` for multinomial's `(pi^2/6)(I+J)`), so
the missing piece is narrowly the wiring-and-evidence step, not new theory.
This is PA2's scope: exercise `extract_phylo_signal()` against the admitted
ordinal/multinomial phylo cells above, decide whether the diagonal-only
denominator is the right target for multinomial's `(I+J)`-coupled residual,
and add the recovery evidence the register currently lacks.

**PA2 outcome (2026-08-17, CLOSED).** Measured first: on a phylo-only fid 14
or fid 16 fit the pre-PA2 extractor returned `H2 = 1` for every trait /
contrast — technically the correct species-level-latent proportion, but
silent nonsense relative to the paper's estimand, because the fixed liability
residual never entered the denominator. Fix shipped in `R/extract-omega.R`:
`extract_phylo_signal()` gains `link_residual = c("none", "auto")` —
default `"none"` is byte-identical to the old behaviour (all existing tests
untouched), `"auto"` adds `link_residual_per_trait()` to the denominator and
reports it as a fourth proportion column, which on a phylogenetic-only fit
yields exactly the paper's `H^2 = V_a / (V_a + 1)` per ordinal trait (eq 18)
and `H^2_(k) = V_a(k) / (V_a(k) + pi^2/3)` per multinomial contrast (eq 19).
The diagonal-only-denominator question is DECIDED: per-contrast H^2 uses the
`pi^2/3` diagonal, is documented as baseline-referenced (the `(pi^2/6)(I+J)`
off-diagonals mean changing baseline changes the contrasts), and is never
collapsed to one scalar. A categorical fit summarised with the default
denominator now fires an advisory; `ci = TRUE` with `"auto"` refuses with a
typed error (`gllvmTMB_phylo_signal_ci_link_residual_unsupported` — the
existing CI machinery targets the old ratio), and the no-phylo-tier refusal
is now typed (`gllvmTMB_phylo_signal_no_phylo_tier`). Evidence:
`tests/testthat/test-phylo-signal-categorical.R` — hand-computed mocked
cells for both families, typed-refusal cells, a live star-tree ordinal fit
(loose 0.2-band recovery of `sigma2_phy/(sigma2_phy + 1)`), a live
one-draw multinomial wiring cell (NO recovery claim — that regime fails
identifiability per FAM-20C above), and an MCMCglmm `family = "ordinal"`
comparator (R fixed at 1, `nitt = 33000`, H^2 formula
`Va/(Va + Vunits + 1)` per MCMCglmm's implicit probit link variance;
measured agreement 0.357 vs 0.436 = 0.079 abs, band 0.15). What PA2 does
NOT cover: coverage-calibrated intervals for the liability-scale H^2, a
multi-seed recovery campaign (single-seed live cells only), and the
replication-regime multinomial H^2 (PA4's combined-tier campaign is the
natural home).

### The ordinal x kernel/animal evidence gap (PA3)

Within the ordinal PGLMM rows above, the phylo and spatial tiers both carry
real (if skip-honest, not-yet-passing) recovery-test evidence
(`test-matrix-ordinal-phylo.R`, `test-matrix-ordinal-spatial.R`). The
`animal_*` tier has only a byte-equivalence + CI-smoke cell
(`test-matrix-animal-nongaussian.R`'s "Cell 5"), capped at T <= 3 traits and
making no recovery claim. The `kernel_*` tier has NO dedicated test at all
for `ordinal_probit()` — its admission is inferred from the general Design 65
C1 phylo-equivalence architecture, not measured. PA3 should close this
asymmetry: either add a `kernel_* x ordinal_probit` construct+recovery cell
mirroring `test-matrix-ordinal-phylo.R`'s structure, or explicitly register
the kernel tier as untested for this family rather than leaving it silently
implied by the phylo evidence.

**CLOSED (2026-08-17):** PA3 took the first branch.
`tests/testthat/test-matrix-ordinal-kernel-animal.R` now carries five
measured cells for `ordinal_probit()` on a T = 3, n_sp = 48, K = 4,
n_rep = 4 coalescent-tree fixture (rank-1 latent phylo truth): (1)
`kernel_latent(K = vcv(tree, corr = TRUE))` vs `phylo_latent(tree =)` and
(2) `kernel_indep(K =)` vs `phylo_indep(tree =)` — both S1 engine-identity
checks (matched TMB objective at each other's converged parameters, BOTH
directions, tol 1e-6; matched phy-tier `extract_Sigma` to 1e-4;
cross-route sparse-tree vs dense-K); (3) the same identity for
`animal_latent(A =)` vs `phylo_latent(tree =)`; (4) an
`animal_indep(0 + trait | species, A =)` construct+converge+diagonal-Sigma
smoke; (5) an `animal_latent` recovery smoke against the rank-1 truth,
LOOSE 3x band on total phy variance, honest-SKIP outside it. The
2026-08-17 local heavy run (`GLLVMTMB_HEAVY_TESTS=1`) passed all five
cells non-skipped (0 fail, 0 skip). The alignment-table rows above now
record the measured statuses; what remains unmeasured for ordinal is
listed there (`kernel_dep`/`kernel_unique`, multi-kernel, augmented
forms, and any recovery claim tighter than the 3x smoke band).

### The replication-model note (PA4)

The paper defers within-species (non-phylogenetic) variation for discrete
traits to "future development" and names replication — multiple
observations per species — as the practical mechanism that would let such a
model be fit. This is not a hypothetical for `gllvmTMB`: the FAM-20C/FAM-20D
campaign already measured exactly this mechanism for the nominal
(multinomial) among-category surface (this document's §4) — one categorical
draw per species FAILS the identifiability gate (rail rate 8/20) and five
draws per species PASSES it (rail rate 4/20, median rho 0.680) — and the
combined-effects rows above (eq 38-46) show that the GRAMMAR for a's paired
non-phylogenetic species effect already exists and is documented for other
families (`docs/design/03-phylogenetic-gllvm.md`,
`docs/design/78-functional-phylogeography-recipe.md`). PA4's job is
therefore to run the s1b-style replication recovery campaign for the
COMBINED phylo + non-phylo (a_i + s_i) formula on `ordinal_probit()` and
`multinomial()` specifically — the untested-combination rows above — rather
than to invent new machinery.

**PA4 status (2026-08-17): constructions verified, campaign staged.** Both
combined constructions fit live (see the updated eq 38-46 rows above and
`dev/categorical-replication/verify-admission-pa4.R`); the pre-registered
criteria (`dev/categorical-replication/pass-criteria-pa4.md`, frozen bands
committed BEFORE any results at `78507518`) and the two campaign scripts
(`campaign-pa4-ordinal.R`, `campaign-pa4-multinomial.R`, modes
timing/smoke/full) are committed; D-139 timing fits project ~4.5 min
(ordinal) and ~0.9 min (multinomial) serial for the 20-seed runs.

**PA4 outcome (2026-08-17, CLOSED — split verdict).** Shinichi signed the
criteria file at `6db3296d` and both `--mode full` campaigns ran to
completion (results at `f9fe7d3c`). The paper's eq 38-46 model RUNS for both
categorical families, and the two verdicts differ:

- **Ordinal (Cell A) PASSES.** 20/20 conv+PD; all four component medians
  (est/true) inside the frozen [0.33, 3.0] band separately — phy1 0.77,
  phy2 0.82, sp1 1.04, sp2 0.96.
- **Multinomial (Cell B) FAILS its rail gate** while its components recover.
  20/20 conv+PD, component medians 0.97 / 0.56 / 0.90 / 0.69 all in band,
  but 12/20 seeds rail `|rho_hat| > 0.99` against the frozen >6/20
  threshold. The claim admitted from this cell is therefore
  **components-only: the phylogenetic and non-phylogenetic species
  variances separate and recover; the among-category correlation does
  not, under a competing species tier.** Plain replication had rescued
  rho in s1b (4/20 rails); adding the s tier undoes that rescue at this
  design.

What PA4 does NOT cover: any calibrated interval on either tier, any design
other than the two run (`n_sp = 150` ordinal, `n_sp = 300` multinomial, both
at `n_rep = 5`), and a rho claim for the combined multinomial model at any
design — a larger `n_rep` or `n_sp` might restore it, and that is untested,
not ruled out.

### Frequentist-engine positioning

Mizuno et al. (2025) ships Bayesian implementations only (MCMCglmm and brms);
`gllvmTMB` is a frequentist Laplace/TMB engine and is the paper's methods
family, not a translation of its software. Where PA2 needs a second-opinion
comparator for the H^2 / cutpoint estimates on a shared fixture, the paper's
own companion tutorial (ayumi-495.github.io/multinomial-GLMM-tutorial) and
Zenodo code archive (10.5281/zenodo.17038830) are the natural MCMCglmm-side
reference implementations to fit alongside `gllvmTMB` — the same
cross-package-comparator pattern already used elsewhere in this repository
for `glmmTMB`/`gllvm` (see `docs/design/04-sister-package-scope.md`), not a
new engine to build.
