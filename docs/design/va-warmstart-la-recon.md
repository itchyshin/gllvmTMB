# Recon: warm-starting the shipped Laplace engine from the VA prototype

**Status:** read-only recon. No code was edited or run. Repo:
`/private/tmp/gllvmtmb-va-lane2` (worktree, branch `claude/va-lane2`).

**Scope of the matched model** the maintainer named:
`cbind(succ, fail) ~ 0 + trait + latent(0 + trait | unit, d = q, unique = FALSE)`,
`family = binomial(link = "probit")` — single B-tier reduced-rank latent term,
loadings-only (`unique = FALSE`, no Psi diagonal tier), no dispersion parameter
(binomial has none), no missing-covariate/phylo/spatial machinery. All findings
below are qualified to this cell unless stated otherwise.

## 1. Does the engine accept starting values?

**Yes, two routes exist. Neither is a raw "hand me a start vector" argument.**

### 1a. `control$start_from` — public, documented, object-shaped

`gllvmTMBcontrol(start_from = ...)` is a formal argument
(`R/gllvmTMB.R:1461`, roxygen at `R/gllvmTMB.R:1281-1287`). It is read at
`R/fit-multi.R:4133` (`start_from_fit <- control$start_from %||% NULL`) and
applied at `R/fit-multi.R:4242-4251` via `.gllvmTMB_apply_start_from()`
(`R/init-warmstart.R:382-423`).

The mechanism is generic and already does exactly the "copy shape-matched
entries" pattern a VA warm start would need
(`R/init-warmstart.R:407-415`):

```r
for (nm in intersect(names(tmb_params), names(source_params))) {
  src <- source_params[[nm]]; dst <- tmb_params[[nm]]
  same_shape <- identical(dim(src), dim(dst)) && length(src) == length(dst)
  if (!same_shape || !is.numeric(src) || any(!is.finite(src))) next
  tmb_params[[nm]] <- src
  copied <- c(copied, nm)
}
```

**But `start_from` must be a fitted `gllvmTMB` S3 object**, not a list of
arrays: `.gllvmTMB_apply_start_from()` hard-stops if
`!inherits(start_from, "gllvmTMB")` (`R/init-warmstart.R:387-389`) and pulls
`source_params` via `start_from$tmb_obj$env$parList(start_from$opt$par,
par_full)` (`R/init-warmstart.R:394-402`). A `.va_r3_fit()` result is a plain
list (`best$par`, no `tmb_obj`/`opt`), so it cannot be passed here directly.
A dev script could only reach this route by first running a throwaway
minimal-effort Laplace fit of the *same* model shape to obtain a real
`tmb_obj`/`opt`, then overwriting `fit$opt$par` / `fit$tmb_obj$env$last.par.best`
at the `b_fix` / `theta_rr_B` offsets with VA-derived values before passing
`start_from = fit`. That is reachable but indirect and was not attempted here
(recon only).

### 1b. `control$vgh_warm_start` — internal, undocumented, but reachable — and it is the closer precedent

**This is the more relevant existing mechanism**, and it is not the one the
maintainer's brief pointed at (that was `init_strategy`, §1c below). At
`R/fit-multi.R:4253-4321` (guarded by `if (isTRUE(control$vgh_warm_start))`),
the engine seeds `tmb_params$theta_rr_B` from a fast internal variational
solve (`.vgh_build_warm_start()`, `R/vgh-warmstart.R:217`) immediately before
`TMB::MakeADFun()` (`R/fit-multi.R:5113`). This is **already the general
"seed the Laplace fit from a cheap approximate fit" hook**, built and shipped,
just wired to VGH's own engine rather than `.va_r3_fit()`.

`vgh_warm_start` is **not** a formal parameter of `gllvmTMBcontrol()`
(`R/gllvmTMB.R:1451-1519` has no such name; the signature ends in `...`, and
`...length() > 0` triggers `cli_warn("Extra arguments... are ignored")`,
`R/gllvmTMB.R:1583-1586`). But `gllvmTMBcontrol()` returns a plain base
`list()` (`R/gllvmTMB.R:1588` onward), and `fit-multi.R` reads
`control$vgh_warm_start` off whatever list is handed to `gllvmTMB(control=)`
without validating its field set. So a dev script CAN reach it today:

```r
control <- gllvmTMBcontrol()
control$vgh_warm_start <- TRUE
```

**Empirically documented findings already exist for exactly this shape of
question**, on the shipped engine (not the VA prototype):
- Seeding `theta_rr_B` (loadings) only: this is the **default** behaviour
  once `vgh_warm_start` is on (`R/fit-multi.R:4286`).
