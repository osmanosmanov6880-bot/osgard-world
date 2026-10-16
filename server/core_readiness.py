"""Read-only release evidence for one saved version; never fetches external URLs.

Local HTML is tied to its build inputs and its stored SHA-256. A structural check
or a participant review must never be presented as a public deployment check.
"""
import hashlib
import json

from core_model import now, require, simulation


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':'), allow_nan=False)


def checksum(value):
    return hashlib.sha256(value.encode('utf-8')).hexdigest()


def preview_inputs(data):
    """Only values rendered into build_preview's HTML, independent of tick marks."""
    return {
        'title': data['title'],
        'goal': data['goal'],
        'audience': data['audience'],
        'tasks': [item['title'] for item in data['tasks']],
        'acceptance': [item['title'] for item in data['acceptance']],
    }


def artifact_evidence(db, project_id, data):
    artifact = data['artifact']
    asset_id = artifact.get('assetId')
    result = {
        'kind': 'local_html' if asset_id else ('external_url' if artifact.get('url') else 'missing'),
        'assetId': asset_id or None,
        'sourceVersion': None,
        'declaredSha256': artifact.get('checksum') or None,
        'storedSha256': None,
        'actualSha256': None,
        'integrityMatches': None,
        'inputsMatch': None,
        'sourceSnapshotAvailable': None,
        'url': artifact.get('url') or None,
        'externalURLVerified': False,
    }
    if not asset_id:
        return result, []

    asset = db.execute('SELECT * FROM assets WHERE project_id=? AND id=?', (project_id, asset_id)).fetchone()
    checks = [dict(id='asset_exists', label='HTML-файл сохранён в этом проекте', passed=asset is not None)]
    if asset is None:
        result.update(integrityMatches=False, inputsMatch=False, sourceSnapshotAvailable=False)
        return result, checks

    actual = checksum(asset['content'])
    source = db.execute('SELECT data FROM revisions WHERE project_id=? AND version=?',
                        (project_id, asset['source_version'])).fetchone()
    result.update(
        sourceVersion=asset['source_version'], storedSha256=asset['sha256'], actualSha256=actual,
        integrityMatches=actual == asset['sha256'] == artifact.get('checksum'),
        sourceSnapshotAvailable=source is not None,
        inputsMatch=source is not None and preview_inputs(json.loads(source['data'])) == preview_inputs(data),
    )
    checks.extend([
        dict(id='asset_integrity', label='SHA-256 содержимого совпадает с файлом и контрактом', passed=result['integrityMatches']),
        dict(id='asset_source', label='Сохранена исходная версия сборки', passed=result['sourceSnapshotAvailable']),
        dict(id='asset_inputs', label='HTML соответствует текущей цели, аудитории, задачам и критериям', passed=result['inputsMatch']),
    ])
    return result, checks


def evaluate(db, project_id, source_version, data):
    """Evaluate within the caller's transaction for a coherent immutable snapshot."""
    artifact, file_checks = artifact_evidence(db, project_id, data)
    checks = simulation(data) + file_checks
    ready = all(item['passed'] for item in checks)
    blockers = [item['id'] for item in checks if not item['passed']]
    if not data['consents']['studio']:
        next_action = 'Разрешите использование контекста в Studio в текущем контракте.'
    elif not data['accepted']:
        next_action = 'Сохраните условия и примите текущую версию контракта.'
    elif any(item.startswith('asset_') for item in blockers):
        next_action = 'Создайте HTML-прототип заново из текущего контракта и повторите проверку.'
    elif blockers:
        next_action = 'Исправьте пункты проверки, отмеченные как незавершённые.'
    else:
        next_action = 'Можно зафиксировать внутренний выпуск и передать его другому участнику на приёмку.'
    warnings = []
    if artifact['kind'] == 'external_url':
        warnings.append('Внешняя ссылка не открывалась: доступность сайта, содержимое и его SHA-256 не подтверждены.')
    if not data['sources']:
        warnings.append('Источники не добавлены. Отсутствие просроченных источников не подтверждает достоверность содержания.')
    if data['acceptance']:
        warnings.append('Отметки критериев введены человеком. Они не заменяют исполнение тестов и разбор результата.')
    return {
        'format': 'osgard-studio-readiness-v1',
        'projectId': project_id,
        'sourceVersion': source_version,
        'snapshotSha256': checksum(canonical(data)),
        'generatedAt': now(),
        'status': 'ready_for_internal_release' if ready else 'blocked',
        'canCreateInternalRelease': ready,
        'checks': checks,
        'blockers': blockers,
        'artifact': artifact,
        'nextAction': next_action,
        'warnings': warnings,
        'externalVerification': False,
        'limits': {
            'scope': 'One saved project version and its stored local HTML; no network or code execution',
            'publicDeploymentVerified': False,
            'externalURLsChecked': False,
            'independentCertification': False,
            'paymentsVerified': False,
            'sourceContentVerified': False,
            'benchmarkTargetsAchieved': False,
        },
    }


def read(store, db, project_id, actor):
    row = store.access(db, project_id, actor)
    data = json.loads(row['data'])
    require(data['consents']['studio'], 'Использование Studio отключено в контракте.')
    return evaluate(db, project_id, row['version'], data)


def require_current_artifact(report):
    """Block broken local files while preserving the existing external-URL pilot."""
    failed = set(report['blockers'])
    require('asset_exists' not in failed,
            'HTML-файл не найден. Создайте прототип заново перед выпуском.', 'artifact_missing', 409)
    require('asset_integrity' not in failed,
            'SHA-256 HTML-файла не совпадает с сохранённым контрактом. Выпуск остановлен.', 'integrity_mismatch', 409)
    require('asset_source' not in failed,
            'Исходная версия сборки не найдена. Создайте прототип заново.', 'artifact_source_missing', 409)
    require('asset_inputs' not in failed,
            'HTML собран из прежней цели, аудитории, задач или критериев. Создайте новый прототип.', 'artifact_stale', 409)
