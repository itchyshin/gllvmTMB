# Honest variance-component SEs for VA/EVA — scoping note

**Status: SCOPING ONLY.** Fisher (statistical reviewer), design/scoping mode, no code
written or run. Worktree `/private/tmp/gllvmtmb-va-lane2`, branch `claude/va-lane2`.

**dr21 sources: UNVERIFIED LEAD.** Every claim attributed to dr21 (or to the underlying
NotebookLM notebook `b25e6c9f`) below is quarantined per the standing rule — treated as
an unverified literature lead, never as an established fact about our own implementation.
Claims about *our* code are cited `file:line` and are independently checkable.

**Housekeeping note.** This repo already ran its own literature pass on the identical
NotebookLM notebook three days before this task (`docs/dev-log/2026-07-31-ranga-eva-literature.md`,
by Ranganathan). Where that pass traced a number to primary source and dr21's framing is
looser, I follow the more careful reading and say so.

---

## 1. Is this our problem? What do we currently report as uncertainty?

**A correction to the task's own framing, worth stating before anything else.** Finding #3
as given reads as one phenomenon ("VA underestimates posterior variance of latent variables;
EVA's underestimation of that same quantity is reported as even more severe... coverage for
ΛΛᵀ collapses to 39.47%"). Ranga's in-repo literature pass, three days earlier, traced these
to two *different* papers about two *different* objects and warned against merging them:
the EVA paper's own Discussion admits underestimating the posterior covariance of
**individual predicted latent scores** (Aᵢ, a per-observation quantity), while the 39.47%
number is FLAIR's (Mauri & Dunson) independent finding about **Σ = ΛΛᵀ** (the population-level
structural covariance) — "these should not be treated as the same phenomenon"
(`docs/dev-log/2026-07-31-ranga-eva-literature.md:108-114, 449-454`). I follow that separation
throughout: section 1b below distinguishes our own analogue of the *first* object
(`.va_r3_latent_posterior()`, an Aᵢ-type SE) from our own analogue of the *second*
(`.va_r3_fixed_information()`, a `theta_rr`/`Lambda`-type SE, the one section 3 is about).

Two completely separate answers, for two completely separate fit classes. Both `loading_ci()`
and `bootstrap_Sigma()` gate on `inherits(fit, "gllvmTMB_multi")`, and a VA fit does not carry
that class — so the two answers below are not two ends of one spectrum, they are two
disconnected code paths.

### 1a. The default (Laplace/native) route — `gllvmTMB_multi` fits

Uncertainty for loadings and Sigma is reported via three method families, all keyed off
`fit$sd_report`, which comes from a real `TMB::sdreport()` call on the **Laplace** objective
(`R/fit-multi.R:6087`) — never the VA/EVA objective (see 1b).

- **Wald / delta method** on raw or standardized Lambda entries: `loading_ci()`
  (`R/loading-ci.R:112`) requires `inherits(fit, "gllvmTMB_multi")`
  (`R/loading-ci.R:119-120`) and combines a numerical Jacobian
  (`R/loading-uncertainty-helpers.R:27`) with `fit$sd_report$cov.fixed`
  (header comment, `R/loading-ci.R:18-24`). PR #921/#924 landed <12h before this note
  (`docs/dev-log/after-task/2026-08-03-standardized-loading-inference.md`) and made this
  scale-explicit (raw `Lambda` vs standardized `rho`), propagating the *complete*
  fixed-parameter covariance rather than an entrywise heuristic. Design 75's truth matrix
  records this route as `partial` for `Sigma`/communality/`rho`/repeatability at every tier
  (elementwise delta, not a joint interval) (`docs/design/75-inference-route-truth-matrix.md:110-116`).
- **Profile-LR**: `covered` for direct SD; `partial` for `Sigma` (diagonal direct, low-rank
  routes to bootstrap); `blocked` for communality/`rho`/repeatability/proportion at every
  tier (`docs/design/75:110-116`); every augmented nonlinear profile is `blocked`, full stop
  (`docs/design/75:209-213`).
