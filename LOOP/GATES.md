# Gates: integrated-JSDM identifiability diagnostic

OWNS: LOOP/**, dev/isdm-requalification/diagnostic-rescue/**, tests/testthat/test-isdm-diagnostic-*

Scope: retain and adjudicate the approved 52-fit public-route diagnostic experiment and name one evidence-bounded next action

- [x] G1: the frozen diagnostic contract contains exactly 16 nonspatial and 36 spatial tasks with unique immutable task identifiers
  CHECK: Rscript --vanilla dev/isdm-requalification/diagnostic-rescue/verify-contract.R
  EXPECT: DIAGNOSTIC_CONTRACT_VERIFIED
  EVIDENCE: exit=0; shell=/bin/sh; cwd=/Users/z3437171/local-scratch/lanes/gllvmTMB-isdm-identifiability-diagnostic; path=1c6be4364d72/34 entries; output=[1] 36 | DIAGNOSTIC_CONTRACT_VERIFIED

- [x] G2: deterministic tests verify replication, estimand decomposition, seed-selection refusal, curvature extraction, watchdog process-group stopping, and all-attempt reconciliation
  CHECK: Rscript --vanilla -e 'devtools::test(filter = "isdm-diagnostic", stop_on_failure = TRUE)'
  EXPECT: FAIL 0
  EVIDENCE: exit=0; shell=/bin/sh; cwd=/Users/z3437171/local-scratch/lanes/gllvmTMB-isdm-identifiability-diagnostic; path=1c6be4364d72/34 entries; output=ℹ Testing gllvmTMB | gllvmTMB is EXPERIMENTAL (lifecycle: experimental). Use at your own risk: the package is not complete, is not fully human-verified, and needs extensive further validation. Point estimates are the primary inferential out

- [x] G3: the source pin and diagnostic harness manifest are exact and contain no package R or C++ edits
  CHECK: Rscript --vanilla dev/isdm-requalification/diagnostic-rescue/verify-source.R
  EXPECT: DIAGNOSTIC_SOURCE_VERIFIED
  EVIDENCE: exit=0; shell=/bin/sh; cwd=/Users/z3437171/local-scratch/lanes/gllvmTMB-isdm-identifiability-diagnostic; path=1c6be4364d72/34 entries; output=DIAGNOSTIC_SOURCE_VERIFIED

- [x] G4: the seed selector reproduces the frozen rule from checksum-verified immutable production records
  CHECK: Rscript --vanilla dev/isdm-requalification/diagnostic-rescue/verify-seed-selection.R
  EXPECT: DIAGNOSTIC_SEED_SELECTION_VERIFIED
  EVIDENCE: exit=0; shell=/bin/sh; cwd=/Users/z3437171/local-scratch/lanes/gllvmTMB-isdm-identifiability-diagnostic; path=1c6be4364d72/34 entries; output=DIAGNOSTIC_SEED_SELECTION_VERIFIED

- [x] G5: Curie, Gauss, and Rose reviews contain no unresolved blocking finding
  CHECK: Rscript --vanilla dev/isdm-requalification/diagnostic-rescue/verify-reviews.R plan
  EXPECT: DIAGNOSTIC_PLAN_REVIEWS_VERIFIED
  EVIDENCE: exit=0; shell=/bin/sh; cwd=/Users/z3437171/local-scratch/lanes/gllvmTMB-isdm-identifiability-diagnostic; path=1c6be4364d72/34 entries; output=DIAGNOSTIC_PLAN_REVIEWS_VERIFIED

- [x] G6: the Totoro diagnostic install matches the frozen source and harness identity
  CHECK: Rscript --vanilla dev/isdm-requalification/diagnostic-rescue/verify-remote-receipt.R qualification
  EXPECT: DIAGNOSTIC_REMOTE_QUALIFICATION_VERIFIED
  EVIDENCE: exit=0; shell=/bin/sh; cwd=/Users/z3437171/local-scratch/lanes/gllvmTMB-isdm-identifiability-diagnostic; path=1c6be4364d72/34 entries; output=DIAGNOSTIC_REMOTE_QUALIFICATION_VERIFIED

- [x] G7: four smoke tasks verify byte-preserved rep3 baselines, three-estimand identity, optimizer start/copy equality, primary curvature diagnostics, complete records, and a projection no greater than 10 minutes
  CHECK: Rscript --vanilla dev/isdm-requalification/diagnostic-rescue/verify-remote-receipt.R smoke
  EXPECT: DIAGNOSTIC_SMOKE_VERIFIED
  EVIDENCE: exit=0; shell=/bin/sh; cwd=/Users/z3437171/local-scratch/lanes/gllvmTMB-isdm-identifiability-diagnostic; path=1c6be4364d72/34 entries; output=DIAGNOSTIC_SMOKE_VERIFIED

- [x] G8: all 52 planned task identities have exactly one worker or coordinator terminal disposition with no replacement attempts
  CHECK: Rscript --vanilla dev/isdm-requalification/diagnostic-rescue/verify-remote-receipt.R experiment
  EXPECT: DIAGNOSTIC_52_ATTEMPTS_VERIFIED
  EVIDENCE: exit=0; shell=/bin/sh; cwd=/Users/z3437171/local-scratch/lanes/gllvmTMB-isdm-identifiability-diagnostic; path=1c6be4364d72/34 entries; output=DIAGNOSTIC_52_ATTEMPTS_VERIFIED

- [x] G9: the frozen raw manifest verifies and a separate pure reader reproduces all task, status, target-availability, and contrast denominators
  CHECK: Rscript --vanilla dev/isdm-requalification/diagnostic-rescue/verify-remote-receipt.R summary
  EXPECT: DIAGNOSTIC_SUMMARY_VERIFIED
  EVIDENCE: exit=0; shell=/bin/sh; cwd=/Users/z3437171/local-scratch/lanes/gllvmTMB-isdm-identifiability-diagnostic; path=1c6be4364d72/34 entries; output=DIAGNOSTIC_SUMMARY_VERIFIED

- [x] G10: a deliberate corrupted-manifest control is rejected by the same verifier
  CHECK: Rscript --vanilla dev/isdm-requalification/diagnostic-rescue/verify-negative-control.R
  EXPECT: DIAGNOSTIC_NEGATIVE_CONTROL_VERIFIED
  EVIDENCE: exit=0; shell=/bin/sh; cwd=/Users/z3437171/local-scratch/lanes/gllvmTMB-isdm-identifiability-diagnostic; path=1c6be4364d72/34 entries; output=DIAGNOSTIC_NEGATIVE_CONTROL_VERIFIED

- [x] G11: terminal method, numerical, and scope reviews agree that the next action follows from retained evidence without promotion or threshold changes
  CHECK: Rscript --vanilla dev/isdm-requalification/diagnostic-rescue/verify-reviews.R terminal
  EXPECT: DIAGNOSTIC_TERMINAL_REVIEWS_VERIFIED
  EVIDENCE: exit=0; shell=/bin/sh; cwd=/Users/z3437171/local-scratch/lanes/gllvmTMB-isdm-identifiability-diagnostic; path=1c6be4364d72/34 entries; output=DIAGNOSTIC_TERMINAL_REVIEWS_VERIFIED

- [x] G12: the after-task report passes the repository validator, reconciles plan versus actual work, and records a fresh shared-doc lease
  CHECK: Rscript --vanilla dev/isdm-requalification/diagnostic-rescue/verify-closeout.R
  EXPECT: DIAGNOSTIC_CLOSEOUT_VERIFIED
  EVIDENCE: exit=0; shell=/bin/sh; cwd=/Users/z3437171/local-scratch/lanes/gllvmTMB-isdm-identifiability-diagnostic; path=1c6be4364d72/34 entries; output=DIAGNOSTIC_CLOSEOUT_VERIFIED

- [ ] G13: targeted tests and the package test suite pass on the final branch
  CHECK: Rscript --vanilla -e 'devtools::test(stop_on_failure = TRUE)'
  EXPECT: FAIL 0
  EVIDENCE: pending

- [ ] G14: an allowlisted diff, exact merged main, unchanged package-code hashes, green three-OS CI, retained checksums, and released leases are recorded in the postmerge receipt
  CHECK: Rscript --vanilla dev/isdm-requalification/diagnostic-rescue/verify-postmerge.R
  EXPECT: DIAGNOSTIC_POSTMERGE_VERIFIED
  EVIDENCE: pending
