"""Generate the offline UI-to-function flowchart and VS Code source links.

Read-only source analysis; no Godot startup, addon, server or game execution.
The maintained system map must match every source file used by this diagram.
"""
from __future__ import annotations

import argparse
import ast
import collections
import html
import json
import pathlib
import re
import sys

import system_map as mapper

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUTPUT = 'docs/ui_function_map.html'
TEMPLATE = 'tools/ui_function_map_template.html'
CONTRACTS = 'game/diagnostics/tests/gdunit/fixtures/ui_button_contracts.json'
BASE = 'game/rear_base/base_demo.gd'
SHELL = 'game/ui/command_shell.gd'
MAIN = 'game/main/main.gd'
SESSION = 'game/main/game_session.gd'
MAP = 'game/rear_base/base_map.gd'
CONSTRUCTION = 'game/construction/construction_service.gd'
REAR = 'game/staffing/rear_simulation.gd'
SIMULATION = 'game/rear_base/base_simulation.gd'
UI_FILES = [SHELL, BASE, 'game/rear_base/workforce_panel.gd', 'game/forward_supply/forward_delivery_panel.gd',
            'game/rear_base/factory_plan_panel.gd', 'game/logistics/army_supply_panel.gd']
PANEL_NAMES = {
    '_construction_panel': 'Build', '_orders_panel': 'Supplies', '_staff_panel': 'Workers / Jobs',
    '_haul_panel': 'Hauling', '_production_panel': 'Production', '_refresh_ingredients': 'Production',
    '_inspect_panel': 'Inspection', '_training_panel': 'Training', '_vehicles_panel': 'Vehicles',
    '_dispatch_panel': 'Dispatch', '_hq_panel': 'HQ diagnostics (optional)', '_army_needs_panel': 'Army needs',
    '_ready': 'Standalone rear controls',
}
RECEIVERS = {
    'simulation': SIMULATION, 'session': SESSION, 'base_map': MAP,
    'session.automatic_logistics': 'game/logistics/rear_logistics.gd',
    'simulation.receiving': 'game/procurement/receiving_simulation.gd',
    'simulation.rear': REAR,
    **{'simulation.rear.' + name: 'game/' + path for name, path in {
        'construction': 'construction/construction_service.gd', 'training': 'training/training_service.gd',
        'vehicles': 'vehicles/vehicle_activity.gd', 'dispatch': 'dispatch/dispatch_service.gd',
        'hq': 'hq/hq_logistics.gd', 'ledger': 'identity/identity_ledger.gd',
        'forward_supply': 'forward_supply/forward_supply.gd',
    }.items()},
}
INPUT_SIGNALS = {'pressed', 'toggled', 'value_changed', 'item_selected', 'tab_changed', 'id_pressed', 'confirmed', 'canceled'}


class SourceIndex:
    """Resolve stable function IDs and validate current source before using mapped lines."""

    def __init__(self, root: pathlib.Path, document: dict):
        self.root = root
        self.document = document
        self.functions = {f['id']: f for file in document['files'].values() for f in file['functions']}
        self.sources: dict[str, str] = {}
        self.parsed: dict[str, list[dict]] = {}

    def source(self, path: str) -> str:
        """Read a source once and reject stale map fingerprints instead of guessing line numbers."""
        if path not in self.sources:
            source = mapper.normalized_text(self.root / path)
            if mapper.digest(source) != self.document['files'][path]['sha256']:
                raise ValueError('Source map is stale for ' + path + '. Run Update System Map.cmd.')
            self.sources[path] = source
        return self.sources[path]

    def node(self, identifier: str, label: str = '', needle: str = '') -> dict:
        """Create a source-linked function or exact in-function call-site node from a stable ID."""
        function = self.functions[identifier]
        path = identifier.split('::', 1)[0]
        lines = self.source(path).splitlines()
        line = function['line']
        if needle:
            matches = [number for number in range(line, function['end_line'] + 1) if needle in lines[number - 1]]
            if len(matches) != 1:
                raise ValueError('Expected one reviewed source anchor: ' + identifier + ' / ' + needle)
            line = matches[0]
        return {'id': identifier, 'path': path, 'line': line, 'name': function['name'], 'label': label}

    def resolve(self, path: str, expression: str) -> str | None:
        """Resolve local/preloaded calls and explicitly reviewed shared-session receiver paths only."""
        expression = re.sub(r'\.bind\(.*$', '', expression.strip())
        local = path + '::' + expression
        if local in self.functions:
            return local
        if '.' not in expression:
            return None
        receiver, name = expression.rsplit('.', 1)
        target_path = self.document['files'][path].get('definitions', {}).get('resources', {}).get(receiver)
        target_path = target_path or RECEIVERS.get(receiver)
        target = (target_path + '::' + name) if target_path else ''
        return target if target in self.functions else None

    def calls(self, function: dict) -> list[dict]:
        """List direct script-call targets; keep runtime-selected activity calls explicitly unresolved."""
        path = function['id'].split('::', 1)[0]
        result = []
        for expression, line in sorted(function['calls_raw'].items(), key=lambda pair: (pair[1], pair[0])):
            identifier = self.resolve(path, expression)
            if identifier:
                result.append(self.node(identifier, expression + '()'))
            elif '_activity().' in expression or expression.startswith('_pending_activity.'):
                result.append({'id': '', 'path': path, 'line': line, 'name': expression,
                               'label': expression + '() · runtime-selected implementation'})
        return result


