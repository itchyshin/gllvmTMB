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

## 2026-05-11 -- Shannon coordination audit role

Scope:

- added `.agents/skills/shannon-coordination-audit/SKILL.md`;
- documented Shannon in `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`,
  `ROADMAP.md`, and `docs/dev-log/decisions.md`;
- created an after-task report for the Shannon role addition.

Checks:

- documentation-only change; no R code, likelihood, formula grammar,
  NAMESPACE, generated Rd, pkgdown navigation, or article source
  changed;
- Shannon is scoped as read-only and checkpoint-invoked, not as a
  continuous overseer.

## 2026-05-11 -- post-PR-#8-merge pkgdown workflow_run verification

Scope:

- after PR #8 merged to `main` at commit `ae771f8` on 2026-05-11
  14:25 UTC, watched the post-merge CI sequence to confirm the new
  `.github/workflows/pkgdown.yaml` `workflow_run` trigger fires
  pkgdown only after R-CMD-check completes successfully, and
  *not* in parallel with the push event.

Evidence (from `gh run list / view`):

- `R-CMD-check` (run id 25676207810, event `push`, branch `main`):
  - started: 2026-05-11T14:25:33Z
  - completed: 2026-05-11T15:00:00Z
  - wall: 34 min 27 s
  - per-OS: macOS 27:06 (14:25:36 -> 14:52:42), Ubuntu 29:24
    (14:25:36 -> 14:55:00), Windows 34:22 (14:25:37 -> 14:59:59);
- `pkgdown` (run id 25678157733, event **`workflow_run`**, branch
  `main`, displayTitle "pkgdown"):
  - started: 2026-05-11T15:00:07Z (7 s after R-CMD-check
    completed -- auto-fired via `workflow_run`);
  - completed: 2026-05-11T15:10:41Z;
  - wall: 10 min 34 s;
  - conclusion: success.
- `gh run list --workflow pkgdown --branch main` confirms **no
  parallel pkgdown run** was triggered by the PR #8 push event;
  the only post-merge pkgdown run was the workflow_run-triggered
  one above.

