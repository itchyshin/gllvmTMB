# Execution Plan — Option A: Gaussian `phylo_latent(..., lv = ~ x)` (structured × X_lv, phylo first)

Date: 2026-07-06 · Author: Claude (Ada), named lenses below · **Status: PLAN ONLY —
no engine code written; awaits maintainer sign-off before S3.**

This is the implementation plan Design 76 §7 asked for: it turns the Option A decision
(Shinichi, 2026-07-06 — build the structured × X_lv headline feature in gllvmTMB R first,
`phylo_*` first) into a slice-by-slice, **source-grounded** plan a colleague could run.
It does **not** implement anything. The target grammar `phylo_latent(0 + trait | species,
d = K, lv = ~ x)` remains fail-loud by design (Design 76 §3) until the maintainer authorizes
the arc and the S3 TMB likelihood change clears Gauss/Noether sign-off + the ADEMP gate.

**Read first:** `docs/design/76-structured-xlv-phylo.md` (the design contract, §4 alignment,
§5 ADEMP gate, §7 DECISION). This plan is downstream of it and inherits all its non-negotiables.

**Lens owners** (per Design 76): Noether (math↔impl consistency), Fisher (identifiability /
inference), Curie (ADEMP recovery), Boole (parser), Gauss (TMB likelihood), Emmy (extractors),
Rose (scope/claim audit), Shannon (R↔Julia coordination).

---

## 0. What the grounding pass established (and corrected)

Four read-only probes mapped the current `main` (@ `13686230`) reality for each surface.
Design 76's line-number citations predate the 43-conflict reconciliation merge; these are the
**verified** anchors. Three findings materially change the plan versus Design 76 §7's sketch.

### 0.1 Confirmed anchors (build against these)

- **Parser guards** (`R/brms-sugar.R`): two nested guards reject source-specific `lv` —
  `.abort_source_specific_lv()` (~2195–2206) and `.abort_unsupported_lv_keyword()` with the
  reject-keyword list (~2207–2227). `phylo_latent` is in the list. Ordinary `latent(..., lv=~x)`
  desugars at ~3130–3187 (stores `lv_formula`, drops `lv`); `phylo_latent` rewrites to
  `phylo_rr(...)` at ~3117–3129 and does **not** pass `lv` through; the `unique=TRUE` Psi
  companion is appended at ~3218–3247.
- **Family guard** (`R/lv-predictor.R:53–128`): `gll_prepare_lv_predictor_setup()` admits only
  all-Gaussian or all-pure-binomial-standard-link (`family_id_vec==0` / `==1` with `link ∈ {0,1,2}`);
  the X_lv design builder is at ~130–295 (`gll_lv_no_intercept_formula` → `model.matrix` →
  per-unit first-row extraction → `X_lv_B`), fed to TMB via `fit-multi.R` (~1741–1753, ~3161).
- **TMB template** (`src/gllvmTMB.cpp`): ordinary B-tier score mean+innovation at 784–815
  (`U_B_total = X_lv_B·alpha_lv_B + z_B`), spherical prior `z_B ~ N(0,1)` at 774–778, eta entry
  at 1802–1809, `ADREPORT(B_lv_unit)` at 814, `PARAMETER_MATRIX(alpha_lv_B)` at 473. The **phylo
  A⁻¹ GMRF machinery already exists** and is reusable: `DATA_SPARSE_MATRIX(Ainv_phy_rr)`,
  `log_det_A_phy_rr`, `n_aug_phy`, `species_aug_id` (286–291), the quadratic-form GMRF prior at
  1008–1017, `Lambda_phy`/`Sigma_phy` assembly at 1018–1020. Family dispatch is an isolatable
  lambda at 1951+ (`fid==0` = Gaussian).
- **Extractor** (`R/extractors.R`): `extract_lv_effects()` (583–702), `type ∈ {axis_effect,
  trait_effect}`, reads `fit$report$B_lv_unit` (626) + delta-SE from `sdreport(,"report")` (645),
  Wald intervals. Its guard at 605–609 **explicitly lists phylo as "planned"** — the hook.
  `extract_ordination()` (457–537). Reusable phylo-dispatch pattern in `R/extract-sigma.R`
  (~1080–1107). Recovery-test template: `tests/testthat/test-lv-gaussian-recovery.R`.
