# After Task: Design 98 factorial VA/JJ technical incomplete

**Branch**: `codex/design98-factorial-va-jj-20260724`
**Date**: 2026-07-24
**Roles (engaged)**: Ada, Gauss, Noether, Fisher, Rose, Grace

## 1. Goal

Build and execute one private, reproducible q=2 Bernoulli-logit factorial
discriminator that separates direct Gaussian ELBO versus JJ-bound behavior
and diagonal versus full variational posterior covariance, using deterministic
tensor Gaussian-Hermite marginal references.

## 2. Implemented

Design 98 adds a private R/C++ numerical core, exact parameter packers,
normalized GH oracle, deterministic fixtures, three frozen starts, a
failure-resilient 52-task supervisor, exclusive-create telemetry, provenance
inventories, a retained non-evidence invocation smoke, and one immutable real
result packet.

The real packet aggregated operationally but its scientific decision is
`TECHNICAL_INCOMPLETE`. QD, QF and JD were comparable. Low and high GH
references, fixed-global contrasts and JF were unavailable, so no mechanism
label is authorized.

## 3. Mathematical Contract

For

\[
Y_{it}\sim\operatorname{Bernoulli}\{
\operatorname{logit}^{-1}(\beta_t+\lambda_t^\top u_i)\},\qquad
u_i\sim N_2(0,I_2),
\]

the four private objectives are

\[
\{\text{QD},\text{QF},\text{JD},\text{JF}\}
=
\{\text{direct ELBO},\text{JJ bound}\}
\times
\{\text{diagonal }S_i,\text{full }S_i\}.
\]

Full \(S_i=L_iL_i^\top\) uses a positive-diagonal lower-triangular
Cholesky factor; diagonal geometry fixes the strict-lower entry to zero.
The global loading matrix uses a positive lower-triangular leading block.
All common-scale comparisons use the retained 61-node two-dimensional tensor
GH reference.

This is not a package likelihood, public inference method, `dep()` covariance,
\(\Psi\), EVA implementation, phylogenetic/SPDE estimator, recovery campaign,
or package-admission claim. No public R API, package TMB likelihood, formula
grammar, family, NAMESPACE, generated Rd, vignette or pkgdown navigation
changed.

## 3a. Decisions and Rejected Alternatives

- **Decision:** use the full 2×2 objective-by-geometry factorial.
  **Rationale:** GH versus JJ alone cannot identify mean-field geometry.
  **Rejected:** interpreting Design 97 retrospectively.
  **Confidence:** high.
- **Decision:** make every optimizer phase a separately supervised worker.
  **Rationale:** one worker failure must not erase sibling evidence.
  **Rejected:** another one-shot scientific runner.
  **Confidence:** high.
- **Decision:** retain `TECHNICAL_INCOMPLETE`.
  **Rationale:** both GH anchors and JF were unavailable; fixed contrasts were
  dependency-blocked.
  **Rejected:** using attractive raw JF accuracy, changing H, loosening the
  gradient gate, or adding a start.
  **Confidence:** high.
- **Decision:** close Design 98 rather than repair it.
  **Rationale:** fixtures, starts, thresholds and one-shot UUID are immutable.
  **Rejected:** replay, rescore or second root.
  **Confidence:** high.

## 4. Files Touched

- `docs/design/98-factorial-va-jj-discriminator.md`: prospectively reviewed
  contract.
- `dev/design98-factorial-va-jj/R/`: oracle, fitting, fixture, provenance,
  record, supervisor and task-plan modules.
- `dev/design98-factorial-va-jj/src/`: two private TMB templates.
- `dev/design98-factorial-va-jj/*.R`: gate, fault, adjudication, worker,
  smoke, finalizer and one-shot execution scripts.
- `dev/design98-factorial-va-jj/results/`: one `REAL_RUN.json`, one 20-MB
  UUID packet, 52 inputs, 52 terminal records, 44 payloads, 44 launches,
  88 captured logs, two fixtures, retained toy records and aggregate
  summaries.
- `docs/dev-log/plan-actual/2026-07-24-design98-factorial-va-jj.md`:
  reconciliation.
