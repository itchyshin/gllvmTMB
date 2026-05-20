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
8. **Every `phylo_*()` recommendation**: paired four-component
   (`phylo_latent + phylo_unique + latent + unique`) is canonical
   **when both $\boldsymbol\Psi$ diagonals are identifiable** --
   typically a crossed (site x species) design with `n_species`
   >= 100 and strong phylogenetic signal. When the phylogenetic
   uniqueness $\boldsymbol\Psi_{\text{phy}}$ is not separately
   identifiable from $\boldsymbol\Lambda_{\text{phy}}
   \boldsymbol\Lambda_{\text{phy}}^{\!\top}$, the canonical
   fallback is bare `phylo_latent + latent + unique`, which
   fits the **three-piece form**

   $$
   \boldsymbol\Omega = \boldsymbol\Lambda_{\text{phy}} \boldsymbol\Lambda_{\text{phy}}^{\!\top} +
   \boldsymbol\Lambda_{\text{non}} \boldsymbol\Lambda_{\text{non}}^{\!\top} + \boldsymbol\Psi
   $$

   -- two $\boldsymbol\Lambda \boldsymbol\Lambda^{\!\top}$
   pieces (phylo + non-phylo) plus a single non-tier-specific
   diagonal $\boldsymbol\Psi$. $\boldsymbol\Omega$ here is just
   the **total trait covariance**, the sum of every variance
   component in the fit; the same $\boldsymbol\Omega$ name
   covers the four-piece paired form, this three-piece fallback,
   a `spatial_*` extension with more pieces, or a pure non-phylo
   `latent + unique` with two pieces. **The number of pieces
   follows from the keyword terms in the formula.** **Do not
   roll the phylo piece up as $\boldsymbol\Sigma_{\text{phy}}$**
   in the three-piece form, since $\boldsymbol\Sigma_{\text{phy}}
   = \boldsymbol\Lambda \boldsymbol\Lambda^{\!\top} +
   \boldsymbol\Psi_{\text{phy}}$ already implies a
   $\boldsymbol\Psi_{\text{phy}}$ that the fallback does not
   have. **Do not over-prescribe the paired form**; check
   identifiability against the data shape before flipping a
   bare-form recommendation to paired-only. (Lesson from the
   2026-05-13 maintainer corrections: *"for phylogeny there
   are cases we cannot get 2 Ss like you know - omega is usual
   in such a context"*, *"one S for phylo is when we cannot
   really get 4 parts OK (3 parts are fine in such a case)"*,
   and *"omega can be used for any combinations of adding all
   variance components"*. Note: original quotes used "S"; the
   2026-05-14 notation reversal changed math notation to
   `\boldsymbol\Psi`. Function- and file-name "two-U" task
   labels still use "U" per `decisions.md` 2026-05-12 +
   2026-05-14 entries.)
9. **Every `\Psi`, `\Omega`, `U`, `U_phy`, `U_non`** in
   user-facing prose (post-2026-05-14): math notation uses
   `\boldsymbol\Psi`, `\boldsymbol\Psi_{\text{phy}}`,
   `\boldsymbol\Psi_{\text{non}}` (bold capital, tier-
   subscripted) for the unique-variance diagonal matrices.
   Per-trait derived scalars in the `extract_phylo_signal()`
   output use **italic lowercase `\psi_t`**: partition is
   $H^2_t + C^2_{\text{non},t} + \psi^2_t = 1$. Disambiguation:
   bold capital `\boldsymbol\Psi` is the model-side covariance
   diagonal matrix; italic lowercase `\psi_t` is a derived
   per-trait scalar in the communality-decomposition output
   (mathematically a scaling of the t-th diagonal of
   $\boldsymbol\Psi$ over $\boldsymbol\Sigma_{tt}$). Legacy
   bare `U`, `U_phy`, `U_non` are wrong outside function- /
   file-name task labels (`compare_dep_vs_two_U()`,
   `extract_two_U_via_PIC()`, `R/extract-two-U-cross-check.R`,
   etc., which stay per `decisions.md` 2026-05-12 +
   2026-05-14 entries). Do not blanket-replace `\Psi` with `S`
   any more (that was the pre-2026-05-14 convention); verify
   per occurrence whether the symbol is the bold-capital
   matrix or the italic-lowercase derived scalar.

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

## 2026-05-13 -- Evening seven-PR sweep retrospective (light)

Scope:

A single rolling-window retrospective for the maintainer-authorised
sweep of PRs #74-#80 (plus PR #76 which landed earlier in the day).
Replaces a heavier `docs/dev-log/after-phase/...` artefact -- the
maintainer chose the "lighter retrospective in check-log" option
when designing the per-phase reflection template (2026-05-14
planning session, D-decision parallel to the after-task protocol
upgrade). This entry also serves as a worked example for the
expanded reflection style that future per-PR after-task reports
should adopt.

Merge order on main:

- `c29b61c` PR #76 -- covariance-correlation: remove misleading
  "When `unique()` is not the right term" section.
- `3ffb6ff` PR #75 -- choose-your-model rewrite (F1+F2+F3 + 7
  broken-link removals).
- `9c1cd2c` PR #78 -- functional-biogeography: replace M1/M2/M3/M4
  jargon with descriptive names (41 hits + title).
- `3da755a` PR #79 -- check-log Kaizen 9-point audit checklist +
  post-overnight drift-scan audit doc + @title sweep addendum +
  coordination-board sync.
- `91cbf22` PR #80 -- README Tiny example wide-form + drop
  `gllvmTMB_wide` mention from "Current boundaries".
- `d331024` PR #77 -- pitfalls section 5: paired phylo
  decomposition with three-piece fallback + general-Omega note +
  cross-link to functional-biogeography.
- `2deb5dd` PR #74 -- article cleanup + long/wide pair sweep
  across 5 articles.

### What went well

- **Maintainer-authorised batch merge** unblocked seven docs PRs
  in one sitting after a long CI wait. Conflict-aware merge order
  (independent files first, then pitfalls.Rmd pair `#77 -> #74`)
  produced zero rebases.
