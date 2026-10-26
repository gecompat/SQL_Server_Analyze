"""Narrow Linux x86_64 primitives for a future cgroup-v2 reader.

Import is portable. Native ABI checks and system calls happen only after an
explicit backend construction on a supported Linux host.
"""

from __future__ import annotations

import ctypes
import math
import os
import platform
import select
import stat
import struct
import sys
import time
from dataclasses import dataclass
from typing import Callable, Final


U64_MAX: Final = 18_446_744_073_709_551_615
RESOURCE_READ_LIMIT: Final = 64 * 1024
PROCFS_READ_LIMIT: Final = 512 * 1024
TOTAL_READ_LIMIT: Final = 8 * 1024 * 1024
READ_DEADLINE_SECONDS: Final = 10.0
AT_FDCWD: Final = -100
AT_EMPTY_PATH: Final = 0x1000
O_PATH: Final = 0x200000
O_DIRECTORY: Final = 0x10000
O_CLOEXEC: Final = 0x80000
RESOLVE_NO_XDEV: Final = 0x01
RESOLVE_NO_MAGICLINKS: Final = 0x02
RESOLVE_NO_SYMLINKS: Final = 0x04
RESOLVE_BENEATH: Final = 0x08
RESOLVE_ANCHOR: Final = RESOLVE_BENEATH | RESOLVE_NO_SYMLINKS | RESOLVE_NO_MAGICLINKS
RESOLVE_DESCENDANT: Final = RESOLVE_ANCHOR | RESOLVE_NO_XDEV
_ALLOWED_OPEN_FLAGS: Final = O_PATH | O_DIRECTORY | O_CLOEXEC
STATX_TYPE: Final = 0x0001
STATX_MODE: Final = 0x0002
STATX_INO: Final = 0x0100
STATX_MNT_ID: Final = 0x1000
STATX_REQUIRED: Final = STATX_TYPE | STATX_MODE | STATX_INO | STATX_MNT_ID
STATX_REQUIRED_MASK: Final = 0x1103
PROC_SUPER_MAGIC: Final = 0x9FA0
CGROUP2_SUPER_MAGIC: Final = 0x63677270
NSFS_MAGIC: Final = 0x6E736673
NS_GET_NSTYPE: Final = 0xB703
CLONE_NEWPID: Final = 0x20000000
CLONE_NEWNS: Final = 0x00020000
CLONE_NEWCGROUP: Final = 0x02000000
SYSCALL_STATX_X86_64: Final = 332
SYSCALL_OPENAT2_X86_64: Final = 437


class NativeFailure(Exception):
    """Controlled native failure without paths or operating-system text."""

    def __init__(self, code: str, native_errno: int | None = None) -> None:
        super().__init__(code)
        self.code = code
        self.native_errno = native_errno


class UnsupportedNativeError(NativeFailure):
    """The host or kernel cannot satisfy the fixed ABI contract."""


class _OpenHow(ctypes.Structure):
    _fields_ = [
        ("flags", ctypes.c_uint64),
        ("mode", ctypes.c_uint64),
        ("resolve", ctypes.c_uint64),
    ]


class _Statx(ctypes.Structure):
    _fields_ = [
        ("mask", ctypes.c_uint32),
        ("blksize", ctypes.c_uint32),
        ("attributes", ctypes.c_uint64),
        ("nlink", ctypes.c_uint32),
        ("uid", ctypes.c_uint32),
        ("gid", ctypes.c_uint32),
        ("mode", ctypes.c_uint16),
        ("spare0", ctypes.c_uint16),
        ("ino", ctypes.c_uint64),
        ("size", ctypes.c_uint64),
        ("blocks", ctypes.c_uint64),
        ("attributes_mask", ctypes.c_uint64),
        ("_timestamps", ctypes.c_uint8 * 64),
        ("rdev_major", ctypes.c_uint32),
        ("rdev_minor", ctypes.c_uint32),
        ("dev_major", ctypes.c_uint32),
        ("dev_minor", ctypes.c_uint32),
        ("mnt_id", ctypes.c_uint64),
        ("_remaining", ctypes.c_uint8 * 104),
    ]


