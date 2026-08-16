# Frontier campaign results -- E*_pd = 1.85 [1.43, 3.17]; the amplitude frontier is NOT reached

1,600/1,600 fits, 0 errors, 238 s wall on Totoro (11x under budget), 8 levels
x 200 seeds, fields REDRAWN per replicate. Raw rows + summary CSV + estimates
RDS + P1-F2 under the gitignored `results/frontier/`; scripts committed in
`frontier-campaign/`.

| E | pd_rate (MCSE) | med rel amp err | median ||lam|| (truth 16.15) | cov_lam (pd subset) |
| --- | --- | --- | --- | --- |
| 0.5 | 0.310 (0.033) | ~0.99 | 0.20 | 0.51 |
| 1   | 0.390 (0.034) | ~0.97 | 0.48 | 0.65 |
| 1.5 | 0.445 (0.035) | ~0.98 | 0.38 | 0.71 |
| 2   | 0.520 (0.035) | ~0.5  | 12.59 | 0.85 |
| 3   | 0.485 (0.035) | ~0.7  | 4.76 | 0.85 |
| 4   | 0.610 (0.034) | ~0.4  | 14.88 | 0.93 |
| 8   | 0.645 (0.034) | 0.80* | 13.80 | 0.92 |
| 16  | 0.680 (0.033) | 0.58  | 16.89 | 0.94 |

*medians of |amp error|/truth; IQRs in frontier-summary.csv.

FINDINGS, in order of weight:

1. **E*_pd = 1.85 [1.43, 3.17]** (50% PD crossing, isotonic + 1000-rep
   bootstrap) -- ~850 expected GBIF detections in this 3-species/360-cell
   design. Consistent with the pilot bracket, now with uncertainty.
2. **E*_rec was never reached: the pilot's optimism does NOT transfer
   marginally.** The pilot held the sealed (favourable) field realization
   fixed; redrawing fields per replicate, the median amplitude error is still
   0.58 at E=16 and the PD rate plateaus at ~0.68. Reliable amplitude recovery
   is governed by the design's spatial replication (~6 patches per side), not
   by effort. This is the campaign's headline.
3. **The failure surface is bimodal: collapse OR runaway.** 92/1600 fits are
   runaways (||lam|| > 100, max 1.3e6), at every level. Echoes the package's
   standing finding that the GLLVM loading pathology is "bimodal, not biased".
   Mechanism unexamined here; candidate link to the known loading-runaway
   class and `aghq_ridge` remedy -- a bounded follow-up slice.
4. **gamma under-covers** (0.79-0.89 on the PD subset) while lambda coverage
   reaches ~0.94 at E=16 -- a flag for the empirical papers' inference plans.

Licence: synthetic known-truth campaign under the predeclared ADEMP design;
design guidance only; no empirical claim; no admission of any consumed
estimator lineage.
