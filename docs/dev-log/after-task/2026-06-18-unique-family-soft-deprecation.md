# After Task: `unique()` Family Soft Deprecation

**Date:** 2026-06-18 17:11 MDT
**Branch:** `codex/r-bridge-grouped-dispersion`
**Guard:** `PR green != bridge complete != release ready != scientific coverage passed`

## Goal

Finish the next narrow post-coevolution compatibility slice: add parser-level
soft-deprecation warnings for `unique()` / source-specific `*_unique()` /
`kernel_unique()` while preserving existing compatibility rewrites and fitted
paths.

## Implemented

- Added `.gllvmTMB_warn_unique_family_deprecated()` in `R/brms-sugar.R`.
- Routed `unique()`, `phylo_unique()`, `animal_unique()`,
  `spatial_unique()`, and `kernel_unique()` through
  `lifecycle::deprecate_soft()`.
- Added `tests/testthat/test-unique-family-deprecation.R` to assert the
  lifecycle warning and the preserved parser rewrites.
- Quieted lifecycle warnings in old compatibility fixtures where the test is
  about coevolution/kernel behavior, not deprecation behavior.
- Updated roxygen, generated Rd, NEWS, formula grammar, AGENTS/CLAUDE keyword
  guidance, and dashboard JSON.

## Mathematical Contract

No TMB likelihood, covariance parameterization, family, or fitted model equation
changed. The parser still maps the compatibility syntax to the same internal
terms as before. The only behavioral change is a soft lifecycle warning when
the `unique()` family is parsed.

The explicit-Psi model remains:

```text
Sigma = Lambda Lambda^T + Psi
```

where `Psi` is the diagonal trait-unique variance matrix. Standalone diagonal
models should now be taught as `indep()` / `*_indep()`; paired explicit-Psi
forms remain accepted until the later latent-Psi fold/removal slice lands.

## Files Changed

- `R/brms-sugar.R`
- `R/unique-keyword.R`
- `R/animal-keyword.R`
- `R/kernel-keywords.R`
- `tests/testthat/test-unique-family-deprecation.R`
- `tests/testthat/test-brms-sugar.R`
- `tests/testthat/test-canonical-keywords.R`
- `tests/testthat/test-coevolution-two-kernel.R`
- `tests/testthat/test-example-coevolution-kernel.R`
- `tests/testthat/test-keyword-grid.R`
- `tests/testthat/test-spatial-orientation.R`
- `man/animal_unique.Rd`
- `man/unique_keyword.Rd`
- `man/phylo_unique.Rd`
- `man/spatial_unique.Rd`
- `man/kernel_latent.Rd`
- `man/diag_re.Rd`
- `NEWS.md`
- `docs/design/01-formula-grammar.md`
- `AGENTS.md`
- `CLAUDE.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## Checks Run

- Pre-edit lane check:
  - `gh pr list --state open` showed only draft PR #489.
  - `git log --all --oneline --since="6 hours ago"` showed the current
    coevolution stack on this branch.
  - `git diff --check` was clean before edits.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  regenerated the Rd files.
- `Rscript --vanilla -e 'devtools::test(filter = "unique-family-deprecation", reporter = "summary")'`
  passed after fixing a duplicate `spatial_unique()` warning and a brittle
  deparse assertion.
- `Rscript --vanilla -e 'devtools::test(filter = "unique-family-deprecation|canonical-keywords|keyword-grid|brms-sugar|spatial-deprecation|spatial-orientation|kernel-equivalence", reporter = "summary")'`
  passed with only three expected INLA skips.
- `Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution", reporter = "summary")'`
  passed after lifecycle warnings were muffled in compatibility fixtures; 14
  expected heavy skips were reported.
- `GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution", reporter = "summary")'`
  passed with no skips shown by testthat.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  returned `No problems found.`
- `python3 -m json.tool docs/dev-log/dashboard/status.json >/dev/null && python3 -m json.tool docs/dev-log/dashboard/sweep.json >/dev/null && git diff --check`
  passed.

## Tests Of The Tests

The new lifecycle test is a feature-combination parser test: it covers all five
members of the `unique()` family and then checks that the old rewrites still
produce the expected compatibility terms. The coevolution fixtures separately
verify that lifecycle warnings do not mask the C3 two-Psi identifiability
warning or its single-`kernel_unique()` negative control.

