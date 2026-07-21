# After Task: 0.6 M1 Release Truth and Heavy Baseline

**Branch**: `codex/gllvmtmb-060-m1-baseline-20260720`

**Frozen base**: `de211f762812c574646938adaca22cbf41c6175e`

**Date**: 2026-07-20

**Status**: HEAVY BASELINE AND D-50 TARGETED GATES GREEN; final exact-head
local and remote gates pending

**Roles engaged**: Ada, Shannon, Grace, Emmy, Gauss, Noether, Curie, Fisher,
Boole, Pat, Florence, and Rose

## 1. Goal

Establish the truthful release baseline for gllvmTMB 0.6 before any Design 86
EVA work: prove exclusive ownership, reproduce and classify every failure on a
fresh `origin/main`, apply only independently reviewed contract repairs, restore
the complete scheduled-heavy package suite, retire prohibited scientific
GitHub Actions routes under D-50, and leave a complete release ledger.

M1 is the first of five serial macros. It does not admit EVA, launch remote
compute, integrate a new public feature, freeze a release candidate, tag a
version, submit to CRAN, or support a release-readiness claim.

## 2. Implemented

### Ownership and frozen lanes

- Codex is the sole repository owner and sole writer for this programme.
- The dirty primary checkout at
  `6fcf0998a87d00b791c299c94e7995f23c744199` remains quarantined and
  untouched.
- The builder was created from fresh `origin/main` at
  `de211f762812c574646938adaca22cbf41c6175e`; the verifier remains detached
  at the same base.
- The primary check-log was proven to equal its own committed blob byte-for-byte
  plus one 303-line local tail. That tail is preserved only in the primary; it
  was not imported into this branch.
- The inactive parked worktree `agent-ae50a884b8bfbdef5` overlaps only on
  `docs/design/35-validation-debt-register.md`; it remains untouched.

### Reproduced failure truth

The untouched verifier reproduced exactly 48 failures/errors:

- 46 nonvisual failures/errors in the 12-file M1 verifier: 26 failed
  expectations plus 20 errors;
- two visual snapshot mismatches;
- structured-slope contract batch: 12;
- matrix point-only contract batch: 8;
- bootstrap contract batch: 2;
- nonlinear-profile contract batch: 17;
- extractor-channel batch: 7;
- deterministic visual batch: 2;
- Rose neighbour-audit additions: 0.

### Contract repairs

- Centralised the already-landed augmented-slope family/link admission rule so
  runtime guards and tests no longer disagree. Lognormal and Student-t retain
  narrow C1 runtime admission; broader structured-route recovery and interval
  evidence remain partial. Tweedie, beta-binomial, delta/hurdle families, and
  unadmitted links remain fail-loud.
- Corrected covariance-channel extraction for current and legacy structured
  slope fits so labels describe the covariance actually fitted instead of a
  neighbouring channel.
- Withdrew the nonlinear penalty-profile prototype from every public derived
  correlation, communality, repeatability, and proportion route. Requests now
  fail with `gllvmTMB_nonlinear_profile_withdrawn`; point, Fisher-z, Wald, and
  route-specific bootstrap contracts remain separate.
- Made two plot snapshots deterministic without changing their statistical
  values or plot grammar.
- Removed the obsolete tracked `test-zzz-qdebug.R` instrumentation file.
- Reconciled NEWS, likelihood/extractor contracts, inference-route matrices,
  capability status, and validation-debt rows with the actual release boundary.
- Removed the stale `DESCRIPTION` `RoxygenNote: 7.3.2`; the retained
  `Config/roxygen2/version: 8.0.0` is the source of truth. Explicit roxygen2 8
  regeneration produced no further `NAMESPACE` or `man/` drift.

### D-50 fail-closed GitHub Actions boundary

Fourteen scientific campaign workflows were removed from source:

