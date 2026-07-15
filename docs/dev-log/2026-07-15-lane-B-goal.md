# Lane B — goal & autonomy charter (2026-07-15)

Companion to `docs/dev-log/2026-07-15-gap-closure-ultraplan-addendum.md` and the
`2026-07-13` gap-closure ultra-plan. This file exists so Lane B can execute
**autonomously**: it states the goal, what "done" means per slice (verifiable
checks), and the exact decision boundaries — what to do without asking, what to
stop and ask about, what to hand to Codex.

## Goal (one sentence)

> Drive every **non-coverage** gap-closure slice this lane owns — doc-honesty
> fences, shared-dispersion (`disp_group=`) fix + recovery validation, the pilot
> `ci_missing_rate` metric repair, diagnostics breadth, and slope-recovery
> evidence — from *identified* to *landed with evidence*, so that when Lane A's
> coverage certificate lands there is **no remaining non-coverage blocker to
> 0.6** — without ever asserting a coverage claim, merging an API/grammar change
> without sign-off, or colliding with Lane A's working tree.

Lane A owns the headline (interval **coverage** certificate, the Totoro grid, the
widget/NEWS cell-flips). Lane B owns **everything else 0.6 needs**. The two
converge only where Item 1 re-earns nbinom2 — and even then the *flip* is Lane A's.

## Definition of done (lane-level)

Lane B is complete for 0.6 when all of the following hold **with evidence, not
assertion** (D-43 default NOT-DONE):

1. **Doc-honesty:** G1 landed (done); G2/G3 roxygen fences landed via a clean
   `document()`; the register-code grep (checklist §2) is clean; the Phase F
   maintainer review has been *run* (that step is with-Shinichi, not autonomous).
2. **Shared dispersion:** `disp_group=` implemented; the nbinom2 mitigation ladder
   re-run with pooled phi shows median Σ̂/truth materially improved toward nominal
   **and quantified** (pass/fail stated against a pre-declared threshold, not
   vibes); the API is presented for sign-off; merged only after sign-off.
3. **Pilot metric:** `ci_missing_rate` computes a sane value (0–1) with the
   corrected denominator; `dev/test-pilot-scale-gate.R` passes.
4. **Diagnostics breadth:** `predictive_check()` / residuals / `diagnostic_table()`
   extended to at least binomial + one of Gamma/beta, each with a shipped test.
5. **Slope-recovery evidence:** nbinom1 + tweedie slope-recovery either recovers to
   truth (documented) or is fenced as a documented limitation with the #388
   validate-before-advertise gate honoured. (Bare-`||` grammar already landed,
   `900c1af3`.)
6. **Every code slice ships a test**; full-suite closure sums the `error` column
   too; heavy cells run under `GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true`.

## Autonomy contract — the decision rules

**Proceed WITHOUT asking (in-scope, reversible, conflict-safe):**
- Any slice in the addendum marked "fires autonomously": S1 (G2/G3 fences), S2
  (Item 4), S6-scaffold (diagnostics), and **implementing** S3 (`disp_group=`) on a
  branch.
- Reading/validating anything; running local tests, `document()`, `pkgdown` builds.
- Writing design docs, after-task reports, check-log coordination lines.
- Re-running the mitigation ladder / local recovery smokes (small, local — **not**
  Totoro).
- Committing my own new/approved files in focused commits (never Lane A's code).

**STOP and ask the maintainer (Shinichi):**
- **Merging** an API/engine change (`disp_group=`) or any formula-grammar change —
  implement + validate + present, but do not merge without a clear yes.
- Any **coverage** cell-flip on the widget/NEWS, or any prose that upgrades a fence
  from recovery-only to coverage-certified (that is Lane A's certificate).
- Deletions of public exports, new families, likelihood/TMB changes beyond the
  agreed `disp_group=` route, or a broad article rewrite.
- Any genuine scope change beyond this charter's slices.
- Anything irreversible or outward-facing (pushing to a shared remote, opening a
  public PR for review) — surface first.

**Hand to Codex (live TMB / compute), don't attempt as a Claude fan-out:**
- S4 shared-phi ladder re-validation fits, S6 family fits, S7 slope-recovery fits,
  and the Phase A2 coverage campaign (that one is Lane A's anyway).
- Hand over turnkey via `protocols/handoff.md` + a `check-log.md` line; do not defer
  to a Codex session that may not exist — if the fit is needed and no Codex lane is
  live, either run it locally if the toolchain compiles, or park the slice with an
  explicit CARRIED-OVER note.

## Lane-awareness invariants (never violate)

1. Until Lane A commits: **new files + non-Lane-A files only** (mode B).
2. After Lane A commits: **branch off its tip**; never recreate the divergent
   uncommitted-diff hazard.
3. **No coverage claims, ever, from this lane.** Recovery evidence ≠ coverage.
4. nbinom2 stays fenced until Item 1's *evidence* clears it; the un-fence prose and
   the widget flip are staged for Lane A / the Phase F review, not done unilaterally.
5. Report at every stopping point: open PRs/branches, after-task paths, and the
   🔴 sign-off asks — the maintainer does not browse to discover them.

## Cadence

Trigger (Lane A commit) → pull tip → fan out S1+S2+S6-scaffold → implement S3 on a
branch → hand S4 to Codex → **report** (status + the one sign-off ask). Then S5/S6/S7
as capacity and evidence allow. Close each slice with an after-task report; close the
lane with a lane-level recap against the "Definition of done" above.
