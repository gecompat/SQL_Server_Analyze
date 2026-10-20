#!/usr/bin/env python3
"""Offline contracts and one bounded synthetic SQL lock qualification batch."""

import argparse
import io
import json
import os
from pathlib import Path
import re
import subprocess
import queue
import sys
import tempfile
import time
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import CI_LockTimeout_Diagnostics as ci

CASE = "CI_CASE|202|Probe|1|2000-01-01T00:00:00Z|51|2000|synthetic"


class Contracts(unittest.TestCase):
    def test_markers_and_callsite_coverage(self):
        root = Path(__file__).resolve().parent
        for path in sorted(root.glob("20[2-7]*.sql")):
            source = path.read_text(encoding="utf-8-sig")
            calls = re.findall(r"EXEC \[monitor\]\.\[USP_SsisLegacyLogAnalysis\]", source)
            sites = re.findall(r"CI_CASE\|"+path.name[:3]+r"\|(C\d{3})\|", source)
            self.assertEqual(len(calls), len(sites), path.name)
            self.assertEqual(len(sites), len(set(sites)), path.name)
            self.assertIn("CI_BEGIN|"+path.name[:3], source)
            self.assertIn("CI_END|"+path.name[:3], source)
            self.assertIn("@CiOrdinal+=1", source)
            self.assertEqual(source.count("N''CI_AFTER|"+path.name[:3]), len(calls))
            self.assertRegex(source, r"RAISERROR\(N'%s',10,1,@CiFileMarker\) WITH NOWAIT;\s+GO")
            self.assertNotIn("REPLACE(@CiMarker", source)
            if path.name.startswith("202"):
                self.assertRegex(source, r"INSERT \[#ExampleSsisLegacy_Console\]\s+EXEC \[monitor\]\.\[USP_SsisLegacyLogAnalysis\]")
        a, b = ci.marker(CASE), ci.marker(CASE.replace("|1|", "|2|"))
        self.assertNotEqual(a, b)
        self.assertEqual(a["lock_timeout"], 2000)
        self.assertIsNone(ci.marker('unrelated '+CASE))

    def test_complete_resource_identity(self):
        base = dict(zip(ci.RESOURCE_FIELDS, ("KEY", "", 5, "(example)", 42, 0)))
        for field in ci.RESOURCE_FIELDS:
            changed = dict(base, **{field: "different"})
            self.assertNotEqual(ci.resource_key(base), ci.resource_key(changed))
        self.assertIn("l.request_owner_type", ci.sample_sql(51))
        self.assertIn("l.resource_lock_partition", ci.sample_sql(51))
        self.assertNotIn("sql_text", ci.sample_sql(51))
        self.assertRaises(ValueError, ci.sample_sql, 0)

    def test_unknown_is_not_no_blocker_and_scopes_do_not_mix(self):
        case = ci.marker(CASE)
        observed = dict(kind="request", session_id=51, blocking_session_id=52, wait_type="LCK_M_S")
        sample = dict(case=case, rows=[observed])
        self.assertTrue(ci.observed_blocker([sample], case))
        self.assertFalse(ci.observed_blocker([sample], dict(case, ordinal=2)))
        self.assertFalse(ci.observed_blocker([dict(case=case, rows=[dict(observed, blocking_session_id=-5)])], case))
        observer = ci.Observation(lambda: None)
        observer.feed("Msg 1222, Level 16, State 1")
        self.assertEqual(observer.finish()["status"], "BLOCKER_NOT_CAPTURED")

    def test_stream_redaction_and_size_cap(self):
        synthetic_canary = "SyntheticCredential123!"
        for split in range(len(synthetic_canary)+1):
            output = io.BytesIO()
            writer = ci.LogWriter(output, synthetic_canary)
            writer.write("prefix "+synthetic_canary[:split])
            writer.write(synthetic_canary[split:]+" suffix")
            writer.write("", final=True)
            self.assertEqual(output.getvalue(), b"prefix [REDACTED] suffix")
        output = io.BytesIO()
        writer = ci.LogWriter(output, synthetic_canary, limit=3)
        writer.write("abcdef", final=True)
        self.assertTrue(writer.incomplete)
        self.assertLessEqual(len(output.getvalue()), 3)
        output = io.BytesIO()
        writer = ci.LogWriter(output, synthetic_canary)
        writer.write(synthetic_canary[:10], stream="stdout")
        writer.write("unrelated stderr\n", final=True, stream="stderr")
        writer.write(synthetic_canary[10:], final=True, stream="stdout")
        self.assertEqual(output.getvalue(), b"unrelated stderr\n[REDACTED]")

    def test_sqlcmd_protocol_failure_keeps_primary_error(self):
        connection = object.__new__(ci.Sqlcmd)
        connection.process = SimpleNamespace(stdin=io.StringIO())
        connection.env = {"SQLCMDPASSWORD": "SyntheticCredential"}
        connection.lines = queue.Queue()
        connection.lines.put("Sqlcmd: invalid option SyntheticCredential")
        connection.lines.put(None)
        with self.assertRaisesRegex(RuntimeError, r"invalid option \[REDACTED\]"):
            connection.query("synthetic")
        with patch.dict(os.environ, MSSQL_EPHEMERAL_CREDENTIAL="SyntheticCredential"), \
             patch.object(ci.subprocess, "Popen") as launch, \
             patch.object(ci.threading.Thread, "start"):
            ci.Sqlcmd("synthetic", "synthetic")
            command = launch.call_args.args[0]
            self.assertEqual(command[command.index("-y")+1], "4096")
            self.assertEqual(command[command.index("-h")+1], "-1")
            self.assertNotIn("/dev/stdin", command)
            self.assertIn("-q", command)

    def test_protocol_context_redacts_before_limit(self):
        connection = object.__new__(ci.Sqlcmd)
        connection.process = SimpleNamespace(stdin=io.StringIO())
        connection.env = {"SQLCMDPASSWORD": "SyntheticCredential"}
        for eof in (True, False):
            connection.lines = queue.Queue()
            connection.lines.put("x"*1010+"SyntheticCredential")
            if eof:
                connection.lines.put(None)
            try:
                connection.query("synthetic", timeout=0.01)
            except (RuntimeError, TimeoutError) as error:
                self.assertIn("[REDACTED]", str(error))
                self.assertNotIn("Synthetic", str(error))
            else:
                self.fail("Missing protocol failure")

    def test_persistent_sqlcmd_stream_handles_prompts_and_deadline(self):
        child = """import sys
ordinal = 0
for line in sys.stdin:
    if line.strip() == ':QUIT':
        break
    if line.strip() == 'GO':
        ordinal += 1
        print('1> 2> CI_ROW|' + str(ordinal), flush=True)
        print('3> CI_SAMPLE_END', flush=True)
"""
        original_popen = subprocess.Popen
        def launch_child(*args, **kwargs):
            return original_popen([sys.executable, "-u", "-c", child], **kwargs)
        with patch.dict(os.environ, MSSQL_EPHEMERAL_CREDENTIAL="SyntheticCredential"), \
             patch.object(ci.subprocess, "Popen", side_effect=launch_child) as launch:
            connection = ci.Sqlcmd("synthetic", "synthetic")
            try:
                self.assertEqual(connection.query("first batch\nGO\n"), ["CI_ROW|1"])
                self.assertEqual(connection.query("second batch\nGO\n"), ["CI_ROW|2"])
                self.assertEqual(launch.call_count, 1)
                self.assertFalse(connection.process.stdin.closed)
                with self.assertRaisesRegex(TimeoutError, "Observer query deadline exceeded"):
                    connection.query("incomplete batch\n", timeout=0.05)
            finally:
                self.assertTrue(connection.close())

    def test_artifact_cap_preserves_failure_and_case(self):
        case = ci.marker(CASE)
        report = dict(status="BLOCKER_OBSERVED", case=case, sqlcmd_exit_code=7, errors=[],
                      samples=[dict(case=case, rows=[dict(kind="lock", resource_description="x"*4000)]) for _ in range(40)])
        encoded = ci.encode_report(report, "SyntheticCredential", limit=4096)
        self.assertLessEqual(len(encoded), 4096)
        value = json.loads(encoded)
        self.assertEqual(value["sqlcmd_exit_code"], 7)
        self.assertEqual(value["case"], case)
        self.assertIn("ARTIFACT_SIZE_LIMIT", value["errors"])
        self.assertTrue(value["truncated"])
        self.assertLess(ci.LOG_BYTES+ci.REPORT_BYTES+1024*1024, ci.MAX_BYTES+1)

    def test_original_exit_and_observer_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            args = SimpleNamespace(container="synthetic", sqlcmd="synthetic", input="synthetic.sql",
                                   log=str(Path(directory)/"raw.log"), artifacts=str(Path(directory)/"artifacts"))
            process = SimpleNamespace(stdout=io.BytesIO(b"SyntheticCredential\n"),
                                      stderr=io.BytesIO((CASE+"\nMsg 1222, Level 16, State 1\n").encode()), wait=lambda: 7)
            with patch.dict(os.environ, MSSQL_EPHEMERAL_CREDENTIAL="SyntheticCredential"), \
                 patch.object(ci.subprocess, "Popen", return_value=process), \
                 patch.object(ci, "Sqlcmd", side_effect=OSError("synthetic")):
                self.assertEqual(ci.run(args), 7)
            report = json.loads((Path(args.artifacts)/"diagnostics.json").read_text())
            self.assertIn("OBSERVATION_FAILED", report["errors"])
            self.assertEqual(report["sqlcmd_exit_code"], 7)
            self.assertNotIn("SyntheticCredential", (Path(args.artifacts)/"impact.log").read_text())

    def test_live_message_arrives_before_process_exit(self):
        """Exercise pipe handling; this child does not emulate native ODBC timing."""
        child = """import pathlib, sys, time
ready = pathlib.Path(sys.argv[1])
case = sys.argv[2]
sys.stdout.write('x' * 17000)
sys.stdout.flush()
print(case, file=sys.stderr, flush=True)
deadline = time.monotonic() + 3
while not ready.exists() and time.monotonic() < deadline:
    time.sleep(0.01)
time.sleep(0.05)
print('Msg 1222, Level 16, State 1', file=sys.stderr, flush=True)
sys.exit(7)
"""
        original_popen = subprocess.Popen
        with tempfile.TemporaryDirectory() as directory:
            ready = Path(directory)/"sample-ready"
            class Connection:
                def query(self, sql):
                    ready.touch()
                    return ['CI_SAMPLE_UTC|2000-01-01T00:00:01Z', 'CI_ROW|'+json.dumps(dict(kind="request", session_id=51,
                            blocking_session_id=52, wait_type="LCK_M_S"))]
                def close(self):
                    return True
            def launch_child(command, **kwargs):
                self.assertEqual(command[command.index("-r")+1], "1")
                return original_popen([sys.executable, "-c", child, str(ready), CASE], **kwargs)
            args = SimpleNamespace(container="synthetic", sqlcmd="synthetic", input="synthetic.sql",
                                   log=str(Path(directory)/"raw.log"), artifacts=str(Path(directory)/"artifacts"))
            with patch.dict(os.environ, MSSQL_EPHEMERAL_CREDENTIAL="SyntheticCredential"), \
                 patch.object(ci.subprocess, "Popen", side_effect=launch_child), \
                 patch.object(ci, "Sqlcmd", return_value=Connection()):
                self.assertEqual(ci.run(args), 7)
            report = json.loads((Path(args.artifacts)/"diagnostics.json").read_text())
            self.assertEqual(report["status"], "BLOCKER_OBSERVED")
            self.assertTrue(report["samples"])
            self.assertEqual(report["errors"], [])

    def test_delayed_case_uses_server_time_and_keeps_phase_boundaries(self):
        begin = ci.marker(CASE.replace('CI_CASE', 'CI_BEGIN'))
        case = dict(begin, kind='CASE', utc='2000-01-01T00:00:01.0000002Z')
        def sample(utc, spid=51, clock=100):
            return dict(clock=clock, server_utc=utc, case=dict(begin, spid=spid), rows=[])
        samples = [sample('2000-01-01T00:00:01.0000001Z'),
                   sample('2000-01-01T00:00:01.0000002Z'),
                   sample('2000-01-01T00:00:02Z', spid=52),
                   sample('2000-01-01T00:00:02Z', clock=80)]
        bound = ci.case_samples(samples, case, 101)
        self.assertEqual(len(bound), 1)
        self.assertEqual(bound[0]['case'], case)
        self.assertEqual(bound[0]['sampled_case'], begin)
        self.assertEqual(samples[1]['case'], begin)
        self.assertEqual(ci.case_samples(samples, dict(case, kind='AFTER', utc='2000-01-01T00:00:03Z'), 101), [])
        self.assertEqual(ci.case_samples(samples, None, 101), [])
        self.assertRaises(ValueError, ci.utc_key, '2000-01-01T00:00:00+01:00')
        self.assertRaises(ValueError, ci.utc_key, '2000-02-31T00:00:00Z')

    def test_batch_delayed_marker_rebinds_already_collected_sample(self):
        child = """import pathlib, sys, time
ready = pathlib.Path(sys.argv[1])
print(sys.argv[2], file=sys.stderr, flush=True)
deadline = time.monotonic()+3
while not ready.exists() and time.monotonic()<deadline:
    time.sleep(0.01)
time.sleep(0.05)
print(sys.argv[3], file=sys.stderr, flush=True)
print('Msg 1222, Level 16, State 1', file=sys.stderr, flush=True)
sys.exit(7)
"""
        original_popen = subprocess.Popen
        with tempfile.TemporaryDirectory() as directory:
            ready = Path(directory)/'ready'
            class Connection:
                def query(self, sql):
                    ready.touch()
                    return ['CI_SAMPLE_UTC|2000-01-01T00:00:02Z', 'CI_ROW|'+json.dumps(dict(
                        kind='request', session_id=51, blocking_session_id=52, wait_type='LCK_M_S'))]
                def close(self):
                    return True
            def launch(command, **kwargs):
                return original_popen([sys.executable, '-c', child, str(ready),
                    CASE.replace('CI_CASE', 'CI_BEGIN'), CASE.replace('00:00:00Z', '00:00:01Z')], **kwargs)
            args = SimpleNamespace(container='synthetic', sqlcmd='synthetic', input='synthetic.sql',
                log=str(Path(directory)/'raw.log'), artifacts=str(Path(directory)/'artifacts'))
            with patch.dict(os.environ, MSSQL_EPHEMERAL_CREDENTIAL='SyntheticCredential'), \
                 patch.object(ci.subprocess, 'Popen', side_effect=launch), \
                 patch.object(ci, 'Sqlcmd', return_value=Connection()):
                self.assertEqual(ci.run(args), 7)
            report = json.loads((Path(args.artifacts)/'diagnostics.json').read_text())
            self.assertEqual(report['status'], 'BLOCKER_OBSERVED')
            self.assertEqual(report['samples'][0]['sampled_case']['kind'], 'BEGIN')
            self.assertEqual(report['samples'][0]['case']['kind'], 'CASE')
            self.assertEqual(report['errors'], [])

    def test_cleanup_verification_preserves_primary_failure(self):
        for verification_fails in (False, True):
            with self.subTest(verification_fails=verification_fails), tempfile.TemporaryDirectory() as directory:
                holder = SimpleNamespace(query=lambda sql: ["CI_HOLDER|51"], close=lambda: True)
                verified = []
                def verify(sql):
                    verified.append(sql)
                    if verification_fails:
                        raise RuntimeError("synthetic cleanup failure")
                    return []
                verifier = SimpleNamespace(query=verify, close=lambda: True)
                with patch.object(ci, "Sqlcmd", side_effect=[holder, verifier]), \
                     patch.object(ci, "run", return_value=1):
                    with self.assertRaises(FileNotFoundError):
                        sql_probe("synthetic", directory)
                self.assertEqual(len(verified), 1)
                self.assertIn("session_id=51", verified[0])
                self.assertIn("##ExampleCiLockProbe", verified[0])


