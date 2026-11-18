# After-task: MSPL nbinom1 Phase-4 prep and exact-information repair

**Date:** 2026-08-15
**Lane:** `cursor/mspl-phase4-nbinom1`
**Worktree:** `/private/tmp/gllvmtmb-mspl-phase4-nbinom1`
**Arc:** A0–A3

## Scope

Land the sibling nbinom1 Phase-4 *prep* on this isolated worktree:
copied derivation note, copied pure-R oracles, LOOP kit, stacked PR.
Not admission. No registry row. No prepare widen. Science was **not**
rewritten.

## Outcome

- Research note copied from the shared worktree
  `docs/dev-log/research/2026-08-15-mspl-phase4-nbinom1-prep.md`
  (\(\operatorname{Var}=\mu+\varphi\mu\) vs Poisson vs NB2; no
  nbinom1 registry row).
- Oracles copied
  `tests/testthat/test-mspl-nbinom1-phase4-oracles.R`
  (N1–N13 + live-fit fence).
- PR review repair replaced the incorrect quasi/IRLS
  \(W=\mu/(1+\varphi)\) Jeffreys object with exact Fisher information
  summed from the NB1 pmf (`size = mu / phi`). N2 checks pmf mass,
  centred score, and outer-product = expected-Hessian information;
  N3 and N9 explicitly reject the quasi identities. N12 fixes R/TMB's
  success probability to \(1/(1+\varphi)\).
- LOOP under `docs/dev-log/lanes/cursor-mspl-phase4-nbinom1/LOOP/`.
- `R/mspl.R`, `src/`, `.gllvmTMB_mspl_prepare()`, and
  `R/mspl-registry.R` untouched.

## Checks

```sh
export OMP_NUM_THREADS=1 NOT_CRAN=true
pkgload::load_all(".", compile = FALSE)
testthat::test_file("tests/testthat/test-mspl-nbinom1-phase4-oracles.R")
# PASS 74 / 14 blocks (structured table in LOOP/arcs.md)
testthat::test_file("tests/testthat/test-mspl-registry.R")
# PASS 26 (untouched)
git diff --stat -- src/ R/mspl.R R/mspl-registry.R
# empty
```

| ID | n | ID | n |
|---|---|---|---|
| N1 | 5 | N8 | 4 |
| N2 | 9 | N9 | 8 |
| N3 | 7 | N10 | 3 |
| N4 | 4 | N11 | 9 |
| N5 | 3 | N12 | 8 |
| N6 | 4 | N13 | 5 |
| N7 | 3 | live-fit fence | 2 |
| | | **Total** | **74** |

## Non-claims / OPEN GATE

- No C++ tape; no `estimator="mspl"` on nbinom1; no NEWS covered.
- **No nbinom1 registry row** (N13 pins lookup `NULL`).
- **OPEN GATE:** Shinichi before any later `planned` row or admit.
  Merge is human, not this lane.

## Mathematical contract

No public API / likelihood / grammar / family change. Oracles pin
already-wired NB1 \(\operatorname{Var}=\mu(1+\varphi)\), exact
score information under `size = mu / phi`, and R/TMB success
probability \(1/(1+\varphi)\). The variance-function weight
\(\mu/(1+\varphi)\) is retained only as a quasi/IRLS contrast.

## Roadmap tick

N/A.

## GitHub issue ledger

No relevant open issue; no new issue created. This is planned-only
prep stacked on #971.
