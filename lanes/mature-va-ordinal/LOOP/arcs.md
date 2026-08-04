# ARCS — mature-VA Item 1(B) ordinal

Status: `TODO` · `WIP` · `DONE (verified: <how>)` · `BLOCKED` · `GATE`

| id | arc | status | gate | dep |
|---|---|---|---|---|
| **A0** | **Retract the false "VA is refuted" claim** at every surface it reached: `dev/va-speed/46-VA-VS-LA-VERDICT.md`, `docs/dev-log/handover/2026-08-03-claude-handover-va-lane2-blockers-closed.md`, `dev/va-speed/20-CLAIMS-LEDGER.md`, `docs/dev-log/check-log.md`. Visible banner (the `305b6b86` pattern), never a quiet edit | TODO | — | — |
| **A1** | **Harden `43-va-vs-la-ladder.R`** — record AND assert the resolved `eval_method`/`collapse`/`H`; abort loudly on mismatch; fix `va_iters = NA`; record a real convergence flag | TODO | — | — |
| **A2** | **Ordinal ψ-collapse probe** — characterise where AC's known ψ collapse would bite for ordinal, using the shipped Laplace ordinal path across `n_trials` × #categories × planted ψ | TODO | **G1** | — |
| **A3** | **`va_r3_log_pnorm_diff`** — stable `log(Φ(a) − Φ(b))` per derivation §5.7, re-pointed at `va_r3_log_pnorm`, clamp at `-1.2e-16`. **The crux** | TODO | **G2** | — |
| **A4** | **Family code 5 wiring** — template: two `DATA_IVECTOR`s (`n_ordinal_cuts_per_trait`, `ordinal_offset_per_trait`), cutpoint `PARAMETER_VECTOR`, the AC ordinal term; R: `.va_r3_family_name_to_code`, Laplace→VA map, validation, tier guard | TODO | — | A3 |
| **A5** | **Correctness verify** — mirror `06-ac-tier-verify.R`'s 21 checks for ordinal | TODO | — | A4 |
| **A6** | **Recovery test** + the registry-drift test at `test-va-r3-prototype.R:510` (adding a tier WILL break it — correct, update it) | TODO | — | A4 |
| **A7** | **Mechanical verify** — full VA suite green; fence intact asserted by test | TODO | — | A5,A6 |
| **A8** | **Consolidate** — after-task report, check-log, validation-debt register row, handover | TODO | — | A7 |
| **A9** | **Reconcile plan vs actual** (Melissa) | TODO | — | A8 |

**PARALLEL:** {A0, A1, A2, A3} · **SEQUENTIAL:** A4←A3, A5←A4, A6←A4, A7←{A5,A6}, A8←A7, A9←A8

## Gates

- **G1 — after A2, the shipping shape is the maintainer's call.** AC-alone collapses a real ψ at
  low `n_trials`; for binomial the remedy was to **end on GH**, and **there is no ordinal GH tier
  to warm into**. A2's measurement picks between:
  **(a)** ship ordinal AC fenced with the ψ-collapse regime measured and stated (cheapest);
  **(b)** also build an ordinal GH tier so the warm route exists (doubles the arc);
  **(c)** fence ordinal AC to the regime where ψ *is* recovered.
  **(b) changes scope materially → STOP and surface.** (a)/(c) are inside the approved fence and
  may proceed once A2's numbers are in.
- **G2 — A3 is a hard technical STOP.** If `he()` is not finite over the `|a|,|b| > 8.2924`
  same-side region, do not proceed to A4. That is the exact defect PR #925 fixed, and it is
  invisible to every gradient check.
- **G3 — pushing `claude/va-lane2`** remains the maintainer's call (standing). Do not push.

## Carried over into this lane

- A second Claude session committed to this branch earlier today (`695450d2`, `305b6b86`,
  `2a174fb9`), including a rewrite of a handover and a commit made from this session's working
  tree. Nothing lost; surfaced for the maintainer, not resolved here (D-87).
- Two orphaned `41-va-health-diag.R --args 5000` processes from a prior session may still be on
  Totoro. Harmless (2 of 384 cores); leave them.
