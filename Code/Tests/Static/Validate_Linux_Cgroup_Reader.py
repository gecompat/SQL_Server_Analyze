"""Portable and opt-in Linux tests for cgroup reader native primitives."""

from __future__ import annotations

import argparse
import copy
import ctypes
import errno
import importlib.util
import os
import pickle
import re
import stat
import subprocess
import sys
import tempfile
import threading
from pathlib import Path
from typing import Any
from unittest.mock import patch
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO


MODULE_PATH = Path("Code/Tools/Linux_Cgroup_Native.py")
READER_PATH = Path("Code/Tools/Linux_Cgroup_Reader.py")
NATIVE_RELATIVE_PATH = Path("Code/Tools/Linux_Cgroup_Native.py")
WORKFLOW_RELATIVE_PATH = Path(".github/workflows/documentation-validation.yml")


def load_native(repository_root: Path):
    module_path = repository_root / MODULE_PATH
    spec = importlib.util.spec_from_file_location("linux_cgroup_native_validator", module_path)
    if spec is None or spec.loader is None:
        raise AssertionError("native primitive module is unavailable")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    try:
        spec.loader.exec_module(module)
    except Exception:
        sys.modules.pop(spec.name, None)
        raise
    return module


def load_reader(repository_root: Path):
    tools_path = str(repository_root / "Code/Tools")
    if tools_path not in sys.path:
        sys.path.insert(0, tools_path)
    module_path = repository_root / READER_PATH
    spec = importlib.util.spec_from_file_location("linux_cgroup_reader_validator", module_path)
    if spec is None or spec.loader is None:
        raise AssertionError("reader module is unavailable")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    try:
        spec.loader.exec_module(module)
    except Exception:
        sys.modules.pop(spec.name, None)
        raise
    return module


class _FakeNode:
    def __init__(self, path: str, *, directory: bool, magic: int, mount_id: int, device: int, inode: int, data: bytes = b"") -> None:
        self.path = path
        self.directory = directory
        self.magic = magic
        self.mount_id = mount_id
        self.device = device
        self.inode = inode
        self.data = data


class _FakeOwned:
    def __init__(self, backend: "_FakeBackend", fd: int, identity: Any = None) -> None:
        self._backend = backend
        self.fd = fd
        self.identity = identity
        self.closed = False

    def __enter__(self):
        if self.closed:
            raise self._backend.reader.NativeFailure("FD_CLOSED")
        return self

    def __exit__(self, *_args: object) -> None:
        self.close()

    def close(self) -> None:
        if not self.closed:
            self.closed = True
            self._backend.open_fds.discard(self.fd)


class _FakeRoot(_FakeOwned):
    pass


