# After-task — 0.5→0.6 gap-closure, execution phase 1

**Date:** 2026-07-13 · **Owner:** solo Claude (no Codex) · **Plan:**
`~/.claude/plans/luminous-weaving-nova.md` · **Branch:** `claude/release-0.5.0` (uncommitted).

## Scope

Execute the cheap/independent slices of the 0.5→0.6 gap closure and validate the
interval-coverage headline machinery, per the approved plan. Headline (A2, the n_sim=2000
Totoro grid) deferred — it needs a maintainer Totoro session (MFA).

## Outcome — verified green (real fits, 0 skips)

| Slice | Deliverable | Verification |
|---|---|---|
| **A0** | Design-66 amendment (ordinal excluded, repair map) + punch list | doc, code-checked |
| **A1a** | `pilot_scale_gate()` — calibrated PASS-to-scale decision surface (MCSE + fit-health denominators + true-probit + ordinal-exclusion + signal=0 diagnostic) | 9/9 unit test; **validated end-to-end on live bootstrap pilot → `PASS_TO_SCALE`** |
| **D** | binomial/Gamma/Beta exact randomized-quantile residuals | 23 + 158 pass |
| **C1** | nbinom1 masked-response sweep | 20 pass |
| **E2** | `reml_bridge()` ML−REML gap diagnostic (opt-in, Gaussian-only) | 14 pass |
| **E3** | delta positive-part correlation wiring + "conditional on occurrence" label | 14 pass |
| **B1** | tweedie "~44%" slope-SD bias diagnosis — ALL 3 ARMS (`dev/tweedie-slope-diagnosis.R`) | **DONE — the 44% is NOT a systematic bias.** **Arm 1** n-ladder (p fixed, 18 cells, dev-escaped #388 gates): rel_bias **−31%…+26%, mean ≈ 0**; convergence improves with n → the +44% was a single small-n high-variance draw. **Arm 2** ML−REML gap: negligible (~1e-4, Gaussian control); tweedie REML `NA` (E2 limit). **Arm 3** GHQ-vs-Laplace: Laplace ≈ GHQ (not the cause). Real issue = **imprecision + soft small-n convergence, not systematic bias** — contradicts the handover. tweedie stays gated (imprecision caveat); admitting-with-caveat is a Shinichi call. Dev-only `GLLVMTMB_DEV_TWEEDIE_SLOPE_DIAG` (default-OFF) on the phylo_indep/dep gates. |
| **B2** | nbinom1 phylo_dep slope recovery | **verified: RECOVERS PD in-band** (6 assertions pass, not skipped) — nbinom1 stays on the slope allowlist |
| **B4** | Tier-3 `cluster2` diagonal (`indep`/`||`) random-slope C++ engine via `unique(1 + x | c2)` | **BUILT + verified**: TMB compiles+loads, **zero regression** (cluster2-families 70 / rename 25 / ordinary-latent 90 / nbinom1 29), **new path recovers** (cluster2-slope-recovery 10 pass). Design 81. Follow-ons: unit_obs tier, correlated Tier-3, B3 bare-`\|\|` spelling |
| CI | Disabled 14 sim/recovery/sweep Actions campaigns (D-50) | `gh workflow list` confirms |

Coverage harness runs **locally** (Design 66 Phase-1): smoke `n_errored=0`; a bounded live
bootstrap pilot (4 binomial-probit cells) produced sensible coverage (0.875 / 0.914) with
smoke-grade MCSE and a correct `PASS_TO_SCALE` verdict + the "n_sim=2000 needed to adjudicate"
note. **The whole A-decision path is proven; only the Totoro adjudication remains.**

## Decisions

- **B3** resolved: unprefixed `latent||`/`indep||`/`dep||` grammar doesn't exist; it's the SAME
  engine as B4 (`indep||` aliases the existing diagonal `unique` engine; `latent||`/`dep||` need
  the block-diagonal build). Folded into B4. Maintainer approved the grammar change ("yes build").
- Ordinal excluded from the coverage core (Repair #2 by exclusion) — calibrated ordinal variance
  is Bar-3/AGHQ (1.0).

## Checks

- `devtools::load_all()` clean (E2 `reml_bridge` export consistent).
- Targeted heavy tests summed the `error` column (all 0). #388 respected (no family advertised
  beyond its recovery evidence).
- Local coverage pipeline exercised on live fits; `pilot_scale_gate` gave the right verdict.

## Follow-up (next focused pass)

1. 🔴 **A2 needs the maintainer**: open a Totoro session (Duo MFA → ControlMaster socket); then
   drive the n_sim=2000 core grid (gaussian/nbinom2/binomial-probit) ≤100 cores. Pilot must clear
   its gate first.
2. **B4+B3 (atomic build)**: the Tier-3 `||` C++ slope engine — coordinated
   `src/gllvmTMB.cpp` (clone `use_diag_B_slope` keyed on `cluster2_id`) + `R/fit-multi.R` wiring +
   `R/brms-sugar.R` grammar + recompile + recovery test. Must land in one pass (adding C++
   DATA/PARAM breaks every fit until the R side supplies them).
3. **B2**: nbinom1 slope recovery fixture (converging PD cell).
4. **Full local Phase-1 pilot** (48 cells) — long background run, or defer to Totoro.
5. **A3** (widget/NEWS coverage flip) + **F** (page-by-page honesty review WITH Shinichi) — gated
   on A2 evidence; F is the pre-CRAN human gate.

## State

Substantial verified work is **uncommitted** on `claude/release-0.5.0`. Held files
(`.Rbuildignore`, `.github/workflows/pkgdown.yaml`, `CONTRIBUTING.md`, `ROADMAP.md`) remain the
maintainer's disposition — NOT to be committed. Awaiting maintainer go-ahead to commit the
verified slices.
