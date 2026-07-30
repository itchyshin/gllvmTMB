# Audit — the hardcoded-magnitude-constant class: ~10 instances, 10 measured

**2026-07-30 · Claude (Fable 5) · read-only sweep, no package code changed**

Commissioned after two lanes independently found the same defect shape on the same day
(`aghq_ridge` τ = 2, and `loading_absolute_thresh = 6`) and the VA/VGH lane asked whether it was a
class or a coincidence.

**It is a class.** Three surfaces swept, each returning multiple instances, **10 confirmed by
running fits at 1× and 10×/0.01× and watching the answer change**. Two instances are worse than
either seed case; the worst is filed as **#851** (latent ordination silently collapses at large
response scale, reporting convergence — independently reproduced: ‖Λ̂‖/k falls from 1.366 to
0.000325 while `convergence = 0` and `converged = TRUE`).

## ⚠️ Line numbers

The sweep read `claude/aghq-audit-findings-20260730` @ `9e76e069`. **`main` has since moved**
(`R/traits-keyword.R`, `src/gllvmTMB.cpp` and 8 others), so **line numbers below may be stale** —
re-locate by symbol before acting. Verified example: the `0.5` loading start reported at
`R/fit-multi.R:3737` is at **`:3750-3753` on current main**, and feeds five call sites, not one.
The finding was real; only the citation drifted.

## The generative mechanism — why this recurs

The package's justification prose repeatedly argues from *"the latent scores are standardised
N(0, I)"* and then applies a constant to **Λ**. **Standardising the latent is exactly what pushes
the response scale into the loadings.** Every loading-magnitude constant inherits that error. This
is the finding to remember: the class is not a series of oversights, it is one reasoning step
applied consistently.

---

## 4. Is this a class? — Yes. Unambiguously.

**This is a class, not two coincidences.** Three independently swept surfaces (diagnostics, penalties/fitting, profile/intervals) each produced multiple instances of the same shape, and **10 were confirmed by running fits at 1× and 10×/0.01× and watching the answer change**. Two of the measured instances are *worse* than the two seed cases that motivated the sweep:

- `init_rr_theta` starting every loading at a hardcoded **0.5** zeroes the entire ordination at sd(y) ≳ 1000 while reporting `convergence == 0` — measured, two seeds.
- The AGHQ multistart's hardcoded **0.3** alternative start *wins* the penalised comparison above sd(y) ≈ 30 and collapses loadings from a true 90 to 0.004 — measured, and the documented off-switch (`aghq_multistart`) is not a real `gllvmTMBcontrol()` formal, so it cannot be turned off.

The class also has a clear generative mechanism, which is why it recurs: **the package's own justification prose repeatedly argues from "the latent scores are standardised N(0, I)"** (R/fit-multi.R:4975) and then applies a constant to **Λ**. The latent's standardisation is exactly what pushes the response scale *into* the loadings. Every loading-magnitude constant in the package inherits that error.

Caveat on scope: all three sweeps read `claude/aghq-audit-findings-20260730` @ `9e76e069` in the worktree as found; no `origin/main` checkout was performed. Line numbers are against that branch.

---

## 1. Inventory — surviving scale-dependent constants

**Tier A — silently wrong numbers (reachable; no warning, no NA)**

