# Ultra-plan — cursor-mspl-phase4-tapes-planned (G0-locked 2026-08-15)

Frozen at approval. Binding detail for this lane. Do not reopen
`cursor-mspl-phase4-prep-goal`.

```text
GOAL
Solo platform: Cursor
Deliverable: one shared weight-hook and five fenced planned C++ tapes; public estimator="mspl" runs only for gaussian, bernoulli, and Poisson
HEADLINE: all five tapes exist; only Poisson becomes newly callable; nobody is admitted
DEFER: admit · NEWS covered · SE · Totoro>30min · EVA/VA/AGHQ-MSPL · Codex interval · public MSPL on NB1/NB2/beta/Tweedie · five cpp editors
DISCIPLINE: failing tests before cpp · OMP=1 · prepare = gaussian+bernoulli+Poisson only
```

## Locked G0

- Five C++ tapes: Poisson, NB1, NB2, beta, Tweedie.
- Public door: gaussian, bernoulli, **Poisson only**. Others still error.
- Not admitted. No NEWS covered.
- `c` symbolic (unit scale 1 for new families; no Bernoulli/Gaussian transplant).
- Atom = GLM-outer `1/2 log det(X' W X)` candidate, **not** `I_LA(β)`.
- NB2 registry stays `excluded`. No new planned rows for NB1/beta/Tweedie.

## Atoms

- Poisson: `W=diag(μ)`, `log w = η` (log link, offset 0).
- NB2: `W=μφ/(φ+μ)`.
- NB1: PMF-summed exact `I_η` at fixed `φ`, **not** quasi `μ/(1+φ)`.
- Beta: Ferrari–Cribari-Neto mean-model weight; Jeffreys is **not** coercive at `μ→0/1`.
- Tweedie: `W=μ^{2-p}/φ`; atom **rewards** `φ→0`.

## HARD STOPS

No admit. No NEWS covered. No public `mspl` on NB1/NB2/beta/Tweedie.
No SE. No second `src/gllvmTMB.cpp` editor. No `git add -A`.
No calling GLM-outer `I_LA(β)`. No transplanted `c`.
Prepare message must not still say “binomial or gaussian only”
after Poisson is callable.
