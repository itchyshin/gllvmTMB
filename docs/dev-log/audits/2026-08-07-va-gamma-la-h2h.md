# Gamma Laplace H2H — gllvmTMB LA vs gllvm LA (FE health)

**Date:** 2026-08-07  
**Branch:** `codex/va-gh-all-families` @ worktree `/private/tmp/gllvmtmb-va-gh-all-families`  
**Health fix:** `abaf7802` (FE-only `|g|`; do **not** grade `gr(last.par.best)`)  
**Script:** `lanes/va-s0b-exact/scripts/probe-gamma-la-h2h.R`  
**D-50 raw:** `/private/tmp/va-gamma-la-h2h-20260807/` (not git-staged)

| file | MD5 |
| --- | --- |
| `summary.csv` | `1d4e6bc3f22d22c5938a8778079e3337` |
| `paired-la.csv` | `8258000f31d96af8acc2c9a93fbee3cc` |
| `seed-rows-long.csv` | `dfea8b0fce51668cdeda6a9d51a9b0aa` |

## Design

- DGP: Design-110 exact — `n=120`, `p=8`, `Σ=ΛΛ'` (`unique=FALSE`), shape `2.5`, log link
- `q ∈ {2,5}`; seeds `93001:93024` (24); local **8 cores**; wall **50 s**
- Arms (primary): **gllvmTMB LA** + **gllvm LA** (`family="gamma"`)
- VA×2 skipped this run (`DO_VA=0`) — LA-only cleaner; prior Totoro 4-arm already covers VA
- Abs caps: β RMSE ≤ 0.35 ; Σ rel Frob ≤ 0.50
- Health: `healthy_fe` = `conv==0 ∧ pdHess ∧ max|g|_FE < 1e-3`; also record buggy full `|g|` and proxy `conv∧pd`

## Summary (24 paired seeds)

| q | gtmb FE healthy | proxy conv∧pd | buggy full-g | gllvm “healthy” | mean β (gtmb / gllvm) | Δβ (ours−gllvm) | mean Σ rf | ΔΣ | pass_abs gtmb / gllvm |
| ---: | ---: | ---: | ---: | ---: | --- | ---: | --- | ---: | --- |
| 2 | 0.79 | **1.00** | 0.00 | 1.00 | 0.070 / 0.081 | **−0.011** | 0.399 / 0.508 | **−0.110** | **0.875 / 0.542** |
| 5 | 0.71 | 0.79 | 0.00 | 1.00 | 0.094 / 0.114 | **−0.020** | 0.371 / 0.425 | **−0.053** | **1.00 / 0.917** |

Med FE `|g|` ≈ 6×10⁻⁴ (both q); med **full** `|g|` ≈ 63–71 (the S0b artefact).  
Paired wins (lower error): β 18–19/24; Σ **20–22/24** for gllvmTMB.

## Verdict

**gllvmTMB gamma LA is better than gllvm LA on planted β/Σ absolute recovery** at this Design-110 cell (n=120, p=8, q∈{2,5}).

- Not merely “≈”: mean Δβ and ΔΣ favour ours; abs pass rates favour ours (especially q=2 Σ).
- FE health restores the story: ~70–80% FE-healthy @ tol 1e-3; **100%** q=2 and **79%** q=5 clear `conv∧pd`. Buggy full-gradient health remains **0/48**.
- Shape/φ still not a matched estimand (not scored here).
- Prior Totoro n-ladder “0/6 healthy every n” used confirmation `022b4eab` **before** FE fix — those `max_g≈65` rows are full-vector artefacts; do not cite as post-fix health.

## Totoro?

**Not needed for this ask.** Local 24-seed probe is conclusive on LA×2 abs + FE health. Scale-out only if Shinichi wants tighter CIs, n-ladder re-score with FE gate, or full 2×2 VA refresh.

## Caveats

1. gllvm “healthy” = package `convergence` flag (no FE `|g|` / pdHess analogue exposed here).
2. Scoring uses `extract_Sigma(..., part="shared")` for gllvmTMB (loadings-only LL'); link-implicit residual messages appear and are ignored for the scored matrix.
3. Success bar (VA ≲ LA / VA ≲ gllvm) is a separate question — this audit is **LA vs LA only**.
