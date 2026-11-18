# After Task: Poisson LA-MSPL admit packet (planned, not admitted)

**Branch**: `cursor/mspl-poisson-admit-packet`
**Date**: `2026-08-15`
**Roles (engaged)**: Ada (keep planned), Curie (oracles), Gauss/Noether
(atoms), Rose (fence)

## 1. Goal

Land the missing Poisson admit *science* — pinned rate \(c_P\), a
Poisson loading atom under Laplace, and TMB/pure-R oracles — without
flipping `planned` → `admitted` and without asking Shinichi to merge
first.

## 2. Implemented

- Event-count rate
  \(c_P=2\sqrt{p_{\mathrm{free}}/\max(\sum y,1)}\) in R prepare and
  the Poisson C++ tape branch (`mspl_family_mode == 3`).
- Event-weighted loading atom
  \(\sum_t(\sqrt{1+\|\lambda_t\|^2\bar y_t}-1)\). All-zero traits
  contribute 0. Bernoulli `gll_mspl_row_radial_penalty` is no longer
  used on Poisson ordinary cells.
- Jeffreys GLM-outer \(W=\mathrm{diag}(\mu)\) unchanged.
- Fenced GLM-outer families (NB1/NB2/beta/Tweedie) stay at
  unpinned \(c=1\).
- Registry Poisson rows remain `status="planned"`,
  `evidence="phase4_prep"`.

## 3. Files Changed

- `R/mspl-poisson-atoms.R` (new internals)
- `R/mspl.R` (Poisson rate + scope string)
- `R/mspl-registry.R` (notes only; still planned)
- `src/gllvmTMB.cpp` (Poisson \(c_P\) + event-weighted loading atom)
- `tests/testthat/test-mspl-poisson-admit-packet.R` (new A1–A8)
- `docs/dev-log/research/2026-08-15-mspl-poisson-admit-packet.md`
- `docs/dev-log/after-task/2026-08-15-mspl-poisson-admit-packet.md`
- `docs/dev-log/check-log.md`

No NEWS. No README. No repo-root `LOOP/`. No Dropbox checkout.

## 3a. Decisions and Rejected Alternatives

- **Decision:** event count as the rate denominator.
  **Rationale:** Poisson information size is \(\sum\mu\approx\sum y\),
  not \(N_{\mathrm{rows}}\) (prep E4) and not \(N_{\mathrm{units}}\)
  (Gaussian transplant).
  **Rejected:** keep \(c=1\); transplant Bernoulli \(c_n\) or
  Gaussian \(c_N\).
  **Confidence:** medium (AGENT-INFERRED vanishing scale).
- **Decision:** \(\bar y\)-weighted radial loading atom.
  **Rationale:** coercive at \(\bar y>0\); inert on all-zero traits
  so Jeffreys-on-\(\beta\) owns \(\mu\to 0\); explains #990
  factor-death under Bernoulli \(V_{\mathrm{loading}}\) at \(c=1\).
  **Rejected:** keep Bernoulli \(V_{\mathrm{loading}}\); double-count
  Laplace \(\log\det H_u\); Hirose \(1/\psi\).
  **Confidence:** medium (AGENT-INFERRED; oracles pin the formula).

## 4. Checks Run

```sh
export OMP_NUM_THREADS=1 NOT_CRAN=true
# RED (helpers missing): test-mspl-poisson-admit-packet.R
#   FAIL 7 | PASS 9  — object not found
pkgload::load_all(".", compile = TRUE)
testthat::test_file("tests/testthat/test-mspl-poisson-admit-packet.R")
# GREEN: FAIL 0 | WARN 0 | SKIP 0 | PASS 41
testthat::test_file("tests/testthat/test-mspl-poisson-public-door.R")   # PASS 6
testthat::test_file("tests/testthat/test-mspl-poisson-phase4-oracles.R") # PASS 42
testthat::test_file("tests/testthat/test-mspl-registry.R")              # PASS 26
testthat::test_file("tests/testthat/test-mspl-fenced-family-tapes.R")   # PASS 23
```

rg (verbatim):

```
rg 'status\s*=\s*"admitted"' R/mspl-registry.R
# gaussian block only; poisson block is status = "planned"
rg 'family = "poisson"' -A 8 R/mspl-registry.R
# status = "planned"; evidence = "phase4_prep"
```

Not run: `devtools::test()`, `devtools::check()`, Totoro/DRAC B1,
`pkgdown`.

## 5. Tests of the Tests

- RED first: helpers missing (`could not find function`).
- Two fixtures were too weak (sum(y)=n_rows; ybar=1) and were
  tightened so the contrast against Bernoulli actually fires.
- A7 is a live tape match, not a mock.
- A8 would fail on a registry admit flip.

## 6. Consistency Audit

| Pattern | Verdict |
|---|---|
| `status = "planned"` on poisson q1/q2 | PASS |
| no NEWS `covered` | PASS (NEWS untouched) |
| no public `se=TRUE` | PASS |
| Codex Lane B not absorbed | PASS |
| #972–#976 not merged | PASS |
| repo-root `LOOP/` | PASS (not written) |

## 7. Roadmap Tick

N/A. Internal estimator science only.

## 7a. GitHub Issue Ledger

No relevant open issue; no new issue created. Work is the Phase-4
admit packet named in the 2026-08-15 handover, not an issue closeout.

## 8. What Did Not Go Smoothly

This worktree had leftover #990 untracked copies that blocked
`git checkout` from the handover branch onto `origin/main`. They
were moved to `/tmp/mspl-990-leftovers`, not `git add -A`.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

- **Ada:** Shinichi said code, not merge ceremony. Packet is science;
  admission stays a later gate.
- **Curie:** TDD held; A7 is the tape contract.
- **Gauss / Noether:** atoms are AGENT-INFERRED; oracles pin them.
- **Rose:** `planned` ≠ `admitted`; no NEWS covered.

## 10. Known Limitations And Next Actions

Still OPEN for admission: healthy/sparse no-harm as an *admission*
packet, prediction, penalty sensitivity, Shinichi gate. Do not flip
the registry from this PR. B1 Totoro/DRAC was not started — write a
receipt before any >30 min remote job. #989 remains watch-only.
#972–#976 remain unmerged.
