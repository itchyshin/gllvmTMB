# CI-11 cross-family interval lane — CLOSED · report to the main lane (2026-07-19)

**Lane:** multinomial cross-family `extract_cross_correlations()` interval certification (CI-11).
**Branch:** `claude/cross-family-ci11-20260718` (off `main`, PR #766 merged). **Status: CLOSED. Not opening
another branch — the main lane picks up any remaining work directly from this branch.**

## Report to the main lane (one paragraph)
The cross-family interval-coverage certification RAN END TO END (Totoro pilot → DRAC super-sim job 49532634,
n_sim=13000/n_boot=499, 6389 shards → aggregate → D-43 panel). **Outcome: "all routes validated" WITHHELD
(D-43 3/3 NOT_DONE).** Honest route disposition (MEASURED, not certified): **profile = partial** (most robust;
contrast_r only), **wald = partial** (heuristic, r-dependent), **bootstrap = not_covered / fenced**. **No route
covers at the r=0.8 boundary** — pooling over r had masked it. Mechanism RESOLVED + empirically confirmed:
**finite-sample attenuation bias of the plug-in correlation functional** (binomial GLLVM loadings shrink at high
r), inherited by bootstrap+wald, escaped by likelihood-based profile; `multiple_r` has no profile route so both
its routes collapse (binomial×r=0.8×N=500 → **0.303**). **The CI-11 register / NEWS / roxygen are UNTOUCHED**
and must stay so until the fix + Ayumi's external pass + maintainer sign-off (Design 39).

## Everything landed on the branch (all committed; working tree clean)
| commit | what |
|---|---|
| `4bce0d65` | full route×estimand arms + bootstrap→contrast_r (3-lens adversarial verify, 0 blockers) |
| `0af25fd1` | Feeder-2 hardening pass 1 (MASS guard + contrast_r clamp) + 31-finding hardening map + stress-test |
| `bcdd0338` | Totoro pilot aggregate (N≤150) + plan-vs-actual reconcile |
| `d085ba22` | the MEASURED coverage certificate (DRAC super-sim aggregated) |
| `de30785f` | D-43 WITHHELD (3/3) + per-cell decomposition (r=0.8 boundary fails) |
| `53df7da2` | failure mechanism (attenuation bias, empirically confirmed) |
| `9d4a5568` | after-task closure (full certification outcome) |
| `eb24b33d` | Feeder-2 hardening pass 2 (H1–H6) + register PROPOSAL + this report |

**Verification:** 65 cross-family testthat pass; `dev/xfc-stress-test.R` all-ok (21/21); pass-2 guards proven
NO-OPS on the certification grid. Key docs: `2026-07-19-ci11-coverage-certificate-MEASURED.md`,
`…-per-cell-coverage.txt`, `…-ci11-failure-mechanism.md`, `…-ci11-register-update-PROPOSAL.md`, hardening map
`2026-07-18-cross-family-interval-hardening-map.md`. Local aggregate `~/gllvm_work/xfc-drac-results/AGGREGATED-49532634.rds`.

## FOR THE MAIN LANE — what is LEFT (pick up from THIS branch; no fresh branch needed)
All remaining work is human-gated / a bounded future arc. In priority order:
1. **Maintainer: review the route-specific register PROPOSAL** (`…-ci11-register-update-PROPOSAL.md`) and decide
   whether to apply it (profile=partial · wald=partial-heuristic · bootstrap=not_covered/fenced, with the
   disclosure hedges). **Do NOT apply without** Ayumi's pass + a fresh D-43 on the final wording (Design 39).
2. **Ayumi's external real-data pass** — the uncalibrated intervals are usable now (`method="wald"` is the robust
   first pass); her crashes / NA / non-bracketing reports on genuine cross-family data feed the SE/interval
   hardening. Two hardening passes already landed; the map lists the rest.
3. **The profile-`multiple_r` fix arc** (the principled repair; **maintainer-design-gated** — it un-fences a
   deliberately-fenced un-profileable functional). Build a likelihood route for `multiple_r` mirroring
   `profile_ci_correlation`, re-measure at binomial/r=0.8/N=500, re-run D-43. Task chip `task_25cbceb0`.
4. **Remaining hardening-map minors** (task chip `task_7368e457`).
5. **Merge decision** — the branch carries API changes to the merged `extract_cross_correlations()` (the new
   arms + 2 hardening passes). Merging is the maintainer's call (high-risk API surface); this branch is pushed
   and ready for that review. Nothing here flips CI-11.

## Deferred menu (unchanged; separate future arcs, not this lane)
item-3 one-per-unit recovery certificate · replication-aware contrast-Ψ · multiple-multinomial / structured
cross-family · pkgdown cross-refs.
