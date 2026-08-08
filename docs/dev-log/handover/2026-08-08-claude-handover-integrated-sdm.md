# Session Handoff: integrated SDM (presence-only + presence/absence) in one latent space

Meta: 2026-08-08 · from **Claude Code** · to **Claude Code** · repo `gllvmTMB` · **EXPERIMENTAL LANE**

**You are Claude, picking up an experimental lane in `gllvmTMB`.**
Branch **`claude/experiment-integrated-sdm`** · worktree `~/local-scratch/worktrees/gllvmtmb-isdm`.

---

## 0. LANE SEPARATION — read this before anything else

**Shinichi has Codex lanes running on this repo right now.** He said so directly, and **that overrides the
tool**: `lane_preflight.sh` reported *"no codex lane detected in the last 12h"*, but D-87 is explicit that
**silence is weak evidence, never proof of sole ownership** — a lane working uncommitted is invisible to it.
Treat foreign lanes as **ACTIVE**.

**Measured from `origin` at handover time:**

| lane | branches | subject — **DO NOT TOUCH** |
|---|---|---|
| **Cursor** | `cursor/cran-0.7-20260807`, `cursor/cran-path-a-0.6.1-20260807`, `cursor/va-arc1-merge-fence-20260807` | the **CRAN 0.7 release path** |
| **Codex** | `codex/va-gh-all-families` | the **VA / GH estimator across families** |

**Your boundaries, and they are not negotiable:**

- **Stay in the worktree.** Never work in `~/Dropbox/Github Local/gllvmTMB` — that checkout is shared.
- **Never touch `main`.** A CRAN release is in flight.
- **Never touch VA/GH estimator internals.** That is Codex's subject. **You do not need them** — use
  **Laplace**, which is what the reference method uses anyway. If you find yourself editing VA/GH code, you
  have crossed a lane; stop.
- **Never `git add -A`.** Scoped staging by explicit path, always.
- **Do not open a PR, do not merge.** This lane proves or dies in the worktree; Shinichi decides after.
- Run `bash ~/shinichi-brain/tools/lane_preflight.sh .` at orient **and again before claiming anything**.

**STATE THIS LINE when you start:**
`PLATFORM: claude | LANE: integrated-SDM experiment | FOREIGN LANE: codex (VA/GH) + cursor (CRAN 0.7)`

---

## 1. Critical context — the science, settled

**Do not re-derive this.** It is already in the vault, and it has already been mistaken for a novel finding
once and retracted the same day.

One ecological intensity `μ(s)` — abundance per unit area:

```
log μ(s) = β₀ + X(s)β + ξ(s)
```

**Presence-only** is a *thinned point pattern*; bias adds on the log scale:

```
log λ(s) = log μ(s) + α₀ + X_B(s)α + ξ_B(s)          Y_PO ~ IPP(λ)
```

**Presence/absence** is *derived*, not assumed. Under a Poisson process,
`p = 1 − exp(−a·μ)` for a site of area `a`, hence:

```
cloglog(p) = log a + log μ(s) = log a + β₀ + X(s)β + ξ(s)      Y_PA ~ Bernoulli(p)
```

**So `β₀`, `β`, `ξ(s)` are literally the same parameters in both likelihoods**, which are conditionally
independent given `X` and `ξ`. `log a` is an **offset**. Only the observation layer differs.

**`cloglog` is compulsory, not a preference** — it *is* the change-of-support from a point process to a
binary observation. Logit or probit breaks the derivation and the parameters stop being shared.

**This construction is TEXTBOOK** — Fithian et al. 2015; Fletcher et al. 2019 Eq. 7–8; Dovers et al. 2024
Eq. 2–3. **Claim none of it.** The possibly-new part is **multispecies latent factors on top of it**.

**Reference method (same substrate as us):** Dovers, Popovic & Warton (2024), *MEE* 15:191–203,
doi:10.1111/2041-210X.14252, package `scampr`. Speed comes from **fixed-rank-kriging basis functions** —
`ξ ≈ Z(s)u`, `ξ_B ≈ Z_B(s)b`, `u`,`b` independent Gaussian — which reduces the model to **a GLMM with
independent random effects**, fitted by **Laplace approximation in TMB**, ~10× faster than INLA. Spatial
integral by quadrature. **They name "the multispecies setting" as their own open future work** — that is
this lane.

**Vault sources, read them:**
- `~/shinichi-brain/memory/In an integrated SDM the latent factors are the natural sink for spatial sampling bias.md`
- `~/shinichi-brain/projects/deep-research/dr30-multispecies-integrated-sdm-latent-factors-distilled.md`
- `~/shinichi-brain/docs/dev-log/handover/2026-08-08-gllvmTMB-integrated-sdm-experimental-lane.md`
- Issues **#941, #943, #945**

## 2. Landmines already documented — do not rediscover

1. **Only `α₀ + β₀` is identified from presence-only data** (Fithian proof; Dovers restate it). Absolute
   intensity and cross-species comparison need the PA arm. **An extractor named `ecological_*` that
   silently returns ecology-plus-bias is the failure mode** — name the quantity honestly.
