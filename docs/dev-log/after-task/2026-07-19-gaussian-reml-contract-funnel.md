# After Task: Gaussian REML contract and paired-certificate funnel

## 1. Goal

Make the existing Gaussian REML route mathematically honest, independently
oracle-tested, and ready for a staged paired ML-versus-REML evidence campaign.
This is not the 0.6 small-sample certificate itself and does not begin the 1.0
non-Gaussian REML/AGHQ research arc.

## 2. Implemented

The Gaussian engine restricts the ordinary fixed-effect block `b_fix`. For
eligible data, with (V(\theta)) and a full-rank observed (X\), the test
oracle is

\[
\ell_R(\theta)=-\tfrac12\{(n-p)\log(2\pi)+\log|V|+
\log|X^\top V^{-1}X|+(y-X\hat\beta)^\top V^{-1}(y-X\hat\beta)\}.
\]

Predictor-informed `latent(..., lv = ~ x)` also estimates `alpha_lv_B`, which
is not in that restricted block. It now fails loudly under `REML = TRUE` rather
than being called REML. The guard also requires positive residual degrees of
freedom. No TMB likelihood parameterisation, formula grammar, family, or broad
inference API was added.

The new paired runner records one labelled ML and REML row per target, DGP seed,
and fit, plus convergence, Hessian, gradient, boundary, timing, source, and
error fields. Its fixtures are exactly `diag3` and `latent1_psi3`.

## 3. Files Changed

- Contract and guards: `R/fit-multi.R`, `R/lv-predictor.R`, `R/gllvmTMB.R`,
  `R/reml-bridge.R`, `man/gllvmTMB.Rd`.
- Independent oracle and boundary tests: `tests/testthat/test-gaussian-reml.R`,
  `tests/testthat/test-lv-reml-gaussian.R`,
  `tests/testthat/test-lv-reml-boundary-guard.R`.
- Campaign machinery: `dev/reml-paired-funnel.R`,
  `dev/totoro-reml-paired-funnel.sh`.
- Scope/documentation: `docs/design/03-likelihoods.md`,
  `docs/design/35-validation-debt-register.md`,
  `vignettes/articles/model-selection-latent-rank.Rmd`,
  `docs/dev-log/2026-07-19-gaussian-reml-certificate-execution.md`, and
  `docs/dev-log/audits/2026-07-19-rose-gaussian-reml-prepublish.md`,
  `docs/dev-log/audits/2026-07-19-gaussian-reml-d43-admission.md`, and
  `docs/dev-log/handover/2026-07-19-codex-gaussian-reml-withheld.md`.
- Example cascade: only `vignettes/articles/model-selection-latent-rank.Rmd`
  changed. README, NEWS, ROADMAP, AGENTS, and `_pkgdown.yml` were intentionally
  not changed because no capability is promoted.

## 3a. Decisions and Rejected Alternatives

- **Decision:** reject all predictor-informed `lv` REML fits. **Rationale:**
  the present integration omits `alpha_lv_B`; Gauss's code-path review and the
  dense-oracle contract make a partial restriction indefensible. **Rejected
  alternative:** retain Gaussian `lv` REML as an engine convenience.
  **Confidence:** high.
- **Decision:** keep ML for rank selection and use REML only after selection.
  **Rationale:** ML and REML likelihoods are not comparable across a candidate
  rank table. **Rejected alternative:** compare ranks with a mixed ML/REML
  table. **Confidence:** high.
- **Decision:** withhold the 0.6 certificate. **Rationale:** only deterministic
  tests and a local 25-replicate paired pilot exist. **Rejected alternative:**
  infer a coverage improvement from point estimates or a previous ML campaign.
  **Confidence:** high.

## 4. Checks Run

- `NOT_CRAN=true Rscript --vanilla -e 'devtools::test(filter = "gaussian-reml|lv-reml", reporter = "summary")'` — PASS.
- Local deterministic paired runner (2 reps) — 12 paired target rows, all
  paired fits complete.
- Local `pilot25-local` runner (`n_units = 50`) — 300 long rows / 150 paired
  target rows; all complete. This is timing/recovery reconnaissance only.
- Funnel health smoke (`n_units = 12`, one paired replicate per fixture) —
  PASS: both ML and REML rows had `convergence = 0`, `pd_hessian = TRUE`, and
  maximum gradients below the declared `0.01` tolerance.
- Small-unit stress smoke (`latent1_psi3_stress`, two paired replicates) —
  PASS: its fixture-specific 20-unit, two-observation design preserved the
  paired optimizer-health flag.
