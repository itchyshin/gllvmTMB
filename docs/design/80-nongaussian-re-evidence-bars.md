# Design 80 — Evidence bars for non-Gaussian random-effect arcs (cross-team)

**Status:** methods note (2026-07-12). Cross-team: applies to **drmTMB Arc 2a**
(mu random intercept for the non-Gaussian families, 0.6.0) *and* **gllvmTMB's
random-effect / REML arc**. Source: the drmTMB team's NotebookLM synthesis
(notebook `7742e05e…`, librarian Ranganathan, 2026-07-12).

**Provenance caveat (read first).** The synthesis is **triage, not authority**:
its auto-added web sources and the auto-generated TMB technical report are
**secondary / UNVERIFIED**. Load-bearing *identifiability* claims (ordinal
thresholds-as-intercepts; skew-normal centred parameterisation) are corroborated
by named primary sources (glmmTMB docs, `ordinal`/`clmm`, Azzalini `sn`) →
firm enough to design against, but **verify against those primaries before
locking a parameterisation.** Numeric details (n^(−1/6) rate, "7–25 AGHQ nodes")
are report-only → indicative, do not cite.

## The three bars

The literature forces a separation that these arcs should lean on, not fight.
For a random-effect estimate under ML-Laplace:

| Bar | What it certifies | Belongs to |
|---|---|---|
| **1 — Identifiability / parameterisation** | the model is well-posed; the aliased form is rejected; **fixed effects recover** | **the RE arc (Arc 2a) — non-negotiable** |
| **2 — Point recovery of σ_u² at an *adequate* cluster regime** | σ_u² recovers where Laplace is known adequate; small-cluster **downward bias documented** as a known limitation | **the RE arc (Arc 2a) — weak version** |
| **3 — Calibrated / unbiased variance component across regimes (incl. small n)** | σ_u² is unbiased/calibrated even at small cluster n | **the REML/AGHQ arc (drmTMB Arc 1) — NOT the RE arc** |

**Bar assignment:** the RE arc (Arc 2a) hits **Bar 1 + Bar 2**. It does **not**
claim Bar 3 — "unbiased variance component" structurally requires REML
(integrated-likelihood Laplace, `glmmTMB REML=TRUE`) and/or AGHQ, which is a
different, harder arc. Gating the RE arc on Bar 3 conflates two arcs and would
fail an estimator on a property it cannot have.

This mirrors gllvmTMB's existing honesty contract — every family's interval
evidence is "point-only, no coverage certificate" — and the sample-size-first
rule (never condemn an estimator on one small-n cell; run the n-ladder).

## Per-family Bar-1 gates (identifiability)

- **Ordinal cumulative-logit — the hard gate.** No fixed `mu` intercept; free
  all K−1 thresholds; mean-zero RE. A fixed intercept *and* free thresholds is
  flatly non-identifiable (the thresholds *are* the intercepts). Do **not** reuse
  the generic `mu ~ 1 + (1|g)` plumbing unchanged. (This is exactly why
  gllvmTMB's ordinal random effects are currently *not implemented*.)
- **Skew-normal.** RE on the **mean** (centred parameterisation), not the
  location ξ (direct) — else the intercept aliases skewness α
  (E[Y] = ξ + ωδ√(2/π)). Guard the α→0 singular-information case (bound α /
  mild penalty / flag near-boundary SEs).
- **Tweedie.** Ship a first-class **`p`-fix** escape hatch (mirror glmmTMB's
  `map`): the σ_u²↔p↔φ ridge is flat with few clusters. Provide GLM-pilot
  starts.
- **Binomial logit.** Standard; fixed effects well-behaved. Document the RE-SD
  **downward bias** under Laplace at few/small clusters; an AGHQ check is
  feasible for a single scalar RE.

## Bridge diagnostic (cheap, ship in the RE arc)

Report the **ML-vs-REML gap** as a per-fit health signal even in a Laplace-only
RE arc: a large gap flags the small-cluster regime where σ_u² is untrustworthy —
turning "we know it's biased" into an automatic warning, and the natural hook for
the REML arc later. REML likelihoods are **not** comparable across fixed-effect
structures → default to ML for such LRTs; block/warn on cross-fixed-effect LRTs
if a REML toggle ships.

## Related

drmTMB Arc 2a (0.6.0) · drmTMB Arc 1 (REML) · gllvmTMB REML pilot (Gaussian-only)
· Design 79 (covariance-mode taxonomy) · the sample-size-first / point-only
honesty lines.
