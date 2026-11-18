# G2g diagnostic decision tree

G2g is a no-fit, retained-artifact diagnosis. It cannot change G2c, G2d, G2e,
or G2f classifications and cannot authorize a campaign or redesigned smoke.

| Evidence from reader and certificate | Frozen G2g diagnosis | Allowed recommendation |
| --- | --- | --- |
| Fixed design rank deficient, \(|\operatorname{cor}(x,b)|\ge0.85\), or GBIF gate/map mismatch | `SOURCE_CONFOUNDING` | redesign source/covariate contrast before any fit |
| Rank and source map pass, but fewer than two lower \(\psi_s\) endpoints have delta NLL at least 2 and \(\max|\operatorname{cor}(\Lambda,\theta_{\mathrm{diag}})|\ge0.25\) | `COVARIANCE_INFORMATION_LIMITED` | increase independent cell-level ecological replication; do not add visits alone |
| Raw gradient alone exceeds the smoke threshold while scaled-gradient, raw-stationarity, and positive-definite-Hessian diagnostics pass | `NUMERICAL_THRESHOLD_NOTE` (ancillary, not a scientific diagnosis) | record the admission distinction; do not reinterpret recovery |
| More than one *substantive* row applies | `MIXED_LIMITATION` | retain each mechanism and choose only a design that addresses all named mechanisms |

The reader must retain the numerical evidence for every chosen row. Any future
redesigned smoke needs a new approved protocol, fixture, no-fit contract, and
one separately authorized local execution.

G2f meets `COVARIANCE_INFORMATION_LIMITED`; its numerical threshold note is
retained alongside that diagnosis and does not turn it into `MIXED_LIMITATION`.
