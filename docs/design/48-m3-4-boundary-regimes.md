# Design 48 — M3.4 boundary regimes: warm-start + phi-clamp

**Maintained by**: Fisher (validation design) + Boole (R API)
+ Gauss (TMB-side numerical). **Active reviewers**: Curie (test
fidelity), Noether (identifiability — see audit
`2026-05-18-noether-nbinom2-identifiability.md`), Pat (user-
facing control surface), Rose (scope honesty), Ada (coordinator).
**Status**: Active — Phase M3.4 strategy doc. Implementation in
follow-on PR per two-PR pattern.
**Backed by**:
- Noether identifiability audit
  (`docs/dev-log/audits/2026-05-18-noether-nbinom2-identifiability.md`)
- Cross-package scout audit
  (`docs/dev-log/audits/2026-05-18-cross-package-count-inference-scout.md`)
- Design 43 §4 #4 (single-trait warmup as Tier A borrowable from
  gllvm)

## 1. The problem M3.4 solves

M3.3a smoke (PR #176, 15 cells × 10 reps × 5 traits with profile
CIs) surfaced **systematic under-coverage on count + ordinal +
mixed cells** at the smoke scale:

| Family | Avg coverage |
|---|---|
| Gaussian / binomial | ≈ 0.95 (near nominal) |
| ordinal-probit | 0.75 |
| Mixed | 0.64 |
| **nbinom2** | **0.38 (worst)** |

Per the Noether audit: nbinom2 under-coverage is caused by the
**$(\psi_t, \phi_t)$ trade-off** at small $n$ — the marginal
observed-y variance can be explained equivalently by latent
variance or NB dispersion, and the optimizer drifts along the
trade-off axis.

Per the scout audit: **no package warm-starts counts**
(glmmTMB, drmTMB, gllvm, galamm all start from default values);
gllvm has the only documented user-facing warm-start API
(`start.fit=` + vignette pattern "fit Poisson, pass to NB").
gllvm also has a phi starting-value clamp `[0.01, 100]`.

## 2. The fix design (two mitigations)

### Mitigation A — Single-trait warm-start

Per gllvm pattern (`gllvm.TMB:381-412` + vignette1): fit each
trait **univariately** first, then use the per-trait estimates
as **starting values** for the multivariate fit.

**Why it helps**: univariate fits have fewer parameters
competing for the variance signal. The univariate $(\hat\alpha_t,
\hat\psi_t, \hat\phi_t)$ are near-unbiased on a per-trait basis
because there's no rotation-ambiguous Lambda to absorb signal.
Using these as starting values lands the multivariate optimizer
near a good local mode rather than walking the
$(\psi, \phi)$ trade-off axis.

**User-facing API** (Boole lead):

```r
gllvmTMB(value ~ ... + latent(...) + unique(...),
         data = df,
         family = nbinom2(),
         control = gllvmTMBcontrol(
           init_strategy = "single_trait_warmup"
         ))
```

Default `init_strategy = "default"` keeps current behaviour.

**Implementation sketch** (Boole + Gauss):

1. Parse the multivariate formula. Identify the trait factor.
2. For each trait level, construct a univariate formula by
   subsetting + dropping `latent()` / `unique()`.
3. Fit each univariate model (parallel via future if available).
4. Extract per-trait starts: `b_fix[t]`, `log_phi_nbinom2[t]`,
   `theta_diag_B[t]` (= log SD of unique-tier per-trait
   variance).
5. Assemble into the multivariate parameter vector with
   `Lambda_B_packed = 0` (default) and `theta_rr_B = 0`
   (default).
6. Pass as `par_init` to the multivariate optimizer.

**Out of scope for M3.4**: cluster + interactions in the
univariate fit (those don't apply; only the per-trait fixed
effects matter as warm-starts).

### Mitigation B — Phi starting-value clamp `[0.01, 100]`