- **ADEMP harness** exists and is reusable: `dev/lv-wald-coverage-slurm.sh` + `dev/lv-wald-coverage.R`
  (one-seed-per-array-task grid, failed-fit denominators, MCSE), 500-rep production artifacts under
  `docs/dev-log/artifacts/lv-wald-coverage/`, pass band [0.92, 0.98]. Phylo DGP helpers exist:
  `ape::rcoal`/`ape::vcv`+Cholesky in `tests/testthat/test-phylo-dep-slope-s2-gaussian.R`,
  generic `R/simulate-site-trait.R`. `gllvmTMB_check_consistency()` in `R/check-consistency.R`.

### 0.2 Three corrections that change the plan

1. **The score mean attaches to the PHYLO tier, not the ordinary B tier.** The estimand is
   `B_lv_phy = Λ_phy · α_lv_phy^T`, and the axis innovation must carry the `A⁻¹` GMRF prior
   (`g_phy ~ MVN(0,A)`) — not the ordinary `z_B ~ N(0,I)`. So S3 adds **new** parameters
   (`alpha_lv_phy`, and the phylo score-mean/total blocks) on the phylo tier and re-routes the
   phylo eta contribution — it does **not** reuse `alpha_lv_B`/`z_B`. The *design-matrix builder*
   in `lv-predictor.R` can be reused (pointed at the species grouping), but the *score assembly*
   is new phylo-tier code. (Reconciles Probe A "reuse X-build" with Probe B "new phylo-tier score".)

2. **The profile "hero" CI for `B_lv` is ABSENT in current source** (resolves the item Design 76
   §7/references flagged UNVERIFIED). `R/profile-route-matrix.R`, `R/profile-targets.R`,
   `R/profile-derived.R` implement fix-and-refit profile CIs for ρ / communality / repeatability,
   but there is **no `B_lv`/`alpha_lv` route entry and no `profile_ci_lv_effects()`**; augmented
   tiers are marked `declared_blocked`. **Self–Liang / chi-bar-square boundary handling is also
   ABSENT** (profile machinery uses plain `qchisq(level, 1)`). Design 76 §5 assumed the profile
   hero existed; it must be **built** (new slice **S5a**) before the ADEMP gate can honor D-12.
   This is the single biggest scope surprise — see the sequencing decision in §3.

3. **Do not hang the extractor off `phylo_slope`.** The pre-existing phylo *random-slope* surface
   (`phylo_slope`, `alpha_phy_slope`, register `PHY-11..18`) is a **different arc** (a slope on the
   RE design, not a mean on the latent axis — Design 76 §1). The S4 extractor branch must key off
   the **new** `fit$use$lv_phy` flag and `fit$report$B_lv_phy`/`alpha_lv_phy`, mirroring the
   ordinary `trait_effect`/`axis_effect` path.

---

## 1. Slices, dependencies, and fan-out

Backbone follows Design 76 §7's S1–S6, with S5 split into **S5a (build the profile+boundary
machinery — newly discovered prerequisite)** and **S5b (the ADEMP campaign)**.

```
GOAL: a validated Gaussian phylo_latent(0+trait|species, d=K, lv=~x) fit whose public
      estimand B_lv_phy = Λ_phy α^T recovers + attains nominal coverage, profile as hero.
SEARCH: none external (source-grounded); brain doctrine cited, UNVERIFIED where noted.
PARALLEL: S1 alone first → then {S2 parser, S5a profile-machinery} can proceed in parallel
          (disjoint files) → S3 gated → {S4 extractor, S5b campaign build} → S6.
SEQUENTIAL: S3 ← S1 (+sign-off);  S4 ← S3;  S5b ← S3 & S5a;  S6 ← all.
GATE: S3 (TMB likelihood) is HIGH-RISK — do not start until maintainer authorizes + Gauss/Noether sign off.
```

