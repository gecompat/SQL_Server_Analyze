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
_ASCII_TOKEN_SEPARATOR = re.compile(r"[ \t\r\n]+")
_OUTER_ASCII_WHITESPACE = " \t\r\n"


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

    try:
        raw_size = len(raw_value.encode("utf-8"))
    except UnicodeEncodeError:
        return _invalid(source_key, raw_value, "NON_UTF8_TEXT")
    if raw_size > _MAX_INPUT_BYTES:
        return _result(
            source_key,
            raw_value,
            parse_state="LIMIT_REACHED",
            reason_code="INPUT_TOO_LARGE",
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
