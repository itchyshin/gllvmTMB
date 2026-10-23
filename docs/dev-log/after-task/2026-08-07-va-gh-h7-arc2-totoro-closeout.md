# After Task: VA(GH) H = 7 Arc 2 Totoro closeout

## 1. Goal

Close the authorised Design-110 Arc 2 campaign without changing its frozen
estimator, fixtures, thresholds, denominator, or public fences. Completion
required exactly 36,000 verified confirmation bundles, independent export of
the existing H ladder and the confirmation, checksum-bound adjudication of all
36 family-by-rank cells, and an honest update of the validation and reader
surfaces.

## 2. Implemented

The Totoro confirmation finished at `2026-08-07T05:15:58Z` with a `COMPLETE`
exit receipt, exit code 0, and 36,000 published bundles for 36,000 planned
rows. A clean checkout at `022b4eabf36bb442ed7b76aacadffeeebdc3cff2`
exported the unchanged 5,520-row H ladder and the 36,000-row confirmation with
the committed role-neutral driver. The clean adjudicator then used 5,000
paired-bootstrap replicates and wrote 36 independent family-by-rank rows.

The overall point route returned 1 PASS (`poisson_log`, q = 5), 24 FAIL, and
11 INCONCLUSIVE. Completeness passed for all 36 cells. Reliability returned 20
PASS, 15 FAIL, and 1 INCONCLUSIVE; H = 7 stability returned 16 PASS, 12
INCONCLUSIVE, and 8 `NOT_APPLICABLE` exact-cell labels. Fixed-effect VA-Wald
calibration was 20 CALIBRATED / 16 UNCALIBRATED. Latent posterior-SD
calibration was 15 CALIBRATED / 20 UNCALIBRATED / 1 INCONCLUSIVE.

Both stages ran on Totoro, so the final receipt records
`h_ladder_platform=Totoro`, `confirmation_platform=Totoro`, and
`cross_platform=FALSE`. The failed Fir and Narval execution lanes contribute
no rows to this denominator. Mission Control and the capability surface now
show the same result and state explicitly that multinomial is Laplace-supported
but VA is not implemented because its expectation is a coupled softmax.

### Mathematical Contract

This closeout changes no likelihood equation, family parameterisation,
quadrature rule, estimator, formula grammar, export, S3 method, TMB template,
or simulation DGP. The frozen scalar contract remains ordinary loadings-only,
n = 120, p = 8, q in {2, 5}, H = 7 for non-exact VA cells, matched Laplace,
and 500 confirmation seeds. The public uncertainty boundary remains
`calibrated = FALSE`; a variational posterior SD is not re-labelled as a
frequentist random-effect standard error.

## 3a. Decisions and Rejected Alternatives

The adjudicator's family-by-rank labels remain authoritative; the 36 cells are
not pooled into a package-wide pass. FAIL and INCONCLUSIVE labels are retained
rather than hidden by the complete execution receipt. The Arc-1 public fence is
not silently reversed in this compute-only closeout, but the documentation no
longer confuses implementation/light support with general accuracy.

No Fir partial denominator was mixed into Totoro. Fir stopped at 10,549 bundles
under project file quota, and Narval's transferred dependency runtime failed
before publishing a campaign bundle. The approved Totoro replacement preserved
the exact 36,000-row plan. Calling that same-host evidence “cross-platform” was
rejected. Threshold changes, retrospective family-specific exceptions,
automatic promotion of uncertainty, and any expansion to JJ, multinomial, or
non-scalar scope were also rejected.

## 4. Files Touched

- `NEWS.md`: replaces the in-progress Arc-2 statement with the mixed final
  result and same-host boundary.
- `docs/design/110-va-gh-h7-all-scalar-families.md`: records execution history,
  final verdicts, and unchanged exclusions.
- `docs/design/35-validation-debt-register.md`: updates VA-06, VA-09, VA-12,
  and VA-13 while retaining every row as `partial`.
- `docs/dev-log/audits/2026-08-07-va-gh-h7-arc2-totoro-adjudication.csv`:
  durable 36-row verdict and calibration table.
- `docs/dev-log/audits/2026-08-07-va-gh-h7-arc2-totoro-adjudication.dcf`:
  compact provenance and checksum receipt.
- `docs/dev-log/audits/2026-08-07-va-gh-h7-arc2-totoro-adjudication.md`:
  human-readable result and scope boundary.
- `docs/dev-log/capability-surface.html`: updates the reader-facing result,
  calibration counts, same-host limitation, and multinomial wording.