class _FakeBackend:
    """Deterministic virtual procfs/cgroup2 fixture for portable wire tests."""

    PROC = 0x9FA0
    CGROUP2 = 0x63677270
    NSFS = 0x6E736673
    EXT4 = 0xEF53

    def __init__(self, reader: Any, *, mutations: frozenset[str] = frozenset(), membership: str = "0::/group/leaf\n", mountinfo: str | None = None, levels: int = 3) -> None:
        self.reader = reader
        self.mutations = set(mutations)
        self.next_fd = 100
        self.next_inode = 1000
        self.nodes: dict[str, _FakeNode] = {}
        self.fd_nodes: dict[int, _FakeNode] = {}
        self.open_fds: set[int] = set()
        self.read_counts: dict[str, int] = {}
        self.open_counts: dict[str, int] = {}
        self.namespace_open_count = 0
        self.pidfd_checks = 0
        self.pidfd_number = 0
        self.membership = membership
        self.levels = levels
        self.mountinfo = mountinfo or (
            "29 23 0:24 / /proc rw,nosuid,nodev,noexec,relatime - proc proc rw\n"
            "30 23 0:29 / /sys/fs/cgroup rw,nosuid,nodev,noexec,relatime - cgroup2 cgroup rw\n"
        )
        self.fail_read_path: str | None = None
        self.fail_read_code = "READ_ERROR"
        self.fail_open_path: str | None = None
        self.fail_open_code = "SYMLINK_REJECTED"
        self.membership_text = membership
        if levels != 3 and membership == "0::/group/leaf\n":
            names = ["group"] + [f"parent{index}" for index in range(1, levels - 2)] + ["leaf"]
            self.membership_text = "0::/" + "/".join(names) + "\n"
        self.mountinfo_text = self.mountinfo
        self._add_dir("/", self.EXT4, 1, 1)
        self._add_dir("/proc", self.PROC, 29, 2)
        self._add_dir("/proc/self", self.PROC, 29, 3)
        self._add_dir("/proc/self/fdinfo", self.PROC, 29, 4)
        self._add_dir("/proc/123", self.PROC, 29, 5)
        self._add_dir("/proc/123/ns", self.PROC, 29, 6)
        self._add_dir("/proc/self/ns", self.PROC, 29, 7)
        self._add_file("/proc/123/stat", b"")
        self._add_file("/proc/123/cgroup", self.membership_text.encode())
        self._add_file("/proc/self/mountinfo", self.mountinfo.encode())
        self._add_dir("/sys", self.EXT4, 1, 10)
        self._add_dir("/sys/fs", self.EXT4, 1, 11)
        self._add_dir("/sys/fs/cgroup", self.CGROUP2, 30, 12)
        parent = "/sys/fs/cgroup"
        for index in range(max(0, levels - 2)):
            name = "group" if index == 0 else f"parent{index}"
            parent += "/" + name
            self._add_dir(parent, self.CGROUP2, 30, 12 + index + 1)
        leaf = parent + "/leaf" if levels > 1 else parent
        if levels > 1:
            self._add_dir(leaf, self.CGROUP2, 30, 40)
        self.leaf_path = leaf
        for path, data in (
            ("memory.max", b"1000\n"), ("memory.high", b"max\n"),
            ("memory.current", b"11\n"), ("memory.swap.max", b"max\n"),
            ("memory.events", b"low 0\n"), ("cpu.max", b"200 100\n"),
            ("cpu.stat", b"usage_usec 1\n"), ("cpuset.cpus.effective", b"0-2\n"),
            ("cgroup.type", b"domain\n"),
        ):
            for index, dir_path in enumerate(self._cgroup_dirs()):
                value = data
                if path == "memory.max" and index == len(self._cgroup_dirs()) - 1:
                    value = b"900\n"
                elif path == "cpu.max" and index == len(self._cgroup_dirs()) - 1:
                    value = b"80 100\n"
                self._add_file(dir_path + "/" + path, value)

    def _add_dir(self, path: str, magic: int, mount_id: int, inode: int) -> None:
        self.nodes[path] = _FakeNode(path, directory=True, magic=magic, mount_id=mount_id, device=magic, inode=inode)

    def _add_file(self, path: str, data: bytes) -> None:
        self.next_inode += 1
        parent = path.rsplit("/", 1)[0]
        parent_node = self.nodes.get(parent)
        if parent_node is None:
            return
        self.nodes[path] = _FakeNode(path, directory=False, magic=parent_node.magic, mount_id=parent_node.mount_id, device=parent_node.device, inode=self.next_inode, data=data)

    def _cgroup_dirs(self) -> list[str]:
        values = ["/sys/fs/cgroup"]
        path = "/sys/fs/cgroup"
        for component in self.leaf_path[len("/sys/fs/cgroup/"):].split("/") if self.leaf_path != path else []:
            path += "/" + component
            values.append(path)
        return values

    def _new_handle(self, node: _FakeNode, identity: Any = None):
        fd = self.next_fd
        self.next_fd += 1
        self.fd_nodes[fd] = node
        self.open_fds.add(fd)
        return _FakeOwned(self, fd, identity)

    def _identity(self, node: _FakeNode):
        mode = (stat.S_IFDIR if node.directory else stat.S_IFREG) | (0o755 if node.directory else 0o444)
        return self.reader.sys.modules["Linux_Cgroup_Native"].FdIdentity(node.magic, node.device, node.inode, mode, node.mount_id)

    def open_root_anchor(self):
        node = self.nodes["/"]
        return _FakeRoot(self, self._new_handle(node).fd, self._identity(node))

    def open_anchor(self, root, path, *, flags, expected_magic, expected_mount_id=None):
        del flags
        parent = self.fd_nodes[root.fd].path
        target_path = (parent.rstrip("/") + "/" + str(path)).replace("//", "/")
        node = self.nodes.get(target_path)
        if node is None or not node.directory:
            raise self.reader.NativeFailure("MISSING")
        if node.magic != expected_magic:
            raise self.reader.NativeFailure("FILESYSTEM_MISMATCH")
        if expected_mount_id is not None and node.mount_id != expected_mount_id:
            raise self.reader.NativeFailure("MOUNT_CHANGED")
        count = self.open_counts.get(target_path, 0) + 1
        self.open_counts[target_path] = count
        if "mount_change" in self.mutations and target_path == "/sys/fs/cgroup" and count > 1:
            node = _FakeNode(node.path, directory=True, magic=node.magic, mount_id=node.mount_id, device=node.device, inode=node.inode + 1)
        handle = self._new_handle(node, self._identity(node))
        handle.identity = self._identity(node)
        return handle

    def open_proc_self(self, procfs_fd, *, procfs_mount_id):
        del procfs_fd, procfs_mount_id
        return self._new_handle(self.nodes["/proc/self"], self._identity(self.nodes["/proc/self"]))

    def open_relative(self, dir_fd, path, *, flags, mode=0, context=True):
        del flags, mode
        parent = self.fd_nodes[dir_fd]
        path_text = os.fsdecode(path)
        target_path = (parent.path.rstrip("/") + "/" + path_text).replace("//", "/")
        if self.fail_open_path == target_path:
            raise self.reader.NativeFailure(self.fail_open_code)
        if target_path == "/proc/self/fdinfo" + f"/{self.pidfd_number}" and self.pidfd_number:
            node = self._add_dynamic_fdinfo(target_path)
        else:
            node = self.nodes.get(target_path)
        if node is None:
            raise self.reader.NativeFailure("CONTEXT_UNBOUND" if context else "MISSING")
        if not parent.directory:
            raise self.reader.NativeFailure("READ_ERROR")
        if node.mount_id != parent.mount_id:
            raise self.reader.NativeFailure("CROSS_MOUNT_REJECTED")
        count = self.open_counts.get(target_path, 0) + 1
        self.open_counts[target_path] = count
        if "directory_change" in self.mutations and node.directory and target_path == "/sys/fs/cgroup/group" and count > 1:
            node = _FakeNode(node.path, directory=True, magic=node.magic, mount_id=node.mount_id, device=node.device, inode=node.inode + 1)
        return self._new_handle(node)

    def _add_dynamic_fdinfo(self, path: str):
        data = f"pos:\t0\nflags:\t0100000\nPid:\t123\n\n".encode()
        parent = self.nodes["/proc/self/fdinfo"]
        node = _FakeNode(path, directory=False, magic=parent.magic, mount_id=parent.mount_id, device=parent.device, inode=9001, data=data)
        self.nodes[path] = node
        return node

    def fd_identity(self, fd, *, expected_magic, expected_mount_id=None, expected_type=None, context=True):
        node = self.fd_nodes[fd]
        identity = self._identity(node)
        if identity.filesystem_magic != expected_magic:
            raise self.reader.NativeFailure("FILESYSTEM_MISMATCH")
        if expected_mount_id is not None and identity.mount_id != expected_mount_id:
            raise self.reader.NativeFailure("MOUNT_CHANGED")
        if expected_type is not None and stat.S_IFMT(identity.mode) != expected_type:
            raise self.reader.NativeFailure("CONTEXT_UNBOUND" if context else "READ_ERROR")
        return identity

    def open_pidfd(self, pid):
        del pid
        self.pidfd_number = self.next_fd
        node = _FakeNode("<pidfd>", directory=False, magic=self.NSFS, mount_id=99, device=self.NSFS, inode=700)
        return self._new_handle(node)

    def pidfd_alive(self, fd):
        del fd
        self.pidfd_checks += 1
        return "pid_exit" not in self.mutations or self.pidfd_checks == 1

    def open_namespace_fd(self, namespace_dir_fd, name):
        del namespace_dir_fd
        self.namespace_open_count += 1
        inode = {"pid": 501, "mnt": 502, "cgroup": 503}[name]
        if "namespace_change" in self.mutations and self.namespace_open_count > 6:
            inode += 1
        node = _FakeNode(f"<ns:{name}>", directory=False, magic=self.NSFS, mount_id=99, device=self.NSFS, inode=inode)
        handle = self._new_handle(node)
        return handle, self._identity(node)

    def read_bounded(self, fd, *, source_kind, budget):
        import errno as errno_module
        native = self.reader.sys.modules["Linux_Cgroup_Native"]
        node = self.fd_nodes[fd]
        path = node.path
        self.read_counts[path] = self.read_counts.get(path, 0) + 1
        count = self.read_counts[path]
        if self.fail_read_path == path:
            err = errno_module.EACCES if self.fail_read_code == "PERMISSION_DENIED" else errno_module.EIO
            return native.ReadObservation(self.fail_read_code, "0", None, self.fail_read_code, str(err))
        if path == "/proc/123/stat":
            ticks = b"101" if "starttime_change" in self.mutations and count > 1 else b"100"
            fields = [b"0"] * 18 + [ticks]
            data = b"123 (synthetic process) S " + b" ".join(fields) + b"\n"
        elif path == "/proc/123/cgroup" and "membership_change" in self.mutations and count > 1:
            data = b"0::/group/other\n"
        elif path.endswith("/memory.max") and path.startswith("/sys/fs/cgroup") and "config_change" in self.mutations and count == 3:
            data = b"800\n"
        else:
            data = node.data
        admission = budget.admission_state()
        cap = native.PROCFS_READ_LIMIT if source_kind == "PROCFS" else native.RESOURCE_READ_LIMIT
        if admission:
            return native.ReadObservation(admission, "0", None, admission, None)
        if len(data) >= min(cap, budget.remaining_bytes):
            used = min(cap, budget.remaining_bytes)
            budget.account(used)
            return native.ReadObservation("LIMIT_REACHED", str(used), None, "LIMIT_REACHED", None)
        budget.account(len(data))
        return native.ReadObservation("AVAILABLE", str(len(data)), data, None, None)


