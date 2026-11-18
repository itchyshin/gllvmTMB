# After Task: retained temporal--phylogenetic DRAC recovery completion

## 1. Goal

Complete the predeclared 22 missing Fir DRAC recovery tasks for the replicated
AR1 `temporal_indep()` plus fixed `phylo_indep()` cell, retain every receipt,
and evaluate the unchanged 30-cell recovery gate.

## 2. Implemented

The remote runner now retains a one-row receipt even when package loading fails,
binds the exported provider helpers when it uses an installed package, and
normalizes the collector's ledger keys before strict comparison. Fir job
`59096255` completed the 22 missing tasks. The combined 30-cell gate is
retained as failed: all fits reached terminal success, but the strict
optimizer-gradient rule fails in three cells.

## 3a. Decisions and Rejected Alternatives

**Decision**: retain the completed 30-cell recovery campaign as a failed gate.
**Rationale**: three outer gradients exceed the frozen `1e-3` criterion despite
terminal optimizer success, so the stated gate is not met.
**Rejected alternative**: relaxing thresholds, replacing seeds, or rerunning the
same campaign as evidence; each would invalidate the prespecified acceptance
ledger.
**Confidence**: high.

### Mathematical Contract

The fitted covariance remains the additive independent-process model

\[
V = K_T \otimes \operatorname{diag}(v_T) + K_P \otimes
\operatorname{diag}(v_P) + V_B + V_W + D_\epsilon,
\]

where (K_T(t,s)=\phi^{|t-s|}) for the replicated AR1 temporal term and
(K_P) is the fixed labelled phylogenetic covariance. The recovery gate accepts
only terminal success, convergence code zero, accepted second pass, and maximum
outer gradient at most `1e-3`, then applies its frozen error thresholds. No
model equation, fixture, seed, threshold, or estimator setting changed here.

## 4. Files Touched

- `dev/temporal-program/remote/phylo-recovery-common.R`
- `dev/temporal-program/remote/phylo-recovery-task.R`
- `dev/temporal-program/remote/phylo-recovery-drac.sh`
- `dev/temporal-program/remote/prepare-phylo-recovery-runtime.sh`
- `dev/temporal-program/remote/collect-phylo-recovery.R`
- `dev/temporal-program/results/failed/phylo-recovery-160-fir-59096255-20260910/`
- `dev/temporal-program/PLAN.md`, `dev/temporal-program/RESUME.md`, and
  `docs/design/35-validation-debt-register.md`

No reader-facing example, roxygen block, generated Rd file, vignette, README,
NEWS entry, or pkgdown configuration changed.

## 5. Checks Run

- Fir runtime build job `59095436`: completed in 1:50 and emitted the installed
  package load receipt for source `54fb7b089`.
- Fir one-cell preflight `59095720`: completed with the same objective and
  reported parameters as the retained Totoro rehearsal to floating-point
  precision.
- Fir array `59096255`: all 22 workers completed; all 22 one-row receipts are
  retained locally and on Fir.
- `Rscript --vanilla dev/temporal-program/verify.R remote`:
  `TEMPORAL_PROGRAM_REMOTE_PASS`.
- `Rscript --vanilla dev/temporal-program/verify.R self-test`:
  `TEMPORAL_PROGRAM_SELF_TEST_PASS`.
- The retained-result audit verified 30 unique cells, 30 terminal successes,
  summary passes `TRUE, FALSE, FALSE`, and exactly three gradients above
  `1e-3`.
- The actual collector run stopped with its intended frozen-threshold failure;
  its 30-row receipt and three-row summary were retained before stopping.
- `check-after-task.R` accepted this report's structure. Its full-ledger check
  remains intentionally unmet: `.unlazy/temporal-program/GATES.md` reports G2
  (platform/publication), G3 (every source pair), and G5 (closeout) unchecked.

No full package check, pkgdown check, article render, or documentation
generation was rerun: this phase did not alter package likelihood code,
formula grammar, user-facing help, or articles.

## 6. Tests of the Tests

The exact 22 Fir receipts first reproduced the collector failure before the
fix. The values formed the complete 30-cell grid, but `identical()` compared
row names and `expand.grid()` metadata as well as keys. A temporary copy with
only gradients set to zero then emitted `TEMPORAL_PHYLO_COLLECTION_PASS` after
the collector normalization; the retained real receipts were never altered.
The remote verifier also checks missing task receipts and an invalid package
loader, both of which must fail while retaining evidence.

## 7. Roadmap Tick

N/A: this operational recovery phase changes no `ROADMAP.md` row or progress
chip; it reconciles the existing TEMP-06-03 partial evidence row.

## 7a. Issue Ledger

No issue was inspected, commented on, closed, or created. `gh pr list --state
open` could not connect to the GitHub API during the required collision check,
and this local-only recovery result does not justify a new external issue.

## 8. Consistency Audit

Ran exactly:

```sh
rg -n '8/30 checkpoints|remaining 22|needs compute approval|Phylogenetic result in progress|separately in progress|has not passed its retained recovery gate' dev/temporal-program docs/design/35-validation-debt-register.md
```

It returned no stale current-state wording. `TEMP-06-03` now points to the
retained Fir result and remains `partial`. Historical check-log entries remain
unchanged because they were accurate when written.

## 9. What Did Not Go Smoothly

The first DRAC array used `pkgload::load_all()` and failed before producing
receipts; all 22 scheduler logs were retained. The first installed-runtime
retry correctly retained 22 error receipts because formula evaluation could
not find `temporal_indep()`. The loader now explicitly binds exported helpers.
The completed array fit successfully, but recovery failed solely because three
outer gradients exceeded the predeclared strict limit. The collector initially
misclassified the complete ledger because it compared irrelevant data-frame
metadata; this was reproduced and repaired without touching model results.

## 11. Team Learning

No likelihood or formula-grammar change occurred, so Gauss and Boole review was
not re-run for this operational phase. The next optimizer-qualification slice
must have an independent numerical review before changing controls or the
estimator. The runner should always bind formula helpers explicitly when a
remote task uses an installed package rather than source loading.

## 10. Known Residuals

TEMP-06-03 remains a bounded Gaussian identity-link, replicated AR1,
diagonal-trait-variance, fixed-phylogeny cell. Its recovery gate failed; it
does not support a recovery, coverage, cross-platform, merge, or release claim.
OU, temporal `dep`/`latent`, other source pairs, forecasts with a source pair,
and generic interval/profile/selection/bootstrap routes remain unavailable.
The enclosing temporal programme has unmet G2, G3, and G5 gates and remains
active; this phase report does not close that programme.

## 12. Cross-Product Coverage

This operational recovery phase does NOT cover a change to the likelihood,
formula grammar, family support, ordinary or structured provider behavior,
forecasting, intervals, profiles, bootstrap, selection, simulation, or any
cross-platform route. It only covers the remote receipt/collection mechanism
and the retained result for one replicated AR1 temporal--phylogenetic cell.

### Next Actions

Do not rerun or relax the retained phylogenetic campaign. If the program seeks
admission evidence, first design and independently review a separate optimizer
qualification with an immutable fixture and pre-run gate. Continue the wider
temporal programme through its other separately contracted gates; do not merge,
push, or release this branch.
