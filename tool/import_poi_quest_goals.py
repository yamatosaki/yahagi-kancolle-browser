"""Import a reviewed Poi questgoal FCD file without network access.

The app reapplies quest_progress_policy.dart after validating every payload.
The small mirrored import policy keeps direct flat-asset readers conservative;
quest_progress_bundle_parity_test verifies the complete import against Poi.
"""

import argparse
import copy
import hashlib
import json
from pathlib import Path
import re


MIGRATED = [
    249, 337, 339, 345, 346, 354, 355, 356, 357, 362, 368, 371, 373,
    375, 377, 875, 888, 903, 904, 912, 928, 975, 977, 1018, 1045,
]
FRENCH_IDS = [492, 935, 965, 962, 491, 1051, 1053, 1055]


def digest(value):
    return hashlib.sha256(value).hexdigest()


def json_bytes(value):
    return (json.dumps(value, ensure_ascii=False, indent=2) + '\n').encode('utf-8')


def apply_policy(data):
    data = copy.deepcopy(data)
    for key, goal in data.items():
        quest_id = int(key)
        minimum = 2 if quest_id in [373, 977] else (
            1 if quest_id in MIGRATED + [318, 350, 372, 1005, 1138] else 0
        )
        if minimum > goal.get('revision', 0):
            goal['revision'] = minimum
        if quest_id in [318, 977, 1005]:
            goal['fuzzy'] = True
        for step in goal.values():
            if not isinstance(step, dict):
                continue
            if quest_id == 372:
                require_companions(step, 'escortshiptype', [10], 2)
                require_companions(step, 'escortshiptype', [2], 2)
            elif quest_id == 373:
                require_companions(step, 'escortshipIdAll', FRENCH_IDS, 2)
    return data


def require_companions(step, key, allowed, required):
    groups = step.setdefault(key, [])
    for group in groups:
        if set(group[0]) != set(allowed):
            continue
        group[1] = max(group[1], required)
        if len(group) == 2:
            group.append(True)
        else:
            group[2] = True
        return
    groups.append([allowed[:], required, True])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('--commit', required=True)
    parser.add_argument('--output', type=Path, default=Path('assets/data'))
    args = parser.parse_args()
    if not re.fullmatch(r'[0-9a-f]{40}', args.commit):
        parser.error('--commit must be the reviewed 40-character Git SHA')
    source = args.source.read_bytes()
    envelope = json.loads(source)
    if envelope['meta']['name'] != 'questgoal':
        parser.error('Expected a Poi questgoal FCD file')
    data = envelope['data']
    if not data or any(not isinstance(goal, dict) for goal in data.values()):
        parser.error('Expected nonempty quest goals')
    if any({'flagship', 'secondship', 'escortship', 'shipNamesAll'} & step.keys()
           for goal in data.values() for step in goal.values()
           if isinstance(step, dict)):
        parser.error('Source still has unsupported legacy ship-name constraints')
    bundled = json_bytes(apply_policy(data))
    canonical = json.dumps(data, ensure_ascii=False, separators=(',', ':')).encode('utf-8')
    meta = {
        'version': envelope['meta']['version'],
        'sourceCommit': args.commit,
        'sha256': digest(bundled),
        'upstreamSha256': digest(source),
        'upstreamDataSha256': digest(canonical),
        'questCount': len(data),
        'stepCount': sum(isinstance(step, dict)
                         for goal in data.values() for step in goal.values()),
    }
    sources = {
        'repository': 'https://github.com/poooi/poi',
        'commit': args.commit,
        'path': 'assets/data/fcd/questgoal.json',
        'version': envelope['meta']['version'],
        'questCount': meta['questCount'],
        'stepCount': meta['stepCount'],
        'upstreamSha256': meta['upstreamSha256'],
        'nameToIdMigrations': MIGRATED,
        'localPolicy': {
            '318': 'Keep fuzzy reference-only completion because equipment requirements are not verified.',
            '350': 'Require the four exact ship ID lineages; revision must not fall below 1.',
            '372': 'Two aviation battleships and two destroyers are companions excluding the flagship.',
            '373': 'Use French master IDs and require two companions excluding the flagship; revision 2.',
            '977': 'Use Yamato Kai Ni / Musashi Kai Ni master IDs, two destroyers and cell 15 for 7-2-2; retain upstream fuzzy; revision 2.',
            '1005': 'Require all four ships at Kai or later, and retain upstream fuzzy; revision 1.',
            '1138': 'Require master equipment ID 120 instead of equipment type 17; revision 1.',
        },
        'overrides': {
            '977': 'https://zekamashi.net/kancolle-kouryaku/yamatogata-batubyou/',
        },
    }
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / 'quest-progress-goals.json').write_bytes(bundled)
    (args.output / 'quest-progress-meta.json').write_bytes(json_bytes(meta))
    (args.output / 'quest-progress-sources.json').write_bytes(json_bytes(sources))
    print(json.dumps(meta, ensure_ascii=False))


if __name__ == '__main__':
    main()
