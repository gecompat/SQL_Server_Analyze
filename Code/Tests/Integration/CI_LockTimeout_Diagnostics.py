#!/usr/bin/env python3
"""Bounded lock observation for synthetic SQL Server 2025 CI sessions only."""

from __future__ import annotations

import argparse
import codecs
from collections import deque
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import queue
import re
import subprocess
import threading
import time

INTERVAL = 0.250
WINDOW = 10.0
MAX_SECONDS = 600
MAX_ROWS = 200
MAX_BYTES = 50 * 1024 * 1024
REPORT_BYTES = 5 * 1024 * 1024
LOG_BYTES = 44 * 1024 * 1024
MARKER = re.compile(
    r"CI_(BEGIN|CASE|AFTER|END)\|(20[2-7])\|([A-Za-z0-9_]+)\|(\d+)\|"
    r"([\dT:.Z-]+)\|(\d+)\|(-?\d+)\|([^|\r\n]{0,180})$"
)
RESOURCE_FIELDS = (
    "resource_type", "resource_subtype", "resource_database_id",
    "resource_description", "resource_associated_entity_id", "resource_lock_partition",
)


def marker(line):
    match = MARKER.fullmatch(line.strip())
    if not match:
        return None
    kind, suite, site, ordinal, utc, spid, timeout, variant = match.groups()
    return dict(kind=kind, suite=suite, test_file=TEST_FILES.get(suite), site=site, ordinal=int(ordinal), utc=utc,
                spid=int(spid), lock_timeout=int(timeout), variant=variant)


def resource_key(row):
    return tuple(row.get(field) for field in RESOURCE_FIELDS)


def utc_key(value):
    """Compare SQL UTC timestamps without losing their seventh fractional digit."""
    parts = re.fullmatch(r"(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(?:\.(\d{1,7}))?Z", value)
    if not parts:
        raise ValueError("Invalid server UTC timestamp")
    datetime.fromisoformat(value)
    return parts[1]+"."+(parts[2] or "").ljust(7, "0")+"Z"


def case_samples(samples, case, now):
    """Bind delayed markers to the same session's samples after that phase began."""
    if not case:
        return []
    start = utc_key(case["utc"])
    return [dict(sample, case=case, sampled_case=sample["case"])
            for sample in samples
            if now-sample["clock"] <= WINDOW and sample["case"]["spid"] == case["spid"]
            and utc_key(sample["server_utc"]) > start]


def observed_blocker(samples, case):
    """A sampled request establishes the direct blocker; lock identity stays complete."""
    for sample in reversed(samples):
        if sample["case"] != case:
            continue
        for row in sample["rows"]:
            if row.get("kind") == "request" and row.get("session_id") == case["spid"]:
                if row.get("blocking_session_id", 0) > 0 and str(row.get("wait_type", "")).startswith("LCK_"):
                    return True
    return False


def sample_sql(spid):
    spid = int(spid)
    if not 1 <= spid <= 32767:
        raise ValueError("Invalid test session")
    # Each JSON row stays below SQLCMD's line width. No SQL text or identity columns.
    return f"""SET NOCOUNT ON; SET LOCK_TIMEOUT 250; SET DEADLOCK_PRIORITY LOW;
DECLARE @sid int={spid};
SELECT N'CI_SAMPLE_UTC|'+CONVERT(varchar(27),SYSUTCDATETIME(),126)+N'Z';
;WITH ScopeSessions AS (
 SELECT @sid AS session_id UNION
 SELECT blocking_session_id FROM sys.dm_exec_requests
 WHERE session_id=@sid AND blocking_session_id>0
), SampleRows AS (
 SELECT 0 AS priority, (SELECT N'request' AS kind,r.session_id,r.request_id,
 r.blocking_session_id,r.wait_type,r.wait_time,r.wait_resource,r.lock_timeout
 FOR JSON PATH,INCLUDE_NULL_VALUES,WITHOUT_ARRAY_WRAPPER) AS payload
 FROM sys.dm_exec_requests r WHERE r.session_id IN(SELECT session_id FROM ScopeSessions)
 UNION ALL
 SELECT 1,(SELECT N'lock' AS kind,l.resource_type,l.resource_subtype,
 l.resource_database_id,l.resource_description,l.resource_associated_entity_id,
 l.resource_lock_partition,l.request_mode,l.request_status,l.request_session_id,
 l.request_exec_context_id,l.request_request_id,l.request_owner_type,l.request_owner_id,
 CONVERT(varchar(18),l.lock_owner_address,1) AS lock_owner_address
 FOR JSON PATH,INCLUDE_NULL_VALUES,WITHOUT_ARRAY_WRAPPER)
 FROM sys.dm_tran_locks l WHERE l.request_session_id IN(SELECT session_id FROM ScopeSessions)
)
SELECT TOP ({MAX_ROWS + 1}) N'CI_ROW|'+payload FROM SampleRows ORDER BY priority;
RAISERROR(N'CI_SAMPLE_END',10,1) WITH NOWAIT;
GO
"""


