"""Scoped session analysis and optional persistent Foundation fingerprints.

Only fingerprints are persisted. Semantic analyses remain in caller session memory.
"""
from __future__ import annotations

import argparse
from contextlib import contextmanager
import dataclasses
import json
import os
from pathlib import Path
import re
import sys
import types

PLANNER = ".ai/foundation/rule_context_cache/rule_context_cache.py"
INDEX = "AI_Metadata/Rule_Context_Cache_Scope.json"
PIN = "77ace825963862fd387ef37ac3b105abc95c652049fbf72855e205ab0455295b"
SESSION_RUNTIME = ".ai/foundation/runtime/processing_efficiency.py"
SESSION_PIN = "98b9338500e73ef1d6468612d5187887cc9d4d06fb4693bd69bcb7d560e46e8d"


def load_session_runtime(repository: Path):
    import hashlib
    path = repository / SESSION_RUNTIME
    source = path.read_bytes()
    if hashlib.sha256(source.replace(b"\r\n", b"\n")).hexdigest() != SESSION_PIN:
        raise ValueError("pinned session runtime differs")
    module = types.ModuleType("foundation_processing_efficiency")
    exec(compile(source, str(path), "exec"), module.__dict__)
    return module


def selected_scope(index, scope="development"):
    """Discovery inventory is not a mandatory reading list."""
    if index.get("profile") != "development":
        raise ValueError("unsupported scope index")
    if index.get("schema_version") == 1:
        if scope != "development":
            raise ValueError("unknown scope")
        return index["sources"], None
    if index.get("schema_version") != 2 or scope not in index["scopes"]:
        raise ValueError("unknown scope")
    inventory = index["discovery_sources"]
    dependencies = index["semantic_dependencies"]
    if any(not isinstance(p, str) or not p or "\\" in p or Path(p).is_absolute()
           or Path(p).drive or ".." in Path(p).parts or Path(p).as_posix() != p for p in inventory):
        raise ValueError("invalid source path")
    if len(inventory) != len(set(inventory)) or set(dependencies) != set(inventory):
        raise ValueError("incomplete dependency inventory")
    if any(not isinstance(ds, list) or any(d not in inventory for d in ds) for ds in dependencies.values()):
        raise ValueError("unknown dependency")
    selected = set(index["scopes"][scope])
    pending = list(selected)
    while pending:
        path = pending.pop()
        if path not in dependencies:
            raise ValueError("unknown source")
        for dependency in dependencies[path]:
            if dependency not in selected:
                selected.add(dependency)
                pending.append(dependency)
    return sorted(selected), {p: dependencies[p] for p in sorted(selected)}


def validate_session_links(repository, selected, index):
    """Reject unclassified supported local references without a planner."""
    root = repository.resolve()
    known = set(index["discovery_sources"])
    excluded = {(r["source"], r["target"]) for r in index["excluded_references"]}
    for source in selected:
        if Path(source).suffix != ".md":
            continue
        text = (root / source).read_text(encoding="utf-8")
        references = [(r, True) for r in re.findall(r"\[[^\]]*\]\(([^)\s]+)(?:\s+[\"'][^)]*)?\)", text)]
        suffixes = (".md", ".yaml", ".yml", ".json", ".txt", ".sql", ".py", ".ps1")
        references.extend((r, False) for r in re.findall(r"`([^`\r\n]+)`", text)
                          if not any(c.isspace() for c in r) and r.split("#", 1)[0].lower().endswith(suffixes))
        for ref, strong in references:
            ref = ref.split("#", 1)[0].split("?", 1)[0]
            if not ref or re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", ref) or ref.startswith("/"):
                continue
            candidates = [(root / source).parent / ref, root / ref]
            resolved = next((p.resolve() for p in candidates if p.is_file() and p.resolve().is_relative_to(root)), None)
            if resolved is None and "/" not in ref:
                matches = [root / p for p in known if Path(p).name == ref]
                if len(matches) == 1 and matches[0].is_file():
                    resolved = matches[0].resolve()
            if resolved is None:
                if strong:
                    raise ValueError(f"unresolved selected rule reference in {source}")
                continue
            target = resolved.relative_to(root).as_posix()
            if target not in known and (source, target) not in excluded:
                raise ValueError(f"unclassified selected rule reference: {source} -> {target}")


