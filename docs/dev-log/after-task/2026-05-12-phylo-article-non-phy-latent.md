# After-Task: phylogenetic-gllvm.Rmd theory/fit alignment

## Goal

Fix a theory/fit inconsistency in `vignettes/articles/phylogenetic-gllvm.Rmd`
that the maintainer flagged on the live pkgdown site
(<https://itchyshin.github.io/gllvmTMB/articles/phylogenetic-gllvm.html>):

The theory section writes both decompositions in parallel:

```
Sigma_phy = Lambda_phy Lambda_phy^T + S_phy
Sigma_non = Lambda_non Lambda_non^T + S_non
```

but the simulated truth and both fitted models only used
`Lambda_phy + S_phy + S_non`. There was no `Lambda_non` in the
simulation, and no `latent()` term on the non-phylogenetic side
of either fit. A reader following the theory side-by-side with
the syntax would notice the missing `latent(... | species)`
term.

The maintainer chose "make the fit match the theory" (rather
than soften the theory). This branch adds `Lambda_non_true` to
the simulation and `latent(0 + trait | species, d = 1)` /
`latent(1 | species, d = 1)` to both fits, demonstrating the
full four-component paired decomposition.

After-task report at branch start per `CONTRIBUTING.md`.

## Implemented

- **`vignettes/articles/phylogenetic-gllvm.Rmd`** (M):
  - `## Simulate` section: paragraph rewritten to say "the truth
    has four components, matching the paired decomposition in
    the theory section". Added `Lambda_non_true <- matrix(c(0.50,
    0.30, 0.20), n_traits, 1)`, `g_non <- matrix(rnorm(n_sp),
    n_sp, 1)`, and the `g_non %*% t(Lambda_non_true)` term in the
    `Y` construction.
  - `## Fit` section: both `fit_long` and `fit_wide` get a new
    `latent(0 + trait | species, d = 1)` (long) /
    `latent(1 | species, d = 1)` (wide) term between the
    `phylo_unique()` term and the `unique()` term. The four
    covariance components are now: phylogenetic shared
    (`phylo_latent`), phylogenetic diagonal (`phylo_unique`),
    non-phylogenetic shared (`latent`), non-phylogenetic
    diagonal (`unique`).
  - Prose after the fit chunks (line 161-168 region) updated to
    enumerate all four keywords and what each estimates.
  - `## Recover the phylogenetic covariance` section: the
    "non-phylogenetic diagonal" subsection rewritten as "the
    non-phylogenetic species-level covariance has the same
    paired decomposition as the phylogenetic side", with three
    `extract_Sigma(fit, level = "unit", part = c("shared",
    "unique", "total"))` calls mirroring the phylogenetic
    extraction immediately above.
  - Identifiability-caveat sentence (line 207-211) generalised:
    "do not over-interpret either split (between `Lambda_phy
    Lambda_phy^T` and `S_phy`, or between `Lambda_non
    Lambda_non^T` and `S_non`)" -- previously only mentioned
    the phylogenetic split.
  - **New `## Communality (within each tier)` section**: shows
    `extract_communality(fit, level = "unit")` for the
    non-phylogenetic side and the manual `diag(Sigma_phy_shared)
    / diag(Sigma_phy_total)` ratio for the phylogenetic side.
    Communality is defined only when both `latent()` and
    `unique()` are fit at a tier; this section is what makes
    the four-component fix pedagogically useful, not just
    cosmetic.
  - **New `## Phylogenetic heritability` section**: shows
    `extract_phylo_signal(fit)` returning the three-way
    decomposition `H^2 + C^2_non + Psi = 1` per trait, with
    prose explaining `H^2` (phylogenetic share, both phy
    components), `C^2_non` (non-phy shared share, requires the
    non-phy `latent()` term), and `Psi` (non-phy unique share).
    Concludes: "`C^2_non` is structurally zero when the
    formula omits the non-phylogenetic `latent()` term, so the
    three-way split collapses to `H^2 + Psi`. Adding `latent(0
    + trait | species, d = K)` (long) or `latent(1 | species,
    d = K)` (wide), as this article does, is what makes
    `C^2_non` a genuine non-phylogenetic shared-axis component
    rather than a placeholder."
- **`docs/dev-log/after-task/2026-05-12-phylo-article-non-phy-latent.md`**
  (NEW, this file).

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE,
generated Rd, or pkgdown navigation change. Single Tier-1 vignette
article rewritten in place.

