# After-task — VA tier-1 parity, calibrated inference, and the Ayumi second opinion

**Lane:** `claude/va-wiring-20260726`, worktree
`/private/tmp/gllvmtmb-va-wiring-20260726`. **HEAD `1476a9f2`**, pushed.
`devtools::test()`: **FAIL 0 | WARN 2 | SKIP 782 | PASS 7711**. NAMESPACE diff
0 lines; nothing exported; Laplace remains the only estimation route.

## 1. Goal

Three deliverables: (1) a per-family evaluation-tier **registry** that turns
"port 13 families" into "write 13 log-densities"; (2) **VA standard errors,
calibrated before quoted**; (3) a **defensible second opinion** on a matched
sub-model at Ayumi's scale.

## 2. Outcome — all three landed

### (1) Registry — done, and proven by a real port

`.va_r3_family_registry` (`4dc65e44`) declares the per-family contract in the
house style of `.profile_target_registry`: `family`, `family_code`, `link`,
`tiers`, `default_tier`, `expectation`. **4 of 16 families**
(gaussian_anchor · binomial · poisson · nbinom2).

The claim was tested rather than asserted: **`nbinom2` was ported through it**
(`f9d8da8f`). `E[log(phi + exp(eta))]` reduced to
`log(phi) + softplus_expectation(mu - log(phi), v)` — a **shifted call into the
existing Gauss-Hermite helper, no new quadrature machinery**. Cost: ~20 edits
across 3 files, one recompile. The template port was correct on its first clean
compile; all three iterations were in *test* code (an oracle that overflowed on
an unbounded exponential mean). So the real per-family cost is writing a sound
independent oracle, not the port — which is what the ~1.5–3h/family estimate
behind "tier-1 parity in 2–3 weeks" assumed.

`1476a9f2` extended the registry with `optimizer_by_tier`, so the optimiser is
resolved per family **and per tier**.

### (2) VA standard errors — built, calibrated, and reaching Ayumi's scale

VA had no inference of any kind, discharging the Design-72 obligation parked
2026-06-03 (*"VA variance components are biased … and SEs need care"*).

* `74f4c810` — `.va_r3_latent_posterior()` reads the variational block out of
  `best$par`; `q(z_i) = N(m_i, L_iL_i')` was already estimated and discarded.
  `.va_r3_fixed_information()` computes **two** quantities whose gap is the
  point: `se_conditional` (naive `optimHess` over the fixed block, **2–11%
  anti-conservative** because it ignores that the variational block
  re-optimises) and `se_profile` (the Schur complement, the correct observed
  information). A test pins `se_profile >= se_conditional` as an invariant.
* `2becfd49` — **the calibration**: `se_profile` covers **0.935–0.950** against
  nominal 0.95 in every cell; `se_conditional` under-covers everywhere
  (0.885–0.910). Nothing is quoted before that number exists.
* `39a0150a` — the dense `obj$he()` was **5.45 GB** at n=5397, so the guard
  fired and silently degraded to the under-covering variant. Replaced by a
  **block-diagonal Schur**: units are conditionally independent, so
  differencing along "within-unit coordinate j of every unit at once" returns
  column j of every block, giving all of `H_vv` in `2k` gradient calls
  **independent of N**. Measured at n=5397: **9.1s, ~220 MB**. Verified against
  the dense route to **1.5e-10 relative**, not assumed.
* `cc70aa8e` — made that route automatic (dims inferred from the parameter
  layout), so there is no scale at which it silently degrades.

### (3) Second opinion at Ayumi's scale — delivered

n = 5397, T = 20, q = 2, same simulated data, known `Lambda_true`:

| arm | rel. Frobenius | attenuation | grad_max | time |
|---|---|---|---|---|
| Laplace | 0.167 | 0.875 | **1.4e-02** | 590 s |
| VA · JJ | 0.391 | 0.655 | 3.6e-04 | 6815 s |
| **VA · GH** | **0.103** | **0.949** | 4.8e-04 | 8313 s + 103 s SE |

**VA-GH is the most accurate arm — better than Laplace** — and the SE machinery
returned on a real converged fit at 27,044 parameters in 103 s.

Note Laplace's `grad_max = 1.4e-02` while reporting `convergence = 0` and
`pdHess = TRUE`: 142× the tolerance the VA gate enforces, on the production
route at the real model size. That is the second opinion doing its job.

## 3. Corrections — the more valuable half

Five claims died here. Four were mine.

1. **"L-BFGS-B is 16× at n=800"** → **0.9× as a polish**. But as the *primary*
   optimiser, 17.7–37.7× at N=1600. Same tool, opposite verdict by role.
