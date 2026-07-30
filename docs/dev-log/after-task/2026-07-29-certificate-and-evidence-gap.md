# After-task — the first certified interval, and four instruments that lied

## 1. Goal

Close the gap between gllvmTMB's model surface and its evidence surface, without widening the model
surface. Three steps in priority order: certify one interval (zero existed); exercise AGHQ beyond
three families or fence it; explain why binomial never stalls.

## 2. Implemented

**Certificate (delivered).** Ported the `Sigma_unit` total-variance profile harness, pre-registered a
`coverage >= 0.94` gate before launch, ran two 20,000-replicate campaigns on Totoro, and put each
through a three-lens D-43 panel.

- **v1: WITHHELD 2-1.** Met the gate arithmetically (bands 0.9447 / 0.9433) but 15,000 of its 20,000
  reps were byte-identical datasets to the historical run.
- **v2: CERTIFY 3-0.** Fresh seeds (reps 20001-40000), disjointness verified from recorded seeds
  before launch. gaussian d1-n150 coverage 0.9467169 (band 0.9434896), d2-n150 0.9467216 (band
  0.9435366).

**Four instrument defects found; three fixed, one claim withdrawn.**

| defect | disposition |
|---|---|
| `m3_summarise` reported `n_failed = 0` while 607 fits failed | fixed (`836480a9`) |
| campaign counted 1 of 3 stall states while labelling it "stall rate" | wording corrected on `main` |
| `19-family-axis.R` "Gamma crash" was a caught link error | diagnosed; real harness never broken |
| my own pre-registered seed clause, written and never implemented | caused v1's withhold; fixed in v2 |

**Record reconciliation.** Three primary certificate documents live only on parked branches, so
`main` carried a stale premise. Six same-class sites corrected; the 15k CERTIFY panel quoted with
provenance rather than ported, honouring R-5's fence on that branch estate.

**Register, not NEWS** (maintainer decision): `CI-08` carries the evidence, status stays `partial`.

## 3a. Decisions and Rejected Alternatives

- **Gate 0.94, not 0.95.** Maintainer decision. Bartlett had already been shown a negative result at
  0.95, and both cells sit ~3.3 clustered SEs below nominal.
- **Re-run rather than land the 15k as-is.** The 15k raw was gone from Totoro; a summary that cannot
  be reproduced is not evidence.
- **Quote the 15k panel, do not port it.** R-5 fences that branch estate; quoting makes the evidence
  visible on `main` without importing from it. *Rejected:* porting the file verbatim (touches the
  fenced estate), and skipping reconciliation (the next session would re-derive it).
- **`n_boot = 10` against a default of 100.** Measured 62s vs >120s for the same 2 reps. Bootstrap is
  emitted as separate `ci_method` rows and is the wrong route for this estimand, so it cannot move a
  `profile_total` value. Recorded in a separate run record, since the pre-registration is immutable.
- **Fixed the failing test, not the code.** `n_boot = NA` is honest on a profile row; changing the
  code would have altered the harness that produced the certified result. *Rejected:* setting
  `n_boot = 0`, which would imply a bootstrap that ran and drew nothing.