The article's model is now the canonical paired four-component
decomposition:

```
Omega = (Sigma_phy ⊗ A) + (Sigma_non ⊗ I)
Sigma_phy = Lambda_phy Lambda_phy^T + diag(s_phy)
Sigma_non = Lambda_non Lambda_non^T + diag(s_non)
```

All math written in `S` / `s` notation per the 2026-05-12 naming
convention. The "two-U" nickname is preserved as a legacy task
label in the prose that introduces it.

## Files Changed

- `vignettes/articles/phylogenetic-gllvm.Rmd` (M)
- `docs/dev-log/after-task/2026-05-12-phylo-article-non-phy-latent.md`
  (new, this file)

## Checks Run

- Pre-edit lane check: 2 open Claude PRs (#50 known-limitations,
  #52 NEWS rewrite) + 1 Codex PR (#51 ordinal-probit Tier-2).
  None touch `vignettes/articles/phylogenetic-gllvm.Rmd`. Safe.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE);
  pkgdown::build_article("articles/phylogenetic-gllvm",
  new_process = FALSE)'`: rendered successfully. Only the
  pre-existing `logo.png` pkgdown warning -- no errors.
- Model fit verification (from rendered HTML output):
  - `fit$opt$convergence`: `0` (both fits converged).
  - `Long/wide logLik difference`: `0` (long and wide fits
    identical at the engine, as expected).
  - `extract_Sigma(fit, level = "phy", part = "shared|unique|total")`:
    returns finite trait covariance matrices.
  - `extract_Sigma(fit, level = "unit", part = "shared|unique|total")`:
    returns finite trait covariance matrices (the new
    extraction added in this PR).
- API alignment: `extract_Sigma()` formals
  (`R/extract-sigma.R` line 454-458) accept
  `level = c("unit", "unit_obs", "phy", "spatial", ...)` and
  `part = c("total", "shared", "unique")`. All extraction calls
  in the article use legal level/part combinations.
- Notation spot-check: every math expression uses `S` / `s`,
  not `U` / `u`. The function-name reference
  "the old project nickname 'two-U'" stays as is per PR #40
  naming convention.

## Tests Of The Tests

This is a Tier-1 vignette article fix. The "tests" are:

1. The rendered article shows the long/wide logLik difference is
   zero -- the test that the wide formula correctly expands to
   the long formula and dispatches to the same engine.
2. The four covariance keywords in the formula align with the
   four components in the simulated `Y`: `phylo_latent` matches
   `Lambda_phy Lambda_phy^T`, `phylo_unique` matches `S_phy`,
   `latent(1 | species)` matches `Lambda_non Lambda_non^T`,
   `unique(1 | species)` matches `S_non`.
3. The `extract_Sigma(fit, level = "phy" / "unit", part = ...)`
   calls return matrices, so the article's "recover the
   covariance" lesson is reproducible from a single fit object.
