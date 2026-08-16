# Gamma / lognormal LA-MSPL door: oracles → door gap list

**Date:** 2026-08-16
**Track:** SE-arc speed-up track 4 (lift `#1000` skip_if)
**Workspace:** `/private/tmp/gllvmtmb-mspl-gamma-lnorm-door-gap`
**Ground truth:** `origin/main` @ `55666f1e` (`#1041`)
**Status:** DRAFT note only. No prepare widen. No `src/` tape. No
admit. No NEWS `covered`. No public `se=TRUE`.

**Reader:** the next MSPL conductor who wants to know whether
Gamma(log) / lognormal(log) may get a `#1007`-shaped planned door
tonight so `#1000` can drop its `skip_if`.

---

## Recommendation

**Do not implement the door or the tape tonight.** Open this draft
and leave `#1000` skipping.

`#1003` already put `planned` / `phase4_prep` rows on `main`. That
is not a door. The Phase-4-style oracles pin the *mean-model
weights* and then FAIL every later object a live `estimator =
"mspl"` fit would need: soft rate \(c\), loading atom,
Laplace-marginal \(I(\beta)\), and (for lognormal) shared
\(\sigma_\varepsilon\) composition. A `#1007` mirror would write
those OPEN objects as the live nbinom defaults — unpinned \(c=1\)
and Bernoulli \(V_{\mathrm{loading}}\) — which both prep notes
list as kill-list transplants.

`#1007` could open a planned door because C++ GLM-outer weights
for `family_id` 5 and 15 already existed. Gamma is `family_id` 4
and lognormal is `family_id` 3. `gll_mspl_log_weight_glm()` still
errors on both.

---

## What `#1000` skip_if is waiting for

`tests/testthat/test-zz-mspl-rest-families-se-feasibility.R` tries
a live `gllvmTMB(..., estimator = "mspl", se = TRUE)` fit for
Gamma and lognormal, then `skip_if` the call errors. On
`origin/main` that error is `gllvmTMB_mspl_unsupported` from
`.gllvmTMB_mspl_prepare()`:

```r
fam_ids %in% c(0L, 1L, 2L, 5L, 15L)
```

(`R/mspl.R`, public door). The same file also `skip_if`s the
internal curvature pin when the family is still outside

```r
binomial+logit / poisson+log / gaussian+identity /
nbinom1+log / nbinom2+log / tweedie+log / Beta+logit
```

(`R/mspl-curvature-pin.R`). Lifting the Gamma / lognormal
`skip_if` therefore needs all three of:

1. a public prepare door for `family_id` 3 and 4;
2. a C++ GLM-outer weight that does not `error()` on those fids;
3. the curvature-pin fence widened so a formed fit can name
   \(Q_P\) and \(Q_0\).

Public `se=TRUE` must still withhold `sdreport()` / `vcov()` /
`confint()`. That withhold is already in `R/fit-multi.R` and is
**not** a gap.

---

## What `#1003` already landed

| Layer | Gamma (`family_id` 4) | lognormal (`family_id` 3) |
|---|---|---|
| Registry | `gamma:log:ordinary:q1,q2` = `planned` / `phase4_prep` | `lognormal:log:ordinary:q1,q2` = `planned` / `phase4_prep` |
| Weight on paper | \(W=\phi_\gamma\), mean-inert | \(W=1/\sigma_\varepsilon^2\) on \(\log y\), mean-inert |
| Prepare fence | rejected | rejected |
| C++ GLM-outer weight | absent (`unknown family_id`) | absent (`unknown family_id`) |
| Soft rate | **OPEN** | **OPEN** |
| Loading atom | **OPEN** | **OPEN** |
| Live MSPL / SE pin | `#1000` SKIP | `#1000` SKIP |

Notes in `R/mspl-registry.R` still say “No prepare widen. No C++
tape.” The oracle files still assert that prepare is not widened
to 3 or 4 and that those files never call live MSPL (Gamma E10;
lognormal E10). A door PR would have to retarget those pins the
way `#1028` retargeted nbinom2 after `#1007`.

---

## Why `#1007` is not a licence

