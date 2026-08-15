# checkpoint — cursor-mspl-phase4-tapes-planned

GOAL: see GOAL.md.   STATE: **LANDED** on `cursor/mspl-phase4-tapes-planned` · [PR #978](https://github.com/itchyshin/gllvmTMB/pull/978). Still **not admitted**.

ARCS DONE (verified): A0–A5 (Wave 1–5).

ARC IN PROGRESS: none. Finish line was fenced planned tapes + Poisson public door.

NEXT: human review / merge #978 when CI green. Do **not** merge #972–#976 from this lane. Do **not** flip `planned` → `admitted`.

OPEN GATES (need human): merge of #978; Poisson admission remains a later G0. Codex interval lane stays PROTECTED.

TRUTH LIVES IN: `cursor/mspl-phase4-tapes-planned` · this kit · after-task `docs/dev-log/after-task/2026-08-15-mspl-phase4-tapes-planned.md` · PR #978.

## Wave 5 receipt (2026-08-15 closeout; science not rebuilt)

`OMP_NUM_THREADS=1` `NOT_CRAN=true` `pkgload::load_all(".", compile = FALSE)` — DLL already matched #978 tip `57ae6983`.

| File | Result |
|---|---|
| `test-mspl-prepare-fence.R` | PASS (4 dots / 1 test) |
| `test-mspl-poisson-public-door.R` | PASS (6 / 2) |
| `test-mspl-fenced-family-tapes.R` | PASS (23 / 4) |
| `test-mspl-nb1-fenced-tape.R` | PASS (12 / 4) |
| `test-mspl-nb2-fenced-tape.R` | PASS (17 / 4) |
| `test-mspl-api.R` | PASS (12) |
| `test-mspl-registry.R` | PASS (2) |
| `test-mspl-poisson-phase4-oracles.R` | PASS (9) |

Not re-run this wave: off-CRAN Gaussian smoke / Heywood oracles (already claimed on #978; no `src/` edit in Wave 5). Not run: `devtools::test()`, `R CMD check`, pkgdown, Totoro.

RESUME:
```text
You are lane cursor/mspl-phase4-tapes-planned — RESUME.
READ FIRST: docs/dev-log/lanes/cursor-mspl-phase4-tapes-planned/LOOP/GOAL.md -> checkpoint.md.
WORKSPACE: /private/tmp/gllvmtmb-mspl-estimator-programme-roadmap
GOAL LANDED: five C++ tapes; public mspl = gaussian + bernoulli + Poisson only; still planned not admitted.
PR: https://github.com/itchyshin/gllvmTMB/pull/978
DO NOT: admit, NEWS covered, merge #972–#976, touch Codex interval, transplant c, call GLM-outer I_LA(beta).
NEXT: review/merge #978 when CI green. New work needs a new GOAL.
```
