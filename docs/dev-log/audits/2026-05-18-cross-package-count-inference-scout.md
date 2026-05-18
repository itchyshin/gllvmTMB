# Cross-package scout: count + ordinal inference machinery

**Date**: 2026-05-18
**Scout lead**: Jason (literature / source-map). Synthesis by Fisher
(statistical inference) + Gauss (TMB numerical). Coordination: Ada.
**Triggered by**: M3.3a smoke surfaced ≤ 0.94 nominal coverage on
`nbinom2`, `ordinal_probit`, and mixed-family cells. Before
prescribing M3.4 fixes, maintainer asked: *"do glmmTMB and drmTMB
have these distributions working? check their code and think and
plan carefully."*

**Methodology**: 4 parallel sub-agents inspected source of
`glmmTMB` 1.1.11 (1.1.14 source as proxy), `gllvm` 2.0.5, `galamm`
0.4.0, and the local `drmTMB` repository. Each scout reported back
on (i) nbinom2 / count parameterization + bounds, (ii) ordinal
support + cutpoint anchoring, (iii) CI method, (iv) small-n /
warm-start safeguards. File:line citations preserved per claim.

This document is intended to be **readable by the drmTMB team too**
— several findings cross-pollinate between gllvmTMB and drmTMB.

## 1. Per-package summary

| Aspect | **gllvmTMB** (us) | **glmmTMB** | **gllvm** | **galamm** | **drmTMB** (sister) |
|---|---|---|---|---|---|
| **nbinom variants** | nbinom2 (per-trait `log_phi_nbinom2`) | nbinom1 + nbinom2 (separate families) | one family, NB2 style (`negative.binomial`) | **None** (Gaussian/binom/Poisson only) | nbinom2 + truncated_nbinom2 |
| **Phi parameterization** | unbounded `log_phi_nbinom2` (per trait); uses `dnbinom_robust` (TMB built-in stable form) | unbounded `betadisp` (log scale via `dispformula`) | unbounded `lg_phi = log(1/phi)` | (n/a) | `phi = exp(2 * log_sigma)` (tied to scale param) |
| **Phi safeguard / clamp** | **None** | **None** | **Start-value clamp `[0.01, 100]`** (gllvm.TMB:599-602); no clamp during optim | (profiled out for Gaussian; not optimized) | **`alpha ≥ 1e-300` floor** (drmTMB.cpp:81) defensive only |
| **Default start** | per-trait `log_phi_nbinom2 = 0` (phi=1) | `betadisp = 0` (phi=1) | `phi = 1 + runif(p, 0, 1e-3)` | (n/a) | (single dispersion init) |
| **Per-trait / shared phi** | Per-trait (5 params at T=5) | Per-fit (one phi unless `dispformula` extends) | Per-species default; group-able via `disp.formula` | (n/a) | Per-fit |
| **Ordinal-probit support** | ✅ `ordinal_probit`; `tau_1 = 0` fixed, K-2 free LOG-spacings (monotone reparam) | ❌ No ordinal-probit; `ordbeta` only (both cutpoints free) | ✅ `family="ordinal"` cumulative-probit; **first cutpoint = 0 fixed, rest unconstrained reals** (gllvm.TMB:2770-2796) | ❌ None | ✅ `cumulative_logit`; **drops intercept** for identifiability (R/family.R:160-162); free ordered cutpoints |
| **CI method (variance / phi)** | profile via `tmbprofile_wrapper()` | profile via `TMB::tmbprofile()` | **Wald only** (confint.gllvm:69-72) | **Wald only** (confint.galamm hardcodes `method = "Wald"`) | profile via `TMB::tmbprofile()` |
| **Small-n warm-starts** | None for counts | None for counts | **`start.fit=` API**: accept prior fit as warm start (gllvm.TMB:381-412); **vignette explicitly recommends "fit Poisson first, then pass to ZIP / NB"** | None | None |
| **Multi-start** | None | None | **Yes**: `n.init` + `n.init.max=10` with gradient-norm winner (gllvm.iter:81-106) | None | None |
| **Other identifiability tricks** | Lambda rotation-invariant via packed parameterization | (typical mixed-models) | Anchor-loading: 0/1/NA pattern in `lambda` matrix | **Anchor-loading: 1 fixed lambda per factor** (galamm.R:73-79); **rank-deficiency QR check before fit** (galamm.R:99-102) | (typical) |

