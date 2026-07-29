# Lane starter — open a PARALLEL gllvmTMB lane, 2026-07-28

For Shinichi or a fresh session that wants to work on gllvmTMB **alongside** the live interval lane
without colliding with it. Copy the opener at the bottom.

---

## 1 · What the LIVE lane owns — do not touch these

**Lane `claude/sigma-intervals-boundary-20260728` → PR #802 (OPEN).** 23 commits, 0 behind main,
full suite 7,872 passed / 0 failed / 0 errors across 329 files.

**FENCED FILES — a parallel lane must not edit any of these:**

```
R/profile-ci.R          R/coverage-study.R      R/gllvmTMB.R
R/fit-multi.R           R/aghq-control.R        R/confint-inspect.R
R/z-confint-gllvmTMB.R  NEWS.md
man/gllvmTMBcontrol.Rd  man/confint_inspect.Rd  man/tmbprofile_wrapper.Rd
tests/testthat/test-profile-ci-level-budget.R
tests/testthat/test-profile-bounds-terminus.R
tests/testthat/test-profile-bounds-zeta.R
tests/testthat/test-coverage-study-nonfinite.R
tests/testthat/test-aghq-control-wiring.R
```

Reading them is fine. Editing them means a merge conflict with an open PR.

**Also in flight, hands off:** a Totoro campaign (`~/h4_work/regime*.csv`, 150 cores). Do not start
another Totoro job above ~150 cores total — the machine is shared and the cap is 150.

## 2 · What that lane established (so a new lane doesn't re-derive it)

* The **chi-bar-square boundary correction points the WRONG WAY** — its 95% crit is 2.706 against
  χ²₁'s 3.841, so it *narrows* intervals and *worsens* under-coverage. **Dead. Do not revive.**
* **Boundary detection is unimplementable** on the current path: `tmbprofile()`'s inner refit is
  unconstrained, its convergence status is discarded, and log-SD puts SD = 0 at −∞.
