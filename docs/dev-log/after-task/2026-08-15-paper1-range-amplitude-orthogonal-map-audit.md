# After Task: Paper 1 range--amplitude orthogonal chart -- map audit, adversarial contract, no-fit gate design

**Branch**: `codex/isdm-range-amplitude-orthogonal`
**Date**: `2026-08-15`
**Roles (engaged)**: `Ada (orchestration) / Noether (map audit + adversarial verification) / Gauss (contract + tests) / Rose (no-fit design, closure) / Shannon (lane pre-flight)`

## 1. Goal

Continue the OWED Next Immediate Steps of
`docs/dev-log/handover/2026-08-15-claude-handover.md`: rehydrate and classify the
protected roots, audit the four-coordinate chart as a mathematical object, extend
pure adversarial coverage, and specify the no-fit/provenance gate as a design.
Closure was defined as *one reviewed design and pure contract, never an admission
claim*.

## 2. Implemented

- **Mathematical audit** of the chart, seven findings (F1--F7), each recomputed
  rather than carried over, plus a verification receipt.
- **Append-only §7 amendment** to the parent design; §1--6 (Codex-authored) left
  byte-intact for provenance.
- **No-fit gate specification**, 808 lines, ten typed status tokens, four gates
  made executable plus three additions forced by the audit.
- **Contract hardening**: `rao_coordinatewise_discrepancy(x, y, atol, rtol)`, a
  mixed absolute/relative criterion with both tolerances required.
- **Adversarial tests**: 13 -> 44 expectations.
- **Sourcing guard** across 30 isdm test files (a defect found in passing, then
  requested for action).

## 3. Files Changed

`10edecc2` -- dev/isdm-package-recovery/{2026-08-15-paper1-range-amplitude-orthogonal-design.md (amended), -map-audit.md (new), -nofit-design.md (new), range-amplitude-orthogonal-contract.R}, tests/testthat/{test-paper1-range-amplitude-orthogonal-contract.R, helper-isdm-dev-contract.R}
`cd3fac12` -- tests/testthat/ 29 files (sourcing guard only)

No file under `R/` or `src/` was touched. No export, no NAMESPACE change, no
NEWS/README/article claim.

## 3a. Decisions and Rejected Alternatives

- **F1 (one kappa, two loading columns): record, do not widen the chart.**
  Maintainer decision. Widening to six coordinates is a materially different
  estimator needing its own identity and review; adapting on zero numerical
  evidence is what this programme is disciplined against.
- **F2 curvature check: reported diagnostic, NOT a gate.** Maintainer decision.
  No threshold on `|A-C|` has evidence behind it; gating would close the lane on
  a criterion manufactured after the design.
- **Gate 2 tolerances: deliberately NOT fixed.** Rejected inventing an `atol`.
  The execution design must measure the objective's central-difference noise
  floor first. Inventing a number here would repeat the exact error F3 records.
- **Landing: local commits only, no push, no PR.** Maintainer decision; matches
  the handover's CARRIED-OVER intent.
- **Rejected** a full `R CMD check` for the sourcing-guard evidence: this package
  compiles TMB/C++ and it would exceed the D-139 30-minute line. A tarball build
  plus extraction tested the claim directly in 19 s.

## 4. Checks Run

```
testthat::test_file("tests/testthat/test-paper1-range-amplitude-orthogonal-contract.R")
  -> 44 expectations, 0 failed        (was 13 at handover)
git diff --check                       -> clean
R CMD build --no-build-vignettes --no-manual
  -> gllvmTMB_0.6.0.tar.gz; dev/ ABSENT, tests/testthat/ present, helper shipped
guarded   test-g2j-psi-diagnostic.R (from tarball) -> 1 skip, 0 failed, 0 errors
unguarded (same file, guard stripped)              -> 0 skip, 1 failed, 1 error
per-file ListReporter baselines, 30 files          -> 29 of 30 identical
```

Sealed MSPDE V3 packet read **read-only**; MD5 `e3b17636c9f5fa0e9e555a307c923724`
verified against the design's declared value. No `MakeADFun`, optimiser, fit,
smoke, result root, or recovery calculation ran at any point.

