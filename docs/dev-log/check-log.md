# Check log

Append-only record of `R CMD check`, `devtools::test()`, and
`pkgdown` runs that produced meaningful evidence. Keep entries
date-stamped.

## 2026-05-10 -- drmTMB-parity match exposes unstated tidyselect

Scope:

- removed `--no-manual --ignore-vignettes` / `--no-build-vignettes`
  overrides from `.github/workflows/R-CMD-check.yaml` so R CMD check
  runs drmTMB-exact defaults;
- the strict defaults surfaced `* checking for unstated dependencies
  in 'tests' ... WARNING` (1 WARNING, 0 ERROR, 0 NOTE) on ubuntu and
  macos runs of PR #3 (run id 25640098258);
- root cause: `tidyselect` was in DESCRIPTION `Imports` (for
  `R/traits-keyword.R` and `R/gllvmTMB-wide.R`) but not in
  `Suggests` (for the test files that use `tidyselect::all_of` and
  related verbs);
- added `tidyselect` to `Suggests:` so R CMD check finds the test-
  side namespace declaration too.

Decision: the drmTMB-parity strictness is doing exactly what it
should -- surfacing real issues our skip-args were masking. Keep
the strictness; fix the underlying declarations.

## 2026-05-10 -- mgcv unstated in tests (second pass of the same class)

Scope:

- after the tidyselect fix above, PR #3 R-CMD-check #6 surfaced a
  second instance of the same warning class: `'::' or ':::' import
  not declared from: 'mgcv'` (Ubuntu + macOS; Windows cancelled);
- root cause: `tests/testthat/test-tweedie-recovery.R` uses
  `mgcv::rTweedie` (line 27, 77) to simulate Tweedie responses, but
  the bootstrap dropped `mgcv` from DESCRIPTION entirely when it cut
  the sdmTMB smoother machinery;
- proactive sweep: greped every `pkg::` use in `tests/testthat/*.R`
  against current Imports + Suggests. Found exactly one other
  missing declaration (mgcv) -- no third pass expected;
- added `mgcv` to `Suggests:` (tests use it; R/ does not need it).

Lesson encoded: a single warning of class X should trigger a sweep
for the whole class, not a fix-then-wait-for-next-instance cycle.

## 2026-05-10 -- Windows wall-time accommodation (45 min temporary)

Scope:

- PR #3 set `timeout-minutes: 30` to match drmTMB exactly;
- Ubuntu (21-24m) and macOS (21m) finish well within the budget;
- Windows-latest R CMD check ran 28m 40s before being cancelled by
  the 30-min cap (run id 25640098258, then 25641006745, then
  25642532495 -- all same Windows cap-hit);
- root cause: Windows TMB compilation + 1250-test execution is
  intrinsically slower than Linux/macOS for this package size.
  drmTMB does 3-OS in 7 min total because their package has ~700
  tests and ~30 exports vs our 1250 tests and ~60 exports;
- bumped `timeout-minutes` 30 -> 45 as a documented temporary;
  this still catches real regressions while letting Windows complete
  its current workload.

Decision: keep the 45-min budget through Phase 1 of ROADMAP. The
Phase 1 task is to gate the slowest 20% of tests behind
`Sys.getenv("RUN_SLOW_TESTS") != ""` so Windows fits in drmTMB's
30-min budget. Once gated, lower `timeout-minutes` back to 30 to
re-establish the strict discipline gate.

## 2026-05-11 -- CI/site/team repair

Scope:

- changed `.github/workflows/pkgdown.yaml` so pkgdown runs after a
  successful `R-CMD-check` on `main` / `master`, or by manual
  dispatch;
- rewrote `README.md` as the pkgdown homepage source: purpose, Start
  here, preview status, install smoke test, tiny example, current
  supported workflows, covariance keyword grid, boundaries, and
  sister packages;
- fixed stale Get Started wording for `extract_correlations()` so the
  default is `method = "fisher-z"` rather than profile-likelihood;
- updated `R/extract-correlations.R` roxygen wording from "three
  methods" to the actual four method names and regenerated
  `man/extract_correlations.Rd`;
- added `.agents/skills/rose-pre-publish-audit/SKILL.md` and
  documented the narrow Rose gate in `AGENTS.md` and
  `CONTRIBUTING.md`;
