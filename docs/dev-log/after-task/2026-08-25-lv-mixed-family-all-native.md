# After Task: Family-Wide Mixed-Family Predictor-Informed LV

Status: **REVIEW REPAIRS IN PROGRESS — all three retained campaigns are
adjudicated; final frozen-diff review found bounded defects that are being
repaired before exact-head verification and landing.**

## 1. Goal

Make ordinary native-TMB
`latent(..., d = 1, unique = FALSE, lv = ~ x)` available for an exact,
source-pinned family-wide set of pure and named mixed-response cells. Each
admitted cell must preserve the rotation-invariant scientific target
`B_lv = Lambda alpha^T`, retain all recovery and interval denominators, and
state inference limits without implying arbitrary mixtures or the broader
Design 73 surface are complete.

## 2. Implemented

### Mathematical contract

The bounded programme uses

\[
x_i \sim N(0,1), \qquad
u_i = \alpha x_i + e_i, \qquad e_i \sim N(0,1),
\]

\[
\eta_{it} = \beta_{0t} + \lambda_t u_i, \qquad
B_{lv,t} = \lambda_t\alpha, \qquad
\Sigma_{shared} = \Lambda\Lambda^\top.
\]

Every trait retains its registered likelihood, link, and nuisance block. Raw
`alpha`, raw `Lambda`, and signed score axes are not cross-fit targets. This
change is not support for rank above one, the default diagonal `Psi` companion,
response masks, missing or factor LV predictors, fixed `X + X_lv`, REML,
source-specific tiers, Julia, VA/AGHQ/MSPL, profile/bootstrap intervals, or
arbitrary family mixtures.

The R preflight now admits only the 19 pure routes and 19 named
mixed/sentinel routes frozen in `dev/mixed-lv-family-wide/00-manifest.R`.
The retained mixed/sentinel r200 evidence contains 3,800/3,800 attempts; all
optimizers converged, 3,789 attempts passed strict point eligibility, 11
gradient exclusions remain in the denominator, and all 19 point gates passed.
That campaign used `se = FALSE` and supports no interval conclusion.

The `traits(...)` wide preprocessor now maps a fully named mixed-family list
to the selected response columns using a collision-safe internal selector. It
does not override an explicit `family_var` attribute. A live Gaussian + Poisson
test proves ordered family IDs, labels, and `B_lv` estimates agree with the
same observations fitted in long form to tolerance `1e-8`.

The approved pure-family r200 retained all 3,800 attempts: 17/19 cells passed,
pure Beta was held at its frozen convergence gate (182/200), and pure
ordinal-probit was held at its shared-Sigma gate. The eight-archetype mixed
r500 retained all 4,000 attempts and 3,999 interval-eligible fits; every named
cell passed target-wise `B_lv` Wald calibration, with coverage 0.920--0.966.
The one non-PD/CI-unavailable Gaussian + Gamma attempt remains in the
denominator. These results do not establish simultaneous all-target coverage
or calibration for arbitrary mixtures.

## 3a. Decisions and Rejected Alternatives

- **Decision**: admit an exact route allow-list, not arbitrary family
  combinations. **Rationale**: the retained manifest and evidence are
  cell-specific. **Rejected alternative**: removing the family guard for any
  combination. **Confidence**: high.
- **Decision**: use `B_lv` and `Lambda Lambda^T` as cross-fit targets.
  **Rationale**: they are invariant to the rank-1 sign choice. **Rejected
  alternative**: raw `alpha`, raw `Lambda`, or raw score comparisons.
  **Confidence**: high.
- **Decision**: keep pure-route point recovery and mixed-route Wald calibration
  as separate campaigns. **Rationale**: runtime admission, point recovery, and
  interval calibration answer different questions and use different
  denominators. **Rejected alternative**: borrowing mixed r200 evidence for
  pure routes or treating one-fit canaries as evidence. **Confidence**: high.
- **Decision**: map named wide-family lists only when their names exactly match
  the selected `traits(...)` columns and no explicit selector is supplied.
  **Rationale**: this is deterministic, collision-safe, and preserves explicit
  user intent. **Rejected alternative**: use list order or silently override a
  misspelled `family_var`. **Confidence**: high.
