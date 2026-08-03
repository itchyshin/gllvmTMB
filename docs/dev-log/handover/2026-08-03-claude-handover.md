# Session Handoff: Design 108 campaign ANSWERED · mature-VA arc approved and re-aimed

> # ⛔ RETRACTION — READ FIRST (added 2026-08-03, after adversarial review)
>
> **The Design 108 comparison in this handover DOES NOT HOLD. Do not cite it.**
>
> The adversarial review found the two arms were fitted to **different models**. The DGP is
> binomial-probit; the Laplace arm fitted that correctly, but the campaign script inlined the
> VA arm as `gaussian_anchor`/identity on `scale(y)`, bypassing the harness's own
> `.d108_fit_va()`. Attenuation across traits spans **0.37-0.77** — not a correctable scalar.
>
> **VA's oracle floor (tier 2) is 0.709-0.782 against Laplace's observed 0.561-0.764: in 3 of 4
> cells a PERFECT VA loses anyway.** The test could not return "VA wins". Tier 1 **reverses** —
> VA's excess-over-floor is smaller than Laplace's in all four cells, so "Laplace better 8x on
> tier 1" is an artefact of the scoring.
>
> **The 34% completion rate is a HARNESS property, not VA's** — the grid forked 40 ways without
> seeding the TMB DLL per worker, which `harness.R:103-110` documents as required. The "failed"
> cells complete fine single-threaded.
>
> **Stages 3/5 CANNOT be retired on this evidence** — that would retire an arc on a confound.
> **The corrected re-run is ~1 day, not 7.**
>
> What survives, and is publishable as written: *the VA prototype produced degenerate estimates
> of the structured phylo tier in every fit that returned (9/27 collapsed to zero, 18 exceeded
> the error of estimating nothing), a pattern multi-start does not repair and the engine's own
> health gate rejects — so the prototype does not currently recover a structured phylo tier. The
> pilot does NOT support a comparison against Laplace.*
>
> Full review: `dev/design108-recovery/ADVERSARIAL-REVIEW.md` on
> `claude/d108-recovery-campaign` (commit `fdbf5e0e`).
>
> **The mature-VA arc is UNAFFECTED** — it rests on the profile and the literature, not on this
> comparison. VA's value was always speed-via-closed-form, not accuracy.


**Meta:** 2026-08-03 · from Claude · to Claude · fresh context required
**`origin/main` at write:** `dbd0b2d5`

## Mission-control summary

| Field | Value |
| --- | --- |
| Repo | `gllvmTMB` |
| This session | Answered the Design 108 recovery question; found + fixed 5 silent defects; re-aimed the VA speed arc on measured evidence |
| **Design 108 verdict** | **VA does NOT recover the structured phylo tier.** Laplace better **31x**. Stages 3/5 **not worth ~7 days** |
| **Next arc** | **Mature VA** — maintainer-approved 4 items, primary = Albert-Chib closed form |
| 🔴 Needs Shinichi | Review **PR #917** (register-code guard) · collect the **Totoro grid** (in flight) |
| Fence | untouched — no export, no `method=`, no public claim |

## 🔴 FOREIGN LANE — a Stan-oracle lane is ACTIVE and touches this subject

Three PRs landed on `main` **during this session**, from a lane this session did not own:

- **#918** `spike(stan-oracle): Arc 0` — a hand-written Stan model reproduces the joint log-density, **and finds a doc/engine divergence**
- **#919** `docs: the loadings diagonal is unconstrained — correct the claim everywhere`
- **#920** `spike(stan-oracle): Arc 1 — phylo_latent reproduced, and two undocumented details`

**#919 bears directly on this session's estimand.** The campaign scored against
`Sigma_B = Lambda Lambda'` (loadings-only). If the loadings diagonal being *unconstrained* changes
what that quantity means or how it should be compared, **the campaign's numbers may need
re-reading**. **Reconcile before citing this handover's verdict.** Do not claim their surface.

Also read `docs/dev-log/handover/2026-07-25-active-lane-split.md`.

## Goals / mission

