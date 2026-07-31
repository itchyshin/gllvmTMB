# Rose — adversarial gate on the binomial `default_tier` reversal (JJ → GH)

**Date:** 2026-07-30
**Reviewer:** Rose (adversarial closure review; default position = the change is not justified)
**Worktree:** `/private/tmp/gllvmtmb-va-in-06`, branch `claude/va-in-06-20260730`, at `origin/main` `c473364e`. Read-only except this file.
**Proposal under review:** `R/va-r3-proto.R:534`, `default_tier = "jj"` → `"gh"` for the binomial family.

**VERDICT: REJECT** (not DEFER). The evidence is not merely insufficient — recomputed from the same
`grid.csv` the proposal cites, it points the *other way* in the regime Design 85 exists to serve.

Every number below was recomputed from `dev/totoro-grid/results/grid.csv` with `Rscript`. No figure is
taken on trust from `RESULTS.md` or from any brief.

---

## 0. Summary of the finding that decides it

Fisher's attenuation table is **arithmetically correct** — I reproduced all eight numbers to four
decimals. But it is a **median pooled over `p ∈ {8, 20, 40, 80}`**, and the pooling hides a monotone
`p`-trend that reverses the conclusion. Disaggregated at `n = 400`:

| median attenuation `tr(Σ̂)/tr(Σ_true)`, bernoulli | p=8 | p=20 | p=40 | p=80 |
|---|---|---|---|---|
| `gtmb_gh` | 1.208 | 1.072 | 1.096 | **1.105** |
| `gtmb_jj` | 0.501 | 0.700 | 0.814 | **0.934** |
| `\|κ−1\|` GH | 0.208 | 0.072 | 0.096 | **0.105** |
| `\|κ−1\|` JJ | 0.499 | 0.300 | 0.186 | **0.066** |

JJ's bias shrinks monotonically toward 1 as the problem gets high-dimensional (Spearman ρ of median κ
on p = **+1.00**). GH's does not (ρ = **−0.20**; κ is flat at ≈1.07–1.21). **At `n=400, p=80` — the
corner Design 85 is named after — JJ is the *less* biased arm on Fisher's own metric** (0.066 vs 0.105),
and it wins the paired sign test 14/20.

That is the whole review in one table. The rest is verification and the honest residual.

---

## 1. The code and its stated justification

`R/va-r3-proto.R:522–534`, verbatim:

```
522:   ## Binomial-logit -- the only family with a genuine choice. Gauss-Hermite
523:   ## evaluates E[softplus(eta)] to quadrature accuracy; the Jaakkola-Jordan/PG
524:   ## bound over-estimates it in closed form, which is what keeps the ELBO a
525:   ## valid lower bound. "auto" takes the bound: measured 1.9-4.0x faster
526:   ## (n = 200/400/800, interleaved) with better Sigma_B recovery on 20/20
527:   ## paired seeds. Ask for "gh" to force quadrature -- the controlled bound
528:   ## comparisons in dev/ do exactly that.
529:   list(
530:     family = "binomial",
...
534:     default_tier = "jj",
```

Resolution machinery: `.va_r3_resolve_eval_method()` at `R/va-r3-proto.R:585–597` maps `"auto"` to
`entry$default_tier`; `.va_r3_eval_method_code()` at `:599–601` and `.va_r3_objective_type()` at
`:603–605` derive the template flag and the reported objective label from it.

**Is the existing default documented with evidence? Yes — two claims, both testable. Do they survive?
Both survive; one is independently replicated at far greater scale than its author had.**

**(a) The speed claim ("1.9–4.0× faster").** Replicated and exceeded. Median seconds per fit, bernoulli,
recomputed from `grid.csv`:

| n | `gtmb_gh` | `gtmb_jj` | ratio |
|---|---|---|---|
| 40 | 4.1 | 0.5 | 8.2× |
| 100 | 15.9 | 2.6 | 6.1× |
| 200 | 62.8 | 17.8 | 3.5× |
| 400 | 202.5 | 98.5 | 2.1× |

