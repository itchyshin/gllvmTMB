# Claude → Claude handover — the categorical arc is CLOSED; follow-ups are filed

**Date:** 2026-08-17 · **Author:** Claude (Fable) · **Target:** a fresh Claude session
**Lane:** `claude/categorical-paper-alignment-20260817` — **MERGED and closed**
**Shipped:** PR [#1057](https://github.com/itchyshin/gllvmTMB/pull/1057) (`489162dc`) ·
PR [#1088](https://github.com/itchyshin/gllvmTMB/pull/1088) (`c26c294c`)

You are Claude, picking up after a two-day arc on gllvmTMB's categorical
families. **Nothing from this arc is owed.** Its work is on `main`; its
open questions are GitHub issues. Your job is to pick ONE of those issues —
or something else entirely — not to resume this lane.

---

## Critical context

This repo is **multi-lane**. Do not treat it as a single writable lane, and
do not read this document as the repository's status. The authoritative map
is `docs/dev-log/handover/2026-07-25-active-lane-split.md`, which names each
lane's own current handover. As of this writing the **Cursor LA-MSPL lane**
is the active programme there (D-157 B1 SIGNED PARK; Codex Lane B
PROTECTED). This document adds one closed lane to that map and takes
nothing from the others.

**FIRST ACTION, before claiming any file:** `bash ~/shinichi-brain/tools/lane_preflight.sh`
and act on its verdict. At the time of writing it reported a foreign lane
active plus ~17 live lanes.

## Goals / mission (why this arc existed)

`multinomial()` was marked "limited" for structured random effects on the
capability board, and issue #897 recorded that `ordinal_probit` fits with
degenerate covariance passed every check the package had (239/239 unflagged
where binomial catches 272/272). Mid-arc, Shinichi supplied Mizuno,
Drobniak, Williams, Lagisz & Nakagawa (2025) *J. Evol. Biol.* 38:1699-1715
(doi 10.1093/jeb/voaf116) — the paper Design 84 was grounded on — and the
arc was reshaped to lead with alignment against it.

## What was accomplished

**Structured-dependency surface (PR #1057).**
`multinomial()` is admitted across phylo / animal / kernel × latent, dep,
indep; spatial × latent, indep, dep; `(1|g)` and cluster/cluster2
intercepts. `*_scalar` is a **documented refusal**, not an omission: sigma^2 I
across shared-baseline contrasts has no interpretable target against the
(I+J) null, and a null-DGP probe backs it. The admission fence was rebuilt:
the old `use_*` allow-list leaked **eight** documented-as-blocked cells
because the keyword grid folds distinct keywords onto shared engine flags,
and `mi()` was invisible to it entirely. Now a covstruct-keyed admission
table with a typed condition class.

**Paper alignment + detector (PR #1088).**
- 🔴 **`extract_phylo_signal()` returned H^2 = 1.0 for every categorical
  trait and contrast** — the fixed liability residual never entered the
  denominator. `link_residual = "auto"` now returns the paper's estimand
  exactly (verified to 1e-10; live MCMCglmm comparator 0.357 vs 0.436).
  The default is unchanged, so no existing result moves.
- A 20-row paper-equation ↔ gllvmTMB-call alignment table in
  `docs/design/123-multinomial-structured-surface.md`, plus the Box-2
  cutpoint-parameterisation translation for readers arriving from MCMCglmm.
- ordinal × kernel/animal engine identities **measured** (previously
  inferred); the paper's own deferred eq 38-46 model (phylogenetic +
  non-phylogenetic species effect together) **runs**, with ordinal passing
  all four component gates.
- **Multinomial degeneracy screen: calibrated, armed, fit-time warning
  wired** under the existing `warn_runaway` control with its own
  once-per-session slot. M1 6/7 labeled + 7/7 out-of-sample, M2 8/8,
  M3 3/3, zero false positives on the informative healthy pool.
- **Ordinal screen: arms ship DISARMED**, on evidence. See below.

## Current working state

**working** — everything above is on `main` and covered by tests.
**in-progress** — nothing.
**blocked** — nothing owed by this lane.

### Landing State ledger

| item | state |
|---|---|
| `claude/categorical-paper-alignment-20260817` | **LANDED** — merged `c26c294c`, 0 unpushed |
| `claude/multinomial-structured-20260816` | **LANDED** — merged `489162dc`, 0 unpushed (one untracked scratch file `.full-test-run.log` in its worktree; not committed, not needed) |
| `tmp/*`, `worktree-agent-*` branches flagged by `handoff_gate.sh` | **PROTECTED — NOT MINE.** Other lanes' unlanded state. Do not land, rebase, or delete them on this lane's behalf |
| Six temp worktrees under `/private/tmp/gllvmtmb-*` created by this arc | **CARRIED-OVER (inert).** Left for Shinichi's inspection; safe to `git worktree remove` once he has looked. They hold no unlanded commits |

⚠ **Post-merge CI was still running when #1088 merged.** Local evidence was
strong (full `devtools::test()` green; `--as-cran` 0E/0W on the prior
rebase), but the GitHub R-CMD-check had not finished. **Check
`gh run list --branch main --limit 3` early** and fix anything it surfaced.

## Key decisions and rationale

1. **`*_scalar` refused for multinomial** — not mechanically impossible (it
   fitted silently before the fence repair), but uninterpretable: the null
   for shared-baseline contrasts is (I+J)-shaped, so a fitted scalar
   variance confounds signal with contrast geometry. Ordinal keeps its
   scalar cell (one liability axis).
2. **Ordinal detector arms ship DISARMED.** Five candidate statistics were
   pre-registered and eliminated (details below). No threshold met the
   frozen targets, so the pre-registration's own ship-disarmed fallback
   applies. **Do not arm them without new evidence.**
3. **Multinomial fit-time warning wired; ordinal deliberately not** — the
   ordinal row has nothing to warn about while disarmed, so a hook there
   would be a permanent no-op.
4. **Binomial re-calibration (#1098) is NOT a prerequisite** for the ordinal
   route. The dichotomised check fails on *damaged input*, not thresholds.

## The ordinal question — read this before touching #897 or #1097

Five candidates, all pre-registered before running, all eliminated:

| candidate | outcome |
|---|---|
| `max_loading_unit` (absolute liability scale) | at binomial's own threshold of 6: 100% sensitivity, **39.2% FP** — worse than the 25% rate #897 complains about. Does not transport across heterogeneous per-trait scales |
| `relative_loading` (family-scoped) | 28.6% FP at best sensitivity |
| `loading / cutpoint_span` | **refused on circularity** — cor(span, degeneracy) = +0.546, p = 4.6e-20; the span is a symptom of the same runaway |
| `spike_ratio` (max ÷ second-max) | independent (cor +0.242), discriminates centrally (4.16 vs 1.32), but **2.4% sensitivity** at zero FP |
| dichotomised refit (collapse to binary, run the binomial screen) | 97.6% sensitivity but **86.3% FP** — the collapse *manufactures* what the screen detects |

🔴 **The dichotomised result falsified one leg of this arc's own mechanism
verdict.** The S1 probe concluded "category-level separation, not link
saturation" partly on "24/24 dichotomised refits fire". A check firing on
86% of healthy fits fires 24/24 by construction, so that measurement
discriminates nothing. **Corrected standing: "NOT link saturation" is solid**
(flat-row share exactly 0 on all 24 degenerate fits — the
`gll_log_pnorm_diff` underflow is never reached); **"therefore separation"
is the residual hypothesis, not demonstrated.** Cite only the negative half.

The search was stopped deliberately at four loading-based statistics to
avoid multiple testing on the same 315 fits. A working check needs a
different information source — see #1097 for the candidates worth
pre-registering (observed-information/curvature; a refit that preserves the
ordinal information; multi-start disagreement).

## Files created / modified

Full diffs: `git diff origin/main~2...origin/main` covers both merges.
Principal paths:

- `R/multinomial-fence.R` (new), `R/fit-multi.R`, `R/brms-sugar.R`,
  `R/diagnose.R`, `R/extract-omega.R`, `R/extract-sigma.R`,
  `R/families.R`, `R/gllvmTMB.R`
- `tests/testthat/test-multinomial-fence.R`, `test-sanity-categorical.R`,
  `test-matrix-multinomial-{phylo,spatial,unit}.R`,
  `test-matrix-ordinal-kernel-animal.R`, `test-phylo-signal-categorical.R`,
  `test-runaway-warning.R`, `test-sanity-multi.R`
- `docs/design/123-multinomial-structured-surface.md` (the surface + the
  paper alignment table + detector coverage),
  `docs/design/35-validation-debt-register.md` (FAM-14, FAM-20*, DIA-08),
  `docs/design/02-family-registry.md`, `docs/dev-log/capability-surface.html`
- `dev/multinomial-structured/`, `dev/categorical-replication/`,
  `dev/ordinal-degeneracy/` — every campaign's pre-registered criteria,
  scripts, and per-fit CSVs
- After-tasks: `docs/dev-log/after-task/2026-08-16-multinomial-fence-soundness.md`,
  `2026-08-17-categorical-paper-alignment-and-detector.md`;
  reconciles under `docs/dev-log/plan-actual/`

## Next immediate steps (pick ONE; none is owed by this lane)

1. **[#1097](https://github.com/itchyshin/gllvmTMB/issues/1097) — ordinal
   degeneracy detection.** The research question, with five eliminations
   already recorded so you do not repeat them. Highest scientific value.
2. **[#1098](https://github.com/itchyshin/gllvmTMB/issues/1098) — the
   binomial screen's measured 25% false-positive rate.** Well-scoped, user-
   visible, independent of #1097.
3. **[#1099](https://github.com/itchyshin/gllvmTMB/issues/1099) — the
   paper-companion vignette** (AVONET/BirdTree, MCMCglmm comparison). Check
   data licensing before starting.
4. **Something else entirely** — consult the lane-split map; the repo's
   standing queue also holds the VA-vs-Laplace recovery study and Design 66
   power-study scoping.

## Blockers / open questions

- Post-merge CI on `main` (see the ⚠ above) — verify early.
- Whether an ordinal fit-time warning should ever exist. Currently: no,
  because there is nothing to warn about.

## Gotchas / failed approaches — do not repeat these

- **Score a campaign by its FROZEN rule.** This arc's first ordinal verdict
  scored false positives with a per-fit relabelling chosen *after* results,
  moving 57 of 180 healthy fits out of the denominator. Two D-43 reviewers
  caught it. The frozen block defines FP **arm-level**. Filed to the brain's
  `CROSS-REPO-GUARDS`.
- **An all-negative grid is a harness failure until proven otherwise.** A
  0/315 result nearly shipped as "no sensitivity"; it was a field-name typo
  recording `FALSE` everywhere.
- **Do not fence on engine flag names.** The keyword grid folds distinct
  keywords onto shared flags; fence on parsed covstruct intent.
- **`trait_id` in `tmb_data` is 0-based**, while `R/diagnose.R` converts to
  1-based before use. Passing raw ids to `.gllvmTMB_ordinal_cutpoint_span_by_trait()`
  returns all-NA. Not a package bug — a caller convention.
- **Replication rescues correlation railing, not variance collapse.**
  n_rep = 5 fixed the full-rank cell (rails 8/20 → 4/20) and did nothing for
  the diagonal mode (7/20 collapse, identical to baseline).

## How to resume (environment)

- Working directory: the repo root, or a fresh worktree —
  `git worktree add /private/tmp/<name> -b claude/<lane>-<date> origin/main`.
  **Never** create worktrees inside `~/Dropbox/Github Local/`.
- Toolchain: `OPENBLAS_NUM_THREADS=1 Rscript -e 'devtools::test(filter="...")'`;
  heavy cells need `GLLVMTMB_HEAVY_TESTS=1`; `NOT_CRAN=true` for skip_on_cran suites.
- Campaigns: local first with a D-139 timing fit before anything long; >30 min
  needs a pre-run test and Shinichi's approval; **never GitHub Actions** (D-50).
- Safe verification: `OPENBLAS_NUM_THREADS=1 Rscript -e 'devtools::test(filter="sanity|multinomial|ordinal")'`
- Do not stage: other lanes' files, `R/mspl*`, `tests/testthat/test-mspl-*`,
  anything under another worktree.

---

```text
Read AGENTS.md and docs/dev-log/handover/2026-08-17-claude-handover-categorical-arc.md. Run the handover rehydration steps, reconcile them with the current git state, then continue only the OWED Next Immediate Steps.
```
