# Tree-axis latent correction: approved execution plan

## Goal and approval

Codex owns isolated dca1/gllvmTMB and the bounded
codex:tree-axis-latent-correction-20260830 lease. Deliver two runnable examples
and verify the deployed article, preserving all requested covariance components.
No new API, engine, spatial model, recovery campaign, manuscript edits or release.
Shinichi approved the complete reviewed plan with "PLEASE IMPLEMENT THIS PLAN"
on 2026-08-30. This supersedes the earlier population-replicated draft.
Gauss/Noether/Fisher conditionally passed its mathematics; Darwin/Pat passed the
biology; Rose passed after explicit map, fit-budget and publication repairs.

## Locked symbolic and implementation contract

Example 1: 80 species x six traits, one multivariate observation/species.
Traits: leaf area, specific leaf area, leaf dry matter content, stem height,
seed mass, root depth. All are synthetic standardized morphology measurements.
Fixed effects are trait means and trait-specific standardized species-elevation
slopes. Both phylo_latent(d=2, unique=TRUE) and ordinary species
latent(d=2, unique=TRUE) must be active, with unit="species".
For species-major stacking, Cov(vec(Y^T)) = A (x) Sigma_phy + I (x) Sigma_non;
each Sigma = Lambda Lambda^T + Psi. Simulate all four contributions separately.
Check labels, scaling, positive definiteness and the rank/condition of normalized
vech(A),vech(I). Two loading dimensions do not establish source separation.

Example 2: 150 sites x 50 species, C3/C4 fixed pathway means and standardized
latitude slopes. Compare column_coef() and phylo_coef() species intercept/slope
deviations; BOTH include ordinary site latent(d=2, unique=TRUE). Plant rho=.60,
fit rho=NULL. Retain coefficient SDs (.18,.55), correlation -.25, pathway
intercepts (.85,.45), slopes (-.30,.55). The exact implementation uses
K_rho = rho K + (1-rho) diag(diag(K)); DGP and fit must share labels/scaling.

Gaussian identification: ordinary Psi absorbs independent per-cell variation.
Assert all log_sigma_eps map entries NA and fixed sigma_eps=max(1e-3 sd(y),1e-6).
This numerical stabilizer is not an extra estimated biological component.
No within-species variance interpretation. Freeze seeds, rank-two loadings,
positive heterogeneous Psi and deterministic non-truth starts before fitting.
Public extract_Sigma(shared/total, link_residual="none") must verify the
shared-plus-diagonal identity; private engine inspection stays in validation.

## Fit ledger and compute limits

| IDs | Purpose | Count |
|---|---|---:|
| C1-C2 | Small morphology and coefficient/site composition checks | 2 |
| M1-M3 | Target long morphology, phylogenetic and IID coefficients | 3 |
| S1-S6 | Two additional deterministic starts for EACH target | 6 |
| W1-W3 | Corresponding wide formulas | 3 |

Maximum 14 optimizer attempts; no rank-one checks. Execution clarification:
the public API supplies distinct jitter starts only through n_init=3. Thus
M1-M3 each encompass three attempts (the S IDs identify attempts 2/3),
while C1-C2 and W1-W3 each use one. Eight model calls, 14 optimizer attempts.
Per-start covariance evidence remains required; restart_history alone is not
enough. Validation instrumentation may retain optimizer outputs within process
without changing any package API/engine. This does not expand the fit budget. One successful article render
may execute three primary fits; wide calls are displayed but independently run
under W1-W3. Count additional/failed renders and package-check reruns separately.
Estimate each fit and enforce process timeout. C1/C2 provisionally 1-5 minutes
each, five-minute limit; calibrate target estimates from measurements. A block
above 30 minutes needs measured pre-run evidence and approval. No campaign,
seed hunting, truth starts, favourite-start selection or threshold changes.

## Acceptance ledger

