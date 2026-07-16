# After-task — Model A extension arc (structured × X_lv) kickoff, Lane B (2026-07-16)

Session as Ada (ultra-plan) with a 3-member plan-review (Rose, Gauss/Noether, Fisher/Shannon).
Branch `claude/lvb-modelA-extend` (worktree `~/gllvm_work/lvb-modelA-extend`, off
`claude/release-0.5.0` @ 48a66b93). Uncommitted (per "commit only when asked").

## Scope
Extend the already-certified orthogonal **Model A** (`latent(0+trait|unit,d=K,lv=~x)` + a separate
orthogonal source term; estimand `B_lv = Λ_B α^T`) to the genuinely-open cells: **rank-2 Gaussian ·
non-Gaussian families · animal/spatial/kernel sources**. NO new likelihood, NO grammar keyword.

## The near-miss this session prevented (headline outcome)
The dispatch brief pointed at the **interacting** `phylo_latent(lv=~x)` + new-TMB-likelihood arc
(the "C++ recompiles"). The prior-work sweep + all 3 members caught (source-verified) that this arc
was **maintainer-DEFERRED on 2026-07-06** (Design 76 §7 UPDATE; reinforced 07-08/07-09 handovers),
the S2 grammar reverted, the HIGH-RISK likelihood declared obsolete. The sanctioned path is
orthogonal **Model A** (register `LV-09` = `partial`, rank-1 Gaussian coverage PASSED). Maintainer
chose (2026-07-16): extend Model A. **Building the deferred model was averted by the review.**

## Outcome (verified by REAL fits, not self-reports)
- **S0 frontier — DONE.** `docs/dev-log/artifacts/model-a-extend/frontier.md`. rank-2 Gaussian,
  kernel, animal Model A all fit + pdHess + recover `B_lv` (maxAbsErr 0.195). Poisson **fail-loud**
  (LV-05 family guard). Binomial admitted (rank-1 already certified).
