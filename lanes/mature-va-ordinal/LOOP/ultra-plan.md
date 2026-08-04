# gllvmTMB mature-VA — Item 1(B): ordinal-probit Albert–Chib

## Context

**First, a correction I owe you.** I claimed *"the arc's founding premise is REFUTED — VA is
slower than Laplace at every N"*, committed it (`33805e86`) and put it in a handover
(`36f4b5b1`). **It is wrong.** You were right that VA was ~6× faster.

The mechanism: `f3df8193` measured `eval_method = "ac"` with `collapse_variational_cov = TRUE`
— Albert–Chib closed form plus the A_i collapse, *which is the entire point of this arc*. My
ladder let `eval_method` default to `"auto"` → `gh`, with `collapse = FALSE`. **I benchmarked
the pre-arc quadrature route and reported it as a verdict on the arc.** The numbers reconcile
rather than conflict: 4.10 s (AC+collapse) vs my 53.02 s (GH/H=15) at N=250 is ~13×, exactly
what "GH is 75–82% of a VA fn/gr call" predicts. Two signals were in my own output and I
ignored both: `va_status = failed_health_gate` on 12/12 cells, and `va_iters = NA` on 12/12.

I also lost the thread of the arc itself — I rehydrated from the lane-2 handover and treated
it as the whole picture, then drifted into EVA and AGHQ, neither of which is your arc. The
real arc is **MATURE-VA**, and its handover is
`docs/dev-log/handover/2026-08-03-claude-handover-mature-va-item1.md`.

### Where the arc actually stands

Your scope decision, on record in `memory/AGENT_LOG.md` (2026-08-03): *"binomial-probit AND
ordinal-probit together (Albert–Chib Theorem 1 + Theorem 3)"*, win condition **speed at
protected accuracy** (`rel_frob ≤ 0.298`), *"VA's value is SPEED VIA CLOSED FORM."*

