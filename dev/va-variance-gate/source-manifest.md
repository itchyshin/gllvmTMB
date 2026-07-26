# Frozen input manifest

The runner is pinned to the following files at the worktree head below.  It
records fresh MD5 checksums of these same files in every output manifest and
does not read `dev/va-bernoulli.R`.

| input | SHA-256 | MD5 |
| --- | --- | --- |
| `R/va-r3-proto.R` | `ecf5d4b76880339262d1e60c7937115848a43590033449212d39f36ff49acdf9` | `f0e035071fbf4c624c6c3441ee2fef83` |
| `inst/tmb/gllvmTMB_va_r3.cpp` | `8f13267a27835592db8b9e63f4e86ca5a4fdb91cd425f22600df11317981e065` | `4d5817ebf6a21e4c9a27aadf39097755` |

Pinned worktree commit at authoring: `ebe3bd4f84f68f3290597f2df451f666020048fa`.

Frozen fixture/configuration values live in `va_gate_config()` in the runner.
The post-calibration cell map in
`calibration-receipts/2026-07-26-post-calibration-cell-map.md` maps observed
bands 4/6/10/20 to nominal-prior target and seed pairs 12/2026074012,
50/2026074050, 55/2026074055, and 45/2026074045.  The receipt's expected
observed projected-variance maxima are 4.614/5.988/8.674/22.191, and the
predeclared observed bands are [3, 6]/[5, 7]/[8, 12]/[18, 24].  All
observations use 12 binomial trials.  These are calibrated finite-fixture
cells, not an estimator guarantee.  A run records this configuration verbatim
in `source-manifest.rds` before fitting, and a campaign with a band miss
withholds any gate conclusion.

The post-calibration cell-map receipt is bound to each output manifest. Its
SHA-256 at authoring is
`4c3cf66914db44121f263a8cbd10426a023717eebf97077158427201e3b67d3e`.
