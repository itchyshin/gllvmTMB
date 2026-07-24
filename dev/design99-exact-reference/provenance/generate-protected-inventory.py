#!/usr/bin/env python3
"""Create or compare Design-99 predecessor inventories without overwriting evidence.

The script reads files and Git objects only. It never imports or executes
Design-98 code. Baseline, prelock, and final receipts are exclusive-create;
compare mode writes nothing. Every non-baseline mode checks the current
inventory against the immutable digest pinned in protected-paths.json.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
from typing import NoReturn


HERE = Path(__file__).resolve().parent
SPEC_PATH = HERE / "protected-paths.json"
FIELDNAMES = [
    "group", "source", "path", "kind", "bytes",
    "sha256", "git_blob", "status",
]


def fail(message: str) -> NoReturn:
    raise SystemExit(message)


def git(*args: str, binary: bool = False) -> str | bytes:
    result = subprocess.run(
        ["git", *args],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return result.stdout if binary else result.stdout.decode("utf-8")


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def worktree_files(root: Path, declared: str) -> list[Path]:
    target = root / declared
    if not target.exists() and not target.is_symlink():
        return []
    if target.is_file() or target.is_symlink():
        return [target]
    return sorted(
        path for path in target.rglob("*")
        if path.is_file() or path.is_symlink()
    )


def worktree_row(root: Path, group: str, path: Path) -> dict[str, object]:
    relative = path.relative_to(root).as_posix()
    if path.is_symlink():
        data = os.readlink(path).encode("utf-8")
        kind = "symlink"
    else:
        data = path.read_bytes()
        kind = "file"
    blob = git("hash-object", "--", relative).strip()
    return {
        "group": group,
        "source": "worktree",
        "path": relative,
        "kind": kind,
        "bytes": len(data),
        "sha256": sha256(data),
        "git_blob": blob,
        "status": "present",
    }


def git_tree_rows(group: dict[str, object]) -> list[dict[str, object]]:
    commit = str(group["commit"])
    paths = [str(path) for path in group["paths"]]
    raw = git(
        "ls-tree", "-r", "-z", "--full-tree", commit, "--", *paths,
        binary=True,
    )
    assert isinstance(raw, bytes)
    rows: list[dict[str, object]] = []
    for entry in raw.split(b"\0"):
        if not entry:
            continue
        metadata, encoded_path = entry.split(b"\t", 1)
        mode, kind, blob = metadata.decode("ascii").split()
        path = encoded_path.decode("utf-8")
        data = git("show", f"{commit}:{path}", binary=True)
        assert isinstance(data, bytes)
        rows.append({
            "group": str(group["name"]),
            "source": f"git:{commit}",
            "path": path,
            "kind": f"{kind}:{mode}",
            "bytes": len(data),
            "sha256": sha256(data),
            "git_blob": blob,
            "status": "present",
        })
    return rows


def dirty_paths(allowed: list[str]) -> list[str]:
    outside: list[str] = []
    status = git("status", "--porcelain=v1", "--untracked-files=all")
    assert isinstance(status, str)
    for line in status.splitlines():
        path = line[3:]
        if " -> " in path:
            path = path.split(" -> ", 1)[1]
        if not any(
            path == prefix.rstrip("/")
            or (prefix.endswith("/") and path.startswith(prefix))
            for prefix in allowed
        ):
            outside.append(path)
    return sorted(outside)


def verify_allowlist(spec: dict[str, object], scope: str) -> list[str]:
    key = (
        "current_task_write_allowlist"
        if scope == "producer"
        else "complete_lane_allowlist"
    )
    allowed = [str(path) for path in spec[key]]
    outside = dirty_paths(allowed)
    if outside:
        fail(
            f"dirty paths outside {scope} allowlist: " + ", ".join(outside)
        )
    return outside


def verify_check_log_prefix(root: Path, spec: dict[str, object]) -> dict[str, object]:
    guard = spec["design98_check_log_prefix"]
    assert isinstance(guard, dict)
    path = str(guard["path"])
    commit = str(guard["commit"])
    expected_bytes = int(guard["bytes"])
    expected_sha = str(guard["sha256"])
    expected_blob = str(guard["git_blob"])

    baseline = git("show", f"{commit}:{path}", binary=True)
    assert isinstance(baseline, bytes)
    if len(baseline) != expected_bytes:
        fail(f"pinned check-log byte count mismatch: {len(baseline)}")
    if sha256(baseline) != expected_sha:
        fail("pinned check-log SHA-256 mismatch")
    blob = git("rev-parse", f"{commit}:{path}").strip()
    if blob != expected_blob:
        fail(f"pinned check-log Git blob mismatch: {blob}")

    current = (root / path).read_bytes()
    if len(current) < expected_bytes or current[:expected_bytes] != baseline:
        fail("Design-98 check-log prefix changed; append-only protection failed")
    return {
        "path": path,
        "protected_prefix_bytes": expected_bytes,
        "protected_prefix_sha256": expected_sha,
        "current_bytes": len(current),
        "append_only_prefix_intact": True,
    }


def collect_rows(
    root: Path, spec: dict[str, object]
) -> tuple[list[dict[str, object]], list[dict[str, str]]]:
    rows: list[dict[str, object]] = []
    missing: list[dict[str, str]] = []
    for group in spec["groups"]:
        if group["mode"] == "git_tree":
            historical = git_tree_rows(group)
            if not historical:
                missing.append({
                    "group": str(group["name"]),
                    "path": " | ".join(str(path) for path in group["paths"]),
                })
            rows.extend(historical)
            continue
        for declared in group["paths"]:
            files = worktree_files(root, str(declared))
            if not files:
                missing.append({
                    "group": str(group["name"]),
                    "path": str(declared),
                })
                continue
            rows.extend(
                worktree_row(root, str(group["name"]), path) for path in files
            )
    rows.sort(key=lambda row: (str(row["group"]), str(row["path"])))
    return rows, missing


def canonical_inventory(rows: list[dict[str, object]]) -> bytes:
    return (
        "\n".join(
            "\t".join(str(row[name]) for name in FIELDNAMES) for row in rows
        )
        .encode("utf-8")
    )


def baseline_tsv_digest(path: Path) -> str:
    with path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    return sha256(canonical_inventory(rows))


def verify_frozen_baseline(spec: dict[str, object]) -> str:
    expected = str(spec["expected_baseline_inventory_sha256"])
    receipt_names = spec["receipt_files"]
    assert isinstance(receipt_names, dict)
    baseline = receipt_names["baseline"]
    assert isinstance(baseline, dict)
    tsv_path = HERE / str(baseline["inventory"])
    summary_path = HERE / str(baseline["summary"])
    if not tsv_path.is_file() or not summary_path.is_file():
        fail("immutable baseline receipt is missing")
    if sha256(tsv_path.read_bytes()) != baseline["inventory_file_sha256"]:
        fail("baseline TSV file SHA-256 differs from its pinned receipt hash")
    if sha256(summary_path.read_bytes()) != baseline["summary_file_sha256"]:
        fail("baseline summary file SHA-256 differs from its pinned receipt hash")
    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    if summary.get("inventory_sha256") != expected:
        fail("baseline summary does not contain the pinned inventory digest")
    if baseline_tsv_digest(tsv_path) != expected:
        fail("baseline TSV does not reproduce the pinned inventory digest")
    return expected


def exclusive_write(path: Path, data: bytes) -> None:
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
    descriptor = os.open(path, flags, 0o644)
    try:
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(data)
    except BaseException:
        try:
            path.unlink()
        except FileNotFoundError:
            pass
        raise


def tsv_bytes(rows: list[dict[str, object]]) -> bytes:
    import io

    buffer = io.StringIO(newline="")
    writer = csv.DictWriter(buffer, fieldnames=FIELDNAMES, delimiter="\t")
    writer.writeheader()
    writer.writerows(rows)
    return buffer.getvalue().encode("utf-8")


def make_summary(
    spec: dict[str, object],
    head: str,
    mode: str,
    scope: str,
    rows: list[dict[str, object]],
    inventory_digest: str,
    check_log: dict[str, object],
) -> dict[str, object]:
    counts: dict[str, int] = {}
    byte_counts: dict[str, int] = {}
    for row in rows:
        group = str(row["group"])
        counts[group] = counts.get(group, 0) + 1
        byte_counts[group] = byte_counts.get(group, 0) + int(row["bytes"])
    return {
        "schema_version": 2,
        "design": 99,
        "receipt_mode": mode,
        "allowlist_scope": scope,
        "baseline_commit": head,
        "branch": git("branch", "--show-current").strip(),
        "manifest_sha256": sha256(SPEC_PATH.read_bytes()),
        "expected_baseline_inventory_sha256": spec[
            "expected_baseline_inventory_sha256"
        ],
        "inventory_sha256": inventory_digest,
        "inventory_matches_expected_baseline": (
            inventory_digest == spec["expected_baseline_inventory_sha256"]
        ),
        "row_count": len(rows),
        "counts_by_group": counts,
        "bytes_by_group": byte_counts,
        "missing_declared_paths": [],
        "dirty_paths_outside_selected_allowlist": [],
        "design98_real_uuid": spec["design98_real_uuid"],
        "design98_execution": "not sourced; not executed",
        "design98_check_log_prefix": check_log,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "mode",
        choices=("baseline", "prelock", "final", "compare"),
        help="baseline/prelock/final create distinct receipts; compare writes none",
    )
    parser.add_argument(
        "--scope",
        choices=("producer", "lane"),
        required=True,
        help="select current-task or complete-lane dirty-path allowlist",
    )
    return parser.parse_args()


def verify_mode_scope(mode: str, scope: str) -> None:
    required = {"baseline": "producer", "prelock": "lane", "final": "lane"}
    if mode in required and scope != required[mode]:
        fail(f"{mode} mode requires --scope {required[mode]}")


def run_runtime_scan(scope: str) -> dict[str, object]:
    scanner = HERE / "scan-design99-runtime.py"
    result = subprocess.run(
        [sys.executable, str(scanner), "--scope", scope],
        cwd=Path(git("rev-parse", "--show-toplevel").strip()),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    if result.returncode != 0:
        fail(
            "Design-99 runtime scan failed:\n"
            + result.stdout
            + result.stderr
        )
    return json.loads(result.stdout)


def main() -> int:
    args = parse_args()
    verify_mode_scope(args.mode, args.scope)
    spec = json.loads(SPEC_PATH.read_text(encoding="utf-8"))
    root = Path(git("rev-parse", "--show-toplevel").strip())
    head = git("rev-parse", "HEAD").strip()
    if head != spec["baseline_commit"]:
        fail(f"baseline mismatch: expected {spec['baseline_commit']}, found {head}")

    verify_allowlist(spec, args.scope)
    runtime_scan = (
        run_runtime_scan(args.scope)
        if args.mode in {"prelock", "final"}
        else None
    )
    receipt_names = spec["receipt_files"]
    assert isinstance(receipt_names, dict)
    output_paths: tuple[Path, Path] | None = None
    if args.mode != "compare":
        names = receipt_names[args.mode]
        assert isinstance(names, dict)
        output_paths = (
            HERE / str(names["inventory"]),
            HERE / str(names["summary"]),
        )
        existing = [str(path) for path in output_paths if path.exists()]
        if existing:
            fail(
                f"{args.mode} receipt already exists; refusing overwrite: "
                + ", ".join(existing)
            )

    check_log = verify_check_log_prefix(root, spec)
    rows, missing = collect_rows(root, spec)
    if missing:
        fail("missing protected paths: " + json.dumps(missing, sort_keys=True))
    inventory_digest = sha256(canonical_inventory(rows))

    if args.mode == "baseline":
        expected = str(spec["expected_baseline_inventory_sha256"])
        if inventory_digest != expected:
            fail(
                f"new baseline digest {inventory_digest} differs from pinned {expected}"
            )
    else:
        expected = verify_frozen_baseline(spec)
        if inventory_digest != expected:
            fail(
                f"protected inventory mismatch: expected {expected}, "
                f"found {inventory_digest}"
            )

    summary = make_summary(
        spec, head, args.mode, args.scope, rows, inventory_digest, check_log
    )
    summary["runtime_scan"] = runtime_scan
    if output_paths is not None:
        exclusive_write(output_paths[0], tsv_bytes(rows))
        try:
            exclusive_write(
                output_paths[1],
                (json.dumps(summary, indent=2, sort_keys=True) + "\n")
                .encode("utf-8"),
            )
        except BaseException:
            output_paths[0].unlink()
            raise
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
