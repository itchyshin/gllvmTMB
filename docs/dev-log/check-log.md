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

## 2026-05-12 -- Origin branch hygiene: 22 merged branches deleted

Scope: Shannon audit PR #35 flagged 22 merged-but-not-deleted
branches accumulating on origin (the `gh pr merge --delete-branch`
flag failed for branches that had active worktrees at merge time,
so the local deletion succeeded but the remote ref was left
behind for a subset). Maintainer authorised cleanup 2026-05-12
~09:50 MT.

Verification (one row per branch; each `gh pr list --state merged
--head <branch>` returned exactly one merged PR number):

- agent/after-task-protocol-enrich -> PR #24
- agent/air-format-trial -> PR #29
- agent/bootstrap -> PR #1
- agent/bootstrap-after-task-report -> PR #4
- agent/citations-cleanup-path-a -> PR #26
- agent/extractor-examples -> PR #7
- agent/first-shannon-audit -> PR #17
- agent/handoff-readfirst-update -> PR #21
- agent/logo-favicon -> PR #9
- agent/long-wide-convention -> PR #11
- agent/missing-after-tasks -> PR #13
- agent/overnight-report-2026-05-11 -> PR #28
- agent/phase3-weights-contract -> PR #23
- agent/phylo-keyword-examples -> PR #6
- agent/pkgdown-destination-fix -> PR #2
- agent/pkgdown-workflow-run-verification -> PR #16
- agent/pr22-check-log-evidence -> PR #25
- agent/priority-1a-proposal -> PR #14
- agent/priority-2-audit -> PR #10
- agent/r-cmd-check-drmtmb-parity -> PR #3
- codex/merge-gate-11-12-after-task -> PR #19
- codex/morphometrics-tier1-rewrite -> PR #27

Cleanup: `git push origin --delete <branch>` for each. All 22
returned `- [deleted]`. Verified post-cleanup with
`git ls-remote origin 'refs/heads/agent/*' 'refs/heads/codex/*'`
which now shows only active branches.

