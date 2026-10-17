# OSGARD — связь релизного ZIP с манифестом

Теперь `scripts/verify-zip-manifest.py` побайтово проверяет **каждый распакованный файл ZIP** против списка имён, размеров и SHA-256 из манифеста, подготовленного предыдущим модулем. Проверяются также лишние и пропущенные файлы, дубликаты и опасные пути.

```sh
python3 scripts/release-artifact-manifest.py build dist --commit <COMMIT_SHA> --output /private/release-manifest.json
python3 scripts/verify-zip-manifest.py /private/OSGARD-RELEASE.zip --manifest /private/release-manifest.json
python3 -m unittest discover -s tests -p test_zip_manifest_binding.py -v
```

Важные условия: ZIP должен хранить файлы относительно корня сайта, `index.html` должен лежать в корне. Сохраните выданные ZIP SHA-256 и manifest SHA-256 для последующего сопоставления перед размещением.

Это проверяет совпадение двух предоставленных артефактов, но **не** доказывает, что сам манифест честно создан из заявленного коммита. Требуется доверенная сборка CI, подпись/attestation, независимая проверка развернутого сайта, и контроль секретов внутри файлов. Релиз и платежи скрипт не запускает.