- **Decision**: preserve Design 73, FG-18, RE-13, and LV-05 as `partial`.
  **Rationale**: the programme remains rank-1, loadings-only, complete-response,
  named-cell, native-ML work. **Rejected alternative**: promote the umbrella LV
  surface. **Confidence**: high.

## 4. Files Touched

### Implementation and generated help

- `R/lv-predictor.R`
- `R/gllvmTMB.R`
- `R/traits-keyword.R`
- `R/brms-sugar.R`
- `man/latent.Rd`
- `man/traits.Rd`

### Tests and retained-campaign harness

- `tests/testthat/test-lv-family-boundary-guard.R`
- `tests/testthat/test-lv-native-nongaussian-guard.R`
- `tests/testthat/test-lv-mixed-family-first-cell.R`
- `tests/testthat/test-mixed-lv-family-harness.R`
- `dev/mixed-lv-family-wide/00-manifest.R`
- `dev/mixed-lv-family-wide/01-run.R`
- `dev/mixed-lv-family-wide/02-summarise.R`
- `dev/mixed-lv-family-wide/03-totoro-launch.sh`
- `dev/mixed-lv-family-wide/04-totoro-detached.sh`
- `dev/mixed-lv-family-wide/05-totoro-run.R`
- `dev/mixed-lv-family-wide/06-totoro-collect.R`

### Evidence and design/status cascade

- `docs/dev-log/artifacts/methods-superarc/lv-mixed-family-all-native-source-contract.md`
- `docs/dev-log/artifacts/methods-superarc/lv-mixed-family-all-native-recovery-cell-summary.csv`
- `docs/dev-log/artifacts/methods-superarc/lv-mixed-family-all-native-recovery-target-summary.csv`
- `docs/dev-log/artifacts/methods-superarc/lv-mixed-family-all-native-recovery-gate-verdicts.csv`
- `docs/dev-log/artifacts/methods-superarc/lv-mixed-family-all-native-recovery-raw-sha256.txt`
- `docs/dev-log/artifacts/methods-superarc/lv-mixed-family-all-native-pure-recovery-cell-summary.csv`
- `docs/dev-log/artifacts/methods-superarc/lv-mixed-family-all-native-pure-recovery-target-summary.csv`
- `docs/dev-log/artifacts/methods-superarc/lv-mixed-family-all-native-pure-recovery-gate-verdicts.csv`
- `docs/dev-log/artifacts/methods-superarc/lv-mixed-family-all-native-pure-recovery-raw-sha256.txt`
- `docs/dev-log/artifacts/methods-superarc/lv-mixed-family-all-native-calibration-cell-summary.csv`
- `docs/dev-log/artifacts/methods-superarc/lv-mixed-family-all-native-calibration-target-summary.csv`
- `docs/dev-log/artifacts/methods-superarc/lv-mixed-family-all-native-calibration-gate-verdicts.csv`
- `docs/dev-log/artifacts/methods-superarc/lv-mixed-family-all-native-calibration-raw-sha256.txt`
- `docs/design/02-family-registry.md`
- `docs/design/01-formula-grammar.md`
- `docs/design/03-likelihoods.md`
- `docs/design/05-testing-strategy.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/57-mixed-family-link-residual.md`
- `docs/design/61-capability-status.md`
- `docs/design/73-predictor-informed-latent-scores.md`

### Reader path and coordination

- `vignettes/articles/explaining-latent-ecological-axes.Rmd`
- `docs/dev-log/plans/2026-08-25-lv-mixed-family-all-native-ultra-plan.md`
- `docs/dev-log/after-task/2026-08-25-lv-mixed-family-all-native.md`
- `docs/dev-log/plan-actual/2026-08-25-lv-mixed-family-all-native.md`
- `docs/dev-log/handover/2026-08-25-lv-mixed-family-all-native.md`

