extends RefCounted
## W21: deterministic explainable coaching derived ONLY from genuine simulator state.
## No hardware IO, ML guesses, network, user profiling, or mutation of game physics.
## Each result starts with the simple "why", then offers an optional deeper answer.

const LABELS_RU = [
    "ОПТИКА: ПОЧЕМУ ЭТО ВАЖНО",
    "ОХЛАЖДЕНИЕ: ПОЧЕМУ ЭТО ВАЖНО",
    "ЛЮК: ПОЧЕМУ НУЖНА БЛОКИРОВКА"
]
const LABELS_EN = [
    "OPTICS: WHY IT MATTERS",
    "COOLING: WHY IT MATTERS",
    "HATCH: WHY INTERLOCKS MATTER"
]
const CAUSES_RU = [
    "Учебное смещение оптического края означает, что точка измерения не совпала с ожидаемой.",
    "В этой симуляции поток воздуха ниже заданного значения; учебный индикатор показывает проблему охлаждения.",
    "В симуляторе датчик герметичности люка не подтвердил безопасное состояние."
]
const CAUSES_EN = [
    "The simulated optical edge is offset from its expected reference.",
    "Simulated airflow is below target; the training indicator identifies a cooling fault.",
    "The virtual access-hatch seal has not confirmed the safe state."
]
const DETAILS_RU = [
    "Смещение оптического сигнала может исказить результат измерения. В игровом сценарии проверяется выбор нужного узла и правильный порядок безопасного осмотра.",
    "Уменьшенный поток ухудшает условный отвод тепла. Игра проверяет, способен ли оператор заметить подсказку и выбрать боковой ракурс после остановки привода.",
    "Блокировка не допускает запуск, пока виртуальный люк не закрылся. Смысл урока — сначала устранить опасное состояние, а не обходить защиту."
]
const DETAILS_EN = [
    "An optical offset can corrupt measurements. This game tests locating the correct indicator and following a safe inspection sequence.",
    "Reduced simulated airflow affects virtual heat removal. The test is to notice the clue and use the side inspection view after stopping the drive.",
    "The simulated interlock prohibits restarting until the hatch is closed. The lesson is to resolve the unsafe state, not bypass protection."
]

static func _lang(ru: String, en: String, locale: String) -> String:
    return en if locale == "en" else ru


