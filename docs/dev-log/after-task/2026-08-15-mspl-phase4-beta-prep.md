# After Task: MSPL Beta Phase-4 prep (planned only)

**Branch**: `cursor/mspl-phase4-beta`
**Date**: `2026-08-15`
**Worktree**: `/private/tmp/gllvmtmb-mspl-phase4-beta`
**Roles (engaged)**: Ada / Curie / Rose

## 1. Goal

Land the isolated Beta (logit) LA-MSPL Phase-4 *prep* lane: copy the
already-written science from the shared worktree, add this lane’s
LOOP kit, re-run oracles, and open a stacked PR. Not admission.

## 2. Implemented

- Research note and E1–E9 oracles are byte-identical copies of the
  shared-worktree files. This lane did not rewrite the science.
- Lane LOOP kit under `docs/dev-log/lanes/cursor-mspl-phase4-beta/LOOP/`.
- No `beta:*` registry row. Prepare fence untouched. No C++.

## 3. Files Changed

- `docs/dev-log/research/2026-08-15-mspl-phase4-beta-prep.md` (copied)
- `tests/testthat/test-mspl-beta-phase4-oracles.R` (copied)
- `docs/dev-log/lanes/cursor-mspl-phase4-beta/LOOP/{GOAL,arcs,checkpoint,ultra-plan}.md`
- this after-task

## 3a. Decisions and Rejected Alternatives

Decision: copy sibling science; do not rewrite. Rationale: parent
instruction after the shared worktree already held a 65/65 oracle
file. Rejected: re-deriving a second Beta note on this worktree.

## 4. Checks Run

```sh
export OMP_NUM_THREADS=1 NOT_CRAN=true
cmp shared/docs/dev-log/research/2026-08-15-mspl-phase4-beta-prep.md \
    docs/dev-log/research/2026-08-15-mspl-phase4-beta-prep.md
cmp shared/tests/testthat/test-mspl-beta-phase4-oracles.R \
    tests/testthat/test-mspl-beta-phase4-oracles.R
# both identical

Rscript --vanilla -e 'pkgload::load_all(".", compile = FALSE, quiet = TRUE);
  testthat::test_file("tests/testthat/test-mspl-beta-phase4-oracles.R")'
# FAIL 0 | WARN 0 | SKIP 0 | PASS 65
git diff --stat -- src/ R/mspl.R R/mspl-registry.R
# empty
```

### Structured counts

| Block | Expectations |
|---|---|
| E1 Beta \(w(\mu,\phi)\) vs Bernoulli / Poisson | 7 |
| E2 \(\mu\to 0/1\): \(w\to 1\), \(P^*_{\mathrm{J}}\) finite | 10 |
| E3 Beta \(\ell\to-\infty\); Bernoulli all-zero finite | 10 |
| E4 near-boundary \(y\) intercept MLE | 5 |
| E5 \(\phi\to\infty\) | 5 |
| E6 \(\phi\to 0\) | 6 |
| E7 Hirose refused | 4 |
| E8 \(V_{\mathrm{loading}}\) inert | 7 |
| E9 \(I_{\eta\phi}\) orthogonality only at \(\mu=1/2\) | 6 |
| no live MSPL / no registry | 5 |
| **Total** | **65/65 PASS** (10 `test_that`) |

Not run: `devtools::test()`, `R CMD check`, Beta `estimator="mspl"`.

## 5. Tests of the Tests

Prophylactic oracles (no production defect). E2 would fail if
Bernoulli \(W_g\) were silently reused as a “coercive” Beta atom.
The no-live-fit block would fail if this file called
`estimator = "mspl"` or the registry.

## 6. Consistency Audit

```
rg -n "estimator\\s*=\\s*[\"']mspl[\"']" tests/testthat/test-mspl-beta-phase4-oracles.R
# no match (comments stripped in the test itself)
rg -n "admitted|prepare\\(\\)" docs/dev-log/research/2026-08-15-mspl-phase4-beta-prep.md
# admission language is FAIL / not-admitted only
```

Verdict: planned-only; no prepare widen.

## 7. Roadmap Tick

N/A — no `ROADMAP.md` row.

## 7a. GitHub Issue Ledger

No relevant open issue; no new issue created. This is planned-only
prep stacked on #971.

## 8. What Did Not Go Smoothly

A first pass on this worktree started a parallel Beta note. Parent
then pointed at the shared-worktree science (already 65/65). That
draft was discarded; files were copied.

## 9. Team Learning

**Ada.** Isolated worktree + explicit paths; do not rewrite a
sibling’s landed science.
**Curie.** Structured counts are 10 blocks / 65 expectations, not
an exit code.
**Rose.** No registry row, no NEWS covered, no `src/` / `R/mspl.R`.

## 10. Known Limitations And Next Actions

Mean-model Jeffreys is **not** coercive at \(\mu\to 0/1\) (E2).
Precision / loading atoms OPEN. Human merge only. HARD STOP:
admit, prepare widen, C++, SE, NEWS covered.
