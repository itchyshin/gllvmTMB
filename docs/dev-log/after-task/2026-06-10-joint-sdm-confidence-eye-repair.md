# After Task: Joint-SDM Confidence Eye Figure Repair

Date: 2026-06-10
Branch: `main`
Roles engaged: Ada, Pat, Florence, Fisher, Rose, Grace

## Goal

Repair the public binary JSDM article's loading Confidence Eye figure. The
visible failure was that the SDM article used the cheap `wald_retention`
suggestion for the displayed constrained refit; in this fixture that suggestion
over-pruned the loading matrix and produced an all-pinned, Hessian-failed plot.

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE, generated Rd,
or pkgdown navigation change. The article still fits the same binary-logit JSDM
with `latent(0 + trait | site, d = 2)`. The displayed loading diagnostic now
uses the already-supported `profile_retention` constraint before plotting Wald
intervals on the constrained refit.

## Files Changed

- `vignettes/articles/joint-sdm.Rmd`
  - Compares `varimax_threshold`, `wald_retention`, and
    `profile_retention` in the SDM article.
  - Uses the recommended profile-retention constraint for the displayed
    constrained refit.
  - Rewrites the figure caption, alt text, y-axis label, and subtitle so the
    figure describes profile-retention rather than the old Wald-only path.
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-10-joint-sdm-confidence-eye-repair.md`

## Checks Run

- `gh pr list --state open --limit 20 --json number,title,headRefName,updatedAt,isDraft,url` -> `[]`.
- `git log --all --oneline --since="6 hours ago" -- vignettes/articles/joint-sdm.Rmd docs/dev-log/check-log.md docs/dev-log/after-task _pkgdown.yml` -> only `9d0548b Codex worktree snapshot: archive-cleanup`.
- Diagnostic R script comparing `varimax_threshold`, `wald_retention`, and `profile_retention` -> `profile_retention` pinned 9 / 16 entries, left 7 free, refit with `pdHess = TRUE`, and produced finite Wald intervals for all 7 free rows.
- `air format vignettes/articles/joint-sdm.Rmd` -> clean.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/joint-sdm", lazy = FALSE, new_process = FALSE)'` -> wrote `pkgdown-site/articles/joint-sdm.html`.
- `rg -n "profile-retention constrained|Profile-retention constraint|profile_retention|wald_retention|non-positive-definite Hessian|jsdm-loading-confidence-eye|Loading estimate" pkgdown-site/articles/joint-sdm.html vignettes/articles/joint-sdm.Rmd` -> fixed article/HTML handles present.
- `rg -n "methods = c\\(|varimax_threshold|wald_retention|profile_retention|threshold = 0\\.30|retention_prob = 0\\.90|pi\\^2 / 3|sigma_d2" R/suggest-lambda-constraint.R vignettes/articles/joint-sdm.Rmd man/suggest_lambda_constraints.Rd pkgdown-site/articles/joint-sdm.html` -> method/default claims agree.
- `rg -n "Hessian non-PD; CIs unavailable|all-NA|eval = FALSE|not run in the first-pass|wald_retention.*recommended|recommended_method.*wald_retention|profile.*not run" vignettes/articles/joint-sdm.Rmd pkgdown-site/articles/joint-sdm.html || true` -> no stale non-PD loading-figure text; remaining `eval = FALSE` chunks are deliberate optional heavy correlation/bootstrap chunks.
- `rg -n "gllvmTMB\\(" vignettes/articles/joint-sdm.Rmd` -> long calls include `trait = "trait"` and the wide `traits(...)` call correctly omits it.
- `rg -n "\\bS_B\\b|\\bS_W\\b|\\\\bf S|gllvmTMB_wide|meta_known_V|\\bphylo\\(|\\bgr\\(|\\bmeta\\(|block_V\\(|phylo_rr\\(" vignettes/articles/joint-sdm.Rmd pkgdown-site/articles/joint-sdm.html || true` -> no hits.
- Browser check at `http://127.0.0.1:8123/articles/joint-sdm.html?v=20260610-jsdm-profile-eye#check-loadings-before-naming-axes` -> fixed article has profile-retention text, no old non-PD loading subtitle, and a refreshed `jsdm-loading-confidence-eye` image.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` -> `No problems found.`
- `git diff --check` -> clean.

## Consistency Audit

Rose: PASS. The article now matches the source contract for
`suggest_lambda_constraints()`: default methods remain
`varimax_threshold` / `wald_retention`, but when `profile_retention` is included
it is recommended. The SDM article explicitly passes `sigma_d2 = pi^2 / 3` for
the binary-logit fixture and no longer claims the profile path is not run.

Pat: PASS with one caveat. The SDM article stays Tier 1 because the worked
example remains runnable in long and wide forms. The loading-method comparison
is now short enough for the public article, with the deeper explanation linked
to `lambda-constraint-suggest.html`.

Florence: PASS. The old figure failed because it had no intervals and showed
only pinned grey points. The refreshed figure has a visible profile-retention
constraint, seven free loading intervals, a readable y-axis label, and caption
text that names the interval provenance.

## Tests Of The Tests

No new test file was added. This is a rendered-article repair. The failure was
confirmed by direct diagnostic R output before the edit: `wald_retention`
over-pruned and refit with `pdHess = FALSE`; `profile_retention` refit with
`pdHess = TRUE` and finite intervals. The article render and browser check are
the tests for the user-visible failure.

## What Did Not Go Smoothly

The browser initially held a cached copy of the old article. A cache-busted URL
confirmed the local server was serving the fixed HTML and figure.

## Team Learning

Ada: A cheap recommended method can be mathematically valid but visually useless
for a public teaching figure. The orchestrator should check the rendered figure,
not only the code path.

Pat: Keep the SDM article focused on the applied workflow. The deeper method
comparison belongs in the Lambda-suggestion article, which the SDM article now
links explicitly.

Fisher: `pdHess = FALSE` correctly blocked Wald intervals; the fix is not to
pretend those intervals exist, but to choose a better constrained refit before
plotting.

Florence: The Confidence Eye contract worked once the input had real finite
intervals. The y-axis label needed plain text rather than the rendered
`\hat{\Lambda}` symbol at article size.

Rose: The exact stale-wording scans matter. The old "not run in the first-pass"
profile wording was removed from the SDM article, while optional heavy
correlation/bootstrap chunks remain explicit `eval = FALSE` examples.

Grace: The targeted article render plus `pkgdown::check_pkgdown()` was the right
local gate for this vignette-only repair. During deployment closeout, full local
`devtools::check(args = "--no-manual")` was also run; it returned 0 errors, 1
install WARNING from the local macOS compiler/toolchain, and 2 existing NOTEs.

## Design Docs, NEWS, Roadmap

No design doc, NEWS, ROADMAP, or validation-debt register row changed. The
underlying methods were already present; this task changes which supported
method the SDM article uses for the displayed loading diagnostic.

## Pkgdown / Documentation

`pkgdown::build_article("articles/joint-sdm", lazy = FALSE, new_process = FALSE)`
refreshed the affected HTML and figure. `pkgdown::check_pkgdown()` returned
`No problems found`.

## Roadmap Tick

N/A. This advances the public article polish lane but does not change a
ROADMAP.md status row.

## GitHub Issue Ledger

`gh issue list --repo itchyshin/gllvmTMB --state open --limit 30 --search "JSDM OR SDM OR species distribution OR confidence eye OR lambda" --json number,title,url,labels,updatedAt`
found existing relevant trackers #230 and #347. No issue was created, closed,
or commented.

## Known Limitations And Next Actions

- `bootstrap_retention` remains planned, not implemented.
- The SDM article now runs the slower `profile_retention` suggestion, adding
  about 20-25 seconds to this article render on the local fixture.
- `pkgdown::build_site()` was not run locally; affected articles were rendered
  individually and `pkgdown::check_pkgdown()` passed.
- Full local `devtools::check()` ran during closeout but returned an install
  WARNING from the local compiler/toolchain rather than a clean green result.
