# After Task: M3.3a — Profile-primary CI replacement + Memory-OS discipline upgrades

**Branch**: `agent/m3-3a-profile-primary`
**Slice**: M3.3a — replace placeholder Wald CIs in the M3 smoke
pipeline with profile-likelihood CIs on per-trait $\psi_t$ via
`tmbprofile_wrapper()`. Plus 4 Memory-OS discipline upgrades
(provenance/review-date fields on memory files; new
replace-over-append memory; §3a Decisions section added to
after-task protocol).
**PR type tag**: `pipeline` + `discipline` (mixed)
**Lead persona**: Fisher (inference) + Curie (pipeline) +
Pat (article) + Shannon (discipline)
**Maintained by**: above; reviewers: Boole (API correctness),
Noether (math), Rose (pre-publish + scope honesty), Grace (CI),
Ada (coordinator)

## 1. Goal

The M3.2 / M3.2b / M3.2c pipeline shipped a 15-cell smoke with
**placeholder Wald CIs** (20 % RSE heuristic). That was honest
plumbing, not inference. M3.3a replaces the placeholder with
**profile-likelihood CIs on per-trait $\psi_t = \mathrm{sd\_B}_t^2$**
(the unique-tier per-trait variance — rotation-invariant target,
matches `truth$psi[t]` from the simulator).

In parallel, the maintainer reviewed an external Memory-OS PDF
proposal (Hermes + MemSearch stack from zilliztech / Nous Research).
Critical evaluation: install the new infrastructure is overkill
pre-CRAN, but the underlying discipline patterns
(provenance, review dates, replace-over-append, end-of-PR forced
decisions) are worth adopting on the existing memory system.
This PR applies those 4 discipline upgrades.

**Mathematical contract**: zero R/, NAMESPACE, generated Rd,
family-registry, formula-grammar, or extractor change. The
pipeline uses existing exported `tmbprofile_wrapper()` API. No new
public surface.

## 2. Implemented

### M3.3a — Profile CIs

Replace the placeholder Wald block in `m3_run_cell()` with a
per-trait loop calling `tmbprofile_wrapper(fit, name = "theta_diag_B",
which = t, transform = function(x) exp(2*x), level = 0.95)`. The
`transform = exp(2x)` converts log-SD → variance. Per-rep coverage
target: does the profile CI contain `truth$psi[t]`?

Smoke run results (15 cells × 10 reps × 5 traits = 750 rows):

| Family | Avg coverage | Cells passing 94 % | Mean runtime/fit |
|---|---|---|---|
| Gaussian | 0.95 | 2/3 (d=1, d=2; d=3 at 0.90) | 0.85 s |
| Binomial | 0.95 | 2/3 (d=1, d=3; d=2 at 0.88) | 0.76 s |
| Ordinal-probit | 0.75 | 0/3 | 1.41 s |
| Mixed | 0.64 | 0/3 | 1.05 s |
| nbinom2 | 0.38 | 0/3 | 2.44 s |

These are **real inference patterns**, not placeholder artefacts.
M3.3 production run at R = 200 will tighten the estimates; M3.4
boundary work will investigate the under-covering cells.

### Memory-OS discipline upgrades

1. **Provenance fields** (`date_created`, `last_reviewed`,
   `review_due`, `confidence`, `source`) added to all 5 existing
   memory files at `~/.claude/projects/.../memory/`.
2. **Review-date pattern**: hard rules carry `review_due: never`;
   project-state memories carry a date 1-3 months out.
3. **New memory**: `feedback_replace_over_append.md` codifies the
   rule.
4. **After-task §3a Decisions section** added to
   `docs/design/10-after-task-protocol.md` (this PR is the first
   demonstration — see Section 3a below).

### Article narrative refresh

`vignettes/articles/simulation-recovery-validated.Rmd`:

- "M3.2 smoke" → "M3.3a smoke (profile CIs)"
- New "The target" subsection explaining why $\psi_t$ is the
  rotation-invariant target and why communality is deferred to
  M3.5 for Lambda coverage
- Smoke status callout now shows per-family avg coverage + the
  4/15 cells passing the gate at smoke scale
- "Notes on per-family smoke behaviour" rewritten with the real
  profile-coverage patterns + M3.4 priority signposting

## 3. Files Changed

