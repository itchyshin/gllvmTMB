# S1 — Symbolic ↔ R ↔ TMB alignment contract: Gaussian `phylo_latent(..., lv = ~ x)`

Date: 2026-07-06 · Owners: **Noether** (math↔impl), **Fisher** (identifiability).
**Status: CONTRACT ONLY (S1 of the Option A execution plan). No engine code, no grammar
change. Every runtime row is currently fail-loud (Design 76 §3).** This document is the
target map that S2 (parser), S3 (TMB), S4 (extractor), and S5b (ADEMP) must each match
term-by-term. It supersedes/completes Design 76 §4 with the **verified** `src/gllvmTMB.cpp`
variable names from the 2026-07-06 grounding pass (`main` @ `13686230`).

The discipline (symbolic-alignment skill): write the decomposition first; then the DGP draws
N pieces, the formula has N terms, and recovery extracts N things. Any symbol present in the
math but missing a DGP-draw or a recovery column is the bug. A latent factor is always paired
with its unique/residual partner (`Λ_phy` with `Ψ_phy`).

---

## 0. Model statement (the six-term decomposition)

For species `s = 1..S`, trait `t = 1..T`, latent axis `k = 1..K`, lv-design column
`h = 1..p_lv`. `A` is the `S×S` phylogenetic correlation matrix (sparse `A⁻¹` from the tree).

```
(1)  score (phylo tier):   z_s   = M_s α + e_s,     e_{·,k} ~ MVN(0, A)          [innovation carries A]
(2)  reduced-rank map:     u_st  = Σ_k Λ_phy(t,k) · z_s(k)                        [factor]
(3)  unique/residual:      q_st,  with q_{·,t} ~ MVN(0, ψ_phy(t) · A)            [Λ_phy's partner]
(4)  linear predictor:     η_st  = β_t + u_st + q_st                             [no fixed X_lv row in C1]
(5)  observation:          y_st  ~ N(η_st, σ_ε²)                                 [Gaussian, family_id 0]
(6)  public estimand:      B_lv  = Λ_phy α^T   (T×p_lv, rotation-invariant)      [the target]
```

Phylo covariance decomposition (the tier law): `g_phy ~ MVN(0, Σ_phy ⊗ A)`,
`Σ_phy = Λ_phy Λ_phy^T + Ψ_phy` (Design 03). Three-piece fallback when `Ψ_phy` is not
separately identifiable: `Ω = Λ_phy Λ_phy^T + Λ_non Λ_non^T + Ψ`.

Reductions this must satisfy (proofs in §3): **phylo-off** (`A = I` ⇒ ordinary Design-73
`lv`), **predictor-off** (`α = 0` ⇒ existing `phylo_latent` innovation-only, register
`PHY-02`), **rotation-invariance** of `B_lv` for `K > 1`.

---

## 1. Master alignment table

Columns: **Symbol** · **R surface (keyword / covstruct / extractor)** · **TMB variable
(file:line; E = exists, N = new in S3)** · **DGP draw (S5b)** · **Recovery extractor** ·
**Truth**. Anchors verified in `src/gllvmTMB.cpp` and `R/*` on `main`.

