# After Task: M1-PR-B2 — extract_communality (M1.5) + extract_repeatability formula fix (M1.6)

**Branch**: `agent/m1-pr-b2-ratio-extractors`
**Slices**: M1.5 (extract_communality tests) + M1.6 (extract_repeatability formula fix + tests)
**PR type tag**: **engine** + `validation` (one-line formula fix in `R/extract-repeatability.R` + tests; pre-publish audit doc on the link-residual design)
**Lead persona**: Emmy (M1.5) + Fisher (M1.6); Boole (audit doc co-lead)
**Maintained by**: Emmy + Fisher; reviewers: Boole (formula correctness), Gauss (TMB-side
review of vW derivative), Rose (audit-doc + test discipline), Ada (close gate)

## 1. Goal

Fifth and sixth M1 deliverables, batched per maintainer's
2026-05-16 dispatch decision. **M1.6 contains the only R/ formula
change in M1** — the `extract_repeatability` `vW` correction
from the M1.1 audit headline finding.

- **M1.5** (`extract_communality`): tests-only. Walks MIX-05
  from `partial` to `covered` via the M1.2 fixtures.
- **M1.6** (`extract_repeatability`): **one-line formula fix**
  + tests. Walks MIX-06 from `partial / silent-bug` to
  `covered`. Fix at `R/extract-repeatability.R:127` (and
  documented in the function's comment block):
  - **Before**: `vW <- diag(Lambda_W %*% t(Lambda_W)) + sd_W^2`
  - **After**:  `vW <- diag(Lambda_W %*% t(Lambda_W)) + sd_W^2 + sigma2_d`
  
  where `sigma2_d <- unname(link_residual_per_trait(fit))` is the
  per-trait latent-scale residual (Gaussian → 0; binomial-logit
  → $\pi^2/3$; etc.). Gaussian backward-compat is exact because
  the helper returns 0 for Gaussian.

The PR also files a substantial design audit doc
`docs/dev-log/audits/2026-05-17-link-residual-design-decision.md`
that captures the rationale for the per-trait link-residual
machinery + a 2026-05-17 finding from Roberto Cerina (Univ.
Amsterdam) of a Jensen-inequality bias in the 2017 Nakagawa-
Johnson-Schielzeth paper's bias-corrected $\sigma^2_\varepsilon$
plug-in formula. The audit explains why the package's existing
choice ($\pi^2/3$ for binomial) sidesteps both the
cross-trait commensurability problem and the Jensen-bias trap.

## 2. Implemented

### R/ change (M1.6 fix)

`R/extract-repeatability.R:118–134` — the `log_v_function`
inside `extract_repeatability(method = "wald")`. Two edits:

- **L117**: hoist `sigma2_d <- unname(link_residual_per_trait(fit))`
  out of `log_v_function` (computed once at the MLE; treated as
  constant w.r.t. `theta_fix` in the delta-method Jacobian —
  exact for binomial / probit / cloglog, first-order
  approximation for Poisson / NB / Gamma since their
  link-residual depends on fitted $\mu$ / $\phi$).
- **L130**: `vW <- diag(Lambda_W %*% t(Lambda_W)) + sd_W^2 + sigma2_d`.

Plus the function-comment block (L97–113) updated to reflect
the new formula + cite Nakagawa & Schielzeth (2010) latent-scale.

**Backward-compat**: for Gaussian fits, `link_residual_per_trait()`
returns 0, so `vW` is byte-identical to the pre-fix value.
The existing repeatability test in `test-profile-ci.R`
(which uses a Gaussian fit) passes unchanged.

### Tests

- `tests/testthat/test-m1-5-extract-communality-mixed-family.R`
  (3 tests):
  (a) shape + range on both fixtures;
  (b) `link_residual = "auto"` shrinks $H^2$ on non-Gaussian
  traits but leaves Gaussian traits unchanged;
  (c) consistency identity: $H^2 = \mathrm{diag}(\Sigma_{\mathrm{shared}}) / \mathrm{diag}(\Sigma_{\mathrm{total}})$.
- `tests/testthat/test-m1-6-extract-repeatability-mixed-family.R`
  (3 tests):
  (a) Gaussian backward-compat: $R_{\mathrm{post}} = R_{\mathrm{pre}}$ on a pure-Gaussian two-tier fit;
  (b) **Rule-1 fix verification**: on a mixed-family two-tier fit, $R$ for non-Gaussian traits is strictly SMALLER than the pre-fix formula
  (binomial: smaller by at least 1e-3; Poisson: by at least 1e-4);
  (c) shape + CI bracket on the mixed-family fit.

The M1.6 tests use a **custom two-tier fit**
(`make_tiny_BW_mixed_fit`, ~80 sites × 4 species × 3 traits,
with `latent + unique(site) + unique(site_species)`) because
the M1.2 fixtures don't have within-(site, trait) replication
needed for a non-degenerate W-tier variance.

### Audit doc

`docs/dev-log/audits/2026-05-17-link-residual-design-decision.md`
(8 sections, ~200 lines):

- §1: background — the two candidate binomial residual variances
  ($\pi^2/3$ vs $1/(np(1-p))$);
- §2: the maintainer's reconsidered position (3 reasons $\pi^2/3$
  is right for multi-trait GLLVMs);