| # | Slice | Lens | Risk | Depends on |
|---|-------|------|------|-----------|
| S1 | Symbolic ↔ R ↔ TMB alignment table + reduction proofs | Noether/Fisher | low (doc) | — |
| S2 | Parser: admit **Gaussian** `phylo_*(lv=~x)` only; all else rejected | Boole | med (grammar) | S1 |
| S3 | TMB likelihood: Gaussian phylo `B_lv_phy`, reuse `A⁻¹` GMRF | Gauss/Noether | **HIGH** | S1 + **sign-off** |
| S4 | Extractor: `extract_lv_effects`/`extract_ordination` phylo cell | Emmy | med | S3 |
| S5a | **Build** `B_lv` profile route + Self–Liang boundary reference | Fisher/Gauss | med–high | S1 (parallel w/ S2) |
| S5b | ADEMP recovery/coverage campaign (profile=hero) | Curie/Fisher | med | S3 + S5a |
| S6 | Verify + Rose claim audit + maintainer-authorization checkpoint | Rose/Shannon | — | all |

---

## 2. The slices in detail

Each slice: **input → output(path) → files/anchors → tests → verify → owner**. Every file
anchor is from the grounding pass (§0.1). "Reduce to" checks are the Noether reduction proofs.

### S1 — Symbolic ↔ R ↔ TMB alignment table (do FIRST; `symbolic-alignment` discipline)
- **Input:** Design 76 §4 (already a 5-row table), Design 73 (ordinary `lv`), Design 03 (phylo GMRF).
- **Output:** a completed alignment table committed as `docs/design/76-...` §4 amendment *or* a new
  `docs/dev-log/artifacts/xlv-phylo/S1-alignment-table.md`, mapping every symbol → R surface →
  **verified** `src/gllvmTMB.cpp` variable name (from §0.1), with the two reduction proofs written
  out as pass/fail predicates for S3's tests.
- **Files:** doc only. References `src/gllvmTMB.cpp:774–815,1008–1020,1802–1809`.
- **Reductions to state precisely (become S3 tests):**
  - *phylo-off (A=I / star tree):* the phylo score must reduce to the ordinary Design-73 score;
    a Gaussian `phylo_latent(...,lv=~x)` fit on a star tree must be **byte-identical** to the
    ordinary `latent(...,lv=~x)` fit on the same data.
  - *predictor-off (α=0):* reduces to the existing `phylo_latent` innovation-only model (register
    `PHY-02`).
  - *`B_lv_phy = Λ_phy α^T` rotation-invariance* for K>1 (raw α, raw Λ_phy are **not** pass/fail).
- **Verify:** Noether signs the table; the three predicates are written before any S3 code.
- **Owner:** Noether (+Fisher on identifiability of `Λ_phy Λ_phy^T + Ψ_phy` under a predictor mean).

### S2 — Parser (Boole): admit Gaussian `phylo_*(lv=~x)` only, preserve every other rejection
- **Input:** S1 contract.
- **Output:** parser changes on a feature branch; **no behavior change advertised**.
- **Files / anchors:**
  1. `R/brms-sugar.R` ~3117–3129: in the `phylo_latent → phylo_rr` rewrite, pass `lv` through as
     `lv_formula` (mirror the ordinary desugar at ~3184–3186); keep the Psi companion (~3218–3247)
     **lv-free** (intercept-only Ψ_phy).
  2. `R/brms-sugar.R` ~2195–2227: add a **narrow** exception so `phylo_latent` + `lv` is admitted
     **only** when the fit is Gaussian and the term is the plain intercept-bar form; every other
     source (`spatial_*`, `animal_*`, `kernel_*`), every other phylo keyword (`phylo_unique/_dep/
     _scalar/_indep/_rr/_slope`), augmented-LHS, and non-Gaussian stays rejected.
  3. `R/lv-predictor.R` ~119–128: extend the family guard to permit the phylo Gaussian cell
     (detected via the phylo covstruct marker), delegating to a phylo-specific validation that
     reuses the X_lv builder (~130–295) pointed at the species grouping.
