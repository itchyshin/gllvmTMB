# The shipped-engine truth start — the AGHQ runaway at n = 100 is an optimiser failure

**2026-07-31 · Claude (Fable 5) · issue #843 · first slice of the AGHQ estimator-validation lane**
**Compute: local, 4 cores, ~25 min total. Results LOCAL (D-50). No package behaviour changed.**

---

## The headline

**On the 16 of 40 seeds where the shipped AGHQ arm ran away catastrophically
(‖Λ̂‖/‖Λ‖ > 5), the runaway is NOT the maximum-likelihood solution. It is an optimiser
failure — unanimously, 16/16.**

Started at the true parameters, the *same shipped engine* reaches a **strictly better
objective** on every one of those seeds — by **1.14 to 12.94 nll** (median 4.70) — and a
far better estimate (median ‖Λ̂‖/‖Λ‖ **16.23 → 2.12**).

**And the fix is already in the code, switched off.** The truth-free alternative start the
engine builds and then discards under `aghq_ridge = Inf` recovers the lost optimum on
**16/16** of those seeds (median gap closed **1.00**), taking catastrophic fits from
**16/40 to 1/40** and matching the truth start's objective without using the truth.

This **refutes, on the shipped engine, the conclusion that the withdrawn justification
rested on.** The in-source comment at `R/fit-multi.R:5314-5318` says:

> *"an investigation of 40 seeds showed the runaway IS the maximum-likelihood solution —
> refitting from the TRUE parameters ties the objective in 40/40 and then walks back out"*

That investigation (`09C-truthstart.csv`) ran on `dev/aghq-r-reference.R`, which
`decisions.md:1706-1709` invalidated as not modelling the shipped AGHQ arm. Re-run through
`gllvmTMB()` itself, the objective ties in **13/40, not 40/40** — and in **0/16** of the
catastrophic cases. The reference and the engine disagree exactly where it matters, which
is precisely what the invalidation predicted.

---

## What was run

Exactly the `aghq` arm of `18-shipped-engine-campaign.R`, so the numbers are directly
comparable to its baseline: binomial, **n = 100, p = 6, q = 2, lam_sd = 1.0**, `aghq = 9`,
`aghq_ridge = Inf`, grammar `latent(1 | site, d = 2, unique = FALSE)` (AGHQ Stage 1a is
loadings-only, so the default grammar is ineligible — audit §5a). Seeds 2001:2040.

| arm | AGHQ's starting point |
|---|---|
| `default` | the Laplace optimum — **the shipped behaviour** |
| `truthstart` | the **true** parameters |
| `altstart` | the **truth-free** alternative start the engine already builds but never uses under `aghq_ridge = Inf` |

Everything else — template, Laplace stage, adaptation loop, convergence test, continuation
schedule — is the shipped code. The only change is a diagnostic hook
(`control$aghq_start_par`, `R/fit-multi.R`) that replaces AGHQ's start. It is deliberately
**not** a `gllvmTMBcontrol()` argument, so it is unreachable for users and changes no
shipped behaviour.

Script: `dev/aghq-evidence/22-truthstart-shipped.R`, `23-altstart-shipped.R`.
Data: `22-truthstart.csv`, `23-altstart.csv`.

### Pre-flight — the three things that could have silently corrupted this

Λ is identified only up to a q×q rotation, and `theta_rr_B` holds a *lower-triangular* Λ,
so "the truth" cannot be written into the engine directly — it must first be rotated. Each
step carries an executable check, run before any campaign fit:

| check | observed |
|---|---|
| the LQ rotation preserves Σ = ΛΛ' exactly | max\|ΔΣ\| = 3.55e-15 |
| the rotated Λ really is lower-triangular | max\|upper\| = 0 |
| **the C++ template round-trips my packing** — write the packed vector in, read `Lambda_B` back out of the engine's own report | max\|ΔΛ\| = **0** |

The third is the load-bearing one: it is the *template*, not my arithmetic, that defines
the map.

---

## The result

### Pre-registered decision rule → **B2, START PROBLEM**

| branch | pre-registered meaning | seeds |
|---|---|---|
| **B2** | truth start finds a strictly **better** objective → the shipped single start loses a better optimum | **20 / 40** |
| B1 | truth start walks away and only **ties** → the runaway is genuinely the argmin | 13 / 40 |
| B3 | truth start **stays** at truth and ties → flat / not identified | 0 / 40 |
| — | truth start strictly **worse** than default | 7 / 40 |

P(truth start strictly better) = **0.500**, MCSE 0.079, 95% CI **0.345–0.655** — decisively
non-zero.

### And the split by severity is clean, not mixed

