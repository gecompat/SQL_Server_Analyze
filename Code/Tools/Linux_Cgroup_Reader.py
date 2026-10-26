"""Bounded, read-only observations of one caller-selected cgroup-v2 process.

The module does not search for processes, change namespaces, or connect a Linux
observation to a SQL Server process.  Native access is delegated to the fixed
Linux ABI wrapper; tests can provide a controlled backend without claiming a
native qualification.
"""

from __future__ import annotations

import argparse
import json
import re
import stat
import sys
import time
from contextlib import ExitStack
from datetime import datetime, timezone
from typing import Any, Callable

from Linux_Cgroup_Metadata import parse_cgroup2_mountinfo, parse_v2_membership
from Linux_Cgroup_Native import (
    CGROUP2_SUPER_MAGIC,
    O_CLOEXEC,
    O_DIRECTORY,
    O_PATH,
    PROC_SUPER_MAGIC,
    ReadBudget,
    NativeFailure,
    UnsupportedNativeError,
    live_probe,
    native_backend,
)
from Linux_Cgroup_Values import (
    parse_cpuset_cpus_effective,
    parse_cgroup_type,
    parse_cpu_stat,
    parse_memory_events,
    parse_resource_value,
)


_PID_MAX = 2_147_483_647
_RESOURCE_KEYS = (
    "memory.max",
    "memory.high",
    "memory.current",
    "memory.swap.max",
    "memory.events",
    "cpu.max",
    "cpu.stat",
    "cpuset.cpus.effective",
)
_LIMIT_KEYS = ("memory.max", "memory.high", "memory.swap.max", "cpu.max")
_PROCFS_FILES = frozenset({"stat", "cgroup", "mountinfo", "fdinfo"})
_U64_TEXT = re.compile(rb"[0-9]+\Z")
_RESULT_CONSTANTS = {
    "schema_version": "linux-cgroup-observation/1",
    "target_identity": "CALLER_SELECTED_PROCESS",
    "partial": True,
    "global_hierarchy": "UNVERIFIED",
    "sql_binding": "UNVERIFIED",
    "event_scope": "UNVERIFIED",
}


class _CollectionFailure(Exception):
    def __init__(self, code: str, *, scope: str = "CONTEXT", selection: str | None = None) -> None:
        super().__init__(code)
        self.code = code
        self.scope = scope
        self.selection = selection


def _empty_result(target_pid: int) -> dict[str, object]:
    return {
        **_RESULT_CONSTANTS,
        "target_pid": str(target_pid),
        "selection_state": "CONTEXT_UNBOUND",
        "context_state": "CONTEXT_UNBOUND",
        "resources": [],
        "hierarchy_metrics": {
            "visible_memory_max_ceiling_bytes": {
                "state": "UNAVAILABLE", "value": None, "source_ordinals": []
            },
            "visible_swap_max_ceiling_bytes": {
                "state": "UNAVAILABLE", "value": None, "source_ordinals": []
            },
            "visible_cpu_quota_ratio": {
                "state": "UNAVAILABLE", "value": None, "ratio_numerator": None,
                "ratio_denominator": None, "source_ordinals": []
            },
        },
        "issues": [],
    }


