# Design 86 Arc 2 — Gate 2 correctness-anchor ultra plan

## Goal

Seal Arc 1 and deliver only the private, information-rich Gate-2 recovery
anchor. Freeze the fixture before execution; build and smoke the two private
arms; run the bounded all-attempts anchor on Totoro only after the smoke; then
review and stop before Gate 3.

## Sequential slices

1. Seal Arc 1 at 3b479354285a8dcd69ab43cc26d98f98e6b98041 and use this clean
   Arc-2 worktree.
2. Draft the Gate-2 JSON, contract amendment, and build brief; pause for
   maintainer sign-off.
3. Implement only private EVA/Laplace runners and packing/provenance checks.
4. Run one local smoke; inspect its emitted inputs and receipts.
5. Run exactly the signed-off R = 500 anchor on Totoro at no more than 100
   cores; score every attempt.
6. Obtain fresh math, numerical, and scope verdicts; write closeout records and
   stop.

## Deferred

Gate 3 reference work, all Gate-4 simulation ladders, public API/integration,
changes to shipped source, and release claims are prohibited.