| # | Symbol | R surface | TMB variable (E/N) | DGP draw | Recovery | Truth |
|---|--------|-----------|--------------------|----------|----------|-------|
| 1 | predictor design `M_s` (row of `X_lv_phy`) | `phylo_latent(0+trait\|species, d=K, lv = ~ x)`; desugars to `phylo_rr(..., lv_formula=~x)` (`R/brms-sugar.R` ~3117–3129, mirror ordinary ~3184–3186); built by `gll_lv_*` (`R/lv-predictor.R` ~130–295) pointed at the **species** grouping | `X_lv_phy` **(N)**, `S×p_lv`; `n_lv_phy` **(N)** | `x_s` drawn once per species, constant within species; `M_s` = model.matrix row (no intercept) | (design; not an estimand) | fixed `x_s` |
| 2 | axis coefficients `α` (`p_lv×K`) | `extract_lv_effects(fit, type="axis_effect")` (phylo cell, S4) | `alpha_lv_phy` **(N)**, `n_lv_phy×d_phy` (layout mirrors `alpha_lv_B`, `src/gllvmTMB.cpp:473` E) | fixed known `α` | axis_effect (rotation-**dependent**, secondary) | `α` (not a pass/fail target) |
| 3 | phylo innovation `e_{·,k} ~ MVN(0,A)` | (internal random effect of the phylo tier) | `g_phy` **(E)** carrying the GMRF prior via `Ainv_phy_rr` (`DATA_SPARSE_MATRIX` :289 E), `log_det_A_phy_rr` :290, `n_aug_phy` :288, `species_aug_id` :291; prior quad-form :1008–1017 | `e = L_A Z`, `L_A = chol(A)`, `Z ~ N(0,I_{S×K})`; **star tree ⇒ `A=I`** for phylo-off | `extract_ordination(level="phy")` innovation component (S4) | `A` (tree) |
| 4 | latent score total `z_s = M_sα + e_s` | (internal) | `U_lv_mean_phy` + `G_phy_total = X_lv_phy·alpha_lv_phy + g_phy` **(N)** (mirror `U_B_total`, :784–815 E) | `z_s = M_sα + e_s` | `extract_ordination(level="phy", component="total")` (S4) | derived |
| 5 | reduced-rank loadings `Λ_phy` (`T×K`) | `phylo_latent(..., d=K)`; `getLoadings`-style access | `Lambda_phy` **(E)** (`:1018`); assembled from `theta_rr` packing | fixed known `Λ_phy` (lower-tri, +diag convention) | (via `Σ_phy` / not raw for K>1) | `Λ_phy` (not pass/fail for K>1) |
| 6 | eta contribution `u_st = Σ_k Λ_phy(t,k) z_s(k)` | (internal) | phylo eta re-route (mirror `:1802–1809` E): `score_k = (use_lv_phy? G_phy_total : g_phy)` **(N branch)** | `u_st = (Λ_phy z_s)_t` | (in fitted `η`) | derived |
| 7 | **unique partner** `q_{·,t} ~ MVN(0, ψ_phy(t)·A)` | `phylo_latent(..., unique=TRUE)` → auto Ψ companion (`R/brms-sugar.R` ~3218–3247), **kept lv-free** | `Ψ_phy` diagonal in `Sigma_phy` (`:1019` E) | `q_{·,t} = √ψ_phy(t) · L_A Z_t` | `extract_Sigma(level="phy")` diagonal (`R/extract-sigma.R` ~1080–1107 E) | `ψ_phy` (T-vec, broad band) |
| 8 | intercepts `β_t`, residual `σ_ε` | `0 + trait` LHS; Gaussian family | `b_fix`, `sigma_eps` **(E)** | fixed `β`, `σ_ε` | fixed-effect table | `β`, `σ_ε` |
| 9 | **public estimand** `B_lv = Λ_phy α^T` (`T×p_lv`) | `extract_lv_effects(fit, type="trait_effect")` (phylo cell, S4) | `B_lv_phy = Lambda_phy * alpha_lv_phy.transpose()`; `ADREPORT(B_lv_phy)` **(N)** (mirror `B_lv_unit` :809–814 E) | `B_lv = Λ_phy α^T` (computed from truth) | trait_effect + delta-SE from `sdreport(,"report")` | `B_lv` (**primary**) |
| 10 | phylo covariance `Σ_phy = Λ_phyΛ_phy^T + Ψ_phy` | `phylo_latent(unique=TRUE)` folded form | `Sigma_phy` (`:1019` E) | `Σ_phy` from `Λ_phy,ψ_phy` | `extract_Sigma(level="phy")` | off-diag pattern (secondary) |

