# gllvmTMB 0.6 arc-loop decision queue

The loop parks consequential decisions here and continues only genuinely
independent reversible work. An empty queue does not waive gates listed in
`LOOP/GOAL.md`.

| Gate | State | Question | Recommendation | Blocked work | Safe work meanwhile |
|---|---|---|---|---|---|
| M1 close | OPEN | Does exact-head local/platform evidence plus fresh D-43 support closing M1? | Default NOT-DONE until every receipt is terminal | M2 entry | finish M1 tests/docs/receipts |
| Design 86 | NOT YET OPEN | Approve the new narrow q1 estimator/scientific contract? | Write only after M1; preserve Design 85 NO-GO and Design 72 sequence | all EVA implementation/compute | none needed before M1 close |
| Remote scientific compute | NOT YET OPEN | Approve Totoro smoke + DRAC pilot for the frozen campaign? | only after deterministic gates and immutable manifest | Totoro/DRAC jobs | local deterministic proof |
| Public EVA | NOT YET OPEN | Admit the evidence-backed allowlist to the installed package? | default CUT unless M2 scientific GO and M3 package gates pass | public API/docs | Laplace-only release path |
| Release ceremony | NOT YET OPEN | Approve API/candidate freeze, RC/final tag, and submission at each rung? | separate decisions; never bundle them | irreversible outward action | read-only review and receipt assembly |