`README.md`, `ROADMAP.md`, `_pkgdown.yml`, `AGENTS.md`, `CLAUDE.md`,
`NAMESPACE`, `src/gllvmTMB.cpp`, and Design 76 were inspected or classified as
unchanged. `NEWS.md` and `docs/dev-log/check-log.md` were released to the
interval-calibration lane and are not edited in this draft.

## 5. Checks Run

Completed checks:

- Source/harness identity, shell syntax, and R parse checks: passed for final
  source bundle SHA-256
  `d295bf14cae6e26036107f181bd2b3ff407303f783122c5127c7eb2da61dcd02`
  at source HEAD `7dd5eec733c42c722fe94be4c0e5a2efe1f4a3c3`.
- Final pure non-evidence pre-run: 19/19 returned, converged, and point-eligible;
  zero warnings; 26.96787 seconds.
- Final calibration non-evidence pre-run: 8/8 returned, converged, had
  positive-definite Hessians, and were interval-eligible; zero warnings;
  17.56942 seconds.
- Focused mixed-LV and complete `lv-` test batches: passed.
- `NOT_CRAN=true Rscript --vanilla -e 'devtools::test(reporter = "summary")'`:
  exit 0; testthat terminus `DONE`.
- Evaluated Tier-1 article render from development source: passed; the Gaussian
  + Poisson long/wide estimates were identical.
- Final post-campaign focused suite passed all four mixed-LV files, including
  the live long/wide equality fit and negative boundary controls. The first
  single-page rerender command, `pkgdown::build_article()` with the article
  slug, failed because pkgdown did not find this repository's nested
  `vignettes/articles/` page; the failure is retained. Direct evaluated
  `rmarkdown::render()` from development source then passed and wrote a
  non-empty HTML page. `pkgdown::check_pkgdown()` also passed.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`: passed.
- `Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE, error_on = "never")'`:
  20 minutes 56.6 seconds; 0 errors, 0 warnings, 4 explicit pre-existing or
  environment notes.
- `git diff --check`: passed after the final local edits.
- Independent retained-evidence recheck: `shasum -a 256 -c` verified all
  7,622 entries in the mixed/sentinel raw/source manifest. Direct CSV reads
  recovered 19 cell rows, 166 target rows, 19 gate rows, 3,800 planned and
  attempted fits, 3,800 convergences, 3,789 point-eligible fits, zero
  interval-eligible fits, and 19/19 point verdicts `TRUE`; every interval and
  calibration verdict remained `NA` as required by `se = FALSE`.
- Independent pure-campaign recheck verified all 7,607 raw/source/receipt
  entries. Direct summaries recovered 3,800 planned, started, and final rows;
  3,770 converged and 3,762 were point-eligible. Frozen point verdicts were
  17 PASS and two HOLD, with no retry or threshold change.
- Independent calibration-campaign recheck verified all 8,007 raw/source/
  receipt entries. Direct summaries recovered 4,000 planned, started, and
  final rows; all converged and were point-eligible, 3,999 were interval-
  eligible, and all eight cell verdicts passed. The 71 total target-summary
  rows contain 17 distinct `B_lv` rows and 8,498 eligible `B_lv` intervals;
  their coverage was 0.920--0.966 with MCSE 0.0081--0.0121.
- Overnight fail-closed Totoro watch: 285/285 probes of the exact existing
  ControlMaster socket returned `Operation not permitted` between
  `2026-08-26T06:20:22Z` and `2026-08-26T11:06:52Z`. The operator exited 72,
  issued zero remote commands, started zero fits, and produced no results
  bundle. Its log SHA-256 is
  `5a3debc8f7bcca2ba93c48ff00bbed8dfa6b01a4f36b7c6a73735a4f2f0b4d75`.

Still required before closure: affected focused reruns, final `--reverify`,
the frozen-candidate completion panel, final local landing checks, and the
closeout validators.

