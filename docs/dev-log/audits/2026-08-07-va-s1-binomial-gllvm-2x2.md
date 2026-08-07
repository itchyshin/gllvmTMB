# Binomial gllvm 2×2 — first local H2H (fills Arc-2 gap)

**Date:** 2026-08-07  
**Why:** Arc-2/Codex Totoro had **no** gllvm (`docs/dev-log/audits/2026-08-07-va-gllvm-inventory-arc2.md`).  
**Script:** `lanes/va-s1-binomials/scripts/probe-binomial-gllvm-2x2.R`  
**D-50:** `/private/tmp/va-s1-binomial-gllvm-2x2-20260807/`  
**MD5:** summary `a2a3bd5e2d701af3f01e7b17412a48c1` · rows `22640a4541a09fa80f0b128ac478bec5`

## Design

- n=120, p=8, unique=FALSE, binomial **logit**, seeds `10801:10824` (24), q∈{2,5}
- Arms: gllvmTMB VA (public `va_H=7`) / LA × gllvm VA / LA
- H not re-laddered (Totoro H7≈H61 already PASS)

## Summary (mean over finite)

| q | arm | ok | healthy | β RMSE | Σ rel Frob | pass_abs | secs |
| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 2 | gtmb_va | 1.00 | 1.00 | 0.232 | 4.94 | 0 | 3.10 |
| 2 | gtmb_laplace | 1.00 | 1.00 | NA† | NA† | 0 | 1.80 |
| 2 | gllvm_VA | 1.00 | 1.00 | 0.170 | 1.00‡ | 0 | 0.06 |
| 2 | gllvm_LA | 1.00 | 1.00 | 0.311 | 15.8‡ | 0 | 0.73 |
| 5 | gtmb_va | **0** | 0 | — | — | 0 | 0.06 |
| 5 | gtmb_laplace | 1.00 | 0.96 | NA† | NA† | 0 | 4.21 |
| 5 | gllvm_VA | 1.00 | 1.00 | 0.178 | 1.00‡ | 0 | 0.34 |
| 5 | gllvm_LA | 1.00 | 1.00 | 0.172 | 0.95‡ | 0 | 0.88 |

† Laplace β/Σ extractor still broken in this script (fits healthy; scoring bug — fix before claiming LA bar).  
‡ gllvm Σ scale not yet matched to Design-110 / Arc-2 scorer (gllvm_VA Σ≈1.00 looks standardised); **do not** treat pass_abs from this table as scientific.  
**q=5 gtmb_va:** public fence rejects `q>2` (`integration="va"` admission). Arc-2 used the **private** GH engine — Totoro S1 / private-route probe required for q=5 VA×gllvm.

## Verdict for Shinichi

1. **Codex/Arc-2 gllvm?** **N** — confirmed absent by design.  
2. **Binomial gllvm status:** **new local 2×2 started and finished** (q=2 all four arms run; q=5 public VA blocked).  
3. **Next:** fix LA β extractor + campaign-aligned Σ; for q=5 use private VA engine (or Totoro S1). No H-ladder re-run. No fence change.
