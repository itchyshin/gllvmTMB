# After-task — #851 scale-aware start: regressions resolved on merit

**2026-07-31 · Claude (Fable 5) · branch `claude/851-scale-aware-start-20260731` · PR #873**

## 1. Goal

Resolve the test regressions caused by the #851 scale-aware starting values, without
relaxing any convergence check, and either land PR #873 or write an evidenced decision
not to.

## 2. Implemented

Three commits, in the order the evidence arrived.

- **`0c52362f` — scope the loading scale to the tier that has a Ψ.** `init_rr_theta()` is
  shared by six tiers. Multiplying its `0.5` by the data scale moved the loading start on
  all six, while the companion Ψ start moved on one (`theta_diag_B`). The other five were
  left scaling Λ *without* its Ψ — the exact variant this branch had already measured and
  rejected, because it moves the shared/independent balance rather than the scale. `scale`
  is now an explicit argument defaulting to `1.0`, passed only at `theta_rr_B`.
- **`f31935e5` — do not seed latent scores when an `lv` predictor models their mean.** The
  SVD seeding assumes `z_B` is a free standardised score. Under `latent(..., lv = ~x)` it
  carries a modelled mean `alpha_lv_B %*% x` whose coefficient starts at zero, so the
  seeded start asserts and denies the same signal.
- **`b0e41aa4` — put three assertions back on ground that can carry them.** Two routing
  tests were re-fixtured off a weakly identified model; one tolerance was restored to
  testthat's default. Neither is a relaxed convergence check — see §3a.

## 3a. Decisions and rejected alternatives

- **Scope the scale to the B tier** (Shinichi, this session). Every #851 measurement is
  single-tier `latent()`, i.e. the B tier, so the headline result is preserved intact while
  the five unmeasured tiers stop sitting in a known-bad configuration. Declared limitation,
  now in NEWS: the scale bug remains unfixed for the phylogenetic, spatial, kernel and
  random-slope latent terms. It is unfixed there today too; this makes the scope honest
  rather than silently partial.
- **REJECTED — remove the score seeding outright.** It tightens ordinary-scale convergence
  but is load-bearing at scale: disabling it degrades k = 5000 badly (Λ 0.0171 → 0.0749,
  Σ 0.0204 → 0.117, correlations 0.0177 → 0.102), flipping three laws to VIOLATED. The
  `lv` gate is the narrow version that keeps the benefit.
- **REJECTED — accept `convergence = 1` on the two routing fixtures.** That is literally
  the relaxation Bolker names as the agent failure mode, and it would blind those tests to
  a future real regression. Re-fixturing keeps the check and makes it mean something.
- **REJECTED — a loadings-only re-fixture** (`latent(d = 1, unique = FALSE)` alone). It is
  degenerate on the wide data: `max|grad|` ≈ 7e+10 on the branch and 2.7e+11 on `main`.
  Measured, not assumed.

## 4. Files touched

