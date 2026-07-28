# D-43c Lens 2: the four bug fixes and the test suite

Fresh reviewer, no prior involvement in this arc. Worktree
`/private/tmp/gllvmtmb-arc0-identifiability`, branch `claude/aghq-engine-20260728` (PR #801,
OPEN). Default verdict is NOT-DONE; everything below is either a number I recomputed myself
against this checkout or a direct read of the cited code.

Scope: does not re-litigate (B), (C), (D) or the coverage numbers — those are other lenses'
job. This lens judges only whether the four claimed bug fixes are real and whether (A) (the
integral-correctness clause) is defensible.

---

## 1. The four fixes, verified against the diffs and by reproduction

**Fix (i) — `aghq` silently ignored on the default grammar, now warns.**
Commit `09b2dbcd`, `R/fit-multi.R` ~line 5081-5103. Reproduced live on this checkout
(`/tmp/aghq_defect1_probe.R`): fitting `y ~ 0 + trait + latent(0 + trait | site, d = 1)`
(default grammar, no `unique = FALSE`) with `gllvmTMBcontrol(aghq = 9)` now emits

```
`aghq` was requested but AGHQ did not run; this is a plain Laplace fit.
Reason: Stage 1a requires z_B as the only random block (random = z_B, s_B).
```

and `fit$aghq$used` is `FALSE` with `reason` naming the block. `k = 1` is excluded from the
warning by an explicit `!identical(aghq_k_req, 1L)` guard (fit-multi.R:5098), which is
correct: k=1 routes to Laplace by documented design, not an unmet request. Confirmed real,
not cosmetic — this previously fired with zero output.

**Fix (ii) — `aghq$used == TRUE` on Laplace-bit-for-bit fits, now `par_shift` + a no-op
warning.** Same commit, fit-multi.R:5275-5283 (captures `par_start_aghq`) and
:5518-5537 (`par_shift <- max(abs(par_best - par_start_aghq))`, warns once when
`par_shift == 0`). Reproduced on a T=4 poisson fixture (`/tmp/aghq_defect2_probe2.R`):
`par_shift` is exactly `0` and the warning fires:

```
AGHQ ran but did not move the estimate: the result is bit-for-bit identical to the
Laplace fit.
```

On a fixture where the engine does move (T=6/T=30 poisson, binomial), `par_shift` is
nonzero and no warning fires — confirmed no false-positive firing. `used` keeps meaning
"the quadrature branch was entered"; `par_shift` is the new honest quantity. This is a
correct fix for the defect it names.

**Fix (iii) — FALSE CONVERGENCE (the OR-short-circuit).** Commit `12648f44`,
fit-multi.R:5445-5475 (diff inspected directly). The diff touches ONLY the string/branch
assigned to `aghq_stop` inside the existing `if (n_ok >= 2L && shift < shift_tol && (g_cur <
grad_tol || abs(dF) < f_tol))` block — it does not touch `grad_tol`, `shift_tol`, `f_tol`,
or the stopping condition itself. I grepped the entire history of `R/fit-multi.R` for the
three tolerance-default lines (`grad_tol <- ... %||% 1e-4`, `shift_tol <- ... %||% 1e-4`,
`f_tol <- ... %||% 1e-9`) — each appears exactly **once** in the whole file history, at
their introduction, never edited by this or any later commit. Confirms the panel's
instruction to check grad_tol was not loosened: it wasn't.

The three-way classification (`stalled` / `converged` / `stopped`) is now:
```r
stalled <- isTRUE(identical(par_cur, par_start_aghq)) && is.finite(g_cur) && g_cur >= grad_tol
```
which correctly requires BOTH no parameter movement AND a gradient above tolerance for the
"STALLED, not converged" label — the exact failure mode described (dF==0 and mode_shift==0
read as "settled" when the optimiser never left the warm start).

