# VGH vs the gllvm package — corrected head-to-head, 2026-07-29

Testing the claim "VGH + Laplace is the fastest and best GLLVM algorithm in R".
Gaussian family, q = 2, 3 seeds per cell, each package at its **own defaults**.

## A defect found and fixed before any number was believed

The first run reported `relfrob_G` of **5772** for gllvm — i.e. gllvm looked
catastrophically inaccurate. It is not. `gllvm` constrains its loading matrix for
identification: `fit$params$theta` carries **1.0 on the diagonal** and is *not* the
loadings; the scale lives separately in `fit$params$sigma.lv`. The actual loadings are
`theta %*% diag(sigma.lv)`.

Verified on an 80×5 gaussian fixture: `theta` alone → relfrob 505.2; with `sigma.lv` →
0.366. Every accuracy number below uses the corrected extraction. **Had this gone
unnoticed it would have produced a spectacular and entirely false "gllvm is inaccurate"
result.**

## Speed — median seconds

| n | T | gllvm VA | gllvm LA | VGH | VGH vs VA | VGH vs LA |
|---|---|---|---|---|---|---|
| 100 | 5 | 0.119 | 0.129 | 0.016 | 7.4× | 8.1× |
| 400 | 5 | 1.614 | 0.316 | 0.035 | 46.1× | 9.0× |
| 1000 | 5 | 15.874 | 1.054 | 0.058 | **273.7×** | 18.2× |
| 100 | 10 | 0.164 | 0.147 | 0.027 | 6.1× | 5.4× |
| 400 | 10 | 1.926 | 0.614 | 0.047 | 41.0× | 13.1× |
| 1000 | 10 | 17.226 | 2.265 | 0.078 | 220.8× | 29.0× |

## Accuracy — median relfrob(G_hat, G_true), Frobenius scale, unsquared

Rotation-invariant by construction; raw loadings are never compared.

| n | T | gllvm VA | gllvm LA | VGH |
|---|---|---|---|---|
| 100 | 5 | 0.2983 | 0.2909 | 0.2353 |
| 400 | 5 | 0.0967 | 0.0811 | 0.0833 |
| 1000 | 5 | 0.0942 | 0.0582 | 0.0401 |
| 100 | 10 | 0.1839 | 0.1839 | 0.1880 |
| 400 | 10 | 0.0825 | 0.0825 | 0.0776 |
| 1000 | 10 | 0.0343 | 0.0343 | 0.0333 |

**VGH is not trading accuracy for speed.** Its G-recovery is comparable to both gllvm
arms everywhere and better in two of six cells. That is the substantive result.

## Do not quote the 273× — read this first

1. **The gllvm VA arm is behaving oddly, and the largest ratios come from it.** gllvm's
   VA takes 15.9 s where its own LA takes 1.05 s at n = 1000. A variational method being
   15× *slower* than Laplace in the same package is not what VA is supposed to do; it
   suggests that path is hitting something pathological on this DGP (iteration count,
   starting values), not that VGH is 274× better engineered. **The defensible comparator
   is gllvm's LA arm, where the ratio is 5–29×.** Quoting the VA ratio without diagnosing
   why VA is slow would be exactly the kind of flattering artefact this audit exists to
   catch.
2. **Equal effort is NOT established.** Each package ran at its own defaults —
   convergence tolerances, `n.init`, starting values all differ. An unequal-effort timing
   is not yet a speed result.
3. **Objectives are not comparable.** VGH reports an ELBO (a lower bound); gllvm reports
   a log-likelihood. They are never tabulated against each other here, and must not be.
4. **Narrow scope:** gaussian only, q = 2, n ≤ 1000, one DGP, 3 seeds. VGH admits only
   three families, no `Psi`, no structured or spatial tiers — and **is not wired into the
   package**, so no user can currently reach it.

## What is actually supported

> On gaussian data with q = 2 and n ≤ 1000, at each package's default settings, VGH
> matches the G-recovery accuracy of `gllvm`'s VA and LA engines while running 5–29×
> faster than `gllvm`'s Laplace.

**Not supported:** "the fastest and best GLLVM algorithm in R". That needs more families,
an equal-effort protocol, larger n, and an engine users can actually call.

**Novelty, separately checked:** `gllvm` 2.0.13 does **not** automatically warm-start a
Laplace fit from a converged VA fit — so the Phase 2 hand-off is not simply reproducing
what the incumbent already does.