| # | Constant | file:line | Compared against / applied to | Breaks at 10× | Family/link gated |
|---|---|---|---|---|---|
| A1 | `0.5` loading start | R/fit-multi.R:3737 `c(rep(0.5, rank), rep(0.0, ...))` | Initial value of `theta_rr_B` (raw Λ, no transform: src/gllvmTMB.cpp:888-897) | Not at 10× — **degrades from sd(y)≈272, total collapse by ≈1362**: Σ_B/k² goes 1.03 → 5.5e-07, Ψ absorbs everything, `convergence = 0`, `restart_history$success = TRUE`. Only 27/1500 iterations used, so caps are not the limiter. **MEASURED** | **No.** Default path for every reduced-rank latent fit |
| A2 | `0.3` AGHQ alt start | R/fit-multi.R:5284 `alt[lam_i] <- 0.3` | Loadings of the second multistart point, scored on the **tau=2-penalised** objective (R/fit-multi.R:5305-5314) | Fine at 10×; **above sd(y)≈30 the cold start always wins**: Λ̂₁ = 0.004 vs true 90. Silent (`opt$convergence == 1` only). Off-switch documented at :5277 **does not exist** as a control formal. **MEASURED** | **Asymmetric, which is the bug** — the companion intercept fill two lines down *is* binomial-gated (:5290); the loading line is not |
| A3 | `+ 0.5` grid-scale floor | R/loading-profile.R:131 `se_mat <- abs(Lambda) / 2 + 0.5` | Stands in for SE(Λ) in the **non-PD-Hessian** branch; sets grid `est ± grid_extent/2 * sc` | Harmless at 10×; at small scale sc pins at 0.5. Linear interpolation (:273, :283) over a quadratic profile then lands on the minimum: **CI = 3% of true width at sc/SE=100, `ci_status` still `"profile"`**. `grid_extent` is hardcoded at both public entry points (R/z-confint-gllvmTMB.R:380-381; R/loading-ci.R:169-170). **MEASURED** | **No** — gated only on `pdHess` failing, i.e. the case it is *designed* for |
| A4 | `aghq_ridge = 2` (τ) | R/gllvmTMB.R:1254; R/fit-multi.R:5255, :5002 | `0.5·‖θ_rr_B‖²/τ²` added to the NLL — i.e. ‖Λ_B‖²_F = tr(Σ_B) | 24.3% shrinkage vs 0.38% at 1× (‖L‖_F 20.87 → 15.79 against truth 22.38). τ=2 at 10× **is identically** τ=0.2 at 1× (verified to 6 s.f.). **MEASURED** | **No.** Bites via the documented `Laplace + aghq_ridge` route; the default AGHQ path was inert on gaussian (accept/reject uses the *unpenalised* F) |
| A5 | `init_jitter = 0.3` | R/gllvmTMB.R:1245; R/fit-multi.R:5087 | Added as absolute SD to the **entire** `obj$par` — raw `b_fix`/`theta_rr_B` alongside log-SDs and atanh-correlations | Objective perturbation collapses as **1/k²** (θ_rr_B: 1.158 → 0.0064 → 6e-05 at k=1/10/100) while log-blocks stay flat at ~9.6. `jitter_sd = 0.3` is still recorded in the multistart history, so a run that explored nothing reports as a genuine multistart. **MEASURED** | **No.** Inert at the `n_init = 1L` default; live in the configuration the docs recommend (R/gllvmTMB.R:1119) and 7 spatial tests use |
| A6 | `sqrt(.Machine$double.eps)` | R/init-warmstart.R:262 `keep <- which(sv$d[seq_len(r_svd)] > sqrt(.Machine$double.eps))` | Raw singular values of the residual matrix R | Every s.v. 10× larger → noise directions clear the bar, `r_eff` over-estimated → wrong starting subspace. Correct idiom `> tol * sv$d[1]` is one character away. *Inspected only* | No |
| A7 | `absolute_floor = 2` | R/loading-ci-bootstrap.R:55, :60, :236 | `max(abs(L_aligned))` per bootstrap replicate; exceeding it **discards** the replicate | Multiplier dominates at 10× (benign); at max\|Λ̂\|=0.02 the guard sits 100× above the loading scale and the separation screen is silently inert. *Inspected only* | **No** — the justifying comment (:182-189) is entirely about binary probit fits; no family check exists |
| A8 | `eps <- 1e-6` | R/extract-repeatability.R:172, :176-177 | Forward-difference step on `par_fix_at_mle`, which mixes log-SDs with raw Λ | At extreme loading magnitudes the relative perturbation → cancellation noise; Jacobian column is noise, propagates into `var_log_v` and the reported CI. Partly protected — the target is a log-ratio. *Inspected only* | No |

**Tier B — missed warnings (diagnostic goes silent on a real problem)**

