# New lane: reconcile the completion-arc branch into `main` (2026-07-05)

You are a fresh Claude session with **one focused job**: merge
`codex/r-bridge-grouped-dispersion` into `main`. Shinichi authorized the merge;
it turned out NOT to be a fast-forward, so it needs a careful reconciliation.
Work from repo files, clean context. This env runs live R/TMB.

## The situation (why this is a real task, not a fast-forward)

- **Work branch** `codex/r-bridge-grouped-dispersion` @ `aa0b3f96` — pushed; carries
  the whole completion-arc session (the 99-conflict fold-arc merge + M1–M5 audits +
  delta resolution + `interval_status` marker + D-28 principle). **294 commits ahead
  of main.**
- **`origin/main` @ `8c5f73b0`** advanced **139 commits** since the branch last synced
  (merge-base `1e85f091`, 2026-06-22): active PRs — twin-review fixes, robustness/clean-file
  guards, family-label & mesh fixes, meta/pedigree PD fixes, dead-code cleanup, **and more
  `codex/unique-latent-psi-fold` work (PR #706)**. So both sides moved. This is the
  branch-drift pattern (see `~/.claude/memory/memory_summary.md` + LESSONS): the branch
  should have integrated main sooner.
- **Dry-run merge = 43 conflicts** across: 17 vignettes, 10 `R/` (`brms-sugar.R`,
  `extract-sigma.R`, `fit-multi.R`, `julia-bridge.R`, `profile-derived.R`,
  `bootstrap-sigma.R`, `methods-gllvmTMB.R`, `gllvmTMB-wide.R`, `init-warmstart.R`,
  `profile-derived-curves.R`), `src/gllvmTMB.cpp`, `NEWS.md`, `ROADMAP.md`, `_pkgdown.yml`,
  7 design docs (`01/03/04/35/61/65`), `docs/dev-log/check-log.md`, 4 `man/`, 1 test.

## Strategy (mirror the successful fold-arc merge from this session)

1. **Isolated worktree**, do NOT touch `main` or the live branch until green:
   `git worktree add ../gllvmTMB-mergewt2 codex/r-bridge-grouped-dispersion`
2. In it: `git merge origin/main` → resolve the 43. **Union-merge**, don't blanket
   take-one-side:
   - **PRESERVE this branch's session deliverables** (re-layer if a side is taken):
     the `interval_status` marker in `R/extract-correlations.R`; the guards in
     `R/brms-sugar.R` (source-`lv=` abort, spatial `trait`-anchor, phylo mode-dispatch
     exemption, dup-slope, positional control args); the delta resolution + D-28
     principle in `docs/design/02-family-registry.md`; MIX-10=partial in `35-*`; the
     `57-*` banner; `NEWS.md` marker entry; the delta vignette wording
     (mixed-family-extractors, response-families); the 2026-07-05 dev-log/after-task notes.
   - **TAKE main's 139 commits' fixes** (twin-review, robustness guards, family-label/mesh,
     meta/pedigree PD, dead-code, bootstrap robustness) — they are newer than the branch.
   - **⚠️ WATCH for duplicated fold work**: main's PR #706 (`unique-latent-psi-fold`) may
     overlap the branch's fold work. Check for the branch having re-done what main already
     has (the exact branch-drift trap). Prefer main's landed version; keep only the branch's
     genuinely-new session additions on top.
3. **Verify before `main`:** `NOT_CRAN=true` full suite (target PASS ~4165+/0),
   then `_R_CHECK_FORCE_SUGGESTS_=false` `rcmdcheck(args=c("--no-manual","--no-build-vignettes"))`
   → 0 errors. Grep the artifact for leftover conflict markers (`<<<<<<<`).
4. **Show Shinichi the verified-green result BEFORE merging to main.** Then merge the
   reconciled branch → main (his final nod), push main.

## Gotchas (do NOT repeat — from this session)

- `isTRUE(fit$sdr$pdHess)` is `FALSE` on default fits (`fit$sdr` is `NULL`) — not a signal.
- Do NOT hand one subagent a broad multi-file conflict set — it hallucinates an orchestrator
  role. Scope ≤~5 files per edit-subagent; forbid spawning; verify by grepping the artifact.
- Do NOT zero the non-Gaussian between-unit Ψ (identifiable).
- Hard guards: **no push to main / no PR-to-main merge without Shinichi's explicit nod** on
  the verified-green tree; no mixed-family CI claims; no pdHess as CI evidence.

## Resume command

```
claude "Rehydrate from docs/dev-log/handover/2026-07-05-merge-to-main-reconciliation-brief.md + the AGENTS.md snapshot, spawn Rose, then do the isolated-worktree reconciliation of codex/r-bridge-grouped-dispersion with origin/main (43 conflicts), get the suite + R CMD check green, and show me before anything lands on main. This env runs live R/TMB."
```

Companion context: [session closure](../after-task/2026-07-05-completion-arc-session-closure.md),
[the completion-arc handover](2026-07-05-claude-handover.md) (last section),
[Codex handoff](2026-07-05-codex-handoff-completion-arc.md) (the pdHess retraction).
