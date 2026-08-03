# Design 108 recovery campaign — gaussian positive control: why it plateaus

**Reviewer:** Noether (adversarial statistical-correctness review, fresh eyes)
**Date:** 2026-08-02
**Worktree:** `/private/tmp/gllvmtmb-d108-recovery` (branch `claude/d108-recovery-campaign`)
**Scope:** read-only investigation of `R/`, `src/`, `dev/design108-recovery/`; new scratch
scripts under `dev/design108-recovery/noether-diag{1,2,3,4}.R` only. No package file touched.

---

## VERDICT

**ESTIMAND-MISMATCH** (two independent instances, both mechanical, both quantified below),
**plus a genuine-limit caveat on the phylogenetic tier that is NOT ruled out.**

The gaussian control is *not* failing to converge and the estimator is *not* inconsistent.
`Sigma_hat` and `Sigma_true` denote different objects, and the difference between them is a
**fixed additive diagonal offset that does not shrink with `N` by construction**. That offset
alone reproduces essentially the whole observed plateau for tier 1.

---

## 1. The observation

`dev/design108-recovery/pilot-results/job1_floor_sweep.csv`, gaussian control arm,
T=20, q=1, 3 seeds/N:

| N | mean tier-1 `rel_frob` | mean tier-2 `rel_frob` |
|---|---|---|
| 100 | 0.584 | 0.554 |
| 250 | 0.418 | 0.373 |
| 500 | 0.348 | 0.402 |
| 1000 | 0.394 | 0.419 |

Reproduced exactly: my independent re-run of N=250/seed=1 returned `rel_frob` 0.41336 /
0.34522 against the recorded 0.413355 / 0.345224. The pipeline is deterministic; nothing is
flaky.

Secondary observation not in the brief: **7 of the 12 recorded cells have
`convergence == 1`** (`job1_floor_sweep.csv`), i.e. the outer optimiser hit its iteration
limit, while `pdHess == TRUE` throughout. `job1_floor_sweep.R:58` requires
`convergence == 0` for a cell to count as clean, so on the script's own gate the floor sweep
has **no clean N at all**. That is a separate problem from the plateau (the N=1000/seed=1 cell
has `convergence == 0` and still shows `rel_frob` 0.381), but it must not be left unrecorded.

---

## 2. Hypotheses considered

1. **Estimand mismatch** — `Sigma_hat` and `Sigma_true` denote different objects.
2. **`S_i` / `Sigma_B` conflation** — the harness compares a variational posterior covariance
   to a between-unit covariance.
3. **Genuine identifiability limit** — part of `Sigma_B` is not estimable at q=1.
4. **Defect** in the truth, the extraction, or `rel_frob`.
5. **Metric floor** — `rel_frob` artifact of how `Sigma_true` is normalised.

**Hypothesis 2 is cleanly ruled out.** The gaussian control never touches the VA engine:
`harness.R:396-402` and `harness.R:414-420` fit with `gllvmTMB::gllvmTMB(...)`, the shipped
Laplace path, and score via `gllvmTMB::extract_Sigma(fit, level = ..., part = "total")`
(`harness.R:432-437`), which is a function of the *estimated parameters* `Lambda` and `psi`,
not of any per-unit posterior. No `S_i`-derived quantity enters the control arm.

**Hypothesis 4 is ruled out for `rel_frob` itself** (`dgp.R:45-51` computes exactly
`||H-T||_F / ||T||_F`) and for the *extraction* of `Sigma_hat` (`extract_Sigma()` does what its
documentation says). It is **confirmed for the DGP**, in a specific and narrow sense: the DGP
is internally consistent — `dgp-selfcheck.R` genuinely passes and I did not find a fault in it
— but it generates a tier-2 Psi component whose **cross-species structure the fitted model
cannot represent** (§4b), and it labels `Lambda Lambda' + diag(psi)` as `Sigma_B`, which is not
what `PROTOCOL.md` means by that symbol (§4d). Note why `dgp-selfcheck.R` cannot catch this:
its Check C (`dgp-selfcheck.R:114-175`) verifies that `cov(realized)` converges to the stated
`Sigma_B`, which is a statement about **marginal second moments** and is true whether or not
the Psi component is phylogenetically correlated. The self-check is blind to precisely the
axis that is wrong.

**Hypothesis 5 is ruled out as the primary cause.** `Sigma_true` here is not strongly
diagonally dominant (N=250/seed=1: mean diagonal 1.265 vs off-diagonal sd 0.550), and the
plateau is quantitatively reproduced from first principles in §5 without appealing to any
property of the normalisation.

**Hypotheses 1 and 4 are what the evidence supports.** Hypothesis 3 survives as an
unresolved caveat confined to the *phylogenetic tier's loadings* — see §7.

---

## 3. Decisive experiment 1 — element-wise, not scalar

`dev/design108-recovery/noether-diag1.R`, one cell (N=250, seed=1), gaussian control.
`rel_frob` 0.4134 / 0.3452 as recorded.

```
TIER 1 (level = "unit")
  diag  true: mean=1.2653   diag hat: mean=2.1651   hat-true: mean=+0.8998  sd=0.2990
  offd  cor(hat, true) = 0.9937     slope(hat ~ true) = 1.2352
  squared-error share: diagonal 67.7%, off-diagonal 32.3%

TIER 2 (level = "phy")
  diag  true: mean=1.1626   diag hat: mean=0.5349   hat-true: mean=-0.6277  sd=0.2937
  offd  cor(hat, true) = 0.9706     slope(hat ~ true) = 1.0065
  squared-error share: diagonal 63.9%, off-diagonal 36.1%
```

This is **structure, not scatter**. The off-diagonals correlate with truth at 0.97–0.99; the
diagonals are offset by a nearly constant amount, **+0.90 on tier 1 and −0.63 on tier 2**,
in opposite directions. Two thirds of the squared error is on the diagonal. That is the
signature of a mis-specified diagonal, not of sampling noise.

---

## 4. Decisive experiment 2 — what the offset is

`dev/design108-recovery/noether-diag2.R` decomposes the same fit into
`part = "shared"` (`Lambda Lambda'`) and the implied `psi` (`total − shared`):

```
  unit  total   diag mean = 2.1651     unit  shared  diag mean = 0.7012   => psi_row_hat = 1.4639
  phy   total   diag mean = 0.5349     phy   shared  diag mean = 0.5349   => psi_phy_hat  = 0
  max |phy_total − phy_shared| = 1.98e-08          (the phylo Psi has collapsed to zero)

  truth: psi1 mean = 0.6992   psi2 mean = 0.6596   gauss_sd^2 = 0.16
         psi1 + psi2 + gauss_sd^2 = 1.5188   vs   psi_row_hat = 1.4639
```

### 4a. The DGP has three iid noise sources; the fitted model has one

- `dgp.R:123-125` — tier-1 Psi: `Z1 <- matrix(rnorm(N*T), N, T)`, `B1 <- sweep(Z1, 2, sqrt(psi1), "*")`.
  **iid across species and traits** (one draw per (species, trait) cell).
- `dgp.R:133-134` — tier-2 Psi: `Z2 <- matrix(rnorm(N*T), N, T)`,
  `F2_base <- U2 %*% t(Lambda2_base) + sweep(Z2, 2, sqrt(psi2_base), "*")`.
  **Also iid across species** — `Z2` carries no phylogenetic correlation whatsoever.
- `harness.R:406` — the control's own residual: `dat$y <- dat$eta_true + rnorm(nrow(dat), 0, gauss_sd)`.
  **Also iid per row.**

The fitted model has exactly one row-level diagonal. `R/fit-multi.R:4794-4808` auto-suppresses
`sigma_eps` and says so at run time:

> "Auto-suppressing `sigma_eps`: `indep(0 + trait | species)` is at the per-row level, so it
> already absorbs the observation residual." (fixed at 0.00164)

So the tier-1 Psi is an OLRE that necessarily absorbs **all three**. Measured: 1.4639 against
a true total of 1.5188 (3.6% low at N=250; the gap closes with N — see §6).

### 4b. The model's phylogenetic Psi is `Psi_phy ⊗ A`; the DGP's is `Psi_2 ⊗ I`

