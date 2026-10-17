# Единый предрелизный контроль OSGARD — этап 01

**Назначение:** связать независимые результаты тестирования, проверки готового ZIP и проверки восстановленной SQLite-копии в один проверяемый пакет доказательств перед ручным решением о публикации. Этот инструмент не выполняет деплой и не изменяет production.

## Три независимых рабочих блока
- [PR 103](https://github.com/osmanosmanov6880-bot/osgard-world/pull/103): измерение результатов реального пилота; отдельный исследовательский инструмент, **не** является обязательным блокером для каждого статического релиза.
- [PR 104](https://github.com/osmanosmanov6880-bot/osgard-world/pull/104): проверка восстановимости уже созданного резервного файла SQLite. Не доказывает успешный полный запуск приложения с восстановленной базой.
- [PR 105](https://github.com/osmanosmanov6880-bot/osgard-world/pull/105): независимая проверка готового ZIP, включая целостность, опасные пути и лимиты распаковки.

**Важно:** пока эти PR не приняты в базовую ветку, новый общий gate не вызывает их как единый pipeline. Он оценивает существование и полноту внешних подтверждений. Ссылки на CI должны проверяться ответственным оператором, а не восприниматься как автоматически аутентифицированные: этот локальный скрипт **не обращается** в GitHub API.

## Формат входного свидетельства

```json
{
  "schema_version": 1,
  "release_id": "osgard-2026-10-17-candidate",
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "artifact_sha256": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  "payment_mode": "disabled",
  "publication_authorized": false,
  "checks": {
    "code_ci": {"status":"passed","evidence_url":"https://github.com/org/repo/actions/runs/1"},
    "frontend_ci": {"status":"passed","evidence_url":"https://github.com/org/repo/actions/runs/2"},
    "archive": {"status":"passed","evidence_url":"https://github.com/org/repo/actions/runs/3"},
    "backup_restore": {"status":"passed","evidence_url":"https://github.com/org/repo/actions/runs/4"},
    "smoke": {"status":"passed","evidence_url":"https://github.com/org/repo/actions/runs/5"}
  }
}
```

`commit_sha` допускает 64 шестнадцатеричных символа в текущей схеме как простую проверку формы, но реальные Git-коммиты GitHub SHA-1 обычно имеют **40** символов. Перед реальным использованием схемы необходимо исправить этот контракт на принимающий 40 или 64 символа — иначе валидный Git SHA-1 будет ложно отклонён. Не подставляйте случайный 64-символьный идентификатор. `artifact_sha256` должен быть точным хешем утверждаемого ZIP.

```sh
python3 scripts/unified-release-gate.py /private/release-evidence.json --artifact /private/release.zip
python3 -m unittest discover -s tests -p test_unified_release_gate.py -v
```

**Вывод `ready_for_human_review` — это не автоматическое разрешение на деплой.** Обязательны проверка подлинности ссылок и привязки всех результатов к точному коммиту/артефакту, подтверждённая восстановимость на инфраструктуре, ответственный оператор и процедура отката. Текущая версия сознательно запрещает `publication_authorized: true`, а оплаты должны оставаться выключенными.

Не загружайте данные покупателей, резервные копии, приватные ключи и реальные токены в репозиторий.
