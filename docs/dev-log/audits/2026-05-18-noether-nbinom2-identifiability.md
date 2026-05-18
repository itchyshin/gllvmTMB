# Noether identifiability audit: nbinom2 latent-vs-dispersion confounding at small n

**Date**: 2026-05-18
**Lead persona**: Noether (mathematical consistency / identifiability)
**Reviewers**: Fisher (inference), Gauss (TMB likelihood), Curie
(simulator target alignment), Rose (scope honesty).
**Triggered by**: M3.3a smoke surfaced 0.38 average coverage on
nbinom2 cells. Maintainer 2026-05-18 caution: "do glmmTMB +
drmTMB have these working?". Cross-package scout audit (PR #177)
ruled out gllvmTMB-specific bugs in cutpoint anchoring,
phi parameterisation, and CI machinery. **Question remaining**:
is the simulator's `truth$psi[t]` aligned with the fit's
identifiable target for nbinom2?

## 1. The simulator (`dev/m3-grid.R`)

For an nbinom2 cell, the per-replicate DGP is:

$$
\eta_{ut} = \mathbf z_u^\top \boldsymbol\lambda_t + e_{ut},
\quad e_{ut} \sim \mathcal{N}(0, \psi_t)
$$

$$
y_{ut} \sim \mathrm{NegBin2}\bigl(\mu = \exp(\eta_{ut}),\ \mathrm{size} = \phi_t\bigr)
$$

with:
- $\boldsymbol\lambda_t$ = row $t$ of $\boldsymbol\Lambda$
  (rotation-ambiguous loadings; not the inference target)
- $\psi_t$ = `truth$psi[t]` (per-trait unique-tier variance on
  the latent scale, the inference target)
- $\phi_t$ = `truth$phi` (per-trait or shared NB dispersion)

## 2. The fit (gllvmTMB nbinom2)

The fitted model (from `R/fit-multi.R` + `src/gllvmTMB.cpp:280-282`):

$$
\eta_{ut} = \alpha_t + \mathbf z_u^\top \boldsymbol\lambda_t + e_{ut},
\quad e_{ut} \sim \mathcal{N}(0, \mathrm{sd\_B}_t^2)
$$

$$
y_{ut} \sim \mathrm{NegBin2}\bigl(\mu = \exp(\eta_{ut}),\ \mathrm{size} = \exp(\mathrm{log\_phi\_nbinom2}_t)\bigr)
$$

Engine estimates per trait:
- $\alpha_t$ (fixed-effect intercept; `b_fix`)
- $\boldsymbol\lambda_t$ (loadings; rotation-ambiguous)
- $\mathrm{sd\_B}_t$ (estimates $\sqrt{\psi_t}$ on the latent scale)
- $\mathrm{log\_phi\_nbinom2}_t$ (estimates $\log\phi_t$)

**Conclusion 1**: the simulator's `truth$psi[t]` corresponds
exactly to the engine's `sd_B[t]^2`. The profile-CI target
in M3.3a — `tmbprofile_wrapper(name = "theta_diag_B", which =
t, transform = exp(2x))` — gives a CI on `sd_B[t]^2`, i.e.,
$\psi_t$. **Target alignment confirmed.**

## 3. The identifiability question

Both $\psi_t$ and $\phi_t$ contribute to observed-y
overdispersion. The marginal mean and variance of $y_{ut}$
(integrating out $e_{ut}$) are:

$$
\mathbb{E}[y_{ut}] = \exp(\alpha_t + \tfrac{1}{2}\psi_t) \cdot
\exp(\mathbf z_u^\top \boldsymbol\lambda_t \text{ contributions})
$$

$$
\mathrm{Var}(y_{ut}) =
\mathbb{E}[y_{ut}] \cdot \bigl(1 + \mathbb{E}[y_{ut}]/\phi_t\bigr)
\cdot e^{\psi_t}
+ \mathbb{E}[y_{ut}]^2 \cdot (e^{\psi_t} - 1)
$$

(Standard log-Normal-NB mixture variance; see e.g. Lawless 1987.)

**Both $\psi_t$ and $\phi_t$ inflate $\mathrm{Var}(y_{ut})$.** At
small $n$ the likelihood is **flat in a direction** where
$\psi_t$ and $\phi_t$ trade off — the observed counts can be
explained equally well by a small psi + large phi OR by a large
psi + small phi. The trade-off is one-dimensional, not strictly
non-identified — the marginal moments are different functions
of $(\psi, \phi)$ — but the **information matrix is
ill-conditioned** along the trade-off axis at small $n$.

