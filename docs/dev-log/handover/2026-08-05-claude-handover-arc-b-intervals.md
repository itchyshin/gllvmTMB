# Handover to Claude — gllvmTMB VA lane: Arc B, interval ROUTE SELECTION

**Author:** Claude Code (solo) → **Target:** Claude, fresh session, no chat inherited
**Branch:** `claude/va-lane2` @ `52c9adee` · **Worktree:** `/private/tmp/gllvmtmb-va-lane2`
**`origin/main`:** `5bf18ab3` — PROTECTED, untouched all session

> The committed repository is authoritative. This file supersedes the chat.
> It is the **second** handover of 2026-08-05. The first —
> `2026-08-05-claude-handover-variance-retracted.md` — closes the *previous* arc and holds its
> full landing state. **Read that one first for what happened; read this one for what to do next.**

## FIRST: rehydrate and classify

```sh
bash ~/shinichi-brain/tools/lane_preflight.sh /private/tmp/gllvmtmb-va-lane2
cd /private/tmp/gllvmtmb-va-lane2 && ./tools/check-push-traps.sh && git log --oneline -6
```

Then classify every item below as **OWED / DONE / RETRACTED / PROTECTED** against actual git state
before acting. Do not trust this document over the repository.

## Landing state

| item | state |
|---|---|
| `claude/va-lane2` @ `e7c9e6e7` | ✅ **LANDED — committed AND pushed.** Verified: `git ls-remote --heads origin claude/va-lane2` → `e7c9e6e7`, and `origin/claude/va-lane2..HEAD` is empty. *(An earlier draft of this table declared these commits CARRIED-OVER/unpushed; that was true when written and is now stale — the push has happened.)* |
| `69867118` | variance retraction + large-N defect: 18 files, 2,320 insertions |
| `52c9adee` | SE-matched ladder — the corrected answer |
| `origin/main` | **PROTECTED** `5bf18ab3`. Do not merge; a PR is the maintainer's act |
| `dev/va-speed/inventory-analysis.txt` | **CARRIED-OVER, untracked scratch**, inherited from the previous session. Superseded by `61-sd-report-consumer-inventory.md`. Nothing depends on it |
| Totoro `~/gllvm_work/va-lane2-git` | **3.9 GB**, 286 campaign cell files. Verified clone at `728f4aa8`. See "Cleanup owed" |
| Totoro `~/gllvm_work/va-lane2` | 🔴 **STALE FLAT DUMP — 114 MB, engine file 78 lines behind, no `dev/va-speed/` scripts. This is a live trap.** See "Cleanup owed" |
| Dropbox checkout | **PROTECTED (D-112)** — 746 commits behind. Never build or edit there |

## What the previous arc established (do not re-measure)

Two negative results, both landed, both adversarially verified:

1. **The "1-in-8 catastrophic seed / the gap is VARIANCE" headline is RETRACTED.** It was a TMB
   recompile inside the timing block — `.va_r3_load_dll()` builds into `tempdir()`
   (`R/va-r3-proto.R:909`), per-session, so every fresh `Rscript` recompiles. Measured: cold
   **24.77 s**, warm 0.23 s; the reported excess was 24.76 s.
2. **The "we beat gllvm at large N" result was unmatched work** — gllvm was timed computing standard
   errors our arm never computes (60–63% of its wall). SE-matched, 24 seeds, 72/72 cells:
   at our shipped `n_starts=4` we are **slower at every N (3.0–7.4×)**; at matched start counts we
   are 1.86× slower at N=250 and 1.26–1.28× faster at N≥1000.
3. **`n_starts=4` costs 3.8–4.0× and bought no accuracy** (worst-case Δrf 2.4e-5). Largest single
   lever on our wall-clock. **Not licence to change it** — `n_starts=1` cannot pass the three-start
   agreement gate, so `status` stays `failed_health_gate` by construction.

