# HVT-1 plan versus actual

## Result

**Partial, honest close:** stable band 4 is `TRUTH_CERTIFIED_ADAPTIVE`; frozen
band 20 is `TRUTH_UNINTERPRETABLE_ADAPTIVE`.  The overall required decision is
therefore `ORACLE_NOT_CERTIFIED`, with no high-cell ELBO--truth gap.

## Material reconciliation

| Axis | Plan | Actual | Classification |
| --- | --- | --- | --- |
| Scope | private q=2 multi-trial oracle | met; no public surface change | aligned |
| Evidence | stable/high certification | stable certified; high tightened reverse failed | aligned outcome |
| Routing | fresh 2 Terra + 1 Sol completion panel | Curie and Noether passed after remediation; fresh Rose slot was unavailable after planning children | adaptive deviation |
| Safety | lock, no retuning, no fallback | met | aligned |
| Claims | no VA admission/gate relaxation | met | aligned |
| Handoff | report, receipt, branch preservation | met: committed and pushed as `3a22ac48` on `codex/hvt1-high-variance-truth-oracle-20260726` | aligned |

## Timing calibration

The all-route nested integral exceeded the interactive command window.  Local
parallel evaluation across independent units reduced a stable all-route pass to
about 12 seconds.  Future private q=2 reference arcs should budget explicit
parallel-unit infrastructure before certification, rather than treating it as
repair reserve.
