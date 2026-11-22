#!/usr/bin/env python3
"""Deterministic CLI fixture; real subprocesses exercise Plenary's callbacks."""
import json
import os
import sys
from pathlib import Path

root = Path(os.environ['ZOXIDE_TEST_ROOT'])
args = sys.argv[1:]
with (root / 'calls.jsonl').open('a') as log:
    log.write(json.dumps(args) + '\n')

if args[0] == 'add':
    if Path(args[1]).name == 'add-fail':
        print('fixture: cannot write zoxide database', file=sys.stderr)
        sys.exit(1)
    sys.exit(0)

query = args[-1]
if query == 'missing':
    print('fixture: no matching directory', file=sys.stderr)
    sys.exit(1)
if query == 'empty':
    sys.exit(0)

names = ['alpha', 'beta'] if query == 'multi' else ['alpha']
for index, name in enumerate(names):
    path = str(root / name)
    print(f'{10 - index}.0 {path}' if '--score' in args else path)
