# After Phase: two-paper private narrative and figure staging

**Date**: `2026-08-13`
**Phase**: `Private staging after foundation contracts; no evidence gate advanced`
**Roles (engaged)**: `Ada, Jason, Pat, Fisher, Gauss, Noether, Rose, Florence`

## 1. Goal

Turn the two-paper programme into two non-duplicative, private manuscript
architectures while preserving the evidence gates: Paper 1 is the spatial
source-separation question; Paper 2 is the nonspatial numerical-admission and
diagonal-Psi diagnostic question. Create only the two design figures explicitly
allowed before any model, empirical-data, or recovery gate.

## 2. What Shipped

- `dev/isdm-package-recovery/two-paper-staging/README.md` — scope and output
  receipt for the private staging package.
- `paper1-spatial-source-separation.md` — Paper 1 question, estimand,
  equations, evidence sequence, and figure fence.
- `paper2-numerical-psi-diagnostics.md` — Paper 2 frozen model, separate
  \(A_i\) and \(P_i\) outcomes, evidence sequence, and figure fence.
- `render-prototype-figures.R` — deterministic graphics-only renderer for
  P1-F1 known-truth fields and P2-F1 model/gate schematic.

The PNG files and `prototype-receipt.md` are ignored run artefacts under
`dev/isdm-package-recovery/results/two-paper-prototypes/`; they are not
versioned evidence or public material.

## 3. Evidence

```sh
Rscript --vanilla dev/isdm-package-recovery/two-paper-staging/render-prototype-figures.R
# PASS: P1-F1 and P2-F1 rendered in 3.5 s; no model fit, optimiser, profile,
# simulation, campaign, empirical record, or package compilation was invoked.

Rscript --vanilla -e 'stopifnot(file.info("dev/isdm-package-recovery/results/two-paper-prototypes/P1-F1-synthetic-two-field-design.png")$size > 0, file.info("dev/isdm-package-recovery/results/two-paper-prototypes/P2-F1-frozen-numerical-psi-design.png")$size > 0); cat("private prototype receipt PASS\n")'
# PASS: both prototype files were non-empty.

git diff --check
# PASS.

rg -n 'gllvmTMB\(|MakeADFun\(|nlminb\(|optim\(|profile\(|run.*campaign' dev/isdm-package-recovery/two-paper-staging
# PASS: no model-execution path is present in the staging renderer.

rg -n 'recovery result|fitted|empirical claim|NO_CANDIDATE|not a rate' dev/isdm-package-recovery/two-paper-staging
# PASS: all intentionally restricted wording names the private design or STOP/HOLD boundary.

rg -n 'integrated_jsdm\(|iJSDM|repeated-visit' README.md NEWS.md ROADMAP.md _pkgdown.yml vignettes
# PASS: this phase added no public iJSDM/repeated-visit capability wording.
```

The two rendered PNGs were visually inspected. The first visual pass caught a
crowded facet boundary in P1-F1 and an unreadable void-theme title in P2-F1;
the renderer was corrected, rerun without warnings, and reinspected. A final
source-routing correction ensures both sources enter shared ecology and only
GBIF enters the source-specific bias path.

## 4. Status Inventory

No public R API, likelihood, formula grammar, family, NAMESPACE, generated Rd,
README, NEWS, ROADMAP, vignette, pkgdown navigation, validation-debt row, or
empirical record changed. **Roadmap tick**: N/A — this is private design
staging, not a public capability or evidence promotion.

GitHub issue ledger: open PRs #959, #958, #957, #956, and #955 were inspected
for coordination only; none owns these private staging paths. No issue was
created, changed, or closed.

## 5. What Did Not Go Smoothly

The first renderer assumed a sourced-script frame and failed under `Rscript`
before making output. It now resolves its own `--file=` path explicitly.
Visual inspection caught two layout defects and one conceptual routing defect
before the prototypes became durable assets. These corrections did not touch
the estimator, fixture constants, maps, or gates.

## 6. Team Learning and Next Phase / Next Slices

**Jason / Pat:** Paper 1 must remain an applied spatial source-separation
story; Paper 2 must remain a synthetic numerical/Psi story. A shared empirical
case cannot be used to validate or populate Paper 2.

**Gauss / Noether / Fisher:** Paper 1's B2 Case D is a classifier-domain and
gradient-provenance question, not evidence to loosen the numerical gate.
Paper 2's numerical admission \(A_i\) and Psi recovery \(P_i\) are distinct
attempt-level outcomes; their co-occurrence cannot establish a cause.

**Rose:** all result-shaped maps, recovery figures, and empirical claims stay
locked. A design figure must not gain evidentiary force merely because it
renders. The next task needs a fresh explicit approval for each independently
reversible slice: Paper 1 C1 no-fit implementation, Paper 2 C2 no-fit
implementation, and/or empirical case-admission metadata work. None of these
authorises a fit or campaign.

**Florence:** separate palettes and visible private captions make P1-F1 legible
as known DGP truth; the P2-F1 gate node makes the Case-C terminal state visible
without presenting it as a recovery result.