2. **Latent factors absorb spatial sampling bias.** `u_i` is site-level and so is unmodelled recording
   bias; two species over-recorded in the same places load on a common factor and get reported as
   positively associated. Corpus-backed for PA (Tobler et al. 2019); **the PO case is unstudied** (#943).
3. **⚠️ THE GATE, and it is untested.** A GLLVM pins the latent scale by convention (`u ~ N(0, I)`, `Λ`
   lower-triangular with positive diagonal), so **`Λ` carries all the scale**. Nobody has checked whether
   that still gives a **unique, well-scaled** solution when one species' `λ_j` is informed by **two
   likelihoods of very different curvature** (Bernoulli-cloglog vs Poisson-IPP). Keep **identifiability**
   (unique?) separate from **estimability** (well determined? — the arms carry very different Fisher
   information).
4. **Define correlations on the ecological linear predictor**, upstream of the observation layer. Link
   variances (π²/3 logit, 1 probit, π²/6 cloglog) have no Poisson-log counterpart, so "the link residual"
   for a species spanning both is genuinely ill-posed. Upstream ⇒ family-free by construction — but the
   output **must name its scale**, as it is not comparable with a single-source binomial GLLVM's.
5. **A simulation generated from the fitted model cannot fail.** It measures recovery, never benefit. The
   honest arm is **misspecification** — spatially structured bias correlated with the environmental
   predictors, which a per-source constant `γ[d,j]` cannot represent.

## 3. What already exists — check before building

- **Mixed families are already reachable from the public API.** `family` accepts a list
  (`R/gllvmTMB.R:869`, `R/fit-multi.R:505–526`); `R/data-mixed-family.R` has `family_list`. A prior session
  wrongly recorded this as unreachable — verify in the source, not from a summary.
- **`Λ` is per-species, not per-family.** One `λ_j` however many families that species' rows use, so
  `Σ = ΛΛ' + diag(ψ)` is structurally untouched. **This is the decisive argument for one-species-many-families
  encoding** over tying two columns together, which would plant structural 1s in the correlation matrix.
- `offset()` is supported for count families (#833). Spatial machinery exists (`spatial()`, Matérn, SPDE).

## 4. Landing state

| artifact | committed | pushed | state |
|---|---|---|---|
| this handover, on `claude/experiment-integrated-sdm` | y (see below) | n | **the lane's entry point** |
| worktree `~/local-scratch/worktrees/gllvmtmb-isdm` | — | — | created 2026-08-08, empty of code |
| **285 unpushed commits across ~dozens of `agent/*` branches** | y | **n** | **PRE-EXISTING, NOT THIS LANE'S.** `handoff_gate.sh` fails on them. **Do not land, rebase, or delete them** — provenance unknown, and they predate this work. Declared here so the gate failure is explained rather than silently inherited. |

The authoring session introduced **no** unlanded code. The working tree was clean at branch creation.

## 5. Next immediate steps — OWED, in order, narrow on purpose

**Do not start with GBIF.** Start where the truth is known.

1. **Orient.** Lane preflight; read §1–§3 above and the vault sources; classify every item here
   `OWED` / `DONE` / `RETRACTED` / `PROTECTED` against actual repo state.
2. **Plumbing check, one species.** Simulate from the Dovers model — shared `μ(s)`, a PA arm with `log a`
   offset + cloglog, a PO arm with thinning bias. Fit jointly. **Recover `β`.** This only tests that the
   offset and the two links genuinely share parameters. Keep it in `tests/` or a scratch script; **do not
   touch `src/gllvmTMB.cpp` yet**.
3. **THE GATE — two species, one latent factor.** **Planted-`Λ` recovery under mixed families**, scored
   **rotation-invariantly** via `extract_Sigma_B()`. This is landmine 3. **If `Λ` is not recoverable when
   one species' rows span two curvatures, stop and report — the design needs rethinking before any
   ecology.** A negative result here is a genuine finding, not a failure.
4. **Only then:** the misspecification arm (landmine 5) and the bias-strength ladder (#943).

**Compute:** seeded multi-arm simulation belongs on **Totoro** under the standing authorisation, not a
laptop (`~/shinichi-brain/projects/COMPUTE-PLAYBOOK.md`).

## 6. Environment

- **Working directory:** `~/local-scratch/worktrees/gllvmtmb-isdm` (**not** the Dropbox checkout).
- ⚠️ `~/local-scratch` is **outside Dropbox and is not backed up.** Commit early; if you produce anything
  you would hate to lose, push the branch or copy it to `~/Dropbox/_archive/`.
- **Toolchain:** R + TMB. Safe verification: `devtools::load_all()` then the targeted simulation script.
  **Local checks over CI** — do not push to trigger GitHub Actions.
- **Do not stage:** anything under `src/` touching VA/GH; anything on the CRAN path; `.Rproj.user`;
  scratch data.

## 7. Blockers / open questions

- Landmine 3 is the whole risk. Everything after it is contingent.
- Counts vs binary for the PO arm: quadrature/pseudo-absence weighting is a real design choice — read
  Dovers §2.2 before picking.
- **Collaborator note, not a blocker:** the reference paper's authors are **UNSW — Gordana Popović and
  David Warton**, and Gordana is already on Shinichi's advisory-board invite list. If this lane produces
  anything, that conversation should happen before any public claim.

---

## Resume prompt

```text
Read AGENTS.md and docs/dev-log/handover/2026-08-08-claude-handover-integrated-sdm.md. Run the handover rehydration steps, reconcile them with the current git state, then continue only the OWED Next Immediate Steps.
```
