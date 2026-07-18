#!/usr/bin/env python3
"""Validate that newly introduced Git commits have exactly one message line."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


SHA_PATTERN = re.compile(r"[0-9a-f]{40}")
ZERO_SHA = "0" * 40


@dataclass(frozen=True)
class Finding:
    rule_code: str
    commit_id: str


def validate_message(message: bytes, commit_id: str) -> list[Finding]:
    try:
        text = message.decode("utf-8")
    except UnicodeDecodeError:
        return [Finding("COMMIT_MESSAGE_NOT_UTF8", commit_id)]

    if text.endswith("\r\n"):
        logical_text = text[:-2]
    elif text.endswith("\n"):
        logical_text = text[:-1]
    else:
        logical_text = text

    if not logical_text:
        return [Finding("COMMIT_MESSAGE_EMPTY", commit_id)]
    if "\n" in logical_text or "\r" in logical_text:
        return [Finding("COMMIT_MESSAGE_NOT_SINGLE_LINE", commit_id)]
    return []


def commit_message(repository_root: Path, commit_sha: str) -> tuple[bytes | None, list[Finding]]:
    try:
        result = subprocess.run(
            ["git", "-C", str(repository_root), "cat-file", "commit", commit_sha],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )
    except (OSError, subprocess.CalledProcessError):
        return None, [Finding("COMMIT_OBJECT_UNAVAILABLE", commit_sha)]

    separator = result.stdout.find(b"\n\n")
    if separator < 0:
        return None, [Finding("COMMIT_OBJECT_INVALID", commit_sha)]
    return result.stdout[separator + 2 :], []


def introduced_commits(
    repository_root: Path,
    head_sha: str,
    base_sha: str | None,
) -> tuple[list[str], list[Finding]]:
    if not SHA_PATTERN.fullmatch(head_sha):
        return [], [Finding("HEAD_SHA_INVALID", "HEAD")]
    if base_sha is not None and base_sha != ZERO_SHA and not SHA_PATTERN.fullmatch(base_sha):
        return [], [Finding("BASE_SHA_INVALID", "BASE")]

    revision = head_sha
    if base_sha and base_sha != ZERO_SHA:
        revision = f"{base_sha}..{head_sha}"
    try:
        result = subprocess.run(
            ["git", "-C", str(repository_root), "rev-list", "--reverse", revision],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
        )
    except (OSError, subprocess.CalledProcessError):
        return [], [Finding("COMMIT_RANGE_UNAVAILABLE", "RANGE")]

    commits = [line for line in result.stdout.splitlines() if line]
    if base_sha is None or base_sha == ZERO_SHA:
        commits = commits[-1:]
    if any(not SHA_PATTERN.fullmatch(item) for item in commits):
        return [], [Finding("COMMIT_RANGE_INVALID", "RANGE")]
    return commits, []


def scan_repository(
    repository_root: Path,
    head_sha: str,
    base_sha: str | None,
) -> tuple[list[Finding], int]:
    commits, findings = introduced_commits(repository_root, head_sha, base_sha)
    if findings:
        return findings, 0

    for commit_sha in commits:
        message, message_findings = commit_message(repository_root, commit_sha)
        findings.extend(message_findings)
        if message is not None:
            findings.extend(validate_message(message, commit_sha))
    return findings, len(commits)


def run_self_test() -> list[Finding]:
    cases = {
        "SINGLE_LINE_WITH_TERMINATOR": (b"docs: update contract\n", 0),
        "SINGLE_LINE_WITHOUT_TERMINATOR": (b"docs: update contract", 0),
        "SINGLE_LINE_CRLF_TERMINATOR": (b"docs: update contract\r\n", 0),
        "EMPTY_MESSAGE": (b"\n", 1),
        "MESSAGE_BODY": (b"docs: update contract\nadditional detail\n", 1),
        "TRAILING_BLANK_LINE": (b"docs: update contract\n\n", 1),
        "EMBEDDED_CARRIAGE_RETURN": (b"docs: update\rcontract\n", 1),
        "NON_UTF8_MESSAGE": (b"docs: update \xff\n", 1),
    }
    failures: list[Finding] = []
    for case_id, (message, expected_count) in cases.items():
        actual_count = len(validate_message(message, case_id))
        if actual_count != expected_count:
            failures.append(Finding("SELF_TEST_CONTRACT_FAILED", case_id))
    return failures


def report(findings: Iterable[Finding], scope: str, commit_count: int) -> int:
    ordered = sorted(findings, key=lambda item: (item.rule_code, item.commit_id))
    counts = Counter((item.rule_code, item.commit_id) for item in ordered)
    for (rule_code, commit_id), count in sorted(counts.items()):
        print(
            "Commit message validation finding: "
            f"scope={scope} rule={rule_code} "
            f"commit={json.dumps(commit_id, ensure_ascii=True)} count={count}"
        )
    if ordered:
        print(
            "Commit message validation blocked: "
            f"scope={scope} commits={commit_count} findings={len(ordered)}"
        )
        return 1
    print(
        "Commit message validation passed: "
        f"scope={scope} commits={commit_count} findings=0"
    )
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository-root", type=Path, default=Path.cwd())
    parser.add_argument("--head-sha")
    parser.add_argument("--base-sha")
    parser.add_argument("--self-test", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.self_test:
        return report(run_self_test(), "SELF_TEST", 8)
    if args.head_sha is None:
        return report([Finding("HEAD_SHA_MISSING", "HEAD")], "REPOSITORY", 0)
    findings, commit_count = scan_repository(
        args.repository_root.resolve(),
        args.head_sha.lower(),
        args.base_sha.lower() if args.base_sha else None,
    )
    return report(findings, "REPOSITORY", commit_count)


if __name__ == "__main__":
    sys.exit(main())
