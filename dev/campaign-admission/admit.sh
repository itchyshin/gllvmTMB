#!/usr/bin/env bash
# Design 66 / D-50 compute-admission gate — campaign-agnostic.
#
# Freezes a campaign's source, runner script, and destination convention
# BEFORE any fit is launched, so a claim-bearing capstone campaign never
# starts against a dirty tree, an unpinned commit, an overwritten result
# directory, or a runner that skips the smoke/canary ladder. This tool
# does not run any fit and does not touch Totoro/DRAC — it only decides
# whether a campaign is ADMITTED to start the smoke ladder
# (see smoke-ladder.md) and records the manifest that makes the eventual
# results reproducible and auditable.
#
# Modelled on dev/coxreid-ab/launch-ab.sh's defensive style (dry-run
# default, explicit refusal messages, --self-test), generalised to any
# campaign/runner/source triple instead of one hardcoded campaign.
#
# Usage:
#   dev/campaign-admission/admit.sh --campaign <name> --script <runner.R> --src <pkg-src-dir>
#   dev/campaign-admission/admit.sh --self-test
#
# Env:
#   CAMPAIGN_ADMISSION_DEST_ROOT   override the immutable-destination root
#                                  (default: $HOME/gllvm_work/campaigns).
#                                  Used by --self-test and the dry-run
#                                  admission below to avoid touching the
#                                  real campaigns directory.
#
# What "ADMITTED" freezes, written to <dest>/MANIFEST.txt:
#   - campaign id            = <name>-<UTC date>-<short commit>
#   - pinned commit           (full + short SHA, HEAD of --src)
#   - R/ and src/ cleanliness (git status --porcelain; refuses if dirty)
#   - runner script checksum  (sha256; a frozen COPY is stored alongside)
#   - source archive checksum (sha256; a frozen COPY is stored alongside,
#                               `git archive` of DESCRIPTION/NAMESPACE/R/src
#                               at the pinned commit -- untracked/dirty
#                               files can never leak into the archive)
#   - destination convention  (~/gllvm_work/campaigns/<campaign-id>/,
#                               refuses if it already exists non-empty --
#                               a rerun needs a NEW campaign id, per the
#                               no-automatic-retries policy in
#                               RESULT-SCHEMA.md)
#   - the SMOKE/CANARY contract check on the runner script
#
# What this tool does NOT do (see docs/design/124-campaign-admission.md
# section "What this slice does NOT do"): it does not schedule, launch,
# or drive fits; it does not validate the runner's DGP, formula, or
# result columns beyond the mode-contract grep; it is not a DRAC array
# driver.

set -euo pipefail

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

CAMPAIGN=""
RUNNER=""
SRC=""
SELF_TEST=0
DEST_ROOT="${CAMPAIGN_ADMISSION_DEST_ROOT:-$HOME/gllvm_work/campaigns}"

usage() {
  sed -n '2,45p' "$SCRIPT_PATH"
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --campaign) CAMPAIGN="${2:?--campaign needs a name}"; shift 2 ;;
    --campaign=*) CAMPAIGN="${1#--campaign=}"; shift ;;
    --script) RUNNER="${2:?--script needs a runner path}"; shift 2 ;;
    --script=*) RUNNER="${1#--script=}"; shift ;;
    --src) SRC="${2:?--src needs a package source dir}"; shift 2 ;;
    --src=*) SRC="${1#--src=}"; shift ;;
    --dest-root) DEST_ROOT="${2:?--dest-root needs a dir}"; shift 2 ;;
    --dest-root=*) DEST_ROOT="${1#--dest-root=}"; shift ;;
    --self-test) SELF_TEST=1; shift ;;
    -h|--help) usage 0 ;;
    *) echo "unknown argument: $1" >&2; usage 2 ;;
  esac
done

sha256_of() {
  local f="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$f" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$f" | awk '{print $1}'
  else
    echo "no sha256 tool (sha256sum/shasum) found on PATH" >&2
    return 1
  fi
}

# refuse MSG: print a refusal to stderr and exit 2. Every admission failure
# goes through this so the verdict is always loud and the exit code is
# always non-zero.
refuse() {
  echo "REFUSED: $1" >&2
  exit 2
}