**Completeness check (skill rule).** Ten symbols; each has a DGP-draw column and a recovery
column, except the pure design/derived rows (1, 4, 6, 8) which are inputs or intermediates,
not estimands. The factor `Λ_phy` (rows 5–6) is paired with its unique partner `Ψ_phy` (row
7): **no standalone shared-axis factor without its `Ψ` companion.** The only genuinely **new**
TMB objects S3 must add are `X_lv_phy`, `n_lv_phy`, `use_lv_phy`, `alpha_lv_phy`, and the
`U_lv_mean_phy`/`G_phy_total`/`B_lv_phy` blocks — the innovation reuses the **existing** `g_phy`
+ `Ainv_phy_rr` GMRF machinery (see §2).

---

## 2. Plumbing note for S3 (recommended, for Gauss)

The phylo innovation `e_s` **is** the existing mean-zero random effect `g_phy` that already
carries the `MVN(0,A)` GMRF prior (`:1008–1017`). Under `lv`, the *total* latent score becomes
`G_phy_total = X_lv_phy·alpha_lv_phy + g_phy`; `Λ_phy` multiplies the **total** in the eta map.
This means:
- **No new random-effect parameter** for the innovation — reuse `g_phy` (keeps the GMRF prior
  and its `log_det_A_phy_rr` normalizer untouched). Only `alpha_lv_phy` (a fixed parameter),
  `X_lv_phy`/`n_lv_phy` (data), and `use_lv_phy` (flag) are added.
