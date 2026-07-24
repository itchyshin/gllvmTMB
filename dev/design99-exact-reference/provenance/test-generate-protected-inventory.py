#!/usr/bin/env python3
"""Regression checks for Design-99 provenance lineage handling.

Run directly from any checkout.  The integration check deliberately invokes
only compare mode: it must not create or replace lifecycle receipts.
"""

from __future__ import annotations

import hashlib
import importlib.util
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch


HERE = Path(__file__).resolve().parent
GENERATOR = HERE / "generate-protected-inventory.py"


def load_generator():
    module_spec = importlib.util.spec_from_file_location("design99_inventory", GENERATOR)
    assert module_spec is not None and module_spec.loader is not None
    module = importlib.util.module_from_spec(module_spec)
    module_spec.loader.exec_module(module)
    return module


class LineageTests(unittest.TestCase):
    def setUp(self) -> None:
        self.module = load_generator()
        self.spec = {
            "baseline_commit": "baseline",
            "expected_branch": "codex/design99-exact-reference-20260724",
        }

    def test_compare_accepts_descendant_on_expected_branch(self) -> None:
        with patch.object(self.module, "git", return_value=self.spec["expected_branch"] + "\n"), patch.object(
            self.module, "is_ancestor", return_value=True
        ):
            branch = self.module.verify_head_context(self.spec, "compare", "descendant")
        self.assertEqual(branch, self.spec["expected_branch"])

    def test_compare_rejects_wrong_branch(self) -> None:
        with patch.object(self.module, "git", return_value="other-branch\n"):
            with self.assertRaisesRegex(SystemExit, "branch mismatch"):
                self.module.verify_head_context(self.spec, "compare", "descendant")

    def test_compare_rejects_non_descendant(self) -> None:
        with patch.object(self.module, "git", return_value=self.spec["expected_branch"] + "\n"), patch.object(
            self.module, "is_ancestor", return_value=False
        ):
            with self.assertRaisesRegex(SystemExit, "not an ancestor"):
                self.module.verify_head_context(self.spec, "compare", "unrelated")


class CurrentCheckoutIntegrationTests(unittest.TestCase):
    def test_compare_lane_at_current_head_is_read_only(self) -> None:
        receipt_paths = [
            HERE / "baseline-protected-inventory.tsv",
            HERE / "baseline-protected-inventory-summary.json",
            HERE / "prelock-protected-inventory.tsv",
            HERE / "prelock-protected-inventory-summary.json",
            HERE / "final-protected-inventory.tsv",
            HERE / "final-protected-inventory-summary.json",
        ]
        before = {
            path: hashlib.sha256(path.read_bytes()).hexdigest()
            for path in receipt_paths if path.exists()
        }
        result = subprocess.run(
            [sys.executable, str(GENERATOR), "compare", "--scope", "lane"],
            cwd=HERE.parents[2],
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        self.assertEqual(result.returncode, 0, msg=result.stdout + result.stderr)
        self.assertIn('"current_head": "e340d3d3ee0f1666312f318e2a2d00b405fe0e59"', result.stdout)
        after = {
            path: hashlib.sha256(path.read_bytes()).hexdigest()
            for path in receipt_paths if path.exists()
        }
        self.assertEqual(after, before)
        self.assertFalse((HERE / "prelock-protected-inventory.tsv").exists())
        self.assertFalse((HERE / "final-protected-inventory.tsv").exists())


if __name__ == "__main__":
    unittest.main()
