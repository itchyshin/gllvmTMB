GOAL: see GOAL.md.   STATE: Shinichi signed off the two draft API PRs (D-216); merging them and
building the last two ports.

ARCS DONE (verified):
- O0  #1240 merged (5855e2ad9) — verified by `gh pr view` mergedAt + main's log.
- O3  zi multi-seed recovery, 450 fits on Totoro -> PR #1248 MERGED. Verified by recounting the
      450-row per-seed CSV myself; two cells came out stricter than the agent's table because I also
      required convergence. Register rows FAM-21/22/23 quote the measured fractions.
- O1  bare aborts 999 -> 828 across 7 R files, 16 snapshot tests -> PR #1251. Verified by running
      count_bare_aborts() (828) and spot-checking the two riskiest bullets by fitting the named route.
      Full suite on the branch: FAIL 0 | WARN 55 | SKIP 880 | PASS 27020.
- O4  ordinal_logit() at runtime id 20 -> DRAFT PR #1250. Density identity 5.684e-14 on a
      fixed-effects-only fit (exact NLL, not Laplace); FD gradient 2.786e-08. SIGNED OFF (D-216).
- O5  select_lv() + anova.gllvmTMB_multi() with the chi-bar boundary mixture -> DRAFT PR #1249.
      Empirical size 0.095 (MCSE 0.021) at nominal 0.05, reported not buried. My own brief had the
      direction of the naive test WRONG (it is conservative, not anticonservative); the agent caught
      it, proved it, and pinned it with a test. SIGNED OFF (D-216).
- O8  morning brief written, committed 43fd76573, pushed, delivered to Shinichi.

ARC IN PROGRESS:
- Merge chain (background): wait #1251 CI -> squash-merge -> merge main into the two signed-off
  branches -> recount bare aborts against the new 828 ceiling. Landed when `gh pr view` shows all
  three merged and main's count is <= 828.

NEXT:
- O6 #1243 ordination_uncertainty()  (builder running, branch claude/overnight-ordination-uncertainty)
- O7 #1244 censored_poisson() engine (builder running, branch claude/overnight-censored-poisson)

STOP INSTRUCTION (Shinichi, 2026-09-03 ~06:50 local): scope ENDS AT PARITY — the two ports close it,
nothing beyond. STOP AROUND NOON LOCAL and re-evaluate the situation with him. Do not open new arcs
after the ports.

OPEN GATES (need human): re-evaluation at noon. D-216 signed off #1249/#1250; D-210 covers the rest of the run.

THE TRAP TO RE-CHECK BEFORE EVERY MERGE FROM HERE: once #1251 lands the ratchet ceiling on main is
828 and `test-gapclose-next-steps.R` only lets it fall. Any branch adding a refusal without a ">"
next-step bullet fails CI after taking main. This reddened #1240 (five new zi refusals -> 1004).

TRUTH LIVES IN: origin/main; PRs #1249 #1250 #1251; branches claude/overnight-*;
docs/dev-log/2026-09-03-morning-brief.md; the plan's EXECUTION LOG at
~/.claude/plans/read-agents-md-and-docs-dev-log-handover-lovely-grove.md.

RESUME: read LOOP/GOAL.md then this file; check `gh pr list`; finish the merge chain; collect the O6
and O7 builder reports; ratchet-check each before its PR; after-task report + board refresh.
