# Which level is the ψ tier? — a correction to my own too-simple answer

**Status: OPEN QUESTION, deliberately not resolved here.** Recorded because a confident
wrong answer was written into commit `6102e044` and should not be inherited.

## What I claimed, and why it was too simple

Commit `6102e044` argued: our VA ψ tier is indexed by `unit`, therefore it is the
"between-unit / B-tier" variance, therefore LESSONS.md D-28 forbids zeroing it.

The second step does not follow. **The level's NAME does not determine whether it is the
lowest level — the DATA STRUCTURE does.** Shinichi, 2026-08-03: *"also unit can be the
lowest I guess — things are not that simple as you know"*, and separately that the old
W/B vocabulary has been superseded by `unit` / `unit_obs` / `cluster` / `cluster2`.

In the benchmark cell used throughout this arc there is **exactly one observation per
(unit, trait) cell** — no replication. So the diagonal ψ there is a per-(unit, trait)
effect with a single observation beneath it: an **observation-level random effect**,
whatever the tier is called. That is exactly the configuration D-28's lowest-level rule
governs, where a non-Gaussian link already supplies the residual variance.

**So the original instinct — that we are estimating something the link already gives us —
was closer to right than my correction to it.**

## Where it is genuinely subtle, and why neither answer is categorical

| configuration | is ψ identified? | why |
|---|---|---|
| `n_trials = 1` (Bernoulli), no replication | **No** | a single Bernoulli draw cannot separate a latent normal from the link's fixed residual |
| `n_trials > 1`, no replication | **Weakly** | a latent normal on a binomial produces overdispersion *relative to binomial*, and the link's contribution is FIXED at 1 rather than estimated — so the beta-binomial-shaped signal carries information about ψ |
| genuine `unit_obs` replication beneath `unit` | **Yes** | ψ at `unit` is then a true higher-level variance and D-28's higher-level rule applies: estimated for ALL families |

The arc's benchmark sits in the middle row (`n_trials = 6`, no replication).

## What the measurement does and does not show

Fitted ψ SDs were 3e-06 to 4.6e-05 against a loadings signal of 0.2050 — but **the DGP
plants ψ = 0**, so ~0 is the correct answer under *either* reading. The measurement is
**not diagnostic** of identifiability. It only shows the tier costs 66× (191.1 s vs 2.9 s
at N=250/T=20) and moves the loadings estimand by <1e-4 *on a truth that has no ψ*.

## What would actually settle it

1. Plant a NON-ZERO between-unit ψ and check recovery, at `n_trials` = 1, 6 and 20. If
   ψ is recovered at n=6 and n=20 but not n=1, the overdispersion reading is confirmed.
2. Add genuine `unit_obs` replication and confirm ψ at `unit` becomes cleanly identified
   for probit.
3. Compare the profile likelihood in ψ across those cells — a flat profile is the direct
   evidence of non-identifiability, and needs no DGP assumption at all.

**Until (1)–(3) are run, do not change any default in either direction.** The honest
statement is: the rule attaches to the lowest level PRESENT, which level that is depends
on replication and on `n_trials`, and this arc has not measured which case its own
benchmark is in.

## Terminology note

D-28 in `~/shinichi-brain/memory/LESSONS.md` is written in the superseded W-tier / B-tier
vocabulary. The package's grammar is now `unit`, `unit_slope`, `unit_obs`, `cluster`,
`cluster2`, `phy`, `phy_slope`, `spatial`, `spde_slope`
(`docs/design/06-extractors-contract.md:103`). The mapping is NOT a simple rename —
`W` ≡ `unit_obs` and `B` ≡ `unit` only when a `unit_obs` tier actually exists. **Do not
mechanically rewrite D-28 into the new vocabulary**; that substitution is what produced
the error above.
