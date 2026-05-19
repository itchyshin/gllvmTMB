# Shannon handover audit: Claude team → Codex team

**Author**: Shannon (cross-team coordination + persona-active row
ownership in the validation-debt register).
**Date**: 2026-05-18 (15:50 UTC at write time).
**Trigger**: maintainer 2026-05-18 requested codex team take over
"for a while to check what your team has been done". Operational
boundary: I (Claude) finish in-flight work + write this handover
+ do **not** start anything new. Codex picks up from here.

**Audience**: Codex team (primary). Maintainer (secondary, for
context-handoff approval).

**Method**: walk the git log + open-PR list + validation-debt
register + audit/after-task/check-log artefacts from the past
~24 h of intensive Claude-team work. Report pass / warn /
fail with concrete evidence. Shannon does **not** edit any
file in this report — it is a point-in-time snapshot.

## 1. Where main currently stands

Most recent merge: **PR #180** (M3.4 design — Noether
identifiability audit + Design 48 strategy doc, 2026-05-18 ~15:00
UTC).

**Merged since 2026-05-17 evening (12 PRs)**:

| # | Title | Lead | Persona briefing |
|---|---|---|---|
| #169 | M2.8b CI fixes: non-ASCII chars + @param A/Ainv + nadiv Suggests | Grace + Rose | CI cleanup for the M2.8b animal-keyword soft-deprecate PR |
| #170 | M2.8c article cascade for animal_* (5 articles) | Pat + Rose lead; Darwin + Boole + Ada review | 5 worked-example articles covering animal_*(pedigree/A/Ainv) on real-ish quant-gen fixtures |
| #171 | M3.1 DGP grid design + ASReml speed reference + ROADMAP M2/M3 refresh | Fisher + Curie + Jason + Gauss + Ada | M3 strategy doc; speed-techniques reference; roadmap milestone restructure |
| #172 | M3.2 DGP grid pipeline + smoke artefact + M3.6 article scaffold + #170 after-task | Curie + Grace + Pat + Fisher; Boole + Rose review | `dev/precompute-m3-grid.R`, smoke artefact ships, article scaffold |
| #173 | M3.2b all-fams smoke (12 cells) + simulator bug fixes | Curie lead; Fisher + Pat + Boole + Rose | 12-cell smoke over 4 families × 3 d; simulator robustness |
| #174 | M3.2c integrate mixed-family in smoke | Curie + Boole lead; Fisher + Pat + Rose | mixed-family smoke cell wired in; family_var attr conventions |
| #175 | Design 44 — M3.3 inference-replacement strategy | Fisher + Curie lead; Gauss + Boole + Rose | profile-primary CI architecture (replaces Wald in PR #176) |
| #176 | M3.3a profile-primary CI + Memory-OS discipline upgrades | Fisher + Curie + Pat + Shannon | profile CI is primary; bootstrap optional; memory-OS upgrades |
| #177 | Cross-package scout audit: count + ordinal inference machinery | Jason lead; Fisher + Gauss synthesis; Boole + Curie + Rose review | 4-package scout (glmmTMB, drmTMB, gllvm, galamm); shareable with drmTMB team per maintainer |
| #178 | Florence recruitment + Design 46 visualization grammar | Boole + Pat + Rose + Ada | New persona Florence (scientific illustrator); mirrors drmTMB; figure gate |
| #179 | Sparse pedigree A^{-1} helper (Design 47 building block) | Boole + Gauss lead | `pedigree_to_Ainv_sparse()` exported (pre-CRAN per maintainer correction) |
| #180 | M3.4 design: Noether identifiability audit + Design 48 | Boole + Noether + Pat | strategy doc for warm-start + phi-clamp; implementation = PR #182 |

**Open PRs in flight (3)**:

