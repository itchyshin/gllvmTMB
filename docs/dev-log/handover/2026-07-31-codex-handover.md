# Claude → Codex handover — 2026-07-31, the VA-in-0.6 lane (CLOSED, merged to main)

**You are Codex, picking up after a Claude session that closed the variational-engine lane.**
Everything it built is **merged to `main`** (`c5da0903`); its branches and worktrees are deleted.
There is nothing to resume — this hands you **live-toolchain work that Claude could not finish**.

**🔴 MULTI-LANE REPO.** This is one lane of several. `docs/dev-log/handover/2026-07-25-active-lane-split.md`
is authoritative for ownership and names each lane's own handover. **The AGHQ / scale-constants lane
is separately active** and also landed on `main` today (`2026-07-31-aghq-*.md` handovers) — do not
absorb, revert, or claim it. Read the lane map before any repository mutation.

---

## Goals / mission

`gllvmTMB` 0.6 is the package's **first CRAN release** (not 1.0 — issue #772). Settled maintainer
position: **Laplace is the default, AGHQ for accuracy, VA and EVA are OPT-IN.** An opt-in route need
not beat Laplace — it must **work correctly and be honestly fenced**. That framing is why this lane's
pass rule was *"no more than 0.05 worse than ML"* rather than *"better than ML"*.

## What was accomplished (all on `main`)

- **`integration = "va"` is routed.** `gllvmTMB(control = gllvmTMBcontrol(integration = "va"))`
  returns a real `c("gllvmTMB_va","gllvmTMB")` fit instead of aborting. New `R/va-routing.R`
  (translation layer) and `R/va-methods.R` (methods).
- **The admission fence is reachable for the first time.** `gllvmTMB()` previously aborted *before*
  `q`/`p`/`n`/family/link existed, so those limits were implemented and tested but could never fire.
- **Gate 3 ran to completion** — 2,160 datasets × 3 arms = 6,480 fits, on Totoro — and the maintainer
  decided: **estimator JJ, rule R2, fence `q ≤ 2`**.
- **`"eva"` removed from the `integration` enum** (now `c("laplace","va")`).
- **Validation register Section 15** added: `docs/design/35-validation-debt-register.md`, rows
  VA-01…VA-09.
- **PR #869 merged**; branches `claude/va-routing-20260731` and `claude/va-in-06-20260730` deleted.

## Current working state

| | |
|---|---|
| `main` | `c5da0903`, VA routing present, `q_max = 2L` verified |
| this lane's branches/worktrees | **deleted** — nothing to check out |
| test suite on main | **2 FAILURES** (below) — pre-existing, not from this lane |
| `R CMD check` | **NOT RUN** on the merged tree — Claude could not; **this is yours** |
| advertising | none — no NEWS, vignette, or README change (Design 72 §7) |

## 🔴 Next immediate steps — these are LIVE-TOOLCHAIN work, which is why they come to you