The first frozen completion panel returned `FAIL`. Gauss/Emmy found that an
explicit ordinary unit-tier `indep()` or compatibility `unique()` companion
bypassed the programme's loadings-only guard, and that the harness test
incorrectly required the final checkout HEAD to equal the historical campaign
HEAD. Rose/Grace additionally found the r200/v4 source wording contradictory
and the files-touched inventory incomplete. Test-first repairs now reject both
explicit diagonal spellings, validate the retained campaign identity against
its recorded HEAD and hashes rather than the current checkout, distinguish the
r200 dirty snapshot from the clean v4 pure/calibration source, and enumerate
all candidate files. The final exact-head package check started before these
findings was deliberately interrupted and is retained as a failed verification
attempt; it will be rerun only after the repaired candidate is frozen.

Noether/Fisher then identified three further fail-open combinations: the
programme accepted factor, transformed, or multi-column LV designs; a single
Gaussian/binomial fit could mix more than one binomial link; and unrelated
covariance terms could coexist with the evidence-bearing LV block. Five new
negative tests failed on the pre-repair candidate and now pass. Programme cells
require exactly one untransformed numeric unit predictor, one binomial link per
fit, and the predictor-informed latent block as the only covariance term.
Their final sweep then found that a matrix-valued numeric column could bypass
the syntactic one-predictor check, and that the single-link fence did not cover
the pre-existing pure-binomial C1 route. Both new negative controls failed on
the pre-repair candidate and pass after the raw-column/model-matrix and
pure-binomial link repairs. A proposed duplicate within-trait route check was
not added because the public fit path already rejects that condition in the
ordinary family-scale validator.

## 6. Tests of the Tests

- Failure-before-fix: the wide mixed-family equality test first failed because
  `traits()` supplied no family selector; it would catch the original reader
  route defect.
- Failure-before-fix and boundary: an unrelated ambient `family` column first
  collided with the internal selector; its regression test proves the generated
  selector is collision-safe.
- Failure-before-fix and boundary: an explicit misspelled selector was first
  silently overridden; its regression test now proves explicit user intent
  fails loudly.
- Boundary: default `Psi`, rank 2, incomplete responses, noncanonical links,
  multiple binomial links (including pure-binomial C1),
  factor/transformed/multi-column and matrix-valued LV designs, extra
  covariance tiers, arbitrary family combinations, changed source/harness
  hashes, incomplete denominators, and all-failure cells each have rejection
  or conservative verdict tests.
- Feature combination: the live long/wide test combines predictor-informed LV,
  mixed Gaussian/Poisson families, `traits()` sugar, extraction, family labels,
  and equality of `B_lv` estimates.
- Prophylactic invariant tests: immutable seed/grid sizes, disjoint campaign
  seeds, watchdog process-group termination, point/interval denominator
  separation, inclusive coverage boundaries, and MCSE formulas protect the
  preregistered evidence contract.

## 7. Roadmap Tick

N/A. No `ROADMAP.md` row changes; Design 73 remains partial.

## 7a. Issue Ledger

No issue has been created, closed, or commented by this lane. No push, PR,
merge, release, or public capability
announcement is authorized by this local lane.

## 8. Consistency Audit

Completed exact scans and verdicts:

- The exact command below found no stale universal native-family rejection
  after correcting FG-18 and RE-13:

  ```sh
  rg -n 'native count-family `lv` support|native non-binomial/ordinal/mixed-family support|unsupported native non-Gaussian families|ordinal/mixed-family rows' docs/design/35-validation-debt-register.md
  ```
- `rg -n '\b(FG|LV|FAM|MIX)-[0-9]+' vignettes/articles/explaining-latent-ecological-axes.Rmd`
  — no internal validation-row ID appears on the reader page.
- Added-line scan for `all arbitrary|any arbitrary|every possible mixed|all mixed families (are|have) calibrated|profile intervals are supported|bootstrap intervals are supported|REML is supported for predictor-informed|rank [2-9].*family-wide`
  — no broad capability claim was added.
- Final scans require the two pure HOLDs, the eight named target-wise Wald
  cells, and the arbitrary-mixture boundary to agree across Design 35, 61, 73,
  the source contract, and the public article.

The final campaign-specific status scans remain to run after their verdicts
are known; the current changed-surface prose and rendered-Rd audits are green.

