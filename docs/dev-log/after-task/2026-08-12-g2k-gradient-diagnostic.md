# After Task: G2k all-attempt gradient diagnosis

**Branch:** `codex/isdm-g2k-gradient-diagnostic`
**Date:** 2026-08-12
**Roles engaged:** Ada, Gauss, Noether, Fisher, Curie, Rose

## 1. Goal

Explain why the completed six-species G2k campaign has 106/150 all-metric
recoveries but only 22/150 strict passes, then make one evidence-bound repair
decision without fitting or changing the frozen model/campaign contract.

## 2. Implemented claim

A private, read-only 150-attempt extractor and certificate establish that raw
gradient is the principal strict-admission loss (89 failures; 69 otherwise
metric-passing attempts), but not the only admission interaction.  The decision
is `NO_REPAIR`: retain `G2K_CALIBRATION_HOLD` because no same-objective repair
is evidenced for the dominant non-boundary residual-score geometry.

## 3. Files Changed

The files created by this private evidence lane are listed below.  The
mathematical contract is unchanged and recorded under the next heading.

### Mathematical contract

No public R API, likelihood, formula grammar, family, NAMESPACE, generated Rd,
vignette, pkgdown navigation, DGP, parameter map, threshold, or recovery
criterion changed.  The certificate records the unchanged Poisson-plus-
PA-cloglog model, \(\psi_s=\exp(\theta_{\rm diag,s})\), raw score
\(\|\nabla\ell\|_\infty\), the descriptive scaled score
\(\|\nabla\ell\|_\infty/(1+|\ell|)\), and profile curvature used in this
diagnosis.

## 3a. Decisions and Rejected Alternatives

**Decision:** `NO_REPAIR`.

**Rationale:** the 31 eligible same-objective boundary-polish calls all pass,
while 68 of the 69 recovery-pass/raw-gradient holds have no boundary flag and
the remaining one is ineligible.  A broader retry is not evidenced by the
retained campaign and would be a new estimator.

**Rejected alternatives:** lowering the raw-gradient threshold, treating the
objective-scaled gradient as a convergence certificate, rerunning the same
campaign, extending the boundary polish to `b_fix`/`theta_rr_B`, or changing
the mandatory-polish rule.  Each would change a locked criterion or estimator.

**Confidence:** high for the descriptive all-attempt decomposition; limited
for any causal account of the untried non-boundary optimizer route.

## 4. Files Touched

- `dev/isdm-package-recovery/run-g2k-gradient-diagnostic.R`: read-only
  campaign validator/extractor and retained decomposition tables.
- `tests/testthat/test-g2k-gradient-diagnostic.R`: static no-fit contract.
- `dev/isdm-package-recovery/2026-08-12-g2k-gradient-diagnostic-certificate.md`:
  symbolic/numerical certificate and adversarial checks.
- `dev/isdm-package-recovery/2026-08-12-g2k-gradient-diagnostic-decision.md`:
  `NO_REPAIR` memo and frozen next protocol.
- `docs/dev-log/plan-actual/2026-08-12-g2k-gradient-diagnostic-reconciliation.md`
  and this report.

No reader-facing, generated, or exported file changed.  No example-file,
roxygen, Rd, README, NEWS, ROADMAP, design-document, vignette, or `_pkgdown.yml`
cascade applies.

## 5. Checks Run

```sh
Rscript --vanilla dev/isdm-package-recovery/run-g2k-gradient-diagnostic.R --mode=validate
# PASS: exact retained campaign identity, 150 ledgers, fit/profile/truth paths;
# exits before any objective construction or fit.

Rscript --vanilla dev/isdm-package-recovery/run-g2k-gradient-diagnostic.R \
  --mode=audit --output=dev/isdm-package-recovery/results/g2k-gradient-diagnostic-20260812-007
# PASS: fresh read-only diagnostic root produced.

Rscript --vanilla -e 'devtools::test(filter = "g2k-gradient-diagnostic", reporter = "summary")'
# PASS: 9 assertions.
```

