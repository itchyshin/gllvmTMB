# Detector-S2c ordinal calibration: curvature and multi-start arms

STATUS: **FROZEN 2026-08-17, before any scored fit runs.** The arms, grid,
targets, and scoring rule below are locked as of this timestamp. The D-139
timing pilot (`campaign-curvature-pilot.R`) has already run and is
quarantined (see the D-139 cost estimate section) — its statistic VALUES
were inspected only for finiteness/sanity, never for what threshold they'd
imply, so freezing now does not launder any peeking. No scored fit for this
campaign has been run as of this freeze. Mirrors `pass-criteria-ordinal.md`
and `probe-criteria.md`'s own frozen-then-VERDICT pattern: the VERDICT, when
it comes, is scored by a separate reviewer against exactly this frozen text
and does not revise it.

## Review history

**2026-08-17 — adversarial review (Opus, fresh context) returned BLOCK** on
the first draft, with four blocking findings (B1–B4) and six should-fix
findings (B5–B10). The coordinator independently verified B2's most
falsifiable claim (`objective$he(par)` exists at `R/va-r3-proto.R:1982`) and
found the draft's "grep returns zero matches" statement false. This section
records what changed. The reviewer's core objection — **as originally
pinned, the campaign's only reachable outcome was a null result
indistinguishable from an uninformative statistic**, because the FP target
was unattainable by construction — is the organizing concern behind every
fix below, not just B1's own line item.

