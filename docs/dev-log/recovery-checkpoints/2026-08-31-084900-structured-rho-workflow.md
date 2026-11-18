# Structured rho workflow checkpoint

Goal active; approved full arc, solewriterworktree87fa; branchcodex/structured-term-rho-20260831.
No optimizer attempts yet. Core619 and workflow216 assertions pass; receipts under
dev/structured-rho/evidence. R/src dependency install-workflow-04. Build and help
regeneration passed with unchanged upstream S3 tag diagnostics. Sources frozen
in dev/structured-rho/prerun-fixtures; pre-run runner read-only reviewed.
Next: local checkpoint commit then python3 dev/structured-rho/run-prerun.py
(expected<=24min,12attempts,each<=2minincludingcleanup). Record all results;
then compatibility/family/ordinary-component gates and teaching. No campaign
before measured24pilotapproval. No blocking maintainer question at this point.
No push/merge/version/release or other-repository edits.

Commands already run and exact results: latest check-log entry, workflow04 and
workflow-core-* receipts. Pending: optimizerpre-run, family/compatibility tests,
fullteaching/renders/packagecheck,24pilot,approval,restofcampaign,finalpanel.

```text
## codex/structured-term-rho-20260831
 M R/bootstrap-sigma.R
 M R/extract-omega.R
 M R/extract-sigma.R
 M R/extract-two-psi-cross-check.R
 M R/fit-multi.R
 M R/loading-ci-bootstrap.R
 M R/methods-gllvmTMB.R
 M R/output-methods.R
 M R/structured-rho.R
 M dev/structured-rho/GATES.md
 M dev/structured-rho/STATUS.md
 M docs/design/06-extractors-contract.md
 M docs/design/35-validation-debt-register.md
 M docs/dev-log/after-task/2026-08-31-structured-rho.md
 M docs/dev-log/check-log.md
 M man/VP.Rd
 M man/bootstrap_Sigma.Rd
 M man/extract_Sigma.Rd
 M man/extract_phylo_signal.Rd
 M man/extract_proportions.Rd
 M man/predict.gllvmTMB_multi.Rd
 M man/simulate.gllvmTMB_multi.Rd
 M tests/testthat/helper-structured-rho.R
?? dev/structured-rho/evidence/document-workflow-01/
?? dev/structured-rho/evidence/install-workflow-01/
?? dev/structured-rho/evidence/install-workflow-02/
?? dev/structured-rho/evidence/install-workflow-03/
?? dev/structured-rho/evidence/install-workflow-04/
?? dev/structured-rho/evidence/workflow-01/
?? dev/structured-rho/evidence/workflow-02/
?? dev/structured-rho/evidence/workflow-03/
?? dev/structured-rho/evidence/workflow-04/
?? dev/structured-rho/evidence/workflow-core-contract/
?? dev/structured-rho/evidence/workflow-core-estimated-oracle/
?? dev/structured-rho/evidence/workflow-core-estimation-contract/
?? dev/structured-rho/evidence/workflow-core-fixed-oracle/
?? dev/structured-rho/evidence/workflow-red/
?? dev/structured-rho/fit-prerun.R
?? dev/structured-rho/freeze-prerun.R
?? dev/structured-rho/prerun-fixtures/
?? dev/structured-rho/run-prerun.py
?? dev/structured-rho/test-workflow.R
?? tests/testthat/test-structured-rho-workflow.R

 R/bootstrap-sigma.R                                |   7 +
 R/extract-omega.R                                  |  12 ++
 R/extract-sigma.R                                  |  19 ++-
 R/extract-two-psi-cross-check.R                    |   1 +
 R/fit-multi.R                                      |   5 +-
 R/loading-ci-bootstrap.R                           |   1 +
 R/methods-gllvmTMB.R                               |  61 ++++++++-
 R/output-methods.R                                 |   5 +
 R/structured-rho.R                                 | 143 +++++++++++++++++++++
 dev/structured-rho/GATES.md                        |   5 +
 dev/structured-rho/STATUS.md                       |  11 ++
 docs/design/06-extractors-contract.md              |  25 ++++
 docs/design/35-validation-debt-register.md         |   4 +-
 .../after-task/2026-08-31-structured-rho.md        |  38 +++++-
 docs/dev-log/check-log.md                          |  42 ++++++
 man/VP.Rd                                          |   3 +
 man/bootstrap_Sigma.Rd                             |   4 +
 man/extract_Sigma.Rd                               |  10 ++
 man/extract_phylo_signal.Rd                        |   4 +
 man/extract_proportions.Rd                         |   4 +
 man/predict.gllvmTMB_multi.Rd                      |   4 +-
 man/simulate.gllvmTMB_multi.Rd                     |   8 ++
 tests/testthat/helper-structured-rho.R             |  19 +++
 23 files changed, 416 insertions(+), 19 deletions(-)
```
