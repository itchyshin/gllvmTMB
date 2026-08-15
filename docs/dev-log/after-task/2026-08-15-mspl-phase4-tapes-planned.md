# After Task: MSPL Phase-4 fenced tapes + Poisson public door

**Branch**: `cursor/mspl-phase4-tapes-planned`
**Date**: `2026-08-15`
**Roles (engaged)**: Ada / Gauss / Noether / Curie / Rose / Shannon / Melissa
**Lane LOOP**: `docs/dev-log/lanes/cursor-mspl-phase4-tapes-planned/LOOP/`

```text
🎯 GOAL
Solo: Cursor
Deliverable: one shared weight-hook and five fenced planned C++ tapes; public estimator="mspl" runs only for gaussian, bernoulli, and Poisson
HEADLINE: all five tapes exist; only Poisson becomes newly callable; nobody is admitted
DEFER: admit, NEWS covered, SE, Totoro>30min, Codex interval, public MSPL on NB1/NB2/beta/Tweedie
```

## 1. Goal

Land the G0-locked Phase-4 **tapes** slice: one C++ GLM-outer weight
hook, five family atoms, and a public `estimator="mspl"` door that
now includes Poisson. Nobody is admitted. NB1, NB2, beta, and
Tweedie stay behind the prepare fence.

## 2. Implemented

- Shared hook `gll_mspl_log_weight_glm` in `src/gllvmTMB.cpp`. The
  validated 2-arg Bernoulli `gll_mspl_log_weight` is unchanged and
  remains the family-1 call path.
- Poisson tape: `log w = η` (`W = diag(μ)` on the log link). Public
  `gllvmTMB(..., family = poisson(), estimator = "mspl")` no longer
  hits the old family fence. Registry stays `planned` /
  `phase4_prep`.
- Fenced tapes: NB2 `W = μφ/(φ+μ)`; NB1 PMF-summed exact `I_η` at
  fixed `φ` (not quasi `μ/(1+φ)`); beta Ferrari–Cribari-Neto weight
  (not coercive at `μ→0/1`); Tweedie `W = μ^{2-p}/φ` (rewards
  `φ→0`). Public `mspl` still errors for those four.
- Rate: Bernoulli keeps `2√(p_free/N_eff)`; Gaussian keeps
  `√(2/N_units)`; Poisson and fenced tapes use unpinned `c = 1`.
- Prepare message now names gaussian, bernoulli, or Poisson only.

## 3. Files Changed

- `src/gllvmTMB.cpp` — fail-closed + GLM-outer hook + call site
- `R/mspl.R` — prepare door `{0,1,2}`; Poisson log-link / ordinary /
  unpinned `c`
- `R/mspl-registry.R` — Poisson link name; notes say fenced planned
  tape, not admitted, not covered
- `tests/testthat/test-mspl-poisson-public-door.R` (new)
- `tests/testthat/test-mspl-fenced-family-tapes.R` (new)
- `tests/testthat/test-mspl-nb1-fenced-tape.R` (new)
- `tests/testthat/test-mspl-nb2-fenced-tape.R` (new)
- `docs/dev-log/research/2026-08-15-mspl-glm-outer-five-atoms.md` (new)
- `tests/testthat/test-mspl-prepare-fence.R` — drop Poisson; new message
- `tests/testthat/test-mspl-api.R` — unsupported-family example is
  `nbinom2()`, not `poisson()`
- `tests/testthat/test-mspl-poisson-phase4-oracles.R` — notes pin only
- LOOP kit under `docs/dev-log/lanes/cursor-mspl-phase4-tapes-planned/LOOP/`
- this after-task; Melissa plan-actual; check-log; lane-split row;
  handover `docs/dev-log/handover/2026-08-15-cursor-handover-phase4-tapes.md`

No NEWS. No `man/*.Rd`. No ROADMAP tick. No `docs/design/117`.

## 3a. Decisions and Rejected Alternatives

- **Decision:** atom is GLM-outer `½ log det(X'WX)` at fixed-only
  `η = Xβ`, not Laplace-marginal `I(β)`.
- **Rationale:** G0 lock; the Phase-4 prep notes already named this
  as OPEN.
- **Rejected:** transplant Bernoulli `c = 2√(p_free/N_eff)` or
  Gaussian `√(2/N)` onto Poisson/NB; public `mspl` on NB1/NB2/beta/
  Tweedie; `planned` → `admitted`; NEWS “covered”.
- **Confidence:** high on the fence and the three-family door; the
  Poisson tape is experimental point plumbing only.

## Mathematical Contract

| Family | Atom (GLM-outer weight) | Public door | Registry |
|---|---|---|---|
| gaussian | Hirose `Σ_j S_jj/ψ_j` (unchanged) | yes | `admitted` / `oracle_local` |
| bernoulli | 2-arg Jeffreys `gll_mspl_log_weight` (unchanged) | yes | `admitted` |
| Poisson | `log w = η` (`W = diag(μ)`) | **yes, new** | **`planned`** |
| NB2 | `W = μφ/(φ+μ)` | no | `excluded` |
| NB1 | PMF-summed exact `I_η` at fixed `φ`, `size=μ/φ`, `p=1/(1+φ)` | no | no row |
| beta | Ferrari–Cribari-Neto; weight → 1 as `μ→0/1` | no | no row |
| Tweedie | `W = μ^{2-p}/φ`; `p = 1+invlogit(·)` | no | no row |