TEST_FILES = {p.name[:3]: "Code/Tests/Integration/"+p.name
              for p in Path(__file__).parent.glob("20[2-7]*.sql")}


class Sqlcmd:
    """One persistent connection, including while its server session is sleeping."""

    def __init__(self, container, sqlcmd):
        self.base = ["docker", "exec", "-i", "--env", "SQLCMDPASSWORD",
                     "--workdir", "/work/Code/Tests", container, sqlcmd,
                     "-S", "localhost", "-U", "sa", "-C", "-b", "-h", "-1",
                     "-y", "4096", "-w", "65535", "-t", "2", "-q", "SET NOCOUNT ON;"]
        self.env = dict(os.environ, SQLCMDPASSWORD=os.environ["MSSQL_EPHEMERAL_CREDENTIAL"])
        self.process = subprocess.Popen(self.base, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                        stderr=subprocess.STDOUT, env=self.env, text=True,
                                        encoding="utf-8", errors="replace", bufsize=1)
        self.lines = queue.Queue(maxsize=256)
        self.reader = threading.Thread(target=self._read, daemon=True)
        self.reader.start()

    def _read(self):
        for line in self.process.stdout:
            self.lines.put(line)
        self.lines.put(None)

    def query(self, sql, end="CI_SAMPLE_END", timeout=3):
        self.process.stdin.write(sql)
        self.process.stdin.flush()
        result = []
        deadline = time.monotonic() + timeout
        while True:
            try:
                line = self.lines.get(timeout=max(0.001, deadline - time.monotonic()))
            except queue.Empty as error:
                detail = redact(" | ".join(result[-3:]), self.env["SQLCMDPASSWORD"])[:1024]
                raise TimeoutError("Observer query deadline exceeded: "+detail) from error
            if line is None:
                raise RuntimeError("Observer connection ended: "+redact(" | ".join(result[-3:]), self.env["SQLCMDPASSWORD"])[:1024])
            # Interactive SQLCMD can prefix the next output line with several prompts.
            # Read batches from the live command stream, never through /dev/stdin as a file.
            line = re.sub(r"^(?:\d+>\s*)+", "", line.strip())
            if line == end:
                return result
            if line:
                result.append(line)
            if time.monotonic() >= deadline:
                raise TimeoutError("Observer query deadline exceeded")

    def close(self):
        try:
            if self.process.poll() is None:
                self.process.stdin.write(":QUIT\n")
                self.process.stdin.flush()
            self.process.stdin.close()
            self.process.wait(timeout=2)
        except (OSError, subprocess.TimeoutExpired):
            self.process.kill()
            self.process.wait(timeout=2)
            return False
        finally:
            self.reader.join(timeout=2)
            self.process.stdout.close()
        return self.process.returncode == 0 and not self.reader.is_alive()


