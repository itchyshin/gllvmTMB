# Random slopes × dependence × families — completeness audit and gap tracker

**Status date:** 2026-06-01
**Author lens:** Claude Code (read-only completeness synthesis)
**Sources of truth:** `docs/design/35-validation-debt-register.md`
(row-by-row ledger) and `docs/design/61-capability-status.md`
(capability matrix + two-track work-list), reconciled against
`origin/main` HEAD `3ef12df` on 2026-05-31. This document does **not**
re-derive status; it consolidates the slope/dependence/family axes into
one completeness view and turns the open cells into a checkable closure
list. Where this doc and Design 35 disagree, **Design 35 wins** and this
doc is the stale one.

This is an audit, not an engine change. Every gap that touches likelihood,
formula grammar, family support, or the TMB parameter map is tagged
**Track B (maintainer-sequenced)** per `CLAUDE.md` / `ROADMAP.md`
discussion checkpoints and must not be filled by agent fan-out.

---

## 1. Direct answer

> *"All random slopes and all dependence done for all families?"*

**No — not the full cross-product.** The honest one-line state:

- **Intercept-level dependence** (`phylo_*`, `spatial_*`, `animal_*`,
  `kernel_*`) is **broadly covered**, often on the binary scale too.
- **Random slopes** are **Gaussian-validated across the whole keyword
  family**, and the **augmented engine is family-general with zero new
  C++**. Non-Gaussian slope coverage is filled for the *diagonal*
  (`phylo_indep`) and *block-diagonal* (`phylo_latent`, `spatial_latent`)
  modes, but the *full-unstructured* (`dep`) modes stay **reserved**
  (fail-loud behind a family guard, not unbuilt) because the full
  covariance is not identifiable for non-Gaussian families at the current
  fixtures.
- **CI coverage gates** (Gaussian `CI-08`, mixed-family `CI-10`) are
  **failing** and must not be advertised as done.
- A handful of families (mixtures, gengamma, delta/hurdle latent
  correlation) are **blocked** by design or by a missing derivation.

So: slopes are done for Gaussian everywhere and for non-Gaussian on the
diagonal / block-diagonal modes; the unstructured-`dep` non-Gaussian
cells, two CI gates, and a few families remain open. The matrices below
say exactly which.

Legend: **C** covered · **P** partial · **R** reserved (engine exists,
family-guard fail-loud, validation pending) · **N** not implemented ·
**B** blocked (needs derivation/removal) · **—** n/a.

---

## 2. Random slopes × family (`0 + trait + trait:x | group`)

| Slope mode | Gaussian | Binomial | Poisson | NB2 | Gamma | Beta | Ordinal | Register IDs |
|---|---|---|---|---|---|---|---|---|
| `phylo_slope` / `animal_slope` (scalar) | C | C | C | C | C | C | C | RE-02, FG-15, PHY-06, ANI-06 |
| `phylo_indep(1+x)` (diagonal) | C | C | C | C | C | C | C | PHY-11..16 |
| `phylo_latent(1+x, d=K)` (block-diag RR) | C | C | C | C | C | C | C | PHY-17 |
| `phylo_dep(1+x)` (full unstructured) | C | **R** | **R** | **R** | **R** | **R** | **R** | PHY-18 |
| `spatial_indep(1+x)` (diagonal SPDE) | C | **R** | **R** | **R** | **R** | **R** | **R** | SPA-08, B4 |
| `spatial_latent(1+x, d=K)` (block-diag RR) | C | C* | C | **P** | C | C | **P** | SPA-09 |
| `spatial_dep(1+x)` (full unstructured field) | C | **R** | **R** | **R** | **R** | **R** | **R** | SPA-10 |
| multiple slopes `s ≥ 2` | C | **R** | **R** | **R** | **R** | **R** | **R** | RE-03 |

