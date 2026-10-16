export type OSALessonLocale = 'ru' | 'en'

export { OSA_LESSON_SLUGS } from './osaLessonRegistry'

export type OSALessonGuide = {
  objectives: string[]
  example: string
  glossary: { term: string; definition: string }[]
  check: { question: string; options: string[]; correctIndex: number; explanation: string }
  exercise: { title: string; steps: string[]; successCriteria: string }
  sources: { title: string; url: string; context: string }[]
}

export const osaLessonGuides: Record<OSALessonLocale, OSALessonGuide[]> = {
  ru: [
    {
      objectives: [
        'Различать полезный результат ИИ и доказательство его истинности.',
        'Выбирать задачу, для которой можно заранее определить критерии качества.',
        'Объяснять, почему человеческая проверка должна соответствовать риску ошибки.',
      ],
      example: 'Попросите модель кратко объяснить незнакомую тему. Используйте объяснение как черновую карту, затем выберите одно важное утверждение и проверьте его по первоисточнику. Не оценивайте ответ только по уверенности тона или гладкости текста.',
      glossary: [
        { term: 'Критерий качества', definition: 'Заранее определённое условие, по которому оценивают результат: точность, полнота, ясность или пригодность для задачи.' },
        { term: 'Проверяемое утверждение', definition: 'Фраза, которую можно сопоставить с данными, документом, наблюдением или надёжным источником.' },
      ],
      check: {
        question: 'Что лучше всего показывает, что ответ ИИ подходит для важной задачи?',
        options: ['Ответ звучит уверенно и профессионально.', 'Ответ проверен по подходящим источникам и заданным критериям.', 'Ответ длиннее альтернативных ответов.'],
        correctIndex: 1,
        explanation: 'Уверенный стиль и объём не подтверждают точность. Нужны критерии, проверка ключевых утверждений и оценка последствий ошибки.',
      },
      exercise: {
        title: 'Сравните способ работы с ИИ и без него',
        steps: [
          'Выберите небольшую повторяемую задачу с низким риском.',
          'Зафиксируйте обычное время выполнения и критерии хорошего результата.',
          'Попросите ИИ подготовить черновик, затем проверьте факты и исправьте ошибки.',
          'Сравните время, качество, объём правок и новые риски с исходным способом.',
        ],
        successCriteria: 'Запишите конкретный результат сравнения и ограничения эксперимента. Не делайте общий вывод об ИИ по одному примеру.',
      },
      sources: [
        { title: 'Stanford HAI — AI Index', url: 'https://hai.stanford.edu/ai-index', context: 'Данные и контекст о развитии и применении ИИ.' },
        { title: 'NIST — AI Risk Management Framework', url: 'https://www.nist.gov/itl/ai-risk-management-framework', context: 'Подход к выявлению и управлению рисками ИИ-систем.' },
      ],
    },
    {
      objectives: [
        'Описывать на базовом уровне, как языковая модель генерирует текст.',
        'Отделять генерацию ответа от поиска, вычисления и проверки фактов.',
        'Выбирать проверку, соответствующую задаче и ограничениям инструмента.',
      ],
      example: 'Один и тот же вопрос может давать разные формулировки. Это не обязательно ошибка само по себе: генерация зависит от контекста, настроек и системы. Важно отдельно проверить факты, даты, расчёты и ссылки, особенно если они влияют на решение.',
      glossary: [
        { term: 'Языковая модель', definition: 'Модель машинного обучения, обученная работать с последовательностями текста и генерировать вероятные продолжения с учётом контекста.' },
        { term: 'Контекст', definition: 'Информация и инструкции, доступные модели в текущем взаимодействии; контекст не гарантирует истинность содержащихся в нём данных.' },
      ],
      check: {
        question: 'Какое описание языковой модели наиболее точное для вводного уровня?',
        options: ['Она всегда извлекает готовый факт из проверенной базы.', 'Она генерирует продолжение на основе выученных закономерностей и текущего контекста; дополнительные инструменты могут менять поведение системы.', 'Она знает, какие утверждения истинны, потому что обучалась на большом объёме текста.'],
        correctIndex: 1,
        explanation: 'Базовая генерация текста не равна гарантированному поиску или проверке фактов. Отдельные системы могут пользоваться поиском, инструментами или источниками, но их результат также требуется проверять.',
      },
      exercise: {
        title: 'Проверьте один ответ по частям',
        steps: [
          'Задайте вопрос, ответ на который содержит несколько проверяемых тезисов.',
          'Разделите ответ на отдельные утверждения и отметьте даты, числа и ссылки.',
          'Проверьте утверждения по первоисточникам, а расчёты — независимо.',
          'Запишите, какие части были верны, неточны, устарели или остались неизвестными.',
        ],
        successCriteria: 'У каждого существенного тезиса есть статус проверки; неизвестные элементы обозначены, а не замаскированы уверенным текстом.',
      },
      sources: [
        { title: 'OpenAI — Prompt engineering guide', url: 'https://platform.openai.com/docs/guides/prompt-engineering', context: 'Роль инструкций и контекста при работе с моделями.' },
        { title: 'Stanford HAI — AI Index', url: 'https://hai.stanford.edu/ai-index', context: 'Контекст развития и применения современных систем ИИ.' },
      ],
    },
    {
      objectives: [
        'Объяснять, почему доступ к информации связан с инфраструктурой и правилами платформ.',
        'Различать открытость системы, безопасность, приватность и подотчётность.',
        'Формулировать вопросы, по которым можно оценить последствия внедрения ИИ.',
      ],
      example: 'При выборе AI-сервиса недостаточно спросить, насколько он «мощный». Важно выяснить, какие данные он получает, кто может использовать результат, как исправлять ошибки и есть ли понятный способ оспорить важное решение.',
      glossary: [
        { term: 'Подотчётность', definition: 'Понятная ответственность за действия и последствия системы, включая возможность проверки и исправления.' },
        { term: 'Управление ИИ', definition: 'Правила, роли и процессы, помогающие контролировать разработку и применение систем ИИ.' },
      ],
      check: {
        question: 'Какой набор вопросов лучше оценивает общественный AI-сервис?',
        options: ['Только скорость ответа и количество функций.', 'Доступ, безопасность данных, ограничения, ответственность и возможность исправить ошибку.', 'Только популярность сервиса.'],
        correctIndex: 1,
        explanation: 'Полезность системы зависит не только от технической возможности, но и от условий доступа, риска, приватности и управления последствиями.',
      },
      exercise: {
        title: 'Составьте короткую карту последствий',
        steps: [
          'Назовите конкретную задачу и людей, на которых влияет результат.',
          'Определите, кто получает пользу, кто может понести ущерб и какие данные используются.',
          'Запишите, кто проверяет результат и кто исправляет ошибку.',
          'Добавьте механизм обратной связи или пересмотра решения.',
        ],
        successCriteria: 'Карта указывает на ответственных, возможные риски и проверяемые способы исправления, а не ограничивается общими лозунгами.',
      },
      sources: [
        { title: 'NIST — AI Risk Management Framework', url: 'https://www.nist.gov/itl/ai-risk-management-framework', context: 'Практическая структура для управления рисками ИИ.' },
        { title: 'Stanford HAI — AI Index', url: 'https://hai.stanford.edu/ai-index', context: 'Данные для оценки контекста и тенденций применения ИИ.' },
      ],
    },
    {
      objectives: [
        'Различать первоисточник, пересказ и независимое подтверждение.',
        'Выявлять несколько публикаций, которые зависят от одного исходного материала.',
        'Использовать неопределённость как допустимый вывод, когда доказательств мало.',
      ],
      example: 'Три сайта могут повторить одно пресс-сообщение. Количество страниц увеличилось, но независимых свидетельств не стало три. Проследите ссылки назад к первичному документу и выясните, подтверждает ли он исходное утверждение.',
      glossary: [
        { term: 'Первоисточник', definition: 'Исходный документ, данные, метод или заявление, на которых основано утверждение.' },
        { term: 'Независимое подтверждение', definition: 'Свидетельство, которое не является простым копированием того же источника и проверяется отдельно.' },
      ],
      check: {
        question: 'Три статьи ссылаются на одно и то же пресс-сообщение. Что это означает?',
        options: ['Утверждение независимо подтверждено трижды.', 'Есть несколько пересказов, но независимость свидетельств ещё не установлена.', 'Можно не читать первоисточник.'],
        correctIndex: 1,
        explanation: 'Число публикаций не равно числу независимых подтверждений. Нужно проследить происхождение информации и найти независимые данные.',
      },
      exercise: {
        title: 'Постройте цепочку происхождения одного тезиса',
        steps: [
          'Выберите новость или утверждение, которое встречается на нескольких сайтах.',
          'Откройте ссылки и найдите самый ранний доступный первичный документ.',
          'Сравните даты, формулировки, доказательства и ограничения.',
          'Отметьте, какие публикации независимы, повторяют друг друга или не дают доказательств.',
        ],
        successCriteria: 'Вы можете объяснить, откуда происходит тезис и какие независимые подтверждения существуют, не считая копии отдельными доказательствами.',
      },
      sources: [
        { title: 'NIST — AI Risk Management Framework', url: 'https://www.nist.gov/itl/ai-risk-management-framework', context: 'Структурированный подход к неопределённости и оценке риска.' },
        { title: 'Stanford HAI — AI Index', url: 'https://hai.stanford.edu/ai-index', context: 'Пример ресурса с методологией и исходным контекстом данных об ИИ.' },
      ],
    },
    {
      objectives: [
        'Проверять конкретный тезис, а не только наличие ссылки рядом с ним.',
        'Сверять дату, единицы измерения, выборку и ограничения исходных данных.',
        'Фиксировать результат проверки и сохранять неопределённость там, где ответ не найден.',
      ],
      example: 'Если модель сообщает точное число, откройте ссылку и найдите число в первичном материале. Сверьте, тот ли период, регион, показатель и набор данных использованы. Корректная ссылка может не подтверждать формулировку, рядом с которой она поставлена.',
      glossary: [
        { term: 'Соответствие источника тезису', definition: 'Насколько содержание источника действительно поддерживает конкретное утверждение, а не просто относится к похожей теме.' },
        { term: 'Ограничение данных', definition: 'Условие, сужающее применимость результата: например, дата, выборка, метод или неполнота информации.' },
      ],
      check: {
        question: 'Как проверить цифру, которую модель снабдила ссылкой?',
        options: ['Считать её верной, потому что ссылка открывается.', 'Открыть источник и сверить саму цифру, единицы, дату, метод и контекст.', 'Попросить другую модель повторить ответ.'],
        correctIndex: 1,
        explanation: 'Рабочая ссылка — это только начало проверки. Убедитесь, что первоисточник подтверждает именно данный тезис в нужном контексте.',
      },
      exercise: {
        title: 'Проведите аудит одного ответа',
        steps: [
          'Выберите ответ ИИ с тремя фактическими утверждениями.',
          'Для каждого тезиса найдите первичный источник либо запишите, что источник не найден.',
          'Сверьте формулировку, дату, числа и ограничения.',
          'Поставьте статус: подтверждено, частично подтверждено, противоречит источнику или неизвестно.',
        ],
        successCriteria: 'Каждый тезис имеет обоснованный статус и ссылку на источник, когда он найден; сомнение не заменяется догадкой.',
      },
      sources: [
        { title: 'NIST — AI Risk Management Framework', url: 'https://www.nist.gov/itl/ai-risk-management-framework', context: 'Оценка рисков и систематическая проверка поведения системы.' },
        { title: 'Stanford HAI — AI Index', url: 'https://hai.stanford.edu/ai-index', context: 'Проверяемые данные и контекст по вопросам развития ИИ.' },
      ],
    },
    {
      objectives: [
        'Находить лишние персональные данные, секреты и чувствительный контекст до отправки запроса.',
        'Применять минимизацию и обезличивание данных, когда это возможно.',
        'Проверять правила сервиса и организации до обработки чувствительной информации.',
      ],
      example: 'Для анализа обращения часто не нужны настоящее имя, телефон, адрес или номер договора. Сначала замените идентификаторы нейтральными обозначениями и проверьте, не можно ли восстановить личность по оставшимся деталям.',
      glossary: [
        { term: 'Минимизация данных', definition: 'Передача и обработка только тех данных, которые необходимы для конкретной разрешённой цели.' },
        { term: 'Обезличивание', definition: 'Удаление или преобразование идентификаторов; оно не всегда исключает повторное определение человека по косвенным признакам.' },
      ],
      check: {
        question: 'Какой первый шаг безопаснее перед загрузкой клиентского документа?',
        options: ['Загрузить всё, если это экономит время.', 'Проверить правила и убрать данные, которые не нужны для задачи.', 'Скрыть только имя, не проверяя остальные поля.'],
        correctIndex: 1,
        explanation: 'Сначала выясните, разрешена ли обработка в выбранном сервисе, и сократите объём данных. Одного удаления имени может быть недостаточно.',
      },
      exercise: {
        title: 'Подготовьте безопасную версию запроса',
        steps: [
          'Выберите вымышленный или разрешённый документ-пример.',
          'Отметьте персональные данные, секреты, учётные данные и чужую конфиденциальную информацию.',
          'Удалите ненужные поля, замените нужные идентификаторы нейтральными метками.',
          'Проверьте, не раскрывает ли оставшийся контекст человека или организацию косвенно.',
        ],
        successCriteria: 'Запрос содержит только необходимые данные, не раскрывает секреты и соответствует правилам обработки выбранного сервиса.',
      },
      sources: [
        { title: 'NIST — Privacy Framework', url: 'https://www.nist.gov/privacy-framework', context: 'Структура для выявления и управления рисками приватности.' },
        { title: 'NIST — AI Risk Management Framework', url: 'https://www.nist.gov/itl/ai-risk-management-framework', context: 'Связь технических решений ИИ с риском, управлением и ответственностью.' },
      ],
    },
    {
      objectives: [
        'Выбирать глубину проверки в зависимости от последствий ошибки.',
        'Определять критерии качества до того, как просить ИИ подготовить решение.',
        'Сохранять за человеком финальную оценку и ответственность там, где это необходимо.',
      ],
      example: 'Для черновика внутреннего письма достаточно одной проверки тона и фактов. Для медицинского, юридического, финансового или кадрового решения нужны специальные компетенции, первичные данные и установленный процесс проверки; ответ чат-бота сам по себе не является разрешением действовать.',
      glossary: [
        { term: 'Человек в контуре', definition: 'Организация процесса так, чтобы человек проверял, утверждал или мог остановить результат системы в нужных точках.' },
        { term: 'Соразмерность риска', definition: 'Глубина контроля выбирается с учётом вероятности и тяжести возможного вреда.' },
      ],
      check: {
        question: 'Как изменить проверку, когда последствия ошибки становятся серьёзнее?',
        options: ['Использовать тот же быстрый просмотр для любой задачи.', 'Усилить проверку, привлечь компетентного специалиста и установить критерии до принятия решения.', 'Передать модели право на окончательное решение.'],
        correctIndex: 1,
        explanation: 'Контроль должен соответствовать риску. Чем серьёзнее возможный вред, тем важнее независимые доказательства, компетентная проверка и чёткая ответственность.',
      },
      exercise: {
        title: 'Составьте чек-лист проверки с учётом риска',
        steps: [
          'Опишите решение и самый серьёзный правдоподобный вред от ошибки.',
          'Разделите задачу на проверяемые утверждения, расчёты и рекомендации.',
          'Укажите, что можно автоматизировать, что должен проверить человек и когда требуется эксперт.',
          'Определите условие, при котором результат нужно отклонить или эскалировать.',
        ],
        successCriteria: 'В чек-листе есть критерии, ответственный проверяющий и чёткое условие остановки для неприемлемого риска.',
      },
      sources: [
        { title: 'NIST — AI Risk Management Framework', url: 'https://www.nist.gov/itl/ai-risk-management-framework', context: 'Практические функции управления, измерения и контроля рисков ИИ.' },
        { title: 'NIST — Privacy Framework', url: 'https://www.nist.gov/privacy-framework', context: 'Дополнительный взгляд на последствия обработки данных.' },
      ],
    },
    {
      objectives: [
        'Оценивать ИИ через измеряемую задачу, а не через абстрактные обещания.',
        'Сравнивать качество и скорость с исходным способом работы.',
        'Обозначать границы личного эксперимента и не переносить вывод на все профессии.',
      ],
      example: 'Выберите одну регулярную задачу: первичный план, черновик или сортировку материалов. Сравните несколько попыток с обычным процессом, включая время проверки, исправления и ошибки. Ускорение первого черновика не всегда означает ускорение всей работы.',
      glossary: [
        { term: 'Базовый уровень', definition: 'Результат обычного процесса, с которым сравнивают новый подход по одинаковым критериям.' },
        { term: 'Чистая выгода', definition: 'Изменение времени и качества после учёта проверки, исправлений, ошибок и дополнительных затрат.' },
      ],
      check: {
        question: 'Как сделать полезный вывод из личного эксперимента с ИИ?',
        options: ['Сравнить один удачный ответ с воспоминанием о старом способе.', 'Повторить задачу по одинаковым критериям, учитывать правки и риски и явно записать ограничения.', 'Предположить, что результат одинаков для всех задач и профессий.'],
        correctIndex: 1,
        explanation: 'Справедливое сравнение требует базового уровня, повторяемых критериев и учёта всей работы, а не только скорости генерации.',
      },
      exercise: {
        title: 'Проведите небольшой полевой эксперимент',
        steps: [
          'Выберите одну низкорисковую задачу и опишите исходный процесс.',
          'Заранее определите метрики: время, точность, полнота, правки и ошибки.',
          'Выполните несколько попыток обычным способом и с ИИ в сходных условиях.',
          'Сравните результаты и запишите, где метод полезен, где не помогает и что ещё нужно проверить.',
        ],
        successCriteria: 'Вы получили проверяемое сравнение для одной задачи и не выдаёте локальный эксперимент за универсальный прогноз.',
      },
      sources: [
        { title: 'ILO — Generative AI and Jobs', url: 'https://www.ilo.org/publications/generative-ai-and-jobs-global-analysis-potential-effects-job-quantity-and', context: 'Глобальный анализ возможных эффектов генеративного ИИ на занятость.' },
        { title: 'Stanford HAI — AI Index', url: 'https://hai.stanford.edu/ai-index', context: 'Контекст и данные об исследованиях и внедрении ИИ.' },
      ],
    },
  ],
  en: [
    {
      objectives: [
        'Distinguish a useful AI output from evidence that it is true.',
        'Choose a task with criteria that can be defined before using a model.',
        'Match human review to the risk of an error.',
      ],
      example: 'Ask a model to explain an unfamiliar topic. Use the explanation as a first-pass map, then pick one consequential claim and check it against a primary source. Do not judge the output only by its confident tone or polished writing.',
      glossary: [
        { term: 'Quality criterion', definition: 'A condition defined in advance for evaluating a result, such as accuracy, completeness, clarity or suitability for the task.' },
        { term: 'Verifiable claim', definition: 'A statement that can be compared with data, a document, an observation or a reliable source.' },
      ],
      check: {
        question: 'What best shows that an AI answer is suitable for an important task?',
        options: ['It sounds confident and professional.', 'Its key claims have been checked against relevant sources and predefined criteria.', 'It is longer than alternative answers.'],
        correctIndex: 1,
        explanation: 'A confident style and length do not establish accuracy. Use criteria, verify important claims and consider the consequences of error.',
      },
      exercise: {
        title: 'Compare a workflow with and without AI',
        steps: [
          'Choose a small, repeatable, low-risk task.',
          'Record the usual completion time and define what a good result means.',
          'Ask AI for a draft, then verify facts and correct errors.',
          'Compare time, quality, edits and new risks with the original workflow.',
        ],
        successCriteria: 'Record a concrete comparison and its limitations. Do not generalise about AI from one example.',
      },
      sources: [
        { title: 'Stanford HAI — AI Index', url: 'https://hai.stanford.edu/ai-index', context: 'Data and context about AI development and deployment.' },
        { title: 'NIST — AI Risk Management Framework', url: 'https://www.nist.gov/itl/ai-risk-management-framework', context: 'A framework for identifying and managing AI-system risks.' },
      ],
    },
    {
      objectives: [
        'Describe at a basic level how a language model generates text.',
        'Separate text generation from retrieval, calculation and fact verification.',
        'Choose checks that fit the task and the tool’s limitations.',
      ],
      example: 'The same question may produce different wording. That is not necessarily an error by itself: generation depends on context, settings and the system. Separately verify facts, dates, calculations and links when they affect a decision.',
      glossary: [
        { term: 'Language model', definition: 'A machine-learning model trained on sequences of text to generate likely continuations given a context.' },
        { term: 'Context', definition: 'Information and instructions available to the model during an interaction; context does not guarantee that the information is true.' },
      ],
      check: {
        question: 'Which description of a language model is the most accurate at an introductory level?',
        options: ['It always retrieves a verified fact from a trusted database.', 'It generates continuations from learned patterns and current context; tools can change how a system behaves.', 'It knows which claims are true because it trained on a lot of text.'],
        correctIndex: 1,
        explanation: 'Basic text generation is not the same as guaranteed retrieval or fact checking. Some systems use search or other tools, but their results still require verification.',
      },
      exercise: {
        title: 'Check an answer claim by claim',
        steps: [
          'Ask a question whose answer contains several verifiable claims.',
          'Split the answer into claims and mark dates, numbers and links.',
          'Check claims against primary sources and independently verify calculations.',
          'Record which parts are correct, inaccurate, outdated or still unknown.',
        ],
        successCriteria: 'Each consequential claim has a verification status. Unknown parts remain labelled as unknown rather than hidden behind confident prose.',
      },
      sources: [
        { title: 'OpenAI — Prompt engineering guide', url: 'https://platform.openai.com/docs/guides/prompt-engineering', context: 'The role of instructions and context in working with models.' },
        { title: 'Stanford HAI — AI Index', url: 'https://hai.stanford.edu/ai-index', context: 'Context on the development and deployment of modern AI systems.' },
      ],
    },
    {
      objectives: [
        'Explain why access to information is shaped by infrastructure and platform rules.',
        'Distinguish openness, safety, privacy and accountability.',
        'Ask concrete questions to assess the consequences of deploying AI.',
      ],
      example: 'When choosing an AI service, it is not enough to ask whether it is powerful. Ask what data it receives, who can use its output, how errors are corrected and whether consequential decisions can be challenged.',
      glossary: [
        { term: 'Accountability', definition: 'Clear responsibility for a system’s actions and consequences, including ways to review and correct them.' },
        { term: 'AI governance', definition: 'The rules, roles and processes used to oversee the development and use of AI systems.' },
      ],
      check: {
        question: 'Which set of questions best evaluates a public AI service?',
        options: ['Only response speed and number of features.', 'Access, data safety, limitations, accountability and ways to correct mistakes.', 'Only the service’s popularity.'],
        correctIndex: 1,
        explanation: 'A system’s value depends on more than capability. Access conditions, risk, privacy and governance shape real-world outcomes.',
      },
      exercise: {
        title: 'Create a brief impact map',
        steps: [
          'Name the task and the people affected by the output.',
          'Record who benefits, who could be harmed and what data is used.',
          'Identify who reviews the output and who fixes an error.',
          'Add a feedback or review mechanism.',
        ],
        successCriteria: 'The map identifies accountable roles, plausible risks and testable correction paths rather than relying on slogans.',
      },
      sources: [
        { title: 'NIST — AI Risk Management Framework', url: 'https://www.nist.gov/itl/ai-risk-management-framework', context: 'A practical framework for AI risk management.' },
        { title: 'Stanford HAI — AI Index', url: 'https://hai.stanford.edu/ai-index', context: 'Data to help assess AI deployment context and trends.' },
      ],
    },
    {
      objectives: [
        'Distinguish primary sources, summaries and independent corroboration.',
        'Identify publications that depend on the same original source.',
        'Treat uncertainty as a valid conclusion when evidence is limited.',
      ],
      example: 'Three websites may repeat one press release. There are more pages, but not necessarily three independent pieces of evidence. Follow citations back to the original document and check whether it supports the claim.',
      glossary: [
        { term: 'Primary source', definition: 'The original document, dataset, method or statement on which a claim is based.' },
        { term: 'Independent corroboration', definition: 'Evidence checked separately rather than copied from the same source.' },
      ],
      check: {
        question: 'Three articles cite the same press release. What does that establish?',
        options: ['The claim has been independently confirmed three times.', 'There are several reports, but the independence of the evidence has not been established.', 'There is no need to read the primary source.'],
        correctIndex: 1,
        explanation: 'The number of publications is not the number of independent confirmations. Trace the information’s origin and look for separate evidence.',
      },
      exercise: {
        title: 'Trace the origin of a claim',
        steps: [
          'Choose a news item or claim repeated across several websites.',
          'Follow citations and locate the earliest available primary document.',
          'Compare dates, wording, evidence and limitations.',
          'Mark which reports are independent, repeat one another or offer no evidence.',
        ],
        successCriteria: 'You can describe where the claim originated and what independent evidence exists without counting copies as separate proof.',
      },
      sources: [
        { title: 'NIST — AI Risk Management Framework', url: 'https://www.nist.gov/itl/ai-risk-management-framework', context: 'A structured approach to uncertainty and risk assessment.' },
        { title: 'Stanford HAI — AI Index', url: 'https://hai.stanford.edu/ai-index', context: 'An example of a resource with methodology and underlying data context.' },
      ],
    },
    {
      objectives: [
        'Verify the specific claim rather than only checking whether a nearby link exists.',
        'Check dates, units, sample, method and limits in the underlying material.',
        'Record verification outcomes and preserve uncertainty where answers are unavailable.',
      ],
      example: 'If a model gives a precise number, open the link and find that number in the primary material. Confirm the period, region, metric and dataset. A valid link may still fail to support the statement it accompanies.',
      glossary: [
        { term: 'Source-to-claim fit', definition: 'How well a source actually supports a specific statement rather than merely discussing a related topic.' },
        { term: 'Data limitation', definition: 'A condition that narrows how a result can be used, such as date, sample, method or missing information.' },
      ],
      check: {
        question: 'How should you verify a number that an AI answer cites?',
        options: ['Trust it if the link opens.', 'Open the source and check the number, units, date, method and context.', 'Ask another model to repeat the answer.'],
        correctIndex: 1,
        explanation: 'A working link is only the beginning. Make sure the primary source supports that exact claim in the relevant context.',
      },
      exercise: {
        title: 'Audit one AI answer',
        steps: [
          'Select an answer containing three factual claims.',
          'Find a primary source for each claim or record that none was found.',
          'Check wording, dates, figures and limitations.',
          'Label each claim confirmed, partly confirmed, contradicted or unknown.',
        ],
        successCriteria: 'Each claim has a reasoned status and a source where found; uncertainty is not replaced by a guess.',
      },
      sources: [
        { title: 'NIST — AI Risk Management Framework', url: 'https://www.nist.gov/itl/ai-risk-management-framework', context: 'Risk assessment and systematic evaluation of AI-system behavior.' },
        { title: 'Stanford HAI — AI Index', url: 'https://hai.stanford.edu/ai-index', context: 'Verifiable information and context on AI development.' },
      ],
    },
    {
      objectives: [
        'Find unnecessary personal data, secrets and sensitive context before sharing a prompt.',
        'Apply data minimisation and de-identification where feasible.',
        'Check service and organisational rules before processing sensitive information.',
      ],
      example: 'A request analysis may not need a real name, phone number, address or contract identifier. Replace identifiers with neutral labels and check whether the remaining details could still reveal the person.',
      glossary: [
        { term: 'Data minimisation', definition: 'Sharing and processing only the data needed for a specific, permitted purpose.' },
        { term: 'De-identification', definition: 'Removing or transforming identifiers; it does not always prevent re-identification from indirect clues.' },
      ],
      check: {
        question: 'What is the safer first step before uploading a customer document?',
        options: ['Upload everything if it saves time.', 'Check the rules and remove data that is not needed for the task.', 'Hide only the name and ignore the other fields.'],
        correctIndex: 1,
        explanation: 'First determine whether processing is permitted in the chosen service and reduce the data shared. Removing a name alone may not be sufficient.',
      },
      exercise: {
        title: 'Prepare a safer prompt',
        steps: [
          'Use a fictional or authorised example document.',
          'Identify personal data, secrets, credentials and confidential information about others.',
          'Remove unnecessary fields and replace essential identifiers with neutral labels.',
          'Check whether remaining context could indirectly identify a person or organisation.',
        ],
        successCriteria: 'The prompt contains only necessary data, does not reveal secrets and follows the chosen service’s handling rules.',
      },
      sources: [
        { title: 'NIST — Privacy Framework', url: 'https://www.nist.gov/privacy-framework', context: 'A structure for identifying and managing privacy risks.' },
        { title: 'NIST — AI Risk Management Framework', url: 'https://www.nist.gov/itl/ai-risk-management-framework', context: 'How AI decisions connect to risk, governance and accountability.' },
      ],
    },
    {
      objectives: [
        'Choose a level of verification that reflects the consequences of an error.',
        'Define quality criteria before asking AI to prepare a recommendation.',
        'Retain human review and responsibility where required.',
      ],
      example: 'A draft internal email may need a quick tone and fact check. A medical, legal, financial or hiring decision needs qualified expertise, primary information and an established review process; a chatbot response alone is not permission to act.',
      glossary: [
        { term: 'Human in the loop', definition: 'A process in which a person reviews, approves or can stop a system’s output at defined points.' },
        { term: 'Risk-proportionate review', definition: 'The depth of oversight is selected in light of the likelihood and severity of possible harm.' },
      ],
      check: {
        question: 'How should verification change when the consequences of an error become more serious?',
        options: ['Use the same quick glance for every task.', 'Strengthen review, involve a qualified person and set criteria before deciding.', 'Give the model final authority.'],
        correctIndex: 1,
        explanation: 'Oversight should match the risk. Serious potential harm calls for stronger evidence, qualified review and clear accountability.',
      },
      exercise: {
        title: 'Build a risk-aware review checklist',
        steps: [
          'Describe the decision and the most serious plausible harm from an error.',
          'Split the task into claims, calculations and recommendations that can be checked.',
          'Specify what may be automated, what a person must verify and when an expert is needed.',
          'Define when to reject the output or escalate the case.',
        ],
        successCriteria: 'The checklist names criteria, a responsible reviewer and a clear stop condition for unacceptable risk.',
      },
      sources: [
        { title: 'NIST — AI Risk Management Framework', url: 'https://www.nist.gov/itl/ai-risk-management-framework', context: 'Practical functions for governing, measuring and managing AI risks.' },
        { title: 'NIST — Privacy Framework', url: 'https://www.nist.gov/privacy-framework', context: 'An additional view on the consequences of data processing.' },
      ],
    },
    {
      objectives: [
        'Evaluate AI through a measurable task rather than broad promises.',
        'Compare quality and speed with the original workflow.',
        'State the limits of a personal experiment instead of generalising to all jobs.',
      ],
      example: 'Choose one recurring task such as a first draft, plan or sorting materials. Compare multiple attempts with the usual process, including review time, edits and mistakes. Faster drafting does not always mean the whole task gets faster.',
      glossary: [
        { term: 'Baseline', definition: 'The usual process or result used as a comparison point under the same criteria.' },
        { term: 'Net benefit', definition: 'The change in time and quality after accounting for review, corrections, errors and additional costs.' },
      ],
      check: {
        question: 'How can you draw a useful conclusion from a personal AI experiment?',
        options: ['Compare one good answer with a memory of the old process.', 'Repeat the task under comparable conditions, count edits and risks, and record limitations.', 'Assume the result applies equally to all tasks and occupations.'],
        correctIndex: 1,
        explanation: 'A fair comparison needs a baseline, repeatable criteria and the full cost of the work, not only generation speed.',
      },
      exercise: {
        title: 'Run a small field experiment',
        steps: [
          'Choose one low-risk task and describe the original workflow.',
          'Define metrics in advance: time, accuracy, completeness, edits and errors.',
          'Complete several attempts with and without AI under similar conditions.',
          'Compare outcomes and record where the method helps, fails or needs more evidence.',
        ],
        successCriteria: 'You have a checkable comparison for one task and do not present a local experiment as a universal forecast.',
      },
      sources: [
        { title: 'ILO — Generative AI and Jobs', url: 'https://www.ilo.org/publications/generative-ai-and-jobs-global-analysis-potential-effects-job-quantity-and', context: 'Global analysis of potential effects of generative AI on employment.' },
        { title: 'Stanford HAI — AI Index', url: 'https://hai.stanford.edu/ai-index', context: 'Context and data about AI research and deployment.' },
      ],
    },
  ],
}
