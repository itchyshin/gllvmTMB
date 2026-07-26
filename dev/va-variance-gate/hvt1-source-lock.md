# HVT-1 frozen source lock

HVT-1 starts from commit `f22800812b123eb3e3dcf8e08db72769a45c10ae` in a
clean isolated worktree.  The adaptive oracle may consume only the inputs
listed below.  A mismatch is `ORACLE_NOT_CERTIFIED`; it must not be repaired by
retuning a fixture or changing the fitted coordinates.

| input | SHA-256 |
| --- | --- |
| `R/va-r3-proto.R` | `ecf5d4b76880339262d1e60c7937115848a43590033449212d39f36ff49acdf9` |
| `inst/tmb/gllvmTMB_va_r3.cpp` | `8f13267a27835592db8b9e63f4e86ca5a4fdb91cd425f22600df11317981e065` |
| `dev/va-variance-gate/run-va-variance-gate.R` | `7f9890fd33cf952c3a2742e9d05d398ef5c3f57c38a60f9662ba785748602c03` |
| `dev/va-variance-gate/calibration-receipts/2026-07-26-post-calibration-cell-map.md` | `4c3cf66914db44121f263a8cbd10426a023717eebf97077158427201e3b67d3e` |
| `dev/va-variance-gate/source-manifest.md` | `84a8b2a59314409c837cdc889aef8939bb07563fcc08e9177d120998b6210eec` |
| local campaign record `campaign.rds` | `6f4c899587cd57454b3bd8cf5f174c76ce31229516a83a03246616c56d7bb64c` |

The frozen configuration remains complete multi-trial binomial-logit data with
`q = 2`, `N = 10`, `T = 2`, and `n_trials = 12`.  It excludes Bernoulli,
AGHQ, Laplace values, refitting, public interfaces, and fixture retuning.

The HVT-1 runner must lock the SHA-256 of the original local campaign record
before extracting its retained best-H61 fixed coordinates; it selects neither a
new start nor a new fit.  The run receipt additionally records
`R.version.string` and the installed TMB version.  Raw HVT-1 results remain
local under `/private/tmp` in accordance with D-50.
