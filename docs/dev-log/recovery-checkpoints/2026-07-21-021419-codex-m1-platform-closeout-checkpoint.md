# Recovery Checkpoint: M1 Platform Closeout

**Timestamp**: 2026-07-21 02:14:19 MDT

**Owner**: root Codex, sole programme writer

## Branch and working-tree status

Builder: `/private/tmp/gllvmtmb-060-m1-builder`.

Branch: `codex/gllvmtmb-060-m1-baseline-20260720`.

Pre-receipt source head:
`9ee0ecd7bf38d71346534f6db6267af4061a9a38`.

Draft PR #778 is the sole open PR. At this checkpoint, `origin/main`
remains at the frozen M1 base
`de211f762812c574646938adaca22cbf41c6175e`.

Literal `git status --short --branch` after this checkpoint exists:

```text
## codex/gllvmtmb-060-m1-baseline-20260720...origin/codex/gllvmtmb-060-m1-baseline-20260720
 M docs/dev-log/after-task/2026-07-20-m1-heavy-baseline.md
 M docs/dev-log/check-log.md
?? docs/dev-log/recovery-checkpoints/2026-07-21-021419-codex-m1-platform-closeout-checkpoint.md
```

The live census contains 38 registered worktrees:

```sh
git worktree list --porcelain | awk '/^worktree /{n++} END{print n+0}'
```

Result: `38`. The dirty primary, detached verifier, and every registered
worktree other than the isolated builder remained untouched. This is a claim
of one active programme writer, not a claim that the parked estate is clean.

## Current diff before the receipt commit

```text
 .../after-task/2026-07-20-m1-heavy-baseline.md     | 141 ++++++++++++++++++---
 docs/dev-log/check-log.md                          | 138 ++++++++++++++++++++
 2 files changed, 260 insertions(+), 19 deletions(-)
```

This literal `git diff --stat` excludes the new untracked checkpoint by Git
design. `git ls-files --others --exclude-standard` identifies that one file;
its final line count is `658`.

The terminal touched-path inventory relative to `origin/main` includes tracked
and untracked paths using:

```sh
{
  git diff --name-only origin/main --
  git ls-files --others --exclude-standard
} | sort -u
```

Result: `76` paths (`7` added, `15` deleted, `54` modified).

## Retained platform evidence

- Predecessor PR Ubuntu run `29804219087`: PASS; historical/non-qualifying.
- Predecessor manual three-OS run `29804302347`: Ubuntu/macOS PASS;
  Windows job `88551611475` RETAINED FAILURE with 7,235 passes, 786 skips,
  one warning, and one failure.
- Predecessor Ubuntu-heavy run `29804303658`, job `88551626899`: PASS with
  13,614 passes, 104 skips, and 10 warnings; historical/non-qualifying.
- Repaired-head PR Ubuntu run `29806600748`, job `88558325914`: PASS.
- Repaired-head manual three-OS run `29806604519`: Windows job
  `88558339416`, Ubuntu job `88558339458`, and macOS job `88558339463`
  PASS.
- Repaired-head Ubuntu-heavy run `29809774107`, job `88568008718`: PASS
  from `2026-07-21T07:15:27Z` to `2026-07-21T08:12:44Z` at
  `9ee0ecd7bf38d71346534f6db6267af4061a9a38`; `Status: OK`; 13,611
  passes, 103 skips, 9 classified warnings, and 0 failures.

The complete run/job/OS/timestamp/denominator/qualification ledger is under
`### Immutable platform-attempt ledger` in
`docs/dev-log/after-task/2026-07-20-m1-heavy-baseline.md`.

The rejected `2026-07-21T06:41:13Z` dispatch created no run and remains an
infrastructure event outside the workflow-attempt denominator.

## Repaired-head local receipts

- Targeted plot suite: 250 passes; zero failure/error/warning/skip.
- Standard package check: 0 R CMD errors/warnings/notes; 7,010 passes,
  809 skips, one expected warning; 565.6744 seconds.
- Standard runner SHA-256:
  `a0d633ccac8d69b90a4282d87ad6ecce539db923df799fb5bc61903393f2cddd`.
- Standard results SHA-256:
  `c29194ba1536033e9e01ea333f8aadf688df4e996c0f4114758032291e905fa2`.
- Standard log SHA-256:
  `42f98e2c64595da5950779d8f5109e0aa74e3077232284c54e528ed79e5021ac`.
- Pkgdown PASS; log SHA-256:
  `4cd0200ed0bddccb1561b06b5ffbf716a6ca4f6556abaa1235660aa716d6b3a8`.
- Durable non-Git final-runner keeper:
  `/Users/z3437171/gllvmTMB-0.6-evidence/m1/final-receipt/runners/`.
  Its two runner files are byte-identical to the reviewed `/private/tmp`
  copies at the hashes below, so a cleanup or reboot does not erase the
  reconstructible gate.

## Commands already run

- Exclusive PR/branch/main/worktree coordination census: PASS.
- Repaired-head targeted, standard local, pkgdown, PR Ubuntu, complete manual
  three-OS, and Ubuntu-heavy gates: PASS.
- `gh run view 29809774107 --repo itchyshin/gllvmTMB --json
  status,conclusion,createdAt,updatedAt,headSha,jobs,url,workflowName`: terminal
  `success`; job `88568008718` completed `2026-07-21T08:12:44Z`.
