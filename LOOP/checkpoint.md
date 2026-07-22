# gllvmTMB 0.6 arc-loop checkpoint

**GOAL:** `LOOP/GOAL.md` — read **both** maintainer amendments: (1) EVA is CUT from 0.6 to
0.7, 0.6 is Laplace-only; (2) **CI authorisation RESTORED** — push, Ubuntu, heavy and the
three-OS matrix are approved, do not re-ask.

**STATE: M1 IS WITHHELD.** **FIVE** consecutive D-43 panels, **five** 3/3 NOT-DONE verdicts.
Head `672f611b`, tree clean, pushed.

---

## THE ONE THING TO UNDERSTAND BEFORE CONTINUING

**Not one of five panels found a numerical, algorithmic, or statistical defect.** The
engineering has been green throughout. Every panel found the *same* failure in the agent:

> **It repairs the instance it was pointed at, not the class it belongs to — then states in a
> commit message that the class is fixed.**

Measured this arc: **ten instances**, and — decisively — **three of the five panel findings
were defects introduced by the previous panel's own fix.**

Concretely: a false `FAIL 0` reported from a grep that matched nothing; a suppression wrapper
applied to one of two return branches while the **default** branch stayed broken; `"validated"`
corrected on line 1587 and left on line 1588 of the same `cli_abort`; an R-10 register
contradiction fixed without checking R-9, which had the identical defect.

**The countermeasure that demonstrably works: SWEEP THE CLASS, NEVER PATCH THE INSTANCE.**
When the agent finally swept rather than patched, it found six `cli_abort` messages telling
users to *"consult the validation register"* — a `docs/design/` file `.Rbuildignore` excludes
from the package. **Five panels had missed it.** Sweeping finds things; patching reintroduces
them.

**Corollary for whoever continues:** do not trust this agent's summaries, counts, or commit
messages. Re-derive from artifacts. Two commit messages in this arc were false as written.

---

## VERIFICATION STANDARD IN FORCE (paid for twice)

- **Structured results only** — `as.data.frame(<testthat result>)` counts, or the runner's
  `M1_FINAL_RECEIPT_CHECK_*` fields. **A missing or unparseable field is CANNOT VERIFY, never
  PASS.** Never grep reporter prose for failure markers.
- **`test_dir()` ≠ `devtools::test()`.** Measured: `test_dir()` gave `FAILED=2` at `SKIP=1001`;
  `devtools::test()` gave `FAILED=3 + ERROR=1` at the correct `SKIP=779`. **~2,400 tests
  silently did not run.** Only the `SKIP=779` profile is evidence.
- **A backgrounded launcher's exit 0 is not the job's result.** It fired repeatedly this arc.

---

## EVIDENCE — all green, but at the SUPERSEDED head `71753ccb`

```
devtools::test()              FAILED 0 | ERROR 0 | SKIP 779 | PASS 7290
durable R CMD check --as-cran 0 errors | 0 warnings | 0 notes
CRAN-configuration check      0 errors | 0 warnings | 1 note (New submission)
Ubuntu CI         29891503417 success
three-OS matrix   29892340756 ubuntu + macos + windows — all success (jobs asserted by name)
heavy full-check  29891513258 FAIL 0 | WARN 9 | SKIP 103 | PASS 13656
check-reader-surface.sh       PASS
```

Receipts + `SHA256SUMS.txt`:
`~/gllvmTMB-0.6-evidence/m1/final-receipt/71753ccbbedd3f0f34c9fb06a58ce6b5ab986d64/`

**`672f611b` (current head) has ONLY the suite re-run** — `FAILED=0 SKIP=779 PASS=7290` — plus
guard PASS. **Its runners, CRAN check and CI are NOT yet earned.** The push has started an
Ubuntu run; the matrix and heavy still need dispatching.

**🔴 RETRACTED — the heavy warning set is NOT stable.** This checkpoint previously called it an
*"established invariant"* after four consecutive identical nine-site Ubuntu runs. **The fifth
run (`29896539701`) returned EIGHT sites, a different set** — `test-matrix-slope-spatial-unique.R:249,:293`
absent, `test-matrix-nbinom2-spatial.R:258` (site (d)) back — on the same platform, one
docs-and-message-string commit apart. Skip 103 → 102, pass 13656 → 13650.

**An invariant asserted from n=4, refuted at n=5.** The contingent sites are
**optimiser-convergence-dependent**, so the set is not a function of the code alone.
**Therefore an exact set match between ANY two heavy runs cannot show that an arc added no
warning site** — which is what R-7's causation evidence rested on. No site is a defect; the
evidence standard was.

---

## 🔴 NEXT — and the agent deliberately STOPPED here

