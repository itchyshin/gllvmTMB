# D-43 Lens 2 — Scope review of the AGHQ claim

Reviewer: fresh D-43 panel member, lens = scope. Default verdict is NOT-DONE unless
the evidence compels otherwise. Worktree `/private/tmp/gllvmtmb-arc0-identifiability`,
branch `claude/aghq-engine-20260728`, base `main` @ `72c2e53d`. Package loaded via
`devtools::load_all()`; all numbers below were recomputed directly from
`dev/aghq-evidence/totoro-suite-inc.csv`, from re-running `dev/aghq-evidence/02-template-vs-oracle.R`
and a hand-built Gaussian-exactness check, and from executing the test suite with
`NOT_CRAN=true` (the flag `devtools::test()` sets, which the claim's own numbers require —
without it, `skip_on_cran()` fires first and the counts do not match what is claimed).

## 1. "at every sample size tested" — checked against BOTH shapes in the suite

`totoro-suite-inc.csv` has 954 rows across **two** shapes: `p=6,q=2` (474 rows) and
`p=4,q=1` (480 rows). The design comment in `totoro-suite.R` is explicit about why:
*"p=6,q=2 is a realistic JSDM; p=4,q=1 is where the runaway was worst, so both ends are
covered."* Both arms were run to completion.

**Only the p=6,q=2 arm is ever discussed in `docs/dev-log/decisions.md`.** I grepped the
full file for `p=4`, `p = 4`, `q=1`, `q = 1` — zero hits. The "fair four-arm comparison"
and "correction to the correction" entries (2026-07-28) that finally establish the
defensible sentence *"AGHQ + ridge beats Laplace at every n on both sigma and rho"* build
that table **only from p=6,q=2**. The p=4,q=1 arm — 480 fits, gathered for exactly this
generalization check per the script's own stated rationale — was never analyzed or
reported.

I ran that analysis myself, using the authors' own metric (median `|sigma_rat - 1|`,
matching how `decisions.md` computes the four-arm table, not the raw ratio which is
misleading under the known bimodal runaway):

```
p=4, q=1, |sigma_rat-1| median, runaway% = frob_rat > 2:
     n | Laplace (shipped)        | AGHQ + ridge
   100 | 0.2624 err, 20.0% runaway| 0.2417 err,  3.3% runaway
   200 | 0.1862 err,  6.7% runaway| 0.1717 err,  3.3% runaway
   400 | 0.1399 err,  3.3% runaway| 0.1065 err,  0.0% runaway
  1600 | 0.1235 err,  0.0% runaway| 0.0917 err,  0.0% runaway
```

Sigma does generalize: AGHQ+ridge beats shipped Laplace at every n in this shape too.
**But this is a check I had to run as a reviewer — it is not in the record**, and it
does not save "eliminates" (§3) or supply any rho evidence (§2). The claim's "at every
sample size tested" describes work that was only ever done for one of the two shapes
the authors themselves designed the suite to cover.

## 2. "recovers sigma AND rho better than Laplace" — rho is undefined at q=1

Confirmed directly from the CSV: for every `p=4,q=1` row, `rho_absd` and `rho_cor` are
empty/`NA` — `q=1` has no off-diagonal correlation to estimate. So the rho half of the
claim has **zero supporting evidence outside p=6,q=2**, not "weaker" evidence — none.
The claim sentence bundles "sigma AND rho" under one "at every sample size tested," which
is not a statement that can be true of rho at n where q=1 is the design, because rho is
not a quantity that exists there. The sentence needs to say "and rho (defined only where
q >= 2)," not imply a single uniform result over the whole design space.

## 3. "eliminates the divergent-fit mode" — true only for the shape actually reported

