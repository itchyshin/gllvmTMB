# gllvmTMB 0.6 arc-loop checkpoint

**GOAL:** `LOOP/GOAL.md` — read **both** maintainer amendments. (1) EVA is CUT from 0.6 to 0.7;
0.6 is Laplace-only. (2) **CI authorisation RESTORED** (`GOAL.md:159`) — push, Ubuntu, heavy
and the three-OS matrix are approved by the maintainer and the "stop before any push/CI spend"
line is **superseded**. Do not re-ask; do not re-litigate it.

**STATE: M1 IS WITHHELD.** **Five** consecutive D-43 panels, **five** 3/3 NOT-DONE verdicts.

**Branch head: `21e04eb5`** — clean, pushed. **Certified evidence SHA: `21e04eb5`** (this head).

**⚠ A PREVIOUS VERSION OF THIS LINE WAS FALSE.** It read: *"Certified evidence SHA `95f7d06a`
… no source file changed after `95f7d06a`."* True when written; **false the moment `97f5c378`
landed**, which changed **six source files** — `R/methods-gllvmTMB.R`, `R/fit-multi.R`,
`R/profile-route-matrix.R`, `vignettes/gllvmTMB.Rmd`, `tools/check-reader-surface.sh` and a
test (`git diff --stat 95f7d06a 21e04eb5` settles it). Evidence has since been **re-earned at
`21e04eb5`**.

### ✅ HOW TO CHECK WHETHER A CERTIFICATION STILL TRANSFERS — run this, do not trust prose

The certified SHA and the branch head are allowed to differ, **provided no shipped file
changed between them.** Do not take any document's word for that — including this one.
**Re-derive it:**

```sh
git diff --name-only <CERTIFIED_SHA> HEAD -- \
  R/ src/ tests/ man/ vignettes/ tools/ DESCRIPTION NAMESPACE
```

**Empty output ⇒ the certification transfers to HEAD.** Any output ⇒ **it does not**, and the
evidence must be re-earned before any claim rests on it.

This is written as a **rule rather than a result** deliberately: a rule stays true as the head
moves; a recorded conclusion goes stale the moment someone commits — which is precisely the
failure below. Verified by this method at the time of writing: `21e04eb5` → `HEAD` returned
empty (the only later commits touch `LOOP/` and `docs/`, both `.Rbuildignore`d).

**This is the fifth form of one failure: a document accurate at the moment of writing that
silently goes false as the repo moves beneath it.** The same shape produced the stale head
reference, the stale R-9 row, the stale check-log entry, and this. It is **structural, not
carelessness**: any claim naming a SHA or a diff-state is a *snapshot*, and a snapshot must be
**re-verified**, never merely written carefully. **`tools/check-reader-surface.sh` cannot
catch this class** — it checks code shapes on surfaces; it cannot know a document has gone
stale. Re-derive every SHA claim from `git` before repeating it.

---

## 1. THE PATTERN — read this before touching anything

**Not one of five panels found a numerical, algorithmic or statistical defect.** The
engineering has been green throughout. All five found the same failure in the agent:

> **It repairs the instance it was pointed at, not the class it belongs to — then states in a
> commit message that the class is fixed.**

**Twelve instances this arc. THREE of the five panel findings were defects introduced by the
previous panel's own fix.** Two commit messages were false as written.

Worked examples: a false `FAIL 0` from a grep matching a marker the reporter never emits; a
suppression wrapper on one of two return branches while the **default** stayed broken;
`"validated"` corrected on line 1587 and left on line 1588 of the same `cli_abort`; an R-10
register contradiction fixed without checking R-9, which had the identical defect; a
checkpoint warning about stale references that named its own commit's SHA and was stale on
arrival.

**THE COUNTERMEASURE THAT DEMONSTRABLY WORKS: SWEEP THE CLASS, NEVER PATCH THE INSTANCE.**
When the agent finally swept, it found six `cli_abort` messages sending users to
*"consult the validation register"* — a `docs/design/` file `.Rbuildignore` excludes from the
package. **Five panels had missed it.**

**Do not trust this agent's summaries, counts, or commit messages. Re-derive from artifacts.**

---

## 2. 🔴 A RETRACTION THE AGENT MADE AGAINST ITSELF

