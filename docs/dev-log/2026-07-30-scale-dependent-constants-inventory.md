# Scale-dependent constants — repo-wide inventory

**Date:** 2026-07-30 · **Lane:** `/private/tmp/gllvmtmb-scaleconst` (read-only survey; sole writer: Ada)
**Audience:** the owner of **D3** (the `aghq_ridge` verification arc)
**Status:** inventory only. **This lane fixed nothing and proposes no tested fix.**

---

## 1. The verdict in one line

**48 genuinely scale-dependent constants (16 high · 20 medium · 12 low) across 22 files — so D3 is NOT a local patch: `tau = 2` is one member of a repo-wide defect class, and the ridge should be reformulated relative rather than re-tuned.**

Two supporting facts that sharpen the verdict, because "it's a pattern" is only useful if it is also bounded:

- The class is **confined to three layers** — the R diagnostic surface, the R warm-start/control surface, and the R prototype engines (`va-*`, `eva-*`). **`src/gllvmTMB.cpp` is clean on this axis**: every hardcoded constant in the compiled likelihood and the loading construction clamps a probability, a `(0,1)`-supported response, a log-probability, or a standardised probit argument. Nothing in the compiled code is compared against a loading, a variance, a linear predictor, or a response value. So the fix is an R-layer convention change, not a template rewrite.
- **~50 further constants were checked and cleared** as genuinely dimensionless (§4). The repo is not uniformly careless — it already contains the correct pattern in at least six places (`psi_rel_thresh`, `loading_runaway_thresh`, `se_g = SE(V)/(2V)`, `vgh-verify.R`'s relative tolerances, `small_eps = max(1e-3 * data_sd, 1e-6)`, `missing-predictor.R`'s `0.25 * x_scale`). The defect is inconsistency in *which* denominator was chosen, not absence of the idea.

