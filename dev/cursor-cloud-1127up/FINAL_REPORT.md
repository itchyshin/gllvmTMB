# Final report — claim tag `cursor-cloud-1127up`

**Repo:** `itchyshin/gllvmTMB` · **main SHA tested:** `1e3662653e4a45907b18255afbe621cd18415720`  
**Environment:** R 4.3.3, `gllvmTMB` installed via `R CMD INSTALL` from that commit (TMB 1.9.25).  
**Scope:** Non-phylo `latent(d=1..3, unique=TRUE/FALSE)`, mixed families, post-fit extractors. No changes under `src/` or `tests/`.

## Issues filed or commented

| URL | Action |
|-----|--------|
| https://github.com/itchyshin/gllvmTMB/issues/2004 | **Filed** — `simulate()` accepts `family=` in `...` but silently ignores it on in-sample latent Poisson fits |
| https://github.com/itchyshin/gllvmTMB/issues/1980 | **Comment blocked (403)** — long-format binomial `latent()` also yields `getResidualCor()` all-1; evidence in `repro_getResidualCor_long.R` |
| https://github.com/itchyshin/gllvmTMB/issues/1979 | **Comment blocked (403)** — ordinary Poisson `latent()` `simulate(newdata=)` non-integer draws; repro in v3 exploration |

**Not re-filed** (already open today / this lane): #1975, #1978, #1979 (`newdata` Gaussian fallback), #1980 (`getResidualCor` all-1), #1982 (`predict`/`simulate` `newdata` all-NA binomial), #1901 (`df.residual()` NULL), #1989 (`select_lv` tied logLik).

## Scenarios exercised (≥30)

| ID | Scenario | Outcome |
|----|----------|---------|
| G01–G06 | Gaussian `latent()` d=1,2,3 × `unique` TRUE/FALSE | Pass (converged; post-fit extractors usable) |
| I07 | `indep()` Gaussian + `simulate(nsim=1)` + RQ residuals | Pass |
| D08 | `dep()` — no latent-only `extract_Sigma` advisory (#1556 fixed) | Pass |
| P09 | Poisson `latent()` d=1 | Pass |
| B10 | Binomial `latent()`; `predict(response)` ∈ [0,1] | Pass |
| N11 | `nbinom2()` only latent | Pass (converged on direct re-check) |
| T12 | `tweedie(p=1.5)` latent | Pass |
| O13 | `ordinal_logit()` latent | Pass |
| M14 | Mixed Gaussian + binomial (correct long-format prep) | Pass |
| S15 | `simulate_site_trait` + `latent(| site)` | Pass |
| L16 | `logLik` + `objective` sign sum ≈ 0 Gaussian | Pass |
| A17 | Ridge fit: `AIC()` warns; formula consistent | Pass |
| C18 | `extract_correlations` vs `cor(Sigma)` (`link_residual=none`) | Pass |
| M24 | Mixed Gaussian + `nbinom2` | Pass |
| M25 | Mixed `tweedie` + binomial | Pass |
| U28 | `unique=TRUE` vs `FALSE` same data both converge | Pass |
| MIX tw+ord | `tweedie` + `ordinal_logit` mixed latent | Pass |
| B1 | Unconditional `simulate` binomial → 0/1 | Pass |
| B9 | `bootstrap_Sigma` smoke Gaussian | Pass |
| B10b | `stats::logLik` ≡ `logLik()` | Pass |
| LV/load | `extract_loadings` ≡ `getLoadings` | Pass |
| Ordiplot | `ordiplot(f)` on Gaussian d=2 | Pass |
| PSI30 | Gaussian latent positive `unique` ψ | Pass |
| P29 | Poisson `simulate` integers | Pass |
| SIM19 | `simulate(..., family=gaussian())` still Poisson-like | **Bug → #2004** |
| ND20 | `simulate(newdata)` clear error when `trait` missing | Pass (clear error) |
| SIM newdata Poisson | Non-integer / sub-1 counts | Matches #1979 (not re-filed) |
| getResidualCor binomial | All-1 vs `extract_correlations` | Matches #1980 (not re-filed) |
| predict newdata binomial | All-NA `est` | Matches #1982 |
| df.residual | NULL on latent fit | Matches #1901 |

Harness scripts: `dev/cursor-cloud-1127up/run_scenarios_v2.R`, `run_scenarios_v3.R`, repros `repro_*.R`.

## Suspicious / not confirmed as new issues

- **Harness false positive (v1):** `quote(d = d)` in `latent_formula()` made early scenarios look like fit errors; fixed in v2+.
- **`pearson` residuals / `simulate(..., n=)`:** Wrong API for `gllvmTMB_multi` (use RQ residuals and `nsim=`).
- **`family=gaussian()` on Poisson:** Does not change RNG; counts can still be integers by chance — use `family=binomial()` on Poisson fit to see values > 1 (`#2004`).
- **Mixed nbinom2 “no conv” in v3:** Could not reproduce on corrected data prep; converged in manual run.
- **`getLV` nrow vs `length(unique(unit))`:** Misleading when using `fit$frame` (empty); not a package bug.
- **`vcov` 3×3 vs `length(fit$par)`:** `vcov` covers fixed effects only (3 trait intercepts); not inconsistent.
- **Non-PD Hessian d=2 toy fit:** `predict(se.fit=TRUE)` returns NA SEs with warning — expected, not filed.

## Stop notes

- Issue comments returned **403** from this agent token after **#2004** create succeeded; maintainer may need to paste comments from `comment_1980.md` / `comment_1979.md`.
- No git tag `cursor-cloud-1127up` created (label only).