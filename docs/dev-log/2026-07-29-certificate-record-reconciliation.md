# Certificate record reconciliation — the Gaussian `Sigma_unit` diagonal coverage cell

**2026-07-29.** This note exists because the package's record of one number — whether the
Gaussian `Sigma_unit` diagonal profile interval clears its 0.94 coverage gate at n ≥ 150 — split
into two contradictory lines of descent that neither knew the other existed. **If you are a
future session about to re-derive this cell's certificate state, read this note first. Do not
re-read `decisions.md` or any single handover and treat it as settled.**

## What happened, as a table

| date | evidence | gate | verdict | on `main` before 2026-07-29? |
|---|---|---|---|---|
| 2026-07-17 | 5k reps, orig-only seeds (`after-task/2026-07-17-sigma-coverage-nsim5000-confirm.md`) | 0.94 | WITHHELD — d2-n150 0.9462, band 0.9398 ✗ | **No** — parked on `claude/profile-coverage-remeasure-20260718`; only *quoted* on `main` inside later synthesis docs (see below) |
| 2026-07-17 (later, same day) | pooled N≈15k, disjoint fresh seeds (`dd80244a:docs/dev-log/2026-07-17-sigma-coverage-d43-panel.md`) | 0.94 | **BOTH cells CERTIFY, 3-0** — d1-n150 0.9477/band 0.9440, d2-n150 0.9461/band 0.9424 | **No** — same parked branch; quoted on `main` for the first time by this note, and deliberately not ported (R-5) |
| 2026-07-19 | Bartlett re-score, n≈4000 (commit `9476cbe4`) | 0.95 | WITHHELD — *"0.94 floor held everywhere"* | **No** — same parked branch cluster |
| 2026-07-29 | 20,000-rep-per-cell confirmatory re-run | 0.94 | pre-registered (`docs/dev-log/2026-07-29-certificate-gate-preregistration.md`, commit `90798365`) and **launched** (`docs/dev-log/2026-07-29-certificate-run-record.md`, from this same lane, ≈2h expected on 90 Totoro cores); result not yet in | Pre-registration and launch record yes; coverage result no |

**Correction to the brief that requested this note.** The brief's version of this table marked the
5k WITHHELD document and the Bartlett WITHHELD document as "on `main`? yes." That is not what the
repository shows. `git log --all -- <path>` for all three 2026-07-17/07-19 primary documents shows
each reachable only from `claude/profile-coverage-remeasure-20260718`, `claude/release-0.5.0`, and
sibling `codex/*` branches — **none is an ancestor of `origin/main`.** What *is* on `main` before
today is a chain of second-hand citations: `docs/dev-log/2026-07-28-next-arc-sigma-intervals-ULTRAPLAN.md`,
`docs/dev-log/after-task/2026-07-28-sigma-interval-arc-premise-collapse.md`, and two handovers
(`2026-07-28-claude-handover-sigma-premise-collapse.md`, `2026-07-28-lane-starter-parallel-lanes.md`)
all quote the 5k WITHHELD numbers, correctly, as if that were the complete 2026-07-17 record. None
of them quotes the Bartlett re-score at all. So the accurate summary is: **all three primary
documents were equally absent from `main`; only one of the three was ever indirectly represented
there, and only its unfavourable half.**

## Why the record diverged

`dd80244a` (2026-07-17) is the commit that flipped the interval route and, per its own commit
message, was "Maintainer-approved" — but it landed on a branch (`claude/profile-coverage-remeasure-20260718`)
that a 2026-07-21 maintainer decision (R-5, `docs/dev-log/known-residuals-register.md:203`,
`docs/dev-log/2026-07-22-a-iss-open-issue-triage.md:24-28`) left **deliberately unmerged**, bundled
with unrelated #750 spatial-redraw work on the same branch, "to avoid touching the quarantined
estate and re-minting M1's source identity." That decision was about the branch's *code*; it does
not appear to have been revisited for the *documentation* riding alongside it, and the panel
document simply never got ported on its own. That is a plausible, evidenced reason the CERTIFY
panel never reached `main` — it is not the same claim as "nobody looked," and this note does not
allege negligence in the original non-merge decision.

