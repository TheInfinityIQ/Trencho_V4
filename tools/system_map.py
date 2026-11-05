"""Inventory project files and maintain a source-checked JSON function map.

Only static syntax is inspected. Nothing imports/runs the game's GDScript or
enables an editor plugin. Purpose text lives in the map and survives regeneration;
changed implementations require a new purpose review before --check passes.
"""
from __future__ import annotations

import argparse
import ast
import collections
import hashlib
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
from typing import Any

ROOT = pathlib.Path(__file__).resolve().parents[1]
MAP_PATH = ROOT / 'docs/system_map.json'
SCHEMA_VERSION = 1
PARSER_VERSION = '4.5.0'
MODULE_PURPOSES = {
    'main': 'Own the playable session, shared clock and navigation between screens.',
    'identity': 'Own authoritative entity identity, holders, stock, personnel assignments, claims and conservation.',
    'staffing': 'Schedule rear workers, hauling jobs, movement, shared time and immediate service transitions.',
    'rear_base': 'Integrate the rear simulation and present construction, supply, workforce and command controls.',
    'battlefield': 'Author the opening battlefield and execute/display squad, vehicle, supply and resource orders.',
    'scenario': 'Create the initial rear/battlefield state and join it into a playable session.',
    'procurement': 'Manage requisition balance, incoming purchases, receiving capacity, recruitment and goods catalogues.',
    'production': 'Define recipes/equipment and turn staffed local inputs into manufactured outputs.',
    'construction': 'Place structures, commit local materials and builders, finish sites and dismantle structures.',
    'vehicles': 'Schedule rear fleet operators, vehicle movement, loading and physical access.',
    'dispatch': 'Admit people and vehicles into military service through physical reporting and handover.',
    'hq': 'Issue HQ equipment, ammunition and fuel to eligible recipients using actual local stock.',
    'military': 'Maintain formations, leaders, crews, capabilities and personnel transport.',
    'combat': 'Resolve infantry fire, wounds, morale, suppression, treatment and casualty consequences.',
    'vehicle_combat': 'Resolve vehicle fire, damage, movement effects, destruction and wreck consequences.',
    'vehicle_recovery': 'Authorize and advance physical towing/recovery with crew, route and damage constraints.',
    'orders': 'Deliver command intent, sample battlefield reports and handle delayed/fallback decisions.',
    'objectives': 'Track objective ownership and progress from physically present eligible forces.',
    'forward_supply': 'Allocate forward ammunition/equipment and transport real freight to deployed recipients.',
    'field_structures': 'Build and operate battlefield structures with workers, local materials and access checks.',
    'bridges': 'Build and damage crossings, and place/resolve controlled demolition charges.',
    'mines': 'Place, detect, clear and detonate devices while constraining movement through known hazards.',
    'routes': 'Plan usable routes and validate distance, clearance, crossing load and fuel requirements.',
    'terrain': 'Own terrain geometry, surfaces, obstacles, crossings and bounded route-search work.',
    'training': 'Enroll eligible people, consume course inputs and advance staffed training to qualification.',
    'ui': 'Construct shared controls/themes and provide the command shell/navigation layout.',
    'diagnostics': 'Count runtime calls/stacks and run the opt-in 1x menu performance detector and its guards.',
    'world_probe': 'Measure correctness and data size of a synthetic full-size world without changing the main scene.',
    'overhead_evaluation': 'Compare illustrative map presentation and data overhead in a separate evaluation scene.',
}


def normalized_text(path: pathlib.Path) -> str:
    """Read UTF-8 source with platform-independent line endings for stable hashes."""
    return path.read_text(encoding='utf-8-sig').replace('\r\n', '\n').replace('\r', '\n')


def digest(text: str) -> str:
    """Fingerprint normalized source without embedding complete implementations."""
    return hashlib.sha256(text.encode('utf-8')).hexdigest()


def inventory(root: pathlib.Path) -> list[str]:
    """List every existing tracked or nonignored untracked project file through Git."""
    result = subprocess.check_output(['git', '-C', str(root), 'ls-files', '--cached', '--others', '--exclude-standard', '-z'])
    paths = sorted(set(part.decode('utf-8') for part in result.split(b'\0') if part))
    return [path for path in paths if (root / path).is_file()]


def load_parser() -> Any:
    """Load the pinned GDScript AST parser from project-local or installed dependencies."""
    for folder in ['.tools/system-map-deps', '.tools/gdscript-parser']:
        if (ROOT / folder / 'gdtoolkit').is_dir():
            sys.path.insert(0, str(ROOT / folder))
            break
    try:
        from importlib.metadata import version
        from gdtoolkit.parser import parser
        if version('gdtoolkit') != PARSER_VERSION:
            raise RuntimeError(f'Expected gdtoolkit {PARSER_VERSION}; install tools/system_map_requirements.txt.')
        parser.disable_grammar_caching()
        return parser
    except ImportError as error:
        raise RuntimeError('Install parser dependencies: python -m pip install -r tools/system_map_requirements.txt') from error


