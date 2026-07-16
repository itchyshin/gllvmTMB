# Handover — Claude → Claude: `multinomial()` family COMPLETE (Lane C)

**You are Claude, picking up a FINISHED, parallel side-lane.** Date: 2026-07-16 ·
Branch: `agent/lane-c-multinomial` (worktree `.claude/worktrees/lane-c-multinomial`, based
`48a66b93`) · **State: DONE + committed, LOCAL, UNPUSHED.** This is *not* the main thread —
the headline release arc is Lane A (interval coverage, `CLAUDE.md` current-handoff pointer =
`2026-07-13-claude-handover.md`). Do not redirect that pointer to this doc.

## 🔴 Loud flag: this branch is UNPUSHED
19 commits live only in the local worktree. A fresh session checks out a clean tree and will
NOT see them unless the branch is pushed. **Pushing / opening a PR is the maintainer's call**
(local-first discipline held all session; a PR triggers CI). To push + PR when you want:
```
git -C "<repo>" push -u origin agent/lane-c-multinomial
gh pr create --base main --head agent/lane-c-multinomial --title "feat: multinomial() response family (Tier 1)" --body "See docs/dev-log/after-task/2026-07-16-multinomial-c1-c2-core.md"
```

## Goals / mission
gllvmTMB = multivariate stacked-trait GLLVMs. This arc added a genuine **unordered categorical
(multinomial) response family** — the companion to the ordinal cell — R-only, `family_id 16`,
**Tier-1 fixed-effects-only**. Full rationale: `docs/design/83-multinomial-response-family.md`.

## Plans / roadmap (beyond immediate)
Multinomial was on-record "planned; post-CRAN"; the maintainer re-scoped it into the 0.6 dev
cycle, fixed-effects-only. Tier 2 (the K−1-dimensional latent-scale correlation surface) stays
deferred — it breaks the single-latent contract (Design 62 delta precedent) and needs its own
derivation. Julia (GLLVM.jl) parity is a separate later arc.

