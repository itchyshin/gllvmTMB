# Design 128 — Slope-per-family recovery campaign: tweedie, truncated_poisson, truncated_nbinom2

**Maintained by:** Curie (costing).
**Status:** COSTING ONLY. Nothing in this document has been run. No fit, simulation, or
probe was executed to produce it — every number is either a citation to a landed prior
document or explicitly flagged as unestablished. This is a plan for Shinichi to approve
or reject on numbers, per D-139.
**Branch:** `claude/rand-slope-surface-20260818`, worktree `/private/tmp/gllvmtmb-randslope`.
**Date:** 2026-08-18.
**Decision this document feeds:** D-113 track 6 (Shinichi, 2026-08-01, "≥1 random-slope
recovery cell per exported distribution/family") and the unanswered G0 option (d) in
`docs/dev-log/plan-actual/2026-08-07-gllvmtmb-cran-0.7-g0.md` line 141: *"one slope gap
(name tweedie vs truncated_*)."*

## 0. Scope and non-goals

**In scope:** a costed campaign design for the 3 evidence-open families named in
`docs/dev-log/after-task/2026-08-01-slope-per-family-gap-ledger.md` — tweedie (id 6),
truncated_poisson (id 10), truncated_nbinom2 (id 11) — plus a recommendation to exclude
delta_lognormal (12) / delta_gamma (13) from this campaign entirely.

**Not in scope, and not claimed anywhere below:**
- Interval coverage or calibration (D-112 forbids a coverage chase; Design 80 owns
  calibration as a separate arc).
- Route-specific (`phylo_dep`, `phylo_latent`, `spatial_*`) recovery for these families —
  only the C1 `phylo_indep(1 + x | species)` route, mirroring the existing admissions.
- Any engine, R, or C++ change. This is a design document; `R/`, `src/`, `NEWS.md`,
  `DESCRIPTION` are untouched.
- Running anything. Every wall-clock number below is either cited or explicitly marked
  unknown.

## 1. Background — what is already landed and how a family gets admitted

The engine that accumulates the augmented-slope contribution into `eta` is family-agnostic
(`src/gllvmTMB.cpp:2468-2612`, before the family dispatch at `:2625`). Admission is a pure
R-side policy table, `.augmented_slope_family_contract()` (`R/fit-multi.R:453-480`), checked
by `.augmented_slope_family_allowed()`. Per the #388 discipline (used for every prior
admission, most recently betabinomial — `docs/dev-log/after-task/2026-08-01-slope-per-family-betabinomial-admission.md`),
a family is added to that table **only after** a recovery cell for it passes, non-skipped,
under `GLLVMTMB_HEAVY_TESTS=1`.

