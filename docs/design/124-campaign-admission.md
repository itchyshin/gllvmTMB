# Design 124 — compute-admission slice for claim-bearing capstone campaigns

**Status: BUILT, opt-in tooling, not itself a campaign authorisation.** This
is the compute-admission slice Design 66's D-50 supersession requires
before any 48-cell pilot, claim-bearing fit campaign, or production DRAC
array is admitted. Building this slice does not launch, schedule, or
authorise any campaign; it is the gate that a future campaign must pass
through. Lane: `claude/design66-scoping-20260816`, worktree
`/private/tmp/gllvmtmb-doc-lane-20260816`.

## 0. What this slice satisfies

Design 66 (`docs/design/66-capstone-power-study.md`, lines 11-18) states:

> **2026-07-20 D-50 execution supersession:** deterministic local
> diagnostics and bounded non-claim local/Totoro smoke may exercise the
> existing primitives. No 48-cell pilot, claim-bearing fit campaign, or
> production DRAC array is admitted until a separate compute-admission
> slice freezes and validates source/archive/runner checksums,
> campaign/task identity, immutable destinations, retry policy, and result
> schema, followed by explicit maintainer approval.

and (lines 43-45):

> The first compute step after that audit is an immutable-chunk smoke
> ladder, not the full `n_sim = 2000` grid.

This document and the `dev/campaign-admission/` tooling it describes are
that slice. It is deliberately campaign-agnostic — it does not know about
Design 66's specific grid, families, or estimands, and it is built to admit
any future campaign (the capstone, or a smaller one like Design 121's
Cox-Reid slice) that supplies a runner script and a pinned source tree.

## 1. What `admit.sh` does

`dev/campaign-admission/admit.sh --campaign <name> --script <runner.R>
--src <package-source-dir>` runs the following checks, in order, refusing
loudly (exit 2, message on stderr) at the first failure:

1. **Pinned commit + `R/`/`src/` cleanliness.** Records `git rev-parse
   HEAD` of `--src` and refuses if `git status --porcelain -- R/ src/` is
   non-empty. Only `R/` and `src/` are checked (not the whole tree) so
   in-flight `dev/`, `docs/`, or `vignettes/` work in the same checkout
   does not block an admission that only cares about the package's
   compiled behaviour.
2. **Campaign identity.** `campaign_id = <name>-<UTC date>-<short commit>`
   — deterministic, human-legible, and distinct per commit and per day, so
   two admissions of the same named campaign against different commits (or
   the same commit on different days) do not collide.
3. **Checksummed, frozen source archive and runner script.** `sha256` of
   the runner script, and `sha256` of a `git archive` of
   `DESCRIPTION`/`NAMESPACE`/`R`/`src` at the pinned commit (only the paths
   that exist are archived; `git archive` reads from the committed tree,
   so a dirty or untracked file can never leak into the frozen source even
   if the cleanliness check above were somehow bypassed). Both the runner
   script and the archive are **copied**, not just hashed, into the
   admitted destination — the checksum is verifiable later without trusting
   that the original `--script`/`--src` paths were not touched afterwards.
4. **Immutable destination.** The destination convention is
   `~/gllvm_work/campaigns/<campaign-id>/` (overridable via
   `CAMPAIGN_ADMISSION_DEST_ROOT`, used by `--self-test` and by any dry-run
   admission so neither touches the real campaigns directory). Admission
   refuses if this directory already exists and is non-empty — a rerun of
   the same campaign against the same commit on the same day must get a
   new campaign id (typically by widening `--campaign`), not overwrite the
   prior admission's manifest or archive. Chunk files written by the
   campaign's own runner are expected as `chunk-NNN.csv` inside this
   directory and are likewise never-overwritten by convention, though
   `admit.sh` itself only creates the directory and the three admission
   artefacts (`MANIFEST.txt`, `runner.R`, `source-<commit>.tar.gz`) — chunk
   discipline is the runner's responsibility, stated in
   `RESULT-SCHEMA.md`.
5. **SMOKE/CANARY mode contract.** Refuses if the runner script does not
   contain (case-insensitive) both `smoke` and `canary` — the minimal
   textual proof that the runner supports the two lower rungs of the
   ladder (`smoke-ladder.md`) before it is ever pointed at a real cluster.
   This is a grep, not a static analyser: it verifies the contract is
   *declared*, not that it is implemented correctly (see section 3).
6. **Verdict + launch commands.** On success, prints `ADMITTED:
   <campaign-id>`, the manifest/runner/archive paths and checksums, and
   the shape of the three smoke-ladder commands (`smoke-ladder.md` has the
   full PASS criteria per rung).

`--self-test` exercises all of the above against a disposable fixture git
repo under `mktemp`, including every refusal path (dirty tree, duplicate
destination, missing mode contract, missing required argument) and a
checksum-integrity check that the frozen runner copy matches the original
byte-for-byte. It never touches `$HOME/gllvm_work`.

## 2. Result schema and smoke ladder, by reference

The result-row contract every admitted campaign's runner must emit — identity
columns, outcome columns, the mandatory error-as-row rule, the
three-denominator reporting convention, and the no-automatic-retries policy
— is `dev/campaign-admission/RESULT-SCHEMA.md`. It is written from the
columns the Design 121 A+B campaign (`dev/coxreid-ab/run-ab.R`) and its
pre-run harness converged to, generalised rather than copied.

