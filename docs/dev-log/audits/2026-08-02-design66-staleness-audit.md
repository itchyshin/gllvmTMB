# Design 66 staleness audit — what the capstone spec gets wrong as of 2026-08-02

**Type:** read-only audit. **No compute was run. No campaign was launched. Nothing in
Design 66 was edited by this audit.**

**Author:** Claude Code (evidence/validation lane). **Date:** 2026-08-02.
**Verified against:** `origin/main` @ `26c38dd5`, in a fresh worktree (not the Dropbox
checkout, which sits 639 commits behind on a July-18 branch and reports the wrong
`DESCRIPTION` version).

**Why this exists.** `docs/dev-log/handover/2026-08-02-claude-handover-evidence-capstone.md`
owes the next session one task: scope the Design 66 capstone as the *paper's evidence
chapter* now that CRAN is descoped. It instructs that session to begin by re-reading
Design 66 against this lane's findings and listing where it has gone stale, rather than
re-deriving the spec. This is that list.

**Status of the capstone itself: unchanged.** This audit does not authorise, size, or
launch anything. Five scope decisions remain Shinichi's and are restated in §4.

---

## 0. Verification ledger

Every claim below was checked against the working tree at `26c38dd5`, not against the
handover's summary of it. What was actually run:

| Check | Command / file | Result |
|---|---|---|
| Package version | `DESCRIPTION` | `0.6.0` (the handover is right; the Dropbox checkout's `0.5.0` is stale) |
| Profile route exported | `NAMESPACE:174` | `export(profile_ci_total_variance)` — present |
| Kernel engine exported | `NAMESPACE:129-133` | `kernel_dep`, `kernel_indep`, `kernel_latent`, `kernel_scalar`, `kernel_unique` — all present |
| Kernel engine tested | register rows KER-01/02/03 | all three `covered`, with named test files |
| Bootstrap default | `R/bootstrap-sigma.R:183` | `n_boot = 200` |
| Bootstrap ceiling guard | `R/bootstrap-sigma.R:227-241` | `coverage_ceiling <- (n_boot - 1) / (n_boot + 1)`, warns below the floor |
| Register CI-08 | `35-validation-debt-register.md:411` | carries the 2026-08-02 addendum; still `partial` |
| Oracle map | `docs/design/87-latent-variable-oracle-map.md` | exists, dated 2026-08-02 |
| Compute-admission slice | `grep -rl 'compute-admission' docs/ dev/` | **no design doc** — referenced only by Design 66 itself, the check-log, two dev scripts, and one recovery checkpoint |
| Issues | `gh issue view 349`, `345` | both OPEN |

Arithmetic used in S-2, recomputed here rather than quoted:

| `n_boot` (B) | max attainable coverage `(B−1)/(B+1)` |
|---|---|
| 25 | **0.9231** |
| 50 | 0.9608 |
| 100 | 0.9802 |
| 200 | 0.9900 |

---

## 1. Stale items, in descending order of consequence

### S-1 — §8's bootstrap budget lever is not just stale, it is unsafe

**Where:** §8 "Levers to cut the bill", lever 2 (lines 521–525); the cost table (lines
499–503) prices every scenario at `n_boot = 100`.

**What it says:** *"The M3 production default is n_boot = 25; the capstone needs enough
bootstrap reps for a stable interval but n_boot = 100 is a reasonable target and
n_boot = 50 halves the bill versus 100. (The bootstrap-replication count trades against
interval noise, not against the coverage MCSE, which is set by n_sim.)"*

**Why it is wrong.** The parenthetical is false, and the falsity is arithmetic, not
empirical. A percentile interval built from B bootstrap draws is bounded by its own
widest possible realisation, `[min, max]`, whose coverage cannot exceed `(B−1)/(B+1)`
**whatever the data are**. This is not Monte Carlo noise that averages out over
replicates — it is a ceiling on the estimand itself. Consequences, in order of severity:

1. **At the quoted M3 production default `n_boot = 25`, the ceiling is 0.9231 — below
   Design 66's own 0.94 gate.** A capstone run at that setting could not pass H1 even if
   the estimator were perfect. The failure would present as a coverage shortfall and be
   misread as a package defect.
2. **`n_boot = 50` (the "halve the bill" lever) has a ceiling of 0.9608** against a
   *nominal 95%* target that L-c says the study must adjudicate. That leaves 1.1
   percentage points of headroom for all real miscalibration — the lever eats most of
   the quantity being measured.
3. **The empirical number confirms the direction.** Holding draws fixed and varying only
   B, this lane measured 0.8073 (B=10) → **0.9418 (B=200)**. Even at the default, the
   bootstrap route lands barely above the 0.94 gate. There is no slack to trade.

**Correction to fold in:** delete lever 2. Set a hard floor of `n_boot >= 200` for any
claim-bearing cell, and require each cell to assert `coverage_ceiling >= conf` from the
returned object (`R/bootstrap-sigma.R` now exposes `$coverage_ceiling` precisely so a
campaign can). **Re-price §8's entire cost table at `n_boot >= 200`** — the current table
understates the bootstrap bill by at least 2×.

### S-2 — the primary interval method is the wrong one, and it is the expensive one

**Where:** §3 (line 187, "Primary CI method: parametric bootstrap"); §6 "Interval
methods" (lines 400–410); §1's ADEMP table (line 101).

**What it says:** bootstrap is PRIMARY on `Sigma_unit_diag`; profile likelihood is a
DIAGNOSTIC on per-trait `psi` (`theta_diag_B`), reported but never gated, per PR #364's
demotion.

**Why it is stale.** Design 66 knows of exactly one profile route — the rotation-*variant*
`psi` profile that PR #364 correctly demoted — and therefore reads "profile" as "the
demoted diagnostic". A *second, different* profile route now exists and is certified:
`profile_ci_total_variance()`, a χ²₁ profile on log V_t, targeting the
rotation-**invariant** total variance. It reached **0.9467** under a pre-registered gate
on a fresh-seed 20,000-replicate campaign, passed a 3-lens D-43 panel 3–0, and was
exported at `f04c066c` (`NAMESPACE:174`, wrapper `R/profile-derived.R:1010`). Design 66's
§6 cannot distinguish these two routes because it predates the second one.

**Why this is the highest-value correction in this document.** *Evidence quality.* The
certified route covers 0.9467; the bootstrap route covers 0.9418 at its default. The
capstone would currently gate its headline claim on the weaker, uncertified arm while the
certified arm sits unused.

> **CORRECTION, 2026-08-02 (same day) — this finding originally claimed a second,
> compute-cost axis, and that claim was wrong. It is withdrawn.**
>
> The withdrawn text read: *"the bootstrap cost model is `cells × n_sim × (1 + n_boot)`
> … a 1-D profile is a small number of constrained optimisations per replicate, not 200
> full refits. Switching the primary arm plausibly cuts the capstone bill by roughly an
> order of magnitude — which is the difference between a campaign that needs a DRAC
> allocation and one that fits on Totoro."*
>
> Two successive adversarial reviews took it apart, and the second **flipped its sign**:
>
> 1. **Bootstrap amortises; a profile does not.** One bootstrap refit set yields *every*
>    requested summary — all `T` diagonal entries and the off-diagonal correlations from
>    the same draws (`R/bootstrap-sigma.R:346-375`). A profile is a per-scalar `uniroot`
>    bisection, one interval at a time (`R/profile-derived.R:866-897`).
> 2. **The scalar count was undercounted.** The off-diagonal target is computed over
>    `utils::combn(n_traits, 2L)` — **10 pairs at `T = 5`** (`dev/m3-grid.R:1666-1681`),
>    not one. So the capstone needs **5 or 15** univariate profiles per replicate, not the
>    "~6" the first correction assumed.
>
> Measured against the code, at `refits_per_profile ≈ 14–26` per two-sided scalar
> interval: **diagonals only (5 scalars) = 1.5×–2.8× cheaper; diagonals plus all pairs
> (15 scalars) = 1.05×–1.95× MORE EXPENSIVE.** The sign depends on which estimands are
> gated. And the comparison still assumes equal cost per refit, which favours the profile
> wrongly — a bootstrap draw is a cold `gllvmTMB()` call while a profile step is a
> warm-started `nlminb` on the existing tape with an analytic gradient.
>
> **No compute-saving figure should be committed anywhere until `refits_per_profile` is
> measured empirically** (median and upper decile, per family and per RE structure).
>
> The evidence-quality argument above is unaffected and still stands on its own. What is
> retracted is only the claim that switching arms is *also* cheaper.
>
> *Why this is recorded rather than quietly edited:* this audit exists to catch unverified
> quantitative claims, and it made one. The tell was structural and should have been caught
> on writing — a precisely quantified numerator (201 refits) divided by an entirely
> unquantified denominator ("a small number"), reported as a ratio.

**Correction to fold in:** re-open the primary/diagnostic assignment in §3 and §6 as an
explicit decision, with three named candidates: (a) profile primary / bootstrap
secondary, (b) bootstrap primary at `n_boot ≥ 200`, (c) both arms on every core cell,
reporting the pair. **Do not simply swap them by fiat** — the certificate carries live
scope fences (two-sided only; fails in the smallest-`V_t` ventile at 0.9259/0.9369;
conditional on convergence; a 0.94 floor, never nominal 0.95; the two certified cells
share 19,000 of 20,000 seeds and are not independent) and it is certified only for
**gaussian, d ∈ {1,2}, n = 150**. The capstone's core grid spans four families and two
sample sizes. Extending the certificate to the rest of the grid is itself a deliverable,
not an assumption. Full fences: `docs/dev-log/2026-07-29-certificate-disposition.md`.

### S-3 — the CRAN framing is dead, and it changes what the study is *for*

**Where:** §0 (line 60, *"the final validation milestone before CRAN + paper"*); §2 (lines
113–115, the claim set is sized to what *"the paper and the CRAN submission will make"*);
§10 DoD item (line 584, *"CRAN + paper (milestone #3) gate on this being DONE"*).

**Why it is stale.** Shinichi, 2026-08-02: *"do not worry about CRAN submission — I am not
intending to do so."* Issue #345 loses its first half.

**Why this is not merely cosmetic.** It inverts the study's logic. As a *release gate*, a
capstone is adequate when it clears a pass/fail bar — a binary, and the cheapest grid
that resolves the binary wins. As the *paper's evidence chapter*, the deliverable is a
defensible characterisation: the power **curve**, the regimes where calibration degrades,
and the honest statement of what was not checked. Under the second reading, H3 (already
specified as *"the curve, not a single pass/fail"*) rises in priority relative to H1's
binary gate, and cells that fail become findings worth reporting rather than blockers
worth eliminating. §0, §2 and §10 should be rewritten to the paper framing before the
grid is sized, because the framing determines which cells are worth buying.

### S-4 — L-e defers Tier 3 on a premise that is now factually dead

**Where:** §4.1 (line 226, *"`kernel_*()` is NOT built on origin/main -- #361"*); §4.5
(line 321); §3 (line 195, *"the `kernel_*()` engine is not yet built on origin/main"*);
§12 L-e (lines 667–672).

**Why it is stale.** The kernel engine is built, exported, and tested. `NAMESPACE:129-133`
exports the full quartet plus `kernel_scalar`; `diagnose_kernel_separability` is exported
at `:86`; register rows **KER-01, KER-02 and KER-03 are all `covered`** with named test
files (`test-kernel-latent-unique-fold.R`, `test-kernel-equivalence.R`,
`test-coevolution-two-kernel.R`, `test-coevolution-prototype.R`), including the fixed
named multi-kernel engine.

**Note this was not in the handover's list.** It surfaced from checking `NAMESPACE`
directly rather than trusting the spec's own statement about itself — the same move that
found the `psi` category error.

**Correction to fold in:** deferring Tier 3 may still be the right call on budget grounds,
but it can no longer be justified by "the engine does not exist". L-e must be re-decided
on its merits, and §4.1/§4.5/§3 must stop asserting a capability is absent when it ships.

### S-5 — the spec has no comparator/oracle axis, and its core grid collides with the one that now exists

**Where:** absent throughout. Design 87 postdates Design 66.

**The collision.** Design 66 §4.2 fixes the core RE structures as **`phylo_dep`,
`spatial_dep`, `animal_dep`, `phylo_latent`**. Design 87 §3.1 rates exactly those cells:

| core cell | best available third-party oracle (Design 87 §3.1) |
|---|---|
| `phylo_dep` | `MCMCglmm` `us(trait):animal` + pedigree — posterior mean, **untested**, not an MLE |
| `animal_dep` | `MCMCglmm` `us` + pedigree — same caveat |
| `spatial_dep` | *"not confidently established"* either way — an admitted verification gap |
| `phylo_latent` | **NONE** — a checked absence, not a scouting gap (§3.2) |

**So all four core structural cells lack an MLE-quality external oracle.** For a coverage
and power study this is not fatal — such a study validates against *known simulated
truth*, which needs no third-party package. But for the *paper's* evidence chapter it is
load-bearing in two ways, and the spec currently says neither:

1. It must be **stated as a limitation**: the capstone's structural axis is
   self-validation against simulation, with no independent implementation agreeing.
2. There is **one available instrument** and Design 66 does not mention it. Per §6.1, a
   hand-written Stan model can encode any of these cells, and the check that matters is a
   *fixed-parameter log-likelihood comparison to machine precision* — strictly stronger
   than the tolerance-based comparisons the ✓✓ cells get. `rstan` 2.32.7 and `cmdstanr`
   0.9.0 are installed. **No such model has been written for any cell.** Its limitation is
   equally load-bearing and must be stated with it: a self-written Stan reference checks
   *implementation*, not a shared conceptual misreading; derive it from the published
   model definition, not from this package's own C++.

   **`tmbstan` is not an oracle** — it wraps the same TMB objective and can only show that
   objective is internally consistent under a different integration scheme.

**Correction to fold in:** add an oracle/comparator section to Design 66 that cites Design
87 per core cell, states the no-MLE-oracle limitation explicitly in the terms the paper
will use, and decides whether a Stan fixed-parameter check for `phylo_latent` is in scope
for the capstone or a separate slice.

### S-6 — the execution route is still blocked, and the unblocking artefact does not exist

**Where:** the 2026-07-20 D-50 supersession header (lines 11–18); §4.7 (lines 336–350);
§8 (lines 505–535); §12 preamble and L-a.

**What it says:** no 48-cell pilot, no claim-bearing fit campaign, and no production DRAC
array is admitted until a **separate compute-admission slice** freezes and validates
source/archive/runner checksums, campaign and task identity, immutable destinations,
retry policy, and result schema — followed by explicit maintainer approval.

**Why it matters now.** `grep -rl 'compute-admission' docs/ dev/` returns Design 66 itself,
the check-log, one after-task report, one recovery checkpoint, and two dev scripts —
**no design document, and no evidence the slice was ever built.** This is not stale; it is
*live and unsatisfied*. It is the binding constraint on execution regardless of what the
five scope decisions resolve to, and any capstone plan that does not schedule it first is
planning a campaign it is not permitted to run.

---

## 2. What is NOT stale (do not re-litigate)

Stated explicitly so the next session does not spend effort re-deriving what survives:

- **§3's estimand discipline is correct and current.** Rotation-invariant
  `Sigma_unit_diag` + total off-diagonal correlation are primary; raw `psi` and `Lambda`
  are diagnostics. This is the PR #364 discipline and this lane's findings reinforce it.
- **The "13/15 cells below 94%" history in §3 is correctly framed** as the retired
  `psi`-proxy result, not as a live failure. §3 is in fact the source the CI-08 addendum
  cites when correcting others who quote it as current.
- **§7's MCSE arithmetic and the `n_sim` floor are sound.** 2000 replicates → 0.49 pp
  coverage MCSE at p = 0.95; R = 200 cannot adjudicate a 1 pp gap. Untouched by anything
  found here. (Note it is *`n_sim`* that sets coverage MCSE — S-1's point is that
  `n_boot` separately imposes a hard ceiling, not that `n_sim` sizing is wrong.)
- **L-g's signal parametrisation** (between-unit variance share, levels 0 / 0.2 / 0.5)
  is unaffected.
- **The §4.2 caveat that `signal = 0` is not yet a Type-I estimate** for a positive
  `Sigma_unit_diag` target still stands, and H4 still needs a pre-specified
  structure-present rejection rule.
- **§4.6's replication constraint** (RE-09: replicates are required to separate the
  diagonal Ψ tier from `sigma_eps`, a correctness constraint not a power knob) stands.
