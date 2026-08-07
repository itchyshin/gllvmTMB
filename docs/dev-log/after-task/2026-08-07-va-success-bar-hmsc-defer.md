# After-task — VA success bar lock + HMSC deferral (2026-08-07)

## Scope

Shinichi affirmed the near-term scientific success bar for the VA validation
series and asked whether **HMSC** (`https://github.com/hmsc-r/HMSC`) must enter
the comparator panel. Docs-only lock; no package / fence change.

## Outcome

**Bar LOCKED for now (before harder distributions):**

1. gllvmTMB **VA ≲ LA** (or better) on abs recovery vs planted truth (default LA;
   LA+tricks when exploring).
2. gllvmTMB **VA ≲ gllvm** (or better) on the mandatory **2×2** (our VA ≠ gllvm VA).
3. Dual-report reliability stays; Arc-2 / public fence unchanged.

**HMSC recommendation:** **later paper / bounded capstone comparator — not a
near-term must-compare and not a drop-in 5th arm.** Bayesian JSDM / posterior
mean ≠ MLE; Jason scout §5b and Design 87 already say do not build an HMSC
validation *programme*. Worth ~1 day later for `phylo_latent + spatial_unique`
(Phase 5.5), not S0/S1 gating.

## Evidence consulted

- Brain (`search_all_projects: true`): vault *HMSC scout (2026-07-29)*; Bolker
  follow-up (Ovaskainen / HMSC as subject match); DR3 JSDM landscape.
- Repo: `docs/dev-log/audits/2026-07-29-jason-hmsc-cross-package-scout.md` §5b;
  `docs/design/87-latent-variable-oracle-map.md` (“Not worth building” HMSC
  programme); `docs/design/05-testing-strategy.md` Phase 5.5 planned row;
  register has **no** HMSC row (correct — not a VA-series blocker).

## Files touched

- `docs/dev-log/2026-08-07-va-validation-series-arc0-ultraplan.md` — locked bar + §E HMSC
- `lanes/va-s0b-exact/protocol/gllvm-comparator.md` — locked bar + HMSC note
- `lanes/va-s0{a,b}-*/protocol/absolute-first.md` — bar + HMSC deferral lines
- Mission Control `live/status/gllvmTMB.json` — light `capability.note` / decision receipt (if edited)

## Checks

Docs-only; no `devtools::test` / fence edit. Pre-edit: no colliding open PR on
these paths in the last 6 h beyond this lane’s own docs commits.

## Follow-up

None blocking. HMSC stays on the paper / Phase 5.5 menu.
