# Gate-A review — Paper 2 Case-C/Psi specification

**Review type:** independent, read-only method checklist after drafting A0–A2.
It is a separate evidence pass, not a new fit, code review, or claim of
independent human/agent authorship.

| Check | Verdict | Evidence |
| --- | --- | --- |
| Exact predecessor and lane boundary | PASS | A0 base is G2o `0f668c46`; loop is lane-local and does not modify the shared `LOOP/`. |
| Protected HOLDs | PASS | Reconciliation names and preserves G2n, G2k, and G2c HOLDs without promotion. |
| Likelihood/DGP/maps/transforms | PASS | The specification restates the G2d Poisson/cloglog shared-state model; `B` remains GBIF-only, `d=1`, and `theta_diag_B=log(psi)`. |
| Case-C interpretation | PASS | The G2n `b_fix` residual remains `NO_CANDIDATE`; no repair or threshold relaxation appears. |
| Psi estimand | PASS | Psi is scored as diagonal variance `exp(2*theta_diag_B)`, separately from `Lambda Lambda'`. |
| Recovery design | PASS | Only S = 6, 20, 60 are proposed; each retains all attempts, fixed metrics, and the existing thresholds. |
| Measured scale design | PASS | S = 250/1,000 record all required stages and peak RSS, have fixed C/r/b/d/N/P/R, and apply the required numerical predicates and <=2 empirical ratios. |
| 10k boundary | PASS | Explicit architecture HOLD; no dense S-by-S inference/output is proposed. |
| Scope/reader honesty | PASS | Source map is non-ranking and disclaims occupancy/detection, spatial, count, empirical, absolute-abundance, generic-zero-inflation, arbitrary-source, and 10k support. |

## Gate-A conclusion

`GATE_A_METHOD_SPECIFICATION_PASS`: the A0–A2 artefacts are internally
consistent with the retained evidence and their negative-space contract.  This
is **not** scientific admission, implementation approval, fit approval, or
recovery evidence.  A3 remains subject to explicit maintainer approval.
