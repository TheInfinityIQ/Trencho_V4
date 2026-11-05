"""Verify complete definition discovery, honest graph links and stale-purpose rejection."""
import contextlib
import io
import json
import pathlib
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
import system_map as mapper


class SystemMapTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        """Load the real pinned GDScript parser once for focused map tests."""
        cls.parser = mapper.load_parser()
        cls.temp_root = (mapper.ROOT / '.tools/system-map-test-work').resolve()
        cls.temp_root.relative_to(mapper.ROOT.resolve())
        cls.temp_root.mkdir(parents=True, exist_ok=True)

    def parse(self, source, path='game/example.gd'):
        """Extract definitions through the real grammar, rather than a regex stand-in."""
        return mapper.gd_functions(path, source, self.parser.parse(source, gather_metadata=True))

    def test_all_named_and_inline_functions_have_separate_facts(self):
        """Find classes, static functions and multiline callbacks without fake string/comment definitions."""
        source = '''extends Node
# func imaginary(): pass
const TEXT = "func fake(): pass"
signal changed
class Inner:
    static func calculate(value: int) -> int:
        return value + 1
func _ready() -> void:
    changed.connect(func(): callback_only())
    var compare = func(a, b): return a < b
    ordinary()
func ordinary() -> void: pass
'''
        functions, definitions = self.parse(source)
        self.assertEqual(len(functions), 5)
        self.assertEqual([function['name'] for function in functions], ['Inner.calculate', '_ready', '_ready/<lambda#1>', '_ready/<lambda#2>', 'ordinary'])
        self.assertTrue(functions[0]['signature'].startswith('static func'))
        self.assertNotIn('callback_only', functions[1]['calls_raw'])
        self.assertIn('callback_only', functions[2]['calls_raw'])
        self.assertEqual(functions[2]['parent'], 'game/example.gd::_ready')
        self.assertEqual(definitions['signals'], ['signal changed'])
        for function in functions:
            self.assertLessEqual(function['end_line'], len(source.splitlines()))
        self.assertEqual(functions[-1]['end_line'], len(source.splitlines()))
        self.assertIn('intentionally empty', mapper.derive_purpose(functions[-1], 'game/example.gd'))

    def test_static_links_do_not_claim_dynamic_receivers_are_proven(self):
        """Resolve local/preloaded callbacks and preserve an unresolved receiver as a candidate."""
        left, definitions = self.parse('''extends Node
const Other = preload("res://game/other.gd")
signal changed
func work():
    Other.run()
    object.run()
    object.unknown()
    helper()
    changed.connect(helper)
    changed.connect(func(): helper())
func helper(): pass
''')
        right, right_definitions = self.parse('extends RefCounted\nstatic func run(): pass\n', 'game/other.gd')
        files = {'game/example.gd': {'functions': left, 'definitions': definitions}, 'game/other.gd': {'functions': right, 'definitions': right_definitions}}
        candidates = mapper.link_calls(files)
        calls = {call['expression']: call for call in left[0]['calls']}
        self.assertEqual(calls['Other.run']['target'], 'game/other.gd::run')
        self.assertEqual(calls['helper']['target'], 'game/example.gd::helper')
        self.assertNotIn('target', calls['object.run'])
        self.assertIn('object.unknown', left[0]['external_or_dynamic_calls'])
        self.assertEqual(candidates[calls['object.run']['candidate_group']], ['game/other.gd::run'])
        self.assertEqual(left[0]['callbacks'][0]['target'], 'game/example.gd::helper')
        self.assertEqual(left[0]['callbacks'][1]['target'], 'game/example.gd::work/<lambda#1>')

    def test_multiline_lambda_stops_before_following_statements(self):
        """A missing DEDENT offset must not fingerprint the rest of the file as callback code."""
        source = '''extends Node
func setup():
    var check = func(value: int) -> int:
        if value < 0: return 0
        return maxi(0, value)
    unrelated()
func unrelated():
    pass
'''
        functions, _ = self.parse(source)
        callback = functions[1]
        self.assertEqual(callback['line'], 3)
        self.assertEqual(callback['end_line'], 5)
        self.assertEqual(callback['source'], 'func(value: int) -> int:\n        if value < 0: return 0\n        return maxi(0, value)')
        edited, _ = self.parse(source.replace('    pass\n', '    print("changed")\n'))
        self.assertEqual(callback['code_sha256'], edited[1]['code_sha256'])
        changed_body, _ = self.parse(source.replace('maxi(0, value)', 'maxi(1, value)'))
        self.assertNotEqual(callback['code_sha256'], changed_body[1]['code_sha256'])

    def test_python_nested_callbacks_do_not_duplicate_parent_calls(self):
        """Inventory Python nested definitions and keep their calls separate from their parent."""
        functions = mapper.python_functions('tool.py', 'def outer():\n    child = lambda: hidden()\n    visible()\n    def inner():\n        nested()\n')
        self.assertEqual([function['name'] for function in functions], ['outer', 'outer/<lambda#1>', 'outer.inner'])
        self.assertEqual(set(functions[0]['calls_raw']), {'visible'})
        self.assertEqual(set(functions[1]['calls_raw']), {'hidden'})
        self.assertEqual(set(functions[2]['calls_raw']), {'nested'})

    def test_crlf_and_lf_have_identical_source_fingerprints(self):
        """Keep source fingerprints stable across Windows and Linux checkouts."""
        with tempfile.TemporaryDirectory(dir=self.temp_root) as directory:
            path = pathlib.Path(directory) / 'source.gd'
            path.write_bytes(b'extends Node\r\nfunc work(): pass\r\n')
            windows = mapper.digest(mapper.normalized_text(path))
            path.write_bytes(b'extends Node\nfunc work(): pass\n')
            self.assertEqual(windows, mapper.digest(mapper.normalized_text(path)))

    def test_native_powershell_parser_includes_inline_scriptblocks(self):
        """Verify real PowerShell callback discovery and unique IDs in the source-inspection helper."""
        files = mapper.powershell_functions(mapper.ROOT)
        callbacks = files['tools/system_map_powershell.ps1']
        self.assertGreaterEqual(len(callbacks), 2)
        self.assertTrue(all(function['kind'] == 'lambda' for function in callbacks))
        self.assertEqual(len({function['id'] for function in callbacks}), len(callbacks))
        self.assertTrue(all(function['source'].startswith('{') for function in callbacks))

    def test_changed_added_removed_functions_and_pending_review_gate(self):
        """A refreshed but unreviewed function must still fail; review/removal must update the map."""
        with tempfile.TemporaryDirectory(dir=self.temp_root) as directory:
            root = pathlib.Path(directory)
            (root / 'game').mkdir()
            script = root / 'game/example.gd'
            script.write_text('extends Node\nfunc value(): return 1\n', encoding='utf-8')
            project = root / 'project.godot'
            project.write_text('[application]\nrun/main_scene="res://game/main.tscn"\n', encoding='utf-8')
            fixture_paths = ['game/example.gd', 'project.godot']
            with mock.patch.object(mapper, 'ROOT', root), mock.patch.object(mapper, 'MAP_PATH', root / 'docs/system_map.json'), mock.patch.object(mapper, 'inventory', return_value=fixture_paths), mock.patch.object(mapper, 'powershell_functions', return_value={}), mock.patch.object(mapper, 'load_parser', return_value=self.parser):
                self.assertEqual(self.invoke('--initialize'), 0)
                self.assertEqual(self.invoke('--check'), 0)
                script.write_text('extends Node\nfunc value(): return 2\n', encoding='utf-8')
                self.assertEqual(self.invoke('--check'), 1)
                self.assertEqual(self.invoke('--update'), 0)
                self.assertEqual(self.invoke('--check'), 1, 'Persisting pending review must not bypass the gate.')
                self.assertEqual(self.invoke('--purpose', 'game/example.gd::value', 'Return the updated fixture value, two.'), 0)
                self.assertEqual(self.invoke('--check'), 0)
                script.write_text('extends Node\nfunc value(): return 2\nfunc added(): pass\n', encoding='utf-8')
                self.assertEqual(self.invoke('--update'), 0)
                self.assertEqual(self.invoke('--check'), 1)
                self.assertEqual(mapper.read_previous()['totals']['purpose_reviews_required'], 1)
                script.write_text('extends Node\nfunc value(): return 2\n', encoding='utf-8')
                self.assertEqual(self.invoke('--update'), 0)
                self.assertEqual(self.invoke('--check'), 0)
                script.unlink()
                fixture_paths.remove('game/example.gd')
                self.assertEqual(self.invoke('--update'), 0)
                self.assertEqual(self.invoke('--check'), 0)
                self.assertEqual(mapper.read_previous()['totals']['functions'], 0)

    def invoke(self, *arguments):
        """Run the real CLI dispatcher with captured output inside a temporary miniature project."""
        with mock.patch.object(sys, 'argv', ['system_map.py', *arguments]), contextlib.redirect_stdout(io.StringIO()):
            return mapper.main()


if __name__ == '__main__':
    unittest.main()
