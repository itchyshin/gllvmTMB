# Cursor handover — MSPL after Arc 1A cleanup (2026-08-15)

**Lane:** Cursor MSPL estimator programme  
**Worktree:** `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap`  
**Branch:** `cursor/mspl-arc-1a-provenance`  
**1A PR:** https://github.com/itchyshin/gllvmTMB/pull/962 (OPEN, do not auto-merge)  
**Programme PR:** https://github.com/itchyshin/gllvmTMB/pull/961 (draft docs vehicle)

Shinichi 2026-08-15: *"clean things up — we are going to do MSPL yes."*

## What was cleaned

Repo-root `LOOP/` on #962 would have overwritten the 0.6 release kit on
`main`. The Arc 1A `/goal` kit now lives at
`docs/dev-log/lanes/cursor-mspl-arc-1a/LOOP/`. Root `LOOP/` matches
`origin/main`.

Do **not** use the Dropbox checkout
(`/Users/z3437171/Dropbox/Github Local/gllvmTMB`); it has been on
foreign branches (`claude/design-117-separation-programme`, then a
cloud-agent branch).

## OWED

| Item | Status |
|---|---|
| Arc 1A implementation + parity tests | **DONE** |
| LOOP unclobber | **DONE** (this note) |
| Merge #962 | **GATED** — Shinichi |
| Arc 1B user-visible `estimator="ml"` outside Laplace | **OWED** — needs a **new G0** (API/semantic change) |
| Arcs 2–8 (registry, Gaussian Heywood, …) | **QUEUED** after 1B policy |
| Interval / jackknife lane | **PROTECTED** |

## Next Immediate Steps

1. Review and (when ready) merge #962. Leave #961 draft unless you want
   the programme doc on `main` separately.
2. New ultra-plan G0 for **Arc 1B only**: typed error, deprecation, or
   redesigned criterion argument for explicit `estimator = "ml"` with
   non-Laplace integration. Do not implement 1B without that approval.
3. After 1B policy, the first *scientific* MSPL route in the programme
   is the Gaussian factor / Heywood cell — not a family-wide expansion.

## Resume prompt

```text
Read AGENTS.md and docs/dev-log/handover/2026-08-15-cursor-mspl-after-1a-cleanup.md.
Work only in /private/tmp/gllvmtmb-mspl-estimator-programme-roadmap.
Reconcile with git and PR #962. Continue only OWED Next Immediate Steps.
Do not merge #962 unless Shinichi authorized merge. Do not start Arc 1B without a new G0.
```
