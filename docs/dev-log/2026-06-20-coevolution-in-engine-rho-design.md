# Design note: in-engine `rho` estimation for the Design 65 coevolution kernel

**Date:** 2026-06-20
**Author:** Claude (read-only analysis; no engine code changed)
**Scope:** Design 65 cross-lineage coevolution kernel (`make_cross_kernel`,
the multi-kernel TMB block, `extract_Gamma`). This note evaluates whether the
bridge strength `rho` should become a *free TMB parameter estimated inside the
fit* instead of the current *fixed-and-profiled* scalar.
**Status of the feature today:** `rho` is **fixed** at kernel-construction time
and only **profiled** post hoc. There is no in-engine estimation.
**Baseline:** all `file:line` citations are against `origin/main`
(`92e246b`), the branch base.
**Decision:** **DESIGN-NOTE-ONLY.** Recommendation at the end: **keep fixed-rho
profiling for now; do not add an in-engine `rho` parameter yet.** Reasoning is
the identifiability section.

---

## 1. Where `rho` lives today

### 1.1 Construction time (R, fixed scalar)

`rho` is a constructor argument to `make_cross_kernel()` and enters the kernel
*multiplicatively* on the cross-lineage off-diagonal block only:

- `R/kernel-helpers.R:44` — `make_cross_kernel(A_H, A_P, W, rho = 0.5, eps = 1e-8)`.
- `R/kernel-helpers.R:89-90` — `W_scaled <- W / max(spectral_norm, eps)` then
  `C_HP <- rho * L_H %*% W_scaled %*% t(L_P)`. The within-lineage diagonal
  blocks `A_H`, `A_P` carry **no** `rho`; only the host-partner bridge does.
- `R/kernel-helpers.R:96-97` — the assembled `K` is symmetrised and its diagonal
  is reset to 1, so `rho` controls *only* the off-diagonal correlation mass.
- `R/kernel-helpers.R:100-108` — a PSD check rejects `K` whose minimum eigenvalue
  is below `-1e-6`; this is the constraint that forces `|rho| <= 1` in practice
  (the spectral scaling of `W` makes `|rho| <= 1` sufficient for PSD).
- `R/kernel-helpers.R:110-115` — the chosen `rho` is stored as metadata
  (`attr(K, "gllvmTMB_cross_kernel")$rho`) so downstream extractors can recover
  it. `.cross_kernel_rho()` (`R/kernel-helpers.R:307-315` region) reads it back.

So today `rho` is **baked into the numbers of `K`** before the fit ever sees it.

### 1.2 Fit time (the engine never sees `rho`)

The multi-kernel engine consumes the *already-built* dense `K_r` matrices; it has
no notion of `rho`:

- `R/fit-multi.R:2248` — `kernel_rho <- .cross_kernel_rho(K)` merely *reads the
  recorded metadata* for reporting; it is not a parameter.
- `R/fit-multi.R:2292` — `Ainv_kernel[r, , ] <- solve(K_jit)`: the precision is
  formed once from the fixed `K_r` and passed to TMB as **data**.
- TMB prior (`src/gllvmTMB.cpp:1068-1080`): each kernel tier draws standard latent
  scores `g_kernel` with quadratic form `g' Ainv_kernel(r) g` and the fixed
  `log_det_A_kernel(r)`. `Ainv_kernel` is `DATA_ARRAY` (`src/gllvmTMB.cpp:290`),
  not a `PARAMETER`. There is no path by which the optimiser can move `rho`.
- The estimable trait-side object is the loading block `Lambda_kernel`
  (`src/gllvmTMB.cpp:1046-1066`), constrained lower-triangular with a free
  diagonal, giving `Sigma_kernel(r) = Lambda_r Lambda_r^T`.

### 1.3 Post-hoc profiling (the current "estimation" surrogate)

`rho` is selected, not estimated, by a grid profile:

- `R/kernel-helpers.R:166` — `profile_cross_rho(A_H, A_P, W, rho, refit, ...)`
  rebuilds `K` over a user grid and returns a `logLik` table with `delta_deviance`
  and an `is_best` flag (`R/kernel-helpers.R:229-256` region).