**The single worst instance is `R/va-r3-proto.R:1271** — `variance_domain_ok <- max_projected_variance <= 4`**, a hard admission gate on a link-scale variance that encodes "loadings are about 2" as `2² = 4` and flips a fit to `admitted = FALSE`. The worst instance *in the shipped (non-prototype) surface* is `R/diagnose.R:13` — `.gllvmTMB_converged_gtol <- 1e-2` — because a public coverage-certificate label (`certified-0.94` vs `route-only`, via `R/profile-derived.R:941-942`) turns on an absolute gradient tolerance that scales with both the response magnitude and the row count, and that no documented argument can reach.

---

## 2. What the defect class is

**A hardcoded magnitude constant standing in for a quantity whose scale the data determines.**

The test applied to every candidate was a single question: **"this number is compared against what, and does the denominator cancel the units?"** A constant is an *instance* if the quantity it is compared against carries response units, link units, `[nll]/[parameter]` units, or grows with `n`. It is *cleared* if the comparison is a ratio of like-dimensioned quantities, a probability, a proportion, a correlation, a count, or a relative tolerance.

The two calibration instances — the only two rows in this document with **measurement** behind them — anchor the class at both ends:

| # | Instance | Site(s) | What was measured |
|---|---|---|---|
| **A** | `aghq_ridge` (`tau`) `= 2` | `R/gllvmTMB.R:1281` (control default) · `R/fit-multi.R:5271` (`%||% 2` fallback) · `R/fit-multi.R:5022` (penalty site) | `docs/dev-log/audits/2026-07-30-aghq-ridge-verification-audit.md`: at true `lam_sd = 3`, `tau = 2` makes **both** engines worse (median sigma 0.920/0.976 vs 0.959/1.000 unridged) and does nothing at `lam_sd` 0.5 or 1. |
| **B** | `loading_absolute_thresh = 6` | `R/diagnose.R:440` (helper) · `:746` (formal) · `man/check_gllvmTMB.Rd:21` (documented) | `max|Lambda|` reached **32.64** on healthy adversarial gaussian fits, i.e. the Heywood gate fires on fits that are fine. |

**A is confirmed RAW, not relative, from the template.** `src/gllvmTMB.cpp:902-911` writes `Lambda_B(i,j) = lam_diag(j)` / `lam_lower(...)` with **no transform of any kind**, and `R/fit-multi.R:5022` adds `0.5 * sum(p[lam_idx]^2) * inv_t2` over exactly those raw entries. Nothing divides by a data SD, a typical loading, or a trace. So `tau` is a prior SD on a loading **in whatever units the response/link carries** — D3's diagnosis ("a prior claim that loadings are about 2") is exact, not approximate. Two aggravations this survey adds:

1. **No family gate exists on the AGHQ/ridge path.** `.gllvmTMB_aghq_k` (`R/fit-multi.R:6360`) and `R/aghq-gate.R` contain no family restriction, yet the justification at `R/fit-multi.R:4990-4994` is explicitly binomial-logit ("a loading of 1 swings occurrence 0.27–0.73"). Gaussian, Gamma and tweedie fits get a logit-calibrated prior.
2. **The mis-scaled ridge is also the start-selection scoring function.** `R/fit-multi.R:5321-5330` chooses between the warm start and the ungated cold start `alt[lam_i] <- 0.3` (`:5300`) on the **penalised** objective. At large data scale the systematically-too-small start is rewarded by the penalty term rather than on fit — two scale-dependent constants reinforcing each other.

**The clean counter-example, and the reason the numbers are not the problem:** `aghq_shift_tol` and `aghq_grad_tol` share an identical `1e-4` default (`R/gllvmTMB.R:1287`, `:1288`). The former is scale-**free** and correctly absolute — it measures `z_B` mode shifts, and `src/gllvmTMB.cpp:918-921` imposes an exact `dnorm(z_B, 0, 1)` prior, so `z_B` is anchored to the unit normal by identification and the loadings absorb the scale. The latter is scale-**dependent**, because it measures a gradient of the absolute nll. Same number, same file, opposite verdicts. **The denominator is the defect; the digit is not.**

---

## 3. Inventory — genuinely scale-dependent constants (48)

Sorted by severity, then user-reachable first within each severity (reachable rows are the ones a release note can warn about; unreachable rows can only be fixed in code).
`Basis` column: **MEASURED** = a simulation/audit stands behind the severity; **AGENT-INFERRED** = severity is a reasoned judgement from a code read, with no simulation behind it.

### HIGH (16)

| file:line | constant | default | assumed scale | breaks at 10× | reach? | basis |
|---|---|---|---|---|---|---|
| `R/gllvmTMB.R:1281` | `aghq_ridge` (`tau`) | `2` | raw loading magnitude, link/response units | penalty at the truth is 100× larger; shrinkage 100× too strong (measured: median sigma 0.920/0.976 vs 0.959/1.000 unridged at `lam_sd = 3`) | yes | **MEASURED** |
| `R/fit-multi.R:5271` | `aghq_ridge_tau` (`%||% 2`) | `2` | raw loading magnitude | same, but fires **unasked** whenever AGHQ is on and survives a hand-made control list with no `aghq_ridge` field | yes | **MEASURED** |
| `R/diagnose.R:440` (+`:746`, `man/check_gllvmTMB.Rd:21`) | `loading_absolute_thresh` | `6` | raw loading claimed as latent SD in **link** units | Heywood gate WARNs on healthy fits (measured `max|Lambda| = 32.64`); link-scale justification does not survive a rescale | yes | **MEASURED** |
| `R/gllvmTMB.R:1272` | `init_jitter` | `0.3` | the **whole** parameter vector — `b_fix` (response units) + loadings + log-dispersions under one absolute SD | at `sd(y) ~ 1000` every restart lands in the identical basin; multi-start is a **silent no-op** while `restart_history` still reports `n_init` restarts. `convergence == 0` throughout, no warning | yes | AGENT-INFERRED |
| `R/diagnose.R:734` | `gradient_thresh` | `1e-2` | absolute `max|gradient|`, `[nll]/[par]` — presumes both response scale and `n` | 10× rows inflates the gradient ~10× → spurious WARN; 10× response deflates the mean-block gradient ~10× → spurious PASS | yes | AGENT-INFERRED |
| `R/diagnose.R:1115` | `gradient_thresh` (`gllvmTMB_diagnose`) | `1e-2` | same | third site; forwarded to `sanity_multi()` **and** re-tested at `:1236` to print "Optimum may not be tight" on a converged fit | yes | AGENT-INFERRED |
| `R/diagnose.R:735` | `se_thresh` | `100` | raw fixed-effect SE in coefficient units | every SE 10× larger → healthy fit WARNs `weakly identified`. Fires on **every** family, no relative companion | yes | AGENT-INFERRED |
| `R/diagnose.R:1116` | `se_thresh` (`gllvmTMB_diagnose`) | `100` | same | second site; forwarded to `sanity_multi()` **and** re-tested at `:1262` → the user is told the model is unidentified twice from one scale artefact | yes | AGENT-INFERRED |
| `R/methods-gllvmTMB.R:1468` | `se_thresh` (`sanity_multi`) | `100` | link-scale fixed-effect SE | kg → g flips PASS to WARN with no model change; on the function documented as "the fast first screen after fitting" | yes | AGENT-INFERRED |
| `R/diagnose.R:739` | `sigma_eps_thresh` | `1e-4` | residual SD in **response** units | at `Y/1e4` a healthy `sigma_eps = 1e-5` is flagged `boundary_sigma_eps`; at `10Y` a collapsed `5e-5` becomes `5e-4` and passes silently. **Sole** test on this quantity — only `sigma_eps[1L]` is read (`:1046`), so no siblings exist for a relative companion | yes | AGENT-INFERRED |
| `R/diagnose.R:13` | `.gllvmTMB_converged_gtol` | `1e-2` | absolute `max|gradient|` — presumes response scale **and** row count | **WORST in the shipped surface.** 10× rows → healthy fit declared NOT converged; 10× response → non-stationary fit declared converged. Gates `health$converged`, which `R/profile-derived.R:941-942` uses to stamp `certified-0.94` vs `route-only`. **A public certificate label turns on this constant.** Unreachable by any documented argument (`assignInNamespace` only) | **no** | AGENT-INFERRED |
| `R/diagnose.R:602` | `aghq_ridge = 2` **inside the recommended-action string** | `2` | prior SD on loadings | the runaway-loading action prescribes `gllvmTMBcontrol(aghq_ridge = 2)` at exactly the large-loading fits the audit measured it damages. Hard-coded in the string: a user who changes `loading_absolute_thresh` cannot change the advice | **no** | **MEASURED** |
| `R/fit-multi.R:5022` | penalty site `0.5 * sum(p[lam_idx]^2) * inv_t2` (gradient `:5023`) | — | raw `theta_rr_B` entries in response/link units | the penalty grows as `scale²` while the log-likelihood grows only with `n`, so the claim at `:4995` that a fixed prior contributes `O(1)` is false in the scale direction | **no** | **MEASURED** |
| `R/fit-multi.R:5300` | AGHQ alternative cold start `alt[lam_i]` | `0.3` | raw loading ~`O(1)` | **ungated by family** (only the `b_fix` empirical-logit branch is gated), so a gaussian AGHQ fit starts all loadings at 0.3 whatever `sd(y)` is — then `:5321-5330` *rewards* that too-small start via the mis-scaled ridge | **no** | AGENT-INFERRED |
| `R/va-r3-proto.R:1271` | `projected_variance_limit` | `4` | link-scale latent variance `v = ‖L_i' lambda_t‖²`; `4 = 2²` encodes "loadings ≈ 2" | **WORST overall.** For `family == 0` (gaussian_anchor) the link *is* the response scale: 10× `y` makes `v` 100×, so every fit with latent SD > 2 returns `status = "failed_variance_domain"`, `admitted = FALSE`. `dev/variance-domain-gate-note.md` measures `theta_rr = 3` → `max_v ≈ 9`, tripping it. Justified only by the **binomial** softplus Taylor truncation, yet applied to Poisson (exact lognormal mean, `inst/tmb/gllvmTMB_va_r3.cpp:352`) and gaussian (`v` enters exactly and linearly, `:328-330`) where it is pure prior belief with no numerical content | **no** | AGENT-INFERRED |
| `R/va-r3-proto.R:1316` (used `:1188`, `:1201`, `:1229`) | `gradient_tolerance` | `1e-4` | absolute `max|gradient|` of the negative ELBO | decides `healthy`, and `admitted` needs ≥3 healthy starts → a converged optimum reports non-convergence at 10× data scale. **Mirrored in `R/eva-proto.R:432`, `:444`, `:467`** — a fix must land in both | **no** | AGENT-INFERRED |

### MEDIUM (20)

