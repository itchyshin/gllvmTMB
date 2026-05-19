# Codex kickoff brief (Shannon → Codex, 2026-05-18)

**From**: Shannon (cross-team coordination)
**To**: Codex team
**Date**: 2026-05-18, ~16:00 UTC
**Companion document**: the full handover audit lives at
`docs/dev-log/shannon-audits/2026-05-18-handover-to-codex-team.md`
(read that first for the full snapshot — this brief is the
2-minute version).

---

## Welcome back

Maintainer activated codex-team review on 2026-05-18 ~15:50 UTC
to check Claude's recent work. Per coordination-board.md, codex
had been assumed absent since 2026-05-14; today's activation is
the formal return cue. Update the coordination-board's
Codex-absent section when you're ready.

## TL;DR

1. **18 PRs merged in the last 24 h** (Claude lane, under
   persona-active review). Most-recent merge: PR #180 (M3.4
   design — Noether identifiability audit + Design 48 strategy).
2. **3 PRs in flight** (`gh pr list --state open`): #181
   (sparse-Ainv engine pass-through), #182 (M3.4 implementation
   — warm-start + phi-clamp), #183 (1-line `_pkgdown.yml` fix).
   Maintainer's handoff decision: **self-merge #183 only**; hold
   **#181 + #182 for codex pre-merge review**.
3. **Pat + Rose + Grace pkgdown audit (2026-05-18)** surfaced
   4 findings; 1 covered by PR #183; 3 queued for codex pickup.

## What's on your plate

### A. Pre-merge review of PRs #181 and #182 (PRIMARY)

Both touch `R/fit-multi.R` at non-overlapping line ranges.
Specific review priorities per PR are listed in §2 of the full
handover audit. The headline questions:

- **#181**: numerical equivalence at 1e-6 tolerance — should
  it be tighter? The propto block's sparse-Ainv branch
  densifies into `Cphy_inv` (line ~1092) — does this negate
  the sparse construction win, or is it acceptable for the
  single-shared-variance case?
- **#182**: `.gllvm_univariate_phi()` family dispatch — are
  the moment-of-method estimators (beta, betabinomial,
  gamma_delta) correctly aligned with gllvmTMB's per-family
  parameterisation? Is the phi-clamp at the right injection
  points (currently 2: `tmb_params` init + inside the warmup
  helper)?

Both PRs walk validation-debt register rows to `covered`
(ANI-08, MIS-16, MIS-17). If you find concerns, request a
revert + re-engineer rather than letting the rows ship under
shaky evidence.

### B. Pkgdown audit pickups (NEXT)

Three findings deferred for codex (or coordination with Pat /
Rose / Darwin):

1. **Pat-grade critical**: `_pkgdown.yml:113` uses
   `has_keyword("families")` but `R/families.R` has zero
   `@keywords families` — the "Response families" section
   in the rendered site shows only `ordinal_probit`. The 27
   families (Beta, betabinomial, nbinom1, nbinom2, tweedie,
   student, all delta_*, all *_mix, truncated_*, censored_poisson,
   gengamma, lognormal) are unfindable in the navbar.
   **Recommended fix**: replace `has_keyword("families")` with
   explicit `- families` (the topic name to which all 27
   functions are aliased via `@rdname families`).
2. **Pat-grade redundancy**: 8 roxygen `@examples` blocks +
   1 article have redundant `trait = "trait"` (the function's
   default). Bundle with #1.
3. **Rose + Darwin scope**: 14 `Nakagawa et al. (in prep)`
   citations in `R/` roxygen + 4 in articles. Per maintainer's
   published-foundations rule, most should cite Bartholomew
   et al. 2011 / Westneat / Hui / Thorson / Leibold &
   Mikkelson. Reserve in-prep for engine-specific validation
   claims. Held question for maintainer: do this now (M3
   phase) or at Phase 1e final Rose pre-publish sweep?

### C. M3.3 production grid (FOLLOW-ON)

After #182 merges, the next natural slice gate is **M3.3
production grid** — 15 cells × R = 200 reps via
`workflow_dispatch` GHA on Linux runner. Needs:
- `dev/precompute-m3-grid.R` extended to accept
  `--init-strategy=single_trait_warmup` flag.
- New `.github/workflows/m3-production-grid.yaml` with
  `on: workflow_dispatch` + artifact upload of the
  per-cell RDS.

See `docs/design/48-m3-4-boundary-regimes.md` §5 for Fisher's
expected outcome bands; if any cell remains < 0.90 at R = 200
production, Design 49 (Mitigation C — `disp_group=` shared phi)
activates.

## Where to read

In order of usefulness for onboarding:

1. **This brief** + the full Shannon handover audit
   (`docs/dev-log/shannon-audits/2026-05-18-handover-to-codex-team.md`).
