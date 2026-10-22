#!/usr/bin/env python3
"""Verify the commit, canonical installers and privacy of a release ZIP."""
from __future__ import annotations

import argparse
import csv
import hashlib
import importlib.util
import io
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import tempfile
import unittest
import zipfile

INSTALLERS = (
    'Install_All.generated.sql', 'Deploy_All.generated.sql',
    'Install_ExecutionPlanAnalysis.generated.sql',
    'Install_SnapshotBaseline_Target.generated.sql',
    'Install_SnapshotBaseline_Framework.generated.sql',
)
GENERATED = tuple('Code/Install/generated/'+name for name in INSTALLERS)
MAX_ZIP_BYTES = 128 * 1024 * 1024
MAX_EXPANDED_BYTES = 512 * 1024 * 1024


def fail(code):
    raise ValueError(code)


def archive_files(archive):
    if sum(item.file_size for item in archive.infolist()) > MAX_EXPANDED_BYTES:
        fail('RELEASE_EXPANDED_SIZE')
    if len(archive.infolist()) > 10000:
        fail('RELEASE_ENTRY_COUNT')
    files, seen, roots = {}, set(), set()
    for item in archive.infolist():
        name = item.filename
        parts = PurePosixPath(name).parts
        if (not parts or '\\' in name or ':' in name or name.startswith('/') or
                '..' in parts or (item.external_attr >> 16) & 0o170000 == 0o120000):
            fail('RELEASE_UNSAFE_PATH')
        key = name.rstrip('/').casefold()
        if key in seen:
            fail('RELEASE_DUPLICATE_PATH')
        seen.add(key)
        roots.add(parts[0])
        if '.git' in parts or '__pycache__' in parts:
            fail('RELEASE_LOCAL_FILE')
        if not item.is_dir():
            if len(parts) < 2:
                fail('RELEASE_ROOT_INVALID')
            files[PurePosixPath(*parts[1:]).as_posix()] = archive.read(item)
    if len(roots) != 1:
        fail('RELEASE_ROOT_INVALID')
    return roots.pop(), files


def canonical_installers(root):
    """Regenerate only SQL text; this function never connects to SQL Server."""
    with tempfile.TemporaryDirectory(prefix='sql-analyze-release-check-') as directory:
        destination = Path(directory)
        jobs = [
            ('Build-StandaloneInstaller.ps1', ['-OutputPath', str(destination/INSTALLERS[0])]),
            ('Build-DeploymentInstaller.ps1', ['-OutputPath', str(destination/INSTALLERS[1]),
                                             '-PythonExecutable', sys.executable]),
            ('Build-ExecutionPlanAnalysisInstaller.ps1', ['-OutputPath', str(destination/INSTALLERS[2])]),
            ('Build-SnapshotBaselineInstallers.ps1', ['-OutputDirectory', str(destination)]),
        ]
        for name, arguments in jobs:
            result = subprocess.run(['pwsh', '-NoProfile', '-File', str(root/'Code/Install'/name),
                                     '-RepositoryRoot', str(root), *arguments],
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)
            if result.returncode:
                fail('RELEASE_CANONICAL_BUILD_FAILED')
        # Release artifacts use UTF-8 without BOM and LF on every build host.
        return {path: (destination/Path(path).name).read_text(encoding='utf-8-sig').encode('utf-8')
                for path in GENERATED}


def check_contents(files, expected_sources, generated, commit, tree, root_name):
    try:
        metadata = json.loads(files['RELEASE.json'])
    except (KeyError, ValueError, UnicodeError):
        fail('RELEASE_METADATA_INVALID')
    version = metadata.get('framework_version', '')
    if not re.fullmatch(r'\d+\.\d+\.\d+', version) or root_name != 'SQL_Server_Analyze-'+version:
        fail('RELEASE_VERSION_INVALID')
    if metadata.get('source_commit') != commit or metadata.get('source_tree') != tree:
        fail('RELEASE_SOURCE_BINDING')
    if (metadata.get('schema_version') != 1 or metadata.get('contract_version') != '1.24' or
            metadata.get('minimum_product_major_version') != 15 or
            metadata.get('supported_product_major_versions') != [15, 16, 17] or
            metadata.get('build_number_restriction') is not False or
            metadata.get('generated_installers') != list(INSTALLERS)):
        fail('RELEASE_METADATA_CONTRACT')
    if set(files) != set(expected_sources) | set(GENERATED) | {'RELEASE.json'}:
        fail('RELEASE_FILE_SET')
    for path, content in expected_sources.items():
        if files[path] != content:
            fail('RELEASE_SOURCE_CHANGED')
    for path in GENERATED:
        if files[path] != generated[path]:
            fail('RELEASE_INSTALLER_CHANGED')
    source = files['Code/01_Common/077_FrameworkVersion.sql'].decode('utf-8-sig')
    if "[FrameworkVersion]='"+version+"'" not in source:
        fail('RELEASE_VERSION_MISMATCH')
    inventory = list(csv.DictReader(io.StringIO(files['Metadata/Inventory/Objects.csv'].decode('utf-8-sig'))))
    snapshot = sum(row['SourcePath'].startswith('Code/10_SnapshotBaseline/') for row in inventory)
    if (metadata.get('object_count') != len(inventory) or
            metadata.get('snapshot_object_count') != snapshot or
            metadata.get('core_object_count') != len(inventory)-snapshot or
            any(row['SourcePath'] not in files for row in inventory)):
        fail('RELEASE_INVENTORY')
    return metadata


