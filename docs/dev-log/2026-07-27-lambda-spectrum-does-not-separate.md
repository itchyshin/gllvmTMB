# The Lambda_B spectrum does not separate degenerate from healthy fits

**Status: the second hypothesis on the 59/70 fails to yield a usable detector.**
The statistic carries real signal, but not enough to threshold. More
importantly, the exercise suggests the 59/70 may be **mislabelled rather than
undetected**.

## The hypothesis

`docs/dev-log/2026-07-27-relative-collapse-does-not-explain-59of70.md` recorded
this as the next untested idea:

> with `unique = FALSE` the only structure is `Lambda_B`, so a degenerate fit is
> a near-collinear loading matrix rather than a collapsed variance. The absolute
> `loading_thresh = 1e-3` on `diag(Lambda_B)` is the same shape of blind spot
> the psi threshold had — absolute where it should be relative, and applied to
> the Cholesky diagonal rather than to the implied `Lambda Lambda'` spectrum.

Prediction: `min/max` eigenvalue ratio of `Lambda_B Lambda_B'` is small for
degenerate cells and not small for healthy ones.

## What was run

16 degenerate and 16 healthy `gtmb_laplace` bernoulli cells, re-identified from
the original grid by `n`/`p`/`q`/`seed` and re-fitted with the same DGP and
model. Script `dev/lambda-spectrum-vs-degeneracy.R`, results
`dev/lambda-spectrum-vs-degeneracy.csv`.

## Result

| group | `eig_ratio` median | range |
|---|---|---|
| degenerate (n=16) | **1.150e-03** | 9.80e-07 – 5.77e-01 |
| healthy (n=16) | **1.385e-01** | 5.37e-06 – 7.15e-01 |

| check | degenerate flagged | healthy flagged |
|---|---|---|
| current absolute `min\|diag(Lambda_B)\| < 1e-3` | **0/16** | **0/16** |
| best relative `eig_ratio` threshold (7.93e-02) | 12/16 | **6/16** |

**Half confirmed.** The absolute check is completely blind — 0/16 on both
groups, exactly as the hypothesis said. And the relative statistic does carry
signal: a **120× median shift** between the groups.

**But it does not separate.** The ranges overlap heavily — one degenerate fit
has `eig_ratio = 0.577` (not rank-deficient at all), one healthy fit has
`5.37e-06` (severely so). The best achievable threshold yields **Youden 0.38**:
75% sensitivity at a **37.5% false-positive rate**. A package diagnostic that
flags 6 of every 16 healthy fits is worse than no diagnostic.

**Verdict: not usable as a gate.** Possibly usable as one input to a composite
score, but nothing here supports shipping it as a flag.

## The more useful implication — the 59/70 may be mislabelled

"Degenerate" in that grid means `rel_frob > 10`, i.e. **failure to recover
`Sigma_true`**. That is not a property a fit can observe, because truth is not
available to a diagnostic.

A fit can be a perfectly well-converged optimum of a model the data does not
identify. If that describes most of the 59, then:

* **no fit-side diagnostic can flag them**, and looking for one is looking for
  something that cannot exist;
* the framing "Laplace reported convergence on genuinely degenerate fits" is
  itself wrong — the optimiser converged correctly; the *model* was not
  identified by the data;
* `convergence == 0` and `pdHess = TRUE` are then **true statements**, answering
  a question the user is misreading, exactly as after-task §6a said of `pdHess`
  in the Heywood case.

That reframing is **AGENT-INFERRED and untested**. The test that would settle it:
for the degenerate cells, check whether the fit is at a genuine local optimum of
a flat/ridged likelihood (multi-start agreement, profile curvature along the
trailing eigenvector) versus a failed optimisation. If they are genuine optima,
the finding is about identifiability, not about convergence reporting, and the
honest fix is documentation plus an identifiability warning — not a convergence
flag.

## Notes on the run

Three control defects were found and fixed before the numbers above were
trusted, each of which would have produced a confidently wrong verdict:

1. **No family filter.** Healthy poisson cells were re-simulated with `rbinom()`
   at the same seed, reproducing the exact degenerate bernoulli datasets — the
   first run reported *byte-identical* statistics for both groups.
2. **Blanket seed exclusion.** Seeds repeat across configs, so excluding every
   seed appearing in the degenerate set emptied the healthy group entirely. It
   was also unnecessary: within `arm = gtmb_laplace` and `family = bernoulli`
   all 281 rows have unique `(n,p,q,seed)`, so a healthy cell cannot be a
   degenerate one.
3. **Exact `(n,p,q)` matching produced 1 healthy cell against 16 degenerate.**
   That is itself a finding: **degeneracy is concentrated in the small cells** —
   at `n=40, p=8` almost every fit is degenerate, so there are almost no
   same-size healthy controls. The control was relaxed to the cheapest healthy
   cells with per-cell `n`/`p`/`q` reported so size confounding stays visible.

## Scope

16 vs 16, bernoulli only, `n` in {40,…,200}, `p` in {8,20}, `q` in {2,4}, single
fit per cell, one OS, one BLAS. The control is size-spanning rather than exactly
matched, so some of the group difference may be size rather than degeneracy —
the per-cell columns in the CSV allow that to be checked.
