# Capability build-up campaign — toward a finished first CRAN release

**Date:** 2026-07-12
**Decision (Shinichi):** Do **not** rush 0.5.0 to CRAN as a thin recovery-grade
release. First **build up capabilities** so the first release is **finished and
genuinely usable for a focused scope** — *"systematic, not comprehensive, but
quite finished and usable for particular structures and particular common
distributions."* This supersedes the earlier "ship thin 0.5.0 now, defer all
gaps to 1.0" plan. Version number is a downstream detail.

**Baseline:** the current tree passes `R CMD check --as-cran` at **0E/0W/1N**
(only the benign "New submission"). We build on a provably-clean foundation.

## Locked scope (the finished first release)

| Axis | IN scope | Deferred |
|---|---|---|
| **Distributions** | gaussian · poisson · nbinom1 · nbinom2 · binomial | beta, Gamma, tweedie, student, gengamma, truncated/censored, **categorical** (big dev), delta/hurdle latent-corr |
| **Structures** | ordinary (scalar/indep/dep/latent) · phylogenetic (`phylo_*`) · **spatial SPDE (`spatial_*`)** | animal QG story (shares relmat machinery; some comes free), kernel deep-dive |
| **Random effects** | intercept **+ ≥1 finished random slope**, across tiers unit / unit_obs / cluster / cluster2 | s≥2 non-Gaussian, exotic tiers |
| **Missing data** | responses across all in-scope families (not Gaussian-only) | multiple `mi()` predictors |
| **Intervals** | point + profile where the target supports it (honest) | full coverage-calibration |
| **Grammar** | add `scalar()` (no-prefix) + `kernel_scalar()` | — |

**"Finish" a cell** = engine fits it + recovery evidence vs truth + fitted
diagnostics + missing-response handling + a doc/example. Point-estimate honest;
no coverage over-claim.

## Phases

**Phase 0 — Real-state audit (RUNNING, 4 read-only agents).** Establish, per
in-scope cell, what is IMPLEMENTED / PARTIAL / MISSING against code (not the
widget's grammar-guesses). Outputs: `scratchpad/audit-{slope-tier, missing,
diagnostics-intervals, structured-admission}.md`. This settles the two honesty
flags and task #8, and *defines Phase 1's slices*.

**Phase 1 — Close grammar/engine gaps** (per the audit). Candidate slices
(finalised once the audit lands): finish random slope (≥1) for each in-scope
family × {ordinary, phylo, spatial}; extend missing-response beyond Gaussian;
extend diagnostics to all in-scope families; confirm/repair structured-source
admission per family; add `scalar()` + `kernel_scalar()`. **Mostly Codex's
live R/TMB lane**; Claude writes parser/logic where pure, plus test skeletons.

**Phase 2 — Recovery-evidence campaign (Totoro / DRAC).** For every finished
cell, a gated multi-seed recovery study (truth vs estimate; MCSE; failed-fit
denominators). Turns opt-in sims into committed evidence. Compute-heavy;
stream results to disk per unit.

**Phase 3 — Docs for the finished scope.** One honest worked example per
in-scope structure × representative family; update the keyword grid (scalar
cells) and the capability widget from verified per-cell status.

**Phase 4 — Final gate + CRAN prep.** `--as-cran` on the final tree,
`cran-extrachecks`, visual/mobile QA, then Shinichi's release decision.

## Roles / division of labour

- **Claude** — plans (this doc), the Phase-0 audit, pure-logic parser/refactor,
  test skeletons, prose/docs, orchestration, the widget. Runs pure-logic checks.
- **Codex** — the live toolchain: real R/TMB engine work (new family×structure
  fits, slope/missing plumbing), `R CMD check`, rendering. Sequential per repo;
  hand off via `protocols/handoff.md`.
- **Compute (Totoro / DRAC)** — Phase-2 recovery campaigns. Totoro (≤100 cores,
  no queue) for quick turns; DRAC job arrays for large multi-seed.

## Verification (built into every phase)

Recovery vs truth per cell (Phase 2); fitted diagnostics per family; `--as-cran`
each engine change; adversarial review (Rose/statistical-reviewer) before any
"finished" claim. No cell is "finished" on a single small-n recovery — run the
n-ladder (sample-size-first discipline).

## Status (updated 2026-07-12, Claude session; Codex out ~3 days)

Baseline `--as-cran` = 0E/0W/1N. Branch `claude/release-0.5.0`; all work below
committed, **not pushed past `b18b683b`** (later commits local). Slope scope
locked = **FULL** (unit_obs/cluster2 + ordinary indep/dep slopes).

- ✅ **Phase 0 audit** — 4 reports in `scratchpad/audit-*.md`; consolidated gap
  map `docs/dev-log/2026-07-12-capability-audit-gapmap.md`.
- ✅ **Tier 1 bugs (4/4)** — `aa76b84c` (T1.1 binomial cbind+mask crash),
  `4dfd2e2b` (T1.4 NB1 rootogram), `db9ecb06` (T1.3 phylo_signal wald),
  `f7c0198b` (T1.2 non-Gaussian latent-slope Ψ warn). Full suite FAIL 0 / PASS 4471.
- ◐ **Tier 3 coverage** — `c2d93609`: non-Gaussian missing-response
  (poisson/nbinom2/binomial) sentinel-invariance tested → upgraded from
  "works, untested". README missing-response row qualified.

### Remaining, in Claude-doable priority order (Codex out ~3 days)
1. **Tier 3 coverage (Claude lane — highest leverage):** nbinom1 structured
   base grid (scalar/dep/latent × phylo/spatial) recovery tests; non-Gaussian
   `mi()` predictor tests (audit probes confirm both work, untested); nbinom1
   interval-route tests.
2. **T2.3 binomial exact-residual diagnostic** (moderate R work).
3. **T2.4 `scalar()` + `kernel_scalar()`** grammar (parser Claude-doable;
   verify no TMB change needed).
4. **Tier 4 docs:** refresh this widget + `61-capability-status.md` from the
   verified audit (stale 2026-06-28).
5. **T2.1/T2.2 structural slopes** (unit_obs/cluster2, ordinary indep/dep) —
   heaviest live-TMB engine work; Codex's lane on return, or cautious Claude
   attempt if prioritised. Recovery campaign (Phase 2) on Totoro/DRAC follows.

This is a multi-session campaign — resume from this section + the gap map.
