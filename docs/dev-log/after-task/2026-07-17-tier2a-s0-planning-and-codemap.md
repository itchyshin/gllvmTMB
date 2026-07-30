# After-task — Tier-2a phylo-multinomial: S0, planning, and the turnkey code-map

**Date:** 2026-07-17 · **Agent:** Claude (Fable 5) · **Arc:** Design 84 (phylogenetic multinomial
GLLVM, multinomial Tier-2a). **Session type:** planning + R-side spec (Codex owns the live TMB build).

## Scope
Rehydrate the Tier-2a handover; produce the ultra-plan; get maintainer sign-off on the three Design 84
§7 decisions; then make maximal Claude-lane progress toward the deliverable (gllvmTMB reporting the
(K−1)×(K−1) among-category V for a multinomial trait via a phylo factor decomposition). Live TMB build
(S2) and the Totoro recovery campaign (S4b) are Codex/compute-owned by the goal's division of labour.

## What changed / was produced
- **S0 (identification spec) — COMPLETE.** Residual convention **pinned**: fix the latent-scale residual
  to `R = (1/K)·(I + J)` on the (K−1) category contrasts (the MCMCglmm categorical convention, read
  from the validated spike `dev/phylo-multinomial-spike.R:60-63`). Supersedes Design 84 §7's
  "identity vs 0.5/0.25" hedge. Estimand/scale reconciliation written (MCMCglmm = apples-to-apples
  reference; brms = scale-checked secondary).
- **Ultra-plan** — `docs/dev-log/2026-07-17-tier2a-ultra-plan-DRAFT.md`. Revised after a self-critique
  the maintainer accepted: added the **consistency-ladder** recovery gate (0.6→0.45 must be proven
  under-power, not asymptotic bias, across N=800/1600/3200); split S2 → S2a core / S2b optimizer
  robustness; added backward-compat, print/summary, and a sample-size-fence slice.
- **S4a harness (draft)** — `dev/phylo-multinomial-harness-DRAFT.R`: generalises the spike into the
  power-calibrated consistency ladder (bias ± MCSE; under-power-vs-bias verdict). Runnable on Totoro.
- **S2 Codex brief (turnkey)** — `docs/dev-log/handover/2026-07-17-tier2a-S2-codex-build-brief-DRAFT.md`.
- **Complete code-map (exact edit points).** fid-16 = `family_id_vec == 16L`. S1 fence at
  `R/fit-multi.R:1793`; S3 fences at `R/extract-sigma.R:629-636` and `R/extract-correlations.R:439-446`;
  extractor defs at `extract-sigma.R:584` / `extract-correlations.R:392`; sparse A⁻¹ engine at
  `R/phylo-tree-precision.R`. Captured in the handover.
- **Arc branch created** — `claude/tier2a-phylo-multinomial` off `main` (worktree `/tmp/gtmb-tier2a`).

## Maintainer decisions (Design 84 §7) — locked 2026-07-17
1. Residual scale = spike's fixed `(1/K)(I+J)`, exposed but default-fixed.
2. Factor rank = fixed small `d` first; latent-rank selection later.
3. Scope = standalone per-trait `V` first; cross-trait fenced. Julia parity = later arc.

## Key finding (changes sequencing)
The `fit-multi.R:1793` fence is **load-bearing**: it rejects a latent/RE term on a multinomial trait
*because the engine has no K−1 category-contrast representation*. **S1 (opening the fence) is therefore
coupled to S2 (the TMB representation)** — relaxing it blind would admit a silently-broken model. Every
code slice (S1 grammar, S3 reporting) depends on a working phylo-factor fit, which only S2 (Codex/TMB)
produces. So the deliverable genuinely requires the Codex handoff + a compute run.

## Checks run
- None executable this session: `devtools::test()` / `R CMD check` require a Bash/R window, which the
  `claude-opus-4-8` classifier outage gated for the entire session (~2 read-only windows in ~21 tries).
- No code was edited on any branch — deliberately. Untested formula-grammar edits are exactly what the
  Discussion-Checkpoint rule guards against; and nothing could be committed (state-changing Bash gated).

## Blockers (all external)
- **Classifier outage** gates state-changing Bash → cannot merge #752, commit, or run tests.
- **S2a/S2b (live TMB)** is Codex-owned; **S4b (recovery campaign)** is Totoro-owned.

## Carried-over (turnkey; resume order)
1. Merge PR #752 (`gh pr merge 752 --squash`); hold PR #751 (article) until the arc lands.
2. Codex: build S2a/S2b against the brief (open the `fit-multi.R:1793` fence + K−1 softmax loadings).
3. Claude: wire S1 parser + flip S3 fences (mapped lines) once S2 exists; run pure-logic tests.
4. Totoro: run `dev/phylo-multinomial-harness-DRAFT.R` consistency ladder (S4b) — the DISCIPLINE gate.
5. Append the pinned `(1/K)(I+J)` convention to the brain note when MCP writes are ungated.

## Follow-up / lessons
- The consistency-ladder gate (not a single-N ±0.25 band) is the recovery discipline for a data-hungry
  method; do not promote to `covered` until it rules out asymptotic bias.
- Reader surfaces carry no `fid-16`/`FAM-20`; compute local→Totoro, never GitHub Actions (D-50).

## Status
Deliverable **NOT reached** — gllvmTMB does not yet report V. Claude-lane prep is complete and turnkey;
the terminal build is Codex's + compute's by the goal's own design.
