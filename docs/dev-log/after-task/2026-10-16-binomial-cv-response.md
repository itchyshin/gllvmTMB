# After Task: Binomial response metadata and metrics in internal CV

Branch: codex/issue-1496-cv. Date:2026-10-16. Base:d8f3bbe4 (PR1507).

## 1. Goal

Repair the remaining cbind CV truth/null-refit defects in issue1496 and the associated Bernoulli-only metric assumptions. User approved the continuation; merging, releases, issue closure and Sage correspondence remain outside authorization.

## 2. Implemented and mathematical contract

No public API, formula grammar, native likelihood, family admission or export changed. Canonical matrix response R=(S,N-S) preserves the original observed trials and model-row order in the main fit and each null, with genuine single-column trial/likelihood weights forwarded. Current-fold predictions alone are scored; pre-existing missing responses are excluded. Data values/order and required fitted columns are checked before formula evaluation.

For valid grouped-binomial cells(S_i,N_i,p_i): LogScore=sum log dbinom(S_i,N_i,p_i); RMSE=sqrt(mean((S_i/N_i-p_i)^2)), equal-cell weighting. Brier=sum[S_i(1-p_i)^2+(N_i-S_i)p_i^2]/sum N_i. Tjur=sum(S_i p_i)/sum S_i - sum((N_i-S_i)p_i)/sum(N_i-S_i). AUC weights every positive/negative trial pair, counting ties as1/2; grouped accumulation avoids expanding large trial counts. The latter three equal literal Bernoulli expansion. Existing N=1 behavior is retained. Zero-total groups have no probability-metric contribution; this does not admit zero-trial fitted responses. Invalid count/probability inputs fail clearly. Unsupported family scoring remains NA. All densities remain conditional plug-in quantities, not marginal predictive densities or calibration evidence.

## 3. Files changed

R/cv-internal.R; R/cv-metrics.R; tests/testthat/test-cv-binomial-response.R; NEWS.md; dev/issue-1496/CV-RESULTS.md; this report; docs/dev-log/check-log.md. No NAMESPACE, man, native code, version, README, roadmap or public article change.

## 3a. Decisions and rejected alternatives

Reuse the bootstrap canonical-response helper rather than invert cbind expressions or mask their predictor inputs. Retain count densities rather than score counts as Bernoulli. Distinguish cell-proportion RMSE from per-trial Brier rather than silently call them equal. Use weighted tied-pair AUC rather than allocate one row per trial. Confidence: manual refit/trial-expansion oracles plus independent review; full-suite validation remains separate.

Prior work: complete issue1496, merged1495/aec24e1, bootstrap1507/d8f3bbe4, historical CV introduction ec83f469495e/PR900 and 2026-08-02 CV report. The historical contract explicitly deferred multi-trial scoring; no previous metric generalization was overwritten. Open PR census showed overlapping bootstrap1501 and phylogenetic1505 work, left untouched; no CV implementation PR was found. Existing isolated clone was reused on a new branch; unrelated untracked logs/artifacts preserved.

## 4. Checks run

Exact commands, environment, red counts and limitations: dev/issue-1496/CV-RESULTS.md. Affected heavy bootstrap run437 pass/0 fail/23 warning captures. Final source CV/encoding run308 pass/0 fail/error/warning/skip. roxygen/pkgdown, reader-surface, Actions-boundary, formatter and parser checks passed. No fresh local compiled package check because the configured compiler is license-gated. Exact-commit CI state will be in the draft PR.

## 5. Tests of the tests

Old-code regression execution produced20 failed assertions and2 errors. Manual references construct paired responses independently, refit each fold and all three nulls, evaluate dbinom with original N, and compare same-fold score deltas. Pure metric oracles literally expand trials and compare pairwise AUC including ties. Added boundaries cover shuffled data, missing predictors, endpoints, malformed counts, matrix truth, single-column trial weights, original missing cells, cbind inputs reused on RHS and stacked mixed-wide CV. Additional boundary tests are prophylactic, not falsely labelled individual red proofs.

## 6. Consistency audit

`rg -n 'out of scope|defaults to 1|only.*first|n_trials.*1|Bernoulli' R/cv-internal.R R/cv-metrics.R`: remaining matches document sentinels, Bernoulli defaults or the explicit grouped contract; obsolete first-column/multi-trial exclusions removed. Public status is unchanged: internal evidence harness only. Existing unknown/null-model health boundaries are not promoted. Internal changes add no public reference-page or article requirement; pkgdown check passed. No new validation-debt capability row claimed.

## 7. Roadmap tick

N/A: repair to an internal harness; no capability promotion.

## 7a. GitHub issue ledger

Inspected1496 and linked merged1495; reviewed overlapping1501/1505 and retained1507. No issue closed, public comment posted, release made or email sent.

## 8. What did not go smoothly

Heavy unsharded run timed out before this CV continuation. Test output buffering prevents locating a stall. Apple compiler discovery and system git are blocked by pending Xcode license; no bypass/acceptance. Existing libgit2 and compile-free R loading permit scoped edits/tests. An initial local probe omitted required grouping arguments before switching to the established fixture; those errors are not repair evidence. The older /tmp installed package predates the bootstrap weight correction and was excluded from final checks.

## 9. Team learning

Fisher: independent mathematical review established the cell-versus-trial distinction and caught the original-missing-cell denominator risk. Explicit trial expansion now guards the formulas without sharing their implementation.

Emmy: independent implementation review caught missing predictors escaping the initial intersection-only alignment guard. Required fitted data variables/grouping columns are now checked while external formula objects remain valid.

Curie: the red tests expose fitted refit failures, not just arithmetic kernels; manual ordinary/null folds make trial preservation observable end to end. Separate prophylactic cases from executed red proofs.

Grace: compiler-free testing against unchanged native code allows useful progress without license or security changes, while a fresh-build/full-suite claim remains withheld. Partition completeness must be proved on the final commit, not a stale file count.

## 10. Limitations and next actions

Publish as a draft stacked on1507, verify normal CI at its exact head, and complete heavy validation through an explicitly approved route. Optional manual heavy sharding approval is pending; no test/time limit/security changes made. No claim of scientific interval calibration or new family scoring. Original raw wide input is not the CV driver input: use fit$data, its stacked model frame. The pre-existing null-model degeneracy policy is unchanged. Integration remains a maintainer decision; do not close1496 or merge either draft automatically.
