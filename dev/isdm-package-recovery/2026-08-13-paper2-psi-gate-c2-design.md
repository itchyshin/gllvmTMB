# Paper 2 Gate C2 — numerical-admission and Psi-information separation

**Status:** implemented as a private no-fit contract.  It preserves
`PAPER2_PRIVATE_STOP_HOLD` and authorises no candidate, repair, threshold
change, fit, profile, simulation, campaign, empirical case, reader packet or
public claim.

## Fixed quantities

For a future replicate, retain the existing indicators without amendment:

\[
A_i=\text{frozen joint numerical admission},\qquad
P_i=I\left\{\max_s|\widehat\Psi_{i,ss}-\Psi_{i,ss}|\le0.20\right\}.
\]

`A_i` includes the frozen numerical/profile predicate and `P_i` is diagonal-Psi
variance recovery using \(\widehat\Psi_{ss}=\exp(2\widehat\theta_{\rm diag,s})\).
Neither quantity explains, replaces or waives the other.  Case C remains
`NO_CANDIDATE`.

## Gate C2 no-fit deliverables

1. A hash-addressed frozen-record receipt for model, fixture, DLL, maps,
   profile grid, numerical atomic predicates, all five truth criteria, `A`,
   `P`, known-truth joint recovery `K`, and strict joint result `J=A K`.
2. A per-cell all-attempt schema for the fixed S=6/20/60, R=20 design: the
   `A` by `P` 2x2 table, atomic counts, five recovery counts, `K`, `J`,
   first-failure ledger and available-ledger diagnostics.  Errors/missing
   ledgers remain all-attempt failures.
3. An interpretation memo: profiles remain admission evidence; weak-profile
   counts and loading--Psi diagnostics are descriptive stratifiers only.  The
   only permitted readings are co-occurrence, persistence among admitted fits,
   or inconclusiveness—not causal information claims.
4. A figure-sidecar schema that permits a private design schematic and a
   one-row n=1 Case-C ledger only.  Result tables, distributions and profile
   figures remain deferred.

## Promotion and stop rule

An exact-hash mismatch, changed threshold/denominator, candidate/retry
language, causal interpretation of S, or a claim that Paper 1 evidence promotes
Paper 2 is an immediate C2 HOLD.  Only after independent review of these four
no-fit deliverables may a fresh, separately approved campaign proposal request
timing evidence and compute approval.

## 2026-08-13 C2 receipt outcome

The receipt fixes the independent `S = 6, 20, 60`, `C = 360`, `r = 3`,
`b = d = 1`, `R = 20` cells and validates the retained S=6 record without
constructing a model.  That single historic attempt has `A = FALSE`,
`P = FALSE`, and fails the diagonal-Psi variance threshold (`0.2156398 >
0.20`).  It supplies a one-row ledger, not a co-occurrence rate or causal
Psi-information explanation.  `PAPER2_PRIVATE_STOP_HOLD` and `NO_CANDIDATE`
therefore remain in force; no campaign has been authorised.
