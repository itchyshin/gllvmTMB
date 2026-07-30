# Session Handoff: the VGH arc is closed — the remaining work is a Heywood gate in `diagnose.R`

Date: 2026-07-29. Author: Claude. Target: Claude (same platform).
Predecessor handover: `2026-07-29-claude-handover-vgh-phase2.md`.

## Critical Context

**The VGH arc is finished and every headline claim in its plan failed. That is the
result, not a shortfall.** What the arc *did* produce is three defects in shipped code,
one of which is still open and is the whole content of this handover.

**Do not restart any VGH performance or screening work.** Both are closed by
measurement, not by opinion:

- **Warm-start speed: impossible, with a bound.** `speedup <= cold_iters/warm_iters`.
  Best iteration reduction observed 20%; 1.5x needs 33.3%; **ceiling is 1.25x even with
  a costless, perfect start.** Measured over ~38 cells, n=120–2000, q=2–6, T=5–15, three
  families, cold fits 0.09s–20.2s. Merged in **#820**.
- **VGH as a degenerate-fit screen: refuted.** The statistic is structurally blind to
  `Lambda` (identical to ten significant figures whether `Lambda` is absent, `~N(0,1)`,
  or x1e6) while the failure *is* a loading explosion. Held out with the band frozen:
  **AUC 0.4986, Youden J = −0.196** — worse than a coin flip. PR **#825**.

## What Was Accomplished

| Phase | Outcome | Landed |
|---|---|---|
| 0–1 | VGH engine, internal, verified 4.7e-15 vs the TMB template | merged #819 |
| 2 | Warm start wired + verified; **speed target proven impossible (1.25x ceiling)** | merged #820 |
| — | `.vgh_fit()` reported the ELBO from the *previous* sweep; fixed + regression test | merged #821 |
| 3 | Screen premise **disproved**; found `check_gllvmTMB()` passes fits off by 5 orders of magnitude | **PR #825 open** |
| 4 | Design: **recommend (c) no new public surface**; fix the existing check | **PR #826 open** |

## THE OPEN WORK — one conjunction in `R/diagnose.R`

`check_gllvmTMB()` is **exported**. Run on a Bernoulli fit whose `Sigma_B` is wrong by
`rel_frob = 156645`:

```
check  : binomial_prevalence_loading
status : PASS
value  : sp12 prevalence=0.617; max_loading=949; relative_loading=6980; saturated_fit=1
```

It computes `relative_loading = 6980` against its own `loading_relative_thresh = 8` —
**872x over the line — and reports PASS.** The entire check returns two WARNs on that
fit: a 0.011 gradient and the generic `rotation_ambiguous` note. **A user is told their
fit is healthy when its covariance is out by five orders of magnitude.**

Cause, `R/diagnose.R:464`:

```r
tab$flag <- tab$extreme_prevalence & (tab$dominant_loading | tab$saturated_fit)
```

`extreme_prevalence` (prevalence >= 0.9 or <= 0.1) is a **required** conjunct. Prevalence
here is 0.617, so the row cannot fire however far the loading runs.

**Why that gate is wrong.** The recorded cause of this failure is **quasi-complete
separation**, which produces a runaway loading at *moderate* marginal prevalence —
separation is a property of the fitted linear predictor, not of the marginal rate.

**The fix in one line:** a sufficiently extreme `relative_loading` must be able to flag
on its own, without `extreme_prevalence`.

## Next Immediate Steps