The immutable-chunk smoke ladder — local 1-fit, Totoro canary (1 seed x all
cell-arms), one bounded full chunk (one cell, all seeds), and only then the
full campaign pending an explicit D-139 maintainer go — is
`dev/campaign-admission/smoke-ladder.md`, with PASS criteria stated per
rung.

## 3. What this slice does NOT do

- **No scheduling or execution.** `admit.sh` never launches a fit, never
  touches Totoro or DRAC, and never runs R. It only freezes what a future
  launch would use. Actually running the smoke ladder still requires a
  campaign-specific launcher in the shape of `dev/coxreid-ab/launch-ab.sh`
  (dry-run default, explicit confirm env var, hostname check, worker cap,
  `GITHUB_ACTIONS` unset) — this slice does not build that launcher
  generically, because the launch mechanics (mirai vs. SLURM array,
  worker count, which arms exist) are inherently campaign-specific.
- **No DRAC array driver.** Design 66 (line 52) notes "the repository has
  smoke-only Slurm plumbing, not an admitted production DRAC array
  harness; that driver must still be built, reviewed, and frozen." This
  slice does not build it. If DRAC (rather than Totoro) is chosen for the
  capstone's full grid, a SLURM job-array driver — one seed per
  `$SLURM_ARRAY_TASK_ID`, per the operating doctrine's job-array guidance —
  is a separate, later build that would consume this slice's admission
  manifest as its starting point, not replace it.
- **No validation of DGP, formula, or scientific content.** `admit.sh`'s
  SMOKE/CANARY check is a textual contract check, not a review of whether
  the runner's data-generating process, formula, or estimand extraction is
  correct. That review still belongs to the maintainer sign-off Design 66
  requires, and to the smoke ladder's rung-by-rung inspection (which is
  manual, by design — "inspect the output file by hand, do not just check
  the exit code").
- **No campaign approval.** `ADMITTED` from `admit.sh` means "this source,
  runner, and destination are frozen and internally consistent." It is not
  the maintainer's D-139 go to run the full grid — that approval still
  happens after rung 3 of the smoke ladder, informed by its extrapolated
  compute-time estimate.

## 4. Worked example — admitting a hypothetical `design122-pilot` campaign

(Illustrative; no such campaign is launched by this document. `design122`
is Design 66's neighbour, the VA-vs-Laplace recovery study named as the
recommended next arc in `CLAUDE.md`'s 2026-08-02 snapshot — used here only
as a plausible campaign name, not as an endorsement of running it now.)

Given a hypothetical runner `dev/design122-pilot/run-pilot.R` that declares
`GRID_SMOKE` and `PILOT_MODE=canary|full` in its header comment, and a
clean gllvmTMB checkout at commit `abcd123`:

```
dev/campaign-admission/admit.sh \
  --campaign design122-pilot \
  --script dev/design122-pilot/run-pilot.R \
  --src /path/to/gllvmTMB
```

would (if `R/` and `src/` are clean, and the destination does not already
exist) print:

```
ADMITTED: design122-pilot-20260817-abcd123
  manifest:   ~/gllvm_work/campaigns/design122-pilot-20260817-abcd123/MANIFEST.txt
  runner:     .../runner.R  (sha256 <...>)
  source:     .../source-abcd123.tar.gz  (sha256 <...>)

Smoke ladder (see dev/campaign-admission/smoke-ladder.md for PASS criteria):
  rung 1 (local, 1 fit): ...
  rung 2 (Totoro canary, 1 seed x all cell-arms), inspected for non-empty/finite: ...
  rung 3 (one bounded full chunk -- one cell, all seeds): ...
  full campaign only after rung 3 PASS + maintainer D-139 go.
```

`MANIFEST.txt` would record the campaign id, the pinned full and short
commit SHA, the `R/`/`src/` cleanliness confirmation, both checksums, the
frozen-copy paths, the destination, and the retry policy statement — the
full set Design 66 names: campaign/task identity, source/archive/runner
checksums, immutable destination, and retry policy. Result schema is the
fifth named requirement and is satisfied by `RESULT-SCHEMA.md`, which the
pilot runner would need to conform to (not something `admit.sh` can verify
by grep beyond the mode-contract check in section 1 step 5).

A second invocation with the same `--campaign design122-pilot` against the
same commit on the same day would refuse: `destination already exists and
is non-empty` — the retry policy in `RESULT-SCHEMA.md` requires a new
campaign id for a rerun, not a silent overwrite.

## 5. Honest gaps

- The SMOKE/CANARY contract check is textual, not behavioural — a runner
  could declare the tokens without actually truncating its task list on
  smoke mode. Nothing in this slice executes the runner to confirm the
  contract is honoured; rung 1 of the smoke ladder is where that gets
  checked by a human, not by `admit.sh`.
- `admit.sh` checks `R/` and `src/` cleanliness, not the whole repository.
  A dirty `dev/` file that the runner actually depends on (e.g. a shared
  helper sourced from `dev/`) would not be caught. Runners intended for
  admission should be self-contained (see `RESULT-SCHEMA.md`'s
  error-as-row section and the `run_row()` self-containment discipline it
  cites from `dev/coxreid-ab/run-ab.R`), which is the mitigation, not a
  wider dirty-tree check this slice adds.
- No DRAC-side admission analogue exists yet (see section 3). If the
  capstone's full grid runs on DRAC rather than Totoro, the SLURM
  array driver is unbuilt and this slice does not attempt to anticipate
  its shape.
