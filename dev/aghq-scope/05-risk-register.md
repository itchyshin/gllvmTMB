# AGHQ-Laplace all-family scope: risk register and acceptance criterion

**Status:** research scoping note only. No package behaviour claimed or
changed. `R/`, `src/`, `inst/`, `tests/`, `NAMESPACE`, `DESCRIPTION` untouched
in any worktree. Written under
`/private/tmp/gllvmtmb-arc0-identifiability/dev/aghq-scope/` per brief.

**What was read to ground this note (read-only, no edits made there):**
`/private/tmp/gllvmtmb-va-wiring-20260726/dev/aghq-scope-accuracy-crux.md`
(the q=1/q=2 accuracy measurements and the `(star)` derivation),
`dev/aghq-scope-cost.md` (the timing/node-cost model and the
"no cheap AD gradient exists" finding), `dev/aghq-scope-gap.md` (the
`spHess(random=FALSE)` zero-cross-block finding), and `dev/aghq-q2-seed1{1..5}.log`
(the five raw q=2 attenuation values used for the MCSE arithmetic in §1 below —
the paired CSVs at that path are empty; the numbers live in the `.log` files).
I also confirmed directly in this repo (not from memory) that
`R/families.R` defines delta/hurdle, `tweedie()`, and `ordinal_probit()`
families, and `src/gllvmTMB.cpp` has an `mi_family` dispatch with an
explicit unordered/softmax branch (`mi_family == 3`, lines ~2297-2480) —
these ground §4's mixture-family and boundary-mode risk rows.

---

## 1. The overshoot and the acceptance criterion

### 1.1 What attenuation is defined against

`attenuation = trace(Sigma_hat) / trace(Sigma_true)` (accuracy-crux §2a(ii)),
where `Sigma_true` is the **simulated, known DGP covariance**, not VA-GH's
answer. The accuracy-crux note (§3) makes this point explicitly and for a
reason that generalizes: VA-GH's own bias **flips sign across cells** in this
repo (design 109 found GH over-estimates `Sigma_B` at n∈{150,400}, T=8; the
Ayumi cell finds GH under-estimates it). A bias that changes sign across
design points is a property of the design point, not of the engine, so it
cannot serve as ground truth. **The all-family acceptance criterion must be
defined against `Sigma_true` in simulation, never against another
approximate engine's output.** This also means the criterion is only testable
in simulation (known DGP), not on real data — a limitation to state up front,
not a defect to paper over.

### 1.2 What tolerance is defensible

Recompute the MCSE from the raw numbers rather than quoting means alone,
because the note repeatedly stresses that single-seed / few-seed levels are
unreliable (§2c(3) of accuracy-crux: `atten_LA` swung to 1.282 at n=500).

**q=2, 5 seeds (from `dev/aghq-q2-seed1{1..5}.log`):**
AGHQ attenuation = 1.0266, 1.0918, 1.0332, 1.0460, 1.0214.
Mean = 1.0438 (matches the reported headline). Sample SD ≈ 0.0284,
SE of the mean ≈ 0.0127. A naive 95% CI on the mean is **1.044 ± 0.025**,
i.e. **[1.019, 1.069]** — it excludes 1.000 (so "AGHQ ≠ exact" is already
supported at 5 seeds), but it does **not** pin the estimate to within a
tight band: the CI half-width (0.025) is itself larger than a plausible
tolerance (e.g. ±0.02).

**q=1, 3 seeds:** AGHQ attenuation = 0.8991, 0.9538, 0.9992, mean 0.9507,
sample SD ≈ 0.050, SE ≈ 0.029. Here `|0.9507 - 1| = 0.049` is **smaller than
one SE** — at 3 seeds the q=1 result is statistically indistinguishable from
"AGHQ recovers the exact integral," even though the point estimate reads
"undershoots by 5pp." This matters directly for §7.1's "unexplained sign
flip" in the outer brief: **the flip from 0.951 (q=1) to 1.044 (q=2) may not
be a real qualitative difference at all** — the q=1 number is within noise of
1.000, while only the q=2 number (5 seeds, narrower CI) is confidently off
zero. Before treating the sign flip as a phenomenon to explain, more q=1
seeds are needed to know whether there is a sign flip to explain.

**Defensible tolerance:** given the observed cell-to-cell SD is ~0.03-0.05 on
a single attenuation statistic with 3-5 seeds, a **tolerance narrower than
±0.02 on attenuation is not currently resolvable** with the seed counts on
hand — proposing anything tighter would be pretending to precision the data
does not have. ±0.02–0.03 (2-3 percentage points of trace-scale bias) is the
right order for a first pre-registered band, treated as provisional and
revisited once seed counts increase.

