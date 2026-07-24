# After Task: Design 99 exact q=2 reference stabilization

**Branch**: `codex/design99-exact-reference-20260724`  
**Date**: 2026-07-24  
**Roles engaged**: Ada, Jason, Gauss, Noether, Curie, Fisher, Grace, Rose, Shannon

## 1. Goal

Design 99 attempted to establish a private, bounded q=2 Bernoulli-logit
adaptive Gaussian--Hermite reference. Admission required a fresh provenance
chain, independently checked quadrature algebra, failure-resilient execution,
and one immutable information ladder. The design ended
`INFRASTRUCTURE_INCOMPLETE`; it did not establish the reference.

## 2. Implemented

The branch contains a private pure-R research implementation of stabilized
numerical helpers, response-pattern-compressed adaptive quadrature, direct
original-\(u\) integration comparators, two loading charts, three starts, two
optimization routes, deterministic fixture construction, immutable records,
a 208-task graph, worker supervision, and fail-closed adjudication.

The 732-row predecessor inventory remained byte-identical, with aggregate
SHA-256
`0b8910908bd9b89a21994f008f806a2e973005fc69ae1d39e5b88396c6b64531`.
The runtime scanner found no predecessor runtime dependency, symlink, or new
C/C++ source. The real-run preparation path exists but was never invoked.

The terminal non-evidence receipt records that the strict independent-oracle
mechanical gate did not create its required terminal receipt. No approved
fixture, real UUID, real lock, optimization, or information-ladder run exists.

### Mathematical contract

For a binary response pattern \(y\), the private target is

\[
h_y(u;\theta)=\sum_{t=1}^{6}
\{y_t\eta_t-\log(1+\exp\eta_t)\}
-\tfrac12u^\top u-\log(2\pi),\qquad
\eta_t=\beta_t+\lambda_t^\top u.
\]

The adaptive rule uses the conditional mode, the positive-definite curvature
\(Q_y\), and \(A_yA_y^\top=Q_y^{-1}\). The implementation keeps the
finite-rule derivative distinct from the integrated Fisher score and
adjudicates only \(\beta\), \(\Lambda\Lambda^\top\), and marginal
probabilities across loading charts.

No public R API, package likelihood, formula grammar, family, C++ engine,
NAMESPACE, generated Rd, vignette, README, NEWS, or pkgdown navigation
changed. The private implementation is not an admitted exact reference.

## 4. Files Touched

Design and reconciliation:

- `docs/design/99-exact-q2-reference-stabilization.md`
- `docs/dev-log/plan-actual/2026-07-24-design99-exact-reference.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-24-design99-exact-reference.md`

Private numerical implementation:

- `dev/design99-exact-reference/R/aghq.R`
- `dev/design99-exact-reference/R/charts.R`
- `dev/design99-exact-reference/R/fixture.R`
- `dev/design99-exact-reference/R/independent-oracle.R`
- `dev/design99-exact-reference/R/numerics.R`
- `dev/design99-exact-reference/R/optimizers.R`
- `dev/design99-exact-reference/R/records.R`
- `dev/design99-exact-reference/R/task-graph.R`

Private execution:

- `dev/design99-exact-reference/scripts/benchmark-non-evidence.R`
- `dev/design99-exact-reference/scripts/cell-evaluator.R`
- `dev/design99-exact-reference/scripts/finalize.R`
- `dev/design99-exact-reference/scripts/fit-worker.R`
- `dev/design99-exact-reference/scripts/freeze-fixture.R`
- `dev/design99-exact-reference/scripts/n-evaluator.R`
- `dev/design99-exact-reference/scripts/oracle-worker.R`
- `dev/design99-exact-reference/scripts/preflight.R`
- `dev/design99-exact-reference/scripts/prepare-real-run.R`
- `dev/design99-exact-reference/scripts/run-mechanical-gates.R`
- `dev/design99-exact-reference/scripts/run-real-graph.R`
- `dev/design99-exact-reference/scripts/supervise.R`

Tests and terminal record:

- `dev/design99-exact-reference/tests/test-gate-orchestration.R`
- `dev/design99-exact-reference/tests/test-gate1-charts.R`
- `dev/design99-exact-reference/tests/test-gate1-numerics.R`
- `dev/design99-exact-reference/tests/test-gate2-optimizer.R`
- `dev/design99-exact-reference/tests/test-gate3-infrastructure.R`
- `dev/design99-exact-reference/tests/test-gate3-runtime-wiring.R`
- `dev/design99-exact-reference/results/non-evidence/gate3-infrastructure-incomplete.json`