The reusable C1 fixture is `tests/testthat/test-family-slope-recovery.R`:
`make_family_slope_mu(seed, n_sp = 90L, n_rep = 10L)` builds 3 traits over an
`ape::rcoal(n_sp)` tree, `s2_int = c(0.4, 0.6, 0.3)`, `s2_slope = c(0.3, 0.5, 0.2)`, fits
`value ~ 0 + trait + phylo_indep(1 + x | species)`, and
`.check_slope_c1_plausibility()` asserts: `fit$opt$convergence == 0`, `sd_b` length 6
(interleaved intercept/slope SD per trait) finite and positive, and the pooled ratio
`mean(slope_sd) / mean(true_slope_sd)` inside `(0.5, 1.7)` — "a generous band, single seed"
(the file's own comment, line 82). This is the band every admitted C1-partial family
(lognormal, student, betabinomial) cleared, and it is the band this design reuses unless a
family-specific reason says otherwise (tweedie, §2.3, is that reason).

Ledger status on the 3 open families (`docs/dev-log/after-task/2026-08-01-slope-per-family-gap-ledger.md`,
rows 6/10/11):

| id | family | intercept evidence | slope evidence |
|---|---|---|---|
| 6 | tweedie | covered | **none admitted** — a fail-loud boundary test only (`test-matrix-slope-phylo-indep.R:158-167`, "allowlist boundary: tweedie still reserved") |
| 10 | truncated_poisson | partial | none |
| 11 | truncated_nbinom2 | partial | none |

## 2. Per-family design

### 2.1 truncated_poisson (family_id 10, log link only — `R/fit-multi.R:843`)

**DGP / fit formula.** Reuse `make_family_slope_mu()` unmodified (3 traits, `s2_int =
c(0.4, 0.6, 0.3)`, `s2_slope = c(0.3, 0.5, 0.2)`, intercept 0.5 on the log scale — cited
from `test-family-slope-recovery.R:24-46`). Draw the response by rejection sampling on
`rpois`, exactly `rztpois()` in `tests/testthat/test-truncated-recovery.R:19-30` (draw
until `y >= 1`). Fit `value ~ 0 + trait + phylo_indep(1 + x | species)` with
`family = truncated_poisson()`.

**Sample size — cited, not derived.** `test-truncated-recovery.R` runs the family's only
existing recovery evidence: an ordinary `latent(0 + trait | individual, d = 1)`
random-**intercept** cell (not phylo, not a slope) at `n_ind = 250` (log-scale
intercepts `c(0.5, 1.0, 1.5)`, 3 traits, converges, intercepts recover to <0.20 — lines
32-66) and a second-seed cell at `n_ind = 280` with 4 traits and a lower intercept floor
`exp(0.3) ~ 1.35` (lines 67-104). `test-matrix-truncated.R`'s header comment independently
recommends truncated_poisson as "the right pick for a *structural* smoke" precisely
*because* it carries **no dispersion parameter** — the structural cells identify only
trait intercepts and the unit-tier (co)variance, which is the cleanest of the three open
families to add a slope to.

**This is intercept evidence, not slope evidence, and the random-effect route differs**
(ordinary reduced-rank `latent(d=1)` vs. phylo-structured `phylo_indep(1+x|species)`).
It is cited here as the closest available floor: `n_sp = 250` (the smaller of the two cited
`n_ind` values, matched to a 3-trait design like the C1 fixture) is the **starting cell**,
not an invented number. If it fails to converge or fails the plausibility band, escalate
using the betabinomial precedent (§2.4 below) rather than guessing a new number.

**Acceptance criterion.** Reuse `.check_slope_c1_plausibility()` verbatim: `convergence ==
0`, `sd_b` length 6 finite/positive, pooled ratio in `(0.5, 1.7)`.

**Admission condition.** A single-seed `phylo_indep(1+x|species)` cell at `n_sp = 250`
(or the escalated N from the pre-run test, §4) passes the criterion above, non-skipped
under `GLLVMTMB_HEAVY_TESTS=1`, landed in `test-family-slope-recovery.R` alongside the
existing lognormal/student/betabinomial cells. Then `.augmented_slope_family_contract()`
gains row `family_id = 10L`, `admission_basis = "c1_partial"`, same evidence string as the
existing C1-partial rows.

### 2.2 truncated_nbinom2 (family_id 11, log link only — `R/fit-multi.R:845`)

**DGP / fit formula.** Same skeleton, response via `rztnbinom2()` (the zero-truncated NB2
rejection sampler used in `test-truncated-recovery.R`), `family = truncated_nbinom2()`.

**Sample size and a required DGP modification — both cited.** The family's only existing
recovery evidence, again ordinary `latent(d=1)` intercept + dispersion (not phylo, not a
slope), runs at `n_ind = 300` (`mu_true = c(1.5, 2.0, 2.5)`, `phi_true = 2.0`,
`test-truncated-recovery.R:185-224`) and `n_ind = 320` (`mu_true = c(1.8, 2.3, 2.8)`,
`phi_true = 3.0`, lines 230-274). **Both cells deliberately keep the log-scale intercept
`>= 1.5`**, with the file's own comment explaining why (lines 190-194): *"with low mu the
truncation removes the bulk of the zero-mass evidence and phi becomes weakly identified
(the truncated NB2 collapses toward truncated Poisson)."* `test-matrix-truncated.R`
(lines 17-23) independently records the failure mode this avoids: at a 60-unit tier with
its (lower) matrix-campaign intercept, truncated_nbinom2's per-trait phi "ran away to
~4e7 (NB2 -> Poisson limit)," tripping nlminb code 8 even with a PD Hessian.

This means the **C1 fixture's default intercept (0.5) cannot be reused unmodified** for
this family — it sits inside the exact regime the cited evidence says breaks phi
identifiability. The design here is: keep `s2_int`/`s2_slope`/`n_rep`/the tree/the
`phylo_indep(1+x|species)` formula from the C1 fixture unchanged, but raise the fixed
intercept from 0.5 to the cited floor (`>= 1.5`, matching `mu_true` in the passing
recovery cells) and set `n_sp = 300` (the smaller of the two cited `n_ind` values). This
is a parameter substitution sourced from a landed identifiability finding, not a
re-derivation.

**Acceptance criterion.** `.check_slope_c1_plausibility()`'s three checks, **plus** an
explicit dispersion-sanity check mirrored from `test-truncated-recovery.R`'s own band:
`phi_hat` (from `fit$report$phi_truncnb2`) finite and inside `(0.3 * phi_true, 5 *
phi_true)` for every trait. Without this addition, a collapsed/runaway phi (the exact
failure the matrix-test comment documents) could still leave the slope-SD ratio inside
band by chance, and admission would be silently unsound on dispersion.

**Admission condition.** Same shape as §2.1: one passing cell lands in
`test-family-slope-recovery.R`, contract row `family_id = 11L`, `admission_basis =
"c1_partial"`.

### 2.3 tweedie (family_id 6, log link only) — this is not a missing-evidence gap, it is a known failure

**This family is different from the other two.** The ledger's "GATED — fail-loud boundary;
campaign deferred" undersells what is already known. Two landed documents record an actual
negative result, not an absence of evidence:

1. `docs/dev-log/after-task/2026-07-12-re-surface-arc-start.md` ("Remaining (Tier 2)"
   section): *"tweedie is structurally slope-ready but its random-slope recovery is
   **empirically ridge-biased** — a bare gate-removal fit converges but over-estimates the
   slope SDs by ~44% (the sigma_u^2 <-> p <-> phi ridge flagged by Design 80 + the
   mixed-models lens). So tweedie is NOT a clean gate-removal like lognormal/student; it
   needs a ridge-aware recovery study... before admission."*
2. `tests/testthat/test-tweedie-fixed-p.R` (header comment): *"fixing p does NOT unlock
   tweedie random SLOPES — an empirical check... found the ~44% slope-variance
   over-estimate persists with p fixed, so tweedie stays off the random-slope allowlist."*
3. `docs/design/80-*.md` (the RE-surface design memo) names the mechanism directly:
   *"Tweedie. Ship a first-class `p`-fix escape hatch... the σ_u²↔p↔φ ridge is flat with
   few clusters."*

**The generic C1 band would not have caught this bias.** A 44% over-estimate is a ratio of
`1.44`, which sits comfortably inside the existing `(0.5, 1.7)` band used for every other
C1-partial family. Reusing that band unmodified for tweedie risks admitting a family with a
known, documented, mechanism-explained upward bias. This design does **not** recommend
that.

**DGP.** Same C1 skeleton; response via `tweedie::rtweedie(mu = exp(eta), phi, power)`,
already the package's own precedent for simulating tweedie responses
(`tests/testthat/test-va-all-family-light-fits.R:76`, `phi = 0.7, power = 1.5`; also
`tests/testthat/test-tweedie-fixed-p.R:26`, `phi = 1.4, power = 1.6`).

**Sample size — genuinely not established for slopes.** No document sweeps N for a tweedie
slope cell; convergence was not the reported problem in the 2026-07-12 finding (the bare
fit "converges"), so an N-sweep is not obviously the right next step at all. Do not invent
one.

**What would have to be true to admit it.** Not just "a cell passes at some N." Given the
known mechanism, admission requires one of:
- (a) **Replication that the 44% figure does not reproduce** on the C1 fixture's specific
  DGP/N — i.e. the 2026-07-12 finding was tied to a different DGP/design and does not
  transfer. This needs its own multi-seed check, not a single C1 seed, because a
  single-seed pass inside a loose band cannot distinguish "no bias" from "the known 44%
  bias plus noise."
- (b) Admission gated on `tweedie(p = ...)` (the Design-80 escape hatch) **and** a
  tightened band that would actually reject a ~1.44 ratio (e.g. `(0.7, 1.3)`, not the
  generic `(0.5, 1.7)`) — but `test-tweedie-fixed-p.R`'s own comment says the bias
  *persists* under fixed `p`, so this path is not obviously open either.
  Per Design 80's own recommendation, a first-class `p`-fix escape hatch was proposed as
  the fix, but the fixed-`p` test that exists today only checks that pinning works
  mechanically, not that it fixes the slope-SD bias — this is exactly the gap the
  pre-run test (§4) is aimed at closing.
- (c) A maintainer decision to admit with an explicit "known upward-biased slope SD, use
  qualitatively" caveat in the contract's `evidence` string, mirroring the honesty-fencing
  discipline used elsewhere in this package (AGHQ, EVA). **This is Shinichi's call, not
  a default** — none of the three prior C1-partial admissions carry a known-bias caveat,
  so this would be a new category of admission.

**Recommendation:** do not fold tweedie into the same recovery-cell PR as the two
truncated families. It needs its own small pre-run test (§4) before a campaign shape can
even be chosen (multi-seed bias-replication vs. fixed-`p` band vs. caveated admission are
three different code/test shapes with different costs).

### 2.4 The escalation precedent (used by §2.1/§2.2 if the starting N is insufficient)

`docs/dev-log/after-task/2026-08-01-slope-per-family-betabinomial-admission.md` records the
only prior N-escalation for this exact fixture family: a multi-trial betabinomial cell at
the C1 default `n_sp = 90` failed to converge; `n_sp = 200` cleared the band (probe:
`dev/probe-betabinomial-slope.R`, cited in the after-task's Outcome section and in the
`test-family-slope-recovery.R` comment at line 58-59). If §2.1 or §2.2's starting N fails,
escalate by the same method — a cheap probe script sweeping a small N grid above the
starting point, not a re-derivation from first principles.

## 3. delta_lognormal (12) / delta_gamma (13) — recommend excluding, semantic fence not evidence gap

These two are fenced by **semantics**, not by missing data. A delta/hurdle family has
**two latent scales** — the binary occurrence part and the positive-value part — bundled
into one `family_id` row. `docs/design/57-mixed-family-link-residual.md:53` states this
directly: *"delta_* (hurdle) | TWO latent scales (binary + positive) | Currently blocked in
mixed-family fits per `check_auto_residual()`."* `docs/design/61-capability-status.md:158`
extends the same fence to random effects: *"delta / hurdle / two-stage zero-inflated
families | blocked | FAM-17, MIX-10 | Do not advertise random-slope covariance or
latent-scale correlation for these families."* And per
`docs/design/35-validation-debt-register.md:168` (FAM-17), the resolved delta convention
constrains any latent structure to the **positive submodel only** — the occurrence
submodel is fixed-effects-only by design, which is why random slopes are already blocked
there, not merely untested.

A `phylo_indep(1 + x | species)` augmented slope contributes one shared `eta` term. For a
single-scale family that term has one unambiguous interpretation. For a delta family it
would enter both the occurrence and positive-part linear predictors identically, but the
package's own resolved convention (Design 02 §Hurdle/delta, cited above) already restricts
random structure to the positive part alone — so a slope cell here would either (a)
silently violate that convention, or (b) require a delta-specific augmented-slope route
that does not exist and is out of scope for a #388-style recovery-cell campaign (it would
be a grammar/engine change, high-risk per `ROADMAP.md`).

