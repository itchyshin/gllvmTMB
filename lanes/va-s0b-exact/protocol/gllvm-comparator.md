# Series note — matched gllvm comparator (standing)

**Date:** 2026-08-07  
**Authority:** Shinichi standing rule for VA validation / diagnosis arcs.  
**Applies to:** S0a (forward), S0b, and later S1–S4 / diagnosis probes.

## Invariant

Scientific absolute-first cells should report **gllvmTMB VA**, **gllvmTMB
Laplace (secondary)**, and **gllvm VA (and gllvm Laplace if available)** vs
planted truth, with model-match caveats documented.

Do **not** publish diagnosis tables that only show gllvmTMB VA vs gllvmTMB
Laplace when a matched `gllvm` fit is feasible.

## Feasibility / match caveats (document every time)

| Axis | Typical match note |
| --- | --- |
| Covariance | Design 110 exact cells are loadings-only (`Σ = ΛΛ'`); gllvm `num.lv` VA is also loadings-only — matched on Ψ absence. |
| Family API | gllvm often wants string families (`"poisson"`, `"gamma"`); `Gamma(link="log")` is **rejected** (`Selected family: Gamma not permitted`). Confirmed 2026-08-07: `family="gamma"` works for both `method="VA"` and `method="LA"`. |
| Gamma shape / φ | Parameterisation may differ across packages; primary scored estimands remain β and Σ vs planted truth. |
| Laplace | Include gllvm Laplace **when** the API exposes it for that family (`method="LA"` with `family="gamma"` works). Else mark `gllvm_LA = N/A` explicitly. |
| Seeds / DGP | Prefer identical planted draws; local probes **≤10 cores** (Shinichi 2026-08-07); consolidate — do not thrash parallel jobs. |

## Active local probes (2026-08-07) — coordinate, do not thrash

| Dir | Role |
| --- | --- |
| `/private/tmp/va-poisson-gllvm-probe-20260807/` | Primary VA paired script (`probe-poisson-gamma-paired.R`); early smoke only so far |
| `/private/tmp/va-s0b-gllvm-h2h-20260807/` | Sibling h2h / Laplace-extended compare — consolidate into one table |

Outputs expected: `paired-summary.csv`, `paired-seed-rows.csv`, optional `s0b-known-truth-reference.csv`.
