import { getPlayGame } from './redesignCatalog'

const cleanSeo: Record<string, { title: string; description: string }> = {
  '/osa-cinema': { title: 'OSA Original — интерактивный фильм об ИИ и власти знаний', description: 'Три акта об искусственном интеллекте, власти информации и будущем человека. Интерактивные решения, источники и прогресс на устройстве.' },
  '/': { title: 'OSA Intelligence — понимать, проверять, решать', description: 'Интерактивная среда OSA: изучайте возможности ИИ, проверяйте доказательства и принимайте ответственные решения.' },
  '/academy': { title: 'OSGARD AI Academy — понимать, проверять, применять ИИ', description: 'Учебные маршруты, интерактивный курс и практическая студия по применению искусственного интеллекта.' },
  '/learning/assessment': { title: 'OSA Learning — проверка знаний', description: 'Восемь проверочных вопросов по интерактивным урокам OSA.' },
  '/learning/program': { title: 'OSA — Практическая программа | OSGARD', description: 'Восемь уроков, практический проект и рубрика проверки.' },
  '/learning/workspace': { title: 'OSA — Мастерская проектов | OSGARD', description: 'Коллекция практических проектов и история версий.' },
  '/learning/portfolio': { title: 'OSA — Локальное портфолио | OSGARD', description: 'Практические работы ученика на этом устройстве.' },
  '/learning/experiments': { title: 'OSA — журнал экспериментов | OSGARD', description: 'Сравнение времени и качества работы с ИИ и без него.' },
  '/learning/project': { title: 'OSA — учебный проект | OSGARD', description: 'Цель, план, практическая работа и самооценка учебного проекта OSA.' },
  '/learning/pricing': { title: 'OSA Learning — программы и доступ', description: 'Практические программы OSA по ИИ и технологиям: самостоятельное обучение, сопровождение и командные пилоты.' },
  '/learning': { title: 'OSA Learning — карта знаний | OSGARD', description: 'Учебные маршруты, результаты и следующий урок OSA Learning.' },
  '/lectures': { title: 'OSA Original — курсы и интерактивные лекции | OSGARD', description: 'Упорядоченная программа OSA Original: три акта и все существующие интерактивные лекции об ИИ, власти знаний и человеческом выборе. Видеозаписи отмечены отдельно от доступных интерактивных сцен.' },
  '/portal': { title: 'OSGARD World — портал экосистемы', description: 'Продукты, игры, проекты и направления цифровой экосистемы OSGARD.' },
  '/worlds': { title: 'Миры OSGARD — семь самостоятельных продуктов', description: 'Выберите мир OSGARD: защита, мобильность, бизнес, время и создание цифровых продуктов.' },
  '/catalog': { title: 'Каталог OSGARD — продукты и решения', description: 'Каталог самостоятельных продуктов OSGARD с понятными условиями и маршрутами.' },
  '/chronicle': { title: 'Хроника OSGARD — история экосистемы', description: 'События, продукты и ключевые этапы развития OSGARD.' },
  '/masters': { title: 'Мастера OSGARD — люди и команды', description: 'Команды OSGARD и их работа над продуктами, играми и цифровыми решениями.' },
  '/club': { title: 'Клуб OSGARD — закрытое пространство', description: 'Клуб OSGARD для раннего доступа, общения и совместного развития продуктов.' },
  '/aurum': { title: 'AURUM — координационный интеллект OSGARD', description: 'AURUM связывает продукты OSGARD в единую картину и помогает выбрать следующий шаг.' },
  '/timecoin': { title: 'TimeCoin OSGARD — правила и условия', description: 'Правила внутренней бонусной единицы OSGARD для доступа, статуса и специальных условий.' },
  '/development': { title: 'OSGARD Development — создание цифровых продуктов', description: 'Разработка сайтов, приложений и MVP-платформ от идеи до запуска.' },
  '/entertainment': { title: 'OSGARD Entertainment — интерактивные игры', description: 'Игры OSGARD: выбирайте мир, запускайте сессию и сохраняйте результат.' },
  '/skillcred': { title: 'SkillCred — навыки, которые остаются с вами | OSGARD', description: 'Переносимые цифровые подтверждения навыков. Проверка Ed25519 в браузере.' },
  '/games/time': { title: 'Империя времени — стратегия живого города | OSGARD PLAY', description: 'Управляйте казной, энергией, районами и политическими фракциями. Каждое решение меняет летопись города.' },
}