admit() {
  [[ -n "$CAMPAIGN" ]] || refuse "--campaign is required"
  [[ "$CAMPAIGN" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]] || \
    refuse "--campaign must be alnum/dash/underscore, got: $CAMPAIGN"
  [[ -n "$RUNNER" ]] || refuse "--script is required"
  [[ -f "$RUNNER" ]] || refuse "runner script not found: $RUNNER"
  [[ -n "$SRC" ]] || refuse "--src is required"
  [[ -d "$SRC" ]] || refuse "--src is not a directory: $SRC"
  git -C "$SRC" rev-parse --git-dir >/dev/null 2>&1 || \
    refuse "--src is not a git repository: $SRC"

  # (a) pinned commit + R/ src/ cleanliness -----------------------------
  local commit commit_short dirty_report=""
  commit="$(git -C "$SRC" rev-parse HEAD)"
  commit_short="$(git -C "$SRC" rev-parse --short HEAD)"

  local check_paths=()
  [[ -e "$SRC/R" ]] && check_paths+=("R/")
  [[ -e "$SRC/src" ]] && check_paths+=("src/")
  if [[ ${#check_paths[@]} -gt 0 ]]; then
    dirty_report="$(git -C "$SRC" status --porcelain -- "${check_paths[@]}")"
    if [[ -n "$dirty_report" ]]; then
      refuse "R/ and/or src/ are dirty in $SRC -- commit or stash before admission:
$dirty_report"
    fi
  fi

  # (b) campaign id + checksums of runner + source archive --------------
  local campaign_id dest
  campaign_id="${CAMPAIGN}-$(date -u +%Y%m%d)-${commit_short}"
  dest="$DEST_ROOT/$campaign_id"

  # (c) immutable destination -- refuse before creating anything --------
  if [[ -d "$dest" ]] && [[ -n "$(ls -A "$dest" 2>/dev/null)" ]]; then
    refuse "destination already exists and is non-empty: $dest
A rerun needs a NEW campaign id (retry policy: no automatic retries,
see RESULT-SCHEMA.md) -- change --campaign or wait for a new commit/date."
  fi

  local runner_sha
  runner_sha="$(sha256_of "$RUNNER")"

  local archive_paths=() p
  for p in DESCRIPTION NAMESPACE R src; do
    if git -C "$SRC" cat-file -e "HEAD:$p" 2>/dev/null; then
      archive_paths+=("$p")
    fi
  done
  [[ ${#archive_paths[@]} -gt 0 ]] || \
    refuse "none of DESCRIPTION/NAMESPACE/R/src exist at HEAD in $SRC -- nothing to archive"

  local tmp_tar
  tmp_tar="$(mktemp -t campaign-admission-src.XXXXXX.tar.gz)"
  git -C "$SRC" archive --format=tar.gz -o "$tmp_tar" HEAD -- "${archive_paths[@]}"
  local archive_sha
  archive_sha="$(sha256_of "$tmp_tar")"

  # (d) runner declares SMOKE and CANARY modes ---------------------------
  if ! grep -qi "smoke" "$RUNNER" || ! grep -qi "canary" "$RUNNER"; then
    rm -f "$tmp_tar"
    refuse "runner does not declare BOTH a SMOKE and a CANARY mode
(case-insensitive grep for 'smoke' and 'canary' in $RUNNER found nothing
for at least one of them) -- every capstone runner must support a
truncated single-fit smoke mode and a one-seed canary mode. See
dev/coxreid-ab/run-ab.R (GRID_SMOKE, AB_MODE=canary) for the pattern."
  fi

  # --- admitted: create destination and freeze everything ---
  mkdir -p "$dest"
  cp "$RUNNER" "$dest/runner.R"
  mv "$tmp_tar" "$dest/source-${commit_short}.tar.gz"

  cat > "$dest/MANIFEST.txt" <<EOF
# Campaign admission manifest -- generated by dev/campaign-admission/admit.sh
# Design 66 / D-50 compute-admission gate. Do not hand-edit; a manifest is
# the frozen record of what was admitted, not a place to patch afterwards.

campaign_id:        $campaign_id
campaign_name:      $CAMPAIGN
admitted_at_utc:    $(date -u +%Y-%m-%dT%H:%M:%SZ)

source_dir:         $(cd "$SRC" && pwd)
commit:             $commit
commit_short:       $commit_short
r_src_clean:        $([[ ${#check_paths[@]} -gt 0 ]] && echo "TRUE (checked: ${check_paths[*]})" || echo "N/A (no R/ or src/ found)")

runner_script:      $RUNNER
runner_sha256:      $runner_sha
runner_frozen_copy: $dest/runner.R

source_archive_paths: ${archive_paths[*]}
source_archive_sha256: $archive_sha
source_archive_frozen: $dest/source-${commit_short}.tar.gz

destination:        $dest
retry_policy:        no automatic retries; a failed row is a row; a rerun
                      of this campaign gets a NEW campaign id (see
                      RESULT-SCHEMA.md)

verdict:            ADMITTED
EOF

  echo "ADMITTED: $campaign_id"
  echo "  manifest:   $dest/MANIFEST.txt"
  echo "  runner:     $dest/runner.R  (sha256 $runner_sha)"
  echo "  source:     $dest/source-${commit_short}.tar.gz  (sha256 $archive_sha)"
  echo
  echo "Smoke ladder (see dev/campaign-admission/smoke-ladder.md for PASS criteria):"
  echo "  rung 1 (local, 1 fit):"
  echo "    Rscript --vanilla $dest/runner.R   # with this runner's smoke env var set TRUE"
  echo "  rung 2 (Totoro canary, 1 seed x all cell-arms), inspected for non-empty/finite:"
  echo "    <this campaign's launcher> --mode=canary --launch   # canary env var set"
  echo "  rung 3 (one bounded full chunk -- one cell, all seeds):"
  echo "    <this campaign's launcher> --mode=full --chunk=<one-cell-id> --launch"
  echo "  full campaign only after rung 3 PASS + maintainer D-139 go."
}

# ---------------------------------------------------------------------------
# --self-test: builds a throwaway git repo + runner fixture under mktemp,
# exercises every refusal path, and cleans up after itself. Never touches
# $HOME/gllvm_work.
# ---------------------------------------------------------------------------
self_test() {
  local fail=0
  local work
  work="$(mktemp -d -t campaign-admission-selftest.XXXXXX)"
  local fixture_src="$work/pkgsrc"
  local fixture_dest_root="$work/campaigns"
  local fixture_runner="$work/runner.R"

  mkdir -p "$fixture_src/R" "$fixture_src/src"
  echo "Package: fixture" > "$fixture_src/DESCRIPTION"
  echo "export(foo)" > "$fixture_src/NAMESPACE"
  echo "foo <- function() 1" > "$fixture_src/R/foo.R"
  echo "// c stub" > "$fixture_src/src/foo.c"
  git -C "$fixture_src" init -q
  git -C "$fixture_src" -c user.email=t@t -c user.name=t add -A
  git -C "$fixture_src" -c user.email=t@t -c user.name=t commit -q -m "fixture"

  cat > "$fixture_runner" <<'EOF'
## GRID_SMOKE truncates to 1 fit. AB_MODE canary|full.
EOF

  # 1. clean admission should pass. (Captured into a var, not piped
  #    straight into grep -q -- grep closing early on a pipe would send
  #    SIGPIPE to admit.sh's later echo calls, and under set -e that
  #    non-zero exit becomes the pipeline's status under pipefail even
  #    though grep itself matched.)
  local out
  out="$("$SCRIPT_PATH" --campaign selftest --script "$fixture_runner" \
      --src "$fixture_src" --dest-root "$fixture_dest_root")"
  if ! printf '%s\n' "$out" | grep -q "^ADMITTED:"; then
    echo "self-test: clean admission should have been ADMITTED"; fail=1
  fi

  # 2. re-running the SAME campaign against the SAME commit must refuse
  #    (destination already non-empty).
  if "$SCRIPT_PATH" --campaign selftest --script "$fixture_runner" \
      --src "$fixture_src" --dest-root "$fixture_dest_root" >/dev/null 2>&1; then
    echo "self-test: re-admission onto a non-empty destination should have been refused"
    fail=1
  fi

  # 3. dirty R/ must refuse.
  echo "bar <- function() 2" >> "$fixture_src/R/foo.R"
  if "$SCRIPT_PATH" --campaign selftest2 --script "$fixture_runner" \
      --src "$fixture_src" --dest-root "$fixture_dest_root" >/dev/null 2>&1; then
    echo "self-test: dirty R/ should have been refused"
    fail=1
  fi
  git -C "$fixture_src" -c user.email=t@t -c user.name=t checkout -q -- R/foo.R

  # 4. runner missing the smoke/canary contract must refuse.
  local bad_runner="$work/runner-bad.R"
  echo "## no mode contract here" > "$bad_runner"
  if "$SCRIPT_PATH" --campaign selftest3 --script "$bad_runner" \
      --src "$fixture_src" --dest-root "$fixture_dest_root" >/dev/null 2>&1; then
    echo "self-test: runner without SMOKE/CANARY contract should have been refused"
    fail=1
  fi

  # 5. missing --campaign must refuse.
  if "$SCRIPT_PATH" --script "$fixture_runner" --src "$fixture_src" \
      --dest-root "$fixture_dest_root" >/dev/null 2>&1; then
    echo "self-test: missing --campaign should have been refused"
    fail=1
  fi

  # 6. manifest content sanity: sha256 of the frozen runner copy must match
  #    the sha256 of the original fixture runner.
  local orig_sha copy_sha admitted_dir
  admitted_dir="$(find "$fixture_dest_root" -maxdepth 1 -name 'selftest-*' | head -1)"
  if [[ -z "$admitted_dir" ]]; then
    echo "self-test: could not locate the admitted campaign dir"
    fail=1
  else
    orig_sha="$(sha256_of "$fixture_runner")"
    copy_sha="$(sha256_of "$admitted_dir/runner.R")"
    if [[ "$orig_sha" != "$copy_sha" ]]; then
      echo "self-test: frozen runner copy checksum mismatch"
      fail=1
    fi
    grep -q "verdict:            ADMITTED" "$admitted_dir/MANIFEST.txt" || {
      echo "self-test: MANIFEST.txt missing ADMITTED verdict line"
      fail=1
    }
  fi

  rm -rf "$work"

  if [[ $fail -ne 0 ]]; then
    echo "self-test FAIL"
    exit 1
  fi
  echo "self-test PASS (admission, dupe-destination refusal, dirty-tree refusal, missing-contract refusal, missing-arg refusal, manifest checksum integrity)"
}

if [[ "$SELF_TEST" == 1 ]]; then
  self_test
  exit 0
fi

admit