- `gh run view 29809774107 --repo itchyshin/gllvmTMB --job 88568008718
  --log`: `Status: OK` and
  `[ FAIL 0 | WARN 9 | SKIP 103 | PASS 13611 ]`.
- After-task validator: PASS — `after-task structure check passed` (exit 0).
- `git diff --check`: PASS — exit 0 with no output.
- Independent receipt, numerical, runner, D-50, prospective D-43, and local
  gate-concurrency audits: PASS after their corrections. The prospective
  D-43 review is not one of the three required terminal verdicts.
- `shasum -a 256` across both temporary runners and both durable mirrors:
  pairwise equality at
  `fdee381f0cf7afa9b6cebe1ae0acc8b6ff4d0fbc987456c6e21f8b7a8030720c`
  and
  `6bc5c7f20a9767f59d69fb11552838c522dcb195fb110b6ca02f722d17b6bb1c`.

## Commands still required

1. Prove no sentinel or placeholder remains and validate this literal
   checkpoint, the after-task report, the terminal path inventory, and the
   complete diff.
2. Stage only the after-task report, check-log, and this checkpoint; inspect
   the cached diff and commit the receipt-only final source head locally. Do
   not push yet.
3. Use the durable runner directory
   `/Users/z3437171/gllvmTMB-0.6-evidence/m1/final-receipt/runners` and
   re-hash both files immediately before execution. Require exact equality to:
   - package-check runner
     `fdee381f0cf7afa9b6cebe1ae0acc8b6ff4d0fbc987456c6e21f8b7a8030720c`;
   - pkgdown runner
     `6bc5c7f20a9767f59d69fb11552838c522dcb195fb110b6ca02f722d17b6bb1c`.
