# The gllvm scaling convention is SETTLED. Do not re-argue it. Re-run the arbiter.

**Verdict: `Lambda = theta %*% diag(sigma.lv)`. The `sweep(th, 2, sg, "*")` convention in
`dev/` is CORRECT. gllvm SHARES our ~2x loading attenuation.**

Settled 2026-08-05 by measurement, after this line flipped **three times** on argument alone.

## Why this file exists

| # | claim | status |
|---|---|---|
| 1 | "gllvm shares the bias" (original) | **CORRECT** — but retracted in error |
| 2 | "raw `theta` IS Lambda; gllvm is unbiased" (`2026-08-05-claude-handover.md`, retraction of #1) | **WRONG** |
| 3 | "the CSV's gllvm rows are wrong; corrected gllvm is UNBIASED ≈1.01–1.02" (`2026-08-05-addendum-probit-nladder.md` §2, commit `c327ff61`) | **WRONG** — repeats #2 |

Two independent sessions reached #2/#3 separately. That is not carelessness; it is a trap
(see "Why the wrong answer is seductive" below).

## The arbiter — 30 seconds, convention-free

```sh
Rscript dev/va-usability/170-gllvm-convention-arbiter.R
```

It reconstructs **gllvm's own linear predictor** and asks which Lambda reproduces it. That is
gllvm's own arithmetic, so it cannot be argued with:

| convention | max abs difference from gllvm's own eta |
|---|---|
| raw `theta` | **4.78e-01** |
| **`theta %*% diag(sigma.lv)`** | **4.44e-16** — machine precision |

Plus the structural fact: `theta`'s diagonal is pinned at **exactly** 1 (`theta[1,1] = 1`,
`theta[2,2] = 1`, `theta[1,2] = 0`). **A loading matrix with a fixed unit diagonal cannot
represent loading magnitude.** The scale has to live in `sigma.lv` (~0.71–0.86); `lvs` are
already ~unit scale (sd ~0.89–0.95), so there is nowhere else for it to go.

## Why the wrong answer is seductive — the actual lesson

**The wrong convention produces the expected number.** Raw scoring gives trace ~1.0, which looks
like "gllvm is unbiased, as a mature CRAN package should be." The correct convention gives ~0.53,
which looks like a scoring bug. Both sessions reached for the number that matched their prior.

A third corroboration nobody used: in `100-probit-stage8-summary.csv`, `va_ac` and `gllvm` agree
to **five or six significant figures at all three sample sizes** (0.507808 vs 0.507810;
0.5119271 vs 0.5119259; 0.5075200 vs 0.5075259). A *scoring artifact* cannot make two independently
implemented optimisers agree to six digits three times. That agreement is evidence they are
computing the **same estimator with the same bias** — which is exactly what the arbiter proves.

## The process rule, and the half that was missing

The addendum proposes: *"when you retract a convention, grep for every script that copied it, in
the same pass."* Correct, and necessary — the fold had already spread to a second script.

**But applied here it would have been a disaster.** The "retracted" convention was the *right*
one, and a same-pass sweep would have propagated the error into ~10 scripts
(`dev/va-speed/07,10,18,19,29`, `dev/va-usability/70,71,130,140`, `dev/va-eva-comparison-runner.R`,
plus `dev/bound-vs-estimates.md` pitfall #1, `dev/three-engine-demo.R`,
`dev/real-data/real-data-benchmark.R`, `dev/eva-probe/common.R`). One session began that sweep and
stopped only on reading pitfall #1's specific, checkable claim.

**So the rule needs both halves:**

> When you retract a convention, (a) **verify the retraction against an artifact before
> propagating it** — especially when the convention you are retracting is the one that yields the
> *unexpected* answer — and only then (b) grep for every script that copied it, in the same pass.
>
> Half (b) without half (a) is an error amplifier: it converts one wrong belief into N wrong files.

A convention dispute is settled by an **arbiter that is convention-free** (here: does it reproduce
the other package's own linear predictor?), never by argument about which quantity "is" the
loading.

## What this changes

- `100-probit-stage8-summary.csv`'s `gllvm` rows are **CORRECT**. Do not "fix" them.
  The addendum's §2 one-line change must **not** be applied.
- **gllvm is not an unbiased reference for loading recovery on probit.** trace ~0.53, eta_var ~0.42.
- The curvature difference between our `ac` (constant −1) and gllvm (exact `(log Phi)''`, verified
  to 4e-15) is **real but is NOT the cause of the attenuation** — gllvm uses the exact curvature
  and attenuates just as much.
- **Our `gh` tier (trace ~1.0, eta_var ~1.03) is the only unbiased arm measured, and it beats
  gllvm.** That is the headline, and it is better than the one being chased.

## Still open

Both second-order *expansions* attenuate regardless of curvature accuracy; only *quadrature*
escapes. So the live suspect is the expansion itself, not the coefficient. Untested.
