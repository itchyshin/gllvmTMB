# After Task: Internal IID response-column coefficient engine

**Branch**: `codex/column-coef-iid-engine`
**Date**: 2026-08-26
**Roles (engaged)**: Ada, Boole, Noether, Curie, Fisher, Rose, Grace

## 1. Goal

Admit an internal Gaussian `column_coef()` point-estimation route with
intercept and predictor coefficients across response columns, while preserving
the released warning-free `*_slope()` family exactly. Keep structured
`phylo_coef()`, `animal_coef()`, `kernel_coef()`, and `spatial_coef()` routes,
public exports, extractors, and article teaching fenced for later slices.

## 2. Mathematical Contract

For response column `t` and sampled row `i`, the admitted term is

```text
eta_it,coef = z_i^T b_t,
B = [b_1^T; ...; b_T^T],
B ~ MN(0, I_T, Sigma_coef).
```

`z_i` is ordered as an optional synthetic intercept followed by the named
numeric row predictors. A single bar estimates a full positive-definite
`Sigma_coef = L L^T`; a double bar maps every strict-lower element of `L` to
zero. This is an IID response-column random-coefficient covariance, not an
observation residual, unit-tier covariance, phylogenetic covariance, or new
TMB likelihood. The implementation reuses the released matrix-normal
response-column slope core without changing C++ arithmetic.

## 3. Files Changed

- Engine routing: `R/column-coef-foundation.R`, `R/gllvmTMB.R`,
  `R/fit-multi.R`.
- Tests: `tests/testthat/test-column-coef-engine-iid.R`,
  `tests/testthat/test-column-coef-foundation.R`.
- Design and validation: `docs/design/131-response-column-coefficient-foundation.md`,
  `docs/design/01-formula-grammar.md`, and
  `docs/design/35-validation-debt-register.md` (FG-20).
- Planning and closeout:
  `docs/dev-log/plans/2026-08-26-response-column-coef-programme-ultra-plan.md`,
  this report, `docs/dev-log/check-log.md`, and
  `docs/dev-log/handover/2026-08-26-column-coef-iid-engine.md`.
- No `src/`, `NAMESPACE`, generated Rd, `_pkgdown.yml`, `NEWS.md`, `README.md`,
  vignette, or article source changed.

### 3a. Decisions and Rejected Alternatives

**Decision:** rewrite internal `column_coef()` terms to the existing
response-column matrix-normal route after overlap validation and before the
general sugar pass. **Rationale:** this preserves one proven likelihood and
prevents `||` from being mistaken for augmented random-slope sugar.
**Rejected:** a second TMB likelihood or a public alias to `slope()`; both
would duplicate arithmetic or erase coefficient-specific basis metadata.
**Confidence:** high for the internal IID Gaussian point route because exact
fit-equivalence is tested.

**Decision:** reserve the literal predictor name `(Intercept)` and require `1`
for the synthetic intercept. **Rationale:** one label cannot safely mean both
a data column and an inserted all-ones column. **Rejected:** silent precedence.
**Confidence:** high.

## 4. Checks Run

```sh
Rscript --vanilla -e 'devtools::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-column-coef-engine-iid.R", reporter="summary", stop_on_failure=TRUE)'
# PASS: 49 expectations after Rose review.

Rscript --vanilla -e 'devtools::load_all(quiet=TRUE); testthat::test_dir("tests/testthat", filter="^(column-coef-foundation|column-coef-engine-iid|traits-keyword|fixed-column-slope-family|phylo-slope-rhs-routing|ordinary-column-slope-phylo-coexistence)$", reporter="summary", stop_on_failure=TRUE)'
# Post-Rose-fix PASS in 27.8 seconds; only three pre-existing optional-cluster
# warnings and two explicit CRAN skips in neighbouring tests. Rose independently
# reran the same command with the same result.

Rscript --vanilla -e 'devtools::test(stop_on_failure = TRUE)'
# Intentionally stopped at the declared 20-minute ceiling. Every file through
# test-extractors-extra.R passed; the interrupt occurred in the unrelated
# test-extractors.R file, with no test failure.

Rscript --vanilla -e 'pkgdown::check_pkgdown(); pkgdown::build_article("articles/where-does-the-tree-go", lazy = FALSE)'
# check_pkgdown: PASS. Article render: known baseline FAIL at the
# column-axis-fit chunk because extract_Sigma(level = "column_slope") is not
# supported by the loaded public extractor. This slice did not edit the article.

git diff --check
# PASS.
```

The unchanged Arc 1 post-merge run `33001159527` on exact main SHA
`5a202fc8154a8e0c50c41ebb76932b0d805bdee8` was still in progress at this
report's first draft; no IID push occurred while it was active.

## 5. Tests of the Tests

