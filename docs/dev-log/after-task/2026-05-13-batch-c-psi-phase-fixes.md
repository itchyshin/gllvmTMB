# After-task: Batch C -- Psi notation + Phase-label cleanup -- 2026-05-13

**PR / branch**: pending / `agent/batch-c-psi-phase-fixes`

**Lane**: Claude (article-only sweep; per audit doc Batch C scope).

**Dispatched by**: maintainer 2026-05-13 ~21:00 MT (*"Batch C - After
this you can call it a day - but I want you to show what is planned"*).

**Files touched**:
- `vignettes/articles/functional-biogeography.Rmd` (6 edits)
- `vignettes/articles/joint-sdm.Rmd` (3 edits)

No source / API / math change. No new vocabulary.

## Math contract

Unchanged. The Sigma = Lambda Lambda^T + Psi -> Sigma = Lambda
Lambda^T + S notation switch is *renaming*, not redefinition.
The diagonal entries the symbol refers to are identical; we are
swapping the symbol to follow the project canon (PR #40 + PR #72
S/s naming convention; check-log point 9).

## What changed

### `vignettes/articles/functional-biogeography.Rmd` -- 6 Psi -> S

Per-line verification (audit doc Item 5 caveat:
"do not blanket-replace Psi -> S; verify per occurrence"):

| Line | Context | Replacement |
|---|---|---|
| 185 | `Sigma_B = Lambda_B Lambda_B^T + Psi_B` (between-site trait covariance) | `... + S_B` |
| 188 | `Sigma_W = Lambda_W Lambda_W^T + Psi_W` (within-site) | `... + S_W` |
| 482 | `Sigma_R = Lambda_R Lambda_R^T + Psi_R` (spatial-tier) | `... + S_R` |
| 506 | `Lambda_R and Psi_R separately` (identifiability prose) | `... and S_R separately` |
| 515 | `Sigma_P = Lambda_P Lambda_P^T + Psi_P` (phylo-tier) | `... + S_P` |
| 540 | `Psi_P requires K_P < T` (identifiability prose) | `S_P requires ...` |

All six are confirmed to be the *model-side unique-variance
diagonal* in the `Sigma = Lambda Lambda^T + Psi` formulation.
None are the `extract_phylo_signal()` derived per-trait scalar
`Psi_t = 1 - H^2 - C^2_non` (which stays as `Psi`).

**Bold style**: the article uses `\boldsymbol{\Lambda}` /
`\boldsymbol{\Sigma}` throughout, so the replacements use
`\boldsymbol{S}` to keep the article internally consistent. The
project canon (check-log point 9) prefers `\mathbf{S}`; the
*letter* is the rule, the bold style is article-local.
A future cross-article styling sweep can normalise
`\boldsymbol{X}` -> `\mathbf{X}` if desired.

### `vignettes/articles/joint-sdm.Rmd` -- 3 in-prep Phase labels

In-prep manuscript phase labels in user-facing prose -> descriptive
replacements naming what the planned change does:

| Line | Was | Is |
|---|---|---|
| 126 | `Phase D follow-up will add a one-shot info message ...` | `a planned follow-up will add ...` |
| 183 | `The Phase D follow-up will add per-family-aware ...` | `A planned follow-up will add ...` |
| 291 | `once Phase K's warm-started TMB::tmbprofile() accelerates the path.` | `once a warm-started TMB::tmbprofile() (planned) accelerates the path.` |

## What this does NOT do

- Does not touch `\boldsymbol{\Lambda}` -> `\Lambda` styling.
  Separate sweep if maintainer wants `\mathbf{}` everywhere.
- Does not touch `extract_correlations(fit, tier = "unit")` on
  joint-sdm.Rmd line 296. The `tier =` vs `level =` API
  inconsistency is parked as audit item #10.
- Does not touch `\Psi` in any roxygen
  `extract_phylo_signal()` context where it's the derived
  per-trait scalar.

## Risk

Low. Article-prose only. Math content unchanged (renaming).

## Tests of the tests

No tests added (docs-only). CI runs the package `R CMD check`
which builds the articles; any LaTeX malformation would surface
as an `R CMD check` failure.

## Self-merge eligibility

Article wording only, no source, no rules, no API. Self-merge
once CI is green per the merged plan
(`docs/dev-log/audits/2026-05-13-post-overnight-drift-scan.md`,
Batch C scope).
