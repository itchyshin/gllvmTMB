# Design 48 — M3.4 boundary regimes: warm-start + phi-clamp

**Maintained by**: Fisher (validation design) + Boole (R API)
+ Gauss (TMB-side numerical). **Active reviewers**: Curie (test
fidelity), Noether (identifiability — see audit
`2026-05-18-noether-nbinom2-identifiability.md`), Pat (user-
facing control surface), Rose (scope honesty), Ada (coordinator).
**Status**: Active — M3.4 mitigation implementation has landed;
target-explicit empirical rerun evidence and default-policy
decisions remain.
**Backed by**:
- Noether identifiability audit
  (`docs/dev-log/audits/2026-05-18-noether-nbinom2-identifiability.md`)
- Cross-package scout audit
  (`docs/dev-log/audits/2026-05-18-cross-package-count-inference-scout.md`)
- Design 43 §4 #4 (single-trait warmup as Tier A borrowable from
  gllvm)
- M3.4 implementation after-task report
  (`docs/dev-log/after-task/2026-05-18-m3-4-implementation.md`)
- validation-debt rows MIS-16 / MIS-17

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

## 2. Implemented fix design (two mitigations)

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

**Implemented path** (Boole + Gauss):

1. Parse the multivariate data already assembled by
   `gllvmTMB_multi_fit()`.
2. For each trait level, fit an intercept-only univariate GLM with
   that trait's family.
3. Extract finite, clamped starts for matching `log_phi_*` entries.
4. Merge those starts into the default `tmb_params` before
   `TMB::MakeADFun()`.

**Implemented scope in v0.2.0**: phi-bearing families only, with
intercept-only univariate fits. Per-trait `b_fix`, `theta_diag_B`,
ordinal cutpoints, and delta-family secondary-parameter warmups are
deferred until the target-explicit M3.3 pilot shows they are needed.

### Mitigation B — Phi starting-value clamp `[0.01, 100]`

Per gllvm pattern (`gllvm.TMB:599-602`): when a count family is
used (nbinom1, nbinom2, truncated_nbinom1/2, beta_binomial),
clamp the **initial value** of `log_phi_*` to a reasonable
range.

**Why it helps**: avoids pathological random inits where phi
starts at numerical infinity (-> Poisson limit, sd_B picks up
all overdispersion) or numerical zero (-> NB likelihood
near-uniform, optimizer wanders).

**Implemented path** (Gauss):

For any `log_phi_*` starting parameter, clamp the initial value to
`[log(0.01), log(100)]` so initial phi ∈ `[0.01, 100]`. The
optimizer remains unconstrained; only the starting value is clamped.

No new user-facing argument needed — this is purely a sensible
default.

## 3. Implemented scope and remaining evidence

The implementation PR closed the API and internal-start mechanics.
The next M3 work is empirical validation, not basic implementation.

| Step | Lead | Status |
|---|---|---|
| **S1** — Add `init_strategy` arg to `gllvmTMBcontrol()` | Boole | Implemented; MIS-16 covered. |
| **S2** — Implement single-trait warmup loop in `R/fit-multi.R` | Boole + Gauss | Implemented for phi-bearing families. |
| **S3** — Add phi starting-value clamp in `R/fit-multi.R` | Gauss | Implemented; MIS-17 covered. |
| **S4** — Contract tests | Curie | Implemented in `test-m3-4-warmstart-phi-clamp.R`; these are contract tests, not R = 200 coverage claims. |
| **S5** — Rerun evidence | Curie + Pat | Pending. The next run must be target-explicit per Design 44. |
| **S6** — Validation-debt register | Rose | MIS-16 / MIS-17 covered; CI-08 / CI-10 remain partial. |
| **S7** — After-task report | Ada | Completed in `2026-05-18-m3-4-implementation.md`. |

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

## 5. Evidence needed after M3.4

Fisher's original prediction was that warm-start + phi clamp would
improve count and mixed-family coverage without changing Gaussian or
binomial cells. The implementation now exists, but the 2026-05-19
production grid still measured profile-`psi` coverage rather than
the primary total `Sigma_unit[tt]` target. Treat the table below as
the pre-implementation expectation, not as validated post-M3.4
evidence.

At smoke (R=10) — expected visible improvement:

| Cell | M3.3a coverage | M3.4 prediction |
|---|---|---|
| Gaussian | 0.95 | ~0.95 (no change; no count family) |
| Binomial | 0.95 | ~0.95 |
| ordinal-probit | 0.75 | ~0.80-0.85 (phi clamp irrelevant; warm-start helps cutpoints find good init) |
| Mixed | 0.64 | ~0.75-0.85 (warm-start helps the nbinom2 traits) |
| nbinom2 | 0.38 | **~0.70-0.85** (largest improvement) |

At production (R=200) — prediction before the target-scale audit:

- Gaussian / binomial: ≥ 0.94 (nominal at gate)
- ordinal-probit: ≥ 0.90, likely ≥ 0.94 with warm-start
- Mixed: ≥ 0.85, possibly ≥ 0.94
- nbinom2: ≥ 0.85, possibly ≥ 0.94 — but the
  $(\psi, \phi)$ trade-off at n=60 may keep this below gate;
  Mitigation C (disp_group) would close the rest

If the target-explicit post-M3.4 pilot still under-covers total
`Sigma_unit[tt]` in any cell < 0.90, Design 49 (Mitigation C)
activates.

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
- `R/init-warmstart.R` — single-trait warmup helper.
- `R/fit-multi.R` — warmup merge before `TMB::MakeADFun()`.
- `R/gllvmTMB.R` — `gllvmTMBcontrol()` `init_strategy` argument.

## 7. Open questions

- **Q-Boole-1**: should single-trait warmup default to ON for
  count families, or always opt-in?
  - Lean: **opt-in for v0.2.0** (`control = list(init_strategy
    = "single_trait_warmup")`); revisit defaulting only after
    target-explicit R=200 evidence.
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
  target-explicit bootstrap/profile CI for nbinom2 variance targets,
  to give users diagnostic insight into the $(\psi, \phi)$ trade-off
  symmetry?
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
- **Ada** (coordinator): two-PR split held historically; current
  coordination point is the target-explicit M3.3 pilot before any
  default-policy change.

## 9. Next actions

1. **N1** — Keep `init_strategy = "single_trait_warmup"` opt-in for
   v0.2.0.
2. **N2** — Run the Design 44 target-explicit pilot with warmstart
   enabled before any new full 15-cell production dispatch.
3. **N3** — Update CI-08 / CI-10 only after total `Sigma_unit[tt]`
   evidence is available.
4. **N4** — If target-explicit R=200 production still under-covers
   any cell < 0.90, activate Design 49 (Mitigation C).