**Recommendation: do not design a cell for delta_lognormal / delta_gamma in this campaign.**
Leave both `open (fenced)` in the ledger. If Shinichi wants slope coverage for delta
families eventually, that is a semantics decision (which submodel the slope attaches to)
that must be settled — as a maintainer discussion checkpoint, per `CLAUDE.md`'s formula-
grammar rule — before any recovery cell can even be specified, let alone costed.

## 4. Pre-run test spec (D-139)

**No cited per-fit wall-clock exists anywhere in the documents this design was built
from** (checked: the betabinomial after-task reports an ~2.5-3.5h *arc* total, not a
per-fit time; the closest numeric fit-timing evidence found, `docs/dev-log/after-task/2026-08-16-mspl-tweedie-hang-wstar.md`,
reports `elapsed=1.549s` for an unrelated 8-species x 3-trait **MSPL** probe under a
different estimator, not comparable to a 250-300 species phylo_indep ML fit). **That
absence is itself the finding required by D-139**: a wall-clock estimate cannot be
produced from citation alone, so the campaign needs exactly one timed run before any
further commitment.

**The single smallest cell:** truncated_poisson at `n_sp = 250`, one seed (the fixture
described in §2.1), run as a plain `Rscript` invocation, not inside `testthat`. This
family is picked because (a) it is the cheapest of the three on structural grounds —
`test-matrix-truncated.R`'s own header names it the "clean" pick, no dispersion parameter
— and (b) its cited N is the smallest of the three open cells' floors.

