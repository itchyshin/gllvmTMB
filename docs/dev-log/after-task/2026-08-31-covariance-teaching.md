# After Task: covariance teaching correction

**Branch:** `codex/covariance-teaching-20260831`  
**Date:** 2026-08-30 local / 2026-08-31 UTC  
**Status:** verification in progress; PR preparation only, no landing authorized.

## 1. Goal

Correct covariance teaching in three articles and matching nominal extractor
help without changing any fitted model, estimator, numerical calculation or
capability. The maintainer approved the plan, nine existing article fits and
one bounded package check, and explicitly separated landing from this task.

## 2. Implemented

The spatial example distinguishes rotation from nonunique shared/diagonal
partitioning and targets total spatial covariance without a stability claim.
The cross-family article and help define residual-augmented latent-liability
(model-scale) association, explicitly distinct from observed-response
correlation. ICC teaching permits a diagonal tier. Between-unit Psi, an OLRE
and fixed link residual conventions are separated. The seeded cross-family
example is a known-truth teaching check, not repeated-simulation recovery.

Four plots have explicit alt descriptions. New matching wide syntax is
unevaluated and labelled as structural translation, not demonstrated parity.
Existing long/wide fits remain in covariance and spatial; cross-family still
fits long data only. `dev/covariance-teaching/requirement-map.md` maps all five
findings and three reader issues to their before/after locations.

### Mathematical contract

No public R API, likelihood, formula grammar, family, extractor calculation,
estimand, executed model, seed, rank, control or numerical implementation
changed. The sole executable-source change is an ordinal-probit refusal's
scale label; its trigger and error classes are unchanged. Roxygen regenerated
`man/extract_cross_correlations.Rd`; ordinary correlation and Sigma help remain
unchanged. The two spatial loading matrices have off-diagonals
`(1/2,1/2,3/4)` and different shared diagonals; distinct positive Psi companions
produce identical total covariance with diagonal `(3,3,3)`.

## 4. Files Touched

Reader surfaces: `vignettes/articles/covariance-correlation.Rmd`,
`vignettes/articles/cross-family-correlations.Rmd`,
`vignettes/articles/spatial-models.Rmd`, `R/extract-correlations.R`, and
regenerated `man/extract_cross_correlations.Rd`.

Task evidence: this report; one appended `docs/dev-log/check-log.md` entry;
`dev/covariance-teaching/` contains the approved plan, fit ledger, requirement
map, four review reports, bounded runner/setup/render/check scripts,
no-fit harness test, invariant and rendered-page verifiers, and receipts.
The final inventory is recorded in `dev/covariance-teaching/file-inventory.txt`.
Local libraries, caches, raw logs and rendered pages are retained but excluded
from Git. The Unlazy acceptance ledger is `.unlazy/covariance-teaching/GATES.md`.

Verified clean outside scope: `src/`, `tests/`, fixtures and their generator,
`NAMESPACE`, `DESCRIPTION`, `README.md`, `NEWS.md`, `ROADMAP.md`, `_pkgdown.yml`,
`R/extract-sigma.R`, `man/extract_Sigma.Rd`, and ordinary
`man/extract_correlations.Rd`. No convention/API cascade or capability promotion
was needed. The covariance fixture is tracked and was not regenerated.

## 3a. Decisions and Rejected Alternatives

The approved models stayed frozen; no model repair, new wide fit, seed search,
restart or recovery study was attempted. The spatial counterexample is an
algebraic demonstration, not an observed optimizer failure. No new issue or
capability claim is inferred from it. Reviewer corrections were confined to
the same meanings: the summary preamble, communality qualification, and
explicitly different Psi companions.

## 5. Checks Run

- Canonical lane preflight and `route.py gllvmTMB`: completed. Fetched
  `origin/main` at `da6398a9d8df78c04dc4645dfa3fd4c3bd8d75e3`; five targets
  unchanged from audit `255cedd6`. No intervening main changes at refresh.
- `Rscript --vanilla dev/covariance-teaching/verify-invariants.R`: PASS;
  evaluated R ASTs identical, diagnostic-only executable delta, spatial
  counterexample verified. Mechanical positive/negative controls passed.
- `devtools::document(quiet = TRUE)`: PASS with three pre-existing S3-tag
  warnings in `aghq-report.R`. Only intended Rd differs after the ordinary
  extractor roxygen was restored. `pkgdown::check_pkgdown()`: no problems.
- Isolated production `R CMD INSTALL --preclean --no-multiarch --library=...`:
  PASS in the 98.701-second successful setup receipt. Compiler warnings retained.
- `Rscript --vanilla dev/covariance-teaching/check-render-harness.R`: PASS
  without fitting; package-namespace bindings, nested forwarding counter and
  suppressed-warning capture exercised.
- One render of each affected article using `pkgdown::build_article(...,
  lazy=FALSE, new_process=FALSE)`: covariance 12.012 seconds, cross-family
  20.226 seconds, spatial 10.254 seconds. Nine model fits, convergence code 0
  for each; 42.492 seconds process time and 207.254 seconds block wall time.
  **The covariance wrapper exited 1 after successful HTML creation because
  function-entry counting included wide-to-long recursion.** Its raw failed
  receipt, original trace, HTML and warnings remain untouched. The separate
  `covariance-reconciliation.json` proves three top-level fits using the
  trace nesting and `R/gllvmTMB.R:762–874`; no rerender or refit occurred.
