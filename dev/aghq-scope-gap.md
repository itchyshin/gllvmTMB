# AGHQ-Laplace scope gap: what O3 built vs. what an optimisable estimator needs

**Lens: Curie — what exists vs. what is missing.**
**Status: research note, dev/ only. Not a design doc, not a claim about
package direction.**

## 1. Exactly what the O3 spike computes, and how

`tests/testthat/helper-aghq-o3.R` (canonical home; `dev/aghq-o3-*.R` are thin
local runners) does the following, for q = 1 (`.o3_hook_*`) and q = 2
(`.o3_q2_*`, `.o3_r2_*`):

1. Fit the production model ONCE with the ordinary `latent(..., unique =
   FALSE)` route (`gllvmTMB()` → `TMB::MakeADFun(..., random = "z_B")` →
   `nlminb`), to convergence.
2. Extract, at the converged optimum only: `b_fix` and `Lambda_B` from
   `fit$tmb_obj$env$last.par.best` / `fit$report$Lambda_B`, plus `y`,
   `n_trials`, `X_fix` from `fit$tmb_obj$env$data`.
3. For each unit `i` independently, **hand-write** the conditional log-density
   `ld(u) = sum_t dbinom(y_it, n_it, plogis(eta_it), log=TRUE) + dnorm(u,
   0, 1, log=TRUE)` in plain R (`.o3_hook_mode`, `.o3_q2_mode`), find its mode
   by `optimize()`/`optim(method="BFGS")`, and get its curvature from a
   **hand-derived closed-form formula** — `sum(loading^2 * n_trials * p *
   (1-p)) + 1` for q = 1, `crossprod(loading * sqrt(n_trials*p*(1-p))) +
   diag(q)` for q = 2 — not from TMB's automatic differentiation.
4. Place `nodes^q` Gauss–Hermite nodes around that mode via the adaptive
   transform `u = mode + sqrt(2)·R^{-1}x_h` (`R` from a Cholesky of the
   hand-derived curvature), evaluate `ld()` at each shifted node (again by
   direct R evaluation, not by re-querying the TMB tape), and combine by
   log-sum-exp.
5. Sum the per-unit log-integrals and compare to `fit$opt$objective` (the
   TMB Laplace marginal NLL). Agreement is `1.4e-9` (q=1) / `9.8e-8` (q=2) at
   one node — the empirical restatement of "Laplace = AGHQ with one node."

**Every part of steps 3–4 is a from-scratch R reimplementation of the
binomial-logit density**, run once, at fixed, already-optimal `(b_fix,
Lambda_B)`. It touches TMB only to *read out* the converged coordinates; it
never calls back into TMB's AD graph to obtain a mode, gradient, or Hessian.
`R/eva-proto.R:520 .eva_aghq_marginal_q1()` is the same pattern in miniature
(`q=1, N=1` only) inside the EVA prototype file, independently confirming
this is the established, minimal, hand-coded approach — not an oversight.

## 2. The delta: fixed-coordinate reference → optimisable AGHQ objective

Enumerated missing pieces, in the order they would need to be built:

1. **Re-solving the inner problem at every outer iterate, not once.** O3
   computes the per-unit mode/Hessian a single time, after the outer fit has
   already converged by ordinary Laplace. An estimator needs the per-unit
   mode as a function of the *trial* `(b_fix, Lambda_B)` at every evaluation
   the outer optimiser makes. This is the correct nested (nested-Newton)
   structure — but nothing in the repo runs it: no code re-solves the O3
   per-unit mode inside an outer `nlminb`/`optim` loop.

2. **Differentiability through the inner mode (the actual crux).** An
   outer gradient-based optimiser needs `d(AGHQ objective)/d(b_fix,
   Lambda_B)`, which requires differentiating *through* the per-unit argmin
   (the implicit-function-theorem term TMB's C++ Laplace machinery supplies
   natively for the one-node case). The O3 R-level mode/Hessian functions are
   **plain numeric R** (`dbinom`, `plogis`, `optimize`) with **no AD tape** —
   there is no gradient available at all, let alone one that accounts for how
   the mode moves as `(b_fix, Lambda_B)` moves. This is not a detail; it is
   the one piece genuinely new work is needed for, and it is exactly the part
   TMB's built-in Laplace gets "for free" and AGHQ-with-K>1-nodes does not.

3. **Family generality.** The per-unit density in O3 is hand-written for
   binomial-logit only. `src/gllvmTMB.cpp` (2620 lines) dispatches many
   families per row inside the compiled template. An R-level AGHQ layer
   claiming Laplace-route generality would need to reimplement every
   family's log-density (and its score/curvature) a second time in R, in
   parallel with the C++ template — a duplication the project already avoids
   elsewhere by construction.

