# G2o reconciliation receipt

**Status:** `G2O_NO_FIT_DESIGN_ONLY_GO`.

G2o began from the closed G2n local-pre-run commit `a0f0b8a8` on the
private branch `codex/isdm-g2o-postmortem`. It read, but did not modify, the
retained G2n result root `g2n-local-prerun-20260812-0630` and G2k diagnostic
root `g2k-gradient-diagnostic-20260812-007`.

The G2o runner performed RDS reads, an exact gradient evaluation at the
retained parameter vector, covariance arithmetic, and summary-file writing. It
did not fit, optimize, profile, simulate, invoke remote compute, or change the
model, DGP, source gate, map, thresholds, recovery metrics, public API,
pkgdown, or the staged articles. The 150/150 denominator is the completed
private FIR campaign summarized by the G2k diagnostic bundle; it is not the
earlier incomplete Totoro root.

The retained classifications are unchanged:

- `G2C_SMOKE_ADMISSION_HOLD`
- `G2K_CALIBRATION_HOLD`
- `G2N_LOCAL_PRERUN_HOLD`

G2o's only forward permission is a **fresh design-only** arc: specify a
pre-registered Psi calibration/information experiment and any separately
justified Case-C estimator candidate before another fit can be proposed. It is
not approval for a fit, optimizer repair, recovery campaign, or public claim.
