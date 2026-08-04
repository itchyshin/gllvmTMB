GOAL: see `GOAL.md`. The lane was REDIRECTED to **speed** by Shinichi; `arcs.md` has the arc
list. Ordinal Item 1(B) remains deferred, not cancelled.

STATE: **lane closing — carry-over is FOLDED into a design note + issue.**
Read `docs/design/va-interval-route-selection.md` and
https://github.com/itchyshin/gllvmTMB/issues/934 FIRST. They supersede this file on detail.

## The correction that should shape the next lane

Shinichi, 2026-08-04: *"VA is not Wald but MCMC posterior like trick?? — and can use sandwich
like trick??"* Both right. **VA's uncertainty is a variational POSTERIOR, not a sampling
distribution**, and mean-field VA is known to under-state variance — so VA-Wald under-covers by
construction, and **VA-Wald is the only route Step-0 ever scored** (0.897 / 0.935 vs nominal
0.95, but 30 seeds, MCSE 0.055 — triage, not an estimate).

**The sandwich is the theoretically indicated route, is already built
(`R/va-intervals.R:1409`, `:1496`), and has NEVER been scored.** That is the highest-value
unmade measurement in the arc. It requires a stationarity gate — an adversary already caught a
version returning plausible SEs from a `par` 4–6 orders off-optimum.

## ARCS DONE (verified)

- **A0 retraction** `56dfd5f0` — banners on 4 surfaces; ledger row 46 + process lesson 3.
- **Blockers 1 & 2 CLOSED** `f15ad1b7`, `2a174fb9`+`86049310` — verified end-to-end:
  VA-Wald healthy yield **0/30 → 28/30** (n=150) and **29/30** (n=400); LA-Profile V_j 30/30,
  coverage 0.925 / 0.929 (was collapsing to 0.096).
- **Two speedups SHIPPED, both bit-exact** (0 cells differing): `bootstrap_Sigma()` 1.26×
  (`e729a5be`), `bootstrap_ci_lv_effects()` 1.21× (`7f47717a`). Of 5 refit paths audited only
  2 qualified — `coverage_study()` and `check_identifiability()` genuinely need their SEs.
- **Harness hardened + guard PROVEN by negative control** `658c5a15`.
- **Scouts + knob audit** `6462fb61`, `35f16118`.
- **Speed facts, crossovers MEASURED not extrapolated** `202292cf`, `11a33e71`.

## The numbers, with regimes attached (never quote without them)

| comparison | N=250 | N=1000 | N=2500 | N=5000 |
|---|---:|---:|---:|---:|
| VA(AC+collapse) vs LA **with** SEs | 6.72× | 4.02× | 1.67× | **0.97–1.17×** |
| VA vs LA **without** SEs (algorithm only) | 4.59× | 2.51× | **1.11×** | — |

Algorithm parity **N≈2500**; with LA's SEs, parity **N≈5000**. VA ~N^1.58, LA ~N^0.97.
**A third of the N=250 advantage is LA computing SEs VA cannot produce at all.**

## CLOSED by measurement — do not re-attempt

TMBad (1.76× *slower*) · supernodal (needs TMBad, then fails to link CHOLMOD) · custom sparse
Cholesky (lives in TMB core, unreachable at package level) · galamm's AD (forward-mode, behind
ours) · profiling as an exponent fix (~7× penalty, constant in N).

## NEXT (all in issue #934)

1. **Score the sandwich route**, Wald as control, stationarity-gated, enough seeds to rank.
2. **Lazy `sdreport()`** — 1.49–1.57× on the core LA fit, measured. Needs a public API
   decision → **Shinichi's call**, do not build unilaterally.
3. `multiphase` · `optimHess` · `scale=` · `inner.control` (⚠ may move estimates) · sdreport knobs.
4. Ordinal Item 1(B) — derivation done (`ALBERT-CHIB-DERIVATION.md` §5, cutpoints pinned §5.8);
   only the build remains, crux fully specified in `ultra-plan.md`.

## OPEN GATES

- **G2** — any change to the SHIPPED Laplace engine (`src/gllvmTMB.cpp`) needs maintainer + review.
- **G3** — do NOT push `claude/va-lane2`. **43 commits unpushed. Maintainer's call, standing.**
- **G4** — statistically-free only. `inner.control`'s `tol10` may move estimates.
- **D-112** — coverage campaigns are fenced as release blockers. Issue #934 is framed as
  *route selection*, a capability question; **confirm that framing before spending compute.**

## LANE COLLISION (D-88) — unresolved, for the maintainer

A second Claude session committed to this branch **twice** from this session's working tree
(`2a174fb9` ~19:01; `7f47717a`+`136608a7` ~05:39) and also edited handovers on the same files.
Nothing was lost and the findings agree, but it happened twice. Not resolved here (D-87).

RESUME: `GOAL.md` → this file → `docs/design/va-interval-route-selection.md` → issue #934 →
`AGENTS.md`. Reattach to `/private/tmp/gllvmtmb-va-lane2` (do NOT recreate). Totoro lane
`~/gllvm_work/va-lane2`, ≤150 cores, results LOCAL (D-50). Nothing promoted: `default_tier`
still `"gh"`, integration fence shut, `confint`/`vcov` still refuse.
