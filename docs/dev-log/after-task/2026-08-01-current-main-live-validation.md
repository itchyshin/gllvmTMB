# After Task: Current-main live validation

**Branch**: `codex/current-main-live-validation-20260801`
**Date**: 2026-08-01
**Roles (engaged)**: Ada, Curie, Gauss, Florence, Grace, Rose, Shannon, Melissa

## 1. Goal

Run a bounded live-validation arc from immutable baseline
`074387156888c915d07de445988c516b5f99d09f`: classify the two
profile-derived-curve expectations, the functional-phylogeography convergence
assertion, and the dispatcher correlation-ellipse snapshot; then run the
overdue ordinary local package check and admit at most one narrow repair.

**Mathematical contract:** no public R API, likelihood, formula grammar,
family, estimand, optimizer policy, tolerance, generated Rd, vignette, or
pkgdown-navigation change. The only implementation change qualifies the
existing `weights.gllvmTMB_va` S3 method against the `stats::weights` generic so
the namespace can load with only base attached.

## 2. Implemented

- The two heavy profile expectations were `NOT_REPRODUCED`: the complete file
  passed twice in clean fresh R processes (28.8 s and 28.3 s).
- The spatial convergence assertion was `REPRODUCIBLE` under its direct
  three-process contract: line 54 failed three times. An equivalent
  source-unchanged diagnostic fit reported optimizer code 0, maximum gradient
  `0.006637`, scaled gradient `8.52e-07`, loading cosine `0.99933167`, and
  maximum correlation error `2.17e-09`. The same test passed in the built-package
  check, so the overall evidence is execution-context-sensitive and does not
  justify a convergence-policy repair.
- The ellipse is `INTERPRETABLE_VISUAL_DRIFT`. The retained candidate and
  expected SVG are both 21,896 bytes; the only diff is four coordinates moving
  by 0.01 SVG units on one polygon line. No snapshot was accepted or copied.
- The ordinary baseline check found an independent namespace defect:
  `weights.gllvmTMB_va` was registered against an unqualified generic, so
  namespace loading with only base attached failed. The two-file repair changes
  `@export` to `@exportS3Method stats::weights` and regenerates `NAMESPACE`.
- Independent verification built and installed the repaired package, loaded it
  with `R_DEFAULT_PACKAGES=NULL`, passed the VA routing oracle (31 expectations),
  passed `git diff --check`, and confirmed no excluded-lane or snapshot change.

## 3a. Decisions and Rejected Alternatives

**Decision — repair only the S3 registration.** The base-only namespace failure
reproduced at package load, unload, and namespace-only load; its cause was
localized to two files, and the adjacent `nobs.gllvmTMB_va` method already uses
the correct namespaced roxygen form. Confidence: high.

**Rejected — repair the spatial test or convergence machinery.** The direct test
object failed its health flag, an equivalent instrumented fit was healthy, and
the built-package test passed. Changing a seed, assertion, tolerance, start,
optimizer, or convergence definition would attach a plausible mechanism to an
unlocalized object/path discrepancy. Confidence: high that deferral is safer.

**Rejected — repair profile inversion.** Both complete fresh-process runs
passed. Issue #837 describes an earlier asymmetric path, but this baseline
contains later profile-derived work and did not reproduce its expectations.

**Rejected — accept the SVG.** The retained diff is visually negligible, but
snapshot acceptance was explicitly excluded and would not establish or fix an
SVG-coordinate serialization or geometry policy.

## 4. Files Touched

Implementation and generated registration:

- `R/va-methods.R`
- `NAMESPACE`

Durable closure:

- `docs/dev-log/after-task/2026-08-01-current-main-live-validation.md`
- `docs/dev-log/plan-actual/2026-08-01-current-main-live-validation.md`
- `docs/dev-log/check-log.md`

No test, snapshot, README, NEWS, ROADMAP, design, validation-debt, roxygen help,
vignette, C++, AGHQ, scale-start, VA-09, or PR #881 file changed. The five-file
inventory is the predeclared cap.