**Package** — `R/fit-multi.R` (both engine commits), `NEWS.md` (scope disclosure).
**Tests** — `tests/testthat/test-traits-keyword.R`, `tests/testthat/test-canonical-keywords.R`.
**dev/** — `dev/851-dep-vs-latent-ridge-tolerance.R` (new; the 12-seed ridge measurement).
**docs/** — this report.
Not touched: `src/` (byte-identical to `main` throughout, which is what made the baseline
cheap — see §5).

## 5. Checks run

All suite runs on Totoro, 32 cores, ~17.5 min each, against a **verified `main` baseline**
re-derived this session (18 fail / 3 err: `test-m3-pilot-manifest.R` 16+2,
`test-profile-derived-curves.R` 2, `test-tweedie-fixed-p.R` 1).

| state | FAIL | ERR | new vs main | what cleared |
|---|---|---|---|---|
| branch as inherited | 25 | 3 | 7 | — |
| + tier restriction | 22 | 3 | 4 | `test-coevolution-two-kernel.R` ×2 |
| + `lv` gate | 21 | 3 | 3 | `test-lv-factor-runtime.R` |
| + test re-fixturing | **18** | **3** | **0** | `test-traits-keyword.R` ×2, `test-canonical-keywords.R` ×1 |

The final run is **file-for-file identical to the `main` baseline** — the only failing
files are `test-m3-pilot-manifest.R` (16+2), `test-profile-derived-curves.R` (2) and
`test-tweedie-fixed-p.R` (1 err), all pre-existing. PASS rose 14129 → 14131.

**Equivariance, preserved.** `dev/scale-equivariance-check.R` k = 100: every law OK
(6.35e-06 … 1.4e-05). `dev/851-scale-equivariance-comparators.R`: gllvmTMB **0/8** at both
k = 100 and k = 5000, worst case 0.0105, against gllvm 3/16 (worst 0.998) and glmmTMB
14/16 (worst 2.00) — reproducing the pre-existing numbers exactly.

## 6. Tests of the tests

The re-fixtured assertions were checked to still bite: the rejected loadings-only fixture
fails them loudly (`|grad|` ~1e+11), and the retained `convergence == 0` checks now run on
a model where both trees converge cleanly with gradients three to four orders tighter
(6.85e-10 / 7.66e-07 on branch) than the fixture they replaced.

## 8. Consistency audit

Swept the neighbourhood for the same defect class. `init_rr_theta` has **two further
private copies** — `init_rr_theta_spde_lv` and `init_rr_theta_pkg` — that hardcode `0.5`.
They are why two tiers escaped the original blast radius, by accident rather than design.
Not fixed here (out of scope, and a pure de-duplication should not ride on a behaviour
commit); filed as a follow-up task.

## 9. What did not go smoothly

**The Totoro branch tree was stale and would have produced a wrong answer.** It still held
the *reverted* Ψ-at-remainder code — the 36 fail / 16 err state — so the `fullsuite.log`
sitting there looked like current evidence and was not. Caught by grepping the deployed
source for a marker (`REMAINDER`) before trusting the log. Existence is not validation.

**Four of the "five remaining regressions" were three, and one was platform-specific.**
`test-lv-factor-runtime.R` passes on macOS and fails on Linux; the inherited count also
included a failure that no longer reproduced. Re-deriving the list from a fresh
branch-vs-baseline pair was necessary before any of it could be reasoned about.

## 10. Known residuals

- The scale fix does **not** cover the W, kernel, phylogenetic, SPDE or slope tiers. Stated
  in NEWS. Not measured there, and deliberately not moved.
- The two-tier k = 5000 remainder (Σ 0.0204) is unchanged and remains #872's territory —
  a property of the likelihood surface, not of starting values.
- `main` itself is **not green** (18 fail / 3 err, 16 in `test-m3-pilot-manifest.R`),
  independent of this work and sitting under the 0.6 rung. Raised, not absorbed.

## 11. Team learning

**A shared helper turns a one-tier change into a six-tier change silently.** The #851 start
was reasoned about, measured, and documented entirely in terms of the B tier — and it was
correct there. What made it a regression was that the helper it edited was shared, and five
other tiers had no companion Ψ to move with it. The branch's own comment already contained
the refutation ("scaling Λ alone … changes that balance rather than the scale"); it simply
was not read as applying to the tiers the author was not thinking about. *Before editing a
helper, list its call sites and ask which of the change's preconditions hold at each one.*

**"Is this assertion an invariant, or one lucky trajectory?" is answerable, cheaply.** Run
the assertion across seeds **on `main`**. `test-canonical-keywords.R:556` breached its own
1e-10 on 6 of 12 seeds on `main` and passed at seed 42 by luck — which converts "the branch
broke it" into "the branch re-rolled it", and converts a tolerance change from a relaxation
into a correction. This generalises to every knife-edge numerical assertion in the suite.

## 12. Cross-product coverage — the negative space

Not covered, and deliberately: any tier other than B for the scale fix; non-gaussian
families for the ridge measurement (the 12-seed sweep is gaussian only); the `lv` gate at
`d > 1` (the fixture is `d = 1`); and Windows, where nothing here was run. The convergence
characterisation covers three fixtures, not the class — "over-parameterised fits are merely
flagged" is established for those three, not proven in general.