1. `coevolution-two-kernel-recovery.yaml`;
2. `dep-slope-identifiability-sweep.yaml`;
3. `dep-slope-poisson-recovery.yaml`;
4. `gamma-ordinal-recovery-depth.yaml`;
5. `m3-production-grid.yaml`;
6. `nightly-stale-test-fixups-gate.yaml`;
7. `phylo-q-decomposition-recovery.yaml`;
8. `power-pilot-sweep.yaml`;
9. `simulate-unit-trait-recovery.yaml`;
10. `slope-grid-residuals-recovery.yaml`;
11. `spatial-dep-slope-nongaussian-recovery.yaml`;
12. `spatial-indep-slope-nongaussian-recovery.yaml`;
13. `spatial-latent-slope-nongaussian-recovery.yaml`;
14. `spde-slope-base-engine-check.yaml`.

Only `R-CMD-check.yaml`, `full-check.yaml`, and `pkgdown.yaml` remain. The two
package checks now execute `tools/check-actions-boundary.sh`, explicitly select
`shell: bash`, set `upload-snapshots: false`, and set
`upload-results: never`. The guard rejects any extra workflow, direct
`actions/upload-artifact`, package snapshot/result uploads, or a Pages upload
outside pkgdown.

Historical run records, failed denominators, seed bands, and old manifest
fields remain preserved and clearly labelled historical. The tested manifest
compatibility paths pass 147 assertions; this is not a claim that every
historical result store was replayed. Current dev scripts provide deterministic
local diagnostics and bounded smoke plumbing only. They do not provide an
admitted production DRAC driver: that requires a later, checksummed
compute-admission bundle and explicit maintainer authority.

### Mathematical contract

No likelihood equation, TMB parameter transform, response-family
parameterisation, formula grammar, exported symbol, function signature,
NAMESPACE entry, or estimator was added or changed. The fitted covariance
models remain the already-landed contracts. Public behavior did change: M1
aligns admission policy, covariance-channel read-out, typed refusal of an
unsupported approximation route, deterministic rendering, and compute/CI
process truth.

Design 85 remains a landed research-only NO-GO prototype. No `integration =
"eva"` public control exists. Design 86 remains a later M2 estimator contract.

**Roadmap tick**: N/A. `ROADMAP.md` was deliberately not changed; M1 restores
truth and package gates but does not complete a public roadmap phase.

## 3a. Decisions and Rejected Alternatives

- **Use one clean builder and detached verifier.** Rejected: switching,
  stashing, cleaning, rebasing, or merging the dirty primary and 38-worktree
  estate. The quarantined files are user/agent evidence, not disposable state.
- **Selectively reconstruct the repair.** Rejected: wholesale cherry-pick of
  `0f1ef2bc`, because its profile hunks included superseded contracts.
- **Treat the 48 failures as evidence, not inconvenience.** Rejected: relaxing
  expectations, deleting legitimate tests, or declaring the suite flaky.
- **Withdraw nonlinear penalty profiles.** Rejected: shipping a numerically
  plausible prototype without an exact or independently tolerance-certified
  constraint solver, endpoint ledger, and target-specific calibration.
- **Keep structured-slope statements partial.** Rejected: promoting one-seed
  or mechanically shared family guards into route-wide recovery or interval
  claims.
- **Delete scientific workflows from source.** Rejected: relying only on their
  current `disabled_manually` server state, because they can be re-enabled and
  therefore are not fail-closed.
- **Do not build a DRAC production driver inside M1.** Rejected: widening a
  release-truth repair into a new campaign system without its own symbolic,
  provenance, retry, parity, and maintainer-admission gates.
- **Retain all historical scientific receipts.** Rejected: rewriting or
  deleting failed runs merely because their execution route is now prohibited.
- **Keep EVA outside M1.** Rejected: treating the Design 85 prototype or the
  proposal for Design 86 as sufficient evidence for public 0.6 admission.

## 4. Files Touched

### GitHub Actions and boundary guard

