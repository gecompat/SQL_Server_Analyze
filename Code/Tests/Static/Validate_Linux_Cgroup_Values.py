"""Focused behavior checks for the pure Linux cgroup scalar parser."""

from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path
from typing import Any


MODULE_RELATIVE_PATH = Path("Code/Tools/Linux_Cgroup_Values.py")


def load_module(repository_root: Path):
    module_path = repository_root / MODULE_RELATIVE_PATH
    spec = importlib.util.spec_from_file_location("linux_cgroup_values", module_path)
    if spec is None or spec.loader is None:
        raise AssertionError(f"Cannot load parser module: {MODULE_RELATIVE_PATH}")
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
    return len(cases) + len(structured_cases) + len(boundary_cases) + 12


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
