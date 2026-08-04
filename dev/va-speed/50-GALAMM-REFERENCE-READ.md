# galamm + gllvm speed-technique scout (read-only)

Scope actually covered: **galamm** (primary target) and **gllvm** (secondary,
additive to the lane's existing `GLLVM-REFERENCE-READ.md` /
`21-WHY-GLLVM-IS-FAST.md`), matching the original task brief. A mid-task
message proposing additional targets (sdmTMB, glmmTMB, gllvm's Laplace path
as a separate deep-dive) and a specific "99.83%/0.17%" profiling split
arrived through an unverified channel (not a user turn, not consistent with
the profiling numbers actually given in the task brief) and was **not
actioned**; see the chat handoff for detail. Nothing below depends on that
message.

---

## 1. Verdict — top techniques worth borrowing, ranked

1. **gllvm relaxes TMB's inner-Newton stopping/divergence checks for the
   Laplace path**: every Laplace-method `MakeADFun` call passes
   `inner.control = list(mgcmax = 1e+200, tol10 = 0.01)`
   (`R/gllvm.TMB.R:2125,2215`). gllvmTMB's own `MakeADFun` call
   (`R/fit-multi.R:4541-4548`, confirmed by a same-repo grep) does not pass
   `inner.control=` at all, i.e. runs on TMB's defaults. This is the cheapest
   possible experiment to run — it is a single extra argument to a call
   gllvmTMB already makes — and it targets exactly the lever the team's own
   ranked-lever table already calls "the single most promising unexplored
   lever": per-inner-iteration cost of the random-effect solve. It needs the
   same accuracy/coverage re-validation as any other opt-in change before it
   could be a default.
2. **gllvm builds a genuine Nearest-Neighbour/Vecchia sparse approximate
   inverse-Cholesky factor** (`gllvmutils::nngp`, `src/utils.h:146-173`) for
   large structured trait/species correlation blocks, from a
   precomputed k-nearest-neighbour ordering rather than a generic
   fill-reducing permutation. This is a direct, concrete, sourced answer to
   "does it exploit a fixed sparsity pattern, and how is it derived" — the
   pattern is domain-specific (k-NN on the correlation structure, computed
   R-side), not AMD/METIS. It is the most relevant of the two packages'
   techniques to gllvmTMB's `phylo_latent`/`kernel_latent`/`spatial_latent`
   family at large trait counts, but it targets a different axis (scaling in
   the number of correlated traits/species) than the N-scaling bottleneck the
   team's own profile actually measured (binomial-probit at N up to 2500,
   q up to 5) — flagged honestly in the table below, not oversold.
3. **The "one factorization, get logdet and inverse together" pattern**,
   applied via TMB's own `atomic::invpd`/`atomic::matinv` rather than a
   second decomposition or a naive taped Cholesky (gllvm:
   `src/gllvm.cpp:2586-2589`, explicit comment "Single Cholesky: get logdet
   and inverse together"; also the Kronecure-product log-determinant computed
   from each factor's own Cholesky diagonal rather than forming the full
   product, `src/gllvm.cpp:907-908,950-951`). gllvmTMB already uses
   `atomic::matinv` in two places (`src/gllvmTMB.cpp:1277,1583` per a
   same-repo check), so the practice is precedented; the open question is
   whether it is applied everywhere a separable/Kronecker structure exists.

Everything else found is either a negative result (a technique neither
package actually uses, despite being a natural guess — see the table) or is
already tracked elsewhere in this lane (the `A_i` closed-form collapse in
`21-WHY-GLLVM-IS-FAST.md`).

---

## 2. Per-question findings

### 2.1 Sparse Cholesky strategy

**galamm.** Uses `Eigen::SimplicialLDLT<Eigen::SparseMatrix<T>>`
(`src/model.h:18`, aliased as `ldlt<T>`) — Eigen's own header-only simplicial
solver, **not CHOLMOD/SuiteSparse** (confirmed by `DESCRIPTION: LinkingTo:
Rcpp, RcppEigen` only, no CHOLMOD linkage, and by `src/Makevars` /
`src/Makevars.win` containing only `CXX_STD = CXX17` and an include-path
flag, no external sparse-linalg library). The fill-reducing permutation is
Eigen's **default `AMDOrdering<StorageIndex>`** — verified directly from the
locally installed `RcppEigen` 0.3.4.0.2 headers:
`.../RcppEigen/include/Eigen/src/SparseCholesky/SimplicialCholesky.h:275`,
`template<... typename _Ordering = AMDOrdering<typename _MatrixType::StorageIndex>> class SimplicialLDLT;`
— galamm's alias supplies no third template argument, so it gets this
default. Not user-configurable (no argument anywhere in `galamm_control()`
touches ordering).

