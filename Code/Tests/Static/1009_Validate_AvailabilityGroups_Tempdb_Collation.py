#!/usr/bin/env python3
"""Validate explicit temp-table collation in the Availability Groups procedure."""
from __future__ import annotations

import argparse
import sys
from pathlib import Path


PROCEDURE = "Code/07_Infrastructure/040_USP_AvailabilityGroups.sql"
REQUIRED = (
    "[AgName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[ReplicaServerName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[EndpointUrl] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[ListenerDnsName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[IpAddress] nvarchar(48) COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[ReadOnlyReplicaServerName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS",
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path, default=Path("."))
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        assert len(REQUIRED) == 7 and all(REQUIRED)
        print("Availability Groups temp-table collation validator self-test passed.")
        return 0
    source = (args.repository_root.resolve() / PROCEDURE).read_text(encoding="utf-8-sig")
    errors = [f"missing Availability Groups collation contract: {token}" for token in REQUIRED if token not in source]
    if errors:
        print("\n".join(f"ERROR: {error}" for error in errors), file=sys.stderr)
        return 1
    print("Availability Groups temporary-table collation contract passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
