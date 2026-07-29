# Claude → Claude handover — LANE 1: AGHQ and the evidence surface

**2026-07-29.** You are Claude, picking up the AGHQ / interval-evidence lane. A sibling lane
(LANE 2, `…-LANE2-va-eva.md`) runs VA/EVA in parallel — read its fence before touching shared files.

---

## Mission control

| | |
|---|---|
| **repo / branch** | gllvmTMB · everything below is **MERGED TO `main`** unless marked |
| **shipped** | 4 interval-machinery fixes · AGHQ control wiring · a CRAN-blocking namespace fix · a 432k-fit campaign · a silent-link bug |
| **claim state** | **NO capability claim made. NO certified interval exists.** Point estimates are the supported claim |
| **open PR** | **#810 (`claude/gaussian-link-guard-20260729`) — targeted-verified only, full suite unconfirmed** |
| **compute** | Totoro **idle**. Campaign complete, results LOCAL (D-50) at `~/h4_work/regime.csv` |
| **START HERE** | this doc → `docs/dev-log/2026-07-29-flat-regime-campaign-results.md` |

## Goal for this lane

**The model surface is broad and real, the evidence surface is narrower and honest, and the gap
between them is the roadmap.** Close the gap — do not widen the model surface.

## The three next steps, in priority order

### 1 · Certify ONE interval

gllvmTMB has **zero live certified intervals.** The nearest candidate — Gaussian `Sigma_unit`
**diagonal** profile — was **WITHHELD** by two D-43 panels against 5k-rep, orig-only-seed evidence,
not certified. Against a **0.94** gate (not 0.95): d1-n150 passes (0.9482 / 0.9481); **d2-n150 fails
on rorqual** (0.9462, band 0.9398) and clears on Totoro by +0.0009.

> 🔴 **Addendum, 2026-07-29 (evidence-gap slice A1).** The two WITHHELD panels above are not the
> whole 2026-07-17 record. A later same-day panel pooled these reps with a disjoint fresh-seed
> batch to N≈15k and returned **BOTH cells CERTIFY, 3-0** (d1 0.9477/band 0.9440, d2 0.9461/band
> 0.9424) — `dd80244a:docs/dev-log/2026-07-17-sigma-coverage-d43-panel.md`, where it sat unmerged
> for 12 days. It is **deliberately NOT ported** to `main`: R-5 (2026-07-21) fences that branch
> estate, so its numbers, method and verdict are quoted with provenance in
> `docs/dev-log/2026-07-29-certificate-record-reconciliation.md` instead. That does not make the "certify
> ONE interval" step below unnecessary — the CERTIFY panel's raw is gone (Totoro results emptied),
> so it is not reproducible, and it never reached a public surface. **It does change why the
> confirmatory run below matters: the expected answer is already known, not merely hoped for**, and
> a parallel lane already acted on this the same day — `90798365` ports the harness and
> pre-registers the 20k-rep gate (`docs/dev-log/2026-07-29-certificate-gate-preregistration.md`).
> Check whether that run has launched or completed before re-porting `829c34cd` below.

**The lift is a ~20k-rep top-up, not a fresh campaign.** MCSE is 0.0032 at 5k reps; quadrupling
halves it, moving bands to cov − 0.0032, and both clusters then clear.

🔴 **Correction to carry.** An earlier session claimed today's four fixes made those numbers stale.
**They do not.** `.profile_ci_via_refit()` (`R/profile-derived.R`) uses its own `stats::uniroot`
and never calls `.profile_bounds()` or `TMB::tmbprofile()` — it only *mentions* the former in a
comment. So `e34176eb` / `26ac8301` / `bb4862bb` are all off that path. **The numbers stand.**

**Prerequisite:** the producing scripts are `dev/profile-rescore-run.R` +
`dev/totoro-profile-rescore.sh`, commit **`829c34cd`**, on `claude/release-0.5.0` and
`claude/profile-coverage-remeasure-20260718` — **not ancestors of `main`**. A scoping pass found
all three patches apply with `git apply --check` exit 0. Port them first.