Object.assign(cleanSeo, {
 '/':{title:'OSGARD WORLD — цифровые продукты, построенные как системы',description:'Стратегия, структура, дизайн и разработка цифровых продуктов. OSA Intelligence, Development и OSGARD PLAY.'},
 '/intelligence':{title:'OSA Intelligence — понимать ИИ, проверять, решать',description:'Интеллектуальная среда OSA: метод проверки, интерактивный пример, восемь уроков и практические проекты.'},
 '/play':{title:'OSGARD PLAY — каталог игровых миров',description:'Стратегии, платформеры и кооперативные эксперименты. Фильтры, управление и честные статусы сохранения и онлайна.'},
 '/games':{title:'OSGARD PLAY — каталог игровых миров',description:'Каталог игр OSGARD: платформы, управление и статусы доступности.'},
 '/entertainment':{title:'OSGARD PLAY — игровые миры',description:'Каталог игр OSGARD с платформами, управлением и статусами доступности.'},
 '/development':{title:'OSGARD Development — цифровые продукты и кейсы',description:'PHANTOM, TEDES, MERAKKI и ESSENTIA. Концепты, демо и прототипы с обозначенными стадиями.'},
 '/play/partners':{title:'OSGARD PLAY — партнёрам',description:'Обсуждение игровых интеграций, брендированных миров и испытаний. Условия и техническая проверка до запуска.'},
 '/brand':{title:'OSGARD — фирменная система открытого портала',description:'Мастер-знак, версии для OSA и PLAY, монохромные варианты, favicon и правила движения.'},
 '/learning/organizer':{title:'OSA — организация пилота и очередь разборов',description:'Доступные учебные проекты, назначения проверяющих, сроки и отчёты по сохранённым данным.'},
 '/learning/campus':{title:'OSA Learning — практика, итоговый проект и расписание',description:'Серверные учебные записи, снимки итоговой работы, разбор по рубрике и расписание пилота.'},
 '/learning/enrollment':{title:'OSA — приобретённая практическая программа',description:'Состояние зачисления, версия программы, личная практика и экспорт собственных работ.'},
 '/teams':{title:'OSGARD Core — команды',description:'Командные пространства, роли и явное подключение проектов.'},
 '/deliveries':{title:'OSGARD — полученные материалы',description:'Изолированная передача выпуска и обсуждение без доступа к внутреннему проекту.'},
 '/purchases':{title:'OSGARD — мои покупки',description:'Состояние заказа, подтверждённая оплата и доступ к приобретённому результату.'},
 '/workspace/overview':{title:'OSGARD Core — рабочий центр',description:'Состояние доступных проектов, очередь проверок, расходы и следующий шаг.'},
 '/account':{title:'OSGARD Core — аккаунт и доступ',description:'Сессии, смена пароля и резервные коды для восстановления доступа к серверному аккаунту.'},
 '/workspace':{title:'OSGARD Core — от цели к результату',description:'Контракт, серверные проекты, Learning, Studio и Business. Версии, разрешения и контроль бюджета.'},
 '/data':{title:'OSGARD — резервные копии ваших данных',description:'Экспорт и восстановление локального прогресса, проектов и коллекции PLAY.'},
 '/quality':{title:'OSGARD — состояние локальной сборки',description:'Фактические возможности, ограничения, локальные события и критерии качества OSGARD.'},
})

