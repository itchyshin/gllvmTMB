# After Task: MSPL catch-up Phase 2 + Phase 3 prep

**Branch**: `cursor/mspl-catchup-ml-laplace`
**Date**: `2026-08-15`
**Roles (engaged)**: Ada / Curie / Gauss / Noether / Rose / Melissa

```text
🎯 GOAL
Solo platform: Cursor
Deliverable: landed Phase 2 Bernoulli cell registry with unchanged admits/aborts/numbers, plus a Gaussian Heywood derivation and local oracles that do not admit Gaussian MSPL
HEADLINE: make LA-MSPL a truthful parallel to LA-ML on the live binary surface, then earn the first matched Gaussian cell on paper and in oracles — not by transplanting the Bernoulli penalty
DEFER: Phase 1B; merge #962/#961; Gaussian live admission; C++; NEWS; campaigns; EVA/VA
DISCIPLINE: verify=registry 13 + test-mspl-api 241 + new oracles green · compute=local targeted tests only · closure=after-task + stacked PR + Melissa
```

## 1. Goal

Re-express the live Bernoulli LA-MSPL surface as named registry
cells without changing admits, aborts, classes, or numbers, then
write a Phase 3 Gaussian Heywood derivation and pure-R oracles.
Do not admit Gaussian. Do not write C++. This is LA-MSPL, not EVA.

## 2. Implemented

- Phase 2 (already committed `5f306119`): explicit Bernoulli
  registry; successful prepares carry a cell id; Gaussian rows
  `gaussian:identity:ordinary:q1` / `q2` stay `planned`; B2 evidence
  stays `partial_b2_incomplete`.
- Phase 3 prep note with the paper (3.2)/(4.1) alignment table,
  Hirose primary / Akaike sibling, \(c_N=\sqrt{2/N}\), Opus fold
  (inert \(V_{\mathrm{loading}}\), \(\Psi\) split / #856 flat ridge
  OPEN GATE, rate tension, Jeffreys drop, kill list, E1–E7).
- Pure-R oracles in
  `tests/testthat/test-mspl-gaussian-heywood-oracles.R`. No
  `gllvmTMB(..., estimator = "mspl")` on Gaussian. Helpers stay in
  the test file.

## 3. Files Changed

- `R/mspl-registry.R` (Phase 2; already on `5f306119`)
- `R/fit-multi.R` (cell-id attach; already on `5f306119`)
- `tests/testthat/test-mspl-registry.R` (already on `5f306119`)
- `docs/dev-log/research/2026-08-15-mspl-phase3-gaussian-heywood-prep.md`
- `tests/testthat/test-mspl-gaussian-heywood-oracles.R`
- `docs/dev-log/plans/2026-08-15-cursor-mspl-catchup-ultra-plan.md`
  (already on the branch)
- `docs/dev-log/lanes/cursor-mspl-catchup/LOOP/`
- `docs/dev-log/after-task/2026-08-15-mspl-catchup-phase2-phase3prep.md`
  (this file)
- `docs/dev-log/check-log.md` (append)
- `docs/dev-log/plan-actual/2026-08-15-mspl-catchup.md`

Not changed: `src/gllvmTMB.cpp`, `NEWS.md`,
`docs/design/35-validation-debt-register.md`, `R/mspl.R` fence,
repo-root `LOOP/`, Design 117, interval-feasibility, iSDM / G3P /
#872 / #855 / AA-03.

## 3a. Decisions and Rejected Alternatives

- **Decision:** do not wait on #962. **Rejected:** merge-first.
  **Confidence:** high (G0).
- **Decision:** Phase 3 = derivation + oracles only.
  **Rejected:** live Gaussian `estimator = "mspl"`. **Confidence:** high (G0).
- **Decision:** Hirose \(S_{jj}/\psi_j\) is the preferred later
  atom; Akaike is a sibling. **Rejected:** Bernoulli
  \(V_{\mathrm{loading}}\) or a log-type atom with vanishing
  \(c_n\). **Confidence:** high (paper E3 + Opus B4).
- **Decision:** drop Gaussian Jeffreys. **Rejected:** keep it for
  symmetry with Bernoulli. **Confidence:** high (A5 identity).
- **Decision:** \(\Psi\) split / flat ridge is an OPEN GATE;
  oracles stay on textbook \((\Lambda,\psi,S)\). **Rejected:**
  pretend `sd_B` is paper \(\Psi\). **Confidence:** high (Opus B0).
- **Decision:** new stacked PR, not onto #962. **Rejected:**
  pushing Phase 2/3 onto the 1A PR. **Confidence:** high.

## 4. Checks Run

Worktree `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap`.
`OMP_NUM_THREADS=1`, `NOT_CRAN=true`. `pkgload::load_all(..., compile = FALSE)`.

