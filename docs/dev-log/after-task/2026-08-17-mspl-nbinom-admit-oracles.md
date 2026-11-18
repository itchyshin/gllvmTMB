# After-task: nbinom1/nbinom2 LA-MSPL Pure-R admit-packet oracles

**Branch**: `cursor/mspl-nbinom-admit-oracles`
**Date**: `2026-08-17`
**Roles (engaged)**: Ada / Noether / Curie / Rose

## 1. Goal

Continue the #1042 packet-first note as Pure-R science: pin family
\(c\), the information-weighted loading atom, and the NB2
Jeffreys-on-\(\varphi\) keep/drop. Keep the registry `planned`. Do
not admit. Do not retape. Do not merge the conflicting #1065 C++ /
live-A7 slice.

## 2. Implemented

Oracle-only pins, AGENT-INFERRED, not a theorem transfer:

- \(c_{\mathrm{NB2}}=2\sqrt{p_{\mathrm{free}}/\max(I_{\mathrm{NB2}},1)}\)
  with data-plugin \(I_{\mathrm{NB2}}=\sum_t n_t\bar w_t\),
  \(\bar w_t=\bar y_t\hat\varphi_t/(\hat\varphi_t+\bar y_t)\).
- \(c_{\mathrm{NB1}}=2\sqrt{p_{\mathrm{free}}/\max(I_{\mathrm{NB1}},1)}\)
  with data-plugin exact \(I_\eta(\bar y_t,\hat\varphi_t)\), not
  quasi \(\mu/(1+\varphi)\), not \(\sum y\).
- Loading atoms
  \(\sum_t(\sqrt{1+\|\lambda_t\|^2\bar w_t}-1)\) (NB2) and
  \(\sum_t(\sqrt{1+\|\lambda_t\|^2\bar I_t}-1)\) (NB1).
- **NB2 Jeffreys-on-\(\varphi\) DROP** (Jacobian pin kept; quasi
  stand-in refused; atom not taped).

A1–A6 / D-phi / A8 are Pure-R. No live A7 twin. Live door still
reports unpinned \(c=1\) and Bernoulli \(V_{\mathrm{loading}}\).

## 3. Files Changed

- `R/mspl-nbinom2-atoms.R` (new internals)
- `R/mspl-nbinom1-atoms.R` (new internals)
- `tests/testthat/test-mspl-nbinom2-admit-packet.R`
- `tests/testthat/test-mspl-nbinom1-admit-packet.R`
- `docs/dev-log/research/2026-08-17-mspl-nbinom-admit-oracles.md`
- this after-task + `docs/dev-log/check-log.md`

Not touched: `src/`, `R/mspl.R`, `R/mspl-registry.R`, NEWS, README,
ROADMAP, repo-root `LOOP/`, Dropbox checkout.

## 3a. Decisions and Rejected Alternatives

- **Decision:** data-plugin information size as the rate denominator.
  **Rationale:** Poisson A3 requires \(c\) not to move with offset at
  fixed \(y\); live \(\mathrm{tr}(W(\mu,\varphi))\) would. Family
  MoM \(\hat\varphi\) plus \(\bar y\) is the information-size proxy
  that still rejects \(c_P\).
  **Rejected:** keep \(c=1\); copy \(c_P\); live \(\mu\)-dependent \(c\).
  **Confidence:** medium (AGENT-INFERRED vanishing scale).
- **Decision:** weight the radial term by family \(\bar w\) / \(\bar I\).
  **Rationale:** #1042's obvious candidate; coercive at positive
  information; inert on all-zero traits.
  **Rejected:** Bernoulli radial; Poisson \(\bar y\); Hirose \(1/\psi\).
  **Confidence:** medium.
- **Decision:** DROP NB2 Jeffreys-on-\(\varphi\).
  **Rationale:** Jacobian kill if taped on `log_phi` as
  \(\tfrac12\log I_{\varphi\varphi}\); quasi stand-in is wrong; exact
  \(I_{\varphi\varphi}\) is a PMF sum; the atom fights one \(\varphi\)
  boundary and rewards the other; mean atom already couples to
  \(\varphi\).
  **Rejected:** tape \(\tfrac12\log I_{\varphi\varphi}\) tonight.
  **Confidence:** high for "not tonight"; medium for "never".
