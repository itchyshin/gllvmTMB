# After-task — Diagnostic + bootstrap robustness (twin-review batch 3)

**Date:** 2026-07-03
**Agent:** Claude (Ada; Fisher inference lens, Curie diagnostics lens)
**Branch:** `fix/diagnostics-bootstrap-robustness` (from `origin/main`)
**Issues closed:** #603, #644, #652 (itchyshin/gllvmTMB)

## Scope

Third batch of the issue-clearing campaign: diagnostic-label and bootstrap
reliability fixes, all in files byte-identical to `origin/main`. No likelihood,
family, formula-grammar, or `src/gllvmTMB.cpp` change.

## Outcome

| Issue | Fix |
|---|---|
| #603 | `.gllvmTMB_family_label_from_id()` now maps runtime family id 15 to `nbinom1` (verified against `family_to_id()` in `R/fit-multi.R`). Previously NB1 residual/rootogram rows were labelled `family_id_15` in facet strips and captions. |
| #652 | The two seeded residual helpers (`.gllvmTMB_exact_rq_residuals`, `.gllvmTMB_simulation_rank_residuals`) save and restore `.Random.seed` via a base-R `on.exit` idiom, so a seeded `residuals()` / `predictive_check()` no longer overwrites the caller's global RNG stream (matching base R's `simulate.lm` contract). `withr` is Suggests-only, so no `withr::` call is used in package code. |
| #644 | The loading-CI bootstrap attaches `attr(out, "n_failed")` and emits a `cli_warn` when any refit failed/was rejected, mirroring `.phylo_signal_bootstrap_ci`. Intervals from a small surviving fraction are no longer presented as if built from all replicates. |

## Checks (DoD)

1. **Implementation** — 2 R files; branch pushed; CI pending on PR.
2. **Test** — new `tests/testthat/test-diagnostics-family-label.R` (3) exercises
   #603 directly; existing `test-predictive-diagnostics.R` and
   `test-loading-ci-bootstrap.R` exercise the #652/#644 code paths (no regression).
   No simulation-recovery requirement (no likelihood/family/keyword/estimator change).
3. **Docs** — no roxygen/`man` change (no exported signature change; #644 adds an
   attribute + warning to an existing return). NEWS entry added.
4. **Example** — no new user-facing surface.
5. **check-log** — entry added with commands.
6. **Review** — Fisher (bootstrap reliability / n_failed surfacing) + Curie
   (diagnostic labelling) perspectives.

## Follow-up

- Deferred (need a statistical/threshold judgment, not a guard → Codex/Fisher):
  #687 (loading bootstrap `scale_guard = 5*max|Lambda_hat|` truncates small-loading
  tails) and #693 (rootogram auto `max_count` can explode bins for overdispersed
  fits). Both are in these same files but require a design decision on the
  replacement threshold / cap.
