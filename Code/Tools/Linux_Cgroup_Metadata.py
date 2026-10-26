"""Parse bounded cgroup membership and mountinfo metadata without I/O."""

from __future__ import annotations

import re
from typing import Final


_MAX_INPUT_BYTES: Final = 512 * 1024
_U64_MAX: Final = 18_446_744_073_709_551_615
_ASCII_DIGITS = re.compile(r"[0-9]+\Z")
_ASCII_WS = re.compile(r"[ \t]+")
_CONTROLLERS = re.compile(r"[A-Za-z0-9_]+\Z")
_NAMED_HIERARCHY = re.compile(r"name=[A-Za-z0-9_.-]+\Z")
_MOUNT_ESCAPE = re.compile(r"\\(040|011|012|134)")
_INVALID_MOUNT_ESCAPE = re.compile(r"\\(?!040|011|012|134)")
_MOUNT_ESCAPE_MAP = {
    "040": " ",
    "011": "\t",
    "012": "\n",
    "134": "\\",
}


def _parse_u64(text: str) -> tuple[int | None, str | None]:
    if not _ASCII_DIGITS.fullmatch(text):
        return None, "INVALID_TOKEN"
    normalized = text.lstrip("0") or "0"
    if len(normalized) > 20:
        return None, "OUT_OF_RANGE"
    value = int(normalized)
    if value > _U64_MAX:
        return None, "OUT_OF_RANGE"
    return value, None


def _input_problem(raw_value: str) -> tuple[str, str] | None:
    raw_size = 0
    for character in raw_value:
        codepoint = ord(character)
        if 0xD800 <= codepoint <= 0xDFFF:
            return "INVALID_VALUE", "NON_UTF8_TEXT"
        if codepoint <= 0x7F:
            raw_size += 1
        elif codepoint <= 0x7FF:
            raw_size += 2
        elif codepoint <= 0xFFFF:
            raw_size += 3
        else:
            raw_size += 4
        if raw_size > _MAX_INPUT_BYTES:
            return "LIMIT_REACHED", "INPUT_TOO_LARGE"
    return None


def _lines(raw_value: str) -> list[tuple[int, str]]:
    if raw_value == "":
        return []
    lines = raw_value.split("\n")
    trailing_line_feed = lines[-1] == ""
    if trailing_line_feed:
        lines.pop()
    return [(ordinal, line) for ordinal, line in enumerate(lines, start=1)]


def _membership_result(
    parse_state: str,
    reason_code: str,
    *,
    record_count: str = "0",
    record_ordinal: str | None = None,
    hierarchy_id: str | None = None,
    membership_path: str | None = None,
    layout_state: str = "UNVERIFIED",
    issue_line_ordinals: list[str] | None = None,
) -> dict[str, object]:
    return {
        "source_key": "proc.cgroup",
        "parse_state": parse_state,
        "reason_code": reason_code,
        "record_count": record_count,
        "record_ordinal": record_ordinal,
        "hierarchy_id": hierarchy_id,
        "membership_path": membership_path,
        "layout_state": layout_state,
        "issue_line_ordinals": issue_line_ordinals or [],
    }


def _parse_membership_record(
    line: str,
) -> tuple[int, list[str], str, bool] | str:
    if "\x00" in line:
        return "INVALID_TOKEN"
    first_colon = line.find(":")
    if first_colon <= 0:
        return "MALFORMED_RECORD"
    second_colon = line.find(":", first_colon + 1)
    if second_colon < 0:
        return "MALFORMED_RECORD"

    hierarchy_text = line[:first_colon]
    hierarchy_id, id_error = _parse_u64(hierarchy_text)
    if id_error:
        return id_error

    controllers_text = line[first_colon + 1 : second_colon]
    if controllers_text:
        controllers = controllers_text.split(",")
        if any(
            not _CONTROLLERS.fullmatch(controller)
            and not _NAMED_HIERARCHY.fullmatch(controller)
            for controller in controllers
        ):
            return "MALFORMED_RECORD"
    else:
        controllers = []

    path = line[second_colon + 1 :]
    if not controllers and hierarchy_id != 0:
        return "MALFORMED_RECORD"
    if not path.startswith("/"):
        return "INVALID_PATH"
    if any(component in {".", ".."} for component in path.split("/")):
        return "INVALID_PATH"
    return hierarchy_id, controllers, path, path.endswith(" (deleted)")