| file:line | constant | default | assumed scale | breaks at 10× | reach? | basis |
|---|---|---|---|---|---|---|
| `R/diagnose.R:737` | `psi_thresh` | `1e-4` | per-trait psi SD, response/link units | collapsed psi `5e-5` → `5e-4`, clears the absolute test. Medium only because the OR-ed dimensionless `psi_rel_thresh` catches most cases; residual exposure is the **single-component** case, where `.gllvmTMB_relative_collapse()` returns `FALSE` by construction (`:114`) | yes | AGENT-INFERRED |
| `R/gllvmTMB.R:1288` | `aghq_grad_tol` | `1e-4` | `max|gradient|` of the absolute nll | for gaussian, `y → 10y` (with `sigma → 10 sigma`) shrinks the gradient ~10×, so the fixed tolerance is ~10× **looser** and the loop declares convergence early. Also scales with `n`. `:5510-5516` already records a ridged fit's unpenalised gradient at "2500× the 1e-4 tolerance" — and fixed the gradient, not the scaling | yes | AGENT-INFERRED |
| `R/gllvmTMB.R:1289` | `aghq_f_tol` | `1e-9` | absolute change in the objective | at `|F| = 1e7` the double-precision noise floor is `2.2e-9`, so the `f_tol` leg fires on arithmetic noise — the "STUCK IS NOT SETTLED" failure the `:5598-5604` comment only partly guards | yes | AGENT-INFERRED |
| `R/diagnose.R:126` | `loading_thresh` (`.gllvmTMB_boundary_flags`) | `1e-3` | magnitude of a `diag(Lambda_B/W)` element | drives `near_zero_B/W_loading` → WARN rows. **No** relative companion, unlike the `sd_*` loop below it. At `10Y` a pinned `1e-4` becomes `1e-3` and the flag vanishes | **no** | AGENT-INFERRED |
| `R/diagnose.R:127` | `sd_thresh` (`.gllvmTMB_boundary_flags`) | `1e-4` | variance-component SDs (`sd_B/W/phy/spde/b`), response/link units | the file documents the failure itself (`:100-108`: an sd of `6.8e-4` is fully collapsed yet clears `1e-4`) and that argument is purely about magnitude. Medium because the OR-ed `sd_rel_thresh` covers the multi-component case | **no** | AGENT-INFERRED |
| `R/methods-gllvmTMB.R:1548` (+`:1567` for `rr_W`) | `rr_B_min_loading` PASS/WARN cut | `1e-3` | absolute diagonal latent loading, link units | scale down 1000× and every healthy loading WARNs; scale up 10× and a collapsing factor at `1e-4` reads PASS | **no** | AGENT-INFERRED |
| `R/check-identifiability.R:213` | loading-collapse **absolute** conjunct | `0.05` | mean `|loading|` of a latent column | the test is `sorted[1] < 0.1 * sorted[2] && sorted[1] < 0.05`; the first conjunct is correctly a ratio, the second is binding at large scale → a genuinely collapsed column (0.3 against a sibling at 10) is **not** flagged. A false negative in an identifiability checker, produced entirely by units | **no** | AGENT-INFERRED |
| `R/predictive-diagnostics.R:1120` | `.gllvmTMB_sigma_eps` fallback | `1` | residual SD in response units | used as `sd` in `pnorm(y, eta, sigma_eps)` at `:400`: at 10× scale every PIT value clips to 0/1 and the quantile residual reports catastrophic misfit for a healthy model | **no** | AGENT-INFERRED |
| `R/simulate-site-trait.R:117` | spatial Cholesky jitter | `1e-8` | variance of the simulated spatial field (response²) | added to an **already variance-scaled** kernel: at `sigma2_spa = 1e-6` the jitter is ~1% of signal, so the "spatial" DGP is substantially white noise and any coverage study on it tests the wrong truth. The **same file does it right** at `:152-153` (jitter the unit-diagonal `Cphy`, scale afterwards) | **no** | AGENT-INFERRED |
| `R/profile-derived-curves.R:300` | monotone test on profile differences | `1e-10` | successive differences of a derived variance/covariance | round-off in the differences is `~1e-10 × |dv|`: for a variance of order `1e6` a genuinely monotone profile is declared non-monotone and silently routed through the `spar = 0.6` spline instead of `approxfun` — and the chosen route produces the **user-facing CI bound** | **no** | AGENT-INFERRED |
| `R/check-consistency.R:191` | marginal-bias threshold | `0.5` | TMB `checkConsistency()` bias, each parameter's own units | one constant over a vector mixing log-SDs, correlations and fixed-effect coefficients: rescaling a covariate by 10 rescales its bias by 10 and flags it for a notational change | **no** | AGENT-INFERRED |
| `R/eva-proto.R:554` | AGHQ mode-search interval | `c(-12, 12)` | latent score `u`, assumed standard normal — but the mode is bounded by `sum_t|lambda_t|`, a **loading**-scale quantity | with `T = 20` traits at `lambda = 2` the mode can sit near 20; `optimize()` silently returns a boundary point and the AGHQ nodes are centred in the wrong place → wrong reference marginal likelihood, **no error** | **no** | AGENT-INFERRED |
| `R/mesh.R:170` | `binary_search_knots` min/max | `1e-4`, `1e4` | mesh cutoff in projection units (sdmTMB convention: UTM **km**) | `make_mesh()` docs only require an equal-distance projection, so **metres are admissible**: on a 500 km domain in metres the needed cutoff exceeds `1e4`, the bisection saturates at the grid edge and returns far more knots than requested, silently. Inherited from sdmTMB (`inst/COPYRIGHTS`) — flag upstream | **no** | AGENT-INFERRED |
| `R/va-vgh.R:281` | Fisher-information ridge | `1e-8` | entries of the observed information (`X'WX/phi`, ∝ `n`) | 10× response → `phi` 100× → information 100× smaller, so the **ridge, not the data**, determines `delta = solve(Info, g)` and the Newton step is silently shrunk | **no** | AGENT-INFERRED |
| `R/fit-multi.R:3753` | `init_rr_theta` `lam_diag` | `0.5` | raw diagonal loading | 10× too small at 10× scale, on precisely the flat-ridge direction `:4984-4988` says the likelihood barely constrains. **Secondary, non-scale:** the comment at `:3752` says "`lam_diag = 0.5 (sd 1.65)`", implying an `exp` transform that does not exist (`src/gllvmTMB.cpp:909` uses `lam_diag(j)` directly, so the implied Sigma diagonal is 0.25) | **no** | AGENT-INFERRED |
| `R/fit-multi.R:6133` | `.gllvmTMB_log_sigma_eps_start` floor | `1e-3` | residual SD in response units | asymmetric: inert at 10×, but at `0.01×` (kg → tonnes, proportions) the start is pinned **orders of magnitude above** the truth, in a region where the Gaussian density is flat in sigma. The relative form already exists in the same file at `:4656` (`1e-3 * data_sd`) | **no** | AGENT-INFERRED |
| `R/init-warmstart.R:282` | `theta_diag` residual-start floor | `1e-3` | per-trait remainder SD, response units | same defect on the per-trait diagonal start; binds on small-scale responses, silent. Mitigated only in that `start_method = "res"` is soft-deprecated as of 0.6.0 (`R/gllvmTMB.R:1230`) — the code still runs when asked for | **no** | AGENT-INFERRED |
| `R/fit-multi.R:2784` | log-link `b_fix` start offset `log(y + 0.5)` | `0.5` | response units; a **count** convention | the `log_link_only` guard at `:2765` admits lognormal (3), Gamma (4), tweedie (6), delta_lognormal (12), delta_gamma (13) — **continuous** responses with arbitrary units. For Gamma with `y ~ 1e-3`, `log(y + 0.5) = log(0.5)` to three decimals for every row: the `lm.fit` start collapses to an intercept and the fixed-effect start is discarded, silently | **no** | AGENT-INFERRED |
| `R/fit-multi.R:5548` | accept-step slack `F_cur <= F_best + 1e-10` | `1e-10` | absolute objective (nll) units | at `|F| ~ 1e6` the representable resolution is `~2e-10`, so an honest re-evaluation registers as an increase, the step is rejected as a "stale-node artefact", and the loop backtracks to `aghq_stop = "stalled"`. A large-`n` fit is reported stalled for a purely numerical reason | **no** | AGENT-INFERRED |
| `R/fit-multi.R:3009` | kernel `K` symmetry gate `max|K - K'| > 1e-8` → `cli_abort` | `1e-8` | entries of a user-supplied dense kernel, kernel's own units | Design 65 `kernel_*()` accepts an arbitrary dense `K`, not a correlation matrix: at `|K| ~ 1e6`, a `K` symmetric to full double precision has `max|K - K'| ~ 1e-4` and the fit is **refused**. The paired PSD check at `:3020` fails the other way. Contrast the phylo path, where `Aphy/Cphy` are unit-diagonal and the same `1e-8` is scale-free | **no** | AGENT-INFERRED |

### LOW (12)

| file:line | constant | default | assumed scale | breaks at 10× | reach? | basis |
|---|---|---|---|---|---|---|
| `R/fit-multi.R:3763` (mirrored `:6144`) | `.clamp_log_phi` bounds | `log(0.01)`, `log(100)` | **split**: dimensionless for nbinom2 size / Gamma shape / Beta precision; response-dependent for **tweedie** dispersion (`units^(2-p)`) | tweedie starts pinned at `log(100)` on a large-scale response. Low: start clamp only — `:3760` correctly notes the optimiser stays unconstrained | **no** | AGENT-INFERRED |
| `R/init-warmstart.R:119` | phi warm-start clamp (Design 48 §2-B) | `[log(0.01), log(100)]` | one clamp over eight phi slots of differing dimension | `log_phi_tweedie` moves a decade under `y → 10y`, so the clamp binds where it did not. Even on the dimensionless slots the upper bound bites exactly in the near-Poisson case the comment names | **no** | AGENT-INFERRED |
| `R/fit-multi.R:4656` | `small_eps` **absolute** floor in `max(1e-3 * data_sd, 1e-6)` | `1e-6` | response units (the first term is correctly relative) | binds only when `sd(y) < 1e-3`; at `sd(y) = 1e-7` the pinned `sigma_eps` is 10× the response SD and dominates the density `diag(Psi)` was to own. **Secondary:** the user message at `:4664` asserts "~1/1000 of sd(y)", which becomes false exactly when the floor binds | **no** | AGENT-INFERRED |
| `R/fit-multi.R:3419` | `known_V` nugget | `1e-8` | sampling variances, response² | fine for lnRR/Zr/logOR (variances 0.001–1); for a raw-mean-difference meta-analysis in original units the nugget is a non-trivial fraction of `V` before `V_inv`/`log_det_V`. Same pattern at `:3032` (`K_jit`, shares the exposure); `:3180`/`:3262` (`Aphy`/`Cphy`) are unit-diagonal and therefore clean | **no** | AGENT-INFERRED |
| `R/profile-derived.R:1094` | log-SD-Wald boundary guard | `1e-8` | a variance component `V`, link units | at a `1e-4` trait scale a real variance of `1e-9` is labelled `boundary_na` and its CI suppressed. Low because the next lines compute the scale-free version of the same test (`se_g = SE(V)/(2V)`, gated at 2.5, `:1111`) — the absolute pre-guard is largely redundant and could simply be deleted | **no** | AGENT-INFERRED |
| `R/va-vgh.R:476` | warm-start eigenvalue floor | `1e-6` | eigenvalue of the link-scale residual covariance | for a trait with residual SD `1e-4` (variance `1e-8`) the floor binds and the warm-start `Lambda` is 100× too large. Warm start only — but it is the start SQUAREM was added to survive | **no** | AGENT-INFERRED |
| `R/eva-proto.R:438` (+`:451`; `R/va-r3-proto.R:1194`, `:1214`) | objective-improvement guard | `1e-8` | absolute nll difference | at `|F| ~ 1e7` the margin is a few ulp, so the guard becomes noise-driven and a legitimate polish pass is rejected. The neighbouring BFGS call at `:447` uses `reltol = 1e-12` — the correct relative form, right next to the absolute one | **no** | AGENT-INFERRED |
| `R/va-vgh.R:454` | within-unit `X` constancy tolerance | `1e-10` | absolute difference of covariate values | a covariate at large magnitude (unstandardised year, population count) can differ within a unit by `>1e-10` negligibly and **hard-error**; a genuinely varying covariate at `1e-12` passes. Low: in practice the two sides are the same stored doubles reordered, so exact equality holds | **no** | AGENT-INFERRED |
| `R/loading-uncertainty-helpers.R:67` (mirrored `R/phylo-signal-ci.R:164`) | finite-difference step for `dLambda/dpar` | `1e-6` | absolute step in TMB parameter units | the textbook scale-dependent choice, feeding `cov_lambda = J Cov J'` and therefore the loading SEs the Confidence Eye plots. Low because the parameters that move `Lambda` are the packed loadings themselves, near-linear and `O(1)`; `|par| >> 1e6` would lose the difference to cancellation | **no** | AGENT-INFERRED |
| `R/screen-gllvmTMB.R:448` (+`:449`, `:470`, `:471`) | count-integrality tolerance | `1e-8` | absolute deviation-from-integer of a **count** | exactly representable integers give residual 0 at any magnitude, so this bites only when a large count arrives with float error: double spacing at `1e10` is `~2e-6`, so one ulp fails the test and `.screen_trait_status()` (`:573-579`) hard-FAILs legitimate data with "invalid binomial values" | **no** | AGENT-INFERRED |
| `R/diagnose.R:1183` | `round(diag(Sigma_B), 3)` | `3` **decimal places** | between-unit variance, response² | with `Sigma` of order `1e-5` (proportions, rates) `gllvmTMB_diagnose()` prints `0 0 0` and the reader concludes the component is dead; at `1e6` three decimals is noise. Display only — but it destroys output rather than warning. `signif()` is already the house form in the same file (`:296`) | **no** | AGENT-INFERRED |
| `R/diagnose.R:1206` | `round(diag(Sigma_W), 3)` | `3` | within-unit variance, response² | same, second site. **Contrast** `:1210`/`:1214`/`:1218`, which round `ICC_site` and the communalities — those are proportions in `[0,1]`, so three decimals is correct there. Only the two `Sigma` diagonals carry units | **no** | AGENT-INFERRED |

