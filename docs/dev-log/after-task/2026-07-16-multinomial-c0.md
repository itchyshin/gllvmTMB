# After-task — Lane C C0: `multinomial()` family design + register (Design 83)

**Date:** 2026-07-16 · **Author:** Claude (Fable 5) · **Branch:** `agent/lane-c-multinomial`
(worktree, based `48a66b93`) · **Commit:** `2b7d3c1d`.

## Scope
Phase **C0** of the Lane-C ultra-plan (`~/.claude/plans/categorical-multinomial-humble-babbage.md`):
the design spec + validation-debt register for a new `multinomial()` (baseline-category logit /
softmax) **response** family, `family_id 16`, **Tier-1 fixed-effects-only**. No engine code — the live
build (C1a–C2) is Codex's baton (sequential). Design produced by a 6-member ultra-plan panel (Gauss,
Boole, Noether, Fisher+Emmy, Curie, Rose+Jason).

## What the decisive gate found (why the shape)
- `ordinal_probit` (fid 14) is a fully `covered` family — NOT fenced for identifiability; the board's
  "ordinal fenced" is only the Lane-A interval-coverage-certificate hold. Categorical inherits no
  negative result.
- The real obstruction: an unordered categorical response is intrinsically **K−1 latent dimensions**,
  so it cannot supply the single scalar link-residual `σ²_d` gllvmTMB's mixed-family correlation
  requires (Design 02 Link Residual Contract; Design 62 delta precedent). ⇒ Tier 1 fixed-effects-only;
  the K−1-dim latent-scale correlation surface is Tier 2, deferred + fenced.
- De-riskers: a validated softmax kernel already exists (MD6c predictor path,
  `src/gllvmTMB.cpp:2320-2334`) to port; and category contrasts can ride the existing grammar as
  pseudo-trait factor levels (no parser change). `categorical()` is taken (imputation) ⇒ `multinomial()`.

## Outcome (files changed — docs only)
- **NEW** `docs/design/83-multinomial-response-family.md` — full spec: softmax decomposition + Noether's
  alignment table + identifiability proof; the K−1-latent-dimension deferral; representation
  (pseudo-trait + group-index + anchor eval); C++/R build contract; S3/inference contract; ADEMP
  recovery contract; Jason's use-case.
- **EDIT** `docs/design/35-validation-debt-register.md` — new **FAM-20** row (`partial`,
  fixed-effects-only, latent N/A by design; evidence placeholders "not passing until D-43 audit").
- **EDIT** `docs/design/02-family-registry.md` — removed the "planned; post-CRAN" bullet; added the
  "Unordered categorical (multinomial) families" subsection with the Design-62 scope note; updated the
  Rose honesty note; added the Design 83 cross-ref.
- **NEW** `docs/dev-log/handover/2026-07-16-claude-to-codex-multinomial.md` — the turnkey build package.
- **EDIT** `docs/dev-log/check-log.md` — directed Lane-C handoff line to Codex.
- Vault (separate commit `8321904`): mission-control `gllvmTMB.json` Lane-C `do_not_repeat` + capability note.

## Checks
- `git status --porcelain | grep -E '(src/|R/)'` → **NONE** (docs only, as intended for C0).
- No compile / test run (correct — C0 is design; the live toolchain is Codex's C1a–C2).

## Follow-up (the baton)
Codex builds C1a (C++ fid-16 softmax, port MD6c, `tmb-likelihood-review`) → C1b (R `multinomial()` +
expansion) → C1c (S3 surface) → C2 (ADEMP recovery + fail-loud fence tests). **Pin first:** the response
encoding contract (handover §"PIN FIRST"). Then hand back to Claude for **C3** (honesty fencing + Rose
D-43 audit — default NOT-DONE, no public wording before it) and **Vf**. `test-matrix-multinomial-unit.R`
deliberately NOT authored (covariance tier = out of Tier-1 scope). Julia parity = a separate later arc.

## Discipline notes
Worked in an isolated Lane-C worktree (Lane A's uncommitted release-branch changes untouched).
Scoped staging; local commits, no push (local-first). HIGH-RISK likelihood authorized by maintainer
2026-07-16; region-local, disjoint from Lane B's latent-score C++.
