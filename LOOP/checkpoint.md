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

**STATE: M1 CLOSED · M3 CLOSED · M4 IS NEXT.**

- **M1 CLOSED.** All four maintainer decisions ANSWERED; D-74 CONFIRMED, so **no seventh panel**.
  The claim is **SIGNED** at `docs/dev-log/2026-07-22-m1-closing-claim.md`, in D-43's required form.
  Six panels ran where D-74 specifies one, and **not one of the six found a numerical, algorithmic
  or statistical defect** — every finding was about the agent's method, not the package.
- **M3 CLOSED.** API frozen on the maintainer's sign-off and pinned by checksum (`NAMESPACE`
  SHA-256 `c97ae039…`, 153 exports / 33 S3 methods); version bumped `0.5.0 → 0.6.0`. Record:
  `docs/dev-log/2026-07-22-m3-api-freeze.md`.
- **Version is now `0.6.0`. Head `458dc01b`. Draft PR #780.** The EIGHTH evidence chain is complete
  and green **on the bumped identity** — local suite `0 | 779 | 7290`, three-OS `29934531169` with
  three `Status: OK` and zero warn/note, heavy `29934532873` `FAIL 0`, CRAN-config 0/0/1 with the
  NOTE allowlisted. The built artefact was confirmed to be `gllvmTMB_0.6.0.tar.gz` — the bump
  reached the **build**, not merely the files.

**M4's MECHANICAL HALF IS DONE. Head `3c5fd11d` (draft PR #780). The mechanical work stops HERE, at
the candidate-freeze gate — the freeze is Shinichi's.** The TENTH evidence chain is green at the
fences SHA `aa939ce8` (local `0 | 779 | 7290`, 3-OS `29969703136` all three OS `Status: OK` building
`gllvmTMB_0.6.0.tar.gz`, heavy `29969704205` `FAIL 0`, CRAN-config 0/0/1 pinned clean at `3c5fd11d`).
Receipts: `~/gllvmTMB-0.6-evidence/m4/tenth-chain/`.

**D-41 DONE** — all four accepted channels, grounded from `memory/DECISIONS.md` D-41 (NOT a per-export
badge). `.onAttach` verified firing via `load_all(attach = TRUE)`.

**Four additive-safe fences APPLIED** (`aa939ce8`, roxygen-comment only, zero code): dropped "validated"
at `kernel-helpers.R:13`; `@section Interval calibration:` on `extract_phylo_signal`, `loading_ci`,
`extract_repeatability`. Each surfaced as a diff for the page review; every one makes a claim smaller.

**WHAT REMAINS IS SHINICHI'S — the page-by-page reader review**, now a focused sitting guided by the
dossier and the **page-review packet** (`docs/dev-log/2026-07-22-m4-page-review-packet.md`) + the
**rendered site** (`pkgdown-site/index.html`). He chose "review first, then freeze" (2026-07-22). The
M4→M5 gate sequence is on disk: `docs/dev-log/2026-07-22-m4-to-m5-runbook.md`.

