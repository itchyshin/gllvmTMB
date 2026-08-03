# Capability worklist — VA/LA uncertainty surface

**Standing maintainer direction (2026-08-03): keep building capability, not only evidence.**
Recorded here so it survives the session. Every item below is **evidence-backed from today's
work** — each cites the finding that identified it, so nothing here is a guess about what
might be useful.

Ordering principle: the shipping engine first. gllvmTMB 0.6 ships **Laplace-only**; the VA
route is a fenced research spike (`default_tier = "gh"`, integration fence shut). So a gap on
the Laplace surface is worth more to a user today than a new VA capability, whatever the VA
arc's headline is.

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
