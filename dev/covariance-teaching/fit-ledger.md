# Approved fit ledger

| Block | Existing fits | Estimate | Cap | Attempts | Outcome |
|---|---:|---|---|---:|---|
| covariance-correlation | 3 | 5–10 min | 10 min | 1 | HTML PASS in12.012s; raw wrapper receipt failed nested-call count; separate reconciliation confirms3 fits |
| cross-family-correlations | 2 | 2–3min after covariance12.012s; prior same article about1.5min | 5min within shared30min | 1 | PASS20.226s,2 fits, convergence0 |
| spatial-models | 4 | 1–3min after covariance12.012s; includes mesh overhead | 5min within shared30min | 1 | PASS10.254s,4 fits, convergence0 |
| package check | separate check suite | 20–25 min | 30 min | 1 | running |

Total article allowance: 9 executions, one successful render per article. No failed attempt is erased. No standalone fits, added wide fits, retries, seed hunting or recovery studies. Package/setup/CI receipts separate.

Setup attempt1: document completed in 35.326 s (three existing S3-tag warnings); install call stopped at argument validation because this devtools version requires logical upgrade. No article fits executed. Corrected task wrapper to upgrade=FALSE; retry estimate 1–3 min, cap5 min. Ordinary extractor Rd will be regenerated from restored original roxygen.

Setup attempt2: devtools documentation succeeded and restored ordinary extractor Rd, but pak dependency-cache lock was sandbox-denied. No fits. Retain receipt. Direct R CMD INSTALL --preclean to isolated library avoids dependency-cache mutation; estimate1–3min cap5min.

Setup attempt3: direct install rejected split --library argument before installing; no fits and shared library unchanged. Attempt4 uses --library=PATH; retained logs. Harness no-fit namespace stub and suppressed-warning knitr chunk both PASS (harness.log).

Setup attempt4 PASS in98.701s: production compile/install to isolated library, document, pkgdown check. Source/Rd limited to five approved files. No scientific fits so far. Noether and Pat source reviews PASS after scoped wording fixes.

Covariance render: original failed receipt, trace, HTML and warnings retained. Failure occurred only after HTML creation because nested wide forwarding was counted as independent fitting. R/gllvmTMB.R762–874 plus nested no-fit stub reconcile3 top-level fits, all convergence0. No rerender. Bootstrap CSS288492 bytes, other styles/scripts/logo and all3 plot files exist; Sass warning was a cache-write failure, not missing presentation assets. Future wrapper cache directed to task directory.

Article block complete: exactly3 render attempts,9 model fits, all convergence0. Process time42.492s; block wall time207.254s, below30min. Covariance raw wrapper failure remains retained and separately reconciled. Actual HTML has all4 requested alt attributes, corrected meanings and local presentation assets (rendered-verification.json).
