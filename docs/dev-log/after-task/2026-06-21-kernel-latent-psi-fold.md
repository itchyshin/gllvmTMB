# After Task: kernel_latent() default Psi fold

## Goal

Carry Stage A of the latent migration forward after the animal fold:
make one named `kernel_latent()` tier carry its dense-kernel diagonal Psi
companion by default, matching ordinary `latent()`, `phylo_latent()`, and
`animal_latent()`, while keeping `unique = FALSE` as the loadings-only escape
hatch.

## Implemented

`kernel_latent(unit, K = A, d = q, name = "known")` now rewrites to the
existing dense `phylo_rr(..., vcv = A)` reduced-rank path plus an automatic
`phylo_rr(..., .phylo_unique = TRUE, .auto_unique = TRUE, vcv = A,
.kernel_mode = "unique")` companion.

`kernel_latent(..., unique = FALSE)` preserves the older loadings-only route.
The explicit compatibility spelling
`kernel_latent(..., unique = FALSE) + kernel_unique(...)` remains accepted and
is byte-equivalent to the folded default for one named dense-kernel tier.

For two or more named `kernel_latent()` tiers, the parser still emits the same
default companion per term, but `R/fit-multi.R` prunes those auto-generated
kernel Psi companions before the existing multi-kernel guard. That preserves the
first multi-kernel engine wave as latent-only while leaving user-written
`kernel_unique()` terms visible to the explicit-Psi guard.

## Mathematical Contract

For one named dense-kernel latent tier, the fitted trait covariance associated
with kernel `K` is now

```text
Sigma_kernel = (Lambda Lambda^T) \otimes K + Psi_kernel \otimes K
```

where `Psi_kernel` is the diagonal trait-specific companion on the same dense
between-unit kernel. In R syntax:

```r
kernel_latent(unit, K = A, d = q, name = "known")
```

targets the same model as:

```r
kernel_latent(unit, K = A, d = q, name = "known", unique = FALSE) +
  kernel_unique(unit, K = A, name = "known")
```

The loadings-only subset is now explicit:

```r
kernel_latent(unit, K = A, d = q, name = "known", unique = FALSE)
```

This task does not change `src/gllvmTMB.cpp`, the TMB likelihood, the dense
kernel numerical engine, or the SPDE engine. It is a formula-rewriter,
dedup/pruning, test, and documentation slice over the already-existing dense
`vcv` path.

## Files Changed

- `R/brms-sugar.R`: `kernel_latent()` validates `unique`, emits the automatic
  kernel Psi companion by default, and preserves `unique = FALSE` as
  loadings-only.
- `R/fit-multi.R`: auto-generated kernel Psi companions are pruned when two or
  more named latent kernel tiers are present, before the existing explicit-Psi
  guard.
- `R/kernel-keywords.R`: `kernel_latent()` gains `unique = TRUE` and updated
  roxygen for the folded default and multi-kernel boundary.
- `R/unique-keyword.R`: source-specific diagonal guidance now includes the
  folded kernel syntax and leaves only spatial pending.
- `R/extract-sigma.R`: the kernel `part = "unique"` diagnostic now distinguishes
  one-kernel folded Psi from latent-only multi-kernel fits.
- `tests/testthat/test-kernel-latent-unique-fold.R`: new parser, error, and
  Gaussian default-vs-explicit equivalence tests.
- `tests/testthat/test-kernel-equivalence.R`: the loadings-only
  dense-phylo-equivalence test now opts into `unique = FALSE`.
- `tests/testthat/test-coevolution-two-kernel.R`: one-component comparators and
  collapsed comparator fits now opt into `unique = FALSE` where the legacy
  two-kernel evidence is explicitly latent-only.
- `man/kernel_latent.Rd` and `man/diag_re.Rd`: regenerated help touched by the
  roxygen updates.
- `NEWS.md`, `docs/design/01-formula-grammar.md`,
  `docs/design/35-validation-debt-register.md`, and
  `docs/design/2026-06-21-source-specific-latent-psi-fold.md`: convention
  cascade, validation ledger, and Stage-A design progress updates.
- `docs/dev-log/check-log.md` and this report: audit trail.

## Checks Run

- RED-first:
  `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-kernel-latent-unique-fold.R", reporter = "summary")'`
  failed before implementation because the parser did not emit the automatic
  companion, `unique = FALSE` did not select the loadings-only route, and
  malformed `unique` values were not rejected.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` completed;
  unrelated generated Rd churn was removed before staging.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-kernel-latent-unique-fold.R", reporter = "summary")'`
  passed (`kernel-latent-unique-fold: .......................`).
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-kernel-equivalence.R", reporter = "summary")'`
  passed (`kernel-equivalence: ......................................`).
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-coevolution-two-kernel.R", reporter = "summary")'`
  passed under normal env; expected heavy gates skipped.
- `GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-coevolution-two-kernel.R", reporter = "summary")'`
  first failed because one-kernel comparators inherited the new default Psi and
  invalidated legacy latent-only likelihood-gap thresholds. After retargeting
  those comparators to `unique = FALSE`, the same command passed.
