# After-Task: Priority 1a Proposal -- Reader-Path Article Rewrites

## Goal

Propose how to implement Priority 1a from the
post-2026-05-11 `ROADMAP.md` ("Stabilise the reader path"):

1. Pair long-format and wide-format `gllvmTMB` fit examples in
   every Tier-1 article (per the `AGENTS.md` "Writing Style"
   bullet locked on 2026-05-11).
2. Replace the four legacy helpers slated for delete-after-rewrite
   in PR #10's Priority 2 audit (`getLoadings`,
   `extract_ICC_site`, `ordiplot`, `extract_residual_split`) with
   their canonical replacements.

This PR is **proposal only**: no article files modified. After
maintainer approval of the canonical snippet (Section "Canonical
long + wide snippet" below), Codex (or Claude) implements one
article at a time, each as a separate small PR with its own
after-task report.

## Implemented

A single proposal document at
`docs/dev-log/after-task/2026-05-11-priority-1a-proposal.md`
containing:

- a read-only audit of all eight reader-facing `.Rmd` files
  (seven Tier-1 articles + the Get Started vignette);
- a canonical long + wide example snippet that every rewrite
  should match;
- a suggested rewrite order with rationale per article;
- an explicit handoff note for whoever picks up the rewrite
  work (the implementer is expected to be Codex per the
  Collaboration Rhythm in `CLAUDE.md`).

No package code, NAMESPACE, generated Rd, vignette source, or
pkgdown navigation changed. Proposal only.

## Mathematical Contract

No public R API, likelihood, formula grammar, estimator, family,
NAMESPACE, or generated Rd changed.

## Audit (article-by-article)

Source data: ripgrep counts of `gllvmTMB(`, `gllvmTMB_wide(`, and
`traits(` call sites across all reader-facing Rmd files, plus an
explicit search for the four legacy helpers.

### Long / wide / traits coverage

| Article | `gllvmTMB(` | `gllvmTMB_wide(` | `traits(` | Already paired? |
|---|---|---|---|---|
| `vignettes/gllvmTMB.Rmd` (Get Started) | 1 | 0 | 0 | NO |
| `vignettes/articles/morphometrics.Rmd` | 5 | 0 | 0 | NO |
| `vignettes/articles/joint-sdm.Rmd` | 2 | 0 | 0 | NO |
| `vignettes/articles/behavioural-syndromes.Rmd` | 3 | 1 | 2 | YES |
| `vignettes/articles/choose-your-model.Rmd` | 7 | 0 | 0 | NO |
| `vignettes/articles/covariance-correlation.Rmd` | 2 | 0 | 0 | NO |
| `vignettes/articles/functional-biogeography.Rmd` | 7 | 1 | 2 | YES |
| `vignettes/articles/pitfalls.Rmd` | 5 | 0 | 0 | NO |

Two articles (`behavioural-syndromes`, `functional-biogeography`)
already show both forms. Six need a long + wide pairing added to
at least one fit example.

### Legacy helper usage

| Helper | Article | Line | Context |
|---|---|---|---|
| `extract_ICC_site(` | `functional-biogeography.Rmd` | 214 | live call inside a fit recovery block |
| `extract_ICC_site(` | `choose-your-model.Rmd` | 352 | inside a recommendations table |
| `extract_ICC_site(` | `covariance-correlation.Rmd` | 248 | live call |
| `getLoadings(` | `pitfalls.Rmd` | 141 | prose mention ("`getLoadings()` will surface a one-shot hint...") -- not a live call |
| `getLoadings(` | `choose-your-model.Rmd` | 350 | inside a recommendations table |
| `getLoadings(` | `morphometrics.Rmd` | 398 | live call |
| `ordiplot(` | `morphometrics.Rmd` | 404 | live call + plot |
| `extract_residual_split(` | `covariance-correlation.Rmd` | 338 | prose mention ("`extract_residual_split(fit)` to separate...") |

Five articles need legacy-helper replacement; the other three
(`behavioural-syndromes`, `joint-sdm`, `gllvmTMB.Rmd`) need only
the long + wide pairing work.

## Canonical long + wide snippet

The reader-path rule says every Tier-1 fit example shows the
long-format and wide-format calls side by side. The cleanest pair
preserves the formula RHS unchanged so a reader can see that long
and wide are two views of the **same** model:

````markdown
We can fit the same model two ways. The long form is canonical;
the wide form is the convenience equivalent for readers who think
in matrices.

```r
# --- Long format (canonical) -------------------------------------
df_long <- tidyr::pivot_longer(
  df_wide,
  cols      = c(trait_A, trait_B, trait_C),
  names_to  = "trait",
  values_to = "value"
)

fit_long <- gllvmTMB(
  value ~ 0 + trait +
          latent(0 + trait | site, d = 2) +
          unique(0 + trait | site),
  data = df_long,
  unit = "site"
)

# --- Wide format (convenience; identical fit) --------------------
fit_wide <- gllvmTMB(
  traits(trait_A, trait_B, trait_C) ~ 0 + trait +
          latent(0 + trait | site, d = 2) +
          unique(0 + trait | site),
  data = df_wide,
  unit = "site"
)

# Both fits produce the same model.
# `gllvmTMB_wide(Y, ...)` is a third entry point for users who
# already have a numeric response matrix Y in hand.
```
````

Properties of the snippet:

- The RHS of the formula is **byte-identical** between the two
  calls. Only the LHS marker (`value` vs `traits(trait_A, ...)`)
  and `data` (`df_long` vs `df_wide`) differ.
- The shared `unit = "site"` argument is the same in both calls,
  reinforcing that the unit grouping has the same meaning.
- The `gllvmTMB_wide(Y, ...)` matrix entry is mentioned in a
  one-line comment but not shown in full -- it is the third entry
  for a different reader (matrix-in, fit-out) and crowds the
  primary side-by-side comparison.
- Trait names are illustrative placeholders. Each article
  substitutes its real trait columns.
- Optional `family = ...` arguments fit naturally in both calls
  with identical syntax.

Carve-outs (per `AGENTS.md`):

- Roxygen `@examples` for individual keyword or extractor
  functions may stay single-form when the keyword is
  intrinsically one shape (e.g., `traits()` is wide-only by
  construction).
- Articles that already pair long + wide
  (`behavioural-syndromes`, `functional-biogeography`) should be
  inspected for consistency with this snippet but may not need
  rewriting from scratch.

## Suggested rewrite order

Each row is a single PR; each PR ships its after-task report in
the same commit (per the locked discipline).

| # | Article | Rationale | Legacy helpers to replace | Long+wide work |
|---|---|---|---|---|
| 1 | `morphometrics.Rmd` | AGENTS.md names this the canonical Tier-1 exemplar. Land first so the snippet pattern is anchored. | `getLoadings` (line 398) -> `extract_Sigma(level = "unit")$Lambda` + `rotate_loadings()`; `ordiplot` (line 404) -> `extract_ordination(level = "unit")` + `plot()` | Add wide pairing to the main fit example. |
| 2 | `covariance-correlation.Rmd` | Core covariance content. Two legacy helpers (one live, one prose). | `extract_ICC_site` (line 248) -> `extract_communality()`; `extract_residual_split` (line 338, prose) -> `extract_Omega()` / `extract_communality()` | Add wide pairing to the main fit example. |
| 3 | `joint-sdm.Rmd` | No legacy helpers; just the long + wide pairing. Demonstrates the snippet on a spatial example. | none | Add wide pairing to both fit examples. |
| 4 | `pitfalls.Rmd` | One prose mention of `getLoadings()` (line 141, error-handling hint). The mention should be retired since the function itself will go in Priority 2. | `getLoadings` (line 141, prose) -> rephrase the error-handling hint without the function name | Add wide pairing to the main fit example. |
| 5 | `choose-your-model.Rmd` | Recommendations table cites two legacy helpers (lines 350, 352). The table needs canonical replacements. | `getLoadings` -> `extract_Sigma()$Lambda` + `rotate_loadings()`; `extract_ICC_site` -> `extract_communality()` | Add wide pairing to the worked example block. |
| 6 | `functional-biogeography.Rmd` | Already shows both forms; one live `extract_ICC_site` call (line 214) to swap. Minor pass. | `extract_ICC_site` (line 214) -> `extract_communality()` | Audit existing pair against the canonical snippet; fix only if drift. |
| 7 | `behavioural-syndromes.Rmd` | Already shows both forms; no legacy helpers. Audit-only pass. | none | Audit existing pair against the canonical snippet; fix only if drift. |
| 8 | `vignettes/gllvmTMB.Rmd` (Get Started) | One fit example, one form. Highest-traffic page. Suggested last so the canonical snippet has been validated through six article PRs first. | none | Add wide pairing to the tiny fit example. |

## Codex / Claude handoff

Per `CLAUDE.md` "Collaboration Rhythm" and `ROADMAP.md`
"Collaboration Stops":

- This proposal is the **Claude propose** step.
- The maintainer approves (or revises) the canonical snippet and
  the rewrite order.
- **Codex implements** the rewrites, one article per PR, in the
  approved order.
- Each rewrite PR includes its after-task report in the same
  commit and runs the Rose pre-publish gate (`vignettes/`
  triggers it).
- `pkgdown::check_pkgdown()` and `pkgdown::build_article(...)`
  for the affected article are the local checks before push.

The first Codex PR should be `morphometrics.Rmd` (row 1). Once it
lands and the snippet pattern is anchored, the remaining articles
follow the same template.

## Checks Run

- `rg -n "getLoadings\(|extract_ICC_site\(|ordiplot\(|extract_residual_split\(" vignettes/`
  enumerated all legacy-helper hits with line numbers.
- A per-article shell loop counting `gllvmTMB(`,
  `gllvmTMB_wide(`, and `traits(` produced the coverage table.

## Tests Of The Tests

- The legacy-helper count (8) matches the audit table row count.
- The two articles flagged as "already paired"
  (`behavioural-syndromes`, `functional-biogeography`) both have
  non-zero `wide` and `traits` counts in the coverage table,
  consistent with the "Already paired? = YES" verdict.

## Consistency Audit

- The canonical snippet is consistent with `AGENTS.md` Writing
  Style ("long form is canonical; wide form is the convenience
  equivalent") and the post-2026-05-11 `ROADMAP.md` Phase 1
  ("Present every Tier-1 fit example with long-format and
  wide-format calls side by side").
- The rewrite order is consistent with `ROADMAP.md` Phase 1
  ("one article or homepage section at a time").
- The handoff structure is consistent with `CLAUDE.md`
  Collaboration Rhythm ("Claude proposes; Codex implements
  bounded changes after the maintainer chooses").
- Legacy-helper replacements match the canonical mapping in PR
  #10's Priority 2 audit:
  - `getLoadings()` -> `extract_Sigma()$Lambda` + `rotate_loadings()`
  - `extract_ICC_site()` -> `extract_communality()`
  - `ordiplot()` -> `extract_ordination()` + `plot()`
  - `extract_residual_split()` -> `extract_Omega()` / `extract_communality()`

## What Did Not Go Smoothly

Nothing on this PR's scope. The proposal itself is a small
read-only audit.

## Team Learning

- The audit is reusable. The same ripgrep one-liners (legacy
  helpers + fit-call counts) can be re-run after each article
  rewrite as a regression check to confirm the article no longer
  uses the legacy names and now shows both forms.
- Per-article-per-PR is the right granularity. Bundling article
  rewrites would trigger the "broad article rewrite" stop in
  `ROADMAP.md` Collaboration Stops; one-article PRs stay below
  that line.

## Known Limitations

- The canonical snippet assumes the article has a `df_wide` data
  frame to `pivot_longer`. Articles that start from a long
  format already (some simulation-driven examples do) will
  reverse the order: simulate long, then `pivot_wider` to
  produce the wide form for the comparison call. Codex picks the
  shape per article.
- The snippet does not show `gllvmTMB_wide(Y, ...)` (matrix
  entry) in full. That form is for matrix-in-hand users and
  belongs in a separate article or a `?gllvmTMB_wide` example,
  not in the primary side-by-side comparison.

## Next Actions

- Maintainer reviews this proposal: approve / revise the
  canonical snippet, approve / reorder the rewrite order.
- Codex picks up the **first rewrite** (row 1, `morphometrics.Rmd`)
  per `CLAUDE.md` Collaboration Rhythm.
- Each subsequent article follows the same shape: one PR per
  article, after-task report in same commit, Rose gate runs,
  pkgdown article render verified locally.
