# VA(GH) H=7 Arc 2 campaign scaffold readiness

## 1. Goal

Turn the frozen Design-110 Arc-2 campaign scaffold into a fail-closed,
revision-bound launch path for the 18 scalar family/link cells. This phase ends
at local readiness for the post-commit Totoro smoke; it does not claim a remote
fit, a recovery verdict, or calibrated uncertainty.

## 2. Implemented

The driver now validates canonical and singular CLI aliases, rejects unknown or
duplicate flags, requires `n >= 100`, and validates every loaded plan against
the ordered 18-cell registry. Gate-E DCF receipts bind the git revision, VA
template, repo-relative 18-cell CSV, row count, checksum, and ordered PASS set.
Runtime and preflight receipts bind that Gate receipt and each other.

The campaign forwards fixed Tweedie power 1.5 and Student df 5 through VA and
matched Laplace, scores q > 1 latent coordinates after orthogonal Procrustes
alignment, materialises missing plan tasks as scheduler failures, and reports
conditional recovery alongside explicit eligible counts. Failed/missing fits
remain in failure, availability, and unconditional-coverage denominators.

Totoro now has a synchronous one-row smoke gate. DRAC submission derives task
counts from the immutable plan, splits arrays into scheduler-sized batches,
uses offsets without changing task identity, keeps receipts/results/logs under
`/project`, and requires task 1's checksum-bound smoke bundle before broad
submission. Recognised DRAC hosts cannot compile or fit without a SLURM
allocation.

## 3a. Decisions and Rejected Alternatives

The campaign uses gllvmTMB's matched Laplace route as the primary comparator;
`gllvm` is not treated as ground truth. A plain-text PASS receipt was rejected
because it binds neither code nor evidence. Absolute paths inside Gate receipts
were rejected because they cannot move from local to Totoro/DRAC. Hard-coded
SLURM arrays were rejected because the 5,520-row Totoro plan and 36,000-row DRAC
plan have different geometries.

Design 110 section 6.1 predeclares separate family/rank verdicts. The 30-seed
Totoro stage is failure-finding and H-ladder evidence; the 500-seed DRAC stage
has coverage MCSE below 0.01. Fixed-effect VA-Wald and latent posterior-SD
calibration are classified separately from point recovery, so a calibration
failure cannot be hidden by a pooled package pass rate.

## 4. Files Touched

- `dev/va-gh-h7-campaign/run-cell.R`: plan, receipt, runtime, comparator,
  Procrustes, bundle-verification, summary, and portable Tweedie-DGP contracts.
- `dev/va-gh-h7-campaign/prepare-runtime.sh`: manifest-only preparation and
  DRAC allocation guard.
- `dev/va-gh-h7-campaign/run-preflight.sh`: new fit-running preflight boundary.
- `dev/va-gh-h7-campaign/launch-totoro.sh`: durable plan/run and one-row smoke.
- `dev/va-gh-h7-campaign/submit-drac.sh`: new plan-derived batched submission.
- `dev/va-gh-h7-campaign/drac-array.sbatch`: task-offset compute-node runner.
- `dev/va-gh-h7-campaign/README.md`: current ADEMP, MCSE, receipt, and launch
  instructions.
- `docs/design/110-va-gh-h7-all-scalar-families.md`: predeclared Arc-2 stages
  and family/rank verdict rules.
- `docs/dev-log/audits/2026-08-06-va-gh-h7-gate-e.csv`: machine-readable ordered
  Gate-E verdict derived from the reviewed audit.
- `tests/testthat/test-va-gh-h7-campaign.R`: pure campaign/launcher contracts.

No likelihood template, public R API, NAMESPACE, family constructor, README at
the package root, vignette, or generated help file changed.

## 5. Checks Run

```sh
NOT_CRAN=true Rscript --vanilla -e 'devtools::test(filter = "va-gh-h7-campaign", reporter = "summary", stop_on_failure = TRUE)'
# DONE; 0 failures, warnings, or skips.
Rscript --vanilla -e 'invisible(parse("dev/va-gh-h7-campaign/run-cell.R")); cat("parse ok\n")'
# PASS.
bash -n dev/va-gh-h7-campaign/prepare-runtime.sh dev/va-gh-h7-campaign/run-preflight.sh dev/va-gh-h7-campaign/launch-totoro.sh dev/va-gh-h7-campaign/drac-array.sbatch dev/va-gh-h7-campaign/submit-drac.sh
# PASS.
ACTION=dry-run bash dev/va-gh-h7-campaign/launch-totoro.sh
# PASS; one canonical binomial-logit VA task at n=120, H=7, q=2.
Rscript --vanilla dev/va-gh-h7-campaign/run-cell.R --mode=dry-run
# PASS; 5,520 tasks, zero nonzero-H Laplace or exact-VA rows.
git diff --check
# PASS.
```