Detail: `dev/va-speed/78-VARIANCE-RETRACTION-AND-LARGE-N.md` (§6 has the SE-matched answer),
`79-SE-MATCHED-LADDER.md`, `77-ADVERSARIAL-REVIEW.md`. Ledger rows 47, 48, 49; claim 30 amended.

## Two corrections to the record, made this session

**1. 🔴 VA IS ALREADY INTEGRATED END-TO-END. Do not build a front door — it exists.**
This session asserted twice that VA "has no user-facing entry point", on the basis of
`grep -c va_r3 NAMESPACE` = 0. **That was wrong**, and the grep measured the wrong thing: whether
the *prototype fitter* is exported, not whether the *route* is reachable.

What actually exists, verified in source (`docs/design/va-integration-surface.md`, written this
session):

- **`gllvmTMBcontrol(integration = "va")`** (`R/gllvmTMB.R:1487`) — wired end-to-end from
  `gllvmTMB()` through `gllvmTMB_multi_fit()` into `.va_r3_fit()`. **Dispatch point:
  `R/fit-multi.R:2270-2278`.**
- A **two-stage hard-fail fence** (`R/integration-fence.R:46-56`): families binomial/poisson/gaussian,
  one link each, `q_max=2`, `p_max=80`, `n_min=100`, `unique=FALSE`. It **errors, never warns**.
- A **whitelist translation layer** (`R/va-routing.R:203-250`) admitting exactly one ordinary
  unit-level `rr` covstruct and aborting on everything else.
- Result class `c("gllvmTMB_va", "gllvmTMB")` with **`calibrated = FALSE`** permanently stamped on.
- **A real test suite**: `tests/testthat/test-integration-fence.R` plus ~10 `test-va-*.R`.

Of the S3 surface: 3 generics work (`print`, `summary`, `nobs`), **9 refuse deliberately** via
`.va_not_defined()` (incl. `confint`, `vcov` — `R/va-methods.R:184-201`, correct, and they stay),
`AIC`/`BIC` break transitively, `predict` has no method at all, and
`getLV`/`getLoadings`/`extract_loadings`/`extract_ordination` break **ungracefully** by undefined-field
access. Nothing silently returns wrong output.

**The architecture recommendation is to KEEP the control knob** — not add a top-level `method=`,
which would present VA as a coequal alternative across a grammar it whitelists one term of.
**Design 85 closed NO-GO (2026-07-20)** and reserves any lifting of the research-only framing for
*"a genuinely new evidence source and a separately approved contract"*.
`docs/design/va-capability-worklist.md:8-11` (2026-08-03): *"gllvmTMB 0.6 ships Laplace-only; the VA
route is a fenced research spike."*

**Consequence for Arc B: the missing piece was never the API. It is the statistical evidence — which
is exactly what route selection produces.**