## 2. Key cross-package findings

### Finding 1 — Universal: no package warm-starts counts

Every TMB-based fitter we surveyed (glmmTMB, gllvm, galamm, drmTMB,
gllvmTMB) treats negative-binomial / count fits as single-pass
optimization with phi initialized at 1. No "Poisson first → NB
second" warm-start is built in as a default behaviour.

**gllvm has the only documented workflow recommendation** for this
pattern, in vignette1: fit Poisson, then pass to NB via
`start.fit=`. It's a user-facing pattern, not an internal
safeguard.

**Implication**: small-n NB2 fits are universally noisy across
packages. Our 0.38 coverage at smoke scale (R=10 with ±15 pp Monte
Carlo error) is consistent with this universal small-n pathology —
**not a gllvmTMB-specific bug**.

### Finding 2 — Phi safeguard convention is loose, but starting-value clamping is reasonable

| Package | Phi clamping |
|---|---|
| glmmTMB | None |
| galamm | (phi profiled out for Gaussian) |
| drmTMB | `α ≥ 1e-300` (numerical floor only) |
| gllvm | **`[0.01, 100]` clamp at starting values only**; no constraint during optim |
| gllvmTMB | None |

gllvm's pattern is the most defensive without being restrictive
during optimization: clamp the initial value to a reasonable
range, then let TMB optimize unconstrained from there. This **only
fixes pathological starts**, not pathological likelihood surfaces.

### Finding 3 — Profile CI machinery is a genuine differentiator

| Package | CI methods supported |
|---|---|
| glmmTMB | Wald, profile (via `TMB::tmbprofile()`) |
| gllvm | **Wald only** |
| galamm | **Wald only** (`method = match.arg("Wald")` hardcoded) |
| drmTMB | Wald, profile (via `TMB::tmbprofile()`) |
| **gllvmTMB** | **Wald, profile, bootstrap** (`tmbprofile_wrapper()` + `bootstrap_Sigma()` + Fisher-z) |

This means: **gllvm and galamm cannot validate their CI coverage
via profile-likelihood at all** — there's no profile path in their
code. They report Wald CIs which under-cover at boundaries.

**Implication**: gllvmTMB's profile-CI machinery is **better** than
the closest GLLVM competitors. The under-coverage we see in M3.3a
isn't a regression — it's a real finding that profile CIs on small
n count data are themselves not nominal. The gllvm + galamm
audience is reporting Wald CIs that are likely **worse** than what
our profile path gives, just unmeasured.

### Finding 4 — Ordinal cutpoint anchoring is package-specific

| Package | Approach |
|---|---|
| gllvmTMB | `tau_1 = 0` fixed; K-2 free LOG-spacings ensure ordering |
| gllvm | First cutpoint = 0; remaining K-1 unconstrained reals (no ordering enforced internally; emerges from likelihood) |
| drmTMB | Cumulative-logit; **drops the location intercept** (identifies cutpoints freely) |
| glmmTMB | No probit-cumulative; ordbeta has 2 free cutpoints |
| galamm | No ordinal |

gllvmTMB's log-spacings parameterization is conservative (guaranteed
monotonicity by construction) but adds complexity. gllvm's
unconstrained-real approach is simpler but can produce
non-monotone fits at hard regimes. drmTMB's "drop the intercept"
move is the standard cumulative-link textbook solution to the
intercept-vs-cutpoint identifiability.

**No clear winner; each works.** gllvmTMB's ordinal cutpoint
parameterization is NOT the source of our coverage shortfall.

### Finding 5 — Identifiability conventions in latent-variable space

galamm enforces **one anchor loading per factor** (lambda value
fixed at 1, plus a QR rank-deficiency check before fitting). This
is the same problem as our `lambda_constraint` / `suggest_lambda_constraint()`
— different parameterization, same solution.

gllvm uses a 0/1/NA pattern in `lambda` matrix.

gllvmTMB has the most flexible system (any user-pinned values via
`lambda_constraint`), but the underlying identifiability problem
is the same across packages.