- **Parametric bootstrap**: `bootstrap_Sigma()` (`R/bootstrap-sigma.R:196`), also gated on
  `inherits(fit, "gllvmTMB_multi")` (`R/bootstrap-sigma.R:208-209`), simulates via
  `simulate.gllvmTMB_multi()`, refits, and returns percentile CIs for Sigma/R/communality/
  ICC/cross_corr. `opt-in` only (Design 75). It carries its own honesty machinery: a hard
  arithmetic floor (`n_boot >= 39` for a 95% percentile interval to be mathematically
  possible at all; default `999`; the ceiling is returned as `$coverage_ceiling`
  — `R/bootstrap-sigma.R:228-246`). A *separate* file, `R/loading-ci-bootstrap.R`, implements
  a percentile bootstrap for individual raw Lambda entries specifically, and by its own
  header is **not yet wired** into `loading_ci(method = "bootstrap")`
  (`R/loading-ci-bootstrap.R:6-9`) — a distinct, partially-built route, not the same function
  as `bootstrap_Sigma()`.
- No cell here carries a blanket calibration certificate: "No cell in this matrix is
  empirical-coverage-calibrated" (`docs/design/75:98`), and `loading_ci()`'s own roxygen
  says interval methods are "provided for exploration: their empirical coverage is not
  certified for this estimand ... treat the intervals as exploratory" (`R/loading-ci.R`,
  "Interval calibration" section, immediately above line 112). The one calibrated exception
  in project history (gaussian `Sigma_unit_diag`, profile/log-SD-Wald, held at a 0.94 floor
  per the live snapshot in `CLAUDE.md`) is itself on the Laplace route — unrelated to VA.

### 1b. The VA/EVA (opt-in, research) route — `gllvmTMB_va` fits

The answer here is categorical, not partial: **no calibrated uncertainty of any kind is
obtainable through the public API**, for loadings or for Sigma, by design.

- `confint.gllvmTMB_va()` and `vcov.gllvmTMB_va()` (`R/va-methods.R:178-199`) raise an error
  for **every** `gllvmTMB_va` object, unconditionally — they never attempt a computation.
  Message: "the inverse variational Hessian is not calibrated frequentist uncertainty, so
  no interval computed from it would have its nominal coverage" (`R/va-methods.R:187-189`).
- `loading_ci()` and `bootstrap_Sigma()` both hard-require class `"gllvmTMB_multi"`
  (`R/loading-ci.R:119-120`; `R/bootstrap-sigma.R:208-209`). A VA fit's class is
  `c("gllvmTMB_va", "gllvmTMB")` (`R/va-routing.R:432`) — it deliberately does **not**
  inherit `gllvmTMB_multi` (Design 85 §10, cited at `R/va-methods.R:3-5`), so both functions
  reject it before any numerical step runs.
- No `TMB::sdreport()` call exists anywhere in the VA/EVA engine code: zero hits searching
  `R/va-r3-proto.R`, `R/eva-proto.R`, `R/approximation-engine.R`, `R/va-routing.R`. The only
  `sdreport()` in the package fires on the Laplace path (`R/fit-multi.R:6087`).
- There **is**, however, more than "nothing" sitting unexported inside the engine — this is
  the single most important fact for section 3. `.va_r3_fixed_information()` /
  `.va_r3_fixed_information_blocked()` (`R/va-r3-proto.R:1436-1670` region) compute two
  Hessian-based SEs for the VA-R3 engine's fixed/global block (`beta`, and `theta_rr` — the
  packed raw `Lambda`, confirmed by `R/va-r3-proto.R:313-314`), directly from
  `objective$he(par)` (the call already sits at `R/va-r3-proto.R:1761`):
  - `se_conditional`, from the fixed-block Hessian alone, documented in the code's own words
    as "expected ANTI-CONSERVATIVE" because it "IGNORES the fact that `m` and the Cholesky
    would re-optimise as beta and theta_rr move" (`R/va-r3-proto.R:1443-1446`) — this is
    exactly the naive mistake dr21 warns about, already named and rejected internally.
  - `se_profile`, the Schur complement `H_ff - H_fv H_vv^-1 H_vf`, documented as "the correct
    observed information for the fixed parameters" (`R/va-r3-proto.R:1447-1450`).
  - Both are returned with `calibrated = FALSE` **hardcoded** regardless of route or success
    (`R/va-r3-proto.R:1666, 1730, 1748, 1754`), "until a coverage study says otherwise"
    (`R/va-r3-proto.R:1392`).
  - Tests cross-validate the O(N) block-diagonal shortcut against an O(N³) dense
    recomputation to `1e-8` and confirm `se_profile >= se_conditional`
    (`tests/testthat/test-va-r3-prototype.R:307-408`) — this machinery is numerically sound,
    not a stub.
  - A parallel, analogous helper, `.va_r3_latent_posterior()` (`R/va-r3-proto.R:1397-1432`),
    computes **per-unit** latent-score SEs (the `A_i`-type object) with the same
    `calibrated = FALSE` gate (line 1432) and the explicit comment "Variational posteriors
    are known to understate spread; the size of that understatement here is unmeasured"
    (`R/va-r3-proto.R:1392-1394`) — our own code already names, in its own words, essentially
    the first clause of dr21 Finding #3 ("VA underestimates posterior variance of latent
    variables"), independent of reading any literature.
  - None of this is reachable from `gllvmTMB()`, `confint()`, or any exported function. It
    exists only to be exercised by `test-va-r3-prototype.R`'s own regression tests.
  - **EVA has none of this.** `R/eva-proto.R` (573 lines total) contains no Hessian/SE helper
    of any kind — the only "hessian" hit in the file is an unrelated scalar curvature
    calculation used in a starting-value heuristic (`R/eva-proto.R:556-557`), not an
    inference calculation. The Schur/profile-information head start described above exists
    for **VA-R3 only**, not for EVA — a point that matters a great deal for section 3 and 5,
    because dr21's specific ΛΛᵀ-collapse number is about EVA.