\* `spatial_latent` is C for binomial-probit/poisson/Gamma/Beta at the
matrix fixture; binomial-**logit**, **ordinal_probit**, **nbinom2** are
**P** — they construct and converge and are PD at alternate seeds / n=150
but honest-skip at the default fixture seed (a power/seed artifact, not
non-identifiability). `animal_slope` non-Gaussian cells are the
`phylo`-path equivalents and inherit the same reserved status.

**Read:** the only true engine-shape gaps are the **`dep` (full
unstructured) non-Gaussian** rows and the **`s ≥ 2` non-Gaussian** row.
Everything else is either covered or a fixture-power fill.

---

## 3. Dependence modes × scale (intercept-only LHS)

| Keyword family | latent | unique | indep | dep | scalar | Notes / IDs |
|---|---|---|---|---|---|---|
| (none, on `unit`) | C | C | P | P | P | FG-04..09. indep/dep/scalar: bare-keyword non-Gaussian closed 2026-05-31; **known-V variant still Gaussian-only** |
| `phylo_*` | C | C | C | C | C | FG-12, PHY-02..05; binary/probit covered |
| `spatial_*` | C | C | C | C | C | FG-13, SPA-02..04; binary/probit covered |
| `animal_*` | C | C | C | C | C | ANI-01..05, byte-equiv to `phylo_*(vcv=A)` < 1e-6 |
| `kernel_*` | C | C | C | C | — | KER-02, C1 equivalence to dense `phylo_*` < 1e-6; no `kernel_scalar` |
| coevolution `extract_Gamma()` | C | — | — | — | — | KER-01, COE-01/02 |

**Read:** the source-specific grids (`phylo_/spatial_/animal_`) are full
for intercepts. The only soft spots are the plain `indep/dep/scalar`
**known-V** non-Gaussian variants (the harder phylo-dep identifiability
item). Ordinary crossed `(1 | group)` random intercepts are now covered
by FG-11/RE-05; trait-specific crossed diagonal grouping is tracked
separately under RE-11 / `cluster2`.

---

## 4. Families × validation tier

| Family | Recovery | Cross-package | IDs |
|---|---|---|---|
| gaussian | C | C (glmmTMB `rr()`) | FAM-01 |
| binomial logit/probit/cloglog | C | C (mirt 2PL) | FAM-02..04 |
| betabinomial | C | — | FAM-05 |
| poisson | C | C (glmmTMB) | FAM-06 |
| nbinom1 | C (wired 2026-05-30/31) | C (glmmTMB light fixture) | FAM-07 |
| nbinom2 | C | C (glmmTMB) | FAM-08 |
| gamma (log) | C | **P** (no comparator) | FAM-09 |
| beta (logit) | C | **P** | FAM-10 |
| lognormal | C | — | FAM-11 |
| student-t | C | — | FAM-12 |
| tweedie | C | — | FAM-13 |
| ordinal_probit | C | **P** (no mirt `graded`) | FAM-14 |
| truncated poisson/nbinom* | **P** | P | FAM-15 |
| censored_poisson | **P** | — | FAM-16 |
| delta_* (10 variants) | C (fixed/latent); random **N/A by design** | B (mixed-family) | FAM-17, MIX-10 |
| gamma_mix / lognormal_mix / nbinom2_mix | **B** | B | FAM-18 |
| gengamma | **B** | B | FAM-19 |

---

## 5. CI-coverage gates (the two failing gates)

| Estimand scale | Machinery | ≥94% coverage gate | IDs |
|---|---|---|---|
| Gaussian ICC / communality / correlations | C | **FAILING** — only d=1, d=3 clear; 13/15 cells below; 236/3000 fits failed | CI-02..07 (C); **CI-08 (P)** |
| Mixed-family (Gaussian+Binomial) | P | **FAILING** — d=1 0.820, d=2 0.685, d=3 0.550; 105/600 fits failed | **CI-10 (P)** |
| Ordinal cutpoints / variance components | **N** | — | EXT-10 (P) |

