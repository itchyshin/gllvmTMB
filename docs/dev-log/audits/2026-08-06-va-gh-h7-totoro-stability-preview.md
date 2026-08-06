# VA(GH) H=7 Totoro stability preview

**Status:** PREVIEW ONLY — not a final Arc-2 family verdict.

The frozen 5,520-row Totoro plan completed on 2026-08-06. Host-local export
verified every broad bundle and its Gate/runtime/preflight/plan provenance. It
also verified and excluded the separately planned legacy p=6 smoke bundle.

Export receipt:

- data status: `COMPLETE`;
- result rows: 5,520;
- input-manifest rows: 5,520;
- campaign revision: `ac45e50f0c88ef961a9ce8be92ca04fec01455af`;
- exporter revision: `c1b86e42b1f2cdb0ec917fc11c0594c5d2d91e76`;
- exporter checksum: `9ebf01f85578106d6bcb271bc4097f71`;
- plan checksum: `1fbec63d93d3f2451d8bd784d6263971`;
- result checksum: `895bea568af0e582e8b104f9bf991d72`;
- input-manifest checksum: `b1add5f806255d7da75e415650efe14c`;
- VA-template checksum: `7248289db52411b083d9d0517405fbc9`;
- Gate-report checksum: `79d57f9b916a339af76ef1063777faf7`.

## Predeclared H7/H61 stability result

Across the 36 family/link-by-rank rows:

- `PASS`: 16;
- `INCONCLUSIVE`: 12;
- `NOT_APPLICABLE` exact rows: 8;
- `FAIL`: 0.

Every finite paired-bootstrap upper ratio was at most 1.0004, far below the
predeclared 1.10 degradation threshold. The 12 inconclusive rows did not reach
the required 27 healthy paired seeds:

| cell | q | beta pairs | beta upper ratio | Sigma pairs | Sigma upper ratio |
|---|---:|---:|---:|---:|---:|
| nbinom2_log | 2 | 8 | 1.0000284 | 8 | 1.000019 |
| nbinom2_log | 5 | 16 | 1.0000468 | 16 | 1.000017 |
| beta_logit | 2 | 24 | 1.0000004 | 24 | 1.000004 |
| beta_logit | 5 | 12 | 1.0000011 | 12 | 1.000001 |
| betabinomial_logit | 2 | 18 | 0.9999997 | 18 | 1.000010 |
| betabinomial_logit | 5 | 11 | 1.0000022 | 11 | 1.000028 |
| truncated_nbinom2_log | 2 | 0 | NA | 0 | NA |
| truncated_nbinom2_log | 5 | 6 | 1.0003921 | 6 | 1.000019 |
| delta_lognormal_log | 2 | 15 | 1.0000000 | 15 | 1.000004 |
| delta_lognormal_log | 5 | 5 | 1.0000332 | 5 | 1.000052 |
| delta_gamma_log | 5 | 18 | 1.0000025 | 18 | 1.000003 |
| nbinom1_log | 5 | 21 | 1.0000070 | 21 | 1.000002 |

Interpretation: among healthy paired fits, H=7 and H=61 have effectively
identical recovery. This does not resolve the operational-health shortfall and
does not make any row a final PASS. The 500-seed DRAC reliability/recovery and
calibration evidence must be combined before independent final verdicts or
family fences are issued.

Exact command class: the committed `adjudicate_campaigns()` was run with the
verified Totoro export and a clearly synthetic all-healthy DRAC placeholder so
only `h7_stability_verdict` and its Totoro-derived fields were inspected. No
synthetic point-recovery or calibration label is evidence.
