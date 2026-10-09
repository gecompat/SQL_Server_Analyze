"""Project discovery boundary for the pinned Foundation rule-context planner.

Only fingerprints are persisted. Semantic analyses remain in caller session memory.
"""
from __future__ import annotations

import argparse
from contextlib import contextmanager
import dataclasses
import json
import os
from pathlib import Path
import sys
import types

PLANNER = ".ai/foundation/rule_context_cache/rule_context_cache.py"
INDEX = "AI_Metadata/Rule_Context_Cache_Scope.json"
PIN = "77ace825963862fd387ef37ac3b105abc95c652049fbf72855e205ab0455295b"


def load_planner(repository: Path):
    path = repository / PLANNER
    import hashlib
    source = path.read_bytes()
    if hashlib.sha256(source.replace(b"\r\n", b"\n")).hexdigest() != PIN:
        raise ValueError("pinned planner differs")
    module = types.ModuleType("foundation_rule_context_cache")
    module.__file__ = str(path)
    sys.modules[module.__name__] = module
    exec(compile(source, str(path), "exec"), module.__dict__)
    return module


def capture_once(planner, options, index_path: Path):
    index_bytes = index_path.read_bytes()
    index = json.loads(index_bytes)
    if index.get("schema_version") != 1 or index.get("profile") != "development":
        raise ValueError("unsupported scope index")
    selected = index["sources"]
    excluded = index["excluded_references"]
    if len(selected) != len(set(selected)):
        raise ValueError("duplicate source")
    for path in selected:
        if not planner._is_record_path(path, allow_global=False):
            raise ValueError("invalid source path")
    allowed = {"product-reference", "optional-contract", "historical-context"}
    if any(row.get("classification") not in allowed for row in excluded):
        raise ValueError("invalid excluded reference")
    excluded_edges = {(row["source"], row["target"]) for row in excluded}
    tag = planner._sha256_json({
        "profile": index["profile"],
        "index": planner._logical_content(index_bytes)[1],
        "adapter": planner._logical_content(Path(__file__).read_bytes())[1],
        "planner": PIN,
        "effective_configuration": options.discovery_config_tag,
    })
    options = dataclasses.replace(options, discovery_config_tag=tag)
    chain, reasons = planner._instruction_chain(options)
    locations = {entry.canonical_path: entry for entry in chain}
    graph = {entry.canonical_path: set() for entry in chain}
    for path in selected:
        physical = (options.repository / path).resolve()
        if not physical.is_relative_to(options.repository) or not physical.is_file():
            reasons.append("UNRESOLVED_REFERENCE")
            continue
        if path not in locations:
            locations[path] = planner.SourceLocation(path, physical, planner._source_kind(physical, options.repository))
            graph[path] = set()
    file_index = planner._repo_file_index(options.repository)
    for path, location in locations.items():
        if path.startswith("@global/"):
            continue
        text = location.filesystem_path.read_text(encoding="utf-8")
        references = planner._markdown_references(text)
        if location.filesystem_path.name in {"repo_map.yaml", "repo_map.yml"}:
            references.extend(planner._repo_map_references(text))
        for reference, strong in references:
            if planner.URL_RE.match(reference) or reference.startswith(("#", "/")) or planner.WINDOWS_ABSOLUTE_RE.match(reference):
                continue
            resolved = planner._resolve_reference(reference, location.filesystem_path, options.repository, file_index)
            if resolved is None:
                if strong and planner._looks_like_rule_path(reference):
                    reasons.append("UNRESOLVED_REFERENCE")
                continue
            target = resolved.relative_to(options.repository).as_posix()
            if target in locations:
                graph[path].add(target)
            elif (path, target) not in excluded_edges:
                reasons.append("UNRESOLVED_REFERENCE")
    record = planner._finalize_record(options, planner._repository_identity(options.repository),
                                      planner._relative_cwd(options.repository, options.cwd), chain, locations, graph)
    return planner.SnapshotResult(record, not reasons, tuple(sorted(set(reasons))))


def capture(planner, options, index_path):
    first = capture_once(planner, options, index_path)
    if not first.complete:
        return first
    second = capture_once(planner, options, index_path)
    if first.record["record_digest"] != second.record["record_digest"]:
        return planner.SnapshotResult(second.record, False, ("SOURCE_CHANGED_DURING_DISCOVERY",))
    return second


