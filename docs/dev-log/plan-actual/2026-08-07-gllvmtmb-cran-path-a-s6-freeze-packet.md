# S6 — Candidate freeze packet (Path A option B)

**Lane:** gllvmTMB-cran-path-a-0.6.1  
**Branch:** `cursor/cran-path-a-0.6.1-20260807`  
**Worktree:** `/private/tmp/gllvmtmb-cran-path-a-0.6.1`  
**Date:** 2026-08-07  
**Status:** **FROZEN (S6 GO)** — Shinichi approved option B (rebuild from post-`#949` `main`, re-verify, freeze tip). **STOP before S7.**

---

## Identity checklist (frozen)

| Item | Value | Verified |
| --- | --- | --- |
| Version | **0.6.1** (`DESCRIPTION`) | yes |
| Engine default | Laplace (AGHQ/VA opt-in/fenced) | NEWS 0.6.1 + `gllvmTMBcontrol` Rd |
| Interval claim | Narrow `profile_ci_total_variance()` regime named; else recovery/uncalibrated | DESCRIPTION + zzz |
| VA `#949` | **IN** freeze — squash `d7bee2fa` on `origin/main`, merged into Path A | merge commit on branch |
| VA intervals | `calibrated = FALSE` / research / opt-in | NEWS + Rd |
| July `v0.6.0` receipts | **Not** tip evidence | cran-comments TBD rows |
| Upload | Shinichi only (M5-g) | contract |

## Frozen SHA

**Freeze tip** = tip of `cursor/cran-path-a-0.6.1-20260807` after the S6B stamp commit (recorded in `lanes/gllvmtmb-cran-path-a-0.6.1/LOOP/checkpoint.md`).

```sh
git -C /private/tmp/gllvmtmb-cran-path-a-0.6.1 fetch origin
git -C /private/tmp/gllvmtmb-cran-path-a-0.6.1 rev-parse HEAD   # must match checkpoint freeze SHA
git -C /private/tmp/gllvmtmb-cran-path-a-0.6.1 status -sb        # must be clean
```

**Merge base for option B:** `origin/main` @ `d7bee2fac876e736e8eb2f13864bbc47ce300214` (`#949` squash).  
**Integration:** `git merge origin/main` into Path A (ort; **no conflict markers**). Kept Path A Version `0.6.1` + honesty fences; took Arc-1 VA code/tests/NEWS from `#949`.

**Freeze means:** no further source edits on this identity. Any edit remints the package and voids D-49 receipts (M4→M5 runbook).

## Re-verify at post-merge tip (S6B)

| Check | Result |
| --- | --- |
| Rose-style claim scan (NEWS/README/`gllvmTMBcontrol` Rd) | No soft-PASS Arc-2; Laplace default; VA research/opt-in; `calibrated = FALSE` present |
| `pkgdown::check_pkgdown()` | No problems found (EXIT 0; `/tmp/gllvmtmb-cran-s6b-pkgdown-check.log`) |
| `test-integration-fence.R` | FAIL 0 / PASS 57 |
| `test-va-control-exposure.R` | FAIL 0 / PASS 33 |

## Pre-freeze arcs completed

| Arc | Outcome |
| --- | --- |
| S0 | Vault D-89 Path A amend; D-66 clarifying note; AGENT_LOG |
| S1 | RECON inventory |
| S2 | Honesty fences (DESCRIPTION/zzz/NEWS/AGHQ “fixed 9-node”) |
| S3 | Version bump → 0.6.1 |
| S4 | `cran-comments.md` 0.6.1 skeleton; platform rows **TBD until exact-tag** |
| S5 | `pkgdown::check_pkgdown()` → No problems found |
| S6 (first pass) | OPEN GATE packet; Shinichi chose **option B** (rebuild with `#949`) |
| S6B | Merge post-`#949` `main`; re-verify; **freeze tip** |

## What freeze does **not** authorize

- RC / final tags (M5-a / M5-d — separate 🛑) — **S7 not started**
- CRAN upload (M5-g — Shinichi only)
- Coverage re-measure (D-112)
- Laplace→AGHQ/VA default flip
- Soft-PASS / Arc-2 claims
- D-113 / 0.7 capability work

## NEXT (OPEN GATE)

**S7 exact-tag ceremony** — only in a fresh chat after maintainer GO. Do not cut RC/final tags or upload from this session.