static func explain(state: Dictionary, chapter: int = 0, locale: String = "ru") -> Dictionary:
    var language: String = "en" if locale == "en" else "ru"
    var n: int = clampi(int(state.get("challenge_fault_index", 0)), 0, 2)
    var challenge: bool = bool(state.get("challenge_active", false))
    var done: bool = bool(state.get("challenge_completed", false))
    var mission: bool = bool(state.get("mission_active", false))
    var stage: int = clampi(int(state.get("challenge_step", 0)), 0, 5)
    var mistakes: int = maxi(0, int(state.get("challenge_errors", 0)))
    var feedback: String = str(state.get("challenge_feedback", ""))
    var saved_evidence: String = str(state.get("challenge_evidence", ""))
    var evidence: String = saved_evidence if "(SIM)" in saved_evidence else ""
    var title: String = _lang(LABELS_RU[n], LABELS_EN[n], language)
    var cause: String = _lang(CAUSES_RU[n], CAUSES_EN[n], language)
    var deeper: String = _lang(DETAILS_RU[n], DETAILS_EN[n], language)
    var next: String = ""
    var status: String = "overview"
    var error: bool = false

    if challenge or done:
        if done:
            status = "completed"
            next = _lang(
                "Учебный кейс закрыт. Сравните ошибки и счёт; повторение улучшает понимание причин.",
                "The simulated case is cleared. Review mistakes and score, then replay to understand the cause.",
                language)
        elif feedback.begins_with("INCORRECT VIEW"):
            status = "wrong_view"
            error = true
            next = _lang(
                "Выбран другой ракурс. Перейдите к подсвеченному учебному узлу, затем повторите сканирование.",
                "The camera is on the wrong view. Select the highlighted simulated target, then scan again.",
                language)
        elif feedback.begins_with("WRONG ORDER"):
            status = "wrong_order"
            error = true
            next = _lang(
                "Этап выполнен не по порядку. Сначала остановите учебный привод; следуйте показанной цели.",
                "The action was out of order. Stop the simulated drive first; follow the current objective.",
                language)
        elif feedback.begins_with("WAIT FOR THE STOPPED"):
            status = "wait_for_hatch"
            error = true
            next = _lang(
                "Сканирование запрещено, пока виртуальный люк не открыт полностью и привод не остановлен.",
                "Scanning is blocked until the virtual hatch is fully open and the drive is stopped.",
                language)
        else:
            match stage:
                0:
                    next = _lang("Начните с остановки учебного привода.", "Stop the simulated drive first.", language)
                1:
                    next = _lang("После остановки откройте учебный сервисный люк.", "After stopping, open the virtual service hatch.", language)
                2:
                    next = _lang(
                        "Дождитесь открытия люка, выберите показанный ракурс и сканируйте учебную метку.",
                        "Wait for the hatch, select the shown view, then scan the simulated indicator.",
                        language)
                3:
                    next = _lang("Закройте учебный люк.", "Close the simulated access hatch.", language)
                4:
                    next = _lang(
                        "Дождитесь полного закрытия, затем запустите виртуальный привод.",
                        "Wait for the hatch to seal before restarting the virtual drive.",
                        language)
                _:
                    next = _lang("Посмотрите итог учебного кейса.", "Review the case result.", language)
        if mistakes > 0 and not done:
            deeper += _lang(
                "\nОшибок в этой попытке: %d. Они влияют на учебный балл, но не отменяют блокировку опасных действий." % mistakes,
                "\nMistakes this attempt: %d. They affect the game score but never bypass safety interlocks." % mistakes,
                language)
    elif mission:
        status = "maintenance"
        title = _lang("ПОЧЕМУ СНАЧАЛА ОСТАНОВКА", "WHY THE DRIVE MUST STOP FIRST", language)
        cause = _lang(
            "Движущийся виртуальный механизм не должен допускать открытия сервисного люка.",
            "A moving simulated mechanism must not permit the service hatch to open.",
            language)
        deeper = _lang(
            "Учебная блокировка предотвращает опасный порядок: остановка → открытие → закрытие → полная фиксация → повторный пуск. Реальная процедура требует отдельного допуска и энергетической изоляции.",
            "The virtual interlock enforces stop → open → close → full seal → restart. Real equipment requires authorized lockout and verified isolation.",
            language)
        next = _lang(
            "Следуйте текущему этапу безопасного обслуживания.",
            "Follow the current safe-service objective.",
            language)
        var mission_feedback: String = str(state.get("mission_feedback", ""))
        if mission_feedback.begins_with("SAFETY INTERLOCK"):
            status = "interlock"
            error = true
            next = _lang(
                "Блокировка сработала верно. Не обходите защиту: сначала остановите привод или дождитесь закрытия люка.",
                "The interlock worked. Do not bypass it: stop the drive or wait for the hatch to seal.",
                language)
    else:
        status = "intro"
        title = _lang("ЗАЧЕМ НУЖЕН ПОРЯДОК", "WHY THE ORDER MATTERS", language)
        cause = _lang(
            "В этой игре каждое действие меняет состояние установки. Безопасное обслуживание начинается с остановки.",
            "Every action changes the virtual machine state. Safe inspection begins with stopping the drive.",
            language)
        deeper = _lang(
            "Вначале изучите ракурсы и элементы управления. Затем проверьте, как игровые блокировки отклоняют ошибочные команды.",
            "Explore camera views and controls first. Then test how virtual interlocks reject unsafe action sequences.",
            language)
        next = _lang(
            "Начните учебную миссию и наблюдайте, как меняются её цели.",
            "Start the training mission and watch how its objectives change.",
            language)
    if not challenge and not done and not mission and chapter == 5:
        status = "review"
        title = _lang("КАК ОЦЕНИТЬ РЕЗУЛЬТАТ", "HOW TO REVIEW YOUR PROGRESS", language)
        cause = _lang(
            "Прогресс трёх учебных неисправностей показывает, какие сценарии уже пройдены.",
            "Progress across three simulated faults shows which cases have been completed.",
            language)
        next = _lang(
            "Сравните число ошибок и повторите те задания, в которых возникли затруднения.",
            "Review errors and replay the situations that were difficult.",
            language)
    return {
        "status": status,
        "fault_index": n,
        "title": title,
        "cause": cause,
        "deeper": deeper,
        "next": next,
        "evidence": evidence,
        "error": error,
        "mistakes": mistakes,
        "simulation_only": true
    }