Prose review found no filler phrases, legacy `S_B`/`S_W` notation, deprecated
aliases, public register IDs, raw-axis teaching, or unsupported broad claim in
the changed reader path. Both long-format calls explicitly name `trait`; both
wide calls use `traits(...)`. The changed `man/latent.Rd` and `man/traits.Rd`
files end with balanced closing braces and contain zero `\\keyword{}` entries,
matching their roxygen sources (neither source declares a keyword tag).

Rose pre-publish verdict: **PASS for the current repository contract**. Source
formals confirm ordinary `latent()` defaults to `unique = TRUE`,
`extract_lv_effects()` defaults to axis output and offers Wald/profile/bootstrap
methods, the article explicitly requests the covered Wald or point-only routes,
and its long calls name `trait` while wide calls use `traits(...)`. There is no
export or article add/remove/rename, pkgdown already links the article, and the
plain-language boundary maps internally to partial FG-18 / RE-13 / LV-05 rows.
The first source-formal scan named a nonexistent `R/control.R`; because the
command was piped to `head` without `pipefail`, later checks continued. That
failed path is retained here and was not used as evidence.

## 9. What Did Not Go Smoothly

- The managed Codex sandbox repeatedly refused access to the existing Totoro
  ControlMaster socket with `Operation not permitted`; DNS fallback is also
  disabled. A full overnight operator retained 285/285 denied probes and
  issued no remote command. A later explicitly approved escalated attachment
  succeeded.
- The first approved operator invocation failed before any fit because its
  `nohup` redirection target directory did not yet exist. After that directory
  was created, the first remote source extraction also failed before any fit:
  the macOS source archive contained 4,636 AppleDouble `._*` files and the
  Linux build attempted to compile `._gllvmTMB.cpp`. Both zero-attempt failures
  and their logs remain preserved. A second source-identical extraction removed
  only `._*` metadata files, passed the exact seven-file source manifest, and
  produced the retained campaigns. The original archive was not changed.
- The shared lease registry is outside the writable sandbox. Renewal printed a
  grant after its collision check but could not persist the lease file. The
  lane therefore relied on repeated live-census checks and exact disjoint paths.
- Failed development attempts were retained: malformed shell escaping,
  unsupported per-cell wide weights, the three TDD reader-route defects, an
  invalid test-only optimizer method, a stale installed-package article render,
  two intentional source-manifest refusals, output-overwrite refusals, an
  obsolete-candidate full-test run interrupted before final verification, and
  one misquoted stale-scan pattern.
- A repeated-staleness sweep found FG-18 and RE-13 had not moved with LV-05.
  The corrected rows preserve partial status and the exact evidence boundary.
- The status-inventory sweep then found the same universal-rejection wording
  in canonical Design 01. GitHub PR lookup was network-blocked, but all-ref
  six-hour path history showed no recent edit and the live lease census showed
  no overlap. The row and detailed grammar section now describe the exact
  family-wide allow-list while retaining `partial` status and all exclusions.
- The project-local prose skill itself contains a stale sentence saying
  standalone ordinary `latent()` is loadings-only. Current AGENTS.md, source,
  help, Design 01, and the article agree that ordinary `latent()` includes
  `Psi` by default and `unique = FALSE` selects loadings-only. The lane followed
  the current repository contract and records the skill sentence as a future
  maintenance item; it did not edit the skill inside this capability change.
- The Rose pre-publish skill also carries older project contracts: it calls the
  keyword surface 4 x 5 instead of the canonical 5 x 3 grid, says every delta
  mixed-family route is blocked despite the current source-pinned shared-eta
  contract, and asks for internal register IDs on public pages despite the
  reconciled AGENTS.md plain-language rule. The audit followed current
  AGENTS.md, source, register, and Design 01/02/03/57 instead. These skill
  discrepancies are maintenance findings, not reasons to corrupt current
  public prose.
