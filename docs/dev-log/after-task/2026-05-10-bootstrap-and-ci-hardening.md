# After Task: Bootstrap fresh gllvmTMB v0.2.0 and CI hardening

## Goal

Bootstrap a fresh `gllvmTMB` repository from the gllvmTMB-native
subset of the legacy `itchyshin/gllvmTMB` (now renamed
`gllvmTMB-legacy`), adopt drmTMB tooling and discipline, and reach
a working main with 3-OS R-CMD-check green + live pkgdown site at
`https://itchyshin.github.io/gllvmTMB/`.

## Implemented

Three PRs, in order:

**PR #1 — `Bootstrap fresh gllvmTMB v0.2.0 from gllvmTMB-native subset + drmTMB tooling`**

- Cherry-picked the gllvmTMB-native subset from `gllvmTMB-legacy`:
  the multi-trait TMB engine (`src/gllvmTMB.cpp`, ~2000 lines), R/
  parser + extractors + methods, the 7 Tier-1 articles, the
  gllvmTMB-native test files.
- Dropped 73 sdmTMB-inherited exports (legacy single-response
  `sdmTMB()` API + fisheries-stock-assessment utilities + the entire
  `R/fit.R`, 2002 LOC). Per `_workshop/audits/standalone-cut-list.md`.
- Adopted drmTMB's 12 canonical role names in `.codex/agents/*.toml`
  and 5 invokable skills in `.agents/skills/*/SKILL.md`, with three
  gllvmTMB-specific baked-in additions:
  - symbolic-math \(\leftrightarrow\) implementation alignment table
    into `add-simulation-test/SKILL.md` (caught two real bugs on the
    legacy repo: missing \(q_{it}\) in functional-biogeography,
    `Lambda_phy_true` mismatch in phylogenetic-gllvm);
  - 2026-05-10 anti-patterns (success-complacency, coverage-of-
    acceptance, drmTMB-benchmark) into `after-task-audit/SKILL.md`;
  - new `article-tier-audit/SKILL.md` codifying the Tier-1-by-default
    rule from Pat's audit.
- Trimmed `Authors@R` `cph` entries from 20+ down to 5 (Anderson,
  Ward, English, Barnett for sdmTMB SPDE/mesh inheritance; Kristensen
  for TMB). Each surviving entry justified by surviving code paths
  (`inst/COPYRIGHTS` to follow).
- Chose vendor-mesh over `Imports: sdmTMB` (R/mesh.R, R/crs.R,
  plot_anisotropy verbatim; provenance entries in `inst/COPYRIGHTS`
  remain a pending task).
- Set up CI workflows: 3-OS R-CMD-check (ubuntu / macos / windows
  release) + pkgdown deploy-to-Pages.

**PR #2 — `fix(pkgdown): destination = pkgdown-site (match drmTMB pattern)`**

- The bootstrap put drmTMB-style scaffolding in `docs/design/` +
  `docs/dev-log/`, but pkgdown defaults to `docs/` as its OUTPUT
  directory and refuses to overwrite a non-empty `docs/` it did not
  build. PR #1's pkgdown deploy failed with
  `check_dest_is_pkgdown()` error.
- drmTMB resolves this by setting `destination: pkgdown-site` in
  `_pkgdown.yml` and uploading from `pkgdown-site/` in the workflow.
  Match the convention. `_pkgdown.yml` gets `destination:
  pkgdown-site`; `pkgdown.yaml` uploads from `pkgdown-site/`;
  `.gitignore` + `.Rbuildignore` exclude that path.
- Also cleaned a `.Rbuildignore` heredoc-leak corruption introduced
  during the bootstrap (`</content>` + `</invoke>` strings written
  literally into the file).

**PR #3 — `ci(R-CMD-check): match drmTMB exactly (5-min discipline parity)`**

- Stripped four divergences from drmTMB's R-CMD-check.yaml:
  - `timeout-minutes`: 60 → initially 30, then 45 (see fixup below);
  - `cancel-in-progress`: conditional on event_name → always `true`;
  - `check-r-package@v2` overrides
    (`--no-manual --ignore-vignettes --no-build-vignettes`) →
    defaults (vignettes built as part of R CMD check, drmTMB-style);
  - `paths-ignore` → removed (drmTMB does not have it; we commit to
    push discipline at agent level instead).