export function updateRouteSeo(path: string): void {
    const gameId = path.startsWith('/play/world/') ? path.slice('/play/world/'.length) : null
    const game = gameId ? getPlayGame(gameId) : undefined
    const lessonTitles: Record<string,string> = {'intelligence-and-imitation':'Интеллект и имитация','how-language-models-work':'Как работают языковые модели','power-of-knowledge':'Власть знаний','signal-and-noise':'Сигнал и шум','verify-an-ai-answer':'Проверьте ответ ИИ','privacy-before-prompting':'Приватность до запроса','human-in-the-loop':'Человек в контуре','investigate-the-future':'Исследуйте будущее'}
    const lessonTitle = path.startsWith('/lectures/') ? lessonTitles[path.slice('/lectures/'.length)] : null
    const data = lessonTitle ? {title:'OSA — '+lessonTitle,description:'Урок OSA: '+lessonTitle+'. Цели, материал, практика, самопроверка и источники.'} : (game ? { title: game.title+' — OSGARD PLAY', description: game.description+' '+game.platform+'. Инструкция, сохранение и запуск.' } : gameId ? { title: 'Мир не найден — OSGARD PLAY', description: 'Такого мира нет в каталоге. Откройте OSGARD PLAY и выберите доступный проект.' } : cleanSeo[path]) ?? (path.startsWith('/lectures/') ? { title: 'OSA Original — подробная лекция | OSGARD', description: 'Учебные цели, материал, словарь, самопроверка, практика и проверяемые источники OSA Original.' } : cleanSeo['/'])
    const canonicalPath = path==='/entertainment'||path==='/games'?'/play':path
    const canonical = `https://osgard.world${canonicalPath === '/' ? '/' : canonicalPath}`
    document.title = data.title
    const setMeta = (selector: string, attribute: string, value: string) => {
      let element = document.head.querySelector<HTMLMetaElement>(selector)
      if (!element) {
        element = document.createElement('meta')
        const identity = /^meta\[(name|property)="([^"]+)"\]$/.exec(selector)
        if (!identity) return
        element.setAttribute(identity[1], identity[2])
        document.head.appendChild(element)
      }
      element.setAttribute(attribute, value)
    }
    setMeta('meta[name="description"]', 'content', data.description)
    const privateRoute = ['/account','/workspace','/workspace/overview','/teams','/deliveries','/purchases','/data','/learning/campus','/learning/organizer','/learning/enrollment'].includes(path)
    setMeta('meta[name="robots"]', 'content', privateRoute || gameId && !game ? 'noindex,follow' : 'index,follow')
    setMeta('meta[name="twitter:card"]', 'content', 'summary_large_image')
    setMeta('meta[property="og:title"]', 'content', data.title)
    setMeta('meta[property="og:description"]', 'content', data.description)
    setMeta('meta[property="og:url"]', 'content', canonical)
    const theme = path==='/'&&(new URLSearchParams(location.search).has('project')||location.hash==='#project-studio')?'intelligence':path==='/play/partners'?'world':path==='/play'||path.startsWith('/play/')||path==='/games'||path==='/entertainment'?'play':path==='/intelligence'||path.startsWith('/learning')||path.startsWith('/lectures')||path==='/academy'||path==='/osa-cinema'?'intelligence':'world'
    const preview = `https://osgard.world/brand/preview-${theme}.png`
    setMeta('meta[property="og:image"]', 'content', preview)
    setMeta('meta[property="og:image:alt"]', 'content', data.title)
    setMeta('meta[name="twitter:title"]', 'content', data.title)
    setMeta('meta[name="twitter:description"]', 'content', data.description)
    setMeta('meta[name="twitter:image"]', 'content', preview)
    setMeta('meta[name="theme-color"]', 'content', theme==='world'?'#F3F4F1':theme==='intelligence'?'#101A27':'#080B12')
    let link = document.head.querySelector<HTMLLinkElement>('link[rel="canonical"]')
    if (!link) { link = document.createElement('link'); link.rel = 'canonical'; document.head.appendChild(link) }
    link.href = canonical
    const jsonLd = { '@context': 'https://schema.org', '@type': 'WebPage', name: data.title, description: data.description, url: canonical, isPartOf: { '@type': 'WebSite', name: 'OSGARD WORLD', url: 'https://osgard.world/' } }
    let script = document.head.querySelector<HTMLScriptElement>('script[data-route-seo]')
    if (!script) { script = document.createElement('script'); script.type = 'application/ld+json'; script.dataset.routeSeo = 'true'; document.head.appendChild(script) }
    script.textContent = JSON.stringify(jsonLd)
}