- `docs/dev-log/handover/2026-07-24-codex-handover-design98.md`: immutable
  terminal handover.
- `docs/dev-log/check-log.md` and this report: closeout records.

No README, NEWS, ROADMAP, known-limitations, validation-debt, roxygen, manual,
article, example, package source or package test file changed.

## 5. Checks Run

```sh
Rscript --vanilla dev/design98-factorial-va-jj/run-gate0-provenance.R
Rscript --vanilla dev/design98-factorial-va-jj/run-gate1-tests.R
Rscript --vanilla dev/design98-factorial-va-jj/run-fault-tests.R
Rscript --vanilla dev/design98-factorial-va-jj/run-fit-worker-tests.R
Rscript --vanilla dev/design98-factorial-va-jj/run-adjudication-tests.R
Rscript --vanilla dev/design98-factorial-va-jj/run-toy-smoke.R \
  --execute --fit-worker \
  /private/tmp/gllvmtmb-design98-factorial-va-jj/dev/design98-factorial-va-jj/fit-worker.R
Rscript --vanilla dev/design98-factorial-va-jj/run-design98.R
git diff --check
git diff 7a725c5e -- src R man NAMESPACE DESCRIPTION inst vignettes \
  README.md NEWS.md _pkgdown.yml
git diff 7a725c5e -- \
  docs/design/72-variational-approximation-feasibility.md \
  docs/design/85-highdim-nongaussian-va-formal-contract.md \
  dev/design95-free-jj-va dev/design96-jj-recovery dev/design97-fullcov-jj
```

Outcomes:

- Gate 0 provenance and fixture checks: PASS.
- Gate 1: objective error at most `1.78e-15`; relative gradient error at most
  `2.66e-9`; PASS.
- Fault suite: all nine retained supervision/failure cases PASS.
- Fit-worker mechanics and adjudication tests: PASS.
- Canonical Gate-3 smoke: PASS, 52/52 terminal, zero infrastructure failures.
- Real packet: 52/52 terminal; `TECHNICAL_INCOMPLETE`.
- Package/public and prior-design diffs: empty.

Three independent completion reviews passed the packet only as an honest
terminal incomplete result. The mathematics/inference review rejected every
mechanism claim; the scope/provenance review confirmed the private boundary;
and the mechanical review rechecked all 52 input-file hashes, terminal input
hashes, 44 payload hashes, 88 stdout/stderr hashes, eight zero-launch
dependency blocks, fixture hashes, and prior baseline/final inventories.

Full `devtools::test()`, documentation, pkgdown and package check were not run
because no package path, API, roxygen, example, vignette or package test
changed. Compilation was confined to temporary copies of the two private TMB
templates.

## 6. Tests of the Tests

- Failure-before-fix: the all-terminal evaluator test caught the original
  behavior in which one unhealthy sibling blocked adjudication.
- Boundary cases: crash, timeout, malformed JSON, partial JSON, duplicate
  payload, parent interruption, orphan resume and duplicate real-run lock.
- Failure-before-fix: the adjudication test caught use of a healthy payload
  whose authoritative terminal was unhealthy.
- Feature combination: the 52-node smoke exercised GH, all four variational
  methods, phase dependencies, evaluators, finalizer and immutable telemetry.
- Prophylactic: pack/unpack, SPD, GH moments and invariant tests protect the
  new private numerical contract.

## 8. Consistency Audit

Exact scans:

```sh
rg -n "Design 98|TECHNICAL_INCOMPLETE|MEAN_FIELD_SIGNAL|JJ_SIGNAL|GAUSSIAN_OR_GLOBAL_SIGNAL|NESTED_FIXTURE_INFORMATION_SIGNAL" \
  docs/design/98-factorial-va-jj-discriminator.md \
  docs/dev-log/plan-actual/2026-07-24-design98-factorial-va-jj.md \
  docs/dev-log/after-task/2026-07-24-design98-factorial-va-jj-technical-incomplete.md \
  docs/dev-log/handover/2026-07-24-codex-handover-design98.md \
  dev/design98-factorial-va-jj
rg -n "EVA|q4|q6|phylo|SPDE|public|package" \
  docs/design/98-factorial-va-jj-discriminator.md \
  docs/dev-log/plan-actual/2026-07-24-design98-factorial-va-jj.md \
  docs/dev-log/after-task/2026-07-24-design98-factorial-va-jj-technical-incomplete.md \
  docs/dev-log/handover/2026-07-24-codex-handover-design98.md
```