def run_reader_self_tests(repository_root: Path) -> int:
    reader = load_reader(repository_root)
    native = sys.modules["Linux_Cgroup_Native"]
    cases = 0

    def collect(**kwargs: Any):
        backend = _FakeBackend(reader, **kwargs)
        result = reader._collect_with_backend(123, backend)
        return result, backend

    result, backend = collect()
    _assert(result["schema_version"] == "linux-cgroup-observation/1", "reader schema marker")
    _assert(result["partial"] is True and result["sql_binding"] == "UNVERIFIED", "reader always partial and unbound to SQL")
    _assert(result["selection_state"] == "SELECTED" and result["context_state"] == "BOUND", "synthetic process context binds")
    memory_metric = result["hierarchy_metrics"]["visible_memory_max_ceiling_bytes"]
    cpu_metric = result["hierarchy_metrics"]["visible_cpu_quota_ratio"]
    _assert((memory_metric["state"], memory_metric["value"]) == ("AVAILABLE", "900"), "visible memory minimum")
    _assert((cpu_metric["state"], cpu_metric["ratio_numerator"], cpu_metric["ratio_denominator"]) == ("AVAILABLE", "4", "5"), "visible CPU quota minimum")
    resources = result["resources"]
    _assert(len(resources) == 48, "three-level fixed resource and fence records")
    _assert(all(isinstance(record["source_ordinal"], str) and isinstance(record["byte_count"], str) for record in resources), "ordinals and byte counts are strings")
    _assert(backend.open_fds == set(), "synthetic collector closes every descriptor")
    cases += 8

    # A malformed resource does not discard successful neighboring observations.
    backend = _FakeBackend(reader)
    backend.nodes[backend.leaf_path + "/memory.current"].data = b"max\n"
    result = reader._collect_with_backend(123, backend)
    leaf_current = [record for record in result["resources"] if record["source_key"] == "memory.current"]
    _assert(len(leaf_current) == 1 and leaf_current[0]["read_state"] == "AVAILABLE" and leaf_current[0]["parse_state"] == "INVALID_VALUE", "parse failure remains separate from read")
    _assert(any(record["source_key"] == "cpu.stat" and record["read_state"] == "AVAILABLE" for record in result["resources"]), "other values survive parse failure")
    cases += 2

    for text, expected_state, expected_selection in (
        ("0::/group/leaf\n1:memory:/legacy\n", "UNSUPPORTED_LAYOUT", "UNSUPPORTED_LAYOUT"),
        ("7:name=systemd:/synthetic.slice\n", "UNSUPPORTED_LAYOUT", "UNSUPPORTED_LAYOUT"),
        ("", "MISSING_MEMBERSHIP", "MISSING_MEMBERSHIP"),
        ("0::/group/leaf\n0::/group/other\n", "INVALID_VALUE", "CONTEXT_UNBOUND"),
    ):
        result, backend = collect(membership=text)
        _assert(result["selection_state"] == expected_selection, "membership classification")
        _assert(result["context_state"] == "CONTEXT_UNBOUND" and not result["resources"], "unselected membership has no fabricated resource reads")
        _assert(expected_state in {"UNSUPPORTED_LAYOUT", "MISSING_MEMBERSHIP", "INVALID_VALUE"}, "membership oracle is independent")
        _assert(backend.open_fds == set(), "membership failure cleanup")
        cases += 3

    for mutation, expected in (
        ("membership_change", "MEMBERSHIP_CHANGED"),
        ("namespace_change", "NAMESPACE_MISMATCH"),
        ("starttime_change", "STARTTIME_CHANGED"),
        ("mount_change", "MOUNT_CHANGED"),
        ("directory_change", "DIRECTORY_CHANGED"),
        ("pid_exit", "PID_EXITED"),
    ):
        result, backend = collect(mutations=frozenset({mutation}))
        _assert(result["context_state"] == "CONTEXT_UNBOUND", "changed fence suppresses bound context")
        _assert(any(issue["reason_code"] == expected for issue in result["issues"]), "fixed changed-fence code")
        _assert(any(record["read_state"] == "AVAILABLE" for record in result["resources"]), "successful reads retained after late fence failure")
        _assert(backend.open_fds == set(), "changed-fence cleanup")
        cases += 4

    result, backend = collect(mutations=frozenset({"config_change"}))
    _assert(any(issue["reason_code"] == "CONFIGURATION_CHANGED" for issue in result["issues"]), "closing configuration change identified")
    _assert(result["hierarchy_metrics"]["visible_memory_max_ceiling_bytes"]["state"] == "UNAVAILABLE", "changed memory limit suppresses metric")
    _assert(backend.open_fds == set(), "configuration cleanup")
    cases += 3

    for observed_type, expected_state, expected_selection in (
        (b"threaded\n", "UNSUPPORTED_LAYOUT", "UNSUPPORTED_LAYOUT"),
        (b"domain threaded\n", "UNSUPPORTED_LAYOUT", "UNSUPPORTED_LAYOUT"),
        (b"domain invalid\n", "UNSUPPORTED_LAYOUT", "UNSUPPORTED_LAYOUT"),
        (b"future-layout\n", "TYPE_UNVERIFIED", "SELECTED"),
    ):
        backend = _FakeBackend(reader)
        for path, node in tuple(backend.nodes.items()):
            if path.endswith("/cgroup.type"):
                node.data = observed_type
        result = reader._collect_with_backend(123, backend)
        type_records = [record for record in result["resources"] if record["source_key"] == "cgroup.type"]
        _assert(type_records and all(record["parse_state"] == expected_state for record in type_records), "type state has no synthesized default")
        _assert(result["selection_state"] == expected_selection, "layout selection status")
        if expected_state != "VALID":
            _assert(result["hierarchy_metrics"]["visible_memory_max_ceiling_bytes"]["state"] == "UNAVAILABLE", "unverified type suppresses hierarchy metrics")
        _assert(backend.open_fds == set(), "type-state cleanup")
        cases += 4

    # Unknown counter keys remain visible, while malformed documents stay wholly unmapped.
    backend = _FakeBackend(reader)
    backend.nodes[backend.leaf_path + "/memory.events"].data = b"future_event 7\nlow 0\n"
    result = reader._collect_with_backend(123, backend)
    events = next(record["parsed_value"] for record in result["resources"] if record["source_key"] == "memory.events")
    _assert(events["event_scope"] == "UNVERIFIED" and events["counters"][0]["key_state"] == "UNMAPPED_KEY", "unknown event counter remains unmapped")
    _assert(result["event_scope"] == "UNVERIFIED", "event scope never inferred")
    _assert(backend.open_fds == set(), "unknown counter cleanup")
    cases += 3
    backend = _FakeBackend(reader)
    backend.nodes[backend.leaf_path + "/cpu.stat"].data = b"usage_usec 1\nusage_usec 2\n"
    result = reader._collect_with_backend(123, backend)
    cpu_stat = next(record for record in result["resources"] if record["source_key"] == "cpu.stat")
    _assert(cpu_stat["parse_state"] == "INVALID_VALUE" and cpu_stat["parsed_value"]["counters"] is None, "invalid keyed source has no partial counters")
    _assert(backend.open_fds == set(), "invalid counter cleanup")
    cases += 2

    # Permission, symlink, foreign-mount, missing-parent, and read-budget outcomes are distinct.
    backend = _FakeBackend(reader)
    backend.fail_read_path = backend.leaf_path + "/memory.current"
    backend.fail_read_code = "PERMISSION_DENIED"
    result = reader._collect_with_backend(123, backend)
    current = next(record for record in result["resources"] if record["source_key"] == "memory.current")
    _assert((current["read_state"], current["raw_value"], current["parse_state"]) == ("PERMISSION_DENIED", None, "NOT_ATTEMPTED"), "permission failure is a read state")
    _assert(backend.open_fds == set(), "permission failure cleanup")
    cases += 2
    backend = _FakeBackend(reader)
    backend.fail_open_path = backend.leaf_path + "/memory.current"
    result = reader._collect_with_backend(123, backend)
    current = next(record for record in result["resources"] if record["source_key"] == "memory.current")
    _assert((current["read_state"], current["reason_code"]) == ("CONTEXT_UNBOUND", "SYMLINK_REJECTED"), "symlink failure fails closed with fixed reason")
    _assert(backend.open_fds == set(), "symlink failure cleanup")
    cases += 2
    backend = _FakeBackend(reader)
    foreign = backend.nodes[backend.leaf_path + "/memory.current"]
    foreign.mount_id = 31
    result = reader._collect_with_backend(123, backend)
    current = next(record for record in result["resources"] if record["source_key"] == "memory.current")
    _assert((current["read_state"], current["reason_code"]) == ("CONTEXT_UNBOUND", "CROSS_MOUNT_REJECTED"), "foreign mount is rejected")
    _assert(backend.open_fds == set(), "cross-mount failure cleanup")
    cases += 2
    backend = _FakeBackend(reader)
    backend.nodes.pop("/sys/fs/cgroup/group/memory.max")
    result = reader._collect_with_backend(123, backend)
    missing_parent = [record for record in result["resources"] if record["source_key"] == "memory.max" and record["level_ordinal"] == "2" and record["observation_phase"] == "MAIN_READ"]
    _assert(len(missing_parent) == 1 and missing_parent[0]["read_state"] == "MISSING", "visible parent gap is explicit")
    _assert(result["hierarchy_metrics"]["visible_memory_max_ceiling_bytes"]["state"] == "UNAVAILABLE", "visible scope gap suppresses minimum")
    _assert(backend.open_fds == set(), "scope gap cleanup")
    cases += 3
    budget_backend = _FakeBackend(reader)
    budget_result = reader._collect_with_backend(123, budget_backend, budget=reader.ReadBudget(1, 10))
    _assert(budget_result["context_state"] == "CONTEXT_UNBOUND" and any(item["reason_code"] == "LIMIT_REACHED" for item in budget_result["issues"]), "shared byte limit blocks metadata read")
    _assert(budget_backend.open_fds == set(), "budget cleanup")
    cases += 2
    deadline_backend = _FakeBackend(reader)
    deadline_result = reader._collect_with_backend(123, deadline_backend, budget=reader.ReadBudget(1024, 0))
    _assert(deadline_result["context_state"] == "CONTEXT_UNBOUND" and any(item["reason_code"] == "DEADLINE_REACHED" for item in deadline_result["issues"]), "deadline blocks metadata read")
    _assert(deadline_backend.open_fds == set(), "deadline cleanup")
    cases += 2

    for depth, expected_selection in ((64, "SELECTED"), (65, "CONTEXT_UNBOUND")):
        backend = _FakeBackend(reader, levels=depth)
        result = reader._collect_with_backend(123, backend)
        _assert(result["selection_state"] == expected_selection, "64-level cap is inclusive and fail closed")
        if depth == 64:
            _assert(len(result["resources"]) > 0, "64 visible levels remain observable")
        _assert(backend.open_fds == set(), "level-bound cleanup")
        cases += 3

    result, backend = collect(membership="0::/\n")
    _assert(result["selection_state"] == "SELECTED" and result["context_state"] == "BOUND", "root membership is allowed")
    _assert(len(result["resources"]) == 20, "single visible level source count")
    _assert(backend.open_fds == set(), "root membership cleanup")
    cases += 3

    ambiguous = (
        "29 23 0:24 / /proc rw - proc proc rw\n"
        "30 23 0:29 / /sys/fs/cgroup rw - cgroup2 cgroup rw\n"
        "31 23 0:30 / /alt/cgroup rw - cgroup2 cgroup rw\n"
    )
    result, backend = collect(mountinfo=ambiguous)
    _assert(result["selection_state"] == "AMBIGUOUS_MOUNT", "equal cgroup2 roots are ambiguous")
    _assert(backend.open_fds == set(), "ambiguous mount cleanup")
    cases += 2

    # API and CLI errors are stable and do not echo arguments or invoke the collector.
    for bad in (True, "123", 0, -1, 2_147_483_648):
        expected = TypeError if type(bad) is not int else ValueError
        _raises(expected, lambda bad=bad: reader.collect_process(bad), "target PID API validation")
        cases += 1
    for bad_text in ("١", "+1", "0", "2147483648", "9" * 50000):
        _raises(ValueError, lambda bad_text=bad_text: reader._cli_pid(bad_text), "strict bounded CLI PID")
        cases += 1
    stdout, stderr = StringIO(), StringIO()
    with redirect_stdout(stdout), redirect_stderr(stderr):
        invalid_code = reader.main(["--target-pid", "+123"])
    _assert(invalid_code == 2 and stdout.getvalue() == "" and stderr.getvalue() == "INVALID_ARGUMENT\n", "CLI rejects invalid PID without echo")
    cases += 1
    with patch.object(reader, "collect_process") as collector:
        stdout, stderr = StringIO(), StringIO()
        with redirect_stdout(stdout), redirect_stderr(stderr):
            code = reader.main(["--help"])
        _assert(code == 0 and "--target-pid" in stdout.getvalue() and not stderr.getvalue(), "help is static and successful")
    _assert(not collector.called, "help does not collect")
    cases += 2
    with patch.object(reader, "native_backend", side_effect=reader.UnsupportedNativeError("UNSUPPORTED_ABI")):
        unsupported = reader.collect_process(123)
    _assert(unsupported["context_state"] == "CONTEXT_UNBOUND" and unsupported["issues"][0]["reason_code"] == "UNSUPPORTED_ABI", "unsupported platform is a JSON observation")
    cases += 1

    return cases