**Bottom line for section 1:** for the default route, we already have a real (if partial,
uncalibrated-by-blanket-claim) Wald/profile/bootstrap SE apparatus built on genuine TMB
`sdreport()` output. For VA/EVA, the public answer is "nothing, by design, on purpose,
tested" — but privately, for VA-R3 specifically, a mathematically serious partial answer
already exists, unexported and explicitly marked uncalibrated.

---

## 2. Does the diagnosed failure apply to our route? LIVE DEFECT vs PROMOTION PREREQUISITE

**Answer: PROMOTION PREREQUISITE, not a live defect.** No user, published example, or
internal extractor can obtain a VA/EVA-derived number that looks like a calibrated SE today.
Evidence, layered (any one of these alone would already be sufficient):

1. **Public default excludes VA entirely.** `gllvmTMBcontrol(integration = c("laplace",
   "va"))` (`R/gllvmTMB.R:1475`) — R's `match.arg` takes the first element, so ordinary
   `gllvmTMB()` calls use Laplace and never construct a VA object at all unless a caller
   explicitly writes `integration = "va"`.
2. **Even opted in, a narrow fence gates it, erroring rather than warning.** `unique = FALSE`
   only (no Psi — every VA measurement in the package suppresses it,
   `R/integration-fence.R:13-16`), `binomial`-logit / `poisson`-log / `gaussian`-identity only,
   `q <= 2`, `p <= 80`, `n >= 100`, native TMB engine only
   (`.gllvmTMB_integration_fence_limits()`, `R/integration-fence.R:46-55`, checked by
   `.gllvmTMB_check_integration_fence()` starting at `R/integration-fence.R:58`). Requesting
   outside this region is an error (`R/integration-fence.R:1-6` states this is deliberate: "a
   warning would let a user keep a fit from outside the evidenced region").
3. **`"eva"` is not even an admitted value of `integration`.** The enum is
   `c("laplace", "va")` only (`R/gllvmTMB.R:1475`); the roxygen is explicit: "There is no
   `"eva"` value... it is not wired to `gllvmTMB()`... Its own measurements are the reason
   it is not a candidate here: EVA delivers valid inference for the regression coefficients
   but not for `Lambda Lambda'`" (`R/gllvmTMB.R:1332-1338`). The validation register
   independently records this as "a decision on evidence, not an unfinished feature ... stated
   in the literature **and independently reproduced on this repo's own grid**" (VA-08,
   `docs/design/35-validation-debt-register.md:731`) — that internal reproduction is
   `docs/dev-log/2026-07-31-eva-misuse-probe.md`, and it tested the external CRAN `gllvm`
   2.0.13 package, **not** our own `R/eva-proto.R` prototype (see caveat below).
4. **Categorical fail-loud regardless of the above.** `confint`/`vcov` on `gllvmTMB_va`
   always error (`R/va-methods.R:178-199`), independent of family/size/fence state. The
   register records this as policy, not gap: "VA-06 ... `blocked` ... `calibrated = FALSE`
   is a decision, not a gap to be filled quietly" (`docs/design/35:729`).

