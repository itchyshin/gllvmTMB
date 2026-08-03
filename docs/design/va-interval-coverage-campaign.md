# VA interval coverage campaign — synthesised design

Status: DESIGN ONLY. No fits have been run under this document. Nothing here
is promoted; `default_tier` stays `"gh"`; the integration fence stays shut.
Every number below is measured-in-regime evidence at most, never a
certificate.

Base design: the **interval-method lens** design (`VA-interval-method-coverage-design`,
fewest total adversarial fatal flaws of the three reviewed candidates — 6 vs 8
(minimal) vs 10 (diagnostic)). Grafted in: Amendment (A)'s LA-as-shared-
parameterisation reference and the diagnostic lens's 4-way causal rubric and
numerical-health diagnostics; the minimal lens's per-trait-slope DGP (already
present in the base, kept because it independently avoids the minimal
design's own `(0+trait):x` ambiguity flaw); the diagnostic lens's oracle-floor
discipline and MCSE-arithmetic re-derivation.

## Question

For gllvmTMB's shipped Laplace (LA) engine and its internal, unshipped
variational (VA-R3) engine — crossed against gllvm's external VA-Wald
reference as a secondary algebraic cross-check — does the Schur-complement
Wald interval on gllvmTMB's own VA engine achieve nominal 95% coverage for
`Sigma := Lambda %*% t(Lambda)` and per-trait total variance
`V_j = Sigma_jj + psi_j`, in the one Gaussian, moderate-`psi`, in-regime
corner where the existing machinery can compute an interval at all — and,
using LA (which shares the parameterisation, extraction code, and estimand
with VA) as an internal reference, can the observed pattern be attributed to
(a) a partition/Schur-complement bug, (b) the ELBO-vs-likelihood curvature
gap, (c) the Wald/symmetric-interval construction, or (d) mean-field
estimator bias?

## Why it matters — we and gllvm compute the same Schur complement; neither has measured coverage

- `gllvmTMB`'s VA route deliberately refuses intervals:
  `confint.gllvmTMB_va`/`vcov.gllvmTMB_va` (`R/va-methods.R:184`, `:195`) error
  with `calibrated = FALSE: the inverse variational Hessian is not calibrated
  frequentist uncertainty`. This gate stays intact; this campaign calls the
  internal `.va_r3_fixed_information_blocked()` machinery directly (`:::`),
  never the public S3 methods.
- That internal machinery (`R/va-r3-proto.R:1624`–`1743`) computes
  `se_profile`, the Schur complement `H_ff - H_fv H_vv^-1 H_vf` — our own code
  comments call this "the correct observed information for the fixed
  parameters" and call the naive alternative (`se_conditional`) "expected
  ANTI-CONSERVATIVE" (test-enforced invariant `se_profile >= se_conditional`,
  `tests/testthat/test-va-r3-prototype.R:334-409`).
- gllvm 2.0.13's `se.gllvm` computes **algebraically the identical formula**:
  `I <- A.mat - B.mat %*% solve(D.mat, t(B.mat))`, i.e. `A - B D^-1 B'`, off
  TMB's exact Hessian. `confint.gllvm` builds a plain `qnorm`-based Wald
  interval off it.