### 1.3 Seeds needed to distinguish 1.044 from 1.000 at that tolerance

Using the measured q=2 SD (0.0284) and requiring the 95% CI half-width to be
below a chosen tolerance `tol`:

```
n >= (1.96 * sd / tol)^2
```

| tolerance (tol) | n required (95% CI half-width < tol) |
|---:|---:|
| 0.03 | ~4 (already met at 5 seeds, barely) |
| 0.02 | ~8 |
| 0.01 | ~31 |

So: **5 seeds is enough to say "AGHQ's q=2 attenuation is not exactly 1"
(barely — it is right at the edge for a ±0.03 band) but not enough to certify
it within a ±0.02 band**, and nowhere near enough for a ±0.01 band. Any
all-family campaign that wants to *certify* (not just detect) an attenuation
close to 1 should budget for **~8-10 seeds per cell** as a floor, more if the
tolerance tightens.

### 1.4 A pre-registered kill rule (single sentence, for the all-family build)

> **Kill rule:** for a family/regime cell to pass, the AGHQ-vs-Laplace
> paired estimate of `|attenuation(Sigma_hat, Sigma_true) - 1|`, averaged
> over at least 8 seeds, must fall and its 95% CI must lie entirely below
> 0.03 (3 percentage points of trace-scale bias) — under- or over-shoot
> scored identically by absolute value, never "higher attenuation is
> better" — and if any in-scope family/regime cell's point estimate exceeds
> 0.05 or its CI fails to exclude values above 0.08, that cell is DEAD and
> is reported as a named exclusion from the "AGHQ covers all families" claim,
> not silently dropped from the average.

This preserves the two things the accuracy-crux note already established
(the |attenuation-1| framing, and scoring against `Sigma_true`) and adds the
one thing missing: a **numeric band and a seed floor**, committable before the
next run.

---

## 2. Overshoot vs undershoot: does the sign of the bias matter for coverage?

Laplace undershoots (0.897 at q=1, 0.922 at q=2); AGHQ overshoots (0.951,
1.044). In `|deviation|` terms AGHQ is smaller at q=1 (0.049 vs 0.103) and
comparable-to-worse at q=2 (0.044 vs 0.078 — actually still smaller in
magnitude, but closer to parity). But the project's actual gate is **interval
coverage**, not point attenuation, and the two do not move together
automatically:

- **A point estimator's sign of bias does not by itself fix interval
  coverage.** Coverage of a Wald or profile interval depends on both the
  point estimate's bias *and* the accuracy of the reported standard error /
  curvature at that point. Laplace's undershoot is at least a **known,
  monotone, well-studied direction** (it is the textbook Laplace variance-
  component attenuation); if its associated SE is *also* attenuated in the
  same direction (plausible, since the same curvature approximation drives
  both), under-coverage from a too-narrow interval around a too-small point
  compounds in one direction. AGHQ's overshoot is a **novel bias regime for
  this codebase** — there is no existing evidence here about whether AGHQ's
  reported curvature (from the AGHQ Hessian, not yet built — see §3 of
  `dev/aghq-scope-gap.md`) over- or under-states its own SE at an overshot
  point. **An overshooting point estimator paired with an under-scaled SE
  could produce WORSE coverage than Laplace's undershoot**, even though the
  point bias looks smaller in magnitude. This is not measured anywhere in
  the cited notes — it is a gap, not a result — and should be named as such.
- **Smaller |bias| is not obviously "better" for coverage in a small-sample
  regime with noisy SD estimates.** §2c(3) of accuracy-crux shows the
  attenuation statistic itself is upward-biased at small n (noise inflates
  the trace), and that this noise inflation is *itself* larger at small n —
  exactly where coverage is hardest to hit. If AGHQ's overshoot amplifies
  with the same noise-inflation mechanism at small n (untested), its
  coverage could degrade faster with shrinking n than Laplace's does, even
  though at n=2000/5397 its point estimate looks closer to 1.
- **Bottom line:** the sign of the bias is not obviously worse or better in
  itself; what matters is whether the *reported uncertainty* is correctly
  scaled at that biased point, and this is **completely unmeasured** for
  AGHQ in this repo (no `sdreport()`-equivalent exists yet, per
  `dev/aghq-scope-gap.md` §2 point 6). **Coverage must be measured directly
  once an SE mechanism exists; point-attenuation sign is not a usable proxy
  for it and should not be treated as one.**

