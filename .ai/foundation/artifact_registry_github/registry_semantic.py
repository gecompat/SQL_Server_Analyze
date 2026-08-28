#!/usr/bin/env python3
"""Reference validator, allocator, object-level merger, and GitHub PR preflight for registry v2."""

from __future__ import annotations

import argparse
import base64
import json
import os
import re
import sys
import urllib.parse
import urllib.request
import uuid
from pathlib import Path
from typing import Any

PROFILE = "foundation-artifact-registry/v2"
REF_RE = re.compile(r"^(?P<prefix>[A-Z][A-Z0-9_]*)-(?P<sequence>[0-9]+)$")
UID_RE = re.compile(r"^urn:uuid:([0-9a-fA-F-]{36})$")
ACYCLIC_RELATIONS = {"parent", "depends_on"}
MISSING = object()


class RegistryError(RuntimeError):
    pass


def load_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise RegistryError(f"file not found: {path}") from exc
    except json.JSONDecodeError as exc:
        raise RegistryError(f"invalid JSON in {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise RegistryError(f"JSON root must be an object: {path}")
    return value


def canonical_text(value: dict[str, Any]) -> str:
    return json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + "\n"


def write_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(canonical_text(value), encoding="utf-8", newline="\n")


def normalize_uid(raw: str) -> str:
    match = UID_RE.fullmatch(raw)
    if not match:
        raise RegistryError(f"invalid artifact UID: {raw}")
    parsed = uuid.UUID(match.group(1))
    if parsed.version not in {4, 7}:
        raise RegistryError(f"unsupported artifact UID version: {raw}")
    return f"urn:uuid:{parsed}"


def parse_ref(ref: str) -> tuple[str, int]:
    match = REF_RE.fullmatch(ref)
    if not match:
        raise RegistryError(f"invalid canonical human reference: {ref}")
    return match.group("prefix"), int(match.group("sequence"))


def resolve_target(registry: dict[str, Any], target: str) -> str | None:
    artifacts = registry["artifacts"]
    if target in artifacts:
        return target
    for ref, record in artifacts.items():
        if record.get("artifact_uid") == target or target in record.get("aliases", []):
            return ref
    return None


def _detect_cycles(edges: dict[str, set[str]], relation_type: str) -> list[str]:
    visiting: set[str] = set()
    visited: set[str] = set()
    stack: list[str] = []
    problems: list[str] = []

    def visit(node: str) -> None:
        if node in visited:
            return
        if node in visiting:
            start = stack.index(node) if node in stack else 0
            problems.append(f"{relation_type} cycle: {' -> '.join(stack[start:] + [node])}")
            return
        visiting.add(node)
        stack.append(node)
        for nxt in sorted(edges.get(node, set())):
            visit(nxt)
        stack.pop()
        visiting.remove(node)
        visited.add(node)

    for node in sorted(edges):
        visit(node)
    return problems


def validate_registry(registry: dict[str, Any]) -> list[str]:
    problems: list[str] = []
    if registry.get("schema_version") != 2 or registry.get("profile") != PROFILE:
        return [f"registry must use schema_version=2 and profile={PROFILE}"]
    prefixes = registry.get("prefixes")
    artifacts = registry.get("artifacts")
    if not isinstance(prefixes, dict) or not prefixes:
        return ["prefixes must be a non-empty object"]
    if not isinstance(artifacts, dict):
        return ["artifacts must be an object"]

    kind_to_prefix: dict[str, str] = {}
    for prefix, row in prefixes.items():
        if not re.fullmatch(r"[A-Z][A-Z0-9_]*", prefix) or not isinstance(row, dict):
            problems.append(f"invalid prefix definition: {prefix}")
            continue
        kind = row.get("kind")
        width = row.get("width")
        if not isinstance(kind, str) or not kind:
            problems.append(f"prefix {prefix} has invalid kind")
        elif kind in kind_to_prefix:
            problems.append(f"kind {kind} is assigned to multiple prefixes")
        else:
            kind_to_prefix[kind] = prefix
        if not isinstance(width, int) or width < 1 or width > 12:
            problems.append(f"prefix {prefix} has invalid width")
        if "next_sequence" in row:
            problems.append(f"prefix {prefix} persists forbidden derived field next_sequence")
    if "registry_revision" in registry:
        problems.append("v2 Git-native registry must not persist registry_revision")

    seen_uids: dict[str, str] = {}
    alias_owner: dict[str, str] = {}
    graph_edges: dict[str, dict[str, set[str]]] = {name: {} for name in ACYCLIC_RELATIONS}

    for ref, record in artifacts.items():
        try:
            prefix, sequence = parse_ref(ref)
        except RegistryError as exc:
            problems.append(str(exc))
            continue
        if prefix not in prefixes:
            problems.append(f"{ref} uses unknown prefix {prefix}")
            continue
        width = prefixes[prefix].get("width")
        if isinstance(width, int):
            expected = f"{prefix}-{sequence:0{max(width, len(str(sequence)))}d}"
            if ref != expected:
                problems.append(f"{ref} does not match configured width {width}")
        if not isinstance(record, dict):
            problems.append(f"{ref} record must be an object")
            continue
        if "human_ref" in record:
            problems.append(f"{ref} redundantly stores human_ref; the object key is canonical")
        kind = record.get("kind")
        if kind != prefixes[prefix].get("kind"):
            problems.append(f"{ref} kind {kind!r} does not match prefix kind {prefixes[prefix].get('kind')!r}")
        title = record.get("title")
        if not isinstance(title, str) or not title.strip():
            problems.append(f"{ref} requires non-empty title")
        if record.get("registration_state") not in {"DRAFT", "REGISTERED", "RETIRED"}:
            problems.append(f"{ref} has invalid registration_state")
        uid = record.get("artifact_uid")
        if not isinstance(uid, str):
            problems.append(f"{ref} requires artifact_uid")
        else:
            try:
                uid = normalize_uid(uid)
            except RegistryError as exc:
                problems.append(str(exc))
            else:
                if uid in seen_uids:
                    problems.append(f"artifact UID {uid} is used by both {seen_uids[uid]} and {ref}")
                else:
                    seen_uids[uid] = ref

        aliases = record.get("aliases", [])
        if not isinstance(aliases, list) or any(not isinstance(value, str) or not value for value in aliases):
            problems.append(f"{ref} aliases must be a list of non-empty strings")
            aliases = []
        if len(aliases) != len(set(aliases)):
            problems.append(f"{ref} contains duplicate aliases")
        for alias in aliases:
            if alias in artifacts and alias != ref:
                problems.append(f"alias {alias} on {ref} collides with canonical reference")
            owner = alias_owner.get(alias)
            if owner and owner != ref:
                problems.append(f"alias {alias} is claimed by both {owner} and {ref}")
            alias_owner[alias] = ref

        relations = record.get("relations", [])
        if not isinstance(relations, list):
            problems.append(f"{ref} relations must be a list")
            continue
        for relation in relations:
            if not isinstance(relation, dict) or not isinstance(relation.get("type"), str) or not isinstance(relation.get("target"), str):
                problems.append(f"{ref} has invalid relation entry")
                continue
            relation_type = relation["type"]
            target = resolve_target(registry, relation["target"])
            if target is None:
                problems.append(f"{ref} relation {relation_type} has unresolved target {relation['target']}")
                continue
            if target == ref:
                problems.append(f"{ref} relation {relation_type} may not target itself")
            if relation_type in ACYCLIC_RELATIONS:
                graph_edges[relation_type].setdefault(ref, set()).add(target)

    for relation_type, edges in graph_edges.items():
        problems.extend(_detect_cycles(edges, relation_type))
    return problems


def next_reference(registry: dict[str, Any], prefix: str, reserved_refs: set[str] | None = None) -> str:
    problems = validate_registry(registry)
    if problems:
        raise RegistryError("; ".join(problems))
    if prefix not in registry["prefixes"]:
        raise RegistryError(f"unknown prefix: {prefix}")
    used = set(registry["artifacts"])
    used.update(reserved_refs or set())
    sequences = []
    for ref in used:
        match = REF_RE.fullmatch(ref)
        if match and match.group("prefix") == prefix:
            sequences.append(int(match.group("sequence")))
    sequence = max(sequences, default=0) + 1
    width = registry["prefixes"][prefix]["width"]
    return f"{prefix}-{sequence:0{max(width, len(str(sequence)))}d}"


def _merge_value(base: Any, main: Any, head: Any, path: tuple[str, ...], conflicts: list[str]) -> Any:
    if main == head:
        return main
    if head == base:
        return main
    if main == base:
        return head
    if isinstance(base, dict) and isinstance(main, dict) and isinstance(head, dict):
        result: dict[str, Any] = {}
        for key in sorted(set(base) | set(main) | set(head)):
            b = base.get(key, MISSING)
            m = main.get(key, MISSING)
            h = head.get(key, MISSING)
            child_path = path + (key,)
            if m is MISSING and h is MISSING:
                continue
            if b is MISSING:
                if m is MISSING:
                    result[key] = h
                elif h is MISSING:
                    result[key] = m
                elif m == h:
                    result[key] = m
                else:
                    conflicts.append(f"CONCURRENT_ADD {'.'.join(child_path)}")
                continue
            if m is MISSING:
                if h == b:
                    continue
                conflicts.append(f"DELETE_MODIFY_CONFLICT {'.'.join(child_path)}")
                continue
            if h is MISSING:
                if m == b:
                    continue
                conflicts.append(f"MODIFY_DELETE_CONFLICT {'.'.join(child_path)}")
                continue
            result[key] = _merge_value(b, m, h, child_path, conflicts)
        return result
    conflicts.append(
        f"VALUE_CONFLICT {'.'.join(path)} base={base!r} main={main!r} head={head!r}"
    )
    return main


def validate_transition(old: dict[str, Any], new: dict[str, Any], label: str) -> list[str]:
    problems: list[str] = []
    old_artifacts = old.get("artifacts", {})
    new_artifacts = new.get("artifacts", {})
    for ref, old_record in old_artifacts.items():
        if ref not in new_artifacts:
            problems.append(f"{label}: registered reference removed instead of retained/retired: {ref}")
            continue
        new_record = new_artifacts[ref]
        if old_record.get("artifact_uid") != new_record.get("artifact_uid"):
            problems.append(f"{label}: canonical reference {ref} reassigned to another artifact UID")
        if old_record.get("registration_state") == "RETIRED" and new_record.get("registration_state") != "RETIRED":
            problems.append(f"{label}: retired artifact reactivated: {ref}")
    return problems


def semantic_merge(base: dict[str, Any], main: dict[str, Any], head: dict[str, Any]) -> tuple[dict[str, Any], list[str]]:
    conflicts: list[str] = []
    result = _merge_value(base, main, head, tuple(), conflicts)
    if not isinstance(result, dict):
        conflicts.append("MERGED_ROOT_NOT_OBJECT")
        return {}, conflicts
    conflicts.extend(validate_transition(base, result, "base->merged"))
    conflicts.extend(validate_transition(main, result, "main->merged"))
    conflicts.extend(validate_registry(result))
    return result, conflicts


def changed_refs(base: dict[str, Any], head: dict[str, Any]) -> set[str]:
    base_artifacts = base.get("artifacts", {})
    head_artifacts = head.get("artifacts", {})
    return {ref for ref in set(base_artifacts) | set(head_artifacts) if base_artifacts.get(ref, MISSING) != head_artifacts.get(ref, MISSING)}


def introduced_refs(base: dict[str, Any], head: dict[str, Any]) -> set[str]:
    return set(head.get("artifacts", {})) - set(base.get("artifacts", {}))


def aliases_for_refs(registry: dict[str, Any], refs: set[str]) -> dict[str, str]:
    result: dict[str, str] = {}
    for ref in refs:
        record = registry.get("artifacts", {}).get(ref, {})
        for alias in record.get("aliases", []) if isinstance(record, dict) else []:
            result[alias] = ref
    return result


def uids_for_refs(registry: dict[str, Any], refs: set[str]) -> dict[str, str]:
    result: dict[str, str] = {}
    for ref in refs:
        record = registry.get("artifacts", {}).get(ref, {})
        uid = record.get("artifact_uid") if isinstance(record, dict) else None
        if isinstance(uid, str):
            result[uid] = ref
    return result


def github_json(url: str, token: str) -> Any:
    request = urllib.request.Request(
        url,
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "ai-repository-foundation-registry-preflight",
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.loads(response.read().decode("utf-8"))


def github_registry(repo: str, path: str, ref: str, token: str) -> dict[str, Any]:
    encoded_path = "/".join(urllib.parse.quote(part, safe="") for part in path.split("/"))
    url = f"https://api.github.com/repos/{repo}/contents/{encoded_path}?ref={urllib.parse.quote(ref, safe='')}"
    payload = github_json(url, token)
    raw = base64.b64decode(payload["content"]).decode("utf-8")
    value = json.loads(raw)
    if not isinstance(value, dict):
        raise RegistryError(f"registry at {repo}@{ref}:{path} is not an object")
    return value


def github_preflight(repo: str, pr_number: int, registry_path: str, token: str) -> tuple[list[str], list[str], set[str]]:
    pulls = github_json(f"https://api.github.com/repos/{repo}/pulls?state=open&per_page=100", token)
    current = next((item for item in pulls if int(item["number"]) == pr_number), None)
    if current is None:
        raise RegistryError(f"current PR #{pr_number} not found among open pull requests")
    current_base = github_registry(repo, registry_path, current["base"]["sha"], token)
    current_head = github_registry(repo, registry_path, current["head"]["sha"], token)
    cur_new = introduced_refs(current_base, current_head)
    cur_changed = changed_refs(current_base, current_head)
    cur_uids = uids_for_refs(current_head, cur_new)
    cur_aliases = aliases_for_refs(current_head, cur_new)
    hard: list[str] = []
    warnings: list[str] = []
    reserved = set(cur_new)

    for other in pulls:
        if int(other["number"]) == pr_number:
            continue
        try:
            other_base = github_registry(repo, registry_path, other["base"]["sha"], token)
            other_head = github_registry(repo, registry_path, other["head"]["sha"], token)
        except Exception as exc:  # fail visible but do not hide current PR validation
            warnings.append(f"PR #{other['number']}: unable to inspect registry: {exc}")
            continue
        other_new = introduced_refs(other_base, other_head)
        other_changed = changed_refs(other_base, other_head)
        reserved.update(other_new)
        for ref in sorted(cur_new & other_new):
            if current_head["artifacts"].get(ref) != other_head["artifacts"].get(ref):
                hard.append(f"DUPLICATE_HUMAN_REF {ref} also introduced by PR #{other['number']}")
        other_uids = uids_for_refs(other_head, other_new)
        for uid in sorted(set(cur_uids) & set(other_uids)):
            hard.append(f"DUPLICATE_ARTIFACT_UID {uid} in {cur_uids[uid]} and PR #{other['number']} {other_uids[uid]}")
        other_aliases = aliases_for_refs(other_head, other_new)
        for alias in sorted(set(cur_aliases) & set(other_aliases)):
            hard.append(f"ALIAS_COLLISION {alias} also introduced by PR #{other['number']}")
        for ref in sorted((cur_changed & other_changed) - (cur_new | other_new)):
            warnings.append(f"CONCURRENT_ARTIFACT_EDIT {ref} also changed by PR #{other['number']}")
    return hard, warnings, reserved


def backlog_text(registry: dict[str, Any]) -> str:
    lines = [
        "# Backlog",
        "",
        "Status: GENERATED/INFORMATIVE",
        "",
        "Canonical planning state is `.ai/identity/registry.json`. Do not edit this table independently.",
        "Historical `FND-*` references remain aliases according to `Documentation/Architecture/IDENTIFIER_MIGRATION_2026-08-24.md`.",
        "",
        "| ID | Priority | Status | Title | Dependencies | Acceptance criteria |",
        "|---|---|---|---|---|---|",
    ]
    for ref, record in sorted(registry["artifacts"].items()):
        if not ref.startswith("WI-"):
            continue
        deps = [rel["target"] for rel in record.get("relations", []) if rel.get("type") == "depends_on"]
        lines.append(
            "| {ref} | {priority} | {status} | {title} | {deps} | {acceptance} |".format(
                ref=ref,
                priority=record.get("priority") or "",
                status=record.get("status") or "",
                title=str(record.get("title", "")).replace("|", "\\|"),
                deps=", ".join(deps),
                acceptance=str(record.get("acceptance_criteria") or "").replace("|", "\\|"),
            )
        )
    lines += [
        "",
        "Existing-repository AI transfer evidence is recorded in `Documentation/Quality/EXISTING_REPOSITORY_AI_TRANSFER_EVIDENCE.md`; the fresh-agent continuation criterion remains tracked by WI-0001.",
        "",
        "Allowed work-item statuses are project-governed values such as `proposed`, `ready`, `in_progress`, `blocked`, and `done`.",
        "",
    ]
    return "\n".join(lines)


def cmd_validate(args: argparse.Namespace) -> int:
    registry = load_json(args.registry)
    problems = validate_registry(registry)
    for problem in problems:
        print(f"[BLOCK] {problem}")
    if problems:
        return 2
    print(f"[OK] {PROFILE} artifacts={len(registry['artifacts'])}")
    return 0


def cmd_allocate(args: argparse.Namespace) -> int:
    registry = load_json(args.registry)
    reserved = set(args.reserved_ref or [])
    print(next_reference(registry, args.prefix, reserved))
    return 0


def cmd_merge(args: argparse.Namespace) -> int:
    base, main, head = load_json(args.base), load_json(args.main), load_json(args.head)
    result, conflicts = semantic_merge(base, main, head)
    for conflict in conflicts:
        print(f"[BLOCK] {conflict}")
    if conflicts:
        return 2
    if args.output:
        write_json(args.output, result)
    else:
        sys.stdout.write(canonical_text(result))
    return 0


def cmd_compare(args: argparse.Namespace) -> int:
    expected, actual = load_json(args.expected), load_json(args.actual)
    if expected != actual:
        print("[BLOCK] GIT_MERGE_RESULT_DIFFERS_FROM_SEMANTIC_MERGE")
        return 2
    print("[OK] Git merge result equals object-level semantic merge")
    return 0


def cmd_backlog(args: argparse.Namespace) -> int:
    registry = load_json(args.registry)
    problems = validate_registry(registry)
    if problems:
        for problem in problems:
            print(f"[BLOCK] {problem}")
        return 2
    expected = backlog_text(registry)
    if args.check:
        actual = args.output.read_text(encoding="utf-8") if args.output.exists() else ""
        if actual != expected:
            print(f"[BLOCK] generated backlog is stale: {args.output}")
            return 2
        print(f"[OK] generated backlog matches {args.registry}")
        return 0
    args.output.write_text(expected, encoding="utf-8", newline="\n")
    return 0


def cmd_preflight(args: argparse.Namespace) -> int:
    token = os.environ.get(args.token_env)
    if not token:
        raise RegistryError(f"missing GitHub token environment variable: {args.token_env}")
    hard, warnings, reserved = github_preflight(args.repo, args.pr, args.registry_path, token)
    for warning in warnings:
        print(f"[WARN] {warning}")
    for conflict in hard:
        print(f"[BLOCK] {conflict}")
    if args.reserved_output:
        args.reserved_output.write_text("\n".join(sorted(reserved)) + "\n", encoding="utf-8")
    return 2 if hard else 0


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description=__doc__)
    sub = root.add_subparsers(dest="command", required=True)
    p = sub.add_parser("validate")
    p.add_argument("--registry", type=Path, required=True)
    p.set_defaults(func=cmd_validate)
    p = sub.add_parser("allocate")
    p.add_argument("--registry", type=Path, required=True)
    p.add_argument("--prefix", required=True)
    p.add_argument("--reserved-ref", action="append")
    p.set_defaults(func=cmd_allocate)
    p = sub.add_parser("merge")
    p.add_argument("--base", type=Path, required=True)
    p.add_argument("--main", type=Path, required=True)
    p.add_argument("--head", type=Path, required=True)
    p.add_argument("--output", type=Path)
    p.set_defaults(func=cmd_merge)
    p = sub.add_parser("compare")
    p.add_argument("--expected", type=Path, required=True)
    p.add_argument("--actual", type=Path, required=True)
    p.set_defaults(func=cmd_compare)
    p = sub.add_parser("backlog")
    p.add_argument("--registry", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--check", action="store_true")
    p.set_defaults(func=cmd_backlog)
    p = sub.add_parser("preflight-github")
    p.add_argument("--repo", required=True)
    p.add_argument("--pr", type=int, required=True)
    p.add_argument("--registry-path", required=True)
    p.add_argument("--token-env", default="GITHUB_TOKEN")
    p.add_argument("--reserved-output", type=Path)
    p.set_defaults(func=cmd_preflight)
    return root


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    try:
        return int(args.func(args))
    except (OSError, RegistryError, urllib.error.URLError, json.JSONDecodeError) as exc:
        print(f"[BLOCK] {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