This is **not** `I_LA(β)`. Poisson `c = 1` is unpinned, not a
validated rate.

## 4. Checks Run

```sh
OMP_NUM_THREADS=1 Rscript --vanilla -e 'pkgload::load_all(compile = TRUE)'
# DONE (gllvmTMB); Eigen unused-variable warnings only

NOT_CRAN=true OMP_NUM_THREADS=1
# test-mspl-prepare-fence.R          PASS (4)
# test-mspl-poisson-public-door.R    PASS
# test-mspl-fenced-family-tapes.R    PASS
# test-mspl-nb1-fenced-tape.R        PASS
# test-mspl-api.R                    PASS
# test-mspl-registry.R               PASS
# test-mspl-gaussian-fit-smoke.R     PASS (off-CRAN)
# test-mspl-poisson-phase4-oracles.R PASS
# test-mspl-gaussian-heywood-oracles.R PASS
```

```sh
rg -n 'fam_ids %in% c\\(' R/mspl.R
# R/mspl.R:182  c(0L, 1L, 2L)

rg -n 'binomial or gaussian only' R/mspl.R tests
# no matches

rg -n 'status = "planned"|status = "admitted"|status = "excluded"' R/mspl-registry.R
# gaussian admitted; poisson planned; nbinom2 excluded

rg -n 'I_LA|Laplace-marginal I\\(beta\\)' src/gllvmTMB.cpp
# comments only: "NOT Laplace-marginal I(beta)"

rg -n 'mspl_c_n =' src/gllvmTMB.cpp
# Gaussian sqrt(2/N); Bernoulli 2*sqrt(p_free/N_eff); else 1.0
```

Not run: `devtools::test()`, `R CMD check`, pkgdown, Totoro, NEWS,
document().

## 5. Tests of the Tests

- Poisson public-door was RED on the pre-door fence (“binomial or
  gaussian only”) before the hook-owner edited `src/`.
- Prepare-fence still fails NB1/NB2/beta/Tweedie with
  `gllvmTMB_mspl_unsupported`.
- `test-mspl-api.R` unsupported-family case is now `nbinom2()` so
  Poisson is no longer used as the “must error” example.
- NB1 Curie file pins PMF-summed exact `I` ≠ quasi `μ/(1+φ)` ≠
  Poisson `μ`, and requires the C++ comments to name that split.
- Shared fence file reads `src/gllvmTMB.cpp` for GLM-outer / five
  `family_id` atoms / beta “not coercive” / Tweedie “rewards”.

## 6. Consistency Audit

| Pattern | Verdict |
|---|---|
| `fam_ids %in% c(0L, 1L, 2L)` | PASS — public door is three families |
| prepare “binomial or gaussian only” | PASS — gone |
| Poisson `status = "admitted"` | PASS — still `planned` |
| NB2 `excluded` | PASS |
| planned rows for NB1/beta/Tweedie | PASS — none |
| NEWS Poisson MSPL / “covered” | PASS — NEWS untouched |
| GLM-outer called `I_LA(β)` | PASS — comments deny it |
| Bernoulli/Gaussian `c` on Poisson | PASS — `c = 1` |

## 7. Roadmap Tick

N/A. No `ROADMAP.md` row moved.

## 7a. GitHub Issue Ledger

No relevant open issue; no new issue created. This is a fenced
estimator-programme tape, not a user-facing issue closeout. Do not
merge #972–#976 from this lane.

## 8. What Did Not Go Smoothly

The first C++ pass broke the 2-arg Bernoulli weight (duplicate
`link_id == 0` / missing overload). Restored before compile. Two
Wave-1 tests over-fitted registry wording (`admitted` inside “not
admitted”; NB2 lookup vs suffixed excluded `cell_id`). Fixed in the
tests, not by widening the registry.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Ada.** One cpp owner, one branch, no `git add -A`. The public door
and the C++ tape are different objects: Poisson is callable and
still `planned`.

**Gauss.** Bernoulli and Gaussian numeric paths stay on their old
functions and rates. New families do not inherit those rates. The
NB1 host-side `ymax` truncation is a numerical cutoff of the same
estimand, not a different atom.

**Noether.** GLM-outer `½ log det(X'WX)` at fixed-only `η` is not
`I_LA(β)`. Poisson `W = diag(μ)` is not Bernoulli `p(1-p)` and not
Hirose.

**Curie.** Failing public-door test before `src/`. Fence tests keep
the four deferred families red at prepare. NB1 extra file refuses
the quasi-weight shortcut.

**Rose.** No NEWS covered. No admit. Prepare message no longer says
“binomial or gaussian only”.

**Shannon.** #972–#976 stay open on `cursor/mspl-point-programme-continue`
and were not merged here. Codex `lane-b-mspl-interval-feasibility`
still owns SE; this lane only widened the Poisson prepare door in
`R/mspl.R`.

**Melissa.** Plan-actual records the two test-wording drifts; no
HARD STOP hit.

## 10. Known Limitations And Next Actions

- Poisson `estimator="mspl"` is experimental plumbing, not an
  admission. No multi-seed Poisson point evidence in this slice.
- NB1/NB2/beta/Tweedie tapes exist only for later Phase 5 / later
  G0. Public calls still error.
- SE/intervals remain PROTECTED on Codex Lane B.
- Next: human review of this PR. New G0 required for Poisson
  admit, NEWS covered, or any public door beyond the three
  families.
