# Handover to Cursor — VA(GH) H = 7 Arc 2 is complete; diagnose the mixed result

**Author:** Codex · **Target:** Cursor, fresh agent with no chat inherited

**Date:** 2026-08-07

**Branch:** `codex/va-gh-all-families` (Arc-2 closeout before this handover:
`7bf56c4a`)

**Worktree:** `/private/tmp/gllvmtmb-va-gh-all-families`

**Platform / lane:** Codex handing one bounded VA(GH) diagnostic lane to Cursor;
the repository remains multi-lane.

> Cursor: the committed repository is authoritative. First reconcile this file
> with `git`, then classify every item below as **OWED**, **DONE**, **RETRACTED**,
> or **PROTECTED**. Continue only the OWED diagnosis. This handover does not
> authorise a fence change, another campaign, a merge, or a release.

---

## 0. First — rehydrate and check ownership

```sh
cd /private/tmp/gllvmtmb-va-gh-all-families
bash /Users/z3437171/Dropbox/Github\ Local/Shinichi/tools/lane_preflight.sh \
  /private/tmp/gllvmtmb-va-gh-all-families
git status --short --branch
git log --oneline --decorate -8
git log --all --oneline --since="6 hours ago"
git diff --stat origin/main...HEAD
export NOT_CRAN=true
```

Read, in order:

1. `AGENTS.md` and the multi-lane warning at the top of `CLAUDE.md`;
2. `docs/design/110-va-gh-h7-all-scalar-families.md`;
3. `docs/dev-log/audits/2026-08-07-va-gh-h7-arc2-totoro-adjudication.md`;
4. `docs/dev-log/audits/2026-08-07-va-gh-h7-arc2-totoro-adjudication.csv`;
5. `docs/dev-log/after-task/2026-08-07-va-gh-h7-arc2-totoro-closeout.md`;
6. the VA-06, VA-09, VA-12, and VA-13 rows in
   `docs/design/35-validation-debt-register.md`.

The repository's `CLAUDE.md` snapshot is intentionally not repointed to this
handover: it declares a multi-lane repository and directs every agent through
`docs/dev-log/handover/2026-07-25-active-lane-split.md`. Do not replace that
one-to-many routing with a single-lane pointer.

## 1. Mission and current boundary

Arc 1 implemented and light-gated public GH H = 7 routing for 18 admitted
scalar family/link cells. Arc 2 has now completed the exact frozen confirmation
on Totoro. The next useful question is narrower: **why did 24 of 36 independent
family-by-rank point routes fail and 11 remain inconclusive, and what
cell-specific public-admission decision does that evidence support?**

The next lane is diagnosis and decision preparation only. It must not change
the estimator, fixture, thresholds, public family fence, TMB likelihood
template, JJ route, multinomial boundary, or non-scalar scope. Any code or
fence mutation requires a separate maintainer decision after the diagnostic
packet is reviewed.

## 2. Critical result — complete execution is not an accuracy pass

The Totoro confirmation ended at `2026-08-07T05:15:58Z` with a `COMPLETE`
exit receipt, exit code 0, and exactly **36,000 verified bundles for 36,000
planned rows**. The pre-existing H ladder contributed a separate 5,520-row
export. The clean adjudicator used 5,000 paired-bootstrap replicates and
returned 36 non-pooled family-by-rank verdicts:

| outcome | result |
| --- | ---: |
| Overall point route | **1 PASS, 24 FAIL, 11 INCONCLUSIVE** |
| Reliability | 20 PASS, 15 FAIL, 1 INCONCLUSIVE |
| H = 7 / H = 61 stability | 16 PASS, 12 INCONCLUSIVE, 8 NOT_APPLICABLE |
| Fixed-effect beta-Wald calibration | 20 CALIBRATED, 16 UNCALIBRATED |
| Latent posterior-SD calibration | 15 CALIBRATED, 20 UNCALIBRATED, 1 INCONCLUSIVE |

