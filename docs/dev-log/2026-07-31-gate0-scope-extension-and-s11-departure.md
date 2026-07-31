# Scope freeze — Gate 0 extended to Bernoulli and to `q = 4`, plus a recorded §11 departure

**Date:** 2026-07-31. **Authority:** Shinichi Nakagawa, in session. **Recorded by:** Claude Code.
**Status:** a fresh Gate 0 scope freeze, written **before** the Gate 3 campaign runs. Three decisions,
one of which is an explicit departure from Design 85 §11 and is labelled as such.

Design 85 remains **READ-ONLY**. This note supersedes its scope on two axes by a new dated record; it
does not amend that document.

---

## Decision 1 — the data contract is extended to Bernoulli (`n_trials >= 1`)

**Design 85 §2 previously excluded it:** *"The data are complete multi-trial binomial data:
`n_it ∈ {2,3,…}` … There are no … single-trial Bernoulli rows"*, and Gate 0's NO-GO list named
*"trial count below two"*.

**Why the exclusion existed, and why it no longer binds.** Bernoulli is where separation bites. With
pure 0/1 responses a separated fixed-effect design drives `beta` — and therefore the ELBO's optimum —
to infinity, while every finite-precision health check still reports success. That hazard was
unguarded, so excluding the data was the only safe move available.

**It is now guarded.** `.va_r3_check_separation()` landed in this lane (`08010b02`): a fail-closed
detector on the marginal logistic regression `y ~ X - 1`, refusing complete and quasi-complete
separation by **divergence** rather than by a magnitude threshold — the marginal IRLS is run twice,
four orders of tolerance apart, and a coefficient that moves with the tolerance has no finite
maximum-likelihood value. Six tests; the existing prototype suite unchanged at 352 passed.

**Why the extension is worth making.** `decisions.md` **A3** names VA's purpose in this package as
*"high-$d$ **binary** JSDM … the regime where Laplace genuinely degrades"*. Binary means
presence/absence, i.e. Bernoulli. A VA engine fenced to multi-trial only would not cover the use case
that motivates its existence. VA handles Bernoulli perfectly well mathematically — JJ/Pólya-Gamma is
exact at any trial count and gllvm's VA does binary routinely — so the exclusion was always a scope
freeze, never a limitation of the method.

**What this admits:** `n_trials >= 1`, binomial-logit, with the separation guard active. Everything
else in Design 85 §2 stands unchanged: complete cells, no response masks, no case weights, no
offsets, no fractional successes, no trait-specific links, `X` fixed and full column rank, and
byte-identical response cells / trial counts / `X` / family / link / starts / optimiser policy across
every arm and rank candidate.

**Note on `main`.** `R/va-r3-proto.R` has been admitting `n_trials >= 1` since PR #797 **without** the
guard. This decision makes the code's behaviour and the design contract agree for the first time,
rather than leaving the code ahead of the contract.

---

## Decision 2 — the fence rises to `q <= 4`, and Gate 3's design is extended to earn it

The 2026-07-20 audit refused precisely this advance: its stated claim boundary was *"whether the
internal Gaussian-VA experiment may advance from q=1/q=2 references to q=4/q=6 stress"*, decision
**NO-GO**. That refusal was on **execution**, not on the estimator — the runner selected rank by ML
before fitting VA, which is the Gate-4 hand-off design rather than the fixed-rank Gate-3 comparison,
and failed fits were excluded from denominators.

**So the advance is earned by fixing those two defects and measuring, not by assertion.** Gate 3's
pre-registered design is extended to `q ∈ {1, 2, 4}`, with rank **fixed at the planted `q`** and
**every attempted fit in the denominator**. `q = 6` remains out of scope.

`q <= 4` ships **only if the `q = 4` cells pass on their own terms.** A pass at `q ∈ {1,2}` does not
license a `q = 4` fence — that would be exactly the "later gate compensating for an earlier one"
that §11 forbids.

**Honest note on the target regime.** A3 names **5+ latent factors**. `q <= 4` still does not reach
it. This extension narrows the gap between what we ship and what motivates shipping it; it does not
close it.

---

## Decision 3 — 🔴 an EXPLICIT DEPARTURE from Design 85 §11

**§11 states:** *"Gates are sequential. A later gate cannot compensate for a failed earlier gate, and
**tolerances cannot be widened after seeing the result**."*

**The decision taken:** the campaign reports **both** raw `RMSE_ml` and a trimmed variant, and the
rule that feeds the pass/fail verdict is chosen **after** those numbers are seen.

**This is a departure from §11 and is recorded as one, not presented as compliance.** It was put to
the maintainer with that consequence stated on the option itself, and taken knowingly.

**Why the question arose.** The pass rule is *"VA … no more than `0.05` worse in absolute terms than
ML."* Recomputed from `dev/totoro-grid/results/grid.csv`, `gtmb_laplace`'s signed scale
`kappa = tr(Sigma_hat)/tr(Sigma_true)` has median **1.039** and maximum **1,524,039**. During the
Gate-3 smoke, five debug seeds gave Laplace `kappa` from 3.1 to 1,430 with `convergence = 0` and
`pdHess = TRUE` on every one. If `RMSE_ml` is outlier-dominated, *"no more than 0.05 worse than ML"*
becomes trivially passable — VA would clear a bar ML itself is failing, and the gate would certify
nothing.

**The mitigation, declared NOW to bound the exposure.** A post-hoc choice among *unlimited* rules is
unbounded; a post-hoc choice between *two pre-specified* rules is not. **Exactly these two candidate
rules are admissible, and no third may be introduced later:**

- **R1 — raw.** `RMSE_ml` over every replicate with finite output, no exclusions. The pass rule read
  literally.
- **R2 — paired exclusion.** Replicates where **ML** is degenerate by the two-sided detector
  (`rel_frob > 10` **or** `kappa < 1/3`) are dropped, **applied identically to both arms** so the
  comparison stays paired. This is the *conservative* direction: removing ML's disasters makes VA's
  bar harder, not easier.

Both are computed and reported for every cell. Whichever is chosen, the **other is published beside
it**, and the verdict states which rule it used and why. Nothing else about the pass rule — the
`0.05` tolerance, the 5% axis-collapse rate, the fixed truths, the seeds, the cells, the denominator
— moves at any point.

---

## Consequences for the pre-registered design

- `q ∈ {1, 2, 4}`; `p ∈ {8, 20, 80}`; `n ∈ {100, 400}`; 3 truths; seeds 1:40 → **2,160 datasets
  × 3 arms = 6,480 fits.**
- Binomial-logit at **`n_trials = 1`** (Bernoulli — the A3 regime), with the separation guard active.
  Guard refusals are a recorded status **inside the denominator**, never a dropped row.
- Arms unchanged: `va_gh`, `va_jj`, `ml_laplace`. **The estimator is decided by this campaign, not
  before it** — `default_tier` stays untouched until the gate reports.
- Everything already binding stays binding: no filtering on `status`/`admitted`; continuous
  `max_projected_variance` recorded rather than the collapsed label; MCSE between replicates; signed
  `kappa` beside every error metric; health is recovery against truth, never convergence.

> Related: `docs/dev-log/2026-07-30-gate3-preregistration.md` (the frozen spec this amends) ·
> `docs/dev-log/2026-07-30-va-ships-in-06-reversal.md` · `LOOP/GOAL.md` Amendment 4 ·
> `docs/dev-log/audits/2026-07-20-va-r3-pilot-no-go.md` ·
> `docs/design/85-highdim-nongaussian-va-formal-contract.md` §§2, 10, 11 (READ-ONLY)
