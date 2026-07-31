# After-task — #843 shipped-engine truth start (AGHQ estimator-validation lane, slice 1)

**2026-07-31 · Claude (Fable 5) · branch `claude/843-truthstart-20260731`**

## 1. Goal

Run the first slice named by `docs/dev-log/handover/2026-07-31-aghq-estimator-validation-new-lane.md`:
#843's **shipped-engine truth start at n = 100**. Decide whether the AGHQ runaway is the
maximum-likelihood solution (in which case the shipped single-start design is re-justified)
or an optimiser failure (in which case every "AGHQ alone" number in the evidence base is
contaminated). The handover required reading the **live** GitHub state of #843, #842, #847,
#848 before decomposing.

## 2. Implemented

- `dev/aghq-evidence/22-truthstart-shipped.R` — the truth-start experiment: 40 seeds ×
  2 arms through `gllvmTMB()` itself, with a pre-registered three-branch decision rule and
  three pre-flight assertions.
- `dev/aghq-evidence/23-altstart-shipped.R` — the follow-up that decides the issue: does the
  **truth-free** alternative start the engine already builds recover the lost optimum?
- `dev/aghq-evidence/sweep-control-fields.R` — a class sweep for the defect found on the way.
- `docs/dev-log/audits/2026-07-31-aghq-truthstart-shipped-engine.md` — the evidence record.
- `R/fit-multi.R` — **one** conditional: a `control$aghq_start_par` diagnostic hook,
  deliberately *not* a `gllvmTMBcontrol()` argument, so it is unreachable for users and
  changes no shipped behaviour. It is what makes the experiment reproducible.

**Result. B2 — START PROBLEM.** On the 16/40 seeds where the shipped AGHQ arm ran away
catastrophically (‖Λ̂‖/‖Λ‖ > 5), the runaway is **not** the MLE: unanimously 16/16, the same
engine started at the truth reaches a strictly better objective (1.14–12.94 nll, median
4.70) and a far better estimate (median frob 16.23 → 2.12). The withdrawn justification's
claim of "ties in 40/40" reproduces as **13/40 overall and 0/16 on the catastrophic seeds**.
The truth-free alternative start recovers it (16/16, median gap closed 1.00); best-of-both
takes catastrophic fits **16/40 → 1/40** and matches the truth start's objective.

## 3a. Decisions and Rejected Alternatives

- **Rebuilt the package from `main` before measuring.** The installed binary was from
  2026-07-18 — 13 days stale and missing #844. Measuring a "shipped engine" on it would have
  repeated the exact error (wrong instrument) this lane exists to correct.
- **Rejected `optArgs = list(control = list(iter.max = 0))`** as a zero-patch way to freeze
  the Laplace stage: `run_one()` merges user `optArgs$control` *over* the AGHQ iteration cap
  (`R/fit-multi.R:5052-5056`), so it would have frozen the AGHQ optimiser too and silently
  produced a null result.
- **Rejected reimplementing the fitter.** That is precisely what invalidated
  `dev/aghq-r-reference.R`. The hook instruments the shipped template instead.
- **Rejected `start_from`.** It seeds `tmb_params` *before* the Laplace stage, so AGHQ would
  still start from Laplace's answer — a truth start for Laplace, not for AGHQ.
- **Refined the decision rule after the 1-seed smoke test, before the grid, and said so in
  the script.** The first draft read "stayed" as `frob ≤ 2`; seed 2001 showed that conflates
  "stayed at truth" with "did not run away". Changed to `|frob − 1| ≤ 0.25`. The change is
  about operationalising a word, not about the direction of the answer, and it was made on
  one seed with the grid unrun.
- **Did not implement the fix.** Ungating the start selection changes fitted results for
  every `aghq_ridge = Inf` fit. The handover fences this lane to evidence, and CLAUDE.md
  routes behaviour changes to the maintainer.
