#!/usr/bin/env python3
"""Reject accidental local files and high-confidence secrets before publishing.

Run from any directory inside the repository:
  python tool/check_repository_hygiene.py                # all indexed blobs
  python tool/check_repository_hygiene.py --staged       # changed index blobs
  python tool/check_repository_hygiene.py --working-tree # tracked + unignored new files

Only categories, repository-relative paths and line numbers are reported. This
is a focused accidental-publication guard, not a complete secret scanner.
"""

import argparse
import base64
import gzip
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import zlib


EMPTY_FIXTURE = "test/fixtures/record_backup_v12_empty.yhb"
PACKAGED_MANIFEST = "assets/data/game_resource_baseline_manifest.json.gz"
BLOCKED_DIRECTORIES = {
    "outputs", "backups", ".codex-work", ".build-tools", ".worktrees",
    ".dart_tool", ".pub-cache", "build", ".gradle", ".idea", ".vscode",
    ".reference", ".android-sdk-backups", ".java-sockets", ".jtmp",
}
BLOCKED_SUFFIXES = {
    ".apk", ".aab", ".ipa", ".zip", ".7z", ".rar", ".tar", ".gz",
    ".tgz", ".bz2", ".xz", ".log", ".db", ".sqlite", ".sqlite3",
    ".jks", ".keystore", ".p12", ".pfx", ".pem", ".p8", ".key",
    ".mobileprovision", ".yhb", ".dmp", ".hprof",
    ".har", ".pcap", ".pcapng",
}
SECRET_PATTERNS = (
    ("private-key", re.compile(r"-----BEGIN (?:[A-Z0-9]+ )?PRIVATE KEY-----")),
    ("github-token", re.compile(r"\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,})\b")),
    ("aws-access-key", re.compile(r"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b")),
    ("api-secret-key", re.compile(r"\bsk-(?:proj-|svcacct-)?[A-Za-z0-9_-]{24,}\b")),
    ("google-api-key", re.compile(r"\bAIza[0-9A-Za-z_-]{35}\b")),
    ("slack-token", re.compile(r"\bxox[baprs]-[0-9A-Za-z-]{24,}\b")),
)
USER_DIRECTORY = re.compile(r"(?i)\b[A-Z]:[\\/]+Users[\\/]+([^\\/\s\"'`]+)")
DEVICE_SERIAL = re.compile(r"\badb(?:\.exe)?\s+-s\s+[\"']?([A-Za-z0-9_-]{6,})")
SAMSUNG_SERIAL = re.compile(r"\bR[0-9][0-9A-Z]{9}\b")
TEMPLATE_VALUES = {
    "example", "user", "username", "yourname", "your_name", "your_username",
    "your-user", "your-user-name", "runneradmin", "device_serial", "device_id",
    "serial", "emulator-5554", "localhost",
}


def git(root, *arguments):
    result = subprocess.run(
        ["git", "-C", str(root), *arguments], capture_output=True, check=False,
    )
    if result.returncode:
        # Git errors can contain local paths or remote credentials.
        raise RuntimeError("git-read-failed")
    return result.stdout


def path_category(path):
    normalized = PurePosixPath(path.lower())
    parts = normalized.parts
    if any(part in BLOCKED_DIRECTORIES or part.startswith((".scratch", ".codex-"))
           for part in parts[:-1]):
        return "local-or-generated-directory"
    name = normalized.name
    if name in {
        "local.properties", "key.properties", "release-signing.properties",
        ".netrc", "_netrc", ".npmrc", ".pypirc", "id_rsa", "id_ed25519",
    }:
        return "local-configuration-or-credentials"
    if name == ".env" or (name.startswith(".env.") and name != ".env.example"):
        return "local-configuration-or-credentials"
    if re.search(r"\.(?:db|sqlite|sqlite3)-(?:journal|wal|shm)$", name):
        return "database-sidecar"
    if name.endswith((".apk.sha256", ".aab.sha256")):
        return "build-artifact"
    if path in {EMPTY_FIXTURE, PACKAGED_MANIFEST}:
        return None
    if ".yhb." in name:
        return "backup-derived-file"
    if normalized.suffix in BLOCKED_SUFFIXES:
        return "artifact-backup-or-signing-material"
    return None


def is_template(value):
    lowered = value.lower()
    return lowered in TEMPLATE_VALUES or lowered.startswith(("<", "%", "$", "{"))


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate-json-key")
        result[key] = value
    return result


def valid_empty_fixture(data):
    """The sole backup exception is the existing empty synthetic schema fixture."""
    if len(data) > 65536:
        return False
    try:
        envelope = json.loads(data, object_pairs_hook=unique_object)
        if set(envelope) != {"format", "version", "sha256", "payload"}:
            return False
        if envelope["format"] != "yahagi-record-backup" or envelope["version"] != 1:
            return False
        compressed = base64.b64decode(envelope["payload"], validate=True)
        if hashlib.sha256(compressed).hexdigest() != envelope["sha256"]:
            return False
        with gzip.GzipFile(fileobj=io.BytesIO(compressed)) as stream:
            plain = stream.read(65537)
        if len(plain) > 65536:
            return False
        payload = json.loads(plain, object_pairs_hook=unique_object)
        expected = {
            "memberId": 812345,
            "logbookSchema": 12,
            "tables": {name: [] for name in (
                "battle_logs", "map_resource_logs", "resource_logs",
                "expedition_logs", "pending_construction_logs", "construction_logs",
                "development_logs", "retirement_logs",
            )},
            "compositions": [], "writerId": "fixture-writer", "rowIds": {},
        }
        return payload == expected
    except (ValueError, TypeError, KeyError, OSError, EOFError, zlib.error):
        return False


