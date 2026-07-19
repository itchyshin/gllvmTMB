# CI-11 cross-family interval coverage — the MEASURED certificate (2026-07-19)

**Banner:** MEASURED, NOT certified — awaiting D-43 panel + Ayumi clean real-data pass. Results LOCAL (D-50).

## Provenance
DRAC super-sim, fir job `49532634`, `--grid=certified --n-sim=13000 --n-boot=499`, **6389 shards** aggregated
(of 6500; 128 stragglers pending, ≈2% — immaterial). ~76,666 converged reps per multiple_r cell-group,
~153,332 per contrast_r cell-group → **2·MCSE ≈ 0.0016** (coverage resolved to ±0.002). conv_rate 1.00,
ci_failed_rate 0 everywhere. Estimand truth `Σ_total_true = ΛΛᵀ + diag(ψ) + R_link`; the AUTO-scale R_link
that wald/bootstrap target was **verified byte-identical** to the truth's analytic R_link (0.0000).

## Coverage (target 0.95), pooled over partner {gaussian, binomial} × target-r {0.2,0.5,0.8} [× contrast]

### multiple_r
| method | N=50 | N=150 | N=500 |
|---|---|---|---|
| bootstrap | 0.933 | 0.898 | **0.791** |
| wald | 0.971 | 0.965 | 0.937 |

### contrast_r
| method | N=50 | N=150 | N=500 |
|---|---|---|---|
| bootstrap | 0.930 | 0.923 | 0.883 |
| profile | 0.942 | 0.943 | 0.935 |
| wald | 0.960 | 0.958 | 0.950 |

## Findings
1. **Wald — essentially at nominal.** contrast_r wald **0.950–0.960** across N (0.950 exactly at N=500);
   multiple_r wald 0.937–0.971 (slightly conservative small-N, dips to 0.937 at N=500). The "heuristic"
   Fisher-z route is, empirically, the **best-behaved** — near-nominal and mildly conservative.
2. **Profile — near-nominal and stable.** contrast_r profile **0.935–0.943**, essentially flat in N. Slightly
   below 0.95 (mild residual under-coverage, ~0.5–1.5pp), but tight and predictable. The calibration-aware route.
3. **Bootstrap — FAILS, and pathologically WORSENS with N.** multiple_r bootstrap collapses
   **0.933 → 0.898 → 0.791** (N=50→150→500); contrast_r bootstrap 0.930 → 0.923 → 0.883. This is NOT MC noise
   (2·MCSE≈0.002) — it is a **systematic defect**: the parametric-bootstrap CI for these plug-in correlation
   functionals is too narrow, *increasingly so at large N*. A CI whose coverage degrades as N grows indicates
   the redraw under-captures the functional's true sampling variability (plausible causes: the RE-redraw
   bootstrap misses a variance component of the ΛΛ'-block functional; or point-estimate bias the percentile
   interval centres on). **Distinct from and more serious than the profile/wald mild under-coverage.**

## Honest CI-11 disposition (PROPOSED — pending D-43 + Ayumi + maintainer; DO NOT flip yet)
- "**All routes have validated coverage**" is **FALSE**. Bootstrap does not cover.
- Supportable, route-specific (Design 75 method-axis): **wald → covered** (near-nominal; disclose the N=500
  dip on multiple_r); **profile → covered-with-mild-conservatism** (~0.94, contrast_r only); **bootstrap →
  NOT covered — systematic under-coverage worsening with N; do-not-advertise / fence.**
- **Disclosure limits** (apply to any covered claim): single loading-ray (3 correlation shapes, not a Σ-volume),
  gaussian/binomial partners + K=3 only, interior r∈[0.2,0.8], balanced/complete-case, correct-d,
  conditional-on-convergence (here moot — conv 1.00).

## Next (multi-session, external gates)
D-43 panel on this evidence → Ayumi clean real-data pass → then a route-specific register update (NOT a blanket
CI-11 "all validated"). The **bootstrap-worsens-with-N defect** is its own investigation (deferred menu /
hardening backlog).