- Neither package has ever measured whether this shared construction achieves
  nominal coverage. A NotebookLM-derived lead (Ranga's dr21, UNVERIFIED)
  reports ~39% coverage for a loading-derived covariance interval of this
  general class in a different, high-dimensional binary setting — a large
  enough number that even a coarse campaign should detect it if it recurs
  here, but it must not be assumed to transfer.
- The deeper issue, which the Schur complement cannot fix even if computed
  perfectly: the VA objective is an ELBO, a lower bound on the log marginal
  likelihood, not the likelihood itself. Its curvature is the curvature of a
  bound, and the gap between bound and likelihood need not be constant in the
  fixed parameters. Amendment (A)'s reason for adding our own Laplace engine
  as a third arm is exactly to separate this cause from an ordinary Schur/
  partition bug: LA and VA share the parameterisation, the extraction code,
  and the estimand, so an LA-covers/VA-fails contrast isolates the bound
  rather than reopening the cross-package rotation/pinning problem gllvm
  introduces.

## DGP

Gaussian, identity-link, multi-trait GLLVM. `T = 8` traits, latent dimension
`d = 2`. Chosen deliberately as the simplest family so family-specific
confounds (Laplace's documented ~34% weak-engine binary/count behaviour,
per dr21) are excluded from this campaign; see "What this cannot answer."
Gaussian is also the one family where Laplace is algebraically close to
exact, which is what makes LA a trustworthy same-parameterisation reference
rather than a second unknown.

```
y_ij = alpha_j + beta_j * x_i + z_i^T lambda_j + e_ij
e_ij ~ N(0, psi_j)              (the Gaussian family's OWN residual variance,
                                  not an extra diagonal tier -- see estimand
                                  note below)
z_i ~ N(0, I_d),  x_i ~ N(0, 1),  beta_j ~ N(0, 0.5^2)   (per-trait slope)
Lambda (T x d): diagonal ~ U(0.7, 1.3); lower-triangular off-diagonal
  ~ U(-0.5, 0.5); remaining (T-d) rows ~ N(0, 0.7^2) per entry
```

Per-trait slopes `beta_j` (not one shared slope) are used deliberately: this
sidesteps a fatal flaw raised against a sibling design that used one shared
`beta_x` and left the LA arm's formula unspecified, risking a silent switch
to the package's habitual `(0 + trait):x` per-trait-slope idiom producing a
different-dimensional estimand than the DGP. With per-trait `beta_j` planted,
`(0 + trait):x` is exactly the right, unambiguous LA-side term.

**n-grid:** `n = 50` (stress, out-of-regime, expected to fail broadly),
`n = 150` and `n = 400` (PRIMARY, in-regime pair — matches the existing
Gaussian `d in {1,2}`, `n >= 150` floor already established for the LA engine
in `docs/design/35-validation-debt-register.md` CI-08/CI-10/CI-11 and
encoded in `.total_variance_in_certified_regime()`,
`R/profile-derived.R:911-935`), `n = 5000` (oracle/asymptotic-floor, Wald
only, all three primary arms).

**psi regime (Failure Mode 1 guard):** PRIMARY, claim-bearing:
`psi_j ~ iid U(0.3, 0.5)` — psi contributes ~30-45% of `V_j`, explicitly not
the near-zero corner that hides variance-collapse-into-loadings. SECONDARY,
non-claim-bearing positive control only: `psi = 0` exactly, at `n = 150, 400`
— confirms the harness reaches near-nominal coverage in the one corner known
to hide the collapse failure; a pass here proves nothing about the real
regime and is never reported in the same table as the primary cells (see
"Degeneracy and failure handling," gllvm-arm exemption).

## Estimands and why they are identified

| Estimand | Definition | Identified because | Role |
|---|---|---|---|
| `beta_j` (8) | per-trait fixed slope | no rotation/sign ambiguity at all — the cleanest instrument for separating causes (a)/(b)/(d) from (c) | secondary, diagnostic |
| `Sigma_jj` (8) | `(Lambda Lambda^T)_jj` | rotation-invariant: for ANY `d x d` orthogonal `Q`, `(Lambda Q)(Lambda Q)^T = Lambda Lambda^T` — a square, so also sign-invariant | secondary |
| `Sigma_jk`, `j<k` (28) | `(Lambda Lambda^T)_jk` | same rotation-invariance argument, general `d`, not just `d=1` | secondary, flagged (see below) |
| `V_j = Sigma_jj + psi_j` (8) | per-trait total marginal variance | rotation-invariant (sum of a rotation-invariant term and the family's own residual variance); the only target with an EXISTING profile route, `.profile_ci_total_variance()` (`R/profile-derived.R:856-903`), certified in-regime at a 0.94 floor for exactly Gaussian/unit-tier/`d in {1,2}`/`n>=150` | **PRIMARY, pre-registered headline** |
| `trace(Sigma)` (1) | `sum_j Sigma_jj` | rotation-invariant | optional, cheap add-on |
| Raw `Lambda_jk` entries | — | **EXPLICITLY EXCLUDED.** `R/loading-ci.R`'s own docstring restricts per-entry loading CIs to *confirmatory* (rotation-pinned) fits — "a per-entry CI on an unconstrained exploratory fit is a property of the rotation convention, not the biology." Our VA/LA fits here are exploratory (unconstrained `Lambda`), so raw entries are not comparable across seeds, let alone across engines/packages. | never reported as a coverage number |

**Resolving the DGP-vs-fit "loadings-only" ambiguity (the base design's own
fatal flaw).** `.va_r3_fit()` (`R/va-r3-proto.R:2098-2118`) exposes `unique`/
`psi` (whether an EXTRA diagonal covariance tier sits on top of
`Lambda Lambda^T`) as arguments **separate from** `estimate_gaussian_sd`
(whether the Gaussian family's own residual variance is estimated; default
`TRUE`, always on for `family = "gaussian_anchor"`). Fitting `unique = FALSE,
psi = FALSE` therefore does **not** remove the residual/dispersion term the
DGP's `e_ij ~ N(0, psi_j)` requires — it removes only a redundant *additional*
diagonal layer the Gaussian likelihood never needed in the first place, since
a single-factor Gaussian model's residual variance already plays exactly
`psi_j`'s role. Concretely: **`psi_hat_j := ` the fitted Gaussian residual
variance (`exp(2 * log_sigma_j)` on the VA side; the family dispersion
parameter on the LA side), never the (deliberately absent) extra tier.** This
is stated once, in code terms, precisely so the ambiguity a reviewer found in
the base design's English gloss cannot recur. It is verified, not merely
assumed — see Step-0 gate 0a below — because `estimate_gaussian_sd`'s
existence as a separate argument is suggestive but the LA-side glmmTMB-style
dispersion convention is not yet confirmed to match it symbol-for-symbol in
this repo.

**The generic delta-method-on-a-product caveat (kept, not silently dropped).**
`Sigma_jk = lambda_j . lambda_k` (dot product across `d` axes) is a product of
correlated estimates; its delta-method Wald interval is the same construction
as a Sobel/indirect-effect test and is documented to under-cover generically,
independent of engine, especially when a loading component is not large
relative to its own SE. This confound is **shared identically by every arm**
(VA, LA, and — where computable — gllvm all build the same delta-method
construction), so it nets out of the paired VA-vs-LA contrast that answers
the campaign's causal question, but a *marginal*, single-arm `Sigma_jk`
coverage number must never be read alone as "VA/LA is miscalibrated" — it may
just be this generic artifact. Reported, flagged, never used as a standalone
claim.

## Arms and model-matching

1. **VA-Wald** — `.va_r3_fit(family = "gaussian_anchor", unique = FALSE,
   psi = FALSE, estimate_gaussian_sd = TRUE, q = 2, n_starts = 4)`
   (`R/va-r3-proto.R:2098`), SE from
   `.va_r3_fixed_information_blocked(objective, par, N, q)$se_profile`
   (`R/va-r3-proto.R:1624`), the Schur-complement route. Delta-method
   propagation to `Sigma_jj`/`Sigma_jk` via a **new** helper (see Step-0
   gate 0c) that generalises the existing numerical-Jacobian pattern in
   `R/loading-ci.R` (which already combines a numerical Jacobian with the full
   fixed-parameter covariance for `Lambda`) to the target function
   `vec(Lambda %*% t(Lambda))` instead of `vec(Lambda)`.
   **`V_j` is NOT included for this arm without a small, named code change**:
   `fixed_idx <- which(nm %in% c("beta", "theta_rr"))` at both
   `R/va-r3-proto.R:1632` and `:1777` excludes `log_sigma` (the Gaussian
   family's residual/psi parameter, `R/va-r3-proto.R:1122-1123`, `:1976-1993`)
   from the fixed block entirely, so `se_profile` today carries no
   uncertainty on `psi_hat_j` at all. A VA-Wald interval on `V_j = Sigma_jj +
   psi_j` is therefore not computable from the shipped machinery as-is — this
   was found by reading the source during design verification, not raised by
   any reviewer, and is folded into Step-0 gate 0c below as a required,
   narrowly-scoped extension (add `log_sigma` to `fixed_idx` in both
   routes, re-derive the Schur complement over the enlarged fixed block, and
   re-run the existing `se_profile >= se_conditional` invariant test before
   trusting it) rather than silently assumed to already work. Until that
   extension is verified, VA-Wald's estimand set for this campaign is
   `Sigma_jj`/`Sigma_jk` only, and the primary `V_j` headline compares
   LA-Wald and LA-Profile against VA-Wald's `Sigma_jj` coverage as the
   nearest available VA-side quantity, reported as a distinct row, never
   silently equated with `V_j`.
2. **LA-Wald** — shipped engine, formula
   `y ~ 0 + trait + (0 + trait):x + latent(1 | unit, d = 2, unique = FALSE)`,
   Gaussian family, fit via `gllvmTMB()`. SE from the existing
   `fit$sd_report$cov.fixed` full fixed-parameter covariance (already used by
   `R/loading-ci.R`), propagated through the same new Sigma-Jacobian helper as
   VA-Wald — same code path, same estimand, only the fit object differs. This
   is Amendment (A)'s point: sharing extraction code with VA-Wald, not just
   the model.
3. **LA-Profile** — `.profile_ci_total_variance()` (`R/profile-derived.R:856`)
   on `V_j` only, at the two PRIMARY in-regime cells (`n=150,400`, `psi>0`;
   this is exactly the certified regime's Gaussian/unit-tier/`d in {1,2}`/
   `n>=150` corner, at its already-established 0.94 floor — no new code). Plus
   a small oracle pilot at `n=5000` (~30 seeds, see oracle-floor fix below).
4. **LA-Bootstrap** — `bootstrap_Sigma(fit, n_boot = 500, level = "unit",
   what = "Sigma")` (`R/bootstrap-sigma.R:196`), `n=400` only, `psi>0`. `n_boot
   = 500` is chosen, not the package default of 999, purely for Totoro
   budget; the function's own documented arithmetic floor
   (`min_boot = ceiling(2/(1-conf)) - 1 = 39` for a 95% percentile interval,
   `coverage_ceiling = (n_boot-1)/(n_boot+1)`) gives `coverage_ceiling =
   0.996` at `n_boot=500`, comfortably above the floor that produced the
   documented `n_boot=10 -> 0.78` coverage artifact in the validation-debt
   register. `coverage_ceiling` is captured from the function's own return
   value and reported alongside every bootstrap coverage number, not just
   trusted implicitly.
5. **gllvm-Wald (SECONDARY, algebraic cross-check ONLY)** — `gllvm::gllvm(...,
   num.lv = 2, family = "gaussian")`, `se.gllvm`/`confint.gllvm`. Fit under
   the psi=0 secondary DGP cells only (gllvm has no psi tier, so fitting it
   against the primary `psi>0` truth would be a genuine, uncorrectable model
   mismatch). **Exempted from the shared primary coverage table** (see
   "Degeneracy and failure handling"); reported only as numeric agreement of
   point estimates/SEs against our own psi=0-fit Schur output, on `Sigma_jj`
   always, and on `Sigma_jk` only if Step-0 gate 0b confirms gllvm exposes
   the FULL joint loading covariance (not merely per-parameter diagonal SEs)
   needed for a valid product delta method — if not, the gllvm arm reports
   `Sigma_jj` only and this is stated explicitly, not silently dropped.
6. **Oracle cell** — `n=5000`, `psi>0`, Wald only, all of VA-Wald/LA-Wald/
   gllvm-Wald (Failure Mode 2 guard: establishes each method's own large-n
   floor before any finite-n contrast is trusted) plus the small LA-Profile
   oracle pilot named above (interval-method's own design omitted a
   profile/bootstrap oracle floor; both diagnostic-lens verdicts flagged
   this — fixed here at the cost of one small pilot rather than a full tier).

**What is explicitly NOT attempted (Amendment B, partially delivered, stated
honestly).** Amendment (B) asks that interval method be crossed with engine,
not fixed at Wald. This design delivers that crossing **fully for LA**
(Wald x Profile x Bootstrap) and **not at all for VA** beyond Wald, because
VA structurally has no profile or bootstrap route today
(`confint.gllvmTMB_va` errors by design), and every reviewer who considered a
novel `VA-Profile` arm (running `tmbprofile()` against the VA fit's ELBO) flagged
the same unresolved risk: the profile trace's shape has no guaranteed
relationship to a chi-square deviance when the objective is a lower bound
whose gap can vary non-monotonically with the fixed parameter, so a profile
failure there cannot be attributed to a fixable bug versus an inherent
property of profiling a bound, and Step-0 debugging of that arm could consume
disproportionate time before any Tier-2/3 budget should even be released.
Rather than carry that unresolved risk into a Totoro-cost commitment, this
design **accepts** the narrower scope: LA's own Wald/Profile/Bootstrap
crossing establishes whether our profile/bootstrap MACHINERY itself is
trustworthy in this exact parameterisation (a necessary precondition), and
VA-Wald-vs-LA-Wald/Profile isolates cause (b)/(d) vs (a)/(c) as far as a
Wald-only VA arm allows. Building a validated `VA-Profile` prototype is named
here as the natural, prerequisite-gated follow-on campaign, not delivered by
this one.

## Seeds, with MCSE arithmetic

`MCSE = sqrt(p(1-p)/n)` at nominal `p = 0.95`, so `p(1-p) = 0.0475`.

| n_seeds | MCSE | 2·MCSE (single-arm detection floor) |
|---|---|---|
| 100 | 0.02179 | 4.36 pp |
| 200 | 0.01541 | 3.08 pp |
| 300 | 0.01258 | 2.52 pp |
| 500 | 0.00975 | 1.95 pp |
| 1000 | 0.00689 | 1.38 pp |
| 2000 | 0.00487 | 0.97 pp |

(Recomputed and cross-checked term-by-term — one of the three reviewed
candidate designs had a factor-of-`sqrt(2)` arithmetic slip at exactly this
step; every value above is `sqrt(0.0475/n)`, verified numerically before
being written down here.)

**The arm-vs-arm CONTRAST, not the marginal MCSE, is the real deliverable**
(a fatal flaw against two of the three reviewed designs: sizing power against
nominal 0.95 alone, not against the actual difference this campaign exists to
detect). For two independent arms each near 0.95, `Var(p1-p2) =
p1(1-p1)/n1 + p2(1-p2)/n2`; at equal `n` this is `2 x MCSE_single^2`, i.e. the
**unpaired, conservative** difference-SE is `sqrt(2) x MCSE_single`. VA-Wald
and LA-Wald are fit to the **same simulated dataset per seed** (an explicit,
stated design decision, not left implicit), so the true paired-difference
variance is `Var(p_VA) + Var(p_LA) - 2·Cov(p_VA,p_LA)`; if the two engines'
seed-level failures are positively correlated (plausible — both are hardest
on the same near-boundary datasets), the true detection floor is *tighter*
than the unpaired bound below. The unpaired bound is used as the
pre-registered, conservative floor; any tighter paired estimate obtained from
the data is a bonus, not a substitute.

| Tier | n_seeds | Marginal 2·MCSE | Difference-band 2·sqrt(2)·MCSE (unpaired, conservative) |
|---|---|---|---|
| 1 (VA-Wald, LA-Wald, oracle) | 1000 | 1.38 pp | 1.95 pp |
| 2 (LA-Profile, 2 primary cells) | 300 | 2.52 pp | 3.56 pp |
| 3 (LA-Bootstrap, 1 cell) | 100 | 4.36 pp | 6.16 pp |
| gllvm secondary cross-check | 300 | 2.52 pp | n/a (not a coverage claim) |
| Oracle profile pilot | 30 | n/a (feasibility/floor only) | n/a |

**Pre-registered decision bands**, stated before any seed runs (closes the
"what counts as inconclusive" gap a reviewer flagged): for the headline
VA-Wald-vs-LA-Wald/Profile contrast on `V_j` at the two primary cells,
- **RESCUE**: VA-Wald's observed coverage sits outside its own 2·MCSE band
  below 0.95, LA-Wald or LA-Profile sits inside its band, and the gap exceeds
  the tier's difference-band.
- **NO-RESCUE**: both arms miss, or both cover, by amounts within the
  difference-band of each other.
- **INCONCLUSIVE**: the observed gap is smaller than the tier's
  difference-band. This is a valid, reportable, pre-registered outcome, not a
  null result to be quietly reinterpreted after the fact — the DGP's moderate
  (not extreme) `psi` regime makes a modest, hard-to-resolve gap the more
  likely real-world outcome, and the budget above is sized to detect large
  (dr21-scale, tens-of-points) effects reliably while being honest that it
  cannot always resolve single-digit ones.

**Pre-registered PRIMARY headline** (closes the multiplicity/garden-of-
forking-paths gap two reviewers raised, given ~45 estimand x cell x arm
combinations exist in total): the one number this campaign is powered and
committed to report as *the* result is **mean empirical coverage across its 8
traits, pooled over the two primary in-regime cells (`n=150, 400`,
`psi>0`), of `V_j` for LA-Wald and LA-Profile, and of `Sigma_jj` for
VA-Wald** — VA-Wald contributes `Sigma_jj`, not `V_j`, unless the
`fixed_idx`/`log_sigma` extension named under "Arms" (item 1) lands and
passes its own validation at Step-0 gate 0c, in which case `V_j` is added for
VA-Wald too and reported as the primary comparison instead. This distinction
is stated once, here, precisely so a `V_j`-labelled VA number is never
reported unless it is actually a `V_j` interval. Every other cell
(`n=50`, `n=5000` oracle, `psi=0` secondary, individual `Sigma_jj`/`Sigma_jk`
entries, the gllvm cross-check) is reported as secondary/exploratory evidence
and labelled as such — never substituted for the primary headline if it
happens to tell a better story.

## Degeneracy and failure handling

**Three failure modes get the SAME explicit, identical-across-arms treatment**
(closes the single most repeated fatal flaw across every reviewer: an
unstated or inconsistent denominator policy for failed fits, non-PD Schur
blocks, and dropped bootstrap refits):

1. **No-fit**: optimizer failure. Recorded, excluded from the "healthy" set,
   counted in the ITT denominator (below) as non-covering.
2. **Fit-but-no-SE**: `se_profile` is `NULL` (`status` such as
   `"va_singular_variational_block"` or `"va_non_pd_profile_information"`,
   `R/va-r3-proto.R:1671-1690`), or the LA `sdreport()`/bootstrap equivalent
   fails. Same treatment as no-fit.
3. **Fit-with-SE but numerically degenerate**: a fit that reports a finite
   `se_profile` while the underlying Schur denominator is near-singular. This
   is the specific pathology a reviewer traced mechanistically: as the
   variational posterior for the latent scores collapses (large `H_vv`), the
   Schur correction `B D^-1 B'` shrinks toward zero and the "corrected"
   information silently collapses back toward the naive, anti-conservative
   `H_ff` block — the exact failure the profile route exists to fix,
   reproduced invisibly inside a nominally "healthy" fit. **A per-seed,
   per-arm numerical-health record is therefore mandatory, not optional**:
   - `rcond()` of the Schur denominator (VA) / `cov.fixed` (LA) — flag if
     below `1e-8`;
   - gradient norm at the reported optimum;
   - `psi_hat_j / psi_true_j` ratio and, separately, distance of
     `log(psi_hat_j)` from the optimizer's lower search bound (a Heywood-case
     flag, most relevant at `n=50`);
   - for LA-Bootstrap specifically: count and disposition of inner refits
     that fail to converge, reported per seed, never silently dropped from
     the percentile calculation (the reviewed design's own risk section
     named exactly this: differential non-convergence near the boundary
     could make the bootstrap interval look *more* stable exactly where the
     true sampling distribution is breaking down).

   Every downstream metric (coverage, bias, width, the SE-ratio diagnostic
   below) is computed over the **same declared subset with the same flag**,
   never a different population per metric.

**Coverage is reported on two populations, always side by side**, so a
degeneracy-driven survivorship bias cannot masquerade as calibration:
- **ITT (intent-to-treat)**: every attempted seed; no-fit, no-SE, and
  numerically-degenerate seeds all count as non-covering.
- **Per-protocol**: healthy seeds only (none of the three failure flags
  raised).

If the two diverge by more than the tier's own MCSE band, that divergence is
reported as a finding in itself, not resolved by picking whichever number is
more convenient.

**Yield contingency (closes a diagnostic-lens fatal flaw)**: the mandatory
30-seed Step-0 pilot (below) measures per-cell yield (fraction healthy) before
any Tier-1/2/3 budget commits. If a cell's projected healthy yield is below
70% (most plausible at `n=50`, the deliberately out-of-regime stress cell),
that cell is explicitly **down-scoped to descriptive-only** (fit-outcome
counts and bias/degeneracy diagnostics reported, no coverage-rate claim) —
never silently absorbed into the coverage denominator at a smaller effective
`n` than the pre-registered budget assumed.

**Causal decomposition is 4-way, not 3-way** (closes a diagnostic-lens fatal
flaw: a 3-cause rubric that assigns anything left over to "Wald construction"
by elimination would misattribute a biased-but-precisely-estimated VA point
estimate). For every cell where VA-Wald under-covers:

| Cause | Diagnostic | 
|---|---|
| (a) partition/Schur-complement bug | `se_profile`-vs-empirical-SD ratio far from 1 in VA specifically, ~1 in LA (same model, same data) |
| (b) ELBO-vs-likelihood bound gap | SE-ratio ~1 in both VA and LA, but VA under-covers while LA (same parameterisation) covers |
| (c) Wald/symmetric-interval construction | SE-ratio ~1 in both, LA-Wald ALSO under-covers, but LA-Profile (same fits, different interval construction) covers — the one arm where this is directly testable |
| (d) mean-field / variational estimator bias | explicit bias metric `mean(point_est - truth)/truth`, computed per engine per cell; SE-ratio ~1 in both engines AND both point estimates are systematically off truth by more than sampling noise explains |

No cause is assigned by default/elimination; a cell where none of the four
diagnostics clearly fires is reported as "undetermined," not silently folded
into whichever cause has a slot left.

**The gllvm arm never enters the primary coverage table.** Because it is
fit under a psi=0 model against psi=0-truth data (matched, not mismatched, in
its own secondary cell — see DGP), it is a legitimate coverage measurement in
that narrow corner, but including it in the same table as the primary
`psi>0` cells would silently launder the caveat the moment the table is
copied elsewhere. It gets its own labelled section, always.

## Totoro run plan

Mandatory Step-0 gates (near-zero cost, run FIRST, before any tier budget
commits):

- **0a — parameterisation equivalence.** One large-`n` (`n=20000`) fit per
  engine (VA, LA, gllvm-on-psi=0-cell) against a `psi>0` truth (VA, LA) /
  `psi=0` truth (gllvm), confirming (i) `Sigma_jj`/`Sigma_jk`/`beta_j` recover
  planted truth, (ii) which fitted quantity supplies `psi_hat_j` in each
  engine, and (iii) VA and LA report the same free-parameter COUNT for the
  loading block under `unique=FALSE` (closes the "LA silently fits an extra
  Psi tier" mismatch risk raised three times across the minimal-lens
  reviews — one explicit parameter-count check, not an assumption).
- **0b — gllvm covariance surface.** Confirm whether `se.gllvm`/`vcov.gllvm`
  expose the full joint loading covariance or only per-parameter diagonal
  SEs; sets the gllvm arm's `Sigma_jk` scope (full or `Sigma_jj`-only).
- **0c — Sigma-Jacobian validation, and the `log_sigma`/`fixed_idx`
  extension.** Numerical (finite-difference) cross-check of the new
  `vec(Lambda Lambda^T)` delta-method helper against the existing
  `R/loading-ci.R` numerical-Jacobian pattern, on ~20-30 pilot seeds, for both
  VA and LA, before Tier 1 (not just Tier 2/3) is trusted. In the same gate,
  attempt the `log_sigma`-in-`fixed_idx` extension to
  `.va_r3_fixed_information_blocked()`/`.va_r3_fixed_information()`
  (`R/va-r3-proto.R:1632`, `:1777`) needed for a genuine VA-side `V_j`
  interval; re-run the package's own `se_profile >= se_conditional`
  invariant test (`tests/testthat/test-va-r3-prototype.R:334-409`) against the
  enlarged fixed block before trusting it. If this extension is not clean
  (e.g. `log_sigma`'s column of the Hessian is structurally different enough
  that the existing Schur-accumulation loop needs more than a one-line
  change), VA-Wald stays scoped to `Sigma_jj`/`Sigma_jk` for this campaign
  and the primary headline uses `Sigma_jj` for VA-Wald, per "Seeds."
- **0d — 30-seed harness pilot**, one per cell: yield rate, wall-clock,
  degenerate-fit rate. Recalibrates Tier 1-3 budgets before committing them;
  triggers the yield-contingency down-scope where needed.

Tiered budget (assumption-based unit costs, explicitly flagged as such,
recalibrated by 0d before commitment):

- **Tier 1** (VA-Wald + LA-Wald, 6 cells x 1000 seeds x 2 engines + oracle):
  ≈ 12,000 fits at an assumed 15-60s each ≈ 70-90 core-hours.
- **Tier 2** (LA-Profile, 2 primary cells x 300 seeds, 8 traits/replicate):
  ≈ 600 fits + profiling ≈ 100-150 core-hours.
- **Tier 3** (LA-Bootstrap, 1 cell x 100 seeds x (1 + 499 refits at
  `n_boot=500`)): ≈ 50,000 fits ≈ 200-260 core-hours.
- **gllvm secondary cross-check** (2 secondary cells x 300 seeds x 1 engine):
  ≈ 10-15 core-hours.
- **Oracle profile pilot** (30 seeds): < 2 core-hours.

Total ≈ 380-520 core-hours, at the mandated ≤100-core Totoro ceiling ⇒
4-6 hours continuous compute, realistically 1-2 days elapsed once Step-0
gates and a human checkpoint between Tier 1 and Tier 2/3 are counted (Tier
2/3 should not start until Step-0 and Tier-1 results are reviewed). Nothing
here goes to GitHub Actions or DRAC; this is a single Totoro batch, results
stay local.

## What this CANNOT answer

- Any response family other than Gaussian identity-link — count, binary, and
  ordinal responses (including dr21's own ~34-39% binary-loading regime) are
  excluded by construction to isolate the interval-method/bound question from
  family-specific Laplace weakness. A family sweep is a distinct follow-on.
- Whether VA-Profile or VA-Bootstrap would rescue VA-Wald coverage — that
  machinery does not exist and is not built here (see "Arms," above); this
  design measures whether our profile/bootstrap MACHINERY is itself
  trustworthy on LA, a necessary but not sufficient precondition for a future
  VA-Profile campaign.
- Coverage below the tiers' own 2·MCSE / difference-band floors (roughly
  1.4-4.4 pp marginal, 2-6 pp for arm contrasts) — this cannot resolve
  0.95-vs-0.93-type gaps, only dr21-scale or larger effects, by design.
- Whether under-coverage, if found, is caused by the loadings-only model
  choice itself rather than the interval method — Step-0 gate 0a is designed
  to rule out a *gross* mismatch (wrong parameter count, wrong psi
  interpretation) but does not attempt a full matched-truth ablation across
  every possible mismatch; that is a separate lens's job.
- Generalisation beyond `T=8`, `d=2`, this `Lambda`/`psi` magnitude, one
  covariate, and the tested `n`-grid.
- gllvm's real-world coverage in the wild — the gllvm arm runs only in the
  psi=0 secondary corner, matched to its own model, and is reported
  separately from the primary table; it establishes numeric agreement of the
  Schur formula across packages, not a general gllvm coverage claim.
- Any promotion, certification, or public claim. `default_tier` stays `"gh"`;
  the integration fence stays shut; every number is local evidence pending a
  D-43 panel, at most.

## How each adversarial flaw was resolved

1. **DGP-vs-fit "loadings-only" ambiguity (does `unique=FALSE` degenerate the
   likelihood or just drop a redundant tier)** — FIXED. Resolved concretely
   via the `estimate_gaussian_sd`/`unique`/`psi` argument separation in
   `.va_r3_fit()` (`R/va-r3-proto.R:2098-2118`): `psi_hat_j` is defined as the
   Gaussian residual variance, never the absent extra tier. Verified, not
   assumed, by Step-0 gate 0a.
2. **LA arm might silently carry an extra Psi tier vs VA's `psi=FALSE`**
   (raised 3x across the minimal-lens reviews) — FIXED. LA's formula is
   pinned explicitly: `latent(1 | unit, d = 2, unique = FALSE)`; Step-0 gate
   0a adds a parameter-count equality check before any seeded run.
3. **LA arm's shared-slope formula risks the package's `(0+trait):x`
   per-trait idiom producing a different estimand** — FIXED by DGP choice:
   this design plants per-trait `beta_j` from the start, so
   `(0 + trait):x` is the *correct* term, not an accidental mismatch.
4. **gllvm's Sigma_jk delta method needs the full joint loading covariance,
   which may not be exposed** — FIXED via Step-0 gate 0b: verify availability
   before scoping; fall back to `Sigma_jj`-only for the gllvm arm if absent,
   stated explicitly rather than silently computed wrong.
5. **No pre-registered denominator/attrition policy for failed fits, non-PD
   Schur blocks, dropped bootstrap refits** (raised independently by
   reviewers of all three lenses) — FIXED: identical ITT/per-protocol
   dual-reporting convention across every arm, described under "Degeneracy
   and failure handling."
6. **Power sized against nominal-0.95 MCSE rather than the actual arm-vs-arm
   difference, in a DGP regime expected to produce a moderate, not extreme,
   gap** — FIXED: explicit paired/unpaired difference-SE arithmetic and
   pre-registered RESCUE/NO-RESCUE/INCONCLUSIVE decision bands, with
   INCONCLUSIVE stated as a legitimate, honest, reportable outcome.
7. **MCSE arithmetic error found in one candidate design (a
   `sqrt(2)`-scale slip)** — FIXED: every MCSE value in this document is
   independently recomputed as `sqrt(0.0475/n)` and shown in a single table.
8. **No yield-rate contingency for the hardest cells** — FIXED: mandatory
   30-seed Step-0 pilot per cell measures yield before budget commits; a
   cell below 70% healthy yield is down-scoped to descriptive-only, not
   silently absorbed at a smaller effective n.
9. **`Sigma_tt`/`V_j` truth-vs-estimate definitional inconsistency (does the
   "total variance" include psi or not)** — FIXED: `Sigma_jj` and `V_j` are
   defined once, in one table ("Estimands"), with `V_j := Sigma_jj + psi_j`
   used consistently and matching the codebase's own established convention
   in `.profile_ci_total_variance()`/`.total_variance_spec()`
   (`R/profile-derived.R`).
10. **New Sigma-covariance delta-method Jacobian is unvalidated** — FIXED:
    Step-0 gate 0c, a numerical finite-difference cross-check on a small
    pilot, adapting the existing validated pattern in `R/loading-ci.R` rather
    than writing the propagation from scratch.
11. **Near-singular Schur block can silently produce a finite-but-garbage SE,
    masquerading as a healthy fit** — FIXED: explicit numerical-health record
    (`rcond`, gradient norm, psi boundary distance) per seed per arm, ITT vs
    per-protocol dual reporting.
12. **3-way causal rubric would misattribute a biased VA estimate to "Wald
    construction" by elimination** — FIXED: 4-way rubric adds an explicit
    mean-field-bias cause with its own diagnostic, never assigned by default.
13. **Sigma_jk's delta-method-on-a-product is a generic, engine-independent
    under-coverage risk (Sobel-test analogue)** — ACCEPTED as an inherent
    property of the estimand, not fixed away: stated explicitly in
    "Estimands"; marginal single-arm `Sigma_jk` numbers are reported but
    never used alone to indict a specific engine, only the paired VA-vs-LA
    contrast (which shares the artifact and therefore cancels it) supports a
    causal claim.
14. **Secondary gllvm arm (matched-model but different-truth-regime from the
    primary cells) could get silently merged into the shared coverage table**
    — FIXED: gllvm arm is permanently excluded from the primary table and
    reported in its own labelled section.
15. **Bootstrap inner-refit failures could be silently dropped, biasing
    toward apparent stability near the boundary; the new VA-side bootstrap
    code was proposed with no pilot** — PARTIALLY FIXED / PARTIALLY ACCEPTED:
    refit-failure counts are tracked and reported per seed (fixed); a
    VA-Bootstrap arm is not attempted at all in this design (accepted scope
    narrowing, consistent with item 18 below) so its associated no-pilot risk
    does not arise here.
16. **No oracle-floor (large-n) check for the Profile/Bootstrap arms, only
    Wald** — FIXED for Profile (small `n=5000` LA-Profile pilot added);
    ACCEPTED as a gap for Bootstrap — a large-`n` bootstrap replicate is
    dominated by refit cost with limited additional diagnostic value over the
    Profile oracle pilot already added, so it is left for a follow-on if the
    Tier-3 result needs it.
17. **Multiplicity: ~45 estimand x cell x arm combinations with no
    pre-specified primary endpoint** — FIXED: one pre-registered headline
    (mean `V_j` coverage across the two primary cells, VA-Wald vs LA-Wald vs
    LA-Profile); everything else is explicitly secondary.
18. **VA structurally has no profile/bootstrap route, so Amendment (B)'s
    "method x engine" crossing cannot be fully delivered** — ACCEPTED, not
    fixed: building a validated VA-Profile prototype was independently
    flagged by every reviewer who considered it as carrying its own
    unresolved, possibly irreducible risk (profiling a bound rather than a
    likelihood). Rather than commit Totoro budget to an arm whose failure
    mode cannot be diagnosed, this design delivers the full method crossing
    on LA only (validating the machinery) and names a `VA-Profile` prototype
    as the explicit, prerequisite-gated next campaign.
19. **Rotation/sign ambiguity in loadings** — FIXED by estimand choice, not a
    late patch: `Sigma`/`V_j` are rotation-and-sign-invariant at any `d`
    (unlike the minimal-lens design's fallback to `d=1` to dodge rotation
    specifically), and raw `Lambda` entries are excluded outright, consistent
    with `R/loading-ci.R`'s own documented confirmatory-fit-only restriction
    on per-entry loading CIs.
20. **Correlated, non-independent trait-level cells within one seed being
    read as independent replicates** — FIXED: aggregation convention stated —
    one coverage indicator per (seed, trait), never pooled across traits as
    if independent; the pre-registered primary headline is an explicit mean
    across the 8 traits per cell, not treated as 8x the effective replication.
21. **(Self-identified during source verification, not raised by any
    reviewer.)** `.va_r3_fixed_information_blocked()`/
    `.va_r3_fixed_information()` restrict the fixed block to `beta`/
    `theta_rr` only (`R/va-r3-proto.R:1632`, `:1777`), excluding `log_sigma`
    (the Gaussian residual/`psi` parameter) — so a VA-Wald interval on
    `V_j = Sigma_jj + psi_j` is not computable from the shipped machinery
    as-is, even though the campaign's own headline is framed around `V_j`.
    FIXED by scoping honestly rather than silently assuming the interval
    exists: VA-Wald's estimand set is `Sigma_jj`/`Sigma_jk` unless the named,
    narrowly-scoped `fixed_idx` extension (Step-0 gate 0c) lands and is
    validated against the existing `se_profile >= se_conditional` invariant
    test, in which case `V_j` is added for VA-Wald and used in the headline
    instead. Caught by walking the source the way the campaign's own
    machinery citations demanded, not assumed from the recon summary.
