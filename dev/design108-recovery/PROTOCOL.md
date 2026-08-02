# Design 108 recovery campaign — VA-R3 vs Laplace on the two-tier structured phylogenetic model

Status: **protocol only — no code, no fits.** Written for another agent to implement.
Role: Fisher (simulation design). ADEMP framework (Morris, White & Crowther 2019).
Provenance markers follow Design 109's convention: **PROVED** / **KNOWN** / **AGENT-INFERRED**
(this document's own reasoning, not proved) / **CONJECTURE** / **PROPOSAL** (a design choice
requiring the maintainer's input because no cited document fixes a number).

Worktree: `/private/tmp/gllvmtmb-d108-recovery`, branch `claude/d108-recovery-campaign`, pinned
at Design 108 Gate A Stage 7 (`2e7e10c4`, PR #911 base).

**Design goal, stated once and enforced throughout: this campaign must not be able to return a
confident wrong answer.** Every non-negotiable below exists because a specific near-miss
happened; the corresponding protocol clause is the guard against that exact failure repeating.

---

## Correction after maintainer review (round 2)

Two things changed from the first draft of this protocol, both because the maintainer checked
a claim directly against the code rather than trusting the prior draft's summary of it.

**1. The "VA tips-only" arm is restored as first-class, not conditional.** The prior draft
marked it a stretch goal, citing Design 108 Gate A Stage 7's after-task report as having
rejected a tips-only route. **That was a misreading.** What Stage 7 rejected was the **1-vs-0
base-index sniff** (an ordering-detection heuristic that silently mis-attaches observations
under one convention), not the tips-only route itself. `tests/testthat/
test-va-r3-structured-phylo.R:395` constructs and measures **both** routes and states in its
own header comment (line 399): *"BOTH routes are reachable, because the tier's level count is
read off `nrow(Ainv)` and nothing else."* The tips-only recipe, verified present and exercised
in that test:

```r
A   <- ape::vcv(tree, corr = TRUE)[sp, sp] + diag(1e-8, N)
st  <- list(Ainv = solve(A),
            log_det_A = as.numeric(determinant(A, logarithm = TRUE)$modulus))
lid <- unit - 1L        # 0-based, as the structured contract requires
```

The same test measures the cost consequence directly: the augmented route's inner-Hessian
fill is **flat** in tip count (`max(aug) - min(aug) < 0.2` non-zero-entries-per-row across
`n_tip in {20, 40, 80}`), while the tips-only route **grows** (`tip[3]/tip[1] > 1.5`,
`tip[80] > 2 * aug[80]`) — an `O(N^2)` dense inner solve, because `ape::vcv(tree, corr =
TRUE)[sp, sp]` is dense where the augmented `A_phy^{-1}` is sparse (~3 non-zeros/row). **This
is restored as Arm 4 in §M**, with its cost ceiling treated as a first-class output of the
campaign (§Stopping/abort rules), not a reason to exclude it up front.

**2. Seven non-negotiables from the maintainer, each tied to a specific near-miss today, are
now encoded explicitly** rather than left implicit in general good practice. They are listed
in §The seven non-negotiables and threaded through every section below with a forward
reference from there.

---

## The seven non-negotiables

Each item was earned from a documented near-miss, cited where the miss is on record. Every
one is load-bearing in a specific section below; this list is the index, not a summary to be
read once and forgotten.

1. **Pre-register the hypothesis AND its falsifier**, in the eventual script's header, before
   any fit runs. `dev/design108-stage8/analyse-silent-divergence.R` lines 8–24 is the house
   model: it states "THE HYPOTHESIS UNDER TEST... so it cannot be retrofitted to the data" and
   "WHAT WOULD FALSIFY IT" as separate, equally prominent blocks. See §Pre-registration text
   below for the text this campaign's script header must carry verbatim.
2. **Paired design** — same data, same seeds, every engine/arm fit to byte-identical simulated
   data. Already the backbone of §Number of seeds and §Analysis plan; restated here because an
   unpaired comparison at the variances this campaign expects would drown the effect.
3. **A positive control that MUST recover, with a gate.** `gaussian_control` (identity link,
   Gaussian response) must show near-zero degeneracy under both engines; if it does not, **no
   other rate in the campaign is interpretable**, full stop. `dev/design108-stage8/
   analyse-silent-divergence.R` lines 78–85 already implements this gate exactly — reused
   verbatim in §Analysis plan, not rewritten.
4. **Do not pool across design axes.** Report by cell (N x T x q x sigma_lambda x arm x tier),
   never as a single number averaged over several of those. Issue #897's spec was overturned
   precisely because it reported operating characteristics "pooled over three design axes the
   original never examined" — the same failure this campaign must not repeat.
5. **Use the N-ladder; do not fit one N and generalise.** Everything measured in this repo's
   adjacent campaigns so far has decayed (or grown) with `n`; a single-`n` result is a coin
   flip about which side of that curve you landed on.
6. **VA must run `profile_variational = TRUE` above N ≈ 1500.** Below that, `profile_variational
   = FALSE` (joint) is also run, for the optimiser-path comparison §M arm 2 exists to make.
   Above it, running the joint route risks measuring the outer optimiser's memory wall (Design
   108 §9's flagged, unresolved `~52 GB` dense-quasi-Newton estimate) instead of the estimator's
   accuracy — a completely different failure mode that would masquerade as an accuracy result.
7. **Wilson intervals on any rate compared against a prior number.** A bare proportion invites
   over-reading, especially at the seed counts this campaign can afford. Reuse the `wilson()`
   function from `dev/design108-stage8/analyse-silent-divergence.R` lines 41–47 verbatim (given
   in §P below) rather than re-deriving it.

---

## The trap — standing rule, stated once here and repeated in §Analysis plan

Quoting the maintainer's brief, attributed to "Stage 4" — **not independently re-verified
against a specific file in this pinned worktree**, because the source postdates the Stage 7
pin this protocol works from; taken as a direct, trusted instruction, not a citation this
document can point a reader to:

> "agreement between two approximations is not accuracy." Both engines under-recovered the
> planted `Sigma_B` on the toy seed.

**Every comparison in this campaign is against PLANTED TRUTH. Laplace and VA are never each
other's reference.** `rel_frob(VA, truth)` and `rel_frob(Laplace, truth)` are the only
comparisons that mean anything; `rel_frob(VA, Laplace)` (agreement between the two engines) is
not computed as an accuracy measure anywhere in this protocol, and if it is computed for
diagnostic curiosity, it must be labelled "engine agreement, not accuracy" wherever it appears
and kept out of every results table that also carries a truth-based `rel_frob`.

---

## Question

Does the fenced, experimental VA-R3 engine recover the two-tier `Sigma_B` — an ordinary
species latent tier plus a structured phylogenetic latent tier, both `unique = TRUE`
(`Sigma = Lambda Lambda' + diag(psi)`) — **better** than the shipped Laplace engine, at
adequate sample size (N = 5,000–10,000 species, hard cap) and realistic trait count
(T = 20–30), binomial-probit family? "Better" is operationalised entirely against **known
simulated truth** (`rel_frob` of `Sigma_B` per tier), never against convergence diagnostics
(non-negotiable 3 of Design 72/108's recurring caution) and never against the other engine
(the trap, above).

**What a negative result looks like, stated before any fit is run:**

- VA's `Sigma_B` error (`rel_frob`, either tier) is not smaller than Laplace's at any tested
  cell in the structured regime — i.e., the shipped engine is already adequate and VA offers
  no accuracy case.
- VA converges (in the diagnostic sense) but its recovery is **worse** than Laplace's at
  large N — i.e., the known downward-bias mechanism (Design 72 §0 point 4, §4 point 2) does
  not wash out with sample size on the structured tier the way it appears to on the
  unstructured tier (Design 72 §0b).
- VA's degeneracy rate (defined against truth, §P below) is not lower than Laplace's at any
  tested N — i.e., VA does not remove the *mechanism* (non-PD inner Hessian) that motivated
  looking at it in the first place (Design 72 §5).
- Any apparent VA advantage is confined to a narrow prevalence/`sigma_lambda`/`q` corner and
  disappears elsewhere in the grid — i.e., a calibration accident at one design point, not a
  property of the engine (Design 109, "Verdict on the accuracy claim" (d)).
- **The positive control itself fails to recover** — in which case the campaign returns no
  substantive answer at all (non-negotiable 3): a broken harness cannot produce a trustworthy
  negative *or* positive result, and the correct report is "instrument broken," not a rate.

A negative result on any of these is a publishable, useful answer. **This protocol is written
so that "VA does not help here" is exactly as reportable as "VA helps here," and so that
neither can be produced by a harness bug, an unpaired comparison, a single lucky/unlucky N, a
pooled table hiding a cell-level reversal, or a proportion whose interval swamps the point
estimate.**

---

## Pre-registration text for the script header (verbatim, non-negotiable 1)

The implementer must paste text of this shape at the top of the campaign script, filled in
with the actual pilot-derived numbers once available (mirroring
`dev/design108-stage8/analyse-silent-divergence.R` lines 8–24 exactly in structure):

```
## THE HYPOTHESIS UNDER TEST (pre-registered here before the grid returns, so it cannot
## be retrofitted to the data):
##   On the structured phylogenetic tier, at N >= [pilot-determined floor] species,
##   VA-R3 (profile_variational = TRUE above N ~ 1500) recovers Sigma_B1 (phylo tier)
##   with smaller rel_frob against PLANTED TRUTH than the shipped Laplace engine, on a
##   majority of paired seeds, in the binomial-probit family.
##
## WHAT WOULD FALSIFY IT:
##   - A paired sign test not favouring VA at p < [threshold] in the majority of cells.
##   - VA's signed trace bias on Sigma_B1 more negative than Laplace's downward bias
##     (Expectation 1 predicts VA is biased low; if Laplace is ALSO biased low and by
##     more, "VA wins" could still be two wrongs of different size -- report the signed
##     bias, do not infer from rel_frob alone).
##   - A result that reverses sign across the q ladder (non-negotiable 4/5: report by
##     cell; a q-corner win is not a finding).
##   - The positive control (gaussian_control) failing to recover cleanly -- in which
##     case nothing else in this run is interpretable and the campaign reports
##     "instrument broken," not a rate.
## Report the falsifier outcome either way -- a null or reversed result here is a real
## result, exactly as reportable as confirmation.
```

---

## Pre-registered expectations (stated before any data is generated)

**Expectation 1 — VA variance components are biased downward.** Design 72 §0 (TL;DR point 4)
states plainly: "VA variance components are known to be biased DOWNWARD," and §4 point 2
elaborates: "VA is known to UNDER-estimate variance/dispersion parameters (the mean-field
assumption ignores posterior correlation, shrinking the apparent latent spread)... VA
estimates of `Sigma_b`... will likely sit LOW vs LA / vs truth" (**KNOWN**, citing Hui,
Warton, Ormerod, Haapaniemi & Taskinen 2017). **Pre-registered prediction:** the **signed**
trace bias of VA's `Sigma_B` (both tiers) will be negative (`trace(Sigma_B_hat) <
trace(Sigma_B_true)`), and more negative than Laplace's. This is why §P below makes the
signed bias a primary reported quantity, not just `rel_frob`, which is unsigned and cannot
distinguish "VA is closer to truth" from "VA under-shot by less than Laplace over-shot" — the
trap, applied to bias direction specifically.

**Expectation 2 — the unstructured tier is not the question, and adequate N should already
resolve it.** Design 72 §0b (Phase-1 outcome, 2026-06-03) found that wherever the (toy,
unstructured) model is identifiable (`n >= 30`), "VA matches the Laplace point estimates to
~2 significant figures," and that the small-`n` collapse seen in that benchmark is
**under-identification, not a mean-field-`q` artifact.** At this campaign's envelope (N in the
thousands), the ordinary tier is expected, ex ante, to sit in the identifiable regime for both
engines. **Consequence for design, not just prediction:** this campaign does **not** re-run a
small-N unstructured sweep. Tier 0 (ordinary) is measured **as an in-fit control alongside
every cell**, at the same N/T/q as the phylo tier it is fit jointly with. If tier 0 diverges
from the "VA ≈ Laplace" expectation at this campaign's N, that is itself informative and must
be flagged, not silently absorbed — but note per the trap above, "VA ≈ Laplace" on tier 0 is
still checked against truth on both sides, never as VA-vs-Laplace agreement alone.

**Expectation 3 (methodological, not substantive) — do not expect a clean ELBO-gap-vs-recovery
story, and this narrows what the campaign can say about bound tightness.** Design 109 proves
(★, "the general principle: bias tracks the gap's gradient, not its level") that the
displacement of a bound-maximiser from the truth depends on the *gradient* of the approximation
gap, not the gap's *level*. On this codebase's binomial-**logit** family this produced a
counter-intuitive result: the looser JJ bound recovered `Sigma_B` better than the tighter GH
bound on 20/20 paired seeds. **This campaign's family is binomial-probit (family code 4),
which is outside Design 109's scope** ("Scope: `inst/tmb/gllvmTMB_va_r3.cpp`, `family == 1`
(binomial-logit)," Design 109 line 4) — probit is evaluated via the shipped tail-safe `log Φ`
primitive under ordinary GH quadrature (Design 108 Stage 4; **settled, not re-derived here:
the shipped `log Φ` needs no change** for this campaign), not a JJ/Pólya-Gamma bound, so
**Design 109's specific JJ-vs-GH mechanism does not transfer and this campaign includes no
`eval_method`/bound-tightness arm.** What transfers is the family-independent theorem (★)
itself: an ELBO-vs-Laplace-logLik gap is not a proxy for recovery quality (§P, §Analysis plan).
**Stated plainly rather than left as a silent omission:** this means the campaign cannot make
any claim about whether bound tightness predicts recovery for probit specifically — that
question is simply not asked here, and a reader should not infer either a confirmation or a
refutation of Design 109's logit-specific finding from this campaign's probit results.

---

## A — Aims

1. Measure whether VA-R3 recovers `Sigma_B` for a structured phylogenetic tier better than the
   shipped Laplace engine, at sample sizes and trait counts in the envelope motivating this
   work (N = 5,000–10,000 species, T = 20–30 traits), holding family (binomial-probit) fixed,
   **reported by cell, never pooled** (non-negotiable 4).
2. Measure whether that comparison, if it favours VA, is stable across `q` (latent dimension)
   — a design requirement, not a discretionary aim (§Design grid, non-negotiable 4/5).
3. **Measure where the tips-only structured route stops being affordable relative to the
   augmented route**, and report that crossover as a first-class result (§M arm 4, §Stopping/
   abort rules) — not merely "tips-only excluded for cost," which would hide a genuinely
   informative number.
4. Separately and non-inferentially, measure the VA-ELBO-vs-Laplace-logLik gap (the trap; §P,
   §Analysis plan).
5. Measure wall-clock and peak memory scaling for both engines and both node-set routes across
   the N-ladder, resolving Design 108 §9's flagged, unresolved question about whether the
   dense-vs-L-BFGS memory difference at this coordinate count is real (Aim 4 of the prior
   draft; renumbered here as Aim 5).
6. **Confirm the positive control recovers cleanly at every N tested**, as a precondition for
   trusting any other aim's result (non-negotiable 3) — this is listed as its own aim, not
   folded silently into "methods," because a campaign that only checks the control once at the
   smallest N and assumes it holds at scale is exactly the kind of unearned confidence this
   protocol exists to prevent.

**Not an aim:** producing any public-facing or package-advertised capability claim. This is a
research-only campaign on a fenced, experimental engine.

---

## D — Data-generating mechanism

### Tier structure

Two latent tiers, both `unique = TRUE` (loadings-plus-diagonal-Psi), matching the package's
canonical two-tier grammar (`CLAUDE.md`, "Syntax Rules to Preserve"):

- **Tier 0 (ordinary/unstructured):** `q0` latent dimensions, iid across the `N` species.
  `Sigma_B0 = Lambda0 Lambda0'` (T x T), plus diagonal `psi0` (T-vector).
- **Tier 1 (phylogenetic/structured):** `q1` latent dimensions, correlated across species via
  the tree's inverse-correlation matrix `A_phy^{-1}`. `Sigma_B1 = Lambda1 Lambda1'` (T x T),
  plus diagonal `psi1` (T-vector).

Both tiers load on all T traits (`kind = "dense"` in the internal tier-spec grammar) plus a
matching `kind = "diagonal"` tier for each Psi component — the shape exercised by
`tests/testthat/test-va-r3-structured-phylo.R`'s fixture (`.va_r3_phylo_fixture()`), which
builds `extra_tiers = list(spec)` with `spec = list(kind = "dense", dim = q1,
level_id = <node id>, structured = TRUE, label = "phylo")` alongside the top-level
unstructured tier of dimension `q0`. This campaign generates data at that shape and scale, not
at the small fixture's `n_tip = 4`.

### Positive control (non-negotiable 3)

A `gaussian_control` family arm — identity link, Gaussian response, residual SD as a further
**PROPOSAL** (0.4, matching `dev/design108-stage8/README.md`'s own `gaussian_control`
convention, flagged for confirmation) — is fit at **every N in the ladder** (both Parts A and
B), same two-tier structure, same `sigma_lambda`/`q` grid, both engines. This is not optional
and not a one-off smoke check: `dev/design108-stage8/analyse-silent-divergence.R` lines 78–85
gate the entire campaign's interpretability on this control ("if this family also shows a
non-trivial silent-divergence rate, that implicates the harness itself... and the result
should not be trusted until the harness is fixed" — restated for a truth-based `rel_frob`
threshold rather than only the flag-based `silent_divergent` label, since non-negotiable 3
here is about recovery against truth, not just flag agreement).

### Tree simulation

- Simulate one coalescent phylogeny per (N, seed) cell via `ape::rcoal(N)` (an ultrametric
  tree; `ape::rtree` is a plausible alternative if the maintainer wants non-ultrametric branch
  lengths — **PROPOSAL**: default to `rcoal`, flag for confirmation).
- Build the **augmented** phylogenetic precision the same way the fitting code does:
  `.va_r3_phylo_structure(tree, species_levels)`, which calls `.gllvm_phylo_tree_precision(
  tree, correlation = TRUE)` — "the SAME builder, the same `correlation = TRUE` scaling and
  the same node ordering the shipped Laplace engine uses" (`R/va-r3-proto.R`, comment above
  `.va_r3_phylo_structure`). **Settled, not re-derived here: `n_aug = 2N - 2`** (tips plus
  internal nodes minus the root, for a rooted bifurcating tree — do not use the prior draft's
  approximate `2N - 1`).
- Build the **tips-only** precision via the maintainer-supplied recipe (§Correction after
  maintainer review, copied verbatim into the implementer's script):
  ```r
  A   <- ape::vcv(tree, corr = TRUE)[sp, sp] + diag(1e-8, N)
  st  <- list(Ainv = solve(A),
              log_det_A = as.numeric(determinant(A, logarithm = TRUE)$modulus))
  lid <- unit - 1L
  ```
- **Do not hand-build a third, independently-coded precision for the DGP.** Truth is generated
  from whichever precision the fitting route under test actually uses (augmented for the
  augmented arms, tips-only for the tips-only arm) — using a mismatched precision for
  simulation vs. fitting would let numerical differences between two "equivalent" objects
  masquerade as an engine-comparison result. Where the two routes are compared against each
  other's own recovery (both against the SAME planted truth, computed once per replicate from
  the tree's true correlation structure, independent of which route's precision happens to be
  used for fitting), the truth used for `rel_frob` is always the population-level `Sigma_B`
  from the drawn `Lambda`, not a route-specific reconstruction.
- Truth for the phylogenetic tier's latent scores is generated by drawing `z1` on the tree
  consistent with `A_phy^{-1}` (equivalently, simulate via the standard pruning-algorithm /
  independent-contrasts machinery), then restricting to tip rows for the response.

### Parameter values ("how truth is fixed")

Truth is **known exactly per replicate, by construction** — the parameter vector used to
simulate that replicate's data, not an estimated or asymptotic quantity. Per replicate:

- `Lambda0` (T x q0) and `Lambda1` (T x q1): each entry drawn iid `N(0, sigma_lambda^2)`,
  reusing the "homog" DGP shape from `dev/heywood/link-coverage.R` via `dev/design108-stage8/
  README.md`'s convention (explicitly the *least adversarial* of the three published DGP
  shapes there). `sigma_lambda` is a grid factor (§Design grid).
- `psi0`, `psi1` (T-vectors, diagonal component): **PROPOSAL, not fixed by any cited
  document** — propose `psi ~ Uniform(0.1, 0.5)` per trait, comparable in scale to
  `sigma_lambda = 0.7`'s loading variance. **Requires the maintainer's confirmation before the
  grid is bought.**
- Trait intercepts (`beta`, T-vector): drawn `N(0, 0.3)` per `dev/design108-stage8/README.md`'s
  convention. **Flagged caveat, unchanged from the prior draft:** that convention was
  calibrated for a **logit** link; Design 108 §0.2's "logit evidence does not transfer to
  probit" cuts equally against reusing a logit-calibrated intercept SD for probit. **PROPOSAL,
  requires confirmation**, and the smoke test (§Stopping/abort rules) must report the realised
  prevalence distribution before the grid is trusted.
- `n_trials` (binomial denominator): **PROPOSAL** — default to `n_trials = 1` (Bernoulli,
  presence/absence), matching the motivating real dataset's shape.

**On the "67% runaway" figure — settled, not re-derived, and now more precisely scoped than
the prior draft stated it.** The maintainer's round-2 brief settles that the 67%-of-fits
runaway figure "needs logit AND p=6 TOGETHER" — i.e. it is specific to the binomial-**logit**
link at `p = 6` traits, not a general property of `sigma_lambda = 3` alone, and not something
that transfers to this campaign's binomial-**probit**, `T in {20,...,30}` envelope. This
campaign still uses `sigma_lambda = 3.0` as its "hard" DGP regime (it remains a real,
non-adversarially-invented hard case on record in `R/gllvmTMB.R:909-911`), but **does not**
carry forward any expectation, stated or implied, that a 67% (or any other specific) runaway
rate applies here. `aghq_ridge` is opt-in and Laplace-path-only (settled); this campaign does
not use it as a factor (it compares unmodified Laplace to VA-R3, not a ridge-corrected Laplace
arm).

### Held fixed within a cell, across seeds

The tree topology and precision are redrawn **fresh per seed** within a cell (not fixed across
the seed ladder), to avoid confounding "sampling variability given a fixed topology" with
"topology-dependent behaviour of the structured KL." **PROPOSAL, flagged for the maintainer**:
an alternative — one shared tree per cell with per-seed response redraws only — would reduce
simulation variance at fixed seed count but conflate topology effects into a single
realisation; this protocol's default is the more conservative (fresh-tree) choice.

### Missingness

Out of scope, as in the prior draft. `dev/design108-stage8/README.md` already measures
Laplace's silent-divergence rate under missingness on the unstructured tier; adding it here
would cross another factor into an already large grid (non-negotiable 4 makes every added axis
a reporting-by-cell cost, not just a compute cost) without answering this campaign's specific
question. Complete data only.

---

## E — Estimands

Primary:

- `Sigma_B0 = Lambda0 Lambda0'` (T x T), the ordinary tier's between-species covariance.
- `Sigma_B1 = Lambda1 Lambda1'` (T x T), the phylogenetic tier's between-species covariance.

Secondary:

- `Lambda0`, `Lambda1` directly, **only** via the trace/shape decomposition in §Analysis plan
  (Design 109 falsification item 7) — raw loading entries are not rotation-identifiable for
  `q > 1` and must not be compared element-wise between engines or to truth.
- `diag(psi0)`, `diag(psi1)` — directly identifiable (no rotation ambiguity); element-wise
  comparison to truth is valid.
- Total tier covariance `Sigma0_total = Sigma_B0 + diag(psi0)`,
  `Sigma1_total = Sigma_B1 + diag(psi1)`.

**Explicitly not an estimand: `S_i`.** `S_i` is the per-unit variational **posterior**
covariance (Design 109 line 58), not the between-unit prior covariance `Sigma_B`. Design 109
states this conflation is "the trap in this problem, and the whole result turns on keeping
them apart" (line 44) — the same word "trap" the maintainer's round-2 brief independently uses
for the VA-vs-Laplace-agreement failure mode above; the two traps are different failure modes
that happen to share a name, and this campaign guards against both. **This campaign never
reports `S_i` (or any function of it) as evidence about `Sigma_B` recovery.**

---

## M — Methods / arms

All arms fit the identical two-tier formula shape. The internal VA-R3 prototype path is
exercised directly via `.va_r3_fit(..., structured = <precision>, extra_tiers = <phylo tier
spec>)`, since VA-R3 is not wired through the public formula parser (Gate A Stage 7 is
prototype-path only).

1. **Laplace (shipped engine).** `gllvmTMB()` with the two-tier formula
   (`latent(0 + trait | species, d = q0, unique = TRUE) + phylo_latent(0 + trait | species,
   d = q1, unique = TRUE)`), shipped Laplace/AGHQ path. Reference arm.
2. **VA joint, augmented node set (`profile_variational = FALSE`).** `.va_r3_fit(...,
   structured = <augmented precision>, profile_variational = FALSE)`. **Restricted to N ≤ 1500
   (non-negotiable 6)** — not run in Part B.
3. **VA profiled, augmented node set (`profile_variational = TRUE`).** Same data, augmented
   precision, `profile_variational = TRUE`. **Run at every N in the ladder, mandatory above
   N ≈ 1500 (non-negotiable 6).** This is the arm that isolates optimiser-path effects from
   objective-form effects when compared against arm 2 within Part A (both arms share the same
   objective; only the outer optimiser's view of the variational block differs) — the same
   logic Design 109's cross-evaluation check exists for.
4. **VA, tips-only node set — restored as first-class (§Correction above).** `.va_r3_fit(...,
   structured = <tips-only precision, per the maintainer's recipe>)`. Run `profile_variational
   = TRUE` throughout (given the route's own `O(N^2)` cost, joint mode at the tips-only route's
   already-larger footprint is not expected to be affordable anywhere in the ladder worth
   spending budget confirming — **PROPOSAL**, revisit if the smoke test shows otherwise).
   **Cost is measured, not assumed:** `tests/testthat/test-va-r3-structured-phylo.R:395-440`
   already demonstrates the augmented route's inner-Hessian fill is flat in tip count while the
   tips-only route's grows — this campaign's smoke test (§Stopping/abort rules) extends that
   same measurement to campaign scale and **reports the N at which tips-only stops being
   affordable as a first-class result of Aim 3**, not a reason to have skipped the arm.
5. **External `gllvm` package — CONDITIONAL, optional, and not a like-for-like ablation.**
   Unchanged from the prior draft: `gllvm`'s phylogenetic VA uses an NNGP approximation
   (Design 72 §1.3, TO-VERIFY there), a genuinely different structured approximation from
   gllvmTMB's exact sparse `A^{-1}`. If included, it answers "is gllvmTMB's exact-precision
   route competitive with the established alternative," a different question from arms 2–4.
   Size separately before committing.

**Health measurement, for every arm (constraint carried from the prior draft, still
non-negotiable):** recovery is judged **only** by `rel_frob` against known truth.
`convergence`/`pdHess` flags are recorded and reported but never used to decide whether a fit
"worked" — 425 of 511 degenerate fits in the prior campaign reported clean flags
(`docs/dev-log/2026-07-30-heywood-gate-false-positive-sweep.md`).

---

## P — Performance measures

Primary:

- `rel_frob_k = ||Sigma_Bk_hat - Sigma_Bk_true||_F / ||Sigma_Bk_true||_F` for `k in {0, 1}`,
  per fit, per arm — **always against planted truth, never engine-vs-engine** (the trap).

Secondary:

- **Signed trace bias**, per Design 109's falsification item 2: `mean(trace(Sigma_Bk_hat) -
  trace(Sigma_Bk_true))` per tier, per arm, per cell, plus the elementwise signed bias matrix.
- **Degeneracy rate**, defined against truth: `degenerate := rel_frob > 10` (either tier),
  `silent_divergent := degenerate & convergence == 0 & pdHess == TRUE` (or VA's analogous
  diagnostic; if VA has no `pdHess`-equivalent, record that gap explicitly rather than
  substituting a different flag). **Every reported rate carries a Wilson 95% interval
  (non-negotiable 7)**, reused verbatim from `dev/design108-stage8/analyse-silent-divergence.R`
  lines 41–47:
  ```r
  wilson <- function(x) {
    x <- x[!is.na(x)]; n <- length(x); if (!n) return(c(NA, NA))
    p <- mean(x); z <- 1.96; den <- 1 + z^2 / n
    ctr <- (p + z^2 / (2 * n)) / den
    hw  <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / den
    round(100 * c(max(0, ctr - hw), min(1, ctr + hw)), 1)
  }
  ```
- `diag(psi)` recovery: elementwise bias and RMSE against truth, per tier, per arm.
- **ELBO-vs-Laplace-logLik gap — SEPARATE secondary result.** `gap = logLik_laplace_hat -
  ELBO_va_hat`, both at each method's own optimum, per cell, per VA arm. Its own table, never
  merged with a `rel_frob` table, never regressed against `rel_frob` (Expectation 3, the
  trap). Also inherits Design 72 §4 point 1's caveat that `logLik()`/`AIC()` are not
  comparable across `method = "LA"` vs `"VA"`.
- Wall-clock (per fit) and peak RSS (per fit), both engines, both node-set routes, across the
  N-ladder — feeds Aims 3 and 5.

---

## Design grid

**N-ladder (non-negotiable 5).** Following `dev/design108-stage8/README.md`'s own Part A /
Part B precedent and its two-round, measurement-driven cost revision:

- **Part A (moderate N, full factorial):** `N in {500, 1500}`. Arms 1–3 (Laplace, VA-joint,
  VA-profiled) and, cost permitting, arm 4 (tips-only) all run here; N = 1500 is the boundary
  named in non-negotiable 6, so Part A is where the joint-vs-profiled optimiser-path
  comparison (arm 2 vs arm 3) is actually possible.
- **Part B (envelope-scale, narrower factorial, gated):** `N in {5000, 10000}`. **Only arms
  1 and 3 (Laplace, VA-profiled) are committed here** — arm 2 (VA-joint) is out of scope above
  N = 1500 by non-negotiable 6, and arm 4 (tips-only) runs only as far as the Part A / smoke
  measurement shows it remains affordable (§M arm 4; do not assume it reaches Part B without
  evidence). Launched only after Part A's results and a dedicated scale-gate smoke test
  (§Stopping/abort rules) confirm affordability.

**T (trait count):** `{20, 30}` in Part A; `T = 27` only in Part B (Ayumi's real trait count,
`N = 5397, p = 27` per Design 108 Stage 8/9's anchor).

**`q` — a real grid column, load-bearing under non-negotiable 4/5, not cosmetic.** The prior
draft already made this a column; the maintainer's brief confirms this is exactly the axis a
prior sister-lane pooling failure (#897) turned on, so it stays a column and every reported
result is broken out by `q`, never averaged across it. `q in {1, 2, 3}` applied symmetrically
(`q0 = q1 = q`) in Part A; Part B holds `q = 2` only (the motivating case), with asymmetric
`q0 != q1` and a Part-B `q` sweep flagged as stretch goals contingent on Part A's budget
headroom.

**`sigma_lambda`, paired across tiers:** `{0.7 mild, 3.0 hard}`, per `dev/design108-stage8/
README.md`'s two regimes — see §D's corrected note on what the `sigma_lambda = 3.0` /
"67%" figure does and does not imply for this campaign's family/T.

**Family:** binomial-probit (the substantive question) **plus `gaussian_control` (the
required positive control, non-negotiable 3)**, both fit at every N/T/q/sigma_lambda cell.
This is a change from the prior draft, which fixed family to binomial-probit alone; the
control is not optional overhead, it is the gate the whole campaign's interpretability rests
on.

**Missingness:** none (0%), fixed.

**Total cell count (before seeds), reflecting arms 1–3 as committed and arm 4 as
smoke-gated:**

- Part A: `N(2) x T(2) x q(3) x sigma_lambda(2) x family(2, binomial-probit +
  gaussian_control) = 48` cells, each under 3 committed arms (Laplace, VA-joint, VA-profiled)
  = 144 fit-cells, plus arm 4 wherever the smoke test clears it.
- Part B: `N(2) x T(1) x q(1) x sigma_lambda(2) x family(2) = 4` cells x 2 committed arms
  (Laplace, VA-profiled) = 8 fit-cells, launched only after the scale gate passes, plus arm 4
  only as far as it remains affordable.

**Do not pool any of these axes when reporting (non-negotiable 4).** Every table in
§Analysis plan is indexed by cell, or by one axis with all others held fixed in the panel
(the `tapply(..., list(n, arm))`-per-family idiom `dev/design108-stage8/
analyse-silent-divergence.R` already uses), never averaged across N, T, q, sigma_lambda, or
family in a single summary number.

---

## Number of seeds/repetitions, and its MCSE justification

Unchanged in method from the prior draft; the pilot mechanism is now tied explicitly to
existing tooling rather than left to be invented.

**House convention** (`docs/design/2026-07-31-aghq-estimator-campaign-ADEMP.md` §D.3, paired
design per non-negotiable 2): because every arm is fit to the **same simulated dataset**
within a seed, the primary contrast is a within-replicate paired difference, and its MCSE uses
the SD of the paired differences:

```
d_i = rel_frob_VA(tier k, seed i) - rel_frob_Laplace(tier k, seed i)
MCSE(mean(d)) = SD(d_i) / sqrt(n_sim)
n_sim >= (3 * SD(d) / delta)^2
```

For proportions (degeneracy rate), worst-case planning variance: `MCSE(p_hat) <= 0.5 /
sqrt(n_sim)`.

**No pilot SD exists yet for this two-tier structured comparison.** `n_sim` cannot be honestly
fixed by this protocol; it must be computed from a pilot.

**Pilot mechanism — reuse the existing GRID_* filters, do not invent a new one.**
`dev/design108-stage8/laplace-silent-divergence.R` (lines ~134–140) already implements exactly
the "cost one corner before committing to a grid" mechanism this pilot needs:
`GRID_FAMILY`/`GRID_N`/`GRID_SIGMA`/`GRID_MISS`/`GRID_SEEDS` environment variables filter the
full grid down to one cell before the run. **The implementer should extend this same idiom**
(add `GRID_Q`, `GRID_ARM`, `GRID_TIER` filters as needed for this campaign's extra axes)
rather than writing a bespoke pilot harness. Procedure:

1. `GRID_N=500 GRID_SIGMA=0.7 GRID_Q=1 GRID_FAMILY=binomial_probit GRID_SEEDS=10` (Part A's
   cheapest structural cell) — run 10 seeds, all committed arms.
2. Compute `SD(d_i)` for the paired `rel_frob` difference on tier 1 (the phylogenetic tier,
   the primary estimand) from those 10 seeds.
3. Choose `delta` — **PROPOSAL:** `delta = 0.1` on `rel_frob` units, requiring the
   maintainer's confirmation, unchanged from the prior draft.
4. Solve `n_sim >= (3 * SD(d) / 0.1)^2` and round up.

**Provisional planning numbers, pending that pilot, unchanged from the prior draft and still
flagged as placeholders, not derived quantities:** `n_sim = 30` per cell for Part A, `n_sim =
15` per cell for Part B. **The pilot is a hard gate before the grid is bought** — do not launch
Part A's full seed count without having run step 1–4 above first.

---

## Stopping / abort rules, and what a smoke test must show before the grid is bought

**Rule 0:** no go/no-go decision in this section may be made from `convergence`/`pdHess` flags
alone. Every gate below requires an explicit `rel_frob` (or, pre-fit, a data-generation sanity
check) reading.

**Rule 0b (non-negotiable 3, restated as a hard gate, not a soft check):** at every stage below
— smoke, Part A launch, Part B launch, and final write-up — the `gaussian_control` cells at
the N/T/q/sigma_lambda combination in question must show near-truth `rel_frob` (both engines)
before any binomial-probit rate from that same combination is reported. If the control fails
at a given cell, that cell's substantive results are held back and reported as "instrument
unreliable at this cell," not silently included in a pooled or partial summary.

**Smoke test, required before Part A launches:**

1. One seed at Part A's smallest cell, all committed arms including the positive control
   family, run to completion.
2. Confirm the DGP produces a plausible prevalence distribution under the probit link (the
   flagged `N(0, 0.3)` caveat, §D). Report realised min/median/max fitted prevalence.
3. Confirm `n_aug` matches the settled `2N - 2` for the simulated tree at this N (augmented
   route), and record the resulting parameter/coordinate count for every arm including
   tips-only.
4. Confirm every arm produces **finite, non-`NA`** `rel_frob` for both tiers and both
   families.
5. Record wall-clock and peak RSS at this smallest cell, for every arm including tips-only, as
   the first anchor point for a power-law cost extrapolation — this is also the first data
   point toward Aim 3's tips-only-crossover measurement.

**Gate before Part B launches (the scale gate, Aim 5):**

1. A **second, real measured anchor** at or near Part B's smallest cell (`N = 5000`), Laplace
   and VA-profiled, both families — not an extrapolation. Confirms or refutes Design 108 §9's
   flagged `~52 GB` dense-quasi-Newton concern (moot for the profiled-only Part B arms, but the
   measurement itself is still the thing that resolves whether the concern was ever real).
2. If measured cost implies Part B's full grid exceeds available compute (Totoro's shared
   ≤100-core ceiling; DRAC as fallback), cut seeds at the expensive rung first, or drop
   N = 10000 and report N = 5000 as the achieved upper end, rather than cutting uniformly.
3. If either committed engine fails to produce a finite `rel_frob` at N = 5000, Part B does not
   launch for that engine until the failure is diagnosed.

**Tips-only affordability determination (Aim 3), specific gate:** extend the smoke
measurement's wall-clock/RSS anchors for arm 4 across as much of the N-ladder as remains cheap
to probe (following `test-va-r3-structured-phylo.R`'s own `{20, 40, 80}`-tip scaling-check
pattern, scaled up). **Report the N at which tips-only's cost exceeds a stated multiple (e.g.
10x) of the augmented route's cost at the same N as a headline number of this campaign**, not
a footnote explaining an exclusion.

**Abort mid-grid:** if the pilot's `SD(d)` turns out large enough that the recommended
`n_sim` for `delta = 0.1` exceeds Part A's budget, raise `delta` and re-justify it explicitly
— do not silently under-power by capping `n_sim` below the formula's requirement.

---

## Analysis plan

**Standing rule, restated here as instructed (the trap):** every recovery comparison in this
analysis is `estimate` vs `planted truth`. `rel_frob(VA_hat, Laplace_hat)` — engine-vs-engine
agreement — is never used as, or presented alongside, an accuracy claim. If it is computed at
all (e.g. as a diagnostic for why two engines land in the same place despite both missing
truth), it is labelled "agreement, not accuracy" in its own table, disjoint from every
truth-based `rel_frob` table. Quoting the standing instruction: *"agreement between two
approximations is not accuracy."*

**Reporting rule (non-negotiable 4):** every table below is indexed by cell — at minimum by
`(N, arm, family)`, and by `(N, q, sigma_lambda, arm)` for the primary comparison. No table in
this campaign's write-up reports a single number averaged across N, T, q, sigma_lambda, or
family. Where a summary across one axis is useful for readability, it is a panel of numbers
(one per level of the other axes held fixed), following `dev/design108-stage8/
analyse-silent-divergence.R`'s `tapply(x, list(n, arm), pct)`-per-family idiom, never a
collapsed grand mean.

**Primary comparison, per tier (`k = 0, 1`), per cell:**

- Paired difference `d_i = rel_frob_VA_arm(tier k, seed i, cell) -
  rel_frob_Laplace(tier k, seed i, cell)`, for each VA arm separately (joint where run,
  profiled, tips-only where affordable, gllvm if built).
- Report `mean(d)`, `MCSE(mean(d))`, and a paired sign test per cell (Design 109's own
  convention: "20/20 on a paired sign test is `p ≈ 2e-6`... a systematic shift... and not what
  noise produces").
- Report the **signed trace bias** table alongside every `rel_frob` table (Design 109
  falsification item 2) — loss-only reporting cannot distinguish real improvement from a
  smaller-magnitude two-wrongs cancellation.
- **Scale/shape decomposition** (Design 109 falsification item 7): trace (scale) vs
  correlation-matrix (shape) error, per tier, per arm, per cell. Expectation 1 predicts the
  bias concentrates in scale; a result that shows up in *shape* instead falsifies the
  shrinkage account for this tier and must be reported as such.

**Secondary reporting (non-inferential, kept structurally separate from the primary tables):**

- ELBO-vs-Laplace-logLik gap table.
- Degeneracy/silent-divergence rates by cell, **each with a Wilson 95% interval**
  (non-negotiable 7), using the `wilson()` function given verbatim in §P.
- Wall-clock/RSS scaling curves for both engines and both node-set routes across the N-ladder,
  including the tips-only-crossover number (Aim 3).

**Forbidden inferences — stated explicitly so a later reader cannot smuggle them back in:**

1. **Do not infer recovery quality from the ELBO-vs-Laplace-logLik gap**, or from convergence
   flags, or from `pdHess`.
2. **Do not use `S_i` (or any `S_i`-derived quantity) as evidence about `Sigma_B` recovery.**
3. **Do not generalise beyond binomial-probit.** Design 108 §0.2's "logit evidence does not
   transfer to probit" cuts both directions; a probit result here says nothing about logit or
   any other family/link without its own validation.
4. **Do not draw a `q`-independent conclusion from one `q` cell**, and do not pool across `q`
   (or any other axis) into a single reported rate or mean (non-negotiable 4 — the specific
   failure mode issue #897 was overturned for).
5. **Do not claim VA is "better," "faster," "state of the art," or any unqualified capability
   superlative from this campaign**, even if the primary result favours VA. A single-grid win
   is "a bias-cancellation observed at one design point," not "a property of the engine"
   (Design 109's Verdict section).
6. **Do not treat this campaign as re-validating the Laplace-ridge remedy.** Different
   question, already scoped elsewhere (`dev/design108-stage8/`); this campaign compares
   unmodified Laplace to VA-R3.
7. **Do not report a substantive rate from any cell where the positive control failed at that
   cell** (non-negotiable 3) — report "instrument unreliable," not a number with an asterisk.
8. **Do not compute or report VA-vs-Laplace agreement as an accuracy measure** (the trap,
   restated as a forbidden inference so it is enforceable the same way the other seven are).

**What would make the primary result trustworthy enough to write up (not just "computed"):**
the paired sign test direction should be consistent across at least the `q` levels within
Part A; the scale/shape decomposition should show the effect concentrated in scale if
Expectation 1's mechanism is operative (a shape-concentrated effect falsifies that account and
must be reported as such, not rationalised into the pre-registered story); and the positive
control must have cleared its gate at every cell contributing to the result being written up.

---

## Open items requiring the maintainer before this campaign is bought

1. `psi` magnitude for the DGP (§D) — no cited document fixes this; a proposal is given.
2. Whether `N(0, 0.3)` trait intercepts (borrowed from a logit-link campaign) are acceptable
   for probit, or need probit-specific calibration before the smoke test is trusted.
3. Whether the phylogenetic tree should be redrawn per seed (this protocol's default) or fixed
   per cell.
4. `delta = 0.1` for the seed-count MCSE justification — a proposal pending the pilot's actual
   `SD(d)`.
5. Whether the external `gllvm` comparator (arm 5) is in scope for this campaign's launch, or
   deferred as its own separately-sized follow-up. (Arm 4, tips-only, is no longer an open
   item — it is committed, per the correction above; only its N-ladder reach is genuinely
   unknown ex ante, and that unknown is itself Aim 3, not a scoping question.)
6. `gaussian_control`'s residual SD (0.4, proposed) and whether crossing it through the full
   `q`/`sigma_lambda` grid (as this revision now requires, non-negotiable 3) is affordable
   within the same budget as the substantive binomial-probit grid, or needs its own smoke-gated
   sizing pass.

---

## Tensions the maintainer should resolve explicitly, not have silently resolved

- **Non-negotiable 3 (positive control crossed through the full grid) enlarges the grid
  non-trivially** — Part A's cell count roughly doubles (24 → 48) once `gaussian_control` is
  crossed through every `N x T x q x sigma_lambda` combination rather than checked once. This
  protocol resolves the tension by making the control a full grid citizen rather than a
  cheaper spot-check, on the reading that non-negotiable 3's own wording ("no other rate in
  the campaign is interpretable") requires the control to be present at the *same* cells the
  substantive rates are reported for, not just at one representative cell. **If budget does
  not support this, the correct response is to shrink another axis (e.g. Part A's `q` ladder
  to `{1, 2}`), not to thin the control's coverage** — but that is a real trade-off the
  maintainer may want to make differently.
- **Non-negotiable 6 (profiled-only above N=1500) removes the joint-vs-profiled optimiser-path
  comparison exactly where it would matter most** (large N, closest to the envelope). This
  protocol accepts that trade explicitly rather than resolving it quietly: Part A answers
  "does profiling change the estimate at moderate N," Part B cannot answer that question at
  all, only "does the profiled estimate recover well at scale." If the maintainer wants the
  joint-vs-profiled question answered at envelope scale too, that requires either relaxing
  non-negotiable 6 for a narrow probe or accepting the memory-wall risk it exists to avoid —
  this protocol does not choose that for the maintainer.
- **Arm 4's restoration plus non-negotiable 4/5 (report by cell, use the full N-ladder) means
  tips-only may need to be measured at N values where it is already known to be the more
  expensive route**, purely to establish the crossover point (Aim 3) rather than because a win
  there is expected. This is a deliberate use of budget to answer a cost question, not an
  accuracy question, and could be seen as competing with Part B's accuracy-focused budget under
  a fixed total compute allowance — flagged, not resolved, here.

---

## Ada's recommendations on the three tensions above

Added by the orchestrating session so the maintainer sees each decision **with** a
recommendation rather than as an open prompt. Each is a proposal, not a resolution — the
tensions above stand as written.

**1. Positive control — keep full coverage, spend fewer seeds.** The tension is real but it
is being paid on the wrong axis. The control's job is to **gate interpretability** ("is this
cell's machinery behaving at all?"), not to estimate a rate precisely. Detecting *"the
control is not clean"* needs far fewer replicates than estimating a recovery contrast.
So: cross `gaussian_control` through **every** cell as the protocol says, but at roughly
**one-third the seeds** of a substantive cell. That preserves exactly the property
non-negotiable 3 demands — a control at the *same* coordinates as every reported rate — while
costing ~16 cell-equivalents rather than ~24. It varies the cheap axis (seeds) instead of the
load-bearing one (coverage), which is why it is preferred to shrinking the `q` ladder.
*Caveat:* if a control cell fails, re-run **that** cell at full seeds before concluding
anything from it — a 10-seed failure is a trigger to look, not a verdict.

**2. Joint-vs-profiled at scale — reframe as a bridge, because it is not a free choice.**
This one is mis-stated as a trade-off. The joint route is not merely discouraged above
N≈1500; it is **arithmetically impossible** at the envelope — the measured outer-problem
memory is ~1,127 GB at N=5,000 and ~4,508 GB at N=10,000. So non-negotiable 6 is not removing
a comparison that could otherwise have been made; it is naming one that cannot be.
The recoverable version: measure **joint-vs-profiled agreement at the TOP of Part A**
(N≈1,500), where both routes still run, and treat that as the **bridge** licensing the
profiled-only Part B. If they agree there, Part B's profiled-only design is defensible and
should say so citing the bridge. **If they disagree, that disagreement is itself a primary
finding** and must be reported rather than absorbed — it would mean the profiled route
changes the estimate, not just the memory profile. This costs one extra paired cell and
converts an unanswerable question into a measured warrant.

**3. Tips-only — cap it to Part A, and extrapolate the crossover.** Arm 4 has exactly two
jobs: test Design 106 §3.6's ELBO prediction, and pin the cost crossover. **Both are
answerable where tips-only is still affordable.** Its inner solve is O(N^2) and Stage 7
already measured the densification directly (`nnz/dim` 6.76 → 7.72 → 11.36 against a flat
4.35 → 4.28 for augmented), so spending Part B budget to re-confirm a loss we can already
predict is poor value. Recommendation: **run Arm 4 across Part A only**, report the crossover
as an extrapolation from the Part A ladder *plus* the Stage 7 sparsity measurements, and state
plainly that it is an extrapolation. The §3.6 ELBO question is unaffected — it is a statement
about the bound, not about scale, and is best measured where both routes fit comfortably.
*Do not*, however, let this be read as evidence tips-only is statistically worse: per Design
109, cost and recovery are separate axes, and §3.6 remains genuinely open.
