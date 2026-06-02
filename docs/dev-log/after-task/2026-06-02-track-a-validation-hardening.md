# After Task: Track A Validation Hardening

**Branch**: `codex/crossed-recovery-fg11`
**Date**: `2026-06-02`
**Roles (engaged)**: `Ada / Boole / Fisher / Curie / Rose / Grace / Shannon`

## 1. Goal

Close or sync the first four requested Track A items without touching the
rotation, coevolution, likelihood, or formula-grammar lanes: ship the crossed
ordinary random-intercept recovery slice; sync the already-present poisson and
NB2 glmmTMB cross-package fixtures into the register/audit; and add a
deterministic in-fit `TMB::sdreport()` failure fixture for `DIA-09`.

## 2. Implemented

- Added a balanced Gaussian recovery cell for ordinary scalar
  `(1 | site) + (1 | year)` random intercepts.
- Synced `FAM-06` and `FAM-08` to existing cross-package fixtures:
  `test-crosspkg-poisson-glmmTMB.R` and `test-crosspkg-nbinom2-glmmTMB.R`.
- Added an in-fit `TMB::sdreport()` failure fixture that forces the
  namespaced `TMB::sdreport()` call to error during `gllvmTMB()`
  construction, then checks the returned fit and diagnostics.
- Moved `FG-11`, `RE-05`, and `DIA-09` to `covered` in the validation-debt
  register and checked off `GAP-A1`, `GAP-A2`, `GAP-A5`, and `GAP-A6` in the
  audit tracker.

## 3. Files Changed

- `tests/testthat/test-multi-random-intercepts.R`
- `tests/testthat/test-sanity-multi.R`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/audits/2026-06-01-slopes-dependence-family-completeness.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-02-track-a-validation-hardening.md`

No roxygen, Rd, README, NEWS, pkgdown navigation, formula grammar, or TMB
source file changed.

## 3a. Decisions and Rejected Alternatives

Decision: close `FG-11` / `RE-05` only for ordinary scalar crossed random
intercepts. Rationale: `parse_re_int_call()` intentionally rejects random
slopes such as `(0 + trait | study)`, while the ordinary `(1 | group)` engine
packs multiple terms into `u_re_int` with per-term offsets. Rejected
alternative: advertising `(0+trait | site) + (0+trait | year)` as ordinary
crossed random-effect coverage. That syntax is a random-slope shape here and
still fails loud by design.

Decision: treat `GAP-A1` and `GAP-A2` as stale-status syncs, not new fixture
work. Rationale: `test-crosspkg-poisson-glmmTMB.R` and
`test-crosspkg-nbinom2-glmmTMB.R` already exist on main via commit `41d80e3`;
duplicating them would add churn without new evidence.

Decision: use `testthat::with_mocked_bindings()` for `DIA-09`. Rationale: it
exercises the real `gllvmTMB()` fit-construction try/catch path while making
the `TMB::sdreport()` failure deterministic. Rejected alternative: hunting for
a numerically broken model, which would be slower and more platform-sensitive.

## 4. Checks Run

- `git -C "/Users/z3437171/Dropbox/Github Local/gllvmTMB" status --short --branch`
  -> original checkout was dirty on `docs/coev-kernel-article`; no edits were
  made there.
- `git -C /private/tmp/gllvmtmb-crossed-re status --short --branch`
  -> side worktree was clean before edits on `codex/crossed-recovery-fg11`.
- `air format tests/testthat/test-multi-random-intercepts.R`
  -> exited 0; unrelated formatter churn outside the new test was manually
  trimmed back.
- `air format tests/testthat/test-sanity-multi.R`
  -> exited 0.
- Exploratory crossed-RE fixture calibration with
  `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); ...'`
  -> both candidate balanced fixtures converged; the smaller
  `20 site x 16 year x 3 trait x 2 rep` fixture was kept.
- Exploratory `DIA-09` mock check with
  `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); library(testthat); ... with_mocked_bindings(..., .package = "TMB") ...'`
  -> fit convergence 0, `sd_report` NULL, `sdreport_error` recorded,
  `fit_health$sdreport_ok = FALSE`, and `check_gllvmTMB()` returned WARN for
  `sdreport`.
- `Rscript --vanilla -e 'devtools::test(filter = "multi-random-intercepts")'`
  -> `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 35 ]` in 5.0 seconds.
- `Rscript --vanilla -e 'devtools::test(filter = "multi-random-intercepts|sanity-multi|crosspkg-poisson-glmmTMB|crosspkg-nbinom2-glmmTMB")'`
  -> `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 84 ]` in 11.7 seconds.
- `git diff --check`
  -> clean.
- `gh issue list --repo itchyshin/gllvmTMB --state open --search "crossed random effects" --limit 20 --json number,title,url`
  -> `[]`.
- `gh issue list --repo itchyshin/gllvmTMB --state open --search "FG-11 RE-05" --limit 20 --json number,title,url`
  -> issue #340, "Capability matrix -- live status board".