| # | Title | Lead | Status |
|---|---|---|---|
| #181 | Sparse pedigree A^{-1} engine pass-through (Design 47 §10 follow-on) | Boole + Gauss + Curie; Pat + Rose review | CI in progress: ubuntu pass, macOS pass, **windows pending** |
| #182 | M3.4 implementation — single-trait warmup (opt-in) + phi-clamp (default) | Boole + Gauss + Curie; Pat + Fisher + Rose review | CI in progress (all 3 OS pending) |
| #183 | Fix pkgdown reference index: add `pedigree_to_Ainv_sparse` (1-line) | Grace + Boole | CI in progress (all 3 OS pending) |

## 2. PRs in flight — codex verification targets

Each open PR is a natural codex verification target. The
expected codex verification scope per PR:

### PR #181 — Sparse pedigree A^{-1} engine pass-through

**Branch**: `agent/sparse-pedigree-ainv-engine` (commit `f5ca991`).

**Files**: `R/animal-keyword.R`, `R/brms-sugar.R`, `R/fit-multi.R`,
`tests/testthat/test-pedigree-sparse-ainv-engine.R` (NEW), Design
47 §10 update, register row ANI-08 → `covered`, after-task
report.

**What codex should verify** (Boole + Gauss invitation):
1. **Numerical equivalence**: byte-equivalence tests at `1e-6`
   tolerance on `logLik` between sparse-Ainv and dense-A inputs
   for `animal_scalar` (propto path) and `animal_unique`
   (phylo_rr path) — is `1e-6` conservative enough? Should we
   tighten to `1e-8` to match the M2.8 byte-equivalence
   convention?
2. **Propto densification**: in `R/fit-multi.R:1092` the
   sparse-`phylo_vcv` branch of the propto block densifies into
   `Cphy_inv`. Is the construction-time win (sparse Henderson)
   actually realised, or does densifying eagerly negate it?
   Gauss flagged this as "medium-high confidence" in the
   after-task §3a; codex review on numerical cost-benefit is
   welcome.
3. **`Matrix::determinant()` vs `base::determinant()` dispatch**:
   the engine now explicitly calls `Matrix::determinant()` on
   sparse `Ainv_phy_rr`. Should we also switch the dense
   propto branch (`log_det_Cphy <- as.numeric(determinant(Cphy,
   logarithm = TRUE)$modulus)`) for consistency, or is the
   base-generic fine on dense input?
4. **Rownames/colnames symmetry**: the fix mirrors `rownames →
   colnames` in `pedigree_to_Ainv_sparse()` to support character
   subset `Ainv[levs, levs]`. Is this the right level to fix
   (vs defensive in the engine), and is the existing
   `MCMCglmm::inverseA()` rowname convention stable across
   MCMCglmm versions?

### PR #182 — M3.4 implementation (warm-start + phi-clamp)

**Branch**: `agent/m3-4-warmstart-phi-clamp` (commit `f274bf1`).

**Files**: `R/gllvmTMB.R`, `R/fit-multi.R`, `R/init-warmstart.R`
(NEW), `tests/testthat/test-m3-4-warmstart-phi-clamp.R` (NEW),
register rows MIS-16 + MIS-17 → `covered`, after-task report.

**What codex should verify** (Boole + Gauss + Fisher invitation):
1. **`.gllvm_univariate_phi()` family dispatch**: covers
   nbinom1/nbinom2 (via glm.nb), truncated_nbinom2 (via glm.nb
   on `y[y>0]`), beta + betabinomial (moment-of-method),
   gamma_delta (moment-of-method on `y[y>0]`). Tweedie returns
   NULL (deferred). **Are the moment-of-method estimators
   correct for the gllvmTMB parameterisations?** Specifically:
   beta uses `phi = mu(1-mu)/var - 1` — matches gllvmTMB's
   `(a = mu*phi, b = (1-mu)*phi)` parameterisation? Codex review
   on parameterisation alignment is welcome.
2. **Phi-clamp injection point**: applied in two places — at
   `tmb_params` init (line ~1195, no-op for default zero inits)
   and in the warm-start helper before return. Is there a
   third injection point that's needed (e.g., after the
   multi-start jitter at `R/fit-multi.R:1688`)? Gauss's
   after-task §6 Lesson 2 hints yes.