- `.github/workflows/R-CMD-check.yaml`
- `.github/workflows/full-check.yaml`
- `.github/workflows/coevolution-two-kernel-recovery.yaml` (deleted)
- `.github/workflows/dep-slope-identifiability-sweep.yaml` (deleted)
- `.github/workflows/dep-slope-poisson-recovery.yaml` (deleted)
- `.github/workflows/gamma-ordinal-recovery-depth.yaml` (deleted)
- `.github/workflows/m3-production-grid.yaml` (deleted)
- `.github/workflows/nightly-stale-test-fixups-gate.yaml` (deleted)
- `.github/workflows/phylo-q-decomposition-recovery.yaml` (deleted)
- `.github/workflows/power-pilot-sweep.yaml` (deleted)
- `.github/workflows/simulate-unit-trait-recovery.yaml` (deleted)
- `.github/workflows/slope-grid-residuals-recovery.yaml` (deleted)
- `.github/workflows/spatial-dep-slope-nongaussian-recovery.yaml` (deleted)
- `.github/workflows/spatial-indep-slope-nongaussian-recovery.yaml` (deleted)
- `.github/workflows/spatial-latent-slope-nongaussian-recovery.yaml` (deleted)
- `.github/workflows/spde-slope-base-engine-check.yaml` (deleted)
- `tools/check-actions-boundary.sh` (new)

### Package source and metadata

- `DESCRIPTION`
- `NEWS.md`
- `R/extract-sigma.R`
- `R/fit-multi.R`
- `R/plot-gllvmTMB.R`
- `R/profile-route-matrix.R`
- `man/extract_Sigma.Rd`

### Dev-only campaign readers and routing prose

- `dev/m3-pilot-launch.R`
- `dev/m3-pilot-local-loop.R`
- `dev/m3-pilot-report.R`
- `dev/power-pilot-run.R`
- `dev/precompute-m3-grid.R`

### Design and status contracts

- `docs/design/01-formula-grammar.md`
- `docs/design/03-likelihoods.md`
- `docs/design/05-testing-strategy.md`
- `docs/design/06-extractors-contract.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/42-m3-dgp-grid.md`
- `docs/design/44-m3-3-inference-replacement.md`
- `docs/design/49-robust-modeling-roadmap.md`
- `docs/design/50-m3-3b-surface-admission.md`
- `docs/design/61-capability-status.md`
- `docs/design/66-capstone-power-study.md`
- `docs/design/70-missing-data-simulation-design.md`
- `docs/design/73-profile-likelihood-route-matrix.md`
- `docs/design/74-augmented-profile-target-table.md`
- `docs/design/75-inference-route-truth-matrix.md`

### Tests and snapshots

- `tests/testthat/setup.R`
- `tests/testthat/test-augmented-slope-family-policy.R` (new)
- `tests/testthat/test-binomial-slope-recovery.R`
- `tests/testthat/test-bootstrap-Sigma.R`
- `tests/testthat/test-bootstrap-lv-effects.R`
- `tests/testthat/test-confint-derived.R`
- `tests/testthat/test-extract-sigma-spde-base-slope.R`
- `tests/testthat/test-family-slope-recovery.R`
- `tests/testthat/test-m1-4-extract-correlations-mixed-family.R`
- `tests/testthat/test-matrix-ordinal-unit.R`
- `tests/testthat/test-matrix-poisson-unit.R`
- `tests/testthat/test-matrix-slope-phylo-indep.R`
- `tests/testthat/test-phylo-indep-slope-spike.R`
- `tests/testthat/test-phylodepindep-binary.R`
- `tests/testthat/test-plot-gllvmTMB.R`
- `tests/testthat/test-plot-visual-snapshots.R`
- `tests/testthat/test-profile-proportions.R`
- `tests/testthat/test-profile-route-matrix.R`
- `tests/testthat/test-profile-targets.R`
- `tests/testthat/test-relmat-indep-slope-gaussian.R`
- `tests/testthat/test-spatial-dep-slope-nongaussian.R`
- `tests/testthat/test-spatial-depindep-binary.R`
- `tests/testthat/test-spatial-latent-slope-gaussian.R`
- `tests/testthat/test-zzz-qdebug.R` (deleted)
- `tests/testthat/_snaps/plot-visual-snapshots/dispatcher-communality-stacked-bars-plot.svg`
- `tests/testthat/_snaps/plot-visual-snapshots/dispatcher-variance-partition-plot.svg`

### Durable receipts

