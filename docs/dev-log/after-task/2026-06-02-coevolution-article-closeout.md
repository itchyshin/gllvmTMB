# Coevolution Article Closeout

Date: 2026-06-02

Branch: `docs/coev-kernel-article`

Scope: finish the public `cross-lineage-coevolution` article for the
already merged Design 65 C2 coevolution kernel path. This closeout adds
the article, a portable example fixture, a generator, a light fixture
test, pkgdown navigation, NEWS/register/design-note alignment, and a
back-link from the phylogenetic article. It does not change TMB code,
formula grammar, or exported function signatures.

## Files Touched

- `NEWS.md`: adds the public worked-example entry and updates the prior
  `extract_Gamma()` entry from "article planned" to "article shipped".
- `_pkgdown.yml`: adds `articles/cross-lineage-coevolution`.
- `docs/design/35-validation-debt-register.md`: extends `COE-02` with
  the public workflow article as evidence.
- `docs/design/65-cross-lineage-coevolution-kernel.md`: marks the C2.4
  article/data-condition side as covered and keeps C2.3 helper API open.
- `vignettes/articles/cross-lineage-coevolution.Rmd`: new Tier-1 worked
  example with paired wide `traits(...)` and long-format calls, null
  comparison, `extract_Gamma()`, and `rho` grid-profile code.
- `vignettes/articles/phylogenetic-gllvm.Rmd`: adds alt/caption metadata
  to the touched plot and links to the new coevolution article.
- `data-raw/examples/make-coevolution-kernel-example.R`: generator for
  the article fixture.
- `inst/extdata/examples/coevolution-kernel-example.rds`: portable
  teaching fixture; no fitted TMB objects stored.
- `tests/testthat/test-example-coevolution-kernel.R`: checks fixture
  contract, kernel alignment, and long/wide fit agreement.
- `docs/dev-log/check-log.md`: records this closeout.

## Verification

- `devtools::test(filter = "example-coevolution-kernel")`: PASS 33,
  FAIL 0, WARN 0, SKIP 0.
- `devtools::test(filter = "coevolution|kernel-equivalence")`: PASS 86,
  FAIL 0, WARN 0, SKIP 3 expected heavy-gate skips.
- `pkgdown::check_pkgdown()`: No problems found.
- Targeted render of
  `vignettes/articles/cross-lineage-coevolution.Rmd`: PASS, final output
  under `/tmp/gllvmTMB-coev-render`.
- `pkgdown::build_articles(lazy = FALSE)`: not claimed as passed. Without
  a temporary install it failed at the touched article because the
  subprocess loaded an installed namespace lacking `make_cross_kernel()`;
  after temporary install it rendered the coevolution article
  successfully and was stopped later on unrelated `joint-sdm.Rmd` after
  more than five minutes.
- `git diff --check`: clean.
- Stale-wording scan: only expected `rho` point-estimate/future-estimate
  boundaries and existing registry/NEWS compatibility mentions.
- Figure visual review: PASS for the Gamma truth/fitted/null heatmap.

## Review Roles

- Ada / integration: PASS for a narrow article closeout; no engine or
  formula grammar was changed.
- Boole / formula: PASS. The public calls use the existing
  `kernel_latent()` + `kernel_unique()` grammar and the long-format call
  passes `trait = "trait"` explicitly.
- Curie / simulation: PASS by reuse of the merged C2 recovery gate plus
  this slice's light article-fixture test; no new likelihood or estimator
  was added.
- Fisher / inference: PASS with limitation. The article advertises point
  estimates only, treats `rho` as a sensitivity-grid workflow parameter,
  and does not claim calibrated intervals.
- Pat / article-tier: PASS after adding the early model-shape block and
  first-use term glosses.
- Florence / figure: PASS for the rendered Gamma comparison heatmap.
- Rose / pre-publish: PASS for touched coevolution prose/navigation:
  `COE-02` and `KER-02` are cited, and IN / PARTIAL / PLANNED boundaries
  are present in the article and NEWS.
- Grace / pkgdown: PASS for targeted article render and
  `pkgdown::check_pkgdown()`; WARN that the full article sweep was not
  completed after the touched article had rendered.
- Shannon / coordination: WARN. Open PRs at handoff are #420 (clean,
  CI success), #421 (CI in progress, file-level validation-register
  overlap), #422 (CI in progress, no coevol file overlap), and #369
  (draft/dirty). The coevol PR should call out register/check-log
  file-level overlap with #420/#421 and rebase if either merges first.

## Definition Of Done Status

1. Implementation: PR-ready locally; not final done until merged on
   `main` with CI.
2. Simulation recovery: no new simulation gate required for this article
   slice; C2 recovery remains covered by `test-coevolution-recovery.R`.
3. Documentation: source article, NEWS, pkgdown nav, validation row, and
   Design 65 note are updated.
4. Runnable user-facing example: present in
   `vignettes/articles/cross-lineage-coevolution.Rmd`, using the RDS
   fixture under `inst/extdata/examples/`.
5. Check-log: this report is paired with the check-log entry above.
6. Review pass: local Pat/Rose/Florence/Grace checks complete; Shannon
   handoff is WARN because nearby open PRs touch shared coordination
   files.

## Open Boundary

The current working tree also contains unrelated slope/status edits in
`docs/design/61-capability-status.md` and unrelated hunks in shared files.
Those should not be included in the coevolution article PR unless the
maintainer explicitly wants to combine lanes.