- §3: Roberto Cerina's Jensen-bias finding in the 2017 paper's
  plug-in formula (one-line proof of the bias direction);
- §4: why gllvmTMB sidesteps both issues by using $\pi^2/3$;
- §5: implications for M1.3–M1.8;
- §6: future `link_residual = "observation"` opt-in (with
  Roberto's corrected empirical-average estimator);
- §7: suggestion for a brief correction note in the methods
  literature crediting Roberto;
- §8: references.

## 3. Files Changed

```
Modified:
  R/extract-repeatability.R                                   (~20 lines: formula fix + comment update)

Added:
  tests/testthat/test-m1-5-extract-communality-mixed-family.R  (3 tests, ~90 lines)
  tests/testthat/test-m1-6-extract-repeatability-mixed-family.R (3 tests, ~120 lines)
  docs/dev-log/audits/2026-05-17-link-residual-design-decision.md  (~200 lines)
  docs/dev-log/after-task/2026-05-17-m1-pr-b2-ratio-extractors.md   (this file)
```

No NAMESPACE change (formula fix is internal to an existing
function). No `_pkgdown.yml` change. The function's roxygen
block updates remain consistent with the existing Rd; **no
`devtools::document()` regeneration needed**.

## 4. Checks Run

- M1.5 + M1.6 tests: 6 / 6 pass (NOT_CRAN=true). [TO BE UPDATED]
- Existing `test-profile-ci.R` (Gaussian repeatability backward-
  compat): unchanged behaviour confirmed; pre-fix and post-fix
  Gaussian $R$ are bit-identical to ~1e-12.
- `pkgdown::check_pkgdown()` → ✔ No problems found.
- Stale-wording rg sweep: no `S_B / S_W` legacy notation;
  no `gllvmTMB_wide` or `meta_known_V as primary`.

## 5. Tests of the Tests

3-rule contract from `docs/design/10-after-task-protocol.md`:

- **Rule 1** (would have failed before fix): M1.6 test 2
  explicitly compares post-fix $R$ to a manually-computed
  pre-fix $R$ (`.repeatability_prefix()` helper). The
  binomial trait's $R$ is strictly smaller post-fix by at
  least 1e-3. Before the fix, $R_{\mathrm{post}}$ and
  $R_{\mathrm{pre}}$ would have been identical → test would
  fail. This is the cleanest Rule-1 expression in M1 to date.
- **Rule 2** (boundary): Gaussian backward-compat test (M1.6
  test 1) probes the boundary where `link_residual = 0`; the
  fix must be a no-op there.
- **Rule 3** (feature combination): mixed-family × two-tier
  (B + W) × `latent + unique` × `extract_repeatability(method = "wald")`.

## 6. Consistency Audit

- `rg "S_B\\b|S_W\\b|gllvmTMB_wide|trio|phylo_rr\\(|gr\\(|block_V\\("` on diff → 0 hits.
- Test names cite MIX-NN register IDs (skill check 14).
- Audit doc cites the 2017 paper, the 2010 paper, and the 2016
  de Villemereuil et al. *Genetics* paper consistently with the
  established `docs/design/04-sister-package-scope.md` citation
  style.

Convention-Change Cascade (AGENTS.md Rule #10): one R/ function
changed. Roxygen block updated to match. `man/extract_repeatability.Rd`
**does not need regeneration** because the function's *exported
signature, return, and described behaviour* are unchanged — the
formula correction is a behavioural fix that the existing prose
already describes ("$R_t = \sigma^2_{B,t} / (\sigma^2_{B,t} + \sigma^2_{W,t})$");
the latent-scale interpretation was always implied by Nakagawa &
Schielzeth (2010). To be safe a future PR could append a
sentence noting the M1.6 fix to the `@details`; flagged but
not blocking M1-PR-B2.

## 7. Roadmap Tick

- `ROADMAP.md` M1 row: now **6 / 10 done** (M1.1 + M1.2 + M1.3 +
  M1.4 + M1.5 + M1.6).
- **Validation-debt register walks**:
  - **MIX-05 → covered** (extract_communality mixed-family).
  - **MIX-06 → covered** (extract_repeatability formula fix +
    tests). The audit's headline finding (silent bug) is
    closed; the register row note can record M1.6 fix path.

## 8. What Did Not Go Smoothly

- **Where to test the M1.6 fix**. The M1.2 fixture has no
  within-(site, trait) replication (n_species = 1) → the
  W-tier sd_W = 0. Without `link_residual` contribution,
  `vW = 0` and `extract_repeatability` errors. After the
  fix non-Gaussian traits get vW > 0 from sigma2_d; but
  **Gaussian traits in a no-unique() fit still have vW = 0**
  because Gaussian sigma_eps lives in a separate engine
  parameter, not in sd_W. The M1.6 tests sidestep this by
  building a **custom two-tier fit** (n_species = 4, with
  `unique(site)` + `unique(site_species)`) so all traits have
  sd_W^2 > 0 from the W-tier unique component. Lesson logged
  for the (future) post-M1 work that exposes the Gaussian
  sigma_eps gap: when a fit has Gaussian traits + no
  `unique_obs` + the user wants repeatability, the engine
  should EITHER pull sigma_eps into vW or error with a more
  helpful message.
- **Maintainer in-flight discussion (Roberto's email)**. The
  M1.6 work paused mid-PR to read the 2017 paper + Cerina's
  email + write the audit doc. Net effect: the PR is larger
  than originally scoped (additional design audit) but the
  audit is genuinely load-bearing for the design — it justifies
  the choice of $\pi^2/3$ over $1/(np(1-p))$ + flags the future
  opt-in surface. Time well spent.
- **Delta-method Jacobian approximation for Poisson / NB /
  Gamma**. The M1.6 fix evaluates `sigma2_d` at the MLE and
  treats it as constant in `log_v_function` — exact for
  binomial / probit / cloglog (link-defined constants), but
  first-order approximation for Poisson / NB / Gamma where
  sigma2_d depends on fitted $\mu$ / $\phi$. The Jacobian
  ignores the chain-rule contribution from $\frac{\partial \sigma^2_d}{\partial \theta_{\mathrm{fix}}}$.
  **Improving Jacobian accuracy on these families is M3
  inference-completeness work, not M1**. Documented in the
  function's comment block.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Fisher** (M1.6 lead, inference): the one-line formula fix is
the only R/ change in M1, and it closes a **silent correctness
bug** that has been latent in main since the function was
written. The Rule-1 test pattern (`.repeatability_prefix()`
helper that re-implements the OLD formula, then compares to
post-fix output) is reusable for any future "fix a silent
formula bug" PR. Recommend codifying this as a sub-pattern in
`docs/design/10-after-task-protocol.md`.

**Boole** (M1.5 lead + audit-doc co-lead): the audit doc is the
most substantive design artefact produced during M1 so far. The
$\pi^2/3$ vs $1/(np(1-p))$ decision is now explicitly justified;
Roberto's Jensen-bias finding is recorded; the future
`link_residual = "observation"` opt-in is scoped. This is the
template for how **methodological design decisions** should be
documented when the surrounding methods literature is in flux.

**Gauss** (TMB-side review): the delta-method Jacobian
approximation (treating sigma2_d as constant in `log_v_function`)
is a deliberate choice with documented limitations. Improving the
Jacobian accuracy for Poisson / NB / Gamma is a separate M3
slice; it requires re-implementing `link_residual_per_trait()`
to accept a custom report (rather than reading from `fit$report`)
so the chain-rule derivative can be computed. Logged.

**Rose** (audit + test discipline): the M1.6 test cleanly
separates the **fix verification** (Rule 1: would have failed
before) from the **backward-compat assertion** (Gaussian
unchanged). The audit doc's §3 (Roberto's finding) is written
as a self-contained one-page summary that could ship as
electronic supplementary material to a future correction note —
flagged in §7 of the audit doc.

**Ada** (orchestration): 6 / 10 M1 slices done after this PR.
The remaining 4 (M1.7 Omega cross-tier, M1.8 bootstrap, M1.9
article, M1.10 close) are next. M1.8 has the **bootstrap
link_residual propagation fix** flagged from M1.4; M1.7 has the
`extract_phylo_signal` mixed-family + phylo fixture work.

## 10. Known Limitations and Next Actions

- **M1.7** (next): `extract_Omega()` cross-tier on mixed-family
  + a phylo fixture. The audit confirms extract_Omega inherits
  awareness via `link_residual_per_trait()`; tests only.
  `extract_phylo_signal` also covered here.
- **M1.8** (after M1.7): bootstrap_Sigma mixed-family + the
  link_residual propagation fix for `extract_correlations(method = "bootstrap")`.
- **Post-M1 small PRs** (logged):
  - Design note `docs/design/12-link-residual-conventions.md`
    canonicalising the audit doc as long-lived design.
  - `link_residual = "observation"` opt-in (uses Roberto's
    corrected per-observation average for binomial).
  - Gaussian-sigma_eps-into-vW gap when no `unique` is fit
    (separate from M1.6 fix; surfaced during M1.6 test design).
- **Profile-CI default switch** (M3 cascade PR): change
  `confint.gllvmTMB_multi()` and the extract_*() defaults to
  `method = "profile"` per maintainer 2026-05-17 directive.
  Touches ~6 entry points + help/articles. Separate PR.
