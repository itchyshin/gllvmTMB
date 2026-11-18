# Beta Jeffreys / I_μ atom — status 1 was not invalid

**Date:** 2026-08-16
**Lane:** `cursor/mspl-beta-jeffreys-atom`
**Status:** diagnosis + tape fix. **No public door. Not admitted.**

## What #999 / #1014 actually saw

Live Beta MSPL on the 8×3 `#999` cell aborted with

> The guarded Jeffreys information atom did not return a valid result.
> Atomic status code: 1.

`skip_if(TRUE)` then fenced the internal \(Q_P\)/\(Q_0\) pin. That
read status 1 as “invalid atom.” It is not.

Frozen V8 codes in `src/lane_b_jeffreys_maxvol_atomic_v8.h`:

| code | meaning |
|---|---|
| 0 | `OK_DOUBLE_CERTIFIED` |
| **1** | **`OK_MP_CERTIFIED`** |
| 10+ | input / rank / maxvol / factorisation failures |

R `fit-multi.R` accepted only `atom_status == 0`. An MP-certified
half-logdet is a valid atom. Treating 1 as failure is why the pin
could not un-skip.

## Why Beta hit the MP path

Two stacked defects, both Beta-only in this slice.

1. **Wrong GLM-outer diagonal.** Ferrari & Cribari-Neto (2004) write
   \(K_{\beta\beta}=\phi X^\top W X\) with inner
   \(w_t=\phi\{\psi'(a)+\psi'(b)\}/\{g'(\mu)\}^2\). On logit that is
   \[
   w=\phi^2\{\mu(1-\mu)\}^2\{\psi'(\mu\phi)+\psi'((1-\mu)\phi)\}.
   \]
   The tape used the inner \(W\) only (one \(\phi\)). Default
   `log_phi_beta = 1` means \(\phi=e\), so every row was mis-scaled
   by \(e\) from the first evaluation. Phase-4 oracles already used
   the \(\phi^2\) form (E2: \(w\to 1\) as \(\mu\to 0/1\); the one-\(\phi\)
   form goes to \(1/\phi\)).

2. **Nearly constant weights.** Even the correct \(w\) is not
   coercive at \(\mu\to 0/1\) (\(w\to 1\)). On the dummy-trait 8×3
   cell the maxvol double certificate can fail its \(10^{-12}\)
   exchange budget and fall back to MP. That is status 1, not 10.

Tweedie hang (\(W=\mu^{2-p}/\phi\) rewards \(\phi\to 0\)) is a
separate hostility. This note does not touch it.

## What this does not do

- Does not add family id 7 to the public prepare allow-list.
- Does not admit Beta. Does not enable public `se=TRUE`.
- Does not claim the atom repairs \(\mu\to 0/1\).
