# After Task: True Binomial-Probit Pilot Harness

**Branch**: `codex/true-probit-harness-20260624`
**Date**: `2026-06-24`
**Roles (engaged)**: `Ada / Curie / Fisher / Grace / Rose / Shannon`

## 1. Goal

Replace the power-pilot audit-mini binomial row's temporary
probit-labelled logit harness with a true binomial-probit DGP and fit
path, while keeping the evidence boundary intact for all earlier pilot
and fir smoke artifacts.

## 2. Implemented

- Added `binomial_probit` as an explicit M3 harness family.
- Simulated `binomial_probit` rows with `Pr(Y = 1 | eta) = Phi(eta)` via
  `stats::pnorm()`.
- Fitted `binomial_probit` cells through `stats::binomial(link =
  "probit")`.
- Extended the binary-residual guard so both `binomial` and
  `binomial_probit` use `psi_effective = 0` in the truth covariance.
- Updated the audit-mini pilot family map so current manifests record
  `harness_family = "binomial_probit"`, `evidence_family =
  "binomial_probit"`, and `link_harness = "probit"`.
- Updated Design 66 to say the probit swap is now implemented, while
  old logit-harness pilot/fir artifacts remain historical
  scheduler/plumbing evidence only.

## 3. Mathematical Contract

This PR changes the simulation harness contract for the pilot
`binomial_probit` cell, not the package's public likelihood or R API.

For a binomial-probit row with linear predictor `eta`, the harness now
uses:

```text
Y | eta ~ Bernoulli(Phi(eta))
```

where `Phi` is the standard normal CDF. The fit path mirrors that target
with:

```r
stats::binomial(link = "probit")
```

Binary rows still do not receive an additional observed-scale Gaussian
unique residual. In the truth object, `psi` may be retained for
record-keeping, but `psi_effective = 0` for both `binomial` and
`binomial_probit` rows.

This does not change `gllvmTMB` package likelihood code, TMB
parameterization, formula grammar, exported families, roxygen topics,
generated Rd, vignettes, NEWS, or pkgdown navigation. It does not turn
pre-swap `binomial_logit_harness` artifacts into true probit evidence.

## 4. Files Changed

Harness and driver:

- `dev/m3-grid.R`
- `dev/m3-pilot-launch.R`
- `dev/precompute-m3-grid.R`

Tests:

- `tests/testthat/test-m3-grid-summary.R`
- `tests/testthat/test-m3-pilot-manifest.R`
- `tests/testthat/test-m3-pilot-report.R`

Design and logs:

- `docs/design/66-capstone-power-study.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-24-true-binomial-probit-harness.md`

Status-inventory cascade:

- `README.md`, `ROADMAP.md`, `NEWS.md`, roxygen, generated `man/*.Rd`,
  vignettes, and `_pkgdown.yml` were intentionally not changed. This is a
  dev harness and Design 66 correction, not a public user-facing
  capability advertisement.

## 4a. Decisions and Rejected Alternatives

Decision: append `binomial_probit` to `M3_FAMILIES` rather than replace
or reorder the existing `binomial` entry.

Rationale: existing family labels and family-seed indices stay stable for
the already-used families. The true probit target becomes explicit for
new audit-mini and future core-grid runs.

Rejected alternative: keep using the `binomial` harness with
`link_intended = "probit"`. That preserved traceability but left the DGP
and fit target mismatched to the locked core family.

Decision: keep historical `binomial_logit_harness` wording where it
describes old artifacts.

Rationale: earlier fir scheduled smoke jobs were useful scheduler and
artifact-schema evidence but not true probit evidence. Rewording them as
current probit runs would overclaim.

## 5. Checks Run

- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,isDraft,mergeStateStatus,url,updatedAt`
  -> PASS before shared dev-log / after-task edits; no open PRs.
- `git log --all --oneline --since="6 hours ago" --decorate`
  -> PASS before shared dev-log / after-task edits; recent history was
  `b08b146`, `3f76530`, and `7c675dd`.
- `gh run list --repo itchyshin/gllvmTMB --branch main --limit 8 --json databaseId,workflowName,status,conclusion,headSha,createdAt,displayTitle,url`
  -> observed R-CMD-check run `28120675137` success for `b08b146`,
  pkgdown run `28120717889` still in progress, scheduled Power pilot
  sweep run `28118670213` queued, and older scheduled sweep run
  `28106026686` success. Scheduled sweep output was not used as
  validation evidence.
- `gh issue list --repo itchyshin/gllvmTMB --state open --search "probit OR power pilot OR CI-08 OR CI-10" --limit 20 --json number,title,url,updatedAt`
  -> PASS; located the relevant roadmap / board issues.
- `gh issue view 349 --repo itchyshin/gllvmTMB --json number,title,state,url,body,updatedAt`
  -> PASS; inspected the capstone issue.
- `gh issue view 346 --repo itchyshin/gllvmTMB --json number,title,state,url,body,updatedAt`
  -> PASS; inspected the simulation / coverage issue.
- `gh issue view 340 --repo itchyshin/gllvmTMB --json number,title,state,url,body,updatedAt`
  -> PASS; inspected the capability board.
- `Rscript --vanilla -e 'source("dev/m3-grid.R"); source("dev/m3-pilot-launch.R"); g <- pilot_audit_mini_grid(); print(g[, c("family_label", "harness_family", "evidence_family", "link_harness")]); stopifnot(g$harness_family[3] == "binomial_probit", g$evidence_family[3] == "binomial_probit", g$link_harness[3] == "probit")'`
  -> PASS; audit-mini metadata reports true probit for the binomial-probit
  row.
- `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-m3-pilot-manifest.R")'`
  -> PASS; 147 expectations.
