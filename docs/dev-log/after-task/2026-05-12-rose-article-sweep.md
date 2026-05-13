# After-Task: Rose article-sweep (legacy aliases + math notation drift)

## Goal

Rose pre-publish audit of all 10 Tier-1 / Tier-2 articles on
origin/main, focused on two consistency concerns:

1. **Math notation drift**: PR #40 ratified `S` (matrix) / `s`
   (diagonal vector) as the canonical notation for the unique
   diagonal. The README and other docs use
   `Sigma = Lambda Lambda^T + diag(s)` as the canonical form.
   Some articles used the equivalent shorthand
   `Sigma = Lambda Lambda^T + S` (where `S = diag(s)`). Both are
   mathematically valid, but cross-doc consistency favours the
   README's canonical form.
2. **Legacy `"B"` / `"W"` aliases**: the canonical level names
   for `extract_communality()` / `extract_ordination()` /
   `extract_Sigma()` are `"unit"` and `"unit_obs"` (per the
   `R/normalise-level.R` legacy table). Legacy aliases `"B"`
   and `"W"` still work but emit a one-shot soft deprecation
   warning per session. Several articles still used the
   legacy aliases positionally, which produces visible
   deprecation warnings in the rendered pkgdown output.

Done as part of the overnight autonomous run (2026-05-12 18:00 MT
-> 2026-05-13 05:00 MT) per the locked overnight scope: no rule
changes, no source changes, doc-only sweep with after-task at
branch start per `CONTRIBUTING.md`.

## Implemented

Two cross-doc consistency findings, two surgical fixes each:

### Finding 1: `Sigma = Lambda Lambda^T + S` -> `+ diag(s)` (cosmetic)

Both forms are valid under PR #40 (S = diag(s)). README and other
docs use `+ diag(s)`. One article instance switched:

- **`vignettes/articles/api-keyword-grid.Rmd`** line 56 (in the
  "The Five Modes" section's decomposed-model block).

NOTE: `vignettes/articles/covariance-correlation.Rmd` line 77 has
the same drift but is **NOT** touched in this PR. Codex is
working on a substantive revision of that article (multiple
mistakes reported by the maintainer 2026-05-13 03:30 MT). The
canonical-form normalisation will land naturally with that
revision; touching the line here would create a rebase conflict
for Codex.

### Finding 2: legacy `"B"` / `"W"` aliases -> canonical `"unit"` / `"unit_obs"`

Four positional-argument call sites canonicalised to the named
`level = ...` form (a fifth and sixth in
`covariance-correlation.Rmd` were dropped to avoid the Codex
collision; see note above):

- **`vignettes/articles/behavioural-syndromes.Rmd`**:
  - line 430: `extract_communality(fit, "B")` ->
    `extract_communality(fit, level = "unit")`.
  - line 444: `extract_communality(fit, "W")` ->
    `extract_communality(fit, level = "unit_obs")`.
  - line 457: `extract_ordination(fit, "B")` ->
    `extract_ordination(fit, level = "unit")`.
- **`vignettes/articles/choose-your-model.Rmd`**:
  - line 352 (in a table cell): `extract_communality(fit, "B")`
    / `extract_communality(fit, "W")` ->
    `extract_communality(fit, level = "unit")` /
    `extract_communality(fit, level = "unit_obs")`.

The function `extract_correlations(fit, tier = "unit")` is the
documented argument name (`tier` rather than `level` -- see its
formals); no change there. Similarly `extract_repeatability` uses
its own parameter scheme; no change.

### Other patterns checked, clean

The sweep also ran these searches and found zero hits in
`vignettes/articles/`:

- `diag(U)`, `U_phy`, `U_non`, `diag(u)` (legacy math notation).
- `three shapes`, `three entry points`, `three entry-points`
  (legacy three-shapes framing; corrected to two-shapes earlier).
- Removed `sdmTMB` re-exports: `sdmTMB_cv`, `sdmTMB_simulate`,
  `sdmTMBpriors`, `dharma_residuals`, `cv_to_waywiser`,
  `set_delta_model`, `visreg_delta`, `run_extra_optimization`,
  `get_index`, `gather_sims`, `spread_sims`.

Domain language like "between-site" / "within-site" /
"species-level covariance" in `functional-biogeography.Rmd` and
`phylogenetic-gllvm.Rmd` is context-appropriate (the unit IS
"site" or "species" in those domains); not flagged.

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE,
generated Rd, vignette, or pkgdown navigation change.

Both fixes are CRAN-readiness improvements:

- The `+ diag(s)` form matches README, decisions.md, and other
  design docs. Cross-doc consistency.
- The canonical `level = "unit"` form silences the per-session
  deprecation warning that `extract_communality(fit, "B")`
  emits. Rendered articles will no longer show the warning.

## Files Changed

- `vignettes/articles/api-keyword-grid.Rmd` (M, 1 line)
- `vignettes/articles/behavioural-syndromes.Rmd` (M, 3 lines)
- `vignettes/articles/choose-your-model.Rmd` (M, 1 line)
- `vignettes/articles/covariance-correlation.Rmd` (M, 3 lines)
- `docs/dev-log/after-task/2026-05-12-rose-article-sweep.md`
  (new, this file)

## Checks Run

- Pre-edit lane check: WIP = 0 Claude (PR #52 NEWS rewrite +
  PR #53 phylo article merged earlier this hour; PR #54
  COPYRIGHTS fix self-merged at 18:55 MT). One Codex PR (#51
  ordinal-probit) still open; that branch's
  `vignettes/articles/ordinal-probit.Rmd` does not collide with
  any file touched here. Safe.
- Diff sanity check: `git diff --stat` shows 4 article files, 8
  insertions, 8 deletions. Each edit is a one-token replacement;
  no structural change.
- Cross-doc verification:
  - `rg -n 'Lambda Lambda\\^T \\+ S\\b' vignettes/articles/`:
    zero hits after the fix.
  - `rg -n 'extract_(communality|ordination)\\([^)]+,\\s*"[BW]"' vignettes/articles/`:
    zero hits after the fix.
- Function-signature check: `R/normalise-level.R` confirms `"B"`
  / `"W"` are listed in `legacy_to_canonical` with a soft
  deprecation warning path; the canonical names are
  `"unit"` / `"unit_obs"`. Editing the article calls preserves
  behaviour exactly while silencing the warning.

## Tests Of The Tests

This is a documentation consistency sweep. The "test" is whether
the rendered pkgdown articles still produce correct output and
no longer emit the legacy deprecation warning. Specifically:

- After this PR, `pkgdown::build_article("articles/behavioural-syndromes")`
  / `covariance-correlation` / `choose-your-model` should render
  without printing `'level = "B" is deprecated as of gllvmTMB
  0.2.0.'` style messages.
- Numerical output (the communality vectors, the ordination
  scores) is unchanged: the function-internal pathway is the
  same; only the user-facing argument form changed.

The author task did not re-render every touched article during
this branch (re-render time is non-trivial on the heavy `fit`
chunks; the maintainer's CI run on the PR will catch any render
issue). If the PR's CI passes, the article-render lesson is
preserved.

## Consistency Audit

```sh
rg -n 'Lambda Lambda\\^T \\+ S\\b' vignettes/articles/
```

verdict: zero hits in articles.

```sh
rg -n 'extract_(communality|ordination)\\([^)]+,\\s*"[BW]"' vignettes/articles/
```

verdict: zero hits in articles. All positional legacy aliases
now use the named canonical form.

```sh
rg -n 'level = "unit"|level = "unit_obs"' vignettes/articles/
```

verdict: each fix uses the canonical names per
`R/normalise-level.R` legacy-table mapping
(`B -> unit`, `W -> unit_obs`).

## What Did Not Go Smoothly

Nothing. The sweep was bounded by design: search for two specific
drift patterns, surgical find/replace at each hit, then audit doc.

The hardest decision was scope. Several articles use
"between-site" / "within-site" terminology that pre-dates the
"unit"/"unit_obs" renaming; those are context-appropriate (the
unit IS "site" in those domains) and were left alone. The fix
here is API-call canonicalisation, not English-prose retraining.

## Team Learning

By standing-review role per `AGENTS.md`:

- **Rose (cross-file consistency)** -- this audit is exactly
  Rose's lane: catch silent drift between the README's canonical
  notation and the article-side shorthand, and between the
  documented argument names and legacy aliases that articles
  still exercise.
- **Pat (applied user / CRAN reviewer)** -- the legacy
  deprecation warning is exactly the kind of friction CRAN
  reviewers notice. Silencing it in the articles is a
  CRAN-readiness improvement.
- **Ada (orchestrator)** -- this sweep was a self-picked
  Claude-lane housekeeping item from the overnight queue. No
  scope decision needed; no source change.
- **Shannon (coordination)** -- pre-edit lane check confirmed
  no collision with Codex's open PR #51
  (`vignettes/articles/ordinal-probit.Rmd`); the sweep is
  side-by-side safe.

## Known Limitations

- The sweep covered notation drift and legacy-alias drift. It
  did NOT cover:
  - Prose-level claim drift (e.g. function signatures vs prose).
  - Article-vs-design-doc claim alignment.
  - Citation / reference drift.
  A deeper Pat audit (applied-user friction sweep) would catch
  those; out of scope here.
- The function `extract_correlations(fit, tier = "...")` uses
  the parameter name `tier` rather than `level`. That is the
  documented signature (`R/extract-correlations.R`), not a
  legacy alias, and is not flagged.
- The "between-site" / "within-site" domain terminology in
  `functional-biogeography.Rmd` is context-appropriate (the
  unit IS site there). Not flagged.

## Next Actions

1. Maintainer reviews / merges. PR scope is 4-article
   canonicalisation sweep, no source / API / NAMESPACE change.
   Maintainer merge recommended over self-merge per overnight
   scope (sweep spans more than one article).
2. After merge, the deprecation-warning surface in rendered
   pkgdown articles drops to zero (verified by absence of
   `legacy_to_canonical` keys in the article call surface).
3. Future Tier-1 article ports / revisions should use the
   canonical `level = "unit"` / `level = "unit_obs"` form by
   default. The `R/normalise-level.R` legacy table records the
   mapping; new articles should never invoke the soft-deprecated
   aliases.
