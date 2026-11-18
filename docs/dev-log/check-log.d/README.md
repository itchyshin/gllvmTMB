# check-log.d: per-file check evidence

New check evidence goes here, one file per slice, so that parallel lanes
(Codex worktrees, MSPL lanes, column-slope family work) never edit the same
file and never fight over a shared table.

## Rule

- One file per slice, named `YYYY-MM-DD-<slice>.md`
  (for example `2026-10-19-public-study-supplement.md`).
- Never edit another slice's file.
- Do not append new entries to `../check-log.md`. It remains the historical
  log; new entries live in this directory.

## Required fields

Each file records, in prose or in a small table:

1. **Goal**: what the slice set out to check, with the issue or PR number.
2. **Exact commands**: the commands as run, copy-pasteable, including any
   `devtools::test(filter = ...)` filter or script path.
3. **Pass/fail counts**: for example `FAIL 0 / PASS 33`, or a plain PASS/FAIL
   per command. Say plainly what was not run.
4. **Claim boundary**: what these results do and do not support (for example,
   no change to validation-debt status or public documentation).

## Template

```markdown
# Check-log: <slice name> (#<issue>)

**Goal:** <one sentence>

**Commands:**

    <exact command 1>
    <exact command 2>

**Results:** <pass/fail counts per command>

**Not run:** <what was deliberately skipped>

**Claim boundary:** <what this evidence does not show>
```

Existing shards in this directory also use a four-column table
(`Date | Slice | Command / evidence | Result`); either shape is fine as long as
the four fields above are present.

This is process hygiene, not a capability claim.
