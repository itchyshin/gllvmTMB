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

| q | arm | β RMSE | Σ rel Frob | pass_abs | secs | notes |
| ---: | --- | ---: | ---: | ---: | ---: | --- |
| 2 | **gtmb_va** | **0.233** | **4.86** | 0 | 1.50 | runaway Σ̂ (real) |
| 2 | gtmb_la | 0.221 | 2.81 | 0 | 0.23 | inflated |
| 2 | **gllvm_va** | **0.137** | **0.997** | 0 | 0.05 | **Σ̂≈0 collapse** (23/24 \|rf−1\|<1e−6) |
| 2 | gllvm_la | 0.148 | 1.44 | 0 | 0.46 | non-zero Σ̂ |
| 5 | **gtmb_va** | **0.264** | **3.70** | 0 | 12.3 | runaway Σ̂ (real) |
| 5 | gtmb_la | 0.223 | 1.60 | 0 | 0.47 | inflated |
| 5 | **gllvm_va** | **0.128** | **1.00** | 0 | 0.20 | **Σ̂≈0 collapse** (24/24) |
| 5 | gllvm_la | 0.146 | 0.93 | 0 | 0.80 | non-zero Σ̂ |

Paired mean Δ (gtmb_va − gllvm_va): q=2 dβ=+0.096 dΣ=+3.86; q=5 dβ=+0.137 dΣ=+2.70.  
**Read ΔΣ with care:** compares runaway (ours) to zero-estimator (gllvm VA), not two recoveries.

## Shinichi challenge (2026-08-07): are Σ rel Frob 3.7–4.9 impossible / wrong?

**Is relative Frob >1 “impossible”?** **No.** Rel Frob = ‖Σ̂−Σ‖_F / ‖Σ‖_F is **unbounded above**. Values >1 are allowed and mean the error is larger than the truth matrix itself — worse than the zero estimator in Frobenius distance (that baseline has rel = 1 exactly).

### Hand recomputation (seeds 10801, 10804, 10814; q=2)

Estimand checked: both arms score loadings-only `Σ = ΛΛ′` vs planted `ΛΛ′` (no ψ; not correlation; not `extract_Sigma`’s π²/3). Formula and denominator are correct.

| seed | ‖Σ_true‖_F | arm | ‖Σ̂‖_F | ‖diff‖_F | rel | diagnosis |
| ---: | ---: | --- | ---: | ---: | ---: | --- |
| 10801 | 1.729 | gtmb_va | **4.125** | 3.626 | **2.097** | matches table; inflated loadings |
| 10801 | 1.729 | gtmb_la | 2.207 | 2.060 | 1.191 | inflated |
| 10801 | 1.729 | gllvm_va | **~0** | 1.729 | **1.000** | `sigma.lv ≈ 1e−6`; zero estimator |
| 10801 | 1.729 | gllvm_la | 1.147 | 1.539 | 0.890 | real non-zero |
| 10804 | 0.826 | gtmb_va | **6.17** | 6.11 | **7.40** | runaway |
| 10804 | 0.826 | gllvm_va | **~0** | 0.826 | **1.000** | collapse |
| 10814 | 0.894 | gtmb_va | **8.09** | 7.86 | **8.80** | runaway |
| 10814 | 0.894 | gllvm_va | **~0** | 0.894 | **1.000** | collapse |

Footguns ruled out for gtmb: not link-implicit ψ; not cov-vs-cor; not Λ Frobenius mislabeled as Σ; not row/col order; not wrong denominator. `extract_Sigma` *would* add π²/3 — probes correctly use `Sigma_B` / `ΛΛ′`.

### Verdict

**(A) Numbers are mathematically possible and mean near-total Σ failure for gtmb_va** (runaway scale: ‖Σ̂‖_F ≫ ‖Σ‖_F). Not a scorer arithmetic bug; not an estimand mismatch that inflates ours only.

**Interpretation correction (not a number change):** gllvm VA’s ~1.0 is **also catastrophic** — it is the zero-estimator baseline (`sigma.lv` collapsed), not a successful recovery that we are 4× worse than. All arms still fail abs Σ≤0.50. Fair comparator for “does anyone recover Σ?” is **gllvm LA** (and ‖Σ̂‖_F / collapse flag), not gllvm VA’s collapsed scale.

Scorer enrichment (probes): now emit `frob_Shat`, `frob_Strue`, `sigma_collapse` so collapse vs runaway cannot be misread from rel alone.

## Verdict (scientific)

1. **β ~0.23 vs ~0.14 is REAL** after alignment (not plumbing). Holds at q=5.
2. **Σ worse** for gllvmTMB VA on both q (runaway); all arms fail abs Σ (pass_abs=0). gllvm VA fails by **collapse**.
3. **VA ≲ gllvm: FAIL** on this binomial logit cell (β; Σ vs non-collapsed comparators also fail).
4. Process for later families: **C Hybrid** (ultraplan ladder + continuous probes).
   **STOP** — no nbinom Totoro until Shinichi go.
