# Codex recovery checkpoint — 2026-07-12 06:52 MDT

## Repository state

- Branch: `claude/release-0.5.0` (ahead of `origin/claude/release-0.5.0` by four local commits before this checkpoint).
- Working tree: deliberately dirty WIP; the landing gate reported 261 uncommitted paths.
- Diff size at checkpoint: 246 tracked paths changed, 8,501 insertions and 16,375 deletions, plus untracked audit/generated files.
- No merge to `main`, release tag, or CRAN submission has been performed.

## Completed in this loop

- Re-audited the 13 retained pkgdown articles with Fisher, Rose, and Pat.
- Removed internal validation-register identifiers and process-only wording from reader-facing retained pages and refreshed generated HTML.
- Re-established the four public covariance modes (Scalar, Independent, Dependent, Latent); retained `unique =` only as a latent argument and described standalone `unique()` as deprecated compatibility syntax.
- Reworked `phylogenetic-gllvm.Rmd` around `phylo_latent(..., unique = TRUE)` and explicit shared/unique/total extraction, including the 500-species split example.
- Completed explicit grouping-argument cascade: long calls name `trait` and `unit`; repeated designs name `unit_obs`; the phylogenetic guide names `cluster` where it is a real role.

## Verification already run

- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` — PASS, no problems.
- `git diff --check` — PASS.
- All 13 source/render timestamp pairs — PASS (HTML newer than Rmd).
- Internal-code scan over `vignettes/articles` and `pkgdown-site/articles` — zero matches.
- Retained-source scan for `phylo_dep()`/`phylo_indep()` — zero matches.
- Rose grouping cascade — 22/22 executable calls, 5/5 display calls, three article renders successful.

## Next safest action

Read `docs/dev-log/handover/2026-07-12-claude-handover.md`, inspect the carried-over dirty tree, and let Claude perform the fresh-eye review before any release decision. Do not merge, tag, or submit to CRAN.

