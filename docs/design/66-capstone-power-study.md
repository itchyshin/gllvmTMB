# Design 66 -- Capstone power / accuracy / coverage simulation study

**Status:** APPROVED scientific design contract; execution route superseded
under D-50. This is the pre-specification for the end-of-road capstone (issue
#349, milestone `power-study`). The seven scientific questions of the original
draft remain resolved by the maintainer in section 12. The former execution
plan paired a local `n_sim ~= 200` pilot with an `n_sim = 2000` HPC core and
used `dev/m3-pilot-launch.R`; that plan is retained as historical design
provenance, not current launch authority.

**2026-07-20 D-50 execution supersession:** deterministic local diagnostics and
bounded non-claim local/Totoro smoke may exercise the existing primitives. No
48-cell pilot, claim-bearing fit campaign, or production DRAC array is admitted
until a separate compute-admission slice freezes and validates source/archive/
runner checksums, campaign/task identity, immutable destinations, retry policy,
and result schema, followed by explicit maintainer approval. Scientific cell
definitions and thresholds below remain design inputs; present-tense execution
language in the retained locked plan is superseded by this boundary.

**Maintained by:** (to assign). **Reviewers:** Fisher (validation design),
Curie (DGP fixtures), Noether (identifiability), Rose (scope honesty),
Ada (coordinator).

**Parent issues / board:** umbrella #349 ("[roadmap] Power-simulation
capstone"); feeder #346 ("Simulation / coverage framework"); capability
board #340; live register `docs/design/35-validation-debt-register.md`.

**Parent designs:** Design 42 (M3 DGP grid -- the engine this reuses),
Design 48 (M3.4 boundary regimes -- the convergence/start machinery),
Design 50 (M3.3b surface admission -- target-explicit promotion gates),
Design 35 (validation-debt register -- rows CI-08, CI-10, FAM-*, RE-*,
ANI-*), Design 65 (cross-lineage coevolution kernel -- Gamma; scope
question in section 12).

**2026-06-23 scaling gate:** the current pilot is diagnostic only. Do
not launch a broad Totoro/DRAC campaign or promote `CI-08` / `CI-10`
until the pilot audit and metric-repair slices resolve the remaining
issues: pre-2026-06-24 binary logit-harness artifacts must not be read
as true `binomial_probit` evidence, ordinal-probit cells must produce
primary coverage rows or be excluded from the confirmatory core,
`signal = 0` diagnostics must not be described as Type-I error for
positive `Sigma_unit_diag` targets, and decision aggregates must report
MCSE with explicit fit-health denominators. The first compute step after that
audit is an immutable-chunk smoke ladder, not the full `n_sim = 2000`
grid.

**Backed by (verified on origin/main):** PR #364 (merged 2026-05-31,
`fix(m3): coverage gate keys on Sigma_unit_diag bootstrap, not psi
proxy`); PR #366 (merged 2026-05-31, RE-09 within-unit latent()+unique()
recovery test). The capstone reuses the `dev/m3-grid.R` engine and the
current immutable task-manifest and reducer primitives. The repository has
smoke-only Slurm plumbing, not an admitted production DRAC array harness; that
driver must still be built, reviewed, and frozen. The former Actions dispatch
is retired under D-50 and remains only in Git history.

---

## 0. Why this doc exists (and what it is not)

The capstone is the **paper's evidence chapter**: the large, pre-registered
power/accuracy/coverage study that converts the package's per-capability
recovery tests into one defensible, paper-ready evidence surface. The
maintainer restored an eventual, bounded first-CRAN objective on 2026-08-08,
but this capstone remains separate from that release gate: it answers to the
methods paper and post-release validation programme. Issue #349 is currently a
one-line stub. This doc turns that stub into an ADEMP
pre-specification (Morris, White & Crowther 2019) so the headline claims are
falsifiable, the grid is sized by Monte Carlo arithmetic rather than
convenience, and the compute budget is costed before any cluster time is
spent.

