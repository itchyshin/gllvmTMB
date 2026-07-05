# Recovery Checkpoint: spatial_latent Psi Fold Blocker

Date: 2026-06-21 13:29:58 MDT
Agent: Codex / Ada
Worktree: `/private/tmp/gllvmtmb-spatial-latent-psi-fold`
Branch: `codex/spatial-latent-psi-fold-20260621`
Base: `origin/main` at `a16611b`

## Current State

The worktree was created fresh from `origin/main` after fetch. The
mission-control checkout on `codex/r-bridge-grouped-dispersion` was
dirty and was not touched.

Expected changed files in this worktree:

- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-21-spatial-latent-psi-fold-blocker.md`
- `docs/dev-log/recovery-checkpoints/2026-06-21-132958-codex-spatial-latent-blocker.md`

No R, C++, tests, roxygen, generated Rd, vignette, README, NEWS,
ROADMAP, or pkgdown files were edited.

## Commands Already Run

- `git fetch --all --prune`: completed.
- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,author,url`: returned `[]`.
- `git log --all --oneline --since="6 hours ago"`: checked for shared-rule-file collision before dev-log edits.
- Pruned clean merged `/private/tmp/gllvmtmb-*` worktrees.
- `git worktree add -b codex/spatial-latent-psi-fold-20260621 /private/tmp/gllvmtmb-spatial-latent-psi-fold origin/main`: completed.
- `rg -n "spde|spatial_unique|spatial_latent|use_spde|spatial_diag|spde_diag|auto_unique|is_auto_.*psi|auto_unique_off_family" R/fit-multi.R R/brms-sugar.R src/gllvmTMB.cpp tests/testthat`: confirmed split SPDE paths and no spatial auto-Psi machinery.
- `rg -n "Sigma_spde|Lambda_spde|log_tau_spde|omega_spde|spatial_latent.*unique|spatial_unique.*latent|spde_lv_k" R/extract-sigma.R R/extract-correlations.R R/output-methods.R R/check-consistency.R tests/testthat`: confirmed extractor/test mismatch around additive diagonal spatial Psi.
- `gh issue list --repo itchyshin/gllvmTMB --state open --search "spatial_latent OR spatial_unique OR latent unique" --limit 20 --json number,title,url,state`: no dedicated spatial-fold blocker issue found.

Two `Rscript --vanilla -e 'devtools::load_all(".", compile = FALSE,
quiet = TRUE); ...'` parser probes were interrupted after remaining
silent for more than two minutes. No result from those probes should be
used as evidence.

## Finding

Blocker before coding: current SPDE machinery branches between:

- per-trait path: `spde_lv_k == 0`, `omega_spde`, `log_tau_spde`,
  used by `spatial_unique()` / `spatial_scalar()`; and
- low-rank path: `spde_lv_k >= 1`, `Lambda_spde`, `omega_spde_lv`,
  used by `spatial_latent()`.

It does not currently estimate both paths in a single fit, and
`R/extract-sigma.R` says `spatial_latent` has no `S_spde` component.

## Commands Still Needed

Only after maintainer approval of the next lane:

- RED test for additive spatial low-rank-plus-diagonal behavior.
- TMB likelihood / mathematical review if adding a real SPDE companion
  engine path.
- G1-G4 heavy tests under `GLLVMTMB_HEAVY_TESTS=1`.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` if
  roxygen changes.
- Full `Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'`
  before any push, noting the known local glmmTMB/TMB env-only issue if
  still present.

## Next Safest Action

Ask the maintainer whether to:

1. pause spatial and continue Stage A with the next source fold whose
   diagonal companion is already wired; or
2. explicitly approve an SPDE engine change to support
   `Lambda_spde Lambda_spde^T + Psi_spde` before parser/default work.

Do not implement a parser-only `spatial_latent(unique = TRUE)` fold on
top of the current engine.
