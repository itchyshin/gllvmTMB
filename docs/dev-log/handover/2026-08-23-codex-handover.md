# Codex handover — column slopes and iSDM source formulas

You are Codex continuing gllvmTMB after the #1196/#1192 release arc. Read `AGENTS.md`, the multi-lane map `docs/dev-log/handover/2026-07-25-active-lane-split.md`, this file, and `docs/dev-log/after-task/2026-08-23-column-slopes-and-isdm-source-formulas.md`. Do not replace the lane-map pointer with this one-lane handover.

## Critical context

Users write `phylo_slope()` / `animal_slope()` for predictors varying across response columns. The canonical engine remains `*_indep()` (diagonal) / `*_dep()` (full). Do not remove helpers. Long format is deliberately more expressive; wide column-predictor grammar is deferred, not abandoned.

For iSDM, use `isdm_source(law, observation = ~ ...)` inside `isdm_sources()`. A survey formula is naturally `~ observer + method`; the wrapper source-masks and reference-codes only genuine aliases.

## What landed

| Slice | Main commit / PR | Result |
|---|---|---|
| RHS routing | `4180bdd4`, #1199 | term-local structured RHS routing |
| diagonal slopes | `093521d3`, #1201 | `phylo_indep(0 + x1 + x2 | trait)` |
| smoke evidence | `3a934ffe`, #1202 | family-matched release receipt |
| full/helpers/animal | `ea42c058`, #1203 | `phylo_dep()`, helpers, 3-OS green |
| source formulas | `c50ec325`, #1204 | `isdm_source()`, 3-OS green |

For `P` predictors, `Cov(b) = K_source %x% Sigma_slope`. `||` gives diagonal `Sigma_slope`; `|` gives full covariance. The route is Gaussian-first, slope-only, and does not add a random intercept.

## Landing state

| Artifact / branch | State |
|---|---|
| #1192, #1195, #1196 | DONE and closed |
| `main` at `c50ec325` | DONE: feature code/docs merged |
| `codex/column-slopes-isdm-closure` | OWED: push/PR/CI/merge the documentation-only closure |

## Next immediate steps

1. Merge the closure PR after CI, then run `tools/handoff_gate.sh` and update this ledger with its SHA.
2. Later, design wide column-predictor grammar before implementing it.
3. Before any non-Gaussian multi-predictor slope campaign, estimate, pre-run, and obtain campaign approval. Spatial/kernel/latent slope-only variants are separate work.

## Protected and retracted

- **PROTECTED**: one-predictor helper objectives/parameters/maps/extraction; existing wide workflows; fixed `0 + trait` column intercepts; source-current article rendering.
- **RETRACTED**: a required `~ 0 + observer + method`; a new `*_slope` family; claims that iSDM source formulas identify abundance, occupancy, or detectability.

## Gotchas

- Rendering against an installed package that lags source is not verification; install current source into an isolated library.
- Covariates unused by a source still need finite placeholders before upstream row filtering; source masking then makes them irrelevant.
- Windows TMB fixtures compile from their directory because absolute temporary C++ paths lose backslashes in `g++`.
- Tree/pedigree means response-column dependence; indep/dep means covariance among predictor slopes.

## How to resume

From the repo root, start Codex and paste:

```text
Rehydrate from docs/dev-log/handover/2026-08-23-codex-handover.md + the AGENTS.md snapshot, reconcile against git main, then continue only the OWED steps.
```

Codex owns live R/TMB fits, checks, simulations, and article renders. Start in an isolated worktree and run `bash ~/shinichi-brain/tools/lane_preflight.sh "$PWD"` before edits.
