"""Parse bounded scalar values from Linux cgroup-v2 resource files."""

from __future__ import annotations

import math
import re
from typing import Final


_U64_MAX: Final = 18_446_744_073_709_551_615
_MAX_INPUT_BYTES: Final = 64 * 1024
_MEMORY_KEYS: Final = frozenset(
    {"memory.max", "memory.high", "memory.swap.max", "memory.current"}
)
_UNLIMITED_MEMORY_KEYS: Final = frozenset(
    {"memory.max", "memory.high", "memory.swap.max"}
)
_ASCII_DIGITS = re.compile(r"[0-9]+\Z")
_ASCII_ID_OR_RANGE = re.compile(r"([0-9]+)(?:-([0-9]+))?\Z")
_ASCII_COUNTER_KEY = re.compile(r"[A-Za-z0-9_]+\Z")
_ASCII_TOKEN_SEPARATOR = re.compile(r"[ \t\r\n]+")
_OUTER_ASCII_WHITESPACE = " \t\r\n"
_U31_MAX: Final = 2_147_483_647

_MEMORY_EVENT_KEYS: Final = frozenset(
    {"low", "high", "max", "oom", "oom_kill", "oom_group_kill", "sock_throttled"}
)
_CPU_STAT_UNITS: Final = {
    "usage_usec": "microseconds",
    "user_usec": "microseconds",
    "system_usec": "microseconds",
    "throttled_usec": "microseconds",
    "burst_usec": "microseconds",
    "nr_periods": "count",
    "nr_throttled": "count",
    "nr_bursts": "count",
}


def _result(
    source_key: str,
    raw_value: str,
    *,
    parse_state: str,
    reason_code: str,
    value_kind: str = "NONE",
    value: str | None = None,
    quota_us: str | None = None,
    period_us: str | None = None,
    ratio_numerator: str | None = None,
    ratio_denominator: str | None = None,
) -> dict[str, str | None]:
    return {
        "source_key": source_key,
        "raw_value": raw_value,
        "parse_state": parse_state,
        "reason_code": reason_code,
        "value_kind": value_kind,
        "value": value,
        "quota_us": quota_us,
        "period_us": period_us,
        "ratio_numerator": ratio_numerator,
        "ratio_denominator": ratio_denominator,
    }


def _invalid(source_key: str, raw_value: str, reason_code: str) -> dict[str, str | None]:
    return _result(
        source_key,
        raw_value,
        parse_state="INVALID_VALUE",
        reason_code=reason_code,
    )


def _input_problem(raw_value: str) -> tuple[str, str] | None:
    """Return a regular parse state/reason before parsing bounded text."""
    try:
        raw_size = len(raw_value.encode("utf-8"))
    except UnicodeEncodeError:
        return "INVALID_VALUE", "NON_UTF8_TEXT"
    if raw_size > _MAX_INPUT_BYTES:
        return "LIMIT_REACHED", "INPUT_TOO_LARGE"
    return None


def _parse_u64(numeric_text: str) -> tuple[int | None, str | None]:
    """Return (value, error reason); avoid converting oversized tokens."""
    if not _ASCII_DIGITS.fullmatch(numeric_text):
        return None, "INVALID_TOKEN"
    normalized = numeric_text.lstrip("0") or "0"
    if len(normalized) > 20:
        return None, "OUT_OF_RANGE"
    number = int(normalized)
    if number > _U64_MAX:
        return None, "OUT_OF_RANGE"
    return number, None


