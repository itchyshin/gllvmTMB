# After-task report -- COE-04 reciprocal-dependence separability gate

Date: 2026-06-19 01:29 MDT

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

Added one narrow Paper 2 / `COE-04` diagnostic gate. The gate follows the
maintainer Paper 2 note: reciprocal-dependence network weights can still be
too close to the phylogenetic interaction-neighbourhood kernel, so raw `W`
must be screened against residualized `W_tip` before advertising separate
phylogenetic and tip-level coevolution components.

This slice keeps the Paper 2 first wave latent-only. `kernel_unique()` and
source-specific `*_unique()` remain compatibility syntax only and were not
expanded for multi-kernel coevolution.

## Implementation

- `tests/testthat/test-coevolution-two-kernel.R`
  - Added `reciprocal-dependence W needs sensitivity before tip-kernel claims`.
  - Built deterministic link counts from the aligned association pattern.
  - Computed `W_recip = sqrt(p(j|i) p(i|j))`.
  - Compared a raw reciprocal tip kernel against a residualized-plus-opposed
    tip candidate using `diagnose_kernel_separability()`.
  - Asserted the raw reciprocal candidate is `moderate` /
    `sensitivity_required`, while the residualized candidate is
    `near_orthogonal` / `separable_candidate`.

## Documentation and ledgers

- `docs/design/65-cross-lineage-coevolution-kernel.md` records the C3.3
  reciprocal-dependence addendum.
- `docs/design/35-validation-debt-register.md` keeps `COE-04` as `partial`
  and adds the dated diagnostic note.
- `docs/dev-log/check-log.md` records the exact command and outcome.
- `docs/dev-log/dashboard/status.json` and
  `docs/dev-log/dashboard/sweep.json` were updated for the local dashboard.

## Checks

- Pre-edit coordination:
  - `gh pr list --state open`
    -> only draft PR #489 was open.
  - `git log --all --oneline --since="6 hours ago"`
    -> no recent commits.
- Calibration probe before patch:
  - raw reciprocal tip kernel similarity about `0.445`, class `moderate`.
  - residualized-plus-opposed tip kernel similarity about `0.153`, class
    `near_orthogonal`.
- `Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  -> `FAIL 0 | WARN 0 | SKIP 11 | PASS 92`.

## Definition of Done status

- Implementation: local only, not pushed.
- Simulation/recovery evidence: fast pre-fit diagnostic gate covered; not a
  fitted recovery or interval-calibration gate.
- Documentation: design, register, check log, dashboard, and after-task report
  updated.
- Runnable example: not applicable; this is an internal evidence gate.
- Check-log entry: present.
- Review pass: Curie/Fisher-style self-audit through the alignment table; no
  likelihood, formula grammar, or public API changed.

## Still not claimed

- No fitted recovery evidence from this slice.
- No formal identifiability proof.
- No scientific coverage completion.
- No in-engine `rho` estimation, `rho` intervals, or interval calibration.
- No mechanistic validation or empirical trait/data audit.
- No broader non-Gaussian or mixed-family coverage beyond the existing narrow
  Poisson recovery pair.
- No `kernel_unique()` / `*_unique()` removal or Paper 2 expansion.
