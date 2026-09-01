# Structured rho checkpoint before Totoro pilot

Goal active; full approved arc, sole writer worktree87fa. Current STATUS.md and
GATES.md supersede earlier zero-fit checkpoints. Pre-run12spent; engineering7;
retained0;teaching0;packagecheck0. Core,workflow,compatibility,family andoptimized
Poisson/Gaussian software-equivalence gates pass at their recorded hashes.
Current installed local package: install-scope-fence-01. All executable receipts
under dev/structured-rho/evidence. Frozen retained fixture manifest:
7580cdca135874199b740c025764a4bc512da5f0f769164908e27bedf4afc504.

Pilot not launched. No remote files written yet. Existing Totoro socket verified,
/home/snakagaw available41TB; R4.5.3/TMB1.9.21/Matrix1.7.5 known. Pending: final
bounded harness repair check, local commit, exact source+fixture bundle to a new
/home/snakagaw/structured-rho-87fa directory, isolated install<=5min,24pilot
attempts<=30min at12workers/BLAS1, each<=14min includingcleanup. Pilot is partof
2400 retained attempts, notextra. Stage and install are authorized; no campaign
remainder until measuredcheckpoint approval. Runner now verifiesinstalledhashes,
counts numericalfailures separately, and writes not-launcheddeadline records.

Review caught incorrect residualreport field; fixed to scalarfinitepositive
sigma_eps and independently checked full covariance metric at9 parametercases.
No pilot fit occurred with the wrongmetric. No tolerance loosened. Current
source diff check passes excludingraw evidence logs; attemptsCSVnormalizedtoLF.

Next safe action: finish pilot setup andrunapproved24, then presentmeasured
approval checkpoint while continuingdocumentation. No maintainer question blocks
current work. No push/merge/version/release/publication/closedarticle edits.
Afterthat: teaching/article/cascade/fullcheck,remainingcampaignifapproved,
finalfresh2Terra-high+1Sol-highpanel. Goal cannotcompleteatfixed/corecheckpoint.