- `docs/dev-log/after-task/2026-07-20-m1-heavy-baseline.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/recovery-checkpoints/2026-07-20-123822-codex-p0-checkpoint.md`
- `docs/dev-log/recovery-checkpoints/2026-07-20-230053-codex-m1-local-closeout-checkpoint.md`

No README, vignette/article, `_pkgdown.yml`, `ROADMAP.md`, NAMESPACE, or other
generated help file changed. The only generated help change is
`man/extract_Sigma.Rd`, paired with `R/extract-sigma.R`.

## 5. Checks Run

### Baseline and package behavior

- Untouched base verifier: 106 summary rows, 26 failed expectations, 20
  errors, 3 declared skips, 373 passes, 954.6822 seconds. Receipt
  `/private/tmp/gllvmtmb-060-m1-verifier-results.rds`, SHA-256
  `d8634915ebdb2bd67fc5f1a3797c5daaabe39ff773cf299ff84904b3bef24153`.
- Repaired complete heavy suite at `c471bbea`: 1,951 summary rows, 0
  failures, 0 errors, 87 declared skips, 9 classified warnings, 13,641
  passes, 7,525.879 seconds. Receipt
  `/private/tmp/gllvmtmb-060-m1-full-heavy-current-results.rds`, SHA-256
  `9da6e27a46a0b68bb6eb804205543139d04efc5b1233361bcd8e5d95745794ac`.
- No-skip audit of the repaired M1 cells: 59 named rows across 19 files,
  523 passes, 0 failures, 0 errors, 0 skips, 0 warnings. CSV SHA-256
  `2218d7978ddb429cf7222a23386eb2e59289a0b817ec78d748ab879ab57bd32d`.
- Explicit roxygen2 8 documentation: PASS with no unplanned generated diff.
  Initial log SHA-256
  `a833c94f496dab9b59ef9e0fe0d1ae50449adf710a8404b9750f74132693db1c`;
  post-metadata log SHA-256
  `9b834fee77389dd90c3663b56ad898a55a74fbe3aa47395bf0c3c5de7d472e83`.
- `pkgdown::check_pkgdown()`: PASS. Log SHA-256
  `4cd0200ed0bddccb1561b06b5ffbf716a6ca4f6556abaa1235660aa716d6b3a8`.
- Heavy source-package check at `c471bbea`: 0 R CMD errors, warnings, or
  notes; internal testthat 13,313 passes, 131 skips, 9 classified warnings.
  RDS SHA-256
  `06f439037aff2e41a362d39da5e7e834d89dbffcf75e345cb6c85582ec7e9742`.
- Standard source-package check at `d05db562`: 0 R CMD errors, warnings, or
  notes; internal testthat 7,007 passes, 809 skips, one expected ordination
  warning. RDS SHA-256
  `54bc1a84c67e2989fd2e4c928448931d7c84e06bc7630a6077799183ecfd8c35`.

Exact invocations and receipt locations for the load-bearing checks were:

```sh
NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1 \
  OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 \
  Rscript --vanilla -e '
files <- c(
  "tests/testthat/test-binomial-slope-recovery.R",
  "tests/testthat/test-bootstrap-lv-effects.R",
  "tests/testthat/test-bootstrap-Sigma.R",
  "tests/testthat/test-confint-derived.R",
  "tests/testthat/test-extract-sigma-spde-base-slope.R",
  "tests/testthat/test-m1-4-extract-correlations-mixed-family.R",
  "tests/testthat/test-matrix-ordinal-unit.R",
  "tests/testthat/test-matrix-poisson-unit.R",
  "tests/testthat/test-phylo-indep-slope-spike.R",
  "tests/testthat/test-profile-proportions.R",
  "tests/testthat/test-profile-targets.R",
  "tests/testthat/test-relmat-indep-slope-gaussian.R"
)
started <- Sys.time()
results <- lapply(files, function(path) {
  testthat::test_file(path, reporter = "summary", stop_on_failure = FALSE)
})
saveRDS(
  list(
    files = files,
    results = results,
    elapsed_seconds = as.numeric(difftime(Sys.time(), started, units = "secs"))
  ),
  "/private/tmp/gllvmtmb-060-m1-verifier-results.rds"
)
' > /private/tmp/gllvmtmb-060-m1-verifier-m1-subset.log 2>&1
```