**Why the reframing is not cosmetic.** A release gate is adequate once it
clears a pass/fail bar: the cheapest grid that resolves the binary wins, and
a cell that fails is a blocker to eliminate. An evidence chapter is held to a
different standard -- a defensible characterisation: the power curve, the
regimes where calibration degrades, and an honest statement of what was not
checked. Under that standard, claim H3 (section 2; already specified as "the
curve, not a single pass/fail") rises in priority relative to H1's binary
coverage gate, and a cell that fails becomes a finding worth reporting rather
than only a blocker worth eliminating. This reframing is dated 2026-08-02
(audit `docs/dev-log/audits/2026-08-02-design66-staleness-audit.md`, finding
S-3) and should be read alongside section 10, which restates what "DONE"
means under it.

This is a **refinement of #349, not a parallel artefact.** The M3 grid
(Design 42) already validates *coverage* for a `family x d` slice at the
`psi`/`Sigma_unit_diag` estimand. The capstone is broader on three axes
the M3 grid does not currently exercise:

1. **Power and Type-I error**, not only coverage. M3 fixes a single
   signal level; the capstone varies signal strength to map a power
   curve and to estimate the false-positive rate when the structure is
   absent.
2. **The random-effect-structure axis.** M3 varies `family x d` only.
   The capstone must additionally vary the *between-unit structure*
   (phylo / spatial / animal x scalar/unique/indep/dep/latent/slope),
   which is the package's signature surface.
3. **n_sim sized for adjudication.** M3's R = 200 has a coverage MCSE of
   ~1.54 pp, which cannot distinguish a 94 % gate from 95 % nominal
   (section 7). The capstone raises n_sim to a defended floor.

What this doc is **not**: it is not a re-derivation of the DGP (that is
Design 42), not a new engine (the engine lane R/fit-multi.R,
R/brms-sugar.R, R/parse-multi-formula.R, src/*.cpp is untouched), and not
a coverage *re-run* of the existing `family x d` cells (those are tracked
by #346 / CI-08 / CI-10).

---

## 1. ADEMP at a glance

| ADEMP element | This study |
|---|---|
| **A**ims | Falsifiable claims (section 2) about coverage, bias, and power across the capability matrix. |
| **D**ata-generating mechanisms | Tiered factorial grid (section 4): family x RE-structure x source x d x n x signal x replication. |
| **E**stimands | Rotation-invariant targets (section 5): `Sigma_unit_diag`, total off-diagonal correlation; raw `psi`/loadings are diagnostic only. |
| **M**ethods | TMB Laplace ML; TWO distinct interval routes -- the certified chi-square_1 profile on `log V_t` (`profile_ci_total_variance()`) and the parametric bootstrap (`bootstrap_Sigma()`) -- whose primary/diagnostic assignment is an OPEN maintainer decision (section 3); convergence + PD-Hessian filtering (section 6). |
| **P**erformance measures | Coverage, bias, relative bias, empirical SE, RMSE, CI width, power, Type-I error -- each with an MCSE formula (section 7). |

The M3 grid is already reported in ADEMP terms (Design 42 sec.1) and
follows the transparent-reporting items of Williams et al. (2024, MEE);
the capstone inherits both conventions.

---

## 2. Aims -- the headline claims (falsifiable targets)

The capstone exists to support, or refute, the claims the paper will make. It
is not a prerequisite for the bounded first CRAN submission restored on
2026-08-08 (section 0). Each claim below is still stated as a falsifiable
target with a pass/fail rule, but a failing
cell is now read as a finding to characterise, not only a blocker to
eliminate -- see section 0's release-gate-versus-evidence-chapter
distinction. The maintainer must confirm the exact claim set (section 12,
Q-c) before the grid is frozen, because the grid must be sized to support
whichever gate is chosen.

**Claim H1 (coverage).** Across the core confirmatory grid, the 95 %
parametric-bootstrap CIs on the rotation-invariant estimand
`Sigma_unit_diag` attain empirical coverage >= 94 % (the audit-1 gate,
Design 42 sec.1; M3_PASS_GATE = 0.94 in `dev/m3-grid.R`). *Falsified* if
any core cell's coverage point estimate, with its MCSE, lies materially
below 0.94.

**Claim H2 (accuracy).** Across the core grid, the point estimator
recovers `Sigma_unit_diag` and the total off-diagonal correlation with
negligible relative bias (target |rel bias| < 5 %) and RMSE that shrinks
with n. *Falsified* if relative bias exceeds the threshold beyond MCSE in
any core cell.

**Claim H3 (power).** For each RE structure (phylo / spatial / animal),
gllvmTMB detects a present between-unit signal with documented power at a
realistic field-study n; the power curve is monotone in signal strength
and in n. The deliverable is the *curve*, not a single pass/fail -- the
paper reports the n and signal level at which power crosses, e.g., 0.80.

**Claim H4 (calibration of the null / Type-I error).** When the
between-unit structure is absent (signal = 0), the rejection rate of the
"structure present" decision is at or below the nominal alpha (target ~=
0.05 within MCSE). *Falsified* if the false-positive rate is materially
inflated.

**Current audit caveat (2026-06-23).** The existing pilot's
`signal = 0` cells should not yet be interpreted as H4 evidence for
`Sigma_unit_diag`, because total diagonal variance can remain positive
when the shared latent loading signal is absent. The Type-I target must
be a pre-specified structure-present decision, such as off-diagonal
correlation, a variance-share component, or another explicitly defined
null, before the metric is used in the capstone.

**Boundary caveat on the choice of H4 null (2026-08-02).** The three
candidate nulls above are NOT interchangeable, and the difference is a
matter of which asymptotic null distribution applies. If H4's rejection
rule is CI-exclusion on a *variance-type* quantity whose true value under
H0 sits on the BOUNDARY of the parameter space -- a `Sigma_unit_diag`
component, or a variance share, equal to 0 -- then the null distribution
of the profile deviance `2(L_max - L_0)` is not chi-square_1. It is the
50/50 mixture `0.5 * delta_0 + 0.5 * chi-square_1` (Self & Liang 1987;
*flagged unverified in this draft, see section 11*). A profile route that
takes its critical value from `qchisq(level, 1)` -- which is exactly what
`.profile_ci_via_refit()` does by default via `.qchisq_threshold(level)`,
`R/profile-derived.R:394` -- would then be CONSERVATIVE at the boundary:
Type-I error *below* nominal alpha, not the inflation H4 exists to
detect. A percentile bootstrap CI on a non-negative quantity has its own,
different, small-sample boundary behaviour (mass piling at the constraint,
so the lower endpoint is not free to fall below 0). Neither route is a
clean instrument for a boundary null, and the two fail differently, so a
"both arms agree" reading would be misleading rather than reassuring.

**Steer H4 to the INTERIOR null.** The off-diagonal correlation of
`Sigma_unit` is the recommended H4 target, because its null value
(rho = 0) is an interior point of (-1, 1) and the ordinary chi-square_1
reference applies. The variance-share option is retained in the caveat
above only as a *documented alternative that carries a boundary
correction as a prerequisite*, not as an equally-weighted candidate. If a
variance-type null is nonetheless chosen, the mixture reference and its
verification are a deliverable of the study, not an assumption.

**Non-claims (state explicitly in the paper).** (i) We do not claim
asymptotic coverage at n = 10,000; the anchor is the moderate field-study
regime (Design 42 sec.2). (ii) We do not claim recovery of
rotation-variant loadings `Lambda` or raw `psi` as estimands -- those are
identified only up to rotation and are reported as diagnostics (section
5; EXT-09/EXT-14/EXT-15 carry rotation advisories). (iii) Power to detect
phylogenetic signal is fundamentally limited by the number of tips;
Boettiger, Coop & Ralph (2012, Evolution 66:2240) show likelihood
surfaces for OU/BM-type processes are often flat with few tips, so low
power at small n_species is an honest finding, not a defect.

---

## 3. Estimands (stated before Methods, on purpose)

The estimand choice is the single most consequential decision in this
study, and it is the one the package got wrong once already. The
2026-05-19 M3.3 production run gated on **profile CIs of per-trait `psi`**
(`theta_diag_B`), a *rotation-variant* proxy. 13/15 cells "failed" the
94 % gate (CI-08) and the mixed-family cells looked badly miscalibrated
(CI-10: d=1 0.820, d=2 0.685, d=3 0.550). PR #364 (merged 2026-05-31)
corrected this: the promotion gate now keys on `coverage_primary` /
`primary_gate_status`, evaluated on the **bootstrap CI of total
`Sigma_unit_diag`** -- the rotation-invariant estimand the coverage claim
is actually about. `psi` is retained only as a diagnostic
(`coverage_prof` / `profile_gate_status`) and for the binomial-`psi`=0
regression check.

**The capstone inherits PR #364's estimand discipline without exception.**

### 3.1 Two different profile routes -- do not confuse them (2026-08-02)

Everything this document said about "the profile" before 2026-08-02 meant
**route P-psi**. A second and unrelated profile route now exists. They
target different quantities, have opposite rotation properties, and carry
opposite evidence.

| | **P-psi** (the demoted diagnostic) | **P-V** (the certified route) |
|---|---|---|
| Target | per-trait unique variance `psi[t]` (`theta_diag_B`) | per-trait TOTAL variance `V_t = (Lambda Lambda')[t,t] + psi[t]` |
| Rotation | **variant** -- not an estimand | **invariant** -- the canonical target |
| Reference | chi-square_1 profile | chi-square_1 profile on `log V_t` |
| Entry point | M3 legacy `"psi"` target in `dev/m3-grid.R` | `profile_ci_total_variance()`, `NAMESPACE:174`, wrapper `R/profile-derived.R:1010` -> certified internal `:856` |
| Standing | **DEMOTED by PR #364** -- reported, never gated | **CERTIFIED** under a pre-registered gate; see below |
| Measured | 0.9384 (d1) / 0.8653 (d2) -- FAILS | 0.9467 / 0.9467 -- clears the 0.94 gate |

`psi` remains a diagnostic and PR #364's demotion of **P-psi** stands
untouched. Nothing below reinstates it. Wherever this document says
"profile", it now means **P-V** unless it says `psi`.

### 3.2 What the P-V certificate does and does not cover

The certificate (`docs/dev-log/2026-07-29-certificate-disposition.md`,
pre-registration `docs/dev-log/2026-07-29-certificate-gate-preregistration.md`)
records 0.9467 in both cells on a fresh-seed 20,000-replicate campaign
and passed a 3-lens D-43 panel 3-0. It arrives with fences that travel
with it. Every one of these must be carried into any capstone use:

1. **Two-sided only.** The interval is not equal-tailed -- upper-tail
   misses run about 1.53x lower-tail misses -- so **one-sided use is
   invalid**, and so is any test of `V_t = 0`.
2. **A marginal average that FAILS in the smallest-`V_t` ventile**
   (d1 0.9259, d2 0.9369). Coverage is averaged over the simulated `V_t`
   distribution; it does not hold sub-regime.
3. **Conditional on convergence** (96.9 % d1, 99.4 % d2). Non-converged
   fits get no guarantee.
4. **A 0.94 FLOOR, never nominal 0.95.** Both cells sit roughly 3.3
   clustered SEs below 0.95. Restating the result as 95 % coverage is
   explicitly prohibited by the pre-registration.
5. **The two certified cells share 19,000 of 20,000 seeds** and are NOT
   independent replicates. "Both cells clear" is roughly 1.1 cells of
   corroboration, not 2.
6. **Certified for gaussian, d in {1, 2}, n_units = 150 ONLY.**

### 3.3 The certificate has ZERO evidence on the RE-structure axis

This is not a sixth family fence; it is a different kind of gap, and it
is the one that matters most for this study.

The certified cells were fit by `dev/m3-grid.R:1092-1096` as

    value ~ 0 + trait + latent(0 + trait | unit, d = d) + unique(0 + trait | unit)

-- a plain diagonal `Sigma_unit` with a reduced-rank `Lambda`, and **no
`phylo_*`, `spatial_*`, `animal_*` or `kernel_*` random-effect term of
any kind**. (The pre-registration itself names only "a **diagonal**
`Sigma_unit` specification, gaussian family" and the harness whose
sha256 it froze; the formula above is read from that harness, which is
the primary source.)

But section 4.2 DEFINES the Tier-0 core grid by crossing
**`phylo_dep`, `spatial_dep`, `animal_dep`, `phylo_latent`** -- the
structured between-unit tier is the axis that makes the core grid the
core grid, and is the package's signature surface (section 0, item 2).

So the certificate is **not merely "gaussian / d / n"-scoped**. On the
axis this study is built around it has no evidence at all, and the models
are not a rescaling of the certified ones: a structured tier replaces the
identity between-unit kernel with a fixed `K`, adds tier-variance and
correlation parameters, and changes the shape of the likelihood surface
that P-V's `uniroot` bisection walks -- including how flat that surface
is (section 2 non-claim (iii): OU/BM surfaces are often flat at few
tips). **This revision must not be read as "the profile route just needs
re-certifying on more families."** Extending P-V to the structured tiers
is a *deliverable of this study*, not an assumption it may make.

### 3.4 OPEN DECISION -- primary interval method (NOT resolved here)

Section 12 locks the grid; it does **not** lock this. Before 2026-08-02
the assignment was "bootstrap primary, profile diagnostic" only because
the only profile this document knew about was P-psi. That premise is
gone, so the assignment is **re-opened as an explicit maintainer
decision** with three named candidates. **This document does not choose
between them, and no lane may swap them by fiat.**

- **(a) Profile primary / bootstrap secondary.** Gates on P-V; reports
  bootstrap alongside. This option no longer inherits the former
  pre-registered certificate: the retained campaign did not establish exact
  constrained-refit fidelity. Requires an exact-profile repair, recalibration,
  and the structured-tier extension as in-scope work.
- **(b) Bootstrap primary at `n_boot >= 200`.** Keeps PR #364's
  assignment and the single route that amortises across all estimands
  from one refit set (section 8). Costs the `(1 + n_boot)` factor
  re-priced in section 8, and the arm has no certificate -- 0.9418 at
  B=200 is a measurement, not a gate that anyone pre-registered.
- **(c) Both arms on every core cell, reporting the pair.** Most
  informative and most defensible for a paper: agreement between an
  amortising resampling route and a per-scalar likelihood route is real
  evidence, and disagreement is a finding. It is also the most expensive
  and it does **not** average the two costs -- it adds them.

Inputs the decision needs and does not yet have: (i) the measured
`refits_per_profile` demanded by section 8; (ii) whether the off-diagonal
correlation estimand is gated, which changes the cost comparison's sign
(section 8); (iii) whether extending P-V to the structured tiers is in
scope. Until it is taken, section 6 states both routes without ranking
them, and no gate language anywhere in this document may assume either.

Primary estimands (rotation-invariant; the claims in section 2 are about
these):

- **`Sigma_unit_diag`** -- the diagonal of the implied between-unit trait
  covariance `Sigma_unit` (T x T). This is the canonical rotation-free
  target (Design 42 sec.1; constructed in `m3_make_truth()` in
  `dev/m3-grid.R`). **Primary CI method: OPEN (section 3.4)** -- the
  candidates are P-V (`profile_ci_total_variance()`), parametric
  bootstrap (`bootstrap_Sigma()`), or both.
- **Total off-diagonal correlation of `Sigma_unit`** -- the cross-trait
  correlation structure (the "shared latent axis" signal). Surfaced via
  `extract_Sigma(level, part)` (EXT-01, rotation-invariant).
- **(Conditional) Gamma = Lambda_H Lambda_P^T** -- the host-trait x
  partner-trait coevolution block, *only if* the coevolution kernel
  (Design 65 / #361) is in scope for the capstone (section 12, Q-e).
  Default assumption in this draft: **deferred** to a follow-up. The
  `kernel_*()` engine is built, exported (`kernel_dep`, `kernel_indep`,
  `kernel_latent`, `kernel_scalar`, `kernel_unique`; `NAMESPACE`), and
  tested (register KER-01/02/03, all `covered`); the deferral rests on
  budget, not on engine availability -- see section 4.5 and section 12
  L-e.

Diagnostic-only quantities (reported, never gated):

- raw `psi` (per-trait unique variance) -- rotation-variant proxy;
- raw loadings `Lambda` -- identified up to rotation (EXT-14);
- `sigma_eps` -- needs replicate structure to separate from unique-`psi`
  (RE-09; section 4.6).

**Rationale for stating estimands before methods:** Morris et al. (2019)
place E before M precisely so the target is fixed independently of what
the estimator finds convenient to report. The CI-08/CI-10 confound is the
textbook failure of doing it the other way round (the run profiled what
`theta_diag_B` made available, then discovered the claim was about a
different quantity).

---

## 4. Data-generating mechanisms -- the tiered grid

### 4.1 The infeasibility of full factorial

The capability surface (enumerated from `NAMESPACE` + the Design 35
register on origin/main) is:

- **Sources x modes (between-unit RE structure):**
  - phylo: scalar, unique, indep, dep, latent, slope, rr (`R/brms-sugar.R`)
  - spatial: scalar, unique, indep, dep, latent (slope via augmented form)
  - animal: scalar, unique, indep, dep, latent, slope (`R/animal-keyword.R`)
  - (`relmat` is realized via `phylo_*(vcv=)` / `animal_*(A=/Ainv=)` and is
    soft-deprecated toward `kernel_*()` per Design 65; not a separate live
    keyword family. `kernel_*()` is built, exported, and tested on
    origin/main (`kernel_dep`, `kernel_indep`, `kernel_latent`,
    `kernel_scalar`, `kernel_unique`; register KER-01/02/03, all
    `covered`) -- see section 4.5.)
- **Families wired:** gaussian, poisson, nbinom2, binomial(logit/probit/
  cloglog), betabinomial, gamma, beta, lognormal, student-t, tweedie,
  ordinal_probit (register FAM-01..14 = covered). nbinom1 is fid 15,
  test-skip-gated / review-branch-wired (FAM-07). delta/hurdle = fixed-
  effect-only by design (FAM-17, Design 62) -- excluded from the RE grid.
- **Tiers:** unit / unit_obs / cluster (covered); cluster2 planned (#342).
- **Latent rank d:** 1, 2, 3.
- **n axes:** n_species/units, n_traits, observations.
- **Signal strength:** `lambda_scale`, `psi_scale`, `phi`, plus a phylo/
  spatial signal ratio.
- **Replication:** with / without within-cell replicates (RE-09).

A naive product is well over 10^4 cells before n_sim and bootstrap are
applied; at the per-fit cost in section 8 this is not affordable. The
study is therefore **tiered**: a small core confirmatory grid that carries
the paper's claims, plus extension grids that are nice-to-have and can be
staged or dropped under budget pressure. "Must pass" here means the grid the
paper's evidence chapter rests on, not the bounded first-CRAN gate (section
0).

### 4.2 Tier 0 -- Core confirmatory grid (MUST pass)

The minimal grid that supports H1-H4. Design principle: vary one
"hard" axis at a time against a fixed, well-understood backbone rather
than crossing everything.

| Factor | Core levels | n |
|---|---|---|
| Family | gaussian, nbinom2, binomial(probit), ordinal_probit | 4 |
| RE source x mode | phylo_dep, spatial_dep, animal_dep, phylo_latent | 4 |
| Latent rank d | 1, 2 | 2 |
| n_species/units | 50, 150 (moderate field-study anchor; Design 42) | 2 |
| Signal strength | {absent (0), moderate, strong} | 3 |
| Replicates per unit | 1 vs >=2 (RE-09: required to separate sigma_eps) | included as a within-cell design property, not a cross factor |

Cross-product as written = 4 x 4 x 2 x 2 x 3 = **192 cells**. This is the
"everything crossed" reading and is itself near the budget ceiling at
n_sim = 1000+ (section 8). The recommended core is a **fractional**
slice (vary one hard axis at a time off a backbone): hold the backbone at
`gaussian, phylo_dep, d=1, n=150, moderate signal` and walk each factor
singly. That backbone-plus-spokes design is **~40-60 core cells**,
which is the affordable target. The exact fraction (full 192 vs the
~50-cell spoke design) is RESOLVED in section 12 L-b: the Phase-2
confirmatory grid is the core-4 cross; the Phase-1 PILOT is a bounded
48-cell subset (`pilot_grid()`).

Rationale for the level choices:

- **Families:** gaussian (baseline), nbinom2 (the hardest M3 cell --
  0.38 smoke coverage, Design 48; if it passes at scale the count path is
  trustworthy), binomial-probit (link-residual machinery, `psi`=0 invariant
  per PR #263), ordinal-probit (cutpoints). This is the representative
  subset; "all wired families" is the extension (section 4.3). Final
  family set is RESOLVED in section 12 L-f: the core 4 (gaussian,
  nbinom2, binomial(probit), ordinal_probit).
- **RE modes:** `*_dep` exercises the full between-unit correlated tier
  (the off-diagonal estimand); `phylo_latent` exercises the reduced-rank
  path. `scalar`/`unique`/`indep` are simpler and move to the extension.
  `slope` is the structured random-slope surface and is its own extension
  (section 4.4) because the engine guards non-Gaussian slopes to
  `gaussian()` (board #340 "Random slopes (non-Gaussian) -- deferred").
- **n_species 50/150:** brackets the Boettiger et al. (2012) low-power
  regime (n=50) and a comfortable regime (n=150) so H3's power curve has
  a visible rise.
- **Signal {0, moderate, strong}:** the 0 level is the signal-absent
  condition needed for the future H4 Type-I target, but the current
  Phase-1 `Sigma_unit_diag` pilot reports it only as a signal-zero
  coverage diagnostic. It is not a Type-I error estimate until a
  structure-detection rejection rule is specified.

### 4.3 Tier 1 -- Family-completion extension (nice-to-have)

Re-run the core RE/d/n/signal backbone across the remaining wired
families (gamma, beta, lognormal, student-t, tweedie, betabinomial,
poisson, binomial-logit/cloglog, mixed-family). Mixed-family is the
package's signature differentiator (Design 42) and is high-value but was
the worst-calibrated M3 cell (CI-10); include it if budget allows.
Approx **+80-150 cells** depending on how many families x how much of the
backbone. Feeds register FAM-* promotions and #348 (Family-validation
completion).

### 4.4 Tier 2 -- Structured random-slope extension (nice-to-have)

The Gaussian structured-slope surface is COMPLETE on the board
(#326/#327/#328: phylo/spatial/animal/relmat x unique/indep/dep/latent
all C, plus augmented correlated intercept+slope + SPDE). The capstone
slope extension validates *power + coverage* for slope-variance recovery
(`*_slope`, RE-02) at Gaussian only, since non-Gaussian slopes are
engine-deferred. Approx **+20-40 cells**. Feeds #341 (Random-slope
completion).

### 4.5 Tier 3 -- Coevolution / Gamma extension (DEFERRED by default)

The `kernel_*()` engine (Design 65 / #361) is built, exported, and tested
on origin/main (register KER-01/02/03, all `covered`); its absence is no
longer the reason this tier is deferred. Default in this draft: **out of
scope** on budget grounds, flagged for re-decision (section 12, Q-e and
L-e). Listed so the grid schema reserves the slot.

### 4.6 Replication structure (do not skip)

RE-09 established that within-cell replicates are **required** to separate
the diagonal `Psi` tier from `sigma_eps` in the unit_obs / explicit-Psi
compatibility configuration (register RE-09; `test-mixed-response-unique-nongaussian.R`,
`test-tiers-*.R`). The core grid therefore treats "replicates per unit"
as a *design property of each cell* (>= 2 observations per unit where the
estimand requires the separation), not merely a free knob. Cells whose
estimand is unidentifiable without replicates must be generated with
them; this is a correctness constraint, not a power-tuning choice.

### 4.7 Seeds and reproducibility

Reuse the M3 seed discipline: freeze a per-campaign `seed_base` and
deterministic per-cell/per-rep derivation inside `m3_run_cell()`. The legacy
Phase-1 accumulation driver can write a per-shard manifest before fitting,
including campaign, shard, cell, path, replicate-window, and seed fields.
Outside its former Actions environment, however, `source_sha` may be `NA`, and
its campaign identifier is seed-derived. Those manifests remain readable for
historical diagnostics but are not admissible for a new claim-bearing local,
Totoro, or DRAC campaign. Before remote production, a separate compute-admission
slice must require and validate a non-missing frozen source SHA, source-archive
checksum, unique campaign and task identities, exact runner checksum, and
immutable destination paths. Legacy workflow run fields remain readable only
for historical stores. The current persist/status path checks duplicate output
paths, duplicate chunk paths, overlapping per-cell replicate windows, and
overlapping seed ranges; those checks are necessary but not sufficient for a
new scientific campaign.
For future immutable-chunk array jobs, `--mode=chunk` runs the active
rows in a chunk manifest and writes one RDS per planned chunk, while
`--mode=chunk-audit` reads the written manifests and requires every
planned chunk file to exist and be non-empty before any aggregation
step proceeds. `--mode=chunk-aggregate` is the derived single-writer
step: it rereads the validated chunks, checks that each file's `rep`
values match the manifest window, rejects duplicate
`cell_id`/`rep`/`trait_id`/`target` rows, and writes per-cell aggregate
RDS files under `_chunk-aggregate/`. Effective per-cell seed blocks are
separated by a fixed stride larger than the intended batch size after
the harness family/d seed offset is applied, so same-run cells do not
share `rep_seed` values.

Persist the long per-replicate grid (`<cell-id>.rds`) and rebuild
`pilot-index.rds` as a derived cache from those per-cell files. The
manifest plus per-cell grids, not the shared index, are the audit trail
for every failed fit, seed, and CI (Williams et al. 2024 transparency
items; Design 42 sec.1). The first Totoro/DRAC smoke step is
manifest-only: `dev/power-pilot-smoke.sh` runs with
`SMOKE_STAGE=manifest`, or `dev/power-pilot-slurm-smoke.sh` writes and
only after explicit maintainer approval optionally submits the same
manifest-only smoke as a SLURM job. It
parses the fixed audit-mini grid, writes the manifest, validates unique
immutable chunk destinations, and exits before fitting. Before any real
SLURM submission, prepare the remote checkout on the login node with
`dev/power-pilot-drac-setup.sh`: it creates a version-pinned user R
library, installs this checkout into that library, and verifies
`library(gllvmTMB)`. The default library convention is project storage
when `$PROJECT` is set, otherwise a scratch smoke library when
`$SCRATCH` is set, with `$HOME/.local/R/<R version>` as the final
fallback. Scratch libraries are purgeable and are for smoke setup only;
private account and quota paths are deliberately not recorded in this
public design note.

---

## 5. Estimands -- see section 3

(Stated before Methods on purpose; not repeated here.)

---

## 6. Methods -- the estimator and the intervals

- **Estimator:** TMB Laplace-approximate marginal ML, as fitted by
  `gllvmTMB()` through `R/fit-multi.R` (untouched by this study). The
  reduced-rank loadings + structured between-unit covariance are the
  fitted objects; the estimands in section 3 are derived from them via
  the rotation-invariant extractors (EXT-01).
- **Interval methods.** Three routes exist for the primary estimands.
  **Which of the first two is PRIMARY is an open maintainer decision
  (section 3.4); this section deliberately does not rank them.** Both are
  stated at equal weight so that the cost model in section 8 can price
  either arm, and so that no downstream text can quietly assume one.
  - **Route B -- parametric bootstrap**, `bootstrap_Sigma()`, on total
    `Sigma_unit_diag` and the off-diagonal correlation. This was the M3
    PRIMARY method (PR #364);
    `m3_target_method("Sigma_unit_diag", n_boot)` returns `"bootstrap"`
    when `n_boot > 0`. Bootstrap support is gated by
    `m3_bootstrap_supported(fit)`. **Hard floor `n_boot >= 200` for any
    claim-bearing cell, and each such cell must assert
    `coverage_ceiling >= conf` from the returned object** -- see section 8,
    lever 2, for why this is arithmetic and not a tuning preference
    (`R/bootstrap-sigma.R:227-241`). One refit set yields every requested
    summary at once (`R/bootstrap-sigma.R:346-375`).
  - **Route P-V -- chi-square_1 profile on `log V_t`**,
    `profile_ci_total_variance()` (`NAMESPACE:174`; wrapper
    `R/profile-derived.R:1010` delegating to the certified internal at
    `:856`). This is the ONLY route with a pre-registered certificate
    (0.9467, both cells, 20,000 reps, D-43 panel 3-0), and that
    certificate carries six live fences plus a total absence of evidence
    on the RE-structure axis -- **all of them restated in section 3.2 and
    3.3 and all of them binding on any capstone use.** The function marks
    every returned row `route-only` / `none` in its `interval_status` column;
    a
    claim-bearing campaign should record that column per row rather than
    infer regime membership. Unlike Route B this route does **not**
    amortise: it is a separate `uniroot` bisection per scalar quantity
    (`R/profile-derived.R:866-897`, and per trait pair at
    `dev/m3-grid.R:1666-1681`). Section 8 prices that.
  - **Route P-psi -- profile likelihood on per-trait `psi`**
    (`theta_diag_B`) -- reported, not gated (PR #364 demotion). This is a
    DIFFERENT route from P-V and its demotion is unaffected by P-V's
    certificate (section 3.1).
  - Wald / Fisher-z intervals exist for some family paths (register
    FAM-02, CI-10) and may be reported as a further diagnostic where
    cheap. They are not certificate-bearing on any cell.
- **Convergence + identifiability filtering (reuse M3 machinery,
  Design 48):** each replicate records optimizer convergence,
  `median_max_gradient`, `sdreport_ok_rate`, `pd_hessian_rate`,
  `median_restart_count`, `boot_fail_rate`. The M3 stop/quality gates
  carry over verbatim:
  1. empirical coverage on `Sigma_unit_diag` >= 0.94;
  2. CI-missing rate <= 10 %;
  3. fit-failure rate <= 20 % (<= 30 % for mixed-family cells);
  4. bootstrap-failure rate <= the same family limit;
  5. no one-sided miss pattern (>= 80 % of misses on one side);
  6. `pilot_status == "PASS_TO_SCALE"` achieved at the pilot scale first.
  Replicates that fail to converge or lack a PD Hessian are excluded from
  the coverage numerator/denominator using the existing column logic, and
  the *exclusion rate is itself a reported performance measure* (a cell
  that only "passes" by discarding 40 % of fits is not a pass).
- **Start strategy:** `single_trait_warmup` is the M3 production default
  (Design 43/48); residual starts (McGillycuddy et al. 2025, JSS 112(1))
  and multi-start are available for the count cells that need them. The
  start policy is a *fixed method per family*, recorded per cell, not a
  per-replicate search that could bias coverage optimistically.

---

## 6A. Validation oracles -- what external comparator exists per core cell, and what does not

Design 66 predates `docs/design/87-latent-variable-oracle-map.md` (dated 2026-08-02,
this document's first oracle survey). This section states what Design 87 found for
exactly the four Tier-0 core RE structures section 4.2 fixes -- `phylo_dep`,
`spatial_dep`, `animal_dep`, `phylo_latent` -- and what that means for what kind of
evidence this capstone can and cannot produce.

### 6A.1 The four core cells against Design 87's oracle map

| Core cell (section 4.2) | External oracle (Design 87 §3.1) | Epistemic status (Design 87's own words) |
|---|---|---|
| `phylo_dep` | `MCMCglmm` `us(trait):animal` + `pedigree`/`inverseA` | Marked `~` (plausible mechanism, not verified this session). A Bayesian posterior mean under an inverse-Wishart-family prior, not an MLE. Design 87 §3.2: "no fit was attempted" and "a posterior mean ... is not an MLE -- disagreement is not diagnostic of an engine bug, and agreement is not proof of MLE correctness." |
| `animal_dep` | `MCMCglmm` `us` + `pedigree` | Same caveat as `phylo_dep` -- untested, posterior-mean, not an MLE (Design 87 §3.1 `animal_` row, `dep` column). |
| `spatial_dep` | None cleanly matched. `gllvm`'s `row.eff`/`lvCor` do not fit the cell's definition; a `glmmTMB` `mat()`/`exp()` candidate is unchecked. | Design 87 §3.2: "not confidently established either way -- needs a scout, not a clean NONE." An admitted gap in Design 87's own verification, not a rated absence. |
| `phylo_latent` | **NONE.** No package combines a relatedness/tree structure with reduced-rank ordination loadings. | Design 87 §3.1: "no package puts a tree on reduced-rank ordination loadings." §3.2 marks this a *checked* absence, not a scouting gap: `gllvm`'s `colMat` is proven structurally incapable of touching the ordination axis (S2 §D, a positive empirical result, not an unchecked claim), and `Hmsc`'s phylogenetic mechanism structures the trait-regression coefficients `Beta`, not the ordination loadings `Lambda` (per the Hmsc cross-package scout, `docs/dev-log/audits/2026-07-29-jason-hmsc-cross-package-scout.md`). |

**All four core cells lack an MLE-quality external oracle** -- but "no MLE oracle" is
not one uniform state, and this document should not collapse it into one. Design 87
distinguishes three different epistemic positions across these four cells, and the
distinction matters for how each finding should be reported if the corresponding
capstone cell under- or over-covers:

1. **Untested plausible reference** (`phylo_dep`, `animal_dep`): a mechanism exists,
   is documented, and has not been run. A future `MCMCglmm` scout could resolve this
   one way or the other; the caveat is temporary if someone builds it (Design 87 §7
   lists this scout as its #2 build priority).
2. **Admitted scouting gap** (`spatial_dep`): Design 87 itself does not know whether
   an oracle exists. This is not a claim that none does -- it is a claim that this
   repository has not looked hard enough to say.
3. **Checked absence** (`phylo_latent`): verified from both directions this session
   (Design 87 §3.2). No amount of further scouting inside the current package roster
   (`gllvm`, `MCMCglmm`, `Hmsc`, `galamm`) will produce a third-party MLE oracle for
   this cell, because none of the four implements the underlying decomposition at
   all.

### 6A.2 The limitation, stated in the terms the paper will use

Say this plainly, because a reviewer will otherwise say it for us: **the capstone's
structural axis is self-validation against known simulated truth, with no
independent implementation agreeing.** Every core-cell coverage and power number this
study reports is checked against the data-generating process that produced it, not
against a second estimator that arrived at a similar answer by a different route. For
a coverage and power study this is not fatal -- the estimand is defined by the
simulation, so validating against known simulated truth is the correct primary
evidence and needs no third-party package to exist. But it is a real limitation on
what the capstone's numbers can be read to support, and it must be stated as such
rather than left implicit: a coverage claim on `phylo_dep` or `phylo_latent`
demonstrates that `gllvmTMB`'s own estimator and its own interval method are
internally well-calibrated against the process that generated the data; it does not,
and currently cannot, demonstrate that a different implementation of the same model
would recover the same truth. Readers who expect a coverage study to double as a
cross-implementation validation should not be left to discover the absence on their
own.

### 6A.3 The one available instrument: a fixed-parameter Stan check

Design 87 §6.1 describes one route that exists for every cell in this table,
including the three that have no third-party package peer at all: a hand-written
Stan model of the same likelihood, checked not by fitting but by evaluating the
log-likelihood at a fixed, shared parameter vector in both the TMB implementation and
the Stan model and requiring agreement to machine precision. `rstan` 2.32.7 and
`cmdstanr` 0.9.0 are installed on this machine (Design 87's verification ledger,
§0). **No such model has been written for any cell as of this document.**

This is a *stronger* check than most of Design 87's ✓✓ cells (the shipped `gllvm` and
`glmmTMB` comparators this package already has), not a weaker fallback for the cells
that lack one. Those comparators agree that a **fitted** point estimate matches under
a tolerance -- 1% relative log-likelihood, 10-25% relative Frobenius error on Sigma,
>=0.95 Procrustes correlation on loadings (Design 87 §5). A tolerance-based check can
absorb a small shared error along with genuine optimiser noise; there is room inside
the band for two implementations to agree despite each carrying the same
minor mistake. A fixed-parameter log-likelihood comparison has no such room: the two
numbers either match to machine precision or they do not, and there is nothing left
over for a tolerance to hide behind. It is also immune to the two traps that make the
rest of Design 87's map hedge so carefully -- there is nothing being estimated, so
neither the VA-vs-Laplace estimator gap (§2.6) nor the posterior-mean-vs-MLE gap
(§3.2) can arise.

### 6A.4 The Stan route's own limitation, stated with equal prominence

This instrument should not be sold past what it is. A Stan model written by this
package's own contributors encodes *their* reading of the mathematics. It therefore
checks **implementation** -- a TMB template bug, a wrong parameterisation, a missing
Jacobian term, an indexing error -- and not a **shared conceptual misunderstanding**.
If the TMB template and a self-written Stan program both encode the same wrong
reading of the underlying model, they will still agree to machine precision, and the
check will report a pass on a shared error (Design 87 §6.1, stated there in exactly
these terms). A third-party package embodies someone else's independent reading of
the theory; a self-written Stan reference does not, by construction. Mitigation, per
Design 87 §6.1: derive the Stan model from the *published* model definition -- the
paper or textbook a feature is based on -- rather than from this package's own R or
C++ code, and preferably have someone who did not write the TMB template write the
Stan model, so the two implementations are each read from the source material
independently rather than from each other.

**`tmbstan` is not an oracle for this purpose.** It wraps the *same* TMB objective
function `gllvmTMB` already builds and runs HMC over it instead of Laplace-
approximating the random effects. Agreement with `tmbstan` shows only that TMB's own
objective is internally consistent under a different integration scheme -- it cannot
show that the objective encodes the right model, because it is the same objective
being checked against itself. `tmbstan` answers a different, separately useful
question instead: whether the Laplace approximation is adequate, by comparing it
against a Bayesian HMC integration of the *same* random effects. That question is
real and worth asking elsewhere in this package's validation programme, but it is not
a substitute for the fixed-parameter Stan check above and must not be presented as
one (Design 87 §6.1). `tmbstan` is not installed on this machine.

### 6A.5 Open decision

Whether a hand-written, fixed-parameter Stan check for `phylo_latent` (the one core
cell with a checked-absent third-party oracle) is in scope for this capstone, or a
separate slice on its own timeline, is not resolved here -- it is the maintainer's
call, and it interacts with the compute-admission gate (section 12) and the
primary-interval-method decision this audit raises separately. It is also relevant
beyond this capstone: the phylogenetic multinomial (Design 84, partially shipped) has
no third-party package peer either (Design 87 §1, §6), and would need the same kind
of instrument if it is ever to have one.

---

## 7. Performance measures and Monte Carlo SE (n_sim sizing)

Let n_sim be replicates per cell, p the true coverage, theta the
estimand, theta_hat the estimate, and emp_SD the empirical SD of
theta_hat across replicates. All measures and their MCSEs follow Morris
et al. (2019, Table 6).

| Measure | Estimator | Monte Carlo SE |
|---|---|---|
| Coverage | mean(CI contains theta) = p_hat | sqrt(p_hat(1 - p_hat) / n_sim) |
| Bias | mean(theta_hat) - theta | emp_SD / sqrt(n_sim) |
| Relative bias | (mean(theta_hat) - theta) / theta | (emp_SD / sqrt(n_sim)) / |theta| |
| Empirical SE | emp_SD | emp_SD / sqrt(2 (n_sim - 1)) |
| RMSE | sqrt(mean((theta_hat - theta)^2)) | (approx) involves 4th moment; report bootstrap MCSE |
| CI width | mean(upper - lower) | SD(width) / sqrt(n_sim) |
| Power | mean(reject H0 | signal present) = pow_hat | sqrt(pow_hat(1 - pow_hat) / n_sim) |
| Type-I error | mean(reject H0 | signal absent) = a_hat | sqrt(a_hat(1 - a_hat) / n_sim) |

### 7.1 Why R = 200 (the M3 pilot) is inadequate for the gate

Coverage MCSE at the worst case p = 0.95:

| n_sim | Coverage MCSE at p=0.95 | Can it adjudicate 94 % vs 95 % (1 pp gap)? |
|---|---|---|
| 200 (M3 pilot)  | sqrt(0.95*0.05/200)  = 0.0154 (1.54 pp) | No -- MCSE > the gap |
| 500             | sqrt(0.95*0.05/500)  = 0.0097 (0.97 pp) | Marginal |
| 1000            | sqrt(0.95*0.05/1000) = 0.0069 (0.69 pp) | Yes, with a ~0.7 pp margin |
| 2000            | sqrt(0.95*0.05/2000) = 0.0049 (0.49 pp) | Yes -- MCSE < half the gap |
| 5000            | sqrt(0.95*0.05/5000) = 0.0031 (0.31 pp) | Comfortable; usually unaffordable |

At R = 200 the coverage estimate's two-MCSE interval is +-3.1 pp -- it
cannot distinguish "94 % gate met" from "95 % nominal" from "92 % under-
covered". This is *exactly* why Design 42's own gate language is "nominal
up to Monte Carlo noise at R = 200": at the pilot scale the gate is a
smoke check, not an adjudication.

### 7.2 Recommended n_sim

- **Floor for gate adjudication: n_sim = 2000** per core cell (coverage
  MCSE 0.49 pp at p=0.95; resolves the 94/95 gap to within half the gap).
- **Minimum defensible: n_sim = 1000** per core cell (0.69 pp) if budget
  forces it -- acceptable for a binary pass/fail with an explicit ~0.7 pp
  margin, but state the looser MCSE in the paper.
- **Power cells:** at pow ~ 0.80, MCSE = sqrt(0.8*0.2/n_sim) -> 0.89 pp at
  n_sim = 2000, which resolves a power curve to ~+-1.8 pp (two MCSE) --
  ample for reporting the crossing point. Power does not need more than
  the coverage floor.
- **Extension tiers:** n_sim = 1000 is acceptable (these inform register
  promotions, not the paper's headline claim).

The MCSE arithmetic gives the **floor**; the ceiling is the compute
budget (section 8). Final n_sim is Q-d.

---

## 8. Compute budget

Total model fits, primary (bootstrap) path:

    fits = cells x n_sim x (1 + n_boot)

The `+1` is the point fit; `n_boot` is the parametric-bootstrap refits per
replicate. Worked estimates (wall-clock uses a nominal mean fit time;
calibrate against `mean_runtime_s` from a pilot before committing):

**Re-priced 2026-08-02 at the `n_boot >= 200` floor.** The former table
priced every scenario at `n_boot = 100`, which lever 2 below shows is not
admissible for a claim-bearing cell. At the floor the multiplier is
`(1 + 200) = 201`, so the bootstrap bill is just over 2x what this table
previously reported.

*Arm B -- parametric bootstrap.* `fits = cells x n_sim x (1 + n_boot)`:

| Scenario | cells | n_sim | n_boot | fits | at 2 s/fit | at 20 s/fit |
|---|---|---|---|---|---|---|
| Core, spoke design | 50  | 1000 | 200 | 1.01e7 | ~233 days(1 core) | ~6.4 yr(1 core) |
| Core, spoke design | 50  | 2000 | 200 | 2.01e7 | ~465 days(1 core) | ~12.7 yr(1 core) |
| Core, full 192     | 192 | 2000 | 200 | 7.72e7 | ~4.9 yr(1 core)   | ~49 yr(1 core)  |

*Arm P-V -- profile.* The bootstrap formula does not describe this arm at
all, because the bootstrap AMORTISES and the profile does not. One
bootstrap refit set of `>= 201` yields the whole `Sigma_unit` summary --
every diagonal entry AND the off-diagonal correlations -- from the same
draws (`R/bootstrap-sigma.R:346-375`: each refit is a full `gllvmTMB()`
call and `extract_fn()` pulls every requested `what` from it). A profile
is a **per-scalar-quantity `uniroot` bisection**: one per trait for the
diagonals (`R/profile-derived.R:866-897`) and one per trait PAIR for the
correlations (`dev/m3-grid.R:1666-1681`, `utils::combn(n_traits, 2L)`).
The arm therefore costs

    fits = cells x n_sim x (1 + n_estimands x refits_per_profile)

with the `+1` again the point fit. The two multipliers:

- **`n_estimands`.** At the harness default `T = 5`
  (`M3_DEFAULT_N_TRAITS`, `dev/m3-grid.R:46`): **5** if only
  `Sigma_unit_diag` is gated; **15** if section 3's off-diagonal
  correlation estimand is gated too (5 diagonals + `choose(5,2) = 10`
  pairs). Which it is follows from the open decision in section 3.4 and
  is not settled here. It changes the SIGN of the comparison below.
- **`refits_per_profile` -- NOT YET MEASURED.** Each bisection step is
  one penalised `nlminb` on the existing TMB objective, warm-started at
  the MLE with an analytic target gradient. Per bound
  (`R/profile-derived.R:448-506`): up to 8 bracket-widening probes plus
  the finite floor/ceiling probe (`max_expand = 8L`, trials
  `q_hat +/- 0.35 * 1.6^(0:7)`, floor/ceiling `q_hat -/+ 15`), then
  `stats::uniroot` with `tol = 0.005` and `root_maxiter = 25L`, which
  also re-evaluates both bracket endpoints. Reading those constants:
  **hard worst case 2 x (9 + 2 + 25) = 72 refits per scalar**; a
  well-behaved bound that crosses on its first or second probe costs
  roughly 7-13, i.e. **~14-26 per scalar for the two-sided interval.**
  **These are code-derived bounds, not measurements. An empirical
  `refits_per_profile` -- median and upper decile, per family and per RE
  structure, since a flat structured-tier surface will widen brackets --
  MUST be measured on a bounded non-claim smoke before any
  compute-saving number is committed to a budget or a maintainer
  decision.**

**What the comparison actually says.** At `refits_per_profile` in 14-26
against Arm B's 201 refits per replicate, and counting refits only:

| gated estimands | Arm P-V refits/rep | vs Arm B's 201 |
|---|---|---|
| diagonals only (`n_estimands = 5`) | 71 - 131 | **~1.5x - 2.8x CHEAPER** |
| diagonals + all pairs (`n_estimands = 15`) | 211 - 391 | **~1.05x - 1.95x MORE EXPENSIVE** |
| diagonals only, worst case (72/scalar) | 361 | ~1.8x more expensive |

**The profile arm is not an order-of-magnitude saving, and under the
section 3 estimand set it may be no saving at all.** Any planning
statement that says otherwise is wrong. Two honest qualifications, in
both directions: (i) the table counts refits and assumes they cost the
same, which they do not -- a bootstrap refit is a cold full `gllvmTMB()`
call including formula parsing, `MakeADFun` taping, the
`single_trait_warmup` start strategy and `sdreport`, while a profile step
reuses the tape and warm-starts at the MLE with an exact gradient, so the
per-refit cost almost certainly favours P-V; (ii) that advantage is
UNMEASURED, and so is `refits_per_profile`. **Both must be measured
together before the ratio is used to choose a compute target
(section 12, L-a addendum).**

These are *single-core* figures to make the scale unmistakable: the
capstone is **embarrassingly parallel** but **not a GitHub Actions job**.
The retired M3 Actions workflow demonstrated a historical shard shape,
but D-50 supersedes that route even for pilots. Current bounded smoke
plumbing can run locally or on Totoro; no new claim-bearing pilot or
production DRAC array is admitted until its driver receives its own
implementation, review, and frozen manifest. Concretely, the core spoke design at
n_sim = 1000, n_boot = 100, 2 s/fit is ~117 single-core-days -> roughly a
day on ~128 cores, or a few days on a modest cluster allocation. The full
192-cell x n_sim = 2000 reading is a multi-CPU-year job and is only
realistic on HPC.

**Levers to cut the bill (in priority order):**

1. **Stage it:** run Tier 0 first; gate Tiers 1-3 on Tier 0 passing.
2. **`n_boot` is NOT a lever -- it is a floor. (Corrected 2026-08-02;
   the former lever 2 is DELETED as unsafe.)** The deleted text offered
   `n_boot = 50` as a way to halve the bill and asserted that "the
   bootstrap-replication count trades against interval noise, *not*
   against the coverage MCSE, which is set by n_sim". **That parenthetical
   is false, and the falsity is arithmetic rather than empirical.** A
   percentile interval built from `B` draws is bounded by its own widest
   realisation `[min, max]`, whose coverage cannot exceed `(B-1)/(B+1)`
   **whatever the data are**. That is a ceiling on the estimand itself,
   not Monte Carlo noise that averages away over replicates:

   | `n_boot` (B) | max attainable coverage `(B-1)/(B+1)` |
   |---|---|
   | 25 (the quoted M3 production default) | **0.9231 -- BELOW this study's own 0.94 gate** |
   | 39 (`ceiling(2/(1-conf)) - 1` at conf = 0.95) | 0.9500 -- bare minimum for a nominal-95 % request |
   | 50 (the deleted "halve the bill" lever) | 0.9608 -- 1.1 pp of headroom against nominal 95 % |
   | 100 (the former cost-table setting) | 0.9802 |
   | 200 (the `bootstrap_Sigma()` default) | 0.9901 |

   At `n_boot = 25` a capstone cell **could not pass H1 even with a
   perfect estimator**, and the failure would present as a coverage
   shortfall and be misread as a package defect. Empirically, holding the
   draws fixed and varying only B, the same estimand moves 0.8073 (B=10)
   -> 0.9418 (B=200) -- barely above the 0.94 gate at the default, with no
   slack to trade.

   **Therefore: hard floor `n_boot >= 200` for every claim-bearing cell,
   and every such cell must assert `coverage_ceiling >= conf` from the
   returned object before its own numbers are trusted.**
   `bootstrap_Sigma()` returns `$coverage_ceiling` for exactly this
   purpose and warns below `min_boot` (`R/bootstrap-sigma.R:227-241`); a
   warning alone is insufficient because the 2026-07-29 failure was an
   automated harness and a script can swallow a warning.

   **Keep the two quantities separate.** `n_sim` sets the coverage MCSE
   -- section 7's arithmetic and its `n_sim = 2000` floor are correct and
   are NOT touched by this correction. `n_boot` separately imposes a hard
   ceiling on the coverage that is achievable at all. Raising `n_sim`
   cannot lift a `n_boot` ceiling, and raising `n_boot` does not shrink
   the MCSE.
3. **Fractional core (spoke vs full 192):** the single biggest lever.
4. **Family subset** (Q-f): 4 core families, not 14.
5. **The interval-method choice (section 3.4)** is now a first-order cost
   term in both directions -- see the Arm P-V pricing above. It is a
   scientific decision that happens to move the bill, **not** a budget
   lever to be pulled for cost reasons, and its saving is at most ~2.8x
   and may be negative.

**Recommendation:** budget the core (Tier 0) explicitly. The intended route is
Totoro for bounded smoke and DRAC for frozen claim-bearing arrays, with
aggregation from checksummed local/`/project` keepers. That DRAC route is not
admitted until the production driver and compute-admission contract above are
built and reviewed. GitHub Actions is not used for pilot, production,
aggregation, or result storage. Available DRAC allocation and measured task
resources determine the eventual production branch.

---

## 9. Reuse of the M3 grid engine (build = thin)

The capstone is mostly *configuration*, because `dev/m3-grid.R` already
provides the pieces. Explicit reuse map (verified on origin/main):

| Capstone need | Existing M3 component | Gap to build |
|---|---|---|
| DGP / truth | `m3_make_truth()`, `m3_simulate_response()` | extend to phylo/spatial/animal between-unit structure (M3 currently builds the within-trait `Sigma_unit` truth; the RE-source axis needs a between-unit covariance `K` injected) |
| Cell runner | `m3_run_cell()` (targets, n_boot, seeds) | parametrize the RE source/mode + signal-strength axes |
| Estimands + gate | `coverage_primary` / `primary_gate_status` on `Sigma_unit_diag` bootstrap (PR #364) | add a target-aligned detection / false-positive decision rule (reject "structure present") -- the one genuinely new performance measure |
| Signal knobs | `--lambda-scale`, `--psi-scale`, `--phi`, `--n-units`, `--n-traits`, `--d` (precompute CLI) | wire a signal-strength factor (incl. the 0 / null level for H4) |
| Convergence filtering | `pd_hessian_rate`, `sdreport_ok_rate`, `boot_fail_rate`, restart cols | none (reuse) |
| Persistence | `*-grid.rds` + `*-summary.rds` writers | none (reuse) |
| Dispatch | frozen task manifest + reducer contract | run bounded Totoro smoke; build and review the production DRAC array driver before submission; aggregate from local/`/project` keepers |

The new code surface is: (a) a between-unit-`K` DGP extension, (b) a
signal-strength + null factor, (c) a target-aligned detection /
false-positive decision rule, (d) a
cluster array-job driver. None of it touches the engine lane.

**Build it test-first** (the repo's TDD discipline): a smoke at n_sim =
10 per new cell type that asserts the new axes wire through and the
null-signal cell produces ~alpha rejections, before any production sweep.

---

## 10. Definition of Done

The capstone is DONE when:

1. **PREREQUISITE -- the compute-admission slice exists, is reviewed, and
   is frozen.** Under the 2026-07-20 D-50 supersession (header, L11-18;
   section 4.7) no 48-cell pilot, no claim-bearing fit campaign and no
   production DRAC array is admitted until a separate compute-admission
   slice freezes and validates source/archive/runner checksums, campaign
   and task identity, immutable destination paths, retry policy, and
   result schema -- followed by explicit maintainer approval. **Verified
   2026-08-02: no such design document exists.**
   `grep -rl 'compute-admission' docs/ dev/` returns seven files, none of
   them a design doc: this document, `docs/dev-log/check-log.md`,
   `docs/dev-log/audits/2026-08-02-design66-staleness-audit.md`,
   `docs/dev-log/after-task/2026-07-20-m1-heavy-baseline.md`,
   `dev/power-pilot-run.R`, `dev/precompute-m3-grid.R`, and
   `dev/m3-pilot-launch.R`. **This item is not stale, it is LIVE AND
   UNSATISFIED**, and it binds execution regardless of how the open
   decisions in section 3.4 and section 12 resolve. It is listed first
   because it is a gate on starting, not a box to tick at the end: any
   capstone plan that does not schedule it before the grid is sized is
   planning a campaign it is not permitted to run.
2. The core (Tier 0) grid has run at the agreed n_sim with the agreed
   family/RE subset, on the agreed compute, with all six M3 quality
   gates (section 6) satisfied *and* the fit-exclusion rate reported per
   cell.
3. H1 (coverage >= 94 % on `Sigma_unit_diag`, MCSE < 0.5 pp), H2
   (|rel bias| < 5 %), H3 (a power curve per RE source, monotone in n and
   signal), and H4 (Type-I ~= alpha) are each adjudicated -- supported or
   honestly reported as partial -- on the core grid.
4. The long per-replicate artefacts + seeds + failed-fit rows are
   archived (Williams et al. 2024 transparency).
5. The register rows are updated: CI-08 and CI-10 move from `partial`
   toward `covered` (or stay partial with the new evidence), and the
   exercised FAM-*/RE-*/ANI-* rows cite the capstone artefact.
6. A paper-ready report (tables + power curves) is produced.

**2026-08-08 reconciliation.** The earlier combined "CRAN + paper (milestone
#3)" gate remains retired even though an eventual first-CRAN objective has
been restored. This capstone gates the paper, not the bounded release. A core
cell that fails H1's 94% gate is reported as a finding (the regime where
calibration degrades), consistent with H3 already being specified as a curve
rather than a pass/fail. DONE still requires every hypothesis to be honestly
adjudicated -- supported, or reported as partial with the reason -- not that
every cell pass. The capstone itself still gates on all other paper tracks
being done (issue #349: "Gated on all other tracks").

---

## 11. References (verified against repo usage where possible)

- Morris TP, White IR, Crowther MJ (2019). Using simulation studies to
  evaluate statistical methods. *Statistics in Medicine* 38:2074-2102.
  (ADEMP; MCSE table. Already cited in Design 42 sec.1.)
- Williams CJ et al. (2024). Reporting standards for simulation studies.
  *Methods in Ecology and Evolution*. (Transparent-reporting items;
  already cited in Design 42 sec.1.)  *[Exact author list / volume not
  re-verified here -- confirm at write-up; cited as used in Design 42.]*
- Burton A, Altman DG, Royston P, Holder RL (2006). The design of
  simulation studies in medical statistics. *Statistics in Medicine*
  25:4279-4292. (Design-of-simulation framing.)  *[Citation not verified
  against an external source in this draft -- confirm at write-up.]*
- Boettiger C, Coop G, Ralph P (2012). Is your phylogeny informative?
  Measuring the power of comparative methods. *Evolution* 66:2240-2251.
  (Tip-count limits on phylo power -- grounds the n_species axis and the
  H3 non-claim.)  *[Citation not verified against an external source in
  this draft -- confirm at write-up.]*
- Niku J, Hui FKC, Taskinen S, Warton DI (2019). gllvm: Fast analysis of
  multivariate abundance data. *Methods in Ecology and Evolution*
  10:2173-2182. (GLLVM reference method.)  *[Confirm at write-up.]*
- Warton DI et al. (2015). So many variables: joint modeling in
  community ecology. *Trends in Ecology & Evolution* 30:766-779.  *[Confirm
  at write-up.]*
- McGillycuddy M, Popovic G, Bolker BM, Warton DI (2025). Parsimoniously
  fitting large multivariate random effects in glmmTMB. *Journal of
  Statistical Software* 112(1). (Residual starts for reduced-rank fits;
  already cited in Design 48.)
- White IR (2010); Skrondal A (2000) -- performance-measure reporting in
  simulation studies. *[Named in the capstone brief; not independently
  verified here. Confirm at write-up.]*

**Verification note:** Morris (2019), Williams (2024), and McGillycuddy
(2025) are confirmed in use elsewhere in this repo's docs (Design 42, 48).
Burton (2006), Boettiger (2012), Niku (2019), Warton (2015), White (2010),
Skrondal (2000) are cited from the capstone brief and standard knowledge
and are flagged for verification at paper write-up; do not treat the
volume/page details as checked.

---

## 12. LOCKED SCIENTIFIC PLAN (execution superseded under D-50)

The seven open questions of the original draft are RESOLVED. The plan below
locks the scientific grid, estimands, and intended evidence depth. Its original
local/HPC launch instructions are historical and do not override the 2026-07-20
compute-admission boundary above.

**2026-08-02 addendum --** the sentence above is retained verbatim and its
scope is clarified rather than changed. What section 12 locks is the
**scientific grid, the estimand discipline, and the intended evidence
depth**. It never locked the **interval METHOD**, and it could not have:
the only profile route this document knew of when L-a through L-g were
written was the demoted `psi` proxy (route P-psi), and the certified
route P-V did not exist. **Section 3.4 re-opens the primary/diagnostic
assignment as an explicit maintainer decision with three named
candidates. It is not resolved by this addendum, by section 3, or by
section 6.** No L-row below is reversed; L-a and L-c carry their own
dated addenda where the re-pricing and the interval-arithmetic ceiling
bear on them.

- **L-a (compute target) -- PHASED pilot then HPC core (resolves Q-a +
  Q-d).** The scientific design targets a pilot at `n_sim ~= 200` to size
  wall-time and expose gross miscalibration, followed by an `n_sim = 2000` HPC
  core (MCSE 0.49 pp at p = 0.95; section 7.2 floor). Neither fitting stage is
  currently admitted. The pilot and core require the later compute-admission
  bundle and separate approval and are never GitHub Actions jobs. At
  `n_sim = 200`, coverage MCSE is ~1.54 pp (section 7.1), so that stage is a
  sizing/diagnostic instrument rather than gate adjudication; the intended
  94/95 adjudication remains the `n_sim = 2000` target.

  **2026-08-02 addendum --** the `n_sim` figures above stand unchanged;
  the **bill** attached to them does not. Section 8 is re-priced at the
  `n_boot >= 200` floor, which raises the bootstrap arm by just over 2x
  against the retired `n_boot = 100` table (spoke design at
  `n_sim = 2000`: ~465 single-core-days at 2 s/fit, not ~234). The
  profile arm has its own cost term, `cells x n_sim x n_estimands x
  refits_per_profile`, whose `refits_per_profile` is **unmeasured** and
  whose `n_estimands` (5 or 15 at `T = 5`) depends on the open decision
  in section 3.4. Consequently: **the choice of compute target -- Totoro
  versus DRAC -- cannot be settled from this row.** It is downstream of
  (i) section 3.4, (ii) a measured `refits_per_profile`, and (iii) the
  unbuilt compute-admission slice (section 10, item 1), which gates
  execution either way. Nothing in this addendum authorises a campaign or
  chooses an arm.
- **L-b (core grid) -- core-4 confirmatory grid; proposed pilot is a bounded
  subset (resolves Q-b).** The intended confirmatory grid is the core-4 cross
  (section 4.2). The proposed pilot is a deliberately bounded enumeration of
  **48 cells**: core-4 family (4) x latent rank d {1, 2}
  (2) x n_units {50, 150} (2) x signal {0, 0.2, 0.5} (3) = 4 x 2 x 2 x 3
  = 48. This is smaller than the full 192-cell core grid and touches every
  family, rank, sample size, and signal level at least once. It remains a design
  enumeration in `pilot_grid()`, not an authorised fitting campaign.
- **L-c (coverage gate) -- report BOTH 94% and 95%; size to the stricter
  95% (resolves Q-c).** CIs are constructed at 95% nominal
  (`ci_level = 0.95`). Both the 94% audit-1 gate (`M3_PASS_GATE`, the
  existing `passes_94pct_primary`) AND the stricter 95% gate are reported
  per cell. The n_sim FLOOR is sized to adjudicate the stricter 95% gate
  (this is why Phase 2 uses n_sim = 2000, section 7.2). `pilot_status()`
  reports both gates side by side.

  **2026-08-02 addendum --** the gate above is unchanged and both
  thresholds are still reported. Two constraints on its REACHABILITY were
  not visible when it was locked, and neither is a renegotiation of the
  threshold.

  1. **A gate is only reachable if the interval arithmetic can reach it.**
     For the bootstrap arm, coverage cannot exceed `(n_boot-1)/(n_boot+1)`
     whatever the data are (section 8, lever 2). The 95 % half of this row
     is therefore unreachable below `n_boot = 39`, and structurally
     unreachable even for the 94 % half at the M3 production default of
     `n_boot = 25` (ceiling 0.9231). Reporting both gates requires
     `n_boot >= 200` on any claim-bearing cell, plus the
     `coverage_ceiling >= conf` assertion.
  2. **The one certified route is certified at 0.94, not at 0.95.** Route
     P-V's pre-registration fixes the gate at `coverage >= 0.94` and
     explicitly prohibits restating the result as nominal or
     unconditional 95 % coverage; both certified cells sit roughly 3.3
     clustered SEs below 0.95 (section 3.2, fence 4). So if section 3.4
     resolves toward P-V, this row's 95 % column remains a **reported
     descriptive number** and must not be read as a gate that route has
     ever cleared. Nothing here relaxes the 94 % gate or tightens it.
- **L-d (n_sim target) -- pilot ~= 200, core = 2000 (resolves Q-d; folded
  into L-a).** The proposed pilot uses `n_sim ~= 200` for sizing; the intended
  core uses `n_sim = 2000` for gate adjudication at MCSE < 0.5 pp. The
  minimum-defensible 1000 is not used for the headline grid. These counts do
  not themselves authorise execution.
- **L-e (coevolution / Gamma) -- DEFERRED (resolves Q-e).** Design 65 /
  #361 (`kernel_*()`, Gamma coevolution) is OUT of scope for this
  capstone. The `kernel_*()` engine is not built on origin/main; the
  Gamma estimand and the Tier-3 coevolution grid (section 4.5) are a
  follow-up study, not part of the core-4 confirmatory campaign. The
  grid schema reserves the slot but no Gamma cells are run here.

  **2026-08-02 addendum --** the premise above is factually dead: the
  `kernel_*()` engine is built, exported (`kernel_dep`, `kernel_indep`,
  `kernel_latent`, `kernel_scalar`, `kernel_unique`; `NAMESPACE`), and
  tested (register KER-01/02/03, all `covered`, named test files
  `test-kernel-latent-unique-fold.R`, `test-kernel-equivalence.R`,
  `test-coevolution-two-kernel.R`, `test-coevolution-prototype.R`).
  Deferring Tier 3 out of the core-4 confirmatory campaign may still be
  the right call, but on budget grounds, not engine availability. This is
  not a re-decision by this patch -- L-e stays DEFERRED as locked, and the
  text above is retained verbatim and unedited. It is flagged for
  Shinichi to re-decide on its merits (audit
  `docs/dev-log/audits/2026-08-02-design66-staleness-audit.md`, finding
  S-4).
- **L-f (families) -- core 4 (resolves Q-f).** The confirmatory grid is
  the 4-family representative subset: gaussian, nbinom2,
  binomial(probit), ordinal_probit. All-14-families and mixed-family
  (CI-10) are the Tier-1 family-completion EXTENSION (section 4.3), not
  the core. nbinom1 (FAM-07) stays out (review-branch-wired).

  *Pilot harness note (binomial link).* The current `m3_run_cell`
  harness has a true `binomial_probit` path: the DGP uses `pnorm()` and
  the fit uses `stats::binomial(link = "probit")`. Older Phase-1 pilot
  artifacts, including the first Fir scheduled smoke jobs recorded on
  2026-06-24, used the existing binary LOGIT harness behind
  `binomial_probit` cell IDs and saved
  `evidence_family = "binomial_logit_harness"` for traceability. Those
  older artifacts remain scheduler/plumbing evidence only and must not
  be reinterpreted as true binomial-probit validation evidence.

- **L-g (signal parametrization) -- between-unit variance share; levels
  0 / 0.2 / 0.5 (resolves Q-g).** "Signal" is operationalized as the
  **between-unit (latent) variance share of total latent variance**:
  `share = trace(Lambda Lambda^T) / (trace(Lambda Lambda^T) + trace(Psi))`
  per trait, in expectation. The three levels are **0.0 (signal-zero
  coverage diagnostic for the positive `Sigma_unit_diag` target, not
  Type-I error), 0.2 (moderate), 0.5 (strong)**. In the
  M3 DGP this maps to `lambda_scale` via
  `lambda_scale = sqrt( (s/(1-s)) / (d * 0.75) )` (derivation in
  `dev/m3-pilot-launch.R::pilot_signal_to_lambda_scale`), holding the
  share constant across d. The null (s = 0) collapses to a tiny
  `lambda_scale` floor (1e-6; the harness rejects `lambda_scale <= 0`),
  making `Lambda Lambda^T ~= 0` so the between-unit signal is effectively
  absent -- the H4 null cell. This gives the power curve an interpretable
  x-axis (a variance share, not an opaque loading scale).

### 12.1 Historical pilot primitives and current smoke boundary

`dev/m3-pilot-launch.R` retains the former resumable pilot primitives over
`dev/m3-grid.R`: it reuses `m3_run_cell()` for DGP/estimand/CI machinery and
`m3_summarise()` for per-cell coverage. Current admissible use is deterministic
local inspection and bounded non-claim smoke. The 48-cell fit driver below is
historical/local diagnostic plumbing and must not create new claim-bearing
evidence until the separate compute-admission route passes. Entry points:

- `pilot_grid()` -- the enumerated 48-cell core-4 pilot grid (L-b).
- `run_next_pilot_batch(k, n_sim = 200, results_dir)` -- retained historical/
  local diagnostic driver that runs pending cells and updates the legacy index.
  Its idempotence and fail-soft behavior preserve old stores, but it is not an
  admitted local, Totoro, or DRAC evidence route.
- `pilot_status(results_dir)` -- summarizes done / pending / failed and
  the preliminary 94%/95% coverage (signal > 0) plus the signal-zero
  coverage diagnostic (signal = 0) available so far. The signal-zero
  diagnostic is not a Type-I error or power claim for `Sigma_unit_diag`.
- `pilot_build_manifest()` / `pilot_assert_manifest()` -- record and
  validate the planned per-shard chunks before fitting. The manifest
  catches duplicate output paths, duplicate chunk paths, overlapping
  per-cell replicate windows, and overlapping seed ranges before the
  store is persisted or summarized.
- `pilot_audit_mini_cell_ids()` / `dev/power-pilot-run.R
  --mode=audit-mini` -- write a manifest-only four-cell smoke for
  gaussian, nbinom2, true `binomial_probit`, and ordinal-probit. It
  uses the moderate `d = 1`, `n_units = 50`, `signal = 0.2` row for
  each family, plans two chunk reps with `n_boot = 0` by default, and
  launches no fits. This is the audit-mini gate before broader local or
  DRAC volume; it is still smoke evidence until the corrected harness is
  rerun at the intended replication depth.
- `pilot_run_audit_mini_manifest()` / `dev/power-pilot-run.R
  --mode=audit-mini-run` -- run the same fixed four-cell manifest as
  immutable chunk outputs, with `n_boot = 0` by default. Use this only
  as a tiny local execution smoke after the manifest-only gate; it still
  does not mutate `pilot-index.rds`, submit DRAC/SLURM work, or start a
  production campaign.
- `dev/power-pilot-smoke.sh` -- wrap the audit-mini ladder in one
  shell entry point for humans and future job scripts. The default
  `SMOKE_STAGE=all` path runs a one-rep, no-bootstrap local/Totoro
  smoke through manifest, immutable chunk writing, chunk audit, chunk
  aggregation, and chunk-aggregate reporting. `SMOKE_STAGE=manifest` is
  the DRAC-login-safe step: it parses and validates the fixed four-cell
  manifest but launches no fits. Fit-running stages (`run` and `all`)
  are for local/Totoro or scheduled compute jobs, not DRAC login nodes.
  The wrapper sets `OMP_NUM_THREADS`, `OPENBLAS_NUM_THREADS`, and
  `MKL_NUM_THREADS` to 1 by default and still does not submit SLURM
  work, use GPUs, mutate `pilot-index.rds`, or start the production
  campaign.
- `dev/power-pilot-drac-setup.sh` -- login-node setup for the first
  DRAC/fir smoke checkout. It loads the selected R and Julia modules,
  creates a version-pinned user R library, installs the current checkout
  with Depends/Imports/LinkingTo dependencies, and verifies
  `gllvmTMB` is visible from `.libPaths()`. `DRAC_EXTRA_MODULES` carries
  cluster-specific system libraries such as udunits/GDAL/GEOS/PROJ when
  `fmesher`/`sf` need them. It submits no jobs and records no private
  allocation/account path in the repository.
- `dev/power-pilot-slurm-smoke.sh` -- write, validate, or submit a
  conservative SLURM wrapper around `dev/power-pilot-smoke.sh`. The
  default `SLURM_ACTION=test` calls `sbatch --test-only`; actual
  submission requires `SLURM_ACTION=submit`. The default
  `SLURM_STAGE=manifest` is the first DRAC-safe smoke and launches no
  fits. Fit-running stages such as `SLURM_STAGE=all` are only for
  scheduled compute jobs after the manifest smoke passes. The wrapper is
  CPU-only, loads R and Julia modules explicitly, prepends the prepared
  user R library, checks that `gllvmTMB` is installed before running the
  smoke, sets BLAS/OpenMP threads to one, and does not start the
  production `n_sim = 2000` campaign.

  Fir scheduled smoke evidence (2026-06-24, source
  `7c675dd33d58f4dfd633cacfbf05e62c0e168d61`) now covers the first two
  CPU-only scheduled fit steps after the manifest-only gate. Job
  `45626865` ran `SLURM_STAGE=all`, `N_SIM_STEP=1`, `N_SIM_CAP=1`,
  `N_BOOT=0` against
  `$SCRATCH/gllvmtmb-power-pilot-smoke-fit-nboot0-20260624T164759Z`;
  it completed with exit code 0, four active manifest rows, four chunk
  files, four aggregate files, and no `pilot-index.rds`. Job `45627388`
  repeated the same ladder with `N_BOOT=2` against
  `$SCRATCH/gllvmtmb-power-pilot-smoke-fit-nboot2-20260624T165402Z`;
  it also completed with exit code 0 and the same immutable artifact
  shape. This is reproducibility / scheduler plumbing evidence only:
  these jobs pre-date the true probit harness swap, so their
  `binomial_probit` cell remains labelled by `binomial_logit_harness`;
  the `N_BOOT=2` report flagged non-PD diagnostics for the binomial and
  nbinom2 cells, ordinal-probit still lacked a primary interval row, and
  `CI-08` / `CI-10` remain partial.
- `pilot_run_chunk_manifest()` / `dev/power-pilot-run.R --mode=chunk`
  -- run the active rows from a chunk manifest, reindex each chunk's
  `rep` column into the planned per-cell window, add chunk provenance
  fields, and write one immutable RDS file per planned chunk. This is
  the future array-task writer; it does not update `pilot-index.rds` or
  combine chunks.
- `pilot_assert_chunk_outputs()` / `dev/power-pilot-run.R
  --mode=chunk-audit` -- validate the future immutable-chunk output
  set after array tasks finish and before aggregation. This requires
  every planned active chunk file to exist and be non-empty; it does
  not launch fits and does not replace the current accumulated-store
  driver.
- `pilot_collect_chunk_aggregates()` / `dev/m3-pilot-report.R
  --emit-issues --chunk-aggregate` -- read the per-cell RDS files
  written under `_chunk-aggregate/` after immutable chunks have been
  validated and aggregated. This is an explicit report source, not an
  automatic scan, so legacy accumulated stores and derived chunk
  aggregates cannot be double-counted by accident. It reuses the same
  MCSE, denominator, fit-health, and evidence-label reducer as
  `pilot_collect()`, and still does not mutate `pilot-index.rds`.
- For manifest-only compute smoke tests, `dev/power-pilot-run.R
  --mode=preflight --output-mode=chunk` validates the future immutable
  chunk destinations without launching fits.

Phase 2 (HPC, n_sim = 2000, the full core grid) will require a reviewed
cluster array-job driver and frozen compute-admission bundle (section 9). The
current pilot primitives and results schema are inputs to that future driver;
they are not themselves an admitted production harness.
