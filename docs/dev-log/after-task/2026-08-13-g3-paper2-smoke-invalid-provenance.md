# After Task: Paper 2 G3 smoke provenance closure

**Branch**: `codex/two-paper-global-analysis`  
**Date**: 2026-08-13  
**Roles (engaged)**: Ada, Gauss, Noether, Fisher, Rose

## 1. Goal

Implement, independently review, preflight, and run one fresh private Paper 2
G3 numerical-admission smoke at `S=6`, `C=360`, `r=3`, `seed=86302`, while
retaining every outcome without converting numerical evidence into recovery or
reader claims.

## 2. Implemented

`run-g3-paper2-smoke.R` seals a source, loaded-DLL, fixture, session, and
all-attempt receipt before the one-start smoke. It uses the frozen G2h DGP with
only the seed changed, gives each outer-coordinate a positional ID without
changing its numeric value or order, and retains terminal fit, Hessian, and
provenance failures.

The resulting root is a terminal **pre-optimizer `INVALID_PROVENANCE`**
attempt. It has no `fit.rds`, `fit_elapsed_s = NA`, `raw = NULL`, and `g3 =
NULL`. The source and DLL MD5s match the preflight receipt; the only mismatch
is the ephemeral `devtools::load_all()` DLL path. The packet makes that
mismatch terminal, so it cannot be repaired or rerun under this packet.

## 3a. Decisions and Rejected Alternatives

**Decision:** retain the smoke as a terminal invalid-provenance attempt.
**Rationale:** the sealed packet makes any signature mismatch terminal.
**Rejected:** recategorising the pre-optimizer stop as a failed fit, changing
the receipt rule retrospectively, or creating a replacement root.

## 3. Mathematical Contract

The estimator, GBIF Poisson plus repeated PA cloglog likelihood, rank-one
`Lambda`, diagonal `Psi`, `theta_diag_B = log(psi)` transform, DGP, maps,
controls, starts, and thresholds did not change. The runner would evaluate
`theta(alpha) = theta_0 - alpha H_0^{-1} g_0` only after proving that the
ordinary selected NLL equals the G3 `obj$fn(theta_0)` within fixed floating
point tolerance. It never reached that step. No public R API, likelihood,
formula grammar, family, NAMESPACE, generated Rd, vignette, or pkgdown
navigation changed.

## 4. Files Touched

- `dev/isdm-package-recovery/run-g3-paper2-smoke.R`: private sealed runner.
- `tests/testthat/test-g3-paper2-smoke-runner.R`: runner fence test.
- `docs/dev-log/check-log.md`, this report, and the recovery checkpoint:
  private provenance and handover record.

No README, NEWS, ROADMAP, validation-debt register, vignette, public article,
or generated documentation changed; no convention-change cascade applies.

## 5. Checks Run

```sh
Rscript --vanilla -e 'devtools::test(filter = "g3-(paper2-smoke-runner|full-vector-polish-contract|smallest-smoke-packets)", reporter = "summary")'
# PASS: focused no-fit contract tests.

Rscript --vanilla dev/isdm-package-recovery/run-g3-paper2-smoke.R --mode=validate ...
# PASS: G3_P2_SMOKE_RUNNER_VALIDATION_PASS (no fit).

Rscript --vanilla dev/isdm-package-recovery/run-g3-paper2-smoke.R --mode=preflight ...
# PASS: G3_P2_PREFLIGHT_PASS (no fit).

Rscript --vanilla dev/isdm-package-recovery/run-g3-paper2-smoke.R --mode=smoke ...
# Terminal result: INVALID_PROVENANCE; no optimizer entry or fit artifact.

Rscript --vanilla -e 'x <- readRDS("dev/isdm-package-recovery/results/G3_P2_S6_C360_R3_V1/all-attempt-ledger.rds"); stopifnot(identical(x$status,"INVALID_PROVENANCE"), isTRUE(x$terminal), is.na(x$timing$fit_elapsed_s), is.null(x$raw), is.null(x$g3), !file.exists("dev/isdm-package-recovery/results/G3_P2_S6_C360_R3_V1/fit.rds")); cat("P2_INVALID_PROVENANCE_RECEIPT_VALID\\n")'
# PASS: terminal receipt and no-fit absence verified.

git diff --check
# PASS before each source commit.
```

## 6. Tests of the Tests

The runner test is a boundary/feature-combination test: it pins the fresh seed,
one-shot time limit, all-attempt artifact, provenance and unavailable-Hessian
statuses, positional coordinate IDs, and bans profile/retry/remote code. The
first independent review found that the initial finalizer started too late and
that the DLL path was treated as stable. The first defect was fixed before the
smoke; the second was revealed by the terminal, retained smoke root rather
than being silently bypassed.

## 8. Consistency Audit

```sh
rg -n 'PAPER2_PRIVATE_STOP_HOLD|G2N_LOCAL_PRERUN_HOLD|G2K_CALIBRATION_HOLD|G2C_SMOKE_ADMISSION_HOLD' docs/dev-log dev/isdm-package-recovery
# PASS: protected historical holds remain visible and unchanged.

rg -n 'G3_P2|INVALID_PROVENANCE|G3_HESSIAN_UNAVAILABLE|profile_theta\\(|nlminb\\(|TMB::MakeADFun\\(|Totoro|DRAC' dev/isdm-package-recovery/run-g3-paper2-smoke.R tests/testthat/test-g3-paper2-smoke-runner.R
# PASS: one P2 runner has explicit terminal states and no profile, retry, or remote path.
```

## 8. Roadmap Tick

**Roadmap tick:** N/A — private numerical-admission evidence only.

## 7a. Issue Ledger

Open PRs #955–#960 were inspected for dev-log collisions. No relevant issue
exists for this private, packet-bound provenance failure; no issue was created,
commented on, or closed.

## 9. What Did Not Go Smoothly

`devtools::load_all()` loads the compiled DLL from a new temporary directory
on each process. The preflight and smoke used byte-identical DLLs, but the
runner also compared those temporary paths. This made the smoke invalid before
the optimizer. The generic receipt error did not retain the field-by-field
comparison, so a future provenance-design amendment must record it explicitly.

## 11. Team Learning

**Ada:** kept the root immutable after the first terminal result and separated
the runner defect from model evidence.

**Gauss/Noether:** confirmed that no numerical admission occurred and that a
later runner correction cannot reclassify this packet-bound attempt.

**Fisher:** confirmed that this root supports no admission, recovery, Psi,
spatial-separation, or operational claim, and recommended retaining the
historical Paper 2 STOP/HOLD.

**Rose:** required that the closure distinguish an invalid launch from a failed
fit and record the no-fit artifact absence and transient-path mechanism.

## 10. Known Residuals

Paper 1 and Paper 2 each have an invalid-provenance fresh smoke root; neither
is a numerical result. `PAPER2_PRIVATE_STOP_HOLD` remains the only substantive
Paper 2 verdict. No recovery campaign, Totoro/DRAC work, model repair, reader
packet, article evidence, or public claim is admitted.

The next action requires explicit approval for a **new no-fit provenance-design
amendment** that removes transient DLL-path identity from the immutable
criterion while retaining content hashes, captures expected-versus-observed
receipt fields, leaves both invalid roots untouched, and creates a new packet.
It does not authorise another fit.

## 12. Cross-Product Coverage

This record covers one Paper 2 runner, its receipt mechanics, and one terminal
pre-optimizer provenance outcome. It does NOT cover Paper 1 numerical evidence,
Paper 2 numerical admission, recovery, Psi recovery, spatial separation,
empirical data, scale, reader material, or public capability.
