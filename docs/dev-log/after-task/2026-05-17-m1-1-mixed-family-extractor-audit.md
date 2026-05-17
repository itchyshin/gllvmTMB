# After Task: M1.1 — per-extractor mixed-family audit (M1-PR-A1)

**Branch**: `agent/m1-1-mixed-family-extractor-audit`
**PR type tag**: `audit` (audit-table only; no R/, no NAMESPACE, no machinery change)
**Lead persona**: Boole + Emmy
**Maintained by**: Boole + Emmy; reviewers: Fisher (inference path); Rose (audit trail); Ada (close gate)

## 1. Goal

First M1 deliverable per the slice contract in `ROADMAP.md`:
characterise which `extract_*()` and `bootstrap_Sigma()` paths
handle `family = list(...)` fits correctly today, and which
need M1.3..M1.8 work to walk MIX-03..MIX-08 to `covered`.

The audit is **read-only inspection** of the extractor surface.
No code edits in this PR — output is one audit document at
`docs/dev-log/audits/2026-05-17-m1-1-mixed-family-extractor-audit.md`.

## 2. Implemented

**Mathematical Contract**: zero R/ source, NAMESPACE, generated
Rd, family-registry, formula-grammar, or extractor change.

### Audit-doc structure (5 sections + decisions)

1. **Headline finding table** — 14 extractors × (file:line,
   mixed-family path, status, M1 slice, action). Three buckets:
   **aware** (use `family_id_vec`/`link_residual_per_trait`
   directly), **inherit-via-delegation** (call aware
   extractors), **mixed-family-blind** (the gap).
2. **§1 — The `extract_repeatability` correctness gap**. The
   audit's headline finding: `extract_repeatability` is the
   *only* extractor with a real **correctness bug** on
   non-Gaussian / mixed-family fits — its `vW` formula at
   `R/extract-repeatability.R:127` omits the per-family
   `sigma2_d` term. Section walks through the bug, the
   M1.6 fix sketch, and the Gaussian backward-compat
   guarantee.
3. **§2 — Existing test coverage map** + **§3 — aware vs
   inheriting vs blind classification**.
4. **§4 — M1 slice routing implications**. Confirms M1.3..M1.8
   slice routing from the ROADMAP. Surfaces one caveat:
   **M1.6 has a code change** (the repeatability formula fix),
   not just tests; the batched PR should be named
   `M1-PR-B2 (code fix + tests for ratio extractors)` so the
   formula change is explicit.
5. **§5 — Recommended Day-1 plan adjustment** + maintainer
   decisions.

### Headline finding (paraphrased here for context)

- **Aware extractors** (use mixed-family helpers directly):
  `extract_Sigma`, `extract_correlations`, `extract_Omega`,
  `extract_residual_split`, `extract_proportions` (delta-blocked).
- **Inherit awareness via delegation**: `extract_communality`,
  `extract_Sigma_B/W`, `extract_ICC_site`, `extract_phylo_signal`.
- **Aware via separate path (simulate + refit)**:
  `bootstrap_Sigma`.
- **Family-agnostic by design**: `extract_ordination`.
- **Mixed-family-blind (correctness gap)**: `extract_repeatability`.

### The `extract_repeatability` finding

`vW <- diag(Lambda_W %*% t(Lambda_W)) + sd_W^2` at
`R/extract-repeatability.R:127`. For Gaussian fits this is
correct. For non-Gaussian / mixed-family fits it omits the
per-family link residual `sigma2_d`, biasing W-tier variance
*downward* and per-trait repeatability *upward* (toward 1).

The fix is one line: add `+ link_residual_per_trait(fit)` to
the `vW` expression. Gaussian backward-compat preserved
because `link_residual_per_trait()` returns 0 for Gaussian.
This is **M1.6 scope** — coded fix + Gaussian regression test
+ mixed-family test on the M1.2 fixture.

## 3. Files Changed

```
Added:
  docs/dev-log/audits/2026-05-17-m1-1-mixed-family-extractor-audit.md   (the audit doc)
  docs/dev-log/after-task/2026-05-17-m1-1-mixed-family-extractor-audit.md   (this file)
```

No R/, no NAMESPACE, no test, no Rd, no `_pkgdown.yml` change.

## 4. Checks Run

- `pkgdown::check_pkgdown()` → ✔ No problems found (audit docs
  are not part of the pkgdown article surface).
