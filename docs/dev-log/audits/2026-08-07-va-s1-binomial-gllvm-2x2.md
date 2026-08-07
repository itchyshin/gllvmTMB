# Binomial gllvm 2×2 — scientific (aligned scorers)

**Date:** 2026-08-07  
**Supersedes plumbing table** (β/Σ extractors were not campaign-aligned; q=5
public-fence blocked).  
**Script:** `lanes/va-s1-binomials/scripts/probe-binomial-gllvm-2x2.R`  
**Launcher:** `lanes/va-s1-binomials/scripts/launch-totoro-s1-gllvm-2x2.sh`  
**D-50 local:** `/private/tmp/va-s1-binomial-gllvm-2x2-20260807/`  
**Totoro:** `/home/snakagaw/gllvm_work/va-s1-binomial-gllvm-2x2-20260807/results/`  
**MD5 (Totoro summary):** `4cf322551cbc0139cb0770a349c59c3a`

## Design (campaign-aligned)

- Design-110 DGP: n=120, p=8, `Σ=ΛΛ'` (`unique=FALSE`), β ∈ [−0.25, 0.25]
- binomial **logit**; seeds `10801:10824` (24); q∈{2,5}
- Arms: **gllvmTMB VA = private R3 GH H=7** (Arc-2 path) / gllvmTMB LA /
  gllvm VA / gllvm LA — our VA ≠ gllvm VA
- Metrics: β RMSE, Σ rel Frobenius vs planted, abs caps **0.35 / 0.50**, FE health,
  paired Δ (ours − comparator)
- LA β via `coef(fit)`; LA Σ via `report$Sigma_B` (not `extract_Sigma` link-implicit)
- H not re-laddered (H7≈H61 PASS). **No public fence change.**

## Scientific summary (Totoro; n_ok=24/24 all arms)

| q | arm | β RMSE | Σ rel Frob | pass_abs | secs |
| ---: | --- | ---: | ---: | ---: | ---: |
| 2 | **gtmb_va** | **0.233** | **4.86** | 0 | 1.50 |
| 2 | gtmb_la | 0.221 | 2.81 | 0 | 0.23 |
| 2 | **gllvm_va** | **0.137** | **0.997** | 0 | 0.05 |
| 2 | gllvm_la | 0.148 | 1.44 | 0 | 0.46 |
| 5 | **gtmb_va** | **0.264** | **3.70** | 0 | 12.3 |
| 5 | gtmb_la | 0.223 | 1.60 | 0 | 0.47 |
| 5 | **gllvm_va** | **0.128** | **1.00** | 0 | 0.20 |
| 5 | gllvm_la | 0.146 | 0.93 | 0 | 0.80 |

Paired mean Δ (gtmb_va − gllvm_va): q=2 dβ=+0.096 dΣ=+3.86; q=5 dβ=+0.137 dΣ=+2.70.

## Verdict

1. **β ~0.23 vs ~0.14 is REAL** after alignment (not plumbing). Holds at q=5.
2. **Σ worse** for gllvmTMB VA on both q; all arms fail abs Σ (pass_abs=0).
3. **VA ≲ gllvm: FAIL** on this binomial logit cell (β and Σ). VA ≈ LA on β.
4. Process for later families: **C Hybrid** (ultraplan ladder + continuous probes).
   **STOP** — no nbinom Totoro until Shinichi go.
