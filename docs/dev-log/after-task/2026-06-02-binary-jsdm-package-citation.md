# After Task: Binary JSDM Package Citation

**Branch**: `codex/binary-jsdm-citation`
**Date**: `2026-06-02`
**Roles (engaged)**: `Ada / Jason / Rose / Grace`

## 1. Goal

Add one package-level literature anchor for binary presence-absence
models as species distribution models, without changing package
behaviour or widening any validation claim.

## 2. Implemented

The package `DESCRIPTION` now cites Pollock et al. (2014),
*Methods in Ecology and Evolution* 5:397-406,
DOI `10.1111/2041-210X.12180`, as the binomial-family JSDM /
presence-absence SDM anchor. `devtools::document()` propagated that
sentence into `man/gllvmTMB-package.Rd`.

Mathematical contract: no public R API, likelihood parameterisation,
formula grammar, family implementation, NAMESPACE entry, vignette
example, or pkgdown navigation changed.

Scope boundary: the package-description claim maps to covered
validation rows `FG-04` (`latent(0 + trait | unit, d = K)`) and
`FAM-02` / `FAM-03` / `FAM-04` (binomial logit, probit, and cloglog).
The edit does not claim calibrated binary JSDM intervals or promote
`dep()` / `indep()` binary JSDM defaults.

## 3. Files Changed

- `DESCRIPTION`
- `man/gllvmTMB-package.Rd` (generated from `DESCRIPTION`)
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-02-binary-jsdm-package-citation.md`

## 3a. Decisions and Rejected Alternatives

Decision: use Pollock et al. (2014) because it is directly about
presence-absence joint species distribution modelling and residual
co-occurrence.

Rejected alternative: cite only the broader Warton et al. (2015)
review. That review remains useful, but Pollock et al. is the narrower
binary SDM teaching anchor requested here.

## 4. Checks Run

- `gh pr list --state open --json number,title,headRefName,baseRefName,url --limit 20`
  -> open PRs inspected before editing shared files: #427, #425, #423,
  #420, #369; no direct `DESCRIPTION` collision found.
- `git log --all --oneline --since="6 hours ago"` -> no output.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> completed; wrote `man/gllvmTMB-package.Rd`.
- `grep -c '^\\keyword' man/gllvmTMB-package.Rd && tail -n 8 man/gllvmTMB-package.Rd`
  -> one `\keyword{}` entry; tail shows expected package Rd ending.
- `git diff --check` -> clean.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- Split-branch rerun on 2026-06-03 from `origin/main` at `6d08513`:
  `devtools::document(quiet = TRUE)` regenerated
  `man/gllvmTMB-package.Rd`; unrelated Rd link-formatting churn was
  restored to keep the branch narrow.
- `git diff --check` on `codex/binary-jsdm-citation` -> clean.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` on
  `codex/binary-jsdm-citation` -> `No problems found.`

## 5. Tests of the Tests

No tests were added or changed. This was a documentation-only citation
addition.

## 6. Consistency Audit

- `rg -n "Pollock|2041-210X\\.12180|joint species distribution|binomial-family|presence-absence" DESCRIPTION man/gllvmTMB-package.Rd vignettes/articles/lambda-constraint.Rmd vignettes/articles/joint-sdm.Rmd`
  -> expected hits in `DESCRIPTION`, generated package Rd, and the
  existing lambda-constraint article.
- `rg -n "in prep|in preparation|meta_known_V|gllvmTMB_wide|phylo_rr|block_V|deprecated.*0\\.1|\\\\bS_B\\\\b|\\\\bS_W\\\\b|\\\\\\\\bf S" DESCRIPTION man/gllvmTMB-package.Rd`
  -> no output; no stale alias, in-prep foundational claim, or legacy
  S/U notation introduced.
- `rg -n "FAM-02|FAM-03|FAM-04|FG-04" docs/design/35-validation-debt-register.md`
  -> confirmed covered validation rows for the advertised binary family
  and latent JSDM grammar surface.

## 7. Roadmap Tick

N/A. No roadmap row changed.

## 7a. GitHub Issue Ledger

`gh issue list --repo itchyshin/gllvmTMB --state open --search 'binary OR binomial OR "joint SDM" OR JSDM OR "species distribution" OR Pollock' --json number,title,url,labels,updatedAt --limit 20`
returned #351, #341, #340, #332, #348, #349, #342, #346, and #230.
None was specific to package-description citation hygiene, so no issue
comment, closure, or new issue was needed.

## 8. What Did Not Go Smoothly

The phrase "package dump" was not a literal repo file. I treated it as
the package-level generated help / DESCRIPTION surface after confirming
there were no literal `package dump`, `paper dump`, or `citation dump`
files.

## 9. Team Learning

Ada: Keep the edit narrow. A package-description citation is useful,
but it should not pull the active branch into article rewrite work.

Jason: Pollock et al. (2014) is the narrower binary SDM/JSDM anchor;
Warton et al. (2015) remains the broader community-modelling review.

Rose: Any package-description capability wording still needs a
validation-row map. The row map is `FG-04` plus `FAM-02..FAM-04`.

Grace: `devtools::document()` and `pkgdown::check_pkgdown()` were enough
for this doc-only citation change; no article render was required.

## 10. Known Limitations And Next Actions

This does not restore or revise the `joint-sdm` article, and it does
not change binary interval calibration. If the package later promotes a
full binary JSDM article, that article still needs the existing rendered
HTML and figure-review gates.