The agent recorded that the heavy warning set was **"an established invariant, not an
inference"** after four consecutive identical nine-site Ubuntu runs. **The fifth run refuted
it** — run `29896539701` returned **eight** sites, a different set:

- **absent:** `test-matrix-slope-spatial-unique.R:249:3`, `:293:3`
- **present again:** `test-matrix-nbinom2-spatial.R:258:3` — site (d)

Same platform, same epoch, one documentation-and-message-string commit apart. Skip 103 → 102,
pass 13656 → 13650.

**An invariant asserted from n=4, refuted at n=5.** The original claim (the set is *not*
stable) was correct; both later "refinements" were wrong. The contingent sites are
**optimiser-convergence-dependent**, so the set is not a function of the code alone.

**Consequence: an exact set match between ANY two heavy runs cannot establish that an arc
added no warning site — which is what R-7's causation evidence rests on.** No site is a
defect; the evidence standard is.

---

## 3. VERIFICATION STANDARD IN FORCE (each paid for by a failure)

- **Structured results only** — `as.data.frame(<testthat result>)` counts, or the runner's
  `M1_FINAL_RECEIPT_CHECK_*` fields. **A missing or unparseable field is CANNOT VERIFY, never
  PASS.** Never grep reporter prose for failure markers.
- **`test_dir()` ≠ `devtools::test()`.** Measured: `FAILED=2` at `SKIP=1001` versus
  `FAILED=3 + ERROR=1` at the correct `SKIP=779`. **~2,400 tests silently did not run.**
- **A backgrounded launcher's exit 0 is not the job's result.** It fired repeatedly.
- **Never dispatch `R-CMD-check.yaml` while an Ubuntu run is in flight** — the concurrency
  group cancels it. Observed live: run `29896433309` was cancelled exactly this way.

---

## 4. CERTIFIED EVIDENCE — all green at `21e04eb5` (the current head)

```
devtools::test()                 FAILED 0 | ERROR 0 | SKIP 779 | PASS 7290
durable R CMD check --as-cran    0 errors | 0 warnings | 0 notes
CRAN-configuration check         0 errors | 0 warnings | 1 note (New submission)
Ubuntu CI            29903055881 success
three-OS matrix      29904363055 ubuntu + macos + windows — all success (jobs asserted by name)
heavy full-check     29903134856 FAIL 0 | WARN 10 | SKIP 103 | PASS 13656
tools/check-reader-surface.sh    PASS (extended: R/ string literals + vignette links)
```

Receipts + `SHA256SUMS.txt`:
`~/gllvmTMB-0.6-evidence/m1/final-receipt/21e04eb59679d1a92120bc367914a4de948f9afd/`

**This is the FIFTH complete evidence chain of the arc.** The previous four were each
forfeited by a later source change (R-11, then the panel-4, -5 and -6 fixes). Every one of the
five was green on every check — the package has been in working order throughout.

**`WARN 10` is not a regression.** Six Ubuntu heavy runs have returned **WARN 8, 9 and 10** —
the contingent sites are optimiser-convergence-dependent. **Only `FAIL` is a regression signal;
all six runs returned `FAIL 0`.** See R-7's third correction in the register.

**Limits, stated:** the durable runner reports 0 notes only because it omits
`remote`/`incoming` — the `New submission` NOTE is real and appears in the CRAN-configuration
check. `pkgdown::check_pkgdown()` validates configuration and **does not build the site**.

---

## 5. 🔴 OPEN FOR THE MAINTAINER — nothing else blocks

1. **Wording review of the R-11 replacement strings.** The one check the agent cannot
   self-verify. An Opus reviewer already caught **seven overstatements** in its first attempt,
   most seriously `"validated"` on CI rows — `docs/design/75:99` forbids describing a cell as
   calibrated, and `CI-08` records the empirical gate as **FAILED** (13/15 cells below the 94%
   threshold). Current strings include `"direct profile route (not coverage-calibrated)"`,
   `"diagonal grouping tier: no calibrated interval"`, `"no CI (point estimate only)"`,
   `"experimental route: partial validation only"`. **The question is not style — it is
   whether any still claims more than is true.**
