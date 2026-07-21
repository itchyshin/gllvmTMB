# gllvmTMB 0.6 arc-loop decision queue

The loop parks consequential decisions here and continues only genuinely
independent reversible work. An empty queue does not waive gates listed in
`LOOP/GOAL.md`.

| Gate | State | Question | Recommendation | Blocked work | Safe work meanwhile |
|---|---|---|---|---|---|
| M1 close | OPEN | Does exact-head local/platform evidence plus fresh D-43 support closing M1? | Default NOT-DONE until every receipt is terminal | **M3 entry** (M2 is cut) | finish M1 tests/docs/receipts |
| Design 86 | **CUT 2026-07-21** | ~~Approve the new narrow q1 estimator/scientific contract?~~ | **Superseded by the maintainer's EVA cut. Never written or approved — do not cite as a contract. A 0.7 successor must target sparse binary, not q1 multi-trial, and needs its own Gate-0 scope freeze.** | nothing — no EVA work in 0.6 | the Laplace-only release path |
| Remote scientific compute | **CUT 2026-07-21** | ~~Approve Totoro smoke + DRAC pilot for the frozen campaign?~~ | **Dissolved with M2. No Totoro/DRAC scientific compute for 0.6; compute target is LOCAL only.** Revisit only when a 0.7 EVA contract exists. | nothing | local package checks only |
| Public EVA | **CUT 2026-07-21** | ~~Admit the evidence-backed allowlist to the installed package?~~ | **Resolved as CUT. 0.6 ships Laplace-only; no `integration = "eva"` surface is created.** | nothing | Laplace-only release path |
| #750 spde redraw | **RESOLVED 2026-07-21** | Does 0.6 ship unconditional spatial RE redraw? | **No — doc corrected to match code; #750 retargeted to 0.7.** The implemented work is stranded on parked branches (`dd80244a`..`051eb4e5`, not in `origin/main`); it was NOT brought in, to avoid touching the quarantined estate and re-minting M1's source identity. | nothing | — |
| Release ceremony | NOT YET OPEN | Approve API/candidate freeze, RC/final tag, and submission at each rung? | separate decisions; never bundle them | irreversible outward action | read-only review and receipt assembly |
