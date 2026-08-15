# After Task: MSPL Poisson Phase-4 prep strengthen (planned only)

**Branch**: `cursor/mspl-phase4-poisson`
**Date**: `2026-08-15`
**Worktree**: `/private/tmp/gllvmtmb-mspl-phase4-poisson`
**Roles (engaged)**: Ada / Curie / Noether / Rose / Shannon

## 1. Goal

Strengthen the existing Poisson LA-MSPL Phase-4 *prep* surface
(derivation note + pure-R oracles E1–E7) on an isolated lane, then
open a docs+test PR. Not admission.

## 2. Implemented

Poisson ordinary cells stay `planned` / `phase4_prep`. Oracles now
pin algebraic identities that the first prep pass only sketched:
log-det scaling \(P^*_{\mathrm{J}}(\varepsilon\mu)=P^*_{\mathrm{J}}(\mu)+\tfrac{p_*}{2}\log\varepsilon\),
trait-wise all-zero divergence, exposure-blind Bernoulli/Gaussian
rate transplants, offset converse, opposite-signed Hirose vs
Jeffreys boundaries, and a read-only prepare-fence source pin
(`family_id %in% {0,1}`; Poisson remains `2`). No C++ tape, no
prepare widen, no NEWS, no live Poisson `estimator = "mspl"`
success test.

## 3. Files Changed

- `docs/dev-log/lanes/cursor-mspl-phase4-poisson/LOOP/GOAL.md`
- `docs/dev-log/lanes/cursor-mspl-phase4-poisson/LOOP/arcs.md`
- `docs/dev-log/lanes/cursor-mspl-phase4-poisson/LOOP/checkpoint.md`
- `docs/dev-log/lanes/cursor-mspl-phase4-poisson/LOOP/ultra-plan.md`
- `docs/dev-log/research/2026-08-15-mspl-phase4-poisson-prep.md`
- `tests/testthat/test-mspl-poisson-phase4-oracles.R`
- `docs/dev-log/after-task/2026-08-15-mspl-phase4-poisson.md` (this file)

Not touched: `R/mspl.R`, `R/mspl-registry.R`, `src/`, NEWS, register
promotion, Codex SE lane, repo-root `LOOP/`, sibling Tweedie files.

## 3a. Decisions and Rejected Alternatives

- **Decision:** thicken E1–E7 in place rather than add E8–E12.
  **Rationale:** the dispatch named E1–E7; new IDs would look like a
  new scientific claim. **Rejected:** a live Poisson MSPL reject-fit
  in this file (already owned by `test-mspl-api.R`; this file must
  stay free of `gllvmTMB()`). **Confidence:** high.
- **Decision:** source-pin the prepare fence instead of calling
  `.gllvmTMB_mspl_prepare()` with a dummy argument list.
  **Rationale:** the helper’s contract is huge; a source pin plus
  the existing API reject test is enough for prep. **Confidence:**
  medium-high.

## 4. Checks Run

```sh
# Isolated worktree
git -C /private/tmp/gllvmtmb-mspl-estimator-programme-roadmap \
  worktree add -b cursor/mspl-phase4-poisson \
  /private/tmp/gllvmtmb-mspl-phase4-poisson \
  cursor/mspl-point-programme-continue
# HEAD 43b928a4

OMP_NUM_THREADS=1 NOT_CRAN=true
pkgload::load_all(".", compile = FALSE)
testthat::test_file("tests/testthat/test-mspl-poisson-phase4-oracles.R")
# 10 tests / 102 expectations / 0 failed / 0 error / 0 skipped / 0 warning
testthat::test_file("tests/testthat/test-mspl-registry.R")
# 2 tests / 26 expectations / 0 failed
git diff --stat -- src/ R/mspl.R R/mspl-registry.R   # empty
```

Structured oracle PASS counts (expectations per test):

