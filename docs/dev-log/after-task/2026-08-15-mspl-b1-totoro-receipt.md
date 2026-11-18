# After Task: D-139 B1 Totoro receipt + dry-run launcher

**Branch**: `cursor/mspl-b1-totoro-receipt`
**Date**: 2026-08-15
**Roles (engaged)**: Ada / Gauss / Rose / Grace

## 1. Goal

Shinichi lifted the Design 118 B1 Totoro fence. Write the D-139
receipt that proposes `host=Totoro` with an honest B0-derived
time estimate, plus a dry-run-safe launcher a human or next
agent can fire. Do **not** start a >30 min remote job in this
sitting.

## 2. Implemented

- New B1 receipt:
  `docs/dev-log/research/2026-08-15-mspl-b1-totoro-receipt.md`.
  Status **PROPOSED, NOT STARTED**. Estimate ≈2,900 core-hours /
  ~19–21 h wall at 140–150 Totoro cores, from B0's published
  0.4 s/fit-equivalent × 26 M (D2). Uncertainty stated: B1 adds
  profile + 1-in-3 bootstrap; the B1 harness still marks timing
  PROVISIONAL.
- `dev/mspl-b1-totoro-launch.sh`: default dry-run; `--launch`
  requires `MSPL_B1_CONFIRM=yes`; D-143 cap 150; D-50 Actions
  refuse; `--on-totoro` refuses off Totoro.
- SE receipt amended only to point at B1 and to keep
  **NONE ISSUED** / not covered.
- Compute-policy §5 table filled for B1; SE row stays none.

## 3. Files Changed

- `docs/dev-log/research/2026-08-15-mspl-b1-totoro-receipt.md` (new)
- `dev/mspl-b1-totoro-launch.sh` (new)
- `docs/dev-log/research/2026-08-15-mspl-no-se-campaign-receipt.md`
- `docs/dev-log/research/2026-08-15-mspl-compute-totoro-drac.md`
- `docs/dev-log/after-task/2026-08-15-mspl-b1-totoro-receipt.md` (this file)
- `docs/dev-log/check-log.md`

No `src/`, no `R/`, no `NAMESPACE`, no NEWS, no README, no
repo-root `LOOP/`.

## 3a. Decisions and Rejected Alternatives

- **Decision:** new B1 receipt file, plus a pointer on the SE
  receipt, rather than rewriting the SE receipt into a B1
  receipt. **Rationale:** scanners still need `host=none` for
  SE. **Rejected:** one file that says both "none" and "Totoro"
  without a split. **Confidence:** high.
- **Decision:** Totoro host in the receipt; launcher still
  prints a DRAC-shaped note only as history. **Rationale:**
  Shinichi lifted the Totoro fence; D3's written placement was
  DRAC. **Rejected:** silently editing Design 118 §6.4 in this
  docs PR. **Confidence:** high.
- **Decision:** dry-run default + `MSPL_B1_CONFIRM=yes` dual
  key. **Rationale:** a next agent must be able to fire, and
  this sitting must not occupy Totoro by accident.
  **Rejected:** a script that SSHes on first run. **Confidence:**
  high.

## 4. Checks Run

```sh
chmod +x dev/mspl-b1-totoro-launch.sh
dev/mspl-b1-totoro-launch.sh --self-test
# expected: self-test PASS (dry-run, cap, Actions, confirm, hostname)

dev/mspl-b1-totoro-launch.sh --mode=full
# expected: prints plan, "nothing started", exact --launch command;
# does not SSH

rg -n 'SE covered' docs/dev-log/research/2026-08-15-mspl-b1-totoro-receipt.md \
  docs/dev-log/research/2026-08-15-mspl-no-se-campaign-receipt.md \
  dev/mspl-b1-totoro-launch.sh
# expected: B1 receipt and launcher say no; SE receipt stays NONE ISSUED

rg -n 'ssh ' dev/mspl-b1-totoro-launch.sh
# expected: ssh only inside launch_from_laptop, gated by CONFIRM=yes
```

Not run: `devtools::test()`, `R CMD check`, pkgdown, Totoro SSH,
DRAC `sbatch`, any >30 min job.

## 5. Tests of the Tests

`--self-test` is prophylactic: it proves the dry-run banner, the
151-worker refuse, the Actions refuse, the confirm refuse, and
the off-Totoro `--on-totoro` refuse. It does not prove a B1
shard.

## 6. Consistency Audit

```sh
rg -n 'host=Totoro|NONE ISSUED|sd_report' \
  docs/dev-log/research/2026-08-15-mspl-b1-totoro-receipt.md \
  docs/dev-log/research/2026-08-15-mspl-no-se-campaign-receipt.md
```

Verdict: B1 proposes Totoro; SE stays none; public `sd_report`
still withheld.

## 7. Roadmap Tick

N/A — no `ROADMAP.md` row.

## 7a. GitHub Issue Ledger

No relevant open issue; no new issue created. Coordination is
PR #981 (harness, still OPEN, `src/`-touching) and this docs
PR. #988 already merged the SE none-issued receipt.

## 8. What Did Not Go Smoothly

The B1 harness and B0 results file are on #981, not
`origin/main`. The launcher therefore fail-closes until
`MSPL_B1_PACKAGE_ROOT` points at a #981 checkout. That is
stated in the receipt rather than vendoring the harness onto
this branch.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Ada:** receipt before SSH; this sitting stops at the printed
command.

**Gauss:** the 2,900 core-hour number is B0's conversion, not a
B1 shard. The receipt says so.

**Rose:** SE "NONE ISSUED" and B1 "PROPOSED Totoro" must not
collapse into one scanner line.

**Grace:** D-50 / D-142 / D-143 guards are in the launcher, not
only in prose.

## 10. Known Limitations And Next Actions

- This sitting did not occupy Totoro.
- #981 must be available (merged or checked out) before
  `--launch`.
- A ≤30 min `--mode=canary` on B010 is the honest next
  pre-run if a conductor wants a B1-specific second before
  the ~20 h grid.
- MSPL-04 / public SE remain not covered.
