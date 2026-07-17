# Handover — Claude → Claude: multinomial arc CLOSED; next lane = Tier-2a phylogenetic multinomial

**Date:** 2026-07-17 · **From:** Claude (Fable 5). **The `multinomial()` arc is DONE and MERGED to
`main`.** The real next arc — a **phylogenetic multinomial GLMM** (Design 84) — is scoped, spike-
validated, and wants its **own fresh lane** (it is a Discussion-Checkpoint likelihood change: random
effects on a categorical trait). Do NOT start the build without maintainer sign-off.

## 🎯 One-command resume (paste in an authenticated terminal, repo root)
```
claude "Rehydrate from docs/dev-log/handover/2026-07-17-claude-handover-tier2-phylo-multinomial.md,
then STOP for maintainer sign-off before starting the Tier-2a build (Design 84)."
```

## Mission control (all landed — nothing carried over)
| thread | branch / PR | state |
|---|---|---|
| `multinomial()` → FAM-20 `covered` | PR #749 | **MERGED to `main`** (`aeee1bd2`), CI green |
| Article "Unordered categories with `multinomial()`" | PR #751 (`docs/multinomial-article`) | OPEN — maintainer read pending |
| Design 84 (Tier-2a phylo multinomial) scoping + spike + this handover | PR #752 (`docs/tier2a-phylo-multinomial-scoping`) | OPEN — maintainer review |
| Feasibility spike (`dev/phylo-multinomial-spike.R`) | in PR #752 | validated — N=800 recovers ρ 0.6→0.45; N=250 under-powered |
| Compound-back brain note (Mizuno 2025 ↔ Design 84 ↔ notebook) | `~/shinichi-brain/projects/gllvmTMB/` | **FILED** |
| Full 23-commit multinomial history | `agent/lane-c-multinomial` | pushed (archival) |

**Next lane = the Tier-2a build (Design 84).** It is a Discussion-Checkpoint likelihood change
(random effects on a categorical trait) → **maintainer sign-off before any code.**

## What shipped this session
- **`multinomial()` promoted FAM-20 `partial` → `covered`**: `baseline=` arg, calibrated seed-robust
  recovery (`dev/multinomial-recovery.R`), `extract_Sigma()` typed abort, NEWS. **PR #749 MERGED**
  (`aeee1bd2`), CI green.
- **Article** *"Unordered categories with `multinomial()`"* — **PR #751 open** (`docs/multinomial-article`).
- **Design 84 (Tier-2a phylo multinomial) scoping — PR #752 open** (`docs/tier2a-phylo-multinomial-scoping`):
  `docs/design/84-phylogenetic-multinomial-tier2.md` + `dev/phylo-multinomial-spike.R`.
- Full 23-commit multinomial history on `agent/lane-c-multinomial` (pushed).

## The next arc — phylogenetic multinomial GLMM (Design 84)
Real solution (grounded: brain + NotebookLM 100-source deep research; anchored on
**Mizuno, Drobniak, Williams, Lagisz & Nakagawa 2025, JEB `10.1093/jeb/voaf116`**). Notebook:
`https://notebooklm.google.com/notebook/1fc6ce06-dff7-41a8-8832-9662c4362622`.
- Softmax + phylo RE with **Kronecker `G = V ⊗ A`**; `V` = the (K−1)×(K−1) among-category covariance.
- **gllvmTMB's home turf:** the scalable form is a phylo **factor** model `V ≈ ΛΛᵀ + diag(ψ)` = exactly
  `phylo_latent()` on the K−1 category contrasts. The shipped fid-16 softmax is the correct base.
- **Identification (load-bearing):** FIX the latent-scale residual by convention (do not estimate).
- Binary reductions (continuation-ratio / one-vs-rest) are **retired** — break permutation invariance.

**Spike verdict (`dev/phylo-multinomial-spike.R`, MCMCglmm reference):** pipeline runs end-to-end;
**among-category phylo correlation recovers at N=800 (ρ 0.6 → 0.45, PASS)** but **NOT at N=250**
(under-power, not the model). ⇒ the build is sound but **data-hungry** — the arc needs power-
calibrated validation + careful latent-scale handling, NOT a quick reuse of `phylo_latent`. Run more:
`Rscript dev/phylo-multinomial-spike.R <N> <nitt>`.

**Build plan (Design 84 §5):** (1) fid-16 likelihood exists; (2) allow `phylo_latent()` on a
multinomial trait's K−1 pseudo-traits (category loadings on shared phylo factors, sparse A⁻¹ engine);
(3) FIX the latent-scale residual; (4) `extract_correlations()`/`extract_Sigma()` return the reduced-
rank `V`; (5) validate vs MCMCglmm `categorical`+`ginverse` and brms `categorical`+`gr(cov=A)`.
**Open decisions (Design 84 §7):** residual-scale convention; factor rank; standalone-`V` first vs
cross-trait integration.

## CARRIED-OVER: none
All session work is landed (PRs #749 merged / #751 / #752; spike; brain note filed; this handover).
The next session starts clean — nothing to finish first, just the sign-off gate below.

## Guards
- Tier-2a = **Discussion Checkpoint** (likelihood/family change) → maintainer sign-off before code.
- Julia parity is a later arc. Any recovery/coverage/power campaign: local first, then Totoro/DRAC —
  never GitHub Actions (D-50).
- Housekeeping: a stray duplicate of the FIRST draft of this handover was written to the MAIN worktree
  path (`<repo>/docs/dev-log/handover/2026-07-17-...`, untracked on `claude/release-0.5.0`); delete it
  — the canonical copy is this one, in PR #752's branch.
