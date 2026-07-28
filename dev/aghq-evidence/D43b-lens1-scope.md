# D-43(b) Lens: SCOPE — does the claim generalise beyond what was measured?

Fresh reviewer, no prior involvement in this arc. Worktree
`/private/tmp/gllvmtmb-arc0-identifiability`, branch `claude/aghq-engine-20260728`
(PR #801, open, not merged). Default verdict NOT-DONE; only evidence below moves me.
Everything is either a number I recomputed myself from the checked-in CSVs, a line I
read in the checked-in code, or a fit I ran myself against this checkout.

---

## Summary verdict up front

**VERDICT: NOT-DONE.** The single largest problem is structural, not statistical: I
ran a **DEFAULT** poisson `latent()` model (the current, non-deprecated grammar) through
`gllvmTMBcontrol(aghq = 9)` on this checkout and AGHQ silently declined to activate
(`aghq$used = FALSE`, `aghq$reason = "laplace: Stage 1a requires z_B as the only random
block (random = z_B, s_B)"`) — no warning, only a field a caller has to know to inspect.
Every one of the 7550 + 3199 fits in this arc's evidence was run under `unique = FALSE`,
the soft-deprecated loadings-only compatibility keyword. So the claim "gllvmTMB has
gained AGHQ as an opt-in integration engine" is true only for a slice of the model space
that the package's own current default grammar does not produce. That is a scope
statement the claim under review does not make anywhere. Independently, claim (3)'s
"reaches nominal coverage at every n tested" does not survive the project's own
certification bar (2×MCSE lower band ≥ 0.95, the B3b precedent) — confirmed both from
the authors' own already-honest paragraph in `decisions.md` and from my own
recomputation off the raw CSV, which agree once the coverage denominator is computed the
way the script documents (see below — my first pass disagreed with `decisions.md` and
the discrepancy resolved to a coding difference on my end, reported for the record since
it nearly became a false "cannot reproduce" finding).

---

## 1. "BINARY-SPECIFIC" — licensed by 2 families, and by one DGP regime within each

`21-wide-factorial.R:57-68` (`mk()`): the poisson intercept is **fixed** at
`b <- rnorm(p, 0.8, 0.3)` for the entire 7550-fit campaign — never varied the way
`lam_sd` was varied for the loadings. Mean count is `exp(0.8) ≈ 2.2`, capped at
`exp(6) ≈ 403` (`pmin(eta, 6)`). This is a moderate-to-healthy count regime. Binomial's
intercept (`rnorm(p, 0.3, 0.4)`) is likewise fixed. Recomputing the headline numbers
directly (median `frob_rat`, `q=1, lam_sd=1, n=1600, conv==0`):

```
              T=2     T=4     T=6     T=12
binomial     0.653   0.824   0.887   0.962   (matches decisions.md exactly)
poisson      1.006   1.006   0.995   0.997   (matches decisions.md exactly)
```

I confirm these numbers reproduce cleanly (they are computed on `frob_rat`, the
Frobenius-norm loadings-recovery ratio, not `sigma_rat` — worth naming since claim (1)
calls this "latent-covariance bias" and claims (2)/(3) measure Sigma-diagonal Wald
coverage; these are related but not the same quantity, and the claim conflates them
under one word, "bias"/"Sigma", without saying so).

**The mechanism, not just the label, is what's licensed.** The claim states a fact about
two families. The DGP that produced "poisson has ZERO bias" only ever tested poisson at
one intercept regime (mean count ≈ 2.2–2.7 depending on loading draw). A low-count
Poisson regime (mean count near 0–1) has a conditional log-likelihood that is also far
from quadratic — the same non-Gaussian-integrand mechanism the claim invokes for binary.
That regime was never run. So "ZERO at every T for poisson" is licensed only as "zero at
every T for poisson, in the specific moderate-count regime tested" — the mechanism-level
generalization ("Laplace's bias tracks per-observation Fisher information / departure
from Gaussianity, and binary is the extreme low-information case") is the right
statement and is *consistent* with what was measured, but the claim as given states the
narrower family-level fact ("BINARY-SPECIFIC... ZERO... for poisson") as if it were
already established across the family, when only one count regime was tried.

**A second, unflagged problem undercuts the poisson control's strength as stated.**
`aghq_used` is TRUE on 100% of poisson AGHQ fits (true, matches the claim), but the
*optimizer's own convergence code* tells a different story. Recomputed from
`21-wide-inc.csv`, rate of `conv == 1` (non-clean convergence) by family × arm, all
cells pooled:

```
              aghq   aghq_ridge   laplace   laplace_ridge
binomial      0.403     0.465      0.000        0.002
poisson       0.945     0.902      0.000        0.000
```

At the specific cell used for the headline poisson numbers (`q=1, lam_sd=1, n=1600`),
poisson+aghq shows `conv==1` on 14/15 (T=2), 15/15 (T=4), 15/15 (T=6), 15/15 (T=12)
fits — i.e. the "correctness control" that claim (1) calls "a stronger correctness
control than Gaussian exactness" is built almost entirely on fits the optimizer itself
flags as not cleanly converged, while the poisson Laplace baseline it's compared against
is 100% `conv==0`. `decisions.md`'s only caveat on `conv` is "`conv` is uninformative on
ridge arms until the MAP/ML gradient defect is fixed" — that caveat does not cover the
plain `aghq` (no-ridge) arm, and does not cover poisson at all. This doesn't necessarily
mean the frob_rat numbers are wrong (they are stable near 1.0 across all 15 seeds at
each T), but it means the claimed strength of the control ("fully active... correctly
changes the answer") rests on an unexamined asymmetry the claim doesn't mention.

## 2. "reaches NOMINAL coverage at every n tested" — recomputed against the B3b rule

Recomputing Wald coverage from `24-coverage-inc.csv` directly. **First pass, and a
correction for the record:** filtering only on `status == "ok"` and treating any
individual `(s,t)` entry with non-finite `se`/`lo`/`hi` as non-covering gave numbers
6–7pp *below* `decisions.md`'s (e.g. `aghq_ridge` diag n=100: 0.944 vs claimed 0.961).
That discrepancy resolves: the script's documented convention
(`24-coverage-cell.R:34-37`, "coverage is reported CONDITIONAL on an available
interval... counting a refused interval as non-covering would conflate a fail-closed
refusal with a wrong answer") means non-finite *individual entries* must be **excluded**
from the coverage denominator, not counted against it (this is a finer grain than the
per-fit `status` field — a fit can return `status == "ok"` with some entries still
non-finite). Recomputing with that exclusion reproduces `decisions.md`'s numbers almost
exactly (diag: 0.9611/0.9567/0.9492/0.9505 vs claimed 0.961/0.957/0.949/0.951; offdiag:
0.9589/0.9624/0.9592/0.9519 vs claimed 0.959/0.962/0.959/0.952). I record the false
start because it is exactly the kind of "I couldn't reproduce it" claim a scope review
should not make without checking its own arithmetic against the source's stated method
first — and because it surfaces the availability rate below, which the point-estimate
table doesn't carry.

**Applying the project's own 2×MCSE-lower-band ≥ 0.95 rule** (per-seed proportion within
available entries, then mean/SD across the 200 seeds, `n=200` throughout):

```
aghq_ridge  DIAGONAL              lo(mean-2*MCSE)   clears?
  n=100   mean 0.9611  mcse 0.0056   0.9499          NO (misses by 0.0001)
  n=200   mean 0.9567  mcse 0.0057   0.9453          NO
  n=400   mean 0.9492  mcse 0.0074   0.9344          NO
  n=1600  mean 0.9505  mcse 0.0075   0.9356          NO

aghq_ridge  OFF-DIAGONAL
  n=100   mean 0.9589  mcse 0.0044   0.9502          YES
  n=200   mean 0.9624  mcse 0.0040   0.9544          YES
  n=400   mean 0.9592  mcse 0.0045   0.9501          YES
  n=1600  mean 0.9519  mcse 0.0065   0.9390          NO
```

3 of 8 cells clear (offdiag n=100/200/400); the diagonal clears **nowhere**, including
n=100, which lands one ten-thousandth below 0.95 (0.9499) — the same kind of margin the
project withheld a certificate over on 2026-07-19 at 0.9486. `decisions.md`'s own prose
("clears at diag n=100 (0.950) and offdiag n=100/200/400... misses at diag
n=200/400/1600 and offdiag n=1600") already says essentially this — 4 of 8 by their
count, 3 of 8 by mine (the diag n=100 boundary case is a rounding call either way). This
is recorded honestly one paragraph down in `decisions.md`, but **claim (3) as stated to
me carries none of it** — "reaches NOMINAL coverage at every n tested" is the point-
estimate framing with the certification-relevant qualifier dropped. Under this project's
own precedent for what "nominal" is allowed to mean when a claim is being certified,
this does not survive.

## 3. Coverage cell generalises across a much narrower space than point-recovery

`24-coverage-cell.R`'s `mk()` (line ~46-51) fixes `P=6, Q=2, LAM=1.0`, binomial only —
one shape, one family, one loading scale, out of the `T ∈ {2,4,6,12}`,
`lam_sd ∈ {0.5,1,3}`, `q ∈ {1,2}`, `fam ∈ {binomial, poisson}` space the point-recovery
factorial actually explored. Two direct consequences, both unaddressed by the claim as
given:

- **T is fixed at 6.** Claim (1) shows Laplace's point-bias falls from 0.347 (T=2) to
  0.038 (T=12) — a nearly 10-fold range. The coverage story (default under-covers,
  ridge/AGHQ+ridge restores it) is measured at exactly one point in that range. Whether
  the default under-coverage is severe at T=12 (where point-bias is already small) or
  whether the ridge is even needed there is not evidenced.
- **Family is fixed at binomial**, despite poisson being the more interesting case
  *because* claim (1) says its point-bias is zero. If Laplace's poisson point estimate
  is already unbiased, does its interval already have nominal Wald coverage, with no
  AGHQ/ridge needed? That would be the natural next question the campaign's own logic
  raises, and it is untested — the coverage claim (2)/(3) is stated in generic terms
  ("the SHIPPED DEFAULT under-covers") that a reader would not naturally restrict to
  "for binomial only," yet that is all that was run.

`lam_sd` is also fixed at 1.0 for the coverage cell — the same "single most favourable
configuration a shrinkage estimator can be given" objection D-43 lens 3 raised against
the point-recovery ridge study before this arc widened the *point* study to
`lam_sd ∈ {0.5,1,3}`. The coverage study was never given the same widening.

## 4. The largest regime where none of this evidence applies

Ran directly on this checkout (`/tmp/eligibility_test.R`, poisson, n=40, p=4, q=1,
**default** `latent(1 | site, d = 1)` — no `unique = FALSE`):

```
aghq$used: FALSE
aghq$reason: laplace: Stage 1a requires z_B as the only random block (random = z_B, s_B)
```

Confirmed against the code: `src/gllvmTMB.cpp:2480` hard-errors Stage 1a on `s_B`
(`"use_aghq Stage 1a is loadings-only (no s_B)"`), and `R/fit-multi.R:5063`
(`"Stage 1a requires z_B as the only random block"`) is the R-side gate that routes
around that hard error by silently falling back to Laplace — **with no warning**;
`cli_warn` only fires when AGHQ was attempted and then errored
(`R/fit-multi.R:5469`), not when it was never eligible. The only trace is
`fit$aghq$reason`, a field nothing in the current API surfaces to a user who didn't ask
for it.

The auto-Psi-skip that lets *binary* work with package defaults
(`R/fit-multi.R:1085`, `1083-1095`, `4683-4728`) fires only per-trait, and only for
**single-trial** Bernoulli (`n_trials == 1`) or multinomial — not multi-trial
binomial/proportion data, not Gaussian, not NB, not Beta, not Gamma, not Poisson. Given
that ordinary `latent()` has carried Psi by default since gllvmTMB 0.2.0 (confirmed live
by the routine deprecation warning my test run also printed), the regime where a user
gets AGHQ by just turning it on is: **single-trial-binary or multinomial traits under
default `latent()`, or any family under the explicit, soft-deprecated
`unique = FALSE` loadings-only compatibility syntax.** Every fit in both evidence
campaigns (7550 + 3199) was run under the latter (`21-wide-factorial.R:73`,
`24-coverage-cell.R` `mk()`), stated candidly in `decisions.md`'s own "SCOPE" paragraph
for the 21-run but not carried into the claim under review. For any other default
model — replicated-count Poisson/NB/Gaussian/Beta/Gamma with the modern default
`latent()`, or multi-trial binomial — **requesting AGHQ is currently a silent no-op**.
That is the largest regime, and it is not a narrow corner: it is the package's own
current default grammar for every family except single-trial binary/multinomial.

The claim under review states this AGHQ engine is "OPT-IN" with "nothing... exported."
Technically true, but a reader would reasonably take "opt-in" to mean "the user gets
what they opted into." Here, for most of the model space, opting in silently gets you
what you already had.

## 5. Anything under-claimed?

Not materially. `decisions.md`'s "routing map" table (poisson→Laplace always; binomial
small-T/large-n→AGHQ+ridge; binomial small-n→ridge is the lever) is a more honest and
more useful statement than the claim under review, and is *narrower*, not broader, than
what's claimed — so this cuts the same direction as the findings above, not against
them.

---

## What I could not exercise

- Did not re-run any part of the 7550/3199-fit campaigns myself (cost); relied on
  recomputation from the checked-in CSVs plus one small live confirmatory fit for the
  eligibility-gate finding.
- Did not check whether `aghq = "auto"` (if such a mode exists) would route around the
  eligibility gate differently — the claim as given describes only the manual `aghq = 9`
  route, so this is out of scope for judging the claim as stated.
- Did not investigate the `conv == 1` asymmetry (poisson AGHQ) further than confirming
  its magnitude; whether it reflects a real outer-loop convergence problem for poisson or
  a benign tolerance mismatch is unresolved.

## SMALLEST EVIDENCE THAT WOULD CHANGE MY VERDICT

1. A single sentence added to the claim (or its immediate surrounding documentation)
   stating the eligibility scope plainly: AGHQ activates only under `unique = FALSE` (or
   default single-trial-binary/multinomial), and silently falls back to Laplace
   otherwise — with a `cli_warn`/`cli_inform` added so a user who requests `aghq=` on an
   ineligible model is told, not left to introspect `fit$aghq$reason`. That alone would
   resolve item 4, the largest gap.
2. Either (a) reword claim (3) to state the point estimate and the certification result
   together ("reaches ~0.95 as a point estimate; clears the project's own 2×MCSE band in
   3 of 8 diag/offdiag×n cells, not all"), or (b) more seeds to tighten the diag n=100
   boundary case and a wider coverage sweep (at least one more T and the poisson family)
   before "reaches nominal... at every n" is stated as a scope-general fact.
3. One poisson coverage cell (even 50-100 seeds) — since claim (1)'s own logic predicts
   poisson needs no correction, a poisson coverage result would either confirm that
   prediction cheaply or overturn it, and right now it's simply missing.

VERDICT: NOT-DONE
