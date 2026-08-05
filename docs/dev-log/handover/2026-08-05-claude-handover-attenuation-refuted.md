# Handover — VA attenuation: premise INVERTED, mechanism REFUTED, `gh` is the win

**Author:** Claude Code (Fable 5), solo → **Target:** next session, no chat inherited
**Branch:** `claude/va-ac-curvature` @ **`1573fdd5`** · **Worktree:** `/private/tmp/gllvmtmb-ac-curvature`
**`origin/main`:** `5bf18ab3` — PROTECTED, untouched. No PR.

> **This handover CORRECTS two documents that are live in the repo.** Read §1 before acting on
> `2026-08-05-claude-handover.md` or `2026-08-05-addendum-probit-nladder.md` (`c327ff61`).
> Classify every item OWED / DONE / RETRACTED / PROTECTED against git before acting.

## FIRST: rehydrate

```sh
bash ~/shinichi-brain/tools/lane_preflight.sh /private/tmp/gllvmtmb-ac-curvature
cd /private/tmp/gllvmtmb-ac-curvature && ./tools/check-push-traps.sh && git log --oneline -6 && git status --short
Rscript dev/va-usability/170-gllvm-convention-arbiter.R      # 30 s; settles §1 by measurement
```

⚠ **`lane_preflight.sh` cannot see a second CLAUDE session** — it checks for a *Codex* lane. One ran
concurrently in `/private/tmp/gllvmtmb-va-lane2` during this arc and committed underneath me. Check
`ps aux | grep claude` and `git log --all --since="2 hours ago"` as well.

## 1. 🔴 TWO LIVE CLAIMS IN THE REPO ARE WRONG

| document | claim | status |
|---|---|---|
| `2026-08-05-claude-handover.md` | "gllvm's raw `theta` IS Lambda" · retracts "gllvm shares the bias" | **WRONG** |
| `2026-08-05-addendum-probit-nladder.md` §2 (`c327ff61`) | "the `gllvm` rows in that committed CSV are WRONG … corrected, gllvm is UNBIASED (~1.01–1.02)" · proposes a one-line fix | **WRONG — do NOT apply that fix** |

**Correct: `Lambda = theta %*% diag(sigma.lv)`. gllvm SHARES our ~2x attenuation.**
Proof (`dev/va-usability/170-gllvm-convention-arbiter.R`): reconstructing gllvm's **own linear
predictor**, raw `theta` is off by **4.78e-01**; `theta %*% diag(sigma.lv)` is exact to
**4.44e-16**. Structurally, `theta`'s diagonal is pinned at exactly 1 — it cannot carry magnitude.
`100-probit-stage8-summary.csv`'s `gllvm` rows are **CORRECT**.

Full record, including why the wrong answer is seductive: `dev/va-usability/CONVENTION-SETTLED.md`.
**This convention has flipped three times on argument. Do not re-argue it — re-run the arbiter.**

## 2. What is PROVEN

- **gllvm shares the attenuation** (trace ~0.53, `eta_var` ~0.42). Not an unbiased reference.
- **Our `gh` tier is the only unbiased arm measured** (trace ~1.0–1.36, `eta_var` ~1.03) and it
  **beats gllvm**. ← the real headline.
- **`ac`'s bias is a measured plim**: trace 0.508 / 0.512 / 0.508 at n = 150 / 400 / 1000. Flat.
- **The cause is NOT in the data term.** gllvm and our `ac2` hybrid use the *identical* expectation
  functional — exact `(log Phi)''` x `v/2`, verified in both sources (gllvm's `cQ` carries `0.5` at
  all ~20 accumulation sites) — yet land at 0.53 vs 1.36. Four surrogates, two packages, eliminated.
- **`CppAD::CondExp` evaluates both branches** — 118–165 s across the whole threshold dial. No
  threshold hybrid can buy speed in TMB.
- **`-v/2` is a valid global lower bound** (Jensen; `(log Phi)'' > -1`). `ac` is conservative-but-loose,
  **not wrong**. `ac2` is not a bound — hence its label `APPROX_AC2`.

