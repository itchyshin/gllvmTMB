GOAL: see GOAL.md.   STATE: COMPLETE. Reverse parity is closed; every arc landed on main.

ARCS DONE (verified — each by reading the artifact, never a "DONE" line):
- O0  #1240 zero-inflated families
- O3  #1248 450-fit Totoro recovery campaign; register rows quote measured seed-fractions
- O1  #1251 bare aborts 999 -> 828, ratchet lowered
- O4  #1250 ordinal_logit() at runtime family id 20
- O5  #1249 select_lv() + anova() with the chi-bar boundary mixture
- O6  #1253 ordination_uncertainty()
- O7  #1254 censored_poisson() engine at runtime family id 21
- O8  morning brief + after-task report

main @ 073d197e8. Nothing of this lane's is open.

OPEN GATES: none. D-216 signed off #1249/#1250; D-217 approved #1253/#1254.

STILL OWED (deliberately NOT started — Shinichi's "we can stop at the parity" fence):
- 828 refusals still lacking a next step (#1247), behind a ratchet that only falls.
- Multi-seed campaigns for ordinal_logit() and censored_poisson(); both ship on few-seed
  regression guards and their register rows say so.
- No coverage evidence for ordination_uncertainty(); both returned quantities are Wald.

LESSONS THIS LANE PAID FOR (all three cost real time; all three recur):
1. testthat prints "DONE" over a file where every assertion skipped behind skip_on_cran().
   Read the counts; set NOT_CRAN.
2. A merge watcher logged "#1249 MERGED" when no merge had happened — it checked CI but never
   the merge command's own result. Read the PR state back.
3. A conflict marker makes an R file unparseable; the bare-abort counter silently skips such a
   file, so the count comes out BELOW the ceiling and reads as a pass. Check every file parses
   before trusting any count. This fired three times.

TRUTH LIVES IN: origin/main @ 073d197e8; docs/dev-log/after-task/2026-09-03-gapclose-overnight-arcs.md;
docs/dev-log/2026-09-03-morning-brief.md; vault D-216/D-217.

RESUME: nothing pending. A future lane starts from the STILL OWED list above.
