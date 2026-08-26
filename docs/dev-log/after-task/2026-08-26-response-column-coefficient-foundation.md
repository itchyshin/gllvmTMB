# After Task: Response-column coefficient foundation (Arc 1)

## 1. Goal

Freeze and implement the data and parser foundation for a future
response-column `*_coef()` family without changing the TMB likelihood,
exporting new coefficient helpers, or changing existing fitted models.

## 2. Implemented

Arc 1 adds a trailing `column_data` argument to `gllvmTMB()`. It aligns
response-column metadata by exact keys, joins metadata after long or wide
preparation, and restricts the joined fields to ordinary fixed effects. It
also adds internal parsing for `column_coef()`, `phylo_coef()`,
`animal_coef()`, `kernel_coef()`, and `spatial_coef()`, plus the internal
wide-form `shared()` marker. Valid coefficient syntax reaches a deliberate
classed fence before engine construction; malformed syntax fails earlier with
specific classes.

The implementation preserves existing positional calls by adding
`column_data` last. Existing `traits(...)` expansion and every released
`*_slope()` helper retain their previous routes. The five coefficient marker
names and `shared()` remain unexported and absent from the public reference
index.

## 3. Mathematical Contract

Design 131 freezes the future coefficient block as

$$
B \sim \operatorname{MN}(0, K_\rho, \Sigma_{\mathrm{coef}}),
\qquad
\operatorname{Cov}\{\operatorname{vec}(B^\mathsf{T})\}
= K_\rho \otimes \Sigma_{\mathrm{coef}},
$$

with

$$
K_\rho = \rho K + (1-\rho)\operatorname{diag}(K).
$$

Arc 1 estimates neither $B$, $\Sigma_{\mathrm{coef}}$, nor $\rho$. It adds
no TMB data, parameters, likelihood contribution, covariance extractor, or
interval method. This is a parser and keyed-data contract, not a new fitted
random-effect family. Design 130 remains the contract for the released
slope-only family.

## 3a. Decisions and Rejected Alternatives

Arc 1 deliberately chose a fail-closed parser foundation instead of aliasing
the released `*_slope()` engine. The latter fixes the supplied source
correlation, omits a random intercept, and therefore cannot silently stand in
for the proposed intercept-and-slope `K_rho` mixture. A single five-source
engine PR was rejected because it would combine API naming, covariance math,
source alignment, estimation, and teaching before any one slice had recovery
evidence. Public exports and a wide tutorial were also rejected for Arc 1:
parser recognition is not evidence that a model can be fitted.

## 4. Files Touched

- `AGENTS.md`: refreshed the active response-column coefficient lane pointer
  while retaining the canonical multi-lane handover as the start surface.
- `R/column-coef-foundation.R`: exact-key metadata preparation, internal
  coefficient parsers, overlap oracle, `shared()` rewrite, and engine fence.
- `R/gllvmTMB.R`: trailing `column_data` argument, long/wide integration,
  fixed-only and grouping guards, marker parsing, and pre-engine stop.
- `R/traits-keyword.R`: data-aware wide expansion and internal common-effect
  handling while preserving user-defined `shared()` functions.
- `tests/testthat/test-column-coef-foundation.R`: independent Arc 1 oracles.
- `man/gllvmTMB.Rd`: regenerated usage and `column_data` argument text. This
  generated help file did change; no helper reference topic was created.
- `docs/design/131-response-column-coefficient-foundation.md`: authoritative
  future model, metadata, rho, overlap, and deferral contract.
- `docs/design/01-formula-grammar.md`: partial/internal Arc 1 grammar status.
- `docs/design/35-validation-debt-register.md`: FG-20 partial foundation row.
- `docs/dev-log/check-log.md`: exact command and outcome receipt.
- `docs/dev-log/after-task/2026-08-26-response-column-coefficient-foundation.md`:
  this report.
- `docs/dev-log/handover/2026-07-25-active-lane-split.md`: added the Arc 1
  ownership boundary without superseding or absorbing sibling lanes.
- `docs/dev-log/handover/2026-08-26-codex-handover.md`: recorded the exact
  carried-over PR, CI, merge, and next-task gates for the Codex continuation.
- `docs/dev-log/handover/2026-08-26-response-column-coefficient-arc2.md`:
  bounded continuation contract.

`README.md`, `NEWS.md`, `ROADMAP.md`, `_pkgdown.yml`, `NAMESPACE`, public
articles, vignettes, TMB sources, and existing slope documentation are
unchanged.

## 5. Checks Run