## Consistency Audit

- `rg -n 'no parser-wide deprecation|without adding parser-wide|parser deprecation is not claimed|No parser-wide lifecycle/deprecation warning' NEWS.md docs/dev-log/dashboard/status.json docs/dev-log/dashboard/sweep.json docs/design/01-formula-grammar.md CLAUDE.md AGENTS.md R man tests/testthat`
  found no current stale "no parser deprecation" claims in the active
  status/code surface.
- `for f in man/animal_unique.Rd man/unique_keyword.Rd man/phylo_unique.Rd man/spatial_unique.Rd man/kernel_latent.Rd man/diag_re.Rd; do printf '%s keywords=' "$f"; grep -c '^\\keyword' "$f"; tail -5 "$f"; done`
  found no runaway Rd keyword blocks.
- `rg -n '\bS_B\b|\bS_W\b|\\bf S' R/animal-keyword.R R/brms-sugar.R R/kernel-keywords.R R/unique-keyword.R NEWS.md docs/design/01-formula-grammar.md CLAUDE.md AGENTS.md man/animal_unique.Rd man/unique_keyword.Rd man/phylo_unique.Rd man/spatial_unique.Rd man/kernel_latent.Rd tests/testthat/test-unique-family-deprecation.R`
  found no legacy S-notation hits in the touched surface.
- `rg -n '\bphylo\(|\bgr\(|\bmeta\(|block_V\(|phylo_rr\(' NEWS.md docs/design/01-formula-grammar.md CLAUDE.md AGENTS.md R/animal-keyword.R R/brms-sugar.R R/kernel-keywords.R R/unique-keyword.R man/animal_unique.Rd man/unique_keyword.Rd man/phylo_unique.Rd man/spatial_unique.Rd man/kernel_latent.Rd`
  found existing alias-documentation/compatibility references and known
  `block_V()` status text, not new `unique()` deprecation drift.

## Team Learning

Ada kept the slice narrow: warn now, preserve compatibility now, defer removal
and the latent-Psi fold. Boole's syntax concern is recorded in the tests:
compatibility rewrites remain stable while the parser tells users where the API
is headed. Rose caught the status-story flip: the earlier sweep correctly said
there was no parser deprecation, but the current dashboard/NEWS now has to say
soft-deprecated. Curie's test angle was to keep the new lifecycle warning from
masking the real coevolution warning assertions.

## Status Inventory

`NEWS.md`, `docs/design/01-formula-grammar.md`, `AGENTS.md`, `CLAUDE.md`, and
the local mission-control dashboard now describe the `unique()` family as
soft-deprecated compatibility syntax. The validation-debt row anchors remain
`FG-05`, `FG-06`, `FG-07`, `PHY-02`, `ANI-03`, `ANI-11`, `KER-02`, `KER-03`,
`COE-03`, and `COE-04` as appropriate. No `_pkgdown.yml`, README, or ROADMAP
entry changed in this slice.

## Roadmap Tick

N/A. This was a compatibility/lifecycle cleanup inside the current
coevolution/grammar arc, not a public roadmap status-chip change.

## GitHub Issue Ledger

- `gh issue list --state open --search "unique deprecation" --limit 10`
  surfaced #361, #230, and unrelated roadmap issue #341.
- `gh issue list --state open --search "coevolution" --limit 10`
  confirmed #361 remains the relevant open coevolution/kernel tracker.
- No issue was commented, closed, or created from this unpushed local slice.

## Known Limitations

- No `unique()` API removal.
- No `latent()` auto-Psi fold.
- No extractor contract change for `part = "unique"`.
- No free-correlation `unique()` / reaction-norm redesign.
- No Paper 2 multi-kernel explicit-Psi support.
- No bridge completion, release readiness, or scientific coverage completion.

## Next Actions

Treat the coevolution model and first `unique()` soft-deprecation slice as
locally closed. The next grand-plan item is the real `unique()` family
deprecation/removal design work: decide the latent-Psi fold, extractor
semantics, free-correlation reaction-norm replacement, and user migration path
before escalating beyond soft warnings.
