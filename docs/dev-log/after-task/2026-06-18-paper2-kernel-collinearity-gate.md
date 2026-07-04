# After-task report -- Paper 2 pre-fit kernel-collinearity gate

Date: 2026-06-18 18:11 MDT

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

Added the next narrow `COE-04` gate after the Paper 2 estimand and separability
audit: a deterministic pre-fit simulation of kernel-collinearity regimes for
`K_phy` and candidate `K_tip` definitions.

This slice keeps the Paper 2 first wave latent-only. `kernel_unique()` and
source-specific `*_unique()` remain compatibility syntax only; they were not
expanded for multi-kernel coevolution.

## Implementation

- `tests/testthat/test-coevolution-two-kernel.R`
  - Added `kernel-collinearity simulation gate separates Paper 2 claim regimes`.
  - Built `K_phy` from the aligned association pattern and a residualized/opposed
    `K_tip` candidate.
  - Blended `K_tip(alpha) = alpha K_phy + (1 - alpha) K_tip_resid`.
  - Checked monotone off-diagonal Frobenius-style similarity and the expected
    `diagnose_kernel_separability()` recommendations:
    `near_orthogonal -> separable_candidate`,
    `moderate -> sensitivity_required`,
    `high -> collapse_or_single_covariance`.

## Documentation and ledgers

- `NEWS.md` now records the deterministic pre-fit collinearity gate as a
  claim-boundary screen, not scientific promotion.
- `docs/design/65-cross-lineage-coevolution-kernel.md` now lists the gate in
  C3.3 and removes the stale statement that formal collinearity simulation is
  entirely open beyond the helper.
- `docs/design/35-validation-debt-register.md` keeps `COE-04` as `partial` and
  names the deterministic pre-fit collinearity gate as evidence.
- `docs/dev-log/check-log.md` records the exact test command and the deliberate
  non-claims.
- `docs/dev-log/dashboard/status.json` and `docs/dev-log/dashboard/sweep.json`
  were updated for the live mission-control board.

## Checks

- Pre-edit coordination:
  - `gh pr list --state open`
    -> only draft PR #489 was open.
  - `git log --all --oneline --since="6 hours ago"`
    -> recent commits were the current coevolution stack.
- Exploratory alpha probe:
  - `alpha = 0` -> similarity `0.1588016`, `near_orthogonal`.
  - `alpha = 0.15` -> similarity `0.6290093`, `moderate`.
  - `alpha = 0.25` -> similarity `0.8108305`, `high`.
  - `alpha = 1` -> similarity `1`, `high`.
- `Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel|coevolution-recovery", reporter = "summary")'`
  -> passed with 13 expected heavy skips.

## Definition of Done status

- Implementation: local only, not pushed.
- Simulation/recovery evidence: pre-fit deterministic collinearity gate covered;
  this is not fitted recovery or interval calibration.
- Documentation: design, NEWS, validation register, check log, dashboard updated.
- Runnable example: not applicable; this is a test/ledger gate, not a new user
  workflow.
- Check-log entry: present.
- Review pass: self-audit only in this slice; no likelihood or formula grammar
  changed.

## Still not claimed

- No formal identifiability proof.
- No scientific coverage completion.
- No in-engine `rho` estimation, `rho` intervals, or interval calibration.
- No module extraction, mechanistic validation, or empirical trait-data audit.
- No broader non-Gaussian or mixed-family coverage beyond the existing narrow
  Poisson recovery pair.
- No `kernel_unique()` / `*_unique()` removal or Paper 2 expansion.
