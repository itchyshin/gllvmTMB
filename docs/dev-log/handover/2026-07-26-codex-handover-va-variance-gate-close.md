# Session Handoff: VA-R3 variance-domain gate closeout

**Meta:** 2026-07-26 · from Codex · private research lane.

## Critical Context

Do not interpret a high-variance ELBO gap unless the independent product-GH
truth ladder converges. The high calibrated cell does not converge, and that is
the result—not a missing value to replace with Laplace or AGHQ.

## What Was Accomplished

An executable multi-trial-only runner and retained local campaign establish:

- observed 4.613715, 5.987552, and 8.674338 have stable H501-to-H801 truth
  ladders and negative fixed-coordinate ELBO--truth gaps;
- observed 22.190718 has H501-to-H801 spread 0.01636229, is
  `uninterpretable`, and has no ELBO--truth gap;
- no evidence identifies a break exactly at 4, but the current instrument does
  not adjudicate the high-variance regime.

## Current Working State

- Working: none; this limited measurement arc is closed.
- Protected: `claude/va-implementation-20260725` remains DO NOT MERGE because
  it widens to Bernoulli; do not copy its widening or separation guard.
- Separate: the private VA/EVA engine-spine branch retains its own documented
  `jsonlite` merge blocker.

## Key Decisions and Rationale

The `<= 4` gate remains frozen. This result does not authorize a threshold
relaxation, public selector, VA/EVA capability claim, Design 86 admission, or
Totoro replication. A future robustness arc must first establish a convergent
high-variance truth oracle.

## Landing State

| Artifact / branch | Committed | Pushed | PR | State |
| --- | --- | --- | --- |
| `codex/va-variance-gate-20260726` closeout commit (`git log -1`) | yes | no | none | CARRIED-OVER: local-only pending maintainer review/push; resume `cd /private/tmp/gllvmtmb-va-variance-gate-20260726 && git push -u origin codex/va-variance-gate-20260726` |
| local campaign receipt `/private/tmp/gllvmtmb-va-variance-gate-campaign-20260726/` | local receipt | n/a | none | CARRIED-OVER under D-50 |

## Next Immediate Steps

1. Preserve this branch and local receipt; do not rerun it as a threshold test.
2. If Shinichi separately approves a robustness claim, design a high-variance
   truth-oracle repair before any multi-seed Totoro campaign.

## Blockers / Open Questions

Can a new independently validated high-variance integration reference be built?
Without it, the sparse/high-variance VA-R3 regime remains indeterminate.

## Gotchas and Failed Approaches

Nominal DGP variance does not reliably map to fitted projected variance. The
initial nominal targets were retained as calibration attempts and replaced by a
frozen calibrated finite-fixture map; do not silently revive the old labels.

## How to Resume

```sh
cd /private/tmp/gllvmtmb-va-variance-gate-20260726
git status --short --branch
sed -n '1,240p' docs/dev-log/after-task/2026-07-26-va-r3-variance-domain-gate.md
Rscript --vanilla -e 'readRDS("/private/tmp/gllvmtmb-va-variance-gate-campaign-20260726/campaign.rds")$summary'
```