### 2 · Exercise AGHQ beyond three families, or fence it honestly

AGHQ is merged and exported, but **13 of 16 eligible families have never been run under it**.
Dispatch exists; exercise does not. Only gaussian, binomial and poisson have measurements, and
only binomial-logit has non-trivial evidence.

Its eligibility fence is also **much narrower than the family list suggests**: a single ordinary
`latent()` block on the unit tier and nothing else. Any `phylo_*`, `spatial_*`, `animal_*`,
`kernel_*`, a second grouping factor, `REML = TRUE`, `mi()`, or `k = 1` routes back to Laplace.

**Either measure them, or say in the docs that AGHQ is a gaussian/binomial/poisson feature.**
The current surface implies more than the evidence supports.

### 3 · Why does binomial never stall?

**0.0000 in 144,000 fits.** Poisson 0.7401, gaussian 0.8956. That is categorical, not marginal,
and nobody has explained it. Bounded support, logit curvature, and the absence of a free
dispersion parameter are all plausible and all **untested speculation**.

This is the question the campaign *raised*. It likely tells you where quadrature is worth paying
for at all — which makes it worth more than another sweep of the same grid.

## What shipped (all on `main`)

| commit | what |
|---|---|
| `e34176eb` | profile search budget coupled to `level` — `level = 0.99` was losing 4/10 bounds to ±Inf |
| `fde628bf` | coverage harness no longer credits an infinite bound as a cover (`is.na(-Inf)` is `FALSE`) |
| `26ac8301` | asymptotic (±Inf honest) vs truncated (bound unknown → `NA`) terminus separated |
| `bb4862bb` | bounds interpolated on the ζ scale — exact for a quadratic, >10× closer on a coarse grid |
| `3bdf325c` | `aghq = "auto"` now applies its own policy (`.aghq_auto_decide()` had **no call site**); six `aghq_*` controls now accepted instead of silently dropped |
| (in `#802`) | `.onLoad` could not find `stats::AIC` — the installed package **could not load cleanly**. `R CMD check` 1E/3W/2N → 0/0/0 |

All five are **one defect class**: the instrument reporting a definite answer where it had failed
to measure. An infinite bound manufactured, then credited, then asserted, then imprecisely placed.

## Key decisions — do NOT re-litigate

* **The chi-bar-square boundary correction is DEAD.** Its 95% crit is **2.706** vs χ²₁'s **3.841**,
  so it *narrows* intervals and *worsens* under-coverage. Our defect is under-coverage. **χ²₁ at a
  boundary is the conservative choice.** Arithmetic; parameterisation-independent.
* **Boundary detection is unimplementable** on the current path: `tmbprofile()`'s inner refit is
  unconstrained, its convergence status discarded, and log-SD puts SD = 0 at −∞.
* **Reparameterising to fix that will NOT work alone.** `tmbprofile()` hard-codes
  `control <- list(step.min = 0.001)` in its body and does **not** thread `...` into the `nlminb`
  call — so finite bounds still could not reach the inner optimiser. ~3–5 weeks for zero payoff
  without a TMB fork. **Only worth one probe:** can that inner refit be box-constrained at all?
* **We are NOT first.** SAS PROC GLIMMIX `COVTEST … CL / TYPE=PLR` profiles factor-analytic
  `FA(q)`/`FA0(q)`, tracing to Jennrich & Schluchter (1986). Any "first to profile a low-rank
  covariance" wording is false.
* **Multinomial AGHQ deferred** by a pre-registered gate — the stall is a near-flat objective, now
  confirmed at 432k fits. Reopen only if a regime is demonstrated where AGHQ moves materially.
* **(B) chosen for 0.6.0** — recovery-only framing, certificate deferred. NEWS already said
  *"No cell's interval coverage is certified"*; (B) required no retraction.

## Files created / modified this session

