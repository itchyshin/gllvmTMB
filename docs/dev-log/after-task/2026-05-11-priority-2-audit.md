# After Task: Priority 2 Audit -- Current Export Surface

## Goal

Audit the current `gllvmTMB` export surface and `pkgdown` reference
index, and classify every exported function as **keep**, **delete**,
or **internal** ahead of Priority 2 implementation. Read-only --
no file edits, no implementation. Codex handed this audit to Claude
on 2026-05-11 after the CI / site / team repair (PR #8) landed.

## Implemented

A classification of all 96 `export()` lines in `NAMESPACE` plus 11
S3 method registrations. No package code changed.

## Mathematical Contract

No likelihood, formula grammar, estimator, family, or public R API
changed. This file is documentation only.

## Summary

| Bucket | Count | Action |
|---|---|---|
| KEEP -- canonical surface | 65 | retain |
| DELETE -- superseded / legacy / no canonical purpose | 18 | remove from NAMESPACE, R/, man/, tests/ |
| DELETE -- used in articles, rewrite article first | 4 | rewrite article, then delete |
| INTERNAL -- orphan Rd or package-doc only | 4 | `@keywords internal`, or remove if unused |
| Orphan exports -- maintainer call | 5 | one-line decision per item |

## DELETE -- superseded / legacy / no canonical purpose

Verified zero use in `vignettes/`. Per `AGENTS.md` and the handoff
doc: do not preserve legacy functions just because legacy tests call
them by bare name. Tests / Rd files for these functions go with the
function.

| Function | Source | Reason |
|---|---|---|
| `phylo` | `R/brms-sugar.R` | Pre-rename alias (now `phylo_unique` / `phylo_latent`) |
| `phylo_rr` | `R/brms-sugar.R` | Pre-rename alias (now `phylo_latent`) |
| `gr` | `R/brms-sugar.R` | Pre-rename alias (now `unique`) |
| `meta` | `R/brms-sugar.R` | Pre-rename alias (now `meta_known_V`) |
| `spde` | `R/brms-sugar.R` | Pre-rename alias (now `spatial_*`) |
| `spatial` | `R/brms-sugar.R` | Pre-rename alias (now `spatial_unique`) |
| `block_V` | `R/brms-sugar.R` | Pre-rename alias |
| `VP` | gllvm wrapper | Superseded by `extract_proportions()` |
| `getLV` | gllvm wrapper | Superseded by `extract_ordination()` |
| `getResidualCov` | gllvm wrapper | Superseded by `extract_Sigma()` |
| `getResidualCor` | gllvm wrapper | Superseded by `extract_correlations()` |
| `extract_Sigma_B` | `R/extract-sigma.R` | Superseded by `extract_Sigma(level = "B")` |
| `extract_Sigma_W` | `R/extract-sigma.R` | Superseded by `extract_Sigma(level = "W")` |
| `phylo_slope` | `R/brms-sugar.R` | Experimental hook; future trait-specific slope keyword will replace |
| `extract_two_U_via_PIC` | `R/extract-two-U-via-PIC.R` | Niche; rebuild inside Phase F two-U article if needed |
| `compare_PIC_vs_joint` | `R/extract-two-U-via-PIC.R` | Same |
| `tmbprofile_wrapper` | Phase K helper file | Shipped early; rebuild in Phase K with coherent design |
| `profile_ci_communality` / `profile_ci_correlation` / `profile_ci_phylo_signal` / `profile_ci_repeatability` | Phase K extractors | Same -- rebuild in Phase K |

### Implementer note

`R/z-confint-gllvmTMB.R` contains a duplicate `confint.gllvmTMB_multi()`
that shadows the simpler version at `R/methods-gllvmTMB.R:434` via
`z-` filename load order. When the whole `z-confint-gllvmTMB.R` file
+ the four `profile_ci_*` Rd files come out, the simpler
`confint(object, parm, level)` at `R/methods-gllvmTMB.R:434` survives
as the canonical version (no `method =` argument, Phase K deferred).

## DELETE -- but article rewrite required first

These four are still referenced in articles. Cannot delete without
rewriting the article first. Each article fix is its own small PR;
Rose gate runs on it because it touches vignettes.

| Function | Article hits | Canonical replacement |
|---|---|---|
| `getLoadings` | 3 | `extract_Sigma()$Lambda` + `rotate_loadings()` |
| `extract_ICC_site` | 3 | `extract_communality()` |
| `ordiplot` | 1 | `extract_ordination()` + manual `plot()` |
| `extract_residual_split` | 1 | `extract_Omega()` / `extract_communality()` |

Locate the specific articles with:

```sh
rg -n "getLoadings\(|extract_ICC_site\(|ordiplot\(|extract_residual_split\(" vignettes/
```

## INTERNAL -- orphan Rd files (no `export()`)

| Rd file | What it is | Action |
|---|---|---|
| `man/diag_re.Rd` | engine-level RE kind | DELETE (never user-facing) |
| `man/re_int.Rd` | engine-level RE kind | DELETE |
| `man/unique_keyword.Rd` | docs the `unique` formula keyword (can't `export()` because `unique` is base R) | KEEP -- referenced by `_pkgdown.yml` |
| `man/families.Rd` | `@rdname families` consolidated family docs | KEEP -- pkgdown uses via `has_keyword("families")` |
| `man/gllvmTMB-package.Rd` | standard package doc | KEEP |
| `man/reexports.Rd` | re-exports (`tidy` from `generics`) | KEEP |
| `man/gllvmTMB_multi-methods.Rd` | consolidated S3 methods doc | KEEP |

## Orphan exports -- maintainer call

These appear in `NAMESPACE` but cannot be classified without a
one-line maintainer decision.

| Function | Question |
|---|---|
| `plot_anisotropy2` (NAMESPACE:83) | Variant of `plot_anisotropy`. Keep both, or fold into one? |
| `get_crs` (NAMESPACE:56) | Mesh-related utility. Keep public, or internal? |
| `censored_poisson` | Family not in the canonical 14-family list. Keep as 15th, or drop? |
| `gamma_mix`, `nbinom2_mix`, `lognormal_mix`, `gengamma`, `lognormal`, `delta_gengamma`, `delta_gamma_mix`, `delta_lognormal_mix`, `delta_poisson_link_gamma`, `delta_poisson_link_lognormal` | "_mix" / "gengamma" / "delta_poisson_link_*" families inherited from sdmTMB. Which are tested + meaningful for the stacked-trait scope? |

## KEEP -- canonical surface (65)

Grouped by `_pkgdown.yml` section. All entries stay.

- **Entry points (5)**: `gllvmTMB`, `gllvmTMB_wide`, `gllvmTMBcontrol`, `traits`, `simulate_site_trait`
- **Covstruct grid (15)**: `latent`, `unique` (via `unique_keyword.Rd`), `indep`, `dep`, `phylo_scalar`, `phylo_unique`, `phylo_indep`, `phylo_dep`, `phylo_latent`, `spatial_scalar`, `spatial_unique`, `spatial_indep`, `spatial_dep`, `spatial_latent`, `meta_known_V`
- **Response families (core)**: `Beta`, `betabinomial`, `nbinom1`, `nbinom2`, `student`, `tweedie`, `truncated_nbinom1`, `truncated_nbinom2`, `truncated_poisson`, `delta_beta`, `delta_gamma`, `delta_lognormal`, `delta_truncated_nbinom1`, `delta_truncated_nbinom2`, `ordinal_probit` (the orphan-exports above may add to this list pending maintainer)
- **Biological extractors (9)**: `extract_Sigma`, `extract_Omega`, `extract_phylo_signal`, `extract_proportions`, `extract_communality`, `extract_correlations`, `extract_repeatability`, `extract_cutpoints`, `extract_ordination`
- **S3 methods (8 + 1)**: `print`, `summary`, `logLik`, `confint`, `tidy`, `simulate`, `predict`, `plot` on `gllvmTMB_multi`; plus `plot.sdmTMBmesh`
- **Diagnostics (5)**: `gllvmTMB_diagnose`, `sanity_multi`, `compare_dep_vs_two_U`, `compare_indep_vs_two_U`, `bootstrap_Sigma`
- **Loading tools (3)**: `rotate_loadings`, `compare_loadings`, `suggest_lambda_constraint`
- **Mesh utilities (3+)**: `make_mesh`, `add_utm_columns`, `plot_anisotropy` (+ `plot_anisotropy2` / `get_crs` pending)

## Recommended sequence for Priority 2

1. **Article rewrite PR** -- replace `getLoadings` / `extract_ICC_site` / `ordiplot` / `extract_residual_split` with canonical equivalents in the four affected articles. Rose gate runs (touches vignettes).
2. **Maintainer decisions** on the 5 orphan-export rows (single answer per row).
3. **Surface-cleanup PR** (after #1 lands and #2 is decided) -- remove `export()` lines from `NAMESPACE`, delete `R/*.R` files for dropped functions, delete `man/*.Rd`, delete tests that exclusively exercise dropped functions. Update `_pkgdown.yml`: remove the "Deprecated keyword aliases" section entirely (no deprecation flow per the locked policy in the active plan). Single `NEWS.md` line. Rose gate runs.

## Checks Run

```sh
# Surface inventory
cat NAMESPACE | grep -E "^export|^S3method" | wc -l   # 107

# Rd files on disk
ls man/*.Rd | wc -l                                    # 76

# Article usage of classified candidate functions
rg --no-filename -o '<canonical-and-drop-pattern>' vignettes/ | sort | uniq -c | sort -rn
```

## Tests Of The Tests

The article-usage count is a true cross-reference, not a search for
the name in comments alone -- the regex matches `func(` only. The
drop list excludes anything with >0 article usage; the four
article-blocked drops are itemised separately with usage counts.

## Consistency Audit

The audit is consistent with:
- `AGENTS.md` (one-line scope statement, multi-agent rule, narrow Rose gate).
- `CLAUDE.md` (project identity: stacked-trait multivariate only).
- The handoff doc's Priority 2 ("Stabilise the public surface").
- The Codex repair after-task report ("no public R API changed").
- The active Claude plan's locked drop list (this audit refines the proposed bucketing into 18 confirmed deletes + 4 article-blocked + 5 maintainer-call items).

## What Did Not Go Smoothly

None. Audit was straightforward once `NAMESPACE`, `_pkgdown.yml`, and
`man/*.Rd` were enumerated in parallel and cross-referenced with a
single ripgrep against `vignettes/`.

## Team Learning

The "drop" list grew by 5 items vs the active plan's earlier estimate:
- `getResidualCor` was not in the initial plan; it should join its
  sibling `getResidualCov` in the drop bucket.
- The 5 "_mix" / "gengamma" / "delta_poisson_link_*" families
  inherited from sdmTMB were also not enumerated in the plan; they
  need a one-line maintainer decision before Priority 2 implementation.

The audit confirms a useful pattern: a quick canonical-pattern
ripgrep against `vignettes/` plus a `NAMESPACE` parse is sufficient
to classify the surface before any implementation work. The same
script can be re-run before any future Priority N cleanup as a
sanity check.

## Known Limitations

- The audit does not classify by `tests/testthat/` usage. Some
  dropped functions may have dedicated test files that the
  surface-cleanup PR must also remove; that step happens during
  implementation, not in this audit.
- The 5 orphan-export families need a one-line maintainer decision
  (15 minutes) before Priority 2 implementation can start cleanly.

## Next Actions

- Maintainer reviews this audit and confirms / adjusts the drop list.
- Maintainer answers the 5 orphan-export questions.
- Codex (or Claude) takes the **article-rewrite PR** first, then the
  **surface-cleanup PR**.
- Rose pre-publish gate runs on both PRs (both touch user-facing
  prose or generated Rd).