- **Tests:** update the four guard suites to *move* the Gaussian-phylo case to an accept block while
  keeping all other rejections — `tests/testthat/test-lv-source-specific-guard.R`,
  `test-lv-parser-guard.R` (~814–856), `test-canonical-keywords.R` (~235–266),
  `test-lv-native-nongaussian-guard.R`. Add a parse-only test that a Gaussian
  `phylo_latent(0+trait|species,d=K,lv=~x)` yields a `phylo_rr` covstruct carrying `lv_formula`.
- **Verify:** `devtools::test(filter="lv-.*guard|canonical-keywords")` green; every non-target `lv`
  still aborts. **No TMB path exercised yet** (S2 can land parser+guard without S3 by keeping a
  downstream "not yet fittable" stop, or S2 stays on-branch until S3 — see §3 sequencing).
- **Risk:** formula-grammar change → Discussion-Checkpoint / high-risk per CLAUDE.md; do not merge
  to `main` without the maintainer authorization in S6.

### S3 — TMB likelihood (Gauss/Noether) — **HIGH-RISK, SIGN-OFF GATE**
- **Input:** S1 alignment + reductions; maintainer authorization.
- **Output:** `src/gllvmTMB.cpp` change + TMB-data assembly in `R/fit-multi.R`; recompiles; a
  Gaussian phylo `lv` fit runs and passes the S1 reductions + `checkConsistency()`.
- **Files / anchors (four insertion points, all verified in §0.1):**
  1. DATA (after ~291): `use_lv_phy`, `n_lv_phy`, `X_lv_phy` (species-level design, `n_aug_phy ×
     n_lv_phy`). **Reuse** existing `Ainv_phy_rr`, `log_det_A_phy_rr`, `n_aug_phy`, `species_aug_id`.
  2. PARAMETER: `alpha_lv_phy` (`n_lv_phy × d_phy`, layout mirrors `alpha_lv_B` at ~473); the phylo
     axis innovation reuses the existing phylo latent scores carrying the GMRF prior.
  3. Score-mean/total block (new, near the phylo score assembly): `score_k = e_phy(k,s) + Σ_h
     X_lv_phy(s,h)·alpha_lv_phy(h,k)`, then `ADREPORT(B_lv_phy = Λ_phy · alpha_lv_phy^T)`
     (mirrors 784–815 but on the phylo tier).
  4. Re-route the phylo eta contribution (mirror 1802–1809) and keep the GMRF prior (1008–1017) on
     the phylo innovation. Gate everything behind `use_lv_phy==1` so `use_lv_phy==0` is
     **byte-identical** to today's phylo path (stub params length-1 when inactive).
- **Isolation:** guard the new likelihood to `family_id_vec==0` (Gaussian) at the template + R
  level; the 1951+ dispatch already isolates `fid==0`.
- **Tests:** the S1 reductions as executable tests (star-tree byte-identity vs ordinary `lv`;
  α=0 → `PHY-02`); a small known-DGP recovery smoke; `gllvmTMB_check_consistency(fit, n_sim≥50)`
  centred, `|marginal bias|` small for `alpha_lv_phy`.
- **Verify:** Gauss + Noether sign-off on the diff; `checkConsistency()` clean; reductions pass.
- **Risk:** **HIGH** — likelihood + grammar. **Do not begin until §6 authorization.** No public
  wording; `LV-08` stays `blocked`.

### S4 — Extractor (Emmy): phylo cell in `extract_lv_effects` / `extract_ordination`
- **Input:** S3 `ADREPORT(B_lv_phy)`, `REPORT(alpha_lv_phy)`, `fit$use$lv_phy`.
- **Output:** phylo branch returning `B_lv_phy` (trait_effect, rotation-invariant, with SE/CI) and
  `alpha_lv_phy` (axis_effect, marked rotation-dependent), in the same data-frame shape as ordinary.
