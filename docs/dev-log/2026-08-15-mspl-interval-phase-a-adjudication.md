# 2026-08-15 — MSPL interval calibration: Phase-A adjudication (A5, Fisher + Rose)

**Lane:** `claude/mspl-interval-calibration`, worktree
`/private/tmp/gllvmtmb-mspl-interval-calibration`. **Scope of this record:** the Phase-A
close-out of the approved ultra-plan "Calibrated intervals for binary LA-MSPL" — five
read-only analysis slices adjudicated into one pre-registration packet. **No code changed,
no fence lifted, no register row edited, no compute spent.** MSPL-04 remains `blocked`.

## What Phase A found (five slices)

Reports live in the session scratchpad
(`/private/tmp/claude-503/.../scratchpad/phase-a/`); their binding content is transcribed
into Design 118, which is the durable copy.

1. **A1 — mechanism partition** (`A1-mechanism-partition.md`). The 55 joint-gate failures
   of the 2026-08-14 production campaign partition **26 overcoverage / 6 genuine
   undercoverage / 1 availability-only / 22 borderline-by-Wilson-resolution**. Corrections
   established en route: `coverage_gate` is method-specific (unconditional for
   profile/bootstrap, conditional for Wald — the naive uniform reading inflates
   undercoverage 6 → 24); C011 (cloglog × high prevalence) is a **location** failure
   (midpoint −8.26 empirical SDs from truth, bootstrap coverage 0.010) shared by every
   method's centre; the calibratable bulk needs α\* ≈ 0.10–0.18 while C011 would need
   0.40–0.74; all 205 profile-unavailable rows are one-sided bracket-search failures with
   `centre=matched`.
2. **A1b — pinning root cause** (`A1b-pinning-root-cause.md`). **Verdict: INTRINSIC
   (fence).** The C011 pin is the exact finite optimum of the penalised objective under
   quasi-complete separation: with a saturated (all-ones) response column the loading
   collapses, the objective separates per trait, and the intercept lands on a
   count-indexed analytic root — cloglog k=24 root **1.5964000447**, matching the
   empirical mode to 1.3e-6; ten predicted attractors across three links match to
   1e-6–1e-8; stored objectives equal the collapsed model to 1e-11. No bound, clamp,
   start, constant, or underflow involved. Link ordering of the failure = ordering of
   P(saturated column) (0.938/0.525/0.048). The bootstrap catastrophe is **bootstrap
   inconsistency at the separation boundary**: resamples re-saturate w.p. ≈ 0.841, so the
   percentile interval is a needle on a centre biased by construction.
3. **A2 — Kosmidis & Firth primary** (`A2-kosmidis-firth-primary.md`). Verified against
   arXiv:1812.01938v4: the coverage caveat (*"will fail to cover regardless of the nominal
   level"*, §2.2 p. 5) **survives profiling** (*"also true when the penalized likelihood is
   profiled"*). It is an **existence** statement; the paper is silent on the rest of the
   space, so regime-scoped calibration is not contradicted. The Kosmidis-lineage union CI
   exists (Kosmidis 2007, `brglm`) but is conservative and degenerates exactly where the
   fence refuses — diagnostic only.
4. **A3 — calibrator design** (`A3-calibrator-design.md`). The S1–S5 backbone this packet
   pre-registers: penalty-sensitivity fence ($s_j$ tiers 0.25/1.0), prepivoting ladder
   M0–M5 with registered signs, level-calibrated penalised profile base + bootstrap
   fallback, named regime envelope, 88 calibration + 44 hold-out cells (probit held out
   whole), n=600 with one-shot escalation, five gates, stopping rule, ≈45.6 M
   fit-equivalent budget with a ≈26 M reduction option.
5. **A4 — BCa acceleration** (`A4-bca-simulated-acceleration.md`). The canonical/ABC/IJ
   acceleration routes are structurally blocked (no per-unit score exists for the MSPL
   objective — confirmed at file level in the archive); the one viable route is
   perturbation-resimulation, whose conversion formula is UNVERIFIED and which costs ≈600
   refits/fit — hence BCa is an ablation arm behind a literature gate, never the default.

## What was decided (the adjudication)

- **A1b's INTRINSIC verdict applied per the dispatch rule:** the S1 fence is the
  **primary control as designed** — no estimator fix, no penalty retuning, no
  re-measurement of the undercoverage cells as a bug regression (any penalty change
  relocates every attractor without recovering the truth).
- **Two A1b upgrades folded into the design** (marked `[A1b-fold]` in Design 118):
  (i) the fence's **first line is the already-shipped
  `screen_control(separation = "fixed")`** — response-column saturation is the danger
  observable, computable pre-fit, and catches the deep-separation limit where the
  sensitivity probe goes blind; the A3 probe is the second line for the near-saturated
  band. (ii) **Bootstrap intervals are inadmissible for saturated coordinates**
  (atomic resampling distribution); the shipped default refuses the interval there, with
  a flagged-conservative profile arm pre-registered as a secondary outcome behind a
  separate maintainer promotion (decision D4).
- **B0 gains an analytic oracle:** registered prediction P5 — the Route-A probe refits on
  saturated C011 datasets must land at the analytic attractor movement 1.715161 /
  1.466704 (c_n/2 / 2c_n) to 4 dp. The fence detector is predicted quantitatively from
  theory before any Phase-B fit runs.
- **Base construction:** level-calibrated penalised profile (best-measured, fails safe);
  percentile bootstrap as flagged fallback for non-saturated coordinates only; BCa and
  union CI not in the default.
- **Design-number ledger:** `lane_preflight.sh` (2026-08-15) reported NEXT FREE = 118;
  claimed by the Design 118 commit. Design 117 §6.2 replaced with a pointer to it
  (constraint-3 verification outcome, campaign verdict, "the interval design now lives in
  Design 118"); no other section touched. The lane hook flagged foreign refs carrying
  Design 117; `git diff` showed both identical to this checkout's pre-edit version — no
  fork.

## What is OWED (Phase B, behind the maintainer gate)

**Nothing runs until Shinichi signs Design 118 §0.3** (decisions D1–D6: sign-off; 45.6 M
vs 26 M budget; Totoro/DRAC split; saturated-coordinate semantics; BCa arm; owner of the
two code prerequisites — `src/gllvmTMB.cpp` is touched by live cursor/codex MSPL lanes,
so D-87 assignment is explicit). Then:

- **B0** (Totoro, ≤150 cores): `mspl_c_n_multiplier` + bit-identity gate; profile
  bracket widening + root-finder fixes with fail-first tests; per-corner fit timing and
  exact `p_free` counts (freezing the C-ID arms); 7,200-fit probe validation against the
  L1/L2 labels with the §5.3 detection/false-refusal gate. **B0 is the D-139 pre-run
  test; the full launch request returns to Shinichi with its numbers.**
- **B1 → freeze the map → B2** (DRAC job arrays): 88 calibration cells, then the
  read-once 44-cell hold-out under gates G1–G5 and the fixed stopping rule. Gate pass ⇒
  the register edit (MSPL-04) and promotion slice happen **then, not now**. Gate fail ⇒
  ship §6.1 sensitivity reporting alone and publish the negative result.

## Artifacts

- `docs/design/118-mspl-interval-calibration-protocol.md` — the pre-registration packet
  (this is the binding copy; deviations ledger starts empty).
- `docs/design/117-separation-estimability-programme.md` — §6.2 pointer edit only.
- This record.

Committed on `claude/mspl-interval-calibration`; **not pushed, no PR** — surfacing to
Shinichi is the ultra-plan orchestrator's step, per the dispatch brief.
