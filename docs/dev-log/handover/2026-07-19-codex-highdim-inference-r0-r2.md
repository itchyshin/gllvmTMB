# Handover — high-dimensional non-Gaussian inference decision arc

**Branch:** `codex/highdim-inference-decision-20260719` at the merged O3 head.

## Rehydrate first

Read `AGENTS.md`, then:

1. `docs/dev-log/after-task/2026-07-19-highdim-inference-r0-r2.md`
2. `docs/design/85-highdim-nongaussian-va-formal-contract.md`
3. `docs/dev-log/audits/2026-07-19-highdim-inference-precode-claim-audit.md`
4. `docs/dev-log/research/2026-07-19-highdim-inference-reference-harness-spec.md`

## State

R0 (local and NotebookLM synthesis) and R1 (formal contract) are complete.
R2 is specified but not implemented. The existing q=1/q=2/scalar O3 tests
pass. R3 is **CONDITIONAL/BLOCKED**: it requires a passing R2 receipt and a
fresh maintainer GO before any internal VA prototype, Totoro/DRAC work, or
new source/test code.

## Do not do

- Do not build q>=3 AGHQ or expose an AGHQ/VA argument.
- Do not call an ELBO ML, AIC/BIC, Cox--Reid, REML, or calibrated inference.
- Do not reopen CI-11, profile/Bartlett, tier-2a, Ayumi, or
  `docs/dev-log/check-log.md` from this branch.
- Do not use the failed `R CMD check` metadata result as evidence about this
  research documentation.

## Next safe action

Only after the 0.6 article/capstone sequencing permits it, implement the R2
reference harness exactly as specified. Run a local smoke first, inspect the
manifest and guard statuses, then ask Rose to admit or withhold R3. Compute
begins only after that admission.