- **The binomial-logit-harness provenance warning** (L-f pilot note): pre-2026-06-24
  artifacts labelled `binomial_probit` used the logit harness and must not be read as
  probit evidence. Still live.

---

## 3. Suggested order of operations

1. Land the S-1..S-6 corrections into Design 66 as a revision (mechanical; no decisions).
2. Take the five decisions in §4 with Shinichi.
3. Schedule the **compute-admission slice** (S-6) — it gates execution independently.
4. Only then size the grid and the budget.

---

## 4. The five decisions — still Shinichi's, now better informed

The handover named these as blocking. This audit does not resolve any of them; it changes
what two of them are worth.

| # | Decision | What this audit adds |
|---|---|---|
| 1 | **Which cells** | The core-4 RE set has **no MLE oracle for any of its four cells** (S-5). If external corroboration matters to the paper, the cell choice and the Stan-reference question are the same decision. Tier 3 / `kernel_*` is no longer blocked by a missing engine (S-4). |
| 2 | **How many seeds** | §7's floor (`n_sim = 2000` → 0.49 pp) is unchanged and correct. But the *total* bill is now dominated by the interval-method choice, not by `n_sim` (S-1, S-2). |
| 3 | **Which families** | Unchanged (core-4: gaussian, nbinom2, binomial-probit, ordinal-probit). Note the profile certificate currently covers **gaussian only**, so decision 5 below interacts with this. |
| 4 | **The pre-registered gate** | L-c (report both 94% and 95%) stands. But the gate is only reachable if the interval method's arithmetic ceiling clears it — at `n_boot = 25` it structurally cannot (S-1). |
| 5 | **Totoro vs DRAC** | **Answer this last**, and answer it on a measured number. It is downstream of the primary-interval decision (S-2), but **not in the direction this audit first claimed** — see the withdrawn-claim box in S-2. The profile arm is cheaper only if the gate is diagonals-only; gating the off-diagonal pairs too makes it *more* expensive than bootstrap. Neither arm can be costed until `refits_per_profile` is measured. Gated by the unbuilt compute-admission slice either way (S-6). |