class Observation:
    def __init__(self, factory):
        self.factory = factory
        self.case = None
        self.samples = deque(maxlen=40)
        self.frozen = None
        self.errors = []
        self.details = []
        self.stop = threading.Event()
        self.thread = threading.Thread(target=self._observe, daemon=True)
        self.lock = threading.Lock()
        self.started = None

    def feed(self, line):
        item = marker(line)
        with self.lock:
            if item:
                self.case = None if item["kind"] == "END" else item
                if self.started is None and item["kind"] != "END":
                    self.started = time.monotonic()
                    self.thread.start()
            if re.match(r"^Msg 1222, Level \d+, State \d+", line) and self.frozen is None:
                now = time.monotonic()
                try:
                    samples = case_samples(self.samples, self.case, now)
                except ValueError:
                    samples = []
                    self.errors.append("INVALID_SERVER_TIME")
                self.frozen = {"case": self.case, "samples": samples}

    def _observe(self):
        connection = None
        try:
            connection = self.factory()
            while not self.stop.is_set():
                tick = time.monotonic()
                if tick - self.started >= MAX_SECONDS:
                    self.errors.append("OBSERVATION_TIME_LIMIT")
                    break
                with self.lock:
                    case = self.case
                if case:
                    lines = connection.query(sample_sql(case["spid"]))
                    if not lines or not lines[0].startswith("CI_SAMPLE_UTC|"):
                        raise RuntimeError("Missing observer server UTC")
                    server_utc = utc_key(lines[0].split("|", 1)[1])
                    if any(not line.startswith("CI_ROW|") for line in lines[1:]):
                        raise RuntimeError("Unexpected observer output")
                    rows = [json.loads(line[7:]) for line in lines[1:]]
                    sample = dict(clock=time.monotonic(), utc=datetime.now(timezone.utc).isoformat(),
                                  server_utc=server_utc, case=case, rows=rows[:MAX_ROWS],
                                  truncated=len(rows) > MAX_ROWS)
                    with self.lock:
                        self.samples.append(sample)
                self.stop.wait(max(0, INTERVAL-(time.monotonic()-tick)))
        except (OSError, ValueError, RuntimeError, TimeoutError, queue.Empty) as error:
            self.errors.append("OBSERVATION_FAILED")
            self.details.append(str(error)[:1024])
        finally:
            if connection and not connection.close():
                self.errors.append("OBSERVER_CLEANUP_FAILED")

    def finish(self):
        self.stop.set()
        if self.started is not None:
            self.thread.join(timeout=8)
            if self.thread.is_alive():
                self.errors.append("OBSERVER_CLEANUP_DEADLINE")
        with self.lock:
            if self.frozen is None:
                return {"status": "NO_1222", "errors": list(self.errors), "details": list(self.details)}
            case = self.frozen["case"]
            samples = self.frozen["samples"]
            found = bool(case and observed_blocker(samples, case))
            return dict(status="BLOCKER_OBSERVED" if found else "BLOCKER_NOT_CAPTURED",
                        case=case, samples=samples, errors=list(self.errors), details=list(self.details),
                        truncated=any(s["truncated"] for s in samples))


def redact(text, secret):
    return text.replace(secret, "[REDACTED]") if secret else text


class LogWriter:
    """Redact before the size cap, including credentials crossing read boundaries."""

    def __init__(self, output, secret, limit=LOG_BYTES):
        self.output, self.secret, self.limit = output, secret, limit
        self.tails, self.size, self.incomplete = {}, 0, False

    def write(self, text, final=False, stream="stdout"):
        value = self.tails.get(stream, "") + text
        end = len(value) if final else max(0, len(value)-len(self.secret)+1)
        if self.secret and not final:
            start = value.rfind(self.secret, max(0, end-len(self.secret)+1))
            if start >= 0 and start < end < start+len(self.secret):
                end = start
        self.tails[stream] = value[end:]
        data = redact(value[:end], self.secret).encode("utf-8")
        if self.size+len(data) <= self.limit:
            self.output.write(data)
            self.size += len(data)
        else:
            self.incomplete = True


def encode_report(report, secret, limit=REPORT_BYTES):
    payload = redact(json.dumps(report, ensure_ascii=True, indent=2), secret).encode()
    if len(payload) > limit:
        report["truncated"] = True
        report["errors"].append("ARTIFACT_SIZE_LIMIT")
        while report.get("samples") and len(payload) > limit:
            report["samples"].pop(0)
            if report.get("case") and not observed_blocker(report["samples"], report["case"]):
                report["status"] = "BLOCKER_NOT_CAPTURED"
            payload = redact(json.dumps(report, ensure_ascii=True, indent=2), secret).encode()
        if len(payload) > limit:
            payload = json.dumps(dict(status="ARTIFACT_SIZE_LIMIT", sqlcmd_exit_code=report["sqlcmd_exit_code"])).encode()
    return payload


