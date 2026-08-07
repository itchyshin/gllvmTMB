# NB2 (nbinom2) 2×2 smoke — LA / VA × gllvm (Totoro)

**Date:** 2026-08-07  
**Authority:** Shinichi go on LA/VA vs gllvm comparisons; Totoro OK for speed.  
**Estimator rev:** confirmation `022b4eab` (Totoro checkout).  
**D-50:** raw CSVs on Totoro + `/private/tmp` only — not git-staged.  
**Claim level:** **smoke only** — do **not** claim PASS/FAIL on abs caps.

## Roots

| Host | Path |
| --- | --- |
| Totoro | `/home/snakagaw/gllvm_work/va-s2-nbinom2-2x2-20260807/` |
| Local copy | `/private/tmp/va-s2-nbinom2-2x2-smoke-20260807/` |
| Script | `lanes/va-s2-nbinom2/scripts/probe-nbinom2-2x2-smoke.R` |
| Launcher | `lanes/va-s2-nbinom2/scripts/launch-totoro-nbinom2-2x2.sh` |

MD5 (`smoke-summary.csv`): `07264299454492a90c4a7bd87b2d059a`

## Design (apples-to-apples)

- DGP: Design-110 loadings-only (`n=120`, `p=8`, `q=2`, `Σ=ΛΛ'`, `unique=FALSE`)
- Family: **nbinom2 / log** — Design-110 registry **GH** (no closed-form ELBO); `family_id=5`
- Planted size `φ=1.5` (`Var = μ + μ²/φ`); φ is **not** a matched estimand across packages
- Seeds: 11201:11216 (16)
- Arms: **gtmb VA-GH H=7** (private `.va_r3_fit`, `n_starts=1`) · **gtmb LA** (`se=FALSE`) · **gllvm VA** · **gllvm LA** (`family="negative.binomial"`, `n.init=1`, `starting.val="zero"`)
- Warm DLL outside timed cells; Totoro 16 cores; wall ~10 s after compile
- Abs caps (reported, not adjudicated): β RMSE ≤ 0.35 ; Σ rel Frob ≤ 0.50

## Model-match caveats

1. **Ψ / unique:** both packages loadings-only — matched on Ψ absence.
2. **gllvm family string:** `"negative.binomial"` (not `"nbinom2"`).
3. **φ parameterisation:** gllvm reports dispersion-like `phi` (~0.5–1 here ≈ 1/size); gllvmTMB `exp(log_phi_nbinom2)` often huge on this smoke. Primary estimands remain β and Σ.
4. **gtmb VA `healthy`:** with matched `n_starts=1` the multi-start agreement gate cannot fire → `status=failed_health_gate` on all 16 seeds. Finite β/Σ still scored (`ok=TRUE`). Do not equate gate FAIL with hopeless recovery.
5. **gllvm VA Σ collapse:** 14/16 seeds have ‖Σ̂‖_F ≈ 0 (rel Frob ≈ 1). That is **not** good recovery — it is near the zero estimator.

## Summary (16 seeds; mean over finite β+Σ)

| arm | n_ok | n_healthy | β RMSE | Σ rel Frob | pass_abs | collapse | secs mean | vs gtmb_LA |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| gtmb_VA | 16 | 0† | 0.151 | 1.028 | 0 | 0.00 | 1.62 | **2.45×** |
| gtmb_LA | 16 | 16 | 0.185 | 1.175 | 0 | 0.00 | 0.66 | 1.00× |
| gllvm_VA | 16 | 16 | 0.177 | 0.998‡ | 0 | **0.875** | 0.068 | 0.10× |
| gllvm_LA | 16 | 16 | 0.191 | 1.150 | 0 | 0.00 | 0.56 | 0.85× |

† `n_starts=1` bypasses multi-start health gate by design.  
‡ Mean Σ rf looks slightly better than gtmb_LA only because collapse → rel≈1; do not rank gllvm VA as winning Σ.

Paired Δ (arm − gtmb_LA): gtmb_VA β **−0.034** / Σ **−0.147**; gllvm_LA β +0.006 / Σ −0.024.

## Contrast vs banked poisson / gamma / binary

| family | q=2 abs Σ story (banked) | LA vs VA cost | VA ever? |
| --- | --- | --- | --- |
| poisson | all four arms fail abs Σ together (~0.61–0.69) | LA ≪ VA wall | VA can edge Σ at q=5 |
| gamma | LA recovers abs well (esp. q=5); VA reliability separate | LA much cheaper | not for default |
| binary | GH vs gllvm VA ≲ bar FAIL on β (banked S1); dig parked | LA preferred; AGHQ opt-in | JJ/PoisG lanes separate |
| **NB2 (this smoke)** | **all four fail abs Σ together (~1.0)** — shared regime | **LA 2.45× cheaper than matched-start VA** | **no default win; slight β/Σ edge only** |

## Recommendation for Shinichi (NB2)

1. **Prefer gllvmTMB LA** as the default NB2 arm on this geometry: healthy FE gate, ~0.66 s, scorable β/Σ, no collapse.
2. **VA (GH H=7) is not required for default** — it edges mean β/Σ vs LA (paired) but still fails abs Σ with every other arm, costs **2.45×**, and cannot clear the shipped multi-start health gate at matched `n_starts=1`.
3. **Do not treat gllvm VA as the Σ bar** on NB2 here — 87.5% loading collapse.
4. **Next (optional, needs go):** larger N or q∈{2,5} on Totoro; keep φ out of abs pass/fail. No fence / `auto` flip.

## Checks

```sh
ACTION=sync ./lanes/va-s2-nbinom2/scripts/launch-totoro-nbinom2-2x2.sh
ACTION=full PROBE_N_SEED=16 PILOT_CORES=16 \
  ./lanes/va-s2-nbinom2/scripts/launch-totoro-nbinom2-2x2.sh
# EXIT 0; done 09:56:12 MDT; summary MD5 07264299454492a90c4a7bd87b2d059a
LOCAL_PULL=/private/tmp/va-s2-nbinom2-2x2-smoke-20260807 ACTION=pull \
  ./lanes/va-s2-nbinom2/scripts/launch-totoro-nbinom2-2x2.sh
```

Deliberately not run: fence edits, H-ladder, logit-GH reopen, PoisG, package tests.
