# After Task: G2o no-fit iJSDM postmortem

**Branch**: `codex/isdm-g2o-postmortem`  
**Date**: 2026-08-12  
**Roles (engaged)**: Ada, Gauss, Fisher, Noether, Rose

## 1. Goal

Use only the retained G2k and G2n six-species iJSDM artifacts to determine
what the Case-C `b_fix` score and diagonal-Psi recovery miss do—and do not—say
about numerical calibration, parameter scaling, finite information, and model
scope. No new fit or estimator implementation was authorized.

## 2. Implemented

The private `run-g2o-postmortem.R` validates exact retained roots and produces
a reproducible fixed-point certificate: parameter-block scores, covariance
conditioning, covariance-scaled scores, truth-to-estimate Psi geometry, lower
profile summaries, and retained G2k frequency summaries. The certificate and
reconciliation receipt preserve `G2N_LOCAL_PRERUN_HOLD`,
`G2K_CALIBRATION_HOLD`, and `G2C_SMOKE_ADMISSION_HOLD`.

**Mathematical contract:** no public R API, likelihood, formula grammar,
family, NAMESPACE, generated Rd, vignette, pkgdown navigation, DGP, map,
source gate, seed grid, threshold, or recovery metric changed. For the stored
parameter vector, G2o evaluates \(g=\nabla\ell(\hat\theta)\) and reports
\(Vg\), where \(V=\mathrm{cov.fixed}\), as a covariance-scaled score. The
Newton update would be \(-Vg\); G2o never constructs or evaluates that update.

## 4. Files Touched

- `dev/isdm-package-recovery/run-g2o-postmortem.R` — private retained-artifact
  certificate runner.
- `tests/testthat/test-g2o-postmortem.R` — validation and static no-fit guard.
- `dev/isdm-package-recovery/2026-08-12-g2o-postmortem-certificate.md` —
  symbolic alignment, interpretation boundary, and decision table.
- `docs/dev-log/plan-actual/2026-08-12-g2o-postmortem-reconciliation.md` —
  provenance receipt and forward boundary.
- `docs/dev-log/after-task/2026-08-12-g2o-no-fit-postmortem.md` — this report.
- `docs/dev-log/check-log.md` — compact task receipt.

Status-inventory cascade: `README.md`, `ROADMAP.md`, `NEWS.md`,
`docs/dev-log/known-limitations.md`, `docs/design/`, `_pkgdown.yml`, vignettes,
and generated `man/*.Rd` were deliberately untouched: G2o makes no public
capability or interface claim.

## 3a. Decisions and Rejected Alternatives

**Decision:** `G2O_NO_FIT_DESIGN_ONLY_GO`.

The G2n `b_fix` residual is a confirmed admission failure, but the marginal
six-coordinate block alone cannot diagnose full-Hessian geometry, demonstrate
an objective/parameter scaling cause, or admit a retry/Newton repair. The
diagonal-Psi error is consistent with limited variance-partition information,
but no retained comparison identifies it as the sole cause or a model/estimand
limitation. Rejected: relaxing the raw gradient criterion; treating \(Vg\) as
convergence; implementing an optimizer repair; adding zero inflation or
spatial structure; and claiming that weak lower profiles explain Psi recovery.

## 5. Checks Run

```sh
env TMPDIR=/private/tmp Rscript --vanilla -e 'devtools::test(filter = "g2o-postmortem", reporter = "summary")'
# PASS: 5 expectations.

env TMPDIR=/private/tmp Rscript --vanilla dev/isdm-package-recovery/run-g2o-postmortem.R --mode=validate ...
# PASS: G2O postmortem validation PASS (no fit).

env TMPDIR=/private/tmp Rscript --vanilla dev/isdm-package-recovery/run-g2o-postmortem.R --mode=report ... --output=dev/isdm-package-recovery/results/g2o-postmortem-20260812-002
# PASS: G2O postmortem report PASS (no fit).

git diff --check
# PASS.
```

