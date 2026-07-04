# After-task report: random-effects / likelihood Psi wording cleanup

Date: 2026-06-18 20:41 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Task

Continue the post-coevolution `unique()` deprecation cleanup by aligning older
design docs with the current ordinary Psi contract.

## What changed

- `docs/design/04-random-effects.md` now teaches ordinary
  `latent(0 + trait | g, d = K)` and `latent(1 + x | unit, d = K)` as the
  default `Lambda Lambda^T + Psi` / `Lambda_aug Lambda_aug^T + Psi_B,aug`
  surfaces.
- The same design doc now describes explicit ordinary `latent() + unique()` and
  explicit augmented `+ unique(1 + x | unit)` as compatibility syntax.
- `docs/design/03-likelihoods.md` now describes the RE-12 likelihood path using
  default `latent()` plus default diagonal `Psi_B,aug`.
- The older REML NEWS bullet now names default `latent()` covariance fits while
  preserving explicit `latent() + unique()` as compatibility syntax.

## Definition-of-done notes

1. Implementation: documentation-only consistency slice; no parser, TMB, or
   exported API change.
2. Simulation / recovery evidence: not applicable; this slice relies on the
   existing RE-12 / FG-04 / FG-06 evidence.
3. Documentation: source design docs and NEWS updated.
4. Runnable user-facing example: examples in the random-effects design doc now
   use the current default `latent()` spelling.
5. Check-log: see the 2026-06-18 20:41 MDT entry in
   `docs/dev-log/check-log.md`.
6. Review pass: Rose boundary only. Source-specific and kernel paired-Psi folds,
   extractor naming, keyword removal, bridge completion, release readiness, and
   scientific coverage completion remain out of scope.

## Checks

- `gh pr list --state open`
- `git log --all --oneline --since="6 hours ago"`
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
- `python3 -m json.tool docs/dev-log/dashboard/status.json >/dev/null && python3 -m json.tool docs/dev-log/dashboard/sweep.json >/dev/null && git diff --check`
- `rg -n 'ordinary.*latent \+ unique|ordinary.*latent\(\) \+ unique|latent\(1 \+ x \| unit, d = K\) \+ unique|ordinary Gaussian `latent \+ unique|Gaussian latent \+ unique|acceptance path.*latent \+ unique|unit-tier Gaussian augmented `latent \+ unique|ordinary `latent \+ unique' docs/design/03-likelihoods.md docs/design/04-random-effects.md README.md vignettes/gllvmTMB.Rmd vignettes/articles/random-regression-reaction-norms.Rmd`

## Explicit non-claims

- No keyword was removed.
- `part = "unique"` was not renamed.
- Source-specific and kernel paired-Psi folds remain future work.
- This is not bridge completion, release readiness, or scientific coverage
  completion.
