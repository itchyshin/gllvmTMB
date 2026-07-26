# After Task: HVT-1 private high-variance truth instrument

## Goal

Build, run, and close a private independent q=2 adaptive truth instrument for
the frozen complete multi-trial VA-R3 fixtures, returning either a certified
fixed-cell measurement or an honest unavailable-instrument result.

The pre-implementation frozen source base is `f2280081`; the preservation
commit is allowed as a descendant only when each frozen input hash remains
unchanged.

## Implemented

`dev/va-variance-gate/high-variance-oracle.R` independently evaluates the
per-unit binomial-logit / standard-normal q=2 integral by adaptive nested
integration.  It retains forward/reverse nesting and two affine coordinate
forms.  `run-high-variance-oracle.R` locks the old prototype inputs plus the
retained campaign RDS, extracts its retained best-H61 coordinates without a
refit, executes analytic/stable-reference/numerical checks, and writes a local
RDS/CSV packet.  The certification specification and source lock make the
admission and failure rules executable.

## Mathematical Contract

At frozen \(y,\hat\beta,\hat\Lambda\), HVT-1 computes
\(\sum_i\log\int_{\mathbb R^2}p(y_i\mid u_i,\hat\beta,\hat\Lambda)\phi_2(u_i)du_i\).
No public R API, likelihood, formula grammar, family, NAMESPACE, generated Rd,
vignette, or pkgdown navigation changed.  This does not change \(\Sigma_B =
\Lambda\Lambda^T\), fit a model, widen to Bernoulli, or relax the VA gate.

## Files changed

- `dev/va-variance-gate/high-variance-oracle.R`
- `dev/va-variance-gate/run-high-variance-oracle.R`
- `dev/va-variance-gate/hvt1-source-lock.md`
- `dev/va-variance-gate/hvt1-certification-spec.md`
- this report, the matching plan-vs-actual record, handoff, and check-log.

Status inventory / public examples / Rd / README / ROADMAP / NEWS / vignettes:
unchanged by design.  **Roadmap tick:** N/A — no public roadmap claim changed.

## Checks and results

- Parsed both new R scripts: PASS.
- Stable frozen band 4 packet: `TRUTH_CERTIFIED_ADAPTIVE`; all checks passed;
  its adaptive/H801 product-GH difference is `5.684342e-14`, its
  baseline/tightened difference is `1.065814e-13`, and its retained private
  H61 ELBO--truth is `-0.7271131`.
- Frozen band 20 packet: `TRUTH_UNINTERPRETABLE_ADAPTIVE`; baseline forward,
  reverse, and two affine routes agree at `-32.32363`, but tightened reverse
  integration fails.  Baseline-to-tightened total difference is
  `-3.630873e-12`, but the required tightened-route finiteness gate fails;
  `elbo_H61` and `elbo_minus_truth` are `NA`.
- `git diff --check`: PASS.

Raw packets are local only under `/private/tmp/hvt1-20260726-band4-final10/`
and `/private/tmp/hvt1-20260726-band20-final10/`; their `hvt1-result.rds`
SHA-256 values are respectively
`b03794a7513568bbd01f21805fde9c97edb5368a29fba4c76871a7a517cf1151`
and `f7076b4581d3f165d1abc0a68fdd4d4845339c9a8291dddd1d53354a61786e57`.

## Consistency audit

```sh
rg -n 'Bernoulli|AGHQ|Laplace|NAMESPACE|DESCRIPTION|NEWS|gllvmTMB\\(' \
  dev/va-variance-gate R/approximation-engine.R README.md ROADMAP.md NEWS.md docs vignettes
git diff --name-only origin/main...HEAD
```

Verdict: new files state the required exclusions; no public package surface is
in the diff.

## Tests of the tests

The zero-loading and effective-q1 anchors are boundary tests; their failure
would catch a missing Gaussian/Jacobian term or a dimension-reduction error.
The high-band tightened reverse route is a retained instrument-failure test:
it proves no gap is emitted when an adaptive route fails.

## What did not go smoothly

The original all-route implementation was slow enough to exceed the interactive
runner window.  The private oracle now parallelizes its ten independent units
locally (maximum 10 short processes) and uses explicit finite normal-tail
bounds, with a tighter, wider-tail rerun as the declared sensitivity check.
This changes no model calculation or public code.

## Team learning

**Gauss** implemented the independent log-stable adaptive evaluator; its key
lesson is that a joint-mode shift avoids repeatedly optimizing every inner
quadrature node.  **Curie's** fresh completion review found that the original
runner only recorded (rather than enforced) the campaign hash and omitted
several retained route checks.  The runner was corrected and both cells were
rerun before this report.  **Noether** then found regenerated-fixture and
shared-anchor defects; the final runner consumes the campaign's frozen fixture
and independently codes the analytic and q=1 anchors, followed by a second
rerun.  The final Curie review and final Noether review both passed; Curie
required an explicit forward/reverse agreement gate before that pass.  A fresh
Rose audit ran after a child-thread slot became available; it passed the
implementation/provenance evidence and identified two closeout-record wording
discrepancies, both reconciled in the preservation branch.

## Known limitations and next action

HVT-1 certifies the stable frozen cell only.  Band 20 remains
`TRUTH_UNINTERPRETABLE_ADAPTIVE`; it is not evidence about VA quality, a
universal variance threshold, sparse binary support, or Design 86.  The next
smallest scientific arc is a separately approved numerical-method comparison
for the high cell; do not launch Totoro replication until that instrument is
certified.

## GitHub issue ledger

`gh pr list` could not reach the GitHub API during orientation.  No relevant
open issue was verified, commented on, closed, or created; this private
instrument closeout creates no public tracker claim.
