# S6 — Candidate freeze packet (🛑 Shinichi)

**Lane:** gllvmTMB-cran-path-a-0.6.1  
**Branch:** `cursor/cran-path-a-0.6.1-20260807`  
**Worktree:** `/private/tmp/gllvmtmb-cran-path-a-0.6.1`  
**Date drafted:** 2026-08-07  
**Status:** **NOT FROZEN** — awaiting Shinichi 🛑 approval

---

## Identity checklist (proposed freeze)

| Item | Value | Verified |
| --- | --- | --- |
| Version | **0.6.1** (`DESCRIPTION`) | yes |
| Engine default | Laplace (AGHQ/VA opt-in/fenced) | NEWS 0.6.1 scope boundary |
| Interval claim | Narrow `profile_ci_total_variance()` regime named; else recovery/uncalibrated | DESCRIPTION + zzz |
| VA #949 | OPEN — **excluded** from freeze SHA | `gh pr view 949` |
| July `v0.6.0` receipts | **Not** tip evidence | cran-comments TBD rows |
| Upload | Shinichi only (M5-g) | contract |

## Proposed freeze SHA

**Freeze the tip of `cursor/cran-path-a-0.6.1-20260807` after the final LOOP/packet stamp commit** (Version `0.6.1`, tree clean, #949 not merged).

```sh
git -C /private/tmp/gllvmtmb-cran-path-a-0.6.1 fetch origin
git -C /private/tmp/gllvmtmb-cran-path-a-0.6.1 rev-parse HEAD   # proposed freeze
git -C /private/tmp/gllvmtmb-cran-path-a-0.6.1 status -sb        # must be clean
```

Parent content tip for review: `a7a4c60b` (S2+S3), `b3048ddf` (S4 cran-comments + packet), then docs stamps only.

**Freeze means:** no further source edits on this identity. Any edit remints the package and voids D-49 receipts (M4→M5 runbook).

## Pre-freeze arcs completed (reversible)

| Arc | Outcome |
| --- | --- |
| S0 | Vault D-89 Path A amend; D-66 clarifying note; AGENT_LOG |
| S1 | RECON inventory |
| S2 | Honesty fences (DESCRIPTION/zzz/NEWS/AGHQ “fixed 9-node”) |
| S3 | Version bump → 0.6.1 (DESCRIPTION, NEWS, CITATION, README, pkgdown comments) |
| S4 | `cran-comments.md` 0.6.1 skeleton; platform rows **TBD until exact-tag** |
| S5 | `pkgdown::check_pkgdown()` → No problems found |

## What freeze does **not** authorize

- RC / final tags (M5-a / M5-d — separate 🛑)
- CRAN upload (M5-g — Shinichi only)
- Merging #949
- Coverage re-measure (D-112)
- Laplace→AGHQ/VA default flip
- D-113 / 0.7 capability work

## Ask for Shinichi

1. Confirm freeze on this branch at the SHA named after the S4 commit (clean tree).  
2. Or request further cleanup edits **before** freeze (re-freeze required after any edit).  
3. After freeze: agents may proceed S7 exact-tag ceremony only on your next GO (RC tag still 🛑).