- `docs/dev-log/check-log.md`: records exact campaign and verification evidence.
- This after-task report.
- Shinichi Mission Control
  `Shinichi/Dashboards/mission-control/live/status/gllvmTMB.json`: updates the
  live project cockpit. This file is committed separately in the local-only
  Shinichi repository.

No R source, C++ source, NAMESPACE, generated Rd, README, vignette source,
`_pkgdown.yml`, family constructor, likelihood, parser, or user example changed.

## 5. Checks Run

```sh
python3 /Users/z3437171/Dropbox/Github\ Local/Shinichi/tools/automation_owner_check.py \
  va-gh-h7-totoro-arc-2-monitor
# PASS; task and working tree own the action-capable heartbeat.

NOT_CRAN=true Rscript --vanilla -e \
  'devtools::test(filter="va-gh-h7-campaign", reporter="summary", stop_on_failure=TRUE)'
# PASS; 0 failures.

Rscript --vanilla -e 'pkgdown::check_pkgdown()'
# PASS; no problems found.

python3 - <<'PY'
# stdlib HTMLParser over docs/dev-log/capability-surface.html
PY
# PASS; the edited capability HTML parses.

git diff --check
# PASS.

jq empty \
  /Users/z3437171/Dropbox/Github\ Local/Shinichi/Shinichi/Dashboards/mission-control/live/status/gllvmTMB.json
# PASS.

sh /Users/z3437171/Dropbox/Github\ Local/Shinichi/Shinichi/Dashboards/mission-control/live/start.sh --verify
# PASS; canonical server already running at http://127.0.0.1:8823/.

curl -fsS http://127.0.0.1:8823/p/gllvmTMB/status.json
# PASS; live response contains the final Arc-2 counts and multinomial boundary.

gh pr list --state open --limit 50
# PASS; no open pull requests.

git log --all --oneline --since='6 hours ago'
# PASS; recent shared-file work belongs to this VA(GH) lane.
```

The compact evidence was compared with the complete adjudication output and
DCF checksum chain: all 36 compact rows matched, including family/rank labels,
calibration labels, and the full-verdict MD5
`e57f8460fd98bd0eac43b4a6c014317d`. The H-ladder export checksums are
`895bea568af0e582e8b104f9bf991d72` (CSV),
`915194270a3ccb09d46d555265cc9e05` (DCF), and
`b1add5f806255d7da75e415650efe14c` (inputs). The confirmation equivalents are
`2cf5a852e7282290a5de77dc82f62bc9`,
`bc1b579d1ad16298b76ae8783883574b`, and
`cce123b5fc2b16984c004639a93c6619`.

## 6. Tests of the Tests

This closeout adds evidence and prose, not new adjudicator logic. The committed
campaign suite still exercises malformed cross-products, missing and corrupt
bundles, duplicate task claims, wrong provenance, incomplete campaigns,
reliability failure, recovery degradation, uncalibrated coverage, export
tampering, and the distinction between `COMPLETE` data and 36 PASS verdicts.
The final run supplies the production-scale complement: exact plan equality,
36,000 immutable completion receipts, independent host-local exports, a
41,520-row bound input manifest, and 36 retained non-pooled results. No test was
weakened or skipped to obtain the final labels.

## 8. Consistency Audit

The following scoped scans were run after the result update:

```sh
rg -n 'Arc 2 is active|Arc 2.*running|Fir campaign is running|final family.*withheld|remain.*Arc 2|pending.*Arc 2|no final|VA fenced|active Fir|Arc 2.*finish|family-wise recovery.*withheld' \
  NEWS.md docs/design/110-va-gh-h7-all-scalar-families.md \
  docs/design/35-validation-debt-register.md docs/dev-log/capability-surface.html
# PASS; only intended final-status mentions remain.

rg -n '1 PASS|24 FAIL|11 INCONCLUSIVE|1 / 36|1/36|20/36|15/36' \
  NEWS.md docs/design/110-va-gh-h7-all-scalar-families.md \
  docs/design/35-validation-debt-register.md docs/dev-log/capability-surface.html
# PASS; counts agree.

rg -n 'multinomial|coupled softmax|coupled-softmax|VA not implemented' \
  NEWS.md docs/design/110-va-gh-h7-all-scalar-families.md \
  docs/design/35-validation-debt-register.md docs/dev-log/capability-surface.html
# PASS; multinomial is consistently outside VA scope.

rg -l '\bS_B\b|\bS_W\b|\\bf S' README.md NEWS.md docs/design docs/dev-log/capability-surface.html
# PASS; only the historical scan instruction in Design 10 matched.

rg -n 'gllvmTMB\(' R vignettes README.md NEWS.md docs/design | wc -l
# 654 existing call sites; no example changed in this closeout.

rg -l 'in prep|in preparation' docs vignettes
# PASS for this scope; no foundational in-prep claim was added.

rg -l '\bphylo\(|\bgr\(|\bmeta\(|block_V\(|phylo_rr\(' vignettes
# One intentional compatibility-route discussion in function-map-cheatsheet.Rmd.

rg -l 'meta_known_V' README.md NEWS.md docs vignettes
rg -l 'gllvmTMB_wide' README.md NEWS.md docs vignettes
# Existing historical/compatibility references only; no new instance added.
```

