(function () {
  "use strict";
  const STORAGE_KEY = "zion9-language";
  const translations = {
    "ZION-9 — Infinite Worlds": "ZION-9 — Бесконечные миры",
    "ZION-9 — Transmission Index": "ZION-9 — Архив сигналов",
    "BASALT LULLABY — ZION-9": "БАЗАЛЬТОВАЯ КОЛЫБЕЛЬ — ZION-9",
    "THE SILENT ARCHIVE — ZION-9": "ТИХИЙ АРХИВ — ZION-9",
    "GLASS ORCHARD — ZION-9": "СТЕКЛЯННЫЙ САД — ZION-9",
    "THE LAST TIDE ENGINE — ZION-9": "ПОСЛЕДНИЙ ПРИЛИВНЫЙ МЕХАНИЗМ — ZION-9",
    "VELVET FREQUENCY — ZION-9": "БАРХАТНАЯ ЧАСТОТА — ZION-9",
    "THE PALE EQUATION — ZION-9": "БЛЕДНОЕ УРАВНЕНИЕ — ZION-9",
    "POLAR COMPASS — ZION-026": "ПОЛЯРНЫЙ КОМПАС — ZION-026",
    "THE BRONZE HOUR — ZION-9": "БРОНЗОВЫЙ ЧАС — ZION-9",
    "MIRROR WEATHER — ZION-9": "ЗЕРКАЛЬНАЯ ПОГОДА — ZION-9",
    "THE BLUE INTERVAL — ZION-9": "СИНИЙ ИНТЕРВАЛ — ZION-9",
    "ZION-9 Infinite Worlds — ten interactive narrative prototypes.": "ZION-9 — десять интерактивных сюжетных миров.",
    "Public ZION-9 world archive.": "Публичный архив миров ZION-9.",
    "An abandoned observatory sends three pulses through a field of black glass.": "Заброшенная обсерватория посылает три импульса через поле чёрного стекла.",
    "A paper archive remembers every visitor except the person who built it.": "Бумажный архив помнит каждого посетителя, кроме того, кто его создал.",
    "A glass orchard rings softly as distant planets cross its reflected sky.": "Стеклянный сад тихо звенит, когда далёкие планеты пересекают отражённое в нём небо.",
    "A tidal machine keeps a lost city alive in carefully timed waves.": "Приливный механизм поддерживает жизнь затонувшего города точно рассчитанными волнами.",
    "A tidal machine keeps a drowned city breathing in carefully timed waves.": "Приливный механизм поддерживает дыхание затонувшего города точно рассчитанными волнами.",
    "A velvet-dark radio room receives a melody from a station that has no location.": "В окутанной бархатом тьмы радиорубке ловят мелодию станции, которой нет ни на одной карте.",
    "A chalk equation moves one symbol each time the room's light changes.": "В меловом уравнении один символ сдвигается каждый раз, когда меняется освещение комнаты.",
    "A compass in a snowbound field turns only when someone listens to the stillness.": "Компас среди снегов поворачивается лишь тогда, когда кто-то вслушивается в тишину.",
    "A snowbound compass turns only when a player listens to the stillness.": "Компас среди снегов поворачивается лишь тогда, когда игрок вслушивается в тишину.",
    "A bronze clock has thirteen hands, though only three cast shadows.": "У бронзовых часов тринадцать стрелок, но тени отбрасывают лишь три.",
    "Mirrors predict weather for a place that no longer exists on any map.": "Зеркала предсказывают погоду в месте, которого больше нет ни на одной карте.",
    "A blue interval appears between two notes and opens an impossible door.": "Между двумя нотами возникает синий интервал, открывающий невозможную дверь.",
    "There is more": "Существует больше",
    "than one reality.": "одной реальности.",
    "Ten signals. Ten doors. Each world starts with a small anomaly — and opens when you learn how to listen.": "Десять сигналов. Десять дверей. Каждый мир начинается с небольшой аномалии — и раскрывается, когда вы учитесь слушать.",
    "World archive / 10 transmissions": "Архив миров / 10 сигналов",
    "Free static release · story prototypes": "Бесплатная версия · сюжетные прототипы",
    "Explore worlds": "Исследовать миры",
    "EXPLORE WORLDS": "ИССЛЕДОВАТЬ МИРЫ",
    "TRANSMISSION INDEX": "АРХИВ СИГНАЛОВ",
    "Available transmissions": "Доступные сигналы",
    "10 WORLDS / STATIC PROTOTYPES": "10 МИРОВ / ИНТЕРАКТИВНЫЕ ПРОТОТИПЫ",
    "Interactive worlds": "Интерактивные миры",
    "ENTER WORLD": "ВОЙТИ В МИР",
    "OPEN WORLD": "ОТКРЫТЬ МИР",
    "Every signal": "Каждый сигнал",
    "opens a world.": "открывает мир.",
    "Public world directory": "Каталог миров",
    "Ten self-contained narrative prototypes. Open a transmission to explore its world. No account required.": "Десять самостоятельных сюжетных прототипов. Откройте сигнал, чтобы исследовать мир. Регистрация не нужна.",
    "← MAIN ARCHIVE": "← ГЛАВНЫЙ АРХИВ",
    "← ALL WORLDS": "← ВСЕ МИРЫ",
    "← WORLD ARCHIVE": "← АРХИВ МИРОВ",
    "Public story build · static HTML · no private operator data in this archive": "Публичная версия · статический HTML · без внутренних данных оператора",
    "Public story prototype · no account needed": "Публичный сюжетный прототип · регистрация не нужна",
    "Transmission index ↗": "Архив сигналов ↗",
    "Transmission index": "Архив сигналов",
    "Archive index ↗": "Архив миров ↗",
    "Operator dashboard ↗": "Панель оператора ↗",
    "Operator dashboard": "Панель оператора",
    "Signal study / QUARTZ-ORBIT-3": "Исследование сигнала / QUARTZ-ORBIT-3",
    "Signal study / PAPER-MOON-8": "Исследование сигнала / PAPER-MOON-8",
    "Read the resonance": "Считайте резонанс",
    "Tap the signals from lowest resonance to highest. An incorrect choice resets the sequence.": "Нажимайте на сигналы от самого слабого резонанса к сильному. Ошибочный выбор сбрасывает последовательность.",
    "Three signals are waiting. Start with the quietest.": "Ожидают три сигнала. Начните с самого тихого.",
    "Signal decoded": "Сигнал расшифрован",
    "The quiet signal was a lighthouse, not a distress call.": "Тихий сигнал оказался маяком, а не призывом о помощи.",
    "The missing page was never destroyed; it was waiting to be read aloud.": "Пропавшую страницу не уничтожили — она ждала, когда её прочтут вслух.",
    "Reset signal": "Сбросить сигнал",
    "Field note / 01": "Заметка исследователя / 01",
    "Field note / 02": "Заметка исследователя / 02",
    "Some worlds open when you notice what is already there.": "Некоторые миры открываются, когда замечаешь то, что уже рядом.",
    "There is no timer and no penalty. Explore the signals at your own pace. This unpublished prototype uses a narrative reveal, not a private ARG key.": "Здесь нет таймера и штрафов. Исследуйте сигналы в своём темпе. Это сюжетный прототип, а не закрытая головоломка с секретным ключом.",
    "Touch • Keyboard • Reduced motion": "Сенсорный экран • Клавиатура • Без лишней анимации",
    "ZION-9 • Draft build": "ZION-9 • Черновая версия",
    "Interactive transmission · ZION-022": "Интерактивный сигнал · ZION-022",
    "Wake the orchard without breaking its silence.": "Разбудите сад, не нарушив его тишину.",
    "Bloom": "Цветение",
    "One transparent petal warms in your hand.": "Прозрачный лепесток теплеет у вас в руке.",
    "Fruit": "Плод",
    "A small sun rolls inside a crystal shell.": "Внутри хрустальной оболочки перекатывается маленькое солнце.",
    "Root": "Корень",
    "The ground answers with a low, patient note.": "Земля отвечает низкой, терпеливой нотой.",
    "Transmission received": "Сигнал принят",
    "Each fruit stores a decision that was never made. The orchard offers no way to choose again — only a place to finally let the old choice go.": "Каждый плод хранит решение, которое так и не было принято. Сад не даёт выбрать заново — он лишь позволяет наконец отпустить старый выбор.",
    "Interactive transmission · ZION-023": "Интерактивный сигнал · ZION-023",
    "Read the machine's rhythm.": "Прочитайте ритм механизма.",
    "01 · Rise": "01 · Подъём",
    "A bronze wheel turns against the current.": "Бронзовое колесо вращается против течения.",
    "02 · Hold": "02 · Пауза",
    "The water pauses at the edge of a doorway.": "Вода замирает на пороге.",
    "03 · Return": "03 · Возвращение",
    "A lantern drifts home through the dark water.": "Фонарь плывёт домой сквозь тёмную воду.",
    "Open transmission / reveal": "Открыть послание",
    "The city is not beneath the water. It is the memory carried by it — and the engine has been keeping that memory alive one wave at a time.": "Город не под водой. Он — память, которую несёт вода. И механизм сохраняет её живой, волна за волной.",
    "Interactive transmission · ZION-024": "Интерактивный сигнал · ZION-024",
    "Build a receiver from the sounds that remain.": "Соберите приёмник из оставшихся звуков.",
    "01 · Hiss": "01 · Шипение",
    "The static takes the shape of distant rain.": "Помехи складываются в звук далёкого дождя.",
    "02 · Hum": "02 · Гул",
    "A warm note settles beneath your ribs.": "Тёплая нота оседает где-то под рёбрами.",
    "03 · Silence": "03 · Тишина",
    "For one second, the whole room listens back.": "На одну секунду вся комната начинает слушать вас.",
    "The broadcast is a map whose distance is measured in trust. The last coordinate appears only when you stop trying to force the signal.": "Передача — это карта, расстояние на которой измеряется доверием. Последняя координата появляется, когда вы перестаёте заставлять сигнал звучать.",
    "Interactive transmission · ZION-025": "Интерактивный сигнал · ZION-025",
    "Observe what the room changes when you look away.": "Заметьте, что меняется в комнате, когда вы отворачиваетесь.",
    "01 · Light": "01 · Свет",
    "The shadow shifts, leaving a clean square on the wall.": "Тень смещается, оставляя на стене чистый квадрат.",
    "02 · Chalk": "02 · Мел",
    "A white line continues under the locked door.": "Белая линия продолжается под запертой дверью.",
    "03 · Window": "03 · Окно",
    "A reflection reveals stars on the inside of the glass.": "Отражение показывает звёзды по внутреннюю сторону стекла.",
    "The equation describes the room's forgotten window. It measures the light needed to remember the outside.": "Уравнение описывает забытое окно комнаты. Оно измеряет, сколько света нужно, чтобы вспомнить внешний мир.",
    "Interactive transmission · ZION-026": "Интерактивный сигнал · ZION-026",
    "POLAR COMPASS": "ПОЛЯРНЫЙ КОМПАС",
    "01 · Listen": "01 · Слушать",
    "The wind moves across the white field.": "Ветер проходит над белым полем.",
    "02 · Look": "02 · Смотреть",
    "One star stays still as the sky turns.": "Одна звезда остаётся неподвижной, пока вращается небо.",
    "03 · Follow": "03 · Следовать",
    "A line of footprints appears beyond the ridge.": "За гребнем появляется цепочка следов.",
    "Open transmission": "Открыть послание",
    "North is a direction chosen by the promise you keep.": "Север — это направление, которое выбирает данное вами обещание.",
    "Interactive transmission · ZION-027": "Интерактивный сигнал · ZION-027",
    "Find the hour the mechanism forgot.": "Найдите час, который забыл механизм.",
    "01 · Gear": "01 · Шестерня",
    "A tooth clicks into place without touching another.": "Зубец встаёт на место, не касаясь соседнего.",
    "02 · Shadow": "02 · Тень",
    "A fourth shadow points beneath the dial.": "Четвёртая тень указывает под циферблат.",
    "03 · Bell": "03 · Колокол",
    "A low note rings once, though no hammer falls.": "Раздаётся низкая нота, хотя молоток не ударял.",
    "The extra hour belongs to anyone who chooses to begin again. It can only be spent on something that matters.": "Дополнительный час принадлежит тому, кто решает начать заново. Потратить его можно лишь на то, что действительно важно.",
    "Interactive transmission · ZION-028": "Интерактивный сигнал · ZION-028",
    "Compare the forecasts.": "Сравните прогнозы.",
    "01 · Rain": "01 · Дождь",
    "Silver droplets gather on the inside of the glass.": "Серебряные капли собираются на внутренней стороне стекла.",
    "02 · Wind": "02 · Ветер",
    "A curtain moves in a room with no open window.": "В комнате без открытого окна шевелится занавеска.",
    "03 · Sun": "03 · Солнце",
    "A warm horizon appears behind your reflection.": "За вашим отражением возникает тёплый горизонт.",
    "The forecast describes a world that has not yet been made. Your next decision will change the view.": "Прогноз описывает мир, который ещё не создан. Ваше следующее решение изменит картину.",
    "Interactive transmission · ZION-029": "Интерактивный сигнал · ZION-029",
    "Listen for the space between the notes.": "Прислушайтесь к пространству между нотами.",
    "01 · First note": "01 · Первая нота",
    "A blue thread appears in the air.": "В воздухе возникает синяя нить.",
    "02 · Interval": "02 · Интервал",
    "The silence becomes wide enough to step through.": "Тишина становится достаточно широкой, чтобы шагнуть в неё.",
    "03 · Answer": "03 · Ответ",
    "A second voice joins the melody from the other side.": "С другой стороны к мелодии присоединяется второй голос.",
    "The interval was the space left for someone else to answer. The door opens only as wide as the conversation allows.": "Интервал был пространством, оставленным для чужого ответа. Дверь открывается ровно настолько, насколько позволяет разговор.",
    "World 027": "Мир 027",
    "A room contains a strange dial and four shifting shadows.": "В комнате находятся странный циферблат и четыре движущиеся тени.",
    "Signal one": "Сигнал один",
    "A narrow line of light moves across the wall.": "Узкая полоска света скользит по стене.",
    "Signal two": "Сигнал два",
    "A quiet sound comes from behind the dial.": "Из-за циферблата доносится тихий звук.",
    "Signal three": "Сигнал три",
    "A small mark appears where no mark was before.": "Там, где ничего не было, появляется маленькая отметка.",
    "The room gives an extra moment to anyone ready to begin again.": "Комната дарит лишнее мгновение тому, кто готов начать заново.",
    "Transmission 028": "Передача 028",
    "A quiet signal appears where the glass catches the last light.": "Когда стекло ловит последний свет, возникает тихий сигнал.",
    "One drop glimmers on the other side.": "По ту сторону мерцает одна капля.",
    "A curtain moves without a breeze.": "Занавеска движется без ветра.",
    "A warm line settles across the horizon.": "На горизонте ложится тёплая полоса света.",
    "The image waits for the next choice to give it a future.": "Отражение ждёт следующего выбора, который определит его будущее.",
    "Resonance": "Резонанс",
    "Sequence stable. The signal is yours.": "Последовательность устойчива. Теперь сигнал принадлежит вам.",
    "Sequence reset. Start with the quietest.": "Последовательность сброшена. Начните с самого тихого сигнала.",
    "The sequence has reset. Try again, lowest to highest.": "Последовательность сброшена. Попробуйте снова — от слабого резонанса к сильному.",
    "Transmission index ↗": "Архив сигналов ↗"
  };
  Object.assign(translations, {
    "BASALT LULLABY": "БАЗАЛЬТОВАЯ КОЛЫБЕЛЬ",
    "THE SILENT ARCHIVE": "ТИХИЙ АРХИВ",
    "GLASS ORCHARD": "СТЕКЛЯННЫЙ САД",
    "THE LAST TIDE ENGINE": "ПОСЛЕДНИЙ ПРИЛИВНЫЙ МЕХАНИЗМ",
    "VELVET FREQUENCY": "БАРХАТНАЯ ЧАСТОТА",
    "THE PALE EQUATION": "БЛЕДНОЕ УРАВНЕНИЕ",
    "NORTH OF SLEEP": "СЕВЕР СНА",
    "THE BRONZE HOUR": "БРОНЗОВЫЙ ЧАС",
    "MIRROR WEATHER": "ЗЕРКАЛЬНАЯ ПОГОДА",
    "THE BLUE INTERVAL": "СИНИЙ ИНТЕРВАЛ",
    "ZION-9 / INFINITE WORLDS": "ZION-9 / БЕСКОНЕЧНЫЕ МИРЫ",
    "◉ ZION-9 / TRANSMISSION INDEX": "◉ ZION-9 / АРХИВ СИГНАЛОВ",
    "◉ ZION-9 / Infinite Worlds": "◉ ZION-9 / Бесконечные миры",
    "World prototypes": "Прототипы миров",
    "World archive": "Архив миров",
    "World archive / 10 transmissions": "Архив миров / 10 сигналов",
    "Every signal": "Каждый сигнал",
    "opens a world.": "открывает мир.",
    "Signal decoded": "Сигнал расшифрован",
    "Signal held.": "Сигнал удержан.",
    "Prototype • ZION-020": "Прототип • ZION-020",
    "Prototype • ZION-021": "Прототип • ZION-021",
    "Interactive transmission": "Интерактивный сигнал",
    "Signal study": "Исследование сигнала",
    "Public story build": "Публичная версия истории",
    "Draft build": "Черновая версия",
    "STATIC BUILD": "СТАТИЧЕСКАЯ СБОРКА",
    "No trackers · no external scripts ·": "Без трекеров · без внешних скриптов ·",
    "Some worlds open when you notice what is already there.": "Некоторые миры открываются, когда замечаешь то, что уже рядом.",
    "Signal held.": "Сигнал удержан.",
    "WORLD ARCHIVE": "АРХИВ МИРОВ",
    "ALL WORLDS": "ВСЕ МИРЫ",
    "MAIN ARCHIVE": "ГЛАВНЫЙ АРХИВ",
    "Resonance 11": "Резонанс 11",
    "Resonance 18": "Резонанс 18",
    "Resonance 27": "Резонанс 27",
    "Resonance 42": "Резонанс 42",
    "Resonance 58": "Резонанс 58",
    "Resonance 73": "Резонанс 73"
  });
  Object.assign(translations, {
    "ZION-9 / MONOLITH · EPISODE 030": "ZION-9 / МОНОЛИТ · ЭПИЗОД 030",
    "← WORLD ARCHIVE": "← АРХИВ МИРОВ",
    "ENTER 3D WORLD ↗": "ВОЙТИ В 3D-МИР ↗",
    "Athens, Greece · 11 October 2026": "Афины, Греция · 11 октября 2026",
    "THE SHADE": "ТЕНЕВОЙ",
    "PROTOCOL": "ПРОТОКОЛ",
    "A city heat mission in Athens.": "Миссия против городского перегрева в Афинах.",
    "Athens has already measured a way out: exposed paving reached 60°C while ground under tree shade measured 30°C in a 2025 field report. ZION-9 turns that evidence into a playable city-planning mission.": "В Афинах уже измерили один из способов решения: в полевом отчёте за 2025 год открытое покрытие нагревалось до 60°C, а поверхность в тени деревьев — до 30°C. ZION-9 превращает эти данные в интерактивную миссию по планированию города.",
    "PLAY THE 3D MISSION ↗": "ИГРАТЬ В 3D-МИССИЮ ↗",
    "OPEN LOCATION MAP ↗": "ОТКРЫТЬ ТОЧКУ НА КАРТЕ ↗",
    "Illustrative Athens street-tree photograph by Philip Mallis, ": "Иллюстративное фото уличного дерева в Афинах: Philip Mallis, ",
    "Wikimedia Commons": "Wikimedia Commons",
    ", CC BY-SA 2.0. Photo is not the measured square itself.": ", CC BY-SA 2.0. Фото сделано не на площади, где проводились замеры.",
    "Verified episode evidence": "Проверенные данные эпизода",
    "Field measurement · 2025": "Полевые замеры · 2025",
    "Exposed paving vs tree shade at Argentinis Dimokratias Square.": "Открытое покрытие и тень деревьев на площади Аргентинис-Димократиас.",
    "Other measured site": "Другая площадка",
    "Surface heat reduction reported with cool materials and shade at Agia Irini Square.": "Сообщённое снижение температуры поверхности благодаря прохладным материалам и тени на площади Агиа-Ирини.",
    "City response": "Ответ города",
    "New trees reported planted in Athens over 18 months by the EU city initiative.": "Число новых деревьев, о высадке которых в Афинах сообщили за 18 месяцев в рамках европейской городской инициативы.",
    "Cooling Havens plan": "План Cooling Havens",
    "Planned blue-green infrastructure across six locations; target, not a verified completed total.": "Планируемая голубо-зелёная инфраструктура в шести местах; это цель проекта, а не подтверждённый объём завершённых работ.",
    "01 / Place and pain": "01 / Место и проблема",
    "REAL CITY · CLIMATE / HEALTH": "РЕАЛЬНЫЙ ГОРОД · КЛИМАТ / ЗДОРОВЬЕ",
    "Greece": "Греция",
    "Urban heat": "Городской перегрев",
    "Climate adaptation": "Адаптация к климату",
    "Argentinis Dimokratias Square, Athens": "Площадь Аргентинис-Димократиас, Афины",
    "Reference coordinates:": "Координаты ориентира:",
    "The episode uses the square as a real urban context; the 2025 thermal figures are attributed to the EU Covenant of Mayors article and municipality measurements.": "В эпизоде площадь используется как реальный городской контекст; тепловые показатели за 2025 год приведены в публикации Covenant of Mayors и муниципальных замерах.",
    "Open exact map point ↗": "Открыть точку на карте ↗",
    "Read field report ↗": "Читать полевой отчёт ↗",
    "Category · climate": "Категория · климат",
    "Health and access": "Здоровье и доступность",
    "The pain is not “summer.” It is unequal access to cool space.": "Проблема не в самом «лете», а в неравном доступе к прохладным общественным местам.",
    "Sun-exposed pavement can become much hotter than shaded ground. Older people, outdoor workers, children, pregnant people and people with chronic illness are among the groups the city warns are more vulnerable during heatwaves.": "Покрытие под прямым солнцем может нагреваться гораздо сильнее, чем поверхность в тени. Город отдельно предупреждает о повышенной уязвимости пожилых людей, работников на открытом воздухе, детей, беременных и людей с хроническими заболеваниями.",
    "The city website lists 637,798 residents on its city page. That is the city population for context — not a claim that every resident is equally affected or a count of heat casualties.": "На сайте города указано 637 798 жителей. Это численность населения муниципалитета для контекста, а не оценка числа пострадавших от жары и не утверждение, что все жители подвержены риску одинаково.",
    "Municipality population and city context ↗": "Население и сведения о городе ↗",
    "City heat-safety service ↗": "Городской сервис безопасности в жару ↗",
    "Evidence rule:": "Правило доказательности:",
    "60°C and 30°C are surface-temperature readings, not air-temperature measurements. The −5°C and 70% rainwater figures for Cooling Havens are programme targets described by the municipality, not independently verified outcomes for every site.": "60°C и 30°C — показания температуры поверхности, а не воздуха. Показатели −5°C и 70% удержания дождевой воды для Cooling Havens — цели программы, указанные муниципалитетом, а не независимо подтверждённые результаты для каждой площадки.",
    "02 / Technology already in use": "02 / Уже работающая технология",
    "NOT SCIENCE FICTION": "НЕ НАУЧНАЯ ФАНТАСТИКА",
    "Operational public information": "Действующий информационный сервис",
    "#CoolAthens + heat-risk intelligence": "#CoolAthens + анализ тепловых рисков",
    "The Municipality of Athens says its heatwave categorisation was built using two decades of historical weather and mortality data, in collaboration with the National Observatory of Athens and other partners. The municipal portal links to temperature and thermal-discomfort maps updated every 15 minutes and describes the EXTREMA app’s heat-risk, cool-route and nearby-cooling-place features.": "Муниципалитет Афин сообщает, что система категоризации волн жары создана на основе двадцати лет исторических метеоданных и данных о смертности совместно с Национальной обсерваторией Афин и другими партнёрами. Муниципальный портал ведёт к картам температуры и теплового дискомфорта, обновляемым каждые 15 минут, и описывает возможности приложения EXTREMA: оценку риска, прохладные маршруты и поиск ближайших мест для охлаждения.",
    "Open official #CoolAthens service ↗": "Открыть официальный сервис #CoolAthens ↗",
    "Interventions + monitoring": "Меры и мониторинг",
    "Cooling Havens and shade-first design": "Cooling Havens и проектирование с приоритетом тени",
    "The Athens project specifies rainwater collection and reuse, rain gardens, natural filtration channels, blue-green public space and IoT sensors. The municipal page describes six intervention locations, more than 10 co-design workshops, training for 40 people from vulnerable groups and 25 municipal staff, and over 8,000 m² of planned infrastructure.": "Афинский проект предусматривает сбор и повторное использование дождевой воды, дождевые сады, естественные фильтрационные каналы, голубо-зелёные общественные пространства и IoT-датчики. На странице муниципалитета указаны шесть площадок, более десяти совместных проектных семинаров, обучение 40 человек из уязвимых групп и 25 муниципальных сотрудников, а также более 8 000 м² планируемой инфраструктуры.",
    "Separately, the EU city initiative reports measured results from 2025 interventions: tree shade at Argentinis Dimokratias Square, cool materials and shade at Agia Irini, a microforest at Ano Kypseli and a cooling garden at Serafio.": "Отдельно европейская городская инициатива сообщает о результатах измерений вмешательств 2025 года: тень деревьев на площади Аргентинис-Димократиас, прохладные материалы и затенение на площади Агиа-Ирини, микролес в Ано-Кипсели и охлаждающий сад в Серафио.",
    "Cooling Havens · Municipality of Athens ↗": "Cooling Havens · муниципалитет Афин ↗",
    "National Technical University of Athens research group ↗": "Исследовательская группа Национального технического университета Афин ↗",
    "03 / 75-second video episode": "03 / Видеовыпуск на 75 секунд",
    "10 SHOTS · HOOK IN 0–2 SEC": "10 КАДРОВ · ХУК В ПЕРВЫЕ 0–2 СЕКУНДЫ",
    "Hook / heat shock": "Хук / тепловой шок",
    "Macro of sunlit stone; hard cut to thermal-camera red. On-screen: “60°C in the sun. 30°C under shade.”": "Крупный план нагретого камня; резкая склейка на красное изображение тепловизора. Титр: «60°C на солнце. 30°C в тени».",
    "Athens arrival": "Прибытие в Афины",
    "Wide street shot in Athens. ZION-9 enters frame in a graphite coat; no staged distress or close-ups of vulnerable passers-by.": "Общий план улицы Афин. В кадр входит ZION-9 в графитовом плаще; не инсценировать бедствие и не снимать крупным планом уязвимых прохожих.",
    "The point": "Указание",
    "ZION points to empty pavement. Cyan grid emerges over the street; the hot zone pulses orange.": "ZION указывает на пустое покрытие. Над улицей возникает бирюзовая сетка, горячая зона пульсирует оранжевым.",
    "Show evidence": "Доказательство",
    "Source card names the 2025 field report and distinguishes surface from air temperature.": "Карточка источника указывает полевой отчёт за 2025 год и подчёркивает разницу между температурой поверхности и воздуха.",
    "Existing solution": "Существующее решение",
    "Cut to a public heat-risk map, urban canopy and a rain garden. Overlay “shade · water · measurement”.": "Переход к публичной карте теплового риска, городской кроне и дождевому саду. Титр: «тень · вода · измерения».",
    "World birth": "Рождение мира",
    "Procedural 3D city rises from the asphalt; a C–G–E motif rings once.": "Процедурный 3D-город поднимается из асфальта; один раз звучит мотив C–G–E.",
    "Player solves": "Игрок решает задачу",
    "Choose and place a tree, canopy and rain garden.": "Выбрать и разместить дерево, теневой навес и дождевой сад.",
    "Win": "Победа",
    "All hotspots turn green; show clear game victory.": "Все горячие точки становятся зелёными; показать ясное состояние победы.",
    "Human impact": "Человеческий эффект",
    "Show shade, accessible routes and public space without implying the prototype has already changed real infrastructure.": "Показать тень, доступные маршруты и общественное пространство, не утверждая, что прототип уже изменил реальную инфраструктуру.",
    "CTA": "Призыв к действию",
    "Invite viewers to play and share with city planners.": "Пригласить зрителей сыграть и поделиться выпуском с городскими планировщиками.",
    "Voice-over / EN draft": "Текст озвучки / EN",
    "This pavement reached sixty degrees. Under tree shade, the surface measured thirty. Athens is already testing shade, green space, water and heat-risk maps. ZION-9 turns that evidence into a mission: three hotspots, three interventions. Can you build a cooler block? Enter The Shade Protocol. Then share it with the people who shape your city.": "Это покрытие нагрелось до шестидесяти градусов. Под тенью деревьев поверхность показала тридцать. Афины уже испытывают решения: тень, зелёные зоны, воду и карты теплового риска. ZION-9 превращает эти данные в миссию: три горячие точки, три вмешательства. Сможешь сделать квартал прохладнее? Войди в «Теневой протокол» и отправь его тем, кто меняет твой город.",
    "Голос за кадром / RU": "Голос за кадром / RU",
    "RU draft": "Черновик на русском",
    "VFX + production plan": "VFX + план производства",
    "VFX: procedural thermal palette; point-to-portal line; city blocks rise from a 3D grid; green coverage rings at victory. Sound: original three-note C–G–E motif generated with Web Audio API. Voice: operator’s own voice or licensed voice-over. Edit: CapCut/Premiere. Target budget: €0–€50 excluding operator labour and any paid generator/voice plan; filmed city material must be shot by the operator or properly licensed. Publish a tailored cut for TikTok, Reels, Shorts, X and Telegram.": "VFX: процедурная тепловая палитра; линия из указующей точки к порталу; кварталы поднимаются из 3D-сетки; после победы горячие точки обводятся зелёным. Звук: оригинальный мотив из трёх нот C–G–E через Web Audio API. Голос: голос оператора или лицензированная озвучка. Монтаж: CapCut/Premiere. Целевой бюджет — €0–€50 без учёта труда оператора и платных подписок на генераторы/озвучку; городские съёмки должны быть сделаны оператором или иметь лицензию. Подготовить отдельные версии для TikTok, Reels, Shorts, X и Telegram.",
    "04 / Source register": "04 / Реестр источников",
    "CLICKABLE PRIMARY + INDEPENDENT SOURCES": "ПЕРВОИСТОЧНИКИ И НЕЗАВИСИМЫЕ ИСТОЧНИКИ",
    "Municipality of Athens — Cooling Havens": "Муниципалитет Афин — Cooling Havens",
    "Primary programme source: six intervention areas, water reuse, rain gardens, IoT monitoring, planned 8,000+ m² of blue-green infrastructure, target of up to 5°C local cooling and over 70% local rainwater retention during heavy rain. Targets are identified as targets.": "Первичный источник программы: шесть площадок, повторное использование воды, дождевые сады, IoT-мониторинг, планируемая голубо-зелёная инфраструктура площадью более 8 000 м², цель снижения локальной температуры до 5°C и локального удержания более 70% дождевой воды во время сильных осадков. Целевые показатели явно обозначены как цели.",
    "EU Covenant of Mayors — Athens Hits Refresh (2025 field results)": "EU Covenant of Mayors — Athens Hits Refresh (полевые результаты 2025 года)",
    "Reports measured surface readings of around 60°C on exposed paving versus 30°C under tree shade; also reports 4–6°C reductions at Agia Irini Square and other localized outcomes from shade, microforests and cooling gardens.": "Сообщает о замерах поверхности около 60°C на открытом покрытии против 30°C под тенью деревьев; также приводит снижение на 4–6°C на площади Агиа-Ирини и локальные результаты затенения, микролесов и охлаждающих садов.",
    "National Technical University of Athens — Cooling Havens": "Национальный технический университет Афин — Cooling Havens",
    "University research group project page describing the project timeline and the urban heat challenge, including the reported high share of impermeable urban surfaces.": "Страница университетской исследовательской группы описывает сроки проекта и проблему городского перегрева, включая высокую долю непроницаемых городских поверхностей.",
    "Municipality of Athens — #CoolAthens": "Муниципалитет Афин — #CoolAthens",
    "Official public heat-safety service: heatwave classification based on two decades of historical weather and mortality data; temperature and discomfort maps updated every 15 minutes; guidance and cooling-route/place information.": "Официальный публичный сервис безопасности в жару: категоризация волн жары на основе двадцати лет метеоданных и данных о смертности; карты температуры и дискомфорта обновляются каждые 15 минут; рекомендации и информация о прохладных маршрутах и местах.",
    "Municipality of Athens — population context": "Муниципалитет Афин — численность населения",
    "The city website lists 637,798 residents. This is the municipality population, not an estimate of how many people are harmed by heat.": "На сайте города указано 637 798 жителей. Это численность населения муниципалитета, а не оценка количества людей, пострадавших от жары.",
    "Location and map reference": "Место и картографический ориентир",
    "Argentinis Dimokratias Square reference pin: 37.989284, 23.743921. Coordinates are a navigational reference, not a sensor location or a claim that every reported measurement was taken at the pin centre.": "Ориентир на площади Аргентинис-Димократиас: 37.989284, 23.743921. Координаты предназначены для навигации и не являются местом установки датчика или утверждением, что все замеры проводились точно в центре метки.",
    "05 / Three revenue streams": "05 / Три потока дохода",
    "MODEL ASSUMPTIONS · NOT EXISTING SALES": "РАСЧЁТНЫЕ ДОПУЩЕНИЯ · НЕ СУЩЕСТВУЮЩИЕ ПРОДАЖИ",
    "B2C · series membership": "B2C · подписка на сериал",
    "World Pass": "World Pass",
    "B2B · commissioned impact world": "B2B · заказной мир социального эффекта",
    "City / NGO pilot": "Пилот для города / НКО",
    "Annual licence": "Годовая лицензия",
    "ZION-9 World Engine white-label licence": "White-label лицензия на движок ZION-9",
    "Monthly access to the serial archive, bonus worlds and behind-the-scenes builds. Candidate checkout: Ko-fi or Lemon Squeezy; no live checkout is connected in this release.": "Ежемесячный доступ к архиву сериала, бонусным мирам и закулисным сборкам. Возможные платформы оплаты: Ko-fi или Lemon Squeezy; действующая платёжная ссылка в этой версии не подключена.",
    "Unit example: 100 active members = €499/month gross before payment/platform fees, refunds and taxes. Public static hosting can stay within free-tier limits; creator time is excluded.": "Пример юнит-экономики: 100 активных подписчиков = €499 валовой выручки в месяц до комиссий платёжной платформы, возвратов и налогов. Статический хостинг можно оставить в бесплатных лимитах; время автора не включено.",
    "Branded interactive explainer for one local pain: public engagement, school outreach or a climate-adaptation consultation. Scope, data and rights agreed per project.": "Брендированный интерактивный материал об одной локальной проблеме: вовлечение жителей, просвещение школьников или консультации по климатической адаптации. Объём, данные и права согласуются для каждого проекта.",
    "Illustrative €5,000 contract − €1,500 direct production budget = €3,500 contribution (70%) before sales, overhead and taxes. Assumption, not a quote or recorded result.": "Пример: контракт €5 000 − €1 500 прямых затрат на производство = €3 500 маржинального вклада (70%) до продаж, накладных расходов и налогов. Это расчётное допущение, не оферта и не зафиксированный результат.",
    "White-label deployment, a configurable story template, accessibility/localisation and agreed maintenance. Only after production hardening and a written service scope.": "White-label-развёртывание, настраиваемый шаблон истории, доступность, локализация и согласованное сопровождение. Только после усиления промышленной надёжности и письменного согласования объёма услуг.",
    "Illustrative €10,000 licence − €2,000 annual support allowance = €8,000 contribution (80%) before acquisition cost and taxes. Assumption only.": "Пример: лицензия €10 000 − €2 000 годового бюджета поддержки = €8 000 маржинального вклада (80%) до затрат на привлечение клиентов и налогов. Только расчётное допущение.",
    "Commercial honesty:": "Коммерческая честность:",
    "these are priced offer designs and scenario maths. A live checkout, paid subscriber base, municipal contract, or licence is not connected or claimed. Do not present this simulation as endorsed by the Municipality of Athens or any cited project.": "это модели офферов и сценарные расчёты. Действующая оплата, платная база подписчиков, муниципальный контракт или лицензия не подключены и не заявляются. Не представляйте симуляцию как проект, одобренный муниципалитетом Афин или упомянутыми организациями.",
    "06 / Evolution audit": "06 / Аудит эволюции",
    "EDITORIAL REVIEW · NOT ANALYTICS": "РЕДАКЦИОННАЯ ОЦЕНКА · НЕ АНАЛИТИКА",
    "Axis": "Ось",
    "Previous review*": "Прошлая оценка*",
    "Current review*": "Текущая оценка*",
    "Evidence in this episode": "Доказательство в этом эпизоде",
    "Lore and mythology": "Лор и мифология",
    "City and location": "Город и локация",
    "Pain research": "Исследование проблемы",
    "Technology and sources": "Технологии и источники",
    "Video scenario": "Видео-сценарий",
    "3D world": "3D-мир",
    "Sound": "Звук",
    "Virality": "Виральность",
    "ARG continuity": "Связность ARG",
    "Monetization": "Монетизация",
    "Technical quality": "Техническое качество",
    "Autonomy": "Автономность",
    "Character becomes a social-tech operator, not just a mysterious visitor.": "Персонаж становится социально-технологическим оператором, а не просто загадочным гостем.",
    "Named Athens square, reference coordinates, map and attributed CC photograph.": "Указаны площадь в Афинах, координаты, карта и фотография с атрибуцией CC.",
    "City programme, independent EU field report and university project reference.": "Городская программа, независимый полевой отчёт ЕС и ссылка на университетский проект.",
    "Existing #CoolAthens service and measured urban cooling interventions.": "Действующий сервис #CoolAthens и измеренные результаты городского охлаждения.",
    "10 shots in 75 seconds, hook, VO, VFX and CTA.": "10 кадров за 75 секунд, хук, озвучка, VFX и CTA.",
    "Three.js scene, placeable interventions, win/loss, responsive controls and AR attempt.": "Сцена Three.js, размещаемые вмешательства, победа/поражение, адаптивное управление и попытка AR.",
    "Web Audio C–G–E motif, triggered by user action and victory.": "Мотив C–G–E через Web Audio, запускаемый действием пользователя и победой.",
    "Thermal hook, visible before/after mechanic and short CTA.": "Тепловой хук, видимый механизм «до/после» и короткий CTA.",
    "Next episode clue: “the places that stay cool after sunset”.": "Подсказка следующего эпизода: «места, которые остаются прохладными после заката».",
    "Three priced offer models with transparent assumptions.": "Три ценовые модели офферов с прозрачными допущениями.",
    "Single-file Three.js world; static publish; fallback if WebXR/CDN unavailable.": "Мир Three.js в одном HTML-файле; статическая публикация; запасной сценарий при недоступности WebXR/CDN.",
    "GitHub Pages release; research and publishing still need human review.": "Публикация через GitHub Pages; исследование и публикации всё ещё требуют проверки человеком.",
    "*Scores are editorial self-assessment estimates used for a design review. No signed scorecard for episode 029 or historical analytics baseline was stored, so these deltas are not independently measured performance gains. Average review score: 63.4 → 83.2 (+19.8 estimated).": "*Баллы — редакционная самооценка для анализа дизайна. Подписанная таблица оценок эпизода 029 и историческая база аналитики не сохранены, поэтому изменения не являются независимо измеренным улучшением показателей. Средняя редакционная оценка: 63,4 → 83,2 (+19,8, оценочно).",
    "07 / Release and next clue": "07 / Публикация и следующая подсказка",
    "EPISODE 030 → 031": "ЭПИЗОД 030 → 031",
    "Current release status": "Текущий статус выпуска",
    "The static dossier and playable browser simulation are published on GitHub Pages. WebXR is feature-detected and may be unavailable on some browsers. Three.js loads from a CDN; the page reports a fallback if it cannot load. No cross-device browser test log, live payment link, or real publication IDs are claimed here.": "Статическое досье и браузерная симуляция опубликованы через GitHub Pages. Поддержка WebXR проверяется и может отсутствовать в некоторых браузерах. Three.js загружается с CDN; если загрузка не удаётся, страница показывает резервное сообщение. Здесь не заявляются логи кросс-девайсных браузерных тестов, работающая платёжная ссылка или реальные идентификаторы публикаций.",
    "Open the playable world ↗": "Открыть играбельный мир ↗",
    "Public website repository ↗": "Репозиторий публичного сайта ↗",
    "ARG clue for ZION-031": "ARG-подсказка для ZION-031",
    "THE PLACES THAT STAY COOL AFTER SUNSET.": "МЕСТА, КОТОРЫЕ ОСТАЮТСЯ ПРОХЛАДНЫМИ ПОСЛЕ ЗАКАТА.",
    "Next episode moves from cooling materials to night-time access and safe public routes. The clue is a narrative seed, not a hidden credential or secret answer.": "Следующий эпизод перейдёт от охлаждающих материалов к ночной доступности и безопасным общественным маршрутам. Это сюжетное семя, а не закрытый ключ или секретный ответ.",
    "Next seed:": "Следующий seed:",
    "ZION-9 INFINITE · THE SHADE PROTOCOL · 11 OCT 2026": "ZION-9 INFINITE · ТЕНЕВОЙ ПРОТОКОЛ · 11 ОКТЯБРЯ 2026",
    "MAIN ARCHIVE ↗": "ГЛАВНЫЙ АРХИВ ↗",
    "PLAY WORLD ↗": "ИГРАТЬ В МИР ↗",
    "NEW EPISODE · ZION-030 · ATHENS": "НОВЫЙ ЭПИЗОД · ZION-030 · АФИНЫ",
    "THE SHADE PROTOCOL": "ТЕНЕВОЙ ПРОТОКОЛ",
    "Can you cool a city block? Use three interventions — a tree, a shade canopy and a rain garden — to cover the heat hotspots. Based on real Athens field measurements and existing municipal technology.": "Сможешь охладить городской квартал? Размести три решения — дерево, теневой навес и дождевой сад — на горячих точках. Основано на реальных замерах в Афинах и действующих муниципальных технологиях.",
    "PLAY THE 3D WORLD ↗": "ИГРАТЬ В 3D-МИР ↗",
    "FIELD DOSSIER + SOURCES ↗": "ДОСЬЕ И ИСТОЧНИКИ ↗",
    "Reported surface readings: exposed paving vs tree shade, Athens · 2025": "Замеры поверхности: открытое покрытие и тень деревьев, Афины · 2025",
    "10 ARCHIVE WORLDS + 1 NEW MISSION": "10 МИРОВ В АРХИВЕ + 1 НОВАЯ МИССИЯ",
    "THE SHADE PROTOCOL — ZION-030": "ТЕНЕВОЙ ПРОТОКОЛ — ZION-030",
    "Athens · Climate adaptation / interactive field lab": "Афины · Климатическая адаптация / интерактивная полевая лаборатория",
    "Three interventions. Three heat hotspots. Turn a sun-baked city block into a cooler public place — one deliberate placement at a time.": "Три вмешательства. Три горячие точки. Превратите раскалённый городской квартал в более прохладное общественное пространство — размещая решения одно за другим.",
    "Athens surface reference": "Температура поверхности в Афинах",
    "sun / tree shade · 2025": "солнце / тень дерева · 2025",
    "● HEAT RISK MAP · SIMULATION": "● КАРТА ТЕПЛОВОГО РИСКА · СИМУЛЯЦИЯ",
    "SELECT MODULE → TAP AN EMPTY TILE": "ВЫБЕРИТЕ МОДУЛЬ → НАЖМИТЕ НА ПУСТУЮ КЛЕТКУ",
    "Deploy a cooling intervention": "Разместите средство охлаждения",
    "Choose a module, then tap an empty tile in the city. Cover all three marked hotspots before your deployment budget runs out.": "Выберите модуль, затем нажмите на пустую клетку города. Накройте все три отмеченные горячие точки, пока не закончился запас модулей.",
    "Urban tree": "Городское дерево",
    "Deep shade": "Глубокая тень",
    "Cool canopy": "Охлаждающий навес",
    "Reflective shade": "Отражающая тень",
    "Rain garden": "Дождевой сад",
    "Water + planting": "Вода + озеленение",
    "Cooling points": "Очки охлаждения",
    "Modules left": "Модулей осталось",
    "Hotspots covered": "Горячие точки закрыты",
    "Mission brief": "Задача миссии",
    "Place cooling infrastructure close to each glowing hotspot. This is an educational simulation, not a live city model.": "Размещайте инфраструктуру охлаждения рядом с каждой светящейся горячей точкой. Это учебная симуляция, а не живая модель города.",
    "♫ PLAY C–G–E": "♫ ВКЛЮЧИТЬ C–G–E",
    "◈ CHECKING AR…": "◈ ПРОВЕРКА AR…",
    "◈ ENTER AR": "◈ ВОЙТИ В AR",
    "◈ AR NOT AVAILABLE": "◈ AR НЕДОСТУПЕН",
    "AR NOT SUPPORTED": "AR НЕ ПОДДЕРЖИВАЕТСЯ",
    "↺ RESET": "↺ СБРОСИТЬ",
    "FIELD REPORT ↗": "ПОЛЕВОЕ ДОСЬЕ ↗",
    "Browser audio starts only after a tap. AR requires a compatible phone/browser and HTTPS.": "Звук запускается только после нажатия. Для AR нужны совместимые телефон и браузер, а также HTTPS.",
    "Field evidence · not game scoring": "Полевые данные · не игровые очки",
    "A 2025 Athens field report described surface readings around 60°C on exposed paving and 30°C under tree shade at Argentinis Dimokratias Square. The 3D puzzle uses that finding as context; its points are illustrative, not scientific predictions.": "В полевом отчёте об Афинах за 2025 год указаны примерно 60°C на открытом покрытии и 30°C под тенью деревьев на площади Аргентинис-Димократиас. 3D-головоломка использует это наблюдение как контекст; игровые очки иллюстративны и не являются научным прогнозом.",
    "Technology already in use": "Уже используемая технология",
    "Athens combines shaded/green spaces with a Heat Risk Index and the": "Афины сочетают затенённые и озеленённые пространства с индексом теплового риска и сервисом",
    "full field episode, sources and business model ↗": "полный выпуск, источники и бизнес-модель ↗",
    "Public interactive prototype · no account needed": "Публичный интерактивный прототип · регистрация не нужна",
    "Episode dossier ↗": "Досье эпизода ↗",
    "Three.js could not load. Check the network connection and refresh to load the 3D city.": "Не удалось загрузить Three.js. Проверьте подключение к сети и обновите страницу, чтобы загрузить 3D-город.",
    "3D engine unavailable": "3D-движок недоступен",
    "The Three.js CDN did not load. The field report remains available below.": "Не удалось загрузить Three.js с CDN. Полевой отчёт доступен ниже.",
    "Module selected": "Модуль выбран",
    "Urban tree selected. Tap a tile beside a glowing hotspot.": "Выбрано городское дерево. Нажмите на клетку рядом со светящейся горячей точкой.",
    "Cool canopy selected. Tap a tile beside a glowing hotspot.": "Выбран охлаждающий навес. Нажмите на клетку рядом со светящейся горячей точкой.",
    "Rain garden selected. Tap a tile beside a glowing hotspot.": "Выбран дождевой сад. Нажмите на клетку рядом со светящейся горячей точкой.",
    "Tile unavailable": "Клетка недоступна",
    "Choose an empty tile. Buildings and existing interventions cannot be replaced.": "Выберите пустую клетку. Здания и уже размещённые модули нельзя заменить.",
    "Mission complete": "Миссия выполнена",
    "All three heat hotspots are covered. You built a cooler shared space. Play the C–G–E signature or open the source dossier.": "Все три горячие точки закрыты. Вы создали более прохладное общественное пространство. Послушайте мотив C–G–E или откройте досье с источниками.",
    "Thermal pressure remains": "Тепловая нагрузка сохраняется",
    "Three modules used, but one or more hotspots remain exposed. Reset and try a tighter placement.": "Все три модуля использованы, но одна или несколько горячих точек остаются открытыми. Сбросьте миссию и разместите решения точнее.",
    "Intervention placed": "Решение размещено",
    "Use the 3D simulation in a compatible browser over HTTPS, then try AR again.": "Используйте 3D-симуляцию в совместимом браузере через HTTPS, затем повторите попытку AR.",
    "Audio unavailable": "Звук недоступен",
    "This browser does not support Web Audio.": "Этот браузер не поддерживает Web Audio.",
    "Allow browser audio and try again.": "Разрешите звук в браузере и повторите попытку."
  });
  Object.assign(translations, {
    "ZION-030: The Shade Protocol — a playable 3D urban-cooling simulation inspired by Athens climate solutions.": "ZION-030: «Теневой протокол» — интерактивная 3D-симуляция городского охлаждения, вдохновлённая климатическими решениями Афин.",
    "Athens has already measured a way out: exposed paving reached 60°C while ground under tree shade measured 30°C in a 2025 field report. ZION-9 turns that evidence into a playable city-planning mission.": "В Афинах уже измерили один из способов решения: в полевом отчёте за 2025 год открытое покрытие нагревалось до 60°C, а поверхность в тени деревьев — до 30°C. ZION-9 превращает эти данные в интерактивную миссию по планированию города.",
    "ELSTAT's 2021 census records 643,452 residents for the Municipality of Athens; CNI Greece repeats the same census figure. This is population context only — not an estimate of heat casualties and not a claim that all residents are equally exposed.": "По переписи ELSTAT 2021 года в муниципалитете Афин проживали 643 452 человека; CNI Greece приводит ту же цифру переписи. Это только контекст по населению, а не оценка пострадавших от жары и не утверждение, что все жители подвержены риску одинаково.",
    "ELSTAT · 2021 Census ↗": "ELSTAT · перепись 2021 года ↗",
    "CNI Greece · population cross-check ↗": "CNI Greece · сверка численности населения ↗",
    "Official municipal field update ↗": "Официальное сообщение муниципалитета ↗",
    "The Hellenic Statistical Authority": "Греческое статистическое управление",
    "Municipality population context only": "Только контекст численности муниципалитета",
    "03 / 75-second video episode": "03 / Видеовыпуск на 75 секунд",
    "04 / Source register": "04 / Реестр источников",
    "CLICKABLE PRIMARY + INDEPENDENT SOURCES": "ПЕРВОИСТОЧНИКИ И НЕЗАВИСИМЫЕ ИСТОЧНИКИ",
    "Municipality of Athens — local cooling measures": "Муниципалитет Афин — локальные меры охлаждения",
    "Separate municipal field update states that shaded/natural-material surfaces in several intervention spots were around 30°C, while conventional surfaces exceeded 50°C. This corroborates the scale of surface-temperature differences, but is not claimed as a second measurement of the exact 60°C/30°C pair at Argentinis Dimokratias Square.": "Отдельное полевое сообщение муниципалитета указывает, что в затенённых зонах и на поверхностях из природных материалов в нескольких местах было около 30°C, тогда как температура обычных покрытий превышала 50°C. Это подтверждает масштаб различий температур поверхности, но не выдаётся за повторный замер именно пары 60°C/30°C на площади Аргентинис-Димократиас.",
    "Hellenic Statistical Authority (ELSTAT) — 2021 census": "Греческое статистическое управление (ELSTAT) — перепись 2021 года",
    "Official population census: 643,452 permanent residents in Athens municipality in 2021.": "Официальная перепись населения: 643 452 постоянных жителя муниципалитета Афин в 2021 году.",
    "CNI Greece — Athens municipality population cross-check": "CNI Greece — независимая сверка численности населения Афин",
    "Secondary reference repeats the ELSTAT census figure. This is context only, not an estimate of how many people are harmed by urban heat.": "Вторичный источник повторяет цифру переписи ELSTAT. Это только контекст, а не оценка числа людей, которым вредит городской перегрев.",
    "08 / Social distribution pack": "08 / Пакет публикаций для соцсетей",
    "READY-TO-POST COPY · NO AUTO-PUBLISH": "ТЕКСТЫ ГОТОВЫ · АВТОПУБЛИКАЦИИ НЕТ",
    "Hook + caption": "Хук + подпись",
    "60°C on exposed pavement. 30°C under tree shade. Could you redesign one city block? Play ZION-030: three heat hotspots, three interventions, one mission. Based on Athens’ reported 2025 surface measurements. Game score is illustrative — the field evidence is real.": "60°C на открытом покрытии. 30°C в тени дерева. Сможешь перепроектировать один городской квартал? Играй в ZION-030: три горячие точки, три решения, одна миссия. Основано на опубликованных замерах поверхности в Афинах за 2025 год. Игровые очки иллюстративны — полевые данные реальны.",
    "CTA:": "Призыв к действию:",
    "Play the mission, then send it to someone who plans public spaces.": "Пройди миссию и отправь её тому, кто планирует общественные пространства.",
    "#ZION9 #UrbanHeat #ClimateAdaptation #ThreeJS #InteractiveStory": "#ZION9 #ГородскаяЖара #КлиматическаяАдаптация #ThreeJS #ИнтерактивнаяИстория",
    "Short post": "Короткий пост",
    "Athens reported a surface-temperature gap: ~60°C on exposed paving vs ~30°C under tree shade. We turned the evidence into a playable 3D mission. Place trees, canopies and rain gardens. Can you cover all three hotspots?": "В Афинах сообщили о разнице температур поверхности: около 60°C на открытом покрытии и около 30°C в тени дерева. Мы превратили данные в 3D-миссию. Размещай деревья, навесы и дождевые сады. Сможешь закрыть все три горячие точки?",
    "Play ZION-030 ↗": "Играть в ZION-030 ↗",
    "Carousel caption": "Подпись для карусели",
    "Slide 1: The heat is measurable. Slide 2: Shade changes the surface. Slide 3: Cooling tools already exist. Slide 4: Now it’s your turn to redesign the block. ZION-030 is live as a browser game; sources and limits are documented in the field dossier.": "Слайд 1: Жару можно измерить. Слайд 2: Тень меняет температуру поверхности. Слайд 3: Решения для охлаждения уже существуют. Слайд 4: Теперь твоя очередь перепроектировать квартал. ZION-030 уже доступен как браузерная игра; источники и ограничения описаны в полевом досье.",
    "#Athens #CoolCities #PublicSpace #ZION9": "#Афины #ПрохладныеГорода #ОбщественныеПространства #ZION9",
    "Long-form post": "Развёрнутый пост",
    "NEW EPISODE — THE SHADE PROTOCOL. Athens’ 2025 thermal-camera reporting showed exposed pavement around 60°C and ground under tree shade around 30°C. The city already uses heat-risk information and cooling interventions. We built a 3D mission where you place three interventions beside heat hotspots. This is a simulation, not an official city planning tool. Primary sources, programme targets and business assumptions are linked in the dossier.": "НОВЫЙ ЭПИЗОД — «ТЕНЕВОЙ ПРОТОКОЛ». Согласно опубликованным результатам тепловизионных замеров в Афинах за 2025 год, открытое покрытие нагревалось примерно до 60°C, а земля в тени деревьев — примерно до 30°C. Город уже использует информацию о тепловых рисках и решения для охлаждения. Мы создали 3D-миссию, где нужно разместить три решения рядом с горячими точками. Это симуляция, а не официальный городской инструмент планирования. Первичные источники, цели программы и расчёты бизнес-модели приведены в досье.",
    "Play the world ↗": "Играть в мир ↗",
    "Read sources ↗": "Читать источники ↗",
    "Three hook variants for A/B testing": "Три варианта хука для A/B-тестирования",
    "A — Number: This pavement reached 60°C. Look what shade did.": "A — Цифра: Это покрытие нагрелось до 60°C. Посмотри, что изменила тень.",
    "B — Challenge: Three hotspots. Three interventions. Can you cool the block?": "B — Вызов: Три горячие точки. Три решения. Сможешь охладить квартал?",
    "C — Mystery: ZION-9 points at empty pavement. A city appears — and you have 3 moves to fix it.": "C — Тайна: ZION-9 указывает на пустой асфальт. Возникает город — и у тебя три хода, чтобы его изменить.",
    "Target is a test plan; no reach or conversion result is claimed until platform analytics are connected.": "Это план тестирования; охваты и конверсии не заявляются, пока не подключена аналитика платформ.",
    "Ready-to-post copy · no auto-publish": "Тексты готовы · автопубликации нет",
    "model assumptions · not existing sales": "расчётные допущения · не существующие продажи"
  });
  Object.assign(translations, {
    "information service. Explore the": "информационный сервис. Откройте",
    "Procedurally generated 3D city block heat map. Select a cooling module and tap the ground to place it.": "Трёхмерная карта квартала с зонами нагрева. Выберите модуль охлаждения и нажмите на землю, чтобы разместить его.",
    "Three interventions. Three heat hotspots. Turn a sun-baked city block into a cooler public place — one deliberate placement at a time.": "Три решения. Три горячие точки. Превратите раскалённый городской квартал в более прохладное общественное пространство — размещайте решения по одному."
  });
  Object.assign(translations, {
    "ZION-9 / INFINITE WORLDS": "ZION-9 / БЕСКОНЕЧНЫЕ МИРЫ",
    "World archive / 10 worlds + latest episode": "Архив миров / 10 миров + новый эпизод",
    "Ten signals. Ten doors. One new field mission: use real evidence to redesign an overheated city block.": "Десять сигналов. Десять дверей. Новая полевая миссия: опираясь на реальные данные, измени перегретый городской квартал.",
    "Latest episode": "Новый эпизод",
    "NEW EPISODE · ZION-030 · ATHENS": "НОВЫЙ ЭПИЗОД · ZION-030 · АФИНЫ",
    "THE SHADE PROTOCOL": "ТЕНЕВОЙ ПРОТОКОЛ",
    "Can you cool a city block? Use three interventions — a tree, a shade canopy and a rain garden — to cover the heat hotspots. Based on real Athens field measurements and existing municipal technology.": "Сможешь охладить городской квартал? Размести три решения — дерево, теневой навес и дождевой сад — в самых жарких точках. Миссия основана на реальных замерах в Афинах и существующих городских технологиях.",
    "PLAY THE 3D WORLD ↗": "ИГРАТЬ В 3D-МИР ↗",
    "FIELD DOSSIER + SOURCES ↗": "ДОСЬЕ И ИСТОЧНИКИ ↗",
    "Reported surface readings: exposed paving vs tree shade, Athens · 2025": "Замеры поверхности: открытое покрытие и тень деревьев, Афины · 2025",
    "10 ARCHIVE WORLDS + 1 NEW MISSION": "10 МИРОВ В АРХИВЕ + 1 НОВАЯ МИССИЯ",
    "ZION-9 INFINITE · STATIC BUILD": "ZION-9 БЕСКОНЕЧНЫЕ МИРЫ · СТАТИЧЕСКАЯ ВЕРСИЯ",
    "No trackers · no external scripts ·": "Без трекеров · без внешних скриптов ·"
  });
  Object.assign(translations, {
  "← All OSGARD games": "← Все игры OSGARD",
  "World and controls": "О мире и управлении",
  "Before starting": "Перед началом",
  "Save: current session only": "Сохранение: только текущая сессия",
  "Single player · no online mode": "Одиночный режим · онлайн отсутствует",
  "Russian / English": "Русский / English",
  "Refreshing the page restarts the experience. Catalog favorites save the world link, not in-game progress.": "После обновления страницы прохождение начнётся заново. Избранное каталога сохраняет ссылку на мир, а не игровой прогресс.",
  "Go to the story ↓": "Перейти к истории ↓",
  "Go to the game ↓": "Перейти к игре ↓",
  "Signal nodes": "Узлы сигналов",
  "NORTH OF SLEEP — ZION-026": "СЕВЕР СНА — ZION-026",
  "BOARD CONTROLS": "УПРАВЛЕНИЕ ПОЛЕМ",
  "Arrow keys choose a tile. Enter places the module; 1–3 changes module; R resets. Hotspots: X −4 / Z −3, X 2 / Z 2, X 4 / Z −2.": "Стрелки выбирают клетку. Enter размещает модуль; 1–3 меняет модуль; R начинает заново. Горячие точки: X −4 / Z −3, X 2 / Z 2, X 4 / Z −2.",
  "Place here": "Разместить здесь",
  "Choose tile to the left": "Выбрать клетку слева",
  "Choose tile to the right": "Выбрать клетку справа",
  "Choose tile above": "Выбрать клетку выше",
  "Choose tile below": "Выбрать клетку ниже",
  "Lightweight board": "Облегчённое поле",
  "The same three-hotspot puzzle is ready in a lightweight view. Select a module, then choose a tile.": "Та же задача с тремя горячими точками доступна в облегчённом виде. Выберите модуль, затем клетку.",
  "AR needs the 3D view": "Для AR требуется 3D-режим",
  "Choose a tile with arrow keys, then press Enter to place the selected module.": "Выберите клетку стрелками и нажмите Enter, чтобы разместить выбранный модуль.",
  "Tap signals from the lowest resonance to the highest. A mistake resets the sequence; there is no timer.": "Нажимайте сигналы по возрастанию резонанса. Ошибка сбрасывает цепочку; таймера нет.",
  "Find the order of three signals, from the lowest resonance to the highest, to reveal the lost page.": "Найдите порядок трёх сигналов от меньшего резонанса к большему и откройте потерянную страницу.",
  "Tap a button or use Tab and Enter. Reset signal starts again.": "Нажатие или Tab и Enter. Кнопка «Сбросить сигнал» начинает заново.",
  "Open Bloom, Fruit and Root. This is a short story with expandable fragments.": "Раскройте цветение, плод и корень. Это короткий рассказ с раскрывающимися фрагментами.",
  "Open the three fragments of the machine rhythm, then read the ending.": "Раскройте три фрагмента ритма машины, затем прочитайте завершение истории.",
  "Explore hiss, hum and silence through text. This story does not play an audio recording.": "Исследуйте шипение, гул и тишину через текст. Аудиозапись в этой истории не используется.",
  "Read the light, chalk and window fragments. A separate heading opens the ending.": "Прочитайте фрагменты о свете, меле и окне. Финал открывается отдельным заголовком.",
  "Polar Compass: open the wind, star and footsteps observations, then read the ending.": "Полярный компас: раскройте наблюдения о ветре, звезде и следах, затем прочитайте финал.",
  "Explore the gear, shadow and bell through three text fragments.": "Исследуйте шестерню, тень и колокол через три текстовых фрагмента.",
  "Compare three text forecasts — rain, wind and sun — then open the ending.": "Сравните три текстовых прогноза — дождь, ветер и солнце — и откройте завершение.",
  "Read three fragments about notes and a pause. This is a text story without an audio recording.": "Прочитайте три фрагмента о нотах и паузе. Это текстовая история, без аудиозаписи.",
  "Tap a fragment heading, or select it using Tab and press Enter.": "Нажмите заголовок фрагмента или выберите его клавишей Tab и нажмите Enter.",
  "Choose a tree, canopy or rain garden and cover three hotspots. Your budget is three placements.": "Выберите дерево, навес или дождевой сад и закройте три горячие точки. Бюджет — три размещения.",
  "Mouse or touch selects a tile. Arrow keys select a tile, Enter places a module, 1–3 selects a module, R restarts.": "Мышь или касание — клетка. Стрелки — выбор клетки, Enter — размещение, 1–3 — модуль, R — заново.",
  "Local archive · 11 experiences": "Локальный архив · 11 миров",
  "ZION-020 / Puzzle": "ZION-020 / Головоломка",
  "BEFORE STARTING · PUZZLE": "ПЕРЕД НАЧАЛОМ · ГОЛОВОЛОМКА",
  "ZION-021 / Puzzle": "ZION-021 / Головоломка",
  "ZION-022 / Interactive story": "ZION-022 / Интерактивная история",
  "BEFORE STARTING · INTERACTIVE STORY": "ПЕРЕД НАЧАЛОМ · ИНТЕРАКТИВНАЯ ИСТОРИЯ",
  "ZION-023 / Interactive story": "ZION-023 / Интерактивная история",
  "ZION-024 / Interactive story": "ZION-024 / Интерактивная история",
  "ZION-025 / Interactive story": "ZION-025 / Интерактивная история",
  "ZION-026 / Interactive story": "ZION-026 / Интерактивная история",
  "ZION-027 / Interactive story": "ZION-027 / Интерактивная история",
  "ZION-028 / Interactive story": "ZION-028 / Интерактивная история",
  "ZION-029 / Interactive story": "ZION-029 / Интерактивная история",
  "ZION-030 / 3D puzzle": "ZION-030 / 3D-головоломка",
  "BEFORE STARTING · 3D PUZZLE": "ПЕРЕД НАЧАЛОМ · 3D-ГОЛОВОЛОМКА"
});
  const english = Object.fromEntries(Object.entries(translations).map(([en, ru]) => [ru, en]));
  function getLanguage() {
    const requested = new URLSearchParams(location.search).get("lang");
    if (requested === "ru" || requested === "en") return requested;
    try {
      const saved = localStorage.getItem(STORAGE_KEY);
      if (saved === "en" || saved === "ru") return saved;
    } catch (_) {}
    return "ru";
  }
  let language = getLanguage();
  let translationVersion = 0;
  function toRu(value) {
    if (translations[value] !== undefined) return translations[value];
    let match = value.match(/^Resonance (\d+)$/);
    if (match) return "Резонанс " + match[1];
    match = value.match(/^Signal held\. (\d+) remain\.$/);
    if (match) return "Сигнал удержан. Осталось: " + match[1] + ".";
    match = value.match(/^([A-Z]+), resonance (\d+)$/);
    if (match) return toRu(match[1]) + ", резонанс " + match[2];
    match = value.match(/^NODES (\d+) \/ 3$/);
    if (match) return "УЗЛЫ " + match[1] + " / 3";
    match = value.match(/^(\d+) of 3 hotspots covered\. (\d+) modules remain\. Target glowing rings\.$/);
    if (match) return match[1] + " из 3 горячих точек закрыто. Осталось модулей: " + match[2] + ". Цельтесь в светящиеся кольца.";
    match = value.match(/^Signal stable\. (\d+) of 3 hotspots covered\.$/);
    if (match) return "Сигнал стабилен. Закрыто горячих точек: " + match[1] + " из 3.";
    match = value.match(/^Tile X (-?\d+) \/ Z (-?\d+) — (empty|occupied|hotspot)$/);
    if (match) return "Клетка X " + match[1] + " / Z " + match[2] + " — " + ({empty:"свободна",occupied:"занята",hotspot:"горячая точка"}[match[3]]);
    if (value === "EMBER") return "УГОЛЁК";
    if (value === "TIDE") return "ПРИЛИВ";
    if (value === "LENS") return "ЛИНЗА";
    if (value === "INDEX") return "УКАЗАТЕЛЬ";
    if (value === "INK") return "ЧЕРНИЛА";
    if (value === "MARGIN") return "ПОЛЕ";
    return value;
  }
  function toEn(value) {
    if (english[value] !== undefined) return english[value];
    let match = value.match(/^Резонанс (\d+)$/);
    if (match) return "Resonance " + match[1];
    match = value.match(/^Сигнал удержан\. Осталось: (\d+)\.$/);
    if (match) return "Signal held. " + match[1] + " remain.";
    match = value.match(/^(.+), резонанс (\d+)$/);
    if (match) return ((english[match[1]] || match[1])) + ", resonance " + match[2];
    match = value.match(/^УЗЛЫ (\d+) \/ 3$/);
    if (match) return "NODES " + match[1] + " / 3";
    match = value.match(/^(\d+) из 3 горячих точек закрыто\. Осталось модулей: (\d+)\. Цельтесь в светящиеся кольца\.$/);
    if (match) return match[1] + " of 3 hotspots covered. " + match[2] + " modules remain. Target glowing rings.";
    match = value.match(/^Сигнал стабилен\. Закрыто горячих точек: (\d+) из 3\.$/);
    if (match) return "Signal stable. " + match[1] + " of 3 hotspots covered.";
    match = value.match(/^Клетка X (-?\d+) \/ Z (-?\d+) — (свободна|занята|горячая точка)$/);
    if (match) return "Tile X " + match[1] + " / Z " + match[2] + " — " + ({"свободна":"empty","занята":"occupied","горячая точка":"hotspot"}[match[3]]);
    const reverseNames = {"УГОЛЁК":"EMBER","ПРИЛИВ":"TIDE","ЛИНЗА":"LENS","УКАЗАТЕЛЬ":"INDEX","ЧЕРНИЛА":"INK","ПОЛЕ":"MARGIN"};
    return reverseNames[value] || value;
  }
  function translateValue(value) {
    const trimmed = value.trim();
    if (!trimmed) return value;
    const translated = language === "ru" ? toRu(trimmed) : toEn(trimmed);
    if (translated === trimmed) return value;
    return value.replace(trimmed, translated);
  }
  function translateTree(root) {
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
    const nodes = [];
    while (walker.nextNode()) { const node = walker.currentNode; if (!node.parentElement?.closest("script,style,noscript,code,pre,[data-z9-no-translate]")) nodes.push(node); }
    nodes.forEach(node => { const oldValue = node.nodeValue; const newValue = translateValue(oldValue); if (newValue !== oldValue) node.nodeValue = newValue; });
    const elements = [root, ...root.querySelectorAll("*")];
    elements.forEach(el => {
      ["aria-label", "title", "alt"].forEach(attr => {
        if (el.hasAttribute && el.hasAttribute(attr)) {
          const oldValue = el.getAttribute(attr);
          const newValue = translateValue(oldValue);
          if (newValue !== oldValue) el.setAttribute(attr, newValue);
        }
      });
    });
  }
  function translateTreeAsync(root) {
    const version = ++translationVersion;
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
    const nodes = [];
    while (walker.nextNode()) { const node = walker.currentNode; if (!node.parentElement?.closest("script,style,noscript,code,pre,[data-z9-no-translate]")) nodes.push(node); }
    const elements = [root, ...root.querySelectorAll("*")];
    let textIndex = 0;
    let elementIndex = 0;
    function frame() {
      if (version !== translationVersion) return;
      // Keep language switching responsive while the 3D scene is rendering.
      const textEnd = Math.min(textIndex + 100, nodes.length);
      while (textIndex < textEnd) {
        const node = nodes[textIndex++];
        const oldValue = node.nodeValue;
        const newValue = translateValue(oldValue);
        if (newValue !== oldValue) node.nodeValue = newValue;
      }
      const elementEnd = Math.min(elementIndex + 200, elements.length);
      while (elementIndex < elementEnd) {
        const el = elements[elementIndex++];
        ["aria-label", "title", "alt"].forEach(attr => {
          if (el.hasAttribute && el.hasAttribute(attr)) {
            const oldValue = el.getAttribute(attr);
            const newValue = translateValue(oldValue);
            if (newValue !== oldValue) el.setAttribute(attr, newValue);
          }
        });
      }
      if (textIndex < nodes.length || elementIndex < elements.length) {
        requestAnimationFrame(frame);
      }
    }
    requestAnimationFrame(frame);
  }
  function addStyles() {
    const style = document.createElement("style");
    style.textContent = ".z9-language-bar{display:flex;justify-content:flex-end;align-items:center;gap:4px;margin:0 0 12px;font:11px/1.2 system-ui,sans-serif;letter-spacing:.08em}.z9-language-label{color:#8290a6;margin-right:6px;font-size:10px}.z9-language-btn{border:1px solid rgba(255,255,255,.17);border-radius:99px;background:rgba(255,255,255,.025);color:#c2cee0;padding:7px 11px;cursor:pointer;font:600 10px/1 system-ui,sans-serif;letter-spacing:.1em}.z9-language-btn:hover,.z9-language-btn:focus-visible{border-color:#91e7f5;outline:none}.z9-language-btn[aria-pressed=true]{color:#071018;background:#91e7f5;border-color:#91e7f5}";
    document.head.appendChild(style);
  }
  function addSwitcher() {
    const main = document.querySelector("main") || document.body;
    const bar = document.createElement("nav");
    bar.className = "z9-language-bar";
    bar.setAttribute("aria-label", "Language / Язык");
    const label = document.createElement("span");
    label.className = "z9-language-label";
    label.textContent = language === "ru" ? "ЯЗЫК" : "LANGUAGE";
    const en = document.createElement("button");
    en.type = "button"; en.className = "z9-language-btn"; en.textContent = "EN"; en.dataset.language = "en";
    const ru = document.createElement("button");
    ru.type = "button"; ru.className = "z9-language-btn"; ru.textContent = "RU"; ru.dataset.language = "ru";
    [en, ru].forEach(button => button.addEventListener("click", () => setLanguage(button.dataset.language)));
    bar.append(label, en, ru);
    main.insertBefore(bar, main.firstChild);
    updateSwitcher();
  }
  function updateSwitcher() {
    const label = document.querySelector(".z9-language-label");
    if (label) label.textContent = language === "ru" ? "ЯЗЫК" : "LANGUAGE";
    document.querySelectorAll(".z9-language-btn").forEach(button => button.setAttribute("aria-pressed", String(button.dataset.language === language)));
  }
  function applySplitDossierHeading() {
    const heading = document.querySelector(".hero h1");
    if (!heading || !heading.querySelector("em")) return;
    const emphasis = heading.querySelector("em");
    const firstText = Array.from(heading.childNodes).find(node => node.nodeType === Node.TEXT_NODE && node.nodeValue.trim());
    if (!firstText) return;
    // Keep this intentionally split design heading stable across DOM-based translation.
    firstText.nodeValue = language === "ru" ? "ТЕНЕВОЙ" : "THE SHADE";
    emphasis.textContent = language === "ru" ? "ПРОТОКОЛ" : "PROTOCOL";
  }
  function setLanguage(next) {
    language = next === "ru" ? "ru" : "en";
    try { localStorage.setItem(STORAGE_KEY, language); } catch (_) {}
    document.documentElement.lang = language;
    // Schedule text translation in small batches so language changes never freeze a live 3D scene.
    translateTreeAsync(document.body);
    applySplitDossierHeading();
    if (document.title) document.title = translateValue(document.title);
    document.querySelectorAll('meta[name="description"]').forEach(meta => meta.content = translateValue(meta.content));
    updateSwitcher();
  }
  addStyles();
  addSwitcher();
  setLanguage(language);
  const observer = new MutationObserver(records => {
    if (!records.length) return;
    records.forEach(record => {
      record.addedNodes && record.addedNodes.forEach(node => {
        if (node.nodeType === Node.TEXT_NODE) { const oldValue = node.nodeValue; const newValue = translateValue(oldValue); if (newValue !== oldValue) node.nodeValue = newValue; }
        else if (node.nodeType === Node.ELEMENT_NODE) translateTree(node);
      });
    });
  });
  // Observe newly inserted UI nodes only. Watching characterData also observes
  // the translations performed above and needlessly reprocesses the whole update.
  observer.observe(document.body, {subtree:true,childList:true});
})();
