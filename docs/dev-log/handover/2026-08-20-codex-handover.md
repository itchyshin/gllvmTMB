# Claude → Codex handover — 2026-08-20
## SDM article set (CLOSED, live) · prediction-uncertainty arc (~45%) · four new API gaps with measurements

**You are Codex, picking up gllvmTMB.** You never saw the authoring chat; this document is
self-contained. `AGENTS.md` is native to you — read it first, then this file.

**FIRST ACTION:** `bash ~/shinichi-brain/tools/lane_preflight.sh "<repo>"`. Ten lanes were
live at handover and commits land on `main` all day.

> **🔴 MULTI-LANE REPO.** This is ONE lane's handover. The lane map
> `docs/dev-log/handover/2026-07-25-active-lane-split.md` is authoritative for ownership and
> names EACH lane's own current handover. Do not treat this document as project status.
> **Other lanes' open PRs at handover: #1191, #1193 (not ours — do not touch).**

---

## Critical Context

Two things drove this session.

1. **The maintainer could not read his own package's flagship article.** His words:
   *"some details without good explanations and insider voices — I did not understand much
   of it."* Root cause: an adversarial review loop had optimised for reviewers; every round
   added armour and nobody in the loop held the reader's utility function. He set the
   standard explicitly, and it now governs all reader-facing work:
   > **"Can an ecology graduate student read this for the first time — will it be useful?"**
   Audience: a second-year ecology PhD who knows GLMMs, AIC and eBird, and has never heard
   of TMB, SPDE, latent variables or meshes. **Plain language in the articles AND in reports
   to him** — no "gate/fence/lane/register" jargon without a definition at first use.

2. **He is designing a real study** — two insect groups, latitudinal decline, GBIF-style
   opportunistic records. That analysis became the forcing function that exposed four API
   gaps (below). Keep it in view: it is a live user, not a hypothetical.

---

## What Was Accomplished (all MERGED to `main`, tip `147da385`)

| PR | what |
|---|---|
| #1180 | **SDM article set rebuilt reader-first** — two new articles + two rewrites + vocabulary |
| #1175 | **ADREPORT marginal slope SDs** (`src/gllvmTMB.cpp`) — unblocks phylo/loadings slope intervals |
| #1183 | **Design 129** — the estimand for prediction uncertainty at new locations |
| #1184 | site-build fix after #1182 broke the Warbler article |
| #1185 | nav: dropped a duplicate `spatial-models` entry from the SDM menu |
| #1186 | **corrected a routing error I introduced** in the front door |

**The site is live and verified by content** (not by a green tick):
`sdm-start-here`, `unit-of-analysis`, `isdm-canada-warbler`, `isdm-spatial-precision`,
`gllvm-vocabulary`. `pkgdown` #965 green.

