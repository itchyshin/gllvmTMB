# gllvmTMB 0.6 arc-loop checkpoint

**GOAL:** `LOOP/GOAL.md` — read **all THREE** maintainer amendments. (1) EVA is CUT from 0.6 to
0.7; 0.6 is Laplace-only. (2) **CI authorisation RESTORED** (`GOAL.md:159`) — push, Ubuntu, heavy
and the three-OS matrix are approved and the "stop before any push/CI spend" line is
**superseded**. Do not re-ask; do not re-litigate it. (3) **2026-07-22 — a parallel Design 86
lane is authorised**, design-only, fenced to `docs/design/86-*.md`, in a worktree outside
Dropbox. **It does NOT gate 0.6 and does NOT reverse Amendment 1** — 0.6 still ships
Laplace-only and M2 stays CUT. Brief: `docs/dev-log/2026-07-22-design86-lane-brief.md`.

> ⚠ **A source outside this repo still carries the revoked line.** The ultra-plan Rev 3 `🎯 GOAL`
> block (and its `MD-5`) reads *"stop before any push/CI spend"*. Amendment 2 exists specifically to
> revoke it, having established that it makes M1 **unclosable by construction** — M1's definition of
> done needs exact-SHA three-OS evidence, which only CI produces. **If a future session is handed that
> block, it must not paste it over `GOAL.md`.**

**STATE: M1 IS WITHHELD.** **SIX** consecutive D-43 panels, **six** 3/3 NOT-DONE verdicts.

---

## 0. VERIFIED GIT GROUND TRUTH (re-derived 2026-07-22, not inherited)

```
branch                     codex/gllvmtmb-060-m1-baseline-20260720
HEAD                       d74a6a08   (d74a6a0814862e92b2b0bdb0bf93d86d031c0632)
working tree               CLEAN  (git status --porcelain = empty)
vs origin                  0  0    (rev-list --left-right --count — fully in sync, pushed)
certified evidence SHA     21e04eb5
certification transfers?   YES — shipped-path diff 21e04eb5..HEAD is EMPTY
```

The four commits since the certified SHA touch **only** `LOOP/checkpoint.md` and three
`docs/dev-log/` files — **zero shipped paths**:

```
d74a6a08 docs: correct the non-Gaussian thread — our sign claim is UNVERIFIED
e65030b3 docs(handover): Claude -> Claude handoff — M1 withheld after six panels
eea9761c docs(loop): record the certification-transfer CHECK as a rule, not a result
821c5ced docs: re-certify at 21e04eb5, correct a false SHA claim, confirm WARN variability
```

### ✅ HOW TO CHECK WHETHER A CERTIFICATION STILL TRANSFERS — run this, do not trust prose

The certified SHA and the branch head may differ, **provided no shipped file changed between them.**
Do not take any document's word for that — **including this one.** Re-derive it, **from inside the
worktree** (running it from `~` fails with *"Not a git repository"*, which is an operator error, not
a result):

```sh
cd /private/tmp/gllvmtmb-060-m1-builder
git diff --name-only 21e04eb5 HEAD -- \
  R/ src/ tests/ man/ vignettes/ tools/ DESCRIPTION NAMESPACE
```

**Empty output ⇒ the certification transfers to HEAD.** Any output ⇒ **it does not**, and the
evidence must be re-earned before any claim rests on it.

**Written as a rule rather than a result deliberately.** A rule stays true as the head moves; a
recorded conclusion goes stale the moment someone commits. **The previous version of this file was
itself stale on both counts** — it claimed head `21e04eb5` and *five* panels. So did the six-panel
handover, which named `eea9761c` (two commits back) as head. **This is the sixth appearance of one
failure: a document accurate when written that silently goes false as the repo moves.** It is
structural, not carelessness — `tools/check-reader-surface.sh` **cannot** catch this class, because it
checks code shapes on surfaces and cannot know a document has gone stale.

---

## 1. 🔴 THE FINDING THAT CHANGES THE PATH — D-74 (needs Shinichi's confirmation)

A brain query (`memory/DECISIONS.md`, read directly — the basic-memory MCP layer was down) surfaced a
decision that **bears directly on the six-panel loop and appears not to have been applied here**:

> **D-74 (2026-07-21, accepted).** *"D-43 runs **once per actual milestone claim**, after candidate
> evidence is ready — not per commit, receipt, or repair… Melissa records **gratuitous repeat panels
> as drift**."*

**D-74's own evidence is this lane**: *"86 observed child sessions, **81 from one long gllvmTMB
parent**, including 31 Sol children."* It was written on 2026-07-21 from this arc's telemetry.

**And D-43's remedy clause has been misread.** Its text is:

> *"If ≥2 return 'not done', the claim is **WITHHELD until the uncovered cells are named
> explicitly**."*

Withheld until the cells are **named** — not until a panel votes DONE. **D-46** records the designed
shape from the first real panel: 3 NOT-DONE → repair → **the same three reviewers re-ran and voted 3
DONE**. One cycle with a re-vote, not six fresh panels.