> **CORRECTION (2026-08-18, after attempting to run this spec).** The spec below is
> **NOT EXECUTABLE AS WRITTEN**, and any future gate-removal campaign design must avoid
> the same omission. `truncated_poisson` is `family_id` 10, deliberately ABSENT from
> `.augmented_slope_family_contract()` (`R/fit-multi.R:453`) — that absence is the whole
> reason this campaign exists. So the fit hard-errors at
> `.augmented_slope_family_allowed()` (`R/fit-multi.R:2023`) *before TMB is ever reached*:
> `phylo_indep() LHS richer than 0 + trait is not yet supported for this family`.
> **A timing probe cannot measure a family the admission gate refuses to fit.**
>
> The fix is an explicit numbered step: a **temporary contract-table patch** (add
> `family_id` 10 with `link_0 = TRUE`, marked in-code as measurement scaffolding and NOT
> an admission), run the cell, then revert so `R/fit-multi.R` ends byte-identical to
> `main`. Note that on 2026-08-18 the Claude Code auto-mode permission classifier blocked
> *executing* R against a locally-modified `R/fit-multi.R`, so this step may need an
> explicit Bash permission rule or a human-run session.
>
> **The wall-clock question was answered by proxy instead**
> (`dev/prerun-truncated-poisson-RESULTS.md`): `poisson` — admitted, same log link, no
> dispersion parameter, same augmented-slope route — on the identical fixture took
> **9.216 s at `n_sp = 250`** and **15.277 s at `n_sp = 300`**, both `convergence = 0`,
> `pdHess = TRUE`. **This refutes §5's framing:** the cited "~2.5–3.5 h" is the
> betabinomial *arc* total (authoring, tests, review, CI), not fit time. These campaigns
> are **authoring-bound, not compute-bound**, so §6's Totoro contingency is moot and a
> multi-seed n-ladder — the actual bar for `partial` → ✓ — costs minutes, not hours.
> Future slope cells should therefore be scoped richer than single-seed.
> The proxy is NOT `truncated_poisson`'s own convergence evidence and creates no admission
> claim for any family; `truncated_poisson` remains **ABORT/BLOCKED**, unmeasured.

