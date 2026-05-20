# After Task: Convergence And Start-Values Article

**Branch**: `codex/convergence-start-values-article-2026-05-19`
**Date**: `2026-05-19`
**Roles (engaged)**: Ada / Boole / Pat / Fisher / Grace / Rose / Shannon

## 1. Goal

Draft the reader-facing convergence/start-values article after the
robust-modeling diagnostics and M3.3a schema smoke tests were in
place. The article should teach users how to read fit-health
diagnostics, what `pdHess = FALSE` means, how to choose start values,
and why hard fits may use `gllvmTMBcontrol(se = FALSE)` with
bootstrap or profile uncertainty.

## 2. Implemented

- Added `vignettes/articles/convergence-start-values.Rmd`.
- Registered the article in `_pkgdown.yml` under Methods and
  validation.
- Updated the M3.4 roadmap row to mark the article as drafted and to
  keep target-explicit empirical evidence and family stress lanes as
  remaining work.
- Kept the article evidence-bounded: DIA-08 and DIA-10 are marked
  covered, DIA-09 remains partial, and start-method default-policy
  claims remain M3.3a/M3.4 evidence work.

## 3. Files Changed

- `_pkgdown.yml`
- `ROADMAP.md`
- `vignettes/articles/convergence-start-values.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-19-convergence-start-values-article.md`

No generated Rd, NAMESPACE, R source, tests, family code, formula
grammar, or likelihood files changed.

## 3a. Decisions and Rejected Alternatives

Decision: keep the article as a practical troubleshooting guide rather
than a simulation-results article.

Rationale: the M3.3a pilot schema is now smoke-tested, but production
evidence for family-specific default policies is not yet available.

Rejected alternative: presenting residual starts, independent starts,
or `optim(BFGS)` as new defaults. Those remain opt-in until Curie and
Fisher produce target-explicit evidence.

Confidence: high for the documentation shape; medium for final
recommendation wording until the M3.3a pilot produces larger evidence.

## 4. Checks Run

- `git status --short --branch`
  -> clean start on `codex/m3-3a-fit-health-pilot-2026-05-19`.
- `git diff --stat`
  -> no uncommitted diff at lane start.
- `gh pr list --state open`
  -> #206 open / ready branch, #207 draft stacked branch.
- `git log --all --oneline --since="6 hours ago"`
  -> recent M3 / robust-modeling commits inspected.
- `git switch codex/rr-residual-starts-2026-05-19`
  -> switched to the robust-modeling branch.
- `git switch -c codex/convergence-start-values-article-2026-05-19`
  -> created this docs branch from #206.
- `Rscript --vanilla -e 'pkgdown::build_article("convergence-start-values")'`
  -> failed because the article lives under `vignettes/articles/`.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/convergence-start-values")'`
  -> found the article but failed because the installed package did
  not yet export branch-local `check_gllvmTMB()`.
- `Rscript --vanilla -e 'devtools::load_all(".", quiet = TRUE); pkgdown::build_article("articles/convergence-start-values", new_process = FALSE)'`
  -> rendered `articles/convergence-start-values.html`; pkgdown
  printed the existing missing-template-image note for `../logo.png`.
- `Rscript --vanilla -e 'devtools::load_all(".", quiet = TRUE); pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean.

## 5. Tests of the Tests

No package tests were added or modified. The integration check for
this docs-only lane is the rendered article: it exercises the small
long-format `gllvmTMB()` fit, `gllvmTMBcontrol(se = FALSE)`,
`check_gllvmTMB(fit)`, and `fit$restart_history` in the branch-local
namespace.

## 6. Consistency Audit

- `rg -n "gllvmTMB\(" vignettes/articles/convergence-start-values.Rmd`
  -> long-format call passes `trait = "trait"` and `unit = "site"`;
  wide-format call uses the `traits(...)` LHS and does not pass a
  `trait` argument.
- `rg -n "DIA-08|DIA-09|DIA-10|MIS-16|MIS-18|MIS-19|MIS-20|EXT-13|CI-02|CI-03" docs/design/35-validation-debt-register.md`
  -> article claims map to explicit covered / partial register rows.
- `rg -n "convergence-start-values|se = FALSE|pdHess|bootstrap|start_method|check_gllvmTMB" README.md ROADMAP.md NEWS.md docs/dev-log/known-limitations.md docs/design _pkgdown.yml vignettes/articles/convergence-start-values.Rmd`
  -> new article and roadmap wording are consistent with Design 49,
  NEWS, and the validation-debt register.
- `rg -n "full.*rejected|only diagonal|planned.*implemented|deprecated.*0\\.1" README.md ROADMAP.md NEWS.md docs vignettes`
  -> hits only existing known-limitations / protocol text and an
  intentional `indep()` explanation, not the new article.
- `rg -n "S_B|S_W|\\\\bf S|gllvmTMB_wide|meta_known_V|\\bphylo\\(|\\bgr\\(|\\bmeta\\(|block_V\\(|phylo_rr\\(|in prep|in preparation" vignettes/articles/convergence-start-values.Rmd _pkgdown.yml`
  -> only hit is existing `_pkgdown.yml` reference registration for
  deprecated alias `meta_known_V`; no new article hit.

## 7. Roadmap Tick

M3.4 remains partial, but its Done-when text now states that the
convergence/start-values article is drafted. Remaining M3.4 work is
target-explicit empirical evidence, default-policy decisions, and
family-specific stress lanes.

## 8. What Did Not Go Smoothly

The first `pkgdown::build_article()` call used the short article name
and could not find the file under `vignettes/articles/`. The second
call found the file but used the installed package namespace, which
did not yet have `check_gllvmTMB()`. Rendering with
`devtools::load_all(".", quiet = TRUE)` and `new_process = FALSE`
validated the branch-local article.

## 9. Team Learning

Ada kept the branch split clean: this article branch is based on the
robust-modeling PR, not on the M3.3a dev-script pilot branch.

Boole kept the API examples concrete: the article uses
`gllvmTMBcontrol(se = FALSE)`, `n_init`, `init_jitter`,
`start_method`, `start_from`, and `optimizer` syntax without inventing
new controls.

Pat pushed the article toward a reader rescue path: fit a small model,
read the diagnostic table, choose a start strategy, then use
bootstrap/profile when Hessian-based uncertainty is weak.

Fisher kept the inference language honest: `pdHess = FALSE` is an
inference and identifiability warning, not proof that point estimates
are unusable.

Grace verified pkgdown navigation and article rendering with the
branch-local namespace.

Rose checked that the article cites validation-debt rows and avoids
claiming default start-policy evidence before M3.3a/M3.4 simulations.

Shannon's lane check kept the PR stack explicit: #206 is the green
robust-modeling base, #207 is the draft M3.3a script branch, and this
docs branch stays separate.

## 10. Known Limitations And Next Actions

- DIA-09 remains partial until there is a deterministic in-fit
  `sdreport()` failure fixture.
- Start methods are opt-in tools. Promotion to defaults waits for
  M3.3a/M3.4 evidence.
- The article shows multicore bootstrap as an uncertainty workflow,
  but larger local / Slurm / Canada Compute wrappers remain Branch B
  and later infrastructure work.
- Next: merge or rebase after #206, then use Branch B's M3.3a schema
  to run larger Gaussian, `nbinom2`, mixed-family, and two-level
  pilot cells.