2. **A `NEWS.md` boundary statement**, drafted but deliberately not written in (release-level
   claim): *variance-component **point estimates** are the supported claim for non-Gaussian
   families; **interval calibration** is established only for the Gaussian cells that cleared
   the coverage gate.*
3. **Does R-7's SIGN-OFF still stand?** Its causation evidence has now been undermined three
   times, most recently by the agent's own retracted invariant. The row is signed off; its
   basis is weaker than when it was signed.
4. **🛑 DO NOT convene a sixth panel on the agent's judgement alone.** The findings have
   converged on prose accuracy in user-facing text — precisely the judgement the agent is
   demonstrably unreliable at, and three of five findings were self-inflicted. Get the wording
   review first.

---

## 6. Register · scientific thread · traps

**Register:** R-1…R-11 **all closed** (R-2, R-6, R-7 `SIGNED OFF`; rest `RESOLVED`). **No row
blocks the closing claim.** R-9's status was stale through four panels and is corrected; R-7
carries three recorded corrections to its causation evidence.

**Separate scientific thread — NOT an M1 blocker:**
`docs/dev-log/2026-07-22-nongaussian-variance-component-thread.md` — the non-Gaussian
variance-component boundary; why **EVA is probably the wrong lever** (R-2's cause is
information starvation, which a better approximation cannot fix, and VA biases the *opposite*
direction); why **AGHQ is better supported** (drmTMB tracks a `glmer` oracle to four decimals;
this repo already has AGHQ harnesses); and the unexplained **cross-repo sign anomaly** with the
experiment that would settle it — noting `glmer` can only arbitrate a **reduced** cell.

**Traps hit:** backgrounded launcher exit 0 read as the job's result · a grep for a failure
marker the reporter never emits, read as `FAIL 0` · `test_dir()` silently skipping ~2,400
tests · `check_pkgdown()` validating config but **not building the site** · `"the register"`
matching `"the regist**ered** transformation"` · `extract_Gamma()` "**slices**" a matrix ·
`.Rbuildignore` excluding `vignettes/articles`, so `vignette("x")` for any article dangles · a
guard passing on *"see the Random effects article"* because **it cannot know the article does
not exist**.

## TRUTH LIVES IN

Branch `codex/gllvmtmb-060-m1-baseline-20260720` @ **`21e04eb5`** (clean, pushed; certified
evidence at that same head). Draft PR #778. `docs/dev-log/known-residuals-register.md` ·
`docs/dev-log/check-log.md` · `docs/dev-log/after-task/2026-07-21-m1-third-reader-surface-sweep.md`
· `docs/dev-log/2026-07-22-nongaussian-variance-component-thread.md` ·
`~/gllvmTMB-0.6-evidence/m1/`.

## RESUME

```text
Read LOOP/GOAL.md (BOTH amendments — CI IS AUTHORISED) -> LOOP/checkpoint.md ->
docs/dev-log/known-residuals-register.md -> docs/dev-log/check-log.md.

M1 is WITHHELD after FIVE 3/3 NOT-DONE panels. No register row blocks it, no check is
failing, no defect is outstanding. It is withheld because five panels each found something
and the base rate says a sixth would too — NOT because anything specific is known wrong.

Head 21e04eb5 (clean, pushed) AND certified at that same head: suite 0/779/7290, durable
runner 0/0/0, CRAN check 0/0/1, Ubuntu success, three-OS matrix ubuntu+macos+windows success,
heavy FAIL 0 | WARN 10, guard PASS, receipts mirrored with SHA256SUMS.

BEFORE REPEATING ANY SHA CLAIM, RE-DERIVE IT FROM git. A previous version of this file said
"no source changed after 95f7d06a" — true when written, false once 97f5c378 landed six source
files. That failure mode has appeared FIVE times in five forms and no grep can catch it.

WARN counts vary (8, 9, 10 observed across six Ubuntu heavy runs) because the contingent sites
are optimiser-convergence-dependent. ONLY `FAIL` is a regression signal.

DO NOT convene a sixth panel before the maintainer's wording review of the R-11 strings.
SWEEP THE CLASS, NEVER PATCH THE INSTANCE. Verify from structured results only.
Do not trust this agent's commit messages — two were false as written.
```