Design 108 Gate A is closed. First CRAN target remains **0.6.0**; none of this widens a public
claim. North star is Ayumi's BIRDBASE model (N=5397, gaussian + binomial-probit +
ordinal-probit + lognormal).

## What was accomplished

### 1. THE CAMPAIGN'S ANSWER — VA loses on the structured tier

Structured two-tier, **gaussian**, **N=1000**, T=10, 3 seeds, both tiers extracted, planted truth:

| | tier-1 | **tier-2 (phylo — the target)** |
|---|---|---|
| VA | 0.783 | **16.89** (seeds 16.89 / 48.68 / 1.000) |
| Laplace | **0.094** | **0.543** (0.704 / 0.543 / 0.540) |

**Laplace better on both — 8x tier 1, 31x tier 2.** VA **FAILS 3/3**: two runaways past the
`rel_frob > 10` degeneracy threshold, one at exactly **1.000** (collapse to zero). Runaway or
collapse, never recovery.

**Stages 3/5: NOT worth ~7 days**, by the handover's own criterion.

**Four caveats that bound it** (full text in `PILOT-FINDINGS.md`, commit `ed6f88a3`):
gaussian not probit (a designed scope limit; probit adds a measured **8.8x** GH penalty);
3 seeds, **no MCSE claimed**; tier-2 informativeness is **marginal** (Laplace 0.543 vs a
stipulated 0.5); and it measures **VA AS IT IS** — `n_starts=1`, unrefined starts, no
closed-form evaluator. **Cite as "this engine, in this state, does not" — NEVER as "VA cannot
do structured phylogenetics."**

### 2. FIVE silent defects found and fixed — every one ran clean and reported success

1. **Bernoulli silently drops the between-unit Psi** from the Laplace arm's target — it would
   have estimated a Psi-free quantity against Psi-including truth. Fixed via `n_trials = 6`.
2. **The DGP contradicted the model**: drew the phylo Psi *iid* where `phylo_latent(unique=TRUE)`
   wants `Psi_phy (x) A`. Measured `psi_phy_hat` = **1.98e-08**. (`132aa79b`)
3. **Scoring against the wrong estimand** — the cause of an apparent control "plateau". An
   algebraic floor computed from truth with NO fitting reproduced **96%** of the observed
   number. (`c20fb681`)
4. **The VA phylo-Psi tier was BYTE-IDENTICAL to another tier**, so *starting values* decided the
   psi split — tier-4 shares of 52.7% / 47.6% / 20.7% across seeds, up to **+232%** of the
   estimand. (`37531e09`)
5. **The positive-control gate was about to pass VACUOUSLY** — the control was the one arm with
   no loadings extraction, so its `rel_frob` would have been a silent `NA`.

### 3. The VA speed arc — APPROVED and RE-AIMED

**Our VA is CORRECT and more accurate than the mature reference.** On identical single-tier
model and data (binomial-probit, N=250, T=20): gllvm **0.70 s / 0.359**, ours **45.6 s /
0.298** — ours beats gllvm on **4/4 seeds**. **Do not go looking for a correctness bug.**

**Maintainer-approved 4 items** — full plan with falsifiers in `dev/va-speed/MATURE-VA.md`
(branch `claude/va-speed-arc`):

1. **PRIMARY — Albert-Chib closed-form probit/ordinal evaluator.** Removes the ~75% GH cost.
   Proved at GLLVM level by Hui/Warton/Ormerod/Haapaniemi/Taskinen — the paper gllvm itself
   implements. **Theorem 1** binary probit, **Theorem 3** cumulative ordinal (Ayumi's other hard
   column). Only `Phi`/`phi` — TMB-native atomics, so an **objective substitution**, not an
   architecture change.
2. **`profile_variational` default — HALF-established.** The objective identity **IS** settled
   (5 sizes, 1.7e-11 to 1.4e-9; it computes the EXACT profile, and the `sdreport` rationale is
   inapplicable — **zero** such machinery in the path). The **speed rule is NOT**: ratios
   0.19 / 0.42 / 1.33 / **0.90** / 3.25 at N=120/250/500/1000/2000 are **non-monotonic**.
   **An unconditional flip would slow every small fit.** Do not set a threshold from this data.