The arc's own `n=400/p=80/q=4` figures (771s vs 419s) reproduce exactly (771.5 / 418.7, ratio 1.84×).
The ratio decays with n, so at very large n the speed argument weakens — that is fair to note and it is
the one place the comment's range (1.9–4.0×) is optimistic at the low end for small n and pessimistic at
the high end. Direction is not in doubt.

**(b) The "20/20 paired seeds" claim.** The comment does not state its regime — a real documentation
defect, already flagged by `docs/design/109-bound-tightness-vs-recovery.md` ("a scoped descriptive
statement… with the design attached, and no generalisation"). But the claim did not need to be taken on
faith: the Totoro grid is an *independent* 320-cell replication, and it reproduces "20/20" literally.
Paired within-cell on `rel_frob` (relative Frobenius error of `Σ̂_B` against the known truth — the exact
quantity the comment names), JJ-wins / cell-total, 10 seeds × 2 q per cell:

| n \ p | 8 | 20 | 40 | 80 |
|---|---|---|---|---|
| 40 | 20/20 | 20/20 | 20/20 | 20/20 |
| 100 | 20/20 | 20/20 | 20/20 | 20/20 |
| 200 | 14/20 | 20/20 | 20/20 | 20/20 |
| 400 | 10/20 | 6/20 | 15/20 | **18/20** |

Pooled over p: 80/80, 80/80, 74/80, 49/80 at n = 40/100/200/400. At n=400 the pooled sign test gives
p = 0.057 — **a tie, not a loss.** GH's only genuine win is the `{n ≥ 200, p ≤ 20}` corner.

So the answer to Q1 is: the in-code justification is evidenced, its evidence replicates on a 320-cell
grid its author did not have, and the reversal's evidence does not overturn it — **it sits beside it,
in a different corner of the design space.**

---

## 2. Q2 — is the reversal justified now, or does it need Gate 3 first?

**Neither. It is refuted now, and Gate 3 as written would not settle it anyway.**

**The reversal is refuted against the project's own tolerance.** Design 85 §11 Gate 3
(`docs/design/85-highdim-nongaussian-va-formal-contract.md:411–424`) fixes the indifference band:

> "VA passes only if its `Sigma_B` relative Frobenius RMSE is no more than `0.05` worse in absolute
> terms than ML"

Applying that band to the paired GH-vs-JJ difference across all 16 `(n, p)` cells — mean of
`rel_frob(JJ) − rel_frob(GH)`, negative = JJ better:

| n \ p | 8 | 20 | 40 | 80 |
|---|---|---|---|---|
| 40 | −3.211 | −3.000 | −2.684 | −3.317 |
| 100 | −0.824 | −0.669 | −0.373 | −0.218 |
| 200 | −0.279 | −0.218 | −0.154 | −0.107 |
| 400 | −0.011 | **+0.010** | −0.020 | −0.040 |

**There is not one cell in the 320-cell grid where GH beats JJ by more than Gate 3's own tolerance.**
The single GH-favouring cell (n=400, p=20) is +0.010 — one fifth of the band. Twelve of sixteen cells
exceed the band in JJ's favour, by up to 3.3. On the package's own declared standard of material
difference, the reversal would be trading a proven material advantage at n ≤ 200 for an immaterial one
at n = 400.

**Gate 3 will not adjudicate this.** Gate 3 is specified "at `q = 1/2`" and its comparator is
**ML/Laplace**, not the other tier: "VA bias and RMSE must be reported beside byte-identical ML/Laplace
results" (`85-…:418–422`). The crossover I measured is at `q ∈ {2, 4}` and is driven by `p`, which
Gate 3 does not sweep. Running Gate 3 first is good practice for the arc and irrelevant to the default.
Deferring to it would be **deferring to a measurement that does not answer the question** — which is
worse than deciding now, because it manufactures the appearance of a gate.

**Materiality — and this cuts both ways.** The VA engine is **not exported**: `grep` for
`va_r3|approximation_engine` in `NAMESPACE` returns nothing; the grid reaches it via
`gllvmTMB:::.approximation_engine_fit`. Every result carries `research_only = TRUE`
(`R/va-r3-proto.R:1291`), and the 2026-07-27 handover records that `engine = "laplace"` remains the only
user route. **No user is reachable by either default.** So (i) the framing "whichever way the default
goes, one regime is harmed" is hypothetical — no user is in either regime today; and (ii) there is
therefore no urgency argument for changing it, only for documenting it correctly.

The change is also not the one-liner it looks like. `tests/testthat/test-approximation-engine.R:67–68`
asserts `expect_identical(result$objective_type, "ELBO_JJ")` for binomial `"auto"`, and
`tests/testthat/test-va-r3-prototype.R:552` round-trips the registry against
`.va_r3_resolve_eval_method()`. Flipping `default_tier` flips an asserted contract in two test files.

---

## 3. Q3 — attack on Fisher's attenuation table

**Reproduced exactly.** All-rows medians, bernoulli, GH / JJ: n=40 4.3018/1.6703; n=100 1.6284/1.0146;
n=200 1.2877/0.8570; n=400 1.1045/0.7799. Fisher's arithmetic is sound and I found no transcription
error. Four objections, in decreasing force.

**(a) The pooling is the artefact — this is the fatal one.** Section 0 above. Fisher's "~22% variance
deficit that is not shrinking" is a statement about a median pooled across a factor (`p`) on which the
deficit varies from 50% to 6.6%. In the high-dimensional cells the package is designed for, the deficit
is **6.6%** and is *smaller* than GH's 10.5% inflation. A conclusion that inverts when you disaggregate
by a design factor is not a conclusion about the estimator.

**(b) Redrawn truth does *not* undermine this comparison — I must concede that point.** The brief's
suspicion is reasonable but wrong here. In `dev/totoro-grid/run-grid.R:47–54`, `set.seed(seed)` runs
once per *cell*, `Lt <- matrix(rnorm(p*q, 0, 0.6), p, q)` is drawn once, and **all five arms fit the
same `Y` against the same `Σ_true`**. So `κ_GH` and `κ_JJ` share a denominator seed-by-seed and the
within-cell paired contrast is clean. Redrawn truth destroys *coverage* (the target moves under a fixed
nominal band) but not a *paired* ratio comparison. Fisher's design is sound on this axis.

**(c) Median-of-ratios is the wrong summary — but not in the direction that helps.** `attenuation` is a
**trace** ratio; `rel_frob` is a Frobenius ratio, and `κ_tr ≈ κ_F²` (the units confusion already logged
in `docs/dev-log/handover/2026-07-29-claude-handover-vgh-phase1.md:75–80`). On the trace scale JJ's
n=400 pooled deficit is 22%; on the SD/Frobenius scale it is `1−√0.780` = **11.7%**, and GH's inflation
is 5.1%. The ranking survives the rescaling; only the drama does. The real defect in the summary is
different: **attenuation is a bias axis, not a loss axis**, and the code comment claims *recovery*.
On the loss axis (`rel_frob`) JJ wins or ties everywhere (§1b). At n=400/p=80/q=4, GH's trace is nearly
right (κ=1.105) while its matrix is *worse* than JJ's (0.393 vs 0.316 median) — GH's error is shape and
spread, not scale, so calibrating the trace buys nothing. This is exactly the scale/shape decomposition
Design 109 asked for as falsification item 7 (`109-…:495–498`) and it has now been done.

**(d) Health status is ignored, and the differential attrition is severe.** Health-gate pass rate
(`status == "healthy"`; the gate is `variance_domain_ok <- max_projected_variance <= 4` at
`R/va-r3-proto.R:1274` plus the admission flag at `:1285–1291`):

| n | GH pass | JJ pass |
|---|---|---|
| 40 | 0.100 | 0.963 |
| 100 | 0.637 | 0.875 |
| 200 | 0.188 | 0.312 |
| 400 | 0.250 | 0.537 |

All 93 `failed_variance_domain` rows in the grid are GH's; JJ has zero. GH's 4.302 at n=40 is a median
over a sample that is **70/80 variance-domain failures** — it is not a measurement of GH-as-estimator,
it is a measurement of GH diverging. Restricting to healthy rows drops it to 2.333, and restricting to
*paired*-healthy cells (n=8) gives GH 1.965 vs JJ 1.264. Note carefully: healthy-only filtering is what
Gate 3's NO-GO clause explicitly forbids ("failed fits are excluded from denominators",
`85-…:423–424`), so the all-rows numbers are the contract-compliant ones — and they are the ones that
favour JJ most. I report both; the conclusion does not turn on the choice.

