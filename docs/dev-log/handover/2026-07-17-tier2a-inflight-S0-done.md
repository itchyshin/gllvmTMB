# In-flight handover — Tier-2a phylo-multinomial: S0 done, build blocked on classifier outage

**Date:** 2026-07-17 · **From:** Claude (Fable 5). Session goal is SET (the Design 84 build).
This captures mid-flight state so nothing is lost while the `claude-opus-4-8` safety classifier is
intermittently down (it gates Bash/`gh`/Agent/Workflow/MCP-writes; file Read/Write/Edit still work).

## 🎯 One-command resume
```
claude "Rehydrate from docs/dev-log/handover/2026-07-17-tier2a-inflight-S0-done.md and the plan
docs/dev-log/2026-07-17-tier2a-ultra-plan-DRAFT.md. If the classifier outage has cleared: (1) merge
PR #752 (squash), hold PR #751; (2) create a fresh arc branch off main
(claude/tier2a-phylo-multinomial), move the two DRAFT files onto it; (3) start S1 grammar wiring."
```

## Done this session (Claude lane, no Bash needed)
- **S0 COMPLETE.** Identification convention **PINNED**: fix the latent-scale residual to
  `R = (1/K)·(I + J)` on the (K−1) contrasts (spike `dev/phylo-multinomial-spike.R:60-63`; MCMCglmm
  categorical convention; supersedes Design 84 §7's "identity vs 0.5/0.25"). Scale reconciliation
  written (ultra-plan §S0(b)): gllvmTMB must adopt the identical residual; MCMCglmm is the
  apples-to-apples reference, brms is scale-checked secondary.
- **Plan revised** (`docs/dev-log/2026-07-17-tier2a-ultra-plan-DRAFT.md`) after a self-critique the
  maintainer accepted: added the **consistency ladder** as the load-bearing recovery gate; S2 split
  into S2a/S2b; added backward-compat + print/summary + sample-size-fence slices.
- **S4a harness DRAFTED**: `dev/phylo-multinomial-harness-DRAFT.R` — generalises the spike into the
  N=800/1600/3200 consistency ladder (bias ± MCSE; verdict under-power vs asymptotic bias). Untracked
  DRAFT; move to the arc branch.
- **S2 Codex brief WRITTEN**: `docs/dev-log/handover/2026-07-17-tier2a-S2-codex-build-brief-DRAFT.md`
  — turnkey spec for the live TMB build (Codex owns it).

## 🔴 CARRIED-OVER (blocked on the classifier outage — retry when it clears)
1. **Merge PR #752** (Design 84 scoping) squash; **hold PR #751** (multinomial article) until the arc
   lands (maintainer decision — the article gets the full picture in one pass afterward).
2. **Create the fresh arc branch off `main`** and move the two DRAFT files onto it (keep them OFF
   `claude/release-0.5.0`, which is where they currently sit untracked).
3. **S1 grammar wiring** (Claude, pure-R): admit `latent()`/`phylo_latent()` on a multinomial trait →
   K−1 category-contrast pseudo-traits. **Code-map so far (via Read, no grep):** the `multinomial()`
   family lives in `R/families.R` (class `c("multinomial","family")`, arg `baseline=`), and its own
   docstring names the fence S1 opens — "latent()/unique()/indep()/phylo_*()/spatial_*()/random
   slopes/cluster on a multinomial trait are not supported, because an unordered categorical response
   spans K−1 latent liability dimensions rather than one (Design 83)." S1 replaces that guard with the
   factor decomposition. **Still need (grep, needs a Bash window):** the exact file:line of that guard,
   the latent/phylo_latent parser, `extract_Sigma`/`extract_correlations`, and the TMB softmax block.

## Pipeline map (via Read of the arc worktree, no grep) — S1 turnkey pointers
- Arc branch **created**: `/tmp/gtmb-tier2a` on `claude/tier2a-phylo-multinomial` off `origin/main`
  (`aeee1bd2`, has the multinomial base). Read/Edit it directly (both work under the Bash outage).
- Entry: `R/gllvmTMB.R`, `gllvmTMB()` (roxygen 1–431; signature 432–459+). The **multivariate engine's
  supported-family list** (roxygen lines 117–153) deliberately **omits `multinomial()`** — that omission,
  plus the `multinomial()` docstring guard, is the fence S1 opens.
- Covstruct terms (`latent()`/`phylo_latent()`/…) are "processed by extending the formula parser and the
  TMB template" (Details ~line 279). `extract_Sigma()` is the "unified post-fit covariance API" (S3 target).
- **S1 change:** admit `multinomial` into the covstruct engine's family gate, and map a multinomial trait
  to K−1 category-contrast pseudo-traits so `phylo_latent()` loadings attach per contrast. Still need the
  exact validator line (grep when Bash returns) + the parser file for `phylo_latent`.
- **DISCIPLINE:** S1 is a formula-grammar change (Discussion Checkpoint) — do NOT commit untested edits;
  wire + `devtools::test()` together when Bash/R are back.

## S1/S3 EXACT EDIT POINTS (mapped via Read; turnkey — fid-16 = `family_id_vec == 16L`)
- **S1 fence** — `R/fit-multi.R:1793`:
  ```r
  if (any(family_id_vec == 16L) &&
      (use_lv_B || use_rr_B || use_diag_B || use_spde ||
       use_phylo_rr || use_phylo_slope || use_re_int)) { cli_abort(... Tier-1 ...) }
  ```
  S1 relaxes this to PERMIT the phylo-factor path (`use_phylo_rr` = `phylo_latent`) on a multinomial
  trait, while still rejecting the genuinely-unsupported combos. The multinomial trait maps to K−1
  category-contrast pseudo-traits; `phylo_latent` loadings attach per contrast; residual fixed to
  `R=(1/K)(I+J)` (S0). The K−1 pseudo-trait representation + softmax coupling is the **S2 (TMB, Codex)**
  depth; S1 is the R-side gate + parser wiring.
- **S3 fences** — `R/extract-sigma.R:629-636` and `R/extract-correlations.R:439-446`: both `cli_abort`
  on `family_id_vec == 16L`. S3 replaces the abort (gated on a Tier-2a phylo-factor multinomial fit,
  NOT merely family==16) with the reduced-rank `V ≈ ΛΛᵀ+diag(ψ)` return on the S0 scale. `extract_Sigma`
  def at `R/extract-sigma.R:584`; `extract_correlations` def at `R/extract-correlations.R:392`.
- Sparse A⁻¹ engine: `R/phylo-tree-precision.R`. Multi-trait engine: `R/fit-multi.R` (family list @287).

### ⚠️ Sequencing correction (found while mapping the fence)
The `fit-multi.R:1793` fence is **load-bearing, not cosmetic**: it exists *because* the engine has no
K−1 category-contrast representation for a multinomial trait. **Opening it (S1) before S2 builds that
TMB representation would admit a silently-broken model.** So S1's fence-relaxation is **coupled to S2
(Codex/TMB)** — do NOT relax it blind ahead of S2. Revised Claude-lane S1 = the parser wiring that
represents the multinomial trait as K−1 pseudo-traits + prepares (but does not yet flip) the fence;
the fence opens together with S2's TMB softmax + phylo-factor loadings. This is why the arc is
Codex-led, and why untested blind S1 edits are the wrong move.

## ⚠️ CRITICAL: build off `main`, NOT `claude/release-0.5.0`
This working branch **predates the multinomial merge** (`aeee1bd2`) — `R/families.R` here has NO
`multinomial()`. The arc branch MUST be cut off `main`. The PR #752 worktree
(`.claude/worktrees/lane-c-multinomial`, branch `docs/tier2a-phylo-multinomial-scoping`) DOES have the
multinomial base and is a safe place to Read the post-merge code from without Bash.

## Then (Codex + compute)
S2a/S2b live TMB build → S3 reporting → S4b Totoro consistency-ladder campaign → S5 docs/fence flip +
sample-size fence → Rose after-task. Compute local→Totoro, never GitHub Actions (D-50).

## Maintainer decisions locked (Design 84 §7)
Residual scale = spike's fixed `(1/K)(I+J)`, default-fixed; factor rank = fixed small `d` first;
scope = standalone per-trait `V` first, cross-trait fenced; Julia parity = later arc.
