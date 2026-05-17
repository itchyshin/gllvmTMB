# gllvmTMB Roadmap

*Last refreshed: 2026-05-16 (function-first milestone insertion).*

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
| Phase 1b | Engine + extractor fixes | ✅ Done | `████████` 5/5 | PRs #100 (mu_t clamp), #101 (link_residual="auto"), #104 (check_auto_residual), #105 (check_identifiability), #106 (mixed-family + 15-family fixture) + **P0 audit fix** PR #116 (multi-start sdreport consistency) |
| 2026-05-15 audit response | External-audit triage + P0 / P1a / P1b / P1c | ✅ Done | `████` 4/4 | PRs #109 (drmTMB scan), #116 (P0 multi-start fix), #117 (README softening + feature matrix), #118 (audit-response doc + decisions.md), #119 (profile_targets + confint(method=...) routing) |
| Phase 1b validation | Profile-likelihood CI validation | 🟢 Gaussian baseline | `█████░` 3/3 (Gaussian) | PR #121 (gllvmTMB_check_consistency, merged); PR #120 (confint_inspect, merged); PR-0C.COVERAGE (R = 200 Gaussian d=2 grid shipped at `dev/precomputed/coverage-gaussian-d2.rds`). Binomial / nbinom2 / ordinal-probit / mixed-family cells walk via M3.3. |
| Phase 0A | Function-first infrastructure prep | ✅ Done | `████████` 1/1 | PR #132. 8 design docs + AGENTS.md DoD + after-task 10-section template + stop-checkpoint skill + validation-debt register (102 rows). |
| Phase 0B | Empirical verification (zero `claimed` rows) | ✅ Done | `████████` 4/4 | PRs #134–#139. Walked every `claimed` formula-grammar row to `covered` / `partial` / `blocked`; 9 new smoke tests. |
| Phase 0C | Transition cleanup (article overpromise) | ✅ Done | `████████` 6/6 | PRs #140 (triage), #141 (paper notes), #142 (pkgdown hotfix), #143 (PULL), #144 (TRIM), #145 (PREVIEW), #146 (REWRITE-PREP), #147 (ROADMAP), PR-0C.COVERAGE. Phase 0C closed; M1 dispatched at PR #149; M1 closed at PR #160. |
| **Phase 1c-slope** | **Random slopes (NEW pre-CRAN)** | ⚪ Planned | `░░░░░░░░` 0/6 | Engine generalisation + extractors + recovery + plots + article. **Capped at 1 slope per fit** per M1 design. |
| Phase 1c article ports | Article ports + new Concepts pedagogy | 🔵 Frozen at 7/14 | `█████░░░` 7/14 | **Superseded 2026-05-15** by the function-first M1 / M2 / M3 milestone sequence below. Remaining article work absorbed into M1.9 (mixed-family-extractors), M2.5 (psychometrics-irt rewrite), M3.6 (simulation-recovery-validated), and Phase 1f (choose-your-model rewrite). |
| **M1** | **Mixed-family extractor rigour** | ✅ Done | `████████` 10/10 | PRs #149 – #158 + M1.10 close gate. Every extractor validated on `family = list(...)` fits; `mixed-family-extractors.Rmd` shipped; MIX-03..MIX-06, MIX-08, MIS-05 walked to `covered`. |
| **M2** | **Binary completeness** | 🟢 In progress | `████░░░░` 4/7 | Weeks 3–5. M2.1 design note + M2.2-A binary family recovery + M2.2-B binary CIs/extractors/glmmTMB cross-check + M2.3 `lambda_constraint` binary IRT + mirt + galamm cross-checks shipped 2026-05-17. |
| **M3** | **Inference completeness across families** | ⚪ Planned | `░░░░░░░░` 0/8 | Weeks 5–7. `coverage_study()` ≥ 94 % on Gaussian / binomial / nbinom2 / ordinal-probit / mixed-family at R = 200. |
| Phase 1c-viz | Visualization layer completion | ⚪ Planned | `░░░░░░░░` 0/7 | Static + interactive plot dispatcher (incl. random-slope plots) |
| Phase 1d | Navbar restructure | 🟢 Partly done | `█░` 1/2 | PR #112 created the **Methods + validation** tier; full 3-tier audit deferred to a Phase 1d close PR |
| Phase 1e | Final reframe sweep | 🟢 Partly done | `█░` 1/2 | PR #107 phylo three-piece-fallback subsection landed; full cross-article sweep deferred |
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

