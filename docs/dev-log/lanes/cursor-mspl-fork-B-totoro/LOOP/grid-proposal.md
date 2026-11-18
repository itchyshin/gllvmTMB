# T1 grid — LOCKED (kit pointer)

**Canonical file:**
`docs/dev-log/research/2026-08-18-mspl-forkB-totoro-grid-proposal.md`

Sibling-locked 2026-08-18. This is the **declared hold-out for measurement**.
It does **not** freeze T\*. `calibrated: FALSE`. `public_confint: refused`.

| cell_id | n_site | T | prevalence | seed | n_rep | cores | rule |
|---|---:|---:|---|---:|---:|---:|---|
| `T1-anchor-n40-T8` | 40 | 8 | anchor | 20260830 | 200 | 16 | RECORD |
| `T1-anchor-n160-T8` | 160 | 8 | anchor | 20260831 | 200 | 16 | RECORD |
| `T1-neartail-n80-T8` | 80 | 8 | near_tail | 20260832 | 200 | 16 | RECORD |
| `T1-fartail-n40-T4` | 40 | 4 | far_tail (\(\beta_0=-2.4\)) | 20260833 | 200 | 16 | RECORD-ONLY |

**800 fits.** Smoke-first: local 1-rep × 4, then Totoro BatchMode + deploy +
1-rep × 4, **then** the full 800. Wall: ~20–40 min including deploy;
200-rep panel ~2–5 min at 16 cores (conservative serial ~25 min).

Do not re-walk `20260818`–`20260821`. Do not undraft #1077. Do not flip
MSPL-04. Optional confirm `T1-confirm-n80-T8` / seed `20260834` is **out**
of the primary 800.
