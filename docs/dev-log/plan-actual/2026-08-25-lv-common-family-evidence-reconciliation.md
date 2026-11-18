# Plan vs actual — LV common-family evidence reconciliation

Date: 2026-08-25
Reconciler: Melissa
Plan: `docs/dev-log/plans/2026-08-25-lv-common-family-evidence-reconciliation.md`

## Result

The lane returned exactly:

`LV_COMMON_FAMILY_HOLD__RAW_OR_LINEAGE_GAP`

The source-pinned bridge implementation is reusable engineering input. The
historical coverage/recovery tables are not reusable calibration evidence
because their seed-level results, failed attempts, earned MCSEs, denominator
policy, and all-family K=2 driver are not retained.

## Six-axis reconciliation

| Axis | Planned | Actual | Classification |
| --- | --- | --- | --- |
| Scope | One receipt; status edits only after REUSABLE | HOLD receipt, plan, check-log, closeout artifacts; Design 73/register/status untouched | met |
| Evidence | Source-pinned ancestry, DGP/estimand, families, raw-vs-narrative, denominators, bugs, endpoint | All audited; clean candidate pinned at `8c9acc76`; absence of raw/K=2 driver is load-bearing | met |
| Model routing | Luna-low provenance, Sol-high integration/adjudication, Terra-high Rose/Grace close review | Same routing; no duplicate scouting or ceiling-level child | met |
| Safety gates | GLLVM.jl read-only; no duplicate campaign; estimate before fits; stop before remote or >30-minute work | No fit/compute/remote mutation; four-fit 8--20-minute pre-run frozen but not launched because clean-worktree authority is absent | met |
| Public claims | No public or native-TMB promotion | No reader-facing, NEWS, API, family, or validation-status change | met |
| Handoff | After-task, Melissa record, handover, narrow local commit; no push | Same; branch remains local and unpushed by design | met |

## Material deviations

Two plan defects were corrected adaptively; neither widened the lane.

1. Phase 0.25 initially left the GLLVM.jl twin finding as “pending exact
   receipt” after decomposition had begun. The completed row now records the
   pinned candidate and raw/lineage gap. This is plan drift caught before
   closure, not missing scientific work.
2. The plan initially called the receipt a D-43 milestone while substituting a
   smaller review panel. Once HOLD meant no implementation, status promotion,
   or public claim, D-43 was marked explicitly N/A. The Sol adjudication and
   Rose/Grace close review remain proportionate gates.

Execution friction, not scope drift: Unlazy G2 failed first on an invalid R
escape and then on Git's collapsed untracked-directory display; the Poisson
detector had the same first-pass escape defect. Each failed attempt is recorded
in the check log, and the final checks use fixed strings plus
`--untracked-files=all`.

## Melissa verdict

Two adaptive plan corrections; zero scope, safety, public-claim, routing, or
handoff drift. HOLD was applied conservatively: compatible source contracts do
not substitute for retained claim-bearing evidence.