At `p=6,q=2`, AGHQ+ridge runaway is 0.0% at every n (100/200/400/1600) — "eliminates" is
literally correct there, and I reproduced it (§1 table above, second block available on
request; matches the claim's reported 0%/0%/0%/0% within rounding).

At `p=4,q=1` — the shape the authors' own script says is *"where the runaway was
worst"* — AGHQ+ridge runaway is **3.3% at n=100 and 3.3% at n=200**, reaching 0% only
from n=400. "Eliminates" is the wrong verb for the shape where the problem is worst; the
correct verb there is "sharply reduces, and eliminates by moderate n." The general,
unqualified claim ("eliminates the divergent-fit mode") overclaims by generalizing from
the one shape where it happens to be perfectly true.

## 4. "a validated integration engine" — validated on binomial only, and the automated proof of that does not currently run

The non-trivial evidence (oracle agreement, descend-ladder, totoro suite) is binomial
throughout — I confirmed this by reading `02-template-vs-oracle.R`, `totoro-suite.R`, and
`05-descend-from-large-n.R`; all three simulate via `rbinom`/`plogis`. Gaussian is an
exactness *control*, not independent validation: Laplace is exact for a gaussian
latent-linear model by construction, so any correctly-normalized rule reproduces it — the
evidence document itself says as much (`02-template-vs-oracle.R` line 2-3). I reproduced
the exactness check independently on my own toy gaussian model and got the same order of
magnitude the claim reports (+1.137e-13 at k=3 and k=9 vs Laplace, against the claim's
quoted +6.253e-13 — I could not find that exact digit string anywhere in the repo, but
the phenomenon and its magnitude both check out). So: 1 of 16 families has real
(non-trivial) evidence; the concession list already says this, correctly.

**What is new here: the automated test suite that is supposed to lock in "validated"
does not actually validate anything right now.** `tests/testthat/test-aghq-golden.R` has
5 `test_that()` blocks. Running with `NOT_CRAN=true` (required to match the claimed
"5/0, 3 skipped"):

```
test                                                                    nb  skipped
[oracle sanity] brute-force matches fine-grid quadrature                3   FALSE
[oracle sanity] plain Laplace does NOT match brute-force truth          2   FALSE
GOLDEN 1 [PLUMBING]: AGHQ k=1 reproduces Laplace objective               -  TRUE
GOLDEN 2: AGHQ at large k matches brute-force integral (q=1)             -  TRUE
GOLDEN 2 [bonus, q=2]: AGHQ at large k matches nested-integrate()        -  TRUE
```

The "5 passed" are the two **oracle sanity** checks — they test that the brute-force
truth itself is correct and that plain Laplace has a real, nonzero gap from it. They say
nothing about AGHQ. **The three tests that would actually prove AGHQ matches the oracle
— GOLDEN 1, GOLDEN 2, and the q=2 bonus — are exactly the three that are skipped**, and
I traced why: they are gated by `.golden_aghq_smoke_ok()`, which fits at `k=1` and checks
`isTRUE(fit$aghq$used)`. I called the router directly:

```
k=1  used=FALSE  reason="laplace: k = 1 is the Laplace rule; the Laplace path computes it exactly"
k=3  used=TRUE   reason="quadrature on z_B (d=1, k=3, 3 nodes); ... converged"
k=9  used=TRUE   reason="quadrature on z_B (d=1, k=9, 9 nodes); ... converged"
```

`k=1` is *defined* to route to the plain-Laplace branch rather than the quadrature
machinery (a sensible optimization — there is no quadrature to do at one node) — which
means `.golden_aghq_smoke_ok()`'s probe at `k=1` can **never** report `used=TRUE`, so the
golden tests will **always** skip, regardless of whether AGHQ is actually wired. The skip
message printed to the user — *"AGHQ kernel not fully wired end-to-end yet
(gllvmTMBcontrol(aghq=) and/or the R/fit-multi.R integration is incomplete)"* — is
therefore stale/wrong: I confirmed the kernel **is** wired and functioning correctly
through the ordinary package call at k=3, 5, 9. The smoke test has a bug, not the
package — but the practical consequence is the same: **nothing in the automated,
regression-tested suite currently checks that AGHQ matches a brute-force oracle.** That
check exists only as a manually-run script in `dev/aghq-evidence/`, which nothing
prevents from silently regressing. "A validated ... engine" overstates this: it is
validated by hand, once, by the same person making the claim, on one family, and the
automated proof of that is currently disabled by an unrelated diagnostic bug.

## 5. "no existing user's results move" — true for the AGHQ machinery, not for the whole branch

`aghq` defaults to `FALSE` (`R/gllvmTMB.R` control constructor; asserted in
`test-aghq-surface.R:221`), and the new C++ data/quadrature blocks are gated by
`if (use_aghq == 1)` / `... && use_aghq == 0` — I read the diff against `main` and this
guard is real and structural for the B-tier random-effect machinery.

But the same diff (same branch, same PR-sized changeset) contains **two unconditional
changes to shared likelihood code**, neither gated by `use_aghq`:

- `diag_B_skip` / `diag_W_skip`: a pinned trait (single-trial Bernoulli / ordinal_probit
  / multinomial, Psi or OLRE pinned off by the identifiability gate) used to add a large
  positive constant (`dnorm(0, 0, ~1e-6, log=TRUE)`) to `nll` regardless of engine; that
  constant is now skipped. This is a real, disclosed bug fix (commits `59a83c5b`,
  `409b68e6`, message `fix(likelihood): ... no longer inject a positive constant into
  nll`) — it does not move point estimates (additive constants do not change an
  optimum) but it **does** move `logLik()`/AIC/BIC for any existing default-engine model
  with a pinned trait. It appears to be pre-existing, already-tracked work bundled into
  this branch rather than something the AGHQ claim is trying to hide, but the claim
  sentence as written ("no existing user's results move") is a statement about the
  shipped diff, and that statement is not true of this diff.
- The `ordinal_probit` cell-probability computation was rewritten from
  `p_k = pnorm(upper)-pnorm(lower)` (floored at `1e-12`, then logged) to an
  entirely-log-scale form (`gll_log_pnorm`/`gll_log_pnorm_diff`), applied unconditionally
  to every `ordinal_probit` fit, Laplace included. I benchmarked both formulas in R over
  200,000 random (eta, cutpoint) draws restricted to the non-floored, "typical" region:
  the two formulas agree to 1.1e-16 (median) and 1.7e-10 (worst case) — floating-point
  noise, not a substantive change, consistent with the code comment's own claim that the
  old floor was *"harmless under Laplace."* Not a real finding on its own, but it is
  another unconditional change to default-engine output riding in the same branch as the
  AGHQ work, undisclosed in the claim.

Net: the claim is correct about the part that matters most (the shipped default is
`aghq=FALSE` and the quadrature/adaptation code is a structural no-op then) but incorrect
as a claim about "no existing user's results move" for the branch as a whole, because
two unrelated changes in the same diff do move existing default-engine output (one
materially, for `logLik`/AIC of pinned-trait models; one at machine-precision noise, for
`ordinal_probit`).

## 6. Under- or over-claimed?

Nothing found is under-claimed net of the above — if anything the sigma-generalizes-to-
p=4,q=1 finding (§1) is unpublished evidence that would have *strengthened* the claim had
anyone looked, but it is offset by the "eliminates" failure in that same unexamined
shape (§3). One more thing worth surfacing: `dev/aghq-evidence/05-descend-RESULT.txt`
(T=4, q=1, unridged) shows unridged AGHQ's own **median** ratio is *further* from 1.0
than unridged Laplace's at n=100, 200, and 800 (e.g. n=200: Laplace median 0.836 vs AGHQ
median 1.967) — quadrature alone, without the ridge, can be worse than Laplace alone in
this intermediate-n range. The claim's own bullet about this file only cites the n=3200
endpoint and the "Laplace flat at 0.79-0.88" observation (both accurate), silently
passing over the fact that AGHQ-without-ridge is not monotonically better across the
ladder it ran. This does not undermine the shipped claim (which is about AGHQ+ridge, not
raw AGHQ) but the two-component "ridge fixes small-n, quadrature fixes large-n" story
would be more complete if it said outright that raw AGHQ can be worse than raw Laplace at
moderate n, not just that raw Laplace is "flat."

