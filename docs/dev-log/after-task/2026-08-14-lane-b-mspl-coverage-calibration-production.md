# After Task: LA-MSPL fixed-effect coverage calibration production

**Branch:** `codex/lane-b-mspl-interval-feasibility`

**Date:** 2026-08-14/15 UTC

**Roles engaged:** Ada, Curie, Fisher, Gauss, Grace, Rose, Shannon

## 1. Goal

Run the frozen ordinary `q = 1` LA-MSPL coverage campaign across four regimes,
three links, and three resolved fixed-effect targets; promote only methods that
pass all 36 predeclared cells; otherwise retain an exact typed non-promotion
map and leave public inference fail-closed.

## 2. Implemented

The campaign completed 1,200 immutable shards: 12 Gate 4 shards plus 1,188
production shards. The exact aggregate contains 12,000 outer fits, 6,000,000
unconditional bootstrap attempts, 108,000 method-target endpoints, 1,159,993
profile-trace rows, and 108 summary cells. All outer fits succeeded. Every
bootstrap endpoint met the 475-of-500 usable-refit floor; five individual
bootstrap attempts retained `refit_optimizer_failed`.

The final joint gates were profile 24/36, bootstrap 20/36, and Wald 9/36.
Because no method passed 36/36, this task implemented the third planned
closure state: an exact non-promotion map. It did not enable a public method.

Compact claim-bearing evidence lives in
`docs/dev-log/simulation-artifacts/2026-08-14-mspl-coverage-calibration-production/`.
Raw shards and row-level aggregates remain outside Git on DRAC project storage.

### Mathematical contract

No public R API, likelihood, formula grammar, family, NAMESPACE, generated Rd,
vignette, or pkgdown navigation changed.

The data-generating mechanism remained

\[
z_i \sim N(0,1),\qquad
\eta_{it}=\beta_t+\lambda_t z_i,\qquad
Y_{it}\sim\operatorname{Bernoulli}\{g^{-1}(\eta_{it})\},
\]

with 24 sites, three traits, `q = 1`, four regimes, and logit, probit, or
standard cloglog. Profile fixed one `b_fix` coordinate and reoptimised every
nuisance coordinate against penalised `fit$tmb_obj` (`estimator_id = 1`).
Bootstrap simulated unconditional latent effects and responses and refit the
complete penalised MSPL estimator. Wald evaluated the penalty-off approximate
Laplace Hessian (`estimator_id = 2`) only at the penalised MSPL estimate; that
tape was not optimised, and non-positive-definite Hessians were not repaired.

Profile and bootstrap unavailable endpoints counted as noncoverage.
Availability needed to be at least 0.95, and the 90% Wilson coverage interval
needed to lie wholly inside `[0.92, 0.98]`. Wald needed at least 500 available
intervals and applied the same equivalence rule to conditional coverage.

## 3. Files Changed

- `docs/dev-log/plan-actual/2026-08-14-lane-b-mspl-coverage-calibration.md`
  — appended production execution, adjudication, and non-promotion actuals.
- `docs/dev-log/after-task/2026-08-14-lane-b-mspl-coverage-calibration-production.md`
  — this closeout.
- `docs/dev-log/check-log.md` — appended the exact production receipt and
  deliberate non-runs.
- `docs/dev-log/simulation-artifacts/2026-08-14-mspl-coverage-calibration-production/README.md`
  — compact evidence boundary and result.
- `docs/dev-log/simulation-artifacts/2026-08-14-mspl-coverage-calibration-production/SHA256SUMS`
  — compact artifact hashes.
- `case-summary.tsv`, `gate-map-108.tsv`, `joint-gate-failures-55.tsv`,
  `method-summary.tsv`, `production-receipt.txt`, and
  `resource-runtime-stop-resume-summary.txt` in the same artifact directory.

No implementation, test, exported documentation, example, NEWS, ROADMAP,
validation-register, or pkgdown file changed. The convention-change cascade is
not applicable.

## 3a. Decisions and Rejected Alternatives

**Decision:** Do not promote any MSPL interval method publicly from this
campaign.

**Rationale:** A route needed to pass all 36 frozen cells; profile passed 24,
bootstrap 20, and Wald 9. A passing subset was not sufficient under the frozen
gate.

**Rejected alternatives:** Exposing a method only for passing cells;
relabelling `calibration_gate_eligible: TRUE` as a method-level pass; repairing
non-positive-definite Wald Hessians with a pseudoinverse, eigenvalue clipping,
or nearest-positive-definite replacement; changing the profile grid or Wilson
gate after seeing results; and tuning then confirming on the same seeds.

**Confidence:** High. Two independent reviews reconstructed the statistical
and provenance receipts and reached the same non-promotion verdict.

## 4. Checks Run

Production acceptance:

- canonical shard ledger: 1,200 unique names, 100 per case, no missing or
  duplicate keys; all hashes passed;
- exact aggregate: 12,000 outer, 6,000,000 bootstrap, 108,000 endpoint,
  1,159,993 profile-trace, and 108 summary rows;
