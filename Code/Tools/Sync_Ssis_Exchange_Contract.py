"""Übernimmt ausschließlich versionierte kanonische SSIS-Vertragsdateien aus Toolbelt."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT=Path(__file__).resolve().parents[2]
PROVENANCE=ROOT/"Metadata/Quality/SSIS_Exchange_V1.provenance.json"
PREFIX="Modules/toolbelt.tsql.ssis-debug/Contracts/Exchange/"
FILES={
    "SSIS_Exchange_V1.schema.json":"Metadata/Quality/SSIS_Exchange_V1.schema.json",
    "SSIS_Exchange_V1.example.json":"Metadata/Quality/SSIS_Exchange_V1.example.json",
    "Fixtures/direct-8.dtsx":"Code/Tests/Fixtures/SSIS_Exchange/direct-8.dtsx",
    "Fixtures/direct-8.expected.json":"Code/Tests/Fixtures/SSIS_Exchange/direct-8.expected.json",
    "Fixtures/.gitattributes":"Code/Tests/Fixtures/SSIS_Exchange/.gitattributes",
}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--toolbelt-root",type=Path)
    parser.add_argument("--check",action="store_true")
    args=parser.parse_args()
    if args.check:
        data=json.loads(PROVENANCE.read_text(encoding="utf-8"))
        assert data["sourceRepository"]=="https://github.com/gecompat/SQL_Server_Toolbelt"
        assert re.fullmatch(r"[0-9a-f]{40}",data["sourceCommit"])
        assert {row["sourcePath"]:row["targetPath"] for row in data["files"]}=={PREFIX+k:v for k,v in FILES.items()}
        for row in data["files"]:
            assert hashlib.sha256((ROOT/row["targetPath"]).read_bytes()).hexdigest()==row["sha256"],row["targetPath"]
        print("SSIS_EXCHANGE_VENDOR_PASS: immutable local contract and fixture copy; no adjacent repository required")
        return
    if args.toolbelt_root is None:
        parser.error("--toolbelt-root is required for an explicit update")
    source=args.toolbelt_root.resolve()
    def git(*arguments):
        return subprocess.check_output(["git","-C",str(source),*arguments])
    paths=[PREFIX+k for k in FILES]
    if git("status","--porcelain","--",*paths).strip():
        raise SystemExit("SSIS_EXCHANGE_SOURCE_MUST_BE_COMMITTED")
    commit=git("rev-parse","HEAD").decode().strip()
    if not re.fullmatch(r"[0-9a-f]{40}",commit):
        raise SystemExit("SSIS_EXCHANGE_INVALID_SOURCE_COMMIT")
    rows=[]
    for relative,target in FILES.items():
        content=git("show",commit+":"+PREFIX+relative)
        destination=ROOT/target;destination.parent.mkdir(parents=True,exist_ok=True);destination.write_bytes(content)
        rows.append({"sourcePath":PREFIX+relative,"targetPath":target,"sha256":hashlib.sha256(content).hexdigest()})
    PROVENANCE.write_text(json.dumps({"schemaVersion":1,"sourceRepository":"https://github.com/gecompat/SQL_Server_Toolbelt","sourceCommit":commit,"files":rows},indent=2)+"\n",encoding="utf-8")
    print("SSIS_EXCHANGE_VENDOR_UPDATED: exact Git blobs and commit binding; no network or runtime installation")


if __name__=="__main__":
    main()
