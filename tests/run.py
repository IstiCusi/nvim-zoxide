#!/usr/bin/env python3
"""Run the real plugin with Plenary jobs and a deterministic CLI subprocess."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('--nvim', required=True, type=Path)
parser.add_argument('--plenary', required=True, type=Path)
parser.add_argument('--telescope', type=Path)
parser.add_argument('--plugin', type=Path, help='Optional original checkout for failure reproduction')
parser.add_argument('--report', required=True, type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
plugin = (args.plugin or root).resolve()
output = args.report.resolve()
output.parent.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix='zoxide-regression-') as temporary:
    temporary = Path(temporary)
    for name in ('alpha', 'beta', 'add-fail'):
        (temporary / name).mkdir()
    (temporary / 'calls.jsonl').touch()
    fixture = temporary / 'zoxide-fixture'
    shutil.copy2(root / 'tests/fixture.py', fixture)
    fixture.chmod(0o755)
    options = {'plugin': str(plugin), 'plenary': str(args.plenary.resolve()),
               'fixture': str(fixture), 'output': str(output)}
    if args.telescope:
        options['telescope'] = str(args.telescope.resolve())
    env = os.environ.copy()
    env['ZOXIDE_TEST_ROOT'] = str(temporary)
    env['ZOXIDE_TEST_OPTIONS'] = json.dumps(options)
    env.pop('NVIM_APPNAME', None)
    for kind in ('CONFIG', 'DATA', 'STATE', 'CACHE'):
        env['XDG_' + kind + '_HOME'] = str(temporary / kind.lower())
    result = subprocess.run([str(args.nvim.resolve()), '--headless', '-u', 'NONE', '-i', 'NONE',
                             '-l', str(root / 'tests/regression.lua')], env=env, cwd=temporary,
                            capture_output=True, text=True, timeout=90)
    print(result.stdout, end='')
    print(result.stderr, end='')
    if output.exists():
        report = json.loads(output.read_text())
        report['source_sha256'] = hashlib.sha256((plugin / 'lua/zoxide/init.lua').read_bytes()).hexdigest()
        report['cli'] = 'Deterministic Python subprocess fixture; not the real zoxide database'
        report['telescope_tested'] = bool(args.telescope)
        report['dependency_commits'] = {}
        for name, path in [('plenary', args.plenary), ('telescope', args.telescope)]:
            if path:
                revision = subprocess.run(['git', '-C', str(path.resolve()), 'rev-parse', 'HEAD'],
                                          capture_output=True, text=True)
                if revision.returncode == 0:
                    report['dependency_commits'][name] = revision.stdout.strip()
        output.write_text(json.dumps(report, indent=2) + '\n')
        print(f"{'PASS' if report['passed'] else 'FAIL'}: {len(report['checks'])} checks; {report['nvim']}")
    raise SystemExit(result.returncode)