4. **Scale of the inner loop.** O3's per-unit solve is a plain R
   `for`/`lapply`/`vapply` loop, one `optimize()`/`optim()` call per unit per
   outer evaluation. At Ayumi's scale (n=5397 units, q=2 → 27,000
   coordinates, T=20 traits), running this loop from R inside every outer
   iteration reproduces the "R-level per-unit parameterisation" cost this
   proposal is meant to avoid — this has not been measured, but the
   architecture is the same shape VA already pays for, applied per outer
   evaluation instead of once.

5. **The q ≥ 3 wall is untouched and irrelevant to q = 2 use, but real.**
   Ayumi's model is q=2, inside the O3 stop point (Design 85 closed NO-GO for
   the sibling VA route at q ≥ 4; O3 itself never attempted q ≥ 3). Any
   future q ≥ 3 use case is closed by tensor-grid growth (`n_q^q` per unit),
   independent of everything else in this note.

6. **No SE/uncertainty machinery** analogous to `sdreport()` exists for an
   AGHQ fit; not attempted anywhere in the repo.

## 3. R-level outer layer, or a new TMB template? — measured evidence

I inspected a live fitted TMB object from the O3 `q=1` fixture
(`gllvmTMB::gllvmTMB(cbind(succ,fail) ~ 0+trait + latent(0+trait|unit, d=1,
unique=FALSE), family=binomial())`) directly, not from memory.

**What works as hoped:**

- `obj$env$random` gives the integer indices of the random block in the
  joint parameter vector (16 = 16 units × d_B=1 here).
- `obj$env$f(theta, order=0)` evaluates the **joint** (unmarginalised)
  negative log-density at an **arbitrary** `theta`, including a `theta` whose
  random-effect coordinates have been shifted away from the mode (verified:
  shifting `z_B[1]` by 0.37 changes the joint NLL from 196.4094 to 196.6275,
  a finite, sane delta). This is exactly the "evaluate the joint density at a
  shifted latent value" primitive question 5 asks about, and it is **generic
  across every family already coded in the C++ template** — it is not
  specific to binomial-logit the way O3's hand-coded density is.
- `obj$env$spHess(theta, random = TRUE)` returns the sparse random-effect
  Hessian block at any `theta`, and it is confirmed **exactly block-diagonal**
  here (16×16, zero off-diagonal, matching the model's independent per-unit
  `z_B ~ N(0,I)` prior) — i.e. TMB already gives you, generically, the
  per-unit curvature blocks O3 hand-derived from a closed-form binomial
  formula. This generalises O3's mechanism to any family for free.

**What does NOT work, measured directly (this is the load-bearing finding):**

`obj$env$spHess(theta, random = FALSE)` is documented informally (and I
initially assumed) to return the *full joint* Hessian — the natural source
for the fixed-effect/random-effect cross-block `H_{fu}` an implicit-function-
theorem gradient chain (`d(mode)/d(b_fix) = -H_uu^{-1} H_{uf}`) would need.
I tested this directly and it is **wrong for this purpose**:

```
finite-difference d^2f / d(b_fix[1]) d(z_B[1]) via obj$env$f gradient: 3.369334
spHess(theta, random=FALSE) value at the same [b_fix[1], z_B[1]] entry: 0
```

Reading `TMB:::sparseHessianFun`'s source confirms why: the sparse Hessian's
nonzero *structural* pattern is fixed once, at construction, from
`MakeADHessObject(...)`'s own sparsity detection — and in this fixture that
detected pattern contains **only 16 entries total** (exactly the random-block
diagonal), regardless of `skipFixedEffects`. `spHess(theta, random=FALSE)`
silently returns **exact zero** at every fixed-effect and cross-block
position, including ones a direct finite difference on `obj$env$f(...,
order=1)` shows are genuinely nonzero (3.37, not small-and-truncated). This
was reproduced at both the fitted optimum and at a perturbed
`(b_fix, theta_rr_B)` point with `z_B` deliberately left off its
conditional mode.

**Implication.** The tempting "days" shortcut — reuse `spHess(random=FALSE)`
as the joint precision, apply the implicit-function-theorem formula in R —
is not simply available; it silently returns wrong (zero) cross-derivatives
in this object. A correct R-level gradient chain would have to fall back to
finite differences on `obj$env$f(theta, order=1)` for the cross-block (or
find a different TMB primitive not yet located), which is slower, adds a
second numerical-error source per outer-optimiser step, and has not been
validated at Ayumi's scale (n=5397, q=2).

