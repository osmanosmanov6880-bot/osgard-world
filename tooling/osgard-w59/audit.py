#!/usr/bin/env python3
"""W59: offline, untrusted evidence audit for the exact W58 software preview.

This tool checks identity, file integrity and plausibility, NOT actual physical
provenance. It never signs off devices, visual quality, a master merge or release.
"""
import argparse
import csv
import hashlib
import json
import math
import statistics
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath

SOURCE_SHA = 'ef570cf6c406cc14ec180585ee2c5d64c667c658'
CANDIDATE_SHA256 = 'd38390b6bc483431193ada34382330f101bb2aee3923f1eb619029f212fe7684'
PLATFORMS = ('windows', 'webgl', 'android', 'ios')
COMMON = ('launch', 'six_missions', 'hero_eco', 'ru_en', 'no_crashes', 'accessibility')
EXTRA = {'windows': ('keyboard_mouse',), 'webgl': ('browser_fullscreen',),
         'android': ('touch_controls', 'safe_area'), 'ios': ('touch_controls', 'safe_area')}
MANUAL = {'PASS_MANUAL', 'FAIL_MANUAL', 'NOT_TESTED'}


class EvidenceError(ValueError):
    pass


def require(ok, message):
    if not ok:
        raise EvidenceError(message)


def is_sha(s):
    return isinstance(s, str) and len(s) == 64 and all(c in '0123456789abcdef' for c in s)