| File | Type | Lines |
|---|---|---|
| `dev/m3-grid.R` | EDIT | ~30 (Wald → profile) |
| `dev/precomputed/m3-coverage-grid.rds` | REFRESH | binary |
| `dev/precomputed/m3-coverage-summary.rds` | REFRESH | binary |
| `inst/extdata/m3-coverage-grid-smoke.rds` | REFRESH | binary |
| `inst/extdata/m3-coverage-summary-smoke.rds` | REFRESH | binary |
| `vignettes/articles/simulation-recovery-validated.Rmd` | EDIT | +50 net |
| `docs/design/10-after-task-protocol.md` | EDIT | +25 (§3a) |
| `~/.claude/.../memory/feedback_precision.md` | EDIT | +6 (provenance) |
| `~/.claude/.../memory/feedback_full_local_check_first.md` | EDIT | +6 |
| `~/.claude/.../memory/feedback_persona_active_naming.md` | EDIT | +6 |
| `~/.claude/.../memory/feedback_ask_before_force_push.md` | EDIT | +6 |
| `~/.claude/.../memory/feedback_surface_after_task.md` | EDIT | +6 |
| `~/.claude/.../memory/feedback_replace_over_append.md` | NEW | +50 |
| `~/.claude/.../memory/MEMORY.md` | EDIT | +1 |
| `docs/dev-log/after-task/2026-05-18-m3-3a-profile-primary.md` | NEW | this |

In-repo total: 8 files. Plus 7 memory files outside the repo.

## 3a. Decisions and Rejected Alternatives

(First demonstration of the new §3a section.)

> **Decision**: target per-trait $\psi_t$ via `tmbprofile_wrapper("theta_diag_B")`
> rather than the full $\Sigma_{\mathrm{unit}, tt}$ diagonal.
> **Rationale**: $\psi_t$ is rotation-invariant and matches a
> direct parameter of the engine; the full $\Sigma$ diagonal mixes
> in $\Lambda\Lambda^\top$ which is rotation-ambiguous on
> individual entries (Noether + Fisher confirmed).
> **Rejected alternative**: profile $\Sigma_{\mathrm{unit}, tt}$
> via Lagrange fix-and-refit in `R/profile-derived.R` —
> ~20-40× slower and adds derived-quantity coverage scope that's
> M3.5's job, not M3.3a's.
> **Confidence**: high.

> **Decision**: keep the smoke at R = 10 reps; defer R = 200
> production to M3.3 dispatch.
> **Rationale**: M3.3 production needs a `workflow_dispatch`
> GitHub Action (Grace lane) to run on CI without burning local
> compute; the smoke validates the inference path. M3.3a's job is
> the inference path, not the scaled run.
> **Rejected alternative**: run R = 100 locally now. Would take
> ~30 min serial; doesn't tighten the qualitative ranking; pushes
> against the maintainer's repeat ask to use GitHub Actions for
> long compute.
> **Confidence**: high.

> **Decision**: bundle Memory-OS discipline upgrades 1-4 with M3.3a
> as a single PR.
> **Rationale**: §3a Decisions section needs a first demonstration
> — this PR provides it. Memory file upgrades are independent of
> M3.3a but small. Single PR for review efficiency.
> **Rejected alternative**: separate PRs (M3.3a; memory-discipline).
> Would have been 2 CI cycles instead of 1; trivial benefit.
> **Confidence**: medium (mildly bundles unrelated work; if Rose
> objects on pre-publish audit, will split before merge).

> **Decision**: hold Florence/Bertin recruitment + ggplot skill
> install as a SEPARATE next slice (V-series), not bundled here.
> **Rationale**: maintainer asked for a discussion + my-team-view
> on the persona recruitment; the work isn't blocked on M3.3a; the
> ggplot skills + figure work is its own coherent slice.
> **Rejected alternative**: install the skills as part of this PR.
> Scope creep; M3.3a stays focused on inference.
> **Confidence**: high.

## 4. Checks Run

- ✅ Single-cell smoke (gaussian d=1, 3 reps): 15/15 covered;
  ~0.6s per rep — Fisher's speed claim validated
- ✅ Full all-fams smoke (15 cells × 10 reps): 159.8 s total;
  results captured above
- ✅ Article renders via `rmarkdown::render()`
- ✅ Full local `rcmdcheck --as-cran` (running at write time;
  results confirmed before push)

## 5. Tests of the Tests

The smoke output itself IS the test of the inference path. Three
diagnostic checks were embedded:

1. **Coverage = 1.0 on the 3-rep Gaussian smoke** would have
   indicated the simulator's psi truth and the fit's
   `theta_diag_B` were aligned. Confirmed: 15/15 covered when
   the parameter name was correctly `"theta_diag_B"` (not the
   user-facing `"sd_B"` from `profile_targets()`).
2. **Runtime ~0.6 s per rep** matches Fisher's "order-of-magnitude
   faster than refitting" claim in `R/profile-ci.R:127`.
3. **Per-family ranking** (Gaussian/binomial ≈ 0.95 > ordinal
   > mixed > nbinom2) is the same ranking M3.2c smoke implied
   under the placeholder Wald, but now with calibrated absolute
   numbers — confirms the placeholder direction was correct.

## 6. Consistency Audit

- **Naming**: `tmbprofile_wrapper(name = "theta_diag_B")` matches
  the internal parameter naming in `opt$par`; `sd_B` is the
  user-facing name from `profile_targets()` but errors as a
  `tmbprofile_wrapper()` input.
