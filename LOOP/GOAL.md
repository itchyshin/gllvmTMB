# GOAL — Integrated-JSDM identifiability diagnostic

**IMMUTABLE for this run. Re-read before every arc.**

## Goal

Produce a retained, paired sentinel experiment that triages whether the failed
integrated-JSDM gates respond to the scored estimand, within-cell information,
optimizer basin/termination, or Hessian curvature, and use that hypothesis-
generating evidence to name one bounded confirmatory experiment or engineering
investigation.

## Definition of done

- The package source is exactly `09eca7b1eb9018958bad367be824871161a60af1`
  (tree `fb979daa5d9a93d0804a053ff1bb00eced47ad09`) and the diagnostic
  harness is checksum-bound separately.
- A deterministic seed manifest is derived from the immutable 2,600-attempt
  campaign without replacing or modifying any production record.
- Four retained smoke fits validate source identity, record completeness,
  diagnostic extraction, and runtime before the experiment.
- Exactly 52 planned diagnostic task identities receive one terminal
  disposition: 16 nonspatial and 36 spatial. Every available fit is attempted
  once; a dependent task may be unavailable before optimizer entry.
- All started, failed, interrupted, and unavailable fits remain in the
  diagnostic denominator.
- An independent summarizer reports estimand decomposition, replication
  contrasts, optimizer transitions, gradients, and Hessian eigenstructure.
- Method, numerical, and scope reviewers sign off on the interpretation.
- The result names one evidence-bounded next action; it does not retune a gate
  or promote the package.

## Invariants

- Public `gllvmTMB(..., family = isdm_sources(...))` fitting route only.
- Existing production attempts and frozen gates are protected and immutable.
- No replacement fits, threshold changes, interval work, structured-source
  work, `*_coef`/`*_slope` work, API changes, or public promotion.
- Smoke fits are outside the 52-fit diagnostic denominator.
- Totoro only, at one thread per process and at most 16 concurrent workers.
- Estimated diagnostic runtime is 5–10 minutes. If the smoke projects beyond
  10 minutes, source identity fails, or retained output is incomplete, stop and
  report before the 52-fit experiment.
- A 10-minute live watchdog stops the experiment process group on estimate
  overrun, reconciles unfinished tasks once as interrupted/unavailable, and
  reports without relaunching.
- No GitHub Actions compute.

## Pre-authorisation

Shinichi approved this exact diagnostic experiment on 2026-08-29. Routine
isolated-lane edits, tests, Totoro smoke and conditional experiment, local
commits, branch push, draft PR, reviewed merge, exact-main verification, and
lease release are authorised. Stop for source drift, a runtime projection over
10 minutes, a changed estimand, a package/API change, threshold retuning,
credentials, protection bypass, release, or destructive work.
