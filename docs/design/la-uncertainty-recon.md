# Recon: closing the two Laplace-engine uncertainty gaps (VA lane 2)

Status: READ-ONLY recon. No files edited except this one. One repo-only
grep/read investigation; no fit was run (existing behaviour was traced from
source, which was sufficient — no ambiguity required a toy fit).

Scope note: this recon only inspected the shipping `gllvmTMB_multi` /
`fit-multi.R` Laplace engine, per the task brief. `R/julia-bridge.R`
(`gllvmTMB_julia`) and the VA/EVA research-spike route are out of scope and
already error/fence `se = TRUE` (`R/output-methods.R:164-169`).

## 1. What does `fit$sd_report` actually contain?

`fit$sd_report` is the direct return value of one `TMB::sdreport()` call,
stored verbatim (`R/fit-multi.R:6082-6094`, list-assigned at
`R/fit-multi.R:6122`):

```r
sd_rep <- TMB::sdreport(obj, par.fixed = opt$par, getJointPrecision = FALSE)
```

So it is a stock TMB `sdreport` object with the standard fields: `par.fixed`,
`cov.fixed`, `par.random`, `diag.cov.random`, `pdHess`, `gradient.fixed`,
`value`/`sd`/`cov` (for every `ADREPORT()`'d quantity in the C++ template),
and — because `getJointPrecision = FALSE` — **no** `$jointPrecision` field.
This is the only `sdreport()` call site in the R source
(`grep -n "sdreport(" R/*.R` finds exactly one production call, at
`R/fit-multi.R:6087`; every other hit is a doc comment).

Two independent uncertainty mechanisms live in this one object:

- **`diag.cov.random`**, indexed against `names(sd_rep$par.random)`: the
  marginal variance of every individual random-effect coordinate, already
  including TMB's generalized-delta-method correction for propagated
  fixed-effect uncertainty (this is why `.getLV_se()`, discussed in §2, needs
  no extra machinery — it is not a naive random-effects-only variance).
  `getJointPrecision` does **not** gate this: TMB computes it whenever
  `random` is non-empty, regardless of that flag. It gives the SE of each
  random-effect coordinate **on its own**, not the covariance *between* two
  different coordinates or between a random coordinate and a fixed one.
- **`cov.fixed`** / the `summary(sd_rep, "fixed")` table: SEs (and full
  covariance) for `par.fixed` and every `ADREPORT()`'d derived quantity —
  e.g. `B_lv_unit` (`src/gllvmTMB.cpp:1014`), `sd_phy_diag`
  (`src/gllvmTMB.cpp:1253`), `b_fix` (`src/gllvmTMB.cpp:2852`),
  `ordinal_cutpoints` (`src/gllvmTMB.cpp:2912`). Consumed today via
  `summary(fit$sd_report, component)` (`R/extractors.R:781`,
  `R/cv-internal.R:361`) and via `fit$sd_report$cov.fixed` directly
  (`R/loading-ci.R:5,18,183`).

Neither field gives the **joint** covariance across a fixed effect and a
random-effect block, or across two different random-effect blocks — that
would require `$jointPrecision`, which this fit never requests (§5).

## 2. How `getLV(se = TRUE)` turns this into per-unit SEs

Traced end to end, `R/output-methods.R`:

1. `getLV(fit, level, se = TRUE)` (`R/output-methods.R:150-189`) validates
   the request (rejects Julia-bridge fits at `:164-169`, rejects
   `rotate != "none"` at `:170-176` because rotation changes the
   covariance and that propagation isn't implemented), gets the point
   estimates from `extract_ordination()` (`:177`), then calls
   `.getLV_se(fit, level, scores = ord$scores)` (`:187`).
2. `.getLV_se()` (`R/output-methods.R:207-249`) is the actual mechanism:
   - Rejects predictor-informed `lv_B` fits (`:208-214`) — the score
     mean's own uncertainty isn't propagated yet, a real, documented gap
     but a different one from what this task is about.
   - Requires `fit$sd_report` to be non-`NULL` (`:216-222`) and warns +
     returns `NA` SEs if `!pdHess` (`:235-240`).
   - Picks the TMB parameter block name — `"z_B"` or `"z_W"` — and the
     block's declared shape (`d_B`/`n_sites` or `d_W`/`n_site_species`,
     both fields already stored on the fit object) (`:223-225`).
   - `idx <- which(names(sd_rep$par.random) == z_name)` (`:226-227`) —
     locates every element of that block inside the flat `par.random`
     vector by exact name match, and asserts the count equals `d * n`
     (`:228-234`) as a staleness guard.
   - `se_vec <- sqrt(pmax(sd_rep$diag.cov.random[idx], 0))` (`:244`) —
     the entire numerical step. `diag.cov.random` is parallel to
     `par.random` (same length, same order), so indexing by `idx` reads
     the SE of exactly the `z_B`/`z_W` coordinates.
   - Reshapes with `t(matrix(se_vec, nrow = d, ncol = n))` (`:246`) — the
     identical reshape convention `extract_ordination()` uses for the
     point estimates (`R/extractors.R:478,507`), so `scores[i,k]` and
     `se[i,k]` refer to the same (unit, axis) cell by construction.

Nothing here is specific to `z_B`/`z_W` beyond the block name and the two
shape integers. Every other block enumerated in §3 sits in exactly the same
`par.random` / `diag.cov.random` pair, addressable by the same
`which(names(...) == block_name)` pattern — see §4.

## 3. Every random-effect block the engine can fit

The authoritative enumeration is `R/fit-multi.R:5047-5093`, which builds the
`random` character vector passed to `TMB::MakeADFun(..., random = random,
...)` (`:5117`) and is then stored verbatim on the fit as `fit$random`
(`R/fit-multi.R:6141`, list field `random = random,`). Every block is
therefore self-documenting per fit — no need to special-case which blocks a
given fit has.

| Block name | Trigger / meaning | Shape metadata on fit | Per-unit SE reachable via a public function today? |
|---|---|---|---|
| `b_fix` | REML-only: fixed-effect coefficients integrated by Laplace | n/a (fixed-effect count) | N/A — not a "per-unit" random effect; already covered by ordinary `summary()`/`vcov()` fixed-effect SEs |
| `z_B` | ordinary between-unit latent scores | `d_B`, `n_sites` | **YES** — `getLV(fit, level="unit", se=TRUE)` |
| `z_B_slope` | augmented B-tier random-slope latent block (Design 56 §9.5a) | `d_B_slope` (on fit) | **NO** — no accessor at all, point estimate or SE |
| `s_B` | B-tier diagonal (unique/Psi) random effect | `n_traits`, `n_sites` | **NO** |
| `s_B_slope` | augmented B-tier diagonal random-slope block | — | **NO** |
| `z_W` | ordinary within-unit latent scores | `d_W`, `n_site_species` | **YES** — `getLV(fit, level="unit_obs", se=TRUE)` |
| `s_W` | W-tier diagonal random effect | `n_traits`, `n_site_species` | **NO** |
| `p_phy` | `propto`-style phylogenetic per-species random effect | `n_species`, `n_traits` (used directly in `predict.gllvmTMB_multi`, `R/methods-gllvmTMB.R:1700-1709`) | **NO** — point estimate is read ad hoc inside `predict()`'s RE-contribution loop, never exposed as an accessor; no SE anywhere |
| `q_sp` | diagonal species random effect | — | **NO** |
| `r_c2` | diagonal `cluster2` random effect | — | **NO** |
| `e_eq` | `equalto()` shared/equal-covariance random effect | — | **NO** |
| `omega_spde` | plain SPDE spatial field | mesh, `d_spde_lv` when relevant | **NO** |
| `omega_spde_lv` | spatial-latent SPDE field (reduced-rank spatial ordination) | `d_spde_lv`, `mesh` | **NO** |
| `omega_spde_aug` | augmented spatial random-slope field | — | **NO** |
| `g_spde_slope` | spatial-latent random-slope block | — | **NO** |
| `g_phy` | phylogenetic reduced-rank latent scores | `d_phy` (on fit) | **NO** — confirmed by `grep`: `g_phy` appears only in engine plumbing (`fit-multi.R`, `aghq-gate.R` comment, `profile-derived.R` — none of which extract per-species SEs), never in an extractor |
| `g_phy_diag` | phylogenetic diagonal random effect | — | **NO** |
| `g_kernel` | generic dense-kernel latent scores (Design 65 quartet) | — | **NO** |
| `g_kernel_diag` | dense-kernel diagonal random effect | — | **NO** |
| `b_phy_aug` | correlated phylogenetic random-slope block | — | **NO** |
| `b_phy_slope` | phylogenetic random-slope block (uncorrelated) | — | **NO** |
| `g_phy_slope` | phylo-latent augmented random-slope block | — | **NO** |
| `u_re_int` | ordinary `(1 \| group)` random intercepts (bar syntax) | term metadata in `fit$re_int$groups`/`$n_groups`/`$offsets` (`R/fit-multi.R:6283-6287`) | **NO exported accessor at all** — `R/re-int.R:53-55` documents only the raw escape hatch `fit$tmb_obj$env$parList()$u_re_int` for point estimates; no SE, no wrapper |
| `x_mis` | latent missing-predictor draws (continuous route, Phase 2a) | — | **NO** |
| `u_mi_group` | grouped missing-covariate intercepts (Phase 2b) | — | **NO** |
| `g_x` | phylogenetic missing-covariate field (Phase 3) | — | **NO** |

Summary: **`z_B`/`z_W` are the only blocks with a public SE accessor.**
Every other block — including ones as basic as ordinary `(1|group)`
random intercepts and the phylogenetic/spatial latent scores that are the
package's headline features — has its SE sitting unused in
`sd_report$diag.cov.random`, reachable by the exact same
`which(names(sd_rep$par.random) == "<block_name>")` pattern
`.getLV_se()` already uses, with no wrapper written. This matches the
task's framing precisely: **gap 1 is a build gap, not a structural one.**

One caveat worth flagging loudly, since the task asked for anything found
already closed or unexpectedly hard: `s_B_slope`'s shape/order convention
was not traced in this recon (no code currently reads it back for
reshaping — `diag_B_all_skipped` fencing at `R/fit-multi.R:5036-5038` shows
the diagonal blocks have edge cases where the block name is conditionally
excluded from `random` even when `use$diag_B` is set). A generic accessor
must reconstruct each block's `(d, n)` shape from the *same* per-fit
metadata the engine used to build `tmb_params` in the first place, not
assume every block is `matrix(nrow=d, ncol=n)` — the reshape convention
varies (e.g. `re_int`'s flat vector packed by term with offsets, vs.
`z_B`'s dense `d × n` matrix). This is a real per-block design task, not
just one loop over `fit$random`.

## 4. Reachable from an already-fitted object, or does it force a refit / extra `sdreport()`?

**Gap 1 (per-block SEs) is reachable from the ALREADY-FITTED object with NO
refit and NO extra `sdreport()` call.** `fit$sd_report` already contains
`diag.cov.random` for every block in `fit$random` — all of them were
included in the one `TMB::sdreport()` call at fit time
(`R/fit-multi.R:6082-6094`), because `TMB::MakeADFun(..., random = random,
...)` was told about every active block up front (`R/fit-multi.R:5047-5117`)
and `sdreport()` computes `diag.cov.random` for the *entire* random vector
in one pass, not block-by-block on request. This was verified by reading
the `sdreport()` call site itself, not inferred: there is exactly one
`sdreport()` call in the whole engine, it runs unconditionally over the full
`random` vector, and `getJointPrecision = FALSE` does not gate
`diag.cov.random` (only `$jointPrecision`, which nothing in gap 1 needs).
So gap 1 is exactly as cheap as `getLV(se=TRUE)` already is: an O(1) name
lookup into arrays that already exist on disk/in memory the moment
`gllvmTMB()` returns.

**Gap 2 (predict-level fitted-value SEs) is NOT reachable from the
already-fitted object without new computation.** See §5 for why: `eta` is
never `ADREPORT()`ed in the C++ template, and the one `sdreport()` call sets
`getJointPrecision = FALSE`, so the cross-covariance between different
random-effect blocks and between random effects and fixed effects — which a
delta-method SE for `eta` (a function of *multiple* blocks summed together,
e.g. `eta = X %*% b_fix + Lambda_B %*% z_B + s_B + ...`) genuinely needs —
is not present in `fit$sd_report` today. Closing gap 2 needs one of:

- **(a)** An additional `TMB::sdreport(obj, getJointPrecision = TRUE)` call
  reusing the existing `obj` and `opt$par` (no refit — `obj$env$last.par.best`
  is already forced to the optimum at `R/fit-multi.R:6077-6078`), plus an
  R-side numerical Jacobian of `eta` with respect to the full parameter
  vector (e.g. finite differences via repeated `obj$report(par)` calls,
  which are cheap forward evaluations, not re-optimizations) to assemble
  `Var(eta) = J %*% Sigma_joint %*% t(J)`. This is genuinely new, nontrivial
  R-side machinery, and the extra `sdreport(getJointPrecision=TRUE)` call is
  more expensive than the current one (full joint precision factorization
  over fixed + every random block).
- **(b)** Adding `ADREPORT(eta)` to `src/gllvmTMB.cpp` so TMB's own
  generalized delta method computes `Var(eta)` automatically as part of the
  standard `sdreport()` (no `getJointPrecision=TRUE` needed for this path,
  since ADREPORT'd generalized-delta-method SEs use the joint precision
  internally regardless of that flag — the same mechanism that already makes
  `diag.cov.random` correct). This is architecturally the cleaner fix but
  requires editing the shared C++ engine and recompiling the package, which
  is out of this worktree's file scope (`R/output-methods.R`,
  `R/extractors.R`, `R/predict*.R`, or a new `R/re-uncertainty.R` — not
  `src/gllvmTMB.cpp`) and should be reported as a **blocked dependency**
  exactly as the task brief anticipated for `R/fit-multi.R`.

Either route is real, additive work — not a name-lookup like gap 1.

## 5. What `predict()` returns today, and where `se.fit` would attach

`predict.gllvmTMB_multi()` (`R/methods-gllvmTMB.R:1600-...`) returns a
`data.frame` of unit/species/trait identifiers plus a single `est` column
(`:1635-1642` for `newdata = NULL`; the `newdata` branch builds `eta`
similarly from `.gllvmTMB_predict_fixed_eta()` plus a manual per-block RE
loop, e.g. the `p_phy` handling at `:1700-1709`). There is no `se.fit`
argument, no covariance-aware code path, and no `type = "se"` case anywhere
in the function. For `newdata = NULL` the point estimate is read directly
from `object$report$eta` (`:1626`) — the raw `REPORT(eta)` output
(`src/gllvmTMB.cpp:2853`), which carries no uncertainty information by
construction (`REPORT()` is a bare report, not `ADREPORT()`).

Confirmed by direct search: `grep -n "ADREPORT" src/gllvmTMB.cpp` has no
`eta` hit; `grep -n "REPORT(eta)"` finds exactly one, the plain `REPORT`
call at `:2853`. `eta` is declared as `vector<Type> eta(y.size())` at
`:849` and filled in per-family/per-row — it is a genuine deterministic
function of `(b_fix, z_B, s_B, z_W, s_W, p_phy, ...)`, i.e. exactly the kind
of sum-of-random-effects-plus-fixed-effects quantity a delta method targets,
but the template never marks it for `ADREPORT`.

**The sdreport covariance an `se.fit` path needs is not currently
available**, for the reason in §4: `getJointPrecision = FALSE`
(`R/fit-multi.R:6088`) means the cross-block covariance terms a
multi-random-effect linear predictor needs are absent from `fit$sd_report`.
Confirmed: `grep -rn "getJointPrecision" R/*.R` finds exactly the one
`FALSE` call site plus one documentation mention in `getLV()`'s `@section
Standard errors` roxygen block (`R/output-methods.R:122`) that explicitly
describes the joint-precision route as the (unused-in-production)
verification method for gap 1, not something the engine actually computes.

If `se.fit` is built, the natural attachment point is inside
`predict.gllvmTMB_multi()` right after `eta` is assembled (`:1626` for the
`newdata=NULL` branch, after the RE-contribution loop for the `newdata`
branch), returning an additional `se` column — additive, matching the
worktree's "new optional argument defaulting to current behaviour"
constraint, e.g. `predict(fit, se.fit = FALSE)` with the current `est`-only
data frame as the unchanged default return.

## Obstacles / things that made this harder than expected

- `fit$sd_report` field semantics (why `diag.cov.random` already
  incorporates fixed-effect uncertainty propagation, and why that is
  different from what `getJointPrecision` adds) are undocumented in this
  repo outside `R/output-methods.R`'s roxygen for `getLV()`; the
  distinction had to be reconstructed from TMB's own generalized-delta-
  method design rather than read off a comment in this codebase. Flagging
  this so whoever builds gap 1's wrapper writes it down once, centrally,
  rather than re-deriving it per block.
- Per-block reshape conventions are NOT uniform (`z_B`/`z_W` are dense
  `d × n` matrices; `u_re_int` is a flat vector packed by term with
  offsets in `fit$re_int`; several blocks — `z_B_slope`, `s_B_slope`,
  `g_kernel_diag`, the missing-predictor blocks — have no existing reader
  in the R source at all, so their shape convention would need to be
  reverse-engineered from `src/gllvmTMB.cpp`'s parameter declarations
  before a generic accessor could reshape them correctly). A single
  generic "SE for any block" function is not a one-line generalization of
  `.getLV_se()`; it needs a per-block shape lookup table.
- No good news to report on gap 2: nothing already closes it elsewhere in
  the tree (checked `R/*.R` broadly for `jointPrecision`/`ADREPORT.*eta`
  patterns; both are absent everywhere, not just in the obvious places).
