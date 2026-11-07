"""A bounded, manually launched project task loop around Codex's native sessions."""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import uuid

from agent_process import OwnedProcess

ROOT = Path(__file__).resolve().parents[1]
RUNS = ROOT / 'logs/agent-workflow'
DEFAULTS = dict(attempts=3, runtime_seconds=600, worker_seconds=120,
                check_seconds=30, no_progress=2)
TERMINAL = {'completed', 'failed', 'limit_reached'}
REPORT_SCHEMA = {
    'type': 'object', 'additionalProperties': False,
    'properties': {name: {'type': 'string'} for name in
                   ('status', 'changes', 'evidence', 'next_action', 'blocker')},
    'required': ['status', 'changes', 'evidence', 'next_action', 'blocker'],
}


def digest(path):
    """Fingerprint file bytes, including absence, without reading credentials into the record."""
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None


def write_json(path, value):
    """Atomically replace a durable JSON record on the same volume."""
    temp = path.with_suffix('.tmp')
    temp.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')
    for attempt in range(10):
        try:
            os.replace(temp, path)
            return
        except PermissionError:
            if attempt == 9:
                raise
            time.sleep(0.02)


def relative_path(value):
    """Reject absolute or escaping task paths before resolving them in a workspace."""
    path = Path(value)
    if not value or not path.parts or path.is_absolute() or '..' in path.parts or path.drive:
        raise ValueError(f'Expected a workspace-relative path: {value!r}')
    return path


def load_task(path):
    """Validate and freeze an explicit objective, machine checks, edit scope and finite limits."""
    task = json.loads(path.read_text(encoding='utf-8-sig'))
    if not isinstance(task, dict):
        raise ValueError('Objective JSON must be an object')
    for key in ('objective', 'acceptance', 'workspace', 'mutable_paths', 'checks'):
        if not task.get(key):
            raise ValueError(f'Task needs nonempty {key}')
    if (not isinstance(task['objective'], str) or not isinstance(task['acceptance'], list) or
            not all(isinstance(x, str) and x for x in task['acceptance'])):
        raise ValueError('Objective and acceptance criteria must be text')
    task['workspace'] = str(Path(task['workspace']).resolve())
    if not isinstance(task['mutable_paths'], list) or not isinstance(task['checks'], list):
        raise ValueError('mutable_paths and checks must be lists')
    for value in task['mutable_paths']:
        relative_path(value)
        (Path(task['workspace']) / value).resolve().relative_to(Path(task['workspace']))
    ids = set()
    for check in task['checks']:
        if not check.get('id') or check['id'] in ids:
            raise ValueError('Checks need unique nonempty IDs')
        ids.add(check['id'])
        if not isinstance(check.get('argv'), list) or not check['argv'] or not all(isinstance(a, str) for a in check['argv']):
            raise ValueError('Each check needs an argv list; shell commands are not supported')
    task['limits'] = DEFAULTS | task.get('limits', {})
    if set(task['limits']) != set(DEFAULTS):
        raise ValueError('Unknown limit; token and money caps are not supported')
    for key, value in task['limits'].items():
        if isinstance(value, bool) or not isinstance(value, (int, float)) or value <= 0:
            raise ValueError(f'{key} must be positive and finite')
        if not math.isfinite(value):
            raise ValueError(f'{key} must be finite')
    for key in ('attempts', 'no_progress'):
        if not isinstance(task['limits'][key], int):
            raise ValueError(f'{key} must be an integer')
    worker = task.setdefault('worker', {'kind': 'codex'})
    if worker['kind'] not in ('codex', 'simulation'):
        raise ValueError('Worker must be codex or explicitly labelled simulation')
    if worker['kind'] == 'simulation' and (not isinstance(worker.get('argv'), list) or
            not worker['argv'] or not all(isinstance(a, str) for a in worker['argv'])):
        raise ValueError('Simulation needs an argv list')
    workspace = Path(task['workspace'])
    if not isinstance(task.get('protected_files'), list) or not task['protected_files']:
        raise ValueError('Declare protected verifier files and their dependencies explicitly')
    protected = [Path(p).resolve() if Path(p).is_absolute() else workspace / relative_path(p)
                 for p in task.get('protected_files', [])]
    for check in task['checks']:
        for arg in check['argv'][1:]:
            if not arg.startswith('-') and (workspace / arg).is_file():
                protected.append((workspace / arg).resolve())
    # Objective and verifier integrity are checked before every acceptance decision.
    protected += [path.resolve(), Path(__file__).resolve(), ROOT / 'tools/agent_process.py']
    task['protected_files'] = sorted(set(map(str, protected)))
    task['prerequisites'] = [str(Path(p).resolve() if Path(p).is_absolute() else workspace / relative_path(p))
                             for p in task.get('prerequisites', [])]
    return task