**Exact spec:**
```r
devtools::load_all(quiet = TRUE)
t0 <- Sys.time()
fx <- make_family_slope_mu(seed = 42L, n_sp = 250L, n_rep = 10L)  # reuse verbatim
y  <- integer(nrow(fx$df))
for (i in seq_along(y)) {
  repeat { d <- rpois(1L, exp(fx$df$mu[i])); if (d >= 1L) { y[i] <- d; break } }
}
fit <- gllvmTMB(
  value ~ 0 + trait + phylo_indep(1 + x | species),
  data = transform(fx$df, value = y), phylo_tree = fx$tree,
  unit = "species", family = truncated_poisson()
)
elapsed <- Sys.time() - t0
```
Report: wall-clock elapsed, `fit$opt$convergence`, `fit$report$sd_b` (finite/positive?),
the pooled ratio against `sqrt(fx$s2_slope)`.

**What would abort the campaign (do not proceed past this cell without redesign):**
- Elapsed time on this single smallest, cheapest cell exceeds **~5 minutes** (a rough
  ceiling motivated by the documented tweedie dtweedie-series hang risk in
  `docs/dev-log/after-task/2026-08-16-mspl-tweedie-hang-wstar.md`, `>180s` for an
  unrelated code path — not tweedie's specific risk here, but the only evidence in this
  repo of a gllvmTMB non-Gaussian fit taking that long, so used as a conservative trip
  wire). If truncated_poisson (the cheapest, simplest family, no dispersion parameter)
  takes that long, tweedie (2 extra per-trait dispersion parameters, a documented ridge)
  is very unlikely to be a 30-minute-total campaign.