## 5. Checks Run

All R commands used `TMPDIR=/private/tmp`. Complete receipts and logs are under
`/private/tmp/gllvmtmb-live-validation-receipts-20260801/` and the retained check
directories named below.

```sh
# profile, twice in separate processes
NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e \
  'devtools::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-profile-derived-curves.R", reporter = "summary")'

# spatial, three times in separate processes
NOT_CRAN=true Rscript --vanilla -e \
  'devtools::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-funcphylo-spatial-recovery.R", reporter = "summary")'

# immutable-baseline ordinary check, heavy tests explicitly unset
env -u GLLVMTMB_HEAVY_TESTS TMPDIR=/private/tmp NOT_CRAN=true \
  Rscript --vanilla -e \
  'devtools::check(args = "--no-manual", quiet = TRUE, check_dir = "/private/tmp/gllvmtmb-main-check-artifacts-clean-20260801", error_on = "never")'

# repair generation and focused verification
Rscript --vanilla -e 'devtools::document(quiet = TRUE)'
Rscript --vanilla -e 'pkgdown::check_pkgdown()'
R CMD build /private/tmp/gllvmtmb-live-validation-20260801 --no-build-vignettes --no-manual
R CMD INSTALL --library=/private/tmp/gllvmtmb-repair-verification-lib .
R_DEFAULT_PACKAGES=NULL R_LIBS=/private/tmp/gllvmtmb-repair-verification-lib \
  Rscript --vanilla -e "loadNamespace('gllvmTMB')"
NOT_CRAN=true Rscript --vanilla -e \
  'devtools::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-va-routing-oracle.R", reporter = "summary")'
git diff --check
python3 '/Users/z3437171/Dropbox/Github Local/Shinichi/skills/ultra-plan/scripts/codex-routing-audit.py' \
  --date 2026-08-01 --enforce \
  --dispatch-root /private/tmp/gllvmtmb-live-validation-receipts-20260801/routing \
  --require-luna --max-compactions-per-session 1
gh pr list --repo itchyshin/gllvmTMB --state open \
  --json number,title,headRefName,baseRefName,mergeStateStatus,statusCheckRollup,updatedAt,url
gh run list --repo itchyshin/gllvmTMB --limit 12 \
  --json databaseId,displayTitle,workflowName,status,conclusion,headBranch,headSha,url
gh pr view 882 --repo itchyshin/gllvmTMB \
  --json number,title,state,mergedAt,mergeCommit,headRefName,files,url
```

Outcomes:

- Profile: two clean passes, zero failures.
- Spatial: the same line-54 health assertion failed in all three direct runs;
  `testthat::test_file()` itself returned status 0, so classification used the
  reporter output rather than shell status.
- Baseline ordinary check: `1 ERROR, 4 WARNINGs, 4 NOTEs`; testthat
  `FAIL 1 / WARN 2 / SKIP 822 / PASS 8032`. The error is the ellipse snapshot.
  Three warnings plus two notes are duplicate symptoms of the unqualified
  `weights` registration; the remaining warning combines unavailable repository
  indices with a deliberately quoted `some::wrapper` test fixture; the other
  notes are unavailable clock verification and macOS `xcrun_db` detritus. The
  first and retained runs found the same substantive diagnostics but were
  quarantined for summary purposes because the runner wrote `main-check.log` at
  source root, creating a self-inflicted top-level-file NOTE.
- `devtools::document()`: completed and changed only `NAMESPACE`; it also
  reported pre-existing missing export tags for `AIC.gllvmTMB_multi` and
  `BIC.gllvmTMB_multi`.
- Repair build/install, base-only namespace load, VA routing oracle, and
  `git diff --check`: PASS.
- Repaired-branch ordinary check: `1 ERROR, 1 WARNING, 2 NOTEs` after
  11m39.7s; testthat counts were unchanged at
  `FAIL 1 / WARN 2 / SKIP 822 / PASS 8032`. Relative to baseline, the repair
  removed exactly the three namespace warnings and two dependent namespace
  notes. The ellipse error and unrelated warning/notes remain.
