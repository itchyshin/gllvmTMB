# After-task — D-220 kernel-latent unique bridge

**Date:** 2026-09-06  
**Owner:** Cursor/Ada  
**Scope:** bounded Gaussian dense-K `kernel_latent(..., unique = TRUE)` bridge slice.

Implemented the R bridge marshalling for one named dense kernel, including
label alignment, source `B = Lambda Lambda' + Psi` extraction, and explicit
gates for unsupported source combinations, non-Gaussian rows, masks,
covariates, weights, REML, offsets, and intervals. Added focused extractor,
rejection, and paired-cell tests. No TMB engine file was changed.

Evidence:

- R parse and focused package tests: **7 expectations passed, 1 skipped**
  without a configured Julia path.
- The live paired cell exited 0 with `GLLVM_JL_PATH` configured. It is one
  local paired cell and is not promoted to a parity claim.
- Julia-side regression: **11/11 passed**, covering non-identity K, repeated
  groups, and `unique = true`.

Rose audit: no NEWS or public capability claim was added. True parity,
Class-1 promotion, M2-R2, Totoro/DRAC work, push, merge, and release remain
out of scope.
