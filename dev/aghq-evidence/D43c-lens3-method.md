# D-43c lens 3 — STATISTICAL SOUNDNESS (load-bearing)

Fresh reviewer, not involved in producing any of this. Default verdict NOT-DONE.
Worktree `/private/tmp/gllvmtmb-arc0-identifiability`, branch `claude/aghq-engine-20260728`,
PR #801 (OPEN, unmerged). Every number below is recomputed by me from the CSVs, not quoted.

**Verdict up front: NOT-DONE.** Not because the sentence is too strong in tone — because two
of its four numbered parts, (C) and (D), are *arithmetically* not what the fixed-truth data
say. (C)'s "in every cell measured" has significant paired counterexamples under the authors'
own complete-case accounting. (D)'s "0.023" is, on my recomputation, ~90% an artefact of the
unexported delta SE, not a property of the shipped Laplace estimator — and the run's own
pre-registered validity gate for that SE was written down and then never computed.

I want to be explicit that the narrowing is real work: (A) is scoped honestly, the
retractions are genuine, and this arc found more against itself than the previous panel did.
The problem is that the retraction stopped one step short.

---

## 0. What I recomputed, and the data's own shape

`dev/aghq-evidence/25-fixedtruth-inc.csv`: 105,714 entry-rows. Fit-level, that is **5,034
fits of a 9,600 grid (52.4%)** — 4 n × 4 arms × 3 truths × 200 seeds. Every recorded fit has
`status == "ok"`; there are zero `no_fit` and zero `no_se` rows. Per-cell seed counts run
89–113 (the grid was shuffled, so the partial run is roughly balanced, but no cell has the
200 seeds the script's own power argument at `25-coverage-fixedtruth.R:14-19` was written to
buy).

The design is genuinely **paired**: `mk()` (`25-coverage-fixedtruth.R:56-63`) calls
`set.seed(seed)` and takes `Lt` from the fixed truth, so a given `(seed, truth_id, n)` is the
*same dataset* across all four arms. That is a real strength and it lets me do the paired
per-seed analysis the brief asks for. I used it.

Entry-level missingness (non-finite `se` among `ok` fits), which is what actually enters a
coverage denominator:

| arm | all | lam_sd 0.5 | 1.0 | 3.0 |
|---|---|---|---|---|
| aghq | **12.47%** | 4.29% | 4.73% | **28.70%** |
| aghq_ridge | 2.50% | 2.52% | 0.36% | 4.66% |
| laplace_ridge | 3.72% | 0.65% | 0.31% | 10.01% |
| laplace | **0.03%** | 0.06% | 0.00% | 0.03% |

The asymmetry is 400× and it favours the arms the claim credits. The previous panel already
forced this concession (`decisions.md`, "availability 100% … FALSE"), and the authors
conceded there that *"the conservative figure is the honest one."* I therefore report both,
and I hold them to their own concession.

---

## 1. (C) — "UNIFORMLY BETTER … in every cell measured, gap widening in n"

### 1a. It is false under the authors' own complete-case accounting

Paired per-seed differences (AGHQ − Laplace at **matched ridge**, per-seed mean over the
entries of that part, MCSE = sd of the per-seed differences / √npair). Only the cells that
contradict the claim:

| contrast | part | lam_sd | n | npair | mean diff | MCSE | t |
|---|---|---|---|---|---|---|---|
| aghq − laplace | offdiag | 0.5 | 200 | 97 | **−0.0352** | 0.0088 | **−4.01** |
| aghq − laplace | offdiag | 0.5 | 400 | 93 | **−0.0381** | 0.0095 | **−4.03** |
| aghq_ridge − laplace_ridge | offdiag | 0.5 | 200 | 93 | **−0.0108** | 0.0046 | **−2.38** |

Three cells where Laplace is better by more than 2·MCSE, complete-case, on the off-diagonal
of Σ. "Uniformly better … in every cell measured" is refuted by its own strictest-accounting
data. The `lam_sd = 0.5, n = 400, offdiag` cell is unambiguous under *either* reading of
"better": Laplace 0.9673 vs AGHQ 0.9294 — Laplace is both **higher** and **closer to
nominal** (|0.017| vs |0.021|).

Cell-level, complete-case, offdiag, lam_sd = 0.5:

```
 n=100   aghq 0.9751 (mcse .0103)   laplace 0.9817 (.0065)
 n=200   aghq 0.9529 (.0080)        laplace 0.9879 (.0026)
 n=400   aghq 0.9294 (.0092)        laplace 0.9673 (.0048)
```

