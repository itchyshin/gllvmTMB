# MSPL implementation guide for drmTMB (transfer packet)

**Canonical home (preferred):** `drmTMB` repo  
`docs/design/225-mspl-implementation-guide.md`  
**This file:** gllvmTMB transfer packet + full text so agents can execute even if the drmTMB copy is not yet synced.  
**Date:** 2026-08-16  
**Status:** executable transfer guide — **not** an admitted capability; **not** a NEWS/README claim  
**Brain rung used:** shinichi-brain MCP (`search_notes` / `read_note` / `build_context` on project `shinichi-brain`)

---

## 0. One-sentence contract

Port **Laplace outer + softly penalized criterion + registry discipline** from gllvmTMB; do **not** port stacked-trait loadings, GLLVM atoms, or any public covered/interval claim. In drmTMB the theory match is *stronger* than in gllvmTMB for fixed-design logistic submodels — use that advantage; do not invent a third penalty family.

---

## 1. What transfers from gllvmTMB

### 1.1 Conceptual split (mandatory)

Keep these distinct in code, docs, and claims (gllvmTMB programme constitution):

| Layer | Meaning | drmTMB analogue |
|---|---|---|
| Integration | Laplace (or later AGHQ) approx to the marginal | Existing TMB Laplace / `REML` path — unchanged |
| Outer criterion | ML vs MSPL | New opt-in criterion; default stays ML |
| Penalty provenance | Jeffreys / Huber / Hirose atoms + soft scale \(c_n\) | New; **not** the existing PC-prior phylo MAP |
| Inference | Point → internal SE pin → calibrated intervals | Same ladder; intervals last |

\[
\widehat\theta_{\mathrm{LA\text{-}ML}}=\arg\max_\theta \ell_{\mathrm{LA}}(\theta),
\qquad
\widehat\theta_{\mathrm{LA\text{-}MSPL}}=\arg\max_\theta\{\ell_{\mathrm{LA}}(\theta)+P_n(\theta)\}.
\]

Cite: gllvmTMB `docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md` §4; brain `projects/deep-research/dr34-la-mspl-parallel-estimator-distilled`.

### 1.2 Softly-penalized form (literature-matched for drmTMB)

**Primary paper for drmTMB (fixed design + RE):** Sterzinger & Kosmidis (2023), *Maximum softly-penalized likelihood for mixed-effects logistic regression* (DOI 10.1007/s11222-023-10217-3). Composite penalty:

- Jeffreys-type on **fixed effects**;
- negative-Huber on **log-Cholesky / covariance coordinates**;
- recommended soft scale \(c_n = 2\sqrt{p/n}\) (paper); vanish as \(n\to\infty\).

**Gaussian FA companion (only if drmTMB needs a Heywood-like Ψ collapse story later):** Sterzinger, Kosmidis & Moustaki (2026) factor-analysis MSPL — brain `ENGINEERING-NOTEBOOK` + gllvmTMB Hirose ordinary Gaussian route. Prefer **not** as drmTMB Phase-1.

Brain lane note: *Borrow MSPL; do not invent* — `memory/lane-notes/FOR-DRM-LANE-2026-08-08-separation-borrowable-from-the-literature.md`.

### 1.3 Registry states (copy the discipline, not the cells)

From gllvmTMB `R/mspl-registry.R`:

| Status | Meaning | Public door |
|---|---|---|
| `planned` | Fenced tape + oracles; science may be pinned | Opt-in experimental only; **not admitted** |
| `admitted` | Explicit Shinichi/G0 flip after admit packet | Still not NEWS `covered` |
| `excluded` / `deferred` | Named fence | Hard reject |
| Evidence tags | e.g. `oracle_local`, `phase4_prep`, `partial_*` | Never equate to covered |

**Admit-packet discipline:** finite oracles + pinned \(c\) + pinned atoms are **necessary and not sufficient**. Healthy / boundary multi-seed, prediction, sensitivity, and an explicit admission gate remain separate (gllvmTMB Poisson packet pattern).

### 1.4 Point-first, SE second, intervals last

