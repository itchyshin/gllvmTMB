# Codex handover -- Design 97 full-covariance JJ

## Critical context

You are Codex, resuming a new private Design-97 discriminator. Read
`AGENTS.md`, this handover, and `docs/design/97-fullcov-jj-discrimination.md`
before acting. Design 96 is immutable `SMOKE_STOP` at `1e113e32`; do not rerun,
rescore, amend, or use it as new evidence.

## Current working state

The isolated worktree is `/private/tmp/gllvmtmb-design97-fullcov-jj` on
`codex/design97-fullcov-jj-20260724`, based on `1e113e32`. Gate 1 passed after
math and scope review. The one-shot Gate-2/3 runner retained Gate 2 but stopped
before a Gate-3 record, so an exclusive stop receipt closed Design 97 as
`SMOKE_STOP`. The active Design-87 checkout is dirty and belongs to another
lane; it must remain untouched.

## Key decisions

Design 97 tests a full per-unit q=2 Cholesky covariance against a deterministic
two-dimensional GH marginal-likelihood comparator. It does not claim that a
richer q repairs underidentification, EVA parity, recovery, or integration.
Only private `dev/design97-fullcov-jj/` code is allowed.

## Next immediate steps

1. Do not rerun `run-discriminator.R`, delete its root, or create a Gate-3 fit.
2. Read `docs/dev-log/after-task/2026-07-24-design97-fullcov-jj-smoke-stop.md`.
3. Treat any runner investigation as a separately approved new research design.

## Landing state

| Artifact / branch | Commit | Pushed | State |
|---|---:|---|---|
| Design 96 recovery stop | `1e113e32` | no | LANDED locally, immutable predecessor |
| `codex/design97-fullcov-jj-20260724` | `85f27ae3` | no | CARRIED-OVER private `SMOKE_STOP` record |

The Design-97 branch is intentionally unpushed because this approved private
arc deferred push/PR/merge. Resume locally with
`git -C /private/tmp/gllvmtmb-design97-fullcov-jj switch codex/design97-fullcov-jj-20260724`.
Do not treat it as remotely recoverable until a maintainer separately authorizes
a push.

## How to resume

```text
Read AGENTS.md first. Rehydrate from docs/dev-log/handover/2026-07-24-codex-handover-design97.md and docs/dev-log/after-task/2026-07-24-design97-fullcov-jj-smoke-stop.md. Preserve Design 96 and 97 as immutable stop records; do not rerun either.
```
