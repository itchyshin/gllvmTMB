# Random-Slope Capability Truth Ledger

**Method:** Three independent sources extracted without paraphrase or interpolation:
1. **CODED** — `.augmented_slope_family_contract()` in `R/fit-multi.R` lines 453–481
2. **VALIDATED** — `docs/design/35-validation-debt-register.md` register rows for random slopes
3. **ADVERTISED** — `docs/dev-log/capability-surface.html` per-family table (lines 360–464) and Section 4 (lines 612–631)

---

## Table A: Per-Family Truth Matrix (IDs 0–15)

| ID | Family | CODED<br/>(contract presence, links, basis) | VALIDATED<br/>(register codes + statuses) | ADVERTISED<br/>(board cell + annotation) |
|----|--------|------|----------|----------|
| 0 | gaussian | Present: link_0=T, link_1=F, link_2=F; basis=`route_specific` | RE-02 `covered`; RE-03 `partial`; RE-12 `partial` | `partial s1·s2` (line 370) |
| 1 | binomial | Present: link_0=T, link_1=T, link_2=F; basis=`route_specific` | RE-02 `covered`; PHY-11 `partial`; RE-03 `partial`; RE-12 `partial` | `partial` (line 377) |
| 2 | poisson | Present: link_0=T, link_1=F, link_2=F; basis=`route_specific` | RE-02 `covered`; PHY-12 `covered`; RE-03 `partial`; RE-12 `partial` | `partial` (line 384) |
| 3 | lognormal | Present: link_0=T, link_1=F, link_2=F; basis=`c1_partial` | RE-14 `partial`; FAM-11 `partial`; PHY-17 `partial`; SPA-09 `partial`; SPA-10 `partial` | `—` (line 433) |
| 4 | Gamma | Present: link_0=T, link_1=F, link_2=F; basis=`route_specific` | RE-02 `covered`; PHY-14 `covered`; RE-03 `partial`; RE-12 `partial` | `—` (line 412) |
| 5 | nbinom2 | Present: link_0=T, link_1=F, link_2=F; basis=`route_specific` | RE-02 `covered`; PHY-13 `covered`; RE-03 `partial`; RE-12 `partial` | `partial` (line 384) |
| 6 | (none) | **ABSENT** from contract | — | — |
| 7 | Beta | Present: link_0=T, link_1=F, link_2=F; basis=`route_specific` | RE-02 `covered`; PHY-15 `covered`; RE-03 `partial`; RE-12 `partial` | `—` (line 405) |
| 8 | betabinomial | Present: link_0=T, link_1=F, link_2=F; basis=`c1_partial` | RE-14 `partial`; FAM-05 `partial`; SPA-10 `partial` (via RE-14) | `partial C1 phylo_indep large-N` (line 398) |
| 9 | student | Present: link_0=T, link_1=F, link_2=F; basis=`c1_partial` | RE-14 `partial`; FAM-12 `partial`; PHY-17 `partial`; SPA-09 `partial`; SPA-10 `partial` | `—` (line 426) |
| 10 | (none) | **ABSENT** from contract | — | — |
| 11 | (none) | **ABSENT** from contract | — | — |
| 12 | (none) | **ABSENT** from contract | — | — |
| 13 | (none) | **ABSENT** from contract | — | — |
| 14 | ordinal_probit | Present: link_0=T, link_1=F, link_2=F; basis=`route_specific` | RE-02 `covered`; PHY-16 `partial`; RE-03 `partial`; RE-12 `partial` | `— ordinal RE not implemented` (line 447) |
| 15 | nbinom1 | Present: link_0=T, link_1=F, link_2=F; basis=`route_specific` | RE-02 `covered`; PHY-18 `covered`; RE-03 `partial`; RE-12 `partial` | `partial` (line 384) |

---

## Table B: Section 4 Rows (Random slopes & special capabilities)

Verbatim from `docs/dev-log/capability-surface.html` lines 612–631:

| Capability | Detail | Status |
|-----------|--------|--------|
| Data input | Long `value ~ 0 + trait + …` and wide `traits(…) ~ …`, one engine, byte-identical fits | `taught` |
| Keyworded random slope | Gaussian reaction norm `latent(1 + x \| unit, d = K)`; structured `*_indep/dep/latent(1 + x \| g)`, s = 1, across phylo / animal / kernel / spatial | `tested` |
| Uncorrelated slope `(1 + x \|\| g)` | `indep\|\|` per-trait diagonal · `dep\|\|` = Σ_int⊕Σ_slope (parity pin) · `latent\|\|` separate-Λ — phylo / animal / kernel / spatial | `tested` |
| Gaussian structured s = 2 | `phylo_dep(1 + x1 + x2 \| species)` | `point-only` |
| Plain bare-bar slope `(1 + x \| g)` | reserved — use the keyworded decomposition | `reserved` |
| Missing responses | `NA` cells as unobserved; `predict_missing()` | `taught` |
| Missing predictor | one `mi()` term: Gaussian, grouped, phylo, binary, ordered, unordered fixed routes | `point-only` |
| Latent scores on covariates | `latent(…, lv = ~ x)` — ordinary Gaussian & binomial unit-tier | `partial` |
| Known sampling covariance | `meta_V(V = V)` — function live, no worked guide yet | `no guide` |
| REML | narrow Gaussian-only `REML = TRUE` pilot | `pilot` |
| Julia bridge | narrow point route for select families; experimental, not required | `experimental` |