| # | Constant | file:line | Compared against | Breaks at 10× | Gated |
|---|---|---|---|---|---|
| B1 | `sigma_eps_thresh = 1e-4` | R/diagnose.R:739, :1052 | `report$sigma_eps[1]`, the residual SD in **raw y units** (src/gllvmTMB.cpp:2104) | A genuinely collapsed fit at ratio σ/sd(y) = 9.9e-06 flips **WARN → PASS** at y×100. **No relative companion.** **MEASURED** both directions | **No** — and the *same shared scalar* is a log-scale SD for lognormal (fid 3, :2135), where 1e-4 is correct |
| B2 | `loading_thresh = 1e-3` | R/diagnose.R:126, :138, :148 | `abs(diag(Lambda_B))`, `abs(diag(Lambda_W))` | Collapsed axis at 5e-4 → 5e-3, `near_zero_B_loading` disappears. The sd_* loop 25 lines below **does** OR with `.gllvmTMB_relative_collapse`; these two do not. **MEASURED** | **No** — gated only on `use$rr_B`/`rr_W` |
| B3 | `sorted[1L] < 0.05` | R/check-identifiability.R:213 | Smallest column magnitude of the Procrustes residual matrix | **ANDed** with the correct relative test, so scaling *up* suppresses a flag the relative test would raise. Comment at :207-208 says "or near zero" — the code implements AND. *Inspected only* | No |
| B4 | `gradient_thresh`/`.gllvmTMB_converged_gtol = 1e-2`; `aghq_grad_tol = 1e-4` | R/diagnose.R:13, :734; R/gllvmTMB.R:1262 | `max(abs(gr(par)))`, the **unscaled** joint NLL gradient | Gaussian score scales ~1/k, so a non-stationary fit reads as converged at 10× — while growing ~n makes it unreachably tight. Deliberate documented trade-off (:7-12), and the scaled sibling is computed but rejected. Lower priority | No |
| B5 | `loading_absolute_thresh = 6` — **link gap** (new) | R/diagnose.R:440, :464, :746 | `tab$max_loading_unit`; gate is `family_id == 1L` only | The identity-link issue is the known seed. **New:** `link_id` is read at :451 but never gates the row, while `screen_gllvmTMB()` documents probit and cloglog. A probit loading is ~1.7× smaller for the same curve → systematic under-reporting on probit | Family yes, **link no** |

**Tier C — spurious warnings / spurious hard failures**

| # | Constant | file:line | Compared against | Breaks at 10× | Gated |
|---|---|---|---|---|---|
| C1 | `se_thresh = 100` | R/diagnose.R:735, :821, :1262; **R/methods-gllvmTMB.R:1464, :1528** (third consumer) | `max` of raw fixed-effect SEs from `summary(sd_report,"fixed")` — no normalisation on any branch | Exactly proportional: maxSE 0.123 → 12.34 → 123.35 flips **PASS → WARN** with `pdHess` TRUE, convergence 0, gradient PASS unchanged. Scale-free alternatives invariant across the sweep (SE/\|est\| = 0.2274; SE/sd(y) = 0.07523). **MEASURED**. Also fails the other way — SE 500 in grams passes as 0.5 in kg | **No** — built unconditionally in the `rows <- list(...)` block |
| C2 | `1e-12` warm-start signal floor | R/init-warmstart.R:253 | `var(as.numeric(R))` — **squared** response units, so the threshold bites quadratically | Fails only downward, but silently: warm start falls back with the reason string "residual matrix has no usable signal" for data with perfectly good signal. *Inspected only* | No |
| C3 | `1e-3` residual-SD floor | R/init-warmstart.R:282 `theta_diag <- log(pmax(sd_rem, 1e-3))` | Per-trait residual SD in raw response units | Below that scale every trait's Ψ start is pinned 10⁴ too large in variance. The **correct** version of this identical construct is 4000 lines away (R/fit-multi.R:4640). *Inspected only* | No |
| C4 | `1e-8` kernel symmetry | R/fit-multi.R:2996 | `max(abs(K - t(K)))` on a user-supplied **generic dense** kernel (Design 65) | A Gram matrix with entries ~1e6 accumulates asymmetry past 1e-8 and is rejected with a misleading "must be symmetric". Fails loudly, which is much better. *Inspected only* | No |
| C5 | `max(abs(eg$values), 1)` | R/extract-sigma.R:2276-2284 | Eigenvalues of Σ_row/Σ_col. `tol * max\|eigenvalue\|` is the **correct** form — the `, 1)` floor breaks it below unit scale | All eigenvalues ~1e-9 → `keep` all FALSE → `extract_coevolution_modules()` **hard-aborts** claiming the block "is numerically zero". Fix is deleting `, 1)`. *Inspected only* | No |
| C6 | `1e-6` VGH eigenvalue floor; `1e-8` VGH info ridge | R/va-vgh.R:476; R/va-vgh.R:281 | Eigenvalues of `crossprod(Rz)/(n-1)` (raw y² on the `gaussian_anchor` branch); observed information ÷ φ | Low severity, listed for completeness. Note the very next line — `Lambda <- Lambda * 0.5` (:478) — is multiplicative on a data-derived quantity, i.e. correct | Partially, and **not on the branch that needs it** |

