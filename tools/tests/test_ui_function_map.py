"""Verify real UI callback discovery, exact source jumps and stale-line rejection."""
import json
import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
import system_map as mapper
import ui_function_map as ui


class UiFunctionMapTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        """Read the maintained project map and actual Build controls through the real parser."""
        cls.document = json.loads((mapper.ROOT / 'docs/system_map.json').read_text(encoding='utf-8'))
        cls.index = ui.SourceIndex(mapper.ROOT, cls.document)
        cls.controls = ui.scan_controls(cls.index, ui.BASE)

    def test_real_button_resolves_its_own_callback_and_target(self):
        """The visible Place on field button must lead to its own lambda and select_build_kind."""
        control = next(control for control in self.controls if control['label'] == 'Place on field')
        self.assertEqual(control['area'], 'Build')
        self.assertEqual(control['signal'], 'pressed')
        self.assertIn('/<lambda#', control['handler']['id'])
        self.assertIn(ui.BASE + '::select_build_kind', [node['id'] for node in control['calls']])
        line = self.index.source(ui.BASE).splitlines()[control['source']['line'] - 1]
        self.assertIn('"Place on field"', line)
        cancel = next(control for control in self.controls if control['label'] == 'Cancel placement')
        self.assertEqual(cancel['handler']['id'], ui.BASE + '::_cancel_placement')
        self.assertNotIn(ui.BASE + '::confirm_build_at', [node['id'] for node in cancel['calls']])

    def test_cross_file_hiring_targets_actual_receiving_service(self):
        """A declared hire callback must resolve to receiving.buy_people, not a same-name candidate."""
        hire = next(control for control in self.controls if control['label'].startswith('Hire 8 workers'))
        self.assertIn('game/procurement/receiving_simulation.gd::buy_people', [node['id'] for node in hire['calls']])
        self.assertIsNone(self.index.resolve(ui.BASE, 'unknown_receiver.buy_people'))
        runtime = next(control for control in self.controls if control['label'] == 'Pause / resume facility')
        self.assertTrue(any(not node['id'] and 'runtime-selected' in node['label'] for node in runtime['calls']))

    def test_stale_source_is_rejected_before_generating_wrong_lines(self):
        """A changed source fingerprint must require map refresh instead of silently reusing old lines."""
        document = json.loads(json.dumps(self.document))
        document['files'][ui.BASE]['sha256'] = 'old-source-fingerprint'
        index = ui.SourceIndex(mapper.ROOT, document)
        with self.assertRaisesRegex(ValueError, 'stale'):
            index.node(ui.BASE + '::confirm_build_at')

    def test_button_obligations_keep_runtime_captions_and_dynamic_limits(self):
        """Generate coverage obligations with real captions, signal suffixes removed and explicit factory limits."""
        contract = ui.button_contracts(self.index)
        rows = contract['button_definitions']
        self.assertTrue(any(row['label'] == 'Place on field' for row in rows))
        hire = next(row for row in rows if row['path'] == 'game/rear_base/workforce_panel.gd'
                    and row['label'].startswith('Hire 8 workers'))
        self.assertFalse(hire['label'].endswith(' · pressed'))
        self.assertEqual(hire['path'], 'game/rear_base/workforce_panel.gd')
        self.assertTrue(any(row['dynamic'] for row in rows))
        self.assertEqual(contract['source_sha256'][ui.BASE], mapper.digest(self.index.source(ui.BASE)))
        self.assertIn('not proof', contract['limits'])

    def test_workflow_call_sites_and_portable_html_are_source_checked(self):
        """Every reviewed workflow jump must be current; escaping and local-path resolution stay portable."""
        flows = ui.reviewed_flows(self.index)
        training = next(flow for flow in flows if flow['id'] == 'training-read')
        self.assertIn(ui.SIMULATION + '::training_view', [node['id'] for node in training['nodes']])
        branch = training['nodes'][0]
        self.assertIn('active_panel == "Train"', self.index.source(branch['path']).splitlines()[branch['line'] - 1])
        command = next(flow for flow in flows if flow['id'] == 'training-command')
        self.assertIn('Rejected training requests', command['note'])
        placement = next(flow for flow in flows if flow['id'] == 'place')
        hover = next(flow for flow in flows if flow['id'] == 'build')
        self.assertIn(ui.CONSTRUCTION + '::placement_hint', [node['id'] for node in hover['nodes']])
        self.assertNotIn(ui.CONSTRUCTION + '::preview', [node['id'] for node in hover['nodes']])
        full_preview = next(flow for flow in flows if flow['id'] == 'build-full-preview')
        self.assertIn(ui.CONSTRUCTION + '::preview', [node['id'] for node in full_preview['nodes']])
        self.assertIn(ui.CONSTRUCTION + '::preview', [node['id'] for node in placement['nodes']])
        signal = placement['nodes'][0]
        self.assertIn('placement_requested.emit', self.index.source(signal['path']).splitlines()[signal['line'] - 1])
        template = (mapper.ROOT / ui.TEMPLATE).read_text(encoding='utf-8')
        result = ui.render(self.index, template)
        self.assertNotIn('<!-- WORKFLOWS -->', result)
        self.assertNotIn(str(mapper.ROOT), result)
        self.assertIn("'vscode://file/'", result)
        self.assertIn('data-source="game/construction/construction_service.gd"', result)
        node = {'path': 'game/test&name.gd', 'line': 4, 'name': '<unsafe>', 'label': '"<script>"'}
        escaped = ui.source_link(node)
        self.assertNotIn('<script>', escaped)
        self.assertIn('&lt;script&gt;', escaped)
        self.assertIn('test&amp;name.gd', escaped)


if __name__ == '__main__':
    unittest.main()
