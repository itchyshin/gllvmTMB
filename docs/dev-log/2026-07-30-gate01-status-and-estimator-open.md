# Gate 0/1 status, and the estimator question re-opened

**Date:** 2026-07-30. **Lane:** `claude/va-in-06-20260730`. **Author:** Claude Code.
**Status:** evidence note. **Nothing promoted. No default changed. No public claim.**

## 1. Gates 0 and 1 — PASS, measured today

```
NOT_CRAN=true Rscript -e 'devtools::load_all("."); testthat::test_file(
  "tests/testthat/test-va-r3-prototype.R")'
→ failed: 0   error: 0   skipped: 0   passed: 352
```

`inst/tmb/gllvmTMB_va_r3.cpp` compiled cleanly in the same run (clang++, `-std=gnu++20`, TMB
`-DTMB_SAFEBOUNDS`).

**Read the skip behaviour before citing this.** The same file run *without* `NOT_CRAN` reports
**183 passed, 8 skipped**, and the eight skips are precisely Design 85 **Gate 1**'s assertions —
the scalar ELBO / KL-sign / autodiff checks against independent calculations, the small-variance
branch's value- and derivative-continuity, the `q>1` projected-variance and KL matrix algebra, the
Gaussian variational gradient anchor, and *"R3 JJ bound over-estimates the softplus expectation and
is exact at zero variance"*. They carry `skip_on_cran()`. **A default `test_file()` invocation
silently skips Gate 1 and still prints a clean summary** — so a green run is not evidence unless
`NOT_CRAN=true` is set. Recorded because this is exactly the shape of failure this project keeps
paying for: a clean-looking receipt that never exercised the thing it appears to certify.

Gate 1 covers the algebra and autodiff. **Gate 2 (the low-dimensional O3 references) is NOT
established by this run** and remains open. §11 makes the gates sequential, so Gate 3 counts only
once Gate 2 does.

Note also that Polya's bound-ordering result is **already encoded as a shipped test** — the JJ bound
over-estimating the softplus expectation is asserted at `test-va-r3-prototype.R:581`. That is
independent corroboration of result 2, predating this session.

## 2. The estimator question is RE-OPENED — do not treat GH-over-JJ as settled

The plan of record chose **GH quadrature over the JJ/Pólya-Gamma bound**, on Polya's derivation
(JJ is coercive in `‖Λ‖`, so its 0/320 degeneracy record is a theorem, not evidence) plus Fisher's
recomputed attenuation table. **Rose's adversarial gate returns REJECT**, and the objection
survives independent recomputation.

**Fisher's table was a median pooled over `p ∈ {8,20,40,80}`. Disaggregating by `p` inverts the
conclusion.** Recomputed independently from `dev/totoro-grid/results/grid.csv`
(median `attenuation` = `tr(Sigma_hat)/tr(Sigma_true)`, bernoulli, n = 400):

| arm | p=8 | p=20 | p=40 | p=80 |
|---|---|---|---|---|
| `gtmb_gh` | 1.208 | 1.072 | 1.096 | **1.105** |
| `gtmb_jj` | 0.501 | 0.700 | 0.814 | **0.934** |

`|kappa - 1|` at **n=400, p=80**: GH **0.1054**, JJ **0.0663**.

JJ's bias falls monotonically toward zero with `p` (Spearman rho = +1.00); GH's is flat
(rho = -0.20). **At the large-`p` corner Design 85 exists for, JJ is the LESS-biased arm.** Rose
adds, from the same grid: JJ wins the paired `rel_frob` sign test 18/20 there; GH does not beat JJ
by more than Gate 3's own `0.05` tolerance in a single one of 320 cells, while JJ beats GH
materially in 12 of 16; and the in-code "20/20 paired seeds" justification for the existing `jj`
default replicates on the full grid (literally 20/20 per `(n,p)` cell at n<=100, every `p`).

**What is and is not overturned.** Polya's theorem stands: JJ *is* coercive, it *cannot* produce a
runaway, and `rel_frob > 10` *is* structurally blind to contraction. What fails is the **inference**
drawn from it — that GH is therefore the better foundation. Both arms are biased; JJ contracts, GH
inflates, and which is worse **depends on `p`**. That is a crossover, not a winner.

**Consequence for the plan: Gate 3 cannot settle this.** Gate 3 is defined at `q = 1/2` against an
ML comparator and sweeps neither `p` nor `n`, so it is structurally incapable of discriminating
between the tiers. The estimator clause and the admission gate are answering different questions.

**`default_tier` was NOT changed.** Rose's verdict is REJECT and the reversal is not made. The VA
engine is unexported (`NAMESPACE` carries no `va_r3`), so no user is reachable by either default
today — the change is low-risk and also non-urgent, and it would flip an asserted contract in two
test files.

## 3. The cheapest decisive measurement — identified, NOT in the approved plan

Extend the existing grid to **n in {800, 1600}** at fixed **p=80, q=4**, arms `gtmb_gh` and
`gtmb_jj` plus the `gtmb_laplace` reference, 10 seeds, reporting **signed** `tr(Sigma_hat_B) -
tr(Sigma_B)` with **all attempted fits in the denominator**. About 40 fits, 8–12 core-hours on
Totoro. It tests the only live question: does `kappa_JJ` stabilise near 0.93 or keep falling, while
`kappa_GH` settles near 1.0.

**Open for the maintainer**, alongside the `q <= 4` → `q <= 2` fence correction already recorded in
`2026-07-30-va-ships-in-06-reversal.md`.

## 4. Provenance discipline this note exists to enforce

Three layers of review each corrected the last: Polya corrected the grid's reading, Fisher corrected
Polya's plan, Rose corrected Fisher's table. Every correction came from **disaggregating or
recomputing a number that had been cited rather than derived**. The standing rule for this lane —
no number cited without recomputation from raw rows — now extends to: **no pooled summary cited
without checking the gradient it pools over.**

> Related: `2026-07-30-va-ships-in-06-reversal.md` · `2026-07-30-rose-default-tier-reversal-gate.md`
> · `docs/design/85-highdim-nongaussian-va-formal-contract.md` §11 ·
> `docs/design/104-va-family-coverage.md` §4 · `agents/polya.md`
