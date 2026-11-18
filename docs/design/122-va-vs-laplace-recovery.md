# Design 122 — pre-registered VA-vs-Laplace recovery study

**Status: PROPOSAL.** Pre-run authorised in the current arc under D-139. The
FULL confirmatory campaign is gated on Design 66 capstone scoping AND explicit
maintainer approval — nothing in this document authorises compute beyond the
pre-run in §7. Lane: `claude/doc-lane-diag-reml-slopes-20260816`, worktree
`/private/tmp/gllvmtmb-doc-lane-20260816`. Framework: ADEMP (Morris, White &
Crowther 2019, *Statistics in Medicine* 38:2074–2102) plus the 11 transparent-
reporting items of Williams et al. (2024, *Methods Ecol. Evol.* 15:1926–1939);
a self-audit against both appears in §11.

## 0. What this answers, and why it is not answered yet

The 2026-08-02 handover
(`docs/dev-log/handover/2026-08-02-claude-handover-gate-a-closed.md`,
"Next Immediate Steps" item 3) named this study directly: *"Ask: does VA
recover `Sigma_B` better than Laplace on probit, at realistic size, with two
tiers? … If VA ties or loses, ~7 days of Stages 3/5 are saved."* Two premises
under Design 108's 17–26 day Gate-B programme are unvalidated, and this study
is designed to close both at once:

1. **Does the VA route recover `Sigma_B = Lambda Lambda'` more accurately
   than Laplace** on the families Design 108 actually targets (probit,
   ordinal-probit), rather than on the Bernoulli-logit cells where all prior
   VA-vs-Laplace recovery evidence was measured
   (`docs/design/108-va-parity-programme.md` §0.1: *"GH-VA is worse than JJ
   [on Bernoulli-logit]… relative Frobenius error on `Sigma_B` 2.19 vs 0.87 at
   `n=60,p=12`"*, and separately *"Ayumi has no Poisson columns"*)?
2. **Does Design 108 §0.2's silent-divergence justification for the VA
   programme transfer to probit at the sizes this study covers?** §0.2 itself
   states the finding is *"a Bernoulli-logit result on small n… Whether it
   reproduces on probit + ordinal + missing data at N = 5397 is unknown, and
   Stage 8 exists to find out. If it does not reproduce, this programme is
   optional and should be reconsidered."* Design 108 Stage 8
   (`dev/design108-stage8/README.md`) already ran a large Laplace-only grid on
   binomial-probit/ordinal-probit/gaussian-control and found the rate *decays
   with n* (2026-08-02 handover, Critical Context 1: *"18.1% at n≤150 → 0.6%
   at n≥1600"*, and `aghq_ridge = 2` *"drives it to ~0 across the whole
   ladder"*). That finding used a different DGP convention (`loading_sd()`
   homog/`sigma_lambda` shape, no VA arms) than this study's Gate-3-style
   frozen-`Lambda_0` truths, so this study's K4 (§6) is an internal
   replication check on its own grid, not a re-quote of Stage 8's number —
   the two are complementary evidence, not the same measurement repeated.

The study is explicitly **not** trying to answer whether VA is faster (Design
108 §0.1 already closed that question against VA: *"nothing in this programme
should be sold on speed"*) or whether VA gives calibrated intervals (out of
scope; VA is `calibrated = FALSE` throughout, `R/gllvmTMB.R:1446,1463`,
`"…are labelled calibrated = FALSE"`). It answers exactly one thing: **is
there a measured accuracy or reliability payoff to the VA route on Design
108's own target families, large enough to justify continuing the programme
before Stages 3 and 5 are built.**

## 1. Aims (Williams item 1)

**Primary aim.** Estimate, per stratum of signal strength × n, the difference
in `Sigma_B` recovery error (stratified relative-Frobenius norm) between the
opt-in VA route (`integration = "va"`, GH evaluator) and the shipped Laplace
route, with and without the loading ridge, on `binomial_probit` and
`ordinal_probit` at Design-108-relevant sizes — and to determine, via K3
(§6), whether that difference is large enough and consistent enough to
justify Design 108 Stages 3 and 5.

**Secondary aims.**

- Measure whether Laplace's silent-divergence rate on probit decays with `n`
  inside this design's own grid and its own truth convention (K4, §6),
  replicating the qualitative Stage-8 finding under a different DGP.
- Measure whether the VA JJ evaluator (admitted only for pure binomial-logit,
  `R/gllvmTMB.R`: `"jj" … is defined only for pure binomial-logit fits"`)
  offers a materially different accuracy/cost trade to GH on the cells where
  it is admissible, as a **nested sub-study**, not a confirmatory arm.
- Characterise ordinal-probit-specific behaviour (cutpoint recovery, joint
  cutpoint–Lambda scale interaction) given that no degeneracy detector exists
  for that family (issue #897, cited in `dev/design108-stage8/README.md`:
  *"the shipped detector caught 272/272 degenerate binomial-probit fits but
  never runs on ordinal_probit (239/239 unflagged)"*).
- Record, as a pre-registered but explicitly deferred module, whether the
  augmented-vs-tips-only phylogenetic ELBO factorisation is statistically
  right (Design 106 §3.6) — deferred because it needs the phylo tier, which
  sits outside the VA admission fence today (§9).

## 2. The adversarial critique this design answers point-for-point

A prior adversarial pass (Fisher lens) raised five binding objections against
an earlier sketch of this study. Every one is design text below, not a
footnote, because a study built to answer "does VA beat Laplace" that does
not defend against these five specific failure modes would certify nothing.

### F1 — optimiser-artifact risk

A measured accuracy gap between two engines is worthless if it is actually a
gap in how hard each optimiser tried. This design commits to:

- **Identical optimiser budgets, starts, and tolerances across all arms.**
  Every arm uses `gllvmTMB()`'s default multi-start policy
  (`n_init`, `optimizer`, `optArgs` left at package defaults) unless a
  specific arm's control forces a divergence the fence requires (VA's own
  multi-start/optimiser policy is engine-internal and cannot be overridden —
  `R/gllvmTMB.R`, VA integration note: *"the search settings of
  gllvmTMBcontrol() — n_init, optimizer, optArgs, start_from, init_\*, and se
  — have no effect on this route"* — so the Laplace arms are held to the
  package's own matching defaults rather than hand-tuned to compensate).
- **Cold start is the pre-registered estimand for every arm.** Warm-starting
  VA from a Laplace solution would answer a *different* question — "does VA
  improve on an already-good Laplace point" — not "does VA recover `Sigma_B`
  better than Laplace from the same starting information." Both are
  legitimate questions; this design commits to the cold-start one and states
  the warm-start comparison as an explicit non-goal, not a silent omission.
- **Per-fit primary columns**: `max_abs_gradient`, `iterations`,
  `convergence_code`, recorded for every fit of every arm, mirroring
  `dev/va-gate3/analyse-gate3.R`'s recorded `max_abs_gradient` (added there
  as defect fix #3: *"`max_abs_gradient` computed by the engine, dropped by
  the row builder [...] recorded, mirroring what the pre-registration already
  required"*) and `dev/design108-stage8/laplace-silent-divergence.R`'s
  `conv`/`pdhess` columns.
- **TEST A — the scale-perturbation optimum certificate**, adapted from
  `dev/aghq-scope-accuracy-crux.md` §5's TEST A (*"re-evaluate the objective
  at c·theta_hat for c in a neighbourhood of 1; the k=1 curve must peak at
  c_hat = 1.000"*). Applied here per arm and per fit in the pre-run (§7): at
  each arm's own reported optimum, re-evaluate that arm's own objective under
  a one-dimensional scale perturbation of the loading block,
  `c ∈ seq(0.95, 1.15, by = 0.01)`. **For VGH specifically, the variational
  parameters (`m_i`, `S_i` for every unit `i`) are RE-OPTIMISED at each
  perturbed `c`, not merely evaluated at the fitted optimum's `m_i`/`S_i`
  with `Lambda` rescaled.** Re-evaluating the ELBO at a rescaled `Lambda`
  while holding the variational parameters fixed at their original optimum
  would let VGH pass TEST A trivially — the ELBO is a lower bound, and an
  unmoved variational posterior does not probe whether `c = 1` is actually
  the loading scale that maximises VA's own objective, only whether the old
  posterior still bounds the rescaled model tolerably. The fitted point must
  be the visible maximiser of that arm's own (re-optimised, for VGH)
  objective along that line, **to a stated numeric tolerance: the parabolic
  fit's peak `c_hat` must satisfy `|c_hat - 1| <= 0.01`** (one grid step in
  the `c` sequence above — the same granularity `dev/aghq-scope-accuracy-crux.md`
  §5 uses for its own TEST A grid). This is a *within-arm* self-consistency
  certificate — it does not compare arms to each other — and it catches
  exactly the failure mode `dev/aghq-scope-accuracy-crux.md` names: *"If it
  does not [peak at 1.000], the objective is not the one that was optimised
  and nothing downstream means anything."*
- **K1 kill rule (§6), stated as a per-fit rule with a declared numeric
  tolerance.** The package has no single gradient tolerance that applies
  generically across Laplace and VA fits (`aghq_grad_tol = 1e-4` is an
  AGHQ-specific convergence-loop parameter, `R/gllvmTMB.R:1709`, not a
  general-purpose gradient bound), so this design declares its own:
  **`grad_tol = 1e-3`**. **K1 fires if TEST A fails for any arm (`|c_hat -
  1| > 0.01`), OR if more than 10% of pre-run fits in any single arm have
  `max_abs_gradient > 1e-3`.** Both conditions are evaluated per fit, not
  from a pooled median — a median can hide a fat tail of non-converged fits
  the same way a pooled RMSE hides a subgroup (F4). Either trigger voids the
  study: stop-and-fix, not a footnote finding.

### F2 — same-instrument requirement

`docs/dev-log/2026-07-31-gate3-result-corrected.md` found that Gate 3's
collapse criterion was **not** measured with the same instrument across arms
— `va_gh`'s degenerate solutions are intercepted upstream by a variance-domain
guard that `va_jj` does not have, so `va_gh` scored `any_axis_collapsed =
FALSE` in **0 of 6,480 rows**, and *"the two arms are not measured with the
same instrument."* This design closes that hole three ways:

- **The two-sided detector** (`dev/va-gate3/two-sided-detector.R`) —
  `flag_inflated = rel_frob > 10` (the original one-sided rule,
  `dev/totoro-grid/analyse-grid.R:99`) **OR** `flag_contracted = kappa < 1/3`
  where `kappa = ||Sigma_hat||_F / ||Sigma_true||_F` — is applied identically
  to every arm's `Sigma_hat` (raw `Lambda %*% t(Lambda)`, computed the same
  way regardless of which engine produced `Lambda`). No arm gets a bespoke
  degeneracy definition.
