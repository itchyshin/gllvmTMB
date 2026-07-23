# Design 86 Arc 3 — G2R-V1 prospective EVA smoke ultra-plan

```text
🎯 GOAL
PLATFORM: Codex. Deliver one prospective, private G2R-V1 EVA smoke outcome
for seed 86200002 while preserving the historical red Gate-2 evidence.
DISCIPLINE: valid maintainer Gate-B signature and a fresh clean-tree/hash
preflight are required before input construction; the result is never a
Gate-2 GO/NO-GO verdict.
```

## Locked boundary

The only live action is the existing private EVA runner with seed `86200002`,
the V1 fixture, and the V1 non-overwriting output root. EVA is the sole scorer.
Laplace, another seed, retry, campaign, Totoro/DRAC, Gate 3/4, public API, and
shipped-engine work are excluded. The historical fixture, seed `86200001`,
artifacts, and red result remain immutable.

## Sequential execution

1. Inspect the unique Gate-B block and signed JSON fields. An unsigned,
   duplicated, stale, or mismatched record stops before input construction.
2. In parallel, independently verify source/fixture/seed hashes and historical
   immutability; verify frozen starts, health, acceptance, interval, and
   collapse semantics; verify EVA-only scope and an empty output root.
3. Immediately before execution, repeat clean-tree, fixture-hash,
   `R/eva-proto.R == 3b479354`, `src/gllvmTMB.cpp == origin/main`, and
   output-root checks.
4. Invoke only `design86_gate2_eva_run()` with the canonical V1 output path,
   `seed = 86200002L`, and `rebuild = FALSE`.
5. Validate manifest/result/receipt hashes, `source_tree_clean = true`, exact
   seed/root/denominator, four-stage telemetry, and JSON-null semantics.
6. Close with a one-seed smoke record only. A failed health screen is retained;
   no retry, altered control, or follow-up run is permitted.

## Required conclusion

The closeout must say only whether the signed one-seed EVA receipt is valid
and whether the frozen rule admitted a winner. It must state that one seed
cannot satisfy the all-500-attempt denominator or reopen Gate 2, and that it
does not authorise any deferred work.
