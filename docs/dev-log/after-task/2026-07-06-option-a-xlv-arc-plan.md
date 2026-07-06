# After-task: Option A structured × X_lv (phylo) arc — execution plan + S1 alignment contract (2026-07-06)

Session as **Ada**, named lenses (Noether/Fisher on S1; Boole/Gauss/Emmy/Curie referenced in
the plan; **Rose** claim-audit). Followed the `ultra-plan` + `symbolic-alignment` disciplines.
All grounding verified by **file ground-truth** (4 read-only probes), not self-reports.

## Scope

Picked up the 2026-07-06 handover (reconciliation-stabilization CLOSED). Mandate: **ultra-plan
the Option A arc** — Gaussian `phylo_latent(0+trait|species, d=K, lv=~x)`, predictor-informed
latent betas under phylogeny (Design 76 §7 decision) — and **stop at the plan for maintainer
sign-off before any engine code**. Maintainer chose the session goal mid-stream: **plan + the
ungated S1 alignment table**; park before S2/S3.

## Outcome

- **PR #718 merged** (`13686230`) — prior stabilization session closed on `main`.
- **Execution plan** written and Rose-audited: `docs/dev-log/2026-07-06-option-a-xlv-phylo-execution-plan.md`.
- **S1 alignment contract** written (ungated, doc-only): `docs/dev-log/2026-07-06-xlv-phylo-S1-alignment.md`.
- **No engine code, no grammar change.** `phylo_*(lv=~x)` stays fail-loud; `LV-08` stays `blocked`.
- Arc **PARKED** pending the maintainer authorization decision (unchanged default).

## Key findings (grounding corrected Design 76's pre-merge assumptions)

1. **Profile "hero" CI for `B_lv` is ABSENT in source** — resolves the item Design 76 §5/§7
   flagged UNVERIFIED. Fix-and-refit profile machinery exists for ρ/communality/repeatability
   (`R/profile-derived.R`, `profile-route-matrix.R`, `profile-targets.R`) but there is **no
   `B_lv`/`alpha_lv` route and no Self–Liang boundary code**. The gate's mandated method is a
   **build slice (S5a)**, not an existing capability. Biggest scope surprise.
2. **Score-mean attaches to the PHYLO tier**, not the ordinary B tier: estimand
   `B_lv_phy = Λ_phy·α_lv_phy^T`, innovation reuses the existing `g_phy` + `Ainv_phy_rr` GMRF
   machinery (byte-identity for free when `use_lv_phy==0`).
3. **Extractor must key off the new `use_lv_phy`/`B_lv_phy`, not the unrelated `phylo_slope`**
   surface (a different arc — Design 76 §1).
4. Verified `main` anchors for all four surfaces (parser guards, TMB template, extractor, ADEMP
   harness) — Design 76's line citations predated the 43-conflict merge.

## Checks run

- Grounding: 4 read-only `Explore` probes (parser / TMB / extractor / ADEMP) against `main`
  @ `13686230`; every file:line anchor in the plan + S1 traces to confirmed source.
- **Rose claim-audit** of the plan: no over-claims; every non-Gaussian/other-source/augmented-LHS/
  REML `lv` rejection preserved in S2; `LV-08` honest; population-`B_lv` target never weakened to
  a realized `eta`-scale target; PR #127 reopen framed as a coupled maintainer decision; brain
  items (D-12, #715) cited + UNVERIFIED-marked. One [FIX] applied (§3.1 sequencing framed as
  awaiting maintainer decision, not a default).
- S1 rotation algebra self-verified by hand (`Λ_phy→Λ_phy R^T`, `α→α R^T` ⇒ `B_lv` invariant;
  innovation law `MN(0,A⊗I_K)` rotation-stable). Reduction predicates stated as future S3 tests
  (not yet run — no engine code this pass).

## Follow-ups (non-blocking; maintainer's call)

- **🔴 Authorization gate (Needs Shinichi):** authorize S2 (grammar) + S3 (HIGH-RISK TMB
  likelihood) + the coupled GLLVM.jl **PR #127** reopen, or stay parked. Nothing downstream of
  S1 proceeds without it.
- **Sequencing decision (if authorized):** profile-first vs. staged (Wald/bootstrap first,
  profile follows, "profile pending", `LV-08` not promoted until profile lands) — §3.1.
- **#717** (method="profile" `extract_correlations` warning storm) remains open, non-blocking;
  adjacent to S5a's profile machinery but separate.
- Stray `scratchpad_enum_results.txt` in repo root still present (untracked); left in place per
  the no-hard-delete discipline.

## Guards honored

- No likelihood / grammar / TMB / family change — plan + S1 are design-only; grammar stays
  fail-loud; no capability promoted; `LV-08` stays `blocked`.
- Sub-agent output verified by file ground-truth, not self-reports.
- Maintainer-authorization gate surfaced (not self-approved); R and Julia doors move only
  together and only on maintainer authorization.
- Stopped at the plan for sign-off, exactly as the handover mandated.
