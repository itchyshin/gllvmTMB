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

**Register row — `MIS-35`** (`docs/design/35-validation-debt-register.md`), added per that
document's rule that every PR touching an advertised capability appends or updates a row.
**Package** — `R/fit-multi.R` (both engine commits, plus the helper de-duplication),
`NEWS.md` (scope disclosure + the corrected precision figure).
**Tests** — `tests/testthat/test-scale-equivariance.R` (**new** — the in-suite guard),
`tests/testthat/test-traits-keyword.R`, `tests/testthat/test-canonical-keywords.R`.
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

That run was **file-for-file identical to the `main` baseline** — the only failing files
were `test-m3-pilot-manifest.R` (16+2), `test-profile-derived-curves.R` (2) and
`test-tweedie-fixed-p.R` (1 err), all pre-existing. PASS rose 14129 → 14131.

**Then `origin/main` moved under the branch** (the AGHQ lane merged #875, 204 lines in the
same `R/fit-multi.R`). The baseline was therefore re-derived rather than reused — a stale
baseline is worse than none. Post-merge, on 347 files: `main` **18 fail / 3 err**, branch
**19 fail / 3 err**. The single difference is `test-aghq-multistart-convergence.R`,
analysed in §7a. `git merge` produced **no conflict in `R/`** — the two lanes' edits are in
different regions (~:3770 and ~:6360); the only collision was append-append in
`check-log.md`.

**`R CMD check` — partial, and labelled as such.** A *restricted* check was run locally
(`--as-cran --no-tests --no-vignettes --no-manual`): `Status: 2 WARNINGs, 1 NOTE`, where
both WARNINGs are artefacts of `--no-build-vignettes` (no `inst/doc` was built) and the
NOTE is the standard "New submission" plus the same missing vignette index. `checking
examples ... OK`, namespace OK. **A full `--as-cran` on this branch was NOT run this
session**, so the prior 0E/0W/1N is not re-established here — only that nothing in these
changes disturbs examples, namespace, Rd or NEWS parsing. The same check on Totoro is
useless for this purpose and should not be attempted there: the box lacks nine `Suggests`
packages, so the run aborts at the dependency stage before examining the package at all.

**Equivariance, preserved.** `dev/scale-equivariance-check.R` k = 100: every law OK
(6.35e-06 … 1.4e-05). `dev/851-scale-equivariance-comparators.R`: gllvmTMB **0/8** at both
k = 100 and k = 5000, worst case 0.0105, against gllvm 3/16 (worst 0.998) and glmmTMB
14/16 (worst 2.00) — reproducing the pre-existing numbers exactly.

## 5b. Rose's pre-merge audit, and what it changed

`AGENTS.md` requires a Rose cross-file consistency audit before merge on an
inference-machinery touch. It returned **NOT READY** with two blockers, both fair:

- **NEWS overclaimed by ~3 orders of magnitude.** It said scaling by 100 *or 5000*
  reproduced every transformation "to within about one part in 100,000". True at k = 100;
  at k = 5000 the measured worst case across eight seeds is 0.0105, i.e. about 1%. The
  figure had been inherited unexamined from an internal handover that stated it two
  sentences above its own contradicting table. Corrected to state both scales separately.
- **No validation-debt register row**, contrary to the register's own binding rule. Added
  as `MIS-35`.

Writing that row surfaced the more serious gap: **no test in the suite asserted the scale
law at all.** The entire headline claim rested on two opt-in `dev/` scripts, so a future
regression would have been invisible to CI. Closed by `test-scale-equivariance.R`.

## 6. Tests of the tests

`test-scale-equivariance.R` was checked to bite before being trusted, and the first two
drafts of it failed that check. A k = 100-only version passes on `origin/main` — the
pre-fix engine already held the law there — so it would have guarded nothing. A fixture
with unmodelled within-unit replication was mis-specified and drifted at both scales
regardless of the fix. The shipped version uses the comparator study's exact fixture and
**fails on `origin/main` with Lambda rel.err 0.99** (the loadings do not move at all when
the response is scaled by 5000), while k = 100 passes on both trees.

The re-fixtured assertions were checked to still bite: the rejected loadings-only fixture
fails them loudly (`|grad|` ~1e+11), and the retained `convergence == 0` checks now run on
a model where both trees converge cleanly with gradients three to four orders tighter
(6.85e-10 / 7.66e-07 on branch) than the fixture they replaced.