What compounded it: every session since 2026-07-28 that went looking for "the primary record" on
`Sigma_unit` coverage found the 5k WITHHELD after-task, correctly quoted it, and stopped — without
checking whether a second same-day document existed. `docs/dev-log/2026-07-28-next-arc-sigma-intervals-ULTRAPLAN.md`
even names `dd80244a` explicitly and correctly describes its diffstat ("the public-flip commit
only and contains no script") without reading the panel markdown carried inside that same diff.

## The symmetry — the durable lesson

`decisions.md:2130-2135` (2026-07-28) *over*-stated the position: "It is the one coverage-certified
cell in the package" — a live-certificate claim resting only on the CERTIFY panel, without the
gate framing, the raw-loss problem, or the fact nothing was ever flipped publicly.

The 2026-07-28 sessions that caught that overstatement (`2026-07-28-next-arc-sigma-intervals-ULTRAPLAN.md`
"EXECUTION FINDING #3", `after-task/2026-07-28-sigma-interval-arc-premise-collapse.md` §9.3, and
two handovers) corrected it to *"THERE IS NO CERTIFICATE" / "the certificate does not exist"* — an
*under*-statement resting only on the WITHHELD document, which is equally one-sided.

**Both errors have the identical shape: a claim restated from whichever single source was in hand,
never checked against every primary document that source's own trail pointed to.** Catching that a
claim is too strong tells you nothing about what the accurate claim is — that requires reading the
full evidence, not just disbelieving the overstated version of it. The 2026-07-28 sessions
explicitly diagnosed this exact failure mode in themselves and in others, then, one paragraph
later, committed a new instance of it. That recurrence — not the individual errors — is the thing
worth remembering.

## What is true as of today (2026-07-29)

- The 0.94 coverage gate **was met once**, at pooled N≈15k, by a 3-0 D-43 panel — see the quoted
  record immediately below.
- **That result is not reproducible.** `~/gllvm_work/results/` on Totoro, which both independent
  lenses recomputed from, is now empty. The summary survives; the raw does not.
- **A confirmatory 20,000-rep-per-cell re-run supersedes it**, self-contained (no pooling with the
  15k or 5k reps), against the identical 0.94 gate, pre-registered *before* launch
  (`docs/dev-log/2026-07-29-certificate-gate-preregistration.md`, commit `90798365`). A sibling
  slice in this same lane (`claude/evidence-gap-20260729`) launched it while this note was being
  written — `docs/dev-log/2026-07-29-certificate-run-record.md` records the invocation, 90 Totoro
  cores, ≈2h expected wall-clock, raw retained this time. **No coverage result yet exists for this
  run; do not assume it has passed or failed until its own D-43 panel writes a disposition.**
- **There is no live certificate and no public claim.** `NEWS.md` ("No cell's interval coverage is
  certified"), the `confint()` roxygen, and `capability-surface.html` are all still accurate and
  were not touched by this reconciliation — nothing in the record justifies flipping any of them
  today, and nothing here should be read as license to.
- The gate is **0.94, stated explicitly, never nominal 0.95** — carried through unchanged from the
  2026-07-17 panel's own instruction, which every downstream document that quotes any part of this
  history has continued to honour.

## The 15k CERTIFY panel, quoted with provenance

**Source:** `dd80244a:docs/dev-log/2026-07-17-sigma-coverage-d43-panel.md`. Retrieve the full
document with `git show dd80244a:docs/dev-log/2026-07-17-sigma-coverage-d43-panel.md`.

**Why it is quoted here rather than ported.** R-5 in `docs/dev-log/known-residuals-register.md`
records a maintainer decision of 2026-07-21: the work on
`claude/profile-coverage-remeasure-20260718` *"was deliberately NOT merged, to avoid touching the
quarantined branch estate and re-minting M1's source identity."* `dd80244a` is the first commit of
that fenced range (`dd80244a..051eb4e5`). Quoting it makes the evidence visible on `main` without
importing a file from the fenced estate. **Maintainer decision, 2026-07-29: quote, do not port.**

What that panel recorded, so this note stands alone:

| cell | coverage | band (cov − 2·MCSE) | gate 0.94 | disposition |
|---|---|---|---|---|
| d1-n150 | 0.9477 | 0.9440 | ✓ +0.0040 (~2.2 MCSE) | CERTIFY |
| d2-n150 | 0.9461 | 0.9424 | ✓ +0.0024 (~1.3 MCSE, thin) | CERTIFY |

- **Method:** three independent adversarial lenses, default NOT-DONE, plus a synthesis chair. Two
  lenses independently recomputed the pooled figures to 4 dp on Totoro **from the raw
  covered/converged/`ci_available` flags**, not from a precomputed summary.
- **Why it earned:** doubling the independent reps with a **disjoint fresh seed** halved the MCSE
  (0.0032 → 0.00185) and lifted the lower band above 0.94 **without inflating the point estimate** —
  d2 settled slightly *down*, to ~0.9461. No looser MCSE, no same-seed refit.
- **Checks recorded:** rep-index overlap re-verified 0; per-batch homogeneity re-verified
  (d1 p=0.85, d2 p=0.65); orig-only figures match the committed WITHHELD after-task exactly; the
  rorqual N=5k d2=0.9462 is consistent with the pooled 0.9461.
- **Its own scope instruction, carried forward unchanged:** *"Do NOT restate the number as
  unconditional or nominal-0.95 coverage; the gate is `coverage ≥ 0.94`."*
- **"CERTIFY" meant:** the evidence would support a certificate *if the maintainer flips*; it did
  not itself flip any public surface. Nothing was flipped then, and nothing is flipped now.

## Files touched by this reconciliation

- The 15k CERTIFY panel was **deliberately not ported** — quoted above instead, per R-5.
- `docs/dev-log/decisions.md:2130-2135` — inline correction plus a full dated entry appended at the
  end of the file, following the file's own append-only convention.
- `docs/dev-log/2026-07-28-next-arc-sigma-intervals-ULTRAPLAN.md`,
  `docs/dev-log/after-task/2026-07-28-sigma-interval-arc-premise-collapse.md`,
  `docs/dev-log/handover/2026-07-28-claude-handover-sigma-premise-collapse.md`,
  `docs/dev-log/handover/2026-07-28-lane-starter-parallel-lanes.md`,
  `docs/dev-log/handover/2026-07-29-claude-handover-LANE1-aghq-and-evidence.md` — each received a
  short dated addendum at the point where it stated "no certificate" / "does not exist," pointing
  here. None of their historical narrative was rewritten — each addendum is additive, matching the
  append-only convention `decisions.md` already uses throughout.

## What was deliberately NOT touched

`NEWS.md`, `confint()` roxygen (`R/z-confint-gllvmTMB.R`, `man/confint.gllvmTMB_multi.Rd`), and
`docs/dev-log/capability-surface.html` were checked and found accurate — none makes a certificate
claim for this cell, so none needed correction, and per standing instruction none was edited as
part of this slice regardless. If a future session is tempted to flip any of them on the strength
of the ported panel document alone: don't. The panel's own recommendation is explicit — "nothing
is flipped by this panel" — and the confirmatory 20k run is the thing that was actually asked for.
