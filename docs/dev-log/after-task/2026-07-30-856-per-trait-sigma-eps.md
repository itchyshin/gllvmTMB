# After Task: per-trait gaussian/lognormal residual SD (#856)

**Branch**: `claude/856-sigma-eps-archaeology-20260730`
**Date**: `2026-07-30`
**Roles (engaged)**: Ada (orchestration, archaeology, independent verification), Curie
(validation fixtures), Gauss (engine + consumers), Rose / statistical-reviewer
(adversarial gate), Melissa (reconciliation)

## 1. Goal

#856 asked one gating question before any work: is the single scalar `log_sigma_eps`
(`src/gllvmTMB.cpp:582`), shared across every gaussian and lognormal row, **deliberate or
incidental**? The answer decided whether #856 was a documentation gap or a capability gap,
and it gates #855, because under per-trait scales one fitted `sigma_eps` back-transforms to
`T` raw values. The archaeology answered *incidental*; Shinichi then chose the capability
fix, sequenced **before** #855. This arc is that fix and nothing else.

## 2. Implemented

- `log_sigma_eps` is a `PARAMETER_VECTOR` of length `n_traits`, mirroring the
  `log_sigma_student` template that Student-t (fid 9) has always used. Gaussian and
  lognormal traits each estimate their own residual SD.
- The Q7 auto-suppression guard is evaluated **per trait** rather than dataset-wide, because
  a mixed design can replicate one trait and not another. The map becomes `NA` for suppressed
  traits and sequential levels for estimated ones; the message names the affected traits.
- The consumer surface is trait-aware: `residuals()`, `predict()`, `simulate()`,
  `.draw_y_per_family()`, `VP()`, and `check_gllvmTMB()` (now one boundary row per trait,
  with single-trait output unchanged).
- Three `opt$par["log_sigma_eps"]` name lookups migrated to the existing `.par_indices()`
  helper. TMB gives every element of a `PARAMETER_VECTOR` the same name and R's
  single-bracket lookup returns only the first match, so these had been silently using
  trait 1.
- `.gllvmTMB_sigma_eps_mapped_off()` returns a per-trait logical vector instead of
  `all(is.na(...))`. Partial suppression was unreachable before this arc and is reachable now.
- A silent-skip fixed: the VGH warm start gated on `length(...) == 1L` and would have stopped
  applying the moment the parameter became a vector — the exact silence the surrounding
  comment in that file warns about.

**Three further fixes came out of the adversarial gate, which returned DO-NOT-SHIP.** They are
listed here rather than buried, because two of them were regressions this arc introduced:

- **Traits with no continuous rows.** A gaussian + Poisson fit left `log_sigma_eps[2]` with no
  data — an exactly flat direction, gradient identically zero, `pdHess` TRUE→FALSE, Hessian rank
  5/5→NA/6, and a frozen `lm` start value reported as `boundary_sigma_eps_t2 PASS 1.78`. The old
  shared scalar was identified by any gaussian row anywhere, so this failure mode is created by
  the promotion. Suppression now also covers traits with no family id in {0, 3}, and
  `check_gllvmTMB()` no longer reports a residual scale for a trait that has none.
- **Silent boundary collapse.** On the canonical one-row-per-cell layout with a shared low-rank
  score, a per-trait residual SD can be driven to zero because the latent score absorbs that
  trait's variation; 13 of 20 seeds collapse, every one with `conv = 0` *and* `pdHess = TRUE`.
  `sigma_eps_thresh` is an absolute magnitude and missed 11 of the 13. The boundary check now
  also fires on a scale-relative criterion (13/13 caught, no false positives on healthy fits),
  and the cost is disclosed in `NEWS.md`.
- **One trait mixing identity- and log-scale rows** produced a single residual SD spanning both
  (measured 5.0008 where the gaussian rows have sd 3.0 and the lognormal rows log-scale sd 0.2),
  reported without qualification while `link_residual_per_trait()` already returned NA for the
  same case. Now warned at fit time.