def _assert(condition: bool, label: str) -> None:
    if not condition:
        raise AssertionError(label)


def _raises(expected: type[BaseException], callback: Any, label: str) -> BaseException:
    try:
        callback()
    except expected as error:
        return error
    except Exception as error:  # pragma: no cover - diagnostic path
        raise AssertionError(f"{label}: unexpected {type(error).__name__}") from None
    raise AssertionError(f"{label}: expected {expected.__name__}")


def _stop_and_join_thread(stop_event: threading.Event, thread: Any) -> None:
    stop_event.set()
    thread.join()
    if thread.is_alive():
        raise AssertionError("NATIVE_RACE_CLEANUP")


def _with_thread_cleanup(stop_event: threading.Event, thread: Any, callback: Any) -> Any:
    try:
        return callback()
    finally:
        _stop_and_join_thread(stop_event, thread)


def _cleanup_child_process(child: Any) -> None:
    if child.poll() is None:
        try:
            child.terminate()
        except ProcessLookupError:
            pass
        try:
            child.wait(timeout=5)
        except subprocess.TimeoutExpired:
            child.kill()
            child.wait(timeout=5)
    else:
        child.wait()


def _with_child_process(start_child: Any, callback: Any) -> Any:
    child = None
    try:
        child = start_child()
        return callback(child)
    finally:
        if child is not None:
            _cleanup_child_process(child)


def _load_child_dependencies(load_reader_fn: Any, backend_factory: Any) -> tuple[Any, Any]:
    reader = load_reader_fn()
    backend = backend_factory()
    return reader, backend


def run_cleanup_self_tests() -> int:
    cases = 0

    class FakeChild:
        def __init__(self, *, timeout_once: bool = False) -> None:
            self.running = True
            self.timeout_once = timeout_once
            self.terminate_calls = 0
            self.kill_calls = 0
            self.wait_calls = 0

        def poll(self):
            return None if self.running else 0

        def terminate(self):
            self.terminate_calls += 1
            self.running = False

        def kill(self):
            self.kill_calls += 1
            self.running = False

        def wait(self, timeout=None):
            del timeout
            self.wait_calls += 1
            if self.timeout_once:
                self.timeout_once = False
                raise subprocess.TimeoutExpired("synthetic-child", 5)
            self.running = False
            return 0

    for fail_stage, failure_code in (("reader", "SYNTHETIC_IMPORT_FAILURE"), ("backend", "SYNTHETIC_BACKEND_FAILURE")):
        child = FakeChild()

        def fake_loader(stage: str = fail_stage, code: str = failure_code) -> object:
            if stage == "reader":
                raise RuntimeError(code)
            return object()

        def fake_backend(stage: str = fail_stage, code: str = failure_code) -> object:
            if stage == "backend":
                raise RuntimeError(code)
            return object()

        error = _raises(
            RuntimeError,
            lambda: _with_child_process(
                lambda: child,
                lambda _child: _load_child_dependencies(fake_loader, fake_backend),
            ),
            "child cleanup after setup failure",
        )
        _assert(str(error) == failure_code, "setup failure propagates after cleanup")
        _assert((child.terminate_calls, child.wait_calls, child.kill_calls, child.running) == (1, 1, 0, False), "started child is terminated and reaped")
        cases += 1

    timed_out_child = FakeChild(timeout_once=True)
    _cleanup_child_process(timed_out_child)
    _assert((timed_out_child.terminate_calls, timed_out_child.kill_calls, timed_out_child.wait_calls, timed_out_child.running) == (1, 1, 2, False), "timed out child is killed and reaped")
    cases += 1

    start_error = _raises(
        RuntimeError,
        lambda: _with_child_process(lambda: (_ for _ in ()).throw(RuntimeError("SYNTHETIC_SPAWN_FAILURE")), lambda _child: None),
        "spawn failure has no child to clean",
    )
    _assert(str(start_error) == "SYNTHETIC_SPAWN_FAILURE", "spawn failure propagates")
    cases += 1

    stop_event = threading.Event()
    finished = threading.Event()
    worker = threading.Thread(target=lambda: (stop_event.wait(), finished.set()))
    worker.start()
    error = _raises(
        RuntimeError,
        lambda: _with_thread_cleanup(stop_event, worker, lambda: (_ for _ in ()).throw(RuntimeError("SYNTHETIC_PROBE_FAILURE"))),
        "race thread cleanup after probe failure",
    )
    _assert(str(error) == "SYNTHETIC_PROBE_FAILURE", "probe failure propagates after joining worker")
    _assert(finished.is_set() and not worker.is_alive(), "worker is stopped and joined after probe failure")
    cases += 2

    class UnjoinedThread:
        def join(self):
            return None

        def is_alive(self):
            return True

    failed_cleanup_stop = threading.Event()
    _raises(
        AssertionError,
        lambda: _with_thread_cleanup(failed_cleanup_stop, UnjoinedThread(), lambda: None),
        "unconfirmed worker cleanup fails",
    )
    _assert(failed_cleanup_stop.is_set(), "cleanup always signals stop before join")
    cases += 2
    return cases