The only overall point-route pass was `poisson_log`, q = 5. Completeness passed
for every cell, but completeness is only operational evidence. It does not
rescue failed or inconclusive recovery.

Both the H ladder and confirmation ran on Totoro. The final receipt therefore
records:

```text
h_ladder_platform=Totoro
confirmation_platform=Totoro
cross_platform=FALSE
```

Fir stopped after 10,549 valid partial bundles because of project file quota;
Narval failed its transferred dependency runtime before producing a campaign
bundle. Neither contributes a row to the 36,000 denominator. The old Narval
lane and the completed H-ladder evidence stay separate.

## 3. Classification ledger

### DONE

- Arc 0 generalised the launcher and receipts from DRAC-specific confirmation
  language to role-neutral confirmation vocabulary, records Totoro honestly,
  and protects the exact frozen 36,000-row plan.
- The sequential native-runtime, checksum, preflight, one-row smoke, and
  separate 100-row sentinel gates passed before the full launch.
- The 36,000-row Totoro confirmation completed with retained failures and no
  smoke/sentinel contamination of the denominator.
- The H ladder and confirmation were exported separately with checksum-bound
  provenance; all 36 cells were adjudicated independently.
- The adjudication, Design 110, validation debt, NEWS, capability surface,
  check log, after-task report, and Mission Control were reconciled.
- Focused campaign tests passed; `pkgdown::check_pkgdown()`, HTML parsing, and
  `git diff --check` passed at the closeout commit.
- The action-capable heartbeat `va-gh-h7-totoro-arc-2-monitor` completed and
  was removed after final closeout.

### OWED

1. Reconcile this handover with live branch, upstream, PR, and lane state, then
   explicitly record the four-way classification before any analysis.
2. Use the retained 74-column adjudication and its bound input manifests to
   separate the failure mechanisms at each family/rank cell. At minimum,
   distinguish infrastructure/reliability failure, paired-route eligibility
   shortfall, beta RMSE failure, covariance RMSE-ratio failure, absolute beta
   RMSE failure, relative covariance-Frobenius failure, calibration failure,
   and H-stability non-eligibility.
3. Produce a read-only diagnostic decision table with one row per family and
   rank: observed driver(s), exact evidence columns, whether the signal is
   estimator-specific or shared with matched Laplace, uncertainty/eligibility
   limitations, and a recommendation of **retain**, **narrow**, or
   **investigate** for later maintainer consideration.
4. State explicitly what the diagnosis does not establish: cross-platform
   replication, q >= 3, structured covariance tiers, random slopes,
   mixed-family recovery, multinomial VA, raw-loading/covariance intervals, or
   frequentist calibration of latent posterior SDs.
5. Stop and ask the maintainer before changing code, a public fence, a default,
   a threshold, or the campaign design.

### RETRACTED

- Any package-wide claim that H = 7 VA is accurate across the 18 scalar cells.
- Any interpretation of 36,000/36,000 completeness as 36/36 statistical PASS.
- Any claim that this is independent cross-platform confirmation.
- Any attempt to pool cells, reinterpret INCONCLUSIVE as PASS, weaken a frozen
  threshold, or rerun the same campaign until the result looks favourable.

### PROTECTED

- The exact estimator and quadrature route, n = 120, p = 8, q in {2, 5}, 500
  seeds, matched Laplace arm, 5,000 bootstrap replicates, fixtures, and frozen
  thresholds.
- The 36 independent cell-by-rank adjudications and all retained failures.
- The unchanged public fence and `calibrated = FALSE` uncertainty boundary.
- The TMB likelihood template, public family grammar/fences, JJ,
  multinomial/coupled-softmax boundary, and every non-scalar regime.
- The completed H-ladder evidence, the failed Fir/Narval histories, and the
  Totoro confirmation as distinct provenance roles.