**Newly surfaced, not previously on the list:**

- **6. Primary interval method** (S-2) — profile / bootstrap / both. This is now the
  single highest-leverage scope decision, because it moves evidence quality and compute
  cost in the same direction.
- **7. Is a hand-written Stan reference in scope** for the capstone, or a separate slice?
  (S-5.) Relevant beyond the capstone: the phylogenetic multinomial (Design 84, partially
  shipped) has no third-party peer either.

---

## 5. What this audit did not do

- No compute of any kind; no fit, no pilot, no smoke run.
- **Design 66 was not edited.** Every correction above is a proposal, not an applied
  change — the spec is an APPROVED contract and §12 is a LOCKED plan; amending it is a
  maintainer act.
- No register row was moved; CI-08 and CI-10 stay `partial`.
- The bootstrap re-measurement at `n_boot = 200` that the handover lists as an open item
  was **not** run — it remains open (minutes on Totoro, D-50: results stay local).
- Design 87's own `[R]`/unverified markers were carried through as-is, not independently
  re-verified. The `MCMCglmm` and `spatial_*` cells in S-5's table are Design 87's own
  "plausible, untested" ratings, not fresh findings.

---

## Related

`docs/design/66-capstone-power-study.md` (the spec audited) ·
`docs/design/87-latent-variable-oracle-map.md` (the oracle map, §5) ·
`docs/design/35-validation-debt-register.md` (CI-08 @ `:411`) ·
`docs/dev-log/2026-07-29-certificate-disposition.md` (the profile certificate's scope
fences) · `docs/dev-log/audits/2026-08-02-ci08-coverage-explained.md` (the `n_boot = 10`
diagnosis behind S-1) ·
`docs/dev-log/handover/2026-08-02-claude-handover-evidence-capstone.md` (the handover
this discharges) · issues #349, #345.