- `pkgdown::check_pkgdown()`: FAIL because the existing public
  `gllvmTMB_va-methods` topic is missing from `_pkgdown.yml`. This is a second
  public-surface defect exposed on immutable baseline `07438715`, not part of
  the selected S3 registration repair. While this arc remained pinned, PR #882
  independently fixed that omission and merged to remote `main` at `0b898266`;
  this branch does not duplicate or absorb it.
- Enforced routing audit: PASS; retained dispatch receipts supplied three Luna
  routes, Sol was a minority, Terra remained the majority, and no audited
  session exceeded one compaction.
- Shannon coordination audit: WARN. PRs #881 and #877 remain open; PR #882
  merged during this pinned arc and overlaps only the append-only
  `docs/dev-log/check-log.md` closure surface. Main CI for `0b898266` was still
  running at the audit. Safe next action: preserve this local commit, do not
  rebase/merge during the arc, and reconcile the append after CI in a later
  integration step.

## 6. Tests of the Tests

No test file changed. The existing `R CMD check` package-load,
package-unload, and base-namespace checks are the regression harness: the
untouched baseline recorded `object 'weights' not found`, whereas the repaired
tarball loads with `R_DEFAULT_PACKAGES=NULL`. The VA routing oracle additionally
confirms that `weights(fit)` still reaches the deliberate variational-method
error rather than a default method.

The existing spatial assertion caught the direct-run discrepancy, but the
built-package pass shows that one execution route cannot certify stable
failure. The profile tests were exercised with both gates enabled. The visual
snapshot test caught a four-token polygon-coordinate diff; retained SVG inspection
demonstrated what the snapshot failure does and does not mean.

## 7. Roadmap Tick

**Roadmap tick:** N/A — no `ROADMAP.md` status or progress row changed.

## 7a. Issue Ledger

Inspected open issues #837 (profile curve inversion), #835 (SVG text noise),
and #872 (a distinct two-tier flat-objective convergence question), plus closed
#650 (ellipse fill clamping). #837 did not reproduce on the pinned baseline;
#835 concerns other snapshots but supports treating tiny SVG text differences
as observational rather than mathematical evidence; #872 and #650 do not own
the present spatial-path discrepancy. No issue was commented, closed, or
created because external tracker mutation was outside this arc; the repair and
residuals are preserved here and in the check log.

## 8. Consistency Audit

The following exact searches were run from the integration worktree:

```sh
rg -n 'test-profile-derived-curves|test-funcphylo-spatial-recovery|dispatcher-correlation-ellipse' docs/dev-log/handover docs/dev-log/check-log.md tests/testthat
```

Verdict: found the historical handover/check-log claims and the three live test
surfaces; the fresh receipts supersede historical fail counts without deleting
their record.

```sh
rg -n 'main.*(red|green)|18 fail|3 err|three failures|3 fail' docs/dev-log/handover/2026-07-31-claude-handover-851-lane-closed.md docs/dev-log/check-log.md
```

Verdict: confirmed the correction that aggregate Totoro counts were a harness
error and retained only the properly scoped historical three-failure statement.

```sh
rg -n 'VA-09|AGHQ|scale-start|scale-aware start' docs/dev-log/handover/2026-07-31-claude-handover-851-lane-closed.md docs/dev-log/handover/2026-07-31-codex-handover.md docs/design/35-validation-debt-register.md
```

Verdict: VA-09 and AGHQ/scale work remain separate. The command correctly
reported the local absence of `docs/dev-log/handover/2026-07-31-codex-handover.md`:
that file is on unmerged PR #881, which this arc did not touch.

No user-facing prose, equation, formula example, capability claim, or generated
help changed, so the convention-change cascade, status inventory, rendered-Rd,
pkgdown, and validation-debt claim sweeps are not applicable.

## 9. What Did Not Go Smoothly

- The first Luna child ran read-only and could not create an R temporary
  directory or write its receipt. Its routing manifest is retained; the parent
  repeated the mechanical provenance checks with `TMPDIR=/private/tmp`.
