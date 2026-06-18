# COE-04 fitted kernel-diagnostics slot

Date: 2026-06-18 11:17 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

This slice makes the `COE-04` kernel-separation diagnostic available on fitted
multi-kernel objects. It strengthens the Paper 2 two-component evidence lane,
but does not finish scientific coverage.

The fitted object now carries:

- `fit$kernel_diagnostics$similarity`: named pairwise similarity matrix;
- `fit$kernel_diagnostics$pairs`: pair table with `level_1`, `level_2`,
  `similarity`, and `overlap_class`;
- `fit$kernel_diagnostics$thresholds`: near-orthogonal and high-overlap
  boundaries;
- `fit$kernel_diagnostics$note`: warning that high overlap weakens
  component-specific `Gamma_shape` separation evidence.

Supersession note: the follow-up
`2026-06-18-coe04-high-overlap-warning.md` adds a fit-time warning for high
overlap. This report remains the record for first exposing the fitted-object
diagnostic slot.

## Files changed

- `R/fit-multi.R`
- `tests/testthat/test-coevolution-two-kernel.R`
- `NEWS.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/65-cross-lineage-coevolution-kernel.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## Commands run

- `/opt/homebrew/bin/gh pr list --state open`
  -> only draft PR #489 open.
- `git log --all --oneline --since="6 hours ago"`
  -> recent commits were current mission-control/article/kernel commits.
- `/usr/local/bin/Rscript --vanilla -e 'parse("R/fit-multi.R")'`
  -> parsed.
- `/usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  -> `FAIL 0 | WARN 0 | SKIP 2 | PASS 36`.
- `GLLVMTMB_HEAVY_TESTS=1 /usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 51`.
- `/usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution")'`
  -> `FAIL 0 | WARN 0 | SKIP 5 | PASS 122`.
- `GLLVMTMB_HEAVY_TESTS=1 /usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 160`.

## Review perspectives

Boole: no new formula grammar was added. The diagnostic attaches to existing
multi-kernel fits.

Gauss / Noether: no TMB likelihood or parameterisation change was made. The
diagnostic is computed from fixed input kernels before fitting.

Fisher / Curie: the diagnostic is now an inspectable fitted-object artefact.
This supports near-orthogonal recovery evidence, but moderate-overlap recovery,
high-overlap calibration, and null/selective absence still need explicit gates.

Rose: evidence files say `partial`, not `covered`, and preserve the guard
against bridge/release/science overclaiming.

## Still open

- Moderate-overlap recovery and high-overlap failure language.
- Block-null and selective-absence calibration.
- `rho` profiling or estimation.
- Interval coverage.
- Mixed/non-Gaussian coevolution gates.
- Explicit Psi grammar redesign and `*_unique()` lifecycle/deprecation arc.
- Bridge completion, release readiness, and scientific coverage completion.
