"""Repository hygiene integration tests; run with Python's unittest module."""

import base64
import gzip
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


CHECKER = Path(__file__).with_name("check_repository_hygiene.py")
EMPTY_FIXTURE = Path(__file__).resolve().parents[1] / "test/fixtures/record_backup_v12_empty.yhb"


class RepositoryHygieneTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.git("init", "--quiet")

    def git(self, *args):
        return subprocess.run(
            ["git", "-C", str(self.root), *args], check=True,
            capture_output=True,
        ).stdout

    def write(self, path, content=b"safe\n", stage=True):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content.encode() if isinstance(content, str) else content)
        if stage:
            self.git("add", "--", path)
        return target

    def check(self, *args):
        return subprocess.run(
            [sys.executable, str(CHECKER), *args], cwd=self.root,
            capture_output=True, text=True,
        )

    def test_safe_sources_and_synthetic_tokens_pass(self):
        self.write("lib/example.dart", "final url = 'https://example.invalid/?token=secret';\n")
        self.write(".env.example", "API_KEY=your_api_key_here\n")
        self.write("README.md", "SDK: C:/Users/example/Android/Sdk\n")
        self.write("test/privacy_test.dart", "input = 'C:" + "/Users/Player/private.dart'\n")
        result = self.check("--staged")
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)

    def test_staged_blob_blocks_secret_even_when_worktree_is_clean(self):
        token = "ghp_" + "aBcD1234" * 5
        target = self.write("lib/config.dart", "safe\n" + token + "\n")
        target.write_text("safe\n", encoding="utf-8")
        result = self.check("--staged")
        self.assertEqual(1, result.returncode, result.stdout + result.stderr)
        self.assertIn("github-token", result.stdout)
        self.assertIn("lib/config.dart:2", result.stdout)
        self.assertNotIn(token, result.stdout + result.stderr)

    def test_staged_clean_blob_ignores_unstaged_secret(self):
        target = self.write("lib/config.dart")
        target.write_text("ghp_" + "z9Ab" * 10, encoding="utf-8")
        self.assertEqual(0, self.check("--staged").returncode)
        self.assertEqual(1, self.check("--working-tree").returncode)

    def test_default_checks_all_tracked_files(self):
        self.write("lib/config.dart", "github_pat_" + "X8zq" * 16)
        result = self.check()
        self.assertEqual(1, result.returncode)
        self.assertIn("github-token", result.stdout)

    def test_working_tree_includes_untracked_files(self):
        self.write("notes/local.log", stage=False)
        self.assertEqual(0, self.check().returncode)
        self.assertEqual(1, self.check("--working-tree").returncode)

    def test_artifacts_local_configuration_and_backups_are_blocked(self):
        paths = [
            "app.apk", "data.aab", "dump.zip", "log.txt.log", "record.db",
            "record.db-wal", "record.sqlite3-shm", "record.sqlite-journal",
            "android/local.properties", "android/key.properties", "release.jks",
            ".env", ".env.local", "private.pem", "personal.yhb",
            "outputs/report.md", "backups/readme.md", ".codex-work/script.py",
            ".build-tools/config.json", ".worktrees/branch/source.dart",
            ".scratch-demo/trace.json", ".vscode/settings.json",
            "capture.har", "capture.pcap", "capture.pcapng",
            "personal.yhb.tmp", "personal.yhb.sha256", "personal.yhb.export",
        ]
        for path in paths:
            self.write(path)
        result = self.check("--staged")
        self.assertEqual(1, result.returncode)
        for path in paths:
            with self.subTest(path=path):
                self.assertIn(path, result.stdout)

    def test_release_signing_properties_are_blocked_without_echoing_passwords(self):
        paths = ["release-signing.properties", "android/release-signing.properties"]
        password = "synthetic-signing-password"
        content = (
            "storeFile=keys/release.jks\n"
            f"storePassword={password}\n"
            "keyAlias=release\n"
            f"keyPassword={password}\n"
        )
        for path in paths:
            self.write(path, content)
        result = self.check("--staged")
        self.assertEqual(1, result.returncode, result.stdout + result.stderr)
        self.assertIn("local-configuration-or-credentials", result.stdout)
        for path in paths:
            self.assertIn(path, result.stdout)
        self.assertNotIn(password, result.stdout + result.stderr)

    def test_release_signing_properties_are_ignored_in_root_and_subdirectories(self):
        ignore_file = CHECKER.resolve().parents[1] / ".gitignore"
        self.write(".gitignore", ignore_file.read_bytes())
        paths = ["release-signing.properties", "android/release-signing.properties"]
        result = subprocess.run(
            ["git", "-C", str(self.root), "check-ignore", "--no-index", "--", *paths],
            capture_output=True, text=True,
        )
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertEqual(paths, result.stdout.splitlines())

    def test_current_empty_synthetic_backup_fixture_passes(self):
        self.write("test/fixtures/record_backup_v12_empty.yhb", EMPTY_FIXTURE.read_bytes())
        result = self.check("--staged")
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)

    def test_fixture_cannot_be_replaced_with_personal_records(self):
        envelope = json.loads(EMPTY_FIXTURE.read_bytes())
        payload = json.loads(gzip.decompress(base64.b64decode(envelope["payload"])))
        payload["tables"]["battle_logs"].append({"id": 1})
        compressed = gzip.compress(json.dumps(payload).encode())
        envelope["payload"] = base64.b64encode(compressed).decode()
        envelope["sha256"] = hashlib.sha256(compressed).hexdigest()
        self.write("test/fixtures/record_backup_v12_empty.yhb", json.dumps(envelope))
        result = self.check("--staged")
        self.assertEqual(1, result.returncode)
        self.assertIn("unsafe-backup-fixture", result.stdout)

    def test_fixture_rejects_corrupt_checksum(self):
        envelope = json.loads(EMPTY_FIXTURE.read_bytes())
        envelope["sha256"] = "0" * 64
        self.write("test/fixtures/record_backup_v12_empty.yhb", json.dumps(envelope))
        self.assertEqual(1, self.check("--staged").returncode)

    def test_fixture_rejects_duplicate_metadata_keys(self):
        fixture = EMPTY_FIXTURE.read_text(encoding="utf-8")
        self.write("test/fixtures/record_backup_v12_empty.yhb", '{"payload":"personal-data",' + fixture[1:])
        self.assertEqual(1, self.check("--staged").returncode)

    def test_corrupt_compressed_data_reports_category_without_traceback(self):
        envelope = json.loads(EMPTY_FIXTURE.read_bytes())
        compressed = b"\x1f\x8b\x08\x00" + b"\x00" * 6 + b"\x07" * 20
        envelope["payload"] = base64.b64encode(compressed).decode()
        envelope["sha256"] = hashlib.sha256(compressed).hexdigest()
        self.write("test/fixtures/record_backup_v12_empty.yhb", json.dumps(envelope))
        result = self.check("--staged")
        self.assertEqual(1, result.returncode)
        self.assertIn("unsafe-backup-fixture", result.stdout)
        self.assertNotIn("Traceback", result.stderr)

    def test_packaged_baseline_manifest_is_allowed_but_scanned(self):
        path = "assets/data/game_resource_baseline_manifest.json.gz"
        self.write(path, gzip.compress(b'{"entries": []}'))
        self.assertEqual(0, self.check("--staged").returncode)
        self.write(path, gzip.compress(json.dumps({"secret": "ghp_" + "aB3c" * 10}).encode()))
        self.assertEqual(1, self.check("--staged").returncode)

    def test_private_key_and_local_user_path_are_redacted(self):
        key = "-----BEGIN " + "RSA PRIVATE KEY-----"
        user_path = "C:" + "/Users/ActualDeveloper/AppData/Local"
        self.write("lib/config.dart", key + "\n" + user_path)
        result = self.check("--staged")
        self.assertEqual(1, result.returncode)
        self.assertIn("private-key", result.stdout)
        self.assertIn("local-user-directory", result.stdout)
        self.assertNotIn(key, result.stdout)
        self.assertNotIn(user_path, result.stdout)

    def test_device_serial_command_is_blocked_but_placeholder_is_allowed(self):
        self.write("docs/device.md", "adb -s " + "R58" + "A12BCDEF" + " shell\n")
        self.assertEqual(1, self.check("--staged").returncode)
        self.write("docs/device.md", "adb -s <device_serial> shell\n")
        self.assertEqual(0, self.check("--staged").returncode)

    def test_deleted_file_does_not_require_missing_blob(self):
        target = self.write("lib/old.dart")
        # Create a minimal baseline without needing a global Git identity.
        self.git("-c", "user.name=Test", "-c", "user.email=test@example.invalid", "commit", "-qm", "baseline")
        target.unlink()
        self.git("add", "-u")
        self.assertEqual(0, self.check("--staged").returncode)


if __name__ == "__main__":
    unittest.main()
