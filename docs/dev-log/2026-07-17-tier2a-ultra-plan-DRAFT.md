# Ultra-Plan — Tier-2a phylogenetic multinomial GLMM (Design 84) — DRAFT for maintainer sign-off

**Date:** 2026-07-17 · **Status:** PLAN ONLY — no code. Discussion-Checkpoint likelihood change
(random effects on a categorical trait) → maintainer sign-off gates the build.
**Blueprint:** `docs/design/84-phylogenetic-multinomial-tier2.md` (PR #752).
**Base already shipped:** `multinomial()` FAM-20 `covered` (fid-16 softmax), merged `main` `aeee1bd2`.

---

## 🎯 GOAL (paste to set a fresh session goal)
```
Solo platform: primarily CODEX (owns the live TMB build, MCMCglmm/brms reference fits, and the
Totoro compute campaign); Claude plans, wires pure-R grammar/reporting, writes prose, runs
pure-logic tests. Deliverable: gllvmTMB reports the (K−1)×(K−1) among-category correlation
surface V for a multinomial trait — standalone per-trait first, with a phylogenetic version —
via a phylo FACTOR decomposition V ≈ ΛΛᵀ + diag(ψ) on category-contrast pseudo-traits, reusing
the shipped fid-16 softmax + phylo_latent() + sparse A⁻¹ engine. HEADLINE (the one leverage item):
FIX THE LATENT-SCALE RESIDUAL BY CONVENTION (Design 84 §3) — the model is non-identified in scale
and every downstream slice depends on this being pinned, not estimated. IN PARALLEL: the validation
harness (DGP + MCMCglmm/brms reference fits + power calibration) is independent of the gllvmTMB
implementation and can be built alongside the grammar/likelihood work. DEFER + FENCE: cross-trait
integration (a multinomial trait correlating with 1-dim traits) — needs a K−1↔1-dim mixing
convention; ship standalone V first and keep cross-trait fenced. Julia parity is a later arc.
DISCIPLINE: recover a KNOWN V within the spike-calibrated band before any "covered" claim (spike:
N=800 recovers ρ 0.6→0.45; N=250 under-powered → validation is power-calibrated, not single-n);
compute local→Totoro/DRAC, NEVER GitHub Actions (D-50); close with Rose after-task + handover.
```

---

## Context (from the prior-work sweep — nothing to rebuild)
- **Likelihood base EXISTS:** fid-16 grouped baseline-category softmax (Design 83). Correct base.
- **Factor machinery EXISTS:** `phylo_latent()` gives `Σ = ΛΛᵀ + diag(ψ)`; sparse `A⁻¹` phylo
  precision + AD/Laplace are core gllvmTMB.
- **Spike VALIDATED (PR #752):** phylo multinomial with known among-category `ρ=0.6` recovered to
  `0.45` at `N=800`; `N=250` under-powered → **the model works but is data-hungry**.
- **Brain filed:** `mizuno-et-al.-2025-phylogenetic-multinomial-glmm-jeb` + "real Tier-2 route
  (factor model)" note. NotebookLM provenance notebook `1fc6ce06-dff7-41a8-8832-9662c4362622`.
- **Methods reference:** Mizuno, Drobniak, Williams, Lagisz & Nakagawa (2025), *JEB*,
  `10.1093/jeb/voaf116`.
- **The gap is only the wiring** — see slices below.

## SEARCH
NotebookLM notebook `1fc6ce06` (100 sources, Mizuno-anchored) — DONE. Tier-b academic search
offered? Already run this arc; no new search needed unless the residual-scale convention needs a
targeted lit pull.

---

## SLICE TABLE

| Slice | What | Member / lens | Model + effort | Owner platform | Time | Dep |
|---|---|---|---|---|---|---|
| **S0** | Identification spec: (a) READ `dev/phylo-multinomial-spike.R` and pin the EXACT fixed R-structure it validated against (identity vs 0.5/0.25) as the default; (b) **estimand/scale reconciliation** — write down the scale on which ρ is reported under the fixed residual, and confirm it matches how MCMCglmm/brms report ρ, so cross-checks are apples-to-apples | statistical-reviewer / gauss | **Fable/Opus · high** | Claude (spec) | ~0.5 sess | maintainer decision #1 |
| **S1** | Grammar wiring: admit `latent()`/`phylo_latent()` on a multinomial trait → K−1 category-contrast pseudo-traits, loadings λⱼ on shared zᵢ; **preserve backward-compat with the shipped fixed-effects `multinomial()`** (no RE term = unchanged behaviour) | r-package-engineer | **Sonnet · medium** | Claude (pure-R parser) | ~1 sess | S0 |
| **S2a** | TMB core: connect pseudo-trait loadings to fid-16 softmax + sparse `A⁻¹` on zᵢ; ENFORCE the fixed residual scale in the objective (the AD/Laplace core) | julia-porter/TMB + statistical-reviewer | **ceiling — Fable/Opus high; live build = Codex Sol** | **Codex** (live TMB) | ~1 sess | S1 |
| **S2b** | Optimizer/AD robustness: starting values, convergence checks, a Laplace-failure fallback + a loud non-convergence signal (do not silently return NA) | TMB + statistical-reviewer | **Codex Sol/Terra · high** | **Codex** (live TMB) | ~0.5–1 sess | S2a |
| **S3** | Reporting: `extract_correlations()`/`extract_Sigma()` return reduced-rank `V ≈ ΛΛᵀ+diag(ψ)` (+ phylo version) on the S0-reconciled scale; `print`/`summary` methods for the new V surface | r-package-engineer | **Sonnet · medium** | Claude/Codex | ~0.5 sess | S2a |
| **S4a** | Validation harness (PARALLEL): DGP for known `V` + phylo signal; MCMCglmm `categorical`+`ginverse` and brms `categorical`+`gr(cov=A)` reference fits on a shared toy set | simulation-design + statistical-reviewer | **Sonnet · medium; live fits = Codex Terra** | Codex (live R) | ~0.5 sess ∥ S1/S2 | S0 |
| **S4b** | Power-calibrated recovery campaign + **consistency ladder** (see VERIFY): run gllvmTMB through S4a across N = 800/1600/3200; distinguish under-power (estimate climbs toward truth) from asymptotic bias (plateaus below truth); reproduce spike `V`; cross-check refs | statistical-reviewer verify | **Totoro run + Fable/Opus verify** | Codex (compute) | overnight wall-clock | S2a, S2b, S3, S4a |
| **S5** | Docs/NEWS + fence flip: Design 84 status→built, `extract_*` docs, NEWS, flip the fence that declines the multinomial `V` table; **sample-size-guidance fence** (method is data-hungry — N≈800 to recover ρ; typical phylo n=100–300 is thin); article para | manuscript-editor + prose-style-review; Rose claim-gate | **Sonnet · medium; Rose/Opus gate** | Claude | ~0.5 sess | S3, S4b |
| **V** | Verify + consolidate: consistency ladder passed, refs agree on the reconciled scale, `R CMD check` clean, Rose after-task + handover | Rose + statistical-reviewer | **Fable/Opus · high** | either | ~0.5 sess | all |

## STRUCTURE
- **Sequential spine:** S0 → S1 → S2a → S2b → S3 (likelihood-build pipeline; each needs the prior's output).
- **PARALLEL arm:** S4a (harness + reference fits + DGP) runs alongside S1/S2 — it depends only on
  S0's convention + Design 84, not on the finished gllvmTMB build.
- **Gated tail:** S4b (compute campaign) after S2+S3+S4a; S5 fence-flip gated on S4b evidence
  (docs skeleton can start earlier, but the *claim* waits on recovery).

## MODELS (roster checked live 2026-07-17)
Agent tool exposes `haiku · sonnet · opus · fable`; this session is **Fable 5** (current top tier).
Routing: scout/mechanical → Haiku; build/default → Sonnet; hardest/verify/claim-gate → Fable/Opus.
Codex owns live TMB/R (Terra default, Sol for the hard S2 core), per the durable division of labour.

## ESTIMATE
**Not one session — needs a handoff chain.** ~4 focused build sessions (S2 now split into S2a core +
S2b optimizer-robustness) + one overnight Totoro recovery/consistency-ladder campaign, mostly
**Codex-owned** for the live TMB/fit/compute parts. **R-side first; Julia (GLLVM.jl) parity is a later
arc** (maintainer, 2026-07-17). Fan-out is modest (deep pipeline, not a wide sweep): 1–2 sub-agents per
slice, most value in S0 (pin the convention + scale) and S4b (prove recovery is real, not attenuated).

## PLAN REVIEW (before any execution)
- **Rose** — scope/claims: is "standalone V first, cross-trait fenced" the right cut? does the
  slice list overclaim?
- **statistical-reviewer** — the method: is fixing the residual scale by convention actually
  sufficient for identification here, and does the factor route (`ΛΛᵀ+diag(ψ)`) recover `V` faithfully
  rather than an artefact of the rank choice? This critique runs on the PLAN, before code.

## VERIFY — the consistency ladder is the load-bearing gate
The spike recovered ρ=0.6 as **0.45** at N=800 (and ~0 at N=250). "Within a calibrated band" is NOT a
sufficient gate on its own — 0.45 could be finite-sample under-power OR asymptotic bias (scale mismatch
from the fixed residual convention). **Gate before any `covered` claim:**
1. **Consistency ladder** — run recovery at **N = 800, 1600, 3200** (Totoro). If the estimate climbs
   toward 0.6 → it's under-power (acceptable; carry the sample-size fence into docs). If it **plateaus
   below 0.6 → asymptotic bias**: STOP, fix the estimand/scale (S0) before claiming recovery.
2. **Scale-matched cross-check** — vs MCMCglmm + brms on the S0-reconciled scale (§S0(b)); agreement is
   only meaningful once all three report ρ on the same scale.
3. `R CMD check` clean; Rose after-task report + Claude→Codex/Claude handover.
**Compute local→Totoro/DRAC, NEVER GitHub Actions (D-50).** Smoke-first: 1 tiny fit proving non-NA,
in-range `V` before any full campaign.

## CONSOLIDATE
Update Design 84 status, `extract_*` docs, NEWS, the fence; file the after-task report in
`docs/dev-log/after-task/`; update the brain note with the recovered-`V` result; refresh the
capability widget (FAM-20 multinomial: add the RE/phylo tier).

---

## Progress (2026-07-17, classifier-outage constrained)
- **S0 DONE** (Claude): residual convention pinned to `R=(1/K)(I+J)`; scale reconciliation written (§S0(b)).
- **S4a DRAFTED** (Claude): `dev/phylo-multinomial-harness-DRAFT.R` — the consistency-ladder harness
  (generalises the validated spike; implements the load-bearing recovery gate). Move to the arc branch.
- **S2 Codex brief WRITTEN**: `docs/dev-log/handover/2026-07-17-tier2a-S2-codex-build-brief-DRAFT.md` — turnkey.
- **BLOCKED on the classifier outage (Bash gated):** create fresh arc branch, merge #752, S1 grammar edits,
  live code-map. **BLOCKED on Codex/compute:** S2a/S2b TMB build, S4b Totoro campaign.

## Revision log
- **2026-07-17 (rev 1):** tightened after a self-critique the maintainer accepted — (1) added the
  **consistency ladder** as the load-bearing recovery gate (0.6→0.45 must be proven under-power, not
  bias); (2) S0 now pins the EXACT spike R-structure + owns estimand/scale reconciliation; (3) split
  S2 → S2a core / S2b optimizer-robustness and added backward-compat + print/summary + sample-size
  fence slices. Adversarial multi-agent critique **waived** by maintainer (self-critique sufficient).

## ✅ RESOLVED DECISIONS — maintainer, 2026-07-17 (Design 84 §7)
All three settled; recorded here so S0 starts from a fixed spec. **Cleared to START S0/S1 (R-side spec +
grammar)** — these are reversible spec/parser work; the consistency-ladder gate (VERIFY) protects the
far-end `covered` claim, so starting the build does not commit to a possibly-biased method.
1. **Residual-scale convention** → **anchor to the spike's fixed R-structure; expose as an advanced
   arg but default-fix it** (do not estimate). Keeps cross-checks aligned with the reference.
   **PINNED (S0(a) done, 2026-07-17):** the validated spike (`dev/phylo-multinomial-spike.R:60-63`)
   fixes the residual to **`R = (1/K)·(I + J)`** on the (K−1)×(K−1) category contrasts (`I` identity,
   `J` all-ones; `fix=1`) — the standard MCMCglmm categorical residual, reflecting the correlation
   induced by differencing against the shared baseline. For K=3 that is 0.667-diag / 0.333-offdiag.
   **This supersedes Design 84 §7's "identity vs 0.5/0.25" wording.** gllvmTMB must adopt the identical
   residual so its reported `V`/ρ lives on the same scale as the MCMCglmm reference (S0(b)).
2. **Factor rank policy** → **fixed small `d` first** (full `V` only for small K); reuse the existing
   latent-rank selection in a later slice. Simplicity first.
3. **Scope** → **standalone per-trait `V` first; fence cross-trait** until a K−1↔1-dim mixing
   convention exists. The factor route makes standalone clean.

## S0(b) — estimand/scale reconciliation (done 2026-07-17)
The reported ρ is **scale-dependent on the fixed residual**, so the three tools are comparable ONLY on
a shared scale. Canonical reporting scale = the **`R = (1/K)·(I + J)` latent scale** (S0(a)).
- **MCMCglmm** (reference): ρ = `V₁₂/√(V₁₁V₂₂)` from the `us(trait):species` G-structure, on the fixed
  `(1/K)(I+J)` residual scale. This is the number the spike reports and gllvmTMB must reproduce.
- **gllvmTMB** (build): `phylo_latent` gives `V = ΛΛᵀ + diag(ψ)` on the K−1 baseline-category
  contrasts. To match, it must (i) use the **same baseline-contrast coding**, (ii) **fix the same
  residual** `(1/K)(I+J)` — NOT identity, (iii) report ρ from the same `V` normalization. `extract_*`
  docs must state the residual convention the reported `V` is conditioned on.
- **brms** `categorical` + `gr(cov=A)`: reports the correlation of the category random effects, but its
  implicit categorical residual handling differs — **do NOT assume scale-match; the S4b cross-check
  must verify it**, and if brms sits on a different implicit scale, compare ρ only after rescaling.
Net: adopt `(1/K)(I+J)` as the canonical reporting scale; MCMCglmm is the apples-to-apples reference,
brms is a scale-checked secondary.

## Guards
- New arc = Discussion Checkpoint (likelihood/family change) → **maintainer sign-off before code.**
- Binary/continuation-ratio reductions are **retired** (break permutation invariance for unordered
  categories) — do not resurrect them as a shortcut.
- Julia parity is a later arc.