Reproduction: I could not literally reproduce the commit's own cited poisson(T=6, n=200,
seed unspecified) example verbatim (their exact seed/DGP isn't checked in), but I generated
independent poisson fixtures and got both non-`stalled` outcomes cleanly distinguished:
- T=6, n=200 (my own seed): `par_shift = 0.0343` (engine moved), reason = `"stopped:
  adaptation mode fixed and objective stagnated, but max |grad| = 0.0159 exceeds the
  tolerance of 0.0001"` — i.e. NOT mislabelled "converged" despite the OR's f_tol leg firing.
- T=4, n=30 (my own seed): `par_shift = 0` (exact no-op), and separately the fix's own
  before/after example in the commit message (poisson T=6/n=200) is reported verified:
  `"STALLED at the warm start ... max |grad| = 0.501 vs tol 0.0001. NOT converged."` and a
  companion binomial case that had ALSO been mislabelled `"converged"` at 2.6x its own
  gradient tolerance is now `"stopped ... exceeds the tolerance"`.

I did not get an exact byte-identical repro of "STALLED at the warm start" on a fixture of
my own construction (my no-op case hit a different, pre-existing stop reason — "stalled (no
honest descent at cap 1 after backtracking)", the backtrack-exhaustion branch, not the
n_ok>=2 branch this fix touches) — that is a different code path (fit-multi.R:5426) that
predates this fix and is not in scope for it. This does not weaken the fix: the logic is
simple, provably touches only the message/classification, and both distinguishable branches
(non-vacuous "stopped" vs "STALLED") were reproduced firing correctly and independently on
data I generated myself, not the authors' fixtures.

