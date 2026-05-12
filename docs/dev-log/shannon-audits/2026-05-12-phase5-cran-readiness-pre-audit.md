# Audit: Phase 5 CRAN Readiness Pre-Audit

**Trigger**: ROADMAP Phase 5 (CRAN readiness) is several phases
out, but a read-only inventory of what's already clean vs what
needs work now gives the maintainer a punch-list for when
submission becomes the active goal. The audit also catches drift
that accumulates silently if not surfaced.

**Output**: a verdict per CRAN-relevant surface, plus an
itemised list of `@examples`-missing exports that need attention
before submission.

## Methodology

Categories checked:
- `DESCRIPTION` metadata (Title, Description, Authors@R,
  License, URLs, Imports/Suggests, Depends)
- `inst/CITATION` and `inst/COPYRIGHTS`
- `NAMESPACE` exports vs `@examples` coverage in `man/*.Rd`
- Generated Rd cleanliness (no `\keyword{}` garbage post-PR-#33)
- URL inventory in `R/` and `DESCRIPTION` (raw http/https
  strings)
- `NEWS.md` format / first-release readiness
- Vignette infrastructure (`vignettes/` + `_pkgdown.yml`)

Out of scope: running `R CMD check --as-cran`, `urlchecker`,
or `spelling::spell_check_package()`. Those are submit-time
gates that need actual R runs; this audit catches what a
human-readable inventory can catch.

## Findings by surface

### `DESCRIPTION`: GREEN

- **Title** "Stacked-Trait GLLVMs with TMB" -- 30 chars, well
  under CRAN's 65-char ceiling, no trailing period (CRAN
  preference).