**1. Diagnose the two failing tests on `main`.** Claude confirmed both reproduce on a clean
`origin/main` checkout with none of this lane's code, so they arrived with the AGHQ /
scale-aware-start work (#873/#878) — but the *cause* was never diagnosed, only attributed.

- `tests/testthat/test-funcphylo-spatial-recovery.R:54` —
  `Expected isTRUE(fit$fit_health$converged) to be TRUE`, got `FALSE`.
- `tests/testthat/test-plot-visual-snapshots.R:301` — vdiffr snapshot changed
  ("dispatcher correlation ellipse"). Review with
  `testthat::snapshot_review("plot-visual-snapshots/")` and decide **accept vs regression** —
  a changed ellipse is a *plausible* consequence of a changed default start, but plausible is not
  verified.

Both need real fits. Coordinate with the AGHQ lane rather than fixing across the boundary.

**2. Run `R CMD check --as-cran` on merged `main`.** This lane added public surface — a new S3 class,
13 method registrations, a new man page — and **no `--as-cran` run has happened since**. For a
first-CRAN-release branch that gap should not persist.

```bash
NOT_CRAN=true Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'
```

**3. Optional, closes register row VA-09.** Poisson-log is admitted by the fence on the theoretical
ground that its expectation is exact in closed form, but **Gate 3 was Bernoulli only** — there is no
recovery evidence for poisson under `integration = "va"`. A small poisson recovery run would convert
VA-09 from `blocked` to evidenced. Compute belongs on **Totoro**, not GitHub Actions (D-50).

## Key decisions & rationale

- **Estimator JJ, not GH.** Under R2, `va_jj` passes the RMSE criterion in *every* cell (50/50;
  54/54 raw), worst gap 0.0393 against a 0.05 tolerance, and holds the lower `Sigma_B` error in 52 of
  54 cells ignoring Laplace entirely (sign test p = 1.7e-13), across all eleven leave-one-out subsets.
  `va_gh` passes 13/50. **This reversed a pre-registered expectation**, and reversed the lane's own
  2026-07-30 decision entry, which had argued for GH on principled grounds. That entry is left in
  `decisions.md` with a supersession banner — deliberately, as a record of why the gate existed.
- **Fence `q ≤ 2`, not 4.** The scope freeze admitted `q ≤ 4` *conditionally* — "only if Gate 3's
  q = 4 cells pass on their own terms." They did not: every `va_jj` axis-collapse failure sits in the
  single `q = 4, p = 8` corner at 0.26–0.77 against a 0.05 tolerance. Honest consequence: `q ≤ 2` is
  **further** from the 5+ latent factors `decisions.md` A3 names as the motivating regime, not closer.
- **`eval_method` routed per family, not hardcoded.** JJ is defined for the logistic term only;
  poisson-log implements one tier (`gh`) where the expectation is exact. A hardcoded `"jj"` would have
  errored on every poisson fit.
- **Class excludes `gllvmTMB_multi`** — Design 85 §10 forbids it, and `nobs.gllvmTMB_multi` would
  silently return `0L` on this object.

## Files created / modified (this lane, all merged in `c5da0903`)

New: `R/va-routing.R` · `R/va-methods.R` · `man/gllvmTMB_va-methods.Rd` ·
`tests/testthat/test-va-routing-oracle.R` ·
`docs/dev-log/2026-07-31-gate3-result-corrected.md` ·
`docs/dev-log/2026-07-31-gate3-totoro-migration.md` ·
`docs/dev-log/after-task/2026-07-31-va-integration-routing.md` ·
`docs/dev-log/handover/2026-07-31-claude-handover-va-lane.md`

Modified: `R/gllvmTMB.R` · `R/fit-multi.R` · `R/integration-fence.R` · `NAMESPACE` ·
`man/gllvmTMBcontrol.Rd` · `tests/testthat/test-integration-fence.R` ·
`docs/design/35-validation-debt-register.md` (new Section 15) · `docs/dev-log/decisions.md` ·
`CLAUDE.md` · `dev/va-gate3/{analyse-gate3.R, run-gate3.R}` · `dev/va-gate3/results/*.csv`

Full diff: `git diff --name-only c5da0903^1 c5da0903` (95 paths, includes the AGHQ lane's merge).
This handover adds: this file + the `CLAUDE.md` snapshot edit.

## Blockers / open questions

1. **The two failing tests** — attributed, not diagnosed. Item 1 above.
2. **`R CMD check` never run** on the merged tree. Item 2 above.
3. **Poisson VA is admitted but unmeasured** (register VA-09).
4. **No cross-machine reproducibility evidence** for Gate 3: it was restarted on Totoro
   (Linux/R 4.5.3) after 531 cells on macOS/R 4.6.0. The restart was *clean* — all 2,160 delivered
   cells come from one environment — but whether the verdict reproduces on the Mac is **untested**.
   See `docs/dev-log/2026-07-31-gate3-totoro-migration.md`.

## Gotchas / failed approaches — do not repeat

- **`NOT_CRAN=true` or whole gate files silently skip** and still print a clean pass.
- **`skip_if_not_heavy()` is a second gate.** `tests/testthat/setup.R` keys on
  `GLLVMTMB_HEAVY_TESTS`; either variable unset can make a test skip while reporting green.
- **Verify S3 dispatch under a real `R CMD INSTALL`, not `devtools::load_all()`.**
  `R/aghq-report.R:176-190` records a CRAN-blocking episode where a method looked registered under
  `load_all()`'s export-all shim and was invisible to real `UseMethod()`.
- **Do not cite Gate 3's collapse criterion to rank the two arms.** `any_axis_collapsed` is TRUE
  **zero times in 6,480 rows** for `va_gh` — its degenerate fits are intercepted upstream by a
  variance-domain guard `va_jj` does not have. Different instruments.
- **Read the corrections before quoting any Gate 3 number.** Two reporting passes were wrong — a
  conjunction reported as its RMSE half, then an over-correction denying a conclusion the evidence
  supports — and a 3/3 NOT-DONE panel caught both. The *arithmetic* was never wrong.
- **`gllvm`'s top-level `link=` is a silent no-op** for binomial; use `family = binomial(link=)`.
- **Never `git add -A`.** The primary checkout at `/Users/z3437171/Dropbox/Github Local/gllvmTMB` is
  **another lane's dirty tree** (`claude/profile-coverage-remeasure-20260718`, 2 uncommitted files).
  Work in a worktree.
- **Campaign compute goes on Totoro/DRAC, never GitHub Actions** (D-50). The pre-registration wrote
  *"Compute: LOCAL (D-50)"*, which misreads it — D-50 says campaigns run on Totoro/DRAC and *results*
  stay local. That misreading cost ~15 h of laptop time.

## Where the Gate 3 evidence lives

Results are **local** (D-50) — never GitHub artifacts. Three copies:

- `~/gllvmTMB-gate3-2026-07-31/` — durable local copy (`gate3.rds`, cell summary, both verdict
  tables at 108/108 rows, original and corrected)
- `totoro:~/gllvm_work/gate3/` — the full run including all 2,160 per-cell files
- `dev/va-gate3/results/*.csv` on `main` — the durable verdict tables, committed

## How to resume

Start Codex in the repo (it reads `AGENTS.md` natively) and paste:

```
Rehydrate from docs/dev-log/handover/2026-07-31-codex-handover.md + the CLAUDE.md snapshot and
the lane map at docs/dev-log/handover/2026-07-25-active-lane-split.md, then continue with the
Next Immediate Steps.
```

Live environment — Codex runs the toolchain Claude cannot:

```bash
cd "/Users/z3437171/Dropbox/Github Local/gllvmTMB"
git worktree add /private/tmp/gtmb-codex -b codex/<topic>-20260731 origin/main
cd /private/tmp/gtmb-codex
export NOT_CRAN=true
export GLLVMTMB_HEAVY_TESTS=1          # else heavy tests skip and still print green
Rscript --vanilla -e 'devtools::test()'
Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'
```

Team mirror: `.codex/agents/*.toml`. **Rose's audit is mandatory before any public claim**, and a
D-43 panel (three fresh reviewers, default NOT-DONE) before any milestone claim — this lane's own
result was caught 3/3 NOT-DONE on its first pass.

## Routing — what is yours, what is not

**Yours (live toolchain):** the two failing tests, `R CMD check --as-cran`, the optional poisson
recovery run, and any Totoro/DRAC campaign.
**Not yours:** the AGHQ / scale-constants lane's own arc (coordinate, do not absorb); promoting any
VA claim to NEWS/vignette/README — that needs the maintainer, and Design 72 §7 requires register
evidence first (Section 15 now carries it, but the promotion decision is his).

## Mission control

| repo | branch / CI | what shipped | plan by leverage |
|---|---|---|---|
| gllvmTMB | `main` @ `c5da0903` · **2 tests failing** | `integration = "va"` routed; fence reachable; Gate 3 reported (JJ, R2, `q ≤ 2`); `"eva"` removed from the enum; register Section 15 | 1. diagnose the 2 failures · 2. `R CMD check --as-cran` on merged main · 3. poisson VA evidence (VA-09) |

> Related: `docs/dev-log/2026-07-31-gate3-result-corrected.md` (read before citing any number) ·
> `docs/dev-log/2026-07-31-gate3-totoro-migration.md` ·
> `docs/dev-log/after-task/2026-07-31-va-integration-routing.md` ·
> `docs/design/35-validation-debt-register.md` §15 · `docs/design/85-*` §§10-11 (READ-ONLY)