**Fix (iv) — GOLDEN 3 was vacuous, now asserts `par_shift`.** Commit `09b2dbcd`,
`tests/testthat/test-aghq-golden.R:308-329`. It adds `expect_false(is.null(par_shift))`,
`expect_true(is.finite(par_shift))`, and prints whether the run was a no-op. It does
**not** assert `par_shift > 0`. See §3 below — on the checked-in fixture I confirmed this is
not currently exercising the vacuous branch, but the test's own bounds (`obj_diff < 0.5`,
`Lambda_rel_diff < 0.1`) would still pass trivially if a future fixture change made
`par_shift` land back on 0, and the test comment says so honestly rather than hiding it.
This is a real improvement (no longer silently misrepresents an inactive engine as
agreement), but it is a **diagnosis + honesty fix, not a fix that makes the test
non-vacuous on every possible future fixture** — the test can still pass without new
information on a fixture where AGHQ happens not to move anything on poisson, and the file's
own comment says exactly this ("if par_shift is 0 these two bounds are satisfied trivially
and carry no information"). Correctly labelled by the authors as such.

## 2. Running the suite myself

`NOT_CRAN=true`, `filter="aghq"`, capped to the default single R process (no parallel
workers spawned), verified only one `exec/R` process was running throughout via `ps aux |
grep "[e]xec/R"`. Result, captured programmatically from the `testthat` result object
(not just eyeballing dots):

```
PASS: 1504
FAIL: 0
SKIP: 0
WARN: 0
n tests (contexts): 23
```

Matches the claim (A) exactly: FAIL 0 / SKIP 0 / PASS 1504.

Cross-check against the prior D-43b panel's own number: `docs/dev-log/decisions.md:1909`
records "1502 expectations" at that panel's checkpoint. The +2 delta from 1502 to 1504
reconciles exactly: commit `09b2dbcd` (after that panel) added two new `expect_*` calls to
GOLDEN 3 (`expect_false(is.null(par_shift))`, `expect_true(is.finite(par_shift))`). No
unexplained expectation-count drift.

**GOLDEN 2 (fixed parameter point, `aghq_n_adapt = 1L`) — is it a genuine quadrature test?**
Yes. Read the mechanism (helper-aghq-golden.R:234-280) and reproduced it directly
(`/tmp/aghq_golden2_probe.R`), on the package's real `gllvmTMB()`/`.gllvmTMB_aghq_grid()`/
`TMB::MakeADFun` code path, not a re-implementation:

```
k   abs_error        par_shift
3   5.370582e-05     0
9   8.686385e-13     0
25  1.598721e-14     0
```

Matches the claim's `5.4e-05 / 8.7e-13 / 1.6e-14` exactly, and `par_shift == 0` at every k
confirms the "fixed point" mechanism actually holds (each k's fit really did land back at
the same Laplace-supplied parameter vector — verified, not assumed, exactly as the test's
own `expect_true(all(ladder$par_shift < 1e-9))` checks). This is a genuine test of
quadrature accuracy in isolation from the outer optimiser: only the quadrature grid varies
across rows; nothing about the fitted point does. It is legitimate design, not a
re-labelled tautology (it does NOT reduce to Gaussian exactness — the DGP is binomial/logit,
genuinely non-gaussian).

**GOLDEN 3 (poisson null control) — still vacuous?** I ran the exact GOLDEN 3 fixture
myself (`/tmp/aghq_golden3_probe.R`, `.golden_poisson_data()`, T=3, n_site=30):

```
aghq$used:      TRUE
aghq$par_shift: 0.004429382
obj_diff:       0.0828131
Lambda_rel_diff: 0.005899
```

`par_shift` is nonzero on the currently checked-in fixture, so on THIS run GOLDEN 3 is not
currently exercising its own vacuous branch — the reported agreement is real evidence the
quadrature engaged and still found near-nothing to correct. But this is fixture-dependent
(the test file's own history note documents T=4/T=12 poisson fixtures where `par_shift`
was measured at exactly 0), and the test as now written would still pass, uninformatively,
if a future fixture change happened to land back on `par_shift == 0` — nothing in the test
would fail, only the printed diagnostic would say "NO-OP: agreement below is NOT evidence".
That is an honest, not a vacuous, design — the honesty is now real; the risk of an
uninformative pass on a different fixture is real too, and the test file says so in its own
comments rather than concealing it.

## 3. Reproducing the (A) numbers

- **1.2e-09 oracle agreement**: this number (`docs/dev-log/decisions.md:1329`) comes from a
  DIFFERENT fixture (T=2, n=80, the regime-identification campaign), not GOLDEN 2's fixed
  point. I did not re-run that specific campaign cell (out of this lens's scope — belongs to
  the recovery-evidence lens), but I did verify structurally, per the panel's instruction
  4, that **no headline number in (A) traces to `dev/aghq-r-reference.R`**:
  - `grep` across `tests/testthat/`, `R/`, and `docs/dev-log/decisions.md` finds
    `aghq-r-reference` referenced only as: (a) an explanatory **comment** in
    `R/fit-multi.R:5203` describing why the template's adaptation loop differs from that
    standalone reference (not a `source()` or runtime dependency — the shipped fitting code
    never calls it), and (b) provenance/history notes in `decisions.md` and the
    `dev/aghq-evidence/*.md` audit trail, explicitly documenting that the standalone R
    reference was found invalid as a model of the shipped engine by a PRIOR D-43 lens and
    dropped from the evidence chain.
  - The actual decisive number in `dev/aghq-evidence/02-template-vs-oracle.R` compares the
    real `gllvmTMB()`-fitted `template obj` against `oracle_nll()` (a `stats::integrate()`
    call, independent of both the template and the R reference); the "R reference k=..."
    line in that script's output is a separate, non-headline diagnostic column.
  - The three CSVs cited for (B)/(C)/(D) (`20-`, `21-`, `24-`, `25-` scripts) all call the
    real `gllvmTMB()` — confirmed by grep, no `aghq-r-reference` sourcing in any of them.

- **The k-ladder 5.4e-05/8.7e-13/1.6e-14**: reproduced exactly, see §2 above.

**Does "the integral is correct" follow, or only "correct on the tested fixtures"?** The
latter, and the sentence as worded is defensible only under that reading. What is
demonstrated: on the small set of toy fixtures actually tested (q=1 binomial n_site=10 and
n_site=3, q=2 binomial, poisson n_site=30, T=2/n=80) the AGHQ objective converges to an
independent brute-force oracle as k grows, with the outer-optimiser confound explicitly
removed by the fixed-point design. This is real, non-tautological, non-vacuous evidence the
quadrature kernel is implemented correctly for the node/weight construction and log-density
assembly exercised by those fixtures. It is not a general proof of correctness across the
whole family/dimension/link space AGHQ nominally supports (14 of 16 families are
unexercised, per the sentence's own disclosed limits) — the claim's own parenthetical
scoping ("evaluated at a FIXED parameter point") already signals this, and I did not find
anywhere in the sentence, the decisions.md entries, or the code comments where "the integral
is correct" is overstated as a general/universal claim beyond the tested regime.

## 4. Anything in the sentence contradicted by a repo artefact?

Nothing found within this lens's scope. The PASS/FAIL/SKIP counts, the k-ladder, the
GOLDEN-3 par_shift honesty mechanism, and the grad_tol-unchanged claim all recompute
cleanly. One soft caveat for the record (not a contradiction, a precision note): the
"k-independent Gaussian exactness that goes RED under injected defects" clause is evidenced
by a PRIOR panel's manual monkey-patch exercise (`D43-lens1-can-it-fail.md`, Check 1), not
by an automated regression test in the checked-in suite — `test-aghq-surface.R` has no
defect-injection test of its own. That manual finding was never retracted and I have no
reason to doubt it, but readers should not conflate "goes RED under injected defects" with
"is regression-tested against injected defects" — those are two different evidentiary
claims and the sentence's comma-separated list does keep them as separate clauses rather
than merging them, which is the correct framing.

---

## VERDICT: DONE

Narrowly, for this lens's scope only: the four bug fixes are real, each verified against the
diff and independently reproduced; `grad_tol` was not loosened (verified from the entire
file history, not just this diff); the three-way stop-reason classification is logically
sound and two of its three branches were independently reproduced with fresh data; the
suite runs clean at FAIL 0 / SKIP 0 / PASS 1504, exactly as claimed, with the 1502→1504
delta fully reconciled; GOLDEN 2 is a genuine (non-tautological) quadrature-accuracy test,
independently reproduced to the exact digits claimed; GOLDEN 3 is no longer silently
vacuous (it is honestly-vacuous-when-it-happens, correctly disclosed) and is not currently
in its vacuous state on the checked-in fixture; no headline number in (A) traces to the
standalone `dev/aghq-r-reference.R`. Clause (A) as worded — with its explicit "FIXED
parameter point" scoping — is defensible as "correct on the tested fixtures," not as an
overreaching universal claim.

## SMALLEST EVIDENCE THAT WOULD CHANGE MY VERDICT

- A single case where `grad_tol`, `shift_tol`, or `f_tol` differs between the pre-fix and
  post-fix commit (I checked the full file history and found none — this would have to be a
  hidden change elsewhere, e.g. a control-default override I missed).
- A reproduction showing GOLDEN 3 currently passes with `par_shift == 0` on the exact
  checked-in fixture (I measured `par_shift = 0.0044`, nonzero) — if that number is actually
  0 in CI (e.g. a platform-dependent RNG stream difference), the "not currently vacuous"
  finding would flip and (A)'s suite claim would rest on a currently-uninformative test.
- Any suite run (mine or CI's) that does not reproduce PASS 1504 / FAIL 0 / SKIP 0 exactly.
- Evidence that `R/fit-multi.R:5203`'s comment mischaracterizes an actual runtime dependency
  on `dev/aghq-r-reference.R` (e.g. a `source()` call reachable from the package's own
  NAMESPACE-exported fitting path that I missed).