def text_of(node: Any, source: str) -> str:
    """Recover the exact expression represented by an AST node or token."""
    location = node.meta if hasattr(node, 'meta') else node
    end = location.end_pos
    if end is None:
        # The grammar's synthetic DEDENT can leave a multiline lambda without
        # an end offset. Slicing to None would silently include the entire
        # remaining file and make unrelated edits change its implementation.
        ends = []
        for child in getattr(node, 'children', []):
            child_location = child.meta if hasattr(child, 'meta') else child
            child_end = getattr(child_location, 'end_pos', None)
            if child_end is not None:
                ends.append(child_end)
            elif hasattr(child, 'meta'):
                child_text = text_of(child, source)
                ends.append(child.meta.start_pos + len(child_text))
        if not ends:
            raise ValueError('AST node has no usable source endpoint.')
        end = max(ends)
    return source[location.start_pos:end].strip()


def compact(text: str, limit: int = 180) -> str:
    """Collapse expression whitespace for a small navigable map entry."""
    value = re.sub(r'\s+', ' ', text).strip()
    return value if len(value) <= limit else value[:limit - 1] + '…'


def own_nodes(node: Any) -> Any:
    """Traverse one implementation without mixing its nested callbacks into its facts."""
    yield node
    for child in getattr(node, 'children', []):
        if hasattr(child, 'data') and str(child.data) not in {'func_def', 'lambda', 'class_def'}:
            yield from own_nodes(child)


def module_of(path: str) -> str:
    """Locate a file's system folder, retaining support/documentation as separate systems."""
    parts = path.split('/')
    return parts[1] if parts[0] == 'game' and len(parts) > 1 else parts[0] if len(parts) > 1 else 'project'


def role_of(path: str) -> str:
    """Distinguish production code, retained tests, demos, resources and support files."""
    if path == 'docs/ui_function_map.html':
        return 'generated_ui_diagram'
    if path == 'tools/ui_function_map_template.html':
        return 'tool_template'
    if path.endswith('.uid'):
        return 'resource_identity'
    if path.endswith('.png'):
        return 'evidence_image'
    if '/tests/' in path:
        return 'test_fixture' if '/fixtures/' in path else 'test'
    if path.endswith('.gd'):
        return 'demo' if path.endswith('_demo.gd') else 'production'
    return {'.tscn': 'scene', '.uid': 'resource_identity', '.md': 'documentation', '.json': 'data',
            '.ps1': 'tool', '.py': 'tool', '.cmd': 'launcher', '.yml': 'workflow'}.get(pathlib.Path(path).suffix, 'configuration')


def file_purpose(path: str, source: str) -> str:
    """Describe a file's actual role using its location, content and known runtime entry."""
    name = pathlib.Path(path).stem.replace('_', ' ')
    if path == 'project.godot':
        return 'Select the playable main scene and configure Godot 4.7, viewport, rendering and disabled editor addons.'
    if path == 'AGENTS.md':
        return 'Require future code changes to refresh and review this system map before reporting completion.'
    if path == 'docs/system_map.json':
        return 'Store this generated file inventory, per-function purpose/facts and static system connections.'
    if path == 'docs/system_overhaul_plan.json':
        return 'Track evidence-linked system migrations, protected behavior, dependencies, planned acceptance checks and bounded implementation progress.'
    if path == 'docs/overhaul_inventory.json':
        return 'Preserve the fingerprinted pre-overhaul GDScript audit and label current source drift against that historical inventory.'
    if path == 'docs/ui_function_map.html':
        return 'Display current UI workflows, declared control callbacks and clickable VS Code file/line navigation without running Godot.'
    if path == 'tools/ui_function_map_template.html':
        return 'Define the offline flowchart layout and resolve portable source-link metadata into local VS Code URLs.'
    if path.endswith('.uid'):
        return 'Preserve Godot resource identity for ' + path[:-4] + '.'
    if path.endswith('.png'):
        return 'Retain image/screenshot evidence for ' + name + '; binary image contents are fingerprinted, not interpreted as source code.'
    if path.endswith('.md'):
        headings = re.findall(r'^#\s+(.+)$', source, re.M)
        return 'Document ' + (headings[0] if headings else name) + '.'
    if path.endswith('.tscn'):
        return 'Declare the scene nodes, attached scripts, resources and saved connections for ' + name + '.'
    if path.endswith('.gd'):
        context = MODULE_PURPOSES.get(module_of(path), name)
        if '/tests/' in path:
            return ('Provide deterministic test call targets for ' if '/fixtures/' in path else 'Verify behavior through ') + name + '.'
        if path.endswith('_demo.gd'):
            return 'Provide the ' + name + ' control/view and connect user actions to its simulation.'
        return context + ' This file implements ' + name + '.'
    if path.endswith('.cmd'):
        return 'Provide a double-click Windows entry point: ' + compact(source.replace('@echo off', ''), 160) + '.'
    if path.endswith(('.py', '.ps1')):
        return 'Run the ' + name + ' development/verification workflow; top-level statements are its entry point.'
    if path.endswith(('.yml', '.yaml')):
        return 'Configure GitHub automation: ' + name + '.'
    if path.endswith('.json'):
        return 'Supply structured settings, dependency pins or catalogue data for ' + name + '.'
    return 'Supply ' + name + ' project settings or repository metadata.'


