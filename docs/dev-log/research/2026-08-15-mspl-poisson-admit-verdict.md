# Poisson LA-MSPL admit verdict — KEEP PLANNED

**Date:** 2026-08-15
**Role:** Ada (adjudication only)
**Workspace:** `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap`
**Branch at adjudication:** `cursor/mspl-se-ci` @ `fa3c92a9`
**Status:** verdict note only. No registry edit. No `src/`. No admit.

**Reader:** the next MSPL conductor who arrives at the Phase-4 Poisson
cell and wants to know whether `poisson:log:ordinary:q1` / `q2` may
flip from `planned` to `admitted` tonight.

---

## Verdict

**KEEP PLANNED.** The Poisson LA-MSPL registry rows
`poisson:log:ordinary:q1` and `poisson:log:ordinary:q2` stay
`status = "planned"`, `evidence = "phase4_prep"`. No admission is
recommended, and `R/mspl-registry.R` was not edited by this sitting.

The decision rule for this adjudication was pre-committed: admit only
if `docs/dev-log/research/2026-08-15-mspl-poisson-point-smoke.md`
exists **and** is an unambiguous PASS. Default otherwise is KEEP
PLANNED.

---

## The decisive fact

The smoke note now exists. It is **not** an unambiguous PASS.

`docs/dev-log/research/2026-08-15-mspl-poisson-point-smoke.md`
records a split table and a FAIL headline for admission:

| Surface | Smoke-note verdict |
|---|---|
| Operational local point smoke (8 seeds, 64 arms, `se = FALSE`) | **PASS** — every arm `conv = 0`, finite objective, registry stayed `planned`, no \(\max|\Lambda|\ge 15\) runaway |
| Admit evidence (Phase 4 exit + prep §8) | **FAIL** — rate `c = 1` unpinned; Poisson loading atom under Laplace still OPEN; two sparse MSPL arms died to a null factor; no prediction / penalty-sensitivity / TMB-oracle packet; Shinichi gate not held |

The smoke note's own headline is `n=8`, **FAIL** for admit evidence.
The existence test therefore passes and the unambiguity test fails.
KEEP PLANNED is the default branch of the pre-committed rule.

Machine TSV (same sitting, committed beside the note):
`docs/dev-log/research/2026-08-15-mspl-poisson-point-smoke.tsv`.
Script: `dev/mspl-poisson-multiseed-point-smoke.R`. Tree named in
the smoke note: `cursor/mspl-poisson-point-smoke` from
`origin/main` @ `fa3c92a9`.

---

## Why operational PASS is not admission

All 64 arms converged with a finite objective. That is the
operational smoke, not the scientific exit. Programme constitution
Phase 4 and kill-list item 7 both say a finite count fit is not the
result. Two sparse MSPL arms collapsed shared loadings to numerical
zero (`max|Λ| = 1.78e-6` on sparse q=1 seed 160904;
`9.24e-7` on sparse q=2 seed 160903). RelF versus true \(G\) is then
exactly 1. On seed 160904, ML's relF 0.618 *beats* that collapsed
MSPL. Finite-and-stationary is not a recovered factor.

The remaining Phase-4 / prep §8 items are still open:

1. a proved **loading** atom under Laplace — still **OPEN**;
2. the soft rate \(c\) — still **unpinned** (`c = 1` on the live
   Poisson door; Bernoulli \(c_n\) and Gaussian \(c_N\) remain
   rejected transplants);
3. healthy-regime no-harm plus boundary DGPs as an *admission*
   packet — the 8-seed smoke is local, not that packet;
4. family-specific TMB oracles after the tape — not run as an
   admission suite;
5. the Shinichi gate — not held.

Kill-list item 10 forbids admission-shaped language ahead of that
gate. A flip on tonight's smoke would trip items 7 and 10 together.

Healthy cells are mixed, not a win: q=1 MSPL closer to \(G\) on 5/8
seeds; q=2 split 4/8 with median relF slightly favouring ML
(0.494 vs 0.551). Sparse cells look better for MSPL on 15/16 seeds
and are an anti-runaway *observation*, not a covered recovery claim.

---

## What the public door does and does not mean

`.gllvmTMB_mspl_prepare()` now accepts `family_id %in% {0, 1, 2}`
(`R/mspl.R:182`), so Poisson-log ordinary `latent()` reaches a
public, **experimental** LA-MSPL door via #978. That is a door, not
an admission. `R/mspl-registry.R:119-132` still reads:

```
status   = "planned"
evidence = "phase4_prep"
notes    = "Phase 4 fenced planned tape: GLM-outer W=diag(mu), not
            I_LA(beta); public estimator=mspl is experimental; not
            admitted; not covered"
```

The tape is **GLM-outer** \(W = \operatorname{diag}(\mu)\), not the
Laplace information \(I_{LA}(\beta)\). A reachable experimental
surface with a local smoke that itself refuses admission is exactly
the state in which `planned` is the honest label.

---

## Required standing statements

- **No SE campaign.** None is issued, and none is authorised by this
  verdict. Host = none, minutes = 0, Totoro not started, DRAC not
  started, GitHub Actions not used as a campaign host.

- **#972–#976 remain UNMERGED.** All five Phase-4 prep PRs are OPEN
  against the stale base `cursor/mspl-point-programme-continue`, not
  `main`. They must not be merged from the MSPL tapes or SE lanes.
  Census: `docs/dev-log/research/2026-08-15-mspl-972-976-unmerged.md`.
  #978 is merged and carries the tapes plus the Poisson public door.

- **Public `se = TRUE` is withheld.** Under `estimator = "mspl"`,
  `sd_report` is set to `NULL` regardless of `gllvmTMBcontrol(se =)`.
  SE / intervals stay PROTECTED on Codex Lane B.

---

## Non-claims

This note does **not** claim:

- that Poisson LA-MSPL fails — only that the smoke is not an
  unambiguous PASS for admission;
- a Poisson point-recovery, no-harm, or boundary *admission* result;
- calibrated inference, SEs, coverage, width, or intervals;
- that the loading atom or the rate \(c\) is settled;
- NB1 / NB2 / Tweedie / Beta inheritance from any Poisson outcome;
- NEWS `covered` or validation-register promotion;
- that nonzero offsets are admitted.

---

## Rose boundary

- **No registry edit.** `R/mspl-registry.R` untouched; `git diff` on
  it must stay empty for this sitting.
- **No `src/`.** No tape change; `git diff -- src/` stays empty.
- **`planned` ≠ `admitted`.** Poisson rows keep
  `evidence = "phase4_prep"`.
- **No NEWS `covered`,** no validation-debt promotion.
- **Not EVA / not VA / not AGHQ-MSPL.** The estimator is LA-MSPL:
  Laplace plus a soft outer penalty.

## Next action

Human-only, at a later G0: either commission the missing admission
packet (pinned \(c\), proved loading atom, TMB oracles, and a
Shinichi gate) or close the Phase-4 Poisson question as deferred.
Until a smoke note exists **and** reads as an unambiguous PASS, the
verdict on this cell is KEEP PLANNED.

## Sources

- Rule input: `docs/dev-log/research/2026-08-15-mspl-poisson-point-smoke.md`
- Machine TSV: `docs/dev-log/research/2026-08-15-mspl-poisson-point-smoke.tsv`
- Prep: `docs/dev-log/research/2026-08-15-mspl-phase4-poisson-prep.md`
- PR census: `docs/dev-log/research/2026-08-15-mspl-972-976-unmerged.md`
- Registry rows: `R/mspl-registry.R:119-136`
- Prepare fence / public door: `R/mspl.R:181-190`