- Other repository lanes, dirty worktrees, unpushed branches, and their named
  owners in the active-lane map.

## 4. Evidence and provenance

The compact, committed 36-row evidence lives at:

- `docs/dev-log/audits/2026-08-07-va-gh-h7-arc2-totoro-adjudication.csv`;
- `docs/dev-log/audits/2026-08-07-va-gh-h7-arc2-totoro-adjudication.dcf`;
- `docs/dev-log/audits/2026-08-07-va-gh-h7-arc2-totoro-adjudication.md`.

The full local evidence copy is outside git at:

```text
/private/tmp/va-gh-h7-final-evidence/totoro/
```

The 74-column adjudication is:

```text
/private/tmp/va-gh-h7-final-evidence/totoro/adjudication/
va-gh-h7-adjudication-totoro-022b4eab.csv
```

Its full-verdict MD5 is `e57f8460fd98bd0eac43b4a6c014317d`.
The durable remote roots are:

```text
confirmation: /home/snakagaw/gllvm_work/va-gh-h7-totoro-confirmation-022b4eab-20260806
H ladder:     /home/snakagaw/gllvm_work/va-gh-h7-campaign-ac45e50f
```

If the `/private/tmp` copy is absent, recover the exact retained files from
those roots through an already-live Totoro ControlMaster socket. Do not open a
new login, recreate the campaign, or substitute a differently generated CSV.
Verify checksums against the committed DCF before analysis.

The raw evidence stays outside git under D-50. **Never stage the evidence
directory or move campaign outputs into GitHub Actions artifacts.**

## 5. Frozen adjudication rules

Do not weaken or pool these rules:

- exact completeness;
- Wilson reliability upper <= 0.10;
- VA/Laplace beta and covariance RMSE ratio upper <= 1.25;
- beta RMSE < 0.35;
- relative covariance Frobenius < 0.50;
- existing H7/H61 upper <= 1.10;
- beta-Wald and latent-SD calibration in [0.90, 0.99].

An H-stability PASS does not override failed recovery. Calibration labels are
separate from the point route. A variational posterior SD is not a frequentist
random-effect standard error.

## 6. Files changed in Arc 2

Relative to the approved Arc-2 start at
`5fd58c33c9c3d1ce3ad4932fb04d57b28659f238`, the completed branch changes:

- `NEWS.md`;
- `dev/va-gh-h7-campaign/launch-totoro-confirmation.sh`;
- `dev/va-gh-h7-campaign/run-cell.R`;
- `docs/design/110-va-gh-h7-all-scalar-families.md`;
- `docs/design/35-validation-debt-register.md`;
- `docs/dev-log/after-task/2026-08-07-va-gh-h7-arc2-totoro-closeout.md`;
- `docs/dev-log/audits/2026-08-07-va-gh-h7-arc2-totoro-adjudication.csv`;
- `docs/dev-log/audits/2026-08-07-va-gh-h7-arc2-totoro-adjudication.dcf`;
- `docs/dev-log/audits/2026-08-07-va-gh-h7-arc2-totoro-adjudication.md`;
- `docs/dev-log/capability-surface.html`;
- `docs/dev-log/check-log.md`;
- `docs/dev-log/recovery-checkpoints/2026-08-06-202438-codex-arc2-totoro-confirmation-launch.md`;
- `tests/testthat/test-va-gh-h7-campaign.R`;
- this Cursor handover.

No R package source, TMB likelihood source, NAMESPACE, Rd file, README,
vignette, formula grammar, family constructor, or user example changed in the
Arc-2 slice.

## 7. Landing state

