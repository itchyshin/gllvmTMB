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

## Rose claim audit (R4 closeout, 2026-09-06)

Internal only. This section is the Slice D Rose claim audit. It does not
authorise NEWS, README, pkgdown, register promotion, merge, or a public
capability claim.

**Admitted claim (internal, development):** one Gaussian source of the
public form `kernel_latent(unit, K = K, d = 1, unique = TRUE)` can be
marshalled through the Julia bridge, with K aligned to the `unit` levels,
source `B = Lambda Lambda' + Psi` returned by `extract_Sigma(..., level =
"kernel")`, and `cov2cor(B)` compared to a TMB fit of the same formula.

**Live paired-cell evidence:**
`TALLY failed=0 skipped=0 error=0 warning=0 passed=20`
(extractor 4 + rejection 7 + paired logLik / B / cov2cor(B) 9). Recorded
in `.unlazy/julia-fixed-dense-kernel/GATES.md` R2/R3 and in the
2026-09-06 check-log entries. This is one local cell, not a multi-seed
recovery and not a true-parity certificate.

**Public-surface scan (this branch vs `origin/main`):** `NEWS.md`,
`README.md`, and `DESCRIPTION` are unchanged. `rg` of `NEWS.md` /
`README.md` for `kernel_latent(unit`, `dense-K Julia`, and
`public capability` returned no hits. No register row was moved to
`covered`.

**Not claiming:** true parity; Class-1 promotion; Totoro/DRAC campaigns;
M2 / Destination B / arc A work; #1236 merge; intervals; non-Gaussian
rows; multi-source kernels; `kernel_unique()`; REML; offsets; weights;
masks; covariates; or any user-facing capability.

**#1236 disposition:** parked / reassigned. Draft remains OPEN
([#1236](https://github.com/itchyshin/gllvmTMB/pull/1236));
[comment 5560055805](https://github.com/itchyshin/gllvmTMB/pull/1236#issuecomment-5560055805)
records Cursor/Ada ownership of this bounded cell. No dual-write onto
the Claude draft paths in this closeout.

Rose verdict (claim audit): PASS WITH NOTES — file exists, cites
no-public-claim, and cites paired PASS 20. The notes are the same
scope fence as above.
