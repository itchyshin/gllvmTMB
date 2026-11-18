# Gates: covariance teaching correction

OWNS: vignettes/articles/covariance-correlation.Rmd, vignettes/articles/cross-family-correlations.Rmd, vignettes/articles/spatial-models.Rmd, R/extract-correlations.R, man/extract_cross_correlations.Rd, dev/covariance-teaching/**

- [x] G1: Baseline and exact-path lease confirmed
  EVIDENCE: fetched da6398a9; exact-path lease codex:covariance-teaching-4568 granted; PLAN.md records approval.

- [x] G2: All five findings and three reader issues corrected with exact before/after evidence
  EVIDENCE: requirement-map.md covers F1-F5/R1-R3; final Noether/Pat/Rose reports PASS.

- [x] G3: Static verification preserves evaluated R expressions and extractor numerical behavior
  CHECK: Rscript --vanilla dev/covariance-teaching/verify-invariants.R
  EXPECT: INVARIANTS_VERIFIED
  EVIDENCE: exit=0; shell=/bin/sh; cwd=/Users/z3437171/.codex/worktrees/4568/gllvmTMB; path=e453f830a327/38 entries; output=Spatial counterexample: same total covariance, different shared covariance and positive diagonals | INVARIANTS_VERIFIED

- [x] G4: Spatial counterexample and final Noether mathematical review pass
  EVIDENCE: verify-invariants.R counterexample PASS; noether-review.md exact algebra and scope PASS.

- [x] G5: devtools::document regenerates matching help without unrelated changes; pkgdown check passes
  EVIDENCE: setup-library-argument.json PASS98.701s; only intended Rd differs; pkgdown no problems.

- [x] G6: Exactly three authorized article renders succeed within allowance; warnings retained
  EVIDENCE: 3 article renders;9 fits convergence0;42.492 process seconds/207.254 block seconds. Original covariance wrapper failed; separate covariance-reconciliation.json proves nested forwarding, no rerender.

- [x] G7: Rendered corrections, wide labels and four actual alt attributes verified; Pat review passes
  EVIDENCE: verify-rendered.py PASS actual4 alts and local assets; direct4 PNG inspections; Pat PASS; browser local-file navigation policy-blocked, no workaround.

- [x] G8: One bounded local package check passes with retained receipt
  EVIDENCE: package-check.json PASS1311.453s;0E/0W/1unchanged-source NOTE; testthat FAIL0 WARN54 SKIP1190 PASS16067.

- [x] G9: Rose consistency review and after-task/check-log evidence complete
  EVIDENCE: Rose source report PASS; after-task structural checker PASS; own check-log append after exact lease grant. Package and CI gates remain separate.

- [ ] G10: Focused PR prepared; final candidate three-OS CI green; no merge or landing
  EVIDENCE: pending

Post-push G10 evidence is stored on the PR and in local receipts/final-ci.json.
