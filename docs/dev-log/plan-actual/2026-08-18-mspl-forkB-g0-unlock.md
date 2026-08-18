# Plan vs actual — g0_unlock fork B (2026-08-18)

**Plan:** `docs/dev-log/lanes/cursor-mspl-fork-B/LOOP/ultra-plan.md`  
**Lane LOOP:** `docs/dev-log/lanes/cursor-mspl-fork-B/LOOP/`  
**Reconciler:** Melissa (six materiality axes only)

Campaign close after A5. L0 [#1130](https://github.com/itchyshin/gllvmTMB/pull/1130) `d7f526d4` and L1 [#1128](https://github.com/itchyshin/gllvmTMB/pull/1128) `715326af` are on `origin/main`. This file does **not** start L2.

## Axes

| Axis | Planned | Actual | Tag |
|---|---|---|---|
| Scope | Design 125 G4c = fork B recorded; D-148→D-159 + PARK→REPLACE; L0 penalty-off measurable (`calibrated=FALSE`, public refuse); L1 local coverage smoke logged. Stop at L2. | Delivered. Decision [#1129](https://github.com/itchyshin/gllvmTMB/pull/1129); kit [#1127](https://github.com/itchyshin/gllvmTMB/pull/1127); L0 [#1130](https://github.com/itchyshin/gllvmTMB/pull/1130); L1 [#1128](https://github.com/itchyshin/gllvmTMB/pull/1128). No Totoro, no T\*, no undraft [#1077](https://github.com/itchyshin/gllvmTMB/pull/1077), no public `se` / `vcov` / `confint`, MSPL-04 still `blocked`. | match |
| Evidence | Local ADEMP L\* on ≥1 binary-first anchor cell, \(n_{\mathrm{rep}}\) 50–100: \(\widehat{\mathrm{cov}}_{\mathrm{eff}}\) Wilson not entirely below 0.80; availability ≥ 0.90; refusal ≤ 0.15. E1 + E2 named in the envelope. | Official L1 on `main`: cell `L1-anchor-n80-T8`, \(n_{\mathrm{rep}}=50\), seed_base `20260818`, all 50 rows `tape=Q_0` / fork B. availability 1.000, refusal 0.000, \(\widehat{\mathrm{cov}}_{\mathrm{eff}}=0.880\), Wilson [0.7620, 0.9438], 50/0/44, **L1-PASS**. E2 not walked on this harness (probe still requires `b_fix`). Not calibrated; not a public coverage claim. | match (E1); **adaptive** (E2) |
| Model routing | Kit = Cursor Grok / docs-only. L0 = `cursor/mspl-forkB-l0-20260818`. L1 = `cursor/mspl-forkB-l1-smoke-20260818`. Decision = `cursor/mspl-forkB-decision`. | Kit landed as [#1127](https://github.com/itchyshin/gllvmTMB/pull/1127). L0 authorising code shipped as [#1130](https://github.com/itchyshin/gllvmTMB/pull/1130) (`objective=` selector; `tape=` kept as synonym) and **closed** [#1126](https://github.com/itchyshin/gllvmTMB/pull/1126) rather than dual-merging it. L1 ADEMP + main-reproducible 50-rep receipt = [#1128](https://github.com/itchyshin/gllvmTMB/pull/1128). | **adaptive** |
| Safety gates | Local compute only. Public doors stay closed. Root `LOOP/` frozen GOAL_MET. Merge of the kit is a human gate. Totoro / T\* / undraft #1077 / MSPL-04→covered / NEWS covered = hard OUT. | Held. `gh pr view 1077 --json isDraft` → `true`. Root `LOOP/` untouched by this campaign. Shinichi G0-preapproved the L0/L1/docs squash-merges; this reconcile PR is the same preapprove. | match |
| Public claims | No `se=TRUE`, no `vcov()` / `confint()`, no NEWS / README / article `covered`, no MSPL-04 flip. L1 PASS is a plumbing-plus-crude-coverage gate, not a licence for public intervals. | Held. Receipt and after-task state `calibrated = FALSE`, `coverage_claim = none`. Wilson lower 0.762 is recorded, not hidden. | match |
| Handoff | After A5: `checkpoint.md` names **L2 — needs Shinichi G0**; this Melissa file; after-task + check-log. D-43 panel fires once on L1 PASS. | Checkpoint / arcs / decision-queue updated this sitting. D-43 panel **not** fired — L1 is not a public claim and the user asked for reconcile only. | **adaptive** |

## Material deviations

1. **L0 PR identity** — planned owner was [#1126](https://github.com/itchyshin/gllvmTMB/pull/1126) (`tape=` only). Actual authorising code is [#1130](https://github.com/itchyshin/gllvmTMB/pull/1130) (`objective = c("penalised", "unpenalized")`, default penalised; `tape=` synonym). #1126 CLOSED as superseded. **`adaptive`** · Ada. Reason: splitting the signed G0 from the selector that implements it is how the two drift; #1130 carries both.
2. **E2 not on the official L1 receipt** — ultra-plan envelope names E1 and E2; the ADEMP harness on `main` is E1 only because the probe still refuses non-`b_fix` coordinates. Companion [#1143](https://github.com/itchyshin/gllvmTMB/pull/1143) recorded E2 as 400/400 `R-ENV` (NOT-EVALUABLE), but that 800-row walk is L0-worktree, not main-reproducible. **`adaptive`** · Fisher. Official L1 stays the #1128 E1 cell.
3. **Wilson rule** — signed L\* is “Wilson not entirely below 0.80”, taken as Wilson *upper* ≥ 0.80. The interval [0.762, 0.944] overlaps 0.80 and also dips below it. Requiring Wilson lower ≥ 0.80 would have FAILed this cell. **`adaptive`** · Fisher. Recorded in the #1128 after-task; not a silent reinterpretation.
4. **Second L1 harness PR** — [#1143](https://github.com/itchyshin/gllvmTMB/pull/1143) (`dev/mspl-forkB-l1-lib.R` + coverage-gate runner + 61 arithmetic tests) is complementary files, not a second official verdict. It was CONFLICTING on `check-log.md` after #1128 landed. This sitting resolves it rather than leaving two L1 owners. **`adaptive`** · Ada.
5. **D-43 panel skipped** — ultra-plan said fire once after A5 PASS. Not run. L1 PASS is explicitly *not* a public coverage claim; running a completion panel here would dress a local smoke as a milestone. **`adaptive`** · Rose. No `drift` — the user asked for GOAL_MET reconcile and hard-OUTed L2 / public se.

## Drift to Rose

None unjustified. L2 not started. #1077 stays draft. MSPL-04 stays `blocked`.

```
DECISION RECEIPT
  Questions asked      — AskQuestion 2026-08-18: g0_unlock vs docs-only vs full public unlock;
                         fork A/B/C (asked twice). Queue Q3: stop on L1 PASS vs draft L2 G0
                         in the same sitting?
  Answers received     — "g0_unlock"; "Fork B" twice. This sitting's user line: finish
                         reconcile; next gate L2 needs Shinichi G0; NO L2 start, no Totoro,
                         no undraft #1077, no public se. G0-preapprove tiny docs squash-merge.
  Defaults accepted    — Queue Q1 (PR decision+code whole) ran as #1130. Queue Q2 (L0 test
                         specs vs test files) ran as tests on #1130. Queue Q3 default
                         (stop and record; do not pre-draft L2) ran.
  Adaptive decisions   — Close #1126 rather than dual-merge with #1130; treat #1128 as the
                         official L1 number; skip D-43; resolve #1143 instead of leaving it
                         CONFLICTING.
  Unresolved           — L2 / Totoro / T* / undraft #1077 / public se / MSPL-04→covered
                         remain hard OUTs for Shinichi. E2 still has no main-reproducible
                         coverage walk. Hand to Rose only if someone cites 0.880 as
                         calibrated coverage.
```
