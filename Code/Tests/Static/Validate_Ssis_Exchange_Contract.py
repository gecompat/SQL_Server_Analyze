"""Prüft die lokale unveränderte Schema-/Sollfallübernahme und generierte native Regeln."""
from pathlib import Path
import json
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[3]
for script in ("Sync_Ssis_Exchange_Contract.py","Build_Ssis_Exchange_Rules.py"):
    subprocess.run([sys.executable,str(ROOT/"Code/Tools"/script),"--check"],check=True)
schema=json.loads((ROOT/"Metadata/Quality/SSIS_Exchange_V1.schema.json").read_text(encoding="utf-8"))
example=json.loads((ROOT/"Metadata/Quality/SSIS_Exchange_V1.example.json").read_text(encoding="utf-8"))
assert schema["properties"]["version"]["const"]==example["version"]=="1.0.0"
assert len(example["coverage"])==8 and len({x["feature"] for x in example["coverage"]})==8
oracle=json.loads((ROOT/"Code/Tests/Fixtures/SSIS_Exchange/direct-8.expected.json").read_text(encoding="utf-8"))
assert len(oracle["nodeSignatures"])==9 and len(oracle["edgeSignatures"])==3
source=(ROOT/"Code/10_SSIS/040_USP_SsisPackageModelAnalysis.sql").read_text(encoding="utf-8")
assert "CREATE OR ALTER PROCEDURE [monitor].[USP_SsisPackageModelAnalysis]" in source
assert "EXCHANGE_TIME_BUDGET_EXCEEDED" not in source
assert "PACKAGE_BYTES_MATCH" in source and "'UNVERIFIED'" in source
for forbidden in ("AS EXTERNAL NAME","OPENROWSET","xp_cmdshell","sp_add_trusted_assembly","EXECUTE AS"):
    assert forbidden not in source,forbidden
print("SSIS_EXCHANGE_STATIC_PASS: local contract, shared oracle, generated validation and native-only boundary")