## Critical context
- **Built entirely on Claude** (maintainer moved it off the plan's Codex routing — "drive gllvm
  all from Claude, token reasons"; Codex review is app-update-blocked). The plan's original
  Codex-baton handoff (`docs/dev-log/handover/2026-07-16-claude-to-codex-multinomial.md`) is a
  now-superseded design artifact.
- The mechanism: a K-category response expands into **K−1 category-contrast pseudo-trait rows**
  (`<trait>:<cat>`) tied by a `.multinom_group_` index, BEFORE parse — so the ordinary
  `0 + trait + (0+trait):x` grammar builds the per-category design (no parser change). The C++
  `fid==16` branch evaluates one grouped softmax per observation-group at the anchor row.

## What was accomplished (all verified)
- fid-16 C++ softmax likelihood (ported the validated MD6c kernel, anchor-once anti-double-count).
- `multinomial()` constructor + `expand_multinomial_response()` + Tier-1 covstruct fence.
- Recovery K=3, K=4, + 5-seed aggregate (band 0.30). `predict(type="response")` per-category
  probabilities (sum-to-1, calibrated); `predict(type="link")` = K−1 logits.
- All misuse fails loud + tested: latent/RE, K<3→binomial, mixed-family, `extract_correlations`,
  `predict(newdata=)`, `simulate`; `residuals`→unsupported.
- **Rose D-43 audit (3 fresh lenses):** likelihood-correctness = DONE, honesty/fencing = DONE,
  recovery-evidence = NOT-DONE→addressed (it caught a failing `test-enum-runtime-ids.R` — fixed).
- `test-multinomial.R` **43/43**; regressions clean. `man/multinomial.Rd` generated.
- **`R CMD check --as-cran`: 0E / 0W / 1N** (the 1N = inherent "New submission"; unremovable pre-CRAN).

## Current working state
- **Working / done:** the family fits, recovers, predicts, and fences correctly; check clean bar
  the inherent note.
- **In-progress:** none.
- **Blocked:** the independent Codex adversarial review (`adversarial-review "--base 48a66b93"`) —
  Codex CLI 0.144.5 is rejected for the whole gpt-5.6 family; needs the Codex desktop app updated.

## Key decisions & rationale
- Tier-1 fixed-effects-only (Design 62 single-latent-scale precedent) — categorical spans K−1
  latent dims, so no single trait-correlation; fenced by fail-loud tests, not just prose.
- Name `multinomial()` (not `categorical()`, which is the exported missing-*predictor* imputation family).
- Recovery via inline `sample()` DGP; band = ordinal FIXED-EFFECT abs 0.30/0.40, not the 2.5x variance band.
- FAM-20 stays `partial` — no public NEWS/README claim before maintainer sign-off + a clean re-audit.

## Files created / modified (session diff 48a66b93..HEAD)
Engine: `src/gllvmTMB.cpp`, `R/gllvmTMB.R`, `R/fit-multi.R`, `R/families.R`, `R/enum.R`,
`R/methods-gllvmTMB.R`, `R/extract-correlations.R`, `NAMESPACE`, `DESCRIPTION`, `man/multinomial.Rd`.
Tests: `tests/testthat/test-multinomial.R`, `tests/testthat/test-enum-runtime-ids.R`.
Docs: `docs/design/83-multinomial-response-family.md`, `docs/design/02-family-registry.md`,
`docs/design/35-validation-debt-register.md`, `docs/dev-log/after-task/2026-07-16-multinomial-c0.md`,
`docs/dev-log/after-task/2026-07-16-multinomial-c1-c2-core.md`, `docs/dev-log/check-log.md`,
`docs/dev-log/handover/2026-07-16-claude-to-codex-multinomial.md`, this doc.

## Next immediate steps (all OPTIONAL — nothing blocking)
1. **Wire `multinomial(baseline=)`** — arg exists but the expansion ignores it (uses first factor
   level; users set the reference via `relevel()`). ~10 lines in `expand_multinomial_response()`.
2. **Typed condition classes** for the 3 message-matched fences (latent/RE, K<3, mixed) — robustness;
   the load-bearing `extract_correlations` fence is already typed.
3. `dev/multinomial-recovery.R` band-calibration harness (Totoro/DRAC, never GitHub Actions — D-50).
4. **Push branch / open PR** (see loud flag above) when the maintainer is ready.
5. **Codex adversarial review** once the Codex app is updated.
6. **Promote FAM-20** off `partial` only after maintainer sign-off + a clean D-43 re-audit; then NEWS/README wording.

## Gotchas / failed approaches
- A single family object *is* a list — `is.list(family)` is TRUE for one `multinomial()`; test class
  FIRST (`inherits(family,"family")`) before treating it as a mixed-family list (caught in a smoke fit).
- Adding a new `family_id` to `.valid_family` requires the SAME id in `test-enum-runtime-ids.R` or it
  fails (the D-43 audit + R CMD check both caught this).
- `simulate()` on a multinomial fit must fail loud, NOT fall back to Gaussian-on-link (would fabricate data).

## Mission control
| repo | branch | CI / check | what shipped | plan by leverage |
|---|---|---|---|---|
| gllvmTMB | `agent/lane-c-multinomial` (local, unpushed) | `R CMD check --as-cran` 0E/0W/1N; tests 43/43 | Tier-1 `multinomial()` family: fid-16 softmax, K=3/4 recovery, per-category predict, all fences, D-43-audited | (1) push/PR (maintainer) → (2) optional: baseline= arg, typed fences → (3) Codex review post app-update → (4) FAM-20 promotion after sign-off |

## How to resume (rehydration recipe — TARGET = claude)
1. `cd` to the repo; `git checkout agent/lane-c-multinomial` (push first if resuming elsewhere — see loud flag).
2. Read: this doc → `docs/design/83-multinomial-response-family.md` → the after-task
   `docs/dev-log/after-task/2026-07-16-multinomial-c1-c2-core.md`. (The main repo thread is Lane A —
   `CLAUDE.md`'s pointer — do NOT conflate.)
3. Before any PUBLIC capability claim, spawn a fresh **Rose** lens (D-43); FAM-20 stays `partial` until it clears.
4. Claude plans/refactors/prose + runs the R test suite (`devtools::load_all()` compiles the C++ in ~25s here).

**One-command resume** (paste in YOUR authenticated terminal, from the repo root):
```
claude "Rehydrate from docs/dev-log/handover/2026-07-16-claude-multinomial-handover.md, then continue with the optional Next Immediate Steps (baseline= arg first)."
```
A fresh session = a clean context window — the point of resuming rather than compacting.