def run(args):
    """Keep the original test return code even if collection or publication fails."""
    ephemeral_value = os.environ["MSSQL_EPHEMERAL_CREDENTIAL"]
    observer = Observation(lambda: Sqlcmd(args.container, args.sqlcmd))
    log = Path(args.log)
    log.parent.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, SQLCMDPASSWORD=ephemeral_value)
    command = ["docker", "exec", "--env", "SQLCMDPASSWORD", "--workdir", "/work/Code/Tests",
               args.container, "stdbuf", "-o0", "-e0", args.sqlcmd,
               "-S", "localhost", "-U", "sa", "-C", "-b", "-r", "1"]
    # A completed BEGIN batch makes SQLCMD deliver the session marker before
    # executing the test batch. CASE messages may still arrive after the wait;
    # the observer's server timestamps retain their phase association.
    query = getattr(args, "query", None)
    if query:
        command.insert(2, "-i")
        command += ["-q", "SET NOCOUNT ON;"]
    else:
        command += ["-i", args.input]
    with log.open("wb") as output:
        writer = LogWriter(output, ephemeral_value, getattr(args, "log_limit", LOG_BYTES))
        process = subprocess.Popen(command, stdin=subprocess.PIPE if query else None,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env)
        input_errors = []
        if query:
            try:
                process.stdin.write((query+"\nGO\n:QUIT\n").encode("utf-8"))
                process.stdin.close()
            except OSError:
                input_errors.append("INPUT_WRITE_FAILED")
        chunks = queue.Queue(maxsize=32)
        def read_stream(name, pipe):
            try:
                for chunk in iter(lambda: pipe.read1(8192), b""):
                    chunks.put((name, chunk))
            except OSError:
                chunks.put((name, "OUTPUT_READ_FAILED"))
            finally:
                pipe.close()
                chunks.put((name, None))
        readers = [threading.Thread(target=read_stream, args=(name, pipe), daemon=True)
                   for name, pipe in (("stdout", process.stdout), ("stderr", process.stderr))]
        for reader in readers:
            reader.start()
        # Result rows never enter the marker parser. Each stream retains its own
        # decoder and secret tail, while the shared log size cap covers both.
        pending = b""
        decoders = {name: codecs.getincrementaldecoder("utf-8")(errors="replace")
                    for name in ("stdout", "stderr")}
        read_errors = input_errors
        ended = set()
        while len(ended) < 2:
            name, chunk = chunks.get()
            if chunk is None:
                ended.add(name)
                writer.write(decoders[name].decode(b"", final=True), final=True, stream=name)
                if name == "stderr" and pending:
                    observer.feed(pending.decode("utf-8", errors="replace"))
                continue
            if isinstance(chunk, str):
                read_errors.append(chunk)
                continue
            writer.write(decoders[name].decode(chunk), stream=name)
            if name == "stderr":
                pending += chunk
                while b"\n" in pending or len(pending) >= 16384:
                    end = pending.find(b"\n") + 1
                    if end == 0:
                        end = 8192
                    part, pending = pending[:end], pending[end:]
                    observer.feed(part.decode("utf-8", errors="replace"))
        for reader in readers:
            reader.join(timeout=2)
        code = process.wait()
    report = observer.finish()
    report["errors"].extend(read_errors)
    report.update(sqlcmd_exit_code=code, log_incomplete=writer.incomplete,
                  commit=os.environ.get("GITHUB_SHA"), run_id=os.environ.get("GITHUB_RUN_ID"),
                  attempt=os.environ.get("GITHUB_RUN_ATTEMPT"))
    if code or report["errors"] or writer.incomplete:
        try:
            destination = Path(args.artifacts)
            destination.mkdir(parents=True, exist_ok=True)
            payload = encode_report(report, ephemeral_value, getattr(args, "report_limit", REPORT_BYTES))
            (destination / "diagnostics.json").write_bytes(payload)
            # Move the sanitized log; never upload the unbounded runner directory.
            log.replace(destination / "impact.log")
        except OSError:
            print(f"CI lock diagnostics publication failed; sqlcmd exit={code}")
            return code or 1
        print(f"CI lock diagnostics: {report['status']}; sqlcmd exit={code}; "
              f"observer errors={len(report['errors'])}; incomplete={writer.incomplete}")
    return code if code else (1 if report["errors"] or writer.incomplete else 0)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--container", default="sqlserver-analyze-impact-2025")
    parser.add_argument("--sqlcmd", required=True)
    parser.add_argument("--input", default="Run_Impact_Gate.sql")
    parser.add_argument("--log", required=True)
    parser.add_argument("--artifacts", required=True)
    return run(parser.parse_args())


if __name__ == "__main__":
    raise SystemExit(main())
