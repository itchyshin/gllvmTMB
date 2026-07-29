# VGH — implementation plan

**2026-07-29 · Claude · branch `claude/vgh-variational-20260729` (pushed)**

Scope: a **fast internal engine plus Laplace hand-off**, NOT VA parity.
Design 108 sizes full parity at 26–42 working days; this is 6–13 days to the end
of Phase 3 because it skips everything parity requires — no `method=` argument,
no `summary`/`confint`/`predict`/`getLV` methods, no model-selection surface, no
missing data, no new families.

**Lane constraints throughout.** LANE 1 owns `NAMESPACE`, `NEWS.md`,
`R/profile-ci.R`, `R/coverage-study.R`, `R/confint-inspect.R`,
`R/z-confint-gllvmTMB.R`, `R/aghq-control.R`, `R/aghq-report.R`, `R/imports.R`.
`R/fit-multi.R` and `R/gllvmTMB.R` are **SHARED — coordinate before editing**.
**Do not run `devtools::document()`.** Never `git add -A`.

---

## Phase 0 — decide (½–1 day) · GATED

The one measurement missing. Every recovery comparison so far is cross-DGP: my
numbers and the repo's come from different simulations, so they cannot be
compared. This settles whether VGH is an *engine* or only a *comparator*.

**0.1 Matched head-to-head.** VGH vs `va_r3` (`eval_method = "gh"`) on **identical
simulated data, identical seeds**. Binomial-logit and Poisson-log, n ∈ {200, 400,
800}, T = 20, q = 2, H/Q = 15, ≥10 seeds per cell. Report **both**:
* wall time,
* recovery — relative Frobenius error on `Lambda Lambda'` **and** attenuation
  `||Lambda_hat||_F / ||Lambda_true||_F`.

**🔴 KILL CRITERION.** If VGH's recovery is materially worse than `va_r3`'s on
matched data, **stop**. A faster route to a worse answer is not worth building.
Report the number either way.

Note the sign question this also settles: Design 109 argues the Gaussian-VA
channel makes exact-GH **over**-estimate `Sigma_B`, while my unmatched probe
measured attenuation slightly **below** 1 (0.9908 / 0.9656). One of those is
wrong. `109` warns that getting this sign wrong is already a recorded mistake in
this repo.

**0.2 Governance (parallel, docs-only, no compute).**
* Replace the eight phantom **"Design 160"** citations in `docs/design/106`, `107`,
  `108` with (a) `docs/design/72:145-154`, the real origin of the
  "variational coordinates as ordinary TMB parameters" decision, and (b) the
  2026-07-29 A/B measurement in `dev/vgh/ab-runs/`, which now settles the
  architecture question empirically. Three of the eight are vetoes aimed at this
  engine.
* File the `Q_gg` structured-prior derivation as an issue, pointing at
  `docs/dev-log/2026-07-29-vgh-structured-stationarity.md`.

**Deliverable:** go / no-go, with a number.

---

## Phase 1 — the engine, internal (3–5 days)

**1.1** Port `dev/vgh/vgh-engine.R` → `R/va-vgh.R`. **All internal, dot-prefixed,
no exports, no `NAMESPACE` change.**

**1.2** Accept `va_r3`'s existing data contract — `(y, n_trials, X, unit_id,
trait_id, N, T, q)` — so it drops into plumbing that already exists rather than
inventing a second one.

**1.3** Close the two known gaps:
* **`n_trials`** — `vgh_elbo()` has no such argument today, so the binomial entry
  point is Bernoulli-only (found by the cross-check).
* **per-trait dispersion** for gaussian, to match `latent(..., unique = FALSE)`
  semantics rather than the current free per-trait `phi`.

**1.4** Fail-closed guards mirroring `va_r3:196-201` — structured tiers,
`unique = TRUE`, `psi`, `missing`, `lv`, `provider`, `q > 6`, non-admitted links.
Refuse loudly; do not silently approximate.

**1.5 Tests — reuse the harness, write no new infrastructure.** One file,
`tests/testthat/test-vgh-oracle.R`, mostly lifted from
`dev/vgh/crosscheck-va-r3.R` and `dev/vgh/vgh-validate.R`:
* gaussian ELBO == exact marginal log-likelihood (tol 1e-10) — the absolute oracle;
* cross-check against the TMB `va_r3` GH template at fixed parameter points
  (tol 1e-12), including the five **negative controls** that proved the check has
  power (row-major `Lambda`, `L_i'L_i`, flipped KL sign, missing `sqrt(2)` node
  scaling, unnormalised weights);
* ELBO monotonicity on all three families.

**🔴 The test must not read anything under `docs/`.** `.Rbuildignore:18` contains
`^docs$`, so such a file is absent from the tarball — this is exactly the live
defect in `tests/testthat/test-eva-gate1.R`. Ship fixtures under
`tests/testthat/` or `inst/`.

**Run `rcmdcheck`, not just `devtools::test()`.** `load_all()` cannot catch
namespace or packaging defects, which is how both the `.onLoad` bug and the
`docs/` dependency survived 7,872 green tests.

---

