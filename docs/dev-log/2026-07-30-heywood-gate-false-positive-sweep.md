# Calibrating the runaway-loading gate in `check_gllvmTMB()`

Date: 2026-07-30. Author: Claude. Lane: `claude/heywood-gate-20260730`.
Predecessor: `docs/dev-log/handover/2026-07-29-claude-handover-vgh-heywood-gate.md`.

Provenance markers: **RECORDED** (measured in this lane, script and CSV cited),
**DERIVED** (arithmetic from a recorded number), **AGENT-INFERRED** (inference,
not measured).

---

## 1. The defect, reproduced

`check_gllvmTMB()` is exported. On a Bernoulli fit whose implied covariance is
wrong by a factor of 156,645, it reported the loading row as **PASS**:

```
check  : binomial_prevalence_loading
status : PASS
value  : 12 prevalence=0.617; max_loading=949; relative_loading=6980; saturated_fit=1
```

**RECORDED**, reproduced from `dev/vgh/p3-existing-check-evidence.R` (seed 3,
n = 60, p = 12, q = 2, Bernoulli); `rel_frob = 156645.4`, `convergence = 0`,
`pdHess = TRUE`. The numbers match the predecessor handover exactly.

Both disjuncts of the rule were already true — `relative_loading = 6980` against
a threshold of 8, and `saturated_fit = 1` against 0.5. The row still passed,
because `R/diagnose.R:464` required `extreme_prevalence` as a **conjunct**:

```r
tab$flag <- tab$extreme_prevalence & (tab$dominant_loading | tab$saturated_fit)
```

The trait sits at prevalence 0.617, so the row could not fire however far the
loading ran. The recorded cause is quasi-complete separation, which is a property
of the fitted linear predictor, not of the marginal rate — so it produces a
runaway loading at perfectly ordinary prevalence, which is exactly the case the
conjunct excludes.

## 2. What had to be measured before changing it

This is a shipped exported diagnostic. Loosening it changes what existing users
are told about fits that currently pass, so the false-positive rate is the gate,
not an afterthought. The predecessor handover states the trap plainly: the VGH
screen died because its band flagged **100% of healthy gaussian fits**.

Two facts shaped the design of the sweep.

**`relative_loading` is already scale-relative, so the obvious worry is the wrong
one.** It is a trait's largest loading divided by `max(median, mad)` of the
per-trait largest loadings (`R/diagnose.R:321-379`), i.e. a within-fit,
cross-trait ratio. The response scale cancels, so "a binomial variance is bounded
but a gaussian variance is not" does not by itself break it. The real exposure is
that **the denominator collapses when most traits genuinely load near zero** — a
sparse but entirely legitimate loading structure inflates the ratio on a healthy
fit. That is a property of the *loading structure*, not the family, and no amount
of family-stratified reporting would have found it.

**Healthy must be defined by recovery, not by convergence.** 59 of 70 recorded
degenerate fits reported `convergence = 0`, and the reproduction above has
`convergence = 0, pdHess = TRUE`. Screening the "healthy" set on the optimizer
would seed it with the exact pathology being calibrated against.

## 3. Sweep design

Script: `dev/heywood/fp-sweep.R`. Analysis: `dev/heywood/fp-analyse.R`.
Output: `dev/heywood/fp-sweep-full.csv`.

Data-generating process: `Lambda` (p x q) with per-trait loading scale set by
`dgp` below, `Z ~ N(0, I)` (n x q), `eta = Z Lambda' + 1 B'`, response drawn from
the family. The fit is the matching model,
`y ~ 0 + trait + latent(0 + trait | site, d = q, unique = FALSE)`.

| Factor | Levels |
|---|---|
| `dgp` (true loading structure) | `homog` (all traits sd 0.7); `sparse50` (half the traits sd 0.05, rest sd 1.0); `sparse75` (three quarters sd 0.05) |
| `family` | binomial, poisson, gaussian |
| `n` (units) | 60, 150, 400 |
| `p` (traits) | 5, 12, 25 |
| `q` (rank) | 2, 3, 5 (cells with `q >= p` dropped) |
| seeds | 60 per binomial cell, 20 per gaussian/poisson cell |

Seeds are spent where they decide the threshold. Only binomial fits produce the
row at all — `.gllvmTMB_binomial_prevalence_loading_row()` returns `NULL` when the
fit has no binomial rows — so binomial carries triple replication to pin the
healthy null tightly, and gaussian/poisson are carried as transport evidence for
the statistic itself.

