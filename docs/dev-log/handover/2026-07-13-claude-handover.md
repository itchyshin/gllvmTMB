# gllvmTMB — Claude → Claude handover (2026-07-13)

Meta: 2026-07-13 · from Claude · **supersedes** the 2026-07-12 covariance handover.
You are the next Claude. **Your job: ultra-plan and execute the 0.5→0.6 gap
closure.** Branch `claude/release-0.5.0`, work MERGED to `main` @ `8ec261bb`.

> ## 🔴 STEP 0 — BEFORE ANYTHING ELSE: OPEN THE CAPABILITY WIDGET
> Open `docs/dev-log/capability-surface.html` (live artifact
> https://claude.ai/code/artifact/46e611f2-69d1-48e1-8b8b-ccab2e89983d) and show
> it to Shinichi FIRST — it is the mission-control. Do not read further, plan, or
> touch code until you have surfaced the widget. This is a standing rule.

## Mission (the strategy shift — read this first)

- **0.5 is the "cover everything" development cycle.** We are NOT releasing 0.5.
  We accumulate as much of the `0.5.0 → 1.0` gap list as we can on the 0.5 line
  and **release at 0.6**. So: no CRAN submission now; keep building.
- **Next move (Shinichi's ask): ULTRA-PLAN the gap closure** (`skills/ultra-plan`),
  then execute. The gaps are the widget's "WHERE THE GAPS ARE" box (below).
- **Tag:** the premature `v0.5.0` tag was **DROPPED** (local + remote, 2026-07-13)
  — 0.5 is not a release. `main` @ `8ec261bb` is the 0.5 dev line (no release tag).

## Critical Context

- **The `||` uncorrelated random-slope coupling axis is COMPLETE** across all
  sources (phylo/animal/kernel/spatial) + source-tier latent — grammar +
  engine + recovery/target-matrix tests. This was the big 0.5-cycle arc. Detail:
  `docs/dev-log/after-task/2026-07-12-re-surface-arc-start.md` (turnkey, cited).
- **Scalar-collapse** (earlier this session): the grid is 3 modes {indep, dep,
  latent}; scalar = `common = TRUE` modifier; `*_scalar()` soft-deprecated. See
  `docs/dev-log/after-task/2026-07-12-scalar-collapse-three-modes.md`.
- **Package is CRAN-clean** (`R CMD check --as-cran` 0E/0W/1N benign) and the
  full non-heavy suite is **green (4541/0/0)**. Heavy recovery cells pass under
  `GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true`.
- **Design 79** (`docs/design/79-covariance-mode-taxonomy.md`) is the covariance
  spec; §7.2 now records the landed `||` cells. **Design 80**
  (`80-nongaussian-re-evidence-bars.md`) is the ML/REML/AGHQ evidence framework.

## What Was Accomplished (this session, 25 commits, all on main@8ec261bb)

pkgdown (sticky-navbar banner fix; articles confirmed pulled) · scalar-collapse
(`b101914e`) · rootogram gate fix (`640b895a`) · the full `||` arc: `indep||`
A0/A1 (`7d8ca4fe`), `latent||` A3 (`bf541444`), `dep||` parity-pin A2
(`bcd96888`), kernel slopes B1 (`7d8dc6d4`), spatial migration B2a (`e902f8bd`)
+ spatial `||` B2b (`93123ea0`) · families C1 lognormal+student (`a51e9704`) ·
`tweedie(p=)` + finding (`114ffa8b`) · singular-fit diagnostic (`49888366`) ·
`extract_Sigma` slope note fix (`904af87c`) · widget refresh · article `|`/`||`
docs (`8ec261bb`). drmTMB coordination issue posted: `itchyshin/drmTMB#776`.

## Current Working State

- **Working / green:** `main` @ `8ec261bb` == branch tip, pushed. Suite 4541/0/0,
  `--as-cran` clean.
- **Held files (CARRIED-OVER, Shinichi's disposition — NEVER commit):**
  `.Rbuildignore`, `.github/workflows/pkgdown.yaml`, `CONTRIBUTING.md`,
  `ROADMAP.md` (modified, uncommitted).
- **The `v0.5.0` tag exists (pushed)** — see Tag note above.

## The gap list to ultra-plan (the 0.5→0.6 / →1.0 work)

From the capability widget's "WHERE THE GAPS ARE" box — Shinichi wants to *try to
cover all of these*:

1. **Interval coverage — the headline gap.** Zero families have coverage-checked
   intervals; every cell is point-only. **Calibration is the largest task.** (Ties
   to Design 80; needs a coverage/ADEMP campaign — Totoro/DRAC candidate.)
2. **Random slopes finished.** `||` grammar is done, but the *recovery/coverage
   evidence* is the gap: tweedie/betabinomial slope recovery (tweedie is
   **ridge-independent-biased ~44%** — see `test-tweedie-fixed-p.R`; needs a bias
   diagnosis), ordinary no-prefix `latent||` (block-diagonal Λ), and the heavy
   `unit_obs`/`cluster2` tier slope engines (Tier-3, live-TMB — Codex lane).
3. **Missing responses.** nbinom1 recovery + `mi()` predictor coverage pending.
4. **Fitted diagnostics across more families.** Currently Gaussian/Poisson/NB2;
   extend residual/predictive checks.
5. **Categorical** — major development (nominal early-stage).
6. **REML non-Gaussian / weighted / missing-data** — Gaussian-only pilot now.
7. **Delta/hurdle latent-scale correlation** — needs a reporting convention.
8. **AGHQ** (Design 80 Bar-3) — calibrated non-Gaussian variance; unbuilt.

## Next Immediate Steps

1. **Show the capability widget** (STEP 0 above) — always first.
2. **Ultra-plan the gap closure** (`skills/ultra-plan`): decompose the list above
   into slices, sequence by leverage (interval coverage is the headline; it likely
   needs a compute campaign). Recommend interval-coverage first (biggest, gating
   the "point-only" caveat everywhere), then the random-slope recovery evidence.
3. Execute slice-by-slice, verified + committed, per the session discipline
   (recovery cells under `GLLVMTMB_HEAVY_TESTS=1`; #388 = validate before you
   advertise a family; full-suite closure summing the `error` column, not just fail).

## Key Decisions & Rationale

- **`dep||` = Σ_int⊕Σ_slope via a Cholesky *parity* pin** (`dep_chol_parity_pins`,
  `R/lambda-constraint.R`): pin strictly-lower L(i,j) with parity(i)≠parity(j). NOT
  a contiguous block-size. Target-matrix verified. This is the one subtle cell.
- **tweedie/betabinomial stay OFF the slope allowlist** — tweedie's ~44% slope-SD
  over-estimate is not the p↔φ↔σ ridge (fixed-p tested, identical). #388: validate
  before admitting.
- **No parallel platform lanes** (brain note): one lane all the way, then hand off.
  In-lane sub-agent fan-out is fine. The RE arc needed zero new C++ (Claude ran it
  end-to-end); the `unit_obs`/`cluster2` tier engines DO need live TMB (Codex).

## Blockers / Open Questions

- Interval-coverage calibration is a research-grade campaign (compute).
- tweedie slope bias needs a diagnosis (Laplace? small-sample?).
- The pkgdown/doc honesty **one-by-one review with Shinichi** is still undone — a
  gate before ANY eventual 0.6 CRAN submission.

## Gotchas & Failed Approaches

- Report field is **`cor_b_mat`** (not `cor_b`); slope variance is **`sd_b`**
  (length 2T interleaved int/slope). Spatial: `sd_spde_b`, `theta_spde_dep_chol`.
- Heavy tests skip unless **`GLLVMTMB_HEAVY_TESTS=1` AND `NOT_CRAN=true`**.
- `extract_Sigma` for slope fits uses **`level = "phy"` / `"spde"` / `"kernel"`**
  (the default level errors). It works + labels correctly for all `|`/`||` cells.
- Full-suite closure MUST sum the **`error`** column too — the rootogram fail hid
  in `error` (not `failed`) and a naive `sum(failed)` reported false-green.
- Mesh must be built on the **long-format** data passed to `gllvmTMB()` (not the
  deduped coords), else "projection has N rows but the data has M".
- Spatial can be verified locally with **`fmesher` (installed) — NOT INLA**.

## How to Resume

1. Read this doc → `docs/dev-log/after-task/2026-07-12-re-surface-arc-start.md`
   (turnkey recipes) → Design 79 §7 + Design 80 → the capability widget
   (`docs/dev-log/capability-surface.html`; live artifact
   https://claude.ai/code/artifact/46e611f2-69d1-48e1-8b8b-ccab2e89983d — show it first).
2. Invoke **`skills/ultra-plan`** on the gap list above. Spawn a Rose /
   statistical-reviewer lens before any "cell covered" claim.
3. Live R/TMB recovery + coverage campaigns → consider Totoro/DRAC; Codex runs the
   live toolchain for the heavy `unit_obs`/`cluster2` tier engines.

One-command resume (paste in your authenticated terminal, from the repo root):

```
claude "FIRST open and show me the capability widget (docs/dev-log/capability-surface.html), then rehydrate from docs/dev-log/handover/2026-07-13-claude-handover.md + the AGENTS.md snapshot and ultra-plan the 0.5→0.6 gap closure (interval coverage is the headline)."
```

## Mission control

| Area | State | Next by leverage |
|---|---|---|
| **`\|\|` coupling axis** | COMPLETE (indep/dep/latent, all sources) + tested | recovery/coverage *evidence* is the remaining gap |
| **Interval coverage** | point-only everywhere (0 families coverage-checked) | **headline 1.0 task** — calibration campaign (compute) |
| **Families (slopes)** | +lognormal/student; tweedie/betabinom gated | diagnose tweedie bias; nbinom1 recovery |
| **Diagnostics** | Gaussian/Poisson/NB2 | extend residual/predictive checks to more families |
| **Categorical / REML / delta-hurdle / AGHQ** | early-stage / Gaussian-only / design-gap / unbuilt | the deep 0.6→1.0 lanes |
| **Release** | `main` @ `8ec261bb`; **NOT releasing 0.5** (v0.5.0 tag dropped) | release at **0.6**; doc honesty review is the gate |

Branch `claude/release-0.5.0` == `main` @ `8ec261bb`, pushed. Nothing half-done.
The `||` arc is complete and green; the gap list is the next campaign. Good luck. 🧬