def sql_probe(sqlcmd, artifacts):
    """Use only the existing isolated CI container; never execute an SSIS package."""
    root = Path(artifacts)
    root.mkdir(parents=True, exist_ok=True)
    holder = ci.Sqlcmd("sqlserver-analyze-impact-2025", sqlcmd)
    spid = None
    evidence = {}
    started = time.monotonic()
    try:
        rows = holder.query("""USE tempdb; SET NOCOUNT ON;
IF TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'))<>17 OR (SELECT compatibility_level FROM sys.databases WHERE name=N'tempdb')<>170 THROW 51002,N'CI_PROBE_ENGINE',1;
IF OBJECT_ID(N'tempdb..##ExampleCiLockProbe') IS NOT NULL THROW 51000,N'CI_PROBE_COLLISION',1;
CREATE TABLE ##ExampleCiLockProbe(id int NOT NULL);
INSERT ##ExampleCiLockProbe VALUES(1);
BEGIN TRAN; UPDATE ##ExampleCiLockProbe WITH(TABLOCKX) SET id=2;
SELECT N'CI_HOLDER|'+CONVERT(varchar(12),@@SPID);
RAISERROR(N'CI_SAMPLE_END',10,1) WITH NOWAIT;
GO
""")
        spid = int(next(row.split("|")[1] for row in rows if row.startswith("CI_HOLDER|")))
        # The holder is idle between batches and keeps its transaction and lock.
        for name, timeout in (("positive", 2000), ("immediate", 0), ("success", -1)):
            if name == "success":
                holder.query("ROLLBACK; RAISERROR(N'CI_SAMPLE_END',10,1) WITH NOWAIT;\nGO\n")
            query = f"""USE tempdb; SET NOCOUNT ON;
DECLARE @m nvarchar(400)=CONCAT(N'CI_BEGIN|202|file|0|',CONVERT(varchar(27),SYSUTCDATETIME(),126),N'Z|',@@SPID,N'|',@@LOCK_TIMEOUT,N'|-');
RAISERROR(N'%s',10,1,@m) WITH NOWAIT;
GO
SET LOCK_TIMEOUT {timeout};
DECLARE @m nvarchar(400)=CONCAT(N'CI_CASE|202|Probe|1|',CONVERT(varchar(27),SYSUTCDATETIME(),126),N'Z|',@@SPID,N'|',@@LOCK_TIMEOUT,N'|{name}');
RAISERROR(N'%s',10,1,@m) WITH NOWAIT;
WAITFOR DELAY '00:00:01';
SELECT id FROM ##ExampleCiLockProbe;
"""
            args = SimpleNamespace(container="sqlserver-analyze-impact-2025", sqlcmd=sqlcmd,
                                   query=query, log=str(root/(name+".log")), artifacts=str(root/name),
                                   log_limit=64*1024, report_limit=192*1024)
            code = ci.run(args)
            if name == "success":
                assert code == 0, "CI_PROBE_SUCCESS_STATUS"
                assert not Path(args.artifacts).exists(), "CI_PROBE_SUCCESS_ARTIFACT"
                (root/(name+".log")).unlink()
                evidence[name] = dict(sqlcmd_exit_code=code)
                continue
            report = json.loads((Path(args.artifacts)/"diagnostics.json").read_text())
            assert code != 0 and report["sqlcmd_exit_code"] == code, "CI_PROBE_NATIVE_EXIT"
            assert "Msg 1222," in (Path(args.artifacts)/"impact.log").read_text(), "CI_PROBE_NATIVE_1222"
            assert report["case"]["site"] == "Probe" and report["case"]["variant"] == name, "CI_PROBE_CASE"
            assert not report["errors"] and not report["log_incomplete"], "CI_PROBE_DIAGNOSTIC_FAILURE"
            if name == "positive":
                assert report["status"] == "BLOCKER_OBSERVED", "CI_PROBE_BLOCKER_NOT_CAPTURED"
                matches = []
                for sample in report["samples"]:
                    locks = [row for row in sample["rows"] if row["kind"] == "lock"]
                    waits = [row for row in locks if row["request_session_id"] == report["case"]["spid"] and row["request_status"] == "WAIT"]
                    owners = [row for row in locks if row["request_session_id"] == spid and row["request_status"] == "GRANTED"]
                    for wait in waits:
                        for owner in owners:
                            if ci.resource_key(wait) == ci.resource_key(owner):
                                matches.append(wait)
                    assert not any(row.get("kind") == "request" and row["session_id"] == spid for row in sample["rows"]), "CI_PROBE_HOLDER_NOT_IDLE"
                assert matches, "CI_PROBE_RESOURCE_MISSING"
            else:
                assert report["status"] in ("BLOCKER_NOT_CAPTURED", "BLOCKER_OBSERVED"), "CI_PROBE_UNKNOWN_STATUS"
            evidence[name] = report
        holder.query("DROP TABLE ##ExampleCiLockProbe; RAISERROR(N'CI_SAMPLE_END',10,1) WITH NOWAIT;\nGO\n")
    finally:
        primary_error = sys.exc_info()[0] is not None
        cleanup_errors = []
        holder_closed = holder.close()
        if not holder_closed:
            cleanup_errors.append("CI_PROBE_HOLDER_CLEANUP")
        if spid is not None:
            verifier = None
            try:
                verifier = ci.Sqlcmd("sqlserver-analyze-impact-2025", sqlcmd)
                verifier.query(f"""IF OBJECT_ID(N'tempdb..##ExampleCiLockProbe') IS NOT NULL OR EXISTS(SELECT 1 FROM sys.dm_exec_sessions WHERE session_id={spid} AND session_id<>@@SPID) THROW 51001,N'CI_PROBE_CLEANUP',1;
RAISERROR(N'CI_SAMPLE_END',10,1) WITH NOWAIT;
GO
""")
            except (OSError, RuntimeError, TimeoutError):
                cleanup_errors.append("CI_PROBE_CLEANUP_VERIFICATION_FAILED")
            finally:
                if verifier is not None and not verifier.close():
                    cleanup_errors.append("CI_PROBE_VERIFIER_CLEANUP")
        if cleanup_errors:
            if not primary_error:
                raise AssertionError(", ".join(cleanup_errors))
            print(", ".join(cleanup_errors)+" (primary error retained)")
    elapsed = time.monotonic()-started
    assert elapsed < 60, "CI_PROBE_TIME_LIMIT"
    assert sum(p.stat().st_size for p in root.rglob("*") if p.is_file()) < 1024*1024, "CI_PROBE_SIZE_LIMIT"
    (root/"qualification.json").write_text(json.dumps(dict(status="PASS", elapsed_seconds=elapsed,
        cases=list(evidence), cleanup="PASS", commit=os.environ.get("GITHUB_SHA")), indent=2), encoding="utf-8")
    print("CI lock diagnostic qualification: PASS (positive, immediate, success, sleeping holder, resource identity, cleanup)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sql-probe")
    parser.add_argument("--artifacts")
    args = parser.parse_args()
    if args.sql_probe:
        sql_probe(args.sql_probe, args.artifacts)
    else:
        unittest.main(argv=[__file__])
