# Poisson LA-MSPL admit packet — pinned \(c_P\) and event-weighted loading atom

**Date:** 2026-08-15
**Branch:** `cursor/mspl-poisson-admit-packet`
**Status:** science landed; registry stays **`planned`**. Not admitted.
Not NEWS `covered`. Not public `se = TRUE`.

**Reader:** the next MSPL conductor who needs the missing Phase-4
science (rate + loading atom + TMB/R oracles) without flipping
admission.

---

## What was missing

The #990 smoke was an operational PASS and an admit-evidence FAIL:
soft rate \(c=1\) was unpinned, the Poisson loading atom under
Laplace was OPEN, and the live tape still used Bernoulli
\(V_{\mathrm{loading}}\). Programme constitution Phase 4 and prep
§8 require those pins before any `planned` → `admitted` flip.

This packet pins the candidate atoms and matches the live tape to
pure-R oracles. It does **not** claim healthy-regime no-harm,
boundary recovery, prediction, or a Shinichi admission gate.

## Pinned rate

\[
c_P=2\sqrt{p_{\mathrm{free}}/\max\bigl(\textstyle\sum y,\,1\bigr)}.
\]

Event count is the information-size proxy. This is not Bernoulli
\(c_n=2\sqrt{p_{\mathrm{free}}/N_{\mathrm{rows}}}\) and not Gaussian
\(c_N=\sqrt{2/N_{\mathrm{units}}}\). It is not the placeholder
\(c=1\) (full Firth scale on the Jeffreys piece; huge on loadings).

- All-zero data floors the denominator at 1, so \(c_P\) stays finite
  and \(O(\sqrt{p_{\mathrm{free}}})\).
- \(c_P\to 0\) as \(\sum y\to\infty\).
- Known exposure at fixed observed \(y\) does not change \(c_P\).

AGENT-INFERRED analogy to the Bernoulli vanishing scale, using
Poisson event count instead of row count. Not a transferred theorem.

## Pinned loading atom

\[
V_\lambda^P=\sum_t\Bigl(\sqrt{1+\|\lambda_t\|^2\,\bar y_t}-1\Bigr),
\qquad
\bar y_t=n_t^{-1}\sum_i y_{it}.
\]

- All-zero traits contribute 0. Jeffreys-on-\(\beta\) owns
  \(\mu\to 0\).
- Coercive as \(\|\lambda\|\to\infty\) at \(\bar y_t>0\).
- Recovers Bernoulli \(V_{\mathrm{loading}}\) only at \(\bar y\equiv 1\);
  that coincidence is not a transfer.
- Rotation-invariant in the factor space (row Euclidean norms).

This is the outer loading atom, not a second copy of the Laplace
\(\tfrac12\log\det H_u\) term. AGENT-INFERRED. Not Design 88
\(V_{\mathrm{loading}}\) and not Hirose.

## Jeffreys atom (unchanged)

GLM-outer \(W=\operatorname{diag}(\mu)\),
\(P_J^*=\tfrac12\log\det(X_*^\top W X_*)\). Not \(I_{LA}(\beta)\).

TMB nll adds \(-c_P P_J^* + c_P V_\lambda^P\).

## Oracles

`tests/testthat/test-mspl-poisson-admit-packet.R` A1–A8. A7 is a
live `estimator="mspl"` Poisson fit that checks
`report$mspl_c_n`, `report$mspl_V_loading`, and
`report$mspl_logdet_information` against the R twins. Registry
assertions in A8 keep `planned`.

## Still planned

Healthy / sparse multi-seed no-harm, prediction, penalty
sensitivity, and the Shinichi admission gate remain OPEN. Finite
and matching oracles are necessary and not sufficient (constitution
Phase 4). NB1 / NB2 / beta / Tweedie are not inherited.

## B1 Totoro / DRAC (not started)

Design 118 B1 is an approved *fence*, not a job this sitting
started. Launch remains a written-receipt act (D-50 / D-139). Do
not start a >30 min remote job from this packet.

Suggested later command shape (do not run tonight):

```sh
# After a D-139 receipt naming host, minutes, and shard list:
# ssh totoro && OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 \
#   Rscript --vanilla <B1 driver from #981 / Design 118 §6>
```