def gd_functions(path: str, source: str, tree: Any) -> tuple[list[dict], dict]:
    """Extract every named/anonymous function, class field, signal and literal resource from GDScript AST."""
    functions: list[dict] = []
    definitions: dict = {'extends': [], 'classes': [], 'fields': [], 'signals': [], 'enums': [], 'resources': {}}
    lambda_numbers: collections.Counter = collections.Counter()

    def visit(node: Any, owner: str = '', parent: str = '', static: bool = False) -> None:
        if not hasattr(node, 'data'):
            return
        kind = str(node.data)
        if kind == 'class_def':
            owner = '.'.join(filter(None, [owner, str(node.children[0])]))
            definitions['classes'].append(owner)
        if kind in {'func_def', 'lambda', 'abstract_func_def'}:
            header = node.children[0]
            anonymous = kind == 'lambda'
            if anonymous:
                lambda_numbers[parent] += 1
                name = f'{parent}/<lambda#{lambda_numbers[parent]}>'
            else:
                name = '.'.join(filter(None, [owner, str(header.children[0])]))
            identifier = path + '::' + name
            own = list(own_nodes(node))
            calls: dict[str, int] = {}
            writes: set[str] = set()
            returns: list[str] = []
            connections: list[str] = []
            callbacks: list[dict] = []
            emits: set[str] = set()
            for part in own:
                part_kind = str(part.data)
                if part_kind in {'standalone_call', 'getattr_call'}:
                    call = compact(text_of(part.children[0], source), 300)
                    calls.setdefault(call, part.meta.line)
                    if call.endswith(('.connect', '.disconnect', '.call_deferred')):
                        connections.append(compact(text_of(part, source), 400))
                    if call.endswith(('.connect', '.disconnect')) and len(part.children) > 1:
                        callbacks.append({'operation': call, 'callback': compact(text_of(part.children[1], source), 400), 'line': part.meta.line})
                    if call.endswith('.emit'):
                        emits.add(call[:-5])
                if part_kind == 'assnmnt_expr':
                    writes.add(compact(text_of(part.children[0], source), 120))
                if part_kind == 'return_stmt':
                    returns.append(compact(text_of(part, source).removeprefix('return').strip()))
            signature = ('static ' if static else '') + compact(text_of(header, source), 400)
            implementation = text_of(node, source)
            code = ('static\n' if static else '') + implementation
            start_line = source.count('\n', 0, node.meta.start_pos) + 1
            end_line = start_line + len(implementation.splitlines()) - 1
            functions.append({'id': identifier, 'name': name, 'kind': 'lambda' if anonymous else 'method',
                              'line': start_line, 'end_line': end_line, 'signature': signature,
                              'code_sha256': digest(code), 'calls_raw': calls, 'writes': sorted(writes),
                              'returns': sorted(set(returns)), 'emits': sorted(emits), 'connections': connections,
                              'callbacks': callbacks, 'source': code, 'parent': path + '::' + parent if parent else ''})
            parent = name
        if not parent:
            if kind == 'extends_stmt':
                definitions['extends'].append(compact(text_of(node, source)))
            if kind in {'class_var_stmt', 'const_stmt'}:
                declaration = compact(text_of(node, source), 450)
                definitions['fields'].append(declaration)
                match = re.search(r'(?:const|var)\s+(\w+).*?preload\(["\']res://([^"\']+)', declaration)
                if match:
                    definitions['resources'][match[1]] = match[2]
            if kind in {'signal_stmt', 'enum_stmt'}:
                definitions['signals' if kind == 'signal_stmt' else 'enums'].append(compact(text_of(node, source), 600))
        for child in node.children:
            visit(child, owner, parent, static=kind == 'static_func_def')

    visit(tree)
    return functions, definitions