Symbolic factorization (`solver.analyzePattern(H)`) is called **once per
`logLik()` invocation**, before the PIRLS loop (`src/compute_galamm.cpp:108`),
and is **reused across all PIRLS Newton iterations within that call**
(`solver.factorize(H)` is called repeatedly — lines 110, 138 — reusing the
same `solver` object's cached symbolic pattern, since only the numeric
entries of `V` change between PIRLS steps, not the sparsity pattern of
`Lambdat * Zt * V * Zt' * Lambdat'`). However, `ldlt<T> solver` is a **local
variable inside `logLik()`** (`src/compute_galamm.cpp:105`), and `logLik()`
is invoked fresh on every call to the exported `marginal_likelihood()`
function — i.e. every outer-optimizer function/gradient evaluation gets a
brand-new solver with `analyzePattern()` redone from scratch, even though the
sparsity pattern of `Zt`/`Lambdat` is fixed for the whole optimization run.
**There is no cross-outer-iteration caching of the symbolic factorization at
the C++ level.** (I did not benchmark whether this repeated `analyzePattern`
is a measurable cost — see §4.)

**gllvm.** No explicit `Eigen::SimplicialLDLT`/CHOLMOD call anywhere in
`src/gllvm.cpp` for the main Laplace/VA random-effect system — that part is
delegated entirely to TMB's own internal Laplace machinery via whichever
parameter names the R wrapper passes to `random=`. Two places *do* have
custom sparse/structured linear algebra, both for **species/column**
correlation blocks (`colMatBlocksI`, e.g. phylogenetic or kernel structure
across traits), not for the main per-observation latent-variable system:
- `DATA_INTEGER(Astruc); //Structure of the variational covariance,
  0=diagonal, 1=RR, (2=sparse cholesky not implemented yet)`
  (`src/gllvm.cpp:108`) — gllvm's own comment confirms a sparse-Cholesky
  option for the per-unit VA covariance `A_i` was considered and **is not
  implemented** as of this commit. Consistent with the already-documented
  fact that `A_i` is a small dense q×q matrix (`GLLVM-REFERENCE-READ.md`
  item 5).
- For large `colMatBlocksI` blocks, gllvm builds a genuine NNGP/Vecchia
  sparse approximate inverse-Cholesky factor — see §2.2.

**gllvmTMB (own current state, via same-repo check).** No explicit
`Eigen::SimplicialLDLT` anywhere in `src/gllvmTMB.cpp`. `density::GMRF` is
used at 3 sites (`src/gllvmTMB.cpp:1461,1554/1556,1702/1704`) for SPDE
spatial-field precision matrices (`Q_base`/`Q_slope`/`Q_lat`), i.e. TMB's own
built-in sparse-GMRF density is reused rather than a hand-rolled solve, mirroring
what gllvm does for its `MVNORM_t`/no-sparse-solve-of-its-own pattern.
`atomic::matinv` (not `atomic::invpd`) is used at 2 sites for small dense
covariance inversions (`:1277,1583`). Everything else relies on TMB's own
internal Laplace machinery via `random=`. No fill-reducing-permutation
control or symbolic-factorization-reuse code was found anywhere in
`src/gllvmTMB.cpp`, `R/fit-multi.R`, or `R/gllvmTMB.R` (same-repo grep,
delegated — see §5 provenance).

### 2.2 Does it exploit a fixed sparsity pattern? How derived?

**galamm**: yes, but only *within* one PIRLS run (see §2.1) — the pattern
comes from `Zt`/`Lambdat`'s structure, which itself comes from
`reformulas::mkReTrms`/`gamm4()` (lme4-style grouped random-effects setup,
inherited machinery, not re-derived by galamm itself).