1. **Re-earn evidence at `672f611b`**: durable runners (+ mirror with SHA-256), CRAN-config
   check, wait for Ubuntu, **then** dispatch the three-OS matrix (never during an in-flight
   run — the concurrency group cancels it), and re-dispatch `full-check`.
2. **🛑 A SIXTH PANEL SHOULD NOT BE CONVENED ON THE AGENT'S JUDGEMENT ALONE.** The remaining
   findings have converged on **prose accuracy in user-facing text** — exactly the judgement
   this agent has now demonstrated it is unreliable at. Get the maintainer's wording review
   first; otherwise a sixth panel is likely to find a sixth instance of the same thing.

## 🔴 OPEN FOR THE MAINTAINER

1. **Wording review of the R-11 replacement strings** — the one check the agent cannot
   self-verify. An Opus reviewer already caught **seven overstatements** in its first attempt,
   most seriously `"validated"` on CI rows: `docs/design/75:99` forbids describing a cell as
   calibrated, and `CI-08` records the empirical gate as **FAILED** (13/15 cells below the 94%
   threshold). Current strings include `"direct profile route (not coverage-calibrated)"`,
   `"diagonal grouping tier: no calibrated interval"`, `"no CI (point estimate only)"`,
   `"experimental route: partial validation only"`. **The question is not style — it is
   whether any still claims more than is true.**
2. **A `NEWS.md` boundary statement**, drafted but deliberately not written in (release-level
   claim, maintainer's wording): *variance-component **point estimates** are the supported
   claim for non-Gaussian families; **interval calibration** is established only for the
   Gaussian cells that cleared the coverage gate.*
3. **The four `vignettes/*.png`** are now `.gitignore`d (approved) and no longer block the
   clean-worktree runners. Deleting them is optional tidying.

## Register

R-1…R-11 **all closed**. R-2, R-6, R-7 `SIGNED OFF`; the rest `RESOLVED`. **No row blocks the
closing claim.** R-9's status was stale for four panels and is now corrected; R-7 carries two
recorded corrections to its causation evidence.

## Separate scientific thread — NOT an M1 blocker

`docs/dev-log/2026-07-22-nongaussian-variance-component-thread.md`: the non-Gaussian
variance-component boundary, why **EVA is probably the wrong lever** (R-2's cause is
information starvation, which a better approximation cannot fix, and VA biases the *opposite*
direction), why **AGHQ is better-supported** (drmTMB tracks a `glmer` oracle to four decimals;
this repo already has AGHQ harnesses), and the unexplained **cross-repo sign anomaly** with the
experiment that would settle it — noting `glmer` can only arbitrate a **reduced** cell.

## TRAPS THIS ARC HIT

Backgrounded launcher exit 0 read as the job's result · a grep for a failure marker the
reporter never emits, read as `FAIL 0` · `test_dir()` silently skipping ~2,400 tests ·
`pkgdown::check_pkgdown()` validating config but **not building the site** · `"the register"`
matching `"the regist**ered** transformation"` · `extract_Gamma()` "**slices**" a matrix ·
`.Rbuildignore` excluding `vignettes/articles`, so `vignette("x")` for any article is dangling
· a guard that passes on *"see the Random effects article"* because **it cannot know the
article does not exist**.

## TRUTH LIVES IN

Branch `codex/gllvmtmb-060-m1-baseline-20260720` @ **`672f611b`**, clean, pushed. Draft PR
#778. `docs/dev-log/known-residuals-register.md` · `docs/dev-log/check-log.md` ·
`docs/dev-log/after-task/2026-07-21-m1-third-reader-surface-sweep.md` ·
`docs/dev-log/2026-07-22-nongaussian-variance-component-thread.md` ·
`~/gllvmTMB-0.6-evidence/m1/`.

## RESUME

```text
Read LOOP/GOAL.md (BOTH amendments) -> LOOP/checkpoint.md ->
docs/dev-log/known-residuals-register.md -> docs/dev-log/check-log.md.

M1 is WITHHELD after FIVE 3/3 NOT-DONE panels. No register row blocks it; the engineering is
green; every panel finding was about whether the package's own words are true.

Head 672f611b, clean, pushed. Suite FAILED=0 SKIP=779 PASS=7290, guard PASS. Runners, CRAN
check and CI are NOT yet earned at this head — re-earn them (Ubuntu first, THEN the matrix).

DO NOT convene a sixth panel before the maintainer's wording review of the R-11 replacement
strings. The remaining findings are prose-accuracy judgements the agent is demonstrably
unreliable at, and three of five panel findings were defects introduced by the previous fix.

SWEEP THE CLASS, NEVER PATCH THE INSTANCE. Verify from structured results only; a missing
field is CANNOT VERIFY, never PASS. Do not trust this agent's commit messages — two were
false as written.
```