def python_functions(path: str, source: str) -> list[dict]:
    """Map Python definitions/lambdas from the standard-library AST, including nested scopes."""
    tree = ast.parse(source, filename=path)
    result: list[dict] = []
    counters: collections.Counter = collections.Counter()

    def own(node: ast.AST) -> Any:
        """Yield a Python implementation's nodes while excluding nested implementations."""
        yield node
        for child in ast.iter_child_nodes(node):
            if not isinstance(child, (ast.FunctionDef, ast.AsyncFunctionDef, ast.Lambda, ast.ClassDef)):
                yield from own(child)

    def visit(node: ast.AST, owner: str = '') -> None:
        if isinstance(node, ast.ClassDef):
            owner = '.'.join(filter(None, [owner, node.name]))
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.Lambda)):
            is_lambda = isinstance(node, ast.Lambda)
            counters[owner] += is_lambda
            name = f'{owner}/<lambda#{counters[owner]}>' if is_lambda else '.'.join(filter(None, [owner, node.name]))
            code = ast.get_source_segment(source, node) or ''
            owned = list(own(node))
            calls = {ast.unparse(child.func): child.lineno for child in owned if isinstance(child, ast.Call)}
            returns = [compact(ast.unparse(child.value)) for child in owned if isinstance(child, ast.Return) and child.value is not None]
            result.append({'id': path + '::' + name, 'name': name, 'kind': 'lambda' if is_lambda else 'function',
                           'line': node.lineno, 'end_line': node.end_lineno, 'signature': compact(code.splitlines()[0]),
                           'code_sha256': digest(code), 'calls_raw': calls, 'source': code, 'writes': [],
                           'returns': returns, 'emits': [], 'connections': [],
                           'docstring': '' if is_lambda else ast.get_docstring(node) or ''})
            owner = name
        for child in ast.iter_child_nodes(node):
            visit(child, owner)

    visit(tree)
    return result


def powershell_functions(root: pathlib.Path) -> dict[str, list[dict]]:
    """Ask PowerShell's native parser for named functions, inline scriptblocks and scoped command dependencies."""
    executable = shutil.which('pwsh') or shutil.which('powershell')
    if not executable:
        raise RuntimeError('PowerShell is required to inspect .ps1 files (pwsh on Linux).')
    output = subprocess.check_output([executable, '-NoProfile', '-File', str(root / 'tools/system_map_powershell.ps1'), '-Root', str(root)], cwd=root, text=True, encoding='utf-8-sig')
    records: dict[str, list[dict]] = {}
    for file in json.loads(output):
        records[file['path']] = []
        for function in file['functions']:
            code = function['source'].replace('\r\n', '\n')
            records[file['path']].append({'id': file['path'] + '::' + function['name'], 'name': function['name'],
                'kind': function['kind'], 'parent': file['path'] + '::' + function['parent'] if function['parent'] else '', 'line': function['line'], 'end_line': function['end_line'],
                'signature': code.splitlines()[0], 'code_sha256': digest(code), 'source': code,
                'calls_raw': {call: function['line'] for call in function['calls']}, 'writes': [], 'returns': [], 'emits': [], 'connections': []})
    return records


def words(value: str) -> str:
    """Turn an identifier into readable words while retaining names in the detailed facts."""
    return re.sub(r'\s+', ' ', value.replace('_', ' ').strip())


