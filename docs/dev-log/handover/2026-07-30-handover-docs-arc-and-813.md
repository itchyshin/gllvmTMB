# Handover — the documentation-honesty arc is CLOSED; #813 is instrumented, not implemented

Written 2026-07-30 for a fresh lane (Claude or Codex). Base: `origin/main` @ `ae650765`.

**This file is on `main`.** Read it directly; nothing here lives only on a branch. (A previous
starter pointed at a path that existed only on its own branch, and the next session hit "file
does not exist." Don't repeat that.)

---

## 1 · Copy-paste opener

```
You are opening a lane on gllvmTMB after the documentation-honesty arc of 2026-07-28/29.

FIRST read docs/dev-log/handover/2026-07-30-handover-docs-arc-and-813.md IN FULL (it is on
main). §4 is the job; §6 is the discipline list; §5 says what is deliberately NOT done.

THE JOB, pick one:
  (A) #813 — profile intervals for communality. Diagnosed, NOT implemented. Step 1 is
      INSTRUMENTATION, not a rewrite: emit achieved c2 + convergence status per grid point.
      Read the issue's own comment thread first, then dev/profile-communality-diagnostic.R.
  (B) The axis-3 behavioural-accuracy doc review. Needs Shinichi in the loop; do not batch it.

DO NOT re-attempt (settled, with evidence):
  * chi-bar-square boundary correction — points the WRONG way (2.706 vs 3.841). Dead.
  * boundary detection under log-SD — unimplementable on the current path.
  * any claim a coverage certificate exists — the disposition is WITHHELD. decisions.md:2130-2135
    OVERSTATES it; read the after-task record, not the summary citing it.
  * "first to profile a low-rank covariance" — SAS PROC GLIMMIX COVTEST TYPE=PLR predates us
    (Jennrich & Schluchter 1986).
  * the overclaim-vocabulary and executable-honesty sweeps of articles / man pages / README /
    NEWS — all four surfaces are DONE and clean. See §2. Re-running them wastes a day.

DISCIPLINE — every item below cost real time in the last arc. §6 has the detail.
  * Check the PRIMARY source, never the summary citing it.
  * An agent's confident file:line is NOT evidence. Open the file.
  * A guard test that finds nothing is indistinguishable from a clean surface. MAKE IT FAIL
    FIRST. Five guards passed vacuously in this arc before being made to fail.
  * NEVER \b in grep -E on macOS (BSD grep ignores it, returns ZERO). Also avoid .{N} lookbehind
    patterns and awk ranges over multi-line fields — both silently under-report. Cross-check
    every zero a second way.
  * The CLAUDE.md loaded into your session context may be OLDER than origin/main's. Verify lane
    fences against the repo, not the injected snapshot.
  * No coverage claim, anywhere, on any surface.
  * Totoro cap 150 cores; local cap 6-8 (Codex shares the laptop).
  * Verify R jobs with `ps aux | grep exec/R`, NEVER `pgrep -f Rscript` (reports 0 for healthy jobs).
  * Local devtools::test() / rcmdcheck before pushing — not CI-first. Never `git add -A`.
  * Run tools/lane_preflight.sh . at orient AND before claiming a lane.

FIRST ACTION: open docs/dev-log/capability-surface.html and show it to Shinichi (CLAUDE.md
step 0), then read the handover.
```

---

## 2 · What is DONE — do not redo any of this

The documentation surface has been swept on **both automatable axes**. All merged to `main`.

| Surface | Overclaim vocabulary | Executable honesty |
|---|---|---|
| 21 articles | swept; 1 fixed (#803) | 15 candidates → 13 confirmed, 2 refuted; all adjudicated (#805, #814) |
| 138 man pages | swept; **clean** | 1,774 calls / 98 pages; 3 candidates, **all 3 false positives** (#816) |
| `README.md`, `_pkgdown.yml` | swept; clean | — |
| `NEWS.md` | swept; **1 fixed** (#817) | — |

PRs: **#805, #806, #809, #812, #814, #815, #816, #817, #824, #829.**

**Verified package state on merged `main`:**
`R CMD check --as-cran` → **0 errors / 0 warnings / 1 note** (the unavoidable `New submission`);
full `devtools::test()` → **6,454 passed / 773 skipped / 0 failed**;
`pkgdown::build_site()` → **20 articles, exit 0**.

Two regression guards now ship: `tests/testthat/test-article-prescribed-calls.R` (article chunks,
including `eval = FALSE`) and `test-no-deprecated-recommendations.R` (string literals across `R/`).
`test-uncorrelated-bar-support.R` pins the `||` support list to its own guard vectors.

### Findings worth carrying, not just the fixes

* **This surface UNDER-claims more than it over-claims.** Three of eight late findings were the
  package describing itself as *less* capable than it is (rootogram NB1 omitted; a "Wald is not
  implemented" claim that was false; an error message naming four fewer supported keywords than
  its own guard allows). This matches drmTMB's 2026-07-11 audit. Use it as a prior.
* **Doc investigation is a good probe for code defects.** Two code defects surfaced *from*
  reading docs — a drifted `||` support list in `R/brms-sugar.R` and a stale hint in
  `R/diagnose.R`. Both were message text; both are fixed.
* **The reference docs were more accurate than the narrative docs.** `kernel_latent.Rd` had
  `level = "known"` right all along while `api-keyword-grid.Rmd` had `level = "kernel"` wrong.
* **A green pkgdown build proves execution, not truth.** All 20 articles rendered clean both
  before and after every one of the 13 findings. It would not have caught any of them.

---

## 3 · The structural gap that made the arc necessary

Recorded in `docs/dev-log/2026-07-28-article-verification-gap.md`. Still true:

* `.Rbuildignore:29` excludes `^vignettes/articles$` → **`R CMD check` never builds 20 of 21
  reader documents**, `--as-cran` included.
* `.github/workflows/pkgdown.yaml` triggers on `workflow_run` … `branches: [main, master]` →
  the site builds **only after a merge**, never on a PR.
* **27 article chunks are `eval = FALSE`**; **72 of 97 man pages contain `\dontrun{}`** — neither
  is executed by anything, `--run-donttest` included.

No CI change was proposed: the cheap fix is a *static* check, which is what the two guards are.

---

## 4 · #813 — profile intervals for communality: WHAT TO DO

**Status: diagnosed, not implemented.** Issue **#813 is OPEN and must stay open.** The only
artefact is `dev/profile-communality-diagnostic.R` (#824) — a harness, not a route. Nothing is
exported, no public route is wired, no coverage claim is made.

Full findings: the [#813 comment thread](https://github.com/itchyshin/gllvmTMB/issues/813).
Read that and the harness before touching code.

### What the diagnostic established

Ran the existing internal `profile_communality()` (`R/profile-derived-curves.R:542`, unexported)
against a live Gaussian `d = 1` fit with a deliberate loading gradient, so `c2_hat` spans high to low.

1. **The curve is well-behaved.** `delta_deviance` falls to a clean minimum at the MLE and rises
   both sides. #679's baseline fix (anchor to the joint MLE, not the grid minimum) is in place —
   all three curve builders share `.profile_curve_delta_deviance()`.
2. **The bracketing failure is a BOUNDARY effect, not a solver failure.** At `c2_hat = 0.776` the
   profile brackets the lower bound but reaches only **2.53 against a 3.841 critical value**
   before hitting `c2 = 1`. Traits at 0.470 / 0.348 / 0.059 bracket both sides comfortably.
   **The upper bound genuinely does not exist in [0,1] for high `c2_hat`** — that is *correct*
   behaviour for a profile on a bounded parameter, and it is the common case for exactly the
   strongly-loading traits users care most about.
3. **There is no achieved-constraint column.** The returned frame is `target`, `profile_value`,
   `objective`, `delta_deviance`, `estimate`, `conf_level`. `profile_value` is the *requested*
   grid value. So the stated withdrawal reason — *"the penalty-based route could accept loose
   constraints and unconverged refits"* (`R/extractors.R:264`) — **cannot be checked from the
   output at all**, by a user or by a calibration harness.

### The revised plan, in order. Do not skip to step 4.

**Step 1 — INSTRUMENT (start here).** Emit, per grid point: the **achieved** `c2` (not the
requested one) and the constrained refit's **convergence status**. Cheap, solver-agnostic, no
public surface. This converts *"we think the penalty is loose"* into a measurement. **A
calibration campaign cannot honestly report coverage without it, because it cannot discard the
refits that missed their constraint.** This is the step the issue was reordered around.

**Step 2 — MEASURE, then decide.** With step 1 in place, answer: is the penalty actually loose?
The withdrawal assumed yes; nobody has measured it. If it is tight, the exact-constraint rewrite
may be unnecessary — which would be the cheapest possible outcome and is a live possibility.

**Step 3 — Boundary semantics, explicitly.** Finding 2 means a one-sided interval is often the
*honest* answer, not a failure. Decide what to return when the bound does not exist in [0,1]:
`NA` with a reason, an explicit one-sided interval, or a typed condition. Do **not** return a
bare `NA` — that is what the article used to (wrongly) claim already happened.

**Step 4 — Exact constraint solver, only if step 2 shows it is needed.**

**Step 5 — Calibration, and NO coverage claim before it.** n_sim ≥ 2000 for adjudication (~200
is PILOT ONLY, Design 66 §7); fixed truth per cell; report the fit-health denominator, never
complete-case coverage alone. Compute on Totoro/DRAC, results stay LOCAL (D-50). Run a D-43
panel (default NOT-DONE) before any promotion, and record whatever it returns.

### Constraints on any fix

* **Do not revive the penalty route as a silent fallback** when an exact solver fails. Failing
  closed is the point of the current abort.
* `extract_correlations(method = "profile")` shares the abort class
  (`gllvmTMB_nonlinear_profile_withdrawn`) and the same prototype — abort sites are
  `R/extract-correlations.R:413`, `:879`, `R/extractors.R:268`,
  `R/z-confint-gllvmTMB.R:893`. A fix to one probably wants the other; decide deliberately.
* **Prior art:** SAS `PROC GLIMMIX` `COVTEST … CL / TYPE=PLR` on `FA(q)`/`FA0(q)`, tracing to
  Jennrich & Schluchter (1986). Read the primary source. There is no novelty claim to make, but
  there may be a solved constraint formulation to borrow.

### One correction to carry

An earlier after-task record asserted that `extract_communality()` "does not abort" on
`method = "profile"`, citing `R/extractors.R:207,214`. **That was wrong** — it aborts at
**`:268`**, ~50 lines below where the reading stopped. Corrected in #814. If you see the old
claim quoted anywhere, it is retracted.

---

## 5 · Deliberately NOT done, with the decisions attached

* **Axis-3 behavioural accuracy** — prose that describes behaviour *incorrectly* while running
  fine and using no suspicious vocabulary. This is where most of the 13 article findings actually
  lived (`part = "unique"` called "a named numeric vector" when it returns a **list**; rootograms
  credited with two families when they support three). **No parser settles this** — #816 shows
  why. It is the review `CLAUDE.md` names: *"one-by-one … WITH Shinichi (slow, deliberate; not a
  batch rewrite)."* Needs him in the loop.
* **VA/R3 prototype tests on CRAN.** #812's goal "stop CRAN building parked prototypes" is
  delivered for the EVA template but only partly for VA/R3: **8 of 27 `test_that` blocks** in
  `test-va-r3-prototype.R` carry `skip_on_cran()`. Not a correctness problem — `main` checks
  clean. **Maintainer decision 2026-07-29: deferred, "not implemented generally for now." No
  issue filed, by that instruction.** Do not file one without asking.
* **The article guard was NOT shipped against `man/`.** It is wrong there in three distinct ways
  — formula **DSL keywords** (`formals()` is not their contract), **alias resolvers**
  (`.kernel_level_alias()` resolves a kernel tier by its `name`), and a formals default that is a
  **subset** of an `allowed` set validated by `setdiff` rather than `match.arg`. 100%
  false-positive rate. Do not "fix" this by extending it there.
* **Cross-OS.** Everything above is macOS-local. The 3-OS matrix is a pre-release step and was
  not run. `main` being 0/0/1 on one platform is a rung, not the ladder — the CRAN gate defaults
  to NOT READY.

---

## 6 · Discipline, with the cases that earned each line

* **Five guard tests passed vacuously before being made to fail first.** `parse()` returns an
  `expression`, for which `is.call()` is FALSE, so a walker silently descends into nothing;
  `as.list()` on a call yields the empty symbol for missing arguments, which errors on *any*
  evaluation including a predicate written to detect it; `formals()` entries without defaults are
  that same empty symbol. **A static check over a corpus defaults toward finding nothing, and "no
  findings" is indistinguishable from "clean."** Fail-first is mandatory for this class.
* **Three shell patterns silently under-reported**, each reading as clean: `\b` in `grep -E`
  under BSD grep (ignored outright — produced two false "zero findings"); a `.{75}` lookbehind
  (showed 3 of 6 hits); an `awk` range over multi-line `DESCRIPTION` fields (reported MCMCglmm
  undeclared — a plain `grep -c` contradicted it, and it would have been filed as a false
  CRAN-policy defect). **Cross-check every zero a second way.**
* **Twice, reading stopped at the point the expectation was confirmed.** Once generalising a
  two-word polarity check into a five-word claim — the one genuine overclaim on the whole surface
  sat in a word never opened, and another lane found it. Once citing `R/extractors.R:207` when the
  abort was at `:268`. Both corrected in the merged record.
* **The `CLAUDE.md` in session context can be STALE relative to `origin/main`.** A reviewer in
  this arc flagged a Codex lane-fence violation quoting text that exists only in the primary
  checkout's copy on an old branch; `origin/main` had since narrowed that fence. Verify lane
  ownership against the repo.
* **`lane_preflight.sh` silence is weak evidence (D-87).** It reported "no codex lane detected"
  while a Codex lane ran the whole time — in **drmTMB**, a different repo. Right verdict for this
  repo, but the lesson holds: silence is not proof of sole ownership.
* **More than half of a careful audit's candidates did not survive refutation.** Across two
  audits, 22 candidates → 16 confirmed, 6 refuted, including a confident, specific, plausible
  `file:line` in a file **too short to contain that line**. Default a verifier to *refuted*.

---

## 7 · State at handover

`main` @ `ae650765`. **Zero open PRs.** Every session worktree clean, nothing unpushed.
Open threads: **#813** (open by design), the axis-3 review, the deferred VA/R3 gap.

Nothing is half-done and nothing is blocked on the outgoing lane.
