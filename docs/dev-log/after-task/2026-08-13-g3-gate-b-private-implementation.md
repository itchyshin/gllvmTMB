# After Task: private G3 Gate-B implementation and smoke packets

**Branch**: `codex/two-paper-global-analysis`
**Date**: 2026-08-13
**Roles (engaged)**: Ada, Gauss, Noether, Fisher, Rose

## 1. Goal

Implement and independently verify the sealed private G3 full-vector,
same-objective Newton candidate, then prepare two exact smallest-smoke packets
without executing either Paper 1 or Paper 2 model.

## 2. Implemented

The private internal helper evaluates only the unchanged already-constructed
objective at the fixed nine-step grid `2^-(0:8)`. It requires an iSDM,
code-zero, unbounded-retry-free, no-AGHQ/no-ridge/no-profile raw state; an
ordered objective/map/data/control/start/selection signature; a unique raw
maximum in `(1e-3, 1e-2)`; and a PD, conditioned raw Hessian. Every trial is
retained, has fresh curvature checked, and the first qualifying alpha is the
only selected acceptance. Two seed-pinned no-run packets now specify Paper 1
`S=3,C=360,r=3` and Paper 2 `S=6,C=360,r=3`.

**Mathematical contract:** \(\theta(\alpha)=\theta_0-\alpha H_0^{-1}g_0\),
\(\alpha\in\{1,1/2,\ldots,1/256\}\); an accepted trial additionally needs
a non-increasing same objective, `max(abs(g_candidate)) <= 1e-3`, and fresh PD
candidate curvature with condition <= `1e8`. No likelihood, DGP, transform,
map, formula grammar, public API, family, or threshold was changed.

## 4. Files Touched

- `R/fit-multi.R`: private internal G3 numerical primitive only.
- `dev/isdm-package-recovery/g3-full-vector-polish-contract.R`: exact
  all-attempt receipt validator.
- `tests/testthat/test-g3-full-vector-polish-contract.R`: pure contract tests.
- `tests/testthat/test-g3-compiled-cloglog-unit.R`: compiled cloglog objective
  acceptance, all-rejection, and signature-failure tests.
- `dev/isdm-package-recovery/2026-08-13-g3-paper1-smallest-smoke-packet.md`
  and `2026-08-13-g3-paper2-smallest-smoke-packet.md`: immutable, no-run
  proposals.
- `tests/testthat/test-g3-smallest-smoke-packets.R`: packet fence tests.
- `docs/dev-log/check-log.md` and this report: private provenance.

No README, NEWS, ROADMAP, pkgdown, vignette, roxygen, generated Rd, or public
validation-debt surface changed; no convention-change cascade applies.

## 3a. Decisions and Rejected Alternatives

- **Decision:** retain every alpha, selecting only the first qualified one.
  **Rationale:** deterministic and auditable; a later qualified step remains
  evidence, not a hidden retry. **Rejected:** stop at first success.
- **Decision:** prepare but do not execute local smokes. **Rationale:** this
  Gate-B task is implementation/evidence preparation only. **Rejected:** infer
  recovery or run a fit from a passing compiled unit.

## 5. Checks Run

```sh
Rscript --vanilla -e 'devtools::test(filter = "g3-(full-vector-polish-contract|compiled-cloglog-unit|smallest-smoke-packets)", reporter = "summary")'
# PASS: pure contract, smoke-packet fence, and tiny compiled TMB cloglog unit.

Rscript --vanilla dev/isdm-package-recovery/run-g3-full-vector-no-fit-validation.R
# PASS: G3_FULL_VECTOR_NO_FIT_CONTRACT_PASS.

git diff --check
# PASS.
```

The compiled unit used a temporary three-coordinate cloglog fixture only; it
did not construct or fit either iSDM.

## 6. Tests of the Tests

The compiled unit first failed because TMB returned a `1 x 3` gradient matrix;
the failure was diagnosed and the helper now explicitly makes the named vector.
It covers a feature combination (compiled cloglog objective plus full-vector
step), a bound-rejection case retaining all nine rows, and malformed-signature
rejection. Pure tests cover non-PD curvature, tied maxima, reordered Hessians,
signature mismatch, incomplete grids, and selected-trial integrity.

## 8. Consistency Audit

```sh
rg -n 'g3|G3|full-vector|MakeADFun\(|\.gll_isdm_fit\(|nlminb\(|optim\(|profile\(|download\s*\(' R/fit-multi.R dev/isdm-package-recovery/g3-full-vector-polish-contract.R dev/isdm-package-recovery/run-g3-full-vector-no-fit-validation.R tests/testthat/test-g3-compiled-cloglog-unit.R tests/testthat/test-g3-smallest-smoke-packets.R
# PASS: the only MakeADFun is the explicit tiny compiled-unit fixture; G3 source has no fit/optimiser/profile/download path.

rg -n 'G2N_LOCAL_PRERUN_HOLD|G2K_CALIBRATION_HOLD|G2C_SMOKE_ADMISSION_HOLD|PAPER2_PRIVATE_STOP_HOLD|PRIVATE_NUMERICAL_ADMISSION_HOLD' dev/isdm-package-recovery/2026-08-13-g3* dev/isdm-package-recovery/g3-full-vector-polish-contract.R
# PASS: Paper 1 Case-D and Paper 2 Case-C/Psi historical fences remain visible; the three protected historical hold names are unchanged elsewhere.
```

## 7. Roadmap Tick

**Roadmap tick:** N/A — this is a private, non-public Gate-B safeguard.

## 7a. Issue Ledger

No relevant open issue; no new issue created. Open PRs #955–#960 were inspected
for shared-document collision and concern unrelated package/release lanes.

## 9. What Did Not Go Smoothly

The initial compiled fixture exercised a gradient matrix shape and a tied raw
maximum that would legitimately fail closed. Keeping those failures visible
revealed missing vector normalization and receipt-schema details before any
iSDM smoke could be proposed.

## 11. Team Learning

**Ada:** kept the slice private and no-run, while returning each independent
review finding to implementation rather than treating a passing first test as
completion.

**Gauss/Noether:** required fresh trial Hessians, a unique selected alpha, and
exact binding between the selected candidate and retained trial receipt.

**Fisher:** required a complete nine-trial ledger and made unbounded bound
validation consistent across pure and compiled contracts.

**Rose:** verified historical Paper 1/Paper 2 fences and required full per-trial
provenance rather than a summary-only rejection record.

## 10. Known Residuals

Gate B **approves requesting execution only**, not a numerical/recovery claim.
The prepared packets estimate 10–15 minutes for Paper 1 and 15–25 minutes for
Paper 2, both below the 30-minute line, but each still needs explicit maintainer
approval before any fit. The future smoke runner must derive and hash each
signature at its runner boundary; the helper deliberately consumes that sealed
receipt rather than constructing model components itself. `G2N_LOCAL_PRERUN_HOLD`,
`G2K_CALIBRATION_HOLD`, `G2C_SMOKE_ADMISSION_HOLD`, and
`PAPER2_PRIVATE_STOP_HOLD` remain historical and unchanged.

## 12. Cross-Product Coverage

This evidence covers only the private G3 numerical primitive and two prepared
one-fixture smoke packets. It does not cover a completed fit, recovery,
spatial-field separation, Psi recovery, a second source law, empirical data,
scale, public documentation, or reader-facing claim.