## 4. TMB primitives, confirmed live (not from memory)

| Need | Primitive | Confirmed |
|---|---|---|
| indices of the random block | `obj$env$random` | yes — 16 integer indices |
| joint density at arbitrary (incl. shifted) theta | `obj$env$f(theta, order=0)` | yes — verified numerically on a shifted `z_B` |
| joint-density gradient at arbitrary theta | `obj$env$f(theta, order=1)` | yes — matrix of length 20, nonzero for `b_fix` at the joint optimum (correctly reflecting that the *marginal*, not joint, gradient is zero there) |
| per-unit (random-block) Hessian at any theta, generic across families | `obj$env$spHess(theta, random=TRUE)` | yes — exact block-diagonal 16×16, matches O3's hand-derived per-unit curvature in structure |
| **full joint Hessian (fixed × random cross-block)** | `obj$env$spHess(theta, random=FALSE)` | **NO** — structurally zero at cross-block positions that are genuinely nonzero (measured against finite difference) |
| converged joint coordinates | `obj$env$last.par.best` | yes |

## 5. Existing re-evaluation-at-perturbed-latent-values code

Two hand-coded R re-implementations exist and already do this, both outside
TMB's own AD tape:

- `tests/testthat/helper-aghq-o3.R` (`.o3_hook_log_integral`,
  `.o3_q2_log_integral`, `.o3_r2_log_integral`) — the O3 reference, q=1/q=2,
  binomial-logit only, fixed coordinates only.
- `R/eva-proto.R:520 .eva_aghq_marginal_q1()` — the same pattern, q=1, N=1
  diagnostic only, inside the EVA prototype.

Neither calls `obj$env$f()` on a shifted `theta` — both reconstruct the
density from scratch in R. The `obj$env$f(theta, order=0)` hook demonstrated
in §3 above is a *more general* re-evaluation mechanism than either existing
hook, because it works for any family the C++ template already supports, but
nothing in the repo currently uses it this way.

## 6. Build-shape and honest days-vs-weeks estimate

**Two real options, not one:**

**(a) R-level outer layer, restricted to the current object's per-unit
block-diagonal structure.** Feasible only because §3 confirms
`obj$env$f(theta, order=0)` and `obj$env$spHess(theta, random=TRUE)` are
generic, live, correct primitives. But because §3 also shows the
fixed×random cross-block is NOT available via `spHess`, a correct gradient
requires either (i) finite-differencing the cross-block via repeated
`obj$env$f(..., order=1)` calls (one extra AD gradient evaluation per unit
per outer step — expensive and unvalidated at n=5397), or (ii) restricting
the "outer" objective to be evaluated by `optim`/`nlminb` with a
**numerical, not analytic**, gradient over `(b_fix, Lambda_B)`, at which
point the R-level per-unit inner-mode loop (§2 point 4) becomes the dominant
cost and this degenerates toward VA's cost profile rather than avoiding it.
Even the *narrow* version of this — q=1 or q=2 only, binomial-logit only,
matching exactly what O3 already validated — is genuinely **on the order of
1–2 weeks**, not days: it needs a differentiable (or reliably numerically
differentiated) nested-optimisation loop wired to gllvmTMB's parameter
packing, tested for correctness against the existing Laplace fit at the
one-node limit, and load-tested at realistic scale before any claim about
speed relative to VA is possible. "Days" is not supported by what was
measured here.

**(b) A new TMB C++ template implementing AGHQ nodes natively.** This
reuses TMB's own correct, generic, AD-based inner-Newton machinery (the same
code that already gives the one-node Laplace case its free implicit-function-
theorem gradient) and extends it to K nodes inside the compiled objective, so
the outer optimiser gets a genuinely correct analytic gradient without any
R-level finite-difference patchwork. This is **weeks**, consistent with the
task's own framing, and is the only route that does not inherit the
cross-block gap found in §3.

**Evidence for (b) over a fast (a):** the concrete blocker is not
speculative architecture — it is the measured `spHess(random=FALSE)`
zero-cross-block result in §3, which removes the one shortcut that would
have made (a) genuinely days-scale. Absent that shortcut, (a) and (b)
converge toward comparable effort, and (b) is more likely to produce a
correct, general (multi-family) result rather than a q≤2,
binomial-logit-only patch that would need to be redone per family anyway.

## 7. What this note does NOT establish

No timing, no recovery, no coverage claim. It is confined to answering "what
exists vs. what is missing" for turning the O3 fixed-coordinate reference
into an optimisable AGHQ-Laplace estimator, using live TMB introspection
where the question turned on a TMB implementation detail rather than
documented behaviour.
