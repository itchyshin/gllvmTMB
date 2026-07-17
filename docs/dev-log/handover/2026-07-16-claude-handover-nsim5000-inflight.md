# Handover CORRECTION → Sigma_unit coverage arc is WITHHELD (my earlier "EARNED" was WRONG)

**Corrected 2026-07-17.** An earlier version of this file concluded the scoped gaussian-n≥150
`Sigma_unit` diagonal certificate was EARNED and drove toward a public flip. **That was wrong.**
The authoritative, committed decision is **WITHHELD**.

## Authoritative record (repo = ground truth)

- Committed after-task: `docs/dev-log/after-task/2026-07-17-sigma-coverage-nsim5000-confirm.md`
  (`f0f17333`, Shinichi).
- Directed Lane-A note: `docs/dev-log/check-log.md` §"2026-07-17 → Lane A … WITHHELD + MCSE-convention
  flag" (`1d862396`).

## Why WITHHELD (what my in-session analysis got wrong)

- **d1-n150 is certify-grade; d2-n150 is NOT.** d2-n150 **fails on rorqual: 0.9398 < 0.94** under the
  **committed conservative MCSE** (`m3-pilot-report.R:554` = `sqrt(p(1−p)/n_sim)` ≈ 0.0032). On Totoro
  it is a razor-thin 0.9409.
- My in-session adversarial panel let its refuters use the **trait-level ~0.0015 MCSE** (the "earlier
  draft" convention the committed record flags as wrong) and I had **no cross-hardware check** — so it
  wrongly returned "2/3 certify". Under the committed 0.0032 MCSE + rorqual, the certificate is not earned.
- **Root cause of the miss:** I did not re-diff the branch before acting; Shinichi's WITHHELD commits
  had already landed on the branch during the session. Repo state is authoritative — check it first.

## Correct state

- **NO public flip.** widget / NEWS / `confint` roxygen unchanged (my flip edits were reverted; nothing
  committed, nothing public touched).
- **S6 `confint` Sigma_unit-diagonal profile wiring: NOT merged** (coupled to the certificate claim).
- **Recovery-only framing for 0.6.** Exclusion = non-convergence (conditional-on-convergence; disclose
  the rate). Binomial/nbinom2/ordinal/off-diagonal/n<150 fenced.

## Lift path (per the committed note)

**FRESH-SEED reps** (NOT same-seed — the rorqual run was same-seed, so it corroborates but adds no
independent precision) to shrink the MCSE so **d2-n150 clears 0.94 with margin**, then re-audit d2. The
launcher `dev/totoro-profile-rescore.sh` (S1 `$HOME`/OUTDIR + socket fix, uncommitted) is ready for it.
The flip-wording draft `docs/dev-log/2026-07-16-sigma-coverage-flip-wording-DRAFT.md` stays parked until
d2 is earned (and must carry the conditional-on-convergence framing).

## Fresh-seed lift run (Option A) — STAGED, launch pending classifier (2026-07-17)

Shinichi approved running A. Runner `dev/profile-rescore-run.R` extended with `--rep-start/--rep-end`
(shard a fresh rep WINDOW) + `--family/--n-units` filters (synced to Totoro; smoke green for reps
5001-5002). Detached launcher staged on Totoro at `~/gllvm_work/run_freshseed.sh`:
96 shards, **reps 5001..20000** (15,000 FRESH reps, disjoint seeds from the original 1..5000),
`--family=gaussian --n-units=150`, `--n-boot=10` (profile is the target, not bootstrap),
out-dir `~/gllvm_work/profile_rescore_freshseed`, log `freshseed.log` (marker `FRESHSEED_DONE`).
**To run:** `mkdir -p ~/gllvm_work/profile_rescore_freshseed` FIRST (redirect-dir bug), then
`setsid bash ~/gllvm_work/run_freshseed.sh > .../freshseed.log 2>&1 </dev/null &` (idempotent: guard on
`pgrep -f rep-start=5001`). **Then:** aggregate the fresh reps + POOL with the original 5,000 (from
`profile_rescore/`) → N=20,000 → re-audit d2-n150 under the COMMITTED MCSE `sqrt(p(1-p)/N)` (~0.0016).
Earn iff d2 lower band ≥ 0.94 with margin; else d2 is genuinely borderline → defer to 1.0. ~1.6 h.

## Still valid from the session (separate from the coverage verdict)

- Ayumi **#18** convergence-criterion fix `c5c56f41` (committed, in branch history).
- Ayumi **#17 / #18** replies posted; gllvmTMB tracking issue **#750** (unconditional RE redraw) opened.
- S1 launcher fix (uncommitted, useful for the fresh-seed run).
- `disp_group` (shared NB2 dispersion): **DEFERRED** per Shinichi's note — supersedes my S7
  merge-as-opt-in recommendation.
