# After-task report: figure surface rescan after bootstrap plot slices

**Date:** 2026-05-21  
**Branch:** `codex/florence-covariance-plots-2026-05-21`  
**Agent:** Codex / Ada  
**Active review lenses:** Rose, Florence, Fisher, Pat, Grace  
**Spawned subagents:** none

## Scope

This read-only audit re-scanned README and articles for covariance,
correlation, communality, and repeatability figure surfaces after the bootstrap
plot slices. It records the remaining hidden/technical article backlog and
names the next safest implementation slice.

## Files touched

- `docs/dev-log/audits/2026-05-21-figure-surface-scan-after-bootstrap.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-21-figure-surface-rescan-after-bootstrap.md`

## Definition-of-Done check

1. **Implementation:** audit-only; no package code changed.
2. **Simulation recovery:** not applicable.
3. **Documentation:** audit and check-log entries created.
4. **Runnable user-facing example:** not applicable.
5. **Check-log:** appended in `docs/dev-log/check-log.md`.
6. **Review pass:** Rose checked cross-surface consistency, Florence checked
   figure-backlog priority, Fisher checked uncertainty-provenance risk, Pat
   checked first-reader priority, and Grace checked that no package validation
   command was needed for an audit-only slice.

## Evidence

- Pre-edit lane check: `gh pr list --state open` reported only draft PR #233;
  `git log --all --oneline --since="6 hours ago"` showed the current
  covariance/plot lane.
- `rg -n "extract_Sigma\\(|extract_Sigma_table\\(|extract_correlations\\(|plot_correlations\\(|plot_Sigma_table\\(|cov2cor\\(|geom_tile\\(|geom_text\\(|extract_communality\\(|extract_repeatability\\(|plot\\(fit.*type = \\\"correlation|type = \\\"communality|type = \\\"integration" vignettes/gllvmTMB.Rmd vignettes/articles/*.Rmd README.md`
  produced the source map summarized in
  `docs/dev-log/audits/2026-05-21-figure-surface-scan-after-bootstrap.md`.
- `git diff --check` was run after the audit files were written and was clean.

## Deliberately not run

- No R tests, pkgdown render, or package check were run because this slice only
  added internal audit/check-log Markdown files.
