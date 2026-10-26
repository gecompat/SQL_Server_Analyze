"""Focused domain counterexamples for the SSIS custom-metrics report validator."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "Code/Tools"))
import Validate_Ssis_Custom_Metrics_Report as validator  # noqa: E402


def report(*, kind: str = "DELTA", observations: list[dict[str, object]] | None = None,
           series_extra: dict[str, object] | None = None, scope_id: str = "scope-a",
           epoch: str = "epoch-a", include_second_epoch: bool = False) -> dict[str, object]:
    default_observation: dict[str, object] = {
        "sequence": "1", "observedAtUtc": "2026-01-01T00:00:00Z", "status": "KNOWN", "value": "0"
    }
    if kind == "FINAL":
        default_observation["final"] = True
    current_series: dict[str, object] = {
        "metricId": "rows-written", "definitionVersion": "v1", "scopeId": scope_id,
        "epoch": epoch, "expectedFinalSequence": "1", "completed": True,
        "cumulativeZeroPointKnown": True,
        "observations": observations if observations is not None else [default_observation],
    }
    current_series.update(series_extra or {})
    series = [current_series]
    if include_second_epoch:
        second = dict(current_series)
        second["epoch"] = "epoch-b"
        series.append(second)
    return {
        "profile": "ssis-reported-metrics/v1",
        "metricProducer": {"id": "example.metrics", "version": "1.0.0", "sourceCommit": "f" * 40,
                            "buildSha256": "a" * 64},
        "modelReference": {"sourceSha256": "b" * 64, "packageNodeId": "node-a"},
        "execution": {"id": "run-a", "captureHandoverId": "handover-a"},
        "definitions": [{"id": "rows-written", "definitionVersion": "v1", "kind": kind, "unit": "count"}],
        "scopes": [{"id": scope_id}], "series": series,
    }


def encoded(value: object) -> bytes:
    return json.dumps(value, separators=(",", ":")).encode("utf-8")


def must_reject(value: object, code: str) -> None:
    try:
        validator.parse_report(encoded(value))
    except validator.ReportError as exc:
        assert str(exc) == code, (code, str(exc))
    else:
        raise AssertionError(f"expected {code}")


def must_reject_raw(raw: bytes, code: str) -> None:
    try:
        validator.parse_report(raw)
    except validator.ReportError as exc:
        assert str(exc) == code, (code, str(exc))
    else:
        raise AssertionError(f"expected {code}")


def self_test() -> None:
    maximum = "9" * 38
    result = validator.parse_report(encoded(report(observations=[{
        "sequence": "1", "observedAtUtc": "2026-01-01T00:00:00Z", "status": "KNOWN", "value": maximum
    }])))
    assert result["valid"] is True and result["runtimeEligibility"] == "NOT_EVALUATED"
    assert result["captureBinding"] == "UNVERIFIED"
    assert result["producerIdentity"] == "DECLARED_UNVERIFIED"

    for invalid in ("00", "+1", "-1", "1.0", "١", "9" * 39):
        candidate = report()
        candidate["series"][0]["observations"][0]["value"] = invalid
        must_reject(candidate, "NONCANONICAL_INTEGER_TEXT")

    must_reject_raw(b'{"x":"a","x":"b"}', "DUPLICATE_JSON_PROPERTY")
    must_reject_raw(b'{"x":1}', "JSON_NUMERIC_LITERAL_NOT_ALLOWED")
    must_reject_raw(b'{"x":1e2}', "JSON_NUMERIC_LITERAL_NOT_ALLOWED")

    duplicate = {"sequence": "1", "observedAtUtc": "2026-01-01T00:00:00Z", "status": "KNOWN", "value": "2"}
    duplicate_result = validator.parse_report(encoded(report(observations=[duplicate, dict(reversed(list(duplicate.items())))])))
    assert any(item["status"] == "IDENTICAL_DUPLICATE" for item in duplicate_result["coverage"])
    conflict = report(observations=[duplicate, {**duplicate, "value": "3"}])
    must_reject(conflict, "CONFLICTING_DUPLICATE_SEQUENCE")

    gap = report(series_extra={"expectedFinalSequence": "3", "observations": [
        {"sequence": "1", "observedAtUtc": "2026-01-01T00:00:00Z", "status": "KNOWN", "value": "1"},
        {"sequence": "3", "observedAtUtc": "2026-01-01T00:00:02Z", "status": "KNOWN", "value": "1"},
    ]})
    assert any(item["status"] == "SEQUENCE_GAP" for item in validator.parse_report(encoded(gap))["coverage"])
    missing_final = report(series_extra={"expectedFinalSequence": "3", "observations": [
        {"sequence": "1", "observedAtUtc": "2026-01-01T00:00:00Z", "status": "KNOWN", "value": "1"},
        {"sequence": "2", "observedAtUtc": "2026-01-01T00:00:01Z", "status": "KNOWN", "value": "1"},
    ]})
    assert any(item["status"] == "SEQUENCE_GAP" for item in validator.parse_report(encoded(missing_final))["coverage"])
    huge_watermark = report(series_extra={"expectedFinalSequence": maximum})
    assert any(item["status"] == "SEQUENCE_GAP" for item in validator.parse_report(encoded(huge_watermark))["coverage"])
    unknown = report(observations=[{"sequence": "1", "observedAtUtc": "2026-01-01T00:00:00Z",
                                    "status": "UNKNOWN", "reasonCode": "not-measured"}])
    assert any(item["status"] == "UNKNOWN_VALUE" for item in validator.parse_report(encoded(unknown))["coverage"])
    zero_with_reason = report(observations=[{"sequence": "1", "observedAtUtc": "2026-01-01T00:00:00Z",
                                              "status": "UNKNOWN", "reasonCode": "unknown", "value": "0"}])
    must_reject(zero_with_reason, "UNKNOWN_VALUE_SHAPE_INVALID")

    reset = report(kind="CUMULATIVE", series_extra={"cumulativeZeroPointKnown": False})
    assert any(item["status"] == "RESET_UNKNOWN" for item in validator.parse_report(encoded(reset))["coverage"])
    decreased = report(kind="CUMULATIVE", observations=[
        {"sequence": "1", "observedAtUtc": "2026-01-01T00:00:00Z", "status": "KNOWN", "value": "2"},
        {"sequence": "2", "observedAtUtc": "2026-01-01T00:00:01Z", "status": "KNOWN", "value": "1"},
    ], series_extra={"expectedFinalSequence": "2"})
    assert any(item["status"] == "CUMULATIVE_DECREASE" for item in validator.parse_report(encoded(decreased))["coverage"])
    assert validator.parse_report(encoded(report(kind="FINAL")))["valid"] is True
    bad_final_sequence = report(kind="FINAL", observations=[{
        "sequence": "2", "observedAtUtc": "2026-01-01T00:00:00Z", "status": "KNOWN", "value": "0", "final": True
    }], series_extra={"expectedFinalSequence": "2"})
    must_reject(bad_final_sequence, "FINAL_SERIES_CONSTRAINT")
    multi = report(include_second_epoch=True)
    assert any(item["status"] == "MULTIPLE_EPOCHS" for item in validator.parse_report(encoded(multi))["coverage"])
    scopes = report(scope_id="scope-b")
    scopes["scopes"].append({"id": "scope-a"})
    second_scope = dict(scopes["series"][0])
    second_scope["scopeId"] = "scope-a"
    scopes["series"].append(second_scope)
    assert validator.parse_report(encoded(scopes))["valid"] is True

    numeric_sequence = report()
    numeric_sequence["series"][0]["observations"][0]["sequence"] = 1
    must_reject(numeric_sequence, "JSON_NUMERIC_LITERAL_NOT_ALLOWED")
    final = report(kind="FINAL")
    final["definitions"][0]["selectionRule"] = "invalid"
    must_reject(final, "GAUGE_SELECTION_RULE_CONSTRAINT")
    generic_unit = report()
    generic_unit["definitions"][0]["unit"] = "number"
    must_reject(generic_unit, "NONCANONICAL_UNIT")
    malformed_kind = report()
    malformed_kind["definitions"][0]["kind"] = []
    must_reject(malformed_kind, "INVALID_METRIC_KIND")

    for wrong_type in (None, "not-an-array", True, {"sequence": "1"}):
        malformed_observations = report()
        malformed_observations["series"][0]["observations"] = wrong_type
        must_reject(malformed_observations, "OBSERVATION_ARRAY_REQUIRED")
    direct_wrong_type = report()
    direct_wrong_type["series"][0]["observations"] = 3
    try:
        validator.validate_document(direct_wrong_type)
    except validator.ReportError as exc:
        assert str(exc) == "OBSERVATION_ARRAY_REQUIRED"
    else:
        raise AssertionError("expected OBSERVATION_ARRAY_REQUIRED")

    cli_input = report()
    cli_input["series"][0]["observations"] = None
    with tempfile.TemporaryDirectory(prefix="ssis-metrics-") as directory:
        report_path = Path(directory) / "synthetic-report.json"
        report_path.write_bytes(encoded(cli_input))
        completed = subprocess.run(
            [sys.executable, str(ROOT / "Code/Tools/Validate_Ssis_Custom_Metrics_Report.py"), str(report_path)],
            capture_output=True,
            text=True,
            check=False,
        )
    assert completed.returncode == 1
    assert completed.stderr == ""
    assert json.loads(completed.stdout) == {"valid": False, "error": "OBSERVATION_ARRAY_REQUIRED"}


if __name__ == "__main__":
    self_test()
    print("SSIS_CUSTOM_METRICS_SELF_TEST_PASS")