2. **"VA cannot fit n=5397"** → **it can**: ~500 s with `convergence = 0`. A
   wall-clock *budget* wall, not a capability wall.
3. **"gllvm profiles the variational block; we don't"** → **they don't either**.
   No `random=` at any of their three VA `MakeADFun` sites; same joint
   optimisation, same layout.
4. **"we hardcode gllvm's most expensive covariance option"** → their latent
   default is `unstructured`, same as ours.
5. **"lbfgsb should be the default"** → **refuted by measurement**. It is
   **1.7× slower on binomial-gh** (0.57×) and 2.4× slower on nbinom2 (0.42×),
   while 2.54× faster on binomial-jj and 2.13× on gaussian. Hence per-tier
   routing rather than a flip.

Also three **vacuous verifications** found, all silent: `grepl("converged", …)`
matching `"not_converged"` (inflating a reported 203/203 that is truly
160/203); a cross-check of mine that auto-dispatch turned into blocked-vs-blocked;
and a suite that ran new tests against a stale namespace.

## 4. AGHQ-Laplace — scoped, and its blocker closed

Measured, not argued. At q=1 (n=2000, T=20, 3 paired seeds): Laplace
attenuation 0.8968 → AGHQ (k=15) **0.9507**, at **1.67×** cost. About **half**
of Laplace's 10.3 pp deficit is quadrature error and AGHQ removes it; the other
4.9 pp is not, and no node count can reach it — AGHQ at k=15 *is* the exact
integral.

**TEST C — the stated blocker — passed.** Does q=1 transfer to q=2 (Ayumi's
cell)? Kill rule written before the run: `c_full < 1.01` ⇒ dead.

| seed | Laplace | AGHQ (k=9) | c_full | cost |
|---|---|---|---|---|
| 11 | 0.9290 | 1.0266 | 1.0512 | 3.40× |
| 12 | 0.9450 | 1.0918 | 1.0749 | 3.57× |
| 13 | 0.8982 | 1.0332 | 1.0725 | 3.62× |
| 14 | 0.9425 | 1.0460 | 1.0534 | 2.73× |
| 15 | 0.8929 | 1.0214 | 1.0695 | 2.72× |
| **mean** | **0.9215** | **1.0438** | **1.0643** | **3.40×** |

5/5 same direction, `c_full` 1.064 — **above** the predicted 1.02–1.04 band and
well clear of the kill rule. **The q=1 result transfers.**

Two honest qualifications:

* **AGHQ now overshoots**: mean attenuation **1.044**, recovering ~4% *more*
  trace than truth, where Laplace undershoots at 0.92. The acceptance criterion
  must therefore be `|attenuation − 1|`, not "higher is better". On that metric
  AGHQ (0.044) still beats Laplace (0.078), but by less than the raw numbers
  suggest, and the sign flip versus the q=1 run (0.951) is unexplained at 5
  seeds.
* **Cost is 3.40× at q=2, not the 1.67× measured at q=1.** Still the fast route
  — ~33 min at Ayumi's scale against VA-GH's 2h19m — but the cost model needs
  updating.

`H^q` nodes makes this a **low-q** solution (25 at q=2, 2401 at q=4). VA does
not degrade with q, so they are complementary.

## 5. Checks

`devtools::test()` FAIL 0 / PASS 7711 on every landed commit · NAMESPACE diff 0
· `src/gllvmTMB.cpp` and `R/gllvmTMB.R` untouched · never `git add -A` (the
worktree carries ~40 untracked research scratch files) · `devtools::check()`
and pkgdown **not** run.

## 6. Scope limits

VA admits 4 of 16 families, binomial **logit** only, and rejects `structured`
(phylogeny), `missing`, and incomplete cells — so it covers **2 of Ayumi's 27
responses** and cannot express her phylogeny or missingness. The second opinion
above is a *matched sub-model*, explicitly not her analysis. Coverage evidence
is beta-only, q=2, p=8, n ∈ {150,400}, 25 seeds. AGHQ numbers are one DGP,
3–5 seeds, one OS, one BLAS, on a contended machine.

## 7. Follow-up

* `profile=` (R3) — the structural route, still **unmeasured**.
* Closed-form PG updates — **verified** (gradient 1.55e-15 at the fixed point,
  monotone) but **not built**, and **JJ-only**, so it accelerates the *worse*
  arm.
* AGHQ-LA: explain the q=1→q=2 attenuation sign flip before building.
* The 59/70 silent-degenerate-fit finding is **still undiagnosed** — see
  `docs/dev-log/2026-07-27-relative-collapse-does-not-explain-59of70.md` on
  PR #799.
