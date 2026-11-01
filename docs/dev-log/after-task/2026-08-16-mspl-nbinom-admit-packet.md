# After Task: nbinom1/nbinom2 LA-MSPL admit packet (planned, not admitted)

**Branch**: `cursor/mspl-nbinom-admit-packet`
**Date**: `2026-08-16`
**Roles (engaged)**: Ada (keep planned; G0 at 5am), Curie (oracles),
Gauss/Noether (atoms), Rose (fence)

## 1. Goal

Land the missing nbinom admit *science* — family-specific rates,
information-weighted loading atoms, a written NB2 Jeffreys-on-φ
keep-or-drop, and TMB/pure-R A7 twins — without flipping
`planned` → `admitted` and without public SE.

## 2. Implemented

- **NB2 rate**
  \(c_{\mathrm{NB2}}=2\sqrt{p_{\mathrm{free}}/\max(I_{\mathrm{NB2}},1)}\)
  with data-plugin \(I_{\mathrm{NB2}}=\sum_t n_t\bar w_t\),
  \(\bar w_t=\bar y_t\hat\varphi_t/(\hat\varphi_t+\bar y_t)\).
- **NB1 rate**
  \(c_{\mathrm{NB1}}=2\sqrt{p_{\mathrm{free}}/\max(I_{\mathrm{NB1}},1)}\)
  with data-plugin exact \(I_\eta(\bar y_t,\hat\varphi_t)\), not
  quasi \(\mu/(1+\varphi)\), not \(\sum y\).
- Information-weighted loading atoms (not Bernoulli radial, not
  Poisson \(\bar y\)).
- **NB2 Jeffreys-on-φ DROP** (Jacobian pin kept; quasi stand-in
  refused; atom not taped).
- Live A7 twins. Registry stays `planned` / `phase4_prep`.
- Optional `dev/mspl-nbinom-multiseed-point-smoke.R` (`se=FALSE`).

## 3. Files Changed

- `R/mspl-nbinom2-atoms.R` (new internals)
- `R/mspl-nbinom1-atoms.R` (new internals)
- `R/mspl.R` (nbinom rates + scope strings)
- `src/gllvmTMB.cpp` (nbinom `c` + weighted loading; Poisson
  \(c_P\) / \(V_\lambda^P\) untouched)
- `tests/testthat/test-mspl-nbinom2-admit-packet.R`
- `tests/testthat/test-mspl-nbinom1-admit-packet.R`
- `dev/mspl-nbinom-multiseed-point-smoke.R`
- `docs/dev-log/research/2026-08-16-mspl-nbinom-admit-packet.md`
- this after-task + `docs/dev-log/check-log.md`

No `R/mspl-registry.R` edit. No NEWS. No README. No repo-root
`LOOP/`. No Dropbox checkout.

## 3a. Decisions and Rejected Alternatives

- **Decision:** data-plugin information size as the rate denominator.
  **Rationale:** Poisson A3 requires \(c\) not to move with offset at
  fixed \(y\); live \(\mathrm{tr}(W(\mu,\varphi))\) would. Family
  MoM \(\hat\varphi\) plus \(\bar y\) is the information-size proxy
  that still rejects \(c_P\).
  **Rejected:** keep \(c=1\); copy \(c_P\); live \(\mu\)-dependent \(c\).
  **Confidence:** medium (AGENT-INFERRED vanishing scale).
- **Decision:** weight the radial term by family \(\bar w\) / \(\bar I\).
  **Rationale:** scout's obvious candidate; coercive at positive
  information; inert on all-zero traits.
  **Rejected:** Bernoulli radial; Poisson \(\bar y\); Hirose \(1/\psi\).
  **Confidence:** medium.