def run_self_tests(repository_root: Path) -> int:
    native = load_native(repository_root)
    cases = 0

    _assert(ctypes.sizeof(native._OpenHow) == 24, "open_how size")
    _assert(ctypes.alignment(native._OpenHow) == 8, "open_how alignment")
    _assert(native._OpenHow.resolve.offset == 16, "open_how resolve offset")
    _assert(ctypes.sizeof(native._Statx) == 256, "statx size")
    _assert(native._Statx.mask.offset == 0, "statx mask offset")
    _assert(native._Statx.mode.offset == 28, "statx mode offset")
    _assert(native._Statx.ino.offset == 32, "statx inode offset")
    _assert(native._Statx.dev_major.offset == 136, "statx device major offset")
    _assert(native._Statx.dev_minor.offset == 140, "statx device minor offset")
    _assert(native._Statx.mnt_id.offset == 144, "statx mount id offset")
    _assert(native.STATX_REQUIRED_MASK == 0x1103, "statx required mask")
    cases += 11
    if ctypes.sizeof(ctypes.c_long) == 8:
        _assert(ctypes.sizeof(native._Statfs) == 120, "statfs size")
        _assert(ctypes.alignment(native._Statfs) == 8, "statfs alignment")
        _assert(native._Statfs.f_type.offset == 0, "statfs type offset")
        _assert(native._Statfs.f_bsize.offset == 8, "statfs block size offset")
        _assert(native._Statfs.f_blocks.offset == 16, "statfs blocks offset")
        _assert(native._Statfs.f_bfree.offset == 24, "statfs free blocks offset")
        _assert(native._Statfs.f_bavail.offset == 32, "statfs available blocks offset")
        _assert(native._Statfs.f_files.offset == 40, "statfs files offset")
        _assert(native._Statfs.f_ffree.offset == 48, "statfs free files offset")
        _assert(native._Statfs.f_fsid.offset == 56, "statfs fsid offset")
        _assert(native._Statfs.f_namelen.offset == 64, "statfs name length offset")
        _assert(native._Statfs.f_frsize.offset == 72, "statfs fragment size offset")
        _assert(native._Statfs.f_flags.offset == 80, "statfs flags offset")
        _assert(native._Statfs.f_spare.offset == 88, "statfs spare offset")
        cases += 13
    _raises(ValueError, lambda: native.ReadBudget(native.TOTAL_READ_LIMIT + 1), "total byte cap")
    _raises(ValueError, lambda: native.ReadBudget(1, float("inf")), "finite deadline cap")
    cases += 2

    native.LinuxCgroupNative.validate_statx_mask(0x1103 | 0x40 | 0x8000)
    cases += 1
    for missing in (native.STATX_TYPE, native.STATX_MODE, native.STATX_INO, native.STATX_MNT_ID):
        error = _raises(
            native.NativeFailure,
            lambda missing=missing: native.LinuxCgroupNative.validate_statx_mask(
                native.STATX_REQUIRED & ~missing
            ),
            "missing statx required bit",
        )
        _assert(error.code == "UNSUPPORTED_ABI", "missing statx bit code")
        cases += 1

    _assert(native._errno_code(errno.EACCES) == "PERMISSION_DENIED", "permission errno")
    _assert(native._errno_code(errno.EPERM) == "PERMISSION_DENIED", "operation permission errno")
    _assert(native._errno_code(errno.ELOOP) == "SYMLINK_REJECTED", "symlink errno")
    _assert(native._errno_code(errno.EXDEV) == "CROSS_MOUNT_REJECTED", "cross-mount errno")
    _assert(native._errno_code(errno.EAGAIN, context=True) == "CONTEXT_UNBOUND", "race errno")
    _assert(native._errno_code(errno.EIO) == "READ_ERROR", "read errno")
    cases += 6

    closes: list[int] = []
    zero_fd = native.OwnedFD(0)
    _assert(zero_fd.fd == 0, "fd zero is valid")
    live_handle = native.OwnedFD(9)
    for copier in (copy.copy, copy.deepcopy, pickle.dumps):
        _raises(TypeError, lambda copier=copier: copier(live_handle), "fd handle cannot be copied or pickled")
    detached = live_handle.detach()
    new_owner = native.OwnedFD(detached)
    with patch.object(native.os, "close", side_effect=closes.append):
        zero_fd.close()
        zero_fd.close()
        new_owner.close()
        live_handle.close()
    _assert(closes == [0, 9] and zero_fd.closed, "fd zero close and detach transfer happen once")
    _raises(native.NativeFailure, lambda: zero_fd.fd, "closed descriptor access")
    cases += 7

    failed_closes: list[int] = []

    def fail_close(fd: int) -> None:
        failed_closes.append(fd)
        raise OSError(errno.EIO, "synthetic")

    close_error_owner = native.OwnedFD(11)
    with patch.object(native.os, "close", side_effect=fail_close):
        _raises(OSError, close_error_owner.close, "close failure")
        close_error_owner.close()
    _assert(failed_closes == [11] and close_error_owner.closed, "close failure is not retried")
    cases += 1

    fake_backend_for_cleanup = object.__new__(native.LinuxCgroupNative)
    cleanup_fds: list[int] = []

    def fail_identity(*_args: Any, **_kwargs: Any) -> None:
        raise native.NativeFailure("CONTEXT_UNBOUND")

    fake_backend_for_cleanup.fd_identity = fail_identity
    with patch.object(native.os, "open", return_value=0), patch.object(native.os, "close", side_effect=cleanup_fds.append):
        _raises(
            native.NativeFailure,
            lambda: fake_backend_for_cleanup.open_proc_self(8, procfs_mount_id=10),
            "cleanup after identity failure",
        )
    _assert(cleanup_fds == [0], "opened fd closed on validation exception")
    cases += 1

    root_cleanup_fds: list[int] = []
    fake_root_backend = object.__new__(native.LinuxCgroupNative)
    fake_root_backend.filesystem_magic = lambda _fd: 0x1234
    fake_root_backend.fd_identity = fail_identity
    with (
        patch.object(native, "_require_supported_host"),
        patch.object(native.os, "open", return_value=0),
        patch.object(native.os, "close", side_effect=root_cleanup_fds.append),
    ):
        _raises(native.NativeFailure, fake_root_backend.open_root_anchor, "root anchor cleanup after identity failure")
    _assert(root_cleanup_fds == [0], "rejected root anchor closes acquired fd")
    cases += 1

    class FakeSyscall:
        def __init__(self, result: int, *, mask: int = 0, set_errno: int | None = None) -> None:
            self.result = result
            self.mask = mask
            self.set_errno = set_errno
            self.arguments: tuple[Any, ...] | None = None

        def __call__(self, *arguments: Any) -> int:
            self.arguments = arguments
            if self.set_errno is not None:
                ctypes.set_errno(self.set_errno)
            if self.result >= 0 and int(arguments[0].value) == native.SYSCALL_STATX_X86_64:
                output = arguments[-1]._obj
                output.mask = self.mask
                output.mode = 0o040755
                output.ino = 77
                output.dev_major = 8
                output.dev_minor = 4
                output.mnt_id = 321
            return self.result

    fake_backend = object.__new__(native.LinuxCgroupNative)
    fake_backend._syscall = FakeSyscall(
        0, mask=native.STATX_REQUIRED | 0x200000
    )
    observed = fake_backend.statx_fd(0)
    _assert(observed.mask == native.STATX_REQUIRED | 0x200000, "statx superset retained")
    _assert(observed.mount_id == 321 and observed.inode == 77, "statx typed fields")
    _assert(fake_backend._syscall.arguments[1].value == 0, "statx accepts fd zero")
    cases += 3

    fake_backend._syscall = FakeSyscall(0, mask=native.STATX_REQUIRED & ~native.STATX_MNT_ID)
    error = _raises(native.NativeFailure, lambda: fake_backend.statx_fd(12), "statx missing mount bit")
    _assert(error.code == "UNSUPPORTED_ABI", "statx missing-bit failure")
    fake_backend._syscall = FakeSyscall(-1, set_errno=errno.ELOOP)
    error = _raises(native.NativeFailure, lambda: fake_backend.statx_fd(12), "native syscall errno")
    _assert((error.code, error.native_errno) == ("SYMLINK_REJECTED", errno.ELOOP), "errno copied immediately")
    cases += 2

    fake_backend._syscall = FakeSyscall(0)
    fake_open = fake_backend.open_relative(
        native.AT_FDCWD, b"synthetic", flags=native.O_PATH | native.O_DIRECTORY | native.O_CLOEXEC
    )
    open_arguments = fake_backend._syscall.arguments
    open_how = open_arguments[3]._obj
    _assert(fake_open.fd == 0, "openat2 owns fd zero")
    _assert(open_how.resolve == 0x0F and open_how.flags == (0x200000 | 0x10000 | 0x80000), "descendant policy flags")
    _assert(open_arguments[-1].value == 24, "openat2 structure size")
    fake_close_calls: list[int] = []
    with patch.object(native.os, "close", side_effect=fake_close_calls.append):
        fake_open.close()
    _raises(
        TypeError,
        lambda: fake_backend.open_relative(
            4, b"child", flags=native.O_PATH, descendant=False
        ),
        "descendant cannot disable no-xdev",
    )
    proc_fd_decoy = native.OwnedFD(4)
    cgroup_fd_decoy = native.OwnedFD(5)
    for label, decoy in (("proc", proc_fd_decoy), ("cgroup", cgroup_fd_decoy)):
        _raises(
            TypeError,
            lambda decoy=decoy: fake_backend.open_anchor(
                decoy, b"mount", flags=native.O_PATH, expected_magic=0x1234
            ),
            f"{label} fd cannot request anchor policy",
        )
        with patch.object(native.os, "close", side_effect=fake_close_calls.append):
            decoy.close()
    root_identity = native.FdIdentity(0x1234, 1, 2, 0o040755, 3)
    fake_backend.fd_identity = lambda _fd, **_kwargs: root_identity
    fake_backend._syscall = FakeSyscall(0)
    test_root_anchor = native.RootAnchor(
        native.OwnedFD(6), root_identity, anchor_guard=native._ROOT_ANCHOR_TOKEN
    )
    for copier in (copy.copy, copy.deepcopy, pickle.dumps):
        _raises(TypeError, lambda copier=copier: copier(test_root_anchor), "root anchor cannot be copied or pickled")
    fake_backend.fd_identity = lambda _fd, **_kwargs: native.FdIdentity(0x1234, 1, 2, 0o040755, 4)
    anchor_reject_syscall = FakeSyscall(0)
    fake_backend._syscall = anchor_reject_syscall
    rejection = _raises(
        native.NativeFailure,
        lambda: fake_backend.open_anchor(
            test_root_anchor, b"mount", flags=native.O_PATH, expected_magic=0x1234
        ),
        "changed root identity rejects mount crossing",
    )
    _assert(rejection.code == "CONTEXT_UNBOUND" and anchor_reject_syscall.arguments is None, "anchor failure occurs before openat2")
    anchor_checks = 0

    def fail_new_anchor_identity(_fd: int, **_kwargs: Any) -> Any:
        nonlocal anchor_checks
        anchor_checks += 1
        if anchor_checks == 1:
            return root_identity
        raise native.NativeFailure("FILESYSTEM_MISMATCH")

    fake_backend.fd_identity = fail_new_anchor_identity
    fake_backend._syscall = FakeSyscall(0)
    rejected_anchor_closes: list[int] = []
    with patch.object(native.os, "close", side_effect=rejected_anchor_closes.append):
        rejected_anchor = _raises(
            native.NativeFailure,
            lambda: fake_backend.open_anchor(
                test_root_anchor, b"mount", flags=native.O_PATH, expected_magic=0x1234
            ),
            "opened anchor fails filesystem identity",
        )
    _assert(rejected_anchor.code == "FILESYSTEM_MISMATCH" and rejected_anchor_closes == [0], "rejected anchor closes fd")
    anchor_checks = 0

    def fail_new_anchor_mount(_fd: int, **_kwargs: Any) -> Any:
        nonlocal anchor_checks
        anchor_checks += 1
        if anchor_checks == 1:
            return root_identity
        raise native.NativeFailure("MOUNT_CHANGED")

    fake_backend.fd_identity = fail_new_anchor_mount
    fake_backend._syscall = FakeSyscall(0)
    rejected_mount_closes: list[int] = []
    with patch.object(native.os, "close", side_effect=rejected_mount_closes.append):
        rejected_mount = _raises(
            native.NativeFailure,
            lambda: fake_backend.open_anchor(
                test_root_anchor,
                b"mount",
                flags=native.O_PATH,
                expected_magic=0x1234,
                expected_mount_id=3,
            ),
            "opened anchor fails selected mount identity",
        )
    _assert(rejected_mount.code == "MOUNT_CHANGED" and rejected_mount_closes == [0], "mount mismatch closes fd")
    fake_backend.fd_identity = lambda _fd, **_kwargs: root_identity
    fake_backend._syscall = FakeSyscall(0)
    anchor_fd = fake_backend.open_anchor(
        test_root_anchor,
        b"mount",
        flags=native.O_PATH,
        expected_magic=0x1234,
        expected_mount_id=3,
    )
    anchor_how = fake_backend._syscall.arguments[3]._obj
    _assert(anchor_how.resolve == 0x0E, "anchor crossing policy only from root handle")
    _assert(anchor_fd.identity == root_identity, "anchor result carries checked mount identity")
    with patch.object(native.os, "close", side_effect=fake_close_calls.append):
        anchor_fd.close()
        test_root_anchor.close()
    rejected_root_owner = native.OwnedFD(7)
    _raises(
        TypeError,
        lambda: native.RootAnchor(rejected_root_owner, root_identity, anchor_guard=object()),
        "root anchor provenance token",
    )
    with patch.object(native.os, "close", side_effect=fake_close_calls.append):
        rejected_root_owner.close()
    _raises(
        ValueError,
        lambda: fake_backend.open_relative(native.AT_FDCWD, b"synthetic", flags=os.O_WRONLY),
        "write flags rejected",
    )
    fake_backend._syscall = FakeSyscall(-1, set_errno=errno.ENOENT)
    missing_resource = _raises(
        native.NativeFailure,
        lambda: fake_backend.open_relative(native.AT_FDCWD, b"resource", flags=os.O_RDONLY, context=False),
        "missing resource mapping",
    )
    _assert(missing_resource.code == "MISSING", "selected resource errno")
    missing_fence = _raises(
        native.NativeFailure,
        lambda: fake_backend.open_relative(native.AT_FDCWD, b"fence", flags=os.O_RDONLY),
        "missing fence mapping",
    )
    _assert(missing_fence.code == "CONTEXT_UNBOUND", "context fence errno")
    cases += 20

    def fake_fstatfs(fd: int, output: Any) -> int:
        _assert(fd == 0, "fstatfs accepts fd zero")
        output._obj.f_type = native.CGROUP2_SUPER_MAGIC
        return 0

    fake_backend._fstatfs = fake_fstatfs
    _assert(fake_backend.filesystem_magic(0) == native.CGROUP2_SUPER_MAGIC, "fstatfs typed result")
    cases += 1

    budget = native.ReadBudget(native.RESOURCE_READ_LIMIT * 2, 10, clock=lambda: 1.0)
    chunks = iter((b"abc", b"def", b""))
    requested: list[int] = []

    def under_cap_reader(_fd: int, amount: int) -> bytes:
        requested.append(amount)
        return next(chunks)

    under_cap = native.LinuxCgroupNative.read_bounded(
        0, source_kind="RESOURCE", budget=budget, reader=under_cap_reader, clock=lambda: 1.0
    )
    _assert((under_cap.read_state, under_cap.byte_count, under_cap.raw_value) == ("AVAILABLE", "6", b"abcdef"), "EOF below cap")
    _assert(requested == [native.RESOURCE_READ_LIMIT, native.RESOURCE_READ_LIMIT - 3, native.RESOURCE_READ_LIMIT - 6], "bounded short reads")
    cases += 2

    exact_budget = native.ReadBudget(4, 10, clock=lambda: 1.0)
    exact_reads: list[int] = []
    exact = native.LinuxCgroupNative.read_bounded(
        4,
        source_kind="RESOURCE",
        budget=exact_budget,
        reader=lambda _fd, amount: (exact_reads.append(amount) or b"1234"),
        clock=lambda: 1.0,
    )
    _assert((exact.read_state, exact.byte_count, exact.raw_value) == ("LIMIT_REACHED", "4", None), "exact total cap is incomplete")
    _assert(exact_reads == [4], "no EOF probe beyond total cap")
    cases += 2

    file_cap_reads: list[int] = []
    file_cap = native.LinuxCgroupNative.read_bounded(
        5,
        source_kind="RESOURCE",
        budget=native.ReadBudget(native.RESOURCE_READ_LIMIT + 1, 10, clock=lambda: 1.0),
        reader=lambda _fd, amount: (file_cap_reads.append(amount) or b"x" * amount),
        clock=lambda: 1.0,
    )
    _assert(file_cap.read_state == "LIMIT_REACHED" and file_cap.raw_value is None, "exact file cap is incomplete")
    _assert(file_cap_reads == [native.RESOURCE_READ_LIMIT], "no EOF probe beyond file cap")
    cases += 2

    procfs_amounts: list[int] = []
    procfs_eof = native.LinuxCgroupNative.read_bounded(
        5,
        source_kind="PROCFS",
        budget=native.ReadBudget(native.PROCFS_READ_LIMIT * 2, 10, clock=lambda: 1.0),
        reader=lambda _fd, amount: (procfs_amounts.append(amount) or b""),
        clock=lambda: 1.0,
    )
    _assert(procfs_eof.read_state == "AVAILABLE" and procfs_amounts == [native.PROCFS_READ_LIMIT], "fixed procfs source cap")
    procfs_missing = native.LinuxCgroupNative.read_bounded(
        5,
        source_kind="PROCFS",
        budget=native.ReadBudget(8, 10, clock=lambda: 1.0),
        reader=lambda _fd, _amount: (_ for _ in ()).throw(OSError(errno.ENOENT, "synthetic")),
        clock=lambda: 1.0,
    )
    resource_missing = native.LinuxCgroupNative.read_bounded(
        5,
        source_kind="RESOURCE",
        budget=native.ReadBudget(8, 10, clock=lambda: 1.0),
        reader=lambda _fd, _amount: (_ for _ in ()).throw(OSError(errno.ENOENT, "synthetic")),
        clock=lambda: 1.0,
    )
    _assert((procfs_missing.read_state, procfs_missing.native_errno) == ("CONTEXT_UNBOUND", str(errno.ENOENT)), "procfs fence missing mapping")
    _assert((resource_missing.read_state, resource_missing.native_errno) == ("MISSING", str(errno.ENOENT)), "resource missing mapping remains")
    _raises(
        ValueError,
        lambda: native.LinuxCgroupNative.read_bounded(
            1, source_kind="OTHER", budget=native.ReadBudget(1, 1), reader=lambda _fd, _n: b""
        ),
        "unknown source cap",
    )
    cases += 4

    zero_read_calls: list[int] = []
    deadline_clock = iter((0.0, 2.0))
    deadline = native.LinuxCgroupNative.read_bounded(
        6,
        source_kind="RESOURCE",
        budget=native.ReadBudget(4, 1, clock=lambda: 0.0),
        reader=lambda _fd, amount: (zero_read_calls.append(amount) or b"x"),
        clock=lambda: next(deadline_clock),
    )
    _assert(deadline.read_state == "DEADLINE_REACHED" and zero_read_calls == [], "deadline blocks next read")
    after_read_clock = iter((0.0, 0.0, 2.0))
    after_read_calls: list[int] = []
    after_read = native.LinuxCgroupNative.read_bounded(
        6,
        source_kind="RESOURCE",
        budget=native.ReadBudget(4, 1, clock=lambda: 0.0),
        reader=lambda _fd, amount: (after_read_calls.append(amount) or b"x"),
        clock=lambda: next(after_read_clock),
    )
    _assert(after_read.read_state == "DEADLINE_REACHED" and after_read.raw_value is None, "deadline after partial read")
    _assert(len(after_read_calls) == 1, "deadline blocks subsequent read")
    read_error = native.LinuxCgroupNative.read_bounded(
        7,
        source_kind="RESOURCE",
        budget=native.ReadBudget(4, 10, clock=lambda: 0.0),
        reader=lambda _fd, _amount: (_ for _ in ()).throw(OSError(errno.EIO, "synthetic")),
        clock=lambda: 0.0,
    )
    _assert((read_error.read_state, read_error.native_errno, read_error.raw_value) == ("READ_ERROR", str(errno.EIO), None), "read error has no partial value")
    cases += 4

    for native_errno, expected_code in (
        (errno.EACCES, "PERMISSION_DENIED"),
        (errno.EPERM, "PERMISSION_DENIED"),
        (errno.EINTR, "READ_ERROR"),
    ):
        calls: list[int] = []

        def partial_then_error(_fd: int, amount: int, *, code: int = native_errno) -> bytes:
            calls.append(amount)
            if len(calls) == 1:
                return b"abc"
            raise OSError(code, "synthetic")

        budget_after_partial = native.ReadBudget(10, 10, clock=lambda: 0.0)
        partial_error = native.LinuxCgroupNative.read_bounded(
            8,
            source_kind="RESOURCE",
            budget=budget_after_partial,
            reader=partial_then_error,
            clock=lambda: 0.0,
        )
        _assert(partial_error.read_state == expected_code, "read errno classification")
        _assert(partial_error.reason_code == expected_code, "read reason classification")
        _assert(partial_error.byte_count == "3" and budget_after_partial.bytes_read == 3, "partial bytes counted once")
        _assert(partial_error.raw_value is None and partial_error.native_errno == str(native_errno), "partial read is not parseable and errno is preserved")
        _assert(len(calls) == 2, "read error is not retried")
        cases += 5

    no_native_call = False
    if sys.platform != "linux" or platform_machine() not in {"x86_64", "amd64"}:
        error = _raises(native.UnsupportedNativeError, native.native_backend, "unsupported host")
        no_native_call = error.code == "UNSUPPORTED_ABI"
        _assert(no_native_call, "unsupported host rejected before native loading")
        cases += 1

    return cases + run_reader_self_tests(repository_root) + run_cleanup_self_tests()