- **Export design deferred, not improvised.** The route accepts five tiers; the certificate covers
  one. Recommended per-row `interval_status` labelling (the package's existing idiom). *Rejected:* a
  narrowed erroring wrapper (paternalistic) and prose-only fencing (does not survive restatement).
- **Status stays `partial`.** Recording evidence is not flipping a capability.

## 4. Files Touched

`dev/m3-grid.R` (+`n_attempted`, `n_failed` fix) · `dev/profile-rescore-run.R` ·
`dev/totoro-profile-rescore.sh` (filter passthrough) · `R/profile-derived.R` (+301, additive) ·
`dev/aghq-families/family_spec.R` (comment) · `tests/testthat/test-m3-pilot-report.R` ·
`docs/design/35-validation-debt-register.md` (CI-08 addendum) ·
`docs/dev-log/2026-07-29-{certificate-gate-preregistration,-v2,certificate-run-record,-v2,certificate-record-reconciliation,certificate-disposition,binomial-stall-interrogation,aghq-family-harness-audit,family-axis-campaign-design}.md` ·
`docs/dev-log/2026-07-29-flat-regime-campaign-results.md` (wording) · 6 addendum sites ·
`docs/dev-log/handover/2026-07-30-claude-handover-export-profile-route.md`

**Not touched, deliberately:** `NEWS.md`, `capability-surface.html`, `NAMESPACE`, `man/`, and every
LANE 2 VA/EVA file.

## 5. Checks Run

- `R CMD check` via CI on PR #822: **pass** (21m) after the test fix; the first run failed on one test
  and was diagnosed before any change.
- Heavy tests explicitly, because CI skips them: `GLLVMTMB_HEAVY_TESTS=1` →
  `test-m3-pilot-report.R` 0 failed / 41 passed, `test-m3-grid-summary.R` 0 failed / 79 passed.
- Parse check across all 84 `R/` files after the port.
- Smoke before each campaign, reading values past the guards (`truth` finite, `covered` /
  `converged` / `ci_available` populated, zero NAs) — not row counts.
- Seed disjointness verified from recorded `rep_seed` before the v2 launch.
- Re-aggregated the existing campaign to prove the `n_failed` fix: `profile_total` and `bootstrap`
  now report the same 607/134 from different subsets.

## 6. Tests of the Tests

The replacement assertion in `test-m3-pilot-report.R` is strictly stronger than the one it replaces:
it asserts the **route** (`ci_method == "profile_total"`) as well as the counts, so a silent re-route
back to bootstrap or none now fails. The original single `n_boot` assertion could not have caught
that.

The `n_failed` fix has a genuine cross-check rather than a self-consistent one: the value is computed
in two subsets that see different data — `bootstrap` sees all 20,000 reps, `profile_total` only the
converged — and both must agree.

## 7a. Issue Ledger

No issues opened or closed. PR #822 (certificate evidence) and #828 (register + handover) merged.
PRs #810 and #812 were merged by the maintainer during the session.

## 8. Consistency Audit

Swept for each defect's class rather than fixing only the reported instance.

- **`stop_reason` parsing:** exactly one site (`23-flat-regime-campaign.R:108`). Shipped `R/` only
  *writes* `stop_reason`, never parses it — no user-facing defect. `R/fit-multi.R` already carries a
  "A SILENT NO-OP IS A RESULT THE USER MUST BE TOLD ABOUT" guard.
- **Base-R constructor default vs required link:** all 16 specs checked; Gamma was the only mismatch,
  because gllvmTMB-native constructors default to the link their own check demands.
- **Certificate-status statements:** 6 same-class sites (1 overstated, 5 understated). `NEWS.md`,
  `confint()` roxygen and `capability-surface.html` checked and found accurate; left untouched.
- **Tests exposed to the `m3_summarise` change:** 2 files; the second is heavy-gated and invisible to
  CI, so it was run explicitly.

## 9. What Did Not Go Smoothly

**I wrote a pre-registration clause and did not implement it.** "No reuse of a previous seed window",
then no `--seed-base` and no rep window — so `rep_seed`, a function of the rep *index*, silently
re-scored 15,000 historical datasets. I had built the `REPSTART` passthrough that would have
prevented it, in the same commit as the pre-registration. The close agreement with history, which I
reported as strong confirmation, was the **symptom**. Cost: one 3-hour campaign and a withheld panel.

**I reported two things as fact that were not.** That the 5k WITHHELD doc was on `main` (none of the
three primary docs is), and that H3 "inverts" (withheld 2-1 on two independent grounds). Both were
corrected in the record rather than quietly dropped.

**My first diagnosis of the CI failure was wrong** — I read it as reverting main's `dev/m3-grid.R`;
main's copy is an ancestor, so nothing was reverted. Checking beat the plausible story.

## 10. Known Residuals

- **`rep_seed` is non-injective across `d`** (`+ 1000L * d`): the two certified cells share 19,000 of
  20,000 seeds, so "both cells clear" is ~1.1 cells of corroboration. **Must be offset before any
  cell is added.**
- **`wald_t_logsd` d2 accounting gap:** `n_reps` 19,888 against coverage over 19,730 reps' rows. The
  certificate row is clean; this diagnostic row is the same defect class.
- **The certified route is unexported.** The evidence surface moved; the capability surface did not.
- **Half B unfunded:** the family-axis campaign is designed, cost unestimated until smoked.
- **Three naming/export conventions** coexist in `R/profile-derived.R`; not touched.
- Raw retained on Totoro (D-50): `run20k-20260729` and `run20k-v2-20260729` (180 shards each),
  `~/h4_work/regime.csv` (113 MB). **Do not delete** — v1's raw is the evidence for the seed-reuse
  finding.

## 11. Team Learning

**One defect class produced four instances in one day: an instrument reporting a definite answer
where it had failed to measure.** `n_failed = 0` against 607 failures; a regex counting one of three
stall states; a "crash" that was a caught error whose CSV write sat inside the success branch; and a
pre-registration clause asserted rather than verified. In every case the *number* was correct and the
*scope it claimed* was not.

The practical rule: **a failure that emits no row is invisible, and a count computed inside the subset
that excludes failures will always read zero.** Check the denominator, not just the estimate.

**The adversarial panels paid for themselves twice** — they withheld a claim already reported as fact,
and caught seed reuse that would otherwise have entered the register. A self-check would not have
found either; both required a different agent with a different lens.

## 12. Cross-Product Coverage — the negative space

This arc covers exactly one cell family: gaussian × diagonal `Sigma_unit` × `tier = "unit"` × d ≤ 2 × n ≥ 150, on the internal `profile_total` route, two-sided, at a 0.94 floor. It **does NOT cover**: binomial (fenced, ψ=0 boundary);
`n_units = 50` and everything between 50 and 150; every family other than gaussian; off-diagonal
`Sigma_unit` and all correlations; **the ψ target, which fails on this same run** (0.9384 d1, 0.8653
d2); `phylo_*` / `spatial_*` / `animal_*` / `kernel_*` / `meta_V` tiers; nominal 0.95; one-sided
intervals and any test of `V_t = 0`; `d > 2`; every exported interval route; the small-`V_t`
sub-regime; non-converged fits; and any real dataset — this is one DGP.