| ID / test | passed | failed |
|---|---:|---:|
| E1 information vs Bernoulli \(W_g\) | 12 | 0 |
| E2 all-zero + trait-wise + P6 | 15 | 0 |
| E3 near-zero + P5 log-det identity | 24 | 0 |
| E4 exposure vs \(N_{\mathrm{rows}}\) / rate transplant | 12 | 0 |
| E5 offset spelling + converse | 5 | 0 |
| E6 Hirose refuse + opposite sign | 8 | 0 |
| E7 \(V_{\mathrm{loading}}\) \(\mu\)-inert + all-zero path | 6 | 0 |
| planned `phase4_prep` registry pin | 13 | 0 |
| no live Poisson MSPL / no `gllvmTMB(` | 3 | 0 |
| prepare fence source pin `{0,1}` | 4 | 0 |
| **total** | **102** | **0** |

`load_all(..., compile = FALSE)` printed a DLL-load warning; oracles
are pure R and did not need the compiled tape.

## 5. Tests of the Tests

- **Failure-before-fix (prophylactic thicken):** E3’s
  \(P^*_{\mathrm{J}}(\varepsilon\mu)=P^*_{\mathrm{J}}(\mu)+\tfrac{p_*}{2}\log\varepsilon\)
  would fail if the atom used \(\operatorname{tr}(W)\) or Bernoulli
  weights. E4’s rate contrast would fail if \(c_n\) were keyed on
  \(\sum\mu\). The prepare source pin would fail if
  `fam_ids %in% c(0L, 1L, 2L)` landed.
- **Boundary:** E2 trait-wise path keeps trait-B means \(>0.5\) while
  trait-A means drop below \(10^{-6}\).
- **Feature-combination:** E5 identity plus converse (offset dropped
  without folding \(\eta\)).

## 6. Consistency Audit

```sh
rg -n "admitted|estimator = .mspl.|NEWS covered|prepare widen" \
  docs/dev-log/research/2026-08-15-mspl-phase4-poisson-prep.md \
  tests/testthat/test-mspl-poisson-phase4-oracles.R \
  docs/dev-log/lanes/cursor-mspl-phase4-poisson/LOOP/
# Verdict: every hit is a fence / non-claim, not an admission.

rg "fam_ids %in% c\\(0L, 1L, 2L\\)" R/mspl.R
# Verdict: no match (fence unchanged).

git diff --stat -- src/ R/mspl.R R/mspl-registry.R
# Verdict: empty.
```

User-facing stale-wording patterns from the after-task-audit skill
were not re-run on README/NEWS/vignettes: this PR does not touch
those surfaces.

## 7. Roadmap Tick

N/A. No `ROADMAP.md` row moved. Poisson MSPL remains planned prep.

## 7a. GitHub Issue Ledger

No relevant open issue for Poisson Phase-4 admission; none created.
This is a prep-only docs+test strengthen. The next scientific gate
(admit) needs Shinichi and is explicitly not this PR.

## 8. What Did Not Go Smoothly

`move_agent_to_root` is blocked for subagents, so edits used
absolute paths under the new worktree rather than a re-rooted
Cursor workspace. Lane preflight on the parent tree reported many
live foreign lanes; this lane named itself and stayed inside the
owned path set.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Ada.** Isolated worktree from `cursor/mspl-point-programme-continue`
@ `43b928a4`, not Dropbox and not the parent point-continue tree.
Finish line is prep+PR, not merge.

**Noether.** The load-bearing new equation is P5
(\(I(\varepsilon\mu)=\varepsilon I(\mu)\)). It matches the R helpers
`.poisson_I` / `.poisson_Pj` bit-for-bit in E3.

**Curie.** Oracles stay pure R. The no-`gllvmTMB(` scan is the
test-of-the-test that keeps this file off the live Poisson MSPL
surface.

**Rose.** `planned` ≠ `admitted`; prepare fence unchanged; LOOP path
moved from the historical point-continue kit to this lane.

**Shannon.** Owned paths only. After-task is a new file
(`2026-08-15-mspl-phase4-poisson.md`) so it does not rewrite the
point-continue B1 report.

## 10. Known Limitations And Next Actions

- Loading-atom coercivity under Laplace: **OPEN**.
- Poisson rate \(c\): **OPEN**.
- No tape, no healthy/boundary DGP, no admit.
- **HARD STOP:** do not merge this PR to `main` as an admission;
  do not flip registry status; do not widen prepare.
- Next human gate: review the docs+test PR. A later GOAL is
  required before any Poisson admit smoke.
