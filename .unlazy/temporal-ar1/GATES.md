# Gates: temporal AR1 latent provider

OWNS: R/temporal.R, R/gllvmTMB.R, R/brms-sugar.R, R/traits-keyword.R, R/fit-multi.R, R/methods-gllvmTMB.R, R/output-methods.R, R/extractors.R, src/gllvmTMB.cpp, tests/testthat/test-temporal-ar1-parser.R, tests/testthat/test-temporal-ar1-oracles.R, tests/testthat/test-temporal-ar1-methods.R, tests/testthat/test-temporal-ar1-verify-runner.R, dev/temporal-ar1/**, .unlazy/temporal-ar1/**

Scope: native rank-one Gaussian temporal AR1 latent scores for unreplicated and replicated longitudinal data

- [x] G0: contract, execution root, and ownership are explicit before implementation
  CHECK: bash "/Users/z3437171/Dropbox/Github Local/Shinichi/tools/lane_preflight.sh" .
  EXPECT: ON BRANCH
  CWD: .
  EVIDENCE: exit=0; shell=/bin/sh; cwd=/Users/z3437171/.codex/worktrees/cb78/gllvmTMB; path=84c5b90d7dee/38 entries; output=OTHER LANES: <none / codex|cursor+PR# / Nx unknown> | ───────────────────────────────────

- [x] G1: temporal grammar and pair indexing reject malformed panels and preserve both public formula forms
  CHECK: NOT_CRAN=true Rscript --vanilla dev/temporal-ar1/verify.R parser
  EXPECT: TEMPORAL_PARSER_PASS
  CWD: .
  EVIDENCE: exit=0; shell=/bin/sh; cwd=/Users/z3437171/.codex/worktrees/cb78/gllvmTMB; path=84c5b90d7dee/38 entries; output=TEMPORAL_PARSER_PASS | gllvmTMB is EXPERIMENTAL (lifecycle: experimental). Use at your own risk: the package is not complete, is not fully human-verified, and needs extensive further validation. Point estimates are the primary output, and h

- [x] G2: temporal likelihood matches independently constructed Gaussian identities
  CHECK: NOT_CRAN=true Rscript --vanilla dev/temporal-ar1/verify.R oracle
  EXPECT: TEMPORAL_ORACLE_PASS
  CWD: .
  EVIDENCE: exit=0; shell=/bin/sh; cwd=/Users/z3437171/.codex/worktrees/cb78/gllvmTMB; path=84c5b90d7dee/38 entries; output=TEMPORAL_ORACLE_PASS | gllvmTMB is EXPERIMENTAL (lifecycle: experimental). Use at your own risk: the package is not complete, is not fully human-verified, and needs extensive further validation. Point estimates are the primary output, and h

- [x] G3: temporal lifecycle methods retain public labels and refuse unsupported routes
  CHECK: NOT_CRAN=true Rscript --vanilla dev/temporal-ar1/verify.R methods
  EXPECT: TEMPORAL_METHODS_PASS
  CWD: .
  EVIDENCE: exit=0; shell=/bin/sh; cwd=/Users/z3437171/.codex/worktrees/cb78/gllvmTMB; path=84c5b90d7dee/38 entries; output=TEMPORAL_METHODS_PASS | gllvmTMB is EXPERIMENTAL (lifecycle: experimental). Use at your own risk: the package is not complete, is not fully human-verified, and needs extensive further validation. Point estimates are the primary output, and

- [x] G4: bounded recovery fixtures retain every result and satisfy approved fixture-local smoke criteria
  CHECK: NOT_CRAN=true Rscript --vanilla dev/temporal-ar1/verify.R recovery
  EXPECT: TEMPORAL_RECOVERY_PASS
  CWD: .
  EVIDENCE: exit=0; shell=/bin/sh; cwd=/Users/z3437171/.codex/worktrees/cb78/gllvmTMB; path=84c5b90d7dee/38 entries; output=gllvmTMB is EXPERIMENTAL (lifecycle: experimental). Use at your own risk: the package is not complete, is not fully human-verified, and needs extensive further validation. Point estimates are the primary output, and how well they are suppor

- [x] G5: unchanged provider checks and documentation render locally
  CHECK: NOT_CRAN=true Rscript --vanilla dev/temporal-ar1/verify.R regression
  EXPECT: TEMPORAL_REGRESSION_PASS
  CWD: .
  EVIDENCE: exit=0; shell=/bin/sh; cwd=/Users/z3437171/.codex/worktrees/cb78/gllvmTMB; path=84c5b90d7dee/38 entries; output=* Fixed at 0.00132 (~1/1000 of sd(y)) to keep the Gaussian density well-defined; the row-level residual variance is fully captured by the per-row diagonal term. | ✔ No problems found.

- [x] G6: independent reviews and local reconciliation identify no unresolved temporal blocking finding
  EVIDENCE: dev/temporal-ar1/REVIEWS.md records resolved independent likelihood and user-workflow findings. Detached clean worktree at commit 184aa685f ran `devtools::check(args = "--no-manual")` in 24m12.7s: 0 errors, 5 warnings, 4 notes, and no temporal failure. The warnings are pre-existing BIC namespace registration, gllvm_julia_fit Rd, and anova.gllvmTMB_multi Rd defects outside this slice. G4 passes under the approved fixture-local revision in dev/temporal-ar1/ACCEPTANCE-REVISION.md.
