# v0.6.0-rc.1 — adversarial review result and the honest rung

**2026-07-22.** The RC ceremony ran to completion on the maintainer's authorisation. Outcome: the RC
is **platform-clean**; the D-49 adversarial review returned **unanimous 3/3 NOT-READY**; **submission
is WITHHELD** on one real gap. This is the gate working, not a failure.

## Exact-tag evidence — complete and green at `v0.6.0-rc.1` (source `e9bc655a`)

| Check | Result |
|---|---|
| RC tarball `gllvmTMB_0.6.0.tar.gz` (SHA-256 `532c205b…`, 3.25 MB) `--as-cran` | **0 errors, 0 warnings, 1 NOTE** (New submission); forbidden-path scan NONE |
| 3-OS `R-CMD-check` (run 29977191886, at the tag) | ubuntu + macos + windows all SUCCESS, 3× `Status: OK` |
| Heavy `full-check` (run 29977182659, at the tag, 3-OS) | all three OS `FAIL 0`, 3× `Status: OK` |
| Local suite + CRAN-config | transfer from the 10th chain (shipped content byte-identical; diff empty): `0/779/7290`, `0/0/1` `SHA_STABLE` |

Ledger: `~/gllvmTMB-0.6-evidence/m5-rc1/`. Grace independently verified the tarball matches the tag
exactly (SHA, size, `HEAD == e9bc655a`, tag points at HEAD, clean worktree, **zero source edits**,
version 0.6.0 consistent across DESCRIPTION/NEWS/tarball).

## The review: 3/3 NOT-READY, submission WITHHELD

**One blocking reason, shared by all three reviewers:**

> **win-builder R-devel and macbuilder have not run.** CRAN checks first submissions on **R-devel**;
> the 3-OS matrix pins R **release** only. gllvmTMB is a compiled C++17/TMB/RcppEigen package with
> real R-devel exposure, where new NOTEs/WARNINGs commonly appear. This is the standard first-submission
> due-diligence step and the single thing separating a clean candidate from an uploadable submission.

This gap was **predeclared** in the freeze record and is an **external upload held for the maintainer** —
the ceremony correctly stopped here rather than crossing it.

**One doc fix (done): `cran-comments.md`** cited the pre-freeze run IDs (29969703136/29969704205); it
now cites the frozen-tag runs (29977191886/29977182659) and names the win-builder R-devel step as
pending. `cran-comments.md` is `.Rbuildignore`d, so this did not change the tarball.

## What the review confirmed is SOUND (not a blocker)

- **Honesty bar MET** (Rose, independently verified at the tag): **no forbidden coverage-calibration
  claim survives on any shipped surface** — every calibration mention in `man/`, the shipped vignette,
  README, NEWS, and DESCRIPTION is a negation or scoped exactly to "the Gaussian cells that cleared the
  gate" (matching CI-08). No cell is described as calibrated.
- **D-41 experimental warning** present and consistent across all four channels.
- **Known residuals** (R-2, R-6, R-7, CI-08, CI-10, FAM-17/MIX-10) disclosed and not contradicted.
- **The deferred page review is NOT a tarball blocker** — the 19 articles are `.Rbuildignore`d
  (confirmed absent from the tarball), so no unreviewed article wording ships. It remains a maintainer
  quality gate to complete before a **stable** (non-rc) release.
- Rose's one register note: R-11's formal claim-string sweep "must not be assumed done" — a formal M4
  confirmation would close the register's own open item (her spot-sweep found only negations).

## The honest rung (D-49 / D-66)

**`platform-clean` at the RC.** NOT `submission-ready`. The gap to submission is:

1. **win-builder R-devel + macbuilder** on `gllvmTMB_0.6.0.tar.gz`, reconciled — **maintainer's**
   (external upload).
2. The **page-by-page reader review** — maintainer's (deferred for rc.1; required before a stable release).
3. **CRAN submission** itself — the maintainer's act alone.

The agent ceremony has taken the release as far as it can without the maintainer. Everything up to the
R-devel gate is done, green, and honest.

> Frozen: `docs/dev-log/2026-07-22-candidate-freeze-rc1.md` · runbook:
> `docs/dev-log/2026-07-22-m4-to-m5-runbook.md` · review entry point:
> `docs/dev-log/2026-07-22-REVIEW-ME-shinichi.md`.
