# Structured rho core recovery checkpoint

2026-08-31, worktree87fa. Active goal remains the entire fixed-plus-estimated
arc in dev/structured-rho/PLAN.md. This is an internal checkpoint, not a handoff
or completion claim. Same root writer resumes; no new task/worktree needed.

## Current branch and working state before checkpoint commit

```text
## codex/structured-term-rho-20260831
 M AGENTS.md
 M CLAUDE.md
 M R/animal-keyword.R
 M R/brms-sugar.R
 M R/fit-multi.R
 M R/gllvmTMB.R
 M R/kernel-keywords.R
 M docs/design/01-formula-grammar.md
 M docs/design/03-likelihoods.md
 M docs/design/35-validation-debt-register.md
 M docs/dev-log/check-log.md
 M man/animal_dep.Rd
 M man/animal_indep.Rd
 M man/animal_latent.Rd
 M man/kernel_latent.Rd
 M man/phylo_dep.Rd
 M man/phylo_indep.Rd
 M man/phylo_latent.Rd
 M man/spatial_dep.Rd
 M man/spatial_indep.Rd
 M man/spatial_latent.Rd
 M src/gllvmTMB.cpp
?? R/structured-rho.R
?? dev/structured-rho/
?? docs/dev-log/after-task/2026-08-31-structured-rho.md
?? tests/testthat/helper-structured-rho.R
?? tests/testthat/test-structured-rho-contract.R
?? tests/testthat/test-structured-rho-estimated-oracle.R
?? tests/testthat/test-structured-rho-estimation-contract.R
?? tests/testthat/test-structured-rho-fixed-oracle.R
```

```text
 AGENTS.md                                  |   9 +++
 CLAUDE.md                                  |   8 ++
 R/animal-keyword.R                         |  31 +++++++-
 R/brms-sugar.R                             |  47 +++++++++--
 R/fit-multi.R                              | 120 ++++++++++++++++++++++++++++-
 R/gllvmTMB.R                               |  15 ++++
 R/kernel-keywords.R                        |  14 +++-
 docs/design/01-formula-grammar.md          |  20 +++++
 docs/design/03-likelihoods.md              |  39 ++++++++++
 docs/design/35-validation-debt-register.md |   8 ++
 docs/dev-log/check-log.md                  |  57 ++++++++++++++
 man/animal_dep.Rd                          |  11 ++-
 man/animal_indep.Rd                        |  18 ++++-
 man/animal_latent.Rd                       |  12 ++-
 man/kernel_latent.Rd                       |  15 +++-
 man/phylo_dep.Rd                           |  11 ++-
 man/phylo_indep.Rd                         |  12 ++-
 man/phylo_latent.Rd                        |  12 ++-
 man/spatial_dep.Rd                         |   6 +-
 man/spatial_indep.Rd                       |   6 +-
 man/spatial_latent.Rd                      |  13 +++-
 src/gllvmTMB.cpp                           |  87 +++++++++++++++++++--
 22 files changed, 537 insertions(+), 34 deletions(-)
```

Untracked implementation/tests/dev evidence and this checkpoint are intentional.
Initial baseline101fafcc3. Scoped local checkpoint commit is authorized; no push.

## Evidence already obtained

Read `.unlazy/structured-rho/GATES.md`, dev/structured-rho/STATUS.md and the
latest check-log entry. Four final core gates pass with FAIL0/WARN0/SKIP0:
contract66, estimation-contract14, fixed-oracle150, estimated-oracle389.
Sixty fixed and100 estimated Gaussian covariance points plus explicit-unit_obs
and wide-format comparisons. Latest installed dependency install-core-04;
R/src hashes match tested files. Source/test SHA-256:
47906bb4523f4ce9ca9d037ad74f99ac4e9edc65c5ed6e29ee6c6ff734c893d3.
Builds and document generation completed; ten scoped Rd files updated.
Three roxygen S3 diagnostics reference untouched aghq-report.R. Failed oracle
iterations remain retained; see evidence/PROVENANCE.md. No tolerance changes.

Every optimizer-attempt counter remains0. No outer optimizer, local pre-run,
Totoro pilot, retained campaign, teaching render or full package check ran.

## Next safest action

Finish weak-loading diagnostics and full user workflow: simulation including
Psi/IID; known-level prediction; source-strength extraction; typed limitations
on legacy source allocation and unsupported intervals/refit comparisons.
The concrete read-only inventory is dev/structured-rho/reviews/core-review.md.
Then run the approved12-attempt local feasibility study with attempt guards;
finish family and exact legacy compatibility checks; prepare frozen Totoro
pilot/manifest. The user reports Totoro and DRAC reconnected; verify existing
ControlMaster socket before pilot, never initiate a Duo login.

## Outstanding gates and permission boundary

All parent acceptance gates remain open. Full recovery is Gaussian-only;
Poisson comparisons are software equivalence, not recovery. Full retained
campaign beyond its first24pilot attempts still needs the user's measured
compute approval. No other blocking question. Never close at fixed-only/core.
Do not touch closed articles, coefficient defaults, unrelated softmax wording,
older MSPL/slope lanes, or other repositories. Three-OS and publication gates
are subsequent landing requirements, not current authorization.