I also confirmed the known `analyse-grid.R:100` defect: `grepl("pdHessTRUE|healthy|converged", s$status)`
matches the failure label `"not_converged"` by substring. It affects `RESULTS.md` §4's last column only,
not §2 or §3. **Verified independently: §2's bound ordering is correct** — min(GH−JJ) = **+2.8692** nats,
median +22.2219, GH above JJ in **320/320** cells.

---

## 4. Q4 — attack on Polya's derivation (applicability, not algebra)

I do not dispute the algebra. `p_JJ = tanh(ξ/2)/(4ξ)` with `ξ=√(μ²+v)` against
`p_GH = ½E[σ(η)(1−σ(η))]`, and the coercivity of the ξ-profiled JJ ELBO along a loading ray, are
correct as stated. The objection is that **the divergence is never reached in this DGP, and the
asymptotic form Polya quotes is a poor approximation where the mass actually lies.**

Computed by 61-node Gauss–Hermite (`plogis`, `statmod::gauss.quad`), exact ratio vs the asymptotic
`e^{|μ|}/(2|μ|)`:

| \|μ\| | v=0.25 | v=0.72 | v=1.44 | asymptotic | asym/exact @ v=0.72 |
|---|---|---|---|---|---|
| 0.0 | 1.038 | 1.092 | 1.152 | — | — |
| 0.5 | 1.072 | 1.118 | 1.169 | 1.649 | **1.48×** |
| 1.0 | 1.182 | 1.199 | 1.225 | 1.359 | 1.13× |
| 1.5 | 1.386 | 1.352 | 1.332 | 1.494 | 1.11× |
| 2.0 | 1.720 | 1.604 | 1.508 | 1.847 | 1.15× |
| 3.0 | 3.035 | 2.611 | 2.212 | 3.348 | 1.28× |
| 5.0 | 13.115 | 10.474 | 7.649 | 14.841 | 1.42× |