class SessionRuleContext:
    """Default in-memory API; no persistent planner, record, or destination.

    The caller supplies a freshly verified native authority/configuration
    digest and repository identity. Unknown discovery disables all reuse.
    Acknowledge actual analyses only after reading the captured source state.
    """
    def __init__(self, repository: Path):
        self.runtime = load_session_runtime(repository)
        self.context = self.runtime.SessionContext()

    def capture(self, repository, *, repository_identity, authority_key,
                discovery_complete, scope="development"):
        index_bytes = (repository / INDEX).read_bytes()
        index = json.loads(index_bytes)
        selected, dependencies = selected_scope(index, scope)
        if dependencies is None:
            raise ValueError("session reuse requires scoped dependency inventory")
        validate_session_links(repository, selected, index)
        # Implementation and selection changes cannot reuse a prior analysis.
        for path in (INDEX, "Code/Tools/Rule_Context_Cache.py", SESSION_RUNTIME):
            dependencies.setdefault(path, [])
        for path in selected:
            dependencies[path] = sorted(set(dependencies[path] + [INDEX, "Code/Tools/Rule_Context_Cache.py", SESSION_RUNTIME]))
        snapshot = self.runtime.capture_context(
            repository, dependencies, repository_identity=repository_identity,
            authority_key=authority_key, scope_key=scope,
            discovery_complete=discovery_complete)
        if (repository / INDEX).read_bytes() != index_bytes:
            raise ValueError("scope changed during capture")
        # Control inputs bind rule keys but do not become mandatory model reads.
        snapshot["analysis_keys"] = {p: snapshot["analysis_keys"][p] for p in selected}
        self._binding = dict(repository=repository, repository_identity=repository_identity,
                             authority_key=authority_key, discovery_complete=discovery_complete, scope=scope)
        return snapshot

    def check(self, snapshot):
        return self.context.check(snapshot)

    def acknowledge(self, snapshot, analyses):
        if self.capture(**self._binding) != snapshot:
            raise ValueError("analyzed session snapshot changed")
        return self.context.acknowledge(snapshot, analyses)

    def analysis_for(self, snapshot, source):
        return self.context.analysis_for(snapshot, source)


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


def capture_once(planner, options, index_path: Path, scope="development"):
    index_bytes = index_path.read_bytes()
    index = json.loads(index_bytes)
    selected, dependencies = selected_scope(index, scope)
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
        "scope": scope,
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
            if dependencies is None and target in locations:
                graph[path].add(target)
            elif dependencies is not None and target in index["discovery_sources"]:
                continue
            elif (path, target) not in excluded_edges:
                reasons.append("UNRESOLVED_REFERENCE")
    if dependencies is not None:
        for path, deps in dependencies.items():
            graph[path].update(deps)
        for entry in chain:
            for path in graph:
                if path != entry.canonical_path:
                    graph[path].add(entry.canonical_path)
    record = planner._finalize_record(options, planner._repository_identity(options.repository),
                                      planner._relative_cwd(options.repository, options.cwd), chain, locations, graph)
    return planner.SnapshotResult(record, not reasons, tuple(sorted(set(reasons))))


def capture(planner, options, index_path, scope="development"):
    first = capture_once(planner, options, index_path, scope)
    if not first.complete:
        return first
    second = capture_once(planner, options, index_path, scope)
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


def _operate(planner, options, cache_dir, index_path, *, expected_digest=None, available_keys=(), lock_timeout=5.0, scope="development"):
    snapshot = capture(planner, options, index_path, scope)
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
                current = capture(planner, options, index_path, scope)
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
    parser.add_argument("--scope", default="development", help="Selected task scope from the project index.")
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
                         available_keys=args.available_analysis_key, scope=args.scope)
        print(json.dumps(result, sort_keys=True))
        return 0
    except Exception:
        # Failure details may contain private host paths. No reuse is permitted.
        print(json.dumps({"status": "CACHE_MISS", "reason_codes": ["CACHE_OPERATION_FAILED"]}))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
