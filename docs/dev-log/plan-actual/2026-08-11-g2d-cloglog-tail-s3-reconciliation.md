# G2d cloglog-tail repair and S3 smoke reconciliation

| Axis | Approved plan | Actual | Classification | Consequence |
| --- | --- | --- | --- | --- |
| Frozen state | One repaired engine commit | `55be39babfa128e7c7691690fbdf05acbcdd56f7`; clean before S3 | pass | exact provenance |
| Numerical repair | Remove the generic cloglog probability clip | Direct log-scale general-binomial helper; left-tail series and explicit `eta = 700` representability guard | pass | no ordinary-range saturation |
| No-fit admission | Tests and fresh preflight | Both passed | pass | one smoke admitted |
| S3 local smoke | One ordinary smoke with complete terminal artifact bundle | Only root receipts were emitted; no fixture, fit, profile, manifest, or smoke receipt | **G2D_SMOKE_HOLD_INCOMPLETE_ARTIFACTS** | no numerical/admission conclusion |
| Retry discipline | One attempt | One command; no retry | pass | fresh authority required |
| Escalation | PASS could prompt later Totoro decision | No PASS or terminal receipt | pass | Totoro/campaign closed |
| Scope | Preserve G2c and all exclusions | No prohibited work; Issue #953 read-only metadata only | pass | G2c unchanged |

## Retained root

`dev/isdm-package-recovery/results/g2d-tail-smoke-20260811-001/` is ignored
and retained. It contains only:

| File | SHA-256 |
| --- | --- |
| `root-receipt.rds` | `6434707913c54d6695c754b5f81f3009f8c2ec88acd1ae0be7f43063b5e0a51d` |
| `root-receipt.md` | `adaa92c0253dc86fc73fe169e6ad15dd056a56510832326fcb9f1558101bac12` |

RDS read-back confirms purpose `local-smoke`, commit `55be39ba`, runner,
protocol, and decision hashes, fixed 30-row seed grid, R 4.6.0, TMB 1.9.21,
macOS arm64, and creation time `2026-08-11 14:30:26 UTC`. It does not identify
why execution stopped; cause is unobserved, not inferred.

**Rose reconciliation verdict**: the sole authorised S3 attempt is retained
negative provenance with an incomplete bundle. It is neither estimator evidence
nor a completed smoke. A separately approved diagnostic may investigate the
runner termination, but must preserve this root and cannot relabel it as PASS
or consume an implicit retry.
