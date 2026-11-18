# Session Handoff: VA speed settled, two speedups shipped, ordinal crux proven — and four decisions taken

**Meta:** 2026-08-04 · Claude Code (solo) → Claude · fresh context required
**Branch:** `claude/va-lane2` @ `7c075fab` — **PUSHED** to `origin` this session
**Worktree:** `/private/tmp/gllvmtmb-va-lane2` · 47 commits off `origin/main` @ `5bf18ab3`
**`origin/main` at write:** `5bf18ab3` (untouched)

> **Supersedes** `2026-08-04-claude-handover-va-speed-and-ordinal-crux.md` (written hours
> earlier, before the four decisions below). That file's technical content stands; this one
> carries the decisions and the landing state.

---

## 🔴 THE FOUR DECISIONS SHINICHI TOOK — this is what changed

| # | question | decision | status |
|---|---|---|---|
| 1 | Push `claude/va-lane2`? | **YES** | ✅ **DONE** — pushed `7c075fab`, `origin/main` untouched |
| 2 | Issue #934's route-selection framing | **OK — approved** | ✅ unblocked; compute may be spent |
| 3 | Lazy `sdreport()` (public API addition) | **OK — approved** | ✅ unblocked; **build it** |
| 4 | The D-88 lane collision | **RESOLVE** | ✅ **RESOLVED** — see below |

**Decision 4, resolved and evidenced.** A second Claude session committed twice from this
session's working tree (`2a174fb9`; `7f47717a` + `136608a7`) plus three docs commits
(`695450d2`, `305b6b86`, `8cd70a32`). Verified with `git merge-base --is-ancestor`: **all six
are CONTAINED in the pushed branch.** There is one lineage, nothing forked, nothing lost, and it
is now on `origin` where a second session can no longer commit into an invisible local tree.
The collision is closed. **The standing rule that produced it remains**: separate lanes by
subject, run `lane_preflight.sh` before claiming one.

⚠️ **A push trap was found and avoided — carry this forward.** `claude/va-lane2` **tracks
`origin/main`**, not a branch of its own name. A bare `git push` would have put 47 commits
straight onto `main`. It was pushed with an explicit refspec
(`git push origin claude/va-lane2:refs/heads/claude/va-lane2`). **Always check
`git rev-parse --abbrev-ref <branch>@{upstream}` before pushing in this repo.**

---

## Critical Context

**1. One claim was RETRACTED mid-session — do not resurrect it.** I reported *"VA is slower than
Laplace at every N"*. Wrong: the ladder ran `eval_method="auto"` (→ **`gh`**) with
`collapse=FALSE`, while `f3df8193`'s 5.8× was **`ac` + `collapse=TRUE`** — a different
estimator. Retracted in `56dfd5f0` (ledger row 46 + process lesson 3, banners on four
surfaces). The harness now **requests its arm and ABORTS on mismatch** (`658c5a15`), proven by a
negative control.

**2. VA vs Laplace — crossovers MEASURED, not extrapolated:**

| N | vs LA **with** SEs | vs LA **without** SEs (algorithm only) |
|---:|---:|---:|
| 250 | 6.72× | 4.59× |
| 1000 | 4.02× | 2.51× |
| 2500 | 1.67× | **1.11×** |
| 5000 | **0.97–1.17×** | — |

Algorithm parity **N≈2500**; with LA's SEs, parity **N≈5000**. **A third of the N=250 advantage
is LA computing SEs that VA cannot produce at all.** Never quote a multiplier without its N and
without saying whether SEs are on both sides.

**3. Three engines, three exponents:** our Laplace **N^0.97** · our VA **N^1.58** · **gllvm's VA
N^2.16**. VA's superlinearity is **intrinsic to the approach, not our defect** — and we are the
flatter of the two VA implementations (0.94× → 2.72× → 3.55× vs gllvm across N=250/1000/2500).
The A_i collapse buys this; without it AC alone is 3.7× *slower* than gllvm.

**4. Ordinal-probit AC is NOT built.** Only its crux is. See "What was NOT done".

## What Was Accomplished

| # | result | commit |
|---|---|---|
| 1 | **Coverage blocker 1 CLOSED** — health bar recalibrated 1e-4 → 5e-3 against measurement. VA-Wald yield **0/30 → 28/30** (n=150), **29/30** (n=400) | `f15ad1b7` |
| 2 | **Coverage blocker 2 CLOSED, both halves** — `.total_variance_spec()` aborts rather than scoring `Sigma_tt` as `V_t`; Step-0 LA formula → `unique=TRUE`. LA-Profile `V_j` **30/30**, coverage **0.925/0.929** (was 0.096) | `2a174fb9`, `86049310` |
| 3 | **Two speedups SHIPPED, BIT-EXACT** (`all.equal(tol=0)`, 0 cells differing): `bootstrap_Sigma()` **1.26×**, `bootstrap_ci_lv_effects()` **1.21×** | `e729a5be`, `7f47717a` |
| 4 | **The profiling heuristic** — glmmTMB's unshipped FIXME, both arms measured | `98d73e2a` |
| 5 | **Ordinal crux + `he()` gate PASSES**, clamp proven necessary by control | `05ded537`, `4a8c8827` |
| 6 | **gllvm scaling comparison** | `8e25f518` |
| 7 | Two source-map scouts + engine knob audit | `6462fb61`, `35f16118` |