**Dedup note:** `R/init-warmstart.R:282` was reported independently by two sweeps (as medium and as low); it is listed **once**, at the higher severity. That is the only overlap between the three sweeps.

---

## 4. Considered and cleared (≈50)

**This section is load-bearing.** Every row here was tested with the same question — *compared against what?* — and the denominator was found to cancel. It exists so the next reader does not re-raise them, and so "48 instances" is read as a filtered count rather than a grep count.

### The five exemplars a fix should copy

| file:line | constant | why it is fine |
|---|---|---|
| `R/diagnose.R:738` | `psi_rel_thresh = 1e-2` | `min(val)/max(val)` of sibling psi SDs (`:121`) — units cancel exactly. **Best-engineered threshold in the repo**: its roxygen (`:659-674`) records a real calibration (0.001 → 0.01 on 360 fits; 96.2% sensitivity, zero false positives) **including a transport test across 1000× true-variance heterogeneity that passed** — i.e. an explicit scale-invariance check. |
| `R/profile-derived.R:1111` | `se_g` gate `= 2.5` | `se_g = SE(V)/(2V)` is half the CV of `V`; the in-code comment says so. This is the correct shape `se_thresh = 100` lacks. |
| `R/vgh-verify.R:101` | `pmax(1, abs(a))` denominator | The house pattern, stated at `:202-204`: every tolerance in `.vgh_compare_optima` divides by a same-dimension quantity, with a unit floor so near-zero parameters do not blow up. **Use this file as the template.** |
| `R/fit-multi.R:4656` | `1e-3 * data_sd` | A fixed fraction of the data's own SD (only the `1e-6` floor beside it is an instance). |
| `R/missing-predictor.R:1100` (+`:1114`) | `log(max(1e-4, 0.25 * x_scale))` | Seed as a fraction of the covariate's own scale; the `1e-4` exists only to keep `log()` finite. This layer produced **zero** hits, which is why it is cited. |