## ✅ Phase 1b -- Engine + extractor fixes -- `████████` 5/5 items done

**Goal**: close two correctness gaps in the multivariate
extractor / correlation surface and add the identifiability
and inference diagnostics that the package will need to make
honest claims at CRAN time and for the manuscript. **Closed
2026-05-15.**

### Work items

- ✅ **P1 -- `extract_correlations()` `link_residual = "auto"`**
  -- PR #101 merged 2026-05-15. Switched the default to `"auto"`
  with a one-shot deprecation warning; the per-family residual
  plumbing in `R/extract-sigma.R:99-280` is now the default code
  path. Companion `mu_t` Beta / betabinomial clamp landed as
  PR #100 (saturated `eta -> +/-Inf` no longer crushes
  correlations to ~0 via `trigamma(1e-12) ~ 1e24`).
- ✅ **`check_auto_residual()` safeguard** -- PR #104 merged
  2026-05-15. Warns when ordinal-probit traits are present
  (the auto path over-counts; latent residual is already 1 by
  construction) and errors with class
  `gllvmTMB_auto_residual_incoherent` when a trait mixes
  incompatible families.
- ✅ **`check_identifiability(fit, sim_reps = 100)` diagnostic**
  -- PR #105 merged 2026-05-15. Simulate-refit + Procrustes
  alignment + Hessian eigenvalue rank check; the canonical case
  it catches that no other diagnostic does is a **spurious extra
  factor masquerading as identified** (a column of Λ with
  near-zero Procrustes-aligned residual magnitude across
  replicates). V1 scope: Gaussian fits only; non-Gaussian
  extension queued for the Phase 1b validation milestone.
- ✅ **Mixed-family extractor tests + 15-family fixture** -- PR
  #106 merged 2026-05-15. New `test-mixed-family-extractor.R`
  (extract_Sigma + extract_correlations on `family = list(...)`
  fits) and new `test-link-residual-15-family-fixture.R`
  (mock-fit fixture per family ID 0-14).
