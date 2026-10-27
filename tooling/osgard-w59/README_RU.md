# W59 — аппаратная приёмка OSGARD, только подготовка

**PRODUCTION HOLD.** Программа проверяет структуру отчётов и SHA-256, но не доказывает происхождение файлов от физических устройств и не выдаёт разрешение на выпуск.

Проверенный исходный W58: `ef570cf6c406cc14ec180585ee2c5d64c667c658`, 9/9 GitHub Actions #40549670648. SHA-256 **внутреннего** кандидата: `d38390b6bc483431193ada34382330f101bb2aee3923f1eb619029f212fe7684`.

## 6 блоков

1. Точные SHA-256 исходного ZIP, каждого JSON, кадров CSV, PNG.
2. Физические Windows GPU, настольный WebGL GPU, Android Chrome, iPhone Safari; эмуляторы не считаются.
3. Запуск, шесть миссий, HERO/ECO, RU/EN, доступность, отсутствие аварий, клавиатура или touch и safe-area.
4. Реальные непрерывные покадровые CSV HERO/ECO, по минимум 1800 кадров и 120 секунд. Счёт медианы времени кадра и худшего 1% по данным, без заявления о сертифицированных 60 FPS.
5. 30-минутная термика: `elapsed_s,temperature_c,throttle`, где throttle принимает yes/no/unknown, температура может отсутствовать. Не подменять отсутствие датчика выдуманными измерениями.
6. Независимое ручное утверждение графики, реального оборудования, цепочки PR, проверки отката и отдельный подписанный GO — вне компетенции скрипта.

Из корня репозитория:

```bash
python3 tooling/osgard-w59/scaffold.py --evidence-dir W59_LOCAL_EVIDENCE
python3 tooling/osgard-w59/audit.py --evidence-dir W59_LOCAL_EVIDENCE --output W59_LOCAL_EVIDENCE/audit.json
python3 -m unittest discover -s tooling/osgard-w59 -p 'test_*.py' -v
```

scaffold создаёт **только пустые шаблоны**. В каталог candidate положите неизменный исходный внутренний ZIP W58, в reports — собственные JSON с настоящим source_sha, данными об оборудовании, UTC-временем старта и конца, manual_checks и оригинальными файлами, SHA-256. Заполняйте manifest.json путями и SHA-256 только собранных отчётов. Формат CSV кадров: `t_ms,frame_ms` — одна строка на каждый кадр. Термальный CSV: `elapsed_s,temperature_c,throttle`. RU и EN — оригинальные PNG с устройств.

Даже при полном наборе валидных самоотчётов будет только `HOLD / HUMAN_HARDWARE_ART_INTEGRATION_REVIEW_REQUIRED`, никогда GO. Не загружайте частные данные устройств в публичный GitHub. Никаких master-слияний, сайта, DNS/CDN/VPS/SSH и изменения игры.
