# Handover — Claude→Claude: `multinomial()` family COMPLETE (Lane C)

**Date:** 2026-07-16 · **Branch:** `agent/lane-c-multinomial` (worktree
`.claude/worktrees/lane-c-multinomial`, based `48a66b93`) · **State: DONE + committed, local, unpushed.**

## Status: the arc is finished. Nothing is in-flight.
gllvmTMB now has a working, correct, tested, honestly-fenced Tier-1 `multinomial()` (baseline-category
logit / softmax) response family, `family_id 16`, R-only, fixed-effects-only. Built entirely on Claude
(maintainer moved it off Codex for token reasons; Codex review is app-update-blocked).

**Verified:**
- fid-16 C++ softmax likelihood (ported MD6c, anchor-once anti-double-count) — **D-43 likelihood lens = DONE** (correct MLE, not artifact).
- `multinomial()` + `expand_multinomial_response()` (K categories → K−1 pseudo-trait rows; no parser change).
- Recovery K=3, K=4, + 5-seed aggregate (band 0.30). `predict(type="response")` per-category probabilities (sum-to-1, calibrated).
- All Tier-1 fences fail-loud + tested: latent/RE, K<3→binomial, mixed-family `list()`, `extract_correlations()`, `predict(newdata=)`, `simulate()`; `residuals()`→unsupported. **D-43 honesty lens = DONE.**
- `tests/testthat/test-multinomial.R` **43/43**; `test-enum-runtime-ids.R` 15/15; ordinal + entry regressions clean.
- **`R CMD check --as-cran`: 0E / 0W / 1N** (the 1N is the inherent "New submission" note).
- `man/multinomial.Rd` generated. FAM-20 stays `partial` (no public claim; promotion needs maintainer sign-off + clean re-audit).

## Key files (for reference, not action)
- `src/gllvmTMB.cpp` — fid-16 branch in the obs loop (search `family_id_vec(o) == 16`, `logp_mn`).
- `R/gllvmTMB.R` — `expand_multinomial_response()` + `multinomial_meta` attach.
- `R/methods-gllvmTMB.R` — `.predict_multinomial()`, predict/simulate fences.
- `R/families.R` — `multinomial()` constructor. `R/fit-multi.R` — `family_to_id` 16L + Tier-1 covstruct guard + data plumbing. `R/extract-correlations.R` — fid-16 refusal.
- `docs/design/83-multinomial-response-family.md` — the spec. After-task: `docs/dev-log/after-task/2026-07-16-multinomial-c1-c2-core.md`.

## Small follow-ups (optional, none blocking)
1. **Wire `multinomial(baseline=)`** — the arg exists but the expansion ignores it (uses the first factor level; users set the reference via `relevel()`). ~10-line change in `expand_multinomial_response()`.
2. **Typed classes** for the 3 message-matched fences (latent/RE, K<3, mixed) — currently regexp-tested; the load-bearing `extract_correlations` fence is already typed. Robustness only.
3. `dev/multinomial-recovery.R` band-calibration harness (Totoro/DRAC).
4. **Push the branch / open PR** when ready (currently local-first).
5. **Codex adversarial review** — `adversarial-review "--base 48a66b93"` — once the Codex *desktop app* is updated (npm-latest CLI 0.144.5 is rejected for the whole gpt-5.6 family; ChatGPT account blocks older models).

## Note on the `/goal`
The active `/goal` contains two clauses that cannot be satisfied by any code: "SOLO PLATFORM = CODEX"
(the maintainer explicitly overrode this — "drive gllvm all from Claude") and literal "0N" (the
"New submission" note is inherent to any first `--as-cran` run and clears only once on CRAN). Its
automated checker will keep re-flagging them; `/goal clear` ends it.