All three starts per target: finite objective, convergence zero, existing
gradient screen <1e-2. Relative objective spread <=1e-6; reported source/shared
covariance matrices and shared/unique variance vectors within 10% relative norm.
Long/wide objective difference <=1e-6 normalized, fitted difference <=1e-4
response SD. These are stability screens, NOT recovery guarantees. Run public
gllvmTMB_diagnose(), retain all warnings/failures, label uncomputed Hessians and
uncertainty unassessed. A failed gate stops interpretation of that model.

Synchronize DGP, equations, both public formats, extracts, results, captions,
figures and recap. Four figures: axis map; Example 1 source correlations and
four-part variance bars; Example 2 pathway/species trajectories; Example 2
residual correlations and public unit ordination. No private phylo scores or
API expansion. Site ordination is within-fit and conditional; no cross-model
axis comparisons. Truth displays describe ONE synthetic realization, not
recovery or coverage. Residual association does not establish interactions.

## Delivery and stops

Use .unlazy/tree-axis-latent/GATES.md. Run focused tests, document/check_pkgdown,
affected article render, package check, independent method/reader/figure review,
and after-task/check-log closeout. Routine CI is Ubuntu-only; verify manual
full_matrix=true at the candidate commit on Ubuntu/macOS/Windows. Prefer reuse
of draft PR1229 after live ownership checks, preserving history; do not merge
it automatically. Explicit landing gate, then deployment/live-page verification.
Approval covers scoped edits/checks/builds/commits and draft PR preparation.
Stop for ownership conflicts, API/engine expansion, fit-budget exhaustion,
unresolved instability, larger compute, or absent landing approval.
Private manuscripts inform design only: no public copying or upload.

## Intake receipt

Fetched origin/main: 9c265e76b54ea0f238d5487066964dd81e897f65.
PR1229 handover: 739213bfd211036b1f915b9a0c8da047a918d83e.
Correction branch tracks the handover; merging origin/main was already up to date.
Preflight reported foreign/direct-main and historical Codex lanes; only the
explicit article/validation/closeout lease was refreshed. Older PRs untouched.

## Execution checkpoint (2026-08-30)

Isolated source install passed in84.574s at
/private/tmp/gllvm-tree-axis-latent-20260830/library; source hashes/sessionInfo
retained in the same scratch directory. No engine/API/source edits.
Fixture construction passed for20x6/50x20 canaries and80x6/150x50 targets; all
three Lambda matrices rank2. Engine/tree covariance errors2.76e-11/2.69e-12;
source design rank2 with normalized condition1.278/1.341.
C1/C2 ran from frozen-C1-C2 script copies, one optimizer attempt each: fitting
0.787s/1.464s, convergence0 both, gradients1.86e-5/1.76e-4. Gaussian maps
and fixed stabilizer values passed. Original receipts retained unchanged.
Harness post-processing incorrectly coerced fitted() data.frame to numeric;
repair extracts from saved objects without refitting. The parList(fullvector)
helper caused a replacement warning; parList() reads fixed scales correctly.
M1 and W1 pass. M2/M3 have false-convergence stops (1,1,0)/(0,0,1), despite
passing gradient/objective/covariance stability screens. Twelve optimizer
attempts used; W2/W3, full render, package checks, CI and publication held.
No-fit article checks pass exact frozen fixture equality, six public formula
argument sets and morphology public output generation. The source remains an
explicitly incomplete draft. Six additional BFGS attempts (three per community
model), each model call capped at five minutes, are recommended but NOT
approved or executed. See the after-task report and check-log.

## Approved BFGS adjudication

The maintainer replied "OK - do yoiu want to unstall automatically once it is
done??" to the explicit six-attempt request. This approves B2/B3: three BFGS
starts for each community model, five-minute process cap per model. Continue
through the original checks/PR preparation automatically if these pass; no
landing approval is inferred. Models, DGP, seeds, jitter and numerical screens
remain unchanged. Original M2/M3 failures are historical failures, not erased
or relabelled. B2/B3 use additional immutable receipts. W2/W3 retain their
original one-attempt budget and use the same qualified optimizer if admitted.