`#1007` opened a planned nbinom door and widened the curvature
pin. It did **not** add `src/`. The after-task says so:
`docs/dev-log/after-task/2026-08-16-mspl-nbinom-planned-door.md`.

A Gamma / lognormal `#1007` mirror is a different change class:

- **Weight tape does not exist.** nbinom1 / nbinom2 weights were
  already in `gll_mspl_log_weight_glm()`. Gamma and lognormal
  fall through to `error("... unknown family_id")`.
- **Default rate is unpinned \(c=1\).** The live tape sets
  Bernoulli \(c_n\), Poisson \(c_P\), and otherwise
  `mspl_c_n = 1` (`src/gllvmTMB.cpp`). Both prep notes reject
  Bernoulli \(c_n\), Gaussian \(c_N=\sqrt{2/N}\), and Poisson
  \(c_P\) as transplants, and they do not pin a replacement.
- **Default loading atom is Bernoulli radial.** Non-Poisson
  GLM-outer families call `gll_mspl_row_radial_penalty`. Gamma
  oracle E8 and lognormal oracle E9 prove that atom is
  \((\mu,\phi)\)-inert and \((\eta,\sigma)\)-inert. Copying it
  is the same class of transplant the nbinom admit-next note
  later named on the *current* nbinom door
  (`docs/dev-log/research/2026-08-16-mspl-nbinom-admit-next.md`).
- **Oracle kill lists forbid the door itself** until a Shinichi
  gate: Gamma kill 11–13 and lognormal kill 11–14 name C++ tape,
  live `estimator = "mspl"`, and quietly widening prepare to
  `family_id` 3 or 4.

nbinom later needed a separate admit packet (`#1042`: packet
first, not tonight). Gamma / lognormal do not even have the
weight tape that packet would audit.

---

## Oracles → door gap list

Pinned formulas from
`docs/dev-log/research/2026-08-15-mspl-phase4-gamma-prep.md` and
`docs/dev-log/research/2026-08-15-mspl-phase4-lognormal-prep.md`.
“READY” means the oracle identity is testable in pure R. It does
**not** mean a tape may ship.

| ID | Object | Oracle state | What a `#1007` mirror would do tonight | Block |
|---|---|---|---|---|
| G-W | Gamma \(W=\phi_\gamma\); \(\log w=\log\phi_\gamma\) | READY (E1–E3, E5). Mean-inert. Not Poisson \(W=\mu\). Not Tweedie \(p\to 2\). | Add `family_id == 4` in `gll_mspl_log_weight_glm()` and pass `log_phi_gamma(t)` at the call site (today only 5 / 15 / 7 / 6 set `log_phi`). | Weight formula is ready. Wiring is new `src/`. |
| L-W | Lognormal \(W=1/\sigma_\varepsilon^2\); \(\log w=-2\log\sigma_\varepsilon\) | READY (E1–E5). Identity on \(\log y\). Jacobian \(-\log y\) is parameter-free. \(\mathrm{E}[Y]=\mathrm{e}^{\eta+\sigma^2/2}\). | Add `family_id == 3`. There is no per-trait `log_phi_*` for this family; the live residual is shared `log_sigma_eps`. | Weight formula is ready. Shared-\(\sigma\) plumbing is not a Gaussian Phase-3 transfer (L-E7). |
| G-c / L-c | Soft rate \(c\) | **OPEN.** Kill: \(c_n\), \(c_N\), \(c_P\). | Inherit `mspl_c_n = 1`. | Speculative. Same default nbinom used; nbinom admit-next still refuses to treat that as science. |
| G-λ / L-λ | Loading atom | **OPEN.** Kill: Bernoulli \(V_{\mathrm{loading}}\), Hirose \(\Psi\). | Inherit `gll_mspl_row_radial_penalty`. | Speculative and already proven inert (Gamma E8, lognormal E9). |
| G-φ / L-σ | Shape / residual atom | **OPEN.** \(\tfrac12\log I_{\phi\phi}\) *rewards* \(\phi_\gamma\to 0\); \(\beta\)-atom *rewards* \(\sigma_\varepsilon\to 0\). | None. Live tape has no Gamma-shape or lognormal-residual atom. | Not required to form a fit. Required before anyone calls the atom a boundary repair. |
| L-mix | Shared `log_sigma_eps` with Gaussian | **OPEN.** | Single-family door would hide it. | Mixed 0+3 is Phase-6; do not “solve” it by opening only lognormal. |
| I-LA | Laplace-marginal \(I(\beta)\) | **OPEN.** Atom is fixed-only / conditional at \(\eta=X_{\mathrm{fix}}b_{\mathrm{fix}}+\mathrm{offset}\). | Same convention as the live GLM-outer tape. | Honest as a planned-tape label. Not a theorem. |
| Door | `.gllvmTMB_mspl_prepare()` | Oracle E10 / kill 13: must stay `{0,1,2,5,15}`. | Add 3 and 4; retarget Gamma / lognormal E10 and `#1026` rest-family fence. | Shinichi gate. Oracle files would FAIL until retargeted. |
| Pin | Curvature family fence | Gamma / lognormal → `gllvmTMB_mspl_curvature_family`. | Add `Gamma+log` and `lognormal+log` the way `#1007` added nbinom. | Only after a real fit exists. |
| Live | `estimator = "mspl"` in tests | Kill 12: oracle files must not call it. | New fenced-tape tests, `#1000` un-skip. | Operational reachability, not Phase-4 exit. |
| Admit | Registry / NEWS / `se=TRUE` | FAIL on both notes. | Must stay `planned` / withheld / no NEWS covered. | Not a gap. A fence. |

