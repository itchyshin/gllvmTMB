# M1 — plan versus actual (slice C4)

**Slice C4 of the ultra-plan Rev 3.** Never previously run; it was carried as outstanding through
six D-43 panels. Written 2026-07-22 on `claude/0.6-m1-close-20260722` @ `509d5792`.

**What this is.** A reconciliation of the approved M1 plan against what the arc actually did, plus
the scope, evidence and claim drift that opened between them. `LOOP/ultra-plan.md` requires this at
programme close: *"reconcile plan versus actual and surface all scope/evidence/claim drift."*

**Standard applied.** A slice is `DONE` only against a named artifact — a commit, a receipt, a file
that exists. A document *mentioning* a slice is not evidence it ran. Anything I could not establish
is `CANNOT VERIFY`, never `DONE`.

---

## 1. Slice reconciliation

| Slice | Planned | Actual | Evidence |
|---|---|---|---|
| A0 | `^LOOP$` → `.Rbuildignore` | **DONE** | `.Rbuildignore:23` |
| A2 | WARN causation test | **DONE, then RETIRED** | Became R-7. Its "exact set match" evidence was withdrawn — see §3. |
| A2b | Register row per WARN / non-declared skip | **DONE** | R-7 in `known-residuals-register.md`, with three recorded corrections |
| A3 | Touched heavy routes | **DONE** | heavy run `29903134856`, `FAIL 0 \| WARN 10 \| SKIP 103 \| PASS 13656` |
| A4 | Article renders + `check_pkgdown()` | **DONE** | recorded in `arcs.md` "Complete local qualification" |
| A5 | Inspect rendered pages | **DONE** | ordinal-refusal string oracle passed (`arcs.md`) |
| A6b | CRAN-config check on the tarball | **DONE** | 0 errors / 0 warnings / 1 note (`New submission`) |
| A9 | LOOP reshape + EVA persistence | **DONE** | `GOAL.md` Amendments 1–3, `docs/dev-log/2026-07-21-eva-cut-to-0.7.md` |
| A9b | `decision-queue.md` CUT rows | **DONE** | Design 86 recorded `NOT YET OPEN` |
| A9c | Mission Control update | **DONE** | `arcs.md` records "rewritten + JSON-validated" |
| A10 | Receipts + commit | **DONE** | receipts under `~/gllvmTMB-0.6-evidence/m1/final-receipt/21e04eb5…/` with `SHA256SUMS` |
| A11 | Two durable exact-head runners | **DONE** | suite `0/779/7290`; durable `--as-cran` `0/0/0` |
| B1 | Push + 3 exact-SHA workflows | **DONE** | Ubuntu `29903055881`; matrix `29904363055` (ubuntu+macos+windows, asserted by job name) |
| B2 | Record CI to PR #778 + Mission Control | **CANNOT VERIFY** | not confirmed this session |
| C1–C3 | D-43 panel | **DONE — SIX TIMES.** See §2 | six 3/3 NOT-DONE verdicts |
| **C4** | Reconcile plan vs actual | **DONE — this file** | — |
| C5 | Terminal M1 synthesis to #778 | **NOT DONE** | blocked behind the closing claim |
| A12 | Brain updates | **DONE 2026-07-22** | vault `ceb2ab7`, `de1a764`; five surfaces superseded |
| A-iss | Triage 20 open issues | **NOT DONE** | — |

---

## 2. The largest drift: C1–C3 ran six times, not once

**Planned:** one D-43 panel — *"three fresh D-43 NOT-DONE-default reviews"* — fired once after
candidate evidence existed.

**Actual:** six consecutive panels, six 3/3 NOT-DONE verdicts.

**This is a governance drift, not diligence.** Brain **D-74** (2026-07-21, accepted) states that
D-43 *"runs **once per actual milestone claim**, after candidate evidence is ready — not per commit,
receipt, or repair,"* and that *"Melissa records **gratuitous repeat panels as drift**."* D-74's own
evidence is this lane — *"81 [child sessions] from one long gllvmTMB parent."* It was written from
this arc's telemetry, and then the arc ran three more panels.

**D-43's remedy was also misread.** Its text is *"WITHHELD until the uncovered cells are named
explicitly"* — named, not "until a panel passes". **D-46** records the designed shape from the first
real panel: 3 NOT-DONE → repair → *the same three reviewers re-voted 3 DONE*. One cycle with a
re-vote.

**Cost of the drift, measured.** Five complete evidence chains were earned and forfeited, each by a
source edit made in response to a panel finding; the sixth stands. **Three of the six panel findings
were defects introduced by the previous panel's own fix.** Twelve instance-fixes were claimed as
class-fixes. Three commit messages were false or damaged.

**Benefit, stated fairly.** The panels were not worthless. They produced a genuinely false capability
claim removed (`simulate()` told users multinomial was unsupported while drawing it), dead links
fixed in the shipped vignette, and the reader-surface guard extended to cover a *class* — two new
code shapes, a new surface (`R/` string literals), and shipped-vignette link checking, each pattern
validated by construction. **But not one of the six found a numerical, algorithmic or statistical
defect.** The engineering was green throughout.

---

## 3. Evidence drift

