# Structured rho recovery checkpoint — 2026-08-31 10:42 MDT

Goal active; sole implementation writer root. Latest commit027610316. Full
approved arc remains incomplete. User reconnected Totoro/DRAC; access was
verified and approved24-attempt pilot ran. Explicit remaining-campaign approval
was requested after pilot and has NOT arrived. No approval file exists.

Counts from attempt ledger: {"prerun": 12, "engineering": 7, "retained": 24, "teaching": 12}. All failures retained.
Pilot23/24 numerical successes,34.408seconds,4.752GiB maximum processRSS.
PILOT.md includes frozen bundle/installed/fixture hashes and requests2376more
attempts,12workers,BLAS1,20–60min,hard60min. Do not launch without user reply.
Remote task /home/snakagaw/structured-rho-87fa-027610316 is idle afterpilot.

## Commands and outcomes

Receipts in dev/structured-rho/evidence retain exact commands/hash/status/log.
install-multivariate-01 passed23.852s. multivariate-admission-red fails exactly
the missing two-trait minimum; green passes15assertions after narrowguard.
candidate-fixed-01, candidate-estimated-01, candidate-workflow-01 pass on the
verified install dependency. teaching-render-03 passed19.293s,4fitcalls; HTML
and source hash retained. Direct phylogenetic-signal interval guard regression
passed before reinstall; no fitting code changed by that guard. No rhoCI added.

## Live operations to poll

- Full package-check-01: exec session50391; timeout1800s; startedabout10:16MDT.
  Suite still running at this checkpoint; code/example/compilation checksdone.
  logLik import note is baseline; timestamp note also retained. Do notextend
  ceiling. Test callslogged, but first-pass build/example callcounts UNMEASURED
  because rcmdcheck cleared R_TESTS. Preparedcheck-package-repair.R explicitly
  passesenv; one attributable repair rerun allowed, not yetstarted.
- candidate-family-01: exec session76644, fixed-point1116nativefamilyoracles,
  noouteroptimizer.
- compat-candidate-omitted-03 and one-03: sessions10514/62843; snapshotsnooptimizer.
  Need comparison against retained baseline-02 after bothcomplete.

## Next safest actions

Finish live gates, retain outcomeandcounts, updateGATES/status/report/check-log.
Before repairfullcheck settleallsourcechanges; no hiddenadditionalpass.
Boole/Pat reviewed repaircountenv and found no remainingblocker with required
run-gate.py wrapper. Generalp>=2guardchangesunsupportedinputonly; allstudydata
p6; keep frozenremoteinstallation. Allparentgatesopen; finalpanel2Terrahigh+
1Solhigh onlyaftercandidateandfullretainedevidence. No push/merge/release,
version,publication,closedarticleedits orotherrepowrites.

## Git status

```text
## codex/structured-term-rho-20260831
 M NEWS.md
 M R/phylo-signal-ci.R
 M R/profile-derived.R
 M R/structured-rho.R
 M _pkgdown.yml
 M dev/structured-rho/STATUS.md
 M dev/structured-rho/attempts.csv
 M dev/structured-rho/compat-snapshot.R
 M dev/structured-rho/reviews/core-review.md
 M dev/structured-rho/run-gate.py
 M docs/design/01-formula-grammar.md
 M docs/design/03-likelihoods.md
 M docs/design/06-extractors-contract.md
 M docs/dev-log/after-task/2026-08-31-structured-rho.md
 M docs/dev-log/check-log.md
 M man/profile_ci_phylo_signal.Rd
 M tests/testthat/test-structured-rho-contract.R
 M tests/testthat/test-structured-rho-estimation-contract.R
 M tests/testthat/test-structured-rho-interval.R
 M vignettes/articles/api-keyword-grid.Rmd
?? dev/structured-rho/PILOT.md
?? dev/structured-rho/check-optimizer-startup.R
?? dev/structured-rho/check-package-repair.R
?? dev/structured-rho/check-package.R
?? dev/structured-rho/evidence/candidate-estimated-01/
?? dev/structured-rho/evidence/candidate-family-01/
?? dev/structured-rho/evidence/candidate-fixed-01/
?? dev/structured-rho/evidence/candidate-workflow-01/
?? dev/structured-rho/evidence/compat-candidate-omitted-03/
?? dev/structured-rho/evidence/compat-candidate-one-03/
?? dev/structured-rho/evidence/contract-final-01/
?? dev/structured-rho/evidence/direct-signal-interval-green/
?? dev/structured-rho/evidence/direct-signal-interval-red/
?? dev/structured-rho/evidence/document-direct-signal-01/
?? dev/structured-rho/evidence/install-direct-signal-01/
?? dev/structured-rho/evidence/install-multivariate-01/
?? dev/structured-rho/evidence/multivariate-admission-green/
?? dev/structured-rho/evidence/multivariate-admission-red/
?? dev/structured-rho/evidence/package-check-01/
?? dev/structured-rho/evidence/pilot-summary-01/
?? dev/structured-rho/evidence/real-rho-type-green/
?? dev/structured-rho/evidence/real-rho-type-red/
?? dev/structured-rho/evidence/teaching-grid-01/
?? dev/structured-rho/evidence/teaching-render-01/
?? dev/structured-rho/evidence/teaching-render-02/
?? dev/structured-rho/evidence/teaching-render-03/
?? dev/structured-rho/evidence/totoro-pilot-01/
?? dev/structured-rho/evidence/totoro-stage-01/
?? dev/structured-rho/render-example.R
?? dev/structured-rho/run-remaining.py
?? dev/structured-rho/stage-pilot-bundle.py
?? dev/structured-rho/summarize-study.R
?? tests/testthat/helper-structured-rho-check-counts.R
?? vignettes/articles/structured-source-strength.Rmd
```

## Diff stat

```text
 NEWS.md                                            | 21 ++++++
 R/phylo-signal-ci.R                                |  1 +
 R/profile-derived.R                                |  4 ++
 R/structured-rho.R                                 |  3 +
 _pkgdown.yml                                       |  3 +
 dev/structured-rho/STATUS.md                       | 58 ++++++++++-------
 dev/structured-rho/attempts.csv                    | 76 ++++++++++++++++------
 dev/structured-rho/compat-snapshot.R               |  2 +-
 dev/structured-rho/reviews/core-review.md          | 20 ++++++
 dev/structured-rho/run-gate.py                     |  6 ++
 docs/design/01-formula-grammar.md                  | 11 ++--
 docs/design/03-likelihoods.md                      |  2 +-
 docs/design/06-extractors-contract.md              |  2 +-
 .../after-task/2026-08-31-structured-rho.md        | 48 ++++++++++++++
 docs/dev-log/check-log.md                          | 48 ++++++++++++++
 man/profile_ci_phylo_signal.Rd                     |  3 +
 tests/testthat/test-structured-rho-contract.R      |  2 +-
 .../test-structured-rho-estimation-contract.R      |  1 +
 tests/testthat/test-structured-rho-interval.R      | 11 ++++
 vignettes/articles/api-keyword-grid.Rmd            | 20 ++++++
 20 files changed, 290 insertions(+), 52 deletions(-)
```