### Cleared — ratios of like-dimensioned quantities

| file:line | constant | denominator (named, not assumed) |
|---|---|---|
| `R/diagnose.R:439` | `loading_runaway_thresh = 25` | `max(median(m), mad(m, constant=1))` where `m` = per-trait `max|Lambda|` over the **binomial reference traits only** (`:363-382`, `:508`). Both sides are loading magnitudes → invariant under `Lambda → cLambda`. *Caveats of a different kind:* the denominator switches median/MAD with the **shape** of the loading distribution, and the calibration is fenced to single-family binomial (`:696-706`). |
| `R/diagnose.R:438` | `loading_relative_thresh = 8` | same denominator (`:514-515`); additionally conjoined with `extreme_prevalence`, itself a proportion, so the whole `dominant_loading & extreme_prevalence` path carries no scale. |
| `R/diagnose.R:128` | `sd_rel_thresh = 1e-3` | `min/max` of sibling SDs (`:173`). *Follow-up, not a scale defect:* it sits at `1e-3` while the measured psi analogue was **raised** to `1e-2` on evidence that `1e-3` reports only 73.7% of collapses (`:664-674`) — a sensitivity inconsistency between sibling relative tests. |
| `R/diagnose.R:736` | `weak_axis_thresh = 0.05` | `axis_share = colSums(L²)/sum(colSums(L²))` (`:262-268`) — a proportion summing to 1. |
| `R/diagnose.R:740` | `cross_loading_thresh = 0.6` | `max_j L[i,j]² / sum_j L[i,j]²` of the **same row** (`:269-276`) → `[1/ncol, 1]`. |
| `R/diagnose.R:1117` | `big_corr_thresh = 0.5` | applied to `out_Sigma_B$R_B`, the **correlation** matrix (`:1186`), not the covariance. Recorded explicitly because the covariance diagonal one line above (`:1183`) **is** an instance — the R-vs-Sigma distinction was checked, not assumed. |
| `R/diagnose.R:370` | `mad(finite, constant = 1)` | multiplies a unit-carrying spread but is only ever used as `denom` in `out/denom` (`:428`). *Calibration note:* `constant = 1` makes the spread ~33% smaller and the ratio ~1.5× larger than a MAD-as-SD reading implies — bound up with the 8 and the 25, not a scale defect. |
| `R/suggest-lambda-constraint.R:102` | `threshold = 0.30` | explicitly a **standardised** loading (Comrey–Lee); the loading is divided by the trait's implied SD first. The correctly-fenced twin of calibration case B. |
| `R/check-identifiability.R:213` (first conjunct) | `sorted[1] < 0.1 * sorted[2]` | a ratio of sibling column magnitudes. Only the `&& < 0.05` half is the instance. |

### Cleared — probabilities, proportions, correlations, shares