`R/brms-sugar.R:3555-3559`, the package's own comment on the `phylo_latent(unique = TRUE)`
fold:

> "The auto-companion is the phylo-structured diagonal `Psi_phy (x) A`, i.e.
> `phylo_rr(species, .phylo_unique = TRUE, .auto_unique = TRUE)`, **NOT a plain diag**."

Confirmed in the C++ (`src/gllvmTMB.cpp:1181-1208`): `g_phy_diag.col(t) ~ N(0, A)`, contributed
to the linear predictor at `src/gllvmTMB.cpp:2045-2049`.

The DGP therefore plants **nothing** that `sd_phy_diag` can estimate. Its MLE goes to the
boundary — measured `max|phy_total − phy_shared| = 1.98e-08` at N=250/seed=1 and
`2.11e-09` at N=250/seed=2 — and the variance the DGP calls `psi2` is correctly picked up by
the row-level OLRE instead.

`extract_Sigma(level = "phy", part = "total")` adds `sd_phy_diag^2` to the diagonal
(`R/extract-sigma.R:1245-1246`). The `phylo_diag` tier *is* fitted here — the fold at
`R/brms-sugar.R:3562-3591` does create it — but its estimate is at the boundary, so
`part = "total"` and `part = "shared"` coincide numerically and the returned matrix is
effectively `Lambda_phy Lambda_phy'`. The truth it is scored against is
`sim$truth$tier2$Sigma_B = Lambda2 Lambda2' + diag(psi2)` (`dgp.R:138-139, 166`), which
carries a mean diagonal contribution of 0.6596 that the fit structurally cannot produce.

### 4c. The accounting, and what in it is actually a prediction

N=250, seed=1, decomposing the measured mean diagonal error into its Psi and loading parts:

| | Psi contribution | loading contribution | total | measured |
|---|---|---|---|---|
| tier 1 | `1.4639 − 0.6992` = +0.7647 | `0.7012 − 0.5661` = +0.1351 | +0.8998 | +0.8998 |
| tier 2 | `0 − 0.6596` = −0.6596 | `0.5349 − 0.5030` = +0.0319 | −0.6277 | −0.6277 |

**Be clear about what this is.** The agreement in the last two columns is an algebraic
identity — `diag(Sigma_hat) − diag(Sigma_true)` split into its two additive pieces — so it
proves nothing by itself. What the table *shows* is the **partition**: on tier 1, 85% of the
diagonal error is the Psi term; on tier 2 the Psi term (−0.6596) is 21× the loading term
(+0.0319) and carries the opposite sign to tier 1's. That is the asymmetry visible in §3.

The genuinely **predictive** claims — each derived from §4a/§4b before looking at the fit, and
each confirmed — are:

1. `psi_row_hat` should equal `psi1 + psi2 + gauss_sd^2`: predicted 1.5188, measured 1.4639
   at N=250 (3.6% low), with the gap closing as `1/sqrt(N)` (§6) and reaching 1.5275 vs
   1.5188 (+0.6%) in the controlled rerun of §6b.
2. `psi_phy_hat` should be **zero**: measured 1.98e-08 (N=250 s1), 2.11e-09 (N=250 s2).
3. `rel_frob` should therefore carry an N-independent algebraic floor computable from the
   truth alone — tested in §5 — and swapping the tier-2 Psi's cross-species structure should
   move `psi_row_hat` down by exactly `psi2` — tested in §6b.

### 4d. There is also a protocol-level naming collision

`PROTOCOL.md:382-383` defines the estimands as

> `Sigma_B0 = Lambda0 Lambda0'` … `Sigma_B1 = Lambda1 Lambda1'`

**loadings-only**, with `Sigma_total = Sigma_B + diag(psi)` listed separately at
`PROTOCOL.md:392-393`, and `PROTOCOL.md:453` defining `rel_frob` **on `Sigma_Bk`**.

`dgp.R:126, 138-139, 163, 166` names `Lambda Lambda' + diag(psi)` as `truth$tier*$Sigma_B`,
and `harness.R:492-493` scores `extract_Sigma(part = "total")` against it. So the harness is
measuring `Sigma_total`, not the protocol's `Sigma_B`, and calling the result `rel_frob`.
Even with the DGP fixed, that discrepancy has to be resolved deliberately rather than by
accident.

---

## 5. Decisive experiment 3 — the plateau value is predictable without fitting anything

If the account in §4 is right, `rel_frob` has an **algebraic floor computable from the truth
alone**:

- tier 1 floor = `||diag(psi2 + gauss_sd^2)||_F / ||Sigma1_true||_F`
- tier 2 floor = `||diag(psi2)||_F / ||Sigma2_true||_F`

Neither depends on `N`. Computed for the exact 12 cells of `job1_floor_sweep.csv` (no fitting
— `simulate_two_tier()` only):

| N | seed | floor₁ | observed₁ | excess₁ | floor₂ | observed₂ | excess₂ |
|---|---|---|---|---|---|---|---|
| 100 | 1 | 0.7267 | 0.8157 | 0.0889 | 0.3234 | 0.5720 | 0.2487 |
| 100 | 2 | 0.3955 | 0.4334 | 0.0379 | 0.2549 | 0.3594 | 0.1045 |
| 100 | 3 | 0.4280 | 0.5034 | 0.0754 | 0.2643 | 0.7308 | 0.4665 |
| 250 | 1 | 0.3037 | 0.4134 | 0.1097 | 0.2762 | 0.3452 | 0.0690 |
| 250 | 2 | 0.3258 | 0.4397 | 0.1138 | 0.2048 | 0.2300 | 0.0252 |
| 250 | 3 | 0.2980 | 0.3996 | 0.1017 | 0.4539 | 0.5449 | 0.0909 |
| 500 | 1 | 0.4011 | 0.4165 | 0.0154 | 0.2170 | 0.2851 | 0.0680 |
| 500 | 2 | 0.3886 | 0.3896 | 0.0010 | 0.3144 | 0.5823 | 0.2678 |
| 500 | 3 | 0.2155 | 0.2377 | 0.0222 | 0.2666 | 0.3373 | 0.0707 |
| 1000 | 1 | 0.3537 | 0.3808 | 0.0271 | 0.2399 | 0.3687 | 0.1287 |
| 1000 | 2 | 0.4410 | 0.4370 | −0.0040 | 0.2139 | 0.4155 | 0.2016 |
| 1000 | 3 | 0.3379 | 0.3655 | 0.0276 | 0.3467 | 0.4734 | 0.1267 |
| **mean** | | **0.3846** | **0.4360** | | **0.2813** | **0.4370** | |

**Tier 1: at N ≥ 500 the measured `rel_frob` is the floor, to within 0.03.** Excess over the
floor falls 0.075 → 0.108 → 0.013 → 0.017 (mean per N). The metric is saturated: **96%** of
what the sweep reports at N=1000 (0.3775 floor vs 0.3944 measured, means over 3 seeds) is the
built-in offset, and the same at N=500 (0.3351 vs 0.3479). The floor itself wanders
between 0.22 and 0.73 across cells purely because each `(N, seed)` redraws `psi2` and the
tree — that is *draw* variation masquerading as an N-effect, which is why the reported curve
looks like it "worsens" from 500 to 1000.

**Tier 2: the floor accounts for roughly two-thirds of the measured value, and a real
residual remains** (see §7).

---

## 6. Decisive experiment 4 — remove the mismatch and the estimator is consistent

`dev/design108-recovery/noether-diag3.R` re-scores the *same fits* against the corrected
estimand (`part = "shared"` vs the true `Lambda Lambda'`, i.e. `PROTOCOL.md:382-383`'s
actual definition), and separately checks the row-level Psi against the sum it should
recover:

```
  N  seed conv | rel_frob AS-IS   | rel_frob SHARED  | psi_row rel-err | max psi_phy_hat
             |  tier1 / tier2   |  tier1 / tier2   |                 |
 100   1   0  | 0.816 / 0.572    | 0.607 / 0.601    |     0.202       |   5.78e-01
 100   2   0  | 0.433 / 0.359    | 0.183 / 0.293    |     0.169       |   5.76e-02
 250   1   1  | 0.413 / 0.345    | 0.271 / 0.254    |     0.089       |   1.98e-08
 250   2   1  | 0.440 / 0.230    | 0.255 / 0.099    |     0.105       |   2.11e-09
 500   1   1  | 0.416 / 0.285    | 0.153 / 0.192    |     0.067       |   1.34e-02
 500   2   0  | 0.390 / 0.582    | 0.151 / 0.631    |     0.071       |   1.54e-02
1000   1   0  | 0.381 / 0.369    | 0.100 / 0.264    |     0.049       |   1.85e-02
1000   2   1  | 0.437 / 0.416    | 0.086 / 0.340    |     0.040       |   4.12e-09
1000   3   1  | 0.365 / 0.473    | 0.132 / 0.339    |     0.031       |   5.54e-09
```

Per-N means of the corrected (SHARED) metric:

| N | tier-1 shared | tier-2 shared | psi_row rel-err |
|---|---|---|---|
| 100 | 0.395 | 0.447 | 0.186 |
| 250 | 0.263 | 0.177 | 0.097 |
| 500 | 0.152 | 0.412 | 0.069 |
| 1000 | 0.106 | 0.314 | 0.040 |

Two things shrink cleanly and one does not:

- **Row-level Psi:** rel-err 0.186 → 0.097 → 0.069 → 0.040 across N = 100 → 250 → 500 → 1000.
  That tracks `1/sqrt(N)` closely (predicted from the N=100 anchor: 0.186, 0.118, 0.083,
  0.059), and it converges to `psi1 + psi2 + gauss_sd^2` — confirming §4a's claim about what
  the OLRE absorbs.
- **Tier-1 loadings (`Lambda1 Lambda1'`):** 0.395 → 0.263 → 0.152 → **0.106**, monotone, at or
  slightly faster than `1/sqrt(N)` (which from the N=100 anchor predicts 0.395, 0.250, 0.177,
  0.125). **There is no tier-1 plateau once the estimand is correct.** The corrected tier-1
  error at N=1000 is a factor of 3.7 below the as-is number (0.106 vs 0.394).
- **Tier-2 loadings (`Lambda_phy Lambda_phy'`):** 0.447 → 0.177 → 0.412 → 0.314. **Not
  monotone and not shrinking after N=250**, with cell-to-cell spread (0.192 vs 0.631 at
  N=500; 0.264 / 0.340 / 0.339 at N=1000) far larger than tier 1's (0.153 vs 0.151;
  0.100 / 0.086 / 0.132). See §7.

---

## 6b. Decisive experiment 5 — the causal test

`dev/design108-recovery/noether-diag4.R` holds everything fixed (same tree, same `beta0`,
same `Lambda1`/`Lambda2`/`psi1`/`psi2`, same `U1`/`U2`, same seeds) and swaps **only** the
cross-species structure of the tier-2 Psi component. N=250, seed=1:

```
A: tier-2 Psi iid across species  (what dgp.R:133 does)
   rel_frob as-is  0.4078 / 0.3992      psi_phy_hat mean = 0.0024   (cor with true psi2 = 0.025)
                                        psi_row_hat mean = 1.5275
B: tier-2 Psi phylo-structured    (what the fitted model assumes)
   rel_frob as-is  0.2125 / 0.6571      psi_phy_hat mean = 0.5657   (cor with true psi2 = 0.503)
                                        psi_row_hat mean = 0.8583
```

The absorption prediction of §4a is confirmed to within rounding, in both directions:

| arm | what the row-level OLRE should absorb | predicted | measured `psi_row_hat` |
|---|---|---|---|
| A (iid) | `psi1 + psi2 + gauss_sd^2` | 1.5188 | **1.5275** (+0.6%) |
| B (phylo) | `psi1 + gauss_sd^2` | 0.8592 | **0.8583** (−0.1%) |

And `sd_phy_diag` stops being a null parameter: `psi_phy_hat` moves from 0.0024 (a collapsed
boundary estimate, uncorrelated with truth at r=0.025) to 0.5657 against a true 0.6596, with
r=0.503. **This is a causal demonstration, not an accounting argument.** Tier 1's as-is
`rel_frob` halves, from 0.4078 to 0.2125, purely from removing the mismatch.

Note the honest counterweight: in arm B tier 2's as-is `rel_frob` *rose*, 0.3992 → 0.6571,
because the phylo-structured Psi adds T=20 structured components competing with the rank-1
`Lambda_phy` for the same tree signal, and at N=250 it is only weakly recovered (r=0.503).
Fixing the DGP makes the tier-2 problem **harder**, not easier. One seed; do not over-read it.

---

## 7. What I could NOT rule out

**The phylogenetic tier's loading error may be a genuine limit (hypothesis 3), and I did not
resolve it.** After removing the entire Psi mismatch, tier-1's error falls monotonically
(0.395 → 0.263 → 0.152 → 0.106) but tier-2's does not: 0.447 → 0.177 → 0.412 → 0.314, with
within-N spread (0.192 vs 0.631 at N=500; 0.264 / 0.340 / 0.339 at N=1000) that dwarfs
tier 1's (0.153 vs 0.151; 0.100 / 0.086 / 0.132 at the same two N).
Tier 1 is behaving like a consistent estimator; tier 2 is not obviously behaving like one.

A plausible mechanism is that the phylogenetic tier's effective sample size is governed by the
*shape* of the drawn tree rather than by the tip count. `ape::rcoal()` trees at these sizes
have high and erratic mean off-diagonal correlation — measured at seed 1: N=100 0.325,
N=250 0.393, N=500 0.386, N=1000 0.258, N=2000 0.634 — and a single deep split contributes one
effectively independent realisation of the rank-1 phylo field however many tips hang below it.
On that account the per-cell tier-2 error would be driven mostly by *which tree got drawn*,
which is exactly the erratic pattern observed, and **the campaign's N-ladder could not buy it
down**. That would materially change what the campaign can conclude about the phylo tier —
which is the tier the whole question is about.

I have 2 seeds at each of N=100/250/500 and 3 at N=1000 for this quantity. **That is far too few
to call it, in either direction.** §6b additionally shows the corrected DGP makes
the tier-2 problem *harder*, so this must be measured under the fixed DGP, not the current one.
This is the gating unknown and must be settled before the grid is bought.

Other open items:

- **The `convergence == 1` rate** (7/12 cells). Not the cause of the plateau, but it is a
  failure of `job1_floor_sweep.R`'s own clean-cell gate and is currently unreported.
- **Whether the same mismatch afflicts the binomial-probit arms.** I only diagnosed the
  gaussian control. §4a's OLRE-absorption argument is family-independent, but the shipped
  engine's binomial identifiability gate (`harness.R:349-357`) interacts with it and I did
  not test that path.
- **The VA arms — a second, independent estimand mismatch, found by code reading only.**
  `.d108_va_phylo_tiers()` (`harness.R:228-233`) declares the phylo Psi as

  ```r
  list(kind = "diagonal", dim = as.integer(T), level_id = as.integer(unit - 1L),
       structured = FALSE, label = "phylo_psi")
  ```

  `structured = FALSE`, indexed by **species**, not by augmented node. That is the *opposite*
  of the Laplace engine's `Psi_phy ⊗ A` (§4b) — and it also contradicts the VA-R3 prototype's
  own stated requirement at `R/va-r3-proto.R:356-359`: "what `phylo_latent(unique = TRUE)`
  needs: a structured low-rank tier **plus a structured diagonal Psi tier** over the SAME
  tree." Worse, `.va_r3_build_tiers()` (`R/va-r3-proto.R:462-466`) already creates, under
  `unique = TRUE`, a tier with the byte-identical specification
  `list(kind = "diagonal", dim = T, level_id = unit_id0, structured = FALSE)`. So the VA arm
  as configured carries **two exactly-identical unstructured per-row diagonals** (tier 2
  "psi" and tier 4 "phylo_psi"), which are mutually non-identifiable, and
  `.d108_va_tier_sigma(par, layout, 3L, 4L, T)` (`harness.R:304`) folds the second into the
  reported tier-2 `Sigma_B`. The Laplace arm's tier-2 `Sigma_hat` therefore *cannot* contain a
  row-level diagonal and the VA arm's *always* can. **A `rel_frob` comparison between the two
  arms is confounded at the level of the estimand before any inference happens.**
  I did not run a VA fit — this is read off `harness.R` and `R/va-r3-proto.R`, and should be
  confirmed empirically — but it is the single most important thing to settle next.