def label_of(node, source: str) -> str:
    """Read a literal UI caption or retain its explicit dynamic source expression."""
    text = mapper.text_of(node, source)
    try:
        value = ast.literal_eval(text)
        if isinstance(value, str):
            return value
    except (ValueError, SyntaxError):
        pass
    return mapper.compact(text, 100) + ' [dynamic label]'


def scan_controls(index: SourceIndex, path: str) -> list[dict]:
    """Extract declared button callbacks and input-signal handlers through the real GDScript AST."""
    source = index.source(path)
    tree = mapper.load_parser().parse(source, gather_metadata=True)
    functions, _ = mapper.gd_functions(path, source, tree)
    index.parsed[path] = functions
    by_start = {}
    definitions = iter(functions)
    for node in tree.iter_subtrees_topdown():
        if str(node.data) in {'func_def', 'lambda', 'abstract_func_def'}:
            by_start[node.meta.start_pos] = next(definitions)
    captions = {'_confirmation': 'New game confirmation'}
    for node in tree.iter_subtrees():
        if str(node.data) == 'assnmnt_expr' and len(node.children) >= 2:
            left = mapper.text_of(node.children[0], source)
            if left.endswith('.text'):
                captions[left[:-5]] = label_of(node.children[-1], source)
    controls = []

    def visit(node, owner: dict | None = None):
        """Walk source scopes so nested callback bodies never become their parent's direct calls."""
        if not hasattr(node, 'data'):
            return
        owner = by_start.get(node.meta.start_pos, owner) if str(node.data) in {'func_def', 'lambda', 'abstract_func_def'} else owner
        if owner and owner['name'] != '_button' and str(node.data) in {'standalone_call', 'getattr_call'}:
            expression = mapper.text_of(node.children[0], source)
            callback = None
            caption = ''
            signal = ''
            if expression in {'_button', 'UI.button'}:
                offset = 1 if path.endswith('forward_delivery_panel.gd') else 2
                caption = label_of(node.children[offset], source)
                callback = node.children[offset + 1]
                signal = 'pressed'
            elif expression.endswith('.connect') and len(node.children) >= 2:
                signal_path = expression.removesuffix('.connect')
                receiver, _, signal = signal_path.rpartition('.')
                if signal in INPUT_SIGNALS:
                    caption_receiver = receiver.removesuffix('.get_popup()')
                    caption = captions.get(caption_receiver, caption_receiver.replace('_', ' ').strip()) + ' · ' + signal.replace('_', ' ')
                    callback = node.children[1]
            if callback is not None:
                if hasattr(callback, 'data') and str(callback.data) == 'lambda':
                    target = by_start[callback.meta.start_pos]
                    handler = index.node(target['id'], 'Inline ' + signal + ' handler')
                    calls = index.calls(target)
                else:
                    expression = mapper.text_of(callback, source)
                    identifier = index.resolve(path, expression)
                    target = next((f for f in functions if f['id'] == identifier), None)
                    handler = index.node(identifier) if identifier else {'id': '', 'path': path, 'line': node.meta.line,
                                'name': expression, 'label': expression + ' · engine or runtime callback'}
                    calls = index.calls(target) if target else []
                if path == SHELL:
                    area = 'Shell / navigation'
                elif path.endswith('workforce_panel.gd'):
                    area = 'Workers / Jobs'
                elif path.endswith('forward_delivery_panel.gd'):
                    area = 'Forward supply / advanced'
                elif path.endswith('army_supply_panel.gd'):
                    area = 'Army needs'
                else:
                    area = PANEL_NAMES.get(owner['name'].split('/')[0], 'Other rear controls')
                controls.append({'area': area, 'label': caption, 'signal': signal,
                                 'source': {'id': owner['id'], 'path': path, 'line': node.meta.line,
                                            'name': owner['name'], 'label': caption},
                                 'handler': handler, 'calls': calls})
        for child in node.children:
            visit(child, owner)

    visit(tree)
    return sorted(controls, key=lambda control: control['source']['line'])


