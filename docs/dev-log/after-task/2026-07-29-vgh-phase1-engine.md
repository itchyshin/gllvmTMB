# After-task — VGH Phase 1: the internal engine

**2026-07-29 · Claude · branch `claude/vgh-phase1-20260729` (pushed)**

## Scope

Port the validated block coordinate-ascent variational engine from
`dev/vgh/vgh-engine.R` into `R/` as an internal, unexported engine, with SQUAREM
acceleration, `n_trials` support, fail-closed guards, and an oracle test file
carrying no `docs/` dependency. Executed against the approved ultra-plan
(`~/.claude/plans/memoized-growing-sparkle.md`).

## Outcome — DONE

`R/va-vgh.R` (internal, `.vgh_*`, no roxygen, no NAMESPACE change) and
`tests/testthat/test-vgh-oracle.R` (27 assertions, all fixtures inline).

**The headline defect is fixed.** Phase 0 found 34 of 36 poisson fits hitting a
sweep cap. Two causes, both addressed:

* **SQUAREM acceleration** (Varadhan & Roland 2008) on the model block, guarded
  on the ELBO so it can never decrease it. Poisson n=120, T=8:
  **450 sweeps / 0.69 s → 77 sweeps / 0.12 s**, at the same ELBO
  (2804.239764 vs 2804.239767 — the accelerated run marginally *higher*).
* **The stopping rule was backwards.** It judged the increment relative to
  `|ELBO|`, so it *loosened* as n grew. Now judged **per observation**.

**Poisson recovery on Phase 0's own DGP** (6 seeds, medians) — the gap closes,
and at the two larger sizes overtakes `va_r3` GH:

| n | Phase 0 (capped) | now | `va_r3` GH |
|---:|---:|---:|---:|
| 200 | 0.1767 | 0.1547 | 0.1611 |
| 400 | 0.1305 | 0.1047 | 0.1047 |
| 800 | 0.1162 | **0.0626** | 0.0749 |

Attenuation 1.007–1.008 (previously undershooting in 36/36 paired seeds);
median sweeps 142–170 against a 4000 cap; all converged.

## A real bug, caught by the oracle rather than by inspection

`.vgh_long_to_wide()` wrote a **row-major** linear index into R's
**column-major** matrix, silently scrambling `Y` across units and traits. It
raised no error — it simply fitted the wrong dataset, and every fit still looked
plausible.

It surfaced because the gaussian exactness oracle returned an ELBO **above** the
exact marginal log-likelihood, which a lower bound cannot do. Fixed to
`trait_id * N + unit_id + 1`; the round-trip is now exact and the oracle reads
**1.35e-15**.

That is the argument for building the oracle before the engine: the check that
caught it is the one that could not be satisfied by a plausible-looking wrong
answer.

## Checks

| check | result |
|---|---|
| reshape round-trip (n ≠ T, so a transpose cannot hide) | **exact, 0** |
| gaussian ELBO == exact marginal log-likelihood | **1.35e-15** |
| monotone ELBO — gaussian / poisson / binomial | min increment > −1e-8 |
| SQUAREM: same optimum, strictly fewer sweeps | pass |
| exact families invariant to quadrature order Q | 1e-9 |
| `n_trials` > 1 admitted; `y > n_trials` refused | pass |
| fail-closed: unique/psi/structured/lv/missing/provider/family/link/q | pass |
| GH rule is probabilists'; normal moments to k=6 | 1e-10 |
| **27/27 from the INSTALLED package** (built tarball, temp lib, namespace env) | pass |
| `docs/` reachable from the installed tree | **FALSE** |
| `grep -c -i vgh NAMESPACE` | **0** |

The installed-package run is the one that matters: `devtools::test()` cannot
catch the packaging defect class, which is exactly how `test-eva-gate1.R`'s
`docs/` dependency and the earlier `.onLoad` bug both survived 7,872 green tests.

## Design decisions

* **Long-format contract**, mirroring `.va_r3_validate_data()`. Following the
  EVA precedent, the validator's *shape* is duplicated (each engine's admitted
  surface differs) while the shared primitive `.va_r3_normalise_index()` is
  called directly.
* **Probabilists' quadrature**, any `Q ≥ 1` — not `.va_r3_gh_rule()`'s
  physicists' convention restricted to {15, 25, 61}, because Phase 0 measured
  Q = 9 sufficient for recovery and that restriction would forbid it. The two
  rules were previously verified node-for-node by agreeing on the
  *discretisation error itself* at H = 15.
* **Gaussian dispersion is fixed** at `gaussian_sd^2` by the contract, as in
  `va_r3` — not estimated per trait as the prototype did.
* **SQUAREM on the model block only**; the variational block is re-solved at
  whatever point is accepted, so extrapolation never yields an inconsistent
  `(θ, q)` pair.

## Not done — carried forward

* **Rotational identifiability is still unhandled.** `Lambda` is dense and
  unconstrained; `va_r3` packs it lower-triangular. An explicit modelling
  decision, and it gates the Phase 2 hand-off into Laplace's convention.
* **Not wired into `R/approximation-engine.R`** — that file hardcodes two
  engines into `match.arg`/`switch`. Reachability needs a regime entry plus
  `.approximation_engine_vgh_fit()`. Deliberately deferred: this arc adds no
  reachable surface.
* **`nbinom2` not admitted** (fail-closed), nor structured tiers, nor spatial.
* **Full `rcmdcheck --as-cran` not run** — the targeted installed-package test
  was run instead. The full check should run before any merge.
* Seeds 3 and 8 from the Phase 0 poisson grid were flagged as bad at every n and
  have not been investigated separately.

## Do not claim

More accurate than Laplace (not measured) · novelty of the mathematics (Ormerod
& Wand 2012 Appendix A.3; Opper & Archambeau 2009; Hui et al. 2017 for the
probit case — only the optimisation architecture is this package's) · any
interval or coverage property · that this reopens VA as an estimator.

## Follow-up

Phase 2 (Laplace hand-off) and Phase 3 (degenerate-fit screen) per the plan.
Phase 2 must resolve the rotation question first.