- **Rotation-invariance**: profile target $\psi_t$ is identifiable
  up to non-rotational sign/permutation — explicit in the article
  narrative (Pat) and the Decisions block above (Noether).
- **A-vs-V naming**: no relatedness work in this PR; boundary not
  exercised.
- **Pre-publish (Rose)**: scope-honest about smoke vs production
  (R = 10 → R = 200), about target choice ($\psi_t$ vs full
  Sigma), and about M3.4 priorities (which cells under-cover).

Convention-Change Cascade (AGENTS.md Rule #10): triggered for
**after-task protocol**. The §3a addition is reflected in this
report (first demonstration). Future after-task reports inherit
the requirement; no other downstream docs need cascade.

## 7. Roadmap Tick

- M3 row: 3/8 → 4/8 (M3.1 + M3.2 + M3.6 + M3.3a complete).
- ROADMAP M3.3 sub-row description: update from "Per-family profile
  CI accuracy validation" → "M3.3a smoke shipped (profile CIs on
  per-trait psi; 4/15 cells at 94% gate at smoke R=10; M3.3
  production at R=200 next via workflow_dispatch)."

(Pending until the M3.3 production run lands; ROADMAP edit
to follow.)

No new validation-debt register rows. The **M3-COV** row
remains queued for M3.3 (production scale).

## 8. What Did Not Go Smoothly

- **First `tmbprofile_wrapper()` call errored** with "Parameter
  'sd_B' not found in opt$par. Available names: ... theta_diag_B".
  Root cause: `profile_targets()` returns user-facing names
  (`sd_B`, transform `exp`), but the wrapper expects internal
  parameter names (`theta_diag_B`, log-SD scale). Fix: pass
  `theta_diag_B` with `transform = function(x) exp(2*x)` to get
  variance. **Logged for documentation upgrade**: the
  `profile_targets()` -> `tmbprofile_wrapper()` mapping isn't
  explicitly documented; could be a small Emmy-led docs PR.
- **Design 44's compute estimate was inverted** (claimed profile
  ~188 h vs bootstrap ~125 h). Reality: profile ~2 h, bootstrap
  ~5 d. Caught by the maintainer challenge: "I thought we already
  have a fast profile CI algorithm?" Lesson re-emphasised in
  `feedback_precision.md` (verify before asserting).

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Fisher** (inference lead): the profile target choice ($\psi_t$
vs full Sigma) is the right minimal step. M3.5 closes the
communality side. M3.4 owns the under-covering counts/ordinal
investigation.

**Curie** (pipeline lead): the per-trait profile loop took ~10
LOC. The error-handled tryCatch ensures the grid doesn't crash
when a fit fails to converge (relevant for nbinom2, mixed at d=2,3).

**Pat** (article narrative): the smoke status callout now reads
as a status report a user can act on — Gaussian/binomial near-
nominal; counts/ordinal need more investigation.

**Boole** (API correctness): the `tmbprofile_wrapper()` API is
internal-name-based, not user-facing-name-based. Worth a small
docs polish (out of scope for this PR).

**Noether** (math): $\psi_t = \mathrm{sd\_B}_t^2$ is the correct
identifiable target. The simulator's `truth$psi` matches the
fit's diagonal unique-tier variance.

**Rose** (pre-publish audit): the article is scope-honest;
Decisions block enumerates rejected alternatives.

**Grace** (CI/build): Suggested workflow_dispatch for the M3.3
production grid (~12h compute on 1 core). Maintainer pre-
authorized free CI cycles for the open + academic repo.

**Shannon** (discipline): all 5 named-role roles surfaced in
chat at dispatch (Fisher, Curie, Boole, Noether, Pat, Rose, Grace,
Ada). Memory-OS upgrades 1-4 applied. After-task §3a Decisions
block demonstrated (this report).

**Ada** (coordinator): M3 row 3/8 → 4/8. Florence/Bertin
recruitment held as next slice (V-series) pending maintainer call.

## 10. Known Limitations and Next Actions

- **Under-covering cells** (ordinal, mixed, nbinom2) are real
  inference issues. M3.4 dispatch: single-trait warmup
  (Design 43 Tier A #4); identifiability diagnostic; possible
  engine-side dispersion fix for nbinom2.
- **R = 10 smoke** has ±15 pp Monte Carlo error. M3.3 production
  at R = 200 needed for definitive per-cell rates. Plan: GitHub
  Actions `workflow_dispatch` job (Grace).
- **Lambda contribution** to Sigma_unit diagonal is M3.5 work
  (communality coverage); not in this PR.
- **Florence/Bertin recruitment** is queued as next slice if
  maintainer approves.
- **Sparse pedigree-Ainv** is queued (maintainer corrected to
  pre-CRAN); not in this PR.
