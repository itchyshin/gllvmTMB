# After-task — KF2021 triad footnote + handover §4 align (post-#1102)

**Date:** 2026-08-17
**Lane:** `cursor/mspl-kf2021-footnote-post-1102`
**Scope:** Docs only. Lands residual unique value from conflicting #1101 / closed #1096 after #1102 REPLACE merge.

## Outcome

- MSPL/KF2021 footnote on triad card (profiling ≠ coverage rescue under finiteness penalty; binomial-only).
- Caveat note marks footnote landed.
- Cursor handover §4 UNSIGNED → **SIGNED — REPLACE**.
- Codex REPLACE handover stub now carries the build contract (was a redirect to a missing file).

## Checks

```sh
rg -n 'MSPL footnote|SIGNED — REPLACE' docs/dev-log/research/2026-08-17-mspl-ci-wald-plus-profile.md
rg -n 'footnote is landed' docs/dev-log/research/2026-08-17-kosmidis-firth-2021-profile-caveat.md
rg -n 'SIGNED — REPLACE' docs/dev-log/handover/2026-08-17-cursor-handover-mspl-se-ci.md
git diff --check
# deliberately not: src/, undraft #1077, public se, Design 118
```

## Follow-up

- Close #1101 as residual-landed.
- Codex takes tape PR from handover; Cursor does not edit `src/`.