def verify_archive(root, archive_path, expected_commit=None):
    root = Path(root).resolve()
    commit = subprocess.check_output(['git', '-C', str(root), 'rev-parse', '--verify',
                                      (expected_commit or 'HEAD')+'^{commit}'], text=True).strip()
    tree = subprocess.check_output(['git', '-C', str(root), 'rev-parse', commit+'^{tree}'], text=True).strip()
    if not re.fullmatch(r'[0-9a-f]{40}', commit):
        fail('RELEASE_COMMIT_INVALID')
    if Path(archive_path).stat().st_size > MAX_ZIP_BYTES:
        fail('RELEASE_ZIP_SIZE')
    reference = subprocess.check_output(['git', '-C', str(root), 'archive', '--format=zip', commit])
    with zipfile.ZipFile(io.BytesIO(reference)) as original:
        sources = {item.filename: original.read(item) for item in original.infolist() if not item.is_dir()}
    with zipfile.ZipFile(archive_path) as archive:
        root_name, files = archive_files(archive)
    # Build the reference from the exported commit, never from dirty/untracked files.
    with tempfile.TemporaryDirectory(prefix='sql-analyze-release-source-') as directory:
        reference_root = Path(directory)
        with zipfile.ZipFile(io.BytesIO(reference)) as original:
            original.extractall(reference_root)
        generated = canonical_installers(reference_root)
    metadata = check_contents(files, sources, generated, commit, tree, root_name)
    return metadata, {path: files[path] for path in GENERATED}


def privacy_module(root):
    specification = importlib.util.spec_from_file_location(
        'release_privacy', root/'Code/Tests/Static/910_Validate_Repository_Privacy.py')
    module = importlib.util.module_from_spec(specification)
    sys.modules[specification.name] = module
    specification.loader.exec_module(module)
    return module


def validate_privacy(root, archive_path, metadata, verified):
    privacy = privacy_module(root)
    allowed, findings = privacy.load_allowlist(root/'Metadata/Quality/Repository_Privacy_Allowlist.csv')
    repository_findings, _ = privacy.scan_repository(root, allowed)
    if findings or repository_findings:
        fail('RELEASE_SOURCE_PRIVACY')
    archive_findings, _ = privacy.scan_archive(archive_path, allowed,
        verified_installers=verified, expected_root='SQL_Server_Analyze-'+metadata['framework_version'])
    if archive_findings:
        privacy.report(archive_findings, 'RELEASE_ZIP', 1)
        fail('RELEASE_ARCHIVE_PRIVACY')


