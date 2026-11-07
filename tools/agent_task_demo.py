"""Isolated workflow fixture: real processes/checks; explicitly simulated repair reasoning."""
import argparse
import ast
import json
from pathlib import Path
import subprocess
import sys
import time

HERE = Path(__file__).resolve()


def make_task(directory, mode='repair', native=None):
    """Create a disposable wrong-answer task with a verifier outside the worker's edit scope."""
    directory.mkdir(parents=True, exist_ok=True)
    workspace = directory / 'workspace'
    workspace.mkdir()
    (workspace / 'answer.py').write_text('def answer():\n    return 0\n', encoding='utf-8')
    worker = {'kind': 'codex', 'executable': native} if native else {
        'kind': 'simulation', 'argv': ['{python}', str(HERE), 'worker', mode, '{request}', '{report}']}
    task = dict(objective='Make answer() return the integer 42 in the isolated fixture.',
                acceptance=['answer.py defines only a zero-argument answer function returning literal 42.',
                            'The protected verifier succeeds; no files outside the edit scope change.'],
                workspace=str(workspace), mutable_paths=['answer.py'], protected_files=[str(HERE)],
                checks=[{'id': 'answer-is-42', 'argv': ['{python}', str(HERE), 'verify']}],
                worker=worker, limits=dict(attempts=3, runtime_seconds=30, worker_seconds=5,
                                           check_seconds=3, no_progress=2))
    path = directory / 'objective.json'
    path.write_text(json.dumps(task, indent=2) + '\n', encoding='utf-8')
    return path


def verify():
    """Check the tiny fixture's structure and literal result without executing worker-written code."""
    try:
        tree = ast.parse(Path('answer.py').read_text(encoding='utf-8'))
        function, = tree.body
        statement, = function.body
        valid = (isinstance(function, ast.FunctionDef) and function.name == 'answer' and
                 not function.args.args and not function.args.posonlyargs and
                 not function.args.kwonlyargs and not function.args.vararg and
                 not function.args.kwarg and not function.decorator_list and
                 isinstance(statement, ast.Return))
        value = ast.literal_eval(statement.value) if valid else None
        if type(value) is int and value == 42:
            print('PASS: answer() returns literal integer 42')
            return 0
        print(f'FAIL: expected 42, got {value!r}')
    except (OSError, SyntaxError, ValueError, TypeError, AttributeError):
        print('FAIL: expected exactly def answer(): return 42')
    return 1


def worker(mode, request_path, report_path):
    """Supply deterministic repairs or failure injection; this is not a model-quality evaluation."""
    request = json.loads(Path(request_path).read_text(encoding='utf-8'))
    answer = Path('answer.py')
    if mode == 'repair':
        failures = '\n'.join(Path(r['command']['stdout']).read_text(encoding='utf-8')
                             for r in request['verification'])
        value = 42 if 'expected 42, got 41' in failures else 41
        answer.write_text(f'def answer():\n    return {value}\n', encoding='utf-8')
    elif mode in ('sleep', 'crash'):
        if mode == 'crash':
            answer.write_text('def answer():\n    return 42\n', encoding='utf-8')
        counter = Path('logs/worker-count.txt')
        counter.parent.mkdir(exist_ok=True)
        count = int(counter.read_text()) if counter.exists() else 0
        counter.write_text(str(count + 1))
        subprocess.Popen([sys.executable, str(HERE), 'descendant'])
        Path('logs/worker-started').touch()
        time.sleep(20)
    elif mode == 'tamper':
        Path(request['protected_files'][0]).write_text('changed', encoding='utf-8')
    elif mode == 'weaken':
        Path(request['verification'][0]['command']['argv'][1]).write_text('raise SystemExit(0)\n')
    elif mode == 'outside':
        Path('outside.txt').write_text('Out of scope', encoding='utf-8')
    report = dict(status='ready', changes=f'Simulation mode: {mode}', evidence='Controller verifies independently',
                  next_action='Run the fixed verifier', blocker='')
    Path(report_path).write_text(json.dumps(report), encoding='utf-8')
    return 0


def main():
    """Expose fixture preparation, an immutable check, simulation workers and descendant probes."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['prepare', 'verify', 'worker', 'descendant'])
    parser.add_argument('values', nargs='*')
    args = parser.parse_args()
    if args.action == 'verify':
        return verify()
    if args.action == 'worker':
        return worker(*args.values)
    if args.action == 'descendant':
        time.sleep(2)
        Path('logs/escaped-child').touch()
        return 0
    print(make_task(Path(args.values[0]).resolve()))
    return 0


if __name__ == '__main__':
    sys.exit(main())