class _Fsid(ctypes.Structure):
    _fields_ = [("value", ctypes.c_int32 * 2)]


class _Statfs(ctypes.Structure):
    _fields_ = [
        ("f_type", ctypes.c_long),
        ("f_bsize", ctypes.c_long),
        ("f_blocks", ctypes.c_ulong),
        ("f_bfree", ctypes.c_ulong),
        ("f_bavail", ctypes.c_ulong),
        ("f_files", ctypes.c_ulong),
        ("f_ffree", ctypes.c_ulong),
        ("f_fsid", _Fsid),
        ("f_namelen", ctypes.c_long),
        ("f_frsize", ctypes.c_long),
        ("f_flags", ctypes.c_long),
        ("f_spare", ctypes.c_long * 4),
    ]


@dataclass(frozen=True)
class StatxInfo:
    mask: int
    mode: int
    inode: int
    dev_major: int
    dev_minor: int
    mount_id: int


@dataclass(frozen=True)
class FdIdentity:
    filesystem_magic: int
    device: int
    inode: int
    mode: int
    mount_id: int


@dataclass(frozen=True)
class ReadObservation:
    read_state: str
    byte_count: str
    raw_value: bytes | None
    reason_code: str | None
    native_errno: str | None


class OwnedFD:
    """Single-owner descriptor; descriptor zero is valid and close is once."""

    __slots__ = ("_fd", "_closed", "_identity")

    def __init__(self, fd: int, identity: FdIdentity | None = None) -> None:
        if type(fd) is not int or fd < 0:
            raise TypeError("fd must be a nonnegative int")
        if identity is not None and not isinstance(identity, FdIdentity):
            raise TypeError("identity must be FdIdentity or None")
        self._fd = fd
        self._closed = False
        self._identity = identity

    @property
    def fd(self) -> int:
        if self._closed:
            raise NativeFailure("FD_CLOSED")
        return self._fd

    @property
    def closed(self) -> bool:
        return self._closed

    @property
    def identity(self) -> FdIdentity | None:
        return self._identity

    def close(self) -> None:
        if self._closed:
            return
        self._closed = True
        os.close(self._fd)

    def detach(self) -> int:
        if self._closed:
            raise NativeFailure("FD_CLOSED")
        self._closed = True
        return self._fd

    def __enter__(self) -> OwnedFD:
        if self._closed:
            raise NativeFailure("FD_CLOSED")
        return self

    def __exit__(self, exc_type: object, exc: object, traceback: object) -> None:
        self.close()

    def __copy__(self) -> OwnedFD:
        raise TypeError("FD handles cannot be copied")

    def __deepcopy__(self, memo: dict[int, object]) -> OwnedFD:
        del memo
        raise TypeError("FD handles cannot be copied")

    def __reduce__(self) -> object:
        raise TypeError("FD handles cannot be serialized")

    def __reduce_ex__(self, protocol: int) -> object:
        del protocol
        raise TypeError("FD handles cannot be serialized")


_ROOT_ANCHOR_TOKEN = object()


class RootAnchor:
    """Single-owner descriptor acquired and verified for the fixed root."""

    __slots__ = ("_owned_fd", "_identity")

    def __init__(self, owned_fd: OwnedFD, identity: FdIdentity, *, anchor_guard: object) -> None:
        if anchor_guard is not _ROOT_ANCHOR_TOKEN:
            raise TypeError("RootAnchor is created only by the native backend")
        if not isinstance(owned_fd, OwnedFD) or owned_fd.closed:
            raise TypeError("RootAnchor requires an open owned fd")
        if not isinstance(identity, FdIdentity):
            raise TypeError("identity must be FdIdentity")
        self._owned_fd = owned_fd
        self._identity = identity

    @property
    def fd(self) -> int:
        return self._owned_fd.fd

    @property
    def identity(self) -> FdIdentity:
        return self._identity

    @property
    def closed(self) -> bool:
        return self._owned_fd.closed

    def close(self) -> None:
        self._owned_fd.close()

    def __enter__(self) -> RootAnchor:
        if self.closed:
            raise NativeFailure("FD_CLOSED")
        return self

    def __exit__(self, exc_type: object, exc: object, traceback: object) -> None:
        self.close()

    def __copy__(self) -> RootAnchor:
        raise TypeError("FD handles cannot be copied")

    def __deepcopy__(self, memo: dict[int, object]) -> RootAnchor:
        del memo
        raise TypeError("FD handles cannot be copied")

    def __reduce__(self) -> object:
        raise TypeError("FD handles cannot be serialized")

    def __reduce_ex__(self, protocol: int) -> object:
        del protocol
        raise TypeError("FD handles cannot be serialized")