- A companion profile-likelihood **CI** helper, `profile_cross_rho_ci()`, exists
  on the in-flight branch `claude/coevo-rho-ci-20260620` (not yet on
  `origin/main`). It adds a `1.92`-drop (chi-square 1 d.f.) interval on top of the
  same grid. It is still a *profile over fixed rebuilds*, not in-engine estimation.

Design 65 C3.3 names this gap explicitly: "in-engine `rho` estimation, `rho`
profile intervals, broader interval coverage ... remain future work"
(`docs/design/65-cross-lineage-coevolution-kernel.md:120`).

---

## 2. How `rho` *could* be estimated inside the fit

### 2.1 Parameterization (mirror the GP correlation idiom already in the engine)

The engine already maps an unbounded scalar into a correlation with `tanh`:

- `src/gllvmTMB.cpp:1245` — `Type rho = tanh(atanh_cor_b(0));` for the augmented
  `phylo_dep` 2x2 cross-field covariance; the SPDE analogue is
  `src/gllvmTMB.cpp:1531`.

Reuse that exact pattern. Add one free scalar per cross-lineage tier:

```
PARAMETER_VECTOR(atanh_rho_kernel);   // length n_kernel_tiers (or n_cross_tiers)
...
Type rho_r = tanh(atanh_rho_kernel(r));   // rho_r in (-1, 1)
```

`atanh_rho_kernel` is a *fixed effect* (not in the `random` vector), initialised
at `0` (i.e. `rho = 0`, the within-lineage null `K* = blockdiag(A_H, A_P)`). The
`tanh` map keeps `|rho| < 1`, which is the constraint that `make_cross_kernel()`'s
PSD check currently enforces by rejection.

### 2.2 Where it enters the kernel — build `K_r` *inside* TMB, not in R

The hard part: today `rho` is fused into `K_r` in R and only `Ainv_kernel` (a
precision) reaches TMB. To estimate `rho`, the *off-diagonal block must depend on
the parameter*, so the kernel can no longer be precomputed as opaque data. Two
viable shapes:

**Option A — pass the building blocks, reconstruct `K_r(rho_r)` in C++.**
Stop passing `Ainv_kernel`; instead pass as data the pieces that `make_cross_kernel`
combines:

- `A_H`, `A_P` (the diagonal blocks), and the *scaled, square-rooted* bridge
  `B = L_H W~ L_P^T` (everything in `R/kernel-helpers.R:84-90` *except* the `rho`
  multiply). Then inside TMB:
  `K_r = [[A_H, rho_r * B], [rho_r * B^T, A_P]]`, `diag(K_r) = 1`.
- The penalty needs `K_r^{-1}` and `log det K_r` as differentiable functions of
  `rho_r`. The current block uses precomputed `Ainv_kernel` and
  `log_det_A_kernel` (`src/gllvmTMB.cpp:1068-1080`). Those become
  per-evaluation: a dense Cholesky `K_r = L L^T`, solve, and
  `log det = 2 sum log diag(L)`. This is the real cost — a dense `O(n^3)`
  factorisation of an `n_kernel_levels x n_kernel_levels` matrix **at every
  optimiser/inner step**, autodiffed through `rho_r`. Today it is done once in R.
- PSD is automatic only if `|rho_r| <= 1` AND the spectral scaling holds; the
  `tanh` map guarantees `|rho_r| < 1`, and the same spectral-scaling argument that
  justifies the R-side PSD check carries over, so no explicit PSD penalty is
  needed (the Cholesky will fail loudly otherwise, which TMB handles as `+Inf`
  nll).

**Option B — keep the kernel fixed, estimate a separate cross-block scalar.**
Instead of rebuilding `K_r`, build the kernel at `rho = 1` (full off-diagonal
mass) and let an estimated scalar `s_r = tanh(atanh_rho_kernel(r))` scale the
*cross-covariance contribution to `eta`* rather than the kernel itself. This avoids
re-factorising `K_r`, but it changes the model: the penalty is then on scores under
a fixed `K(rho=1)` while the cross signal is scaled in the mean. That is *not* the
same likelihood as estimating `rho` in the covariance, and it muddies the
`Gamma = Lambda_H Lambda_P^T` interpretation. **Option B is rejected** as a
semantic change; Option A is the faithful one.

