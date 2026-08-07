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
| Seeds / DGP | Prefer identical planted draws; local probes **≤10 cores** (Shinichi 2026-08-07; was 20 — `PILOT_CORES`/`mc.cores`/`xargs -P` ≤10); one probe at a time; consolidate — do not thrash parallel jobs. |

## Active probes (2026-08-07) — coordinate, do not thrash

**Local parallelism cap: ≤10 cores** (Shinichi 2026-08-07). Prefer **Totoro**
for decisive grids. Do not overlap two `mclapply`/`xargs -P` probes.

| Dir | Role |
| --- | --- |
| `/home/snakagaw/gllvm_work/va-gllvm-h2h-4arm-022b4eab-20260807/` | **Canonical 4-arm** Totoro run (poisson+gamma, q=2/5, 8 seeds) on confirmation `022b4eab` |
| `/private/tmp/va-gllvm-h2h-4arm-20260807/totoro-results/` | Local D-50 copy of Totoro CSVs |
| `lanes/va-s0b-exact/scripts/probe-gllvm-4arm.R` | Script (VA+LA × both packages) |
| `/private/tmp/va-poisson-gllvm-probe-20260807/` | Early VA-only smoke — superseded |
| `/private/tmp/va-s0b-gllvm-h2h-20260807/` | Aborted sibling h2h — superseded |

**Audit:** `docs/dev-log/audits/2026-08-07-va-gllvm-4arm-poisson-gamma.md`

### Headlines from canonical 4-arm (do not re-derive from smoke)

- Poisson `q=2`: all four arms fail abs Σ together (~0.61–0.69).
- Poisson `q=5`: gllvmTMB VA strongest on Σ; gllvm VA weaker (pass_abs 0.12).
- Gamma: **gllvm LA is not hopeless on β/Σ** (8/8; `q=5` pass_abs=1.0). Shape/φ often explodes — not a matched estimand.
- Always report gllvm wall times (see audit table).