## 5. Tests of the Tests

Every new guard was shown to **fail against the unhardened contract before being
made to pass**. The F3 remedy was proven red->green by removing
`rao_coordinatewise_discrepancy` and observing both dependent tests fail. The
sourcing guard was proven by the counterfactual above: stripping it turns a clean
skip into a failure and an error.

Two boundary cases (amplitude overflow, amplitude underflow) turned out to fail
loudly already, so they were **pinned rather than patched** -- no threshold was
invented for a case that was not silently wrong.

## 6. Consistency Audit

Function names reconciled across contract, audit, parent design and no-fit spec.
The parent design's stale gradient-scale citation (`0.002431251466981631`, from
the consumed `G3_P1_S3_C360_R3_V3` root) corrected to the MSPDE V3 value
`2.8237e-4`. The audit's own falsified receipt row corrected in place with the
falsifying arithmetic shown.

## 7. Roadmap Tick

Handover slices 1--4 (rehydrate/classify, map audit, adversarial coverage,
no-fit design) complete. Slices 5--7 (live no-fit implementation, numerical
runner, smoke) remain with Codex at the live-TMB boundary, unstarted.

## 7a. GitHub Issue Ledger

None opened or closed. The branch is deliberately unpushed; no PR.

## 8. What Did Not Go Smoothly

**The audit's own first pass was wrong in six places, and an independent
adversarial review found them.** Most seriously, the prescribed fix for F3 --
a per-coordinate relative tolerance -- kept a floor of 1 and therefore passed a
**100% error** on precisely the coordinates the finding existed to protect. It
then emerged that a strictly relative `1e-5` gate is unreachable for all 22
coordinates. The review also showed §4 was missing a condition, F2's derivation
was degenerate at `B = 0`, one F1 sentence was refuted by norm preservation, F5
was under-graded, F7 was missed entirely, and the verification receipt asserted
an identity falsified by this document's own tolerance (27,345x).

Sub-agent briefs carried three convention errors (packet-ID shape for a no-fit
gate, `.parent-stage.rds` as a permanent slot, marker/ledger as settled
precedent) which the assigned agent caught and flagged rather than following.
The chip filed for the sourcing guard estimated ~55 files; the real figure was
31, of which 30 needed the fix.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Two independent agents converged on the same defect** (the metric floor) from
different directions, and a third adversarial pass found four more. A finding
that survives attack and one waved through are not the same evidence -- the
audit now records what review overturned rather than absorbing it silently.

The generalisable lesson, and it is not local to this lane: **a fixed orthogonal
reparameterisation cannot improve conditioning.** It preserves eigenvalues and
decorrelates only when the two curvatures are already equal; it can as easily
create or amplify a cross-term. Any future "rotate to decouple" proposal in this
family of packages should be met with that check first.

Second: **an error metric with a floor is an absolute test below the floor.**
`max(|x-y|)/max(1, ...)` and `max(|x-y|/pmax(1, ...))` both fail this way, and
the second looks like a fix for the first.

## 10. Known Limitations And Next Actions

- **The sign-orbit gate is load-bearing and untested.** The chart maps onto
  `R x {lambda_1 > 0}`, not `R^4`, so the no-Jacobian argument's *optimum* half
  is unproven until it passes. The chart is established for objective **values**
  only. It should be sequenced **first** among the live gates, not third.
- **Gate 2's `atol`/`rtol` are unset by design.** The execution design must
  measure the noise floor before choosing them.
- **The contract still does not check its own determinant** (F5), and the
  execution design owns the floor.
- **Two test files remain unguarded** for a different call shape
  (`test-bfgs-smoke-contract.R`, `test-g2o-postmortem.R`): they would FAIL rather
  than skip in a tarball run. Flagged, not fixed -- a separate defect.
- **The brain and the coordination board hold no record of this programme.**
  `AGENT_LOG.md` and `DECISIONS.md` return zero hits for `isdm`,
  `range.amplitude`, `orthogonal chart` or `gauge trust`; the board has no isdm
  entries. The handover forbids editing the board from this branch, so this is
  recorded, not acted on. It needs an owner.
- Branch remains **unpushed, no PR**, per maintainer decision.