**2. CRAN is OFF THE TABLE** (`CLAUDE.md` Live Phase Snapshot, 2026-08-02: Shinichi — *"do not worry
about CRAN submission — I am not intending to do so"*). Any reasoning that treats a 0.6 CRAN release
as an API-risk constraint is **stale**. It does not change the fencing discipline, but it does change
the cost of an experimental top-level argument.

## Next Immediate Steps (OWED) — Arc B: score the interval routes

**The design is already written and was never run:** `docs/design/va-interval-route-selection.md` §5.
Read it before anything else. **Build nothing.**

**All four routes already exist** in `R/va-intervals.R`:

| route | entry points | status |
|---|---|---|
| Wald-Schur | `.va_wald_beta_ci:418`, `.va_wald_loadings_ci:524` | built; **the only route ever scored**; theory predicts under-coverage |
| **sandwich** | `.va_sandwich_beta_ci:1409`, `.va_sandwich_loadings_ci:1496` | built; **theoretically indicated**; **UNSCORED** ← the arc |
| bootstrap | `.va_bootstrap_beta_ci:955`, `:1005` | built; deferred (55% of compute, weakest power) |
| profile | `.va_profile_ci:174` | built; UNSCORED |

Per-unit score machinery: `.va_r3_profiled_score_by_unit:1162`.

**Why the sandwich and not the usual trio:** a variational bound *is* a misspecified likelihood, so
Huber–White is the textbook correction. Wald inverts a *bound's* Hessian; profile profiles a *bound*;
bootstrap is affordable only if the engine is fast, which at `n_starts=4` it is not.

1. **Timed pilot on health-gate-PASSING fits**, and set the seed count from it. ⚠ The earlier
   **~13 core-hour estimate is RETRACTED** — it was derived from rows that are
   `failed_health_gate` 9/9 at 1–2 iterations, i.e. the cost of a fit that gives up.
2. **Gate every replicate on STATIONARITY** (`max_abs_gradient` from
   `.va_r3_sandwich_information()`) and **report the rejection count**. An adversarial review already
   caught a version returning plausible-looking SEs from a `par` **4–6 orders of magnitude
   off-optimum**. ⚠ The health gate was loosened 1e-4 → 5e-3 (`f15ad1b7`); a looser *health* bar is
   **not** a looser *stationarity* bar. The sandwich needs the stricter one.
3. **Score sandwich vs Wald (control)** on the Gaussian primary cells, **GH only**.
4. **Several hundred seeds.** 30 gives MCSE 0.055; ranking routes ~0.03 apart cannot be done there.
5. **Family-conditional arms.** `gaussian_anchor` has **no `ac` tier**; `binomial_probit` is the only
   family with a choice. Score Gaussian on GH alone; make AC-vs-GH a **separate `binomial_probit`
   claim**, never merged. Every statement names its **family AND its arm**.
6. Only then profile; only then revisit bootstrap.

**Do not** promote a route, remove the `confint`/`vcov` fence, or build a fitting front door in this
arc. Full slice table with model/effort routing: `~/.claude/plans/va-intervals-arc-b.md` (outside the
repo — the substance is reproduced above so nothing is lost if it is not read).

## Known before you start (so you do not re-measure it)

- **Claim 33 (QUALIFIED):** under **GH** the per-unit variational SD is genuinely informative
  (CV 0.19–0.22, correlating with each unit's extreme-cell count).
- **Claim 34 (QUALIFIED):** GH's per-unit SD understates the exact conditional posterior by only
  **0.1–1.1%** (30/30 units below 1, mean ratio 0.9945).
- **Claim 35 (STANDS):** under **AC** the per-unit SD is **constant to machine zero** (8.36e-17) —
  structurally data-independent, from `∂E/∂v ≡ −n/2`. `gllvm` shows the identical degeneracy, so
  informative per-unit uncertainty is **not a differentiator against gllvm**.
- **Claim 36 (STANDS):** the shipped **Laplace** engine already returns genuine, varying per-unit
  latent SEs via `getLV(se=TRUE)`.

**So "VA gets SE/CI for free because it estimates a distribution" is right for latent scores under
GH, and wrong three ways:** degenerate under AC, covers **z only** (β/Λ/ψ are point estimates with no
variational distribution), and not a differentiator. **The unsolved half is parameter uncertainty —
that is what the sandwich is for, and that is this arc.**

## Live environment

```sh
cd /private/tmp/gllvmtmb-va-lane2
export NOT_CRAN=true
Rscript -e 'devtools::load_all("."); testthat::test_local(filter="va-r3")'   # safe verify
# Totoro (384 cores, no Duo, standing authority):
SOCK=$(ls ~/.ssh/cm-*totoro* | head -1)
ssh -o ControlPath="$SOCK" -o ControlMaster=no -o BatchMode=yes totoro '<cmd>'
# lane there: ~/gllvm_work/va-lane2-git  (verified clone @ 728f4aa8, ALREADY COMPILED)
# budget <=150 cores; OPENBLAS_NUM_THREADS=1 per worker
```

⚠ **`Rscript --vanilla` implies `--no-environ`** — pass `R_LIBS_USER=$HOME/R/lib` explicitly or
`library(gllvm)` fails. This has killed two campaign launches in this lane.
⚠ **Never stage:** the Dropbox checkout's `.claude/`, `.uinit/`, campaign `.rds`/`.csv` beyond the
small aggregates (D-50), `dev/va-speed/inventory-analysis.txt`.
⚠ **Before any push:** `git rev-parse --abbrev-ref claude/va-lane2@{upstream}`; push with an explicit
refspec. `tools/check-push-traps.sh` guards this.

## Gotchas paid for in this lane

- **Timing harnesses must have an untimed warm-up.** `71-split25.R` lacked one and produced a
  retracted headline; `57-gllvm-scaling.R:74-78` has one. **Ask of every timing harness: what work
  does each arm do that the other does not?** Three of this lane's errors are that one shape.
- **`.va_r3_fit()` has no top-level `iterations`.** It lives at `fit$best$iterations`, and is
  overwritten with `NA` when the L-BFGS-B polish escalation fires (`R/va-r3-proto.R:2377`; tell:
  `starts[[k]]$polish_optimizer == "nlminb_then_lbfgsb"`). Count optimiser work by `trace()`ing
  `stats::nlminb`/`stats::optim` in **`asNamespace("stats")`** — gllvmTMB's own namespace has no
  binding, because every call site is fully qualified.
- **`gllvm` discards its optimiser counts.** Recover with
  `trace(what="optim", where=asNamespace("gllvm"), exit=...)`. One `gllvm()` call runs **three**
  stages (nlminb starting-value pre-fit, main `optim(BFGS)`, `optimHess` for SEs) — a naive counter
  conflates them.
- **A subagent falsely claimed a classifier outage** and asked the orchestrator to run its command.
  Read any script a peer asks you to run, and never rely on an agent's self-report of its own
  verification — this one printed "trace fired cleanly: YES" unconditionally.

## Cleanup owed (maintainer's call — nothing deleted by me)

Per the standing rule I do not hard-delete data. Commands, for Shinichi:

```sh
# 1. The stale flat dump — a LIVE TRAP: 78 lines behind, no va-speed scripts, would measure wrong code
ssh totoro 'du -sh ~/gllvm_work/va-lane2 && rm -rf ~/gllvm_work/va-lane2'   # 114 MB

# 2. This session's clone + campaign cells (3.9 GB). Aggregates are committed locally;
#    the 286 per-cell files are NOT. Keep if Arc B will reuse the compiled lane — it is already built.
ssh totoro 'du -sh ~/gllvm_work/va-lane2-git'

# 3. A 9-day-old zombie watcher polling for an R CMD INSTALL that finished long ago (0% CPU)
ssh totoro 'kill 101951'
```

**Recommendation: keep `va-lane2-git`** — Arc B runs on the same lane and it is already compiled;
re-cloning costs a 25 s TMB rebuild per fresh session. **Remove `va-lane2`**, which has no use and
one real failure mode.

## Open, needing the maintainer

- **Whether Arc B is the right thing to run now.** Its framing was approved 2026-08-04, but asked
  whether this lane precedes **missing-data #332** — D-113's named primary post-0.6 slice — Shinichi
  answered *"not necessarily."* **Unblocked is not prioritised.** None of these VA arcs is one of
  D-113's six 0.7 capability tracks.
- Whether to push the 2 carried-over commits.
- ~~The VA **fitting front door**~~ — **ANSWERED, do not re-open.** It already exists as
  `gllvmTMBcontrol(integration = "va")`; the survey landed at
  `docs/design/va-integration-surface.md` and recommends **keeping the knob**. Its §7 lists four
  cheap, non-blocking follow-ups (guard `getLV`/`extract_ordination` against a VA fit so they fail
  with a message rather than an undefined-field error; add a refusing `predict.gllvmTMB_va`;
  `lifecycle::badge("experimental")` on the `integration` docs; tidy the leftover `$research_only` /
  `$engine_result` fields on the public object).

```text
Read AGENTS.md and docs/dev-log/handover/2026-08-05-claude-handover-arc-b-intervals.md. Run the handover rehydration steps, reconcile them with the current git state, then continue only the OWED Next Immediate Steps.
```