* **There is NO coverage certificate.** The primary record says `Disposition: WITHHELD`.
  `decisions.md:2130-2135` overstates it — read the after-task record, not the summary citing it.
  🔴 **2026-07-29 addendum:** that after-task record is one of two same-day 2026-07-17 records —
  a later panel pooled to N≈15k and returned CERTIFY 3-0 for both cells against the same 0.94
  gate (`dd80244a:docs/dev-log/2026-07-17-sigma-coverage-d43-panel.md`, quoted with provenance in
  the reconciliation note; deliberately NOT ported to `main` per R-5). "NO
  coverage certificate" overcorrects the same way the overstatement it replaced did; there is no
  LIVE certificate (the CERTIFY panel's raw is gone), but the gate was met once. See
  `docs/dev-log/2026-07-29-certificate-record-reconciliation.md`.
* **We are NOT first** at profiling a low-rank covariance: SAS PROC GLIMMIX
  `COVTEST … CL / TYPE=PLR` on `FA(q)`/`FA0(q)`, tracing to Jennrich & Schluchter (1986).
* **Multinomial is deferred** by a pre-registered gate, since the AGHQ stall was shown to be a
  genuinely near-flat objective (quadrature and DGP-cap explanations both refuted on Totoro).

## 2b · 🔴 Two corrections to what this lane told Shinichi — both verified

**CORRECTION 1 — the certificate numbers are NOT stale.** I told him today's four fixes made
option (A) "a full re-measurement rather than a top-up", and used that as one of three reasons to
recommend (B). **That was wrong.** The certificate route is `.profile_ci_via_refit()`
(`R/profile-derived.R`), which uses its own `stats::uniroot` on a deviance-excess function — it
only *mentions* `.profile_bounds()` in a comment about matching its boundary semantics, and never
calls it, nor `TMB::tmbprofile()`. So none of `e34176eb` (ytol budget, in `tmbprofile_wrapper`),
`26ac8301` (terminus, in `.profile_bounds`) or `bb4862bb` (ζ interpolation, in `.profile_bounds`)
is on that path. `.qchisq_threshold()` *is* used, and was never changed.
**Consequence:** (A) is a **top-up of ~20k reps against still-valid numbers**, materially cheaper
than described. (B) remains defensible on its other two legs — a 0.94-gated claim has already
proven easy to overstate, and the machinery fixes are an honest 0.6.0 story needing no gate — but
one leg of the argument he decided on was false.

**CORRECTION 2 — reparameterising for boundary detection cannot work alone.**
`TMB::tmbprofile()`'s inner refit is `control <- list(step.min = 0.001); nlminb(start, newfn,
newgr, control = control)` — **`control` is hard-coded in the body**, and although the signature
takes `...` it is *not* threaded into that call, and no `lower=`/`upper=` is passed (verified by
reading the installed source). So even with finite parameter bounds the inner profile optimiser
still cannot be told about them. Reparameterisation is **necessary but not sufficient**; it is two
projects (≈3–5 weeks, plus a TMB fork or a hand-written profile loop), not one.
**Consequence:** the MixedModels.jl lead in
`docs/dev-log/2026-07-28-mixedmodels-jl-profile-lead.md` stands as design insight but the
parameterisation route should be **DROPPED** unless someone first establishes that
`tmbprofile`'s inner refit can be box-constrained. That single probe is the only part worth doing.

## 3 · Candidate parallel lanes

Ranked by value-per-risk. All are disjoint from the fenced set above.

### 🥇 A — Documentation honesty-fencing review *(the repo's own named next job)*

`CLAUDE.md` says outright: *"The one thing NOT done — and the next session's job — is the
one-by-one human review of the pkgdown pages and the function docs WITH Shinichi (slow,
deliberate; not a batch rewrite), where the honesty-fencing lands."*

**Scope:** `vignettes/`, `_pkgdown.yml`, `man/*.Rd` **except the three fenced above**, roxygen in
`R/` files outside the fenced set.
**What it does:** find every sentence asserting more than the evidence supports ("validated",
"certified", "calibrated", "coverage", "guarantee", "unbiased"), and every internal code leaked to
a reader surface (`CI-xx`, `D-xx`, `Design NN`, commit shas, panel language). Fence or remove.
**Why now:** it gates the 0.6.0 release and needs *your judgement*, not a batch rewrite — which is
exactly what a human-paced lane is for.

### 🥈 B — Random-slope evidence matrix

**Scope:** `tests/testthat/test-*slope*.R`, `dev/`, plus a design doc.
**What it does:** build the keyword × coupling × evidence matrix. NEWS claims `||` support across
nine keyword families and admits lognormal/Student-t as **fit admission only, no validation
claim** — check whether that boundary is *enforced anywhere in the package* or merely stated in
NEWS. If a user cannot tell from the package itself, that is the finding.

### 🥉 C — Covariance-keyword grid consistency

**Scope:** the parser/registry file(s) and their tests.
**What it does:** reconcile the documented 4×5 grid + kernel quartet against what actually parses;
check the soft-deprecation of `*_unique()` is uniform (same mechanism, same lifecycle stage,
announced at call time); verify the Design-65 claim that `kernel_*` stays phylo-equivalent to
< 1e-6 has a test.

### D — Missing-data behaviour

**Scope:** data-prep code + a new vignette section.
**What it does:** establish what actually happens to NA responses and NA predictors, whether
long-format and `traits(...)` wide-format agree, and whether *anything* documents it for users.
The likely cheapest high-value gap: users are told nothing about NA handling.

> Audits of all four were running when this was written; their output will sharpen the scopes but
> the fences above are already correct.

## 4 · House rules a new lane must honour

* **Own worktree + own branch.** `git worktree add /private/tmp/gllvmtmb-<subject> -b claude/<subject>-20260728 origin/main`
* **Never `git add -A`.** Scoped staging only.
* Run `tools/session_ownership.sh` / `tools/lane_preflight.sh` before claiming a lane.
* Reader-facing surfaces carry **no internal register codes**.
* The package makes **no interval-coverage certification claim** — do not write wording that does.
* Tests ship with implementation; write the failing test first.
* Local `devtools::test()` / `rcmdcheck` before pushing — not CI-first.

## 5 · Copy-paste opener

```
Open a PARALLEL gllvmTMB lane: <A docs-honesty | B random-slopes | C covstruct-grid | D missing-data>.

FIRST read docs/dev-log/handover/2026-07-28-lane-starter-parallel-lanes.md — it lists the files a
live lane (PR #802) owns, which you must not edit, and what that lane already established so you
do not re-derive it.

Set up: git worktree add /private/tmp/gllvmtmb-<subject> -b claude/<subject>-20260728 origin/main

DO NOT re-attempt: the chi-bar-square boundary correction (it points the wrong way, 2.706 vs
3.841); boundary detection (unimplementable under log-SD); any claim that a coverage certificate
exists (disposition is WITHHELD); any "first to profile a low-rank covariance" novelty claim (SAS
GLIMMIX COVTEST TYPE=PLR predates us).

DISCIPLINE: check the PRIMARY source, not the summary citing it — that error cost a full day here.
An agent's confident file:line is not evidence; verify it. No internal register codes on reader
surfaces. No coverage claim. Test-first. Totoro is at 150 cores already — do not exceed the cap.
```