def sha256(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def safe_file(root, name, size_limit=150_000_000):
    require(isinstance(name, str), 'Missing relative evidence path')
    p = PurePosixPath(name)
    require(name and not p.is_absolute() and '/' in name and
            not any(s in ('.', '..', '') for s in p.parts) and '\\' not in name and
            ':' not in name and not name.startswith('//'), 'Unsafe evidence path: ' + name)
    cur = root
    for part in p.parts:
        cur = cur / part
        require(not cur.is_symlink(), 'Symlink evidence is forbidden: ' + name)
    require(cur.resolve().is_relative_to(root.resolve()), 'Evidence escaped its root')
    require(cur.is_file(), 'Missing evidence file: ' + name)
    require(0 < cur.stat().st_size <= size_limit, 'Invalid evidence size: ' + name)
    return cur


def verified_file(root, item, size_limit=150_000_000):
    require(isinstance(item, dict) and is_sha(item.get('sha256')),
            'Missing or invalid SHA256 evidence entry')
    path = safe_file(root, item.get('path'), size_limit)
    require(sha256(path) == item['sha256'], 'SHA256 mismatch: ' + item['path'])
    return path


def read_json(path):
    require(path.stat().st_size <= 1_000_000, 'Oversized JSON report')
    data = json.loads(path.read_text('utf-8'))
    require(isinstance(data, dict), 'Expected JSON object')
    return data


def utc_time(s):
    require(isinstance(s, str), 'Expected ISO-8601 UTC time')
    try:
        t = datetime.fromisoformat(s.replace('Z', '+00:00'))
    except ValueError as ex:
        raise EvidenceError('Invalid UTC timestamp') from ex
    require(t.tzinfo is not None and t.utcoffset().total_seconds() == 0,
            'Report timestamps must use UTC')
    return t


def frame_stats(root, file_info):
    path = verified_file(root, file_info, 40_000_000)
    times, frames = [], []
    with path.open('r', encoding='utf-8-sig', newline='') as f:
        r = csv.DictReader(f)
        require(r.fieldnames == ['t_ms', 'frame_ms'], 'Frame CSV needs t_ms,frame_ms')
        for row in r:
            require(len(frames) < 500_000, 'Frame CSV too large')
            try:
                t, ms = float(row['t_ms']), float(row['frame_ms'])
            except (TypeError, ValueError, KeyError) as ex:
                raise EvidenceError('Non-numeric frame telemetry') from ex
            require(math.isfinite(t) and math.isfinite(ms) and 0 < ms <= 10000,
                    'Nonfinite or invalid frame duration')
            if times:
                require(0 < t - times[-1] <= 10_000, 'Nonmonotonic or discontinuous frame log')
                require(abs((t-times[-1])-ms) <= max(10.0, 0.3*ms),
                        'Frame timestamps do not match consecutive frame durations')
            times.append(t)
            frames.append(ms)
    require(len(frames) >= 1800 and times[-1] - times[0] >= 120_000,
            'Insufficient consecutive frames or under 120 seconds')
    tail = sorted(frames, reverse=True)[:max(1, math.ceil(len(frames) * .01))]
    median_ms = statistics.median(frames)
    return {'frames': len(frames), 'span_seconds': round((times[-1]-times[0])/1000, 1),
            'median_frame_ms': round(median_ms, 3),
            'median_frame_fps': round(1000 / median_ms, 2),
            'worst_1pct_mean_frame_ms': round(statistics.mean(tail), 3),
            'worst_1pct_mean_fps': round(1000 / statistics.mean(tail), 2)}


def thermal_stats(root, file_info):
    path = verified_file(root, file_info, 2_000_000)
    minutes, measured, throttle = [], 0, False
    with path.open('r', encoding='utf-8-sig', newline='') as f:
        r = csv.DictReader(f)
        require(r.fieldnames == ['elapsed_s', 'temperature_c', 'throttle'],
                'Thermal CSV needs elapsed_s,temperature_c,throttle')
        for row in r:
            try:
                elapsed = float(row['elapsed_s'])
            except (TypeError, ValueError, KeyError) as ex:
                raise EvidenceError('Invalid thermal elapsed time') from ex
            require(math.isfinite(elapsed) and elapsed >= 0, 'Invalid thermal timestamp')
            if minutes:
                require(0 < elapsed - minutes[-1] <= 90, 'Thermal sample gap exceeds 90s')
            temp = row.get('temperature_c', '')
            if temp:
                try:
                    value = float(temp)
                except ValueError as ex:
                    raise EvidenceError('Invalid thermal temperature') from ex
                require(math.isfinite(value) and -20 <= value <= 125, 'Implausible thermal value')
                measured += 1
            require(row.get('throttle') in ('yes', 'no', 'unknown'), 'Invalid throttle status')
            throttle |= row['throttle'] == 'yes'
            minutes.append(elapsed)
    require(len(minutes) >= 21 and minutes[-1] - minutes[0] >= 1800,
            'Thermal observation does not span 30 minutes')
    return {'samples': len(minutes), 'span_seconds': round(minutes[-1]-minutes[0], 1),
            'temperature_samples': measured, 'reported_throttling': throttle,
            'temperature_sensor_data_present': measured > 0}


def screenshot(root, item):
    path = verified_file(root, item, 20_000_000)
    with path.open('rb') as f:
        require(f.read(8) == b'\x89PNG\r\n\x1a\n', 'Screenshot is not a PNG')
    return {'file': item['path'], 'sha256_verified': True}


def device(root, platform, entry, source):
    report = read_json(verified_file(root, entry))
    require(report.get('schema') == 'OSGARD_W59_DEVICE_SESSION_V1', 'Wrong device report schema')
    require(report.get('platform') == platform, 'Mismatched device platform')
    require(report.get('source_sha') == source, 'Stale or mismatched device source')
    require(report.get('device_kind') == 'PHYSICAL_DEVICE_REPORTED_UNVERIFIED',
            'Device must not be an emulator or self-certified')
    for name in ('production_approved', 'physical_certified', 'release_go'):
        require(report.get(name) is not True, 'Forbidden device self-certification: ' + name)
    info = report.get('device')
    require(isinstance(info, dict) and all(isinstance(info.get(k), str) and
            info[k].strip() for k in ('model', 'os', 'gpu')),
            'Missing real device identification (self-reported)')
    started, ended = utc_time(report.get('started_utc')), utc_time(report.get('ended_utc'))
    require(1800 <= (ended-started).total_seconds() <= 24*3600,
            'Reported physical session must span at least 30 minutes')
    checks = report.get('manual_checks')
    require(isinstance(checks, dict), 'Manual checklist not supplied')
    keys = COMMON + EXTRA[platform]
    require(all(checks.get(k) in MANUAL for k in keys), 'Missing manual checklist field')
    complete = all(checks[k] == 'PASS_MANUAL' for k in keys)
    modes = report.get('modes')
    require(isinstance(modes, dict) and set(modes) == {'hero', 'eco'},
            'Both HERO and ECO telemetry are mandatory')
    performance = {name: frame_stats(root, modes[name]) for name in ('hero', 'eco')}
    thermal = thermal_stats(root, report.get('thermal'))
    photos = report.get('screenshots')
    require(isinstance(photos, dict) and set(photos) == {'ru', 'en'},
            'Original RU and EN screenshots are mandatory')
    screenshots = {lang: screenshot(root, photos[lang]) for lang in ('ru', 'en')}
    return {'schema_valid': True, 'reported_platform': platform,
            'self_reported_model': info['model'], 'manual_pass': complete,
            'measured_csv_statistics': performance, 'thermal_observations': thermal,
            'screenshots': screenshots, 'independently_verified_hardware': False}


def audit(root, candidate_source=SOURCE_SHA, candidate_digest=CANDIDATE_SHA256):
    require(len(candidate_source) == 40 and all(c in '0123456789abcdef' for c in candidate_source),
            'Expected exact 40-character source commit')
    require(is_sha(candidate_digest), 'Expected exact candidate ZIP SHA256')
    outcome = {'schema': 'OSGARD_W59_EVIDENCE_AUDIT_V1', 'source_sha': candidate_source,
               'candidate_sha256': candidate_digest, 'status': 'HOLD',
               'decision': 'MISSING_EVIDENCE', 'candidate_bytes_verified': False,
               'devices': {}, 'missing': [], 'errors': [],
               'ready_for_independent_human_review': False,
               'independently_verified_hardware': False,
               'cinematic_signoff': False, 'production_approved': False,
               'allow_master_merge': False, 'published_to_production': False}
    manifest_file = root / 'manifest.json'
    if not manifest_file.is_file():
        outcome['missing'] = ['manifest.json', 'candidate.zip', *PLATFORMS]
        return outcome
    manifest = read_json(manifest_file)
    require(manifest.get('schema') == 'OSGARD_W59_EVIDENCE_MANIFEST_V1', 'Wrong manifest schema')
    require(manifest.get('source_sha') == candidate_source, 'Manifest uses stale source SHA')
    candidate = manifest.get('candidate')
    require(isinstance(candidate, dict) and candidate.get('sha256') == candidate_digest,
            'Manifest must pin approved candidate ZIP SHA256')
    try:
        archive = verified_file(root, candidate, 150_000_000)
        require(archive.suffix == '.zip', 'Approved candidate must be a ZIP')
        outcome['candidate_bytes_verified'] = True
    except (EvidenceError, OSError) as err:
        outcome['errors'].append('candidate: ' + str(err))
    reports = manifest.get('reports')
    require(isinstance(reports, dict) and set(reports).issubset(PLATFORMS),
            'Unexpected or invalid report platforms')
    for platform in PLATFORMS:
        if platform not in reports:
            outcome['missing'].append(platform)
            continue
        try:
            outcome['devices'][platform] = device(root, platform, reports[platform], candidate_source)
        except (EvidenceError, OSError, UnicodeError, json.JSONDecodeError, csv.Error) as err:
            outcome['errors'].append(platform + ': ' + str(err))
    if (outcome['candidate_bytes_verified'] and not outcome['missing'] and
            not outcome['errors'] and len(outcome['devices']) == 4 and
            all(d['manual_pass'] for d in outcome['devices'].values())):
        outcome['ready_for_independent_human_review'] = True
        outcome['decision'] = 'HUMAN_HARDWARE_ART_INTEGRATION_REVIEW_REQUIRED'
    else:
        outcome['decision'] = 'MISSING_OR_INVALID_DEVICE_EVIDENCE'
    return outcome


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--evidence-dir', type=Path, required=True)
    p.add_argument('--expected-sha', default=SOURCE_SHA)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    try:
        result = audit(args.evidence_dir, args.expected_sha)
        exit_code = 0
    except (EvidenceError, OSError, UnicodeError, json.JSONDecodeError) as e:
        result = {'schema': 'OSGARD_W59_EVIDENCE_AUDIT_V1', 'status': 'FAIL',
                  'decision': 'INVALID_MANIFEST', 'error': str(e),
                  'production_approved': False, 'allow_master_merge': False,
                  'published_to_production': False}
        exit_code = 2
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(result['status'] + ': ' + result['decision'])
    raise SystemExit(exit_code)


if __name__ == '__main__':
    main()