- `fit$opt$convergence != 0` at `n_sp = 250` — this would falsify the assumption that the
  intercept-recovery floor transfers to the slope route, and the campaign needs an N-sweep
  (via the betabinomial-style probe, §2.4) before a single number can be quoted for
  truncated_poisson, let alone truncated_nbinom2 or tweedie.
- Any crash, hang beyond the 5-minute trip wire, or non-finite `sd_b` — abort and report
  rather than silently retrying with a larger N.

## 5. Wall-clock estimate

**Per family, stated as a range with basis — not a single cited number, because none
exists (see §4):**

| family | basis | qualitative estimate |
|---|---|---|
| truncated_poisson | cheapest structurally (no dispersion param); N=250, single seed | Unknown until §4 runs. If the pre-run cell completes well under the 5-min trip wire (plausible given `ape::rcoal(250)` + `chol()` are sub-second and TMB/nlminb fits of this row count are not documented anywhere as slow), a single admission cell is a **minutes-scale** run, and the whole family's campaign (that cell, written into the test file, CI-verified) is comparable in total arc time to the betabinomial admission: **cited ~2.5-3.5h** (`docs/dev-log/after-task/2026-08-01-slope-per-family-betabinomial-admission.md`), which is mostly authoring/verification time, not fit time. |
| truncated_nbinom2 | N=300, one extra per-trait dispersion parameter (phi), one extra acceptance check (§2.2) | Same qualitative order as truncated_poisson plus modest extra authoring for the phi-sanity check. No basis to distinguish it further; treat as the same **~2.5-3.5h arc estimate**, contingent on the pre-run cell (§4) not aborting. |
| tweedie | **known bias, not just missing N** (§2.3); needs a multi-seed replication study or a fixed-`p` band redesign before a single admission cell can even be specified | **Cannot be estimated from any cited document.** This is not a "run it and see" gap — the shape of the work (replicate the 44% finding vs. redesign the band vs. caveated admission) is undetermined, so no wall-clock range is offered. Whichever shape is chosen needs its own scoping pass before a number can be quoted. |

**Total:** cannot be stated as a single number. Truncated_poisson + truncated_nbinom2
together are of the same order as one betabinomial-style admission arc each (**~5-7h
combined**, cited basis as above), **contingent on the §4 pre-run test not aborting**.
Tweedie is unscoped and excluded from that total.

## 6. Compute target

**Local first, for the pre-run test and any single-seed admission cell.** Per D-50,
campaigns and their artifacts never run on GitHub Actions — Actions stays package
checks/docs only, so §4's pre-run test and the eventual admission cells run on the Mac or
Totoro, never as a new CI workflow.

