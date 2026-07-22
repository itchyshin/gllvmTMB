# After task — M1 local qualification and the Laplace-only programme reshape

**Date:** 2026-07-21 · **Platform:** Claude Code (sole writer) ·
**Branch:** `codex/gllvmtmb-060-m1-baseline-20260720` · **PR:** #778 (draft)

## 1. Goal

Complete M1 local qualification for a 0.6 release candidate, and reshape the programme
after the maintainer cut EVA from 0.6 to 0.7 mid-arc. M1's purpose is **release truth**:
reconcile what the package claims against what its source actually does, repair only
independently verified defects, and produce evidence that qualifies the exact head.

This report covers local qualification only. **M1 is not closed by this report** —
platform (CI) evidence and three fresh D-43 reviews remain.

## 2. Implemented

**Programme reshape (maintainer decision, 2026-07-21).**

- EVA cut from 0.6 to 0.7; 0.6 ships Laplace-only. M2 CUT, its gates dissolved
  (Design 86 contract, Totoro/DRAC scientific compute, public EVA admission). M3 reduces
  to a source/API freeze plus the version bump.
- `LOOP/GOAL.md` amended **append-only** — the original frozen goal is left intact and
  auditable, with a dated maintainer-amendment block recording exactly which clauses it
  supersedes. `arcs.md`, `ultra-plan.md`, `decision-queue.md` reshaped; cut sections
  retained verbatim rather than deleted, with corrections a 0.7 reader must apply.
- Durable record: `docs/dev-log/2026-07-21-eva-cut-to-0.7.md`.

**Release-truth repairs.**

- `simulate.gllvmTMB_multi()` documented unconditional RE redraw for tiers it does not
  implement. `@param condition_on_RE` now names the eight handled tiers, states that
  `spde` and `phylo_diag` fall back to conditional simulation, and says plainly that
  simulate-based intervals for such fits are **too narrow**. The fallback warning now
  explains why it matters rather than only how to silence it. A stale internal comment
  listing the handled set was corrected.
- `NEWS.md`: recorded the `extract_cross_correlations()` capability reduction (`level` now
  fenced to the ordinary unit tier for **every** method, not just `profile`), and a known
  limitation for phylogenetic slope variance under `binomial(link = "logit")`.
- Test hygiene: the escaping testthat WARNING is now asserted with `expect_warning()`; the
  `.normalise_level()` migration completed (9 call sites, skip removed); both
  `glmmTMB` non-PD guards now declare exactly what coverage is forfeited.
- `.Rbuildignore`: `^LOOP$` added.

## 3a. Decisions and Rejected Alternatives

| Decision | Rejected alternative | Why |
|---|---|---|
| Correct `simulate()` docs; retarget #750 to 0.7 | Import the stranded spatial implementation from parked branches | Would touch the quarantined estate and re-mint M1's source identity, restarting qualification |
| Document the logit slope-variance bias; keep the test skipped | Raise the DGP truth `0.3 -> 0.6` so the test passes | The file's own discipline forbids it; selecting a regime after seeing failures is evidence-shopping |
| Consolidate A6 and A6b into one CRAN-configuration run | Run a provisional check then a CRAN check | A6b's config is strictly harsher, so passing it de-risks A11 *and* yields the CRAN evidence — one run, not two |
| Make the R-2 skip conditionally runnable (`GLLVMTMB_RUN_B2_LOGIT=1`) | Leave the unconditional skip | A declared limitation must be re-measurable, not taken on trust |
| Leave the `glmmTMB` non-PD guards in place, only made explicit | Reseed until the reference converges | Choosing a dataset where the reference happens to converge risks selecting on the outcome |

## 4. Files Touched