`R/profile-ci.R` · `R/coverage-study.R` · `R/confint-inspect.R` · `R/z-confint-gllvmTMB.R` ·
`R/gllvmTMB.R` · `R/fit-multi.R` · `R/aghq-control.R` · `R/aghq-report.R` · `R/imports.R` ·
`NAMESPACE` · `NEWS.md` · `man/{gllvmTMBcontrol,confint_inspect,tmbprofile_wrapper}.Rd` ·
`vignettes/articles/multinomial.Rmd` ·
`tests/testthat/test-{profile-ci-level-budget,profile-bounds-terminus,profile-bounds-zeta,coverage-study-nonfinite,aghq-control-wiring,gaussian-link-guard}.R` ·
`dev/aghq-evidence/23-flat-regime-campaign.R` ·
`docs/dev-log/{2026-07-28-next-arc-sigma-intervals-ULTRAPLAN,2026-07-28-mixedmodels-jl-profile-lead,2026-07-28-S0-codex-review-recovered,2026-07-28-S3-stall-rootcause,2026-07-28-S4b-profile-route-findings,2026-07-29-flat-regime-campaign-results}.md` ·
`docs/dev-log/after-task/2026-07-28-sigma-interval-arc-premise-collapse.md` ·
`docs/dev-log/handover/{2026-07-28-claude-handover-sigma-premise-collapse,2026-07-28-lane-starter-parallel-lanes}.md` · this doc.

## Blockers / open

* **PR #810 is targeted-verified only.** 3/3 on its own tests; the full suite was still running when
  it was pushed, and **gaussian is the most-used family in the suite**. Confirm before merging.
* `test-eva-gate1.R` fails under `R CMD check` — it reads `docs/design/86-*.json`, and
  `.Rbuildignore:18` has `^docs$`. Pre-existing, **LANE 2's file**, real packaging defect.
* A reachable ±Inf bug in **drmTMB** (`R/profile.R:1690-1691`) — one wrapper writes unscrubbed
  infinities where its two siblings scrub. Today's defect class, another repo, ~30 min.

## Gotchas paid for in blood

* **Check the PRIMARY source, not the summary citing it.** `decisions.md:2130-2135` calls the
  Gaussian cell "the one coverage-certified cell"; the after-task record says **WITHHELD**. That
  overstatement was repeated all session before a panel caught it. **This gotcha has a sequel:
  "the after-task record" cited here is one of two same-day 2026-07-17 records, and it is the
  WITHHELD one — the other, a later panel that pooled to N≈15k and returned CERTIFY 3-0, was not
  found in this session either. Checking A primary source is not the same as checking ALL of
  them.** See the addendum above and `docs/dev-log/2026-07-29-certificate-record-reconciliation.md`.
* **An agent's confident `file:line` is not evidence.** Five separate agent claims failed
  verification this session — wrong line numbers, "±Inf for every parameter always" (it is
  level-dependent), "silent bootstrap fallback" (it already warns), "one seeded fixture" (it is a
  500-seed calibration), and a `.onLoad` PR-state disagreement.
* **`devtools::test()` cannot catch namespace defects.** `load_all()` never performs a real
  namespace load: 7,872 tests passed green while the installed package could not load at all.
  **Run `rcmdcheck` before claiming a clean bill.**
* **Never push twice quickly** — GitHub auto-cancels the in-flight run, so no verdict is ever
  reached. Two runs on this lane were cancelled this way.
* `pgrep -f Rscript` reports 0 for healthy R jobs — R runs as `exec/R`.

## How to resume

```bash
cd "/Users/z3437171/Dropbox/Github Local/gllvmTMB"
git worktree add /private/tmp/gllvmtmb-aghq2 -b claude/aghq-evidence-20260730 origin/main
```

One-command resume, from the repo root, in your own authenticated terminal:

```
claude "Rehydrate from docs/dev-log/handover/2026-07-29-claude-handover-LANE1-aghq-and-evidence.md, then start with step 1: port commit 829c34cd's certificate scripts and run the ~20k-rep top-up so d2-n150 clears 0.94 with margin."
```
