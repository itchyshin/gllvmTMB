# Design 122 — the full multinomial() structured-dependency surface

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
| none | `indep()` / standalone `unique()` | `cluster` (the `cluster =` argument) | **admitted** | FAM-20F, same s4 gate (the fixture reused for both cells). `use_diag_species` engine route, per-contrast independent variances. Subject to the OLRE guard. |
| none | `indep()` / standalone `unique()` | `cluster2` (the `cluster2 =` argument) | **admitted** | FAM-20F. `use_diag_cluster2` — verified LITERALLY IDENTICAL engine math to `use_diag_species` on a second grouping column (maintainer decision, 2026-08-16: co-admission approved on that identity). |
| none | `common = TRUE` (the `scalar()` modifier) | `cluster` / `cluster2` | blocked | No `common`-pooling TMB map exists for `use_diag_species`/`use_diag_cluster2` (unlike the unit/unit_obs `diag_B_common`/`diag_W_common` tricks); admitting it would silently ignore the request rather than pool. |
| none | `latent()` / `dep()` | `cluster` / `cluster2` | blocked | No reduced-rank slot exists at these tiers — diagonal-only. |
| none | any mode | `unit_obs` (`site_species`) | blocked | Out of scope for this arc; see the out-of-scope list below. |
| none | `meta_V()` / `equalto()` | any | **refused** | Confirmed Gaussian-only known-sampling-covariance route; no established route on a categorical-contrast pseudo-trait (fail-closed by design, not merely untested). |
| phylo / animal / kernel¹ | `latent()` (loadings-only, `unique = FALSE`) | among-category | **admitted** | FAM-20C. Equivalence to `phylo_latent()` proven for `animal_latent()`/single-name `kernel_latent()` (matched TMB objective to double precision, matched `V` to 1e-4). One-categorical-draw-per-species gate **FAILED**: rail rate 8/20 (>6/20 threshold), IDENTICALLY for all three keywords by proven engine identity; non-railed median rho 0.695. Pre-registered **replication rescue PASSED**: `n_sp = 300`, `n_rep = 5` draws/species → rails 4/20, median rho 0.680 ∈ [0.35, 0.75], SD ratios 0.89/0.85, direction-correct 15/16 of non-railed (94% — the strict-count reading, "≥16/20", falls one short by one seed; both readings recorded). Tree-vs-star check: Δ logLik 29.7 (phylogeny genuinely enters the fit, not decorative). Register statement: **"one categorical draw per species does not identify V; five draws per species does."** |
| phylo / animal / kernel¹ | `dep()` (full unstructured `V`) | among-category | **admitted** | FAM-20D. The IDENTICAL unconstrained packed-triangular parameterisation as `phylo_latent(d = K - 1)` (`gll_unpack_rr_loadings()`), not merely V-equivalent. `phylo_dep()` gate **FAILED**: rails 8/20, median rho 0.781. The s1b replication rescue **transfers EXACTLY** to this cell (`phylo_latent(d = 2)` under s1b IS the identical parameterisation to `phylo_dep()`). |
| phylo / animal / kernel¹ | `indep()` / standalone `unique()` (diagonal `V`) | among-category | **admitted** | FAM-20D. Diagonal Lambda_phy, `D` independent per-contrast variances, no among-category correlation. **A DGP CORRECTION was made mid-campaign and is recorded openly**: the as-run cell first fed correlated truth into this diagonal-truth cell; the corrected rerun (diagonal truth, sd 0.8/0.5) **FAILED**: larger variance recovers fine (median ratio 0.78, 17/20 in band), but smaller variance collapses (median ratio 0.24, 9/20), and the planted-zero criterion fails — a full-`V` `phylo_latent()` refit on this diagonal-truth data rails to a median rho magnitude of 1.0. The replication rescue is **untested for this diagonal-V mode** (s1b only fit the full-rank `phylo_latent(d=2)` parameterisation). |
| phylo / animal | `scalar()` | among-category | **refused** | Routes through the unrelated `propto` engine (blocked since Slice 0, unaffected by Slices 1-2's admissions). Null-probe evidence (`dev/multinomial-structured/probe-scalar-null.R`, `V_true = 0`): `phylo_indep()` correctly recovers near-zero variance in 5/5 seeds; `phylo_dep()`'s rho_hat rails toward ±1 in 4/5 seeds DESPITE a PD Hessian — a scalar collapse across the `(I+J)` contrast geometry has no natural null to check against. |
| kernel | `scalar()` (incl. `kernel_indep(..., common = TRUE)`) | among-category | **refused** | Shares the SAME `phylo_rr` covstruct markers as the now-admitted `kernel_indep()`, distinguished ONLY by `.kernel_mode == "scalar"` — a load-bearing classifier carve-out (Slice 2). Same null-probe rationale as the propto-routed `phylo_scalar()`/`animal_scalar()` above. |
| phylo / animal / kernel¹ | `*_latent(unique = TRUE)` (the auto-emitted Psi companion) | among-category | blocked | A free phylogenetic Psi is deliberately unsupported for multinomial — `phylo_latent()`'s documented default (`unique = FALSE`) emits no Psi companion at all. |
| phylo / animal / kernel¹ | augmented (intercept + slope) `*_latent`/`*_dep` | among-category | blocked | Augmented-slope forms are blocked everywhere in this table. |
| kernel | multi-kernel (> 1 distinct `kernel_latent`/`kernel_dep`/`kernel_indep` name in one fit) | among-category | blocked | Whole-fit override — each individual kernel cell classifies admitted on its own, then this check overrides every kernel-sourced classification back to blocked if more than one distinct name is present. |
| spatial | `latent()` (loadings-only, `unique = FALSE`) | SPDE field | **admitted** | FAM-20E. **PASSED** the signed kappa/tau gate: median practical-range ratio 1.75 (band 0.33-3.0), rails 0/14 (>6/14 threshold). Non-PD 6/20 per cell, reported and excluded per the frozen criteria. |
| spatial | `dep()` | SPDE field (full field covariance) | **admitted** | FAM-20E. Verified (parser desugar) to literally set `.spatial_latent = TRUE, d = n_traits, .dep = TRUE` — IS `spatial_latent(d = n_traits)` under a documentary keyword; confirmed on real fits (matched TMB objective both directions, tolerance 1e-6, identical `kappa_hat`/`range_hat`). Same gate, median ratio 1.75, rails 0/14. |
| spatial | `indep()` | SPDE field (per-contrast independent fields) | **admitted** | FAM-20E. Same gate, median ratio 1.12, rails 3/14 (< 6/14 threshold). `extract_Sigma(level = "spatial")` on an `indep()`-only fit still aborts — a PRE-EXISTING, family-agnostic gap (every family shares it), not introduced or fixed by this slice; read `fit$report$kappa`/`log_tau_spde` directly. |
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
|rho| = 1.0). **Replication rescue is untested for the diagonal-V mode**
— this is stated as an open question, not resolved by extrapolation from
the full-`V` result.

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
