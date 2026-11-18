# Recovery checkpoint — G3 Paper 2 invalid provenance

- **Branch / head:** `codex/two-paper-global-analysis` at `a2accfaf`.
- **Worktree:** `/private/tmp/gllvmtmb-two-paper-global-analysis`.
- **Status:** clean tracked tree; ignored root
  `dev/isdm-package-recovery/results/G3_P2_S6_C360_R3_V1/` is terminal and
  must not be deleted, overwritten, or rerun.
- **Completed:** P2 runner/tests (`494749aa`), provenance corrections
  (`a2accfaf`), focused tests, no-fit validation, immutable preflight, and one
  approved smoke.
- **Smoke evidence:** `INVALID_PROVENANCE`, `fit_elapsed_s = NA`, total
  elapsed 2.119 seconds, `raw = NULL`, `g3 = NULL`, no `fit.rds`. MD5 content
  hashes matched; `devtools::load_all()` temporary DLL path differed.
- **Independent reviews:** Gauss/Noether numerical FAIL/no result; Fisher PASS
  for retained invalid-attempt interpretation; Rose WARN for closure and future
  field-by-field receipt diagnostics.
- **Do not redo:** do not alter the invalid root, historical G2 holds, Paper 2
  STOP/HOLD, DGP, likelihood, maps, transforms, thresholds, or public surface;
  do not fit, profile, simulate, or launch Totoro/DRAC work.
- **Next safe action:** request a new, no-fit provenance-design amendment and
  Gate-B packet. It must not authorise a replacement fit automatically.
