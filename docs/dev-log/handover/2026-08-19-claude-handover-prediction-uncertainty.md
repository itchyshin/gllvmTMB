# Claude → next session handover — 2026-08-19
## Two arcs: the SDM article set (CLOSED) and prediction uncertainty (STARTED, ~45%)

**START BY RUNNING** `bash ~/shinichi-brain/tools/lane_preflight.sh "<repo>"`. Ten lanes
were live at handover. Then reconcile this file against `git log origin/main` and classify
every item `OWED` / `DONE` / `BLOCKED`.

> **MULTI-LANE REPO.** This is ONE lane's handover. The lane map
> (`docs/dev-log/handover/2026-07-25-active-lane-split.md`) is authoritative for ownership.

---

## ARC 1 — the SDM article set: CLOSED, published, verified live

Merged as [#1180](https://github.com/itchyshin/gllvmTMB/pull/1180); site rebuilt and
**verified live by content**, not by a green tick.

| page | state |
|---|---|
| `sdm-start-here.Rmd` | **NEW** — front door: four-windows figure, decision-tree flowchart, routing table, honest exits, "What this is built on" |
| `unit-of-analysis.Rmd` | **NEW** — what a "site" is; two figures; taxon-by-data survey; measured cost of gridding |
| `isdm-canada-warbler.Rmd` | rewritten reader-first |
| `isdm-spatial-precision.Rmd` | rewritten reader-first |
| `gllvm-vocabulary.Rmd` | gained the SDM terms (intensity, arm, offset, point process, quadrature, cloglog, mesh) |

**The governing standard, set by the maintainer and non-negotiable for future article work:**

> *"can an ecology graduate student read this for the first time — will it be useful?"*

He reported not understanding the previous Warbler article — *"some details without good
explanations and insider voices"*. Root cause: an adversarial review loop had optimised for
reviewers; every round added armour, and nobody in the loop held the reader's utility
function. **Plain language is required in the articles AND in reports to him** — no
"gate/fence/lane/arm" jargon without a definition at first use.

### Things that were WRONG and are now corrected — do not reintroduce

- **Occupancy models are NOT "a different model family".** A multi-species occupancy model
  is a binary joint SDM **plus a detection submodel**, estimable only because repeat visits
  let occurrence and detection be separated; with one visit the two collapse and the
  collapsed model is what this package fits. Corrected across the front door, the unit
  article, and the honest exits.
- **`loading_ci()` exists and is exported.** The feasibility doc's heading *"E2 — field
  amplitude: no interval machinery exists"* **overstates its own test** — it only checked
  whether `Lambda` appears in the ADREPORT block. The maintainer caught this from memory.
  Measured since: `loading_ci()` runs on isdm fits and returns finite intervals on a
  confirmatory fit with a PD Hessian; it refuses on an exploratory fit *because Lambda is
  identified only up to rotation there*, which is a correct refusal.
- Every citation across the four articles was verified against Crossref/publisher.

### Gotchas that cost real time

- **Render each article in its own `envir = new.env()`.** A four-article loop in one
  environment lets them trample each other's objects; the Warbler article failed exactly
  that way and rendered fine in isolation.
- **The site build waits on R-CMD-check completing on `main`**, via `workflow_run`. A
  cancelled check fires a *skipped* deploy. Twice, another lane's push cancelled ours.
  `gh workflow run pkgdown.yaml --ref main` triggers it directly and builds from the
  current tip.
- **The site build has a 45-minute timeout** and hit it once **while still installing R
  dependencies**, never reaching the articles. Cold cache. Retry succeeded.
- Evidence files the articles read must be **tracked** — a pkgdown build sees only a clean
  checkout. Verified here by rendering from a fresh clone before merging.

---

## ARC 2 — prediction uncertainty at new locations (#1181 gap 1): ~45% DONE

**Goal:** `predict()` returns RE-aware uncertainty on NEW data, behind the house
`interval_status` fence, with a known-truth coverage campaign that reports plainly whether
it reaches nominal — **including if it does not**.

### Landed

| item | state |
|---|---|
| **[#1175](https://github.com/itchyshin/gllvmTMB/pull/1175)** — ADREPORT marginal slope SDs | **MERGED** `214c1d2b` (maintainer authorised) |
| **[#1183](https://github.com/itchyshin/gllvmTMB/pull/1183)** — **Design 129**, the estimand | **MERGED** `cad3b5ca` |
| Pre-run measurements | **DONE** — `/private/tmp/gllvmtmb-preduncert/S0b-findings.md` (scratch; re-derive if lost) |
| Adversarial plan critique | **DONE** — reshaped the arc; findings on #1181 |

### OWED — the next session's work, in order

1. **S2' — implement.** Extend the EXISTING `predict_missing(se_route = "sim")` route to
   new locations. **Do not build a new one.**
2. **S3' — pre-registration** for the coverage campaign.
3. **S4' — smoke → campaign → score.** Ladder that already worked: zero-compute scorer dry
   run → 60 live fits at fresh seeds → grid.
4. **S5'/S6'** — mechanical verify, then a **D-43 panel** (2 build + 1 ceiling, fresh)
   gating any register or article change. Register row is **ISDM-03**.
5. **Z** — Melissa reconciles plan vs actual → `docs/dev-log/plan-actual/`. **The plan was
   revised mid-flight; that revision must be recorded as adaptive, not drift.**

### 🔴 READ DESIGN 129 BEFORE WRITING ANY CODE

`docs/design/129-prediction-uncertainty-new-locations.md`. It settles the estimand and
carries five pre-registered predictions with falsifiers. The three points most likely to be
got wrong by someone who skips it:

1. **THREE regimes, not two.** SPDE propagates through `Q`; exchangeable unstructured
   levels get the prior; **structured-but-unprojected tiers (`phylo_*`, kernel) REFUSE.**
   A new species *on a tree* is not exchangeable — its cross-covariance to training species
   is known, so the prior fallback would discard real information and silently answer a
   different question.
2. **Regime B's cost is WIDTH, not calibration.** "No information about `u_new`" implies a
   *wide* interval, not a mis-calibrated one — marginally the score really is drawn from
   the prior. Predicted: **the deficit shrinks with n** (falsifier: flat in n ⇒ refuted).
   **A wide-but-covering regime-B interval is a SUCCESS; reporting it as a failure would be
   the error.** An earlier framing of this arc got this backwards.
3. **Two rotation fences.** `eta` IS rotation-invariant (PR #364's scar does not apply to
   it), but `Lambda` and `u` must be drawn **jointly** from `Q` — never `Lambda` from
   `cov.fixed` and `u` from `getREsd()` — and **nothing per-axis** may ever be reported.

### Measured facts — do not re-derive, and do not contradict

- **`getJointPrecision = TRUE` is ALREADY LIVE** at `R/methods-gllvmTMB.R:3084` and
  `:3262`. `predict_missing(se = TRUE, se_route = "sim")` already implements
  draw-from-joint-precision → push-through → quantiles, with five routes and both
  confidence and prediction columns.
- **The O(P²) fear is dead.** `getJointPrecision = TRUE` measured free vs `FALSE`; matrix
  94–98.5% sparse; 50 sparse-Cholesky draws ≈ 1.7 ms.
- **The regime gap is real, confirmed by experiment.** Latent contribution `-0.7210` at a
  known site; **exactly 0** at a new site level. Joint precision names:
  `b_fix(6) + log_sigma_eps(1) + theta_rr_B(3) + z_B(20)` — exactly `n_sites × d_B`, **no
  slot for a new site**. Guard: `R/methods-gllvmTMB.R:2547-2555`.
- **SPDE contrasts correctly** — fields project via `fmesher::fm_basis()` →
  `A_new %*% omega_spde`, and `omega_spde` IS precision-bearing.
- **E4's 0.23–0.82 was measured on TRAINING ROWS ONLY** (the guard refuses `newdata`), so
  the new-location case is an inference from it — strictly harder and unmeasured. Say so.
- **Design 119's ladder** is the decisive prior on this route: quad 0.960–0.966 · joint
  0.925–0.933 · joint_load 0.935–0.939 · **sim 0.941–0.946** · boot 0.929–0.933; **gate
  0/16**; `se =` stays `heuristic_unvalidated`.

### Numbers that were quoted WRONG in this arc's own planning

- 1.7–2.5 points is a route's **total deviation from nominal**, not the price of the
  dropped `d(eta)/d(lambda)` block — that price is **0.6–1.0**.
- The ~0.6-point sampling gain **cannot be credited to quantiles alone**; `sim` also
  removes bilinearity error. Neither half has been priced separately.
- The confidence/prediction gap is **`V_family` in both regimes**, not the regime-B term.

### Campaign design — `n >= 580` does NOT transfer

Design 118's figure is an **independent-Bernoulli** calculation. Map cells within one fit
are strongly correlated (the E1 seed anomaly measured 0.151 pairwise → **4.53× variance**).
So: the **fit** is the replication unit; stratify coverage **by distance to nearest
observation** (E4's own signal demands it — 0.48–0.82 at 150 cells vs 0.23–0.55 at 810);
score **out-of-hull rows separately** (they return an exactly-zero field with a warning, so
mixing them measures the warning); and **pre-register `n_sim`**.

Compute: Totoro, ≤150 cores (D-143), `OPENBLAS_NUM_THREADS=1`. E1 precedent is 22,200 fits
≈ 15 min — but that omits the joint-precision and sampling cost, so it is **not** a direct
precedent. Measure before launching.

---

## Open, not blocking

- **PR #1175's consumer tests do not execute.** The four `summary.sdreport` consumer files
  Rose named all skip (0 passing assertions), by honest design. Her conclusion holds by
  **static analysis**, with no runtime protection behind it. A positional guard on the
  sdreport row layout would convert it to a run-time check — that is the class the 2/5/8
  indexing bug came from. Recorded on the PR.
- **No full-suite tail was obtained** this session (background R died twice). The
  `[FAIL 0 | WARN 9 | SKIP 877 | PASS 16305]` figure is **carried over from the prior
  session, not re-measured**.
- **A brain note was misfiled** into `symbolizer/docs/memory/` by the memory tool. The
  correct copy is in the vault at
  `memory/A prior-work sweep without a CODE row rebuilds what already ships.md`, linked
  from `LESSONS.md`. Delete the stray one when convenient.

## The process lesson worth carrying to every arc

The Phase 0.25 prior-work sweep has **no CODE surface row**. Git state finds branches,
design docs find intentions, the brain finds decisions — a shipped, merged, unremarkable
function falls through all four. This arc's plan claimed a capability was unbuilt while it
was already shipping, on the strength of a grep over **one file**. Add
`grep -rn "<symbol>" R/ src/` across the whole package to every receipt. Full case:
`memory/A prior-work sweep without a CODE row rebuilds what already ships.md`.

And what **worked**: an adversarial critique of the *plan*, before any code, with the
plan's most load-bearing assumption **named for the reviewer to break**. It caught a
construction that would have shipped intervals too narrow by design, and simultaneously
cleared a constraint that had been driving the design unnecessarily.