Verdict: the first scan keeps the terminal label and four unavailable
mechanism labels consistent across contract, code and closeout. The second
finds only explicit exclusions and scope boundaries, not advertised package
capabilities.

The package-wide stale-wording and example scans are N/A: no user-facing
prose, roxygen, parser, article or example changed. Historical Design notes
were not mechanically rewritten.

## 7. Roadmap Tick

N/A. Design 98 is private research and changed no `ROADMAP.md` row or public
status.

## 7a. Issue Ledger

`gh issue list --state open --limit 100 --json number,title` was inspected.
No open issue concerns this private Design-98 discriminator; no issue was
commented, closed or created. Roadmap and package capability issues remain
unchanged.

## 9. What Did Not Go Smoothly

The initial contract needed two review rounds before it became executable.
The first supervisor design also made evaluation dependencies too strict.
Both were fixed before the real lock.

The predeclared local-versus-Totoro benchmark decision was not executed before
high-GH work. High phase-1 tasks later took about 11 minutes locally. They were
not migrated after launch because that would replay immutable attempts. Future
designs should make compute routing a separate pre-lock gate.

Scientifically, H31 optimization moved the low GH fits into a basin with
`epsilon_GH` around `0.791` and 61-node gradients above `6`; all high GH
BFGS endpoints missed `<1e-4`. JF point estimates looked accurate but every
start missed its gradient gate. None was promoted.

## 11. Team Learning

**Ada:** decomposed the work into contract, numerical core, supervision,
fixture/provenance, smoke, evidence and closeout. The most important
orchestration correction was refusing to let a worker failure terminate
independent siblings.

**Gauss:** verified objective signs, Cholesky transforms, stable JJ zero
branch, GH normalization and fixed-contrast algebra. The review prevented
mechanism labels from using terminal-invalid payloads.

**Noether:** forced exact loading-coordinate order, deterministic healthy-start
selection, endpoint-summed quadrature uncertainty and directed accuracy
transitions before compilation.

**Fisher:** distinguished stable single-fixture endpoints from mechanism
evidence. QF's small common-scale advantage and JD's pointwise accuracy are
descriptions, not causal conclusions.

**Rose:** required the one-shot lock, full source/input/fixture provenance,
all-terminal evaluation policy, byte-identical predecessor inventories and
honest `TECHNICAL_INCOMPLETE` closeout.

**Grace:** the retained packet has one UUID, 52 immutable inputs and terminals,
matching hashes, no retry/overwrite, and no package or CI surface. The missed
pre-run compute-routing benchmark is the main reproducibility-process lesson.

## 10. Known Residuals

Design 98 does not identify finite-information, mean-field, JJ, or
Gaussian/global mechanisms. It does not establish recovery, calibration,
coverage, EVA/VA admission, q4/q6 behavior, structured priors, long-format
mapping, package integration or public capability.

One bounded descriptive record survives: on this single low fixture, QD, QF
and JD were stable; QF's 61-node log-marginal was `0.0052997403` above QD,
while both failed the covariance-error accuracy threshold; JD met the three
pointwise thresholds. This must not be generalized or attributed.

Next action: none within Design 98. Any different GH optimization order,
optimizer health rule, additional start, JF repair, or renewed mechanism study
requires a separately approved new design with new fixtures, inputs,
thresholds and UUID.

## 12. Cross-Product Coverage

Design 98 covers only one private q=2 Bernoulli-logit, intercept-only,
single-fixture factorial and its retained low/high GH, fixed-global, and
free-global task graph. It does NOT cover repeated-fixture recovery,
calibration, coverage, q4/q6, covariates, other response families, structured
priors, long-format package mapping, public APIs, package TMB integration,
EVA parity, or any downstream extractor, prediction, uncertainty, profiling,
documentation, or release surface.