def reviewed_flows(index: SourceIndex) -> list[dict]:
    """Define verified signal, placement, timing and refresh chains that cross source files."""
    specs = [
        ('navigation', 'Main navigation', 'Choosing Rear base, Build, Workers / Jobs, Supplies or Production.', [
            (SHELL, '_navigation_button', 'Click navigation button', 'navigation_requested.emit(action)'),
            (MAIN, '_ready', 'Signal connected to navigation handler', 'navigation_requested.connect'),
            (MAIN, '_navigate', 'Queue the selected screen for a presentation frame', 'process_frame.connect'),
            (MAIN, '_apply_navigation', 'Apply the requested screen', ''),
            (BASE, 'show_panel', 'Select the rear panel', ''),
        ]),
        ('more-systems', 'More systems menu', 'The popup has its own handler and emits the same navigation signal.', [
            (SHELL, '_build_navigation', 'Choose a More systems entry', 'advanced.get_popup().id_pressed.connect'),
            (MAIN, '_ready', 'Signal connected to navigation handler', 'navigation_requested.connect'),
            (MAIN, '_navigate', 'Queue the selected panel for a presentation frame', 'process_frame.connect'),
            (MAIN, '_apply_navigation', 'Apply the requested panel', ''),
            (BASE, 'show_panel', 'Show the requested rear panel', ''),
        ]),
        ('build', 'Build: choose and move the blueprint', 'Hover gives provisional footprint feedback without route searches. Full access validation occurs on explicit preview or placement. These are source-checked branches, not a runtime trace.', [
            (BASE, '_construction_panel', 'Click Place on field', '"Place on field"'),
            (BASE, 'select_build_kind', 'Activate placement mode', ''),
            (MAP, 'begin_placement', 'Begin map placement', ''),
            (BASE, 'preview_build_hint_at', 'Handle hover or rotation', ''),
            (BASE, 'preview_build_at', 'Select the provisional branch', 'if full_validation else'),
            (CONSTRUCTION, 'placement_hint', 'Read provisional footprint feedback', ''),
            (CONSTRUCTION, '_footprint_preview', 'Check current bounds and footprint geometry', ''),
        ]),
        ('build-full-preview', 'Build: explicitly check a legal site', 'The exact-coordinate Preview legal site button retains full footprint and access validation. Its result never bypasses fresh checks when placing.', [
            (BASE, '_construction_panel', 'Press Preview legal site', '"Preview legal site"'),
            (BASE, 'preview_build_at', 'Default to the full-validation branch', ''),
            (CONSTRUCTION, 'preview', 'Validate current footprint and access', ''),
        ]),
        ('place', 'Build: click the field', 'The mouse signal creates a site; materials and workers still have to arrive.', [
            (MAP, '_gui_input', 'Left-click emits placement_requested', 'placement_requested.emit'),
            (BASE, '_ready', 'Connect placement_requested', 'placement_requested.connect'),
            (BASE, 'confirm_build_at', 'Confirm the chosen position', ''),
            (CONSTRUCTION, 'place', 'Validate and create the physical site', ''),
            (CONSTRUCTION, 'preview', 'Recheck the clicked pose and all access rules', ''),
            (CONSTRUCTION, 'order_materials', 'Request materials in the empty-field opening', ''),
        ]),
        ('construction-work', 'Build: materials and workers → progress', 'Later simulation work. Placement does not immediately complete a facility.', [
            (CONSTRUCTION, 'set_builders', 'Request construction workers', ''),
            (REAR, 'advance_time', 'Advance shared time and service work', ''),
            (CONSTRUCTION, '_ready', 'Require local materials and present builders', ''),
            (CONSTRUCTION, 'advance_work', 'Consume starting materials and earn work', ''),
            (CONSTRUCTION, 'settle', 'Finish and register the completed facility', ''),
        ]),
        ('production-inputs', 'Work: automatically haul the next batch inputs', 'The selected staffed facility declares its actual missing inputs. Committed changes wake a finite pass; the existing hauling owner still reserves, walks, carries and deposits goods. Source-derived branches, not a runtime trace.', [
            ('game/production/fixed_production.gd', 'set_stock_target', 'Request a production stock target', ''),
            (BASE, '_result', 'Publish the accepted management command', ''),
            (SESSION, 'notify_command', 'Notify committed session changes', ''),
            ('game/logistics/rear_logistics.gd', '_wake', 'Wake a finite logistics pass', ''),
            ('game/logistics/rear_logistics.gd', '_supply_factory', 'Read this facility\'s current demand', ''),
            ('game/logistics/rear_logistics.gd', '_ensure_haul', 'Subtract existing obligations and request only missing goods', ''),
            (REAR, 'request_haul', 'Create real physical hauling demand', ''),
            (REAR, '_start_job', 'Reserve actual goods for an eligible worker', ''),
        ]),
        ('army-needs', 'Army needs: real rifle demand and supply facts', 'A coalesced visible query reads owner facts without advancing time or issuing orders. Rear receipt, forward freight and recipient ammunition are separate facts, not a fabricated shipment lineage. These are source-checked branches, not a runtime trace.', [
            (BASE, '_army_needs_panel', 'Bind the scene-owned panel to the real reader', ''),
            ('game/logistics/army_supply_panel.gd', '_refresh', 'Read once after a visible committed-event burst', ''),
            ('game/logistics/army_supply_view.gd', 'view', 'Read current supply stages and cancellation intent', ''),
            ('game/battlefield/opening_resupply.gd', 'rifle_supply_view', 'Batch reported recipients and actual courier commitments', ''),
            (BASE, '_army_supply_action', 'Re-resolve the clicked action against current state', ''),
            ('game/logistics/rear_logistics.gd', 'resume_automatic_supply', 'Explicitly release cancellation intent without reviving a request', ''),
            (MAIN, '_observe_recipient', 'Open observation only for a valid friendly identity', ''),
            ('game/battlefield/battlefield_view.gd', 'focus_entity', 'Focus the current recipient without a tactical command', ''),
        ]),
        ('army-requests', 'Supplies: request delivery to HQ', 'Available goods are physically staged, loaded, transported and unloaded by existing owners. The same truck returns before the request sends another load. Cancellation holds the unsent remainder. These source-checked branches are not one synchronous call chain.', [
            (BASE, '_orders_panel', 'Press Request delivery to HQ', '"Request delivery to HQ"'),
            (BASE, '_request_army_delivery', 'Submit the chosen type and quantity', ''),
            ('game/logistics/rear_logistics.gd', 'request_delivery', 'Record the request without granting goods', ''),
            ('game/logistics/rear_logistics.gd', '_advance_request', 'Select actual site, stock, truck and Driver', ''),
            ('game/dispatch/dispatch_service.gd', 'accept', 'Accept the physical manifest', ''),
            ('game/dispatch/dispatch_service.gd', '_reserve_cargo', 'Reserve only the outstanding actual cargo', ''),
            ('game/dispatch/dispatch_service.gd', 'depart', 'Depart only after real loading', ''),
            ('game/logistics/rear_logistics.gd', '_advance_request', 'Credit actual unloading once; wait for the truck to return', ''),
        ]),
        ('frontline-freight', 'Army: HQ freight → forward stock → local issue', 'The live opening reports actual shortages. Pure route preparation claims no freight; fresh admission and existing timed physical tasks own the truck and stock. Later Engineer issue changes the recipient\'s actual ammunition. Static branches, not a runtime trace.', [
            ('game/battlefield/opening_resupply.gd', 'tick', 'Observe actual local ammunition deficits', ''),
            ('game/battlefield/opening_resupply.gd', '_dispatch_requested_freight', 'Account for local stock, committed couriers and incoming freight', ''),
            ('game/forward_supply/forward_transport.gd', 'request_deferred', 'Queue private route preparation', ''),
            ('game/forward_supply/forward_transport.gd', 'pump_planning', 'Recheck current route, crew, fuel and source portions', ''),
            ('game/forward_supply/forward_transport.gd', '_request_delivery', 'Reserve exact HQ stock for the admitted job', ''),
            ('game/forward_supply/forward_transport.gd', '_finish_load', 'Finish the real loader\'s handoff to the hull', ''),
            ('game/forward_supply/forward_transport.gd', '_finish_unload', 'Deposit the actual cargo at the forward stop', ''),
            ('game/forward_supply/forward_supply.gd', 'start_issue', 'Start an actual Engineer courier issue', ''),
            ('game/forward_supply/forward_supply.gd', '_finish_drop', 'Hand the real ammunition portion to the recipient', ''),
        ]),
        ('clock', 'Pause / 1× / 2× and the live clock', 'Speed selection and physics callbacks are separate events. Wall-clock models pump once per engine process frame to prevent physics catch-up from repeating expensive work; explicit-delta models retain every step. Elapsed live time remains owed until advanced. These branches are source-derived, not runtime traces.', [
            (SHELL, '_build_header', 'Speed button emits speed_requested', 'speed_requested.emit(value)'),
            (MAIN, '_ready', 'Connect speed_requested', 'speed_requested.connect'),
            (SESSION, 'set_speed', 'Set shared speed', ''),
            (SESSION, '_physics_process', 'Gate duplicate live pumps in this process frame', 'frame == _last_live_process_frame'),
            (SIMULATION, 'tick_live', 'Pump the shared live simulation', ''),
            (SIMULATION, '_pump_live', 'Schedule due decisions and bounded route work separately from simulation transactions', ''),
            (SIMULATION, '_advance_live_quantum', 'Consume actual elapsed-time debt at settled boundaries', ''),
            (REAR, 'advance_time', 'Advance authoritative simulation time', ''),
        ]),
        ('training-read', 'Train: scoped state → visible controls', 'Normal Train reads preserve current training normalization and common HUD facts without broad world snapshots. HQ diagnostics retains its separate broad path. These source links omit intermediate helpers and are not a runtime trace.', [
            (BASE, '_refresh_contents', 'Select the normal Train branch', 'active_panel == "Train"'),
            (BASE, '_refresh_training', 'Refresh only Train and the common HUD', ''),
            (SIMULATION, 'training_view', 'Read fresh training and purchasing facts', ''),
            ('game/training/training_service.gd', 'snapshot', 'Describe current rows and instructor coverage', ''),
            (BASE, '_refresh_training_controls', 'Keep row IDs and render selection details', ''),
        ]),
        ('training-command', 'Train: request → domain result', 'An accepted request assigns real students through existing settlement. Rejected training requests explicitly bypass session notification and world reconciliation; local feedback still refreshes. A request does not itself complete training.', [
            (BASE, '_training_panel', 'Press Request course', '"Request course"'),
            ('game/training/training_service.gd', 'request_course', 'Validate access and capacity, then queue courses', ''),
            ('game/training/training_service.gd', '_result', 'Declare whether reconciliation is required', ''),
            (BASE, '_result', 'Gate reconciliation and show feedback', ''),
            (BASE, '_request_refresh', 'Queue the visible refresh', ''),
        ]),
        ('feedback', 'Command result → visible UI refresh', 'Results requiring reconciliation use after_command synchronously and queue a separate session notification. Explicit read-only training rejections skip both; speed/inspection flags also gate reconciliation. Local feedback and refresh remain available.', [
            (BASE, '_result', 'Handle command feedback', ''),
            (SIMULATION, 'after_command', 'Reconcile the command', ''),
            (BASE, '_request_refresh', 'Coalesce a visible refresh request', ''),
            (BASE, '_refresh', 'Read and display the active panel', ''),
        ]),
        ('notification', 'Deferred session notification', 'A conditional deferred branch from _result() for results requiring reconciliation, not a call made by after_command(). Explicit read-only training rejections bypass it.', [
            (BASE, '_result', 'Queue notify_command for later', 'notify_command.call_deferred'),
            (SESSION, 'notify_command', 'Emit shared state_changed', ''),
            (BASE, '_ready', 'state_changed is connected to refresh requests', 'session.state_changed.connect'),
            (BASE, '_request_refresh', 'Coalesce the visible refresh', ''),
        ]),
        ('new-game', 'Session → New game', 'The confirmation must be accepted before replacing the session.', [
            (SHELL, '_build_header', 'Open the new-game confirmation', '_confirmation.popup_centered'),
            (SHELL, '_build_confirmation', 'Confirmation emits new_session_requested', 'new_session_requested.emit'),
            (MAIN, '_start_playtest', 'Create the empty-field opening', ''),
            (BASE, 'start_empty_field_session', 'Create and bind the replacement game', ''),
            (SESSION, 'replace_simulation', 'Replace the shared simulation', ''),
        ]),
        ('battlefield', 'Battlefield view and selection', 'This screen observes the shared simulation; map selection and objective feedback are read-only. Objective settlement alone records latest actual owner/state changes; current income eligibility is separate from credited requisition.', [
            (MAIN, '_navigate', 'Queue navigation on a reserved presentation frame', 'process_frame.connect'),
            (MAIN, '_apply_navigation', 'Choose Battlefield', '"Battlefield"'),
            (MAIN, '_show_battlefield', 'Show the battlefield view', ''),
            ('game/battlefield/battlefield_view.gd', '_gui_input', 'Click the battlefield map', ''),
            ('game/battlefield/battlefield_view.gd', '_select_nearest', 'Pick the nearest visible marker', ''),
            ('game/battlefield/battlefield_view.gd', '_refresh', 'Refresh the named objective inspector', ''),
            ('game/objectives/objective_service.gd', 'inspect', 'Read detached current objective and latest transition', ''),
            ('game/battlefield/battlefield_presentation.gd', 'objective_feedback', 'Explain current control, income eligibility and credited requisition', ''),
        ]),
    ]
    return [{'id': key, 'title': title, 'note': note,
             'nodes': [index.node(path + '::' + function, label, needle) for path, function, label, needle in steps]}
            for key, title, note, steps in specs]


