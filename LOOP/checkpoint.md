# Checkpoint

STATE: **GOAL_MET** 2026-08-18. Arcs **A0–A8 DONE**. Poisson MSPL live weight
`family_id == 2` is the working logistic `W_* = mu_*(1-mu_*)` via
`gll_mspl_log_weight(eta, 0)` under G0 SIGNED REPLACE (#1102);
PR [#1111](https://github.com/itchyshin/gllvmTMB/pull/1111) **MERGED** into
`main` at merge commit **`3053fce3`** (2026-08-18 00:36 UTC, `R-CMD-check`
ubuntu-latest release SUCCESS). Docs closeout merged as
PR [#1116](https://github.com/itchyshin/gllvmTMB/pull/1116). Hard OUT held in
full.

- DONE: A0–A8 — REPLACE merged via PR #1111 (`3053fce3`); local multi-seed smoke; local `--as-cran`+vignettes **2 NOTEs**
- IN PROGRESS: none (GOAL_MET)
- NEXT: nothing in this LOOP — the lane is closed and a new goal needs its own
  G0. Morning soft gates only if desired (SE-series *prep* packet; still no
  public se)
- OPEN GATE: none (hard OUT absolute — no NEWS covered / no public se)
- WHERE TRUTH LIVES: `main` @ merge `3053fce3` for the REPLACE itself; the
  closeout notes are also on `main` via #1116. The impl branch is merged and is
  no longer the place to read.
- RESUME: not applicable — closed. Do not reopen public se / undraft #1077 from
  this lane.