Rose verdict: **PASS with an explicit evidence limitation**. The result counts,
calibration labels, public-fence wording, validation-debt rows, campaign design,
and live Mission Control agree. The limitation is substantive, not editorial:
both campaign stages used Totoro, so `cross_platform=FALSE` remains visible on
every load-bearing internal surface.

The status inventory is: README unchanged because it makes no Arc-2 accuracy
claim; ROADMAP unchanged because no matching item was completed or re-scoped;
NEWS updated; Design 110 updated; validation debt updated; capability surface
updated; `_pkgdown.yml`, vignettes, reference topics, and known-limitations
surfaces unchanged because no API, example, navigation, or separate
known-limitations claim changed.

## 7a. Issue Ledger

### Roadmap Tick

Not applicable. Arc 2 is governed by Design 110 and the VA validation-debt rows,
not by a discrete ROADMAP checkbox. No roadmap item was silently marked done.

Issue #934 remains open and correctly scoped: it asks to score the already-built
sandwich route under a stricter stationarity gate and enough seeds. Arc 2 scored
the fixed-effect VA-Wald route only, so it neither closes nor duplicates that
issue. No issue was opened or closed during this closeout.

## 9. What Did Not Go Smoothly

Fir's valid partial run exhausted project file quota at 10,549 bundles. Narval's
replacement failed its transferred dependency runtime before producing any
campaign bundle. The approved Totoro replacement therefore supplied a complete
same-host confirmation, which is weaker than the planned independent-platform
design and is labelled accordingly.

Two early prose-audit commands over-escaped their regular expressions and
failed syntactically. Corrected commands are recorded in Section 6 and passed;
the failed invocations supplied no evidence and were not counted as checks.

## 10. Known Residuals

Only one of 36 family-by-rank cells passed the full point route. Twenty-four
failed and eleven were inconclusive. This does not revoke Arc-1 implementation
or light-fit support, but it prevents a general H = 7 accuracy claim. The
same-host result is not cross-platform confirmation. The fixture does not cover
`unique = TRUE`, structured covariance tiers, random slopes, mixed-family
recovery, multinomial, or other non-scalar likelihoods.

Fixed-effect VA-Wald and latent posterior-SD interfaces remain explicitly
uncalibrated in public output. The next bounded statistical action is not to
rerun or reinterpret Arc 2: it is to use the retained cell-level evidence to
diagnose the 24 failures and 11 eligibility shortfalls, then propose any new
estimator or fence change as a separately approved design. Issue #934 remains
the separate route-selection lane for the sandwich estimator.

## 11. Team Learning

Ada kept operational completion separate from statistical success. Gauss and
Noether preserved the frozen estimator, quadrature, DGP, and threshold contract.
Curie and Fisher kept all 36 family/rank verdicts independent and kept Wald and
latent-SD calibration separate from point recovery. Grace verified native
runtime, plan, export, and checksum provenance. Rose and Pat kept the mixed
result and same-host limitation visible while retaining concise reader-facing
language.

The reusable lesson is that a fully completed compute campaign can strengthen
the evidence while weakening the capability claim: immutable failure retention
and separate calibration labels made that conclusion possible.

## 12. Cross-Product Coverage

This closeout covers all 18 admitted scalar family/link cells at q = 2 and q =
5, exact or H = 7 VA evaluation as frozen per cell, matched Laplace, operational
reliability, point recovery, H-ladder stability, fixed-effect VA-Wald
calibration, and rotation-aware latent posterior-SD calibration for the ordinary
loadings-only fixture. It also covers immutable completeness and provenance for
both Totoro evidence roles.

It does NOT cover `unique = TRUE`, structured covariance tiers, random slopes,
mixed-family recovery, multinomial or another coupled/non-scalar likelihood,
the JJ research route, sandwich intervals, global-parameter propagation into
latent-score uncertainty, or an independent operating system or compute
platform.