def parse_v2_membership(raw_value: str) -> dict[str, object]:
    """Parse procfs membership records; never returns source lines or errors."""
    if not isinstance(raw_value, str):
        raise TypeError("raw_value must be str")
    problem = _input_problem(raw_value)
    if problem is not None:
        return _membership_result(*problem)

    records: list[tuple[int, int, list[str], str, bool]] = []
    malformed_ordinals: list[str] = []
    malformed_reasons: list[str] = []
    for ordinal, line in _lines(raw_value):
        if line == "":
            continue
        record = _parse_membership_record(line)
        if isinstance(record, str):
            malformed_ordinals.append(str(ordinal))
            malformed_reasons.append(record)
            continue
        hierarchy_id, controllers, path, deleted = record
        records.append((ordinal, hierarchy_id, controllers, path, deleted))

    if malformed_ordinals:
        return _membership_result(
            "INVALID_VALUE",
            malformed_reasons[0],
            record_count=str(len(records) + len(malformed_ordinals)),
            issue_line_ordinals=malformed_ordinals,
        )

    v2_records = [
        record for record in records if record[1] == 0 and not record[2]
    ]
    legacy_records = [record for record in records if record not in v2_records]
    record_count = str(len(records))
    if len(v2_records) > 1:
        return _membership_result(
            "INVALID_VALUE",
            "DUPLICATE_V2_RECORD",
            record_count=record_count,
            issue_line_ordinals=[str(record[0]) for record in v2_records],
        )
    if v2_records and legacy_records:
        return _membership_result(
            "UNSUPPORTED_LAYOUT",
            "HYBRID_LAYOUT",
            record_count=record_count,
            layout_state="HYBRID",
        )
    if legacy_records:
        return _membership_result(
            "UNSUPPORTED_LAYOUT",
            "V1_ONLY",
            record_count=record_count,
            layout_state="V1_ONLY",
        )
    if not v2_records:
        return _membership_result(
            "MISSING_MEMBERSHIP",
            "V2_MEMBERSHIP_MISSING",
            record_count=record_count,
            layout_state="V2_MISSING",
        )

    ordinal, hierarchy_id, _controllers, path, deleted = v2_records[0]
    if deleted:
        return _membership_result(
            "DELETED_RECORD",
            "MEMBERSHIP_DELETED",
            record_count=record_count,
            record_ordinal=str(ordinal),
            hierarchy_id=str(hierarchy_id),
            layout_state="CGROUP_V2",
        )
    return _membership_result(
        "VALID",
        "V2_MEMBERSHIP_PARSED",
        record_count=record_count,
        record_ordinal=str(ordinal),
        hierarchy_id=str(hierarchy_id),
        membership_path=path,
        layout_state="CGROUP_V2",
    )


def _mountinfo_result(
    parse_state: str,
    reason_code: str,
    *,
    record_count: str = "0",
    mounts: list[dict[str, object]] | None = None,
    selection_state: str = "NOT_SELECTED",
    path_binding_state: str = "UNVERIFIED",
    issue_line_ordinals: list[str] | None = None,
) -> dict[str, object]:
    return {
        "source_key": "proc.mountinfo",
        "parse_state": parse_state,
        "reason_code": reason_code,
        "record_count": record_count,
        "mounts": mounts,
        "selection_state": selection_state,
        "path_binding_state": path_binding_state,
        "issue_line_ordinals": issue_line_ordinals or [],
    }


def _decode_mount_path(text: str) -> str | None:
    if _INVALID_MOUNT_ESCAPE.search(text):
        return None
    return _MOUNT_ESCAPE.sub(lambda match: _MOUNT_ESCAPE_MAP[match.group(1)], text)