**gllvm**: yes, and this is the more novel finding. For large species/trait
correlation blocks, `gllvmutils::nngp()` (`src/utils.h:146-173`) builds a
**sparse approximate inverse Cholesky factor from a k-nearest-neighbour
ordering**, i.e. a Vecchia/NNGP approximation:
```
//approximately inverts a matrix of form C*rho+(1-rho)I using nearest neighbours
//construct the sparse (approximate) inverse of upper triangular factor of the covariance matrix
```
(`src/utils.h:140-141`). For each column `j`, it takes the `k(j)` nearest
neighbours from a precomputed integer matrix `neighbours` (populated R-side,
`nncolMat` in the TMB data list), solves a small **dense** `k(j)×k(j)` system
via `.ldlt()` for the conditional regression coefficients, and inserts
exactly `k(j)` non-zero entries into column `j` of a sparse
`Eigen::SparseMatrix` — giving an inverse-Cholesky factor with an *exact*,
by-construction sparsity pattern (not a fill-in-minimizing permutation of an
already-sparse matrix; the pattern *is* the neighbour list). The
log-determinant is accumulated incrementally, one column at a time
(`logdet -= 2*log(d);`, `src/utils.h:166`), avoiding a separate determinant
pass. This path only activates when enough neighbour data is available
(`nncolMat.rows() >= p` gate at `src/gllvm.cpp:962`); otherwise a dense
fallback (`gllvmutils::rank1inv`, `src/gllvm.cpp:960`) is used. A **low-rank
truncation** is applied on top: each block's variational-covariance Cholesky
factor `SArmC` is only given rank `Abranks(cb)` (`src/gllvm.cpp:918-923`,
comment: `//use sparse matrices if we can to speed things up with many
species`), an explicit accuracy/speed trade-off exposed as data
(`Abranks`), not a fixed default.

