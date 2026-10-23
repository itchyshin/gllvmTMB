# After-task — the authorized overnight chain (#1117 → #1118 → Slice 3)

**Date:** 2026-08-18 · **Agent:** Claude Code (Fable orchestrating; Sonnet builders,
Opus refuters) · **Authority:** Shinichi, 2026-08-17 evening — chain with self-merge on
green; Ayumi replies held for his morning review.

## Task goal and outcome

Three lanes, sequential PRs: #1117 (free flat dispersion parameters in mixed-family
fits), #1118 (deviance silent NULL), Slice 3 (Ayumi #23: response-dependency screen +
ridge_path workflow + prose). **#1121 and #1122 merged, issues #1117/#1118 closed;
#1123 (Slice 3) open on green-pending CI at writing.**

## Mathematical contract (the one that matters)

#1117: dispersion vectors gated whole-vector left free parameters with zero likelihood
contribution in mixed fits — flat directions, mechanically singular Hessians, pdHess
FALSE, phantom confint targets. Fixed by per-trait TMB-map pinning from one shared
helper over a 12-row family table; single-family fits proven bit-identical.

## The evidence discipline held, and it was needed — 4-for-4

Every implementation was adversarially refuted by a fresh context before its PR, and
EVERY refute found a real defect: the unpinned tweedie-p branch (#1117); ridge_path's
unsigned directional verdict + the certificate collapse under a redundant column
(Slice 3); (earlier the same day: the sd_W twin, the two-block ridge). All repaired with
fail-first records; the tautological classification test was replaced with tests that
fail against the old code. **Prose rules did not survive contact even once today;
structure + refute caught everything.**

## Honesty items

- Test (b)'s pdHess assertion was rescoped after a CI flake: three-seed check showed
  TRUE/TRUE/FALSE — genuine weak identifiability (student sigma vs auto-Psi), not the
  fix. The mechanism assertions stay; pdHess is proven on the well-conditioned pair.
- #1118 got an orchestrator line-by-line review instead of a full Opus refute
  (15-line delegating method) — proportionality call, recorded for Melissa.
- check_pkgdown was missing from #1114's verification and CI doesn't run it; the gap it
  left was caught by the Slice-3 builder and closed in #1122. Process note filed.

## Melissa — plan vs actual (chain)

On plan: sequencing, one-open-PR, fail-first, refutes, self-merge only on green, no
estimand decisions taken unilaterally. Adaptive: the #1118 refute proportionality call;
the pdHess rescope. Drift class (recurring, now 4 instances): "instrument/verdict layer
ships one member short" — the ledger row from yesterday stands, evidence strengthened.
New candidate pattern filed in the taxonomy from #1120: "positional contract with silent
reordering."

## GitHub ledger

Merged: #1121, #1122. Open: #1123 (CI). Closed: issues #1117, #1118. Filed: #1119,
#1120. Held: Ayumi replies (Shinichi's morning), PRs #1107/#1108 (his review).
