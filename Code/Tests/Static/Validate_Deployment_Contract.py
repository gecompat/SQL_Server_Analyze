#!/usr/bin/env python3
"""Exercise the source-derived deployment grammar and fail-closed contracts."""
from __future__ import annotations
import argparse
import importlib.util
import re
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('deployment_generator', ROOT / 'Code/Install/deployment_generator.py')
generator = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = generator
spec.loader.exec_module(generator)


class DeploymentContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sql, cls.info = generator.generate(ROOT, True)

    def test_source_closure_and_receipts(self):
        self.assertEqual((195, 20, 7), tuple(self.info[k] for k in ('sources', 'tables', 'archives')))
        self.assertIn('NEWID()', self.sql)
        self.assertTrue("N''State_''" in self.sql)
        self.assertIn('AS [rowCount]', self.sql)
        self.assertIn('identityLastValue', self.sql)
        self.assertTrue('parentColumnName' in self.sql)
        self.assertIn('FOR JSON PATH,INCLUDE_NULL_VALUES', self.sql)

    def test_stored_module_header_matches_native_representation(self):
        source="/* CREATE OR ALTER stays in comments */\nCREATE OR ALTER PROCEDURE [snapshot].[ExampleProbe] AS SELECT N'CREATE OR ALTER';"
        expected="/* CREATE OR ALTER stays in comments */\nCREATE   PROCEDURE [snapshot].[ExampleProbe] AS SELECT N'CREATE OR ALTER';"
        self.assertEqual(expected, generator.stored_module_definition(source))
        with self.assertRaises(generator.BuildError):
            generator.stored_module_definition("SELECT N'CREATE OR ALTER PROCEDURE';")

    def test_wait_seed_guard_rejects_persistent_or_hidden_mutations(self):
        sources,_,_=generator.load_sources(ROOT,True)
        seed=next(s for s in sources if s.path.endswith('075_CompleteWaitStatsInstallation.sql'))
        guard=generator.snapshot_wait_seed_preflight(sources)
        self.assertIn('Waitmetrik',guard)
        for text in (
            seed.text.replace('-- SNAPSHOT_WAIT_SEED_CHECK_END',"UPDATE snapshot.CollectorPolicy SET IsEnabled=1;\n-- SNAPSHOT_WAIT_SEED_CHECK_END"),
            seed.text.replace('INSERT @SnapshotWaitExpectedMetrics','INSERT [snapshot].[MetricDefinition]'),
            seed.text.replace('-- SNAPSHOT_WAIT_SEED_CHECK_BEGIN',"-- SNAPSHOT_WAIT_SEED_CHECK_BEGIN\nEXEC sys.sp_executesql N'SELECT 1';"),
            seed.text.replace('-- SNAPSHOT_WAIT_SEED_CHECK_BEGIN',"-- SNAPSHOT_WAIT_SEED_CHECK_BEGIN\n-- SNAPSHOT_WAIT_SEED_CHECK_BEGIN"),
        ):
            changed=generator.Source(seed.role,seed.path,text,seed.batches,seed.module)
            with self.assertRaises(generator.BuildError):
                generator.snapshot_wait_seed_preflight([changed if s is seed else s for s in sources])
        # Mutation verbs inside a description stay data, not executable tokens.
        described=generator.Source(seed.role,seed.path,seed.text.replace('Unveränderte native kumulative gesamte Waitzeit.', 'UPDATE DELETE EXEC are example text.'),seed.batches,seed.module)
        generator.snapshot_wait_seed_preflight([described if s is seed else s for s in sources])

    def test_lexer_preserves_literals_and_nested_comments(self):
        value = "SELECT N'first\nGO\nlast''value', [GO]; /* a /* GO */ b */\nGO -- actual\nSELECT 2;"
        batches = generator.split_batches(value)
        self.assertEqual(2, len(batches))
        self.assertIn("last''value", batches[0])
        for invalid in ("SELECT N'", '/* nested /* */', 'SELECT [broken', 'SELECT "quoted"'):
            with self.assertRaises(generator.BuildError):
                generator.tokens(invalid)
        with self.assertRaises(generator.BuildError):
            generator.split_batches('SELECT 1;\nGO 2\n')

    def test_caller_gate_precedes_own_transaction_settings(self):
        self.assertLess(self.sql.index('IF @@TRANCOUNT<>0'), self.sql.index('SET XACT_ABORT ON;'))
        self.assertIn('RAISERROR(', self.sql)
        self.assertIn('RETURN; END;', self.sql)
        self.assertNotIn("HAS_PERMS_BY_NAME(NULL,''SERVER''", self.sql)
        self.assertIn("HAS_PERMS_BY_NAME(NULL,NULL,''VIEW ANY DEFINITION'')", self.sql)

    def test_dml_archive_precedes_source_writes(self):
        self.assertLess(self.sql.index("DECLARE @RunName sysname=N''Run_''"), self.sql.index('-- BEGIN SOURCE: Code/01_Common/074a'))
        self.assertIn('TABLOCKX,HOLDLOCK', self.sql)
        self.assertIn('sp_getapplock', self.sql)
        self.assertTrue("@DbPrincipal=N''public''" in self.sql)
        metadata_lock=self.sql.index('Acquire the instance-wide tempdb metadata application lock')
        self.assertLess(self.sql.index('permission gate before locks'),metadata_lock)
        self.assertLess(metadata_lock,self.sql.index('Acquire the first database application lock'))
        self.assertIn("QUOTENAME(N'tempdb')",self.sql)
        self.assertIn('SQL_Server_Analyze.DeploymentFormat1.TempMetadata',self.sql)
        self.assertIn('Custom Wait source collides', self.sql)
        self.assertIn('sys.security_predicates', self.sql)
        self.assertIn('sys.server_triggers', self.sql)
        self.assertTrue('OPTION(MAXDOP 1)' in self.sql)
        self.assertTrue('CanonicalName,Definition' in self.sql)
        self.assertTrue('Canonical Wait seed key is missing after deployment' in self.sql)
        self.assertTrue("IF @@TRANCOUNT<>1 OR XACT_STATE()<>1" in self.sql)

    def test_ownership_conjunct_belongs_to_target(self):
        for value in ('[s].[IsFrameworkDefault]=1 AND ([x]=1 OR [x]=2)', '([s].[IsFrameworkDefault]=1) AND [x] BETWEEN 1 AND 2'):
            self.assertTrue(generator.owns_predicate(generator.tokens(value),'s'))
        for value in ('NOT [s].[IsFrameworkDefault]=1', '[c].[IsFrameworkDefault]=1', '[s].[IsFrameworkDefault]=1 OR [x]=1', '([s].[IsFrameworkDefault]=1 OR [x]=1)'):
            self.assertFalse(generator.owns_predicate(generator.tokens(value),'s'))

    def changed_source(self, relative, old, new, expected_failure=True):
        with tempfile.TemporaryDirectory(prefix='sqlsa-build-contract-') as folder:
            root = Path(folder)
            sources, _, _ = generator.load_sources(ROOT, True)
            paths = {x.path for x in sources} | {
                'Code/Install/Install_All.sql', 'Code/Install/Install_SnapshotBaseline_Target.sql',
                'Code/Install/Install_SnapshotBaseline_Framework.sql',
                'Code/Install/Build-DeploymentInstaller.ps1', 'Code/Install/deployment_generator.py'}
            for name in paths:
                target = root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / name, target)
            target = root / relative
            text = target.read_text(encoding='utf-8-sig')
            self.assertIn(old, text)
            target.write_text(text.replace(old, new, 1), encoding='utf-8')
            if expected_failure:
                with self.assertRaises(generator.BuildError):
                    generator.generate(root, True)
            else:
                _, result = generator.generate(root, True)
                self.assertNotEqual(self.info['digest'], result['digest'])

    def test_unknown_include_rejected(self):
        self.changed_source('Code/Install/Install_All.sql', ':ON ERROR EXIT', ':ON ERROR EXIT\n:r ../../outside.sql')

    def test_unowned_delete_rejected(self):
        self.changed_source('Code/01_Common/074e_WaitTypeCatalog_Analysis.sql', '[IsFrameworkDefault]=1 AND', '[IsFrameworkDefault]=0 OR')

    def test_missing_additive_contract_rejected(self):
        self.changed_source('Code/01_Common/074_WaitTypeCatalog.sql', 'ADD [DefaultAssessment]', 'ADD [UnexpectedAssessment]')

    def test_unsupported_ddl_rejected(self):
        self.changed_source('Code/01_Common/074e_WaitTypeCatalog_Analysis.sql', 'SET NOCOUNT ON;', 'SET NOCOUNT ON;\nTRUNCATE TABLE [monitor].[WaitTypeCatalog];')

    def test_dynamic_select_into_guard_rejected(self):
        self.changed_source('Code/01_Common/074a_WaitTypeCatalog_Seed_01.sql',
                            'IF EXISTS\n(\n    SELECT 1\n    FROM [monitor].[WaitTypeCatalogSource] AS [s]',
                            'IF 1=1 SELECT 1 AS Probe INTO [dbo].[UnclassifiedWrite];\nIF EXISTS\n(\n    SELECT 1\n    FROM [monitor].[WaitTypeCatalogSource] AS [s]')

    def test_static_select_into_rejected(self):
        self.changed_source('Code/01_Common/074e_WaitTypeCatalog_Analysis.sql',
                            'SET NOCOUNT ON;', 'SET NOCOUNT ON;\nSELECT 1 AS Probe INTO [dbo].[UnclassifiedWrite];')

    def test_nested_source_transaction_rejected(self):
        self.changed_source('Code/01_Common/074e_WaitTypeCatalog_Analysis.sql',
                            'SET NOCOUNT ON;', 'SET NOCOUNT ON;\nBEGIN TRANSACTION;')

    def test_actual_update_alias_target_rejected(self):
        self.changed_source('Code/01_Common/087b_ToolBackgroundQueryPattern_Seed.sql',
                            'FROM [monitor].[ToolBackgroundQueryPattern] AS [target]\nJOIN @Seed AS [source]',
                            'FROM [monitor].[ToolBackgroundQueryPattern] AS [unrelated]\nJOIN [dbo].[UnclassifiedRows] AS [target] ON 1=1\nJOIN @Seed AS [source]')

    def test_source_change_changes_receipt_digest(self):
        self.changed_source('Code/01_Common/074e_WaitTypeCatalog_Analysis.sql', 'SET NOCOUNT ON;', '-- fixture digest mutation\nSET NOCOUNT ON;', False)

    def test_snapshot_guard_and_transaction_boundaries(self):
        sources,tables,_=generator.load_sources(ROOT,True)
        source=next(s for s in sources if s.path==generator.SNAPSHOT_SCHEMA_SOURCE)
        original=(ROOT/source.path).read_text(encoding='utf-8-sig')
        clean,guard=generator.snapshot_guard_parts(original)
        self.assertEqual(guard,generator.snapshot_guard([t for t in tables if t.role=='SNAPSHOT'],[s for s in sources if s.role=='SNAPSHOT']))
        self.assertLess(clean.index(generator.SNAPSHOT_TX_BEGIN),clean.index(generator.SNAPSHOT_TX_END))
        for mutation in (original.replace(generator.SNAPSHOT_GUARD_BEGIN,'/*\n'+generator.SNAPSHOT_GUARD_BEGIN,1),
                         original.replace(generator.SNAPSHOT_GUARD_BEGIN,'prefix '+generator.SNAPSHOT_GUARD_BEGIN,1),
                         original+generator.SNAPSHOT_GUARD_END):
            with self.assertRaises(generator.BuildError):
                generator.snapshot_guard_parts(mutation)
        with self.assertRaises(generator.BuildError):
            generator.snapshot_transaction_spans(original.replace(generator.SNAPSHOT_TX_BEGIN,'/*\n'+generator.SNAPSHOT_TX_BEGIN,1),source.path)
        self.assertNotIn('-- Derived model SHA256:',self.sql)
        self.assertIn('Legacy Snapshot version after deployment',self.sql)
        classifier=generator.snapshot_state_classifier([t for t in tables if t.role=='SNAPSHOT'],[s for s in sources if s.role=='SNAPSHOT'])
        self.assertLess(classifier.index('WITH(TABLOCKX,HOLDLOCK)'),classifier.index('EXEC sys.sp_executesql'))

    def test_snapshot_target_has_one_aborting_compilation_envelope(self):
        sql,info=generator.generate_snapshot_target(ROOT)
        self.assertEqual(8,info['sources'])
        self.assertEqual(1,len(generator.split_batches(sql)))
        self.assertLess(sql.index('IF @@TRANCOUNT<>0'),sql.index('SET XACT_ABORT ON;'))
        self.assertLess(sql.index('BEGIN TRANSACTION;'),sql.index('-- BEGIN SOURCE:'))
        self.assertEqual(8,sql.count('-- BEGIN SOURCE:'))
        for setting in ('LOCK_TIMEOUT 0','ANSI_NULLS ON','QUOTED_IDENTIFIER ON','ANSI_PADDING ON','ANSI_WARNINGS ON','ARITHABORT ON','CONCAT_NULL_YIELDS_NULL ON','NUMERIC_ROUNDABORT OFF'):
            self.assertLess(sql.index('SET '+setting+';'),sql.index('-- BEGIN SOURCE:'))
        self.assertIn("BEGIN EXEC sys.sp_executesql N'SET XACT_ABORT OFF; RAISERROR(",sql)
        self.assertIn('IF XACT_STATE()<>0 ROLLBACK TRANSACTION;\nTHROW;',sql)

    def test_stale_snapshot_guard_is_rejected(self):
        self.changed_source(generator.SNAPSHOT_SCHEMA_SOURCE,'-- Derived model SHA256:','-- Changed model SHA256:')

    def test_unknown_snapshot_check_migration_is_rejected(self):
        self.changed_source(generator.SNAPSHOT_SCHEMA_SOURCE,'DROP CONSTRAINT [CK_snapshot_CollectorPolicy_CollectorCode]','DROP CONSTRAINT [CK_ExampleUnrecognized]')

    def test_native_snapshot_risk_selection_preserves_defaults(self):
        workflow=(ROOT/'.github/workflows/release-native-matrix.yml').read_text(encoding='utf-8-sig')
        names=('Run selected packaged deployment and preservation contracts','Run selected packaged Snapshot and concurrency contracts')
        for name in names:
            match=re.search(r'- name: '+re.escape(name)+r'\n\s+if: (.+)',workflow)
            self.assertIsNotNone(match)
            terms=match[1].split('||')
            self.assertEqual(['matrix.regex == true','inputs.snapshot_risk_gate',"inputs.qualification_scope == 'SNAPSHOT_SCHEMA_RISK'"],[t.strip() for t in terms])
            for version in ('2019','2022','2025'):
                for flag in (False,True):
                    for risk in (False,True):
                        values={'matrix.regex == true':version=='2025','inputs.snapshot_risk_gate':flag,"inputs.qualification_scope == 'SNAPSHOT_SCHEMA_RISK'":risk}
                        selected=any(values[t.strip()] for t in terms)
                        self.assertEqual(version=='2025' or flag or risk,selected)
        self.assertIn("if [ '${{ inputs.snapshot_risk_gate }}' = 'true' ] && [ '${{ inputs.target }}' = 'all' ]; then\n            echo 'Snapshot risk qualification requires one explicit native target.'\n            exit 1",workflow)
        self.assertIn("if [ '${{ matrix.version }}' = '2025' ] || [ '${{ inputs.snapshot_risk_gate }}' = 'true' ] || [ '${{ inputs.qualification_scope }}' = 'SNAPSHOT_SCHEMA_RISK' ]; then",workflow)
        for name in ('Run full release gate','Run native permission matrix'):
            self.assertIn('- name: '+name+"\n        if: inputs.qualification_scope == 'FULL_RELEASE'",workflow)
        self.assertIn('SET COMPATIBILITY_LEVEL=${{ matrix.compatibility }}',workflow)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--self-test', action='store_true')
    parser.add_argument('--repository-root')
    args=parser.parse_args()
    if args.self_test:
        assert len(generator.split_batches("SELECT N'GO';\nGO\nSELECT 2;"))==2
        assert not generator.owns_predicate(generator.tokens('NOT IsFrameworkDefault=1'),None)
        print('Deployment parser self-test passed.')
        return 0
    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(DeploymentContract))
    return 0 if result.wasSuccessful() else 1


if __name__ == '__main__':
    raise SystemExit(main())