**Consequence, if Shinichi confirms:** the uncovered cells *are* named exhaustively — R-1…R-11 plus
each handover's "does NOT cover" section — so D-43's remedy is **already satisfied**, and M1 should
close by stating the claim in D-43's required form (cite the tier, name the uncovered cells) rather
than by running a seventh panel. **Do not act on this alone — it is an agent reading of a decision,
and this agent's readings have been wrong before. Get Shinichi's confirmation.**

---

## 2. THE PATTERN — read before touching anything

**Not one of six panels found a numerical, algorithmic or statistical defect.** The engineering has
been green throughout. All six found the same failure in the agent:

> **It repairs the instance it was pointed at, not the class it belongs to — then states in a commit
> message that the class is fixed.**

**Twelve instances this arc. THREE of the six panel findings were defects introduced by the previous
panel's own fix. THREE commit messages were false or damaged.**

Worked examples: a false `FAIL 0` from a grep matching a marker the reporter never emits; a
suppression wrapper on one of two return branches while the **default** stayed broken; `"validated"`
corrected on line 1587 and left on line 1588 of the same `cli_abort`; an R-10 register contradiction
fixed without checking R-9, which had the identical defect; an "invariant" asserted from n=4 and
refuted at n=5; a checkpoint warning about stale references that named its own commit's SHA.

**THE COUNTERMEASURE THAT DEMONSTRABLY WORKS: SWEEP THE CLASS, NEVER PATCH THE INSTANCE.** When the
agent finally swept, it found six `cli_abort` messages sending users to *"consult the validation
register"* — a `docs/design/` file `.Rbuildignore` excludes. **Five panels had missed it.**

**The real class is two-dimensional: SURFACES × CODE SHAPES.** Sweeping known shapes on already-scanned
surfaces was itself instance-thinking, one level up.

**Do not trust this agent's summaries, counts, or commit messages. Re-derive from artifacts.**

---

## 3. VERIFICATION STANDARD IN FORCE (each paid for by a failure)

- **Structured results only** — `as.data.frame(<testthat result>)` counts, or the runner's
  `M1_FINAL_RECEIPT_CHECK_*` fields. **A missing or unparseable field is CANNOT VERIFY, never PASS.**
  Never grep reporter prose for failure markers.
- **`test_dir()` ≠ `devtools::test()`.** Measured: `FAILED=2` at `SKIP=1001` versus
  `FAILED=3 + ERROR=1` at the correct `SKIP=779`. **~2,400 tests silently did not run.**
- **A backgrounded launcher's exit 0 is not the job's result.**
- **Write commit messages to a FILE and use `git commit -F`.** Every `-m` message containing backticks
  was mangled by shell command substitution; every `-F` one is intact.
- **Never dispatch `R-CMD-check.yaml` while an Ubuntu run is in flight** — the concurrency group
  cancels it. Observed live twice.
- **`WARN n` from a heavy run is NOT a regression signal. Only `FAIL` is.**

---

## 4. CERTIFIED EVIDENCE — green at `21e04eb5`, and it TRANSFERS to head `d74a6a08`

```
devtools::test()                 FAILED 0 | ERROR 0 | SKIP 779 | PASS 7290
durable R CMD check --as-cran    0 errors | 0 warnings | 0 notes
CRAN-configuration check         0 errors | 0 warnings | 1 note (New submission)
Ubuntu CI            29903055881 success
three-OS matrix      29904363055 ubuntu + macos + windows — all success (asserted by name)
heavy full-check     29903134856 FAIL 0 | WARN 10 | SKIP 103 | PASS 13656
tools/check-reader-surface.sh    PASS (extended: R/ string literals + vignette links)
```

Receipts + `SHA256SUMS.txt`:
`~/gllvmTMB-0.6-evidence/m1/final-receipt/21e04eb59679d1a92120bc367914a4de948f9afd/`

**This is the SIXTH complete evidence chain of the arc.** The previous five were each forfeited by a
later source change. Every one was green on every check — the package has been in working order
throughout.

**`WARN 10` is not a regression.** Six Ubuntu heavy runs returned **WARN 8, 9 and 10** from
functionally identical code; the contingent sites are optimiser-convergence-dependent. All six
returned `FAIL 0`.

**Limits, stated:** the durable runner reports 0 notes only because it omits `remote`/`incoming` — the
`New submission` NOTE is real and appears in the CRAN-configuration check. `pkgdown::check_pkgdown()`
validates configuration and **does not build the site**.

---

## 5. 🔴 OPEN FOR THE MAINTAINER — nothing else blocks

1. **Wording review of the R-11 replacement strings.** *The one property no check can establish.* An
   Opus reviewer caught **seven overstatements** in the first attempt — worst was `"validated"` on CI
   rows, which `docs/design/75:99` forbids and which `CI-08` records as a **FAILED** gate (13/15 cells
   below 94%; independently corroborated by brain **D-42**, which notes only Gaussian d=1/d=3 cleared).
   Current strings include `"direct profile route (not coverage-calibrated)"`, `"diagonal grouping
   tier: no calibrated interval"`, `"no CI (point estimate only)"`, `"experimental route: partial
   validation only"`. **The question is not style — it is whether any still claims more than is true.**