**Full local suite on `main` after all merges: `FAIL 0 | WARN 9 | SKIP 877 | PASS 16311`**
(up from 16305 — matches #1175's new assertions). Three ERRORS appear in
`test-paper1-spde-slope-gauge-nofit-v2-materializer.R`, which belongs to **another lane** and
depends on `dev/` files absent from that invocation. Not ours, not a defect in `main`.

---

## Landing State

| item | state |
|---|---|
| Everything in the table above | **LANDED on `main`** |
| `claude/handover-20260819` (previous handover doc, `baa8dcaa`) | **PUSHED, NO PR** — supersede or land it with this one |
| `claude/reader-first`, `claude/fix-*`, `claude/nav-*` | merged; branches can be deleted |
| Scratch evidence in `/private/tmp/gllvmtmb-preduncert/` | **EPHEMERAL — re-derive if lost** (see Gotchas) |

---

## Direction — the four gaps this session opened, all with MEASUREMENTS

These are the substance of the handover. Each is filed with evidence, not opinion.

### #1192 — per-source observation models for integrated fits
An integrated fit needs recording-bias covariates on the **opportunistic arm only**. Today
that means hand-masked columns (`ifelse(src == "gbif", access, 0)`), and **writing `+ access`
instead fails silently** — converges, believable slopes, observation effect smeared across
every arm. Proposal (revised twice by review):
`isdm_sources(gbif = po_source(observation = ~ access), survey = po_source(observation = ~ 0 + observer))`.
**Curie's implementability review: 34–48 h**, and the literal `poisson(observation = ~ ...)`
in the first sketch **does not parse** — `stats::poisson()` takes only `link`.

### #1195 — `animal_slope`/`phylo_slope` are undiscoverable
They work. They are not in the 5×3 keyword grid. The three syntaxes a user would try all
refuse. Cheapest high-value fix: **make the refusals name the working route** (the package
already does this well in `loading_ci()`).

### #1196 — column-wise (species-level) random slopes: ONE per model
Measured, and the ceiling is lower than first believed:

| attempted | result |
|---|---|
| `phylo_slope(lat \| trait, tree = tree)` | **FITTED, conv 0, pdHess TRUE** — keys on `trait` directly, no duplicate column |
| `indep(0 + lat \| trait)`, `indep(0 + lat + temp \| trait)` | REFUSED — *"augmented LHS is not yet supported"* |
| `phylo_indep(0 + trait + trait:lat \| species)` | REFUSED — **the exact form the previous error message recommends** |
| **two `phylo_slope()` terms** | REFUSED — *"only one phylogenetic random-regression term per formula"* |

So: **one species-varying slope per MODEL.** A user with latitude *and* temperature has no
route. `phylo_slope` validated by positive control (σ̂ 0.144 vs true 0.25, pdHess TRUE; and
correctly collapses to ~0 when the truth is i.i.d.).

**Maintainer's preferred fix, and I agree:** extend `phylo_slope`/`animal_slope` to accept
several covariates (`phylo_slope(lat + temp | trait)`), diagonal by default, `cor = TRUE`
opt-in. Smaller than a new keyword family, builds on the one validated route, and has **no
intercept by construction** — which is why it avoids the collision the augmented forms hit.

### #1161 — narrowed, not closed
Phylogeny **can** reach the species axis for **slopes**. The gap is specific to **Σ**, the
trait covariance.

---

## Key Decisions & Rationale

- **Merge #1175 (maintainer-authorised).** Touches `src/` and the `sdreport` payload.
- **Sample-based propagation** is the primary route for prediction uncertainty (Design 129).
- **Land #1175 before the prediction arc** — no two lanes in the C++ layer at once (D-87).
- **Articles come LAST** in the remaining programme: they document capability, and two
  capabilities are in flight. Documenting a moving target means writing it twice.

---

## Next Immediate Steps — and WHO does what

**Codex owns the live toolchain.** These are yours:

1. **Prediction-uncertainty implementation (S2', the arc's next slice).** Extend
   `predict_missing(se_route = "sim")` to NEW locations. **Read `docs/design/129-...` first —
   it is 375 lines and it settles the estimand.** Three regimes, and the third is the trap:
   SPDE propagates through `Q`; exchangeable unstructured levels get the **prior**; and
   structured-but-unprojected tiers (`phylo_*`, kernel) must **REFUSE**, because a new
   species *on a tree* is not exchangeable and a prior fallback silently answers a different
   question.
2. **The coverage campaign** (S3'/S4') — pre-register, then smoke → Totoro. Design 118's
   `n >= 580` **does not transfer**: it assumes independent Bernoulli trials, and map cells
   within one fit are strongly correlated (the E1 seed anomaly measured 0.151 pairwise →
   **4.53× variance**). The **fit** is the replication unit; stratify by distance to nearest
   observation; score out-of-hull rows separately; pre-register `n_sim`.
3. **The cheap guard from #1196** — warn when a `| g` grouping column is value-identical to
   the declared `trait` column while the formula also carries fixed `trait` terms. One
   `identical()` check; catches a silent mis-specification today.
4. **Fix the two refusal messages** (#1195, #1196) so they name a form that parses.

**Stays planning-side (Claude/Cursor):** the SDM article consistency fixes (audit at
`/private/tmp/gllvmtmb-preduncert/SDM-consistency-audit.md` — **ephemeral**; its five ranked
fixes are summarised in Gotchas), and the `joint-sdm` repair.

---

## Blockers / Open Questions

- **Does partial pooling actually repair the group-contrast SE?** UNMEASURED. One dataset
  gave a ratio of **0.941** — the pooled SE slightly *smaller*. That tests nothing. The 2025
  *Env Ecol Stat* fourth-corner critique is a **lead to check, not a finding this repo has
  verified.** Do not cite it either way without a multi-seed coverage run.
- **#1192's identification question** gates its build: with two opportunistic arms sharing a
  bias formula and no designed arm, the **absolute** slope is functional-form identified only.
  **But the between-species CONTRAST is robustly identified** — arm-common thinning cancels in
  the within-cell species ratio. Do not refuse the configuration; message it and report a
  diagnostic (Fisher recommends the Schur-complement SE inflation, `VIF_obs`).

---

## Gotchas & Failed Approaches — read before you repeat one

1. **Render articles against SOURCE, not the installed package.** Two renders "passed" and
   proved nothing: the installed build was older than `main` and lacked the behaviour under
   test. Use `devtools::load_all()` then `rmarkdown::render(...)`.
2. **Render each article in its own `envir = new.env()`.** A four-article loop in one
   environment lets them trample each other's objects.
3. **The pkgdown build waits on R-CMD-check completing on `main`** (`workflow_run`). A
   cancelled check fires a *skipped* deploy. `gh workflow run pkgdown.yaml --ref main`
   triggers it directly. It has a **45-minute timeout** and hit it once while still installing
   dependencies.
4. **`phylo_tree =` as a global `gllvmTMB()` argument is DEPRECATED** — pass `tree =` inside
   the `phylo_*()` keyword. I got this backwards mid-session; the in-keyword form is current.
5. **Background `Rscript ... &` inside a foreground shell dies here.** Long fits/renders need
   foreground or the harness's own background flag — not double-backgrounding.
6. **`testthat::test_local()` throws on failure**, so a summary written after it never runs.
   Use `stop_on_failure = FALSE` and write results to a FILE (stdout gets truncated).
7. **A prior-work sweep with no CODE row rebuilds what already ships.** This session's plan
   claimed `getJointPrecision` was never computed, on the strength of a grep over ONE file.
   It is live at `R/methods-gllvmTMB.R:3084` and `:3262`. **Add
   `grep -rn "<symbol>" R/ src/` across the whole package to every sweep.** Full case:
   `~/shinichi-brain/memory/A prior-work sweep without a CODE row rebuilds what already ships.md`.
8. **The SDM consistency audit's five ranked fixes** (source file is ephemeral): repoint the
   presence-only routing (**DONE**, #1186); add a four-line standard header to the eight
   non-rebuilt articles; repair `joint-sdm` (reference-manual voice, no limits section, never
   says its data are simulated); settle "arm" (it means a *simulation branch* in
   `integrated-survey-design.Rmd:382–447`, a *data source* elsewhere); expand GBIF/SPDE/MSPL
   and clear "fences" ×2. Verdict: **not eleven inconsistent articles — three house styles**;
   the four integrated articles are consistent with each other.

---

## Mission control

| repo | branch / main | CI | what shipped | plan by leverage |
|---|---|---|---|---|
| gllvmTMB | `main` @ `147da385` | R-CMD-check green; pkgdown #965 green; local suite FAIL 0 / PASS 16311 | SDM article set live; ADREPORT slice; Design 129 | 1. prediction-uncertainty implementation + campaign · 2. `phylo_slope` multi-covariate (#1196) · 3. observation models (#1192, 34–48 h) · 4. article consistency fixes LAST |

---

## How to Resume

```bash
cd "/Users/z3437171/Dropbox/Github Local/gllvmTMB"
bash ~/shinichi-brain/tools/lane_preflight.sh "$PWD"     # ALWAYS FIRST — 10 lanes live
git fetch origin && git log --oneline origin/main -5
export NOT_CRAN=true                                      # live toolchain
```

Read, in order: `AGENTS.md` → this file → `docs/dev-log/handover/2026-07-25-active-lane-split.md`
(other lanes) → **`docs/design/129-prediction-uncertainty-new-locations.md`** (before writing any
prediction-uncertainty code) → `docs/design/127-isdm-prediction-map-implementation.md` §6.

Team mirror: `.codex/agents/*.toml`. **Rose's audit is mandatory before any public claim**; a
**D-43 panel** (2 build + 1 ceiling, fresh) gates any register or article change, and the
register row for the prediction work is **ISDM-03**.

Verification shape for live work:
```r
Sys.setenv(NOT_CRAN = "true"); devtools::load_all()
testthat::test_local(reporter = testthat::SilentReporter$new(), stop_on_failure = FALSE)
```

**One-command resume prompt for a fresh Codex session, from the repo root:**

> Rehydrate from `docs/dev-log/handover/2026-08-20-codex-handover.md` + the `AGENTS.md`
> snapshot, then continue with the Next Immediate Steps.