- Predeclared profile smoke — PASS: `diag3` profiles only trait 2 total
  variance (truth 0.55) and `latent1_psi3` only trait 1 total variance (truth
  0.94); all four ML/REML intervals were finite, ordered, and agreed with
  `extract_Sigma(..., part = "total")` within `1e-6`.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` — PASS; rendered
  `man/gllvmTMB.Rd` spot-check has zero `\\keyword` tags (none were added).
- `rmarkdown::render("vignettes/articles/model-selection-latent-rank.Rmd", output_file = "/tmp/gllvmtmb-model-selection-reml.html", quiet = TRUE)` — PASS; rendered text contains the new restriction and MIS-33.
- `pkgdown::check_pkgdown()` — FAIL: pre-existing `_pkgdown.yml` omissions for
  `kernel_scalar`, `reml_bridge`, and `scalar`.
- `pkgdown::build_articles(lazy = FALSE)` — attempted; a complete clean-site
  result was not obtained in this host session, so the temporary targeted render
  above is the only article-render receipt.
- `NOT_CRAN=true R CMD check --as-cran gllvmTMB_0.5.0.tar.gz` — FAIL: after
  installation starts, the host terminates the R subprocess with `Killed: 9`.
- Full `devtools::test()` — FAIL outside this slice (visual snapshot files and
  `test-tweedie-fixed-p.R`); no failure was attributed to these changes.
- `git diff --check` — PASS.

## 5. Tests of the Tests

The dense oracle is an independent computation, including a perturbed
outer-parameter point, so it would catch an objective that agrees only at an
optimum. `indep`, `dep`, and rank-2 `latent()+Psi` are feature-combination
tests. The positive-df and `lv` rejection tests are boundary/failure-path tests;
the surviving ordinary Gaussian acceptance tests are their counterpart.

## 6. Consistency Audit

```sh
rg -n "REML = TRUE|REML|MIS-33|non-Gaussian" R/gllvmTMB.R R/reml-bridge.R R/lv-predictor.R man/gllvmTMB.Rd vignettes/articles/model-selection-latent-rank.Rmd docs/design/03-likelihoods.md docs/design/35-validation-debt-register.md
rg -n "gllvmTMB_wide|meta_known_V|\\bphylo\\(|\\bgr\\(|\\bmeta\\(|block_V\\(|phylo_rr\\(" vignettes/articles/model-selection-latent-rank.Rmd R/gllvmTMB.R man/gllvmTMB.Rd
rg -n "\\bS_B\\b|\\bS_W\\b|\\\\bf S" R/gllvmTMB.R man/gllvmTMB.Rd vignettes/articles/model-selection-latent-rank.Rmd docs/design/03-likelihoods.md
```

Verdict: touched surfaces agree on the narrow Gaussian contract; no touched
surface advertises non-Gaussian REML, `lv` REML, AGHQ, or a coverage win. Rose's
full claim/rendered-surface matrix is in the paired audit file and withholds
public promotion.

## 7. Roadmap Tick

N/A — no `ROADMAP.md` status chip changed: the certificate evidence is not yet
admitted.

## 8. What Did Not Go Smoothly

The local host killed the CRAN-check R subprocess and did not yield a clean
full pkgdown receipt. Existing full-suite visual/Tweedie failures and the
reference-index error independently prevent a release rung. The first build
attempt also used an invalid output option; it was discarded and not counted as
evidence. The first isolated Totoro install found that its private R library
lacked `assertthat`; the retry prepends that checkout's library to the existing
Totoro dependency library. No failed remote output is used as evidence.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Ada:** preserved the park-lane/check-log fence and converted the broad arc
into a testable contract plus an evidence funnel.

**Gauss:** identified the omitted `alpha_lv_B` restriction and required the
fail-loud `lv` guard; this prevented an invalid Gaussian-only claim.

**Fisher:** kept the paired ML/REML unit of comparison and distinguished a
point-recovery pilot from interval-coverage evidence.

**Rose:** the pre-publish matrix separates consistent source text from release
readiness and blocks all public promotion pending full certificate evidence.

**Grace:** the local pkgdown and `--as-cran` receipts classify the release rung
as NOT READY rather than allowing a green focused test subset to imply release
fitness.

**Noether:** verified that the total-variance profile targets the same
\(\Lambda\Lambda^\top+\Psi\) estimand as the documented Gaussian contract,
while withholding the separate certificate claim.

## 10. Known Limitations and Next Actions

The point 100/500 gates ran cleanly, but the 150-unit profile 100-screen hit
six predeclared gradient-threshold failures (all otherwise converged and PD).
Both certificate fixtures stop before the profile 500/15,000 stages; do not
relax the 0.01 threshold post hoc. The independent raw-shard audit, then fresh
Fisher, Grace, and Noether D-43 decisions must confirm the WITHHELD outcome.
Any later retry needs a newly approved optimizer/gradient contract, disjoint
seed manifest, and fresh pilot—not a rerun quietly relabelled as this
certificate. Do not begin the 1.0 AGHQ/Cox--Reid spike until this 0.6 negative
result is landed and handed off. Issue #705 was inspected; it concerns
matrix-free large-data REML and is not this small-sample certificate. No issue
was closed or created in this slice.