**R-7's causation evidence was retired mid-arc.** The row originally claimed an "EXACT SET MATCH" of
heavy warning sites proved the arc added none. Six Ubuntu heavy runs then returned **WARN 8, 9 and
10** from functionally identical code. The contingent sites are optimiser-convergence-dependent, so
the set is not a function of the code and a match between two runs proves nothing.

The instructive part is the sequence: the original claim (*the set is not stable*) was **correct**;
two subsequent "refinements" narrowed it and were **both wrong**; an "established invariant" was
asserted from **n=4** and refuted at **n=5**. **The sites were never the defect — the evidence
standard was.** `WARN n` is not a regression signal; only `FAIL` is, and all six runs returned
`FAIL 0`.

**Five evidence chains forfeited.** Each was green on every check when earned. The package has been
in working order the entire arc; what kept moving was the source identity beneath the receipts.

---

## 4. Claim drift — the recurring failure

One shape, twelve times: **repair the instance pointed at, not the class it belongs to, then state
in a commit message that the class is fixed.**

Worked examples worth keeping: a reported `FAIL 0` from a grep matching a marker the reporter never
emits (the run had failed); a suppression wrapper applied to one of **two** return branches, leaving
the **default** broken; `"validated"` corrected on line 1587 and left on 1588 of the *same*
`cli_abort`; an R-10 register contradiction fixed without checking R-9, which had the identical
defect; a checkpoint warning about stale references that named its own commit's SHA.

**The real class is two-dimensional — SURFACES × CODE SHAPES.** Sweeping known shapes on
already-scanned surfaces was itself instance-thinking, one level up. When the arc finally swept
properly it found six `cli_abort` messages directing users to *"consult the validation register"* —
a `docs/design/` file `.Rbuildignore:18` (`^docs$`) excludes from the tarball. **Five panels had
missed it.**

**A sixth stale-document instance closed today.** `LOOP/checkpoint.md` and the six-panel handover
both named the wrong head (`21e04eb5` and `eea9761c`; actual `d74a6a08`). Re-derived from `git` and
corrected. The rule now written into the checkpoint is deliberately a *rule, not a result*: a
recorded conclusion goes stale the moment someone commits.

---

## 5. Scope drift

**EVA cut from 0.6 to 0.7** (Amendment 1) — the largest scope change, and a maintainer decision at a
gate, so legitimate rather than drift. M2 dissolved with it.

**A goal-block line silently revoked a standing authorisation.** A `/goal` carried *"stop before any
push/CI spend"* alongside *"close M1"*. M1's definition of done requires exact-SHA three-OS
evidence, which only CI can produce, so the two were contradictory and **M1 was unclosable by
construction**. Amendment 2 restored CI authorisation. The line still lives in the ultra-plan Rev 3
GOAL block as `MD-5`; a guard against reinstating it is now recorded in `LOOP/checkpoint.md`.

**A parallel design-only lane was opened** (Amendment 3, 2026-07-22): Design 86 feasibility, fenced
to `docs/design/86-*.md`, in a worktree outside Dropbox, explicitly **not** gating 0.6.

**Under-scoping recurred six times**, by the arc's own count — R-10 was presented as "15 sites" and
proved to span six files and a wider vocabulary. The maintainer was told before work continued.

---

## 6. What M1 did NOT cover

- **Whether the replacement prose is true.** No check establishes it; that is the maintainer's
  review. Prepared as `docs/dev-log/2026-07-22-r11-wording-review-dossier.md`.
- **The `NEWS.md` boundary statement** — drafted, deliberately not written in.
- **Whether R-7's sign-off survives** its retired causation evidence.
- **The claim-string class outside the five R-11 files** — `man/`, the shipped vignette, `NEWS.md`,
  `README.md`, the `DESCRIPTION` `Description`. An M4 item; **do not assume it is done.**
- **D-41's mandatory experimental warning** (pkgdown callout, README badge, `lifecycle` badges,
  `.onAttach`, DESCRIPTION `Description`). gllvmTMB is **not** exempt; only `prepR4pcm` is.
  Unverified whether it exists — a release blocker if absent.
- **B2, C5, A-iss** — outstanding.
- **Any merge, tag, submission or readiness claim.** Per D-49 the rung must be named; per D-66 the
  honest rung is **NOT READY, below `source-clean`** — the gap is *evidence, not capability*.

---

## 7. Estimate versus actual

`arcs.md` estimated *"roughly 7 active hours plus CI wait, assuming no load-bearing repair,"* and
flagged that assumption as weak. **It was weak.** The arc ran six panels, twelve instance-repairs,
and five forfeited evidence chains. The estimate's own hedge — *"budget a handoff if one fires"* —
was the accurate part; multiple handoffs fired.

**Lesson for M3–M5 estimates:** the dominant cost was not the work, it was **re-earning evidence
after each repair re-minted the source identity.** M3's version bump invalidates every M1 platform
receipt *by design*, so M5 must price a second exact-tag three-OS cycle. That is expected and
budgeted — but it is also a second reason not to spend further evidence perfecting M1's CI.

> Related: `LOOP/ultra-plan.md` · `LOOP/arcs.md` · `LOOP/checkpoint.md` ·
> `docs/dev-log/known-residuals-register.md` · `docs/dev-log/2026-07-22-r11-wording-review-dossier.md`