The initial valid-IID test failed with
`gllvmTMB_column_coef_engine_not_admitted` before implementation. Expanded
tests then caught three real integration defects: synthetic intercept lookup
as a data column, `||` interception by the general sugar pass, and a long/wide
fixture with the wrong pivot order. Boundary tests retain structured-engine
fences for all four structured helpers, reject literal `(Intercept)`, and fail
clearly for Poisson. Feature-combination tests compare long and `traits(...)`
wide fits and compare both bars of the new no-intercept spelling to the
released warning-free `slope()` route. The known-DGP test uses a deterministic
whitened finite coefficient draw, so its covariance oracle does not pass or
fail by Monte Carlo luck; its truth-gradient vector explicitly sets the fixed
intercept, coefficient covariance, and residual scale.

## 6. Consistency Audit

```sh
rg -n "column_coef|phylo_coef|animal_coef|kernel_coef|spatial_coef" README.md NEWS.md vignettes _pkgdown.yml NAMESPACE man
# Verdict: no public API teaching except the existing article's explicit and
# still-correct statement that column_coef() is not publicly available.

rg -n -i "deprecat.*(_slope|slope\\()|(_slope|slope\\().*deprecat" R README.md NEWS.md vignettes man docs/design
# Verdict: no runtime or public-doc slope deprecation was added. Older Designs
# 55/56 retain historical future proposals; Design 130 and FG-15/PHY-06 state
# the current no-deprecation contract.

rg -n "reserved / engine-blocked|coefficient engine blocked|then stop before engine|No helper is exported or routed" docs/design README.md ROADMAP.md NEWS.md docs/dev-log/known-limitations.md
# Verdict: the stale all-helpers-blocked Design 01 row was updated after the LV
# owner explicitly agreed to preserve the current-main response-column rows on
# rebase; no LV-specific content was touched.

rg -n "column_coef|response-column coefficient" ROADMAP.md NEWS.md docs/dev-log/known-limitations.md _pkgdown.yml README.md
# Verdict: no public status surface advertises the internal IID route.
```

## 7. Roadmap Tick

N/A. The IID engine remains internal and does not advance a public roadmap row.

## 7a. GitHub Issue Ledger

Issue #1212, “design: estimate structured-source strength across the covariance
grid,” was inspected. This IID slice supplies a prerequisite but does not
implement `rho`, change the 5 x 3 grid, or close the issue. No comment or new
issue was created because the structured fixed/estimated-`rho` slices remain
the immediately following work in the approved programme.

## 8. What Did Not Go Smoothly

The first implementation exposed three integration assumptions rather than
passing immediately: the synthetic intercept needed separate data validation,
the rewrite order had to precede general sugar, and long/wide parity required
the exact stacking order. The initial recovery fixture compared a finite
random draw to its population covariance too loosely; whitening made the
oracle deterministic. The broad package suite exceeded its declared estimate
and was stopped rather than silently extending it. The unchanged tree article
also reproduced its pre-existing extractor/render failure, confirming that
article repair must remain a separate later slice.

## 9. Team Learning

**Ada:** Sequential narrow slices prevented the internal IID admission from
pulling structured `rho`, extractors, exports, or article repair into one PR.
The next slice must start only after exact-head IID CI and merge.

**Boole:** The parser must distinguish the user spelling `1` from the internal
`(Intercept)` basis label, and the coefficient rewrite must occur before
ordinary `||` sugar. The public API remains deliberately absent.

**Noether:** The strongest oracle is not approximate recovery but exact
identity with the released slope likelihood when the coefficient basis has no
intercept and the response-column source is IID.

**Curie:** A whitened finite coefficient draw separates covariance-recovery
evidence from Monte Carlo chance. Both acceptance and rejection routes are
covered.

**Fisher:** This slice earns Gaussian point estimation only. It supplies no
interval, non-Gaussian, or structured-source claim.

**Rose:** Independent review initially failed the slice for overclaimed gates:
only one structured helper was fit-tested, `||` slope equivalence and long/wide
fitted values were absent, and the truth-gradient vector retained the fitted
fixed effect. The strengthened 49-expectation file and six-file replay fixed
all findings. Rose's terminal re-review returned PASS with no blocking finding;
that pass does not substitute for exact-head CI.

**Grace:** `pkgdown::check_pkgdown()` passed; the existing tree article render
failure was reproduced exactly and remains separate. Exact-head CI is still
required before merge.

## 10. Design And Documentation Updates

Design 131 now distinguishes the admitted IID engine from the still-fenced
structured helpers. Validation row FG-20 is `partial`: internal IID Gaussian
point fitting is covered, while public and structured surfaces remain blocked.
No reader-facing documentation changed. Prose review kept claims concrete and
placed every limitation beside the admitted result.

## 11. Known Limitations And Next Actions

- Confirm the LV rebase preserves the coordinated internal-IID boundary in
  `docs/design/01-formula-grammar.md`.
- Obtain terminal Rose review, exact-head PR CI, and post-merge main evidence
  for this narrow IID slice.
- Begin fixed-`rho` `phylo_coef()` from fresh main. Prove exact `rho = 1`
  equivalence to `phylo_slope()` and the raw-scale-preserving `rho = 0`
  diagonal-source oracle before estimated `rho`.
- Do not export or teach `*_coef()` and do not deprecate or warn from
  `*_slope()` until the fixed and estimated phylogenetic slices, extractor
  contract, article render, and exact fit-equivalence gates all pass.