---

## MISMATCHES

Rows where the three columns (CODED, VALIDATED, ADVERTISED) disagree:

1. **ID 0, gaussian:**
   - CODED: `route_specific`
   - VALIDATED: RE-02 `covered`; others `partial`
   - ADVERTISED: `partial s1·s2`
   - **Disagreement:** CODED claims route_specific, VALIDATED has mixed `covered`/`partial`, ADVERTISED reports `partial`

2. **ID 2, poisson:**
   - CODED: `route_specific`
   - VALIDATED: RE-02 `covered`, PHY-12 `covered`; others `partial`
   - ADVERTISED: `partial`
   - **Disagreement:** CODED `route_specific` + VALIDATED includes `covered`, but ADVERTISED reports only `partial`

3. **ID 3, lognormal:**
   - CODED: `c1_partial`
   - VALIDATED: RE-14 `partial`; FAM-11 `partial`; PHY-17 `partial`; SPA-09 `partial`; SPA-10 `partial`
   - ADVERTISED: `—` (none)
   - **Disagreement:** CODED admits (`c1_partial`), VALIDATED admits (multiple `partial`), but ADVERTISED advertises nothing

4. **ID 4, Gamma:**
   - CODED: `route_specific`
   - VALIDATED: RE-02 `covered`, PHY-14 `covered`
   - ADVERTISED: `—` (none)
   - **Disagreement:** CODED `route_specific` + VALIDATED `covered`, but ADVERTISED advertises nothing

5. **ID 5, nbinom2:**
   - CODED: `route_specific`
   - VALIDATED: RE-02 `covered`, PHY-13 `covered`
   - ADVERTISED: `partial`
   - **Disagreement:** CODED `route_specific` + VALIDATED `covered`, but ADVERTISED reports only `partial`

6. **ID 7, Beta:**
   - CODED: `route_specific`
   - VALIDATED: RE-02 `covered`, PHY-15 `covered`
   - ADVERTISED: `—` (none)
   - **Disagreement:** CODED `route_specific` + VALIDATED `covered`, but ADVERTISED advertises nothing

7. **ID 9, student:**
   - CODED: `c1_partial`
   - VALIDATED: RE-14 `partial`; FAM-12 `partial`; PHY-17 `partial`; SPA-09 `partial`; SPA-10 `partial`
   - ADVERTISED: `—` (none)
   - **Disagreement:** CODED admits (`c1_partial`), VALIDATED admits (multiple `partial`), but ADVERTISED advertises nothing

8. **ID 14, ordinal_probit:**
   - CODED: `route_specific`
   - VALIDATED: RE-02 `covered`, PHY-16 `partial`; others `partial`
   - ADVERTISED: `— ordinal RE not implemented`
   - **Disagreement:** CODED `route_specific` + VALIDATED `covered` for RE-02, but ADVERTISED advertises nothing with annotation that feature is not implemented

9. **ID 15, nbinom1:**
   - CODED: `route_specific`
   - VALIDATED: RE-02 `covered`, PHY-18 `covered`
   - ADVERTISED: `partial`
   - **Disagreement:** CODED `route_specific` + VALIDATED `covered`, but ADVERTISED reports only `partial`

---

## Exact Line Numbers for ADVERTISED Cells

Board per-family table (column: "Rand. slope"), family name lines → cell lines:

- gaussian (line 367) → cell line 370
- poisson (line 374) → cell line 377
- nbinom1 · nbinom2 (line 381) → cell line 384
- binomial (line 388) → cell line 391
- betabinomial (line 395) → cell line 398
- beta (line 402) → cell line 405
- Gamma (line 409) → cell line 412
- tweedie (line 416) → cell line 419
- student (line 423) → cell line 426
- lognormal (line 430) → cell line 433
- truncated_poisson · truncated_nbinom2 (line 437) → cell line 440
- ordinal_probit (line 444) → cell line 447
- multinomial (line 451) → cell line 454
- delta_* · hurdle (line 458) → cell line 461

Section 4 table: lines 612–631