4. Run the package-check runner first and pkgdown runner second with this exact
   local protocol. It freezes the commit identity, disables the heavy opt-in,
   pins numerical-library threads, uses SHA/attempt-specific durable logs,
   validates each RDS `source_sha`, and proves repository/ignored-file state
   is unchanged after each gate:

   ```sh
   set -euo pipefail
   m1_final_branch='codex/gllvmtmb-060-m1-baseline-20260720'
   m1_pre_receipt_sha='9ee0ecd7bf38d71346534f6db6267af4061a9a38'
   m1_final_sha=$(git rev-parse HEAD)
   m1_runner_dir='/Users/z3437171/gllvmTMB-0.6-evidence/m1/final-receipt/runners'
   m1_evidence_dir="/Users/z3437171/gllvmTMB-0.6-evidence/m1/final-receipt/${m1_final_sha}"
   mkdir -p "$m1_evidence_dir/logs" "$m1_evidence_dir/results" "$m1_evidence_dir/state"

   test "$(git rev-parse --abbrev-ref HEAD)" = "$m1_final_branch"
   test "$(git rev-parse HEAD^)" = "$m1_pre_receipt_sha"
   test "$(git rev-list --parents -n 1 HEAD | awk '{print NF}')" -eq 2
   m1_expected_receipt_paths=$(printf '%s\n' \
     'docs/dev-log/after-task/2026-07-20-m1-heavy-baseline.md' \
     'docs/dev-log/check-log.md' \
     'docs/dev-log/recovery-checkpoints/2026-07-21-021419-codex-m1-platform-closeout-checkpoint.md' \
     | LC_ALL=C sort)
   m1_actual_receipt_paths=$(git diff-tree --no-commit-id --name-only -r HEAD \
     | LC_ALL=C sort)
   test "$m1_actual_receipt_paths" = "$m1_expected_receipt_paths"
   test -z "$(git status --porcelain=v1 --untracked-files=all)"
   test "$(shasum -a 256 "$m1_runner_dir/m1-final-receipt-head-check-runner.R" | awk '{print $1}')" = \
     'fdee381f0cf7afa9b6cebe1ae0acc8b6ff4d0fbc987456c6e21f8b7a8030720c'
   test "$(shasum -a 256 "$m1_runner_dir/m1-final-receipt-head-pkgdown-runner.R" | awk '{print $1}')" = \
     '6bc5c7f20a9767f59d69fb11552838c522dcb195fb110b6ca02f722d17b6bb1c'
   git status --ignored --short > "$m1_evidence_dir/state/ignored-before.txt"

   m1_check_attempt=$(date -u '+%Y%m%dT%H%M%SZ')
   m1_check_log="$m1_evidence_dir/logs/${m1_final_sha}-${m1_check_attempt}-check.log"
   test ! -e "$m1_check_log"
   GLLVMTMB_HEAVY_TESTS= NOT_CRAN=true \
     OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 \
     Rscript --vanilla "$m1_runner_dir/m1-final-receipt-head-check-runner.R" \
     > "$m1_check_log" 2>&1
   m1_check_rds=$(sed -n 's/^M1_FINAL_RECEIPT_CHECK_RESULTS_PATH=//p' "$m1_check_log" | tail -n 1)
   test -n "$m1_check_rds"
   test -f "$m1_check_rds"
   M1_RECEIPT_RDS="$m1_check_rds" M1_EXPECTED_SHA="$m1_final_sha" \
     Rscript --vanilla -e '
   x <- readRDS(Sys.getenv("M1_RECEIPT_RDS"))
   required <- c(
     "source_sha", "attempt_id", "started_at", "finished_at",
     "elapsed_seconds", "environment", "session_info", "result",
     "runner_error", "runner_warnings", "counts"
   )
   stopifnot(
     is.list(x), identical(names(x), required),
     is.character(x$source_sha), length(x$source_sha) == 1L,
     !is.na(x$source_sha),
     identical(x$source_sha, Sys.getenv("M1_EXPECTED_SHA")),
     is.character(x$attempt_id), length(x$attempt_id) == 1L,
     !is.na(x$attempt_id), nzchar(x$attempt_id),
     inherits(x$started_at, "POSIXt"), length(x$started_at) == 1L,
     !is.na(x$started_at), inherits(x$finished_at, "POSIXt"),
     length(x$finished_at) == 1L, !is.na(x$finished_at),
     x$finished_at >= x$started_at, is.numeric(x$elapsed_seconds),
     length(x$elapsed_seconds) == 1L, is.finite(x$elapsed_seconds),
     x$elapsed_seconds >= 0, is.character(x$environment),
     inherits(x$session_info, "sessionInfo"),
     inherits(x$result, "rcmdcheck"), is.null(x$runner_error),
     is.character(x$runner_warnings), length(x$runner_warnings) == 0L,
     is.integer(x$counts), identical(names(x$counts), c("errors", "warnings", "notes")),
     length(x$counts) == 3L, identical(unname(x$counts), rep.int(0L, 3L))
   )
   '
   test "$(git rev-parse HEAD)" = "$m1_final_sha"
   test "$(git rev-parse --abbrev-ref HEAD)" = "$m1_final_branch"
   test -z "$(git status --porcelain=v1 --untracked-files=all)"
   git status --ignored --short > "$m1_evidence_dir/state/ignored-after-check.txt"
   diff -u "$m1_evidence_dir/state/ignored-before.txt" \
     "$m1_evidence_dir/state/ignored-after-check.txt"
   cp -p "$m1_check_rds" "$m1_evidence_dir/results/"
   shasum -a 256 "$m1_check_log" "$m1_check_rds" \
     > "$m1_evidence_dir/state/${m1_check_attempt}-check-sha256.txt"

   m1_pkgdown_attempt=$(date -u '+%Y%m%dT%H%M%SZ')
   m1_pkgdown_log="$m1_evidence_dir/logs/${m1_final_sha}-${m1_pkgdown_attempt}-pkgdown.log"
   test ! -e "$m1_pkgdown_log"
   GLLVMTMB_HEAVY_TESTS= NOT_CRAN=true \
     OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 \
     Rscript --vanilla "$m1_runner_dir/m1-final-receipt-head-pkgdown-runner.R" \
     > "$m1_pkgdown_log" 2>&1
   m1_pkgdown_rds=$(sed -n 's/^M1_FINAL_RECEIPT_PKGDOWN_RESULTS_PATH=//p' "$m1_pkgdown_log" | tail -n 1)
   test -n "$m1_pkgdown_rds"
   test -f "$m1_pkgdown_rds"
   M1_RECEIPT_RDS="$m1_pkgdown_rds" M1_EXPECTED_SHA="$m1_final_sha" \
     Rscript --vanilla -e '
   x <- readRDS(Sys.getenv("M1_RECEIPT_RDS"))
   required <- c(
     "source_sha", "attempt_id", "started_at", "finished_at",
     "elapsed_seconds", "session_info", "result", "runner_error",
     "runner_warnings"
   )
   stopifnot(
     is.list(x), identical(names(x), required),
     is.character(x$source_sha), length(x$source_sha) == 1L,
     !is.na(x$source_sha),
     identical(x$source_sha, Sys.getenv("M1_EXPECTED_SHA")),
     is.character(x$attempt_id), length(x$attempt_id) == 1L,
     !is.na(x$attempt_id), nzchar(x$attempt_id),
     inherits(x$started_at, "POSIXt"), length(x$started_at) == 1L,
     !is.na(x$started_at), inherits(x$finished_at, "POSIXt"),
     length(x$finished_at) == 1L, !is.na(x$finished_at),
     x$finished_at >= x$started_at, is.numeric(x$elapsed_seconds),
     length(x$elapsed_seconds) == 1L, is.finite(x$elapsed_seconds),
     x$elapsed_seconds >= 0, inherits(x$session_info, "sessionInfo"),
     is.null(x$result), is.null(x$runner_error),
     is.character(x$runner_warnings),
     length(x$runner_warnings) == 0L
   )
   '
   test "$(git rev-parse HEAD)" = "$m1_final_sha"
   test "$(git rev-parse --abbrev-ref HEAD)" = "$m1_final_branch"
   test -z "$(git status --porcelain=v1 --untracked-files=all)"
   git status --ignored --short > "$m1_evidence_dir/state/ignored-after-pkgdown.txt"
   diff -u "$m1_evidence_dir/state/ignored-before.txt" \
     "$m1_evidence_dir/state/ignored-after-pkgdown.txt"
   cp -p "$m1_pkgdown_rds" "$m1_evidence_dir/results/"
   shasum -a 256 "$m1_pkgdown_log" "$m1_pkgdown_rds" \
     > "$m1_evidence_dir/state/${m1_pkgdown_attempt}-pkgdown-sha256.txt"
   ```