**UNCLEAR (do not schedule; revisit only alongside a fix)**

- `log_phi` start clamp `[log(0.01), log(100)]` (R/fit-multi.R:3747; R/init-warmstart.R:119). **Seven of eight** clamped slots are genuinely dimensionless (shapes, precisions, count dispersions — traced each into the template). Only `log_phi_tweedie` carries units μ^(2−p). Severity low because no `lower=`/`upper=` is ever passed to `nlminb` (verified) — it is a start clamp, and the code says so at :3745.
- `aghq_f_tol = 1e-9` (R/gllvmTMB.R:1263). Approximately invariant to *response* rescaling (the n·log(s) shift cancels in a difference) but grows ~linearly in *n*. A cousin of the class, not the class. The "STUCK IS NOT SETTLED" guard at R/fit-multi.R:5582-5611 already covers the pathology it invites.

---

## 2. False positives — do not re-investigate

| Candidate | Verdict | Why |
|---|---|---|
| `threshold <- 0.5` marginal-bias cutoff, R/check-consistency.R:191 | **REFUTED — unreachable dead code** | `src/gllvmTMB.cpp` has **zero `SIMULATE` blocks**, so `TMB::checkConsistency` re-evaluates the *same* data every replicate. Verified: two `obj$simulate(complete=TRUE)` calls returned byte-identical lists; the score matrix is identically zero; `qr(var(t(g)))$rank = 0`; `solve()` always fails; `bias` is always NA; `finite_bias` is always length 0. Tested at 1× and 10× on gaussian-identity **and** Poisson-log — identical NA output in all four runs. The units analysis is right; the branch cannot execute. |
| `profile_ci_lv_effects()` bracket ±0.3, ladder 1.6^(0:7), `root_tol = 0.005`, `lambda = 1e6`, `0.05` constraint gate (R/profile-derived.R:316, 343, 345, 365, 368, 424) | **Real class instance, but NOT reachable → NOTE, not a defect** | The function is `@noRd`, absent from NAMESPACE, zero callers in `R/`, and a test *asserts* it stays unexported. The public route `extract_lv_effects(method = "profile")` hard-errors with class `gllvmTMB_lv_interval_withdrawn` (R/extractors.R:652-658) — the maintainers have already fenced this exact problem. Also: the finding's "10× → NA" is wrong (10× works; the trigger is a half-width exceeding ≈8), and its "5000% miss, no NA, no warning" is wrong — as shipped the small-scale path **fails closed** to NA. Fix before ever un-withdrawing. |
| `V <= 1e-8` small-V guard, R/profile-derived.R:914 | **Real class instance, but unreachable AND the proposed fix is wrong** | Two neighbours fire first: `pdHess` (:903) fails around V ≈ 1e-5–1e-6, and a genuinely-collapsing component has se_g = 3.8–6.3 so `se_g > 2.5` (:931) catches it — a variance estimated near zero has SE comparable to its own magnitude *by construction*. The claim that :931 makes :914 "redundant" is **false**: at V=0, seV=0, `se_g = NaN` and `if (se_g > 2.5)` raises a hard R error. Line 914 is the sole crash guard. If ever touched, keep the guard and drop only the magnitude (`V <= 0`). Internal-only surface, self-documented as "never a certificate" (:865). |
| Loading-ratio thresholds `loading_relative_thresh = 8`, `loading_runaway_thresh = 25` (R/diagnose.R:744-745) | **SCALE-FREE OK** | Compared against `relative_loading = max/denom` where `denom = max(median, MAD)` over the reference traits — both scale by the same factor. Verified unchanged to floating point at 10×. |
| `weak_axis_thresh = 0.05`, `cross_loading_thresh = 0.6`, `big_corr_thresh = 0.5`, binomial prevalence/saturation trio (0.9/0.99/0.5), the 1e-8 **relative** eigenvalue tests (R/check-identifiability.R:192, :481), `qr` tol 1e-8, `median_t > 60` (wall-clock seconds), `converged_rate < 0.9`, p-value 0.05s, rootogram `cap = 100L`, all of R/screen-gllvmTMB.R, R/diagnostic-tables.R, R/check-auto-residual.R | **SCALE-FREE OK** | Each traced to its definition rather than inferred from the name: energy proportions, correlations, probabilities, ranks, event counts, or relative-to-max eigenvalue tests. Flagged explicitly because the uniform `_thresh` naming makes them easy to sweep up by mistake. |
| `2.5` wide-interval gate, `0.35`/`15` total-variance hints, `slope_ratio_tol = 0.1`, two-Ψ `threshold = 0.10`, proportion/correlation grid heuristics, `tiny = 1e-12` on p and Beta y, `cut = -20` probit switch, `700`/`30` VA overflow guards | **SCALE-FREE OK** | Ratios, log-scale offsets, bounded quantities, or IEEE representational limits. The `700` is set by `exp()` overflow at 709.78, not by a belief about data. |