`.Rbuildignore` · `LOOP/GOAL.md` · `LOOP/arcs.md` · `LOOP/checkpoint.md` ·
`LOOP/decision-queue.md` · `LOOP/ultra-plan.md` · `NEWS.md` · `R/methods-gllvmTMB.R` ·
`man/simulate.gllvmTMB_multi.Rd` · `tests/testthat/test-phylo-unique-slope-binomial-logit.R` ·
`tests/testthat/test-plot-visual-snapshots.R` · `tests/testthat/test-sigma-rename.R` ·
`tests/testthat/test-stage2-rr-diag.R` · `tests/testthat/test-stage3-propto-equalto.R` ·
**new:** `docs/dev-log/2026-07-21-eva-cut-to-0.7.md`,
`docs/dev-log/known-residuals-register.md`, this report.

No `src/`, `DESCRIPTION`, or `NAMESPACE` changes. `devtools::document()` regenerated
exactly one Rd topic.

## 5. Checks Run

| Check | Result |
|---|---|
| Complete non-heavy suite (pre-edit) | `FAIL 0 \| WARN 1 \| SKIP 780 \| PASS 7274` |
| **Complete non-heavy suite (post-edit, A1r)** | **`FAIL 0 \| WARN 0 \| SKIP 779 \| PASS 7287`** |
| Touched heavy routes (A3) | `FAIL 0 \| WARN 0 \| SKIP 0 \| PASS 173`, 1186.7s, heavy-skip count **0** |
| Four article renders + string oracle | all four built to `pkgdown-site/articles/`; ordinal refusal text present in evaluated HTML |
| Tarball manifest | `LOOP` = 0 entries; internal dirs = 0 |
| **CRAN-configuration check (A6b)** | **`0 errors, 0 warnings, 1 note`** — note is `New submission` |
| — PDF manual | `checking PDF version of manual ... OK` |
| — incoming feasibility | ran (the retained runner disables it) |
| — top-level files | `OK` |

`A6b` config: `remote = TRUE, incoming = TRUE, force_suggests = TRUE, manual = TRUE,
NOT_CRAN = "false"`.

## 6. Tests of the Tests