def session_plan(payload, available_keys):
    """Availability is session-local; a fingerprint hit cannot create analysis."""
    keys = set(available_keys)
    missing = [path for path in payload["reuse"] if payload["analysis_keys"][path] not in keys]
    payload["reuse"] = [path for path in payload["reuse"] if path not in missing]
    payload["reanalyze"] = sorted(set(payload["reanalyze"] + missing))
    payload["analysis_full_read_count"] = len(payload["reanalyze"])
    if missing:
        payload["reason_codes"] = sorted(set(payload["reason_codes"] + ["SESSION_ANALYSIS_UNAVAILABLE"]))
    return payload


@contextmanager
def readonly_git():
    """Prevent optional Git status refreshes from rewriting the index."""
    previous = os.environ.get("GIT_OPTIONAL_LOCKS")
    os.environ["GIT_OPTIONAL_LOCKS"] = "0"
    try:
        yield
    finally:
        if previous is None:
            os.environ.pop("GIT_OPTIONAL_LOCKS", None)
        else:
            os.environ["GIT_OPTIONAL_LOCKS"] = previous


def operate(planner, options, cache_dir, index_path, **kwargs):
    with readonly_git():
        return _operate(planner, options, cache_dir, index_path, **kwargs)


def _operate(planner, options, cache_dir, index_path, *, expected_digest=None, available_keys=(), lock_timeout=5.0):
    snapshot = capture(planner, options, index_path)
    path = planner.cache_record_path(cache_dir, snapshot.record)
    planner._ensure_nonversioned_destination(options, path)
    if expected_digest is None:
        previous, reason = planner._read_record(path)
        result = session_plan(planner.compare_records(previous, snapshot, reason), available_keys)
    else:
        if not snapshot.complete or snapshot.record["record_digest"] != expected_digest:
            snapshot = planner.SnapshotResult(snapshot.record, False, ("ANALYZED_SNAPSHOT_CHANGED",))
            result = planner.compare_records(None, snapshot, "CACHE_RECORD_NOT_WRITTEN")
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            with planner._ExclusiveLock(path.with_suffix(path.suffix + ".lock"), lock_timeout):
                current = capture(planner, options, index_path)
                if not current.complete or current.record["record_digest"] != expected_digest:
                    snapshot = planner.SnapshotResult(current.record, False, ("ANALYZED_SNAPSHOT_CHANGED",))
                    result = planner.compare_records(None, snapshot, "CACHE_RECORD_NOT_WRITTEN")
                else:
                    planner._atomic_write_json(path, current.record)
                    snapshot = current
                    result = planner.compare_records(current.record, current)
                    result["recorded"] = True
                    result["reason_codes"] = sorted(set(result["reason_codes"] + ["CACHE_RECORD_WRITTEN"]))
    result["snapshot_digest"] = snapshot.record["record_digest"]
    return result


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("check", "record"))
    parser.add_argument("--repository", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--cwd", type=Path, default=Path.cwd())
    parser.add_argument("--codex-home", type=Path, required=True)
    parser.add_argument("--cache-dir", type=Path, required=True)
    parser.add_argument("--project-doc-max-bytes", type=int, required=True)
    parser.add_argument("--fallback-filename", action="append", default=[])
    parser.add_argument("--effective-config-tag", required=True,
                        help="Caller-established effective discovery configuration, including runtime overrides.")
    parser.add_argument("--available-analysis-key", action="append", default=[])
    parser.add_argument("--analyzed-snapshot-digest")
    args = parser.parse_args(argv)
    if args.operation == "record" and not args.analyzed_snapshot_digest:
        parser.error("record requires the exact digest checked before complete analysis")
    if args.operation == "check" and args.analyzed_snapshot_digest:
        parser.error("check does not record an analyzed snapshot")
    try:
        repository = args.repository.resolve()
        planner = load_planner(repository)
        options = planner.make_options(repository, args.cwd, codex_home=args.codex_home,
                                       fallback_filenames=tuple(args.fallback_filename),
                                       project_doc_max_bytes=args.project_doc_max_bytes,
                                       discovery_config_tag=args.effective_config_tag)
        result = operate(planner, options, args.cache_dir, repository / INDEX,
                         expected_digest=args.analyzed_snapshot_digest,
                         available_keys=args.available_analysis_key)
        print(json.dumps(result, sort_keys=True))
        return 0
    except Exception:
        # Failure details may contain private host paths. No reuse is permitted.
        print(json.dumps({"status": "CACHE_MISS", "reason_codes": ["CACHE_OPERATION_FAILED"]}))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