- The first profile attempt used the dirty primary checkout. It was immediately
  quarantined and excluded; both admitted runs came from the exact detached
  worktree.
- The initial check runner wrote its console log into the package root, adding
  a false top-level-file NOTE. A retained rerun supplied the SVG diff, then the
  runner moved all outputs outside source and launched an authoritative clean
  check. No contaminated status count is presented as the clean result.
- `testthat::test_file()` returned shell status 0 despite the spatial failure.
  The receipt therefore preserves the reporter output and exact assertion.
- The Luna mechanical gate required two brief/receipt corrections. Its last
  run still cited a superseded line-20 `NO_REPAIR` statement that does not exist
  in the numbered current file. The parent retained that audit text, added the
  exact ground-truth correction, and routed the discrepancy to Rose rather than
  silently calling the gate green.
- Remote `main` moved during closeout when PR #882 independently repaired the
  pkgdown topic index. That PR also appended `docs/dev-log/check-log.md`, so
  this branch now has an append-only shared-file overlap. The arc did not fetch,
  rebase, merge, or resolve that foreign lane while its main CI was running.

## 10. Known Residuals

1. The spatial test is reproducibly red under the direct `load_all()` contract
   but green in the built-package test run. A later narrow arc should compare
   the exact loaded namespace/DLL, object creation, RNG state, and health fields
   between those two routes before changing convergence semantics.
2. The ellipse snapshot remains SVG-coordinate-sensitive. This arc classifies
   the retained diff but does not accept it or design a serialization/geometry
   policy.
3. The profile results establish only non-reproduction on this host and SHA;
   they do not close issue #837 or certify profile coverage.
4. The ordinary check still contains environment and/or fixture warnings that
   are classified in its receipt; this arc repairs only the S3 registration.
5. `pkgdown::check_pkgdown()` fails on the pinned `07438715` baseline because
   `gllvmTMB_va-methods` is absent from `_pkgdown.yml`. PR #882 independently
   fixed that exact omission on remote `main`; do not recreate it here. A later
   integrator must reconcile the append-only `check-log.md` overlap without
   changing this arc's evidence.
6. The primary checkout remains another lane's dirty tree and was never used.

**Arc estimate:** 120 recommended minutes; **actual:** 90 wall minutes from
worktree creation through validated local commit preparation.

## 11. Team Learning (per AGENTS.md Standing Review Roles)

**Ada** kept historical failure attribution separate from live evidence and
reopened the repair gate only for the newly discovered namespace defect.

**Curie** quarantined invalid profile runs, then demonstrated two clean passes;
she also independently verified the repair against the untouched failure log.

**Gauss** retained the spatial fit-health, gradient, stationary, boundary,
loading-cosine, and correlation-error diagnostics. Those fields prevented a
policy change based on a Boolean alone.

**Florence** separated visual interpretability from covariance validation. The
retained snapshot diff changed four polygon-coordinate tokens by 0.01 SVG
units; the cause remains unestablished.

**Grace** found the public-S3 namespace defect and the check-runner contamination
while retaining the ordinary-check evidence rather than reducing it to a red or
green label.

**Rose** returned **PASS** after three rounds of bounded prose/attribution
corrections. Her final receipt explicitly withholds package-green, merge,
release, cross-platform, and public-capability claims.

**Shannon** found that PR #882 independently fixed the pkgdown residual and
moved remote `main` during closeout. Her WARN keeps that foreign repair out of
this branch and makes the `check-log.md` overlap explicit.

**Melissa**: see the paired plan-versus-actual reconciliation.

## 12. Cross-Product Coverage

This arc **does NOT cover** Poisson VA-09 recovery, AGHQ or scale-start design,
optimizer or tolerance policy, snapshot acceptance, cross-platform evidence,
PR #881, release readiness, merge readiness, or any public capability claim.
The S3 repair covers only base-namespace registration and the existing
variational `weights()` method dispatch; it does not certify variational
estimation, interval calibration, pkgdown navigation, or any other S3 method.
