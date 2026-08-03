# Recon: the VA SE/interval surface, and what is comparable to gllvm

Status: read-only recon for the coverage-study design. No fits run. All
line numbers are against this worktree (`claude/va-lane2`).

## 1. `.va_r3_fixed_information_blocked()` / `.va_r3_fixed_information()`

**Signatures**
- `.va_r3_fixed_information_blocked(objective, par, N, q)` --
  `R/va-r3-proto.R:1624`.
- `.va_r3_fixed_information(objective, par, route = c("auto","blocked","dense"), max_variational = NULL)` --
  `R/va-r3-proto.R:1743`. This is the single entry point; default `route =
  "auto"` dispatches to the blocked route whenever `names(par)` parses
  (`.va_r3_infer_dims()`, `R/va-r3-proto.R:1722`), else falls back to dense.
  `route = "dense"` forces the O(p^2) path; `max_variational` is accepted
  and silently ignored (kept only for old call signatures,
  `R/va-r3-proto.R:1738-1742`).

**Return shape** (both routes, identical fields): a plain list --
`se_conditional` (named numeric vector or `NULL`), `se_profile` (named
numeric vector or `NULL`), `pd_hessian` (logical), `calibrated` (always
`FALSE`), `route` (`"blocked"`/`"dense"`), `status` (character code),
`basis` (character, one-line derivation note). The dense route additionally
returns `calibration_evidence` (`R/va-r3-proto.R:1833-1839`) -- a hard-coded
string reporting a **prior, narrow** calibration check: beta only,
binomial-logit, q=2, p=8, n in {150,400}, 25 seeds, se_profile 0.935-0.950,
se_conditional under-covering 0.885-0.910. That evidence is for `beta`
(fixed-effect coefficients) ONLY -- "Latent-score SDs are NOT calibrated.
Nothing else is tested" (literal comment). It says nothing about
`theta_rr` (loadings) coverage, which is this campaign's actual target.

