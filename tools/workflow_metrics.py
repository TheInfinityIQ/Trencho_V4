"""Record one feature's phase boundaries, observed defects and reported usage.

Bookkeeping only: no engine, model, suite, service or background watcher is run.
"""
from __future__ import annotations
import argparse
import datetime as dt
import json
from pathlib import Path

PHASES = ('planning', 'implementation', 'direct_check', 'repair', 'late_handling',
          'review', 'release', 'waiting', 'paused', 'workflow_overhead')
KINDS = ('regression', 'candidate_regression', 'feature_defect', 'planning_discovery',
         'pre_existing', 'infrastructure', 'workflow_error', 'scope_change')
COUNTERS = ('input_tokens', 'cached_input_tokens', 'output_tokens',
            'reasoning_output_tokens', 'total_tokens')


def now() -> str:
    """Capture a timezone-aware UTC boundary for the local journal."""
    return dt.datetime.now(dt.timezone.utc).isoformat()


def read_usage(path: str | None) -> dict | None:
    """Read only the latest reported counter metadata from a bounded session tail."""
    if not path:
        return None
    try:
        with Path(path).open('rb') as stream:
            stream.seek(0, 2)
            stream.seek(max(0, stream.tell() - 4 * 1024 * 1024))
            lines = stream.read().splitlines()
        for line in reversed(lines):
            if b'token_count' not in line:
                continue
            try:
                event = json.loads(line)
            except (ValueError, UnicodeError):
                continue
            payload = event.get('payload', {})
            if event.get('type') != 'event_msg' or payload.get('type') != 'token_count':
                continue
            raw = (payload.get('info') or {}).get('total_token_usage')
            if not isinstance(raw, dict):
                return None
            values = {key: raw.get(key) for key in COUNTERS}
            if any(isinstance(v, bool) or not isinstance(v, int) or v < 0 for v in values.values()):
                return None
            if values['cached_input_tokens'] > values['input_tokens'] or values['reasoning_output_tokens'] > values['output_tokens']:
                return None
            if values['total_tokens'] != values['input_tokens'] + values['output_tokens']:
                return None
            return {'receipt_at': event.get('timestamp'), 'counters': values}
    except (OSError, ValueError):
        return None
    return None


def usage_delta(before: dict | None, after: dict | None) -> dict | None:
    """Compute real cumulative-counter deltas, keeping unavailable intervals unknown."""
    if before is None or after is None:
        return None
    values = {key: after['counters'][key] - before['counters'][key] for key in COUNTERS}
    if min(values.values()) < 0 or values['cached_input_tokens'] > values['input_tokens'] or values['reasoning_output_tokens'] > values['output_tokens']:
        return None
    if values['total_tokens'] != values['input_tokens'] + values['output_tokens']:
        return None
    values['uncached_input_tokens'] = values['input_tokens'] - values['cached_input_tokens']
    return values


def close_phase(run: dict, at: str, usage: dict | None) -> None:
    """Close the sole active interval without overlapping time or reusing its tokens."""
    active = run.get('active')
    if active is None:
        return
    seconds = (dt.datetime.fromisoformat(at) - dt.datetime.fromisoformat(active['started_at'])).total_seconds()
    run['intervals'].append({**active, 'ended_at': at,
                            'elapsed_seconds': seconds if seconds >= 0 else None,
                            'usage_end': usage,
                            'usage_delta': usage_delta(active['usage_start'], usage) if active['phase'] != 'paused' else None})
    run['active'] = None


def validate_incident(data: dict) -> None:
    """Require evidence for regression and missed-planning-case classifications."""
    required = ('id', 'kind', 'summary', 'severity', 'evidence', 'planning_assessment')
    if any(not data.get(key) for key in required) or data['kind'] not in KINDS:
        raise ValueError('Incident needs id/kind/summary/severity/evidence/planning_assessment')
    if data['planning_assessment'] not in ('confirmed', 'possible', 'no', 'unknown'):
        raise ValueError('Planning assessment must be confirmed, possible, no or unknown')
    if data['kind'] == 'regression' and any(not data.get(key) for key in ('prior_good_evidence', 'current_bad_evidence', 'change_attribution')):
        raise ValueError('A confirmed regression needs prior-good, current-bad and change-attribution evidence')
    if data['planning_assessment'] == 'confirmed' and any(not data.get(key) for key in ('preavailable_requirement', 'omitted_assumption', 'assessment_rationale')):
        raise ValueError('A confirmed planning gap needs preavailable requirement, omission and rationale')