**A precision the task's framing blurs, worth stating exactly:** "`default_tier` is `\"gh\"`"
is a *different*, lower-level default than the public fence. `default_tier` is which of the
VA-R3 engine's own internal evaluators (`gh` quadrature / `jj` bound / `ac` closed form)
`eval_method = "auto"` resolves to, **per family** (`R/va-r3-proto.R:1142-1147`). It is `"jj"`
for binomial-logit specifically (`R/va-r3-proto.R:1174`) and `"gh"` for gaussian-anchor,
poisson, nbinom2, and binomial-probit (`R/va-r3-proto.R:1156, 1190, 1207, 1242`). This is an
internal numerical-method selector, orthogonal to whether VA is reachable at all — but both
facts point the same way: nobody gets a VA fit, let alone a VA SE, without deliberately
opting all the way in.

**Why this changes priority, per the task's own framing:** because #1-4 above are already
true today, there is no live user-facing breakage to fix. The urgency is entirely
forward-looking — this is groundwork for a *future* promotion decision ("ship a calibrated
VA/EVA uncertainty route as part of best-in-class VA"), not remediation of a shipped claim.
That said, "prerequisite" undersells how much of the hard part already exists for the VA-R3
engine specifically (section 3) — this is closer to "70% built, 0% validated, 0% wired" than
"not started."

**One nuance to carry into section 5:** dr21 Finding #3's *specific number* (39.47% ΛΛᵀ
coverage) is about **EVA**, and EVA is the engine with *none* of the internal head start
described in section 1b. The engine with the head start (VA-R3) is not the one the sharpest
literature number is about. This asymmetry matters for scoping the fix.

---

## 3. The two fixes, assessed against our machinery

### 3a. What TMB actually hands us

