# Design 120 — the multi-source integrated-SDM contract (Model 2)

**Status: ACTIVE / PARTIAL.** The public constructor and contract are shipped;
the 2026-08-29 requalification programme still owes weak-overlap and spatial
recovery evidence. Companion register row: `ISDM-02`. Umbrella issue: #941.

## 1. What this is

The generalisation of the two-source integrated model to **any number of named
observation sources**, each with its own observation law, all sharing one ecological
process:

```
eta_eco[i,j]     = alpha[j] + x[i]' beta[j] + u[i]' lambda[j]        (shared)
eta_obs[i,j,d]   = gamma[d,j]                                         (per source)
```

with `d = 1..D` sources, reference coding `gamma[1,j] = 0` (#941's stated default),
known per-row support `a[i,d]` entering as `offset(log_support)`, and per-row
observation law selected by source:

```
count arm:   Y[i,j,d] ~ Poisson( a[i,d] * exp(eta_eco + eta_obs) )
PA arm:      Y[i,j,d] ~ Bernoulli( 1 - exp(-a[i,d] * exp(eta_eco + eta_obs)) )
```

**This is an R-contract generalisation, not an engine change.** Verified during
planning: `"gbif"` and `"survey"` appear nowhere in `src/gllvmTMB.cpp`;
`family_id_vec`/`link_id_vec` are per-row; #942 (closed) established that any number
of rows per `(cell, species)` share one `eta_eco` through the unit/cluster index. Two
probes confirmed it empirically: three all-Poisson sources fit today unchanged
(`pd_hessian = PASS`, per-source effects recovered), and three mixed-law sources fit
the moment the data are relabelled into the two-source vocabulary — the only barrier
is the admission predicate's hard-coded `gbif`/`survey_pa` names.

## 2. The n-arm coherence derivation (Gauss's question, answered)

The concern: the thinned-Poisson argument that licenses mixing Poisson-log with
Bernoulli-cloglog was verified at two arms. Does it survive `D > 2`?

**Yes, because it was never a pairwise argument.** Conditional on the shared latent
field `u`, the rows factorise: each row's density involves only that row's `eta`, and
there is no cross-arm term anywhere in the template. (Stated carefully, because the
template is not literally a flat per-row sum: the AGHQ branch aggregates per unit, the
`mi()` machinery sums per unit, and the multinomial family is evaluated per group at an
anchor row — but each of these is an exact marginalisation or regrouping of the
conditionally-independent product, and none introduces a term coupling two arms beyond
their shared `eta`.) So coherence is an **arm-by-arm property against the shared
intensity**, checked once per arm:

- A **Poisson-log** arm asserts `log E[Y] = eta + log a` — the arm observes the
  intensity `exp(eta)` thinned by its own known support `a`. Coherent by definition
  of the model.
- A **Bernoulli-cloglog** arm asserts `p = 1 - exp(-a·exp(eta)) = P(N > 0)` for
  `N ~ Poisson(a·exp(eta))` — the arm observes whether its own Poisson thinning of
  the *same* intensity is non-zero. `cloglog(p) = eta + log a`; same scale, same
  interpretation of the offset as change-of-support.

Adding a third, fourth, … arm adds more independent observations of the same
`exp(eta)`, each individually coherent. Nothing about arm `d` conditions on arm
`d'`. The admitted-law criterion is therefore **per-arm**: *the arm's inverse link
must express its mean as a function of `a·exp(eta)`* — true of Poisson-log and
Bernoulli-cloglog, false of binomial-logit/probit (logit is not a log-intensity
transformation; #945's original refusal reasoning), false of every
dispersion-carrying family (per-trait nuisance ambiguity, #945 wrinkle 1).

**Consequence:** the admitted law set at `D` arms is exactly the admitted set at 2
arms — `{Poisson-log, Bernoulli-cloglog}`. Two qualifications keep this honest:

- **All-PA is refused at construction, not admitted.** The arms of an all-detection
  declaration are mutually coherent by the argument above, but the cloglog
  change-of-support offset is currently admitted only inside the mixed contract, so an
  all-PA fit cannot be expressed; `isdm_sources()` refuses it where the user can see
  why rather than letting the offset gate kill it downstream with an error about
  Poisson. An all-detection multi-survey route is deferred scope, not a coherence
  failure. (All-count is the opposite case: no relaxation needed, ordinary route.)
- **This bounds the admitted LAW SET, not estimator quality.** The Laplace
  approximation's accuracy is not arm-count-invariant even though the model is:
  sparse Bernoulli arms degrade the Gaussian-curvature approximation in a way count
  arms do not. The campaign's 95% `pd_hessian` rate is evidence on exactly this axis
  and should be read as a rate, not a guarantee.

## 3. Identifiability at D arms (Fisher's question, and what the recovery study must test)

With reference coding `gamma[1,j] = 0`:

- `alpha[j]` absorbs source 1's recording level; `gamma[d,j]` for `d ≥ 2` are
  identified as **relative** recording effects, log-scale, source d vs source 1.
  This generalises the two-source case mechanically.
- **Relative intensity only** remains the estimand (Fithian et al. 2015): no arm
  identifies absolute abundance, occupancy, or detectability. More PO arms buy
  precision on the shared pattern and on the relative biases; they do not break the
  ecology/recording confound. A PA arm anchors the shared field's *pattern* better
  (probe evidence at n=2), not its absolute level.
- The open empirical question is **conditioning, not identification**: with several
  near-collinear PO arms (similar spatial coverage), the relative gammas are
  identified but may be poorly conditioned. This is what the recovery study measures
  (§6) — per-source `gamma[d,j]` recovery and the Hessian's PD rate as arms are
  added, not just point error.

## 4. The public interface

```r
fam <- isdm_sources(
  gbif = isdm_source(poisson(), observation = ~ access + popdens),
  literature = isdm_source(poisson(), observation = ~ access + popdens),
  survey = isdm_source(poisson(), observation = ~ observer + method)
)
fit <- gllvmTMB(
  value ~ 0 + trait + trait:env + offset(log_support) +
    latent(0 + trait | cell_id, d = 1),
  data = dat, trait = "trait", unit = "cell_id", family = fam
)
```

`isdm_sources(...)` is a small **exported constructor**:

- takes ≥ 2 named arguments, each a `family` object from the admitted set;
- returns the ordinary mixed-family list the engine already consumes, with
  `attr(., "family_var") = "isdm_source"`. (An `isdm_source_laws` attribute records
  the map for inspection but is informational only — validation rebuilds the
  declaration from the list's names and laws, which survive the reordering that
  strips attributes.);
- the data must carry an `isdm_source` column whose values are exactly the declared
  names. The user's `source`/`src` column for the formula is their own business —
  the *selector* column is the contract surface.

The predicate then validates a **declared** contract instead of pattern-matching two
magic strings. Declaration-first is what makes the admission auditable at any `n`.

`isdm_source(family, observation = ~ ...)` is the optional per-source wrapper.
It evaluates its one-sided formula after row filtering for that source and masks
the resulting columns to zero outside that source. Any admitted source law may
use ordinary R formula syntax such as `~ access + popdens` or
`~ observer + method`; users do **not** need to remember `0 +` for a survey.
Where source intercept or factor-level contrasts are aliased with the
ecological `0 + trait` intercepts, the observation design automatically uses
deterministic reference coding and retains only linearly independent source
columns. Bare
`poisson()` / `binomial("cloglog")` declarations retain their existing behaviour.

## 5. What stays refused (every Model 1 fence generalises; none relaxes)

- any law outside `{Poisson-log, Bernoulli-cloglog}` on any arm — including
  logit/probit and all dispersion-carrying families;
- a trait missing any declared source (the per-trait both-arms rule becomes a
  per-trait **all-declared-sources** rule). Two honest limits of this rule: it checks
  **presence, not balance** — a single row of a source inside a trait satisfies it, as
  it did in the two-source form — but it now checks observed responses rather than row
  presence alone. Under `miss_control(response = "include")`, an all-`NA`
  source-by-trait arm is refused before fitting with
  `gllvmTMB_isdm_observed_source_incomplete`; this applies to mixed-law and
  all-Poisson declarations made with `isdm_sources()`;
- an `isdm_source` value not in the declaration, or a declared source absent from
  the data;
- `weights` (two incompatible meanings across arms — Gauss blocker, unchanged);
- multi-trial rows on any PA arm (the thinned-Poisson argument is per single trial
  of support `a`; visits are separate rows);
- nonzero offsets on any family outside the admitted set (unchanged).

**Backward compatibility is a contract, not an aspiration:** the existing
`list(gbif = poisson(), survey_pa = binomial("cloglog"))` + `isdm_family` route must
keep working byte-for-byte (same objective, same parameters), asserted by test. The
old route is internally recognised as the `n = 2` instance of the new predicate —
one code path, one definition of admission.

## 6. Recovery study (ADEMP sketch; full protocol with the campaign)

- **Aims:** per-source `gamma[d,j]` recovery and conditioning as arms are added.
- **DGP:** the §1 model; `n_sources ∈ {2, 3, 4}`; law mixes {all-PO, PO+PA,
  2PO+PA, 3PO+PA}; effort ratios across sources varied one order of magnitude.
- **Estimand:** relative `gamma[d,j]` (log scale), shared `beta[j]`, `Lambda` at the
  same rotation-safe summaries the existing campaigns use.
- **Methods:** the public route, nonspatial `latent(d = 1)` (the arm with cleared
  Design 111 gates); spatial deferred to its own campaign.
- **Performance:** bias/RMSE per gamma; `pd_hessian` PASS rate per cell; convergence.
- **Compute:** Totoro, ≤150 cores, D-139 discipline — estimate + pre-run test first;
  a full grid whose priced wall-clock exceeds 30 minutes additionally needs maintainer
  approval, and one under it runs on the receipt alone (D-139's own rule). The
  realised campaign priced at ~1–2 minutes wall on 100 cores and ran on the receipt.

## 7. Explicitly out of scope (deferred, not forgotten)

- **Per-source bias covariates** `w[i,d]' delta[d,j]` — expressible today by hand
  (structurally-zero interaction columns, as article 1 does for one source);
  ergonomics + validation is the follow-on arc.
- **#944 weighted joint likelihood** — `D` weights on a simplex is its own design
  problem, unresolved even at `D = 2`.
- **Calibrated intervals** for any of this.
- **Spatial multi-source recovery** — runtime-admitted (the spatial gates thread
  through the same predicate) but evidence-deferred, as for Model 1.