- `gh issue view 340 --repo itchyshin/gllvmTMB --json number,title,state,url,body,updatedAt`
  -> #340 is the open capability status board; no comment posted because this
  branch is local and unmerged.
- `rg -n "FAM-06|FAM-08|DIA-09|FG-11|RE-05|GAP-A1|GAP-A2|GAP-A5|GAP-A6|crosspkg|sdreport\\(\\).*failure|random slopes remain|cluster2" docs/design/35-validation-debt-register.md docs/dev-log/audits/2026-06-01-slopes-dependence-family-completeness.md tests/testthat/test-multi-random-intercepts.R tests/testthat/test-sanity-multi.R tests/testthat/test-crosspkg-poisson-glmmTMB.R tests/testthat/test-crosspkg-nbinom2-glmmTMB.R`
  -> expected updated register, audit, cross-package fixture, diagnostic
  fixture, `cluster2`, and test hits.
- `rg -n "FAM-06.*\\*\\*N\\*\\*|FAM-08.*\\*\\*N\\*\\*|DIA-09.*partial|FG-11.*partial|RE-05.*partial|GAP-A1.*\\[ \\]|GAP-A2.*\\[ \\]|GAP-A5.*\\[ \\]|GAP-A6.*\\[ \\]|crossed random effects.*smoke only|currently smoke|\\(0\\+trait\\|site\\).*\\(0\\+trait\\|year\\)" docs/design/35-validation-debt-register.md docs/dev-log/audits/2026-06-01-slopes-dependence-family-completeness.md`
  -> no matches.

## 5. Tests Of The Tests

The crossed-RE test is a deterministic balanced recovery cell. It asserts
parser / metadata shape (`groups`, `n_groups`, `offsets`), convergence, two
recovered variance components, and packed BLUP-slice correlation with the true
simulated site and year effects.

The `DIA-09` test is a deterministic in-fit failure fixture. It proves the
`tryCatch(TMB::sdreport(...))` branch returns a usable fitted object rather
than crashing, and that downstream diagnostics surface the failure as WARN.

`GAP-A1` and `GAP-A2` were already implemented by existing tests, so this
branch verifies and registers them rather than adding duplicate tests.

## 6. Consistency Audit

`FG-11`, `RE-05`, and `GAP-A5` now agree that ordinary scalar crossed random
intercepts are covered. The same files explicitly keep random slopes out of
this claim and point trait-specific crossed diagonal grouping to `RE-11` /
`cluster2`.

`FAM-06`, `FAM-08`, `GAP-A1`, and `GAP-A2` now agree that the poisson and
NB2 glmmTMB light fixtures are present. `DIA-09` and `GAP-A6` now agree that
both forced degraded-object diagnostics and in-fit `sdreport()` failure
handling are covered.

## 7. Roadmap Tick

N/A. This was a validation-debt register and audit-tracker tick, not a
ROADMAP change.

## 7a. GitHub Issue Ledger

Inspected issue #340, "Capability matrix -- live status board". Search for
`crossed random effects` returned no direct issue; search for `FG-11 RE-05`
returned #340. No issue comment or issue-body edit was posted because this
branch is still local and not merged. Once the branch is pushed / merged, #340
should be refreshed from `docs/design/35-validation-debt-register.md`.

## 8. What Did Not Go Smoothly

The audit's close-gate wording named `(0+trait | site) + (0+trait | year)`,
but that is not an ordinary random-intercept syntax in the current parser.
The branch corrected the wording instead of adding unsupported random-slope
claims to `FG-11` / `RE-05`.

The audit also listed poisson and NB2 cross-package fixtures as missing even
though the files were already on main. This branch treats that as stale status
and records the existing evidence path.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Ada: keep the slice bounded to Track A validation and avoid the active
coevolution branch.

Boole: the formula surface remains unchanged; ordinary `(1 | group)` crossed
terms are distinct from unsupported random-slope syntax.

Fisher / Curie: useful evidence here is targeted: variance-component recovery,
cross-package parameter agreement, and deterministic diagnostic failure
handling.

Rose: the register, audit tracker, and stale wording scan now agree on the
closed Track A rows and the remaining Track B limits.

Grace: targeted `testthat` and `git diff --check` passed. Full
`devtools::test()`, `devtools::check()`, and 3-OS CI remain PR / merge gates.

Shannon: original checkout dirt was left untouched; this branch is isolated
from the coevolution article lane.

## 10. Known Limitations And Next Actions

This does not implement or validate ordinary random slopes. It does not change
likelihood code, parser grammar, roxygen, or user-facing examples. Full
Definition-of-Done remains incomplete until the branch is merged and 3-OS CI
passes on `main`.

The remaining Track A item in this audit is `GAP-A7` register/capability
freeze. The remaining high-leverage open work is Track B: the non-Gaussian
unstructured-slope identifiability cluster and the failing CI coverage gates.