1. **Reproduce the PASS first.** `dev/vgh/p3-existing-check-evidence.R` (on PR #825) does
   it in one run: seed 3, n=60, p=12, q=2, Bernoulli. Confirm `status = PASS` with
   `relative_loading = 6980` before changing anything. If it does not reproduce, stop and
   re-diagnose.
2. **Loosen the conjunction.** Let a runaway `relative_loading` flag independently. Keep
   the existing behaviour for the extreme-prevalence path so nothing currently flagged
   stops flagging.
3. **FALSE-POSITIVE SWEEP — non-negotiable.** This changes what a shipped exported
   diagnostic tells existing users. Sweep **healthy** fits across families (gaussian,
   poisson, binomial), n, T, q and report the flag rate. **An absolute threshold will not
   transport** — a binomial response has bounded variance so an implied `Sigma_B` of 482
   is absurd, while a gaussian response with genuinely large variance could legitimately
   produce a large norm. A scale-relative criterion is required.
   *This is the exact mistake that killed the VGH screen (its band flagged **100%** of
   healthy gaussian fits). Do not repeat it.*
4. **Use the established vocabulary.** This is a **Heywood case** / improper solution
   (1931 factor analysis) — not a new phenomenon needing a new name.
   [UNVERIFIED, web-sourced: one paper generalises the definition to exponential-family
   latent-variable models, which would license applying it to a GLLVM. Verify before
   citing.]
5. Tests + `rcmdcheck --as-cran` locally, then a PR. **Do not self-merge** — package code.

## Landing State

| Item | State |
|---|---|
| `main` | `d2a2e926`; #819/#820/#821 merged |
| PR #825 | **OPEN** — Phase 3 result + evidence. Docs and `dev/` only, no R/ changes |
| PR #826 | **OPEN** — Phase 4 design, recommends (c). Design doc only |
| `diagnose.R:464` fix | **CARRIED OVER — not started.** Needs step 3's sweep before any PR |
| Totoro campaign | **DROPPED, not deferred.** The hypothesis it would measure is disproved |
| `check_identifiability()` defect | pre-existing, `docs/design/61-capability-status.md:193`, separate lane |
| Dangling citation | `ROADMAP.md` has **no "Discussion Checkpoints" heading** (grep = 0), unfixed since 2026-06-19 (`check-log.md:33270`). Repair or remove |
| Other unpushed branches | `missing-data-sim-impl`, `page-sweep`, `remove-unique-family`, `worktree-agent-*` — **NOT mine**, untouched, not my lanes to land |

## Gotchas & Failed Approaches

- **`devtools::test()` cannot catch packaging defects.** Build the tarball, install to a
  temp lib, run with `env = new.env(parent = asNamespace("gllvmTMB"))`.
- **`.vgh_fit()` takes FLAT args**, not a list: `y, n_trials, X, unit_id, trait_id, N, T,
  q, family, link, gaussian_sd, maxit`. Families are `gaussian_anchor` (not "gaussian"),
  `binomial`, `poisson`. Gaussian needs `link = "identity"` explicitly.
- **`gaussian_anchor` FIXES the residual dispersion** rather than estimating it. Any
  comparison against a package that estimates it is unequal-effort — disclose it.
- **`gllvm::…$params$theta` is NOT the loadings.** It is identification-constrained with
  1.0 on the diagonal; the scale lives in `params$sigma.lv`, and the loadings are
  `theta %*% diag(sigma.lv)`. Omitting it produced a fake "gllvm has a G-error of 5772".
- **`.gllvmTMB_apply_start_from()` skips shape mismatches SILENTLY.** Never believe a
  warm-start number without asserting the start landed.
- **Never compare raw `Lambda`** for pass/fail — rotation-arbitrary by design. Use
  loglik, `G = Lambda Lambda'`, eigenvalues of `G`, or `eta`. Name the scale: Frobenius
  is the square root of the trace, and eigenvalues of `G` are squared singular values.
- **A test can hide a bug by converging too tightly.** The existing gaussian oracle
  compared `f$elbo` against an exact marginal likelihood and still missed the stale-ELBO
  defect, because at `tol = 1e-14` the final increment was below its own 1e-10 tolerance.
  The regression test had to converge *loosely* to see it.
- **Do not tune a threshold on the seeds you evaluate it on.** The VGH screen's reported
  0.727 specificity was a design constant: `mean ± 1 sd` returns a 0.317 flag rate for
  *any* statistic.

## How to Resume

Create the lane. **The `cd` is load-bearing** — `git worktree add` run from `~` fails
with `fatal: not a git repository` (this bit once already):

```
cd "/Users/z3437171/Dropbox/Github Local/gllvmTMB" && git worktree add /private/tmp/gllvmtmb-heywood -b claude/heywood-gate-20260730 origin/main
```

Then start the session **inside the new worktree**, not from `~`:

```
cd /private/tmp/gllvmtmb-heywood && claude "Rehydrate from docs/dev-log/handover/2026-07-29-claude-handover-vgh-heywood-gate.md. Reproduce the check_gllvmTMB() PASS on a degenerate Bernoulli fit FIRST, then fix the R/diagnose.R:464 conjunction so a runaway relative_loading flags without extreme_prevalence. Then run the false-positive sweep across families/n/T/q on healthy fits before opening a PR — an absolute threshold will not transport."
```

Read PR #825's result doc for the evidence, and #826 for why no new public surface.
Do **not** re-open VGH performance or screening work; both are closed by measurement.

## Repo hygiene at handover (2026-07-30)

All six VGH PRs are **merged**: #819 (Phase 1), #820 (Phase 2), #821 (stale ELBO),
#825 (Phase 3), #826 (Phase 4 design), #827 (this handover). `main` at `84bb2c44`.

Cleaned: every VGH worktree and branch removed — `claude/vgh-phase1-20260729`,
`claude/vgh-variational-20260729`, `claude/vgh-phase2-20260730`,
`claude/vgh-elbo-fix-20260729`, `claude/vgh-phase3-screen-20260729`,
`claude/vgh-phase4-design-20260729`, `claude/handover-vgh-20260729`, and the
`/private/tmp/gllvmtmb-vgh*` worktrees. Verified 0 remaining before deletion — each
had no uncommitted changes and no unpushed commits.

**Deliberately NOT touched: `CLAUDE.md`'s Live Phase Snapshot.** It is dated
2026-07-25 and therefore stale, but it is a **multi-lane map**, not a single-arc
pointer — it states "do not assume one active writer" and fences the Codex-owned
lanes. Repointing it at the VGH arc would replace a lane warning with a single-lane
claim and orphan the others; #828 merging from a different lane mid-session confirms
that risk is live. Refreshing it is an adjudication across lanes this session did not
own, so it is **Shinichi's call**, not an agent's. The same decision was taken by the
preceding lane for the same reason.
