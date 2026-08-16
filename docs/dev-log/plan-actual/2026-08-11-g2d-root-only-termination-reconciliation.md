# G2d root-only smoke termination reconciliation

| Requirement | Evidence | Verdict |
| --- | --- | --- |
| Preserve original root | `g2d-tail-smoke-20260811-001/` unchanged with only two root receipts | pass |
| Locate boundary | Old runner wrote root, then entered `run_fixture()` with no further write until return | pass |
| Test pre-fit route | Shared `prepare_fixture()` constructed and validated seed 86101 in `smoke_boundary` mode | pass |
| Retain diagnostic | `g2d-tail-boundary-20260811-002/` at `d04cb53e` has root, truth, paired map, stages, receipt, manifest | pass |
| Attribute old termination | No exit status, error, stage, fixture, or fit artifact exists | **G2D_ROOT_ONLY_CAUSE_UNATTRIBUTED** |
| Repair diagnosability | New ledger records root, fixture, and pre/post-arm boundaries | **RUNNER_OBSERVABILITY_DEFECT_REPAIRED** |
| Scope | No optimizer, fit, profile, smoke, campaign, remote or public action | pass |

## Failure boundary

The old flow was `write_root_receipt()` → `run_fixture()` →
`make_fixture()` → `validate_paired_fixture()` → `run_arm()` → `fit_one()` →
`.gll_isdm_fit()`. Its next disk write occurred only after both arms returned.
The new no-fit root proves that the deterministic path through fixture
validation succeeds. It cannot retrospectively distinguish an external process
termination from an abnormal event in the first fitting call.

## Verdict and recommendation

The historical cause is **unattributed**, not an inferred fitter, engine, or
external failure. The actionable cause is a **runner observability defect**:
the old runner had no durable progress record within its long interval. The
ledger repairs that defect.

A separately approved replacement S3 smoke is conditionally justified because
the prior attempt has no assessable numerical outcome and pre-fit preparation
now passes. It must use the ledger commit (or descendant), capture process exit
status, retain all stages, use a new root, and remain local-only. This
diagnostic does not authorise it.