- **Whether `gauss_sd` should exist at all.** The control adds residual noise (`harness.R:406`)
  that has no counterpart in `sim$truth`, so it inflates tier 1 by `gauss_sd^2` on every
  diagonal element even after the tier-2 Psi issue is fixed.

---

## 8. What this implies for the campaign

**The campaign must NOT proceed on the current harness.** Not because the engine is broken —
tier 1 is demonstrably consistent, and at N=1000 the corrected tier-1 error is 0.106 — but
because the reported metric is dominated by a constant that has nothing to do with recovery
quality. At N=500 the mean tier-1 floor is 0.3351 against a mean measured 0.3479 (**96%**);
at N=1000 it is 0.3775 against 0.3944 (**96%**). A VA-vs-Laplace comparison run through this
metric would be comparing two numbers that are each ~96% a fixed offset, which would make the
two engines look artificially similar and destroy the campaign's power to detect the very
difference it exists to detect. Worse, because the offset is an artifact of the *DGP's* Psi
and not of either engine, an arm whose `Sigma_hat` happens to include a row-level diagonal
(the VA arm — see §7) would score *better* on this metric for a reason unrelated to recovery.

Three fixes, in order of preference:

1. **Make the DGP match the model.** Generate the tier-2 Psi as a phylogenetically structured
   per-trait field (`g_t ~ N(0, A)` scaled by `sqrt(psi2_t)`), replacing `dgp.R:133`'s iid
   `Z2`. This is the only fix that makes `sd_phy_diag` an estimable parameter, and it is what
   `PROTOCOL.md:262-272`'s "both tiers `unique = TRUE`" actually means given the package's
   `Psi_phy ⊗ A` semantics.
2. **Score the protocol's estimand.** Change `harness.R:492-493` to compare
   `extract_Sigma(part = "shared")` against `Lambda Lambda'` — `PROTOCOL.md:382-383, 453`'s
   own definition. Do this regardless of (1); it removes the naming collision and is the
   metric the protocol actually specifies.
3. **Account for the control's own residual.** Either set `gauss_sd` to something negligible,
   or add `gauss_sd^2` to the tier-1 truth diagonal.

**Then re-gate.** The positive control's `rel_frob <= 0.5` gate
(`harness.R:545-551`, `job1_floor_sweep.R:58`) is currently being cleared or missed for
reasons unrelated to recovery, and must be re-derived after the fix — together with the
`convergence == 1` question and the tier-2 effective-sample-size question in §7.

**Do not buy the grid until (a) the fixed DGP shows tier-2 `rel_frob` shrinking with N over at
least 5 seeds, and (b) the VA-vs-Laplace phylo-Psi structural question in §7 is resolved.**
Until (b) in particular, there is no guarantee the two arms share an estimand at all, and the
campaign's headline comparison would be uninterpretable no matter how much compute is spent
on it.

> **(b) is now settled — see the ADDENDUM below.** It is a real confound: the VA arm's two
> row-level diagonals are exactly non-identifiable by a labelling symmetry of the objective,
> so the reported VA tier-2 `Sigma_hat` is inflated by the whole row-level diagonal or by
> nothing at all, decided by the starting values. The minimal fix is specified in §A16.

---

## Appendix — scripts

All twelve are read-only against the package; they write only under
`dev/design108-recovery/pilot-results/`. Run from the worktree root with `NOT_CRAN=true`.

| script | what it does | invocation used |
|---|---|---|
| `noether-diag1.R` | element-wise `Sigma_hat` vs `Sigma_true`, one cell (§3) | `D108_N=250 D108_SEED=1` |
| `noether-diag2.R` | shared/unique decomposition, Psi accounting (§4) | `D108_N=250 D108_SEED=1` |
| `noether-diag3.R` | N-sweep, as-is vs corrected estimand (§6) | `D108_NS=100,250,500 D108_SEEDS=1,2 D108_TAG=a`; `D108_NS=1000 D108_SEEDS=1 D108_TAG=b`; `D108_NS=1000 D108_SEEDS=2,3 D108_TAG=c` |
| `noether-diag4.R` | causal test: iid vs phylo-structured tier-2 Psi (§6b) | `D108_N=250 D108_SEED=1` |
| `noether-diag5.R` | VA tier declaration, structural comparison (§A10) | (no env vars) |
| `noether-diag6.R` | first VA gaussian fit; superseded by diag7 | `D108_N=100 D108_T=10 D108_SEED=1` |
| `noether-diag7.R` | VA fit, probit + gaussian, full precision (§A13, §A15) | `D108_N=100 D108_T=10 D108_SEED=1` |
| `noether-diag8.R` | exchange symmetry + mirrored starts (§A11, §A12) | `D108_N=100 D108_T=10 D108_SEED=1` |
| `noether-diag9.R` | the proposed fix (§A16) | `D108_N=100 D108_T=10 D108_SEED=1` |
| `noether-diag10.R` | harness's own 4-start machinery (§A17) | `D108_N=100 D108_T=10 D108_SEEDS=1,2,3 D108_NSTARTS=4` |
| `noether-diag11.R` | per-arm/per-tier: is `Sigma_hat` loadings or total? (§B2, §B3) | `D108_N=120 D108_T=8 D108_SEED=1 D108_VA=0` (VA part did not finish) |
| `noether-diag12.R` | where the control's `gauss_sd^2` lands (§B5.4) | (no env vars) |

Two caveats on my own scratch code, recorded so nobody re-derives them:

- `noether-diag2.R` calls `extract_Sigma(part = "unique")$Sigma`, which is `NULL` — that part
  returns `$s`, a vector (`R/extract-sigma.R:1537-1544`), not a matrix. **That is my script's
  error, not a package defect.** All Psi figures quoted above are computed as
  `diag(total) − diag(shared)` instead, which is exact.
- `noether-diag4.R` originally assigned `dat$y <- as.vector(eta)`, which is misaligned:
  `sim$data` is row-sorted at `dgp.R:158` while `eta` is an `N x T` matrix in column order.
  Fixed to index by `eta[cbind(dat$unit, dat$trait)]`. The pre-fix run produced
  `rel_frob` of 1.02 / 11.9 and was discarded; only post-fix numbers appear in §6b.

An N=2000 cell was started and **deliberately abandoned** — a single seed on a tree with
outlier mean correlation (0.634) cannot settle the §7 question, and it was starving the
N=1000 runs. No N=2000 number is reported.

Raw output: `dev/design108-recovery/pilot-results/noether-*.rds` (LOCAL only, per D-50 — not
committed, never a GitHub artifact).

---
---

# ADDENDUM (2026-08-02) — settling §7's VA double-diagonal finding

**Requested by the coordinator after the diagnostic above:** §7 flagged, *from code reading
only*, that the VA arm declares its phylogenetic Psi as an unstructured per-species diagonal —
byte-identical to the tier `unique = TRUE` already creates — and inferred that the VA arm's
tier-2 `Sigma_hat` therefore carries a row-level diagonal the Laplace arm's cannot. That was
marked UNVERIFIED. This addendum settles it by measurement.

## A9. VERDICT

**CONFOUNDED.**

The two diagonals are **exactly non-identifiable by a labelling symmetry of the objective**.
The answer to "does one collapse to ~0, like `sd_phy_diag` did?" is *yes — but which one is
arbitrary*, decided by the starting values and not by the data. In one corner the campaign
reports a tier-2 `Sigma_hat` with no row-level diagonal; in the other, exactly equal in
objective, it reports one inflated by the **entire** row-level diagonal. Both corners are
optima. The engine's own multi-start health gate cannot distinguish them, because it compares
objectives — and the objectives are identical.

## A10. The declaration is byte-identical (structural)

`dev/design108-recovery/noether-diag5.R` builds the tier list from the harness's **own**
`.d108_va_phylo_tiers()` output (`harness.R:228-233`) and compares tier 2 with tier 4.
Run at a deliberately tiny N=60, T=8 — this check involves no fitting, so size is
irrelevant to it (every other experiment below uses N=100, T=10):