def revision(workspace, seconds=3):
    """Capture the current Git revision and dirty status without changing the checkout."""
    result = {}
    deadline = time.monotonic() + seconds
    for key, argv in [('head', ['rev-parse', 'HEAD']), ('branch', ['branch', '--show-current']),
                      ('status', ['status', '--porcelain'])]:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            result['metadata_incomplete'] = True
            break
        try:
            proc = subprocess.run(['git', '-C', str(workspace), *argv], capture_output=True,
                                  text=True, timeout=remaining)
        except (OSError, subprocess.TimeoutExpired):
            result['metadata_incomplete'] = True
            break
        result[key] = proc.stdout.strip() if proc.returncode == 0 else None
    return result


def snapshot(workspace, deadline=None):
    """Hash non-generated workspace files to detect changes outside the declared edit scope."""
    ignored = {'.git', '.godot', '.tools', '.artifacts', 'builds', 'logs',
               '__pycache__', 'node_modules', '.venv'}
    files = {}
    for folder, dirs, names in os.walk(workspace, followlinks=False):
        if deadline is not None and time.monotonic() >= deadline:
            raise TimeoutError('Workspace fingerprint exceeded the total runtime budget')
        for name in dirs + names:
            path = Path(folder) / name
            if name not in ignored and path.is_symlink():
                files[path.relative_to(workspace).as_posix()] = 'symlink:' + os.readlink(path)
        dirs[:] = [d for d in dirs if d not in ignored and not (Path(folder) / d).is_symlink()]
        for name in names:
            if deadline is not None and time.monotonic() >= deadline:
                raise TimeoutError('Workspace fingerprint exceeded the total runtime budget')
            path = Path(folder) / name
            if not path.is_symlink():
                files[path.relative_to(workspace).as_posix()] = digest(path)
    return files


