# S1 absolute-first scientific protocol (binomials NARROW)

**Date:** 2026-08-07  
**Lane:** `lanes/va-s1-binomials`  
**Frozen Arc-2 authority:** Design 110 Arc-2 overall labels remain authoritative;
this protocol adds a **secondary** scientific ledger only.

## Why S1 first

**Binomial = SDM / evidence-synthesis flagship alongside gaussian** (Shinichi
2026-08-07). Applied anchor:
https://github.com/Ayumi-495/urbanisation_map/issues/13
(Ayumi Stage 1 map + three-package robustness). Do not start later GH families
until this ledger exists.

| Item | Value |
| --- | --- |
| cells | `binomial_logit`, `binomial_probit`, `binomial_cloglog` |
| n, p | 120, 8 |
| q | {2, 5} |
| H | 7 (GH; binomials are not exact-route) |
| estimators | `va`, `laplace` (default LA = Arc-2 lineage) |
| LA+tricks | exploration arm: `aghq=9`, `aghq_ridge=2` — budget-gated probe, not Arc-2 rewrite |
| seeds | **10601:10900** (n=300; disjoint from Arc-2 / S0a / S0b) |
| platform | Totoro (D-50) |
| planned rows | 3 × 300 × 2 × 2 = **3600** (VA+default LA) |

## Scoring rules (predeclared)

Same as S0b `lanes/va-s0b-exact/protocol/absolute-first.md`:

1. Completeness.
2. VA reliability Wilson upper ≤ 0.10 (frozen) → drives `(A) scientific_verdict_default`.
3. Absolute recovery PRIMARY: abs-availability ≥ 0.90; mean β RMSE ≤ 0.35; mean Σ rel Frob ≤ 0.50.
4. Dual-report `(B) ABS_ON_COMPLETED_*` secondary — **not** a soft-PASS.
5. Paired Laplace ratios SECONDARY / non-blocking.
6. Always 2×2 gllvm comparator — see `gllvm-comparator.md`.
7. Success bar: **VA ≲ LA** and **VA ≲ gllvm** (or better) on abs recovery.
8. HMSC not a 5th arm.
9. Do not set `calibrated=TRUE`; reprint frozen Arc-2 labels unchanged.

## Entry / stop

- Enter after S0 close + Gamma LA confidence close (hygiene, not stop).
- Stop after ledger + after-task; ask G0 before S2 shared-hardness.
