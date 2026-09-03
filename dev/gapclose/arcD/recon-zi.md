# Recon: Zero-Inflated Families for gllvmTMB (Arc D)

Worktree: /Users/z3437171/local-scratch/lanes/gllvmTMB-arcD-zi-20260902
Oracles: GLLVM.jl (origin/main), drmTMB (origin/main)

## A. gllvmTMB family hooks

**Highest family_id in use: 16 (multinomial). Next free ids: 17, 18, 19.**
**Highest FAM register row: FAM-20 (+ FAM-20A..F sub-rows). Next free FAM id: FAM-21.**

| Hook | File:line | Note |
|---|---|---|
| C++ fid dispatch (per-row obs_loglik) | `src/gllvmTMB.cpp:3044` `if (fid == 0) {` ... chain through `fid == 16` at `:3282` | Add `else if (fid == 17) { ... }` before the final `else { error(...) }` at `:3280`. fid==16 (multinomial) is special-cased to error here because it's evaluated at its anchor row, not per obs_loglik call -- a ZI family would NOT need that pattern (it's a per-row mixture). |
| C++ dispersion PARAMETER_VECTOR block | `src/gllvmTMB.cpp:1230-1263` e.g. `PARAMETER_VECTOR(log_phi_nbinom2);` L1230, `log_phi_truncnb2` L1257 | A zi_nbinom2 would reuse `log_phi_nbinom2` (per comment at L1230) or need its own; a zi_poisson needs no dispersion param but needs a new `logit_zi` (or similar) PARAMETER_VECTOR, length n_traits. |
| C++ trait-family gating comment | `src/gllvmTMB.cpp:733` "sigma_eps is mapped off when no row has family_id_vec(o) in {0, 3}" | Pattern for how a new family must be added to every such per-family gate list, not just the density switch. |
| C++ likelihood density calls | `src/gllvmTMB.cpp:3091` (`dbinom`), `:3095` (`dpois`), `:3119`/`:3188`/`:3275` (`dnbinom_robust`) | zi density = mixture: `log(pi0 + (1-pi0)*dpois(0,mu)) if y==0 else log(1-pi0) + dpois(y,mu,log=T)`, evaluated inline per-row like the existing dpois/dnbinom_robust calls. |
| R family_to_id() switch | `R/fit-multi.R:1163-1180` (see also comment block `:1108-1122`) | New family names go in the `switch(f$family, ...)` here with new integer ids 17/18/19; comment block above must be updated too. |
| R constructors (family objects) | `R/families.R:318` `truncated_poisson <- function(link = "log")`, `:297` `nbinom2 <- function(...)`, `:578` `betabinomial <- function(...)` | New `zi_poisson()`/`zi_nbinom2()`/`zi_binomial()` constructors go here, same shape (`link=`, returns `family` S3 object). |
| R dispersion trait-map wiring | `R/fit-multi.R:6368-6377` `mask_nbinom2 <- dispersion_trait_family_mask(trait_id, family_id_vec, 5L, n_traits)` then `tmb_map$log_phi_nbinom2 <- m_nbinom2` | Every dispersion (and now zi-prob) parameter needs an analogous mask+map pair keyed on its new family_id. |
| R diagnose.R family-id gates | `R/diagnose.R:605` `binomial_rows <- family_id == 1L & ...`, `:1287` `ordinal_rows <- family_id == 14L` | check_gllvmTMB() degeneracy detectors are opt-in per family_id; a ZI family gets none unless added explicitly (cf. multinomial's issue #897 gap noted in FAM-20 above). |
| R predictive-diagnostics.R family gates | `R/predictive-diagnostics.R:444` `saturating_family <- any(row_meta$family_id %in% c(0L, 3L, 4L, 7L, 9L))`, `:1115` `count_rows <- draws$row_data$family_id %in% ...` | Count-family lists here must be extended to admit zi_poisson/zi_nbinom2 for PIT/residual diagnostics. |
| R simulate() | `R/methods-gllvmTMB.R:1443` `simulate.gllvmTMB_multi <- function(...)` | No per-family rng dispatch visible near the entry point in the grepped region; likely a further per-family switch deeper in the function body (not read -- budget). |
| R error message enumerating supported families | `R/fit-multi.R:1187` `"i" = "Currently supported: {.code gaussian()}, ..."` | Must append new family names here or users get a misleading error listing. |
| Zero-truncated count guard (adjacent pattern) | `R/fit-multi.R:3753-3755` | Shows the pattern for family-specific input validation/guard messages (zero-truncated require y>=1); ZI families have the opposite constraint direction (no restriction on zero, but the density needs the mixture branch). |
| docs/design/02-family-registry.md | `:442` "Zero-inflated count families on multi-trait fits (planned; post-CRAN)." | ZI is explicitly on the roadmap as `planned`, distinguished from delta/hurdle (`:435-441`, single-eta hurdle already exists via delta_lognormal/delta_gamma fid 12/13). |
| docs/design/62-two-part-family-naming-and-scope.md | `:12,19,38-39` | **Naming discipline**: reserve `zi_*` strictly for true zero-inflation (extra zero-generating process on top of the count mass); delta/hurdle families (already fid 12/13) must NOT be called "zero-inflated" -- category error per this doc. |

## B. 14-slot contract (docs/design/02-family-registry.md L27-70)

```
Each family constructor returns a small structured object with
the following slots:

- `name` — canonical family name (e.g. `"nbinom2"`, `"gaussian"`)
- `n_response` — 1 for univariate families; multi-trait fits
  stack the univariate density per row
- `dpars` — distributional parameters as a named character
  vector (e.g. `c("mu", "sigma")`)
- `links` — link function per parameter (identity / log / logit /
  probit / cloglog / inverse / atanh / logm2)
- `inverse_links` — closed-form inverse
- `bounds` — valid response support
- `density_id` — integer code passed to the TMB template
  (`src/gllvmTMB.cpp`)
- `simulate` — simulate-from-fitted closure for
  `simulate.gllvmTMB_multi()` (M2 family-aware rewrite work)
- `starting_values` — closure mapping data summary to initial
  parameter values
- `check_data` — closure validating that the response vector
  matches the family's bounds and dimensions
- `native_parameter_meaning` — the meaning of each `dpar` on the
  link scale (e.g. `mu` = log-mean for Poisson; not arithmetic
  mean of `y`)
- `fitted_response_rule` — what `fitted()` returns (mean of `y`,
  expected category score, hurdle conditional mean, etc.)
- `variance_rule` — formula for `Var(y)` given the parameters
  (or "no finite variance" if applicable)
- **`link_residual_rule`** — gllvmTMB-specific. The latent-scale
  residual variance used for mixed-family correlation reporting
  on the implied trait covariance. See "Link Residual Contract"
  below.
```

**No slot for a "zero-inflation probability" parameter or its link.** `dpars` would need to grow a `pi_zi` (or `zi`) entry with its own link (logit) alongside `mu` -- this is a real gap: nothing in the 14 slots names a second, non-mean, per-observation-or-per-trait distributional parameter that ISN'T a dispersion (`log_phi_*` already has precedent via `native_parameter_meaning` for e.g. nbinom2 phi, but zi's `pi_zi` is architecturally the same shape as a dispersion param: per-trait, own link, own PARAMETER_VECTOR).