def _parse_mountinfo_record(
    line: str, ordinal: int
) -> tuple[str, dict[str, object]] | str:
    if "\x00" in line:
        return "INVALID_TOKEN"
    fields = _ASCII_WS.split(line.strip(" \t"))
    if not fields or not fields[0]:
        return "MALFORMED_RECORD"
    try:
        separator = fields.index("-", 6)
    except ValueError:
        return "MALFORMED_RECORD"
    if len(fields) < 6 or len(fields) - separator - 1 != 3:
        return "MALFORMED_RECORD"

    mount_id, mount_error = _parse_u64(fields[0])
    parent_id, parent_error = _parse_u64(fields[1])
    if mount_error or parent_error:
        return mount_error or parent_error or "INVALID_ID"
    if mount_id == 0 or parent_id == 0:
        return "INVALID_ID"

    device_match = re.fullmatch(r"([0-9]+):([0-9]+)", fields[2])
    if device_match is None:
        return "INVALID_ID"
    major, major_error = _parse_u64(device_match.group(1))
    minor, minor_error = _parse_u64(device_match.group(2))
    if major_error or minor_error:
        return major_error or minor_error or "INVALID_ID"

    for optional in fields[6:separator]:
        if optional.startswith(":") or optional.endswith(":") or optional.count(":") > 1:
            return "MALFORMED_RECORD"

    filesystem_type, _mount_source, superoptions_text = fields[separator + 1 :]
    root = _decode_mount_path(fields[3])
    mount_point = _decode_mount_path(fields[4])
    if root is None or mount_point is None:
        return "INVALID_ESCAPE"
    if "\x00" in root or "\x00" in mount_point:
        return "INVALID_PATH"
    if not root.startswith("/") or not mount_point.startswith("/"):
        return "INVALID_PATH"

    mount_options = fields[5].split(",")
    super_options = superoptions_text.split(",")
    if any(not option for option in mount_options + super_options):
        return "MALFORMED_RECORD"
    parsed = {
        "source_ordinal": str(ordinal),
        "mount_id": str(mount_id),
        "parent_id": str(parent_id),
        "major": str(major),
        "minor": str(minor),
        "root": root,
        "mount_point": mount_point,
        "mount_options": mount_options,
        "super_options": super_options,
        "filesystem_type": filesystem_type,
    }
    return filesystem_type, parsed


def parse_cgroup2_mountinfo(raw_value: str) -> dict[str, object]:
    """Parse all mountinfo records and return cgroup2 metadata without selection."""
    if not isinstance(raw_value, str):
        raise TypeError("raw_value must be str")
    problem = _input_problem(raw_value)
    if problem is not None:
        return _mountinfo_result(*problem)

    parsed_records: list[tuple[int, int, str, dict[str, object]]] = []
    malformed_ordinals: list[str] = []
    malformed_reasons: list[str] = []
    for ordinal, line in _lines(raw_value):
        record = _parse_mountinfo_record(line, ordinal)
        if isinstance(record, str):
            malformed_ordinals.append(str(ordinal))
            malformed_reasons.append(record)
            continue
        filesystem_type, fields = record
        parsed_records.append(
            (ordinal, int(fields["mount_id"]), filesystem_type, fields)
        )

    if malformed_ordinals:
        return _mountinfo_result(
            "INVALID_VALUE",
            malformed_reasons[0],
            record_count=str(len(parsed_records) + len(malformed_ordinals)),
            mounts=None,
            issue_line_ordinals=malformed_ordinals,
        )

    by_id: dict[int, list[int]] = {}
    for ordinal, mount_id, _filesystem_type, _fields in parsed_records:
        by_id.setdefault(mount_id, []).append(ordinal)
    duplicate_lines = [
        str(ordinal)
        for ordinals in by_id.values()
        if len(ordinals) > 1
        for ordinal in ordinals
    ]
    if duplicate_lines:
        return _mountinfo_result(
            "INVALID_VALUE",
            "DUPLICATE_MOUNT_ID",
            record_count=str(len(parsed_records)),
            mounts=None,
            issue_line_ordinals=duplicate_lines,
        )

    cgroup2_mounts = [
        fields
        for _ordinal, _mount_id, filesystem_type, fields in parsed_records
        if filesystem_type == "cgroup2"
    ]
    reason = "MOUNTINFO_PARSED" if cgroup2_mounts else "NO_CGROUP2_MOUNTS"
    selection_state = "NOT_SELECTED" if cgroup2_mounts else "EMPTY_CGROUP2_SELECTION"
    return _mountinfo_result(
        "VALID",
        reason,
        record_count=str(len(parsed_records)),
        mounts=cgroup2_mounts,
        selection_state=selection_state,
        path_binding_state="UNVERIFIED",
    )