- **Files / anchors:** `R/extractors.R` — replace the "planned" guard at ~605–609 with a `phy`
  branch keyed off `fit$use$lv_phy` + `fit$report$B_lv_phy`/`alpha_lv_phy` (**not** `phylo_slope`);
  add a `phy` branch to `extract_ordination()` (~475–536); reuse the SE machinery
  (`.lv_sdreport_effect_se`, "report" for `B_lv_phy`). Mirror the phylo dispatch in
  `R/extract-sigma.R` (~1080–1107) for species-name/loading handling.
- **Tests:** mirror `tests/testthat/test-lv-gaussian-recovery.R` for the phylo cell (species tree,
  known `Λ_phy`, `alpha_lv_phy`, `B_lv_phy` truth); shape tests mirror `test-extractors.R` (~92–114).
- **Verify:** recovery test green; SE/CI finite/labelled; axis vs trait rotation status correct.
- **Owner:** Emmy (+Fisher on rotation handling).

### S5a — **Build the profile hero + boundary reference** (Fisher/Gauss) — *newly discovered prerequisite*
- **Why:** §0.2(2) — there is currently **no** `B_lv` profile route and **no** Self–Liang boundary
  code. Design 76 §5/§7 make profile the non-negotiable hero. So it must be built before S5b can
  claim a profile-hero gate.
- **Output:** a `profile_ci_lv_effects()` (or route-matrix entry) for `B_lv`/`B_lv_phy`, plus a
  boundary-corrected reference for the variance→0 / loading→0 / corr→±1 edges.
- **Files / anchors:** add a `B_lv`/`lv_phy` entry to `R/profile-route-matrix.R` (~13–97) and
  `R/profile-targets.R`; implement the constrained-refit profile in `R/profile-derived.R` (mirror
  `profile_ci_correlation()`/`profile_ci_communality()`); replace the plain `qchisq(level,1)`
  (~308) with a chi-bar-square mixture reference (Self–Liang 1987) **at the boundary cells**, or an
  (R)LRT bootstrap calibration. Follow the Design 74 profile-gate discipline (parse-stable target
  name; a pure test that the token maps to the intended `B_lv` entry; a small known-DGP
  truth-inclusion test; finite/labelled/one-sided-honest endpoints; move only the tested route).
- **Tests:** token-mapping unit test; known-DGP truth-inclusion; boundary-cell reference selected
  correctly.
- **Verify:** profile CI closes on the ordinary Gaussian `lv` cell first (cheaper, already
  validated by Wald) as a self-check, *then* is available to S5b.
- **Note:** this can run **in parallel with S2** (disjoint files) and does not need S3.
- **Decision it forces:** see §3 — whether S5a must land before *any* coverage claim, or the first
  Gaussian gate may report Wald+bootstrap while profile is built.

### S5b — ADEMP recovery/coverage campaign (Curie/Fisher) — Gaussian first, profile = hero
- **Input:** S3 fit + S5a profile route.
- **Output:** a coverage artifact under `docs/dev-log/artifacts/xlv-phylo/` meeting the register
  `LV-02` bar (≥500 reps/cell, one seed per array task, `sessionInfo()`, failed-fit denominators,
  per-rep outputs, MCSE on bias + coverage).