- **Decision:** DROP NB2 Jeffreys-on-φ.
  **Rationale:** Jacobian kill if taped on `log_phi` as
  \(\tfrac12\log I_{\varphi\varphi}\); quasi stand-in is wrong; exact
  \(I_{\varphi\varphi}\) is a PMF sum; the atom fights one φ boundary
  and rewards the other; mean atom already couples to φ.
  **Rejected:** tape \(\tfrac12\log I_{\varphi\varphi}\) tonight.
  **Confidence:** high for "not tonight"; medium for "never".

## 4. Checks Run

```
export OMP_NUM_THREADS=1 NOT_CRAN=true
pkgload::load_all(".", compile = TRUE)
testthat::test_file("tests/testthat/test-mspl-nbinom2-admit-packet.R")  # PASS 51
testthat::test_file("tests/testthat/test-mspl-nbinom1-admit-packet.R")  # PASS 41
testthat::test_file("tests/testthat/test-mspl-nb1-fenced-tape.R")       # PASS 17
testthat::test_file("tests/testthat/test-mspl-nb2-fenced-tape.R")       # PASS 18
testthat::test_file("tests/testthat/test-mspl-registry.R")              # PASS 81
testthat::test_file("tests/testthat/test-mspl-nbinom1-phase4-oracles.R")# PASS 76
testthat::test_file("tests/testthat/test-mspl-nbinom2-phase4-oracles.R")# PASS 68
testthat::test_file("tests/testthat/test-mspl-poisson-admit-packet.R")  # PASS 45
testthat::test_file("tests/testthat/test-mspl-poisson-public-door.R")   # PASS 7
```

`devtools::document()` not required (no roxygen change). Optional
smoke script not run tonight (local `se=FALSE` driver only).

## 5. Tests of the Tests

- A1 fails if \(c=1\) or \(c_P\) is copied.
- A4/A5 fail if Bernoulli radial or Poisson \(\bar y\) is reused.
- A7 fails if the live tape still reports \(c=1\) or Bernoulli \(V\).
- A8 fails if a registry row flips to `admitted`.
- D-phi fails if a `fid==5` dispersion Jeffreys is taped.

## 6. Consistency Audit

```
rg 'status\s*=\s*"admitted"' R/mspl-registry.R
# nbinom blocks stay planned
rg 'unpinned c=1' R/mspl.R
# nbinom scope strings updated; tweedie/beta still unpinned
rg 'NB2 Jeffreys-on-phi DROPPED' src/gllvmTMB.cpp
```

## 7. Roadmap Tick

N/A. No ROADMAP row moved. MSPL-01..05 stay Bernoulli-shaped.

## 7a. GitHub Issue Ledger

No relevant open issue for an nbinom admit flip; #1042 already
said packet first. No new issue created.

## 8. What Did Not Go Smoothly

NB1 exact \(I_\eta\) on the data plugin uses the taped truncation
(`ymax` from `mu+12*sd`), not the Phase-4 qnbinom-tail oracle, so
A7 can twin the live tape. Those two \(I_\eta\) numbers are not
interchangeable across files.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Ada.** Keep planned. G0 is a later flip, family by family, after
reading the packet. Poisson G0 does not transfer.

**Curie.** A7 is the missing live twin. Phase-4 E/N files still
refuse a live MSPL call; that remains correct for those files.

**Gauss / Noether.** Rate and loading are data-plugin atoms, not
\(I_{\mathrm{LA}}(\beta)\). NB1 ≠ NB2. Quasi \(W=\mu/(1+\varphi)\)
stays diagnostic-only.

**Rose.** `planned` ≠ `admitted`. No NEWS `covered`. No public
`vcov()` / `confint()`.

## 10. Known Limitations And Next Actions

- Healthy / sparse multi-seed no-harm and boundary DGPs are OPEN.
- Laplace-marginal loading coercivity is OPEN.
- 🔴 **G0 ask (Shinichi, 5am):** do not flip from this packet
  alone unless you want the Poisson experimental-point bar; if so,
  name which family; confirm φ DROP; keep public SE withheld.
  Full ask:
  `docs/dev-log/research/2026-08-16-mspl-nbinom-admit-packet.md`.