- Shannon coordination verdict: **WARN, safe to continue on exact paths**.
  The dirty tree belongs to `codex/lv-mixed-family-all-native`; the only live
  persisted lease is the disjoint random-slope lane. GitHub PR/run census was
  network-blocked. Three recent interval-calibration commits touched shared
  status files, but an exact `HEAD..origin/main` comparison showed this branch's
  committed tree already contains their design/register/NEWS state; only the
  append-only `docs/dev-log/check-log.md` differs upstream, and this draft does
  not edit it. Final integration must preserve that 84-line upstream append.

## 10. Known Residuals

- **HOLD**: pure Beta point recovery did not meet its frozen convergence gate.
  The 18 failed/nonconverged attempts remain retained; no threshold weakening
  or retry campaign is part of this closeout.
- **HOLD**: pure ordinal-probit point recovery did not meet its frozen shared-
  Sigma gate despite healthy `B_lv` targets. This closeout does not redefine
  the estimand or remove the Sigma oracle.
- Reconcile current `origin/main` without changing the campaign source receipt,
  then rerun affected tests, docs, pkgdown, local package checks, and exact-head
  CI as required by the final landing route.
- Run the final 2-Terra/1-Sol frozen-diff panel, Unlazy `--reverify`, after-task
  validator, Melissa plan-vs-actual, handoff gate, narrow local commit, clean
  tree proof, and lease release.
- Does **not** cover arbitrary mixtures, rank above one, default `+ Psi`, masks,
  missing/factor LV predictors, fixed `X + X_lv`, REML, source tiers, Julia,
  VA/AGHQ/MSPL, profile/bootstrap, simultaneous mixed-family interval coverage,
  or mixed-family interval calibration beyond the eight individually passing
  frozen archetypes.

## 11. Team Learning

**Ada** kept runtime admission, point recovery, and interval calibration as
separate gates and continued reversible local work while remote compute was
blocked.

**Jason** pinned current family IDs, links, nuisance blocks, implementation
routes, historical evidence, and the non-transfer boundary to current source.

**Gauss** checked that family-specific likelihood and nuisance blocks do not
change `u_i`, `B_lv`, or the shared loadings-only covariance contract; no C++
change was needed.

**Noether** confirmed that raw axes are invalid cross-fit targets and that the
long/wide reader example fits the same observations and estimand.

**Fisher** required independent attempted, point-eligible, interval-eligible,
non-PD, CI-unavailable, coverage, and MCSE denominators; those denominators now
support the eight target-wise calibration verdicts without a simultaneous-
coverage claim.

**Curie** designed immutable grids, disjoint seeds, all-attempt collection,
tests of the tests, and a hard 1,800-second campaign watchdog.

**Boole and Emmy** caught the `traits()` mixed-family selector gap, ambient
column collision, and explicit-selector precedence requirement.

**Pat** required a runnable long/wide Gaussian + Poisson reader path with
family/link-specific interpretation and no interval overclaim.

**Rose and Grace** found status-register drift, required the full local package
check, and kept remote access, lease degradation, notes, and landing state
explicit rather than treating local success as closure.

## 12. Cross-Product Coverage

This lane covers only native ordinary ML, rank-1, loadings-only
`latent(..., unique = FALSE, lv = ~ x)` with complete responses, one numeric
LV predictor, canonical links, the 19 preregistered pure routes, and the 19
preregistered named mixed/sentinel routes. Runtime admission and point recovery
are assessed separately from Wald calibration. The long and `traits(...)` wide
reader routes are checked on the same Gaussian + Poisson observations and the
rotation-invariant target `B_lv`.

It does NOT cover arbitrary family combinations, rank above one, ordinary
`latent()` with its default diagonal `Psi`, response masks, incomplete data,
factor or missing LV predictors, fixed `X + X_lv`, REML, source-specific or
kernel latent terms, Julia, VA, AGHQ, MSPL, profile or bootstrap intervals, or
Wald calibration outside an individually passing frozen archetype. The
umbrella Design 73, FG-18, RE-13, and LV-05 surfaces therefore remain partial;
blocked neighbouring cells remain blocked. No unsupported product-axis cell is
promoted by a passing one-axis route.
