# After Task: M3.3a nbinom2 Corrected r20 Stress Audit

**Branch**: `codex/m3-3a-nbinom2-corrected-r20-audit-2026-05-20`
**Date**: `2026-05-20`
**Roles (engaged)**: `Ada / Curie / Fisher / Grace / Rose`

## 1. Goal

Record the first bounded `nbinom2-d1` stress evidence after PR #211
made the M3 `Sigma_unit_diag` target use
`bootstrap_Sigma(link_residual = "none")`.

## 2. Implemented

No package code changed. This is an evidence-only dev-log lane.

Added:

- `docs/dev-log/audits/2026-05-20-m3-3a-nbinom2-corrected-r20.md`;
- this after-task report;
- a check-log entry;
- a coordination-board active-lane row.

## 3. Files Changed

- `docs/dev-log/audits/2026-05-20-m3-3a-nbinom2-corrected-r20.md`
- `docs/dev-log/after-task/2026-05-20-m3-3a-nbinom2-corrected-r20.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/coordination-board.md`

## 3a. Mathematical Contract

The artifact used the corrected target from PR #211:

```text
truth:    diag(Lambda Lambda^T + Psi)
estimate: extract_Sigma(fit, level = "unit", link_residual = "none")
CI:       bootstrap_Sigma(fit, level = "unit", what = "Sigma",
                          link_residual = "none")
```

## 3b. Decisions and Rejected Alternatives

I did not launch a full 15-cell grid. The corrected two-scenario pilot
still failed the 0.94 gate and changed the failure direction, so the
next useful step is diagnostic metadata, not scale-up.

## 4. Checks Run

- `gh pr list --repo itchyshin/gllvmTMB --state open --limit 20`
  -> no open PRs at lane start.
- `git status --short --branch && git pull --ff-only`
  -> clean `main...origin/main`, already up to date.
- `git log --all --oneline --since='6 hours ago' | head -80`
  -> recent #209-#211 and board closeout commits reviewed before
  editing shared dev-log files.
- `Rscript --vanilla -e 'x <- readRDS("/tmp/gllvmtmb-m3-3a-corrected-stress-r20/nbinom2-two-scenario-corrected-r20-b20.rds"); stopifnot(x$meta$n_reps == 20L, x$meta$n_boot == 20L, nrow(x$summary) == 2L); ...'`
  -> artifact integrity check passed.
- `Rscript --vanilla - <<'EOF' ... EOF`
  -> trait-level and miss-side summaries printed from the saved
  artifact.
- `git diff --check`
  -> clean.

## 5. Tests of the Tests

No new automated test was added. This lane tests the corrected M3
runner empirically by reusing the r20/b20 simulation driver and
checking the saved artifact structure.

## 6. Consistency Audit

The audit explicitly keeps EXT-13 / CI-08 / CI-10 partial. It does not
claim coverage recovery.

Exact scans to run before close:

- `rg -n 'corrected-r20|baseline_phi1_n60_r20|lowphi_n120_r20|CI-08|CI-10|EXT-13|partial' docs/dev-log/audits/2026-05-20-m3-3a-nbinom2-corrected-r20.md docs/dev-log/after-task/2026-05-20-m3-3a-nbinom2-corrected-r20.md docs/dev-log/check-log.md`

## 7. Roadmap Tick

No validation row moves. The evidence reinforces the M3.3 triage path:
add fitted-dispersion diagnostics before any full-grid promotion
attempt.

## 8. What Did Not Go Smoothly

The r20 result showed a different failure mode than expected. After
the scale fix, most uncovered rows now have truth above the interval,
not below it. That makes the next slice a calibration-diagnostic task.

## 9. Team Learning

Ada kept the run bounded while CI was pending. Curie checked artifact
integrity. Fisher interpreted the changed miss direction as calibration
evidence rather than validation recovery. Grace kept the lane docs-only
after PR #211. Rose kept the scope status partial.

## 10. Known Limitations And Next Actions

The M3 grid does not yet record fitted `phi` or fitted link-residual
diagnostics. Add those columns before another stress grid.