`R/diagnose.R:435` `prevalence_thresh = 0.9` (`sum(y)/sum(trials)`, two-sided at `:511-513`; a binomial response has no free scale) · `:436` `saturation_prob_thresh = 0.99` (applied **after** `.apply_linkinv_per_row()`, `:476` — the correct pattern that `loading_absolute_thresh` gets wrong: a bound on a probability is bounded, the same concern on the link scale is not) · `:437` `saturation_share_thresh = 0.5` (`mean(...)`, a row fraction, `n`-normalised) · `:547` ranking weights `10/2/1` on base `abs(prevalence - 0.5)` ∈ `[0, 0.5]` (reporting **order** only; no status turns on it) · `R/screen-gllvmTMB.R:24` `prevalence_warn = c(0.05, 0.95)` and `:25` `prevalence_strong = c(0.02, 0.98)` (domain-**validated** at construction by `.screen_assert_probability_pair()`, `:268-281` — the structural guarantee `diagnose.R`'s absolute thresholds lack) · `:26`/`:27` `phi_warn/strong` (2×2 Pearson `phi`, normalised at `:696-703`; `phi_strong` is also reused against **Jaccard** at `:799` — dimensionless on both, but reusing a `phi`-named cut for a statistic with a different null is a **calibration** smell worth a separate look) · `:30` `hamming_rate_warn = 0.01` (`discordant/n_pair`) · `:520` `info_fraction` multiplier `4` (normalises `p(1-p)` to max 1; reported, never thresholded) · `:5307` empirical-logit clamp `1/(4*max(1,n_sites))` (a proportion **and** `n`-adaptive — the correct construction; same for the multi-trial continuity correction at `:2780-2781`, while the ordinal quantile clamp at `:2799` is fixed at 0.01/0.99, a mild inconsistency, not a scale defect).

### Cleared — counts, dimensions, iteration budgets

`R/screen-gllvmTMB.R:22` `rare_warn_n = 10` and `:23` `rare_strong_n = 5` (Peduzzi events-per-variable rule, `:99-102`; *denominator caveat of a different kind* — for multi-trial binomial, 10 events means different things at `trials = 1` vs `1000`, partly covered by the parallel rate test) · `:28` `discordant_warn_n = 10` / `:29` `= 5` (counts, with the OR-ed `hamming_rate_warn` companion on the same line, `:782` — good design) · `:972` `unit_levels >= 2` (structural minimum for a variance component) · `:989` `d >= n_traits` (count vs count) · `:246` print head cap `5L` (cf. `R/diagnose.R:1194` `min(nrow(big), 8L)`) · `R/gllvmTMB.R:1269` `n_init = 1L` (a replicate count — fine; its **effectiveness** is destroyed by `init_jitter`, which is the instance) · `:1279` `aghq_n_adapt = 400L` · `:1278` `aghq_iter_cap = 1L` · `:1290` `aghq_escalate_patience = 3L` (the comment at `R/fit-multi.R:5407-5411` records that a fixed mode-**shift** threshold was rejected *because the plateau level is data-dependent* — the authors made the scale-free choice deliberately here) · `R/fit-multi.R:5426` `cap_sched = 1L,2L,5L,25L,NULL` and the optimiser budgets (`maxit = 2000`, `eval.max = 2000`, `iter.max = 1500`).

### Cleared — anchored by identification (the subtle ones)

| file:line | constant | anchor |
|---|---|---|
| `R/gllvmTMB.R:1287` | `aghq_shift_tol = 1e-4` | measures `z_B` mode shifts; `src/gllvmTMB.cpp:918-921` imposes an exact `dnorm(z_B,0,1)` prior, so `z_B` cannot rescale — the loadings absorb the scale. **The instructive contrast with `aghq_grad_tol` (§2).** |
| `R/gllvmTMB.R:1291` | `aghq_rho_min = 1/64` | a dimensionless multiplier on a step direction (`:5567-5569`) = six halvings at any scale. *Non-scale defect:* the roxygen at `R/gllvmTMB.R:1290` calls it a "trust-region-style acceptance ratio" — it is a **backtracking step-length floor**, and no acceptance ratio is ever computed. |
| `R/gllvmTMB.R:1274` | `start_method$jitter.sd` (0 default; 0.2 in the recipe at `:1165`) | applied **only** to `z_tmb`, the latent scores (`R/init-warmstart.R:285-287`), which carry the `N(0,I)` anchor. Same word and magnitude as `init_jitter`, opposite verdict, because the target differs. |
| `R/fit-multi.R:2730`, `:2736` | ordinal increment floor `1e-3`, spacing `log(0.5)` | probit cutpoints on a latent scale pinned to unit variance by ordinal identification; the response is a category label with no units. |
| `R/fit-multi.R:6329` | conditional-Hessian eigenvalue floor `1e-8` | the Hessian is (prior identity) + (data term), so eigenvalues are anchored ≥ ~1 and **grow** with data scale; the floor gets less reachable at 10×. |
| `R/fit-multi.R:6283`, `:6294` | grid tolerances `1e-8`, `1e-6` | test the quadrature identities `sum(w) == 1` and the unit second moment — dimensionless by construction. |
| `R/fit-multi.R:4737`, `:4847` | `pin_log_sd = log(1e-6)` | gated (`:4728`) to bernoulli/ordinal/multinom traits (identification-anchored links), **and** the parameters are mapped off (`factor(NA)`) with `diag_W_skip`/`diag_B_skip` stopping the C++ density — the value sets a reported near-zero and cannot bias a fit. |
| `R/kernel-helpers.R:435` | PSD tolerance `-1e-6` | would be scale-dependent on an arbitrary covariance, but `:425-431` **aborts** unless `max|diag(A) - 1| <= sqrt(eps)`, so eigenvalues are bounded in `[0, n]`. An enforced precondition, not an assumption. |
| `R/va-vgh.R:584` | ELBO tolerance `1e-10` | `(e - prev)/n_obs`: rescaling `y` shifts the ELBO by a constant `-n log(c)` at every iterate, so the **increment** is invariant, and `/n_obs` removes the `n` dependence. `:488-490` records why relative-to-`|ELBO|` was rejected ("loosens as N grows — exactly backwards"). |
| `R/diagnose.R:199` | `qr(cov_fixed, tol = 1e-8)` | LINPACK `dqrdc2` compares each reduced column norm to that column's **original** norm → relative by construction. *Honest residual:* not invariant to **differential** column scaling, and `cov.fixed` mixes `var(beta)` with `var(log-sd)`. That is a conditioning property, not an assumed data scale. Same verdict for the implicit `1e-7` in `R/screen-gllvmTMB.R:948`. |
| `R/diagnose.R:292` | `.gllvmTMB_fmt_num` `signif(x, 3/4)` | significant digits are relative by construction, so every `value`/`threshold` cell in the returned check table is scale-robust even where the **threshold** is not. Contrast the `round(x, 3)` instances at `:1183`/`:1206`. |
| `R/diagnose.R:426` | pooled `max_loading` | **Recorded as a non-defect on purpose, because it looks like the worst one.** It mixes SPDE loadings (measured `6.5e6`) with unit-tier loadings (66), but it is only ever **printed** (`:574-577`); every status decision uses `relative_loading` or `max_loading_unit`, which excludes non-unit tiers by construction (`:392-421`). No threshold is attached. |
| `src/gllvmTMB.cpp:92` | `gll_log_pnorm` switch `-20.0` | a standardised probit argument (20 SD). Cited because the comment at `:86-92` documents the codebase **already diagnosing and removing** an instance of this class: an ordinal cell-probability floor of `1e-12` that was "harmless under Laplace" but "BINDS at outer quadrature nodes … kills the node's gradient". The lesson is already learned here. |
| `src/gllvmTMB.cpp:2140`, `:2189`, `:2310`, `:2564`, `:59` | `1e-12` floors, series switch | probabilities, `(0,1)`-supported responses, log-probabilities — dimensionless by family support. **No constant in the compiled likelihood or the loading construction is compared against a loading, variance, linear predictor, or response value.** |

### Coverage of the cleared set

All 127 `1e-*` / `.Machine$double.eps` literals in the scoped R files, plus ~45 bare-number comparisons and every `pmax`/`pmin` clamp, were examined. The ~150 not itemised above are dimensionless (probabilities, correlations, coverage rates, quadrature orders), relative by construction (`min_eig < 1e-8 * max_eig`, `0.25 * abs(hw)`, `pmax(1, abs(a))`, L-BFGS-B `factr`, standardised compatibility `(theta - centre)/se`, `threshold * lim`), or machine-determined (`exp` overflow at 700, softplus switch at 30, `sqrt(.Machine$double.eps)`). `R/julia-bridge.R` (3881 lines) and `R/brms-sugar.R` (4501 lines) are clean — all sign checks and dimensionless.

---

## 5. The reformulation option

The count (48, of which 16 high) justifies a **convention**, not 48 patches. The scale-free denominator is available and already evidenced:

> In 59 gaussian fits, `max|Lambda|` stayed below each dataset's **own** largest trait SD (max ratio **0.961**), and `log|Sigma|` pins `Lambda` to the data's second moments.

So **a ratio to typical loadings, or to the largest trait SD, is scale-free where a bare constant is not** — and the 0.961 headroom means a threshold expressed as a multiple of `max_t sd(y_t)` has a defensible `O(1)` calibration instead of an inherited digit.

**Can adopt the trait-SD / typical-loading denominator directly (13 rows):**
`R/gllvmTMB.R:1281` + `R/fit-multi.R:5271` + `:5022` (`tau → tau * sd(y_t)`, or `tau ×` the empirical residual SD — **this is the D3 fix**) · `R/diagnose.R:602` (the advice string must interpolate the same relative `tau`, not a literal) · `R/diagnose.R:440` (`loading_absolute_thresh` → a multiple of `max_t sd(y_t)`; a 0.961 observed ceiling makes a limit of ~2–3 defensible) · `R/methods-gllvmTMB.R:1548`/`:1567` (`min|diag|/max|diag|`, or loading ÷ trait residual SD) · `R/check-identifiability.R:213` (drop the absolute conjunct, or express it as a fraction of the max column magnitude) · `R/fit-multi.R:3753` and `R/init-warmstart.R:282` and `R/fit-multi.R:6133` (starts as fractions of the data's own SD) · `R/va-vgh.R:476` (`pmax(ev, 1e-8 * max(ev))`) · `R/va-r3-proto.R:1271` (express the domain relative to the fitted loading scale — **and gate it to `family == 1`**, since Poisson and gaussian have no truncation to protect).

**Needs a different scale-free denominator (the trait-SD ratio does not apply) (13 rows):**
- **Gradient tolerances** — `R/diagnose.R:13`, `:734`, `:1115`, `R/gllvmTMB.R:1288`, `R/va-r3-proto.R:1316` (+ the `R/eva-proto.R` mirrors): use `max|g|/(1 + |F|)` (**already computed at `R/diagnose.R:57-61` and then not used for the `converged` flag**) or, better, a Newton decrement `g/sqrt(diag(H))`, which is genuinely dimensionless.
- **Objective tolerances** — `R/gllvmTMB.R:1289`, `R/fit-multi.R:5548`, `R/eva-proto.R:438`: `abs(dF) < tol * (abs(F_prev) + 1)`.
- **SE checks** — `R/diagnose.R:735`/`:1116`, `R/methods-gllvmTMB.R:1468`: `SE/|estimate|` (a CV), the shape `R/profile-derived.R:1111` already uses.
- **Bias check** — `R/check-consistency.R:191`: bias ÷ the parameter's own SE (which `checkConsistency`'s p-values already do).
- **Residual-scale floors** — `R/diagnose.R:739`, `R/fit-multi.R:4656`: `sigma_eps` relative to `sd(y)` or to total fitted variance.
- **Kernel/matrix tolerances** — `R/fit-multi.R:3009`/`:3020`, `:3419`: scale by `max(abs(K))` / `mean(diag(V))`.
- **Mesh** — `R/mesh.R:170`: derive the search range from `diff(range(loc_xy))`.

**Genuinely cannot adopt a ratio (5 rows) — these need a structural fix instead:**
- `R/gllvmTMB.R:1272` `init_jitter`: there is no single denominator, because the parameter vector mixes units. The fix is **per-block** scaling (or `sd = jitter * (abs(obj$par) + 1)` elementwise), not a relative constant.
- `R/fit-multi.R:5300`: the cold start needs a family gate plus a data-derived magnitude; and the **start-selection score must stop being the penalised objective** or the ridge keeps rewarding the wrong start.
- `R/eva-proto.R:554`: a bracket, not a threshold — widen to `±(5 + sum|lambda|)` or use `uniroot` on the score.
- `R/diagnose.R:1183`/`:1206`: display — `signif(x, 3)`, which the same file already uses.
- `R/screen-gllvmTMB.R:448` and `R/va-vgh.R:454`: relative-with-floor (`< 1e-8 * max(1, abs(x))`) — trivial, but no data scale to ratio against.

---

## 6. Recommended order of work for the D3 owner

Cheapest first. Each step names the **decision** it needs — none of these is mechanical.

| # | Work | Cost | Decision needed |
|---|---|---|---|
| **1** | **Stop the ridge firing unasked.** `R/fit-multi.R:5271`'s `%||% 2` applies `tau = 2` whenever AGHQ is on; the Laplace path already requires `aghq_ridge_explicit` (`:5083-5090`). Make AGHQ symmetric with Laplace. | one line + tests | **Is `tau = 2` ON-by-default defensible given the audit?** If not, this is the smallest change that removes the measured harm, before any reformulation. Ada's read: default-off is the honest state while the relative form is unvalidated. |
| **2** | **Fix the advice string** `R/diagnose.R:602`. It prescribes `aghq_ridge = 2` at exactly the large-loading fits the audit shows it damages. | one line | Does the runaway-loading row get *no* ridge advice, or advice in the new relative units? It cannot keep the literal. |
| **3** | **Gate the AGHQ/ridge path by family.** The justification is binomial-logit; the path has no family restriction (`.gllvmTMB_aghq_k`, `R/aghq-gate.R`). Same call for `R/va-r3-proto.R:1271` (gate to `family == 1`) and `R/fit-multi.R:5300`. | small | Which families the logit-scale calibration is claimed for **at all**. This is a scope declaration, not a code question. |
| **4** | **Reformulate `tau` relative** (`tau × sd(y_t)`, or × the empirical residual SD), then **re-run the D3 ladder at `lam_sd` ∈ {0.5, 1, 3} and at 10× response scale**. | the real D3 slice; Totoro/DRAC, results LOCAL (D-50) | Which denominator: per-trait `sd(y_t)`, pooled `sd(y)`, or a typical-loading yardstick. The 0.961 evidence supports trait SD; per-trait vs pooled is unresolved and matters for heteroscedastic trait sets. |
| **5** | **Decouple start selection from the penalty** (`R/fit-multi.R:5321-5330`). Compare starts on the **unpenalised** objective. | small, but touches fit paths | Whether start choice may legitimately see the prior at all. Independent of the `tau` reformulation and worth landing separately, since fixing `tau` alone leaves the bias in place. |
| **6** | **`.gllvmTMB_converged_gtol` (`R/diagnose.R:13`) → relative.** Highest-value non-D3 row, because it reaches a **public certificate label** via `R/profile-derived.R:941-942`. The relative gradient is already computed at `:57-61`. | small code, **large blast radius** | Does changing `converged` re-open the `certified-0.94` evidence? **Almost certainly yes** — any coverage cell whose certification depended on the old flag needs a re-derivation before the label is re-asserted. Treat as a release-gated change, not a cleanup. |
| **7** | **SE and gradient tolerances → relative** (`R/diagnose.R:734`/`:735`/`:1115`/`:1116`, `R/methods-gllvmTMB.R:1468`). | mechanical; test churn | These are **documented defaults** (`man/`), so changing them is an API-visible change requiring a NEWS entry, and reader-facing text must not expose register codes. |
| **8** | **The silent-failure tail**, in this order: `init_jitter` (`R/gllvmTMB.R:1272` — multi-start is silently a no-op at large scale, arguably belongs at #4 if any multi-start evidence is load-bearing), `R/simulate-site-trait.R:117` (any coverage study built on that spatial DGP tests the wrong truth), `R/predictive-diagnostics.R:1120`, `R/profile-derived-curves.R:300`, `R/eva-proto.R:554`. | medium each | For `simulate-site-trait.R:117`: **does any existing spatial coverage claim rest on this DGP?** If yes, that claim needs re-deriving, and this row jumps the queue. |
| **9** | **Display and low tail** — `round → signif` (`R/diagnose.R:1183`/`:1206`), relative-with-floor tolerances, the two stale comments (`R/fit-multi.R:3752` implies an `exp` transform that does not exist; `:4664` asserts "~1/1000 of sd(y)" which is false exactly when the `1e-6` floor binds) and the `aghq_rho_min` roxygen error (`R/gllvmTMB.R:1290`). | trivial | None. Good first-PR material for a separate lane. |

**Do not** treat #1–#3 as prerequisites for #4 in the sense of blocking it — they are independently correct and independently cheap. But **#4 without #5** leaves a scale-dependent bias in start selection that will contaminate the re-run.

---

## 7. What this inventory does **NOT** cover

- **It is a READ of the code. No simulation stands behind any severity rating except the two calibration instances (A and B).** Every row not marked **MEASURED** is marked **AGENT-INFERRED**: the mechanism is derived from the code and the units, and the "breaks at 10×" column is a **reasoned prediction, not an observation**. Ranking (which high is worst) is especially inferential — treat it as a work-order heuristic, not evidence.
- **No fix is proposed as tested.** §5 and §6 are shapes and orderings. Nothing here was executed, no R was run, no file in the repo was modified by this lane.
- **`inst/tmb/*.cpp` prototype templates and `dev/` scripts were out of scope.** `inst/tmb/gllvmTMB_va_r3.cpp` was read only at the specific lines cited (`:307-318`, `:328-330`, `:352`) to establish what `R/va-r3-proto.R:1271` gates; it was **not swept**. `dev/` was read only for `dev/variance-domain-gate-note.md`. Both plausibly contain further instances.
- **`src/gllvmTMB.cpp` is claimed clean only on this one axis** — no constant compared against a loading, variance, linear predictor, or response value. That is not a statement about its numerical robustness generally.
- **`tests/`, `vignettes/`, `man/` and `data-raw/` were not swept.** Test-side absolute tolerances are a separate and likely populated class: a test that asserts an absolute value will lock in the very scale assumption a fix removes, so **expect test churn at steps #6 and #7 that this document has not sized**.
- **`R/julia-bridge.R` and `R/brms-sugar.R` were swept and found clean**, but by the same read-only method — no Julia-side or brms-side constants were examined at all.
- **Non-scale defects noticed in passing are recorded but not inventoried**: the stale `lam_diag` comment (`R/fit-multi.R:3752`), the false `small_eps` message (`:4664`), the `aghq_rho_min` roxygen mislabel (`R/gllvmTMB.R:1290`), the `sd_rel_thresh` (`1e-3`) vs `psi_rel_thresh` (`1e-2`) sensitivity inconsistency, and the `phi_strong` threshold reused against Jaccard (`R/screen-gllvmTMB.R:799`). These are leads for a different slice.
- **This document makes no release claim and promotes nothing.** It is an input to D3's decision, not evidence for any user-facing statement about calibration, coverage, or convergence.

---

## Lane routing — who owns what (added by the surveying lane; nothing here was acted on)

This inventory was produced by a **read-only** lane. It touches **three other lanes' surfaces**, so
the hits are routed rather than fixed. `git diff --stat -- R/ src/` from this branch is empty.

| hit | owner | why it is theirs |
|---|---|---|
| `aghq_ridge` / `tau = 2` (`R/fit-multi.R:5255`) | **LA + AGHQ + ridge lane** | it is their D3; they hold the `21-wide-inc.csv` evidence |
| `.gllvmTMB_converged_gtol = 1e-2` (`R/diagnose.R:13`) → the `certified-0.94` gate (`R/profile-derived.R:941-942`) | **Profile / Tier-2a lane** | it conditions a **public certificate label** |
| `variance_domain_ok <= 4` (`R/va-r3-proto.R:1271`) | **HVT-1 / VA-R3 (Codex-owned)** | the lane board records *"the `<= 4` gate stays frozen"* |

### The one that deserves a second look, stated carefully

`.gllvmTMB_converged_gtol = 1e-2` is compared against a maximum gradient that the code itself
documents as **unscaled** (`R/diagnose.R:12`: *"a small **unscaled** maximum gradient"*). A gradient's
magnitude scales with the objective, so `1e-2` does not mean the same thing at different data scales.

And `profile-derived.R:941-942` makes the coverage certificate **conditional on that flag** — the
comment is explicit: *"Conditional on convergence — the certificate is among converged fits only."*

**What that does and does not imply.** It means the **conditioning set** of the certificate — which
fits count as converged — moves with the data's scale. It does **not**, by itself, mean the measured
0.94 coverage number is wrong: the number is what it is for the population that passed the gate. The
risk is that the population is scale-dependent in a way the certificate's wording does not disclose,
which could bias the estimate in either direction. **That is a question for the Profile lane to
answer, not a defect this lane is asserting.** Deliberately worded narrowly: this arc has already
had to withdraw one claim for being stated more broadly than its evidence supported.

### What this section does NOT cover

No measurement was made for any of the three routings — the severity ratings are **AGENT-INFERRED**
from reading, except `tau = 2` and `loading_absolute_thresh = 6`, which carry measurements from other
arcs. No fix is proposed as tested. `inst/tmb/*.cpp` prototypes and `dev/` scripts were out of scope.