```sh
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_dir("tests/testthat", filter = "^(column-coef-foundation|traits-keyword|fixed-column-slope-family)$", reporter = "summary", stop_on_failure = TRUE)'
# PASS. Two pre-existing CRAN-gated skips.

Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_dir("tests/testthat", filter = "^(phylo-slope-rhs-routing|ordinary-column-slope-phylo-coexistence|spatial-column-slope|animal-slope-recovery|phylo-column-slope-indep)$", reporter = "summary", stop_on_failure = TRUE)'
# PASS. Heavy recovery cells remained behind their existing opt-in gates;
# pre-existing unused-cluster warnings were unchanged.

Rscript --vanilla -e 'devtools::document(quiet = TRUE)'
# PASS. Updated man/gllvmTMB.Rd; three pre-existing S3 export reminders.

Rscript --vanilla -e 'pkgdown::check_pkgdown()'
# PASS: No problems found.

Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'
# BASELINE FAILURE after all other articles rendered: the unchanged
# where-does-the-tree-go.Rmd asks extract_Sigma(..., level = "column_slope"),
# which the released extractor rejects. The article is byte-identical to the
# Arc 1 baseline and is owned by the separate slope/article lane.

git diff --check
# PASS.
```

A full `devtools::test()` run was started, then deliberately interrupted before
completion when independent review found parser boundary defects. It is not
claimed. After repair, the focused foundation, traits, and slope-regression
sets above were rerun. No simulation campaign was run because Arc 1 admits no
likelihood or estimand.

## 6. Tests of the Tests

The metadata tests are boundary oracles: they permute keys, reject missing,
extra, duplicate, empty and `NA` keys, protect all four internal wide carriers,
and prevent metadata from entering grouping, covariance, offset, or coefficient
bases. The wide tests are feature-combination oracles: they compare long/wide
preparation, preserve old response-specific expansion, verify common
`shared()` model matrices, and preserve a user-defined function named
`shared`.

The parser tests are grammar oracles: all five sources, `|` versus `||`, the
three explicit bases, fixed and estimable rho intent, formula-environment rho,
top-level placement, malformed bases/groups, multiple-source rejection, and rank-saturation rejection are
checked before the deliberate engine fence. The slope and `traits()` tests are
regression oracles. No recovery test is appropriate until Arc 2 adds a real
coefficient likelihood.

## 7a. Issue Ledger

The GitHub API could not be reached from this environment. No issue was
inspected, commented, closed, or created, and no tracker state is inferred.
Arc 2 obligations are therefore recorded in the committed handover and FG-20;
a tracker issue should be reconciled when network access returns.

## 8. Consistency Audit

```sh
rg -n 'export\((column_coef|phylo_coef|animal_coef|kernel_coef|spatial_coef|shared)\)' NAMESPACE
# PASS when empty: no new marker is exported.

git diff 1bacee9a...HEAD -- NAMESPACE _pkgdown.yml src
# PASS when empty: no export, navigation, or TMB change.

rg -n 'column_data|shared\(|column_coef|phylo_coef|animal_coef|kernel_coef|spatial_coef' R tests docs/design man/gllvmTMB.Rd README.md NEWS.md vignettes _pkgdown.yml NAMESPACE
# PASS after classification: occurrences are the internal implementation,
# tests, Design 131/canonical status boundaries, the gllvmTMB argument help,
# and pre-existing article text that says column_coef is not current API.

rg -n 'column_slope_wide_unsupported|traits_has_column_slope' R tests
# PASS: the released slope-only wide guard remains present and unchanged.

rg -n 'vec\(B|K_\\rho|rho.*variance share|response-column' docs/design/131-response-column-coefficient-foundation.md
# PASS: coefficient vectorisation, raw-scale-preserving rho blend, and the
# statement that rho is not generically a variance share are explicit.

rg -n 'column_data|column_coef|phylo_coef|animal_coef|kernel_coef|spatial_coef' README.md ROADMAP.md NEWS.md docs/dev-log/known-limitations.md _pkgdown.yml
# PASS after classification: no public status or navigation claim was added;
# only internal status/limitation records mention the future family.
```

## 9. What Did Not Go Smoothly

GitHub network access was blocked, and the original worktree's shared Git
metadata was read-only. Work continued in an exact local clone of the recorded
`origin/main` snapshot `1bacee9a808b4106ce681502463baa317dcb9d9b`; live
remote freshness could not be re-established. The original dirty article
worktree was not touched.

Initial independent review found that metadata could overwrite internal wide
carriers, metadata could enter covariance/grouping terms, nested markers could
escape validation, fixed rho symbols were not evaluated in the formula
environment, and a user-defined `shared()` could be captured. Each defect
received a focused failing test and a bounded repair. The full article render
then exposed an unrelated baseline `column_slope` extractor failure; Arc 1 did
not widen into that active article lane.