| Stage | What is allowed | What is forbidden |
|---|---|---|
| Point smoke | `se = FALSE`, multi-seed local fits | NEWS covered; `vcov`/`confint` |
| Admit packet | Oracles + rate/atom pins + verdict doc | Registry flip without G0 |
| Internal SE pin | \(Q_P\) / \(Q_0\) availability + PD; **withhold** public `sdreport` | Calling pins "calibrated SE" |
| Intervals | Only after Design-118-style pre-registration + hold-out PASS | Jackknife (rejected in gllvmTMB MSPL-interval D-148) |

gllvmTMB pins: `R/mspl-curvature-pin.R`; after-task `docs/dev-log/after-task/2026-08-15-mspl-se-feasibility-pin.md`.  
Brain **D-149**: internal SE pins for non-binomial cascades ≠ public calibrated intervals.

### 1.5 Existing drmTMB hooks that already help

Do **not** overload these as MSPL:

- `drm_phylo_penalty()` / `estimator = "MAP"` — PC prior on phylo SDs (`R/penalty.R`, Design 172). Different estimator.
- `drm_control(se = TRUE/FALSE)` — MSPL Phase-1 **requires** `se = FALSE`.
- Fit field `estimator` (`ML` / `REML` / `MAP`) — extend with `"MSPL"` only when live; never silently relabel MAP as MSPL.

### 1.6 Process transfers

- Fail-closed prepare fence (gllvmTMB `.gllvmTMB_mspl_prepare()` pattern).
- Symbolic alignment before TMB edits.
- Validation-debt / capability register row before any reader-facing claim.
- Totoro/DRAC for campaigns (**D-50**); never GitHub Actions artifacts.
- **D-139**: state a time estimate always; **>30 min** needs plan + pre-run + Shinichi approval.

---

## 2. What does NOT transfer

| gllvmTMB artefact | Why it does not transfer |
|---|---|
| Stacked-trait latent grid (`latent` / `indep` / `dep` × sources) | drmTMB is uni/bivariate distributional regression |
| Loading-row atoms \(V_\Lambda\), event-weighted Poisson \(V_\lambda^P\) | No \(\Lambda\) matrix; do not invent a fake loading penalty |
| Trait-balanced Gram \(S_{jj}\) / Hirose Gaussian FA route | Multivariate FA boundary, not drmTMB’s first cell |
| Poisson admit packet details that depend on multivariate loadings | Keep only the *discipline* (pin \(c\), pin atoms, oracles, no premature admit) |
| Spatial / phylo / kernel MSPL structure cells | Optional later; not Phase-1 |
| Design 88 binary GLLVM surface as a drop-in | Different model class; reuse Jeffreys + soft scale ideas only |
| Design 118 public-interval programme as copy-paste | Rebuild pre-registration for **drmTMB estimands** (μ, zi, hu, σ, RE SDs) |
| “Sister package therefore covered” | Sister evidence ≠ package evidence |

**Do not call MSPL “Firth”, “ordinary MAP”, or “bias reduction.”** Composite soft penalty ≠ PC phylo MAP ≠ Firth GLM alone.

---

## 3. Recommended drmTMB sequencing

### Phase 0 — Constitution (≤1 sitting, docs only)

1. This guide + a one-page GOAL in a named lane kit.
2. Register stub rows: `planned` only.
3. **G0 stop:** confirm Phase-1 family before any `src/` edit.

### Phase 1 — Point MSPL, `se = FALSE` (highest value)

**Recommended first cell (brain lane note):** logistic **`zi` / `hu`** submodels under zero-inflation / hurdle families — textbook separation where users do not look.

**Runner-up:** binomial / Bernoulli **`mu`** with fixed design (+ optional simple random intercept) — closest published MSPL theorem.

Sequence:

1. Detection smoke: `brglm2::detect_separation()` on each logistic submodel.
2. Jeffreys atom on that submodel’s free fixed effects + soft \(c_n\).
3. If RE present: Sterzinger–Kosmidis Huber-on-Cholesky atom (do not skip and claim “MSPL”).
4. Multi-seed local point smoke vs ML on **healthy** and **separated** DGPs (`se = FALSE`).
5. Admit packet → G0 for `planned` → `admitted` **experimental point only**.