These are engine/estimand problems (target-explicit `Sigma_unit[tt]` not
`psi`), not documentation. Per Design 50 they gate any public CI claim.

---

## 6. Systematic gap tracker

Every open cell above, as a discrete closeable item. **Track A** = safe
to parallelize today (docs, register hygiene, independent test fixtures;
no engine math). **Track B** = maintainer-sequenced (likelihood / family
guard / TMB map / estimand changes; shares engine data contracts — **do
not fan out**). "Close gate" is the concrete evidence that flips the row
to `covered`. Check the box when the register row is updated and an
after-task report lands.

### Track A — parallelizable now

- [x] **GAP-A1 · poisson cross-package fixture** (FAM-06). Close gate
  already met on main by `test-crosspkg-poisson-glmmTMB.R` (commit
  `41d80e3`): per-trait intercept + random-intercept SD agreement vs
  glmmTMB on the shared two-trait `(1 | site)` Poisson(log) fixture.
  This branch syncs the stale audit/register status.
- [x] **GAP-A2 · nbinom2 cross-package fixture** (FAM-08). Close gate
  already met on main by `test-crosspkg-nbinom2-glmmTMB.R` (commit
  `41d80e3`): per-trait intercept, random-intercept SD, and per-trait
  NB2 dispersion agreement vs glmmTMB with `dispformula = ~ 0 + trait`.
  This branch syncs the stale audit/register status.
- [ ] **GAP-A3 · gamma / beta cross-package comparators** (FAM-09, FAM-10).
  Close gate: a clean comparator (gllvm Procrustes or glmmTMB LL) lands;
  §1c moves cross-pkg P→C. Lower priority (no obvious clean comparator).
- [ ] **GAP-A4 · ordinal vs mirt `graded`** (FAM-14). Close gate: a
  cross-check fixture vs `mirt::mirt(..., itemtype="graded")`.
- [x] **GAP-A5 · crossed random effects recovery** (FG-11 / RE-05).
  Close gate met 2026-06-02 for ordinary scalar `(1 | site) +
  (1 | year)` crossing by `test-multi-random-intercepts.R`: balanced
  Gaussian recovery cell, convergence 0, both SDs within 0.20 of
  empirical truth, and packed BLUP slices correlate with truth > 0.95.
  Trait-specific crossed diagonal grouping remains the separate covered
  RE-11 / `cluster2` slot; ordinary random slopes remain unsupported.
- [x] **GAP-A6 · DIA-09 sdreport-failure fixture**. Close gate met
  2026-06-02 by `test-sanity-multi.R`: `testthat::with_mocked_bindings()`
  forces the namespaced `TMB::sdreport()` call to fail during `gllvmTMB()`
  construction, then asserts the returned fit keeps point estimates,
  records `fit$sdreport_error`, sets `fit_health$sdreport_ok = FALSE`, and
  surfaces a WARN `sdreport` row in `check_gllvmTMB()`.
- [ ] **GAP-A7 · register/capability freeze**. Keep Design 35 the single
  source of truth; ratify Design 61 §1–§2 as the status reference and link
  this audit from it. Serialize writes to the register. *Design 61 A1/A2.*

### Track B — maintainer-sequenced (engine / family guard / estimand)