3. **Opt-in vs default**: `init_strategy = "default"` keeps
   current behaviour; `"single_trait_warmup"` activates warmup.
   Pat insisted opt-in for v0.2.0 to avoid silently changing
   nbinom2 users' fits. Codex review on whether the
   `init_strategy` API name reads cleanly is welcome.
4. **`suppressWarnings(MASS::glm.nb)`**: the
   "iteration limit reached" warning from glm.nb on
   near-Poisson y is suppressed because the downstream
   phi-clamp handles it. Is suppression here defensible, or
   should we surface it differently (e.g., `cli::cli_inform()`
   when `control$verbose`)?

### PR #183 — pkgdown reference-index fix

**Branch**: `agent/pkgdown-pedigree-ainv-sparse` (commit `822e682`).

**Files**: `_pkgdown.yml` (1 line).

**What codex should verify**: trivial; `pkgdown::check_pkgdown()`
returns "No problems found" locally — codex can re-run to
confirm. Once green, this PR unblocks the pkgdown workflow
which has been red on main since PR #179 (sparse-Ainv helper)
merged.

## 3. Audit findings — surfaced but NOT implemented

Pat + Rose + Grace pkgdown audit (2026-05-18 ~15:30 UTC) on
maintainer ask "check pkgdown reference page and other bits …
quite a few minor things". Findings ranked by severity:

| # | Severity | Finding | Lead | Status |
|---|---|---|---|---|
| 1 | 🔴 Critical (blocks site build) | `pedigree_to_Ainv_sparse` missing from `_pkgdown.yml` reference index | Grace | **PR #183 open** — will close once merged |
| 2 | 🔴 Critical (Pat-grade) | **Response families section is empty except `ordinal_probit`** in rendered site. `_pkgdown.yml:113` uses `has_keyword("families")` — but `R/families.R` has `@rdname families` for all 27 family functions and **zero** `@keywords families`. The 27 families (`Beta`, `betabinomial`, `nbinom1`, `nbinom2`, `nbinom2_mix`, `lognormal`, `lognormal_mix`, `gamma_mix`, `gengamma`, `tweedie`, `student`, `truncated_poisson`, `truncated_nbinom1`, `truncated_nbinom2`, `censored_poisson`, all 11 `delta_*`) are **unfindable in the navbar reference index** | Pat | **Not implemented; codex pickup recommended** |
| 3 | 🟡 In-prep citation hygiene | 14 `Nakagawa et al. (in prep)` references in R/ roxygen + 4 in articles. Per maintainer's published-foundations rule, most should cite published predecessors (Bartholomew et al. 2011, Westneat, Hui, Thorson, Leibold & Mikkelson). Reserve in-prep for engine-specific validation claims | Rose + Darwin | **Not implemented; codex / Rose-Darwin pickup recommended** |
| 4 | 🟡 Redundant default-arg noise | Redundant `trait = "trait"` in 8 roxygen `@examples` + 1 article (phylogenetic-gllvm.Rmd:235). The default is already `trait = "trait"` in `gllvmTMB()` | Pat | **Not implemented; codex pickup recommended (bundle with finding #2)** |
| 5 | 🟢 No issues | Articles dir vs `_pkgdown.yml` articles list — clean both directions | Grace | pass |
| 6 | 🟢 No issues | Notation cleanliness — no `S_B` / `S_W` legacy notation found anywhere | Rose | pass |
| 7 | 🟢 No issues | Deprecated keyword aliases (`phylo`, `phylo_rr`, `gr`, `meta`, `block_V`) correctly fenced in their own section, not used in articles | Rose | pass |
| 8 | 🟢 No issues | Internal-keyword hygiene — all legacy aliases (`getLoadings`, `getLV`, `ordiplot`, `gllvmTMB_wide`, `VP`, `getResidualCov`, `extract_Sigma_B/W`, `profile_ci_*`) correctly tagged `@keywords internal` | Grace | pass |

**Recommended codex actions on these findings**:
- **Finding #2** is the biggest user-facing inconsistency.
  Fix: replace `has_keyword("families")` in `_pkgdown.yml:113`
  with explicit `- families` (the topic name to which all 27
  family functions are aliased via `@rdname families`).
- **Finding #3** is a larger triage exercise; needs per-citation
  decision against published foundations. Could be a
  Rose-Darwin co-led PR after the M3 production grid lands.
- **Finding #4** is mechanical; bundle with finding #2 in a
  single Pat-led PR.

## 4. Validation-debt register — recent walks

Rose's discipline: every PR that touches an advertised capability
walks a register row. The 2026-05-18 walks were:

| Row | Before | After | Walked by |
|---|---|---|---|
| ANI-08 (sparse `Ainv =` direct engine path) | `blocked` | `partial` (PR #179) → `covered` (PR #181 pending merge) | Boole + Gauss + Curie |
| MIS-16 (`init_strategy = "single_trait_warmup"`) | (new row) | `covered` (PR #182 pending merge) | Boole + Curie |
| MIS-17 (Phi starting-value clamp [0.01, 100]) | (new row) | `covered` (PR #182 pending merge) | Gauss + Curie |

**Rows still in `partial` waiting for M3.3 production grid** (R = 200):
- CI-08 (`coverage_study()` ≥ 94 % empirical coverage gate) —
  Gaussian d=2 shipped at R=200; binomial / nbinom2 / ordinal-
  probit / mixed walk to `covered` at M3.3 production grid run.
- FAM-02..04 (binomial logit / probit / cloglog) — already
  `covered`.
- FAM-05 (betabinomial), FAM-07 (nbinom1), FAM-09..13
  (gamma/beta/lognormal/student/tweedie), FAM-14
  (ordinal_probit), FAM-15..18 (delta_*/mix) — most `partial`
  awaiting M3 family rigour.

## 5. Deferred work — codex pickup queue

Listed in the order I (Claude) was planning to tackle them when
the maintainer halted me:

1. **M3.3 production grid via `workflow_dispatch`** (~30 min
   Linux runner). Depends on PR #182 (M3.4) merging. Needs
   `dev/precompute-m3-grid.R` extended to accept
   `--init-strategy=single_trait_warmup` flag + a new
   `.github/workflows/m3-production-grid.yaml` with
   `on: workflow_dispatch`. After-task §10 of PR #182's report
   has the detailed sequencing.
2. **Pat-led PR for pkgdown findings #2 + #4** (per §3 above).
3. **M3 figure cascade** (Florence's first concrete work).
   Hangs off the M3.3 production grid output. Design 46 (PR #178)
   ratified the visualization grammar + figure gate.
4. **M3.5 derived-quantity coverage** (extend coverage_study to
   communality, repeatability, phylo_signal).
5. **Rose + Darwin in-prep citation triage** (per §3 finding #3).
6. **M2.5 / M2.6 final checkpoint** — held until M3 closes per
   ROADMAP.
7. **M2.7 / M3.7 / M3.8 close gates** — phase-close artefacts.

## 6. Persona-active context for codex

Per `AGENTS.md` Standing Review Roles (14 named personas):

- **Ada** — orchestrator + maintainer relay.
- **Boole** — R API + formula parser.
- **Gauss** — TMB likelihood + numerical.
- **Noether** — math-vs-implementation alignment.
- **Darwin** — ecology / evolution audience framing.
- **Fisher** — statistical inference (CI machinery).
- **Emmy** — R package architecture.
- **Pat** — applied-PhD user reading.
- **Jason** — literature / scout / cross-package landscape.
- **Curie** — simulation / testing fidelity.
- **Grace** — CI / pkgdown / CRAN mechanics.
- **Rose** — systems audit / pre-publish / scope honesty.
- **Shannon** — cross-team coordination + register row
  ownership (**this report's author**).
- **Florence** (added 2026-05-18 in PR #178) — scientific
  illustrator + figure gate (5 dimensions: Interpretability,
  Uncertainty, Evidence, Accessibility, Composability).

Codex team historically owned `src/gllvmTMB.cpp` + a substantial
share of `R/fit-multi.R` engine work. The 2026-05-14 maintainer
guidance ("codex might not come back so you should plan to do
it") reassigned those lanes to Claude on a working-assumption
basis. **The maintainer activating codex now is the formal
return cue**; the coordination-board's "Codex-absent
assumption" should be revised accordingly when codex confirms
return.

## 7. Open questions for codex (review priorities)

These are the items where Claude is least confident and a codex
second-opinion would be highest-value:

1. **Engine-side review of PR #181 + #182** — both touch
   `R/fit-multi.R` initial parameter assignment and the phylo
   VCV preparation block. Codex's historical ownership of the
   TMB engine path makes a numerical-correctness review high-
   value.
2. **Cross-PR consistency between #181 and #182**: both touch
   `R/fit-multi.R` at non-overlapping line ranges (#181 at
   lines ~990 / ~1048 / ~1092; #182 at lines ~1195 / ~1660).
   Codex review on whether the two changes interact (e.g., does
   warmup play nicely with sparse-Ainv inputs?) is welcome.
3. **The pkgdown families gap** (audit finding #2) — does the
   fix `has_keyword("families")` → `- families` produce the
   intended UX, or does pkgdown still split the 27 aliases
   weirdly? Codex / Grace verification by running
   `pkgdown::build_site()` locally on the fix branch is the
   gate.
4. **Honest-scope statement on M3.4** — Design 48 §4
   ("Out of scope for M3.4: cluster + interactions in the
   univariate fit"). Does PR #182's actually-implemented
   `intercept-only` warmup live up to this scope statement, or
   are there hidden assumptions (e.g., that the per-trait
   univariate fit's intercept maps cleanly back to b_fix's
   trait-specific entries) worth flagging?

## 8. Key files for codex onboarding

- `AGENTS.md` — Standing Review Roles + persona-active naming
  + design rules (10 rules).
- `CLAUDE.md` — Claude-specific operating rules (verify locally
  before push; never `--no-tests` etc.).
- `ROADMAP.md` — current phase M3 (boundary-regimes); M3.3
  production grid is the next slice gate.
- `docs/design/35-validation-debt-register.md` — register; row
  walks per PR.
- `docs/design/47-sparse-pedigree-ainv.md` — Design 47 + §10
  follow-on (engine pass-through, PR #181).
- `docs/design/48-m3-4-boundary-regimes.md` — Design 48
  (warm-start + phi-clamp strategy, PR #180 merged).
- `docs/dev-log/coordination-board.md` — live coordination
  doc; codex should update on return.
- `docs/dev-log/after-task/2026-05-18-*.md` — 4 after-task
  reports from today (sparse-pedigree-ainv-helper, sparse-
  pedigree-ainv-engine, m3-4-implementation, m3-3a-profile-
  primary, florence-recruitment).
- `docs/dev-log/audits/2026-05-18-cross-package-count-inference-scout.md`
  — shareable with drmTMB team per maintainer.
- `docs/dev-log/audits/2026-05-18-noether-nbinom2-identifiability.md`
  — backing audit for M3.4 design.
- `docs/dev-log/check-log.md` — durable lessons (most recent:
  Kaizen #11 on cascade discipline).

## 9. Operational handoff state

- **Claude branch state**: all in-flight branches pushed to
  origin (`agent/sparse-pedigree-ainv-engine`,
  `agent/m3-4-warmstart-phi-clamp`,
  `agent/pkgdown-pedigree-ainv-sparse`); no uncommitted work.
- **Local working directory**: clean on `main` (last sync at
  the start of this handover write).
- **CI watchers armed**: Monitor tasks `bwmsqd0di` (#181),
  `b20hzzlgm` (#182), `bh3sdecjw` (#183). These will fire
  notifications on per-OS green / fail events. If codex takes
  the wheel, those notifications still arrive in this Claude
  session; codex should plan around them.
- **Self-merge authority**: per `AGENTS.md` standard, docs-only
  / dev-log / single-line config / audit / after-task PRs may
  self-merge when CI is green. PRs #181 + #182 are engine R/
  changes — these traditionally got a Codex sign-off; under the
  Codex-absent assumption Claude self-merged after the full
  persona review surface. **Codex should consider whether to
  request a revert + re-review on either #181 or #182 if the
  engine-side review surfaces concerns.**

## 10. Recommendation to maintainer

When codex confirms return and accepts handover:

1. **Update `coordination-board.md`**: revise the
   Codex-absent assumption (effective 2026-05-14) → Codex
   resumed 2026-05-18.
2. **Codex first-pass priorities** (Shannon's lean):
   (a) Verify PRs #181 + #182 engine changes don't conflict
       (cross-PR review).
   (b) Implement the Pat-led pkgdown fix for audit findings
       #2 + #4 (small, mechanical, ships fast).
   (c) Pick up M3.3 production grid as the natural next slice
       gate.
3. **Open question for the maintainer**: should the in-prep
   citation triage (audit finding #3) be a Rose-Darwin PR
   inside the current M3 phase, or held until Phase 1e (final
   Rose pre-publish sweep)?

## 11. Status

| Channel | Status | Evidence |
|---|---|---|
| Open PRs | 3 in CI; expected green within ~30 min | `gh pr list --state open` |
| Local main | Clean | `git status` |
| Test suite (last full run) | 122 PASS pedigree/animal/phylo (PR #181 verification); 55 PASS on M3.4 / nb2 / stage33 filter (PR #182 verification); R CMD check 0 errors on both | After-task reports §4 + §5 |
| pkgdown CI on main | Red (`pedigree_to_Ainv_sparse` missing); fixes by PR #183 | `gh run list --workflow=pkgdown` |
| Validation-debt register | Coherent; 3 rows walked today (ANI-08, MIS-16, MIS-17); all backed by test evidence | Section 4 above |
| Persona-active naming | Active in all 5 today's after-task reports | grep §7 of each report |
| Memory-OS discipline | Active; §3a Decisions block applied to all today's reports | inspect any 2026-05-18 after-task report §3a |
| Codex coordination board | Stale (still under 2026-05-14 Codex-absent assumption); needs revision on codex return | `docs/dev-log/coordination-board.md` |

**Bottom line**: main is in a coherent state; the 3 PRs in
flight are independent and ready for codex's engine-side
review pass; the pkgdown audit surfaced 4 findings with 1 fix
already in flight (#183) and 3 deferred. Codex picks up here.

## 12. Final handover decision (maintainer 2026-05-18)

Maintainer ratified **option 3** (hybrid): self-merge #183 only
(1-line pkgdown reference-index fix unblocking the red pkgdown
workflow on main); hold **#181** (sparse-Ainv engine pass-through)
and **#182** (M3.4 implementation) for **codex pre-merge review**.

### Final action plan (executed at handover):

1. **#183 (pkgdown fix)** — self-merge when 3-OS green. This is
   trivial (1 line in `_pkgdown.yml`) and unblocks the
   `pedigree_to_Ainv_sparse` missing-topic error that has been
   making pkgdown CI red on main since PR #179.
2. **#181 (sparse-Ainv engine)** — **HOLD for codex**. 3-OS
   green already; ready for codex engine-side review per §2
   above. Codex decides merge / revert-and-re-engineer.
3. **#182 (M3.4 impl)** — **HOLD for codex**. CI in progress at
   handover time; codex picks up watching the CI completion and
   reviews per §2 above.

### Persona-active note on the handoff

Boole + Gauss + Curie + Pat + Fisher + Rose all engaged in the
2026-05-18 push. The persona-active naming convention
(maintainer 2026-05-16: *"I like drmTMB team actually saying
the name of who's doing what"*) is **active** in every today's
after-task report (§7 per-persona contributions).

When codex picks up, the natural extension is to add a codex-
persona §7 entry to the after-task report on any PR codex
modifies or reviews substantively — preserving the lineage of
"who did what" through the handoff.

— Shannon, 2026-05-18, on handoff to codex team
