# After-Task: Reference index "site × species" → "unit × trait" sweep

## Goal

Fix the reference-index drift the maintainer flagged at
<https://itchyshin.github.io/gllvmTMB/reference/index.html> on
2026-05-12: `gllvmTMB_wide()` was described as "Fit a GLLVM from a
wide site × species matrix", and `simulate_site_trait()` as
"stacked-trait, site-by-species GLLVM dataset". Both descriptions
leaned into the ecological special case (site × species) when the
package is intentionally generic over the `(unit, trait)` layout:
site × species, individual × trait, species × trait,
paper × outcome, and so on.

This is a Rose-style cross-file consistency drift, not an API
change. The functions and their parameter names are unchanged; only
roxygen titles, descriptions, and the `@param` wording move from
the site/species framing to the generic `unit / trait` framing
(with site/species kept as one example among several).

The PR also picks up two stale Rd files left over from PR #26's
citation-cleanup: `make_mesh.Rd` (title still said
"for sdmTMB" -- the roxygen was updated but `devtools::document()`
was not run at the time) and `gllvmTMB-package.Rd` (Description
text and Authors block both stale relative to the post-#26
DESCRIPTION). Regenerating fixes both.

After-task report added at branch start per `CONTRIBUTING.md`.

## Implemented

- **`R/gllvmTMB-wide.R`** (M):
  - Title: `Fit a GLLVM from a wide site × species matrix`
    → `Fit a GLLVM from a wide unit × trait matrix`.
  - Description: "convenience wrapper that lets users supply a
    site-by-species matrix" → "a wide `unit × trait` response
    matrix (rows = units, columns = traits)".
  - Added a paragraph naming the four canonical use cases: site ×
    species (JSDM), individual × trait (morphometrics /
    behavioural syndromes), species × trait (phylogenetic
    comparative), paper × outcome (meta-analysis).
  - `@param Y`: `n_sites × n_species` → `n_units × n_traits`;
    "unique sites / unique species" → "unique units / unique
    traits".
  - `@param X`: `n_sites` → `n_units`; "site-level predictors"
    → "unit-level predictors".
  - `@param phylo_vcv`: `n_species x n_species` → `n_traits x
    n_traits`, with a sentence noting that for the canonical
    site × species use case the "traits" are species, so the
    correlation matrix is the species-level phylogeny.
  - `@return`: "species column is exposed as the 'trait' axis"
    → "column dimension of Y is exposed as the 'trait' axis",
    with examples for the four use cases.
  - File-top comment block updated to the generic framing.
- **`R/simulate-site-trait.R`** (M):
  - Title: `Simulate a stacked-trait, site-by-species GLLVM dataset`
    → `Simulate a functional-biogeography GLLVM dataset
    (sites × species × traits)`.
  - Added one paragraph clarifying that the simulator is
    *domain-specific* -- it produces a `(site, species, trait)`
    cube for the methods-paper functional-biogeography model --
    and pointing readers at inline simulation in the morphometrics
    article for simpler `(unit, trait)` designs.
  - Parameter names (`n_sites`, `n_species`, `n_traits`) and the
    underlying equations are unchanged.
- **`man/gllvmTMB_wide.Rd`** (M): regenerated from the new
  roxygen.
- **`man/simulate_site_trait.Rd`** (M): regenerated.
- **`man/make_mesh.Rd`** (M): regenerated. The current Rd was
  stale relative to `R/mesh.R`'s roxygen, which PR #26 updated
  ("for sdmTMB" → "for gllvmTMB" + an `spatial_*()` keyword
  pointer) without running `devtools::document()`. This PR
  catches that up.
- **`man/gllvmTMB-package.Rd`** (M): regenerated. The current Rd
  was stale relative to PR #26's DESCRIPTION: Description text
  didn't include Kristensen et al. (2016), and the Authors block
  still listed the deprecated `cph` entries (Anderson, Ward,
  English, Barnett, Kristensen). Regenerating brings the package
  help page (`?gllvmTMB`) into agreement with main.
- **`docs/dev-log/after-task/2026-05-12-site-species-to-unit-trait.md`**
  (NEW, this file).

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE,
generated Rd-vs-source mismatch (after this PR), vignette content,
or pkgdown navigation change. Roxygen wording + regenerated Rd
only. The functions, their signatures, and their parameter names
are untouched.

## Files Changed