Exact branch/status and diffstat beforecheckpoint commit:
```text
## codex/structured-term-rho-20260831
 M R/extract-sigma.R
 M R/fit-multi.R
 M R/methods-gllvmTMB.R
 M R/profile-ci.R
 M R/structured-rho.R
 M dev/structured-rho/GATES.md
 M dev/structured-rho/STATUS.md
 M dev/structured-rho/attempts.csv
 M dev/structured-rho/reviews/core-review.md
 M docs/design/06-extractors-contract.md
 M docs/design/35-validation-debt-register.md
 M docs/dev-log/after-task/2026-08-31-structured-rho.md
 M docs/dev-log/check-log.md
 M man/extract_Sigma.Rd
 M man/predict.gllvmTMB_multi.Rd
 M man/tmbprofile_wrapper.Rd
 M tests/testthat/helper-structured-rho.R
 M tests/testthat/test-structured-rho-workflow.R
?? dev/structured-rho/.gitignore
?? dev/structured-rho/PRERUN.md
?? dev/structured-rho/check-compat.R
?? dev/structured-rho/check-engineering.R
?? dev/structured-rho/check-prerun-score.R
?? dev/structured-rho/check-prerun.R
?? dev/structured-rho/check-study-metrics.R
?? dev/structured-rho/check-study-sources.R
?? dev/structured-rho/compat-snapshot.R
?? dev/structured-rho/engineering-fixtures/
?? dev/structured-rho/evidence/compat-baseline-02/
?? dev/structured-rho/evidence/compat-baseline/
?? dev/structured-rho/evidence/compat-candidate-omitted-02/
?? dev/structured-rho/evidence/compat-candidate-omitted/
?? dev/structured-rho/evidence/compat-candidate-one-02/
?? dev/structured-rho/evidence/compat-candidate-one/
?? dev/structured-rho/evidence/compat-check-01/
?? dev/structured-rho/evidence/compat-check-02/
?? dev/structured-rho/evidence/components-01/
?? dev/structured-rho/evidence/diagnostics-interval-01/
?? dev/structured-rho/evidence/diagnostics-workflow-01/
?? dev/structured-rho/evidence/document-diagnostics-01/
?? dev/structured-rho/evidence/endpoint-components-01/
?? dev/structured-rho/evidence/endpoint-interval-01/
?? dev/structured-rho/evidence/endpoint-workflow-01/
?? dev/structured-rho/evidence/engineering-batch-01/
?? dev/structured-rho/evidence/engineering-batch-check-01/
?? dev/structured-rho/evidence/engineering-batch-check-02/
?? dev/structured-rho/evidence/family-oracle-01/
?? dev/structured-rho/evidence/family-oracle-02/
?? dev/structured-rho/evidence/family-oracle-endpoints-01/
?? dev/structured-rho/evidence/freeze-study-01/
?? dev/structured-rho/evidence/install-baseline-command/
?? dev/structured-rho/evidence/install-baseline/
?? dev/structured-rho/evidence/install-diagnostics-01/
?? dev/structured-rho/evidence/install-endpoint-workflow-01/
?? dev/structured-rho/evidence/install-scope-fence-01/
?? dev/structured-rho/evidence/interval-red/
?? dev/structured-rho/evidence/ordinary-slope-fence-green-02/
?? dev/structured-rho/evidence/ordinary-slope-fence-green/
?? dev/structured-rho/evidence/ordinary-slope-fence-red-02/
?? dev/structured-rho/evidence/ordinary-slope-fence-red/
?? dev/structured-rho/evidence/prerun-independent-audit/
?? dev/structured-rho/evidence/prerun-score-audit/
?? dev/structured-rho/evidence/prerun/
?? dev/structured-rho/evidence/study-metrics-01/
?? dev/structured-rho/evidence/study-sources-01/
?? dev/structured-rho/evidence/study-sources-02/
?? dev/structured-rho/fit-engineering.R
?? dev/structured-rho/fit-study.R
?? dev/structured-rho/freeze-engineering.R
?? dev/structured-rho/freeze-study.R
?? dev/structured-rho/install-pilot.py
?? dev/structured-rho/run-engineering.py
?? dev/structured-rho/run-pilot.py
?? dev/structured-rho/study-fixtures/
?? dev/structured-rho/study-formula.R
?? dev/structured-rho/study-metrics.R
?? dev/structured-rho/test-components.R
?? dev/structured-rho/test-family-oracle.R
?? dev/structured-rho/test-interval.R
?? tests/testthat/test-structured-rho-components.R
?? tests/testthat/test-structured-rho-family-oracle.R
?? tests/testthat/test-structured-rho-interval.R

 R/extract-sigma.R                                  |  4 ++
 R/fit-multi.R                                      | 12 +++-
 R/methods-gllvmTMB.R                               | 19 ++++---
 R/profile-ci.R                                     |  3 +
 R/structured-rho.R                                 | 28 +++++++++-
 dev/structured-rho/GATES.md                        | 25 ++++++++-
 dev/structured-rho/STATUS.md                       | 28 ++++++++++
 dev/structured-rho/attempts.csv                    | 19 +++++++
 dev/structured-rho/reviews/core-review.md          | 44 +++++++++++++++
 docs/design/06-extractors-contract.md              |  9 ++-
 docs/design/35-validation-debt-register.md         |  6 +-
 .../after-task/2026-08-31-structured-rho.md        | 30 ++++++++++
 docs/dev-log/check-log.md                          | 65 ++++++++++++++++++++++
 man/extract_Sigma.Rd                               |  4 ++
 man/predict.gllvmTMB_multi.Rd                      |  4 +-
 man/tmbprofile_wrapper.Rd                          |  2 +
 tests/testthat/helper-structured-rho.R             |  9 ++-
 tests/testthat/test-structured-rho-workflow.R      | 37 ++++++++++++
 18 files changed, 322 insertions(+), 26 deletions(-)
```