`sparse75` is adversarial by construction: with three quarters of traits loading
near zero, the median of the per-trait maxima sits *inside* the weak group, so the
denominator is as small as a healthy fit can plausibly make it.

**Health classification**, on `G = Lambda Lambda'` against the known truth, using
relative Frobenius error — a rotation-invariant functional, per the repo's
standing rule that raw `Lambda` is never compared:

- **healthy**: `rel_frob <= 0.5`
- **degenerate**: `rel_frob >= 5`
- **middle**: everything else, reported but never counted as either.

False-positive rate is `P(flag | healthy)` and detection is `P(flag | degenerate)`,
both computed on binomial fits only, since those are the only fits that produce
the row.

Three rules were scored on the same fits:

- **shipped** — `extreme_prevalence & (dominant | saturated)`
- **runaway_alone** — shipped, OR `relative_loading >= tau`
- **runaway_and_saturated** — shipped, OR (`relative_loading >= tau` AND the
  trait's fitted probabilities saturated)

## 4. Compute

Run locally: 16 cores, ~7,200 fits. **Deliberately not sent to Totoro**, against
the standing default that heavy campaigns scale out. The largest cell (n = 400,
p = 25, q = 5, binomial) is 16.6 s **RECORDED**, and the whole grid is under an
hour on 16 local cores, so installing gllvmTMB and its TMB toolchain on the remote
would plausibly have cost more than the run. Totoro's ControlMaster socket was
live and was checked before deciding. This is a judgement about *this* grid, not a
revision of the standing rule.

Results stay local per D-50; only the summary CSV is committed.

---

## 5. Results

7,200 fits, 12.0 CPU-hours. 376 (5.2%) failed outright with
`All 1 restarts failed.` — all binomial, all excluded from every rate below.
Those are loud failures the user sees, not silent ones. 6,824 usable fits, of
which 551 healthy and 1,465 degenerate binomial fits carry the rates.

### 5.1 The gate keys on a quantity the pathology does not move

**RECORDED.** Against 1,465 degenerate binomial fits the shipped rule
`extreme_prevalence & (dominant | saturated)` reported detection **0.0000**.

**That number must not be read as "the row is inert."** Across *all* 3,944
usable binomial fits — healthy, middle and degenerate alike — the worst trait's
marginal prevalence spans only **[0.20, 0.807]**, and **zero** fits reach the
`extreme_prevalence` gate. The data-generating process draws intercepts
`rnorm(p, 0, 0.3)` around mean-zero latent scores, so prevalence sits near 0.5
however far the loading runs. **The detection rate of 0 was forced by the design
and was deducible from the code without simulating anything.** (Caught by
adversarial review, not by the author. See §7.)

The defensible claim is stronger and more mechanistic. Among degenerate fits
`rl_max` spans **1.1 → 24,057** and `rel_frob` reaches **6.3e6**, while
|prevalence − 0.5| is essentially uncorrelated with the blow-up:

> **r = 0.036.**

Quasi-complete separation is a property of the fitted linear predictor, not of
the marginal rate. **The gate is not a high bar; it is the wrong bar.**

**The necessary limitation.** This does *not* show the row never fires. It still
reports a genuinely near-constant trait carrying a dominant loading — the
regime it was built for — which the untouched pre-existing fixture exercises and
which this change leaves working.

### 5.2 The null distribution moves with loading sparsity, not with family

**RECORDED**, healthy binomial `rl_max`:

| `dgp` | median | 90% | 99% | max |
|---|---|---|---|---|
| `homog` | 1.85 | 2.54 | 3.55 | 4.49 |
| `sparse50` | 3.59 | 6.28 | 9.55 | 12.07 |
| `sparse75` | 5.22 | 7.68 | 9.47 | 9.70 |

The ratio roughly triples as the true loading structure sparsifies, because the
denominator — the median per-trait maximum loading — collapses toward the weak
group. **This is the transport risk, and it is driven by the loading structure,
not by the response family.** The predecessor handover expected the risk to be
family-shaped ("a binomial response has bounded variance"); that framing points at
the wrong axis, because the statistic is already a within-fit ratio and the
response scale cancels.

It also grows with trait count. **RECORDED**, worst healthy binomial `rl_max`:

| p (traits) | 5 | 12 | 25 |
|---|---|---|---|
| max | 4.11 | 5.32 | 12.07 |

The row flags if **any** trait exceeds, so more traits means more chances, and the
upper tail keeps climbing. Community datasets routinely run well past p = 25, so
the chosen threshold must keep margin above the largest value swept.

### 5.3 Operating characteristic

**RECORDED**, binomial fits, 551 healthy / 1,465 degenerate:

| tau | FPR | TPR |
|---|---|---|
| 12 | 0.0018 (1/551) | 0.9706 |
| 15 | 0.0000 (0/551) | 0.9693 |
| 20 | 0.0000 (0/551) | 0.9659 |
| **25** | **0.0000 (0/551)** | **0.9631 (1,411/1,465)** |
| 30 | 0.0000 (0/551) | 0.9563 |
| 40 | 0.0000 (0/551) | 0.9352 |
| 60 | 0.0000 (0/551) | 0.8689 |

The first false positive appears at tau = 12.

**A saturation conjunct was tested and rejected as redundant.** Requiring the
worst trait's fitted probabilities to be saturated as well as the ratio to be
extreme gives *identical* FPR and TPR at every tau at or above 15 — every
degenerate fit with a runaway ratio is already saturated. It differs only at
tau = 8, and there its second term is evaluated on a trait this sweep did not
measure across the board, so adopting it would ship a clause with a partially
unmeasured false-positive rate. Rejected on that ground, not on its numbers.

### 5.4 The threshold does not transport beyond binomial

**RECORDED**, worst healthy `rl_max` by family, across all loading structures:

| binomial | gaussian | poisson |
|---|---|---|
| 12.07 | 42.09 | 71.86 |

**DERIVED**: if the gate were generalised to other families at tau = 25, healthy
`sparse75` fits would be flagged at **14.7% (poisson)** and **3.0% (gaussian)**.
That is a shipped-diagnostic false-positive rate one to two orders of magnitude
above what this row tolerates.

The row is binomial-only by construction, so this does not affect shipped
behaviour. **It is recorded as the fence against generalising the gate later on
the assumption that a number calibrated here carries over. It does not.**

---

## 6. Decision

**`loading_runaway_thresh = 25`**, flagging on its own:

```r
tab$flag <- (tab$extreme_prevalence &
  (tab$dominant_loading | tab$saturated_fit)) |
  tab$runaway_loading
```

- **Zero false positives** on 551 healthy binomial fits spanning three loading
  structures, n in {60, 150, 400}, p in {5, 12, 25}, q in {2, 3, 5}.
- **96.3% detection** (1,411 of 1,465) against the shipped rule's **0**.
- **2.07x margin** over the largest healthy value observed (12.07), which is the
  reason for 25 over 15: the healthy tail demonstrably grows with trait count
  (§5.2), so a 1.24x margin would be spent by a dataset with more traits than
  were swept. The cost is 0.6 percentage points of detection.
- The `dominant_loading` threshold of 8 **keeps** its extreme-prevalence conjunct.
  At 8 the ratio is a hint that needs corroboration — healthy sparse fits reach it
  routinely (`sparse75` median 5.22, 90th percentile 7.68). Only the runaway level
  stands alone. Nothing that flagged before stops flagging.

### 6.1 Two limits found after the calibration, by later review

**The ratio's blindness starts well before a pure common inflation.** In an
over-specified-rank run (binomial, truth `q = 2`, fitted `d = 3`), the shipped
threshold of 25 **missed 3 of 8 degenerate fits**, and those three were the
worst in the study (`rel_frob` 7,491 / 5,272 / 2,775); one was missed even at
the weaker `>= 8` bar. Mechanism: with 3 of 6 traits inflated, the robust centre
in the denominator straddles both groups and is itself inflated. **A within-fit
ratio degrades from the halfway mark, not only at the limit** — and users routinely
guess the rank. The instrument for that case is a *scale* statistic, not a ratio,
and none is wired yet (`communality > 1` is computed at `R/extractors.R:201` and
used by no row).

**The denominator was pooled across families.** It took the typical loading size
over every trait in the fit regardless of family, so a large-scale trait from
another family could set a binomial trait's yardstick. Measured on a fixture with
loadings `c(0.25, 0.2, 12 | 300, 280, 320)`: pooled gives the binomial runaway a
ratio of **0.08** (masked); restricted to the binomial traits it is **48**
(reported). Fixed here, with the first mixed-family test the row has ever had —
`grep -rn "relative_loading" tests/` previously returned nothing at all.

### 6.1a The second criterion: what a ratio cannot see, and the fix

§6.1 recorded that the ratio degrades when several traits inflate together. The
limiting case is exact and provable: **under `Lambda -> c * Lambda` every
per-trait maximum scales by `c`, the denominator scales by `c`, and
`relative_loading` does not move at all.** A uniformly inflated loading matrix
is invisible to it by construction, not by miscalibration.

An earlier pass rejected a scale statistic at AUC 0.466 — but that was measured
against the **psi** face, which it was never proposed for. **That rejection was
invalid**, and re-measuring it on the face it was meant for reverses the answer.

**MEASURED**, 360 binomial fits at an over-specified rank (truth `q = 2`, fitted
`d` in 2/3/4, `n` 60–200; `dev/heywood/scale-statistic-overrank.R`): the
shipped ratio catches 70 of 73 degenerate fits, and the worst miss has
`rel_frob = 6597`. `max_loading` catches **72 of 73 at FPR 0.0000**.

**Confirmed on the main 3,944-fit sweep**, which has the far larger healthy
sample:

| cut | sensitivity | false positives | adds over the ratio |
|---|---|---|---|
| `max_loading >= 4` | 0.9727 | 0 / 551 | 14 |
| **`max_loading >= 6`** | **0.9727** | **0 / 551** | **14** |
| `max_loading >= 10` | 0.9727 | 0 / 551 | 14 |

Performance is flat across every cut because the separation is enormous: the
worst healthy `max_loading` is **3.99** (99th percentile 3.25 or below in all
three loading structures; the excluded middle band tops out at 3.87), while the
degenerate 5th percentile is **25**. A cut at 6 sits 1.5x above the worst
healthy value and 4x below the degenerate tail.

**Why an absolute cut is legitimate here specifically.** The latent scores are
standard normal by identification, so a binomial loading *is* the trait's latent
SD in link units — the link supplies a real scale that a gaussian identity link
does not. This is exactly why the criterion is binomial-only, and why the same
number must never be reused for another family.

### 6.2 The stratified denominator, validated on real mixed-family fits

§6.1 demonstrated the pooled-denominator defect on a hand-built fixture. This
measures it on **180 real mixed-family fits** (3 binomial + 3 gaussian traits,
`n` 60/100, `q = 2`, 30 seeds), sweeping the gaussian traits' loading scale —
the axis the defect lives on. Both denominators are computed on the *same* fits,
so nothing is confounded. Label: relative Frobenius error of the **binomial
block** of `G` against its known truth. Script:
`dev/heywood/mixed-family-validation.R`.

**Detection of a degenerate binomial block at the shipped threshold of 25:**

| gaussian loading scale | pooled (old) | stratified (shipped) |
|---|---|---|
| ×1 | 4/5 (0.800) | 3/5 (0.600) |
| ×10 | 4/24 (**0.167**) | 22/24 (**0.917**) |
| ×100 | 0/37 (**0.000**) | 22/37 (**0.595**) |

**At a ×100 response scale the old behaviour detected nothing at all — 0 of 37.**
The mechanism is direct: the median ratio of the stratified to the pooled
`relative_loading` is 1.03 at scale ×1, 4.02 at ×10 and **30.24 at ×100**, so
pooling was dividing the binomial ratio by up to thirty.

**False positives: 0 at every scale, under both denominators.** The worst healthy
stratified ratio observed was 7.95, against a threshold of 25.

Two honest notes. At scale ×1 the stratified denominator detects 3/5 where
pooled detects 4/5 — a one-fit difference on five fits, i.e. noise, and the
regime where the two are expected to agree (their median ratio there is 1.03).
And 59.5% at ×100 is a large improvement on 0% but is not high: the fits still
missed are ones whose binomial block degenerates without a single-trait runaway,
which a per-trait ratio cannot see by construction.

### 6.3 Large p, multi-trial, and whether a third statistic is needed

**MEASURED**, 897 usable fits (`dev/heywood/arcC-threshold-coverage.R`). Three
gaps closed, each of which could have changed a shipped number.

**A. The healthy tail keeps accelerating — and the relative arm is at its limit.**
Worst healthy `rl_max` by trait count, extending the p = 5/12/25 series
(4.11 / 5.32 / 12.07) that justified choosing 25 over 15:

| p | 25 | 50 | **100** |
|---|---|---|---|
| worst healthy `rl_max` | 11.05 | 13.22 | **23.95** |
| 99th percentile | 9.35 | 12.00 | 19.11 |
| worst healthy `max_loading` | 2.95 | 3.79 | **4.69** |

**At p = 100 the worst healthy relative loading is 23.95 against a threshold of
25 — a margin of 4%.** The trend does not saturate, so `loading_runaway_thresh`
should be expected to false-positive somewhere beyond p = 100 **if it were the
only criterion**.

It is not, and that is what saves it. **The absolute arm is stable in p** —
worst healthy `max_loading` rises only 2.95 → 3.79 → 4.69 against a threshold of
6 — because it is a link-scale quantity that does not depend on how many traits
share the denominator. **Measured false positives at the shipped pair: 0 at every
p (0/246 healthy). Detection: 109/109 at every p.**

**This is the argument for having both arms.** A ratio degrades as the trait
count grows; an absolute magnitude does not. Neither is sufficient alone at
large p.

**B. Multi-trial binomial with `unique = TRUE`.** 354 healthy fits, 0 degenerate:
**false positives 0/354**. Worst healthy `rl_max` 21.65 (again close to 25),
worst healthy `max_loading` 4.07.

**C. A third statistic is not justified.** The shipped pair catches **109 of 109**
degenerate fits, so a rotation-invariant scale statistic (`g_norm_var`) has
nothing left to add. Recorded as a negative result so it is not re-proposed.

**Consequence for the reader.** Beyond roughly p = 100, `loading_runaway_thresh`
carries little margin and the absolute arm is doing the work. A user with several
hundred traits should not rely on the relative criterion alone.

### 6.4 Probit and cloglog

The row fires on `family_id == 1` regardless of link, but every calibration fit
used **logit**. That matters specifically for `loading_absolute_thresh`, whose
justification is *link-scale*: a loading is the trait's latent SD in link units.
**That argument is link-specific** — a probit coefficient is roughly 1.7x smaller
than the logit coefficient for the same probability curve, and cloglog is
asymmetric.

**MEASURED**, 634 usable fits (`dev/heywood/link-coverage.R`), p 12/25, n 60–400,
all three loading structures:

| link | false positives | detection | worst healthy `max_loading` | worst healthy `rl_max` |
|---|---|---|---|---|
| logit | **0 / 39** | 66/67 (0.985) | 3.18 | 11.46 |
| probit | **0 / 44** | **120/120 (1.000)** | 2.69 | 10.41 |
| cloglog | **0 / 47** | **78/78 (1.000)** | 2.85 | 14.32 |

**The thresholds transport.** Healthy `max_loading` stays under 3.2 on every
link against a threshold of 6, and the ordering is the predicted one — probit
smallest (2.69), consistent with its smaller coefficient scale, so 6 is
*conservative* there rather than dangerous.

One asymmetry worth recording: the degenerate 5th percentile of `max_loading` is
**25.04 (logit) but 8.53 (probit) and 9.71 (cloglog)**. The separation is real on
every link but the margin above 6 is roughly three times tighter off logit, so
`loading_absolute_thresh` should not be raised without re-measuring there.

The computed rule agrees with the **shipped** row on **633 of 634** fits (the
single disagreement is the extreme-prevalence path firing, which is correct).

### 6.5 A defect the tier sweep found in this lane's own fix

**MEASURED, and it would have shipped.** Extending coverage to the spatial tier
found that the **absolute** criterion added in this lane false-positives on
**every** spatial binomial fit.

`.gllvmTMB_max_loading_by_trait()` takes each trait's maximum across *every*
latent spec present. On a spatial fit:

| quantity | value |
|---|---|
| `max\|Lambda_B\|` (unit tier) | **1.879** |
| `max\|Lambda_spde\|` | **70,792** |
| pooled `max_loading` | 70,792 → absolute arm **fires** |
| shipped row | **WARN** (on a fit whose unit tier is healthy) |

**The cause is a parameterisation, not a pathology.** The absolute threshold is
justified *only* because the latent scores are standard normal by
identification, which makes a loading the trait's latent SD in link units. SPDE
loadings multiply **basis coefficients** carrying their own `sqrt(4*pi)*kappa`
normalisation, so they are not on that scale at all and the justification simply
does not apply to them. Arc A's `reference_traits` fix restricts by **family**,
not by **tier**, so it gave no protection here.

**Fix:** the absolute arm is judged on `max_loading_unit` — the maximum over the
`unit` and `unit_obs` tiers only. The pooled `max_loading` is still reported in
the row's value string, and the **relative** arm still uses the pooled
denominator, which is correct: a ratio is scale-free, and `rl_max` on the same
fit was a healthy **1.85** throughout. After the fix the row reports **PASS**.

**Note the inversion, because it is the argument for carrying both arms.** At
large p the *relative* arm is the fragile one (§6.3, 23.95 against a threshold of
25) and the absolute arm is stable. On a structured tier the *absolute* arm is
the fragile one and the ratio is stable. **Each arm covers the other's failure
mode**, and neither would be safe alone.

**Measured false-positive rate, after the fix.** The earlier failure to obtain a
healthy spatial fit was a fault in the data-generating process, not the package:
single-trial Bernoulli at n = 80 with two competing latent structures is close
to the hardest case available. **Multi-trial** binomial supplies roughly ten
times the information per cell and converges cleanly.

**MEASURED**, 64 fits (n 200/300 sites, p 6/8, 10/20 trials;
`dev/heywood/spatial-fpr.R`), 61 healthy:

| | value |
|---|---|
| **false positives at the shipped thresholds** | **0 / 61** |
| worst healthy `rl_max` | 13.20 (threshold 25) |
| worst healthy `max_loading_unit` | **1.766** (threshold 6) |
| shipped row on all 61 healthy fits | **PASS** |

**And the counterfactual shows how severe the defect was.** On those same healthy
fits the *pooled* `max_loading` ranges **5 to 87**, so the pre-fix rule would
have fired on **60 of 61** — a **98% false-positive rate on healthy spatial
binomial fits**, every one of them driven by the SPDE parameterisation rather
than by anything wrong with the model.

One behaviour worth recording: in a spatial fit carrying **no** unit tier,
`max_loading_unit` is `NA` throughout and the absolute arm is inert by
construction. That is correct — there are no standard-normal-score loadings to
judge — and the relative arm still applies.

### What this does not do

- **It does not catch every degenerate fit.** 54 of 1,465 remain unflagged, and
  1% of degenerate fits have `rl_max` below 1.30 — their loadings did not run
  away, so a runaway-loading gate structurally cannot see them. This gate targets
  Heywood cases, not poor recovery in general.
- **It does not screen non-binomial degenerate loadings.** That gap is pre-existing
  and was accepted knowingly in `docs/design/vgh-phase4-eda-surface-design.md`
  §7; §5.4 above now quantifies why the binomial number must not simply be reused
  there.
- **It makes no coverage or interval claim.** It is a flag, not a test with a size.

---

## 7. What review caught that the author did not

Recorded because the pattern matters more than the instances. Four errors, one
root cause: **a summary was trusted over the primary artifact.**

| Claim | Primary artifact that contradicted it |
|---|---|
| "The old rule fired on 0 of 1,465 — it is inert" | The DGP made `extreme_prevalence` unreachable (§5.1). The zero was forced, not found. |
| "Mixed-family fits aren't reachable, so the pooled denominator is moot" | `family` accepts a list (`R/gllvmTMB.R:869`; `R/data-mixed-family.R`). The gap was real. |
| Shipped advice: "see `suggest_lambda_constraint()` for a boundary constraint" | It produces no boundary constraint — it pins entries to zero for *rotational identification* (`R/suggest-lambda-constraint.R:263`); zeroing `λ_t1` relocates the divergence to `λ_t2`. Written from a design-doc mention without reading the function. Deleted. |
| "Detect-first; a remedy is a separate arc" | The remedy already ships. `gllvmTMBcontrol(aghq_ridge = 2)` takes this very reproduction fit from **‖Λ‖_F = 979.1 to 3.352** — measured, on the Laplace path. |

A fifth was caught by verification rather than review: the stratification patch
first named its argument `keep`, colliding with a local `keep` in the merge loop
above it (`R/diagnose.R:340`). The parameter was silently overwritten and the
denominator collapsed to the *first trait's* loading for every fit. **The new
test passed anyway** — 12/0.25 = 48 clears 25 by accident. It was found only by
checking that the test *fails* against the unfixed behaviour, which it did not.
Argument renamed to `reference_traits`.

**The rule this earns:** a test that passes proves nothing until it has been
shown to fail against the defect it targets. And when simulating to test whether
a gate fires, design the data so the gated quantity can actually reach its
threshold — otherwise a guaranteed zero reads like a discovery.