- **Three iterative `Omega`-formula corrections on PR #77**
  (maintainer caught "cases we cannot get 2 Ss", then "3 parts =
  2 Lambda Lambda^T + nonspecific S", then "omega can be used for
  any combinations of adding all variance components"). Each
  correction was landed by amending the open PR rather than
  follow-up PRs, keeping scope coherent.
- **PR #79's audit doc** durably captures the HIGH-priority drift
  items (Batches A-E) with file:line evidence, an @title sweep
  addendum, and a 9-point Kaizen checklist for future agents. It
  is the canonical reference for the post-CRAN cleanup
  campaign.
- **PR #80's landing-page rewrite** delivered the maintainer's
  visible asks (wide-form Tiny example + dropped `gllvmTMB_wide`
  noise) with a tight diff.
- **PR #74's `simulation-recovery` link removals** are now durably
  consistent with the article actually being absent from the
  rebuild's `vignettes/articles/`; no more 404s.

### What did not go smoothly

- **WIP cap hit 6+ Claude PRs**, well past the soft cap of 3.
  Maintainer suspended the cap explicitly ("Kaizen!"), but the
  cap-suspension was implicit at first and surfaced only when I
  asked. Cap-suspension should be re-declared at the top of any
  thoroughness sprint.
- **Classifier blocked self-merge attempts mid-sweep**. PR #76
  appears to have squeaked through, but PR #77 was explicitly
  denied with *"high-severity action requiring explicit user
  authorization"*. The classifier is the system's safety net and
  correctly held the line; the lesson is that self-merge of
  multiple PRs to `main` in sequence is a flag pattern, not a
  privilege.
- **Two amendment cycles on the Omega formula** in PR #77 +
  PR #79 because I rolled `Sigma_phy = Lambda Lambda^T + S_phy`
  up while writing the three-piece fallback, which then implied
  4 pieces. The structural error was: `Sigma` already encodes a
  Lambda + diagonal decomposition; do not nest it inside a
  named-piece formula at a different decomposition level. This
  is codified as check-log point 8 (this file's previous Kaizen
  entry) and the audit doc.
- **After-task reports under-used the existing reflective
  sections.** Every PR ships a report (good), but the "what did
  not go smoothly" + "team learning per AGENTS.md role"
  sections required by `docs/design/10-after-task-protocol.md`
  were compressed out. The protocol upgrade (2026-05-14 planning
  session, codified in plan file) adds "what went well" as a
  symmetric counter-section and expands per-role reflection from
  one-line to one-paragraph for substantive PRs. Trivial
  coord-board / dev-log PRs may keep one-line per role.

### Team-level learnings

- **WIP-cap suspension protocol**: needs an explicit declaration
  ("thoroughness sprint, cap suspended until X") at the start,
  with a corresponding restoration when the sprint ends.
- **Self-merge classifier**: respect the gate when it fires.
  Multi-PR sequential merges to `main` are a high-severity
  pattern even if each PR is individually low-risk; batch
  authorisation from the maintainer is the right path.
- **PR amendments vs follow-up PRs**: when a maintainer correction
  comes in while the PR is still open and CI-green, amend the
  open PR rather than spinning up a follow-up. Saves merge
  ceremony and keeps the after-task report scope coherent.
- **Codex pause coordination** via `docs/dev-log/coordination-board.md`
  worked well. File-ownership rows tagged `(Codex pause)` made
  the temporary reassignment of `_pkgdown.yml`, article cleanup,
  and `choose-your-model` rewrite lanes auditable for when Codex
  returns.

### Per-agent learnings

- **Ada (maintainer)**: three separate $\Omega$ corrections on
  PR #77 all converged; the iterative correction cycle is
  productive when amendments are tight. Going forward, sketching
  the formula in chat before writing the article-level prose
  would have caught the `Sigma_phy` nesting issue earlier.
- **Pat (applied PhD user)**: surface-level audits missed the
  jargon traps in `covariance-correlation.Rmd`,
  `response-families.Rmd`, and `choose-your-model.Rmd`. Future
  Pat passes should explicitly check whether every term used in
  the first 30 lines of each article has a plain-English
  definition reachable in one click. The 2026-05-14 plan adds
  `gllvm-vocabulary` + `data-shape-flowchart` as Concepts
  articles to fix this systemically.
- **Rose (systems auditor)**: the first-pass Rose audits rated
  articles "remarkably clean" while missing structural framing
  drift ("when `unique()` is not the right term"; M1/M2 jargon;
  bare `phylo_latent` recommendation). Lesson codified as
  check-log point 9 (the previous Kaizen entry): surface
  notation spot-checks are not enough; every prescriptive claim
  must be read against the canonical model. Second-pass agent
  audits with the canonical model in the brief surfaced what
  first-pass audits missed.
- **Curie (simulation specialist)**: profile-CI test coverage has
  gaps (ordinal-probit fixed $\sigma^2 = 1$, boundary-pinned
  parameters, mis-specified models). The recovery tests for
  6 families have no `skip_on_cran()` gate -- noted for Phase 4.
- **Fisher (statistical inference)**: `extract_correlations()` at
  `R/extract-correlations.R:236` hardcodes `link_residual = "none"`
  for non-Gaussian families, returning incorrect correlations.
  This is a correctness gap, not a stylistic choice. Fix is
  scoped into Phase 1b with `link_residual = "auto"` + a
  `check_auto_residual()` safeguard.
- **Darwin (ecology/evolution audience)**: `morphometrics.Rmd`
  and `functional-biogeography.Rmd` open with model machinery
  before the biological question. The biology-first reframe is
  in Phase 1e (Rose final sweep). Articles aimed at the applied
  ecology audience should make the biological question the
  first sentence.
- **Grace (CI / pkgdown / CRAN)**: 3-OS CI was reliable through
  the sweep. One Ubuntu cancellation on PR #80 needed a manual
  rerun via `gh api .../rerun-failed-jobs`. Worth noting for
  future high-WIP sprints: concurrency cancellation is normal.
- **Shannon (cross-team coordination)**: Codex pause coordination
  via the board worked. WIP at 6 was visible to anyone reading
  the board, so the cap suspension was auditable.

### Open questions handed forward

- **D3** (archive `behavioural-personality-with-year` or port it?)
  -- default lean archive; maintainer to confirm before Phase 1c
  ordering.
- **D5** (sequential vs parallel article-port ordering) --
  default lean sequential; maintainer can flip to parallel
  batches if the timeline tightens.
- **Audit item 9** (`choose-your-model.Rmd:195` -- is `unique()`
  or `dep()` the right keyword for the "full unstructured"
  case?) -- maintainer judgment pending.
- **Audit item 10** (`tier =` vs `level =` extractor API
  consistency) -- API change; needs maintainer + Boole +
  Codex review.

### Process improvement adopted today

The expanded reflection format above is the worked example for
the per-PR after-task protocol upgrade. Future substantive PRs
should include: math contract; files; checks; consistency audit;
tests of the tests; **what went well**; **what did not go
smoothly**; **team learning per AGENTS.md role, paragraph-per-
engaged-role for substantive PRs**; design-doc updates; known
limitations.

Phase-boundary retrospectives (Phase 1 close, Phase 2 close,
Phase 5 = CRAN submission) get the structured form: bullet wins,
bullet defects + process patterns, team-level learnings,
per-agent learnings, open questions handed forward, Rose
pre-publish audit sign-off.

## 2026-05-14 -- Kaizen point 10: notation-sweep verification regex must actually parse

**Trigger**: Phase 1a Batch B opened after Batch A's "0 hits"
verification scan was reported clean. Re-running the scan with
correct regex syntax found ~24 remaining stragglers across 9 R/
source files + 4 vignettes that the NS-3b, NS-4, NS-5, and
Batch A scans had all silently missed.

**Root cause**: the scan used patterns of the form
`\mathbf{?S}? | \boldsymbol{?S}? | S_phy | S_non | ...` joined
with `|` (alternation). In ripgrep's default Rust regex engine:

- `\m` is an undefined escape and may fail to parse (the
  pattern silently matches nothing); the literal backslash
  needs `\\` in the regex.
- `{?` and `}?` may be parsed as quantifiers rather than
  optional braces.
- Unescaped `|` in bash splits the shell command at the pipe.

The combination meant the scan returned 0 hits not because no
stragglers existed but because the regex either failed silently
or matched the empty string. The maintainer's "let me know if
all S turned into psi" verification was therefore answered with
high-confidence-but-wrong "0 hits across the surface."

**Stragglers caught on rerun**:

- `\mathbf S_\text{phy|non|tier|level}` matrix-S forms: 14
  hits across `R/extract-omega.R`, `R/extract-sigma.R`,
  `R/extract-two-U-cross-check.R`, `R/extract-two-U-via-PIC.R`,
  `R/brms-sugar.R`, `R/gllvmTMB.R`,
  `vignettes/articles/covariance-correlation.Rmd`.
- ASCII `Lambda Lambda^T + S` / `diag(S)` forms in roxygen and
  code comments: 8 hits across `R/extract-two-U-cross-check.R`,
  `R/extract-two-U-via-PIC.R`, `R/extractors.R`,
  `R/fit-multi.R`, `R/extract-sigma.R`, `R/unique-keyword.R`.
- LaTeX `+ S_{\text{phy|non|unit|...}}` in articles: 8 hits
  across `vignettes/articles/choose-your-model.Rmd`,
  `vignettes/articles/pitfalls.Rmd`,
  `vignettes/articles/phylogenetic-gllvm.Rmd`.
- Capital `\Psi_t` (scalar, should be lowercase `\psi_t`): 3
  hits in `R/extract-omega.R`.
- Bare `\Psi` (should be `\psi^2` for partition or
  `\boldsymbol{\Psi}` for matrix): 2 hits in
  `R/extract-omega.R` and `vignettes/articles/pitfalls.Rmd`.

**Lesson**: notation-sweep verification scans must use
parse-tested regex. Specifically:

1. Use **double-escaped backslashes** in ripgrep patterns:
   `\\mathbf`, not `\mathbf`. The latter may match nothing.
2. Use **single-quoted strings** in bash to prevent shell
   expansion of `\` and unescaped `|`.
3. Test the regex against a **known-positive fixture** before
   trusting a 0-hit result. E.g. before scanning the package,
   confirm the pattern matches a deliberately-planted
   `\mathbf S` in a scratch file.
4. **Run multiple complementary patterns**, not a single
   alternation. Separate calls for `\\mathbf\s*\{?\s*S`,
   `\+\s*S_\{`, `\bS_\\text\{`, `diag\([Ss]\)`, `\\Psi(?![a-zA-Z_])`
   each catch a different family of stragglers; the union
   covers the surface.
5. **Spot-check the rendered output** as a sanity floor: run
   `Rscript -e 'devtools::document()'` then `tail -20
   man/<key>.Rd` and confirm the math reads `\boldsymbol\Psi`
   not `\mathbf S`. Rendered-Rd inspection is the ground truth
   the maintainer will see on pkgdown.

**Process change adopted**: every future notation-sweep PR
must include a "verification scan" section in the after-task
report listing the **actual regex commands** used (not just
"0 hits found"). The maintainer can re-run them. If the
regexes don't parse cleanly, the scan is treated as
non-verifying and a second pass is required.

**Worked example**: Batch B (this PR) re-ran the scan with
parse-tested patterns and caught the 24+ stragglers above.
After-task report records each pattern verbatim.


## 2026-05-15 -- Kaizen point 11: R CMD check --as-cran banned cross-reference patterns

**Lesson learned (three separate PR failures today)**:
R CMD check `--as-cran` with `error_on = "warning"` rejects
missing-Rd-link warnings as build failures. Several roxygen
patterns silently break with this configuration:

| Banned pattern | Why | Fix |
|---|---|---|
| `[fn(args)]` -- autolink with function arguments | R CMD check can't resolve a `[fn(args)]` target | Use bare `[fn()]` or canonical S3 form `[fn.class()]` |
| `[vignette("...", package = "...")]` | `vignette(...)` is not an autolinkable Rd target | Plain markdown URL to the rendered pkgdown article |
| `` `vignette("...")` `` (backtick form) | Even in backticks, R CMD check sometimes parses it as a link target | Same: plain markdown URL |
| `[0, 1]` -- interval bounds in prose | Parsed as `[link target]` | Rewrite as prose "between 0 and 1" |
| Cross-references to functions on sibling-branch PRs | Target Rd doesn't exist in main yet | Merge the prerequisite PR first OR drop the cross-link until both are in main OR use a plain markdown URL |

**Worked examples from today** (all 2026-05-15):

- PR #105 (`check_identifiability`) cross-referenced
  `check_auto_residual()` which was on PR #104 -- failed 3-OS
  on the missing-link warning until #104 merged.
- PR #120 (`confint_inspect`) used
  `[confint(fit, method = "profile")]` and
  `[vignette("troubleshooting-profile", package = "gllvmTMB")]`
  in roxygen `@seealso`. Both flagged. Fix replaced the first
  with `[confint.gllvmTMB_multi()]` + an inline arg note, and
  the second with a plain markdown URL to the rendered article.
- PR #122 (`coverage_study`) had `[0, 1]` in a prose description
  of a coverage rate. Replaced with "between 0 and 1".

**Detection recipe**: before pushing any new R/ file with a
`@seealso` block or descriptive math (intervals, function-call
references), run:

```r
tools::checkRd(file.path("man", "<new_function>.Rd"))
```

Empty return = clean. Any "Missing link(s)" output is a CI
blocker under `error_on = "warning"`.

**Process change adopted**: this banned-pattern catalogue is
the new go-to reference for any PR that touches roxygen
`@seealso` blocks. The detection recipe above is the canonical
local-check step before pushing.

## 2026-05-16 -- Phase 0A infrastructure prep + the autopilot-overpromise Kaizen lesson

Scope:

- 14 commits on `agent/phase0-infrastructure-prep` produced 8
  design docs (1 refresh + 7 new), AGENTS.md with new Rule #10
  (Convention-Change Cascade), `10-after-task-protocol.md`
  with 3-rule tests contract + 10-section template, README
  Stable-core feature matrix refresh, 2 skill upgrades + 1
  new skill (`stop-checkpoint`), and Option A / Option C
  ratifications.
- ~50 files touched, ~2,800 net lines added. Zero R/ source
  touched.

Evidence:

- drmTMB-parity gap: 38 design docs / 321 after-task reports
  / 16 R/ files (drmTMB) vs 6 design docs / 86 after-task
  reports / 47 R/ files (gllvmTMB pre-Phase-0A). drmTMB writes
  more about what they're doing than they write code.
- 2026-05-15 article-port crisis: `/loop` autopilot shipped
  articles describing aspirational capabilities past Pat +
  Rose review.
- 2026-05-16 Phase 0A session itself: the agent shipped
  Steps 5 / 6 / 7 commits in sequence WITHOUT surfacing for
  maintainer review between artefacts. The maintainer caught
  it ("I do want to check all these different documents you're
  writing as we have been doing so far"). The `stop-checkpoint`
  skill is the operational fix.

Kaizen points (appended to the rolling catalogue):

10. **Autopilot is the failure mode the validation-debt
    register exists to prevent.** When momentum builds — a
    streak of clean commits, an obvious next step, an
    apparently mechanical batch — the discipline correction is
    to slow down and surface for review before each artefact,
    not to chain through. Two-layer fix:
    - **operational** (`stop-checkpoint` skill): artefact →
      checkpoint → action, never artefact → action directly;
    - **structural** (validation-debt register +
      scope-boundary template): every advertised claim maps
      to a register row with status evidence; no "stable"
      claim is allowed without a `covered` row backing it.

11. **Convention changes cascade through help files.** Option A
    uniform-naming was ratified in `01-formula-grammar.md` but
    did NOT propagate to the README Tiny example until the
    maintainer caught it mid-Phase-0A. The deeper lesson:
    every R function is bound to its help file (roxygen →
    `man/*.Rd`); convention changes propagate to roxygen
    `@examples`, vignette / article code chunks, README, NEWS,
    design-doc examples, and validation-debt register rows in
    the same PR. Codified as AGENTS.md Design Rule #10.
    Follow-up PR(s) apply the cascade to all 26 R/ `@examples`
    blocks, 20 vignettes/articles, and NEWS code chunks.

12. **The skill that catches stale wording can itself have
    stale wording.** `rose-pre-publish-audit/SKILL.md` was
    enforcing "math uses S / s" (from 2026-05-12) even though
    `decisions.md` 2026-05-14 reversed the convention to
    Ψ / ψ. Similar: `gllvmTMB_wide()` described as
    "soft-deprecated" when it was actually REMOVED in 0.2.0;
    rg patterns named `meta_known_V` as primary after `meta_V`
    had become canonical. Step 11's skill upgrade fixed these
    self-references. The deeper Kaizen: every skill is itself
    subject to the convention-cascade rule.

Process changes adopted:

- AGENTS.md Design Rule #10 (Convention-Change Cascade) — new.
- `10-after-task-protocol.md` Convention-Change Cascade
  section — new operational checklist.
- `stop-checkpoint` skill — new; Shannon authors, Ada invokes.
- Validation-debt register row-ID cross-check in every
  after-task report and Rose pre-publish audit.

## 2026-05-18 -- drmTMB-parity hygiene: stale source-of-truth correction

Scope:

- Branch `codex/drmtmb-parity-hygiene` updated the live coordination
  board, added `docs/dev-log/team-improvements.md`, and repaired
  high-risk contradictions across AGENTS / CLAUDE / CONTRIBUTING /
  README / NEWS / DESCRIPTION / pkgdown labels / design docs /
  known-limitations / skills / roxygen / generated Rd.
- No likelihood, engine, test, article-rewrite, or PR #181 / #182
  review work was done in this lane.

Evidence:

- Open PR census before edits: #181 (`agent/sparse-pedigree-ainv-engine`)
  and #182 (`agent/m3-4-warmstart-phi-clamp`) were both open and
  green / held for Codex review.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` completed
  cleanly.
- `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-traits-keyword.R")'`
  completed with 41 pass, 2 skip, 0 fail.
- `Rscript --vanilla -e 'devtools::test(filter = "brms-sugar", reporter = "summary")'`
  completed successfully. A first naked `test_file()` attempt on
  `test-brms-sugar.R` failed because package helpers were not loaded;
  the `devtools::test()` rerun is the meaningful check.
- `git diff --check` completed cleanly.
- Stale-wording scan used verbatim:
  `rg -n '3 x 5|3 × 5|removed in 0\\.2\\.0|REMOVED in 0\\.2\\.0|compound-symmetric \`indep|Compound-symmetric \`indep|indep.*compound-symmetric|off-diagonals equal|single trait-by-trait correlation|meta_known_V\\(V|reserved for \`meta_known_V|gllvmTMB_wide\\(Y, \\.\\.\\.\\) was removed' AGENTS.md CLAUDE.md CONTRIBUTING.md DESCRIPTION README.md NEWS.md _pkgdown.yml docs/design docs/dev-log/known-limitations.md .agents/skills R man`
  Remaining hits were expected: NEWS's historical "3 x 5 to 4 x 5"
  wording and a `R/gllvmTMB.R` no-covstruct fallback comment, not the
  legacy matrix wrapper.

Kaizen points:

13. **Append-only process logs can preserve wrong corrections.** The
    2026-05-16 check-log point 12 said `gllvmTMB_wide()` was "actually
    REMOVED in 0.2.0". Current code exports it and the maintainer asked
    Claude to deprecate it, so the correct current contract is:
    `gllvmTMB_wide(Y, ...)` is **soft-deprecated**, new examples use
    `gllvmTMB(traits(...) ~ ..., data = df_wide)`, and removal is a
    later API-change decision while the export remains live. Future
    agents should treat this 2026-05-18 entry as the superseding rule.

14. **A source-of-truth cascade must include Roxygen and skill files.**
    The stale claims were not limited to README or design docs:
    project-local skills, `DESCRIPTION`, top-level `gllvmTMB()`
    roxygen, `traits()` help, and generated Rd pages also encoded old
    contracts. Rose's pre-publish gate should audit the tools that do
    the auditing.

15. **Equivalence tests outrank intuitive keyword names.** Several
    docs described `indep()` as compound-symmetric, but current code
    and `test-canonical-keywords.R` assert standalone `indep()` is
    byte-equivalent to standalone `unique()` (marginal / diagonal).
    The documentation contract now follows the tested implementation:
    `indep()` is the explicit marginal-only diagonal path.

16. **drmTMB's success pattern is a closed loop, not a larger
    context dump.** The follow-up local `drmTMB` audit found the same
    loop repeated across recent slices: small PR, explicit scope wall,
    targeted checks, after-task report, check-log entry, and a visible
    next surface. The reusable lesson for `gllvmTMB` is to keep PRs
    smaller and make the README / pkgdown entrance task-shaped
    ("start here", supported surfaces, worked guides, concepts /
    reference), while keeping validation-debt status visible before
    broad claims reach Tier-1 articles.

Post-merge sync:

- Maintainer then asked Codex to review and merge Claude's held
  engine PRs first. Codex reviewed #181 and #182, simulated the
  combined #181 -> #182 tree, ran targeted tests with
  `NOT_CRAN=true` + `devtools::load_all(".")`, and merged #181 then
  #182 to `main`.
- This branch then merged `origin/main` cleanly and updated
  `docs/dev-log/coordination-board.md`, this after-task report, and
  `docs/dev-log/team-improvements.md` so #184 no longer preserves
  stale "held PR" wording.
- Post-sync local verification passed for sparse-Ainv engine (8/8),
  M3.4 warm-start / phi-clamp (14/14), traits keyword (44 pass,
  1 expected skip), and `brms-sugar`.

## 2026-05-18 -- Red-main M3.4 smoke-test hygiene

Scope:

- Branch `codex/red-main-m34-test-hygiene` responds to the
  post-merge `main` R-CMD-check failure after PR #184.
- No package code, likelihood, formula grammar, exported API, roxygen,
  Rd, vignette, article, or validation-debt status changed.

Evidence:

- Failed run: `26057303978`, attempt 1.
- Ubuntu failed in `test-m3-4-warmstart-phi-clamp.R:113` because the
  tiny nbinom2 warm-start smoke fixture returned optimizer convergence
  code `1` once.
- Windows failed before R setup at `setup-pandoc`, consistent with an
  infrastructure/setup failure rather than package test evidence.
- Local targeted check before edits:
  `Rscript --vanilla -e 'devtools::test(filter = "m3-4-warmstart-phi-clamp")'`
  passed with 14 pass, 0 fail, 0 warn.
- Local targeted check before edits:
  `Rscript --vanilla -e 'devtools::test(filter = "wide-weights-matrix")'`
  passed with 25 pass, 0 fail, 7 expected-warning leaks from
  deliberate `gllvmTMB_wide()` legacy-wrapper calls.

Kaizen point:

17. **Smoke tests should pin smoke-test contracts, not production-grid
    claims.** The M3.4 nbinom2 warm-start smoke test should assert
    finite, clamped, non-default phi seeds. Convergence-rate,
    coverage, and power claims belong in replicated simulation
    artifacts, not in a single CRAN-time optimizer draw.

## 2026-05-18 -- Slice 1 PR slice contract

Scope:

- Branch `codex/pr-slice-contract` adds the first small
  drmTMB-inspired discipline surface: a GitHub PR template plus a
  short CONTRIBUTING pointer.
- No package code, likelihood, formula grammar, family, vignette,
  article, pkgdown navigation, generated Rd, or validation-debt status
  was changed.

Evidence:

- #184 was allowed to finish 3-OS R-CMD-check and merge before this
  branch started.
- Open PR census before edits: zero open PRs.

Kaizen point:

18. **The PR surface is the first discipline gate.** If the team wants
    small slices, fewer contradictions, and better handoffs, every PR
    needs to say its one-sentence goal, intentional file scope, checks
    run, checks not run, role reviewers, and next slice before review.
    This makes "small PR" inspectable instead of aspirational.

## 2026-05-18 -- CI tiered gates

Scope:

- Branch `codex/ci-tiered-gates` adds a conservative classifier to
  `.github/workflows/R-CMD-check.yaml`.
- Known process-only paths fast-pass after checkout/classification;
  all package-affecting, unknown, mixed, manual, and tag-triggered
  runs still execute full R CMD check.
- No package code, likelihood, formula grammar, exported API, roxygen,
  Rd, vignette, article, pkgdown navigation, or validation-debt status
  changed.

Evidence:

- GitHub documentation says workflows skipped by path filtering can
  leave associated checks pending. The workflow therefore keeps the
  same OS-named jobs and fast-passes inside the job instead of using
  `paths-ignore`.
- First PR CI run exposed a macOS portability bug in the classifier:
  `mapfile` is not available in the macOS runner's default Bash. The
  classifier now collects changed files with a Bash 3.2-compatible
  `while IFS= read -r` loop.
- Follow-up PR CI run `26062918120` passed the full 3-OS
  R-CMD-check on ubuntu-latest, macos-latest, and windows-latest.
  Because the PR changed the workflow file, this was the intentional
  full-check path rather than the new process-only fast path.
- Rose's read-only overnight audit found one policy mismatch before
  merge: the workflow fast-pass list included
  `docs/dev-log/team-improvements.md` and
  `docs/dev-log/recovery-checkpoints/*`, but the CONTRIBUTING table
  did not. The table now matches the workflow path list.
- The policy table in `CONTRIBUTING.md` now separates package-
  affecting PRs, docs/prose PRs, process-only PRs, and long
  simulation/power-analysis experiments.

Kaizen point:

19. **Fewer R CMD checks needs a visible replacement gate.** The team
    should not skip expensive checks silently. The replacement is a
    conservative changed-file classifier, a workflow summary naming
    why R CMD was or was not required, and a fallback to full R CMD
    for every unknown or mixed path.

## 2026-05-18 -- pkgdown families reference index

Scope:

- Branch `codex/pkgdown-families-index` fixes the Response families
  section of the pkgdown reference index.
- `_pkgdown.yml` now points at the actual `Families` topic instead of
  `has_keyword("families")`, because the family constructors share
  `@rdname families` and do not carry `@keywords families`.
- No package code, likelihood, formula grammar, family implementation,
  roxygen, Rd, vignette, article, or validation-debt status changed.

Evidence:

- Pre-edit open PR census: zero open PR rows.
- Pre-edit recent-log check inspected local history through PR #188.
- `man/families.Rd` contains the `Families` topic and aliases for the exported family
  constructors (`Beta`, `betabinomial`, `nbinom1`, `nbinom2`,
  `tweedie`, `student`, `delta_*`, and related families), confirming
  `Families` is the topic that pkgdown should list.
- The suggested redundant `trait = "trait"` cleanup from the Shannon
  handoff was not implemented because current Option A evidence says
  long-format examples should pass `trait =` explicitly.
- First `pkgdown::check_pkgdown()` failed on lowercase `families`; the
  corrected capitalized `Families` selector passed.
- `pkgdown::build_reference(lazy = FALSE)` completed, and the rendered
  `pkgdown-site/reference/index.html` Response families section listed
  the family constructors via `families.html` plus `ordinal_probit()`.
- Maintainer clarified during the run that `trait =` is helpful and may
  be needed for long format, but not wide format.

Kaizen point:

20. **Reference-index selectors should target real topics or real
    keywords.** A `has_keyword()` selector can silently hide an
    exported surface when the roxygen source uses `@rdname` aliases
    instead of `@keywords`. For pkgdown navigation bugs, check both
    `_pkgdown.yml` and the generated `man/*.Rd` aliases before editing.

## 2026-05-18 -- Families help topic: document mixed-family usage

Scope:

- Add a short "how to use families with `gllvmTMB()`" paragraph to the
  `Families` help topic, focused on mixed-family fits.
- No changes to likelihoods, formula grammar, family implementations,
  or validation-debt status.

Evidence:

- `R/families.R`: `@details` now documents the mixed-family API: pass
  `family` as a list of `family` objects plus a selector column in
  `data` (default name `"family"`; override with
  `attr(family, "family_var") <- "colname"`). Also records the
  ordering contract: selector levels are mapped in list order and the
  list length must match the number of selector levels.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` regenerated
  `man/families.Rd`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` -> `No problems found.`

Kaizen point:

21. **Document the "glue" API where users look first.** A page listing
    available families is only half the job; it should also explain how
    the family object is consumed by `gllvmTMB()`, especially for
    mixed-family models where the selector-column contract is easy to
    miss.

## 2026-05-19 -- Roadmap refresh after families lanes

Scope:

- Refresh `ROADMAP.md` to reflect the recent reader-facing families
  discoverability work (PR #189) and the mixed-family Families help
  topic documentation (PR #190), plus the process-only lane close
  (PR #191).
- Add a short “next small steps” list to keep the doc-slice queue
  explicit and low-risk.

Evidence:

- Pre-edit lane check: `gh pr list --state open` -> no open PR rows.
- Pre-edit lane check: `git log --all --oneline --since='6 hours ago'`
  confirmed the recent merge order through #190/#191.

Kaizen point:

22. **Keep the roadmap “hot” for reader-path work.** After small
    discoverability fixes merge, record them in `ROADMAP.md` along with
    the next 1–3 low-risk lanes; otherwise the queue drifts into stale
    handoff bullets.

## 2026-05-19 -- In-prep citation discipline

Scope:

- Replace or remove "`in prep` / `in preparation`" citations in
  user-facing roxygen help, README, and a small number of Tier-1
  articles, preferring published anchors already in the repository.
- No likelihoods, formula grammar, tests, or validation-debt status
  changed.

Evidence:

- `rg -n "in prep|in preparation" README.md R vignettes/articles | head -n 200`
  enumerated all in-prep references before editing.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` regenerated
  affected `man/*.Rd` topics.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` passed (`No problems found.`).
- Post-edit `rg` shows no remaining in-prep literature placeholders in
  the touched user-facing surfaces.

Kaizen point:

23. **Prefer published anchors over “in prep” placeholders.** If a
    methods paper is not yet published, cite the package via
    `inst/CITATION` and reserve “in preparation” wording for internal
    dev-log notes, not for public help pages and tutorials.

## 2026-05-19 -- Slice 2 after-task templates

Scope:

- Add copy/paste templates for after-task and after-phase reports.
- Point the after-task protocol at the new template files.
- No package code, likelihood, formula grammar, families, roxygen, Rd,
  vignettes, README, NEWS, workflows, or validation-debt status changed.

Evidence:

- Pre-edit lane check: `gh pr list --state open` -> no open PR rows.
- Pre-edit lane check: `git log --all --oneline --since="6 hours ago"`
  inspected recent merges through PR #194.
- `git diff --check` clean.

Kaizen point:

24. **Make process templates easy to reuse.** A protocol doc is not
    enough; keep a copy/paste `_TEMPLATE.md` in the folder so authors
    can start an after-task/after-phase report without reconstructing
    section headings from memory.

## 2026-05-19 -- M3.3 production grid workflow

Scope:

- Add a manual `workflow_dispatch` GitHub Actions workflow for the
  15-cell M3.3 production grid.
- Add cell filters, output-prefix controls, and `init_strategy`
  forwarding to the dev precompute scripts.
- Update Design 44, the roadmap queue, the coordination board, and the
  after-task report.
- No public R API, likelihood, formula grammar, family, generated Rd,
  vignette, pkgdown navigation, or validation-debt status changed.

Evidence:

- Pre-edit lane check: `gh pr list --state open --limit 20` -> no open
  PR rows.
- Pre-edit lane check: `git log --all --oneline --since="6 hours ago"`
  inspected recent merges through PR #196.
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/m3-production-grid.yaml"); puts "yaml ok"'`
  passed.
- `air format dev/m3-grid.R dev/precompute-m3-grid.R` completed.
- `Rscript --vanilla -e 'parse("dev/m3-grid.R"); parse("dev/precompute-m3-grid.R")'`
  parsed both scripts.
- One-rep Gaussian d=1 driver checks passed with both
  `--init-strategy=default` and `--init-strategy=single_trait_warmup`.
- The warm-start one-rep driver check was rerun after formatting.
- Malformed `--family=bogus` check failed loudly as expected.
- `Rscript --vanilla -e 'devtools::test(filter = "m3-4-warmstart-phi-clamp")'`
  passed (16 tests).
- `git diff --check` clean.

Kaizen point:

25. **Separate dispatch wiring from evidence claims.** Production
    compute infrastructure can land before the R = 200 artifacts, but
    coverage rows, roadmap progress, and article claims should move only
    after the artifacts are reviewed.

## 2026-05-19 -- M3.3 production artifact review

Scope:

- Dispatch and review the R = 200 M3.3 production grid artifacts from
  the manual Actions workflow.
- Patch `m3_summarise()` so future summaries count failed replicate
  fits before filtering to converged coverage rows.
- File the artifact audit and keep CI-08 / CI-10 in `partial` status
  because the statistical gate failed.
- Update Design 42 / Design 44, ROADMAP, validation-debt register, and
  coordination board to match the evidence.
- No public R API, likelihood, formula grammar, family, roxygen, Rd,
  vignette, README, NEWS, or pkgdown navigation changed.

Evidence:

- Pre-edit lane check: `gh pr list --state open --limit 20` -> no open
  PR rows.
- Pre-edit lane check: `git log --all --oneline --since="6 hours ago"`
  inspected recent merges through PR #198.
- `gh workflow run m3-production-grid.yaml --ref main -f n_reps=200 -f init_strategy=single_trait_warmup -f retention_days=14`
  dispatched run 26100827665.
- `gh run watch 26100827665 --exit-status --interval 60` -> success;
  15/15 matrix jobs completed and uploaded artifacts.
- `gh run download 26100827665 --dir /tmp/gllvmtmb-m3-artifacts-26100827665`
  downloaded 15 artifact directories, each with grid + summary RDS.
- Artifact aggregation from full grid RDS files found only 2/15 cells
  passing the 94 % profile-psi gate and 236/3000 failed replicate
  fits; see `docs/dev-log/audits/2026-05-19-m3-production-grid-artifact-review.md`.
- `air format dev/m3-grid.R tests/testthat/test-m3-grid-summary.R`
  completed.
- `Rscript --vanilla -e 'parse("dev/m3-grid.R"); parse("tests/testthat/test-m3-grid-summary.R")'`
  parsed both files.
- `Rscript --vanilla -e 'devtools::test(filter = "m3-grid-summary")'`
  passed (10 tests).
- PR #199 initial `gh run watch 26106481687 --exit-status --interval 60`
  failed on ubuntu-latest, macos-latest, and windows-latest because
  `tests/testthat/test-m3-grid-summary.R` sourced `../../dev/m3-grid.R`
  during `R CMD check`, but `dev/` is deliberately excluded by
  `.Rbuildignore`.
- `air format tests/testthat/test-m3-grid-summary.R` completed after the
  test harness was changed to find `dev/m3-grid.R` through the GitHub
  Actions checkout when `GITHUB_WORKSPACE` is set and to skip explicitly
  when no development checkout is available.
- `Rscript --vanilla -e 'devtools::test(filter = "m3-grid-summary")'`
  passed again locally (10 tests).
- Temporary no-`dev/` test-harness emulation using `testthat::test_file()`
  skipped the two M3-grid-summary tests cleanly when `GITHUB_WORKSPACE`
  was unset and passed all 10 checks when `GITHUB_WORKSPACE` pointed to
  the repository checkout.
- `git diff --check` clean.

Kaizen point:

26. **Count failures before filtering to coverage rows.** Coverage
    summaries must keep failed-refit denominators visible. If a summary
    helper filters out `NA` coverage rows first, it can make every cell
    look like `n_failed = 0` even when the full grid records failed
    replicate fits.

## 2026-05-19 -- ROADMAP post-M3 evidence refresh

Scope:

- Refresh `ROADMAP.md` after PR #199 merged and the M3.3 production
  artifact review established that the compute workflow passed but the
  statistical coverage gate failed.
- Sync the detailed M3 heading with the phase-at-a-glance row.
- Replace verified stale roadmap wording for merged PRs #120, #122,
  #125, and #170.
- Update the coordination board and add an after-task report for this
  bounded documentation/process lane.
- No public R API, likelihood, formula grammar, response family,
  roxygen, Rd, vignette, README, NEWS, pkgdown navigation,
  validation-debt status, or test expectation changed.

Evidence:

- `gh pr view 199 --repo itchyshin/gllvmTMB --json number,state,mergedAt,mergeCommit,url`
  -> PR #199 merged at `2026-05-19T17:42:48Z` as merge commit
  `6a1e5d5f5f26545d7d2a1d23194e27cf70ef2ce8`.
- `git switch main` -> switched from the PR #199 branch to `main`.
- `git pull --ff-only` -> fast-forwarded `main` from `020e305` to
  `6a1e5d5`.
- Pre-edit lane check: `gh pr list --state open --limit 20` -> no open
  PR rows.
- Pre-edit lane check: `git log --all --oneline --since="6 hours ago"`
  inspected recent merges through PR #199.
- `gh pr view 170 --repo itchyshin/gllvmTMB --json number,title,state,mergedAt,url`
  -> PR #170 merged at `2026-05-18T01:09:12Z`.
- `gh pr view 120 --repo itchyshin/gllvmTMB --json number,title,state,mergedAt,url`
  -> PR #120 merged at `2026-05-15T19:45:43Z`.
- `gh pr view 122 --repo itchyshin/gllvmTMB --json number,title,state,mergedAt,url`
  -> PR #122 merged at `2026-05-15T20:28:41Z`.
- `gh pr view 125 --repo itchyshin/gllvmTMB --json number,title,state,mergedAt,url`
  -> PR #125 merged at `2026-05-15T20:35:38Z`.
- ``rg -n 'PR #170, in flight|2/3 in main; 1 in flight|cross-reference fix in flight|PR #122.*held|simulation-verification\\.Rmd.*LOCAL DRAFT|### ⚪ M3 -- Inference completeness across families -- `░░░░░░░░` 0/8' ROADMAP.md``
  -> no remaining stale roadmap status hits.
- `rg -n "PR #197|PR #198|PR #199|M3\\.3 production|26100827665|2/15|CI-08|CI-10|failure-mode triage" ROADMAP.md docs/dev-log/coordination-board.md`
  -> expected current-status hits only.
- `git diff --check` -> clean.

Kaizen point:

27. **Sweep the detailed section after each roadmap tick.** When a
    phase-at-a-glance row changes, check the matching detailed heading,
    milestone bullets, and adjacent "in flight" wording before the
    roadmap lane closes.

## 2026-05-19 -- M3.3 failure-mode ledger

Scope:

- Start M3.3 failure-mode triage from the production run 26100827665
  full grid artifacts.
- Classify undercoverage by miss side, failed-refit rate, family, rank,
  and trait.
- Add a small glmmTMB nbinom2 comparator probe requested by the
  maintainer.
- Check galamm availability and record why it is not a direct nbinom2
  comparator for this slice.
- No public R API, likelihood, formula grammar, response family,
  roxygen, Rd, vignette, README, NEWS, pkgdown navigation,
  validation-debt status, or test expectation changed.

Evidence:

- Pre-edit lane check: `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,mergeStateStatus,updatedAt,url`
  -> no open PRs.
- Pre-edit lane check: `git log --all --oneline --since="6 hours ago"`
  inspected recent M3/roadmap merges through PR #200.
- `git switch -c codex/m3-3-failure-mode-triage-2026-05-19`
  created the triage branch.
- `gh run download 26100827665 --repo itchyshin/gllvmTMB --dir /tmp/gllvmtmb-m3-artifacts-26100827665-triage`
  downloaded all 15 production grid/summary artifact pairs.
- R artifact reconstruction from `*grid.rds` files found all uncovered
  converged rows missed above the profile upper bound; no lower-bound
  misses.
- Cell-level coverage/failure classes were recorded in
  `docs/dev-log/audits/2026-05-19-m3-3-failure-mode-ledger.md`.
- `Rscript --vanilla -e 'cat(as.character(utils::packageVersion("glmmTMB")), "\n")'`
  -> `1.1.13`.
- Small glmmTMB nbinom2 comparator, d = 1, 20 reps x 5 traits:
  99/100 fits converged, 70/100 profile bounds available, 0.914
  coverage among available profile intervals, 0.640 if missing profile
  bounds count as failures.
- `Rscript --vanilla -e 'cat(requireNamespace("galamm", quietly = TRUE), "\n"); if (requireNamespace("galamm", quietly = TRUE)) cat(as.character(utils::packageVersion("galamm")), "\n")'`
  -> `TRUE`, `0.4.0`.
- galamm single-trait binomial random-intercept probe failed with:
  `number of levels of each grouping factor must be < number of observations`.

Kaizen point:

28. **Separate target failure from optimizer failure before rerun.**
    M3.3 should not rerun all 15 cells until Fisher and Gauss decide
    whether the promotion target is `psi`, total `Sigma_unit[tt]`, or
    both. Otherwise a clean rerun could still validate the wrong
    quantity.

## 2026-05-19 -- M3.3 target-scale audit

Scope:

- Re-read the M3.3 production artifacts from run 26100827665 after the
  failure-mode ledger landed.
- Determine whether the next M3.3 run should validate `psi`, total
  `Sigma_unit[tt]`, or both.
- Record the user-suggested galamm comparator lane without treating it
  as an nbinom2 comparator.
- Update Design 42, Design 44, and `dev/m3-grid.R` comments to keep the
  target distinction visible.
- No public R API, likelihood, formula grammar, response family,
  roxygen, Rd, vignette, README, NEWS, pkgdown navigation,
  validation-debt status, or test expectation changed.

Evidence:

- PR #201 merged to `main` at `2026-05-19T19:31:43Z` as merge commit
  `f3dee1e4151d054a518b5443938f3910e6f4c797`.
- `git switch main && git pull --ff-only` fast-forwarded `main` from
  `f0e2dc0` to `f3dee1e`.
- Pre-edit lane check: `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,author,updatedAt`
  -> no open PRs.
- Pre-edit lane check: `git log --all --oneline --since="6 hours ago"`
  inspected recent M3 merges through PR #201.
- `git switch -c codex/m3-3-target-scale-audit-2026-05-19`
  created the Slice 2 branch.
- R artifact reconstruction from the previously downloaded
  `/tmp/gllvmtmb-m3-artifacts-26100827665-triage` grids computed
  target-allocation summaries:
  - binomial median `est_psi / truth_psi` = `1.28e-09`, median
    `est_Sigma_diag / truth_Sigma_diag` = `1.928`;
  - nbinom2 median `est_psi / truth_psi` = `7.29e-07`, median
    `est_Sigma_diag / truth_Sigma_diag` = `2.613`;
  - ordinal-probit median `est_psi / truth_psi` = `5.44e-09`, median
    `est_Sigma_diag / truth_Sigma_diag` = `0.837`;
  - mixed-family median `est_psi / truth_psi` = `1.94e-07`, median
    `est_Sigma_diag / truth_Sigma_diag` = `1.360`;
  - Gaussian median `est_psi / truth_psi` = `0.610`, median
    `est_Sigma_diag / truth_Sigma_diag` = `0.830`.
- `nl -ba docs/design/42-m3-dgp-grid.md`, `nl -ba docs/design/44-m3-3-inference-replacement.md`,
  `nl -ba dev/m3-grid.R`, and the existing
  `tests/testthat/test-m2-3-galamm-cross-check.R` were inspected for
  target and comparator wording.
- The audit is filed at
  `docs/dev-log/audits/2026-05-19-m3-3-target-scale-audit.md`.

Kaizen point:

29. **Name the target in every simulation artifact column.** A generic
    `ci_prof_lo/hi` and `covered_prof` field is too easy to misread once
    the design has both `psi` and total `Sigma_unit[tt]` targets. Future
    grid artifacts should either use a long `target` column or explicit
    names such as `covered_psi_prof` and `covered_sigma_diag_boot`.

## 2026-05-19 -- CI ignored-source fast path

Scope:

- Expand the existing in-job R-CMD-check classifier so PRs touching only
  ignored-source planning/doc files can fast-pass more often.
- Keep full R CMD check for package-facing paths and mixed scopes.
- Add light validation for fast-passed changes: `git diff --check` for
  every fast path and `Rscript parse(file = ...)` for ignored `dev/*.R`
  scripts.
- Update `CONTRIBUTING.md`, the coordination board, and the after-task
  report.

Evidence:

- PR #202 merged to `main` at `2026-05-19T20:13:53Z` as merge commit
  `10bc85988e851f982ca40cba3728f8ad423994f5`.
- Pre-edit lane check: `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,author,updatedAt`
  -> no open PRs.
- Pre-edit lane check: `git log --all --oneline --since="6 hours ago"`
  inspected recent M3 merges through PR #202.
- Official GitHub Actions workflow syntax docs were checked for path
  filter behaviour; skipped required workflows can leave checks pending,
  so this change keeps the in-job classifier rather than adding
  workflow-level `paths-ignore`.
- `.Rbuildignore` confirms `docs`, `dev`, `AGENTS.md`, `CLAUDE.md`,
  `CONTRIBUTING.md`, and `ROADMAP.md` are excluded from package builds.
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/R-CMD-check.yaml"); puts "yaml ok"'`
  -> `yaml ok`.
- Extracted every workflow `run:` block with GitHub expressions replaced
  by `DUMMY`; `bash -n` returned cleanly for each script.
- Local classifier simulation:
  - `docs/design/42-m3-dgp-grid.md`, `docs/dev-log/check-log.md`,
    `ROADMAP.md`, and `AGENTS.md` -> fast path, no R parse.
  - `dev/m3-grid.R` -> fast path plus R parse.
  - `R/fit-multi.R`, `src/gllvmTMB.cpp`, `README.md`, and
    `.github/workflows/R-CMD-check.yaml` -> full R CMD check.
- `Rscript --vanilla -e 'parse(file = "dev/m3-grid.R"); cat("r parse ok\n")'`
  -> `r parse ok`.
- `git diff --check` -> clean.

Kaizen point:

30. **Fast-pass only where R CMD cannot add evidence.** R CMD check
    stays required for package surfaces. Ignored-source PRs should use a
    visible replacement gate instead of paying 30-40 minutes for a check
    that cannot exercise the changed files.

## 2026-05-19 -- M3 roadmap target-explicit refresh

Scope:

- Refresh `ROADMAP.md` after PR #201 and PR #202 so the next M3.3
  slice is a target-explicit pilot, not another generic failure-mode
  triage.
- Align Design 42 / 44 with CI-08 and CI-10 rather than the stale
  `M3-COV` placeholder.
- Align Design 43 / 48 with the implemented M3.4 warmup + phi-clamp
  status: MIS-16 / MIS-17 are covered, while empirical rerun evidence
  and default-policy remain open.
- Keep README and `simulation-recovery-validated.Rmd` for a later
  Pat/Rose reader-facing honesty lane.
- Update the coordination board now that PR #203 has merged and this
  roadmap refresh is Ada's active lane.
- No public R API, likelihood, formula grammar, response family,
  roxygen, Rd, vignette, README, NEWS, pkgdown navigation,
  validation-debt status, or test expectation changed.

Evidence:

- PR #203 merged to `main` at `2026-05-19T21:05:15Z` as merge commit
  `5dd3316d5a3b4f7a1d216986baea9f7d6f48f90f`.
- `git switch main && git pull --ff-only` fast-forwarded the primary
  worktree from `10bc859` to `5dd3316`.
- Roadmap worktree rebase: `git stash push -u -m 'm3-roadmap-target-explicit-refresh-draft' && git rebase origin/main && git stash pop`
  -> rebase succeeded and the stash applied cleanly.
- Pre-edit lane check: `gh pr list --state open --repo itchyshin/gllvmTMB --json number,title,headRefName,files --jq '.[] | {number,title,headRefName,files: [.files[].path]}'`
  -> before PR #203 merged, only PR #203 was open; it did not touch
  `ROADMAP.md` or the Design 42 / 43 / 44 / 48 files.
- Pre-edit lane check: `git log --all --oneline --since='6 hours ago'`
  inspected recent M3 and CI fast-path commits through PR #203.
- Rose read-only audit found stale roadmap/design wording and
  recommended one source-of-truth docs PR before the later README /
  article honesty lane.
- Gauss read-only review recommended bootstrap total
  `Sigma_unit[tt]` rows before derived-profile fix-and-refit and kept
  ADREPORT/delta as a later fast diagnostic.
- Curie read-only review recommended the first pilot cells
  `gaussian-d2`, `nbinom2-d1`, and `mixed-d2`, with
  `ordinal_probit-d1` blocked until ordinal simulation supports family
  ID 14.
- Stale-wording scan:
  `rg -n 'M3-COV|failure-mode triage|precompute-vignettes|follow-on PR per two-PR pattern|Implementation follow-on PR|Easy add, not implemented|No implementation in this PR|proposed M3.4 fix|profile-likelihood specifically|post-CRAN\\. No v0\\.2\\.0' ROADMAP.md docs/design/42-m3-dgp-grid.md docs/design/43-asreml-speed-techniques.md docs/design/44-m3-3-inference-replacement.md docs/design/48-m3-4-boundary-regimes.md`
  -> no hits.
- `git diff --check` -> clean.
- After-task report filed at
  `docs/dev-log/after-task/2026-05-19-m3-roadmap-target-explicit-refresh.md`.
- Coordination board moved PR #203 to recently resolved and listed
  `codex/m3-3-roadmap-refresh-2026-05-19` as the active Ada lane.

Kaizen point:

31. **Refresh source-of-truth docs before reader-facing honesty.** When
    M3 evidence changes the interpretation of a failed run, first align
    ROADMAP and design docs on target, method, and status. Then Pat and
    Rose can update README/articles without inheriting inconsistent
    source language.

## 2026-05-19 -- M3.3 target-explicit pilot implementation

Scope:

- Implement target-explicit M3 grid rows in `dev/m3-grid.R`.
- Keep profile-`psi` rows as the diagnostic target and add
  bootstrap total `Sigma_unit[tt]` rows as the primary pilot target.
- Add `--targets=`, `--n-boot=`, and `--ci-level=` to
  `dev/precompute-m3-grid.R`.
- Add bootstrap refit failure accounting to the summary so
  `COMPUTE_FAIL` can reflect unstable resampling, not only original
  fit failure or missing CIs.
- Fix the M3 driver's grouping call: leave `cluster` at the default
  placeholder instead of passing `cluster = "unit"`, which
  double-registered `unique(0 + trait | unit)` as both `diag_B` and
  `diag_species`.
- No package API, formula grammar, TMB likelihood, roxygen, Rd,
  README, vignette, NEWS, pkgdown navigation, or validation-debt
  status changed.

Evidence:

- Pre-edit lane check:
  `git status --short --branch && gh pr list --state open --repo itchyshin/gllvmTMB --json number,title,headRefName,files --jq '.[] | {number,title,headRefName,files: [.files[].path]}' && git log --all --oneline --since='6 hours ago'`
  -> clean branch point on `main`, no open PRs, recent M3 / CI merges
  inspected.
- `Rscript --vanilla -e 'invisible(parse(file = "dev/m3-grid.R")); invisible(parse(file = "dev/precompute-m3-grid.R")); cat("parse ok\n")'`
  -> `parse ok`.
- `Rscript --vanilla -e 'source("dev/m3-grid.R"); stopifnot(identical(m3_normalise_targets("all"), M3_INTERVAL_TARGETS)); stopifnot(m3_target_method("Sigma_unit_diag") == "bootstrap"); stopifnot(identical(m3_miss_side(1, 0, 2, TRUE, TRUE), "covered")); cat("helpers ok\n")'`
  -> `helpers ok`.
- Summary mock:
  `Rscript --vanilla -e 'source("dev/m3-grid.R"); df <- data.frame(cell="gaussian-d1", family="gaussian", d=1L, rep=c(1L,1L,1L,1L), trait_id=c(1L,2L,1L,2L), converged=TRUE, fit_converged=TRUE, target=rep(c("psi","Sigma_unit_diag"), each=2), ci_method=rep(c("profile","bootstrap"), each=2), truth=c(1,2,3,4), estimate=c(1.1,1.8,2.9,4.2), ci_lo=c(.5,1.5,2.5,3.5), ci_hi=c(1.5,2.5,3.5,4.5), covered=c(TRUE,TRUE,TRUE,TRUE), ci_available=TRUE, runtime_s=1, miss_side="covered", n_boot=c(NA,NA,10,10), n_boot_failed=c(NA,NA,1,1), covered_prof=c(TRUE,TRUE,NA,NA)); print(m3_summarise(df), row.names=FALSE)'`
  -> two target summaries; bootstrap row reported
  `n_boot_failed = 1`, `n_boot_attempted = 10`,
  `boot_fail_rate = 0.1`.
- Legacy summary mock:
  `Rscript --vanilla -e 'source("dev/m3-grid.R"); old <- data.frame(cell="gaussian-d1", family="gaussian", d=1L, rep=c(1L,1L), trait_id=1:2, covered_prof=c(TRUE,FALSE), converged=TRUE, runtime_s=c(1,1)); print(m3_summarise(old), row.names=FALSE)'`
  -> old no-`target` artifacts still summarise with `coverage_prof`
  and `passes_94pct_prof`.
- Before-fix grouping reproducer:
  `Rscript --vanilla -e 'devtools::load_all(".", quiet = TRUE); source("dev/m3-grid.R"); truth <- m3_sample_truth("gaussian", 1, n_traits=2, n_units=25, seed=1); sim <- m3_simulate_response(truth); fit <- gllvmTMB(value ~ 0 + trait + latent(0 + trait | unit, d = 1) + unique(0 + trait | unit), data = sim$data, family = gaussian(), unit="unit", cluster="unit", control=gllvmTMBcontrol(init_strategy="default")); cat("diag_species=", fit$use$diag_species, "\n"); print(gllvmTMB:::.check_simulate_unconditional(fit));'`
  -> explicit `cluster = "unit"` reproduces `diag_species = TRUE` and
  `can_redraw = FALSE`.
- Grouping reproducer:
  `Rscript --vanilla -e 'devtools::load_all(".", quiet = TRUE); source("dev/m3-grid.R"); truth <- m3_sample_truth("gaussian", 1, n_traits=2, n_units=25, seed=1); sim <- m3_simulate_response(truth); fit <- gllvmTMB(value ~ 0 + trait + latent(0 + trait | unit, d = 1) + unique(0 + trait | unit), data = sim$data, family = gaussian(), unit="unit", control=gllvmTMBcontrol(init_strategy="default")); print(fit$use); print(gllvmTMB:::.check_simulate_unconditional(fit));'`
  -> `diag_species = FALSE`, `can_redraw = TRUE`.
- Combined-target smoke:
  `Rscript --vanilla -e 'devtools::load_all(".", quiet = TRUE); source("dev/m3-grid.R"); grid <- m3_run_cell("gaussian", d = 1, n_reps = 1, seed_base = 20260521L, n_units = 25L, n_traits = 2L, targets = c("psi", "Sigma_unit_diag"), n_boot = 2L, ci_level = 0.80, verbose = FALSE); print(m3_summarise(grid), row.names = FALSE)'`
  -> separate `psi/profile` and `Sigma_unit_diag/bootstrap` rows;
  both had zero bootstrap refit failures in that toy run.
- CLI driver smoke:
  `Rscript --vanilla dev/precompute-m3-grid.R --full --family=gaussian --d=1 --n-reps=1 --targets=Sigma_unit_diag --n-boot=2 --ci-level=0.80 --out-dir=/tmp/gllvmtmb-m3-target-pilot-smoke --out-prefix=smoke2`
  -> completed and saved `/tmp/gllvmtmb-m3-target-pilot-smoke/smoke2-grid.rds`
  and `/tmp/gllvmtmb-m3-target-pilot-smoke/smoke2-summary.rds`.
- Tiny `nbinom2-d1` smoke:
  `Rscript --vanilla -e 'devtools::load_all(".", quiet = TRUE); source("dev/m3-grid.R"); grid <- m3_run_cell("nbinom2", d = 1, n_reps = 1, seed_base = 20260522L, n_units = 25L, n_traits = 2L, targets = "Sigma_unit_diag", n_boot = 2L, ci_level = 0.80, verbose = TRUE); print(grid[, c("cell", "target", "ci_method", "trait_id", "fit_converged", "ci_available", "n_boot_failed", "miss_side", "runtime_s")], row.names = FALSE); print(m3_summarise(grid), row.names = FALSE)'`
  -> original fit converged; one of two bootstrap refits failed; summary
  labelled the toy cell `COMPUTE_FAIL`.
- Stale-target scan:
  `rg -n 'profile-psi primary|profile.*primary target|M3-COV' ROADMAP.md docs/design/42-m3-dgp-grid.md docs/design/44-m3-3-inference-replacement.md dev/m3-grid.R dev/precompute-m3-grid.R`
  -> no hits.
- Grouping guard scan:
  `rg -n 'cluster\s*=\s*"unit"' dev/m3-grid.R docs/design/42-m3-dgp-grid.md docs/design/44-m3-3-inference-replacement.md`
  -> hits only the intentional implementation/design guard text; no
  active `gllvmTMB(..., cluster = "unit")` call remains in
  `dev/m3-grid.R`.
- Bootstrap-summary scan:
  `rg -n 'n_boot_failed|boot_fail_rate|n_boot_attempted' dev/m3-grid.R dev/precompute-m3-grid.R docs/design/42-m3-dgp-grid.md docs/design/44-m3-3-inference-replacement.md`
  -> Design 44 and implementation agree on the bootstrap-failure
  columns.
- `git diff --check` -> clean.
- After-task report filed at
  `docs/dev-log/after-task/2026-05-19-m3-3-target-explicit-pilot.md`.

Kaizen point:

32. **Warnings can reveal target invalidity, not just log noise.** The
    first bootstrap smoke warned that unconditional simulation fell back
    to conditional simulation. Tracing that warning found an unintended
    `diag_species` tier from `cluster = "unit"`. For simulation evidence
    lanes, treat unexpected warnings as part of the model contract until
    the target, grouping, and simulation path are confirmed.

## 2026-05-19 -- Robust modeling starts, fit-health diagnostics, and roadmap scaffold

Scope:

- Implement the first code-bearing slice of Design 49:
  start provenance, restart history, protected/skipped `sdreport()`
  status, `gllvmTMBcontrol(se = FALSE)`, `fit_health`, and
  `check_gllvmTMB()`.
- Keep residual starts, simpler-model starts, and optimizer fallback as
  opt-in tools; do not claim default-policy promotion until M3.3a/M3.4
  simulation evidence exists.
- Update the validation-debt register, roadmap, NEWS, pkgdown reference
  navigation, and the robust-modeling design note so user-facing claims
  distinguish implemented, partial, and evidence-pending behavior.

Evidence:

- Pre-edit recovery checkpoint:
  `docs/dev-log/recovery-checkpoints/2026-05-19-173400-codex-checkpoint.md`
  recorded branch, `git status --short --branch`, `git diff --stat`,
  `gh pr list --state open --limit 20`, recent `git log --all --oneline --since="6 hours ago"`,
  newest check-log entry, and newest recovery checkpoint.
- `git status --short --branch`
  -> branch `codex/rr-residual-starts-2026-05-19` with expected
  start/diagnostic code, docs, generated Rd, and test files modified.
- `gh pr list --state open --limit 20`
  -> no open PR rows printed.
- `git log --all --oneline --since="6 hours ago"`
  -> recent M3 / CI merges inspected, including PRs #199 through #205.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> regenerated `NAMESPACE`, `man/gllvmTMBcontrol.Rd`, and
  `man/check_gllvmTMB.Rd`.
- `Rscript --vanilla -e 'invisible(parse(file="R/fit-multi.R")); invisible(parse(file="R/diagnose.R")); invisible(parse(file="R/methods-gllvmTMB.R")); cat("parse ok\n")'`
  -> `parse ok`.
- `Rscript --vanilla -e 'devtools::load_all(".", quiet = TRUE); cat("load_all ok\n")'`
  -> `load_all ok`.
- `Rscript --vanilla -e 'devtools::test(filter = "sanity-multi")'`
  -> 14 passed, 0 failed, 0 warnings, 0 skipped.
- `Rscript --vanilla -e 'devtools::test(filter = "stage39-multi-start")'`
  -> 15 passed, 0 failed, 0 warnings, 0 skipped.
- `Rscript --vanilla -e 'devtools::test(filter = "gllvmTMB-diagnose")'`
  -> 10 passed, 0 failed, 0 warnings, 0 skipped after replacing
  deprecated `"B"` / `"W"` communality aliases with `"unit"` /
  `"unit_obs"` in `gllvmTMB_diagnose()`.
- `Rscript --vanilla -e 'devtools::test(filter = "gllvmTMBcontrol|start-method-residual|multi-start-sdreport-consistency")'`
  -> 60 passed, 0 failed, 0 warnings, 0 skipped.
- `Rscript --vanilla -e 'devtools::test()'`
  -> 0 failed, 19 warnings, 14 skipped, 1875 passed; duration 1669.3 s.
  Slow points included `phylo-q-decomposition` (666.9 s) and
  `profile-ci` (352.1 s).
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> rerun after adding `gllvmTMBcontrol(se = FALSE)`; regenerated
  `man/gllvmTMBcontrol.Rd`.
- `Rscript --vanilla -e 'devtools::test(filter = "gllvmTMBcontrol|sanity-multi")'`
  -> 54 passed, 0 failed, 0 warnings, 0 skipped.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean.

Consistency and stale-wording scans:

- `rg "\bS_B\b|\bS_W\b|\\bf S" .`
  -> hits only historical/dev-log/check-log/protocol/audit notes; no
  new touched public files reintroduced legacy S notation.
- `rg -n "gllvmTMB\(" R vignettes README.md NEWS.md docs/design`
  -> manually checked this lane's new `R/diagnose.R` example has
  `trait = "trait"` and `unit = "site"`; new Design 48 snippets are
  schematic design prose, not runnable long-format examples.
- `rg "in prep|in preparation" docs vignettes`
  -> hits only existing historical/internal records; no new
  robust-modeling docs introduced foundational in-prep claims.
- `rg "\bphylo\(|\bgr\(|\bmeta\(|block_V\(|phylo_rr\(" vignettes`
  -> no hits.
- `rg "meta_known_V" README.md NEWS.md docs vignettes`
  -> existing intended alias/deprecation/history hits only; no new
  robust-modeling docs present `meta_known_V` as primary syntax.
- `rg "gllvmTMB_wide" README.md NEWS.md docs vignettes`
  -> existing soft-deprecation/history hits only; no new
  robust-modeling docs present `gllvmTMB_wide()` as primary syntax or
  claim removal while exported.

Kaizen point:

33. **Record fit health as data, not prose.** Robust-modeling work
    should make convergence state, `pdHess`, `sdreport()` status,
    starts, optimizer choice, and selected restarts table-shaped early.
    That keeps simulations, diagnostics, articles, and reviewer audits
    from parsing human messages and makes failures visible without
    pretending every warning invalidates the whole fitted model.

34. **Hard fits need a no-SE path plus bootstrap.** Some difficult
    multivariate latent models can have useful point estimates while
    `pdHess = FALSE` or Hessian-based SEs fail. Mirror the drmTMB
    workflow: allow intentional SE skipping (`gllvmTMBcontrol(se =
    FALSE)`), report degraded inference honestly, and route uncertainty
    to bootstrap/profile workflows, ideally with multicore support.

## 2026-05-19 -- M3.3a fit-health pilot schema

Scope:

- Start dependent Branch B from PR #206 so M3.3a pilot artifacts can
  use `fit_health`, `restart_history`, `start_provenance`, `pdHess`,
  `sdreport` status, and `gllvmTMBcontrol(se = FALSE)`.
- Extend `dev/m3-grid.R` and `dev/precompute-m3-grid.R` with
  start-method, optimizer, restart, skipped-SE, and bootstrap-core
  metadata.
- Keep this as a schema and tiny-smoke slice, not a production coverage
  claim.

Evidence:

- PR #206 CI: R-CMD-check passed on ubuntu-latest, macos-latest, and
  windows-latest for run 26134392947; PR marked ready for review.
- Branch switch:
  `git switch -c codex/m3-3a-fit-health-pilot-2026-05-19`
  -> new dependent branch created from PR #206 head.
- `Rscript --vanilla -e 'invisible(parse(file="dev/m3-grid.R")); invisible(parse(file="dev/precompute-m3-grid.R")); cat("parse ok\n")'`
  -> `parse ok`.
- Summary mock with new diagnostic columns:
  `Rscript --vanilla -e 'source("dev/m3-grid.R"); df <- data.frame(cell="gaussian-d1", family="gaussian", d=1L, rep=c(1L,1L), trait_id=1:2, converged=TRUE, fit_converged=TRUE, target="Sigma_unit_diag", ci_method="bootstrap", truth=c(1,2), estimate=c(1.1,1.9), ci_lo=c(.8,1.6), ci_hi=c(1.3,2.3), covered=TRUE, ci_available=TRUE, runtime_s=1, miss_side="covered", n_boot=10L, n_boot_failed=1L, init_strategy="default", start_method="res", start_method_jitter_sd=.2, optimizer="nlminb", n_init=5L, init_jitter=.3, se=FALSE, fit_error=NA_character_, fit_convergence_code=0L, fit_message="", fit_objective=10, max_gradient=.001, pd_hessian=FALSE, sdreport_ok=FALSE, sdreport_error="skipped", selected_restart=2L, restart_count=5L, objective_spread=.5, boundary_flags=""); print(m3_summarise(df), row.names=FALSE)'`
  -> summary included `pd_hessian_rate`, `sdreport_ok_rate`,
  `median_max_gradient`, `median_restart_count`, and
  `median_objective_spread`.
- Driver smoke:
  `Rscript --vanilla dev/precompute-m3-grid.R --full --family=gaussian --d=1 --n-reps=1 --start-method=res --start-jitter=0.1 --n-init=2 --init-jitter=0.05 --se=false --targets=Sigma_unit_diag --n-boot=2 --n-cores-boot=1 --ci-level=0.80 --out-dir=/tmp/gllvmtmb-m3-3a-fit-health-smoke --out-prefix=gaussian-res-sefalse2`
  -> completed; artifact grid contains start method `res`, `n_init =
  2`, `se = FALSE`, `sdreport_ok = FALSE`, restart count 2, and
  `n_cores_boot = 1`.
- Tiny `nbinom2` smoke with same settings:
  `Rscript --vanilla dev/precompute-m3-grid.R --full --family=nbinom2 --d=1 --n-reps=1 --start-method=res --start-jitter=0.1 --n-init=2 --init-jitter=0.05 --se=false --targets=Sigma_unit_diag --n-boot=2 --n-cores-boot=1 --ci-level=0.80 --out-dir=/tmp/gllvmtmb-m3-3a-fit-health-smoke --out-prefix=nbinom2-res-sefalse`
  -> fit completed, bootstrap refits completed, summary `TARGET_FAIL`
  in the one-rep toy run; median estimate/truth ratio was above 2,
  suggesting `nbinom2` still needs a real stress lane.
- Tiny mixed-family smoke with same settings:
  `Rscript --vanilla dev/precompute-m3-grid.R --full --family=mixed --d=1 --n-reps=1 --start-method=res --start-jitter=0.1 --n-init=2 --init-jitter=0.05 --se=false --targets=Sigma_unit_diag --n-boot=2 --n-cores-boot=1 --ci-level=0.80 --out-dir=/tmp/gllvmtmb-m3-3a-fit-health-smoke --out-prefix=mixed-res-sefalse`
  -> fit completed, bootstrap refits completed, summary `TARGET_FAIL`
  in the one-rep toy run.
- Multicore bootstrap smoke:
  `Rscript --vanilla dev/precompute-m3-grid.R --full --family=gaussian --d=1 --n-reps=1 --start-method=res --start-jitter=0.1 --n-init=2 --init-jitter=0.05 --se=false --targets=Sigma_unit_diag --n-boot=2 --n-cores-boot=2 --ci-level=0.80 --out-dir=/tmp/gllvmtmb-m3-3a-fit-health-smoke --out-prefix=gaussian-res-sefalse-cores2`
  -> completed; artifact recorded `n_cores_boot = 2`.
- Two-level Gaussian smoke outside the unit-tier M3 grid:
  `Rscript --vanilla -e 'devtools::load_all(".", quiet=TRUE); set.seed(9201); sim <- simulate_site_trait(n_sites=18, n_species=6, n_traits=3, mean_species_per_site=4, Lambda_B=matrix(c(.7,.4,-.2),3,1), Lambda_W=matrix(c(.5,-.3,.2),3,1), psi_B=c(.3,.3,.3), psi_W=c(.2,.2,.2), seed=9201); fit <- gllvmTMB(value ~ 0 + trait + latent(0 + trait | site, d=1) + unique(0 + trait | site) + latent(0 + trait | site_species, d=1) + unique(0 + trait | site_species), data=sim$data, control=gllvmTMBcontrol(start_method=list(method="indep"), n_init=2, init_jitter=.05, se=FALSE)); print(check_gllvmTMB(fit), row.names=FALSE); print(fit$restart_history[, c("restart", "start_method", "objective", "convergence", "selected")], row.names=FALSE); cat("sdreport_ok=", fit$fit_health$sdreport_ok, " selected_restart=", fit$fit_health$selected_restart, "\n")'`
  -> optimizer converged, max gradient passed, `sdreport` warned
  because `se = FALSE`, selected restart 2, and boundary flags exposed
  near-zero unit-tier SD.

Kaizen point:

35. **Pilot artifacts need diagnostic metadata before bigger grids.**
    M3.3a should not only say whether coverage passed. Each row should
    carry the start strategy, optimizer, restart count, selected
    restart, objective spread, gradient, `pdHess`, `sdreport` status,
    skipped-SE status, bootstrap failures, and bootstrap core count.
    Otherwise `nbinom2` failures blur into one bucket instead of showing
    whether the problem is fitting, Hessian inference, refit failure, or
    target-scale bias.

## 2026-05-19 -- M3.3a nbinom2 night pilot

Scope:

- Run a small `nbinom2` start-strategy comparison using the Branch B
  fit-health schema after PR #206 merged to `main`.
- Keep artifacts in `/tmp` and record only the summary in a dev-log
  audit because this is pilot evidence, not a promoted package
  dataset.

Evidence:

- PR #206 merged as squash commit `a89aac8`.
- Branch #207 was rebased onto `origin/main`, force-pushed, and its
  PR base was changed from `codex/rr-residual-starts-2026-05-19` to
  `main`.
- `Rscript --vanilla -e 'invisible(parse(file="dev/m3-grid.R")); invisible(parse(file="dev/precompute-m3-grid.R")); cat("parse ok\n")'`
  -> `parse ok`.
- `Rscript --vanilla dev/precompute-m3-grid.R --full --family=gaussian --d=1 --n-reps=2 --start-method=res --start-jitter=0.1 --n-init=2 --init-jitter=0.05 --se=false --targets=Sigma_unit_diag --n-boot=2 --n-cores-boot=1 --ci-level=0.80 --out-dir=/tmp/gllvmtmb-m3-3a-night-smoke --out-prefix=gaussian-res-sefalse-n2`
  -> completed 2 / 2 original fits; 0 / 4 bootstrap refits failed.
- `Rscript --vanilla dev/precompute-m3-grid.R --full --family=nbinom2 --d=1 --n-reps=2 --init-strategy=single_trait_warmup --start-method=res --start-jitter=0.2 --n-init=2 --init-jitter=0.05 --se=false --targets=Sigma_unit_diag --n-boot=2 --n-cores-boot=1 --ci-level=0.80 --out-dir=/tmp/gllvmtmb-m3-3a-night-smoke --out-prefix=nbinom2-res-sefalse-n2`
  -> completed 1 / 2 original fits; 1 / 2 bootstrap refits failed.
- `Rscript --vanilla dev/precompute-m3-grid.R --full --family=mixed --d=1 --n-reps=2 --start-method=res --start-jitter=0.1 --n-init=2 --init-jitter=0.05 --se=false --targets=Sigma_unit_diag --n-boot=2 --n-cores-boot=1 --ci-level=0.80 --out-dir=/tmp/gllvmtmb-m3-3a-night-smoke --out-prefix=mixed-res-sefalse-n2`
  -> completed 2 / 2 original fits; 0 / 4 bootstrap refits failed.
- Four `nbinom2` `n_reps = 5`, `n_boot = 5` start grids:
  default, single-trait warmup, warmup + residual multistart, and
  warmup + residual multistart + BFGS. Residual multistart removed
  original fit failures in this toy grid; BFGS lowered bootstrap
  refit failure rate from 0.20 to 0.12; coverage remained poor
  (0.08 to 0.20) with mostly lower misses and estimates above truth.
- Multicore smoke:
  `Rscript --vanilla dev/precompute-m3-grid.R --full --family=nbinom2 --d=1 --n-reps=3 --init-strategy=single_trait_warmup --start-method=res --start-jitter=0.2 --n-init=5 --init-jitter=0.05 --optimizer=optim --optim-method=BFGS --se=false --targets=Sigma_unit_diag --n-boot=6 --n-cores-boot=2 --ci-level=0.80 --out-dir=/tmp/gllvmtmb-m3-3a-night-nb-multicore --out-prefix=nbinom2-warmup-res-bfgs-cores2-n3`
  -> completed 3 / 3 original fits; 2 / 18 bootstrap refits failed;
  artifact recorded `n_cores_boot = 2`.
- `git diff --check`
  -> clean.

Audit report:

- `docs/dev-log/audits/2026-05-19-m3-3a-nbinom2-night-pilot.md`

Kaizen point:

36. **nbinom2 looks under-started and target-biased, not merely slow.**
    In the toy night grid, residual multistart fixed original optimizer
    failures, and BFGS helped bootstrap refit failures. But
    `Sigma_unit_diag` still missed badly, mostly below the interval
    with estimates above truth. The next lane should separate optimizer
    failure, bootstrap refit failure, Hessian/SE failure, and
    target-scale bias instead of treating "nbinom2 failed" as one
    bucket.
