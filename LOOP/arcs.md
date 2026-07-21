# gllvmTMB 0.6 arc ledger

Status values: `DONE`, `IN PROGRESS`, `PENDING`, `GATED`, `CUT`.

| Arc | Status | Purpose | Exit evidence | Human gate |
|---|---|---|---|---|
| P0 | DONE | Exclusive ownership, clean builder/verifier, compute inventory | one owner; frozen predecessor; clean lanes; no overlap | none remaining |
| M1 | IN PROGRESS | Release truth, public-boundary repair, green heavy baseline | full release ledger; clean local package checks; exact-SHA Ubuntu/heavy + 3-OS; fresh D-43 | admit M2 only after M1 closes |
| M2 | **CUT** | ~~Design 86 narrow EVA scientific admission~~ — **CUT 2026-07-21 by maintainer decision; EVA moves to 0.7.** See `docs/dev-log/2026-07-21-eva-cut-to-0.7.md` | n/a — no EVA work is attempted for 0.6 | none; its gates are dissolved |
| M3 | PENDING | **Source/API freeze only** (EVA admission removed) + version bump `0.5.0` -> `0.6.0` | frozen source/API/feature list; permissible-claims list; bump lands AFTER the freeze | API freeze |
| M4 | PENDING | Reader-ready release candidate | reconciled docs/Rd/pkgdown; source tarball; local `--as-cran`; candidate hashes | page decisions; candidate freeze |
| M5 | PENDING | Immutable RC, platform, and CRAN ceremony | exact RC/final-tag evidence; NOT-READY-default review | RC tag; final tag; submission |

## Current M1 batch

| Slice | Status | Verification / next proof |
|---|---|---|
| Public nonlinear-profile withdrawal | FOCUSED PASS | profile wins before fit, Julia, level, link, or object validation |
| Repeatability full-covariance contract | FOCUSED PASS | Wald default; typed profile refusal; malformed bootstrap guards; Rd matches code |
| Multinomial FAM-20/FAM-20A/FAM-20B truth | FOCUSED PASS | fitted phylogenetic V distinguished from total + softmax residual |
| Auto-Psi guidance/frequency | FOCUSED PASS | binomial, multinomial, and combined messages have distinct once IDs |
| Cross-family ordinary-tier/ordinal fences | FOCUSED PASS | unit-only typed fence; ordinal `auto` typed refusal; safe article path |
| Generated Rd and exact example | PASS | `devtools::document()` changed only the two expected Rd topics; exact `\dontrun{}` example passed |
| Complete local qualification | **PASS** | full non-heavy `FAIL 0 \| WARN 0 \| SKIP 779 \| PASS 7287`; touched heavy `PASS 173`, 0 heavy-skips, 1186.7s; four articles rendered to `pkgdown-site/` with the ordinal-refusal string oracle passing; **CRAN-config check 0 errors / 0 warnings / 1 `New submission` note**, PDF manual OK, incoming feasibility ran, top-level files OK |
| Programme reshape (EVA cut) | **PASS** | `GOAL.md` amended append-only; `arcs.md`/`ultra-plan.md`/`decision-queue.md` reshaped; `docs/dev-log/2026-07-21-eva-cut-to-0.7.md`; Mission Control rewritten + JSON-validated |
| Known-residuals register | **PASS** | `docs/dev-log/known-residuals-register.md`; R-1/R-3 resolved, R-4 resolved as far as this package can, R-2 signed off as a declared limitation, **R-6 awaits sign-off** |
| Exact-head remote qualification | PENDING | push; automatic Ubuntu; manual 3-OS (`full_matrix=true`); Ubuntu heavy; retained receipts. **Gated on maintainer go/no-go before any CI spend.** |
| M1 closeout | IN PROGRESS | bounded repair after-task/check-log/handoff now; terminal M1 close still needs Mission Control + three fresh D-43 reviews |

## M2 sequential ladder — CUT for 0.6, RETAINED for 0.7

**STATUS: CUT on 2026-07-21 by maintainer decision. None of the steps below run
for 0.6.** The ladder is kept verbatim rather than deleted because its sequential
discipline remains correct whenever EVA is revived. Two corrections a 0.7 reader
must apply before using it:

- **Step 1's target cell is superseded.** The maintainer directed that 0.7's EVA
  target **sparse binary first**, not the `q = 1` complete multi-trial
  binomial-logit cell below. Multi-trial binomial with a complete design is
  information-rich — the regime where Laplace already performs well — so proving
  the estimator there demonstrates correctness but no user value. Note that
  sparse binary at high `q` lies **outside Design 85's admitted data contract**,
  so it requires a new Gate-0 scope freeze, not an extension of existing evidence.
- **"Design 86" was never written or approved.** It exists only as this sketch;
  `LOOP/decision-queue.md` records it as `NOT YET OPEN`. Do not cite it as a
  contract. Separate the *correctness anchor* (an easy, verifiable cell) from the
  *admission criterion* (does it beat Laplace where Laplace is weak) — the sketch
  below conflated them.

1. Write Design 86 from the approved narrow fixed-rank q=1 complete
   multi-trial binomial-logit contract.
2. Obtain explicit maintainer approval of the Design 86 contract.
3. Pass local algebra, Gaussian anchor, scalar/KL, AD/finite-difference, v-to-0,
   H61 calibration, and result-schema gates.
4. Freeze and checksum the campaign bundle.
5. Obtain approval for Totoro smoke and DRAC pilot.
6. Pass Totoro reference/parity, then DRAC-A/DRAC-B parity.
7. Run the predeclared 25-seed-per-stratum pilot; retain all failures.
8. Fisher/Curie/Rose issue `PROMOTE` or `CUT` without tuning the frozen gate.
9. Obtain separate approval for 100-seed confirmation.
10. Issue `SCIENTIFIC-GO` or `CUT` for q1.
11. Only after q1 GO, consider each family/link as a separate wave with its own
    derivation, deterministic gate, smoke, parity, pilot, confirmation, and
    `ADMIT`/`CUT`. No family inherits another's evidence.

## Honest current estimates — revised 2026-07-21 after the EVA cut

**0.6 (the live programme, Laplace-only):**

- M1 remaining: roughly 7 active hours plus CI wait, assuming no load-bearing
  repair. That assumption is weak — the prior session found four such defects —
  so budget a handoff if one fires.
- M3 source/API freeze + version bump: ~0.5 working day.
- M4 reader-ready candidate: ~2–4 agent working days, **plus N sessions of
  Shinichi's own page-by-page review, which is his time, not agent wall-clock**.
- M5 RC + platform + CRAN ceremony: ~1–2 working days plus CI.
- **Total: roughly 4–7 agent working days plus the page-review sessions.**

**0.7 (EVA, deferred — NOT part of this programme):**

- The earlier figures priced the OLD non-sparse scope: minimal q1 EVA ~4–7 weeks;
  broad family-layer q1 ~10–16+ weeks; universal ranks/structures/mixed/
  missing-data a 2–4+ month research programme.
- **The redirected sparse-binary target is UNESTIMATED.** Do not reuse the
  figures above for it — it needs a fresh Gate-0 scope freeze, and the
  second-order surrogate's fixed-order bias is worst in exactly that regime.
- A "minimal EVA" is, by the reasoning in the decision record, permanently not
  worth shipping: 0.7's EVA is the broad version or it is nothing.