- [ ] **GAP-B1 · `phylo_dep` slope, non-Gaussian** (PHY-18). Engine
  built + Gaussian-validated. **Identifiability question RESOLVED (sweep
  evidence, 2026-06-02): the non-Gaussian dep covariance IS identifiable
  given adequate data — finite-sample power, not non-identifiability.**
  The N-sweep (`docs/dev-log/spikes/2026-06-01-phylo-dep-slope-identifiability-N-sweep.R`,
  Actions runs #26808484707/#26812586011; see after-task
  `2026-06-02-dep-slope-identifiability-sweep.md`) shows `conv==0 &
  pdHess` reliably reached: poisson at every N (incl. n_sp=80);
  Gamma/Beta/nbinom2/ordinal_probit by N=300; Bernoulli binomial by
  N=1200; gaussian control PD throughout. The prior "non-PD at n≤100"
  rationale reflected small-n / low-`n_rep` matrix-test fixtures.
  Remaining blocker (ii): the matrix-dep harness reads the 2-vector `sd_b`
  channel, incompatible with the engine's `Sigma_b_dep` — production cells
  must read `report$Sigma_b_dep`. Close gate: per-family recovery cell PD +
  within band (at the N this sweep flags), then relax the `c(0L)` allowlist
  one family at a time, mirroring PHY-11..17. **Now an engine task (Track
  B), not a research question** — needs maintainer sequencing.
- [ ] **GAP-B2 · `spatial_dep` slope, non-Gaussian** (SPA-10). Spatial
  analogue of B1; engine built + Gaussian-validated to 1e-9 prior nll. The
  B1 sweep finding (identifiable at adequate N) is expected to transfer;
  worth confirming with an analogous `use_spde_dep_slope` sweep before the
  guard relaxation. Close gate: ≥1 non-Gaussian field-cov recovery cell,
  then relax the `c(0L)` SPDE-dep allowlist.
- [ ] **GAP-B3 · `spatial_indep` slope, non-Gaussian** (SPA-08 / B4).
  Engine built (`use_spde_slope`), Gaussian-only guard at
  `R/fit-multi.R:308`. Close gate: non-Gaussian diagonal SPDE-slope
  recovery, then relax the guard (expected to mirror `phylo_indep`).
- [ ] **GAP-B4 · `spatial_latent` slope fixture-skip families** (SPA-09).
  binomial-logit / ordinal_probit / nbinom2 honest-skip at the default
  fixture. Close gate: wider-n (n≥150) / alternate-seed recovery promotes
  the 3 P cells to C; **no engine change**, fixture/power only — could be
  Track A if scoped to test fixtures only, but lives here because it
  shares the SPDE slope contract.
- [ ] **GAP-B5 · multiple slopes `s ≥ 2`, non-Gaussian** (RE-03).
  Gaussian s=2 covered (dep path is dimension-general). Close gate:
  non-Gaussian (1+s)T identifiability, gated behind the same guard as B1.
- [ ] **GAP-B6 · plain `indep/dep/scalar` known-V, non-Gaussian**
  (FG-07/08/09). Bare-keyword non-Gaussian closed; the `propto()`/
  `equalto()` known-V variant is still Gaussian-only and routes through
  the phylo-dep identifiability path. Close gate: non-Gaussian known-V
  recovery (tied to B1).
- [ ] **GAP-B7 · Gaussian CI coverage gate** (CI-08). Drive 13/15 cells
  to ≥94%; resolve 236/3000 fit failures; target-explicit total
  `Sigma_unit[tt]`. Close gate: ≥94% across the grid + diagnostic report
  (Design 50 surface admission).
- [ ] **GAP-B8 · mixed-family CI coverage gate** (CI-10). Lift d=1/2/3
  from 0.55–0.82 to ≥0.94; estimand redefinition (`Sigma_unit[tt]` not
  `psi`). **Precedes any mixed-family CI article promotion.**
- [ ] **GAP-B9 · ordinal CI extension** (EXT-10 / CI). Extend
  profile/Wald/bootstrap to ordinal cutpoints + variance components.
- [ ] **GAP-B10 · nbinom1 downstream wiring** (FAM-07 follow-up).
  Extractor / simulate / profile NB1 paths + a glmmTMB NB1 LL-agreement
  fixture; tier/phylo/spatial coverage. (Note the `R/enum.R` `nbinom1=10`
  vs `fit-multi.R` `15L` constant split — do not "fix" pre-merge.)