- production receipt SHA-256:
  `8232f1a847e6bfeb4626e6b55d033496743aa0e373284ad30a6432aeac277ea1`;
- summary SHA-256:
  `64b2776010b0f5af4b41d0f764d412853bd43a918fd758c4727ea854af991564`;
- shard-ledger SHA-256:
  `1cb6c667f9018784545646dcdda2183766758272e265848e80d1e27691f15fd1`;
- independent statistical and provenance reviews both passed the evidence and
  returned no public-promotion route.

Local verification:

```sh
Rscript --vanilla -e \
  'devtools::test(filter = "mspl", stop_on_failure = TRUE)'
# PASS: exit 0; focused MSPL tests retained the public refusal surface.

bash inst/sim/lane-b-uncertainty/mspl-coverage/contract-self-test.sh
# PASS: launcher-contract-self-test=PASS.

for file in inst/sim/lane-b-uncertainty/mspl-coverage/*.sh \
            inst/sim/lane-b-uncertainty/mspl-coverage/*.sbatch; do
  bash -n "$file" || exit 1
done
# PASS.

(cd docs/dev-log/simulation-artifacts/2026-08-14-mspl-coverage-calibration-production && \
  shasum -a 256 -c SHA256SUMS)
# PASS: all six retained compact evidence files.

git diff --check
# PASS.
```

`git diff -- R NAMESPACE man tests/testthat vignettes NEWS.md ROADMAP.md
_pkgdown.yml` returned empty. Static inspection confirmed the MSPL inference
guards remain at `confint.gllvmTMB_multi()`, `vcov.gllvmTMB_multi()`,
`profile_targets()`, `tmbprofile_wrapper()`, `bootstrap_Sigma()`, and
`standard_errors()`.

## 5. Tests of the Tests

The campaign runner's negative tests reject missing or duplicate keys, wrong
source SHA, stale manifests, mixed shard schemas, runtime drift, modified shard
bytes, and incomplete production cardinality. The launcher contract pairs
valid closed-schema Gate 3/Gate 4 receipts with malformed, unknown, duplicate,
missing, and wrong-hash cases. The production run itself exercised the
two-hour pending stop twice: each continuation had to prove that its exact
missing-key ledger was disjoint from all preserved immutable outputs before
submission. Existing MSPL API tests poison the penalty-off objective during
profile work and assert that every public inference route still refuses MSPL.

## 6. Consistency Audit

Exact searches:

```sh
rg -n 'calibrat|coverage|promotion|public|confidence interval|95%' \
  docs/dev-log/plan-actual/2026-08-14-lane-b-mspl-coverage-calibration.md \
  docs/dev-log/simulation-artifacts/2026-08-14-mspl-coverage-calibration-production/README.md

rg -n 'vcov\(\)|confint\(\)|profile_targets\(\)|tmbprofile_wrapper\(\)|bootstrap_Sigma\(\)|standard_errors\(\)' \
  R/mspl.R R/z-confint-gllvmTMB.R R/vcov-coef.R R/profile-targets.R \
  R/profile-ci.R R/bootstrap-sigma.R R/standard-errors.R \
  docs/dev-log/plan-actual/2026-08-14-lane-b-mspl-coverage-calibration.md \
  docs/dev-log/simulation-artifacts/2026-08-14-mspl-coverage-calibration-production/README.md

rg -n 'MSPL-04' docs/design/35-validation-debt-register.md
```

Verdict: every new calibration statement ends in blocked/no-promotion scope;
all six public functions still call the MSPL inference guard; `MSPL-04`
remains `blocked`. The prose review found no use of the 53 passing cells as a
partial public claim.

## 7. Roadmap Tick

N/A. No `ROADMAP.md` row changed. The plan-versus-actual file and compact
internal evidence were updated, while `MSPL-04` remains blocked.

## 7a. GitHub Issue Ledger

Issue #345 (first CRAN readiness) was inspected. It explicitly treats LA-MSPL
as separate from the bounded first-release claim and forbids broad interval-
calibration claims, so this task did not comment on or change that issue. No
issue was closed or created. GitHub PR listing was unavailable during the
pre-edit coordination check; local refs showed the separate Cursor Arc 1A
provenance work.

No reader-facing documentation changed because no method earned promotion.
`devtools::document()`, pkgdown, article rendering, and Rd spot checks are not
applicable because roxygen, Rd, articles, and public navigation did not change.

## 8. What Did Not Go Smoothly

Rorqual rejected creation of the fresh campaign root with `Disk quota
exceeded`; nominal inode headroom was not treated as writeability. The source
contract correctly refused an external routing edit, so a reviewed source
commit moved the exact same statistical keys to Nibi and Narval.

The read-only production monitor reported `pending_over_2h` twice at the
predeclared limit; the operator then cancelled the still-pending jobs. Exact-key
continuations made this operationally safe: valid shards remained immutable,
completion races became non-contiguous holes, and only absent keys were
resubmitted.