- `R/gllvmTMB-wide.R`
- `R/simulate-site-trait.R`
- `man/gllvmTMB_wide.Rd` (regenerated)
- `man/simulate_site_trait.Rd` (regenerated)
- `man/make_mesh.Rd` (regenerated; back-fills PR #26)
- `man/gllvmTMB-package.Rd` (regenerated; back-fills PR #26)
- `docs/dev-log/after-task/2026-05-12-site-species-to-unit-trait.md`
  (new, this file)

## Checks Run

- **Pre-edit lane check**: 1 open PR (#29, Air format) on
  different files (CONTRIBUTING.md / `air.toml` /
  `.github/workflows/air-format.yaml`); no overlap with `R/` or
  `man/`. Codex's `codex/phase3-weights-unified` is local-only on
  the maintainer's machine and has not yet pushed; no `R/` files
  modified by this PR are listed in Codex's branch-start
  after-task report ("R/" not enumerated in Files Created Or
  Changed -- still TBC). Safe to proceed.
- **`Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`**:
  wrote `gllvmTMB_wide.Rd`, `make_mesh.Rd`, `simulate_site_trait.Rd`,
  `gllvmTMB-package.Rd`. No errors.
- **Reference-page rewording cross-check**:
  `rg -n "site.{0,3}(×|x|by).{0,3}species" R/ man/` post-edit
  shows only domain-appropriate mentions: `R/gllvmTMB.R` `@param`
  examples (one of four parallel use cases), `R/fit-multi.R`
  internal comment (out of scope -- internal, not Rd), and one
  acknowledging sentence in `R/gllvmTMB-wide.R`'s `@param
  phylo_vcv` ("for the canonical site × species use case ..."),
  which is exactly the place to mention it as an example.

## Tests Of The Tests

This is a documentation drift fix with no behavioural change.
The implicit "test" is the post-merge pkgdown rebuild: the
public reference page should read "Fit a GLLVM from a wide unit
× trait matrix" and "Simulate a functional-biogeography GLLVM
dataset (sites × species × traits)" after deployment. Verify by
opening the deployed `reference/index.html` after the workflow_run
pkgdown deploy completes on main.

If a future PR introduces another roxygen-vs-Rd drift (e.g.,
updates `R/<file>.R` without running `devtools::document()`),
this PR's pattern -- always include the regenerated Rd in the
same commit -- is the right discipline; PR #26 was the recent
counterexample.

## Consistency Audit

```sh
rg -n "site.{0,3}(×|x|by).{0,3}species|site-by-species|site_by_species" R/ man/ vignettes/ README.md NEWS.md
```

post-edit verdict: every remaining mention is domain-appropriate
(article-level prose in `functional-biogeography.Rmd`, balanced
`@param` examples in `R/gllvmTMB.R`, internal source comments,
and one explicit "canonical use case" mention in
`gllvmTMB_wide()`'s `@param phylo_vcv`). No reference-page title
or description still frames the package as site-by-species-only.

```sh
rg -n "unit × trait|unit by trait|n_units|n_traits" R/gllvmTMB-wide.R man/gllvmTMB_wide.Rd
```

verdict: the new generic framing appears consistently in both
the roxygen source and the regenerated Rd.

```sh
diff <(rg -c "site|species|individual|paper|outcome" R/gllvmTMB-wide.R) old-counts.txt
```

(not run -- count check is not a meaningful test for prose drift;
the manual review above is the gate.)

## What Did Not Go Smoothly

- The regenerated Rd files surfaced two stale entries from PR #26
  that I authored: `man/make_mesh.Rd` (roxygen title was updated,
  Rd was not) and `man/gllvmTMB-package.Rd` (Description and
  Authors block were stale relative to DESCRIPTION). The post-PR
  CI gate did not catch these because `R CMD check` does not flag
  roxygen-vs-Rd drift (only code-vs-Rd, which is different).
  Recording this as a lesson for the post-edit checklist: when
  any R file's roxygen changes, the same commit must run
  `devtools::document()` and stage the regenerated Rd.

## Team Learning

By standing-review role per `AGENTS.md`:

- **Ada (orchestrator)** kept the scope narrow: roxygen +
  regenerated Rd only; no API or behaviour change; the stale
  Rd from PR #26 brought in incidentally but inside the same
  consistency theme.
- **Rose (cross-file consistency)** is the lead role here. The
  drift was flagged by the maintainer looking at the deployed
  reference index; Rose's audit pattern is the right one for
  catching this kind of public-facing wording drift earlier.
- **Pat (applied user / new contributor)** is the implicit
  beneficiary: a reader landing on `?gllvmTMB_wide` or the
  reference index no longer sees gllvmTMB framed as a site ×
  species package; they see the generic `unit × trait` framing
  with their actual domain (morphometrics, meta-analysis, ...)
  represented as an example.
- **Darwin (biology audience)** does not engage: this is wording
  cleanup, not a biological-interpretation change.
- **Grace (CI / pkgdown / CRAN)** is the silent beneficiary of
  the regenerated Rd: post-merge `R CMD check` no longer ships
  with an obvious-on-inspection (though not blocking) doc drift.

## Known Limitations

- `R/gllvmTMB.R` internal source comments (lines 393, 415, 464)
  still use "site × species data" as historical framing. These
  are private comments, not user-visible, and out of scope for a
  reference-page consistency PR. A future "internal comment
  cleanup" sweep could update them; it does not block this PR.
- The `simulate_site_trait()` function itself is genuinely
  domain-specific (a `(site, species, trait)` cube). Renaming
  it to something generic would be a breaking API change. The
  new title and description make the domain scope explicit
  instead.
- The PR does not amend `vignettes/articles/functional-biogeography.Rmd`,
  which still uses "site-by-species" language. That article is
  explicitly about the site × species case; the language is
  domain-appropriate there.

## Next Actions

1. Maintainer reviews / merges. Self-merge eligible: roxygen +
   Rd-regen only, no source behaviour change.
2. After merge, the deployed reference index should show the
   corrected titles. Verify at
   <https://itchyshin.github.io/gllvmTMB/reference/index.html>
   once the workflow_run pkgdown deploy completes on main.
3. **Unification of `gllvmTMB()` + `gllvmTMB_wide()`** remains
   queued -- the maintainer approved it conditional on Codex's
   Phase 3 PR landing first. Once Codex's PR merges, the
   unification becomes a small follow-up that builds on this
   PR's `unit × trait` framing (so the unified entry point is
   already presented generically in the reference page).
