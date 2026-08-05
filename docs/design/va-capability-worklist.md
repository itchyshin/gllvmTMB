# Capability worklist — VA/LA uncertainty surface

**Standing maintainer direction (2026-08-03): keep building capability, not only evidence.**
Recorded here so it survives the session. Every item below is **evidence-backed from today's
work** — each cites the finding that identified it, so nothing here is a guess about what
might be useful.

Ordering principle: the shipping engine first. gllvmTMB 0.6 ships **Laplace-only as the
DEFAULT**; the VA route is a fenced research spike. So a gap on the Laplace surface is worth
more to a user today than a new VA capability, whatever the VA arc's headline is.

> **Corrected 2026-08-05.** This paragraph previously said "integration fence shut". That was
> factually wrong. The fence is **open inside a measured region and hard-fails outside it**:
> `.gllvmTMB_integration_fence_limits()` (`R/integration-fence.R:46-56`) admits
> **binomial-logit, poisson-log and gaussian-identity** at `q <= 2`, `p <= 80`, `n >= 100`,
> `unique = FALSE`. The same sentence's `default_tier = "gh"` held for gaussian and poisson but
> **not** for binomial, whose `default_tier` is `"jj"` (`R/va-r3-proto.R:1186-1189`).
> The ordering principle itself is unchanged — only the description of the fence was wrong.

## Tier 1 — the shipping engine, and both are BUILD gaps not structural ones

| # | gap | evidence | why it is small |
|---|---|---|---|
| 1 | **`getLV(se = TRUE)` covers only ONE random-effect family** (ordinary latent scores, `z_B`/`z_W`). Phylo, spatial and random-intercept blocks have the *identical* `sdreport`-computed SEs already sitting in `fit$sd_report` with **no accessor**. | `docs/design/va-latent-uncertainty.md` §1, §6 | The numbers already exist and are already computed at fit time. This is exposing them, not deriving them. |
| 2 | **`predict()`-level fitted-value SEs are entirely absent** from the Laplace engine. | same doc, §1 | Genuinely new machinery, but standard: delta method on the linear predictor from the existing `sdreport` covariance. |

**Why these matter:** the same synthesis measured per-unit latent SEs varying 0.47–32.8
across 40 units under Laplace — real, informative, machine-verified uncertainty that users
cannot currently reach for most random-effect types.

## Tier 2 — VA interval surface (prerequisites for the coverage campaign)

| # | gap | evidence |
|---|---|---|
| 3 | **`fixed_idx` excludes the variance parameters.** `which(nm %in% c("beta", "theta_rr"))` at `R/va-r3-proto.R:1632` and `:1777` leaves `log_sigma` and `log_sd_tier` outside the Schur block, so **VA-Wald cannot produce an interval for any variance component**. | Coverage-campaign design, self-identified flaw #21 — named there as an explicit prerequisite |
| 4 | The four interval routes — Wald-from-Schur, sandwich, bootstrap, profile. | in flight; profile may prove unbuildable (an ELBO has no χ² calibration) |
| 5 | **`extract_Sigma(part = "unique"/"psi")` returns an all-NA diagonal** where `total`/`shared` are finite. | claims ledger, "Open and honestly unresolved" — filed, not fixed |
| 6 | No `predict` / `ranef` / `extract_Sigma` methods for class `gllvmTMB_va`. | `R/va-routing.R:413-416` — deliberately disjoint today; only worth building **after** the fence question is settled |

## Tier 3 — separate lane, already sequenced

| # | item | note |
|---|---|---|
| 7 | **Ordinal family for the VA engine (Item 1B).** The VA template has family codes 0–4 and **no ordinal family at all**. | Maintainer already sequenced Design 108 Stage 5 behind it. Cut-points and a stable `log(Φ(a) − Φ(b))` already exist in the *shipped* engine (`src/gllvmTMB.cpp` fid 14, `gll_log_pnorm_diff` at `:106`) — reusable structure, but a new family code either way. **Different subject: its own lane.** |
| 8 | **VA → LA warm start** (the maintainer's "idea 1", deferred since 2026-05-18). | Two hooks exist: `control$start_from` (public, object-shaped) and `control$vgh_warm_start` (internal, and the closer precedent). `theta_rr` → `theta_rr_B` packing verified identical. In flight. |

## Two standing cautions, both paid for today

1. **Capability is not evidence.** This lane already carries the A_i collapse, the warm-route
   repair and four interval routes — none validated by a coverage campaign. Building more
   surface makes the eventual validation *larger*, not stronger. Keep Tier 1 (which ships and
   is validated machinery being exposed) ahead of Tier 2 (which is not).
2. **Check before building.** Twice today a plan reversed under checking: `init_strategy` was
   the wrong warm-start hook (it seeds `log_phi_*` only, a no-op for binomial), and VA-Profile
   was judged undeliverable after being pitched as the prize. Read the code before costing the
   work.

> Related: `va-latent-uncertainty.md` · `va-interval-coverage-campaign.md` ·
> `va-warmstart-la-recon.md` · `ai-collapse-design.md` · `20-CLAIMS-LEDGER.md`

---

## Campaign sequencing decision — LA-Bootstrap is DEFERRED, not cancelled (2026-08-03)

**Maintainer asked: "do we need LA-bootstrap?"** Answer: not up front.

Sized from today's measured per-fit costs at the 150-core budget:

| tier | work | core-hours | wall-clock |
|---|---|---|---|
| Step-0 pilot | 30 seeds/cell | <1 | minutes |
| Tier 1 | 1000 seeds × 3 arms × ~4 cells | ~50 | ~25 min |
| Tier 2 | LA-Profile, 300 seeds × 2 cells | ~120 | ~50 min |
| **Tier 3** | **LA-Bootstrap, 100 seeds × 500 refits** | **~330** | **~2.2 h** |

**Tier 3 is 55% of the compute for the least informative tier.** Three reasons to defer it:

1. **No oracle floor.** The campaign's own adversarial flaw list records this as an accepted
   gap: *"No oracle floor for Profile/Bootstrap — FIXED for Profile (small n=5000 pilot
   added); ACCEPTED as a gap for Bootstrap."* We would not know what a perfect fit scores.
2. **Weakest power of any tier.** 100 seeds → 2·MCSE = 4.36 pp, difference band 6.16 pp. It
   detects gross brokenness only, not the subtle miscalibration that is the actual question.
3. **It does not bear on the primary question**, which is whether *VA's* intervals are honest.
   LA-Wald is the necessary contrast; LA-Profile is the differentiator gllvm and galamm lack;
   LA-Bootstrap is a third LA variant.

**But it keeps real option value and must not be deleted:** bootstrap is the only route that
assumes *neither* the ELBO's curvature nor the information-matrix equality. If Tier 1 shows
Wald under-covering **and** the sandwich route fails to rescue it, bootstrap becomes the
remaining candidate and is worth its 2.2 h at that point.

**DECISION: run Tiers 1+2 first (~75 min), read the result, then launch Tier 3 only if the
first two leave a question it can settle.** Conditional sequencing, not a coin-flip up front.
