# After-task — the Σ-interval arc: premise collapse, and three machinery fixes

Date 2026-07-28 · Platform **Claude Code** · Lane `claude/sigma-intervals-boundary-20260728`
(off `main` @ `da7ee99e`) · 12 commits, **unpushed**.

## 1. Goal

Refine, then execute, the next-arc ultra-plan: correct gllvmTMB's profile boundary reference
package-wide, extend the profile route to low-rank Σ, re-certify the Gaussian `Sigma_unit`
diagonal cell at n_sim ≥ 2000, then wire multinomial.

**Outcome: the goal was not achieved and cannot be, as written.** Three of its four deliverables
were shown to rest on false premises; the fourth was deferred by the plan's own pre-registered
gate. What the arc produced instead is the disproof, plus three fixes to the machinery that the
disproof exposed.

## 2. Implemented

**Refined the ultra-plan** (`docs/dev-log/2026-07-28-next-arc-sigma-intervals-ULTRAPLAN.md`):
full GOAL block, sweep receipt, 16-slice table with member · model · effort · dispatch · time ·
dep, five legal checkpoints, compute target, risk branches.

**Merged H0** — `claude/aghq-family-axis-20260728` into `main` (`869e92b5`), resolving the
`decisions.md` conflict by keeping both append streams. Verified 0 lines lost from either side.

**Three fixes, each written test-first and confirmed failing on the unfixed tree:**

| commit | fix |
|---|---|
| `e34176eb` | `.profile_ytol(level)` couples the profile search budget to `level`. `ytol` was hard-coded to 2 while `crit = qchisq(level,1)/2` reaches 2.0 at level 0.9545 |
| `fde628bf` | `.ci_covers()` refuses to credit a non-finite bound. `is.na(-Inf)` is `FALSE`, so `(−Inf, Inf)` was scoring as a successful cover |
| `26ac8301` | `.profile_terminus_status()` separates an **asymptotic** profile (±Inf honest) from a **truncated** one (bound unknown → `NA`) |

They are one defect in three places: **the instrument reporting a definite answer where it had
failed to measure.** One manufactured infinite bounds, one credited them, one asserted them.

## 3a. Decisions and Rejected Alternatives

- **Rejected: build the boundary-detecting reference.** Two independent disproofs (§9).
- **Rejected: change `.tmbprofile_curve_grid()`** despite the same hard-coded `ytol = 2`. It is
  internal, takes no `level`, and feeds a plotting path whose cutoff uses the *unhalved* `qchisq`
  — a convention not verified. A truncated curve is visible; a truncated bound is silent.
- **Rejected: fence the low-rank route / change `bootstrap_Sigma()` warnings.** User-facing
  behaviour changes; CLAUDE.md puts these in the ask-first set, and the arc premise they would
  rest on is not re-approved.
- **Chose: `crit + margin`, not `crit`,** for the search budget — measured, not assumed (§5).
- **Chose: treat "undecidable" terminus as truncated** — "unknown" is the safe answer.
- **Chose: adjudication scale (2000 seeds) over pilot** for the Totoro campaign, since the run
  is meant to settle S3's finding rather than sketch it.

## 4. Files Touched

Created — `R/`: none. `tests/testthat/`: `test-profile-ci-level-budget.R`,
`test-coverage-study-nonfinite.R`, `test-profile-bounds-terminus.R`.
`docs/dev-log/`: `2026-07-28-S0-codex-review-recovered.md`,
`2026-07-28-S3-stall-rootcause.md`, `2026-07-28-S4b-profile-route-findings.md`, this report.
`dev/aghq-evidence/23-flat-regime-campaign.R`.

Modified — `R/profile-ci.R` (`.profile_ytol`, `.profile_terminus_status`, `.profile_bounds`
status fields, boundary roxygen), `R/confint-inspect.R` (`ytol` default + roxygen),
`R/coverage-study.R` (`.ci_covers`, `n_excl`),
`docs/dev-log/2026-07-28-next-arc-sigma-intervals-ULTRAPLAN.md`,
`man/` (regenerated: `confint_inspect.Rd`, `tmbprofile_wrapper.Rd`, plus pre-existing drift in
`gllvmTMBcontrol.Rd` and new `dot-aghq_gate.Rd`).

`main` via merge — `dev/aghq-evidence/19-*`, `20-*`, `docs/dev-log/decisions.md`.

## 5. Checks Run

- `testthat::test_file()` on 10 profile/coverage files → **104 passed, 0 failed, 0 errors,
  99 skipped.** The skip count is high; this is partial regression coverage, not a clean bill.
- Each new test file confirmed **failing/erroring before** its fix.
- Empirical bug reproduction, n=120 4-trait Gaussian: level 0.80/0.90/0.95 → 10/10 bounds
  finite; **level 0.99 → 6/10**.
- Mechanism isolation, varying only `ytol` at crit(0.99)=3.3174: `ytol=2` → 0/4 finite;
  `ytol=3` → **still 0/4** (clears crit but cannot bracket); `ytol=4` → 4/4.
- Merge safety: 0 lines removed vs `origin/main`, 0 family-axis lines missing, 0 markers left.
- Line-reference audit: all 15 file:line citations in the plan re-grepped and matching.
- Totoro smoke: 32/32 cells, 0 errors, 0 NA; `eta_cap` arm proven non-vacuous
  (`frac_capped` 0.0475, `eta_max` 15.2 at `lam_sd` 3).

## 6. Tests of the Tests

