# After Task: G2i deterministic-polish replacement smoke

## 1. Goal

Execute approved G2i S0--S6: reconcile G2h, implement and independently
review one private deterministic same-objective polish, run exactly one fresh
local six-species replacement smoke, inspect its retained artifacts, and return
with a recovery-pre-run packet rather than launching one.

## 2. Implemented

Fresh branch `codex/isdm-g2i-polish-recovery` began at immutable G2h closure
`88e329554c3688a93b696f0ead43a4aaeea4104d`.  Commit `a45411a7` adds a private
internal-iSDM-only final-polish path and the G2i runner/contract.  The runner
used a new SHA-bound root,
`dev/isdm-package-recovery/results/g2i-smoke-20260811-001`, once.  It returned
`G2I_SMOKE_COMPLETE` and `GEOMETRY_RESPONSIVE`.

G2h remains `G2H_SMOKE_HOLD`; G2i is a new estimator and does not rewrite G2h.
G2c remains `G2C_SMOKE_ADMISSION_HOLD`.

## 3a. Decisions and Rejected Alternatives

The ecological/observation model is unchanged:

\[
\eta_{cs}=\alpha_s+x_c\beta_s+z_c\lambda_s+e_{cs},\quad
Y^G_{cs}\sim\operatorname{Poisson}\{a^G_c\exp(\eta_{cs}+\delta_s+b_c\gamma_s)\},
\]

with three conditionally independent survey cloglog events sharing
`eta_cs`, rank-one `Lambda`, free diagonal `Psi`, and the GBIF-only bias gate.
The G2i estimator may perform one `nlminb` continuation from the raw outer
vector only when `1e-3 < max|g_raw| < 1e-2`, the sole flag is an unrelated
`near_zero_sd_B`, and the raw maximum is uniquely in `theta_rr_B`.  It accepts
only a same-map, same-boundary, finite PD candidate with non-worse objective
and `max|g_candidate| <= 1e-3`.

No public R API, likelihood, formula grammar, family, NAMESPACE, generated Rd,
vignette, pkgdown navigation, fixture, source gate, parameter map, or profile
coordinate changed.

## 4. Files Touched

- `R/fit-multi.R` — internal iSDM-only eligibility, acceptance, and immutable
  raw/candidate provenance helper.
- `tests/testthat/test-warm-nlminb-restart.R` — predicate, tie, boundary,
  provenance-restoration, and ordinary-fit scope tests.
- `dev/isdm-package-recovery/2026-08-11-g2i-polish-{contract,protocol,decision}.md`
  and `run-g2i-polish-smoke.R` — private frozen contract and one-attempt runner.
- Private ignored result root above, including `final-provenance-closure.rds`.

No reader-facing example, `README.md`, `NEWS.md`, `ROADMAP.md`,
`_pkgdown.yml`, or Issue #953 changed.

## 5. Checks Run

```sh
Rscript --vanilla -e 'devtools::test(filter="warm-nlminb-restart", reporter="summary")'
# PASS: focused compiled-unit suite; six existing heavy tests skipped by policy.

Rscript --vanilla dev/isdm-package-recovery/run-g2i-polish-smoke.R \
  --mode=validate --output=dev/isdm-package-recovery/results/g2i-validation-unused \
  --pkg=/private/tmp/gllvmtmb-isdm-g2i-polish-recovery
# PASS: G2I smoke wrapper validation PASS (no fit).

Rscript --vanilla dev/isdm-package-recovery/run-g2i-polish-smoke.R \
  --mode=smoke --output=dev/isdm-package-recovery/results/g2i-smoke-20260811-001 \
  --pkg=/private/tmp/gllvmtmb-isdm-g2i-polish-recovery \
  --campaign-sha=a45411a785973cab2dab05223c062589ef40d86c
# One run only: G2I_SMOKE_COMPLETE; GEOMETRY_RESPONSIVE.
```

All three restart rows were retained.  Six profiles had finite NLL and zero
convergence codes.  The GBIF-bias maximum error was `0.1149449`; three lower
profile deltas exceeded 2.  The raw retained gradient was `0.0012905340` in
`theta_rr_B[2]`; its sole boundary was `theta_diag_B[1] = -8.8723509`.  The
candidate preserved that boundary and map, reduced the final maximum gradient
to `0.0005347812`, and did not increase the objective beyond the frozen
floating tolerance.  The smoke elapsed about six minutes from root receipt to
terminal stage.

The core manifest hashes recomputed.  A final provenance closure receipt then
hashed the manifest and terminal receipt as well; it explicitly excludes only
itself from its own hash list.

## 6. Tests of the Tests

The new tests are boundary/failure tests: they reject non-iSDM fits, AGHQ,
ridge, non-PD/nonfinite states, every tied maximum involving `theta_diag_B`,
different/multiple boundary classes, changed map/index/value, objective
increase, and candidate gradients above `1e-3`.  They also prove a rejected
candidate retains its raw/candidate ledger and that ordinary package fits do
not receive the private field.  The latter is ordinary package regression
evidence, not a no-fit runner validation.

## 7a. Issue Ledger

Issue #953 was explicitly out of scope and was not inspected, commented,
created, or updated. No other issue was required for this private evidence lane.

## 8. Consistency Audit

`rg -n 'G2H|G2I|isdm.*polish|polish.*isdm' README.md ROADMAP.md NEWS.md docs/design docs/dev-log/known-limitations.md _pkgdown.yml dev/isdm-package-recovery`
found G2i only on private development surfaces; no public capability wording
was added.  `rg -n 'gllvmTMB\\(' R vignettes README.md NEWS.md docs/design`
was an inventory only; no public call syntax changed.  `git diff --check` and
the focused suite passed before committing the candidate.

**Roadmap tick**: N/A; this remains a private evidence lane.

## 9. What Did Not Go Smoothly

The first smoke command used an abbreviated SHA.  The wrapper rejected it
before creating a root or entering the optimizer.  The subsequent full-SHA
command was the sole smoke; its parent terminal returned while its profile
phase continued, so process and artifact checks were used rather than treating
the early empty terminal output as a verdict.  Independent review also found
the one-pass manifest omitted the terminal receipt; final closure hashes now
cover it without re-running the fit.

## 10. Known Residuals

This is one synthetic, nonspatial local admission smoke.  It is not a
multi-seed recovery campaign, detection extension, spatial analysis, empirical
fit, count-survey analysis, comparator result, abundance claim, zero-inflation
result, public API, or package documentation claim.

## 11. Team Learning

**Noether** rejected an initially missing ledger helper and a tied-gradient
admission gap; both became fail-closed unit tests.  **Curie** required ledger
retention across restoration and a private-scope guard, then caught the
terminal-receipt provenance gap.  **Fisher** independently confirmed the final
six-profile, three-restart, map/boundary, and gradient evidence.  **Rose's**
closure discipline separates this valid local admission smoke from recovery
evidence.

## 12. Cross-Product Coverage

G2i covers exactly one private, synthetic, six-species, 360-cell, nonspatial
GBIF-Poisson plus three-visit PA-cloglog admission smoke.  It does not cover
multi-seed recovery, spatial fields, repeated-visit detection parameters,
count-survey outcomes, other sources, empirical inference, absolute intensity,
zero inflation, comparator performance, or public workflows.

### Next Actions

S7 requires separate approval for one local recovery pre-run.  Its pre-run
packet should use the measured smoke time of about six minutes to declare a
representative seed/attempt, inspect non-empty recovery output, and estimate
the subsequently separate Totoro campaign.  No Totoro/DRAC action is approved
by this report.