```
  tier 1: kind=dense     dim=1   n_levels=60   structured=FALSE label=latent
  tier 2: kind=diagonal  dim=8   n_levels=60   structured=FALSE label=psi
  tier 3: kind=dense     dim=1   n_levels=118  structured=TRUE  label=phylo
  tier 4: kind=diagonal  dim=8   n_levels=60   structured=FALSE label=phylo_psi

  kind / dim / n_levels / structured : identical = TRUE for all four
  level_id                           : identical = TRUE  (max abs diff 0)
  => byte-identical apart from `label`: TRUE
```

Tier 2 comes from `unique = TRUE` (`R/va-r3-proto.R:462-466`, via `want_psi` at
`R/va-r3-proto.R:708`); tier 4 from `harness.R:231-232`. Confirmed, not inferred.

## A11. The decisive experiment — an exact exchange symmetry

`dev/design108-recovery/noether-diag8.R`, TEST A. Swap tier 2's and tier 4's blocks
wholesale — `log_sd_tier`, `m`, `log_L_diag`, `L_off`, sliced by the layout's own offsets
(`R/va-r3-proto.R:604-611`) — and re-evaluate the objective. N=100, T=10, q=1,
binomial_probit (the campaign's actual VA family), H=15:

```
[random par]  obj(par) = 47262.8890397626   obj(swap) = 47262.8890397626   diff =  3.638e-11
[FITTED par]  obj(par) =  1798.7925802187   obj(swap) =  1798.7925802187   diff = -9.095e-13
              psi tier2  9.320750e-01 -> 3.381526e-09
              psi tier4  3.381526e-09 -> 9.320750e-01
```

Relative differences of 8e-16 and 5e-16 — floating-point noise. **The objective cannot tell
the two tiers apart.** Note what the second line means concretely: the fitted solution and its
mirror image are *equally good*, and they differ by moving 0.93 of diagonal variance into or
out of the quantity the campaign reports as the VA arm's tier-2 `Sigma_hat`.

## A12. It is reachable, not merely theoretical

Same script, TEST B. Two optimisations from mirrored starts, everything else identical:

| start | final objective | tier-2 psi | tier-4 psi | SUM | tier-4 share |
|---|---|---|---|---|---|
| tier2 high (0.90 / 0.05) | 1798.876040 | 9.026530e-01 | 4.198252e-10 | 0.902653 | **0.00%** |
| tier4 high (0.05 / 0.90) | 1798.876040 | 4.530212e-10 | 9.026522e-01 | 0.902652 | **100.00%** |

Objective difference **2.750e-08**; row-level sum difference **8.3e-07**. The *sum* is
determined by the data to 6 significant figures. The *split* is determined by nothing but the
start. This is the two-corner optimum the symmetry predicts, reached in practice.

**Why a corner here:** the marginal model sees only `sd2[t]^2 + sd4[t]^2`, but the ELBO's
variational family is a product over tiers and is *not* closed under the rotation that mixes
them, so splitting the variance across two mean-field blocks is somewhat worse than loading
one. Run to convergence, the ELBO drifts to a corner — and there are two, exactly equal. The
ridge between them is very nearly flat rather than exactly flat, which matters in practice:
§A17 shows the harness's own configuration **stalls partway along it** instead of reaching
either corner. So the reported split is not a two-way choice; it is an arbitrary point on a
one-dimensional near-flat direction.

## A13. Q1 answered numerically — yes, and the magnitude is large

`.d108_va_tier_sigma(par, layout, 3L, 4L, T)` (`harness.R:304`) reports
`Sigma_hat_tier2 = Lambda_phy Lambda_phy' + diag(psi_tier4)`. The Laplace arm's tier-2
`Sigma_hat` structurally cannot contain a row-level diagonal at all — its phylo Psi is
`Psi_phy ⊗ A` and collapses to 1.98e-08 under this DGP (§4b). So the two arms' tier-2
`Sigma_hat` differ by `diag(psi_tier4)`, which at this cell can be **anywhere from 0 to 0.9027
per element** — 0.9027 at the tier-4 corner (§A12), 3.4e-09 at the tier-2 corner (§A13's
`n_starts = 1` run), and 0.4916 where the harness's own default actually lands (§A17). For
scale, the true tier-2 diagonal here is `diag(Lambda2 Lambda2')` 0.2118 **+** `psi2` 0.7595 =
0.9713 under the harness's current (as-is) estimand, and 0.2118 under
`PROTOCOL.md:382-383`'s estimand. The spurious component is therefore up to **93% of the as-is
truth, or 4.3× the protocol truth**. Not immaterial.

## A14. The health gate is blind to this

`admitted <- length(healthy_id) >= 3L && agreement`, where
`agreement <- ... && agreement_range <= 1e-6` over the best three **objectives**
(`R/va-r3-proto.R:2149-2156`). Because the corners are exactly degenerate, four starts landing
in *different* corners agree to ~1e-8 and the gate **passes**, after which
`best_id <- healthy_id[which.min(objectives[healthy_id])]` (`R/va-r3-proto.R:2157-2158`) breaks
a numerical tie. The jitter table perturbs `log_sd_tier` directly
(`R/va-r3-proto.R:1106-1107`), so the starts genuinely do differ on the axis that selects the
corner. A gate built on objective agreement cannot detect a symmetry that leaves the objective
invariant.

The second gate is blind too. `variance_domain_ok <- max_projected_variance <= 4`
(`R/va-r3-proto.R:2170-2176`, gating `admitted` at `R/va-r3-proto.R:2176`) reads `report$v_by_obs`, which the template accumulates as a
*sum over tiers* of each tier's own quadratic form (`inst/tmb/gllvmTMB_va_r3.cpp:786-822`).
A sum is invariant under exchanging two identically-shaped tiers, so this gate returns the
same verdict in either corner as well.

## A15. A second, smaller divergence found on the way

The VA **gaussian** path carries a free per-trait residual `log_sigma`
(`R/va-r3-proto.R:1816-1833`, "log_sigma free only on Gaussian traits";
`inst/tmb/gllvmTMB_va_r3.cpp:387`). The Laplace gaussian control does **not** — it is
auto-suppressed (`R/fit-multi.R:4794-4808`, §4a). Measured
(`dev/design108-recovery/noether-diag7.R`, same cell, gaussian):

```
tier2 psi mean = 7.983062e-09      tier4 psi mean = 7.983062e-09    (equal to every digit)
free log_sigma^2 mean = 1.152265   truth psi1+psi2+gauss_sd^2 = 1.628307
```

Both diagonal tiers collapse and the free residual takes the row-level variance. Note the two
tiers are equal *to every printed digit* — the symmetry again, this time from a symmetric start
that the optimiser never broke. This does not affect the campaign directly (its VA arms are
binomial_probit, `harness.R:270`), but it means a gaussian VA control would not be comparable
to the gaussian Laplace control either.

## A16. Q3 — the minimal correct declaration

The VA arm's phylogenetic Psi must be `Psi_phy ⊗ A`, matching the Laplace engine
(`src/gllvmTMB.cpp:1181-1208`) and the VA-R3 prototype's own stated requirement
(`R/va-r3-proto.R:356-359`: "a structured low-rank tier **plus a structured diagonal Psi
tier** over the SAME tree"). The engine already supports this — `tier_structured` is applied
per tier and is kind-agnostic (`inst/tmb/gllvmTMB_va_r3.cpp:646`, with the level-count check at
`inst/tmb/gllvmTMB_va_r3.cpp:465-466`). Only the harness's declaration is wrong.

**Change `harness.R:231-232` — two tokens:**

```r
## before
    list(kind = "diagonal", dim = as.integer(T), level_id = as.integer(unit - 1L),
         structured = FALSE, label = "phylo_psi")
## after
    list(kind = "diagonal", dim = as.integer(T), level_id = as.integer(lid_dense),
         structured = TRUE,  label = "phylo_psi")
```

`lid_dense` is already in scope in **both** route branches — the augmented branch sets it from
`st$node_of_species[unit]` and the tips-only branch from `unit - 1L` (`harness.R:226`) — and in
both cases `n_levels` then equals `nrow(structured$Ainv)`, which is what
`.va_r3_build_tiers()` requires. So the one change is correct for both routes. I did **not**
edit `harness.R`; this is a specification.

### Verification of the fix

`dev/design108-recovery/noether-diag9.R` builds the corrected declaration and re-runs both
tests. N=100, T=10, q=1, binomial_probit:

```
  kind       : dense | diagonal | dense    | diagonal
  label      : latent| psi      | phylo    | phylo_psi
  n_levels   : 100   | 100      | 198      | 198
  structured : FALSE | FALSE    | TRUE     | TRUE

  tier2 variational block = 100 x 10 = 1000 params
  tier4 variational block = 198 x 10 = 1980 params
  => tiers 2 and 4 exchangeable?  FALSE  (block sizes DIFFER)
```

The symmetry is gone **by construction** — the blocks are not even the same length, so the
swap of §A11 cannot be formed. And empirically, the mirrored starts of §A12 no longer tie:

| | before the fix | after the fix |
|---|---|---|
| objective difference between mirrored starts | **2.750e-08** | **5.178177** |

That is the whole finding, inverted: the confound was that the two starts were
indistinguishable; under the fix they are distinguishable by 5.2 log-likelihood units.

### An honest caveat on the fix — it is NOT yet shown to fit well

Both post-fix runs hit the iteration limit (`conv = 1`) and drove the phylo Psi to
**17.67** and **26.62** respectively, when the truth under the *current* DGP is exactly
**zero** (`dgp.R:133` makes the tier-2 Psi iid across species, so there is no phylogenetically
structured Psi in the data at all). Two explanations I cannot separate on this evidence:

1. My test used a bare `stats::nlminb` on the objective, bypassing `.va_r3_fit()`'s
   factor-analytic warm start, 4-start jitter and health gate.
2. A genuine flat direction: when a structured tier's variational mean collapses to zero, `eta`
   stops depending on its `sd`, which is then constrained only through the KL — the classic
   variational scale-degeneracy, and exactly what one expects when a tier is asked to fit a
   component the data does not contain.

**These two fixes are therefore coupled.** The VA declaration fix should be validated against
the *fixed* DGP (§8 fix 1, where the phylo Psi is genuinely non-zero), not against the current
one. Validating it against the current DGP asks the corrected tier to estimate a zero variance
on a boundary, which is the worst case and tells you little.

## A17. It is not hypothetical — the harness's OWN configuration hits it

Everything above used either a hand-built parameter vector (§A11) or a deliberately mirrored
start (§A12). The remaining question was whether `.va_r3_fit()`'s own machinery can land off
the safe corner. `dev/design108-recovery/noether-diag10.R` runs the harness's default —
`n_starts = 4L` (`harness.R:457`), binomial_probit, augmented route, nothing hand-set:

```
seed 1 | n_starts=4 admitted=FALSE healthy=0 | obj=1798.7926
        psi2=4.4052e-01  psi4=4.9156e-01  SUM=0.9321   tier-4 share = 52.74%
        VA tier-2 Sigma_hat diag mean = 2.4122  ( = LpLp' 1.9206 + psi4 0.4916 )
        truth tier-2: L2L2' 0.2118 + psi2 0.7595
```

Compare that with §A13's `n_starts = 1` run on **the same data**:

| harness configuration | objective | tier-2 psi | tier-4 psi | tier-4 share |
|---|---|---|---|---|
| `n_starts = 1` (§A13, the pilot's setting) | 1798.792580 | 9.3208e-01 | 3.3815e-09 | **0.00%** |
| `n_starts = 4` (`run_cell()`'s default) | 1798.7926 | 4.4052e-01 | 4.9156e-01 | **52.74%** |

**Same data, same code, same objective to seven significant figures, and a tier-4 share of 0%
versus 53%.** No hand-crafted start was needed — only the harness's own `n_starts` default,
which is exactly what the campaign will run. The reported VA tier-2 `Sigma_hat` diagonal
differs between these two runs by **0.4916 per element**: +51% of the true as-is tier-2
diagonal (0.9713), or **+232% of the protocol estimand** (0.2118).

Note also that the fit stalls at an *interior* point (52.74%) rather than a corner, with
`healthy = 0` starts. That is the expected behaviour on an exactly flat ridge: the optimiser
stops wherever it happens to be along it. The reported split is not even a choice between two
corners — it is an arbitrary point on a one-dimensional flat direction.

*(Two further seeds were queued at the same settings and had not finished when this was
written; their outcome is **not** part of the verdict and no number from them is reported here.
The verdict does not rest on a frequency estimate: §A11's exchange test is exact and holds at
every parameter value, so the degeneracy is a property of the model as declared, not of how
often an optimiser happens to fall off it. The two runs already in hand are enough to show it
is reachable from the harness's own settings.)*

### What this does to the campaign's headline number

The Laplace arm's tier-2 `Sigma_hat` cannot contain a row-level diagonal at all (§4b, §A13).
The VA arm's contains an arbitrary fraction of it. So `rel_frob_tier2(VA)` and
`rel_frob_tier2(Laplace)` are **not measurements of the same quantity**, and their difference —
which is the campaign's entire research question (`PROTOCOL.md:114-125`) — would be reporting a
declaration artifact whose size is set by where the optimiser stopped. This is not a bias both
arms share and that partly cancels; it is present in one arm and structurally absent from the
other.

**Fix §A16 before the grid is bought.** It is a two-token change and it is the cheapest item on
the whole remediation list.

---
---

# ADDENDUM 2 (2026-08-02) — mismatch 2: what each arm's `Sigma_hat` actually contains

**Context.** The DGP now exposes `Sigma_B_loadings`, `Sigma_B_total`, and `Sigma_B` as a
back-compat alias for the total (`dgp.R:182-205`). All 8 scoring sites in `harness.R` still
read the alias, so the harness is still scoring against the TOTAL while `PROTOCOL.md:453`
defines `rel_frob` on the loadings-only `Sigma_B`. The coordinator's question: is the naive
"swap `Sigma_B` → `Sigma_B_loadings`" correct, and does it differ per arm?

**Short answer: the naive swap is WRONG and would create a fresh mismatch.** All four arms
extract the TOTAL. Their current pairing against `Sigma_B` (= `Sigma_B_total`) is
*correctly paired*; what is wrong is that the total is not the protocol's estimand. The fix is
to make each arm also expose a loadings-only `Sigma_hat` and record both — not to repoint the
truth alone.

## B1. A correction to the brief's line numbers

`.d108_fit_va` ends at **`harness.R:333`**, `.d108_fit_laplace` at **`:417`**, and
`.d108_fit_gaussian_control` at **`:486`** (function heads at `:273`, `:382`, `:450`). The
brief has `:417` and `:486` swapped — `:417` is Laplace, `:486` is the gaussian control. Worth
fixing before the edit is applied, since the two need the same change but the surrounding code
differs.

## B2. Per arm, per tier: what `Sigma_hat` contains — measured

`dev/design108-recovery/noether-diag11.R`, one cell, N=120, T=8, q=1, seed=1, corrected DGP.

First, the DGP's own names check out and the two estimands now differ materially:

```
tier1: max|Sigma_B - Sigma_B_total| = 0.000e+00        (alias confirmed)
       max|Sigma_B_total - Sigma_B_loadings - diag(psi)| = 1.11e-16
       diag means: loadings 0.2839  psi 0.6401  total 0.9240
       rel_frob(loadings, total) = 0.5689
tier2: max|Sigma_B - Sigma_B_total| = 0.000e+00
       max|Sigma_B_total - Sigma_B_loadings - diag(psi)| = 2.22e-16
       diag means: loadings 1.0854  psi 0.6848  total 1.7702
       rel_frob(loadings, total) = 0.2118
```

For the two Laplace-family arms, `part = "total"` minus `part = "shared"` is **exactly
diagonal** (max off-diagonal difference 0.000e+00 at both levels, both arms) and equals
`part = "unique"$s` to 1e-16. So `part = "total"` is unambiguously `Lambda Lambda' + diag(psi)`.

| arm | tier | `Sigma_hat` as extracted today | contains |
|---|---|---|---|
| `gaussian_control` (`:486`) | 1 (`level="unit"`) | `extract_Sigma(part="total")` | **TOTAL** |
| `gaussian_control` | 2 (`level="phy"`) | `extract_Sigma(part="total")` | **TOTAL** |
| `laplace` (`:417`) | 1 | `extract_Sigma(part="total")` | **TOTAL** |
| `laplace` | 2 | `extract_Sigma(part="total")` | **TOTAL** |
| `va_augmented` / `va_tips_only` (`:333`) | 1 | `.d108_va_tier_sigma(...,1,2,T)$Sigma_B` | **TOTAL** |
| `va_augmented` / `va_tips_only` | 2 | `.d108_va_tier_sigma(...,3,4,T)$Sigma_B` | **TOTAL** |

`.d108_va_tier_sigma()` returns `Sigma_B = Lambda %*% t(Lambda) + diag(psi, T)`
(`harness.R:203`) — the same total, built by hand rather than by `extract_Sigma()`.

**No arm differs from the others on this axis. There is no fifth mismatch here.** That is a
genuine (and welcome) null result, and it only became true today: before the phylo-Psi
declaration fix, the VA arm's tier-2 total contained an *unstructured row-level* diagonal while
the Laplace arm's contained a *structured* one — different objects wearing the same name. Both
are now `Psi_phy ⊗ A`, confirmed on the live layout: `n_levels 120 | 120 | 238 | 238`,
`structured FALSE | FALSE | TRUE | TRUE` (238 = 2N−2 augmented nodes).

## B3. Why the naive swap would be a fresh mismatch — measured

Pairing a TOTAL `Sigma_hat` against `Sigma_B_loadings` is exactly the error this whole
document is about. Measured on the same cell:

| arm / tier | `rel_frob(total, Sigma_B_total)` | `rel_frob(shared, Sigma_B_loadings)` | `rel_frob(total, Sigma_B_loadings)` ✗ |
|---|---|---|---|
| laplace, tier 1 | 0.7179 | 0.9479 | **1.6360** |
| laplace, tier 2 | 0.6759 | 0.7912 | **0.7914** |
| gaussian_control, tier 1 | 0.3722 | 0.4214 | **1.2945** |
| gaussian_control, tier 2 | 0.4851 | 0.5824 | **0.5880** |

The naive swap would report **1.6360 instead of 0.7179** for the Laplace tier-1 cell — a 2.3×
inflation that is pure estimand mismatch. The coordinator was right not to guess.

## B3b. What is empirical here, and what is not

Being precise about the evidential status of each row of the §B2 table, because "settled by
reading" is what let mismatch 2 survive:

- **`laplace` and `gaussian_control`, both tiers — fully empirical.** `extract_Sigma()` is an
  opaque package function, so its `part = "total"` semantics were the genuine unknown. Measured
  on a live fit: `total − shared` has max off-diagonal 0.000e+00 at both levels in both arms,
  and equals `part = "unique"$s` to ≤8.8e-16. `part = "total"` is the total. No ambiguity left.
- **VA arm — construction verified in the harness's own code, layout verified empirically,
  `rel_frob` numbers NOT obtained.** The object is not built by a package function: it is built
  one line inside this harness, `Sigma_B = Lambda %*% t(Lambda) + diag(psi, T)`
  (`harness.R:203`), so what it contains is not in doubt. What *was* in doubt — which tiers the
  layout actually assigns after the phylo-Psi fix — I did verify on the live validated object
  for this cell: `n_levels 120 | 120 | 238 | 238`, `structured FALSE | FALSE | TRUE | TRUE`,
  with `extra 2: kind=diagonal dim=8 structured=TRUE label=phylo_psi`. So tier 4 is now the
  structured phylo Psi, matching the Laplace arm's `Psi_phy ⊗ A`.
  **The VA fit itself did not finish inside this slice** (the post-fix structured tier adds a
  238×8 variational block and is markedly slower — the same slowness §A16 flagged), so I report
  no VA `rel_frob` figure. Nothing in the edit below depends on one: the edit only needs to know
  *which object* the arm returns, and that is settled by `harness.R:203`. If you want the belt
  and braces, re-run `noether-diag11.R` with `D108_VA=1` at leisure and check the printed
  `Sigma_B == Lambda Lambda' + diag(psi)` line reports ~1e-16.

## B4. The exact minimal edit — record BOTH, per the coordinator's preferred shape

Every arm already *has* the loadings-only object; none of them returns it. Three extraction
sites gain it, then the 8 scoring sites gain a second comparison. No new fitting, no new
extraction cost beyond one extra `extract_Sigma(part = "shared")` call per Laplace-family arm.

### Edit 1 of 4 — `.d108_fit_va`, `harness.R:333`

`.d108_va_tier_sigma()` already returns `Lambda` (`harness.R:203`); it is simply discarded.

```r
## before (harness.R:333)
       Sigma1 = s1$Sigma_B, Sigma2 = s2$Sigma_B)
## after
       Sigma1 = s1$Sigma_B, Sigma2 = s2$Sigma_B,
       Sigma1_loadings = if (is.null(s1)) NULL else s1$Lambda %*% t(s1$Lambda),
       Sigma2_loadings = if (is.null(s2)) NULL else s2$Lambda %*% t(s2$Lambda))
```

### Edits 2 and 3 — `.d108_fit_laplace` (`harness.R:412-417`) and `.d108_fit_gaussian_control` (`harness.R:481-486`)

**Identical change in both.** Insert after the existing `S1` / `S2` extraction:

```r
  S1L <- tryCatch(gllvmTMB::extract_Sigma(fit, level = "unit", part = "shared",
                                          link_residual = "none")$Sigma,
                 error = function(e) NULL)
  S2L <- tryCatch(gllvmTMB::extract_Sigma(fit, level = "phy", part = "shared",
                                          link_residual = "none")$Sigma,
                 error = function(e) NULL)
```

and extend the return list with `Sigma1_loadings = S1L, Sigma2_loadings = S2L`.

Keep `link_residual = "none"`: for `part = "shared"` it is inert (the link residual is purely
diagonal), but making the two calls differ invites exactly the drift this exercise is about.
The early `return()` branches on fit error need no edit — `$` on an absent name gives `NULL`,
and `score()` already maps `NULL` to `NA_real_` (`harness.R:530-533`).

### Edit 4 — `run_cell()`: the 8 scoring sites, `mkrow()`, and the gate

**(a) Kill the alias at all 8 sites.** `sim$truth$tier1$Sigma_B` → `sim$truth$tier1$Sigma_B_total`
(and `tier2`) at `harness.R:539, 540, 547, 548, 560, 561, 575, 576`. This is a no-op in value —
the point is that a reader can no longer mistake which estimand is being scored.

**(b) Add the loadings comparison.** Add one helper next to `score()`:

```r
  score_both <- function(hat_total, hat_load, tier) {
    list(tot = score(hat_total, tier$Sigma_B_total),
         load = score(hat_load,  tier$Sigma_B_loadings))
  }
```

and at each of the four arms, e.g. for the control:

```r
  gc1 <- score_both(gcf$Sigma1, gcf$Sigma1_loadings, sim$truth$tier1)
  gc2 <- score_both(gcf$Sigma2, gcf$Sigma2_loadings, sim$truth$tier2)
```

**(c) `mkrow()` (`harness.R:514-528`) gains four columns**, and — mirroring exactly what the
DGP did with `Sigma_B` — the two existing columns keep their present meaning rather than being
silently repointed:

| column | meaning |
|---|---|
| `rel_frob_tier1/2` | **unchanged** = the total. Back-compat alias; `job1_floor_sweep.R:57-63` keeps working. |
| `rel_frob_total_tier1/2` | explicit name for the same number |
| `rel_frob_loadings_tier1/2` | **new headline** — `PROTOCOL.md:453`'s estimand |
| `bias_loadings_tier1/2` | signed bias on the loadings estimand |

Repointing `rel_frob_tier1` to mean the loadings would be a silent change of meaning in an
existing column — the precise failure mode that let mismatch 2 survive all day. Do not do it.

**(d) Point the gate at the headline.** `.d108_positive_control_gate()` (`harness.R:592-597`)
reads `rel_frob_tier1/2`; switch those four references to `rel_frob_loadings_tier1/2`, and
likewise `job1_floor_sweep.R:57-63`. This matters: §B5 shows the `_total` column is
contaminated for the control arm and the `_loadings` column is not.

## B5. The gaussian `log_sigma` asymmetry — recommendation

**First, a scoping fact that de-fangs it.** The gaussian control arm is fit with the shipped
**Laplace** engine only — `.d108_fit_gaussian_control()` (`harness.R:450`) calls
`gllvmTMB::gllvmTMB(..., family = stats::gaussian())`, and the function's own comment says it
"always uses Laplace regardless of which arms are under test". There is **no VA gaussian arm
in the harness**, so the `log_sigma` asymmetry is currently latent, not active. It becomes a
sixth mismatch only if someone adds a VA gaussian control — which is a natural thing to want,
and is why it needs a written rule now rather than later.

**The asymmetry, restated.** The Laplace gaussian path auto-suppresses `sigma_eps`
(`R/fit-multi.R:4794-4808`) because the unit-tier Psi is at per-row resolution, so the row-level
residual lands in `diag(Psi_unit)`. The VA gaussian path keeps a free per-trait `log_sigma`
(`R/va-r3-proto.R:1816-1833`; `inst/tmb/gllvmTMB_va_r3.cpp:387`), which absorbs it instead —
measured in §A15: `log_sigma^2` mean 1.152265 with both diagonal tiers collapsing to ~8e-09.
Same data, same nominal model, the residual in a different parameter.

**Recommendation, in order.**

1. **Make the loadings estimand the headline (Edit 4d) and the problem stops mattering.** The
   entire class of row-level-residual placement questions — `gauss_sd`, `sigma_eps`,
   `log_sigma`, OLRE absorption — touches only the *diagonal*. `Lambda Lambda'` is invariant to
   all of it. This is the single highest-value line in this addendum: it retires mismatch 3 and
   the `log_sigma` asymmetry from the headline in one move, and it is what `PROTOCOL.md:453`
   already specifies.

2. **Keep the control Laplace-only, and say so in `PROTOCOL.md`.** Record it as a deliberate
   constraint with the reason, not as an accident of how the harness happens to be written.

3. **If a VA gaussian control is ever added**, suppress `log_sigma` to mirror
   `R/fit-multi.R:4794-4808` — fix it at a small constant via `.va_r3_fit(fixed_global = ...)`
   so the unit-tier Psi absorbs the row-level residual in *both* engines. Do not leave it free
   and compare `_total` columns across engines.

4. **Flag the `_total` column of the control arm as not directly comparable.** The control adds
   its own `gauss_sd` noise (`harness.R:454`) that has no counterpart in `sim$truth`. Measured
   on the same cell (`dev/design108-recovery/noether-diag12.R`):

   ```
   TIER 1 (unit) -- where the residual lands
     psi_hat mean = 0.8562   truth psi1 = 0.6401   truth psi1 + gauss_sd^2 = 0.8001
     rel_frob(total,  Sigma_B_total)                   = 0.3722
     rel_frob(total,  Sigma_B_total + diag(gauss_sd^2)) = 0.2676   <- residual-aware
     rel_frob(shared, Sigma_B_loadings)                 = 0.4214   <- immune to gauss_sd
   TIER 2 (phy) -- the residual must NOT appear here
     rel_frob(total,  Sigma_B_total)                   = 0.4851
     rel_frob(total,  Sigma_B_total + diag(gauss_sd^2)) = 0.4748   <- WRONG for tier 2
     rel_frob(shared, Sigma_B_loadings)                 = 0.5824
   ```

   `gauss_sd^2` accounts for a 28% reduction in the tier-1 total-column error (0.3722 → 0.2676)
   and belongs to **tier 1 only**. So either add `+ diag(gauss_sd^2)` to the control arm's
   tier-1 total-truth *and nothing to tier 2*, or simply record the control's `_total` columns
   as diagnostic-only. Given recommendation 1, the second is cleaner and less error-prone —
   a residual-aware truth that is right for one tier and wrong for the other is a trap of the
   same family as the one this document opened with.

## B6. Summary of the estimand state after this addendum

| # | mismatch | status |
|---|---|---|
| 1 | DGP tier-2 Psi iid, model's is `Psi_phy ⊗ A` | **FIXED** in `dgp.R` (Z2 now a GMRF over the same `Ainv`) |
| 2 | harness scores the TOTAL; `PROTOCOL.md:453` specifies loadings-only | **specified here** (§B4); not yet applied |
| 3 | control's own `gauss_sd^2` has no counterpart in the truth | **retired from the headline** by §B4d + §B5.1; still contaminates the `_total` columns of the control arm's tier 1 (measured: 0.3722 → 0.2676 when accounted for) |
| 4 | VA phylo-Psi declared unstructured → labelling symmetry | **FIXED** in `harness.R` (verified live: 238 levels, `structured = TRUE`) |
| 5 | *(hypothesised: arms extract different objects)* | **DOES NOT EXIST.** All four arms return the TOTAL. Verified empirically for the two Laplace-family arms; established from `harness.R:203` plus the verified live layout for the VA arms. |
| 6 | *(hypothesised: VA gaussian `log_sigma` asymmetry)* | **LATENT, not active** — there is no VA gaussian arm (`harness.R:450` fits the control with Laplace only). Rule written in §B5 for if one is added. |

### What I could not settle

- **No VA `rel_frob` number** (§B3b). The determination of *what* the VA arm returns does not
  depend on it, but the numeric confirmation is outstanding.
- **The phylo Psi is badly under-recovered at this size, even post-fix.** Measured tier-2
  `psi_hat`: 0.0530 (laplace) and 0.1768 (gaussian control) against a truth of 0.6848. That is
  N=120, T=8, q=1 — small enough that this may be pure finite-sample, and one cell cannot tell.
  But it is the same tier whose loadings already refused to shrink with N (§7), so it wants
  watching on the ladder rather than assuming away.
- **Whether `rel_frob_loadings` behaves better than `rel_frob_total` on the ladder.** The
  loadings estimand is immune to residual placement, which is why it should be the headline —
  but §7's open question (does the phylo tier's error shrink with N at all?) is unaffected by
  this addendum and remains the gating unknown before the grid is bought.

## B7. LANE NOTE — a concurrent edit to `harness.R` is already in flight

While this addendum was being written, `harness.R` was modified by another lane (working tree
dirty, not committed). It has already applied edits 1–2 of §B4, under **different field names
than my spec**:

| §B4 spec | what is actually in the file now | status |
|---|---|---|
| `.d108_va_tier_sigma` returns `Lambda` | returns `Sigma_B_loadings` directly (`harness.R:206-210`) | **done**, better than my spec |
| `.d108_fit_va` → `Sigma1_loadings` | `Sigma1_load` / `Sigma2_load` (`harness.R:341-342`, plus both error branches) | **done**, different name |
| `.d108_fit_laplace` → `S1L`/`S2L` + return | `Sigma1_load` / `Sigma2_load` (`harness.R:426-437`) | **done** |
| `.d108_fit_gaussian_control` | **NOT edited** — still returns only `Sigma1`/`Sigma2` (`harness.R:505-506`) | **OUTSTANDING** |
| 8 scoring sites | unchanged, still the `Sigma_B` alias | **OUTSTANDING** |
| `mkrow()` columns | unchanged | **OUTSTANDING** |
| gate | unchanged | **OUTSTANDING** |

**Use `Sigma1_load` / `Sigma2_load`, not my `Sigma1_loadings`** — the in-flight name is already
in three functions and is fine; what matters is that all four arms use one name. **The line
numbers in §B4 are now stale**: the concurrent edit shifted everything below `harness.R:200`.
Current positions are given in the reply. I have not touched `harness.R`.

The single most important outstanding item is the **gaussian control**, because it is the arm
the whole §B5 recommendation turns on: if the other three arms gain a loadings column and the
control does not, the control's `rel_frob_loadings_*` will be silently `NA` (via `score()`'s
`NULL` guard at `harness.R:550-553`) and the positive-control gate will pass vacuously on
missing data. That is the same failure shape as everything else in this document.
