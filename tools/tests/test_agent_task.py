"""Exercise the real controller using isolated, explicitly simulated worker decisions."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import agent_task as workflow
from agent_task_demo import make_task


class AgentTaskTests(unittest.TestCase):
    def setUp(self):
        """Keep each demonstration's editable files and durable records isolated from the game."""
        (workflow.ROOT / 'logs').mkdir(exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=workflow.ROOT / 'logs')
        self.root = Path(self.temp.name)

    def tearDown(self):
        """Remove only the disposable directory created by this test after owned children exit."""
        self.temp.cleanup()

    def task(self, mode='repair', **limits):
        """Prepare a task and optional stricter limits before its acceptance contract is frozen."""
        path = make_task(self.root / 'fixture', mode)
        value = json.loads(path.read_text())
        value['limits'].update(limits)
        path.write_text(json.dumps(value))
        return path

    def run_task(self, path):
        """Create and execute a fresh durable run through production controller code."""
        run = workflow.start(path, self.root / 'runs')
        state = run.execute()
        return run, state

    def test_failure_drives_focused_repair_and_stops_green(self):
        """Retain baseline failure, first incorrect repair and evidence-driven correction to 42."""
        run, state = self.run_task(self.task())
        self.assertEqual(state['status'], 'completed')
        self.assertEqual(state['attempts'], 2)
        self.assertEqual(len(state['failure_patterns']), 2)
        self.assertEqual(state['baseline'], {'answer-is-42': False})
        checks = [c for c in state['commands'] if c['label'].startswith('check')]
        self.assertEqual([c['exit_code'] for c in checks], [1, 1, 0])
        second = json.loads((run.directory / 'attempt-2.json').read_text())
        self.assertIn('expected 42, got 41', Path(second['verification'][0]['command']['stdout']).read_text())
        count = len(state['commands'])
        resumed = workflow.Run(run.directory).execute()
        self.assertEqual(resumed['status'], 'completed')
        self.assertEqual(len(resumed['commands']), count)

    def test_missing_prerequisite_blocks_without_worker(self):
        """Stop before mutation when an explicit required input does not exist."""
        path = self.task()
        value = json.loads(path.read_text())
        value['prerequisites'] = [str(self.root / 'absent-tool')]
        path.write_text(json.dumps(value))
        _, state = self.run_task(path)
        self.assertEqual(state['status'], 'blocked')
        self.assertEqual(state['attempts'], 0)
        self.assertIn('absent-tool', state['stop_reason'])

    def test_attempt_limit_and_no_progress_stop(self):
        """Enforce independent attempt and unchanged-progress stopping rules without relaxing acceptance."""
        path = self.task('unchanged', attempts=1)
        _, state = self.run_task(path)
        self.assertEqual((state['status'], state['attempts']), ('limit_reached', 1))
        # A separate objective is required to test different limits.
        second = self.root / 'second'
        path = make_task(second, 'unchanged')
        value = json.loads(path.read_text())
        value['limits'].update(attempts=4, no_progress=2)
        path.write_text(json.dumps(value))
        _, state = self.run_task(path)
        self.assertEqual((state['status'], state['attempts']), ('failed', 2))
        self.assertIn('no measurable progress', state['stop_reason'])

    def test_deadline_kills_owned_descendants(self):
        """A real worker deadline must kill its spawned child and preserve the consumed attempt."""
        run, state = self.run_task(self.task('sleep', worker_seconds=0.4))
        self.assertEqual(state['status'], 'limit_reached')
        self.assertEqual(state['attempts'], 1)
        self.assertGreaterEqual(state['elapsed_seconds'], 0.4)
        time.sleep(2.2)
        self.assertFalse((Path(state['task']['workspace']) / 'logs/escaped-child').exists())
        resumed = workflow.Run(run.directory).execute()
        self.assertEqual((resumed['status'], resumed['attempts']), ('limit_reached', 1))

    def test_protected_contract_change_is_blocked(self):
        """Refuse to resume against a modified objective instead of silently changing success criteria."""
        path = self.task()
        run = workflow.start(path, self.root / 'runs')
        path.write_text('{}')
        state = run.execute()
        self.assertEqual(state['status'], 'blocked')
        self.assertEqual(state['attempts'], 0)
        self.assertIn('Protected input changed', state['stop_reason'])

    def test_check_script_is_automatically_protected(self):
        """A worker cannot obtain green by rewriting the invoked checker inside its edit scope."""
        path = self.task('weaken')
        value = json.loads(path.read_text())
        verifier = Path(value['workspace']) / 'verifier.py'
        verifier.write_text('raise SystemExit(1)\n')
        value['mutable_paths'].append('verifier.py')
        value['checks'][0]['argv'] = ['{python}', 'verifier.py']
        path.write_text(json.dumps(value))
        _, state = self.run_task(path)
        self.assertEqual((state['status'], state['attempts']), ('blocked', 1))
        self.assertIn('Protected input changed', state['stop_reason'])
        self.assertEqual(len([c for c in state['commands'] if c['label'].startswith('check')]), 1)

    def test_outside_scope_changes_are_retained_on_failure(self):
        """Record and stop an outside-scope edit without deleting or reverting it."""
        _, state = self.run_task(self.task('outside'))
        self.assertEqual(state['status'], 'blocked')
        self.assertEqual(state['changes'], ['outside.txt'])
        self.assertIn('outside task scope', state['stop_reason'])

    def test_snapshot_excludes_generated_builds_and_artifacts_but_tracks_source(self):
        """Prune documented generated output before hashing while retaining real and hidden source."""
        for directory in ('game', '.github', '.artifacts/nested-worktree', 'builds/old-export'):
            (self.root / directory).mkdir(parents=True)
        source = self.root / 'game/play.gd'
        source.write_text('extends Node\n')
        configuration = self.root / '.github/check.yml'
        configuration.write_text('name: retained\n')
        artifact = self.root / '.artifacts/nested-worktree/generated.gd'
        artifact.write_text('old generated snapshot\n')
        export = self.root / 'builds/old-export/game.pck'
        export.write_bytes(b'generated export')
        expected = {'game/play.gd': workflow.digest(source), '.github/check.yml': workflow.digest(configuration)}
        self.assertEqual(workflow.snapshot(self.root), expected)
        artifact.write_text('another generated snapshot\n')
        export.write_bytes(b'changed generated export')
        self.assertEqual(workflow.snapshot(self.root), expected)
        source.write_text('extends Control\n')
        self.assertNotEqual(workflow.snapshot(self.root)['game/play.gd'], expected['game/play.gd'])

    def test_changed_symlink_is_visible(self):
        """Scope hashing must expose a new link even though it never traverses that link."""
        path = self.task()
        run = workflow.start(path, self.root / 'runs')
        try:
            (run.workspace / 'outside-link').symlink_to(run.workspace / 'answer.py')
        except OSError as error:
            self.skipTest(f'Symlink creation unavailable: {error}')
        state = run.execute()
        self.assertEqual(state['status'], 'blocked')
        self.assertIn('symlink', state['stop_reason'])

    def test_path_command_resolution(self):
        """Resolve a normal PATH executable before Windows CreateProcess receives its application name."""
        path = self.task()
        run = workflow.start(path, self.root / 'runs')
        result = run.command(['git', '--version'], 'path-probe', 2)
        self.assertEqual(result['exit_code'], 0)
        self.assertTrue(Path(result['resolved_executable']).is_absolute())

    def test_verification_cannot_complete_after_total_deadline(self):
        """A green result arriving after reconciliation used the budget is limit-reached, not success."""
        path = self.task()
        run = workflow.start(path, self.root / 'runs')
        observed = []
        def slow_green(owner):
            observed.append(True)
            owner.base_elapsed += owner.task['limits']['runtime_seconds']
            return [{'id': 'answer-is-42', 'passed': True, 'command': {}}]
        with mock.patch.object(workflow.Run, 'checks', slow_green):
            state = run.execute()
        self.assertEqual(state['status'], 'limit_reached')
        self.assertEqual(state['attempts'], 0)
        self.assertEqual(observed, [True])

    def test_reload_after_lock_does_not_replay_stale_state(self):
        """An object created before another owner completed must reload before choosing work."""
        path = self.task()
        run = workflow.start(path, self.root / 'runs')
        stale = workflow.Run(run.directory)
        finished = run.execute()
        resumed = stale.execute()
        self.assertEqual(resumed['status'], 'completed')
        self.assertEqual(resumed['attempts'], finished['attempts'])
        self.assertEqual(len(resumed['commands']), len(finished['commands']))

    def test_non_object_native_events_do_not_break_cleanup(self):
        """Malformed JSON event values are ignored without losing the durable active-command record."""
        run = workflow.start(self.task(), self.root / 'runs')
        path = run.directory / 'events.jsonl'
        path.write_text('[]\nnull\n{"type":"turn.completed","usage":{"input_tokens":7}}\n')
        run.native_events(path)
        run.native_events(path)
        self.assertEqual(run.state['usage_by_attempt']['0'], {'input_tokens': 7})

    def test_lock_rejects_second_controller(self):
        """Prevent overlapping runs in the same workspace even when their IDs differ."""
        run = workflow.start(self.task(), self.root / 'runs')
        with workflow.WorkspaceLock(run.workspace):
            with self.assertRaisesRegex(RuntimeError, 'Another controller'):
                run.execute()

    def start_child(self, path):
        """Launch the actual command-line entry and wait for its durable worker-started marker."""
        # Use the default run directory so stop/resume commands work exactly as documented.
        stream = (self.root / 'controller.stdout').open('w')
        child = subprocess.Popen([sys.executable, str(workflow.ROOT / 'tools/agent_task.py'),
                                  'start', str(path)], stdout=stream, stderr=stream)
        deadline = time.monotonic() + 8
        marker = self.root / 'fixture/workspace/logs/worker-started'
        while not marker.exists() and child.poll() is None and time.monotonic() < deadline:
            time.sleep(0.03)
        if not marker.exists():
            child.kill()
            child.wait()
            stream.close()
            self.fail((self.root / 'controller.stdout').read_text())
        text = (self.root / 'controller.stdout').read_text()
        directory = workflow.RUNS / text.split('RUN_ID=', 1)[1].splitlines()[0]
        return child, stream, directory

    @unittest.skipUnless(os.name == 'nt', 'Crash containment is implemented and demonstrated on Windows')
    def test_crash_resume_reconciles_without_replaying_completed_edit(self):
        """Kill the controller mid-action; job containment and durable verification prevent duplicate repair."""
        path = self.task('crash', worker_seconds=1.5)
        child, stream, directory = self.start_child(path)
        try:
            child.kill()
            child.wait(timeout=3)
            state = workflow.Run(directory).execute()
            self.assertEqual((state['status'], state['attempts']), ('completed', 1))
            self.assertGreaterEqual(state['elapsed_seconds'], 1.5)
            self.assertEqual((self.root / 'fixture/workspace/logs/worker-count.txt').read_text(), '1')
            time.sleep(2.2)
            self.assertFalse((self.root / 'fixture/workspace/logs/escaped-child').exists())
        finally:
            if child.poll() is None:
                child.kill()
                child.wait()
            stream.close()

    def test_stop_and_resume_preserves_attempts(self):
        """Request a cooperative stop and then verify existing edits before invoking another worker."""
        path = self.task('crash')
        child, stream, directory = self.start_child(path)
        try:
            result = subprocess.run([sys.executable, str(workflow.ROOT / 'tools/agent_task.py'),
                                     'stop', directory.name], capture_output=True, timeout=4)
            self.assertEqual(result.returncode, 0)
            child.wait(timeout=4)
            stopped = workflow.Run(directory).state
            self.assertEqual(stopped['status'], 'stopped')
            resumed = workflow.Run(directory).execute()
            self.assertEqual((resumed['status'], resumed['attempts']), ('completed', 1))
        finally:
            if child.poll() is None:
                child.kill()
                child.wait()
            stream.close()


if __name__ == '__main__':
    unittest.main()
