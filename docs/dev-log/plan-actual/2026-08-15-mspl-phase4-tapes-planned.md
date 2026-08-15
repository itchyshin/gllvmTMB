# Plan-actual — MSPL Phase-4 tapes-planned (Melissa)

```text
🎯 GOAL
Solo: Cursor
Deliverable: one shared weight-hook and five fenced planned C++ tapes; public estimator="mspl" runs only for gaussian, bernoulli, and Poisson
HEADLINE: all five tapes exist; only Poisson becomes newly callable; nobody is admitted
DEFER: admit · NEWS covered · SE · Totoro>30min · EVA/VA/AGHQ-MSPL · Codex interval · public MSPL on NB1/NB2/beta/Tweedie
```

## Slice ledger

| Slice | Plan | Actual | Status |
|---|---|---|---|
| A0 LOOP kit | branch from `origin/main` @ #977 | `b1271cca`; kit under `lanes/cursor-mspl-phase4-tapes-planned/LOOP/` | **DONE** |
| A1 failing tests | Poisson public-door RED before `src/` | RED on old “binomial or gaussian only” fence; now GREEN | **DONE** |
| A2 shared hook | one cpp owner; Bernoulli 2-arg bit-identical | `gll_mspl_log_weight` restored; `gll_mspl_log_weight_glm` dispatches 2/5/15/7/6 | **DONE** |
| A3 Poisson door | prepare `{0,1,2}`; `c=1`; still `planned` | `fam_ids %in% c(0L,1L,2L)`; registry `planned`/`phase4_prep`; public fit no longer the old fence | **DONE** |
| A4 fenced tapes | C++ exists; public still errors | NB2/NB1/beta/Tweedie still `gllvmTMB_mspl_unsupported`; NB2 `excluded`; no planned rows for NB1/beta/Tweedie | **DONE** |
| A5 closeout | Rose / Shannon / Melissa; no admit | this file + after-task; NEWS untouched | **DONE** |

## Drift

- Curie-nb1 added `tests/testthat/test-mspl-nb1-fenced-tape.R` beside the shared fence file. Kept; C++ comments aligned to “PMF-summed exact I” / “NOT quasi W=mu/(1+phi)”.
- Poisson public-door notes test first treated the words “admitted” and “covered” as forbidden even inside “not admitted; not covered”. Tightened to require the negations.
- NB2 lookup by exact `cell_id` is NULL because the excluded row is suffixed `:nbinom2`. Test now reads the registry table, matching `test-mspl-registry.R`.

## HARD STOP hits

None. No admit. No NEWS covered. No public `mspl` on NB1/NB2/beta/Tweedie. No SE. #972–#976 not merged.

## Notes

Closed kits (catch-up / gaussian / point-continue / phase4-prep-goal) were not reopened. Codex interval lane untouched. No `git add -A`. No force-push to `main`.