5. Only after both local gates pass, push the sole branch. The pull-request
   classifier uses `origin/main...HEAD`, so the automatic PR run must perform
   a full Ubuntu package check for the complete 76-path PR rather than take
   the ignored-source/process fast path. The executable guard below proves the
   final commit has exactly one parent (the repaired head), changes exactly the
   three receipt paths, captures a unique automatic run, and retains every job
   log plus its denominator under the SHA-keyed durable evidence directory.
   The automatic Ubuntu result cannot replace the complete manual matrix.

   ```sh
   set -euo pipefail
   m1_final_branch='codex/gllvmtmb-060-m1-baseline-20260720'
   m1_frozen_base='de211f762812c574646938adaca22cbf41c6175e'
   m1_pre_receipt_sha='9ee0ecd7bf38d71346534f6db6267af4061a9a38'
   m1_final_sha=$(git rev-parse HEAD)
   m1_evidence_dir="/Users/z3437171/gllvmTMB-0.6-evidence/m1/final-receipt/${m1_final_sha}"

   m1_assert_lane() {
     m1_expected_remote=$1
     test "$(git rev-parse --abbrev-ref HEAD)" = "$m1_final_branch"
     test "$(git rev-parse HEAD)" = "$m1_final_sha"
     test "$(git rev-parse HEAD^)" = "$m1_pre_receipt_sha"
     test "$(git rev-list --parents -n 1 HEAD | awk '{print NF}')" -eq 2
     test -z "$(git status --porcelain=v1 --untracked-files=all)"
     m1_expected_receipt_paths=$(printf '%s\n' \
       'docs/dev-log/after-task/2026-07-20-m1-heavy-baseline.md' \
       'docs/dev-log/check-log.md' \
       'docs/dev-log/recovery-checkpoints/2026-07-21-021419-codex-m1-platform-closeout-checkpoint.md' \
       | LC_ALL=C sort)
     m1_actual_receipt_paths=$(git diff-tree --no-commit-id --name-only -r HEAD \
       | LC_ALL=C sort)
     test "$m1_actual_receipt_paths" = "$m1_expected_receipt_paths"
     test "$(git ls-remote origin refs/heads/main | awk '{print $1}')" = "$m1_frozen_base"
     test "$(git ls-remote --heads origin "$m1_final_branch" | awk '{print $1}')" = "$m1_expected_remote"
   }

   m1_capture_run_logs() {
     m1_capture_run_id=$1
     m1_capture_terminal=$2
     m1_capture_manifest="$m1_evidence_dir/state/run-${m1_capture_run_id}-jobs.json"
     m1_capture_hashes="$m1_evidence_dir/state/run-${m1_capture_run_id}-job-logs-sha256.txt"
     test ! -e "$m1_capture_manifest"
     test ! -e "$m1_capture_hashes"
     jq '[.jobs[] | {databaseId,name,status,conclusion,startedAt,completedAt,steps}]' \
       "$m1_capture_terminal" > "$m1_capture_manifest"
     : > "$m1_capture_hashes"
     jq -r '.jobs[].databaseId' "$m1_capture_terminal" | while IFS= read -r m1_capture_job_id; do
       m1_capture_log="$m1_evidence_dir/logs/run-${m1_capture_run_id}-job-${m1_capture_job_id}.log"
       test ! -e "$m1_capture_log"
       gh run view "$m1_capture_run_id" --repo itchyshin/gllvmTMB \
         --job "$m1_capture_job_id" --log > "$m1_capture_log"
       shasum -a 256 "$m1_capture_log" >> "$m1_capture_hashes"
     done
     shasum -a 256 "$m1_capture_terminal" "$m1_capture_manifest" \
       >> "$m1_capture_hashes"
   }

   m1_record_check_denominator() {
     m1_record_run_id=$1
     m1_record_job_id=$2
     m1_record_log="$m1_evidence_dir/logs/run-${m1_record_run_id}-job-${m1_record_job_id}.log"
     m1_record_summary="$m1_evidence_dir/state/run-${m1_record_run_id}-job-${m1_record_job_id}-denominator.txt"
     test -f "$m1_record_log"
     test ! -e "$m1_record_summary"
     rg -o '\[ FAIL [0-9]+ \| WARN [0-9]+ \| SKIP [0-9]+ \| PASS [0-9]+ \]' \
       "$m1_record_log" | LC_ALL=C sort -u > "$m1_record_summary"
     test "$(wc -l < "$m1_record_summary" | tr -d '[:space:]')" = 1
     shasum -a 256 "$m1_record_summary" \
       >> "$m1_evidence_dir/state/run-${m1_record_run_id}-job-logs-sha256.txt"
   }

   m1_require_successful_check_log() {
     m1_require_run_id=$1
     m1_require_job_id=$2
     m1_require_log="$m1_evidence_dir/logs/run-${m1_require_run_id}-job-${m1_require_job_id}.log"
     m1_require_summary="$m1_evidence_dir/state/run-${m1_require_run_id}-job-${m1_require_job_id}-denominator.txt"
     rg -q 'Status: OK' "$m1_require_log"
     rg -q '^\[ FAIL 0 \| WARN [0-9]+ \| SKIP [0-9]+ \| PASS [0-9]+ \]$' \
       "$m1_require_summary"
   }

   m1_assert_lane "$m1_pre_receipt_sha"
   m1_push_started=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
   git push origin "$m1_final_branch"
   m1_assert_lane "$m1_final_sha"

   m1_auto_list="$m1_evidence_dir/state/automatic-pr-runs-after-push.json"
   m1_auto_run_id=''
   for m1_poll in $(seq 1 60); do
     gh run list --repo itchyshin/gllvmTMB --workflow R-CMD-check.yaml \
       --branch "$m1_final_branch" --event pull_request --limit 30 \
       --json databaseId,createdAt,headSha,status,conclusion,event,headBranch,url \
       > "$m1_auto_list"
     m1_auto_count=$(jq -r --arg sha "$m1_final_sha" --arg branch "$m1_final_branch" \
       --arg since "$m1_push_started" \
       '[.[] | select(.headSha == $sha and .headBranch == $branch and .event == "pull_request" and .createdAt >= $since)] | length' \
       "$m1_auto_list")
     case "$m1_auto_count" in
       0) sleep 10 ;;
       1) m1_auto_run_id=$(jq -r --arg sha "$m1_final_sha" --arg branch "$m1_final_branch" \
            --arg since "$m1_push_started" \
            '.[] | select(.headSha == $sha and .headBranch == $branch and .event == "pull_request" and .createdAt >= $since) | .databaseId' \
            "$m1_auto_list"); break ;;
       *) exit 1 ;;
     esac
   done
   test -n "$m1_auto_run_id"
   m1_auto_created="$m1_evidence_dir/state/automatic-pr-${m1_auto_run_id}-created.json"
   m1_auto_terminal="$m1_evidence_dir/state/automatic-pr-${m1_auto_run_id}-terminal.json"
   gh run view "$m1_auto_run_id" --repo itchyshin/gllvmTMB \
     --json workflowName,headSha,status,conclusion,event,headBranch,url,jobs \
     > "$m1_auto_created"
   jq -e --arg sha "$m1_final_sha" --arg branch "$m1_final_branch" \
     '.workflowName == "R-CMD-check" and .headSha == $sha and .headBranch == $branch and .event == "pull_request"' \
     "$m1_auto_created"
   m1_auto_watch_status=0
   gh run watch "$m1_auto_run_id" --repo itchyshin/gllvmTMB --exit-status --interval 60 \
     || m1_auto_watch_status=$?
   gh run view "$m1_auto_run_id" --repo itchyshin/gllvmTMB \
     --json workflowName,headSha,status,conclusion,event,headBranch,url,jobs \
     > "$m1_auto_terminal"
   m1_capture_run_logs "$m1_auto_run_id" "$m1_auto_terminal"
   m1_auto_job_id=$(jq -r '[.jobs[] | select(.name == "ubuntu-latest (release)")] | if length == 1 then .[0].databaseId else empty end' \
     "$m1_auto_terminal")
   test -n "$m1_auto_job_id"
   m1_record_check_denominator "$m1_auto_run_id" "$m1_auto_job_id"
   jq -e --arg sha "$m1_final_sha" --arg branch "$m1_final_branch" '
     .workflowName == "R-CMD-check" and
     .headSha == $sha and .headBranch == $branch and
     .event == "pull_request" and .status == "completed" and .conclusion == "success" and
     (.jobs | length) == 1 and .jobs[0].name == "ubuntu-latest (release)" and
     .jobs[0].status == "completed" and .jobs[0].conclusion == "success" and
     ([.jobs[0].steps[] | select(.name == "Run r-lib/actions/check-r-package@v2" and .status == "completed" and .conclusion == "success")] | length) == 1 and
     ([.jobs[0].steps[] | select(.name == "Fast pass for ignored-source/process change" and .status == "completed" and .conclusion == "skipped")] | length) == 1
   ' "$m1_auto_terminal"
   test "$m1_auto_watch_status" -eq 0
   m1_require_successful_check_log "$m1_auto_run_id" "$m1_auto_job_id"
   gh run list --repo itchyshin/gllvmTMB --workflow R-CMD-check.yaml \
     --branch "$m1_final_branch" --event pull_request --limit 30 \
     --json databaseId,createdAt,headSha,status,conclusion,event,headBranch,url \
     > "$m1_evidence_dir/state/automatic-pr-terminal-candidates.json"
   jq -e --arg sha "$m1_final_sha" --arg branch "$m1_final_branch" \
     --arg since "$m1_push_started" --argjson run "$m1_auto_run_id" \
     '[.[] | select(.headSha == $sha and .headBranch == $branch and .event == "pull_request" and .createdAt >= $since) | .databaseId] == [$run]' \
     "$m1_evidence_dir/state/automatic-pr-terminal-candidates.json"
   m1_assert_lane "$m1_final_sha"
   ```