Retained: `agent/shannon-audit-2026-05-12` (PR #35 open),
`agent/housekeeping-bundle` (PR #36 open),
`codex/long-wide-example-sweep` (Codex's active sweep work,
unpushed at audit time).

Decision: future `gh pr merge --delete-branch` failures (when a
worktree blocks the local delete) should be followed by an explicit
`git push origin --delete <branch>` so the remote ref does not
accumulate. The local branch can be deleted later once the
worktree is removed; the remote ref does not need to wait.

## 2026-05-12 -- Long/wide reader-facing sweep: compact `traits()` RHS

Scope: finish the post-PR #33 reader-path sweep for wide data-frame
formula input. The `traits(...)` LHS path now expands compact wide RHS
syntax before dispatching to the long engine: `1` becomes `0 + trait`,
ordinary predictors become `(0 + trait):x`, and covariance keywords
such as `latent(1 | unit)`, `unique(1 | unit)`, `indep(1 | unit)`,
`dep(1 | unit)`, bar-style `phylo_indep(1 | species)` /
`phylo_dep(1 | species)`, and `spatial_*()` become the matching
trait-stacked long terms. Species-axis phylogenetic calls such as
`phylo_latent(species, d = K)` and ordinary `(1 | group)` random
intercepts pass through unchanged.

Files synchronised:

- `R/traits-keyword.R`, `R/gllvmTMB.R`, `R/gllvmTMB-wide.R`;
- `tests/testthat/test-traits-keyword.R`,
  `tests/testthat/test-weights-unified.R`;
- `README.md`, `_pkgdown.yml`, `NEWS.md`, `AGENTS.md`, `CLAUDE.md`,
  `docs/design/02-data-shape-and-weights.md`;
- `vignettes/articles/morphometrics.Rmd`,
  `vignettes/articles/behavioural-syndromes.Rmd`,
  `vignettes/articles/functional-biogeography.Rmd`;
- regenerated `man/gllvmTMB.Rd`, `man/gllvmTMB_wide.Rd`, and
  `man/traits.Rd`;
- after-task report:
  `docs/dev-log/after-task/2026-05-12-long-wide-reader-sweep.md`.

Checks:

- pre-edit lane check found PR #35 open and PR #36 merged; PR #36's
  check-log append was fast-forwarded into this branch before this
  append;
- `Rscript --vanilla -e 'devtools::test(filter = "traits-keyword|weights-unified")'`:
  passed with `FAIL 0 | WARN 0 | SKIP 1 | PASS 65`; the skip is the
  existing fixed-effect-only fallback skip;
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`:
  completed and regenerated `man/traits.Rd` after the final
  phylogenetic wording fix;
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/morphometrics", new_process = FALSE)'`:
  completed; only the pre-existing `../logo.png` warning was reported;
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::check_pkgdown()'`:
  passed with "No problems found";
- Rose pre-publish targeted scans found no stale `traits()` status or
  RHS-rewrite wording, and no remaining over-broad phylogenetic
  pass-through wording;
- `git diff --check`: passed.
- recovery follow-up after Codex stream failure: parser review found
  that subtractive formula controls such as `-1` could be expanded to
  `-(0 + trait)`. The RHS expander now preserves subtractive `1`
  literally while still expanding compact positive terms. Direct probes
  returned `-1 + (0 + trait):env_temp` and
  `0 + trait + (0 + trait):env_temp - 1`; `air format
  R/traits-keyword.R tests/testthat/test-traits-keyword.R` completed;
  `Rscript --vanilla -e 'devtools::test(filter = "traits-keyword|weights-unified")'`
  passed with `FAIL 0 | WARN 0 | SKIP 1 | PASS 71`.
- full-suite recovery attempt: `Rscript --vanilla -e
  'devtools::test()'` was run without explicit multi-core settings and
  interrupted after about 14 minutes while computing
  `phylo-q-decomposition` (`sigma2_Q recovered within 50% relative
  error`). Do not count this as a full-suite pass. Future bootstrap- or
  recovery-heavy validation should use explicit multi-core settings
  where supported.
- bootstrap wording scan: touched public prose still points readers
  toward Wald or profile intervals where appropriate;
  bootstrap is described as a slower deliberate cached check, not the
  default inferential recommendation.
- Claude review follow-up for PR #39: reverted the scope-expansion
  change that renamed the `extract_correlations()` default. Source,
  focused tests, and generated Rd are back to
  `method = c("fisher-z", "profile", "wald", "bootstrap")`; touched
  vignettes and NEWS again describe `fisher-z` as the default and
  `wald` as the alias. This keeps the compact `traits(...)` RHS pivot
  separate from the extractor-default decision.
- post-review validation after the default revert:
  `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` completed;
  a direct probe returned default `method` label `fisher-z`;
  `Rscript --vanilla -e 'devtools::test(filter = "fisher-z-correlations|traits-keyword|weights-unified")'`
  passed with `FAIL 0 | WARN 1 | SKIP 1 | PASS 87`; the one warning
  is the restored legacy `tier = "B"` alias warning inside
  `test-fisher-z-correlations.R`, not a default-method failure;
  `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::check_pkgdown()'`
  passed with "No problems found"; `git diff --check` passed.
- Rose pre-publish terminology gate after the default revert: PASS.
  Source formals, generated Rd, NEWS, and touched vignettes agree that
  `extract_correlations()` defaults to `method = "fisher-z"`; `wald`
  remains an alias or a separate extractor method where explicitly
  requested.
- next-lane notation guard: for the maintainer-dispatched item #1
  lane ("phylogenetic / two-U doc-validation branch"), "two-U" is a
  legacy task label only. Public math and user-facing prose should
  translate the unique diagonal component to current `gllvmTMB`
  notation: `S` / `s`, e.g. `Sigma = Lambda Lambda^T + S`, `S_phy`,
  and `S_non`, not legacy `U`, `U_phy`, or `U_non`.
- post-fast-forward validation after PR #37/#38 landed on `origin/main`:
  `Rscript --vanilla -e 'devtools::test(filter = "fisher-z-correlations|traits-keyword|weights-unified")'`
  passed with `FAIL 0 | WARN 0 | SKIP 1 | PASS 87`;
  `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::check_pkgdown()'`
  passed with "No problems found"; `git diff --check` passed.

Known remaining validation gap: the full package test suite was
attempted but interrupted before completion, and `devtools::check()`
was not rerun in this narrow resume pass.

## 2026-05-12 -- Phylogenetic / two-U doc-validation branch

Branch: `codex/phylo-two-u-doc-validation`.

Maintainer dispatch: proceed with Codex-owned work while main CI and
pkgdown finish, but cap the branch at three user-visible items. Scope:

1. add a public phylogenetic trait-covariance article using current
   `S/s` notation and long + wide data-frame syntax;
2. add a design note pinning the current phylogenetic GLLVM math and
   syntax contract;
3. add a focused current-code guard that compact wide `traits()`
   phylogenetic syntax matches explicit long syntax.

Pre-edit Shannon check: working tree clean on `main`, zero open PRs,
recent history shows PR #39 merged, and no other branch currently owns
the target article/design/test files. Post-merge main R-CMD-check is
still running on GitHub, but the maintainer explicitly allowed starting
the next branch without waiting for that integration run.

Validation:

- live pre-write probe fitted the intended long and wide data-frame
  phylogenetic formulas, both converged with code `0`, and the
  log-likelihood difference was `0`;
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` completed,
  updating the generated Rd files for the S/s notation sweep;
- `Rscript --vanilla -e 'devtools::test(filter = "traits-keyword|two-U-cross-check|extract-omega")'`
  passed with `FAIL 0 | WARN 2 | SKIP 1 | PASS 82`; both warnings are
  the existing `B`/`W` deprecation checks in `test-extract-omega.R`;
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/phylogenetic-gllvm", new_process = FALSE); pkgdown::build_article("articles/covariance-correlation", new_process = FALSE)'`
  completed; both affected article renders emitted only the known
  missing `../logo.png` pkgdown warning;
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::check_pkgdown()'`
  passed with "No problems found";
- `git diff --check` passed.

## 2026-05-12 -- Ordinal-probit Tier-2 reference

Branch: `codex/ordinal-probit-tier2`.

Maintainer dispatch context: after PR #46 merged, proceed with the
next Codex-owned Tier-2 article from the salvage queue. Scope is one
article: add `ordinal-probit.Rmd` as a compact technical reference for
`ordinal_probit()`, plus pkgdown/NEWS/dev-log hygiene.

Pre-edit Shannon check: working tree clean on `main`; open PRs #47,
#48, and #49 are agent PRs. They do not touch `_pkgdown.yml`,
`NEWS.md`, or `vignettes/articles/ordinal-probit.Rmd`; PR #48 touches
README/design prose and should merge separately. Post-merge main
R-CMD-check for PR #46 is running, but this branch starts from the
current merge commit and avoids implementation files.

Final Shannon recheck: after fetching, `origin/main` had advanced to
PR #47's merge commit. Open PRs #48 and #50 do not touch this branch's
files; #48 changes README/design prose, and #50 changes
`docs/dev-log/known-limitations.md` plus its own after-task note.

Validation:

- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`:
  completed and regenerated only `man/extract_cutpoints.Rd` after the
  stale `extract_cutpoints()` example was aligned to canonical
  `phylo_unique(species, tree = tree)` syntax;
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE);
  pkgdown::build_article("articles/ordinal-probit", new_process =
  FALSE); pkgdown::build_article("articles/response-families",
  new_process = FALSE)'`: completed; only the pre-existing
  `../logo.png` pkgdown warning was reported for both articles;
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`: passed with "No
  problems found";
- `Rscript --vanilla -e 'devtools::test(filter =
  "ordinal-probit|traits-keyword")'`: passed with `FAIL 0 | WARN 0 |
  SKIP 1 | PASS 74`; the skip is the existing fixed-effect-only
  fallback skip in `test-traits-keyword.R`;
- Rose pre-publish gate: article claims were checked against
  `R/families.R`, `R/fit-multi.R`, `R/extract-cutpoints.R`,
  `R/extract-sigma.R`, and `tests/testthat/test-ordinal-probit.R`.
  No mismatch found for family names, `K = 2`, cutpoint convention,
  `sigma_d^2 = 1`, OLRE mapping, or latent-scale correlation wording.

## 2026-05-12 -- API keyword grid Tier-2 reference

Branch: `codex/api-keyword-grid-tier2`.

Maintainer dispatch context: after PR #45 merged, continue with the
next Codex-owned item from the Tier-2 article salvage queue. Scope is
one article: port `api-keyword-grid.Rmd` as a Tier-2 technical
reference, plus pkgdown/NEWS/dev-log hygiene.

Pre-edit lane check: open PRs #43 and #44 are Claude audit PRs adding
their own `docs/dev-log/after-task/` and
`docs/dev-log/shannon-audits/` files only; no overlap with this
branch's article, `_pkgdown.yml`, `NEWS.md`, or check-log entry.

Validation:

- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/api-keyword-grid", new_process = FALSE)'`
  completed; the render emitted only the known missing `../logo.png`
  pkgdown warning;
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::check_pkgdown()'`
  passed with "No problems found";
- Rose pre-publish gate: PASS. The grid in the article matches
  `README.md`, `docs/design/00-vision.md`, and `R/gllvmTMB.R`; helper
  terms `phylo_slope()` and `meta_known_V()` are named as outside the
  grid; no method/default claims were introduced;
- `git diff --check` passed.

## 2026-05-12 -- Response families Tier-2 reference

Branch: `codex/api-keyword-grid-tier2`.

Maintainer dispatch context: while PR #46 R-CMD-check and the latest
main R-CMD-check were still running, continue under the maintainer's
cap of at most three branch items. This is item 2 on the same branch:
add `response-families.Rmd` as a Tier-2 technical reference and keep
the change to docs/nav/news/check-log/after-task files.

Pre-edit Shannon check: working tree clean; the only open PR is #46,
the current branch; recent history shows the Claude audit PRs #43 and
#44 already merged. No other open branch owns the response-family
article.

Validation:

- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/response-families", new_process = FALSE); pkgdown::build_article("articles/choose-your-model", new_process = FALSE)'`
  completed; both renders emitted only the known missing `../logo.png`
  pkgdown warning;
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::check_pkgdown()'`
  passed with "No problems found";
- Rose pre-publish gate: PASS. The quick-lookup table matches the 15
  `family_to_id()` entries in `R/fit-multi.R`; exported constructors
  present in `R/families.R` / `NAMESPACE` but absent from
  `family_to_id()` are named as unsupported in multivariate
  `gllvmTMB()` fits rather than advertised as engine-supported; stale
  `mixed-response.html` links in `choose-your-model` now point to the
  new response-family reference. A final source check against
  `R/extract-correlations.R` and `R/extract-sigma.R` added an explicit
  two-part-family caveat: `extract_correlations()` reports fitted
  covariance-tier correlations, while `extract_Sigma(link_residual =
  "auto")` uses approximate diagonal link-residual corrections for
  `delta_lognormal()` / `delta_gamma()`, not a full observed-scale
  two-part correlation estimand;
- `git diff --check` passed.

## 2026-05-12 -- Theory/fit gap in Tier-1 article (PR #45 caught by maintainer; fixed in PR #53)

Recurring pattern flagged. Audience: future Tier-1 article ports
(Codex one-PR-per-article queue per PR #41) and Tier-1 article
revisions.

Pattern: when an article's **theory section** writes a paired
decomposition in parallel notation (e.g. for `phylogenetic-gllvm.Rmd`
the theory wrote `Sigma_phy = Lambda_phy Lambda_phy^T + S_phy` AND
`Sigma_non = Lambda_non Lambda_non^T + S_non`), the **simulation**
and the **fit** in the same article must include each component
named in the theory. PR #45 wrote the paired theory but the
simulation only generated `Lambda_phy + S_phy + S_non` (no
`Lambda_non`) and the fit only had `phylo_latent + phylo_unique +
unique` (no `latent()` for the non-phy side). The reader following
theory side-by-side with syntax notices the missing `latent()` term
and is rightly confused.

What this breaks beyond cosmetics:

- `extract_communality(fit, level = "unit")` requires both a
  `latent()` and a `unique()` term at the tier to compute
  `c_t^2 = diag(Lambda Lambda^T) / diag(Lambda Lambda^T + S)`.
  Without the non-phy `latent()` term, the function is
  structurally undefined on the non-phy side.
- `extract_phylo_signal(fit)` returns a three-way decomposition
  `H^2 + C^2_non + Psi = 1` per trait. Without the non-phy
  `latent()` term, `C^2_non` is structurally 0 and the "three-way"
  decomposition collapses to a two-way `H^2 + Psi` masquerading as
  three-way -- which is the maintainer's specific phrasing:
  "the decomposition of phylogenetic heritability does not really
  make sense" when the formula is the 3-component model.

Process check for future Tier-1 article ports / revisions:

1. When the theory section writes a paired or n-fold decomposition,
   audit each named component is in the simulation and in the fit.
2. **Run the motivating extractor** for the decomposition (e.g.
   `extract_communality`, `extract_phylo_signal`, `extract_ICC_site`,
   `extract_proportions`) and include it in the article. The
   extractor's output is the test that catches theory/fit drift --
   structurally-zero columns and `NULL`-returning calls are the
   smoking gun.
3. Cross-check that the simulation truth values map one-to-one to
   the fit's covariance keywords (e.g. `Lambda_phy_true` ->
   `phylo_latent`; `s_phy_true` -> `phylo_unique`;
   `Lambda_non_true` -> `latent(... | species)`; `s_non_true` ->
   `unique(... | species)`).
4. Set `eval = TRUE` on diagnostic chunks
   (`compare_dep_vs_two_U`, `compare_indep_vs_two_U`) when the fit
   is cheap enough -- a flagged `$agreement` row is more pedagogical
   than a fenced code block the reader never sees executed.

This is the *second* time a paired-decomposition article has had
this gap (maintainer's "I think we already talked about this").
The previous instance was in a legacy article; the pattern is
recurrent. Adding to the process discipline so we catch it on
authoring, not after the live pkgdown site exposes it.

## 2026-05-13 -- Covariance-correlation article substantive fix (Codex lane)

Coordination:

- Shannon-style lane check before editing found open Claude PRs #55,
  #59, and #60. PR #55 had already dropped
  `vignettes/articles/covariance-correlation.Rmd` and now touches only
  `api-keyword-grid.Rmd`, `behavioural-syndromes.Rmd`,
  `choose-your-model.Rmd`, and its after-task report. PR #59 touches
  `AGENTS.md`, `CLAUDE.md`, and a distinct after-task report. PR #60
  touches `README.md`, `NEWS.md`, and a distinct after-task report.
  No open PR touched `R/extract-sigma.R`,
  `tests/testthat/test-extract-sigma.R`,
  `tests/testthat/test-extract-omega.R`, or
  `vignettes/articles/covariance-correlation.Rmd`.
- Posted a PR #55 coordination comment:
  <https://github.com/itchyshin/gllvmTMB/pull/55#issuecomment-4439530651>.
  Codex owns the covariance-correlation article lane and will avoid the
  three article files still owned by PR #55.

Implemented:

- `vignettes/articles/covariance-correlation.Rmd` now separates the
  ordinary non-phylogenetic `unique()` term from `phylo_unique()`. The
  phylogenetic section now states
  `Sigma_phy = Lambda_phy Lambda_phy^T + S_phy`,
  `Sigma_non = Lambda_non Lambda_non^T + S_non`, and
  `Omega = Sigma_phy + Sigma_non`, matching
  `docs/design/03-phylogenetic-gllvm.md` and the 2026-05-12 S/s
  notation decision.
- The article no longer shows legacy `extract_communality(fit, "B")`
  calls or `Sigma_B` / `S_B` comments in the demonstrated
  `extract_Sigma()` workflow.
- `extract_Sigma()` now reports the canonical level label in its
  missing-`unique()` advisory, so rendered pages show `Sigma_unit`
  rather than `Sigma_B` when the user called `level = "unit"`.
- `R/extract-sigma.R` roxygen and `man/extract_Sigma.Rd` now present
  `level = "unit"` / `"unit_obs"` as the primary interface while still
  documenting `"B"` / `"W"` as legacy aliases.
- Targeted tests now use canonical extractor levels where they are not
  explicitly testing legacy alias behaviour, and the missing-`unique()`
  advisory has a regression assertion for `Sigma_unit` and against
  `Sigma_B`.

Checks run:

- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` completed
  and regenerated `man/extract_Sigma.Rd`.
- `tail -12 man/extract_Sigma.Rd` ended in the expected `\seealso{...}`
  block; `grep -c '^\\keyword' man/extract_Sigma.Rd` returned `0`
  because this topic has no keyword tag.
- `Rscript --vanilla -e 'devtools::test(filter = "extract-sigma")'`
  passed: `FAIL 0 | WARN 0 | SKIP 0 | PASS 31`.
- `Rscript --vanilla -e 'devtools::test(filter = "extract-sigma|sigma-rename|extract-omega|mixed-response-sigma")'`
  passed: `FAIL 0 | WARN 0 | SKIP 1 | PASS 70`; the skip is the
  pre-existing `.normalise_level()` migration skip in
  `test-sigma-rename.R`.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/covariance-correlation", new_process = FALSE)'`
  rendered `articles/covariance-correlation.html`; only the known
  `../logo.png` pkgdown image warning appeared.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::check_pkgdown()'`
  passed with "No problems found."
- `rg -n 'Sigma_B|S_B|"B"|\\+ U|diag\\(U\\)|U_phy|U_non|no associated|three-piece|3-piece' vignettes/articles/covariance-correlation.Rmd pkgdown-site/articles/covariance-correlation.html`
  returned no hits after the final article render.
- Focused Rose scan found only intentional legacy-alias documentation
  in `R/extract-sigma.R` / `man/extract_Sigma.Rd` and the active
  `phylo_latent()` / `phylo_unique()` wording in the touched article.
- Export/source check confirmed `extract_Sigma`, `extract_Omega`,
  `extract_communality`, `phylo_latent`, and `phylo_unique` are exported
  and defined in the expected R files.

Not run:

- Full `devtools::test()` and `devtools::check()` were not run in this
  lane; the change is scoped to one article, one extractor advisory,
  roxygen text for that extractor, and targeted tests.

## 2026-05-13 -- Covariance-correlation Pat/Rose reread (Codex lane)

Coordination:

- Continued on `codex/covariance-correlation-pat-rose-reread`.
  Open PR census showed only PR #68 touching
  `docs/dev-log/coordination-board.md`; the coordination board still
  assigns `vignettes/articles/covariance-correlation.Rmd` to Codex.
- Pat read the article as an applied-user Tier-1 page. Rose read it
  as a pre-publish consistency gate. Their highest-impact findings
  were folded into the article before validation.

Implemented:

- The article now opens with the behavioural-syndrome use case and
  shows the latent-only failure model beside the `latent() + unique()`
  fix before the decomposition.
- The opening now includes the wide data-frame equivalent through
  `gllvmTMB(traits(...) ~ ...)`, avoiding the soft-deprecated
  `gllvmTMB_wide()` path.
- The decomposition prose defines `level`, keeps `S` / `s` notation,
  and removes overbroad wording such as "Every published GLLVM
  treatment" and "come up everywhere".
- Two-level and OLRE examples now show `unit_obs = "obs_id"` whenever
  they use `obs_id` as the within-individual or observation-level tier.
- The stale "Future work" OLRE heading is now current-support wording.
  The See also block links to `?unique`, `?extract_Sigma`, and
  `?suggest_lambda_constraint` instead of stale or missing targets.

Checks run:

- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/covariance-correlation", new_process = FALSE)'`
  rendered `articles/covariance-correlation.html`; only the known
  `../logo.png` pkgdown image warning appeared.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` passed with
  "No problems found."
- `git diff --check` passed.
- Targeted Rose scan over the article and rendered HTML found no
  stale hits for `diag(U)`, `U_phy`, `U_non`, `gllvmTMB_wide`,
  `unique (unique)`, `Future work`, `lambda-constraint.html`, or
  `diag_re`.

Not run:

- Full `devtools::test()` and `devtools::check()` were not run; this
  lane changes one article and dev-log bookkeeping only.

## 2026-05-13 -- Rebuild-canon drift: surface audit is not enough (Kaizen)

Recurring pattern flagged. Audience: every future agent (Claude,
Codex, or human) writing or auditing user-facing prose in this
package.

Pattern: the package was rebuilt from scratch in 2026-05; pre-rebuild
prose, paper-internal labels, and in-prep equation references were
inherited from legacy articles / drafts. Surface spot-checks
(notation, legacy aliases, single-entry-point) catch the easy drift
but miss FRAMING drift -- claims that contradict the rebuilt
canonical model.

Today's findings (2026-05-13 11:00 - 12:00 MT):

- **53 R/ roxygen findings** (35 HIGH, 12 MEDIUM, 6 LOW). Three
  hotspots:
  - `R/unique-keyword.R:54-58` says `phylo_latent(species, d = K)`
    has no associated `unique()` because the phylogenetic prior is
    already structured. This **contradicts** the canonical paired
    four-component model (PR #53). The user-facing keyword doc
    actively misdirected readers away from `phylo_unique()`.
  - `R/extract-omega.R` made `phylo_unique()` "optional" in
    `extract_phylo_signal()` docs; called the three-component
    decomposition "PGLLVM" (drops `phylo_unique`).
  - Multiple in-prep equation citations
    ("manuscript Eq. 13", "Eq. 14", "Eq. 15", "Eq. 19",
    "Eq. 23-25", etc.) -- equation numbers from an unpublished
    paper that can renumber before publication. These would
    have shipped to CRAN with stale references.
  - Runtime `cli_inform()` / `cat()` messages with M1/M2 jargon
    and in-prep equation numbers (`R/fit-multi.R`, `R/diagnose.R`).
- **83 vignette findings** (42 HIGH). Notable new ones beyond
  the in-flight fixes (PRs #74-78):
  - `choose-your-model.Rmd:195` recommends `unique()` for "full
    unstructured covariance" -- **wrong**: `unique()` is the
    diagonal `S`; full unstructured is `dep()`.
  - `functional-biogeography.Rmd` uses `\Psi` notation instead of
    canonical `\mathbf S` (6 hits).
  - `joint-sdm.Rmd` has "Phase D follow-up", "Phase K's warm-
    started" internal milestone labels in user-facing prose.
  - Two divergent in-prep paper titles cited across articles:
    "Functional biogeography using GLLVM" vs "Quantifying
    between- and within-individual correlations and the degree of
    trait integration".
  - Extractor API has `tier=` and `level=` for analogous
    parameters in sibling extractors -- reader-visible
    inconsistency.

The Rose audit (PR #62 / #64) caught about 6 of these. Two follow-up
agents (general-purpose, deep-brief) caught the remaining ~130. The
first Explore agent on the same data flagged "very minimal drift"
because it scanned surface patterns -- exactly the failure mode the
maintainer keeps calling out.

**The lesson, recorded so future agents do not repeat it:**

When auditing user-facing prose in a rebuilt-from-scratch package,
surface spot-checks (notation, legacy aliases, single-entry-point)
are necessary but NOT sufficient. Every **prescriptive claim** must
be re-read against the current canonical model.

Concrete audit checklist for prose and roxygen:

1. **Every `##` / `###` section header**: does the title imply a
   claim that contradicts the canon? Specifically watch for "When X
   is not Y", "In special case Z", "If S = 0", "phylo_X vs phylo_Y"
   -- framings that hide a recommendation against the canonical
   pattern.
2. **Every `@title` and `@description` in roxygen**: does the
   first line of the function doc imply the same drift? Reference
   index is what CRAN reviewers see first.
3. **Every code chunk / `@examples` block**: do the calls match the
   current canonical pattern (paired `latent + unique`,
   `phylo_latent + phylo_unique`, `level = "unit"` not `"B"`)?
4. **Every `cli::cli_*` / `cat()` runtime message**: does the
   user-visible message use paper-internal labels (M1, M2),
   in-prep equation numbers, or stale framings?
5. **Every `(Eq. N)` / `(Eqs. N-M)` / "manuscript Eq."**: does the
   citation point at an in-prep paper? Equation numbers from
   unpublished work are unstable. Drop the specific number;
   keep the author/year pointer.
6. **Every reference to a sister-article**: does the link target
   exist? If it points at `corvidae-two-stage.html`,
   `simulation-recovery.html`, etc., verify the file is present
   under `vignettes/articles/`.
7. **Every "Phase D / Phase K / dev/design/..." mention**:
   internal milestone labels do not belong in user-facing prose.
8. **Every `phylo_*()` recommendation**: does it pair with
   `phylo_unique()` (per the canonical four-component
   decomposition)? Bare `phylo_latent` is the no-residual subset;
   bare `phylo_scalar` is single-scalar. Neither is the default.
9. **Every `\Psi`, `\Omega`, `U`, `U_phy`, `U_non`**: math should
   use `\mathbf S`, `\mathbf S_\text{phy}`, `\mathbf S_\text{non}`
   per PR #40 + PR #72 naming convention.

**Process recommendation**: when porting or auditing an article,
spawn a deep agent with the canonical model in its briefing and ask
it to flag prescriptive claims, not just surface patterns. The brief
needs to enumerate the canon explicitly (single entry point,
canonical paired decomposition, four-component phylo,
S/s notation, etc.) so the agent can check claim-by-claim.

This entry exists to prevent recurrence. PRs #76, #77, #78 fixed
specific instances of this pattern across articles; the broader
audit produced ~136 more findings split across roxygen and
articles, in progress.