- The strict defaults exposed two unstated test dependencies the
  prior skip-args had masked, fixed in fixup commits:
  - `Add tidyselect to Suggests` — test files use `tidyselect::all_of`
    and related verbs;
  - `Add mgcv to Suggests` — `test-tweedie-recovery.R` uses
    `mgcv::rTweedie`. Proactive grep of every `pkg::` use in
    `tests/testthat/*.R` confirmed mgcv was the only remaining
    missing decl.
- `Bump Windows timeout to 45 min temporarily` — drmTMB's 30-min
  budget is sized for a ~30-export package; gllvmTMB's current
  60-export / 1250-test surface needs ~30-35 min on Windows. 45
  catches real regressions; Phase 1 ROADMAP item is to gate slow
  tests behind `RUN_SLOW_TESTS=true` and bring Windows back under 30.

## Mathematical Contract

No likelihood equations or parameter transforms changed. The
bootstrap copied the TMB engine verbatim from legacy
`inst/tmb/gllvmTMB_multi.cpp` to `src/gllvmTMB.cpp`. The covstruct
quartet semantics (`latent` / `unique` / `indep` / `dep` + phylo /
spatial prefixes) is unchanged.

## Files Changed (high-level)

| Path | Change |
|---|---|
| `src/gllvmTMB.cpp` | New, ~2000 lines, copied from legacy `inst/tmb/gllvmTMB_multi.cpp` |
| `R/` | gllvmTMB-native subset only; legacy `R/fit.R` + 73 inherited exports cut |
| `tests/testthat/` | gllvmTMB-native test files only; ~10 inherited sdmTMB test files dropped |
| `vignettes/gllvmTMB.Rmd` + `vignettes/articles/` | Get Started + 7 Tier-1 articles |
| `DESCRIPTION` | Title, Authors@R (5 cph), Imports, Suggests (tidyselect + mgcv added during PR #3) |
| `NAMESPACE` | Auto-generated, surviving exports only |
| `.codex/agents/*.toml` | 10 drmTMB-canonical role definitions |
| `.agents/skills/*/SKILL.md` | 5 drmTMB skills + 3 baked-in additions |
| `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `ROADMAP.md` | drmTMB-style discipline docs |
| `docs/design/00-vision.md`, `docs/design/10-after-task-protocol.md` | Initial design docs |
| `docs/dev-log/{check-log,decisions,known-limitations}.md` | drmTMB-style append-only logs |
| `_pkgdown.yml` | Site config; `destination: pkgdown-site` added in PR #2 |
| `.github/workflows/R-CMD-check.yaml` | 3-OS matrix, 45-min budget, drmTMB-pattern-matched in PR #3 |
| `.github/workflows/pkgdown.yaml` | Upload-from-pkgdown-site, paths-ignore for dev-only |
| `inst/COPYRIGHTS` | Initial provenance for sdmTMB code paths (full audit pending) |

## Checks Run

- **PR #1 R-CMD-check #1** (pull-request event, cold cache):
  3-OS all SUCCESS at ubuntu 23m 46s / macos 25m 39s / windows
  31m 47s.
- **PR #1 merge → on-main R-CMD-check #2**: success at ubuntu 20m /
  macos 22m / windows 29m (warm cache).
- **PR #1 merge → on-main pkgdown #1**: FAILURE
  (`check_dest_is_pkgdown`) — fixed by PR #2.
- **PR #2 R-CMD-check #4**: 3-OS all SUCCESS at 30m 57s combined.
- **PR #2 merge → on-main pkgdown #2**: SUCCESS. Site live at
  `https://itchyshin.github.io/gllvmTMB/` (returns 200).
- **PR #2 merge → on-main R-CMD-check #3**: 3-OS all SUCCESS at
  ubuntu 20m / macos 22m / windows 29m.
- **PR #3 R-CMD-check #8** (after Windows-timeout bump): 3-OS all
  SUCCESS at ubuntu 22m / macos 24m / windows 32m.

## Tests Of The Tests

- 6 tests skip-gated `skip("0.2.0: no-covstruct fallback removed")`
  (Phase 1 ROADMAP item — re-implement the no-covstruct dispatch).
- All legacy sdmTMB inherited test files dropped; only gllvmTMB-
  native tests retained (test-canonical-keywords, test-cluster-
  rename, test-traits-keyword, test-wide-weights-matrix, etc.).
- The unstated-tidyselect and unstated-mgcv warnings were both
  caught by the strict R-CMD-check defaults — i.e. the drmTMB-
  parity pass DID act as a test of the tests, surfacing real
  declaration gaps that prior skip-args had been hiding.

## Consistency Audit

- `_workshop/audits/standalone-cut-list.md`: per-export classification
  yielded ~50 keep, ~10 hide-internal, ~73 cut, 5 maintainer-
  decided (all 5 cut per the 2026-05-10 maintainer decision).
- DESCRIPTION `cph` trimmed to lockstep with the cut surface.
- All `pkg::` uses in `tests/testthat/*.R` cross-checked against
  Imports + Suggests; tidyselect and mgcv added to Suggests.
- pkgdown reference index aligns with surviving exports.

## What Did Not Go Smoothly

- **Bootstrap-agent heredoc leak**: the bootstrap agent created
  `.Rbuildignore` with three stray lines (`</content>`, `</invoke>`)
  written literally. I introduced the same corruption pattern again
  in PR #2 via my own `echo >> .Rbuildignore` inside a heredoc-
  wrapped Bash call before catching it. Lesson encoded:
  **prefer `Edit` over `echo >> file` for repo files when operating
  inside a heredoc-wrapped Bash command**.
- **drmTMB scaffolding versus pkgdown's `docs/` default**: the
  bootstrap put `docs/design/` + `docs/dev-log/` in place without
  also adding `destination: pkgdown-site` to `_pkgdown.yml`. pkgdown
  refused to overwrite the non-empty `docs/`. Lesson encoded:
  **when adopting drmTMB tooling, copy the `_pkgdown.yml` settings
  too, not just the directory structure**.
- **Windows R-CMD-check wall time**: 30 min budget too tight for
  current 60-export / 1250-test surface. Bumped to 45 as documented
  temporary. Phase 1 ROADMAP item.
- **High GitHub Actions variance on Windows**: the same code ran
  29 min on main and 32 min on PR #3 in back-to-back runs. Windows
  runners have noticeable timing variance; budget needs headroom
  beyond the median.

## Team Learning

- **drmTMB-parity strictness exposes hidden warnings**. The
  bootstrap's inherited `--no-build-vignettes` / `--ignore-vignettes`
  args were masking the unstated-tidyselect and unstated-mgcv
  warnings. PR #3's strict defaults surfaced them; we fixed the
  underlying declarations rather than re-add the skip-args.
- **One task per commit, drmTMB-named**, beats bundled fix-up
  commits. PR #3's three fixup commits (`Add tidyselect to Suggests`,
  `Add mgcv to Suggests`, `Bump Windows timeout to 45 min
  temporarily`) are each one-line project-log titles, much easier
  to review than one combined commit.