def _utc_text(epoch_ns: int) -> str:
    whole_seconds, remainder_ns = divmod(epoch_ns, 1_000_000_000)
    instant = datetime.fromtimestamp(whole_seconds, timezone.utc)
    instant = instant.replace(microsecond=remainder_ns // 1_000)
    return instant.isoformat(timespec="microseconds").replace("+00:00", "Z")


def _add_issue(
    result: dict[str, object], scope: str, reason_code: str, source_ordinal: str | None = None
) -> None:
    issue: dict[str, str] = {"scope": scope, "reason_code": reason_code}
    if source_ordinal is not None:
        issue["source_ordinal"] = source_ordinal
    issues = result["issues"]
    assert isinstance(issues, list)
    if issue not in issues:
        issues.append(issue)


def _state_for_failure(code: str, *, context: bool) -> str:
    if code in {
        "MISSING", "PERMISSION_DENIED", "READ_ERROR", "CONTEXT_UNBOUND",
        "LIMIT_REACHED", "DEADLINE_REACHED",
    }:
        return code
    if code == "RESOURCE_MISSING":
        return "MISSING"
    if code in {
        "SYMLINK_REJECTED", "CROSS_MOUNT_REJECTED", "FILESYSTEM_MISMATCH",
        "MOUNT_CHANGED", "DIRECTORY_CHANGED", "NAMESPACE_MISMATCH",
        "PIDFD_PROCFS_MISMATCH", "PID_EXITED", "STARTTIME_CHANGED",
    }:
        return "CONTEXT_UNBOUND"
    return "CONTEXT_UNBOUND" if context else "READ_ERROR"


def _u64_token(numeric_bytes: bytes, *, maximum: int = 18_446_744_073_709_551_615) -> str | None:
    if not _U64_TEXT.fullmatch(numeric_bytes):
        return None
    normalized = numeric_bytes.lstrip(b"0") or b"0"
    if len(normalized) > 20:
        return None
    value = int(normalized)
    return str(value) if value <= maximum else None


def _parse_process_stat(raw: bytes, target_pid: int) -> tuple[str, str] | None:
    """Extract only the stat PID and starttime; never expose comm or raw text."""
    first_space = raw.find(b" ")
    open_paren = raw.find(b"(", first_space + 1 if first_space >= 0 else 0)
    close_paren = raw.rfind(b")")
    if first_space <= 0 or open_paren <= first_space or close_paren <= open_paren:
        return None
    pid_text = _u64_token(raw[:first_space], maximum=_PID_MAX)
    fields = raw[close_paren + 1 :].split()
    # The first post-comm token is field 3; starttime is field 22.
    if pid_text is None or len(fields) < 20:
        return None
    start_ticks = _u64_token(fields[19])
    if pid_text != str(target_pid) or start_ticks is None:
        return None
    return pid_text, start_ticks


def _parse_pidfd_info(raw: str, target_pid: int) -> bool:
    found: list[str] = []
    for line in raw.splitlines():
        tokens = line.split()
        if tokens and tokens[0] == "Pid:":
            if len(tokens) != 2:
                return False
            found.append(tokens[1])
    if len(found) != 1:
        return False
    try:
        encoded = found[0].encode("ascii", "strict")
    except UnicodeEncodeError:
        return False
    return _u64_token(encoded, maximum=_PID_MAX) == str(target_pid)


def _path_components(path: object) -> tuple[str, ...] | None:
    if not isinstance(path, str) or not path.startswith("/") or "\x00" in path:
        return None
    if path == "/":
        return ()
    parts = path[1:].split("/")
    if any(part in ("", ".", "..") for part in parts):
        return None
    return tuple(parts)


def _relative_mount_path(path: object) -> str | None:
    parts = _path_components(path)
    if parts is None:
        return None
    return "/".join(parts) if parts else "."


def _select_cgroup2_mount(mountinfo: dict[str, object], membership_path: str) -> dict[str, object] | None:
    mounts = mountinfo.get("mounts")
    member_parts = _path_components(membership_path)
    if mountinfo.get("parse_state") != "VALID" or not isinstance(mounts, list) or member_parts is None:
        return None
    candidates: list[tuple[int, dict[str, object]]] = []
    for mount in mounts:
        if not isinstance(mount, dict) or mount.get("filesystem_type") != "cgroup2":
            continue
        root_parts = _path_components(mount.get("root"))
        if root_parts is not None and member_parts[: len(root_parts)] == root_parts:
            candidates.append((len(root_parts), mount))
    if not candidates:
        return None
    best_depth = max(depth for depth, _mount in candidates)
    best = [mount for depth, mount in candidates if depth == best_depth]
    return best[0] if len(best) == 1 else None


def _proc_mount_identity(raw_mountinfo: str, proc_mount_id: int) -> tuple[str, ...] | None:
    """Select the already-validated proc record omitted by the cgroup2 parser."""
    matches: list[tuple[str, ...]] = []
    for line in raw_mountinfo.splitlines():
        fields = line.split()
        if len(fields) < 10 or "-" not in fields[6:]:
            continue
        separator = fields.index("-", 6)
        if separator + 3 >= len(fields) or fields[0] != str(proc_mount_id):
            continue
        if fields[separator + 1] != "proc":
            continue
        matches.append(tuple(fields[:6] + fields[separator + 1 :]))
    return matches[0] if len(matches) == 1 else None


def _parse_resource(source_key: str, text: str) -> dict[str, object]:
    if source_key in ("memory.max", "memory.high", "memory.current", "memory.swap.max", "cpu.max"):
        return parse_resource_value(source_key, text)
    if source_key == "memory.events":
        return parse_memory_events(text)
    if source_key == "cpu.stat":
        return parse_cpu_stat(text)
    if source_key == "cpuset.cpus.effective":
        return parse_cpuset_cpus_effective(text)
    if source_key == "cgroup.type":
        return parse_cgroup_type(text)
    raise ValueError("unknown fixed cgroup source")


class _Collector:
    def __init__(self, target_pid: int, backend: Any, budget: ReadBudget) -> None:
        self.target_pid = target_pid
        self.backend = backend
        self.budget = budget
        self.result = _empty_result(target_pid)
        self._source_ordinal = 0
        self._config: dict[tuple[str, str], list[dict[str, object]]] = {}
        self._main: dict[tuple[str, str], dict[str, object]] = {}
        self._last_wall_ns: int | None = None

    def _issue(self, scope: str, code: str, ordinal: str | None = None) -> None:
        _add_issue(self.result, scope, code, ordinal)

    def _failed(self, code: str, *, scope: str = "CONTEXT", selection: str | None = None) -> None:
        self._issue(scope, code)
        if scope in {"CONTEXT", "ABI", "SELECTION"}:
            self.result["context_state"] = "CONTEXT_UNBOUND"
        if selection is not None:
            self.result["selection_state"] = selection

    def _observe(
        self,
        parent_fd: int,
        name: str,
        source_key: str,
        *,
        phase: str,
        level: str | None,
        filesystem_magic: int,
        mount_id: int,
        source_kind: str,
        emit: bool,
        binary: bool = False,
    ) -> tuple[dict[str, object] | None, str | bytes | None]:
        context_source = source_kind == "PROCFS"
        record: dict[str, object] | None = None
        if emit:
            self._source_ordinal += 1
            ordinal = str(self._source_ordinal)
            record = {
                "source_ordinal": ordinal,
                "level_ordinal": level,
                "observation_phase": phase,
                "source_key": source_key,
                "read_state": "READ_ERROR",
                "parse_state": "NOT_ATTEMPTED",
                "reason_code": None,
                "byte_count": "0",
                "raw_value": None,
                "parsed_value": None,
                "native_errno": None,
                "started_at_utc": None,
                "completed_at_utc": None,
                "duration_ns": None,
            }
        else:
            ordinal = None
        start_ns = time.monotonic_ns()
        start_wall_ns = time.time_ns()
        started = _utc_text(start_wall_ns)
        if self._last_wall_ns is not None and start_wall_ns < self._last_wall_ns:
            self._failed("CLOCK_CHANGED")
        if record is not None:
            record["started_at_utc"] = started
        try:
            owner = self.backend.open_relative(
                parent_fd,
                name,
                flags=O_CLOEXEC,
                context=context_source,
            )
            with owner:
                self.backend.fd_identity(
                    owner.fd,
                    expected_magic=filesystem_magic,
                    expected_mount_id=mount_id,
                    expected_type=stat.S_IFREG,
                    context=context_source,
                )
                observation = self.backend.read_bounded(
                    owner.fd, source_kind=source_kind, budget=self.budget
                )
            end_ns = time.monotonic_ns()
            end_wall_ns = time.time_ns()
            ended = _utc_text(end_wall_ns)
            duration = str(max(0, end_ns - start_ns))
            if end_wall_ns < start_wall_ns or end_ns < start_ns:
                self._failed("CLOCK_CHANGED")
            self._last_wall_ns = end_wall_ns
            read_state = observation.read_state
            if record is not None:
                record.update({
                    "read_state": read_state,
                    "byte_count": observation.byte_count,
                    "native_errno": observation.native_errno,
                    "started_at_utc": started,
                    "completed_at_utc": ended,
                    "duration_ns": duration,
                })
            if read_state != "AVAILABLE" or observation.raw_value is None:
                reason = observation.reason_code or read_state
                if record is not None:
                    record["reason_code"] = reason
                    resources = self.result["resources"]
                    assert isinstance(resources, list)
                    resources.append(record)
                    self._issue("BUDGET" if read_state in {"LIMIT_REACHED", "DEADLINE_REACHED"} else "CONTEXT" if read_state == "CONTEXT_UNBOUND" else "RESOURCE", reason, ordinal)
                else:
                    self._issue("BUDGET" if read_state in {"LIMIT_REACHED", "DEADLINE_REACHED"} else "CONTEXT", reason)
                return record, None
            raw_bytes = observation.raw_value
            if binary:
                decoded: str | bytes = raw_bytes
            else:
                try:
                    decoded = raw_bytes.decode("utf-8", "strict")
                except UnicodeDecodeError:
                    if record is not None:
                        record.update({"parse_state": "INVALID_VALUE", "reason_code": "NON_UTF8_TEXT"})
                        resources = self.result["resources"]
                        assert isinstance(resources, list)
                        resources.append(record)
                        self._issue("RESOURCE", "NON_UTF8_TEXT", ordinal)
                    else:
                        self._issue("CONTEXT", "NON_UTF8_TEXT")
                    return record, None
            if record is not None:
                assert isinstance(decoded, str)
                parsed = _parse_resource(source_key, decoded)
                record.update({
                    "parse_state": parsed.get("parse_state", "INVALID_VALUE"),
                    "reason_code": parsed.get("reason_code"),
                    "raw_value": decoded,
                    "parsed_value": parsed,
                })
                resources = self.result["resources"]
                assert isinstance(resources, list)
                resources.append(record)
                if parsed.get("parse_state") not in {"VALID", "EMPTY_OBSERVATION"}:
                    self._issue("RESOURCE", str(parsed.get("reason_code") or "INVALID_VALUE"), ordinal)
            return record, decoded
        except NativeFailure as error:
            state = _state_for_failure(error.code, context=context_source)
            if record is not None:
                record.update({
                    "read_state": state,
                    "reason_code": error.code,
                    "native_errno": str(error.native_errno) if error.native_errno is not None else None,
                    "completed_at_utc": _utc_text(time.time_ns()),
                    "duration_ns": str(max(0, time.monotonic_ns() - start_ns)),
                })
                resources = self.result["resources"]
                assert isinstance(resources, list)
                resources.append(record)
                self._issue("BUDGET" if state in {"LIMIT_REACHED", "DEADLINE_REACHED"} else "CONTEXT" if context_source or state == "CONTEXT_UNBOUND" else "RESOURCE", error.code, ordinal)
            else:
                self._issue("BUDGET" if state in {"LIMIT_REACHED", "DEADLINE_REACHED"} else "CONTEXT", error.code)
            return record, None
        except OSError:
            if record is not None:
                record.update({"read_state": "READ_ERROR", "reason_code": "READ_ERROR", "duration_ns": str(max(0, time.monotonic_ns() - start_ns))})
                resources = self.result["resources"]
                assert isinstance(resources, list)
                resources.append(record)
                self._issue("RESOURCE", "READ_ERROR", ordinal)
            else:
                self._issue("CONTEXT", "READ_ERROR")
            return record, None

    def _proc_text(self, parent_fd: int, name: str, mount_id: int) -> str | None:
        _record, value = self._observe(
            parent_fd, name, "proc." + name, phase="INITIAL_FENCE", level=None,
            filesystem_magic=PROC_SUPER_MAGIC, mount_id=mount_id,
            source_kind="PROCFS", emit=False,
        )
        return value if isinstance(value, str) else None

    def _proc_stat(self, parent_fd: int, mount_id: int) -> tuple[str, str] | None:
        _record, value = self._observe(
            parent_fd, "stat", "proc.stat", phase="INITIAL_FENCE", level=None,
            filesystem_magic=PROC_SUPER_MAGIC, mount_id=mount_id,
            source_kind="PROCFS", emit=False, binary=True,
        )
        return _parse_process_stat(value, self.target_pid) if isinstance(value, bytes) else None

    def _resource(self, level: dict[str, object], key: str, phase: str) -> dict[str, object] | None:
        _record, _value = self._observe(
            int(level["fd"]), key, key, phase=phase, level=str(level["ordinal"]),
            filesystem_magic=CGROUP2_SUPER_MAGIC, mount_id=int(level["mount_id"]),
            source_kind="RESOURCE", emit=True,
        )
        records = self.result["resources"]
        assert isinstance(records, list)
        return records[-1] if records else None

    def _config_read(self, level: dict[str, object], key: str, phase: str) -> dict[str, object] | None:
        record = self._resource(level, key, phase)
        if record is not None:
            bucket_key = (str(level["ordinal"]), key)
            self._config.setdefault(bucket_key, []).append(record)
        return record

    def _read_mountinfo(self, caller_fd: int, proc_mount_id: int) -> tuple[dict[str, object], tuple[str, ...]]:
        text = self._proc_text(caller_fd, "mountinfo", proc_mount_id)
        if text is None:
            raise _CollectionFailure("CONTEXT_UNBOUND")
        parsed = parse_cgroup2_mountinfo(text)
        if parsed.get("parse_state") != "VALID":
            raise _CollectionFailure("MALFORMED_RECORD")
        proc_identity = _proc_mount_identity(text, proc_mount_id)
        if proc_identity is None:
            raise _CollectionFailure("FILESYSTEM_MISMATCH")
        return parsed, proc_identity

    def _read_membership(self, target_fd: int, proc_mount_id: int) -> dict[str, object]:
        text = self._proc_text(target_fd, "cgroup", proc_mount_id)
        if text is None:
            raise _CollectionFailure("CONTEXT_UNBOUND")
        parsed = parse_v2_membership(text)
        if parsed.get("parse_state") != "VALID":
            reason = str(parsed.get("reason_code") or "MALFORMED_RECORD")
            selection = "UNSUPPORTED_LAYOUT" if parsed.get("layout_state") in {"UNSUPPORTED_LAYOUT", "HYBRID", "V1_ONLY"} else "MISSING_MEMBERSHIP" if parsed.get("parse_state") in {"MISSING_MEMBERSHIP", "DELETED_RECORD"} else "CONTEXT_UNBOUND"
            raise _CollectionFailure(reason, scope="SELECTION", selection=selection)
        return parsed

    def _namespace_pair(self, stack: ExitStack, proc_dir_fd: int, proc_mount_id: int) -> dict[str, tuple[int, int]]:
        ns_dir = stack.enter_context(self.backend.open_relative(
            proc_dir_fd, "ns", flags=O_PATH | O_DIRECTORY | O_CLOEXEC, context=True
        ))
        self.backend.fd_identity(ns_dir.fd, expected_magic=PROC_SUPER_MAGIC, expected_mount_id=proc_mount_id, expected_type=stat.S_IFDIR)
        result: dict[str, tuple[int, int]] = {}
        for name in ("pid", "mnt", "cgroup"):
            owned, identity = self.backend.open_namespace_fd(ns_dir.fd, name)
            stack.enter_context(owned)
            result[name] = (identity.device, identity.inode)
        return result

    def _open_initial_context(self, stack: ExitStack) -> dict[str, object]:
        root = stack.enter_context(self.backend.open_root_anchor())
        proc = stack.enter_context(self.backend.open_anchor(
            root, "proc", flags=O_PATH | O_DIRECTORY | O_CLOEXEC,
            expected_magic=PROC_SUPER_MAGIC,
        ))
        proc_mount_id = int(proc.identity.mount_id)
        caller = stack.enter_context(self.backend.open_proc_self(proc.fd, procfs_mount_id=proc_mount_id))
        caller_identity = self.backend.fd_identity(caller.fd, expected_magic=PROC_SUPER_MAGIC, expected_mount_id=proc_mount_id, expected_type=stat.S_IFDIR)
        mountinfo, proc_mount_identity = self._read_mountinfo(caller.fd, proc_mount_id)

        pidfd = stack.enter_context(self.backend.open_pidfd(self.target_pid))
        if not self.backend.pidfd_alive(pidfd.fd):
            raise _CollectionFailure("PID_EXITED")
        target = stack.enter_context(self.backend.open_relative(
            proc.fd, str(self.target_pid), flags=O_PATH | O_DIRECTORY | O_CLOEXEC, context=True
        ))
        target_identity = self.backend.fd_identity(target.fd, expected_magic=PROC_SUPER_MAGIC, expected_mount_id=proc_mount_id, expected_type=stat.S_IFDIR)
        stat_value = self._proc_stat(target.fd, proc_mount_id)
        if stat_value is None:
            raise _CollectionFailure("PIDFD_PROCFS_MISMATCH")
        pid_text, start_ticks = stat_value

        fdinfo_dir = stack.enter_context(self.backend.open_relative(caller.fd, "fdinfo", flags=O_PATH | O_DIRECTORY | O_CLOEXEC, context=True))
        self.backend.fd_identity(fdinfo_dir.fd, expected_magic=PROC_SUPER_MAGIC, expected_mount_id=proc_mount_id, expected_type=stat.S_IFDIR)
        fdinfo = self._proc_text(fdinfo_dir.fd, str(pidfd.fd), proc_mount_id)
        if fdinfo is None or not _parse_pidfd_info(fdinfo, self.target_pid):
            raise _CollectionFailure("PIDFD_PROCFS_MISMATCH")

        membership = self._read_membership(target.fd, proc_mount_id)
        target_namespaces = self._namespace_pair(stack, target.fd, proc_mount_id)
        caller_namespaces = self._namespace_pair(stack, caller.fd, proc_mount_id)
        if target_namespaces != caller_namespaces:
            raise _CollectionFailure("NAMESPACE_MISMATCH")

        mount = _select_cgroup2_mount(mountinfo, str(membership["membership_path"]))
        if mount is None:
            mounts = mountinfo.get("mounts")
            if not isinstance(mounts, list) or not mounts:
                raise _CollectionFailure("FILESYSTEM_MISMATCH", scope="SELECTION", selection="CONTEXT_UNBOUND")
            member_parts = _path_components(membership.get("membership_path"))
            matching_depths = []
            for candidate in mounts:
                root_parts = _path_components(candidate.get("root")) if isinstance(candidate, dict) else None
                if candidate.get("filesystem_type") == "cgroup2" and root_parts is not None and member_parts is not None and member_parts[:len(root_parts)] == root_parts:
                    matching_depths.append(len(root_parts))
            if not matching_depths:
                raise _CollectionFailure("FILESYSTEM_MISMATCH", scope="SELECTION", selection="CONTEXT_UNBOUND")
            if matching_depths.count(max(matching_depths)) > 1:
                raise _CollectionFailure("AMBIGUOUS_MOUNT", scope="SELECTION", selection="AMBIGUOUS_MOUNT")
            raise _CollectionFailure("MOUNT_CHANGED", scope="SELECTION", selection="CONTEXT_UNBOUND")
        mount_point = _relative_mount_path(mount.get("mount_point"))
        if mount_point is None:
            raise _CollectionFailure("INVALID_PATH", scope="SELECTION", selection="CONTEXT_UNBOUND")
        try:
            mount_id = int(str(mount["mount_id"]))
        except (KeyError, ValueError):
            raise _CollectionFailure("INVALID_ID", scope="SELECTION") from None
        cgroup_mount = stack.enter_context(self.backend.open_anchor(
            root, mount_point, flags=O_PATH | O_DIRECTORY | O_CLOEXEC,
            expected_magic=CGROUP2_SUPER_MAGIC, expected_mount_id=mount_id,
        ))
        mount_identity = cgroup_mount.identity

        member_parts = _path_components(membership.get("membership_path"))
        root_parts = _path_components(mount.get("root"))
        if member_parts is None or root_parts is None or member_parts[:len(root_parts)] != root_parts:
            raise _CollectionFailure("INVALID_PATH", scope="SELECTION")
        suffix = member_parts[len(root_parts):]
        if len(suffix) + 1 > 64:
            raise _CollectionFailure("LIMIT_REACHED", scope="BUDGET")
        levels: list[dict[str, object]] = [{"ordinal": "1", "fd": cgroup_mount.fd, "identity": mount_identity, "mount_id": mount_id, "components": ()}]
        previous_fd = cgroup_mount.fd
        previous_parts: tuple[str, ...] = ()
        for component in suffix:
            directory = stack.enter_context(self.backend.open_relative(
                previous_fd, component, flags=O_PATH | O_DIRECTORY | O_CLOEXEC, context=True
            ))
            identity = self.backend.fd_identity(
                directory.fd, expected_magic=CGROUP2_SUPER_MAGIC,
                expected_mount_id=mount_id, expected_type=stat.S_IFDIR,
            )
            previous_parts += (component,)
            levels.append({"ordinal": str(len(levels) + 1), "fd": directory.fd, "identity": identity, "mount_id": mount_id, "components": previous_parts})
            previous_fd = directory.fd
        return {
            "root": root,
            "proc": proc,
            "proc_mount_id": proc_mount_id,
            "proc_identity": proc.identity,
            "caller": caller,
            "caller_identity": caller_identity,
            "target": target,
            "target_identity": target_identity,
            "pidfd": pidfd,
            "pid_text": pid_text,
            "start_ticks": start_ticks,
            "mountinfo": mountinfo,
            "proc_mount_identity": proc_mount_identity,
            "membership": membership,
            "target_namespaces": target_namespaces,
            "caller_namespaces": caller_namespaces,
            "mount": mount,
            "mount_point": mount_point,
            "mount_id": mount_id,
            "mount_identity": mount_identity,
            "levels": levels,
        }

    @staticmethod
    def _signature(record: dict[str, object] | None) -> tuple[object, ...] | None:
        if record is None:
            return None
        return (record.get("read_state"), record.get("parse_state"), record.get("reason_code"), record.get("raw_value"), record.get("parsed_value"))

    def _read_configuration(self, levels: list[dict[str, object]], phase: str) -> dict[tuple[str, str], dict[str, object] | None]:
        observed: dict[tuple[str, str], dict[str, object] | None] = {}
        for level in levels:
            for key in (*_LIMIT_KEYS, "cgroup.type"):
                observed[(str(level["ordinal"]), key)] = self._config_read(level, key, phase)
        leaf = levels[-1]
        observed[(str(leaf["ordinal"]), "cpuset.cpus.effective")] = self._config_read(leaf, "cpuset.cpus.effective", phase)
        return observed

    def _main_reads(self, levels: list[dict[str, object]]) -> None:
        for level in levels[:-1]:
            for key in _LIMIT_KEYS:
                record = self._resource(level, key, "MAIN_READ")
                self._main[(str(level["ordinal"]), key)] = record if record is not None else {}
        for key in _RESOURCE_KEYS:
            record = self._resource(levels[-1], key, "MAIN_READ")
            self._main[(str(levels[-1]["ordinal"]), key)] = record if record is not None else {}

    def _closing_fence(self, context: dict[str, object], stack: ExitStack) -> None:
        proc_mount_id = int(context["proc_mount_id"])
        root = context["root"]
        assert hasattr(root, "fd")
        try:
            proc_again = stack.enter_context(self.backend.open_anchor(
                root, "proc", flags=O_PATH | O_DIRECTORY | O_CLOEXEC,
                expected_magic=PROC_SUPER_MAGIC, expected_mount_id=proc_mount_id,
            ))
            if proc_again.identity != context["proc_identity"]:
                raise _CollectionFailure("MOUNT_CHANGED")
            caller_again = stack.enter_context(self.backend.open_proc_self(proc_again.fd, procfs_mount_id=proc_mount_id))
            caller_id = self.backend.fd_identity(caller_again.fd, expected_magic=PROC_SUPER_MAGIC, expected_mount_id=proc_mount_id, expected_type=stat.S_IFDIR)
            if caller_id != context["caller_identity"]:
                raise _CollectionFailure("DIRECTORY_CHANGED")
            mountinfo_after, proc_identity_after = self._read_mountinfo(caller_again.fd, proc_mount_id)
            if proc_identity_after != context["proc_mount_identity"]:
                raise _CollectionFailure("MOUNT_CHANGED")
            if mountinfo_after.get("mounts") != context["mountinfo"].get("mounts"):
                raise _CollectionFailure("MOUNT_CHANGED")
            target_again = stack.enter_context(self.backend.open_relative(
                proc_again.fd, str(self.target_pid), flags=O_PATH | O_DIRECTORY | O_CLOEXEC, context=True
            ))
            target_id = self.backend.fd_identity(target_again.fd, expected_magic=PROC_SUPER_MAGIC, expected_mount_id=proc_mount_id, expected_type=stat.S_IFDIR)
            if target_id != context["target_identity"]:
                raise _CollectionFailure("DIRECTORY_CHANGED")
            membership_after = self._read_membership(target_again.fd, proc_mount_id)
            if membership_after.get("membership_path") != context["membership"].get("membership_path"):
                raise _CollectionFailure("MEMBERSHIP_CHANGED")
            final_stat = self._proc_stat(target_again.fd, proc_mount_id)
            if final_stat is None or final_stat[0] != context["pid_text"]:
                raise _CollectionFailure("PIDFD_PROCFS_MISMATCH")
            if final_stat[1] != context["start_ticks"]:
                raise _CollectionFailure("STARTTIME_CHANGED")
            fdinfo_dir = stack.enter_context(self.backend.open_relative(caller_again.fd, "fdinfo", flags=O_PATH | O_DIRECTORY | O_CLOEXEC, context=True))
            self.backend.fd_identity(fdinfo_dir.fd, expected_magic=PROC_SUPER_MAGIC, expected_mount_id=proc_mount_id, expected_type=stat.S_IFDIR)
            fdinfo_after = self._proc_text(fdinfo_dir.fd, str(context["pidfd"].fd), proc_mount_id)
            if fdinfo_after is None or not _parse_pidfd_info(fdinfo_after, self.target_pid):
                raise _CollectionFailure("PIDFD_PROCFS_MISMATCH")
            target_namespaces = self._namespace_pair(stack, target_again.fd, proc_mount_id)
            caller_namespaces = self._namespace_pair(stack, caller_again.fd, proc_mount_id)
            if target_namespaces != caller_namespaces or target_namespaces != context["target_namespaces"]:
                raise _CollectionFailure("NAMESPACE_MISMATCH")
            if not self.backend.pidfd_alive(int(context["pidfd"].fd)):
                raise _CollectionFailure("PID_EXITED")

            cgroup_again = stack.enter_context(self.backend.open_anchor(
                root, str(context["mount_point"]), flags=O_PATH | O_DIRECTORY | O_CLOEXEC,
                expected_magic=CGROUP2_SUPER_MAGIC, expected_mount_id=int(context["mount_id"]),
            ))
            if cgroup_again.identity != context["mount_identity"]:
                raise _CollectionFailure("MOUNT_CHANGED")
            current_fd = cgroup_again.fd
            current_identity = cgroup_again.identity
            if current_identity != context["levels"][0]["identity"]:
                raise _CollectionFailure("MOUNT_CHANGED")
            for original in context["levels"]:
                parts = original["components"]
                assert isinstance(parts, tuple)
                if not parts:
                    continue
                component = parts[-1]
                current_owner = stack.enter_context(self.backend.open_relative(
                    current_fd, component, flags=O_PATH | O_DIRECTORY | O_CLOEXEC, context=True
                ))
                current_fd = current_owner.fd
                current_identity = self.backend.fd_identity(
                    current_fd, expected_magic=CGROUP2_SUPER_MAGIC,
                    expected_mount_id=int(context["mount_id"]), expected_type=stat.S_IFDIR,
                )
                if current_identity != original["identity"]:
                    raise _CollectionFailure("DIRECTORY_CHANGED")
        except _CollectionFailure as error:
            self._failed(error.code, scope=error.scope)
        except NativeFailure as error:
            self._failed(error.code)

    def _configuration_consistent(self, initial: dict[tuple[str, str], dict[str, object] | None], closing: dict[tuple[str, str], dict[str, object] | None]) -> set[str]:
        changed: set[str] = set()
        for key, before in initial.items():
            after = closing.get(key)
            main = self._main.get(key)
            signatures = [self._signature(before), self._signature(after)]
            if key[1] in _LIMIT_KEYS or key[1] == "cpuset.cpus.effective":
                signatures.append(self._signature(main))
            if any(signature is None for signature in signatures) or any(signature != signatures[0] for signature in signatures[1:]):
                changed.add(key[1])
        if changed:
            self._issue("CONTEXT", "CONFIGURATION_CHANGED")
        return changed

    def _derive_metrics(self, levels: list[dict[str, object]], changed: set[str]) -> None:
        if self.result["context_state"] != "BOUND" or self.result["selection_state"] != "SELECTED":
            return
        if "cgroup.type" in changed:
            return
        type_records = [self._config.get((str(level["ordinal"]), "cgroup.type"), []) for level in levels]
        for records in type_records:
            parsed = [record.get("parsed_value") for record in records]
            if not parsed or any(not isinstance(value, dict) or value.get("parse_state") != "VALID" or value.get("layout_state") != "SUPPORTED_DOMAIN" for value in parsed):
                return

        def metric(key: str, metric_name: str, source_key: str) -> None:
            target = self.result["hierarchy_metrics"][metric_name]
            if key in changed:
                target.update({"state": "UNAVAILABLE", "value": None, "source_ordinals": []})
                return
            values: list[tuple[dict[str, object], dict[str, object]]] = []
            for level in levels:
                main = self._main.get((str(level["ordinal"]), source_key))
                config = self._config.get((str(level["ordinal"]), source_key), [])
                initial = config[0] if config else None
                closing = config[-1] if len(config) > 1 else None
                if not isinstance(main, dict) or main.get("read_state") != "AVAILABLE" or main.get("parse_state") != "VALID":
                    target.update({"state": "UNAVAILABLE", "value": None, "source_ordinals": []})
                    return
                parsed = main.get("parsed_value")
                if not isinstance(parsed, dict) or parsed.get("value_kind") not in {"FINITE", "UNLIMITED"}:
                    target.update({"state": "UNAVAILABLE", "value": None, "source_ordinals": []})
                    return
                if self._signature(initial) != self._signature(main) or self._signature(closing) != self._signature(main):
                    target.update({"state": "UNAVAILABLE", "value": None, "source_ordinals": []})
                    return
                values.append((main, parsed))
            finite = [(record, parsed) for record, parsed in values if parsed.get("value_kind") == "FINITE"]
            if not finite:
                target.update({"state": "NO_FINITE_VISIBLE_LIMIT", "value": None, "source_ordinals": [record["source_ordinal"] for record, _ in values]})
                return
            minimum = min(int(parsed["value"]) for _record, parsed in finite)
            target.update({"state": "AVAILABLE", "value": str(minimum), "source_ordinals": [record["source_ordinal"] for record, _ in values]})

        metric("memory.max", "visible_memory_max_ceiling_bytes", "memory.max")
        metric("memory.swap.max", "visible_swap_max_ceiling_bytes", "memory.swap.max")
        cpu_metric = self.result["hierarchy_metrics"]["visible_cpu_quota_ratio"]
        if {"cpu.max", "cpuset.cpus.effective"} & changed:
            return
        ratios: list[tuple[int, int]] = []
        ordinals: list[str] = []
        for level in levels:
            record = self._main.get((str(level["ordinal"]), "cpu.max"))
            initial = self._config.get((str(level["ordinal"]), "cpu.max"), [])
            if not isinstance(record, dict) or record.get("read_state") != "AVAILABLE" or record.get("parse_state") != "VALID":
                return
            parsed = record.get("parsed_value")
            if not isinstance(parsed, dict) or parsed.get("value_kind") not in {"FINITE", "UNLIMITED"}:
                return
            if self._signature(initial[0] if initial else None) != self._signature(record) or self._signature(initial[-1] if len(initial) > 1 else None) != self._signature(record):
                return
            ordinals.append(str(record["source_ordinal"]))
            if parsed.get("value_kind") == "FINITE":
                p, q = int(str(parsed["ratio_numerator"])), int(str(parsed["ratio_denominator"]))
                ratios.append((p, q))
        cpuset_record = self._main.get((str(levels[-1]["ordinal"]), "cpuset.cpus.effective"))
        if not isinstance(cpuset_record, dict) or cpuset_record.get("read_state") != "AVAILABLE" or cpuset_record.get("parse_state") != "VALID":
            return
        cpuset = cpuset_record.get("parsed_value")
        if not isinstance(cpuset, dict) or cpuset.get("parse_state") not in {"VALID", "EMPTY_OBSERVATION"}:
            return
        cpuset_fences = self._config.get((str(levels[-1]["ordinal"]), "cpuset.cpus.effective"), [])
        if len(cpuset_fences) < 2 or self._signature(cpuset_fences[0]) != self._signature(cpuset_record) or self._signature(cpuset_fences[-1]) != self._signature(cpuset_record):
            return
        if not ratios:
            cpu_metric.update({"state": "NO_FINITE_VISIBLE_LIMIT", "value": None, "ratio_numerator": None, "ratio_denominator": None, "source_ordinals": ordinals})
            return
        from fractions import Fraction
        num, den = min(Fraction(p, q) for p, q in ratios).as_integer_ratio()
        cpu_metric.update({
            "state": "AVAILABLE",
            "value": None,
            "ratio_numerator": str(num),
            "ratio_denominator": str(den),
            "source_ordinals": ordinals,
        })

    def run(self) -> dict[str, object]:
        try:
            with ExitStack() as stack:
                context = self._open_initial_context(stack)
                self.result["selection_state"] = "SELECTED"
                self.result["context_state"] = "BOUND"
                levels = context["levels"]
                assert isinstance(levels, list)
                initial = self._read_configuration(levels, "INITIAL_FENCE")
                for level in levels:
                    type_record = initial.get((str(level["ordinal"]), "cgroup.type"))
                    parsed_type = type_record.get("parsed_value") if isinstance(type_record, dict) else None
                    if isinstance(parsed_type, dict) and parsed_type.get("parse_state") == "UNSUPPORTED_LAYOUT":
                        self.result["selection_state"] = "UNSUPPORTED_LAYOUT"
                        self._issue("SELECTION", "UNSUPPORTED_LAYOUT", str(type_record["source_ordinal"]))
                self._main_reads(levels)
                closing = self._read_configuration(levels, "CLOSING_FENCE")
                changed = self._configuration_consistent(initial, closing)
                self._closing_fence(context, stack)
                self._derive_metrics(levels, changed)
        except _CollectionFailure as error:
            self._failed(error.code, scope=error.scope, selection=error.selection)
        except UnsupportedNativeError as error:
            self._failed(error.code, scope="ABI")
        except NativeFailure as error:
            self._failed(error.code)
        except (OSError, ValueError, TypeError):
            self._failed("CONTEXT_UNBOUND")
        return self.result


def _validate_target_pid(target_pid: int) -> None:
    if type(target_pid) is not int:
        raise TypeError("target_pid must be an int")
    if target_pid <= 0 or target_pid > _PID_MAX:
        raise ValueError("target_pid must be a positive supported PID")


def _collect_with_backend(target_pid: int, backend: Any, *, budget: ReadBudget | None = None) -> dict[str, object]:
    _validate_target_pid(target_pid)
    return _Collector(target_pid, backend, budget or ReadBudget()).run()


def collect_process(target_pid: int) -> dict[str, object]:
    """Collect a bounded observation for one explicitly selected positive PID."""
    _validate_target_pid(target_pid)
    try:
        backend = native_backend()
        live_probe()
    except UnsupportedNativeError as error:
        result = _empty_result(target_pid)
        _add_issue(result, "ABI", error.code)
        return result
    except NativeFailure as error:
        result = _empty_result(target_pid)
        scope = "ABI" if error.code in {"UNSUPPORTED_ABI", "ABI_MISMATCH", "SYSCALL_UNAVAILABLE"} else "CONTEXT"
        _add_issue(result, scope, error.code)
        return result
    return _collect_with_backend(target_pid, backend)


class _ArgumentParser(argparse.ArgumentParser):
    def error(self, message: str) -> None:
        del message
        raise ValueError("INVALID_ARGUMENT")


def _cli_pid(value: str) -> int:
    if not isinstance(value, str) or not value.isascii() or not value.isdecimal():
        raise ValueError("INVALID_ARGUMENT")
    normalized = value.lstrip("0") or "0"
    if len(normalized) > 10:
        raise ValueError("INVALID_ARGUMENT")
    pid = int(normalized)
    if pid <= 0 or pid > _PID_MAX:
        raise ValueError("INVALID_ARGUMENT")
    return pid


def main(argv: list[str] | None = None) -> int:
    parser = _ArgumentParser(add_help=True, prog="Linux_Cgroup_Reader")
    parser.add_argument("--target-pid", required=True)
    try:
        arguments = parser.parse_args(argv)
        target_pid = _cli_pid(arguments.target_pid)
    except SystemExit as error:
        return int(error.code)
    except ValueError:
        sys.stderr.write("INVALID_ARGUMENT\n")
        return 2
    try:
        result = collect_process(target_pid)
        rendered = json.dumps(result, ensure_ascii=False, allow_nan=False, separators=(",", ":"))
        sys.stdout.write(rendered + "\n")
        return 0
    except (NativeFailure, UnsupportedNativeError):
        sys.stderr.write("OUTPUT_ERROR\n")
        return 3
    except (OSError, TypeError, ValueError):
        sys.stderr.write("OUTPUT_ERROR\n")
        return 3


if __name__ == "__main__":
    raise SystemExit(main())