class PackageContracts(unittest.TestCase):
    def fixture(self):
        commit, tree = 'a'*40, 'b'*40
        sources = {
            'README.md': b'License notice preserved\n', 'LICENSE.md': b'Synthetic license\n',
            'Code/01_Common/077_FrameworkVersion.sql': b"SET [FrameworkVersion]='1.1.0';",
            'Metadata/Inventory/Objects.csv': b'ObjectType,ObjectName,SourcePath\nTABLE,Example,Code/01_Common/077_FrameworkVersion.sql\n',
        }
        generated = {name: b'USE [DeineDatenbank];\nGO\n' for name in GENERATED}
        metadata = dict(schema_version=1, framework_version='1.1.0', contract_version='1.24',
            source_commit=commit, source_tree=tree, minimum_product_major_version=15,
            supported_product_major_versions=[15, 16, 17], build_number_restriction=False,
            object_count=1, core_object_count=1, snapshot_object_count=0,
            generated_installers=list(INSTALLERS))
        files = {**sources, **generated, 'RELEASE.json': json.dumps(metadata).encode()}
        return files, sources, generated, commit, tree

    def test_complete_package_and_changed_sources(self):
        files, sources, generated, commit, tree = self.fixture()
        self.assertEqual(check_contents(files, sources, generated, commit, tree,
                                        'SQL_Server_Analyze-1.1.0')['object_count'], 1)
        mutations = [
            ('missing source', lambda f: f.pop('LICENSE.md')),
            ('missing installer', lambda f: f.pop(GENERATED[0])),
            ('local file', lambda f: f.update({'local.log': b'synthetic'})),
            ('changed license', lambda f: f.update({'LICENSE.md': b'changed'})),
            ('changed installer', lambda f: f.update({GENERATED[0]: b'changed'})),
            ('changed installer EOL', lambda f: f.update({GENERATED[0]: f[GENERATED[0]].replace(b'\n', b'\r\n')})),
            ('invalid metadata', lambda f: f.update({'RELEASE.json': b'{}'})),
        ]
        for label, mutate in mutations:
            with self.subTest(label=label):
                candidate = dict(files)
                mutate(candidate)
                with self.assertRaises(ValueError):
                    check_contents(candidate, sources, generated, commit, tree, 'SQL_Server_Analyze-1.1.0')

    def test_source_commit_version_and_build_restriction(self):
        files, sources, generated, commit, tree = self.fixture()
        for key, value in [('source_commit', 'c'*40), ('framework_version', '1.1.1'),
                           ('build_number_restriction', True), ('object_count', 2)]:
            with self.subTest(key=key):
                metadata = json.loads(files['RELEASE.json'])
                metadata[key] = value
                candidate = dict(files, **{'RELEASE.json': json.dumps(metadata).encode()})
                with self.assertRaises(ValueError):
                    check_contents(candidate, sources, generated, commit, tree, 'SQL_Server_Analyze-1.1.0')

    def test_unsafe_and_duplicate_zip_entries(self):
        for names in [('root/../escape.sql',), ('root/a.sql', 'root/A.sql'),
                      ('root/.git/config',), ('other/a.sql', 'root/b.sql')]:
            with self.subTest(names=names):
                output = io.BytesIO()
                with zipfile.ZipFile(output, 'w') as archive:
                    for name in names:
                        archive.writestr(name, b'synthetic')
                with zipfile.ZipFile(io.BytesIO(output.getvalue())) as archive:
                    with self.assertRaises(ValueError):
                        archive_files(archive)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repository-root', type=Path, default=Path(__file__).resolve().parents[3])
    parser.add_argument('--archive', type=Path)
    parser.add_argument('--expected-commit')
    parser.add_argument('--self-test', action='store_true')
    arguments = parser.parse_args()
    if arguments.self_test:
        result = unittest.TextTestRunner(verbosity=1).run(unittest.defaultTestLoader.loadTestsFromTestCase(PackageContracts))
        return 0 if result.wasSuccessful() else 1
    if arguments.archive:
        metadata, verified = verify_archive(arguments.repository_root, arguments.archive, arguments.expected_commit)
        validate_privacy(arguments.repository_root.resolve(), arguments.archive.resolve(), metadata, verified)
        digest = hashlib.sha256(arguments.archive.read_bytes()).hexdigest()
        sidecar = Path(str(arguments.archive)+'.sha256').read_text().strip()
        if sidecar != digest+'  '+arguments.archive.name:
            fail('RELEASE_CHECKSUM')
        print('Release package validated: version='+metadata['framework_version']+
              ' objects='+str(metadata['object_count'])+' source='+metadata['source_commit'])
        return 0
    # This explicit source check does not build a ZIP. The package workflow
    # invokes this validator's self-tests and actual archive verification.
    root = arguments.repository_root
    builder = (root/'Code/Install/Build-ReleasePackage.ps1').read_text(encoding='utf-8-sig')
    workflow = (root/'.github/workflows/release-native-matrix.yml').read_text(encoding='utf-8-sig')
    if 'git -C $RepositoryRoot archive' not in builder or 'Build-ReleasePackage.ps1' not in workflow:
        fail('RELEASE_BUILD_DISCOVERY')
    print('Release package source contract validated.')
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (ValueError, OSError, subprocess.SubprocessError, zipfile.BadZipFile) as error:
        print('Release package validation failed: '+str(error).splitlines()[0][:160], file=sys.stderr)
        raise SystemExit(1)
