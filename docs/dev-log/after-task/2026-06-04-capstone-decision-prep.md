# Decision-prep: capstone power-study spec freeze (Design 66 / #369)

**Branch**: `claude/capstone-decision-prep`
**Date**: `2026-06-04`
**Roles (engaged)**: Rose (scope honesty), Fisher (validation design), Ada (coordinator)
**Type**: ADVISORY / decision-prep. Read-only on Design 66 and on the
`agent/capstone-power-study` branch. This memo drafts RECOMMENDED answers
to the seven freeze-blocking questions in Design 66 sec.12 with rationale;
the **maintainer makes the actual calls**.

## 0. Purpose and what changed since the draft

PR #369 froze a draft of Design 66 on 2026-05-31 with seven open questions
(Q-a..Q-g) blocking the spec freeze. This memo exists so the maintainer can
unblock the freeze in one pass on return, rather than re-reading the full
ADEMP pre-spec.

**The single most important update:** the capability board (#340) was
refreshed 2026-06-03 (v0.2.0 tag-prep) and again 2026-06-04, and the
register tally is now **166 C / 20 P / 0 opt-in / 7 B over 193 rows**. Two
of the draft's open questions were written against a *staler* capability
snapshot and their default answers are now out of date:

- **Coevolution / kernel is BUILT and covered.** KER-02
  (`kernel_unique/indep/dep/latent`), KER-01 (`make_cross_kernel()`), and
  COE-02 (`extract_Gamma()`, validated cross-lineage coevolution engine)
  are all `covered` as of #361, with a published `cross-lineage-coevolution`
  article. Design 66's Q-e default ("deferred -- the `kernel_*()` engine is
  not built on origin/main") is **factually stale**. The decision is no
  longer "can't, so defer"; it is now a genuine scope choice.
- **Non-Gaussian random slopes are COMPLETE** (#388/#392/#422/#424/#427/#429),
  every supported family x structured mode. Design 66 sec.4.4 still says
  "non-Gaussian slopes are engine-deferred"; that constraint no longer
  holds, which widens what a slope extension *could* cover (though it does
  not change the recommendation to keep slopes an extension, not core).
- **nbinom1 (FAM-07) is `covered`** (wired #441-line, fid 15), and gamma +
  ordinal recovery-depth cells went `covered` 2026-06-04 (#443). The
  4-family core subset is still defensible, but "all wired families" is a
  larger and more real set than the draft implied.

The MCSE arithmetic, the rotation-invariant estimand discipline (PR #364),
and the compute-budget shape are unchanged and remain correct.

---

## 1. RECOMMENDED answers (one line each)

| Q | Topic | RECOMMENDED |
|---|---|---|
| Q-a | Compute: HPC vs GHA | **HPC / large cloud allocation for the production sweep; GHA only for pilot + aggregation.** GHA-only is not viable for the core. |
| Q-b | Core: ~50-cell spoke vs full 192 | **~50-cell backbone-plus-spokes core.** Stage the full cross only if HPC headroom is confirmed. |
| Q-c | Headline claims + gate | **Adopt H1-H4 as written; gate at 94% (the existing audit-1 threshold), report against 95% nominal.** |
| Q-d | n_sim final | **n_sim = 2000 for core gate cells; 1000 for extension tiers.** |
| Q-e | Coevolution / Gamma in scope | **In scope as a bounded Tier-3 extension (engine is now covered), gated on the core passing -- NOT core.** |
| Q-f | Core 4-family subset vs all 14 | **4-family representative core (gaussian, nbinom2, binomial-probit, ordinal-probit); remaining families as the Tier-1 extension, mixed-family included.** |
| Q-g | "moderate"/"strong" signal | **Define signal as a between-unit variance share of total trait variance: absent=0, moderate≈0.25, strong≈0.50, fixed identically across RE sources.** |

---

## 2. Per-question rationale and trade-offs

### Q-a -- Compute: HPC cluster vs GHA-only

**RECOMMENDED:** Run the production sweep on an HPC cluster or a large
cloud spot allocation; use GHA only for the pilot (n_sim=10 smoke) and for
aggregation/reporting.

**Rationale.** Design 66 sec.8 costs the *cheapest* viable scenario --
core spoke design, 50 cells, n_sim=1000, n_boot=100 -- at ~5.05e6 fits,
which is ~117 single-core-days, i.e. roughly a cluster-day on ~128 cores.
The M3 workflow shards `family x d` into 4 shards x 5 max-parallel on
`ubuntu-latest` under a 120-min job cap; that absorbs the R=200 smoke but
cannot absorb 10^6-10^7 fits. The bootstrap `(1+n_boot)` factor is the
dominant cost driver, and it is intrinsic to the rotation-invariant
estimand (the bootstrap CI is the gate-bearing interval, PR #364), so it
cannot be cut without weakening the gate.

**Trade-off / if GHA-only.** GHA-only forces a cascade of cuts that, taken
together, hollow out the study: drop to n_sim≈500 (coverage MCSE 0.97pp,
back into the can't-adjudicate-94-vs-95 zone the whole exercise is meant to
escape), n_boot≈25, and a handful of cells. At that point the capstone is a
larger M3 smoke, not the CRAN/paper adjudication gate. Recommend treating
"is HPC available?" as the gating logistics question for the whole
milestone -- if the answer is no, the realistic move is to descope the
*claims* (H3 power curve becomes illustrative, not certified) rather than
pretend GHA can carry the sweep.

**Uncertainty.** The 2 s/fit vs 20 s/fit spread is 10x; the true number
must come from the pilot's `mean_runtime_s` before any allocation is
committed. nbinom2/mixed/ordinal cells with bootstrap are the slow tail.

---

### Q-b -- Core grid: ~50-cell spoke vs full 192-cell cross

**RECOMMENDED:** Use the ~50-cell backbone-plus-spokes core (hold the
backbone at `gaussian, phylo_dep, d=1, n=150, moderate signal`, walk each
factor singly). Promote to the full 192-cell cross only if Q-a confirms
HPC headroom after the pilot calibrates fit time.

**Rationale.** The full cross is 4 x 4 x 2 x 2 x 3 = 192 cells; at n_sim=2000,
n_boot=100 that is ~3.88e7 fits = multi-CPU-year (sec.8), realistic only on
serious HPC. The spoke design (~40-60 cells) is the single biggest cost
lever after compute itself, and it still exercises every level of every
axis at least once against a well-understood backbone -- which is what H1-H4
actually require (each claim is "does coverage/power/Type-I hold as we move
this one axis", not "does every interaction hold"). Confirmatory simulation
practice (Morris et al. 2019) favours a defensible fractional design over an
unaffordable full factorial.

**Trade-off / if full 192.** The full cross buys interaction coverage
(e.g. does ordinal-probit x spatial_dep x d=2 specifically misbehave) that
the spoke design samples only at the backbone. That is real evidence, but
it costs ~8x the core and is mostly redundant for the headline claims. The
honest compromise: spoke core for the gate; if a spoke cell shows a
near-miss, *locally densify* around that cell rather than running the whole
cross.

**Uncertainty.** "~50" is a target, not frozen -- the exact spoke list must
be pinned against the then-current `covered` ledger at dispatch (sec.4.2),
and replicate-structure cells (RE-09) add rows that are correctness
constraints, not free knobs.

---

### Q-c -- Headline claims and the 94% vs 95% gate

**RECOMMENDED:** Adopt H1-H4 (sec.2) as the exact claim set. Keep the gate
at empirical coverage >= 0.94 (the existing audit-1 / `M3_PASS_GATE`
threshold in `dev/m3-grid.R`), and report each cell's coverage point
estimate with its MCSE against the 95% nominal line.

**Rationale.** 94% is already the live, code-enforced gate; PR #364 keys it
on the rotation-invariant `Sigma_unit_diag` bootstrap, so adopting it keeps
the capstone continuous with the M3 surface it certifies-at-scale rather
than introducing a second, stricter standard mid-study. The 1pp slack
between 94% gate and 95% nominal is an honest acknowledgement of finite
Monte Carlo and bootstrap-interval noise; at n_sim=2000 the coverage MCSE is
0.49pp (sec.7.1), so a true 95% cell clears 94% comfortably and a genuinely
under-covering 92% cell is distinguishable. The claims stay falsifiable:
H1 coverage, H2 |rel bias|<5%, H3 a *power curve* (not a pass/fail), H4
Type-I ≈ alpha.

**Trade-off / if strict 95%.** A strict 95% gate is a stronger paper claim
but materially raises failure risk: any cell that genuinely sits at 94.0-94.9%
(plausible for the hard nbinom2/ordinal/mixed paths) would "fail" a 95%
gate while being statistically indistinguishable from nominal at n_sim=2000.
That would force either more n_sim (cost) or honest "partial" reporting on
cells that are fine. Recommend 94% gate + transparent 95%-referenced
reporting as the defensible middle: the gate is achievable, the table tells
the whole truth.

**Uncertainty.** Whether reviewers/CRAN read a 94% gate as "95% intervals"
is a presentation question; the mitigation is already in the spec (report
the MCSE on every number, state the gate explicitly).

---

### Q-d -- Final n_sim

**RECOMMENDED:** n_sim = 2000 per core gate cell; n_sim = 1000 for the
extension tiers (Tier 1 family-completion, Tier 2 slope, Tier 3 coevolution).

**Rationale.** Coverage MCSE = sqrt(p(1-p)/n_sim). At p=0.95: n_sim=2000 ->
0.49pp (< half the 1pp gate-vs-nominal gap, meets the Morris ±0.5pp
benchmark); n_sim=1000 -> 0.69pp (resolves the gap with ~0.7pp margin, the
minimum defensible); R=200 -> 1.54pp (cannot resolve it -- the precise
reason M3.3 could not adjudicate its near-miss cells). The core cells *are*
the CRAN/paper gate, so they should sit at the research-grade floor (2000).
The extension tiers inform register promotions rather than the headline
gate, so 1000 is an honest economy there. Power cells need no more than the
coverage floor: at pow≈0.80, n_sim=2000 gives 0.89pp MCSE, resolving the
power curve to ±1.8pp.

**Trade-off / if 1000 for core.** Halves the core bill and is still
defensible (0.69pp), but the paper must state the looser MCSE, and a cell
landing at 94.3% becomes harder to call cleanly. Given the core is small
(~50 cells) and is the entire point of the study, the marginal compute for
2000-over-1000 is the cheapest insurance in the whole budget. Spend it on
the core; economize on the extensions.

**Uncertainty.** n_boot (interval noise) is a *separate* axis from n_sim
(coverage MCSE); the spec's n_boot=100 is a target, and the pilot should
confirm the interval is stable there. Do not trade n_sim down to fund
n_boot up -- they buy different things.

---

### Q-e -- Coevolution / Gamma in scope or deferred

**RECOMMENDED:** In scope as a **bounded Tier-3 extension**, gated on the
core (Tier 0) passing -- not in the core. The draft's "deferred because the
engine isn't built" rationale is now stale and should be retired.

**Rationale.** Design 66's Q-e default was "deferred -- the `kernel_*()`
engine is not built on origin/main." That is no longer true: KER-01/KER-02
(`make_cross_kernel()`, `kernel_*()`) and COE-02 (`extract_Gamma()`,
validated coevolution engine) are all `covered` as of #361, with a
published article. The blocker the default rested on is gone, so the only
remaining reason to exclude coevolution is *budget*, not capability.
Coevolution (Gamma = Lambda_H Lambda_P^T) is one of the package's signature
differentiators; certifying its power/coverage at scale is high paper
value. Putting it in a staged Tier-3 (sec.4.5 already reserves the schema
slot) captures that value without loading the must-pass core.

**Trade-off / if kept deferred.** Keeping it deferred is still a *legitimate
budget call* -- it is genuinely an extension, and a clean core + paper that
cites the existing COE-02 recovery evidence is shippable. But the maintainer
should make that call knowing it is now a "we chose not to spend the compute"
decision, not a "we can't" one. If included, scope it tightly: a single
block-structure (host x partner), 1-2 signal levels, n_sim=1000, gated on
core PASS_TO_SCALE.

**Uncertainty.** Coevolution bootstrap cost per fit is not yet pilot-measured
and the cross-kernel DGP is the least-exercised path in the engine reuse map
(sec.9); pilot it before committing cells.

---

### Q-f -- Core 4-family subset vs all 14 wired families

**RECOMMENDED:** 4-family representative core (gaussian, nbinom2,
binomial-probit, ordinal-probit). Remaining wired families -- including
mixed-family -- as the Tier-1 family-completion extension at n_sim=1000.

**Rationale.** The 4-family subset spans the hard machinery: gaussian
(baseline), nbinom2 (the hardest M3 cell at 0.38 smoke coverage -- if it
passes at scale the count path is trustworthy), binomial-probit
(link-residual + psi=0 invariant), ordinal-probit (cutpoints). That is the
representative set; "all 14" multiplies the core by ~3.5x for families that
mostly re-exercise paths the four already cover. The board now lists gamma,
beta, lognormal, student, tweedie, betabinomial as `covered` for recovery
and nbinom1 (FAM-07) as `covered`, so the extension is a real, large set --
which is exactly why it belongs in a staged tier, not the gate. Mixed-family
is the signature differentiator *and* was the worst-calibrated M3 cell
(CI-10: 0.820/0.685/0.550 on the old psi proxy); re-running it against the
corrected `Sigma_unit_diag` estimand is high-value but higher-risk, so it
belongs in the extension where a partial result is reportable without
failing the core gate.

**Trade-off / if all 14 in core.** Stronger blanket claim ("every wired
family certified at the headline n_sim"), but ~3.5x core cost and it drags
the riskiest cells (mixed-family, tweedie) into the must-pass set, raising
the chance the core "fails" on a family that needs its own diagnostic lane.
Recommend the representative core for the gate; let the family-completion
extension promote FAM-* register rows individually.

**Uncertainty.** nbinom1 is `covered` but heavy-gated/recently-wired;
mixed-family fit-failure allowance is already looser (≤30%, sec.6). Both
argue for the extension tier, not the core.

---

### Q-g -- Operational definition of "moderate"/"strong" signal

**RECOMMENDED:** Parametrize signal as the **between-unit variance share of
total trait variance** -- the fraction of trait variance attributable to the
structured between-unit RE tier. Levels: absent = 0 (the H4 Type-I cell),
moderate ≈ 0.25, strong ≈ 0.50. Hold the *share* identical across phylo /
spatial / animal so the power curve's x-axis is comparable across sources.

**Rationale.** Design 66 sec.12 Q-g proposes "a between-unit variance share
of total" and asks the maintainer to fix the metric; this recommendation
adopts that proposal and pins the levels. A variance share is the
source-agnostic quantity: it means the same thing for a phylo, spatial, or
animal tier, so H3's "power curve per RE source, monotone in signal" is
directly comparable across the three sources (sec.2). It maps cleanly onto
the existing `--lambda-scale` / `--psi-scale` signal knobs (sec.9) -- the
DGP fixes total trait variance and splits it by the target share. The 0
level *is* the Type-I cell by construction, so H4 falls out of the same
parametrization. 0.25 and 0.50 bracket a realistic field-study regime and
give a visible rise on the power curve between n=50 (Boettiger et al. 2012
low-power regime) and n=150.

**Trade-off / if a source-specific signal metric.** A phylo/spatial signal
lambda (e.g. Pagel's lambda, OU strength) is more interpretable *within* a
source and closer to how ecologists read phylogenetic signal -- but it is not
commensurable across sources, so the three power curves would have different
x-axes and H3's "monotone in signal strength" claim would be per-source
rather than unified. Recommend the variance share as the primary,
cross-source axis, and optionally annotate the phylo cells with the implied
signal lambda for reader intuition.

**Uncertainty.** The exact 0.25 / 0.50 anchors are a judgement call; the
pilot should confirm that 0.25 is detectable-but-not-trivial at n=50 (if
power is ~1.0 there, lower the moderate anchor; if ~alpha, raise it). The
variance-share-to-knob mapping for the reduced-rank `latent` modes needs one
explicit DGP check (the share is defined on the implied `Sigma_unit`, not on
raw loadings).

---

## 3. Sequencing note -- this is freeze prep, not a start

The capstone is the **end-of-road gate** and is explicitly "gated on all
other tracks" (#349): capabilities, functions/docs, articles, then power
study, then CRAN/paper. The current milestone arc is v0.2.0 -> power-study
-> CRAN+paper. As of 2026-06-04 the package is at v0.2.0 tag-prep with the
register at 166 C / 20 P / 7 B and a small number of in-flight rows
(nbinom1 #441-line, kernel C3 #439). The capstone's own gating clause
(sec.0 / Design 66 sec.10) requires every upstream surface `covered`, the
Wald-vs-profile-vs-bootstrap differential landed, and the extractor surface
(Design 53) complete before dispatch.

So this memo is **pre-spec-freeze preparation**: deciding Q-a..Q-g lets the
spec freeze now, so upstream tracks aim at exactly the cells the capstone
will certify -- but it does **not** authorize a run. The run order is: (1)
freeze the spec via these decisions; (2) finish the remaining upstream
tracks to `covered`; (3) pilot at n_sim=10 to calibrate fit time and verify
the new axes wire through and the null cell yields ~alpha; (4) only then
dispatch the core on the agreed compute. Pinning the spec early is the
explicit point of registering a study that runs last (sec.0): it prevents
a repeat of the M3.3 confound where the run profiled what was convenient
(`psi`) rather than the estimand the claim was about.

---

## 4. On #369 itself -- rebase vs park (Codex's open question)

**RECOMMENDED: leave #369 parked as the draft of record; do not rebase it
into a fresh review PR yet.** Rationale: #369 is a DRAFT design doc that is
*not* meant to merge as-is (its own body says so) and whose seven questions
are still open. Its purpose is to hold the pre-spec while the maintainer
decides Q-a..Q-g. Rebasing it now would churn the branch and the PR for no
review benefit while the decisions are still pending. The cleaner sequence
is: maintainer confirms/adjusts the Q-a..Q-g recommendations in this memo;
**then** Design 66 sec.12 is rewritten from "open questions" to "frozen
decisions" and #369 is rebased onto current `origin/main` (it was cut
2026-05-31; main has since advanced through #442/#443/#444 and the board
refresh) and re-opened as the clean, mergeable spec. Rebase *after* the
decisions, not before -- one rebase, into a doc that is actually ready to
merge.

---

## 5. Checks run

- `mcp__github__issue_read` #369 (PR body, no comments), #349 (umbrella +
  ADEMP pre-reg comment), #346 (sim/coverage framework), #340 (board,
  refreshed 2026-06-03/06-04).
- `mcp__github__get_file_contents` `docs/design/66-capstone-power-study.md`
  @ `refs/heads/agent/capstone-power-study` (full ADEMP pre-spec read).
- `docs/design/35-validation-debt-register.md` @ `main`: extracted CI-08,
  CI-10 (both `partial`), FAM-07 nbinom1 (`covered`), KER-02 (`covered`),
  COE-02 (`covered`).
- `git log origin/main`: HEAD at `4e9f7d8` (#444, simulate_unit_trait); main
  advanced past #369's 2026-05-31 cut point.

## 6. GitHub issue ledger

- Read #369, #349, #346, #340; register @ main.
- Will post a decision-prep summary comment on #369 (links this memo).
- No issue created; this is advisory decision-prep for an existing draft PR.
- Did NOT modify Design 66, did NOT touch `agent/capstone-power-study`, did
  NOT merge anything.

## 7. Known limitations and next actions

- These are RECOMMENDED answers, not decisions. The maintainer confirms or
  adjusts each, then the spec freezes.
- All compute figures inherit the unverified 2 s vs 20 s/fit spread; the
  pilot's `mean_runtime_s` is the gate on any allocation commitment.
- Q-g anchors (0.25 / 0.50) and the variance-share-to-knob mapping for
  reduced-rank `latent` modes need one explicit pilot DGP check.
- Next slice (maintainer-gated): rewrite Design 66 sec.12 from open
  questions to frozen decisions, rebase #369 onto current main, re-open as
  the mergeable spec.

https://claude.ai/code/session_01E83SkoXEaWMo1WRxj2Hud4