## 3. What is REFUTED (do not re-chase — each has a disproof on file)

1. "gllvm is unbiased, we are uniquely biased" → the arbiter.
2. "The `<= 4` variance gate is mis-calibrated" → it caught a real `max_v` = **1.5e10** runaway.
3. "Constant-vs-exact curvature causes the attenuation" → gllvm uses exact curvature, attenuates equally.
4. "The 2nd-order expansion itself causes it" → threshold dial moves trace **up** (1.36 → 1.95), not toward 0.53.

## 4. 🎯 NEXT — the mechanism is still open, but sharply narrowed

The cause is **not** the likelihood surrogate. Two suspects remain:

**(a) The loading parameterisation — test this first, it is cheap and it is the asymmetry that
survived every elimination.** gllvm pins `theta`'s diagonal at exactly 1 and carries scale in a
separate `sigma.lv`; we leave the diagonal free in `theta_rr`. gllvm attenuates; our `gh` (same
free parameterisation, but quadrature) does not. **Test:** impose gllvm's constraint on our `ac`
fit — fix the leading `q x q` block of `Lambda` to unit diagonal and add an explicit per-axis scale
— and see whether the attenuation tracks the parameterisation rather than the surrogate.

**(b) The KL / entropy term.** Not yet compared between the two packages at all. A read of gllvm's
KL against ours is the obvious companion to (a).

**Do NOT** start by proposing a fifth data-term variant.

## 5. Landing state

| item | state |
|---|---|
| `0d37f8f1` `ac2` tier (opt-in, internal) | ✅ committed, **NOT pushed** |
| `fed5e65a` convention arbiter + stage-8 restore | ✅ committed, NOT pushed |
| `e1dbc4f6` `ac2` hybrid + dial refutation | ✅ committed, NOT pushed |
| `1573fdd5` `CONVENTION-SETTLED.md` | ✅ committed, NOT pushed |
| this after-task + handover | see final commit |
| **branch `claude/va-ac-curvature`** | 🔶 **CARRIED-OVER, unpushed.** RESUME: `git push origin claude/va-ac-curvature` |
| `claude/va-lane2` | pushed at `aba2d21e`; the other session has since added `c327ff61` **locally** |
| `dev/va-usability/raw/` | 🔶 untracked by design (D-50). Never stage. |
| `origin/main` | **PROTECTED** `5bf18ab3` |

**`ac2` earns its keep only as evidence for refutations 3 and 4.** It is never faster than `gh`, and
at its only healthy threshold it *is* `gh`. Consider reverting it, or leave it explicitly dead.

## 6. Verification state

`devtools::test()` VA subset **201 passed / 0 failed**, 1 pre-existing skip · `ac` byte-identical to
`aba2d21e` · `R/va-routing.R` untouched · `resolve("auto", probit)` still `gh` — **no default moved**
· gaussian + `ac2` correctly refused · gllvm rescore reproduced the shipped column to **+0.0000** at
all three rungs (the control proving the harness).

## 7. Traps that cost time here

- **`attenuation-lib.R` defaults `T0` (= p) to 8**, read from a global. Set it at top level *before*
  `sim_cell`, and assert `nrow(b$d) == N0 * T0`. p=8 is the width where every estimator collapses.
- **All `dev/va-usability/` measurements are pinned to the current `ac` branch.** Change the engine
  and every ladder expires.
- A unit test passing on `mu` ∈ [−3,3], `v` ∈ [0.05,1] said nothing about an optimiser that walked
  to `v` = 1.5e10. **Cover where the optimiser goes.**
- A harness that `next`s on non-`healthy` status makes a *refused* arm look like a *null* arm.
- `Rscript -e` with nested quotes will fight you — write the script to a file.
- One narrow `pgrep` returning nothing is not proof a job died.

```text
Read AGENTS.md and docs/dev-log/handover/2026-08-05-claude-handover-attenuation-refuted.md.
Run the rehydration block including the arbiter, reconcile against git, then start at §4(a) —
the loading-parameterisation test. Do not re-chase §3.
```