**Full package suite: 366 files, 8,963 passed, 0 failed, 0 errors.**

## Current Working State

- **Working:** everything above. Tree **clean**. Branch **pushed**.
- **In progress:** nothing.
- **Blocked:** nothing — decisions 2 and 3 unblocked the two items that were.

## What was NOT done — the honest reason

**Ordinal-probit AC (Item 1B) is NOT coded.** No family code 5, no `DATA_IVECTOR`s, no cutpoint
`PARAMETER_VECTOR`, no R wiring. `va_r3_log_pnorm_diff` / `va_r3_log1mexp` are **dead code called
by nothing**. What IS true: the numerically dangerous primitive is implemented, accurate to
**4.0e-08 / 4.9e-07** against the derivation, and **Hessian-safe by measurement**. The lane opened
on ordinal, was redirected to speed, and returned to the crux only at the end. The build plan
survives intact in `lanes/mature-va-ordinal/LOOP/ultra-plan.md`.

## Key Decisions & Rationale

1. **The clamp is load-bearing, but the derivation's reasoning was too pessimistic.** §5.7 says a
   1e-300 floor is insufficient; **control A tests exactly that and it does NOT produce a
   non-finite `he()`**. **Control B (clamp removed entirely) DOES fire.** So the guard is
   necessary; the claim about *which* floor suffices is not reproduced. Both recorded — different
   claims, only the first proven.
2. **Five levers CLOSED by measurement — do not re-attempt:** TMBad (**1.76× slower**), supernodal
   (needs TMBad, then fails to link CHOLMOD), custom sparse Cholesky (**TMB core**, unreachable at
   package level — two independent scouts), galamm's AD (forward-mode, behind ours),
   profiling-as-exponent-fix (~7× penalty, constant in N).
3. **Of five refit paths audited, only two qualified for `se = FALSE`.** `coverage_study()` calls
   `confint(refit)`; `check_identifiability()` reads `refit$sd_report`. Batching would have
   silently broken both.
4. **Nothing promoted.** `default_tier` still `"gh"`, integration fence shut, `confint`/`vcov`
   still refuse.

## Files Created / Modified (session diff, `5bf18ab3..7c075fab`)

- `R/va-r3-proto.R` — health bar → two named constants; `framework=`/`supernodal=` pass-through
- `R/profile-derived.R` — `.total_variance_spec()` estimand guard
- `R/bootstrap-sigma.R`, `R/bootstrap-lv-effects.R` — `se = FALSE` on discarded refits
- `inst/tmb/gllvmTMB_va_r3.cpp` — **`va_r3_log1mexp` + `va_r3_log_pnorm_diff`** (the crux)
- `tests/testthat/test-va-r3-prototype.R`, `test-profile-ci-total-variance-export.R` — new gates
- `dev/va-speed/40,43,44,45,47,50,51,52,53,54,55,56,57,58-*` — harnesses, scouts, audit, results
- `docs/design/va-interval-route-selection.md` — **the carry-over note**
- `docs/dev-log/handover/2026-08-04-*.md` (×2), `docs/dev-log/check-log.md`
- `lanes/mature-va-ordinal/LOOP/{GOAL,arcs,checkpoint,ultra-plan}.md`

## Landing State

