# Integrated-SDM Phase C findings — #943

## Evidence boundary

Phase C is a developer-only simulation campaign on spatial recording bias in
an integrated presence-only / presence-absence GLLVM; it is not a package
feature or a real-data integrated SDM. Frozen source
`7e26e1bdb9d0f99fd67ec3a4850bcf2e28d7229b`, the corrected pilot, G1--G6
results, and receipts are under
`/Users/z3437171/local-scratch/gllvmtmb-isdm-artifacts/7e26e1bd/run4-aligned`.
The independent campaign-audit receipt SHA-256 is
`4a1df5570a4231366c6ec9a7925a7d97fc1f81363c2d0a0c5ce865d60e268f91`.
C-lite and the sealed old pilot are excluded.

## Result

The primary shared-bias cell passes: A1 at `kappa=1`, `rho=0`, `omega=1`,
`n=400`, `T_sp=8`, and `d_fit=2` gives paired `dD_bias=0.45218` (MCSE
`0.00220`), with 100/100 complete and both-pdHess pairs. It clears C1/C2.
The A5--A6 attribution contrast is `0.31360` (MCSE `0.00230`) and clears C3.
Thus, in this shared-bias regime, omitted recording bias contaminates fitted
ecological correlation and the A5--A6 contrast attributes it to omitted bias
structure rather than Hessian selection.

This is not a universal mechanism result. All 32 negative R5 cells occur in
`omega=0` controls, where the design expects diagonal rather than shared-factor
distortion. The immutable preregistered aggregate remains `H_SINK_REFUTED`;
the separate D-43 post-analysis addendum preserves every cell result and says
`H_SINK_UNRESOLVED_PREREGISTRATION_SCOPE_CONFLICT`.

R3/R4 remain unresolved under their frozen rules. G6 is unsupported; G5/A6 is
qualified sensitivity evidence (7/50 retained fit errors). The campaign retains
7 fit-error rows, 1,342 nonzero-convergence completed rows, and 21
`pdHess=FALSE` completed rows.

## D-43 conclusion

The initial panel withheld completion because the global wording overreached.
The addendum then passed unanimous Curie/Fisher/Noether rereview: it hashes the
immutable v1 inputs, copies the 432 R1--R5 cells unchanged, keeps all 32 R5
control results, and changes only the explicitly post-analysis global
interpretation. Phase C is complete as a reproducible, qualified campaign.
