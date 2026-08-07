# gllvm comparator (S3 betabinomial) — always 2×2

Same standing rule as S0b/S1/S2. Canonical write-up:

`lanes/va-s0b-exact/protocol/gllvm-comparator.md`

For every S3 scientific cell, report **gllvmTMB VA × gllvmTMB LA × gllvm VA × gllvm LA**
vs planted truth on matched seeds/DGP. Our VA (R3/GH) ≠ gllvm `method="VA"`.
Mark an arm `N/A` with reason only after attempting it.

## Pre-flight (gllvm 2.0.13, 2026-08-07)

| arm | status |
|---|---|
| gllvmTMB VA (GH H=7) | expected live |
| gllvmTMB LA | expected live (`cbind(succ,fail)` + `betabinomial()`) |
| gllvm VA `beta.binomial` | **N/A** — "not implemented with method VA" |
| gllvm LA `beta.binomial` | **N/A** — errors ("condition has length > 1") across Ntrials shapes |

Still attempt both gllvm arms in the probe so the raw CSV records the refusal.