| Artifact | State |
|---|---|
| `claude/va-lane2` @ `7c075fab`, 47 commits | ✅ **PUSHED** (no PR — fenced research; opening one is the maintainer's act) |
| [gllvmTMB #934](https://github.com/itchyshin/gllvmTMB/issues/934) | filed; **framing APPROVED** |
| [drmTMB #914](https://github.com/itchyshin/drmTMB/issues/914) | filed + follow-up comment |
| Working tree | **clean** |

**Foreign untracked dirs — never stage:** the Dropbox checkout's `.claude/`, `.uinit/`, any
campaign `.rds`/`.csv` (D-50).

## Next Immediate Steps (all OWED, in order)

1. **Build lazy `sdreport()`** — **APPROVED (decision 3)**. Fit fast, SEs on demand: a
   `standard_errors(fit)`-style accessor that populates `sd_report` post hoc. **1.49–1.57× on the
   core LA fit, measured.** Biggest unbanked user-facing win. Public API → roxygen + NEWS + a
   register row; `se = FALSE` already exists as the gate (`R/gllvmTMB.R:1288-1294`,
   `R/fit-multi.R:6082-6084`).
2. **Score the SANDWICH interval route** — **APPROVED (decision 2)**, per issue #934. VA's
   uncertainty is a variational *posterior*, not a sampling distribution, so **Wald under-covers
   by construction** — and Wald is the only route Step-0 ever scored (0.897 / 0.935 vs nominal
   0.95, but 30 seeds, MCSE 0.055 → triage only). The sandwich is built
   (`R/va-intervals.R:1409`, `:1496`) and **never scored**. Requirements: **gate every replicate
   on stationarity** (`max_abs_gradient` from `.va_r3_sandwich_information()`; an adversary caught
   a version returning plausible SEs from a `par` 4–6 orders off-optimum) and report rejections;
   **several hundred seeds**, not 30; score under **both** `eval_method`s (under AC+collapse the
   variational covariance is structurally data-independent, so a GH result does not transfer).
3. **Ordinal Item 1(B)** — the crux is proven; build family code 5 on top. Plan in
   `lanes/mature-va-ordinal/LOOP/ultra-plan.md`. ⚠ Unresolved design question: **AC collapses ψ at
   low `n_trials`, and the binomial remedy was to end on GH — there is no ordinal GH tier to warm
   into.** Settle before or during the build.
4. **Cheap untested levers**, in order: `nlminb(scale=)` (never passed by any engine; also the
   cheap proxy for the conditioning lever) · sdmTMB `multiphase` · `optimHess` polish ·
   `sdreport` knobs · gllvm's `inner.control` (⚠ `tol10` may **move estimates** — not free until
   proven).

## Blockers / Open Questions

- **None blocking.** All four prior decisions are taken.
- Open (not blocking): whether to open a PR for `claude/va-lane2` — maintainer's act.
- D-112 still fences *coverage campaigns as release blockers*; #934 proceeds as **route
  selection**, which decision 2 approved.

## Gotchas — paid for this session

- ⚠️ **`claude/va-lane2` tracks `origin/main`.** A bare `git push` would push to **main**. Always
  `git rev-parse --abbrev-ref <branch>@{upstream}` first; push with an explicit refspec.
- **`/private/tmp` was cleaned mid-session and the worktree vanished.** Commits survived on the
  branch; the uncommitted crux survived **only** because it had been scp'd to Totoro. Luck, not
  design. **Commit at every boundary; prefer a worktree outside `/private/tmp`.**
- **`pkill -f "<pattern>"` matches its own command line** and killed the ssh session. Use
  `pgrep -c -f "[4]3-..."` bracket-splitting.
- **`scp` over a script while processes read it** produced a bogus syntax error elsewhere. Deploy
  before launching, never during.
- **`A && B & C &` backgrounds only `A && B`** — the `cd` applied to one job. Use subshells.
- **TMB's `pnorm` is an atomic with no 2nd-order derivative** → `obj$he()` unavailable for
  anything routing through it. A TMB property, not ours.
- **`Rscript --vanilla` implies `--no-environ`** → `gllvm` in `~/R/lib` invisible. Always pass
  `R_LIBS_USER=$HOME/R/lib` on Totoro.
- **A guard that has never fired is not a guard.** Three test defects this session would each have
  given a green light on an untested path.

## Live environment

```sh
WT=/private/tmp/gllvmtmb-va-lane2     # recreate: git worktree add "$WT" claude/va-lane2
REPO="/Users/z3437171/Dropbox/Github Local/gllvmTMB"   # PROTECTED — never build here (D-112)
export NOT_CRAN=true
# Totoro (compute; results LOCAL per D-50, never GitHub Actions):
ssh -o BatchMode=yes totoro    # lane ~/gllvm_work/va-lane2, <=150 cores
#   OPENBLAS_NUM_THREADS=1  R_LIBS_USER=$HOME/R/lib  GLLVMTMB_LANE_DIR=$HOME/gllvm_work/va-lane2
```

Safe verification: `Rscript -e 'devtools::load_all("."); testthat::test_local(filter="va")'`

## How to Resume

```sh
bash ~/shinichi-brain/tools/lane_preflight.sh /private/tmp/gllvmtmb-va-lane2
cd /private/tmp/gllvmtmb-va-lane2 && git log --oneline 5bf18ab3..HEAD | head -20
```

Read in order: this file → `docs/design/va-interval-route-selection.md` → issue #934 →
`lanes/mature-va-ordinal/LOOP/` → `dev/va-speed/20-CLAIMS-LEDGER.md` (**check status before
citing anything**; row 46 is RETRACTED).

```text
Read AGENTS.md and docs/dev-log/handover/2026-08-04-claude-handover.md. Run the handover rehydration steps, reconcile them with the current git state, then continue only the OWED Next Immediate Steps.
```