Provenance:

- `dev/design99-exact-reference/provenance/baseline-protected-inventory-summary.json`
- `dev/design99-exact-reference/provenance/baseline-protected-inventory.tsv`
- `dev/design99-exact-reference/provenance/borrowed-pattern-provenance.md`
- `dev/design99-exact-reference/provenance/generate-protected-inventory.py`
- `dev/design99-exact-reference/provenance/manifest-and-allowlist-specification.md`
- `dev/design99-exact-reference/provenance/prior-work-sweep.md`
- `dev/design99-exact-reference/provenance/protected-paths.json`
- `dev/design99-exact-reference/provenance/scan-design99-runtime.py`
- `dev/design99-exact-reference/provenance/test-generate-protected-inventory.py`

No package example or public status-inventory file changed.

## 3a. Decisions and Rejected Alternatives

The design stopped when the strict independent-oracle process lacked a
terminal receipt after a bounded 2,700-second run. Replacing the comparator,
raising the timeout after observing the run, freezing the real fixture anyway,
or treating unit tests as Gate-1 evidence were rejected because each would
change the one-shot contract after evidence was visible. Confidence is high
that `INFRASTRUCTURE_INCOMPLETE` is the honest terminal label; no numerical
diagnosis is claimed.

## 5. Checks Run

The following bounded suites passed:

```sh
Rscript --vanilla dev/design99-exact-reference/tests/test-gate1-numerics.R
# 100 expectations passed in 12 test contexts
Rscript --vanilla dev/design99-exact-reference/tests/test-gate1-charts.R
# PASS, synthetic NON_EVIDENCE only
Rscript --vanilla dev/design99-exact-reference/tests/test-gate2-optimizer.R
# PASS, synthetic NON_EVIDENCE only
Rscript --vanilla dev/design99-exact-reference/tests/test-gate3-infrastructure.R
# 24 expectations passed in four contexts
Rscript --vanilla dev/design99-exact-reference/tests/test-gate3-runtime-wiring.R
# 15 expectations passed in two contexts
Rscript --vanilla dev/design99-exact-reference/tests/test-gate-orchestration.R
# 45 expectations passed in five contexts
python3 dev/design99-exact-reference/provenance/test-generate-protected-inventory.py
# four tests passed
python3 dev/design99-exact-reference/provenance/scan-design99-runtime.py --scope lane
# PASS; no findings
python3 dev/design99-exact-reference/provenance/generate-protected-inventory.py compare --scope lane
# PASS; 732 rows, protected digest unchanged
git diff --check
# PASS
git diff 7ca5da1c -- src R man NAMESPACE DESCRIPTION inst vignettes README.md NEWS.md _pkgdown.yml
# empty
```

The strict non-evidence command was:

```sh
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 \
Rscript --vanilla dev/design99-exact-reference/scripts/run-mechanical-gates.R \
  --output-root /private/tmp/d99-mechanical.WpLWgH
```

Its first launch failed before a receipt because a generated child expression
contained locale-sensitive curly quotes. After repairing the quoting, the
strict independent-integration stage ran silently until the 2,700-second
operator cutoff and was interrupted. It produced no terminal receipt. It was
not rerun.

Package-wide tests, documentation generation, pkgdown, and `R CMD check` were
not run because package paths did not change and the private design stopped
before producing admissible numerical evidence.

## 6. Tests of the Tests

Negative tests cover malformed and partial JSON, duplicate exclusive-create
outputs, bad graph dependencies, worker crash, timeout, interruption, orphan
reconciliation, sibling failure, invalid real-run locks, source-hash mismatch,
fixture-hash mismatch, and prohibited predecessor runtime references.

The provenance tests mutate temporary path, prefix, and ancestry conditions and
verify fail-closed rejection. The runtime scanner's negative fixtures
previously rejected a predecessor source dependency, prohibited C/C++, and a
symlink escape. The infrastructure test initially lacked its own
`library(testthat)` declaration and assumed one working directory; direct
execution exposed the fault. The test was made standalone, then passed from the
repository root.

Synthetic acceptance tests remain `NON_EVIDENCE`. They show that guards can
accept well-formed artificial records; they do not substitute for the missing
strict independent-oracle receipt.

## 8. Consistency Audit

```sh
rg -n "NOT_IMPLEMENTED|TODO|FIXME" dev/design99-exact-reference
```

Verdict: no unfinished placeholder was found.