3. **Per-family best evaluator** — falls out of Item 1.
4. **Re-measure vs gllvm**, interleaved, accuracy as the CONSTRAINT (`rel_frob <= 0.298`).

**Deprioritised on evidence:** block-diagonal `S` (targets an inner solve the profile shows is
healthy); staged warm-up (no literature support in 14 sources); EVA as the probit route (a
**surrogate, not a bound** — its own objective prefers a runaway by **291 nats**, and more
restarts make it worse).

**Where the time is:** single-tier — GH is **~75% of total**. Structured tier — **99.83%
`nlminb` outer bookkeeping** under the default route (genuine `fn`/`gr`: **0.17%**).

### 4. Reader-facing jargon — PR #915 MERGED, guard PR #917 OPEN

Shinichi hit `2C` on a published article. 14 sites across 14 files. **The brain showed at least
FOUR prior manual sweeps and no guard script** — so #917 adds a test, and it **caught
`CI-08/CI-10` on `main` on its first run**, introduced by #914 hours after the sweep.

## Landing state

| Artifact | Branch | State |
|---|---|---|
| Campaign (protocol, DGP, harness, findings, ANSWER) | `claude/d108-recovery-campaign` | **PUSHED**, no PR — evidence lane, not for merge |
| VA speed arc (ARC, PROFILE, LITERATURE, MATURE-VA) | `claude/va-speed-arc` | **PUSHED**, no PR |
| Register-code guard | `claude/register-code-guard` | **PR #917 OPEN** — needs review |
| Reader-facing jargon | — | **MERGED** (#915) |
| Design 106 §6.4 discrepancies | — | **issue #913** filed |
| **Totoro grid (80 cells, 20 seeds, N/q)** | n/a | **IN FLIGHT** — see below |
| ~13 legacy unpushed local branches | various | **CARRIED-OVER** — pre-existing `handoff_gate` noise, not this session's |

**Campaign results are LOCAL (D-50)** — `.rds`/`.csv` gitignored, never committed.

### The Totoro grid — COLLECTED, and it FORCED A CORRECTION

**Ran: 80 cells, 20 seeds, N in {500,1000} x q in {1,2}, 40 cores.** Results LOCAL (D-50) at
`totoro:~/gllvm_work/d108-recovery/campaign_grid.{rds,csv}`; a copy is in the campaign worktree.

**The PRIMARY finding is completion, not accuracy:**

| arm | cells returning a number |
|---|---|
| **VA** | **27/80 (34%)** |
| Laplace | **80/80 (100%)** |

**CORRECTION — the strong form of this handover's verdict is WITHDRAWN.** With MCSE, the paired
tier-2 contrast is **INDETERMINATE in two of four cells**: 2*MCSE bands `[-0.536, 20.853]`
(N=1000 q=1) and `[-0.095, 47.184]` (N=1000 q=2) both include zero, because VA's runaways
inflate the variance. The two cells that DO exclude zero are both at **N=500 — the SMALLER
size**, which is backwards from "at realistic size".

**The cells also FAIL the informativeness precondition:** Laplace's tier-2 medians are
0.561-0.764 against a stipulated 0.5, so no arm achieves acceptable tier-2 recovery anywhere.

Degeneracy rates carry wide, overlapping Wilson intervals (1/8 `[0.02,0.47]`, 2/7 `[0.08,0.64]`,
2/6 `[0.10,0.70]`, 3/6 `[0.19,0.81]`) — **not a precise rate; do not quote as one.**

Full detail: `PILOT-FINDINGS.md`, commit `30dd716f`.

### 🔴 ADVERSARIAL REVIEW — DISPATCHED, RESULT NOT YET IN

Running with a default of **NOT-HOLDING** and six named attacks. Output lands at
`dev/design108-recovery/ADVERSARIAL-REVIEW.md` on `claude/d108-recovery-campaign`.
**READ IT BEFORE CITING ANY VERDICT.**

Its first and most important attack: **is the 66% non-completion a VA property or a HARNESS
property?** If VA's failures trace to `n_starts = 1`, an iteration cap, or unrefined starting
values, the headline measures **our scripting, not the estimator**, and collapses. That single
question decides whether the Stages 3/5 verdict stands.

### (superseded) the grid as originally described

Launched to close the two gaps the local 3-seed run left: **no MCSE**, and **no compute-discipline
compliance**. 80 cells (N in {500,1000} x q in {1,2} x 20 seeds), 40 cores.

```sh
SOCK=$(ls ~/.ssh/cm-*totoro* | head -1)
ssh -o ControlPath="$SOCK" -o ControlMaster=no -o BatchMode=yes totoro \
  'tail -5 ~/gllvm_work/d108-recovery/grid.log; ls -la ~/gllvm_work/d108-recovery/campaign_grid.*'
```

Results at `totoro:~/gllvm_work/d108-recovery/campaign_grid.{rds,csv}`. **Keep them LOCAL.**
With 20 seeds the paired VA-minus-Laplace contrast finally supports **MCSE**, which the 3-seed
verdict above explicitly does not claim.

## Next immediate steps (classify OWED / DONE / RETRACTED / PROTECTED)

1. **OWED — rehydrate:** `bash ~/shinichi-brain/tools/lane_preflight.sh "$PWD"`; read `AGENTS.md`,
   this doc, `2026-07-25-active-lane-split.md`; **reconcile #918/#919/#920 (Stan-oracle lane)
   against this session's estimand** — see the red section above.
2. **OWED — collect the Totoro grid** and recompute the verdict **with MCSE**. If it contradicts
   the 3-seed result, the grid wins.
3. **OWED — adversarial verification of the campaign verdict.** It has not had one. The verdict
   rests on 3 seeds, one family, one N. Default to NOT-HOLDING.
4. **OWED — start the mature-VA arc at Item 1** (Albert-Chib). Read
   `dev/va-speed/MATURE-VA.md` on `claude/va-speed-arc` first.
5. **🔴 Needs Shinichi — PR #917** (register-code guard).
6. **DEFERRED:** Stages 3/5 (verdict: not worth it) · issue #897 · the EVA arm (likely
   superseded) · the family sweep P0b.
