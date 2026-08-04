# The gllvm gap is not a constant factor — it is VARIANCE, and one run in eight is catastrophic

**Date:** 2026-08-04 · **Compute:** Totoro, single-threaded, idle box
**Cell:** N=120, T=10, q=1, binomial-probit, `n_trials`=6, 8 seeds · **Script:** `dev/va-speed/71-split25.R`

## Why this was asked

Two of our own measured facts contradict each other:

- **Ledger claim 20 (STANDS):** gllvm spends ~57 % of its outer parameters numerically
  rediscovering the `A_i` closed form we exploit — verified to 1.9e-9 against a real gllvm fit.
  `21-WHY-GLLVM-IS-FAST.md` is subtitled *"this is how we beat them."*
- **Arc E (2026-08-04):** we lose **0 of 12 seeds** on speed, by 10–50×.

We removed more than half their outer parameters and are still an order of magnitude slower.
Nobody had asked where the time actually goes.

## Result — 8 seeds, same DGP, both engines

| | min | median | max | spread |
|---|---:|---:|---:|---:|
| **gllvm-VA** | 0.086 s | **0.093 s** | 0.294 s | **3.4×** |
| **ours, AC + collapse** | 0.692 s | **0.753 s** | **25.508 s** | **36.9×** |

| ratio | value |
|---|---:|
| median / median | **8.1×** |
| worst case / worst case | **86.8×** |

Per-seed, ours: 25.508, 0.923, 0.780, 0.692, 0.732, 0.725, 0.729, 0.775.
**Every one reported `status = "healthy"`.** The 25.5 s run converged; it just took **35× our own
median** to do it.

## What this changes

**1. The dominant problem is variance, not the constant factor.** Our *typical* gap is **8×**, and
seven of eight seeds sit in a tight band (0.69–0.92 s). One seed costs 25.5 s. Chasing a uniform 8×
and chasing a 1-in-8 blow-up are different projects, and only the second explains Arc E's spread.

**2. It is invisible to the health gate.** The catastrophic run is `healthy`. Nothing in the fit's
own status says "this took 35× longer than it should have", so a campaign averaging over seeds
silently pays for it — and a *median* over few seeds may miss it entirely while a *mean* is
dominated by it.

**3. It looks like conditioning, which is the lever we already know we are behind on.** Seed 1 is
harder for both engines — gllvm also slows, 0.294 s against its 0.093 s median (**3.2×**). But we
degrade **34×** on the same data. A problem that is mildly harder for a well-conditioned optimiser
being *catastrophically* harder for ours is the signature of ill-conditioning, not of expensive
function evaluations. That points at the gap claim 30 already names — *gllvm pins its loadings
diagonal with a separate scale; ours is unconstrained* — and at the `nlminb(scale=)` lever, which as
a crude constant-vector proxy already bought 1.11–1.13× (Arc D).

## ⚠ What this is NOT

- **Not a refinement of Arc E's 25×.** Arc E measured through `18-four-way.R`; this calls
  `.va_r3_fit()` directly. Different code paths, different absolute numbers (median 0.75 s here vs
  5.05 s there). **Do not merge the two figures** — compare each within its own harness.
- **Not the iteration/per-evaluation split I set out to make.** gllvm's return object exposes
  `convergence` and `optim.method` but **no iteration count**, and our own count was not at the
  field I probed. The conditioning reading above is an **inference from the degradation pattern**,
  not from counted iterations. Getting the split properly needs instrumenting both sides.
- **Not a claim about other cells.** One N, one T, q=1, one family, 8 seeds.

## The next measurement, if this is continued

Instrument outer-iteration counts on both sides at this cell and re-run seed 1 against the seven
others. If seed 1 costs ~35× the iterations at similar per-iteration cost, conditioning is
confirmed and the loadings-diagonal scale is the concrete thing to try. If instead its
per-iteration cost explodes, the cause is elsewhere and conditioning work would be wasted.

**That single seed is the cheapest reproducer of this lane's biggest speed problem, and it is
already in hand.**