- `Rscript --vanilla -e 'devtools::test()'` passed:
  `[ FAIL 0 | WARN 10 | SKIP 745 | PASS 3445 ]`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` passed:
  `No problems found`.
- `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'` failed in
  existing article-render debt:
  `vignettes/articles/lambda-constraint-suggest.Rmd`, chunk
  `profile-confidence-eye`, where `loading_ci(fit_pr, level = "unit", method =
  "wald")` correctly rejects an unconstrained loading fit. This is not a kernel
  fold regression.
- `Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'`
  completed with `0 errors, 1 warning, 0 notes`. The warning was local
  Apple-clang/R-header install noise:
  `R_ext/Boolean.h:62:36: warning: unknown warning group
  '-Wfixed-enum-extension', ignored [-Wunknown-warning-option]`.
- Plain persistent `rcmdcheck::rcmdcheck(args = "--no-manual")` errored because
  local Suggests `mirt` and `nadiv` are not installed. The persistent rerun with
  `_R_CHECK_FORCE_SUGGESTS_=false` completed with `0 errors, 1 warning,
  0 notes`, the same local clang warning.
- Rendered-Rd spot check:
  `tail -5 man/kernel_latent.Rd && grep -c '^\\keyword' man/kernel_latent.Rd || true && tail -5 man/diag_re.Rd && grep -c '^\\keyword' man/diag_re.Rd || true`
  showed no keyword tag in `man/kernel_latent.Rd` and the expected one
  `\keyword{internal}` in `man/diag_re.Rd`.
- Post-#527 rebase validation on 2026-06-22:
  `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` completed;
  the focused kernel fold test, kernel equivalence test, normal two-kernel
  test, and heavy two-kernel gate all passed; `devtools::test()` passed
  `[ FAIL 0 | WARN 10 | SKIP 745 | PASS 3445 ]`;
  `pkgdown::check_pkgdown()` passed; `git diff --check` passed.
  `devtools::check(args = "--no-manual", quiet = TRUE)` completed with
  `0 errors, 1 warning, 1 note` but returned nonzero because this wrapper
  treats warnings as errors. A persistent rerun with
  `_R_CHECK_FORCE_SUGGESTS_=false` completed with `0 errors, 1 warning,
  0 notes`; the warning was the known local Apple-clang/R-header warning.

## Tests Of The Tests

The new test file satisfies the failure-before-fix rule: it failed before the
rewriter emitted the automatic kernel Psi companion and before invalid `unique`
values were rejected. It covers the boundary/error path (`unique = NA`), the
loadings-only escape hatch (`unique = FALSE`), parser metadata for the generated
companion, and the feature-combination path where an explicit `kernel_unique()`
pair remains byte-equivalent to the folded default.

The heavy two-kernel rerun caught a real test-contract issue: one-kernel
comparators were no longer latent-only after the default changed. Retargeting
those comparators to `unique = FALSE` keeps the COE-04 likelihood-gap evidence
about the same latent-only model it was designed to test.

## Consistency Audit

Exact scans:

- `rg -n 'remaining `spatial_latent` / `kernel_latent`|Dense-kernel latent-Psi folding remains|kernel_latent\(\.\.\.\) alone do|kernel_latent\(unit, K = A, d = q\) \+ kernel_unique|same dense `kernel_latent \+ kernel_unique` grammar|kernel_latent\(\) keep their explicit|kernel_latent\(\) remains next|kernel_latent` remains next' R docs/design NEWS.md tests/testthat man`
  returned no matches; no current source says kernel is still pending or
  requires paired syntax as primary.
- `rg -n 'kernel_latent|kernel_unique|KER-02|KER-03|COE-03|unique = FALSE|spatial_latent' NEWS.md R/kernel-keywords.R R/unique-keyword.R R/extract-sigma.R man/kernel_latent.Rd man/diag_re.Rd docs/design/01-formula-grammar.md docs/design/35-validation-debt-register.md docs/design/2026-06-21-source-specific-latent-psi-fold.md tests/testthat/test-kernel-latent-unique-fold.R tests/testthat/test-kernel-equivalence.R tests/testthat/test-coevolution-two-kernel.R`
  returned expected current fold references, loadings-only comparator
  retargeting, multi-kernel latent-only limitations, and historical test
  coverage references.
- `rg -n '\bS_B\b|\bS_W\b|\\bf S' NEWS.md R/kernel-keywords.R R/unique-keyword.R man/kernel_latent.Rd man/diag_re.Rd docs/design/01-formula-grammar.md docs/design/35-validation-debt-register.md docs/design/2026-06-21-source-specific-latent-psi-fold.md`
  returned no matches.
- `rg -n 'gllvmTMB\(' R/kernel-keywords.R man/kernel_latent.Rd NEWS.md docs/design/01-formula-grammar.md`
  returned expected package/news/design call sites; the new kernel roxygen
  example is a wide `traits(...)` call and correctly omits `trait =`.