def platform_machine() -> str:
    import platform

    return platform.machine().lower()


def run_native_tests(repository_root: Path) -> int:
    if sys.platform != "linux" or platform_machine() not in {"x86_64", "amd64"}:
        raise AssertionError("NATIVE_UNSUPPORTED_ABI")
    native = load_native(repository_root)
    codes = native.live_probe()
    backend = native.native_backend()
    with tempfile.TemporaryDirectory(prefix="cgroup-native-") as temp_dir:
        root_fd = os.open(temp_dir, native.O_PATH | native.O_DIRECTORY | native.O_CLOEXEC)
        try:
            with backend.open_relative(root_fd, b".", flags=native.O_PATH | native.O_DIRECTORY | native.O_CLOEXEC) as directory:
                identity = backend.fd_identity(directory.fd, expected_magic=backend.filesystem_magic(directory.fd))
                if identity.inode == 0:
                    raise AssertionError("NATIVE_DIRECTORY_IDENTITY")
            with open(Path(temp_dir) / "sample", "wb") as handle:
                handle.write(b"synthetic")
            os.symlink(Path(temp_dir) / "sample", Path(temp_dir) / "link")
            try:
                backend.open_relative(root_fd, b"link", flags=os.O_RDONLY | os.O_CLOEXEC)
            except native.NativeFailure as error:
                if error.code != "SYMLINK_REJECTED":
                    raise AssertionError("NATIVE_SYMLINK_REJECTION") from None
            else:
                raise AssertionError("NATIVE_SYMLINK_ACCEPTED")
            sample_fd = os.open(Path(temp_dir) / "sample", os.O_RDONLY | os.O_CLOEXEC)
            try:
                observation = backend.read_bounded(
                    sample_fd,
                    source_kind="RESOURCE",
                    budget=native.ReadBudget(64, 3),
                )
                if (observation.read_state, observation.raw_value) != ("AVAILABLE", b"synthetic"):
                    raise AssertionError("NATIVE_READ_EOF")
            finally:
                os.close(sample_fd)

            race_entry = Path(temp_dir) / "race-entry"
            race_backup = Path(temp_dir) / "race-backup"
            race_outside = Path(temp_dir) / "outside"
            race_entry.mkdir()
            race_outside.mkdir()
            (race_entry / "value").write_bytes(b"inside")
            (race_outside / "value").write_bytes(b"outside")
            race_started = threading.Event()
            race_stop = threading.Event()
            race_failures: list[str] = []

            def replace_with_link() -> None:
                race_started.set()
                try:
                    for _ in range(80):
                        if race_stop.is_set():
                            return
                        try:
                            if race_entry.exists() and not race_entry.is_symlink():
                                os.rename(race_entry, race_backup)
                            if not race_entry.exists() and not race_entry.is_symlink():
                                os.symlink(race_outside, race_entry, target_is_directory=True)
                            if race_entry.is_symlink():
                                race_entry.unlink()
                            if race_backup.exists() and not race_entry.exists():
                                os.rename(race_backup, race_entry)
                        except OSError:
                            continue
                except BaseException:
                    race_failures.append("NATIVE_RACE_THREAD_ERROR")

            racer = threading.Thread(target=replace_with_link)
            racer.start()
            try:
                if not race_started.wait(timeout=2):
                    raise AssertionError("NATIVE_RACE_START")
                for _ in range(100):
                    try:
                        with backend.open_relative(root_fd, b"race-entry/value", flags=os.O_RDONLY | os.O_CLOEXEC) as race_fd:
                            payload = os.read(race_fd.fd, 16)
                            if payload != b"inside":
                                raise AssertionError("NATIVE_RACE_ESCAPED")
                    except native.NativeFailure as error:
                        if error.code not in {"SYMLINK_REJECTED", "CONTEXT_UNBOUND", "MISSING", "CROSS_MOUNT_REJECTED"}:
                            raise AssertionError("NATIVE_RACE_CODE") from None
            finally:
                _stop_and_join_thread(race_stop, racer)
            if race_failures:
                raise AssertionError("NATIVE_RACE_THREAD_ERROR")
        finally:
            os.close(root_fd)

    def inspect_child(child: subprocess.Popen[Any]) -> Any:
        reader, reader_backend = _load_child_dependencies(
            lambda: load_reader(repository_root),
            lambda: sys.modules["Linux_Cgroup_Native"].native_backend(),
        )
        with reader_backend.open_pidfd(child.pid) as pidfd:
            if not reader_backend.pidfd_alive(pidfd.fd):
                raise AssertionError("NATIVE_PIDFD_LIVENESS")
            child_observation = reader._collect_with_backend(child.pid, reader_backend)
            if child_observation["selection_state"] != "SELECTED" or child_observation["context_state"] != "BOUND":
                raise AssertionError("NATIVE_CHILD_READER_CONTEXT")
            child_memory = [record for record in child_observation["resources"] if record["source_key"] == "memory.current" and record["observation_phase"] == "MAIN_READ"]
            if len(child_memory) != 1 or child_memory[0]["read_state"] != "AVAILABLE" or child_memory[0]["parse_state"] != "VALID":
                raise AssertionError("NATIVE_CHILD_READER_RESOURCE")
            child.terminate()
            child.wait(timeout=5)
            if reader_backend.pidfd_alive(pidfd.fd):
                raise AssertionError("NATIVE_PIDFD_EXIT")
        return reader_backend

    reader_backend = _with_child_process(
        lambda: subprocess.Popen(
            [sys.executable, "-c", "import time; time.sleep(30)"],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        ),
        inspect_child,
    )
    observed = reader._collect_with_backend(os.getpid(), reader_backend)
    if observed["selection_state"] != "SELECTED" or observed["context_state"] != "BOUND":
        raise AssertionError("NATIVE_READER_CONTEXT")
    own_leaf = [record for record in observed["resources"] if record["source_key"] == "memory.current" and record["observation_phase"] == "MAIN_READ"]
    if len(own_leaf) != 1 or own_leaf[0]["read_state"] != "AVAILABLE" or own_leaf[0]["parse_state"] != "VALID":
        raise AssertionError("NATIVE_READER_RESOURCE")
    if any(str(record["source_key"]).startswith("proc.") for record in observed["resources"]):
        raise AssertionError("NATIVE_PROCFS_REDACTION")
    return len(codes) + 13


