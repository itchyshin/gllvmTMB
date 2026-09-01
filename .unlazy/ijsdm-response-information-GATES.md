# Gates: fresh iJSDM response-information study

OWNS: dev/isdm-requalification/response-information/, tests/testthat/test-isdm-response-information-, docs/dev-log/check-log.md, docs/dev-log/after-task/, docs/dev-log/recovery-checkpoints/, docs/design/35-validation-debt-register.md

- [x] G1: The fresh contract has 800 identities, disjoint qualification seeds, paired optimizer starts, nested response streams, and a tested classifier.
  CHECK: Rscript --vanilla dev/isdm-requalification/response-information/verify-contract.R && Rscript --vanilla dev/isdm-requalification/response-information/verify-tests.R
  CWD: .
  EXPECT: response information tests passed
  EVIDENCE: exit=0; shell=/bin/sh; cwd=/private/tmp/gllvmtmb-isdm-response-information-20260901; path=92301ffe9a62/34 entries; output=ℹ Testing gllvmTMB | gllvmTMB is EXPERIMENTAL (lifecycle: experimental). Use at your own risk: the package is not complete, is not fully human-verified, and needs extensive further validation. Point estimates are the primary inferential out

- [x] G2: Frozen plans and harness manifest bind the exact source files and exclude the prior stopped denominator.
  CHECK: Rscript --vanilla dev/isdm-requalification/response-information/freeze.R
  CWD: .
  EXPECT: response information freeze passed
  EVIDENCE: exit=0; shell=/bin/sh; cwd=/private/tmp/gllvmtmb-isdm-response-information-20260901; path=92301ffe9a62/34 entries; output=response information freeze passed

- [x] G3: Two Totoro and two DRAC engineering qualifications return real finite public-route fits in fresh workers.
  CHECK: Rscript --vanilla dev/isdm-requalification/response-information/verify-qualification.R dev/isdm-requalification/response-information/compute-inputs/qualification-plan.rds /private/tmp/isdm-qualification-6219/totoro /private/tmp/isdm-qualification-6219/tamia
  EXPECT: response information qualification verification passed
  EVIDENCE: exit=0; source=6219a478c8e5a7ce6f05f859ae6d04e126034ad7; harness=a4c5b7334cef74c6a4ddfd27d3f9670bb6f0fcce62bed317bc1a38a5cddc5309

- [x] G4: The intended 16 retained DRAC pilot identities pass every predeclared fit and resource gate.
  CHECK: Rscript --vanilla dev/isdm-requalification/response-information/verify-pilot.R dev/isdm-requalification/response-information/compute-inputs/pilot-plan.rds /private/tmp/isdm-pilot-recovery-retrieved && Rscript --vanilla dev/isdm-requalification/response-information/pilot-checkpoint.R dev/isdm-requalification/response-information/compute-inputs/pilot-plan.rds /private/tmp/isdm-pilot-recovery-retrieved /private/tmp/isdm-pilot-recovery-retrieved/pilot-checkpoint-770.rds 770
  EXPECT: response information pilot verification passed; response information pilot checkpoint passed
  EVIDENCE: Tamia job 434826 first 16 task positions plus approved job 434931 missing intended IDs; 30/30 terminal records; intended pilot 16/16 valid; max gradient=0.009472; peak RSS=343.8 MiB; max runtime=8.551 s; remaining=770; conservative projection=418.998 s.

- [x] G5: The remaining 770 identities ran after the repaired-pilot checkpoint and reconcile to exactly 800 terminal records.
  CHECK: Tamia job 434945; Rscript --vanilla dev/isdm-requalification/response-information/verify-study.R <scientific-plan.rds> <Tamia archive> <independent-summary.rds>
  EXPECT: response information study verification passed
  EVIDENCE: 800/800 terminal and returned fits; 398/400 scoreable pairs; per-cell scoreable counts=50,50,50,50,50,50,48,50; classifier=EVIDENCE_INCOMPLETE because task 624 and 632 have max gradients 0.01036609 and 0.01108690 (>0.01). Raw archive manifest SHA-256=6ac8b1aa246f913e2403d3373d6a115542ce4b03b026fd8204f6facb732112d8; compact summary SHA-256=a9c123847ba0122b411dd7b01381abdd9f3243301842cfc1754b5c863b4f74d6.

- [x] G6: Internal wording retains scope and makes no public response-information claim.
  CHECK: Rscript --vanilla dev/isdm-requalification/response-information/verify-wording.R
  CWD: .
  EXPECT: response information wording verification passed
  EVIDENCE: exit=0; shell=/bin/sh; cwd=/private/tmp/gllvmtmb-isdm-response-information-20260901; path=92301ffe9a62/34 entries; output=response information wording verification passed

- [x] G7: Scoped checks, independent reviews, provenance reconciliation, and a draft PR leave no P0/P1 finding.
  EVIDENCE: candidate `45f0013bb` was current with `origin/main` before push; focused contract/test/wording checks pass; evidence and reproducibility reviews pass after correcting scoreable denominators, write-once summaries, runtime binding, and `/project` manifest provenance. Draft PR #1233 is open at the exact candidate branch; no P0/P1 remains.