- **Decision:** Pure-R oracles only; no C++ / A7 in this PR.
  **Rationale:** #1065 already tried the full packet and CI failed
  on the NB1 penalty-off check and a tarball `src/` read. #1042
  asked for the science first.
  **Rejected:** fix-forward #1065 in the same sitting.
  **Confidence:** high.

## 4. Checks Run

See `docs/dev-log/check-log.md` (2026-08-17 nbinom admit-packet
Pure-R oracles). Targeted `testthat::test_file`:

- `test-mspl-nbinom2-admit-packet.R` PASS 39
- `test-mspl-nbinom1-admit-packet.R` PASS 33
- `test-mspl-nbinom1-phase4-oracles.R` PASS 76
- `test-mspl-nbinom2-phase4-oracles.R` PASS 68
- `test-mspl-registry.R` PASS 81
- `test-mspl-nb1-fenced-tape.R` PASS 17
- `test-mspl-nb2-fenced-tape.R` PASS 18

`git diff --stat -- src/ R/mspl.R R/mspl-registry.R NEWS.md` empty.
`devtools::document()` not required (no roxygen change).

## 5. Tests of the Tests

- A1 fails if \(c=1\) or \(c_P\) / \(c_n\) / \(c_N\) is copied.
- A4/A5 fail if Bernoulli radial or Poisson \(\bar y\) is reused.
- D-phi fails if \(I_{\log\varphi}\neq\varphi^2 I_{\varphi\varphi}\)
  or if the quasi stand-in is treated as \(I_{\varphi\varphi}\).
- A8 fails if a registry row flips to `admitted`.
- The NB1 \(\neq\) NB2 test fails if the two families share a rate
  or loading weight on the same overdispersed \(y\).

## 6. Consistency Audit

```
rg -n 'status\s*=\s*"admitted"' R/mspl-registry.R
# nbinom blocks stay planned
rg -n 'unpinned c=1' R/mspl.R
# nbinom scope strings still unpinned (tape unchanged)
rg -n 'NEWS covered|admitted' docs/dev-log/research/2026-08-17-mspl-nbinom-admit-oracles.md
# those tokens appear only as negations
```

## 7. Roadmap Tick

N/A. No ROADMAP row moved. MSPL-01..05 stay Bernoulli-shaped.

## 7a. GitHub Issue Ledger

No relevant open issue for an nbinom admit flip. #1042 already
said packet first and is merged. #1065 remains the C++ / A7
follow-on and should not merge against this pin. No new issue
created.

## 8. What Did Not Go Smoothly

#1065 already wrote the same atoms plus a live tape. This sitting
kept the science and dropped the two CI-failing surfaces (live NB1
A7; `src/` read under R CMD check). Two correct full packets in
one week would have been worse than a Pure-R pin that can merge.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Ada.** Keep planned. Green oracles are not an admit. Poisson G0
does not transfer. #1065 is not this PR.

**Curie.** A7 is still the missing live twin. Phase-4 E/N files
still refuse a live MSPL call; that remains correct for those
files. Do not read `src/` from an installed tarball.

**Noether.** Rate and loading are data-plugin atoms, not
\(I_{\mathrm{LA}}(\beta)\). NB1 \(\neq\) NB2. Quasi
\(W=\mu/(1+\varphi)\) stays diagnostic-only.

**Rose.** `planned` \(\neq\) `admitted`. No NEWS `covered`. No
public `vcov()` / `confint()`.

## 10. Known Limitations And Next Actions

- Live tape still reports \(c=1\) and Bernoulli
  \(V_{\mathrm{loading}}\). A later sitting must match these R
  twins without the #1065 CI holes.
- Healthy / sparse multi-seed no-harm and boundary DGPs are OPEN.
- Laplace-marginal loading coercivity is OPEN.
- Shinichi G0 for a registry flip is not requested from this PR.
