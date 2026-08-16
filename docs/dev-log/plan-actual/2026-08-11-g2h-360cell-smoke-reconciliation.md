# G2h 360-cell smoke reconciliation

| Frozen requirement | Current evidence | Status |
| --- | --- | --- |
| Private G2h branch and frozen fixture | `codex/isdm-g2h-360cell-prep`, smoke receipt commit `bdc3da6a36da407d22b9162afcdef38dfda42eea`, seed `86121` | met |
| One fresh local smoke only | `results/g2h-smoke-20260811-001`; no second result root | met |
| Exact fit and three restarts retained | `fit.rds`; restart history has three rows | met |
| Six `theta_diag_B` profiles retained | `profile-ledger.rds`; six species x five offsets, all finite and converged | met |
| Decision ledger retained | `decision-ledger.rds`: `GEOMETRY_RESPONSIVE`, gamma error `0.1149462` | met |
| Manifest retained and core hashes read back | `file-manifest.csv`, six core entries verified | met with terminal-file limitation |
| Frozen operational admission | gradient `0.001290534 > 0.001` | hold |
| Campaign authority | no campaign / Totoro / DRAC action | preserved |
| G2c--G2g evidence | no edits or replacements | preserved |

The result shows a geometry-responsive profile pattern but is not a completed smoke under the frozen numerical rule. It is therefore `G2H_SMOKE_HOLD`; no campaign is implied or authorised.