2. **Recent after-task reports** (today, 2026-05-18):
   - `docs/dev-log/after-task/2026-05-18-sparse-pedigree-ainv-helper.md`
     (PR #179 — sparse-Ainv building block)
   - `docs/dev-log/after-task/2026-05-18-sparse-pedigree-ainv-engine.md`
     (PR #181 — engine pass-through)
   - `docs/dev-log/after-task/2026-05-18-m3-4-implementation.md`
     (PR #182 — warm-start + phi-clamp)
   - `docs/dev-log/after-task/2026-05-18-m3-3a-profile-primary.md`
     (PR #176 — profile-CI primary)
   - `docs/dev-log/after-task/2026-05-18-florence-recruitment.md`
     (PR #178 — Florence persona)
3. **Backing audits**:
   - `docs/dev-log/audits/2026-05-18-cross-package-count-inference-scout.md`
     (4-package scout; shareable with drmTMB team)
   - `docs/dev-log/audits/2026-05-18-noether-nbinom2-identifiability.md`
     (backing audit for M3.4 design)
4. **Strategy docs**:
   - `docs/design/47-sparse-pedigree-ainv.md` (§10 = follow-on
     section for PR #181)
   - `docs/design/48-m3-4-boundary-regimes.md` (M3.4 strategy)
   - `docs/design/46-visualization-grammar.md` (Florence's
     figure-gate framework)
5. **Persistent rules**: `AGENTS.md` (14 standing roles + 10
   design rules), `CLAUDE.md` (operating discipline), `ROADMAP.md`.

## Conventions to preserve

- **Persona-active naming** (maintainer 2026-05-16 ratified
  discipline): name leads + reviewers actively in chat,
  commits, design docs, after-task reports — not just buried
  in §9 footers. When codex picks up a PR, add a codex
  per-persona §7 paragraph to the after-task report.
- **§3a Decisions block** in after-task reports (Memory-OS
  upgrade 2026-05-18): every after-task includes
  decisions + rejected alternatives + confidence levels.
- **Local checks before push**: full `R CMD check --as-cran`
  (never truncated with `--no-tests` / `--no-examples`); this
  is the drmTMB-team discipline the maintainer enforced
  2026-05-18.
- **Self-merge authority**: docs-only / dev-log / single-line
  config / audit / after-task = self-merge OK. Engine R/ +
  formula + likelihood = ask the maintainer (and now, ask
  codex first).
- **Validation-debt register**: every PR that touches an
  advertised capability walks a row. Status states are
  `covered / partial / opt-in / blocked` per Rose's
  4-state vocabulary.

## Operational state at handoff

- **Local working dir**: clean on `main`.
- **All branches pushed** to origin
  (`agent/sparse-pedigree-ainv-engine`,
  `agent/m3-4-warmstart-phi-clamp`,
  `agent/pkgdown-pedigree-ainv-sparse`).
- **CI watchers armed** (Monitor tasks `bwmsqd0di` #181,
  `b20hzzlgm` #182, `bh3sdecjw` #183).
- **No uncommitted work**.

## Open questions for codex (highest-value second opinions)

1. **Cross-PR consistency between #181 and #182**: both touch
   `R/fit-multi.R` initial-parameter / phylo-VCV-prep blocks
   at non-overlapping lines. Do the two changes interact
   (e.g., warmup × sparse Ainv input)?
2. **Honest-scope on M3.4**: PR #182's intercept-only warmup
   covers phi seeding only (per Design 48 §4 out-of-scope
   for b_fix warmup). Are there hidden assumptions in the
   intercept-only formulation worth flagging?
3. **Sparse-Ainv propto branch**: the densification into
   `Cphy_inv` for animal_scalar / propto path — acceptable
   for v0.2.0, or worth a C++ sparse branch in
   `src/gllvmTMB.cpp`? Gauss called it medium-high confidence;
   codex's historical TMB ownership makes this your call.
4. **In-prep citation scope** (audit finding #3): full
   triage now, or hold for Phase 1e? Maintainer-decision item.

---

## Maintainer-forwardable kickoff message for Codex

Below is a verbatim short note the maintainer can paste / forward
to Codex when codex starts. Designed to land cold (codex has not
seen this conversation) but link to everything needed:

> Welcome back. Claude's team has been busy 2026-05-17 → 2026-05-18
> (~18 PRs merged including sparse pedigree A⁻¹ pre-CRAN pivot,
> M3.4 boundary-regime mitigations, Florence persona recruitment,
> M3 inference design ratification, cross-package scout for the
> drmTMB team). Three PRs are in flight (#181 sparse-Ainv engine,
> #182 M3.4 warm-start + phi-clamp, #183 1-line pkgdown fix);
> Claude self-merged only #183 (the trivial one) and held #181 +
> #182 for your pre-merge review. Start by reading
> `docs/dev-log/shannon-audits/2026-05-18-codex-kickoff-brief.md`
> (2-minute brief) → then the full handover at
> `docs/dev-log/shannon-audits/2026-05-18-handover-to-codex-team.md`
> (longer audit) → then the today's after-task reports in
> `docs/dev-log/after-task/2026-05-18-*.md` for each PR's
> context. Specific review priorities per open PR are in §2 of
> the full audit. Decision items needing your call: (a)
> sparse-Ainv propto densification — accept for v0.2.0 or push to
> C++ sparse branch; (b) M3.4 honest-scope statement adequacy;
> (c) cross-PR consistency #181 × #182 in `R/fit-multi.R`.
> Update `docs/dev-log/coordination-board.md` to revise the
> Codex-absent assumption when you're ready. Persona-active
> naming is the active discipline — preserve "who did what" by
> adding a codex per-persona paragraph to any PR's §7 you
> modify substantively.

— Shannon