Two things follow. First, `e^{|μ|}/(2|μ|)` **over-states the exact ratio by 13–48% across the whole
in-regime band** — it is an asymptote borrowed into a region it does not describe, and the "→ ∞"
framing is doing rhetorical work the numbers do not support. Second, the operative magnitude is small.

Under the grid's DGP (`run-grid.R:49–52`: `Lt ~ N(0, 0.6)`, `u ~ N(0, I_q)`, `b ~ N(0.3, 0.3)`), the
marginal linear predictor has `sd(η)` = 0.90 (q=2) / 1.24 (q=4). Monte Carlo over 2×10⁵ draws, with
`v = q·0.36/2` (a conservative posterior-variance proxy):

| q | sd(η) | aggregate mispricing `E[p_JJ]/E[p_GH]` | median pointwise ratio | P(\|η\|>2) | P(\|η\|>3) |
|---|---|---|---|---|---|
| 2 | 0.90 | **1.149** | 1.105 | 0.035 | 0.0014 |
| 4 | 1.24 | **1.226** | 1.170 | 0.116 | 0.0180 |

**JJ over-prices predictive variance by ~15–23% in aggregate, not by orders of magnitude, and 1.4–1.8%
of the mass sits beyond |η|=3 where the divergence begins to bite.** The mechanism is real, present, and
*modest*. That is consistent with what I measured: a shrinkage that is material at small `n`/small `p`
(where 15–23% of a large VA gap is a lot) and fades to 6.6% at `n=400, p=80`.

**On coercivity.** Polya is right that 0/320 degeneracy is implied by coercivity and is therefore not
independent evidence of accuracy. I accept the correction in full. But the brief's own counterpoint
holds and is stronger than it looks: GH's non-coercivity is not a neutral property — **all 93
`failed_variance_domain` rows in the grid are GH's**, i.e. the degeneracy JJ's coercivity forecloses is
one GH demonstrably falls into, 70 times at n=40 alone. "Coercive by design" describes `aghq_ridge`,
which the package ships deliberately; it describes JJ here too.

