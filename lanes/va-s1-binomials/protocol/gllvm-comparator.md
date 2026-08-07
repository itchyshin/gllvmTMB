# gllvm comparator (S1) — always 2×2

Same standing rule as S0b. Canonical write-up:

`lanes/va-s0b-exact/protocol/gllvm-comparator.md`

For every S1 scientific cell, report **gllvmTMB VA × gllvmTMB LA × gllvm VA × gllvm LA**
vs planted truth on matched seeds/DGP. Our VA (R3/GH) ≠ gllvm `method="VA"`.
Mark an arm `N/A` with reason only after attempting it.

## Link-specific VA tiers (internal)

| link | gllvm `method="VA"` | our default (`auto`) | our gllvm-matched opt-in |
|---|---|---|---|
| logit | JJ / PG | GH | `eval_method="jj"` (also public via `va_eval_method`) |
| probit | Albert–Chib | GH | `eval_method="ac"` (internal) |
| cloglog | truncated-Poisson **PoisG** | GH | `eval_method="poisg"` (internal, 2026-08-07) |

PoisG does **not** flip `auto`; Design 110 default for cloglog remains GH.
Σ under PoisG may still collapse — report honestly; matching gllvm VA is not
a Σ-recovery claim.
