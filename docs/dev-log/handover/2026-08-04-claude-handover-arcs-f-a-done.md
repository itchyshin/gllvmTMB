# Session Handoff: arcs F and A landed — and two of this session's own claims retracted

**Meta:** 2026-08-04 · Claude Code (solo) → Claude · fresh context required
**Branch:** `claude/va-lane2` @ `2d75e575` — **NOT pushed this sitting**
**Worktree:** `/private/tmp/gllvmtmb-va-lane2` · 51 commits off `origin/main` @ `5bf18ab3`
**`origin/main` at write:** `5bf18ab3` (untouched)

> **Supersedes** `2026-08-04-claude-handover.md` for lane state. That file's four decisions and
> its technical content stand; this one carries what was executed against them.

---

## What changed

A five-arc programme was approved (plan: `~/.claude/plans/kind-sprouting-cascade.md`).
**Two arcs are done. Three are not started.**

| Arc | State | Commit |
|---|---|---|
| **F** — push-trap guard | ✅ **DONE**, negative-controlled | `9d560616` |
| **A** — lazy `sdreport()` | ✅ **DONE**, bit-exact | `29d7db7e` |
| **D** — cheap speed levers | ⬜ not started (scope shrank — below) | — |
| **B** — sandwich scoring | ⛔ **blocked on a spec defect + a decision** | — |
| **E** — gllvm head-to-head | ⬜ not started | — |
| **C** — ordinal | deferred to a ~45-min probe | — |

## 🔴 Read this before citing anything from this session

**Two claims made *in this session* were retracted by measurement, by me, before shipping.**

**1. An Arc B compute estimate.** I sized the sandwich campaign at "~13 core-hours, ~15 min on
Totoro" from per-fit seconds in `dev/va-speed/43-vala-ac_N*.rds`. Then I read the status column:
**9/9 `failed_health_gate`, `iters` NA/1/2**. Those are the seconds a fit costs when it gives up;
a converged fit runs 159–674 outer iterations. **Do not reuse that estimate.** Arc B must open
with a healthy-fit timing probe. This is the third occurrence of this class in this lane.

**2. An Arc A test that could not fail.** `test-standard-errors.R` originally claimed to prove the
internal-state replay in `standard_errors()` was load-bearing. Measured:

| arm | vs eager truth |
|---|---|
| state moved, no replay, no `par.fixed` | **bit-identical** |
| state moved, no replay, with `par.fixed` | **bit-identical** |
| shipped accessor (replay + `par.fixed`) | **bit-identical** |

Repeated with a 30-element random-effect block: unchanged. **Mechanism:** `sdreport()` reads
`last.par.best`; `obj$fn()` moves `last.par`, not `last.par.best`. Directly corrupting
`last.par.best` **does** change the answer (max abs SE diff **0.20**) — and the replay does **not**
recover from it. The replay is kept as fidelity to the fit-time path. The comment and test now
claim only what was measured.

## 🔴 Arc B is blocked — do not start it without these two answers

**(a) A spec defect.** `docs/design/va-interval-route-selection.md` §5 requires scoring under
**both** `eval_method`s. But `R/va-r3-proto.R:1164-1176` / `:1253-1261`:

| family | code | tiers |
|---|---:|---|
| `gaussian_anchor` | 0 | **`gh` only** |
| `binomial_probit` | 4 | `gh`, `ac` — *the only family with a choice* |

The primary cells (n=150/400) are **Gaussian**, so "both arms" is **impossible there**. Options:
(a) move the DGP to binomial-probit — a materially different cell from the one that produced
0.897/0.935; (b) family-conditional; (c) two separate comparisons. **Ada + Fisher recommend (b).**
Shinichi's call — it changes what the result means.

**(b) Prior art to cite, not re-derive.** The brain sweep surfaced
**Qin, Mizuno, Morrison & Nakagawa 2026 §7.2** (from inside the group): sandwich and
parametric-bootstrap intervals **reverse their ordering** depending on whether the working family
is correctly specified — bootstrap SE 55% of sandwich under a misspecified Poisson, +48% under a
correct NB. Tracked as **CI-17** in `OPEN_QUESTIONS`. **Arc B must state its DGP's specification
status or its ranking is meaningless**, and should tell that lane it exists. Also read
`dr21-gllvm-estimation-engines-distilled` before spending compute.

## 🔴 A priority question that outranks all of it

**D-113 (2026-08-01, accepted):** the 0.7 programme is six tracks, and *"**Sequencing. Primary
post-0.6 slice = missing-data #332.**"* **D-112:** *"more capabilities not coverage tho"*, and
*"ask Shinichi which capability is primary for the 0.7 Gate-0 before ultra-planning it."*

**None of arcs A/B/D/E/F is one of the six tracks.** Arcs A and B are genuinely approved
(decisions 3 and 2) — but approval is not the same as being next in the queue. **Unanswered.**

## Arc D is smaller than the handover implies

- **The "one-liner" AD-framework lever is already CLOSED** — `b4fb920f`, TMBad **1.76× slower**,
  supernodal unreachable. Not on the list.
