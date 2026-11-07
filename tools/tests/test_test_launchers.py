"""Exercise real launch-plan selection without starting Godot or touching the desktop."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
PWSH = shutil.which('pwsh')
if not PWSH and os.name == 'nt':
    candidate = Path.home() / '.cache/codex-runtimes/codex-primary-runtime/dependencies/native/powershell/pwsh.exe'
    if candidate.is_file():
        PWSH = str(candidate)


@unittest.skipUnless(PWSH, 'PowerShell 7 required to execute launcher plans')
class TestLaunchers(unittest.TestCase):
    def plan(self, launcher='run_gdunit4_performance.ps1', *arguments, succeeds=True):
        """Execute the production launcher's side-effect-free selection and preserve failures."""
        result = subprocess.run([PWSH, '-NoProfile', '-File', str(ROOT / 'tools' / launcher),
                                 '-ListOnly', *arguments], cwd=ROOT, capture_output=True,
                                text=True, timeout=20)
        if not succeeds:
            self.assertNotEqual(result.returncode, 0, result.stdout)
            return result.stderr
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def test_background_defaults_and_native_omissions_are_explicit(self):
        """Require the sixty-case routine subset and matching background domain selectors."""
        default = self.plan()
        self.assertTrue(default['headless'])
        self.assertFalse(default['foreground'])
        self.assertFalse(default['visible_fps_certified'])
        self.assertEqual(default['expected_cases'], 60)
        exclusions = '\n'.join(default['exclusions'])
        for native in ('a_full_ui_test.gd', 'building_pointer_test.gd',
                       'training_input_test.gd', 'prototype_live_ui_test.gd',
                       'test_03_observe_live_menu_actions_at_one_x',
                       'test_ordinary_request_and_cancel_buttons_do_not_create_goods_or_vehicles'):
            self.assertIn(native, exclusions)
        for selector, count in (('TrainingOnly', 18), ('LogisticsOnly', 11),
                                ('LiveFrameOnly', 5), ('PlacementReadsOnly', 6),
                                ('BuildingsOnly', 2), ('LongSessionOnly', 1)):
            with self.subTest(selector=selector):
                plan = self.plan('run_gdunit4_performance.ps1', '-' + selector)
                self.assertTrue(plan['headless'])
                self.assertEqual(plan['expected_cases'], count)
        menu = self.plan('run_menu_performance.ps1')
        self.assertTrue(menu['headless'])
        self.assertTrue(menu['exit_on_pause'])
        self.assertFalse(menu['visible_fps_certified'])

    def test_foreground_is_explicit_and_conflicting_modes_fail(self):
        """Preserve native selections only with an explicit foreground request, rejecting ambiguity."""
        foreground = self.plan('run_gdunit4_performance.ps1', '-Foreground')
        self.assertFalse(foreground['headless'])
        self.assertTrue(foreground['foreground'])
        self.assertEqual(foreground['expected_cases'], 76)
        self.assertEqual(foreground['exclusions'], ['game/diagnostics/tests/gdunit/long_session_test.gd'])
        for selector, count in (('PlacementOnly', 12), ('UiOnly', 9),
                                ('TrainingOnly', 22), ('LogisticsOnly', 12)):
            with self.subTest(selector=selector):
                plan = self.plan('run_gdunit4_performance.ps1', '-Foreground', '-' + selector)
                self.assertEqual(plan['expected_cases'], count)
        for launcher in ('run_gdunit4_performance.ps1', 'run_menu_performance.ps1'):
            with self.subTest(launcher=launcher):
                message = self.plan(launcher, '-Headless', '-Foreground', succeeds=False)
                self.assertIn('cannot be combined', message)

    def test_native_only_selections_refuse_background_before_engine_start(self):
        """Prevent a native-only shortcut from silently starting a foreground mouse runner."""
        for selector in ('PlacementOnly', 'PlacementBenchmarkOnly', 'UiOnly', 'ButtonsOnly',
                         'OrdinaryMenusOnly', 'TrainingUiOnly'):
            with self.subTest(selector=selector):
                message = self.plan('run_gdunit4_performance.ps1', '-' + selector, succeeds=False)
                self.assertIn('needs -Foreground', message)


if __name__ == '__main__':
    unittest.main()