## C. Julia oracle (GLLVM.jl)

No `src/*zero*` or `src/*zi*` filenames; ZI lives inside `src/families/twopart.jl` (shared file with the hurdle/delta families). Test files: `test/test_zero_inflated.jl` (main), plus `test_bridge_zib.jl`, `test_bridge_zip_nox.jl`, `test_postfit_zib_tweedie.jl`, `test_zib_x_identity.jl`, `test_zinb_x_identity.jl`, `test_zip_x_identity.jl`.

**Mixture, NOT hurdle** (`src/families/twopart.jl:1028` comment header):
```
P(y=0) = π + (1−π)·p₀,   P(y=k) = (1−π)·count(k)   (k ≥ 1)
with π = logistic(η^z) and the count mean μ = exp(η^c)
```
This is the key structural difference from gllvmTMB's existing delta/hurdle families (fid 12/13, `delta_lognormal`/`delta_gamma`): a hurdle has the count process ACTIVE ONLY for y>0 (truncated-at-zero count + separate presence Bernoulli); a true ZI mixture has the count process active at every observation, so y=0 carries count-part Fisher information too (`Icc` computations at `:1052`/`:1059` are nonzero at y=0). docs/design/62 (gllvmTMB) explicitly reserves `zi_*` for this and calls the hurdle-as-"zero-inflated" framing a category error -- Julia's naming/comment agrees exactly.