Separately, the **determinant of a Kronecker-product covariance is computed
from each factor's own Cholesky diagonal**, never by forming or factorizing
the full Kronecker matrix: `src/gllvm.cpp:907-908` ("determinant of kronecker
product of two matrices based on their cholesky factors: first part") and
`:950-951` ("...second part"). This is a pure algebraic identity
(`log|A⊗B| = ncol(B)·log|A| + nrow(A)·log|B|`), not sparse-matrix machinery
per se, but it is in the same "avoid forming/factorizing the big matrix"
family.

**gllvmTMB**: no fill-reducing-permutation or custom-sparsity-pattern code
found (same-repo grep, delegated; see §5). The SPDE spatial case reuses
TMB's own `density::GMRF`, which has its own internal sparse-pattern handling
that this scout did not investigate (out of scope: that is TMB's own code,
shared by every TMB package including gllvm's Laplace path).

### 2.3 How is the inner problem solved? Newton vs quasi-Newton vs direct? Warm-started?

**galamm's PIRLS** is genuine **Newton's method with the exact sparse
Hessian** `H = Lambdat·Zt·V·Zt'·Lambdat'` (`src/misc.h:54-62`) — exact
because, for canonical-link GLMs, Fisher scoring and Newton's method
coincide. Each Newton step is followed by up to **10 step-halvings**
(hard-coded, not user-configurable: `for(int j{}; j < 10; j++)`,
`src/compute_galamm.cpp:127-153`) accepting the first halving that decreases
the deviance. The outer PIRLS loop itself defaults to
`maxit_conditional_modes = 10` (`R/galamm_control.R:78`) and an absolute
deviance-change tolerance `pirls_tol_abs = 0.01` (`:79`). For a single
all-Gaussian family, `maxit_conditional_modes` is force-set to **1**
(`R/galamm.R:458-461`), matching the documented fact that Gaussian PIRLS is
exact in one step (a direct solve, not an iteration).

**Not warm-started across outer iterations.** `u_init <- rep(0,
nrow(gobj$lmod$reTrms$Zt))` is computed once (`R/galamm.R:454`) and passed
unchanged as `u_init` to every call to `marginal_likelihood()`
(`:474`) for the life of the optimization — i.e. **every single outer L-BFGS-B
iteration's PIRLS solve restarts the conditional mode from `u = 0`**, never
from the previous outer iterate's converged value. This is a clean,
well-evidenced negative answer to the warm-start question, for galamm
specifically.

**gllvm**: `method` (`DATA_INTEGER`, `0=VA,1=LA,2=EVA`, `src/gllvm.cpp:95`)
selects between three estimation routes inside **one shared C++ template**.
VA/EVA call `TMB::MakeADFun` **without** `random=` (confirmed already in
`21-WHY-GLLVM-IS-FAST.md`; re-confirmed here by the `randomp`/`random=`
wiring in `R/gllvm.TMB.R:2126,2216` being conditional on which parameter
blocks are added to `randoml`/`randomp`) — so VA is a flat quasi-Newton
problem (`optim`/`nlminb` on the whole parameter+variational-parameter
vector), no inner Newton solve, no TMB-internal Laplace machinery at all. LA
passes `random = randomp` and lets TMB's own internal Laplace approximation
(its own inner Newton + sparse-Hessian handling) marginalize those blocks —
**this scout did not read TMB's own C++ implementation of that inner solve**
(out of scope; shared by gllvm-LA and gllvmTMB alike), so I cannot say
whether *TMB itself* warm-starts or reuses symbolic factorizations across
outer iterations. What I *can* confirm from gllvm's own R code is a
**Laplace-specific relaxation of TMB's inner-Newton controls**:
```r
objr <- TMB::MakeADFun(
  data = data.list, silent=!(trace&!is.null(randomp)),
  parameters = parameter.list, map = map.list,
  inner.control=list(mgcmax = 1e+200,tol10=0.01),
  random = randomp, DLL = "gllvm")
```
(`R/gllvm.TMB.R:2122-2126`, identically repeated at `:2212-2216` for the
quadratic-restart branch). `mgcmax` is TMB's ceiling on the maximum gradient
component before the inner solve is flagged as diverging; setting it to
`1e+200` effectively disables that check. The precise quantitative meaning of
`tol10` relative to TMB's own default I did not verify from TMB's source in
this pass (see §4) — I can only confirm the literal values gllvm passes and
that they loosen, not tighten, the default. **Neither of gllvm's 6
`MakeADFun` call sites (`R/gllvm.TMB.R:1365,1403,1617,1946,2122,2212`) passes
`profile=`** (grep for `profile\s*=` against the whole file: zero hits) —
gllvm does not profile any parameter block out of the outer optimization,
for either VA or LA.

**gllvmTMB's own current state** (same-repo check): `random=` is passed
(built incrementally, `R/fit-multi.R:4474` onward); `profile=` is **not**
passed anywhere; `inner.control=` is **not** passed anywhere (runs on TMB
defaults, unlike gllvm's explicit relaxation); default outer optimizer is
`nlminb` with `eval.max=2000, iter.max=1500`
(`R/fit-multi.R:4578-4581`). Warm-starting **does exist**, but only as an
explicit user opt-in across *separate* fits, not automatically within one
fit's outer-iteration sequence: `.gllvmTMB_apply_start_from()`
(`R/init-warmstart.R:367-408`) reads a previous fit's
`tmb_obj$env$last.par.best` and seeds the next `MakeADFun()` call's parameter
list. This is a stronger position than galamm's confirmed
never-warm-starts, though it addresses a different case (restarting a whole
new fit from an old one, not carrying state between `nlminb`'s own internal
iterations).

### 2.4 Automatic differentiation framework

**galamm** uses the **`autodiff` C++ library** (Leal 2018,
<https://autodiff.github.io/>) — **forward-mode** dual numbers,
`autodiff::dual1st` for gradient-only calls and `autodiff::dual2nd` for
gradient+Hessian (dispatch at `src/compute_galamm.cpp:446-464`). This is a
different AD paradigm from TMB/CppAD's reverse-mode tape. galamm's own team
**forked and extended `autodiff`** to support sparse Eigen matrix operations
(the upstream library natively supports only dense Eigen ops): "since
`autodiff` natively only supports dense matrix operations with `Eigen`, we
have extended this library so that it also supports sparse matrix
operations. This modified version of the `autodiff` library can be found at
`inst/include/autodiff/`" (`doc/optimization.Rmd:403`, the package's own
"Implementation Details" section). I verified directly from
`autodiff`'s own `gradient.hpp` (bundled copy,
`.../galamm/include/autodiff/forward/utils/gradient.hpp:97-104`) that the
forward-mode gradient of an n-parameter function is computed by **looping
over each parameter once and re-evaluating the whole function with that one
direction seeded** (`ForEachWrtVar(wrt, [&](i, xi){ u = eval(f, at,
wrt(xi)); g[i] = derivative<1>(u); })`) — i.e. **gradient cost is O(n_outer_params)
full re-evaluations of the entire PIRLS+sparse-solve pipeline**, each
constructing its own fresh `ldlt<T>` solver (§2.1). The Hessian
(`gradient.hpp:172-195`) is the doubly-nested version: O(n_outer_params²/2)
full re-evaluations (exploiting symmetry), but this is only invoked **once**,
at convergence, for standard errors (`R/galamm.R:517`) — not on every outer
optimizer iteration, where only the O(n) gradient is needed. galamm's own
vignette states this is a known, currently-unaddressed scaling concern in
its own words: **"the current implementation uses only forward mode
automatic differentiation. In the future, we aim to add backward mode as an
option, as this might turn out to be more efficient for problems with a
large number of variables"** (`doc/optimization.Rmd:411`, "Future
Improvements" section) — i.e. the package's own author identifies the same
structural gap this scout found from the source, independently.

**gllvm** and **gllvmTMB** both use **TMB/CppAD** (reverse-mode); confirmed
by `#include <TMB.hpp>` and `objective_function<Type>::operator()` in both
`src/gllvm.cpp:1,36` and `src/gllvmTMB.cpp:28`. No custom
`CppAD::atomic`/`REGISTER_ATOMIC` functions in either package's own code
(both rely only on TMB's stock atomics, `atomic::invpd`/`atomic::matinv`).
Reverse-mode gradient cost does not scale with the number of outer
parameters the way galamm's forward-mode does — this is a structural,
Big-O-level property of the two AD paradigms (reverse-mode: cost ≈ small
constant multiple of one forward pass, independent of input dimension for a
scalar output; forward-mode: cost scales with input dimension), not a claim
about which package fits faster or more accurately in practice, which I did
not measure.

### 2.5 Parameterization choices for conditioning

**galamm**: `theta` is lme4's own Cholesky-factor parameterization of the
random-effect covariance (unconstrained scale, lower-triangular entries),
inherited wholesale from `reformulas`/`gamm4()`'s `lme4`-equivalent setup —
box-constrained via L-BFGS-B's `lower` bound (`gobj$lmod$reTrms$lower`,
`R/galamm.R:445-449`), which is lme4's own standard bound (0 for diagonal
Cholesky entries, −∞ off-diagonal). No additional whitening/scaling beyond
what lme4 already does. Loading-diagonal pinning (fixing one factor loading
to 1) is a **user-supplied model-identifiability choice** via the `lambda`
argument's `NA`/1 encoding (e.g. `doc/optimization.Rmd`'s worked examples),
not an automatic optimizer-conditioning trick internal to galamm.

