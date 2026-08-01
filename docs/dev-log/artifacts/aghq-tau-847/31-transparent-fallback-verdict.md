# Posthoc transparent-fallback sensitivity

- Input MD5: `3399541e3b944c858e7d7b7c9f836f00` (locked in the analyser)
- Package SHA: `54d6f366e972643c663be9645ed598aa98e81869`
- Strict analyser recheck on the same bytes: **NO_CAP_PASSED_SELECTION**.
- Bootstrap replicates: 5000
- Policy: use `auto_cap6` only when its final fit is valid; otherwise return the independently started `fixed2_shipped` fit.
- Status: **POSTHOC SENSITIVITY, NOT THE PREREGISTERED DEFAULT GATE**.
- Auto result used: 135/600.
- Six-cell macro-mean paired loading-error difference: +0.002819895.

This supports a narrow explicit runaway/failure-avoidance capability. It does not support changing the package default or claiming broad loading accuracy. Failed and nonconverged fits count as adverse; no replicate is filtered from those denominators.