```sh
rg -n "BOUNDED_ORACLE_PASS|INFRASTRUCTURE_INCOMPLETE|real_uuid|REAL_RUN" \
  docs/design/99-exact-q2-reference-stabilization.md \
  docs/dev-log/plan-actual/2026-07-24-design99-exact-reference.md \
  dev/design99-exact-reference
```

Verdict: positive labels occur in the prospective contract, code vocabulary,
and synthetic acceptance tests; the actual reconciliation and terminal receipt
state `INFRASTRUCTURE_INCOMPLETE` and record that no real UUID or lock exists.

```sh
rg -n "dev/design98-factorial-va-jj|20260724T161436-30841-62d0004f" \
  dev/design99-exact-reference --glob '!provenance/**'
```

Verdict: no predecessor path or UUID occurs in executable Design-99 runtime
files outside the provenance quarantine.

```sh
git diff 7ca5da1c -- src R man NAMESPACE DESCRIPTION inst vignettes \
  README.md NEWS.md _pkgdown.yml
```

Verdict: empty; no package or public surface changed. The convention-change
cascade, rendered-Rd check, validation-debt register, and public capability
inventory are therefore not applicable.

## 7. Roadmap Tick

N/A. No `ROADMAP.md` row or public capability status changed.

## 7a. Issue Ledger

`gh issue list --state open --limit 30` and `gh pr list --state open`
were attempted during closeout, but the GitHub API was unreachable. No issue
was inspected, commented, closed, or created. Design 99 is a local-only private
research lane and does not change a tracked public capability.

## 9. What Did Not Go Smoothly

The first strict launch exposed a quoting error that the synthetic orchestration
suite had not caught. The corrected independent-oracle stage then provided no
pattern-level progress or terminal record for 45 minutes. The contract defined
the 45-minute threshold for routing a projected real run, not for the
mechanical gate itself; using it as an operator cutoff was an adaptive safety
decision and is recorded as a plan deviation.

Early implementation reviews also caught an untracked Newton fallback,
insufficient oracle error propagation, incomplete endpoint certification,
weak run-identity checks, and accidental package-root files. These were
repaired before the strict gate, and the package-root files were removed.

## 11. Team Learning

**Ada** kept the decisive ordering intact: provenance and mechanics precede a
real fixture. When the strict gate lacked its receipt, Ada stopped the design
instead of converting implemented code into an admission claim.

**Jason** pinned predecessor and conceptual-source provenance. This prevented
the new runtime from sourcing or executing quarantined Design-98 code.

**Gauss and Noether** separated adaptive finite-rule derivatives from the
integrated score, required both chart invariants, and removed a Newton fallback
that did not satisfy the stated line-search contract.

**Curie and Grace** forced immutable task inputs, exclusive terminal records,
failure injection, fixed compute routing, and a non-evidence root. The silent
strict gate shows that future designs also need prospectively timed,
pattern-level progress records for expensive oracle work.

**Fisher** held the inference boundary: unit and synthetic tests establish
mechanical behavior only. Without the independent-oracle receipt and real
information ladder, no stability, identification, recovery, or optimizer
conclusion follows.

**Rose** required the negative facts to be durable: no fixture, UUID, lock,
optimization, or ladder. The prose review removed any implication that a large
private implementation equals a passed reference.

**Shannon** found a local, unpushed research branch and an unavailable GitHub
API. The handover must therefore declare the exact local worktree and commit;
it cannot imply the branch is fetchable from a remote.

## 10. Known Residuals

Design 99 is terminal and inspection-only. Its independent-oracle gate did not
produce a terminal receipt, so the numerical reference was never tested to the
contract's admission standard. No future task should rerun or repair Design 99.

If the maintainer wants to continue, the next work is a separately approved
Design 100. It should prospectively redesign the independent-oracle execution
with pattern-level heartbeats, explicit per-pattern and whole-gate timeouts,
bounded parallelism, and a dry-run cost benchmark before freezing a scientific
fixture. It must not begin another VA/JJ factorial unless a new exact-reference
design first passes.

## 12. Cross-Product Coverage

This arc covers only private, intercept-only, Bernoulli-logit, \(T=6\), \(q=2\)
research infrastructure and synthetic `NON_EVIDENCE` checks. It does NOT cover
an admitted exact reference, real-fixture numerical behavior, parameter
recovery, calibration, VA, JJ, EVA, other response families, other latent
dimensions, unit covariates, offsets, weights, missingness, structured priors,
package C++, the public R API, extractors, prediction, inference methods,
documentation, or package integration.
