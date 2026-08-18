# Probe findings — predict() on `isdm_sources()` fits (2026-08-17)

Lane `claude/isdm-predict-20260817`; OWED-1 from
`docs/dev-log/handover/2026-08-17-claude-handover-isdm-next.md`. Evidence:
`dev/isdm-predict-probe/probe.R` (deterministic, seeds 7/23) and its captured
run `probe-output.txt`; line IDs below are the `PROBE[..]` tags. Code
references are to `R/methods-gllvmTMB.R` (`predict.gllvmTMB_multi`, ~L2183).

## Verdict

**Mixed.** The in-sample surface is correct and certifiable. The map-making
surface — `newdata` on a spatial fit — is broken in one silent way and absent
in another, so the SDM collection's prediction-map promise cannot be completed
on the current `predict()`.

## Defensible (certified by `tests/testthat/test-isdm-predict.R`)

1. **In-sample `predict(fit)`** returns one row per observation with `est`
   identical to `fit$report$eta` — the full linear predictor: fixed effects +
   offset (`log_support`) + all random effects including the shared latent
   and, on spatial fits, the SPDE field (A1, B1).
2. **`type = "response"` uses each row's own arm**: count rows get
   `exp(eta)` (an expected count *at that row's support*), detection rows get
   `1 - exp(-exp(eta))` (a detection probability *at that row's support*),
   never the first trait's link (A2, A2b). Relative-intensity maps therefore
   need the offset subtracted on the link scale first — an article-level
   instruction, not a defect.
3. **Non-spatial `newdata` round-trip is exact**: `predict(fit, newdata =
   <training data>)` reproduces in-sample predictions to 0 (offset and latent
   REs both re-included) (A3); `re_form = ~0` gives fixed-effects-only (A4);
   an unseen unit level falls back to fixed-only, as documented (A7).
4. **`se.fit = TRUE`** works in-sample (finite, positive, conditional
   fixed-effect-only delta SE, as documented) and refuses `newdata` with a
   classed error (A6, A6b).

## Not defensible (scoped in `docs/design/126-isdm-prediction-api.md`)

1. 🔴 **Spatial fits: `newdata` silently drops the SPDE field — even at the
   training locations.** On a converged spatial isdm fit (B0: conv 0, field
   sd 0.08) the newdata-vs-in-sample discrepancy has sd 0.381 against a
   linear-predictor sd 0.949, and the dropped piece *is* the field
   (cor(−diff, u_true) = 0.82) (B2, B2b). On a pure-spatial fit `re_form = ~.`
   equals `re_form = ~0` — nothing is re-added — while the path still prints
   "Random effects … have been added" (B4). Code: the newdata branch re-adds
   only `rr_B` / `diag_B` / `propto`; there is no SPDE term in it.
2. 🔴 **`re_form = NA` behaves as `~.`, not `~0`.** The roxygen says "pass
   `~0` (or `NA`)" for fixed-only; empirically `NA` includes the REs (A5).
   The code tests only `deparse(re_form) == "~0"`. A user following the docs
   gets conditional predictions labelled as population-mean ones.
3. **No `A_proj` projection for new locations** — predictions at unseen cells
   are fixed-effects-only (B3), so a fine-grid map from a spatial fit cannot
   be made through `predict()` at all.
4. Minor: in-sample output carries no source/arm column (A1b) — rows are
   data-aligned so the user can `cbind`, but a mixed-scale `response` column
   without an arm label invites misreading.

## What this scopes

Certify (1)–(4) now (done, tests); fix bugs (1)–(2) in a focused R/ PR
(maintainer-gated); design the map API (3)–(4) — `A_proj` kriging, an arm
column, an intensity-scale option — before any map-making article is written.
The article is NOT written in this lane: it would advertise a surface that
drops the field it is mapping.
