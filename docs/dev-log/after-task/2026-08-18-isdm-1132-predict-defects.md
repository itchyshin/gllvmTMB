# After-task — #1132: three predict(newdata=) defects fixed

Date: 2026-08-18 · Lane: `claude/isdm-1132-predict-defects` (Claude Code) ·
Worktree: `/private/tmp/gllvmtmb-1132` · Base: `origin/main` @ `b5ea39fd`

## Scope

Issue [#1132](https://github.com/itchyshin/gllvmTMB/issues/1132), the three
`newdata`-path defects in `predict.gllvmTMB_multi` measured in Design 126 §3.
Plus a fourth defect found in the same block during the work. Design 127
(implementation design for #1133) written; **no #1133 code**, per the plan.

## Outcome

Four defects fixed in `R/methods-gllvmTMB.R`, all in one function.

1. **SPDE field dropped on `newdata`.** The branch re-added 3 of ~23 engine
   tiers, so a spatial fit's field was absent from every `newdata`
   prediction — at training locations too — while the branch reported that
   random effects had been added. Not iSDM-specific: reproduced on a plain
   `gaussian()` spatial fit. Fixed by rebuilding the mesh projection with
   `fmesher::fm_basis()`, mirroring `src/gllvmTMB.cpp:2418-2423` and
   `2518-2528` across all three spatial paths (per-trait, low-rank, unique).
   Every *other* active tier now raises a warning naming it.
2. **`re_form` not honoured.** Read only on the `newdata` path and only as
   the literal `~0`, so `predict(fit, re_form = ~0)` — the *default* calling
   convention — returned the full conditional predictor. `~0`, `NA` and
   numeric `0` are now honoured on both paths; anything else warns.
3. **Wrong arm's inverse link on `newdata` + `response`.** Per-row family/link
   ids were reduced to a per-trait *modal* id, which cannot represent an
   `isdm_sources()` fit. Ids are now recovered per row from the fit's
   `family_var` column, keeping each `(family, link)` pair together.
4. **NOT IN THE ISSUE — `lv_B` score mean dropped.** With an active `lv_B`,
   the `z_B` parameter is only the zero-mean innovation and eta uses
   `U_B_total = X_lv_B alpha_lv_B + z_B` (`src/gllvmTMB.cpp:1518-1543`). The
   `rr_B` re-add used `z_B` alone. Now uses the reported `U_B_total`.

## A false alarm that was caught before shipping

The first implementation keyed the "unhandled tier" warning on `fit$use`.
That warned on a spatial fit whose prediction was **exactly correct**:
`fit$use` mixes engine flags with *mode descriptors* (`spatial_scalar`,
`spatial_latent`, `dep_B`), which ride alongside the engine flag that
actually adds the term. The warning now reads `tmb_data`'s `use_*` switches —
the template's own. Measured: `spatial_scalar` and `spatial_latent` fits now
warn not at all and match `report$eta` exactly; an `re_int` fit warns and
names `re_int`. A warning that fires on correct output is worse than none.

## Checks

- `test-isdm-predict.R`: **16 → 35 assertions**, all passing. The 16 baseline
  assertions are unchanged and still green.
- Acceptance test for defect 1 is the **exact identity** — `predict(newdata =
  training rows) == report$eta`, measured `max|diff| = 0` — the form the
  original adversarial verification recommended over the weaker
  correlation-with-truth argument.
- `devtools::document()` clean; `man/predict.gllvmTMB_multi.Rd` regenerated.
- Full suite + `R CMD check --as-cran`: see `VERIFY-mechanical.md`.
- Independent adversarial verification of the SPDE re-add across all three
  spatial paths: see `VERIFY-adversarial.md`.

## Follow-up

- **Open an issue** for the all-tiers re-add. Deliberately NOT attempted:
  `getREsd()`'s roxygen states that `omega_spde*`, `g_kernel*`, `s_B_slope`,
  `s_W_slope`, `r_c2`, `g_phy`, `g_phy_diag` and every augmented-slope block
  have **no established reshape convention**. Guessing one yields a silently
  *wrong* number, strictly worse than a loudly *absent* one. The warning now
  makes each such tier visible at the call site.
- 🔴 **`vignettes/articles/rare-species-jsdm.Rmd:163`** calls
  `predict(fit_mspl, type = "response", re_form = ~0)` with no `newdata`. It
  was therefore getting conditional predictions while labelling them
  population-level. **Its numbers will move and its prose needs a re-read.**
  Flagged, not silently rewritten.
- **`propto` row-1-only guard** (`object$use$propto && !is.na(sp_id[1])`)
  gates the whole species loop on row 1. Adjacent, untouched, still present.
  Deserves its own issue.
- **Extrapolation honesty** (Design 127 §3.2): `fm_basis()` returns an
  all-zero row outside the mesh hull, which reads as "field = 0". The fix did
  not introduce this, but it now exposes it to users predicting on a grid.

## Register

ISDM-03 stays `partial`. The `newdata` spatial path moves from broken to
covered *for training coordinates*; the map claim stays fenced behind #1133.
