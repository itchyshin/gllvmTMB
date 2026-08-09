# Phase C prospective amendment 4: one geometry tolerance

Date: 2026-08-09  
Lane: `claude/experiment-integrated-sdm`  
Issue: #943

## Trigger and sealed state

The first preflight attempt from portable-identity source `5e40aef1` stopped in
the pure geometry stage, before any model fit or scientific statistic. Totoro's
linear algebra produced a maximum component-Gram error of
`2.497e-10`. The outer preflight contract and independent campaign verifier had
already frozen and enforced a numerical tolerance of `1e-9`, but the inner
`.exact_bias_basis()` helper retained a stale default of `1e-10` and rejected
the same geometry.

The failed attempt wrote no result or receipt and is not evidence. It remains a
declared infrastructure/instrument failure under its original artifact path.

## Repair

Set `.exact_bias_basis(geometry_tol = 1e-9)` by default so the generating helper,
the 54-case preflight, the hashed preflight contract, the result diagnostics,
and the independent verifier use the same tolerance. The numerical-rank
tolerance remains `1e-10` and its fail-closed guards are unchanged.

This harmonises an existing frozen contract; it does not change the DGP,
configuration grid, random-number streams, estimand, scientific thresholds,
pilot decision rule, or analysis. A component-Gram error above `1e-9` still
fails before fitting.

The replacement preflight and all downstream compute require a new clean source
commit and new immutable artifact paths. No earlier pilot or preflight result is
reused for a statistical decision.