- **Compute: local, 4 cores, not Totoro.** 120 fits × ~26 s ≈ 25 min; a TMB toolchain build
  on Totoro costs more than the whole job. Host was already carrying other lanes (load ~93),
  hence 4 cores and not 20.

## 4. Files Touched

| file | change |
|---|---|
| `R/fit-multi.R` | +12 lines: the `aghq_start_par` diagnostic hook (inert by construction) |
| `dev/aghq-evidence/22-truthstart-shipped.R` | new |
| `dev/aghq-evidence/23-altstart-shipped.R` | new |
| `dev/aghq-evidence/sweep-control-fields.R` | new |
| `dev/aghq-evidence/22-truthstart.csv`, `23-altstart.csv` (+ `-inc`, `.log`) | new results, LOCAL |
| `docs/dev-log/audits/2026-07-31-aghq-truthstart-shipped-engine.md` | new |
| `docs/dev-log/after-task/2026-07-31-aghq-truthstart-843.md` | this file |

No user-facing surface, no export, no NEWS, no default changed.

## 5. Checks Run

- `R CMD INSTALL` from `main`: **EXIT=0**.
- `test-aghq-control-wiring.R`, `test-aghq-surface.R`, `test-aghq-golden.R`:
  **75 assertions, 0 failures, 0 errors** (5 skips, pre-existing) against the patched source.
- Three pre-flight assertions, run before any campaign fit:
  LQ rotation preserves Σ (`max|ΔΣ| = 3.55e-15`); rotated Λ lower-triangular (`0`);
  **the C++ template round-trips my truth→packed mapping (`max|ΔΛ| = 0`)**.
- 120 shipped-engine fits, 0 failures.

## 6. Tests of the Tests

The pre-flight is the test of the instrument, and the third assertion is the load-bearing
one: it reads `Lambda_B` back out of the **engine's own report** after writing my packed
vector in, so it is the C++ template — not my arithmetic — that certifies the map. Without
it, a packing error would have produced a confident, wrong "truth start".

Two further self-checks fell out of the design: `frob_rat_true_start` is recorded per seed
and is 1.000 by construction (a non-1 value would mean the rotation was wrong), and
`d_par_max` measures whether the two arms converged to the same point rather than inferring
it from a summary. `d_par_max` median 10.5 confirmed they did **not** — which is what makes
the objective comparison meaningful.

The `aghq_multistart` defect was confirmed **by execution**, not by reading: the warning
fires and the field is `NULL`.

## 7a. Issue Ledger

- **#843 — ANSWERED, ready to close on the maintainer's decision.** Its suggested resolution
  branch 2 fires: enable the alternative start under `aghq_ridge = Inf` and re-run the
  affected arms. Evidence posted to the issue.
- **NEW — `aghq_multistart` is unreachable** (`R/fit-multi.R:5308` reads it;
  `gllvmTMBcontrol()` never produces it). Same class as D2/#844. Filed.
- **#842** — its §3 mechanism story and §6 small-n table need the single-start caveat.
- **#847 / #848** — untouched (D3/D4, ridge τ and disclosure). Noted below where this slice
  bears on #847.

## 8. Consistency Audit

Applying the Rose principle to the defect class found (`control$X` read but never produced),
I swept all of `R/` (`sweep-control-fields.R`). 18 raw hits; after filtering false positives
(`screen-gllvmTMB.R` uses a separate `screen_control()` constructor; `va-r3-proto.R:716`
uses a local optimiser control) the genuine set in `fit-multi.R` is:

- `aghq_multistart` — **real defect**, and it mislabels `19-warmstart-vs-flatness.R`'s arm.
- `vgh_warm_start*` (4 fields) — **not** a defect. Reached deliberately by hand-built control
  lists in `dev/vgh/*.R`; documented as an internal opt-in. My initial suspicion was wrong
  and is recorded as wrong. (Also Codex's lane — read-only here, untouched.)
- `aghq_start_par` — mine, by the same intentional pattern.

Walking the neighbourhood also turned up a second problem I did not go looking for: the
`MEASURED (Totoro, 954 fits)` table at `R/fit-multi.R:4997-5010` that justifies the ridge's
τ = 2 comes from the invalidated `dev/aghq-r-reference.R` (`decisions.md:1625` names it;
`:1706-1709` supersedes it), **and its headline is contradicted in direction by the shipped
engine** — it tells a maintainer "LAPLACE runs away MORE than AGHQ (50% vs 13%)" where
`18-shipped.csv` measured laplace 47% / aghq 73%. Recorded in the audit; relevant to #847.

## 9. What Did Not Go Smoothly

- The handover named in the task **did not exist in the working tree** — it was on
  `origin/main`, and the checkout was 40+ commits behind on an unrelated branch. Reading it
  required `git show origin/main:…`. Anyone resuming should fetch first.
- Two designs were built and discarded before the workable one (see §3a). The `optArgs`
  route in particular *looked* zero-patch and would have silently produced a null result;
  it was caught by reading the merge order in `run_one()`, not by running it.
- The 1-seed smoke test invalidated my own pre-registered threshold. That is the smoke test
  working, but it means the first pre-registration was wrong and had to be amended in the
  open.

## 10. Known Residuals

- **Scope is one cell.** n = 100, p = 6, q = 2, binomial, lam_sd = 1.0, `aghq = 9`,
  non-default grammar. Nothing here extends to n ≥ 400, other families, other q, or the
  default grammar.
- **This says where the optimiser lands, not whether the argmin is good.** The AGHQ
  estimator remains unestablished — that is the lane's main campaign, not this slice.
- **Residual moderate runaway is unexplained.** Best-of-both only moves runaway 65% → 52%,
  and the truth start itself sits at 48%. Multi-start fixes the catastrophic tail; whatever
  drives the rest is a separate question.
- **Weak counter-signal, reported as weak:** on 2/40 seeds the better objective belongs to
  the *worse* Λ̂ — genuine estimator bias coexisting with the optimiser failure. 2/40 is not
  a finding.
- **The hook ships in this branch.** Inert and tested, but it is a source change; if the
  maintainer prefers it out, the two scripts become non-runnable and should be reverted with it.

## 11. Team Learning

- **"Shipped engine" is a claim about the binary, not the repo.** The installed package was
  13 days stale. A campaign labelled shipped-engine that runs against a stale install is the
  same defect as one that runs against a reimplementation — check the build date, not just
  the branch.
- **A withdrawn justification is not a wrong conclusion, and the difference is worth
  measuring.** #843 was careful to say the design *might* still be right. It was not — but
  only measurement could tell, and the measurement was cheap (25 min, local).
- **When a control is read but never produced, the harness lies quietly.** Three instances
  now in this one file (six fixed earlier, `aghq_multistart` today, and #844's cousin). The
  sweep is one script; it should probably become a test.

## 12. Cross-Product Coverage

Not applicable to sister packages — the AGHQ Stage 1a path is gllvmTMB-only. The *class*
defect (a `control$X` read but never produced by the control constructor) is worth a
one-line check in any package with a `*control()` constructor, drmTMB included; the sweep
script generalises with a changed constructor name.

**Memory receipt.** Loaded from `CLAUDE.md`: the capability-widget step-0 rule (done first),
the lane-split / no-cross-lane-claim rule (checked: no open PRs, no foreign lane; Codex's
VA/VGH lane read-only and untouched), the merge-authority split (this is dev-log + audit =
low-risk, but the *fix* it recommends is not, so it was not made), and D-50 (results local,
never Actions artifacts). From the hub: the Rose principle (drove §8, which found the second
in-source problem), evidence-before-assertion, and "state what the arc does NOT cover" (§10).
I did **not** query the brain MCP — the question was entirely repo-local and the repo is
ground truth for it; the handover, the audit and the live issues were the sources.