### 2.3 R-side wiring (Option A)

- `R/fit-multi.R:2248-2292` region: stop calling `solve(K_jit)` for cross-lineage
  tiers; instead extract `A_H`, `A_P`, `B` from the kernel (these are
  recoverable: `make_cross_kernel` already records `host_levels`,
  `partner_levels`, `spectral_norm_W` in the metadata at
  `R/kernel-helpers.R:110-115`; `B` needs to be added to that metadata, or
  recomputed from `A_H`, `A_P`, `W`). Pass them as new `DATA_*` blocks.
- Add `atanh_rho_kernel` to `tmb_params` and leave it *out* of the `map` so it is
  estimated; for the legacy fixed-rho path, pin it via the `map` (factor `NA`) at
  `atanh(rho_fixed)` so the existing fixed-rho fits stay byte-identical.
- After the fit, report `rho_hat_r = tanh(atanh_rho_kernel_hat(r))` and its SE via
  the delta method or `TMB::sdreport(ADREPORT(rho_r))`. `extract_Gamma(scale =
  "effect")` (`R/extract-sigma.R:1474`, `.gamma_level_rho` at
  `R/extract-sigma.R:1694`) would then read the *estimated* `rho` instead of the
  recorded fixed metadata — with the caveat in section 3.

---

## 3. Identifiability: is `rho` separable from the loading scale / `Gamma`
magnitude?

**This is the load-bearing concern, and the answer is: not cleanly, in the
general case.** The cross-block covariance the model implies is (Design 65 model
contract, `docs/design/65-cross-lineage-coevolution-kernel.md:40`):

```
Cov(eta_{H,ia}, eta_{P,jb}) = Gamma_ab . K_HP,ij
  with  Gamma = Lambda_H Lambda_P^T   (trait loadings)
        K_HP  = rho . (L_H W~ L_P^T)   (the species-level bridge)
```

So the host-partner covariance is a **product** `Gamma_ab * rho * B_ij`. The data
constrain that product. The split between the scalar `rho` and the magnitude of
`Gamma` (i.e. the scale of `Lambda_H`, `Lambda_P`) is **not** pinned by the
cross-block alone:

- Scaling `rho -> c.rho` and `Lambda_H -> Lambda_H / c` (or `Lambda_P -> Lambda_P /
  c`) leaves the **cross-block** covariance unchanged. `rho` and the cross-loading
  magnitude trade off along a ridge.

What *partially* breaks the tie is that `Lambda_H`, `Lambda_P` also appear in the
**within-lineage** blocks, which `rho` does not touch:

- Within-host: `Var(eta_H) = (Lambda_H Lambda_H^T) (x) A_H` — independent of `rho`
  (the diagonal block `A_H` carries no `rho`, `R/kernel-helpers.R:92-97`).
- Within-partner: likewise with `A_P`.

So `||Lambda_H||` and `||Lambda_P||` are anchored by the within-lineage trait
covariances, and `rho` is then (in principle) identified by the *residual* cross-block
mass after those magnitudes are fixed. **In principle** `rho` is identified. **In
practice** it is weak, for three compounding reasons:

1. **Single-`W` replication (literature-mandated).** The cross signal is one shared
   association matrix `W` — "a single shared `W` is only ONE replicate of the
   coevolution signal -> `Gamma` precision is limited" (Design 65 evidence base,
   `docs/design/65-cross-lineage-coevolution-kernel.md:178`; Boettiger et al.
   2012). Estimating an *extra* free scalar `rho` off the same one-replicate signal
   makes the `rho`-vs-`Gamma`-magnitude ridge near-flat in small designs.

