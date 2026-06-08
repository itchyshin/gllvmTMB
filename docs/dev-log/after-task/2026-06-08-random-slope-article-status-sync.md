# After Task: Structured Random-Slope Article Status Sync

**Superseded-in-branch note:** this report records the initial rendered-preview
status-sync. The same branch now also implements the ordinary augmented
`latent()` component under RE-12; see
`docs/dev-log/after-task/2026-06-08-ordinary-latent-reaction-norm.md` for the
current implementation closeout. Statements below that say ordinary unit-tier
augmented `latent()` was not implemented describe the pre-RE-12 state.

**Branch**: `codex/status-random-regression-article-2026-06-08`
**Date**: `2026-06-08`
**Roles (engaged)**: `Ada / Pat / Rose / Fisher / Grace`

## 1. Goal

Keep the Julia bridge lane separate and finish the main documentation lane:
status-sync plus one honest public structured-random-slope article. The
ordinary behavioural random-regression article remains internal because the
right model is `unit = "individual"` with augmented unit-tier random
intercept/slope blocks, and that engine support is not implemented yet.

## 2. Implemented

- Promoted `random-slopes-nongaussian` to the public Model guide.
- Kept `random-regression-reaction-norms` buildable but internal.
- Reworked `random-regression-reaction-norms` as the target article for the
  Appendix-B behavioural model: individual-level reaction norms, `unit =
  "individual"`, `unit_obs = "session_id"`, temperature/context varying within
  individuals, and an augmented `2T x 2T` between-individual covariance for
  personality, plasticity, and personality-plasticity associations.
- Removed `phylo_slope()` / `animal_slope()` as public teaching routes for the
  ordinary reaction-norm article. These legacy single-variance paths are not
  substitutes for individual-level random regression.
- Updated `_pkgdown.yml`, README, ROADMAP, NEWS, Design 61, and the article
  gate matrix so only the structured-slope article is public in this slice.

## 3. Files Changed

Public article:

- `vignettes/articles/random-slopes-nongaussian.Rmd`

Internal target article:

- `vignettes/articles/random-regression-reaction-norms.Rmd`

Public routing and status:

- `_pkgdown.yml`
- `README.md`
- `ROADMAP.md`
- `NEWS.md`
- `docs/design/61-capability-status.md`
- `docs/dev-log/audits/2026-05-20-article-gate-matrix.md`

Dev-log closure:

- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-08-random-slope-article-status-sync.md`

## 4. Decisions

Decision: keep one good random-regression article, but keep it internal until
the correct engine exists.

Rationale: the attached Appendix B defines the right article: random slopes at
the between-individual ID level, within-individual occasion effects as random
intercepts/covariance only, and interpretation of intercept-intercept,
slope-slope, and intercept-slope covariance blocks. Publicly teaching this with
`phylo_slope()` or spatial/phylogenetic dependence would answer a different
scientific question.

Rejected alternative: publish a Gaussian `phylo_slope()` behavioural example.
That used a deprecated/legacy structured route and was rejected after rendered
preview.

Decision: leave `random-slopes-nongaussian` public.

Rationale: it is explicitly about structured phylogenetic and spatial slope
cells with row-level validation evidence. It no longer routes readers to the
internal ordinary reaction-norm article as a public foundation.

Decision: do not move validation-debt status.

Rationale: this slice is documentation/routing/status work. The ordinary
unit-tier augmented-LHS feature still needs implementation and simulation
recovery before any public claim.

## 5. Checks Run

- `gh pr list --state open --json number,title,headRefName,baseRefName,author,updatedAt --limit 20`
  -> `[]`; no open PR collision.
- `git log --all --oneline --since="6 hours ago"`
  -> no same-window shared-file commits returned.
- `pdftotext -layout /Users/z3437171/Downloads/GLLVMs_for_studying_behavioural_syndromes.pdf ...`
  -> appendix text inspected; Appendix B identifies the individual-level random
  regression target.
- `pdftoppm -png -f 16 -l 22 /Users/z3437171/Downloads/GLLVMs_for_studying_behavioural_syndromes.pdf ...`
  -> appendix pages rendered for visual inspection if needed.
- `Rscript --vanilla - <<'RS' ...`
  -> scratch-tested the Appendix-B target syntax; source checkout aborts
  expectedly with "`latent()` augmented LHS is not yet supported."
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/random-regression-reaction-norms", quiet = FALSE, new_process = FALSE)'`
  -> rendered the internal target article.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/random-slopes-nongaussian", quiet = FALSE, new_process = FALSE)'`
  -> rendered the public structured-slope article.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean.

## 6. Consistency Audit

- `rg -n "phylo_slope\\(|animal_slope\\(|random-regression-reaction-norms.html" README.md NEWS.md ROADMAP.md _pkgdown.yml vignettes/articles/random-slopes-nongaussian.Rmd`
  -> no public article route to the internal reaction-norm article and no
  deprecated single-variance slope keyword in new public article prose.
- `rg -n "\\\\\\|" vignettes/articles/random-regression-reaction-norms.Rmd vignettes/articles/random-slopes-nongaussian.Rmd pkgdown-site/articles/random-regression-reaction-norms.html pkgdown-site/articles/random-slopes-nongaussian.html`
  -> no rendered escaped-pipe syntax remains in the touched articles.
- `rg -n "ordinary non-structured|unit = \"individual\"|unit_obs = \"session_id\"|augmented LHS|latent\\(0 \\+ trait \\+ \\(0 \\+ trait\\):temperature \\| individual" ...`
  -> internal target article and status files carry the correct ordinary
  behavioural random-regression boundary.

## 7. Known Limitations And Next Actions

- Ordinary non-structured random regression remains unimplemented at the unit
  tier. Required syntax is
  `latent(0 + trait + (0 + trait):x | individual, d = d_B)` plus the matching
  `unique()` block.
- The public structured-slope article remains point-estimate/recovery framed;
  calibrated intervals are still out of scope.
- Non-Gaussian `phylo_dep(..., s >= 2)` remains partial under RE-03.
- Full `devtools::check()` was not run because this was a documentation and
  pkgdown-routing slice with targeted renders plus `pkgdown::check_pkgdown()`.