Baseline receipts:
`/private/tmp/gllvmtmb-060-m1-verifier-results.rds` and
`/private/tmp/gllvmtmb-060-m1-verifier-m1-subset.log` (log SHA-256
`ade2d238a06e8b1a972526a3597fba25038cd0a06bb010e879fb95573d46efa9`).

```sh
NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1 \
  OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 \
  Rscript --vanilla /private/tmp/gllvmtmb-060-m1-full-heavy-runner.R \
  > /private/tmp/gllvmtmb-060-m1-full-heavy-current.log 2>&1

Rscript --vanilla /private/tmp/gllvmtmb-060-m1-no-skip-audit.R
```

Heavy receipts:
`/private/tmp/gllvmtmb-060-m1-full-heavy-current-results.rds`,
`/private/tmp/gllvmtmb-060-m1-full-heavy-current-summary.csv`, and
`/private/tmp/gllvmtmb-060-m1-full-heavy-current.log`; runner SHA-256
`b8339478d4bb3638e2d1cc2829a11a213d0d07bae231c3148152743e40ca8919`.
No-skip receipt:
`/private/tmp/gllvmtmb-060-m1-no-skip-audit.csv`; runner SHA-256
`9dbaa157a4b46e6fff0bc9f7eb96a5aee234a9fa269f4e240aa60636039576d5`.

```sh
Rscript --vanilla -e '
devtools::document()
cat("ROXYGEN_VERSION=", as.character(packageVersion("roxygen2")), "\n", sep = "")
' > /private/tmp/gllvmtmb-060-m1-document-postmetadata.log 2>&1

Rscript --vanilla -e 'pkgdown::check_pkgdown()' \
  > /private/tmp/gllvmtmb-060-m1-pkgdown-check.log 2>&1
```

Documentation receipts:
`/private/tmp/gllvmtmb-060-m1-document-postmetadata.log` and
`/private/tmp/gllvmtmb-060-m1-pkgdown-check.log`.

```sh
NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1 \
  OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 \
  Rscript --vanilla /private/tmp/gllvmtmb-060-m1-check-runner.R \
  > /private/tmp/gllvmtmb-060-m1-check-current.log 2>&1

NOT_CRAN=true \
  OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 \
  Rscript --vanilla /private/tmp/gllvmtmb-060-m1-final-check-runner.R \
  > /private/tmp/gllvmtmb-060-m1-final-check.log 2>&1
```

Heavy package-check receipts:
`/private/tmp/gllvmtmb-060-m1-check-current-results.rds` and
`/private/tmp/gllvmtmb-060-m1-check-current.log`; runner SHA-256
`7ef79c70359e03392b6ea015843f42dfdbbc543bf74ad2e6fb77f18827599a1d`.
Standard package-check receipts:
`/private/tmp/gllvmtmb-060-m1-final-check-results.rds` and
`/private/tmp/gllvmtmb-060-m1-final-check.log`; runner SHA-256
`31f2df652630fafa0c1988f52116f0d8337115fe1e017e5114f5931e737dad48`.

### D-50 boundary

- `bash -n tools/check-actions-boundary.sh`: PASS.
- `bash tools/check-actions-boundary.sh`: PASS; exactly the three allowed
  workflows and no package-check artifacts.
- Ruby/Psych parse of all three retained YAML files: PASS. The first command
  used a newer `YAML.load_file(..., aliases: true)` API unavailable in the
  system Ruby 2.6 and failed before parsing; the compatible
  `YAML.load(File.read(...))` command passed all files.
- R parse of all five modified dev scripts: PASS.
- `devtools::test(filter = "m3-pilot-manifest")`: 147 passes, 0 failures,
  0 warnings, 0 skips.
- Four isolated negative guard fixtures: PASS. The guard rejected an extra
  workflow, direct `actions/upload-artifact@v4`,
  `upload-snapshots: true`, and a missing `upload-results: never`.
- Boundary-guard SHA-256:
  `b94d91e7cca9996de6c28ca41f94c304e757f411c193b22422e9610d7d25717e`.
