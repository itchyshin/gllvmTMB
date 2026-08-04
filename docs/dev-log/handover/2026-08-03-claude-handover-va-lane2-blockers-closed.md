# Session Handoff: VA lane 2 — both coverage blockers CLOSED, and the arc's founding premise REFUTED

**Meta:** 2026-08-03 · from Claude Code (solo) · branch `claude/va-lane2` · worktree
`/private/tmp/gllvmtmb-va-lane2` · 24 commits off `origin/main` @ `5bf18ab3`

**Supersedes** `2026-08-03-claude-handover-va-lane2.md` for its Next Immediate Steps 1–6.
Everything else in that file — the accomplishments table, the gotchas, the A_i collapse
status — still stands. Written as a **new file** deliberately: a second session was editing
that one concurrently (see §Lane collision), and editing it under a live writer is the
bleed-through D-88 warns about.

---

## Critical Context

**1. Both coverage blockers are closed, verified end-to-end in the real campaign harness.**
Not "the code changed" — the pilot was re-run at both primary cells:

| | before | after |
|---|---|---|
| VA-Wald healthy yield, n=150 | **0/30** | **28/30 = 0.933** |
| VA-Wald healthy yield, n=400 | **0/30** | **29/30 = 0.967** |
| LA-Profile `V_j` produced | wrong estimand | **30/30**, status `ok` ×30 |
| LA-Profile `V_j` coverage, n=150 | collapsing 0.517 → 0.300 → **0.096** | **0.925** |
| LA-Profile `V_j` coverage, n=400 | " | **0.929** |

(Coverages are descriptive at n=30 seeds, explicitly **not** calibrated estimates.)

**2. The arc's founding premise is refuted. VA is slower than our own Laplace at every
configuration measured, and scales worse.** Complete paired ladder at H=15 — the arm most
favourable to VA:

| N | VA (s) | LA (s) | VA/LA |
|---:|---:|---:|---:|
| 250 | 53.02 | 19.97 | **2.65× slower** |
| 1000 | 319.36 | 74.41 | **4.29× slower** |
| 2500 | 1175.54 | 201.29 | **5.84× slower** |

**VA ~N^1.35, Laplace ~N^1.00.** At the shipped default H=61 it is worse still (8.5–10.2× at
N=250, 13.2–16.4× at N=1000), and the same exponent appears there (VA N^1.27, LA N^0.94), so
**the superlinearity is structural, not a quadrature artifact** — it survives a 4× change in
GH nodes. Full argument and regime caveats: `dev/va-speed/46-VA-VS-LA-VERDICT.md`.

**3. So the coverage campaign's premise is in question, and I did not spend its compute.**
Tiers 1+2 are now technically unblocked but were deliberately NOT launched. If VA is slower
than Laplace at every N, "do VA's intervals cover" is not the next question. **This is the
maintainer's call and it is the first thing the next session should raise.**

**4. Blocker 1's published diagnosis was WRONG, and the correction matters.** The previous
handover said to make the gradient bar relative or N-scaled — the intuitive fix for an
absolute bar on an extensive quantity. Measurement says the safe window *barely moves* with
`n_obs` and if anything tightens (0.0201 → 0.0134 over an 8× n range), so scaling with N
pushes the bar the **wrong way**. The bar was simply ~130–200× too tight at every n.

---

## What Was Accomplished

| # | result | status |
|---|---|---|
| 1 | **Blocker 1 closed.** Health bar recalibrated `1e-4` → `5e-3` against a measurement (`45-gradient-vs-objective-gap.R`), not a guess. Four bare literals → two named constants with distinct jobs. | LANDED `f15ad1b7` |
| 2 | **Blocker 2 closed, both halves.** `.total_variance_spec()` aborts instead of silently scoring `Sigma_tt` as `V_t`; the Step-0 LA formula moved to `unique = TRUE` so psi exists in the tier the estimand reads. | LANDED `2a174fb9` + `86049310` |
| 3 | **OWED step 2 answered** — the paired VA-vs-LA ladder above. | LANDED `33805e86` |
| 4 | **Step-0 re-run** at n=150 and n=400 — the table in §1. | LANDED (logs on Totoro) |
| 5 | After-task report + check-log entry. | LANDED `0bdf52c8`, `a9cdbec0` |

**The correction that mattered most:** my own first negative control was **invalid**, and the
finding I nearly filed from it was an artifact. `44-gradient-tolerance-calibration.R` tried to
force non-convergence with `eval.max=12/iter.max=6`; the truncated fits reached the same
optimum to 6+ decimals because the polish loop and L-BFGS-B fallback rescue them regardless.
It "showed" that converged and truncated gradients overlap, i.e. that no threshold could ever
work. `45-…` replaced the instrument — walk away from a converged `par*`, measure
`max|gradient|` against the objective gap — and the classes separate cleanly at every n.
**Check that a negative control actually failed before believing it.**

## Current Working State

- **Working:** everything above. VA suite **21 files, 1335 passed, 0 failed, 0 errors, 1
  skipped**. Profile suite **523 passed, 0 failed**.
- **In progress:** `43-vala-N2500_s{1,2,3}` (H=61, three seeds) still running on Totoro at
  write time. They cannot change the direction — VA is already 5.84× behind at N=2500 on the
  arm four times cheaper for it. The harness writes right-censored results.
- **Blocked:** nothing technically. The coverage campaign is a **decision**, not a blocker.

## Key Decisions & Rationale