### 1b. Under the honest (conservative) accounting it fails much more widely

Counting a refused interval as not-covered — the treatment the authors themselves called
honest — the paired analysis returns **six** significantly-Laplace cells:

| contrast | part | lam_sd | n | mean diff | t |
|---|---|---|---|---|---|
| aghq − laplace | diag | 1.0 | 200 | −0.0466 | −2.99 |
| aghq − laplace | offdiag | 0.5 | 100 | −0.0623 | −3.49 |
| aghq − laplace | offdiag | 0.5 | 200 | −0.0770 | −4.49 |
| aghq − laplace | offdiag | 0.5 | 400 | −0.0681 | −4.63 |
| aghq − laplace | offdiag | 3.0 | 100 | **−0.1284** | **−4.34** |
| aghq_ridge − laplace_ridge | offdiag | 0.5 | 200 | −0.0473 | −3.18 |

and a further nine cells indistinguishable from zero. The `lam_sd = 3, n = 100` offdiag cell
is the sharpest: conservative coverage AGHQ 0.4981 vs Laplace 0.6305, both far below nominal,
so "higher" and "closer to nominal" coincide and Laplace wins by 13 points. That cell is
driven entirely by AGHQ's 28.7% refused intervals at `lam_sd = 3`.

### 1c. "with the gap widening in n" is false at one of the three truths

Paired diag gap (aghq − laplace, complete-case), lam_sd = 0.5:
`n = 100: +0.047 → 200: +0.047 → 400: +0.032 → 1600: +0.013 (ns)`. That is **narrowing** to
nothing. The widening is a `lam_sd = 1` and `lam_sd = 3` phenomenon; stated unconditionally it
is a one-third-false generalisation.

### 1d. The most charitable reading still is not "uniformly better"

Restrict to the diagonal, complete-case, matched ridge — the most favourable slice available.
No cell is significantly Laplace-better, but 4 of 24 are null (`aghq_ridge − laplace_ridge`:
lam_sd 0.5/n=100 −0.0029 ns; 1.0/n=100 −0.0178 ns; `aghq − laplace`: 0.5/n=1600 +0.0133 ns;
1.0/n=200 +0.0050 ns), and two of those point the wrong way. The supportable sentence for that
slice is *"better or indistinguishable"*, not *"uniformly better in every cell measured."*
That is a different sentence and a referee will say so.

---

## 2. The instrument — can ANY coverage number from this run be quoted?

**The run wrote its own gate and never ran it.** `25-coverage-fixedtruth.R:26-31`:

> "The decisive check is SE/SD… It is computed here per cell and per entry. **NO COVERAGE
> NUMBER FROM THIS RUN MAY BE QUOTED UNLESS SE/SD IS NEAR 1** — otherwise the run is
> measuring the Jacobian, not the engine."

It is *not* computed there. `grep -n "sd(\|se_sd"` over that script returns only the comment
at line 27. A repo-wide grep for `se_sd` / `SE/SD` finds the diagnostic only in
`13-coverage.R` and in the **previous** panel's `D43b-lens3-method.md:171`, which computed it
on the *redrawn-truth* `24-` data — the dataset this arc then retracted. **Nobody has run the
gate on the fixed-truth data.** I ran it.

Median SE/SD per (arm × lam_sd × n) cell, diagonal on the log scale (matching `sigma_ci()`'s
own transform, `22-sigma-se-delta.R`), off-diagonal raw:

* **Diagonal: 3 of 48 cells** fall in [0.9, 1.1]. Range **0.159 – 2.608**.
* Off-diagonal: 22 of 48. Range 0.167 – 1.833.

The failures are systematic, not scattered. `laplace` diagonal at `lam_sd = 3`: SE/SD =
**0.227 / 0.185 / 0.159 / 0.163** at n = 100/200/400/1600 — the interval is five to six times
too narrow. `laplace` diagonal at `lam_sd = 0.5`: **0.93 / 1.89 / 1.64 / 1.61** — 60–90% too
*wide*. The instrument is not merely noisy; it is biased in both directions depending on the
regime, and its worst regime is exactly the regime claim (D) is built on.

The answer to the brief's question 2 is therefore: **no, not as the sentence uses them.** The
negative claims are not automatically safe. A too-narrow SE manufactures under-coverage out of
nothing, which is precisely the direction (D) reports.

---

## 3. (D) — "the SHIPPED LAPLACE DEFAULT … covers 0.023 at n = 1600"

