# Design 121 — a pre-registered validation slice for non-Gaussian Cox–Reid REML

**Status: PROPOSAL, not an authorised campaign.** This is a scoping input for
the Design 66 capstone (`docs/design/66-capstone-power-study.md`), pre-registered
per D-139 (any run > 30 min needs a stated estimate, a PRE-RUN TEST with shown
results, and Shinichi's approval *before* the full run). Nothing in this
document authorises compute. Lane: `claude/doc-lane-diag-reml-slopes-20260816`,
worktree `/private/tmp/gllvmtmb-doc-lane-20260816`.

## 0. What this answers, and why it is not answered yet

`gllvmTMB(REML = TRUE)` is validated **Gaussian-only** — register row **MIS-33**
(`docs/design/35-validation-debt-register.md:487`): a dense Patterson–Thompson
oracle agreement plus `glmmTMB(REML = TRUE)` agreement on matched
random-intercept and rank-1 latent fixtures. That row certifies nothing about
non-Gaussian families.

A non-Gaussian route exists, opt-in and explicitly unvalidated:
`gllvmTMBcontrol(allow_nongaussian_reml = TRUE)` (`R/gllvmTMB.R:1575`,
`R/gllvmTMB.R:1730`, `R/gllvmTMB.R:1860`) lifts the non-Gaussian abort
(`R/fit-multi.R:2860-2861`, the `cli_abort` immediately after the hypothesis
block) and lets `b_fix` join TMB's `random` vector for
non-Gaussian rows, realising the Cox–Reid (1987) adjusted profile likelihood
`l_p(psi) - 0.5*log|j_bb|` rather than an exact restricted likelihood. The
hypothesis block at `R/fit-multi.R:2824-2858` (the comment opening
`"NON-GAUSSIAN REML IS THE COX-REID ADJUSTED PROFILE LIKELIHOOD"` — read it
verbatim before this document) records the motivating evidence and states
plainly that the drmTMB transfer is *"a hypothesis under test, not an
inherited result."* Citations into `R/fit-multi.R` and `R/aghq-gate.R` below
carry a quoted anchor phrase alongside the line number, because both files
are hot and line numbers drift; the anchor is authoritative. This design
proposes the slice that would test the hypothesis in gllvmTMB's own
parameterisation.

## 1. Estimand

**Relative bias of the latent/random-effect SD** (`||Lambda_hat|| / ||Lambda_true||`
or the equivalent scalar RE SD ratio, matching the metric already used in
`dev/aghq-evidence/05-descend-RESULT.txt`), and **latent correlations** where
the model has more than one latent dimension and correlations are defined,
each measured against the **known simulation truth**.

**Why truth is the only admissible oracle here — plain-Laplace agreement is
not.** The existing MIS-33 oracle strategy (agree with `glmmTMB(REML = TRUE)`,
agree with a closed-form Gaussian restricted likelihood) cannot be reused for
this slice, because for non-Gaussian families there is no closed-form
restricted likelihood to agree with, and the whole premise under test is that
**plain Laplace-ML is itself biased** (`R/fit-multi.R:2847-2849`, anchor:
*"Laplace's small-n adequacy is TWO ERRORS CANCELLING"* — its integral error
biases down, the small-sample variance bias biases up, and the cancellation
is uncontrolled). An estimator that
agrees with a biased comparator is not shown to be right; it is shown to
share the same bias, or — worse — to cancel a different way. Only a
known-truth simulation DGP separates "closer to truth" from "closer to
Laplace." This mirrors the standing package rule (Design 66 §0, and the
n-ladder discipline already used for the AGHQ evidence) that estimators are
judged against generative truth, not against each other.

## 2. Design

**Three primary arms**, one held-fixed configuration knob, run per cell:

| Arm | Engine | `gllvmTMBcontrol(...)` |
|---|---|---|
| A — Laplace-ML | Laplace, ML | defaults (`REML = FALSE`) |
| B — Laplace + Cox–Reid | Laplace, adjusted profile | `REML = TRUE, allow_nongaussian_reml = TRUE` |
| C — AGHQ-ML | AGHQ, ML | `aghq = k` (k TBD, e.g. 7, per the existing AGHQ evidence convention) |