- `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-m3-pilot-report.R")'`
  -> PASS; 39 expectations.
- `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-m3-grid-summary.R")'`
  -> PASS by opt-in skip; 14 skipped because `GLLVMTMB_HEAVY_TESTS` was
  not set.
- `SMOKE_STAGE=all RESULTS_DIR=/tmp/gllvmtmb-true-probit-smoke-20260624 N_SIM_STEP=1 N_SIM_CAP=1 N_BOOT=0 SEED_BASE=191 bash dev/power-pilot-smoke.sh`
  -> PASS; local audit-mini smoke wrote manifest, chunk, aggregate, and
  report artifacts with the binomial row recorded as true
  `binomial_probit`. Tiny-run non-PD diagnostics were not promoted.
- `git diff --check`
  -> PASS.
- `Rscript --vanilla /Users/z3437171/shinichi-brain/tools/check-after-task.R docs/dev-log/after-task/2026-06-24-true-binomial-probit-harness.md`
  -> PASS.

## 6. Tests of the Tests

The new report test directly exercises the corrected feature path:
`m3_sample_truth("binomial_probit")`, `m3_simulate_response()`, and one
`m3_run_cell(family = "binomial_probit", n_reps = 1, n_boot = 0, se =
FALSE)`. It checks the intended boundary condition that binary
`psi_effective` is zero and that simulated responses are 0/1.

The manifest tests check the metadata contract that would have failed
before this slice: audit-mini rows now identify `binomial_probit` as both
the harness and evidence family, with `link_harness = "probit"`.

The heavy grid-summary test is prophylactic and opt-in; it protects the
same truth/link/zero-binary-psi contract in the heavier M3 grid summary
path without making default local checks slow.

## 7. Consistency Audit

- `rg -n "All 5 families|binomial_logit_harness|There is no binomial\\(probit\\)|logit harness|DEFERS|not true binomial-probit|probit-link swap" dev tests docs/design/66-capstone-power-study.md`
  -> PASS; remaining hits are intentional historical-boundary notes for
  old result stores and pre-swap fir smoke artifacts.
- `rg -n "binomial_probit|link_harness|evidence_family|pnorm|plogis|stats::binomial\\(" dev/m3-grid.R dev/m3-pilot-launch.R dev/precompute-m3-grid.R tests/testthat/test-m3-pilot-manifest.R tests/testthat/test-m3-pilot-report.R docs/design/66-capstone-power-study.md`
  -> PASS; implementation, tests, and Design 66 show the current
  `pnorm()` DGP, probit fit, and true-probit manifest metadata.

## 8. Roadmap Tick

N/A. This removes a Phase-2 prerequisite from the Design 66 harness but
does not change a `ROADMAP.md` status chip or validation-register status.
`CI-08` and `CI-10` remain partial.

## 8a. GitHub Issue Ledger

- Issue #349, `[roadmap] Power-simulation capstone (power / accuracy /
  coverage)`, was inspected. This slice advances the 66.4
  binomial-probit prerequisite but does not complete the capstone.
- Issue #346, `[roadmap] Simulation / coverage framework`, was inspected.
  No row moves in this PR.
- Issue #340, `Capability matrix -- live status board`, was inspected.
  The board boundary still applies: pilot outputs are diagnostic and
  `CI-08` / `CI-10` remain partial.

No issue was closed. No new issue was created because this PR is a
bounded prerequisite for already tracked Design 66 / issue #349 work.

## 9. What Did Not Go Smoothly

The main subtlety was not the probit implementation; it was preserving the
old evidence boundary. Design 66 and the pilot-launch comment now separate
current true-probit runs from pre-swap `binomial_logit_harness` artifacts.

The local one-rep smoke still surfaced non-PD diagnostics for the
binomial-probit and nbinom2 tiny cells. That is expected at this scale and
is recorded only as smoke output, not validation evidence.

## 10. Team Learning (per AGENTS.md Standing Review Roles)

Ada: keep the slice at the exact prerequisite. The branch changes the
pilot harness and evidence labels, not the production grid or validation
register.

Curie: the simulation target now matches the locked core family label.
The direct one-rep test is small but exercises DGP, response support,
binary residual handling, and the fit call.

Fisher: no coverage, power, Type-I, or CI adjudication follows from this
patch. `CI-08` and `CI-10` stay partial until n_sim evidence exists.

Grace: the smoke run proves the corrected harness can travel through the
existing audit-mini wrapper locally. DRAC submission is deliberately left
for a later scheduled-compute slice after the PR is reviewed.

Rose: the historical wording is now doing useful work. Old fir smoke
artifacts remain labelled as logit-harness scheduler evidence rather than
being silently upgraded.

Shannon: the work stayed in the clean `/private/tmp` worktree and did not
stage or clean the dirty Dropbox mission-control checkout.

## 11. Known Limitations And Next Actions

- No DRAC job was submitted in this slice.
- No production `n_sim = 2000` campaign was launched.
- No GPU work was started.
- No validation-debt row changed; `CI-08` and `CI-10` remain partial.
- Ordinal-probit primary interval coverage is still unresolved.
- Old `binomial_logit_harness` artifacts remain historical smoke evidence
  only.

Next, after this PR is reviewed and merged, rerun the CPU-only audit-mini
smoke on fir with the true probit harness before using any
binomial-probit output in the larger core-grid ladder.
