"""Validate the bounded, read-only SSIS reported-metrics v1 profile."""

from __future__ import annotations

import argparse
from datetime import datetime
import json
import re
import sys
from pathlib import Path
from typing import Any


MAX_INPUT_BYTES = 4 * 1024 * 1024
MAX_DEFINITIONS = 256
MAX_SERIES = 1024
MAX_OBSERVATIONS = 10000
MAX_DEPTH = 16
MAX_TEXT = 256
DECIMAL_RE = re.compile(r"(?:0|[1-9][0-9]{0,37})\Z", re.ASCII)
POSITIVE_RE = re.compile(r"[1-9][0-9]{0,37}\Z", re.ASCII)
IDENTIFIER_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}\Z", re.ASCII)
VERSION_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9.+-]{0,63}\Z", re.ASCII)
COMMIT_RE = re.compile(r"[0-9a-f]{40}\Z", re.ASCII)
HASH_RE = re.compile(r"[0-9a-f]{64}\Z", re.ASCII)
KINDS = {"DELTA", "CUMULATIVE", "GAUGE", "FINAL"}


class ReportError(ValueError):
    """A report violates the closed v1 profile."""


def _pairs_no_duplicates(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ReportError("DUPLICATE_JSON_PROPERTY")
        result[key] = value
    return result


def _reject_number(value: str) -> None:
    raise ReportError("JSON_NUMERIC_LITERAL_NOT_ALLOWED")


def _check_tree(value: Any, depth: int = 0) -> None:
    if depth > MAX_DEPTH:
        raise ReportError("MAXIMUM_JSON_DEPTH_EXCEEDED")
    if isinstance(value, str):
        if len(value) > MAX_TEXT:
            raise ReportError("TEXT_LIMIT_EXCEEDED")
    elif isinstance(value, list):
        for item in value:
            _check_tree(item, depth + 1)
    elif isinstance(value, dict):
        for key, item in value.items():
            if not isinstance(key, str) or len(key) > MAX_TEXT:
                raise ReportError("PROPERTY_NAME_LIMIT_EXCEEDED")
            _check_tree(item, depth + 1)
    elif value is not None and not isinstance(value, bool):
        raise ReportError("UNSUPPORTED_JSON_VALUE")


def _object(value: Any, required: set[str], optional: set[str] = frozenset()) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ReportError("OBJECT_REQUIRED")
    keys = set(value)
    if not required <= keys:
        raise ReportError("REQUIRED_PROPERTY_MISSING")
    if keys - required - set(optional):
        raise ReportError("UNKNOWN_PROPERTY")
    return value


def _string(value: Any, *, identifier: bool = False, nonempty: bool = True) -> str:
    if not isinstance(value, str) or (nonempty and not value) or len(value) > MAX_TEXT:
        raise ReportError("STRING_REQUIRED")
    if identifier and not IDENTIFIER_RE.fullmatch(value):
        raise ReportError("INVALID_IDENTIFIER")
    return value


def _decimal(value: Any, *, positive: bool = False) -> int:
    pattern = POSITIVE_RE if positive else DECIMAL_RE
    if not isinstance(value, str) or not pattern.fullmatch(value):
        raise ReportError("NONCANONICAL_INTEGER_TEXT")
    return int(value)


def _timestamp(value: Any) -> str:
    text = _string(value)
    if not re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(?:\.[0-9]{1,6})?Z", text, re.ASCII):
        raise ReportError("INVALID_UTC_TIMESTAMP")
    try:
        datetime.fromisoformat(text[:-1] + "+00:00")
    except ValueError as exc:
        raise ReportError("INVALID_UTC_TIMESTAMP") from exc
    return text


def parse_report(raw: bytes) -> dict[str, Any]:
    """Parse a report with resource bounds and reject ambiguous JSON encodings."""
    if len(raw) > MAX_INPUT_BYTES:
        raise ReportError("INPUT_SIZE_LIMIT_EXCEEDED")
    try:
        document = json.loads(
            raw.decode("utf-8"),
            object_pairs_hook=_pairs_no_duplicates,
            parse_int=_reject_number,
            parse_float=_reject_number,
            parse_constant=_reject_number,
        )
    except (UnicodeDecodeError, json.JSONDecodeError, RecursionError) as exc:
        raise ReportError("INVALID_JSON") from exc
    _check_tree(document)
    return validate_document(document)


def validate_document(document: Any) -> dict[str, Any]:
    root = _object(document, {"profile", "metricProducer", "modelReference", "execution", "definitions", "scopes", "series"})
    if root["profile"] != "ssis-reported-metrics/v1":
        raise ReportError("UNSUPPORTED_PROFILE")

    producer = _object(root["metricProducer"], {"id", "version", "sourceCommit", "buildSha256"})
    _string(producer["id"], identifier=True)
    if not isinstance(producer["version"], str) or not VERSION_RE.fullmatch(producer["version"]):
        raise ReportError("INVALID_PRODUCER_VERSION")
    if not isinstance(producer["sourceCommit"], str) or not COMMIT_RE.fullmatch(producer["sourceCommit"]):
        raise ReportError("INVALID_SOURCE_COMMIT")
    if not isinstance(producer["buildSha256"], str) or not HASH_RE.fullmatch(producer["buildSha256"]):
        raise ReportError("INVALID_BUILD_HASH")

    model = _object(root["modelReference"], {"sourceSha256", "packageNodeId"})
    if not isinstance(model["sourceSha256"], str) or not HASH_RE.fullmatch(model["sourceSha256"]):
        raise ReportError("INVALID_MODEL_HASH")
    _string(model["packageNodeId"], identifier=True)

    execution = _object(root["execution"], {"id", "captureHandoverId"})
    _string(execution["id"], identifier=True)
    _string(execution["captureHandoverId"], identifier=True)

    definitions = root["definitions"]
    scopes = root["scopes"]
    series = root["series"]
    if not isinstance(definitions, list) or not 1 <= len(definitions) <= MAX_DEFINITIONS:
        raise ReportError("DEFINITION_COUNT_OUT_OF_RANGE")
    if not isinstance(scopes, list) or not 1 <= len(scopes) <= MAX_SERIES:
        raise ReportError("SCOPE_COUNT_OUT_OF_RANGE")
    if not isinstance(series, list) or not 1 <= len(series) <= MAX_SERIES:
        raise ReportError("SERIES_COUNT_OUT_OF_RANGE")

    definition_map: dict[tuple[str, str], dict[str, Any]] = {}
    definition_ids: set[str] = set()
    for item in definitions:
        definition = _object(item, {"id", "definitionVersion", "kind", "unit"}, {"selectionRule"})
        metric_id = _string(definition["id"], identifier=True)
        version = _string(definition["definitionVersion"], identifier=True)
        kind = definition["kind"]
        if not isinstance(kind, str) or kind not in KINDS:
            raise ReportError("INVALID_METRIC_KIND")
        unit = _string(definition["unit"], identifier=True)
        if unit.casefold() == "number":
            raise ReportError("NONCANONICAL_UNIT")
        if (kind == "GAUGE") != ("selectionRule" in definition):
            raise ReportError("GAUGE_SELECTION_RULE_CONSTRAINT")
        if "selectionRule" in definition:
            _string(definition["selectionRule"], identifier=True)
        key = (metric_id, version)
        if key in definition_map or metric_id in definition_ids:
            raise ReportError("DUPLICATE_OR_CONFLICTING_DEFINITION")
        definition_ids.add(metric_id)
        definition_map[key] = {"id": metric_id, "definitionVersion": version, "kind": kind, "unit": unit}

    scope_ids: set[str] = set()
    for item in scopes:
        scope = _object(item, {"id"})
        scope_id = _string(scope["id"], identifier=True)
        if scope_id in scope_ids:
            raise ReportError("DUPLICATE_SCOPE")
        scope_ids.add(scope_id)

    declared_observation_count = 0
    for item in series:
        if not isinstance(item, dict) or "observations" not in item:
            continue
        observations_value = item["observations"]
        if not isinstance(observations_value, list):
            raise ReportError("OBSERVATION_ARRAY_REQUIRED")
        declared_observation_count += len(observations_value)
        if declared_observation_count > MAX_OBSERVATIONS:
            raise ReportError("OBSERVATION_COUNT_LIMIT_EXCEEDED")

    seen_series: set[tuple[str, str, str, str]] = set()
    coverage: list[dict[str, Any]] = []
    total_observations = 0
    for raw_series in series:
        current = _object(
            raw_series,
            {"metricId", "definitionVersion", "scopeId", "epoch", "expectedFinalSequence", "completed", "cumulativeZeroPointKnown", "observations"},
        )
        metric_id = _string(current["metricId"], identifier=True)
        definition_version = _string(current["definitionVersion"], identifier=True)
        definition = definition_map.get((metric_id, definition_version))
        if definition is None:
            raise ReportError("UNDECLARED_DEFINITION")
        scope_id = _string(current["scopeId"], identifier=True)
        if scope_id not in scope_ids:
            raise ReportError("UNDECLARED_SCOPE")
        epoch = _string(current["epoch"], identifier=True)
        series_key = (metric_id, definition_version, scope_id, epoch)
        if series_key in seen_series:
            raise ReportError("DUPLICATE_SERIES_EPOCH")
        seen_series.add(series_key)
        completed = current["completed"]
        zero_known = current["cumulativeZeroPointKnown"]
        if not isinstance(completed, bool) or not isinstance(zero_known, bool):
            raise ReportError("BOOLEAN_REQUIRED")
        expected_raw = current["expectedFinalSequence"]
        expected = None if expected_raw is None else _decimal(expected_raw, positive=True)
        observations = current["observations"]
        if not isinstance(observations, list):
            raise ReportError("OBSERVATION_ARRAY_REQUIRED")
        total_observations += len(observations)
        if total_observations > MAX_OBSERVATIONS:
            raise ReportError("OBSERVATION_COUNT_LIMIT_EXCEEDED")

        by_sequence: dict[int, dict[str, Any]] = {}
        duplicate_count = 0
        for observation in observations:
            obs = _object(observation, {"sequence", "observedAtUtc", "status"}, {"value", "reasonCode", "final"})
            sequence = _decimal(obs["sequence"], positive=True)
            _timestamp(obs["observedAtUtc"])
            status = obs["status"]
            if status == "KNOWN":
                if "value" not in obs or "reasonCode" in obs:
                    raise ReportError("KNOWN_VALUE_SHAPE_INVALID")
                _decimal(obs["value"])
            elif status == "UNKNOWN":
                if definition["kind"] == "FINAL":
                    raise ReportError("FINAL_VALUE_REQUIRED")
                if "value" in obs or "reasonCode" not in obs:
                    raise ReportError("UNKNOWN_VALUE_SHAPE_INVALID")
                _string(obs["reasonCode"], identifier=True)
            else:
                raise ReportError("INVALID_VALUE_STATUS")
            final_flag = obs.get("final", False)
            if not isinstance(final_flag, bool):
                raise ReportError("BOOLEAN_REQUIRED")
            if definition["kind"] == "FINAL" and final_flag is not True:
                raise ReportError("FINAL_OBSERVATION_REQUIRED")
            if definition["kind"] != "FINAL" and final_flag:
                raise ReportError("FINAL_FLAG_NOT_ALLOWED")
            prior = by_sequence.get(sequence)
            if prior is None:
                by_sequence[sequence] = obs
            elif prior == obs:
                duplicate_count += 1
            else:
                raise ReportError("CONFLICTING_DUPLICATE_SEQUENCE")

        sequences = sorted(by_sequence)
        gaps = False
        if completed:
            # Treat missing rows as coverage, not proof that the declared report is false.
            gaps = expected is None or not sequences or sequences[0] != 1 or sequences[-1] != expected or len(sequences) != expected
        elif expected is not None:
            raise ReportError("INCOMPLETE_SERIES_HAS_FINAL_WATERMARK")
        if definition["kind"] == "FINAL" and (not completed or set(by_sequence) != {1} or expected != 1):
            raise ReportError("FINAL_SERIES_CONSTRAINT")
        if definition["kind"] == "CUMULATIVE" and not zero_known:
            coverage.append({"metricId": metric_id, "scopeId": scope_id, "epoch": epoch, "status": "RESET_UNKNOWN"})
        if gaps:
            coverage.append({"metricId": metric_id, "scopeId": scope_id, "epoch": epoch, "status": "SEQUENCE_GAP"})
        if any(item["status"] == "UNKNOWN" for item in by_sequence.values()):
            coverage.append({"metricId": metric_id, "scopeId": scope_id, "epoch": epoch, "status": "UNKNOWN_VALUE"})
        if definition["kind"] == "CUMULATIVE":
            known_values = [int(item["value"]) for _, item in sorted(by_sequence.items()) if item["status"] == "KNOWN"]
            if any(current < prior for prior, current in zip(known_values, known_values[1:])):
                coverage.append({"metricId": metric_id, "scopeId": scope_id, "epoch": epoch, "status": "CUMULATIVE_DECREASE"})
        if duplicate_count:
            coverage.append({"metricId": metric_id, "scopeId": scope_id, "epoch": epoch, "status": "IDENTICAL_DUPLICATE", "count": duplicate_count})
        if not completed:
            coverage.append({"metricId": metric_id, "scopeId": scope_id, "epoch": epoch, "status": "INCOMPLETE"})

    epoch_sets: dict[tuple[str, str, str], set[str]] = {}
    for metric_id, version, scope_id, epoch in seen_series:
        epoch_sets.setdefault((metric_id, version, scope_id), set()).add(epoch)
    for (metric_id, _version, scope_id), epochs in epoch_sets.items():
        if len(epochs) > 1:
            coverage.append({"metricId": metric_id, "scopeId": scope_id, "status": "MULTIPLE_EPOCHS"})

    return {
        "profile": "ssis-reported-metrics/v1",
        "valid": True,
        "captureBinding": "UNVERIFIED",
        "producerIdentity": "DECLARED_UNVERIFIED",
        "coverage": coverage,
        "runtimeEligibility": "NOT_EVALUATED",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path, help="local UTF-8 JSON report")
    args = parser.parse_args()
    try:
        with args.report.open("rb") as report_file:
            raw = report_file.read(MAX_INPUT_BYTES + 1)
        result = parse_report(raw)
    except (OSError, ReportError) as exc:
        print(json.dumps({"valid": False, "error": str(exc)}, separators=(",", ":")))
        return 1
    print(json.dumps(result, separators=(",", ":"), ensure_ascii=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