Gauss also ran direct receipt portability, runtime/preflight provenance,
q=1/q=2/q=5 alignment, and missing-task denominator probes. Rose's final
read-only launch audit returned PASS.

## 6. Tests of the Tests

The dedicated suite began with six observed failures: undersized `n`, dropped
fixed Tweedie/Student metadata, conditional-only coverage, and q=2/q=5
sign-only alignment. Each now passes for the intended reason. The test sources
the driver in dry-run mode and mocks fit-heavy paths. It corrupts receipt
checksums, removes planned bundles, rotates latent coordinates, and inspects
shell launch contracts. It therefore exercises failure modes rather than only
the successful path.

## 7a. Issue Ledger

No duplicate issue was opened. Design 110 is the authoritative Arc-2 tracker.
Live GitHub PR state could not be refreshed because `api.github.com` was
unreachable; local recent history showed no foreign lane on this subject.

## 8. Consistency Audit

Scans confirmed no literal-PASS grep, fixed `#SBATCH --array`, `n=30`/`n=60`
launch default, stale "Gate E unrecorded" state, or login-node preflight route.
The README, Design 110, runner defaults, launcher defaults, and test geometry
agree on 5,520 Totoro rows and a later 36,000-row H=7 DRAC confirmation.

Gauss verified the statistical runner. Curie supplied the campaign-specific
test-first contract. Rose's first audit found the login-context bypass; after
the host/allocation guard and `/project` receipt hardening, her final verdict was
PASS for post-commit Totoro-smoke readiness.

## 9. What Did Not Go Smoothly

The inherited scaffold mixed a strong structured driver with launchers that
still grepped a plain PASS line, hard-coded 10,800 DRAC tasks, omitted runtime
receipts, defaulted to `n=60`, and could run timed preflight on a login node.
The first shell repair still trusted a caller-supplied `local` context; Rose
correctly demonstrated that this was bypassable. Host/allocation evidence now
controls the irreversible fit boundary.

The first Totoro runtime preparation then stopped because `tweedie` was absent
although the recommended package `mgcv` and its equivalent `rTweedie()` DGP
were installed. The runner now uses `tweedie::rtweedie()` when present and the
parameter-matched `mgcv::rTweedie(mu, p=1.5, phi=0.8)` fallback otherwise;
runtime preparation requires either package.

The rebuilt runtime then exposed a first-run ordering defect before either
timed preflight fit: the exported target receipt path made the initial
runtime-only verifier demand a receipt that the next command was responsible
for creating. The initial verifier now masks that one environment value; the
post-fit verifier continues to require and authenticate the full chain.

Once that verifier passed, the package loader exposed a second pre-fit defect:
`library(gllvmTMB, character.only = TRUE)` evaluated the unquoted package name
as an object. Supplying `"gllvmTMB"` gives `character.only = TRUE` the input it
requires. A dedicated regression assertion now protects this live-only path.

## 10. Known Residuals

A real Gate receipt and installed Totoro runtime were created for revision
`98f78567`; both remain valid historical evidence but cannot authorize the
corrected source revision. No timed preflight receipt, Totoro result bundle, or
DRAC job exists yet. The corrected revision therefore requires a newly bound
Gate receipt and runtime before the timed preflight is retried. The structured
family/rank adjudication thresholds are predeclared, but the final verdict
artifact will be produced only after campaign data exist. Cross-OS CI is not
evidence for this compute campaign and was not run.

## 11. Team Learning

Ada kept the receipt, runtime, smoke, and broad submission as separate evidence
boundaries. Gauss made statistical parity and provenance executable rather than
documentary. Curie's test-first failures exposed the exact runner gaps without
starting compute. Rose showed that a user-declared execution context is not an
allocation check; host and scheduler state must supply that fact.

The simulation-design review separated the 30-seed failure-finding stage from
the 500-seed coverage stage. The quantitative review kept point recovery,
fixed-effect VA-Wald calibration, and latent posterior-SD calibration as
distinct claims with replicate-level MCSE.

## 12. Cross-Product Coverage

This phase covers the campaign machinery for all 18 scalar family/link cells,
H in 5/7/9/15/61, q in 2/5, matched VA/Laplace fitting, fixed Tweedie/Student
metadata, plan-bound failures, Procrustes latent calibration, Totoro launch, and
batched DRAC launch. It does not cover multinomial/non-scalar likelihoods,
`unique = TRUE`, structured covariance tiers, random slopes, missing predictors,
actual multi-seed recovery, actual interval calibration, or remote-compute
success.
