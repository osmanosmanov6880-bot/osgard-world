extends RefCounted
## W17 translations are presentation-only: gameplay, save format and QA stay unchanged.
const ACTION_EN = ["START MISSION", "DIAGNOSTICS", "NEXT VIEW", "SCAN TARGET",
    "ECO / HERO", "PLAY / PAUSE", "OPEN HATCH", "RESET VIEW"]
const ACTION_RU = ["НАЧАТЬ", "ДИАГНОСТИКА", "РАКУРС", "СКАНИРОВАТЬ",
    "ЭКО / ГЕРОЙ", "ПУСК / ПАУЗА", "ЛЮК", "СБРОС КАМЕРЫ"]
# Long phrases before short labels to preserve grammatical feedback.
const RU_PHRASES = {
    "SAFETY INTERLOCK: STOP DRIVE BEFORE OPENING": "БЛОКИРОВКА: ОСТАНОВИ ПРИВОД ПЕРЕД ОТКРЫТИЕМ",
    "SAFETY INTERLOCK: SEAL THE HATCH BEFORE STARTING": "БЛОКИРОВКА: ЗАКРОЙ ЛЮК ПЕРЕД ПУСКОМ",
    "SAFETY INTERLOCK: WAIT UNTIL HATCH SEALED": "БЛОКИРОВКА: ДОЖДИСЬ ЗАКРЫТИЯ ЛЮКА",
    "SAFETY INTERLOCK: COMPLETE MAINTENANCE FIRST": "БЛОКИРОВКА: ЗАВЕРШИ ОБСЛУЖИВАНИЕ",
    "SAFETY INTERLOCK: COMPLETE DIAGNOSTIC FIRST": "БЛОКИРОВКА: ЗАВЕРШИ ДИАГНОСТИКУ",
    "MISSION COMPLETE - SERVICE CYCLE RESTORED": "ОБУЧЕНИЕ ПРОЙДЕНО — ЦИКЛ ВОССТАНОВЛЕН",
    "PRESS START MISSION TO INSPECT": "НАЖМИ НАЧАТЬ ДЛЯ ОБУЧЕНИЯ",
    "PRESS START MISSION": "НАЧНИ ОБУЧЕНИЕ",
    "DIAGNOSTIC COMPLETE": "ДИАГНОСТИКА ЗАВЕРШЕНА",
    "FAULT CLEARED": "НЕИСПРАВНОСТЬ УСТРАНЕНА",
    "OPTICAL ALIGNMENT": "ЮСТИРОВКА ОПТИКИ",
    "COOLING AIRFLOW": "ВОЗДУШНОЕ ОХЛАЖДЕНИЕ",
    "SERVICE INTERLOCK": "БЛОКИРОВКА СЕРВИСНОГО ЛЮКА",
    "EDGE OFFSET": "СМЕЩЕНИЕ КРАЯ",
    "AIRFLOW BELOW TARGET": "ПОТОК НИЖЕ НОРМЫ",
    "CONTACT UNSEALED": "КОНТАКТ НЕ ЗАКРЫТ",
    "(SIM)": "(УЧЕБНО)",
    "DIAGNOSTICS READY — SELECT CHALLENGE": "ДИАГНОСТИКА ГОТОВА — ВЫБЕРИ СЦЕНАРИЙ",
    "SIMULATED FAULT FOUND": "ОБНАРУЖЕНА УЧЕБНАЯ НЕИСПРАВНОСТЬ",
    "OPTIONAL CHALLENGE: 3 FAULT SCENARIOS": "ТРИ УЧЕБНЫХ СЦЕНАРИЯ",
    "INSPECTION CLEARED - DRIVE RESTORED": "ОСМОТР ЗАВЕРШЁН — ПРИВОД ВКЛЮЧЁН",
    "TASK 1 / 4 - STOP DRIVE BEFORE OPENING HATCH": "ЗАДАНИЕ 1/4 — ОСТАНОВИ ПРИВОД ПЕРЕД ОТКРЫТИЕМ",
    "WAIT FOR THE STOPPED, OPEN HATCH": "ДОЖДИСЬ ОСТАНОВКИ И ОТКРЫТИЯ ЛЮКА",
    "START DIAGNOSTICS TO SCAN A TARGET": "НАЧНИ ДИАГНОСТИКУ ПЕРЕД СКАНИРОВАНИЕМ",
    "FOLLOW THE CURRENT OBJECTIVE": "СЛЕДУЙ ТЕКУЩЕЙ ЦЕЛИ",
    "INCORRECT VIEW — TARGET VIEW": "НЕВЕРНЫЙ РАКУРС — НУЖЕН РАКУРС",
    "CHECK AIRFLOW WITH ACCESS HATCH OPEN": "ПРОВЕРЬ ВОЗДУШНЫЙ КАНАЛ",
    "ALIGN OPTICS ONLY AFTER MOTOR STOP": "ПРОВЕРЬ ОПТИКУ ПОСЛЕ ОСТАНОВКИ",
    "VERIFY INTERLOCK SEAL BEFORE RESTART": "ПРОВЕРЬ ЗАКРЫТИЕ ЛЮКА",
    "OPEN THE SERVICE HATCH": "ОТКРОЙ СЕРВИСНЫЙ ЛЮК",
    "CLOSE THE SERVICE HATCH": "ЗАКРОЙ СЕРВИСНЫЙ ЛЮК",
    "INSPECT THE CORRECT FAULT": "ОСМОТРИ НУЖНЫЙ УЗЕЛ",
    "RESTART THE DRIVE": "ЗАПУСТИ ПРИВОД",
    "RESUME THE DRIVE": "ЗАПУСТИ ПРИВОД",
    "PAUSE THE DRIVE": "ОСТАНОВИ ПРИВОД",
    "STOP THE DRIVE": "ОСТАНОВИ ПРИВОД",
    "STOP DRIVE": "ОСТАНОВИ ПРИВОД",
    "OPEN SERVICE HATCH": "ОТКРОЙ СЕРВИСНЫЙ ЛЮК",
    "CLOSE SERVICE HATCH": "ЗАКРОЙ СЕРВИСНЫЙ ЛЮК",
    "WRONG ORDER": "НЕВЕРНЫЙ ПОРЯДОК",
    "CHECKPOINT": "ЭТАП",
    "SIM CLUE": "УЧЕБНЫЙ СИГНАЛ",
    "SIM ONLY": "ТОЛЬКО СИМУЛЯЦИЯ",
    "BEST SCORE": "РЕКОРД",
    "MODEL LOAD FAILED - CHECK GLB IMPORT": "МОДЕЛЬ НЕ ЗАГРУЖЕНА — ПРОВЕРЬ GLB",
    "CASES": "СЦЕНАРИИ", "CASE": "СЦЕНАРИЙ", "FAULT": "НЕИСПРАВНОСТЬ",
    "CLEARED": "ЗАВЕРШЁН", "LESSON": "УРОК", "PENALTY": "ШТРАФ",
    "ERRORS": "ОШИБКИ", "BEST": "РЕКОРД", "RUNS": "ПОПЫТКИ",
    "STEP": "ШАГ", "TASK": "ЗАДАНИЕ", "QUALITY": "ПРОФИЛЬ",
    "DRIVE": "ПРИВОД", "RUNNING": "РАБОТАЕТ", "PAUSED": "ОСТАНОВЛЕН",
    "OVERVIEW": "ОБЗОР", "VIEW": "РАКУРС", "SERVICE DECK": "СЕРВИСНАЯ ЗОНА",
    "OPTICAL HEAD": "ОПТИКА", "SIDE INSPECTION": "БОКОВОЙ ОСМОТР",
    "TRAIN": "ОБУЧЕНИЕ", "DIAGNOSE": "ДИАГНОСТИКА",
    "SCAN": "СКАНИРОВАТЬ", "CAMERA": "КАМЕРА", "SCORE": "СЧЁТ"
}
static func button_text(index: int, locale: String) -> String:
    if index < 0 or index >= ACTION_EN.size():
        return ""
    return ACTION_RU[index] if locale == "ru" else ACTION_EN[index]
static func notice(locale: String) -> String:
    if locale == "ru":
        return "ТОЛЬКО СИМУЛЯЦИЯ. Реальное обслуживание требует допуска, блокировки питания и проверки отсутствия энергии."
    return "SIMULATION ONLY. Real maintenance requires authorization, lockout and verified zero energy."
static func translate(value: String, locale: String) -> String:
    if locale != "ru":
        return value
    var translated: String = value
    for source in RU_PHRASES.keys():
        translated = translated.replace(str(source), str(RU_PHRASES[source]))
    return translated