- **`va_gh` guard-trips are logged as degenerate OUTCOMES, never missing
  rows.** When the VA engine's internal variance-domain guard rejects a fit
  (`dev/va-gate3/run-gate3.R:572`: `failed_variance_domain = "guard_rejected"`),
  that fit is recorded with `status = "guard_rejected"` **and**
  `two_sided_degenerate = TRUE` by construction — it counts toward the
  degenerate rate exactly as an unguarded `rel_frob > 10` fit from another arm
  would. This directly reverses the Gate-3 defect: a tripped guard cannot make
  an arm's degeneracy rate look artificially clean by removing the row from
  the denominator.
- **Three denominators per cell, every one printed, adapting Gate 3's R1/R2
  convention (`dev/va-gate3/analyse-gate3.R` §"apply_pass_rule"/
  §"`.drop_ml_degenerate`") to a three-arm design:**
  1. **raw** — `n_attempted`, every row whatever its status (matches
     `dev/va-gate3/analyse-gate3.R`'s comment: *"'every attempted fit in the
     denominator' governs n_attempted/rate_ok"*).
  2. **guard-inclusive** — `n_attempted` minus only hard `status == "error"`
     rows (a fit that never returned any number at all — no `Lambda`,
     timeout, crash); `guard_rejected` rows stay in this denominator per the
     point above.
  3. **all-arm intersection** — the seeds for which *every* confirmatory arm
     (L0, L2, VGH; §5) produced a usable `Sigma_hat`, i.e. the paired subset,
     directly extending Gate 3's R2 logic (*"R2 drops every replicate in
     which the [comparator] is itself degenerate [...] and drops it from ALL
     arms so the comparison stays paired"*) from a one-comparator design to a
     three-arm one: a seed is retained only if L0, L2, and VGH all produced a
     finite `Sigma_hat`.
- **The "silently" half of silent-divergence is measured with a genuinely
  different instrument on VGH than on L0/L2, and this design names the
  asymmetry rather than papering over it.** `pdHess` and `sdreport` come
  from `MakeADFun`'s Laplace machinery; grepping `R/va-*.R` for either finds
  zero hits, and the VA route's own documentation confirms `se` (the
  standard-error request) is one of the arguments that *"have no effect on
  this route"* (`R/gllvmTMB.R:1509-1510`). There is therefore no `pdHess`
  for VGH to report at all — using the Laplace-arm definition unmodified for
  VGH would silently score every VGH fit's `silent_divergent` as `FALSE`
  (undefined `pdHess` cannot satisfy `pdHess == TRUE`), manufacturing a
  guaranteed-zero rate rather than measuring one. §6.1 pre-registers the
  VGH-specific substitute (the Gate-3 `status == "ok"` proxy) explicitly, and
  it remains a **different instrument** from the Laplace arms' `convergence
  == 0 & pdHess == TRUE` criterion: `status == "ok"` certifies that the
  engine's own internal checks (including its variance-domain guard, F2
  above) did not reject the fit, which is not the same claim as "a
  positive-definite Hessian was verified downstream." This residual
  asymmetry is why K3's condition on relative silent-divergence rates (§6.2)
  is demoted to a descriptive report rather than a kill conjunct — a
  cross-instrument rate comparison is not a like-for-like test even after
  naming the best available substitute on each side.

### F3 — ordinal-specific requirements

- `K = 4` categories, fixed cutpoints `tau = c(0, 0.7, 1.4)`, matching
  `tests/testthat/test-ordinal-recovery-depth.R:49` (`.ord_depth_taus <-
  c(0, 0.7, 1.4)`) and the same convention already reused by
  `dev/design108-stage8/README.md` (*"K = 4 categories, fixed cutpoints tau =
  c(0, 0.7, 1.4) (matches tests/testthat/test-ordinal-recovery-depth.R's
  convention)"*).
- **Pre-declared category probabilities** giving ≥5 expected counts per
  category at `n = 100` (the smallest confirmatory n): with 4 categories and
  the fixed cutpoints above under a standard-normal linear predictor,
  category probabilities are approximately `Phi(0) = 0.500`,
  `Phi(0.7)-Phi(0) = 0.258`, `Phi(1.4)-Phi(0.7) = 0.161`, `1-Phi(1.4) = 0.081`
  at `eta = 0`; the smallest category (0.081) needs ≥62 observed units for an
  expected count of 5 at a single trait-site cell, comfortably inside
  `n = 100`. This must be re-checked against the actual per-trait intercepts
  drawn for each seed in the pre-run (§7), not asserted from the population
  marginal alone, because trait-specific intercepts shift these probabilities
  per trait.
- **Empty-category replicates scored NA with printed counts**, never dropped
  silently and never imputed — a trait-site cell that never realises one of
  the 4 categories in a given seed's draw makes the K=4 cutpoint estimate for
  that replicate undefined in the same sense Gate 3 treats an undefined
  collapse rate: *"undefined is not failure"*
  (`dev/va-gate3/analyse-gate3.R`, defect-2 comment). Per-replicate category
  counts are stored alongside the NA so the empty-category rate is itself
  reportable, not just excluded.
- **A joint cutpoint–Lambda scale diagnostic**: because ordinal-probit ties
  the loading scale and the cutpoint scale together through the same latent
  standard-normal index (the family shares `link = "probit"` with binomial
  and both route through `gll_log_pnorm_diff`-style machinery per
  `docs/dev-log/handover/2026-08-02-claude-handover-gate-a-closed.md`'s
  Stage-5 note on differencing machinery), a Lambda-scale runaway can hide
  behind a compensating cutpoint-scale shift that leaves fitted category
  probabilities looking reasonable. This design reports, per ordinal fit, the
  pair (`max|Lambda_hat|`, `max|tau_hat - tau_true|`) jointly, not just each
  marginally, so a joint runaway is visible even when neither statistic alone
  crosses its individual threshold.
- **Per-arm `max|Lambda|` distributions reported, unconditionally.** Per
  issue #897 (cited in §0 above), no degeneracy detector exists for ordinal
  data at all — `check_gllvmTMB()`'s `binomial_prevalence_loading` row is
  *"calibrated for logit-link binomial specifically"*
  (`dev/design108-stage8/README.md`) and does not fire on this family. In the
  absence of a detector, the raw `max|Lambda_hat|` distribution per arm is
  reported as the ordinal-specific substitute health signal, alongside — not
  instead of — the two-sided `rel_frob`/`kappa` detector, which remains
  computable for ordinal because it is defined on `Sigma_hat` directly and
  does not depend on any family-specific gate.

### F4 — exploratory cell fencing and no pooling across signal

- The `p = 80, n = 100` cell is **exploratory-only**, pre-registered as such
  in §5's grid table, and reported in a clearly separated table, never merged
  into the confirmatory K1–K4 gates. This mirrors the fence's own
  documented boundary (`R/integration-fence.R:62-68`, `.gllvmTMB_integration_fence_limits()`:
  `p_max = 80L`, `n_min = 100L` — the corner sits exactly on both admitted
  boundaries at once, which is precisely why it is informative but not
  confirmatory-grade).
- **All estimands are stratified by signal-strength (truth) × n, and never
  pooled across truth strata.** This directly reapplies the Gate-3 lesson
  named in its own corrected record: *"A pooled median hid the signal[...]
  There is a real JJ contraction subgroup [...] invisible under the pool"*
  (`docs/dev-log/2026-07-31-gate3-result-corrected.md`). Every RMSE, kappa,
  and divergence-rate table in §5/§8 below is indexed by (truth, family, n,
  p, arm) and no marginal-over-truth summary is reported as a headline
  number; a pooled table may appear only as a clearly labelled secondary
  view alongside the stratified one, never in its place.

### F5 — the confirmatory arm set is exactly three, VJJ is nested

The confirmatory factorial (§5) is **3 arms**: L0 (Laplace, no ridge), L2
(Laplace, `aghq_ridge = 2`), VGH (the public VA route, GH evaluator). VJJ is
a **pre-registered nested sub-study**, run only on the pure-binomial-logit
continuity block (§5), never folded into the probit/ordinal confirmatory
grid, because `va_eval_method = "jj"` is admitted only for pure
binomial-logit fits (`R/gllvmTMB.R`: *"'jj' uses the Jaakkola-Jordan bound,
which is defined only for pure binomial-logit fits"*) — including it in the
probit confirmatory grid would either be inadmissible (the fence would error)
or would silently substitute a different, unintended evaluator.

## 3. Data-generating mechanism (Williams item 2)

1. **Structure.** Single tier (Gate A's phylo/multi-tier extension is
   deferred, §9), `n` sites × `p` traits, `q = 2` latent dimensions
   throughout (matching Gate 3's certified region, `q ≤ 2`, and the fence's
   `q_max = 2L`, `R/integration-fence.R:62-68`).
2. **Latent scores.** `u_i ~ N(0, I_q)` iid across sites, `i = 1..n`.
3. **Loadings.** `Lambda` is `p × q`, frozen per (truth, q, p) combination
   using Gate 3's own construction — a random `p × q` matrix scaled so
   `max|Lambda_0|` hits an exact per-truth target, then rotated into
   `dev/va-gate3/run-gate3.R`'s canonical lower-triangular basis
   (`gllvmTMB:::.va_r3_rotate_to_lower_triangular`) — and reused verbatim
   from `dev/va-gate3/truths.rds` wherever a (truth, q, p) cell already exists
   there (`dev/va-gate3/run-gate3.R:205-210`: the runner loads `truths.rds`
   unconditionally when it exists, so this design inherits Gate 3's exact
   `Lambda_0` for every shared cell rather than redrawing it). Three signal
   strengths, Gate 3's own truth names and targets
   (`dev/va-gate3/run-gate3.R:85-86`):
   `TRUTH_NAMES <- c("T-weak", "T-mid", "T-strong")`,
   `TRUTH_TARGET_MAX <- c("T-weak" = 0.35, "T-mid" = 0.70, "T-strong" = 1.40)`.
4. **Fixed effects.** Per-trait intercepts, drawn as in the two prior
   harnesses this design reuses (`dev/heywood/link-coverage.R`'s and
   `dev/design108-stage8/README.md`'s convention: *"Trait-level intercepts
   are drawn N(0, 0.3)"*) — a moderate, non-extreme prevalence spread, so the
   ordinal category-count check in F3 remains approximately valid across
   traits without engineered separation.
5. **Response construction.**
   - `binomial_probit`: `eta = X*beta + Lambda*u`, `y ~ Bernoulli(Phi(eta))`.
   - `ordinal_probit`: same `eta`, `K = 4` categories cut by the fixed
     `tau = c(0, 0.7, 1.4)` (§ F3).
   - `binomial_logit` (continuity block only, §5): same `eta`, `y ~
     Bernoulli(logit^-1(eta))`.
6. **Conditions varied** (full table in §5).
7. **Missingness.** None in the confirmatory grid — this design's estimand is
   engine recovery accuracy under complete data; Design 108's missing-data
   admission is a *separate*, already-shipped surface
   (`docs/design/108-va-parity-programme.md` §0: *"missing responses… `stop`"*
   for the VA engine specifically) and mixing it in here would confound two
   unresolved questions. Recorded as a scope boundary, not an oversight.
8. **Replicates per cell.** Determined empirically from the pre-run's
   paired-difference SD (§7), not asserted in advance — see §4 seed formula.

## 4. Estimands / targets (Williams item 3)

| Estimand | Definition | Truth | Canonical source |
|---|---|---|---|
| `Sigma_B` relative Frobenius error | `rel_frob = \|\|Sigma_hat - Sigma_true\|\|_F / \|\|Sigma_true\|\|_F`, `Sigma_hat = Lambda_hat Lambda_hat'`, `Sigma_true = Lambda_0 Lambda_0'` | Frozen `Lambda_0` per (truth,q,p) | `dev/totoro-grid/run-grid.R:47`; `dev/design108-stage8/README.md` "Metric" |
| Scale ratio `kappa` | `\|\|Sigma_hat\|\|_F / \|\|Sigma_true\|\|_F` | as above | `dev/va-gate3/two-sided-detector.R:24` |
| Stratified `Sigma_B` RMSE | `sqrt(mean_over_seeds(rel_frob^2))`, stratified by **diag / \|off-diag\|≥0.1 / near-zero** entries of `Sigma_B` per Gate 3's own preregistered breakdown | per (truth,family,n,p,arm) cell | `dev/va-gate3/analyse-gate3.R` `.rmse_and_mcse()`; Gate-3 preregistration doc |
| Silent-divergence rate | **Canonical (two-sided) `degenerate := rel_frob > 10 OR kappa < 1/3`** (`dev/va-gate3/two-sided-detector.R`). "Silently": for **L0/L2** (Laplace-path arms, where `sdreport`/`pdHess` exist), `silent_divergent := degenerate & convergence == 0 & pdHess == TRUE`, the Stage-8 definition. For **VGH**, no `pdHess`/`sdreport` exists on the VA route at all (`R/va-*.R` has zero hits for either; `se` is explicitly listed among the arguments that *"have no effect on this route"*, `R/gllvmTMB.R:1509-1510`) — the pre-registered substitute is `silent_divergent_VGH := degenerate & status == "ok"`, the Gate-3 status-string proxy (`dev/totoro-grid/analyse-grid.R:100`). This is a **different instrument** from the Laplace-arm criterion, named explicitly in F2, and its cross-arm comparison is descriptive only (K3 condition 2 is not a kill conjunct, §6.2). A **secondary column** also reports the Stage-8 one-sided form (`rel_frob > 10` alone, no `kappa` leg) for cross-study comparability with Stage 8's own published numbers. | per (family,arm,n,p) cell | `dev/va-gate3/two-sided-detector.R` (canonical detector); `dev/design108-stage8/README.md` "Metric" (Laplace-arm `silent_divergent` and the one-sided secondary column); `dev/totoro-grid/analyse-grid.R:100` (VGH's `status == "ok"` proxy) |
| Cutpoint recovery (ordinal only) | `max|tau_hat - tau_true|`, reported jointly with `max|Lambda_hat|` (F3) | `tau = c(0, 0.7, 1.4)` | `tests/testthat/test-ordinal-recovery-depth.R:49` |
| Wall time | seconds per fit, per arm | — | `dev/design108-stage8/laplace-silent-divergence.R` (`seconds` column) |

`kappa` is reported **beside every target**, never substituted for `rel_frob`
alone, per `dev/va-gate3/two-sided-detector.R`'s own algebraic argument: a
one-sided `rel_frob > 10` rule is *"structurally blind to contraction"* — an
estimator that shrinks `Sigma_hat` toward zero can never trigger it
(`rel_frob <= kappa + 1 <= 2` whenever `kappa <= 1`), so `kappa` is the only
column in this design that can ever detect that failure mode.

## 5. Methods — arms and grid (Williams item 4)

### 5.1 Arms

| Arm | `gllvmTMBcontrol()` call | Role |
|---|---|---|
| **L0** | `gllvmTMBcontrol()` (default; `aghq_ridge` NOT named) | Confirmatory. Today's actual default-user behaviour — `aghq_ridge` stays inert unless the caller names it explicitly. The opt-in gate is `aghq_ridge_explicit <- !missing(aghq_ridge)` (`R/gllvmTMB.R:1761`), applied at `R/gllvmTMB.R:576`, documented at `R/gllvmTMB.R:1532-1536`; cited via `dev/design108-stage8/README.md`: *"aghq_ridge defaults to 2 as a gllvmTMBcontrol() argument… but on the Laplace path it is opt-in ONLY… A user who calls gllvmTMB() with no control= argument at all… gets NO ridge"* |
| **L2** | `gllvmTMBcontrol(aghq_ridge = 2)` | Confirmatory. The "cheap remedy" this study exists to score against VA (K3, §6) |
| **VGH** | `gllvmTMBcontrol(integration = "va", va_eval_method = "gh")` (`va_H = 7`, the Gate-E-promoted default, `R/gllvmTMB.R`: *"H = 7 was indistinguishable from H = 61… while running 3.4-6.7 times faster"*) | Confirmatory. The public VA route |
| **VJJ** | `gllvmTMBcontrol(integration = "va", va_eval_method = "jj")` | **Nested sub-study only**, binomial-logit continuity block (§5.3) |

Every arm justified by inclusion or exclusion from the confirmatory set:
L0/L2 are the two live Laplace-path behaviours a real user can reach today
without opting into VA at all; VGH is the only VA evaluator admitted outside
pure-binomial-logit (`R/integration-fence.R`'s family/link table admits
`binomial-probit` and `ordinal_probit` but the JJ-specific admissibility text
in `R/gllvmTMB.R` restricts JJ to logit); comparators beyond these four would
either be untested combinations (e.g. `aghq` on the Laplace path — Design
121's arm-C possibility, folded in only conditionally, §9) or duplicate an
existing arm.

### 5.2 Confirmatory grid

| Factor | Levels |
|---|---|
| Family | `binomial_probit`, `ordinal_probit` |
| Arm | L0, L2, VGH |
| n | 100, 400, 1600 |
| p | 12, 27 (confirmatory); 80 (**exploratory only**, `n = 100` corner only, F4) |
| q | 2 (fixed) |
| Truth (signal strength) | T-weak, T-mid, T-strong (§3) |
| Seeds/cell | derived, §4 formula — see §7 pre-run |

Confirmatory cell count: 2 families × 3 arms × 3 n × 2 p × 3 truths = **108
cells**, each replicated by the seed count derived in §7. `p = 80` adds 2
families × 3 arms × 1 n × 3 truths = 18 exploratory cells, reported
separately (F4).

`p = 27` matches Ayumi's trait count exactly
(`docs/design/108-va-parity-programme.md` §0: *"N = 5397 species, 27
responses"*); `n = 1600` matches the #847 large-n rung Stage 8 already probed
(`dev/design108-stage8/README.md`: *"n = 1600 (moved from 1500 so the design
measures the same large-n boundary examined in #847)"*), reused here rather
than re-chosen so this design's n-ladder shares an anchor with Stage 8's.

### 5.3 Binomial-logit continuity block (VJJ nested sub-study)

| Factor | Levels |
|---|---|
| Family | `binomial_logit` only |
| Arm | L0, L2, VGH, **VJJ** |
| n | 100, 400 (`n = 1600` optional, gated on pre-run cost) |
| p | 12, 27 |
| q | 2 |
| Truth | T-mid, T-strong (2 of 3 — the block's role is a continuity check, not a full replication of §5.2) |

This block links directly to two existing bodies of evidence: Gate 3's
already-certified region (*"va_jj passes the FULL conjunction in 100% of q ≤
2 cells, under BOTH rules"*, `docs/dev-log/2026-07-31-gate3-result-corrected.md`)
and Design 108 §0.2's `d108-logit-847.csv` 720-fit logit arm. Its purpose is
to confirm this design's own harness reproduces the qualitative Gate-3
JJ-beats-GH-on-RMSE finding before that same harness is trusted to make novel
claims about probit, where no comparable prior VA evidence exists at all.

## 6. Performance measures and kill criteria (Williams item 5)

### 6.1 Performance measures

- **Stratified `Sigma_B` RMSE** (diag / off-diag≥0.1 / near-zero), with MCSE
  (`.rmse_and_mcse()`, `dev/va-gate3/analyse-gate3.R:48`: `mcse =
  sqrt(var(x^2)/n) / (2*rmse)`), per (truth, family, n, p, arm) — never
  pooled across truth (F4).
- **`kappa`**, reported beside every RMSE table, not folded into a single
  number (§4).
- **Silent-divergence rate**, using the **canonical two-sided `degenerate`
  flag** (`rel_frob > 10 OR kappa < 1/3`, §4) as the "divergent" leg
  throughout — never the Stage-8 one-sided `rel_frob > 10` form alone as the
  primary rule. "Silently": L0/L2 use `degenerate & convergence == 0 &
  pdHess == TRUE` (Stage-8's exact form, valid because `pdHess` exists on the
  Laplace path); VGH uses the pre-registered substitute `degenerate & status
  == "ok"` (§4, F2) because no `pdHess`/`sdreport` exists on the VA route.
  Rate MCSE via `.rate_mcse()` (`sqrt(p_hat*(1-p_hat)/n)`,
  `dev/va-gate3/analyse-gate3.R:33-39`) for every arm's rate. The Stage-8
  one-sided form (`rel_frob > 10` alone, dropping the `kappa` leg) is
  additionally reported as a **separately labelled secondary column**, for
  comparability with Stage 8's own published numbers only — it never drives
  K3 or K4.
- **Wall time**, per arm, per cell, mean and range — informative only; Design
  108 §0.1 already closed the speed question against VA, so this is reported
  for completeness, never used in a kill rule.

### 6.2 Kill criteria

- **K1 — optimiser-artifact voids the study.** Restated identically to § F1
  as a per-fit rule with a declared tolerance: **TEST A fails for any arm**
  (`|c_hat - 1| > 0.01`, VGH's variational parameters re-optimised at each
  perturbed `c`, § F1), **OR more than 10% of pre-run fits in any single
  arm have `max_abs_gradient > 1e-3`** (the declared `grad_tol`, § F1 — the
  package has no single generic gradient tolerance across Laplace and VA
  fits to borrow instead). Evaluated per fit, never from a pooled median.
  **Action: halt, fix the harness, do not proceed to the full campaign.**
  This is checked entirely inside the pre-run (§7) and must clear before any
  confirmatory launch is even proposed.
- **K2 — convergence failure downgrades the cell's verdict.** If any
  confirmatory cell's raw-denominator convergence rate (any arm) is below
  70%, that cell is reported as a **convergence result only** — no accuracy
  (RMSE/kappa) comparison is drawn from it, because a comparison built on the
  surviving 70%-or-fewer fits is a comparison on a selected, non-random
  subsample and its RMSE numbers would not mean what an RMSE table normally
  means.
- **K3 — the pre-registered "cheap remedy wins" outcome.**

  **MCSE used throughout K3 is the PAIRED-DIFFERENCE MCSE derived in §7**,
  `MCSE_paired(stratum) = SD(Delta)/sqrt(n_seeds)` where `Delta =
  rel_frob_VGH - rel_frob_L2` for the seeds realised in that (truth × n ×
  family × p) stratum — never the marginal per-arm RMSE MCSE from
  `.rmse_and_mcse()` (§6.1), which answers a different question (how
  precisely is one arm's own RMSE known) than the paired comparison K3
  actually turns on.

  **Primary stratification: the `|off-diag| >= 0.1` entries of `Sigma_B`
  are the primary, scientifically-loaded target**; the `diag` stratum is
  secondary, reported alongside but not load-bearing for the verdict below —
  off-diagonal recovery is what a VA-vs-Laplace ordination claim is actually
  about, and the diagonal alone can look recovered while cross-trait
  structure is not.

  **"VA wins" claim** requires the primary (`|off-diag| >= 0.1`) stratum's
  VGH-over-L2 RMSE advantage to clear `2 x MCSE_paired` in **at least 2
  independent (truth x n) strata** — one chance stratum crossing the
  threshold is not sufficient, per the same anti-pooling logic F4 applies
  against a single lucky cell standing in for the design.

  **"Cheap remedy wins" (the pre-registered null) applies if, in every
  confirmatory (truth x family x n x p) stratum**, the primary
  (`|off-diag| >= 0.1`) VGH-over-L2 RMSE advantage is smaller than
  `2 x MCSE_paired` — i.e. the "VA wins" bar above is never cleared anywhere
  in the primary stratum. **Condition 2 (relative silent-divergence rates)
  is reported descriptively alongside this verdict but is NOT a kill
  conjunct**: § F2 establishes that VGH's `status == "ok"` proxy and the
  Laplace arms' `convergence == 0 & pdHess == TRUE` criterion are different
  instruments, so a rate comparison between them cannot be required to
  co-occur with the RMSE finding without importing an instrument mismatch
  into the kill rule (the earlier draft's condition 2, unmodified, would have
  auto-satisfied toward "no VA payoff" on every VGH fit, because no
  `pdHess` exists on the VA route for `silent_divergent_VGH` to require —
  the guaranteed-null failure mode this fix closes).

  **Mixed outcomes are reported as mixed, with no winner claim.** If neither
  the "VA wins" bar (>=2 independent primary strata clearing the margin) nor
  the "cheap remedy wins" condition (margin never cleared anywhere) holds —
  e.g. exactly one primary stratum clears the margin — the study reports
  this explicitly as an inconclusive/mixed result on the primary stratum and
  does **not** round it to either verdict.

  Whichever verdict obtains, it prices the *"~7 days saved"* outcome the
  2026-08-02 handover named as the reason to run this study before Stages 3
  and 5, and is stated as such — a pre-registered null is not an
  afterthought if the data disappoint.
- **K4 — the §0.2 transfer check, per stratum, no pooling.** Evaluated
  **separately for each (truth, n, p) stratum** on `binomial_probit`, never
  pooled across truth or p (F4's rule applies here too — a pooled rate could
  hide a subgroup exactly as Gate 3's pooled median did). For a given
  stratum at `n >= 400`: if the **upper `2 x MCSE` bound of L0's
  raw-denominator silent-divergence rate** (canonical two-sided definition,
  §6.1; `rate + 2 x sqrt(rate*(1-rate)/n_seeds)`) **lies below 2%**, that
  stratum's result is read as "does not transfer" — a rate whose entire
  plausible range (not just its point estimate) sits under the 2% bar is the
  standard this design requires before overturning §0.2's framing, because a
  point estimate alone could sit under 2% by chance in a small stratum. If
  **any** `n >= 400` stratum fails to clear that upper-bound test, Design 108
  §0.2's silent-divergence argument (the *"one honest argument that does
  survive"* for building the VA programme at all, §0.2: *"a silent 40%
  failure rate is worse than a slow fit"*) is read as **transferring, at
  least partially, to probit at this design's sizes**, and the framing is
  retained for that stratum. This is a check on THIS study's own grid — the
  Stage-8 finding it qualitatively replicates used a different DGP (§0), so
  K4 is not automatically satisfied by citing Stage 8's own number.

## 7. Pre-run (D-139), authorised now

Per D-139 (*"State a time guesstimate before starting any simulation… >30 min
→ present a simulation plan and a PRE-RUN TEST, with its results shown"*),
this design authorises exactly one pre-run, not the confirmatory campaign.

**Spec.** ~10 seeds × 4 sentinel cells × 3 confirmatory arms (L0, L2, VGH),
plus TEST A on every resulting fit:

1. Cheapest confirmatory cell: `binomial_probit`, `n = 100`, `p = 12`,
   T-weak.
2. Most expensive confirmatory cell: `binomial_probit`, `n = 1600`, `p = 27`,
   T-strong (the same corner Design 108's own Totoro probe already measured
   for Laplace at ~37s/fit, `dev/design108-stage8/README.md` "The Totoro
   n=1600 probe" — this pre-run adds VGH's cost at the identical corner,
   which Stage 8 never measured since it ran Laplace only).
3. One `ordinal_probit` cell: `n = 400`, `p = 12`, T-mid (ordinal's per-fit
   cost is the flagged unknown in Stage 8's own honest wall-clock section:
   *"ordinal_probit's cost at n = 1600 and at p = 27… is pure extrapolation
   from one small-n/small-p data point"* — this pre-run gets a second,
   independent ordinal anchor under the VA arm specifically).
4. One strong-signal small-n cell: `binomial_probit`, `n = 100`, `p = 27`,
   T-strong (checks whether VA's contraction behaviour, if any, is visible
   already at the smallest confirmatory n).

**Deliverables.**

- Per-stratum paired-difference SD of `(rel_frob_VGH - rel_frob_L2)` and
  `(rel_frob_VGH - rel_frob_L0)`, the input to the seed-count formula below.
- Derived seeds/cell for the full confirmatory campaign.
- Wall-time per corner, per arm — the input to a revised full-campaign time
  estimate (currently marked ASSUMPTION, §10).
- Per-arm convergence/pdHess summary on the 10×4×3 = 120 pre-run fits.
- TEST A verdict per arm (K1).

**Seed-count formula.** `seeds/cell = (2 * SD(Delta) / target_MCSE)^2`, where
`Delta` is the per-seed paired difference `rel_frob_VGH - rel_frob_L2` (the
comparison K3 actually turns on) measured stratum-by-stratum in the pre-run,
and `target_MCSE = 0.05` relative-Frobenius units (suggested; matches the
scale of Gate 3's own tolerance, *"maximum rmse_gap anywhere is 0.0393
against a 0.05 tolerance"*). Wherever the pre-run's own divergence rate for a
sentinel cell falls in the 1–5% range — where a rate needs many replicates to
resolve at all — the seed count is raised to **at least 100** regardless of
what the RMSE-driven formula alone would give, because a rate near that band
is exactly where `.rate_mcse() = sqrt(p(1-p)/n)` is least informative at low
`n`: at `p = 0.03`, `n = 30` gives an MCSE of 0.031, wider than the rate
itself.

**Smoke-first + 25-minute stop rule.** The pre-run itself runs smoke-scale
first (matching `dev/design108-stage8/laplace-silent-divergence.R`'s own
`GRID_SMOKE` idiom: a tiny subset, checked for non-empty/non-NA/in-range
output, before the real run). If the full 120-fit pre-run has not completed
within **25 minutes** of wall-clock on whatever machine it is launched on, it
stops and re-reports rather than continuing silently, per D-139's overrun
rule (*"A run that overruns its estimate stops and re-reports; it does not
quietly continue"*). Time estimate for the pre-run itself: **≤30 minutes**
(120 fits, dominated by the four `n=1600` VGH fits — VA cost at that corner
is unmeasured, so this is the one cell most likely to trigger the stop rule;
if it does, the pre-run is re-scoped to run that corner alone first before
committing to the rest).

## 8. Reporting stage (Williams items 9–11)

- A worked case study: the strongest-signal, largest-n confirmatory cell
  (`binomial_probit`, `n = 1600`, `p = 27`, T-strong) reported as a single
  fully-detailed comparison across all three confirmatory arms in the main
  reporting document, not only inside the aggregate table.
- Full performance table: one row per (truth, family, n, p, arm) confirmatory
  cell, each cell carrying its metric **and** its MCSE in parentheses,
  stratified per §6.1 — never a single pooled number standing in for the
  table.
- Convergence/silent-divergence rate is a column in that same table, never a
  separately-dropped appendix, per Williams item 10b and per Gate 3's own
  corrected-record lesson about hidden denominators
  (`docs/dev-log/2026-07-31-gate3-result-corrected.md`).
- Every reported number states which of the three F2 denominators (raw /
  guard-inclusive / all-arm intersection) it was computed against, printed
  alongside the number itself — following the same discipline
  `dev/va-gate3/analyse-gate3.R` already applies (`n_attempted`, `n_ok`,
  `n_sigma_usable` all printed together, never one substituted silently for
  another).

## 9. Deferrals, pre-registered

- **The augmented-vs-tips ELBO probe (Design 106 §3.6).** Scheduled, not
  dropped. It requires the phylo tier, which sits outside the VA admission
  fence today (`R/integration-fence.R` admits no phylo/spatial route; Design
  108 Stage 7 (PR #911, per §0's cited handover) makes the *Laplace* phylo
  tier real via the profile route, not VA's). This module activates once a
  VA phylo tier exists to test against, and its estimand is unchanged from
  Design 106 §3.6: whether the augmented route's factorised ELBO sits further
  below the true marginal likelihood than the tips-only route predicts.
- **The AGHQ axis (Design 121's possible arm C).** Folded into this design
  as a possible **L2-adjacent** arm — `gllvmTMBcontrol(aghq = k, aghq_ridge =
  2)` on the Laplace path — **only if** the ridge/`k` decision that Design
  121 and `dev/aghq-scope-accuracy-crux.md` leave open lands first. That
  crux note's own headline (*"AGHQ removes ~52% of Laplace's attenuation
  deficit… the other half is mostly finite-n bias"*, its §0) is Bernoulli-
  logit-only evidence (its §7 item 4: *"Everything here… is Bernoulli-logit,
  complete cells, no phylogeny… None of this validates [Ayumi's] fitted
  model"*), so admitting it here without that decision first would import an
  unresolved family-transfer question into this study's own confirmatory
  grid.

## 10. Fence-admissibility table

Every cell in §5.2/§5.3 is checked against `R/integration-fence.R`'s admitted
region before it can run under the VA arms (L0/L2 need no such check — the
fence is VA-specific, `.gllvmTMB_check_integration_fence()` returns
immediately for `integration = "laplace"`, `R/integration-fence.R:79`):

| Boundary | Fence value | This design's grid | Admissible? |
|---|---|---|---|
| `q_max` | 2 | `q = 2` throughout | Yes, at the boundary |
| `p_max` | 80 | 12, 27 confirmatory; 80 exploratory-only | Yes; `p = 80` exploratory sits exactly at the boundary, hence F4's fencing |
| `n_min` | 100 | 100, 400, 1600 | Yes, at the boundary at the smallest n |
| `unique` | must be `FALSE` | ordinary `latent(unique = FALSE)` throughout (§3: no Psi companion) | Yes |
| family/link | `binomial-probit`, `ordinal_probit`, `binomial-logit` all listed | matches exactly | Yes |
| `engine` | `"tmb"` only | native TMB engine | Yes |
| `va_eval_method = "jj"` admissibility | pure binomial-logit only | VJJ restricted to the §5.3 logit-only block | Yes, by construction |
| latent term at the unit grouping | any latent term "away from the unit grouping" is an error (`R/gllvmTMB.R:1511-1512`: *"Any model structure the route cannot represent (a latent term away from the unit grouping, a constrained ordination, an offset, weights, REML, lambda_constraint, Xcoef_fixed, or a further random effect) is an error"*) | single ordinary `latent(0 + trait | site, d = q)` term at the unit (site) grouping throughout (§3); no offsets, weights, REML, or further random effects in any confirmatory or exploratory cell | Yes |

No cell in this design's confirmatory or exploratory grid requests anything
the fence would reject; the `p = 80, n = 100` corner is the only one that
sits on two boundaries simultaneously, which is the stated reason it is
exploratory rather than confirmatory (F4).

## 11. Relationship to Design 66

Design 66 (`docs/design/66-capstone-power-study.md`) is the paper's evidence
chapter and **has no VA arm today** — its cell definitions, per its own
status line, are *"APPROVED scientific design contract; execution route
superseded under D-50"* and cover the shipped Laplace engine only. This
design is an **extension**, not a substitute: only fence-admissible cells
(§10) could ever carry a VA arm inside Design 66's own grid, and any such
addition would itself need Design 66's own D-50 compute-admission slice
(*"No 48-cell pilot, claim-bearing fit campaign… is admitted until a
separate compute-admission slice freezes and validates source/archive/
runner checksums… followed by explicit maintainer approval"*) — this design
does not shortcut that gate.

## 12. Compute estimate — ASSUMPTION, pending the pre-run

**Marked ASSUMPTION**, to be replaced by the pre-run's own measured numbers
(§7) before any full-campaign launch is proposed. Using Design 108 Stage 8's
own measured Laplace anchors (`~1.2s` at `n=60,p=12`; `~36.4s` at
`n=1600,p=27`, binomial-probit, `dev/design108-stage8/README.md` "Honest
wall-clock estimate") as a **Laplace-only** floor, and treating VA's cost as
unmeasured at every one of these cells (the crux note's only VA-adjacent
timing evidence, `dev/aghq-scope-accuracy-crux.md` §4, is for a *different*
estimator, AGHQ, not VA-GH, and states its own ratio is *"a ratio and an
order of magnitude, not a timing"*): **this design cannot currently produce a
defensible full-campaign wall-clock estimate**, which is precisely why the
pre-run (§7) is a required gate rather than an optional nicety. The 108-cell
confirmatory grid (§5.2: 2 families x 3 arms x 3 n x 2 p x 3 truths = 108
cells, the arm factor already counted in that product) at 100 seeds/cell
would be **10,800 total fits**, before the VJJ continuity block (§5.3) adds
more; whether that is minutes or hours on Totoro at typical worker counts
depends entirely on VGH's per-fit cost at `n = 1600, p = 27`, which is
exactly pre-run sentinel cell 2 (§7).

## 13. UNVERIFIED flags

- **The `p = 80` exploratory smallest-category expected-count check (F3)**
  was computed from the population marginal at `eta = 0` and not re-derived
  per drawn trait intercept; the pre-run should re-verify it empirically
  against actual simulated category counts before the confirmatory ordinal
  cells are trusted, not merely the analytic approximation in F3.
- **VGH's per-fit cost at `n = 1600, p = 27`** (binomial-probit and
  ordinal-probit) is UNVERIFIED — no VA fit at that corner has been measured
  anywhere in this repository as of this document; §7 sentinel cell 2 exists
  specifically to close this gap.
- **Whether the §0.2 rate genuinely transfers to this design's own DGP
  convention** (frozen Gate-3-style `Lambda_0` truths vs. Stage 8's
  `loading_sd()`-drawn regime) is UNVERIFIED prior to K4 being evaluated on
  this design's own confirmatory grid; the two DGPs are related but not
  identical, and this document does not assume the transfer holds.
- **The ordinal category-probability calculation in F3** assumed
  `eta = 0` (population marginal); actual per-seed, per-trait intercepts draw
  from `N(0, 0.3)` (§3), so individual traits' category counts will vary
  around this figure — flagged, not resolved, pending the pre-run's empirical
  check.
- **VJJ's `n = 1600` level** in the continuity block (§5.3) is marked
  optional and gated on pre-run cost; whether it runs at all is UNVERIFIED
  until the pre-run's wall-time numbers are in hand.

## 14. Pre-run outcome (2026-08-16) — the §12 assumption is FALSIFIED

The D-139 pre-run ran smoke-first and **stopped on its own rule**: the single
smoke fit (VGH, `n = 1600, p = 27`, T-strong — sentinel 2, the corner §13
flagged as UNVERIFIED) exceeded **17.3 minutes wall without finishing**
(killed while healthy at 93% CPU; not hung). Root cause identified: the VA-GH
route's default `n_starts = 4` (`R/va-r3-proto.R:2447`, anchor: `n_starts`)
runs four sequential full optimisations over ~8,080 free variational +
model parameters at this corner, a cost Laplace never faces (it profiles the
randoms internally; its Stage-8 reference at this corner is ~37 s/fit).

Consequences, pre-registered here rather than discovered mid-campaign:

- §12's compute assumption is **falsified**: the confirmatory grid as
  costed cannot run at the n = 1600 tier without either (a) a
  pre-registered `n_starts` reduction for the VGH arm (which changes the
  arm's estimand — cold-start-single vs best-of-4 — and must be stated as
  such, per F1's own logic), or (b) an accepted multi-day VGH budget, or
  (c) dropping the n = 1600 tier from confirmatory scope.
- TEST A machinery is validated on toy fits (L0 `c_hat = 1.0005` PASS; L2
  `c_hat = 1.018` borderline at ridge+small-n; VGH `c_hat = 1.0003` PASS,
  `TESTA_VGH_partial = TRUE` — fixed-variational fallback as §7 allows).
- Zero of the 120 sentinel fits were spent; SD(Δ) and derived seeds/cell
  remain unmeasured. The next pre-run attempt should measure the cheap
  sentinels FIRST and treat the n = 1600 VGH corner as its own
  budget-gated probe.
- The projection formula in the runner under-counted already-spent smoke
  time; corrected in `dev/va-vs-laplace-prerun/RESULTS.md`.

**This section is a finding, not a failure**: the pre-run's job was to
price the campaign before seeds were burned, and it did — the decision on
(a)/(b)/(c) belongs to Design 66 scoping.

## 15. Completed pre-run (2026-08-16, later) — §14's options resolved by measurement

The reduced-sentinel pre-run ran to completion (120/120 fits, stop rule not
fired; `dev/va-vs-laplace-prerun/RESULTS.md`). VGH cost curve: 45.0 s
(n=100) · 125.7 s (n=400) · >17.3 min unfinished (n=1600). **Recommended
disposition = (c-modified): confirmatory n ∈ {100, 400}; n = 1600
exploratory-budgeted; no `n_starts` arm.** TEST A passes 120/120 across all
arms after an instrument correction the pre-run itself caught: the Laplace
`aghq_ridge` penalty is applied at the R level (`R/fit-multi.R:5586-5592`,
anchor: the ridge penalty block) and is NOT part of `tmb_obj$fn()` — a
TEST A that evaluates the raw TMB objective scores L2 against the wrong
function (18/40 false alarms, all cleared on the corrected objective,
`c_hat ∈ [1.0000, 1.0014]`). Seeds/cell from measured SD(Δ) (primary
stratum, VGH−L2): ~205–306 at binomial sentinels; ordinal trivially small;
VGH−L0 contrasts degenerate-inflated and adjudicated on intersection
denominators only, as §6 already mandates. One open flag for the campaign:
4/40 optimiser non-determinism flips (parallel vs sequential) at the
weakest-signal cell. Final scoping lives in
`docs/dev-log/2026-08-16-design66-scoping-proposal.md`.

> **2026-08-17 addendum (issue #1092).** The instrument correction above was
> applied to TEST A only; the same raw gradient remained the source of the K1
> gradient column and of `fit_health$max_gradient`, which is why K1's gradient
> leg later read 100% of L2 fits as over-tolerance (see the independent
> adjudication, `dev/design122-campaign/ADJUDICATION.md`). The root cause is
> now fixed package-wide: `.gllvmTMB_penalised_gradient()` is the single
> accessor for the gradient of the objective the optimiser actually minimised,
> and `fit_health$max_gradient`, `sanity_multi()`, and the AGHQ engine's
> stop-reason reporting all read it. Future campaigns that reuse
> `fit_health$max_gradient` (per `dev/campaign-admission/RESULT-SCHEMA.md`)
> record the penalised gradient automatically. The stored Design 122 rows are
> NOT retro-correctable — the CSVs keep only the scalar — so the K1 question
> for THIS campaign is a decision, not a recomputation:
> `docs/dev-log/2026-08-17-design122-k1-reread-infeasible.md`.

## 16. Confirmatory campaign STAGED — measured cost, awaiting the D-139 go (2026-08-17)

The campaign is built, **admitted through the Design 124 compute-admission
slice** (`campaign_id = design122-confirmatory-20260817-646005cf`, pinned
commit `646005cf`, fresh pinned library — the older `ae17a501` lib was
correctly REFUSED because `R/` and `src/` had drifted), and has cleared all
three smoke-ladder rungs. It has **not** been launched.

**Rung results.** Rung 1 (1 fit) PASS. Rung 2 (canary, 24 cells × 3 arms =
72 rows) PASS — 72/72 rows, 97.2% converged, zero NA among outcome columns,
TEST A 71/72 (the one FAIL is a genuinely degenerate L0 fit at `rel_frob`
7401, correctly caught, not a harness artefact). Rung 3 (one full chunk: the
worst-cost cell `ordinal_probit, n=400, p=27, T-weak`, 300 seeds × 3 arms =
900 fits) PASS — 900/900 rows, TEST A 900/900, zero degenerate, zero
silent-divergent, 56.5 min wall.

**Measured full-run cost (21,600 fits): ~382 core-hours**, of which **VGH is
83%**; the VGH `n = 400` corner alone is 80.9% of all VGH core-seconds
despite being half the VGH fits. Per-arm wall from rung 3: L0 ~90 s, L2 ~94 s,
**VGH ~769 s** per fit. At 96 workers the pure-compute floor is **~4.0 h**.

**A fixable +2.8 h overhead.** Launching as 24 chunk jobs re-pays a ~7 min
VA-R3 DLL compile burst per daemon pool (measured: rung 3's 56.5 min minus
`sum(wall)/96` ≈ 49.6 min). `R/va-r3-proto.R:1070-1075` documents the remedy
and this run did not use it: `GLLVMTMB_VA_R3_BUILD_ROOT` lets workers share
one precompiled template (its own comment notes *"a 100-worker Totoro launch
would compile the same source 100 times"* without it). **Set it before the
full launch** — that collapses the realistic ~6.5–7 h back toward ~4 h.

**Scope limitation found at rung 2 and confirmed at rung 3:**
`extract_cutpoints()` errors on **every** VGH `ordinal_probit` row
(*"Provide a fit returned by gllvmTMB()"*), so `tau2_hat`/`tau3_hat` are NA
for 300/300 VGH rows. The error is captured in-row, not silently dropped.
**The VGH ordinal cutpoint estimand is currently unmeasurable through this
harness** — ordinal is one of the two confirmatory families, so this either
needs fixing before the full run or the ordinal-VGH cutpoint target must be
pre-registered as out of scope.

**Status: awaiting the final D-139 go.** The measured 382 core-hours exceeds
the "tens of CPU-hours" stated at scoping, so the number is restated here
rather than absorbed silently.

## 17. PRE-REGISTERED AMENDMENT, before any confirmatory data exists (2026-08-17)

Maintainer decision, recorded **prior to the launch** of the confirmatory
campaign and therefore binding on its analysis:

**The VGH ordinal cutpoint target is OUT OF SCOPE for this campaign.**
`extract_cutpoints()` rejects VA-route fits (*"Provide a fit returned by
`gllvmTMB()`"*), so `tau_k` cannot be recovered for the VGH arm on
`ordinal_probit` rows. Rather than fix the accessor under time pressure, or —
worse — discover the gap during analysis and decide then, the target is
withdrawn now.

What this does and does not cost:

- **Unaffected:** the primary estimand, stratified `Sigma_B` relative
  Frobenius error, together with `kappa`, the two-sided degeneracy detector,
  `max|Lambda|`, silent-divergence rates, and TEST A. All measured normally on
  ordinal rows in all three arms; rung 3 produced 900/900 complete rows for
  exactly this cell. **The campaign still answers the question it was built to
  answer.**
- **Withdrawn:** any claim about VGH's recovery of ordinal cutpoints. Rows
  will carry `tau2_hat`/`tau3_hat` as `NA` with the captured error string, so
  the absence is visible in the data rather than inferred from silence.
- **Not withdrawn for Laplace:** L0 and L2 ordinal cutpoints are measured
  normally; only the VGH arm's are missing. Any cross-arm cutpoint comparison
  is therefore impossible and must not be attempted post hoc.

Tracked as a follow-up: `extract_cutpoints()` should accept VA fits, or refuse
them with a message naming the actual limitation. Until then, this amendment
stands.
