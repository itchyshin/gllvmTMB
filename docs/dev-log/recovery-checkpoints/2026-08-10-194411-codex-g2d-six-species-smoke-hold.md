# G2d six-species smoke HOLD checkpoint

- **Branch**: `codex/isdm-g2d-six-species` at `ffe52ab1974ac26e3551f3b10f59fd37a672f24c`.
- **Status**: private G2d artifacts are untracked; no public/package files changed.
- **Completed**: no-fit runner validation passed; targeted harness test passed; the one authorised local smoke was attempted once for ordinary seed `86101`.
- **Smoke outcome**: `G2D_SMOKE_HOLD` due to a post-fit write-path failure. The `results/` parent was absent and `write_fixture()` used `normalizePath(..., mustWork = TRUE)` before creating it. No numerical output was serialised.
- **Repair made, not exercised**: smoke mode now creates the fresh root before the first fit.
- **Do not run**: another smoke, any fixture panel, Totoro, empirical data, count/comparator/spatial/source-admission work, or Issue #953 updates.
- **Next safest action**: review/commit the private harness and the closure records; obtain explicit new authority before any retry.