class ReadBudget:
    """Shared actual-byte and monotonic admission budget for descriptor reads."""

    __slots__ = ("byte_limit", "deadline", "bytes_read", "_clock")

    def __init__(
        self,
        byte_limit: int = TOTAL_READ_LIMIT,
        deadline_seconds: float = READ_DEADLINE_SECONDS,
        *,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        if type(byte_limit) is not int or byte_limit < 0 or byte_limit > TOTAL_READ_LIMIT:
            raise ValueError("invalid byte limit")
        if (
            type(deadline_seconds) not in (int, float)
            or deadline_seconds < 0
            or deadline_seconds > READ_DEADLINE_SECONDS
            or not math.isfinite(deadline_seconds)
        ):
            raise ValueError("invalid deadline")
        self.byte_limit = byte_limit
        self._clock = clock
        self.deadline = clock() + deadline_seconds
        self.bytes_read = 0

    @property
    def remaining_bytes(self) -> int:
        return max(0, self.byte_limit - self.bytes_read)

    def admission_state(self) -> str | None:
        if self._clock() >= self.deadline:
            return "DEADLINE_REACHED"
        if self.remaining_bytes <= 0:
            return "LIMIT_REACHED"
        return None

    def account(self, count: int) -> None:
        if type(count) is not int or count < 0 or count > self.remaining_bytes:
            raise NativeFailure("BYTE_BUDGET_INVARIANT")
        self.bytes_read += count


def _require_supported_host() -> None:
    if sys.platform != "linux" or platform.machine().lower() not in {"x86_64", "amd64"}:
        raise UnsupportedNativeError("UNSUPPORTED_ABI")
    if sys.byteorder != "little" or ctypes.sizeof(ctypes.c_long) != 8:
        raise UnsupportedNativeError("UNSUPPORTED_ABI")
    if sys.version_info < (3, 11):
        raise UnsupportedNativeError("UNSUPPORTED_ABI")
    if ctypes.sizeof(ctypes.c_void_p) != 8:
        raise UnsupportedNativeError("UNSUPPORTED_ABI")


def _validate_layouts() -> None:
    expected = (
        (_OpenHow, 24, 8, {"flags": 0, "mode": 8, "resolve": 16}),
        (_Statx, 256, 8, {"mask": 0, "mode": 28, "ino": 32, "dev_major": 136, "dev_minor": 140, "mnt_id": 144}),
        (_Statfs, 120, 8, {"f_type": 0, "f_bsize": 8, "f_blocks": 16, "f_fsid": 56, "f_namelen": 64, "f_frsize": 72, "f_flags": 80, "f_spare": 88}),
    )
    for structure, size, alignment, offsets in expected:
        if ctypes.sizeof(structure) != size or ctypes.alignment(structure) != alignment:
            raise UnsupportedNativeError("UNSUPPORTED_ABI")
        for name, offset in offsets.items():
            if getattr(structure, name).offset != offset:
                raise UnsupportedNativeError("UNSUPPORTED_ABI")
    if struct.calcsize("P") != 8 or struct.calcsize("l") != 8:
        raise UnsupportedNativeError("UNSUPPORTED_ABI")


def _errno_code(native_errno: int, *, context: bool = False) -> str:
    import errno

    if native_errno in (errno.EACCES, errno.EPERM):
        return "PERMISSION_DENIED"
    if native_errno == errno.ENOENT:
        return "MISSING" if not context else "CONTEXT_UNBOUND"
    if native_errno == errno.ELOOP:
        return "SYMLINK_REJECTED"
    if native_errno == errno.EXDEV:
        return "CROSS_MOUNT_REJECTED"
    if native_errno == errno.EAGAIN:
        return "CONTEXT_UNBOUND"
    if native_errno in (errno.ENOSYS, errno.EINVAL, errno.E2BIG):
        return "UNSUPPORTED_ABI"
    return "CONTEXT_UNBOUND" if context else "READ_ERROR"


class LinuxCgroupNative:
    """Fixed Linux ABI wrapper with no path-selection or collector policy."""

    def __init__(self) -> None:
        _require_supported_host()
        _validate_layouts()
        try:
            libc = ctypes.CDLL(None, use_errno=True)
        except OSError:
            raise UnsupportedNativeError("UNSUPPORTED_ABI") from None
        syscall = getattr(libc, "syscall", None)
        fstatfs = getattr(libc, "fstatfs", None)
        if syscall is None or fstatfs is None or not hasattr(os, "pidfd_open"):
            raise UnsupportedNativeError("UNSUPPORTED_ABI")
        syscall.restype = ctypes.c_long
        syscall.argtypes = [ctypes.c_long]
        fstatfs.restype = ctypes.c_int
        fstatfs.argtypes = [ctypes.c_int, ctypes.POINTER(_Statfs)]
        self._libc = libc
        self._syscall = syscall
        self._fstatfs = fstatfs

    @staticmethod
    def validate_statx_mask(mask: int) -> None:
        if type(mask) is not int or mask < 0:
            raise TypeError("mask must be a nonnegative int")
        if (mask & STATX_REQUIRED) != STATX_REQUIRED:
            raise NativeFailure("UNSUPPORTED_ABI")

    def _syscall_error(self, *, context: bool = False) -> NativeFailure:
        native_errno = ctypes.get_errno()
        return NativeFailure(_errno_code(native_errno, context=context), native_errno)

    def open_relative(
        self,
        dir_fd: int,
        path: str | bytes,
        *,
        flags: int,
        mode: int = 0,
        context: bool = True,
    ) -> OwnedFD:
        """Open beneath an existing descriptor with NO_XDEV always enabled."""
        return self._openat2(
            dir_fd,
            path,
            flags=flags,
            mode=mode,
            resolve=RESOLVE_DESCENDANT,
            context=context,
        )

    def open_anchor(
        self,
        root_anchor: RootAnchor,
        path: str | bytes,
        *,
        flags: int,
        expected_magic: int,
        expected_mount_id: int | None = None,
    ) -> OwnedFD:
        """Open only from the verified root, allowing the initial mount crossing."""
        if not isinstance(root_anchor, RootAnchor):
            raise TypeError("root_anchor must be RootAnchor")
        if root_anchor.closed:
            raise NativeFailure("FD_CLOSED")
        current = self.fd_identity(
            root_anchor.fd,
            expected_magic=root_anchor.identity.filesystem_magic,
            expected_mount_id=root_anchor.identity.mount_id,
            expected_type=stat.S_IFDIR,
        )
        if current != root_anchor.identity:
            raise NativeFailure("CONTEXT_UNBOUND")
        owned = self._openat2(
            root_anchor.fd,
            path,
            flags=flags,
            resolve=RESOLVE_ANCHOR,
            context=True,
        )
        try:
            identity = self.fd_identity(
                owned.fd,
                expected_magic=expected_magic,
                expected_mount_id=expected_mount_id,
                expected_type=stat.S_IFDIR,
            )
            owned._identity = identity
            return owned
        except BaseException:
            owned.close()
            raise

    def _openat2(
        self,
        dir_fd: int,
        path: str | bytes,
        *,
        flags: int,
        mode: int = 0,
        resolve: int,
        context: bool,
    ) -> OwnedFD:
        if type(dir_fd) is not int or (dir_fd < 0 and dir_fd != AT_FDCWD):
            raise ValueError("invalid dir_fd")
        if type(context) is not bool:
            raise TypeError("context must be bool")
        if resolve not in (RESOLVE_DESCENDANT, RESOLVE_ANCHOR):
            raise ValueError("unsupported internal resolve policy")
        if isinstance(path, str):
            try:
                path_bytes = path.encode("utf-8")
            except UnicodeEncodeError as error:
                raise ValueError("invalid path encoding") from error
        elif isinstance(path, bytes):
            path_bytes = path
        else:
            raise TypeError("path must be str or bytes")
        if not path_bytes or b"\x00" in path_bytes:
            raise ValueError("invalid relative path")
        if type(flags) is not int or flags < 0 or flags & ~_ALLOWED_OPEN_FLAGS:
            raise ValueError("unsupported open flags")
        if type(mode) is not int or mode != 0:
            raise ValueError("mode must be zero")
        how = _OpenHow(flags=flags, mode=mode, resolve=resolve)
        ctypes.set_errno(0)
        result = self._syscall(
            ctypes.c_long(SYSCALL_OPENAT2_X86_64),
            ctypes.c_int(dir_fd),
            ctypes.c_char_p(path_bytes),
            ctypes.byref(how),
            ctypes.c_size_t(ctypes.sizeof(_OpenHow)),
        )
        if result == -1:
            raise self._syscall_error(context=context)
        return OwnedFD(int(result))

    def open_root_anchor(self) -> RootAnchor:
        """Acquire and verify the fixed root that alone may cross a mount."""
        _require_supported_host()
        try:
            fd = os.open("/", O_PATH | O_DIRECTORY | O_CLOEXEC)
        except OSError as error:
            native_errno = error.errno
            raise NativeFailure(_errno_code(native_errno, context=True), native_errno) from None
        owned = OwnedFD(fd)
        try:
            identity = self.fd_identity(
                owned.fd,
                expected_magic=self.filesystem_magic(owned.fd),
                expected_type=stat.S_IFDIR,
            )
        except BaseException:
            owned.close()
            raise
        return RootAnchor(owned, identity, anchor_guard=_ROOT_ANCHOR_TOKEN)

    def statx_fd(self, fd: int) -> StatxInfo:
        if type(fd) is not int or fd < 0:
            raise ValueError("invalid fd")
        result = _Statx()
        ctypes.set_errno(0)
        status = self._syscall(
            ctypes.c_long(SYSCALL_STATX_X86_64),
            ctypes.c_int(fd),
            ctypes.c_char_p(b""),
            ctypes.c_int(AT_EMPTY_PATH),
            ctypes.c_uint(STATX_REQUIRED_MASK),
            ctypes.byref(result),
        )
        if status == -1:
            raise self._syscall_error(context=True)
        self.validate_statx_mask(int(result.mask))
        return StatxInfo(
            mask=int(result.mask),
            mode=int(result.mode),
            inode=int(result.ino),
            dev_major=int(result.dev_major),
            dev_minor=int(result.dev_minor),
            mount_id=int(result.mnt_id),
        )

    def filesystem_magic(self, fd: int) -> int:
        if type(fd) is not int or fd < 0:
            raise ValueError("invalid fd")
        result = _Statfs()
        ctypes.set_errno(0)
        if self._fstatfs(fd, ctypes.byref(result)) == -1:
            native_errno = ctypes.get_errno()
            raise NativeFailure(_errno_code(native_errno, context=True), native_errno)
        return int(result.f_type) & U64_MAX

    def fd_identity(
        self,
        fd: int,
        *,
        expected_magic: int,
        expected_mount_id: int | None = None,
        expected_type: int | None = None,
        context: bool = True,
    ) -> FdIdentity:
        if type(fd) is not int or fd < 0:
            raise ValueError("invalid fd")
        try:
            info = os.fstat(fd)
        except OSError as error:
            native_errno = error.errno
            raise NativeFailure(_errno_code(native_errno, context=True), native_errno) from None
        magic = self.filesystem_magic(fd)
        native_statx = self.statx_fd(fd)
        if magic != expected_magic:
            raise NativeFailure("FILESYSTEM_MISMATCH")
        if expected_mount_id is not None and native_statx.mount_id != expected_mount_id:
            raise NativeFailure("MOUNT_CHANGED")
        if expected_type is not None and stat.S_IFMT(info.st_mode) != expected_type:
            raise NativeFailure("CONTEXT_UNBOUND" if context else "READ_ERROR")
        if os.major(info.st_dev) != native_statx.dev_major or os.minor(info.st_dev) != native_statx.dev_minor:
            raise NativeFailure("CONTEXT_UNBOUND")
        if info.st_ino != native_statx.inode:
            raise NativeFailure("CONTEXT_UNBOUND")
        return FdIdentity(magic, info.st_dev, info.st_ino, info.st_mode, native_statx.mount_id)

    def open_proc_self(self, procfs_fd: int, *, procfs_mount_id: int) -> OwnedFD:
        if type(procfs_fd) is not int or procfs_fd < 0:
            raise ValueError("invalid procfs fd")
        try:
            fd = os.open("self", O_PATH | O_DIRECTORY | O_CLOEXEC, dir_fd=procfs_fd)
        except OSError as error:
            native_errno = error.errno
            raise NativeFailure(_errno_code(native_errno, context=True), native_errno) from None
        owned = OwnedFD(fd)
        try:
            self.fd_identity(
                owned.fd,
                expected_magic=PROC_SUPER_MAGIC,
                expected_mount_id=procfs_mount_id,
                expected_type=stat.S_IFDIR,
            )
        except BaseException:
            owned.close()
            raise
        return owned

    def open_namespace_fd(self, namespace_dir_fd: int, name: str) -> tuple[OwnedFD, FdIdentity]:
        namespace_types = {"pid": CLONE_NEWPID, "mnt": CLONE_NEWNS, "cgroup": CLONE_NEWCGROUP}
        if name not in namespace_types:
            raise ValueError("unsupported namespace entry")
        if type(namespace_dir_fd) is not int or namespace_dir_fd < 0:
            raise ValueError("invalid namespace directory fd")
        try:
            fd = os.open(name, O_CLOEXEC, dir_fd=namespace_dir_fd)
        except OSError as error:
            native_errno = error.errno
            raise NativeFailure(_errno_code(native_errno, context=True), native_errno) from None
        owned = OwnedFD(fd)
        try:
            identity = self.fd_identity(owned.fd, expected_magic=NSFS_MAGIC)
            try:
                import fcntl
            except ImportError:
                raise UnsupportedNativeError("UNSUPPORTED_ABI") from None

            try:
                namespace_type = fcntl.ioctl(owned.fd, NS_GET_NSTYPE)
            except OSError as error:
                native_errno = error.errno
                raise NativeFailure("CONTEXT_UNBOUND", native_errno) from None
            if namespace_type != namespace_types[name]:
                raise NativeFailure("NAMESPACE_MISMATCH")
        except BaseException:
            owned.close()
            raise
        return owned, identity

    def open_pidfd(self, pid: int) -> OwnedFD:
        if type(pid) is not int:
            raise TypeError("pid must be int")
        if pid <= 0 or pid > 2_147_483_647:
            raise ValueError("invalid pid")
        try:
            return OwnedFD(os.pidfd_open(pid, 0))
        except OSError as error:
            native_errno = error.errno
            raise NativeFailure(_errno_code(native_errno, context=True), native_errno) from None

    @staticmethod
    def pidfd_alive(fd: int) -> bool:
        if type(fd) is not int or fd < 0:
            raise ValueError("invalid fd")
        required_names = ("POLLIN", "POLLHUP", "POLLERR", "POLLNVAL")
        if not hasattr(select, "poll") or any(not hasattr(select, name) for name in required_names):
            raise UnsupportedNativeError("UNSUPPORTED_ABI")
        invalid_events = sum(getattr(select, name) for name in required_names)
        try:
            poller = select.poll()
            poller.register(fd, invalid_events)
            return not bool(poller.poll(0))
        except OSError as error:
            native_errno = error.errno
            raise NativeFailure(_errno_code(native_errno, context=True), native_errno) from None

    @staticmethod
    def read_bounded(
        fd: int,
        *,
        source_kind: str,
        budget: ReadBudget,
        reader: Callable[[int, int], bytes] = os.read,
        clock: Callable[[], float] = time.monotonic,
    ) -> ReadObservation:
        if type(fd) is not int or fd < 0:
            raise ValueError("invalid fd")
        file_limits = {"RESOURCE": RESOURCE_READ_LIMIT, "PROCFS": PROCFS_READ_LIMIT}
        if not isinstance(source_kind, str):
            raise TypeError("source_kind must be str")
        if source_kind not in file_limits:
            raise ValueError("unsupported source kind")
        if not isinstance(budget, ReadBudget):
            raise TypeError("budget must be ReadBudget")
        file_limit = file_limits[source_kind]
        chunks: list[bytes] = []
        count = 0
        while True:
            admission = budget.admission_state()
            if admission is None and clock() >= budget.deadline:
                admission = "DEADLINE_REACHED"
            if admission:
                return ReadObservation(admission, str(count), None, admission, None)
            remaining_file = file_limit - count
            if remaining_file <= 0:
                return ReadObservation("LIMIT_REACHED", str(count), None, "LIMIT_REACHED", None)
            amount = min(remaining_file, budget.remaining_bytes)
            if amount <= 0:
                return ReadObservation("LIMIT_REACHED", str(count), None, "LIMIT_REACHED", None)
            if clock() >= budget.deadline:
                return ReadObservation("DEADLINE_REACHED", str(count), None, "DEADLINE_REACHED", None)
            try:
                chunk = reader(fd, amount)
            except OSError as error:
                native_errno = error.errno
                reason_code = (
                    _errno_code(native_errno, context=source_kind == "PROCFS")
                    if native_errno is not None
                    else "READ_ERROR"
                )
                return ReadObservation(
                    reason_code,
                    str(count),
                    None,
                    reason_code,
                    str(native_errno) if native_errno is not None else None,
                )
            if not isinstance(chunk, bytes) or len(chunk) > amount:
                return ReadObservation("READ_ERROR", str(count), None, "READ_ERROR", None)
            if not chunk:
                return ReadObservation("AVAILABLE", str(count), b"".join(chunks), None, None)
            budget.account(len(chunk))
            count += len(chunk)
            chunks.append(chunk)
            if count == file_limit or budget.remaining_bytes == 0:
                return ReadObservation("LIMIT_REACHED", str(count), None, "LIMIT_REACHED", None)


def native_backend() -> LinuxCgroupNative:
    """Construct a backend only after host, Python, and structure checks."""
    return LinuxCgroupNative()


def live_probe() -> tuple[str, ...]:
    """Exercise required syscalls and namespace primitives without output data."""
    backend = native_backend()
    with backend.open_relative(AT_FDCWD, b".", flags=O_PATH | O_DIRECTORY | O_CLOEXEC) as cwd_fd:
        backend.fd_identity(cwd_fd.fd, expected_magic=backend.filesystem_magic(cwd_fd.fd))
    with backend.open_root_anchor() as root_anchor:
        with backend.open_anchor(
            root_anchor,
            b"proc",
            flags=O_PATH | O_DIRECTORY | O_CLOEXEC,
            expected_magic=PROC_SUPER_MAGIC,
        ) as proc_fd:
            proc_info = proc_fd.identity
            if proc_info is None:
                raise UnsupportedNativeError("CONTEXT_UNBOUND")
            with backend.open_proc_self(proc_fd.fd, procfs_mount_id=proc_info.mount_id) as caller_fd:
                with backend.open_relative(caller_fd.fd, b"ns", flags=O_PATH | O_DIRECTORY | O_CLOEXEC) as ns_dir:
                    for namespace in ("pid", "mnt", "cgroup"):
                        namespace_fd, _identity = backend.open_namespace_fd(ns_dir.fd, namespace)
                        namespace_fd.close()
                with backend.open_pidfd(os.getpid()) as pidfd:
                    if not backend.pidfd_alive(pidfd.fd):
                        raise UnsupportedNativeError("PID_EXITED")
    return ("ABI_LAYOUT", "OPENAT2", "STATX", "FSTATFS", "NAMESPACE_FD", "PIDFD")
