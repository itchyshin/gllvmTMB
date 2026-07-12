# Retained articles batch A — applied-reader audit

Date: 2026-07-12  
Reviewer: Pat lane (reader audit plus bounded implementation follow-up)  
Scope: `fit-diagnostics`, `convergence-start-values`, `pre-fit-response-screening`, and `pitfalls`, including source Rmd and rendered pkgdown HTML.

| Page | Verdict | Applied-reader findings |
|---|---|---|
| `fit-diagnostics` | **PASS** | The APIs are current and exported; long and wide fits are both run and their likelihood agreement is printed. All non-PASS fit-health rows, lifecycle/parser warnings, and no-SE warnings are shown and interpreted. Claims distinguish point health, Hessian/Wald inference, fitted-response diagnostics, rank, and calibration. Headings and local links are synchronized, and no internal IDs, process prose, or deprecated covariance functions appear. The two multi-panel chunks now use `fig.class="wide-scientific-figure"`; that class survives on both rendered `<img>` elements and matches the mobile CSS rule that preserves a readable 680-pixel drawing width inside a horizontally scrollable figure container. |
| `convergence-start-values` | **PASS** | Current convergence semantics are explicit: optimiser success, finite objective, and raw maximum gradient below `0.01`; scaled gradient is descriptive only. Long and wide fits are both run and agree. Global warning suppression is removed; the rendered lifecycle/parser warning, `pd_hessian = FALSE`, and no-SE `WARN` rows are visible and interpreted without turning convergence into an inference certificate. `latent(..., unique = FALSE)` is correctly presented as a current latent argument for the older no-Psi subset, not as deprecated `unique()` covariance syntax. No internal IDs/process prose appear. All headings, outputs, and local links (including the profile troubleshooting fragment) match. No obvious mobile blocker found. |
| `pre-fit-response-screening` | **PASS** | The current exported screening API is used in both wide and canonical long form, and the rendered equality check is `TRUE`. Global warning suppression is removed; the lifecycle/parser warning, initial `FAIL 4 | WARN 1 | PASS 13`, trait/pair/design tables, five recommendations, and deliberately retained rarity warning are all visible and explained by scope. Limits are unusually clear: binary families only, pair redundancy Bernoulli-only, no automatic deletion, no separation/identifiability/convergence guarantee, and no structured covariance tiers. No internal IDs/process prose or deprecated covariance functions appear. Headings and links match; long code-output tables scroll rather than silently clipping. |
| `pitfalls` | **PASS** | The metadata now promises six checks with concrete checks and examples, matching the six numbered sections. The opening routes readers to `converged`, `optimizer_converged`, and raw `max_gradient`, while labelling `scaled_gradient` as secondary and unable to override failed primary checks. Global warning suppression is removed and the rendered lifecycle/parser warning remains visible. The examples and rendered outputs are synchronized; linked pages exist; current covariance examples use `latent()`, `indep()`, `meta_V()`, and relatedness inputs without deprecated `unique()` functions. Long-only presentation is justified and links to the side-by-side wide/long starter. |

## Remaining blockers

None in this four-page batch. All four articles were rebuilt individually with
`pkgdown::build_article(..., lazy = FALSE)` after removing global warning
suppression; no render-time command failure or unrelated warning required local
suppression.
