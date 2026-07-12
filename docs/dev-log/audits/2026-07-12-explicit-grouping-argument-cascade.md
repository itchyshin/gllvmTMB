# Explicit grouping-argument cascade

**Date:** 2026-07-12  
**Scope:** every displayed `gllvmTMB()` call in the 13 retained article set,
excluding `phylogenetic-gllvm.Rmd` from this implementation pass as directed  
**Verdict:** **PASS — no blockers**

## Result

Twenty-two executable calls passed the parsed role check. Five non-executed
teaching calls passed direct source inspection. One additional commented call
in `pitfalls.Rmd` intentionally demonstrates the error produced when the
default `unit = "site"` column is absent; the same section immediately shows
the correct `unit = "individual"` override. No nonexistent grouping column was
added, and no call required `cluster` or `cluster2` in this scoped article set.

Three articles required changes:

- `profile-likelihood-ci.Rmd`: both calls now state `unit = "site"` and
  `unit_obs = "site_species"`; the long call retains `trait = "trait"`.
- `pitfalls.Rmd`: the estimand example now states `unit = "site"`.
- `gllvm-vocabulary.Rmd`: the display-only long call now states
  `trait = "trait"`; adjacent prose explains the long/wide default and override
  rule.

`phylogenetic-gllvm.Rmd` was not edited. Its latent-focused long/wide role
arguments had already passed the preceding targeted Rose audit.

## Call-by-call ledger

| Article | Call and source line | Shape | Explicit role arguments | Decision |
|---|---|---|---|---|
| `fit-diagnostics.Rmd` | `fit_long`, line 90 | long | `trait = "trait"`; `unit = "individual"` | PASS |
| `fit-diagnostics.Rmd` | `fit_wide`, line 117 | wide | `unit = "individual"` | PASS |
| `fit-diagnostics.Rmd` | `fit_no_se`, line 216 | long | `trait = "trait"`; `unit = "individual"` | PASS |
| `convergence-start-values.Rmd` | `fit`, line 90 | long | `trait = "trait"`; `unit = "site"` | PASS |
| `convergence-start-values.Rmd` | `fit_wide`, line 111 | wide | `unit = "site"` | PASS |
| `convergence-start-values.Rmd` | `fit_no_se`, line 246 | long | `trait = "trait"`; `unit = "site"` | PASS |
| `pre-fit-response-screening.Rmd` | no `gllvmTMB()` call | — | Uses the separate `screen_gllvmTMB()` API | Out of call scope |
| `pitfalls.Rmd` | `fit`, line 128 | long | `trait = "trait"`; `unit = "site"` | PASS after repair |
| `pitfalls.Rmd` | commented mismatched call, line 230 | long negative example | `trait = "trait"`; intentionally relies on absent default `site` | PASS as an explicit error demonstration; prose at lines 219–222 explains the default and override |
| `pitfalls.Rmd` | `fit_ind`, line 234 | long | `trait = "trait"`; `unit = "individual"` | PASS |
| `profile-likelihood-ci.Rmd` | `fit_long`, line 103 | long | `trait = "trait"`; `unit = "site"`; `unit_obs = "site_species"` | PASS after repair |
| `profile-likelihood-ci.Rmd` | `fit_wide`, line 114 | wide | `unit = "site"`; `unit_obs = "site_species"` | PASS after repair |
| `missing-data.Rmd` | `fit_response_wide`, line 91 | wide | `unit = "site"` | PASS |
| `missing-data.Rmd` | `fit_response_long`, line 108 | long | `trait = "trait"`; `unit = "site"` | PASS |
| `missing-data.Rmd` | `fit_predictor`, line 178 | wide | `unit = "site"` | PASS |
| `missing-data.Rmd` | `fit_predictor_long`, line 211 | long | `trait = "trait"`; `unit = "site"` | PASS |
| `gllvm-vocabulary.Rmd` | unnamed long teaching call, line 63 | long, `eval = FALSE` | `trait = "trait"`; `unit = "site"` | PASS after repair |
| `gllvm-vocabulary.Rmd` | unnamed wide teaching call, line 72 | wide, `eval = FALSE` | `unit = "site"` | PASS |
| `api-keyword-grid.Rmd` | `fit_long`, line 153 | long, `eval = FALSE` | `trait = "trait"`; `unit = "individual"` | PASS |
| `api-keyword-grid.Rmd` | `fit_wide`, line 161 | wide, `eval = FALSE` | `unit = "individual"` | PASS |
| `fixed-effect-zero-constraints.Rmd` | `fit_long`, line 107 | long | `trait = "trait"`; `unit = "site"` | PASS |
| `fixed-effect-zero-constraints.Rmd` | `fit_wide`, line 142 | wide | `unit = "site"` | PASS |
| `response-families.Rmd` | `fit_long`, line 171 | long | `trait = "trait"`; `unit = "unit"` | PASS |
| `response-families.Rmd` | `fit_wide`, line 180 | wide | `unit = "unit"` | PASS |
| `response-families.Rmd` | `fit_mixed`, line 218 | long, `eval = FALSE` | `trait = "trait"`; `unit = "unit"` | PASS |
| `behavioural-syndromes.Rmd` | `fit_long`, line 230 | long | `trait = "trait"`; `unit = "individual"`; `unit_obs = "occasion"` | PASS |
| `behavioural-syndromes.Rmd` | `fit_wide`, line 242 | wide | `unit = "individual"`; `unit_obs = "occasion"` | PASS |
| `random-regression-reaction-norms.Rmd` | `fit_long`, line 212 | long | `trait = rr$fit_args$trait`; `unit = rr$fit_args$unit`; `unit_obs = rr$fit_args$unit_obs` | PASS; fixture resolves to `trait`, `individual`, and `session_id` |
| `random-regression-reaction-norms.Rmd` | `fit_wide`, line 222 | wide | `unit = rr$fit_args$unit`; `unit_obs = rr$fit_args$unit_obs` | PASS; fixture resolves to `individual` and `session_id` |