## Phase 2 — the hand-off (2–3 days) · **this is what makes it valuable**

The reported estimate stays the **Laplace MLE with Laplace SEs**, so every VA
recovery and attenuation concern stops applying to the published number.

**2.1** Rotation matching. `Lambda` is identified only up to rotation, so VGH's
estimate must be mapped into the Laplace parameterisation's lower-triangular
convention before it can serve as a start.

**2.2** `Psi` initialisation. VGH covers `Sigma = Lambda Lambda'` with **no `Psi`**,
while ordinary `latent()` carries `Psi` by default — initialise it separately.

**2.3** Wire as start values. Touches `R/fit-multi.R`, which is **SHARED with
LANE 1 — coordinate first.**

**2.4 The deliverable number:** Laplace outer-iteration count and wall time, with
and without the warm start, on matched data, with the final estimates verified
identical.
**Success criterion: ≥1.5× end-to-end at an identical optimum.**

---

## Phase 3 — the screen (1–2 days) · possibly the highest-value output

This is the one argument Design 108 says survives, and it does **not** require VA
to be a good estimator.

**3.1** Expose VGH's health status as a degenerate-fit detector.

**3.2** Measure it against the two recorded failures of the incumbent:
* *"8 of 20 Laplace fits (40%) diverged to a degenerate loading — off by 2–5
  orders of magnitude — while reporting a clean convergence code and
  `pdHess = TRUE`"* (Design 108);
* 59 of 70 degenerate Laplace fits reported `convergence = 0` across the 640-cell
  sweep, while VA never reported a clean status on a degenerate fit.

VA's KL-to-prior term is an implicit regulariser — that is *why* it labels its own
bad fits. This is the prior/ridge mechanism already built into the objective, and
it needs no tuning.

---

## Phase 4 — EDA surface (2–3 days, OPTIONAL, only if 1–3 land)

Needs maintainer sign-off: a new public route is a high-risk change under
`ROADMAP.md`'s discussion-checkpoint list.

Fences, non-negotiable:
* **no `logLik` / `AIC` / `BIC`** — the ELBO is a bound, not a likelihood, and
  Design 85 §10 prohibits selecting rank `q` by ELBO;
* **no intervals** — nothing in gllvmTMB has certified coverage;
* no internal register codes on any reader-facing surface.

---

## Explicitly deferred

**See `2026-07-29-vgh-coverage-map.md` for the full family/structure map** — it
records that the recorded *"4 of 16 families"* is too pessimistic (the real figure
is **13–14 of 16**), that phylo/animal/kernel/pedigree are reachable via the
`Q_gg` derivation, and which items are genuinely unfixable. It also lists the
three things to do first when this arc resumes.

| item | why |
|---|---|
| Structured tiers (phylo / animal / kernel) | Derivation recorded (`2026-07-29-vgh-structured-stationarity.md`); only `Q_gg` enters, so it *will* work — but not needed for Phases 0–3 |
| Spatial / SPDE | A genuinely different problem. The projection spans ~3 mesh nodes, so a node-factorised `q` mis-states `v` for every observation; the correct fix needs a differentiable partial inverse that Design 106 calls *"an open engineering question, not a plan"* |
| The other 27 families | Reachable in principle by the same 1-D rule (Designs 104–105) |
| delta / hurdle / zero-inflated | **Structurally excluded** — two linear predictors share `u_i`, so the collapse needs a 2-D quadrature |
| multinomial | **Structurally excluded for VA** — needs a `K-1`-dimensional integral over category contrasts |

---

## Effort

| phase | days | gate |
|---|---|---|
| 0 decide | 0.5–1 | **kill criterion on matched recovery** |
| 1 engine | 3–5 | oracle tests + `rcmdcheck` |
| 2 hand-off | 2–3 | ≥1.5× end-to-end, identical optimum |
| 3 screen | 1–2 | beats the 40% silent-divergence baseline |
| **subtotal** | **6.5–11** | |
| 4 EDA surface (optional) | 2–3 | maintainer sign-off |

Against Design 108's **26–42 days** for parity. The difference is entirely scope.

---

## Two free levers, independent of all of the above

1. **Use `Q = 9`.** Measured: relative error and attenuation are identical to four
   decimals at `Q` ∈ {9, 15, 21, 31}; only cost changes (2.37 s vs 6.11 s).
   **2.6× for nothing.**
2. **Make the `Psi` tier trait-diagonal.** Exact by Design 106 Proposition 2 — the
   off-diagonal blocks are *provably* zero at the optimum, so this loses nothing.
   Cuts Ayumi's model from 2,034,669 coordinates to 280,644: **7.25× at zero
   accuracy cost.** This helps the **existing** engine too, and does not depend on
   VGH at all.

---

## What must not be claimed at any phase

* That VGH is more accurate than Laplace — not measured.
* That the mathematics is novel — it is not (Ormerod & Wand 2012; Opper &
  Archambeau 2009; Hui et al. 2017). Only the optimisation architecture is.
* Any interval or coverage property.
* That this reopens VA as an estimator. It does not; the recorded freeze was on
  **coverage** (4 of 16 families), which speed does not change.
