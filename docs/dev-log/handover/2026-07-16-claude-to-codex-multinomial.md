# Handover — Claude → Codex: build the `multinomial()` response family (Lane C)

**Date:** 2026-07-16 · **From:** Claude (design + C0) · **To:** Codex (live build C1–C2) ·
**Branch:** `agent/lane-c-multinomial` (worktree `.claude/worktrees/lane-c-multinomial`, based at
`48a66b93`). **Sequential baton — never run concurrently with Lane A/B.**

## GOAL (paste to set your session)
```
Build gllvmTMB's multinomial() response family (baseline-category logit / softmax), R-only,
family_id 16, Tier-1 FIXED-EFFECTS-ONLY. HEADLINE: the C++ fid==16 grouped-softmax branch — PORT the
already-validated MD6c kernel (src/gllvmTMB.cpp:2320-2334), evaluate once per observation-group at the
anchor row (anti-double-count). Tier-2 latent-scale correlation surface DEFERRED + fenced by a
FAIL-LOUD TEST. Smoke-first; recovery band = ordinal FIXED-EFFECT abs-0.30 (NOT the 2.5x variance
band); K=2 → binomial(logit); recovery via inline sample() DGP; simulate()/bootstrap honest-skip until
the fid-16 draw lands; dev calibration on Totoro/DRAC not GitHub Actions (D-50); apply
tmb-likelihood-review; close with R CMD check --as-cran 0E/0W/0N + after-task report.
```

## What Claude already did (C0 — on this branch)
- **`docs/design/83-multinomial-response-family.md`** — the full spec (READ THIS FIRST; §4 is the
  build contract, §6 the recovery contract).
- **`docs/design/35-validation-debt-register.md`** — new **FAM-20** row (`partial`, fixed-effects-only,
  latent N/A by design; evidence placeholders "not passing until the D-43 audit clears").
- **`docs/design/02-family-registry.md`** — removed the "planned; post-CRAN" bullet; added the
  "Unordered categorical (multinomial) families" subsection; updated the Rose note; added the Design 83
  cross-ref.

Your job is C1a → C1b → C1c → C2. C3 (honesty fencing + Rose D-43 audit) comes back to Claude after C2.

## Model routing (per MODEL-ROUTING.md)
Terra `high` for the build slices; **Sol `xhigh`** for the C1a likelihood-correctness adversarial verify
and the C2 recovery verdict. Use the enforced tiered-cli dispatch if you fan out; otherwise native at
Terra-high is fine for the coupled C1a/C1b work.

---