---

## 5. Q5 — what would change my mind, and the cheapest decisive measurement

**The one thing that could still be right in the reversal's case is a trend argument, and I found it
myself rather than taking it from the brief.** At the design-target corner `p=80`, medians of κ:

| arm | n=40 | n=100 | n=200 | n=400 | δ-ratio | extrapolated asymptote |
|---|---|---|---|---|---|---|
| `gtmb_gh` | 4.888 | 1.476 | 1.226 | 1.105 | 0.484 | **0.992** |
| `gtmb_jj` | 2.119 | 1.211 | 1.038 | 0.934 | 0.609 | **0.771** |

**AGENT-INFERRED** (a three-point geometric extrapolation on medians — weak, and I flag it as a lead,
not a result). If it holds, GH's inflation is a vanishing small-sample VA-gap effect and JJ's deficit is
an **asymptotic bias**, exactly as Polya's constant per-observation mispricing predicts. Then at some
`n > 400` GH overtakes JJ even at `p=80`, and the reversal becomes right — just not yet, and not at the
`n` currently measured.

**Cheapest decisive measurement.** Extend the *existing* grid to `n ∈ {800, 1600}` at **fixed `p=80`,
`q=4`**, two arms only (`gtmb_gh`, `gtmb_jj`) plus the `gtmb_laplace` reference, 10 seeds, and report
**signed** `tr(Σ̂_B) − tr(Σ_B)` alongside `rel_frob`, with all attempted fits in the denominator and
MCSEs. That is 40 VA fits; extrapolating the measured `n^≈1.6` cost from 771 s / 419 s at n=400, roughly
**8–12 core-hours on Totoro** — one afternoon inside the ≤100-core ceiling, results local per D-50.

It is decisive because it tests the *only* live disagreement: does `κ_JJ` stabilise near 0.93 (a bounded
shrinkage, keep JJ) or keep falling toward ~0.77 while `κ_GH` settles at ~1.0 (an inconsistency, flip
GH)? Both outcomes are unambiguous and the design is already written.

**Is it in the arc's plan? No.** Gate 3 is at `q = 1/2` against an ML comparator (§2 above) and sweeps
neither `p` nor `n` into the region where the two tiers diverge. It will report a number for whichever
tier is default and will not discriminate between them. Design 109's falsification item 2 —
*"Report the SIGNED bias, not the loss… This is the single most informative number in the whole exercise"*
(`109-…:466–474`) — was raised on 2026-07-27 and **is still not done**. That is the gap, and it is
cheaper than the reversal it would justify.

---

## 6. Q6 — VERDICT

### REJECT.

Not DEFER. DEFER is the right verdict when evidence is absent; here it is present, was recomputed from
the proposal's own dataset, and **contradicts the proposal in the regime the package is built for**:

1. **On the reversal's own metric** (attenuation), JJ is the less-biased arm at `n=400, p=80` — 0.066
   vs 0.105 — and its bias shrinks monotonically toward zero as `p` grows (ρ=+1.00) while GH's does not
   (ρ=−0.20). Fisher's headline is a pooling artefact across `p`.
2. **On the metric the code comment claims** (`Σ_B` recovery loss), JJ wins 80/80, 80/80, 74/80 and
   ties 49/80 at n = 40/100/200/400, and wins 18/20 at n=400/p=80.
3. **Against the project's own indifference band** (Gate 3's 0.05 absolute rel-Frobenius), GH does not
   beat JJ by a material margin in a single one of 320 cells, while JJ beats GH materially in 12 of 16.
4. **On failure behaviour**, GH owns all 93 `failed_variance_domain` rows and passes its own health gate
   at 10–64% against JJ's 31–96%.
5. **On speed**, GH is 2.1–8.2× slower.
6. **Polya's mechanism is real but ~15–23% in-regime**, not divergent, and the `e^{|μ|}/(2|μ|)` form
   over-states the exact ratio by 13–48% everywhere the DGP puts mass.

