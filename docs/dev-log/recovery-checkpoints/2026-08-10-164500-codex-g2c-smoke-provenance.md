# G2c smoke-root provenance reconciliation

## Purpose

This committed ledger freezes the provenance of two ignored, completed local
smoke roots without modifying either root after execution.  It supersedes the
incorrect earlier description of `g2c-smoke-20260810` as empty.

## Root history

Two independent invocations of the same synthetic ordinary fixture completed
in separate immutable-on-rerun roots.  The first terminal process returned
after the shell's early status capture; the second was deliberately placed in
a fresh `-retry1` root while the first outcome was still unknown.  Both roots
are retained.  Neither may be overwritten, re-summarised, or used for G2c or
G2d work.

| root | completed UTC | result | interpretation |
|---|---|---|---|
| `g2c-smoke-20260810` | 2026-08-10 21:45:50 | `SMOKE_HOLD` | first complete smoke; retained after delayed terminal observation |
| `g2c-smoke-20260810-retry1` | 2026-08-10 21:46:38 | `SMOKE_HOLD` | independent confirmation in a fresh root; the cited smoke record |

The two roots have byte-identical event ledgers and receipts.  Their RDS files
differ only as expected from separately retained object/timestamp state; their
embedded manifests agree on all scientific and software provenance.

## Shared embedded manifest

- package commit: `2041684f044303c0fe26d5dde2b83f38d882f05d`
- runner MD5: `bd40df1f92c518ee9eb654e315c94cd0`
- frozen protocol MD5: `58aca5bb985b8fed46edccfc50a07841`
- decision MD5: `4d7f990e0e86163a420dc47b2a10b1c7`
- R: `R version 4.6.0 (2026-04-24)`
- TMB: `1.9.21`
- platform: `aarch64-apple-darwin23`
- fixture: ordinary, replicate 1, seed 81101

## SHA-256 inventory

| root | file | SHA-256 |
|---|---|---|
| original | `event-ledger.csv` | `c72dd0ceff605bc5dd9beb635e1204d39f83350610b97f51482de1c3192240ee` |
| original | `fixtures/ordinary-replicate-01.rds` | `470af04a45dedcdac7a084a9c5a154a9dd969755607d0d5edd6d61048f661b4f` |
| original | `smoke-receipt.md` | `966defcb13d86e0b2b3a6a062ef3ecf107af0606666e25bf8da6af92448775e1` |
| retry1 | `event-ledger.csv` | `c72dd0ceff605bc5dd9beb635e1204d39f83350610b97f51482de1c3192240ee` |
| retry1 | `fixtures/ordinary-replicate-01.rds` | `582e6cc69a5479a0d2a6cb6d072533e5db1552eeeef37f93037f08db38719eda` |
| retry1 | `smoke-receipt.md` | `966defcb13d86e0b2b3a6a062ef3ecf107af0606666e25bf8da6af92448775e1` |

## Claim boundary

This ledger makes the ignored roots externally auditable against their frozen
commit.  It does not make either root a recovery campaign, a D-43 campaign
panel, empirical evidence, or a reason to launch Totoro.