### Phase 2 — Internal SE pins (D-149 spirit)

- Name \(Q_P\) (penalised objective Hessian) and \(Q_0\) (penalty-off at MSPL point).
- Pin availability + PD; retain non-PD unrepaired.
- Public `drm_control(se = TRUE)` / `vcov` / `confint` stay withheld for MSPL until a later gate.
- Cascade if multiple families admitted: logistic submodel first → Gaussian location → Poisson → NB — **pins only**.

### Phase 3 — Intervals (separate programme)

- Profile remains drmTMB’s featured CI method (**brain D-12**).
- Any MSPL interval route needs its own pre-registration (Design 118 pattern), hold-out gate, and register promotion.
- Jackknife: **rejected by default** unless Shinichi reopens (gllvmTMB MSPL-interval D-148).

### Explicitly defer

Bivariate `rho12` MSPL; phylo/spatial MSPL hybrids; AGHQ-MSPL; REML+MSPL hybrids; replacing phylo PC MAP; all-family admit; NEWS covered.

---

## 4. File / API sketch (sketch only — hooks exist)

### 4.1 Proposed surface (opt-in)

```r
# Experimental — not default, not covered
fit <- drmTMB(
  bf(y ~ x + (1 | g), zi ~ x),
  family = zi_poisson(),  # illustrative
  data = dat,
  estimator = "mspl",     # NEW; alternative: drm_control(estimator = "mspl")
  control = drm_control(se = FALSE),
  mspl = drm_mspl_control(...)  # optional: c_n, which submodels
)
```

**Fence rules:**

- Default estimator remains `ML` (or `REML` when requested).
- Reject `estimator = "mspl"` + `REML = TRUE`.
- Reject combining MSPL with `drm_phylo_penalty()` until a named hybrid is designed.
- Reject public SE methods on MSPL fits until Phase 2+ authorisation.

### 4.2 Suggested files

| Path | Role |
|---|---|
| `R/mspl-registry.R` | Cell table: family × submodel (`mu`/`zi`/`hu`/…) × RE structure × status × evidence |
| `R/mspl.R` | Prepare fence, provenance labels, soft-scale helpers |
| `R/mspl-curvature-pin.R` | Unexported \(Q_P\)/\(Q_0\) pins (Phase 2) |
| `R/control.R` | Optional `estimator` / `mspl` fields — pick one SSOT with top-level arg |
| `src/drmTMB.cpp` | MSPL penalty behind a DATA flag; ML bit-identical when off |
| `tests/testthat/test-mspl-*.R` | Fence rejects; oracle twins; `se=FALSE` smoke; pin tests |
| `docs/design/226-…` (later) | Symbolic alignment for the first admitted cell |
| `docs/design/34-validation-debt-register.md` | New rows; stay `blocked`/`partial` until evidence |

### 4.3 Honesty labels (copy drmTMB MAP discipline)

- Print/`summary`: `estimator: MSPL` + “experimental softly penalized; not Firth; not calibrated inference”.
- `logLik()`: unpenalized data Laplace likelihood (store penalty separately), matching Design 172 — document if a later G0 chooses otherwise.
- `check_drm()`: AIC/LRT across MSPL fits are not standard.

### 4.4 Do not implement yet

Full public `vcov`/`confint` for MSPL; bootstrap campaign; NEWS “covered”; tutorial article; Julia twin MSPL.

---

## 5. Hard fences (brain decisions)