```text
testthat::test_file("tests/testthat/test-mspl-gaussian-heywood-oracles.R")
[ FAIL 0 | WARN 0 | SKIP 0 | PASS 68 ]

testthat::test_file("tests/testthat/test-mspl-registry.R")
[ FAIL 0 | WARN 0 | SKIP 0 | PASS 13 ]

testthat::test_file("tests/testthat/test-mspl-api.R")
[ FAIL 0 | WARN 0 | SKIP 0 | PASS 241 ]
```

`git diff -- src/` empty. No NEWS. Gaussian registry rows remain
`planned`.

rg / grep:

- `estimator = "mspl"` in the new oracle file — expected-absent
  (no Gaussian MSPL fit).
- `status = "admitted"` on Gaussian rows — expected-absent.
- `NEWS.md` / `src/gllvmTMB.cpp` / validation register in this
  closeout diff — expected-absent.

Not run: `devtools::test()`, `R CMD check`, `pkgdown`, campaigns.

## 5. Tests of the Tests

- Algebra tests fail if (3.2) traces leave (4.1) sums.
- Coercivity fails if \(P^*\) stays finite as \(\psi_j\to 0\).
- Scale tests fail if the standardised atom moves under \(Y\mapsto LY\),
  or if \(\|\Lambda\|/k\) is treated as the atom.
- E4 fails if Hirose is not \(1/\psi\) or if a log-type atom with
  \(c_N\) is as coercive as Hirose.
- E5 fails if the flat ridge does not leave \(\Sigma\) invariant,
  or if penalising `sd_B` alone is silently identical to
  \(\psi^{\mathrm{total}}\).
- E7 fails if a later reader gives \(V_{\mathrm{loading}}\) a
  nonzero \(\psi\)-gradient.
- Registry test fails if Gaussian rows flip to `admitted` or B2
  evidence is rewritten.

## 6. Consistency Audit

| Pattern | Verdict |
|---|---|
| `git diff -- src/` | empty |
| `NEWS.md` in this closeout | expected-absent |
| `docs/design/35-validation-debt-register.md` | expected-absent |
| repo-root `LOOP/` | expected-absent (lane kit only) |
| Gaussian `status = "admitted"` | expected-absent |
| `estimator = "mspl"` in the new oracle file | expected-absent |
| EVA/VA language as this estimator | expected-absent |

## 7. Roadmap Tick

N/A. No `ROADMAP.md` row changed.

## 7a. GitHub Issue Ledger

No new issue. Programme vehicle remains
[#961](https://github.com/itchyshin/gllvmTMB/pull/961) (docs-only;
not merged). Arc 1A remains
[#962](https://github.com/itchyshin/gllvmTMB/pull/962) (do not merge
from this PR). #856 is named as the \(\Psi\)-split OPEN GATE, not
closed.

## 8. What Did Not Go Smoothly

- Review children were still running when S2 started; Opus was
  folded after interrupt. The (3.2)/(4.1) table was kept; kill
  list, E1–E7, Jeffreys drop, and the flat-ridge gate were added.
- E4 first used a fixture \(S\) that was not a model covariance;
  the Anderson–Rubin path only appears when \(S=\Sigma(\Lambda,\psi)\).
- `move_agent_to_root` is blocked for subagents; all writes used
  the mandatory worktree path.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Gauss.** The paper atoms are on the log-likelihood scale to be
maximised; TMB would add \(-P^*\). Hirose \(1/\psi\) is the only
candidate that wins the \((N/2)\log(1/\psi)\) race under a
vanishing \(c_N\). PASS for oracles; FAIL for tape.

**Noether.** Symbolic table, R oracles, and the rejected Bernoulli
atom describe the same three objects. The live
`sd_B`+\(\sigma_\varepsilon\) split is named and not silently
identified with paper \(\Psi\). PASS.

**Rose.** Not EVA; no 1B; no B2 promotion; no root `LOOP/`;
`planned` ≠ `admitted`; no NEWS; no C++. The kill list is the
later-admission fail set. PASS.

**Curie.** Targeted tests can fail. Oracles 68 / registry 13 /
`test-mspl-api` 241 all green. No Gaussian MSPL fit was used as
evidence.

**Melissa.** See `docs/dev-log/plan-actual/2026-08-15-mspl-catchup.md`.

## 10. Known Limitations And Next Actions

- Gaussian MSPL is still `planned`. The #856 flat ridge is an
  OPEN GATE: later admission must choose `diag(sd_B²)`,
  \(\psi^{\mathrm{total}}\), or a pinned-\(\sigma_\varepsilon\)
  exact-FA cell.
- No live Gaussian fit, no C++, no recovery/no-harm smoke, no
  inference.
- Phase 1B, merge of #962/#961, NEWS, and campaigns remain gated.
- Next slice after Shinichi: decide the \(\Psi\) coordinate map,
  then a C++ tape only if Sol/Opus still PASS on that map.
