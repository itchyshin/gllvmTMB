# Claude → Claude handover — the evidence/validation lane, and the capstone next

**Date:** 2026-08-02. **Author:** Claude Code (evidence/validation lane).
**Addressed to:** Claude, picking up the evidence lane in `gllvmTMB`.

> ⚠️ **MULTI-LANE REPO — this is not the only handover for today.**
> `docs/dev-log/handover/2026-08-02-claude-handover.md` is the **VA/Design-108 baton** and belongs to a
> different lane. Do not treat either as the whole picture. The authoritative lane map is
> `docs/dev-log/handover/2026-07-25-active-lane-split.md`. Cursor also has a live lane (#890) and
> Codex has spatial-doc lanes. **Read the lane split first.**

---

## Critical context

**The mission changed today.** Shinichi, 2026-08-02: *"do not worry about CRAN submission — I am not
intending to do so."* Everything CRAN-shaped is descoped: 3-OS checks, URL/DESCRIPTION polish,
`cran-comments.md`, submission prep. Issue **#345** ("CRAN readiness + paper") loses its first half.

**What survives is the paper**, and for a methods paper the binding question is *how do you know it is
right?* — which makes this lane's validation work the contribution rather than release hygiene.

**Version on `main` is already `0.6.0`.** Do not repeat this session's error of reading `DESCRIPTION`
from the Dropbox checkout: that checkout sits on `claude/profile-coverage-remeasure-20260718`, **639
commits behind**, and reports 0.5.0. **The Dropbox checkout is not `main`.** Read anything factual
from a fresh worktree off `origin/main`.

---

## What was accomplished

Five PRs merged (#900, #901, #903, #906, plus #907 which belonged to the VA lane and was merged on
Shinichi's "merge where we can"). Two documents were also unblocked for the Cursor lane (#890).

**Built** — an internal held-out cross-validation layer (`R/cv-internal.R`, `R/cv-metrics.R`), a
known-truth CV fixture (`R/data-cv-fixture.R`, `inst/extdata/cv-fixture.rds`), a `dev/` evidence
harness, block-conditional recovery tests, the glmmTMB shipped-corpus comparator, the latent-variable
oracle map (Design 87), and a public article. **No new exports** — deliberate.

**Found — and these matter more than the code:**

1. **The "13/15 cells below 94%" headline is a retired gate.** It measured profile CIs of per-trait
   `psi` (`theta_diag_B`), a **rotation-variant** proxy. PR #364 (2026-05-31) corrected this;
   `psi` is diagnostic-only, never gated (`docs/design/66-capstone-power-study.md:167-176`).
2. **The "exported route covered 0.78" claim was a measurement artifact.** The 2026-07-29 campaign
   ran `bootstrap_Sigma()` at **`n_boot = 10`** against a default of 200. A percentile interval from
   B draws cannot cover more than `(B−1)/(B+1)` = **0.818** at B=10. Holding draws fixed and varying
   only B: **0.8073 (B=10) → 0.9418 (B=200)**, against 0.9491 for the profile route.
3. **The "certified but unreachable" caveat is stale** — `f04c066c` exported
   `profile_ci_total_variance()`.
4. **The cross-trait covariance ΛΛᵀ bought nothing** on the CV fixture, because the DGP has no
   species term and ~8 near-exact replicates sit in training for every held-out cell.

**Both stale claims are now corrected** in register row CI-08 and the certificate disposition, as
dated addenda with the superseded text retained verbatim.

**`R CMD check --as-cran`** at `fdefbb91`: **0 errors, 0 warnings, 2 notes** — `New submission`
(unavoidable) and `lanes` at top level (fixed in #908, unmerged).

---

## Current working state

**Landed on `origin/main` @ `773b1ffa`.** No worktrees of this lane remain; all four were removed.

**CARRIED-OVER — unmerged:**

| item | branch | state | resume |
|---|---|---|---|
| **#908** `.Rbuildignore` `^lanes$` | `claude/ascran-lanes-ignore-20260802` | pushed, CI was pending | `gh pr checks 908` → merge if green |
| **#890** Cursor missing-data ledger | `cursor/missing-data-ledger-336-20260801` | **conflicts resolved by this lane and pushed**; CI re-running | **not yours to merge** — Cursor owns it |
| **#909** | (VA lane) | not this lane's | leave alone |

**PROTECTED — do not touch, do not stage (D-112):** the Dropbox checkout
`/Users/z3437171/Dropbox/Github Local/gllvmTMB` is intentionally dirty on
`claude/profile-coverage-remeasure-20260718` with 5 uncommitted paths (`capability-surface.html`,
a handover doc, `.claude/`, `.uinit/`, a Tier-2 handover). **Never `git add -A` there.**

---

## Key decisions & rationale

- **Internal-only, no exports.** Avoids AGENTS.md's six-item Definition of Done and a
  validation-debt register row; the register gates on *advertised* capability.
- **Cell-wise CV folds only.** `predict()` returns the predictor at empirical-Bayes **modes**, so
  site-wise folds are **not** marginal prediction, and integrating `rr_B` alone would not fix it
  (η also carries `s_B`, `p_phy`, `Lambda_W`, `Lambda_spde`, `Lambda_phy`). Marginalisation deferred.
- **`bootstrap_Sigma()` warns rather than aborts** below the arithmetic floor, and returns
  `$coverage_ceiling`. Aborting would break six test files that legitimately use small `n_boot`; and
  **the thing that failed was a script**, which can swallow a warning but can assert on a field.
- **Attrition floor not promoted to NA-ing** — that would change returned values on an exported
  function during a release push. Deferred to 0.7 as a known residual.
- **AGENTS.md/CLAUDE.md register-code conflict reconciled** — register IDs in internal artifacts;
  reader-facing surfaces state boundaries in plain language.

---

## Files created / modified (this lane, all on `origin/main` unless noted)

```
R/cv-internal.R                        R/cv-metrics.R                    (new)
R/data-cv-fixture.R                    data-raw/cv-fixture.R             (new)
inst/extdata/cv-fixture.rds            dev/cv-evidence.R                 (new)
dev/boot-vs-profile-diagnosis.R                                          (new)
R/bootstrap-sigma.R                    man/bootstrap_Sigma.Rd            (modified)
tests/testthat/test-cv-internal.R                                        (new)
tests/testthat/test-block-conditional-recovery.R                         (new)
tests/testthat/test-crosspkg-glmmTMB-corpus.R                            (new)
tests/testthat/test-bootstrap-Sigma.R                                    (modified)
docs/design/87-latent-variable-oracle-map.md                             (new)
docs/design/05-testing-strategy.md     docs/design/35-validation-debt-register.md  (modified)
docs/dev-log/2026-07-29-certificate-disposition.md                       (modified)
docs/dev-log/audits/2026-07-29-jason-hmsc-cross-package-scout.md         (new)
docs/dev-log/audits/2026-08-02-ci08-coverage-explained.md                (new)
docs/dev-log/after-task/2026-08-02-cv-evidence-layer.md                  (new)
vignettes/articles/validation-oracles.Rmd  _pkgdown.yml  AGENTS.md  docs/dev-log/check-log.md
.Rbuildignore                                                  (in #908, UNMERGED)
```

---

## Next immediate steps — OWED

**1. Merge #908** if CI is green. One line; clears the only actionable as-cran note.

**2. THE MAIN TASK — scope the power-study capstone as the paper's evidence chapter.**

Issue **#345** says everything is gated on it, and with CRAN gone it is not a gate but *the
deliverable*. `docs/design/66-capstone-power-study.md` is the spec.

**Do not start compute. This is a planning slice and it needs Shinichi's input on scope.** The
decisions he named: **which cells · how many seeds · which families · the pre-registered gate ·
Totoro vs DRAC.**

**Start by re-reading Design 66 against this session's findings and listing where it is now stale** —
the same move that found the `psi` category error. Known corrections to fold in:

- The estimand question is **settled**: rotation-invariant `Sigma_unit_diag`, not `psi`.
- The profile route is **certified and now exported** (0.9467, scope fences in the disposition doc).
- `bootstrap_Sigma()` is **not broken** — at B ≥ 200 it reaches 0.9418. Do not design the capstone
  around replacing it, and **do not run any campaign at `n_boot < 200`**; assert
  `coverage_ceiling >= conf`.
- Per `docs/design/87-...md`, several cells have **no third-party oracle**; a **hand-written Stan
  reference** is the available route (`rstan` 2.32.7, `cmdstanr` 0.9.0 installed). **`tmbstan` is
  NOT an oracle** — it reuses the TMB objective.

`skills/ultra-plan` suits this. Compute: **Totoro** (384 cores, no queue, `ssh` ControlMaster already
open) for ≤100-core work; **DRAC** for GPU/multi-node/queued arrays. **Never GitHub Actions (D-50);
results stay LOCAL.**

---

## Blockers / open questions for Shinichi

- **Phylogenetic multinomial** (Design 84, partially shipped): no third-party oracle, but buildable
  via Stan. He marked this "good" but no build decision was taken.
- **Capstone scope** — the five decisions above. Blocking.
- **Attrition floor → hard NA** in `bootstrap_Sigma()`: deferred to 0.7, needs his call.
- **Re-measure the bootstrap at `n_boot = 200`** so the record carries a real number rather than a
  corrected caveat. Minutes on Totoro.

---

## Gotchas / failed approaches

- **The Dropbox checkout is 639 commits behind.** It cost this session a set of stale line numbers in
  a plan and a wrong `DESCRIPTION` version. Always work from a fresh worktree off `origin/main`.
- **Three adversarial review rounds each found blocking defects in the previous round's fixes** —
  including a proposed sentinel-invariance test that was **tautological** (`is_y_observed` is derived
  from the NA pattern, so filling cells then NA-ing them yields identical data). The correct
  construction already existed at `test-missing-response-gaussian.R:104`.
- **Every failure in this lane produced confident, plausible, WRONG output rather than a crash** — a
  sentinel-zero truth source, deterministic "family draws" that would have given AUC ≈ 1, an
  over-parameterised fixture, miscounted buckets. None would have been caught by "does it run".
- **Identifiability arithmetic for `latent()` with default Ψ**: `T·d − d(d−1)/2 + T` free vs
  `T(T+1)/2` unique. T=3,d=2 → 8 vs 6 = over-parameterised (converges, Hessian not PD). T=5,d=2 → fine.
  For **single-trial Bernoulli the package maps Ψ off**, so binomial stays identified where gaussian
  does not.
- Backticks in `git commit -m "…"` get shell-substituted and silently eat text. Use `-F -` with a heredoc.
- `rm` inside a compound Bash command trips the permission gate. Split it out.

---

## How to resume

```sh
cd "/Users/z3437171/Dropbox/Github Local/gllvmTMB"
bash ~/shinichi-brain/tools/lane_preflight.sh .        # FOREIGN LANES ARE LIVE
git fetch origin && git log origin/main --oneline -5
gh pr list --state open
# work in a FRESH worktree — never in the Dropbox checkout:
git worktree add /Users/z3437171/local-scratch/worktrees/<name> -b claude/<branch> origin/main
```

Verification in a worktree: `NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1 Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/<file>")'`.
Full suite (~30 min): `devtools::test()` — was **359 files / 8,611 pass / 0 fail** at `fdefbb91`.

**First action:** run lane preflight, compare this document against current git state, and classify
every item above as `OWED`, `DONE`, `RETRACTED`, or `PROTECTED` before doing any work.

---

```text
Read AGENTS.md and docs/dev-log/handover/2026-08-02-claude-handover-evidence-capstone.md. Run the handover rehydration steps, reconcile them with the current git state, then continue only the OWED Next Immediate Steps.
```