## PIN FIRST (C1a) — the one integration decision
The exact response encoding the C++ branch reads. Two equivalent options; **pick one and make the R
expansion emit exactly it**:
- **(A) per-pseudo-row 0/1 indicator** (Gauss's sketch): `y(anchor+j)` = 1 iff observed category ==
  contrast `j`; all-zero ⇒ baseline observed. Numerator = `Σ_j y_j·η_j`.
- **(B) repeated observed-category code** (Boole): the response column carries the category code `1..K`
  repeated across the K−1 rows; C++ reconstructs the observed contrast at the anchor.

Recommend **(A)** — it needs no extra "which category" structure and reuses `DATA_VECTOR(y)` directly.
Whichever you choose, **the inline recovery DGP (§6 of Design 83) must match the coefficient packing
term-by-term** (baseline = category 1, K−1 column-major blocks) or name-keyed recovery breaks silently.

---

## C1a — C++ softmax likelihood (`src/gllvmTMB.cpp`) — HIGH-RISK, apply `tmb-likelihood-review`
Port the validated MD6c kernel at `:2320-2334`. Evaluate once per group at the anchor row.

1. Enum comment (~:244): document `16 = multinomial (baseline-category logit)`.
2. New data near the ordinal metadata (~:275): `DATA_IVECTOR(multinom_group_id)` (length n_obs, −1
   off-family); recommended `DATA_IVECTOR(multinom_K_per_trait)` (length n_traits). **No new
   `PARAMETER_VECTOR`** — category effects come through `X_fix`/`eta`.
3. Add a `multinom_group_loglik(anchor)` lambda next to `obs_loglik` (NOT inside it):
   ```cpp
   // logp = Σ_j y(anchor+j)·η(anchor+j) − logsumexp(0, η_1..η_L),  L = multinom_K_per_trait(t)
   Type m = Type(0.0);                                   // baseline 0 seeds the running max
   for (int j=0;j<L;++j) m = CppAD::CondExpGt(eta(anchor+j), m, eta(anchor+j), m);
   Type s = exp(Type(0.0)-m);
   for (int j=0;j<L;++j) s += exp(eta(anchor+j)-m);
   Type log_denom = m + log(s);                          // s>=1 → finite
   Type num = Type(0.0);
   for (int j=0;j<L;++j) num += y(anchor+j)*eta(anchor+j);
   Type logp = num - log_denom;                          // AD-safe floor like ordinal tiny_p
   ```
4. Main loop (`:2339`): a fid-16 pre-branch — evaluate the group density **once at the anchor** (detect
   by `multinom_group_id` change vs previous row), contribute 0 elsewhere, apply weight once at anchor,
   whole-group mask. Add a fail-loud `error()` for a stray per-row fid-16 call inside `obs_loglik`.
**Verify (Sol):** compiles; one-trait cell probs == `nnet::multinom` / the MD6c oracle on a tiny set
(Noether faithfulness gate); a toy K=3 fit converges PD (smoke-first).

## C1b — R API + expansion (`R/gllvmTMB.R`, `R/fit-multi.R`, `R/families.R`, `R/enum.R`, `NAMESPACE`)
1. `multinomial(link="logit", baseline=NULL)` in `R/families.R` (mirror `ordinal_probit()` :784-792);
   `export(multinomial)`; roxygen with a prominent "distinct from `categorical()` (imputation)" note.
2. New `expand_multinomial_response()` in `R/gllvmTMB.R` (after the `traits()` pivot ~:501-551, before
   the fit call ~:772): each categorical obs → **K−1 pseudo-trait-level rows** `"<T>:cat<c>"`
   (contiguous, category order) + the `.multinom_group_` index; K from **observed** cats (`droplevels`);
   abort on an unobserved non-baseline category. Predictors copied verbatim; group mask broadcast;
   group weight on the first row only. This reuses the existing `model.matrix()`/`X_fix` path with no
   parser change.
3. `R/fit-multi.R`: `family_to_id()` arm `multinomial=16L` + link check + append to the "Unsupported
   family" message (:265-325); build `multinom_K_per_trait` (pattern :2410-2471) + pass
   `multinom_group_id` into `tmb_data` (:3374); map off dispersion + auto-`Psi`
   (`auto_unique_off_family` :526; map :4245); the **single Tier-1 covstruct choke-point** (~:1831) that
   fails loud if any latent/RE/slope/cluster flag is set with a fid-16 trait present; **reject**
   `multinomial()` inside a mixed-family `list(...)` (:343), reject `weights`, and redirect `K<3` to
   `binomial()`.
4. `R/enum.R`: add `multinomial = 16L` to `.valid_family` (:5-22, keep lockstep).
**Verify:** `devtools::load_all()`; toy long + wide K=3 fits construct, dispatch `family_id 16`,
converge PD.

## C1c — inference + S3 (`R/methods-gllvmTMB.R`, `R/predictive-diagnostics.R`, `R/extract-*.R`, `R/z-confint-*.R`)
The pseudo-row expansion breaks the `n == nrow(data)` invariant — add a `multinom_group_id`-aware
reduction (pseudo-rows → observations) at each co-indexed site (predict fast-path :1572, residual
metadata, `.apply_linkinv_per_row`).
- `predict(type="response")` = K per-category probabilities (long-in-category); `type="link"` = K−1
  etas. New `fitted.gllvmTMB_multi` = per-category probability (modal via arg).
- `simulate()`: group-blocked softmax draw → one category, expand to the pseudo-row encoding; add `16L`
  to `supported` (:1100). `residuals()` → `unsupported_family` (Tier 1, honest — where fid 14 lands).
- `confint()` Wald on per-category `b_fix` (free); profile runs but uncalibrated → **not advertised**.
- `print()` labels `trait:cat_k[:x]` + a baseline advisory line.
- **Hard-refuse guard** (typed `cli_abort`) in `extract_correlations` / `extract_sigma` /
  `extract_repeatability` for a fid-16 trait; `link_residual_per_trait()` gains a `fid==16 → NA` branch.
**Verify:** shapes correct on the toy fit; `extract_correlations()` on a multinomial fit errors cleanly.

## C2 — recovery + fence tests (`tests/testthat/`, `dev/`)
Follow Design 83 §6 exactly. `test-multinomial-recovery.R` (K=3 n=400 / K=4 n=600 recovery, name-keyed,
band **abs 0.30**; **K=2 → binomial(logit) byte-identity 1e-6**; baseline-invariance 1e-6; 5-seed
aggregate; mixed gaussian+poisson smoke). `test-multinomial-unit.R` (fast: fid==16 + (K−1)-block
contract; **fail-loud latent-on-multinomial guard**; optimiser-free reference-invariance math gate).
Update `test-enum-runtime-ids.R` for id 16. `dev/multinomial-recovery.R` calibrates bands over 20–50
seeds on **Totoro/DRAC** (never GitHub Actions, D-50). **Do NOT author `test-matrix-multinomial-unit.R`**
(covariance tier = needs random effects = out of scope; would fake-pass).
**R4 trap:** the inline `sample()` DGP needs no `simulate()`; anything routing through
`.draw_y_per_family` (:1078, `supported` lacks 16) **honest-skips** until the C1c draw branch lands —
never accept the silent Gaussian-on-link fallback.
**Verify (Sol/Opus):** `GLLVMTMB_HEAVY_TESTS=1 devtools::test(filter="multinomial")` non-skipped, 0 fail,
all alignment terms + invariance + K<3-reject + latent-guard pass; local `R CMD check --as-cran`.

## Guards / risks (consolidated)
Anchor-once + strictly-monotone group id + run-length cross-check (double-count); NA branch + hard
`extract_*` refusal (silent correlation fabrication); n_traits pollution / weights-once / whole-group
mask / baseline choice / unused levels (Boole's mitigations). Region-local, disjoint from Lane B's
latent-score C++.

## Hand back to Claude for C3
After C2 is green, post a directed line in `docs/dev-log/check-log.md` and write an after-task report in
`docs/dev-log/after-task/`. Claude runs C3 (honesty fencing + the D-43 3-fresh-agent audit) before any
public wording, then Vf (verify + consolidate). Full slice table + routing:
`~/.claude/plans/categorical-multinomial-humble-babbage.md`.