The unlazy Node checker was unavailable because this environment has no Node
runtime. The acceptance ledger was therefore re-verified manually with its
exact R, `rg`, Git, and documentation commands; the missing checker is recorded
rather than silently treated as evidence.

## 10. Known Residuals

The branch is a committed local foundation, not a merge-ready public feature.
Arc 2 must select one coefficient source, align symbolic math to TMB layout,
implement its likelihood, add independent known-DGP recovery and extractor
contracts, decide `screen_gllvmTMB()` parity, and pass three-OS CI before any
helper is exported or taught. Wide helper parsing, keyed species attributes in
public tutorials, non-Gaussian multi-predictor coefficients, latent predictor
covariance, intervals, multiple simultaneous coefficient sources, and a general
rho retrofit for the 5 x 3 grid remain deferred.

## 11. Team Learning

**Ada:** isolating the work at an exact local remote-tracking snapshot avoided
mixing the new design with the dirty article lane. Next time, remote freshness
and Git writeability should be established before design work begins.

**Jason:** comparison with `gllvm` separated the desired future coefficient
mixture from the released fixed-tree `*_slope()` family. The useful lesson is
to freeze the covariance equation before naming helpers.

**Noether:** corrected the trait-major matrix-normal vectorisation and forced
rho to be described as correlation strength under a raw-scale-preserving blend,
not automatically a variance share. Future engine work must reproduce this
exact ordering.

**Curie:** independent tests found the practical contract defects before an
engine existed. The most valuable tests combined boundaries: metadata with
wide carriers, marker nesting, formula environments, and grouped fixed means.

**Emmy:** kept `column_data` trailing for positional compatibility and placed
the fence before desugaring/TMB construction. Arc 2 must preserve that staging
instead of turning the inert parser into accidental partial support.

**Grace:** distinguished the live documented `column_data` argument from the
unexported coefficient helpers and identified `screen_gllvmTMB()` propagation
as a later parity decision. She also classified the article-render failure as
baseline rather than Arc 1 evidence.

**Rose:** required the authoritative design to state the same reserved-name and
top-level-placement rules as code/tests, and caught the false draft claim that
generated Rd was unchanged. Closure documents are part of the implementation
contract, not an optional summary.

## 12. Cross-Product Coverage

| Surface | Arc 1 status | Evidence |
| --- | --- | --- |
| long metadata | covered at parser/data level | exact-key, permutation, collision, and fixed-only tests |
| wide metadata | covered at parser/data level | synthetic-key, long/wide alignment, carrier, and custom-trait guards |
| common wide fixed effects | internal partial | `shared()` model-matrix and compatibility tests |
| all five coefficient names | parser-only | exact basis/source/bar/rho tests plus pre-engine fence |
| released `*_slope()` family | protected, unchanged | focused slope regression filters |
| likelihood/recovery/extractors/intervals | blocked/deferred | no TMB route; FG-20 remains partial |
| non-Gaussian and broad wide coefficient grammar | blocked/deferred | Design 131 and Arc 2 handover |

Arc 1 does NOT cover a coefficient likelihood, TMB parameters, REML behavior,
penalties, missing metadata values, observation aggregation, recovery,
extractors, intervals, non-Gaussian coefficient models, multiple coefficient
sources, public wide helper grammar, or propagation through
`screen_gllvmTMB()`. It covers only exact metadata preparation, fixed-effect
rewriting, inert parser validation, and the pre-engine fence listed above.

## 13. Design-Doc Updates

Design 131 is the authoritative Arc 1 contract. The canonical grammar records
the partial fixed-metadata surface and the engine-blocked markers. Validation
row FG-20 keeps the capability `partial`: there is no likelihood, recovery,
extractor, interval, non-Gaussian, or public-helper claim. Design 130 remains
authoritative for released `*_slope()` behavior.

## 14. pkgdown and Documentation

`column_data` is documented on `gllvmTMB()` and `man/gllvmTMB.Rd` was
regenerated and inspected. No coefficient helper help page, public article,
vignette, README example, NEWS claim, reference-index entry, or pkgdown
navigation entry was added. `pkgdown::check_pkgdown()` passed. The full article
build reached the unchanged slope article and reproduced its baseline extractor
failure; that failure does not validate or invalidate the Arc 1 parser.

## 15. Roadmap Tick

N/A: no `ROADMAP.md` row or progress bar changed. Arc 1 remains an internal
foundation, not a public shipped capability.