| item | state |
| --- | --- |
| `codex/va-gh-all-families` | Arc-2 closeout committed at `7bf56c4a`; this handover is committed on the same branch |
| Remote | **CARRIED-OVER:** branch is local-only; protected remote export was not authorised in this turn |
| Pull request | none; opening a draft PR is carried over with the push and requires explicit maintainer approval |
| `origin/main` | protected and untouched; branch merge-base checked as `5bf18ab3` |
| Working tree | clean after the local handover commit |
| Campaign process | none active; full campaign and monitor are complete |
| Other local branches | pre-existing unpushed work belongs to other lanes and is not part of this handover |
| Carried-over work | the OWED read-only diagnosis, later maintainer decision, and optional branch push/draft PR; no unfinished compute |

The pre-handover landing gate reported this branch unpushed and many unrelated
historical local branches with unpushed commits. A single push was prepared,
but the protected remote-export boundary rejected it because this turn did not
contain explicit authorisation to send the full branch to GitHub. No workaround
was attempted. Cursor can resume from the local worktree; if the maintainer
later authorises publication, push this exact branch once, open a draft PR, and
verify the new landing state before treating origin as authoritative.

## 8. Checks and safe commands

The final closeout checks are recorded verbatim in the after-task report. A
safe focused verification command is:

```sh
cd /private/tmp/gllvmtmb-va-gh-all-families
export NOT_CRAN=true
Rscript --vanilla -e \
  'devtools::test(filter="va-gh-h7-campaign", reporter="summary", stop_on_failure=TRUE)'
```

For the diagnosis, prefer a new read-only script or notebook outside the
package source until the maintainer chooses a change. Do not mutate the frozen
campaign driver merely to make analysis convenient.

## 9. Mission Control handoff

| Repo | Branch / worktree | Last green evidence | Shipped | Next by leverage |
| --- | --- | --- | --- | --- |
| gllvmTMB | `codex/va-gh-all-families` in `/private/tmp/gllvmtmb-va-gh-all-families` | 36,000/36,000 complete; focused tests, pkgdown check, HTML parse, and diff check PASS | Arc 1 implementation/light gates plus Arc 2 immutable same-host adjudication; no merge or release | Diagnose the 24 FAIL and 11 INCONCLUSIVE cells, prepare a non-pooled cell-specific fence recommendation, then stop for maintainer decision |

Mission Control currently states the same boundary: implementation/light
support does not imply broad accuracy; `cross_platform=FALSE` remains visible;
and multinomial is Laplace-supported while VA is not implemented because its
coupled-softmax expectation needs a separate architecture.

## 10. Gotchas and explicit exclusions

- The committed compact CSV has 11 verdict/calibration columns. Mechanism
  diagnosis needs the retained 74-column adjudication; do not guess missing
  metrics from the compact labels.
- `INCONCLUSIVE` is an eligibility result, not evidence of equivalence and not
  a soft PASS.
- Exact-expectation cells can still fail recovery or comparator gates; absence
  of GH cost does not guarantee estimator accuracy.
- The one passing q = 5 cell does not authorise q >= 3 generally. Here q = 5
  is an internal evidence rank, not a blanket public-admission boundary.
- Same-host independent roles are valuable provenance but are not
  cross-platform replication.
- Issue #934 is the separate sandwich-route selection lane. Arc 2 scored
  fixed-effect VA-Wald only and does not close or absorb that issue.
- Multinomial wording must remain equivalent to: **Laplace supported; VA not
  implemented because coupled softmax requires a separate architecture.**
- Do not touch the old Narval lane, the completed H ladder, other worktrees,
  stashes, Mission Control files, or unrelated branches while diagnosing this
  result.

## 11. Exact resume prompt

> Read `AGENTS.md` and
> `docs/dev-log/handover/2026-08-07-cursor-handover.md`. Run the handover
> rehydration steps, reconcile them with the current git state, and classify
> every item as OWED, DONE, RETRACTED, or PROTECTED. Then continue only the
> OWED read-only diagnosis: explain the retained 24 FAIL and 11 INCONCLUSIVE
> family-by-rank results and prepare a non-pooled cell-specific public-fence
> recommendation. Stop for maintainer approval before any code, fence,
> threshold, campaign, merge, or release action.