### What I concede, and what should ship instead

- **Fisher's numbers are correct and his direction is real** in `{n ≥ 200, p ≤ 20}`. That corner should
  be recorded, not buried.
- **Polya's coercivity correction is right**: "0/320 degeneracies" must stop being cited as evidence of
  JJ's accuracy. It is a consequence of the bound's geometry.
- **The κ trend at p=80 is the reversal's strongest surviving argument** and it is unresolved. If the
  extrapolation in §5 holds, the reversal is right at larger `n` and should be revisited then.

The defensible change to make now is **documentary, not behavioural**: amend the comment at
`R/va-r3-proto.R:522–528` to attach its regime and its limits — something to the effect of *"JJ is the
default on paired-seed `Σ_B` recovery measured at n ≤ 400 across p ∈ {8..80} (320 cells, Totoro grid);
JJ shrinks `tr(Σ̂_B)` and GH inflates it, JJ's deficit falls with p (6.6% at n=400/p=80) and GH's
inflation does not; the ordering on the bias axis reverses for p ≤ 20 at n ≥ 200, and the large-n
behaviour is unmeasured"* — plus the §5 run. That converts an undocumented default into a scoped one
without asserting anything the evidence does not carry.

---

## Appendix — provenance of every number

| Claim | Source | How obtained |
|---|---|---|
| Fisher's 8 medians reproduce | `dev/totoro-grid/results/grid.csv` | `tapply(median)` by n × arm, bernoulli, all rows |
| κ by n × p, both arms | same | `tapply(median)` by n × p × arm |
| Spearman ρ of κ on p at n=400 | same | `cor(p, median κ, method="spearman")` |
| Paired `rel_frob` win counts | same | `reshape()` to wide by (n,p,q,seed); `sum(jj < gh)`; `binom.test` |
| Gate-3 band table | same | `mean(rel_frob_jj − rel_frob_gh)` per (n,p) |
| Health-gate pass rates | same | `mean(status == "healthy")` by n × p × arm |
| Median seconds | same | `tapply(median)` by n × arm; n=400/p=80/q=4 subset |
| Bound ordering +2.8692 / 320/320 | same | `objective_gh − objective_jj` over paired cells |
| `p_JJ/p_GH` table | computed | 61-node `statmod::gauss.quad(H,"hermite")`, `plogis` |
| Aggregate mispricing, tail mass | computed | 2×10⁵ MC draws from the `run-grid.R` DGP |
| κ extrapolation (AGENT-INFERRED) | `grid.csv` + arithmetic | geometric δ-ratio on 3 successive differences at p=80 |
| Engine not exported | `NAMESPACE` | `grep va_r3\|approximation_engine` → no match |
| Tests asserting `ELBO_JJ` | repo | `tests/testthat/test-approximation-engine.R:67`; `test-va-r3-prototype.R:552` |
| Gate 3 text, §10 prohibitions | `docs/design/85-…md:319–353, 411–424` | read |
| `analyse-grid.R:100` substring bug | `dev/totoro-grid/analyse-grid.R:100` | read; `"not_converged"` contains `"converged"` |

### Scope caveats I could not remove

- **All binomial evidence in this grid is Bernoulli** (`run-grid.R:53` `rbinom(n*p, 1, ·)`;
  `n_trials = rep(1L, ·)` at `:87`). Design 85 §10 (`85-…:344`) explicitly prohibits *"widening to
  Bernoulli"*. So neither side's evidence is in-contract for a claim about the binomial family at
  `n_trials > 1`. This is a further reason not to flip a family-level default on it.
- The `n=800` figures quoted in `docs/dev-log/handover/2026-07-29-claude-handover-vgh-phase1.md:63`
  (GH 0.218 vs JJ 0.386) come from the separate `dev/vgh/` study with a different design; I did not
  re-derive them and do not rely on them. If that design's `p` is small, it is consistent with the
  `p ≤ 20` corner I found rather than in conflict with it — **unverified**.
- I did not re-run any fit. Everything here is analysis of stored results plus closed-form quadrature.