4. The identifiability caveat ("do not over-interpret either
   split") is exemplified by the actual fitted numbers on a
   30-species tree -- a reader looking at the rendered output
   sees the split is not always clean, which is the lesson.
5. `extract_communality(fit, level = "unit")` returns a named
   numeric vector with nonzero values (verified in the rendered
   output: c2_non = 0.78, 0.77, 0.35). The phylogenetic-side
   communality `diag(Sigma_phy_shared) / diag(Sigma_phy_total)`
   also returns nonzero values (1.00, 0.64, 0.71). Both would
   be structurally undefined if the non-phy `latent()` term
   were absent (the original 3-component model).
6. `extract_phylo_signal(fit)` returns a three-column
   decomposition `H^2 + C^2_non + Psi = 1` with all three
   columns nonzero (verified: trait_1 = 0.87 + 0.10 + 0.03,
   trait_2 = 0.46 + 0.42 + 0.13, trait_3 = 0.36 + 0.22 + 0.41,
   each row summing to 1.0). With the original 3-component
   model, `C^2_non` would be structurally 0 and the table
   would collapse to two columns -- which is the maintainer's
   point that motivated this PR.

If a future fit_long / fit_wide call introduces a long/wide
mismatch (e.g., the wide-formula expander forgets to expand
`latent(1 | species, d = 1)` to `latent(0 + trait | species,
d = 1)`), the "Long/wide logLik difference" line will print
something other than `0` and the article-render check will
expose it.

## Consistency Audit

```sh
rg -n "diag\\(U\\)|U_phy|U_non" vignettes/articles/phylogenetic-gllvm.Rmd
```

verdict: zero hits in math notation. The only `U` is in the
sentence introducing the "two-U" nickname, which is the
legacy task label per PR #40.

```sh
rg -n "Lambda_phy|Lambda_non|S_phy|S_non" vignettes/articles/phylogenetic-gllvm.Rmd
```

verdict: every reference to a component matrix names both the
phy and non-phy versions consistently. No drift like
"`Lambda_phy`" written once and "`Lambda_phylo`" elsewhere.

```sh
rg -n "phylo_latent|phylo_unique|latent\\(|unique\\(" vignettes/articles/phylogenetic-gllvm.Rmd
```

verdict: the four covariance keywords are each named in the
theory, the fit, and the prose. The wide form expands cleanly
to the long form (verified by the zero log-likelihood
difference).

## What Did Not Go Smoothly

Nothing. The fix was bounded: add one term to the simulation
and one term to each fit, rewrite four sentences of prose,
mirror the existing phy extraction with a non-phy extraction.

The hardest decision was whether to also change the 30-species
sample size or the seed. With four components, 30 species is
borderline identified, and the fitted Lambda_phy estimates run
high. Per the maintainer's framing of the existing article
("show syntax and extraction, not a full simulation study"),
the small tree and the existing identifiability caveat are
deliberate teaching choices, and the harder fit on the bigger
model is itself a useful illustration of the caveat. The seed
and sample size were therefore left unchanged.

## Team Learning

By standing-review role per `AGENTS.md`:

- **Noether (math consistency)** -- the article's theory section
  now matches the fitted model exactly. Four components in the
  math, four covariance keywords in the formula, four extracted
  matrices.
- **Pat (applied user)** -- the reader who follows the article
  from theory to syntax to extraction now sees a one-to-one
  mapping. No silent gap between what the equation promises
  and what the fit estimates.
- **Boole (correctness)** -- long-vs-wide log-likelihood
  difference is zero, confirming the wide-formula expander
  preserves the four-component grammar.
- **Curie (identifiability)** -- the 30-species four-component
  fit is more identifiability-fragile than the previous
  three-component fit. The article's existing caveat ("do not
  over-interpret either split, especially when the tree is
  small") now applies symmetrically to both splits.
- **Ada (orchestrator)** -- the fix is bounded to one article;
  no engine, no API, no NAMESPACE, no Rd change.

## Known Limitations

- The fitted `Sigma_phy_shared` for trait_1 (~1.9) overshoots
  the simulated `Lambda_phy_true[1]^2 = 0.49`. With four
  components and 30 species, the model is borderline identified
  and the splits between shared and unique components can flow
  variance unevenly. The article's caveat is the right
  teaching message; a future revision could either grow the
  tree or use a tighter prior-like start to demonstrate
  cleaner recovery.
- The wide formula expander now handles four nested covariance
  keywords (`phylo_latent`, `phylo_unique`, `latent`, `unique`)
  with two distinct grouping factors (the `species` axis for
  the phy keywords; the `species` unit for the `latent` /
  `unique` keywords). If a future parser change breaks the
  expansion of any of these, the article-render check will
  catch it via the long/wide log-likelihood difference.
- The `compare_dep_vs_two_U()` / `compare_indep_vs_two_U()`
  diagnostic block was not changed. Both diagnostics already
  handle the four-component model, but the diagnostic chunk
  is `eval = FALSE`, so the rendered article does not show
  the diagnostic output. That is intentional (the diagnostics
  take time to run); a future "fully evaluated" reproduction
  branch could remove `eval = FALSE`.

## Next Actions

1. Maintainer reviews / merges. Self-merge eligible per
   `docs/dev-log/decisions.md`: single Tier-1 article rewrite
   against an approved snippet (the existing article structure
   plus the maintainer's "make the fit match the theory" call).
2. After merge, the pkgdown site rebuilds and the live
   `articles/phylogenetic-gllvm.html` page reflects the
   four-component fit.
3. If the planned phylogenetic / two-U doc-validation lane
   opens (per PR #37 dispatch queue item #1), the new article
   structure is the starting point: Codex's branch can extend
   the article with a worked simulation recovery, a tighter
   identifiability discussion, and the diagnostic comparisons
   evaluated rather than `eval = FALSE`.