Local aggregation overran successive 8-, 20-, and 40-minute estimates. A
read-only benchmark identified a superlinear validator loop that repeatedly
filtered six million bootstrap rows for 36,000 endpoints, approximately 216
billion comparisons. The definitive Nibi aggregation used one CPU and 32 GB,
completed in 1:25:43, and peaked at 5.76 GiB RSS. Future campaigns should fix
and benchmark the validator before producing another six-million-row payload.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Ada:** The immutable-key continuation turned the two-hour queue rule into a
recovery mechanism rather than lost work. Future large arrays should plan the
continuation ledger from the beginning.

**Curie:** Exact ADEMP cardinality, unavailable-as-noncoverage, and retained
attempt failures prevented selective success. The next method study needs new
confirmation seeds, not gate tuning on this campaign.

**Fisher:** Independent reconstruction caught the crucial conditional-Wald
denominator. Unconditional Wald coverage would have produced the wrong joint
total. The final 53/108 is correct, but no method is broadly calibrated.

**Gauss:** The objective identities remained separated: penalised tape for
profile and bootstrap estimates, penalty-off tape only for paper-style
curvature at the penalised estimate. No pseudoinverse or Hessian repair entered
the evidence.

**Grace:** Cluster-native runtimes and source/manifest/launcher hashes kept the
Narval v3 and Nibi v4 environments separate. The aggregation estimate, rather
than fit runtime, was the main resource-planning miss.

**Rose:** Independent provenance review reconciled all row counts and failure
types and prevented `calibration_gate_eligible: TRUE` from being misread as a
method pass. Rose also keeps the 53 successful cells out of public prose.

**Shannon:** Lane preflight found an active Cursor MSPL provenance lane and a
recent `check-log.md` edit on its stacked branch. This lane changed only its
named coverage artifacts; GitHub PR lookup was temporarily unavailable during
the pre-edit check, so local all-ref history supplied the collision evidence.

## 10. Known Limitations and Next Actions

- This campaign covers selected complete-Bernoulli ordinary `q = 1` regimes,
  not arbitrary datasets, `q = 2`, structured effects, weights, or missing
  data.
- Finite interval construction remains feasible on the deterministic fixtures,
  but repeated-sampling calibration is regime- and target-dependent.
- Profile availability falls below 0.95 in two cells.
- Bootstrap is universally constructible here but fails coverage in 16 cells,
  including severe high-prevalence cloglog undercoverage.
- Wald retains 6,948 non-positive-definite endpoint failures and passes
  conditional coverage in only nine cells.
- The aggregation validator is too slow for convenient repeated confirmation.

Next actions:

1. Keep every public MSPL uncertainty and likelihood-comparison route
   fail-closed.
2. Repair the superlinear aggregate validator as a pure performance change and
   verify byte-identical summaries on this frozen 1,200-shard corpus.
3. Treat any statistical repair as a new method-design arc. Diagnose profile
   geometry and bootstrap under/overcoverage by mechanism, preregister changes,
   and use independent confirmation seeds. Do not tune gates or methods on the
   completed campaign.
4. Reconcile this branch with the separate Cursor provenance PR before any
   integration, because both append to `docs/dev-log/check-log.md` and touch
   adjacent MSPL tests on different branches.

## Appendix A. Cross-Product Coverage

This arc covers the product of four named regimes, logit/probit/cloglog, three
resolved `b_fix` targets, and three private interval candidates for complete-
Bernoulli ordinary `q = 1` fits. It also covers source/runtime provenance,
unconditional redraw, nuisance reoptimisation, non-positive-definite Wald
typing, availability, and repeated-sampling coverage within that product.

It does NOT cover arbitrary data regimes, other sample sizes or trait counts,
`q = 2`, spatial/phylogenetic/animal/kernel effects, weights, missingness,
loadings, covariance or latent-effect targets, derived quantities, likelihood
comparison, generic TMB profiling, calibrated standard errors, or a public
method subset. It also does NOT establish that a passing fixture cell can be
safely selected from a new fitted dataset.

## Appendix B. Legacy Validator Compatibility

The executable hub validator still checks the older section names below. These
are compatibility aliases only; substantive content remains in the canonical
sections above.

## 4. Files Touched

Compatibility alias for Section 3, **Files Changed**.

## 5. Checks Run

Compatibility alias for Section 4, **Checks Run**.

## 6. Tests of the Tests

Compatibility alias for Section 5, **Tests of the Tests**.

## 7a. Issue Ledger

Compatibility alias for Section 7a, **GitHub Issue Ledger**.

## 8. Consistency Audit

Compatibility alias for Section 6, **Consistency Audit**.

## 9. What Did Not Go Smoothly

Compatibility alias for Section 8, **What Did Not Go Smoothly**.

## 10. Known Residuals

Compatibility alias for Section 10, **Known Limitations and Next Actions**.

## 11. Team Learning

Compatibility alias for Section 9, **Team Learning**.

## 12. Cross-Product Coverage

Compatibility alias for Appendix A. The campaign does NOT cover arbitrary data
regimes or public MSPL inference; Appendix A records the full negative space.