Preferred later-admission *candidates* (still not a tape):

- Gamma: \(\tfrac12\log\det(\phi_\gamma X_*^\top X_*)\).
- Lognormal: \(\tfrac12\log\det(\sigma_\varepsilon^{-2} X_*^\top X_*)\)
  on \(\log y\).

Rate, loading, shape/residual, and Laplace-marginal \(I(\beta)\)
stay OPEN on both notes.

---

## What would have to change if a later gate says “door”

A later planned-only door, after Shinichi G0 on the OPEN atoms
(or an explicit “inherit \(c=1\) + no loading atom” decision),
would touch at least:

- `src/gllvmTMB.cpp` — `gll_mspl_log_weight_glm()` plus the
  `log_phi` / `log_sigma_eps` call site;
- `R/mspl.R` — `fam_ids` and the log-link / positivity branches;
- `R/mspl-curvature-pin.R` — family fence;
- `R/mspl-registry.R` — drop “No prepare widen. No C++ tape”;
- `tests/testthat/test-mspl-gamma-phase4-oracles.R` and
  `test-mspl-lognormal-phase4-oracles.R` — E10 / prepare pins
  (`#1028` pattern);
- `tests/testthat/test-zz-mspl-rest-family-prepare-fence.R` —
  Gamma / lognormal leave the “still rejected” set;
- new fenced-tape tests (nbinom `test-mspl-nb1-fenced-tape.R` /
  `test-mspl-nb2-fenced-tape.R` shape);
- `#1000` then stops skipping Gamma / lognormal live pins.

Do **not** start that list from “copy nbinom and set \(c=1\).”

---

## Non-claims

This note does not implement a tape, open a door, admit a cell,
calibrate an interval, or lift `#1000`. It does not claim that
mean-inert \(W\) is enough for a healthy GLLVM fit, that
lognormal is Gaussian Phase-3 MSPL, that Gamma is Tweedie at
\(p=2\), or that nbinom’s unpinned \(c=1\) is a reusable rate.

Sibling warning, not a Gamma/lognormal measurement: `#1047`
(Tweedie working \(W_*\)) is still DRAFT / hang BLOCKED. That is
a different family and a different atom. It is a reminder that
“the weight formula is ready” is not “the live cell returns.”

---

## HARD STOP

planned → admitted · NEWS covered · public `se=TRUE` · prepare
widen to 3 or 4 · `src/` GLM-outer tape · `#1000` un-skip ·
Codex Lane B absorb · merge this draft as a door