**Totoro only if the pre-run test shows a genuine multi-seed sweep is needed** — e.g. if
truncated_poisson's `n_sp = 250` cell fails at §4 and an N-escalation grid (mirroring the
betabinomial probe) is required, or if tweedie's bias-replication needs multiple seeds x
multiple N to characterize. Per D-143, keep any Totoro job **≤150 cores**, pin
`OPENBLAS_NUM_THREADS=1`, and do not open a fresh login — attach to the existing
`ControlMaster` socket at `~/.ssh/cm-*totoro*`.

**A single admission cell (one seed, one N) is local-only** — it does not warrant Totoro on
its own; a single `Rscript` run, timed, is exactly what §4 specifies.

## 7. Ordering recommendation

The unanswered G0 question (`docs/dev-log/plan-actual/2026-08-07-gllvmtmb-cran-0.7-g0.md`
line 141) asked Shinichi to pick tweedie **or** one truncated_* for a single INCLUDE slot.
Given the evidence above, the costs are not comparable:

- **truncated_poisson**: cheapest, structurally simplest (no dispersion parameter), has a
  cited intercept-recovery floor (N=250) and the cleanest acceptance criterion — a direct
  reuse of `.check_slope_c1_plausibility()` with no modification. Lowest risk, most
  boundedly costed of the three.
- **truncated_nbinom2**: same shape, one documented extra risk (phi weak-identifiability
  at low mu — `test-matrix-truncated.R`'s own NB2-to-Poisson-runaway finding), mitigated by
  the cited `mu_true >= 1.5` fix and an added phi-sanity check. Slightly more costly to
  author, similarly boundedly costed to run.
- **tweedie**: **not a same-shaped decision.** It carries a documented, mechanism-explained
  ~44% slope-SD bias that survives the one mitigation already tried (`p`-fixing). Picking
  tweedie for "one slope gap" is not "run a cell and admit it" — it is choosing to open a
  small research question (does the bias replicate on this DGP? does a tighter band or a
  different fix close it? or does the family get admitted with a caveat, a new admission
  category?) with an unscoped cost.

**My recommendation: truncated_poisson first, on its own, as the G0 INCLUDE if Shinichi
wants one slope gap closed cheaply.** It is the only one of the three with (a) a cited
sample-size floor from an unrelated-but-analogous recovery cell, (b) zero required
acceptance-criterion changes, and (c) no documented failure mode standing in the way.
truncated_nbinom2 is a natural, only-slightly-more-expensive follow-on once
truncated_poisson's pre-run test (§4) confirms the fixture-and-floor transfer generally
works for this family class. Tweedie should be scoped **separately**, as its own small
research slice (replicate-or-redesign, §2.3), not bundled into "the slope gap" decision —
bundling it risks either quietly admitting a family with a known bias under too-loose a
band, or stalling the other two behind an open research question that has nothing to do
with them.

## 8. What this design does NOT cover

- Route-specific (`phylo_dep`, `phylo_latent`, `spatial_*`) recovery for any of the three
  families — C1 `phylo_indep` only, mirroring every existing C1-partial admission.
- Interval coverage or calibration (D-112, Design 80).
- Any engine/R/C++ change — this is a test-file-only campaign, same shape as the
  betabinomial admission.
- Replicated-seed or Hessian/gradient health beyond the single convergence + PD-adjacent
  checks already in `.check_slope_c1_plausibility()`.
- A resolved answer for delta_lognormal / delta_gamma — explicitly recommended out of
  scope (§3), pending a maintainer semantics decision.
- Any actual run. §4's pre-run test is specified, not executed, by this document.

## 9. Checks

This document is design-only; the checks that apply are to the document itself, not to a
campaign result:

- Every sample size and every qualitative finding above is a citation to a file path and
  line range in this worktree, checked by reading those files during authoring (not
  invented).
- `docs/design/128-slope-per-family-campaign.md` does not exist on any other ref
  (`git log --all --diff-filter=A -- 'docs/design/128-*'` and a full-ref `ls-tree` scan,
  both empty at authoring time) — 128 is genuinely free, not a collision like the
  87/88/89 case Design 117 documents.
- `R/`, `src/`, `NEWS.md`, `DESCRIPTION` are untouched by this commit.