The A1r deltas were **predicted before the run and matched exactly**: WARN 1 → 0 (R-1
asserted), SKIP 780 → 779 (R-3 migrated), PASS 7274 → **7287** (+13 = R-3's 12 assertions
plus R-1's). No unexplained movement across 311 test files — the strongest available
evidence the edits did what was intended and nothing else.

The heavy run carried its own verifier: `GLLVMTMB_HEAVY_TESTS` echoed from **inside** the
R process, an assertion that the heavy-skip string appears **zero** times, and an elapsed
floor — because `skip_if_not_heavy()` fails **open**.

## 7. Roadmap Tick

M1 local qualification complete. M2 **CUT**. M3 reduced to freeze + version bump. M4, M5
unchanged. Four arcs survive; roughly 4–7 agent working days plus maintainer page-review
sessions.

## 7a. Issue Ledger

20 open issues triaged (report only, nothing closed). One release-relevant: **#750**,
resolved by correcting the docs and retargeting to 0.7. **#345** (CRAN umbrella) has
unclear gating and needs a maintainer call. Six issues sit on a stale `v0.2.0` milestone
and want re-milestoning.

## 8. Consistency Audit

- `CLAUDE.md`'s `#750 SHIPPED` claim was checked and is **true on its own branch**
  (`claude/profile-coverage-remeasure-20260718`, which holds the commits). The release
  branch carries neither claim nor code. Consistent; no correction needed.
- Mission Control rewritten and JSON-validated; it previously asserted EVA was a gated
  0.6 candidate, which the cut made false.
- The **0.5.0 → 0.6.0 bump in M3 is a source edit** and will invalidate every M1 platform
  receipt. M1's evidence qualifies a *pre-bump* identity; M5 must budget a second
  exact-tag three-OS cycle. Recorded in `arcs.md` and Mission Control.

## 9. What Did Not Go Smoothly

Five near-misses, all caught by verification, all recorded because each would have been a
confident false pass:

1. **pkgdown reported exit 0 while the artifacts were absent** from the path checked —
   `_pkgdown.yml` sets `destination: pkgdown-site`, not `docs/`.
2. **A focused run reported `FAIL 0` while the assertion under test was silently skipped**
   behind `skip_if_not_heavy()`. Re-run under heavy to get real evidence.
3. **`expect_warning()` in testthat 3e returns the caught condition, not the value.**
   Assigning from it made vdiffr snapshot the warning object instead of the plot.
4. **A code comment read in isolation nearly became a false finding** —
   `bootstrap-sigma.R:276` documents a case being *handled*, not broken.
5. **A limitation was nearly published against code a 357-line rework had replaced.** The
   R-2 evidence predated `6e46a24a` by 14 days; re-measurement was required.

Also: an agent-authored conjecture (that variance-component bias flips sign at low
per-cluster information) was **refuted the same day** against drmTMB's retained
oracle-validated artifacts, and corrected in every place it had been written.

## 10. Known Residuals

Register created at `docs/dev-log/known-residuals-register.md`. R-1, R-3 **resolved**;
R-4 resolved as far as this package can (upstream `glmmTMB` non-convergence remains);
R-2 **signed off as a declared estimator limitation** with the test re-measurable on
demand; **R-6 awaits sign-off** — no structural guard on random-slope identifiability
(recommend deferring the guard to 0.7).

## 11. Team Learning

- A skip is not evidence. `skip_if_not_heavy()` fails open, so a green non-heavy run says
  nothing about the assertions behind it. Verify the gate from inside the process.
- Check which **branch** you are reading. Two "contradictory" documents were both correct
  on their own branches.
- Re-measure before documenting a limitation. Evidence ages faster than prose.
- A declared limitation should be **re-runnable**, not asserted.

## 12. Cross-Product Coverage

**What this arc covers, and what it explicitly does NOT cover.**

| Cross-cutting surface | Covered | **does NOT cover** |
|---|---|---|
| `simulate()` unconditional RE redraw | `rr_B`, `diag_B`, `rr_W`, `diag_W`, `propto`, `lv_B`, `phylo_rr`, `diag_species` — documented accurately | **`spde` and `phylo_diag`**, which fall back to conditional simulation. Simulate-based intervals for those fits (incl. `bootstrap_Sigma()`) are too narrow. Documented, **not fixed** |
| `extract_cross_correlations()` | ordinary unit tier, all methods | **source tiers** (`unit_obs`, `phy`, `spatial`) on any method — now typed-refused, estimand never validated |
| Inference engine | Laplace only | **EVA / variational approximation in any form** — cut to 0.7. No Design 86, no Totoro/DRAC, no public EVA surface |
| Slope-variance recovery | Gaussian (27/27 under heavy) | **binomial-logit phylo slope variance** — upward-biased, test skipped by default, re-measurable via `GLLVMTMB_RUN_B2_LOGIT=1` |
| Cross-implementation `glmmTMB` agreement | asserted where the reference converges | **the `rr+diag` and `propto` combined cells on this platform** — the reference returns a non-PD Hessian, so the comparison does not run |
| Random-slope identifiability | tier-name refusal at `unit_obs` | **structural check** that the slope covariate varies within clusters — absent, so an unidentifiable spec at any other tier is not refused (R-6) |
| Package evidence | local: full non-heavy, touched heavy, renders, CRAN-config check | **platform/CI evidence** (exact-SHA Ubuntu, 3-OS, Ubuntu-heavy) and **three fresh D-43 reviews** — both outstanding; M1 is not closed |
| Source identity | the current pre-bump head | **the post-bump `0.6.0` identity** — the M3 version bump invalidates every receipt produced here |

### Cross-repo

Two cross-repo briefs were produced for the drmTMB team, in the vault (not this repo):
the random-slope identifiability precondition, and an adjudication of whether per-cluster
information starvation explains drmTMB's blocked cells. The adjudication found the
proposed sign-flip mechanism **contradicted** by drmTMB's own artifacts, and that its
blocked-cell census is dominated by engineering gates rather than information. The one
novel lead handed over: a **correlated `(1 + x | id)` intercept+slope block under a
non-Gaussian family**, which drmTMB has never measured.
