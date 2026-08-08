# After Task: Codex handover — CRAN 0.7 track pick locked

**Branch**: `cursor/cran-0.7-20260807` (worktree `/private/tmp/gllvmtmb-cran-0.7-20260807`)  
**Date**: `2026-08-08`  
**Roles (engaged)**: Ada (lock Q1–Q3 into files) · Rose (claim-fence + multi-lane pointer) · Shannon (read-only coord) · Grace (live-check routing named, not run)

## 1. Goal

Follow `handover-to-codex` exactly (`TARGET=codex`, `AUTHOR=claude`) so a new Codex session can resume the 0.7 CRAN lane with Shinichi’s 2026-08-08 morning answers, with no chat context.

## 2. Implemented

- Durable handover `docs/dev-log/handover/2026-08-08-codex-handover.md` addressed to Codex.
- Snapshot pointers: `AGENTS.md` rehydrate box; `CLAUDE.md` Live Phase Snapshot prepend; lane-split CRAN 0.7 / Path A rows.
- G0 file + LOOP checkpoint/GOAL updated with Q1–Q3 answers.
- Check-log + this after-task.
- Vault D-89 / D-113 morning clarifying notes (DECISIONS only; AGENT_LOG was already dirty).

No public R API, likelihood, formula grammar, family, NAMESPACE, generated Rd, vignette body (except G0/dev-log), or pkgdown navigation change.

## 3. Files Changed

- `docs/dev-log/handover/2026-08-08-codex-handover.md`
- `AGENTS.md`
- `CLAUDE.md`
- `docs/dev-log/handover/2026-07-25-active-lane-split.md`
- `docs/dev-log/plan-actual/2026-08-07-gllvmtmb-cran-0.7-g0.md`
- `lanes/gllvmtmb-cran-0.7/LOOP/checkpoint.md`
- `lanes/gllvmtmb-cran-0.7/LOOP/GOAL.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-08-08-codex-handover-cran-0.7.md`
- vault `~/shinichi-brain/memory/DECISIONS.md` (separate repo)

## 3a. Decisions and Rejected Alternatives

- **Decision:** write on the 0.7 worktree branch, not a fresh `handover/2026-08-08-codex` off main. **Rationale:** protocol says commit onto the feature branch that carries the work. **Rejected:** orphan handover branch that drops G0. **Confidence:** high.
- **Decision:** classify 0.7 bump as DEFER. **Rationale:** Shinichi wants more testing first; user instruction “0.7 bump not yet”. **Rejected:** bump in this slice because Q1 said Ada default includes bump. **Confidence:** high.
- **Decision:** do not assume #750/#332/one-slope as the next tests. **Rationale:** explicit 2026-08-08 instruction; Codex re-derives from register. **Rejected:** Ada INCLUDE-if-time table as the programme. **Confidence:** high.

## 4. Checks Run

See `docs/dev-log/check-log.md` 2026-08-08 entry (verbatim). No `R CMD check` (docs/handover only). Shannon: 0 open PRs; no 6-hour shared-file collision.

## 5. Tests of the Tests

N/A — no package tests changed.

## 6. Consistency Audit

```sh
rg -n "0\\.7\\.0|not imminent|keep #949|first portal day|calibrated" \
  docs/dev-log/handover/2026-08-08-codex-handover.md \
  docs/dev-log/plan-actual/2026-08-07-gllvmtmb-cran-0.7-g0.md \
  docs/dev-log/handover/2026-07-25-active-lane-split.md
# morning lock + keep-VA + not-imminent present; no default-flip language

rg -n "Version:" DESCRIPTION
# still 0.6.0

rg -n "list_projects|create_thread" docs/dev-log/handover/2026-08-08-codex-handover.md docs/dev-log/check-log.md
# MCP absence recorded
```

## 7. Roadmap Tick

N/A — `ROADMAP.md` not edited.

## 7a. GitHub Issue Ledger

Inspected, not closed or commented: #332 OPEN, #750 OPEN, #345 OPEN, #949 MERGED, #908 MERGED (historical NOTE). No new issue (Codex proposes the test programme first).

## 8. What Did Not Go Smoothly

- `handoff_gate.sh` enumerates hundreds of historical unpushed local branches in the shared git dir — slow; declared rather than landed.
- Vault `AGENT_LOG.md` already dirty with an unrelated reciprocal-action receipt; morning line kept out of a mixed commit.
- Codex thread MCP tools (`list_projects`, `create_thread`) are not available in this Cursor session.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Ada:** Q1 YES does not imply bump-today when Q2+Q3 say more testing first.  
**Rose:** Multi-lane pointer must stay on the split table; a single CLAUDE.md bullet cannot own CRAN + VA + evidence.  
**Shannon:** Empty open-PR list is healthy; unpushed historical branches are WARN, not this lane’s merge work.  
**Grace:** Live `--as-cran` + `NOT_CRAN=true` is Codex’s first real check, not this docs slice.

## 10. Known Limitations And Next Actions

Codex executes OWED leave-M5, Rose fence, live check, and testing-debt inventory. Shinichi’s remaining gate is approving the proposed INCLUDE + test programme. No upload. No auto-merge.