**Zero probability parameterisation: per-trait (species) intercept-only, `π = logistic(η^z)`, no covariates in v1.** Explicit in the comment (`:1040-1043`): *"the zero-inflation is per-species intercept-only (Λ_z = 0 — only β^z)... Letting Λ_z load on z would need the 2×2 cross-term machinery; that is a deliberate future extension."* So structural-zero prob does NOT vary by observation/covariate yet, only by species (trait). Link = logit.

**Family structs and dispersion:**
| Julia struct | family | count link | dispersion |
|---|---|---|---|
| `ZIPoisson` (`:1074`) | ZIP | log (μ=exp(ηc)) | none |
| `ZINB` (`:1314`, public alias `ZINegBin` `:1424`) | ZINB | log | **one shared scalar `r`** (NB2-style, `p = r/(r+μ)`), NOT per-trait -- `ZINBCovFit` docstring (`:1427`) states "one shared scalar NB2 dispersion `r`" |
| `ZIB` (`:1586`) | zero-inflated binomial, N trials | logit (μ=inv.logit(ηc)) | N (trials), not a free dispersion param |

Each `_tp_pieces` returns `(score_z, score_c, Wz, Wcc, logf)` — `logf` is exactly the mixture log-density above, split y==0 / y>0.

**DGP + tolerance (`test/test_zero_inflated.jl:1-80`):**
- Exact-reduction tests (`Λ=0` reduces to independent ZIP/ZINB loglik): `atol = 1e-8` against a hand-rolled reference loop.
- Limiting-case tests (`π→0` reduces to Poisson marginal; `r→∞` ZINB reduces to ZIP): `atol = 1e-4` / `atol = 1e-2`.
- Recovery test `fit_zip_gllvm` (`:66` on): p=8, K=2, n=400, `βz_true = 0.4·randn(p) - 0.8` (~30% structural zeros), `βc_true = 0.4·randn(p) + 1.2`, `Λc_true = 0.5·randn(p,K)` -- standard GLLVM-style DGP identical in shape to the package's other count-family recovery cells.

## D. drmTMB oracle (origin/main)

`src/` tree: `drmTMB.cpp`, `drm_count_kernels.h`, `drm_numeric.h`, `drm_response_kernels.h`, `init.c`. No dedicated `zip.h`/`zi*.h` file — ZI lives inline in `drmTMB.cpp` as `model_type == 6` ("zi_poisson") and (by the same pattern, R side `model_type = if (has_zi) "zi_nbinom2" else "nbinom2"`, `R/drmTMB.R:8238`) `zi_nbinom2`. **No GPL/licence header block found in the first 15 lines of `src/drmTMB.cpp`** (starts directly with an Apple-clang `Rconfig.h`/`TMB.hpp` include workaround comment) — could not confirm licence provenance from the header alone within budget.

