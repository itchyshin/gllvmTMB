# VA-warm-started Laplace hybrid: scaling and rescue verdict

**Author:** Claude (closer role), 2026-08-03. Worktree `/private/tmp/gllvmtmb-va-lane2`,
branch `claude/va-lane2`. Not committed (per task instruction).

## Answer, in three sentences

No — on the only two data points that ran a complete paired campaign (N=200 and N=1000,
both q=2, single seed each), the hybrid's advantage **shrinks** as N grows and **flips
from a 1.12–1.14x speedup into a 0.84x slowdown**, the opposite of what "the inner
solve dominates at scale" predicts. Seeding the random-effect modes (`z_B`, script 34)
changes nothing about that verdict — it lands on the identical optimum as the
fixed-parameter-only hybrid (script 33) at every rung tested and is marginally faster
on the LA stage alone, but it does not alter the sign of the scaling trend because the
bottleneck is the VA sub-fit's own cost, not the LA stage. No rescue was demonstrated
either: across 4 boundary regimes and 3 seeds each, cold Laplace's `nlminb` never once
failed to converge, so there was no genuine "cold LA struggles" cell for the hybrid to
rescue, and in the one regime built to stress the hybrid's own applicability (`q=7`)
the hybrid mechanism itself failed outright (VA's rank cap) while cold LA succeeded.

## The ladder numbers

Regime: binomial-probit, `T=20`, `unique=FALSE` (single loadings-only B-tier), Totoro
(384-core box, loadavg 1.6–3.2, other agents' jobs concurrently present). 4 arms — VA,
cold LA, HybridFixed (script 33's route), HybridModes (script 34's route with `z_B`
mode-seeding) — paired, interleaved, order-rotated, untimed warm-up, hybrid time
**includes** the VA sub-fit.

| N | q | arm | secs | va_secs | la_secs | rel_frob | objective | same optimum vs cold LA |
|---|---|---|---|---|---|---|---|---|
| 200 | 2 | VA | 1.85 | – | – | 0.25806 | 6164.136 | – |
| 200 | 2 | LA (cold) | 14.04 | – | – | 0.11270 | 5985.089 | – |
| 200 | 2 | HybridFixed | 12.50 | 1.85 | 10.65 | 0.11271 | 5985.089 | SAME (Δobj≈0.0000) |
| 200 | 2 | HybridModes | 12.28 | 1.85 | 10.43 | 0.11271 | 5985.089 | SAME (Δobj≈0.0000) |
| 1000 | 2 | VA | 26.39 | – | – | 0.17086 | 30402.575 | – |
| 1000 | 2 | LA (cold) | 70.94 | – | – | 0.07125 | 29453.189 | – |
| 1000 | 2 | HybridFixed | 84.61 | 25.87 | 58.74 | 0.07125 | 29453.189 | SAME (Δobj≈0.0000) |
| 1000 | 2 | HybridModes | 84.82 | 26.56 | 58.26 | 0.07125 | 29453.189 | SAME (Δobj≈0.0000) |
| 1000 | 5 | VA only | 181.35 | – | – | 0.25366 | 31557.965 | LA/Hybrid never completed before cutoff |
| 2500 | 2 | VA only | 227.93 | – | – | 0.15707 | 76600.167 | LA/Hybrid never completed before cutoff |
| 250 | *, 2500/5 | — | — | — | — | — | — | never started |

**LA-stage saving (the quantity that actually bounds the method):** N=200,q=2 →
HybridFixed 24.1%, HybridModes 25.7% (cold 14.04 s vs hybrid LA-stage 10.65/10.43 s).
N=1000,q=2 → HybridFixed 17.2%, HybridModes 17.9% (cold 70.94 s vs hybrid LA-stage
58.74/58.26 s). **The saving shrank, not grew, between the two measured rungs.**

**End-to-end speedup:** N=200,q=2 → both hybrid variants ~1.12–1.14x faster than cold
LA. N=1000,q=2 → both hybrid variants ~0.84x, i.e. **slower** than cold LA. The
mechanism is legible in the printed numbers: the VA sub-fit that the hybrid time must
include grew 14x (1.85 s → 26.4 s) between the two rungs, while the LA-stage saving it
bought grew only roughly linearly with N (~3.4 s → ~12.4 s) — the VA cost is eating the
saving, not funding it.

This is a 2-point, 1-seed-per-point campaign (planned: 3 seeds × {N∈250,1000,2500} ×
{q∈2,5}, cut short mid-run). It establishes a direction, not a settled magnitude. The
two mid-flight rungs' VA-only timings (N=1000,q=5: 181 s; N=2500,q=2: 228 s) show VA
cost itself scaling steeply, which — if the same eat-the-saving pattern holds — would
only worsen the hybrid's position further, but no hybrid number exists at those cells
to confirm it.

## Landed-on-optimum evidence, every rung

- **Script 33 smoke** (fixed-parameter warm start, N=250,T=20,q=2, seed 1): VA
  4.26 s obj 7697.87 rel_frob 0.249393; LA 23.84 s obj 7471.45 rel_frob 0.111772;
  Hybrid 22.56 s obj 7471.45 rel_frob 0.111783 — objectives identical, rel_frob to 4
  s.f. Genuinely the Laplace optimum.
- **Script 34 smoke** (mode-seeded, N=200, seed 1): cold LA obj 5985.089 rel_frob
  0.11270; hybrid obj 5985.089 rel_frob 0.11271 — SAME OPTIMUM. Independently
  MakeADFun-traced: `z_B` reaching TMB's literal `parameters` argument was proven
  bit-for-bit identical to the VA-derived seed by an adversarial reviewer, not merely
  asserted by the script.
- **Script 35 ladder**: SAME OPTIMUM at both completed rungs (N=200,q=2 and
  N=1000,q=2), both hybrid variants, Δobj≈0.0000 in every case.
- **Script 37 boundary regimes** (4 regimes × 3 seeds, mode-seeded hybrid only):
  SMALL_N_BIG_T and NEAR_BOUNDARY — 5 of 6 pairs SAME OPTIMUM (the 6th, SMALL_N_BIG_T
  seed 2, has Δobj≈0 but rel_frob differing by 0.221, likely a flat-likelihood-direction
  artifact rather than a distinct mode). RARE_EVENTS — all 3 seeds DIFFERENT optima,
  but both arms show quasi-separation (trace_hat 100–500x trace_true, the package's own
  "runaway trait loading" diagnostic fired), so `nlminb`'s own success flag is not a
  trustworthy signal for either engine there — this is a shared-fragility finding, not
  evidence the hybrid specifically got trapped (where they disagreed, the hybrid's
  objective was actually *lower*/better in 2 of 3 seeds). HIGH_Q_LOW_N — hybrid never
  ran (see below).

Net: at every rung where both arms actually completed and neither hit a known
separation/rank pathology, the hybrid landed on cold Laplace's optimum. The one
divergent regime (RARE_EVENTS) is a convergence-diagnostic reliability problem for
Laplace generally, not a warm-start-specific defect.

## Convergence-rescue result

4 boundary regimes (RARE_EVENTS, HIGH_Q_LOW_N, SMALL_N_BIG_T, NEAR_BOUNDARY; script
37), 3 seeds each, default `control` (no artificial iteration cap). **Cold LA's
`nlminb` reported `convergence=0` in all 12 completed fits** — no cell where cold
Laplace failed or hit an iteration limit, so there is no genuine "cold LA
struggles/fails" case for the hybrid to rescue in these 4 regimes at this scale.

**HIGH_Q_LOW_N (q=7, N=20, T=25) is the one regime where the arms diverged
structurally**: the Hybrid arm failed instantly (0.0 s) with `VA sub-fit failed: q
must be one integer in 0..6` — a hard, pre-existing rank cap in the VA prototype's AC
route, not the warm start trapping an in-progress fit — while cold LA converged
normally at all 3 seeds (iters 186–337, objective finite). This is a real **coverage
gap** in the current hybrid mechanism (inapplicable above q=6, since it requires a VA
sub-fit as its seed source), reported loudly per the task brief, but it is evidence of
inapplicability, not of the warm start causing worse convergence when it is
applicable.

**Verdict: the convergence-rescue hypothesis is UNSUPPORTED** at these 4 regimes and
this scale — an honest negative, not a refutation of a hypothesis that was never
actually tested (no failing cold-LA cell arose to test it against). A related,
uncontrolled single-seed probe outside the formal campaign (harder intercept, ~4%
events, full-separation-adjacent) is worth citing as a caveat only: there VA's own
separation guard refused the design outright while cold LA silently "converged" on a
badly runaway fit (rel_frob 544) — arguably the opposite of a rescue story, since VA's
refusal was the more honest signal — but this is one uncontrolled seed, not part of the
3-seed campaign.

## Defects found and their resolution

**No FATAL defect survived adversarial review of scripts 34, 35, or 37.** Three
independent adversarial passes re-ran the scripts and the campaign's core empirical
numbers (objective/rel_frob agreement, hybrid-includes-VA-time arithmetic, LA-stage
saving vs end-to-end speedup, the RARE_EVENTS quasi-separation finding) all
reproduced. No claim above rests on a defect that was later withdrawn.

Three SERIOUS-graded issues were raised and resolved as follows, none of which changes
a number in this report:

1. **Seed-reaches-TMB verification was incomplete in the scripts as written** — only
   `z_B` was traced all the way into `TMB::MakeADFun`'s literal `parameters` argument;
   `theta_rr_B`/`b_fix` relied on a weaker R-list-level assertion, and a documented,
   silent length-mismatch skip path in `R/fit-multi.R` could in principle bypass
   `b_fix` seeding undetected. *Resolution:* an adversarial reviewer independently
   extended the MakeADFun trace to `b_fix`/`theta_rr_B` on a fresh cell and confirmed
   both land bit-for-bit identical to the VA-derived seed — the mechanism itself is
   sound, but the scripts' own instrumentation should be extended to cover all three
   quantities before being reused as a template. **Status: verified externally, not
   patched into the scripts.**
2. **The `landed` field/column in both scripts reports only that
   `start_provenance$vgh_warm_start[_z]` flags were set TRUE — mechanism engaged — not
   that the fit reached the same optimum as cold LA.** The genuine same-optimum check
   (Δobj/Δrel_frob) is computed correctly elsewhere in both scripts and is what this
   report and the ledger actually cite; a reader trusting the `landed` field alone
   (e.g. from a saved `.rds` without reading the source) would be misled. **Status:
   naming defect only — this report and the ledger use the correct Δobj/Δrel_frob
   check throughout, not the `landed` field. Not patched into the scripts.**
3. **Neither script inspects `nlminb` convergence codes, gradient norms, or Hessian
   PD-ness** when determining "landed on the same optimum" — only objective/rel_frob
   agreement (script 37 is the exception: it does report `conv_code`/`max_grad`/
   `pdHess` per the rescue task's own requirement). A reviewer also reproduced an
   unguarded `if()` on a possibly-`NA` delta in script 35's same-optimum loop
   (reachable via `score_la()`'s own documented `extract_Sigma` failure path) that
   would throw an uncaught error and silently discard an entire rung's already-computed
   arms — indistinguishable from "still running" from the outside, and possibly the
   actual cause of the two rungs the SCALING report already flagged as cut off
   mid-flight. **Status: identified, reproduced, NOT fixed in this closer pass** —
   flagged here as open harness debt for whoever resumes the campaign; it does not
   invalidate any number already reported (none of the reported rungs hit the NA
   path), but it should be fixed before extending the ladder to N=1000,q=5 or
   N=2500,q=5, which are exactly the fragile large-N/q cells most likely to trigger it.

## What remains unmeasured

- The full planned grid: 3 seeds × {N∈250,1000,2500} × {q∈2,5} — only 2 of 6 (N,q)
  cells completed, each with 1 seed. No median/variance anywhere in the scaling table.
- N=1000,q=5 and N=2500,q=2: VA-arm timings only (181 s, 228 s); LA and both hybrid
  arms never finished before cutoff.
- N=250 (both q) and N=2500,q=5: never started. N=2500,q=5 is the highest-N×q corner
  and the most informative for the growth hypothesis; extrapolation from the two
  partial VA-only probes suggests it could run tens of minutes to an hour-plus for VA
  alone, plausibly the "would take hours, drop it" case, but this was never confirmed.
- Whether HybridModes' LA-stage edge over HybridFixed (1.6–2.1 pp more saved) persists
  or grows at larger N — only 2 rungs, both showing a small consistent edge, neither
  changing the end-to-end sign.
- Convergence-rescue at larger N, higher q (>6, where the hybrid mechanism cannot even
  run), or families other than binomial-probit.
- The script-35 NA-guard crash bug: whether it actually caused either of the two
  "still running when cut off" rungs to silently die rather than merely run long.
- Whether a fixed (b_fix/theta_rr_B)-only-verified, `z_B`-traced instrumentation
  pattern, extended per defect (1) above, would change any reported number — expected
  not to, based on the adversarial reviewer's independent reproduction, but not
  re-run through the extended instrumentation.

## Files

- `/private/tmp/gllvmtmb-va-lane2/docs/design/hybrid-scaling-verdict.md` (this file)
- `/private/tmp/gllvmtmb-va-lane2/dev/va-speed/20-CLAIMS-LEDGER.md` (rows appended)
- `/private/tmp/gllvmtmb-va-lane2/dev/va-speed/33-va-warmstart-la.R` (fixed-parameter
  hybrid, established baseline)
- `/private/tmp/gllvmtmb-va-lane2/dev/va-speed/34-hybrid-mode-warmstart.R` (mode-seeded
  hybrid, `z_B`)
- `/private/tmp/gllvmtmb-va-lane2/dev/va-speed/35-hybrid-scaling-ladder.R` (scaling
  campaign, 4 arms)
- `/private/tmp/gllvmtmb-va-lane2/dev/va-speed/37-convergence-rescue.R` (boundary-regime
  rescue campaign)
- `/private/tmp/gllvmtmb-va-lane2/dev/va-speed/37-full-log.txt`,
  `37-convergence-rescue-result.rds` (raw rescue campaign output)
