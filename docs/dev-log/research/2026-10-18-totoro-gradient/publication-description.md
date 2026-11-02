Refs #1596.

The behavioural reaction-norm test's BFGS fit stops with optimiser code zero while its raw gradient is 0.01817, above the existing 0.01 cutoff on Totoro. Its relative objective stopping rule ends the fit too early. Set `reltol = 1e-10` in both long and wide test helpers and explicitly retain `loading_ridge = Inf`. The resulting gradient is 0.0002363 and the objective improves from 24.94217 to 24.61862.

Add direct finite, unpenalised gradient checks below 0.01 for both formats and check the wide diagnostic row. Existing recovery, likelihood agreement and diagnostic expectations remain intact. No package code, defaults or test thresholds change.

The strengthened test reproduces four failures before the control change; the fixed file passes all 73 assertions with no failures, errors, warnings or skips on Totoro. Long/wide parameters match exactly; a `reltol = 1e-12` cross-check agrees on the objective within 4.03e-10. Independent review found no blocker. This verifies fixture stationarity and existing point recovery, without a new Hessian or interval-calibration claim.

The complete Totoro package check passed in 28 minutes 21 seconds: 0 errors, 0 warnings and the same 2 existing notes (TMB internal API use and server compiler flags). The full suite reported 26,641 passes, 60 diagnostic warnings, 1,259 skips and 0 failures. The neighbouring article's default nlminb fit also passes its gradient check, so its calls remain unchanged. Reproduction scripts, fit receipts, test logs and source provenance are retained under `docs/dev-log/research/2026-10-18-totoro-gradient/`.