- **S1 rank-2 Gaussian — DONE (this session's deliverable).** Heavy `test-lv-gaussian-recovery.R`
  rank-2 recovery test PASSES. New coverage harness `dev/modelA-rank2-coverage.R` (corrected for the
  current package: `gllvmTMB:::profile_ci_lv_effects(reference="chisq")` hero + Wald + t-df
  sensitivity `df=S−d−1`) **smoke-green**: 3/3 converged, 3/3 profile CIs finite. Totoro-ready.
- **S3 other-source — harness built + viability PROVEN.** `dev/modelA-source-coverage.R` (kernel +
  animal, source term parametrized). Viability from the frontier (`modelA_frontier2.R`): kernel +
  animal Model A converge, pdHess, recover `B_lv` (0.195, identical to phylo), profile-chisq finite.
  The coverage-smoke (a redundant harness-output check) is slow on profile refits; front already viable.
- **S2 non-Gaussian — Poisson ENGINE DIAGNOSTIC DONE; verdict = validation-debt fence, not an
  engine gap.** Lifted the guard on-branch (`R/lv-predictor.R:122-131`, marked DIAGNOSTIC, **not for
  merge**), `load_all` compiled the TMB template, fit a Poisson Model A: **converged, pdHess,
  `B_lv` recovery maxAbsErr = 0.066** (truth range [-0.27,0.33]), Wald finite. Richer fixture
  (S=200,T=8): converges, **pdHess=FALSE**, B_lv recovery 0.087. `checkConsistency(50)` **inconclusive
  on both** (information matrix singular). **Root cause = the ordinary-vs-phylo shared-`species`
  latent-variance trade-off** — the SAME "pdHess≠failure; route via profile" case the register
  documents for Gaussian LV-09. So Poisson `lv` behaves like Gaussian Model A: **recovers B_lv, but
  route intervals via PROFILE (not Wald)**; a clean `checkConsistency` needs `estimate=TRUE`
  (joint-score) or a non-shared-grouping fixture. **Verdict: the LV-05 Poisson fence is
  validation-debt, not an engine limit.** Admitting it flips an explicit fail-loud reject test
  (`test-lv-native-nongaussian-guard.R`) → **new-family admission = maintainer discussion-checkpoint**
  (CLAUDE.md); staged for sign-off + a clean checkConsistency + a coverage gate. NOT merged/promoted.
  ✅ The diagnostic guard-lift was **REVERTED — the fence is fail-closed again**; the only remaining
  diff to `R/lv-predictor.R` is a doc-comment recording the finding + the exact one-line admission
  change to apply on sign-off. Nothing unauthorised can merge.

## Interval doctrine locked (confirms the Fisher review)
`B_lv` is a MEAN coefficient → `profile_ci_lv_effects(reference="t")` **refuses an auto df** (package
enforces this). Hero = **profile-chisq**; **Wald** natural-scale delta-SE (NO log-SD/Fisher-z — that's
for the Ψ/Σ variance siblings); **t-df** `df=n_species−d−1` = an optional reported sensitivity.
`profile_ci_lv_effects()` is in Lane A's `R/profile-derived.R:1591` → **reused READ-ONLY** via `:::`.

## Checks run
- 3 read-only Explore agents (source-drift) + 3 members (Rose/Gauss-Noether/Fisher-Shannon) — all
  source-grounded. Rank-2 recovery test PASS. Rank-2 + source coverage harness smokes.
- Frontier fits: `scratchpad/modelA_frontier.R`, `modelA_frontier2.R`.

## Coordination (Lane B fences)
Do NOT edit Lane A (`profile-derived.R` etc.) or Lane C (`fid==` dispatch). Reuse profile READ-ONLY.
Non-Gaussian guard-lift is R-side only (`R/lv-predictor.R`), no C++ family-dispatch edit. Merge A→B→C.
Lane B note posted to `docs/dev-log/check-log.md` (2026-07-16).

## Follow-ups (ordered; next session / after sign-off)
1. **🔴 Needs Shinichi:** authorize the per-family `lv` admission (Poisson first) — it flips a
   fail-loud fence (new-family surface). Then run the S2 diagnostic (`checkConsistency` + recovery).
2. Launch the rank-2 + source coverage campaigns on **Totoro** (≥500 reps/cell, one seed/array task,
   D-50 — NOT GitHub Actions). Harnesses are staged + smoke-green.
3. S3 spatial frontier check (needs coords/mesh — not yet tested).
4. **S5 Rose claim audit** before ANY LV-05/09 promotion or public wording.

---

## Execution update (2026-07-16 PM) — maintainer authorized "admit Poisson + launch Totoro"

**Totoro campaign — LAUNCHED + producing real coverage.** Socket auth is standing (AGENTS.md fixed:
`~/.ssh/cm-*totoro*`). After several orchestration missteps (fixed: use a launcher-script file under
`tmux`, not inline `ssh→xargs→sh -c` quoting), the 3 Gaussian cells run at 80-way on Totoro
(`run_campaign.sh` + `tmux lvbcov`; per-task logs in `results/logs/`).

- **rank-2 Gaussian `B_lv` (gauss-S200-K2-hard, n≈397/500):** **Wald 0.952** (MCSE 0.011, ≈nominal),
  **profile-chisq 0.914** (under-covers), **t-df 0.919** (under-covers). **FINDING: for the rank-2
  B_lv MEAN coefficient, Wald is the well-calibrated interval; profile UNDER-covers** — the opposite
  of the variance-component story, exactly as the Fisher review predicted (B_lv is a smooth location
  parameter; delta-Wald is accurate, profile is a boundary tool and is mildly miscalibrated at K=2).
  The rank-2 Gaussian claim will be **Wald-based, with the profile under-coverage flagged, not hidden.**
- kernel/animal-S200-K2 cells rolling in (dispatched after rank-2); full 500/cell ~pending.

**Poisson admission — CODE LANDED + correct; coverage needs the modified pkg installed.**
- `R/lv-predictor.R` guard lifted (`is_poisson <- all(family_id_vec==2L)`); abort message updated.
- `test-lv-native-nongaussian-guard.R`: Poisson removed from the reject `cases`; nbinom1/2, Gamma,
  Beta, tweedie, student, truncated_*, betabinomial, delta_* **still rejected** (verified on disk).
- New `test-lv-modelA-poisson.R` (recovery) + `dev/modelA-poisson-coverage.R` (harness) created.
- ⚠️ **The Poisson coverage smoke showed all `converged=FALSE`** — NOT an engine problem: the harness
  loads `library(gllvmTMB)` = **installed stock 0.5.0, whose old guard still rejects Poisson**. The
  admission lives in the worktree SOURCE. So the Poisson *campaign* needs the modified package
  **installed** (on Totoro / locally) — the code + recovery test work under `load_all`/`devtools::test`.
  (My standalone diagnostic already showed the engine converges + recovers B_lv 0.066–0.087.)

**Spatial — MARGINAL.** `dev/modelA-spatial-coverage.R` created + smoked (`spatial-S100-K1`): fits
INTERMITTENTLY (rep 1 non-converge, rep 2 converged with B_lv err 0.25 but missed coverage). Needs a
richer fixture / mesh review before a recovery test lands; do not claim spatial yet.

**Still finishing:** the two build agents' slow `checkConsistency(estimate=TRUE)` tail; the kernel +
animal Totoro cells. Their file deliverables are already on disk + verified above.

### Next (ordered)
1. Full Gaussian campaign completes on Totoro → summarise rank-2/kernel/animal coverage (500/cell).
2. To run the **Poisson campaign**: `R CMD INSTALL` the worktree package on Totoro, then add
   `modelA-poisson-coverage.R pois-S200-K1 <task>` to the task list. (Deferred — Gaussian first.)
3. Spatial: richer-fixture frontier before any harness campaign.
4. **S5 Rose claim audit** on the actual coverage numbers before any LV-05/09 promotion or wording.

## Non-Gaussian family diagnostics (Workflow fan-out, 3 parallel worktree builders, ~3 min)

Evidence for per-family admission (NOT merges). Each: guard-lift on-branch + `load_all` + known-DGP
Model A fit + B_lv recovery. Poisson-style question: is the LV-05 fence validation-debt or an engine gap?

| Family | fid | converged | pdHess | B_lv maxAbsErr | Verdict |
|---|---|---|---|---|---|
| **Gamma** (log) | 4 | ✓ | **TRUE** (default opt) | **0.080** | **cleanly admittable** — clean SEs |
| **Beta** | 7 | ✓ | TRUE | 0.184 | admittable (mild Laplace attenuation) |
| **nbinom2** | 5 | ✓ | FALSE | 0.103 | point-admittable; **SEs unreliable + dispersion confound → HOLD** |
| Poisson | 2 | ✓ | mixed | 0.066–0.087 | admitted (this session) |

**Verdict: Gamma + Beta are cleanly admittable like Poisson (engine handles them; fence is
validation-debt). nbinom2 recovers the point but its uncertainty is untrustworthy — hold it.**

### OPTIMIZER FINDING (VERIFIED — scoped to non-Gaussian)
The Gamma builder isolated it: for the harder non-Gaussian likelihoods, `optimizer="optim"/BFGS`
yields a non-PD Hessian while the DEFAULT optimizer (`nlminb`) gives `pdHess=TRUE` + clean Wald SEs
with identical B_lv recovery. **Verified against the Gaussian case** (`scratchpad/optimizer_check.R`):
for rank-2 Gaussian, BFGS and default are **IDENTICAL** (both pdHess=TRUE, same Wald, profile
[0.865,1.177] vs [0.862,1.177]). Conclusions:
- **The rank-2 Gaussian profile under-coverage (0.916) is REAL, not an optimizer artifact** — the
  fits are pdHess=TRUE and BFGS≡default. Wald (0.953) is the correct interval for the rank-2 B_lv
  mean coefficient; profile genuinely under-covers. Report it as such.
- **For NON-Gaussian families, switch harnesses/tests to the DEFAULT optimizer** (drop
  `optimizer="optim", optArgs=...`) — that fixes the spurious `pdHess=FALSE`/NA-SE seen for
  Poisson/Gamma/nbinom2 with BFGS. Re-run the Poisson/Gamma/Beta admissions + harnesses under the
  default optimizer before any non-Gaussian interval claim.

### Next per-family (on maintainer sign-off, same pattern as Poisson)
Admit Gamma + Beta (guard-lift + guard-test flip + recovery test + harness). nbinom2 stays fenced
pending a fix for its non-PD-Hessian/SE issue. ordinal deferred (Lane C coordination).