The number reproduces: laplace, diag, lam_sd = 3, n = 1600 → **0.0227** (2·MCSE band 0.0113),
103 seeds, complete-case and conservative alike (Laplace has ~no missingness). So the
arithmetic is right. The **attribution** is not.

Because the truth is fixed, the empirical SD of Σ̂ *within* a (arm, lam_sd, n, entry) stratum
is exactly what the SE is trying to estimate. Substituting it gives an **oracle-SE coverage**
that isolates estimator bias from instrument mis-sizing. Entry-averaged, diagonal:

| arm | lam_sd | n | delta-SE cov | **oracle-SE cov** | SE/SD | bias/SD |
|---|---|---|---|---|---|---|
| laplace | 3.0 | 100 | 0.171 | **0.970** | 0.256 | +0.259 |
| laplace | 3.0 | 200 | 0.181 | **0.969** | 0.232 | +0.106 |
| laplace | 3.0 | 400 | 0.110 | **0.959** | 0.244 | −0.136 |
| laplace | 3.0 | **1600** | **0.023** | **0.649** | 0.202 | −0.409 |

At n = 100, 200 and 400 the "catastrophic coverage failure of the shipped default" is
**entirely** the SE: with a correctly sized interval the shipped Laplace estimator covers
0.96–0.97. At n = 1600 it is a mixture — bias is real (−0.41 SD) but an honest interval covers
0.65, not 0.023. The sentence's headline number is roughly 90% a property of
`dev/aghq-evidence/22-sigma-se-delta.R`, which is unexported evidence code whose only
independent validation (`23-validate-sigma-se.R`, V2 against `bootstrap_Sigma`) **failed** at
width ratios 1.4–3.4×.

Writing "the SHIPPED LAPLACE DEFAULT has a previously unmeasured coverage failure … it covers
0.023" attributes to a shipped estimator a number that a route the package does not ship, and
that failed its own validation, is doing most of the work to produce. A hostile referee needs
one paragraph to dismantle that, and the dismantling computation was available in this dataset
and was not run.

**There is a defensible sentence in here and it is not this one.** The instrument-independent
result is: *at lam_sd = 1, n = 1600, the shipped Laplace default's Σ-diagonal bias exceeds one
sampling SD (bias/SD = −1.115), so even an oracle-SE interval covers only 0.699.* Same for the
off-diagonal there (oracle 0.701, bias/SD = −1.005). That is a genuine, previously unmeasured
estimator failure at a *realistic* loading scale, it does not depend on the delta SE at all,
and it is strictly stronger evidence than the 0.023 the sentence chose.

### 3b. And the lam_sd = 3 regime is not a coverage regime at all

Reconstructing the third truth (`set.seed(90003)`, `matrix(rnorm(12, 0, 3), 6, 2)`):
`diag(Σ) = 2.00, 31.70, 23.97, 31.55, 11.19, 29.16`, i.e. latent SDs of **1.4 to 5.6 on the
logit scale**. Five of six traits produce Bernoulli responses that are effectively
deterministic given u — quasi-separation. A Wald interval on a variance of 31.7, built from a
delta-method Jacobian at an ML mode, is outside the regime where asymptotic normality is even
approximately true. Reporting 0.023 there and calling it a property of the *engine* conflates
"the shipped estimator is broken" with "Wald intervals do not exist in this regime". A
referee will demand a likelihood-ratio or profile interval before accepting any statement
about that cell — and this project already owns a profile route.

---

## 4. Is the fixed-truth design adequate? (brief question 4)

Fixing the truth was the right fix and it worked — it is what produced the retraction. But the
design has one structural limitation that the sentence's language walks straight into.

**`truth_id` is perfectly confounded with `lam_sd`: three truths, one draw each.** So "at
lam_sd = 3, Laplace covers 0.023" is a statement about **one realisation of Λ**, with an
effective sample size of **one** on that axis. The seed-clustered MCSE I computed (and the
±2·MCSE bands in `decisions.md`) quantify data-resampling noise *conditional on that draw* and
say nothing about draw-to-draw variability. Given that the three draws are wildly
heterogeneous internally — truth 1 has a Σ diagonal entry of 0.03, truth 3 has entries from
2.0 to 31.7 — the between-draw variance is plainly not negligible.

What a referee would demand, in order:

1. **≥ 10 Λ draws per scale**, with MCSE propagated over draws, before any sentence containing
   "with large true loadings" is written. Right now the loading *scale* and the loading
   *realisation* cannot be separated.