**Which parameters**: `se_conditional`/`se_profile` are named by
`nm[fixed_idx]` where `fixed_idx <- which(nm %in% c("beta", "theta_rr"))`
(`R/va-r3-proto.R:1632`, `:1777`). So both `beta` (fixed effects) and
`theta_rr` (packed loadings, see #2 below) get SEs from the same call --
they are not separated in the return object; a caller must subset by name.

**Preconditions**
- Single-tier only. `.va_r3_multi_tier(objective)` (`R/va-r3-proto.R:1710`)
  reads `attr(objective, "va_r3_tiers")$n_tiers`; if `> 1` both functions
  fail closed with status `"va_multi_tier_fixed_information_unsupported"`
  (`R/va-r3-proto.R:1708`, `:1747-1757`) -- H_vv is only block-diagonal by
  *unit* when a unit's observations touch a single tier; with a second tier
  the true blocks are the tier-incidence graph's connected components, and
  nothing in the parameter names can currently distinguish the safe case
  from the unsafe one (`R/va-r3-proto.R:1698-1707`).
- `par` must be named, and dims must be recoverable from names alone
  (`.va_r3_infer_dims`, `R/va-r3-proto.R:1722-1731`, valid for one tier
  only: `q = 2*n_off/n_m + 1`, `N = n_m/q`).
- `objective` must expose `$gr()` (blocked route, finite-differences the
  gradient, `R/va-r3-proto.R:1584-1619`) or `$he()` (dense route,
  `R/va-r3-proto.R:1781`).
- The resulting `H_ff` (blocked) or full Hessian (dense) must Cholesky-
  factor and invert cleanly, else `se_conditional`/`se_profile` come back
  `NULL` with a `va_non_pd_*` / `va_singular_*` status
  (`R/va-r3-proto.R:1647-1655`, `:1787-1798`).

**Turning the return into a Wald interval for a named parameter**: there is
**no packaged helper that does this** -- the campaign would have to write
it. Mechanically: `est <- par[nm == "theta_rr"]`; `se <-
info$se_profile[names(info$se_profile) == "theta_rr"]`; `est +/-
qnorm(c(alfa/2, 1-alfa/2)) * se` (Wald/normal, matching gllvm's own
`confint.gllvm`, which is also a plain normal Wald interval on `theta`/
`sigma.lv`, see #3). Nothing in this repo currently builds that interval,
because `confint.gllvmTMB_va` unconditionally errors (`R/va-methods.R:184-
191`) rather than routing through `.va_r3_fixed_information()` -- the
machinery and the public method are deliberately disconnected.

**Dense/brute-force cross-check**: yes -- `route = "dense"` on the same
`.va_r3_fixed_information()` entry point (`R/va-r3-proto.R:1743`) forms the
literal dense Hessian via `objective$he(par)` and does the same Schur
complement (`H_ff - H_fv %*% solve(H_vv, t(H_fv))`,
`R/va-r3-proto.R:1812-1815`) without exploiting block-diagonal structure.

**Existing test comparing the two routes**:
`tests/testthat/test-va-r3-prototype.R:334-409`, "R3 blocked information
reproduces the dense Schur complement exactly" -- fits a small binomial VA-R3
fixture (n=60, p=5, q=2), calls both routes, and asserts
`se_profile`/`se_conditional` agree to `tolerance = 1e-8` **whenever the
dense route is numerically available** (`dense_available` gate at
`:383`, because the dense Cholesky is BLAS-sensitive and known to fail on
some platforms, `:370-382`). Also checks the index map places every
variational coordinate exactly once (`:389-396`) and the profile-SE >=
conditional-SE invariant on the blocked route (`:386`). There is a second,
separate test at `:292-332` ("R3 fixed-parameter information marginalises
the variational block") that checks the same anti-conservatism invariant
and the fail-closed broken-Hessian path, but on a single call (not a
cross-route comparison). `test-getlv-se.R` is unrelated -- it tests
`getLV(se = TRUE)` for the main `gllvmTMB_multi` engine's unit-level latent
SCORES, a different code path entirely (nothing there touches
`.va_r3_fixed_information*`).

## 2. Parameter alignment: `theta_rr` vs gllvm's `theta` + `sigma.lv`

**Our packing** (`.va_r3_unpack_theta_rr`, `R/va-r3-proto.R:27-48`): builds
a `T x q` matrix `Lambda` (T = number of traits, q = latent dims),
lower-triangular (`Lambda[rows above diagonal] == 0` enforced on pack,
`R/va-r3-proto.R:60-64`), with the **diagonal entries free** --
`Lambda[cbind(seq_len(q), seq_len(q))] <- theta_rr[seq_len(q)]`
(`:37`), no `exp()` or other positivity transform. Sign of each diagonal
entry is therefore unconstrained.

**gllvm's packing**: `object$params$theta` -- Rd doc, `?gllvm`: "theta:
latent variables' loadings **relative to the diagonal**"; "sigma.lv:
diagonal entries of latent variables' loading matrix" (confirmed by
running `tools::Rd2txt` on the installed 2.0.13 `gllvm.Rd`). Confirmed
algebraically in `gllvm:::getResidualCov.gllvm` (installed package,
non-quadratic branch): `ResCov <- theta %*% diag(sigma.lv) %*%
t(theta %*% diag(sigma.lv))`, i.e. gllvm's **effective loading matrix is
`theta %*% diag(sigma.lv)`** -- `theta` is the SAME `T x q` lower-triangular
shape as our `Lambda`, but its leading `q x q` block is pinned to have
**diagonal exactly 1** (the "relative to the diagonal" language), with the
per-axis scale carried separately in `sigma.lv` (positive by
construction -- gllvm parameterises it on a log scale internally, unlike
our free-signed diagonal).

**What this means structurally**: both packages use the textbook
factor-analytic identifying constraint for `q > 1` (upper triangle of the
first `q` rows fixed to zero) -- so there is **no residual continuous
rotational freedom** in either `theta_rr`/`Lambda` or gllvm's
`theta`x`sigma.lv` product once that convention is applied; the only
freedom left is per-column **sign** (both), and, structurally, whichever
diagonal-vs-separate-scale split each package chose (only ours; not
gllvm's). Define `Lambda_gllvm := theta %*% diag(sigma.lv)` (same `T x q`
shape, same lower-triangular pattern, diagonal = `sigma.lv[1:q]`). Then:

- **NOT directly comparable, entry by entry, without extra work**: raw
  `theta_rr` vs raw `theta`/`sigma.lv` -- different split of the same
  quantity, and both carry an unresolved per-column sign ambiguity (our
  diagonal is unconstrained-sign; gllvm's diagonal is pinned to +1 by
  convention, so a sign flip on our side has no counterpart on theirs
  without also flipping every entry in that column of our `Lambda`).
- **Comparable up to sign, after reduction**: `Lambda` (ours, from
  `.va_r3_unpack_theta_rr`) vs `Lambda_gllvm := theta %*% diag(sigma.lv)`
  (gllvm) -- same object, same shape, provided trait order and axis
  count/order match between the two fits, and provided a sign-alignment
  step (flip each gllvm column so its diagonal entry has the same sign as
  ours, or vice versa) precedes any entrywise comparison.
- **Comparable with NO further reduction needed -- the crux answer**:
  **`Sigma := Lambda %*% t(Lambda)`** (ours, `unique = FALSE`, i.e. NO
  Psi companion -- see the model-mismatch note below) vs gllvm's
  `ResCov` as computed above. This is invariant to per-column sign flips
  (a sign flip cancels in the outer product) and is exactly the quantity
  this repository's own validation-debt register already treats as the
  canonical cross-parameterisation-safe target: `docs/design/35-
  validation-debt-register.md:341` -- `EXT-01 | extract_Sigma(level, part)
  | covered | ... | rotation-invariant`, contrasted explicitly against
  `EXT-14 | getLoadings() raw Lambda | covered | ... | rotation-variant;
  warn` (`:354`) and `EXT-15 | rotate_loadings() | ... | Rotation is for
  interpretation of loading columns; covariance, correlation, communality,
  and uniqueness remain the primary rotation-invariant summaries` (`:355`).
  This is the same precedent the CI-08 coverage register addendum invokes
  when it retired a rotation-variant per-trait `psi` (`theta_diag_B`)
  target in favour of "the rotation-invariant `Sigma_unit_diag`"
  (`docs/design/35-validation-debt-register.md:411`, citing `docs/design/
  66-capstone-power-study.md:167-176`). No 2026-06-19-dated decision doc
  specifically about FA rotation convention was found by name; the
  operative, load-bearing precedent is the EXT-01/EXT-14/EXT-15 register
  rows above plus the CI-08 psi-to-Sigma_unit_diag retirement, both of
  which already establish "Sigma, not raw loadings" as this package's
  answer to the rotation problem.

**MODEL-MISMATCH note (constraint #2 from the brief)**: gllvm has no `Psi`
/ diagonal-uniqueness tier at all -- its model is `Sigma = Lambda Lambda^T`
only. Our `unique = TRUE` fits (the default for `phylo_latent`/
`animal_latent`/etc., and opt-in for ordinary `latent()`) add `+
diag(psi)`. To keep the comparison valid, **the VA-R3 side of a head-to-
head must be fit with the loadings-only decomposition** (`unique = FALSE`
in the standalone-`latent()` sense, i.e. no Psi term at all) -- otherwise
the two arms are fitting different models and any coverage/rel_frob
contrast is void per this campaign's own failure-mode #2. `Sigma` is then
`Lambda Lambda^T` on both sides with nothing else to reconcile.

**UNCERTAIN / not verified this session**:
- Whether `.va_r3_fit()`'s VA-R3 prototype path actually exposes a
  `unique = FALSE` (no-Psi) mode, or whether Psi is baked into the R3
  ELBO unconditionally -- I did not trace `.va_r3_fit()`'s family/psi
  wiring in this pass; this must be checked before designing the fitting
  step, since if the R3 prototype's Sigma always includes a Psi term, the
  loadings-only comparison above cannot be run without reduction.
  **[flag: needs verification, not asserted]**
- Whether `u_i` (gllvm's latent scores) and our variational mean `m`/chol
  factor assume literally the same `N(0, I_q)` prior scaling -- I inferred
  this from the standard GLLVM formulation and gllvm's Rd doc language but
  did not read gllvm's TMB template to confirm. If the prior variance
  differs, `sigma.lv` and our free diagonal are not on a directly
  comparable scale even after the sign fix, and `Sigma` remains the safer
  target regardless. **[flag: inferred, not verified against gllvm's C++]**
- Whether trait/response ordering and axis (LV) ordering can be forced
  identical across a `gllvmTMB` VA-R3 fit and a `gllvm::gllvm()` fit on the
  same simulated data -- this determines whether even the sign-fixed
  `Lambda` comparison is usable, or only the axis-order-invariant `Sigma`
  is. Not tested this session. **[flag: UNCERTAIN]**

## 3. gllvm's own interval/SE surface (installed gllvm 2.0.13, read-only)

**`se.gllvm`** (`gllvm:::se.gllvm`, inspected via `deparse()`, non-quadratic
branch, lines ~180-218 of the deparsed body): for `method %in% c("VA",
"EVA")`, `sdr <- objrFinal$he(objrFinal$par)` -- the **exact TMB Hessian**
of the ELBO (not a finite-difference approximation, unlike our blocked
route's gradient-differencing). It builds a logical mask `incl` over
`names(objrFinal$par)` and explicitly **excludes**: `ePower`, `lambda2`
(unless `quadratic`), `Ab_lv`, `sigmab_lv`, `b_lv`, `lg_Ar`, `Au`, `u`,
conditionally `zeta`/`lg_phi`/`lg_phiZINB`. A second mask `incld` marks the
**random/variational block** to profile out -- `Au`, `u` (and `lg_Ar`,
`r0r` when row effects are random). Then, on a correlation-scaled Hessian
(`sdr.s`, `:180-181`):
```
A.mat <- sdr.s[incl, incl]
D.mat <- sdr.s[incld, incld]
B.mat <- sdr.s[incl, incld]
I <- A.mat - B.mat %*% solve(D.mat, t(B.mat))     # Schur complement
cov.mat.mod <- MASS::ginv(I)                       # (or solve, with a
                                                    #  Woodbury fallback if
                                                    #  ginv fails)
se <- sqrt(diag(cov.mat.mod))                      # rescaled back off sdr.s
```
This is algebraically the same `H_ff - H_fv H_vv^-1 H_vf` Schur complement
as our `.va_r3_fixed_information()`'s `se_profile`, computed from the exact
Hessian rather than our finite-difference approximation of it, and using
`MASS::ginv` (pseudo-inverse, silently tolerant of near-singularity) rather
than our `chol()`-gated fail-closed `solve()`. **UNVERIFIED** whether the
two produce the same NUMBERS on a matched fixture -- only the formula is
confirmed identical; no run was performed (task scope: inspection only).

**`confint.gllvm`** (`gllvm:::confint.gllvm`, deparsed, `:1-75`+): a plain
normal Wald interval (`alfa <- (1-level)/2`, then presumably
`est +/- qnorm(1-alfa)*se`, standard downstream in the function body) over
`parm_all <- c("sigma.lv", "theta", "LvXcoef", "beta0", "Xcoef", "B",
"row.params.fixed", "sigma", "sigmaB", "sigmaLvXcoef", "inv.phi", "phi",
"ZINB.phi", "ZINB.inv.phi", "p", "zeta", "rho.sp", "rho.lv")` intersected
with what the fitted model actually has (`:68-75`). Confirms: gllvm DOES
report an interval directly on raw `theta` (loadings) and `sigma.lv`
(per-axis scale) -- i.e. gllvm ships exactly the rotation-sign-ambiguous
raw-loading interval our own register (EXT-14) calls out as
"rotation-variant; warn" for OUR package's analogous `getLoadings()`.
gllvm does not, as far as this inspection went, offer a packaged interval
on the derived `Sigma`/`ResCov` object itself -- that would have to be
built by the campaign from `theta`+`sigma.lv`'s joint covariance the same
way our side would need to build one from `theta_rr`'s.

**`vcov.gllvm`**: not separately inspected this session (task scope did
not require it); `se.gllvm`'s `cov.mat.mod` is very likely what `vcov.gllvm`
returns or wraps, given the shared `incl`/`incld` naming convention, but
this is **inferred, not read** this session. **[flag: UNCERTAIN]**

## 10-line summary (verbatim for the reply)

The single validly-comparable quantity across the two packages'
parameterisations is `Sigma := Lambda %*% t(Lambda)` (no Psi on either
side -- gllvm has no Psi tier, so the VA-R3 side must be fit `unique =
FALSE`/loadings-only to match). `Lambda` (ours, `.va_r3_unpack_theta_rr`,
`R/va-r3-proto.R:27`) and `Lambda_gllvm := theta %*% diag(sigma.lv)`
(gllvm, from `getResidualCov.gllvm`) are the SAME `T x q` lower-triangular
object, differing only in how the diagonal-vs-scale split is made and in
an unresolved per-column sign; `Sigma` cancels the sign ambiguity and
matches this repo's own established convention (EXT-01 vs EXT-14/EXT-15 in
`docs/design/35-validation-debt-register.md`) that Sigma, not raw loadings,
is the rotation/sign-invariant cross-comparison target. Both packages'
"profile" SE is algebraically the same Schur complement `H_ff - H_fv
H_vv^-1 H_vf` (ours: `.va_r3_fixed_information()`/`_blocked()`,
`R/va-r3-proto.R:1624`/`:1743`; gllvm: `se.gllvm`'s `A.mat - B.mat %*%
solve(D.mat, t(B.mat))`), but neither package ships a `Sigma`-scale
interval directly -- both only interval raw loadings/scale parameters, so
a `Sigma`-scale coverage study must be built (delta method or simulation)
on top of the existing per-parameter machinery on both sides. Confirmed by
`test-va-r3-prototype.R:334-409`: our blocked and dense Schur routes agree
to 1e-8 where the dense route is numerically available. UNVERIFIED this
session: whether the VA-R3 prototype can actually fit loadings-only (no
Psi); whether gllvm's and our latent-score prior scale (`N(0,I)`) truly
match; whether trait/axis ordering can be forced identical across a
`gllvm::gllvm()` fit and a `gllvmTMB` VA-R3 fit on the same simulated data;
whether the two routes' SE NUMBERS (not just formula) agree on any fixture.
