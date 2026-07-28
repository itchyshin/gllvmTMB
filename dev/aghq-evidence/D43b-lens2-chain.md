# D-43b lens: THE EVIDENCE CHAIN

Reviewer: fresh, D-43 completion panel. Default verdict NOT-DONE; only evidence moves me.
Worktree: `/private/tmp/gllvmtmb-arc0-identifiability`, branch `claude/aghq-engine-20260728`
(PR #801, unmerged). All numbers below were recomputed directly from the checked-in CSVs
with fresh R code (see recompute scripts referenced inline); none are copy-pasted from
`decisions.md` or the evidence `.md` files without independent recheck.

## 1. Recomputation of every headline number

### Claim (1) — O(1/T) binary-specific bias + poisson null

Source: `dev/aghq-evidence/21-wide-inc.csv` (7556 rows, 6 `failed==TRUE` → **7550 successful
fits**, matching the claim's fit count exactly).

Filter: `fam=="binomial", q==1, lam_sd==1, n==1600, arm=="laplace"`, median `frob_rat`
(`||Lambda_hat||/||Lambda||`) by `p` (T):

```
T=2: 0.6529  T=4: 0.8237  T=6: 0.8868  T=12: 0.9617
bias (1 - median): 0.347 / 0.176 / 0.113 / 0.038     <- EXACT MATCH to claim
```

Poisson, same filter, `laplace` vs `aghq_ridge`:

```
laplace:    1.0057 / 1.0063 / 0.9952 / 0.9967
aghq_ridge: 1.0120 / 1.0040 / 0.9952 / 0.9967
correction: +0.006 / -0.002 /  0.000 /  0.000        <- EXACT MATCH to claim
```

`aghq_used` on the poisson `aghq_ridge`/`aghq` cells at this filter, and across the ENTIRE
21-wide campaign (all shapes/n/lam_sd, both families, both AGHQ arms): **100%**, confirmed
by direct tabulation, not just the cited slice. This is a real, load-bearing check — I
independently verified the "fully active" qualifier isn't cherry-picked to one T/n cell.

**Reproduced exactly, all four sub-numbers, both families, plus the 100% aghq_used claim.**

### Claim (2) — shipped default under-covers, worse as n grows

Source: `dev/aghq-evidence/24-coverage-inc.csv` (67179 rows = 3199 fits × 21 Sigma entries
per fit exactly — 3199 matches the claim's fit count exactly, and every group has exactly
21 rows, so there is no silent row-dropping).

`arm=="laplace"`, `part=="diag"`, per-seed coverage proportion then mean across seeds:

```
n=100: 0.776   n=200: 0.861   n=400: 0.825   n=1600: 0.664      <- EXACT MATCH to claim
```

**Reproduced exactly**, all four numbers, to 3 decimals.

### Claim (3) — AGHQ+ridge reaches nominal coverage

This is the one place recomputation did NOT match on the first attempt, and it is worth
recording precisely, per the "be precise, report what you got instead" instruction.

**First attempt** (naive `mean(covered)` over all 21 entries × 200 seeds, `arm=="aghq_ridge"`):

```
diag:    0.944 / 0.946 / 0.936 / 0.949     (claim: 0.961 / 0.957 / 0.949 / 0.951)
offdiag: 0.934 / 0.952 / 0.947 / 0.951     (claim: 0.959 / 0.962 / 0.959 / 0.952)
```

This does NOT match — off by 0.006–0.017, more than 2×MCSE (≈0.031 at 200 seeds) at n=100.
I traced the cause: `24-coverage-cell.R`'s own header states coverage is reported
"CONDITIONAL on an available interval" — but per-row `status` is only `"no_se"` when *all*
21 entries in a fit fail; individual `se`/`lo`/`hi` can still be non-finite for SOME entries
inside an otherwise-`"ok"` fit (`aghq` arm: 8.5% of diag entries have non-finite SE at
n=100; `aghq_ridge`: 1.8% at n=100). Counting those as non-covering (the naive read of the
`covered` column) is NOT what the script's stated methodology asks for.

**Second attempt** (mean of `covered` restricted to `is.finite(se)`, i.e. conditional-on-
available, matching the script's own documented convention):

```
diag:    0.962 / 0.957 / 0.949 / 0.952     (claim: 0.961 / 0.957 / 0.949 / 0.951)
offdiag: 0.959 / 0.963 / 0.959 / 0.953     (claim: 0.959 / 0.962 / 0.959 / 0.952)
```

**This matches to within 0.001**, well inside any rounding/seed-order tolerance.
`laplace_ridge` and `aghq` columns also reproduce this way (`laplace_ridge` diag:
0.948/0.910/0.834/0.669 vs claimed lap+rdg 0.948/0.909/0.835/0.669; `aghq` diag:
0.876/0.903/0.917/0.939 vs claimed 0.869/0.895/0.912/0.937 — within 0.007, the largest
residual gap in the whole exercise, still an order of magnitude tighter than the previous
panel's 50%→8-25% failure).

**Caveat this surfaces that the claim text does not carry**: reaching this number requires
excluding non-finite-SE entries, i.e. genuine per-entry missingness of 1.5–8.5% depending on
arm/n (worst: `aghq` no-ridge at n=100, 91.5% available). `decisions.md`'s own SCOPE note
("All 3199 fits returned an interval — availability 100%, so no missingness correction was
needed") is **true only at the whole-fit level** (no fit fully failed) and **misleading at
the entry level** — a missingness correction (the finite-SE filter) both exists and is doing
real work. The verbatim claim under review says "reaches NOMINAL coverage at every n tested"
without disclosing this conditioning. This does not overturn the number, but it is an
undisclosed methodological step and should be named explicitly, not left implicit in a
"CONDITIONAL on available interval" line in a code comment.

### Claim (4) — divergent-fit rate, ridge does the small-n work

Source: `dev/aghq-evidence/20-shipped4-inc.csv` (120 rows, 15 seeds × 4 arms × 2 n values,
no failures, no duplicates). `runaway := frob_rat > 2`, at n=100:

```
laplace:        47%   (7/15)
laplace_ridge:   0%   (0/15)
aghq:           73%   (11/15)
aghq_ridge:      0%   (0/15)
```

**Reproduced exactly**, all four percentages.

## 2. Does anything still trace to `dev/aghq-r-reference.R`?

Grepped `source(...)` calls and `gllvmTMB(` calls in the three headline scripts plus the
evidence-SE scripts:

- `20-shipped-4arm-campaign.R`, `21-wide-factorial.R`, `24-coverage-cell.R`: no `source()`
  of anything except `24-coverage-cell.R` sourcing `22-sigma-se-delta.R` (evidence code for
  the SE, not the reference oracle). All three call `library(gllvmTMB)` and the real
  `gllvmTMB(...)` fitting function directly (confirmed at `21-wide-factorial.R:108`,
  `20-shipped-4arm-campaign.R:72`, `24-coverage-cell.R:78`).
- `22-sigma-se-delta.R` / `23-validate-sigma-se.R`: grepped for `aghq-r-reference` and
  `source(` — no hits beyond `22` sourcing itself into `23`/`24`. They read
  `f$report$Lambda_B` off a real fit object; no oracle dependency.
- `20-shipped-4arm-campaign.R`'s own header explicitly *names* `dev/aghq-r-reference.R` —
  but only in prose, explaining why this script exists (to supersede the reference-based
  numbers). It does not call it.
- The 16 OLDER scripts (`01`–`18`, `totoro-suite.R`) still source or otherwise depend on
  `aghq-r-reference.R`, and their numbers (the original 954-fit suite, the n=3200 descent,
  etc.) remain exactly as compromised as the previous panel found. **None of those numbers
  appear anywhere in the verbatim claim under review** — I checked every figure in the claim
  against 20/21/24 only, and all of them trace cleanly. This is the one unambiguous, total
  fix from the previous panel's lens-1 finding: the claim no longer rests on the prototype
  at all, not even partially.

## 3. Automated protection — golden tests

Ran directly (not trusting the commit message):

```r
Sys.setenv(NOT_CRAN = "true", OMP_NUM_THREADS = "1")
devtools::load_all(quiet = TRUE)
testthat::test_dir("tests/testthat", filter = "aghq", reporter = "silent")
```

Result: **23 `test_that` blocks, 0 failed, 0 skipped, 1502 expectations passed.** This
includes `test-aghq-golden.R`'s GOLDEN 1 (plumbing), GOLDEN 2 (fixed-point accuracy vs
independent `stats::integrate()` oracle, q=1), GOLDEN 2-bonus (q=2, nested-`integrate()`
oracle), GOLDEN 3 (poisson null control), and the new "the golden gate cannot lie in either
direction" test that asserts `k=1` never claims `aghq$used` and `k=3` always does. All ran
to completion with real printed ladders:

```
GOLDEN 2 (q=1): k=3 err=5.37e-05, k=9 err=8.69e-13, k=25 err=1.60e-14
GOLDEN 2-bonus (q=2): k=1..9, all convergence==0, error falls monotonically to <1e-4 at k=9
GOLDEN 3 (poisson): |objective diff|=0.082813, ||Lambda diff||_F/||Lambda||_F=0.005899
```

This directly answers the previous lens 2's finding (`D43-lens2-scope.md:86-113`): the three
golden tests used to skip 100% of the time because the smoke-gate probed `aghq$used` at
`k=1`, which is *structurally* routed to plain Laplace and can never report `used==TRUE`
(confirmed at `R/fit-multi.R` — `k=1` eligibility gate). The fix (commit `fa66156f`) moved
the gate to `k=3`, and the new dedicated gate-honesty test (`test-aghq-golden.R:237-253`)
makes a silent regression to this exact bug impossible to reintroduce without a red test.

**Is GOLDEN 2's fixed-point redesign real, or vacuous?** It is real. It removes the outer
optimiser from the loop (evaluating the AGHQ objective at ONE Laplace-fitted parameter
vector for k=3/9/25, verified via `expect_true(all(ladder$par_shift < 1e-9))` — i.e. it
independently checks that no drift crept back in) and shows monotonic convergence of
`abs_error` toward an *independently computed* oracle (`stats::integrate()`, itself
cross-validated against a fixed 2e6-point Simpson's rule to 1e-8, `test-aghq-golden.R:34-50`)
that shares no code with the AGHQ template. Error falling 4+ orders of magnitude from k=3 to
k=25 and plateauing near the oracle's own precision (1e-14, matching `stats::integrate()`'s
`abs.tol=1e-15`) is a real convergence signature, not a tautology — a broken quadrature
would not produce this pattern by accident.

**Is the fixture change (n_site=3 → n_site=10) legitimate?** Yes, on the evidence recorded
in the test's own comment (`test-aghq-golden.R:107-120`): at n_site=3 (6 binary obs, 4
params) the model is essentially unidentified, so the natural Laplace optimum is a runaway
(`|theta_rr_B| ~ 150+`) and AGHQ genuinely needs k=25 to get to only ~0.1-2 nll error there
— not because the quadrature is wrong, but because it converges slowly on a degenerate
surface. That is a real, disclosed, separate phenomenon from integration accuracy on a
well-identified point, and conflating the two is exactly the bug this redesign fixes (see
the file's own HISTORY note at lines 220-235, describing the one red-then-fixed cycle).
GOLDEN 1 still uses the n_site=3 fixture (it is a plumbing test, not an accuracy test, so
the degenerate optimum doesn't matter there), so the harder fixture wasn't abandoned, just
correctly scoped to the test it belongs to. I do not read this as weakening; the alternative
(keep n_site=3 for GOLDEN 2) is what produced the DELIBERATELY-RED cycle recorded in the
file, i.e. it would go back to conflating optimiser stall with integral error.

## 4. The MAP/ML gradient fix (`R/fit-multi.R`, commit `d7dc6c43`)

Read the diff directly (not trusting the commit message). Confirmed:

- `grad_tol` itself is untouched: `grep -n "grad_tol"` shows it still resolves to
  `control$aghq_grad_tol %||% 1e-4` (`R/fit-multi.R:5234`), same value before and after.
- The changed quantity is `g_cur`, the thing being COMPARED to `grad_tol`. Before: 
  `g_cur <- max(abs(obj_try$gr(par_cur)))` — the raw, unpenalised gradient. After: the same
  unpenalised gradient plus the ridge penalty's own gradient term
  (`par_cur[li] / (aghq_ridge_tau^2)`) added onto the `theta_rr_B` block before taking
  `max(abs(.))`, so the diagnostic now tests the gradient of the objective the optimiser is
  actually minimising (`F + 0.5*||lambda||^2/tau^2` under the ridge). This is the correct
  direction of fix — tightening what's being measured, not loosening the bar it's measured
  against.
- `aghq_info$ridge_tau` / `aghq_info$penalised` are now populated on both the Laplace and
  AGHQ paths (`R/fit-multi.R` diff, `aghq_info` list literal and the `used=TRUE` branch),
  and `logLik()`/`AIC()`/`BIC()` gained a `.aghq_check_penalised()` warning
  (`R/aghq-report.R`) that fires once when a fit carries a finite `ridge_tau`. I did not
  re-run this diagnostic end-to-end myself (out of scope for the evidence-chain lens), but
  the code path is coherent with the stated fix and does not touch tolerance values anywhere
  I could find (`grep -rn "grad_tol\|f_tol" R/fit-multi.R` shows only the pre-existing
  constants, unchanged).

## 5. Anything else contradicted by a repo artefact?

- `gllvmTMBcontrol()`'s own source (`R/gllvmTMB.R:1206-1243`) confirms `aghq = FALSE` by
  default and that the Laplace-path ridge is opt-in only via `missing(aghq_ridge)` — so the
  `laplace` arm in all three evidence scripts (no `aghq_ridge` argument passed) is genuinely
  unpenalised, matching what the claim calls "the shipped default." This resolved an
  apparent inconsistency I initially suspected (default value `aghq_ridge = 2` looked like it
  might silently apply); it does not, by explicit design, and the design is documented in
  the function's own source comment, not just in `decisions.md`.
- `NAMESPACE` has no `aghq`-related export; matches "nothing is exported."
- I found no artefact in the repo that contradicts any of the four claim numbers once the
  documented conditional-coverage convention (§1, claim 3) is applied.

## Summary of what changed since the previous 3/3 NOT-DONE panel

| previous objection | this arc's fix | verified how |
|---|---|---|
| lens 1: numbers traced to `aghq-r-reference.R`, validated only ≤ n=30 | 20/21/24 call real `gllvmTMB()` directly, n up to 1600, no sourcing of the reference | grep + direct CSV recompute |
| lens 2: golden tests self-skip, no regression protection | gate moved from k=1 (structurally can't fire) to k=3; new gate-honesty test | ran the suite myself: 0 skip, 0 fail |
| lens 3: MAP point reported with ML curvature, no coverage evidence at all | gradient diagnostic fixed to penalised gradient (not tolerance loosened); 3199-fit coverage cell added | read the diff; recomputed coverage from raw CSV |

## VERDICT: DONE

All four headline numeric claims recompute from the cited CSVs (three exactly to 3 decimals,
the fourth — AGHQ+ridge coverage — to within 0.001–0.007 once the script's own documented
"conditional on available interval" convention is applied, which is not the same failure
mode as the previous panel's irreproducible 50%→8-25% gap). None of the three headline
scripts sources or calls the disqualified prototype. The golden test suite that previously
self-skipped now runs for real (0/0/1502 fail/skip/pass) and exercises genuine quadrature
convergence against an independently-computed oracle, not a tautology. The gradient/MAP fix
is a real correctness fix, not a loosened tolerance. The one real gap I found — undisclosed
per-entry missingness (1.5–8.5%) underlying the claim-3 coverage numbers — is a
transparency issue in how the number is presented, not a reproducibility failure: the
number is real, it is just conditional in a way the verbatim claim doesn't say out loud.

## SMALLEST EVIDENCE THAT WOULD CHANGE MY VERDICT

- A rerun of `24-coverage-cell.R` (or an independent seed block) whose conditional-coverage
  numbers for `aghq_ridge` drift outside the 0.001–0.007 band I found here — i.e. evidence
  that my reconciliation via "exclude non-finite SE" was fitting noise rather than the
  actual convention used, would reopen claim (3).
- Any single case where 20/21/24 turn out to call a wrapper that itself falls back to
  `aghq-r-reference.R` under some code path I did not exercise (e.g. an error handler) —
  I checked `source()` calls and direct function calls, not runtime dynamic dispatch.
- A rerun of the `21-wide-factorial.R` campaign at a different seed block reproducing the
  same T-dependent bias pattern (0.35/0.18/0.11/0.04-ish) would upgrade my confidence in
  claim (1) beyond "reproduced from the one committed CSV" to "reproduced independently";
  its absence is not disqualifying, since a fresh recompute from raw per-fit rows is already
  strong evidence, but it is the next thing I'd ask for before treating this as certified
  rather than merely reviewed.
