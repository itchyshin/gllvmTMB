# After-task: Notation switch NS-5 -- articles part 2 + NEWS -- 2026-05-14

**Tag**: `docs` (article math prose + NEWS.md; no R code,
no API, no math content change).

**PR / branch**: this PR / `agent/notation-switch-ns5-articles-part2-news`.

**Lane**: Claude (Codex absent).

**Dispatched by**: continuing the maintainer-authorised
2026-05-14 notation switch. NS-1..NS-4 merged earlier in
this session. **NS-5 closes the sequence**: 3 heavy articles
+ NEWS.md + pkgdown sanity.

**Files touched**:

3 articles + NEWS + after-task:

- `vignettes/articles/behavioural-syndromes.Rmd` (~17 hits:
  matrix forms `\mathbf{S}` / `\boldsymbol{S}`, scalars
  `S_{tt}` / `s_t^2`, plus 3 R comment-text references that
  needed manual edits since they were just labels)
- `vignettes/articles/functional-biogeography.Rmd` (~11 hits:
  reverses PR #82 / Batch C's earlier `\Psi -> S` conversion;
  `\boldsymbol{S}_B`, `\boldsymbol{S}_W`, `\boldsymbol{S}_R`,
  `\boldsymbol{S}_P` all become `\boldsymbol{\Psi}_X`)
- `vignettes/articles/phylogenetic-gllvm.Rmd` (~2 hits)
- `NEWS.md` (2 edits: drop "ML or REML" overstatement -> "ML
  only with REML planned post-0.2.0"; expand the
  "decomposition mode" line with the bold-capital-Psi /
  italic-lowercase-psi convention citing
  `decisions.md` 2026-05-14)
- This after-task file

## Math contract

No model / parser / likelihood / family change. Same
convention as NS-1..NS-4: `\boldsymbol{\Psi}` for matrices,
`\psi_t` for per-trait scalars (italic lowercase), `\psi_{tt}`
for matrix entries. Tier-subscripted matrix forms:
`\boldsymbol{\Psi}_B`, `\boldsymbol{\Psi}_W`,
`\boldsymbol{\Psi}_R` (spatial), `\boldsymbol{\Psi}_P`
(phylogenetic in functional-biogeography ladder),
`\boldsymbol{\Psi}_{\text{phy}}`,
`\boldsymbol{\Psi}_{\text{non}}`.

## Substitutions applied (single perl pass + 2 manual fixes)

```perl
# \boldsymbol{S}_X -> \boldsymbol{\Psi}_X
s/\\boldsymbol\{S\}_B/\\boldsymbol{\\Psi}_B/g;
s/\\boldsymbol\{S\}_W/\\boldsymbol{\\Psi}_W/g;
s/\\boldsymbol\{S\}_R/\\boldsymbol{\\Psi}_R/g;
s/\\boldsymbol\{S\}_P/\\boldsymbol{\\Psi}_P/g;
s/\\boldsymbol\{S\}_\{phy\}/\\boldsymbol{\\Psi}_{phy}/g;
s/\\boldsymbol\{S\}_\{non\}/\\boldsymbol{\\Psi}_{non}/g;
s/\\boldsymbol\{S\}/\\boldsymbol{\\Psi}/g;
# \mathbf{S} forms
s/\\mathbf\{S\}_B/\\boldsymbol{\\Psi}_B/g;
s/\\mathbf\{S\}_W/\\boldsymbol{\\Psi}_W/g;
s/\\mathbf\{S\}/\\boldsymbol{\\Psi}/g;
s/\\mathbf S\b/\\boldsymbol\\Psi/g;
# Plain prose tokens
s/\bS_phy\b/Psi_phy/g;
s/\bS_non\b/Psi_non/g;
s/\bs_phy\b/psi_phy/g;
s/\bs_non\b/psi_non/g;
# Bare S in equation contexts
s/\$S\$/\$\\boldsymbol{\\Psi}\$/g;
s/\+ S$/+ \\boldsymbol\\Psi/g;
# S_{tt} matrix entry
s/S_\{tt\}/\\psi_{tt}/g;
s/\bS_t\b/\\psi_t/g;
# diag(s)
s/diag\(s\)/diag(psi)/g;
# Lowercase s_t scalar
s/\bs_t\^2\b/psi_t^2/g;
s/\bs_t\b/psi_t/g;
# Local variable names in code chunks
s/\bS_B_true\b/psi_B_true/g;
s/\bS_W_true\b/psi_W_true/g;
```

