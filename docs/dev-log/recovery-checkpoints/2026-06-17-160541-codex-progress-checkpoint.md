# Codex progress checkpoint -- 2026-06-17 16:05 MDT

## Purpose

Record the post-restart progress on the gllvmTMB + GLLVM.jl twin finish lane
without starting another edit cycle while GitHub Actions is still active.

## Current branch and tree

```sh
git status --short --branch
## codex/r-bridge-grouped-dispersion...origin/codex/r-bridge-grouped-dispersion
?? docs/dev-log/recovery-checkpoints/2026-06-17-050000-codex-handover-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-06-17-151509-codex-stop-checkpoint.md
```

No tracked-file diff was present at checkpoint time.

## Completed in this continuation

- Rehydrated from the 15:15 stop checkpoint and current GitHub state.
- Confirmed `gh` and `Rscript` were present but missing from the restarted
  shell PATH; used absolute paths.
- Merged `origin/main` at `0567cd7` into
  `codex/r-bridge-grouped-dispersion`, resolving the `_pkgdown.yml` conflict by
  keeping #489's broader Julia bridge reference section.
- Ran:

```sh
PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin \
  /Library/Frameworks/R.framework/Resources/bin/Rscript --vanilla \
  -e 'pkgdown::check_pkgdown()'
# No problems found.
```

- Committed and pushed merge commit:

```text
3c5d111 Merge remote-tracking branch 'origin/main' into codex/r-bridge-grouped-dispersion
```

- Waited until the previous #489 recovery check completed before pushing, so no
  useful #489 check was cancelled.
- Main post-#491 evidence:
  - R-CMD-check `27720099917` succeeded on `0567cd7`.
  - pkgdown `27720668325` succeeded on `0567cd7`.
- #489 evidence at `3c5d111`:
  - coevolution recovery `27721260397` succeeded.
  - R-CMD-check `27721260400` was still in progress, stuck in
    `Run r-lib/actions/setup-r-dependencies@v2` at 16:05 MDT.
- Power-pilot dry-run evidence:
  - run `27717007830` completed successfully.
  - persist rebuilt a 48-row `pilot-index.rds`.
  - results branch advanced `ed7a88d..2709930`.
  - new results commit:
    `2709930 power-pilot: accumulate reps (run 107)`.
  - remote store summary from `origin/power-pilot-results`: 48 cells, 10,376
    reps, 0/48 cells at cap, signal mean coverage 0.733, signal pass94 3/32,
    signal pass95 3/32, null mean coverage 0.412.
  - Evidence comment posted on merged PR #490:
    <https://github.com/itchyshin/gllvmTMB/pull/490#issuecomment-4735890567>
- Local LaunchAgent power pilot is running again from
  `/Users/z3437171/gllvmTMB-power-pilot`, with 10 workers active. Latest logged
  summary before this checkpoint: 347,510 / 480,000 reps, 0/48 cells at cap,
  signal mean coverage 0.753, signal pass94 3/24, signal pass95 2/24.

## GLLVM.jl ordering state refreshed

- GLLVM.jl #95: open, non-draft, `CLEAN`, all listed checks green, head
  `65a1f106606137671efce84a7689a33ae22de5d2`.
- GLLVM.jl #101: open, draft, `CLEAN`, targets `integration`, head
  `f7be594e72486ef1bb2f2bde1875e1e6e903b5f9`, Documenter green.
- GLLVM.jl #94: open, draft, `DIRTY`, no current check rollup; still separate
  salvage and not part of the #95 -> #101 -> #489 landing path.

## Important boundaries

- Do not call #489 release-ready. It is still draft and partial.
- Do not call the power-pilot run coverage proof. Run 107 proves persistence
  mechanics, not scientific coverage or power.
- Do not update and push dashboard JSON while #489 R-CMD-check is active,
  because that would restart the PR checks.
- Do not merge GLLVM.jl #95 silently; it is a maintainer-level landing decision
  even though it is clean and green.

## Next safest actions

1. Recheck #489 R-CMD-check run `27721260400`.
2. If it succeeds, update the dashboard/status evidence in one small commit, or
   leave the dashboard off if the maintainer prefers no widget churn.
3. If it fails, inspect logs before editing.
4. If it remains in setup for much longer, treat it as runner delay before
   considering cancellation/rerun; avoid another cancellation cascade.
5. Continue Fisher/Curie scoring only from the accumulated store evidence, not
   from workflow success alone.
