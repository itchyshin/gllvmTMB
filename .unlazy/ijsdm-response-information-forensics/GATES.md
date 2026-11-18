# Gates: iJSDM response-information forensic audit

OWNS: dev/isdm-requalification/response-information-forensics/**, tests/testthat/test-isdm-response-information-forensics.R, docs/design/35-validation-debt-register.md, docs/dev-log/check-log.md, docs/dev-log/after-task/2026-09-02-isdm-response-information-forensics.md, .unlazy/ijsdm-response-information-forensics/**

Scope: Preserve the completed 800-fit study while producing a reproducible diagnostic audit and a conservative successor-campaign decision.

- [x] G0: Frozen predecessor integrity is demonstrated by the all-fit table and the two committed focal hashes.
  CHECK: Rscript --vanilla dev/isdm-requalification/response-information-forensics/verify-forensics.R integrity
  EXPECT: G0 predecessor integrity PASS
  CWD: ../..
  EVIDENCE: exit=0; shell=/bin/sh; cwd=/private/tmp/gllvmtmb-isdm-response-information-20260901; path=92301ffe9a62/34 entries; output=G0 predecessor integrity PASS

- [x] G1: The independently recomputed 800-fit and 400-pair diagnostic tables are complete.
  CHECK: Rscript --vanilla dev/isdm-requalification/response-information-forensics/verify-forensics.R table
  EXPECT: G1 diagnostic table PASS
  CWD: ../..
  EVIDENCE: exit=0; shell=/bin/sh; cwd=/private/tmp/gllvmtmb-isdm-response-information-20260901; path=92301ffe9a62/34 entries; output=G1 diagnostic table PASS

- [x] G2: The forensic result preserves the original fit-health classification and does not reclassify either failed identity.
  CHECK: Rscript --vanilla dev/isdm-requalification/response-information-forensics/verify-forensics.R boundary
  EXPECT: G2 boundary PASS
  CWD: ../..
  EVIDENCE: exit=0; shell=/bin/sh; cwd=/private/tmp/gllvmtmb-isdm-response-information-20260901; path=92301ffe9a62/34 entries; output=G2 boundary PASS

- [x] G3: The receipt records an explicit, conservative successor-campaign decision.
  CHECK: Rscript --vanilla dev/isdm-requalification/response-information-forensics/verify-forensics.R receipt
  EXPECT: G3 decision receipt PASS
  CWD: ../..
  EVIDENCE: exit=0; shell=/bin/sh; cwd=/private/tmp/gllvmtmb-isdm-response-information-20260901; path=92301ffe9a62/34 entries; output=G3 decision receipt PASS
