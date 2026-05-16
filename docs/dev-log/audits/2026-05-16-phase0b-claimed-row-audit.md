# Phase 0B — per-row audit of `claimed` syntax in 01-formula-grammar.md

**Maintained by:** Rose (audit lead) and Curie (test-writing lead for
0B execution).
**Reviewers:** Pat (applied-user readability), Boole (parser-surface
correctness), Ada (orchestrator ratifies).
**Status:** DRAFT — Pat + Rose review **before** any test-writing
(vision rule #2). No code or test changes in this PR; this is the
planning artefact.

## Purpose

Phase 0B per `docs/dev-log/decisions.md` 2026-05-16 item 9:

> 0B: empirical verification — walk every `claimed` row to
> `covered` or honestly downgrade. **No new features.**

This audit is the planning input to that walk. For each `claimed`
row in `docs/design/01-formula-grammar.md` status map, I record:

1. the corresponding `35-validation-debt-register.md` row ID;
2. the register row's status (`covered` / `partial` / `blocked`);
3. existing test evidence (file path);
4. the **proposed action** for Phase 0B execution:
   - **PROMOTE-COVERED**: register row already says `covered`;
     the formula-grammar status map can move `claimed` → `covered`
     in a single doc edit, no new test needed.
   - **NEEDS-SMOKE**: register row says `partial`; identify the gap
     and write a smoke test that closes it, then promote both rows.
   - **NEEDS-AUDIT-FIRST**: cannot tell without running existing
     tests to confirm they assert what they claim to assert. Curie
     audits during execution.
   - **DOWNGRADE-RESERVED**: register row says `blocked` or no real
     coverage; honestly downgrade the formula-grammar row.

## Vocabulary reminder

Two distinct status systems, both intentional:

- **Parser-syntax status map** (`01-formula-grammar.md`): `covered /
  claimed / reserved / planned`.
- **Validation-debt register** (`35-validation-debt-register.md`):
  `covered / partial / opt-in / blocked` (drmTMB convention).

Phase 0B's job is to make these two artefacts agree, by walking
parser-syntax `claimed` rows to either `covered` (when register
evidence supports it) or honestly downgrading.

## Audit table

19 `claimed` rows in `01-formula-grammar.md` status map (as of
2026-05-16 post-Phase-0A merge). The "Register row" column points
at the corresponding row in `35-validation-debt-register.md`
Section 1 (FG-*) and elsewhere.

| # | Parser-syntax row | Register row | Register status | Existing test evidence | Proposed 0B action | Rationale |
|---|-------------------|--------------|-----------------|------------------------|--------------------|-----------|
| 1 | `gllvmTMB(value ~ ..., data = df_long)` long entry | FG-02 | `covered` | `test-canonical-keywords.R`, `test-keyword-grid.R` | **PROMOTE-COVERED** | Register evidence supports promotion immediately. |
| 2 | `gllvmTMB(traits(t1, t2, ...) ~ ..., data = df_wide)` wide entry | FG-01, FG-03 | `covered` | `test-traits-keyword.R`, `test-wide-weights-matrix.R` | **PROMOTE-COVERED** | Register evidence supports promotion. |
| 3 | `0 + trait` and `(0 + trait):x` long-format grammar | (covered by FG-02; no dedicated row) | (via FG-02) | `test-stage1-stacked-fixed-effects.R`, `test-canonical-keywords.R` | **PROMOTE-COVERED** | The trait-stacked grammar IS the long-format entry point's contract. |
| 4 | `latent(0 + trait \| g, d = K)` standalone | FG-04 | `covered` | `test-stage2-rr-diag.R`, `test-keyword-grid.R` | **PROMOTE-COVERED** | |
| 5 | `unique(0 + trait \| g)` standalone | FG-05 | `covered` | `test-stage2-rr-diag.R`, `test-cross-sectional-unique.R` | **PROMOTE-COVERED** | |
| 6 | `latent + unique` paired | FG-06 | `covered` | `test-stage2-rr-diag.R`, `test-mixed-response-sigma.R` | **PROMOTE-COVERED** | Headline decomposition; well-tested. |
| 7 | `indep(0 + trait \| g)` | FG-07 | `partial` | `test-stage3-propto-equalto.R` (Gaussian only) | **NEEDS-SMOKE** | Gap: non-Gaussian regimes. Smoke test on binomial + Poisson recommended; if the engine accepts and converges, promote. |
| 8 | `dep(0 + trait \| g)` | FG-08 | `partial` | `test-stage3-propto-equalto.R` (Gaussian only) | **NEEDS-SMOKE** | Same gap pattern as #7. |
| 9 | `(omit) ↔ scalar covariance` | (no dedicated row) | n/a | implicitly tested via FG-04/FG-05 | **NEEDS-AUDIT-FIRST** | The row describes a "no term added" path. Audit whether existing tests actually exercise this; if yes, promote with cross-ref. |
| 10 | `phylo_latent(species, d = K, tree = tree)` | PHY-02 (paired) | `covered` | `test-stage35-phylo-rr.R`, `test-phylo-q-decomposition.R` | **PROMOTE-COVERED** | |
| 11 | `phylo_unique(species, tree = tree)` | PHY-02 (paired) | `covered` | `test-stage35-phylo-rr.R`, `test-phylo-q-decomposition.R` | **PROMOTE-COVERED** | |
| 12 | `phylo_scalar(species, vcv = Cphy)` | PHY-04 | `partial` | `test-stage35-phylo-rr.R` | **NEEDS-SMOKE** | Gap: dedicated `phylo_scalar` smoke test (vcv = Cphy path). |
| 13 | `phylo_indep` / `phylo_dep` | PHY-05 | `partial` | `test-stage35-phylo-rr.R` (smoke) | **NEEDS-SMOKE** | Gap: per-keyword smoke (parse + fit + extractor sanity). |
| 14 | `spatial_latent` / `spatial_unique` / `spatial_scalar` / `spatial_indep` / `spatial_dep` (5 keywords) | SPA-02, SPA-03, SPA-04 | `partial` | `test-stage4-spde.R`, `test-spatial-latent-recovery.R`, `test-spatial-mode-dispatch.R`, `test-spatial-orientation.R` | **NEEDS-SMOKE per-keyword** | Mesh + mode-dispatch covered; per-keyword smoke for `spatial_indep`, `spatial_dep`, `spatial_scalar` needed. |
| 15 | `meta_V(value, V = V)` | MET-01, MET-02 | `partial` (single-V) / `covered` (block-V) | `test-block-V.R` | **NEEDS-SMOKE** for single-V | block-V already `covered`. Single-V smoke needed: parse + fit + sigma sanity. |
| 16 | `block_V(study, sampling_var, rho_within)` helper | MET-02 | `covered` | `test-block-V.R` | **PROMOTE-COVERED** | |
| 17 | `(1 \| group)` ordinary RE | RE-01 (and FG-10 nested case) | `covered` | `test-multi-random-intercepts.R` | **PROMOTE-COVERED** | |
| 18 | `lambda_constraint = list(B = M)` | LAM-01, LAM-02 | `partial` (Gaussian) | `test-lambda-constraint.R` | **NEEDS-SMOKE** (Gaussian path) + **LAM-03 deferred to M2** | Gaussian smoke probably already passes; verify the existing test asserts pinned-entry values within tolerance. Binary IRT (LAM-03) is M2 work, NOT 0B. |
| 19 | `suggest_lambda_constraint(fit)` | LAM-04 | `partial` | `test-suggest-lambda-constraint.R` | **NEEDS-AUDIT-FIRST** | Per validation-debt register: M2.4 verifies on `n_items ∈ {10, 20, 50}` × `d ∈ {1, 2, 3}`. For 0B: verify the helper returns a well-typed object on Gaussian (smoke); full binary verification is M2. |

## Summary

| Action | Count | Rows |
|--------|-------|------|
| **PROMOTE-COVERED** (doc edit only, no new test) | 10 | #1, #2, #3, #4, #5, #6, #10, #11, #16, #17 |
| **NEEDS-SMOKE** (write 1+ new smoke test, then promote) | 6 | #7, #8, #12, #13, #14, #15 (and partly #18) |
| **NEEDS-AUDIT-FIRST** (verify existing test asserts what it claims before promoting) | 2 | #9, #19 |
| **DOWNGRADE-RESERVED** | 0 | (none — no `claimed` row is `blocked` in the register) |

**Net 0B execution scope**: ~6 new smoke tests + 2 audit-and-confirm + 10 doc-only promotions.

## What Pat + Rose should check

**Pat (applied-user lens)**:
- Are the proposed smoke tests legible to a new applied user? Each
  smoke should be a 5–10 line test that mirrors how a real user
  would call the keyword.
- Is the "NEEDS-AUDIT-FIRST" framing for rows #9 and #19 honest, or
  am I dodging real work that should be smoked properly?

**Rose (consistency audit)**:
- Does every cross-reference (parser-syntax row → register row) hold?
- Are any `claimed` rows missing from the audit?
- Are any rows where the register says `partial` but a real Phase
  0B smoke would surface `reserved` or `blocked` more honestly than
  `covered`?

**Boole (parser-surface correctness)**:
- For row #9 (`(omit) ↔ scalar covariance`), is the "no term added"
  path actually a thing the parser handles distinctly, or is it
  implicit in the other keyword paths?
- For row #14 (5 spatial keywords), should `spatial_latent` get
  its own smoke even though `test-spatial-latent-recovery.R`
  exists?

**Ada (orchestrator)**:
- Phase 0B execution plan: do the 6 NEEDS-SMOKE rows go in one PR
  (Curie writes all 6), or one PR per row (smaller, easier to
  review)?
- LAM-03 / LAM-04 cross-reference: confirm that binary IRT
  validation is M2 work (not 0B); the 0B scope is Gaussian smoke
  only for the lambda-constraint helpers.

## Proposed 0B execution sequencing (for discussion)

After Pat + Rose + Boole + Ada review and approve this audit:

1. **PR-0B.1**: doc-only PR walking the 10 PROMOTE-COVERED rows
   from `claimed` → `covered` in `01-formula-grammar.md` and
   adding matching FG-* / RE-* / PHY-* / MET-* notes in the
   register. No code, no tests.
2. **PR-0B.2**: smoke tests for the 6 NEEDS-SMOKE rows
   (#7, #8, #12, #13, #14, #15). One PR with 6 small tests; Curie
   writes; Pat + Rose audit; Ada ratifies. After merge, promote
   the corresponding rows.
3. **PR-0B.3**: audit-and-confirm work for #9 and #19. Probably a
   small doc-fix PR after running the existing tests confirms
   coverage (or downgrades if they don't).
4. **PR-0B.4** (if needed): any honest downgrades to `reserved` or
   to `partial` that surface during smoke-writing.

After all four PRs merge: Phase 0B closes. The status map in
`01-formula-grammar.md` should have **zero `claimed` rows**;
everything is `covered`, `reserved`, or `planned` (with `partial`
in the register where appropriate).

## What this audit explicitly does NOT do

- **Does not write any tests.** Curie writes tests in PR-0B.2 and
  PR-0B.3 after this audit is ratified.
- **Does not edit `01-formula-grammar.md`.** The status map walks
  happen in PR-0B.1.
- **Does not touch articles.** Article cleanup is Phase 0C work
  (per `decisions.md` 2026-05-16 item 9): revert overpromise
  articles, rewrite ROADMAP, run Phase 1b empirical coverage
  artefact.
- **Does not touch the R/ source.** Phase 0B has no new features;
  it's verification of existing parser behaviour.

## Cross-references

- `docs/design/00-vision.md` — vision rule #2 (Pat + Rose review
  before edits), function-first sequencing.
- `docs/design/01-formula-grammar.md` — status map being audited.
- `docs/design/35-validation-debt-register.md` Section 1 (FG-*) +
  others — register evidence.
- `docs/dev-log/decisions.md` 2026-05-16 entry — Phase 0A/0B/0C
  sequencing.
- AGENTS.md Design Rule #10 — Convention-Change Cascade
  (relevant for PR-0B.1: when walking `claimed` → `covered`,
  cascade applies if any argument-name / keyword default changed).
