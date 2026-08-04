# VA vs the shipped Laplace engine — the arc's founding premise, measured

**Scope.** OWED step 2 of `2026-08-03-claude-handover-va-lane2.md`: settle whether VA scales
superlinearly. **Where the Laplace engine's time goes is NOT this document's question** —
that is `docs/design/laplace-cost-profile.md` (commit `695450d2`), which supersedes anything
said here about phase shares. This document asks the one thing that profile cannot answer:
**against Laplace, is VA actually faster?**

**Why it needed asking.** Ledger claim `f3df8193` — "our VA is 5.8× faster than our own
Laplace" — is the premise the entire VA speed arc rests on. It was measured once, on three
seeds, on a cell whose configuration the handover does not record. Two later harnesses put it
in doubt: the hybrid ladder measured VA growing 14× for a 5× N increase (~N^1.6), and the
coverage pilot had one VA fit exceed 350 s at n=5000 where n=400 took 2.44 s.

---

## Method

`43-va-vs-la-ladder.R` runs both engines **on the same dataset inside one process**, VA then
LA. Pairing is the point: box load cancels in the ratio, which is the lesson the 12-seed
head-to-head established. Cells deliberately match the Laplace profiling grid's `q = 2` arm
(binomial-probit, `NTR = 6`, `T = 20`, `latent(0 + trait | unit, d = 2, unique = FALSE)`), so
the LA arm is checkable against already-measured cells.

`n_starts = 1` for VA — this is an engine-vs-engine measurement, and multistart is a separate,
already-quantified ~3.88× multiplier. Each process pays an **untimed** warm-up first, so no
TMB compile lands inside a timed arm.

**Harness validation.** The LA arm reproduces `41-ladder-N250_q2.rds` exactly: **159 outer
iterations**, both. The two harnesses agree on the same cell to the iteration.

## Results

**The complete H = 15 ladder** — one seed per N, the arm that most favours VA:

| N | VA (s) | LA (s) | VA/LA |
|---:|---:|---:|---:|
| 250 | 53.02 | 19.97 | **2.65× slower** |
| 1000 | 319.36 | 74.41 | **4.29× slower** |
| 2500 | 1175.54 | 201.29 | **5.84× slower** |

**H = 61, the shipped default** — three seeds per N:

| N | VA (s) | LA (s) | VA/LA |
|---:|---:|---:|---:|
| 250 | 173.78 / 171.38 / 183.37 | 20.09 / 20.21 / 17.92 | **8.65× / 8.48× / 10.23×** |
| 1000 | 1015.21 / 985.77 / 1003.43 | 74.53 / 74.45 / 61.07 | **13.62× / 13.24× / 16.43×** |

*(N = 2500 at H = 61 was still running; `43-vala-N2500_s{1,2,3}.rds` will carry it, with
right-censored entries if it never finishes. It cannot change the direction — VA is already
5.84× behind at N = 2500 on the arm four times cheaper for VA.)*

### 1. VA is slower than Laplace at every configuration measured

Not marginally: 8.5–10.2× at the shipped default. The H = 15 arm exists because
`PROFILE.md` profiled `H = 15` while a user actually gets the formal default `H = 61`. That
confound is real and now measured — 173.78 → 53.02 s, a 3.3× swing, consistent with GH
quadrature being ~75–82% of a VA fn/gr call and linear in H. **It does not change the sign.**
At the configuration most favourable to VA, VA is still 2.65× slower than the engine it exists
to accelerate.

### 2. VA scales worse than Laplace — the superlinearity is real, and it is VA's

Over the full 10× N range at matched H = 15:

| engine | 250 → 2500 | fitted exponent |
|---|---:|---:|
| **VA** | 53.02 → 1175.54 s (22.17×) | **N^1.35** |
| Laplace | 19.97 → 201.29 s (10.08×) | **N^1.00** |

Laplace is linear in N to two decimal places — independently confirmed across the whole
`41-ladder` grid (N^1.05 at q=2, N^1.12 at q=5). VA is not, and the same exponent appears at
H = 61 (VA N^1.27, Laplace N^0.94 over the 250→1000 step), so **the superlinearity is
structural, not a quadrature artifact**: it survives a 4× change in GH nodes. That is what
you expect when the variational parameters themselves grow with N.

**The gap therefore widens monotonically: 2.65× → 4.29× → 5.84× across N = 250, 1000, 2500.**
This answers the handover's question, and the answer is the unfavourable one: VA has no
large-N regime where it overtakes Laplace on these cells. It falls further behind at every
step, and the two harnesses that first raised the suspicion (the hybrid ladder's ~N^1.6, the
pilot's 350 s at n=5000) were pointing at something real.

### 3. What this does and does not refute

**Regime, stated plainly, per the arc's own primary discipline.** These cells are
binomial-probit, T=20, q=2, `unique = FALSE`, `n_starts = 1`, no A_i collapse. Claim
`f3df8193`'s 5.8× was measured on a matched model whose configuration is not recorded and
which I have not reproduced. **I am not asserting that measurement was wrong on its own
cell.** What is established is narrower and still decisive for the roadmap: on the cells the
Laplace profiling fleet itself measured, VA loses at both H, and loses by more as N grows.

The A_i collapse (3.81× at N=1000, `07af7df3`) is not in these numbers. Even granting it in
full and compounding it against the H=15 N=1000 result, VA would land at ~84 s against
Laplace's 74 s — **still not ahead.** That is an arithmetic projection, not a measurement, and
it should be measured before it is quoted.

## Consequence for the roadmap

The coverage campaign (OWED step 5) asks whether VA's intervals cover. That question is
downstream of a premise these numbers undercut. **If VA is slower than Laplace at every N
measured, "do VA's intervals cover" is not the next question — "is VA worth using at all on
these cells" is.** Spending the campaign's compute before closing that is spending it on the
wrong question.

Recommended: finish the N=2500 cells, then re-measure claim `f3df8193` on its own cell with
the paired harness, since pairing is what made this measurement trustworthy. Only then decide
whether the coverage campaign runs.

## Provenance

Scripts `43-va-vs-la-ladder.R`; raw `43-vala-*.rds` + `.log`. Cross-checked against
`41-ladder-N250_q2.rds`. Results LOCAL per D-50 — nothing here is promoted, advertised, or in
NEWS, and `default_tier` remains `"gh"`.