- Live GitHub census: `R-CMD-check`, `full-check`, and `pkgdown` are active;
  the retired registrations remain `disabled_manually`; queued and in-progress
  runs are both zero.
- `git diff --check`: PASS.

### Coordination and documentation structure

- Open PRs: 0; remote M1 branch: absent; active external owners: 0.
- Primary committed-prefix proof: PASS. The 303-line primary-only tail is
  24,675 bytes with SHA-256
  `902d88919d88b43c89cec54fd4cd08b619529e2110ac79eca02e244597425ced`.
- `Rscript /Users/z3437171/Dropbox/Github\ Local/Shinichi/tools/check-after-task.R
  docs/dev-log/after-task/2026-07-20-m1-heavy-baseline.md`: PASS,
  `after-task structure check passed`.
- A final exact-head standard package check, one PR, three-platform package CI,
  and Ubuntu scheduled-heavy CI remain pending. Earlier green local receipts do
  not substitute for those exact-head remote gates.

## 6. Tests of the Tests

- The untouched detached verifier supplied failure-before-fix evidence for all
  48 baseline failures/errors; repaired expectations were not inferred from a
  green-only run.
- `test-augmented-slope-family-policy.R` joins each runtime guard to one
  central family/link policy, including admitted and rejected rows. It would
  catch the drift where a family passed one structured slope guard but failed
  a mechanically equivalent guard elsewhere.
- The nonlinear-profile tests require the public typed refusal across ordinary,
  phylogenetic, spatial, kernel, augmented, ordinal, and mixed-family
  neighbours. They would catch any accidental reactivation of the withdrawn
  prototype under a different target name.
- Extractor tests reconstruct the fitted covariance channel independently and
  compare labels/dimensions; they would catch the legacy/current channel swap
  that produced the baseline extractor failures.
- Snapshot tests compare deterministic plot structure and rendering; the two
  changed snapshots were reviewed as rendering-only changes.
- The 59-row no-skip audit ensures the repaired M1 assertions genuinely ran and
  did not turn red tests into environmental skips.
- The D-50 guard has one positive case and four deliberately corrupted
  negative cases. Each negative fixture failed for its intended policy rule.
- No statistical test was removed to make the suite green. The only deleted
  test file was the explicitly temporary qdebug instrumentation probe.

## 7a. Issue Ledger

The following open issues were inspected and remain open:

- **#343 — CI / engineering health**: M1 advances the package gate, but the
  umbrella contains further engineering work and lacks merged platform proof.
- **#341 — random-slope completion**: non-Gaussian route depth, extractor gaps,
  and the article remain incomplete.
- **#340 — capability matrix / live status board**: continuing umbrella.
- **#345 — CRAN readiness and paper**: release-candidate, three-platform,
  paper, and downstream release gates remain.
- **#346 — simulation / coverage framework**: M1 retires prohibited Actions
  compute but does not implement or run the required Totoro/DRAC programme.
- **#348 — family-validation completion**: family fixtures and recovery-depth
  work remain incomplete.
- **#750 — unconditional structured-tier redraw**: M1 preserves the fail-loud
  limitation and does not implement unconditional phylogenetic/spatial redraw.

No issue closes. The eventual PR relates to #343, #341, #340, #345, #346,
#348, and #750 but must explicitly say it closes none, especially not #346 or
#750. No new issue is needed for this already-tracked M1 scope.

## 8. Consistency Audit

Exact closeout scans and verdicts:

```sh
rg -n 'penalty[-_ ]profile|nonlinear[_ -]profile|gllvmTMB_nonlinear_profile_withdrawn' R tests/testthat NEWS.md docs/design man
```

Verdict: all public and design occurrences classify nonlinear profiles as
withdrawn/blocked or preserve clearly labelled historical evidence; typed
refusal tests are present across neighbouring routes.

