"""Build source-validated, offline per-system diagrams; never start Godot."""
from __future__ import annotations

import argparse
import hashlib
import html
import json
from pathlib import Path
import re
import textwrap

ROOT = Path(__file__).resolve().parents[1]
CATALOG = 'docs/system_atlas_catalog.json'
TEMPLATE = 'tools/system_atlas_template.html'
OUTPUTS = ('docs/system_atlas.json', 'docs/system_atlas.html', 'docs/system_atlas.md')


def digest(text: str) -> str:
    """Fingerprint normalized source text consistently on Windows and Linux."""
    return hashlib.sha256(text.encode('utf-8')).hexdigest()


def build() -> dict:
    """Validate reviewed sources/references and assign every inventoried game script."""
    catalog = json.loads((ROOT / CATALOG).read_text(encoding='utf-8'))
    mapped = json.loads((ROOT / 'docs/system_map.json').read_text(encoding='utf-8'))
    systems = {s['id']: {**s, 'files': []} for s in catalog['systems']}
    assert len(systems) == len(catalog['systems']), 'Duplicate system ID'
    game = {p: f for p, f in mapped['files'].items() if p.startswith('game/') and p.endswith('.gd')}
    actual = {p.relative_to(ROOT).as_posix() for p in (ROOT / 'game').rglob('*.gd') if not any(part in ['.godot', 'addons'] for part in p.parts)}
    assert set(game) == actual, 'Update the maintained system map for current game script inventory first'
    owners = catalog['file_owners']
    assert set(owners) == {p for p in game if '/tests/' not in p}, 'Review primary ownership for new/removed non-test scripts'
    changed = [p for p, sha in catalog['reviewed_sources'].items() if not (ROOT / p).is_file() or digest((ROOT / p).read_text(encoding='utf-8')) != sha]
    assert set(catalog['reviewed_sources']) == set(owners), 'Reviewed-source coverage differs from ownership'
    assert not changed, 'Review affected system descriptions and update reviewed_sources hashes: ' + ', '.join(changed)
    for path, file in sorted(game.items()):
        source = (ROOT / path).read_text(encoding='utf-8')
        assert digest(source) == file['sha256'], 'Stale function-map source: ' + path
        if '/tests/' in path:
            module = path.split('/')[1]
            owner = next((s['id'] for s in catalog['systems'] if any(p.startswith('game/' + module + '/') for p in s['primary_files'])), 'reviews')
            kind = 'retained test — not executed'
        else:
            owner = owners[path]
            kind = 'optional review / fixture / probe' if owner == 'reviews' else ('retained performance harness — not executed' if path.endswith('/menu_performance_suite.gd') else 'implementation / presentation / data')
        functions = [{k: f[k] for k in ('id', 'name', 'line', 'end_line', 'kind', 'purpose', 'purpose_origin')} for f in file['functions']]
        systems[owner]['files'].append({'path': path, 'sha256': file['sha256'], 'classification': kind, 'functions': functions})
    for system in systems.values():
        assert all(s in systems for s in system['related']), system['id']
        nodes = {n['id'] for n in system['nodes']}
        assert len(nodes) == len(system['nodes'])
        for node in system['nodes']:
            assert node['file'] in game, node['file']
            if node.get('function'):
                matches = [f for f in game[node['file']]['functions'] if f['name'] == node['function'] and f['kind'] != 'lambda']
                assert len(matches) == 1, f"Ambiguous/missing function: {node}"
                node['line'] = matches[0]['line']
                line = (ROOT / node['file']).read_text(encoding='utf-8').splitlines()[node['line'] - 1]
                assert re.search(r'\bfunc\s+' + re.escape(node['function']) + r'\s*\(', line), 'Stale source line'
            else:
                node['line'] = 1
        assert all(e['from'] in nodes and e['to'] in nodes for e in system['edges'])
    assert all(e['from'] in systems and e['to'] in systems for e in catalog['overview'])
    return {k: catalog[k] for k in ('schema', 'title', 'reviewed_baseline', 'workspace_hint', 'diagram_semantics')} | {
        'source_fingerprint': digest(json.dumps({p: f['sha256'] for p, f in sorted(game.items())}, sort_keys=True)),
        'totals': {'systems': len(systems), 'game_scripts': len(game), 'non_test_scripts': len(owners),
                   'retained_test_scripts': len(game) - len(owners), 'functions_in_inventory': sum(len(f['functions']) for f in game.values()),
                   'diagram_function_links': sum(bool(n.get('function')) for s in systems.values() for n in s['nodes'])},
        'systems': list(systems.values()), 'overview': catalog['overview'],
        'limits': ['Source inspection only; no engine, test suite or runtime trace executed for this atlas.',
                   'Folder/diagram groupings are documentation boundaries, not invented classes or autoloads.',
                   'Inherited function purposes retain their original review/derivation status; inventory is not proof of semantic review of every function.',
                   'Default F5 main and opt-in F6 3D preview share services; optional review scenes may create separate sessions.',
                   'Full ordinary factory/supply/repeat loop, complete 3D parity, native input and 60FPS acceptance remain open.']}