**Ridge held identical across all three arms.** `aghq_ridge` (`R/gllvmTMB.R:1521`,
default `2`, `R/gllvmTMB.R:1691`) changes the objective the loadings are fit
against, and Design 80's Bar-3 framing plus the AGHQ engine's own finding (a
flat ~21% downward Laplace bias on binomial latent SD, unmoved by 16x more
data, remedied by AGHQ + `aghq_ridge = 2`) makes the ridge a real confound if
it differs between arms — a bias-reduction credited to Cox–Reid could
actually be the ridge. **The default state is asymmetric: the ridge is on
for arm C only.** A plain Laplace fit has NO default-on ridge — the default
does not penalise an ordinary Laplace fit unless the caller explicitly names
`aghq_ridge` (`R/gllvmTMB.R:1524-1525`, enforced via
`control$aghq_ridge_explicit` at `R/fit-multi.R:5704`, anchor:
`aghq_ridge_explicit`) — so under defaults arms A and B run unpenalised while
arm C runs ridged. **Fix the ridge value across A/B/C explicitly** (either
all off, `aghq_ridge = 0`, or all on at the same value — noting that turning
it ON for the Laplace arms A/B requires explicitly naming `aghq_ridge` in
their controls, or the penalty silently does not apply) and report which
choice was used — see K3 below, which exists to catch exactly this.

