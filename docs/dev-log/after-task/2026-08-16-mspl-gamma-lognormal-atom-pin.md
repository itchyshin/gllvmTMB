# After-task: Gamma / lognormal MSPL rate and loading oracles

**Branch**: `cursor/mspl-gamma-lognormal-atoms`
**Date**: `2026-08-16`
**Roles (engaged)**: Ada / Noether / Curie / Rose

## 1. Goal

Close the two OPEN objects named in
`docs/dev-log/research/2026-08-16-mspl-gamma-lognormal-door-gap.md`
(#1051): soft rate \(c\) and the loading atom for Gamma(log) and
lognormal(log). Prefer pure-R Phase-4 oracles. Do not open the
prepare door or a C++ tape. Do not admit.

## 2. Implemented

Oracle-only pins, AGENT-INFERRED, not a theorem transfer:

- \(c_\Gamma=2\sqrt{p_{\mathrm{free}}/\max(n\phi_\gamma,1)}\)
- \(c_L=2\sqrt{p_{\mathrm{free}}/\max(n/\sigma_\varepsilon^2,1)}\)
- \(V_\lambda^\Gamma=\sum_t(\sqrt{1+\|\lambda_t\|^2\phi_t}-1)\)
- \(V_\lambda^L=\sum_t(\sqrt{1+\|\lambda_t\|^2/\sigma_\varepsilon^2}-1)\)

E11–E16 in the existing Phase-4 oracle files reject \(c=1\),
Bernoulli \(c_n\), Gaussian \(c_N\), Poisson \(c_P\), Bernoulli
\(V_{\mathrm{loading}}\), Hirose \(\Psi\), and Poisson
\(\bar y\)-weighting. Helpers stay in those test files.

Registry rows stay `planned` / `phase4_prep`. Prepare still
rejects `family_id` 3 and 4. No `src/`. No NEWS. No public
`se=TRUE`. `#1000` still skips.

## 3. Files Changed

- `tests/testthat/test-mspl-gamma-phase4-oracles.R`
- `tests/testthat/test-mspl-lognormal-phase4-oracles.R`
- `docs/dev-log/research/2026-08-16-mspl-gamma-lognormal-atom-pin.md`
- `docs/dev-log/research/2026-08-16-mspl-gamma-lognormal-door-gap.md`
- `docs/dev-log/research/2026-08-15-mspl-phase4-gamma-prep.md`
- `docs/dev-log/research/2026-08-15-mspl-phase4-lognormal-prep.md`
- `docs/dev-log/after-task/2026-08-16-mspl-gamma-lognormal-atom-pin.md` (this file)
- `docs/dev-log/check-log.md`

Not touched: `src/`, `R/mspl.R`, `R/mspl-registry.R`,
`R/mspl-curvature-pin.R`, `R/fit-multi.R`, NEWS, README,
ROADMAP, repo-root `LOOP/`, `#1000` test file.

## 3a. Decisions and Rejected Alternatives

- **Decision:** pin information-size rates
  \(2\sqrt{p/\max(\operatorname{tr} W,1)}\) with the live
  Bernoulli/Poisson leading 2. **Rationale:** both prep notes
  already name \(\operatorname{tr}(W)=n\phi\) and
  \(n/\sigma^2\) as the information-size diagnostic and kill
  row-count / event-count transplants. **Rejected:** inherit
  \(c=1\); copy \(c_n\), \(c_N\), or \(c_P\); use the 2023
  paper \(\sqrt{2p/n}\) without a family argument.
  **Confidence:** medium — AGENT-INFERRED; softness vs the
  Laplace objective is still unproved.
- **Decision:** weight the radial loading atom by the family
  \(W\) (per-trait \(\phi\); shared \(\sigma_\varepsilon\)).
  **Rationale:** Bernoulli radial is proven inert; Poisson
  \(\bar y\) is the wrong proxy; Hirose has no \(\Psi\).
  **Rejected:** no loading atom; Bernoulli radial; Poisson
  event-weighted radial. **Confidence:** medium — coercivity
  under Laplace remains OPEN (I-LA).
- **Decision:** helpers stay in the Phase-4 test files, not
  `R/mspl-*-atoms.R`. **Rationale:** no tape to twin.
  **Rejected:** admit-packet helper files. **Confidence:** high.

## 4. Checks Run

See `docs/dev-log/check-log.md` (2026-08-16 Gamma/lognormal
atom pin). Targeted `testthat::test_file` on the two oracle
files plus registry / rest-family prepare fence. `git diff --
src/ R/ NEWS.md` empty.

## 5. Tests of the Tests

- E11 fails if \(c\) equals 1, \(c_n\), \(c_N\), or \(c_P\).
- E12 fails if the info\(<1\) floor is omitted or if doubling
  \(\mu\) / \(\eta\) moves \(c\).
- E13–E14 fail if the loading atom stays positive at
  \(\phi=0\) / \(\sigma\to\infty\), or if it is not coercive
  at \(W>0\).
- E16 fails if Hirose or Poisson \(\bar y\) is accepted as
  the family atom.
- Existing E10 / prepare-fence tests fail if this sitting
  widens `fam_ids` to 3 or 4 or calls live MSPL.

## 6. Consistency Audit

```sh
rg -n 'status = "admitted"' R/mspl-registry.R
# Verdict: gamma / lognormal rows remain status = "planned".

rg -n 'fam_ids %in%' R/mspl.R
# Verdict: 3L and 4L absent.

rg -n 'estimator = .mspl.' \
  tests/testthat/test-mspl-gamma-phase4-oracles.R \
  tests/testthat/test-mspl-lognormal-phase4-oracles.R
# Verdict: comment / kill-list only; no live call.

git diff --stat -- src/ R/ NEWS.md
# Verdict: empty.
```

## 7. Roadmap Tick

N/A — oracle pin; no `ROADMAP.md` row.

## 7a. GitHub Issue Ledger

Inspected `#1051` (door-gap list, merged). No issue closed.
No new issue. This sitting is the overnight follow-on named
in the #1051 track, not a door.

## 8. What Did Not Go Smoothly

`move_agent_to_root` is blocked for subagents, so the isolated
worktree was edited by absolute path. The parent shared
worktree stayed on `cursor/mspl-poisson-admit-packet` and was
not mutated.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Ada.** Isolated worktree from `origin/main`. Finish line is
oracles + draft PR, merge only if CI-green and no door.

**Noether.** Rate uses \(\operatorname{tr}(W)\), not \(N_{\mathrm{rows}}\).
Loading uses family \(W\), not Bernoulli radial. Alias
\(V_\lambda^L(\sigma)=V_\lambda^\Gamma(\phi=1/\sigma^2)\) is
named so it cannot be sold as inheritance.

**Curie.** E11–E16 are prophylactic contrasts, not recovery
cells. No live MSPL.

**Rose.** `planned` ≠ door ≠ `admitted`. `#1000` skip stays.

## 10. Known Limitations And Next Actions

Still OPEN: G-φ / L-σ (shape / residual repair), L-mix
(shared `log_sigma_eps`), I-LA (Laplace-marginal
\(I(\beta)\)), prepare door, C++ tape, `#1000` un-skip,
admit.

**HARD STOP / OPEN GATE:** Shinichi before any prepare
widen, `src/` tape, `#1000` un-skip, `admitted` flip, NEWS
covered, or public `se=TRUE`.

## Mathematical contract

No public API / likelihood / grammar / family change. Oracle
pins only:

\[
c_\Gamma=2\sqrt{p_{\mathrm{free}}/\max(n\phi_\gamma,1)},
\quad
V_\lambda^\Gamma=\sum_t(\sqrt{1+\|\lambda_t\|^2\phi_t}-1),
\]

\[
c_L=2\sqrt{p_{\mathrm{free}}/\max(n/\sigma_\varepsilon^2,1)},
\quad
V_\lambda^L=\sum_t(\sqrt{1+\|\lambda_t\|^2/\sigma_\varepsilon^2}-1).
\]
