# Session Handoff: MSPL binary interval arc → the theorem-gated-inference lane

**Date:** 2026-08-16 · **From:** Claude (the Design 118 interval lane) · **To:** Claude (fresh lane)
**Branch / HEAD:** `claude/mspl-b0-prereqs` @ `66e97082` (pushed; PR
[#981](https://github.com/itchyshin/gllvmTMB/pull/981) open, src-touching, maintainer-merge only)
**Working dir for this branch:** worktree `/private/tmp/gllvmtmb-mspl-b0-prereqs`
(the main Dropbox checkout is a SHARED multi-lane checkout — never `git checkout` in it; use worktrees)

## Mission and claim boundary

The Design 118 pre-registered calibrator arc is **finished and FAILED** — that verdict is final
and recorded; do not reopen it. `MSPL-04` stays `blocked`; no public interval/SE/vcov route
exists. The OWED work is a **new lane** implementing **theorem-gated inference**, proposed to and
wanted by Shinichi (*"can you implement it and usable??"* · *"start a new lane to finish this
once for all"*), grounded in the two primary papers he supplied (both read this session):

- Sterzinger & Kosmidis 2023 (Stat & Comp 33:53), `/Users/z3437171/Desktop/s11222-023-10217-3-1.pdf`
- Sterzinger, Kosmidis & Moustaki 2026 (Psychometrika 91:494),
  `/Users/z3437171/Desktop/maximum-softly-penalized-likelihood-in-factor-analysis.pdf`

**The thesis the new lane builds on (from the primaries, not from us):** MSPL inference is an
ADMISSION problem, not a calibration problem. 2023 §7 + FA Thm 5.2: with soft scaling
(`c_n = o(√n)`) and identifiability, MSPL is asymptotically equivalent to ML *including its
distribution* — plain Wald/profile intervals are then valid (their Fig. 1 shows near-nominal Wald
coverage). Where the conditions fail (separation, Heywood, rank-deficiency), no first-order
interval is valid (Kosmidis & Firth 2021, verified against the primary: the caveat survives
profiling but is existence-only). The FA paper's own §7 practice EXCLUDES condition-violating
fits from inference. Hence: **admit → plain penalised-profile CI; refuse → typed refusal.
No fitted calibration map anywhere** (that is what failed, and why).

## What is DONE (do not redo)

1. **Phase A** (zero-compute): mechanism partition; A1b count-attractor proof (INTRINSIC);
   Kosmidis–Firth primary verification; calibrator + fence design. Archived:
   `docs/dev-log/mspl-interval-phase-a/` (6 reports).
2. **Design 118 signed, executed, discharged with FAIL.** §8 ledger complete DEV-1..12
   (on `main`; #984, #1002, #1009, #1056). Vault decisions D-148 (signatures) and **D-155**
   (the failure + refuted premise).
3. **B1 campaign COMPLETE and clean**: 7,920/7,920 shards, 132/132 cells, 250,380 rows,
   15,840 sidecars (2/shard exact), zero repair failures.
   Root: Totoro `/home/snakagaw/gllvmtmb-local-artifacts/b1-full-20260816` (KEEP; D-50 local-only).
4. **B2 executed; calibrator FAILED hold-out** (G1 0.0%, G4 fail). Mechanism independently
   verified: degenerate optimum — clip-as-refusal removes rows from the metric; frozen map
   scores 0.0690 over 30 surviving units (95,578 refused) vs 12.985 over 264 no-refusal.
   Review: session scratchpad `b2-diagnosis-review.md`; durable summary in DEV-11 and
   `docs/dev-log/2026-08-16-phase-b-verdict-and-recommendation.md`.
5. **The envelope measurement (trace-exact, done this session):** uncalibrated 0.95
   penalised-profile CIs pass the lane-B-style screen in **52/132 cells**; by prevalence:
   **π=0.50 → 96.7%** pass; extremes (0.03–0.20, 0.80–0.97) → 17–31%.
   Data: Totoro `~/b1-consolidated/exact-envelope.csv` (+ `nominal-profile-screen.csv`,
   screening-grade). This is the empirical shadow of the theorems' conditions.
6. **Package prerequisites on the branch:** `mspl_c_n_multiplier` probe hook (bit-identity
   9.05e-12), profile bracket-search fixes, `b1_profile_trace_endpoint` non-monotone fix,
   B1/B2 harnesses + 42 B2 tests. All pushed.
7. **#1020 filed and sharpened**: pre-existing decomposition-check failure; trigger =
   inner Laplace dimension (`n_site × q`) × cloglog low-p tail; 96×3 q=2 fails 38% at π=0.03.
8. **Cross-lane duties done**: directed note to the SE-series (Cursor) lane
   ([#1058](https://github.com/itchyshin/gllvmTMB/pull/1058), check-log + research note);
   B1 launch collision resolved (D-87) — the sibling stood down permanently.

## OWED — the new lane's narrow first tasks (in order)

1. **Lane preflight** (`~/shinichi-brain/tools/lane_preflight.sh`), classify this handover
   against current git, claim a fresh branch (suggest `claude/mspl-theorem-gated-inference`).
2. **Draft the new pre-registration** (next free design number — CHECK via preflight across
   all refs; 118's numbering note explains why). Content skeleton already agreed in chat:
   - Admission gate = the theorems' own fit-time conditions: (a) softness ratio
     ‖R_n^{-1/2}∇P(θ̂)‖ (2023 §7; penalty gradient computable from X, W(β̂), no refit);
     (b) identification/curvature check (FA N2′; min-eig / condition of information at θ̂);
     (c) the shipped separation screen. NO fitted map, NO tuned thresholds against coverage —
     thresholds argued from the theorems and fixed a priori.
   - Admitted → penalised-profile CI at nominal level. Refused → typed refusal naming the
     failed condition. Wald optional secondary; bootstrap stays internal.
   - Scope decision for Shinichi: logit-first promotion (Thm C.1 bound is logit-only; the
     authors state probit/cloglog bounds are open work) vs all-three-empirical.
   - Validation: re-score the existing 250k rows under the gate (traces re-threshold free;
     compute the gate quantities in one cheap Totoro pass) — coverage AMONG ADMITTED fits and
     admission rate per cell are the endpoints. Declare gates before scoring. The spent
     Design-118 hold-out cannot be reused as a fitted-map test, but condition-gated
     descriptive coverage is a different, non-fitted claim — state this distinction explicitly.
3. **Get Shinichi's sign-off on the pre-registration**, then implement `confint()` for MSPL
   fixed effects behind the gate (fence machinery exists in `inst/sim/b1-calibration/`;
   needs porting into `R/mspl.R` proper + typed refusals + docs + tests).
4. MSPL-04 `blocked` → `partial` ONLY after the gated validation passes and Shinichi reviews.

## PROTECTED / boundaries

- Design 118's hold-out is SPENT for fitted-map claims — never tune anything against it.
- The five #1020 cells (B124/126/128/130/132) + B048's lost 38% stay attributed, never in
  denominators, until #1020 is fixed (a separate, package-level lane).
- Sibling lanes: Cursor SE-series (Beta/Tweedie/Gamma/nbinom doors) is live — coordinate via
  check-log; PR #981 is maintainer-merge only; do not edit the shared Dropbox checkout's HEAD.
- Jackknife remains rejected (D-148). The 2,102-core-hour constrained-inversion run stays cancelled.

## Environment

- **Branch worktree:** `/private/tmp/gllvmtmb-mspl-b0-prereqs` (kept). Cleaned this session:
  the other /private/tmp worktrees (note-cursor removed; 118-dev11 + interval-calibration may
  need `git worktree prune` — removal timed out on Dropbox FS; harmless).
- **Totoro** (socket `~/.ssh/cm-snakagaw@totoro.biology.ualberta.ca:22`, no Duo): kept and
  declared — campaign root (above), `~/b1-consolidated/` (fit, verdict, envelope CSVs, cache),
  `~/gllvmtmb-b1-repair-02b32324` (compiled clone @ current tip, reuse for re-scoring).
  All scratch scripts/logs/processes swept (D-142 verified: 0 stray processes).
- Local R 4.6.0 with package deps; narval staged-but-unused root
  `/project/def-snakagaw/snakagaw/gllvmtmb-mspl-b1-a3b31e62` (deps installed via login node;
  harmless to leave or delete).
- Verification command: `Rscript -e 'testthat::test_local(filter="b2-calibrator")'` (42 pass)
  in the worktree; `--as-cran` untouched by this lane's docs.

## Landing state

| Item | State | Resume / restriction |
|---|---|---|
| Branch `claude/mspl-b0-prereqs` | LANDED (pushed, PR #981 open) | maintainer review; do not merge |
| Design 118 ledger DEV-1..12 | LANDED on `main` | closed record |
| B1 campaign + B2 outputs | KEPT on Totoro (declared paths) | read-only inputs for the new lane |
| Envelope CSVs | KEPT on Totoro `~/b1-consolidated/` | promotion-grade = `exact-envelope.csv` |
| New pre-registration | **OWED** | new lane, step 2 above |
| MSPL-04 | `blocked` | moves only per OWED step 4 |

## Resume prompt

```text
Read AGENTS.md and docs/dev-log/handover/2026-08-16-claude-handover-theorem-gated-inference.md. Run the handover rehydration steps, reconcile them with the current git state, then continue only the OWED Next Immediate Steps.
```
