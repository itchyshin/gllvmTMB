# `log Phi` reconciliation — Stage 5 precondition, DISCHARGED (2026-08-02)

**Verdict: (a) NO CHANGE.** `gll_log_pnorm()` (`src/gllvmTMB.cpp:71`) stays exactly as shipped.

Stage 4's after-task recorded an owed item: two `log Phi` implementations now coexist — the shipped
asymptotic (A&S 26.2.12, switch at −20, self-reported "accurate to 9e-11") and Stage 4's continued
fraction (switch at −10, 0 ULP). *"Stage 5 will want them to agree."* This settles it by
measurement so Stage 5 can cite the grid instead of re-deriving it.

Reference: **mpmath at 60 dp** (`Rmpfr` not installed). Both algorithms transcribed to R so the
`direct` branch calls the same Rmath `pnorm()` TMB resolves to for `Type = double`.
Scripts: `01-primitives.R`, `02-grid.R`, `03-reference.py`, `04-refine.R`, `05-refine.py`,
`06-aghq.R` in this directory.

## 1. Pointwise error — max absolute in `log Phi`

| region | shipped | @x | VA R3 (CF) | @x |
|---|---|---|---|---|
| bulk `[-8, 5]` | 7.43e-14 | −7.26 | 7.43e-14 | −7.26 |
| VA switch nbhd `[-12,-8]` | 6.03e-14 | −8.78 | 6.49e-14 | −11.62 |
| between switches `[-20,-10]` | 5.33e-13 | −16.96 | 5.31e-13 | −16.41 |
| **shipped switch nbhd `[-22,-18]`** | **9.00e-11** | **−20.00** | 5.37e-13 | −19.48 |
| Stage-5 AGHQ band `[-60,-20]` | 8.82e-11 | −20.05 | 5.09e-12 | −57.35 |
| deep tail `[-300,-60]` | 6.01e-11 | −260.1 | 5.93e-11 | −272.1 |

**The asymptotic series does not lose everywhere.** For `x >= -10` the two are **byte-identical**
(same `log(pnorm)` code). For `-20 <= x < -10` they are still identical — the shipped engine has
not switched yet. **`-30 < x < -20` is the ONLY band where shipped is worse**; the neglected A&S
term is `945/x^10` (9.0e-11 at −20, 1.6e-12 at −30, 9e-14 at −40). Below −40 they are **tied** on
the double round-off floor of a value of magnitude `x²/2`.

Truncation alone, at 60 dp (mathematics separated from floating point):

| | value | derivative (inverse Mills) |
|---|---|---|
| shipped @ x=−20 | 9.005e-11 | 4.48e-11 abs / 2.24e-12 rel of λ=20.0498 |
| VA R3 @ x=−10 | 1.07e-24 | 1.08e-23 abs / 1.07e-24 rel of λ=10.0981 |

The shipped comment's "9e-11 at the −20 switch" **reproduces to three digits**. It is honest, and
it is the *whole* gap — the CF is essentially exact, so 9e-11 is shipped-vs-truth, not shipped-vs-VA.

## 2. The deciding number — error of the DIFFERENCE

Ordinal cell probability, sweep `a ∈ [-45,10]` step 0.005, max absolute error in `log P(cell)`:

| gap | shipped | VA R3 |
|---|---|---|
| 0.05 | 9.14e-11 | 4.99e-12 |
| 0.50 | 8.96e-11 | 4.79e-12 |
| 1.50 | 9.02e-11 | 5.02e-12 |
| 3.00 | 9.02e-11 | 5.02e-12 |

**The shipped column is FLAT in the gap** — at realistic spacings the per-term 9e-11 passes through
the difference with **no amplification**. (The VA column is not algorithmic error; it is the
round-off floor of representing `log Phi(-45) ≈ -1024`.)

Cancellation bites only at spacings no ordinal fit produces (amplification ≈ `1/gap`, hurting
**both**): gap 1e-2 → 4.0e-10 / 3.5e-12; 1e-4 → 4.5e-8 / 4.0e-11; 1e-8 → 4.5e-4 / 5.1e-7.

