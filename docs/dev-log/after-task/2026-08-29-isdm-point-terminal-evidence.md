# After Task: Integrated-JSDM point terminal evidence

**Branch**: `codex/isdm-point-terminal-evidence`
**Date**: `2026-08-29`
**Roles (engaged)**: Ada, Curie, Fisher, Rose, Grace

## 1. Goal

Qualify the exact merged public iJSDM source, run the preregistered 14-fit
timing gate and 2,600-attempt point campaign without replacement, adjudicate
the frozen nonspatial, attack, and held-out spatial gates, and retain either
earned evidence or terminal negative receipts. SPDE map uncertainty could begin
only if the spatial point gate passed.

## 2. Implemented or executed

No package implementation changed in this phase. Exact-main GitHub Actions,
the Totoro install, loaded DLL, package files, and relevant source files were
bound in a qualified source contract. The retained pre-run projected 223.2
seconds at 40 one-thread workers. Production then completed 1,600 ordinary
nonspatial attempts, 200 disconnected-support attacks, and 800 held-out spatial
attempts with every planned attempt started and terminal.

The first adjudicator exposed a plan-schema defect: `rbind()` added
ordinary-only pairing columns to attack rows. A checksum-verified v2
adjudication used the immutable fields shared by the native plans. It did not
change a fit, raw receipt, threshold, or estimand.

Independent review found two further v2 scoring defects. V3 reverified the raw
manifest, bound v1/v2, restored unnamed `Psi` only through the exact named
truth/`Sigma` order, and excluded unrelated lifecycle warnings from attack
qualification. The final scientific verdicts did not require a replacement
attempt or threshold change.

## 3. Mathematical and estimand contract

Only rotation-invariant quantities were scored: ecological and
source-observation coefficients, centered relative-intensity surfaces,
`Sigma = Lambda Lambda^T + Psi`, and the preregistered named `Psi` target. Raw
latent axes and unaligned loadings were excluded. V3 bound the unnamed finite
`Psi` estimate to the exact trait order jointly proven by named truth and named
`Sigma`; ambiguous shapes or names fail closed. Presence-only arms identify
relative intensity, not absolute abundance, occupancy, or detectability.

## 3a. Decisions and Rejected Alternatives

**Decision:** retain the failed qualification and zero-start timeout launch,
then resume only work proven not to have started. **Rejected:** delete the
receipts or silently relaunch. **Reason:** the retained record must explain every
operational transition without replacing an attempt.

**Decision:** repair adjudication against the frozen raw manifest. **Rejected:**
rerun attack fits or mutate stored task specifications. **Reason:** the defect
was in combined-plan validation, not simulation or fitting.

**Decision:** stop the programme after the point failures. **Rejected:** retune
surface, `Psi`, RMSE-ratio, or availability gates; launch uncertainty on the
302 eligible spatial fits; or advertise available-only accuracy. **Reason:**
all-attempt denominators and preregistered thresholds define the claim.

**Decision:** supersede the attack `PASS` label with `COMPLETE / STRESS_ONLY`.
**Rejected:** treat an unrelated lifecycle warning as a disconnected-support
diagnostic. **Reason:** the approved amendment made this slice stress-only, and
independent review found zero targeted warnings, refusals, or diagnostics.

## 4. Files Touched

- `dev/isdm-requalification/2026-08-29-point-campaign-terminal-receipt.md`
- `dev/isdm-requalification/terminal-evidence/adjudicate-production-repair.R`
- `dev/isdm-requalification/terminal-evidence/attack-gate.R`
- `dev/isdm-requalification/terminal-evidence/adjudicate-production-v3.R`
- `dev/isdm-requalification/terminal-evidence/adjudication-v3-functions.R`
- `tests/testthat/test-isdm-requalification-terminal-evidence.R`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- this after-task report

No package R, C++, roxygen, generated Rd, NEWS, article, README, or pkgdown
navigation file changed. The dev-only R files preserve the exact v2/v3 sources;
one dedicated regression test covers the terminal-evidence repairs.

## 5. Checks Run

Exact source checks:

```text
origin/main SHA: c5bb0b80a0a733c6d7cb1bab826003bbaa589fe4
tree:            655282a18631700e033319d299e686162b52be97
GitHub Actions:  33262647988
macOS:           PASS, 25m16s
Ubuntu:          PASS, 34m20s
Windows:         PASS, 51m41s
```

Totoro qualification returned
`ISDM_SOURCE_QUALIFIED` and `ISDM_SOURCE_CONTRACT_VERIFIED`. The resumed
pre-run returned `ISDM_POINT_PRERUN_TOTORO_ELIGIBLE`. Production retained 2,600
started and 2,600 terminal records with zero error, interruption, unavailable,
or not-started outcomes. The 10,412-entry raw production manifest passed
`sha256sum -c` before v2 adjudication. The final 10,421-entry evidence manifest
also passed `sha256sum -c`. V3 reverified all 10,412 frozen raw entries, bound
the v1 and v2 receipts, and produced receipt SHA-256
`32c7a9cb325d1e45f015b38b53a8722473e0a9ffc254d3f5e79fb2c6c22001ab`.
Its seven-entry source/receipt chain passed `sha256sum -c`; manifest SHA-256 is
`b452c79c2328a88a1821bee3b1925ccd357c7af1b3dbb4ea7453509127bf9bfa`.