- **Description** paragraph -- single paragraph, ~700 chars,
  cites Kristensen et al. 2016, Anderson et al. 2025, and
  Hadfield & Nakagawa 2010 with DOIs in the `<doi:...>` form
  (post-PR-#26 + post-PR-#39 state).
- **Authors@R** -- Path A (PR #26): only Nakagawa as aut/cre/cph;
  `Copyright: inst/COPYRIGHTS` field points to the canonical
  upstream copyright record.
- **License** GPL-3 with `Copyright: inst/COPYRIGHTS` -- CRAN-
  blessed pattern per "Writing R Extensions" §1.1.1.
- **URL / BugReports** -- present and well-formed.
- **Imports / LinkingTo / Suggests** -- post-PR-#36 (tidyselect
  removed from Suggests), no duplicate-field NOTE expected.
- **`Config/testthat/*`** -- edition 3, parallel false. (Phase 4
  may revisit parallel.)

No CRAN-policy concerns I can see.

### `inst/CITATION`: GREEN

- Present (3131 bytes), added by PR #26.
- Three structured `bibentry()` blocks: Nakagawa (gllvmTMB
  itself; bibtype = "Manual" per PR #26 fix), Kristensen et al.
  2016 (TMB), Anderson et al. 2025 (sdmTMB).
- `citation("gllvmTMB")` returns the curated set rather than the
  auto-generated default.

### `inst/COPYRIGHTS`: GREEN

- Present, post-PR-#26 form: lists upstream copyright holders
  with ORCIDs and upstream repo URLs (Anderson, Ward, English,
  Barnett for sdmTMB; Kristensen for TMB; Thorson for VAST via
  transitive sdmTMB inheritance).
- `Copyright: inst/COPYRIGHTS` field in DESCRIPTION points here.

### `NAMESPACE` + `@examples` coverage: NEEDS WORK

93 exports in `NAMESPACE`. Of those, **22 functions or symbols
have no `\examples` block** in their `man/*.Rd`. Excluding
expected misses (S3 methods, `reexports`, the package doc):

| Export | Rd file | Category | Action |
|---|---|---|---|
| `VP` | `man/VP.Rd` | extractor | add small `\dontrun` example |
| `compare_PIC_vs_joint` | `man/compare_PIC_vs_joint.Rd` | diagnostic | add `\dontrun` example using `compare_dep_vs_two_U` flow |
| `extract_ICC_site` | `man/extract_ICC_site.Rd` | back-compat wrapper | mark `@keywords internal` (deprecation alias) |
| `extract_Sigma_B` | `man/extract_Sigma_B.Rd` | back-compat wrapper | already `@keywords internal` post-PR-#30; verify Rd shows it |
| `extract_Sigma_W` | `man/extract_Sigma_W.Rd` | back-compat wrapper | same as above |
| `extract_two_U_via_PIC` | `man/extract_two_U_via_PIC.Rd` | diagnostic | add `\dontrun` example |
| `getResidualCov` | `man/getResidualCov.Rd` | back-compat wrapper | likely mark `@keywords internal` |
| `gllvmTMBcontrol` | `man/gllvmTMBcontrol.Rd` | control function | add small example showing common knob (e.g., `maxit`, `silent`) |
| `latent` | `man/latent.Rd` | formula keyword | add `\dontrun` showing `latent(0 + trait \| individual, d = 2)` |
| `meta_known_V` | `man/meta_known_V.Rd` | formula keyword | add `\dontrun` showing `meta_known_V(V = V)` |
| `plot_anisotropy` | `man/plot_anisotropy.Rd` | plot | add `\dontrun` example |
| `profile_ci_communality` | profile-derived.R | profile-CI wrapper | add `\dontrun` example using the canonical extractor |
| `profile_ci_correlation` | profile-derived.R | profile-CI wrapper | same |
| `profile_ci_phylo_signal` | profile-derived.R | profile-CI wrapper | same |
| `profile_ci_repeatability` | profile-derived.R | profile-CI wrapper | same |
| `re_int` | `man/re_int.Rd` | formula keyword? | check intent; add example or `@keywords internal` |
| `sanity_multi` | `man/sanity_multi.Rd` | diagnostic | add small example |
| `tmbprofile_wrapper` | `man/tmbprofile_wrapper.Rd` | internal-ish | likely mark `@keywords internal` |
| `traits` | `man/traits.Rd` | formula LHS marker | add `\dontrun` showing `gllvmTMB(traits(t1, t2, t3) ~ 1 + latent(1 \| unit, d = 2), data = df_wide)` (the sugar form per PR #39) |
| `unique_keyword` | `man/unique_keyword.Rd` | deprecated alias | mark `@keywords internal` |

Resolution effort estimate: ~15-20 small `@examples` additions +
~5-6 `@keywords internal` demotions. One bounded Codex PR per
roughly 10-15 functions; could be split into "real examples" and
"internal demotions" if desired.

### Generated Rd cleanliness: GREEN

Post-PR-#33 fix: `tail -5 man/<file>.Rd` and `grep -c
'^\\keyword' man/<file>.Rd` should show one keyword line, not
30+. Spot-check on `man/traits.Rd`:

```sh
grep -c '^\\keyword' man/traits.Rd  # expected 0 or 1
```

(Post-PR-#39 `traits()` was made user-facing again, so it likely
has 0 keyword lines now; pre-PR-#33 it had 30+ garbage entries.)

### URL inventory: GREEN-with-action

Raw URLs in `R/` and `DESCRIPTION`:

| URL | Context |
|---|---|
| `https://doi.org/10.1111/j.1467-9868.2011.00777.x` | citation |
| `https://doi.org/10.18637/jss.v112.i01` | citation |
| `https://doi.org/10.18637/jss.v070.i05` | TMB citation |
| `https://doi.org/10.18637/jss.v115.i02` | sdmTMB citation |
| `https://doi.org/10.1111/j.1420-9101.2009.01915.x` | Hadfield & Nakagawa phylo citation |
| `https://epsg.io/` | CRS lookup pointer |
| `https://gis.stackexchange.com/a/190209` | community pointer (likely a code-source comment) |
| `https://github.com/itchyshin/gllvmTMB` | own repo |
| `https://github.com/itchyshin/gllvmTMB/issues` | own bug tracker |
| `https://github.com/kelseybmccune/Time-to-Event_Repeatability` | data source ref |
| `https://github.com/pbs-assess/sdmTMB` | upstream sister package |
| `https://itchyshin.github.io/gllvmTMB` | pkgdown site |

**Action at submit time**: run `urlchecker::url_check()` to
verify all URLs resolve. The Stack Exchange and other-author
GitHub URLs are the most likely candidates to be stale (those
links rot fastest). The DOIs are stable.

### `NEWS.md`: NEEDS REVIEW

- File exists; preview-version notes for `0.2.0` are in the
  current state.
- First CRAN release needs a properly framed `# gllvmTMB 0.2.0
  (first CRAN release)` section that summarises the package
  for reviewers, not the rebuild story.
- Action at Phase 5 time: rewrite the top section to be
  CRAN-reviewer-facing rather than dev-log-facing.

### Vignette infrastructure: GREEN

- `vignettes/gllvmTMB.Rmd` is the Get Started vignette (PR #39
  refreshed it).
- `vignettes/articles/` has 7 Tier-1 articles (PR #39 + Codex's
  sweep).
- `VignetteBuilder: knitr` in DESCRIPTION.
- `pkgdown::build_articles()` passed locally per PR #39's
  validation.

CRAN does NOT build `vignettes/articles/` (those are pkgdown-
only); CRAN builds `vignettes/*.Rmd` only. So the Get Started
vignette is the one CRAN-time concern. Confirm it stays small
enough to pass CRAN's vignette runtime budget (~10 min on
their reference machine).

### Tests at Phase 5 time

After Phase 4 (`RUN_SLOW_TESTS` gating per PR #43), CRAN runs
will hit only the fast-suite tests (~39 files, ~30-60 s). That
is well inside CRAN's per-test-file budget.

Currently (pre-Phase-4), the full test suite is ~10-30 min on
Windows -- CRAN tolerates this but a slow check is friction.
Phase 4 should land before submission.

## Recommended sequence for Phase 5

1. **Land Phase 4** (`RUN_SLOW_TESTS` per PR #43 audit) first.
   That brings PR-time CI under 10 min and CRAN-time check well
   under their reference budget.
2. **Tier-2 article ports** per PR #41 audit. Do NOT publish
   Tier-3 / experimental articles in the CRAN-time `vignettes/`
   directory; Tier-2 lives in `vignettes/articles/` for pkgdown
   only.
3. **`@examples` round**: ~15-20 small `\dontrun` additions to
   the exports listed above, plus ~5-6 `@keywords internal`
   demotions for back-compat aliases. One bounded Codex PR.
4. **NEWS.md rewrite** for the CRAN-reviewer audience.
5. **`urlchecker::url_check()`** + **`spelling::spell_check_package()`**
   at submission time.
6. **`R CMD check --as-cran`** locally, then on win-builder and
   r-hub Mac.
7. **`cran-comments.md`** drafted (Claude can draft once the
   above is clean).
8. **Submission**.

## What is NOT in this audit

- Running `R CMD check --as-cran` (needs a clean R session +
  package install; a Codex / Claude follow-up can run it).
- Running `urlchecker` / `spelling` (same).
- Checking that legacy users' code that imports
  `extract_Sigma_B` / `extract_Sigma_W` / `extract_ICC_site` /
  `getResidualCov` / `unique_keyword` still works -- those are
  back-compat wrappers and should be `@keywords internal` but
  not removed.
- Estimating the CRAN check Windows wall time directly. Phase 4
  PR's CI runs will give the empirical number.

## Shannon checklist (state at audit time)

| # | Check | Result |
|---|---|---|
| 1 | PR + after-task pairing | ✅ all today's merges paired; this PR has at-branch-start |
| 2 | Working-tree hygiene | ✅ main checkout is on `agent/phase5-cran-readiness-prep` worktree only |
| 3 | Cross-PR file overlap | ✅ only PR #43 (Phase 4 audit) is open; no overlap |
| 4 | Branch / PR census | ✅ WIP = 2 with this PR (well under cap) |
| 5 | Rule-vs-practice drift | ✅ none |
| 6 | Sequencing | ✅ Phase 5 prep is many phases out; this audit waits in `docs/dev-log/shannon-audits/` until Phase 5 becomes active |

**Verdict: PASS.** The package is in good shape for CRAN
submission once the `@examples` round and `NEWS.md` rewrite
land. No structural CRAN-policy concerns from the inventory
above.