- ✅ **Expanded profile-CI edge-case tests** -- partly covered by
  PRs #105 (check_identifiability), #106 (mixed-family),
  #119 (profile_targets + confint(method=...) routing for
  variance components). The full edge-case sweep is part of
  the Phase 1b validation milestone (PRs #120 / #121 / #122).

### P0 audit fix bundled into Phase 1b (added 2026-05-15)

- ✅ **PR #116: multi-start `obj$report()` / `sdreport(obj)`
  consistency with `fit$opt$par`** -- the external audit's #1
  concrete concern, verified by code inspection then fixed at
  `R/fit-multi.R:1700-1737`. Three-step pinch of TMB's internal
  state: `obj$fn(opt$par)` -> `obj$env$last.par.best <-
  obj$env$last.par` -> `obj$report()` + `TMB::sdreport(obj,
  par.fixed = opt$par, ...)`. Bundled regression test
  `test-multi-start-sdreport-consistency.R` with 17
  expectations. Closes a real correctness bug that would have
  affected every multi-start fit (`n_init >= 2`) where restart
  1 won but restart N (N > 1) ran last.

### Phase 1b close gate -- 2026-05-15

| Gate | Status | Verified by |
|---|---|---|
| All 5 items shipped across 4 – 5 PRs | ✅ Done | PRs #100, #101, #104, #105, #106 |
| Mixed-family tests pass on the 15-family fixture | ✅ Done | PR #106 |
| New diagnostics return sensible output on a known-bad fit | ✅ Done | PR #105 (`check_identifiability`), PR #104 (`check_auto_residual`) |
| 3-OS R-CMD-check green | ✅ Done | All PRs merged on 3-OS green CI |
| P0 audit fix landed + bundled regression test | ✅ Done | PR #116 |

### Cross-refs

- [Audit: 2026-05-13 post-overnight drift scan, items 9 – 10](https://github.com/itchyshin/gllvmTMB/blob/main/docs/dev-log/audits/2026-05-13-post-overnight-drift-scan.md)
- [`decisions.md` 2026-05-14 D4 ratification (`link_residual = "auto"`)](https://github.com/itchyshin/gllvmTMB/blob/main/docs/dev-log/decisions.md)

---

## 🟢 Phase 1b validation -- Profile-likelihood CI validation -- `██░░` 2/3 in main; 1 in flight

**Goal**: produce the validation evidence that gllvmTMB's
three-method confidence interval API (`profile` / `wald` /
`bootstrap`) actually delivers the coverage it claims, on the
families and parameter types the package supports. This is the
inference-credibility gate before article ports continue in
Phase 1c. **Started + mostly completed 2026-05-15** after the
external-audit and TMB-report cross-team scans flagged the
TMB-built-in toolset (`tmbprofile()`, `tmbroot()`,
`checkConsistency()`) as the right machinery to surface.

### Deliverables (shipped as 3 sequential PRs, not one bundled
milestone PR as originally scoped -- breaking it into three
made review easier)

- ✅ **`confint_inspect(fit, parm)` function** -- PR #120,
  cross-reference fix in flight. Visual-verification companion
  to `confint(method = "profile")`. Returns the full profile-
  likelihood curve, the deviance bounds, a Wald-vs-profile
  comparison, and (when ggplot2 is available) a ggplot showing
  the curve with MLE + chi-squared threshold + both profile
  and Wald bounds. Eight diagnostic flags catalogue the four
  canonical failure modes from `troubleshooting-profile.Rmd`.
- ✅ **`gllvmTMB_check_consistency()` -- Laplace-accuracy test**
  -- PR #121 merged 2026-05-15. Thin wrapper around
  `TMB::checkConsistency()` that tests whether the approximate
  marginal score is centred at zero. A non-centred score is a
  sign that the Laplace approximation is unreliable for the
  fit. Five diagnostic flags including
  `"information_matrix_singular"` for tiny / weakly-identified
  fixtures.
- 🟢 **`coverage_study(fit, n_reps, methods)` function** --
  PR #122 (`[0,1]` autolink fix held until #120 lands; cross-
  references to `confint_inspect()` need #120 in main first).
  Empirical coverage-rate estimator. For each replicate
  simulates from the fit, refits, computes CIs via the
  requested methods, counts the fraction containing the
  original fit's estimates. Returns a `gllvmTMB_coverage_study`
  object with a `passes_94pct` column flagging the audit's
  exit gate per (`parm` × `method`) row. Also extends
  `confint(method = "wald")` to route non-fixed-effect parm
  labels through `.confint_wald_targets()` -- previously these
  returned `NA` bounds.
- ✅ **`troubleshooting-profile.Rmd` Concepts article** --
  PR #115 merged 2026-05-15 (early in the validation
  milestone). Four failure-mode catalogue cross-linked from
  `confint_inspect()` and the queued `simulation-verification`
  article.
- ✅ **`simulation-verification.Rmd` Concepts article** --
  local draft (`agent/phase1c-new-simulation-verification`),
  push held until the validation-milestone PR chain clears so
  the cross-links to `confint_inspect()`, `coverage_study()`,
  `gllvmTMB_check_consistency()` reference pages all resolve
  on first CI run.
- ⚪ **Empirical coverage matrix on the audit's three canonical
  families (Gaussian / NB2 / ordinal-probit, 50 replicates per
  family)** -- scoped as an **internal artefact** rather than
  a user-facing function. The user-facing function path
  (`coverage_study()`) lets any user run their own; the
  canonical-fixtures matrix is a Phase 5.5 external-validation
  sprint deliverable that depends on the user-facing pieces
  landing first.

### Phase 1b validation close gate

| Gate | Status | Verified by |
|---|---|---|
| `confint_inspect()` passes on all three methods | 🟢 In flight | PR #120 (cross-reference fix pushed; CI re-running) |
| `gllvmTMB_check_consistency()` ships + tested | ✅ Done | PR #121 |
| `coverage_study()` ships + Wald confint routing extended | 🟢 In flight | PR #122 (local fix held pending #120) |
| `troubleshooting-profile.Rmd` article merged | ✅ Done | PR #115 |
| `simulation-verification.Rmd` Concepts article merged | 🟢 Drafted | Local branch, push held pending #120/#122 |
| Empirical coverage matrix on canonical fixtures (>= 94%) | ⚪ Pending | Phase 5.5 sprint scope |
| Rose pre-publish audit sign-off | ⚪ Pending | After PR #120/#122 + simulation-verification merge |

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

## 🟢 Phase 1c -- Article ports + new Concepts pedagogy -- `█████░░░` 7/13 in main; 2 local drafts

**Goal**: port the surviving legacy articles to the current
API + 2026-05-14 vocabulary, and write the three to four new
Concepts-tier pedagogy articles that the persona consults
identified as gaps. After Phase 1c the article roster is
complete and the navbar can be restructured (Phase 1d). **The
4th new pedagogy article (`troubleshooting-profile.Rmd`) was
added 2026-05-14 evening per Fisher's second-pass consult and
ships as part of the validation milestone**, so the article
roster is now 14 total (5 new + 9 ports).

Article taxonomy (ratified 2026-05-14 as D2): **Concepts**
(decision / orientation), **Worked examples** (one scientific
domain per article), **Methods + validation** (cross-check /
simulation-recovery / methodology).

### Concepts tier (5 articles -- 4 merged, 1 drafted)

- ✅ `data-shape-flowchart.Rmd` -- PR #114 merged 2026-05-15
  (Pat). 1-page visual decision tree mapping data shapes to
  articles. Mermaid flowchart + ASCII fallback.
- ✅ `gllvm-vocabulary.Rmd` -- PR #113 merged 2026-05-15 (Pat).
  Plain-English glossary; plain + math definitions for every
  jargon term. Cross-linked from every Concepts article on
  first use.
- ✅ `lambda-constraint.Rmd` -- PR #108 merged 2026-05-15
  (port; D1 resolved 2026-05-14 as standalone Concepts
  article; prerequisite of `psychometrics-irt`).
- ✅ `troubleshooting-profile.Rmd` -- PR #115 merged 2026-05-15
  (Fisher). Four canonical failure modes catalogue.
- 🟢 `simulation-verification.Rmd` -- LOCAL DRAFT (Curie +
  Fisher). 5 sections including Fisher's profile-curve-anatomy
  bridge to `profile-likelihood-ci` + `confint_inspect()`. Push
  held until PR #120 (confint_inspect) and #122 (coverage_study)
  land in main so the cross-links resolve.

### Worked examples tier (6 ports -- 3 merged, 1 drafted)

- ✅ `mixed-response.Rmd` -- PR #111 merged 2026-05-15. P1
  link_residual="auto" landed earlier in the same wave.
- ⚪ `stacked-trait-gllvm.Rmd` -- foundational; no deps. Queued.
- ⚪ `phylo-spatial-meta-analysis.Rmd` -- closes one spatial
  example gap. Queued.
- ⚪ `spde-vs-glmmTMB.Rmd` -- closes the other spatial example
  gap. Queued.
- 🟢 `corvidae-two-stage.Rmd` -- LOCAL DRAFT. Verifies
  `meta_known_V()` workflow on a Corvidae-style proxy. Push
  held until the validation-milestone wave clears.
- ✅ `psychometrics-irt.Rmd` -- PR #110 merged 2026-05-15.
  Cross-domain validation: CFA on mixed Gaussian + binomial
  items.

### Methods + validation tier (3 ports -- 1 merged + new tier created)

- ✅ `profile-likelihood-ci.Rmd` + **NEW Methods + validation
  navbar tier** -- PR #112 merged 2026-05-15. First article in
  the new pkgdown tier per the D2 taxonomy.
- ⚪ `cross-package-validation.Rmd` -- glmmTMB, gllvm, galamm,
  sdmTMB, MCMCglmm, Hmsc. `brms` dropped (Fisher's revision);
  `lavaan` deferred post-CRAN. Queued.
- ⚪ `simulation-recovery.Rmd` -- lands last; depends on all
  others. Queued.

### Phase 1c close gate

| Gate | Status | Verified by |
|---|---|---|
| All 14 articles merged (5 new + 9 ports) | 🟢 7/14 in main; 2 drafted locally | -- |
| Each article renders without warnings | ✅ For the 7 merged | local + 3-OS CI |
| Rose pre-publish audit on every article PR | 🟢 In progress | -- |
| Pat reading-path audit on Concepts tier | ⚪ Pending | After all 5 land |
| Darwin biology-question audit on Worked examples tier | ⚪ Pending | After all 6 land |

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

## ⚪ Phase 1 milestones -- M1 / M2 / M3 (function-first machinery completeness)

The **function-first pivot** (2026-05-15; ratified in
[`decisions.md`](https://github.com/itchyshin/gllvmTMB/blob/main/docs/dev-log/decisions.md)
item 9) replaced the article-port-centric Phase 1c plan with
three milestones (M1, M2, M3) that walk advertised machinery to
empirically validated machinery before any further article
work. **Machinery is designed and tested before examples are
written.** Articles describing M1 / M2 / M3 machinery ship as
part of each milestone's close PR, not ahead of it.

Each slice follows the drmTMB-team rhythm: **Goal → Main work →
Done when**. Per-slice owners are named; reviewers are recorded
in each slice's after-task report.

### ✅ M1 -- Mixed-family extractor rigour -- `████████` 10/10

> **Goal**: every extractor returns correct, unit-tested values
> on `family = list(...)` fits across the 15-family matrix. The
> unparalleled-capability differentiator (vision item 5) walks
> from `partial` to `covered` in the validation-debt register.

| Slice | Goal | Lead | Done when |
|-------|------|------|-----------|
| **M1.1** | Per-extractor mixed-family audit (which paths handle `family = list(...)` correctly) | Boole + Emmy | Audit table filed at `docs/dev-log/audits/2026-05-NN-mixed-family-extractor-audit.md`. |
| **M1.2** | Mixed-family fixture (3-family + 5-family fits with known DGP) | Curie | `inst/extdata/mixed-family-fixture.rds` ships; fixture loads in CI. |
| **M1.3** | `extract_Sigma()` mixed-family validation | Emmy | Tests pass on both fixtures; matches reference Sigma to TMB tolerance. **Walks MIX-03 → `covered`.** |
| **M1.4** | `extract_correlations()` mixed-family (Fisher-z + Wald + profile + bootstrap) | Fisher | Tests pass on all 4 methods × both fixtures. **Walks MIX-04 → `covered`.** |
| **M1.5** | `extract_communality()` mixed-family | Emmy | Tests pass; $H^2 + C^2 + \psi^2 = 1$ within tolerance. **Walks MIX-05 → `covered`.** |
| **M1.6** | `extract_repeatability()` + `extract_phylo_signal()` mixed-family | Emmy + Fisher | Tests pass. **Walks MIX-06 → `covered`.** |
| **M1.7** | `extract_Omega()` cross-tier on mixed-family fits | Emmy | Tests pass; cross-tier integration verified. |
| **M1.8** | `bootstrap_Sigma()` mixed-family (per-row family preserved in resamples) | Curie | Tests pass; 100 reps complete in CI under 5 min. **Walks MIX-08 → `covered`.** |
| **M1.9** | NEW article `mixed-family-extractors.Rmd` | Pat | Article renders; logLik + extractor outputs match fixture-truth; banner removed from `covariance-correlation.Rmd`. |
| **M1.10** | M1 close gate (after-phase report; Shannon audit; 3-OS green) | Ada | PR merged with after-task report; ROADMAP M1 row → ✅. |

**M1 scope boundary**: profile-likelihood CIs on derived
quantities (communality, repeatability, phylo signal) for
mixed-family fits are M3 work. M1 extends extractors to
mixed-family at the point-estimate + Fisher-z + Wald level.

### 🟢 M2 -- Binary completeness -- `████░░░░` 4/7

> **Goal**: every binary capability is end-to-end-validated,
> including `lambda_constraint` for confirmatory binary IRT
> loadings (vision rule: binary is the second family validated
> after Gaussian; "binary completeness" gates the M2.5 article
> rewrite).

| Slice | Goal | Lead | Done when |
|-------|------|------|-----------|
| **M2.1** | Binary design note expanded from Phase 0B baseline | Boole | `docs/design/41-binary-completeness.md` filed; identifies gaps for binomial GLLVM + binary IRT vs M1 Gaussian baseline. |
| **M2.2** | Binary extractor + CI validation (extend M1 suite to `family = binomial()`) | Fisher | All M1 slice tests pass on `binomial(probit)` + `binomial(logit)` fits. **Walks FAM-02 deep validation rows → `covered`.** |
| **M2.3** | `lambda_constraint` validation on binary (confirmatory loadings; pin $\Lambda$ entries; parameter recovery) | Boole + Emmy | LAM-03 walks to `covered`; recovery study at `n_items ∈ {10, 20, 50} × d ∈ {1, 2, 3}` regimes passes. |
| **M2.4** | `suggest_lambda_constraint()` validation on binary | Boole + Pat | Suggester produces sensible constraint matrices across binary regimes; reliability regime documented. |
| **M2.5** | Restore `psychometrics-irt.Rmd` against validated machinery | Pat | Article re-authored per [PR-0C.REWRITE-PREP handoff](https://github.com/itchyshin/gllvmTMB/blob/main/docs/dev-log/audits/2026-05-16-phase0c-rewrite-prep.md); `mirt::mirt()` cross-check live; audit-2 A1 "Stay Laplacian" note added; banner removed. |
| **M2.6** | Restore binary JSDM in `joint-sdm.Rmd` (long+wide pair; audit-2 A1 Laplace note) | Darwin | Article body validated; cross-references `suggest_lambda_constraint()` for users who want to identify their loadings. |
| **M2.7** | M2 close gate (after-phase report; Shannon audit; 3-OS green) | Ada | PR merged; ROADMAP M2 row → ✅; FAM-14 walks to `covered`; banner removed from `lambda-constraint.Rmd` and `ordinal-probit.Rmd`. |

**M2 scope boundary**: Gaussian + binary are end-to-end
validated after M2. Other families (Poisson, NB2, Gamma, Beta,
ordinal-probit deep validation, delta, Tweedie) remain `partial`
until post-CRAN per family-by-family validation slices.

### ⚪ M3 -- Inference completeness across families -- `░░░░░░░░` 0/8

> **Goal**: `coverage_study()` reports ≥ 94 % empirical
> coverage on Gaussian / binomial / nbinom2 / ordinal-probit /
> mixed-family at R = 200 replicates per cell. The audit-1
> empirical coverage exit gate.

| Slice | Goal | Lead | Done when |
|-------|------|------|-----------|
| **M3.1** | DGP grid (4 families × 3 dims × 200 reps + mixed-family cell) | Fisher + Curie | DGP grid documented in `docs/design/29-phase1b-empirical-coverage.md`; runs locally < 6 h. |
| **M3.2** | `dev/precompute-vignettes.R` reproducible pipeline | Curie + Grace | Script + cached RDS shipped; reproducible from clean checkout. |
| **M3.3** | Per-family profile CI accuracy validation | Fisher | All cells ≥ 94 % coverage; coverage-rate matrix filed at `docs/dev-log/audits/2026-05-NN-phase1b-empirical-coverage.md`. |
| **M3.4** | `gllvmTMB_check_consistency()` at boundary regimes | Curie | Flagged regimes (sparse-Bernoulli at d=3; ordinal-probit at d=2 with rare categories) documented in `troubleshooting-profile.Rmd`. |
| **M3.5** | Derived-quantity coverage (communality, repeatability, phylo signal) | Fisher | Coverage table reported per family; Wald-vs-profile-vs-bootstrap differential documented. |
| **M3.6** | NEW article `simulation-recovery-validated.Rmd` (replaces pulled article) | Curie + Pat | Article renders from precomputed RDS; reproducible by running `dev/precompute-vignettes.R`. |
| **M3.7** | Capstone composite validation (functional-biogeography.Rmd) | Darwin + Fisher | Composite-fit identifiability empirically demonstrated; banner removed; M3 row pointer extended to capstone. |
| **M3.8** | M3 close gate (after-phase report; Shannon audit; 3-OS green) | Ada | PR merged; ROADMAP M3 row → ✅; banners removed from `profile-likelihood-ci.Rmd` and `functional-biogeography.Rmd`. |

**M3 scope boundary**: M3 establishes empirical coverage on
simulated data drawn from the model. M5.5 extends to cross-
package agreement on real fixtures (where the truth is
different) and external-reviewer validation. The two are
complementary; neither replaces the other.

### Cross-refs

- [`decisions.md` 2026-05-16 item 9 -- Phase 0A / 0B / 0C sequencing](https://github.com/itchyshin/gllvmTMB/blob/main/docs/dev-log/decisions.md)
- [`docs/design/00-vision.md` -- function-first sequencing + "What we will NOT do"](https://github.com/itchyshin/gllvmTMB/blob/main/docs/design/00-vision.md)
- [`docs/design/35-validation-debt-register.md` -- row-level status the milestone walks are pegged to](https://github.com/itchyshin/gllvmTMB/blob/main/docs/design/35-validation-debt-register.md)
- [`docs/dev-log/audits/2026-05-16-phase0c-article-triage.md` -- the triage that informed Phase 0C and the M1/M2/M3 restoration roadmap](https://github.com/itchyshin/gllvmTMB/blob/main/docs/dev-log/audits/2026-05-16-phase0c-article-triage.md)
- [`docs/dev-log/audits/2026-05-16-phase0c-rewrite-prep.md` -- M2.5 + Phase 1f rewrite contracts](https://github.com/itchyshin/gllvmTMB/blob/main/docs/dev-log/audits/2026-05-16-phase0c-rewrite-prep.md)

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

- **2026-05-16** PR #146 -- PR-0C.REWRITE-PREP: banner +
  rewrite handoff for `psychometrics-irt` (M2.5) +
  `choose-your-model` (Phase 1f)
- **2026-05-16** PR #145 -- PR-0C.PREVIEW: Preview banners on
  5 articles citing validation-debt rows + milestones
- **2026-05-16** PR #144 -- PR-0C.TRIM: trim overpromise
  sections in `joint-sdm` + `cross-package-validation`
- **2026-05-16** PR #143 -- PR-0C.PULL: pull 3 overpromise
  articles to `dev/workshop-articles/`
- **2026-05-16** PR #142 -- PR-0C.PKGDOWN-HOTFIX: add `meta_V`
  to `_pkgdown.yml` reference index
- **2026-05-16** PR #141 -- Phase 0C paper-findings notes
  (Nakagawa et al. *in prep* 2026-05-16 reading)
- **2026-05-16** PR #140 -- Phase 0C planning audit: article
  triage for 24 vignettes/articles
- **2026-05-16** PR #139 -- PR-0B.4: `meta_V` R/ alias rename +
  restored test 9 + walk row #15 to `covered` → **ZERO
  `claimed` rows**
- **2026-05-16** PR #138 -- PR-0B.3: audit-and-confirm (walk 3
  `claimed` rows to `covered`)
- **2026-05-16** PR #137 -- PR-0B.2: 9 smoke tests in
  `test-formula-grammar-smoke.R`
- **2026-05-16** PR #134 -- PR-0B.1: per-row formula-grammar
  test audit
- **2026-05-16** PR #133 -- Cascade #1: function ↔ help-file
  binding sweep
- **2026-05-16** PR #132 -- **Phase 0A**: function-first
  infrastructure prep (8 design docs + DoD + 10-section
  template + stop-checkpoint skill + validation-debt register)
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