- **Class-sweep when one instance fires**: when the tidyselect
  warning surfaced, the right move was to grep ALL `pkg::` uses in
  `tests/` against Imports + Suggests, not just fix the visible
  one. That proactive sweep found mgcv before its own warning
  reached us.
- **WIP=1 + 7-10 min between pushes** prevents cancel-cascades.
  drmTMB's all-green track record correlates exactly with their
  push spacing. We adopt the same.

## Known Limitations

- **Windows R-CMD-check wall time exceeds 30 min** (currently 32m
  on PR #3 / 29m on main). Phase 1 ROADMAP item: gate slowest tests
  behind `Sys.getenv("RUN_SLOW_TESTS") != ""` so Windows fits in
  drmTMB's 30-min budget; then lower `timeout-minutes` back to 30.
- **6 tests skip-gated** for no-covstruct fallback (Phase 1 ROADMAP
  item — re-implement the no-covstruct dispatch or document as a
  permanent constraint).
- **DESCRIPTION Title is 66 chars; CRAN cap is 65.** Trim pending
  (next after-task).
- **8-10 exported functions missing `\examples{}` blocks** (CRAN
  soft-blocker; see `_workshop/audits/cran-readiness-blockers.md`).
- **`inst/COPYRIGHTS` provenance entries** for vendored mesh code
  (R/mesh.R, R/crs.R, plot_anisotropy) need to be written.
- **macOS Apple Clang quirk** `-Wfixed-enum-extension` warning
  appears in local rcmdcheck but not on Ubuntu CI; cosmetic.

## Next Actions

- `Trim Title to 28 chars for CRAN` — single-line DESCRIPTION edit.
- `Add examples block to extract_Sigma` — first of 8-10 missing
  `\examples{}` blocks needed for CRAN.
- `Add examples block to extract_communality`.
- `Document vendored mesh provenance in inst/COPYRIGHTS`.
- Phase 1 ROADMAP: profile + gate slow tests for Windows; bring
  `timeout-minutes` back to 30.
- Phase 1 ROADMAP: re-implement no-covstruct fallback OR document
  as permanent constraint; un-skip the 6 gated tests accordingly.