def svg(nodes: list[dict], edges: list[dict], overview: bool = False) -> str:
    """Render a static accessible SVG with branch labels and clickable source/system nodes."""
    cols = 4 if overview else 2
    gap_x, gap_y = 500, 190
    width, height = cols * gap_x + 40, ((len(nodes) + cols - 1) // cols) * gap_y + 45
    positions = {n['id']: (30 + (i % cols) * gap_x, 24 + (i // cols) * gap_y) for i, n in enumerate(nodes)}
    esc = html.escape
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" role="img" aria-label="{esc("System overview" if overview else "Individual system workflow")}" viewBox="0 0 {width} {height}">',
             '<defs><marker id="arrow" markerWidth="9" markerHeight="9" refX="8" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8" fill="#b4c9cf"/></marker></defs>']
    for e in edges:
        ax, ay = positions[e['from']]; bx, by = positions[e['to']]
        if ay == by:
            x1, y1, x2, y2 = (ax + 310, ay + 54, bx, by + 54) if ax < bx else (ax, ay + 54, bx + 310, by + 54)
            path = f'M{x1},{y1} L{x2},{y2}'
        else:
            x1, y1, x2, y2 = ax + 155, ay + 108, bx + 155, by
            if ay > by: x1, y1, x2, y2 = ax + 300, ay, bx + 300, by + 108
            mid = (y1 + y2) / 2
            path = f'M{x1},{y1} C{x1},{mid} {x2},{mid} {x2},{y2}'
        parts.append(f'<g class="edge"><path d="{path}" fill="none" stroke="#829da7" stroke-width="1.6" marker-end="url(#arrow)"/><title>{esc(e["label"])}</title></g>')
        # Full edge descriptions are also readable outside the SVG and on hover.
        if not overview:
            mx, my = (x1 + x2) / 2, (y1 + y2) / 2
            label = textwrap.shorten(e['label'], width=32, placeholder='…')
            parts.append(f'<text class="edge-label" x="{mx}" y="{my - 6}" text-anchor="middle" paint-order="stroke" stroke="#111e27" stroke-width="5" fill="#d2dee2" font-size="11">{esc(label)}</text>')
    for n in nodes:
        x, y = positions[n['id']]
        attrs = f'data-system="{esc(n["id"])}" href="#{esc(n["id"])}"' if overview else f'data-file="{esc(n["file"])}" data-line="{n["line"]}" href="#source"'
        parts.append(f'<a {attrs}><g class="node"><rect x="{x}" y="{y}" width="310" height="108" rx="10" fill="#1b3442" stroke="#72d0b2"/><title>{esc(n.get("file",n["label"]))}:{n.get("line",1)}</title>')
        for j, line in enumerate(textwrap.wrap(n['label'], 37)[:3]):
            parts.append(f'<text x="{x+14}" y="{y+25+j*18}" fill="#f3f7f8" font-size="14">{esc(line)}</text>')
        sub = n.get('function', '') or (n.get('file', '').split('/')[-1] if not overview else n.get('group', ''))
        parts.append(f'<text x="{x+14}" y="{y+91}" fill="#aac4d0" font-size="11">{esc(textwrap.shorten(sub,44,placeholder="…"))}</text></g></a>')
    return ''.join(parts) + '</svg>'


def render(document: dict) -> dict[str, str]:
    """Generate the offline viewer, queryable JSON and portable Markdown diagrams."""
    systems = document['systems']
    selected = {e[k] for e in document['overview'] for k in ('from', 'to')}
    overview_nodes = [{'id': s['id'], 'label': s['title'], 'group': s['group']} for s in systems if s['id'] in selected]
    payload = {**document, 'overview_svg': svg(overview_nodes, document['overview'], True)}
    for s in payload['systems']:
        s['svg'] = svg(s['nodes'], s['edges'])
    embedded = json.dumps(payload, ensure_ascii=False).replace('<', '\\u003c')
    page = (ROOT / TEMPLATE).read_text(encoding='utf-8').replace('__ATLAS_DATA__', embedded)
    md = ['# Current game systems — implementation atlas', '', f"Reviewed game baseline: `{document['reviewed_baseline']}`.", '',
          '[Open the offline interactive atlas](system_atlas.html) · [Reviewed catalog](system_atlas_catalog.json) · [Queryable inventory](system_atlas.json)', '',
          'The HTML contains an overview, individual diagrams, filtering, source inventory and VS Code links. These are source-observed conditional workflows and dependencies, not measured call stacks.', '',
          'People share one Person/ledger implementation; vehicles span several activity owners; workshops reuse a common batch engine. A shared advance_time/settlement coordinator still connects rear and battlefield. The manager is separate from the worker pool.', '',
          '## System index', '']
    overview = ['', '## Overview', '', '```mermaid', 'flowchart TD']
    overview += [f'    {s["id"]}[{json.dumps(s["title"],ensure_ascii=False)}]' for s in systems if s['id'] in selected]
    overview += [f'    {e["from"]} -->|{json.dumps(e["label"],ensure_ascii=False)}| {e["to"]}' for e in document['overview']]
    overview += ['```', '', '## System index', '']
    # Keep the overview ahead of the index rather than repeating the heading.
    md = md[:-2] + overview
    md += [f"- [{s['title']}](#{s['id']}) — {s['owner']}" for s in systems]
    for s in systems:
        md += ['', f'<a id="{s["id"]}"></a>', f'## {s["title"]}', '', f"**Owner:** {s['owner']}. {s['summary']}", '', '```mermaid', 'flowchart TD']
        md += [f'    {n["id"]}[{json.dumps(n["label"],ensure_ascii=False)}]' for n in s['nodes']]
        md += [f'    {e["from"]} -->|{json.dumps(e["label"],ensure_ascii=False)}| {e["to"]}' for e in s['edges']]
        md += ['```', '', s['notes'], '', '**Source anchors:**', '']
        md += [f'- [{n.get("function",n["file"].split("/")[-1])}]' + f'(https://github.com/TheInfinityIQ/Trencho_V4/blob/{document["reviewed_baseline"]}/{n["file"]}#L{n["line"]}) — {n["label"]}' for n in s['nodes']]
    md += ['', '## Scope and maintenance', ''] + [f'- {v}' for v in document['limits']]
    md += ['', 'Run the existing **Update System Map.cmd** to refresh the atlas with the maps. If a reviewed game source changes, review the affected catalog descriptions and update its normalized SHA256 in reviewed_sources before regenerating. New non-test scripts require an explicit file_owners assignment; retained tests are indexed separately. Do not clear review hashes without reading the changed code.', '']
    # SVG is a view product; keep the JSON inventory compact and free of duplicated SVG.
    compact = {**document, 'systems': [{k: v for k, v in s.items() if k != 'svg'} for s in systems]}
    return {OUTPUTS[0]: json.dumps(compact, ensure_ascii=False, indent=2) + '\n', OUTPUTS[1]: page, OUTPUTS[2]: '\n'.join(md)}


def main() -> int:
    """Regenerate, or compare only this document's outputs without running gameplay."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    options = parser.parse_args()
    document = build()
    outputs = render(document)
    stale = []
    for relative, text in outputs.items():
        path = ROOT / relative
        if options.check:
            if not path.is_file() or path.read_text(encoding='utf-8') != text: stale.append(relative)
        else:
            path.write_text(text, encoding='utf-8', newline='\n')
    if stale:
        print('STALE atlas: ' + ', '.join(stale)); return 1
    print(('PASS current atlas: ' if options.check else 'Generated atlas: ') + json.dumps(document['totals']))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
