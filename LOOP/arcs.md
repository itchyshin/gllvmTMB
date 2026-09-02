# Arcs — gllvmTMB gap-closure overnight lane (status-marked; gates flagged)

| id | arc | gate | status |
|---|---|---|---|
| O0 | Merge PR #1240 (approved D-207) once local suite+check (`scratchpad/g-all-arcD`, or rerun) and CI are green, by merge commit; then `git merge origin/main` into this lane; teardown the merged `gllvmTMB-gapclose-20260902` worktree (`git worktree remove`) and delete its remote branch is NOT allowed (leave branches) | merge is pre-approved by Shinichi | pending |
| O1 | #1247 bare aborts, batch 1: `dev/gapclose/count-bare-aborts.R` inventory → the ~150 most user-reachable (R/gllvmTMB.R, R/brms-sugar.R, R/fit-multi.R, R/families.R, R/mesh.R) get a ">" next-step bullet; snapshot tests; ratchet number lowered; PR `claude/overnight-aborts-1`; full suite+check; auto-merge on green CI | low-risk → auto-merge | pending |
| O2 | #1247 batch 2 (next ~150; diagnose.R, ridge-path.R, methods, extractors) same recipe | low-risk → auto-merge | pending |
| O3 | zi multi-seed recovery: D-139 estimate; Totoro pre-run (1 cell × 3 families, timed); DRAC array (≤200 core-h) via existing `cm-` socket; summaries + checksums committed under `dev/gapclose/arcD/recovery/`; compare with GLLVM.jl ADEMP; reword FAM-21..23 on evidence (Rose check) — PR `claude/overnight-zi-recovery`; docs+tests only → auto-merge if CI green | compute within cap pre-approved; register wording = Rose gate | pending |
| O4 | #1241 `ordinal_logit()`: recon (family hooks; ordinal_probit as template; GLLVM.jl `Ordinal`), alignment table, TMB cumulative-logit likelihood (new family id), constructor, cutpoints per trait, simulate/fitted/residuals, recovery tests, register FAM-24 partial, NEWS boundary; fresh Opus review; DRAFT PR only | API → DRAFT, wait | pending |
| O5 | #1242 `select_lv()` + `anova.gllvmTMB` (chi-bar-square boundary p-values, D=1..K refits, AIC/BIC table); GLLVM.jl `select_lv`/`chibar2_pvalue` as oracles; tests incl. a boundary case; roxygen; NEWS; register row; fresh Opus review; DRAFT PR only | API → DRAFT, wait | pending |
| O6 | #1243 `ordination_uncertainty()` (time permitting): score SEs from the Laplace curvature, plot hook; tests; DRAFT PR | API → DRAFT | optional |
| O7 | #1244 `censored_poisson()` engine (time permitting): TMB likelihood behind the existing constructor; recovery test; register FAM-16 update; DRAFT PR | API/likelihood → DRAFT | optional |
| O8 | Morning brief `docs/dev-log/2026-09-03-morning-brief.md` + board refresh + vault AGENT_LOG line + Melissa reconcile of the night; final checkpoint | — | pending |