def derive_purpose(function: dict, path: str) -> str:
    """Draft a body-backed purpose for initial inventory; future changes require review."""
    if function.get('docstring'):
        return compact(function['docstring'].split('\n\n')[0], 450)
    name = function['name'].split('.')[-1]
    context = words(pathlib.Path(path).stem)
    calls = [call for call in function['calls_raw'] if not call.endswith('.record')]
    returns = [value for value in function['returns'] if value]
    if not calls and not returns and not function['writes'] and re.search(r':\s*pass\s*$', function['source']):
        return 'Provide an intentionally empty ' + ('callback' if function['kind'] == 'lambda' else 'interface/extension hook') + ' for ' + context + '; this implementation performs no work.'
    if function['kind'] == 'lambda':
        if path.endswith('.ps1'):
            return 'Provide an inline PowerShell callback for ' + context + ': ' + compact(function['source'], 240)
        if returns:
            return 'Provide an inline callback that returns ' + compact(returns[-1], 180) + '.'
        actions = []
        if function['writes']:
            actions.append('update ' + ', '.join(function['writes']))
        if calls:
            actions.append('invoke ' + ', '.join(calls[:4]))
        return 'Provide an inline callback for ' + context + ('; ' + '; '.join(actions) if actions else '; evaluate its inline expression') + '.'
    if name.startswith('test_'):
        return 'Verify ' + words(name[5:]) + ' in ' + context + '.'
    if name in {'_ready', '_initialize'} and '/tests/' in path:
        return 'Run the ' + context + ' standalone checks, report failures and exit with the verification outcome.'
    success = re.findall(r'(?:_ok|_result|_success)\(\s*(?:true\s*,\s*)?["\']([^"\'\n]+)', function['source'])
    if success and name not in {'_ok', '_result', '_success'}:
        messages = list(dict.fromkeys(success))[:3]
        return 'Validate and apply ' + words(name) + ' in ' + context + '. Successful outcomes: ' + ' / '.join(messages)
    standard = {
        '_init': 'Initialize ' + context + ' state and retain its supplied dependencies.',
        '_ready': 'Create/connect ' + context + ' when its node enters the scene tree.',
        '_initialize': 'Initialize ' + context + ' and begin its standalone checks or scene setup.',
        '_process': 'Run the per-render-frame ' + context + ' update using elapsed real time.',
        '_physics_process': 'Run the fixed-physics-step ' + context + ' update.',
        '_draw': 'Draw the current ' + context + ' state using Godot canvas primitives.',
        '_gui_input': 'Translate GUI input events into ' + context + ' selection or commands.',
        '_input': 'Handle incoming input events for ' + context + '.',
        '_unhandled_input': 'Handle input not consumed by controls in ' + context + '.',
        '_exit_tree': 'Release connections/resources owned by ' + context + ' as its node exits.',
        '_refresh': 'Rebuild visible ' + context + ' controls/text from current simulation state.',
        '_request_refresh': 'Request a visible ' + context + ' refresh, coalescing work when supported.',
        'snapshot': 'Export the current ' + context + ' state as a detached inspection dictionary.',
        'settle': 'Resolve immediately eligible ' + context + ' transitions and report whether state changed.',
        '_settle': 'Resolve immediately eligible ' + context + ' transitions until a stable boundary is reached.',
        'next_boundary': 'Return the next scheduled ' + context + ' event time for the shared scheduler.',
        '_fail': 'Return a failed ' + context + ' command result with the supplied explanation.',
        '_result': 'Build a structured ' + context + ' result from its success flag and explanation.',
        '_check': 'Record whether a ' + context + ' verification condition holds and report failures.',
        '_assert': 'Record/report a ' + context + ' verification assertion.',
    }
    if name in standard:
        purpose = standard[name]
    elif name.startswith(('_build_', 'build_')) and any('Container.new' in call or 'Label.new' in call for call in calls):
        purpose = 'Build the ' + words(re.sub(r'^_?build_', '', name)) + ' interface and attach its controls/callbacks in ' + context + '.'
    elif name == 'advance_to':
        purpose = 'Advance scheduled ' + context + ' work to the supplied simulation time.'
    elif name == 'advance_time':
        purpose = 'Advance ' + context + ' by the supplied elapsed simulation time, resolving scheduled boundaries.'
    elif name.startswith('_on_'):
        purpose = 'Handle ' + words(name[4:]) + ' events for ' + context + '.'
    elif name.startswith(('_test_', '_case_')):
        purpose = 'Exercise ' + words(name.lstrip('_').split('_', 1)[-1]) + ' and verify its expected behavior in ' + context + '.'
    elif len(returns) == 1 and len(function['source'].splitlines()) <= 6:
        purpose = 'Return ' + compact(returns[0], 230) + ' for ' + context + '.'
    elif name.startswith(('is_', 'has_', 'can_', '_is_', '_has_', '_can_')):
        purpose = 'Check whether ' + words(re.sub(r'^_?(is|has|can)_', '', name)) + ' holds for ' + context + '.'
    elif name.startswith(('set_', '_set_')):
        purpose = 'Set ' + words(re.sub(r'^_?set_', '', name)) + ' for ' + context + ', applying its validation and side effects.'
    else:
        purpose = words(name).capitalize() + ' for ' + context + '.'
    evidence: list[str] = []
    if calls:
        evidence.append('calls ' + ', '.join(calls[:4]))
    if function['writes']:
        evidence.append('updates ' + ', '.join(function['writes'][:4]))
    if function['emits']:
        evidence.append('emits ' + ', '.join(function['emits']))
    return purpose + (' Implementation: ' + '; '.join(evidence) + '.' if evidence else '')