- **`nlminb(scale=)` is already plumbed** for Laplace/AGHQ: `R/fit-multi.R:5196` whitelists
  `scale` in the `optArgs` pass-through and `:5211` passes it to `nlminb`. **Verified by reading
  the code this session.** It needs a *value*, not infrastructure. VA-R3 has **no** such mechanism
  (`R/va-r3-proto.R:1523-1526`) and needs real threading.
- Remaining genuinely untested: `multiphase`, `optimHess` polish, `sdreport` knobs,
  gllvm `inner.control` (⚠ `tol10` **may move estimates** — not free until proven).
- Cheap recipe proven by `b4fb920f`: one quiet Totoro cell, paired arms, untimed warm-up +
  median of 3.

## Open, recorded, NOT closed

**A confirmed silent-wrong-answer path.** `.gllvmTMB_b_fix_se()` (`R/methods-gllvmTMB.R:209`)
returns `rep(NA_real_, n)` with **no warning** when `sd_report` is NULL, and
`confint(method = "wald")` propagates that to an **all-NA interval, silently**. Confirmed by
runtime probe: `dev/va-speed/60-se-false-consumer-probe.md`. Register row **EXT-35** marks it
OPEN; a separate task was spawned. Most sibling consumers `cli_abort` cleanly — these are the
outliers. `standard_errors()` is now the remedy to point users at.

**Separately:** `vcov.gllvmTMB` **does not exist** (only `vcov.gllvmTMB_va` is in NAMESPACE), yet
roxygen at `R/gllvmTMB.R:295` claims `vcov()` dispatches on `gllvmTMB`. Docs-vs-reality gap, unfixed.

## Landing state

| Artifact | State |
|---|---|
| `claude/va-lane2` @ `2d75e575`, 51 commits | **NOT pushed** — push with an explicit refspec |
| Working tree | clean apart from foreign untracked dirs |
| Full suite | see check-log entry (`docs/dev-log/check-log.md`, 2026-08-04) |
| After-task | `docs/dev-log/after-task/2026-08-04-push-trap-guard-and-lazy-sdreport.md` |

**The push trap is now closed** — `claude/va-lane2` tracks `origin/claude/va-lane2`, not
`origin/main`. `tools/check-push-traps.sh` enforces it repo-wide. Still confirm before pushing:
`git rev-parse --abbrev-ref claude/va-lane2@{upstream}`.

**Foreign untracked dirs — never stage:** the Dropbox checkout's `.claude/`, `.uinit/`, any
campaign `.rds`/`.csv` (D-50).

## Next Immediate Steps

1. **Answer the D-113 priority question** — does this VA lane precede missing-data #332?
2. **Arc D** (~1–1.5 h, no decision needed, no compute conflict) — the four remaining levers.
3. **Arc B** — only after the arm decision. Probe healthy-fit timing FIRST; cite CI-17; gate every
   replicate on `max_abs_gradient` from `.va_r3_sandwich_information()` and **report rejection
   counts beside the estimates**. Reuse the request→verify→abort guard from `658c5a15`.
4. **Arc E** — ledger claim 30; model-matched `unique=FALSE`, ≥10 seeds, interleaved, Totoro;
   speed **and** accuracy **and** ψ. Two prior attempts were retracted for being underpowered.
5. **Arc C probe** (~45 min) — does AC's ψ-bias appear for ordinal, where category count may play
   `n_trials`' role? The shipped Laplace `ordinal_probit` (family_id 14,
   `src/gllvmTMB.cpp:407-408, 843, 2334-2342`) is a ready template *and* ground-truth comparator.

## Live environment

```sh
WT=/private/tmp/gllvmtmb-va-lane2     # recreate: git worktree add "$WT" claude/va-lane2
REPO="/Users/z3437171/Dropbox/Github Local/gllvmTMB"   # PROTECTED — never build here (D-112)
export NOT_CRAN=true
ssh -o BatchMode=yes totoro           # 384 cores, idle, R 4.5.3, gllvmTMB+gllvm installed
#   lane ~/gllvm_work/va-lane2, <=150 cores, OPENBLAS_NUM_THREADS=1 per worker
```

⚠ `/private/tmp` was cleaned mid-session once already and the worktree vanished. **Commit at every
boundary**, or relocate the worktree outside `/private/tmp` first.

Safe verification: `Rscript -e 'devtools::load_all("."); testthat::test_local(filter="standard-errors")'`

## How to Resume

```sh
bash ~/shinichi-brain/tools/lane_preflight.sh /private/tmp/gllvmtmb-va-lane2
cd /private/tmp/gllvmtmb-va-lane2 && ./tools/check-push-traps.sh
git log --oneline 5bf18ab3..HEAD | head -5
```

Read in order: this file → `~/.claude/plans/kind-sprouting-cascade.md` (the approved ultra-plan,
incl. the sweep receipt) → `docs/design/va-interval-route-selection.md` → issue #934 →
`dev/va-speed/20-CLAIMS-LEDGER.md` (**check status before citing anything**; row 46 is RETRACTED).

```text
Read AGENTS.md and docs/dev-log/handover/2026-08-04-claude-handover-arcs-f-a-done.md. Run the
rehydration steps, reconcile with git state, then continue the unstarted arcs in the order given —
but surface the D-113 priority question before spending any Totoro compute.
```
