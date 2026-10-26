"""Focused behavior checks for the pure Linux cgroup scalar parser."""

from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path
from typing import Any


MODULE_RELATIVE_PATH = Path("Code/Tools/Linux_Cgroup_Values.py")
METADATA_MODULE_RELATIVE_PATH = Path("Code/Tools/Linux_Cgroup_Metadata.py")


def load_module(repository_root: Path, relative_path: Path = MODULE_RELATIVE_PATH):
    module_path = repository_root / relative_path
    module_name = relative_path.stem.lower()
    spec = importlib.util.spec_from_file_location(module_name, module_path)
    if spec is None or spec.loader is None:
        raise AssertionError(f"Cannot load parser module: {relative_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def load_parser(repository_root: Path):
    return load_module(repository_root).parse_resource_value


def expected(
    source_key: str,
    raw_value: str,
    state: str,
    reason: str,
    kind: str = "NONE",
    *,
    value: str | None = None,
    quota: str | None = None,
    period: str | None = None,
    numerator: str | None = None,
    denominator: str | None = None,
) -> dict[str, Any]:
    return {
        "source_key": source_key,
        "raw_value": raw_value,
        "parse_state": state,
        "reason_code": reason,
        "value_kind": kind,
        "value": value,
        "quota_us": quota,
        "period_us": period,
        "ratio_numerator": numerator,
        "ratio_denominator": denominator,
    }


def assert_raises(error_type: type[Exception], callback: Any, label: str) -> None:
    try:
        callback()
    except error_type:
        return
    except Exception as error:  # pragma: no cover - diagnostic path
        raise AssertionError(f"{label}: expected {error_type.__name__}, got {type(error).__name__}") from error
    raise AssertionError(f"{label}: expected {error_type.__name__}")


def run_metadata_checks(repository_root: Path) -> int:
    module = load_module(repository_root, METADATA_MODULE_RELATIVE_PATH)
    parse_membership = module.parse_v2_membership
    parse_mountinfo = module.parse_cgroup2_mountinfo

    membership_cases = [
        (
            "0::/synthetic/group\n",
            {
                "source_key": "proc.cgroup", "parse_state": "VALID",
                "reason_code": "V2_MEMBERSHIP_PARSED", "record_count": "1",
                "record_ordinal": "1", "hierarchy_id": "0",
                "membership_path": "/synthetic/group", "layout_state": "CGROUP_V2",
                "issue_line_ordinals": [],
            },
        ),
        (
            "0::/synthetic/group:with:colons\n",
            {
                "source_key": "proc.cgroup", "parse_state": "VALID",
                "reason_code": "V2_MEMBERSHIP_PARSED", "record_count": "1",
                "record_ordinal": "1", "hierarchy_id": "0",
                "membership_path": "/synthetic/group:with:colons", "layout_state": "CGROUP_V2",
                "issue_line_ordinals": [],
            },
        ),
        (
            "0::/\n",
            {
                "source_key": "proc.cgroup", "parse_state": "VALID",
                "reason_code": "V2_MEMBERSHIP_PARSED", "record_count": "1",
                "record_ordinal": "1", "hierarchy_id": "0",
                "membership_path": "/", "layout_state": "CGROUP_V2",
                "issue_line_ordinals": [],
            },
        ),
        (
            "0::/synthetic/name ",
            {
                "source_key": "proc.cgroup", "parse_state": "VALID",
                "reason_code": "V2_MEMBERSHIP_PARSED", "record_count": "1",
                "record_ordinal": "1", "hierarchy_id": "0",
                "membership_path": "/synthetic/name ", "layout_state": "CGROUP_V2",
                "issue_line_ordinals": [],
            },
        ),
        (
            "0::/synthetic/name\r",
            {
                "source_key": "proc.cgroup", "parse_state": "VALID",
                "reason_code": "V2_MEMBERSHIP_PARSED", "record_count": "1",
                "record_ordinal": "1", "hierarchy_id": "0",
                "membership_path": "/synthetic/name\r", "layout_state": "CGROUP_V2",
                "issue_line_ordinals": [],
            },
        ),
        (
            "0::/synthetic/über\n",
            {
                "source_key": "proc.cgroup", "parse_state": "VALID",
                "reason_code": "V2_MEMBERSHIP_PARSED", "record_count": "1",
                "record_ordinal": "1", "hierarchy_id": "0",
                "membership_path": "/synthetic/über", "layout_state": "CGROUP_V2",
                "issue_line_ordinals": [],
            },
        ),
        (
            "3:cpu,cpuacct:/synthetic/v1",
            {
                "source_key": "proc.cgroup", "parse_state": "UNSUPPORTED_LAYOUT",
                "reason_code": "V1_ONLY", "record_count": "1",
                "record_ordinal": None, "hierarchy_id": None,
                "membership_path": None, "layout_state": "V1_ONLY",
                "issue_line_ordinals": [],
            },
        ),
        (
            "7:name=systemd:/synthetic.slice",
            {
                "source_key": "proc.cgroup", "parse_state": "UNSUPPORTED_LAYOUT",
                "reason_code": "V1_ONLY", "record_count": "1",
                "record_ordinal": None, "hierarchy_id": None,
                "membership_path": None, "layout_state": "V1_ONLY",
                "issue_line_ordinals": [],
            },
        ),
        (
            "0::/synthetic/v2\n7:name=systemd:/synthetic.slice",
            {
                "source_key": "proc.cgroup", "parse_state": "UNSUPPORTED_LAYOUT",
                "reason_code": "HYBRID_LAYOUT", "record_count": "2",
                "record_ordinal": None, "hierarchy_id": None,
                "membership_path": None, "layout_state": "HYBRID",
                "issue_line_ordinals": [],
            },
        ),
        (
            "7:name=:/synthetic.slice",
            {
                "source_key": "proc.cgroup", "parse_state": "INVALID_VALUE",
                "reason_code": "MALFORMED_RECORD", "record_count": "1",
                "record_ordinal": None, "hierarchy_id": None,
                "membership_path": None, "layout_state": "UNVERIFIED",
                "issue_line_ordinals": ["1"],
            },
        ),
        (
            "7:name=systemd=extra:/synthetic.slice",
            {
                "source_key": "proc.cgroup", "parse_state": "INVALID_VALUE",
                "reason_code": "MALFORMED_RECORD", "record_count": "1",
                "record_ordinal": None, "hierarchy_id": None,
                "membership_path": None, "layout_state": "UNVERIFIED",
                "issue_line_ordinals": ["1"],
            },
        ),
        (
            "0::/synthetic/v2\n3:cpu:/synthetic/v1",
            {
                "source_key": "proc.cgroup", "parse_state": "UNSUPPORTED_LAYOUT",
                "reason_code": "HYBRID_LAYOUT", "record_count": "2",
                "record_ordinal": None, "hierarchy_id": None,
                "membership_path": None, "layout_state": "HYBRID",
                "issue_line_ordinals": [],
            },
        ),
        (
            "0::/synthetic/one\n0::/synthetic/two",
            {
                "source_key": "proc.cgroup", "parse_state": "INVALID_VALUE",
                "reason_code": "DUPLICATE_V2_RECORD", "record_count": "2",
                "record_ordinal": None, "hierarchy_id": None,
                "membership_path": None, "layout_state": "UNVERIFIED",
                "issue_line_ordinals": ["1", "2"],
            },
        ),
        (
            "0::/synthetic/../escape",
            {
                "source_key": "proc.cgroup", "parse_state": "INVALID_VALUE",
                "reason_code": "INVALID_PATH", "record_count": "1",
                "record_ordinal": None, "hierarchy_id": None,
                "membership_path": None, "layout_state": "UNVERIFIED",
                "issue_line_ordinals": ["1"],
            },
        ),
        (
            "0::relative/path",
            {
                "source_key": "proc.cgroup", "parse_state": "INVALID_VALUE",
                "reason_code": "INVALID_PATH", "record_count": "1",
                "record_ordinal": None, "hierarchy_id": None,
                "membership_path": None, "layout_state": "UNVERIFIED",
                "issue_line_ordinals": ["1"],
            },
        ),
        (
            "0::/synthetic\x00/path",
            {
                "source_key": "proc.cgroup", "parse_state": "INVALID_VALUE",
                "reason_code": "INVALID_TOKEN", "record_count": "1",
                "record_ordinal": None, "hierarchy_id": None,
                "membership_path": None, "layout_state": "UNVERIFIED",
                "issue_line_ordinals": ["1"],
            },
        ),
        (
            "0:/synthetic/malformed",
            {
                "source_key": "proc.cgroup", "parse_state": "INVALID_VALUE",
                "reason_code": "MALFORMED_RECORD", "record_count": "1",
                "record_ordinal": None, "hierarchy_id": None,
                "membership_path": None, "layout_state": "UNVERIFIED",
                "issue_line_ordinals": ["1"],
            },
        ),
        (
            "",
            {
                "source_key": "proc.cgroup", "parse_state": "MISSING_MEMBERSHIP",
                "reason_code": "V2_MEMBERSHIP_MISSING", "record_count": "0",
                "record_ordinal": None, "hierarchy_id": None,
                "membership_path": None, "layout_state": "V2_MISSING",
                "issue_line_ordinals": [],
            },
        ),
        (
            "18446744073709551616::/synthetic/group",
            {
                "source_key": "proc.cgroup", "parse_state": "INVALID_VALUE",
                "reason_code": "OUT_OF_RANGE", "record_count": "1",
                "record_ordinal": None, "hierarchy_id": None,
                "membership_path": None, "layout_state": "UNVERIFIED",
                "issue_line_ordinals": ["1"],
            },
        ),
        (
            "0::/synthetic/gone (deleted)\n",
            {
                "source_key": "proc.cgroup", "parse_state": "DELETED_RECORD",
                "reason_code": "MEMBERSHIP_DELETED", "record_count": "1",
                "record_ordinal": "1", "hierarchy_id": "0",
                "membership_path": None, "layout_state": "CGROUP_V2",
                "issue_line_ordinals": [],
            },
        ),
    ]
    for raw_value, wanted in membership_cases:
        actual = parse_membership(raw_value)
        if actual != wanted:
            raise AssertionError(f"membership mismatch: {actual!r} != {wanted!r}")
        _assert_metadata_result(actual, "membership")

    simple_mount_line = (
        "100 999 8:1 /bind-root /mnt/cgroup rw,nosuid shared:3 "
        "- cgroup2 cgroup rw,cpuset,cpu,memory"
    )
    simple_mount = {
        "source_ordinal": "1", "mount_id": "100", "parent_id": "999",
        "major": "8", "minor": "1", "root": "/bind-root",
        "mount_point": "/mnt/cgroup", "mount_options": ["rw", "nosuid"],
        "super_options": ["rw", "cpuset", "cpu", "memory"],
        "filesystem_type": "cgroup2",
    }
    mount_cases = [
        (
            simple_mount_line + "\n",
            {
                "source_key": "proc.mountinfo", "parse_state": "VALID",
                "reason_code": "MOUNTINFO_PARSED", "record_count": "1",
                "mounts": [simple_mount], "selection_state": "NOT_SELECTED",
                "path_binding_state": "UNVERIFIED", "issue_line_ordinals": [],
            },
        ),
        (
            "103 102 8:2 / /synthetic/ext4 rw - ext4 /dev/synthetic rw\n" +
            "101 777 0:32 /.. /mnt/root rw - cgroup2 none rw\n" +
            "102 777 0:33 /other /mnt/other rw - cgroup2 none rw\n",
            {
                "source_key": "proc.mountinfo", "parse_state": "VALID",
                "reason_code": "MOUNTINFO_PARSED", "record_count": "3",
                "mounts": [
                    {
                        "source_ordinal": "2", "mount_id": "101", "parent_id": "777",
                        "major": "0", "minor": "32", "root": "/..",
                        "mount_point": "/mnt/root", "mount_options": ["rw"],
                        "super_options": ["rw"], "filesystem_type": "cgroup2",
                    },
                    {
                        "source_ordinal": "3", "mount_id": "102", "parent_id": "777",
                        "major": "0", "minor": "33", "root": "/other",
                        "mount_point": "/mnt/other", "mount_options": ["rw"],
                        "super_options": ["rw"], "filesystem_type": "cgroup2",
                    },
                ],
                "selection_state": "NOT_SELECTED", "path_binding_state": "UNVERIFIED",
                "issue_line_ordinals": [],
            },
        ),
        (
            "12 99 0:88 /a\\040b\\011c\\012d\\134040 /mnt\\040unicode-über rw "
            "future-tag:meta - cgroup2 none rw,nsdelegate",
            {
                "source_key": "proc.mountinfo", "parse_state": "VALID",
                "reason_code": "MOUNTINFO_PARSED", "record_count": "1",
                "mounts": [
                    {
                        "source_ordinal": "1", "mount_id": "12", "parent_id": "99",
                        "major": "0", "minor": "88", "root": "/a b\tc\nd\\040",
                        "mount_point": "/mnt unicode-über", "mount_options": ["rw"],
                        "super_options": ["rw", "nsdelegate"], "filesystem_type": "cgroup2",
                    },
                ],
                "selection_state": "NOT_SELECTED", "path_binding_state": "UNVERIFIED",
                "issue_line_ordinals": [],
            },
        ),
        (
            "1 1 8:1 / /synthetic/root rw - ext4 /dev/synthetic rw\n",
            {
                "source_key": "proc.mountinfo", "parse_state": "VALID",
                "reason_code": "NO_CGROUP2_MOUNTS", "record_count": "1",
                "mounts": [], "selection_state": "EMPTY_CGROUP2_SELECTION",
                "path_binding_state": "UNVERIFIED", "issue_line_ordinals": [],
            },
        ),
        (
            simple_mount_line + "\nbad structure\n",
            {
                "source_key": "proc.mountinfo", "parse_state": "INVALID_VALUE",
                "reason_code": "MALFORMED_RECORD", "record_count": "2",
                "mounts": None, "selection_state": "NOT_SELECTED",
                "path_binding_state": "UNVERIFIED", "issue_line_ordinals": ["2"],
            },
        ),
        (
            simple_mount_line + "\n100 2 0:2 / /other rw - ext4 none rw",
            {
                "source_key": "proc.mountinfo", "parse_state": "INVALID_VALUE",
                "reason_code": "DUPLICATE_MOUNT_ID", "record_count": "2",
                "mounts": None, "selection_state": "NOT_SELECTED",
                "path_binding_state": "UNVERIFIED", "issue_line_ordinals": ["1", "2"],
            },
        ),
        (
            "18446744073709551616 9 0:1 / /m rw - cgroup2 none rw",
            {
                "source_key": "proc.mountinfo", "parse_state": "INVALID_VALUE",
                "reason_code": "OUT_OF_RANGE", "record_count": "1", "mounts": None,
                "selection_state": "NOT_SELECTED", "path_binding_state": "UNVERIFIED",
                "issue_line_ordinals": ["1"],
            },
        ),
        (
            "0 9 0:1 / /m rw - cgroup2 none rw",
            {
                "source_key": "proc.mountinfo", "parse_state": "INVALID_VALUE",
                "reason_code": "INVALID_ID", "record_count": "1", "mounts": None,
                "selection_state": "NOT_SELECTED", "path_binding_state": "UNVERIFIED",
                "issue_line_ordinals": ["1"],
            },
        ),
        (
            "1 9 0:1 /bad\\777 /mnt rw - cgroup2 none rw",
            {
                "source_key": "proc.mountinfo", "parse_state": "INVALID_VALUE",
                "reason_code": "INVALID_ESCAPE", "record_count": "1", "mounts": None,
                "selection_state": "NOT_SELECTED", "path_binding_state": "UNVERIFIED",
                "issue_line_ordinals": ["1"],
            },
        ),
        (
            "1 9 0:1 / /mnt\x00 rw - cgroup2 none rw",
            {
                "source_key": "proc.mountinfo", "parse_state": "INVALID_VALUE",
                "reason_code": "INVALID_TOKEN", "record_count": "1", "mounts": None,
                "selection_state": "NOT_SELECTED", "path_binding_state": "UNVERIFIED",
                "issue_line_ordinals": ["1"],
            },
        ),
    ]
    for raw_value, wanted in mount_cases:
        actual = parse_mountinfo(raw_value)
        if actual != wanted:
            raise AssertionError(f"mountinfo mismatch: {actual!r} != {wanted!r}")
        _assert_metadata_result(actual, "mountinfo")

    for function in (parse_membership, parse_mountinfo):
        assert_raises(TypeError, lambda function=function: function(None), function.__name__)
        invalid_utf8 = function("\ud800")
        if invalid_utf8["parse_state"] != "INVALID_VALUE" or invalid_utf8["reason_code"] != "NON_UTF8_TEXT":
            raise AssertionError(f"{function.__name__} did not report invalid UTF-8")
        oversized = function("x" * 524_289)
        if oversized["parse_state"] != "LIMIT_REACHED" or oversized["reason_code"] != "INPUT_TOO_LARGE":
            raise AssertionError(f"{function.__name__} did not enforce the 512-KiB bound")
        oversized_utf8 = function("ü" * 262_145)
        if oversized_utf8["parse_state"] != "LIMIT_REACHED" or oversized_utf8["reason_code"] != "INPUT_TOO_LARGE":
            raise AssertionError(f"{function.__name__} did not measure the input bound in UTF-8 bytes")

    membership_limit_path = "/" + ("x" * (524_288 - len("0::/")))
    membership_at_limit = "0::" + membership_limit_path
    if len(membership_at_limit.encode("utf-8")) != 524_288:
        raise AssertionError("membership boundary fixture is not exactly 512 KiB")
    exact_membership = parse_membership(membership_at_limit)
    if exact_membership["parse_state"] != "VALID" or exact_membership["membership_path"] != membership_limit_path:
        raise AssertionError("membership parser rejected or changed an exact 512-KiB path")

    mount_prefix = "1 9 0:1 / /"
    mount_suffix = " rw - cgroup2 none rw"
    mount_at_limit = mount_prefix + ("x" * (524_288 - len(mount_prefix + mount_suffix))) + mount_suffix
    if len(mount_at_limit.encode("utf-8")) != 524_288:
        raise AssertionError("mountinfo boundary fixture is not exactly 512 KiB")
    exact_mountinfo = parse_mountinfo(mount_at_limit)
    if exact_mountinfo["parse_state"] != "VALID" or len(exact_mountinfo["mounts"]) != 1:
        raise AssertionError("mountinfo parser rejected an exact 512-KiB record")
    return len(membership_cases) + len(mount_cases) + 10


def _assert_metadata_result(result: dict[str, object], label: str) -> None:
    try:
        json.dumps(result, allow_nan=False)
    except (TypeError, ValueError) as error:
        raise AssertionError(f"{label} result is not JSON-compatible: {error}") from error
    def inspect(value: object) -> None:
        if isinstance(value, dict):
            if {"raw_value", "raw_line", "read_state"}.intersection(value):
                raise AssertionError(f"{label} result exports raw text or a read state")
            for nested in value.values():
                inspect(nested)
        elif isinstance(value, list):
            for nested in value:
                inspect(nested)

    inspect(result)


def run_behavior_checks(repository_root: Path) -> int:
    module = load_module(repository_root)
    parse = module.parse_resource_value
    cases = [
        ("memory.max", "0", expected("memory.max", "0", "VALID", "FINITE_VALUE", "FINITE", value="0")),
        ("memory.max", "000000000000000000001", expected("memory.max", "000000000000000000001", "VALID", "FINITE_VALUE", "FINITE", value="1")),
        ("memory.max", "0" * 256, expected("memory.max", "0" * 256, "VALID", "FINITE_VALUE", "FINITE", value="0")),
        ("memory.max", "18446744073709551615", expected("memory.max", "18446744073709551615", "VALID", "FINITE_VALUE", "FINITE", value="18446744073709551615")),
        ("memory.max", "18446744073709551616", expected("memory.max", "18446744073709551616", "INVALID_VALUE", "OUT_OF_RANGE")),
        ("memory.current", "18446744073709551615", expected("memory.current", "18446744073709551615", "VALID", "FINITE_VALUE", "FINITE", value="18446744073709551615")),
        ("memory.high", "max", expected("memory.high", "max", "VALID", "UNLIMITED", "UNLIMITED")),
        ("memory.swap.max", " \tmax\r\n", expected("memory.swap.max", " \tmax\r\n", "VALID", "UNLIMITED", "UNLIMITED")),
        ("memory.current", "max", expected("memory.current", "max", "INVALID_VALUE", "INVALID_TOKEN")),
        ("memory.max", "+1", expected("memory.max", "+1", "INVALID_VALUE", "INVALID_TOKEN")),
        ("memory.max", "-1", expected("memory.max", "-1", "INVALID_VALUE", "INVALID_TOKEN")),
        ("memory.max", "1.0", expected("memory.max", "1.0", "INVALID_VALUE", "INVALID_TOKEN")),
        ("memory.max", "١", expected("memory.max", "١", "INVALID_VALUE", "INVALID_TOKEN")),
        ("memory.max", "1\x00", expected("memory.max", "1\x00", "INVALID_VALUE", "INVALID_TOKEN")),
        ("memory.max", " 7\t\r\n", expected("memory.max", " 7\t\r\n", "VALID", "FINITE_VALUE", "FINITE", value="7")),
        ("cpu.max", "100000 100000", expected("cpu.max", "100000 100000", "VALID", "FINITE_VALUE", "FINITE", quota="100000", period="100000", numerator="1", denominator="1")),
        ("cpu.max", "1 18446744073709551615", expected("cpu.max", "1 18446744073709551615", "VALID", "FINITE_VALUE", "FINITE", quota="1", period="18446744073709551615", numerator="1", denominator="18446744073709551615")),
        ("cpu.max", "18446744073709551615 1", expected("cpu.max", "18446744073709551615 1", "VALID", "FINITE_VALUE", "FINITE", quota="18446744073709551615", period="1", numerator="18446744073709551615", denominator="1")),
        ("cpu.max", "max 100000", expected("cpu.max", "max 100000", "VALID", "UNLIMITED", "UNLIMITED", period="100000")),
        ("cpu.max", "1 3", expected("cpu.max", "1 3", "VALID", "FINITE_VALUE", "FINITE", quota="1", period="3", numerator="1", denominator="3")),
        ("cpu.max", "6 4", expected("cpu.max", "6 4", "VALID", "FINITE_VALUE", "FINITE", quota="6", period="4", numerator="3", denominator="2")),
        ("cpu.max", "000000000000000000006 000000000000000000004", expected("cpu.max", "000000000000000000006 000000000000000000004", "VALID", "FINITE_VALUE", "FINITE", quota="6", period="4", numerator="3", denominator="2")),
        ("cpu.max", "100 200 300", expected("cpu.max", "100 200 300", "INVALID_VALUE", "INVALID_FORMAT")),
        ("cpu.max", "100", expected("cpu.max", "100", "INVALID_VALUE", "INVALID_FORMAT")),
        ("cpu.max", "0 100", expected("cpu.max", "0 100", "INVALID_VALUE", "OUT_OF_RANGE")),
        ("cpu.max", "1 0", expected("cpu.max", "1 0", "INVALID_VALUE", "OUT_OF_RANGE")),
        ("cpu.max", "18446744073709551616 1", expected("cpu.max", "18446744073709551616 1", "INVALID_VALUE", "OUT_OF_RANGE")),
        ("cpu.max", "1 18446744073709551616", expected("cpu.max", "1 18446744073709551616", "INVALID_VALUE", "OUT_OF_RANGE")),
        ("cpu.max", "+1 10", expected("cpu.max", "+1 10", "INVALID_VALUE", "INVALID_TOKEN")),
        ("cpu.max", "1\t2", expected("cpu.max", "1\t2", "VALID", "FINITE_VALUE", "FINITE", quota="1", period="2", numerator="1", denominator="2")),
        ("cpu.max", "1\u20032", expected("cpu.max", "1\u20032", "INVALID_VALUE", "INVALID_FORMAT")),
    ]
    for source_key, raw_value, wanted in cases:
        actual = parse(source_key, raw_value)
        if actual != wanted:
            raise AssertionError(f"{source_key} input mismatch: {actual!r} != {wanted!r}")
        if not all(value is None or isinstance(value, str) for value in actual.values()):
            raise AssertionError(f"Non-string JSON value returned for {source_key}: {actual!r}")

    large_digits = "9" * 65_536
    expected_large = expected("memory.max", large_digits, "INVALID_VALUE", "OUT_OF_RANGE")
    if parse("memory.max", large_digits) != expected_large:
        raise AssertionError("Large in-limit token was not rejected before numeric conversion")
    too_large = "1" * 65_537
    if parse("memory.max", too_large) != expected("memory.max", too_large, "LIMIT_REACHED", "INPUT_TOO_LARGE"):
        raise AssertionError("UTF-8 size limit result mismatch")
    multibyte_over = "é" * 32_769
    if parse("memory.max", multibyte_over) != expected("memory.max", multibyte_over, "LIMIT_REACHED", "INPUT_TOO_LARGE"):
        raise AssertionError("UTF-8 byte limit was not measured in bytes")
    if parse("memory.max", "\ud800") != expected("memory.max", "\ud800", "INVALID_VALUE", "NON_UTF8_TEXT"):
        raise AssertionError("Non-UTF-8 Python string result mismatch")

    assert_raises(ValueError, lambda: parse("memory.maxx", "1"), "unknown source key")
    assert_raises(TypeError, lambda: parse(None, "1"), "non-string source key")
    assert_raises(TypeError, lambda: parse("memory.max", None), "non-string raw value")
    structured_cases = [
        (
            "parse_cpuset_cpus_effective",
            "0-2,2-5,6,2147483647",
            {
                "source_key": "cpuset.cpus.effective",
                "raw_value": "0-2,2-5,6,2147483647",
                "parse_state": "VALID",
                "reason_code": "FINITE_VALUE",
                "intervals": [{"start": "0", "end": "6"}, {"start": "2147483647", "end": "2147483647"}],
                "cpu_count": "8",
            },
        ),
        (
            "parse_cpuset_cpus_effective",
            "0-2147483647",
            {
                "source_key": "cpuset.cpus.effective",
                "raw_value": "0-2147483647",
                "parse_state": "VALID",
                "reason_code": "FINITE_VALUE",
                "intervals": [{"start": "0", "end": "2147483647"}],
                "cpu_count": "2147483648",
            },
        ),
        (
            "parse_cpuset_cpus_effective",
            "0001-0003,3-4",
            {
                "source_key": "cpuset.cpus.effective",
                "raw_value": "0001-0003,3-4",
                "parse_state": "VALID",
                "reason_code": "FINITE_VALUE",
                "intervals": [{"start": "1", "end": "4"}],
                "cpu_count": "4",
            },
        ),
        (
            "parse_cpuset_cpus_effective",
            " \t\r\n",
            {
                "source_key": "cpuset.cpus.effective",
                "raw_value": " \t\r\n",
                "parse_state": "EMPTY_OBSERVATION",
                "reason_code": "EMPTY_OBSERVATION",
                "intervals": [],
                "cpu_count": None,
            },
        ),
        ("parse_cpuset_cpus_effective", "0,,1", {"source_key": "cpuset.cpus.effective", "raw_value": "0,,1", "parse_state": "INVALID_VALUE", "reason_code": "INVALID_FORMAT", "intervals": None, "cpu_count": None}),
        ("parse_cpuset_cpus_effective", "4-2", {"source_key": "cpuset.cpus.effective", "raw_value": "4-2", "parse_state": "INVALID_VALUE", "reason_code": "INVALID_RANGE", "intervals": None, "cpu_count": None}),
        ("parse_cpuset_cpus_effective", "2147483648", {"source_key": "cpuset.cpus.effective", "raw_value": "2147483648", "parse_state": "INVALID_VALUE", "reason_code": "OUT_OF_RANGE", "intervals": None, "cpu_count": None}),
        ("parse_cpuset_cpus_effective", "1\x00", {"source_key": "cpuset.cpus.effective", "raw_value": "1\x00", "parse_state": "INVALID_VALUE", "reason_code": "INVALID_TOKEN", "intervals": None, "cpu_count": None}),
        ("parse_cpuset_cpus_effective", "١", {"source_key": "cpuset.cpus.effective", "raw_value": "١", "parse_state": "INVALID_VALUE", "reason_code": "INVALID_FORMAT", "intervals": None, "cpu_count": None}),
        (
            "parse_memory_events",
            "low 0\nhigh 18446744073709551615\nfuture_event 0007\n",
            {
                "source_key": "memory.events",
                "raw_value": "low 0\nhigh 18446744073709551615\nfuture_event 0007\n",
                "parse_state": "VALID",
                "reason_code": "COUNTERS_PARSED",
                "counters": [
                    {"key": "low", "value": "0", "raw_value": "0", "key_state": "MAPPED", "unit": "events"},
                    {"key": "high", "value": "18446744073709551615", "raw_value": "18446744073709551615", "key_state": "MAPPED", "unit": "events"},
                    {"key": "future_event", "value": "7", "raw_value": "0007", "key_state": "UNMAPPED_KEY", "unit": None},
                ],
                "event_scope": "UNVERIFIED",
            },
        ),
        (
            "parse_cpu_stat",
            "usage_usec 12\nnr_periods 3\nfuture_key 0004",
            {
                "source_key": "cpu.stat",
                "raw_value": "usage_usec 12\nnr_periods 3\nfuture_key 0004",
                "parse_state": "VALID",
                "reason_code": "COUNTERS_PARSED",
                "counters": [
                    {"key": "usage_usec", "value": "12", "raw_value": "12", "key_state": "MAPPED", "unit": "microseconds"},
                    {"key": "nr_periods", "value": "3", "raw_value": "3", "key_state": "MAPPED", "unit": "count"},
                    {"key": "future_key", "value": "4", "raw_value": "0004", "key_state": "UNMAPPED_KEY", "unit": None},
                ],
            },
        ),
        ("parse_memory_events", "low 1\nlow 2", {"source_key": "memory.events", "raw_value": "low 1\nlow 2", "parse_state": "INVALID_VALUE", "reason_code": "DUPLICATE_KEY", "counters": None, "event_scope": "UNVERIFIED"}),
        ("parse_cpu_stat", "usage_usec 1 extra", {"source_key": "cpu.stat", "raw_value": "usage_usec 1 extra", "parse_state": "INVALID_VALUE", "reason_code": "INVALID_FORMAT", "counters": None}),
        ("parse_cpu_stat", "usage_usec", {"source_key": "cpu.stat", "raw_value": "usage_usec", "parse_state": "INVALID_VALUE", "reason_code": "INVALID_FORMAT", "counters": None}),
        ("parse_memory_events", "oom 18446744073709551616", {"source_key": "memory.events", "raw_value": "oom 18446744073709551616", "parse_state": "INVALID_VALUE", "reason_code": "OUT_OF_RANGE", "counters": None, "event_scope": "UNVERIFIED"}),
        ("parse_cpu_stat", "nr_periods +1", {"source_key": "cpu.stat", "raw_value": "nr_periods +1", "parse_state": "INVALID_VALUE", "reason_code": "INVALID_TOKEN", "counters": None}),
        ("parse_memory_events", "low 1\x00", {"source_key": "memory.events", "raw_value": "low 1\x00", "parse_state": "INVALID_VALUE", "reason_code": "INVALID_TOKEN", "counters": None, "event_scope": "UNVERIFIED"}),
        ("parse_cpu_stat", "usage_usec ١", {"source_key": "cpu.stat", "raw_value": "usage_usec ١", "parse_state": "INVALID_VALUE", "reason_code": "INVALID_TOKEN", "counters": None}),
        ("parse_cgroup_type", "domain\n", {"source_key": "cgroup.type", "raw_value": "domain\n", "parse_state": "VALID", "reason_code": "SUPPORTED_DOMAIN", "observed_type": "domain", "layout_state": "SUPPORTED_DOMAIN"}),
        ("parse_cgroup_type", "threaded", {"source_key": "cgroup.type", "raw_value": "threaded", "parse_state": "UNSUPPORTED_LAYOUT", "reason_code": "UNSUPPORTED_LAYOUT", "observed_type": "threaded", "layout_state": "UNSUPPORTED_LAYOUT"}),
        ("parse_cgroup_type", "domain threaded", {"source_key": "cgroup.type", "raw_value": "domain threaded", "parse_state": "UNSUPPORTED_LAYOUT", "reason_code": "UNSUPPORTED_LAYOUT", "observed_type": "domain threaded", "layout_state": "UNSUPPORTED_LAYOUT"}),
        ("parse_cgroup_type", "domain (invalid)", {"source_key": "cgroup.type", "raw_value": "domain (invalid)", "parse_state": "UNSUPPORTED_LAYOUT", "reason_code": "UNSUPPORTED_LAYOUT", "observed_type": "domain (invalid)", "layout_state": "UNSUPPORTED_LAYOUT"}),
        ("parse_cgroup_type", "domain invalid", {"source_key": "cgroup.type", "raw_value": "domain invalid", "parse_state": "UNSUPPORTED_LAYOUT", "reason_code": "UNSUPPORTED_LAYOUT", "observed_type": "domain invalid", "layout_state": "UNSUPPORTED_LAYOUT"}),
        ("parse_cgroup_type", "", {"source_key": "cgroup.type", "raw_value": "", "parse_state": "TYPE_UNVERIFIED", "reason_code": "TYPE_UNVERIFIED", "observed_type": None, "layout_state": "UNVERIFIED"}),
        ("parse_cgroup_type", "future-type", {"source_key": "cgroup.type", "raw_value": "future-type", "parse_state": "TYPE_UNVERIFIED", "reason_code": "TYPE_UNVERIFIED", "observed_type": "future-type", "layout_state": "UNVERIFIED"}),
        ("parse_cgroup_type", "domain\x00", {"source_key": "cgroup.type", "raw_value": "domain\x00", "parse_state": "INVALID_VALUE", "reason_code": "INVALID_TOKEN", "observed_type": None, "layout_state": "UNVERIFIED"}),
    ]
    for function_name, raw_value, wanted in structured_cases:
        actual = getattr(module, function_name)(raw_value)
        if actual != wanted:
            raise AssertionError(f"{function_name} input mismatch: {actual!r} != {wanted!r}")
        try:
            json.dumps(actual, allow_nan=False)
        except (TypeError, ValueError) as error:
            raise AssertionError(f"{function_name} result is not JSON-compatible: {error}") from error

    boundary_cases = [
        (
            "parse_cpuset_cpus_effective",
            "0" + (" " * 65_535),
            {
                "source_key": "cpuset.cpus.effective",
                "raw_value": "0" + (" " * 65_535),
                "parse_state": "VALID",
                "reason_code": "FINITE_VALUE",
                "intervals": [{"start": "0", "end": "0"}],
                "cpu_count": "1",
            },
        ),
        (
            "parse_memory_events",
            "low 0" + (" " * 65_531),
            {
                "source_key": "memory.events",
                "raw_value": "low 0" + (" " * 65_531),
                "parse_state": "VALID",
                "reason_code": "COUNTERS_PARSED",
                "counters": [{"key": "low", "value": "0", "raw_value": "0", "key_state": "MAPPED", "unit": "events"}],
                "event_scope": "UNVERIFIED",
            },
        ),
        (
            "parse_cpu_stat",
            "usage_usec 0" + (" " * 65_524),
            {
                "source_key": "cpu.stat",
                "raw_value": "usage_usec 0" + (" " * 65_524),
                "parse_state": "VALID",
                "reason_code": "COUNTERS_PARSED",
                "counters": [{"key": "usage_usec", "value": "0", "raw_value": "0", "key_state": "MAPPED", "unit": "microseconds"}],
            },
        ),
        (
            "parse_cgroup_type",
            "domain" + (" " * 65_530),
            {
                "source_key": "cgroup.type",
                "raw_value": "domain" + (" " * 65_530),
                "parse_state": "VALID",
                "reason_code": "SUPPORTED_DOMAIN",
                "observed_type": "domain",
                "layout_state": "SUPPORTED_DOMAIN",
            },
        ),
    ]
    for function_name, raw_value, wanted in boundary_cases:
        if len(raw_value.encode("utf-8")) != 65_536:
            raise AssertionError(f"{function_name} boundary fixture is not exactly 64 KiB")
        actual = getattr(module, function_name)(raw_value)
        if actual != wanted:
            raise AssertionError(f"{function_name} 64-KiB boundary mismatch")

    functions = [getattr(module, name) for name in (
        "parse_cpuset_cpus_effective", "parse_memory_events", "parse_cpu_stat", "parse_cgroup_type"
    )]
    for function in functions:
        assert_raises(TypeError, lambda function=function: function(None), function.__name__)
    for function in functions:
        oversized = function("1" * 65_537)
        if oversized["parse_state"] != "LIMIT_REACHED" or oversized["reason_code"] != "INPUT_TOO_LARGE":
            raise AssertionError(f"{function.__name__} did not enforce the UTF-8 input limit")
        invalid_utf8 = function("\ud800")
        if invalid_utf8["parse_state"] != "INVALID_VALUE" or invalid_utf8["reason_code"] != "NON_UTF8_TEXT":
            raise AssertionError(f"{function.__name__} did not reject a non-UTF-8 Python string")
    return len(cases) + len(structured_cases) + len(boundary_cases) + 12 + run_metadata_checks(repository_root)


def validate_source(repository_root: Path) -> None:
    module_path = repository_root / MODULE_RELATIVE_PATH
    if not module_path.is_file():
        raise AssertionError(f"Missing parser module: {MODULE_RELATIVE_PATH}")
    source = module_path.read_text(encoding="utf-8")
    for required in (
        "def parse_resource_value(source_key: str, raw_value: str)",
        "def parse_cpuset_cpus_effective(raw_value: str)",
        "def parse_memory_events(raw_value: str)",
        "def parse_cpu_stat(raw_value: str)",
        "def parse_cgroup_type(raw_value: str)",
        "_MAX_INPUT_BYTES: Final = 64 * 1024",
        'return "LIMIT_REACHED", "INPUT_TOO_LARGE"',
        "math.gcd(quota, period)",
        '"sock_throttled"',
        '"burst_usec": "microseconds"',
    ):
        if required not in source:
            raise AssertionError(f"Parser source is missing required contract marker: {required}")

    metadata_path = repository_root / METADATA_MODULE_RELATIVE_PATH
    if not metadata_path.is_file():
        raise AssertionError(f"Missing metadata parser module: {METADATA_MODULE_RELATIVE_PATH}")
    metadata_source = metadata_path.read_text(encoding="utf-8")
    for required in (
        "def parse_v2_membership(raw_value: str)",
        "def parse_cgroup2_mountinfo(raw_value: str)",
        "_MAX_INPUT_BYTES: Final = 512 * 1024",
        '"DUPLICATE_MOUNT_ID"',
        'path_binding_state: str = "UNVERIFIED"',
    ):
        if required not in metadata_source:
            raise AssertionError(f"Metadata parser source is missing contract marker: {required}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository-root", type=Path, required=True)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    root = args.repository_root.resolve()
    if args.self_test:
        count = run_behavior_checks(root)
        print(f"Linux cgroup scalar parser self-test passed: cases={count}")
        return 0
    validate_source(root)
    print("Linux cgroup scalar parser source contract: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