The dedicated v3 terminal-evidence test passed 13 expectations, including the
actual unnamed producer-shaped `Psi`, a mismatched-Sigma refusal, the routine
Psi advisory, a targeted warning, a fit refusal, and an unhealthy fit.

Documentation closeout checks are recorded in the check log. Full package,
pkgdown, article, and three-OS reruns are not required for this evidence-only
append; the exact qualified implementation already passed them and is
unchanged.

## 6. Tests of the Tests

The attack-gate self-test proved that its original operational rule rejected
200 silent converged/PD-Hessian successes and incomplete/unavailable inputs.
Independent review then supplied the more important bite test: all 200 real
warnings were unrelated lifecycle warnings, so the rule was too broad for a
diagnostic PASS. The machine label is retracted and the slice is classified
stress-only. The first combined-plan adjudication separately failed 200
otherwise present attack terminals. V2 verifies the raw manifest first and
validates all 1,800 native nonspatial terminal records without weakening task
identity.

The fixed gates also had bite in production. Perfect convergence and strong
coefficient recovery did not rescue failed surface targets or species-1 `Psi`
relative error 0.390 above the 0.35 gate. Excellent available-only spatial
accuracy did not rescue 37.75% eligible availability.

## 7. Roadmap tick

None. ISDM-01, ISDM-02, and ISDM-03 remain `partial`. This phase adds negative
evidence and closes the approved campaign; it does not broaden a capability.

## 7a. Issue Ledger

Issues #941, #1133, and #1138 remain open. No public capability or uncertainty
issue is closed by failed recovery gates.

## 8. Consistency Audit

The terminal receipt, register addendum, check log, and this report use the
same source SHA/tree, denominators, thresholds, metrics, and claim boundary.
They distinguish the superseded v1 adjudication and retracted v2 attack label
from the checksum-bound v3 verdict and frozen raw attempts. No reader-facing
surface was changed because the campaign earned no promotion.

## 9. What Did Not Go Smoothly

The first qualification process hid `jsonlite` after successfully installing
the package. Qualification resumed with the isolated package library first and
Totoro's dependency library second. The first pre-run command used a GNU
`timeout` string with mixed units; it stopped before any task started. The same
14 registered tasks resumed only after proving zero started and terminal
records. The first production adjudicator then exposed the ordinary/attack
plan-column mismatch. Every failure and correction remains retained.

## 10. Known Residuals

Nonspatial surface recovery failed in the measured design. Corrected `Psi`
availability was 100%, but species 1 median relative error was 0.390, above the
0.35 gate; species 2 and 3 passed at 0.182 and 0.210. Two source-2 weak/full
RMSE ratios also exceeded the gate. Spatial point estimates were accurate
among eligible fits, but strict eligible-fit availability was only 37.75%.
The present programme provides no calibrated map interval and cannot launch
its 4,800-attempt uncertainty campaign.

Any future rescue is a new estimand/design decision with new approval, source
qualification, seeds, and attempts. It cannot replace or pool away this result.

## 11. Team Learning

**Ada:** kept the source and all-attempt denominator immutable through
qualification, operational failures, and adjudication repair.

**Curie:** verified every native plan, task ID, seed, and manifest denominator;
identified the lost `Psi` names and proved the attack warnings were generic,
requiring a stress-only label rather than diagnostic PASS.

**Fisher:** enforced rotation-invariant estimands, frozen thresholds, and the
available-only spatial accuracy boundary.

**Rose:** required byte-level provenance for the failed and resumed operations,
found the pre-run binding gaps before launch and the overbroad attack-warning
semantics during terminal review, and required raw-manifest verification before
corrective adjudication.

**Grace:** exact-main three-OS CI and the installed package/DLL contract prevent
local or stale-source evidence from qualifying the campaign.

## 12. Cross-Product Coverage

Measured: two/three sources; full/weak overlap; 150/810 nonspatial cells; 810
spatial generating cells with 20% in-hull holdout; Poisson-log and
Bernoulli-cloglog sources; ordinary rank-one latent structure; intercept-only
SPDE point maps. Attacks used disconnected support.

This campaign does NOT cover: intervals, structured-source latent terms, SPDE
slopes, phylogenetic/kernel prediction, richer source weights, absolute
abundance, occupancy, detectability, profile/bootstrap intervals, Julia, or
public release readiness.

## 13. Next actions

Close this programme as terminal negative evidence after independent review,
merge the evidence-only PR, verify exact `origin/main`, and release the iJSDM
lease. A future rescue requires a new plan; no automatic uncertainty or
replacement campaign remains.
