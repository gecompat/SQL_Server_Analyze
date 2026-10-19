#!/usr/bin/env python3
"""Offline contracts and one bounded synthetic SQL lock qualification batch."""

import argparse
import io
import json
import os
from pathlib import Path
import re
import subprocess
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
            self.assertEqual(source.count("N''CI_AFTER|''"), len(calls))
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
        secret = "SyntheticCredential123!"
        for split in range(len(secret)+1):
            output = io.BytesIO()
            writer = ci.LogWriter(output, secret)
            writer.write("prefix "+secret[:split])
            writer.write(secret[split:]+" suffix")
            writer.write("", final=True)
            self.assertEqual(output.getvalue(), b"prefix [REDACTED] suffix")
        output = io.BytesIO()
        writer = ci.LogWriter(output, secret, limit=3)
        writer.write("abcdef", final=True)
        self.assertTrue(writer.incomplete)
        self.assertLessEqual(len(output.getvalue()), 3)

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
            process = SimpleNamespace(stdout=io.BytesIO((CASE+"\nMsg 1222, Level 16, State 1\nSyntheticCredential\n").encode()), wait=lambda: 7)
            with patch.dict(os.environ, MSSQL_EPHEMERAL_CREDENTIAL="SyntheticCredential"), \
                 patch.object(ci.subprocess, "Popen", return_value=process), \
                 patch.object(ci, "Sqlcmd", side_effect=OSError("synthetic")):
                self.assertEqual(ci.run(args), 7)
            report = json.loads((Path(args.artifacts)/"diagnostics.json").read_text())
            self.assertIn("OBSERVATION_FAILED", report["errors"])
            self.assertEqual(report["sqlcmd_exit_code"], 7)
            self.assertNotIn("SyntheticCredential", (Path(args.artifacts)/"impact.log").read_text())


def sql_probe(sqlcmd, artifacts):
    """Use only the existing isolated CI container; never execute an SSIS package."""
    root = Path(artifacts)
    root.mkdir(parents=True, exist_ok=True)
    holder = ci.Sqlcmd("sqlserver-analyze-impact-2025", sqlcmd)
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
PRINT N'CI_SAMPLE_END';
GO
""")
        spid = int(next(row.split("|")[1] for row in rows if row.startswith("CI_HOLDER|")))
        # The holder is idle between batches and keeps its transaction and lock.
        for name, timeout in (("positive", 2000), ("immediate", 0), ("success", -1)):
            if name == "success":
                holder.query("ROLLBACK; PRINT N'CI_SAMPLE_END';\nGO\n")
            query = f"""USE tempdb; SET NOCOUNT ON; SET LOCK_TIMEOUT {timeout};
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
        holder.query("DROP TABLE ##ExampleCiLockProbe; PRINT N'CI_SAMPLE_END';\nGO\n")
    finally:
        assert holder.close(), "CI_PROBE_HOLDER_CLEANUP"
    verifier = ci.Sqlcmd("sqlserver-analyze-impact-2025", sqlcmd)
    try:
        verifier.query(f"""IF OBJECT_ID(N'tempdb..##ExampleCiLockProbe') IS NOT NULL OR EXISTS(SELECT 1 FROM sys.dm_exec_sessions WHERE session_id={spid} AND session_id<>@@SPID) THROW 51001,N'CI_PROBE_CLEANUP',1;
PRINT N'CI_SAMPLE_END';
GO
""")
    finally:
        assert verifier.close(), "CI_PROBE_VERIFIER_CLEANUP"
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