The report uses the completed 150/150 private FIR campaign through the G2k
diagnostic root, not the earlier incomplete Totoro root. `gh pr list --state
open --limit 20` was attempted for the shared-file coordination check but could
not contact `api.github.com`; local `git log --all --oneline --since='6 hours
ago'` found no conflicting G2o work.

## 6. Tests of the Tests

The validation test is a boundary/path test: it verifies required retained
roots and confirms validate mode creates no output root. The static test is a
prophylactic scope guard for fitter, optimizer, profiler, and simulator tokens.
It would catch an accidental G2o widening into a new model run. The report
itself independently re-aggregates the retained parameter and Psi summaries.

## 8. Consistency Audit

- `rg -n "G2O_NO_FIT_DESIGN_ONLY_GO|G2o|G2N_LOCAL_PRERUN_HOLD|G2K_CALIBRATION_HOLD|G2C_SMOKE_ADMISSION_HOLD" dev/isdm-package-recovery tests/testthat docs/dev-log/plan-actual docs/dev-log/after-task` — PASS: all three historical HOLDs remain explicit; the sole new label is design-only.
- `rg -n "gllvmTMB\\(|integrated_jsdm\\(|zero inflation|spatial" dev/isdm-package-recovery/run-g2o-postmortem.R dev/isdm-package-recovery/2026-08-12-g2o-postmortem-certificate.md tests/testthat/test-g2o-postmortem.R docs/dev-log/plan-actual/2026-08-12-g2o-postmortem-reconciliation.md` — PASS: only NO-GO scope wording; no new callable API or model claim.
- `rg -n "nlminb\\(|MakeADFun\\(|\\.gll_isdm_fit|profile_theta" dev/isdm-package-recovery/run-g2o-postmortem.R tests/testthat/test-g2o-postmortem.R` — PASS: no prohibited execution route in the G2o runner; the static test names the forbidden forms.

## 7. Roadmap Tick

**Roadmap tick:** N/A. This is a private diagnostic gate, not a public roadmap
or capability change.

## 7a. Issue Ledger

No relevant open issue; no new issue created. Issue #953 was explicitly out of
scope. Network prevented a live GitHub list query, and no tracker state was
changed.

## 9. What Did Not Go Smoothly

The first numerical review correctly found that \(Vg\) had been called a
“movement” even though the Newton update has the opposite sign. The runner and
certificate now call it a covariance-scaled score. Review also narrowed the
conditioning conclusion and corrected the provenance wording so the valid
150/150 FIR denominator cannot be confused with the incomplete Totoro root.
The sandbox required an explicit local-write authorization to rerun the
private no-fit check after those corrections.

## 11. Team Learning (per AGENTS.md Standing Review Roles)

**Ada:** retained-artifact diagnosis needs as much provenance discipline as a
new campaign; campaign denominators cannot be inferred from a nearby root.

**Gauss:** `Vg` is a diagnostic score; its sign and its non-candidate status
must be explicit whenever an objective gradient is reported.

**Noether:** the symbolic \(g\), \(Vg\), and \(-Vg\) distinction prevents a
descriptive postmortem from silently becoming an estimator proposal.

**Fisher:** the evidence supports a possible Psi-information concern, not a
causal attribution or model/estimand conclusion. Any future calibration claim
needs a separately designed comparison.

**Rose:** a low within-block condition number does NOT cover cross-block
geometry, and an incomplete campaign does NOT cover its intended denominator.

## 10. Known Residuals

G2o does NOT cover a new fit, optimizer repair, recovery campaign, repeated
detection extension, spatial model, structural-zero model, public workflow, or
either staged article. The only admissible next task is a fresh design-only
estimator-and-Psi calibration specification, with algebraic invariants,
adversarial no-fit tests, and a pre-registered information comparison. It must
return for approval before any fit or implementation. The iJSDM remains a
private, not-yet-public capability.

## 12. Cross-Product Coverage

N/A: G2o has no public interface, formula, family, documentation, or article
surface. It does NOT cover every cross-product model combination; the only
exercised path is a retained-artifact, fixed-point diagnostic.
