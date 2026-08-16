# Plan vs actual — Model 2 multi-source (2026-08-16)

Reconciler: Melissa. Plan: the approved Model 2 ultra-plan (`generic-giggling-tulip.md`).
Lane: `claude/isdm-model2-multisource-20260816` · PR
[#1030](https://github.com/itchyshin/gllvmTMB/pull/1030).

## Scope

**ADAPTIVE — the arc was resized DOWN by measurement before any code.** The plan itself was
built on two probes showing "engine extension" was the wrong frame; the maintainer approved
that framing. No silent scope change followed: `src/` untouched, exactly one new export.

**ADAPTIVE, disclosed at the time — Design 112 became Design 120.** The planning scout
under-counted (checkout-only view); the preflight census was right; the number was claimed
by committing first. The goal text still says 112 — the discrepancy was surfaced in chat the
moment it was found.

**DRIFT (inherited class, disclosed) — the deliverable's "article" did not ship.** The plan's
closure line did not include it; the deliverable line did. Treated as a maintainer decision
and put in the PR's "Needs you" rather than done unasked or silently dropped. Third
occurrence of goal-text/closure-line ambiguity — worth a template fix: the closure line
should enumerate everything the deliverable names, or the deliverable should not name it.

## Evidence and verification

**Clean, and the gate earned its keep again.** The adversarial review returned 3 blockers +
6 concerns; all fixed or recorded, none argued away. The most consequential was **B2**: a
campaign claim ("more arms help the PA mix") was an averaging artifact — the reviewer
predicted the split metric would show flat-to-worse, the campaign was re-run with the split,
and the prediction held (0.129/0.133/0.133). **A quantitative claim was retracted in place
and the retraction is committed in the results doc**, not just in the review thread. This is
the fourth review of the day to catch something the producer was confident about.

**ADAPTIVE — the campaign ran twice.** First run used the pooled metric; the re-run (same
grid, same seeds) emitted per-arm RMSE. Cost: ~30 s of Totoro. Recorded because "the
campaign was run" would otherwise hide that its first results were partially wrong.

**D-139:** priced from the pre-run, wall-clock basis stated after review caught the
core-minutes/wall-minutes conflation (C4); the price was conservative (pre-run per-fit
includes `load_all()` overhead). One dead launch on an environment error, relaunched.

## Model routing

**DRIFT (forced, third occurrence of the known class).** The plan routed S2 (design doc) and
S3 (implementation) to Opus children and S4/S5 to Sonnet. Write-capable Agent dispatch has
been blocked by the permission classifier all session, so S2–S5 ran inline on the
orchestrator (Fable). Read-only children ran as planned: 1 Sonnet scout, 1 Opus reviewer.
The drift ledger's proposed fix (a fallback routing line in the plan template) is now
supported by three occurrences in one day.

**Children: 2 of the 7 authorised.** Under budget; the ceiling child (the review) was the
one that mattered.

## Safety gates

**Clean.** Preflight + per-file preflight before editing the hot file; design number claimed
by commit; D-143 (100 of 384 cores); D-64 (ControlMaster socket, no Duo); sweep receipt with
commands cited; every DEFER item stayed deferred — and one item moved INTO the deferred set
explicitly (all-PA declarations, B1) rather than shipping half-working.

## Public claims

**Clean after correction, and the correction is the evidence.** One campaign reading was
retracted (B2); the results doc carries the retraction visibly; NEWS/register/design were
re-audited after the fixes (no register codes on reader surfaces — grepped). The register
row now states what only 600 of the 1,200 fits exercise, the PA-arm saturation, and the
two-source-only spatial inheritance — three boundaries the first version under-stated.

## Handoff state

**Clean.** Branch pushed, worktree clean, PR #1030 open with the review findings and
dispositions in the body. Merge with the maintainer (new export). Campaign artifacts
committed (harness, results doc v2, raw CSV).

## For the drift ledger

1. **Planned sub-agent builds absorbed inline when dispatch is blocked** — third occurrence
   today. The template needs a fallback-routing line.
2. **Pooled recovery metrics manufacture findings when arm counts vary across cells.** New
   class, worth a guard: any campaign whose grid varies the number of estimand groups must
   report per-group metrics, or the aggregate will move for composition reasons alone.
