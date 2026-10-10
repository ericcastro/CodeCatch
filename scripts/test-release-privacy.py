#!/usr/bin/env python3
"""Exercise the release privacy checker through its public CLI."""

from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


CHECKER = Path(__file__).with_name("check-release-privacy.py")


class ReleasePrivacyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def run_checker(self, *paths):
        return subprocess.run(
            [sys.executable, str(CHECKER), *map(str, paths)],
            capture_output=True,
            text=True,
            timeout=10,
        )

    def test_embedded_home_paths_block_release_without_echoing_private_content(self):
        for home in (b"/Users/synthetic-developer/project/source.swift",
                     b"/home/synthetic-developer/project/source.swift",
                     b"/System/Volumes/Data/Users/synthetic-developer/project/source.swift",
                     b"/Users/synthetic-developer",
                     b"/home/synthetic-developer"):
            for prefix in (b"build source: ", b"\x00\xff\x01", b"file://", b"source:"):
                with self.subTest(home=home, prefix=prefix):
                    artifact = self.root / "leaking-artifact"
                    artifact.write_bytes(prefix + home + b"\x00")
                    result = self.run_checker(artifact)
                    output = result.stdout + result.stderr
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn(artifact.name, output)
                    self.assertNotIn(home.decode(), output)
                    self.assertNotIn("synthetic-developer", output)

    def test_hidden_nested_artifacts_cannot_bypass_scan(self):
        nested = self.root / ".hidden" / "nested"
        nested.mkdir(parents=True)
        artifact = nested / ".artifact"
        artifact.write_bytes(b"\x00/Users/synthetic-developer/project/file\x00")
        result = self.run_checker(self.root)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(artifact.name, result.stdout + result.stderr)

    def test_every_input_is_checked_even_after_a_clean_artifact(self):
        clean = self.root / "clean"
        clean.write_bytes(b"clean artifact")
        leaking = self.root / "leaking"
        leaking.write_bytes(b"/home/synthetic-developer/project/file")
        result = self.run_checker(clean, leaking)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(leaking.name, result.stdout + result.stderr)

    def test_web_and_api_paths_do_not_block_clean_releases(self):
        artifact = self.root / "clean"
        artifact.write_text(
            "https://service.test/Users/example/resource\n"
            "https://service.test/home/user/profile\n"
            "/users/me/\n/Users/\n/home/\n"
        )
        empty = self.root / "empty-directory"
        empty.mkdir()
        result = self.run_checker(artifact, empty)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_symlinks_do_not_scan_outside_the_requested_tree_or_loop(self):
        outside = self.root / "outside"
        outside.mkdir()
        artifact = outside / "leaking"
        artifact.write_bytes(b"/Users/synthetic-developer/project/file")
        release = self.root / "release"
        release.mkdir()
        (release / "linked-file").symlink_to(artifact)
        (release / "linked-directory").symlink_to(outside, target_is_directory=True)
        (release / "loop").symlink_to(release, target_is_directory=True)
        result = self.run_checker(release)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_missing_inputs_cannot_report_a_successful_scan(self):
        clean = self.root / "clean"
        clean.write_bytes(b"clean artifact")
        missing = self.root / "missing-artifact"
        result = self.run_checker(clean, missing)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(missing.name, result.stdout + result.stderr)

    def test_omitting_inputs_cannot_report_a_successful_scan(self):
        self.assertNotEqual(self.run_checker().returncode, 0)


if __name__ == "__main__":
    unittest.main()