| default ‖Λ̂‖/‖Λ‖ | n | truth start better | median Δobj | median frob: default → truth start |
|---|---|---|---|---|
| ok (≤ 2) | 14 | 1/14 | −0.000 | 1.78 → 1.78 |
| runaway (2–5) | 10 | 3/10 | +0.000 | 2.47 → 2.41 |
| **catastrophic (> 5)** | **16** | **16/16** | **+4.699** | **16.23 → 2.12** |

Where the default fit is fine, the two arms agree and the objective is genuinely flat —
the start does not matter. **Where the default blows up, the start is the whole story, and
it fails unanimously.** No seed in the catastrophic group ties.

The worst cases are the clearest: seed 2018 goes from ‖Λ̂‖/‖Λ‖ = 15.16 to 1.30 while
*improving* the objective by 12.94 nll; seed 2004 from 35.99 to 3.24.

### A caveat on my own instrument: the truth start is not a global optimiser either

On 7/40 seeds the truth start reached a **worse** objective than the default. Five of those
are within tie-noise (Δ ≤ 0.07 nll, i.e. the flatness the audit already measured), but two
are real — seed 2022 by 1.19 nll and seed 2005 by 0.16 nll — and on both of those the
*better* objective belongs to the *worse* Λ̂. Two things follow, and both matter:

- **Neither start finds the argmin reliably.** The truth start wins enormously where the
  default collapses; the default wins slightly on two seeds. So the fix is not "start at a
  better point" but **genuine multi-start: run several and keep the better final
  objective.**
- **There is a second, independent failure mode.** On those two seeds the AGHQ objective
  genuinely prefers a point further from the truth — that is estimator bias, not optimiser
  failure. It is a weak signal (2/40) and is reported as such, **not** as a finding. It does
  mean the two failure modes coexist in one cell and must not be conflated.

---

## The fix already exists in the code, and it is switched off

A truth start is not a fix — users do not have the truth. So the question that actually
decides #843 is whether the **truth-free** alternative start the engine *already builds*
(`R/fit-multi.R:5296-5313`: loadings flat at 0.3, intercepts from the empirical logit)
recovers that optimum. Under `aghq_ridge = Inf` it is built and then never used, because
the selection at `:5321` is gated on a finite τ.

Injected as AGHQ's start and run to convergence (`23-altstart-shipped.R`), on the 16
catastrophic seeds:

| | result |
|---|---|
| altstart strictly better than default | **16 / 16** |
| median gap closed toward the truth start | **1.00** |
| gap closed ≥ 0.8 | **16 / 16** |
| median ‖Λ̂‖/‖Λ‖ | default 16.23 → **altstart 2.30** (truth start 2.12) |

On three seeds the gap closed *exceeds* 1.00 (1.07, 1.15, 1.01) — the truth-free start
found a **better** objective than the truth start itself.

### The implementable rule, measured

The altstart is better on 24/40 but **worse on 6/40**, so the rule is not "always use it".
It is ordinary multi-start: **run both starts to convergence and keep the better final
objective** — which costs one extra adaptation run and cannot lose by construction. Across
all 40 seeds:

| arm | median ‖Λ̂‖/‖Λ‖ | runaway (>2) | catastrophic (>5) | median obj |
|---|---|---|---|---|
| `default` (shipped) | 2.517 | 65% | **40%** | 384.592 |
| `altstart` alone | 2.107 | 57% | 2% | 381.465 |
| **best-of-both (proposed fix)** | **2.047** | **52%** | **2%** | **381.433** |
| `truthstart` (not available to users) | 1.934 | 48% | 0% | 381.434 |

**The proposed fix reaches the truth start's objective without using the truth** (381.433 vs
381.434). Catastrophic fits fall **16/40 → 1/40**; 84.4 nll is recovered in total.

