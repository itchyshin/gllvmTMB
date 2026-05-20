# M3.3b Source-Map Dashboard Florence Review

Date: 2026-05-20

Branch: `codex/m3-3b-source-map-dashboard-2026-05-20`

## Artefact Reviewed

Rendered local smoke artefact:

`/tmp/gllvmtmb-m3-3b-dashboard-smoke/m3-nb2-dashboard-smoke-source-map-dashboard-v2.png`

The source grid came from:

```sh
Rscript --vanilla dev/precompute-m3-grid.R --nb2-start-probe \
  --probe-config=current_res_bfgs_n3_j005 --n-reps=1 \
  --out-dir=/tmp/gllvmtmb-m3-3b-dashboard-smoke \
  --out-prefix=m3-nb2-dashboard-smoke
```

The rerender used the same saved long grid after the layout revision:

```sh
Rscript --vanilla -e 'source("dev/m3-grid.R"); art <- readRDS("/tmp/gllvmtmb-m3-3b-dashboard-smoke/m3-nb2-dashboard-smoke-grid.rds"); m3_write_source_map_dashboard(art$grid, "/tmp/gllvmtmb-m3-3b-dashboard-smoke/m3-nb2-dashboard-smoke-source-map-dashboard-v2.png")'
```

## Verdict

Florence verdict: **PASS for dev-facing M3.3b source-map review**.

This is not a public plotting API and not publication artwork. It is
good enough for the M3.3b admission loop because it makes the weak
cells visible, keeps denominator information on the figure, and
labels the current run as `POINT_ONLY` / `NOT_EVALUATED` rather than
coverage evidence.

## Figure Gate Checks

- Purpose: clear. The figure asks whether the NB2 point-estimate
  source map is dominated by `Sigma_unit_diag`, fitted phi, or link
  residual structure before any interval-coverage claim.
- Geometry: acceptable for the dev gate. Trait-level ratio dots keep
  individual traits visible; tile panels work for the ledger and
  verdict.
- Uncertainty: honest. Point-only rows are labelled as point-only;
  no CI bars or coverage marks are invented.
- Denominators: pass. Fit failures, CI-missing status, bootstrap
  status, `pdHess`, and `sdreport` cells print denominators or
  `not reported`.
- Comparisons: pass. Estimated-phi and known-phi rows are separated,
  with a ratio = 1 reference line for ratio panels.
- Accessibility: pass for a dev contact sheet. Shape distinguishes
  estimated versus known phi; color is not the only grouping channel.
- Reader risk: acceptable. The title/subtitle explicitly say the
  artefact is point-only and not interval-coverage evidence.

## Remaining Limitations

- This smoke uses one replicate and one start configuration; it is a
  rendering and data-grain check, not a statistical decision.
- The dashboard is wide and tuned for local PNG review. It should not
  be copied into a vignette without a smaller, reader-facing redesign.
- `pdHess` is `not reported` in the smoke because the fit path runs
  with standard-error calculation disabled; this is an inference
  warning/metadata state, not model death.

## Next Use

Use this dashboard on selected-seed source-map artefacts before
opening any r50/r200 run. If a future dashboard adds bootstrap or
profile intervals, it must keep `ci_method`, target, and point-only
rows separated rather than mixing them into one coverage panel.
