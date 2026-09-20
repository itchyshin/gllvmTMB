# Reader vocabulary, milestone 7

## 1. Goal

Give biology PhD students and other scientists consistent first definitions of the model, the R package, and the optional Julia connection.

## 2. Implemented

Clarified the opening definition and optional companion wording in README.md and vignettes/articles/gllvm-vocabulary.Rmd. Template Model Builder is expanded at first mention in the new package-identity paragraph. The default R workflow needs no Julia installation. The optional bridge points to its existing limits. All warnings, examples, equations, evidence and capability statuses are preserved.

## 3a. Decisions and Rejected Alternatives

Kept this a prose-only repair with two public files. Reused existing setup and limits pages instead of creating a new guide or promising feature parity. No model, API, build workflow, CI policy, version, figure or Julia repository was changed.

## 4. Files Touched

- README.md
- vignettes/articles/gllvm-vocabulary.Rmd
- docs/dev-log/after-task/2026-09-20-reader-vocabulary-m7.md
- docs/dev-log/check-log.d/2026-09-20-reader-vocabulary-m7.md

## 5. Checks Run

- Base: origin/main aa93d1928; isolated worktree /private/tmp/gllvmtmb-vocabulary-m7, branch docs/reader-vocabulary-m7.
- `Rscript -e 'pkgdown::check_pkgdown()'`: no problems found.
- `bash tools/check-reader-surface.sh`: PASS across README, NEWS, DESCRIPTION, man, vignettes and runtime strings. The requested M8 scan `rg -n 'D-204|FAM-16|Design 62' NEWS.md man/families.Rd R/families.R` returned no matches on this fresh base; those repairs are already present, so no roxygen or NEWS edit was necessary.
- Scoped pkgdown render using `p <- pkgdown::as_pkgdown(".", override=list(destination="/private/tmp/gllvmtmb-vocabulary-m7-review")); pkgdown::init_site(p); pkgdown::build_home_index(p); pkgdown::build_article("articles/gllvm-vocabulary", p)`: home and changed article built successfully.
- `Rscript /private/tmp/check-r-vocabulary-m7.R /private/tmp/gllvmtmb-vocabulary-m7 /private/tmp/gllvmtmb-vocabulary-m7-review`: PASS. Parsed both rendered main elements; checked definitions appear before the warning, optional Julia text and limits are present, new links have the intended targets, and all fenced code blocks equal HEAD.
- `git diff --check`: clean.
- Hub after-task validator: report structure passed; overall validator refused unrelated inherited UNMET ledgers in `.unlazy/ijsdm-response-information-forensics/GATES.md`, `.unlazy/ijsdm-response-information-GATES.md`, and `.unlazy/temporal-ar1/GATES.md`. Those lanes are not modified or marked complete by this documentation task.
- No fits, compilation, Julia startup, full package suite or full-site build: this changes prose only. The scoped render is not a complete site or deployment certificate.

## 6. Tests of the Tests

No permanent tests added for this reversible prose edit. The one-off reader check examines generated HTML, not just source strings; its code-block equality check compares against the pre-edit commit. Existing reader checkers were run unchanged.

## 7a. Issue Ledger

Related public learning-path roadmap: #347. This is a bounded contribution, not completion of that roadmap; no issue was closed or modified.

PR #1295 owns the introduction vignette and current-limits page; neither is touched. PR #1283 edits navigation; this branch leaves navigation unchanged. Recent reader-first branches were inspected against current origin/main before choosing the two prose files.

## 8. Consistency Audit

Inventoried README, current navigation, first tutorial, limits, glossary or Julia guide, and open PR public-file paths before editing. Both R packages now expand TMB and explicitly describe Julia as optional for supported models. Source checks do not certify model accuracy. Package defaults and companion names were checked in the current bridge source/help.

Memory receipt: loaded route.py for both R repos, hub VOICE, memory's reader-first and optional-Julia boundaries, and project prose-style-review/after-task-audit skills. They kept the R workflow primary, retained evidence boundaries, and placed definitions before mechanics. Brain MCP tools were unavailable; repo docs were the fallback. Golden Set was not rerun: no model or estimator behaviour changed. No memory files were modified.

## 9. What Did Not Go Smoothly

The initial main worktrees were stale relative to origin/main. Used fresh isolated checkouts. A direct build_home attempt stopped on a sandboxed CRAN DNS lookup and generated private root pages in a disposable preview. The successful scoped render uses build_home_index and the changed article only in a fresh destination, avoiding private-root generation; no preview artifacts are committed. The glossary article requires pkgdown's articles/gllvm-vocabulary name, not its basename.

## 10. Known Residuals

The glossary later describes unit = "site" as the default, while R/gllvmTMB.R has unit = NULL and a staged resolver; that wording needs a separate check against the fallback contract. The rendered home page visibly retains the existing literal [!WARNING] marker. Neither changes the first-definition claims here.

## 11. Team Learning

Rose: inspect origin/main before treating a stale checkout's wording as a new regression. Match each public model definition with the package identity and an explicit optional-engine boundary. Scoped renders establish the changed reader experience without rerunning scientific examples.

## 12. Cross-Product Coverage

Covers the two edited public entry points, their rendered definitions, links, optional Julia wording, and unchanged examples. This does NOT cover full-site publication, numerical recovery, interval calibration, feature parity, tutorials owned by other PRs, or the Julia packages themselves. Separate review PR requested; do not merge in this lane.