The artifact summary records 150 attempts, 22 strict passes, 106 recovery
passes, 61 final raw-gradient passes, 89 raw-gradient failures, median raw
gradient `0.0016826153`, median descriptive scaled gradient
`2.4638879e-07`, median Hessian condition `4450.7277`, and median 4.5 weak
lower profile coordinates.

## 6. Tests of the Tests

The new test is a prophylactic no-fit contract: it would catch accidental
optimizer/objective construction or loss of the required raw/scaled-gradient,
Hessian, profile, and all-attempt tables.  The dynamic validator separately
checks campaign cardinality, exact source commit, and retained file paths;
neither check can pass by reading a partial campaign.

## 8. Consistency Audit

`rg "G2K_CALIBRATION_HOLD|NO_REPAIR|OPTIMIZER_REPAIR_CANDIDATE|NEW_DESIGN_REQUIRED" dev/isdm-package-recovery docs/dev-log`
found the new `NO_REPAIR` decision alongside, rather than replacing, the
historical `G2K_CALIBRATION_HOLD` records.

`rg "integrated_jsdm\\(|iJSDM|repeated-visit" README.md NEWS.md ROADMAP.md _pkgdown.yml vignettes`
found no new public capability claim.

`rg -n "gllvmTMB\\(" R vignettes README.md NEWS.md docs/design`
found only pre-existing package and article calls; this private diagnostic adds
no reader-facing model call.

## 9. What Did Not Go Smoothly

The fresh private worktree did not expose a writable temporary directory to
the sandbox.  A narrowly scoped permission was used only to create the
diagnostic's private temporary/output files.  It did not run a fit, simulator,
campaign, or external compute.  The first extractor version also needed to
represent ineligible polish records explicitly; the final evidence retains
that distinction instead of treating absent candidates as zeros.

## 11. Team Learning

**Ada:** a separate all-attempt extractor prevented a convenient but false
summary that attributes every strict hold to raw gradient alone.

**Gauss and Noether:** scaled gradients are descriptive because their
denominator is objective-dependent; raw AD gradients, parameter-block labels,
and the same-objective predicate must remain distinct evidence streams.

**Fisher:** weak lower profiles and condition-number tails support a
component-information limitation, but cannot prove a DGP/estimand redesign or
justify lowering an admission threshold.

**Curie:** the 31/31 successful eligible polish cases show a repair can be
successful locally while being irrelevant to the dominant all-attempt failure
mechanism.

**Rose:** the 15 raw-gradient-and-metric passes held by mandatory polish are a
frozen decision-rule interaction; reporting it separately is essential for a
future fair redesign discussion.

## 7a. Issue Ledger

**GitHub issue ledger:** Issue #953 was not inspected, altered, or updated by
scope.  `gh pr list --state open --limit 20` was attempted for the pre-edit
check but the GitHub API was unavailable; no issue action was required.

No relevant open issue; no new issue created.  The status inventory
(`README.md`, `NEWS.md`, `ROADMAP.md`, `docs/dev-log/known-limitations.md`,
`_pkgdown.yml`) is deliberately unchanged because the task added no advertised
capability.  **Roadmap tick:** N/A — no public roadmap status changed.

## 10. Known Residuals

This remains a fixed six-species, nonspatial, synthetic, relative-intensity
iJSDM diagnostic.  It validates neither empirical inference, detection,
spatial fields, public interface, count-survey outcomes, arbitrary sources,
absolute abundance, nor zero inflation.  The only next action is the
unapproved numerical-admission design protocol in the decision memo; it may
not refit, reclassify G2k, or launch compute without explicit approval.

## 12. Cross-Product Coverage

This audit covers only the frozen six-species, nonspatial, GBIF-Poisson plus
three-visit PA-cloglog route, its rank-one Lambda/free-diagonal Psi map, and
the retained G2k numerical-admission records.  It does NOT cover a changed
optimizer, alternate starts/tolerances, a different parameter map, detection
estimation, spatial mesh fields, empirical data, count-survey outcomes,
additional sources, public API/docs, or any recovery campaign under a revised
admission rule.
