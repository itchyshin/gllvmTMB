# After Task: LV Binomial Wald Local r500 Evidence

## Goal

Promote the Design 73 native binomial `latent(..., lv = ~ x)` Wald interval
campaign from launch-ready infrastructure to narrow local r500 evidence for
the three rank-1 multi-trial standard-link cells.

## Implemented

Ran the production-size local binomial grid for:

- `binomial-logit-d1-n160-t3`
- `binomial-probit-d1-n160-t3`
- `binomial-cloglog-d1-n160-t3`

Each cell attempted 500 fits with both `wald_z` and `wald_t_unit` summary
rows for the three trait-scale `B_lv` targets. All 1,500 fitted replicates
optimizer-converged, had positive-definite Hessians, had usable
`sdreport()` output, and remained eligible for CI summaries. All 18
target/method rows passed the 0.92--0.98 coverage band, with coverage
0.920--0.952 and MCSE 0.0096--0.0121.

The compact evidence artifacts are now committed under
`docs/dev-log/artifacts/lv-wald-coverage/`:

- `2026-06-30-local-binomial-r500-summary.csv`
- `2026-06-30-local-binomial-r500-excluded-replicates.csv`
- `2026-06-30-local-binomial-r500-t-vs-z.csv`
- `2026-06-30-local-binomial-r500-session-info.txt`

Design 73, Design 61, and validation-debt rows `FG-18`, `RE-13`, `EXT-31`,
and `LV-05` now cite the new binomial evidence. Rows `LV-01` and `LV-02`
remain Gaussian-only evidence rows.

## Mathematical Contract

The binomial cells use the same trait-scale target as the Gaussian coverage
campaign:

```text
u_i = X_lv,i alpha + e_i,    e_i ~ N(0, I_K)
B_lv = Lambda alpha'
```

For each trait, the simulated response is multi-trial binomial with one of the
three standard links: logit, probit, or cloglog. The fitted native TMB model is
the corresponding complete-response ordinary unit-tier model:

```r
cbind(success, failure) ~
  0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE, lv = ~ x)
```

The interval target is `B_lv`, not raw `alpha` or raw `Lambda`.

## Files Changed

- `docs/design/73-predictor-informed-latent-scores.md`
- `docs/design/61-capability-status.md`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/artifacts/lv-wald-coverage/2026-06-30-local-binomial-r500-summary.csv`
- `docs/dev-log/artifacts/lv-wald-coverage/2026-06-30-local-binomial-r500-excluded-replicates.csv`
- `docs/dev-log/artifacts/lv-wald-coverage/2026-06-30-local-binomial-r500-t-vs-z.csv`
- `docs/dev-log/artifacts/lv-wald-coverage/2026-06-30-local-binomial-r500-session-info.txt`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-30-lv-binomial-wald-local-r500.md`

No R API, formula grammar, roxygen, generated Rd, vignette, or pkgdown
navigation changed in this evidence-promotion slice.

## Checks Run

- Pre-edit lane check:
  `gh pr list --state open --repo itchyshin/gllvmTMB --json number,title,headRefName,updatedAt`
  -> PASS; `[]`.
- Pre-edit lane check:
  `git log --all --oneline --since="6 hours ago" -- docs/design/35-validation-debt-register.md docs/design/61-capability-status.md docs/design/73-predictor-informed-latent-scores.md docs/dev-log/check-log.md docs/dev-log/after-task`
  -> REVIEWED; only the current harness commit touched this lane.
- Three local production cell commands, run concurrently with
  `GLLVMTMB_LV_WALD_COVERAGE_CLI=true NOT_CRAN=true` and the local
  `R_LIBS` stack:
  `dev/lv-wald-coverage.R --mode=cell --cell=binomial-logit-d1-n160-t3 --n-reps=500 --seed-base=20260630 --interval-methods=wald_z,wald_t_unit --results-dir=/tmp/gllvmtmb-lv-binomial-r500-logit-20260630`;
  same for `binomial-probit-d1-n160-t3` into
  `/tmp/gllvmtmb-lv-binomial-r500-probit-20260630`; same for
  `binomial-cloglog-d1-n160-t3` into
  `/tmp/gllvmtmb-lv-binomial-r500-cloglog-20260630`.
  -> PASS; each cell completed 500/500 reps.
