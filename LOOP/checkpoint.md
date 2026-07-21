# gllvmTMB 0.6 arc-loop checkpoint

**GOAL:** `LOOP/GOAL.md` — read its **2026-07-21 MAINTAINER AMENDMENT** first: EVA is
CUT from 0.6 to 0.7; 0.6 is Laplace-only.

**STATE: M1 IS WITHHELD.** Two consecutive D-43 completion panels returned **3/3 NOT-DONE**.
All nine of the second panel's must-fixes are applied, the defect class is now enforced
mechanically by `tools/check-reader-surface.sh`, R-7 is diagnosed, and the
CRAN-configuration check is recorded. **M1 has not closed and must not be claimed closed.**

## SESSION GOAL (2026-07-21, set with the maintainer)

Close M1 — **or withhold it a third time, honestly** — and hand M3 a clean start.
"Finish M1, no compromise" is the standing instruction; a third withhold with a named
cause is a legitimate outcome of this goal, not a failure of it.

## Why M1 was withheld (twice)

Both panels withheld on **documentary** defects, never engineering. Green CI across three
operating systems passed a document that contradicted itself — twice. The repair method
itself was the recurring fault: **repair what was noticed, then assert completeness.** The
second attempt introduced a fresh instance of the very defect it was fixing, and asserted a
false fact (`origin/main` "carried zero register codes") derived from grepping one file,
then propagated it into three durable records.

`tools/check-reader-surface.sh` now enforces the property mechanically. **It cannot tell
whether the prose that replaced the codes is true** — which is exactly how a true statement
became a false one. A third panel can still withhold there.

## Where the evidence stands

| Item | State |
|---|---|
| Reader-surface guard | **PASS** on the current head |
| Complete non-heavy suite | `FAIL 0 \| WARN 0 \| SKIP 779 \| PASS 7287` |
| CRAN-configuration check | **0 errors / 0 warnings / 1 note** (`New submission`, expected) — recorded at `ce2fb177` |
| Durable runners | **NOT RUN** on the final head |
| CI cycle | **NOT RUN** on the final head |
| Third D-43 panel | **NOT RUN** |

## NEXT — in this order

1. **R-7 site (d).** `test-matrix-nbinom2-spatial.R:258` is the ONE of eight sites still
   untraced. Heavy run in flight; log at
   `~/gllvmTMB-0.6-evidence/m1/diagnostics/r7-site-d-trace.log`. Land the result in R-7.
2. **Freeze the final SHA.** Every commit must land before the runners; a later commit
   supersedes the receipts, which is how `25c76789` was lost.
3. **Durable runners** from `~/gllvmTMB-0.6-evidence/m1/final-receipt/runners/` (verify
   hashes first). **Mirror RDS + log into `.../final-receipt/<sha>/` with `SHA256SUMS.txt`.**
   Do not leave them in `/private/tmp` and call them durable.
4. **Push, then CI.** **AUTHORISED — do not re-ask.** Do NOT dispatch `R-CMD-check.yaml`
   while an Ubuntu run is in progress: the concurrency group is `workflow-ref` with
   `cancel-in-progress` true off main, so a dispatch **cancels the running Ubuntu job and
   destroys that receipt.** Wait for Ubuntu, then dispatch with `-f full_matrix=true`.
   `full-check.yaml` is a separate workflow and may be dispatched immediately.
   **Assert three OS-named jobs** — a silent degradation to Ubuntu-only also goes green.
5. **Third D-43 panel.** 2 Sonnet + 1 Opus, fresh contexts, NOT-DONE default, whole estate.
   Give it both prior verdicts and require it to **verify the repairs hold**, not accept a
   summary.

## OPEN GATES (need the maintainer)

- **R-7 AWAITING SIGN-OFF.** ⚠️ **This blocks M1's closing claim by the register's own rule,
  independently of the panel verdict.** Even a 3/3 DONE panel cannot close M1 while R-7 is
  unsigned. Seven of eight sites are traced and none of those seven is a defect; site (d) is
  in flight. Do not describe R-7 as "diagnosed" until (d) lands.
- M3 source/API freeze **+ the `0.5.0 → 0.6.0` version bump, which invalidates every
  exact-SHA receipt** — M5 must budget its own platform cycle.
- M4 **page decisions** — the maintainer's own hours, and the real critical path for 0.6,
  not compute.
- M4 candidate freeze · M5 RC tag · M5 final tag · CRAN submission.

## TRAPS THIS ARC ACTUALLY HIT

pkgdown reported **exit 0 while artifacts were absent** (destination is `pkgdown-site`, not
`docs/`) · a focused run reported **`FAIL 0` while the assertion under test was skipped**
behind `skip_if_not_heavy()`, which fails **open** · `expect_warning()` in testthat 3e
returns the **caught condition**, not the value · `R CMD check` fails its tests step only on
**error**, so testthat warnings and skips hide behind `Status: OK` · a green CI conclusion is
not 0/0/0 · **a negative grep over one file is not a property of all files** · **fixing the
parameter you are looking at is not fixing the page** · an apparent false `#750 SHIPPED`
claim was **true on its own branch** · **readable-but-false is worse than opaque-but-true.**

**Read the log, open the artifact, check which branch you are reading.**

## TRUTH LIVES IN

Branch `codex/gllvmtmb-060-m1-baseline-20260720` @ `ce2fb177` (tree clean, **2 commits
unpushed**), draft PR #778, this `LOOP/` kit, `docs/dev-log/known-residuals-register.md`,
`docs/dev-log/check-log.md`, `docs/dev-log/2026-07-21-eva-cut-to-0.7.md`, and the mirrored
receipts under `~/gllvmTMB-0.6-evidence/`.

## RESUME

```text
Read LOOP/GOAL.md (incl. the 2026-07-21 amendment) -> LOOP/checkpoint.md ->
LOOP/decision-queue.md -> docs/dev-log/known-residuals-register.md ->
docs/dev-log/handover/2026-07-21-claude-handover-m1-withheld-twice.md.
M1 is WITHHELD after two 3/3 NOT-DONE panels. Nine must-fixes are applied, the defect class
is machine-enforced, the CRAN check is recorded at ce2fb177, and the tree is clean.
Resume at R-7 site (d), then freeze the SHA, then durable runners (mirror with SHA-256 into
~/gllvmTMB-0.6-evidence/), then push + full CI (ALREADY AUTHORISED — do not re-ask), then a
THIRD D-43 panel. Do not commit after the runners produce receipts — that invalidates them.
M1 cannot close while R-7 is AWAITING SIGN-OFF, whatever the panel says.
```