2. The **SE/SD gate actually computed and reported**, per the script's own precondition, with
   any cell failing it excluded or flagged.
3. **Missingness handled by design**, not by choosing an accounting after seeing which one is
   favourable. The two accountings give different verdicts on (C); that is the definition of a
   researcher-degree-of-freedom.
4. A **second model shape**. Everything here is p = 6, q = 2, binomial-logit, `unique = FALSE`,
   balanced, no covariates. The word "uniformly" is doing work across 12 cells of one shape.
5. The run **completed** (52.4% now), or an explicit argument that the shuffle makes the
   partial run ignorable per-cell.

---

## 5. Is the OPENING sentence misleading? (brief question 5)

Narrowly, no: `aghq` is a real `gllvmTMBcontrol()` argument, Laplace is untouched as the
default, and the engine now warns rather than silently declining. Part (B) does the scoping
work honestly, and I credit that (B)'s own directional claim reproduces: from
`21-wide-inc.csv`, the median |bias| reduction |ρ_lap − 1| − |ρ_aghq+ridge − 1| across
lam_sd × n × q cells is **0.162 / 0.093 / 0.069 / 0.030** at T = 2/4/6/12 — monotone
decreasing in traits-per-site, as theory predicts. (Caveat the sentence should probably carry:
AGHQ+ridge is *worse* than Laplace in 23 of 63 such cells, min −0.765.)

My reservation is ordering, not truth: a reader meets "gllvmTMB has an AGHQ integration
engine" three paragraphs before learning it is ineligible on the default grammar and no-ops on
poisson. That is a presentation fix, not a blocker, and it is not the basis of my verdict.

---

## 6. Would a hostile methods referee accept the narrowed sentence?

No, and the rejection would be short:

1. (C) says "in every cell measured" and there are three significant counterexamples under the
   authors' own accounting, six under the accounting they conceded is honest, plus a
   "widening in n" that reverses at one of three truths.
2. (D)'s headline number survives at 0.023 only because the SE is 5× too narrow; with an
   oracle SE the same cell covers 0.649 and the neighbouring cells cover 0.96–0.97.
3. Every coverage number in (C) and (D) comes from an instrument that failed its independent
   validation, and whose *pre-registered* validity gate was declared in the run script and
   never computed — and fails, in 45 of 48 diagonal cells, when computed.

Point 3 is the load-bearing one for me. The arc's own recorded lesson from earlier today was
*"a result that confirms the prediction is where the mechanism check is most needed."* The
0.023 confirmed the prediction that Laplace under-covers. The mechanism check — the one the
script itself demanded, in capitals — was not run on it.

**VERDICT: NOT-DONE**

---

## SMALLEST EVIDENCE THAT WOULD CHANGE MY VERDICT

No new fits are needed for two of the three. All of this is computable from
`25-fixedtruth-inc.csv` as it stands.

1. **Run the gate the script promised.** Report median SE/SD per (arm × lam_sd × n × part),
   and restrict every quoted coverage number to cells where it lies in [0.9, 1.1]. If the
   surviving cells still support a comparative statement, quote that statement.

2. **Rewrite (C) to what the paired analysis supports.** E.g.: *"On the Σ diagonal, at matched
   ridge setting, AGHQ's Wald coverage is better than or indistinguishable from Laplace's in
   all 24 paired cells (largest gain +0.65 at lam_sd = 3, n = 400; four cells null). On the
   off-diagonal the ordering reverses at lam_sd = 0.5 (Laplace better by 0.035–0.038, t ≈ −4).
   Neither engine achieves nominal coverage in any configuration tested."* I would accept that
   sentence today — it is the same finding without the false universal.

3. **Replace (D)'s number with the instrument-independent one.** *"At lam_sd = 1, n = 1600,
   the shipped Laplace default's Σ-diagonal bias exceeds one sampling SD (bias/SD = −1.115),
   so an interval built from the empirical sampling SD would still cover only ~0.70."* That is
   a real, previously unmeasured failure of the shipped default, it needs no delta SE, and it
   is stronger than the 0.023.

4. **If the 0.023 is to be kept at all**, it needs a profile or likelihood-ratio interval at
   `lam_sd = 3, n = 1600` showing the failure survives without a Wald approximation on a
   variance of 31.7. That does require new fits — ~100 seeds, one cell, two arms.

5. **For any sentence containing "with large true loadings"**: ≥ 10 Λ draws at that scale, with
   MCSE propagated across draws. One draw cannot support a scale-level generalisation.
