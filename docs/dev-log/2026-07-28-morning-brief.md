# Morning brief — 2026-07-28, 5 a.m.

One page. What happened overnight, what to check first, and what to start.

---

## 1. FIRST THING: check two CI runs (2 minutes)

```bash
gh pr checks 798        # should now PASS — a fix was pushed at fa937cc1
gh pr view 799          # should read MERGED
```

* **#799 is MERGED** (`dc10fa6a` on `main`) — you signed off last night.
* **#798** was red all evening; the cause was found and fixed. **If it is now
  green, it is ready for your review.** It is a big PR (14 commits) and it
  contains **no API change and no export**, so it is not in the
  discussion-checkpoint set — but read the summary in §3 before merging.

---

## 2. What landed on `main` (#799)

**A real detection bug, fixed.** A collapsed variance component could pass every
check the package had: `check_gllvmTMB()` printed `near_zero_psi_unit … PASS …
0.0006826` for a component whose *variance* was `4.7e-7` against siblings near
1.0. Two independent blind spots — the threshold is `1e-4` on the **sd** scale
(so it demanded variance < `1e-8`), and `pdHess` is structurally blind because
`psi` is estimated on the log scale. Detection is now relative to siblings.

**`start_method = "res"` soft-deprecated** on 89 fit-pairs: never materially
better, materially worse 8 times, exactly neutral at `d >= 2`.

**Two negative results, both mine, both recorded so nobody rebuilds them:**

1. The relative-collapse fix does **not** explain the campaign's 59/70 silent
   degenerate fits — **0 of 22** re-fitted cells flagged. Structural: that grid
   fits `latent(..., unique = FALSE)` ("Psi SUPPRESSED") and every degenerate
   cell is bernoulli, so there is **no psi and no residual sd** for a relative
   variance test to act on. §6a of the after-task is corrected in place.
2. The `Lambda_B` **spectrum** does not separate degenerate from healthy fits
   either. Real signal — a 120× median shift — but overlapping ranges, so the
   best threshold runs a **37.5% false-positive rate**. Not usable as a gate.

---

## 3. What is in #798 (the VA lane), if you merge it

Three deliverables, all with evidence:

| | |
|---|---|
| **Per-family registry** | 4 of 16 families. Proven by porting **nbinom2** *through* it — one entry plus one likelihood branch reusing the existing Gauss-Hermite helper via a shifted call. ~20 edits. |
| **Calibrated VA standard errors** | `se_profile` covers **0.935–0.950** vs nominal 0.95; the naive `se_conditional` under-covers everywhere (0.885–0.910). Block-diagonal Schur replaced a **5.45 GB** dense Hessian — now **9.1 s / 220 MB** at n=5397, verified against dense to **1.5e-10**. |
| **Ayumi-scale second opinion** | n=5397: Laplace `rel_frob` 0.167 / atten 0.875 · VA-GH **0.103 / 0.949**. VA-GH is the most accurate arm we have. |

Also: `optimizer = "auto"` now routes per family **and per tier** on measured
evidence (binomial-jj → `lbfgsb` 2.54×; binomial-**gh** → `nlminb`, because
`lbfgsb` is 1.7× *slower* there).

`FAIL 0 | PASS 7710` · NAMESPACE diff 0 · nothing exported · Laplace remains the
only estimation route.

---

## 4. THE DECISION YOU MADE LAST NIGHT

**Invest in Laplace + AGHQ. Freeze VA where it is.**

The deciding argument was **coverage, not accuracy**: AGHQ is a refinement layer
on the Laplace objective, so it inherits all 16 families, phylogeny, spatial and
missing data. VA reaches 4 of 16, rejects phylogeny and missingness, and covers
**2 of Ayumi's 27 responses**. VA-GH recovers `Sigma_B` best and *still* cannot
express her model.

Measured support for AGHQ:

| | Laplace | AGHQ | cost |
|---|---|---|---|
| q=1, n=2000 | 0.8968 | **0.9507** | 1.67× |
| q=2, n=2000 (5/5 seeds) | 0.9215 | **1.0438** | 3.40× |

`c_full` = **1.064** at q=2 against a predicted 1.02–1.04 band, and the kill rule
(`< 1.01`) written *before* the run was cleared. **The q=1 result transfers to
q=2 — the blocker on AGHQ is closed.**

---

## 5. WHAT TO START (in this order)

### A. Settle the identifiability question — half a day, and it could redirect everything

Three hypotheses about the 59/70 have now died. The surviving explanation is
that those fits are **well-converged optima of models the data does not
identify**. If so, `convergence == 0` and `pdHess = TRUE` are *true statements*,
no fit-side diagnostic can ever flag them, and the deliverable is an
**identifiability warning plus documentation** — not a better estimator.

The test is specified and cheap: for the 16 degenerate cells already re-fitted
(`dev/lambda-spectrum-vs-degeneracy.csv` on `main`), check multi-start agreement
and profile curvature along the trailing eigenvector. Genuine optima of a flat
likelihood ⇒ identifiability, not convergence.

**Do this first because it is cheap and it changes what "better" means.**

### B. Build AGHQ-Laplace as an opt-in refinement, q ≤ 3 — days, not weeks

The O3 spike already reproduces our joint TMB Laplace objective to **1.4e-9** at
one node, so this is an outer layer over machinery that exists, not a new TMB
template. Node ladder converges by **k=5–9**, not 25.

Fence it at low q: `H^q` is 81 nodes at q=2 and **2,401 at q=4**.

Two things to resolve while building:
* AGHQ **overshoots** at q=2 (attenuation 1.044 vs Laplace's 0.92 undershoot).
  The acceptance criterion must be `|attenuation − 1|`, **not** "higher is
  better", and the sign flip from q=1's 0.951 is unexplained at 5 seeds.
* The cost model needs updating from the q=1 figure: **3.40× at q=2**, not 1.67×.

### C. Do NOT do these

* `profile=` and the closed-form Pólya-Gamma route — VA is frozen. (The PG route
  is verified sound, gradient `1.55e-15` at the fixed point, but it is **JJ-only**
  and therefore accelerates the arm that recovers *worst*.)
* Re-propose the GLMM/BLUP start — built, measured, reverted as a 4/4 → 0/4
  regression (`10b742f2`). It still sounds right; it is not.
* Chase VA as an estimator. Use it as a comparator when you want a second
  opinion — which it earned at n=5397, disagreeing with Laplace in a way that
  mattered.

---

## 6. Housekeeping

* A `devtools::test()` process (**PID 95515**) has been running **3+ days**.
  Almost certainly hung. No session here started it — kill it when convenient.
* An article on VA/EVA is on your list, **gated on capability**. Right now it
  would have to say "3 of 16 families, no user-facing route". After AGHQ lands
  it becomes a much better paper.

## 7. The honest headline from last night

Five claims died, four of them mine — including my own "L-BFGS-B is 16× faster"
(it is 0.9× as a polish, 17.7–37.7× as the *primary* optimiser) and "lbfgsb
should be the default" (it is 1.7× **slower** on the accurate tier). Three
*verifications* were also found to be silently vacuous — a substring bug matching
`"not_converged"` as `"converged"`, a comparison that auto-dispatch had turned
into blocked-vs-blocked, and a suite running new tests against a stale namespace.

The measured results are in the commits. The retractions are the reason to trust
them.