- Source-code grep verifications (the audit's evidentiary base)
  preserved in the audit doc with file:line references for
  every claim.
- 3-OS CI not yet run; this PR touches no R/ source.

## 5. Tests of the Tests

3-rule contract from `docs/design/10-after-task-protocol.md`:

- **N/A** — audit-only PR. The M1.3..M1.8 implementation PRs
  will each exercise the 3-rule contract against the gaps this
  audit identifies. M1.6 specifically requires Rule 1 ("would
  have failed before fix"): the Gaussian regression test
  confirms backward-compat, and the new mixed-family test
  confirms the bias removal.

## 6. Consistency Audit

Stale-wording rg sweep on the PR diff:

- `rg "S_B\\b|S_W\\b|gllvmTMB_wide|trio" docs/dev-log/audits/2026-05-17-m1-1-mixed-family-extractor-audit.md`
  → 0 hits (the audit uses canonical `Sigma_B / Sigma_W` math
  notation and `\\psi` lowercase per the 2026-05-14 notation
  decision).
- Register row IDs cited in the audit (MIX-01..MIX-09, EXT-01..EXT-09)
  all resolve.

Convention-Change Cascade (AGENTS.md Rule #10): N/A — audit
only.

## 7. Roadmap Tick

- `ROADMAP.md` M1 row: now 1/10 done (M1.1 audit closes with
  this PR). M1.2 (Curie lead, mixed-family fixture) is next.
- Validation-debt register: no status change. The audit surfaces
  the M1.6 correctness fix as a discovery; row MIX-06 stays
  `partial` until the fix lands + is tested.

## 8. What Did Not Go Smoothly

- The audit surfaced **one substantive bug** (the
  `extract_repeatability` `sigma2_d` omission). This bug has
  been in main since the extractor was added — it didn't show
  up in CI because no test exercises non-Gaussian repeatability
  per-trait against an analytic reference value. The
  pre-upgrade `rose-pre-publish-audit` skill wouldn't have
  caught it either; this requires a per-extractor formula
  audit, not surface-content discipline. Future skill upgrade
  candidate.
- One naming wrinkle: the M1.6 slice in ROADMAP groups
  `extract_repeatability` + `extract_phylo_signal` as
  "ratio extractors". The audit clarifies that
  `extract_phylo_signal` already inherits awareness (no
  formula change); only `extract_repeatability` needs the
  code fix. M1.6's after-task should distinguish "fix
  repeatability formula" from "test phylo_signal on
  mixed-family + phylo fixture".

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Boole** (formula / API): the audit surfaced a real correctness
gap in `extract_repeatability` that's been latent in main.
Every M1 slice's audit-then-fix pattern (read source, characterise
behaviour, identify gap, plan code change) is the right
discipline. This is the function-first model working as
intended: machinery design surfaces gaps; tests then verify
the fix preserves backward-compat AND adds the new behaviour.

**Emmy** (extractor architecture): the audit clarified the
extractor surface topology. Three classes of mixed-family
handling: aware-direct, inherit-via-delegation, and
family-agnostic-by-design. The 14 extractors (incl. legacy
aliases) split cleanly into these classes. Only one (the
repeatability gap) falls outside.

**Fisher** (inference path): the
`extract_correlations(method = ?)` × mixed-family gap was
larger than the headline suggests — the existing tests cover
Fisher-z + Wald only; profile + bootstrap on mixed-family is
M1.4 work. The M3.5 derived-quantity coverage walk closes the
remaining inference-method × family gaps.

**Rose** (audit trail discipline): the audit cross-cites every
source-code claim with file:line, every test claim with the
test file's `test_that` name, and every register-row ID. This
audit pattern (read-only, evidence-anchored) is the template
for future per-slice audits.

**Ada** (orchestration): M1 begins. First M1 deliverable (this
PR) is the smallest of the 10 slices but the most diagnostic —
without it, M1.6 could have shipped a "tests-only" PR that
missed the formula bug. After-the-fact pattern: every M1+ slice
gets a brief audit-before-edit step, even when the slice is
"tests only", so we surface latent bugs systematically.

## 10. Known Limitations and Next Actions

- **M1.2 (Curie lead, mixed-family fixture) is next** per Day-1
  plan. Audit confirms fixture design: 3-family (Gaussian +
  binomial + Poisson, 60 sites, 3 traits) + 5-family (add
  Gamma + nbinom2). Maintainer ratification of fixture design
  + the M1.6 code-fix scope is the gate before M1.2 starts.
- **M1.6 PR naming**: rename the planned `M1-PR-B2 (ratio
  batch)` to `M1-PR-B2 (ratio batch + repeatability formula
  fix)` so the formula change is explicit in the PR title.
- **Pre-upgrade skill gap**: the
  `rose-pre-publish-audit` skill (now 16 checks after PR #149)
  catches surface discipline gaps (citations, banners, exports),
  not extractor formula gaps. The M1.6 PR's after-task report
  should propose adding a **per-extractor formula audit** as a
  new skill check, or — more lightly — as a "must read for the
  M1.6-class implementer" entry in
  `docs/design/06-extractors-contract.md`.