The remaining retained phylogenetic article was intentionally excluded from
edits. Its four calls were already verified as two long and two wide fits with
explicit `trait` where applicable, `unit`, `unit_obs` for the split example,
and `cluster`.

## Default and override decisions

- A one-tier call names `unit` explicitly even when the column is literally
  `site`; this keeps the teaching contract visible rather than relying on the
  package default.
- Wide calls omit `trait =` because the `traits(...)` left-hand side declares
  the response columns.
- `site_species` in the profile example is a within-site sampling cell, so it
  is assigned to `unit_obs`, not promoted to a nonexistent third-tier
  `cluster` role.
- `occasion` and `session_id` are within-unit replicate cells in their
  respective repeated-measures examples, so they remain `unit_obs`.
- No scoped formula contains a valid third grouping tier requiring `cluster`
  or `cluster2`. These arguments were therefore not invented.
- The commented pitfalls mismatch deliberately retains the default-unit error;
  changing it would erase the error-recovery lesson.

## Verification

```sh
set -o pipefail
Rscript --vanilla -e 'for (x in c("articles/profile-likelihood-ci", "articles/pitfalls", "articles/gllvm-vocabulary")) { message("BUILD ", x); pkgdown::build_article(x, pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE) }' \
  2>&1 | tee /tmp/gllvmtmb-grouping-argument-cascade.log
# Outcome: exit 0; three build headers and three Output created records.

rg -n -i '(^|[^[:alpha:]])(warning|error|execution halted|deprecated|failed)([^[:alpha:]]|$)' \
  /tmp/gllvmtmb-grouping-argument-cascade.log
# Outcome: zero matches.

# Parsed knitr code for every executable gllvmTMB() call outside the excluded
# phylogenetic article. Long calls required trait + unit; wide calls required
# unit; profile, behavioural, and reaction-norm calls additionally required
# unit_obs. Any cluster/cluster2 argument was rejected unless a third tier was
# present.
# Outcome: 22 executable calls checked; 22 PASS; 0 failures.

# The five eval=FALSE calls and one commented negative example were inspected
# directly because knitr::purl() comments non-evaluated chunks.
# Outcome: five positive teaching calls PASS; one intentional negative example
# retained with its default/override explanation.

stat -f '%m %N' \
  vignettes/articles/{profile-likelihood-ci,pitfalls,gllvm-vocabulary}.Rmd \
  pkgdown-site/articles/{profile-likelihood-ci,pitfalls,gllvm-vocabulary}.html
# Outcome: all three rendered HTML files are newer than their sources.
```

## Blockers

None.