def link_calls(files: dict[str, dict]) -> dict[str, list[str]]:
    """Resolve local/preloaded calls, index dynamic candidates and compact unmatched external/dynamic expressions."""
    by_name: dict[str, list[str]] = collections.defaultdict(list)
    by_id: dict[str, dict] = {}
    for file in files.values():
        for function in file['functions']:
            by_id[function['id']] = function
            if function['kind'] != 'lambda':
                by_name[function['name'].split('.')[-1]].append(function['id'])
    for path, file in files.items():
        dependencies = file.get('definitions', {}).get('resources', {})
        for function in file['functions']:
            calls = []
            external = []
            for expression, line in sorted(function.pop('calls_raw').items()):
                target = ''
                if path + '::' + expression in by_id:
                    target = path + '::' + expression
                elif '.' in function['name'] and path + '::' + function['name'].rsplit('.', 1)[0] + '.' + expression in by_id:
                    target = path + '::' + function['name'].rsplit('.', 1)[0] + '.' + expression
                elif expression.startswith('self.') and path + '::' + expression[5:] in by_id:
                    target = path + '::' + expression[5:]
                elif '.' in expression:
                    alias, method = expression.split('.', 1)
                    if alias in dependencies:
                        candidate = dependencies[alias] + '::' + ('_init' if method == 'new' else method)
                        if candidate in by_id:
                            target = candidate
                call = {'expression': expression, 'line': line}
                if target:
                    call['target'] = target
                else:
                    name = expression.rsplit('.', 1)[-1]
                    candidates = by_name.get(name, [])
                    if candidates:
                        call['candidate_group'] = name
                        call['resolution'] = 'unresolved_receiver'
                    else:
                        external.append(expression)
                        continue
                calls.append(call)
            function['calls'] = calls
            function['external_or_dynamic_calls'] = external
            for callback in function.get('callbacks', []):
                expression = callback['callback']
                method = re.sub(r'\.(bind|unbind)\(.*', '', expression)
                identifier = path + '::' + method.removeprefix('self.')
                if identifier in by_id:
                    callback['target'] = identifier
                elif expression.startswith('func'):
                    matches = [nested for nested in file['functions'] if nested.get('parent') == function['id'] and nested['line'] == callback['line']]
                    if len(matches) == 1:
                        callback['target'] = matches[0]['id']
                if 'target' not in callback:
                    callback['resolution'] = 'dynamic_callback_expression'
    return dict(sorted((name, sorted(ids)) for name, ids in by_name.items()))


def read_previous() -> dict:
    """Read maintained purpose text and reviewed implementation hashes from the existing map."""
    return json.loads(MAP_PATH.read_text(encoding='utf-8')) if MAP_PATH.exists() else {}