- Seeding `z_B` too (`control$vgh_warm_start_z = TRUE`): **measurably
  harmful** — "on a gaussian n=120 fixture the end-to-end ratio was 0.39x
  with z_B seeded and 4.43x without, on identical data
  (`dev/vgh/e2e-warmstart-sweep.R`)" (`R/fit-multi.R:4279-4284`). The comment
  gives the mechanism explicitly: "`z_B` is a RANDOM effect: TMB re-solves it
  in the inner Laplace problem at every outer iteration."
- Seeding `b_fix` / `log_sigma_eps` too (`control$vgh_warm_start_fixed =
  TRUE`): opt-in, not default — "measured on 4 cells it improved iteration
  count in 1 and worsened it in 3 (`dev/vgh/e2e-fixed-effects.R`)"
  (`R/fit-multi.R:4288-4293`).

**Why this precedent does not directly cover the task's model:**
`.vgh_warm_start_eligible()` (`R/vgh-warmstart.R:196-214`) requires
`family_name %in% c("gaussian","binomial","poisson")`
(`R/vgh-warmstart.R:202-206`) — binomial is admitted, but the internal solve
always uses **`link = "logit"`** for binomial
(`R/vgh-warmstart.R:248-249`: `if (identical(family_name,"binomial")) "logit"`)
regardless of the outer model's actual link, so it is not a probit-consistent
approximation. It also fits its own internal model with **`X = matrix(1,
length(y), 1)`** — intercept-only (`R/vgh-warmstart.R:255`) — so the `b_fix`
opt-in seed only ever lands when the real model also has exactly one fixed
effect column (`length(vgh_start$b_fix) == length(tmb_params$b_fix)`,
`R/fit-multi.R:4295-4296`), which the task's `0 + trait` model (T columns)
will not satisfy. So VGH's *machinery* (the "seed loadings, don't seed z"
finding) is directly relevant evidence; VGH's *specific code path* cannot be
reused unmodified for a probit link or for multi-column fixed effects.

### 1c. `control$init_strategy = "single_trait_warmup"` — the maintainer's named insertion point

Confirmed as described in the brief: `R/init-warmstart.R:59-129`, applied at
`R/fit-multi.R:5101-5111`, immediately before `MakeADFun()`
(`R/fit-multi.R:5113`). It seeds **only** the eight `log_phi_*` dispersion
vectors (`R/init-warmstart.R:64-73`) from intercept-only per-trait univariate
GLMs. It has **no counterpart in the task's matched model** — binomial has no
`phi` parameter — so this hook is a no-op for the model the maintainer wants
to warm-start, though its code shape (read `control$X`, mutate `tmb_params`
right before `MakeADFun`) is the third instance of the same pattern as §1a/1b.

### On the "~150 LOC" scout estimate

The 2026-05-18 scout's estimate concerned a full `start.fit=`-style
any-model-to-any-model API (glmmTMB's pattern). That estimate is **plausible
for that scope** but is not what's needed here: the shape-matched-copy
*mechanism* already exists twice, independently (`.gllvmTMB_apply_start_from`
and the VGH block), so a **third, narrower** hook — "seed `b_fix` /
`theta_rr_B` from a caller-supplied list, skip `z_B` by default" — is smaller
than 150 LOC: it is close to `.vgh_build_warm_start()`'s ~15-line assignment
block (`R/fit-multi.R:4285-4303`) plus a small adapter translating
`.va_r3_fit()`'s output names/packing into `theta_rr_B`/`b_fix` shapes (see
§2). The full 150 LOC estimate is closer to right if the deliverable is a
public, documented, validated `control$va_warm_start=` argument with its own
opt-in flags mirroring `vgh_warm_start`/`vgh_warm_start_z`/
`vgh_warm_start_fixed`, roxygen, and tests — i.e. the estimate is not stale,
it was scoped to more than this task strictly needs.

## 2. Parameter mapping: VA vector vs shipped engine

VA vector (`.va_r3_fit()` returns `best$par`, unpacked via names) has entries
`beta, theta_rr, log_sd_tier, m, log_L_diag, L_off, log_phi, log_sigma`
(`R/va-r3-proto.R:1110-1127`, the default-parameters constructor; the fitted
`best$par` shares these names). Shipped engine (`src/gllvmTMB.cpp`) has ~40
`PARAMETER_VECTOR`s; the relevant subset for the B-tier single-latent-term
model:

| VA name | shipped name | same quantity? | notes |
|---|---|---|---|
| `beta` | `b_fix` (`src/gllvmTMB.cpp:636`) | Same role (fixed effects), **ordering not guaranteed identical** | VA's `X` is caller-supplied (`.va_r3_fit(X=...)`, `R/va-r3-proto.R:2098`); shipped `X_fix` is built via `stats::model.matrix(parsed$fixed, mf)` (`R/fit-multi.R:2153`) from the `0 + trait` formula. They align 1:1 only if the caller builds `X` with `model.matrix(~0+trait, d)` on data whose trait-factor level order matches. Not verified here — recon only. |
| `theta_rr` | `theta_rr_B` (`src/gllvmTMB.cpp:666`) | **Yes, packing verified identical** | See below. |
| `m` | `z_B` (`src/gllvmTMB.cpp` — `z_B.col(s)` used at `:975`) | Same estimand (unit-level latent scores) but **different statistical object**: `m` is a *variational posterior mean* (a free parameter in the VA objective); `z_B` is a Laplace *random effect*, re-solved by TMB's inner problem at every outer iteration, not a free parameter the outer optimiser sees directly. | Orientation: VA's `m` has length `N*q` and is reshaped consistently with `log_L_diag`, i.e. `matrix(exp(log_L_diag), nrow=N, ncol=q)` (`R/va-r3-proto.R:86`) — **unit-major**. Shipped `z_B` is indexed `z_B.col(s)` for site `s` (`src/gllvmTMB.cpp:975`), i.e. **`d_B x n_sites`** (VGH's own comment confirms this independently: "The template's z_B is d_B x n_sites", `R/vgh-warmstart.R:275-276`). A transfer would need `m` reshaped to `N x q` then transposed to `q x N`. **This was not verified end to end here — UNKNOWN whether `.va_r3_fit`'s unit ordering (`unit_id`) matches the shipped engine's `site_id` ordering without an explicit relabelling.** |
| `log_sd_tier` | `theta_diag_B` (`src/gllvmTMB.cpp:677`, log-scale: `sd_B <- exp(theta_diag_B)`, `:1064`) | Same role (Psi diagonal tier), **but absent from this task's model** | `unique = FALSE` on both sides means `log_sd_tier` has length 0 in VA (`n_sd = 0` since `layout$total_sd` is 0 for a loadings-only tier, `R/va-r3-proto.R:1089,1096`) and `theta_diag_B` is mapped off in the shipped engine for the same reason. No transfer needed or possible for the matched cell. |
| `log_phi` | `log_phi_*` (8 family-specific vectors, `src/gllvmTMB.cpp:799-826`) | No counterpart needed | Binomial carries no phi; VA's `log_phi` is a fixed placeholder (`rep(0, T)`, mapped off, `R/va-r3-proto.R:1119`). |
| `log_sigma` | `log_sigma_eps` (`src/gllvmTMB.cpp:637`, single scalar, gaussian residual) | No counterpart for this family | Binomial has no residual-SD parameter; VA's per-trait `log_sigma` is mapped off for non-Gaussian traits (`R/va-r3-proto.R:1120-1126` comment). |
| `log_L_diag`, `L_off` | **none** | No shipped counterpart at all | These parameterise the variational posterior's Cholesky covariance — a quantity that exists only because VA has an explicit approximate posterior over `z`. Laplace has no analogous free parameter; its curvature is obtained from the Hessian of the joint NLL at the mode, not from an optimised covariance parameter. |

### Verifying the "live-engine packing, raw diagonal first" claim

**Confirmed correct**, by direct comparison, not by trusting the comment.

- VA unpack (`R/va-r3-proto.R:27-48`, `.va_r3_unpack_theta_rr`): diagonal
  first (`theta_rr[seq_len(q)]`, line 37), then for each column `j = 1..q`,
  the strict-lower rows `(j+1):T` of that column, in order (lines 39-46) —
  i.e. **column-major fill of the strict lower triangle**, diagonal first.
  `.va_r3_theta_length(T,q) = T*q - q*(q-1)/2` (`R/va-r3-proto.R:9-13`).
- Shipped unpack (`src/gllvmTMB.cpp:945-968`): `head(d_B) = lam_diag, tail =
  lam_lower (column-major fill of the strict lower triangle)` (comment at
  `:945-947`, code at `:957-967`). `expected_nt = p*rank - rank*(rank-1)/2`
  (`:954`) — the same length formula with `p=T, rank=q`.
- The template header's own claim, `inst/tmb/gllvmTMB_va_r3.cpp:407-408`
  (`theta_rr` — "dense tiers' packed loadings, tier order; live-engine
  packing, raw diagonal first") and the reconstruction comment at
  `inst/tmb/gllvmTMB_va_r3.cpp:628` ("Exact live-engine reconstruction... raw
  diagonal, then...") match what `src/gllvmTMB.cpp` actually does.

Both are diagonal-first, column-major-lower, and neither transform is
logarithmic — the diagonal entries are **raw values, not log-SDs**, on both
sides. So `theta_rr -> theta_rr_B` is a same-length, same-order, same-scale
copy for a single dense B-tier at matching `(T, q)` — no repacking needed
beyond a direct `as.numeric()` copy, **conditional on §1a/1b's `q`/`T`
matching** (not independently re-verified here for arbitrary `q`; verified
for the packing *formula*, not run against live data).

## 3. Log-scale variance coordinates that must be RESET, not transferred

Per the `.va_r3_fit_warm()` AC->GH finding (`dev/va-speed/25-WARM-ROUTE-PSI-FINDING.md`,
§3, §6) the mechanism is: any parameter on a **log scale** is an attracting
boundary near 0, because `d f / d(log sigma) = (df/dsigma) * sigma` vanishes
as `sigma -> 0`. In the shipped engine, the coordinates fitting that
description (all confirmed by `exp(...)` transforms in `src/gllvmTMB.cpp`)
include:

- `theta_diag_B` / `theta_diag_B_slope` (`:677,:681`, `exp()` at `:1064`) —
  the B-tier Psi diagonal, i.e. the shipped analogue of VA's `log_sd_tier`.
- `theta_diag_W` (`:689`) — same role, W-tier.
- `log_sd_b` (`:768`) — ordinary random-intercept log-SDs.
- `log_sigma_mi`, `log_sd_mi_group`, `log_sd_x` (`:642, :647, :654`) —
  missing-covariate model variances.
- `log_sd_phy_diag` (`:754`), `log_sd_spde_b` (`:728`), `log_tau_spde`
  (`:711`) — phylogenetic/spatial tier variances.
- `log_sigma_re_int` (`:788`) — further random-intercept variances.
- `log_sigma_eps` (`:637`) — Gaussian residual SD.
- `log_phi_*` (8 vectors, `:799-826`) and `log_sigma_student`,
  `log_sigma_lognormal_delta` (`:820, :831`) — dispersion/scale parameters
  for non-Gaussian/heavy-tailed families.

**For the task's specific matched cell (binomial probit, single B-tier,
`unique = FALSE`, no dispersion), none of these are active** — they are
either mapped off or absent from this model's parameter set (§2's
`theta_diag_B` row). So the AC->GH scar tissue's literal failure mode (a
seeded log-variance landing on the zero boundary) **has no coordinate to
attach to in this exact cell**. The nearest analogous risk in this cell is
not a log-scale variance at all — it is **`z_B`**, a natural-scale random
effect, which §1b's VGH evidence already shows is harmful to seed for a
different, structural reason (it is re-solved by TMB's inner Laplace problem
every outer iteration, so a seed does not save what it costs). If the
maintainer later extends the warm start to a `unique = TRUE` variant of this
model, `theta_diag_B` becomes live and should be treated exactly like
`log_sd_tier` was in the AC->GH finding: reset to its ordinary default
(`log(0.3)`-scale, mirroring `R/va-r3-proto.R:1096`) rather than transferred.