**End-to-end through AGHQ**, 192 configs (H ∈ {15,31,61}, s_cond ∈ {0.5,1,2,3}, mu ∈ {0,−3,−8,−14},
gap ∈ {0.1,0.5,1,1.5}):

```
max | AGHQ log-marginal(shipped) − AGHQ log-marginal(VA) | = 1.42e-14
```

Four orders below even the per-node bound — nodes reaching `a ≈ -20` carry weight `exp(-204)` and
are annihilated in the log-sum-exp.

**Why (b) was rejected:** a double holding a log-likelihood of magnitude 1e5 has representation
granularity 1.5e-11, so the worst-case per-term error is the same order as the unavoidable
round-off of *accumulating* the likelihood — and it is attained only for an observation whose cell
probability is ~1e-89. Replacing `gll_log_pnorm` with the CF would shift every existing
probit/ordinal user's objective for zero measurable benefit: **a behaviour change, not a bugfix.**

## 3. 🔴 THE ACTIONABLE PART FOR STAGE 5 — the scheme matters ~1000x more than the primitive

**`inst/tmb/gllvmTMB_va_r3.cpp` has NO differencing machinery.** grep count for `log1mexp`,
`logspace_sub`, `*_pnorm_diff`: **0**.

A naive `logspace_sub(logPhi(b), logPhi(a))` measures **1e2–1e4x worse** than the shipped
`gll_log_pnorm_diff` at small gaps. At gap 1e-8 the naive form gives the *identical* error
(2.067e-05) for **both** primitives — proving the primitive is not the bottleneck there.

**Stage 5 must port the shipped STRUCTURE**, substituting `va_r3_log_pnorm` inside:
- `gll_log1mexp` — `src/gllvmTMB.cpp:50` (cubic series below `u < 1e-6`);
- `gll_log_pnorm_diff` — `src/gllvmTMB.cpp:106`, which branches on `sign(a+b)` so the **smaller**
  probability is always the leading term and `log1mexp` always receives a non-positive argument.

**Correction to the Stage 5 brief and to Design 108's row-5 wording:** Design 108 §3 row 5 describes
Stage 5 as *"`logspace_sub` of two `log Phi`s"*. The shipped engine does **not** use a bare
`logspace_sub` — it uses the dedicated `gll_log_pnorm_diff` above, and that is the correct shape.
The row's wording understates what Stage 5 must port.

**Cross-engine agreement tolerances** for any Stage 5 test comparing VA against the shipped Laplace:
**≥1e-9 absolute per term** on the deep tail, **1e-12** on the AGHQ marginal. The two engines may
legitimately disagree by up to ~1e-10 per term on a deep-tail evaluation; the cause is documented
above and is not a defect in either.

Stage 4's clamp rule applies unchanged if Stage 5 ports this: clamp the **input** of each branch,
never the output, and any finiteness probe **must call `obj$he()`, not just `obj$gr()`** — the clamp
protects the Hessian, not the gradient (measured at x=−50: `gr` finite and correct, `he` NaN).

## Limits of this analysis

- **No `Rmpfr`** — mpmath's `ncdf` at 60 dp, cross-checked against `pnorm(log.p=TRUE)` in the bulk
  (~1e-16 relative).
- **Transcription, not compiled TMB.** Operation-for-operation identical with the same Rmath
  `pnorm` on the direct branches, but compiler reassociation or FMA contraction could move the last
  ULP. Cannot change the conclusion — the margin is four orders.
- **"Realistic cutpoint spacing"** is inferred from the `exp(log_increment)` parameterisation and
  the K ≤ 9 ordinal cases in the test suite, not from a survey of fitted models. Spacings below
  ~0.01 would need re-checking; such a model is unidentified in practice.
- The gap = 1e-8 row is **deliberately retained** even though it fails for both implementations. It
  is the honest statement of where the *scheme* — not the primitive — breaks, and it is what
  produced finding (3).