def validate_source(repository_root: Path) -> None:
    reader_path = repository_root / READER_PATH
    native_path = repository_root / NATIVE_RELATIVE_PATH
    validator_path = repository_root / "Code/Tests/Static/Validate_Linux_Cgroup_Reader.py"
    workflow_path = repository_root / WORKFLOW_RELATIVE_PATH
    for path in (reader_path, native_path, validator_path, workflow_path):
        if not path.is_file():
            raise AssertionError("LINUX_READER_SOURCE_MISSING")
    reader_source = reader_path.read_text(encoding="utf-8")
    for required in (
        "def collect_process(target_pid: int)",
        '"schema_version": "linux-cgroup-observation/1"',
        '"target_identity": "CALLER_SELECTED_PROCESS"',
        '"global_hierarchy": "UNVERIFIED"',
        '"sql_binding": "UNVERIFIED"',
        '"event_scope": "UNVERIFIED"',
        "def _closing_fence(",
        "def _derive_metrics(",
        "self.backend.read_bounded(",
    ):
        if required not in reader_source:
            raise AssertionError("LINUX_READER_CONTRACT_MARKER")
    native_source = native_path.read_text(encoding="utf-8")
    for required in ("def open_anchor(", "def open_relative(", "def read_bounded(", "class ReadBudget"):
        if required not in native_source:
            raise AssertionError("LINUX_READER_NATIVE_MARKER")
    validator_source = validator_path.read_text(encoding="utf-8")
    if "def run_reader_self_tests(" not in validator_source or "def run_native_tests(" not in validator_source:
        raise AssertionError("LINUX_READER_TEST_MODES")
    workflow = workflow_path.read_text(encoding="utf-8")
    for required in (
        "linux_reader",
        "Run required native Linux cgroup reader contracts",
        "actions/setup-python@5fda3b95a4ea91299a34e894583c3862153e4b97",
        "python-version: '3.11'",
        "Validate_Linux_Cgroup_Reader.py --repository-root . --native",
    ):
        if required not in workflow:
            raise AssertionError("LINUX_READER_CI_WIRING")
    selector_match = re.search(r"(?m)^\s*set_flag linux_reader '([^']+)'$", workflow)
    if selector_match is None:
        raise AssertionError("LINUX_READER_WORKFLOW_SELF_TRIGGER")
    selector = re.compile(selector_match.group(1))
    if not selector.fullmatch(".github/workflows/documentation-validation.yml"):
        raise AssertionError("LINUX_READER_WORKFLOW_SELF_TRIGGER")
    if not selector.fullmatch("Code/Tools/Linux_Cgroup_Reader.py"):
        raise AssertionError("LINUX_READER_WORKFLOW_READER_TRIGGER")
    if selector.fullmatch("Code/01_Common/100_USP_AnalysisNavigator.sql"):
        raise AssertionError("LINUX_READER_WORKFLOW_SQL_ISOLATION")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path, required=True)
    group = parser.add_mutually_exclusive_group(required=False)
    group.add_argument("--self-test", action="store_true")
    group.add_argument("--native", action="store_true")
    args = parser.parse_args()
    root = args.repository_root.resolve()
    try:
        if args.self_test:
            cases = run_self_tests(root)
            mode = "SELF_TEST"
        elif args.native:
            cases = run_native_tests(root)
            mode = "NATIVE"
        else:
            validate_source(root)
            print("Linux cgroup reader source contract: PASS")
            return 0
    except Exception as error:
        code = getattr(error, "code", None)
        if code is None:
            code = error.args[0] if isinstance(error, AssertionError) and error.args else "VALIDATION_FAILURE"
        print(f"Linux cgroup native validator failed: {code}", file=sys.stderr)
        return 1
    print(f"Linux cgroup reader validator passed: mode={mode} cases={cases}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
