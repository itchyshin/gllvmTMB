# Handover: main reconciliation LANDED + FAM-17 resolved (2026-07-05)

State at wrap-up. `main` @ `6c70428e`. From Claude → next session (fresh, tomorrow).

## Resume tomorrow (start here)
1. **Read order:** this doc → `docs/dev-log/after-task/2026-07-05-merge-to-main-reconciliation.md`
   → `git log --oneline -6` → `AGENTS.md` / `CLAUDE.md`. Trust the repo, not chat memory.
2. **First action:** confirm CI run **`28760836912`** (R-CMD-check for the `6c70428e` vdiffr fix)
   went **green** — `gh run view 28760836912`. It was still in-progress at handoff. If green,
   `git push origin main` to land the local handover commit **`6f829e2c`** (1 ahead of origin;
   held back only so as not to supersede the running CI).
3. If that CI **failed**: triage first (unlikely — the fix restored the exact ubuntu baselines,
   and merged plotting + test are byte-identical to `origin/main`).
4. Then the follow-ups below. **Env runs live R/TMB. Git authority granted to Claude
   (Shinichi, 2026-07-05): may run git incl. push to `main`; the auto-mode classifier may still
   gate a push (needs a Bash permission rule in settings if so).**

## What landed on `main`
1. **`db3934fa`** — the 43-conflict reconciliation of `codex/r-bridge-grouped-dispersion`
   with `origin/main` (union-merge; branch's completion arc + main's 139 commits).
   Verified locally: full suite **5173/0**, R CMD check **0 errors** (macOS); Rose
   pre-land audit clean. After-task:
   `docs/dev-log/after-task/2026-07-05-merge-to-main-reconciliation.md`.
2. **`6c70428e`** — fix: restored 11 vdiffr `_snaps/plot-visual-snapshots/*.svg`
   baselines the merge accidentally dropped (branch had deleted them; merge took the
   deletion). Surfaced only on ubuntu CI (vdiffr is a non-installed Suggest locally →
   the 5 snapshot tests SKIP locally). Merged plotting code + test file are byte-identical
   to `origin/main`, so restored baselines match on ubuntu.

## VERIFY (open loop)
- **CI run `28760836912`** (R-CMD-check for `6c70428e`) was **in-progress** at wrap-up —
  confirm it went green (`gh run view 28760836912`). Expected green; the fix is sound.

## FAM-17 delta-boundary reproduction — RESOLVED (the original session task)
With the **real** `fit$sd_report$pdHess` (NOT the phantom `fit$sdr$pdHess`), the latent
`delta_lognormal` cell converges cleanly across **6/6 seeds**: `conv=0`, real `pdHess=TRUE`,
`max|grad| ≈ 1e-3–1e-2`, intercepts + σ recover. The register's FAM-17 caveat
(`convergence = 1, pdHess = TRUE` "boundary needs solving") **does not reproduce** — it was a
seed/start-specific nlminb termination-code transient, not an identifiability failure.
**No convergence fix is warranted** (confirms the "spurious signal" retraction + the
maintainer guard: do NOT zero the non-Gaussian Ψ). Scope caveat: swept the standard recovery
DGP (n=800, 3 traits); the original probe's exact config is unknown.
- Diagnostic scripts landed: `data-raw/diagnostics/2026-07-05-fam17-delta-latent-boundary-repro.R`
  (gaussian control + fixed-vs-latent) and `-multiseed.R` (6-seed sweep).

## Follow-ups (not done; maintainer's call)
1. **Soften the FAM-17 build caveat** in `docs/design/35-validation-debt-register.md` to
   reflect the 6/6-clean evidence (evidence-record; do not silently promote — Rose/Fisher lens).
2. **Clean up** the reconciliation worktree `/private/tmp/gllvmtmb-mergewt-20260705` +
   branch `claude/merge-main-reconcile-20260705` (content is on `main`;
   `git worktree remove --force …` then `git branch -D …`).
3. `codex/r-bridge-grouped-dispersion` @ `ee837989` is now behind `main` — foldable/deletable.
4. Cosmetic: register EXT rows are physically ordered 34/32/33/31 (IDs correct — EXT-31 =
   `extract_lv_effects` is code-baked; EXT-34 = `extract_proportions`).

## Gotchas / lessons
- **vdiffr-gated snapshot tests SKIP locally** (vdiffr not installed) → invisible to local
  green. For a main-bound merge, also check what the merge **deletes**:
  `git diff origin/main...HEAD --diff-filter=D --stat` (would have caught the dropped `_snaps`).
- **pdHess**: read `fit$sd_report$pdHess` (real); `fit$sdr$pdHess` is a NULL-field phantom.
- **Git authority granted to Claude (Shinichi, 2026-07-05):** Claude may run `git` incl. push
  to `main` directly (the auto-mode classifier may still gate a push — if so, a Bash permission
  rule in settings is needed).
