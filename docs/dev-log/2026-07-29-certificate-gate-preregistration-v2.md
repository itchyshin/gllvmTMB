# Pre-registered gate v2 — Gaussian `Sigma_unit` diagonal profile interval

**Written 2026-07-29, BEFORE the v2 campaign was launched.** Immutable after launch, as v1 was.

v1 (`2026-07-29-certificate-gate-preregistration.md`, commit `90798365`) is **not edited** — it
stands as written, including the clause this document exists because I failed to implement.

## Why there is a v2: the v1 run was WITHHELD, 2-1

A three-lens D-43 panel adjudicated the v1 result. **Disposition: WITHHELD.** The gate arithmetic
was met — d1 band 0.9447390, d2 band 0.9432775, both clearing 0.94, hitting v1's own recorded
expectation almost exactly — and the panel confirmed the arithmetic to 7 dp. It withheld anyway,
for two reasons that have nothing to do with the arithmetic.

### Defect 1 — the seed clause was violated. This is the dispositive one, and it is my error.

v1 states, under *Replication and seeds*: *"Seeds are drawn fresh for this run… this campaign is
**self-contained** — no pooling with historical reps, **no reuse of a previous seed window**."*

The first half is true. **The second is false.**

`dev/m3-grid.R:1035-1038` computes `rep_seed = seed_base + 1000*d + 100000*family_index + r` — a
deterministic function of the rep **index**, invariant across runs. `dev/totoro-profile-rescore.sh`
contains **no seed parameter at all**, so `seed_base` took the runner's default of `1`
(`dev/profile-rescore-run.R:45`), and with no `--rep-start`/`--rep-end` the window defaulted to
`[1, 20000]` — the same index space the 2026-07-17 campaign used.

So **reps 1–15000 of the v1 run are byte-identical datasets to the historical 15k run.** The panel
proved this empirically rather than inferring it: the v1 run's own reps 1..15000 return d1
0.947672 / band 0.943981 and d2 0.946127 / band 0.942428 against the historical 0.9477 / 0.9440 and
0.9461 / 0.9424, with both subset MCSEs rounding to the historical 0.00185. Four quantities
agreeing to 4 dp is roughly a 1-in-2,000 coincidence under independent sampling.

**The consequence is that v1 did not do the job it was created to do.** Its stated purpose was to
reproduce a result whose raw was lost. Re-scoring the same simulated datasets is not reproduction,
and the close agreement I reported as strong confirmation was the *symptom of the defect*, not
evidence for the result. Only reps 15001–20000 — 5,000 per cell — were genuinely new data.

The mechanism to prevent this existed and I built it: a `REPSTART`/`REPEND` passthrough was added
to the launcher in the same commit as the pre-registration. It was never used.

### Defect 2 — failure accounting was incomplete, and the row affirmatively said otherwise

The certificate row reported `n_failed = 0` while 607 d1 fits (3.03%) and 134 d2 fits (0.67%) had
failed to converge. `m3_summarise` computed failures within the `(cell, target, ci_method)` subset,
and a failed fit's placeholder row is emitted under a different `ci_method`, so it never entered the
`profile_total` subset.

This matters beyond tidiness: `NEWS.md:282-286` already tells users that a coverage design lacking
*"complete failure accounting"* is disqualifying, and register row `CI-08` is negative partly
because replicate fits failed. Certifying off that row would have breached the package's own
published standard.

**Fixed before this run** (commit `836480a9`): attempts are counted at cell level, `n_attempted` is
reported, and `n_failed` now reads 607 / 134 consistently from both the `profile_total` and
`bootstrap` subsets.

## What v2 changes — and what it does not

**Changed: the seed window.** Reps **20001–40000**, via `--rep-start 20001 --rep-end 40000`. Since
`rep_seed` is a function of the rep index, this window is disjoint from `[1, 20000]` — which covers
both the historical 15k run and the v1 run — so **all 20,000 reps per cell are genuinely new
datasets.**

**Changed: failure accounting is complete**, per commit `836480a9`.

**Unchanged: everything about the gate.** Same estimand, same two cells (gaussian d1-n150 and
d2-n150), same route (`profile_total`), **same gate `coverage >= 0.94`**, same band
`coverage - 2*MCSE` with `MCSE = sqrt(p(1-p)/n_reps)`, same both-cells-or-neither rule, same
prohibitions. **The gate is not renegotiated because the last run withheld.**

## The gate

- **Gate: `coverage >= 0.94`.** Not 0.95.
- **Lower band = `coverage - 2 * MCSE`**, `MCSE = sqrt(p * (1 - p) / n_reps)`, each rep one
  Bernoulli — the maximum-variance case. Confirmed conservative by the v1 panel, which measured the
  design effect at 1.13–1.14 (intra-rep correlation 0.033–0.036), making this bound ~2x wider than
  the clustered MCSE.
- **CERTIFY only if the band clears 0.94 for BOTH cells.** Either fails → WITHHELD for both.

## What would make this WITHHELD

- Either cell's band < 0.94.
- **Coverage materially different from the v1 run's 0.9465–0.9479.** Note this trigger is
  meaningful for the first time: v1's version of it was structurally incapable of firing on 75% of
  its sample, because that sample was the historical data. Here the data are new, so a
  disagreement would be real information.
- A convergence rate low enough that the denominator is not the population the claim is about.
  **v1's rates were 96.97% (d1) and 99.33% (d2)** — recorded here in advance as the comparison.

## Prohibited after launch

Unchanged from v1: no relaxing the gate below 0.94; no one-sided band or 1·MCSE; no dropping a
failing cell and certifying the survivor; no pooling with the v1 or historical reps; no restating
the result as nominal or unconditional 95% coverage.

**Added for v2:** no re-running with a third seed window if this one withholds. Two attempts is
already the edge of seed-shopping; a third would be selecting the sample that passes.

## Fences the panel established, which ride with any certificate

These are conditions on wording, not on disposition, and they carry forward regardless of outcome:

1. **The interval is NOT equal-tailed.** v1 measured upper-tail misses at 3.16% / 3.30% against
   lower-tail 2.05% / 2.05% (z ≈ 13.7 / 15.3 for the asymmetry). Two-sided coverage lands near 0.947
   only because the two errors partly offset. **Any one-sided use of this interval is invalid.**
2. **It is a marginal average over this DGP's `V_t` distribution.** v1 measured d1's lowest decile
   of true `V_t` at 0.9351 coverage — below the gate. There is a small-`V_t` sub-regime where 0.94
   does not hold.
3. **The denominator is conditional on convergence**, and the rate must be stated with the claim.

## Data handling

Raw stays **LOCAL on Totoro** (D-50) at `run20k-v2-20260729/`. **Retain it.** v1's raw is retained
too — do not delete it; it is the evidence for the seed-reuse finding.