## 8. Consistency audit

Swept the neighbourhood for the same defect class. `init_rr_theta` had **two further
private copies** — `init_rr_theta_spde_lv` and `init_rr_theta_pkg` — each hardcoding
`0.5`. They are why two tiers escaped the original blast radius, by accident rather than
design. Consolidated in `ae6308d2` at Shinichi's request, as a separate commit from any
behaviour change; identity proved over all 820 `(p, rank)` pairs with `rank <= p <= 40`,
and the suite is unchanged down to the PASS count.

Rose's audit then found two the first sweep missed, both left for follow-up rather than
folded in:

- **`.gllvmTMB_default_rr_lambda`** (`R/init-warmstart.R:328`) hardcodes `0.5` with no
  reference to response scale — the same defect class, in the degenerate fallback of the
  opt-in `start_method = "res"`. Worse, that branch already computes a *scale-aware* Psi
  beside it, so it pairs a scale-blind Λ with a scale-aware Ψ: the imbalance this arc
  spent its effort removing from the default path, still present in the opt-in one.
  Bounded (opt-in, degenerate data only) but real, and not disclosed in NEWS.
- **`theta_dep_chol` / `theta_spde_dep_chol`** inline the same `log(0.5)` Cholesky-diagonal
  start in two places (`R/fit-multi.R:3895`, `:3961`) — the same un-centralised shape that
  made this bug invisible, one level down.

## 7a. Merge decision — READY on the evidence; merging is the maintainer's act

The deliverable was "PR #873 merged, or a written, evidenced decision not to." This is the
decision: **the branch is ready and I recommend merging it; I am not merging it myself,
because that specific act is reserved.**

Three of the four gates that were open when this section was first written have since been
closed on merit, not waived:

| gate | state |
|---|---|
| Suite vs `main` | **CLOSED.** 348 files, **18 fail / 3 err** — file-for-file identical to the re-derived `main` baseline (`test-m3-pilot-manifest.R` 16+2, `test-profile-derived-curves.R` 2, `test-tweedie-fixed-p.R` 1 err). PASS 14173 vs main's 14161. |
| Cross-lane AGHQ failure | **CLOSED on merit** — see below. Their test was not touched, and no action is needed from that lane. Shinichi separately approved editing it (his lean: assert the property rather than the number); that approval was **not used**, because the family gate removed the interaction entirely. His reasoning still stands as advice for whoever revisits that test on its own terms. |
| `R CMD check --as-cran` | **CLOSED. 0 errors, 0 warnings, 1 NOTE** (the standard "New submission"), vignettes built and examples run. The 348-file suite was verified separately on Totoro rather than inside the check. |
| Merge authority | **GRANTED by Shinichi, 2026-07-31**, together with authorisation to spend the 3-OS matrix. Both were withheld until then: `CLAUDE.md` limits agent self-merge to the enumerated low-risk set, which is documentation-shaped, and this changes `R/`; and the macOS/Windows legs bill at 10× and 2×, so triggering them is a spend decision. |
| 3-OS CI | Dispatched on the final SHA via `workflow_dispatch -f full_matrix=true` after that authorisation. |

**How the cross-lane failure was closed, because it matters more than the fact that it
was.** The AGHQ lane's new test pins a start-dependent objective, and #851 moved it. The
tempting fixes were both wrong: re-snapshotting their number, or arguing from my
measurement that their fit was "less runaway" and therefore fine. Neither addresses why my
change was touching that fit at all.

It should not have been. Every #851 measurement is **gaussian** — "multiply the response
by k" is only a meaningful perturbation of an unbounded continuous response. For a
binomial fit y is 0 or 1 and there is no response scale to get wrong. The start
nevertheless keyed off the working residual for every family, so it perturbed fits it had
no evidence to perturb. That is the *same* error as the original blast radius, one axis
over: this branch had already argued that five tiers must keep their historical start
because moving an unmeasured start trades a known problem for an unknown one — and then
did not apply that rule across families.

Gating on `all(family_id_vec == 0L)` restores the binomial cell **exactly** (379.7133 vs
main's 379.7134, loading-runaway ratio 29.700, max|Λ| 81.655 — identical) and costs the
gaussian result nothing: on a matched pair of runs the two-tier oracle is byte-identical
gated and ungated at both scales. So the cross-lane test passes on its own terms, and the
scoping rule is now consistent instead of nearly consistent.

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