def build_map(previous: dict, initialize: bool = False) -> dict:
    """Read every in-scope file, parse all code and build a deterministic source-linked system map."""
    parser = load_parser()
    paths = inventory(ROOT)
    ps_functions = powershell_functions(ROOT)
    files: dict[str, dict] = {}
    old_functions = {function['id']: function for file in previous.get('files', {}).values() for function in file.get('functions', [])}
    for path in paths:
        if path == 'docs/system_map.json':
            continue
        raw = (ROOT / path).read_bytes()
        try:
            source = normalized_text(ROOT / path)
            source_hash = digest(source)
        except UnicodeDecodeError:
            source = ''
            source_hash = hashlib.sha256(raw).hexdigest()
        file: dict = {'role': role_of(path), 'system': module_of(path), 'sha256': source_hash,
                      'lines': len(source.splitlines()), 'purpose': file_purpose(path, source), 'functions': []}
        if path.endswith('.gd'):
            file['functions'], file['definitions'] = gd_functions(path, source, parser.parse(source, gather_metadata=True))
        elif path.endswith('.py'):
            file['functions'] = python_functions(path, source)
        elif path.endswith('.ps1'):
            file['functions'] = ps_functions.get(path, [])
        elif path.endswith(('.tscn', '.tres')):
            file['resources'] = sorted(set(re.findall(r'path="res://([^"]+)"', source)))
            file['nodes'] = re.findall(r'^\[node (.+)\]$', source, re.M)
            file['connections'] = re.findall(r'^\[connection (.+)\]$', source, re.M)
        if path == 'project.godot':
            file['main_scene'] = re.search(r'run/main_scene="([^"]+)"', source).group(1)
        if path.endswith(('.gd', '.tscn', '.tres')):
            file['resource_dependencies'] = sorted(set(re.findall(r'["\']res://([^"\'\n]+)["\']', source)))
        for function in file['functions']:
            old = old_functions.get(function['id'], {})
            unchanged = old.get('purpose_code_sha256') == function['code_sha256']
            keep_reviewed = old.get('purpose_origin') == 'reviewed'
            function['purpose'] = (old.get('purpose') if keep_reviewed or not unchanged else '') or derive_purpose(function, path)
            function['purpose_origin'] = old.get('purpose_origin', 'implementation_derived')
            function['purpose_code_sha256'] = old.get('purpose_code_sha256', function['code_sha256'] if initialize else '')
            function['purpose_review_required'] = not (unchanged or initialize)
            function.pop('docstring', None)
            function.pop('source', None)
        files[path] = file
    files['docs/system_map.json'] = {'role': 'generated_map', 'system': 'docs', 'purpose': file_purpose('docs/system_map.json', ''), 'functions': []}
    files = dict(sorted(files.items()))
    call_candidates = link_calls(files)
    reachable: set[str] = set()
    pending = [files.get('project.godot', {}).get('main_scene', '').removeprefix('res://')]
    while pending:
        path = pending.pop()
        if path in reachable or path not in files:
            continue
        reachable.add(path)
        pending.extend(files[path].get('resource_dependencies', []))
    for path, file in files.items():
        if path.endswith(('.gd', '.tscn', '.tres')):
            file['statically_reached_from_main_scene'] = path in reachable
    systems = {}
    for name in sorted(set(file['system'] for file in files.values())):
        members = [path for path, file in files.items() if file['system'] == name]
        resources = sorted(set(target for path in members for target in files[path].get('definitions', {}).get('resources', {}).values()))
        systems[name] = {'purpose': MODULE_PURPOSES.get(name, {'docs': 'Describe design, implementation, evidence and working conventions.', 'tools': 'Install dependencies, validate code and maintain development reports.', '.github': 'Define automated repository validation and retained workflow configuration.', 'project': 'Configure the Godot project and provide Windows launchers.'}.get(name, name)), 'files': members, 'loads': resources}
    functions = [function for file in files.values() for function in file['functions']]
    identifiers = [function['id'] for function in functions]
    if len(identifiers) != len(set(identifiers)):
        raise RuntimeError('Duplicate function IDs detected; qualify nested definitions before generating a map.')
    return {'schema_version': SCHEMA_VERSION,
            'scope': {'inventory': 'Every existing tracked or nonignored untracked project file, including retained tests/demos, hidden project configuration and support code.',
                      'excluded': ['.git internals', 'Godot import cache (.godot)', 'ignored logs, exports, .artifacts and .tools caches/downloaded third-party addons', 'ignored secrets'],
                      'generated_map_hash': 'The map inventories itself without hashing its own content.',
                      'purpose_policy': 'Initial implementation-derived descriptions are explicit in purpose_origin. Reviewed prose is retained. After any function change, --update marks its purpose for review; --check fails until --purpose records a current explanation.',
                      'graph_limits': 'Static calls only. Unproven receivers reference call_candidates, not proven runtime edges. Unmatched calls are retained compactly in external_or_dynamic_calls, which can include unresolved runtime targets. Signal/deferred connections are retained. Assignments include locals, not a complete side-effect analysis. Literal resource reachability is conservative (including resource-like strings/comments), not proof of execution. No execution/test coverage is implied.'},
            'entry_points': {'main_scene': files.get('project.godot', {}).get('main_scene', ''), 'runtime_session': 'game/main/game_session.gd', 'clock_callback': 'game/main/game_session.gd::_physics_process'},
            'totals': {'files': len(files), 'functions': len(functions), 'named_functions': sum(function['kind'] != 'lambda' for function in functions), 'anonymous_functions': sum(function['kind'] == 'lambda' for function in functions), 'purpose_reviews_required': sum(function['purpose_review_required'] for function in functions)},
            'systems': systems, 'call_candidates': call_candidates, 'files': files}


def write_map(document: dict) -> None:
    """Write deterministic JSON, keeping one compact function record per line for focused reads/diffs."""
    lines = ['{']
    for key in ['schema_version', 'scope', 'entry_points', 'totals', 'systems', 'call_candidates']:
        lines.append('  ' + json.dumps(key) + ': ' + json.dumps(document[key], ensure_ascii=False, separators=(',', ':')) + ',')
    lines.append('  "files": {')
    entries = list(document['files'].items())
    for index, (path, file) in enumerate(entries):
        header = {key: value for key, value in file.items() if key != 'functions'}
        lines.append('    ' + json.dumps(path) + ': ' + json.dumps(header, ensure_ascii=False, separators=(',', ':'))[:-1] + ',"functions":[')
        for number, function in enumerate(file['functions']):
            lines.append('      ' + json.dumps(function, ensure_ascii=False, separators=(',', ':')) + (',' if number + 1 < len(file['functions']) else ''))
        lines.append('    ]}' + (',' if index + 1 < len(entries) else ''))
    lines.extend(['  }', '}'])
    MAP_PATH.parent.mkdir(parents=True, exist_ok=True)
    MAP_PATH.write_text('\n'.join(lines) + '\n', encoding='utf-8', newline='\n')


