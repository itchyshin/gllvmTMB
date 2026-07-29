# Claude → Claude handover — VGH Phase 2 (the Laplace hand-off)

**2026-07-29.** You are Claude, picking up after **Phase 1 shipped**.

**Supersedes** `2026-07-29-claude-handover-vgh-phase1.md`, which was written
before execution and says "your job is the port". The port is done. That doc is
still worth reading for its **six corrections** and its conventions section —
both still apply.

**⚠ MULTI-LANE.** Several other Claude lanes are live on 2026-07-29. This
handover does **not** rewrite `CLAUDE.md`'s snapshot pointer; check the
lane-split board before claiming any shared file.

---

## State

| | |
|---|---|
| **branch** | `claude/vgh-phase1-20260729`, **pushed**. Based on `claude/vgh-variational-20260729`, which is **18 behind `origin/main`** — rebase before any merge. |
| **plan** | `~/.claude/plans/memoized-growing-sparkle.md`. **Phases 0 and 1 are complete.** |
| **risk** | **LOW** — nothing is reachable. `NAMESPACE` untouched, `grep -c -i vgh NAMESPACE` = 0, and the engine is not wired into `R/approximation-engine.R`. |
| **reports** | `docs/dev-log/after-task/2026-07-29-vgh-phase1-engine.md` · `docs/dev-log/2026-07-29-vgh-report.md` |

## What Phase 1 delivered (do not redo)

`R/va-vgh.R` — internal, `.vgh_*`, no roxygen, bare `stop(..., call. = FALSE)`,
long-format contract mirroring `.va_r3_validate_data()`, `n_trials` support,
fail-closed guards, **SQUAREM acceleration** and a **per-observation** stopping
rule. `tests/testthat/test-vgh-oracle.R` — 27 assertions, fixtures inline.

Verified: gaussian ELBO **= exact marginal log-likelihood to 1.35e-15**; ELBO
monotone on all three families; SQUAREM reaches the same optimum in strictly
fewer sweeps; exact families invariant to `Q`; **27/27 from the INSTALLED
package** with `docs/` unreachable.

Poisson recovery, Phase 0's DGP, 6 seeds, medians: **0.1547 / 0.1047 / 0.0626**
at n = 200/400/800, against `va_r3` GH's 0.1611 / 0.1047 / 0.0749.

## 🔴 Before any Phase 2 code — land PR #819

Phase 0 + Phase 1 are in **PR #819**, open and unmerged, on
`claude/vgh-phase1-20260729`. **Land it before writing Phase 2 code**, or Phase 2
piles onto an already-reviewed PR and the two phases stop being separately
reviewable.

Two preconditions, in order:

1. **Reconcile with `origin/main`** (18 behind). Note the branch is **pushed with
   an open PR**, so a rebase means a force-push over published history — prefer
   merging `main` in unless the maintainer wants otherwise.
2. **Run `rcmdcheck::rcmdcheck(args = "--as-cran")`.** Phase 1 ran only a
   targeted installed-package test (27/27, `docs/` unreachable), which answers
   the specific packaging risk but is not the full check.

**The merge itself is the maintainer's** — `R/va-vgh.R` is package code, and the
repo's merge rule reserves that. Do not self-merge.

Until #819 lands, Phase 2 must branch from `claude/vgh-phase1-20260729`, not from
`main`, or it will not have `R/va-vgh.R`.

## 🔴 Then Phase 2 must settle this FIRST

**Rotational identifiability is unhandled.** `Lambda` in `R/va-vgh.R` is dense
and unconstrained — nothing resolves the rotation. `va_r3` packs it
lower-triangular via `.va_r3_pack_theta_rr()` / `.va_r3_unpack_theta_rr()` /
`.va_r3_rotate_to_lower_triangular()`.

