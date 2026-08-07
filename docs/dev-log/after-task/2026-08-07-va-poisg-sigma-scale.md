# After-task: PoisG Σ scale ladder (cloglog)

**Date:** 2026-08-07  
**Branch:** `codex/va-gh-all-families`  
**Lane:** VA GH all-families / S1 binomials

## Goal

Test whether cloglog **PoisG** Σ̂ collapse (seen at n=120) dies with larger **n**
or a wider **p**. Ours + gllvm VA; GH/LA reference. No fence/`auto` flip.

## Outcome

**Σ never recovers under PoisG** at n∈{120,400,1000} p=8 (10 seeds) nor at
n=500 p=20 (8 seeds): collapse frac = **1.0** for `gtmb_poisg` and `gllvm_va`,
median tr(Σ̂) ~1e−10–1e−11. β improves with n and matches gllvm (~1e−6).
GH/LA pass_abs rises to 0.8–0.9 at n=1000. Verdict: **objective-level collapse**,
not a finite-n artefact.

## Artefacts

- Script: `lanes/va-s1-binomials/scripts/probe-cloglog-poisg-nladder.R`
- Audit: `docs/dev-log/audits/2026-08-07-va-poisg-sigma-scale.md`
- Results: `lanes/va-s1-binomials/results/poisg-nladder-20260807/`,
  `…/poisg-wide-500x20-20260807/`

## Checks

Probe only (no package code change). Wall ~510 s (n-ladder) + ~160 s (wide).

## Follow-up

None blocking. Do not flip cloglog `auto` to PoisG.