2. **`NEWS.md` boundary statement** — drafted, deliberately NOT written in (release-level claim):
   *variance-component **point estimates** are the supported claim for non-Gaussian families;
   **interval calibration** is established only for the Gaussian cells that cleared the coverage gate.*
3. **Does R-7's SIGN-OFF still stand?** Its "exact set match" causation evidence is **retired** — six
   heavy runs gave three different warning counts, so the set is not a function of the code. The row is
   signed off; its basis is weaker than when signed.
4. **Confirm or reject the D-74 reading in §1** — it decides whether a seventh panel happens at all.
5. **🛑 DO NOT convene a seventh panel before items 1 and 4.**

---

## 6. Register · outstanding slices · scientific thread

**Register:** R-1…R-11 **all closed** (R-2, R-6, R-7 `SIGNED OFF`; rest `RESOLVED`). **No row blocks
the closing claim.**

**Outstanding non-blocking slices** (ultra-plan Rev 3 ids): **C4** reconcile plan-vs-actual →
`docs/dev-log/plan-actual/` · **C5** terminal M1 synthesis to PR #778 + Mission Control · **A-iss**
triage 20 open issues (#750 self-declares "Target release: 0.6"; #345 CRAN umbrella; #230's 18-comment
thread negotiates M4's gate) · **A12 brain updates — DO THIS FIRST**: a 2026-07-20 note
(`…/2026-07-20-gllvmTMB-EVA-codex-arcloop`) still asserts **"EVA is IN 0.6"** and names Codex as
owner. **A future session reading it will reinstate the cut arc.**

**Surfaced from the brain, on nobody's M1 list — an M4/M5 blocker:** **D-41** requires a *prominent*
experimental warning on first CRAN release — pkgdown callout, README badge, `lifecycle` experimental
badges on exports, `.onAttach` startup message, **and** a line in the DESCRIPTION `Description`. Only
`prepR4pcm` is exempt; **gllvmTMB explicitly is not.** Unverified whether it is in place.
**D-66/D-49:** the honest release rung is **NOT READY, below `source-clean`** — the gap is *evidence,
not capability* — and a closing claim must name the rung.

**Separate scientific thread — NOT an M1 blocker:**
`docs/dev-log/2026-07-22-nongaussian-variance-component-thread.md` — the non-Gaussian
variance-component boundary; why **EVA is probably the wrong lever**; why **AGHQ is better supported**;
and the cross-repo sign anomaly (our sign claim was downgraded to **UNVERIFIED** at `d74a6a08`).

## TRUTH LIVES IN

Branch `codex/gllvmtmb-060-m1-baseline-20260720` @ **`d74a6a08`** (clean, pushed, in sync; certified
evidence `21e04eb5`, transfer **verified empty**). Draft PR #778.
`docs/dev-log/known-residuals-register.md` · `docs/dev-log/check-log.md` ·
`docs/dev-log/handover/2026-07-22-claude-handover-m1-withheld-six-panels.md` ·
`~/gllvmTMB-0.6-evidence/m1/`.

## RESUME

```text
Read LOOP/GOAL.md (ALL THREE amendments — CI IS AUTHORISED; Amendment 3 opens a parallel
design-only Design 86 lane that does NOT gate 0.6) -> LOOP/checkpoint.md ->
docs/dev-log/known-residuals-register.md -> docs/dev-log/check-log.md.

M1 is WITHHELD after SIX 3/3 NOT-DONE panels. No register row blocks it, no check fails, no defect
is outstanding. Withheld on a BASE RATE, not a known problem.

Head d74a6a08, CLEAN, pushed, 0/0 vs origin. Certified 21e04eb5 and the transfer is VERIFIED
(shipped-path diff empty). Suite 0/779/7290, durable runner 0/0/0, CRAN check 0/0/1, Ubuntu success,
three-OS matrix all green, heavy FAIL 0 | WARN 10, guard PASS, receipts with SHA256SUMS.
NOTHING NEEDS RE-EARNING.

BEFORE REPEATING ANY SHA CLAIM, RE-DERIVE IT FROM git, FROM INSIDE THE WORKTREE. This file and the
six-panel handover were BOTH stale on the head. That failure has now appeared SIX times.

BRAIN FINDING (needs Shinichi's confirmation, §1): D-74 says D-43 fires ONCE per milestone claim and
records repeat panels as DRIFT; D-43's remedy is "withheld until the uncovered cells are NAMED", not
"until a panel passes". If confirmed, close M1 in D-43's form instead of running a seventh panel.

DO NOT convene a seventh panel before the wording review (item 1) and the D-74 call (item 4).
SWEEP THE CLASS, NEVER PATCH THE INSTANCE. Verify from structured results only.
Do not trust this agent's commit messages — three were false or damaged.
```