def parse_resource_value(source_key: str, raw_value: str) -> dict[str, str | None]:
    """Parse one bounded memory scalar or ``cpu.max`` value.

    All result fields are strings or ``None`` so the result can be serialized
    to JSON without converting unsigned values through a lossy numeric type.
    """
    if not isinstance(source_key, str):
        raise TypeError("source_key must be str")
    if source_key not in _MEMORY_KEYS and source_key != "cpu.max":
        raise ValueError(f"unknown source_key: {source_key!r}")
    if not isinstance(raw_value, str):
        raise TypeError("raw_value must be str")

    problem = _input_problem(raw_value)
    if problem is not None:
        parse_state, reason_code = problem
        return _result(
            source_key,
            raw_value,
            parse_state=parse_state,
            reason_code=reason_code,
        )

    text = raw_value.strip(_OUTER_ASCII_WHITESPACE)
    if source_key in _MEMORY_KEYS:
        if text == "max" and source_key in _UNLIMITED_MEMORY_KEYS:
            return _result(
                source_key,
                raw_value,
                parse_state="VALID",
                reason_code="UNLIMITED",
                value_kind="UNLIMITED",
            )
        number, error = _parse_u64(text)
        if error:
            return _invalid(source_key, raw_value, error)
        return _result(
            source_key,
            raw_value,
            parse_state="VALID",
            reason_code="FINITE_VALUE",
            value_kind="FINITE",
            value=str(number),
        )

    tokens = _ASCII_TOKEN_SEPARATOR.split(text) if text else []
    if len(tokens) != 2:
        return _invalid(source_key, raw_value, "INVALID_FORMAT")
    quota_token, period_token = tokens
    period, period_error = _parse_u64(period_token)
    if period_error:
        return _invalid(source_key, raw_value, period_error)
    if period == 0:
        return _invalid(source_key, raw_value, "OUT_OF_RANGE")

    if quota_token == "max":
        return _result(
            source_key,
            raw_value,
            parse_state="VALID",
            reason_code="UNLIMITED",
            value_kind="UNLIMITED",
            period_us=str(period),
        )

    quota, quota_error = _parse_u64(quota_token)
    if quota_error:
        return _invalid(source_key, raw_value, quota_error)
    if quota == 0:
        return _invalid(source_key, raw_value, "OUT_OF_RANGE")
    divisor = math.gcd(quota, period)
    return _result(
        source_key,
        raw_value,
        parse_state="VALID",
        reason_code="FINITE_VALUE",
        value_kind="FINITE",
        quota_us=str(quota),
        period_us=str(period),
        ratio_numerator=str(quota // divisor),
        ratio_denominator=str(period // divisor),
    )


def _structured_result(
    source_key: str,
    raw_value: str,
    parse_state: str,
    reason_code: str,
    **fields: object,
) -> dict[str, object]:
    return {
        "source_key": source_key,
        "raw_value": raw_value,
        "parse_state": parse_state,
        "reason_code": reason_code,
        **fields,
    }


def _cpuset_error(
    raw_value: str, parse_state: str, reason_code: str
) -> dict[str, object]:
    return _structured_result(
        "cpuset.cpus.effective",
        raw_value,
        parse_state,
        reason_code,
        intervals=None,
        cpu_count=None,
    )


def parse_cpuset_cpus_effective(raw_value: str) -> dict[str, object]:
    """Parse and compact an effective CPU list without expanding intervals."""
    if not isinstance(raw_value, str):
        raise TypeError("raw_value must be str")
    problem = _input_problem(raw_value)
    if problem is not None:
        return _cpuset_error(raw_value, *problem)
    if "\x00" in raw_value:
        return _cpuset_error(raw_value, "INVALID_VALUE", "INVALID_TOKEN")

    text = raw_value.strip(_OUTER_ASCII_WHITESPACE)
    if not text:
        return _structured_result(
            "cpuset.cpus.effective",
            raw_value,
            "EMPTY_OBSERVATION",
            "EMPTY_OBSERVATION",
            intervals=[],
            cpu_count=None,
        )

    intervals: list[tuple[int, int]] = []
    for item in text.split(","):
        match = _ASCII_ID_OR_RANGE.fullmatch(item)
        if match is None:
            return _cpuset_error(raw_value, "INVALID_VALUE", "INVALID_FORMAT")
        first, first_error = _parse_u64(match.group(1))
        second_text = match.group(2)
        second, second_error = (
            _parse_u64(second_text) if second_text is not None else (first, None)
        )
        if first_error or second_error:
            reason_code = first_error or second_error or "INVALID_TOKEN"
            return _cpuset_error(raw_value, "INVALID_VALUE", reason_code)
        if first > _U31_MAX or second > _U31_MAX:
            return _cpuset_error(raw_value, "INVALID_VALUE", "OUT_OF_RANGE")
        if first > second:
            return _cpuset_error(raw_value, "INVALID_VALUE", "INVALID_RANGE")
        intervals.append((first, second))

    intervals.sort()
    merged: list[tuple[int, int]] = []
    for start, end in intervals:
        if merged and start <= merged[-1][1] + 1:
            previous_start, previous_end = merged[-1]
            merged[-1] = (previous_start, max(previous_end, end))
        else:
            merged.append((start, end))
    cpu_count = sum(end - start + 1 for start, end in merged)
    return _structured_result(
        "cpuset.cpus.effective",
        raw_value,
        "VALID",
        "FINITE_VALUE",
        intervals=[{"start": str(start), "end": str(end)} for start, end in merged],
        cpu_count=str(cpu_count),
    )


def _parse_keyed_counters(
    source_key: str, raw_value: str, known_units: dict[str, str]
) -> dict[str, object]:
    if not isinstance(raw_value, str):
        raise TypeError("raw_value must be str")
    problem = _input_problem(raw_value)
    if problem is not None:
        parse_state, reason_code = problem
        return _structured_result(
            source_key,
            raw_value,
            parse_state,
            reason_code,
            counters=None,
            **({"event_scope": "UNVERIFIED"} if source_key == "memory.events" else {}),
        )
    if "\x00" in raw_value:
        return _structured_result(
            source_key,
            raw_value,
            "INVALID_VALUE",
            "INVALID_TOKEN",
            counters=None,
            **({"event_scope": "UNVERIFIED"} if source_key == "memory.events" else {}),
        )

    counters: list[dict[str, str | None]] = []
    seen: set[str] = set()
    for line in raw_value.split("\n"):
        line = line.strip(" \t\r")
        if not line:
            continue
        tokens = _ASCII_TOKEN_SEPARATOR.split(line)
        if len(tokens) != 2:
            return _structured_result(
                source_key,
                raw_value,
                "INVALID_VALUE",
                "INVALID_FORMAT",
                counters=None,
                **({"event_scope": "UNVERIFIED"} if source_key == "memory.events" else {}),
            )
        key, numeric_text = tokens
        if not _ASCII_COUNTER_KEY.fullmatch(key):
            return _structured_result(
                source_key,
                raw_value,
                "INVALID_VALUE",
                "INVALID_TOKEN",
                counters=None,
                **({"event_scope": "UNVERIFIED"} if source_key == "memory.events" else {}),
            )
        if key in seen:
            return _structured_result(
                source_key,
                raw_value,
                "INVALID_VALUE",
                "DUPLICATE_KEY",
                counters=None,
                **({"event_scope": "UNVERIFIED"} if source_key == "memory.events" else {}),
            )
        value, value_error = _parse_u64(numeric_text)
        if value_error:
            return _structured_result(
                source_key,
                raw_value,
                "INVALID_VALUE",
                value_error,
                counters=None,
                **({"event_scope": "UNVERIFIED"} if source_key == "memory.events" else {}),
            )
        seen.add(key)
        unit = known_units.get(key)
        counters.append(
            {
                "key": key,
                "value": str(value),
                "raw_value": numeric_text,
                "key_state": "MAPPED" if unit is not None else "UNMAPPED_KEY",
                "unit": unit,
            }
        )

    return _structured_result(
        source_key,
        raw_value,
        "VALID",
        "COUNTERS_PARSED",
        counters=counters,
        **({"event_scope": "UNVERIFIED"} if source_key == "memory.events" else {}),
    )


def parse_memory_events(raw_value: str) -> dict[str, object]:
    """Parse bounded memory.events counters; event scope remains unverified."""
    return _parse_keyed_counters(
        "memory.events",
        raw_value,
        {key: "events" for key in _MEMORY_EVENT_KEYS},
    )


def parse_cpu_stat(raw_value: str) -> dict[str, object]:
    """Parse bounded cpu.stat counters with only documented units mapped."""
    return _parse_keyed_counters("cpu.stat", raw_value, _CPU_STAT_UNITS)


def parse_cgroup_type(raw_value: str) -> dict[str, object]:
    """Classify observed cgroup.type text without inferring a missing type."""
    if not isinstance(raw_value, str):
        raise TypeError("raw_value must be str")
    problem = _input_problem(raw_value)
    if problem is not None:
        parse_state, reason_code = problem
        return _structured_result(
            "cgroup.type",
            raw_value,
            parse_state,
            reason_code,
            observed_type=None,
            layout_state="UNVERIFIED",
        )
    if "\x00" in raw_value:
        return _structured_result(
            "cgroup.type",
            raw_value,
            "INVALID_VALUE",
            "INVALID_TOKEN",
            observed_type=None,
            layout_state="UNVERIFIED",
        )

    observed = raw_value.strip(_OUTER_ASCII_WHITESPACE)
    if observed == "domain":
        return _structured_result(
            "cgroup.type",
            raw_value,
            "VALID",
            "SUPPORTED_DOMAIN",
            observed_type=observed,
            layout_state="SUPPORTED_DOMAIN",
        )
    if observed in {
        "threaded",
        "domain threaded",
        "domain invalid",
        "domain (invalid)",
    }:
        return _structured_result(
            "cgroup.type",
            raw_value,
            "UNSUPPORTED_LAYOUT",
            "UNSUPPORTED_LAYOUT",
            observed_type=observed,
            layout_state="UNSUPPORTED_LAYOUT",
        )
    return _structured_result(
        "cgroup.type",
        raw_value,
        "TYPE_UNVERIFIED",
        "TYPE_UNVERIFIED",
        observed_type=observed or None,
        layout_state="UNVERIFIED",
    )