**Conclusion 2**: $\psi_t$ and $\phi_t$ are **weakly identified
at small $n$**, not non-identified. Profile CIs are correctly
computed but **wide and skewed near the trade-off boundary**.

## 4. What this means for M3.3a coverage

- The 0.38 coverage on nbinom2 cells is NOT a profile-CI bug.
- The coverage shortfall comes from CIs that are correctly
  computed but systematically miss the truth because the
  optimizer drifted along the $(\psi, \phi)$ trade-off — e.g.,
  if the optimizer landed at small phi (overdispersion absorbed
  into phi), then sd_B estimate is biased low, and the profile
  CI centered on this biased estimate misses the true psi.
- At larger $n$ (or with multiple replicates of the same
  individual to break the latent-vs-dispersion symmetry), the
  trade-off becomes informative and coverage approaches
  nominal.

## 5. Implications for M3.4 fix design

Three orthogonal mitigations rank by expected impact:

| # | Mitigation | Why it helps | Expected coverage improvement |
|---|---|---|---|
| **A** | **Single-trait warm-start** (per gllvm `start.fit=` + Design 43 Tier A #4) — fit each trait univariately first, use estimated $(\alpha_t, \mathrm{sd\_B}_t, \phi_t)$ as inits for the multivariate fit | Univariate fits have fewer parameters competing for variance signal; the warm-start lands the multivariate optimizer near a good local mode rather than walking the $(\psi, \phi)$ trade-off | **Large** (Tier A; addresses the root cause for many DGPs) |
| **B** | **Phi starting-value clamp $[0.01, 100]$** (per gllvm pattern) | Avoids pathological random inits where phi starts at numerical infinity or zero; engine still optimizes unconstrained | **Small** (defensive; addresses tail cases only) |
| **C** | **disp_group= shared phi across traits** (per gllvm pattern) | Reduces per-trait phi (5 free) to shared phi (1 free) when T=5; restores identifiability if traits share dispersion regime | **Medium** (specific to the per-trait phi over-parameterization at T=5) |

Mitigations A + B can land together in M3.4. Mitigation C is a
deliberate API choice (shared vs per-trait phi); should be
optional with sensible default.

## 6. What this audit does NOT claim

- **Does not claim** the coverage will reach 0.95 after M3.4.
  Small-n likelihood pathology is inherent; the audit-1 gate is
  >=0.94 which may not be hit at n=60, T=5, R=10 even with
  warm-start. At R=200 (production) and n=120 (a smoke at 2x
  units), coverage should improve substantially but might not
  hit gate.
- **Does not propose** a Bayesian prior on phi to regularize.
  That's an opinionated decision; v0.3.0 work.
- **Does not propose** changing the per-trait phi
  parameterization. Per-trait phi is correct for the family-aware
  design; sharing via disp_group is the right API surface, not
  default behaviour.

## 7. Cross-references

- Scout audit: `docs/dev-log/audits/2026-05-18-cross-package-count-inference-scout.md`
- Design 43: ASReml speed techniques (single-trait warmup as
  Tier A #4 borrowable pattern from gllvm)
- M3.3a after-task: `docs/dev-log/after-task/2026-05-18-m3-3a-profile-primary.md`
- M3 DGP grid spec: `docs/design/42-m3-dgp-grid.md`

## 8. Persona contributions

- **Noether** (lead): mathematical verification of simulator
  target alignment (§2) + identifiability of $(\psi, \phi)$
  trade-off (§3).
- **Fisher** (review): coverage implications (§4); ranking of
  mitigations by expected impact (§5).
- **Gauss** (review): TMB-side parameterization verified
  (`src/gllvmTMB.cpp:280-282` exposes `log_phi_nbinom2` per
  trait, unbounded log scale — matches §2 derivation).
- **Curie** (review, simulator alignment): `truth$psi[t]`
  corresponds to `sd_B[t]^2`; confirmed in M3.3a smoke output
  where `est_psi = fit$report$sd_B[t]^2` matches the profile-
  CI target.
- **Rose** (review, scope honesty): §6 enumerates what the
  audit does NOT claim; no overpromise that M3.4 fixes the gate.

## 9. Next actions

- **N1**: Design 48 (M3.4 strategy) drafts mitigations A + B,
  with explicit no-overpromise on coverage gate.
- **N2**: Implementation PR (M3.4 follow-on) ships phi-clamp +
  single-trait warm-start. Tests re-run M3.3a smoke and report
  before/after coverage tables.
- **N3**: If post-M3.4 coverage still under-covers, Design 49
  considers mitigation C (disp_group=) or larger-n smoke at
  n=120.