**M5-PREP DONE OVERNIGHT (no gate crossed), rung advanced `source-clean → tarball-clean`:** the
provisional candidate tarball `gllvmTMB_0.6.0.tar.gz` (SHA-256 `73893f97…`, 3.25 MB) passes
`R CMD check --as-cran` at **0/0/1** (New submission), forbidden-path scan clean; DESCRIPTION
spell-check clean (the gate's hard blocker); `cran-comments.md` corrected from the stale-false 0/0/0
to the honest 0/0/1. Evidence: `~/gllvmTMB-0.6-evidence/m5-prep/`. **HELD for the freeze:** an
`inst/WORDLIST` (142 domain terms) and `\value` on `ordiplot`/`gllvmTMB_multi-methods` (both advisory,
neither a blocker).

**NEXT GATE: candidate freeze (Shinichi's), after his page review.** Then RC tag → exact-tag 3-OS →
final tag → submission, each his gate. NOT DONE autonomously and never to be: RC/final tag,
win-builder/macbuilder, CRAN submission. Rung: **`tarball-clean` proven; NOT READY** for submission —
the gap is the review + gate sign-offs, not capability (D-49/D-66).

---

## 0. VERIFIED GIT GROUND TRUTH (re-derived 2026-07-22, not inherited)

```
branch                     claude/0.6-m1-close-20260722
HEAD                       d13916f3   (d13916f32f6eae10ffac9a6acef3c6d8b9095437)
working tree               CLEAN  (git status --porcelain = empty)
vs origin                  0  0    (rev-list --left-right --count — fully in sync, pushed)
certified evidence SHA     21e04eb5
certification transfers?   NO — FORFEITED, deliberately. See below.
```

**🔴 THE CERTIFICATION NO LONGER TRANSFERS.** The three maintainer decisions (§5) were answered on
2026-07-22 and applying them required **source edits**. The corrected shipped-path check returns:

```
NEWS.md                              (Decision 2 — the boundary statement)
R/julia-bridge.R                     (Decision 1 — the tightened claim string)
tests/testthat/test-julia-bridge.R   (Decision 1 — its asserting test, swept in the same commit)
```

This is the **sixth** time in the arc that a repair re-minted the source identity. It is expected,
not a fault — Amendment 2's sequencing anticipates it. **Re-earning is IN FLIGHT: see §4.**

**⚠ The old path list would have MISSED this.** It omitted `NEWS.md`, and Decision 2 edited exactly
that file. Had Decision 1 not also touched `R/`, the check would have reported "empty" and declared
a certification that no longer held — a false PASS from the command written to prevent one. The
corrected list caught it on its first real use.

Commits since the certified SHA (the first five are documentation-only; the last three are the
decision application and its evidence):

```
d13916f3 docs(m1): record the re-earned suite result — exact match to the certified baseline
226eeafc fix(loop): the certification-transfer check was itself incomplete — 3 shipped paths missing
198ab08a m1: apply the three maintainer decisions; certification at 21e04eb5 is FORFEITED
5d6c01f4 docs(loop): record Mission Control as materially stale — inspected, deliberately NOT edited
902dde41 docs(m1): after-task — M1 unblock arc (verified state, Amendment 3, A12, C4, A-iss)
e367f57f docs(m1): slice A-iss — triage all 20 open issues; two need maintainer edits
4b1681dd docs(m1): slice C4 — plan-vs-actual reconciliation, never previously run
fe10048a docs(m1): R-11 wording-review dossier — 0 HIGH, 1 to look at, 2 false leads ruled out
```

### ✅ HOW TO CHECK WHETHER A CERTIFICATION STILL TRANSFERS — run this, do not trust prose

The certified SHA and the branch head may differ, **provided no shipped file changed between them.**
Do not take any document's word for that — **including this one.** Re-derive it, **from inside the
worktree** (running it from `~` fails with *"Not a git repository"*, which is an operator error, not
a result):

```sh
cd /private/tmp/gllvmtmb-060-m1-builder
git diff --name-only <CERTIFIED_SHA> HEAD -- \
  R/ src/ tests/ man/ vignettes/ tools/ inst/ DESCRIPTION NAMESPACE NEWS.md README.md
```

> **⚠ THE PATH LIST WAS INCOMPLETE UNTIL 2026-07-22 — the check could miss a real forfeit.**
> Every earlier version omitted **`NEWS.md`, `README.md` and `inst/`**, all three of which **ship**
> (they are absent from `.Rbuildignore`). A NEWS-only or README-only edit would therefore have
> forfeited the certification while the canonical check reported "empty" — a false PASS from the very
> command written to prevent one. Found by enumerating the top-level tree against `.Rbuildignore`
> rather than trusting the list. **The shipped set is:** `R/ src/ tests/ man/ vignettes/ tools/ inst/
> DESCRIPTION NAMESPACE NEWS.md README.md` (note `vignettes/articles` and `inst/tmb/*.o|so|dll|dylib`
> are excluded *within* otherwise-shipping trees). Re-derive this list from `.Rbuildignore` if the
> package layout changes — do not copy it forward on trust.

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

## 1. ✅ D-74 — CONFIRMED by Shinichi, 2026-07-22. No seventh panel.

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

**CONFIRMED.** Shinichi set a session goal on 2026-07-22 carrying this verbatim: *"DO NOT CONVENE A
SEVENTH: D-74 says D-43 fires ONCE per milestone and records repeat panels as DRIFT… D-43's remedy
is 'withheld until the uncovered cells are NAMED', not 'until a panel passes'."*

**Consequence, now binding:** the uncovered cells *are* named exhaustively — R-1…R-11 plus each
handover's "does NOT cover" section — so D-43's remedy is **already satisfied**. M1 closes by
stating the claim in D-43's required form (cite the tier, name the uncovered cells), **not** by
running a seventh panel. That claim is written: `docs/dev-log/2026-07-22-m1-closing-claim.md`.

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

## 4. EVIDENCE — the `21e04eb5` chain is **FORFEITED**; re-earning at `d13916f3` is IN FLIGHT

### 4a. Re-earned so far, at the edited tree `d13916f3`

| Step | Result |
|---|---|
| `devtools::test()` | **`FAILED 0 \| ERROR 0 \| SKIP 779 \| PASS 7290`** — an **exact match** to the certified baseline, so the wording change is behaviourally neutral. `SKIP 779` (not `test_dir()`'s 1001) confirms the **full** suite ran. |
| Targeted `test-julia-bridge.R` | `FAILED 0 \| ERROR 0 \| SKIP 19 \| PASS 562` |
| Old-string sweep | zero residue across `R/`, `tests/`, `man/`, `NEWS.md`, `vignettes/` |
| **3-OS matrix** `29926771814` | ✅ **SUCCESS at `d13916f3`.** All three OS-named jobs `completed/success`: `ubuntu-latest (release)`, `macos-latest (release)`, `windows-latest (release)`. **Verified from the LOG, not the conclusion field:** the 27,256-line log carries **three `Status: OK` lines**, one per platform, and **zero** `ERROR`/`WARNING`/`NOTE` count lines. This matters because `error_on: "error"` lets warnings and notes pass — a green conclusion alone would not have established 0/0/0. |
| **Heavy full-check** `29926795733` | ✅ **`FAIL 0 \| WARN 9 \| SKIP 102 \| PASS 13650`**, `Status: OK`, at `d13916f3`. Heavy gate confirmed genuinely ON — `GLLVMTMB_HEAVY_TESTS` appears 18× in the log, asserted because `skip_if_not_heavy()` **fails open**. Baseline was `WARN 10 \| SKIP 103 \| PASS 13656`; the `SKIP −1 / PASS −6` drift is **recorded, not waived** (claim §4.1). |
| **CRAN-configuration check** | ✅ **0 errors, 0 warnings, 1 NOTE, 0 unexpected**, at `7f9b9ed1`. The NOTE is *"New submission"* — on the expected allowlist. `SHA_STABLE=TRUE`. Runner **`dev/m1-cran-config-check.R`** (`^dev$` build-ignored, does not ship). |

**The two evidence SHAs are interchangeable:** the shipped-path diff `d13916f3..7f9b9ed1` is
**empty** — `7f9b9ed1` touches only `LOOP/` and `dev/`, both build-ignored. Same shipped tree.

**The chain is COMPLETE. This is the SEVENTH of the arc; the previous six were each forfeited by a
later source change, and every one was green.**

**Dispatching both at once is safe here** — the concurrency group is `workflow-ref`, and
`R-CMD-check` and `full-check` are different workflows, so they cannot cancel each other. The
standing rule (never dispatch `R-CMD-check.yaml` while an Ubuntu run is in flight) concerns **two
runs of the same workflow on the same ref**; one `full_matrix=true` run avoids it entirely.

**Until these land, the closing claim stays DRAFTED, NOT SIGNED.**

### 4b. The FORFEITED chain, for reference — green at `21e04eb5`

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

## 4c. ⚠ MISSION CONTROL IS MATERIALLY STALE — NOT UPDATED, and deliberately so

`Shinichi/Dashboards/mission-control/live/status/gllvmTMB.json` (the board `CLAUDE.md` makes step 0
of every session) is **wrong on several load-bearing facts and internally self-contradictory**:

- Says **one** D-43 panel returned 3/3 NOT-DONE. **Six** have run.
- Names the pushed head as `25c76789`. Actual head is on `claude/0.6-m1-close-20260722`; certified
  evidence is `21e04eb5`. The same file *also* says `25c76789` is "SUPERSEDED" — it contradicts
  itself two fields apart.
- Lists **R-7 as `AWAITING SIGN-OFF`** and "two of the eight sites remain unidentified". R-7 is
  **SIGNED OFF** and all eight sites are traced.
- Carries a stale post-freeze rule, "DO NOT COMMIT to the package repo".

**Why it was left alone (2026-07-22):** the file was **uncommitted-dirty from another writer** for
the whole session, and the tool layer would not return its diff. Editing a file whose concurrent
change you cannot read risks destroying it — D-60's rule is *identify the writer, never assume*. A
stale board is a smaller harm than a silently clobbered one.

**Next session: re-check `git status` on that path first.** If clean, rewrite it against §0 and §4
of this file. If still dirty, read the other writer's diff before touching it.

## 5. ✅ THE MAINTAINER DECISIONS — ALL FOUR ANSWERED 2026-07-22

**Nothing is open for the maintainer.** Applied in `198ab08a`; recorded in
`docs/dev-log/2026-07-22-m1-closing-claim.md` §1.

| # | Question | Answer | Applied as |
|---|---|---|---|
| 1 | R-11 wording — keep or tighten the one flagged string | **TIGHTEN** | `R/julia-bridge.R:1671` `"experimental route: partial validation only"` → `"experimental route: point estimate only; no coverage evidence"`, **plus** its asserting test at `test-julia-bridge.R:1273`. Grep across `R/`, `tests/`, `man/`, `NEWS.md`, `vignettes/` now returns **zero residue** — swept, not patched. |
| 2 | Write the `NEWS.md` boundary statement in | **YES** | New first bullet under `## Known limitations`: variance-component **point estimates** are the supported claim for non-Gaussian families; **interval calibration** holds only for the Gaussian cells that cleared the gate. |
| 3 | Does R-7's sign-off stand | **YES** | Stands. What was retired is **one strand of causation evidence** (the "exact set match" argument), not any of the eight diagnoses — all traced to source — nor site (d)'s mechanism, confirmed by direct measurement. D-43 governs **claims**, not signed-off register rows. |
| 4 | Confirm or reject the D-74 reading in §1 | **CONFIRMED** | Shinichi set a session goal on 2026-07-22 containing, verbatim: *"DO NOT CONVENE A SEVENTH: D-74 says D-43 fires ONCE per milestone and records repeat panels as DRIFT."* **No seventh panel.** M1 closes by stating the claim in D-43's required form. |

> **⚠ Read-back recorded on Decision 1.** The reply was *"yes experment"*. Both options began
> "experimental route:", so it did not disambiguate on its own. Taken as assent to the proposed
> tightening because the asymmetry is one-sided — the tighter string claims **strictly less** and
> cannot become a false claim, whereas a vague one risks exactly the failure this milestone was
> withheld for. **If "keep as-is" was meant, it is a one-line revert in two files.**

**The only thing now standing between M1 and closure is the re-earned evidence chain in §4.**

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

Branch `claude/0.6-m1-close-20260722` @ **`d13916f3`** (clean, pushed, `0 0` vs origin). Certified
evidence `21e04eb5` is **FORFEITED**; re-earning in flight (§4a). PRs **#778 and #779 are MERGED**
— this branch has no open PR, which is why a push alone triggers nothing and CI must be dispatched.
`docs/dev-log/2026-07-22-m1-closing-claim.md` — **the claim itself, DRAFTED not signed** ·
`docs/dev-log/known-residuals-register.md` · `docs/dev-log/check-log.md` ·
`docs/dev-log/2026-07-22-r11-wording-review-dossier.md` ·
`docs/dev-log/plan-actual/2026-07-22-m1-plan-vs-actual.md` · `~/gllvmTMB-0.6-evidence/m1/`.

## RESUME

```text
Read LOOP/GOAL.md (ALL THREE amendments — CI IS AUTHORISED; Amendment 3 opens a parallel
design-only Design 86 lane that does NOT gate 0.6) -> LOOP/checkpoint.md ->
docs/dev-log/known-residuals-register.md -> docs/dev-log/check-log.md.

ALL FOUR MAINTAINER DECISIONS ARE ANSWERED (§5). NOTHING IS OPEN FOR SHINICHI. D-74 is CONFIRMED
by the goal he set: NO SEVENTH PANEL. M1 closes by stating the claim in D-43's required form.

Head d13916f3 on claude/0.6-m1-close-20260722, CLEAN, pushed, 0/0 vs origin. The certification at
21e04eb5 is FORFEITED — applying the decisions edited NEWS.md, R/julia-bridge.R and its test. That
is expected (the sixth such re-mint), not a fault.

EVIDENCE CHAIN COMPLETE AND GREEN (the seventh of the arc):
  devtools::test()   FAILED 0 | ERROR 0 | SKIP 779 | PASS 7290 — EXACT match to the baseline
  3-OS 29926771814   SUCCESS, ubuntu+macos+windows; LOG shows three "Status: OK", ZERO warn/note
  heavy 29926795733  FAIL 0 | WARN 9 | SKIP 102 | PASS 13650, Status OK, heavy gate asserted ON
  CRAN-config        0 errors | 0 warnings | 1 NOTE ("New submission", allowlisted) | 0 unexpected
All read from LOGS, not conclusions — error_on:"error" lets warnings and notes pass, so a green
conclusion alone would NOT have proven 0/0/0.

THE CLOSING CLAIM IS SIGNED: docs/dev-log/2026-07-22-m1-closing-claim.md.

RECORDING DONE: closing claim SIGNED · check-log entry landed · Mission Control rewritten and
committed (vault 655cee6; JSON validated, key schema matches all seven sibling boards) · A12 swept
(six brain files matched EVA-near-0.6; four already corrected, one fixed at vault 483cc8d where a
banner had been added but the BODY still read "EVA is the headline of gllvmTMB 0.6.0";
Brain-Growth-Report:126 deliberately left, as it logs commit subjects and editing it would falsify
history) · A-iss triaged · C4 plan-vs-actual landed.

C5 LANDED: **draft PR #780** — https://github.com/itchyshin/gllvmTMB/pull/780 — carries the terminal
M1 synthesis. Its specified destination (#778) was merged, so a new PR was opened; the goal's step 5
said "pick a live home and name it", which delegated the choice. **It is DRAFT and stays draft** —
it is the RECORD of M1's close, not a merge request. Merge, tag, freeze and submission remain
separate gates.

**Opening it restored auto-CI, as predicted.** A `pull_request` event immediately triggered
`R-CMD-check` at head `8f406e4b`. That run is **Ubuntu-only** (the `pull_request` trigger does not
set `full_matrix`), so it is a bonus re-qualification of the documentation commits — **not** M1's
platform evidence, which is the exact-SHA three-OS run at `d13916f3`. Do not conflate them.

**M1 AND M3 ARE BOTH CLOSED.** M4 is next. Its two already-known items:

  D-41's mandatory experimental warning is UNVERIFIED and gllvmTMB is NOT exempt — pkgdown callout,
  README badge, lifecycle badges on exports, .onAttach message, DESCRIPTION Description line.
  A RELEASE BLOCKER if absent; resolve it early rather than discovering it at M5.

  A live reader-facing CONTRADICTION, deliberately not guessed at: _pkgdown.yml:319 tells readers
  the deprecated covariance functions are "soft-deprecated as of 0.5.0", while brms-sugar.R:131
  tells users 0.2.0. One is wrong on a reader surface. Resolve with the maintainer, not by picking.

  Also for M4: the claim-string class OUTSIDE the five R-11 files -- man/, the shipped vignette,
  NEWS.md, README.md, the DESCRIPTION Description -- was never swept.

M5 then needs its own exact-TAG three-OS cycle; the eighth chain qualifies the bumped branch head,
not a tag. Historical M3 detail follows:
  1. fill §4 of docs/dev-log/2026-07-22-m1-closing-claim.md and flip DRAFTED -> SIGNED
  2. rewrite Shinichi/Dashboards/mission-control/live/status/gllvmTMB.json (§4c — check git status
     on it FIRST; it was dirty from another writer and must not be clobbered)
  3. commit with git commit -F, push
  4. then M3: API freeze, then bump DESCRIPTION/NEWS 0.5.0 -> 0.6.0 (a source edit that WILL
     invalidate the receipts earned above — expected; M5 prices a second exact-tag cycle)

BEFORE REPEATING ANY SHA CLAIM, RE-DERIVE IT FROM git, FROM INSIDE THE WORKTREE. This file was
stale on the head for the SEVENTH time (it still listed the three decisions as open two commits
after they were applied). The class is structural: a document true when written goes false as the
repo moves. tools/check-reader-surface.sh cannot catch it.

SWEEP THE CLASS, NEVER PATCH THE INSTANCE. Verify from structured results only.
Do not trust this agent's commit messages — three were false or damaged.
```
