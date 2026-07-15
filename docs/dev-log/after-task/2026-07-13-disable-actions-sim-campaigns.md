# After-task — disable simulation campaigns on GitHub Actions (D-50)

**Date:** 2026-07-13 · **Owner:** solo Claude · **Trigger:** maintainer (Shinichi) flagged
scheduled "Power pilot sweep" runs burning Actions minutes + creating artifacts.

## Scope / outcome

Policy (maintainer, 2026-07-13, = D-50): **GitHub Actions is for package checks, pkgdown
deployment, and merge CI only. All simulation / recovery / power / coverage / benchmark
compute runs on Totoro / DRAC / local — never Actions, and never as Actions artifacts.**

Audit found only two cron-scheduled workflows (`Power pilot sweep`, `full-check`); the
sim/recovery workflows were PR/`workflow_dispatch`-triggered but still ran heavy sims and
**uploaded artifacts** on Actions. Disabled the evidence-generating campaigns
(`gh workflow disable`, YAMLs preserved → reversible + portable to Totoro).

**Disabled (14):** Power pilot sweep · M3 production grid · dep-slope-identifiability-sweep ·
dep-slope-poisson-recovery · spatial-dep-identifiability-sweep ·
spatial-indep-slope-nongaussian-recovery · spatial-dep-slope-nongaussian-recovery ·
spatial-latent-slope-nongaussian-recovery · va-phase1-benchmark ·
coevolution-two-kernel-recovery · slope-grid-residuals-recovery ·
gamma-ordinal-recovery-depth · simulate-unit-trait-recovery · phylo-q-decomposition-recovery.

**Kept active (5):** R-CMD-check (PR check) · pkgdown (deploy) · full-check (nightly package
check) · spde-slope-base-engine-check + nightly-stale-test-fixups-gate (PR *correctness*
gates — run heavy test files to catch regressions; they are checks, not evidence campaigns).

## Where this compute goes now

The power/coverage campaign moves onto the local/Totoro path already built this session:
`pilot_scale_gate()` (`dev/m3-pilot-report.R`, the calibrated PASS-to-scale decision) +
`dev/power-pilot-*.sh` smoke ladder, run on **Totoro (≤100 cores)** per the 0.5→0.6 plan
(`~/.claude/plans/luminous-weaving-nova.md`, slices A1d/A2). Recovery sweeps (B-phase) run
locally / Totoro under `GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true`.

## Checks / follow-up

- `gh workflow list --all` confirms 14 `disabled_manually`, 5 `active`.
- Reversible: `gh workflow enable <id>` restores any workflow; YAMLs untouched.
- Open decision (maintainer): whether to also trim `full-check`'s nightly cron to
  PR/`workflow_dispatch` (the "local checks over CI" preference) — left active for now.
- The disabled campaigns' artifact-upload steps remain in their YAMLs; if any is later
  re-enabled it must drop the artifact upload (D-50 keeps outputs local).
