# After Task: Design 101 private q=2 VA/JJ comparator

**Branch**: `codex/design100-progress-oracle-20260724`  
**Date**: 2026-07-24  
**Roles engaged**: Ada, Gauss, Noether, Curie, Fisher, Rose

## 1. Goal

Execute the maintainer-approved, single-fixture private comparison of QD, QF,
JD, and JF for a six-trait q=2 Bernoulli-logit model. The study must retain all
attempts, use one common marginal scale, and stop before EVA, a campaign,
package work, or a public claim.

## 2. Implemented

`dev/design101-va-jj-comparator/run-design101.R` freezes a fresh fixture and
one immutable result root, verifies fixed-coordinate objective/AD-gradient
finiteness, then performs exactly twelve planned fits (four methods by three
starts). Each endpoint has a no-overwrite JSON record; the terminal receipt and
summary remain available at
`/private/tmp/gllvmtmb-design101b-q2-comparator`.

The common endpoint scale is the same q=2 61-node Gaussian--Hermite marginal
log likelihood evaluated at each returned global coordinate. It is not the
variational objective and is not called a likelihood for QD/QF/JD/JF.

### Mathematical contract

All methods use \(u_i\sim N_2(0,I_2)\),
\(\eta_{it}=\beta_t+\lambda_t^\top u_i\), and the same identified two-column
loading chart. QD/QF optimize a direct Gaussian ELBO with diagonal/full local
covariance respectively; JD/JF optimize the corresponding Jaakkola--Jordan
bound. The shared evaluator integrates the Bernoulli-logit likelihood over the
same standard-normal q=2 latent distribution.

## 3. Files Changed

- `dev/design101-va-jj-comparator/PLAN.md`
- `dev/design101-va-jj-comparator/run-design101.R`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-24-design101-va-jj-comparator.md`

No package, public documentation, roxygen, generated Rd, NEWS, README,
vignette, or pkgdown file changed.

## 3a. Decisions and Rejected Alternatives

- **Decision**: run only QD/QF/JD/JF on one fresh fixture. **Rationale**: EVA
  lacks a frozen comparable objective, and the approved scope was one bounded
  execution. **Rejected alternative**: adding EVA or a second fixture after
  observing outcomes. **Confidence**: high.
- **Decision**: use a separate immutable root and source-fingerprint the
  reviewed private equation/template implementation. **Rationale**: it avoids
  reusing any prior fixture, task, record, or output root while retaining a
  tested q=2 numerical representation. **Rejected alternative**: running the
  Design-98 driver or any Design-99/100 root. **Confidence**: high.

## 4. Checks Run

```sh
Rscript --vanilla dev/design101-va-jj-comparator/run-design101.R
# PASS: compiled the private TMB template; pure-logic receipt passed; 12 records written.
jq '{status, healthy_count, best_common_scale_endpoint, retained_failures, attempts}' \
  /private/tmp/gllvmtmb-design101b-q2-comparator/summary.json
# complete_with_healthy_endpoints; 12 healthy; no retained failures.
Rscript --vanilla -e '... independent JSON readback of manifest, terminal, and records ...'
# PASS: 12 terminal records, all healthy.
git diff --check
# PASS.
rg -n -i 'EVA|package|public claim|campaign|Design-99|Design-100' \
  dev/design101-va-jj-comparator docs/dev-log/after-task/2026-07-24-design101-va-jj-comparator.md
# Scope fences only; no prohibited implementation path.
```

Package tests, `R CMD check`, documentation generation, pkgdown, Totoro/DRAC,
and a replicated campaign were not run: no package surface changed, and the
authorized study was deliberately one bounded local fixture.

## 5. Tests of the Tests

The pure-logic receipt is a deterministic fixed-coordinate boundary gate: each
method must return a finite objective and finite AD gradient before any fitting.
The independent readback requires the manifest, fixture, pure-logic receipt,
terminal receipt, exactly twelve records, and only declared terminal states.
Those checks would catch missing endpoint publication, malformed JSON, or an
attempt count/status mismatch. They are prophylactic integrity tests, not
scientific recovery tests.

## 6. Consistency Audit

The scope scan above found the explicit EVA/package/public/campaign fences in
the plan, runner, and report. `git diff --check` passed. The records identify
only QD, QF, JD, and JF, each crossed with A/B/C; no old fixture hash or old
result root appears in the new manifest or terminal receipt.

## 7. Roadmap Tick

N/A. This is a private design experiment and changes no published roadmap.

## 7a. GitHub Issue Ledger

No relevant open issue; no new issue created because the result is private,
single-fixture, and intentionally not a package capability claim.

## 8. What Did Not Go Smoothly

Nothing failed in the authorized run. The important constraint is conceptual:
the numerical separation is only a single-fixture observation, so it cannot
answer recovery, robustness, calibration, or estimator-selection questions.

## 9. Team Learning

**Gauss/Noether**: the common marginal evaluator must stay distinct from every
optimized variational/JJ objective. **Curie/Fisher**: three starts demonstrate
within-fixture endpoint stability here, not repeated-DGP performance. **Rose**:
immutable one-attempt records make the all-healthy outcome auditable without
concealing failures or retries.

## 10. Known Limitations And Next Actions

All results are private and limited to one `n = 24`, six-trait q=2 generated
fixture and one loading chart. EVA remains undefined/deferred. No public or
package conclusion follows. If the maintainer wants to go further, the next
decision is whether to pre-register a separate replicated recovery design and
route that new campaign to Totoro or DRAC; it must not silently extend this
root.
