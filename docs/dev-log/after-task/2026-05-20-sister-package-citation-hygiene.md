# After-task report - sister-package citation hygiene (#223)

**Date**: 2026-05-20
**Branch**: `codex/sister-package-citation-hygiene-2026-05-20`
**Issue**: #223
**Maintainer lane**: citation/provenance hygiene; no new advertised capability.

## Active perspectives

- **Ada**: orchestrated the bounded lane and kept issue, board,
  check-log, and after-task artefacts aligned.
- **Jason**: checked sister-package and literature-map context.
- **Boole**: watched grammar wording, especially the 4 x 5 keyword grid.
- **Fisher**: checked simulation-reporting references and inference claims.
- **Rose**: checked stale wording and unsupported capability drift.
- **Shannon**: checked coordination state before edits.

No spawned subagents were running for this lane.

## Scope

Completed edits:

- refresh sister-package and simulation-reporting citation context;
- fix live stale `3 x 5` wording;
- keep all prose inside existing validation-debt boundaries;
- append exact commands and stale-wording scans to
  `docs/dev-log/check-log.md`.

## Definition-of-done check

1. **Implementation**: complete. This was documentation/provenance
   work only: no R, C++, parser, likelihood, or estimator code changed.
2. **Simulation recovery test**: not applicable; no likelihood, family,
   keyword, estimator, or parser implementation changes were made.
3. **Documentation**: complete. README, design docs, provenance text,
   and two public articles were updated.
4. **Runnable example**: not applicable; no user workflow change planned.
5. **Check-log entry**: complete; see
   `docs/dev-log/check-log.md` 2026-05-20 #223 entry.
6. **Review pass**: complete for this scope. Jason checked comparator
   citation context; Boole checked 4 x 5 grammar wording; Fisher checked
   the M3 simulation-reporting claims; Rose checked stale public-prose
   patterns and validation-debt boundaries; Shannon checked coordination
   state before shared-file edits.

## Commands and evidence

- `git status --short --branch`
  -> branch and worktree checked before editing.
- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,author,updatedAt`
  -> no open PRs at lane start.
- `git log --all --oneline --since="6 hours ago"`
  -> recent shared-file history reviewed before editing.
- `rg -n '3 x 5|3 × 5|3x5' AGENTS.md CLAUDE.md CONTRIBUTING.md DESCRIPTION README.md NEWS.md _pkgdown.yml inst/COPYRIGHTS docs/design docs/dev-log/known-limitations.md .agents/skills R man vignettes --glob '!docs/dev-log/after-task/**' --glob '!docs/dev-log/audits/**' --glob '!docs/dev-log/shannon-audits/**' --glob '!docs/dev-log/check-log.md'`
  -> one remaining hit, NEWS's historical "3 × 5 to 4 × 5" release
  note.
- `rg -n 'gllvmTMB_wide\(Y, \.\.\.\) was removed|removed in 0\.2\.0|REMOVED in 0\.2\.0|profile-likelihood default|trio|meta_known_V\(value|phylo\(|gr\(|meta\(|diag\(U\)|U_phy|U_non|\\bf S|S_B|S_W' README.md vignettes/articles/cross-package-validation.Rmd vignettes/articles/ordinal-probit.Rmd docs/design/00-vision.md docs/design/04-sister-package-scope.md docs/design/42-m3-dgp-grid.md docs/design/50-m3-3b-surface-admission.md inst/COPYRIGHTS`
  -> 0 hits after the `meta_V()` article correction.
- `git diff --check`
  -> clean.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> passed: `No problems found.`

Not run:

- `devtools::test()` / `devtools::check()` because no package code,
  roxygen, generated Rd, examples, or parser behaviour changed.
- `pkgdown::build_articles(lazy = FALSE)` because article edits were
  prose-only and did not touch code chunks or formula parsing.

## Files touched

- `README.md`
- `docs/design/00-vision.md`
- `docs/design/04-sister-package-scope.md`
- `docs/design/42-m3-dgp-grid.md`
- `docs/design/50-m3-3b-surface-admission.md`
- `inst/COPYRIGHTS`
- `vignettes/articles/cross-package-validation.Rmd`
- `vignettes/articles/ordinal-probit.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/coordination-board.md`
- `docs/dev-log/after-task/2026-05-20-sister-package-citation-hygiene.md`

## Outcome

The literature map now credits `gllvm` 2.0, EVA-GLLVM, and
`glmmTMB::rr()` explicitly; M3 simulation docs cite ADEMP and
transparent simulation-reporting guidance; recent phylogenetic
location-scale work is recorded as background rather than an
implemented `gllvmTMB` feature; and live stale `3 x 5` wording is
gone outside historical dev-log / NEWS context.
