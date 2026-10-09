"""Validate project cache boundaries with isolated synthetic Git repositories."""
from pathlib import Path
import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import types
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
adapter_path = ROOT / "Code/Tools/Rule_Context_Cache.py"
adapter = types.ModuleType("project_rule_cache")
adapter.__file__ = str(adapter_path)
exec(compile(adapter_path.read_bytes(), str(adapter_path), "exec"), adapter.__dict__)


class CacheContracts(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "repository"
        self.root.mkdir()
        self.home = Path(self.temp.name) / "agent-home"
        self.home.mkdir()
        self.cache = Path(self.temp.name) / "cache"
        destination = self.root / adapter.PLANNER
        destination.parent.mkdir(parents=True)
        shutil.copyfile(ROOT / adapter.PLANNER, destination)
        self.planner = adapter.load_planner(self.root)
        self.index = self.root / adapter.INDEX
        self.index.parent.mkdir()
        self.scope = {"schema_version": 1, "profile": "development",
                      "sources": ["AGENTS.md", "dependent.md", "rule.md"], "excluded_references": []}
        self.index.write_text(json.dumps(self.scope), encoding="utf-8")
        (self.root / "AGENTS.md").write_text("# Synthetic instructions\n[Rule](rule.md)\n", encoding="utf-8")
        (self.root / "dependent.md").write_text("[Input](rule.md)\n", encoding="utf-8")
        (self.root / "rule.md").write_text("Synthetic rule payload.\n", encoding="utf-8")
        self.git("init", "--quiet")
        self.git("add", ".")
        self.git("-c", "user.name=Synthetic Test", "-c", "user.email=synthetic.invalid", "commit", "--quiet", "-m", "Synthetic fixture")
        self.options = self.planner.make_options(self.root, self.root, codex_home=self.home,
                                                 fallback_filenames=(), project_doc_max_bytes=32768,
                                                 discovery_config_tag="synthetic-defaults")

    def git(self, *args):
        subprocess.run(["git", "-c", "core.autocrlf=false", "-C", str(self.root), *args],
                       capture_output=True, check=True)

    def check(self, **kwargs):
        return adapter.operate(self.planner, self.options, self.cache, self.index, **kwargs)

    def record(self):
        first = self.check()
        result = self.check(expected_digest=first["snapshot_digest"])
        self.assertTrue(result["recorded"])
        return result

    def test_readonly_check_and_session_availability(self):
        # A harmless stat change must not cause Git status to refresh its index.
        os.utime(self.root / "rule.md", (1_700_000_000, 1_700_000_000))
        before = {p.relative_to(self.root).as_posix(): p.read_bytes() for p in self.root.rglob("*") if p.is_file()}
        self.assertEqual(self.check()["status"], "CACHE_MISS")
        self.assertFalse(self.cache.exists())
        adapter.load_planner(self.root)
        after = {p.relative_to(self.root).as_posix(): p.read_bytes() for p in self.root.rglob("*") if p.is_file()}
        self.assertEqual(before, after)
        self.assertFalse(list(self.root.rglob("__pycache__")))
        record = self.record()
        hit = self.check()
        self.assertEqual(hit["status"], "CACHE_HIT")
        self.assertEqual(hit["reuse"], [])
        self.assertEqual(len(hit["reanalyze"]), 3)
        available = self.check(available_keys=record["analysis_keys"].values())
        self.assertEqual(available["reanalyze"], [])
        self.assertEqual(len(available["reuse"]), 3)

    def test_git_state_and_configuration_are_checked(self):
        record = self.record()
        self.git("rm", "--cached", "rule.md")
        result = self.check(available_keys=record["analysis_keys"].values())
        self.assertEqual(result["status"], "PARTIAL_INVALIDATION")
        self.assertIn("RULE_GIT_STATE_CHANGED", result["reason_codes"])
        self.assertIn("rule.md", result["reanalyze"])
        self.options = self.planner.make_options(self.root, self.root, codex_home=self.home,
                                                 fallback_filenames=("RULES.md",), project_doc_max_bytes=32768,
                                                 discovery_config_tag="changed-configuration")
        self.assertEqual(self.check()["status"], "CACHE_MISS")

    def test_changed_dependency_graph_is_miss(self):
        self.record()
        (self.root / "dependent.md").write_text("Independent rule.\n", encoding="utf-8")
        result = self.check()
        self.assertEqual(result["status"], "CACHE_MISS")
        self.assertIn("DEPENDENCY_GRAPH_CHANGED", result["reason_codes"])

    def test_changed_rule_invalidates_dependents(self):
        self.record()
        (self.root / "rule.md").write_text("Changed synthetic rule.\n", encoding="utf-8")
        result = self.check()
        self.assertEqual(result["status"], "PARTIAL_INVALIDATION")
        self.assertIn("dependent.md", result["reanalyze"])
        self.assertIn("TRANSITIVE_DEPENDENT_INVALIDATED", result["reason_codes"])

    def test_instruction_change_is_full_miss(self):
        self.record()
        with (self.root / "AGENTS.md").open("a", encoding="utf-8") as handle:
            handle.write("Additional instruction.\n")
        self.assertEqual(self.check()["status"], "CACHE_MISS")

    def test_unknown_reference_is_miss(self):
        self.record()
        (self.root / "new-rule.md").write_text("New rule.\n", encoding="utf-8")
        (self.root / "rule.md").write_text("[Additional](new-rule.md)\n", encoding="utf-8")
        result = self.check()
        self.assertEqual(result["status"], "CACHE_MISS")
        self.assertIn("UNRESOLVED_REFERENCE", result["reason_codes"])

    def test_new_scoped_instruction_is_miss(self):
        scoped = self.root / "scope"
        scoped.mkdir()
        self.options = self.planner.make_options(self.root, scoped, codex_home=self.home,
                                                 fallback_filenames=(), project_doc_max_bytes=32768,
                                                 discovery_config_tag="synthetic-defaults")
        self.record()
        (scoped / "AGENTS.override.md").write_text("Scoped instruction.\n", encoding="utf-8")
        self.assertEqual(self.check()["status"], "CACHE_MISS")

    def test_scope_index_change_is_miss(self):
        self.record()
        self.scope["excluded_references"].append({"source": "rule.md", "target": "example.md", "classification": "product-reference"})
        self.index.write_text(json.dumps(self.scope), encoding="utf-8")
        result = self.check()
        self.assertEqual(result["status"], "CACHE_MISS")
        self.assertIn("DISCOVERY_CONFIGURATION_CHANGED", result["reason_codes"])

    def test_corrupt_record_is_miss(self):
        self.record()
        next(self.cache.rglob("*.json")).write_text("{}", encoding="utf-8")
        self.assertEqual(self.check()["status"], "CACHE_MISS")

    def test_changed_analyzed_snapshot_cannot_record(self):
        first = self.check()
        (self.root / "rule.md").write_text("Changed after analysis.\n", encoding="utf-8")
        result = self.check(expected_digest=first["snapshot_digest"])
        self.assertNotIn("recorded", result)
        self.assertIn("ANALYZED_SNAPSHOT_CHANGED", result["reason_codes"])
        self.assertFalse(self.cache.exists())

    def test_mutation_under_lock_cannot_record(self):
        first = adapter.capture(self.planner, self.options, self.index)
        (self.root / "rule.md").write_text("Changed during record.\n", encoding="utf-8")
        second = adapter.capture(self.planner, self.options, self.index)
        with patch.object(adapter, "capture", side_effect=[first, second]):
            result = self.check(expected_digest=first.record["record_digest"])
        self.assertNotIn("recorded", result)
        self.assertFalse(list(self.cache.rglob("*.json")))
        self.assertFalse(list(self.cache.rglob("*.lock")))

    def test_unknown_lock_is_preserved(self):
        first = self.check()
        snapshot = adapter.capture(self.planner, self.options, self.index)
        path = self.planner.cache_record_path(self.cache, snapshot.record)
        path.parent.mkdir(parents=True)
        lock = path.with_suffix(path.suffix + ".lock")
        lock.write_text("", encoding="utf-8")
        with self.assertRaises(self.planner.CacheError):
            self.check(expected_digest=first["snapshot_digest"], lock_timeout=0)
        self.assertTrue(lock.exists())
        self.assertFalse(path.exists())

    def test_records_are_content_free(self):
        self.record()
        text = next(self.cache.rglob("*.json")).read_text(encoding="utf-8")
        self.assertNotIn(str(self.root), text)
        self.assertNotIn("Synthetic rule payload", text)
        valid, reason = self.planner._validate_record_shape(json.loads(text))
        self.assertTrue(valid, reason)


class SessionContracts(unittest.TestCase):
    setUp = CacheContracts.setUp
    git = CacheContracts.git

    def session_setup(self):
        for name in (adapter.SESSION_RUNTIME, "Code/Tools/Rule_Context_Cache.py"):
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / name, path)
        (self.root / "independent.md").write_text("Independent synthetic rule.\n", encoding="utf-8")
        (self.root / "optional.md").write_text("Optional synthetic contract.\n", encoding="utf-8")
        self.scope = {"schema_version": 2, "profile": "development",
                      "discovery_sources": ["AGENTS.md", "rule.md", "dependent.md", "independent.md", "optional.md"],
                      "scopes": {"development": ["AGENTS.md", "dependent.md", "independent.md"],
                                 "optional": ["AGENTS.md", "optional.md"]},
                      "semantic_dependencies": {"AGENTS.md": [], "rule.md": ["AGENTS.md"],
                                                "dependent.md": ["rule.md"], "independent.md": ["AGENTS.md"],
                                                "optional.md": ["AGENTS.md"]}, "excluded_references": []}
        self.index.write_text(json.dumps(self.scope), encoding="utf-8")
        self.session = adapter.SessionRuleContext(self.root)
        self.binding = dict(repository_identity="synthetic-repository", authority_key="a" * 64,
                            discovery_complete=True)

    def snapshot(self, root=None, **changes):
        return self.session.capture(root or self.root, **{**self.binding, **changes})

    def analyze(self):
        snapshot = self.snapshot()
        analyses = {p: {"synthetic_analysis": p} for p in snapshot["analysis_keys"]}
        self.session.acknowledge(snapshot, analyses)
        return snapshot

    def test_default_needs_no_persistent_planner_or_record(self):
        self.session_setup()
        (self.root / adapter.PLANNER).unlink()
        first = self.analyze()
        self.assertEqual(self.session.check(self.snapshot())["status"], "REUSE")
        self.assertEqual(self.session.analysis_for(first, "rule.md"), {"synthetic_analysis": "rule.md"})
        self.assertNotIn("optional.md", first["analysis_keys"])
        self.assertNotIn(adapter.INDEX, first["analysis_keys"])
        self.assertNotIn(adapter.SESSION_RUNTIME, first["analysis_keys"])
        self.assertNotIn("Code/Tools/Rule_Context_Cache.py", first["analysis_keys"])
        self.assertFalse(self.cache.exists())
        self.assertFalse(list(self.root.rglob("__pycache__")))

    def test_commit_and_equivalent_worktree_rebind_preserve_session_analysis(self):
        self.session_setup()
        self.analyze()
        self.git("add", ".")
        self.git("-c", "user.name=Synthetic Test", "-c", "user.email=synthetic.invalid",
                 "commit", "--quiet", "-m", "Synthetic scope update")
        self.assertEqual(self.session.check(self.snapshot())["status"], "REUSE")
        other = Path(self.temp.name) / "other-worktree"
        self.git("worktree", "add", "--detach", "--quiet", str(other), "HEAD")
        self.assertEqual(self.session.check(self.snapshot(other))["status"], "REUSE")
        options = self.planner.make_options(other, other, codex_home=self.home,
                                           fallback_filenames=(), project_doc_max_bytes=32768,
                                           discovery_config_tag="synthetic-defaults")
        persistent = adapter.operate(self.planner, options, self.cache, other / adapter.INDEX)
        self.assertEqual(persistent["status"], "CACHE_MISS")

    def test_dirty_rule_invalidates_only_transitive_dependents(self):
        self.session_setup()
        self.analyze()
        (self.root / "rule.md").write_text("Changed synthetic rule.\n", encoding="utf-8")
        plan = self.session.check(self.snapshot())
        self.assertEqual(plan["status"], "PARTIAL")
        self.assertIn("rule.md", plan["reread"])
        self.assertIn("dependent.md", plan["reread"])
        self.assertIn("independent.md", plan["reuse"])

    def test_authority_scope_and_repository_changes_require_reading(self):
        self.session_setup()
        self.analyze()
        for changes in ({"authority_key": "b" * 64}, {"scope": "optional"},
                        {"repository_identity": "other-repository"}):
            self.assertEqual(self.session.check(self.snapshot(**changes))["status"], "READ")
        (self.root / "AGENTS.md").write_text("Changed synthetic instructions.\n", encoding="utf-8")
        plan = self.session.check(self.snapshot())
        self.assertTrue({"AGENTS.md", "rule.md", "dependent.md", "independent.md"}.issubset(plan["reread"]))
        # The caller also supplies a freshly rebound native authority digest.
        self.assertEqual(self.session.check(self.snapshot(authority_key="c" * 64))["status"], "READ")

    def test_unknown_discovery_and_new_session_cannot_invent_analysis(self):
        self.session_setup()
        snapshot = self.analyze()
        unknown = self.snapshot(discovery_complete=False)
        self.assertEqual(self.session.check(unknown)["reason"], "DISCOVERY_INCOMPLETE")
        self.assertEqual(self.session.check(unknown)["reuse"], [])
        with self.assertRaises(ValueError):
            self.session.acknowledge(unknown, {"rule.md": "synthetic analysis"})
        fresh = adapter.SessionRuleContext(self.root)
        self.assertEqual(fresh.check(snapshot)["status"], "READ")

    def test_new_reference_and_incomplete_dependency_inventory_fail_closed(self):
        self.session_setup()
        self.analyze()
        (self.root / "new.md").write_text("New synthetic rule.\n", encoding="utf-8")
        (self.root / "rule.md").write_text("[New](new.md)\n", encoding="utf-8")
        with self.assertRaises(ValueError):
            self.snapshot()
        self.scope["semantic_dependencies"]["rule.md"] = ["new.md"]
        self.index.write_text(json.dumps(self.scope), encoding="utf-8")
        with self.assertRaises(ValueError):
            self.snapshot()

    def test_new_inline_rule_reference_fails_closed(self):
        self.session_setup()
        self.analyze()
        (self.root / "new.md").write_text("New synthetic rule.\n", encoding="utf-8")
        (self.root / "rule.md").write_text("Follow `new.md`.\n", encoding="utf-8")
        with self.assertRaises(ValueError):
            self.snapshot()

    def test_project_normative_dependencies_invalidate_consumers(self):
        self.session_setup()
        index = json.loads((ROOT / adapter.INDEX).read_bytes())
        cases = [
            ("sql-development", "Documentation/Quality/CI_Test_Strategy.md", "Documentation/Quality/CI_Impact_Selection.md"),
            ("planning", "Metadata/Governance/Artifact_Registry.json", "AI_Metadata/ARTIFACT_IDENTITY_AND_NOMENCLATURE.md"),
            ("planning", "AI_Metadata/Internal_Documentation/Quality/Next_Steps.md", "AI_Metadata/Internal_Documentation/Architecture/Long_Term_Development_Roadmap.md"),
            ("foundation-upgrade", ".ai/foundation/feature_catalog.json", ".ai/foundation/SEMANTIC_INTEGRATION_POLICY.md"),
        ]
        for scope, changed, consumer in cases:
            with self.subTest(scope=scope, consumer=consumer):
                _, graph = adapter.selected_scope(index, scope)
                synthetic = Path(self.temp.name) / scope
                for source in graph:
                    path = synthetic / source
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_text("Synthetic scope rule.\n", encoding="utf-8")
                binding = dict(repository_identity="synthetic-repository", authority_key="a" * 64,
                               scope_key=scope, discovery_complete=True)
                before = self.session.runtime.capture_context(synthetic, graph, **binding)
                context = self.session.runtime.SessionContext()
                context.acknowledge(before, {p: "Synthetic analysis" for p in graph})
                (synthetic / changed).write_text("Changed synthetic governing rule.\n", encoding="utf-8")
                after = self.session.runtime.capture_context(synthetic, graph, **binding)
                self.assertIn(consumer, context.check(after)["reread"])
    def test_changed_snapshot_cannot_acknowledge_analysis(self):
        self.session_setup()
        snapshot = self.snapshot()
        (self.root / "rule.md").write_text("Changed after reading.\n", encoding="utf-8")
        with self.assertRaises(ValueError):
            self.session.acknowledge(snapshot, {"rule.md": "synthetic analysis"})

    def test_persistent_v2_selects_dependencies_without_optional_contracts(self):
        self.session_setup()
        result = adapter.operate(self.planner, self.options, self.cache, self.index)
        self.assertNotIn("optional.md", result["analysis_keys"])
        self.assertIn("rule.md", result["analysis_keys"])
        self.assertNotIn("UNRESOLVED_REFERENCE", result["reason_codes"])
        recorded = adapter.operate(self.planner, self.options, self.cache, self.index,
                                   expected_digest=result["snapshot_digest"])
        self.assertTrue(recorded["recorded"])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository-root", type=Path, default=ROOT)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        suite = unittest.TestSuite(unittest.defaultTestLoader.loadTestsFromTestCase(cls)
                                   for cls in (CacheContracts, SessionContracts))
        result = unittest.TextTestRunner(verbosity=2).run(suite)
        return 0 if result.wasSuccessful() else 1
    adapter.load_planner(args.repository_root.resolve())
    index = json.loads((args.repository_root / adapter.INDEX).read_text(encoding="utf-8"))
    sources = index.get("discovery_sources", index.get("sources", []))
    if index["profile"] != "development" or not all((args.repository_root / path).is_file() for path in sources):
        raise ValueError("invalid repository scope")
    for scope in index.get("scopes", {"development": []}):
        selected, _ = adapter.selected_scope(index, scope)
        if index["schema_version"] == 2:
            adapter.validate_session_links(args.repository_root, selected, index)
    print("Rule-context cache repository contract passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