**Families.** `binomial` and `ordinal_probit` — the drmTMB hypothesis
(`R/fit-multi.R:2838-2841`, anchor: *"Laplace -7.3% -> +AGHQ -5.0% ->
+Cox-Reid -0.9%"*) was measured on `cumulative_logit`, but gllvmTMB's
own ordinal response family is `ordinal_probit()` (`R/families.R:632-672`,
class `c("ordinal_probit", "family")`); gllvmTMB has no `cumulative_logit()`
response family (`cumulative_logit()` in `R/missing-predictor.R:81-108` is a
**predictor-model** family for `mi()`, an unrelated use of the name). This
slice therefore tests the hypothesis on a probit link rather than reproducing
drmTMB's logit link exactly — note as a design difference, not an oversight.

**Structure.** 1 latent variable, `q = 1` random effect (matching the scale at
which the package's own n-ladder was measured — `R/fit-multi.R:2842-2846`,
anchor: *"This package's own n-ladder shows the same thing from the other
side"* — at `T = 4`, `q = 1`).

**Grid.**

| Factor | Levels |
|---|---|
| Family | binomial, ordinal_probit |
| Traits `T` | 4, 8 |
| `n` (sites) | 100, 200 |
| Seeds | ~100 per cell |

`2 families x 2 T x 2 n = 8 cells`, `8 cells x 3 arms x 100 seeds ~= 2,400
fits`.

**Nuisance-reparametrisation probe (arm D, subset only).** Reid & Fraser
(2003), cited in `R/fit-multi.R:2853-2857` (anchor: *"Cox-Reid is strictly
justified when the interest parameter is ORTHOGONAL to the nuisance block, and
it is NOT invariant to reparametrising that block"*), give two caveats, and
the hypothesis-block comment states directly that neither property is checked
for gllvmTMB's own parameterisation. **The nuisance block here is `b_fix` —
the fixed effects — because that is what joins TMB's `random` vector under
this route; the loadings/SDs are the *interest* parameters, under which the
adjusted profile likelihood is equivariant.** A probe that reparametrises the
loading/SD block therefore cannot test Reid–Fraser non-invariance: it would
return a guaranteed null and invite the wrong reading. Arm D instead refits
arm B on one subset (e.g. the `binomial, T = 4` cells, both `n` levels, same
seeds) under two parametrisations of the **fixed-effect nuisance block** — the
natural coefficient scale versus a smooth **nonlinear** reparametrisation
(e.g. `sinh`-scaled coefficients; a linear rescale of `X` shifts `log|j_bb|`
only by a constant Jacobian and moves nothing) — and compares the
transformed-back bias in the interest parameters. Two conditions bind arm D:
it runs **ridge-off** (`aghq_ridge = 0` in both refits — a ridge penalises
`Lambda` on a particular scale, so a ridge-on comparison would fire K2 on the
ridge's non-equivariance, not Cox–Reid's), and **start values are pinned to
identical transformed positions across the two parametrisations** (default
starts are scale-dependent — MIS-35 / #851, register `:489` — a second thing
that moves when the parametrisation changes). A secondary loading-block
SD-vs-log-SD refit MAY be reported, but only labelled as a
parameterisation-equivariance / numerical-stability check of the interest
block; it carries no Reid–Fraser interpretation. Arm D is the minimum probe
that can show non-invariance; it is not a full orthogonality diagnostic
(that would require the Fisher-information off-diagonal between the interest
block and `b_fix`, out of scope for this slice).

## 3. Kill criteria (pre-registered)

- **K1 — no effect.** If the point-bias reduction of arm B vs arm A is `< 2`
  percentage points at `n = 100` in *both* families, the Cox–Reid hypothesis
  is dead for this parameterisation and the fence (`allow_nongaussian_reml`
  stays opt-in, unpromoted) stays exactly as-is.
- **K2 — non-invariance.** If arm D's transformed-back bias estimate flips
  **direction** between the two nuisance (`b_fix`) parametrisations (§2:
  natural scale vs the nonlinear reparametrisation), or differs by more
  than 3 percentage points, demote the whole approach to a documented
  curiosity in the design record rather than a candidate fix — Reid &
  Fraser's non-invariance caveat is confirmed to bite in this
  parameterisation.
- **K3 — ridge confounding.** The default asymmetry is {A, B} unpenalised vs
  C ridged (§2). If re-running the arms with the ridge equalised across all
  three (all off, or all explicitly on at the same value) makes the Cox–Reid
  or AGHQ effect vanish or reverse relative to a default-state run, the
  original drmTMB transfer motivating this slice is flagged as an artifact of
  unequal regularisation, not evidence for the estimator itself.
- **K4 — interval harm.** If arm B's point-bias improves over arm A but its
  Wald interval coverage on the same SD/correlation targets degrades by more
  than 5 percentage points, do not recommend the Cox–Reid route even as an
  opt-in default — point accuracy without calibrated uncertainty is not a net
  improvement for a package whose interval evidence is already
  point-only/recovery-only (register row MIS-33 and the general honesty
  contract in Design 80).

**Monte Carlo error governs every threshold above.** At ~100 seeds/cell a
coverage estimate near 0.95 carries an MCSE of roughly ±2.2 percentage
points, so K4's 5-point threshold is only ~1.6 SE — a coin flip, not a
decision — and K1's 2 points and K2's 3 points have the same exposure
against an unmeasured seed-to-seed bias SD. Per the ADEMP / Morris et al.
discipline this package already follows (`simulation-design`), the pre-run
test (§4) must therefore report the observed seed-to-seed SD of each target
metric, and before approval either (a) the seed count is raised until each
kill threshold exceeds ~2x its achieved MCSE, or (b) the thresholds are
revised upward to clear that bar. A kill criterion that cannot clear 2x MCSE
at the affordable seed count is reported as underpowered, not adjudicated.

**Non-convergence rule (pre-registered).** Per-arm convergence rate is a
**primary outcome** of every cell, reported alongside bias. Bias and coverage
are compared only on the **intersection** of seeds that converge in all
compared arms — dropping failures per-arm would select each arm's easiest
seeds and bias the comparison (arm B enlarges the `random` block and may
fail more often than A). If any arm's convergence rate in a cell falls below
**70%**, that cell is reported as a convergence result, not a bias result.
This risk is live at exactly this scale: the register's own `ordinal_probit`
slope fixture records 3/6 converged PD-Hessian fits (PHY-16, register
`:235`). And because `ordinal_probit` has **no degeneracy detector** (#897),
a converged, unflagged, degenerate fit can enter the bias average silently —
the analysis therefore also reports the per-arm distribution of `max|Lambda|`
(the runaway signature) per cell, so a degenerate tail is visible even where
no flag fires.

Any kill criterion firing is a reportable result, not a failed run — the
proposal is designed so a null or negative outcome is as useful to record as
a positive one.

## 4. Compute estimate and the D-139 pre-run test

**This is an ASSUMPTION, not a measurement — no per-fit timing for this exact
grid exists in-repo.** The nearest anchor is the AGHQ engine evidence
(`dev/aghq-evidence/`), which does not report a directly comparable per-fit
wall time for `T in {4,8}`, `n in {100,200}`, `q=1` binomial/ordinal_probit
fits under Laplace, Cox–Reid, or AGHQ separately — flagged **UNVERIFIED**, not
found. Assuming (stated, not sourced) 5–15 seconds per fit for these small
cells across all three arms — Cox–Reid is the same Laplace machinery with a
larger `random` block so its added cost per fit should be modest, and AGHQ at
small `k` on `q=1` is the cheap end of that engine's own range — the total
wall estimate for ~2,400 fits sequentially is roughly **3–10 hours**, well
inside the range statable as an assumption per D-139. On Totoro (384 cores,
this project's cap is ≤150 per D-143) run in parallel across seeds/cells,
elapsed wall time would be far shorter than the sequential estimate; the
range above is deliberately given as sequential-equivalent compute, not
wall-clock under parallelism, because the per-core count for this slice is
undecided pending Shinichi's approval.

**PRE-RUN TEST required before any full run is approved** (D-139): 2 seeds x
all 8 cells x all 3 primary arms = 48 fits (arm D excluded — it is a
follow-on subset of arm B).

**RUN (2026-08-16): COMPLETE, 48/48.** Full table, per-arm/family bias, the
runaway-cell writeup, and the updated wall-time estimate live in
`dev/coxreid-prerun/RESULTS.md` (raw data:
`dev/coxreid-prerun/prerun-results.csv`). Headline: the full run is now
estimated at **~18.2 hours sequential-equivalent** (arms A/B measured close
to the 5–15s assumption; arm C — AGHQ, `k=7`, ridge off — measured a 69.9s
mean and a 345.1s worst cell, driving the whole estimate up from the
original 3–10h assumption), and **arm C's convergence rate (9/16, 56.25%)
is below this design's own 70% cell-level bar**. Neither of these findings
was anticipated by §4's original assumption; both must be shown to Shinichi
before any full-run approval, per this section's own requirement.

## 5. Relationship to Design 66

These 8 cells x 3(+1) arms are proposed as **candidates for the Design 66
capstone grid** (`docs/design/66-capstone-power-study.md`), not as a
freestanding campaign with its own seed budget. Design 66 §0 frames the
capstone as "the paper's evidence chapter," and this slice's binomial and
ordinal_probit cells at `T in {4,8}`, `n in {100,200}` overlap the kind of
regime the capstone's own grid is expected to cover. At capstone-scoping time
(explicitly deferred in the live snapshot in `CLAUDE.md`: *"scope the
power-study capstone (Design 66) as the paper's evidence chapter —
planning only, needs Shinichi on cells/seeds/families/gate/compute"*), this
slice's cells should be merged into one seed budget rather than run twice.
Design 66's own supersession note (D-50) already requires an
immutable-chunk smoke ladder before any broad Totoro/DRAC campaign; that
requirement applies here unchanged.

## 6. What this proposal does NOT do

- It does **not** promote `allow_nongaussian_reml` past its current opt-in,
  unvalidated status. The abort at `R/fit-multi.R:2860-2861` and the roxygen
  caveat at `R/gllvmTMB.R:1575-1576` stay exactly as they are regardless of
  this slice's outcome until a result is reviewed and a promotion decision is
  made separately.
- It does **not** use REML/AI-REML/Cox–Reid terminology for any VA objective.
  Design 85 §10 (`docs/design/85-highdim-nongaussian-va-formal-contract.md:324`)
  explicitly prohibits calling a VA bound "REML, AI-REML, Cox–Reid adjustment,
  or AGHQ," and separately prohibits "using this research prototype to weaken
  the project's Gaussian-only REML boundary" (`:340-341`). This slice is pure
  Laplace/AGHQ; no VA arm is proposed or implied.
- It does **not** treat AGHQ+REML as reachable. The AGHQ structural gate hard-
  excludes REML: `R/aghq-gate.R:225` (anchor: `reml_flag <- isTRUE(...)`)
  reads the REML flag off the fit data, and `R/aghq-gate.R:241-245` (anchor:
  `is_reml_hit`) routes any block containing `b_fix` under REML to
  `"laplace"` regardless of measured treewidth (`R/aghq-gate.R:32-35`
  documents this in the HARD EXCLUSIONS list, anchor: *"REML (`b_fix` joins
  `random` with no prior term)"*).
  **Consequence for interpretation:** arm B (Cox–Reid) and arm C (AGHQ) in
  §2 above are therefore mutually exclusive engine choices today, not
  stackable — a fit cannot run both AGHQ quadrature and the Cox–Reid `b_fix`
  augmentation at once. This slice can only ask "does Cox–Reid alone help"
  and "does AGHQ alone help" as parallel, non-combinable arms; it cannot test
  the drmTMB ladder's full stacked claim (Laplace -7.3% -> +AGHQ -5.0% ->
  +Cox–Reid -0.9%, `R/fit-multi.R:2838-2841`) as a single combined engine in
  gllvmTMB, because that combined engine does not exist and is out of scope
  to build here.

## 7. REML roxygen honesty note — APPLIED in this lane (2026-08-16)

`R/gllvmTMB.R` is a **hot file**: `git log origin/main --oneline --since=2026-08-02
-- R/gllvmTMB.R` shows seven non-doc commits since 2026-08-02 from other lanes
(`9be2e3f1` NA categorical responses for `multinomial()`, `18f24fdd` estimator
provenance, `14650312` LA-MSPL reconciliation, `0d992c61` LA-MSPL Lane B,
`ae340bdd` bounded 0.6 validation surface, `d7bee2fa` VA Arc-1 scalar fence,
`42d7452f` register-code removal from reader-facing surfaces). The edit was
initially deferred to avoid colliding with active lanes on that file; the
maintainer then directed it landed (2026-08-16), and since it is a pure
comment-block addition it rebases trivially even on a hot file. It is now
**applied** to the `@param REML` block (`R/gllvmTMB.R:200`, anchor:
`@param REML`), with `man/gllvmTMB.Rd` regenerated via
`devtools::document()` in the same commit. The applied text:

> REML is validated for **all-Gaussian** fits only. For non-Gaussian families
> an opt-in escape hatch exists
> (`gllvmTMBcontrol(allow_nongaussian_reml = TRUE)`) that realises the
> Cox–Reid adjusted profile likelihood rather than an exact restricted
> likelihood — this is **unvalidated**: a hypothesis under test, not an
> inherited result. Users estimating variance components or heritability on
> non-Gaussian data should be aware that plain Laplace can carry substantial
> downward bias on latent SDs. An opt-in AGHQ engine exists
> (`gllvmTMBcontrol(aghq = k)`) with its own, separately-scoped evidence;
> AGHQ and `REML = TRUE` cannot be combined.

(User-facing text deliberately cites no internal file/line references or
register codes — the standing reader-surface rule; the evidence trail lives
in this design doc instead. The AGHQ sentence points at that engine's scope
rather than recommending it: AGHQ's integrator is established, its estimator
is not.)

Guard for future edits: the sentence "unvalidated: a hypothesis under test,
not an inherited result" is the load-bearing honesty for the
variance-component / heritability audience — do not soften it if this
slice later produces a positive-looking number; promotion goes through its
own decision, not through a doc edit.

## 8. UNVERIFIED flags

- ~~Per-fit wall-clock timing for this exact grid (family x T x n x arm) —
  not found in-repo; §4's 5–15s assumption is stated as an assumption per
  D-139, not sourced from a prior measurement.~~ **MEASURED (2026-08-16),
  48-fit pre-run:** arms A/B match the assumption (means 5.9s / 6.1s, max
  19.3s / 23.3s); arm C (AGHQ, `k=7`, ridge off) does not (mean 69.9s, max
  345.1s at `ordinal_probit`, `T=8`, `n=200`). Full breakdown:
  `dev/coxreid-prerun/RESULTS.md`.
- Whether `k = 7` (or any specific node count) is the right AGHQ setting for
  arm C at this `q = 1`, small-`n` scale — the existing AGHQ evidence
  (`dev/aghq-evidence/`) establishes AGHQ's general behaviour but this slice's
  own node count is not pre-tested; the pre-run test (§4) should report
  convergence at whatever `k` is chosen.
- Whether Reid & Fraser orthogonality (as opposed to invariance, which arm D
  probes) holds or fails for gllvmTMB's Lambda/Psi parameterisation — this
  slice does not test orthogonality directly (see §2, arm D note) and no
  orthogonality check exists in-repo for this model class.

## 9. Campaign outcome (2026-08-16)

**The full A+B campaign ran** (arm C dropped, arm D not run): 1,600 fits,
2 families x `T in {4,8}` x `n in {100,200}` x arm {A,B} x seed 1:100,
`aghq_ridge = Inf` (off) identically in both arms, 100% convergence in both
arms. Full adjudication: `dev/coxreid-ab/RESULTS.md`; script:
`dev/coxreid-ab/adjudicate.R`; raw data: `dev/coxreid-ab/coxreid-ab-full.csv`
(commit `ae17a501`).

**K1 FIRES.** At the pre-registered `n = 100` gate, arm B's median absolute
bias in latent SD is *larger*, not smaller, than arm A's in both families
(reduction −3.58pp binomial, −1.31pp ordinal_probit — both `< 2pp`, the
opposite sign from a positive Cox–Reid effect). Medians are the primary
metric because the raw mean is dominated by a degenerate/runaway tail
concentrated in `n=100` cells (up to 26 runaway rows in one cell); the
spec-literal MCSE (SD of the paired difference / √n) is itself inflated by
that tail and does not clear governance, but the bootstrap MCSE of the
paired **median** difference — the statistic K1 is actually adjudicated on
— is 22–53x smaller than the 2pp threshold, so the null read is
well-powered, not underpowered.

The pre-run's reproducible `binomial, T=8, n=100, seed=2` degenerate cell
**recurs** at comparable magnitude (norm_ratio 5.4/5.6 vs the pre-run's 7.7,
converged, paired across arms, unflagged); more broadly this cell shows a
14% recurrence rate for that pathology class across the full 100 seeds, and
`binomial T=4 n=100` is a *worse* cell than `T=8 n=100` for runaway mass
(26 vs 17 runaway rows across both arms).

**K2 (non-invariance) and K4 (interval harm) are UNADJUDICATED** — arm D and
any coverage/interval columns were out of scope for this campaign; K3
(ridge confounding) is likewise unadjudicated as a formal test (no arm C, no
default-state comparison run), though this campaign's own A-vs-B ridge
equality means the K1 read above is not vulnerable to that specific
asymmetry.

**No promotion decision follows.** `allow_nongaussian_reml` stays opt-in and
unvalidated (§6 above, unchanged); the §7 roxygen honesty text is untouched.
This is a reportable negative result for the Cox–Reid hypothesis in
gllvmTMB's own parameterisation on these two families — not a closure of K2
or K4, and not evidence either way about a different structure, ridge
setting, or family. Candidate hand-in to Design 66 (§5) should **not**
budget seeds for a Cox–Reid arm on this evidence.
