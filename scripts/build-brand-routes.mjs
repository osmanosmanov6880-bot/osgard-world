import { readFile,writeFile,mkdir } from 'node:fs/promises'
const template=await readFile('dist/index.html','utf8')
const routes=[
 ['teams','OSGARD Core — команды','Командные пространства, роли и подключение проектов.','world'],
 ['deliveries','OSGARD — полученные материалы','Изолированная передача выпуска и обсуждение без доступа к внутреннему проекту.','world'],
 ['workspace/overview','OSGARD Core — рабочий центр','Состояние доступных проектов, очередь проверок, расходы и следующий шаг.','world'],
 ['account','OSGARD Core — аккаунт и доступ','Сессии, смена пароля и резервные коды восстановления.','world'],
 ['learning/organizer','OSA — организация пилота и очередь разборов','Назначения проверяющих, сроки и отчёты по сохранённым учебным данным.','intelligence'],
 ['learning/campus','OSA Learning — практика, итоговый проект и расписание','Серверная практика, версионная сдача работы, разбор и расписание пилота.','intelligence'],
 ['workspace','OSGARD Core — от цели к результату','Контракт, Learning, Studio, Business и серверные версии проекта.','world'],
 ['intelligence','OSA Intelligence — понимать ИИ, проверять, решать','Метод проверки, учебная демонстрация, восемь уроков и практические проекты.','intelligence'],
 ['play','OSGARD PLAY — каталог игровых миров','Игры, фильтры и честные статусы сохранения, платформ и онлайн-сервисов.','play'],
 ['games','OSGARD PLAY — игровые миры','Игровой каталог OSGARD: выберите мир и изучите управление перед запуском.','play'],
 ['entertainment','OSGARD PLAY — игровые миры','Каталог миров OSGARD с фильтрами и локальной коллекцией.','play'],
 ['development','OSGARD Development — цифровые продукты и кейсы','PHANTOM, TEDES, MERAKKI и ESSENTIA. Стратегия, дизайн и разработка.','world'],
 ['play/partners','OSGARD PLAY — партнёрам','Брендированные миры и игровые интеграции. Обсудим подходящий формат до запуска.','world'],
 ['brand','OSGARD — фирменная система','Мастер-знак, продуктовые версии, favicon и правила движения.','world'],
 ['data','OSGARD — ваши данные','Резервная копия и восстановление прогресса, проектов и коллекции PLAY.','world'],
 ['quality','OSGARD — состояние локальной сборки','Фактические возможности, ограничения и локальный журнал действий.','world'],
 ...['vector-zero','time','swarm','inherit','remix','null-shift'].map(id=>['play/world/'+id,'OSGARD PLAY — '+id.toUpperCase(),'Управление, платформа и состояние игрового клиента '+id+'.','play']),
 ['academy','OSA — Академия','Практика, учебные маршруты и проекты OSA.','intelligence'],
 ['osa-cinema','OSA Original — интерактивный курс','Восемь сцен, выборы и самопроверка. Прогресс сохраняется в браузере.','intelligence'],
 ['portal','OSGARD — портал экосистемы','Сохранённый портал направлений OSGARD.','world'],
 ['learning','OSA — ваша карта знаний','Учебные маршруты, прогресс и история самопроверки.','intelligence'],
 ...['project','workspace','portfolio','program','experiments','assessment','pricing'].map(id=>['learning/'+id,'OSA — '+({project:'практический проект',workspace:'мастерская',portfolio:'локальное портфолио',program:'практическая программа',experiments:'журнал экспериментов',assessment:'самопроверка',pricing:'форматы обучения'})[id],'OSA Learning: обучение и практика. Возможности и ограничения указаны на странице.','intelligence']),
 ['lectures','OSA — каталог лекций','Восемь уроков с практикой, источниками и статусами медиа.','intelligence'],
 ...['intelligence-and-imitation','how-language-models-work','power-of-knowledge','signal-and-noise','verify-an-ai-answer','privacy-before-prompting','human-in-the-loop','investigate-the-future'].map((id,i)=>['lectures/'+id,'OSA — '+['Интеллект и имитация','Как работают языковые модели','Власть знаний','Сигнал и шум','Проверьте ответ ИИ','Приватность до запроса','Человек в контуре','Исследуйте будущее'][i],'Урок OSA: цели, практика, самопроверка и источники.','intelligence']),
]
const legacyRoutes=[['worlds','Миры'],['catalog','Каталог'],['chronicle','Хроника'],['masters','Мастера'],['club','Клуб'],['aurum','AURUM'],['timecoin','TimeCoin'],['miniapp','Mini App'],['week','Неделя'],['next','Рекомендации'],['archive','Архив'],['profile','Профиль'],['community','Сообщество'],['stream','Трансляции'],['marcosa','MARCOSA'],['media','Медиа'],['core-events','События'],['mobility','Мобильность'],['create','Создание'],['business','Бизнес'],['games/time','Империя времени'],['play/swarm','SWARM — прототип'],['play/null-shift','NULL//SHIFT — прототип'],['play/inherit','INHERIT — прототип'],['play/remix','REMIX — прототип']]
for(const [path,label]of legacyRoutes)if(!routes.some(r=>r[0]===path))routes.push([path,'OSGARD — '+label,'Сохранённый раздел OSGARD: '+label+'. Возможности и ограничения указаны на странице.',path.startsWith('play/')||path.startsWith('games/')?'play':'world'])
const esc=v=>v.replaceAll('&','&amp;').replaceAll('"','&quot;').replaceAll('<','&lt;')
for(const [path,title,description,theme] of routes){
 let html=template.replace(/<title>.*?<\/title>/,`<title>${esc(title)}</title>`)
 for(const [selector,value] of [['name="description"',description],['property="og:title"',title],['property="og:description"',description],['property="og:url"','https://osgard.world/'+path],['property="og:image"','https://osgard.world/brand/preview-'+theme+'.png'],['name="twitter:title"',title],['name="twitter:description"',description],['name="twitter:image"','https://osgard.world/brand/preview-'+theme+'.png']]){
  const regex=new RegExp(`(<meta ${selector} content=")[^"]*("[^>]*>)`);html=html.replace(regex,(_,a,b)=>a+esc(value)+b)
 }
 html=html.replace(/(<link rel="canonical" href=")[^"]+/,`$1https://osgard.world/${path==='games'||path==='entertainment'?'play':path}`)
 html=html.replace('<html lang="ru">',`<html lang="ru" data-product="${theme}">`)
 // Root Organization/WebSite graph stays valid; route-specific WebPage is added by the runtime.
 await mkdir('dist/'+path,{recursive:true});await writeFile('dist/'+path+'/index.html',html)
}
console.log('Brand route shells: '+routes.length+' titles, descriptions, canonicals and PNG previews')
