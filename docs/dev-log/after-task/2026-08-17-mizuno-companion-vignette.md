# After Task: Mizuno et al. (2025) phylogenetic ordinal/nominal PGLMM companion vignette

**Branch**: `claude/1099-mizuno-vignette-20260817`
**Date**: `2026-08-17`
**Roles (engaged)**: `Pat / Rose / Grace / Fisher`

## 1. Goal

Build a pkgdown article reproducing the two worked examples of Mizuno,
Drobniak, Williams, Lagisz & Nakagawa (2025, *J. Evol. Biol.*
38:1699-1715, doi:10.1093/jeb/voaf116) — a phylogenetic-PGLMM tutorial
for discrete traits, Bayesian-only (MCMCglmm/brms) — as `gllvmTMB`
fits, using the paper's own archived data. The task split into a
feasibility/plumbing slice (data layer + prove the fits run) and a
prose slice (the article itself), both completed in this branch.

## 2. Implemented

- A fetch-on-build data layer (`dev/mizuno-vignette/fetch-mizuno-data.R`)
  for the paper's four archive files, with caching, schema validation,
  and no-network degradation (see §4/§8 for data provenance and the
  no-network smoke).
- `vignettes/articles/phylogenetic-categorical-pglmm.Rmd`, registered
  in `_pkgdown.yml` under "Model Guides" (navbar menu + articles
  index), covering:
  - **Example 1 (ordinal_probit, bivariate).** Accipitridae, 136
    species. `Migration_ordered` (3-level) paired with a second real
    trait, `Habitat.Density` (3-level), plus `logMass` as a shared
    covariate on both traits. Long call:
    `value ~ 0 + trait + trait:logMass + phylo_dep(0 + trait | species, tree = tree)`,
    `family = ordinal_probit()`. Wide call:
    `traits(migration, habitat_density) ~ 1 + logMass + phylo_dep(1 | species, tree = tree)`.
    Verified logLik-identical (diff `1.02e-12`). `fit_health`:
    `convergence = 0`, `pd_hessian = TRUE`, `sdreport_ok = TRUE`.
    Wall-clock 1.2-3.1 s across repeated interactive/pkgdown runs (no
    fixed seed on the data-generating side — this is real, not
    simulated, data, so there is nothing to reseed; small run-to-run
    timing variance is expected). Headline estimates:
    `extract_phylo_signal(link_residual = "auto")` gives H^2(migration)
    ~= 0.41-0.45, H^2(habitat_density) ~= 0.87 (paper eq 18,
    `sigma_e^2 = 1` fixed liability residual);
    `extract_correlations(tier = "phy")` gives a positive phylogenetic
    correlation between the two traits (~= 0.38), reported as a single
    point estimate with **no** calibrated interval — consistent with
    the "open-country migrant" hypothesis but not a tested claim.
    `extract_cutpoints()` results carried alongside a Box-2 translation
    note (gllvmTMB's `tau_1 = 0` convention is Hadfield's/MCMCglmm's,
    not brms's zero-intercept convention; the two differ by a location
    shift only).
  - **Example 2 (multinomial, univariate).** Turdidae, 173 species, K =
    3 `Primary.Lifestyle` categories. Long call:
    `value ~ 0 + trait + phylo_latent(species, tree = tree, d = K - 1)`,
    `family = multinomial()`. Wide call:
    `traits(lifestyle) ~ 1 + phylo_latent(1 | species, tree = tree, d = K - 1)`.
    Verified logLik-identical (diff `0`, to reported precision).
    `fit_health`: `convergence = 0`, `pd_hessian = TRUE`. Wall-clock
    ~1.1 s. Per-contrast H^2 (paper eq 19, `pi^2/3` fixed residual per
    contrast, never collapsed to a scalar): Insessorial ~= 0.70,
    Terrestrial ~= 0.74 (baseline: Generalist). The among-category
    phylogenetic correlation is **deliberately withheld** from the
    article text — see §"T=1" below is unrelated; this is a separate,
    documented data-hunger finding (one categorical draw per species is
    the regime `docs/design/123-multinomial-structured-surface.md` §4's
    own recovery campaign found unreliable for the correlation
    specifically, even with `pd_hessian = TRUE`).
  - An independent MCMCglmm comparator for Example 1
    (`Migration_ordered ~ logMass`, univariate, same real data, same
    tree, Hadfield-style prior, `nitt = 33000, burnin = 3000, thin =
    30`). Wall-clock ~24-25 s. `H2` ~= 0.44-0.47, close to gllvmTMB's
    joint-fit H^2(migration) (~= 0.41-0.45). **Reported explicitly as
    qualitative**: MCMCglmm here fits migration alone, gllvmTMB's
    number comes from the joint bivariate fit with habitat density —
    not the same model, so agreement is reassuring but not an
    equivalence test. No comparator was run for Example 2 (nominal);
    that comparison is stated as qualitative-only in the article text.
    No published number from the paper itself is used or approximated
    anywhere — the article states plainly that it does not have access
    to the paper's own posterior output.

