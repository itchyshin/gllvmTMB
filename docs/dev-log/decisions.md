# Decisions log

Date-stamped one-paragraph design decisions. Append-only.

## 2026-05-10  Bootstrap fresh repo from gllvmTMB-native subset

Decision: rebuild gllvmTMB from a clean GitHub repository
(`itchyshin/gllvmTMB`, initial commit `ca4e927`) rather than continuing
to ship the legacy package's 133 exports (65 gllvmTMB-native +
68 sdmTMB-inherited). Rationale: the legacy NAMESPACE breaks the
"standalone" promise and the 28-min R CMD check is too slow for the
3-OS CI matrix the maintainer is committing to. Modelled the team
discipline (Codex agents, project-local skills, design docs,
after-task reports, decisions log) on the drmTMB sister package.

## 2026-05-10  Title: "Stacked-Trait GLLVMs with TMB"

Decision: 30-character Title satisfying CRAN's <= 65-char limit. The
candidate `Multivariate Latent-Variable Models for Trait Data` was
also acceptable (51 chars) but loses the "stacked" specificity and
adds the noun "Models" twice (once via "Latent-Variable Models" and
once implicitly).

## 2026-05-10  Vendor mesh; do not Imports: sdmTMB

Decision: keep `R/mesh.R`, `R/crs.R`, and the anisotropy plotting
helpers in `R/plot.R` as gllvmTMB-internal copies of the
sdmTMB-derived code, with provenance recorded in `inst/COPYRIGHTS`
and DESCRIPTION's `Authors@R` crediting Sean Anderson, Eric Ward,
Philina English, and Lewis Barnett (the sdmTMB founding authors).
Rationale: the `Imports: sdmTMB` route would have been the simpler
dependency model but adds a heavy runtime dep with its own
toolchain-validation surface (Windows TMB build, Apple Clang
warnings); vendoring keeps the closed dependency surface
constant. Revisit in 0.3.x if the maintainer chooses to slim
further.

## 2026-05-10  cph trim: 5 entries (was 21)

Decision: trim DESCRIPTION's Authors@R cph list to (Nakagawa,
Anderson, Ward, English, Barnett, Kristensen). The legacy 21-cph
list over-credited glmmTMB / VAST / brms / mgcv code paths that we
cut along with `R/fit.R`, `R/smoothers.R`, `R/visreg.R`, and
`R/emmeans.R`. The remaining cph entries match the upstream code
that still ships in `R/mesh.R`, `R/crs.R`, `R/plot.R`'s
`plot_anisotropy*`, and the TMB engine.

## 2026-05-10  Engine moved from inst/tmb/ to src/

Decision: rename and move the multivariate TMB template from
`inst/tmb/gllvmTMB_multi.cpp` (runtime-compiled via `TMB::compile()`,
cached in user_dir) to `src/gllvmTMB.cpp` (compiled at install
time via `LinkingTo: TMB, RcppEigen`). Rationale: the legacy
package's runtime-compile pattern existed to coexist with a static
single-response engine in the same `.so` (TMB does not support two
templates per shared library). With the single-response engine cut,
this constraint disappears and the standard install-time path
matches drmTMB's structure.

The `TMB_LIB_INIT` token was renamed from `R_init_gllvmTMB_multi` to
`R_init_gllvmTMB`, and the `MakeADFun` `DLL =` argument in
`R/fit-multi.R` was updated to `"gllvmTMB"`. `R/multi-template.R`
(the cache machinery) was removed; `useDynLib(gllvmTMB,
.registration = TRUE)` is added via the package-level roxygen block
in `R/zzz.R`.

## 2026-05-11  Sequence pkgdown after green R-CMD-check

Decision: change `.github/workflows/pkgdown.yaml` from an independent
push workflow to a `workflow_run` workflow that starts only after a
successful `R-CMD-check` on `main` / `master`, with manual dispatch
retained. Rationale: match the drmTMB feedback discipline before
optimising runtime. `gllvmTMB` still keeps the full 3-OS
`R-CMD-check` on PRs and `main`; this decision does not add slow-test
gating or a fast lane.

## 2026-05-11  Use one narrow Rose pre-publish gate

Decision: add a project-local `rose-pre-publish-audit` skill and
document it in `AGENTS.md` and `CONTRIBUTING.md`. Rationale: the team
needed a concrete consistency gate for public prose and reference
navigation, not a larger static role system. The gate checks method
lists, defaults, exported function names, the 3 x 5 keyword grid,
argument names, family lists, and stale terminology for README,
vignettes, pkgdown, NEWS, exported roxygen, and generated Rd changes.

## 2026-05-11  User-facing examples pair long + wide

Decision: when demonstrating how to fit a `gllvmTMB` model in
user-facing prose -- README, vignettes, and Tier-1 articles -- show
both the long-format and the wide-format call side by side. Long
is canonical (`gllvmTMB(value ~ ..., data = df_long)`); wide is the
convenience entry (`gllvmTMB_wide(Y, ...)` or
`gllvmTMB(traits(...) ~ ..., data = df_wide)`). Rationale: readers
vary in mental model -- some think of the data as a matrix
(rows = sites, columns = traits), some as a long tibble (one row
per `(unit, trait)` observation). A single example that shows
both reaches both reader types without forcing a translation step.
Roxygen `@examples` blocks for individual keyword or extractor
functions may stay single-form when the keyword is intrinsically
one shape (for instance, `traits()` is wide-only by construction).
The rule is recorded in `AGENTS.md` "Writing Style".

Locks out: canonical Tier-1 article examples that show only one
form without explanation. Applies to every new article, every
README snippet, and every README-driven smoke test going forward.
The first application is the Priority 2 article-rewrite PR;
Priority 3 (weights unification) will extend the pattern with
matrix-weights examples.