1. **`5e-3`, not `1e-3`, for the health bar.** `1e-3` was tried first and rejected: it left the
   primary cells at 4/4 but took n=50 seed 20260803 (gradients 1.99e-03..4.97e-03, all
   genuinely converged) from 4/4 to **0/4**. `5e-3` admits every converged start observed and
   still sits 2.7× below the smallest gradient ever seen with an objective gap ≥ 1e-6.
2. **The polish target stays at `1e-4`.** It is an effort knob, not a verdict. Polishing past
   the bar is cheap and yields better fits; relaxing it because the *verdict* was
   miscalibrated would silently degrade every fit. A test pins the ordering.
3. **Did not retract ledger claim `f3df8193`** ("VA is 5.8× faster than our own Laplace"). It
   was measured on a cell whose configuration the handover does not record and which I have
   not reproduced. My cells are binomial-probit, T=20, q=2, `unique=FALSE`, `n_starts=1`. The
   honest statement is narrower and still decisive: on the cells the Laplace profiling fleet
   itself measured, VA loses at both H, and loses by more as N grows.
4. **Did not ship a duplicate verdict doc** — see the lane collision below.
5. **Did not push the branch.** Unchanged: maintainer's call.

## Lane collision (D-88) — for the maintainer to rule on

A second Claude Code session committed to this same lane between 18:50 and 19:01:

- `695450d2` — landed the 21 carried-over `dev/va-speed/` paths **and** wrote
  `docs/design/laplace-cost-profile.md`, its own Laplace-cost verdict. I had independently
  written one; theirs is more thorough (it caught a `MakeADFun` double-count I missed), and
  our numbers agree exactly (58.37% / 39.32% at `N250_q2`). I did **not** ship mine — it was
  reshaped into `46-VA-VS-LA-VERDICT.md`, carrying only the non-duplicated VA-vs-LA content.
- `305b6b86` — **rewrote the handover I had rehydrated from**, correcting the warm-start
  mechanism from "helped iteration 1 of 674" to "cut iterations ~40%".
- `2a174fb9` — committed my **uncommitted** `R/profile-derived.R` blocker-2 fix. The message
  describes it accurately, so nothing was lost or corrupted.

Nothing is broken and the two sessions' findings agree. But the task definition was edited
under a running session and one session's working tree was committed by another, which is
bleed-through rather than mere concurrency. Per D-87 I did not revert, amend, or rebase.
**Two sessions independently wrote the same document within the hour** — that is the cost.

## Next Immediate Steps

1. **🔴 Decide whether the coverage campaign still runs.** Both blockers are closed, so Tiers
   1+2 (~75 min at 150 cores) can start today. But §2 undercuts the premise. This is the
   fork; everything else is downstream of it.
2. **Re-measure claim `f3df8193` on its own cell with the paired harness.** Pairing is what
   made these numbers trustworthy, and it is the fair way to retire or confirm the 5.8×.
3. **Collect `43-vala-N2500_s{1,2,3}.rds`** when they land and append to the verdict doc.
4. **Ship `se = FALSE`.** Independent of everything above, the other session's profile makes
   this the arc's best lever: 22–39% of wall time at zero statistical cost, largest on the
   cheap `q=2` fits. See `docs/design/laplace-cost-profile.md`.
5. **Resolve the lane collision** before the next session starts.

## Gotchas

- **`family = "binomial"` requires link `"logit"`.** For probit use
  `family = "binomial_probit"` — a mis-specified VA cell dies instantly with
  `R3 link for family code 1 must be "logit"`. Smoke-test one cell before launching a grid.
- **`unique = TRUE` looks like it routes psi to the W tier** — it emits an auto-suppression
  message about `sigma_eps` and the per-ROW level. It does not. `theta_diag_B` is present and
  `.total_variance_spec(tier = "unit")` returns OK; the suppression is correct because the
  B-tier diagonal now does what `sigma_eps` was doing. `47-psi-tier-probe.R` settles it.
- Under the old `unique = FALSE`, psi **was** being estimated — as `log_sigma_eps`. The bug
  was never a missing parameter; it was a parameter in a tier the estimand formula does not
  read.
- Every gotcha in the superseded handover still applies (`Rscript --vanilla` implies
  `--no-environ`; always include an untimed warm-up; `profile_variational = TRUE` is a loser).

## How to Resume

```sh
bash ~/shinichi-brain/tools/lane_preflight.sh /private/tmp/gllvmtmb-va-lane2
cd /private/tmp/gllvmtmb-va-lane2 && git log --oneline 5bf18ab3..HEAD && git status --porcelain
ssh -o BatchMode=yes totoro 'ls -la ~/gllvm_work/va-lane2/dev/va-speed/43-vala-N2500*'
```

Read in order: this file → `dev/va-speed/46-VA-VS-LA-VERDICT.md` →
`docs/design/laplace-cost-profile.md` → `dev/va-speed/20-CLAIMS-LEDGER.md` (check status
before citing anything).

**Never build from the Dropbox checkout (PROTECTED, D-112)** — it is also on a stale
2026-07-18 branch, 746 commits behind. Totoro lane `~/gllvm_work/va-lane2`, ≤150 cores,
`OPENBLAS_NUM_THREADS=1`, `R_LIBS_USER=$HOME/R/lib`. Results LOCAL (D-50). Nothing promoted:
`default_tier` is still `"gh"`, `R/integration-fence.R` untouched, `confint.gllvmTMB_va` /
`vcov.gllvmTMB_va` still error.