**Also surfaced, not this class but larger than what it was found next to:** `gllvmTMB_check_consistency()` is **structurally inert**. Because the template has no `SIMULATE` block it cannot test score centring for *any* fit; every call on every family returns `marginal_p_value = NA` and `diagnostics = "information_matrix_singular"`, which the roxygen (:103) and print method misattribute to "tiny / weakly-identified fixtures" and advise fixing with a larger `n_sim` — advice that can never work. Separately, R/check-consistency.R:87 documents the bias as "normalised by its SE"; TMB computes `-solve(var(t(gradients))) %*% rowMeans(gradients)`, which is in raw parameter units. That wrong doc string is what makes the 0.5 look defensible. Both also ship in `man/gllvmTMB_check_consistency.Rd`.

---

## 3. The good pattern — the fix template

The correct form already exists in the package, in the same file as the worst defect:

```r
      small_eps <- max(1e-3 * data_sd, 1e-6)
```
— **R/fit-multi.R:4640**, preceded by `data_sd <- stats::sd(y)` at :4639.

`1e-3` is dimensionless and multiplies a data-derived scale, so at 10× the value is 10× and the ratio to sd(y) is exactly preserved. The user-facing message even prints the *invariant* rather than the number ("~1/1000 of sd(y)", :4648). **This is the same 1e-3 as R/init-warmstart.R:282, written to the same intent, one scale-relative and one not** — the cleanest available evidence that the defects are oversights, not considered choices.

Three more templates worth citing when fixing:

- **OR an absolute test with a ratio:** `passes <- is.finite(min_val) && min_val >= psi_thresh && !relative_collapse` (R/diagnose.R:1018), where `.gllvmTMB_relative_collapse()` is `min/max`. Its roxygen (:656-674) carries measured calibration — 96.2% vs 73.7% sensitivity, zero false positives on 359 healthy fits whose true unique variances differ by up to 1000×. That is the evidentiary standard the other constants should meet.
- **Reparameterise so offsets become factors:** `.profile_ci_total_variance()` profiles `log(V)` (R/profile-derived.R:831, :849-853), which is *why* its ±0.35 / ±15 are scale-free. `profile_ci_lv_effects()` never got that treatment.
- **Restrict the denominator to comparable rows:** R/diagnose.R:704-706 takes the typical loading over the binomial traits alone "so that a trait from another family cannot set the scale this threshold is judged against." Any relative fix on a mixed-family fit must do this, or it reintroduces the same error one level up.

---

## 5. Recommended action

**Not a sweeping refactor.** Four targeted fixes, one gate, one documentation correction, and a deferred list.

**Fix now (silently wrong numbers on reachable paths):**

1. **R/fit-multi.R:3737** — scale the reduced-rank loading start off the data (`sd(y)` for gaussian rows, or seed from the residual SVD by default). This is the single highest-impact item: it destroys the ordination on ordinary response scales while reporting success. Note the source comment "(sd 1.65)" is itself wrong — it describes an `exp()` parameterisation the template does not use.
2. **R/fit-multi.R:5284** — the minimal correct fix is to gate the loading assignment to the **same** binomial condition as the intercept fill at :5290, making the alternative start a no-op elsewhere. **And make `aghq_multistart` an actual `gllvmTMBcontrol()` formal**, since :5277 documents an escape hatch that does not exist.
3. **R/loading-profile.R:131** — replace `+ 0.5` with a data-derived floor. Separately, `.invert_profile_loadings()` should refuse `ci_status = "profile"` when the bracketing span is a large multiple of the grid spacing, rather than returning a collapsed interval labelled as a converged profile bound.
4. **`aghq_ridge`** — either scale τ off the fitted loading scale, or gate the ridge to non-identity links, or document loudly that the response must be standardised. Do **not** touch R/fit-multi.R:5504-5509 (adding the ridge gradient to `g_cur`); that is correct.

**Fix cheaply (diagnostic rows; each is one line, the pattern is already in the file):** OR the absolute test with a ratio for `sigma_eps_thresh` (family-aware: the relative denominator applies to gaussian rows only, since the same scalar is a log-SD for lognormal), `loading_thresh` (reuse `.gllvmTMB_relative_collapse` — but review the denominator, since a lower-triangular Λ's diagonal legitimately declines across columns), and `se_thresh` (SE/|estimate| or SE/sd(y); remember the **third** consumer at R/methods-gllvmTMB.R:1464/1528). Change `&&` to `||` at R/check-identifiability.R:213, which the comment at :207-208 already says was the intent. Gate `loading_absolute_thresh` on `link_id`, or divide by the link's latent scale factor.

**Add a gate, not a sweep:** the recurrence driver is the argument "the latent scores are standardised, therefore the loadings are O(1)". Add one line to `AGENTS.md` / the do-not-repeat ledger: *any new constant compared against Λ, a variance, an SE, or a gradient must be a ratio, a log-scale offset, or a multiple of `sd(y)` — cite R/fit-multi.R:4640.* That is cheaper and more durable than a periodic re-sweep.

**Correct the documentation defect (independent of any code fix):** R/check-consistency.R:87 and `man/gllvmTMB_check_consistency.Rd` — the bias is not "normalised by its SE".

**Decide separately (out of this class, arguably larger):** `gllvmTMB_check_consistency()` cannot run. Either implement `SIMULATE` in `src/gllvmTMB.cpp` for the supported families, or make the function fail loudly instead of returning `"information_matrix_singular"` with advice that can never help. This is an exported, documented Laplace-validation helper that structurally validates nothing — a release concern on its own terms.

**Defer, do not schedule:** the three profile/interval NOTEs (unreachable; fix before the `gllvmTMB_lv_interval_withdrawn` fence is lifted), the tweedie slot of the `log_phi` clamp, `aghq_f_tol`, and the eight *inspected-only* items in Tiers A6–A8 / B3–B4 / C2–C6. Those were read but never fitted; confirm by measurement before spending effort on any of them.