2. **Rotation/reflection of `Lambda`.** `Gamma` is identified only up to the
   loading-rotation constraints; the engine enforces lower-triangular `Lambda` with
   a free diagonal (`src/gllvmTMB.cpp:1046-1058`), which fixes orientation but the
   *sign/scale* interplay with a free `rho` still needs a sign convention (e.g.
   pin `rho >= 0` and let `Lambda` carry sign, or vice versa) to avoid a
   `(rho, Lambda) -> (-rho, -Lambda_P)` flip.

3. **Kernel-overlap collinearity (multi-tier).** With two cross-lineage tiers, the
   existing separability machinery (`diagnose_kernel_separability()`,
   `fit$kernel_diagnostics`, the high-overlap warning at
   `R/fit-multi.R:2338-2348` region) already flags that component-specific `Gamma`
   separation is weak under overlapping kernels. A free per-tier `rho_r`
   multiplies that fragility: two `rho_r` and two `Lambda_r` magnitudes against one
   overlapping signal.

**Net:** `rho` is *theoretically* separable from `Gamma` magnitude because the
within-lineage blocks anchor the loading scale, but the separation is **fragile**
and design-dependent (number of realised host-partner links, tip replication,
kernel overlap). An in-engine `rho` will often hit the `tanh` boundary
(`|rho| -> 1`) or have an SE so wide as to be uninformative — exactly the symptom
already observed for the *profile*: "the best grid point can sit at the high edge"
(`docs/design/65-cross-lineage-coevolution-kernel.md:120`).

---

## 4. Minimal incremental implementation plan (if/when we proceed)

Strictly TDD, one engine PR in flight (the Design 65 serialization rule). Each step
has a verification gate.

