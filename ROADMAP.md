# gllvmTMB Roadmap

*Last refreshed: 2026-05-14.*

This roadmap is the shared map for the maintainer, the Claude
Code and Codex teams, contributors, and prospective users. It
records where the package is on the path to its first CRAN
release, what is stable today, what is in flight, and what is
planned. It is refreshed as PRs merge -- every after-task report
ticks the corresponding row (see "How this roadmap is maintained"
at the bottom).

Repo files remain canonical:
[`docs/dev-log/decisions.md`](https://github.com/itchyshin/gllvmTMB/blob/main/docs/dev-log/decisions.md)
for ratified scope decisions,
[`docs/dev-log/check-log.md`](https://github.com/itchyshin/gllvmTMB/blob/main/docs/dev-log/check-log.md)
for Kaizen-style numbered lessons, and the
[after-task report index](https://github.com/itchyshin/gllvmTMB/tree/main/docs/dev-log/after-task)
for every closed task. This page synthesises status from
those sources.

---

## Should I use this package today?

| State | When | Recommendation |
|---|---|---|
| 🔴 Not yet | Pre-Phase 1 close | Don't adopt for a publication-quality fit. The public surface and reader path are still stabilising; the API may shift in small ways before Phase 1 closes. |
| 🟡 Try with caution | Phase 1 closed, pre-Phase 5 | Try on small problems; report bugs; expect minor API tweaks before CRAN. The engine itself is stable. |
| 🟢 Adopt freely | Phase 5+ on CRAN | Package is on CRAN, externally validated, and stable for publication-quality fits. |

**Current state**: 🔴 **Not yet** -- Phase 1 (the reader path)
is in progress. Track this row to know when 🟡 or 🟢 fires.

The
[Get Started vignette](https://itchyshin.github.io/gllvmTMB/articles/gllvmTMB.html)
and the
[Choose-your-model decision tree](https://itchyshin.github.io/gllvmTMB/articles/choose-your-model.html)
are the best entry points for kicking the tyres while we close
Phase 1.

---

## Phases at a glance

Status legend: ✅ done · 🟢 in progress · ⚪ planned · 🔵
deferred. Progress bars are 8 characters wide; the fraction is
items completed within that phase.

| Phase | Title | Status | Progress | Notes |
|---|---|---|---|---|
| Notation upgrade | Math notation S → Ψ | ✅ Done | `████████` 6/6 | PRs #86 – #91 |
| Phase 1a | Drift cleanup | ✅ Done | `████████` 5/5 | Batches A ✅ · B ✅ · C ✅ · D ✅ · E ✅ |
| Phase 1b | Engine + extractor fixes | ⚪ Planned | `░░░░░░░░` 0/5 | Correlation fix + identifiability + tests |
| Phase 1b validation | Profile-likelihood CI validation | ⚪ Planned | `░░░░░░░░` 0/1 | Coverage study; exit ≥ 94 % per family |
| **Phase 1c-slope** | **Random slopes (NEW pre-CRAN)** | ⚪ Planned | `░░░░░░░░` 0/6 | Engine generalisation + extractors + recovery + plots + article |
| Phase 1c | Article ports + new Concepts pedagogy | ⚪ Planned | `░░░░░░░░` 0/13 | 9 ports + 4 new pedagogy articles |
| Phase 1c-viz | Visualization layer completion | ⚪ Planned | `░░░░░░░░` 0/7 | Static + interactive plot dispatcher (incl. random-slope plots) |
| Phase 1d | Navbar restructure | ⚪ Planned | `░░░░░░░░` 0/1 | `_pkgdown.yml` 3-tier taxonomy |
| Phase 1e | Final reframe sweep | ⚪ Planned | `░░░░░░░░` 0/1 | Cross-article consistency + biology-first reframes |
| Phase 1f | Choose-your-model rewrite (Phase 1 close) | ⚪ Planned | `░░░░░░░░` 0/1 | Phase 1 close gate |
| Phase 2 | Public surface audit | ⚪ Planned | `░░░░░░░░` 0/8 | Keep / internalise / delete each export |
| Phase 3 | Data-shape contract | 🟢 ~ 90 % done | `█████████░` 9/10 | Byte-identical long / wide fits |
| Phase 4 | Feedback time (CI / fast lane) | 🔵 Deferred | — | Recovery-test gating, activated later |
| Phase 5 | CRAN readiness (mechanics) | ⚪ Planned | `░░░░░░░░` 0/8 | DESCRIPTION + WORDLIST + cran-comments |
| Phase 5.5 | External validation sprint | ⚪ Planned | `░░░░░░░░` 0/8 | Pilot users + sim grid + reviewers, 6 – 12 weeks |
| Phase 6 | Post-CRAN extensions | 🔵 Deferred | — | After CRAN; methods paper + new features |

---

## ✅ Math notation upgrade (S → Ψ) -- `████████` 6/6 done

**Closed 2026-05-14.** The unique-variance diagonal in all
user-facing math notation -- roxygen, vignettes, articles,
README, NEWS, design docs -- now reads as the Greek letter
**Ψ** (bold capital for the matrix, italic lowercase `ψ` for
per-trait scalar entries). Engine algebra is unchanged
(`Sigma = Lambda Lambda^T + diag(psi)` in code-style). The
legacy "two-U" task label was further retired on 2026-05-14
(see Phase 1a close); function and file names no longer use
"U" or "PIC".

This was the largest pre-CRAN documentation refactor. Across
the entire R/ source tree, articles, design docs, tests, and
generated Rd files, every reference to the previous `S` / `s`
math notation was rewritten to the new Greek-letter convention.

### Sub-batches

- ✅ NS-1 -- Rule files + decisions + check-log (PR #86)
- ✅ NS-2 -- README + design docs (PR #87)
- ✅ NS-3a -- API rename in `simulate_site_trait` + callers
  (PR #88)
- ✅ NS-3b -- R/ roxygen math-prose sweep across 8 R/ files
  (PR #89)
- ✅ NS-4 -- Article math prose part 1, 6 articles (PR #90)
- ✅ NS-5 -- Article math prose part 2 + NEWS entry (PR #91)

### Cross-refs

- [`decisions.md`, 2026-05-14 notation-reversal entry](https://github.com/itchyshin/gllvmTMB/blob/main/docs/dev-log/decisions.md)
- [`check-log.md` Kaizen points 8, 9, 10](https://github.com/itchyshin/gllvmTMB/blob/main/docs/dev-log/check-log.md)

---

## ✅ Phase 1a -- Drift cleanup -- `████████` 5/5 batches done

**Closed 2026-05-14.** Closed out the small text-and-roxygen
drift items that accumulated between the 2026-05-10 reset and
today -- in-prep equation citations, stale paper-internal
jargon ("M1/M2"), notation-switch stragglers, and the legacy
"two-U" / PIC task-label retention.

Phase 1a was split into five PR batches. Batches A, B, D, and
E were the four drift-cleanup batches identified in the
[2026-05-13 post-overnight drift-scan audit](https://github.com/itchyshin/gllvmTMB/blob/main/docs/dev-log/audits/2026-05-13-post-overnight-drift-scan.md);
Batch C was the 2026-05-13 evening Ψ phase-fix sweep that
preceded the notation reversal. Batch E was repurposed to
close out the 2026-05-14 PIC / "two-U" retirement decision.

### Sub-batches

- ✅ **Batch A** -- audit-doc edits + first NS stragglers
  ([PR #92](https://github.com/itchyshin/gllvmTMB/pull/92),
  merged 2026-05-14). Triggered the comprehensive S → Ψ
  re-scan that exposed Batch A's verification regex bug (see
  Kaizen point 10).
- ✅ **Batch B** -- 14 in-prep `Eq. N` citations dropped +
  24+ NS-3b/4/5 notation stragglers swept across 11 R/ files
  and 4 vignettes
  ([PR #94](https://github.com/itchyshin/gllvmTMB/pull/94),
  merged 2026-05-14).
- ✅ **Batch C** -- Ψ phase-fix sweep + Phase D/K label drop
  ([PR #82](https://github.com/itchyshin/gllvmTMB/pull/82),
  merged 2026-05-13).
- ✅ **Batch D** -- `gllvmTMB_wide()` matrix-in demonstrations
  dropped from `morphometrics.Rmd` + `response-families.Rmd`
  in favour of the canonical `traits(...)` formula path
  ([PR #95](https://github.com/itchyshin/gllvmTMB/pull/95),
  merged 2026-05-14).
- ✅ **Batch E** -- (revised scope) `\mathbf{U}` →
  `\mathbf{Z}` in `behavioural-syndromes.Rmd` math (LHS score
  matrix, NOT the unique-variance matrix Ψ that an earlier
  audit-doc framing wrongly assumed); PLUS the
  2026-05-14 PIC / "two-U" retirement: deletion of
  `R/extract-two-U-via-PIC.R` and
  `R/extract-two-U-cross-check.R`, their tests, the four
  PIC/U exports (`compare_PIC_vs_joint`,
  `compare_dep_vs_two_U`, `compare_indep_vs_two_U`,
  `extract_two_U_via_PIC`), prose scrub across R/ + design
  docs + NEWS, and README footer link fix. **This PR closes
  Phase 1a.** See
  [Phase 1a close after-task](https://github.com/itchyshin/gllvmTMB/blob/main/docs/dev-log/after-task/2026-05-14-phase-1a-close.md).

### Phase 1a close gate

| Gate | Status | Verified by |
|---|---|---|
| All 5 batches merged | ✅ 5 / 5 | A ✅, B ✅, C ✅, D ✅, E ✅ |
| `pkgdown::check_pkgdown()` clean on Phase 1a close | ✅ | Phase 1a close PR (this) |
| 3-OS R-CMD-check green on each batch | ✅ | last verified PR #95 (Batch D) |
| PIC / "two-U" exports retired + 4 NAMESPACE entries removed | ✅ | Phase 1a close PR (this) |
| README footer link to design doc fixed (broken → absolute URL) | ✅ | Phase 1a close PR (this) |

### Cross-refs

- [Audit: 2026-05-13 post-overnight drift scan](https://github.com/itchyshin/gllvmTMB/blob/main/docs/dev-log/audits/2026-05-13-post-overnight-drift-scan.md)
- [After-task: Batch A](https://github.com/itchyshin/gllvmTMB/blob/main/docs/dev-log/after-task/2026-05-14-phase-1a-batch-a.md)
- [Check-log Kaizen point 10 (verification-regex anti-pattern)](https://github.com/itchyshin/gllvmTMB/blob/main/docs/dev-log/check-log.md)

---

## ⚪ Phase 1b -- Engine + extractor fixes -- `░░░░░░░░` 0/5 items

**Goal**: close two correctness gaps in the multivariate
extractor / correlation surface and add the identifiability
and inference diagnostics that the package will need to make
honest claims at CRAN time and for the manuscript.

### Work items

- ⚪ **P1 -- `extract_correlations()` `link_residual = "auto"`**:
  `R/extract-correlations.R:236` currently hardcodes
  `link_residual = "none"`, so non-Gaussian correlations omit
  the per-family link-residual variance. The plumbing for 15
  families and links exists in
  `R/extract-sigma.R:99-280` (`link_residual_per_trait()`)
  but the extractor doesn't use it. Switch the default and
  add tests across the 15 families.
- ⚪ **`check_auto_residual()` safeguard**: warns when
  ordinal-probit is in the formula (its latent residual is
  already standardised by construction) and errors when a
  trait mixes incompatible families. About 80 LOC + a test.
- ⚪ **`check_identifiability(fit, sim_reps = 100)` diagnostic**:
  simulate from the fitted model, refit each replica, apply
  Procrustes alignment to loadings, extract Hessian
  eigenvalues, flag rank deficiency and factor-loading
  collapse. Returns a recovery-rate / SE / alignment-quality
  matrix. About 200 LOC + a new `test-identifiability-check.R`
  with a mixed-rank fixture.
- ⚪ **Mixed-family extractor tests**: `extract_Sigma()` and
  `extract_correlations()` on
  `family = list(gaussian(), binomial(), poisson())` fits.
  Includes a fixture for the 15-family link-residual matrix.
- ⚪ **Expanded profile-CI edge-case tests**: ordinal-probit
  fixed σ² = 1 (pinned-parameter profile is a no-op or warn);
  boundary-pinned variance components; mis-specified models;
  NB2 non-quadratic profile (Wald should under-cover);
  rank-deficient Λ (`d = 2` when truth is `d = 1`);
  bootstrap-vs-Wald-vs-profile systematic comparison;
  transform-boundary pinning (ρ → ± 1).

### Phase 1b close gate

| Gate | Status | Verified by |
|---|---|---|
| All 5 items shipped across 4 – 5 PRs | ⚪ Pending | — |
| Mixed-family tests pass on the 15-family fixture | ⚪ Pending | — |
| New diagnostics return sensible output on a known-bad fit | ⚪ Pending | — |
| 3-OS R-CMD-check green | ⚪ Pending | — |

### Cross-refs

- [Audit: 2026-05-13 post-overnight drift scan, items 9 – 10](https://github.com/itchyshin/gllvmTMB/blob/main/docs/dev-log/audits/2026-05-13-post-overnight-drift-scan.md)
- [`decisions.md` 2026-05-14 D4 ratification (`link_residual = "auto"`)](https://github.com/itchyshin/gllvmTMB/blob/main/docs/dev-log/decisions.md)

---

## ⚪ Phase 1b validation -- Profile-likelihood CI validation -- `░░░░░░░░` 0/1 milestone PR

**Goal**: produce the validation evidence that gllvmTMB's
three-method confidence interval API (`profile` / `wald` /
`bootstrap`) actually delivers the coverage it claims, on the
families and parameter types the package supports. This is the
inference-credibility gate before article ports start in
Phase 1c.

### Deliverables (bundled into one milestone PR)

- ⚪ **Jason pre-1b-validation literature scan** (~30 minutes,
  filed in
  `docs/dev-log/audits/2026-05-XX-pre-phase-1b-validation-scan.md`).
  Checks for new profile-likelihood-related work since the
  2026-05-10 rebuild.
- ⚪ **Empirical coverage study**: simulate from known DGPs
  (Gaussian, NB2, ordinal-probit; 50 replicates per family).
  Fit each replicate; profile every parameter; count fraction
  of CIs that contain truth. Output is a coverage-rate matrix
  as an `.Rds` cached artefact plus a summary table in
  `docs/dev-log/`. **Include galamm as a Wald-only reference
  comparator** on a shared fixture.
- ⚪ **`confint_inspect(fit, parameter)` function**: returns a
  tidy `data.frame` (parameter grid, deviance,
  excess-over-threshold) plus a ggplot showing profile shape +
  MLE + CI bounds for visual verification. About 100 LOC plus
  tests across the three methods.
- ⚪ **`troubleshooting-profile.Rmd` Concepts article**: about
  800 – 1000 words. Four failure-mode cases (profile didn't
  converge; CI bound at ± Inf; profile flat at MLE; profile
  and Wald disagree sharply). Cross-linked from
  `simulation-verification`, `profile-likelihood-ci`, and the
  relevant `extract_*()` extractor roxygen.

### Phase 1b validation close gate

| Gate | Status | Verified by |
|---|---|---|
| Coverage study shows ≥ 94 % empirical coverage per family | ⚪ Pending | — |
| `confint_inspect()` passes on all three methods | ⚪ Pending | — |
| `troubleshooting-profile.Rmd` article merged | ⚪ Pending | — |
| Rose pre-publish audit sign-off | ⚪ Pending | — |

### Cross-refs

- [`decisions.md` 2026-05-14 strategic-plan revision (Phase 1b validation milestone)](https://github.com/itchyshin/gllvmTMB/blob/main/docs/dev-log/decisions.md)
- [After-task: 2026-05-14 strategic plan revision](https://github.com/itchyshin/gllvmTMB/blob/main/docs/dev-log/after-task/2026-05-14-strategic-plan-revision.md)

---

## ⚪ Phase 1c-slope -- Random slopes (NEW pre-CRAN) -- `░░░░░░░░` 0/6 PRs

**Goal**: implement Appendix B of the methods paper (Nakagawa
et al. *in prep*) -- random slopes for reaction-norm / plasticity
modelling -- pre-CRAN. The legacy gllvmTMB package had this as a
779-line article that was engine-blocked on hardcoded `n_traits`
sizing in `R/fit-multi.R`; Phase 1c-slope unblocks it.

Maintainer's framing 2026-05-14: *"this has to be pre-CRAN --
actually this is important one and we should put more ideas to
it -- opinions on this random slopes because it's really
interesting. You can get different correlations, all sorts of
things. The visualization there is an important one as well. So
we best do the random slope stuff before visualization because
visualization tailored to this needs to be developed."*

### Three correlations, three biological questions (Darwin's framing)

The augmented between-individual covariance partitions into
three sub-matrices, each answering a distinct biological
question:

- $\boldsymbol\Sigma_B^{(u)}$ -- **personality syndrome**
  (intercept-intercept correlations). "Do bold individuals also
  tend to be exploratory?" Sih et al. (2004) workhorse.
- $\boldsymbol\Sigma_B^{(b)}$ -- **plasticity syndrome**
  (slope-slope correlations). "Do reaction norms coordinate?"
  Dingemanse & Dochtermann (2013).
- $\boldsymbol\Sigma_B^{(u,b)}$ -- **personality-plasticity
  association** (intercept-slope correlations). The most
  misread sub-matrix: collapsing a tilted 2D distribution to
  a single number loses rank-reversal information.

### Six PRs

- ⚪ **Engine generalisation** (Boole + Gauss). Four `n_traits`
  hardcoded sites in `R/fit-multi.R` (lines 901, 1196,
  1198 – 1199 and W-block mirror at 1200 – 1203) generalise to
  `n_lhs_cols = T * (1 + Q)` where Q = number of random-slope
  covariates. C++ side: `src/gllvmTMB.cpp` `Lambda_B` / `s_B`
  packing comments + new `Z_lhs` `DATA_MATRIX` for
  linear-predictor assembly. Includes Fisher's joint-block
  sign-pinning (combined intercept + slope block, not
  block-by-block) and the slope-covariate centering guard
  (`cli::cli_warn` if `|mean(x) / sd(x)| > 0.1`, referencing
  Eq. 47).
- ⚪ **Extractor extensions**. `extract_Sigma()` with `block =
  c("u", "b", "u,b", "aug")` argument; `extract_repeatability()`
  with `temp = focal_value` and `marginalised = TRUE/FALSE`
  (Eqs. 50 and 52); `extract_communality()` with `temp =
  focal_value` (Eq. 56).
- ⚪ **Recovery test** with five DGPs in
  `tests/testthat/test-random-slope-recovery.R`:
    1. RS-1 aligned $\boldsymbol\Lambda_u = \boldsymbol\Lambda_b$
       (Eq. 41 running example);
    2. RS-2 two-axis ($d_B = 2$, $T = 5$);
    3. RS-3 **boundary** $\text{Cov}(u, b) = 0$ (CI should
       contain 0 in ≥ 92 % of reps);
    4. RS-4 **degenerate** $\text{Var}(b) = 0$ (must NOT
       silently collapse; require boundary-flag or
       `pdHess = FALSE`);
    5. RS-5 mixed-attribute sex covariate (Appendix B.2).
    
   `skip_on_cran()` + `skip_on_ci()` gated; cost ~5 – 15 min
   serial on Tier-1 fixtures.
- ⚪ **`check_identifiability()` augmentation**. Add three new
  flag classes: `$flags$intercept_slope_decoupled` (spurious
  personality-plasticity association detector),
  `$flags$slope_boundary` (RS-4 detector),
  `$flags$temp_within_var_low` (design-limited slope variance).
- ⚪ **Random-slope-tailored plot types in the dispatcher**
  (Darwin priorities): add `type = "reaction_norm"`
  (per-individual spaghetti plot, faceted by trait), `type =
  "intercept_slope_ellipse"` (BLUP scatter with 95 % bivariate
  ellipse, per trait), `type = "repeatability_curve"`
  ($R_t(\text{temp})$ across the covariate range, Eq. 50).
  Update existing `type = "correlation"` to accept `block =
  c("u", "b")` for personality-syndrome and plasticity-syndrome
  separately. The **reaction-norm spaghetti plot** is the
  load-bearing visual -- without it, readers see only matrices
  and lose the per-individual rank-reversal intuition.
- ⚪ **Article port + biological worked example**. Port
  `random-slopes-personality-plasticity.Rmd` from
  gllvmTMB-legacy (779 lines) updated for current API and
  Ψ / ψ notation. Add Darwin's missing worked-example
  question: *"Does temperature variability erode the
  boldness-activity syndrome?"* using
  $\boldsymbol\Sigma_B(x)$ from Eq. 54.

### API decision (Boole-locked)

**Extend existing `latent()` / `unique()` keywords** to accept
augmented LHS:

```r
latent(0 + trait + (0 + trait):temp | ID, d = d_B) +
unique(0 + trait + (0 + trait):temp | ID)
```

Byte-for-byte the paper's Appendix B.1 syntax. **No new
keywords. 3 × 5 grid untouched.** Slopes are a property of the
LHS column count Q, not a new mode dimension. `phylo_latent` /
`spatial_latent` augmented-LHS flagged as
`lifecycle::experimental` post-CRAN.

### Phase 1c-slope close gate

| Gate | Status | Verified by |
|---|---|---|
| Engine generalisation merged; intercept-only fits hash-identical | ⚪ Pending | — |
| Extractor `block =` argument round-trips on RS-1 fixture | ⚪ Pending | — |
| Recovery test passes all 5 DGPs | ⚪ Pending | — |
| `check_identifiability()` 3 new flag classes return sensible output | ⚪ Pending | — |
| 3 new plot types render + `vdiffr` snapshot tests pass | ⚪ Pending | — |
| Article merged; Eq. 54 worked example fits + plots | ⚪ Pending | — |

### Cross-refs

- [`decisions.md` 2026-05-14 Phase 1c-slope ratification](https://github.com/itchyshin/gllvmTMB/blob/main/docs/dev-log/decisions.md)
- [`decisions.md` 2026-05-14 PIC / "two-U" retirement (prerequisite cleanup)](https://github.com/itchyshin/gllvmTMB/blob/main/docs/dev-log/decisions.md)
- [Phase 1a close after-task (Darwin / Fisher / Boole consult briefs captured)](https://github.com/itchyshin/gllvmTMB/blob/main/docs/dev-log/after-task/2026-05-14-phase-1a-close.md)
- Paper: Nakagawa et al. *in prep*, **Appendix B** (Eqs. 41 – 69)

---

## ⚪ Phase 1c -- Article ports + new Concepts pedagogy -- `░░░░░░░░` 0/13 articles

**Goal**: port the surviving legacy articles to the current
API + 2026-05-14 vocabulary, and write the three to four new
Concepts-tier pedagogy articles that the persona consults
identified as gaps. After Phase 1c the article roster is
complete and the navbar can be restructured (Phase 1d).

Article taxonomy (ratified 2026-05-14 as D2): **Concepts**
(decision / orientation), **Worked examples** (one scientific
domain per article), **Methods + validation** (cross-check /
simulation-recovery / methodology).

### Concepts tier (4 articles)

- ⚪ `data-shape-flowchart.Rmd` -- NEW pedagogy (Pat). 1-page
  visual decision tree mapping data shapes to articles.
- ⚪ `gllvm-vocabulary.Rmd` -- NEW pedagogy (Pat). Plain-English
  glossary; plain + math definitions for every jargon term.
  Cross-linked from every Concepts article on first use.
- ⚪ `lambda-constraint.Rmd` -- PORT (D1 resolved 2026-05-14
  as standalone Concepts article; prerequisite of
  `psychometrics-irt`).
- ⚪ `simulation-verification.Rmd` -- NEW pedagogy (Curie +
  Fisher). 5 sections including Fisher's profile-curve-anatomy
  bridge to `profile-likelihood-ci`.

### Worked examples tier (6 ports)

- ⚪ `mixed-response.Rmd` -- depends on Phase 1b P1 fix.
- ⚪ `stacked-trait-gllvm.Rmd` -- foundational; no deps.
- ⚪ `phylo-spatial-meta-analysis.Rmd` -- closes one spatial
  example gap.
- ⚪ `spde-vs-glmmTMB.Rmd` -- closes the other spatial example
  gap.
- ⚪ `corvidae-two-stage.Rmd` -- verify `meta_known_V()`.
- ⚪ `psychometrics-irt.Rmd` -- cross-domain validation.

### Methods + validation tier (3 ports, land last)

- ⚪ `profile-likelihood-ci.Rmd` -- Methods + validation.
- ⚪ `cross-package-validation.Rmd` -- glmmTMB, gllvm, galamm,
  sdmTMB, MCMCglmm, Hmsc. `brms` dropped (Fisher's revision);
  `lavaan` deferred post-CRAN.
- ⚪ `simulation-recovery.Rmd` -- lands last; depends on all
  others.

### Phase 1c close gate

| Gate | Status | Verified by |
|---|---|---|
| All 13 articles merged (4 new + 9 ports) | ⚪ Pending | — |
| Each article renders without warnings | ⚪ Pending | — |
| Rose pre-publish audit on every article PR | ⚪ Pending | — |
| Pat reading-path audit on Concepts tier | ⚪ Pending | — |
| Darwin biology-question audit on Worked examples tier | ⚪ Pending | — |

### Cross-refs

- [`decisions.md` 2026-05-14 D1 (lambda-constraint standalone)](https://github.com/itchyshin/gllvmTMB/blob/main/docs/dev-log/decisions.md)
- [`decisions.md` 2026-05-14 D2 (Concepts / Worked / Methods + validation taxonomy)](https://github.com/itchyshin/gllvmTMB/blob/main/docs/dev-log/decisions.md)
- [`decisions.md` 2026-05-14 D6 (data-shape-flowchart + gllvm-vocabulary)](https://github.com/itchyshin/gllvmTMB/blob/main/docs/dev-log/decisions.md)

---

## ⚪ Phase 1c-viz -- Visualization layer completion -- `░░░░░░░░` 0/7 items

**Goal**: complete the `plot.gllvmTMB_multi(x, type = ...)`
dispatcher and ship publication-ready figures (static + optional
interactive) for the five Tier-1 worked examples. The
dispatcher already exists in `R/plot-gllvmTMB.R` with five
plot types (`correlation`, `loadings`, `integration`,
`variance`, `ordination`). Phase 1c-viz is "complete + polish",
not greenfield.

Runs alongside Phase 1c article ports. Each article-port PR
may use existing plot helpers, or add the helper it needs in
the same PR; dedicated Phase 1c-viz PRs cover the
dimension-aware ordination, the interactive option, the
polish work, snapshot tests, and the new visualisation article.

### Work items (about 3 – 4 PRs)

- ⚪ **Extend dispatcher with 3 missing static plot types**:
  `communality` (per-trait shared / unique stacked bar),
  `phylo_signal` (H² + C²_non + ψ² stacked bar per trait,
  ordered by H², with a thin error overlay on H²),
  `residual_split` (per-trait latent / unique / residual
  stacked bar from `extract_residual_split()`).
- ⚪ **Add `repeatability_forest`** plot type -- ICC is the
  headline behavioural-syndrome / functional-biogeography
  number; a forest plot with point + CI per trait makes it
  legible. Sourced from `extract_repeatability()`.
- ⚪ **Dimension-aware `ordination`**: detect the fit's
  latent rank `d` and dispatch -- `d = 1` strip plot along
  LV1 with trait labels as rug ticks; `d = 2` standard biplot
  (current behaviour); `d = 3` pair-grid of three 2D panels
  (LV1-LV2, LV1-LV3, LV2-LV3) composed via `patchwork`;
  `d > 3` defaults to top-3 pair-grid plus an
  `axes = c(i, j, k)` override argument.
- ⚪ **First-class interactive option** via `plotly`:
  `plot(fit, type = "ordination", interactive = TRUE)` returns
  a `plotly` 3-D scatter object. `plotly` stays in `Suggests`
  with `requireNamespace("plotly", quietly = TRUE)` guards.
  Extensible to other plot types in later passes.
- ⚪ **Polish across all helpers**: rotation-disclaimer
  captions enforced everywhere (Darwin: rotational ambiguity
  must never let LV1/LV2 be auto-labelled with biological
  names); sign-pinning so loadings don't flip across re-fits;
  error-bar overlays where missing; shared / unique / total
  guard annotated on correlation plots when the fit lacks
  `+ unique()` (Pat's pet peeve: users misread inflated
  off-diagonal correlations without this).
- ⚪ **`vdiffr` snapshot tests** per static plot type.
  Interactive plots skip snapshot testing (too brittle).
- ⚪ **NEW Concepts article `visualizing-gllvmTMB.Rmd`**:
  shows all 8+ plot types side-by-side with rotation caveats
  and a short interactive `plotly` demo. Cross-linked from
  every Worked example.

### Phase 1c-viz close gate

| Gate | Status | Verified by |
|---|---|---|
| Dispatcher exposes 8+ plot types (5 existing + 3 new + repeatability_forest) | ⚪ Pending | — |
| `ordination` dispatches correctly for `d = 1, 2, 3, >3` | ⚪ Pending | — |
| Interactive `plot(..., interactive = TRUE)` round-trips on a Tier-1 fixture | ⚪ Pending | — |
| `vdiffr` snapshot tests pass | ⚪ Pending | — |
| `visualizing-gllvmTMB.Rmd` article merged | ⚪ Pending | — |

### Cross-refs

- [`R/plot-gllvmTMB.R` (existing dispatcher)](https://github.com/itchyshin/gllvmTMB/blob/main/R/plot-gllvmTMB.R)
- [`decisions.md` 2026-05-14 Phase 1c-viz scope (added evening 2026-05-14 after Pat / Emmy / Darwin persona consult)](https://github.com/itchyshin/gllvmTMB/blob/main/docs/dev-log/decisions.md)
- [After-task: 2026-05-14 roadmap refresh (persona-consult raw responses)](https://github.com/itchyshin/gllvmTMB/blob/main/docs/dev-log/after-task/2026-05-14-roadmap-refresh.md)

---

## ⚪ Phase 1d -- Navbar restructure -- `░░░░░░░░` 0/1 PR

**Goal**: restructure `_pkgdown.yml` to the ratified
**Concepts / Worked examples / Methods + validation** taxonomy
(D2 resolved 2026-05-14). Runs after Phase 1c so every article
has a tier it can sit in.

### Work

- ⚪ Update `_pkgdown.yml` navbar `articles:` section to three
  named tiers.
- ⚪ Update home-page intro to point at the new entry-tier
  articles.
- ⚪ `pkgdown::check_pkgdown()` clean.

### Cross-refs

- [`decisions.md` 2026-05-14 D2 (3-tier taxonomy ratification)](https://github.com/itchyshin/gllvmTMB/blob/main/docs/dev-log/decisions.md)

---

## ⚪ Phase 1e -- Final reframe sweep -- `░░░░░░░░` 0/1 PR

**Goal**: one Rose + Darwin sweep across every article and
roxygen page that touches user-facing prose, before Phase 1f
closes Phase 1. Catches notation drift, cross-link drift, and
biology-first framing.

### Work

- ⚪ **Rose canon-consistency sweep**: every article reads
  canonical Psi/psi notation, paired-vs-three-piece phylo
  vocabulary, current API function names, no in-prep `Eq. N`
  citations, no Phase-X labels in user-facing text.
- ⚪ **Darwin biology-first reframe**: `morphometrics.Rmd` and
  `functional-biogeography.Rmd` currently open with model
  machinery; rewrite the first 2 – 3 sentences to lead with
  the biological question.
- ⚪ **In-prep citation discipline**: cite Nakagawa et al.
  *in prep* only where the published literature does not
  already contain the foundational result.
- ⚪ **`psychometrics-irt` framing preface**: 2-sentence note
  that this article is cross-domain validation, not the
  package's primary audience.

### Cross-refs

- [`decisions.md` 2026-05-14 Darwin biology-first reframe items](https://github.com/itchyshin/gllvmTMB/blob/main/docs/dev-log/decisions.md)

---

## ⚪ Phase 1f -- Choose-your-model rewrite (Phase 1 close) -- `░░░░░░░░` 0/1 PR

**Goal**: rewrite `choose-your-model.Rmd` now that every
article it points at exists. Each branch of the decision tree
should lead to a real worked example.

### Work

- ⚪ Rewrite the decision tree to map data-shape patterns
  ("1 row per individual + multiple traits",
  "site × species × trait grid", etc.) to specific worked
  examples.
- ⚪ Cross-link to Concepts pedagogy articles where the user
  needs background before choosing.
- ⚪ Final pkgdown render check.

### Phase 1 close gate

| Gate | Status | Verified by |
|---|---|---|
| Phases 1a – 1f all merged | ⚪ Pending | — |
| `pkgdown::check_pkgdown()` zero issues | ⚪ Pending | — |
| `urlchecker::url_check()` zero "Moved" warnings | ⚪ Pending | — |
| Every article renders without warnings on macOS + 3-OS CI | ⚪ Pending | — |
| Final Rose pre-publish audit signed off | ⚪ Pending | — |
| Spelling pre-pass run for obvious cross-article drift | ⚪ Pending | — |

After Phase 1 closes, the **Should I use this package today**
banner above flips to 🟡 **Try with caution**.

---

## ⚪ Phase 2 -- Public surface audit -- `░░░░░░░░` 0/8 PRs

**Goal**: the exported API, pkgdown reference index, examples,
and tests should describe the post-Phase-1 package, not the
2026-05-10 reset's snapshot.

### Work

- ⚪ Read the Priority 2 export audit (in `docs/dev-log/`).
- ⚪ Per export, decide: keep / internalise / delete /
  `lifecycle::deprecate_soft()`. Particular attention to
  `extract_ICC_site` (still in 0.2.0 API; review under the
  current vocabulary), `getLoadings`, `ordiplot`, and any
  other legacy alias.
- ⚪ Rewrite article examples first (for any export marked
  for deletion).
- ⚪ Bucket-by-bucket removal PRs (one coherent bucket per PR).
- ⚪ One `NEWS.md` entry for the surface cleanup.
- ⚪ Final `pkgdown::check_pkgdown()` reference-index review.

### Cross-refs

- [Priority 2 export audit (in dev-log)](https://github.com/itchyshin/gllvmTMB/tree/main/docs/dev-log)

---

## 🟢 Phase 3 -- Data-shape contract -- `█████████░` ~ 9/10 done

**Goal**: long-format and wide-format entry points should feel
like two views of one model, not two separate packages.

### State

Mostly closed via PRs #31, #32, and #65. The byte-identical
contract for `gllvmTMB()` (long), `gllvmTMB_wide()` (legacy
matrix wrapper, soft-deprecated 0.2.0), and `traits(...)` LHS
on wide data is in place. Paired tests confirm long and wide
fits produce the same log-likelihood.

### Remaining

- ⚪ Final ratification note + one small PR to close Phase 3
  after Phase 1 settles.

### Cross-refs

- [`decisions.md` Path A + Option B (2 user-facing shapes)](https://github.com/itchyshin/gllvmTMB/blob/main/docs/dev-log/decisions.md)

---

## 🔵 Phase 4 -- Feedback time (CI / fast lane) -- deferred

**Goal**: keep the 3-OS discipline while making the
maintainer's feedback loop less punishing.

### When activated

After Phases 1 – 3 are stable. The activation work is mostly
Curie's: add `skip_on_cran()` gates to the six recovery tests
(`test-beta-recovery.R`, `test-nb2-recovery.R`,
`test-delta-lognormal-recovery.R`,
`test-spatial-latent-recovery.R`,
`test-betabinomial-recovery.R`, `test-tweedie-recovery.R`) and
optionally reorganise `tests/testthat/` into subdirectories
(`unit/`, `integration/`, `recovery/`, `ci/`) for selective
harness gating.

Defer the rest of the CI fast-lane until the public surface
and data-shape contract are stable. Lower the Windows timeout
only after the gated suite reliably fits inside the stricter
budget.

---

## ⚪ Phase 5 -- CRAN readiness (mechanics) -- `░░░░░░░░` 0/8 items

**Goal**: produce a package that can pass CRAN review without
relying on private knowledge of the repo reset. This phase
covers the mechanics; Phase 5.5 covers scientific external
validation before the submission button is pressed.

### Work

- ⚪ **DESCRIPTION sweep**: title, authorship, license, DOI
  metadata clean; `Language: en-GB` field set.
- ⚪ **`inst/WORDLIST` curation**: resolve the 284-entry
  spelling backlog with author names, Greek letters, and
  GLLVM-domain acronyms.
- ⚪ **Vignette build-time budget**: precomputed artefacts
  where slow.
- ⚪ **Gauss `mu_t` finite-check polish** at
  `R/extract-sigma.R:153, 182, 240`: safety against malformed
  `eta` propagating through `log1p(1/mu_t)` and the trigamma
  family branches. About 30 LOC.
- ⚪ **`cran-comments.md` first draft**.
- ⚪ **`rhub::check_for_cran()` + `devtools::check_win_devel()`
  + `devtools::check_win_release()`** pre-flight.
- ⚪ **Sustained 3-OS CI green ~ 1 week** before submission.
- ⚪ **`devtools::submit_cran()`** -- but only after Phase 5.5
  external validation gate is signed off; the mechanics are
  ready here, the submission event fires after 5.5.

### Cross-refs

- [`decisions.md` 2026-05-14 spelling / urlchecker pre-flight items](https://github.com/itchyshin/gllvmTMB/blob/main/docs/dev-log/decisions.md)

---

## ⚪ Phase 5.5 -- External validation sprint -- `░░░░░░░░` 0/8 items, 6 – 12 weeks

**Goal**: produce the external scrutiny evidence that
gllvmTMB has been used and reviewed by people other than the
maintainer and Codex, on real data, before the CRAN
submission event fires. This is the inference-credibility and
robustness gate between Phase 5 mechanics and the actual
`submit_cran()` call.

Inserted 2026-05-14 evening per the maintainer's framing:
*"I have no intention of putting this on CRAN till we do an
amazing number of tests and checking and simulations, not just
me and you, but I include several more people."*

### Deliverables

- ⚪ **~ 3 – 5 external pilot users** (from the Nakagawa lab
  network): release-candidate build; one fit on their own
  data; bug reports; doc confusion notes; one publishable
  plot.
- ⚪ **~ 1 – 2 methods reviewers**: read `src/gllvmTMB.cpp`,
  check the TMB template + likelihood derivation against the
  manuscript equations, run a parameter-recovery study on a
  non-standard family. If Codex returns by Phase 5.5, Codex
  is the natural reviewer for the C++.
- ⚪ **Cross-package empirical agreement on a wider DGP grid**:
  glmmTMB, gllvm, galamm, sdmTMB, MCMCglmm, Hmsc. Parameter
  agreement within identifiability rotation; CI coverage;
  fit-time comparison.
- ⚪ **~ 10-DGP simulation grid**: Gaussian / binomial /
  Poisson / NB2 / ordinal × {single-level, two-level, phylo,
  spatial} × {n = 30, 100, 500}. Report bias, RMSE, and CI
  coverage in one big table.
- ⚪ **No-major-change settling period**: 2 – 4 weeks of "only
  bug fixes, no API changes" to surface latent issues.
- ⚪ **Response-to-reviewers dev-log entries** consolidating
  each external reviewer's feedback and the package's
  response.
- ⚪ **Final Rose + Shannon pre-submission audit**.
- ⚪ **Maintainer ratifies "ready for `submit_cran()`"**.

### Phase 5.5 close gate

| Gate | Status | Verified by |
|---|---|---|
| All external pilots report no blocking issues | ⚪ Pending | — |
| Simulation grid: nominal coverage, bias < 10 % RMSE on identified parameters | ⚪ Pending | — |
| Cross-package parameter agreement within identifiability tolerance | ⚪ Pending | — |
| Maintainer ratification recorded in `decisions.md` | ⚪ Pending | — |

After Phase 5.5 closes, the **Should I use this package
today** banner flips to 🟢 **Adopt freely** and the CRAN
submission event fires.

### Cross-refs

- [`decisions.md` 2026-05-14 Phase 5.5 ratification](https://github.com/itchyshin/gllvmTMB/blob/main/docs/dev-log/decisions.md)

---

## 🔵 Phase 6 -- Post-CRAN extensions -- deferred until 5.5 closes

**Goal**: after the package surface is stable on CRAN, add
scientific depth without blurring scope.

### Candidate extensions (none in priority order)

- **Nakagawa et al. methods paper draft**.
- **`cluster × unit` nesting** (currently crossed only).
- **Zero-inflated count families** (ZIP, ZINB).
- **SPDE barrier mesh** for coastal data
  (`add_barrier_mesh()`).
- **Random slopes `(1 + x | g)`** once the intercept-only
  path is fully tested.
- **Latent × observed interaction** (galamm-inspired
  `factor_interactions` analogue) -- deferred to a Phase 6
  design doc to translate galamm's wide-data API into the
  stacked-keyword grammar.
- **Algorithmic / speed work**: precompiled C++ headers,
  sparse phylogenetic VCV for `n_species > 500`,
  block-diagonal exploitation for `T >> 10`, OpenMP parallel
  inner-optim, optimizer-default benchmark (nlminb vs
  L-BFGS-B). Gauss's deferred backlog; none block CRAN.
- **Pat's deferred Concepts articles**: "How to read a
  `gllvmTMB` summary", "What `extract_*()` gives you"
  (extractor map), "Model comparison and selection",
  "Workflow: raw data → publication-ready output".
- **Darwin's deferred Worked examples**:
  `temporal-trait-change`, `plasticity-across-gradients`,
  `occupancy-codetection`,
  `spatial-species-trait-landscape`.

Every extension follows the standard discipline: design doc,
simulation test, likelihood review (if engine), documentation,
after-task report.

---

## Recent merges (rolling, newest first)

- **2026-05-14** PR #95 -- Phase 1a Batch D: drop
  `gllvmTMB_wide()` demos in `morphometrics` +
  `response-families` articles
- **2026-05-14** PR #94 -- Phase 1a Batch B + NS-3b/4/5
  notation stragglers (24+ residual `\mathbf S` / ASCII `+ S`
  / `\Psi_t` capital across 11 R/ files + 4 vignettes)
- **2026-05-14** PR #93 -- Roadmap page refresh + pkgdown
  exposure (drmTMB-style)
- **2026-05-14** PR #92 -- Phase 1a Batch A + NS stragglers
- **2026-05-14** PR #91 -- NS-5 article math prose part 2 +
  NEWS (closes notation switch)
- **2026-05-14** PR #90 -- NS-4 article math prose part 1
- **2026-05-14** PR #89 -- NS-3b R/ roxygen math-prose sweep
- **2026-05-14** PR #88 -- NS-3a API rename in
  `simulate_site_trait`
- **2026-05-14** PR #87 -- NS-2 README + design docs
- **2026-05-14** PR #86 -- NS-1 rule files + decisions +
  check-log
- **2026-05-13** PR #82 -- Batch C: Ψ phase fixes + drop
  Phase D/K labels
- **2026-05-13** PR #81 -- coord-board: seven-PR sweep merged

---

## Out of scope

- **Single-response models**: use
  [`glmmTMB`](https://glmmtmb.github.io/glmmTMB/).
- **Spatial-only single-response models**: use
  [`sdmTMB`](https://pbs-assess.github.io/sdmTMB/).
- **One- or two-response distributional regression** (mean
  and / or scale modelling of a single response, or a paired
  bivariate response with correlated residuals): use
  [`drmTMB`](https://itchyshin.github.io/drmTMB/).
- **Heteroscedastic LMM via `dispformula`**: belongs in
  drmTMB's location-scale-shape paradigm; gllvmTMB is
  location-only by maintainer constraint.
- **Bayesian sampling**: use
  [`brms`](https://paulbuerkner.com/brms/) or
  [`MCMCglmm`](https://cran.r-project.org/package=MCMCglmm).
- **Dimension reduction without a likelihood model**: use
  [`gllvm`](https://jenniniku.github.io/gllvm/) (Niku et al.)
  for the variational-approximation flavour.

A full scope comparison and decision matrix lives in
[`docs/design/04-sister-package-scope.md`](https://github.com/itchyshin/gllvmTMB/blob/main/docs/design/04-sister-package-scope.md).

---

## How this roadmap is maintained

This roadmap is a **living document**, not a frozen plan.
Things will come as the work progresses -- new scope items,
re-prioritisations, deferrals. The discipline that keeps the
page accurate:

- **Every after-task report includes a "Roadmap tick" line**
  stating which phase or sub-phase row's status chip or
  progress bar changed in that PR, or `N/A` when no row
  changed. The protocol lives in
  [`docs/design/10-after-task-protocol.md`](https://github.com/itchyshin/gllvmTMB/blob/main/docs/design/10-after-task-protocol.md).
- **When a Roadmap tick changes a row**, the same PR also
  edits `ROADMAP.md` (small change to the row's chip and
  progress bar). The pkgdown workflow re-renders this article
  on the next `main` push.
- **New phases or sub-phases** are added via a
  `docs/dev-log/decisions.md` entry first (so the addition is
  canon) and then this page is updated to surface it. Phase
  5.5 and Phase 1c-viz were both added this way on 2026-05-14.

The maintainer and the Codex / Claude teams should expect new
items to be added as the project surfaces them. The aim is
honest current-snapshot, not aspirational completeness.

Repo files remain canonical:
[`docs/dev-log/decisions.md`](https://github.com/itchyshin/gllvmTMB/blob/main/docs/dev-log/decisions.md)
for ratified scope decisions,
[`docs/dev-log/check-log.md`](https://github.com/itchyshin/gllvmTMB/blob/main/docs/dev-log/check-log.md)
for Kaizen-style numbered lessons, and the
[after-task report index](https://github.com/itchyshin/gllvmTMB/tree/main/docs/dev-log/after-task)
for every closed task.
