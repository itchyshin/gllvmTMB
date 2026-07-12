# Claude fresh pre-publish review — gllvmTMB 0.5.0 docs estate (2026-07-12)

**Session:** Claude, sequential pickup from the Codex → Claude handover
(`docs/dev-log/handover/2026-07-12-claude-handover.md`).
**Branch:** `claude/release-0.5.0` at `4a2398fb` (level with origin).
**Scope:** fresh-eyes pre-publish review of the reader-facing article estate and
classification of the uncommitted working tree. **No files were edited or staged.**
Release remains paused; disposition returned to Shinichi.

## Outcome

Documentation-content honesty: **PASS.** Both an independent deterministic scan
and a fresh adversarial Rose lens found no blocking or should-fix issues on the
reader surfaces.

### Checks run (all clean)

- `pkgdown::check_pkgdown()` → No problems found.
- Internal-code scan (DIA/CI#/EXT/FAM/FG/MIX, `register`, `validation_row`,
  phase numbers, agent names, review scores) across all 17 retained article
  `.Rmd` **and** the rendered `pkgdown-site/articles/*.html` → zero real hits.
- `phylogenetic-gllvm.Rmd` → zero `phylo_dep()`/`phylo_indep()`; teaches
  `phylo_latent(..., unique = TRUE)`; rendered page frames intervals as
  recovery-only ("recovery guarantees", "does not imply…"), no overclaim.
- Deprecated standalone `unique()`/`*_unique()` as a primary teaching route →
  none; all bare `unique(` hits are base-R dedup or an explicit deprecation note.
  Current `unique = TRUE/FALSE` argument consistently distinguished.
- Four-mode grid (Scalar/Independent/Dependent/Latent) uniform across
  `api-keyword-grid.Rmd`, `NEWS.md`, `README.md`, `_pkgdown.yml`; no five-column
  grid anywhere.
- Delta/hurdle latent-scale correlations carry explicit "not yet / do not
  interpret" caveats (`README.md:200-215`, `response-families.Rmd:297-316`).
- Staleness: all 15 deleted articles and 14 deleted `man/` topics have zero
  live reader-facing references (only `NEWS.md:76` documents the withdrawal);
  all ~60 internal cross-links resolve to retained pages.
- `DESCRIPTION` at `Version: 0.5.0`; no stray `1.0`/`1.0.0` in reader files.

Rose full audit result recorded in the session transcript; verdict: honest and
internally consistent, no grounds to block on documentation content.

### One clarity note (not blocking)

`vignettes/articles/gllvm-vocabulary.Rmd:42-43` — "`cluster` supplies a **third**
ordinary or structured grouping, and optional `cluster2` supplies a **second**
plain diagonal grouping." The ordinals read ambiguously: `cluster` is the third
grouping role overall, but `cluster2`'s "second" has no clear first referent
(`cluster` was described as ordinary/structured, not plain diagonal). Sits in the
just-recorded `cluster2` rule territory (commit `4a2398fb`), so surfaced for
Shinichi rather than silently edited.

## Working-tree classification

The uncommitted tree is a coherent release-prep estate (cross-checked against
`docs/dev-log/audits/2026-07-11-pkgdown-estate-disposition.md`), not random WIP,
in three coordinated slices plus hygiene:

- **A. Article finalization** — 15 article deletions (all sanctioned CUT/HIDE/
  MERGE in the ledger) + 3 modified (`covariance-correlation`,
  `model-selection-latent-rank`, `gllvmTMB.Rmd`) + the ledger. 17 SHIP articles remain.
- **B. Public-export trim (HIGH-RISK)** — NAMESPACE −14 exports (`profile_*`,
  `coverage_study`, `check_identifiability`, `bootstrap_ci_lv_effects`,
  `gllvm_julia_capabilities`/`gate_registry`), 14 matching `man/` deletions,
  31 `R/` files, ~62 regenerated `man/`.
- **C. Test estate** — 83 test files (82 referencing the removed export names).
- Hygiene: `ROADMAP`, `CONTRIBUTING`, `.github/workflows/pkgdown.yaml`,
  `.Rbuildignore`, `docs/design/*`. Untracked: old `2026-07-09` handover,
  `results/` coverage CSVs, `vignettes/*.png`, `.claude/launch.json`.

**Correction to the handover framing:** this branch is NOT a doc-only PR. It
carries a high-risk public-API trim (B/C) that, per the CLAUDE.md merge rules,
needs Shinichi's explicit decision before any commit/merge.

## Follow-up (returned to Shinichi)

1. Disposition/commit-scoping of the uncommitted estate (esp. the high-risk
   export trim B/C vs. article finalization A).
2. The one `gllvm-vocabulary.Rmd:42-43` ordinal clarity nit.
3. Visual/mobile QA of the 13 rendered pages remains a browser gate (Florence/
   Grace); this review was content-level. Local server: `http://127.0.0.1:8899/`.
4. Merge/tag/CRAN remain paused — Shinichi's call.
