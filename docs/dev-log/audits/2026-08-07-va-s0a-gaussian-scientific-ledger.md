# S0a Gaussian absolute-first scientific ledger

**Generated:** 2026-08-07 11:54:21 UTC  
**Export:** `/private/tmp/va-s0a-gaussian-evidence-20260807/final-export-s0a.csv` (MD5 `e2311f0744709e39fb3e66754bdba453`)  
**Plan MD5:** `ec5e96311aea7200f4a1b24eb7081b8c` (1,200 rows; seeds 10001:10300)  
**Arc-2 frozen CSV:** `/private/tmp/va-gh-h7-final-evidence/totoro/adjudication/va-gh-h7-adjudication-totoro-022b4eab.csv` (MD5 `e57f8460fd98bd0eac43b4a6c014317d`)  
**Totoro root:** `/home/snakagaw/gllvm_work/va-s0a-gaussian-022b4eab-20260807`

## Caps

| Cap set | β RMSE | Σ rel Frob | Role |
| --- | ---: | ---: | --- |
| **default (chosen)** | 0.35 | 0.50 | Design 110 Arc-2 absolute bounds |
| alternate | — | — | **Not proposed** — margins clear under default |

Abs-availability floor: **0.90** (finite VA β/Σ metrics among planned VA seeds).

## Scientific verdicts (PRIMARY)

| q | reliability | abs avail | β RMSE (VA) | Σ rel Frob (VA) | **SCIENTIFIC (default)** | frozen Arc-2 overall |
| ---: | --- | ---: | ---: | ---: | --- | --- |
| 2 | PASS (fail 0/300; Wilson U 0.013) | 1.00 | 0.071 | 0.395 | **SCIENTIFIC_PASS** | INCONCLUSIVE |
| 5 | PASS (fail 2/300; Wilson U 0.024) | 1.00 | 0.088 | 0.367 | **SCIENTIFIC_PASS** | INCONCLUSIVE |

Machine-readable twin: `2026-08-07-va-s0a-gaussian-scientific-ledger.csv`.

## Secondary Laplace diagnostics (NON-BLOCKING)

| q | LA healthy | paired eligibility | ratio status |
| ---: | ---: | ---: | --- |
| 2 | 119/300 | 0.397 | RATIO_NOT_ELIGIBLE |
| 5 | 143/300 | 0.477 | RATIO_NOT_ELIGIBLE |

Paired VA/Laplace ratio ineligibility does **not** force SCIENTIFIC_FAIL. This
is the same Laplace comparator attrition that made Arc-2 overall INCONCLUSIVE.

## Frozen Arc-2 labels

Both Gaussian ranks retain `overall_point_route_verdict = INCONCLUSIVE`.
This ledger does **not** soft-PASS or mutate those labels. Public fence and
`calibrated = FALSE` are unchanged.

## Calibration note

Arc-2 reported CALIBRATED beta-Wald and latent-SD labels for Gaussian; those
remain descriptive only — this package does not promote `calibrated=TRUE`.

## gllvm comparator (standing rule 2026-08-07)

S0a Totoro export is gllvmTMB-only. Forward: scientific absolute-first cells
should also report matched **gllvm VA** (and Laplace if available) vs planted
truth — see `lanes/va-s0b-exact/protocol/gllvm-comparator.md`.