def findings(path, data):
    category = path_category(path)
    if category:
        yield category, 1
    if path == EMPTY_FIXTURE:
        if not valid_empty_fixture(data):
            yield "unsafe-backup-fixture", 1
        return
    if path == PACKAGED_MANIFEST:
        try:
            with gzip.GzipFile(fileobj=io.BytesIO(data)) as stream:
                data = stream.read(16 * 1024 * 1024 + 1)
            if len(data) > 16 * 1024 * 1024:
                raise ValueError("manifest-too-large")
            json.loads(data, object_pairs_hook=unique_object)
        except (ValueError, TypeError, OSError, EOFError, zlib.error):
            yield "invalid-packaged-manifest", 1
            return
    if b"\x00" in data:
        return
    text = data.decode("utf-8", errors="replace")
    for number, line in enumerate(text.splitlines(), 1):
        for name, pattern in SECRET_PATTERNS:
            if pattern.search(line):
                yield name, number
        if any(not is_template(match.group(1))
               and not (path.startswith("test/") and match.group(1).lower() == "player")
               for match in USER_DIRECTORY.finditer(line)):
            yield "local-user-directory", number
        if (any(not is_template(match.group(1)) for match in DEVICE_SERIAL.finditer(line))
                or SAMSUNG_SERIAL.search(line)):
            yield "local-device-serial", number


def index_entries(root):
    entries = {}
    for record in git(root, "ls-files", "--stage", "-z").split(b"\0"):
        if not record:
            continue
        metadata, raw_path = record.split(b"\t", 1)
        mode, object_id, stage = metadata.split()
        if stage != b"0":
            raise RuntimeError("unmerged-index")
        path = os.fsdecode(raw_path)
        entries[path] = (mode, object_id)
    return entries


def indexed_blobs(root, entries, paths):
    # One persistent Git reader avoids starting a process for every source file.
    with subprocess.Popen(
        ["git", "-C", str(root), "cat-file", "--batch"], stdin=subprocess.PIPE,
        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
    ) as reader:
        try:
            for path in paths:
                mode, object_id = entries[path]
                if mode == b"160000":  # Gitlink: the submodule is audited separately.
                    continue
                reader.stdin.write(object_id + b"\n")
                reader.stdin.flush()
                header = reader.stdout.readline().split()
                if len(header) != 3 or header[1] != b"blob":
                    raise RuntimeError("index-blob-read-failed")
                size = int(header[2])
                data = reader.stdout.read(size)
                if len(data) != size or reader.stdout.read(1) != b"\n":
                    raise RuntimeError("index-blob-read-failed")
                yield path, data
        finally:
            reader.stdin.close()
            reader.wait()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--staged", action="store_true", help="inspect changed blobs from the Git index")
    mode.add_argument("--working-tree", action="store_true", help="inspect tracked and unignored untracked working files")
    args = parser.parse_args(argv)
    try:
        root = Path(os.fsdecode(git(Path.cwd(), "rev-parse", "--show-toplevel")).strip())
        entries = index_entries(root)
        if args.working_tree:
            paths = sorted({os.fsdecode(path) for path in git(
                root, "ls-files", "--cached", "--others", "--exclude-standard", "-z",
            ).split(b"\0") if path})

            def worktree_blobs():
                for path in paths:
                    file = root / path
                    if file.is_symlink():
                        yield path, os.fsencode(os.readlink(file))
                    elif file.is_file():
                        yield path, file.read_bytes()

            blobs = worktree_blobs()
        else:
            if args.staged:
                changed = {os.fsdecode(path) for path in git(
                    root, "diff", "--cached", "--name-only", "--diff-filter=ACMRT", "-z",
                ).split(b"\0") if path}
                paths = sorted(changed & entries.keys())
            else:
                paths = sorted(entries)
            blobs = indexed_blobs(root, entries, paths)
        count = 0
        problems = 0
        for path, data in blobs:
            count += 1
            for category, line in findings(path, data):
                # JSON escapes unusual filenames and prevents terminal control injection.
                safe_path = json.dumps(path, ensure_ascii=True)[1:-1]
                print(f"{category}: {safe_path}:{line}")
                problems += 1
        if problems:
            print(f"Repository hygiene rejected {problems} finding(s) in {count} file(s).")
            return 1
        print(f"Repository hygiene passed ({count} file(s)).")
        return 0
    except (RuntimeError, OSError, ValueError):
        print("repository-read-error: unable to complete hygiene checks", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