| finding | verdict | what changed |
|---|---|---|
| B1 (FP denominator vs widened healthy sweep) | fixed, and extended | FP-scored `scale_healthy` restricted to `sigma_lambda \in {0.3, 0.7}`; `{1.2, 2.0}` moved to a reported-only `scale_boundary` stratum. Additionally (not asked, but the same defect): `transport`'s own known ~partial contamination (prior campaign's 57/180 combined figure) is now reported **decomposed by sub-arm**, not just as one pooled FP number, so a nonzero FP result is interpretable rather than conflated with detector failure. |
| B2 (wrong Hessian route; false "zero matches" claim) | diagnosis accepted, literal fix NOT adopted (see Pushback) | The false claim is removed. Primary route no longer inverts the full `cov.fixed`. |
| B3 (wrong block — conditional, not marginal) | fixed | Resolved together with B2 (see Pushback): the primary statistic is now the Schur complement of the loading block, recovered as `solve(cov.fixed[idx, idx])` — no full-matrix inversion, and it is the *marginal* (profiled-over-everything-else) curvature B3 requires. |
| B4 (D's pair is one statistic; C-abs carries lambda^-2 units) | fixed for C; partially conceded for D | C-abs is now scale-corrected by the fit's own `max_loading_unit`, with a pre-registered circularity precondition (folded into B8's fix). D: adopted the reviewer's own offered alternative — stated as effectively single-statistic, with a secondary exploratory companion, not a guard-satisfying pair (see Pushback). |
| B5 (D's rationale self-cancelling; absolute jitter negligible at large sigma) | mechanism honestly reframed; jitter fixed | Arm D's motivating story is corrected in the text (see below) rather than withdrawn. `init_jitter` is now scaled to each cell's own DGP loading scale instead of a flat 0.3. |
| B6 (power regression, unstated) | partially fixed, bound stated explicitly | FP-scored pool raised from 270 to 290 and the bound (~1.03%) stated explicitly, but NOT raised to >=500 — justified explicitly as a first-pass pilot with a pre-registered >=500 follow-up requirement before arming (see Grid and Targets). |
| B7 (post-hoc threshold discretion) | fixed | Mechanical rule pinned: threshold = the FP-scored pool's own observed extreme (zero-FP boundary), full sweep reported for transparency only. |
| B8 (no independence precondition) | fixed | Correlation of both Arm C statistics against `max_loading_unit`, computed across all fits, with a numeric refusal bar. |
| B9 (silent zero-length subset; over-conservative fallback) | fixed | Explicit `length(idx) == 0` guard to `NA`, not `Inf`/`-Inf`. Positional-name fallback added instead of an unconditional "blocked" verdict. |
| B10 (two fit populations pooled) | fixed | Arm C's sensitivity/FP are now reported both pooled and decomposed by `n_init` stratum (1 vs. 5-selected). |

**2026-08-17 — SCORED: both arms FAIL, ship-disarmed fallback applies.**
Full 450-cell grid run (0 errors), scored independently against the frozen
text. Arm C sensitivity 1.1-5.3% (reading-dependent), Arm D 7.3%, combined
7.3% — all against a >=90% target, a fail margin of 83-89 points that no
reading of three found scoring ambiguities (recorded as a post-hoc
amendment below, not a frozen-text edit) comes close to closing. See
"SCORED VERDICT" and "POST-HOC AMENDMENT" below.

**2026-08-17 — D-139 timing pilot run** (`campaign-curvature-pilot.R`,
`OPENBLAS_NUM_THREADS=1`, quarantined output under `pilot-curvature-*`).
Both preconditions PASS (the `rownames(cov.fixed)` assumption is verified,
not just plausible; Arm C/D statistics are finite on real fits). Measured
full-grid projection: **~84 min serial, ~4–8 min at 10–20-core parallelism**
— well under the D-139 line, and far better than the pre-pilot 28.8-minute
guess (see the D-139 cost estimate section for the likely reason:
`OPENBLAS_NUM_THREADS` pinning). One pilot cell returned `cond_LL = Inf`
and a negative `min_eig_scaled`; traced to a genuine `pdHess = FALSE` fit,
not a harness bug — see the cost section's precondition item 3.

## Scope

Issue #897 still has no working ordinal degeneracy detector. Four
loading/cutpoint-based candidate statistics were pre-registered and
eliminated on the same 315-fit calibration
(`pass-criteria-ordinal.md`, "SEARCH STOPPED" section):

| candidate | outcome |
|---|---|
| `max_loading_unit` (absolute) | fails — does not transport across heterogeneous trait scales (healthy pool reaches 216.9, degenerate arm starts at 13.5) |
| `relative_loading` (family-scoped) | fails — 28.6% FP at its best sensitivity |
| `loading / cutpoint_span` | REFUSED on circularity (span correlates +0.546, p = 4.6e-20, with the degeneracy label) and fails empirically anyway |
| `spike_ratio` (max / second-max) | independent of `max_loading_unit` (cor +0.242) and centrally discriminating, but fails — 2.4% sensitivity at zero FP |

`pass-criteria-ordinal.md`'s own closing paragraph names the two paths left:
"a different information source (e.g. the observed-information/curvature
structure, or a refit-based check such as the dichotomisation counterfactual
the S1 probe used) or a fresh dataset." The dichotomisation counterfactual
was tried as **measurement 3** of the S1 probe and shown (in probe-criteria.md's
own correction notice) to fire on 86.3% of healthy fits — it discriminates
nothing and is not revisited. What remains untested is the **curvature**
route named there, plus **multi-start disagreement**, a second, independent
information source not previously considered. This document pre-registers
exactly those two — no third candidate, and testing further loading/cutpoint
statistics on this or an overlapping fit pool would be multiple testing
without correction (the same discipline `pass-criteria-ordinal.md` invoked to
stop at four).

**Calibrates** two new components, `ordinal_curvature_conditioning`
(Arm C) and `ordinal_multistart_disagreement` (Arm D), that do **not yet
exist in `R/diagnose.R`** — this document specifies what a future
`.gllvmTMB_ordinal_curvature_row()` / `.gllvmTMB_ordinal_multistart_row()`
would need to compute and threshold; it is a calibration pre-registration,
not an implementation plan. Neither is a modification of the existing
`.gllvmTMB_ordinal_degeneracy_row()` (O1/O2), which stays disarmed at `Inf`
regardless of this campaign's outcome.

## Why these two arms and no others

- **Arm C (curvature)** is the literal path `pass-criteria-ordinal.md` names:
  a degenerate loading estimate is still a local optimum of the fitted
  objective (S1 probe's measurement 1 found 23/24 degenerate fits get
  *worse* under a uniform loading-scale perturbation — these are not points
  the optimiser merely failed to leave), so point estimates cannot
  distinguish it from a healthy one, but the *local curvature* around that
  optimum can differ. This is a different information source from all four
  eliminated candidates, which used only the point estimate (`Lambda_B`)
  and the fitted cutpoints, never the second-derivative structure of the
  objective. Per the 🔴 critical constraint below, raw Hessian
  positive-definiteness is excluded a priori as the statistic.
- **Arm D (multi-start disagreement)** is independent again: it does not use
  the Hessian at all, only whether independently-perturbed optimisation runs
  converge to compatibly-scored solutions. Its motivating mechanism is
  weaker than originally framed — see "Arm D's mechanism, honestly stated"
  below, added in response to B5 — but it remains a genuinely different
  information source (multimodality of the objective surface, not its local
  shape at one point) worth testing empirically, precisely because a
  calibration campaign's job is to test candidates whose sign is not
  certain in advance.
- No third arm. A saturation/flat-fit arm remains excluded on the S1 probe's
  own zero-support finding (flat-row share exactly 0/24); an
  extreme-category-prevalence conjunct remains excluded on the same "no
  empirical basis" reasoning `pass-criteria-ordinal.md` gives.

## 🔴 Critical constraint: why raw pdHess is not the Arm C statistic

Issue #851 (cited in this repo's Live Phase Snapshot, 2026-07-30 entry)
documents a fit with `convergence = 0` **and** a positive-definite Hessian
throughout, at `sd(y) ~ 9268`, where every reported quantity (Sigma, fixed
effects, `logLik`, correlations, communality) was nonetheless wrong. A
boolean `pdHess` check is therefore known, in this repository, to pass on
fits this campaign needs Arm C to catch. Arm C's statistics (below) are both
continuous functionals of the eigenspectrum, not the sign test `pdHess`
already computed by `check_gllvmTMB()`'s `hessian_rank` / `pd_hessian` rows
(`R/diagnose.R:83`, `:199-219`) — a block can be exactly positive-definite
and still have its smallest eigenvalue orders of magnitude below its
largest, or below the scale a healthy fit's block reaches at the same `n`.

## Arm C — curvature / observed-information conditioning

### What is reachable from a fitted object (verified by reading, not by
### running R — this design task ran no fits)

- `object$sd_report$cov.fixed` is the fixed-effect covariance matrix from
  `TMB::sdreport()`, populated whenever a fit is built with `se = TRUE`
  (the `gllvmTMB()` default). It is stored at fit time
  (`R/fit-multi.R:7391` `fit$sd_report <- sd_rep`) and is already read as a
  plain matrix elsewhere — `.gllvmTMB_hessian_rank()` (`R/diagnose.R:199-219`)
  does `cov_fixed <- as.matrix(object$sd_report$cov.fixed)`, and
  `.ci_hessian_one()` (`R/check-identifiability.R:455-462`) inverts the
  **whole** matrix and takes its eigenvalues — an already-used pattern for
  the whole-Hessian case.
- **Correction (B2):** an earlier draft of this document claimed
  "`obj$he()`... is not used [in this codebase]... grep... returns zero
  matches." That was false, and the coordinator caught it: `objective$he(par)`
  is called at `R/va-r3-proto.R:1982`, inside the VA-route standard-error
  fallback (`.va_r3_fixed_information_blocked()`'s sibling), to get the
  dense fixed-effect Hessian directly by AD. This establishes both that
  `$he()` is a real, exercised API surface in this package and that
  `object` there is a `TMB::MakeADFun` object with the same `$he(par)`
  contract described in TMB's documentation — evidence used below.
- The loading block within `cov.fixed` is addressable by parameter name:
  `R/fit-multi.R` subsets fixed-effect parameter vectors by
  `which(names(opt$par) == "theta_rr_B")` (line 269), and the same pattern
  at lines 6016, 6280, 6465 — establishing `"theta_rr_B"` as the repeated
  block name TMB attaches to every entry of the reduced-rank ordinary-tier
  loading vector. By TMB's standard construction,
  `dimnames(sd_report$cov.fixed)` equals `list(names(par.fixed),
  names(par.fixed))` where `names(par.fixed)` is the same repeated-block-name
  vector as `names(obj$par)`.
  **UNVERIFIED — mandatory pre-flight check:** this campaign's
  implementation MUST confirm, on the first fitted object it produces,
  `identical(rownames(fit$sd_report$cov.fixed), names(fit$tmb_obj$par))`
  before trusting name-based subsetting. **Per B9, this is no longer a hard
  block if it fails**: fall back to positional indexing via
  `which(names(fit$tmb_obj$par) == "theta_rr_B")` (the same TMB parameter
  ordering `cov.fixed` was built from), and only mark `curvature_available
  = FALSE` for a fit if *neither* naming route yields `length(idx) > 0`.
  (Note: an unrelated naming scheme, `positional_ids <-
  paste0(block_labels, suffixes)`, exists at `R/fit-multi.R:8007` for a
  separate curvature-record diagnostic; it is NOT assumed to apply to
  `sd_report$cov.fixed`'s own dimnames.)
- The DGP here never uses `theta_rr_W`, `theta_rr_spde_lv`, `theta_rr_phy`,
  or `theta_rr_B_slope` (no `dep()`/`spatial()`/`phylo()`/slope terms in
  `sim_ordinal()`, `sim_ordinal_transport()`, or `sim_ordinal_mixed()`), so
  `"theta_rr_B"` is the only loading block present and no other block can be
  mistaken for it.

### Resolving B2 and B3 together: the Schur complement, not either literal fix

B2's own suggested fix ("use `obj$he()` as primary") and B3's finding
("`H_full[idx,idx]` is the wrong, conditional block; use the Schur
complement / marginal block instead") are **in tension with each other if
taken literally**: `obj$he(par)` gives exactly the *conditional* block B3
says is wrong (curvature in the loading directions with cutpoints and every
other fixed effect held at their fitted values) — adopting B2's literal fix
would reintroduce B3's defect. This is addressed in "Pushback" below.

The two findings are resolved together by a standard block-matrix identity
that neither finding's own suggested fix uses. For the full fixed-effect
Hessian `H` partitioned into loading indices `L` and everything else `O`:

```
H = [[H_LL, H_LO],
     [H_OL, H_OO]]
```

`cov.fixed = solve(H)` (this is B2's own correct premise), and by the
standard block-inverse identity, the `L`-block of `solve(H)` is the
**inverse of the Schur complement of `O` in `H`**:

```
cov.fixed[L, L] = (H_LL - H_LO %*% solve(H_OO) %*% H_OL)^{-1}
                = (Schur complement of the loading block)^{-1}
```

So the Schur complement — i.e. the curvature of the objective **profiled
over every other fixed effect**, which is exactly the marginal/profiled
quantity B3 requires and correctly captures a joint loading–cutpoint flat
direction (per `probe-criteria.md`'s own finding that the runaway trait's
`eta` and cutpoints grow in step) — is obtained by:

1. `cov_LL <- as.matrix(object$sd_report$cov.fixed)[idx, idx, drop = FALSE]`
   — a **submatrix extraction from the already-computed `cov.fixed`, no
   inversion of anything yet**.
2. `Schur_LL <- tryCatch(solve(cov_LL), error = function(e) NULL)` — a
   single inversion of a **small `q_L x q_L` matrix** (the number of
   `theta_rr_B` entries), not the full `p x p` fixed-effect Hessian. This
   directly answers B2's numerical concern: the campaign never explicitly
   forms or inverts the full ill-conditioned `H`; it inverts only the small
   block that is already isolated inside `cov.fixed`. Guard: if `solve()`
   errors (singular `cov_LL`) or `cov_LL` is non-finite,
   `curvature_available = FALSE` for that fit — never coerced to `Inf` (see
   the B9 guard below).

This is **not** a claim that inverting `cov_LL` is numerically risk-free —
a genuinely flat direction makes `cov_LL` itself have a large eigenvalue
(TMB's own delta-method computation, not a re-derived quantity), and
inverting that gives the correspondingly small `Schur_LL` eigenvalue **by
design**, which is the signal Arm C is built to detect, not numerical noise
from a redundant round-trip through the full matrix.

3. `ev <- eigen(Schur_LL, symmetric = TRUE, only.values = TRUE)$values`.

### `obj$he()`'s corrected role: a pilot-only cross-check, not the primary route

`fit$tmb_obj$he(fit$sd_report$par.fixed)[idx, idx]` gives `H_LL`, the
**conditional** block (B3's wrong target for the scored statistic) — but it
is exactly the comparator needed to empirically confirm B3's mechanism is
real in this DGP, not just theoretically plausible. During the **timing
pilot only** (never the scored grid, per the pilot-quarantine clause), the
campaign computes both `H_LL` (via `$he()`, per B2's evidence that this API
is exercised elsewhere in the package) and `Schur_LL` (the scored
statistic) on a handful of degenerate pilot fits and reports whether their
smallest eigenvalues disagree materially — corroborating evidence for the
joint-flat-direction mechanism, reported but never scored against the
frozen targets.

### Exact functional (frozen)

1. `cov_fixed <- as.matrix(object$sd_report$cov.fixed)`; if `NULL` or any
   entry non-finite, `curvature_available = FALSE`.
2. `idx <- which(rownames(cov_fixed) == "theta_rr_B")`; if `rownames()` is
   `NULL`, fall back to `which(names(object$tmb_obj$par) == "theta_rr_B")`.
   **Guard (B9): if `length(idx) == 0` under both routes, `curvature_available
   = FALSE`** — never let `max()`/`min()` on an empty numeric vector produce
   a silent `-Inf`/`Inf` that would be scored as a real value.
3. `cov_LL <- cov_fixed[idx, idx, drop = FALSE]`.
4. `Schur_LL <- tryCatch(solve(cov_LL), error = function(e) NULL)`; `NULL`
   or non-finite -> `curvature_available = FALSE`.
5. `ev <- eigen(Schur_LL, symmetric = TRUE, only.values = TRUE)$values`.
6. **C-ratio** (scale-invariant): `cond_LL <- max(ev) / min(ev)` if
   `min(ev) > 0`, else `Inf`.
7. **C-abs, scale-corrected (B4 fix):** the raw `min(ev) / n_obs` carries
   units of (loading scale)^-2 — Fisher information about a loading
   parameter shrinks roughly as the inverse square of the loading's own
   magnitude even in a perfectly healthy fit, so an unnormalised absolute
   threshold would fail exactly the way `max_loading_unit`/O2 failed: a
   healthy fit at `sigma_lambda = 8` could cross a threshold calibrated on
   `sigma_lambda = 0.7` healthy fits for no pathological reason. Corrected
   statistic: `min_eig_scaled <- (min(ev) / n_obs) * max(max_loading_unit,
   1)^2`, using the SAME `max_loading_unit` already computed by
   `.gllvmTMB_max_loading_by_trait()` for O1/O2 (no new machinery) as the
   fit's own scale reference. This removes the benign scale trend so a
   genuinely pathological *extra* curvature collapse (beyond what the
   fit's own loading scale would predict) is what remains.
8. Candidate flag (thresholds **not** frozen here — the campaign's output):
   `flag_C <- (cond_LL >= curvature_cond_thresh) | (min_eig_scaled <=
   curvature_abs_thresh)`.

### Independence precondition (B8)

Before either C statistic can be proposed as an arm, the campaign must
report, across **all** fits with a finite value (not just the healthy
pool): `cor(cond_LL, max_loading_unit)` and `cor(min_eig_scaled,
max_loading_unit)`. **Refusal bar: `|r| >= 0.8` for either statistic**
refuses that statistic as non-independent of the already-eliminated
`max_loading_unit` candidate (a new, explicit numeric bar for this specific
comparator — no prior document in this programme tested correlation
against `max_loading_unit` itself, only `spike_ratio`'s cor = +0.242 against
it, reported as evidence of independence without a formal cutoff). This
mirrors, but is not identical to, the `cutpoint_span` precondition in
`pass-criteria-ordinal.md` (which tested correlation against the
*degeneracy label*, a different question: whether a statistic is downstream
of the same mechanism, not whether it duplicates an eliminated candidate).
Both checks are reported for this campaign; only the `max_loading_unit`
check gates Arm C, since duplicating an already-eliminated candidate (not
tracking the degeneracy label, which is expected and desired) is the
specific risk B8 raises.

## Arm D — multi-start disagreement

### Arm D's mechanism, honestly stated (B5)

The original framing was: "a different start might find a better,
non-degenerate mode, so disagreement across starts signals that the
returned fit is untrustworthy." **This has a logical problem the reviewer
correctly identified.** `gllvmTMB()`'s `n_init` machinery always **keeps
the lowest-objective restart** (`R/fit-multi.R:5853-5856`). So if a jittered
restart finds a materially better (and, plausibly, non-degenerate) mode,
that mode becomes the *returned* fit — the degenerate alternative is
discarded, not reported. High objective spread among the `K` restarts is
therefore more consistent with "the final, returned fit escaped a bad
mode" than with "the final, returned fit is itself bad." The sign of the
relationship between spread and the *returned* fit's own degeneracy status
is not obvious a priori, and could plausibly go either way depending on
whether degenerate optima form a broad, easily-reached basin (many restarts
land there, low spread, and the *returned* fit — the best of a bad bunch —
is still degenerate) or a narrow one next to a much better basin (spread is
high, but the returned fit already escaped it).

**This is not withdrawn, but reframed:** Arm D is retained as an
**empirical test of an uncertain-sign hypothesis**, which is a legitimate
thing for a calibration campaign to test — the sensitivity/FP targets below
apply to whichever direction the data show, decided by the frozen scoring
rule, not chosen after seeing which sign "worked." If Arm D's statistics
show no usable relationship to the returned fit's degeneracy status in
either direction, that is reported as a finding, exactly like the four
already-eliminated candidates.

`init_jitter` is also corrected (B5, mechanical half): a flat `sd = 0.3`
jitter is a negligible relative perturbation once a cell's own loading
scale is `sigma_lambda = 8` — restarts would barely leave the basin they
started near, undermining Arm D's power exactly on the cells that matter
most. Fixed: `init_jitter_cell <- 0.5 * max(nominal_scale_for_cell, 1)`,
where `nominal_scale_for_cell` is the DGP's own known scale parameter for
that cell (`sigma_lambda` for `scale_healthy`/`scale_degenerate`; the
`sim_ordinal_transport()` design's own `scale_hi = 9` for `transport`; the
fixed `sigma_lambda = 0.7` for `mixed`) — all quantities fixed by the DGP
design before any fit is run, so this stays closed-form and mechanical, not
a post-hoc tuning.

### Existing start machinery reused (not new)

`gllvmTMBcontrol(n_init = K, init_jitter = s)` (`R/gllvmTMB.R:1686,1689`)
runs `K` restarts per fit: restart 1 from the default start (`obj$par`),
restarts 2..K from `.gllvmTMB_reclamp_start_par(obj$par + stats::rnorm(
length(obj$par), sd = init_jitter))` (`R/fit-multi.R:5804-5811`), keeping
the restart with the lowest objective. Every restart's outcome (`objective`,
`convergence`, `success`) is recorded in `fit$restart_history`
(`R/fit-multi.R:8939-8952`, `.gllvmTMB_restart_history_row()`; stored at
`R/fit-multi.R:7056`). This campaign uses `n_init`/`init_jitter` exactly as
shipped and reads `fit$restart_history` exactly as populated — no new
perturbation mechanism, and no new plumbing to expose per-restart loading
matrices (the package does not currently persist any but the winning
restart's `Lambda_B`; building that exposure is out of scope here).
`K = 5` (inside the documented "5 to 10" range, `R/gllvmTMB.R:1630`).

### Exact functional (frozen) — single primary statistic, per B4

From `fit$restart_history` (columns `objective`, `success`):

1. `obj_i <- restart_history$objective[restart_history$success &
   is.finite(restart_history$objective)]`.
2. If `length(obj_i) < 2`: `disagreement_available = FALSE`.
3. **D-abs (the scored statistic):** `obj_spread_per_obs <- (max(obj_i) -
   min(obj_i)) / n_obs`.
4. **D-count (secondary, exploratory only — not a guard-satisfying pair,
   per B4):** `n_modes_frac <- mean((obj_i - min(obj_i)) / n_obs >
   0.01)` — the fraction of successful restarts landing outside a fixed
   0.01-nats-per-observation tolerance of the best restart found. This is
   reported alongside `obj_spread_per_obs` because it is cheap (same
   `restart_history` input, no new fits) and captures a distinct-in-kind
   aspect (how many restarts disagree, vs. how far) — but it is derived
   from the same underlying `obj_i` vector as D-abs, not an independent
   information source, and is not claimed to satisfy the ratio+absolute
   guard the way Arm C's `cond_LL`/`min_eig_scaled` pair does. **Per B4's
   own offered alternative, Arm D is scored as a single statistic
   (`obj_spread_per_obs`); `n_modes_frac` is reported for interpretability
   only.**
5. Candidate flag (threshold **not** frozen here): `flag_D <-
   obj_spread_per_obs >= multistart_abs_thresh`.

### Cost, stated plainly

Each Arm D cell costs approximately `K = 5` times a single-start fit (`K`
sequential optimisations sharing one `MakeADFun` build). This is already
folded into the fit-equivalent accounting in the Grid below, not an
additional multiplier on top of it.

## Non-negotiable design constraints — how these arms respect them (revised)

- **Ratio paired with absolute, Arm C.** `cond_LL` (ratio, scale-invariant)
  + `min_eig_scaled` (absolute, now scale-corrected per B4 rather than
  raw). Arm D is **not** claimed to satisfy this pairing — see the D-count
  caveat above; this is a deliberate, disclosed departure from the guard's
  literal form for Arm D specifically, not a silent gap.
- **`sigma_lambda` as a first-class grid axis, not two fixed values —
  revised after B1/B6.** The original design swept `sigma_lambda` across
  `{0.3, 0.7, 1.2, 2.0}` on the "healthy" side, but the S1 probe already
  measured ~10-13% of `sigma_lambda = 0.7` fits as genuinely `rel_frob >
  10` — so pooling `{1.2, 2.0}` into the zero-FP-scored denominator made
  the target unattainable **by construction** for any detector with
  meaningful sensitivity, exactly the reviewer's core objection. Fixed:
  the FP-scored `scale_healthy` arm is restricted to `sigma_lambda \in
  {0.3, 0.7}`; `{1.2, 2.0}` is retained as a **reported, not FP-scored**
  `scale_boundary` stratum (see Grid). This still tests the scale axis far
  beyond the old 0.7/3.0 pair (the frozen `scale_degenerate` sub-arm still
  reaches `sigma_lambda = 8.0`), but the FP target is no longer
  structurally impossible to meet.
- **Arm-level FP, never per-fit relabelling — and its own known
  limitation stated up front.** The FP denominator is `scale_healthy`
  (restricted range) + `transport` + `mixed`, by arm membership,
  unconditional on any individual fit's own `rel_frob`. **New, added
  beyond B1's literal ask:** `transport`'s DGP (`sim_ordinal_transport()`,
  per-trait scale 0.5–9x) is *already known*, from the prior campaign's
  own combined "57 of 180 healthy+transport" figure, to contain a
  meaningful share of genuinely `rel_frob > 10` fits by construction — so
  "zero FP" may still be missed at the `transport` sub-arm specifically
  for a reason that has nothing to do with Arm C/D's quality. The scoring
  rule (below) requires the FP count to be reported **decomposed by
  sub-arm**, so a nonzero result is interpretable (concentrated in
  `transport`'s known-contaminated pool vs. spread into the clean
  `scale_healthy` pool) rather than a single opaque number.
- **Grid wide enough that "no signal" is a real finding, and its cost
  stated (B6).** FP-scored pool: 290 fits (140 `scale_healthy` + 80
  `transport` + 70 `mixed`), bounding the true FPR at ~1.03% by rule of
  three (`3/290`) — below the prior campaign's own >=500-fit review
  amendment (~0.6%), stated explicitly rather than silently dropped. This
  is deliberately **not** raised to >=500: this is a first-pass campaign
  to determine whether Arm C or Arm D shows *any* separating signal before
  committing to a fully-powered confirmatory run, mirroring this
  programme's own two-stage precedent (60-fit S1 probe -> 630-fit O1/O2
  calibration). **Pre-registered follow-up requirement:** if either arm
  clears its sensitivity/FP conjunction here, it may NOT be armed as a
  shipped default without a subsequent >=500-fit FP-scored confirmatory
  campaign — this document alone is insufficient evidence to arm anything.

## DGP reuse (do not fork)

All sub-arms below call `probe$sim_ordinal()`, `sim_ordinal_transport()`,
or `sim_ordinal_mixed()` from `campaign-ordinal-calibration.R` (which
itself loads `sim_ordinal`, `relfrob`, `TAUS`, `Q_FACTORS`, `P_TRAITS`,
`DEGEN_RF` from `probe-mechanism.R` via `.load_probe_defs()`), and
`gllvmTMB:::.gllvmTMB_max_loading_by_trait()` for the `max_loading_unit`
reference statistic O1/O2 already compute (no new machinery). No DGP is
hand-copied; `sigma_lambda` is passed as an argument to the existing
`sim_ordinal()` exactly as the O1/O2 campaign already does.

## Grid (frozen at sign-off)

| sub-arm | construction | sigma_lambda | n | seeds (Arm C, `n_init=1`) | Arm C fits | role |
|---|---|---|---|---|---|---|
| `scale_healthy` | `probe$sim_ordinal()` | `{0.3, 0.7}` | `{100,400}` | `1:35` | 140 | FP-scored |
| `scale_boundary` | `probe$sim_ordinal()` | `{1.2, 2.0}` | `{100,400}` | `1:10` | 40 | reported only, NOT FP-scored |
| `scale_degenerate` | `probe$sim_ordinal()` | `{3.0, 5.0, 8.0}` | `{100,400}` | `1:20` | 120 | sensitivity (rel_frob>10 subset) |
| `transport` | `sim_ordinal_transport()` (unmodified) | per-trait log-uniform 0.5–9 | `{100,400}` | `1:40` | 80 | FP-scored, known partial contamination (decomposed) |
| `mixed` | `sim_ordinal_mixed()` (unmodified) | fixed 0.7 | `{100,400}` | `1:35` | 70 | FP-scored, `rel_frob` unavailable (harness), always pooled |

- Arm C baseline grid: 140 + 40 + 120 + 80 + 70 = **450 fits** (`n_init = 1`).
- Arm D subset (a subset of the SAME cells, run at `n_init = 5` INSTEAD of
  `n_init = 1` — not fit twice): `scale_healthy` seeds `1:12` (48 base
  calls), `scale_degenerate` seeds `1:8` (48 base calls), `transport` seeds
  `1:12` (24 base calls), `mixed` seeds `1:10` (20 base calls).
  `scale_boundary` is **not** evaluated by Arm D (descriptive-only stratum;
  skipped to bound cost). Arm D base replicates: 48+48+24+20 = **140**.
- Total distinct `gllvmTMB()` calls: **450** (310 single-start + 140
  multi-start-bundled).
- Total fit-equivalent compute (`n_init=1` call = 1 unit, `n_init=5` call =
  5 units): `310*1 + 140*5 = 1010` fit-equivalents.

`scale_degenerate` seeds are expected to produce mostly-but-not-all
`rel_frob > 10` fits (per the S1 probe's `sigma_lambda = 3.0` cells: 60–80%
degenerate rate, presumably higher at 5.0/8.0) and `scale_healthy` /
`transport` / `mixed` are expected to produce mostly `rel_frob <= 10` fits
— but arm membership, not the realised rate, is what the FP scoring
conditions on (per the arm-level rule).

## Targets

- **Sensitivity >= 90%**, each arm scored separately (Arm C and Arm D are
  NOT combined into one detector for this campaign): among
  `scale_degenerate` fits with `rel_frob > 10`, the fraction where
  `flag_C` (resp. `flag_D`) fires.
- **Zero false positives**, each arm separately, on the FP-scored pool
  (`scale_healthy` + `transport` + `mixed`, 290 fits for Arm C's baseline;
  the Arm-D-evaluated subset of those cells, 92 base replicates at
  `n_init = 5`, for Arm D's), pooled by arm membership.
- **This campaign's result alone cannot arm a default.** Even a clean pass
  here only qualifies an arm for a >=500-fit confirmatory campaign (per
  B6's fix above); it does not itself meet this project's evidentiary bar
  for shipping a default threshold.
- If Arm C and Arm D are BOTH informative but neither alone clears the
  conjunction, a combined `flag_C | flag_D` rule may be reported as an
  EXPLORATORY finding (clearly labelled, not scored against the frozen
  targets above) — mirroring how `pass-criteria-ordinal.md` retained its
  own per-fit exploratory section below the frozen scored verdict, never
  substituting for it.

## Scoring rule (immovable)

1. Sensitivity denominator: `scale_degenerate` arm fits with
   `rel_frob(Lambda_B_hat %*% t(Lambda_B_hat), Sig_true) > 10` — the same
   `probe$DEGEN_RF` frozen label used throughout this programme.
   `scale_degenerate` fits with `rel_frob <= 10` are excluded from BOTH
   the sensitivity and the FP count.
2. FP denominator: **every** fit in `scale_healthy` (restricted to
   `sigma_lambda \in {0.3, 0.7}`), `transport`, and `mixed`, regardless of
   that individual fit's own `rel_frob`. Arm membership decided before any
   fit is run (the Grid table) is the only admissible criterion.
   `scale_boundary` (`sigma_lambda \in {1.2, 2.0}`) is reported (its own
   realised `rel_frob > 10` rate and its own `flag_C`/`flag_D` firing rate)
   but never counted toward either the sensitivity or the FP target.
3. **Threshold selection is mechanical, not chosen after inspecting the
   sweep (B7 fix):** for each candidate statistic, `thresh` is set to the
   most extreme value observed anywhere in that statistic's FP-scored pool
   (i.e. the empirical zero-FP boundary for that pool as measured) —
   mirroring `pass-criteria-ordinal.md`'s own "first zero-FP point" table
   convention. Sensitivity is reported AT that mechanically-derived
   operating point. A full threshold sweep table is also reported, for
   transparency and for the reader to see the whole curve, but it never
   substitutes for or overrides the mechanical operating point above.
4. **FP is reported decomposed by sub-arm** (`scale_healthy` /
   `transport` / `mixed` separately, in addition to the pooled arm-level
   number) so a nonzero result can be attributed to `transport`'s known
   partial contamination versus a genuine false alarm on clean
   `scale_healthy`/`mixed` fits.
5. **Arm C's sensitivity and FP are reported both pooled and decomposed by
   `n_init` stratum (B10 fix):** the 140 cells evaluated at `n_init = 5`
   (Arm D's subset) contribute their *selected* (best-of-5) fit's Arm C
   statistics; the remaining 310 cells are single-start. These two strata
   are reported separately as well as pooled, because `n_init = 5` is
   expected to reduce the realised degeneracy rate on `scale_degenerate`
   relative to single-start (some restarts escape to a better mode) — a
   confound worth surfacing on its own, not just a caveat.
6. No threshold may be chosen, and no candidate declared to pass or fail,
   by looking at individual fit rows and relabelling them post hoc. A D-43
   panel review is required before this document's VERDICT section is
   written.

## Pilot-quarantine clause

Any `--mode timing` or `--mode smoke` pilot fits run to develop or debug
this campaign's harness — including the `$he()` vs. `Schur_LL` cross-check
described above — are **discarded** and never folded into the scored grid,
and their statistic values are not inspected before the grid and thresholds
in this document are frozen. Output files must be written to separate,
clearly-named paths (mirroring `campaign-ordinal-calibration.R`'s existing
`campaign-timing-pilot.csv` / `campaign-smoke-2seed.csv` split) and never
read when computing the scored VERDICT.

## Ship-disarmed fallback (pre-registered)

If neither Arm C nor Arm D (nor the exploratory `flag_C | flag_D`
combination) meets the sensitivity/FP conjunction above at any threshold,
**both stay unimplemented / unshipped**, and that is the deliverable. This
is not a failure to be rescued by loosening the 90%/zero-FP targets after
the fact, and it is **also** the outcome if a target turns out to be
attainable only via `transport`'s known contamination happening to fall
below the mechanically-derived threshold rather than via genuine
separation — the decomposed FP reporting (Scoring rule, item 4) exists so
this distinction can be made honestly rather than silently.

## Pushback

Per the coordinator's instruction, these are places this revision did not
comply with a suggested fix literally, and why:

- **B2's literal suggested fix ("use `obj$he()` as the primary route")
  was not adopted.** `obj$he()` gives the *conditional* loading block
  (fixed at every other parameter's fitted value) — exactly the block B3
  identifies as wrong for the reason that matters here (a joint
  loading–cutpoint flat direction is invisible to it by eigenvalue
  interlacing). Adopting B2's literal fix would have satisfied B2 while
  reintroducing B3. The Schur-complement route (`solve(cov.fixed[idx,
  idx])`) resolves both simultaneously: it never inverts the full
  ill-conditioned `p x p` Hessian (B2's numerical concern) and it is the
  correctly *marginal* quantity (B3's statistical concern). `obj$he()` is
  kept, but demoted to a pilot-only cross-check, which is where B2's
  underlying evidence (that the API exists and works in this codebase) is
  actually used.
- **B4's request for "a genuinely independent second statistic" for Arm D
  was not fully met.** `n_modes_frac` is offered as a cheap secondary
  statistic derived from the same `restart_history` input already
  available, but it is honestly disclosed as non-independent of D-abs (both
  come from the same `obj_i` vector) rather than oversold as a true
  ratio+absolute pair. B4 itself offered this as an acceptable resolution
  ("or drop the pretense and state D as single-statistic with the
  consequence acknowledged"); building genuine independent evidence for
  Arm D would require exposing per-restart `Lambda_B`, which needs new
  package plumbing outside a calibration pre-registration's scope (and
  outside the original brief's "existing start machinery, not a new one"
  constraint).
- **B6's `>=500` FP pool was not met.** Raising the FP-scored pool from 290
  to >=500 would add roughly 70% more compute to an already
  budget-adjacent campaign (see Cost below), for two arms whose sign and
  usefulness are both still unknown. The explicit follow-up requirement
  (no arming without a subsequent >=500-fit confirmatory campaign) is
  offered as the alternative B6 itself allows ("either meet >=500 or
  justify not doing so").

## D-139 cost estimate — MEASURED (2026-08-17 timing pilot)

- **Fit-equivalent count: 1010** (310 single-start fits + 140 `n_init = 5`
  calls at 5 units each), per the Grid table above.
- **Total distinct `gllvmTMB()` calls: 450.**
- **Pilot run:** `dev/ordinal-degeneracy/campaign-curvature-pilot.R
  --stage timing`, `OPENBLAS_NUM_THREADS=1`, 9 cells chosen to span the two
  flagged cost drivers (`sigma_lambda` up to 8.0; `n_init = 5` with the B5
  scale-relative jitter), serial (1 core), on the same machine (20-core
  Mac) a full run would use. Output quarantined at
  `dev/ordinal-degeneracy/results/pilot-curvature-timing.csv` and
  `...-precondition.csv` — never read by the scored-grid script.
- **Measured per-cell seconds:**

  | cell | seconds |
  |---|---|
  | `scale_healthy`, n=100, sigma=0.7, `n_init=1` | 1.18 |
  | `scale_degenerate`, n=100, sigma=3.0, `n_init=1` | 0.78 |
  | `scale_degenerate`, n=100, sigma=8.0, `n_init=1` | 2.82 |
  | `scale_degenerate`, n=400, sigma=8.0, `n_init=1` | 3.36 |
  | `transport`, n=100, `n_init=1` | 1.16 |
  | `mixed`, n=100, `n_init=1` | 0.85 |
  | `scale_degenerate`, n=100, sigma=8.0, `n_init=5` | 11.53 |
  | `scale_degenerate`, n=400, sigma=8.0, `n_init=5` | 42.75 |
  | `transport`, n=400, `n_init=5` | 42.37 |

  Mean single-start cell: **1.69 s**. Mean `n_init=5` cell: **32.21 s**
  (6.44 s/restart) — this 3-cell sample is deliberately weighted 2:1 toward
  `n = 400` (the pricier `n`), so it is a conservative (not optimistic)
  basis for the `n_init=5` extrapolation below.
- **Projection (serial, 1 core):** `310 * 1.69s + 140 * 32.21s = 523.8s +
  4510.1s = 5033.9s ≈ 83.9 min ≈ 1.40 h`. The `n_init=5` cells dominate:
  ~90% of total projected time despite being ~31% of the fit-equivalent
  count, because a `n_init=5` call is not merely 5x a single fit — it also
  falls on `scale_degenerate`/`transport`, the two sub-arms whose own
  single-start cost is already the highest in the single-start table.
- **At real parallelism (linear, optimistic — this Mac has 20 physical
  cores, confirmed via `sysctl -n hw.ncpu`):** ~8.4 min at 10-core, ~4.2 min
  at 20-core. **Both are well under the D-139 30-minute line.**
- **This measured throughput is far better than the pre-pilot projection**
  (28.8 min at 10-core, borrowed from `pass-criteria-ordinal.md`'s own
  9.0-min/315-fit/10-core figure). The most likely explanation: that
  borrowed anchor implies ~17 s/fit serial-equivalent
  (`9.0 min * 60 / 315` core-seconds), roughly 10x this pilot's own
  measured 1.69 s/fit — consistent with the anchor run not having pinned
  `OPENBLAS_NUM_THREADS=1` (thread oversubscription across 10 parallel R
  processes, each spawning its own BLAS threads, is a well-known cause of
  exactly this kind of 10x slowdown), which is presumably why this task's
  hard constraint insisted on pinning it. This pilot's number is measured
  on the actual machine and actual grid this campaign would run on, and is
  the more trustworthy basis for a go/no-go decision.
- **Recommendation: run locally, not Totoro.** Reversing the pre-pilot
  guess: measured evidence puts the full grid at minutes, not tens of
  minutes, at any parallelism from 10 cores up, on ordinary Mac hardware —
  provided `OPENBLAS_NUM_THREADS=1` is pinned for every worker. The
  remaining uncertainty is the "linear parallel scaling" assumption itself
  (not yet measured at true concurrency); a cheap way to firm this up is to
  launch the first ~20 cells of the real run in parallel and check wall
  clock against the serial-derived estimate before committing the rest,
  rather than assuming linearity blind.
- **Precondition checks, run before any timing (both PASS):**
  1. `rownames(fit$sd_report$cov.fixed)` is **literally identical** to
     `names(fit$tmb_obj$par)` on a real fitted object (7 `theta_rr_B`
     entries at `p=4, q=2`, matching `rr_theta_len(4,2) = 7`) — the
     "UNVERIFIED" assumption in Arm C's functional is now verified on this
     package version. The `length(idx)==0` guard and positional-name
     fallback were exercised directly (rownames stripped -> fallback
     fires, `n_idx=7`; both routes stripped -> `curvature_available=FALSE`,
     not an error, not `Inf`/`-Inf`).
  2. Arm C and Arm D statistics are finite (not `NA`/`Inf`/`-Inf`) on a
     real single fit and a real 3-restart fit.
  3. **One `n_init=1` pilot cell (`scale_degenerate`, n=100, sigma=8.0,
     seed=1) legitimately returned `cond_LL = Inf` and a negative
     `min_eig_scaled` (-503).** Traced directly (not assumed): this fit has
     `pdHess = FALSE` and its full `cov.fixed` itself carries one negative
     eigenvalue (-20.45 of 19, `rel_frob = 312`, `convergence = 0`) — so a
     negative Schur-complement eigenvalue is mathematically forced (a
     principal submatrix and Schur complement of a non-PD matrix cannot
     both be PD), not a harness bug. `cond_LL`'s `Inf` branch and a
     negative `min_eig_scaled` both correctly satisfy `flag_C`'s "very
     suspicious" direction under the frozen functional, so this is the
     statistic behaving as designed on a genuinely severe case, not a
     defect to fix.

---

## SCORED VERDICT (2026-08-17; independent scoring)

**Both arms FAIL. Ship-disarmed fallback applies.** Full grid run: 450/450
`gllvmTMB()` calls `status == "OK"`, coverage exactly matching this
document's frozen Grid table (verified by an independent scorer who did not
design this campaign). Scoring performed by a separate agent against
exactly the frozen text above, without reading the quarantined pilot files
and without design-discussion context. Full scoring detail, every reading
of the ambiguities below, and the row-level audit:
`dev/ordinal-degeneracy/results/scoring-verdict.md`. Raw data:
`dev/ordinal-degeneracy/results/campaign-curvature-scored.csv`.

- **Arm C (curvature):** sensitivity **1.1%–5.3%** (reading-dependent, see
  the amendment below), against the frozen ≥90% target. FP 0–4 out of 290,
  always attributable to `transport`/`mixed`, never `scale_healthy`.
- **Arm D (multi-start):** sensitivity **7.3%**, against the same ≥90%
  target. FP 0–1 out of 92.
- **Exploratory `flag_C | flag_D`:** 7.3% — identical to Arm D alone; Arm C
  contributes nothing incremental on the `n_init=5` subset.
- **Independence precondition (B8) PASSES for both statistics**
  (`cor(cond_LL, max_loading_unit) = 0.538`,
  `cor(min_eig_scaled_per_obs, max_loading_unit) = -0.452`, refusal bar
  `|r| >= 0.8`) — the null result is not a circularity artefact; both
  statistics are measurably independent of the already-eliminated
  `max_loading_unit` candidate and still fail on their own merits.
- The failure margin (83–89 percentage points below target, every reading)
  is far wider than the scoring ambiguities recorded below could ever
  close — see "Why the ambiguity doesn't matter" in the scoring verdict.

**Per this document's own pre-registered fallback: both arms stay
UNIMPLEMENTED.** `O1`/`O2` (the existing, disarmed `ordinal_liability_loading`
row) are unaffected — this campaign never modified them and they remain at
`Inf`/`Inf`. No behaviour change results from this campaign.

## POST-HOC AMENDMENT (2026-08-17, after independent scoring) — NOT part of
## the frozen rule; the frozen text above is unedited and is what was scored

The independent scorer found three genuine ambiguities in the Scoring rule
above. None of them changed the verdict (the failure margin is 83-89
points; see the SCORED VERDICT section), but a future campaign reusing this
document as a template must not inherit them silently. Recorded here as an
amendment, not as a silent tightening of the frozen text — the frozen
Scoring rule stands exactly as written and is what was scored.

1. **Threshold-selection operator tension (Scoring rule item 3 vs. the Arm
   C/D flag formulas' own `>=`/`<=`).** Item 3 defines the mechanical
   threshold as "the most extreme value observed anywhere in that
   statistic's FP-scored pool" and calls this "the empirical zero-FP
   boundary." The flag formulas use inclusive comparison. Under an
   inclusive reading, the pool row that *achieves* the extreme value
   necessarily flags itself, so the pool's own defining threshold is never
   actually zero-FP — only a strict-comparison reading is tautologically
   zero-FP. **Recommended fix for a future pre-registration:** state
   explicitly, as part of the threshold-selection step itself (not only in
   the general flag-formula definition), which comparison operator applies
   when scoring the pool that DEFINED the threshold — e.g. "the
   mechanically-derived threshold is excluded from re-triggering its own
   defining row: score with strict `>`/`<` at that specific threshold."
2. **Whether `Inf`/non-finite values may define the mechanical threshold.**
   This document's Precondition-checks item 3 explicitly endorses `Inf` as
   a legitimate `cond_LL` value elsewhere, but the Scoring rule does not say
   whether an `Inf` value inside the FP pool is eligible to *set* "the most
   extreme value observed" (which would make the ratio arm permanently
   unable to fire) or should be excluded from threshold-selection while
   still being scored as an ordinary data point against whatever threshold
   the finite values set. **Recommended fix:** state explicitly that the
   mechanical threshold is computed from FINITE pool values only, and that
   non-finite pool/sensitivity values are scored (as flagged or not) against
   that finite threshold like any other row, never used to set it.
3. **`*_available == FALSE` rows (unavailable statistic) are not addressed
   by the Scoring rule.** The frozen text has no instruction for a row
   where `curvature_available` or `disagreement_available` is `FALSE`
   (guarded to `NA`, never `Inf`/`-Inf`, per the B9 fix) — comparison-to-`NA`
   semantics silently coerce to "not flagged," which is conservative for FP
   but ALSO conservative against sensitivity (an unavailable statistic on a
   genuinely degenerate fit is excluded from the numerator while remaining
   in the denominator). **Recommended fix:** state the treatment explicitly
   and symmetrically — e.g. "a `*_available == FALSE` row is excluded from
   that arm's sensitivity numerator and never contributes to the FP
   numerator, while remaining in both denominators" — rather than relying on
   R's default NA-comparison behaviour to make the choice implicitly.

**Why this is an amendment, not an edit to the frozen text:** the Scoring
rule section above is exactly the text the independent scorer applied,
unedited, to produce the SCORED VERDICT. Silently tightening it after
seeing the scorer's readings would destroy the audit trail that makes this
null result admissible — a future reader must be able to confirm the
scorer worked from the SAME text a sign-off would have frozen, not a
retroactively cleaner version.
