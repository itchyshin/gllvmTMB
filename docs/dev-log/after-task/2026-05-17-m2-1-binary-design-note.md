# After Task: M2.1 — Binary completeness design note

**Branch**: `agent/m2-1-binary-design-note`
**Slice**: M2.1 (first slice of M2 — Binary completeness)
**PR type tag**: `design` (new design doc; no R/, no NAMESPACE, no machinery change)
**Lead persona**: Boole + Emmy
**Maintained by**: Boole + Emmy; reviewers: Fisher (statistical inference), Pat (reader UX), Rose (overpromise prevention), Ada (close gate)

## 1. Goal

First M2 deliverable per the slice contract in
[`ROADMAP.md`](../../../ROADMAP.md): file the binary-completeness
design note that scopes M2.2 through M2.7. Output is the new
design doc [`docs/design/41-binary-completeness.md`](../../design/41-binary-completeness.md).

The doc serves three purposes:

1. **Honest scope statement** for M2 — what it does, what it
   does NOT do, what stays deferred.
2. **Gap analysis** mapping the validation-debt register's
   binary rows (FAM-02 deep, FAM-03, FAM-04, FAM-14, LAM-03,
   LAM-04) to per-slice deliverables.
3. **Audit of existing engine conventions** for the four
   binary-flavour families (binomial logit / probit / cloglog,
   ordinal-probit) so M2.2 has a single source of truth for
   the identification regime each one runs under.

**Mathematical contract**: zero R/ source, NAMESPACE,
generated Rd, family-registry, formula-grammar, or extractor
change. The design doc records the M2 plan; subsequent slices
(M2.2 → M2.7) deliver the tests + article work.

## 2. Implemented

### `docs/design/41-binary-completeness.md` (new, ~360 lines after cross-package addendum)