def summarize(run: dict) -> dict:
    """Export concise time/quality/usage accounting without raw session data or paths."""
    by_phase = {phase: sum(i['elapsed_seconds'] or 0 for i in run['intervals'] if i['phase'] == phase) for phase in PHASES}
    known = [i['usage_delta'] for i in run['intervals'] if i['usage_delta'] is not None]
    unknown = sum(i['usage_delta'] is None for i in run['intervals'])
    totals = {key: sum(row[key] for row in known) for key in (*COUNTERS, 'uncached_input_tokens')}
    result = {key: run[key] for key in ('schema', 'feature', 'workflow', 'plan', 'source_revision', 'started_at', 'status')}
    result.update({'ended_at': run.get('ended_at'), 'seconds_by_phase': by_phase,
                   'timing_scope': 'Recorded phase wall time; earlier work unknown; UTC clock changes can affect duration.',
                   'active_phase': run['active']['phase'] if run['active'] else None,
                   'observation_scope': run['observations'], 'incidents': run['incidents'],
                   'unique_incidents_by_kind': {kind: sum(i['kind'] == kind for i in run['incidents']) for kind in KINDS},
                   'confirmed_planning_gap_count': sum(i['planning_assessment'] == 'confirmed' for i in run['incidents']),
                   'tracked_repair_seconds_by_incident': {incident['id']: sum(i['elapsed_seconds'] or 0 for i in run['intervals'] if i.get('incident') == incident['id'] and i['phase'] in ('repair', 'late_handling')) for incident in run['incidents']},
                   'tokens': {'measurement': 'Actual Codex cumulative metadata deltas. Phase labels are approximate completion-time attribution, not request-level tracing.',
                              'complete_recorded_interval_total': totals if not unknown and run['intervals'] else None,
                              'known_interval_subtotal': totals if known else None,
                              'unknown_intervals': unknown,
                              'coverage': 'Partial: through recorded receipt timestamps; active phase/final reply and earlier work excluded. Lead-only intervals; no dollar or all-service claim.',
                              'boundaries': [{'phase': i['phase'], 'started_at': i['started_at'], 'ended_at': i['ended_at'], 'receipt_start': (i['usage_start'] or {}).get('receipt_at'), 'receipt_end': (i['usage_end'] or {}).get('receipt_at'), 'usage_delta': i['usage_delta']} for i in run['intervals']]},
                   'limitations': ['Zero observed regressions does not establish regression-free behavior.',
                                   'Historical incidents without tracked repair intervals have unknown repair time.',
                                   'Counts and durations are cooperative bookkeeping, not tamper-proof telemetry.']})
    return result


def main() -> None:
    """Apply an explicit journal action or export its current measured summary."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('start', 'phase', 'incident', 'amend', 'observe', 'stop', 'report'))
    parser.add_argument('--journal', required=True, type=Path)
    for key in ('feature', 'workflow', 'plan', 'source-revision', 'session-file', 'incident', 'note'):
        parser.add_argument('--' + key)
    parser.add_argument('--phase', choices=PHASES, default='planning')
    parser.add_argument('--data', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    at = now()
    if args.action == 'start':
        if args.journal.exists():
            raise ValueError('Journal already exists; evidence will not be overwritten')
        if not all((args.feature, args.workflow, args.plan, args.source_revision)):
            raise ValueError('Start needs feature, workflow, plan and source revision')
        run = {'schema': 1, 'feature': args.feature, 'workflow': args.workflow, 'plan': args.plan,
               'source_revision': args.source_revision, 'started_at': at, 'status': 'recording',
               'session_file': args.session_file, 'intervals': [], 'incidents': [], 'observations': [],
               'active': {'phase': args.phase, 'started_at': at, 'usage_start': read_usage(args.session_file), 'incident': None, 'note': args.note}}
    else:
        run = json.loads(args.journal.read_text(encoding='utf-8'))
        if args.action == 'report':
            summary = summarize(run)
            if args.output:
                args.output.parent.mkdir(parents=True, exist_ok=True)
                args.output.write_text(json.dumps(summary, indent=2) + '\n', encoding='utf-8')
            print(json.dumps(summary, indent=2))
            return
        if run['status'] != 'recording':
            raise ValueError('Closed journals are immutable; start a linked continuation')
        if args.action in ('phase', 'stop'):
            if args.phase in ('repair', 'late_handling') and not args.incident:
                raise ValueError('Repair/late handling needs an existing incident id')
            if args.incident and args.incident not in [i['id'] for i in run['incidents']]:
                raise ValueError('Unknown incident id')
            usage = read_usage(run['session_file'])
            close_phase(run, at, usage)
            if args.action == 'phase':
                run['active'] = {'phase': args.phase, 'started_at': at, 'usage_start': usage, 'incident': args.incident, 'note': args.note}
            else:
                run.update({'status': 'closed', 'ended_at': at, 'closing_note': args.note})
        elif args.action in ('incident', 'amend'):
            data = json.loads(args.data.read_text(encoding='utf-8'))
            validate_incident(data)
            existing = next((i for i in run['incidents'] if i['id'] == data['id']), None)
            if args.action == 'incident' and existing is not None:
                raise ValueError('Incident already recorded; use amend to retain its history')
            if args.action == 'amend':
                if existing is None:
                    raise ValueError('Unknown incident id')
                history = existing.get('history', []) + [{k: v for k, v in existing.items() if k != 'history'}]
                existing.clear()
                existing.update({'recorded_at': at, **data, 'history': history})
            else:
                run['incidents'].append({'recorded_at': at, **data})
        elif args.action == 'observe':
            if not args.note:
                raise ValueError('Observation needs an exact scope and evidence note')
            run['observations'].append({'recorded_at': at, 'note': args.note})
    args.journal.parent.mkdir(parents=True, exist_ok=True)
    # Write a sibling then replace, preserving the old file if serialization fails.
    temporary = args.journal.with_suffix(args.journal.suffix + '.tmp')
    temporary.write_text(json.dumps(run, indent=2) + '\n', encoding='utf-8')
    temporary.replace(args.journal)
    print(json.dumps({'feature': run['feature'], 'action': args.action, 'at': at, 'status': run['status']}))


if __name__ == '__main__':
    main()
