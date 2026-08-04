# Session Handoff: VA speed measured end-to-end, two speedups shipped, ordinal crux built and proven

**Meta:** 2026-08-04 · Claude Code (solo) · branch `claude/va-lane2` · worktree
`/private/tmp/gllvmtmb-va-lane2` · **46 commits off `origin/main` @ `5bf18ab3`, UNPUSHED**

**Supersedes** `2026-08-03-claude-handover-va-lane2-blockers-closed.md` (whose §2 was retracted
mid-session — see below) and the Next Immediate Steps of `2026-08-03-claude-handover-va-lane2.md`.

**Read next:** `docs/design/va-interval-route-selection.md` and
**[issue #934](https://github.com/itchyshin/gllvmTMB/issues/934)** — the carry-over is folded
there deliberately, so this handover does not have to be the only copy.

---

## Critical Context

**1. A claim I made was WRONG and is retracted.** I reported *"the arc's founding premise is
REFUTED — VA is slower than Laplace at every N"*, committed it and put it in a handover.
Shinichi caught it. The ladder left `eval_method` at `"auto"` (which resolves to **`gh`**) and
`collapse_variational_cov` at **`FALSE`**, while `f3df8193`'s 5.8× was measured on
**`ac` + `collapse = TRUE`** — the arc itself. Two different estimators. Retracted in
`56dfd5f0`, ledger row 46 + process lesson 3, banners on four surfaces. **The harness now
requests its arm explicitly and ABORTS on mismatch (`658c5a15`), proven by a negative control.**

**2. VA vs Laplace, measured properly, crossovers MEASURED not extrapolated:**

| N | VA (AC+collapse) vs LA **with** SEs | vs LA **without** SEs (algorithm only) |
|---:|---:|---:|
| 250 | 6.72× | 4.59× |
| 1000 | 4.02× | 2.51× |
| 2500 | 1.67× | **1.11×** |
| 5000 | **0.97–1.17×** | — |

Algorithm parity at **N≈2500**; including LA's SEs, parity at **N≈5000**.
**A third of the N=250 advantage is LA computing standard errors VA cannot produce at all** —
never quote a multiplier without its N and without saying whether SEs are on both sides.

**3. Three engines, three exponents:** our Laplace **N^0.97** · our VA **N^1.58** ·
**gllvm's VA N^2.16**. So VA's superlinearity is **intrinsic to the approach, not our defect** —
and we are the flatter of the two VA implementations. Against gllvm we go 0.94× → 2.72× → 3.55×
across N = 250/1000/2500. The A_i collapse is what buys this: without it AC alone is 3.7×
*slower* than gllvm.

**4. Ordinal-probit AC is NOT built.** The numerical crux is built and proven; the family is
not. See "What was NOT done".

---

## What was accomplished

| # | result | status |
|---|---|---|
| 1 | **Coverage blocker 1 CLOSED** — health gate recalibrated 1e-4 → 5e-3 against a measurement, not a guess. VA-Wald healthy yield **0/30 → 28/30** (n=150), **29/30** (n=400) | `f15ad1b7` |
| 2 | **Coverage blocker 2 CLOSED, both halves** — `.total_variance_spec()` aborts instead of silently scoring `Sigma_tt` as `V_t`; Step-0's LA formula moved to `unique = TRUE`. LA-Profile `V_j` **30/30**, coverage **0.925 / 0.929** (was collapsing to 0.096) | `2a174fb9`, `86049310` |
| 3 | **Two speedups SHIPPED, both BIT-EXACT** (0 cells differing, `all.equal(tol=0)`): `bootstrap_Sigma()` **1.26×**, `bootstrap_ci_lv_effects()` **1.21×** | `e729a5be`, `7f47717a` |
| 4 | **The profiling heuristic** — glmmTMB's unshipped FIXME, both arms measured | `98d73e2a` |
| 5 | **Ordinal crux built + he() gate PASSES**, clamp proven necessary | `05ded537`, `4a8c8827` |
| 6 | Two source-map scouts + engine knob audit | `6462fb61`, `35f16118` |

**Full package suite: 366 files, 8,963 passed, 0 failed, 0 errors.**

### The profiling heuristic (worth knowing beyond this repo)

`glmmTMB/R/glmmTMB.R:1609-1613` carries an unshipped FIXME: *"add heuristic to decide if
'profile' is beneficial… (TMB tweedie derivatives currently slow)"*. The reference
implementation has profiling, **defaults it off**, knows it is not always a win, and has never
shipped the rule. We measured both arms — same latent structure, same N, only the family
changed:

| family | joint | profiled | speedup |
|---|---:|---:|---:|
| `gaussian_anchor` (closed form) | 0.35 s (539 par) | 0.20 s (39 par) | **1.73× win** |
| `binomial_probit` H=15 (quadrature) | 5.20 s (529 par) | 92.44 s (29 par) | **17.8× loss** |

Both reach the same optimum (3.8e-13). **Two mechanisms make profiling lose**: the A_i collapse
already removed the per-unit blocks (so there is nothing left to concentrate out), or
per-evaluation derivative cost is high. Rule: **profile when there is no collapse AND evaluation
is cheap.** Note profiling does **not** fix VA's exponent — a flat ~7× penalty, constant in N
(`9c659d07`).

## What was NOT done — and the honest reason

- **Ordinal-probit AC (Item 1B) is NOT coded.** No family code 5, no `DATA_IVECTOR`s, no
  cutpoint `PARAMETER_VECTOR`, no R wiring. `va_r3_log_pnorm_diff` / `va_r3_log1mexp` are **dead
  code called by nothing**. What IS true: when the family is built, its numerically dangerous
  primitive is implemented, accurate to 4e-08/4.9e-07 against the derivation, and Hessian-safe
  **by measurement**. The lane opened on ordinal, was redirected to speed by Shinichi, and
  returned to the crux only at the end.
- **Tiers 1+2 of the coverage campaign** — fenced by D-112, and issue #934 reframes it as route
  selection. Needs Shinichi's nod on the framing before compute.
- **Lazy `sdreport()`** — 1.49–1.57× on the core LA fit, **measured**, but "fit now, SEs later"
  is a public API addition. Shinichi's call.

## Key decisions & rationale

1. **The clamp is kept, and is load-bearing — but the derivation's reasoning was too
   pessimistic.** §5.7 says a 1e-300 floor is insufficient. Control A tests exactly that and it
   does **not** produce a non-finite `he()`. Control B (clamp removed entirely) **does**. So the
   guard is necessary; the claim about *which* floor suffices is not reproduced. Both recorded —
   they are different claims and only the first is proven.
2. **Five levers CLOSED by measurement — do not re-attempt:** TMBad (**1.76× slower**),
   supernodal (needs TMBad, then fails to link CHOLMOD), custom sparse Cholesky (lives in **TMB
   core**, unreachable at package level — two independent scouts), galamm's AD (forward-mode,
   behind TMB's reverse mode), profiling-as-exponent-fix.
3. **Of five refit paths audited, only two qualified for `se = FALSE`.** `coverage_study()` calls
   `confint(refit)` and `check_identifiability()` reads `refit$sd_report` — batching the pattern
   would have silently broken both.
4. **Nothing promoted.** `default_tier` still `"gh"`, integration fence shut, `confint`/`vcov`
   still refuse.

## Blockers / open questions

- 🔴 **Push `claude/va-lane2`?** 46 commits, unpushed. Maintainer's call, standing all session.
- 🔴 **Issue #934's framing** — route selection (capability) vs coverage campaign (fenced by
  D-112). Confirm before spending compute.
