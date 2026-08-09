# Phase C provenance receipt — 2026-08-08

## Lane ownership

- Platform: Codex
- Lane: integrated-SDM Phase C
- Branch: `claude/experiment-integrated-sdm`
- Recovered P0 commit: `c8fc3ade770fbb6ce35f4877e4b37a67ab038476`
- Recovered commit pushed before artifact movement: yes
- Open same-subject pull request at takeover: none returned by `gh pr list`
- Live Phase C R process at takeover: none returned by the host process scan
- Main modified: no

Silence from the lane scans is weak evidence, not proof of sole ownership. The
explicit owner for further Phase C mutations is Codex in this worktree.

## C-lite quarantine

C-lite is an unapproved, non-preregistered deviation. The two inherited
untracked artifacts were hashed without execution or statistical parsing and
moved intact from the worktree to:

`/Users/z3437171/local-scratch/quarantine/gllvmtmb-isdm/2026-08-08-phase-c-c-lite-c8fc3ade/`

| Original path | Quarantine path | Bytes | Original mtime | SHA-256 |
|---|---|---:|---|---|
| `dev/isdm-bias-analyse.R` | `isdm-bias-analyse.R` | 9,001 | `2026-08-08T17:19:04-0600` | `26c57e607a49ac233125748bc5137a97cfb8af7f5412d379fea0c1356070e593` |
| `dev/isdm-bias-pilot-lite.rds` | `isdm-bias-pilot-lite.rds` | 14,349 | `2026-08-08T17:17:06-0600` | `98554d10584d3cbfea9d72d56f2656b772c1aafd6a1c6d535e15746e93c13fe9` |

The tracked reduced runner moved from `dev/isdm-bias-run-reduced.R` to
`dev/archive/isdm-c-lite/isdm-bias-run-reduced.R`. Its SHA-256 is
`7df67c1f5bfd2805e9aeca98f94ba0e0adac77ca8d95fd8bf00fbf6b6025b8ae`.

No C-lite code or RDS statistic was opened during reconciliation. C-lite must
not contribute statistical value to Phase C.

## Sealed original pilot

The original remote pilot remains permanently statistically sealed. On Totoro,
its existence, source, size, timestamp, and hashes were reverified without
calling `readRDS()` or otherwise parsing its contents.

- Host: `totoro`
- Remote checkout: `/home/snakagaw/hsq_work/gllvmTMB-isdm`
- Source SHA: `0dbc7ec3a637c50ed7f80f9225c777ee37d20853`
- Results path: `/home/snakagaw/hsq_work/gllvmTMB-isdm/dev/isdm-bias-pilot-results.rds`
- Results bytes: 104,773
- Results mtime: `2026-08-08 17:25:44.321347543 -0600`
- Results SHA-256: `3f729e4d48ac047378065597cda3e7ea616aaafd09e0f01305adb585782736c7`
- Log path: `/home/snakagaw/hsq_work/gllvmTMB-isdm/dev/isdm-bias-pilot.log`
- Log bytes: 448,583
- Log mtime: `2026-08-08 17:25:44.321347543 -0600`
- Log SHA-256: `aeafafbfb23ce143b8b1d69f0b59697eaa2c4b9b3d3a076b688c47087756ebac`

The sealed original pilot is provenance only. It will not be inspected or used
for calibration, seed selection, analysis, or claims.

## Non-overlap rule

Four states remain separate in every later receipt:

1. official historical P0/preflight and paired smoke at `c8fc3ade`;
2. the corrected `pilot_v2` instrument and artifact;
3. quarantined C-lite;
4. the corrected `campaign` G1--G6 artifacts.

Only states 2 and 4 can contribute new Phase C statistics.