**ZIP log-density (`src/drmTMB.cpp:4104-4117`, `model_type == 6` block), verbatim:**
```cpp
vector<Type> mu = exp(eta_mu);
vector<Type> zi = Type(1.0) / (Type(1.0) + exp(-eta_zi));
for (int i = 0; i < y.size(); ++i) {
  if (observed_y(i) == 1 &&
      !(has_mi == 1 && mi_family != 0 && mi_observed(i) == 0)) {
    Type log_zi = -logspace_add(Type(0.0), -eta_zi(i));
    Type log_one_minus_zi = -logspace_add(Type(0.0), eta_zi(i));
    if (asDouble(y(i)) == 0.0) {
      nll -= weights(i) * logspace_add(log_zi, log_one_minus_zi - mu(i));
    } else {
      nll -= weights(i) * (log_one_minus_zi + dpois(y(i), mu(i), true));
    }
  }
}
REPORT(eta_mu); REPORT(mu); REPORT(eta_zi); REPORT(zi);
ADREPORT(beta_mu); ADREPORT(beta_zi);
```
(`log_zi`/`log_one_minus_zi - mu(i)` is `logspace_add(log(zi), log(1-zi)-mu)` = `log(zi + (1-zi)*exp(-mu))`, the same mixture form as the Julia oracle's `P(y=0) = π + (1-π)p0`.)

**Key architectural difference from GLLVM.jl: `eta_zi = X_zi * beta_zi` is a FULL linear predictor with its own design matrix and its own logit link (`PARAMETER_VECTOR(beta_zi)` at `:472`), not an intercept-only per-trait scalar.** The zi component even supports a spatial term (`R/drmTMB.R:7397` `extract_gaussian_mu_spatial_term(zi_entry, dpar = "zi")`). drmTMB is univariate/bivariate (per Project Identity in CLAUDE.md), so this "per-observation covariates" richness has no direct trait-stacking precedent to port — gllvmTMB's own dispersion parameters (`log_phi_nbinom2` etc.) are per-trait scalars only, not per-observation with covariates.

**R constructor names:** not standalone `zip()`/`zinb()` — ZI is a **modifier on `poisson()`/`nbinom2()`** via a `zi` formula component (`dpars == "zi"`, `has_zi` flag at `R/drmTMB.R:7728`/`:8238`), i.e. `poisson(..., zi = ~x)`-style dpar syntax rather than a separate family constructor. `model_type` strings: `"zi_poisson"`, `"zi_nbinom2"`.

**NB2 dispersion:** not grepped explicitly in the read window; drmTMB's ordinary `nbinom2()` presumably keeps its own `log_phi`-style scalar per response (not reconfirmed for the zi_nbinom2 branch specifically — budget).

## E. Symbolic alignment table (DRAFT)

| Symbol | Meaning | Julia (GLLVM.jl) | drmTMB | Proposed gllvmTMB |
|---|---|---|---|---|
| `π` / `zi` | structural zero-generating probability | `π = logistic(η^z)`, per-trait intercept-only (`Λ_z=0`) | `zi = logistic(eta_zi)`, `eta_zi = X_zi·beta_zi` full per-observation linear predictor | **per-trait intercept-only for v1** (matches Julia oracle, and matches gllvmTMB's existing dispersion-parameter shape, e.g. `log_phi_nbinom2` per-trait): new `PARAMETER_VECTOR(logit_zi)` length n_traits, logit link |
| `μ` | count mean | `μ = exp(η^c)` | `mu = exp(eta_mu)` | `mu = exp(eta_o)` (existing linear predictor machinery, unchanged) |
| NB dispersion | count-process overdispersion | `r` (NB2 shape), **one shared SCALAR across all fits** in `ZINB`/`ZINegBin` | not confirmed (see D) | reuse `log_phi_nbinom2` (per-trait, matching gllvmTMB's existing nbinom2 convention) — a DELIBERATE departure from Julia's shared-scalar `r`, since gllvmTMB already treats nbinom2 dispersion as per-trait everywhere else |
| Density (mixture-at-zero form), zi_poisson | `y=0`: `log(π + (1-π)·exp(-μ))`; `y>0`: `log(1-π) + dpois(y,μ,log=T)` | identical form, `zi`/`eta_zi` in place of `π`/`η^z` | identical: `y=0`: `logspace_add(log(zi), log(1-zi) - mu)`; `y>0`: `log(1-zi) + dpois(y,mu,log=T)` | same mixture form, TMB `logspace_add()` idiom (matches drmTMB's numerically-stable pattern exactly) |
| Density, zi_nbinom2 | `y=0`: `log(π + (1-π)·p0)`, `p0=(r/(r+μ))^r`; `y>0`: `log(1-π) + logpdf(NB(r, r/(r+μ)), y)` | (pattern implied, not directly read) | | `y=0`: `logspace_add(logit_zi_logscale, log(1-zi) + dnbinom_robust(0,...))`; `y>0`: `log(1-zi) + dnbinom_robust(y, log_mu, log_v_minus_mu, true)` — reuse the existing `dnbinom_robust` machinery at `src/gllvmTMB.cpp:3119` |
| Density, zi_binomial | Julia has `ZIB` (N trials, logit link on count part) | not found in drmTMB read window | none of gllvmTMB's own count families is currently ZI — `zi_binomial` would be a 3rd new family (fid 19) if wanted; **not requested by CLAUDE.md's board notes**, lower priority than zi_poisson/zi_nbinom2 |
| Where it enters | count-process score `s^c`/`Wcc` nonzero even at y=0 (mixture, not hurdle) | same | same | must NOT reuse the delta/hurdle (fid 12/13) code path — those truncate the count process at y>0; ZI evaluates the count density at y=0 too |

## F. Smallest existing known-DGP recovery test for a count family

`grep -l "nbinom2" tests/testthat/*.R | xargs wc -l | sort -n` smallest three:
- `test-diagnostics-family-label.R` (14 lines) — **not a recovery test**: only checks `.gllvmTMB_family_label_from_id()` maps id 15 (nbinom1) to a label string; no simulate/fit/tolerance.
- `test-mspl-prepare-fence.R` (29 lines) — not inspected in detail (budget); filename suggests an MSPL-estimator admission fence, not a DGP recovery test.
- `test-enum-runtime-ids.R` (69 lines) — not inspected in detail (budget); this is where the FAM-19 (gengamma) "blocked" fail-loud check and other id-enumeration checks live per the register grep above, likely also not a recovery test.

**Not resolved within budget: the actual smallest simulate+fit+tolerance nbinom2 recovery test was not located** — the grep-by-line-count proxy surfaced only label/fence/enum tests. A real search would need `grep -l "rnbinom\|simulate_gllvmTMB\|known.*truth" tests/testthat/*nbinom2*.R` or similar, which the tool budget did not allow. Flagged as an open item in G.

## G. Open questions for the builder (NOT to be answered here)

1. **Zero-probability parameterisation richness mismatch.** Julia oracle: per-trait intercept-only (`Λ_z = 0`, explicitly deferred as future work). drmTMB oracle: full per-observation covariate design matrix (`X_zi·beta_zi`, even spatial terms). gllvmTMB's own 14-slot family-registry contract and its dispersion-parameter precedent (`log_phi_*`) are per-trait scalars throughout — closer to the Julia shape. Which does the builder target for v1: per-trait intercept-only (cheap, matches both the Julia oracle's admitted scope and gllvmTMB's existing dispersion machinery), or per-observation covariates (richer, matches drmTMB, but has no existing per-observation non-mean-parameter precedent anywhere in `src/gllvmTMB.cpp`)?
2. **NB2 dispersion scale mismatch.** Julia's `ZINB` uses ONE SHARED SCALAR `r` across all species/traits (explicit in the `ZINBCovFit` docstring). gllvmTMB's existing `nbinom2` (fid 5) and every other dispersion family use PER-TRAIT `log_phi_*` vectors. Reusing `log_phi_nbinom2` per-trait for `zi_nbinom2` would deliberately diverge from the Julia oracle's shared-scalar convention — is that acceptable, or does the builder want a genuinely new shared-scalar dispersion parameter (which would be the first of its kind in the C++ template)?
3. **No 14-slot contract home for `zi`.** `docs/design/02-family-registry.md`'s registry-object slots (`dpars`, `links`, `density_id`, etc.) have no named place for a second non-dispersion distributional parameter with its own link. Does `dpars` grow to `c("mu", "zi")` with a parallel `links = c("log", "logit")`, or does `zi` get folded in alongside `log_phi_*` as a "dispersion-shaped" parameter even though it enters the density as a mixture weight, not a variance/shape term?
4. **Naming discipline collision.** `docs/design/62-two-part-family-naming-and-scope.md` reserves `zi_*` strictly for true mixture zero-inflation and calls the existing `delta_lognormal`/`delta_gamma` (fid 12/13) hurdle-with-shared-eta path a category error if called "zero-inflated." Confirm the new constructors are named `zi_poisson()`/`zi_nbinom2()` (matching drmTMB's `model_type` strings) and NOT `zip()`/`zinb()` — neither oracle uses a bare `zip`/`zinb` R-level constructor name (Julia's are internal structs `ZIPoisson`/`ZINB`; drmTMB's is a `zi=` dpar modifier on `poisson()`/`nbinom2()`, not a standalone family).
5. **Smallest existing nbinom2 recovery test not located within the 25-call/15-min budget** (see F) — the builder should locate a real simulate+fit+tolerance nbinom2 test directly (e.g. `grep -rl "family = nbinom2\|family = \"nbinom2\"" tests/testthat/*.R` combined with a `simulate`/`rnbinom` grep) before writing the zi_poisson/zi_nbinom2 analogue, rather than trusting this recon's F section.
6. **`simulate.gllvmTMB_multi()`'s per-family RNG dispatch was not located** within budget (`R/methods-gllvmTMB.R:1443` is the entry point only) — needs to be found and extended for `rzip`/`rzinb`-style draws.
7. **check_gllvmTMB() / predictive-diagnostics.R gating lists are per-family opt-in, not automatic** — every new family_id (17/18/19) must be manually added to each list at `R/diagnose.R`, `R/predictive-diagnostics.R`, `R/dispersion-trait-map.R`, and the error-message enumeration at `R/fit-multi.R:1187`, or it will silently get NO diagnostic coverage (the exact multinomial/#897 gap the FAM-20 register rows above document at length) and a confusing "not supported" error on construction.
