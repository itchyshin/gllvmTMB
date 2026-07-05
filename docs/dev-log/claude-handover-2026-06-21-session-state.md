# Claude session-state note — 2026-06-21 (for the next Claude session)

Repo is authoritative — rehydrate from git/gh. Working repo: `gllvmTMB`,
`origin/main = a16611b`. Speak as **Ada**; use named perspectives.

## Done this session — `latent_*`-only migration (landed + handed to Codex)

- **#518 merged** — `latent(residual=)` → `latent(unique=)` (soft-deprecated
  `residual=` alias kept; internal marker `.auto_residual` → `.auto_unique`).
- **#519 merged** — `phylo_latent()` folds its diagonal `Psi_phy` by default
  (`unique=`); **#516 closed** (superseded).
- **#520, #521 merged** — Codex handover refresh + kickoff doc.
- **The Codex team now owns the migration continuation** (spatial_latent → animal →
  kernel → augmented `phylo_latent(1+x|sp)` → Stage B). Full handover:
  `docs/dev-log/codex-handover-2026-06-21-latent-migration.md`; kickoff:
  `docs/dev-log/codex-kickoff-2026-06-21.md`. **A new Claude session should NOT
  duplicate that lane — it is Codex's.**

## OPEN THREAD to pick up — `Ayumi-495/urbanisation_map` issues #1 & #3

- **#3** "Improve `check_gllvmTMB()` diagnostics for large loadings in near-universal
  binary indicators" (to @itchyshin) — a real, well-diagnosed gap. Near-universal
  binary under probit → quasi-separation → runaway loading (`|lambda|`≈14);
  `max_fixed_se` (threshold 100) does not fire (intercept SEs stay finite);
  `boundary_flags` catches near-**zero** loadings but **not runaway-large** ones (the
  asymmetry); `weak_axis_unit`'s "lower rank" action is the wrong remedy here.
  **Confirmed in `R/diagnose.R`: no loading-magnitude / prevalence / separation gate
  exists.**
- **#1** "Exploratory quantitative evidence map (GLLVM) - v1" — careful exploratory
  report (43 binary indicators, `traits(...) ~ 1 + latent(1 | review, d = 2)`,
  binomial probit; `d=2` after `d=3` degenerate; region dropped on ΔAIC≈980;
  lift-based gap analysis; porting to `galamm` for publication; flagged a `galamm`
  0.4.0 bug that silently ignores `link=`). Methodologically sound; lead gap claims on
  lift, not residual correlations.
- **Connection:** #3's failure mode is a QC gate for #1's pipeline (the 79→43
  indicator screen should drop near-universal items; a survivor could inflate a
  spurious "breadth" axis in the ordination).
- **My recommendation (pending the maintainer's go):**
  1. **Transfer/mirror #3 to `itchyshin/gllvmTMB`** (the one-ledger rule — issues live
     where the code lives).
  2. Implement a small **additive `check_gllvmTMB()` slice**: a separation gate via
     **fitted-probability saturation (link-invariant)** and/or `|lambda|`
     robust-relative-to-spread (NOT a fixed cutoff — link-scale-dependent: logit
     loadings ≈1.6–1.8× probit); for binomial families surface **per-trait
     prevalence**, and on extreme prevalence + large loading change the action to
     "remove or re-code the near-constant indicator; lowering rank will not help";
     make `weak_axis_unit`'s action conditional. No engine/likelihood touch.
- **Status:** I asked the maintainer "(a) draft the #3 transfer and/or (b) sketch the
  `check_gllvmTMB()` enhancement?" — **not yet answered.** Resume here: confirm which,
  then act.

## Guards still in force

- Grammar / engine / diagnostics merges need **explicit maintainer "yes merge."**
- **Run the FULL `devtools::check()` before any push** (the #516 trap — equivalence
  breakages can live outside the files you touched).
- **Never `git add -A`** — stage by name. Do not revert Codex/human work.
- **Do not touch** the dirty `codex/r-bridge-grouped-dispersion` checkout.
- Local `glmmTMB::equalto` (TMB 1.9.17-vs-1.9.21 mismatch — reinstall glmmTMB) and the
  Apple-clang `-Wfixed-enum-extension` header note in `devtools::check()` are
  **env-only, not branch** — absent on Linux CI.
- Today's worktrees mostly pruned; the dirty `codex/...` and a few prior-session
  `/private/tmp/gllvmtmb-*` worktrees remain (harmless clutter).
