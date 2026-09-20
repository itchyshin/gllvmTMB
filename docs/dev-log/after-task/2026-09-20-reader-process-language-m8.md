# After Task: Reader-facing process-language audit

**Branch**: `codex/reader-process-language-m8`
**Base**: `origin/main` at `1eac2cddb` (merged PR #1295)
**Date**: `2026-09-20`
**Roles (engaged)**: `Rose / Pat / Grace`

## 1. Goal

Audit the nav-reachable introductory and limitation pages for project-internal
workflow language, then state the same evidence in terms a scientific reader can
evaluate. Preserve numerical results, examples, and warnings. Do not alter the
README, glossary, figures, model code, public API, CI policy, NEWS, or developer
simulation records.

## 2. Implemented

- Replaced reader-facing uses of *gate*, *register*, *admitted*, *worktree*,
  issue-number bookkeeping, and lifecycle-process phrasing with the measured
  criterion, evidence boundary, or remaining scientific limitation.
- Preserved all reported sample sizes, recovery and coverage values, supported
  family/mode combinations, examples, and the experimental-package warning.
- Kept scientifically meaningful uses of “source gate” in integrated-model
  articles. These describe a model variable, not project workflow.
- Rendered and scanned the seven changed public pages, including the long Canada
  warbler article, rather than relying on source-only replacements.

The mathematical and software contract is unchanged: this slice changes no R
function signature, formula grammar, family or likelihood definition, estimator,
NAMESPACE entry, Rd file, or pkgdown navigation entry.

## 3a. Decisions and Rejected Alternatives

**Decision:** translate internal process terms only where they reach readers.
**Rationale:** “failed a gate” hides the quantity that failed; “exceeded the
prespecified fixed-effect-bias limit” states what the evidence shows. **Rejected
alternative:** blanket replacement of every source match. That would incorrectly
remove the scientific “source gate” variable and would rewrite hidden retained-data
keys without changing what readers see. **Confidence:** high; all seven rendered
text surfaces were scanned after rendering.

**Decision:** describe the ordinary Gaussian latent `n = 60` result as held before
production and distinguish it from failed correlation-stress designs. **Rationale:**
the retained `CRAN07-AA-03` evidence row makes that distinction. **Rejected
alternative:** treating “not admitted” as equivalent to a failed accuracy result.
**Confidence:** high for the wording; no new performance claim was introduced.

**Decision:** do not edit the glossary's `unit = "site"` statement in this lane.
**Rationale:** draft PR #1296 owns the glossary. Source confirms that the function
formal is now `unit = NULL`; an explicit value is returned unchanged, the literal
`site` column triggers a one-time deprecated fallback, and omission without that
column aborts. The correction belongs in the owning PR. **Rejected alternative:**
silently editing the overlapping glossary file. **Confidence:** high, based on
`R/gllvmTMB.R`, its roxygen documentation, generated Rd text, and NEWS.

## 4. Files Touched

Reader pages:

- `vignettes/gllvmTMB.Rmd`
- `vignettes/articles/current-limits.Rmd`
- `vignettes/articles/temporal-ar1.Rmd`
- `vignettes/articles/profile-likelihood-ci.Rmd`
- `vignettes/articles/api-keyword-grid.Rmd`
- `vignettes/articles/random-slopes-nongaussian.Rmd`
- `vignettes/articles/isdm-canada-warbler.Rmd`

Evidence records:

- `docs/dev-log/check-log.d/2026-09-20-reader-process-language-m8.md`
- `docs/dev-log/after-task/2026-09-20-reader-process-language-m8.md`

## 5. Checks Run

- `bash tools/check-reader-surface.sh` — PASS.
- `Rscript tools/test-check-pkgdown-public-surface.R` — `PKGDOWN PUBLIC SURFACE TEST PASS`.
- `NOT_CRAN=true Rscript -e 'testthat::test_file("tests/testthat/test-reader-facing-no-register-codes.R", reporter="summary")'` — PASS (one test).
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` — `No problems found.`
- Scoped `rmarkdown::render()` into
  `/private/tmp/gllvmtmb-reader-language-m8-render` — all seven changed pages
  rendered successfully.
- `xml2` extraction of each rendered page's `<main>`/`<body>` text, scanned with
  `(?i)\\b(?:gate|gates|ledger|ledgers|receipt|receipts|phase|phases|register|registers|worktree)\\b|#[0-9]{2,}`
  — CLEAN for all seven rendered pages.
- `Rscript /Users/z3437171/Dropbox/Github\ Local/Shinichi/tools/check-after-task.R ...`
  — report structure PASS; closeout then stopped on three unrelated inherited
  `.unlazy` ledgers (`ijsdm-response-information-forensics`,
  `ijsdm-response-information`, and `temporal-ar1`).
- `git diff --check` — clean.

## 6. Tests of the Tests

The existing reader-facing code test includes a synthetic negative case: it
injects `This implementation lane closes PR #456` and verifies that the checker
rejects it. The independent rendered-text scan exercises the final HTML text,
not only Rmd source, and therefore avoids treating CSS colour hex codes as issue
numbers.

## 7a. Issue Ledger

- Inspected #347, the open article-completion roadmap umbrella; this audit
  contributes reader-facing cleanup but does not complete that issue.
- Searched open issues for reader process-language/current-limits work and found
  no narrower issue to close or update.
- Inspected draft PR #1296 for ownership. It owns `README.md` and
  `vignettes/articles/gllvm-vocabulary.Rmd`; neither was touched here.
- No issue was created, commented on, or closed.

## 8. Consistency Audit

Source scan:

```text
rg -n -i '\b(gate|gates|ledger|ledgers|receipt|receipts|phase|phases|register|registers|worktree)\b|#[0-9]{2,}' vignettes/gllvmTMB.Rmd vignettes/articles --glob '*.Rmd' --glob '!vignettes/articles/gllvm-vocabulary.Rmd' --glob '!vignettes/articles/glossary*'
```

The remaining matches are CSS/plot colour literals, the scientific `source gate`
variable, one non-rendered source comment, and hidden Canada-warbler setup keys
that map retained data to reader-facing labels. The rendered-text scan was clean.

No README, glossary, figure, model, public API, CI, NEWS, or developer simulation
record changed. The diff contains only the seven public Rmd files and these two
evidence records.

## 9. What Did Not Go Smoothly

The first source-wide regular expression also matched CSS and plot colour hex
codes. The final audit therefore parses rendered HTML and scans visible text.
The Canada warbler article is long and took roughly 90 seconds to render, but it
completed successfully. The route helper had no dedicated manifest for this
temporary worktree, so the audit used the repository graph, live source, and
reader-surface tools directly. The central after-task validator reported that
the report structure passed, then stopped on three inherited `.unlazy` ledgers
for iJSDM and temporal work outside this slice; they were not modified here.

## 10. Known Residuals

This does **not** cover a full-site build, deployment, full package test suite,
or any new model fit. Those would not add evidence for this prose-only slice.

The glossary currently says that users “override the default `unit = "site"`”.
Current source instead has `unit = NULL`: a literal `site` column is accepted only
through a deprecated fallback, and omission without that column errors. The owner
of draft PR #1296 should correct that sentence while preserving its file ownership.

The hidden Canada-warbler setup retains an issue-numbered data key because the
key is part of a saved artifact; its rendered label is simply `1 iteration`.
The random-slopes source retains one issue-numbered setup comment that is not
rendered. Neither is public process language.

## 11. Team Learning

- **Rose:** an evidence label should name the measured criterion; project status
  words are not substitutes for scientific evidence.
- **Pat:** readers need the failure mechanism or limitation, not the issue number
  that once tracked it.
- **Grace:** source scans are useful for discovery, but rendered-text scans are
  the reliable public-surface check when CSS and hidden setup code are present.

## 12. Cross-Product Coverage

This slice covers only gllvmTMB reader prose. It does NOT cover or alter drmTMB,
GLLVModels.jl, DRModels.jl, any R-to-Julia bridge, engine behavior, REML,
penalties, missing-response handling, or aggregation behavior.
