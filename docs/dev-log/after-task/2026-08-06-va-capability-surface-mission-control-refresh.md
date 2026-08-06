# After Task: VA capability surface and Mission Control refresh

**Verdict:** PASS for the presentation/status slice. Arc 1 remains complete;
Arc 2 scientific verdicts remain pending.

## 1. Goal

Bring the live gllvmTMB capability surface and Mission Control status into line
with the completed VA(GH) H = 7 Arc 1 while preserving the unmerged-branch,
structural-fence, recovery, and calibration boundaries.

## 2. Implemented

The capability page now shows the canonical 5 × 3 covariance grammar and all
18 individually admitted scalar VA family/link cells. It identifies exact,
hybrid, and GH H = 7 paths; retains explicit JJ for pure binomial-logit; and
keeps multinomial and non-scalar architectures fenced. It distinguishes
uncalibrated profiled-Schur fixed-effect VA-Wald bounds from variational latent
posterior SDs, which are not frequentist random-effect standard errors.

Mission Control serves the surface from the feature branch through
`canonical_ref`, while repository health remains based on the configured main
checkout. The status card records Arc 1 as closed and Arc 2 as active without
claiming family recovery or interval calibration.

## 3a. Decisions and Rejected Alternatives

> **Decision:** Pin only the capability surface to the VA branch.
> **Rationale:** It makes the current earned branch evidence visible without
> presenting it as merged main state.
> **Rejected alternative:** Copy or commit the capability claim directly onto
> main before the feature branch lands.
> **Confidence:** high; Mission Control supports a dedicated capability source.

> **Decision:** Collapse the superseded July VA research history instead of
> deleting it in this narrow refresh.
> **Rationale:** The current surface becomes concise while provenance remains
> available and visibly labelled historical.
> **Rejected alternative:** Leave stale “sealed/unreachable/H=15” prose in the
> current reading path.
> **Confidence:** high.

## 4. Files Touched

- `docs/dev-log/capability-surface.html`
- `docs/dev-log/check-log.md`
- this report
- Mission Control `live/projects.json`
- Mission Control `live/status/gllvmTMB.json`

No R source, TMB likelihood, tests, man page, NAMESPACE, README, NEWS, vignette
source, or estimator fixture changed.

## 5. Checks Run

- `git diff --check` — PASS.
- `jq empty` on both Mission Control JSON files — PASS.
- stdlib `HTMLParser` structural check — PASS.
- stale-wording scan — expected hits only inside the closed superseded-history
  disclosure.
- canonical Mission Control `start.sh --verify` — PASS.
- live browser verification of `/p/gllvmTMB/surface` — PASS; the page shows
  5 × 3, 18/18, H = 7, all scalar-family VA engine labels, the inference
  boundary, and the active Arc-2 notice.

## 6. Tests of the Tests

The stale-wording scan deliberately still finds July claims inside the closed
historical disclosure; treating a zero-hit scan as the target would erase
provenance rather than test the current reader path. The live browser check is
the discriminating test that the configured `canonical_ref`, not the main
checkout, supplies the rendered page.

## 7a. Issue Ledger

No issue was created. `gh pr list --state open` could not be refreshed because
GitHub was unreachable; the local six-hour all-ref log showed only this VA lane
touching the capability subject. The Mission Control update is a local cockpit
change, not a public release claim.

## 8. Consistency Audit

The surface, validation rows VA-02/04/06/09/10/11/12/13, Arc-1 report, and
Mission Control status agree on the following: 18 scalar cells are
implementation/light-gated; exact and hybrid paths remain; public branch auto
uses GH H = 7; explicit JJ remains; fixed-beta Wald and latent posterior SD are
uncalibrated; and Arc 2 owns recovery/calibration verdicts. The 5 × 3 grid now
also matches AGENTS.md and the keyword-grid contract.

## 9. What Did Not Go Smoothly

The status JSON stores compact rows and previously carried a very long stale
history blob. The first patch assumed expanded row formatting and failed
without changing files. The second patch matched the compact source, then the
stale note and resume prompt were replaced as whole lines.

## 10. Known Residuals

The page is a feature-branch preview until the VA branch lands. It is not
cross-platform proof, a release readiness statement, or an Arc-2 result. The
closed historical disclosure still contains superseded July prose by design.
Mission Control's broader status ledger contains older non-VA guard entries;
this slice changed only the active VA state.

## 11. Team Learning

Capability status needs two axes: where the code lives and what evidence it has
earned. `canonical_ref` solves the first without falsifying main; explicit
“light-gated / uncalibrated / Arc 2 pending” language solves the second. A
family name is not the admission unit when links differ, so both the code fence
and the dashboard should continue to reason in family/link cells.