---

## 3. The evidence's own limits, ranked by how likely each is to change the decision

1. **One family (Bernoulli-logit), complete cells, no phylogeny/spatial/
   missingness — HIGH likelihood of changing the decision.** Every number
   cited is Bernoulli-logit, per accuracy-crux §7.4. The whole premise of
   "AGHQ inherits all 16 families for free because it sits on the Laplace
   objective" is exactly the untested claim this scope exists to probe, and
   zero of the 16 families other than binomial-logit have been touched. This
   is the single biggest gap between the evidence collected and the claim it
   is being used to support.
2. **No AD-native gradient demonstrated to exist for the AGHQ objective —
   HIGH likelihood of changing the decision.** `dev/aghq-scope-cost.md` §3.5
   found the natural shortcut (`spHess(random=FALSE)` as the cross-block)
   returns structural zero where a finite difference shows a genuinely
   nonzero value (3.37). Under the finite-difference fallback the cost
   projection **reverses** — AGHQ-LA becomes 2-4 hours vs VA's ~2 hours,
   i.e. worse, not better, than the alternative it was chosen to beat. This
   is not a caveat on the accuracy result; it is a live threat to the
   project's own stated reason for choosing AGHQ (coverage-of-families) if
   the per-family gradient work turns out to cost as much as VA's per-family
   wiring did.
3. **3-5 seeds, one DGP — MEDIUM-HIGH likelihood.** §1.3 above shows the
   q=1 result (0.951) is not yet distinguishable from "no effect" at 3
   seeds, and the q=2 result (1.044), while distinguishable from 1.000, is
   not yet pinned within a useful tolerance band at 5 seeds. Any all-family
   decision made on 3-5 seeds per family risks certifying or killing a
   family on noise.