- **DGM (bake in the #715 sample-size lesson — a HARD input, not an afterthought):** Gaussian
  `phylo_latent(0+trait|species,d=K,lv=~x)`; fixed known `Λ_phy`, `α`, `Ψ_phy`; species innovation
  `e ~ MVN(0,A)` on a fixed tree (star tree for the phylo-off check, then a non-degenerate
  ultrametric tree). Grid over `(n_species, K, phylo-signal λ)` **sized so each cell carries enough
  information for the family + latent rank** — non-Gaussian/weak-signal cells need larger
  `n_species` (the #715 finding: same DGP false-converged at n=60, clean at n≥200). Include the
  known-hard cell p=80,K=2,λ=0.5 (the retired route's failure point) and the weak-signal regime
  where `Ψ_phy` vs `Λ_phy Λ_phy^T` is poorly identified (three-piece fallback).
- **Methods (the trio; profile hero):** Wald (`wald_z`, `wald_t_unit`) from delta-SE — expected
  *suspect* near the variance boundary; **profile** (hero, from S5a, with the Self–Liang reference);
  bootstrap as the calibration layer / fallback where profile won't close.
- **Files / anchors:** clone `dev/lv-wald-coverage-slurm.sh` + `dev/lv-wald-coverage.R` to
  `dev/phylo-lv-coverage-*`; reuse the grid/seed/health/summary schema; reuse phylo DGP helpers
  (`test-phylo-dep-slope-s2-gaussian.R`, `R/simulate-site-trait.R`); gate non-Gaussian on
  `checkConsistency()`. Compute on Totoro/DRAC (one seed per array task).
- **Targets:** bias with MCSE (recovery band max-abs-err <0.25 rank-1; `Σ_phylo` off-diag corr >0.90
  CRAN / >0.95 heavy); coverage 0.92–0.98 with MCSE, **reported per method** so profile-vs-Wald is
  explicit.
- **Verify:** artifact meets the `LV-02` production bar; a one-rep smoke is **not** evidence.
- **Owner:** Curie (recovery) + Fisher (coverage/boundary).

### S6 — Verify + Rose claim audit + maintainer-authorization checkpoint (Rose/Shannon)
- **Input:** S1–S5b outputs.
- **Output:** Rose after-task report; `LV-08` moves `blocked → partial` **only** when S5b delivers
  recovery + a first interval subclaim; public wording added **only** after Rose audits the claim;
  the maintainer authorization for grammar exposure and the coupled GLLVM.jl `PR #127` reopen is
  surfaced (Shannon) and obtained, not self-approved.
- **Verify:** `devtools::check()` + `pkgdown` local green; no capability over-claimed; every other
  `lv` rejection intact; brain-sourced D-12 details remain cited/UNVERIFIED where not re-derived.

---

## 3. Decisions to resolve at sign-off (surfaced by grounding)

These are genuine forks the grounding exposed; they want a maintainer (or Fisher/Noether) call
**before** S3, not silent defaults.

1. **Profile-hero sequencing (from §0.2(2)).** The profile hero for `B_lv` does not exist, and
   S5a is a real lift (constrained-refit route + Self–Liang boundary). Options:
   (a) **profile-first** — land S5a before *any* phylo coverage claim (honors D-12 literally,
   slower to first evidence); (b) **staged** — ship the first Gaussian *recovery + Wald/bootstrap*
   subclaim, with `B_lv` profile following as the claim that lifts `LV-08` to `partial`. Design 76
   §5/§7 lean (a); (b) is faster but must not quietly weaken the gate. **Recommend (b) with an
   explicit "profile pending" label on the interim artifact**, since S5a can build in parallel and
   the ordinary-`lv` cell gives S5a a cheap validation target. **This is a recommendation for the
   maintainer (with Fisher/Noether) to confirm before S5b begins — not a default.** If (b) is
   taken, the interim recovery + Wald/bootstrap subclaim must be labelled "profile pending" and
   must **not** be promoted (nor `LV-08` moved to `partial`) until the profile hero (S5a) lands;
   otherwise take (a). Either way the gate targets the population `B_lv`, never a realized
   `eta`-scale weakening (Design 76 §2.1).
2. **Score-mean tier wiring (from §0.2(1)).** Confirm the estimand is the phylo-tier
   `B_lv_phy = Λ_phy α^T` with the innovation carrying `A` (as Design 76 §4 states) — i.e. a new
   `alpha_lv_phy` on the phylo tier, not a reuse of `alpha_lv_B`. (This is the design intent;
   flagging because it dictates the S3 parameter surface.)
3. **Ψ_phy companion + `lv`.** Keep the auto-added `Ψ_phy` (unique=TRUE) companion **intercept-only
   / lv-free** (current parser does this). Confirm no user path threads `lv` onto Ψ_phy.
4. **S2/S3 merge coupling.** Because S2 is a grammar change that is meaningless without S3's
   likelihood, keep S2 **on-branch** until S3 is signed off (do not land a parser that admits a
   grammar the engine can't fit). Land S2+S3 together behind the authorization.

---

## 4. Non-negotiables (inherited from Design 76 §7 — do not relax)

- **Profile is the hero interval** with a boundary-corrected (Self–Liang) reference (D-12). It must
  be **built** (S5a), not assumed.
- **Gaussian is the mandatory first cell.** **No** inheritance of Gaussian evidence into
  non-Gaussian or other-source cells — each needs its own estimand, derivation, ADEMP gate, claim
  audit (Design 76 §2.3(4)).
- **No public wording** before the ADEMP gate passes **and** Rose audits the claim. `LV-08` stays
  `blocked` until then.
- **The S3 TMB change is HIGH-RISK** — maintainer authorization + Gauss/Noether sign-off before any
  engine code; `phylo_*(lv=~x)` stays fail-loud until then.
- **`pdHess=FALSE` ≠ failure**; route CIs through profile/bootstrap; read `fit$sd_report$pdHess`
  (not the `fit$sdr$pdHess` phantom). **Sample-size first** on any non-convergence (the #715 lesson).
- **Verify sub-agent/agent work by file ground-truth**, not self-reports.
- R and Julia doors (`PR #127`) move **only together and only on maintainer authorization** (Shannon).

---

## 5. The authorization gate (what needs Shinichi before S3)

Nothing in S3–S6 proceeds without this. Two coupled, currently-closed doors (Design 76 §7):

1. **R side:** authorize the Gaussian phylo `lv` grammar exposure + the HIGH-RISK TMB likelihood
   change (S2+S3). This is a Discussion-Checkpoint item.
2. **Julia side:** authorize reopening GLLVM.jl `PR #127` in lockstep (its v1 matrix's standing
   directive is "Do not reopen PR #127 from this arc" — a reopen is itself a maintainer decision).

The frozen Julia Gate 0–3 evidence de-risks the Gaussian phylo cell for a *realized `eta`-scale*
target but **licenses neither door**; this arc targets the harder *population* `B_lv` (Design 76
§2.3(1), §7).

---

## 6. Verification & consolidation (own the verifier)

- **Per slice:** the check named in each S-block (narrow `devtools::test` filters; `checkConsistency`;
  the ADEMP `LV-02` bar).
- **Whole-arc:** `devtools::check()` + local `pkgdown` green; a fresh-context **Rose** claim audit
  (no over-claim; every other rejection intact; `LV-08` state honest; UNVERIFIED items still marked).
- **Compute:** S5b runs on Totoro/DRAC (one seed per SLURM array task), mirroring the existing
  `dev/lv-*-coverage-slurm.sh` pattern.
- **Close-out:** Rose after-task report + register/`status.json` updates; `LV-08` moved only on
  delivered evidence.

---

## References
- `docs/design/76-structured-xlv-phylo.md` (design contract; §4 alignment, §5 ADEMP, §7 DECISION).
- `docs/design/73-predictor-informed-latent-scores.md`, `73-profile-likelihood-route-matrix.md`,
  `74-augmented-profile-target-table.md`, `03-phylogenetic-gllvm.md`, `35-validation-debt-register.md`
  (`LV-08`).
- Verified source anchors: `R/brms-sugar.R`, `R/lv-predictor.R`, `src/gllvmTMB.cpp`,
  `R/extractors.R`, `R/extract-sigma.R`, `R/profile-route-matrix.R`, `R/profile-targets.R`,
  `R/profile-derived.R`, `R/check-consistency.R`, `dev/lv-wald-coverage*.{sh,R}`.
- Doctrine (cited; brain items UNVERIFIED where not re-derived here): `memory/LESSONS.md`
  (sample-size vs algorithm-failure; pdHess), `memory/DECISIONS.md` D-12 (profile hero).
- Morris, White & Crowther (2019) *Statist. Med.* 38:2074–2102; Self & Liang (1987) *JASA*
  82:605–610.