## 3. Files Changed

- `dev/mizuno-vignette/fetch-mizuno-data.R` (new)
- `vignettes/articles/phylogenetic-categorical-pglmm.Rmd` (new)
- `_pkgdown.yml` (two additive lines: navbar menu entry + articles
  index entry, both under "Model Guides", inserted immediately after
  the existing `phylogenetic-gllvm` entries)

No `R/`, `src/`, `NAMESPACE`, `man/`, or `tests/testthat/` files
touched. No new exports.

## 3a. Decisions and Rejected Alternatives

- **Decision:** treat the paper's genuinely univariate Example 1 as
  out of `gllvmTMB`'s scope (AGENTS.md line 87: "Single-response
  models (no covstruct keyword) belong in `glmmTMB`") rather than as a
  bug to fix in this PR, and lift the article's Example 1 to a real
  bivariate ordinal PGLMM instead. **Rationale:** three independent
  checks (below) converge on the same root cause, which is a base-R
  structural limitation, not a `gllvmTMB` code defect reachable by a
  small patch. **Rejected alternative:** patch the trait-stacking
  machinery to special-case `T = 1`. Rejected because it is a
  non-trivial engine change (touches the shared `trait` design-matrix
  builder used by every covariance-structure keyword) and is exactly
  the kind of scope-widening change this task's brief explicitly
  excludes ("do not write the article prose" / plumbing-only slice,
  later "do not touch other files" in the closure-artifact slice).
  **Confidence:** high on the diagnosis (reproduced independently
  three ways, two of them mine, one the coordinator's), open on
  whether a future PR should build the `T = 1` path.
- **Decision:** `Habitat.Density` as the second trait for Example 1,
  not a second continuous trait or a repeat of `logMass`.
  **Rationale:** gives a real, statable biological hypothesis (open-
  country species tend to be migratory) that the fitted phylogenetic
  correlation directly speaks to, rather than an arbitrary filler
  variable. **Rejected alternative:** re-use `logMass` as a second
  "trait" (rejected — colinear with its own role as a covariate, and
  biologically vacuous); a continuous second trait (rejected — would
  have required a mixed-family fit, adding complexity without adding
  clarity to the paper-alignment story).
- **Decision:** withhold the Example 2 phylogenetic correlation from
  the article text rather than report it with a caveat.
  **Rationale:** the design-doc campaign (§4 below) shows this specific
  quantity, at this specific data regime (one draw per species), rails
  toward |1| in a material fraction of simulated fits even with a
  positive-definite Hessian — a caveat next to a number that looks
  confident is a weaker signal than omitting the number.

## 4. Checks Run

```sh
# Live data fetch + schema validation (network available)
OPENBLAS_NUM_THREADS=1 Rscript --vanilla -e '
  source("dev/mizuno-vignette/fetch-mizuno-data.R")
  ex1 <- mizuno_load_ordinal(); ex2 <- mizuno_load_nominal()
  stopifnot(!is.null(ex1), !is.null(ex2))'
# -> ex1: 136 species, 136 tree tips, exact match.
# -> ex2: 173 species, 173 tree tips, exact match, 3 observed
#    Primary.Lifestyle levels.

# Both fits, long vs wide, logLik equivalence (interactive, ad hoc, not
# a formal test file -- this article does not add tests/testthat/ files)
OPENBLAS_NUM_THREADS=1 Rscript --vanilla -e '<see §2 for the two calls>'
# -> Example 1: logLik diff 1.02e-12; convergence 0; pd_hessian TRUE.
# -> Example 2: logLik diff 0; convergence 0; pd_hessian TRUE.

# pkgdown structural check
OPENBLAS_NUM_THREADS=1 Rscript --vanilla -e '
  devtools::load_all(quiet = TRUE); pkgdown::check_pkgdown()'
# -> "No problems found."

# Build just this article (network available)
OPENBLAS_NUM_THREADS=1 Rscript --vanilla -e '
  devtools::load_all(quiet = TRUE)
  pkgdown::build_article("articles/phylogenetic-categorical-pglmm",
    pkg = ".", lazy = FALSE, quiet = TRUE)'
# -> "Writing `articles/phylogenetic-categorical-pglmm.html`", no error.

# No-network smoke (the check specified by the task brief)
OPENBLAS_NUM_THREADS=1 \
  GLLVMTMB_CACHE_DIR=<fresh empty tmp dir> \
  http_proxy=http://127.0.0.1:1 https_proxy=http://127.0.0.1:1 \
  Rscript --vanilla -e '
    devtools::load_all(quiet = TRUE)
    pkgdown::build_article("articles/phylogenetic-categorical-pglmm",
      pkg = ".", lazy = FALSE, quiet = TRUE)'
```

**First attempt at the no-network smoke FAILED**, and that failure is
the useful outcome: `pkgdown::build_article()` aborted with
`Quitting from phylogenetic-categorical-pglmm.Rmd:281-287 [ex2-h2-plot]
... object 'ps2' not found`. The `ex2-h2-plot` `ggplot()` chunk was
missing its `eval = have_ex2` guard — every other data-dependent chunk
had it, this one did not — so with no network it tried to run anyway
and crashed instead of degrading. Fixed
(`eval = have_ex2` added to that one chunk header); re-ran the same
command and it built cleanly. Confirmed by text-extracting the
rendered HTML under the no-network condition: the "Data unavailable in
this build" note is present, no `Wall clock` / `H2(migration)` output
strings appear (only the un-executed source code text, since `echo`
stayed on and only `eval` was turned off), and the build produced no
error. This is exactly why the check was specified in the task brief
rather than trusted by inspection — it caught a real defect that a
code read did not.

**Deliberately not run**, and why:
- `devtools::check()` / full `R CMD check --as-cran` — this PR touches
  no `R/`, `src/`, `NAMESPACE`, or generated `Rd`; only new doc/dev
  files and two additive `_pkgdown.yml` lines. The narrower `pkgdown`
  checks above are the relevant surface. See §10/§DoD for the honest
  statement that item 1 (CI) has not yet reported green on this PR.
- `devtools::test()` — no `tests/testthat/` files added or touched.
- An MCMCglmm comparator for Example 2 (nominal/categorical) — its
  categorical family needs a from-scratch multi-response link setup
  distinct from the ordinal comparator above; building it correctly
  was judged out of this task's time budget, and the article says so
  plainly rather than approximating a number.
- Any multi-seed recovery campaign for either fitted model — both
  examples are single fits on the paper's own real (non-simulated)
  data; there is no "seed" to sweep, and no calibrated-coverage claim
  is made anywhere in the article (see §10).

## 5. Tests of the Tests

Not applicable — no `tests/testthat/` file was added or modified by
this PR. The nearest analogue is the no-network smoke above, which is
a manual (not `testthat`-harnessed) failure-before-fix demonstration:
confirmed failing (`object 'ps2' not found`) before the one-line
`eval` guard fix, confirmed passing after.

## 6. Consistency Audit

```sh
rg -n "gllvmTMB\(" vignettes/articles/phylogenetic-categorical-pglmm.Rmd
```
Verdict: every long-format call in the new article passes
`trait = "trait"` explicitly (both `fit1_long`/`fit2_long` calls); the
two `traits(...)` wide-format calls correctly omit `trait =` per the
Option A naming rule.

```sh
rg -n "PHY-0|FAM-20|PA[1-4]\b|register row|covered\b|partial\b" \
  vignettes/articles/phylogenetic-categorical-pglmm.Rmd
```
Verdict: no matches — no internal register code, register status word
(`covered`/`partial`/`admitted`), or task-lane identifier (`PA1..PA4`,
`FAM-20*`, `PHY-0*`) leaked into the reader-facing article, per the
project's standing "reader-facing surfaces carry no register codes"
rule.

```sh
rg -n "S_B|S_W" vignettes/articles/phylogenetic-categorical-pglmm.Rmd
```
Verdict: no matches (no legacy S/U notation).

## 7. Roadmap Tick

N/A — no `ROADMAP.md` row references this article or the Mizuno
alignment work by name.

## 7a. GitHub Issue Ledger

No issue was inspected, commented, closed, or created by this task.
The documentation-defect finding below (§"Documentation defect") is
recorded here and left for a maintainer decision rather than filed as
an issue, per explicit instruction for this closure slice.

## 8. What Did Not Go Smoothly

### The T=1 finding (the substantive result of the plumbing slice)

`gllvmTMB` **cannot fit the paper's own Example 1 shape** — a
genuinely univariate (`T = 1`) ordinal PGLMM, one categorical response
regressed on a covariate with a phylogenetic random effect — through
any route currently in the package. Verified three independent ways:

1. **Base R itself rejects the trait design matrix at `T = 1`.**
   Every `gllvmTMB` covariance-structure keyword (`phylo_latent()`,
   `phylo_indep()`, `phylo_dep()`, ...) builds its fixed-effect design
   matrix through `stats::model.matrix(parsed$fixed, mf)`
   (`R/fit-multi.R:2406`), and a `trait` factor with exactly one level
   makes that call fail structurally, independent of `gllvmTMB` code:
   `model.matrix(~0 + factor("a") + logMass)` errors
   `"contrasts can be applied only to factors with 2 or more levels"`
   in bare base R, no package involved. Reproduced through
   `gllvmTMB(value ~ 0 + trait + logMass + phylo_indep(0 + trait |
   species, tree = tree), ..., family = ordinal_probit())` on the real
   accipitridae data: identical error, same call stack
   (`gllvmTMB_multi_fit -> model.matrix.default -> contrasts<-`). A
   natural workaround — declaring a second, empty `"dummy"` trait
   level so `nlevels(trait) == 2` — clears that error but fails
   deeper, `"missing value where TRUE/FALSE needed"`, because the
   multi-trait engine also assumes every declared trait level carries
   real rows.
2. **No test file in the repository exercises `ordinal_probit()` at
   genuine `T = 1`.** `test-ordinal-probit.R` and
   `test-matrix-ordinal-phylo.R` both use `T >= 2` trait fixtures
   throughout; a `grep` for a single-trait ordinal-phylo test found
   none.
3. **The legacy `phylo_vcv` single-response route fails identically.**
   The coordinator independently verified (outside this branch's
   fitting sessions) that the older `phylo_vcv =` argument, used
   without any covariance-structure keyword, errors `"Column trait not
   found in data"` on the same real data — the same underlying gap
   from a different entry point, not a route around it.

**The maintainer's ruling (relayed by the coordinator in-session):**
this is a **documented scope boundary**, AGENTS.md line 87 —
"Single-response models (no covstruct keyword) belong in `glmmTMB`" —
not a `gllvmTMB` bug to fix in this PR. Example 1 was therefore lifted
to a genuine bivariate ordinal PGLMM (§2 above) rather than patched
around the limitation.

### 🔴 Documentation defect, recorded so it survives this PR

`docs/design/123-multinomial-structured-surface.md`'s "Paper alignment"
table presents two rows as if the univariate case were exercised:

- Row for paper eq 1-5 ("Univariate continuous PMM"), status
  `covered`, evidenced by `test-phylo-hadfield.R` — but that test
  file's own fixture (`make_phylo_sim(n_sp = 50, n_traits = 4, ...)`)
  defaults to `n_traits = 4`, never `1`.
- Row for paper eq 27-32 ("Ordinal PGLMM with phylogenetic/relatedness
  source"), status "admitted, recovery skip-honest", evidenced by
  `test-matrix-ordinal-phylo.R` — that file's own fixture
  (`make_ordinal_phylo_fixture(n_traits = 4, ...)`) also defaults to
  `T = 4`, never `1`.

Neither row's cited evidence actually demonstrates the `T = 1`
(genuinely univariate, no `trait` stacking) case the paper's own
Example 1 needs, and — per the finding above — the underlying
mechanism these tests exercise (the shared `trait`-factor design
matrix) provably **cannot** run at `T = 1` today. **This claim is
unsupported as currently worded** and needs a maintainer decision:
either annotate Design 123 to narrow the claim to `T >= 2`, or treat
it as a tracked gap. Per explicit instruction for this closure slice,
**this task does not edit Design 123 and does not file a GitHub
issue** — it only records the defect here so it is not lost.

### Formula-equivalence subtlety, worth flagging for future article authors

The wide `traits(...) ~ 1 + logMass + ...` shorthand expands a bare
covariate (`logMass`) to a **per-trait slope** (`trait:logMass`), not
one shared slope — this had to be discovered empirically (long/wide
logLik disagreed by 6.3 nats until the long-format formula was
corrected to `0 + trait + trait:logMass` instead of `0 + trait +
logMass`). This is documented explicitly in the article's own prose
(the paragraph immediately after the Example 1 fit chunk) so a reader
translating between the two forms does not hit the same silent
mismatch.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

- **Pat (product/usability):** the T=1 finding is exactly the kind of
  result Pat's lens rewards reporting plainly rather than working
  around quietly — "gllvmTMB cannot fit the paper's own flagship
  univariate example" is a real usability boundary a user needs to
  know before reaching for this package on a single-trait phylogenetic
  question, and the article now says so as a scope statement rather
  than burying it.
- **Rose (after-task/handoff QA):** the no-network smoke is a direct
  Rose-style diligent-student check — it caught a defect (`ex2-h2-plot`
  missing its `eval` guard) that a straight code read of the same
  chunk would very plausibly have missed, since the chunk "looked"
  guarded by the surrounding narrative even though its own header
  wasn't. Watch for next time: **every** `ggplot()`/plotting chunk
  needs its own explicit `eval =` guard when it references
  data-dependent objects — narrative proximity to a guarded chunk is
  not the same as the chunk itself being guarded.
- **Grace (data/statistics honesty):** the deliberate withholding of
  the Example 2 phylogenetic correlation, and the explicit
  "qualitative, not equivalent models" framing on the MCMCglmm
  comparator, are both Grace-shaped calls — report a number only when
  its own evidence supports the claim being made about it, not merely
  when the fit converged.
- **Fisher (statistical/inferential rigor):** flagged (via this
  report, not a live review) that neither example is a recovery
  campaign — both are single fits on real data with no known ground
  truth, so no coverage or bias claim is or should be attached to
  either H^2 or correlation number in the article.

## 10. Known Limitations And Next Actions

**Definition-of-Done items met / not met** (AGENTS.md six-item list, by
number as this repo generally orders them):

1. **CI green** — **NOT MET as of this report.** PR #1112 was opened
   by the coordinator; this report does not have visibility into
   whether GitHub Actions has reported a result yet. Stated honestly
   rather than assumed.
2. **Design-doc / register consistency** — **partially met.** The
   article reuses (does not re-derive) the alignment table from Design
   123; the documentation defect discovered *in* Design 123 itself
   (§8 above) is recorded, not fixed, per this closure slice's explicit
   instruction not to edit that file.
3. **No stale register codes on reader-facing surfaces** — **met**,
   verified by the `rg` scan in §6.
4. **Both long- and wide-format calls shown** — **met** for both
   examples, verified logLik-identical.
5. **After-task report filed** — **met**, this file.
6. **No data redistributed into the repo** — **met**, verified by `git
   status --porcelain` showing zero data files staged across both
   commits on this branch; cache lives entirely under
   `tools::R_user_dir("gllvmTMB", "cache")`, outside the git tree.
7. **Honest limitations statement** — **met**: the article's own "What
   this article does *not* claim" section states no calibrated
   interval, the multivariate-only scope boundary, the withheld
   Example 2 correlation, single-fit-not-a-campaign status, and no
   ancestral-state reconstruction, in plain language with no register
   codes.
8. **check-log.md entry** — **met**, this closure slice's second file.

**Honest framing of what the article's claims rest on:** both examples
are single point-estimate fits on the paper's own real datasets, not a
multi-seed recovery campaign against known simulation truth. The H^2
and correlation numbers describe these two specific fits; they carry
no coverage guarantee and should not be read as validating
`ordinal_probit()`/`multinomial()` phylogenetic recovery in general —
that evidence lives in `docs/design/123-multinomial-structured-surface.md`'s
own campaigns, cited but not repeated here.

**Next actions (not started, not claimed):**
- Maintainer decision on the Design 123 documentation defect (§8):
  narrow the two rows' claimed evidence, or open a tracked gap.
- Whether to build a genuine `T = 1` single-response phylogenetic path
  through `gllvmTMB`'s covariance-structure keywords, given the
  demonstrated demand (this paper's own flagship example), or to
  reaffirm the `glmmTMB`-boundary ruling in the design docs so future
  sessions do not re-discover the same gap from scratch.
- An MCMCglmm categorical-family comparator for Example 2, if a future
  session has budget to build one correctly.
- Confirm PR #1112's CI result once available and update this report's
  §DoD item 1 line if a follow-up commit is needed.