**Resolved as a side effect, and worth stating explicitly.** #856 raised the gaussian↔lognormal
sharing as a *separate* and harder-to-justify defect: one parameter serving an identity-scale
family and a log-scale family at once. Making it per-trait resolves that automatically, because
family is assigned per trait in the ordinary case — a lognormal trait now owns its own log-scale
residual SD and a gaussian trait its own identity-scale one, with no shared parameter between
them. The one case this does **not** resolve is a single trait carrying rows of both families,
since family is per-row; that remains open and is listed under limitations. No documentation
change was needed at `R/extract-sigma.R:513` ("`sigma_eps` already models the log-scale
residual"), which was checked and is still correct.

## 3. Files Changed

**Engine** — `src/gllvmTMB.cpp` (5 code sites: `:312` comment, `:584` declaration, `:2105`
compute + REPORT, `:2121` gaussian density, `:2153` lognormal density)

**R** — `R/fit-multi.R` (per-trait start values, map, the per-trait guard, warm-start shape
match), `R/vgh-warmstart.R`, `R/predictive-diagnostics.R`, `R/methods-gllvmTMB.R`,
`R/output-methods.R`, `R/diagnose.R`, `R/unique-keyword.R` (roxygen)

**Tests** — new `tests/testthat/test-sigma-eps-per-trait.R`,
`tests/testthat/test-sigma-eps-per-trait-consumers.R`; updated `test-confint-inspect.R`,
`test-coverage-study.R`, `test-lme4-style-weights.R`, `test-missing-predictor-{binary,
categorical,ordered}.R`, `test-phylo-latent-slope-gaussian.R`, `test-profile-targets.R`

**dev/** — `856-sigma-eps-pooled-cost.R`, `856-sigma-eps-degenerate-probe.R`,
`856-sigma-eps-mixed-design-guard.R`

**docs/** — `NEWS.md`; `docs/dev-log/audits/2026-07-30-856-sigma-eps-deliberate-or-incidental.md`;
`docs/dev-log/audits/2026-07-30-sigma-eps-consumer-map.md`;
`docs/dev-log/audits/2026-07-30-856-adversarial-review.md`; this report

## 3a. Decisions and Rejected Alternatives

**Decision: the scalar is incidental, so #856 is a capability gap.** Rationale, re-derived
from git rather than from summaries: the scalar originally pooled *three* families and the
pooling was already ruled a defect once (`dff9b363`, titled `fix:`, decoupled gamma); #622's
proposed fix had two clauses and only the gamma one shipped, with the second — "make the
Gaussian/lognormal residual SD per-trait as well" — never implemented before the issue was
closed as already-fixed; and this same engine already gives Student-t a per-trait
identity-scale SD and delta-lognormal a per-trait log-scale SD. *Rejected*: documentation-only.
*Confidence*: high on the archaeology, which is documentary.

**Decision: sequence #856 before #855.** #855 must make `sigma_eps` trait-aware on the way out
regardless; doing #856 first collapses its back-transform from a one-value→`T`-values semantic
change into a per-trait multiply. *Rejected*: folding it into #855. *Confidence*: high.

**Decision: the guard suppresses per trait, not dataset-wide.** *Rejected*: fail-loud on the
degenerate case — main already treats this collapse as routine and non-fatal (clean
convergence, informative message, graceful fixed value), so failing loud would be a UX
regression against shipped behaviour. *Confidence*: high; verified on a mixed fixture.

**Decision: leave `R/julia-bridge.R:2265/:2379` scalar.** GLLVM.jl's `sigma_eps` is genuinely
scalar by its own design — `σ_eps::Real` at `likelihood.jl:73` and
`likelihood_sparse_phy.jl:110`, packed as a single float beside a `σ_phy` Vector at
`em_squarem.jl:59-60`. Vectorising the bridge would introduce a regression, not fix one.
*Confidence*: high; verified in the twin repo directly.

**Decision: leave #622 closed, correct it by comment.** #856 is open and states the gap
precisely; reopening would duplicate it. Comment posted.

**Rejected claim — twin parity.** An early supporting argument was that GLLVM.jl already
treats the residual per-trait, per the 2026-07-03 twin-review note ("Julia folds residual into
`diag(psi)`"). That note is **false**, verified at code level. Both implementations pool. The
argument was withdrawn rather than quietly dropped, and the verdict rests on the three
gllvmTMB-internal lines instead.

## 4. Checks Run

**Adversarial gate** (`docs/dev-log/audits/2026-07-30-856-adversarial-review.md`) —
**DO-NOT-SHIP** on first pass: REFUTED 3, SURVIVES 3, UNCERTAIN 1. Every regression claim
measured against a recompiled pre-fix worktree at `16aeb208`. Both blockers subsequently fixed
(`95cfa10a`, `95e41882`, `0e633f5b`) and each fix verified on its own reproducing design.

**Targeted measurements**, all re-run by the orchestrator rather than accepted from a report:

```sh
Rscript --vanilla dev/856-sigma-eps-pooled-cost.R
#   sigma_eps = 0.19695, 2.0116 vs true 0.2, 2.0 (model-free check: 0.197, 2.012)
Rscript --vanilla dev/856-sigma-eps-mixed-design-guard.R
#   map `1, NA`; sigma_eps[1] = 0.50165 vs true 0.5; message names "t2"; 3/3 pass
# gaussian + poisson (blocker 1): map `1, NA`; pdHess TRUE; rank 5/5 PASS;
#   free log_sigma_eps 2 -> 1; no fabricated boundary row
# 20-seed collapse sweep (blocker 2): 13/20 collapse; 13/13 now WARN (was 2/13);
#   no false positives on healthy fits
# mixed identity/log-scale trait (item 3): warning fires on trait "A", pooled value 5.0008
Rscript --vanilla -e 'devtools::document(quiet = TRUE)'   # only man/diag_re.Rd; NAMESPACE untouched
```

**Scale-equivariance oracle** (`dev/scale-equivariance-check.R`, both blocks) — run because the
plan's VERIFY list required it, with the prediction "not expected to move". It did not move.
Results are identical to the baseline recorded in the script header from `origin/main`:

```
k = 100 : Lambda 1.3e-4, fixed 9.3e-5, Sigma 1.3e-4, correlations 1.3e-4,
          communality 2.5e-4, logLik exact              -- all OK
k = 5000: every law VIOLATED, rel.err 1 on Lambda/Sigma/correlations/communality,
          fixed effects 9.5% out, logLik 49 units out   -- unchanged from main
```

This is the intended negative result: #856 is not a fix for #851 and does not pretend to be. It
neither improves nor regresses the scale-constant class.

**Full suite and `--as-cran`: PENDING.** The first full run was stopped because it was executing
code from four commits earlier; the authoritative run is against the post-gate tree. Results are
written here before this report is treated as closed. Nothing above claims a check that was not
run.

## 5. Tests of the Tests

`test-sigma-eps-per-trait.R` was written **before** the fix and confirmed failing on `main`
for the right reason:

```
Expected `sigma_eps_hat` to have length 2. Actual length: 1.
sigma_eps[1] actual 1.3, expected 0.2;  sigma_eps[2] actual NA, expected 2.0
```

It asserts explicitly that Q7 auto-suppression did **not** fire on its fixture, so the failure
cannot be misread as an identifiability collapse. Post-fix it passes 4/4, recovering
`c(0.2029, 1.8381)`.

Independently reproduced by Ada on a **different seed and DGP** (`dev/856-sigma-eps-pooled-cost.R`,
seed 2026): `sigma_eps = 0.19695, 2.0116` against true `0.2, 2.0`, agreeing with a model-free
within-cell estimator (`0.197, 2.012`) to three decimals. Pre-fix the same fit returned a
single `1.4292` — the root-mean-square compromise, which is exactly what one pooled gaussian
scale can represent.

The guard was verified on the design it exists for (`dev/856-sigma-eps-mixed-design-guard.R`,
seed 4242, t1 replicated ×4 and t2 not): map `1, NA`, `sigma_eps[1] = 0.50165` against true
`0.5`, `sigma_eps[2]` fixed at ~1e-3·sd(y), message `Trait affected: "t2".`

## 6. Consistency Audit

```sh
grep -n "sigma_eps" src/gllvmTMB.cpp                 # 7 hits, 5 code + 2 comment; all migrated
grep -rn "log_sigma_eps" R/                          # every site enumerated before editing
grep -rn "sigma_eps" R/ | grep "\[1L\]"              # only julia-bridge (by design) + 2 documented fallbacks
grep -rn 'opt\$par\["log_sigma_eps"\]' R/            # empty — all three migrated to .par_indices()
grep -rn "which(names(.*opt\$par)" R/                # confirmed the by-index convention this follows
grep -rn "sigma_eps" man/ NEWS.md vignettes/         # corrected #856's own under-count of the doc surface
```

## 7. Roadmap Tick

N/A — a correctness/capability repair under the existing gaussian and lognormal family rows,
not a new roadmap capability. No coverage or interval claim moves.

## 7a. GitHub Issue Ledger

- **#856** — the subject of this arc. Gating question answered (incidental); capability fix
  implemented. Left OPEN pending maintainer review and merge.
- **#622** — inspected and left CLOSED by decision; one comment posted
  (`issuecomment-5137858662`) recording that clause two of its proposed fix was never
  implemented and that the 2026-07-09 triage matched only clause one.
- **#855** — not touched. Deliberately fenced; this arc changes its design by making the
  back-transform a per-trait multiply.
- **#851** — not touched.

## 8. What Did Not Go Smoothly

Three self-inflicted issues, all caught by re-deriving instead of trusting an artifact — the
same failure mode the previous lane's handover warned about, which recurred anyway.

1. **My own reproducer lied.** `dev/856-sigma-eps-pooled-cost.R` called `library(gllvmTMB)`,
   loading the *installed* package. Run on this branch it reported `sigma_eps` length 1 at the
   old pooled value, i.e. that the fix had not worked, on a tree where it had. Caught only by
   actually running it. Fixed to `load_all()`.
2. **My own audit cited a file that did not exist.** The committed archaeology referenced "the
   cost script promoted alongside" the probe; that script was still in a session scratchpad.
   The citation was inaccurate the moment it was written.
3. **The consumer map had a blind spot I had to find separately.** The scout inventoried
   `sigma_eps` thoroughly (105 references, correctly classified) but the sharpest hazard lives
   under the *other* name, `log_sigma_eps`: three `opt$par["log_sigma_eps"]` lookups that
   silently return only the first element once the parameter is a vector. A grep scoped to the
   obvious token missed the dangerous case.

Also: **#856's own framing was wrong in one respect** and this arc corrected it. The issue
claimed `sigma_eps` is essentially undocumented; in fact several `man/` pages and three
vignettes carry it, and `R/unique-keyword.R:127` did state the singleness. The doc surface
needing update was *larger* than the issue implied, not smaller.

**The adversarial gate returned DO-NOT-SHIP, and it was right.** Two things it caught are worth
recording as process failures rather than just defects:

4. **A comment described a guard that was never written.** `src/gllvmTMB.cpp:312-314` was updated
   in the engine commit to say "a trait's entry is mapped off when no row of that trait has
   `family_id_vec(o)` in {0, 3}". `R/fit-multi.R` did not do that. The comment and the code it
   described were written in the same change, and the comment was untrue when written — the most
   expensive kind, because a later reader checks the comment and stops.
5. **I accepted a verdict I had asked to be verified, and it was wrong.** The
   `test-lme4-style-weights.R` failure was diagnosed as a fixture artefact and the fixture was
   strengthened. I did instruct that this be verified independently rather than assumed, which is
   the only reason it was caught — the gate measured 13/20 collapses against 0/20 pre-fix and
   refuted it. Had the brief said "confirm" instead of "try to refute", a genuine user-facing
   regression would have shipped recorded as a test-fixture detail.

The general lesson is the one the previous lane's handover already stated and which recurred here
anyway: a green suite is not evidence about paths the suite does not exercise. Every defect the
gate found was invisible to `conv`, to `pdHess`, and to the test suite.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Ada** — the prior-work sweep paid for itself twice: it surfaced that dispersion granularity
is a named twin-parameterization class already flagged as a merge-gated Discussion Checkpoint,
and it surfaced the #622 half-implementation that is the whole evidential basis of the verdict.
It also produced a *refutation* of one of my own supporting arguments, which is the sweep
working correctly.

**Gauss** — the guard, not the plumbing, was the risk, and the measurement changed its design.
Before measuring, the plan assumed the degenerate case needed a new guard; measurement showed
Q7 already handled it and that the real hazard was the narrower mixed design. Designing the
guard from the measurement rather than from the fear produced a smaller, more correct change.

**Rose** — two claims were withdrawn rather than softened: twin parity, and #856's
documentation-gap framing. A claim that does not survive checking should be removed from the
argument, not restated more weakly.

**Curie** — the test asserts the *absence* of the confound (Q7 did not fire) alongside the
recovery. Without that, a future failure of this test would be ambiguous between the defect it
targets and an unrelated identifiability collapse.

## 10. Known Limitations And Next Actions

- **The boundary collapse is mitigated, not removed.** A per-trait residual SD can still reach
  zero on a one-row-per-cell design with a shared low-rank score. It is now *detected* and
  *disclosed*, and replication cures it, but the underlying behaviour is a real consequence of
  removing the pooling. Whether to add a modelling-level guard (rather than a diagnostic) is a
  design question for the maintainer, not something to decide inside this arc.
- **A trait carrying both gaussian and lognormal rows** is still not separated by per-trait
  alone, since family is per-row. Now warned at fit time rather than silently pooled; splitting
  the scales into separate traits is the documented remedy.
- **`sigma_eps_thresh` remains an absolute magnitude** (`1e-4`). The new relative criterion sits
  beside it rather than replacing it. The absolute constant is an instance of the
  scale-dependent-constant class tracked in #851 and is deliberately left alone here.
- **Two defensive fallbacks retain `sigma_eps[1L]`** for callers that cannot supply a per-row
  trait index. The gate could not reach either on a multi-trait fit through a public entry point,
  so they are recorded as *not refuted* rather than proven unreachable.
- **The load-bearing tests are double-gated** behind `skip_if_not_heavy()` and `skip_on_cran()`,
  so they do not run in routine CI. That is the repo convention for heavy recovery tests, but it
  means the protection added here is only exercised deliberately. Worth a maintainer decision.
- **Next slice is #855**, whose back-transform this arc simplifies.
- 🔴 **Merge is maintainer-gated.** `src/gllvmTMB.cpp` + likelihood + dispersion granularity is
  the ROADMAP Discussion Checkpoint set. Implemented, verified and pushed; **not merged**.
