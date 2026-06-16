# Shannon Audit: Engine Julia Draft Landing

Date: 2026-06-16 06:26 MDT

Auditor: Shannon perspective via Codex

Verdict: **WARN**

## Evidence

- Open PR census: `gh pr list --state open ...` returned `[]`.
- Recent-commit check: recent local commits are Codex truth-map
  `33287b1`, Codex gate-registry `2324646`, and handover commits on
  `engine-julia` (`9aed585`, `99aadb1`, `7c5bcde`).
- Remote refresh: `git fetch --prune origin` completed.
- Branch state:
  - `origin/main` = `9fc9b7f094e6`;
  - `origin/engine-julia` = `9aed58566b09`;
  - branch distance = `18 74` by `git rev-list --left-right --count`.
- Conflict scan: `git merge-tree --write-tree origin/main origin/engine-julia`
  reports conflicts in `NAMESPACE`, `NEWS.md`, `cran-comments.md`,
  `docs/dev-log/check-log.md`, and `man/gllvm_julia_fit.Rd`.
- Current open issues checked live: `#483`, `#485`, `#486`, and `#488`
  are all open.
- Paired Julia runtime check:
  - `GLLVM.jl-integration` clean at `1dc9e98`;
  - main `GLLVM.jl` checkout on `codex/non-gaussian-fitter-gradients`
    at `1b42e35`, ahead of remote by 50 commits, and treated as
    salvage-only for this pass.

## Coordination Finding

The bridge branch is reviewable as a draft concept, but not mergeable to
`main` without a conflict-resolution and release-scope decision. The hot
files are exactly the files that can distort public claims: `NEWS.md`,
generated docs, `NAMESPACE`, CRAN comments, and the check-log.

## Required Guardrails

- Do not close `#483`, `#485`, `#486`, or `#488` from this readout.
- Do not resolve generated `man/*.Rd` conflicts by hand as final truth.
- Do not describe the branch as CRAN-ready.
- Do not let the branch claim per-trait dispersion or per-trait ordinal
  cutpoint parity until the Julia-side implementation exists.
- Keep the CRAN-main lane and bridge lane separate until Ada chooses timing.

## Next Checkpoint

Run Shannon again before either:

- opening a draft PR from an updated bridge branch; or
- switching from the bridge lane into Julia per-trait nuisance-parameter
  implementation.