- **Byte-identity for free** when `use_lv_phy==0`: `G_phy_total ≡ g_phy` (mean 0), so the phylo
  path is unchanged (reduction §3.1's implementation side).
- (Probe B sketched a separate `g_phy_lv` parameter; the reuse-`g_phy` form above is simpler and
  is what the byte-identity reduction wants. Final choice is Gauss's at S3, but the contract is
  the same either way: the innovation carries `A`, the mean is `X_lv_phy·α`.)

---

## 3. Reduction proofs (executable predicates — become S3 tests)

Each is a pass/fail predicate a future `tests/testthat/test-lv-phylo-structured-recovery.R`
must encode. `tol` = `1e-6` unless noted.

### 3.1 Phylo-off (star tree, `A = I`) ⇒ ordinary Design-73 `lv`
**Claim.** With `A = I_S` (a star phylogeny), row 3's prior `e_{·,k} ~ MVN(0,I) = N(0,I_K)`,
so the phylo score (1) becomes `z_s = M_s α + e_s`, `e_s ~ N(0,I_K)` — *identically* the
ordinary Design-73 unit-tier score (`z_i = M_i α + e_i`). Hence a Gaussian
`phylo_latent(0+trait|species, d=K, lv=~x)` fit on a star tree must equal the ordinary
`latent(0+trait|species, d=K, lv=~x)` fit on the same data.
**Predicate (byte-identity).** On one dataset with `A=I`:
`abs(logLik(fit_phylo) − logLik(fit_ordinary)) < tol` **and**
`max(abs(B_lv_phy − B_lv_unit)) < tol` **and** identical converged parameter vectors up to the
rotation convention. (Mirrors the wide/long byte-identity discipline used across the register.)

### 3.2 Predictor-off (`α = 0`) ⇒ existing `phylo_latent` innovation-only (`PHY-02`)
**Claim.** With `α = 0`, the mean `M_s α = 0`, so (1) reduces to `z_s = e_s`, `e_{·,k}~MVN(0,A)`
— the already-covered `phylo_latent(species, d=K)` innovation-only model.
**Predicate.** With `alpha_lv_phy` fixed at `0` (mapped off), the Gaussian phylo-`lv` fit equals
the plain `phylo_latent(species, d=K)` fit: `abs(Δ logLik) < tol`, identical `Λ_phy`/`Σ_phy` up
to rotation. Confirms the `lv` machinery adds *only* the mean and does not perturb the innovation
prior or its normalizer.

### 3.3 `B_lv` rotation-invariance (`K > 1`)
**Claim.** For any orthogonal `R` (`K×K`), the reparameterization `Λ_phy → Λ_phy R^T`,
`α → α R^T` leaves both the likelihood and `B_lv` invariant:
`(Λ_phy R^T)(R z_s) = Λ_phy z_s` (eta unchanged) and
`B_lv = (Λ_phy R^T)(R α^T) = Λ_phy α^T` (estimand unchanged).
Therefore raw `α` and raw `Λ_phy` are **not identified** without a rotation convention and are
**not** pass/fail recovery targets; only `B_lv = Λ_phy α^T` (and `Σ_phy`) are.
**Predicate.** For a fitted `K≥2` model, applying any random orthogonal `R` to
`(Λ_phy, α)` changes `max(abs(ΔΛ_phy))`, `max(abs(Δα))` by `O(1)` but leaves
`max(abs(Δ B_lv_phy)) < tol`. Recovery/coverage (S5b) targets `B_lv_phy` only.

---

## 4. Identifiability notes (Fisher)

- **`Λ_phy Λ_phy^T + Ψ_phy` under a predictor mean.** Adding `M_s α` shifts the *mean* of the
  latent score; it does not touch the covariance decomposition. But in the weak-signal /
  small-`S` regime the separation of `Ψ_phy` from `Λ_phy Λ_phy^T` is poorly identified (the
  three-piece fallback `Ω = Λ_phyΛ_phy^T + Λ_nonΛ_non^T + Ψ`); S5b's grid must include this
  cell (it is the retired route's known-hard point p=80,K=2,λ=0.5, Design 76 §5).
- **Boundary behaviour.** `ψ_phy(t) → 0`, loading `→ 0`, phylo signal `λ → 0/1` put variance
  parameters on their boundary — the LR reference is a chi-bar-square mixture, **not** `χ²₁`
  (Self–Liang 1987). This is why the profile hero (S5a) needs a boundary-corrected reference;
  it is **absent** in current source and must be built.
- **Sample size is a hard input, not an afterthought.** Per the #715 lesson, a non-Gaussian /
  weak-signal latent fit can false-converge at small `S` (blew a loading to −110 at `n=60`,
  clean at `n≥200`, same DGP). S5b sizes `S` to the family + latent rank. *(Doctrine from
  `memory/LESSONS.md`; the specific #715 figures are re-derived in the gllvmTMB after-task
  record 2026-07-06.)*

---

## 5. What S1 licenses (Rose)

Nothing runtime. This is a contract: it names the symbols, binds each to a verified (or
explicitly new) TMB variable and a recovery extractor, and states the three reductions as
testable predicates. It **claims no capability** — `LV-08` stays `blocked`, the grammar stays
fail-loud, and no parameter, parser branch, or extractor is added by this document. S2/S3/S4/S5
must each be checked back against this table; a term added to code with no row here, or a row
here with no code, is the defect the alignment discipline exists to catch.

## References
- `docs/design/76-structured-xlv-phylo.md` §4 (target table this completes), §5 (ADEMP), §7.
- `docs/design/73-predictor-informed-latent-scores.md` (ordinary `lv`), `03-phylogenetic-gllvm.md`
  (`Σ_phy ⊗ A`, three-piece fallback), `74-augmented-profile-target-table.md` (profile gate).
- Verified anchors: `src/gllvmTMB.cpp:289–291,473,774–815,1008–1020,1802–1809`;
  `R/brms-sugar.R:~3117–3129,3184–3186,3218–3247`; `R/lv-predictor.R:~119–128,130–295`;
  `R/extractors.R:583–702`; `R/extract-sigma.R:~1080–1107`.
- Self & Liang (1987) *JASA* 82:605–610; Morris, White & Crowther (2019) *Statist. Med.* 38:2074.
