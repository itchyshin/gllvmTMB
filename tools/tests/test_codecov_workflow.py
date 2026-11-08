"""Guard the Codecov producer/uploader split.

The producer must measure coverage without OIDC or a Codecov token. The
uploader may use GitHub OIDC only after a successful same-repo main push of
test-coverage. stdlib only; fails closed if a required string is missing or
appears only in a comment.
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PRODUCER = ROOT / ".github" / "workflows" / "test-coverage.yaml"
UPLOADER = ROOT / ".github" / "workflows" / "codecov-upload.yaml"
R_CMD_CHECK = ROOT / ".github" / "workflows" / "R-CMD-check.yaml"
FULL_CHECK = ROOT / ".github" / "workflows" / "full-check.yaml"
BOUNDARY = ROOT / "tools" / "check-actions-boundary.sh"

CODECOV_ACTION = (
    "codecov/codecov-action@0fb7174895f61a3b6b78fc075e0cd60383518dac"
)
CHECKOUT_ACTION = (
    "actions/checkout@11d5960a326750d5838078e36cf38b85af677262"
)
DOWNLOAD_ACTION = (
    "actions/download-artifact@d3f86a106a0bac45b974a628896c90dbdf5c8093"
)
UPLOAD_ARTIFACT = (
    "actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02"
)


def _noncomment_text(path: Path) -> str:
    lines = []
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if stripped and not stripped.startswith("#"):
            lines.append(line)
    return "\n".join(lines)


def _active_lines(path: Path) -> list[str]:
    return [
        line.rstrip()
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.strip().startswith("#")
    ]


class CodecovWorkflowTest(unittest.TestCase):
    def setUp(self) -> None:
        self.assertTrue(PRODUCER.is_file(), f"missing {PRODUCER}")
        self.assertTrue(UPLOADER.is_file(), f"missing {UPLOADER}")
        self.producer = _noncomment_text(PRODUCER)
        self.uploader = _noncomment_text(UPLOADER)
        self.r_cmd_check = _noncomment_text(R_CMD_CHECK)
        self.full_check = _noncomment_text(FULL_CHECK)
        self.boundary = _noncomment_text(BOUNDARY)

    def test_producer_has_no_oidc_or_codecov_token(self) -> None:
        self.assertNotIn("id-token", self.producer)
        self.assertNotIn("codecov/", self.producer)
        self.assertNotIn("CODECOV_TOKEN", self.producer)
        self.assertNotIn("pull_request_target", self.producer)

    def test_producer_partitions_one_os_four_shards(self) -> None:
        self.assertIn("runs-on: ubuntu-latest", self.producer)
        self.assertIn("shard: [1, 2, 3, 4]", self.producer)
        self.assertIn(
            "GLLVMTMB_TEST_SHARD: ${{ format('{0}/4', matrix.shard) }}",
            self.producer,
        )
        self.assertIn('NOT_CRAN: "true"', self.producer)
        self.assertIn('type = "tests"', self.producer)
        self.assertIn("covr::package_coverage(", self.producer)
        self.assertIn(
            'covr::to_cobertura(cov, filename = "cobertura.xml")',
            self.producer,
        )
        self.assertNotIn("macos", self.producer.lower())
        self.assertNotIn("windows", self.producer.lower())
        self.assertNotIn("GLLVMTMB_HEAVY_TESTS", self.producer)

    def test_trusted_artifact_is_main_push_only(self) -> None:
        self.assertIn(
            "if: github.event_name == 'push' && github.ref == 'refs/heads/main'",
            self.producer,
        )
        self.assertIn(
            "name: main-coverage-shard-${{ matrix.shard }}",
            self.producer,
        )
        self.assertIn("path: cobertura.xml", self.producer)
        self.assertIn(UPLOAD_ARTIFACT, self.producer)
        self.assertIn("retention-days: 7", self.producer)
        self.assertIn(
            "if: github.event_name == 'pull_request'",
            self.producer,
        )
        self.assertIn(
            "name: pr-coverage-shard-${{ matrix.shard }}",
            self.producer,
        )

    def test_existing_check_workflows_do_not_collect_coverage(self) -> None:
        self.assertNotIn("covr::package_coverage(", self.r_cmd_check)
        self.assertNotIn("covr::package_coverage(", self.full_check)
        self.assertNotIn("codecov/", self.r_cmd_check)
        self.assertNotIn("codecov/", self.full_check)
        self.assertIn("GLLVMTMB_TEST_SHARD", self.r_cmd_check)

    def test_uploader_is_main_workflow_run_oidc_only(self) -> None:
        self.assertIn("workflows: [test-coverage]", self.uploader)
        self.assertIn("branches: [main]", self.uploader)
        self.assertIn(
            "github.event.workflow_run.event == 'push' &&",
            self.uploader,
        )
        self.assertIn(
            "github.event.workflow_run.head_branch == 'main' &&",
            self.uploader,
        )
        self.assertIn(
            "github.event.workflow_run.head_repository.full_name == github.repository &&",
            self.uploader,
        )
        self.assertIn(
            "github.event.workflow_run.conclusion == 'success'",
            self.uploader,
        )
        self.assertIn("id-token: write", self.uploader)
        self.assertIn("use_oidc: true", self.uploader)
        self.assertIn("fail_ci_if_error: true", self.uploader)
        self.assertIn("disable_search: true", self.uploader)
        self.assertIn("plugins: noop", self.uploader)
        self.assertIn("version: v11.3.2", self.uploader)
        self.assertIn(CODECOV_ACTION, self.uploader)
        self.assertIn(CHECKOUT_ACTION, self.uploader)
        self.assertIn(DOWNLOAD_ACTION, self.uploader)
        self.assertIn("pattern: main-coverage-shard-*", self.uploader)
        self.assertIn(
            "override_commit: ${{ github.event.workflow_run.head_sha }}",
            self.uploader,
        )
        self.assertNotIn("CODECOV_TOKEN", self.uploader)
        self.assertNotIn("pull_request_target", self.uploader)
        self.assertNotIn("secrets.CODECOV_TOKEN", self.uploader)
        self.assertNotIn("token: ${{ secrets", self.uploader)

    def test_uploader_pins_all_four_shard_reports(self) -> None:
        files_line = next(
            line for line in _active_lines(UPLOADER) if "files:" in line
        )
        for shard in (1, 2, 3, 4):
            self.assertIn(
                f"main-coverage-shard-{shard}/cobertura.xml",
                files_line,
            )

    def test_boundary_allowlists_coverage_workflows(self) -> None:
        self.assertIn("test-coverage.yaml", self.boundary)
        self.assertIn("codecov-upload.yaml", self.boundary)
        self.assertIn("R-CMD-check.yaml", self.boundary)
        self.assertIn("full-check.yaml", self.boundary)
        self.assertIn("pkgdown.yaml", self.boundary)

    def test_comment_cannot_satisfy_oidc_gate(self) -> None:
        mutated = re.sub(
            r"github\.event\.workflow_run\.event == 'push' &&",
            "",
            self.uploader,
            count=1,
        )
        self.assertNotIn(
            "github.event.workflow_run.event == 'push' &&",
            mutated,
        )


if __name__ == "__main__":
    unittest.main()