class WorkspaceLock:
    """Use an OS lock, released on crash, to allow only one controller per workspace."""

    def __enter__(self):
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.file = self.path.open('a+b')
        self.file.seek(0, os.SEEK_END)
        if self.file.tell() == 0:
            self.file.write(b'0')
            self.file.flush()
        self.file.seek(0)
        try:
            if os.name == 'nt':
                import msvcrt
                msvcrt.locking(self.file.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl
                fcntl.flock(self.file, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            self.file.close()
            raise RuntimeError('Another controller owns this workspace; inspect or stop that run.') from None
        return self

    def __init__(self, workspace):
        self.path = workspace / 'logs/agent-workflow.lock'

    def __exit__(self, *args):
        self.file.close()


class Run:
    """Own continuation decisions while a single bounded worker performs focused edits."""

    def __init__(self, directory):
        self.directory = directory
        self.state = json.loads((directory / 'state.json').read_text(encoding='utf-8'))
        self.task = self.state['task']
        self.workspace = Path(self.task['workspace'])
        self.started = time.monotonic()
        self.base_elapsed = self.state['elapsed_seconds']
        self.event_offsets = {}

    def elapsed(self):
        """Include all active controller time, preserving charges from earlier invocations."""
        return self.base_elapsed + time.monotonic() - self.started

    def save(self, event):
        """Persist current progress and append a small audit event before returning control."""
        self.state['elapsed_seconds'] = round(self.elapsed(), 4)
        self.state['updated_at'] = time.time()
        write_json(self.directory / 'state.json', self.state)
        with (self.directory / 'journal.jsonl').open('a', encoding='utf-8') as stream:
            stream.write(json.dumps({'at': time.time(), 'event': event,
                                     'status': self.state['status'],
                                     'attempts': self.state['attempts']}) + '\n')

    def finish(self, status, reason):
        """Record an exact stopping reason without treating stopped or limited work as complete."""
        self.state.update(status=status, next_action=reason, stop_reason=reason, active=None)
        self.save(reason)
        return self.state

    def stopped(self):
        """Observe a cooperative stop request made by a separate command."""
        return (self.directory / 'stop.request').exists()

    def native_events(self, path):
        """Save the explicit native session ID and observed usage from complete JSONL events."""
        if not path.exists():
            return
        offset = self.event_offsets.get(str(path), 0)
        with path.open('rb') as stream:
            stream.seek(offset)
            data = stream.read()
        complete = data.rfind(b'\n') + 1
        self.event_offsets[str(path)] = offset + complete
        for line in data[:complete].decode('utf-8', errors='replace').splitlines():
            try:
                event = json.loads(line)
            except ValueError:
                continue
            if not isinstance(event, dict):
                continue
            if event.get('type') == 'thread.started' and event.get('thread_id') != self.state.get('session_id'):
                self.state['session_id'] = event['thread_id']
                self.save('Native session ID captured')
            if event.get('type') == 'turn.completed':
                self.state['usage_by_attempt'][str(self.state['attempts'])] = event.get('usage')

    def command(self, argv, label, timeout, stdin=''):
        """Reserve runtime durably, execute one private process tree, and retain actual output."""
        remaining = self.task['limits']['runtime_seconds'] - self.elapsed()
        if remaining <= 0 or self.stopped():
            return {'reason': 'stopped' if self.stopped() else 'runtime_limit', 'exit_code': None}
        timeout = min(timeout, remaining)
        number = len(self.state['commands']) + 1
        prefix = self.directory / f'{number:03d}-{label}'
        paths = {key: prefix.with_suffix('.' + key) for key in ('stdin', 'stdout', 'stderr')}
        paths['stdin'].write_text(stdin, encoding='utf-8')
        argv = [sys.executable if arg == '{python}' else arg for arg in argv]
        record = dict(argv=argv, cwd=str(self.workspace), label=label,
                      stdout=str(paths['stdout']), stderr=str(paths['stderr']),
                      exit_code=None, reason='interrupted', elapsed_seconds=None)
        self.state['commands'].append(record)
        self.state['active'] = dict(command=number - 1, elapsed_before=self.elapsed(),
                                    reserved_seconds=timeout)
        self.save(f'Starting {label}')
        before = time.monotonic()
        child = None
        try:
            child = OwnedProcess(argv, self.workspace, paths['stdin'], paths['stdout'], paths['stderr'])
            record['resolved_executable'] = child.argv[0]
            code, reason = child.run(max(0, timeout - (time.monotonic() - before)),
                                     self.stopped, lambda: self.native_events(paths['stdout'])
                                     if label.startswith('worker') else None)
            record.update(exit_code=code, reason=reason)
        except KeyboardInterrupt:
            record['reason'] = 'stopped'
        except (OSError, RuntimeError) as error:
            record.update(reason='launch_error', error=str(error))
        finally:
            try:
                if child:
                    child.close()
                if label.startswith('worker'):
                    self.native_events(paths['stdout'])
            finally:
                record['elapsed_seconds'] = round(time.monotonic() - before, 4)
                self.state['active'] = None
                self.save(f'Finished {label}: {record["reason"] or record["exit_code"]}')
        return record

    def integrity(self):
        """Reject altered criteria, controller code, verifiers or files outside the allowed scope."""
        current = snapshot(self.workspace, self.started + self.task['limits']['runtime_seconds'] - self.base_elapsed)
        changed = sorted(p for p in self.state['initial_files'].keys() | current.keys()
                         if self.state['initial_files'].get(p) != current.get(p))
        self.state['changes'] = changed
        self.state['verified_files'] = {p: current.get(p) for p in changed}
        self.state['revision'] = revision(self.workspace,
            max(0, min(3, self.task['limits']['runtime_seconds'] - self.elapsed())))
        for path, expected in self.state['protected_hashes'].items():
            if expected is None:
                return f'Missing protected prerequisite: {path}'
            if digest(Path(path)) != expected:
                return f'Protected input changed: {path}. Review it explicitly in a new objective.'
        for p in changed:
            if (current.get(p) or '').startswith('symlink:'):
                return f'New or changed symlink requires explicit review: {p}'
        permitted = self.task['mutable_paths']
        outside = [p for p in changed if not any(p == a.replace('\\', '/').rstrip('/') or
                   p.startswith(a.replace('\\', '/').rstrip('/') + '/') for a in permitted)]
        return f'Changes outside task scope: {outside}' if outside else None

    def checks(self):
        """Execute immutable acceptance commands serially and classify baseline failures/regressions."""
        results = []
        for check in self.task['checks']:
            record = self.command(check['argv'], 'check-' + str(len(results) + 1),
                                  self.task['limits']['check_seconds'])
            results.append(dict(id=check['id'], passed=record.get('exit_code') == 0 and
                                record.get('reason') is None, command=record))
            if record.get('reason'):
                break
        if 'baseline' not in self.state and len(results) == len(self.task['checks']):
            self.state['baseline'] = {r['id']: r['passed'] for r in results}
        baseline = self.state.get('baseline', {})
        for result in results:
            result['classification'] = ('passed' if result['passed'] else
                                        'unclassified' if result['id'] not in baseline else
                                        'pre_existing' if baseline[result['id']] is False else 'regression')
            if not result['passed']:
                record = result['command']
                evidence = '\n'.join(Path(record[p]).read_text(encoding='utf-8', errors='replace')
                                     for p in ('stdout', 'stderr') if p in record and Path(record[p]).exists())
                signature = hashlib.sha256((result['id'] + evidence).encode()).hexdigest()
                pattern = self.state.setdefault('failure_patterns', {}).setdefault(signature,
                    dict(check=result['id'], observations=0, example=record,
                         candidate='Review repeated cause in a separate versioned experiment; do not change this contract.'))
                pattern['observations'] += 1
        self.state['verification'] = results
        self.save('Verified actual workspace state')
        return results

    def request(self):
        """Compose a focused worker instruction from fixed criteria and the latest real failures."""
        return {
            'objective': self.task['objective'], 'acceptance': self.task['acceptance'],
            'mutable_paths': self.task['mutable_paths'], 'protected_files': self.task['protected_files'],
            'attempt': self.state['attempts'], 'previous_report': self.state.get('worker_report'),
            'verification': self.state.get('verification'), 'changes': self.state.get('changes'),
            'rules': 'Inspect actual source and applicable AGENTS.md first. Make one focused repair using '
                     'the recorded failures. Do not weaken acceptance, edit protected inputs, change '
                     'orchestration, launch background work, invoke native goals/subagents, publish, '
                     'commit, reset, or perform external consequential actions. Preserve unrelated '
                     'changes. Follow project map/purpose maintenance within the declared scope. '
                     'Return status ready, blocked, or decision_required, changes, evidence, '
                     'next_action, blocker. The controller alone decides completion and retries. '
                     'If permission, prerequisites or product judgment are missing, report blocked '
                     'or decision_required; do not bypass safeguards.',
        }

    def worker(self):
        """Invoke one native session turn or an explicitly labelled deterministic demonstration worker."""
        self.state['attempts'] += 1
        self.state['work_item'] = 'Repair latest failed acceptance checks'
        request = self.directory / f'attempt-{self.state["attempts"]}.json'
        report = request.with_suffix('.report.json')
        write_json(request, self.request())
        worker = self.task['worker']
        if worker['kind'] == 'simulation':
            argv = [a.replace('{request}', str(request)).replace('{report}', str(report))
                    for a in worker['argv']]
        else:
            executable = worker.get('executable') or shutil.which('codex')
            if not executable:
                return dict(reason='launch_error', error='Codex CLI not found. Set worker.executable.'), None
            argv = [executable, '-c', 'approval_policy="never"', '-c', 'sandbox_mode="workspace-write"',
                    '--disable', 'goals', '--disable', 'multi_agent', 'exec']
            if self.state.get('session_id'):
                argv += ['resume', self.state['session_id']]
            else:
                argv += ['-C', str(self.workspace)]
            schema = self.directory / 'report-schema.json'
            write_json(schema, REPORT_SCHEMA)
            argv += ['--json', '--output-schema', str(schema), '-o', str(report), '-']
        result = self.command(argv, f'worker-{self.state["attempts"]}',
                              self.task['limits']['worker_seconds'], json.dumps(self.request(), indent=2))
        response = None
        if report.exists():
            try:
                response = json.loads(report.read_text(encoding='utf-8-sig'))
                if (not isinstance(response, dict) or set(response) != set(REPORT_SCHEMA['required']) or
                        not all(isinstance(v, str) for v in response.values()) or
                        response['status'] not in ('ready', 'blocked', 'decision_required')):
                    response = None
            except ValueError:
                pass
        self.state['worker_report'] = response
        self.state.setdefault('attempt_reports', {})[str(self.state['attempts'])] = response
        self.save('Worker returned; independent checks decide success')
        return result, response

    def execute(self):
        """Reconcile on entry, repair only verified failures, and stop on success, blockers or budgets."""
        with WorkspaceLock(self.workspace):
            # A Run may have been constructed before a different owner finished.
            # Read accounting only after acquiring ownership, never replay a stale copy.
            self.__init__(self.directory)
            if self.state['status'] in TERMINAL:
                return self.state
            active = self.state.get('active')
            if active:
                # The vanished controller cannot prove how much time it used. Charge its full reservation.
                self.base_elapsed = max(self.base_elapsed, active['elapsed_before'] + active['reserved_seconds'])
                self.state['commands'][active['command']]['reason'] = 'interrupted_reservation_charged'
                self.state['active'] = None
            if self.state['status'] == 'stopped':
                (self.directory / 'stop.request').unlink(missing_ok=True)
            self.state.update(status='running', next_action='Reconcile files and rerun acceptance before edits')
            self.save('Resuming against actual files')
            try:
                for path in self.task.get('prerequisites', []):
                    if not Path(path).exists():
                        return self.finish('blocked', f'Missing prerequisite: {path}')
                while True:
                    if self.stopped():
                        return self.finish('stopped', 'Stop requested; resume will verify before editing')
                    if self.elapsed() >= self.task['limits']['runtime_seconds']:
                        return self.finish('limit_reached', 'Total runtime budget exhausted')
                    problem = self.integrity()
                    if problem:
                        return self.finish('blocked', problem)
                    results = self.checks()
                    problem = self.integrity()
                    if problem:
                        return self.finish('blocked', problem)
                    reason = next((r['command'].get('reason') for r in results if r['command'].get('reason')), None)
                    if reason:
                        status = 'stopped' if reason == 'stopped' else 'limit_reached' if reason in ('timeout', 'runtime_limit') else 'blocked'
                        return self.finish(status, f'Acceptance command stopped: {reason}; inspect command logs')
                    if self.stopped():
                        return self.finish('stopped', 'Stop requested during verification')
                    if self.elapsed() >= self.task['limits']['runtime_seconds']:
                        return self.finish('limit_reached', 'Total runtime budget exhausted during verification')
                    if len(results) == len(self.task['checks']) and all(r['passed'] for r in results):
                        return self.finish('completed', 'All fixed acceptance commands passed')
                    if self.state['attempts'] >= self.task['limits']['attempts']:
                        return self.finish('limit_reached', 'Worker attempt budget exhausted')
                    progress = hashlib.sha256(json.dumps([self.state['changes'],
                        {p: digest(self.workspace / p) for p in self.state['changes']},
                        [r['id'] for r in results if r['passed']]], sort_keys=True).encode()).hexdigest()
                    if (self.state.get('last_progress') == progress and
                            self.state.get('last_progress_attempt', -1) < self.state['attempts']):
                        self.state['unchanged_attempts'] += 1
                    elif self.state.get('last_progress') != progress:
                        self.state['unchanged_attempts'] = 0
                    self.state['last_progress'] = progress
                    self.state['last_progress_attempt'] = self.state['attempts']
                    if self.state['unchanged_attempts'] >= self.task['limits']['no_progress']:
                        return self.finish('failed', 'Repeated attempts made no measurable progress')
                    result, response = self.worker()
                    problem = self.integrity()
                    if problem:
                        return self.finish('blocked', problem)
                    if result.get('reason'):
                        reason = result['reason']
                        status = 'stopped' if reason == 'stopped' else 'limit_reached' if reason in ('timeout', 'runtime_limit') else 'blocked'
                        return self.finish(status, f'Worker stopped: {reason}; {result.get("error", "inspect command stderr")}')
                    if result.get('exit_code') != 0 or response is None:
                        return self.finish('blocked', 'Worker failed or returned an invalid report; inspect command logs')
                    if response['status'] in ('blocked', 'decision_required'):
                        return self.finish('blocked', response['blocker'] or response['next_action'])
            except KeyboardInterrupt:
                return self.finish('stopped', 'Interrupted; resume will verify before editing')
            except TimeoutError as error:
                return self.finish('limit_reached', str(error))
            except (OSError, ValueError, subprocess.SubprocessError) as error:
                return self.finish('blocked', f'Unable to reconcile or execute safely: {error}')


def start(task_path, runs=RUNS):
    """Create a unique task record without changing or cleaning the user's working tree."""
    task = load_task(task_path.resolve())
    workspace = Path(task['workspace'])
    if not workspace.is_dir():
        raise ValueError(f'Workspace does not exist: {workspace}')
    with WorkspaceLock(workspace):
        run_id = time.strftime('%Y%m%d-%H%M%S') + '-' + uuid.uuid4().hex[:8]
        directory = runs / run_id
        directory.mkdir(parents=True)
        state = dict(id=run_id, version=1, status='ready', task=task, attempts=0,
                     elapsed_seconds=0, unchanged_attempts=0, commands=[], usage_by_attempt={},
                     usage_limit='Observed native usage only; no hard token or money cap',
                     protected_hashes={p: digest(Path(p)) for p in task['protected_files']},
                     initial_files={}, revision={}, active=None,
                     next_action='Inspect actual files and run baseline acceptance',
                     work_item='Baseline verification', changes=[])
        write_json(directory / 'state.json', state)
        run = Run(directory)
        try:
            run.state['initial_files'] = snapshot(workspace, run.started + task['limits']['runtime_seconds'])
            run.state['revision'] = revision(workspace,
                max(0, min(3, task['limits']['runtime_seconds'] - run.elapsed())))
            run.save('Captured initial files under workspace ownership')
        except TimeoutError as error:
            run.finish('limit_reached', str(error))
        except OSError as error:
            run.finish('blocked', f'Cannot capture initial workspace: {error}')
    return run


def main():
    """Expose manual start, status, cooperative stop and budget-preserving resume commands."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['start', 'status', 'stop', 'resume'])
    parser.add_argument('target', help='Objective JSON for start; exact run ID otherwise')
    args = parser.parse_args()
    try:
        if args.action == 'start':
            run = start(Path(args.target))
            print(f'RUN_ID={run.state["id"]}', flush=True)
            state = run.execute()
        else:
            if Path(args.target).name != args.target or args.target in ('.', '..'):
                raise ValueError('Expected an exact run ID')
            run = Run(RUNS / args.target)
            if args.action == 'stop':
                (run.directory / 'stop.request').touch()
                print('Stop requested. Inspect status after the running command exits.')
                return 0
            state = run.execute() if args.action == 'resume' else run.state
        print(json.dumps({k: state.get(k) for k in ('id', 'status', 'work_item', 'attempts',
                         'elapsed_seconds', 'next_action', 'stop_reason')}, indent=2))
        return 0 if state['status'] == 'completed' or args.action == 'status' else 2
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(f'Workflow could not proceed: {error}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