4. **q=1→q=2 transfer partially closed, q≥3 fully open — MEDIUM
   likelihood.** accuracy-crux flagged q=1→q=2 as its "largest blocker" and
   the q=2 seed run (§1 above) does now exist, narrowing this gap somewhat
   relative to when that note was written. But q≥3 remains completely
   untested, and the cost note's own viability table (`dev/aghq-scope-
   cost.md` §4) puts the q=3/q=4 hinge as the point where AGHQ stops being
   cheaper than VA — exactly the regime some real ordination models use.
5. **One OS, one BLAS, partly on a contended machine (load average 28-44)
   — MEDIUM likelihood for cost, LOW for the accuracy sign/identification.**
   The cost note is explicit that the three one-off fit times are
   contention-unverified, though the interleaved per-evaluation timings (the
   actual deliverable) were checked and found tight (<15% spread). Absolute
   costs could shift, but the qualitative ranking (AGHQ q=1-2 cheaper than
   VA; AGHQ q≥4 far more expensive) is unlikely to flip from contention
   alone — it would take a BLAS/OS difference in the underlying `O(n)`
   Laplace scaling to threaten the *architecture* conclusion, which is
   lower-probability than the family-coverage and gradient gaps above.
6. **The R-prototype-to-compiled-TMB cost-ratio transfer assumption — LOW-
   MEDIUM likelihood but high-consequence if wrong.** `dev/aghq-scope-
   cost.md` §2b/§3 explicitly flags that the ~42-71:1 mode-solve:node-cost
   ratio measured in interpreted R may not carry over to compiled AD-tape
   code, and that the projected 22-35 minute fit time for Ayumi's cell
   depends on it. If compiling shrinks per-node cost faster than mode-solve
   cost the projection is pessimistic (good); if the reverse holds it is
   optimistic (bad) — direction unknown.
7. **The two-term Tierney-Kadane analytic bias formula understates the
   measured effect 2-4x — LOW likelihood of changing the all-family
   decision by itself**, but it is a standing warning that *any* analytic
   pre-screen of a new family's AGHQ benefit (as opposed to measuring it) is
   liable to be biased against AGHQ, which could cause a family to be
   wrongly deprioritized on paper-only grounds before it is actually tested.

---

## 4. Risk register for the all-family build

| # | Risk | Likelihood | Impact | Earliest cheap test | Mitigation |
|---|---|---|---|---|---|
| R1 | Node-count regime is worse than assumed once families/dimensions used in practice run q=3-4, not q=1-2 | Medium | High — cost note's own table (`dev/aghq-scope-cost.md` §4) shows q=3 is the hinge and q=4 is "not viable at either node count" under the shared-solve model, and worse under the naive (non-shared-mode) model | Enumerate the actual q used across gllvmTMB's existing test/example corpus (grep `d = ` in formula calls) before committing to any q ceiling; this is a `grep`, not a simulation | Fence the AGHQ layer to q ≤ 2 at launch (matching what is actually measured), document q=3 as "provisional, re-test", q≥4 as explicitly out of scope |
| R2 | Mixture families (zero-inflation / hurdle / delta) break the single-mode-per-unit quadrature premise | Medium-High | High — the entire AGHQ machinery (accuracy-crux §2a, cost §2a) assumes ONE conditional mode per unit found by BFGS/Newton on a smooth unimodal density; a hurdle/delta density is a mixture over a discrete zero-vs-continuous state, which is not generically unimodal in the latent variable and may need a different (or multi-mode) quadrature construction entirely, not a drop-in reuse of O3's machinery. `R/families.R` (confirmed) defines delta/hurdle families and `tweedie()` as real, exported families, so this is not a hypothetical | Fit the O3 `.o3_hook_mode`-style single-unit mode solver against a synthetic hurdle/delta density and check unimodality/mode-uniqueness directly (a toy, <60s R script — do not build the full estimator) | If multimodal: either restrict the AGHQ layer to single-mode families at launch (Bernoulli/Poisson/Gaussian/ordinal-probit-style) and name mixture families as a known follow-on gap, or budget separately for a mixture-aware quadrature design before claiming "all families" |
| R3 | Boundary modes (e.g. near p=0/1 in binomial-logit, near-zero variance components, near-zero mixture proportions) break the Laplace/AGHQ curvature approximation that both need | Medium | Medium-High — a mode near a parameter boundary can have near-singular or ill-conditioned curvature, which both destabilizes the Cholesky used to place quadrature nodes (`R^{-1}` in the O3 transform) and is exactly where Laplace is already known to be worst, i.e. exactly where AGHQ is supposed to help most | Re-run the existing T=5 (short-profile) ladder cell with a design deliberately pushed toward extreme prevalence (e.g. p≈0.02 or 0.98) rather than the balanced design already used, and check whether the AGHQ node placement/Cholesky still succeeds | If it fails: document a guard (e.g. a curvature-conditioning check before placing nodes) as required scope, not an afterthought |
| R4 | The q=1→q=2 sign flip (0.951 undershoot-adjacent → 1.044 overshoot) is a bug (e.g. a node-weight or mode-transform error) rather than a genuine q-dependent property | Medium (see §1.2: q=1's result is not even confidently distinguishable from exact at 3 seeds, so "flip" may not exist) | High if it IS a bug — every downstream q=2+ number would be wrong | Increase q=1 seeds to ~8-10 (cheap, per §1.3) and re-check whether 0.951's CI still straddles 1.000; separately, re-verify the q=1→q=2 identity check (accuracy-crux's "k=1 curve must peak at c_hat=1.000" gate) on the actual seed-11..15 runs, not just the original 3-seed probe | If the q=1 result remains straddling 1.000 after more seeds while q=2 remains confidently >1: treat as a genuine q-dependent property and investigate mechanism (e.g. cross-axis coupling term absent at q=1); if q=1 turns out to also be confidently >1 with more seeds, suspect a shared implementation bug in the transform/weights common to both q's |
| R5 | Cost makes AGHQ unusable at realistic n once the AD-native gradient does not materialize | High (per §3 item 2: the shortcut is confirmed NOT to work) | High — the entire "AGHQ beats VA on cost" claim is conditional on an AD-native gradient at Laplace-like cost; the finite-difference fallback reverses the ranking (2-4h vs VA's ~2h) per `dev/aghq-scope-cost.md` §3.5 | Before writing any AGHQ estimator code, spend the smallest possible increment (a few hours) attempting a q=1, single-family C++/TMB-native AGHQ template (option (b) in `dev/aghq-scope-gap.md` §6) and check whether `obj$gr()`-style AD differentiation through it is achievable at all, rather than assuming it and building the R-level scaffold first | If AD-native gradient is not achievable within a bounded time-box: report cost as the finite-difference number honestly and let the maintainer decide whether "slower but general" is still worth building, rather than quietly building the R-level (a) route and discovering the cost problem after the fact |
| R6 | AGHQ improves point recovery (attenuation closer to 1) while NOT improving interval coverage, or making it worse | Medium (§2 above: entirely unmeasured, and there is a plausible mechanism for it to be worse) | High — coverage, not point recovery, is this project's actual gate per `CLAUDE.md`'s repeated framing of coverage/power as the headline metric | Once even a crude AGHQ SE mechanism exists (even a finite-difference Hessian at the AGHQ optimum, no full sdreport needed), run a small (order 100-200 replicate, not thousands) coverage check on the SAME q=1 Bernoulli cell already measured for point-attenuation, before extending to any other family | If coverage does not improve or regresses despite better point attenuation: treat point-attenuation improvement as insufficient evidence on its own for any family-coverage claim, and require a coverage number, not an attenuation number, before advertising any family as "AGHQ-improved" |
| R7 | The all-family claim quietly narrows in practice to "the families we happened to test" while the marketing/roadmap language still says "all 16" | Medium | Medium — a documentation/scope-creep risk more than a technical one, but the kind this project has been bitten by before (per CLAUDE.md's repeated "no register codes on reader-facing surfaces" and "do not oversell claims" discipline) | Maintain a literal per-family checklist (pass/fail/untested) as the register updates, rather than a single yes/no "AGHQ available" flag | Gate any NEWS/vignette/roxygen claim of "AGHQ available for family X" on that family's own row in the register showing PASS under the §1.4 kill rule, not on the general architecture argument alone |
| R8 | Compiled-TMB per-node/mode-solve cost ratio does not match the R-prototype ratio (§3 item 6), invalidating the 22-35 min projection either direction | Low-Medium | Medium — affects the specific timing number, not the qualitative "q≤2 viable" architecture conclusion, per the cost note's own framing | Once even a minimal C++/AD q=1 single-family prototype exists (needed anyway for R5's test), re-measure the mode-solve:node-cost ratio in compiled code directly and compare to the R-prototype's ~42-71:1 | Report the projected fit time as a range bracketing both directions until measured, not as a point estimate |

---

## 5. What would make us stop (or re-scope) outright

1. **The all-family gradient problem does not have a cheap solution for
   families beyond binomial-logit within a bounded time-box (R5).** If a q=1
   single-family C++/AD prototype cannot get an AD-native gradient cheaply
   (i.e. the shortcut failure in `dev/aghq-scope-gap.md` §3 turns out to be
   general, not a one-family artifact), then "AGHQ inherits all families for
   free" is false in the load-bearing sense — it inherits the *objective*
   but not the *cheap optimizability* — and the honest framing becomes "AGHQ
   is a q≤2, per-family engineering investment," which is a fundamentally
   different (much larger, much slower) proposal than the one that won the
   argument against VA on coverage grounds.
2. **AGHQ improves point attenuation but not coverage (R6), tested on the
   one cell that already has the most evidence (q=1/q=2 Bernoulli).** Since
   coverage, not point recovery, is this project's actual gate, a null or
   negative coverage result here would mean the entire accuracy-crux
   argument — however carefully measured — does not answer the question the
   project needs answered, and the AGHQ case would need to be re-made on
   coverage evidence specifically, not re-derived from attenuation.
3. **A mixture family (hurdle/delta/zero-inflated) shows genuine multimodality
   in the per-unit conditional density under the toy check in R2**, at which
   point "AGHQ as a drop-in refinement layer over Laplace" is not a
   description of what would need to be built for roughly a third of this
   package's family surface (delta/hurdle/tweedie/zero-inflated variants are
   a substantial share of the 16), and the "for ALL families" framing in the
   task brief would need to be replaced with a named subset from the outset.

---

## Provenance summary

- **MEASURED** (read from the cited notes' own result files, or recomputed
  here from numbers in those files): the q=1 (3-seed) and q=2 (5-seed)
  attenuation values and the MCSE arithmetic in §1; the family/family-dispatch
  facts in `R/families.R` and `src/gllvmTMB.cpp` (grepped directly, this
  session); the `spHess(random=FALSE)` zero-cross-block finding (cited from
  `dev/aghq-scope-gap.md`, not re-derived here).
- **DERIVED**: the seed-count table in §1.3 (standard CI-half-width formula
  applied to the measured SD); the cost-reversal consequence in §3 item 2
  (arithmetic already in the cited cost note, restated here for the risk
  register).
- **AGENT-INFERRED** (my inference for this note, not measured anywhere
  cited): the coverage/SE-scaling argument in §2 (there is no SE mechanism
  for AGHQ in this repo to measure against, so this is reasoned from
  mechanism, not observed); the mixture-family unimodality concern in R2
  (plausible from the density shape, not tested against an actual hurdle/
  delta fixture in this session); R3's boundary-mode concern (extrapolated
  from Laplace's known boundary behavior, not measured on an AGHQ fixture).
