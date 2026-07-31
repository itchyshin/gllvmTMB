# Correction — EVA's niche DOES include Bernoulli-logit, and the literature predicts what we measured

**Date:** 2026-07-31. **Source:** grounded, citation-backed query against NotebookLM corpus
`b25e6c9f-500b-43da-8487-6430ce01d09b` (32 sources). **Status:** literature claims, quoted. Treated
as **triage, not authority** — the quotes are verbatim from the corpus; the primary papers should be
checked before any of this reaches a public surface.

## What I told Shinichi, and why it was wrong

I said repeatedly this session that EVA is *"out of its niche"* on Bernoulli, on the reasoning that
gllvm documents EVA as used *"when VA is not applicable"* and that VA **is** applicable to binomial.
Design 104 §4.4 says the same, and I leaned on it.

**That reasoning is link-dependent, and I dropped the link.** From the corpus:

> *"Sadly this is not always the case. **A prime example is the case of Bernoulli distributed
> responses with logit link function.**"*

> *"Finally, we point out that had we used the **logit** link instead, then by Lemma 1 the resulting
> VA log-likelihood would involve a term `E_q[log{1 + exp(eta_ij)}]`, and therefore **would involve
> numerical integration** to calculate and optimize. By contrast, using a **probit** link and thus
> Lemma 2 offers a **fully closed form** VA log-likelihood."*

So: **VA has a closed form for binary under PROBIT, and does not under LOGIT.** Bernoulli-**logit**
is the literature's own *prime example* of the case EVA exists for. Our fits are logit.

**Shinichi's instinct that EVA belongs on binary was better founded than my objection to it.** The
correction matters because it was load-bearing: I used it to argue EVA was the wrong route for the
A3 binary-JSDM regime.

## But the literature also predicts, precisely, the failure we measured

> *"**GLLVM-LA suffers from undercoverage, and GLLVM-EVA provides valid uncertainty quantification
> for `B` but not for `Lambda Lambda^T`.**"*

`B` is the regression coefficients; `Lambda Lambda^T` is the latent covariance — i.e. **`Sigma_B`**,
the quantity this package exists to estimate and the primary target of Gate 3.

That is exactly the split our own grid found. `gllvm_eva`'s recovery of `Sigma_B` is catastrophic
(median `kappa = tr(Sigma_hat)/tr(Sigma_true)` = 4.8e7, max 5.5e9, 203/300 degenerate). **The
literature says EVA does not deliver valid uncertainty for `Lambda Lambda^T`, and our measurement
says its `Lambda Lambda^T` recovery is the worst of any arm.** Independent agreement, from two
directions, on the same quantity.

## So the honest position on EVA, revised

**Not** *"EVA is out of niche on binary"* — that was wrong for logit.
**Instead:** EVA's niche genuinely includes Bernoulli-logit, **and** EVA is documented as delivering
valid inference for `B` but **not** for `Lambda Lambda^T`. Since `Sigma_B = Lambda Lambda^T` is
gllvmTMB's core estimand — the ordination, the covariance, the thing users come for — **EVA is the
wrong tool for this package's primary target, for a reason the literature states outright rather
than because it is being misapplied.**

If a user wanted `B` only, EVA would be defensible. For `Sigma_B`, both the literature and our own
grid say no.

## One claim from the corpus our own data disputes

> *"…while being **computationally more scalable than both** methods in practice."*

Measured here, bernoulli `q=4`, median seconds, compiled-against-compiled: at **n=400, p=20** —
`gtmb_laplace` **6.52**, `gllvm_va` 72.83, `gllvm_eva` **315.34**. EVA is the *slowest* arm at nearly
every cell we measured, not the most scalable. Our grid stops at `n = 400`; the scalability claim may
hold at the sizes it was made for (Ayumi's BIRDBASE is `n = 5397`), which we have never run.
**Recorded as an open disagreement between a cited claim and our own measurement, not as a refutation
of the paper.**

## Consequences

1. **Design 104 §4.4's rule needs a link qualifier.** *"EVA … never the default for a family that has
   EXACT or GH"* is right in outcome for us, but its stated reason — "where VA is tractable, VA is
   better" — is imprecise for binomial-logit, where VA is *not* closed-form tractable and reaches the
   answer by quadrature (our GH) or by a bound (our JJ). The rule should say so.
2. **The case against EVA for 0.6 stands, on better grounds** — `Lambda Lambda^T`, not niche.
3. **The case FOR implementing EVA is stronger than I represented**, if the target is `B` or the
   families VA cannot reach at all (tweedie, beta, `betaH`, `orderedBeta`, ordinal).

> Related: `docs/dev-log/2026-07-30-eva-parity.md` (ours ≡ gllvm's) ·
> `docs/design/104-va-family-coverage.md` §4 · `dev/totoro-grid/results/grid.csv` ·
> NotebookLM `b25e6c9f-500b-43da-8487-6430ce01d09b`