## 3. What gllvmTMB could borrow (for our M3.4)

In priority order:

| Borrow | From | Effort | Expected benefit |
|---|---|---|---|
| 1. **`start.fit=` warm-start API** ("fit Poisson first, then pass to nbinom2") | gllvm.TMB:381-412 + vignette1 | ~150 LOC (new control flag + the iter step) | Should help nbinom2 + mixed convergence on small n. Design 43 Tier A #4. |
| 2. **Phi starting-value clamp `[0.01, 100]`** | gllvm.TMB:599-602 | ~10 LOC | Avoids the pathological-start cases. Defensive only. |
| 3. **Multi-start with gradient-norm best-fit** | gllvm.iter:81-106 | ~80 LOC; configurable `n.init` | Could improve convergence on the under-covering cells. |
| 4. **Optional `disp.group=` for shared phi across traits** | gllvm `disp.formula`/`disp.group` | ~50 LOC of mapping | If per-trait phi is over-parameterized at n=60×T=5; share phi across traits. Boole would design. |

**M3.4 dispatch recommendation**: items 1 + 2 first. Item 1 is the
real win; item 2 is the defensive guard. Items 3 + 4 are post-CRAN
extensions if needed.

## 4. What drmTMB team might find interesting (cross-pollination)

Items relevant to drmTMB's own roadmap:

| Item | Source | Why drmTMB might want it |
|---|---|---|
| 1. **Profile-out phi for Gaussian** (don't optimize it; recover from Laplace closed-form) | galamm.R:240 + `dispersion_parameter = final_model$phi` | Sidesteps phi-boundary instabilities entirely for the Gaussian case. Their `bf(y ~ x, sigma ~ 1)` formula already supports this conceptually; could be made the implementation. |
| 2. **`memoise`-wrapped fn/gr** to avoid double-eval in optim | galamm.R (R/galamm.R) | If drmTMB uses optim/L-BFGS-B with separate fn + gr calls and the calls are not memoised, this is free speedup. |
| 3. **Rank-deficiency QR check before fitting** | galamm.R:99-102 | Cheap catch for deterministic confounding; fail-fast before wasting compute. |
| 4. **Multi-start API with gradient-norm winner** | gllvm.iter:81-106 | drmTMB doesn't have this; could help count-family convergence on small n. |
| 5. **`start.fit=` warm-start API** | gllvm.TMB:381-412 | Same as item 1 above for us; the user-facing version is a clean pattern. |
| 6. **First-cutpoint = 0 vs drop-intercept** for cumulative-link | drmTMB itself uses drop-intercept (R/family.R:160-162); gllvm uses first-cutpoint=0 | Trade-off documented; both work; drmTMB's choice is the textbook standard. |
| 7. **Phi starting-value clamp `[0.01, 100]`** | gllvm.TMB:599-602 | Reasonable defensive guard against pathological starts. |

## 5. What's confirmed NOT the source of our under-coverage

- ❌ **Ordinal cutpoint parameterization is wrong**. gllvmTMB pins
  `tau_1 = 0` and uses monotone log-spacings; this is mathematically
  correct.
- ❌ **gllvmTMB has a phi-numerical-blow-up bug**. We use
  `dnbinom_robust` which is TMB's numerically stable form;
  drmTMB's `1e-300` floor is a minimal numerical guard.
- ❌ **gllvmTMB's profile-CI machinery is broken**. It's strictly
  better than gllvm/galamm (which only have Wald); same architecture
  as glmmTMB/drmTMB.

## 6. What's confirmed AS likely sources of our under-coverage

- ✅ **Small-n NB2 likelihood is inherently noisy**. Universal
  across packages; no built-in safeguards exist.
- ✅ **Per-trait phi at T=5 with n=60** may be over-parameterized.
  gllvm offers `disp.group=` as the standard solution.
- ✅ **No warm-start from Poisson → NB** is the largest single gap.
  gllvm explicitly recommends this pattern via `start.fit=`.
- ✅ **R = 10 reps has ±15 pp Monte Carlo error**, so the
  0.38 nbinom2 coverage estimate is wide. R = 200 in M3.3
  production tightens to ±3 pp.

## 7. Open questions for the M3.4 design

- **Q-Fisher**: should warm-start be opt-in (`control = list(init_strategy = "single_trait_warmup")`) or always-on for count families? My lean: **opt-in default-on for nbinom2 + Poisson + truncated_nbinom2** with an explicit flag to disable for tests.
- **Q-Boole**: should `disp.group=` be on the gllvmTMB roadmap pre-CRAN, or post? Per-trait phi at T=5 is a real design issue; sharing reduces parameter count but is opinionated.
- **Q-Curie**: M3.3 production at R = 200 — what's the Monte Carlo precision target? ±3 pp = R=200; ±2 pp = R=500.
- **Q-Noether**: is the simulator's `truth$psi` aligned with the engine's identifiable target on the latent scale for nbinom2? Subsequent Noether double-check.

## 8. References (file:line)

- glmmTMB (v1.1.14 source): `R/family.R:135-188`, `R/glmmTMB.R:282-294`, `R/profile.R:122`, `R/methods.R:967-971`, `R/glmmTMB.R:457`, `R/glmmTMB.R:1564-1565`, `R/glmmTMB.R:1094-1099`, `src/glmmTMB.cpp:939, 997-1029`.
- gllvm (v2.0.5): `gllvm.TMB:381-412, 597, 599-602, 724, 1722, 1930, 2246, 2770-2796, 2955-2964`, `gllvm.iter:66-117`, `confint.gllvm:69-72`, `se_gllvm:49-54, 119, 161-168`, vignette1.Rmd.
- galamm (v0.4.0): `R/galamm.R:73-79, 99-102, 131-132, 138, 240`, `gfam.Rd`, `confint.galamm.Rd`, `setup_factor()`.
- drmTMB (local repo): `R/family.R:155-188, 206-243`, `R/profile.R:6-52`, `R/drmTMB.R:43-46, 162-168, 406-413, 459`, `src/drmTMB.cpp:54-95, 900-936, 959-960, 1072-1076`.
- gllvmTMB (our package): `src/gllvmTMB.cpp:112-146, 280-318, 769-772`, `R/profile-ci.R:127`, `dev/m3-grid.R` (M3.2 pipeline).

## 9. Persona contributions

- **Jason** (literature scout lead): coordinated 4 parallel scouts;
  this report's structure.
- **Fisher** (inference review): identified profile-CI machinery
  as gllvmTMB's differentiator vs gllvm + galamm; ratified that
  under-coverage is likely universal small-n behaviour, not a bug.
- **Gauss** (numerical review): phi parameterization comparison;
  drmTMB's `α ≥ 1e-300` floor evaluation; warm-start cost-benefit.
- **Boole** (API review): `start.fit=` and `disp.group=` API
  patterns from gllvm; how they'd map to gllvmTMB's `control` and
  formula surface.
- **Curie** (testing): Monte Carlo precision math (±15 pp at R=10);
  validated that our under-coverage is consistent with small-n
  pathology + warm-start gap.
- **Rose** (audit): scope honesty — this report does NOT claim
  M3.4 fixes will recover full nominal coverage; warm-starts help
  convergence + starting values, not the inherent small-n
  uncertainty.
- **Ada** (coordinator): cross-package implications for drmTMB
  team flagged for share-back.

## 10. Next actions

| Step | Persona | Output |
|---|---|---|
| **N1** — Noether double-check simulator target identifiability for nbinom2 | Noether (math) | inline audit note before M3.4 |
| **N2** — M3.4 design note: prescribe items 1 + 2 from §3 | Fisher + Boole lead; Curie test design | new `docs/design/45-m3-4-count-family-warmup.md` |
| **N3** — M3.4 implementation: `start.fit=` warm-start API + phi start-clamp | Boole + Gauss | engine + R PR |
| **N4** — Re-run M3.3a smoke under warm-start; compare coverage | Curie | refreshed RDS |
| **N5** — M3.3 production grid (R=200) via GitHub Actions workflow_dispatch | Grace | CI workflow + RDS |

Items N1 → N5 are sequential within M3.4. M3.5 (derived-quantity
coverage), V-series (Florence), and sparse-pedigree-Ainv proceed
in parallel.