7. **PROTECTED:** the Dropbox checkout (D-112, ~700 behind, dirty); `R/integration-fence.R`;
   `R/va-routing.R`; the Stan-oracle lane.

## Gotchas — paid for this session

- **Three false alarms came from MY invalid arguments**, not defects: `H = 11` (must be 15/25/61),
  `n_starts = 2` (must be 1/3/4), `Ntrials = 6` for gllvm EVA (it fits Bernoulli, rejects
  multi-trial). **Never conclude a capability is absent from ONE failed call — vary the argument.**
- **Scope qualifiers get dropped on recall.** Four confident claims were overturned by
  measurement in one day. The sources were all correct; the conclusions were not.
- **`pgrep -f "<pattern>"` matches its own command line** — split the literal.
- **Backticks in a `git commit -m "..."` are shell-evaluated** — a word silently vanished from one
  message. Use a heredoc or `-F`.
- **A background `nohup` loses the working directory** — a script failed silently with an empty
  log until `setwd()` was added.
- **`na.rm = TRUE` rates need their denominator reported** — an all-`NA` arm printed
  "degenerate 0/4" and read as clean.

## Live environment

```sh
REPO="/Users/z3437171/Dropbox/Github Local/gllvmTMB"   # PROTECTED — never build here
git worktree add /private/tmp/gllvmtmb-<arc> -b claude/<arc> origin/main
export NOT_CRAN=true
Rscript --vanilla -e 'devtools::load_all(quiet=TRUE)'
```

**Do not stage:** the Dropbox `.claude/` or `.uinit/` dirs, the dirty profile-coverage files, any
campaign `.csv`/`.rds` (D-50), or foreign lane trees.

## Resume prompt

```text
Read AGENTS.md and docs/dev-log/handover/2026-08-03-claude-handover.md. Run the handover rehydration steps, reconcile them with the current git state, then continue only the OWED Next Immediate Steps.
```
