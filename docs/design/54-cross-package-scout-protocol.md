# Design 54 — Cross-package scout protocol

**Maintained by:** Jason (literature / cross-package scout), Curie
(simulation fidelity), Fisher (inference policy), Rose (scope
honesty), Shannon (coordination).
**Status:** Active design contract, ratified 2026-05-25.
**Triggered by:** the 2026-05-25 binomial-`psi` Scenario A signal
(PR #263). The four-round diagnostic that resolved that signal
took ~36 hours longer than it needed to because the first
framing was "the gllvmTMB engine looks wrong" and the team did
not start with a cross-package check. This design exists so the
next M3 / extractor / parameter-recovery signal that *looks* like
an engine bug doesn't get one.
**Backed by:**
[`audits/2026-05-25-jason-cross-package-binomial-sigma-scout.md`](../dev-log/audits/2026-05-25-jason-cross-package-binomial-sigma-scout.md),
PR #263, PR #264, PR #266.

## 1. Purpose

Before declaring an engine bug from a simulation signal — biased
estimator, low coverage, recovery failure — run a **minimum
viable cross-package scout** to falsify the engine-bug hypothesis.
This protocol gives the scout a shape: trigger conditions, a
minimum scout configuration, an N-sweep when feasible, and a
4-round template the 2026-05-25 case validated.

The protocol exists because engine-bug investigation is expensive
(reading TMB templates, instrumenting C++, designing minimal repros
in the engine) while a cross-package scout is cheap (one R script,
30 min). When the engine is correct and the simulation harness is
wrong, the scout finds out in round 2; the engine deep-dive would
have spent days.

## 2. When to invoke this protocol

Invoke before declaring an engine bug if **any** of these are true:

- A simulation harness reports point-estimate bias outside its
  pre-registered band (Design 50 §3) on a single family or
  family-group;
- An `m3-grid` or `coverage_study()` cell reports coverage
  substantially below 0.94 without a known mechanism;
- A parameter-recovery test fails on a family or random-effects
  structure that has previously passed;
- A persona consult (Fisher, Curie, Gauss) flags a result as
  "engine probably wrong" without already having a cross-package
  baseline.

Skip the protocol when:

- The signal is on a feature unique to gllvmTMB with no peer
  implementation (e.g. mixed-family latent-scale correlations);
- The signal is reproducible at single-rep scale with a known
  numerical mechanism (e.g. a TMB template gradient mismatch
  caught by `check_consistency()`);
- The bug is already a code path with a public-surface
  reproducer (issue + minimal repro + failing test);
- The signal is on the `psi` diagnostic target only, not
  `Sigma_unit_diag` (per Design 50 §3, profile-`psi` coverage
  is not a primary promotion target — a signal there is not
  sufficient to claim engine misbehaviour).

## 3. Minimum viable scout

A minimum scout is one R script that does **all** of:

1. **Reproduces the simulation harness DGP** exactly. Same
   `Lambda`, `psi` draw, latent factors, per-row family. The
   scout must not silently switch DGP (this is the most
   common scout-design mistake; in 2026-05-25 round 1, the
   first scout draft used a simpler DGP and missed the
   binomial `psi` row).
2. **Fits the same model in at least one sister package** on
   identical simulated data. Sister-package roster for
   gllvmTMB (per Design 04, `docs/design/04-sister-package-scope.md`):
   - **glmmTMB** — same TMB lineage; reference for fixed and
     simple random structures.
   - **gllvm** — variational-approximation peer; closest
     latent-factor competitor.
   - **galamm** — Laplace + autodiff GLM-LV peer with explicit
     `lambda` constraint matrix; closest API peer for
     stacked-trait + factor structure (no spatial / phylo / meta-V).
   - **sdmTMB** — spatial GLLVM peer (single-response only, but
     trustworthy for spatial Sigma).
   - **MCMCglmm / Hmsc** — Bayesian comparators; expensive,
     used only when the signal needs prior-vs-likelihood
     framing.
3. **Reports the same point estimate or extractor output** the
   gllvmTMB signal is computed on (e.g. median ratio on
   `Sigma_unit[tt]`, not on `psi`).
4. **Records seed, family, d, n_units, n_traits, n_reps,
   package versions** in the scout output.

A scout that does any of these things is *not* a minimum scout:

- Fits a different model (e.g. ignores `unique()` because the
  sister package can't represent it);
- Uses different data (e.g. real data instead of the simulation
  harness's DGP);
- Reports a different statistic;
- Cherry-picks one rep instead of running ≥ 10.

If the sister package can't represent the model, that is itself a
finding — record it and note that this scout cannot falsify the
engine-bug hypothesis on that feature.

## 3.5. Scope and attribution anti-patterns

Three confusions to avoid when invoking this protocol. Added
2026-05-25 per Codex review of the initial draft.

### 3.5.1. DGP scout vs. TMB-template / engine scout

Cross-package scouts are the right tool when you do not know
whether the bug is in your engine, your DGP, your estimand, or
your comparator code. They are the **wrong** tool when the change
under investigation is internal to your own TMB template or
engine R code.

If a PR modifies `src/gllvmTMB.cpp`, an R-side likelihood path,
or an estimator-gradient routine, the appropriate scout is an
**internal scout**: TMB-template diff, gradient check via
`TMB::checkConsistency()`, or parameter-recovery test against
the engine's previous version. Cross-package agreement at that
layer would confirm only that the bug is downstream of the C++
template, not that the template itself is correct.

The 2026-05-25 binomial-`psi` signal was a DGP-scout case
because the engine code in flight (`#257` / `#260` / `#261`)
had not changed any path that the simulation harness DGP
exercised. An internal scout would have produced no signal
because nothing internal had moved.

### 3.5.2. Family-design rulings vs. diagnostic-API work

A statement like *"binomial has no overdispersion parameter, so
DGP-side `psi` is unidentifiable"* is a **family-design
ruling**: it changes the simulation DGP (`dev/m3-grid.R`) and
the design docs that codify the harness rule
(`docs/design/42-m3-dgp-grid.md`). It does **not** change the
diagnostic-API code (`R/diagnose.R`, `R/diagnostic-tables.R`).

Locate the fix at the layer the wrongness lives at:

| Wrongness | Layer | File / doc |
|---|---|---|
| Family identifiability / DGP construction | DGP | `dev/m3-grid.R`, `docs/design/42-m3-dgp-grid.md` |
| Diagnostic output shape / table API | R-API | `R/diagnose.R`, `R/diagnostic-tables.R`, `docs/design/51-posterior-predictive-diagnostics.md` |
| Estimator gradient / Laplace step | TMB template | `src/gllvmTMB.cpp`, internal scout |
| Estimand definition (what truth means) | Design contract | `docs/design/50-m3-3b-surface-admission.md` §3 |

Conflating these layers attaches a fix to the wrong PR queue
and produces false-positive blame on adjacent lanes. The
2026-05-25 binomial-`psi` rule lived at the DGP layer; it did
not move the diagnostic-API lanes by a single line.

### 3.5.3. "Not implicated" vs. "not yet checked"

Saying *"engine lane X is not implicated by signal Y"* requires
**positive evidence**: typically that a fix at a different
layer (DGP, estimand, comparator, harness) resolves the signal
at its source while the engine code stays unchanged. The
2026-05-25 binomial signal cleared this bar — the DGP patch in
PR #263 + PR #264 shifted post-patch median ratios by +0.55
across binomial cells (PR #266 §3 evidence) with no engine
edit. That is *"not implicated."*

*"Not yet checked"* means: no scout has been run that could
discriminate between engine and non-engine causes for lane X.
Many lanes will be *"not yet checked"* at any given moment;
that is the default state when the scout protocol has not been
exercised against a particular lane. Do not silently promote
*"not yet checked"* to *"not implicated."*

Scout reports must state which attribution applies and cite
the evidence path. A scout that concludes *"engine X is not
implicated"* without an after-fix counterfactual is overstating
its reach.

## 4. The 4-round template

The 2026-05-25 case validated this sequence:

### Round 1 — Single sister package, same N

Fit `gllvmTMB` + one sister (typically `glmmTMB` or `gllvm`) on the
same simulated DGP at the harness's N. Report the same point
estimate on both.

- **If both packages agree and both look wrong**: the signal is
  not gllvmTMB-specific. Proceed to round 2.
- **If gllvmTMB looks wrong and the sister looks right**: the
  signal might be engine-specific. Proceed to round 3 (skip
  round 2; the falsification has not occurred).
- **If both look right**: no signal; close.

### Round 2 — Add a second sister package

If round 1 had both agreeing and both wrong, add a second sister
package. The 2026-05-25 case used `galamm` here. Confirming the
signal in a third independent implementation makes the
engine-bug hypothesis very unlikely.

- **If all three agree and all look wrong**: framing shifts from
  "engine wrong" to "DGP or estimand wrong". Proceed to round 3
  with the new framing.
- **If the second sister disagrees with gllvmTMB + the first
  sister**: framing has not stabilised; investigate the
  disagreement (typically API translation, identification, or
  family parameterisation).

### Round 3 — N-sweep

Run the simulation at ≥ 3 N values (e.g. N ∈ {120, 240, 480}).
Report the same statistic at each N.

- **If bias decreases monotonically with N**: the signal contains
  an unidentified component that washes out asymptotically. The
  signal is a DGP / estimand misspecification, not an engine bug.
  Proceed to round 4.
- **If bias is constant or grows with N**: the signal is more
  likely engine-side. Either (a) the engine has a bug, (b) the
  estimand is misspecified in a way that does not asymptote, or
  (c) the bias is rotation- or identification-related.
- **If bias is noisy and direction unclear**: run more replicates
  per N; the signal might be MCSE-limited.

The N-sweep is the diagnostic that flipped the framing in the
2026-05-25 case (ratios 0.42 @ N=120 → 0.71 @ N=480 falsified
"engine biased at all N").

### Round 4 — Domain-knowledge ratification

The signal now points at the DGP / estimand. Ask the maintainer or
the relevant lead persona (Gauss for TMB likelihood, Noether for
math-vs-implementation, Boole for parser-vs-spec, Fisher for
estimand definition) to ratify the proposed correction.

In the 2026-05-25 case, the ratification was one line: *"simulations
cannot have psi bit — as psi for binary emerges from binomial
error."* The Bernoulli has no scale parameter beyond π²/3 (logit),
so a DGP-side `psi` for binomial rows is unidentifiable by
construction. The fix was selective psi-zeroing in `m3_sample_truth()`
for binomial rows.

Lessons:

- A simulated estimand is not an estimand until a domain-knowledge
  consult ratifies it.
- Families with no overdispersion parameter (Bernoulli;
  ordinal-probit at fixed cutpoints) cannot have a DGP-side `psi`.
- The persona table for a ratification consult: Gauss + Noether
  for likelihood / numerical, Boole for parser / API, Fisher for
  estimand-definition, the maintainer for the final call.

## 5. Scout output requirements

A scout report (typically `docs/dev-log/audits/YYYY-MM-DD-<topic>-scout.md`)
records, at minimum:

1. **The signal**: which simulation harness cell, which statistic,
   what value, against what pre-registered band.
2. **The scout script**: `dev/<topic>-scout.R` or equivalent; the
   exact DGP-reproducing code, executable.
3. **Per-round results**: a row per round with package, N, statistic
   value, verdict (signal confirmed / falsified / shifted framing).
4. **Final attribution**: engine-bug / DGP-bug / estimand-misspec /
   identification-issue / inconclusive.
5. **Hand-off**: if the attribution is engine-bug, which engine
   lane owns the next step. If it's DGP-bug, which design doc /
   harness file needs patching. If inconclusive, what would
   discriminate (more N, more reps, more sister packages).

The 2026-05-25 audit
[`2026-05-25-jason-cross-package-binomial-sigma-scout.md`](../dev-log/audits/2026-05-25-jason-cross-package-binomial-sigma-scout.md)
is the worked example; future scouts mirror its structure.

## 6. Worktree and coordination rule

A scout that touches an engine-bug PR's blast radius **must** run
in a worktree separate from the engine PR's worktree. Per the
2026-05-25 coord-board rule (Shannon): when two agents are active,
they work in separate `git worktree`s on separate branches. The
scout script lives under `dev/` and is committable; the scout
output memo lives under `docs/dev-log/audits/`.

A scout must not silently amend the engine PR's check-log or
after-task report. If the scout's findings need to update a check-
log entry, that update is a separate PR after the scout closes,
to preserve the audit trail.

## 7. What this protocol does NOT do

- Does not require running a scout for every engine signal. The
  trigger conditions in §2 are the gate; skip when the signal is
  on a gllvmTMB-unique feature or already has a code-path repro.
- Does not require running all 6 sister packages. The minimum is
  one; the 4-round template adds at most one more.
- Does not replace engine-side investigation when the scout
  outcome is "engine probably wrong". It triages cheap-first.
- Does not require the scout author to fix the issue. Attribution
  and hand-off are the deliverables; the fix is a separate slice.
- Does not promote the scout's conclusion to a validation-debt
  register status change. Status changes follow Design 50 §9 and
  require the appropriate evidence per row (typically r200, not
  scout-level r10).

## 8. Cross-references

- Design 50 (M3.3b surface admission) §3 estimand contract +
  §9 status-change rule.
- Design 42 (M3 DGP grid) — what the harness DGP looks like in
  full; the binomial-`psi` rule subsection (added 2026-05-25)
  documents the patched DGP for Bernoulli rows.
- Design 04 (sister-package scope) — the canonical sister-package
  roster + per-package strength/weakness notes.
- `docs/dev-log/audits/2026-05-25-jason-cross-package-binomial-sigma-scout.md`
  — the worked-example scout.
- AGENTS.md Standing Review Roles — Jason (literature / cross-
  package), Curie (simulation), Fisher (inference policy), Rose
  (scope honesty), Gauss (TMB likelihood / numerical).

— Jason (drafter), Curie + Fisher + Rose (reviewers), Shannon
  (coordination)