def source_link(node: dict, style: str = 'node') -> str:
    """Render an escaped clickable source node; portable file URLs are filled in by the local viewer."""
    escape = html.escape
    name = 'inline callback' if '/<lambda#' in node['name'] else node['name'] + '()'
    label = '<span class="node-label">' + escape(node['label']) + '</span>' if node.get('label') else ''
    return (f'<a class="{style}" href="#source-link-help" data-source="{escape(node["path"], quote=True)}" '
            f'data-line="{node["line"]}" title="{escape(node["path"] + ":" + str(node["line"]), quote=True)}">'
            + label + '<code>' + escape(name) + '</code><span class="source">'
            + escape(pathlib.PurePosixPath(node['path']).name) + ':' + str(node['line']) + '</span></a>')


def render(index: SourceIndex, template: str) -> str:
    """Build portable, offline flowcharts with expandable per-panel action-to-handler branches."""
    controls = [control for path in UI_FILES for control in scan_controls(index, path)]
    flows = reviewed_flows(index)
    overview = ''.join(f'<a href="#{flow["id"]}">{html.escape(flow["title"])}</a>' for flow in flows)
    diagrams = []
    for flow in flows:
        nodes = ''.join('<li>' + source_link(node) + '</li>' for node in flow['nodes'])
        diagrams.append(f'<section id="{flow["id"]}" class="workflow"><h2>{html.escape(flow["title"])}</h2>'
                        f'<p>{html.escape(flow["note"])}</p><ol class="chain">{nodes}</ol></section>')
    groups = collections.defaultdict(list)
    for control in controls:
        groups[control['area']].append(control)
    panels = []
    for area, entries in groups.items():
        actions = []
        for entry in entries:
            targets = ''.join(source_link(node) for node in entry['calls']) or '<span class="empty">No resolved project call in this handler.</span>'
            actions.append('<details class="action"><summary>' + html.escape(entry['label']) + '</summary>'
                           '<div class="action-flow"><div><span class="stage">UI event · ' + html.escape(entry['signal']) + '</span>'
                           + source_link(entry['source']) + '</div><div><span class="stage">Connected handler</span>'
                           + source_link(entry['handler']) + '</div><div><span class="stage">Direct script calls · branches may vary</span>'
                           '<div class="targets">' + targets + '</div></div></div></details>')
        panels.append('<details class="panel"><summary>' + html.escape(area) + '<span>' + str(len(entries)) + ' declared controls</span></summary>'
                      + ''.join(actions) + '</details>')
    output = template.replace('<!-- OVERVIEW -->', overview).replace('<!-- WORKFLOWS -->', ''.join(diagrams))
    output = output.replace('<!-- PANELS -->', ''.join(panels)).replace('<!-- CONTROL_COUNT -->', str(len(controls)))
    return output


