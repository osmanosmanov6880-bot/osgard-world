extends RefCounted
class_name OSGARDText
## Offline RU/EN labels and explanations with an immutable simulation warning.

const RU = {
    "subtitle":"ИНТЕРАКТИВНАЯ ПРОМЫШЛЕННАЯ ЛАБОРАТОРИЯ",
    "lead":"Шесть учебных миссий · три неисправности · три аварийные смены",
    "sim":"ТОЛЬКО СИМУЛЯЦИЯ. НЕ ИНСТРУКЦИЯ ДЛЯ РЕАЛЬНОГО ОБОРУДОВАНИЯ.",
    "select":"ВЫБЕРИТЕ УЧЕБНУЮ МИССИЮ",
    "camera":"КАМЕРА",
    "view0":"01 / ОБЩИЙ ПЛАН", "view1":"02 / СЕРВИС", "view2":"03 / ОПТИКА",
    "drive_stop":"ОСТАНОВИТЬ ПРИВОД", "drive_start":"ЗАПУСТИТЬ ПРИВОД",
    "hatch_open":"ОТКРЫТЬ ЛЮК", "hatch_close":"ЗАКРЫТЬ ЛЮК",
    "scan":"СКАНИРОВАТЬ УЗЕЛ", "settings":"НАСТРОЙКИ",
    "a0":"ПОЛОЖЕНИЕ ЭМИТТЕРА", "b0":"ФОКУСИРОВКА",
    "a1":"КЛАПАН ПОДАЧИ", "b1":"МОЩНОСТЬ ВЕНТИЛЯТОРА",
    "a2":"ЛЕВЫЙ КОНТАКТ", "b2":"ПРАВЫЙ КОНТАКТ",
    "base0":"01 / ОПТИКА", "base1":"02 / ОХЛАЖДЕНИЕ", "base2":"03 / КОНТАКТЫ",
    "adv0":"04 / КОЛЕБАНИЕ ОПТИКИ", "adv1":"05 / ТЕПЛОВОЙ СКАЧОК", "adv2":"06 / ДРЕБЕЗГ КОНТАКТОВ",
    "locked":"ЗАКРЫТО", "cleared":"ПРОЙДЕНО", "best":"РЕКОРД",
    "rpm":"СКОРОСТЬ", "hatch":"ЛЮК", "score":"УЧЕБНЫЙ БАЛЛ", "elapsed":"ВРЕМЯ",
    "progress":"ПРОТОКОЛ", "step0":"ОСТАНОВ", "step1":"ЛЮК", "step2":"КАЛИБРОВКА", "step3":"ЗАКРЫТИЕ", "step4":"ПУСК",
    "stability":"СТАБИЛЬНОСТЬ", "signal":"ВИРТУАЛЬНЫЕ ПОКАЗАНИЯ",
    "privacy":"ЛОКАЛЬНАЯ СТАТИСТИКА", "sound":"ЗВУК", "captions":"СУБТИТРЫ",
    "motion":"СНИЖЕНИЕ АНИМАЦИИ", "erase":"УДАЛИТЬ МОИ ДАННЫЕ",
    "coach":"ПОЧЕМУ? / СЛЕДУЮЩИЙ ШАГ",
    "debrief":"ОЦЕНКА ОПЕРАТОРА · ИСТОРИЯ СМЕНЫ",
    "quality":"ГРАФИКА",
    "debrief_running":"Текущая миссия: решения и диагностические события фиксируются только в памяти.",
    "debrief_empty":"Выберите миссию, чтобы получить разбор действий и контрольных этапов.",
    "debrief_more":"ПОКАЗАТЬ ДЕЙСТВИЯ", "debrief_less":"СКРЫТЬ ДЕЙСТВИЯ",
    "retry":"ПОВТОРИТЬ МИССИЮ", "completed_grade":"УРОВЕНЬ",
    "grade_EXCELLENT":"ОТЛИЧНО", "grade_PROFICIENT":"ЗАЧЁТ", "grade_PRACTICE":"НУЖНА ПРАКТИКА",
    "errors_count":"ОШИБОК", "step_check":"КОНТРОЛЬНЫЕ ЭТАПЫ",
    "timeline":"ЛОКАЛЬНАЯ ИСТОРИЯ ПОПЫТКИ", "no_history":"Событий пока нет.",
    "erase_confirm_title":"УДАЛЕНИЕ ЛОКАЛЬНЫХ ДАННЫХ",
    "erase_confirm_text":"Удалить все учебные рекорды, настройки и необязательную статистику? Отменить это действие невозможно.",
    "retryUnavailable":"Повторить можно после завершения миссии.",
    "protocol_driveStopped":"Остановлен привод", "protocol_hatchOpened":"Открыт люк",
    "protocol_faultConfirmed":"Подтверждена калибровка", "protocol_hatchClosed":"Люк закрыт",
    "protocol_caseCompleted":"Безопасный повторный пуск",

    "idle":"Выберите базовый кейс. Продвинутые смены откроются после его прохождения.",
    "intro":"Обязательный порядок: остановка → дождаться ниже 80 RPM → люк → камера → калибровка → скан → закрытие → безопасный пуск.",
    "step_0":"Остановите привод. Не открывайте люк, пока ротор не замедлится ниже 80 RPM.",
    "step_1":"После остановки откройте люк и дождитесь полного открытия.",
    "step_2":"Выберите нужный ракурс, измените оба регулятора, удерживайте сигнал и сканируйте.",
    "step_3":"Диагностика принята. Закройте люк и дождитесь полной фиксации.",
    "step_4":"Люк герметичен. Запустите учебный привод для завершения миссии.",
    "step_done":"Миссия завершена. Повторите для улучшения учебного результата.",
    "shift_warm":"Сначала стабилизируйте исходные показания. Через 0,23 секунды произойдёт событие.",
    "shift_alert":"СОБЫТИЕ: прежняя настройка больше не подходит. Измените оба регулятора, удерживайте 1,25 секунды.",
    "cause0":"Смещение оптической метки искажает измерение. Нужна камера 03.",
    "cause1":"Воздушный поток и температура должны одновременно войти в допустимый диапазон. Нужна камера 02.",
    "cause2":"Два виртуальных контакта должны согласоваться. Нужна камера 02.",
    "error_wrongView":"НЕВЕРНЫЙ РАКУРС: выберите камеру нужного узла.",
    "error_safetyInterlock":"ЗАЩИТНАЯ БЛОКИРОВКА: привод остановлен и люк полностью закрыт перед пуском; ниже 80 RPM перед открытием.",
    "error_wrongOrder":"НЕВЕРНЫЙ ПОРЯДОК: завершите текущий шаг протокола.",
    "error_hatchInMotion":"ДОЖДИТЕСЬ: люк нельзя развернуть во время движения.",
    "error_calibrationNeeded":"СИГНАЛ НЕ ГОТОВ: два параметра должны быть в диапазоне достаточное время.",
    "error_calibrationLocked":"КАЛИБРОВКА ЗАБЛОКИРОВАНА: остановите привод, откройте люк, выберите верный ракурс.",
    "error_waitForHatch":"ЛЮК НЕ ГОТОВ: дождитесь полного открытия.",
    "error_shiftLocked":"Сначала пройдите соответствующий базовый кейс.",
    "error_alreadyActive":"Сначала завершите действующую миссию.",
    "error_incidentTriggered":"НОВАЯ НЕИСПРАВНОСТЬ: показания изменились, выполните повторную настройку.",
    "error_caseCompleted":"Миссия успешно завершена с соблюдением игровой безопасности.",
    "error_caseStarted":"Миссия запущена. Остановите виртуальный привод.",
    "error_shiftStarted":"Продвинутая смена запущена. Остановите виртуальный привод.",
    "error_dataCleared":"Результаты, настройки и статистика удалены с этого устройства.",
}

