# After Task: Design 86 Arc 2 Gate-2 correctness-anchor smoke stop

## 1. Goal

Build the private Gate-2 EVA and unchanged-live-Laplace runners on the approved
information-rich fixture, smoke one seed locally, and run Totoro only if that
smoke is green.

## 2. Implemented

The approved fixture is frozen with a contract checksum receipt.  The private
EVA runner, deterministic input generator, immutable input-manifest receipt,
and live-Laplace runner are present under `dev/`; none is exported.  The first
EVA smoke emitted its input manifest and arm receipt but failed the frozen
EVA start gate.  This is a **NO-GO / STOP**, not a recovery or performance
claim.  The live comparator was started on the same manifest but was stopped
once the EVA failure made the two-arm smoke red; it has no result receipt.

## 3a. Decisions and Rejected Alternatives

For each complete row, the private objective is the frozen Bernoulli-logit
second-order EVA objective with `Sigma_B = Lambda Lambda'`, `q = 2`, no Psi,
and all variational coordinates ordinary TMB parameters (`random = NULL`).
The interval implementation uses the signed frozen joint negative Hessian
Schur complement over `a`, `log_A_diag`, and `A_off`.  No public R API,
shipped likelihood, formula grammar, family, NAMESPACE, generated Rd,
vignette, or pkgdown navigation changed.

## 4. Files Touched

- `docs/design/86-eva-gate2-anchor-parameters.json`,
  `docs/design/86-eva-sparse-binary-admission-contract.md`, and
  `docs/design/86-gate2-build-brief.md`: approved freeze and checksum receipt.
- `R/eva-proto.R`, `dev/design86-gate2-eva-runner.R`, and
  `dev/design86-gate2-laplace-runner.R`: private prototype and runner support.
- `tests/testthat/test-design86-gate2-input-contract.R`: deterministic input,
  packed-loading, and invalid-seed checks.
- No README, NEWS, ROADMAP, NAMESPACE, DESCRIPTION, `man/`, vignette,
  `src/gllvmTMB.cpp`, or validation-debt-register file changed.

## 5. Checks Run

- Frozen fixture JSON, seed checksum, and fixture SHA-256: PASS.
- Packed loading reconstruction and `crossprod(Lambda) = 6 I_2`: PASS.
- Targeted input-contract test: 8 expectations, 0 failures.
- `git diff --check`: PASS; `git diff origin/main -- src/gllvmTMB.cpp`: empty.
- EVA local smoke, seed 86200001: input manifest SHA-256
  `dc01e37b02634f5b0de02f6c1b83e2941aafeb53ca5e4969f06a4ec62d585f63`;
  information Q10 = 0.7518268378 (floor 0.35), but zero of four starts was
  healthy.  Maximum absolute gradients were 0.1589847, 0.0274503, 0.3654799,
  and 8.4345128, all above `1e-4`.  Thus there is no selected winner, no
  Schur interval, and the failure counts as collapsed by the frozen rule.
- No Totoro/DRAC campaign, Gate 3 reference, Gate 4 ladder, package check,
  public documentation build, or objective comparison was run.

## 6. Tests of the Tests

The new test is a deterministic replay and malformed-input boundary check: it
would catch a changed seed/DGP, row order, loading packing, covariance map, or
admission of a seed outside the frozen 500-seed array.

## 7a. Issue Ledger

No relevant open issue; no new issue created because the approved Design-86
contract/dev-log is the maintainer’s active gate record.

## 8. Consistency Audit

`rg -n 'Design 86|EVA|Gate 2' README.md NEWS.md ROADMAP.md docs/design
docs/dev-log/known-limitations.md` found the intended Design-86 private
contract records only; no public capability wording was added.  `rg -n
'gllvmTMB\\(' R vignettes README.md NEWS.md docs/design` was inspected only
to confirm the private runner did not modify public examples.  `rg -n
'meta_known_V|gllvmTMB_wide' README.md NEWS.md docs vignettes` found existing
documented compatibility references, unrelated to this private lane.

## 9. What Did Not Go Smoothly

The first immutable-receipt implementation compared a `json`-class string to
a base character string and rejected an equivalent manifest.  That comparison
is now explicitly character-based and covered by the smoke path.  More
importantly, the fixed EVA optimisation schedule returned code zero without
the required stationarity; the gate correctly refused to select a winner. The
review also found JSON `"NA"` failure values and a loader that records rather
than enforces the approved fixture checksum; both block any later scoring
attempt and do not justify rerunning this frozen red smoke.

## 11. Team Learning

Ada enforced the freeze-before-run and stopped the campaign at the first
failed gate.  Curie’s deterministic-input lens is represented by the replay
test.  Noether found an unaccepted-start scoring path, repaired so selection
now requires both multi-start acceptance and a valid Schur interval. Gauss
confirmed the red numerical gate and named the JSON/checksum work for a future
authorised arc. Rose found no public or shipped-engine spillover.

## 10. Known Residuals

This is not a completed Gate-2 anchor.  There is no Laplace result, recovery,
coverage, covariance-bias, or comparison claim.  The fixed start/optimiser
contract needs a fresh, maintainer-approved diagnosis or amendment before any
new smoke; no fifth/replacement start is permitted under the current freeze.
The scope closeout also found that Arc 2 extended `R/eva-proto.R`; although it
is unexported and the `src/gllvmTMB.cpp` guard is clean, the Gate-2 brief
permits new implementation only in `dev/`. A future authorised repair must
move that Arc-2 support into `dev/` or obtain an explicit versioned amendment.

## 12. Cross-Product Coverage

This arc covers only a private complete Bernoulli-logit `q = 2` input and its
manifest/one-arm smoke gate. It does NOT cover a green live-Laplace result,
recovery, Wald coverage, covariance bias, sparse cells, other ranks/families,
Gate 3 reference comparison, Gate 4 ladders, public dispatch, or a shipped
engine surface. Do not run Totoro. Review the red smoke and decide whether to reject the EVA
prototype or to authorise a new, versioned fixture/optimizer amendment; only
after that decision may another Arc-2 smoke be attempted.  Gate 3 and Gate 4
remain out of scope.  **Roadmap tick:** N/A.  **GitHub issue ledger:** no
relevant open issue; no new issue created because the approved Design-86
contract/dev-log is the maintainer’s active gate record.