```sh
rg -n 'coevolution-two-kernel-recovery|dep-slope-identifiability-sweep|dep-slope-poisson-recovery|gamma-ordinal-recovery-depth|m3-production-grid|nightly-stale-test-fixups-gate|phylo-q-decomposition-recovery|power-pilot-sweep|simulate-unit-trait-recovery|slope-grid-residuals-recovery|spatial-dep-slope-nongaussian-recovery|spatial-indep-slope-nongaussian-recovery|spatial-latent-slope-nongaussian-recovery|spde-slope-base-engine-check' .github docs/design dev tests/testthat
```

Verdict: no current scientific Actions route remains. The remaining named
workflow references are historical receipts, including ANI-12 and the failed
M3 run.

```sh
rg -n 'actions/upload-artifact@|upload-snapshots:[[:space:]]+true|upload-results:[[:space:]]+(always|on-error)' .github/workflows
find .github/workflows -maxdepth 1 -type f \( -name '*.yaml' -o -name '*.yml' \) -print | sort
```

Verdict: no prohibited upload setting matches; inventory is exactly the three
allowlisted package/docs workflows.

```sh
rg -n 'integration[[:space:]]*=[[:space:]]*["'"']eva|\bEVA\b|variational approximation' R src man NAMESPACE tests/testthat
```

Verdict: only `R/va-r3-proto.R`, the Design 85 research-only prototype,
matches. No public EVA control, compiled route, help topic, NAMESPACE entry, or
test claim exists.

```sh
rg -n 'test-zzz-qdebug|qdebug|RoxygenNote:[[:space:]]*7\.3\.2' DESCRIPTION tests docs NEWS.md
```

Verdict: qdebug appears only in its historical after-task warning; the tracked
probe and stale roxygen note are absent.

Status inventory verdict: `NEWS.md`, Designs 01/03/05/06/35/42/44/49/50/61/
66/70/73/74/75, and generated `extract_Sigma.Rd` now agree with implementation.
README, ROADMAP, vignettes, `_pkgdown.yml`, and the wider reader estate were
inspected for scope but deliberately remain M4 surfaces; no M1 feature claim
requires their mutation.

## 9. What Did Not Go Smoothly

- The primary checkout was divergent and dirty, and the repository retained 38
  worktrees. Exclusive ownership therefore required a clean builder/verifier
  pair rather than pretending the estate itself was clean.
- The original handover counted 46 heavy failures/errors but omitted the two
  visual mismatches. Untouched reproduction established the actual denominator
  of 48.
- Two attempted long heavy runs were stopped after later review found release-
  truth defects in docs/tests. Their partial output was not promoted; the final
  complete run was restarted from the corrected commit.
- The initial M1 report was only a branch-opening placeholder and used an old
  heading template. It required replacement with the current 12-section gate.
- D-50 was initially treated as a server-state fact because all scientific
  workflows were manually disabled. Grace and Rose correctly rejected that as
  non-fail-closed and found stale current routes in Designs 42/44/49/66/70 and
  the executable dev headers.
- The first YAML parse command used a Psych API not available in macOS Ruby
  2.6. The compatible parser command passed; this was a command portability
  failure, not invalid workflow YAML.
- A naive full-file prefix comparison between the builder and dirty primary
  check-log failed because their committed histories differ. Comparing the
  primary file with its own HEAD blob proved the local 303-line tail exactly and
  prevented accidental import or overwrite.

## 10. Known Residuals

- M1 still needs the exact-head local closeout check, one push/PR, the requested
  three-platform package check, Ubuntu heavy CI, and final independent
  NOT-DONE-default synthesis before it can close.
- The nine complete-heavy warnings remain bounded evidence, not hidden:
  four loading-bootstrap smoke warnings with 30/40 surviving refits; one
  nbinom2 and one Tweedie `sdreport()` covariance warning; one expected
  conditional-residual warning; one phylogenetic unconditional-redraw fallback;
  and one mock-ordination unavailable-link-residual warning. They support no
  interval/coverage or unconditional-redraw claim.
- Reader-estate blockers remain for M4: mode teaching in README, ROADMAP lambda
  visibility, internal identifiability routing, reaction-norm and troubleshooting
  navigation, stale known-limitations prose, covariance-article Fisher-z
  wording, and maintainer decisions on retained pages/figures.
- The inactive overlapping worktree and dirty primary remain quarantined; M1
  neither cleans nor reconciles them.