| ID | Fence | drmTMB consequence |
|---|---|---|
| **D-50** | Sims/campaigns on Totoro/DRAC; never Actions artifacts | Local CI tests only in GA |
| **D-139** | Always estimate time; **>30 min** needs plan + pre-run + approval | No silent overnight MSPL grids |
| **D-142 / D-143** | Totoro hygiene; **150-core cap** binds | Leave Totoro clean; ask before exceeding |
| **MSPL-interval D-148** (gllvmTMB) | Public calibrated intervals binary-only; MSPL-04 blocked; jackknife rejected | Do not copy that public claim; re-pre-register if drmTMB opens intervals |
| **Bare-question D-148** | Every Shinichi question ships a paste-ready draft answer | Use at every G0 |
| **D-149** | Internal SE pins OK for non-binomial cascade; public intervals stay binary-only **in gllvmTMB** | Adapt: internal pins for logistic/`zi`/`hu` early; public MSPL intervals still need a drmTMB gate |
| **D-12** | Profile is featured CI where Wald is suspect | Prefer profile research for MSPL intervals later |
| **D-141** | Evidence-led validation; package-affecting action gated | No covered claim without register evidence |

Also: drmTMB CRAN `0.7.0` path is sequenced elsewhere (**D-86 / D-93 / D-117**). MSPL is an **experimental side lane**, not the 0.7 release path.

---

## 6. Agent execution checklist (first PR shape)

1. Read this guide + brain citations in §7 + gllvmTMB programme constitution §4–6.
2. Dedicated branch / worktree (**D-69**).
3. Registry stub + failing fence tests (TDD).
4. Prepare fence only (reject everything) → green rejects.
5. First logistic submodel Jeffreys + \(c_n\) behind DATA flag; ML bit-identical when off.
6. Local `se=FALSE` smoke (≤30 min). Stop for G0 before RE Huber atom if time-boxed.
7. Admit-packet draft; **do not** flip `admitted` without Shinichi.
8. Append check-log + after-task; **no NEWS**.

---

## 7. Citations

### Brain (shinichi-brain MCP)

- `memory/decisions` — **D-50**, **D-12**, **D-139**, **D-141**, **D-142**, **D-143**, MSPL-interval **D-148**, bare-question **D-148**, **D-149**
- `memory/agent-log` — 2026-08-15/16 MSPL / D-139 / D-149 entries
- `projects/deep-research/dr34-la-mspl-parallel-estimator-distilled`
- `memory/engineering-notebook` — FA MSPL bridge
- `memory/lane-notes/FOR-DRM-LANE-2026-08-08-separation-borrowable-from-the-literature`
- `projects/drm-tmb` — package dossier

### gllvmTMB

- `docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md`
- `docs/design/88-binary-mspl-estimator.md`
- `docs/design/117-separation-estimability-programme.md`
- `docs/design/118-mspl-interval-calibration-protocol.md`
- `R/mspl-registry.R`, `R/mspl.R`, `R/mspl-curvature-pin.R`
- `docs/dev-log/research/2026-08-15-mspl-poisson-admit-packet.md`
- `docs/dev-log/after-task/2026-08-15-mspl-se-feasibility-pin.md`

### drmTMB

- `R/penalty.R`, `docs/design/172-phylo-penalized-map.md`
- `R/control.R` — `drm_control(se = …)`
- `docs/design/12-profile-likelihood-cis.md`
- `docs/design/34-validation-debt-register.md`
- Preferred durable copy: `docs/design/225-mspl-implementation-guide.md`

### Primaries

- Sterzinger & Kosmidis (2023) — DOI 10.1007/s11222-023-10217-3  
- Sterzinger, Kosmidis & Moustaki (2026) — DOI 10.1017/psy.2026.10092  

---

## 8. G0 questions for Shinichi (with draft answers)

1. **Phase-1 cell?**  
   > your answer: [suggested: “zi/hu logistic first (brain lane note), then binomial mu” — or “binomial mu only first”]

2. **API shape?**  
   > your answer: [suggested: “top-level `estimator = \"mspl\"` mirroring gllvmTMB” — or “`drm_control(estimator = …)` only”]

3. **Start code this week, or park until gllvmTMB Poisson admit / SE pin series settles?**  
   > your answer: [suggested: “park code; keep this guide as the baton” — or “start Phase 0+1 fence on a side branch”]

4. **May drmTMB treat D-149-style internal SE pins as authorised for logistic/`zi`/`hu` without a new decision ID?**  
   > your answer: [suggested: “yes for internal pins only; public intervals still need a drmTMB pre-reg” — or “new D-xxx required”]
