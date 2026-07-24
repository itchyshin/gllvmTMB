#!/usr/bin/env python3
"""Fail closed on Design-98 dependencies or new C/C++ in Design-99 runtime files."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import subprocess


HERE = Path(__file__).resolve().parent
SPEC_PATH = HERE / "protected-paths.json"
C_CPP_SUFFIXES = {".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp", ".hxx"}
SOURCE_SUFFIXES = {
    ".r", ".py", ".sh", ".bash", ".zsh", ".json", ".yaml", ".yml",
    ".toml", ".ini", ".cfg",
}


def git(*args: str) -> str:
    return subprocess.run(
        ["git", *args],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    ).stdout


def dirty_paths(allowed: list[str]) -> list[str]:
    outside: list[str] = []
    for line in git("status", "--porcelain=v1", "--untracked-files=all").splitlines():
        path = line[3:].split(" -> ", 1)[-1]
        if not any(
            path == prefix.rstrip("/")
            or (prefix.endswith("/") and path.startswith(prefix))
            for prefix in allowed
        ):
            outside.append(path)
    return sorted(outside)


def is_runtime_candidate(relative: Path) -> bool:
    lowered_parts = {part.lower() for part in relative.parts}
    lowered_name = relative.name.lower()
    return (
        relative.suffix.lower() in SOURCE_SUFFIXES
        or bool(lowered_parts & {"input", "inputs", "manifest", "manifests"})
        or "input" in lowered_name
        or "manifest" in lowered_name
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--scope", choices=("producer", "lane"), required=True)
    args = parser.parse_args()

    spec = json.loads(SPEC_PATH.read_text(encoding="utf-8"))
    root = Path(git("rev-parse", "--show-toplevel").strip())
    allowlist_key = (
        "current_task_write_allowlist"
        if args.scope == "producer"
        else "complete_lane_allowlist"
    )
    outside = dirty_paths([str(path) for path in spec[allowlist_key]])
    if outside:
        raise SystemExit(
            f"dirty paths outside {args.scope} allowlist: " + ", ".join(outside)
        )

    runtime_root = root / str(spec["design99_runtime_root"])
    findings: list[dict[str, object]] = []
    scanned: list[str] = []
    if runtime_root.exists():
        for path in sorted(runtime_root.rglob("*")):
            relative = path.relative_to(runtime_root)
            if relative.parts and relative.parts[0] == "provenance":
                continue
            repo_relative = path.relative_to(root).as_posix()
            if path.is_symlink():
                findings.append({
                    "path": repo_relative,
                    "rule": "runtime_symlink_forbidden",
                    "target": os.readlink(path),
                })
                continue
            if not path.is_file():
                continue
            if path.suffix.lower() in C_CPP_SUFFIXES:
                findings.append({
                    "path": repo_relative,
                    "rule": "new_c_cpp_source_forbidden",
                })
                continue
            if not is_runtime_candidate(relative):
                continue
            scanned.append(repo_relative)
            try:
                text = path.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                findings.append({
                    "path": repo_relative,
                    "rule": "runtime_candidate_not_utf8_text",
                })
                continue
            checks = (
                (
                    "design98_tree_reference",
                    re.compile(r"dev[/\\\\]design98-factorial-va-jj", re.I),
                ),
                (
                    "design98_uuid_reference",
                    re.compile(re.escape(str(spec["design98_real_uuid"])), re.I),
                ),
                (
                    "design98_results_reference",
                    re.compile(
                        r"design98-factorial-va-jj[/\\\\]results(?:[/\\\\]|\b)",
                        re.I,
                    ),
                ),
                (
                    "design98_dynamic_load_reference",
                    re.compile(
                        r"\b(?:source|sys\.source|dyn\.load)\s*\("
                        r"[\s\S]{0,2048}?(?:design\s*[-_]?98|design98)",
                        re.I,
                    ),
                ),
            )
            for rule, pattern in checks:
                match = pattern.search(text)
                if match:
                    findings.append({
                        "path": repo_relative,
                        "rule": rule,
                        "offset": match.start(),
                    })

    report = {
        "schema_version": 1,
        "design": 99,
        "scope": args.scope,
        "runtime_root": str(spec["design99_runtime_root"]),
        "excluded_root": f"{spec['design99_runtime_root']}/provenance/",
        "scanned_files": scanned,
        "findings": findings,
        "passed": not findings,
    }
    print(json.dumps(report, indent=2, sort_keys=True))
    if findings:
        raise SystemExit(1)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
