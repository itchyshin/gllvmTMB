# G3P V2 smoke reconciliation — terminal HOLD

| Axis | Retained result |
| --- | --- |
| Root | Ignored `results/G3P_P2_S6_C360_R3_V2/`, now consumed and immutable. |
| Receipt | Commit `0f5c27969e5baab96162be92aae056e377fddc9c`; provenance `MATCH` with only a non-binding DLL-path difference. |
| Context | Schema, V2 gate, root, attempt, time estimate, and hard stop exactly matched. |
| Mode/budget | One approved local smoke; 15–25 minutes / 1,500 seconds; observed 19.106 seconds. |
| Terminal state | `G3_HESSIAN_UNAVAILABLE`: Hessian unavailable for the random-effects model. |
| G3 state | No G3 trial/candidate; `g3` is `NULL`; no admission or rejection. |
| Negative space | No retry, profile, recovery, campaign, remote compute, frozen-model change, or public claim. |

This records a receipt-valid Hessian-availability stop only. It does not
establish model adequacy, convergence/admission, likelihood behaviour, Psi or
recovery, spatial separation, empirical performance, scale, or any public
capability.