def button_contracts(index: SourceIndex) -> dict:
    """Inventory declared button/toggle/menu callback obligations for the GdUnit coverage gate."""
    definitions = []
    for path in UI_FILES:
        for control in scan_controls(index, path):
            if control['signal'] not in {'pressed', 'toggled', 'id_pressed'}:
                continue
            caption = control['label']
            for suffix in [' · pressed', ' · toggled', ' · id pressed']:
                caption = caption.removesuffix(suffix)
            dynamic = caption.endswith(' [dynamic label]')
            prefix = ''
            if dynamic:
                match = re.match(r'^"([^"\\]*)"', caption)
                if match:
                    prefix = match[1]
            definitions.append({'id': control['source']['id'] + '@' + str(control['source']['line']),
                                'path': path, 'line': control['source']['line'], 'label': caption,
                                'dynamic': dynamic, 'prefix': prefix, 'area': control['area']})
    return {'schema_version': 1, 'button_definitions': definitions,
            'source_sha256': {path: mapper.digest(index.source(path)) for path in UI_FILES},
            'limits': 'Source obligations plus concrete runtime instances in prepared profiles. A dynamic factory match is not proof of every possible argument or gameplay state.'}


def main() -> int:
    """Generate or check the source-linked UI diagram without launching Godot or changing gameplay."""
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--update', action='store_true')
    mode.add_argument('--check', action='store_true')
    arguments = parser.parse_args()
    document = json.loads((ROOT / 'docs/system_map.json').read_text(encoding='utf-8'))
    index = SourceIndex(ROOT, document)
    result = render(index, (ROOT / TEMPLATE).read_text(encoding='utf-8'))
    obligations = json.dumps(button_contracts(index), ensure_ascii=False, indent=2) + '\n'
    destination = ROOT / OUTPUT
    if arguments.check:
        if not destination.exists() or mapper.normalized_text(destination) != result:
            print('STALE UI function diagram. Run Update System Map.cmd.')
            return 1
        if not (ROOT / CONTRACTS).exists() or mapper.normalized_text(ROOT / CONTRACTS) != obligations:
            print('STALE UI button-test inventory. Run Update System Map.cmd.')
            return 1
        print('PASS: UI function diagram matches current source and line numbers.')
    else:
        destination.write_text(result, encoding='utf-8', newline='\n')
        (ROOT / CONTRACTS).write_text(obligations, encoding='utf-8', newline='\n')
        print('Updated ' + OUTPUT)
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (ValueError, KeyError) as error:
        print('UI function map: ' + str(error))
        raise SystemExit(1)