- Aggregate audit over the three `lv-wald-coverage-summary.csv` and
  `lv-wald-coverage-long.csv` outputs:
  -> PASS; 18 summary rows, all `production_n_reps_met = TRUE`, all
  `passes_coverage_band = TRUE`, 9,000 long rows, and 0 bad rows.
- Artifact extraction to
  `docs/dev-log/artifacts/lv-wald-coverage/2026-06-30-local-binomial-r500-*`
  -> PASS; wrote 18 summary rows, one header-only excluded-replicate CSV,
  nine t-vs-z comparator rows, and combined session info.
- `rg -n 'LV-05|binomial.*interval|local.*binomial.*r500|coverage artifact|coverage band|0\.920|0\.952|2026-06-30-local-binomial' docs/design/35-validation-debt-register.md docs/design/61-capability-status.md docs/design/73-predictor-informed-latent-scores.md`
  -> REVIEWED; expected evidence and artifact hits.
- `rg -n 'binomial.*(launch-ready|infrastructure only|not coverage evidence|no native binomial interval coverage|no calibrated native binomial)|native binomial.*(blocked|pending).*interval|500-rep.*binomial.*pending' docs/design/35-validation-debt-register.md docs/design/61-capability-status.md docs/design/73-predictor-informed-latent-scores.md NEWS.md`
  -> PASS; no stale launch-only binomial interval wording in live status docs.
- `rg -n 'native count-family.*(covered|validated|calibrated)|nonstandard binomial.*(covered|validated|calibrated)|ordinal.*lv.*(covered|validated|calibrated)|mixed-family.*lv.*(covered|validated|calibrated)|Julia.*(covered|validated|calibrated).*CI|calibrated Julia' docs/design/35-validation-debt-register.md docs/design/61-capability-status.md docs/design/73-predictor-informed-latent-scores.md NEWS.md`
  -> REVIEWED; broad hits were unrelated historical rows or rows that still
  keep broader non-Gaussian / Julia CI support gated.
- `rg -n 'gllvmTMB\(' R vignettes README.md NEWS.md docs/design | head -n 220`
  -> REVIEWED; no user-facing examples changed in this slice.

## Tests Of The Tests

No new test file was added. This slice exercised the existing coverage harness
at the production evidence tier. The summary audit would fail if the harness
silently dropped failed fits, counted ineligible rows as eligible, lost
link/trial metadata, or marked coverage as passed before the 500-rep threshold.
The header-only excluded-replicate artifact is part of the test: any future
fit, Hessian, `sdreport()`, or CI failure should create rows there.

## Consistency Audit

The implemented claim is narrow: native TMB binomial `latent(..., lv = ~ x)`
interval evidence is covered for the three rank-1 multi-trial standard-link
cells only. Validation-debt row `LV-05` remains partial because native
count-family support, nonstandard binomial links, ordinal rows, mixed-family
rows, response masks, source/tier expansion, Julia bridge intervals, and
broader CI-08 / CI-10 coverage remain gated.

No convention changed, so the AGENTS.md convention-change cascade did not
apply. No examples were added or edited.

## What Did Not Go Smoothly

One broad artifact-path replacement briefly added the binomial artifact to the
Gaussian-only `LV-01` and `LV-02` rows. The follow-up status scan caught it,
and those rows were corrected before this report.

## Team Learning

Fisher: the denominator audit matters as much as the coverage range. Here the
strong result is not just that coverage passed, but that all 1,500 fitted
replicates remained eligible.

Rose: artifact-path edits should be row-scoped when a register uses long
single-line table rows; global replacement is too blunt for evidence ledgers.

## Known Limitations

This is local r500 evidence, not 3-OS CI or merged-main evidence. It does not
cover native Poisson, NB1, NB2, Gamma, Beta, ordinal, nonstandard binomial
links, mixed families, response masks, source/tier-expanded `lv`, Julia bridge
intervals, or profile/bootstrap rescue.

The paired GLLVM.jl phylo-LV Model A blocker remains separate and is not
resolved by this gllvmTMB binomial interval slice.

## Next Actions

Commit this evidence slice, update mission control, and then choose the next
LV-arc bottleneck: phylo DRAC repair/evidence, bridge intervals, source/tier
expansion, or mixed-family backlog.