Per gllvm pattern (`gllvm.TMB:599-602`): when a count family is
used (nbinom1, nbinom2, truncated_nbinom1/2, beta_binomial),
clamp the **initial value** of `log_phi_*` to a reasonable
range.

**Why it helps**: avoids pathological random inits where phi
starts at numerical infinity (-> Poisson limit, sd_B picks up
all overdispersion) or numerical zero (-> NB likelihood
near-uniform, optimizer wanders).

**Implementation sketch** (Gauss):

In `R/fit-multi.R` initial parameter assignment (line
~1300-1500, exact location TBD when implementing), for any
`log_phi_*` parameter, replace the default zero init with
`pmax(pmin(default_init, log(100)), log(0.01))` so initial phi
∈ [0.01, 100]. The OPTIMIZER remains unconstrained; only the
starting value is clamped.

No new user-facing argument needed — this is purely a sensible
default.

## 3. Scope of the M3.4 implementation PR

In a SEPARATE follow-on PR (not this design PR):

| Step | Lead | Output |
|---|---|---|
| **S1** — Add `init_strategy` arg to `gllvmTMBcontrol()` | Boole | API surface |
| **S2** — Implement single-trait warmup loop in `R/fit-multi.R` | Boole + Gauss | ~200 LOC |
| **S3** — Add phi starting-value clamp in `R/fit-multi.R` | Gauss | ~30 LOC |
| **S4** — Test: warm-start vs default on the M3.2c fixture; assert convergence rate ↑, runtime ↑ (acceptable trade-off), no Gaussian regression | Curie | ~150 LOC test |
| **S5** — Re-run M3.3a smoke under warm-start; refresh `inst/extdata/m3-coverage-grid-smoke.rds`; update article | Curie + Pat | smoke rerun |
| **S6** — Validation-debt register: ANI / M3 rows updated with `partial` + before/after table | Rose | register edits |
| **S7** — After-task report | Ada | §3a Decisions block per Memory-OS upgrade |

Est: ~1 day total work + ~30 min smoke compute.

## 4. Honest scope — what M3.4 will NOT achieve

Per the Noether audit §6:

- **Will not guarantee >= 94% coverage at smoke scale (R=10).**
  Monte Carlo error is ±15 pp; even if true coverage is exactly
  nominal, the smoke estimate at R=10 could read anywhere in
  $[0.80, 1.00]$. M3.3 production at R=200 is needed for ±3 pp
  precision.
- **Will not eliminate the $(\psi, \phi)$ trade-off** —
  warm-start helps the optimizer find a good local mode; the
  flat-likelihood direction still exists.
- **Will not address mixed-family $d = \{2, 3\}$ convergence
  drop** beyond what nbinom2 warm-start gives (mixed-family
  fits include nbinom2 rows; helping nbinom2 helps mixed in
  proportion).
- **Will not implement `disp_group=` shared phi** (Mitigation
  C in the Noether audit). That's a deliberate API choice
  needing maintainer ratification; if M3.4 warm-start + clamp
  don't get us to nominal at R=200 production, the follow-on
  PR considers disp_group.

## 5. Expected outcomes after M3.4 (Fisher's prediction)

At smoke (R=10) — likely visible improvement:

| Cell | M3.3a coverage | M3.4 prediction |
|---|---|---|
| Gaussian | 0.95 | ~0.95 (no change; no count family) |
| Binomial | 0.95 | ~0.95 |
| ordinal-probit | 0.75 | ~0.80-0.85 (phi clamp irrelevant; warm-start helps cutpoints find good init) |
| Mixed | 0.64 | ~0.75-0.85 (warm-start helps the nbinom2 traits) |
| nbinom2 | 0.38 | **~0.70-0.85** (largest improvement) |

At production (R=200) — should be statistically tight:

- Gaussian / binomial: ≥ 0.94 (nominal at gate)
- ordinal-probit: ≥ 0.90, likely ≥ 0.94 with warm-start
- Mixed: ≥ 0.85, possibly ≥ 0.94
- nbinom2: ≥ 0.85, possibly ≥ 0.94 — but the
  $(\psi, \phi)$ trade-off at n=60 may keep this below gate;
  Mitigation C (disp_group) would close the rest

If post-M3.4 production at R=200 still under-covers any cell
< 0.90, Design 49 (Mitigation C) activates.

## 6. Cross-references

- Noether audit:
  `docs/dev-log/audits/2026-05-18-noether-nbinom2-identifiability.md`
- Scout audit:
  `docs/dev-log/audits/2026-05-18-cross-package-count-inference-scout.md`
- Design 42 — M3 DGP grid
- Design 43 §4 #4 — single-trait warmup as Tier A borrowable
- Design 44 — M3.3 inference replacement
- M3.3a after-task:
  `docs/dev-log/after-task/2026-05-18-m3-3a-profile-primary.md`
- `R/fit-multi.R` lines ~1300-1500 (initial parameter
  assignment; exact line numbers in implementation PR)
- `R/gllvmTMB.R:649` — `gllvmTMBcontrol()` signature; add
  `init_strategy` arg

## 7. Open questions

- **Q-Boole-1**: should single-trait warmup default to ON for
  count families, or always opt-in?
  - Lean: **opt-in for v0.2.0** (`control = list(init_strategy
    = "single_trait_warmup")`); revisit defaulting in v0.3.0
    after we see production R=200 numbers.
- **Q-Gauss-1**: phi clamp at $\log(0.01)$ ($\phi = 0.01$, near
  Poisson limit) — is this the right lower bound, or should it
  be tighter (e.g. $\phi = 0.1$)?
  - Lean: $[0.01, 100]$ matches gllvm's pattern; defensive +
    permissive. Adjust if production shows pathology.
- **Q-Curie-1**: warm-start parallelization — `future` /
  `future.apply` are already in Suggests; should the warmup
  loop default to parallel?
  - Lean: serial by default (5 univariate fits is ~5s); parallel
    optional via `control = list(warmup_parallel = TRUE)`.
- **Q-Fisher-1**: should we report a Wald CI in addition to the
  profile CI for nbinom2 sd_B, to give users diagnostic insight
  into the $(\psi, \phi)$ trade-off symmetry?
  - Lean: extend `confint_inspect()` to plot profile-vs-Wald
    discrepancy on nbinom2 fits. Post-M3.4 polish.

## 8. Persona contributions to this draft

- **Fisher** (lead): expected-outcomes table (§5); mitigation
  ranking via Noether's audit.
- **Boole** (lead): user-facing `init_strategy` arg design (§2).
- **Gauss** (lead): phi-clamp implementation sketch (§2 B);
  TMB-side cost-benefit.
- **Curie** (review, tests): warm-start vs default
  before/after smoke design (§3 S5).
- **Pat** (review): opt-in vs default for `init_strategy` —
  applied users would benefit from default-on, but it changes
  per-fit semantics; opt-in for v0.2.0 is conservative.
- **Rose** (review, scope honesty): §4 explicit no-claim that
  M3.4 hits the gate; §5 honest prediction band.
- **Ada** (coordinator): two-PR split (design here;
  implementation follow-on); cross-link to Design 49 contingency.

## 9. Next actions

1. **N1** — This PR merges (Noether audit + Design 48
   strategy). No code change.
2. **N2** — Implementation follow-on PR (S1–S7 in §3).
3. **N3** — Re-run M3.3a smoke; refresh
   `inst/extdata/m3-coverage-grid-smoke.rds` with warm-start
   results.
4. **N4** — Update validation-debt register rows for affected
   families (nbinom2, mixed, ordinal-probit).
5. **N5** — If R=200 production still under-covers any cell
   < 0.90: design 49 (Mitigation C).