Decision: the workflow_run sequencing transplanted from drmTMB is
working in this repo as designed. No further adjustment to
`.github/workflows/pkgdown.yaml` is needed in this phase. The
deployed pkgdown site (https://itchyshin.github.io/gllvmTMB/) now
serves the post-PR-#8 README + Fisher-z fix; the logo and
favicons remain pending PR #9 merge.

Reference: PR #8 after-task report at
`docs/dev-log/after-task/2026-05-11-ci-site-team-repair.md`,
"Next Actions" section.

## 2026-05-11 -- WIP=1 suspension during the doc-PR sprint

Scope:

- on 2026-05-11 the project ran a 9-open-PR sprint of
  documentation, audit, and process-rule changes (PRs #7, #9-#16);
- `AGENTS.md` Design Rule 6 ("Keep pull requests small and focused.
  Work-in-progress > 1 produces cancel-cascades on CI") is
  functionally suspended for the duration of this sprint;
- the suspension is acceptable because every PR in the sprint is
  documentation-only or audit-only -- no R code, NAMESPACE,
  generated Rd, vignette source, or pkgdown navigation change in
  any of them, and the CI cost is small per PR;
- Shannon's first audit (`docs/dev-log/shannon-audits/2026-05-11-first-audit.md`)
  flagged the WIP gap and recommended this entry.

Decision: keep WIP=1 as the long-term default; allow the sprint to
clear at its own pace, then restore WIP=1 discipline before any
substantive implementation work (Phase 1a article rewrites,
Priority 2 surface cleanup, Priority 3 weights unification).

## 2026-05-11 -- PR #22 post-merge CI evidence (main `440ff5f`)

Scope:

- PR #22 "Codify six agent-collaboration improvements" merged to
  main at 2026-05-11T21:09:38Z, merge commit `440ff5f` (bumping
  main from `bf6db4e` to `440ff5f`);
- the merge triggered a fresh 3-OS `R-CMD-check` on `440ff5f` and,
  on success, the `pkgdown` workflow_run that deploys the public
  site.

Verification:

- `R-CMD-check` run 25697507205 on `440ff5f`:
  - ubuntu-latest: success 2026-05-11T21:10:11Z to 2026-05-11T21:32:22Z (wall 22m 11s);
  - macos-latest:  success 2026-05-11T21:10:12Z to 2026-05-11T21:34:46Z (wall 24m 34s);
  - windows-latest: success 2026-05-11T21:10:11Z to 2026-05-11T21:43:31Z (wall 33m 20s).
  Conclusion: success on all three OSes.
- `pkgdown` runs on `440ff5f`:
  - run 25697529058, push-triggered at 2026-05-11T21:10:12Z, **skipped**
    because the corresponding `R-CMD-check` was still in progress
    (workflow_run guard fired correctly);
  - run 25699091801, workflow_run-triggered at 2026-05-11T21:43:33Z
    (2 seconds after the windows R-CMD-check job completed at
    21:43:31), pkgdown job started 21:43:43, completed
    2026-05-11T21:54:33Z (wall 10m 50s); conclusion: success.
- `git fetch origin main` after both runs confirmed main = `440ff5f`
  and `agent/collaboration-rules-codification` branch was deleted by
  the merge.

Decision: the workflow_run sequencing copied from drmTMB (and
reverified in PR #16) is holding in production. Two confirmations
on the dev-log now: PR #8 and PR #22 both fired pkgdown only after
their R-CMD-check completed green. The 2-second gap between the
windows R-CMD-check completion and the pkgdown trigger is the
expected behaviour of workflow_run; this entry records it
explicitly so future readers do not mistake the earlier skipped
run for a problem.

## 2026-05-11 -- Phase 3 weights & data-shape contract (design doc)

Scope:

- Claude lane: design doc for `ROADMAP.md` Phase 3 -- "Unify Data
  Shapes and Weights" -- added as
  `docs/design/02-data-shape-and-weights.md`. Specifies the
  contract for `gllvmTMB()`, `gllvmTMB_wide()`, and `traits(...)`:
  accepted shapes, identifiers, trait ordering, reshaping rules,
  weights handling (four shapes for the matrix-in API, vector-only
  for long and `traits()`), error messages, and a byte-identical
  paired-test contract.
- No source / NAMESPACE / Rd / vignette / pkgdown change in this
  PR. The doc is the design input for Codex's Phase 3
  implementation PR.

Implementation outline for Codex (recorded here as a directed
handoff):

- add `R/weights-shape.R` with `normalise_weights()`;
- refactor `gllvmTMB()`, `gllvmTMB_wide()`, and `traits()` to call
  the helper exactly once before dispatch to the engine;
- add `tests/testthat/test-weights-unified.R` with the five
  minimum paired cases (plain Gaussian no weights, row-broadcast,
  per-cell, binomial `cbind(succ, fail)`, `traits()` round-trip);
- update `man/*.Rd` to cross-reference the three entry points;
- add a three-way fit example to the morphometrics article once
  Codex's current Phase 1a rewrite lands.

Verification: the design doc references the current source
behaviour as observed in `origin/main` (`R/gllvmTMB.R`,
`R/gllvmTMB-wide.R`, `R/traits-keyword.R`, `R/fit-multi.R`). No
divergence between contract text and current implementation.

Decision: Phase 3 implementation approved by maintainer 2026-05-11
~22:20 UTC (all six contract items: weights shapes, byte-identical
fields, trait-order tie-break, NA semantics, helper signature,
out-of-scope list); merged 22:22 (`b425462`). Implementation handoff
to Codex posted as a comment on PR #23.

## 2026-05-11 -- Morphometrics Tier-1 long/wide rewrite

Scope:

- Codex lane: rewrote `vignettes/articles/morphometrics.Rmd` as the
  first Tier-1 worked-example implementation of the long-format plus
  wide-format article convention;
- paired every live model-fit context in the article with long and
  wide formula calls: the main rank-2 `latent() + unique()` fit, the
  first recovery-loop replicate, and the comparison fits for
  `latent(d = T)`, `dep()`, and `indep()`;
- replaced live legacy helper calls with `extract_ordination()`,
  `rotate_loadings()`, and `plot(fit, type = "ordination",
  level = "unit")`;
- fixed public wrapper behaviour so canonical `level = "unit"` calls
  no longer warn after wrapper-to-wrapper calls internally touch the
  legacy `B` / `W` storage names;
- updated generated Rd topics for the touched roxygen blocks and
  recorded the after-task report at
  `docs/dev-log/after-task/2026-05-11-morphometrics-tier1-rewrite.md`.

Checks:

- `Rscript --vanilla -e 'devtools::test(filter = "plot-gllvmTMB")'`:
  passed with 37 tests, 0 failures, 0 warnings;
- focused long/wide smoke test: main rank-2, saturated
  `latent(d = T)`, `dep()`, and `indep()` long/wide pairs all had
  maximum log-likelihood difference 0;
- `Rscript --vanilla -e 'devtools::test()'`: passed before the final
  plot-subtitle / roxygen wording patch with 1263 passed, 0 failed,
  6 warnings, 11 skipped, duration 1462.4 s;
- after the final wording patch, the focused plot test passed again
  with 37 tests, 0 failures, 0 warnings, duration 11.3 s;
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`:
  completed and regenerated the touched Rd files;
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`: passed with
  "No problems found";
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/morphometrics")'`:
  completed and wrote the morphometrics article; the only message was
  the pre-existing `../logo.png` pkgdown warning;
- `_R_CHECK_SYSTEM_CLOCK_=FALSE Rscript --vanilla -e 'devtools::check(document = FALSE, manual = FALSE, args = "--no-tests", quiet = FALSE, error_on = "never")'`:
  completed with 0 errors, 1 warning, and 1 note. The warning was an
  Apple clang / R header warning from `R_ext/Boolean.h`; the note was
  the pre-existing duplicated `tidyselect` entry in `Imports` and
  `Suggests`. Neither came from this branch.
- `git diff --check`: passed.

Consistency audit:

- `rg -n "gllvmTMB\\(|gllvmTMB_wide\\(|traits\\(" vignettes/articles/morphometrics.Rmd`
  shows each live fit context has a long and wide formula pair;
- `rg -n "getLoadings\\(|ordiplot\\(|extract_ICC_site\\(|extract_residual_split\\(" vignettes/articles/morphometrics.Rmd`
  returns no live legacy-helper hits;
- stale public wording scan for primary `B` / `W` level names and
  bootstrap-as-default wording found only intentional test references
  and internal bootstrap result labels.

Decision: morphometrics is ready to be the first Phase 1a Tier-1
article PR once the branch is pushed. Authorship, citation, and
provenance wording are deliberately held for the separate citation /
metadata lane (PR #26 and follow-up), not mixed into this article
rewrite.

## 2026-05-12 -- Phase 3 unified data-shape and weights contract

Scope:

- Codex lane: implemented Phase 3 "Unify Data Shapes And Weights"
  from `docs/design/02-data-shape-and-weights.md`;
- added `R/weights-shape.R` with the shared internal
  `normalise_weights()` helper for long, matrix-wide, and
  `traits(...)` wide-data-frame entry points;
- refactored `gllvmTMB()`, `gllvmTMB_wide()`, and `traits(...)` so
  accepted user weight shapes are normalised before the engine sees a
  long-format per-observation vector;
- fixed `gllvmTMB_wide(Y, X = ..., weights = ...)` row alignment by
  replacing the merge/order path with row matching against the
  already-pivoted long data;
- added `tests/testthat/test-weights-unified.R` for helper rejection
  paths, long/matrix-wide equivalence with no weights,
  row-broadcast weights, per-cell weights, matrix-wide `X`, and a
  `traits(...)` round-trip;
- updated `NEWS.md`, `docs/design/02-data-shape-and-weights.md`,
  roxygen/Rd cross-links, and the morphometrics Tier-1 article so
  readers see the long, formula-wide, and matrix-wide entry points
  together.

Coordination:

- pre-edit shared-file check found one open PR, #29
  `agent/air-format-trial`, touching `.github/workflows/air-format.yaml`,
  `CONTRIBUTING.md`, `air.toml`, and
  `docs/dev-log/after-task/2026-05-12-air-format-config.md`; no file
  overlap with this Phase 3 implementation except the shared
  after-task directory;
- recent-log check found `f79567b` and `4ab907b`, both belonging to
  the Air formatting lane.
- end-of-session Shannon check found a second open PR, #30
  `agent/site-species-to-unit-trait`, touching `R/gllvmTMB-wide.R`,
  `man/gllvmTMB_wide.Rd`, `man/gllvmTMB-package.Rd`, and
  `man/make_mesh.Rd`, which overlap this Phase 3 branch. A
  coordination comment was posted on PR #30:
  https://github.com/itchyshin/gllvmTMB/pull/30#issuecomment-4430062907.
- resume/integration check after PR #29 and PR #30 merged: no open PRs
  remained, and `git fetch origin && git rebase origin/main` replayed
  the Phase 3 branch cleanly onto `45eae2e` with no conflicts.

Checks:

- `Rscript --vanilla -e 'devtools::test(filter = "weights-unified")'`:
  passed with 30 tests, 0 failures, 0 warnings, 0 skips, duration
  2.4 s;
- `Rscript --vanilla -e 'devtools::test()'`: passed with 1293 tests,
  0 failures, 6 warnings, 11 skips, duration 1426.7 s. The warnings
  were known legacy alias/deprecation warnings (`B` / `W`, `spde`,
  deprecated keyword aliases), not Phase 3 failures;
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`:
  completed and regenerated Rd files. This also brought the stale
  generated `gllvmTMB-package.Rd` author/provenance text and
  `make_mesh.Rd` title/description back in sync with existing source;
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`: passed with
  "No problems found";
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/morphometrics")'`:
  completed; the only message was the pre-existing `../logo.png`
  pkgdown warning;
- `_R_CHECK_SYSTEM_CLOCK_=FALSE Rscript --vanilla -e 'devtools::check(document = FALSE, manual = FALSE, args = "--no-tests", quiet = FALSE, error_on = "never")'`:
  completed with 0 errors, 1 warning, and 1 note. The warning was the
  known Apple clang / R header warning from `R_ext/Boolean.h`; the
  note was the pre-existing duplicated `tidyselect` entry in
  `Imports` and `Suggests`;
- `git diff --check`: passed.
- post-rebase `git diff --check origin/main..HEAD`: passed;
- post-rebase
  `Rscript --vanilla -e 'devtools::test(filter = "weights-unified")'`:
  passed with 30 tests, 0 failures, 0 warnings, 0 skips, duration
  2.5 s;
- post-rebase `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`:
  completed with no additional file changes;
- post-rebase `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`:
  passed with "No problems found";
- post-rebase `air format --check .`: reported broad pre-existing
  formatting drift across many R and test files. The Air workflow added
  by PR #29 is advisory during its trial period
  (`continue-on-error: true`), so this Phase 3 branch did not absorb a
  repository-wide formatting sweep.

Consistency audit:

- Rose pre-publish searches:
  `rg -n "method *=|default|fisher-z|profile|wald|bootstrap" ...`,
  `rg -n "latent|unique|indep|dep|phylo_|spatial_|meta_known_V|trio" ...`,
  `rg -n "unit_obs|unit =|trait =|cluster =|tier =|level =|weights|normalise_weights|n_trials|cbind" ...`,
  and `rg -n "implementation will follow|will hold|follow-up PR|Phase 3 implementation should|should add|Codex's current|two-layer array|will be" ...`;
- no new public-surface contradiction was found in the touched Phase 3
  prose. The design doc now explicitly records that binomial
  `cbind(successes, failures)` versus `weights = n_trials` remains
  owned by long-engine tests, and that `gllvmTMB_wide()` does not add
  two-layer binomial response arrays in this lane.

Decision: Phase 3 implementation is locally validated and rebased over
the merged PR #29 / PR #30 work. Merge readiness now depends on the new
Phase 3 pull request's GitHub Actions result. The Air-format workflow
remains visible but advisory, and this branch does not absorb its
repository-wide formatting sweep.