Note what does *not* move much: the runaway fraction at the 2× threshold only goes 65% → 52%,
and the truth start itself only reaches 48%. So multi-start fixes the **catastrophic**
failures, and the residual moderate runaway is a separate matter — plausibly the genuine
small-n bias, which is what the ridge addresses (#847) and what this lane's main campaign
must measure.

**This is a recommendation, not a change.** Ungating the selection alters fitted results for
every `aghq_ridge = Inf` fit, which is a behaviour change and the maintainer's call. This
lane produces evidence; it does not flip a default.

---

## What this means for the evidence base

`aghq_ridge = Inf` **is** the `aghq` arm of every campaign in `dev/aghq-evidence/`. So:

1. **The headline "AGHQ alone is worse at small n" is substantially an optimiser artefact.**
   The n = 100 baseline (`18-shipped.csv`) reports the `aghq` arm at median frob 3.401 and
   73% runaway. A large share of that is a start failure, not a property of the estimator.
   The audit's §7 item 2 — *"whether the n=100/n=1600 flip is statistics or an optimiser
   artifact"* — now has an answer for the small-n end: **at least partly an artefact.**
2. **The `Laplace vs AGHQ` small-n comparison cannot stand as measured.** It compares a
   Laplace arm at its optimum against an AGHQ arm that is demonstrably not at its own.
3. **The mechanism story in audit §3 is not wrong, but it is not what was measured.** The
   ‖Λ‖-linear implicit-penalty account is a statement about F(θ) at a given θ; the runaway
   fractions are a statement about where the optimiser lands. Those are now known to be
   different questions for this cell.

**Not established by this slice:** anything at n ≥ 400, any other family, any statement
about the AGHQ *estimator's* bias once it is properly optimised, and anything on the
default grammar. This slice says where the optimiser lands, not whether the argmin is good.

---

## Two defects found on the way

### N1 — `aghq_multistart` is unreachable, and it mislabels the flatness evidence

`R/fit-multi.R:5308` reads `control$aghq_multistart`, and `:5293` documents it
(*"Set control$aghq_multistart = FALSE to restore the single warm start"*). It is **not a
formal argument of `gllvmTMBcontrol()` and not in its returned list**, so `...` discards it.
Verified:

```
gllvmTMBcontrol(aghq = 9, aghq_ridge = Inf, aghq_multistart = TRUE)
#> Warning: Extra arguments to `gllvmTMBcontrol()` are ignored in this version.
#> control$aghq_multistart  ->  NULL
```

This is the **same class** as D2/#844 (dead `auto` k-ladder) and the same class the comment
at `R/gllvmTMB.R:1286` says already bit six other AGHQ fields.

**The consequence is not cosmetic.** `dev/aghq-evidence/19-warmstart-vs-flatness.R:75,77`
passes `aghq_multistart = TRUE` **through the constructor**, where it is discarded, to build
an arm it labels:

> *"COLD: multistart on, so AGHQ is not handed the single Laplace optimum. **This is the
> discriminating arm.**"*

AGHQ **is** still handed a single Laplace optimum in that arm (the best of `n_init = 5`
restarts). The arm varies the *Laplace* start, not the AGHQ start. Script 19 is the source
of the flatness numbers cited in the audit, in #843, and in the shipped source comment at
`R/fit-multi.R:4983-4988`. Its results are still informative about start sensitivity; its
label and the inference drawn from it are wrong.

### N2 — the table justifying τ = 2 in the shipped source is from the invalidated instrument, and its direction is contradicted

`R/fit-multi.R:4997-5010` carries a `MEASURED (Totoro, 954 fits, 30 seeds/cell, p=6 q=2
binomial)` table as the justification for the ridge's τ = 2, ending:

> *"Note also that LAPLACE runs away MORE than AGHQ here (50% vs 13%), not less."*

`decisions.md:1625` names the 954-fit Totoro suite as one of the scripts that sources
`dev/aghq-r-reference.R`, and `decisions.md:1706-1709` supersedes every AGHQ comparative
number derived from it. The shipped engine measured the **opposite direction** for the same
shape (`18-shipped.csv`, n = 100, p = 6, q = 2, binomial): **laplace 47% runaway, aghq 73%.**

So a maintainer reading the shipped source is told AGHQ runs away *less* than Laplace, on
evidence the repo has withdrawn, contradicted by the shipped-engine campaign. This does not
by itself make τ = 2 wrong — but its stated justification is not usable, which is the same
shape of problem as D1 and is directly relevant to #847.

---

## Recommended next steps

1. **Do not cite any "AGHQ alone" small-n number** from `dev/aghq-evidence/` without the
   single-start caveat. That includes the 73%/47% headline in #842, #843 and the audit.
2. 🔴 **Maintainer's call — ungate the start selection under `aghq_ridge = Inf`.** The
   evidence above says the fix is available, truth-free, already written, and worth
   16/40 → 1/40 catastrophic fits. The implementable form is "run both starts to
   convergence, keep the better final objective", **not** the current "select on the
   objective at the start point" (which is a weak proxy and is why the unpenalised case was
   thought unfixable). This changes fitted results for every `aghq_ridge = Inf` fit, so it
   is not something this lane does on its own.
3. **Correct the two in-source comments** (N1's label in script 19; N2's table provenance in
   `R/fit-multi.R`). Neither changes behaviour; both currently mislead.
4. **Then, and only then, re-run the affected arms.** Re-running before the start rule is
   fixed would regenerate contaminated numbers.

🔴 **No public claim from this slice.** It changes no package behaviour and no user-facing
document. "AGHQ is better/worse" remains unestablished; this narrows *why* the existing
evidence cannot answer it.
