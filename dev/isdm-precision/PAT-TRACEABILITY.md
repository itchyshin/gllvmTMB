# Pat's blocking items — traceability

The acceptance gate is **not** "is it correct?" but *"could you now adapt this
to your own data?"* This table exists so that judgement is made against
coverage rather than impression. Every row names the evidence, not an
intention.

Her verdict was: *"the honesty is spent in the wrong places: the fences guard
against claims I would not have made, and leave open the two things I would
actually have got wrong."* **The two things are items 7 and 1.** Both now have
measured answers.

| # | blocking item | status | evidence |
|---|---|---|---|
| 1 | "Correlation length" never defined — the only number the article asks her to compute, ambiguous by 3x | **measured** | Block 1. 1/e definition, validated against known truth, plus its measured limit (unreliable above phi ~ 1/10 domain width; error always downward, so it errs toward caution) |
| 2 | Opportunistic arm has no sampling bias — not the decision she faces | **measured** | Block 10. Tested with a biased PO arm, bias modelled, `env` _|_ `access`: claim survives 14/15 at fuzz 0.5 and 1.0 |
| 3 | Arms 50/50, so the result is the mechanical midpoint | **measured** | Block 7. She is RIGHT about the design (gap 0.023-0.041 at 220/220) and wrong that the claim depends on it (15/15 in all three designs; dose-response in arm weight) |
| 4 | Neither figure carries its own fence; the PNG is what leaves the page | **half closed** | Both precision-article figures now carry "SIMULATED DATA — point estimates only; no interval or coverage claim" *inside the plot device*, verified by rendering a standalone PNG and looking at it rather than by reading the code. The Warbler figures still need the same treatment (S4/S5) |
| 5 | "narrower intervals" contradicts "No coverage claim" | **resolved** | Block 4. Clause cut; the design supports no interval claim |
| 6 | `spatial_scalar(0 + trait \| coords)` — no column called `coords` | **measured** | Block 2. `coords`, `banana` and `xy` all give logLik -63.01954 to 8 s.f. Filed as #1163 |
| 7 | The data shape is the one shape real integrated data never has | **measured** | Block 8 (corrected). Fully disjoint arms (0 shared ids, 0 shared coords) share a field through `make_mesh()`; dLogLik 284.06; omitting the field biases slopes 0.108 -> 0.041 |
| 8 | Copy-paste-ready covariate-scaling bug in the grid chunk | **measured** | Block 5. Within-species rank correlation EXACTLY 1.000 while abundances move up to 5.5x in opposite directions per species — invisible to every check a reader would run |
| 9 | `grid$cell_id <- cells[1]` — does the map inherit one cell's effect? | **measured** | Block 13. Identical to machine zero across cells 1, 2 and 50 against a prediction range of 4.166. Ignored, and the package warns |
| 10 | "Until recently ... silently dropped the spatial field" — which version? | **resolved** | Block 3. gllvmTMB 0.7.0 (development) |
| 11 | SPDE mesh built in unprojected lon/lat | **measured** | Block 11. 1.666x anisotropy; UTM better in 5/5 seeds, slope error 0.125 -> 0.054; and the likelihood mildly PREFERS the wrong mesh, so it cannot diagnose this |

**Also fixed, from her review though not on her numbered list:** her first real
step dead-ended because GBIF returns presences and the article fits Poisson
counts. Block 6 shows the Berman-Turner quadrature route works in gllvmTMB via
`weights =`, with quadrature density measured and the package's own
weighted-objective warning as the fence.

**Her single most-wanted change** — *"the opportunistic arm here is unbiased,
which is not why you integrate; this measures a cost, not a net"*, plus per-arm
sample sizes — is Block 10's framing plus an explicit `n` per arm, and is in
the rewrite brief.

## Score

**11 of 12 items have measured evidence.** Item 4 is half closed: the
precision article's figures now carry their fence in the PNG; the Warbler
article's do not yet.

Two of my own claims were wrong and are corrected in place rather than
deleted: Block 8's original mechanism (the fit had no spatial term at all) and
the severity of the offset confound (Block 12 — pedagogical, not statistical).
