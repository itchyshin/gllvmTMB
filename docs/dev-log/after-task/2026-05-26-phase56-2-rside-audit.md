# After-task Report: Phase 56.2 R-side `n_traits` / `n_lhs_cols` audit

**Date:** 2026-05-26
**Branch:** `codex/phase56-2-rside-audit-2026-05-26`
**Lead:** Ada/Codex
**Spawned subagents:** none

## Task

Close Phase 56.2 after #289 by reconciling Design 56's historical
"nine `n_traits` sites" audit with the post-#289 implementation.

## Files changed

- `docs/design/56-augmented-lhs-engine-stage3.md`
- `docs/dev-log/audits/2026-05-26-phase56-2-rside-audit.md`
- `docs/dev-log/after-task/2026-05-26-phase56-2-rside-audit.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/recovery-checkpoints/2026-05-26-100539-ada-checkpoint.md`

## What changed

- Reframed Design 56 §4 from a stale "replace all nine
  `n_traits` sites" table into a post-#289 site-by-site
  classification.
- Added `docs/dev-log/audits/2026-05-26-phase56-2-rside-audit.md`
  as the durable checklist for Phase 56.2.
- Recorded that legacy phylogenetic covariance paths remain
  trait-indexed: `theta_rr_phy`, `Lambda_phy`, `g_phy`,
  `log_sd_phy_diag`, and `g_phy_diag` stay `n_traits`.
- Recorded that the augmented structural-slope path is already
  represented by `Z_phy_aug`, `b_phy_aug`, `log_sd_b`,
  `atanh_cor_b`, and block-local `n_lhs_cols`.
- Corrected the older draft wording that implied Phase 56.2
  should set `n_lhs_cols = 2 * n_traits`; Phase 56.3 sets
  `n_lhs_cols = 2L` for supported intercept+slope forms, while
  trait stacking stays in the design rows / block structure.

## Evidence

- Pre-edit / coordination:
  `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,mergeStateStatus,statusCheckRollup,updatedAt,url`
  -> `[]`.
- Recent-lane check:
  `git log --all --oneline --decorate --since='6 hours ago'`
  -> #289, #290, and #291 are on `main`; no open PR overlap.
- GitHub Actions watchpoint:
  `gh run list --repo itchyshin/gllvmTMB --limit 12 --json databaseId,displayTitle,workflowName,status,conclusion,headBranch,headSha,url`
  -> #292's `main` R-CMD-check on `e4d67aa` completed successfully;
  the older #289 `main` run on `3133863` was cancelled by the newer
  main push; downstream pkgdown for `e4d67aa` was still in progress
  at closeout.
- Rebase after Shannon's merge-closeout PR:
  `git fetch origin --prune --quiet && git rebase origin/main`
  -> clean rebase onto `e4d67aa` (#292).
- Current open-PR check after Shannon merged #292:
  `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,isDraft,mergeable,updatedAt,url,files`
  -> `[]`.
- Source reads:
  `nl -ba R/fit-multi.R | sed -n '1178,1324p'`,
  `nl -ba R/fit-multi.R | sed -n '1518,1620p'`, and
  `nl -ba src/gllvmTMB.cpp | sed -n '465,620p'`
  -> confirmed which sites are trait covariance paths and which
  sites are the post-#289 augmented path.
- `Rscript --vanilla -e 'devtools::test(filter = "phase56-1-phylo-augmented-stub")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 9`.
- `Rscript --vanilla -e 'devtools::test(filter = "augmented-lhs-guard|phase56-1-phylo-augmented-stub|phylo-slope")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 21`.
- Stale-pattern scan:
  `rg -n '2 \* n_traits|2\*n_traits|n_lhs_cols = T|n_lhs_cols = 2T|mechanical replacement|replace.*nine|R/fit-multi.R:~1150|R/fit-multi.R:~1152|R/fit-multi.R:~1154|R/fit-multi.R:~1173|R/fit-multi.R:~1180|R/fit-multi.R:~1185|R/fit-multi.R:~1187|R/fit-multi.R:~1227|R/fit-multi.R:~1301' docs/design/56-augmented-lhs-engine-stage3.md docs/dev-log/audits/2026-05-26-phase56-2-rside-audit.md docs/dev-log/after-task/2026-05-26-phase56-2-rside-audit.md`
  -> only intentional new wording remains: "not a mechanical
  replacement list" and "not in a `2 * n_traits` prior dimension".
- Alignment scan:
  `rg -n 'theta_rr_phy|Lambda_phy|g_phy|log_sd_phy_diag|g_phy_diag|Z_phy_aug|b_phy_aug|log_sd_b|atanh_cor_b|n_lhs_cols|keep `n_traits`|already promoted|already split' docs/design/56-augmented-lhs-engine-stage3.md docs/dev-log/audits/2026-05-26-phase56-2-rside-audit.md`
  -> Design 56 and the audit name the same keep/promote decisions.
- `git diff --check`
  -> clean.

## Review gates

- **Ada / integration:** PASS. Phase 56.2 is narrowed to a
  classification/design-correction slice on post-#289 `main`.
- **Boole / R API and formula:** PASS. No parser or public formula
  grammar changed; `augmented-lhs-guard` still passes.
- **Gauss / TMB likelihood:** PASS. No TMB likelihood code changed;
  the audit explicitly protects trait-indexed covariance paths from
  accidental `n_lhs_cols` replacement.
- **Noether / math alignment:** PASS. The text preserves the
  block-local prior dimension for `Sigma_b` and keeps trait
  covariance in `Lambda_phy Lambda_phy^T` / `Psi_phy`.
- **Rose / consistency:** PASS. The stale `2 * n_traits` and old
  approximate-line replacement language is either removed or
  explicitly described as rejected older draft wording.
- **Shannon / coordination:** PASS with watchpoint. #292 is merged
  into `main`; this branch is rebased on top of it. Open PR census is
  empty. Downstream pkgdown for #292 was still running at closeout.

## Definition of Done checklist

1. **Implementation.** No user-facing implementation change expected;
   this is a post-#289 classification and design-correction slice.
2. **Simulation recovery test.** Not applicable; no new likelihood,
   family, keyword, or estimator is added in Phase 56.2.
3. **Documentation.** Design 56 classification updated; no roxygen/Rd
   changes expected.
4. **Runnable user-facing example.** Not applicable; public syntax remains
   blocked until Phase 56.3 and later recovery phases.
5. **`docs/dev-log/check-log.md` entry.** Present in this branch.
6. **Review pass.** Boole, Gauss, Noether, Rose, and Shannon lenses recorded
   above.

## Deliberately not run / not changed

- No `R/fit-multi.R` code edits; the post-#289 classification found
  no safe mechanical edit to make before parser activation.
- No `src/gllvmTMB.cpp` edits; no TMB likelihood or parameterisation
  changed.
- No `devtools::document()`; no roxygen, NAMESPACE, or generated Rd
  files changed.
- No `pkgdown::check_pkgdown()`; no pkgdown navigation, README,
  articles, vignettes, reference topics, or user-facing examples
  changed.
- No full `devtools::test()`; focused regression checks covered the
  dormant stub, fail-loud parser guard, and legacy `phylo_slope`
  path, and the branch is docs/dev-log/design only.
- No parser activation, public formula syntax change, skeleton-test
  activation, validation-debt row movement, ROADMAP tick, NEWS entry,
  deprecation, or article rewrite.
