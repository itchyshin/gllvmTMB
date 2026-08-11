# After Task: Paper 2 iJSDM S0–S2 evidence packet

## Goal

Reconcile the private six-species G2d state, document its locked
symbolic-to-TMB model and cloglog numerical boundary, and create a cited
conceptual source map for the later local-only article.

## Implemented

Added three private developer records: the G2d reconciliation receipt, the
symbolic-to-TMB certificate, and the comparator source map. No likelihood,
wrapper, public API, user documentation, or pkgdown article changed.

## Mathematical Contract

The certificate records the locked nonspatial relative-intensity model:
GBIF Poisson quadrature and three PA-cloglog visits share the same
six-species ecological state, with rank-one Lambda and free diagonal Psi.
GBIF bias covariates are structurally zero on survey rows. The retained
diagnostic supports map/extractor assembly only, not recovery.

## Files Changed

- `docs/dev-log/recovery-checkpoints/2026-08-11-codex-g2d-s0-reconciliation.md`
- `dev/isdm-package-recovery/2026-08-11-g2d-symbolic-tmb-certificate.md`
- `dev/isdm-package-recovery/2026-08-11-paper2-ijsdm-comparator-source-map.md`
- `docs/dev-log/check-log.md`

No reader-facing examples, roxygen, Rd files, vignettes, NEWS, README,
ROADMAP, validation-debt rows, or pkgdown configuration changed.

## Checks Run

- `git status --short --branch`: clean before this documentation-only packet.
- `git log --oneline -12`, `git worktree list`, and lane preflight: exact
  G2d branch/head and local lane state inspected.
- Retained G2c/G2d decision, after-task, reconciliation, and diagnostic
  receipts read.
- Official documentation and primary package references inspected for
  `gllvm`, Hmsc, `spOccupancy`, `glmmTMB`, and `sdmTMB`.
- `git diff --check`: pass after the packet.

No tests were run because this tranche adds documentation only and the goal
forbids fitting, smoke execution, campaigns, and implementation changes.

## Tests Of The Tests

No tests were added. The packet reports existing deterministic contract tests
and the retained diagnostic audit without upgrading either to recovery
evidence.

## Consistency Audit

Ran the following exact searches over the newly added records and private iJSDM
materials:

```sh
rg -n 'G2C_SMOKE_ADMISSION_HOLD|G2D_SMOKE_HOLD|diagnostic assembly|recovery/Totoro/campaign not admitted' docs/dev-log dev/isdm-package-recovery
rg -n 'G2D_SMOKE_PASS|Totoro.*PASS|public capability|Paper 2 readiness' docs/dev-log/recovery-checkpoints dev/isdm-package-recovery
```

The new records preserve G2c as HOLD, G2d smoke as HOLD, and diagnostic
map/extractor evidence as assembly-only. The comparator map makes no novelty,
speed, accuracy, empirical-performance, or superiority claim.

## Prose Review

Reader: the next method developer or reviewer deciding whether a new smoke is
authorised. The records lead with the evidence class and retain stable Sigma,
Lambda, psi, and Psi terminology. No reader-facing tutorial, example, or
package claim was introduced.

## What Did Not Go Smoothly

The compiled cloglog expression and R analytic oracle differ in their extreme
tail treatment: direct subtraction plus a probability clip versus stable
`expm1` evaluation. This is a pending numerical-alignment gate, not a model
failure and not authorization to add zero inflation.

## Team Learning

Rose's reconciliation separates original diagnostic HOLD receipts from their
later no-fit audit PASS. Gauss/Noether's review identifies tail equivalence as
the next prerequisite: a numerical guard must be observable and justified,
never silently promoted into evidence.

## Known Limitations

The iJSDM route remains private, nonspatial, relative-intensity only, and
unvalidated for recovery. It does not yet support PA detection, survey-count
outcomes, structural-zero availability, ecological-plus-GBIF-bias spatial
fields, empirical data, public API use, or a public article.

## Next Actions

Return for explicit approval before S3. The minimum next action is a
documentation-and-test repair for the cloglog tail alignment, followed by a
fresh separately approved local pre-run. Totoro remains closed.
