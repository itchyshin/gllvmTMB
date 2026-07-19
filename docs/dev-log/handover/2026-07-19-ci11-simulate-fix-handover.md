# Handover → new lane — CI-11 family-`simulate()` completeness + profile robustness (Ayumi QC fixes)

**Meta:** 2026-07-19 · from Claude (Opus 4.8) · **recommended TARGET = Codex** (live R/TMB feature work, must be
fit-verified) — usable by a fresh Claude lane too if it commits to live verification · repo = **gllvmTMB** · fix
branch = **`claude/cross-family-ci11-20260718`** (the CI-11 cross-family lane, pushed). Disjoint from the active
Codex REML/AGHQ 0.6 lane (different files) → safe as a parallel lane.

> **Origin:** Ayumi's real-data QC on `extract_cross_correlations()` — issue **Ayumi-495/BIRDBASE_pcm#1**
> (reply already posted: https://github.com/Ayumi-495/BIRDBASE_pcm/issues/1#issuecomment-5016824024). She used the
> API CORRECTLY (verified against her repo); the 3 failures are genuine package gaps. Full analysis:
> `scratchpad/ci11-ayumi-fixarc-brief.md` (this session's scratchpad) — copy its content forward if the scratchpad
> is gone. gllvmTMB 0.5.0, her build commit `20773d7`.

## The three bugs (with CORRECTED, code-grounded diagnosis)

### BUG 1 — bootstrap `multiple_r` all-NA — root = family-`simulate()` INCOMPLETENESS (the main arc)
- Ayumi: `method="bootstrap"` on a multinomial-partner fit → 10 `multiple_r` rows, all NA. `bootstrap_Sigma(..., what="cross_corr")` → `n_failed=100`, 0 effective draws. Warning: **`simulate()` not implemented for family_id 14** → Gaussian-on-link fallback → refits fail.
- **CORRECTED:** `family_id 14 = ordinal_probit`, NOT multinomial (legend at `R/fit-multi.R:209-224`). `.draw_y_per_family()` (**`R/methods-gllvmTMB.R:1088`**) supports ONLY `{0 gaussian, 1 binomial, 2 poisson, 3 lognormal, 4 Gamma, 5 nbinom2, 15 nbinom1}` (see the `supported <-` vector at ~L1110). **Both ordinal_probit (14) AND multinomial fall back to Gaussian-on-link** — the code comment (L1118) explicitly calls extending this **"M2/M3 family-completeness work."** So this is a scoped FEATURE, not a one-liner.
- **First step (INVESTIGATE):** how is the multinomial response encoded? It is NOT in the `family_id` 0–15 legend — it's a baseline-category / K-category construction (see `R/missing-predictor.R:120` "baseline-category softmax", and the `n_categories`/cutpoint machinery in `R/julia-bridge.R:1020+`, `R/extract-cutpoints.R`). Confirm whether the multinomial trait's rows carry a special family_id (falling to the Gaussian fallback) or are expanded to K−1 binomial rows (family_id 1, drawn as INDEPENDENT Bernoullis — which is ALSO wrong for a multinomial). The encoding determines the fix.
- **FIX B1a (the feature):** add `.draw_y_per_family()` branches for **multinomial** (baseline-category **softmax** → `rmultinom`/`sample` over K categories from the fitted category linear predictors — NOT independent Bernoullis) and **ordinal_probit** (family 14: **threshold/cutpoint** draws — draw a latent, bin by the fitted cutpoints). Both need the per-trait `n_categories`/cutpoints. ⚠ getting the multinomial softmax wrong passes plumbing but silently breaks calibration — verify against the DGP.
- **FIX B1b (the diagnostic, smaller/decoupled):** surface `n_failed` / effective-draw counts as a STATUS in `extract_cross_correlations()` output, not only inside `bootstrap_Sigma()` (Ayumi Q1). This is Claude-tractable without the feature.
- **Verify (LIVE):** fit a multinomial + ordinal mixed model → `simulate()` yields valid categorical draws → `bootstrap_Sigma(what="cross_corr")` yields finite `multiple_r` / low `n_failed` → add a regression test (mirror `test-m1-8-bootstrap-mixed-family.R`, MIS-05).

### BUG 2 — Gaussian profile route SILENT NON-RETURN (highest severity; needs Ayumi's reproducer)
- `extract_cross_correlations(..., method="profile", link_residual="auto")` on a HEALTHY small Gaussian submodel **did not return and raised no catchable error**. Likely tied to the rank-1 `unique=FALSE` degeneracy: Σ=ΛΛ' ⇒ latent cross-correlations pinned near ±1 (a boundary) ⇒ profile bracket-search may not terminate. (Corroborated by Ayumi's own repo: her 4000sp summary reports the rank-1 fit "produced repeated `multiple_r` magnitudes" = rank-1 shared-loading collapse.)
- **FIX B2:** the route must ALWAYS return intervals or `stop()` catchably (wrap the bracket search + a boundary guard). Root cause needs a **reproducer** — asked Ayumi for the `profile_fit` object / small script in the posted reply. Repro step: re-run B2/B3 with `unique=TRUE` (interior correlations) to isolate boundary-degeneracy vs a deeper bug (her evidence shows `unique=TRUE` trades the ΛΛ' boundary for a Ψ boundary, so a boundary-aware guard is needed regardless).

### BUG 3 — lognormal profile non-finite endpoints (7/10) (smaller)
- `method="profile", link_residual="none"` on a lognormal submodel → 10 contrast rows, 7 non-finite, no status.
- **FIX B3:** add an explicit per-row `profile_status` (e.g. `non_finite`/`unbracketed`) so failures are transparent; investigate lognormal `link_residual="none"` bracketing.

## What PASSED (do not regress)
Wald/Fisher-z on all fit types → finite, bracketed, in-range, no dup/missing status (corroborates register `wald=partial(heuristic)`). Non-PD Hessian on the full ordinary fits is expected (she treated wald as plumbing-QC).

## Gating chain (CI-11 register, Design 39) — AFTER the fixes land + verify
1. Update the CI-11 register PROPOSAL wording (`docs/dev-log/2026-07-19-ci11-register-update-PROPOSAL.md`): profile drop unqualified "most robust" → add the real-data failure modes; bootstrap fenced + the simulate-incompleteness mechanism; wald partial (corroborated). Add 3 hardening-map lines.
2. Fresh D-43 panel on the FINAL wording (gate-3).
3. **Re-invite Ayumi** (issue #1) to re-run the SAME setup as a regression check (only after fixes verify).

## Key files
- `R/methods-gllvmTMB.R:1088` `.draw_y_per_family()` (the fix site) + `:985` `simulate.gllvmTMB_multi`.
- `R/fit-multi.R:209` family_id legend · `R/bootstrap-sigma.R` (bootstrap; `what="cross_corr"`) · `R/extract-sigma.R` / the cross-correlation extractor (surface diagnostics + profile status).
- Register: `docs/design/35-validation-debt-register.md` MIS-05 (the 6/7-family simulate coverage), CI-11 (Section 10).
- Task chips: `task_25cbceb0` (multiple_r profile), `task_7368e457` (hardening minors).

## How to resume (new Codex lane — paste at the gllvmTMB repo root)
```
Rehydrate from docs/dev-log/handover/2026-07-19-ci11-simulate-fix-handover.md + AGENTS.md. Work on branch
claude/cross-family-ci11-20260718. Implement family-completeness simulate() for multinomial (baseline-category
softmax) + ordinal_probit (family 14, threshold) in .draw_y_per_family() (R/methods-gllvmTMB.R:1088), FIRST
confirming the multinomial response encoding; verify LIVE (fit → simulate → bootstrap_Sigma what="cross_corr" →
finite multiple_r + regression test). Also surface n_failed/effective-draw diagnostics + a profile non-finite
status flag. Do NOT touch the Codex REML/AGHQ 0.6 lane's files. Then update the CI-11 register PROPOSAL + hardening
map, run a fresh D-43, and re-invite Ayumi (Ayumi-495/BIRDBASE_pcm#1) to re-test. Reply already posted.
```

## Mission-control
| item | state |
|---|---|
| Ayumi reply (issue #1) | ✅ POSTED (@Ayumi-495) |
| B1 multinomial+ordinal simulate | ⏳ new lane — LIVE feature work; confirm encoding first |
| B1b diagnostics exposure · B3 status flag | ⏳ new lane — smaller, Claude-tractable |
| B2 profile non-return | ⏳ needs Ayumi reproducer + boundary guard |
| CI-11 register / D-43 / re-invite | ⏳ gated on fixes |