const EN = {
    "subtitle":"INTERACTIVE INDUSTRIAL SIMULATION LAB",
    "lead":"Six training missions · three faults · three incident shifts",
    "sim":"SIMULATION ONLY. NOT INSTRUCTIONS FOR REAL INDUSTRIAL EQUIPMENT.",
    "select":"SELECT A TRAINING MISSION",
    "camera":"CAMERA",
    "view0":"01 / OVERVIEW", "view1":"02 / SERVICE", "view2":"03 / OPTICS",
    "drive_stop":"STOP DRIVE", "drive_start":"START DRIVE",
    "hatch_open":"OPEN HATCH", "hatch_close":"CLOSE HATCH",
    "scan":"SCAN COMPONENT", "settings":"SETTINGS",
    "a0":"EMITTER ALIGNMENT", "b0":"FOCUS ADJUSTMENT",
    "a1":"AIRFLOW DAMPER", "b1":"FAN OUTPUT",
    "a2":"LEFT CONTACT", "b2":"RIGHT CONTACT",
    "base0":"01 / OPTICAL OFFSET", "base1":"02 / COOLING", "base2":"03 / HATCH CONTACT",
    "adv0":"04 / OPTICAL VIBRATION", "adv1":"05 / THERMAL SURGE", "adv2":"06 / CONTACT BOUNCE",
    "locked":"LOCKED", "cleared":"CLEARED", "best":"BEST",
    "rpm":"SPEED", "hatch":"HATCH", "score":"SIM SCORE", "elapsed":"TIME",
    "progress":"PROTOCOL", "step0":"STOP", "step1":"HATCH", "step2":"TUNE", "step3":"CLOSE", "step4":"START",
    "stability":"STABILITY", "signal":"SIMULATED READINGS",
    "privacy":"LOCAL METRICS", "sound":"SOUND", "captions":"CAPTIONS",
    "motion":"REDUCED ANIMATION", "erase":"ERASE MY DATA",
    "coach":"WHY? / NEXT ACTION",
    "debrief":"OPERATOR ASSESSMENT · SHIFT HISTORY",
    "quality":"GRAPHICS",
    "debrief_running":"Current mission: real actions and diagnostics are remembered in this session only.",
    "debrief_empty":"Choose a mission to see a review of your actions and safety checkpoints.",
    "debrief_more":"SHOW ACTIONS", "debrief_less":"HIDE ACTIONS",
    "retry":"REPLAY MISSION", "completed_grade":"GRADE",
    "grade_EXCELLENT":"EXCELLENT", "grade_PROFICIENT":"PROFICIENT", "grade_PRACTICE":"KEEP PRACTICING",
    "errors_count":"MISTAKES", "step_check":"SAFETY CHECKPOINTS",
    "timeline":"LOCAL ATTEMPT HISTORY", "no_history":"No actions yet.",
    "erase_confirm_title":"DELETE LOCAL DATA",
    "erase_confirm_text":"Erase all training results, preferences and optional statistics? This cannot be undone.",
    "retryUnavailable":"You can retry after completing a mission.",
    "protocol_driveStopped":"Drive stopped", "protocol_hatchOpened":"Hatch opened",
    "protocol_faultConfirmed":"Calibration confirmed", "protocol_hatchClosed":"Hatch sealed",
    "protocol_caseCompleted":"Safe restart confirmed",

    "idle":"Choose a basic case; each incident shift unlocks after completing its matching case.",
    "intro":"Follow the sequence: stop → below 80 RPM → hatch → view → tune → scan → close → safe restart.",
    "step_0":"Stop the drive. Wait below 80 RPM before opening the hatch.",
    "step_1":"After stopping, open the hatch and wait for full travel.",
    "step_2":"Choose the correct camera, tune both simulated channels, stabilize, then scan.",
    "step_3":"Scan accepted. Fully close and seal the hatch.",
    "step_4":"The hatch is sealed. Start the simulated drive to complete the mission.",
    "step_done":"Mission cleared. Replay to improve the training score.",
    "shift_warm":"Stabilize baseline readings. A scripted event triggers after 0.23 seconds.",
    "shift_alert":"INCIDENT: the old settings no longer match. Re-tune both controls and hold for 1.25 seconds.",
    "cause0":"Optical reference shift corrupts the simulated measurement. Use camera 03.",
    "cause1":"Airflow and temperature must simultaneously meet the target range. Use camera 02.",
    "cause2":"Two simulated hatch contacts must agree. Use camera 02.",
    "error_wrongView":"WRONG VIEW: select the correct inspection camera.",
    "error_safetyInterlock":"SAFETY INTERLOCK: fully seal the hatch before startup; wait below 80 RPM before opening.",
    "error_wrongOrder":"WRONG ORDER: complete the current protocol step first.",
    "error_hatchInMotion":"WAIT: the hatch cannot reverse direction while travelling.",
    "error_calibrationNeeded":"SIGNAL NOT READY: tune both parameters and sustain stability.",
    "error_calibrationLocked":"CALIBRATION LOCKED: stop, open the hatch, choose the correct camera.",
    "error_waitForHatch":"WAIT FOR HATCH: opening must finish before scanning.",
    "error_shiftLocked":"Clear the matching basic training case first.",
    "error_alreadyActive":"Finish your active mission before selecting another.",
    "error_incidentTriggered":"NEW INCIDENT: sensors shifted; recover the calibration.",
    "error_caseCompleted":"Mission cleared after the simulated safety procedure.",
    "error_caseStarted":"Case started. Stop the simulated drive.",
    "error_shiftStarted":"Advanced shift started. Stop the simulated drive.",
    "error_dataCleared":"Training records, preferences and local metrics were erased.",
}

static func text(locale: String, key: String) -> String:
    if locale == "en":
        return str(EN.get(key, RU.get(key, key)))
    return str(RU.get(key, key))

static func coach(locale: String, snap: Dictionary) -> String:
    var fault: int = int(snap.get("fault", -1))
    if fault < 0:
        return text(locale, "idle")
    var feedback := str(snap.get("feedback", "idle"))
    var detail := text(locale, "cause%d" % fault)
    var step := clampi(int(snap.get("step", 0)), 0, 4)
    if bool(snap.get("active", false)):
        detail += "\n" + text(locale, "step_%d" % step)
    elif bool(snap.get("complete", false)):
        detail += "\n" + text(locale, "step_done")
    if bool(snap.get("advanced", false)) and int(snap.get("step", 0)) == 2:
        detail += "\n" + text(locale, "shift_alert" if bool(snap.get("incident_triggered", false)) else "shift_warm")
    if bool(snap.get("last_error", false)) or feedback in ["incidentTriggered", "caseCompleted"]:
        detail += "\n\n" + text(locale, "error_" + feedback)
    return detail + "\n" + text(locale, "sim")