## Corrected claim sentence

> gllvmTMB has gained AGHQ as an opt-in integration engine. Its correctness is
> demonstrated by Gaussian exactness (k=1 identical to Laplace to machine precision, k=3
> and k=9 agreeing to ~1e-13) and by agreement with a brute-force `stats::integrate()`
> oracle on a toy binomial model — evidence that is currently produced only by manually
> run scripts in `dev/aghq-evidence/`, since the automated golden-accuracy tests
> (`test-aghq-golden.R`) self-skip due to a smoke-test bug and do not currently exercise
> this claim in CI. On the one realistic binomial two-factor design tested (p=6, q=2,
> 30 seeds/n), a weakly-informative ridge on the loadings (on by default when AGHQ is on)
> makes AGHQ recover the latent SD and the latent correlation better than the shipped
> Laplace default at every n from 100 to 1600, and eliminates the divergent-fit mode
> there entirely. A second design (p=4, q=1, single-factor, no correlation to measure)
> was run to completion — 480 fits — but never analyzed: on reanalysis, the sigma result
> generalizes, but the divergent-fit mode is only sharply reduced, not eliminated, at
> n <= 200 in that shape. 14 of the package's 16 families, including both DEFAULT
> `latent()` structures where the between-unit Psi block is not auto-pinned, remain
> completely unexercised under quadrature. Laplace's default (`aghq = FALSE`) fit path is
> structurally unaffected for the random-effects machinery itself, but the same branch
> also carries two unconditional changes to shared likelihood code — a pinned-trait
> `logLik`/AIC fix and a machine-precision-level `ordinal_probit` rewrite — that are
> unrelated to AGHQ but do touch existing default-engine output.

VERDICT: NOT-DONE

The claim as stated generalizes past what was measured in three separate, independently
checkable ways: (1) "at every sample size tested" and "eliminates the divergent-fit mode"
are stated as unqualified facts about the method, but a second shape the authors
themselves designed into the same experiment (480 completed fits) was never analyzed, and
on my own analysis of it, "eliminates" is false at two of its four sample sizes; (2) "a
validated ... engine" is supported only by manually-run scripts, because the automated
golden test suite meant to encode that validation currently skips all three of its
accuracy-proving assertions — not for a reason related to AGHQ's correctness, but because
of a bug in the smoke test that gates them, so the "validated" claim currently has no
regression protection at all; (3) "no existing user's results move" is a claim about the
whole shipped branch, and the branch contains an unconditional change to shared
likelihood code (the pinned-trait constant-offset fix) that does move `logLik`/AIC for
existing default-engine users. None of these are fatal to the underlying method — the
core quadrature mechanism checks out on every direct test I ran — but the sentence under
review claims more breadth, more automated proof, and more isolation from other changes
than the evidence in this worktree currently supports.

The smallest piece of evidence that would change this verdict: (a) fix
`.golden_aghq_smoke_ok()` to probe at a real quadrature k (e.g. k=3) instead of k=1, and
show GOLDEN 1/2/2-bonus actually pass in CI rather than self-skip; and (b) add the
p=4,q=1 numbers to `decisions.md` with the "eliminates" language corrected to match. Both
are small, mechanical, and already fully computable from data and code already in this
worktree.