- No remote compute was launched. Totoro/DRAC production remains prohibited
  until M2 has passed deterministic gates and the maintainer separately approves
  the exact smoke/pilot bundle.
- No public EVA, source/API freeze, release-candidate freeze, tag, submission,
  release-ready statement, or release claim is authorised by this report.

## 11. Team Learning

**Ada** kept the five macros serial and treated every attractive adjacent fix as
a scope decision. The important orchestration lesson is that green local tests
do not permit EVA, compute, public admission, or release ceremony to leak
forward across gates.

**Shannon** proved ownership from live PR/run/process/worktree evidence and
identified the one inactive register overlap. The reusable rule is one explicit
writer plus immutable parked state, not a broad claim that every checkout is
clean.

**Grace** separated package-regression CI from scientific evidence, required
source deletion rather than reversible workflow disablement, caught missing
`shell: bash`, and rejected dev comments that overstated DRAC readiness. Future
campaign work must begin with non-missing source/archive/runner hashes, not add
them after a run.

**Emmy** rejected a wholesale repair-branch cherry-pick and reviewed covariance
channel/object consistency. Future extractor repairs should reconstruct the
fitted channel independently before changing labels.

**Gauss** checked that M1 changed no TMB likelihood or parameter transform and
that the slope-family policy reflected existing engine paths. Any future
likelihood change still requires a fresh symbolic/TMB review.

**Noether** treated a numerically plausible nonlinear profile as unproved until
the constraint target and optimizer endpoints are independently verifiable.
That standard is carried into Design 86.

**Curie** required all repaired heavy cells to run without silent skips and kept
failure denominators visible. A one-seed recovery cell remains a narrow runtime
gate, never family-wide scientific admission.

**Fisher** classified all nine warnings by inferential consequence and withheld
coverage, standard-error, and unconditional-redraw claims. Warning-free output
is not the only criterion; claim-to-evidence alignment is.

**Boole** reconciled refusal grammar, route matrices, and generated extractor
help without creating a new public syntax. A typed refusal is part of the API
contract and must be documented as carefully as an admitted method.

**Pat** reviewed the user-facing refusal direction: unsupported profile requests
must identify available alternatives without implying that those alternatives
are calibrated in every route.

**Florence** reviewed the two visual changes as deterministic rendering repairs,
not visual or statistical redesign. Existing figure quality remains an M4 gate.

**Rose** repeatedly searched beyond the changed files and found the same stale
Actions/DRAC story in neighbouring designs and dev headers. The Rose principle
was decisive: fixing one routing sentence required auditing every current
compute surface, not only the deleted workflows.

## 12. Cross-Product Coverage

This M1 arc covers the Cartesian cells needed to restore the already-landed
heavy package contracts: augmented-slope family/link guards, current and legacy
structured covariance read-out, ordinary/source/kernel/augmented nonlinear-
profile refusals, bootstrap neighbours, and deterministic plot snapshots. The
complete heavy suite plus the 59-row no-skip audit verifies those named cells.

It **does NOT cover** route-wide recovery or interval calibration for every
family × link × covariance tier × rank × missingness × structure combination.
Lognormal/Student-t structured slopes remain narrow C1 runtime evidence;
Tweedie, beta-binomial, delta/hurdle, broader mixed-family intervals, correlation
profiles, BCa, and unconditional structured redraw remain partial, blocked, or
cut as recorded in the register.

The D-50 change covers source-level GitHub Actions allowlisting, package-check
artifact suppression, workflow portability, and preservation of historical
receipts. It **does NOT cover** a production Totoro/DRAC scheduler, campaign
identity, source/archive/runner checksums, seed/task manifests, retry ledger,
cross-cluster parity, result transfer, or scientific admission. Those belong to
the separately approved Design 86 M2 compute-admission package.

M1 verifies Laplace-era release truth only. It **does NOT cover** Design 86 EVA
algebra, AD, H61 calibration, paired simulations, family/link waves, public
`integration = "eva"`, EVA inference refusals, reader-ready release-candidate
construction, three-platform RC evidence, tags, CRAN submission, or any public
0.6 readiness/release claim.