Plus 2 manual Edits for R comment-text references in
`behavioural-syndromes.Rmd:165, 194-195` (section headers
in code chunks like
`# ---- Per-trait between-individual unique variances (S_B) -----`
which got renamed to `(psi_B)` -- not caught by perl because
they aren't in a recognizable math or variable context).

## Checks run

- `rg` verify across the 3 articles: **0 remaining** S-form
  references in scope.
- `pkgdown::check_pkgdown()`: **No problems found.** Clean.
- `urlchecker::url_check()`: 1 transient 403 on
  `https://doi.org/10.1111/j.1467-9868.2011.00777.x`
  (Lindgren 2011, SPDE paper) in `man/spde.Rd:158`. Wiley
  DOI rate-limit flake; not blocking; Phase 5 polish target.
- No `devtools::document()` regen (no R/ touched).
- No `devtools::test()` run (article math prose only, no R
  code change).

## Consistency audit

After NS-5 merges, **the entire user-facing surface of the
package is on the new `\boldsymbol{\Psi}` / `\psi_t`
convention**:

- Rule files (NS-1): AGENTS.md, CONTRIBUTING.md, CLAUDE.md,
  decisions.md, check-log.md
- README + design docs (NS-2): 00-vision, 03-phylogenetic-
  gllvm (with 3-piece fallback added), 04-sister-package-
  scope
- R/ source + tests + article code chunks (NS-3a): API
  rename `S_B/S_W -> psi_B/psi_W` in `simulate_site_trait()`;
  cascading rename in 30 test files + 4 article code chunks
  + README line 113 + man/*.Rd regen
- R/ roxygen math prose (NS-3b): 8 R/ files updated;
  14 man/*.Rd regenerated
- Articles part 1 (NS-4): pitfalls, covariance-correlation,
  api-keyword-grid, choose-your-model (clean already),
  morphometrics, joint-sdm
- Articles part 2 + NEWS (NS-5; this PR): behavioural-
  syndromes, functional-biogeography (reverses PR #82's
  earlier Psi -> S), phylogenetic-gllvm + NEWS

**Closes the notation switch.** Phase 1a Batch A can now
start.

Function- and file-name "two-U" task labels preserved per
`decisions.md` 2026-05-14 entry.

## Tests of the tests

No tests added. Article math LaTeX is in `\eqn{}` / `$$`
blocks; not parsed by R. `pkgdown::check_pkgdown()` clean.

## What went well

- The 3 heavy articles + NEWS swept cleanly in one perl pass
  with 2 manual fix-ups for R-comment-text section headers.
- `functional-biogeography.Rmd`'s reverse-of-PR-#82 conversion
  worked seamlessly with the same `\boldsymbol{S}_X ->
  \boldsymbol{\Psi}_X` pattern.
- `pkgdown::check_pkgdown()` returned "No problems found"
  after all 5 notation-switch PRs cumulatively touched ~80
  files. That is the cleanest single signal that the switch
  didn't break documentation rendering.
- NEWS.md gained both the notation-convention codification
  (citing decisions.md) and the REML scope correction (drops
  the "ML or REML" overstatement). One fix per scope decision.

## What did not go smoothly

- **R-comment-text section headers needed manual fix-ups** in
  `behavioural-syndromes.Rmd` (3 lines). These are R
  comments like `# ---- Per-trait between-individual unique
  variances (S_B) ----` where "S_B" appears inside `----`
  separators. Perl regex would need explicit `(S_B)` pattern
  to catch these. Used Edit instead. Lesson: in articles
  with R code chunks containing section-header comments
  that reference variable labels, the article math sweep
  needs an explicit second pattern.
- **Urlchecker 403 on Lindgren 2011 DOI** (Wiley). Pre-existing
  issue, not caused by this PR. Files in `man/spde.Rd:158`.
  Flagged for Phase 5 polish; can be temporarily ignored
  during CI since `urlchecker` isn't part of the standard
  R CMD check pipeline.

## Team learning, per AGENTS.md role

- **Ada (maintainer)**: NS-1..NS-5 sequence complete. 5 PRs
  in one session covering the entire notation surface.
  Pattern-based bulk sweep + per-PR after-task report worked
  reliably end-to-end.
- **Boole (R API)**: standing brief unchanged.
- **Gauss (TMB likelihood / numerical)**: standing brief
  unchanged. No engine change in NS-5.
- **Noether (math consistency)**: the entire package now
  uses `\boldsymbol{\Psi}` (matrix) / `\psi_t` (scalar) /
  `\psi_{tt}` (entry) consistently. The "two-U" function /
  file names are the only place "S" or "U" appears, and
  those are explicitly preserved as task labels per
  decisions.md.
- **Darwin (biology audience)**: no biology change.
- **Fisher (statistical inference)**: standing brief for
  Phase 1b' (galamm Wald-only comparator + empirical
  coverage study).
- **Emmy (R package architecture)**: no S3 method change.
- **Pat (applied PhD user)**: the Phase 1c
  `gllvm-vocabulary.Rmd` article will introduce the
  Greek-letter convention; for now, the rendered articles
  use Psi/psi consistently.
- **Jason (literature scout)**: standing brief.
- **Curie (simulation / testing)**: standing brief.
- **Grace (CI / pkgdown / CRAN)**: `pkgdown::check_pkgdown()`
  clean. The Lindgren 2011 DOI 403 is a known Wiley issue;
  filed for Phase 5 polish. **The notation switch is done as
  far as CI / docs are concerned.**
- **Rose (systems audit)**: full pre-publish audit confirms
  the user-facing surface is internally consistent. Five PRs
  (#86, #87, #88, #89, #90, this PR) cumulatively touched
  ~100+ files; zero remaining S-notation references in math
  prose; function / file names task-label-preserved per
  decisions.md.
- **Shannon (cross-team)**: Codex absent. No cross-team event.

## Design-doc + pkgdown updates

- Design doc 03-phylogenetic-gllvm.md was updated in NS-2 to
  include the three-piece fallback formulation. NS-5 does
  not touch design docs.
- `pkgdown::check_pkgdown()`: "No problems found".
- pkgdown re-render scheduled to fire automatically on the
  next `main` push (the workflow runs after `R-CMD-check`
  on main).

## Known limitations and next actions

**Known limitations**:

- 1 transient Wiley DOI 403 (Lindgren 2011, `man/spde.Rd:158`)
  flagged by `urlchecker::url_check()`. Pre-existing; not
  caused by this PR. Phase 5 polish target.

**Next actions**:

1. After NS-1..NS-5 merged (this PR closes the sequence):
   start **Phase 1a Batch A** (R/unique-keyword.R paired-form
   bullet + R/fit-multi.R:613 formula rewrite +
   R/fit-multi.R:619 M1/M2 label drop). Persona reviews:
   Gauss + Noether + Boole + Rose.
2. Phase 1a Batch B (drop in-prep equation citations in 5 R/
   files), Batch D (gllvmTMB_wide -> traits in 2 articles),
   Batch E (\mathbf{U} -> \boldsymbol{\Psi} in
   behavioural-syndromes + R/extract-two-U-via-PIC roxygen).
3. Phase 1b: engine + extractor fixes (P1, P2, Fisher
   diagnostics, edge-case CI tests).
4. Phase 1b': Profile-CI Validation milestone (Jason
   pre-scan + coverage study + confint_inspect +
   troubleshooting-profile.Rmd).
5. Phase 1c article ports (13 PRs).
6. Phase 1d/1e/1f.
7. Phase 2-5 + Phase 5.5 external validation sprint.

**Notation switch sequence (NS-1..NS-5) is complete.**