- 🔴 **Lazy `sdreport()`** — public API addition.
- 🔴 **LANE COLLISION (D-88), unresolved.** A second Claude session committed **twice** from this
  session's working tree (`2a174fb9`; `7f47717a`+`136608a7`) and edited handovers on the same
  files. Nothing lost, findings agree — but twice is a pattern, not an accident.

## Gotchas paid for this session

- **`/private/tmp` was cleaned mid-session and the worktree vanished.** All commits survived on
  the branch; the uncommitted crux survived **only** because it had been scp'd to Totoro for
  testing. That was luck. **Commit at every boundary, and prefer a worktree outside `/private/tmp`.**
- **`pkill -f "<pattern>"` matches its own command line** and killed the ssh session. Use
  `pgrep -c -f "[4]3-..."` bracket-splitting.
- **`scp` over a script while processes are reading it** produced a bogus syntax error in an
  unrelated cell. Deploy before launching, never during.
- **`A && B & C &` puts only A&&B in the background job** — the `cd` applied to the first job
  only. Use explicit subshells.
- **TMB's `pnorm` is an atomic with no 2nd-order derivative** (*"Atomic 'pnorm1' order not
  implemented"*), so `obj$he()` is unavailable for anything routing through it — a property of
  TMB, not of our code.
- **A guard that has never fired is not a guard.** Three separate test defects this session would
  each have produced a green light on an untested path.

## How to resume

```sh
bash ~/shinichi-brain/tools/lane_preflight.sh /private/tmp/gllvmtmb-va-lane2
cd /private/tmp/gllvmtmb-va-lane2 && git log --oneline 5bf18ab3..HEAD | head -20
```

Read: this file → `docs/design/va-interval-route-selection.md` → issue #934 →
`lanes/mature-va-ordinal/LOOP/` (GOAL, checkpoint, ultra-plan — the ordinal build plan survives
there intact) → `dev/va-speed/20-CLAIMS-LEDGER.md` (**check status before citing anything**;
row 46 is RETRACTED).

**Never build in the Dropbox checkout (D-112).** Totoro: `~/gllvm_work/va-lane2`, ≤150 cores,
`OPENBLAS_NUM_THREADS=1`, **`R_LIBS_USER=$HOME/R/lib`** (`Rscript --vanilla` implies
`--no-environ`, so `gllvm` becomes invisible without it). Results LOCAL (D-50).

```text
Read AGENTS.md and docs/dev-log/handover/2026-08-04-claude-handover-va-speed-and-ordinal-crux.md.
Run the rehydration steps, reconcile with git, then continue the OWED steps — starting with
whether issue #934's route-selection framing is approved, since it gates the compute.
```