This is not cosmetic for Phase 2: the whole point is to hand `Lambda` to Laplace
as a **starting value**, and that requires mapping into Laplace's convention.
Decide explicitly — adopt the lower-triangular packing (the three helpers above
are directly callable), or canonicalise post-hoc via
`.procrustes_align()` (`R/check-identifiability.R:399`). Do not defer it into
the hand-off code.

## Phase 2 — the hand-off

The deliverable is **speed at zero statistical cost**: run VGH to convergence,
take a few Laplace/AGHQ outer iterations from that point, and report the
**Laplace MLE with Laplace SEs**. Every VA recovery and attenuation concern then
stops applying to the published number.

1. Resolve rotation (above).
2. Initialise `Psi` separately — VGH covers `Sigma = Lambda Lambda'` with **no
   Psi**, while ordinary `latent()` carries `Psi` by default.
3. Wire as start values. Touches `R/fit-multi.R`, which is **SHARED with LANE 1
   — coordinate before editing.**
4. **The deliverable number:** Laplace outer-iteration count and wall time, with
   and without the warm start, on matched data, with the final estimates
   verified identical. **Success: ≥1.5× end-to-end at an identical optimum.**

Then Phase 3 (the degenerate-fit screen) — the argument Design 108 says
survives, and it does not need VA to be a good estimator: 8 of 20 Laplace fits
diverged to a degenerate loading while reporting `convergence = 0` and
`pdHess = TRUE`; 59 of 70 in the 640-cell sweep.

## Outstanding from Phase 1

* **Full `rcmdcheck --as-cran` was NOT run.** A targeted installed-package test
  was run instead (27/27, `docs/` unreachable). Run the full check before merge.
* **Not wired into `R/approximation-engine.R`** — that file hardcodes two
  engines into `match.arg`/`switch`. Reachability needs a regime entry plus
  `.approximation_engine_vgh_fit()`. Deliberately deferred.
* `nbinom2` not admitted (fail-closed); structured tiers and spatial deferred.
* Phase 0 poisson seeds **3 and 8** were bad at every n and were never
  investigated.
* Per the plan's discipline, a **Melissa plan-vs-actual reconcile** was done
  inline in the after-task rather than by a sub-agent. Three deviations are
  recorded there.

## Gotchas paid for in blood

* **The oracle is worth more than inspection.** Phase 1's reshape wrote a
  row-major index into a column-major matrix, silently fitting a scrambled
  dataset with no error and plausible-looking output. Only the gaussian
  exactness check caught it — by returning an ELBO *above* the true
  log-likelihood, which a lower bound cannot do.
* **`devtools::test()` cannot catch packaging defects.** Build the tarball,
  install to a temp lib, and run with
  `env = new.env(parent = asNamespace("gllvmTMB"))` so internals are visible —
  a bare `test_file()` from outside cannot see `.vgh_*`.
* **Never `git add -A`**, and do **not** run `devtools::document()` (LANE 1 owns
  `NAMESPACE`). Both were blocked by permission hooks this session, correctly.
* Background runs get killed around ~10 minutes; split long grids.

## Do not claim

More accurate than Laplace (not measured) · novelty of the mathematics (Ormerod
& Wand 2012 App. A.3; Opper & Archambeau 2009; Hui et al. 2017 probit case —
only the optimisation architecture is ours) · any interval or coverage property
· that this reopens VA as an estimator.

## How to resume

```bash
cd "/Users/z3437171/Dropbox/Github Local/gllvmTMB"
git worktree add /private/tmp/gllvmtmb-vgh-p2 -b claude/vgh-phase2-20260730 origin/claude/vgh-phase1-20260729
```

```
claude "Rehydrate from docs/dev-log/handover/2026-07-29-claude-handover-vgh-phase2.md, then read the six corrections in the phase1 handover. Settle the rotational identifiability question FIRST, then execute Phase 2: VGH warm-start into Laplace, reporting the Laplace MLE. Target >=1.5x end-to-end at an identical optimum."
```
