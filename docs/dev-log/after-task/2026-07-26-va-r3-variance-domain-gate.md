# After Task: VA-R3 variance-domain gate measurement

## 1. Goal

Determine, privately and without widening the prototype, whether the frozen
`max_projected_variance <= 4` admission gate coincides with an observed
numerical failure.

## 2. Implemented

Added a private, executable multi-trial binomial-logit measurement runner under
`dev/va-variance-gate/`. It freezes four calibrated finite-fixture cells,
retains all starts and quadrature attempts, and refuses to produce an
ELBO--truth gap when the independent product-GH truth ladder is unstable.

## 3. Mathematical Contract

At fixed H61 VA coordinates, the runner evaluates
`ELBO = sum_i E_q[log p(y_i | u_i)] - sum_i KL(q_i || N(0, I))` at H15/H25/H61.
Independently, it evaluates the q=2 marginal integral with product
Gauss--Hermite at H151/H301/H501/H801. Truth is admitted only when the
predeclared H501-to-H801 difference is at most `1e-3`. This is a private
measurement harness: no public R API, likelihood, formula grammar, family,
NAMESPACE, generated Rd, vignette, or pkgdown navigation changed.

## 3a. Decisions and Rejected Alternatives

Kept the `<= 4` gate unchanged; rejected Bernoulli widening, AGHQ as a fallback
oracle, any Laplace-as-truth interpretation, adaptive post-hoc fixture retuning,
and a Totoro replication campaign. The instrument-boundary result does not need
replication; a future robustness claim would first need a stronger truth oracle.

## 4. Files Touched

- `dev/va-variance-gate/run-va-variance-gate.R`
- `dev/va-variance-gate/README.md`
- `dev/va-variance-gate/source-manifest.md`
- `dev/va-variance-gate/calibration-receipts/2026-07-26-post-calibration-cell-map.md`
- this report and `docs/dev-log/check-log.md`

Untouched by design: `NAMESPACE`, `DESCRIPTION`, `NEWS.md`, `README.md`,
`ROADMAP.md`, `R/`, `inst/tmb/`, `tests/`, `man/`, vignettes, and `_pkgdown.yml`.

## 5. Checks Run

- `Rscript --vanilla dev/va-variance-gate/run-va-variance-gate.R --smoke`:
  PASS. Observed variance 4.613715; truth tail spread `5.29e-11`; ELBO--truth
  `-0.7271131`; the calibrated band hit.
- `Rscript --vanilla dev/va-variance-gate/run-va-variance-gate.R --campaign`:
  PASS as a retained diagnostic packet. Observed bands 4/6/10/20 realized
  4.613715/5.987552/8.674338/22.190718. Product-GH truth is stable through
  8.674338 and uninterpretable at 22.190718 (H501-to-H801 `0.01636229`).
- `Rscript --vanilla -e 'parse(file = "dev/va-variance-gate/run-va-variance-gate.R")'`:
  PASS.
- Manifest recalculation smoke: PASS; calibration receipt SHA-256 bound in the
  output manifest as
  `4c3cf66914db44121f263a8cbd10426a023717eebf97077158427201e3b67d3e`.
- `git diff --check`: PASS.

Campaign RDS receipt SHA-256s remain local under `/private/tmp` per D-50:
`campaign.rds` `6f4c899587cd57454b3bd8cf5f174c76ce31229516a83a03246616c56d7bb64c`;
`attempts-and-results.rds` `f79c71cd5d6f29e923afc97596f53623976d8491e402b4c1fd36a1baf165e211`.

## 6. Tests of the Tests

The smoke is a boundary test: it proves an observed-band miss is retained and
cannot create a gate conclusion. The high-band campaign cell is the matching
instrument-failure test: its nonconvergent truth ladder is retained and leaves
`ELBO - truth` as `NA`, rather than silently averaging or dropping it.

## 7a. Issue Ledger

No issue was opened, closed, or commented on. `gh pr list --state open` was
attempted before the shared dev-log edits but could not reach `api.github.com`;
the maintainer handoff reported no open PRs. No tracker item is needed because
this closes a private measurement question without changing package scope.

## 8. Consistency Audit

Verbatim scans:

```sh
rg -n 'Bernoulli|n_trials = 1|AGHQ|NAMESPACE|DESCRIPTION|NEWS' dev/va-variance-gate
rg -n 'variational|VA|EVA|max_projected_variance|failed_variance_domain' README.md ROADMAP.md NEWS.md docs vignettes R
```

Verdict: the new private runner documents the Bernoulli and AGHQ exclusions;
the active public surfaces were not changed and no VA capability claim was
added. Status inventory and convention-change cascade are N/A because no public
syntax, API, documentation, or generated artefact changed. **Roadmap tick:**
N/A. **GitHub issue ledger:** no relevant open issue could be inspected because
`gh pr list` could not reach `api.github.com`; no issue was created or changed.

## 9. What Did Not Go Smoothly

The original nominal DGP targets did not yield the requested fitted projected
variances. All calibration attempts were retained locally; a post-calibration
cell map freezes the four realized finite fixtures. The high-variance truth
instrument then failed exactly where the handover predicted.

## 10. Known Residuals

The executable campaign receipt is intentionally local in
`/private/tmp/gllvmtmb-va-variance-gate-campaign-20260726/` and is not a
versioned package artefact. The current product-GH instrument cannot adjudicate
the calibrated high-variance cell. The private VA/EVA engine-spine branch also
retains its separate `jsonlite` merge blocker; this measurement arc neither
fixes nor worsens it.

## 11. Team Learning

**Curie** required retained calibration attempts and a truth-stability gate.
**Noether** independently passed the product-GH / fixed-coordinate construction
and limited the inference to stable truth rows. **Rose** found that the
calibration receipt had to be checksum-bound and confirmed that no replication
is warranted for this limited instrument-boundary closeout. **Ada** kept the
DO-NOT-MERGE Bernoulli lane and all public surfaces out of scope.

## 12. Cross-Product Coverage

Not applicable: this work adds neither a public user-facing convention nor a
cross-product package capability. `NAMESPACE`, `DESCRIPTION`, public examples,
Rd, vignettes, README, NEWS, ROADMAP, and `_pkgdown.yml` were inspected as
unchanged; no cascade is required. It does NOT cover REML, penalties, public
engine selection, missingness, aggregation, Bernoulli responses, structured
providers, random slopes, recovery, coverage, or any downstream public surface.

## Known Limitations

This is one calibrated realization per observed band, not a recovery,
robustness, performance, or threshold study. At observed 22.190718, both the
VA H25-to-H61 ladder (`4.39e-4`) and the truth tail ladder fail their respective
criteria. The result is an instrument boundary, not a proof of a universal
failure threshold. It does not admit VA/EVA, sparse binary support, Design 86,
or any public/release claim.

## Next Actions

Do not relax the `<= 4` gate. A future, separately approved robustness arc
would first need a high-variance truth oracle that itself converges, then a
replicated Totoro packet. Otherwise retain the private conclusion: no observed
break immediately at 4; evidence is stable through the calibrated 8.674 cell;
the current truth instrument is not adequate at 22.191.
