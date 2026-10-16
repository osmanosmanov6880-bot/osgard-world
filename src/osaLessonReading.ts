import type { OSALessonLocale } from './osaLessonGuides'
import { OSA_LESSON_SLUGS } from './osaLessonRegistry'

export type OSALessonReadingBlock = {
  heading: string
  body: string
  checkpoints: string[]
}

export type OSALessonReading = {
  sections: [OSALessonReadingBlock, OSALessonReadingBlock, OSALessonReadingBlock]
  keyTakeaways: [string, string, string]
}

type LessonSlug = (typeof OSA_LESSON_SLUGS)[number]

export const osaLessonReadings: Record<OSALessonLocale, Record<LessonSlug, OSALessonReading>> = {
  ru: {
    'intelligence-and-imitation': {
      sections: [
        {
          heading: 'Полезный ответ — ещё не доказательство',
          body: 'Система ИИ может дать быстрый черновик, объяснить термин или предложить варианты. Это полезные действия, но сами по себе они не подтверждают истинность каждого утверждения. Отделяйте качество формы от качества доказательств: вежливый и связный текст всё ещё может содержать ошибку.',
          checkpoints: [
            'Определите, что именно требуется: идея, черновик, расчёт, факт или решение.',
            'Для каждого важного результата задайте критерий проверки до оценки ответа.',
          ],
        },
        {
          heading: 'Сначала задача, затем инструмент',
          body: 'Начинайте с желаемого результата и ограничений. Небольшая задача с понятным критерием чаще подходит для первого эксперимента, чем расплывчатое поручение «сделать всё». Разбейте сложную работу на части и оставьте человеку проверку тех шагов, где ошибка может изменить итог.',
          checkpoints: [
            'Опишите результат, аудиторию, ограничения и формат.',
            'Разделите черновую работу, проверку фактов и окончательное решение.',
          ],
        },
        {
          heading: 'Измеряйте результат, а не впечатление',
          body: 'Чтобы понять, помогает ли инструмент, сравните его результат с привычным способом работы по одинаковым критериям. Учитывайте время на проверку, исправления, конфиденциальность и стоимость ошибок. Один удачный пример — начало проверки, а не универсальное доказательство эффективности.',
          checkpoints: [
            'Сохраните базовый вариант без ИИ для честного сравнения.',
            'Запишите ошибки и ограничения наряду с преимуществами.',
          ],
        },
      ],
      keyTakeaways: [
        'Связный текст не гарантирует правильность.',
        'Критерии качества стоит определить до генерации.',
        'Финальную оценку нужно основывать на проверяемом результате.',
      ],
    },
    'how-language-models-work': {
      sections: [
        {
          heading: 'Как модель строит продолжение',
          body: 'Языковая модель обучается на последовательностях данных и получает контекст текущего запроса. В упрощённом виде она оценивает возможные продолжения и генерирует текст по выученным закономерностям. Это не то же самое, что открыть проверенный справочник или выполнить независимую проверку факта.',
          checkpoints: [
            'Инструкция и контекст влияют на то, какой ответ будет сгенерирован.',
            'Правдоподобие продолжения не является проверкой истинности.',
          ],
        },
        {
          heading: 'Контекст, инструменты и ограничения',
          body: 'Некоторые приложения дополняют модель поиском, вычислениями, файлами или другими инструментами. Тогда результат зависит не только от самой модели, но и от качества источников, прав доступа и того, правильно ли использован инструмент. Наличие инструмента улучшает рабочий процесс лишь при корректной настройке и проверке.',
          checkpoints: [
            'Уточните, действительно ли приложение использовало поиск или другие инструменты.',
            'Проверьте, что источник или вычисление подтверждает нужный тезис.',
          ],
        },
        {
          heading: 'Почему появляются убедительные ошибки',
          body: 'Модель может обобщить неполные примеры, неверно продолжить цепочку рассуждения или сгенерировать несуществующую ссылку. Уверенность формулировки не измеряет достоверность. Уровень контроля следует выбирать по задаче: генерация идей и критичное решение требуют разных процедур проверки.',
          checkpoints: [
            'Проверяйте даты, числа, имена, цитаты и ссылки особенно внимательно.',
            'Если система не показывает доказательства, обозначайте ответ как непроверенный.',
          ],
        },
      ],
      keyTakeaways: [
        'Генерация текста не равна поиску проверенного факта.',
        'Контекст и дополнительные инструменты меняют рабочий процесс.',
        'Ошибки нужно проверять по внешним доказательствам.',
      ],
    },
    'power-of-knowledge': {
      sections: [
        {
          heading: 'Доступ к знаниям зависит от инфраструктуры',
          body: 'Возможности AI-сервиса определяются не только моделью. Важны вычислительные ресурсы, данные, интерфейс, цена, язык, подключение к источникам и правила доступа. Поэтому доступность знаний и возможность влиять на их распространение могут распределяться между людьми и организациями неравномерно.',
          checkpoints: [
            'Назовите, кто может получить доступ к системе и на каких условиях.',
            'Проверьте, какие ограничения задают цена, инфраструктура и язык.',
          ],
        },
        {
          heading: 'Открытость и безопасность — отдельные вопросы',
          body: 'Открытый доступ может расширить участие и независимую проверку, но не снимает вопросы о приватности, лицензиях и возможном вреде. Закрытый доступ может помочь контролировать риски, но иногда создаёт непрозрачность и барьеры. Оценивайте конкретные механизмы управления, а не только ярлык «открыто» или «безопасно».',
          checkpoints: [
            'Спросите, кто определяет правила и как оспорить ошибочное решение.',
            'Различайте открытость кода, открытость данных и доступность сервиса.',
          ],
        },
        {
          heading: 'Подотчётность делает решения проверяемыми',
          body: 'Для важных применений важно знать, кто отвечает за результат, как обнаруживаются ошибки и как можно запросить пересмотр. Документация, независимая оценка, понятные ограничения и каналы обратной связи превращают абстрактное обещание ответственности в проверяемую практику.',
          checkpoints: [
            'Определите ответственного за проверку и исправление.',
            'Зафиксируйте процесс обратной связи и пересмотра решения.',
          ],
        },
      ],
      keyTakeaways: [
        'Реальный доступ формируется инфраструктурой, правилами и стоимостью.',
        'Открытость не отменяет приватность и оценку риска.',
        'Ответственность должна иметь понятный процесс проверки и исправления.',
      ],
    },
    'signal-and-noise': {
      sections: [
        {
          heading: 'Количество публикаций не равно числу доказательств',
          body: 'Несколько текстов могут ссылаться на одно исходное сообщение, пересказывать друг друга или использовать один набор данных. Внешне информации становится больше, но основание утверждения остаётся прежним. Проверка происхождения помогает отличить независимое подтверждение от повторения.',
          checkpoints: [
            'Проследите ссылки до самого раннего доступного первоисточника.',
            'Проверьте, не цитируют ли разные публикации один документ.',
          ],
        },
        {
          heading: 'Оцените качество свидетельства',
          body: 'После нахождения источника проверьте, кто его создал, когда он опубликован, каким методом получены данные и какие ограничения названы. Источник может быть первичным, но неполным или не подходить к конкретному вопросу. Утверждение должно соответствовать доказательству по смыслу, времени и масштабу.',
          checkpoints: [
            'Сверяйте дату, методику, выборку и границы применимости.',
            'Проверяйте, поддерживает ли документ именно сформулированный тезис.',
          ],
        },
        {
          heading: 'Неизвестность — допустимый вывод',
          body: 'Когда доказательств недостаточно или источники противоречат друг другу, не нужно искусственно выбирать уверенную версию. Опишите, что известно, что оспаривается и какой факт позволил бы прояснить вопрос. Такой подход делает исследование воспроизводимым и показывает, где требуется дополнительная работа.',
          checkpoints: [
            'Разделяйте подтверждённые факты, интерпретации и неизвестное.',
            'Запишите, какие новые данные могли бы изменить вывод.',
          ],
        },
      ],
      keyTakeaways: [
        'Повторение одного источника не создаёт независимого подтверждения.',
        'Первичный документ тоже нужно читать с учётом его метода и ограничений.',
        'Честный статус «неизвестно» лучше необоснованной уверенности.',
      ],
    },
    'verify-an-ai-answer': {
      sections: [
        {
          heading: 'Разбейте ответ на проверяемые тезисы',
          body: 'Общий ответ может смешивать факты, предположения, советы и выводы. Разбейте его на утверждения, которые можно проверить по отдельности. Особенно выделяйте числа, даты, имена, цитаты и причинно-следственные выводы: одна ошибка в таком элементе может изменить смысл всего результата.',
          checkpoints: [
            'Сформулируйте каждый существенный тезис одним предложением.',
            'Отметьте, какой тип доказательства нужен для каждого тезиса.',
          ],
        },
        {
          heading: 'Проверьте связь между источником и тезисом',
          body: 'Откройте исходную публикацию и найдите, где именно она подтверждает ответ. Убедитесь, что совпадают период, единицы измерения, регион, группа и определение показателя. Ссылка может открываться и относиться к теме, но не поддерживать утверждение, рядом с которым она указана.',
          checkpoints: [
            'Читайте первичный документ, а не только сниппет поисковой выдачи.',
            'При расчётах проверьте формулу, вводные данные и единицы независимо.',
          ],
        },
        {
          heading: 'Запишите результат проверки',
          body: 'Для каждого тезиса выберите прозрачный статус: подтверждён, подтверждён частично, противоречит источнику или пока неизвестен. Сохраните ссылку и короткое объяснение. Не заменяйте отсутствие доказательств интуицией и не считайте ответ другой модели независимым подтверждением.',
          checkpoints: [
            'Указывайте, что именно подтверждает источник и что остаётся неподтверждённым.',
            'Исправляйте ответ так, чтобы неопределённость была видна читателю.',
          ],
        },
      ],
      keyTakeaways: [
        'Проверяйте отдельные утверждения, а не общее впечатление от ответа.',
        'Открытая ссылка не гарантирует, что она подтверждает заявленный тезис.',
        'Статус проверки должен быть понятен и воспроизводим.',
      ],
    },
    'privacy-before-prompting': {
      sections: [
        {
          heading: 'Сначала определите, что действительно необходимо',
          body: 'Для анализа текста обычно не нужны все идентификаторы и детали исходного документа. Перед передачей данных выясните цель, разрешённый сервис и минимальный набор информации, достаточный для задачи. Минимизация снижает объём потенциального раскрытия и упрощает последующий контроль.',
          checkpoints: [
            'Ищите имена, контакты, идентификаторы, credentials и коммерческие секреты.',
            'Оставляйте только поля, необходимые для конкретного результата.',
          ],
        },
        {
          heading: 'Обезличивание требует проверки контекста',
          body: 'Удаление имени не всегда делает материал анонимным: сочетание должности, местоположения, редкого события или фрагмента договора может снова идентифицировать человека. Используйте нейтральные метки, обобщайте несущественные детали и проверяйте весь фрагмент после преобразования.',
          checkpoints: [
            'Проверьте риск повторной идентификации по косвенным деталям.',
            'Не включайте реальные пароли, ключи, токены или закрытые ссылки.',
          ],
        },
        {
          heading: 'Следуйте разрешённому процессу обработки',
          body: 'Перед загрузкой чувствительной информации изучите условия сервиса и правила организации. Некоторые задачи требуют специального одобренного инструмента, правового основания или участия ответственного специалиста. Если сомневаетесь в разрешённости, остановитесь и уточните процесс до передачи данных.',
          checkpoints: [
            'Определите, разрешено ли использовать выбранный инструмент для этого типа данных.',
            'Сохраняйте ответственность за доступ, хранение и удаление данных.',
          ],
        },
      ],
      keyTakeaways: [
        'Передавайте только минимально необходимые сведения.',
        'Удаление имени не всегда устраняет риск идентификации.',
        'Проверяйте правила сервиса и организации до обработки чувствительного контекста.',
      ],
    },
    'human-in-the-loop': {
      sections: [
        {
          heading: 'Контроль должен соответствовать риску',
          body: 'Черновик текста и решение, влияющее на права, безопасность или деньги, требуют разных процедур. Чем вероятнее и тяжелее последствия ошибки, тем сильнее должны быть доказательства и независимая проверка. Не используйте один и тот же контрольный список для всех случаев.',
          checkpoints: [
            'Опишите возможный вред и кто может пострадать от неверного результата.',
            'Разделите низкорисковые задачи и решения, требующие особой осторожности.',
          ],
        },
        {
          heading: 'Назначьте точки человеческого решения',
          body: 'Человек должен понимать, что именно система предлагает, какие данные и ограничения за этим стоят и когда нужно остановить процесс. Полезные точки контроля включают проверку исходных данных, утверждение рекомендаций, подтверждение действия и возможность эскалации сомнительного случая.',
          checkpoints: [
            'Определите, какие действия автоматизированы, а какие должен утвердить человек.',
            'Задайте условие остановки, при котором результат отклоняется или передаётся эксперту.',
          ],
        },
        {
          heading: 'Ответственность требует доказуемой процедуры',
          body: 'Фраза «человек в контуре» сама по себе не гарантирует надзор. Проверка должна иметь ответственного, критерии, запись результата и способ исправить ошибку. Если проверяющий не имеет времени, компетенции или права остановить процесс, контроль может быть лишь формальным.',
          checkpoints: [
            'Назовите владельца решения и способ документировать проверку.',
            'Убедитесь, что проверяющий может отклонить результат без давления на скорость.',
          ],
        },
      ],
      keyTakeaways: [
        'Строгость проверки зависит от возможного вреда.',
        'Точки человеческого утверждения и остановки должны быть заранее понятны.',
        'Контроль без полномочий и проверяемого процесса может быть формальным.',
      ],
    },
    'investigate-the-future': {
      sections: [
        {
          heading: 'Начните с конкретного вопроса',
          body: 'Большие вопросы о будущем ИИ слишком широки для проверки напрямую. Выберите узкую повторяемую задачу, сформулируйте ожидаемый результат и обозначьте ограничения эксперимента. Так можно получить локальное наблюдение, не притворяясь, что оно объясняет все отрасли или профессии.',
          checkpoints: [
            'Определите задачу, базовый способ выполнения и критерии хорошего результата.',
            'Запишите, какое предположение вы хотите проверить.',
          ],
        },
        {
          heading: 'Сравните полный рабочий процесс',
          body: 'Сравнивайте привычный подход и работу с ИИ при сопоставимых условиях. Учитывайте не только первую генерацию, но и проверку, редактирование, устранение ошибок и подготовку конечного результата. Система может ускорить отдельный шаг, но добавить расходы на другие этапы.',
          checkpoints: [
            'Измеряйте время до завершённого проверенного результата, а не до первого черновика.',
            'Учитывайте качество, исправления, новые риски и повторяемость.',
          ],
        },
        {
          heading: 'Сделайте вывод ограниченным и проверяемым',
          body: 'После нескольких попыток опишите, где инструмент помог, где не помог и что остаётся неизвестным. Не переносите один эксперимент на другие задачи без новых данных. Хороший вывод позволяет другому человеку повторить проверку и увидеть, что могло повлиять на результат.',
          checkpoints: [
            'Укажите количество попыток и условия, которые могли повлиять на результат.',
            'Предложите следующий небольшой эксперимент вместо универсального прогноза.',
          ],
        },
      ],
      keyTakeaways: [
        'Оценивайте ИИ на конкретной задаче с заранее заданными критериями.',
        'Считайте работу до проверенного результата, включая исправления.',
        'Не превращайте локальный эксперимент в универсальный прогноз.',
      ],
    },
  },
  en: {
    'intelligence-and-imitation': {
      sections: [
        {
          heading: 'A useful answer is not proof',
          body: 'An AI system can produce a quick draft, explain a term or suggest alternatives. Those can be useful actions, but they do not establish that every claim is true. Separate presentation quality from evidence quality: fluent, courteous prose may still contain errors.',
          checkpoints: [
            'Define the output needed: an idea, a draft, a calculation, a fact or a decision.',
            'Set a verification criterion before judging the result.',
          ],
        },
        {
          heading: 'Define the task before choosing the tool',
          body: 'Start with the desired outcome and constraints. A small task with a clear criterion is usually a better first experiment than an open-ended request to “do everything”. Split larger work into parts and retain human review wherever an error could change the outcome.',
          checkpoints: [
            'Describe the result, audience, constraints and format.',
            'Separate drafting, fact checking and the final decision.',
          ],
        },
        {
          heading: 'Measure results, not impressions',
          body: 'To learn whether a tool helps, compare its output with the usual workflow against the same criteria. Count review time, corrections, privacy concerns and the cost of mistakes. One successful example is a starting point for evaluation, not universal proof of effectiveness.',
          checkpoints: [
            'Keep a baseline version without AI for a fair comparison.',
            'Record limitations and mistakes alongside the benefits.',
          ],
        },
      ],
      keyTakeaways: [
        'Fluent text does not guarantee correctness.',
        'Set quality criteria before generation.',
        'Base the final judgement on a result that can be checked.',
      ],
    },
    'how-language-models-work': {
      sections: [
        {
          heading: 'How a model generates continuations',
          body: 'A language model is trained on sequences of data and receives the context of the current request. At an introductory level, it estimates possible continuations and generates text from learned patterns. That is different from opening a verified reference book or independently checking a fact.',
          checkpoints: [
            'Instructions and context influence which response is generated.',
            'A plausible continuation is not a verification step.',
          ],
        },
        {
          heading: 'Context, tools and limitations',
          body: 'Some applications add search, calculations, files or other tools. Then the result depends not only on the model, but also on source quality, permissions and correct tool use. A tool improves a workflow only when it is configured appropriately and its output is checked.',
          checkpoints: [
            'Establish whether the application actually used search or another tool.',
            'Check that the cited source or calculation supports the required claim.',
          ],
        },
        {
          heading: 'Why convincing errors occur',
          body: 'A model may generalise from incomplete examples, extend a flawed chain of reasoning or generate a nonexistent citation. Wording confidence does not measure truth. Match the level of oversight to the task: brainstorming and a consequential decision require different verification procedures.',
          checkpoints: [
            'Check dates, numbers, names, quotations and links with particular care.',
            'When evidence is absent, label an answer unverified rather than certain.',
          ],
        },
      ],
      keyTakeaways: [
        'Generating text is not the same as retrieving a verified fact.',
        'Context and extra tools change how a system works.',
        'Check errors against external evidence.',
      ],
    },
    'power-of-knowledge': {
      sections: [
        {
          heading: 'Access to knowledge depends on infrastructure',
          body: 'An AI service is shaped by more than its model. Compute, data, interface, price, language, source access and usage rules matter. Access to knowledge and the ability to influence its distribution can therefore be uneven across people and organisations.',
          checkpoints: [
            'Identify who can access the system and under what conditions.',
            'Check constraints created by cost, infrastructure and language.',
          ],
        },
        {
          heading: 'Openness and safety are separate questions',
          body: 'Open access may expand participation and independent scrutiny, but it does not remove privacy, licensing or harm concerns. Restricted access may help control risk while creating opacity and barriers. Assess concrete governance mechanisms rather than relying on the labels “open” or “safe”.',
          checkpoints: [
            'Ask who sets the rules and how an incorrect decision can be challenged.',
            'Distinguish open code, open data and service availability.',
          ],
        },
        {
          heading: 'Accountability makes decisions reviewable',
          body: 'For important uses, people need to know who owns the outcome, how errors are detected and how a review can be requested. Documentation, independent evaluation, clear limitations and feedback channels turn an abstract promise of accountability into a practice that can be examined.',
          checkpoints: [
            'Identify who is responsible for review and correction.',
            'Record how users can provide feedback or request a decision review.',
          ],
        },
      ],
      keyTakeaways: [
        'Real access is shaped by infrastructure, rules and cost.',
        'Openness does not remove privacy or risk assessment.',
        'Accountability needs a clear way to review and correct outcomes.',
      ],
    },
    'signal-and-noise': {
      sections: [
        {
          heading: 'More publications do not mean more evidence',
          body: 'Several pieces may cite the same original statement, summarise one another or use one dataset. There appears to be more information, but the basis for the claim has not necessarily changed. Tracing provenance helps distinguish independent confirmation from repetition.',
          checkpoints: [
            'Follow citations back to the earliest available primary source.',
            'Check whether different articles rely on the same document.',
          ],
        },
        {
          heading: 'Assess the quality of the evidence',
          body: 'After finding a source, examine who produced it, when it was published, how its data were obtained and what limitations it states. A source can be primary yet incomplete or unsuitable for the question. The claim must fit the evidence in meaning, time and scope.',
          checkpoints: [
            'Check dates, method, sample and boundaries of applicability.',
            'Verify that the document supports the specific claim being made.',
          ],
        },
        {
          heading: 'Unknown is a valid conclusion',
          body: 'When evidence is limited or sources disagree, do not force a confident choice. State what is known, what is disputed and what fact could clarify the question. This makes research reproducible and shows where further work is needed.',
          checkpoints: [
            'Separate verified facts, interpretations and unknowns.',
            'Record what new evidence could change the conclusion.',
          ],
        },
      ],
      keyTakeaways: [
        'Repeating one source does not create independent corroboration.',
        'A primary document still needs methodological and contextual review.',
        '“Unknown” is better than unsupported certainty.',
      ],
    },
    'verify-an-ai-answer': {
      sections: [
        {
          heading: 'Break the answer into claims',
          body: 'A broad answer may mix facts, assumptions, advice and conclusions. Split it into individual statements that can be checked separately. Highlight numbers, dates, names, quotations and causal claims: an error in one of these can change the meaning of the whole result.',
          checkpoints: [
            'Rewrite each consequential claim as one clear sentence.',
            'Specify what type of evidence each claim requires.',
          ],
        },
        {
          heading: 'Check whether the source supports the claim',
          body: 'Open the original publication and find the evidence that supposedly supports the response. Confirm that period, units, region, group and metric definition match. A link can open and discuss a related topic without supporting the specific statement placed beside it.',
          checkpoints: [
            'Read the primary document, not only a search-result snippet.',
            'Independently check formulas, inputs and units in calculations.',
          ],
        },
        {
          heading: 'Record the verification result',
          body: 'Give every claim a transparent status: confirmed, partly confirmed, contradicted by the source or unknown so far. Keep the source link and a short explanation. Do not replace missing evidence with intuition or treat another model’s response as independent proof.',
          checkpoints: [
            'State exactly what the source establishes and what remains unverified.',
            'Revise the response so uncertainty is visible to the reader.',
          ],
        },
      ],
      keyTakeaways: [
        'Verify individual statements instead of judging the whole answer by impression.',
        'A working link does not guarantee support for the stated claim.',
        'Verification status should be clear and reproducible.',
      ],
    },
    'privacy-before-prompting': {
      sections: [
        {
          heading: 'Decide what is actually needed',
          body: 'Text analysis rarely requires every identifier and detail in the original document. Before sharing data, define the purpose, approved service and minimum information required. Minimisation reduces potential exposure and makes later oversight easier.',
          checkpoints: [
            'Look for names, contacts, identifiers, credentials and business secrets.',
            'Keep only the fields needed for the specific result.',
          ],
        },
        {
          heading: 'De-identification requires contextual review',
          body: 'Removing a name does not always anonymise a document: a combination of role, location, rare event or contract detail may identify someone again. Replace identifiers with neutral labels, generalise unnecessary specifics and review the full transformed excerpt.',
          checkpoints: [
            'Check whether indirect details can identify the person again.',
            'Never include actual passwords, keys, tokens or private links.',
          ],
        },
        {
          heading: 'Use an approved data-handling process',
          body: 'Before uploading sensitive information, read the service terms and organisational rules. Some uses require a specifically approved tool, a lawful basis or a responsible specialist. If permission is unclear, pause and resolve the process before sharing the data.',
          checkpoints: [
            'Establish whether the chosen tool is allowed for this data type.',
            'Keep responsibility for access, storage and deletion clear.',
          ],
        },
      ],
      keyTakeaways: [
        'Share only the minimum information required.',
        'Removing a name does not always eliminate identification risk.',
        'Check service and organisational rules before handling sensitive context.',
      ],
    },
    'human-in-the-loop': {
      sections: [
        {
          heading: 'Match review to the risk',
          body: 'A draft text and a decision affecting rights, safety or money need different controls. The more likely and severe the consequences of error, the stronger the evidence and independent review should be. One checklist is not suitable for every case.',
          checkpoints: [
            'Describe plausible harm and who could be affected by an incorrect output.',
            'Separate low-risk tasks from consequential decisions.',
          ],
        },
        {
          heading: 'Define human decision points',
          body: 'A person needs to understand what the system proposes, what data and limits underlie it, and when the process should stop. Useful control points include checking input data, approving recommendations, confirming actions and escalating uncertain cases.',
          checkpoints: [
            'Specify what can be automated and what a person must approve.',
            'Define when to reject an output or send it to a qualified expert.',
          ],
        },
        {
          heading: 'Accountability requires a reviewable process',
          body: 'The phrase “human in the loop” does not guarantee meaningful oversight. Review needs an owner, criteria, a recorded result and a way to correct mistakes. If the reviewer lacks time, competence or the authority to stop the process, the control may be merely formal.',
          checkpoints: [
            'Name the decision owner and how the review will be documented.',
            'Ensure the reviewer can reject the output without pressure to prioritise speed.',
          ],
        },
      ],
      keyTakeaways: [
        'Review strength should reflect the potential harm.',
        'Human approval and stop points must be defined in advance.',
        'Oversight without authority or a checkable process may be only formal.',
      ],
    },
    'investigate-the-future': {
      sections: [
        {
          heading: 'Start with a concrete question',
          body: 'Large questions about AI’s future are too broad to test directly. Choose a narrow, repeatable task, define the expected result and state the experiment’s limits. This creates a local observation without pretending to explain every industry or occupation.',
          checkpoints: [
            'Define the task, baseline workflow and criteria for a good result.',
            'Record the specific assumption you want to test.',
          ],
        },
        {
          heading: 'Compare the full workflow',
          body: 'Compare the usual approach and the AI-assisted approach under similar conditions. Count not only the first generation but review, editing, error correction and preparation of the final output. A system may speed up one step while adding work elsewhere.',
          checkpoints: [
            'Measure time to a completed, checked result rather than the first draft.',
            'Track quality, corrections, new risks and repeatability.',
          ],
        },
        {
          heading: 'Keep conclusions narrow and testable',
          body: 'After several attempts, describe where the tool helped, where it failed and what remains unknown. Do not extend one experiment to other tasks without new data. A useful conclusion lets someone else repeat the test and see what may have influenced the result.',
          checkpoints: [
            'Record attempt count and conditions that may have affected the outcome.',
            'Suggest the next small experiment instead of making a universal forecast.',
          ],
        },
      ],
      keyTakeaways: [
        'Evaluate AI on a specific task with predefined criteria.',
        'Measure the work through a verified result, including corrections.',
        'Do not turn a local experiment into a universal forecast.',
      ],
    },
  },
}
