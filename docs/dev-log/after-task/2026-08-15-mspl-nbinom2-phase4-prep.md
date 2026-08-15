# After-task: MSPL nbinom2 Phase-4 prep (not admitted)

**Date:** 2026-08-15
**Lane:** `cursor/mspl-phase4-nbinom2`
**Worktree:** `/private/tmp/gllvmtmb-mspl-phase4-nbinom2`
**Branch:** `cursor/mspl-phase4-nbinom2` (stacked on #971 tip)

## 1. Goal

Land isolated-lane Phase-4 *prep* for nbinom2 LA-MSPL: the sibling
information/coercivity note, pure-R oracles, and this lane's LOOP
kit. Not admission. Not a registry flip.

## 2. Implemented

Science was copied from the shared point-continue worktree (not
rewritten). This lane re-ran the oracles and owns the LOOP kit,
after-task, and PR.

- Research note
  `docs/dev-log/research/2026-08-15-mspl-phase4-nbinom2-prep.md`
  (NB2 \(W=\mu\phi/(\phi+\mu)\); \(\operatorname{Var}=\mu+\mu^2/\phi
  \neq\mu\); mean / \(\phi\to 0\) / \(\phi\to\infty\) boundaries;
  kill list).
- Oracles
  `tests/testthat/test-mspl-nbinom2-phase4-oracles.R` (E1–E7 plus
  excluded-fence and no-live-fit; no `estimator="mspl"`).
- LOOP kit
  `docs/dev-log/lanes/cursor-mspl-phase4-nbinom2/LOOP/`.
- Registry: nbinom2 stays **`excluded`** / `fence`. No planned
  rows. Prepare fence unchanged (`family_id %in% {0,1}`).

## 3. Files Changed

- `docs/dev-log/lanes/cursor-mspl-phase4-nbinom2/LOOP/GOAL.md`
- `docs/dev-log/lanes/cursor-mspl-phase4-nbinom2/LOOP/arcs.md`
- `docs/dev-log/lanes/cursor-mspl-phase4-nbinom2/LOOP/ultra-plan.md`
- `docs/dev-log/lanes/cursor-mspl-phase4-nbinom2/LOOP/checkpoint.md`
- `docs/dev-log/research/2026-08-15-mspl-phase4-nbinom2-prep.md`
- `tests/testthat/test-mspl-nbinom2-phase4-oracles.R`
- `docs/dev-log/after-task/2026-08-15-mspl-nbinom2-phase4-prep.md`
- `docs/dev-log/check-log.md`

Not touched: `R/mspl.R`, `R/mspl-registry.R`, `src/`, other
families, NEWS, validation-debt register.

## 3a. Decisions and Rejected Alternatives

- **Decision:** keep nbinom2 `excluded`; do not add Poisson-style
  `planned` rows on this lane. **Rationale:** user fence was “no
  registry admit” and OWN list omitted the registry. **Rejected:**
  flipping to `planned` in the same PR as the derivation.
- **Decision:** stack the PR on `cursor/mspl-point-programme-continue`
  (#971). **Rationale:** this branch starts at that tip; a PR to
  `main` would duplicate #971. **Rejected:** rewriting the sibling
  science from scratch.

## 4. Checks Run

```sh
export OMP_NUM_THREADS=1 NOT_CRAN=true
# worktree /private/tmp/gllvmtmb-mspl-phase4-nbinom2
pkgload::load_all(".", compile = FALSE)
testthat::test_file("tests/testthat/test-mspl-nbinom2-phase4-oracles.R")
# 9 tests / 72 expectations / FAIL 0 / WARN 0 / SKIP 0 / PASS 72
testthat::test_file("tests/testthat/test-mspl-registry.R")
# 2 tests / 26 expectations / FAIL 0 / WARN 0 / SKIP 0 / PASS 26
git diff --stat -- src/ R/mspl.R R/mspl-registry.R
# empty
```

Structured oracle counts (this worktree, re-run, not the sibling
claim):

| File | tests | expectations | fail | skip | warn |
|---|---|---|---|---|---|
| `test-mspl-nbinom2-phase4-oracles.R` | 9 | 72 | 0 | 0 | 0 |
| `test-mspl-registry.R` | 2 | 26 | 0 | 0 | 0 |

`load_all(..., compile = FALSE)` printed a DLL-load warning; it did
not enter the testthat WARN count.

Not run: `devtools::test()`, `R CMD check`, pkgdown, live NB2 MSPL
fits, campaigns.

## 5. Tests of the Tests

Prophylactic oracles (no production defect to fail-first). E1
refuses Poisson \(W=\mu\) and Bernoulli \(W_g\) at finite \(\phi\).
E4 refuses the Poisson “exposure doubles \(I\)” identity. The
registry test fails if anyone adds a planned/admitted nbinom2 row.
The last test fails if the file contains `estimator = "mspl"`.

## 6. Consistency Audit

```sh
rg -n "estimator\\s*=\\s*[\"']mspl[\"']" tests/testthat/test-mspl-nbinom2-phase4-oracles.R
# no match (PASS)
rg -n "status\\s*=\\s*[\"']admitted[\"']" docs/dev-log/research/2026-08-15-mspl-phase4-nbinom2-prep.md
# no admission claim (PASS; note says not admitted)
rg -n "NEWS covered|covered claim" docs/dev-log/research/2026-08-15-mspl-phase4-nbinom2-prep.md docs/dev-log/after-task/2026-08-15-mspl-nbinom2-phase4-prep.md
# only HARD-STOP / non-claim language (PASS)
```

## 7. Roadmap Tick

N/A — no `ROADMAP.md` row. Phase-4 prep only.

## 7a. GitHub Issue Ledger

No relevant open issue; no new issue created. This is programme
Phase-4 paper-and-oracle work, not a user-facing bug.

## 8. What Did Not Go Smoothly

A first draft note existed on this worktree before the sibling
science landed. It was overwritten by copy, not merged. Do not
treat the discarded draft as a second derivation.

## 9. Team Learning

- **Curie:** 72/72 oracles re-ran on this worktree; counts are
  structured (9 tests, 72 expectations), not an exit-code glance.
- **Rose:** nbinom2 remains excluded; no NEWS covered; no prepare
  widen; no C++.
- **Shannon:** isolated WT; PR stacked on #971 so the delta is
  this lane only.

## 10. Known Limitations And Next Actions

- Loading-atom coercivity under Laplace is OPEN.
- Size-atom rate and Jacobian-on-tape are OPEN.
- **OPEN GATE:** Shinichi before any `excluded` → `planned` or
  `admitted` flip, prepare widen, or C++ tape.
- HARD STOP: admit, SE, NEWS covered. Do not merge this PR from
  the agent.
