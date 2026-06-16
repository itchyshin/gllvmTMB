# Shannon Audit: Julia Per-Trait Dispersion Spec

Date: 2026-06-16

Auditor: Shannon perspective via Codex

Verdict: **WARN**

## Evidence

- Current branch: `codex/julia-per-trait-dispersion-spec`.
- Working tree before edits: clean.
- Open PR census: `gh pr list --state open ... --repo itchyshin/gllvmTMB`
  returned `[]`.
- Recent-commit check: current finish-programme commits are
  `6701ae5`, `8f1ae83`, `2324646`, and `33287b1`; recent
  `engine-julia` handover commits are `9aed585`, `99aadb1`, and `7c5bcde`.
- Hot-file overlap check on `docs/dev-log/check-log.md`,
  `docs/dev-log/coordination-board.md`, `docs/dev-log/after-task`, and
  `docs/dev-log/shannon-audits` found only the current Codex programme commits
  in the last six hours.
- Recovery rule after context compaction was followed: branch status, diff,
  check-log tail, and newest recovery checkpoint were read before editing.

## Coordination Finding

This is a docs-only design slice. It is safe to commit locally as a planning
contract, but it must not be treated as bridge implementation evidence. The
bridge branch still has the draft-landing conflicts recorded in
`docs/dev-log/2026-06-16-engine-julia-draft-landing.md`; this spec does not make
that branch mergeable.

## Required Guardrails

- Do not close `gllvmTMB#488` from this spec.
- Do not promote dispersion-family or ordinal bridge capability rows from this
  spec alone.
- Do not describe the Julia bridge as full parity, CRAN-ready, or release-ready.
- Keep the Xcoef structural-zero lane separate from per-trait nuisance-parameter
  parity.
- Run Shannon again before starting implementation, opening a PR, switching
  branches with uncommitted work, or updating issues.

## Next Checkpoint

After this spec is committed, the next safe code lane is
`codex/julia-per-trait-dispersion`, starting with no-X complete NB2, NB1, Beta,
and Gamma bridge routing through grouped fitters. Ordinal per-trait cutpoints
should follow as a separate code lane unless Ada explicitly combines them.
