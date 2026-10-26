"""Focused behavior checks for the pure Linux cgroup scalar parser."""

from __future__ import annotations

import argparse
import importlib.util
from pathlib import Path
from typing import Any


MODULE_RELATIVE_PATH = Path("Code/Tools/Linux_Cgroup_Values.py")


def load_parser(repository_root: Path):
    module_path = repository_root / MODULE_RELATIVE_PATH
    spec = importlib.util.spec_from_file_location("linux_cgroup_values", module_path)
    if spec is None or spec.loader is None:
        raise AssertionError(f"Cannot load parser module: {MODULE_RELATIVE_PATH}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.parse_resource_value


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
) -> dict[str, str | None]:
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
    parse = load_parser(repository_root)
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
    return len(cases) + 4


def validate_source(repository_root: Path) -> None:
    module_path = repository_root / MODULE_RELATIVE_PATH
    if not module_path.is_file():
        raise AssertionError(f"Missing parser module: {MODULE_RELATIVE_PATH}")
    source = module_path.read_text(encoding="utf-8")
    for required in (
        "def parse_resource_value(source_key: str, raw_value: str)",
        "_MAX_INPUT_BYTES: Final = 64 * 1024",
        'parse_state="LIMIT_REACHED"',
        "math.gcd(quota, period)",
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