Every one of the three test files was run against the unfixed tree first and observed to fail:
`test-profile-ci-level-budget.R` errored on the missing `.profile_ytol`;
`test-coverage-study-nonfinite.R` errored 2 / passed 1 (the one pass is a pure-arithmetic
exclusion-rule check needing no helper); `test-profile-bounds-terminus.R` was written against
behaviour that did not exist. The terminus tests use **synthetic traces**, so they are
deterministic and exercise the decision rule directly rather than through a fit.

## 7a. Issue Ledger

Open, unscheduled: `aghq = "auto"` routing is dead code (`.aghq_auto_decide()` has no call site);
six `aghq_*` continuation controls are read by the engine but are not `gllvmTMBcontrol()`
arguments; `man/gllvmTMBcontrol.Rd` codoc mismatch from #801 (fixed here as a side effect);
C++ does not validate `aghq_n_node > 0`.

## 8. Consistency Audit

Swept for the same defect class elsewhere. `.qchisq_threshold` has **4** callers (verified);
`.qt_threshold` has a live caller at `profile-derived.R:1387`. **8** χ² LR-reference sites exist,
not the 6 the plan assumed — the eighth, `suggest-lambda-constraint.R:365`, tests **H0: Λ = 0**
and its boundary status is genuinely ambiguous. Exactly **2** bootstrap-fallback route rows
(`:629`, `:636`), so S6 was correctly scoped at two tiers. One further `ytol = 2` site found and
deliberately left (§3a).

## 9. What Did Not Go Smoothly

**The arc's premise collapsed in four stages, each disproving the previous plan:**

1. **S4b** — boundary *detection* is unimplementable: `tmbprofile()`'s inner refit is
   unconstrained, its convergence status discarded, no `parm.range` imposed, and log-SD puts
   SD = 0 at −∞ so there is no finite boundary to detect.
2. **S2** — the correction **points the wrong way**. χ̄²'s 95% crit is **2.706** vs χ²₁'s
   **3.841**, so the mixture *narrows* intervals and *lowers* coverage. Our defect is
   under-coverage. χ²₁ at a boundary is the conservative choice.
3. **The certificate does not exist.** `after-task/2026-07-17-sigma-coverage-nsim5000-confirm.md`
   reads **"Disposition: WITHHELD"**; d2-n150 **fails on rorqual** (0.9462, band 0.9398).
   `decisions.md:2130-2135` overstates it as "the one coverage-certified cell", and I repeated
   that overstatement in every summary until a panel caught it. **This is the arc's own
   documented failure mode, committed by me: a claim restated more strongly than its evidence,
   and the restatement never checked against the source.**

   **🔴 Addendum, 2026-07-29 (evidence-gap slice A1) — the correction above has the same shape as
   the error it corrects.** `nsim5000-confirm.md` is one of *two* same-day 2026-07-17 records. A
   second, later panel pooled its reps with a disjoint fresh-seed batch to N≈15k and returned
   **BOTH cells CERTIFY, 3-0** against the same 0.94 gate
   (`dd80244a:docs/dev-log/2026-07-17-sigma-coverage-d43-panel.md`, unmerged for 12 days; quoted
   with provenance in the reconciliation note below, and deliberately NOT ported to `main` per
   R-5). "The certificate does not exist" is therefore also a claim restated more
   strongly than the full evidence supports — it is accurate that no LIVE, reproducible certificate
   exists today (the CERTIFY panel's raw is gone), but the 0.94 gate was met once. See
   `docs/dev-log/2026-07-29-certificate-record-reconciliation.md`.
4. **S3** fired the pre-registered risk branch, deferring multinomial.

Also: I dispatched S4b with a read-only agent type, so it could not write its own artifact and
correctly refused to fake one — dispatch error, recovered by hand. A scout returned confidently
**wrong line numbers** (1877/1879 and 520–532 against actual 1387/1389 and 629/636) with correct
content, and a reframing panel over-claimed "±Inf for every parameter, always" where the truth is
level-dependent degradation. Both were caught by re-verification, which is the only reason they
are not in the record as facts.

## 10. Known Residuals

- **Totoro campaign running**, ~7% at close, 150 cores, ~5h remaining. `~/h4_work/regime.csv`
  (authoritative combine) and `regime-inc.csv` (crash insurance). Results stay **local, D-50**.
- **S2's Q4 hazard is untested**: the literature says too few quadrature nodes flatten the
  likelihood in covariance parameters with spuriously *exactly zero* SDs. The campaign's
  `aghq_k ∈ {9,25,51}` arm answers it; **S3's verdict (C) is provisional until it returns.**
- **We are not first** — SAS PROC GLIMMIX `COVTEST … CL / TYPE=PLR` profiles `FA(q)`/`FA0(q)`,
  tracing to Jennrich & Schluchter (1986). Any "first to profile a low-rank covariance" wording
  is false.
- **Two decisions pending**: the (A)/(B) certificate fork, and whether to push this lane.
- The `.profile_terminus_status` slope-ratio tolerance (0.1) is a **chosen constant**, not a
  calibrated one. It has no coverage evidence behind it.

## 11. Team Learning

**A result that confirms your prediction is where the mechanism check is most needed.** This arc
inherited that lesson in writing and still broke it — the "certified cell" was quoted all session
because it appeared in a summary, and the summary agreed with what the plan wanted to be true.
**Check the primary source, not the sentence that cites it.**

Second: **an agent's confident file:line is not evidence.** Three separate agent outputs this
session contained verifiable errors alongside correct substance. Verification cost minutes; each
would have entered the durable record as fact.

## 12. Cross-Product Coverage

The `.ci_covers` defect class — a scoring predicate that credits an uncomputable result — is
worth checking in **drmTMB** and **hsquared**, which run analogous coverage harnesses. The
`is.na()`-not-`is.finite()` guard is an easy shape to repeat. Not checked here; flagged.
