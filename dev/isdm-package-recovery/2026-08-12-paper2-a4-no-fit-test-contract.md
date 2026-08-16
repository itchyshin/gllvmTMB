# Paper 2 A4 — no-fit test contract and acceptance matrix

**Status:** specification only; Gate B has not approved implementation.

## Purpose

If Gate B authorizes it, implementation may add only deterministic no-fit
tests for the frozen numerical decision logic and provenance schema. It must
not call `MakeADFun`, `.gll_isdm_fit`, `nlminb`, a profile helper, or a
compiled iJSDM objective; it must not alter the likelihood, DGP, maps,
transforms, thresholds, controls, starts, or public surfaces.

## Required test families

| Family | Fixtures and assertions | Acceptance rule |
| --- | --- | --- |
| Case partition | Synthetic ledger rows for A, B, C (`b_fix` and `theta_rr_B`), and invalid D states. | Cases are mutually exclusive; each row retains raw state and reason. |
| Case-C non-entry | Both unique Case-C maxima in the open `(1e-3, 1e-2)` interval, without the named diagonal boundary. | `case = C`, `polish_status = NO_CANDIDATE`, no candidate method/input/output. |
| Case-B isolation | One valid named diagonal boundary and raw-pass/boundary/invalid neighbours. | Existing Case-B route remains restricted to its predicate; no Case-C fixture can reach it. |
| Adversarial rejection | Tied maximum; `theta_diag_B` maximum; nonfinite objective/gradient; non-PD Hessian; wrong optimiser; AGHQ/ridge; covariance mismatch; map/data/random/bounds/scale/control mismatch; relaxed tolerance or extra retry. | Each fails closed with a retained reason and no candidate/fitter route. |
| Transform/map invariants | Frozen fixture shows `theta_diag_B = log(psi)` and diagonal variance recovery `exp(2 * theta_diag_B)`, distinct from `Lambda Lambda'`; parameter order/dimnames/map signatures are immutable. | Exact expected values and explicit mismatch failures. |
| All-attempt provenance | Valid, missing, error, and candidate-free rows; immutable manifest/hash fields and attempted-start fields. | Every requested attempt remains present; unavailable fields have a reason; no eligible-only denominator. |
| Static no-execution guard | Scan the new no-fit test/helper paths for forbidden fitter/optimizer/profile calls. | Zero executable calls; textual mentions in documentation are not failures. |

## Rejection matrix

The implementation must encode, without invoking a model:

| Input class | Required result |
| --- | --- |
| raw gradient `<= 1e-3`, ordinary prerequisites | A / `NOT_REQUIRED` under existing rules |
| exactly one named diagonal boundary meeting existing predicate | B / existing conditional route only |
| `b_fix` or `theta_rr_B` unique maximum in `(1e-3, 1e-2)`, no boundary | C / `NO_CANDIDATE` / HOLD |
| invalid/nonfinite/tied/non-PD/wrong-control state | D / invalid HOLD |

No acceptance assertion may use a scaled gradient, a covariance-scaled score,
recovery success, profile shape, or a later conditional summary to recode Case
C. The G2N/G2K/G2C HOLD labels are immutable fixture values.

## Review and completion requirements

Before any later test implementation is accepted, Gauss/Noether must confirm
that no objective/map/transform is changed, and Rose must confirm the scope
and static no-execution boundary. A passed pure-logic suite is not numerical
admission, recovery, scale, or reader-promotion evidence. It cannot open a
fit or campaign; those require their later named gates and a time estimate.
