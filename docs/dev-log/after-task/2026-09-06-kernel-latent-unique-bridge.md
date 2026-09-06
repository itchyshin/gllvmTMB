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
- The live paired cell exited 0 with `GLLVM_JL_PATH` configured. It uses the
  public `kernel_latent(unit, K = K, d = 1, unique = TRUE)` formula under
  both `engine = "julia"` and `engine = "tmb"`, aligns the named K levels,
  and compares logLik (1e-3), B (1e-2), and cov2cor(B) (1e-2). It is one
  local paired cell and is not promoted to a parity claim.
- Julia-side regression: **11/11 passed**, covering non-identity K, repeated
  groups, and `unique = true`.

Rose audit: no NEWS or public capability claim was added. True parity,
Class-1 promotion, M2-R2, Totoro/DRAC work, merge, and release remain out of
scope.

Follow-up reverify: the R payload now rejects a non-positive-definite K before
Julia is invoked (strict `chol()` after factor-level alignment; no jitter).
The focused live suite was rerun with the dedicated Julia project and returned
**[ FAIL 0 | WARN 0 | SKIP 0 | PASS 20 ]**. The added controls cover
unlabelled, asymmetric, non-PD, and misaligned K. This strengthens only the
admitted one-source Gaussian route and does not widen the claims above.

The package-prescribed targeted command `devtools::test(filter =
"kernel-latent-unique-bridge", reporter = "summary")` also completed with
the Julia project configured. Full `R CMD check` remains a CI-before-merge
gate; no PR or merge is authorized in this slice.

Closure: the verified branch was pushed to origin after the focused reverify.
No PR, merge, release, or public capability promotion was performed.

Rose verdict: PASS WITH NOTES — the retained evidence supports only the
admitted one-source Gaussian Julia route. Full package checking and CI remain
required before any merge or public capability promotion.
