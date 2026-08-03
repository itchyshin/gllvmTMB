# Why gllvm is fast — and the 57% it leaves on the table

Source: `gllvm 2.0.13`, deparsed R plus **verbatim `src/gllvm.cpp` (5,505 lines)** obtained
by `download.file()`. GPL-2; expressions below are quoted for comparison only, nothing
copied into this repo.

## 🔴 FIRST: a premise correction that invalidates my earlier story

Everything I wrote this session about *"gllvm computes `A_1`, breaks the loop, and copies it
to all n units — that's why it's fast"* was **about a dead code path.**

Those lines live in **`gllvm:::gllvm.VA`** — the legacy, pure-R, non-TMB engine, reachable
only with `TMB = FALSE`. It is **not** the default and **not** what produced the 0.74 s.
The default `gllvm(method = "VA")` routes `gllvm()` → `gllvm.iter()` → `gllvm.TMB()`, which
is a completely different algorithm.

The closed-form-`A` story is real. It is simply not the reason gllvm is fast.

## What the real VA engine actually does: a single generic quasi-Newton

`MakeADFun` is called **without `random =`** for VA (unlike the Laplace path, which passes
it). So there is **no CAVI, no coordinate ascent, no inner Newton, no marginalisation** —
model parameters and variational parameters sit in one flat vector handed to
`optim(method = "BFGS", reltol = 1e-10, maxit = 6000)`.

Measured (n=100, p=20, q=2, binomial-probit), the *entire* algorithm is three optimiser calls:

```
nlminb  npar= 20   f=27   g=15    (num.lv=0 start fit)
optim   npar=459   f=272  g=106   (stage 1, A diagonal)
optim   npar=559   f=152  g=51    (stage 2, A unstructured, warm-started)
```

0.23 s total; 76% inside `optim`, 8 ms per tape. At n=200 it solves a **1,059-parameter**
problem in **161 gradient evaluations** — and gradient count grows *sub-linearly* in
parameter count (90 → 215 while npar goes 309 → 2,059).

**That is the mechanism: the objective is conditioned so that plain BFGS converges in far
fewer iterations than the problem has dimensions.** Three parameterisation choices do it:

| # | choice | why it matters |
|---|---|---|
| 1 | **Identifiability hard-coded in C++** (`gllvm.cpp:295-306`): upper triangle of Λ set to 0, **diagonal pinned to 1**, scale carried by a separate `sigmaLV` | The rotational and scale flat directions **do not exist in the parameterisation**. No constrained optimisation, no wandering along a ridge. |
| 2 | **Whitened / non-centred latents**: prior exactly `N(0, I)`, so the KL is `log|diag(L_i)| − ½(tr(L_iL_iᵀ) + u_iu_iᵀ)` — no inverse, no prior log-determinant. Scale applied **after** the KL via `u *= Δ`, `A(i) = Δ·A(i)` | Removes the σ–u coupling that otherwise wrecks conditioning. |
| 3 | **`A_i` as a log-Cholesky factor**: `exp(Au(...))` on the diagonal, free off-diagonals | Positive-definiteness is free; `log|A|` is a sum of logs, not a decomposition on the tape. |

Plus closed-form analytic bounds with zero quadrature, so one gradient costs only **1.8×** one
function value (186 µs `fn` vs 334 µs `gr` at npar = 559).

## 🎯 The 57% gllvm leaves on the table — this is how we beat them

**gllvm's TMB path does not exploit the closed form its own objective possesses.** In the
probit branch (`gllvm.cpp:3287-3300`), `A_i` enters **only** through the entropy term and
through `cQ(i,j)*Ntrials(i,j)`; the data-dependent part depends on `eta` alone. Stationarity
therefore gives

> `A_i A_iᵀ = (I_q + Σ_j N_ij λ_j λ_jᵀ)⁻¹` — **one q×q matrix, identical for every unit.**

Verified on a real gllvm fit: the fitted `f$A[i,,]` matches `solve(diag(q) + t(Λ) %*% Λ)` to
**1.9e-9**, and varies across 100 units by **1.3e-11**.

**gllvm spends 300 of its 559 outer parameters — 600 of 1,059 at n=200, i.e. 57% — numerically
rediscovering a q×q matrix it could have written down.**

This is independently the same structure our own derivation proved (`∂E/∂v ≡ −n/2`) and that
we then confirmed in **our** engine: per-unit `log_L_diag` identical to machine precision
(sd ≤ 1e-16), matching the predicted form to 2.6e-14, and converging back together from
jittered starts.

So the opportunity is real and it is **ours to implement first** (see "Prior art on the
closed form" below): profiling that block out removes ~57% of the outer problem *and*
removes the entire two-stage diag→unstructured restart machinery, which exists only to
make those parameters tractable.

### Prior art on the closed form

The `A_i` closed form is not new. Ranga's distilled deep-research note
(`dr25-gllvm-variational-implementation-distilled`, `shinichi-brain/projects/deep-research/`,
distilled 2026-08-03 from NotebookLM notebook `f329caa6` source 1) records that the published
VA coordinate-ascent cycle for GLLVMs already gives this as step (iv): "the latent covariance
has a direct closed-form update, `A_i = (I_d + Σ_j λ_jλ_jᵀ)⁻¹` — no GLM fit needed at all." Our
derivation reproduces that exactly and adds the binomial `N_ij` (n_trials) weighting:
`A_i A_iᵀ = (I_q + Σ_j N_ij λ_jλ_jᵀ)⁻¹`. What is ours is the generalisation, the implementation
inside a live TMB engine, and the 57% measurement above — not the closed form itself. The
distinction matters: "first to derive it" would not survive a reviewer holding the Hui/Niku VA
papers open; "first to implement it" — in place of the numerical rediscovery gllvm's own TMB
engine performs — is checkable.

## What this changes for us

1. **The `A_i` collapse is not novel derivation — it is unimplemented engineering.** The
   closed form itself is already published (see "Prior art on the closed form" above);
   what gllvm's TMB engine has not done is implement it.
2. **Check our conditioning against (1)–(3).** Our loadings diagonal is **unconstrained**
   (established by PR #919), where gllvm pins it to 1 with a separate scale. That is exactly
   the flat direction (1) removes. Whether our LVs are whitened in gllvm's sense, and whether
   our variational factor is log-Cholesky, both need checking — these are conditioning
   choices, not accuracy choices, and they cost nothing in identifiability.
3. **Do not port their two-stage restart.** It is scaffolding for a problem the collapse deletes.

## Provenance and honesty

gllvm is GPL-2 and separately licensed. Nothing was copied; the algorithmic facts above are
recorded so our own implementation can be *designed*, not transcribed. The measurements
(optimiser call counts, timings, the 1.9e-9 agreement) are ours, taken on this machine.