TMB gives exact (automatic-differentiation, not finite-difference) gradients and Hessians of
whatever objective is written into the compiled template, via `obj$gr()` / `obj$he()`, for
free — no separate derivation, no numerical differencing. This is already fully exploited
twice in this package: once for the Laplace route's calibrated inference
(`TMB::sdreport()`, `R/fit-multi.R:6087`), and once — unexported, uncalibrated — inside the
VA-R3 engine itself (`objective$he(par)` at `R/va-r3-proto.R:1761`). Both VA-R3 and EVA are
built the same way structurally: `TMB::MakeADFun(..., random = NULL, ...)`
(`R/eva-proto.R:181, 371`; `R/va-r3-proto.R:1985, 1987`) — every parameter, global (`beta`,
`theta_rr`) **and** local/variational (`m`/`a`, `log_L_diag`/`log_A_diag`, `L_off`/`A_off`),
lives in one flat `PARAMETER` vector, jointly optimised by `nlminb`
(`R/va-r3-proto.R:1369, 1505, 2176`). Nothing is integrated out via TMB's own Laplace/`random=`
machinery inside the VA objective itself — the code is explicit about why that would be
*wrong* here: "the variational coordinates are optimisation variables of a deterministic
bound, not latent random variables to integrate over" (`R/va-r3-proto.R:1974-1976`). A
separate, alternative route uses TMB's own `profile=` mechanism with the Laplace correction
term explicitly suppressed, so it gives an *exact* profile rather than a Laplace
approximation of one (`R/va-r3-proto.R:1970-1973`: "no -1/2 log det H term is added, so the
outer objective is the EXACT profile").

**Consequence:** the joint Hessian of the VA/EVA objective, with respect to the *full*
stacked global+local parameter vector, is already mechanically available with no new AD
work. That is precisely the raw ingredient LRVB needs.

### 3b. LRVB, assessed

LRVB (Giordano/Broderick/Jordan) corrects mean-field VB's under-coverage by computing the
Hessian of the variational objective with respect to the *full* moment-parameter vector
(every block's mean and covariance parameters, not just one factor's own reported block),
then reading the corrected covariance off the appropriate block of that Hessian's inverse —
mechanically a Schur complement / implicit-function-theorem correction that accounts for how
one block's optimum would shift as another block moves, which a naive block-diagonal read
misses.

**This is, as far as I can tell working through the algebra against our own code, exactly
what `.va_r3_fixed_information_blocked()` already computes for the global block** —
`se_profile = ` the Schur complement of the joint Hessian, marginalising the per-unit
variational block (`R/va-r3-proto.R:1447-1450` and the Schur-complement loop immediately
below it). **This equivalence claim is my own inference from the code, not something the
repo's own comments assert** — the code uses classical profile-likelihood/observed-information
language throughout, never the name LRVB, and a `grep -ri "LRVB|linear response"` across
`R/` and `docs/` returns zero hits outside this note. The equivalence holds cleanly because
the variational family here is Gaussian and the objective is being locally quadratically
approximated at its optimum — exactly the regime LRVB is derived for.

What is *not* yet done, even granting the equivalence:
- The existing machinery targets `theta_rr` (raw packed `Lambda`) and `beta` directly. Getting
  from there to `Sigma_B = Lambda Lambda'` needs a further delta-method Jacobian step — the
  same pattern `R/loading-uncertainty-helpers.R` already implements for the Laplace route,
  not yet built for VA.
- It is single-tier only; a second tier is refused by construction
  (`.va_r3_multi_tier()`, `R/va-r3-proto.R:1688-1690`) — this matches the existing VA fence's
  scope anyway, so it is not an *additional* restriction in practice.
- It exists for VA-R3 only. EVA has nothing analogous (section 1b) — and EVA is specifically
  the engine dr21's sharpest number is about, and the engine our own register already flags
  as having a point-estimate/degeneracy problem, not merely a variance-calibration one (see
  3d).
- No coverage study has run against it (section 4).

**Verdict: nearly free, more than nearly — a large fraction of the correction is already
built, tested for internal numerical consistency, and sitting behind an explicit
"uncalibrated" gate for VA-R3.**

### 3c. FLAIR-ρ, assessed

FLAIR's variance-inflation factor is, per dr21, an analytical correction derived
specifically for high-dimensional **logistic** factor models with a particular
pretraining/prior scheme — a different paper's different model, not a general mean-field VA
correction. Adopting it would mean re-deriving a model-specific inflation factor against our
own exact ELBO structure (which differs from FLAIR's construction), and it would not obviously
generalise across the families our fence already admits (gaussian-identity, poisson-log,
binomial-logit, binomial-probit) the way a generic Hessian-based correction does. There is no
existing scaffolding for it in this repo at all — it would start from zero, not from the ~70%
head start LRVB/Schur already has.

### 3d. Which is the better bet

**LRVB (via the existing Schur/profile-information machinery).** It reuses an ingredient
(`obj$he()`) already exact and already called; it has a partial, tested implementation in
`R/va-r3-proto.R` today; it is architecture-agnostic across families rather than tied to one
paper's logistic-factor construction. FLAIR-ρ would need to be derived essentially from
scratch, for uncertain transferability.

**A caveat that bounds how far this goes.** LRVB-style corrections fix miscalibrated
*variance around an otherwise-good point estimate*. They do not fix a *biased or
degenerate point estimate*. `docs/dev-log/2026-07-31-eva-misuse-probe.md`'s verdict on the
external `gllvm` package's EVA is "GENUINE METHOD BEHAVIOUR... converges to a degenerate mode
that its own objective genuinely prefers to the truth" (line 15) — a point-estimate pathology,
not a variance-calibration one; no amount of LRVB correction repairs an interval built around
the wrong center. This has **not** been independently confirmed on our own `R/eva-proto.R`
prototype (the probe tested the external CRAN package only) — flagged as an open question,
not a settled fact about our code. It is a further reason 3b's machinery, which lives on the
VA-R3 (GH/JJ/AC) engine — the one this week's mature-VA arc concluded is "the better VA" over
our own AC/EVA-adjacent tiers (`docs/dev-log/handover/2026-08-03-claude-handover-mature-va-item1.md`,
"gllvmTMB already has the better VA — it is our GH tier, not AC", line 280) — is the more
promising target than trying to first calibrate EVA's uncertainty.

---

## 4. What we could measure ourselves, cheaply

**Precedent that sets the bar.** This arc has already retracted two claims for resting on 1
and 6 seeds, with per-seed `rel_frob` ranging 0.13-0.46
(`docs/dev-log/handover/2026-08-03-claude-handover-mature-va-item1.md`, "What is NOT settled"
section). That was a **continuous** point-estimate statistic. Coverage is a **Bernoulli**
outcome per replicate, which is at least as noisy per unit of sample size (Var = p(1-p),
0.0475 at nominal p = 0.95) — so anything that failed to be decisive at 6 replicates for
`rel_frob` will be far less decisive for a coverage proportion at the same n. The existing
in-house pattern for this exact kind of study, `coverage_study()` (`R/coverage-study.R:123`),
defaults to `n_reps = 30` and says so itself: "This prototype is not a publication-quality
validation" (roxygen directly above the function). That function cannot be pointed at a
`gllvmTMB_va` fit without rework (it is built on `confint.gllvmTMB_multi()`), but its schema
(`parm x method x n_reps x n_covered x rate`) is worth mirroring in a small new VA-specific
driver rather than inventing a new one.

**Design (mirrors the existing fence exactly, so any promotable result is automatically
in-fence):**

- **DGP:** single ordinary `latent()` tier, `unique = FALSE` (no Psi — required by the fence
  and it simplifies the target to `Sigma_B = Lambda Lambda'` exactly), binomial-logit link
  (the fence's best-evidenced family, VA-05, `docs/design/35:728`), `q = 2` (the fence's
  `q_max`, and the size the underlying literature also used).
- **Grid:** `p in {20, 80}` (well inside `p_max = 80`, two meaningfully different sizes),
  `n in {100, 400}` (the fence's `n_min`, plus a 4x-larger value already used elsewhere in
  this week's VA benchmarking) — 4 cells. Deliberately small; this is a screening design, not
  a certificate.
- **Quantity scored, two arms per replicate:** empirical coverage of a nominal 95% Wald CI on
  the raw `theta_rr` (packed `Lambda`) entries, built from (a) `se_conditional` — the naive,
  already-flagged-as-anti-conservative SE, and (b) `se_profile` — the Schur/LRVB-style
  corrected SE. Scoring the raw `Lambda` scale first avoids needing the not-yet-built
  Sigma-scale delta-method Jacobian (section 3b) before the first honest read is in hand; a
  `Sigma_B`-scale rerun is the natural follow-on once that Jacobian exists.
- **Replicate count — the actual power question:**
  - *Screening pass:* `n_sim = 200` replicate datasets per cell (800 fits total, comparable in
    scale to VA-05's own 6,480-fit Gate 3 campaign but far smaller, Totoro-parallelisable).
    At nominal `p = 0.95`, MCSE `= sqrt(0.95*0.05/200) approx 0.0154`, so a 2*MCSE lower band
    sits at `approx 0.92` — decisive against anything resembling dr21's reported 39-90% range,
    and decisive against `se_conditional` being clearly anti-conservative if it is. **Not**
    decisive for a marginal result (e.g. distinguishing 0.93 from 0.95).
  - *Certificate-grade pass, only if the screen finds a real gap worth fixing and reporting:*
    `n_sim >= 1000` per cell (4,000 fits total), mirroring `bootstrap_Sigma()`'s own
    documented default (999) and its stated arithmetic ("at the documented default of 999 the
    same estimand covers 0.9418", `R/bootstrap-sigma.R:236-237`). At `n_sim =
    1000`, 2*MCSE `approx 0.0138` at `p = 0.95` — resolving power comparable to what the
    package's existing 0.94-gate certificates already require elsewhere.
- **What this buys:** a first, owned, honest read on whether `se_conditional` (naive) is
  visibly anti-conservative in practice and whether `se_profile` (Schur/LRVB-style) closes
  the gap — on our own engine, our own template, in-fence — rather than reasoning from one
  external paper's one design.

---

## 5. Verdict

**PURSUE, scoped to the VA-R3 engine's global-parameter block, not to EVA.** Two sentences:
this is the rare case where the mathematically hard part of a genuine differentiator (an
exact-Hessian, Schur-complement variance correction structurally equivalent to LRVB) is
already built, unit-tested, and numerically cross-validated inside `R/va-r3-proto.R`, sitting
unused behind an honest `calibrated = FALSE` gate — closing the gap to a Sigma-scale delta
method and an owned coverage read (section 4) is a small, bounded increment, not a new
research programme. EVA is a separate decision: it has none of this scaffolding, our own
register already treats it as having a point-estimate/degeneracy problem an interval fix
cannot repair, and this week's own mature-VA arc concluded our GH/JJ VA-R3 tiers already beat
it — so the honest recommendation is to let EVA stay `blocked` and *not* spend this arc's
effort trying to calibrate uncertainty around a point estimate that may itself be unreliable.

**Seed count for question 4: 200 replicate datasets per cell for a decisive screening pass
(4 cells, 800 fits) that can already detect gross brokenness; >=1000 per cell (4,000 fits) for
a certificate-grade number, only if the screen finds something worth certifying.**
