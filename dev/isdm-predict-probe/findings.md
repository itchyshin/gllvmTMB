# Probe findings — predict() on `isdm_sources()` fits (2026-08-17)

Lane `claude/isdm-predict-20260817`; OWED-1 from
`docs/dev-log/handover/2026-08-17-claude-handover-isdm-next.md`. Evidence:
`dev/isdm-predict-probe/probe.R` (deterministic, seeds 7/23) and its captured
run `probe-output.txt`; line IDs below are the `PROBE[..]` tags. Code
references are to `R/methods-gllvmTMB.R` (`predict.gllvmTMB_multi`, ~L2183).
Adversarially verified by an independent Opus pass (`verify-report.md`,
verdict PASS-WITH-CORRECTIONS; its corrections are applied throughout, and
its independent measurements are cited as `VER[..]`).

## Verdict

**Mixed.** The in-sample surface is correct and certifiable. The `newdata`
surface — the one a map needs — is broken in three distinct ways, so the SDM
collection's prediction-map promise cannot be completed on the current
`predict()`.

## Defensible (certified by `tests/testthat/test-isdm-predict.R`, except
## where marked probe-only)

1. **In-sample `predict(fit)`** returns one row per observation with `est`
   identical to `fit$report$eta` — the full linear predictor: fixed effects +
   offset (`log_support`) + all random effects (A1). On a spatial fit this
   includes the SPDE field (B1) — **probe-measured only; the test fixture is
   non-spatial, so no test pins the spatial case.**
2. **In-sample `type = "response"` uses each row's own arm**: count rows get
   `exp(eta)` (an expected count *at that row's support*), detection rows get
   `1 - exp(-exp(eta))` (a detection probability *at that row's support*),
   never the first trait's link (A2, A2b). **The `newdata` path does not —
   see Not-defensible item 5.** Relative-intensity maps therefore need the
   offset subtracted on the link scale first (exactness of the
   `log_support = 0` workaround confirmed at VER[C5]).
3. **Non-spatial `newdata` round-trip is exact on the link scale**:
   `predict(fit, newdata = <training data>)` reproduces in-sample link-scale
   predictions to 0 (offset and latent REs both re-included) (A3);
   `re_form = ~0` on newdata equals fixed effects + re-evaluated offset
   exactly (tested; VER[C3] `max|diff| = 0`); an unseen unit level falls back
   to fixed-only, as documented (A7).
4. **`se.fit = TRUE`** runs in-sample, returning finite positive SEs, and
   refuses `newdata` with a classed error (A6, A6b). The conditional /
   fixed-effect-only / delta-method semantics are **documented, not
   certified** — no test asserts them.

## Not defensible (scoped in `docs/design/126-isdm-prediction-api.md`)

1. 🔴 **`newdata` drops every random-effect tier except `rr_B` / `diag_B` /
   `propto` — spatial is the measured instance.** On a converged spatial isdm
   fit the newdata-vs-in-sample discrepancy at the *training locations* has
   sd 0.381 against a linear-predictor sd 0.949 (B2), and the dropped piece
   is the field *by identity*: `fitB` carries exactly one random tier
   (`use$spde`), so −diff is the entire RE contribution — confirmed exactly
   on an independent non-isdm gaussian spatial fit (VER[D4]
   `-diff == report$eta - fixed-only`, `all.equal` TRUE; there sd 0.516 vs
   eta sd 0.786). The corroborating cor(−diff, u_true) = 0.82 (B2b) shows
   the field is real. On a pure-spatial fit `re_form = ~.` equals
   `re_form = ~0` — nothing is re-added (B4) — while the path still prints
   "Random effects … have been added". The newdata branch handles 3 of the
   ~30 `use` tiers (`R/methods-gllvmTMB.R:3081-3090`); phylogenetic and
   kernel tiers are structurally identical, unmeasured.
2. 🔴 **`re_form` is honoured only on the `newdata` path, and only as the
   literal `~0`.** In-sample, `re_form` is ignored entirely — the
   `is.null(newdata)` branch never reads it, so the *default* call
   `predict(fit, re_form = ~0)` silently returns the full conditional
   predictor (VER[C2]). On newdata, `NA` (A5), numeric `0` and `~1`
   (VER[C4b,c]) all fall through to full-RE because the code tests only
   `identical(deparse(re_form), "~0")` — against a roxygen that promises
   "`~0` (or `NA`)" gives fixed-only.
3. **No `A_proj` projection for new locations** — predictions at unseen cells
   are fixed-effects-only (B3), so a fine-grid map from a spatial fit cannot
   be made through `predict()` at all.
4. Minor: in-sample output carries no source/arm column (A1b) — rows are
   data-aligned so the user can `cbind`, but a mixed-scale `response` column
   without an arm label invites misreading.
5. 🔴 **`predict(newdata=, type = "response")` applies the wrong arm's
   inverse link on isdm fits** (found by the adversarial verification;
   re-measured at A2c). The newdata response branch collapses the per-row
   family/link vectors to a **per-trait modal** id
   (`.modal_integer_id`, `R/methods-gllvmTMB.R:2342-2350`); an isdm fit
   varies family by *source within trait*, so the reduction cannot represent
   it. Measured: detection-arm rows return `exp(eta)` instead of
   `1-exp(-exp(eta))` — "probabilities" in **[0.253, 2.32]**, silently —
   with `max|diff| = 1.42` against the certified in-sample response (A2c,
   A2c2). Not a tie artifact: in any realistic iSDM the presence-only arm
   out-rows the survey arm and wins the mode.

## Numbers, labelled

`sd(g_spde) = 0.0796` is the **raw mesh-node** RE sd, not the field's
contribution to the linear predictor — that is the sd 0.381 above, larger by
the `Lambda_spde`/`tau` scaling. Like-for-like comparison is sd 0.381 vs
sd 0.949 (max|diff| 0.966).

## What this scopes

Certify the in-sample core now (done — 16 assertions); fix defects (1)/(2)/(5)
in one focused maintainer-gated `R/` PR (same function; Design 126 §3); design
the map API (items 3–4; Design 126 §4) before any map-making article. The
article is NOT written in this lane: it would map a surface that both drops
the field it is mapping and mislabels the detection arm's scale.