10 sections, plus an IRT-confirmation paragraph + a dedicated
**Cross-package light sanity checks** subsection (per maintainer
2026-05-17 dispatch of cross-package checks against `glmmTMB` +
`galamm` + `mirt`, scoped explicitly as "not big tests; big
tests are Phase 5.5"):

1. **Goal** — including a clear "What M2 is NOT" boundary that
   leaves empirical R = 200 coverage for M3 and cross-package
   empirical agreement for Phase 5.5.
2. **Baseline** — what M1 already gives for binary. The
   extractor + resample surface is mixed-family-tested through
   M1.3..M1.8 (binomial rows are part of the M1.2 three-tier
   fixture); M2's gap is at the *single-family deep-validation*
   level, not the extractor-surface level.
3. **Gap analysis** — per-slice deliverables tables for M2.2
   (binary CI + extractor validation), M2.3 (`lambda_constraint`
   binary IRT recovery), M2.4 (`suggest_lambda_constraint`
   reliability), M2.5 (`psychometrics-irt.Rmd` re-author per
   the [Phase 0C rewrite-prep handoff](../audits/2026-05-16-phase0c-rewrite-prep.md)),
   M2.6 (`joint-sdm.Rmd` binary restore), M2.7 (close gate).
4. **Per-family identification conventions audit** — binomial-
   logit ($\pi^2/3$ residual via Dempster-Lerner threshold-model
   convention), binomial-probit ($1$ by construction),
   binomial-cloglog ($\pi^2/6$, extreme-value), ordinal-probit
   ($1$ by construction + `gllvmTMB_auto_residual_ordinal_probit_overcount`
   warning class).
5. **`lambda_constraint` + `suggest_lambda_constraint` machinery
   audit** — what
   [`R/lambda-constraint.R`](../../../R/lambda-constraint.R) and
   [`R/suggest-lambda-constraint.R`](../../../R/suggest-lambda-constraint.R)
   already do (parser + map machinery `covered`; binary recovery
   `partial`); what M2.3 + M2.4 add.
6. **Tests of the tests** — 3-rule contract applied to the M2
   slice plan.
7. **Persona assignment** — lead + reviewers per slice.
8. **Deliverables checklist** — end-to-end view across all 7
   slices.
9. **Open questions / decisions deferred** — six items flagged
   for M2.2 / M2.3 / M2.4 / M2.5 authors to resolve in their
   slice PRs (not in this M2.1 design note).
10. **Honest scope boundary statement** — what's validated
    after M2, what stays `partial`, what's deferred to M3 /
    Phase 5.5 / post-CRAN. Cross-package light-check rule
    quoted verbatim from the maintainer dispatch.

### Cross-package light sanity checks (added 2026-05-17)

Per maintainer 2026-05-17 follow-up to the M2.1 PR: M2 covers
IRT explicitly, and bundles light cross-package checks against
glmmTMB + galamm (in addition to the mirt::mirt() check that
was already in §3). Scope: **one shared fixture per comparator,
no replicates, no grid.** The Phase 5.5 full grid stays
deferred.

Three comparator rows added to the gap-analysis tables:

- **M2.2 + `glmmTMB`** — single-trait binomial-logit GLMM
  fixture; `gllvmTMB` single-trait reduces to a `glmmTMB`
  binomial GLMM modulo the stacked-formula plumbing. Test at
  `test-m2-2-glmmTMB-cross-check.R`.
- **M2.3 + `mirt::mirt()`** — binary 2PL IRT
  $n_\text{items} = 20, d = 1, n_\text{respondents} = 500$
  fixture. Item-slope + intercept agreement.
- **M2.3 + `galamm::galamm()`** — same fixture as the `mirt`
  check; tests the `lambda_constraint` ↔ `galamm`-`lambda`-
  matrix translation. Documents API-mapping difference.

Both M2.3 cross-checks live at `test-m2-3-mirt-cross-check.R`.
Both share the same `R/data-binary-irt.R` fixture (one fit
per package).

## 3. Files Changed

```
Added:
  docs/design/41-binary-completeness.md                          (~310 lines, 10 sections)
  docs/dev-log/after-task/2026-05-17-m2-1-binary-design-note.md  (this file)
```

No R/ source change. No NAMESPACE change. No `man/*.Rd` change.
No `_pkgdown.yml` change (the design doc is not a vignette).
No validation-debt register edit yet — that cascade happens at
M2.7 close gate per the M1 pattern.

## 4. Checks Run

- `pkgdown::check_pkgdown()` → no problems found (design docs
  are reference-only, not articles).
- `rg "S_B\\b|S_W\\b|gllvmTMB_wide|trio|phylo_rr\\(|gr\\(|block_V\\(" docs/design/41-binary-completeness.md docs/dev-log/after-task/2026-05-17-m2-1-binary-design-note.md`
  → 0 hits.
- `rg "meta_known_V" docs/design/41-binary-completeness.md`
  → 0 hits (canonical `meta_V` only).
- Cross-ref sanity: every relative-path link inside the design
  doc resolves to an existing file (manually walked: paths to
  `00-vision.md`, `35-validation-debt-register.md`,
  `02-family-registry.md`, `R/lambda-constraint.R`,
  `R/suggest-lambda-constraint.R`, `R/extract-sigma.R`,
  `R/data-mixed-family.R`, `R/methods-gllvmTMB.R`, the three
  Preview-banner articles, the M1 close after-phase report,
  the Phase 0C rewrite-prep audit).

## 5. Tests of the Tests

3-rule contract from `docs/design/10-after-task-protocol.md`:

- **Rule 1** (would have failed before fix): not applicable —
  M2.1 is a design-doc-only PR. The "would have failed before
  fix" check applies per slice during M2.2..M2.6.
- **Rule 2** (boundary): the design doc explicitly names the
  boundary regimes M2.4 must test
  (`suggest_lambda_constraint()` at $d = 3, n_\text{items} = 10$
  is the parameter-counting boundary). The boundary is in §3
  and §6 of the design note.
- **Rule 3** (feature combination): §6 names the M2.5 feature
  combination (binomial-probit + `lambda_constraint` +
  `extract_correlations()` Fisher-z in one fit; mixed-family
  IRT example if feasible). Carry-forward to M2.5 author.

## 6. Consistency Audit

Stale-wording rg sweep on this PR's files:

- `rg "S_B\\b|S_W\\b|gllvmTMB_wide|trio|phylo_rr\\(|gr\\(|block_V\\(" docs/design/41-binary-completeness.md docs/dev-log/after-task/2026-05-17-m2-1-binary-design-note.md` → 0 hits.
- `rg "meta_known_V"` → 0 hits.
- Citation discipline: design doc references in-repo files
  with relative paths only; no in-prep paper citations made
  here (those are M2.5 article work).
- Persona-active-naming: §7 names every persona per slice;
  Boole + Emmy lead M2.1 with Fisher + Pat + Rose + Ada
  reviewers stated explicitly.
- No function ↔ help-file pair affected (this is design-doc-
  only).

Convention-Change Cascade (AGENTS.md Rule #10): the design doc
adds a forward-looking M2.7 cascade plan that names which
validation-debt register rows walk to `covered` + which Preview
banners are removed at M2.5 / M2.7. No cascade fires in M2.1
itself.

## 7. Roadmap Tick

- `ROADMAP.md` M2 row: ⚪ Planned (0 / 7) → 🟢 In progress (1 / 7
  after this PR merges). Status chip can flip at M2.7 close.
- Validation-debt register: no row walks in this PR. The cascade
  (FAM-02 deep / FAM-03 / FAM-04 / FAM-14 / LAM-03 / LAM-04 →
  `covered`) fires at M2.7.

## 8. What Did Not Go Smoothly

- **Initial Phase 0B baseline turned out to be the rewrite-prep
  handoff doc, not a separate design file.** The ROADMAP M2.1
  contract reads "Binary design note expanded from Phase 0B
  baseline", which led to a brief search for `41-binary-completeness.md`
  already on disk; no such file. The Phase 0B baseline turned
  out to be the LAM-03 + LAM-04 register rows + the
  [Phase 0C rewrite-prep audit](../audits/2026-05-16-phase0c-rewrite-prep.md)
  M2.5 contract. This doc *is* the design note that consolidates
  those into a single source of truth. **Lesson**: when the
  ROADMAP says "expanded from X baseline", confirm what X is
  before writing — the baseline may be a register row + an
  audit doc, not a design file.

## 9. Team Learning (per `AGENTS.md` Standing Review Roles)

**Boole** (lead — formula grammar / lambda machinery audit):
the design doc's §5 audits the
[`R/lambda-constraint.R`](../../../R/lambda-constraint.R) +
[`R/suggest-lambda-constraint.R`](../../../R/suggest-lambda-constraint.R)
contract from the parser side. The packed-vector mapping +
`factor(NA)` constraint mechanism is already well-formed; M2.3
+ M2.4 work is *test depth*, not parser changes. Surfaces three
open questions (§9 of design doc): mirt comparator scope,
probit unique-keyword behaviour, sign-pinning convention.

**Emmy** (co-lead — extractor surface audit): §4 records the
per-family identification convention (residual variance per
link function) that the M1 cascade already validates for
binomial rows *in mixed-family fits*. M2 single-family deep
validation does not require any new extractor work; the
existing machinery is correct, just under-tested at
single-family depth.

**Fisher** (review — statistical inference framing): the design
doc's §3 gap analysis for M2.2 names Wald / profile /
bootstrap CI testing on binomial fits. The profile-CI shape
question (quadratic vs skewed on a logit-scale parameter) is
flagged for M2.2 author; this is downstream of the M1.4 + M1.8
work on `extract_correlations()` CI methods.

**Pat** (review — reader UX): the design doc cites the
[Phase 0C rewrite-prep handoff](../audits/2026-05-16-phase0c-rewrite-prep.md)
for the M2.5 article re-author contract; the M2.5 article
work has its rewrite scope locked in already. M2.6
(`joint-sdm.Rmd` restoration) inherits the long+wide pair
template from M1.9's
[`mixed-family-extractors.Rmd`](../../../vignettes/articles/mixed-family-extractors.Rmd).

**Rose** (review — overpromise prevention): the design doc's
"What M2 is NOT" boundary in §1 explicitly defers empirical
R = 200 coverage to M3 and cross-package empirical agreement
to Phase 5.5. M2's "binary completeness" claim is bounded to
parameter recovery + CI accuracy + binary IRT machinery;
articles describing M2-validated capabilities can ship
without overpromise risk.

**Ada** (review — orchestration): M2.1 follows the M1.1
pattern (design-doc-only first slice; subsequent slices
extend with R/, tests, and articles). The 7-slice plan
mirrors M1's 10-slice ROADMAP table closely; reviewer
assignments per §7 are stable.

## 10. Known Limitations and Next Actions

- **M2.2 dispatches next** — Fisher (CI lead) + Curie (DGP) +
  Emmy (extractor) per §7. Recovery study at $n_\text{units} \in \{50, 200\} \times d \in \{1, 2\}$
  on binomial(logit) / (probit) / (cloglog) + ordinal-probit.
- **M2.5 + M2.6 article work depends on M2.2 + M2.3 + M2.4**
  landing first (validated machinery, then examples). Per
  vision-rule sequencing.
- **Six open questions** flagged in §9 of the design doc for
  resolution during their respective slices.
- **No follow-up PRs** required by M2.1 itself. The next item
  is M2.2 dispatch.