- [ ] **GAP-B11 · truncated / censored counts** (FAM-15, FAM-16). Promote
  from recovery-only / smoke to covered, or honestly down-mark on the
  public surface.
- [ ] **GAP-B12 · mixture & gengamma families** (FAM-18, FAM-19).
  Currently exported-but-unvalidated `blocked`. Close gate: either
  validate or remove from the public surface (API-change checkpoint).
- [ ] **GAP-B13 · delta/hurdle mixed-family latent correlation**
  (FAM-17 / MIX-10 / Design 61 §B11). **Blocked on a derivation** — two
  link scales make the single latent-residual correlation undefined.
  Close gate: a mathematical derivation *before* any code; safeguard
  currently errors with class `gllvmTMB_auto_residual_delta_undefined`.
- [ ] **GAP-B14 · cross-package empirical-agreement grids** (ANI-10,
  SPA cross-pkg, Phase 5.5 sweep). Expert-designed DGPs; explicitly
  Phase 5.5, not M2.

---

## 7. How we fill gaps systematically

The closure loop, per `CLAUDE.md` / `AGENTS.md`:

1. **Pick one gap row, one branch, one PR.** Never bundle a Track-B
   engine change with a Track-A doc change.
2. **Track A items can run in parallel** as long as they touch disjoint
   files; serialize writes to Design 35 (the register is the chokepoint).
   GAP-A1 and GAP-A2 are already closed by existing cross-package fixtures;
   future Track A writes should prioritize DIA-09-style diagnostics and
   register freeze work.
3. **Track B items are maintainer-sequenced.** They mutate shared engine
   data contracts (`b_phy_*`, `g_phy` / `Z_phy_aug`, the SPDE field
   arrays) and the linear-predictor loops, so parallel edits collide in
   `.cpp` and the TMB parameter map. Stop at the discussion checkpoint
   before touching them.
4. **The identifiability cluster (B1, B2, B3, B5, B6) is one investigation,
   not five.** The shared blocker is whether a full-unstructured (or
   known-V) non-Gaussian covariance is identifiable at feasible n. Resolve
   it once (bigger n, reparam, or a principled reserved-forever decision)
   and several rows close together. Recommend tackling this before the
   per-family fan-out.
5. **The CI cluster (B7, B8, B9) is one estimand fix** (target-explicit
   `Sigma_unit[tt]`) plus per-scale coverage runs. B8 gates the
   mixed-family CI articles; do not promote those until it passes.
6. **Every closed gap updates its Design 35 row, flips the box here, and
   leaves an after-task report** under `docs/dev-log/after-task/`. Shannon
   cross-checks the register against the suite at each phase boundary.

### Suggested ordering

1. **GAP-A7** (register/capability freeze) — make this view the reference
   after the current validation-hardening branch lands.
2. **Maintainer decision on the identifiability cluster** (B1/B2/B3/B5/B6):
   invest in bigger-n studies, or formally reserve the unstructured
   non-Gaussian slope modes. This is the single biggest "are we done?"
   lever and needs your call before anyone writes engine code.
3. **GAP-B7/B8** (CI gates) — sequenced engine/estimand work.
4. Remaining family/coverage items (B10–B14) as the roadmap re-ranks them.

---

## 8. Bottom line

We are **most of the way** there: intercept dependence and Gaussian
slopes are done across the board, and non-Gaussian slopes are done for the
diagonal and block-diagonal modes with zero new C++. The remaining "not
done" is concentrated, not scattered: (a) **non-Gaussian unstructured-`dep`
slopes** (one identifiability question, GAP-B1/B2/B3/B5/B6), (b) **two
failing CI coverage gates** (GAP-B7/B8), and (c) a **short tail of
blocked/partial families** (GAP-B11/B12/B13). The cheap Track A
cross-package rows are now closed or synced; Track B needs your sequencing
decision on the identifiability cluster first.
</content>
</invoke>