Gauss/Noether approved process-local optim tracing before the follow-up. A
non-statistical quadratic unit check confirms exact original return values,
exact entry starts, and refusal of a fourth optimizer call before evaluating
its objective. It is an instrumentation test, not another model fit. Exact
executed scripts are retained in frozen-BFGS beside earlier frozen scripts.

BFGS outcome: B2 attempt1 returned impossible NLL -5.3484e29 (Gaussian bound
-46,170.99), then root interrupted attempt2 at76.514s. Two additional attempts
entered, one completed/one interrupted. B3/W2/W3 withheld after method review.
Further numerical investigation is a separate approval boundary; no blind
refit, threshold relaxation or partial-example publication is authorized.

## Approved focused numerical investigation

Shinichi answered "Yes please go ahead" to the request for a focused numerical
investigation with frozen models and no new API or campaign. Fixed-point
replays isolated a negative coefficient-prior quadratic caused by forming and
inverting an ill-conditioned Cholesky covariance. The localized arithmetic
repair uses triangular whitening in the existing native coefficient prior;
parameterization, maps, reporting and estimand are unchanged. A private header
allows compiled regression tests to exercise the actual production helper.

No outer optimizer attempt was added by this investigation. Fourteen have
entered so far. Baseline DLL/fits remain immutable. At the failed point the
repaired joint agrees with an independent triangular calculation to relative
8.63e-14; healthy M2/M3 objectives change by at most1.18e-9. The bad BFGS point
still has no usable inner mode (NaN, inner gradient3.77e30); it remains failed.

Gauss/Noether recommend requesting eight repaired-source nlminb attempts:
three unchanged deterministic starts for EACH community model, then one wide
fit for each only if both long models pass. This supersedes unspent BFGS/wide
slots and increases the total ceiling from20 to22; it does not add eight on
top of all remaining old slots. This request has NOT been approved or run.
Prior three-start timings were60.881s IID and137.179s phylogenetic. Estimate
1-3min and2-5min respectively, plus1-3min each wide fit; five-minute process
limit per call and no BFGS. Total estimated5-14min. All original gates apply;
a failed long model stops wide fits, interpretation and rendering. No seed,
rank, diagonal, tolerance, optimizer limit or model change is proposed.

## 2026-08-30 — eight repaired-source attempts approved; fresh continuation

Shinichi explicitly approved: "Approve the eight fits in a fresh task."
This supersedes pending-approval wording above and in the numerical checkpoint.
The six unspent old slots are replaced by eight repaired-source nlminb attempts;
total ceiling 22, with 14 entered before this continuation. N2/N3 each comprise
three unchanged deterministic starts; NW2/NW3 each one, only after BOTH long
models pass every original gate. No BFGS, changed starts, changed thresholds,
new model or campaign. Five-minute cap per model call. Estimates: IID 1-3min,
phylogenetic 2-5min, each wide 1-3min; block 5-14min.

The released lane is resumed in isolated 7c88/gllvmTMB on
`codex/tree-axis-latent-repaired-20260830`, preserving commit 2e10e3fb.
SSH fetch verified origin/main 9c265e76 and no main commits missing from HEAD.
PR1229 is OPEN/DRAFT at 739213bfd; prefer extending it. No landing authority.
Fresh immutable result directory: /private/tmp/gllvm-tree-axis-latent-20260830/repaired-nlminb-7c88.
Source/header/DLL hashes match the saved production build; old results remain untouched.
The own lease and acceptance ledger retain ALL article/package/CI/deployed gates.

## 2026-08-30 — saved-endpoint diagnostic authority clarified

Coordinator confirms that the exact-Gaussian saved-endpoint value/gradient
check is covered by Shinichi's prior "Yes please go ahead" numerical-investigation
approval. Earlier text proposing another authorization is superseded; no new
permission is needed for this bounded no-optimizer diagnostic. No new fit block,
model/seed/truth/threshold/API/engine change or interpretive waiver is authorized.
Reuse check-gaussian-likelihood.R's covariance algebra; compare independent
analytic scores and directional finite differences at all six saved N2/N3
endpoints with repaired TMB values/scores. Estimate5-30s, process cap30s.