## 4. Single biggest obstacle

**There is no evidence, for this exact model, on whether transferring `beta`
+ `theta_rr_B` (skipping `z_B`, per the VGH precedent) actually reaches the
same Laplace optimum faster** — the only measurement in this repo of
"warm-start a Laplace/GH-family fit from a cheaper approximate fit and check
it lands at the *same* optimum, not just a fast one" is `dev/va-speed/25-
WARM-ROUTE-PSI-FINDING.md`, and that measurement is entirely **within the VA
engine** (AC warm-starting GH), not VA-to-Laplace. The VGH block
(`R/fit-multi.R:4253-4321`) is the closest analogue reaching into the shipped
Laplace engine, but it is gated to `binomial-logit`/`gaussian`/`poisson`
with an intercept-only internal fit, so it has never been measured against a
probit link or against a model with `T > 1` fixed-effect columns — i.e. it
has never been measured on anything resembling this task's model either.

Concretely, building the transfer requires:
1. An adapter turning `.va_r3_fit()`'s `beta`/`theta_rr` into
   `b_fix`/`theta_rr_B`-shaped inputs, matching `X_fix`'s exact column
   order (§2, `beta` row) — unverified whether this alignment holds
   automatically or needs explicit column-name matching.
2. A resolution of the `m`-to-`z_B` orientation and unit-ordering question
   (§2, `m` row) if `z_B` is seeded at all — and per the VGH z_B finding,
   the working hypothesis going in should be **don't seed z_B**, mirroring
   the shipped default.
3. A route into `tmb_params` before `MakeADFun()` (§1) — the least of the
   three obstacles, since two precedented hooks already exist at that exact
   point in `R/fit-multi.R` (`:4253` and `:5101`), and adding a third,
   narrower one (`b_fix`/`theta_rr_B` only, VA-sourced) is a small, well-
   precedented change, not a new architecture.

None of this was measured in this recon (role: read-only). The obstacle is
squarely (1)+(2) — correctness of the transfer, not the existence of an
insertion point.
