# G2d instrumented replacement smoke reconciliation

| Axis | Approved action | Actual | Verdict |
| --- | --- | --- | --- |
| Prior root | Preserve `g2d-tail-smoke-20260811-001` | It completed asynchronously with a full `G2D_SMOKE_HOLD` bundle | corrected record |
| Preflight | Fresh no-fit root plus independent audit | `g2d-replacement-preflight-20260811-001` passed | pass |
| Replacement | One ordinary stage-ledger smoke | One command, exit status 0, all stages retained | pass |
| Artifacts | Full terminal bundle and manifest | All required files exist and hashes verify | pass |
| Numerical admission | Frozen eligibility/recovery gate | All six profiles HOLD; gamma error `0.371326 > 0.30` | **G2D_SMOKE_HOLD** |
| Retry | One replacement attempt | One attempt; no retry | pass |
| Escalation | Totoro needs PASS plus approval | No PASS | closed |
| Scope | No remote/campaign/public/extension/#953 work | None | pass |

## Corrected history

The original root was observed too early, before its process had finished. It
now contains a complete terminal `G2D_SMOKE_HOLD` bundle at engine commit
`55be39ba`. The prior root-only explanation is superseded: its observability
lesson was valid, but no termination occurred. The replacement verifies that
the new stage ledger works.

## Instrumented evidence

The replacement root is bound to `a8b3f80a`. Its stages are
`root_receipt_written`, `fixture_constructed`, `fixture_validated`,
`one_visit_fit_entered`, `one_visit_fit_returned`, `three_visit_fit_entered`,
and `three_visit_fit_returned`.

**Rose reconciliation verdict**: complete negative admission evidence, not a
runner failure, recovery result, campaign admission, or Totoro decision. No
further smoke is authorised by this task.