1. **Identifiability simulation FIRST (no engine code).** Before touching TMB, run a
   recovery sim that estimates `rho` by an *outer* optimiser over the existing
   fixed-rho refit (i.e. `optim` wrapping `profile_cross_rho`'s `refit`), across a
   grid of (a) tip replication, (b) `W` density, (c) true `rho`. **Gate:** does the
   profile likelihood in `rho` have a single interior maximum with a finite
   curvature-based SE in the *good* regime, and does it go flat/boundary in the
   thin-`W` regime? This decides whether an in-engine parameter is even worth
   adding. Pure R; reuses `profile_cross_rho` / `profile_cross_rho_ci`.
2. **Single-tier C++ `rho` (Option A), behind a flag.** Add `atanh_rho_kernel`
   (`src/gllvmTMB.cpp`, mirror line `1245`), pass `A_H`/`A_P`/`B` as data, rebuild
   `K_r(rho_r)` + dense Cholesky for the penalty. **Gate (non-negotiable):** with
   `atanh_rho_kernel` pinned via `map` at `atanh(rho_fixed)`, the fit is
   byte-identical (`logLik`, `Lambda`, `Sigma` to `< 1e-6`) to the current
   fixed-rho path. This is the same discipline as the KER-02 phylo-equivalence gate.
3. **Free single-tier `rho` recovery gate.** Heavy Gaussian DGP with known
   `rho_true`; **gate:** `rho_hat` within a defended band of `rho_true` AND a finite
   `sdreport` SE in the good regime; document boundary behaviour in the thin-`W`
   regime rather than widening tolerances.
4. **`ADREPORT(rho_r)` + extractor wiring.** Surface `rho_hat`, SE, and a Wald/
   profile interval; make `extract_Gamma(scale = "effect")` consume the *estimated*
   `rho` with an explicit "estimated, not fixed" provenance flag so users do not
   silently double-count uncertainty.
5. **Multi-tier (`rho_r` per cross tier) — only after step 3 is clean.** Gate on the
   existing kernel-overlap diagnostics: refuse (or loudly warn) to free `rho_r` for
   tiers flagged `high` overlap.

### Risks

- **Performance.** Per-evaluation dense Cholesky of `K_r` (autodiffed) replaces a
  one-time R `solve()`. For large `n_kernel_levels` this is the dominant new cost
  and may dwarf the rest of the inner problem.
- **Boundary estimates.** `tanh` boundary pile-up (`rho -> +/-1`) in thin-`W`
  designs; needs a documented diagnostic, not a silent clamp.
- **Sign aliasing.** `(rho, Lambda_P) -> (-rho, -Lambda_P)` flip; needs a sign
  convention.
- **Double-counting uncertainty.** Users currently treat fixed `rho` as known;
  estimated `rho` changes the meaning of every downstream `Gamma_effect`,
  `predict_cross_covariance`, and module extraction. Provenance must be explicit.
- **Cross-package divergence.** drmTMB mirrors the `kernel_*()` contract; an
  estimated-`rho` parameter is an API/likelihood change and must go through the
  shared ledger, not ship unilaterally.

---

## 5. Recommendation

**Keep fixed-`rho` profiling for now. Do NOT add an in-engine `rho` parameter in
the current arc.** Reasons, in priority order:

1. **Identifiability is fragile, not absent (section 3).** `rho` and the
   cross-loading magnitude trade off along a ridge that is only broken by the
   within-lineage blocks and by tip/`W` replication. The Design 65 evidence base
   already establishes that a single shared `W` is one replicate; adding a free
   scalar onto that signal is the wrong place to spend the next increment.
2. **The profile already delivers the scientifically honest object.**
   `profile_cross_rho()` + the in-flight `profile_cross_rho_ci()` give a profile
   likelihood and a 1.92-drop interval — which is *exactly* what an in-engine `rho`
   would be summarised by anyway, but without the per-evaluation Cholesky cost or
   the boundary/sign hazards, and without changing the likelihood or the
   cross-package API.
3. **Sequencing.** Design 65 C3.3 still lists the *more fundamental* gaps as open:
   harder moderate-overlap calibration, broader high-overlap recovery, reusable
   null/Type-I thresholds, interval coverage, module uncertainty, and the
   `*_unique()` lifecycle (`docs/design/65-cross-lineage-coevolution-kernel.md:120`).
   Those should land before turning `rho` into a parameter; otherwise we add an
   identifiability-sensitive parameter on top of an arc that has not yet pinned its
   simpler claims.

**Concrete next step if the maintainer wants to move toward estimation:** do
section 4 step 1 only — the *outer-optimiser identifiability simulation in pure R*.
It is zero-engine, reuses the existing profiler, and produces the evidence that
decides whether an in-engine parameter is worth the cost. Promote to the C++ work
(steps 2+) only if that sim shows a usable interior maximum with finite curvature in
the realistic-design regime.

---

## Appendix: anchor map (origin/main, 92e246b)

| Concern | File:line |
|---|---|
| `rho` constructor arg | `R/kernel-helpers.R:44` |
| `rho` enters cross-block only | `R/kernel-helpers.R:89-90` |
| diagonal reset (rho only off-diagonal) | `R/kernel-helpers.R:92-97` |
| PSD rejection (the `|rho|<=1` constraint) | `R/kernel-helpers.R:100-108` |
| `rho` recorded as metadata | `R/kernel-helpers.R:110-115` |
| `profile_cross_rho()` | `R/kernel-helpers.R:166` |
| reads recorded rho (reporting only) | `R/fit-multi.R:2248` |
| fixed precision passed to TMB | `R/fit-multi.R:2292` |
| `Ainv_kernel` is DATA, not PARAMETER | `src/gllvmTMB.cpp:290` |
| `Lambda_kernel` lower-triangular loadings | `src/gllvmTMB.cpp:1046-1066` |
| fixed kernel prior (quad form) | `src/gllvmTMB.cpp:1068-1080` |
| `tanh` correlation idiom to reuse | `src/gllvmTMB.cpp:1245` (SPDE twin `1531`) |
| `extract_Gamma(scale="effect")` | `R/extract-sigma.R:1474` |
| `.gamma_level_rho()` (reads fixed rho) | `R/extract-sigma.R:1694` |
| C3.3 "still partial" (lists rho estimation as future) | `docs/design/65-cross-lineage-coevolution-kernel.md:120` |
| single-`W` = one replicate | `docs/design/65-cross-lineage-coevolution-kernel.md:178` |
| cross-block product `Gamma . K_HP` | `docs/design/65-cross-lineage-coevolution-kernel.md:40` |
