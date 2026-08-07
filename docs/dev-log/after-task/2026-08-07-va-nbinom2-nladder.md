# After-task — NB2 n-ladder (Σ vs n; Totoro)

**Date:** 2026-08-07  
**Branch:** `codex/va-gh-all-families`  
**Scope:** Answer Shinichi — does NB2 Σ recover with larger n after
hopeless abs at n=120 smoke?

## Mathematical contract

No public API / likelihood / grammar / family / fence change. Probe-only
known-truth scoring; same Design-110 DGP as 2×2 smoke.

## Outcome

- Scripts: `lanes/va-s2-nbinom2/scripts/probe-nbinom2-nladder.R` +
  `launch-totoro-nbinom2-nladder.sh`.
- Totoro 12 seeds × n∈{120,250,400,1000}; arms gtmb LA / gtmb VA-GH H=7 /
  gllvm LA; gllvm VA only at n=120.
- Local D-50: `/private/tmp/va-s2-nbinom2-nladder-20260807/` (CSVs not staged).
- Audit: `docs/dev-log/audits/2026-08-07-va-nbinom2-nladder.md`.
- **Yes, larger n helps.** At n=1000 gtmb VA `pass_abs` 0.92 (Σ rf≈0.37) vs
  gtmb LA 0.42 (≈0.55). Smoke “prefer LA” still holds for **small-n cost**;
  VA-GH can **win abs Σ at large n** for NB2. No fence flip.

## Checks

```sh
ACTION=full PROBE_N_SEED=12 PILOT_CORES=24 \
  ./lanes/va-s2-nbinom2/scripts/launch-totoro-nbinom2-nladder.sh
# EXIT 0; summary MD5 f1e9a03f3c7f262ae3c85b901ea29134
```

Deliberately not run: fence/`auto`, package tests, gllvm VA n-ladder.

## Follow-up

- Optional: mark S2 NB2 default as size-regime-dependent (LA small-n / VA large-n).
- Next locked family after maintainer go: **betabinomial → beta**.