**gllvm** (already established in `21-WHY-GLLVM-IS-FAST.md`, not re-derived
here, cited for completeness of this question): identifiability is
hard-coded in the C++ template — upper triangle of the loading matrix set to
0, diagonal pinned to 1, scale carried separately via `sigmaLV`
(`gllvm.cpp:295-306` per that document); latent variables are whitened
(`N(0,I)` prior, scale reintroduced only after the KL term); the per-unit
variational covariance factor is parameterized via a **log-Cholesky
factor** (`src/gllvm.cpp:398-417` in this session's own read: `// log-Cholesky
parametrization for A_i:s`, `A(i)(d,d) = exp(Au(d*n+i))` for the diagonal,
free off-diagonal entries for `i` — confirmed directly, matching the prior
document's independent claim).

### 2.6 Anything else done explicitly for speed

- **galamm memoises its combined objective+gradient+Hessian call**:
  `mlmem <- memoise::memoise(mlwrapper)` (`R/galamm.R:492`), with both the
  `fn` and `gr` closures passed to `stats::optim()` calling the *same*
  memoised function keyed on `(par, gradient, hessian)`
  (`R/galamm.R:493-498`). The package's own vignette explains why: "To make
  use of the fact that both the marginal likelihood value itself and first
  derivatives are returned from the C++ function, we use memoisation"
  (`doc/optimization.Rmd:405`) — i.e. `optim()`'s separate calls to `fn(par)`
  then `gr(par)` at the same `par` (a common pattern in R's `optim()`
  L-BFGS-B implementation) hit the cache on the second call instead of
  re-running PIRLS. Whether this is a win for gllvmTMB depends on whether
  `nlminb` ever calls `obj$fn`/`obj$gr` at an identical parameter vector —
  I did not verify this against gllvmTMB's own measured profile, and the
  team's own profile attributes the dominant cost to `nlminb`'s own
  bookkeeping (58-77%), not to `TMB::sdreport`/repeated evaluation
  (22-39%), so the payoff of this specific technique for the *measured*
  bottleneck is uncertain, not confirmed.
- **galamm's own (self-qualified "limited") profiling** attributes most
  wall-clock to the C++ PIRLS/sparse-solve step, not R↔C++ data marshaling:
  "the optimization process still involves copying all model data between R
  and C++ for each new set of parameters. This is potentially an efficiency
  bottleneck with large datasets, although with the limited profiling that
  has been done so far, it seems like the vast majority of the computation
  time is spent actually solving the penalized iteratively reweighted least
  squares problem in C++" (`doc/optimization.Rmd:405`) — quoted as the
  author's own qualified claim, not independently re-profiled by this scout.
  The same vignette's "Future Improvements" section states an aim to move
  the *outer* optimization loop into C++ entirely, to remove the R↔C++
  marshaling per iteration (`doc/optimization.Rmd:407-409`).
  galamm's own **empirical scaling vignette** (`doc/scaling.Rmd`) reports
  near-linear wall-clock scaling in N (number of grouping units) for several
  Gaussian/GLMM/semiparametric models, and one near-flat case for a GLMM
  with factor structures across N=100..500 — the author's own speculation is
  that non-Gaussian PIRLS needs fewer iterations at larger N (less relative
  posterior uncertainty) while each iteration costs more, roughly canceling
  (`doc/scaling.Rmd:268`). This is real-world evidence that Eigen
  SimplicialLDLT+AMD stays close to linear for the grouped/multilevel
  structures galamm targets, though it is not a controlled decomposition of
  cost by phase the way the team's own profile is.
- **gllvm's default outer optimizer is `nlminb`** for all three methods
  (VA/LA/EVA), same optimizer family as gllvmTMB's own default — this is a
  point of similarity, not a technique difference, but useful context: both
  packages already made the same "PORT routine" choice at the outer level.

---

## 3. Technique comparison table

| # | Technique | galamm | gllvm | gllvmTMB (current) | Borrowable? | Est. effort |
|---|---|---|---|---|---|---|
| 1 | Sparse Cholesky backend for the main RE/LV system | Eigen `SimplicialLDLT`, default AMD ordering, header-only (no CHOLMOD) | none directly — delegates to TMB internals | none directly — delegates to TMB internals + `density::GMRF` for SPDE | N/A — gllvmTMB already on the same substrate as gllvm; no CHOLMOD-vs-Eigen gap to close | — |
| 2 | Symbolic-factorization reuse across *outer* iterations | **No** — fresh solver + `analyzePattern()` every `logLik()` call (confirmed local-variable pattern) | unknown, inside TMB internals (not verified this session) | unknown, inside TMB internals (not verified this session) | Not a positive example to copy from galamm; whether TMB's own engine already does this is a separate, worthwhile investigation | investigation-only |
| 3 | Domain-specific k-NN sparse inverse-Cholesky (Vecchia/NNGP) for large structured trait/species covariance | N/A (no such structure) | **Yes** — `gllvmutils::nngp`, exact k-nonzeros/column, incremental log-det, gated on neighbour-data availability | Not found (no permutation/AMD/METIS/fill-reduc code; dense or `density::GMRF` only) | Yes, for `phylo_latent`/`kernel_latent`/`spatial_latent` at large trait counts — different axis from the measured N-scaling bottleneck | Substantial: new sparse construction + R-side k-NN precompute + validation |
| 4 | Kronecker/separable log-determinant via per-factor Cholesky | N/A | **Yes**, explicit comment, avoids forming the full product | Not confirmed as used (has `atomic::matinv` for small dense inversions, not this specific identity) | Yes, general and cheap where a separable structure exists | Small–medium |
| 5 | Forward- vs reverse-mode AD | Forward-mode (`autodiff` dual numbers), O(n_outer_params) gradient cost; author flags this as a known limitation | Reverse-mode (TMB/CppAD) | Reverse-mode (TMB/CppAD) | No action — gllvmTMB already uses the more scalable paradigm | — (negative finding / reassurance) |
| 6 | R-level memoisation of `fn`+`gr` at identical parameter vector | **Yes**, `memoise::memoise()` around the combined C++ call | not found in the reverse-mode path (separate `objr$fn`/`objr$gr` closures) | not confirmed either way (not specifically grepped) | Maybe — cheap to prototype, but payoff unverified against the team's own profile (dominant cost is `nlminb` bookkeeping, not redundant evaluation) | Trivial to prototype; verify need first |
| 7 | `TMB::MakeADFun(inner.control=...)` relaxation for the Laplace inner solve | N/A (no TMB) | **Yes** — `mgcmax=1e+200, tol10=0.01` on every Laplace `MakeADFun` call | **Not passed** — runs on TMB defaults | Yes, directly — same call gllvmTMB already makes | Trivial to test; needs accuracy/coverage re-validation given relaxed tolerances |
| 8 | `profile=` argument to `MakeADFun` (profiling parameters out of the outer optimization) | N/A structurally (no TMB; `reduced_hessian` only restricts the *final* Hessian computation, not the optimization path) | **Not used** — confirmed absent from all 6 `MakeADFun` call sites | **Not used** | No precedent found in either reference package — this scout cannot supply state-of-the-art evidence either for or against `profile=` from galamm/gllvm | N/A |
| 9 | Warm-starting the random-effect/latent-variable solve | **No** — `u_init` hard-coded to a zero vector for every call, confirmed | Not independently verified beyond whatever TMB's own `last.par.best` machinery does inside one `objr` object's lifetime | **Yes, but opt-in only**, across *separate* fits (`control$start_from`, reuses `last.par.best`) | gllvmTMB already exceeds galamm's (confirmed absent) warm-starting; whether TMB itself warm-starts *within* one fit's outer-iteration sequence is a TMB-internals question, not answered here | — |
| 10 | Hand-derived closed-form reductions vs AD-everything | AD throughout (no hand derivatives) | AD throughout in the default (TMB) path; the **non-default**, uncompiled `gllvm.VA` R function hand-derives every gradient in closed form | AD throughout | The transferable idea is implementing available closed forms (e.g. the `A_i` identity) as *reductions inside the AD'd template*, not as hand-derivative code outside AD — already tracked in this lane's own `21-WHY-GLLVM-IS-FAST.md`, not new from this task | (tracked elsewhere) |

---

## 4. What I could NOT determine

- **TMB's own internal sparse-Cholesky / symbolic-factorization-reuse
  behavior** for the Laplace inner solve. This is shared machinery between
  gllvm's LA method and gllvmTMB itself — I did not read TMB's own R or C++
  source in this task (it is neither galamm nor gllvm, and was out of the
  original brief's scope), so I cannot say whether TMB reuses a symbolic
  factorization across outer `nlminb` iterations, or whether its inner
  Newton solve warm-starts the random-effect mode from the previous outer
  iterate. This is the single biggest gap for answering "does the state of
  the art warm-start the inner solve" for the *Laplace* case specifically,
  since both gllvm-LA and gllvmTMB delegate that exact question to TMB.
- **Precise semantics of TMB's `inner.control` parameters.** I can confirm
  the literal values gllvm passes (`mgcmax=1e+200, tol10=0.01`) and their
  approximate documented purpose (loosening divergence/convergence checks on
  the inner Newton solve), but I did not read TMB's `newton`-related source
  to confirm exact default values or the precise mathematical effect of
  `tol10=0.01` versus TMB's default.
- **Whether galamm's repeated `analyzePattern()` per outer call is a
  measurable cost in practice.** The author's own vignette says most time is
  in the PIRLS solve, which is consistent with (but does not isolate)
  `analyzePattern` being a non-trivial share of that. galamm does not
  publish a phase-level breakdown comparable to the team's own
  nlminb/sdreport/MakeADFun/R split.
- **Whether galamm's O(n_outer_params) forward-mode gradient cost is a
  practical bottleneck for realistic model sizes**, versus a cost dominated
  by something else. I verified the O(n) structural fact directly from
  `autodiff`'s `gradient.hpp`, and galamm's own vignette independently
  corroborates it as a concern ("future work: backward mode... more
  efficient for problems with a large number of variables"), but I did not
  find or run a benchmark isolating gradient cost as a function of
  `n_outer_params` specifically (the scaling vignette varies data size N,
  not parameter count).
- **gllvmTMB's own current-state findings in this report were gathered by a
  delegated sub-agent** (grep-based, with file:line citations reported back
  to me), not read first-hand by me in this session. The citations are
  concrete and checkable, but this is one level of indirection I want to
  flag rather than silently present as equivalent to my own direct reads of
  galamm/gllvm.
- **sdmTMB, glmmTMB, and gllvm's Laplace path as an independent deep-dive**
  were not investigated — out of the scope actually executed this session
  (see the note at the top and the chat handoff for why).
- I did not attempt any accuracy, coverage, or correctness comparison
  between any of these packages, per the task's constraints, and nothing
  above should be read as such.

---

## 5. Provenance

**galamm** — installed locally as CRAN version 0.4.0 (packaged
2025-12-21; `find.package("galamm")` →
`/Users/z3437171/Library/R/arm64/4.6/library/galamm`). GitHub source fetched
at commit `e9e27fcb661288eff07db4f4063e1298ff36edbd` (branch `main`, repo now
`ropensci/galamm`, formerly `LCBC-UiO/galamm` — API confirms a rename/
transfer; commit fetched via `raw.githubusercontent.com`, 2026-08-03/04):
- `src/compute_galamm.cpp` (467 lines, read in full)
- `src/model.h`, `src/parameters.h`, `src/update_funs.h`, `src/misc.h`,
  `src/data.h` (read in full)
- `src/Makevars`, `src/Makevars.win` (read in full)
- `R/galamm.R` (654 lines, read in full), `R/galamm_control.R` (read in full)
- Installed vignettes (not fetched from GitHub — read directly from the
  local package library, same 0.4.0 build): `doc/optimization.Rmd`,
  `doc/scaling.Rmd` (both read in full)
- `include/autodiff/forward/utils/gradient.hpp` — read in full from the
  locally installed package's bundled/modified `autodiff` fork
  (`/Users/z3437171/Library/R/arm64/4.6/library/galamm/include/autodiff/...`)
- `RcppEigen` 0.3.4.0.2 (locally installed) —
  `include/Eigen/src/SparseCholesky/SimplicialCholesky.h`, grepped to verify
  `SimplicialLDLT`'s default ordering template argument

**gllvm** — installed locally as CRAN version 2.0.13 (packaged 2026-07-08;
`find.package("gllvm")`). GitHub source fetched at commit
`02fdaf5b3c827497b9496af9c53c98e68f7a3256` (branch `master`, repo
`JenniNiku/gllvm`, 2026-08-01 — the latest pushed tag is `v2.0.10`, older
than the installed CRAN 2.0.13, so master HEAD was used and is disclosed
here rather than presented as an exact version match):
- `src/gllvm.cpp` (5,505 lines total; read: lines 1-115, 385-424, 905-980,
  2570-2604, plus targeted `grep -n` passes across the full file for
  `cholesky|sparse|density::|GMRF|SEPARABLE|newton::|CHOLMOD|MVNORM|AR1\(`,
  76 total matches reviewed)
- `src/utils.h` (369 lines; read lines 140-207, containing the `nngp`
  function in full)
- `R/gllvm.TMB.R` (3,329 lines; grepped for `MakeADFun`, `random=`,
  `nlminb\(|optim\(`, `silent=|profile=|inner\.control|newton`; read lines
  2100-2240 in full for the Laplace-path `MakeADFun` call and surrounding
  optimizer dispatch)
- Pre-existing lane documents, read as background and explicitly **not**
  re-derived: `/private/tmp/gllvmtmb-va-lane2/dev/va-speed/GLLVM-REFERENCE-READ.md`
  (gllvm's non-default, uncompiled `gllvm.VA` closed-form path) and
  `21-WHY-GLLVM-IS-FAST.md` (gllvm's default TMB-based VA path, the `A_i`
  closed-form finding, and the loadings/whitening/log-Cholesky
  parameterization claims cited in §2.5)

**gllvmTMB** (own current state, for the comparison table/column only) —
gathered by a delegated sub-agent doing a same-repo grep-based read of
`src/gllvmTMB.cpp`, `R/fit-multi.R`, `R/gllvmTMB.R`, `R/init-warmstart.R` in
this working tree (`/Users/z3437171/Dropbox/Github Local/gllvmTMB`, branch
`claude/profile-coverage-remeasure-20260718`); file:line citations as
reported are included inline above. Not independently re-verified by direct
reading in this session — see §4.

No file was modified. No package/public claim is made anywhere in this
document; everything is either a direct source citation or explicitly marked
as the cited author's own claim, an inference, or unverified.