- `rg -n 'meta_known_V|gllvmTMB_wide|\bphylo\(|\bgr\(|\bmeta\(|block_V\(|phylo_rr\(' NEWS.md R/kernel-keywords.R R/unique-keyword.R man/kernel_latent.Rd man/diag_re.Rd docs/design/01-formula-grammar.md docs/design/35-validation-debt-register.md`
  returned expected historical/deprecated-alias and internal-route references;
  no new kernel user-facing primary example uses those aliases.
- `rg -n 'in prep|in preparation' docs/design/01-formula-grammar.md docs/design/35-validation-debt-register.md NEWS.md R/kernel-keywords.R`
  returned no matches.

Status inventory: `NEWS.md`, `R/kernel-keywords.R`, generated
`man/kernel_latent.Rd`, `man/diag_re.Rd`, `docs/design/01-formula-grammar.md`,
`docs/design/35-validation-debt-register.md`, and the Stage-A design note were
updated. `README.md`, `ROADMAP.md`, `_pkgdown.yml`, and vignettes did not need
changes for this single exported keyword cascade.

Roadmap tick: N/A. The latent migration is tracked in the Stage-A design and
dev-log handoff rather than a public `ROADMAP.md` progress row.

GitHub issue ledger: inspected open issues matching
`kernel_latent OR kernel_unique OR KER-02 OR KER-03`; relevant open trackers
are #361 (generic kernel engine), #340 (capability matrix), and #526 (spatial
blocker). Inspected `spatial_latent SPDE diagonal Psi`; no direct matches beyond
#526 appeared in that query. Inspected
`lambda-constraint-suggest OR loading_ci OR profile-confidence-eye`; #230 and
#340 remain the broad article/status trackers for the pre-existing article
render debt. No issue was closed and no new issue was created in this stacked
local slice.

## What Did Not Go Smoothly

`air format` initially reformatted too much of `R/fit-multi.R` and
`R/extract-sigma.R`. That mechanical churn was reversed and only the semantic
kernel hunks were reapplied.

The first heavy two-kernel rerun failed for a good reason: the default change
made one-kernel comparators stronger than the latent-only comparators intended
by the old COE-04 tests. The fix was to mark those comparators
`unique = FALSE`, not to loosen thresholds.

`pkgdown::build_articles(lazy = FALSE)` still fails on the known
`lambda-constraint-suggest.Rmd` unconstrained-loading Wald-CI example. That
needs a separate docs hardening slice before the migration can claim a fully
green article-render gate.

## Team Learning

Ada kept the slice scoped to the dense-kernel path. The spatial fold remains
blocked because it needs a confirmed SPDE diagonal companion engine slot; this
task did not try to paper over that blocker.

Boole checked the grammar contract: `unique = TRUE` is the default,
`unique = FALSE` is loadings-only, and explicit `kernel_unique()` remains
compatibility syntax rather than the primary teaching path.

Gauss checked that no TMB likelihood or parameter transform changed. Numerical
risk was covered through the Gaussian equivalence gate and the heavy
two-kernel recovery rerun, not through C++ review.

Noether checked the symbolic/R alignment: the R formula target and prose both
state that `Lambda Lambda^T` and diagonal `Psi_kernel` are scaled by the same
dense kernel `K`.

Curie checked that tests cover parser emission, malformed input, the
loadings-only escape hatch, default-vs-explicit equivalence, and the hidden
two-kernel comparator regression.

Grace checked package gates: focused tests, heavy two-kernel recovery, full
`devtools::test()`, pkgdown index, and `R CMD check` all reached either pass or
known local environment/article-render limitations.

Rose checked stale wording and validation-debt alignment. The key distinction
is now explicit: one named `kernel_latent()` folds Psi by default, while the
multi-kernel first wave remains latent-only.

Shannon checked coordination state before shared dev-log/design edits: #527 is
the parent stacked PR, and no unrelated open PR was editing the same lane.
After #527 merged, the branch was rebased onto `origin/main`; the open-PR
census returned empty, the only recent local branch movement was the #527 merge
plus an unrelated power-pilot branch, and the post-rebase Rose pre-publish
audit passed.

## Known Limitations

- `spatial_latent()` remains blocked by #526 until the SPDE engine can estimate
  an additive low-rank spatial field plus per-trait diagonal spatial field in
  one fit.
- Two-or-more named `kernel_latent()` tiers remain latent-only in the first
  multi-kernel engine wave; auto-generated kernel Psi companions are pruned for
  that path.
- Explicit multi-kernel `kernel_unique()` Psi remains deferred and guarded.
- The pre-existing `lambda-constraint-suggest.Rmd` render failure still blocks
  a fully green article-render gate for the migration.
- This branch was originally stacked on #527; after explicit maintainer
  approval, #527 merged and this branch was rebased onto `origin/main`
  `b3fc729`.

## Next Actions

1. Open the kernel fold PR after the active main pkgdown run from #527
   finishes.
2. Wait for GitHub Actions on the kernel PR before any follow-up push.
3. Keep `spatial_latent()` parked on #526 until the SPDE diagonal companion
   engine slot is confirmed.
4. Put the `lambda-constraint-suggest.Rmd` render failure and Stage B
   stale-doc hardening on the next docs-hardening list.