6. Recheck commit lineage, local cleanliness, local/remote equality, and the
   frozen base before **each** manual dispatch. Capture each matching run
   uniquely; after both attempts terminate, retain every job log before
   applying success predicates. Require exactly one Ubuntu, one macOS, and one
   Windows package-check job in the routine matrix, and require the successful
   `matrix-setup` plus exactly one Ubuntu package-check job in the heavy run.

   ```sh
   set -euo pipefail
   m1_final_branch='codex/gllvmtmb-060-m1-baseline-20260720'
   m1_frozen_base='de211f762812c574646938adaca22cbf41c6175e'
   m1_pre_receipt_sha='9ee0ecd7bf38d71346534f6db6267af4061a9a38'
   m1_final_sha=$(git rev-parse HEAD)
   m1_evidence_dir="/Users/z3437171/gllvmTMB-0.6-evidence/m1/final-receipt/${m1_final_sha}"

   m1_assert_lane() {
     test "$(git rev-parse --abbrev-ref HEAD)" = "$m1_final_branch"
     test "$(git rev-parse HEAD)" = "$m1_final_sha"
     test "$(git rev-parse HEAD^)" = "$m1_pre_receipt_sha"
     test "$(git rev-list --parents -n 1 HEAD | awk '{print NF}')" -eq 2
     test -z "$(git status --porcelain=v1 --untracked-files=all)"
     m1_expected_receipt_paths=$(printf '%s\n' \
       'docs/dev-log/after-task/2026-07-20-m1-heavy-baseline.md' \
       'docs/dev-log/check-log.md' \
       'docs/dev-log/recovery-checkpoints/2026-07-21-021419-codex-m1-platform-closeout-checkpoint.md' \
       | LC_ALL=C sort)
     m1_actual_receipt_paths=$(git diff-tree --no-commit-id --name-only -r HEAD \
       | LC_ALL=C sort)
     test "$m1_actual_receipt_paths" = "$m1_expected_receipt_paths"
     test "$(git ls-remote origin refs/heads/main | awk '{print $1}')" = "$m1_frozen_base"
     test "$(git ls-remote --heads origin "$m1_final_branch" | awk '{print $1}')" = "$m1_final_sha"
   }

   m1_capture_run_logs() {
     m1_capture_run_id=$1
     m1_capture_terminal=$2
     m1_capture_manifest="$m1_evidence_dir/state/run-${m1_capture_run_id}-jobs.json"
     m1_capture_hashes="$m1_evidence_dir/state/run-${m1_capture_run_id}-job-logs-sha256.txt"
     test ! -e "$m1_capture_manifest"
     test ! -e "$m1_capture_hashes"
     jq '[.jobs[] | {databaseId,name,status,conclusion,startedAt,completedAt,steps}]' \
       "$m1_capture_terminal" > "$m1_capture_manifest"
     : > "$m1_capture_hashes"
     jq -r '.jobs[].databaseId' "$m1_capture_terminal" | while IFS= read -r m1_capture_job_id; do
       m1_capture_log="$m1_evidence_dir/logs/run-${m1_capture_run_id}-job-${m1_capture_job_id}.log"
       test ! -e "$m1_capture_log"
       gh run view "$m1_capture_run_id" --repo itchyshin/gllvmTMB \
         --job "$m1_capture_job_id" --log > "$m1_capture_log"
       shasum -a 256 "$m1_capture_log" >> "$m1_capture_hashes"
     done
     shasum -a 256 "$m1_capture_terminal" "$m1_capture_manifest" \
       >> "$m1_capture_hashes"
   }

   m1_record_check_denominator() {
     m1_record_run_id=$1
     m1_record_job_id=$2
     m1_record_log="$m1_evidence_dir/logs/run-${m1_record_run_id}-job-${m1_record_job_id}.log"
     m1_record_summary="$m1_evidence_dir/state/run-${m1_record_run_id}-job-${m1_record_job_id}-denominator.txt"
     test -f "$m1_record_log"
     test ! -e "$m1_record_summary"
     rg -o '\[ FAIL [0-9]+ \| WARN [0-9]+ \| SKIP [0-9]+ \| PASS [0-9]+ \]' \
       "$m1_record_log" | LC_ALL=C sort -u > "$m1_record_summary"
     test "$(wc -l < "$m1_record_summary" | tr -d '[:space:]')" = 1
     shasum -a 256 "$m1_record_summary" \
       >> "$m1_evidence_dir/state/run-${m1_record_run_id}-job-logs-sha256.txt"
   }

   m1_require_successful_check_log() {
     m1_require_run_id=$1
     m1_require_job_id=$2
     m1_require_log="$m1_evidence_dir/logs/run-${m1_require_run_id}-job-${m1_require_job_id}.log"
     m1_require_summary="$m1_evidence_dir/state/run-${m1_require_run_id}-job-${m1_require_job_id}-denominator.txt"
     rg -q 'Status: OK' "$m1_require_log"
     rg -q '^\[ FAIL 0 \| WARN [0-9]+ \| SKIP [0-9]+ \| PASS [0-9]+ \]$' \
       "$m1_require_summary"
   }

   m1_assert_lane
   m1_three_since=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
   gh workflow run R-CMD-check.yaml --repo itchyshin/gllvmTMB \
     --ref "$m1_final_branch" -f full_matrix=true
   m1_three_list="$m1_evidence_dir/state/manual-three-os-runs.json"
   m1_three_run_id=''
   for m1_poll in $(seq 1 60); do
     gh run list --repo itchyshin/gllvmTMB --workflow R-CMD-check.yaml \
       --branch "$m1_final_branch" --event workflow_dispatch --limit 30 \
       --json databaseId,createdAt,headSha,status,conclusion,event,headBranch,url \
       > "$m1_three_list"
     m1_three_count=$(jq -r --arg sha "$m1_final_sha" --arg branch "$m1_final_branch" \
       --arg since "$m1_three_since" \
       '[.[] | select(.headSha == $sha and .headBranch == $branch and .event == "workflow_dispatch" and .createdAt >= $since)] | length' \
       "$m1_three_list")
     case "$m1_three_count" in
       0) sleep 10 ;;
       1) m1_three_run_id=$(jq -r --arg sha "$m1_final_sha" --arg branch "$m1_final_branch" \
            --arg since "$m1_three_since" \
            '.[] | select(.headSha == $sha and .headBranch == $branch and .event == "workflow_dispatch" and .createdAt >= $since) | .databaseId' \
            "$m1_three_list"); break ;;
       *) exit 1 ;;
     esac
   done
   test -n "$m1_three_run_id"
   m1_three_created="$m1_evidence_dir/state/manual-three-os-${m1_three_run_id}-created.json"
   m1_three_terminal="$m1_evidence_dir/state/manual-three-os-${m1_three_run_id}-terminal.json"
   gh run view "$m1_three_run_id" --repo itchyshin/gllvmTMB \
     --json workflowName,headSha,status,conclusion,event,headBranch,url,jobs \
     > "$m1_three_created"
   jq -e --arg sha "$m1_final_sha" --arg branch "$m1_final_branch" \
     '.workflowName == "R-CMD-check" and .headSha == $sha and .headBranch == $branch and .event == "workflow_dispatch"' \
     "$m1_three_created"

   m1_assert_lane
   m1_heavy_since=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
   gh workflow run full-check.yaml --repo itchyshin/gllvmTMB \
     --ref "$m1_final_branch"
   m1_heavy_list="$m1_evidence_dir/state/manual-heavy-runs.json"
   m1_heavy_run_id=''
   for m1_poll in $(seq 1 60); do
     gh run list --repo itchyshin/gllvmTMB --workflow full-check.yaml \
       --branch "$m1_final_branch" --event workflow_dispatch --limit 30 \
       --json databaseId,createdAt,headSha,status,conclusion,event,headBranch,url \
       > "$m1_heavy_list"
     m1_heavy_count=$(jq -r --arg sha "$m1_final_sha" --arg branch "$m1_final_branch" \
       --arg since "$m1_heavy_since" \
       '[.[] | select(.headSha == $sha and .headBranch == $branch and .event == "workflow_dispatch" and .createdAt >= $since)] | length' \
       "$m1_heavy_list")
     case "$m1_heavy_count" in
       0) sleep 10 ;;
       1) m1_heavy_run_id=$(jq -r --arg sha "$m1_final_sha" --arg branch "$m1_final_branch" \
            --arg since "$m1_heavy_since" \
            '.[] | select(.headSha == $sha and .headBranch == $branch and .event == "workflow_dispatch" and .createdAt >= $since) | .databaseId' \
            "$m1_heavy_list"); break ;;
       *) exit 1 ;;
     esac
   done
   test -n "$m1_heavy_run_id"
   m1_heavy_created="$m1_evidence_dir/state/manual-heavy-${m1_heavy_run_id}-created.json"
   m1_heavy_terminal="$m1_evidence_dir/state/manual-heavy-${m1_heavy_run_id}-terminal.json"
   gh run view "$m1_heavy_run_id" --repo itchyshin/gllvmTMB \
     --json workflowName,headSha,status,conclusion,event,headBranch,url,jobs \
     > "$m1_heavy_created"
   jq -e --arg sha "$m1_final_sha" --arg branch "$m1_final_branch" \
     '.workflowName == "full-check" and .headSha == $sha and .headBranch == $branch and .event == "workflow_dispatch"' \
     "$m1_heavy_created"

   m1_three_watch_status=0
   gh run watch "$m1_three_run_id" --repo itchyshin/gllvmTMB --exit-status --interval 60 \
     || m1_three_watch_status=$?
   m1_heavy_watch_status=0
   gh run watch "$m1_heavy_run_id" --repo itchyshin/gllvmTMB --exit-status --interval 60 \
     || m1_heavy_watch_status=$?
   gh run view "$m1_three_run_id" --repo itchyshin/gllvmTMB \
     --json workflowName,headSha,status,conclusion,event,headBranch,url,jobs \
     > "$m1_three_terminal"
   gh run view "$m1_heavy_run_id" --repo itchyshin/gllvmTMB \
     --json workflowName,headSha,status,conclusion,event,headBranch,url,jobs \
     > "$m1_heavy_terminal"
   m1_capture_run_logs "$m1_three_run_id" "$m1_three_terminal"
   m1_capture_run_logs "$m1_heavy_run_id" "$m1_heavy_terminal"

   m1_three_ubuntu_job=$(jq -r '[.jobs[] | select(.name == "ubuntu-latest (release)")] | if length == 1 then .[0].databaseId else empty end' "$m1_three_terminal")
   m1_three_macos_job=$(jq -r '[.jobs[] | select(.name == "macos-latest (release)")] | if length == 1 then .[0].databaseId else empty end' "$m1_three_terminal")
   m1_three_windows_job=$(jq -r '[.jobs[] | select(.name == "windows-latest (release)")] | if length == 1 then .[0].databaseId else empty end' "$m1_three_terminal")
   m1_heavy_ubuntu_job=$(jq -r '[.jobs[] | select(.name == "ubuntu-latest (release)")] | if length == 1 then .[0].databaseId else empty end' "$m1_heavy_terminal")
   test -n "$m1_three_ubuntu_job"
   test -n "$m1_three_macos_job"
   test -n "$m1_three_windows_job"
   test -n "$m1_heavy_ubuntu_job"
   m1_record_check_denominator "$m1_three_run_id" "$m1_three_ubuntu_job"
   m1_record_check_denominator "$m1_three_run_id" "$m1_three_macos_job"
   m1_record_check_denominator "$m1_three_run_id" "$m1_three_windows_job"
   m1_record_check_denominator "$m1_heavy_run_id" "$m1_heavy_ubuntu_job"

   jq -e --arg sha "$m1_final_sha" --arg branch "$m1_final_branch" '
     def check_step_ok:
       ([.steps[] | select(.name == "Run r-lib/actions/check-r-package@v2" and .status == "completed" and .conclusion == "success")] | length) == 1;
     def fast_pass_skipped:
       ([.steps[] | select(.name == "Fast pass for ignored-source/process change" and .status == "completed" and .conclusion == "skipped")] | length) == 1;
     .workflowName == "R-CMD-check" and
     .headSha == $sha and .headBranch == $branch and
     .event == "workflow_dispatch" and .status == "completed" and .conclusion == "success" and
     (.jobs | length) == 3 and
     ([.jobs[].name] | sort) == ["macos-latest (release)", "ubuntu-latest (release)", "windows-latest (release)"] and
     all(.jobs[]; .status == "completed" and .conclusion == "success" and check_step_ok and fast_pass_skipped)
   ' "$m1_three_terminal"
   jq -e --arg sha "$m1_final_sha" --arg branch "$m1_final_branch" '
     def check_step_ok:
       ([.steps[] | select(.name == "Run r-lib/actions/check-r-package@v2" and .status == "completed" and .conclusion == "success")] | length) == 1;
     .workflowName == "full-check" and
     .headSha == $sha and .headBranch == $branch and
     .event == "workflow_dispatch" and .status == "completed" and .conclusion == "success" and
     (.jobs | length) == 2 and
     ([.jobs[].name] | sort) == ["matrix-setup", "ubuntu-latest (release)"] and
     ([.jobs[] | select(.name == "matrix-setup" and .status == "completed" and .conclusion == "success")] | length) == 1 and
     ([.jobs[] | select(.name == "ubuntu-latest (release)" and .status == "completed" and .conclusion == "success" and check_step_ok)] | length) == 1
   ' "$m1_heavy_terminal"
   test "$m1_three_watch_status" -eq 0
   test "$m1_heavy_watch_status" -eq 0
   m1_require_successful_check_log "$m1_three_run_id" "$m1_three_ubuntu_job"
   m1_require_successful_check_log "$m1_three_run_id" "$m1_three_macos_job"
   m1_require_successful_check_log "$m1_three_run_id" "$m1_three_windows_job"
   m1_require_successful_check_log "$m1_heavy_run_id" "$m1_heavy_ubuntu_job"

   gh run list --repo itchyshin/gllvmTMB --workflow R-CMD-check.yaml \
     --branch "$m1_final_branch" --event workflow_dispatch --limit 30 \
     --json databaseId,createdAt,headSha,status,conclusion,event,headBranch,url \
     > "$m1_evidence_dir/state/manual-three-os-terminal-candidates.json"
   jq -e --arg sha "$m1_final_sha" --arg branch "$m1_final_branch" \
     --arg since "$m1_three_since" --argjson run "$m1_three_run_id" \
     '[.[] | select(.headSha == $sha and .headBranch == $branch and .event == "workflow_dispatch" and .createdAt >= $since) | .databaseId] == [$run]' \
     "$m1_evidence_dir/state/manual-three-os-terminal-candidates.json"
   gh run list --repo itchyshin/gllvmTMB --workflow full-check.yaml \
     --branch "$m1_final_branch" --event workflow_dispatch --limit 30 \
     --json databaseId,createdAt,headSha,status,conclusion,event,headBranch,url \
     > "$m1_evidence_dir/state/manual-heavy-terminal-candidates.json"
   jq -e --arg sha "$m1_final_sha" --arg branch "$m1_final_branch" \
     --arg since "$m1_heavy_since" --argjson run "$m1_heavy_run_id" \
     '[.[] | select(.headSha == $sha and .headBranch == $branch and .event == "workflow_dispatch" and .createdAt >= $since) | .databaseId] == [$run]' \
     "$m1_evidence_dir/state/manual-heavy-terminal-candidates.json"
   m1_assert_lane
   ```

7. Record terminal final-head URLs in PR #778 and Mission Control without
   another package-repository edit.
8. Obtain three fresh independent NOT-DONE-default D-43 reviews. Two
   NOT-DONE verdicts withhold M1 closure; any genuine load-bearing defect must
   be fixed regardless of vote count.

## Next safest action

Validate and independently review this three-file receipt, commit it locally,
and begin serial exact-head local qualification before any push. Do not edit
package source, tests, or any parked checkout.

## Blocking authority boundary

None for M1 closeout. Separate maintainer authority remains required before
Design 86, Totoro/DRAC scientific compute, public EVA admission, candidate
freeze, RC/final tags, CRAN submission, or any release/readiness claim. Design
85 remains NO-GO and Laplace remains the automatic 0.6 fallback.