- replaced the long active Claude plan with a short current plan plus
  backlog at `~/.claude/plans/please-have-a-robust-elephant.md`.

Checks:

- README smoke test:
  `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); ...'`
  fitted the tiny model with convergence 0, returned communality, and
  returned `extract_correlations(..., tier = "unit")` with
  `method = fisher-z`;
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` completed
  and regenerated `man/extract_correlations.Rd`;
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` completed with
  `No problems found`;
- `Rscript --vanilla -e 'pkgdown::build_home(preview = FALSE);
  pkgdown::build_article("gllvmTMB", quiet = TRUE)'` rendered
  `pkgdown-site/index.html` and `pkgdown-site/articles/gllvmTMB.html`;
- `gh workflow list --repo itchyshin/gllvmTMB` found the expected
  active workflows: `R-CMD-check` and `pkgdown`;
- Rose sweep:
  `rg -n "three methods|profile-likelihood confidence|profile-likelihood default|method = \"wald\" and|trio" README.md vignettes R man AGENTS.md CONTRIBUTING.md .agents/skills/rose-pre-publish-audit/SKILL.md pkgdown-site/index.html pkgdown-site/articles/gllvmTMB.html`
  found only the Rose audit examples and an unrelated internal
  `extract-repeatability.R` comment.

Decision: this repair deliberately does not reduce R-CMD-check runtime
or add `RUN_SLOW_TESTS` gating. The immediate fix is cleaner feedback
sequencing and clearer public/project instructions.

## 2026-05-11 (Claude) Add long + wide example pairing convention

Added a writing-style rule to `AGENTS.md`: user-facing prose (README,
vignettes, Tier-1 articles) must show both the long-format and the
wide-format `gllvmTMB` call side by side. Rationale captured in
`docs/dev-log/decisions.md` under "User-facing examples pair long +
wide". Applies from 2026-05-11 onwards; the Priority 2 article-rewrite
PR will be the first application.

No package code or NAMESPACE changes. Documentation rule only.

## 2026-05-11 -- Roadmap and Claude/Codex collaboration rules

Scope:

- rewrote `ROADMAP.md` from a legacy phase list into a current shared
  map: reader path, public surface, long/wide data-shape contract,
  feedback time, CRAN readiness, methods paper, and extensions;
- added explicit collaboration stops to `ROADMAP.md` and
  `docs/dev-log/claude-group-handoff-2026-05-11.md`;
- updated `CLAUDE.md` so Claude Code uses the propose / discuss /
  implement rhythm rather than running broad implementation work
  without a maintainer checkpoint;
- preserved the user-facing long-format plus wide-format example rule
  in `AGENTS.md`.

Checks:

- documentation-only change; no R code, likelihood, formula grammar,
  NAMESPACE, generated Rd, or pkgdown navigation changed;
- reviewed the open GitHub PRs before editing: Priority 2 audit
  (`agent/priority-2-audit`), logo/favicons
  (`agent/logo-favicon`), and extractor examples
  (`agent/extractor-examples`) have non-overlapping file scopes with
  this roadmap update.

## 2026-05-11 -- Merge gate for PR #11 and PR #12

Scope:

- merged PR #11, "Convention: pair long + wide examples in
  user-facing prose", at `07a5b00`;
- merged PR #12, "Roadmap rewrite + Claude/Codex collaboration
  rules (Codex)", at `f5e5548`;
- resolved the expected append-only log conflict between #11 and
  #12 by keeping both entries in chronological order;
- did not start the morphometrics article rewrite in the same task.

Checks:

- main `R-CMD-check` run 25684019531 passed on the #12 merge commit
  `f5e5548`: Ubuntu success at 17:09:12Z, macOS success at
  17:18:55Z, Windows success at 17:21:54Z;
- pkgdown workflow_run 25685872579 passed on the same commit, starting
  at 17:22:07Z and completing at 17:32:40Z;
- the earlier #11 main `R-CMD-check` run 25683842459 was cancelled by
  concurrency when #12 superseded it on `main`;
- pkgdown workflow_run 25684045764 was skipped before R-CMD-check
  completed; the successful pkgdown run above is the deployment
  evidence for the merge-gate task.

Decision: treat "merge #11/#12 and confirm Actions" as its own
completed task. Per maintainer instruction, stop after this report and
do not begin `morphometrics.Rmd` until the maintainer has reviewed the
task closure.