- `python3 dev/covariance-teaching/verify-rendered.py`: PASS; actual HTML
  contains all four source-matched alt attributes, corrected meanings, wide
  labels and nonempty local CSS/JS/image assets. All four PNGs inspected.
  Sass cache-write warning did not omit presentation output. The browser
  policy blocked local-file navigation; no workaround was attempted, so
  browser viewport/wrapping inspection is not claimed.
- One `devtools::check(args="--no-manual", document=FALSE)` with a separate
  30-minute cap: running; result pending.
- Final-commit three-OS manual CI: pending. Routine workflow verified to be
  Ubuntu-only; manual `full_matrix=true` is required for all three OSes.

No standalone fit/test campaign, added wide fit, bootstrap, profile, model
restart, deployment, release or merge was run. Existing focused checks for
ordinal-probit refusal and cross-family intervals were inspected; no low-value
wording-mirroring tests were added.

## 6. Tests of the Tests

Luna's static negative controls detect a changed model expression and an
illustration accidentally made evaluable. The no-fit namespace stub proves
trace bindings resolve; a nested stub exposes the distinction between a public
fit call and recursive wide forwarding. The warning-hook stub emits a sentinel
that is retained in the log but absent from rendered text. The first render's
failed oracle is preserved as a failure, not rewritten as a pass.

## 8. Consistency Audit

Exact scans are retained in `dev/covariance-teaching/static-scans.txt`.
No stale observation-scale nominal label or commensurability assertion remains
in the corrected surface; no guarantee that replication/N resolves covariance
estimation remains in the cross-family caveat. Source defaults, signatures,
ordinal refusal and error classes agree with baseline. Added wide chunks are
all unevaluated and no register codes were added to reader-facing text.

Existing validation boundaries remain: SPA-02 partial; SPA-01/SPA-04 retain
their named structural/route evidence; FAM-20B, FG-18 and RE-13 remain partial;
MIX-03 through MIX-09 and EXT-12 retain their existing extractor/route scope.
No register row status moved. Spatial/cross-family interval and wider recovery
claims remain unearned and are not advertised by this correction.

## 7. Roadmap Tick

N/A — no capability milestone, release rung or roadmap status changed.

## 7a. Issue Ledger

No new issue created: this is the maintainer-approved audit correction.
PR1229 is already merged and was not reused. Open PRs1209,1198,1077,1070,1065,981
were inspected for overlap, not edited or merged. The three older Cursor PRs
contain check-log changes; no live lease conflicted with this task's exact
append lease. Their branches and all tree-axis work remain protected.

## 9. What Did Not Go Smoothly

Setup attempts failed on the local devtools logical `upgrade` argument, a pak
cache lock outside the sandbox, then a split `--library` argument. All stopped
before any article fit or shared-library installation and their receipts remain.
Direct install with `--library=PATH` succeeded. The covariance render counter
incorrectly counted nested forwarding; reconciliation required no scientific
rerun. A rendered-text verifier initially expected wording stronger than the
approved requirement; it was corrected to check the actual target statement,
with Noether/Rose's manual no-stability-overclaim review retained. A mechanical
review briefly mistook a diff context heading for roxygen ownership; exact
function-block and Rd inspection corrected the report.

## 11. Team Learning

**Noether** verified the spatial example algebraically and caught the adjacent
summary preamble and unconditional communality claim. Rotation-invariance is
not sufficient evidence that a shared/diagonal decomposition is identified.

**Pat** checked the applied reader path and missing wide examples. Explicitly
saying the Psi companions differ makes the counterexample usable without
asking readers to infer the key step.

**Rose** checked the five-file cascade, defaults and restrictions, retaining
the experimental boundaries. An unchanged commensurability sentence in
`R/extract-sigma.R:545–548` is a separately scoped follow-up, not an excuse to
expand this correction or its fit allowance.

**Ada/Grace** retained failed instrumentation/setup receipts, isolated the
install, checked actual HTML/PNG outputs and distinguished fit counts from
function-entry counts. The no-fit harness now includes recursion as well as
lexical bindings and warning capture. Native dispatch requested Terra medium
for implementation/Pat/Rose, Luna medium for mechanical checks and Sol high
for Noether; model labels were dispatch settings, not inferred from prose.

## 10. Known Residuals

Complete the bounded package check, prepare the focused PR and obtain green
three-OS CI on its final candidate commit. **STOP BEFORE MERGE/LANDING.**
No public site has been deployed or checked here; after separate landing
approval, verify all three deployed pages. Raw logs and local rendered pages
remain in this worktree. No models or confidence-interval claims were validated
beyond the executed teaching examples. The separate extract-Sigma wording
follow-up and blocked browser layout inspection remain explicit limitations.

## 12. Cross-Product Coverage

This slice does NOT cover new covariance models, non-Gaussian OLRE support,
identifiability of arbitrary ranks or compositions, repeated-simulation
recovery, interval calibration, new long/wide parity, tree-axis work,
release readiness, deployed pages or landing. The nine article fits exercise
only the existing teaching examples; package/CI checks have separate receipts.