def changes_between(previous: dict, current: dict) -> list[str]:
    """Explain stale inventory/hash/function differences without dumping the entire map."""
    changes = []
    old_files, new_files = previous.get('files', {}), current['files']
    for path in sorted(old_files.keys() | new_files.keys()):
        if path not in old_files:
            changes.append('added file: ' + path)
        elif path not in new_files:
            changes.append('removed file: ' + path)
        elif old_files[path].get('sha256') != new_files[path].get('sha256'):
            changes.append('changed file: ' + path)
    for file in new_files.values():
        changes.extend('review purpose: ' + function['id'] for function in file['functions'] if function['purpose_review_required'])
    return changes


def main() -> int:
    """Dispatch generation, stale-document validation and narrow map queries/purpose reviews."""
    arguments = argparse.ArgumentParser(description=__doc__)
    mode = arguments.add_mutually_exclusive_group(required=True)
    mode.add_argument('--initialize', action='store_true', help='Create the initial baseline; never replace an existing map.')
    mode.add_argument('--update', action='store_true', help='Refresh structure and mark changed purposes for review.')
    mode.add_argument('--check', action='store_true', help='Fail if the map is stale or purpose review is pending.')
    mode.add_argument('--query', metavar='PATH_OR_FUNCTION', help='Read one file/function or search its stable ID.')
    mode.add_argument('--callers', metavar='FUNCTION_ID', help='Show definite callers and separate possible dynamic callers.')
    mode.add_argument('--purpose', nargs=2, metavar=('FUNCTION_ID', 'TEXT'), help='Review a purpose against current function source.')
    mode.add_argument('--review-file', metavar='JSON_PATH', help='Review multiple purposes from an ID-to-text JSON object.')
    options = arguments.parse_args()
    previous = read_previous()
    if options.query or options.callers:
        if not previous:
            raise RuntimeError('The system map has not been created.')
        if options.query:
            if options.query in previous['files']:
                found = {options.query: previous['files'][options.query]}
            else:
                found = [function for file in previous['files'].values() for function in file['functions'] if options.query.lower() in function['id'].lower()]
        else:
            found = {'definite': [], 'possible_unresolved': []}
            for file in previous['files'].values():
                for function in file['functions']:
                    for call in function['calls']:
                        if call.get('target') == options.callers:
                            found['definite'].append({'caller': function['id'], 'call': call})
                        elif options.callers in previous['call_candidates'].get(call.get('candidate_group', ''), []):
                            found['possible_unresolved'].append({'caller': function['id'], 'call': call})
        print(json.dumps(found, ensure_ascii=False, indent=2))
        return 0
    if options.initialize and previous:
        raise RuntimeError('Refusing to replace existing purpose text with a fresh baseline. Use --update.')
    document = build_map(previous, initialize=options.initialize)
    if options.purpose or options.review_file:
        purposes = dict([options.purpose]) if options.purpose else json.loads(pathlib.Path(options.review_file).read_text(encoding='utf-8-sig'))
        for identifier, purpose in purposes.items():
            matches = [function for file in document['files'].values() for function in file['functions'] if function['id'] == identifier]
            if len(matches) != 1 or not isinstance(purpose, str) or not purpose.strip():
                raise RuntimeError('Provide one exact function ID and a nonempty purpose: ' + identifier)
            matches[0].update(purpose=purpose.strip(), purpose_origin='reviewed', purpose_code_sha256=matches[0]['code_sha256'], purpose_review_required=False)
        document['totals']['purpose_reviews_required'] = sum(function['purpose_review_required'] for file in document['files'].values() for function in file['functions'])
    changes = changes_between(previous, document)
    if options.check:
        if previous != document or document['totals']['purpose_reviews_required']:
            print('STALE system map. Run the update command and review changed purposes.')
            print('\n'.join(changes[:100]) or 'Map structure/tooling metadata differs; regenerate it.')
            return 1
        print('PASS: system map matches every in-scope file and function; no purpose review is pending.')
    else:
        write_map(document)
        print(json.dumps(document['totals']))
        if changes and not options.initialize:
            print('\n'.join(changes[:100]))
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (RuntimeError, ValueError, subprocess.CalledProcessError) as error:
        print('System map error: ' + str(error), file=sys.stderr)
        raise SystemExit(2) from error
