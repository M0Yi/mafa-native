#!/usr/bin/env python3
"""Run bounded operation-page regressions; never export or alter player saves."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile
import re
import hashlib
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[1]
CASES = {
    'traveler_recovery_test': ['PASS: traveler_recovery_test completed without failures'],
    'green_poison_test': ['PASS: green_poison_test completed without failures'],
    'traveler_audio_test': ['PASS: traveler_audio_test completed without failures'],
    'skill_effects_test': ['PASS: thrust, halfmoon and flame eight-direction source frames match body action timing', 'PASS: fireball 16 directions/96 source frames', 'original effect frames and six shield frames decode'],
    'fireball_resolution_test': ['PASS: committed petrification cancels pending attack and scheduled spell presentation', 'PASS: area resolution excludes escaped target while damaging target still inside the fixed blast', 'PASS: selected area center survives distance sorting and collateral hits emit one effect at that center', 'PASS: off-ray line target rejects before mana, cooldown, proficiency or effect mutation', 'PASS: failed lethal poison and manafire preserve target state; successful hits apply status and mana drain', 'PASS: impact sound dispatch follows committed damage and is silent on failed lethal save', 'PASS: failed lethal reward transaction preserves target health and emits no impact visual', 'PASS: real projectile cast consumes once; damage and impact wait for flight; repeated resolve is inert; invalid generation and map transition cancel impact'],
    'bundle_instance_closeout_test': ['PASS: unpack consumes selected packet instance; other stack and failed-write retry preserved'],
    'shop_death_guard_closeout_test': ['PASS: dead buy/sell rejected'],
    'quest_inventory_refresh_closeout_test': ['PASS: quest submission and progress update'],
    'split_selection_closeout_test': ['PASS: detached inventory sort, use and paging callbacks are inert', 'PASS: detached inventory panel cannot open or confirm a split', 'PASS: selected stack', 'PASS: application and item panel nodes released'],
    'item_drag_guard_closeout_test': ['PASS: non-game item and quickbar drops preserve inventory and bindings','PASS: detached item and quickbar targets reject drops without state changes', 'PASS: malformed', 'PASS: stale item cell cannot click or drag an item moved to another container'],
    'item_use_feedback_closeout_test': ['PASS: item use cooldown', 'PASS: application and item panel nodes released'],
}

PAGE_CASES = {
    'bootstrap_missing_resources_test': ['PASS: missing client cache keeps resource setup interactive; no worker, cache or save created; settings preserved'],
    "resource_entry_failure_closeout_test": ["PASS: incompatible manifest names file and versions; missing manifest keeps original error; startup leaves no save or orphan nodes"],
    "store_open_failure_closeout_test": ["PASS: failed store initialization closes connection, preserves error and existing metadata; retry opens"],
    "store_entry_failure_closeout_test": ["PASS: startup SQL failure shows error, releases store, creates no world or operation and tears down safely"],
    "reentry_revival_test": ["PASS: reentry revives immediately", "PASS: failed revival through entry confirmation", "PASS: missing revival map keeps roster visible", "PASS: safe-zone edge cells block monster damage"],
    'equipment_swap_requirements_test': ['PASS: reverse equipment swaps enforce gender and level in bag and warehouse; failed swaps preserve saved instances'],
    'inventory_capacity_closeout_test': ['PASS: full inventory and warehouse reject split without mutation; freeing slot allows conserved split'],
    'quickbar_validation_closeout_test': ['PASS: malformed quickbar rejected on load without overwriting save; valid bindings and items preserved', 'PASS: legacy missing quickbar defaults agree; binding rollback and restart preserve inventory'],
    'death_return_test': ['PASS: death page regression completed'],
    'story_guild_announcement_test': ['PASS: guild announcement regression completed'],
    'window_position_closeout_test': ['PASS: position save failure closes window, preserves old metadata and reports error; retry saves'],
    'import_error_feedback_closeout_test': ['PASS: import error with missing, null or blank message restores retry and explicit feedback', 'PASS: real exited child with missing or malformed status restores import retry', 'PASS: invalid configured cache path preserves settings and opens recovery UI', 'PASS: replacing invalid cache path persists without losing unrelated settings'],
    'window_close_audio_closeout_test': ['PASS: failed window-close save retains state and audio', 'PASS: successful window close saves, backs up and clears audio before quitting'],
    'repair_feedback_closeout_test': ['PASS: repair write failure retains panel, gold and durability; retry repairs and charges once', 'PASS: closed repair panel cannot transact after a same-title window reopens', 'PASS: closed crafting panel ignores stale confirmation'],
    'story_filter_closeout_test': ['PASS: pausing after opening abandon confirmation preserves the task', 'PASS: story filters update after acceptance and completion; completed archive contains only completed quests'],
    'character_restore_closeout_test': ['PASS: malformed account load blocks subsequent writes', 'PASS: malformed archived records', 'PASS: name conflict and full slots', 'PASS: archive/restore write failures'],
    'controller_stale_item_closeout_test': ['PASS: viewport Start input pauses and resumes with assist settings open', 'PASS: paused viewport confirm and bind inputs preserve inventory state', 'PASS: viewport Start input pauses and resumes while controller panel is open', 'PASS: detached controller inventory, warehouse and skill-guide inputs preserve new windows','PASS: closed controller task back callbacks preserve replacement window','PASS: task history restores identity and never opens a replacement task', 'PASS: controller selection follows item identity', 'PASS: stale controller item cannot use or bind', 'PASS: controller task callback cannot execute'],
    'mute_feedback_closeout_test': ['PASS: mute stops transient audio', 'PASS: music changed while muted resumes the current track'],
    'character_switch_closeout_test': ['PASS: character switch clears stale windows', 'PASS: returning to the same character preserves current potion cooldown'],
    'entry_failure_closeout_test': ['PASS: failed authentication restores controls'],
    'entry_creation_failure_probe': ['PASS: persisted creation preset survives account reload', 'PASS: failed world creation preserves identity'],
    'skill_panel_refresh_closeout_test': ['PASS: open skill panel follows book purchase', 'PASS: spirit description follows equipment accuracy'],
    'skill_bind_failure_test': ['PASS: failed binding and selection preserve state'],
    'warehouse_distance_closeout_test': [
        'PASS: controller warehouse ignores modal and covered inputs',
        'PASS: detached controller warehouse cannot mutate items',
        'PASS: closed warehouse rejects stale withdrawal drag',
        'PASS: NPC-bound mouse warehouse rejects distant deposit',
        'PASS: controller warehouse rejects distance, pause, map change and death',
    ],
}

RESOURCE_CASES = {
    "frame_fallback_cycle_closeout_test": ["PASS: self and two-bank fallback cycles report errors; repeated valid fallback bounds resolve"],
    'resource_entry_failure_closeout_test': PAGE_CASES['resource_entry_failure_closeout_test'],
    'map_catalog_failure_closeout_test': ['PASS: malformed map arrays, records, duplicate IDs and incomplete counts return located errors before world initialization'],
    'supplement_shape_closeout_test': ['PASS: malformed supplement declarations and library containers return located errors'],
    'frame_pack_bounds_closeout_test': ['PASS: corrupt frame ranges and dimensions rejected without caching; valid PNG and negative sprite offsets preserved'],
}

def unexpected_errors(case, log):
    """Keep known diagnostics visible, but fail on every other engine error."""
    errors = []
    for line in log.splitlines():
        if case in {'store_open_failure_closeout_test', 'store_entry_failure_closeout_test', 'resource_entry_failure_closeout_test'}:
            if 'were leaked' in line or 'was leaked' in line or 'resources still in use at exit' in line:
                errors.append(line)
                continue
            expected = 'injected initialization failure' if case == 'store_open_failure_closeout_test' else 'injected entry failure'
            if case != 'resource_entry_failure_closeout_test' and line == 'ERROR:  --> SQL error: ' + expected:
                continue
        if 'ERROR:' not in line and 'Parse Error' not in line and 'Assertion failed' not in line:
            continue
        if line == 'ERROR: Condition "ret != noErr" is true. Returning: ""':
            continue  # macOS certificate lookup in this headless environment
        if re.fullmatch(r'ERROR: \d+ resources still in use at exit .*', line):
            continue  # recorded separately; not a claim of clean resource shutdown
        if case in {'traveler_recovery_test', 'green_poison_test', 'traveler_audio_test', 'fireball_resolution_test', 'bundle_instance_closeout_test', 'reentry_revival_test', 'quickbar_validation_closeout_test', 'shop_death_guard_closeout_test', 'quest_inventory_refresh_closeout_test', 'split_selection_closeout_test', 'item_drag_guard_closeout_test', 'skill_bind_failure_test', 'mute_feedback_closeout_test', 'character_restore_closeout_test', 'repair_feedback_closeout_test', 'window_close_audio_closeout_test', 'death_return_test', 'story_guild_announcement_test', 'window_position_closeout_test'} and line == 'ERROR:  --> SQL error: attempt to write a readonly database':
            continue  # these cases deliberately inject SQLite query_only
        errors.append(line)
    return errors

def source_fingerprint(root=ROOT):
    # Scope is explicit: runtime scripts/content/scenes/config and regression scripts.
    paths = [root / 'game/project.godot', root / 'tools/check_item_ui_closeout.py']
    paths += list((root / 'game').glob('*.tscn'))
    for folder, suffix in [('game/scripts', '.gd'), ('game/content', '.json'), ('game/tests2011', '.gd')]:
        paths += list((root / folder).rglob('*' + suffix))
    digest = hashlib.sha256()
    for path in sorted(set(paths)):
        if path.is_file():
            digest.update(str(path.relative_to(root)).encode('utf-8') + b'\0')
            digest.update(hashlib.sha256(path.read_bytes()).digest())
    return digest.hexdigest()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', type=Path, default=ROOT / '.cache/godot/Godot.app/Contents/MacOS/Godot')
    parser.add_argument('--suite', choices=['items', 'pages', 'resources', 'all'], default='items')
    parser.add_argument('--asset-root', type=Path, help='Converted cache root containing client2011 and optional supplement16')
    args = parser.parse_args()
    asset_root = args.asset_root.expanduser().resolve() if args.asset_root else None
    if asset_root and not (asset_root / 'client2011/manifest.json').is_file():
        parser.error('--asset-root must contain client2011/manifest.json')
    if not args.godot.is_file():
        parser.error('Godot not found; pass --godot /path/to/godot')
    cases = {'items': CASES, 'pages': PAGE_CASES, 'resources': RESOURCE_CASES, 'all': {**CASES, **PAGE_CASES, **RESOURCE_CASES}}[args.suite]
    output = ROOT / ('artifacts/item-ui-closeout' if args.suite == 'items' else 'artifacts/ui-closeout-' + args.suite)
    output.mkdir(parents=True, exist_ok=True)
    started = datetime.now(timezone.utc).isoformat()
    source_before = source_fingerprint()
    results = []
    with tempfile.TemporaryDirectory(prefix='mafa-item-ui-logs-') as temporary:
        for case, markers in cases.items():
            script = 'res://tests2011/' + case + '.gd'
            if asset_root:
                wrapper = Path(temporary) / (case + '.gd')
                wrapper.write_text('extends ' + json.dumps(script) + '\nfunc _initialize():\n'
                    + '\tEditionResources.BASE = ' + json.dumps((asset_root / 'client2011').as_posix() + '/') + '\n'
                    + '\tEditionResources.SUPPLEMENT_BASE = ' + json.dumps((asset_root / 'supplement16').as_posix() + '/') + '\n'
                    + '\tsuper._initialize()\n', encoding='utf-8')
                script = str(wrapper)
            command = [str(args.godot.resolve()), '--headless', '--path', str(ROOT / 'game'),
                       '--log-file', str(Path(temporary) / (case + '.log')),
                       '--script', script]
            try:
                completed = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=45)
                log = completed.stdout + completed.stderr
                status = completed.returncode
            except OSError as error:
                log = f'ERROR: Could not launch Godot: {error}\n'
                status = 'launch_error'
            except subprocess.TimeoutExpired as error:
                def decode(value):
                    return value.decode(errors='replace') if isinstance(value, bytes) else (value or '')
                log = decode(error.stdout) + decode(error.stderr)
                status = 'timeout'
            (output / (case + '.log')).write_text(log, encoding="utf-8")
            errors = unexpected_errors(case, log)
            warnings = [line for line in log.splitlines() if 'WARNING:' in line or 'ERROR:' in line]
            results.append({'test': case, 'exit': status,
                            'engine_banner': next((line for line in log.splitlines() if line.startswith('Godot Engine v')), ''),
                            'functional_pass': status == 0 and not errors and all(m in log for m in markers),
                            'unexpected_errors': errors,
                            'resource_shutdown_warning': 'resources still in use at exit' in log or 'ObjectDB instances were leaked' in log,
                            'warnings_or_injected_errors': warnings,
                            'log': str((output / (case + '.log')).relative_to(ROOT))})
    source_after = source_fingerprint()
    report = {'started_at_utc': started, 'finished_at_utc': datetime.now(timezone.utc).isoformat(),
              'engine_path': str(args.godot.resolve()), 'asset_root': str(asset_root) if asset_root else 'res://assets', 'source_sha256_before': source_before,
              'source_sha256_after': source_after, 'source_changed_during_run': source_before != source_after,
              'fingerprint_scope': 'GDScript, content JSON, top-level scenes, project.godot and runner; excludes assets and native addons',
              'suite': args.suite, 'scope': 'Headless operation-page/transaction regressions; not physical input, rendering or platform acceptance.',
              'results': results}
    (output / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    for result in results:
        print(f"{result['test']}: {'PASS' if result['functional_pass'] else 'FAIL'}; {len(result['warnings_or_injected_errors'])} diagnostic lines")
    return 0 if source_before == source_after and all(row['functional_pass'] for row in results) else 1

if __name__ == '__main__':
    raise SystemExit(main())