| family | closed form | status |
|---|---|---|
| gaussian · poisson · binomial-logit (JJ) | exact / JJ | pre-existing ✓ |
| **binomial-probit** | Albert–Chib Thm 1 | ✅ built (`eval_method = "ac"`, PR #933) |
| **ordinal-probit** | **Albert–Chib Thm 3** | ❌ **NOT BUILT — the unfinished half of your scope** |
| nbinom2 | none | stays on quadrature, by design |

The mature-VA handover's "next arc, recommended order" was: (1) warm start as a real route,
(2) A_i collapse, (3) conditioning vs gllvm, (4) **ordinal Item 1(B)**, (5) the multi-seed
simulation arc. **(1) and (2) have since landed** (`ffabece0` + repair `43341784`; `07af7df3`).
So the next unbuilt item in your own ordering is **(4) ordinal**, and it is the one that
closes "mature VA for all" — after it only nbinom2 lacks a closed form, by design.

**The maths is already done.** `dev/va-speed/ALBERT-CHIB-DERIVATION.md` §5 carries the full
cumulative-probit ordinal derivation: B1–B4, the stable `log(Φ(a) − Φ(b))` in §5.7, and the
cutpoint parameterisation **pinned** in §5.8 with the per-trait block layout. This arc is
implementation, not derivation.

---

## 🎯 GOAL

```
PLATFORM: Claude Code, solo (this session's runtime).

DELIVERABLE: ordinal-probit Albert-Chib as a real VA family in the engine -- family code 5
-- completing the binomial+ordinal scope set on 2026-08-03. Fenced: no export, no
default_tier change, no public claim.

HEADLINE: the derivation is DONE (ALBERT-CHIB-DERIVATION.md section 5, cutpoints pinned in
5.8). What is missing is the build: a new family code in the VA template and R registry,
two DATA_IVECTORs + a cutpoint PARAMETER_VECTOR, and a NUMERICALLY SAFE log(Phi(a)-Phi(b)).
That last one is the crux and is a known trap: gll_log_pnorm_diff CANNOT be ported as-is --
CppAD::CondExp evaluates BOTH branches, and its unselected branch is -Inf whenever both
category bounds sit >8.2924 from eta on the same side. That is a NaN HESSIAN that fn() and
gr() stay finite and correct through, so no gradient check can see it. The clamp magnitude
is load-bearing: -1.2e-16 (double unit roundoff); -1e-300 and -1e-20 both fail.

FIRST: retract the false "VA is refuted" claim at every surface it reached.

DESIGN QUESTION TO SETTLE EARLY (see below): AC-alone collapses a real psi at low n_trials,
and for binomial the remedy was to END ON GH. There is no ordinal GH tier to warm into.

DEFER (fenced): EVA and AGHQ (not this arc -- I raised both in error). The interval-coverage
campaign (D-112). Package-vs-package accuracy claims (need the multi-seed arc first).

DISCIPLINE: every claim states eval_method, collapse, H, n_trials, and psi. Verify = he()
finite, not just gr(). Compute = Totoro, results LOCAL (D-50). Nothing promoted:
default_tier stays "gh", the integration fence stays shut.
```

---

## Phase 0.25 — prior-work sweep RECEIPT

| surface | evidence it ran | finding | call |
|---|---|---|---|
| **the claim I doubted** | `git log -1 --format=%B f3df8193`; `dev/va-speed/31-la-vs-va-timing.R:44-49` | **`eval_method="ac"`, `collapse=TRUE`, `H=15L`** — a different estimator from my ladder's | **retract my claim; his 5.8× stands** |
| **my own results** | `readRDS` over `43-vala-*.rds` | `va_iters` NA 12/12; `failed_health_gate` 12/12 | the harness never proved convergence |
| **the arc's real handover** | `ls -lat docs/dev-log/handover/`; read `…-mature-va-item1.md` (26 KB, all 460 lines) | MATURE-VA arc; ordinal is the unbuilt half of Item 1 | **this is the arc** |
| **is the derivation done?** | `grep -nE "^#{1,3} \|Theorem 3\|ordinal" dev/va-speed/ALBERT-CHIB-DERIVATION.md` | §5 (B) complete: B1–B4, §5.7 stable CDF difference, §5.8 cutpoints **PINNED** | **do NOT re-derive** |
| **is ordinal already in the engine?** | `grep family_code inst/tmb/gllvmTMB_va_r3.cpp`; `R/va-r3-proto.R:230-241` | codes 0–4 only; zero hits for ordinal/cutpoint/cuts | genuinely new — code 5 |
| **are handover items 1–2 done?** | `git log --oneline 5bf18ab3..HEAD` on lane 2 | warm route `ffabece0` + repair `43341784`; A_i collapse `07af7df3` | ordinal is next in your own ordering |
| **brain — decisions** | `grep -in gllvmtmb memory/DECISIONS.md`; D-112, D-113 | capabilities not coverage; 0.6 shipped (`v0.6.0` tagged) | coverage stays fenced |
| **brain — recent log** | `sed -n '691,760p' memory/AGENT_LOG.md` | your scope + win condition on record | ordinal was always in scope |
| **brain — deep research** | `grep -in gllvm projects/deep-research/README.md` | `dr25` (VA implementation; the A_i prior art), `dr21` (engines) | read `dr25` before claiming novelty |
| **things NOT to build** | `rg sdreport R/`; register `MIS-25…31` | `se = FALSE` already exists; missing-data #332 done | skip both |

**Verdict:** build the gap — ordinal AC — reusing the finished derivation, the existing AC
tier as the structural template, and the `gll_log1mexp` clamp lesson from PR #925.

---

## 🔴 The design question to settle in S3, before the C++ is written

The mature-VA handover §3 records that **AC-alone collapses a real ψ** at low `n_trials`
(planted ψ SD 0.6 → AC returns 0.0001 at `n_trials = 6`, where GH returns 0.6207), and calls
it *"disqualifying on its own"* — identified but biased, which is more dangerous than
unidentified. The remedy adopted for binomial-probit was **to end on GH** (warm-start GH
from AC), which inherits GH's ψ recovery.

**There is no ordinal GH tier to warm into.** So ordinal AC would inherit the defect with no
remedy in the engine. Three options, to decide from S3's measurement rather than in advance:

- **(a)** Ship ordinal AC fenced, with the ψ-collapse regime measured and stated. Cheapest.
- **(b)** Build an ordinal GH tier too, so the warm route exists for ordinal. Doubles the arc.
- **(c)** Ship ordinal AC only where the measurement shows ψ is recovered (high `n_trials` /
  many categories), fenced by that regime.

S3 measures the ψ-collapse boundary for ordinal; the answer picks the option. I recommend
holding this open until S3 rather than guessing now.

---

## Slices

| # | slice | member | model · effort | time | files | dep |
|---|---|---|---|---|---|---|
| **S1** | **Retract the false claim** — visible correction banner (the `305b6b86` pattern, never a quiet edit) on `46-VA-VS-LA-VERDICT.md`, the `…-blockers-closed.md` handover, `20-CLAIMS-LEDGER.md`, check-log. State the arm confusion explicitly so it cannot recur | Rose | Sonnet · med | 25 m | 4 docs | — |
| **S2** | **Harden `43-va-vs-la-ladder.R`**: record + assert the RESOLVED `eval_method`/`collapse`/`H`; abort loudly on mismatch; capture real iteration counts and a convergence flag | Curie | Sonnet · med | 30 m | 1 script | — |
| **S3** | **Ordinal ψ-collapse probe** — the design question above. Fit ordinal via the *shipped Laplace* ordinal path across `n_trials` × #categories × planted ψ, and characterise where AC's known collapse would bite. Cheap, and it picks (a)/(b)/(c) | Fisher | Opus · high | 45 m | Totoro | — |
| **S4** | **`va_r3_log_pnorm_diff`** — the numerical crux. Implement stable `log(Φ(a) − Φ(b))` per derivation §5.7, re-pointed at `va_r3_log_pnorm`, with the `-1.2e-16` input clamp. **Unit-test `he()` finiteness, not just `gr()`** — the PR #925 lesson is that `fn`/`gr` stay finite *and correct* while `he()` goes NaN | Gauss | Opus · high | 1.5 h | `inst/tmb/gllvmTMB_va_r3.cpp` | — |
| **S5** | **Family code 5 wiring** — template: two `DATA_IVECTOR`s (`n_ordinal_cuts_per_trait`, `ordinal_offset_per_trait`), cutpoint `PARAMETER_VECTOR`, the AC ordinal term per §5; R: `.va_r3_family_name_to_code`, the Laplace→VA map, validation, tier guard | Gauss | Opus · high | 2 h | template + `R/va-r3-proto.R` | S4 |
| **S6** | **Correctness verify** — mirror `06-ac-tier-verify.R`'s 21 checks for ordinal: tier round-trip, family guard both directions, **AC never below the exact NLL** (strict lower bound, NOT an identity check), `he()` finite, AD gradient vs finite difference, and the `n`-scaling check | Curie | Sonnet · high | 1 h | new verify script | S5 |
| **S7** | **Recovery test** — planted ordinal DGP, cutpoints and loadings recovered; plus the registry-drift test at `test-va-r3-prototype.R:510` (adding a tier WILL break it — that is correct, update it) | Curie | Sonnet · med | 1 h | `tests/testthat/` | S5 |
| **S8** | **Mechanical verify** — full VA suite green, fence intact (`default_tier == "gh"`, no new export, `confint`/`vcov` still refuse) | scout | Haiku · low | 15 m | test run | S6,S7 |
| **S9** | **Consolidate** — after-task, check-log, register row, handover | Rose | Sonnet · med | 40 m | dev-log | S6–S8 |
| **S10** | **Reconcile plan vs actual** | Melissa | Sonnet · low | 10 m | `plan-actual/` | S9 |

**PARALLEL:** {S1, S2, S3, S4} · **SEQUENTIAL:** S5←S4, S6←S5, S7←S5, S8←{S6,S7}, S9←S8, S10←S9

**FAN-OUT BUDGET:** ≤6 new children · scout 1 (S8) · build 3 (S1, S2, S7) · ceiling 2 (S4/S5
Gauss — new likelihood in a TMB template with a known NaN-Hessian trap; S3 Fisher — picks the
shipping shape). Both ceiling rows justified: Terra/Sonnet is not safe where `he()` can go NaN
undetected by any gradient check.

**LUNA SUITABILITY:** yes — S8.

**ESTIMATE:** ~8 h. **Does not fit one session** — S1–S4 and S5 are a natural first sitting,
S6–S10 a second. Handover between them.

## Verification

- **S4 is the gate.** If `he()` is not finite over `|a|,|b| > 8.2924` on the same side, stop —
  that is the exact defect PR #925 fixed in the shipped path, and it is invisible to `gr()`.
- **AC is a strict lower bound**, so ARC.md's *"objective identical to ~1e-13"* discipline
  does **not** apply and would fail a correct implementation. Check `AC ≥ exact NLL` with a
  strict gap instead.
- `devtools::test(filter = "va")` must stay at 1335 passed / 0 failed, plus the new cells.
- Fence assertions in S8 are pass/fail for the arc, not advisory.
- Totoro `~/gllvm_work/va-lane2`, ≤150 cores, `OPENBLAS_NUM_THREADS=1`,
  `R_LIBS_USER=$HOME/R/lib`. Results LOCAL (D-50).

## What I am NOT proposing, and why

- **EVA, AGHQ** — I raised both in error from D-113's track list; neither is this arc, and
  Codex owns the EVA lane.
- **Package-vs-package accuracy** — the handover is explicit that nothing should be claimed
  before the multi-seed Totoro arc (item 5 in its ordering). That is the arc *after* this one.
- **Promoting anything** — `default_tier` stays `"gh"`, fence shut, no export.
