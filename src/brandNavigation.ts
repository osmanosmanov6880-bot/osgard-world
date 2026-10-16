export type BrandArea='world'|'intelligence'|'play'
export function globalNavigationState(path:string,theme:BrandArea,href:string):'page'|'location'|undefined{
 const current=path.replace(/\/+$/,'')||'/'
 if(current===href)return 'page'
 if(href==='/development'&&current.startsWith('/development/'))return 'location'
 if(href==='/'&&theme==='world'&&!current.startsWith('/development'))return 'location'
 if(href==='/intelligence'&&theme==='intelligence')return 'location'
 if(href==='/play'&&theme==='play')return 'location'
 return undefined
}
export function brandBreadcrumbs(path:string,theme:BrandArea):{label:string;href?:string}[]{
 const current=path.replace(/\/+$/,'')||'/'
 if(['/','/intelligence','/play','/entertainment','/games','/development'].includes(current))return []
 const labels:Record<string,string>={'/teams':'Команды','/deliveries':'Полученные материалы','/workspace/overview':'Рабочий центр','/account':'Аккаунт и доступ','/learning/organizer':'Организация пилота','/learning/campus':'Учебное пространство','/workspace':'Рабочее пространство','/learning':'Мой прогресс','/learning/program':'Практическая программа','/learning/project':'Редактор проекта','/learning/workspace':'Мастерская','/learning/portfolio':'Локальное портфолио','/learning/experiments':'Журнал экспериментов','/learning/assessment':'Самопроверка','/learning/pricing':'Форматы обучения','/lectures':'Лекции','/academy':'Академия','/osa-cinema':'OSA Original','/data':'Мои данные','/quality':'Состояние сборки','/brand':'Фирменная система','/play/partners':'Партнёрам'}
 const root=theme==='intelligence'?{label:'OSA Intelligence',href:'/intelligence'}:theme==='play'?{label:'OSGARD PLAY',href:'/play'}:{label:'OSGARD WORLD',href:'/'}
 const items=[{label:'OSGARD',href:'/'},...(theme==='world'?[]:[root])]
 if(current.startsWith('/lectures/'))items.push({label:'Лекции',href:'/lectures'})
 if(current.startsWith('/learning/'))items.push({label:'Мой прогресс',href:'/learning'})
 const name=labels[current]||(current.startsWith('/play/world/')?'Игровой мир':current.startsWith('/lectures/')?'Материал урока':'Раздел экосистемы')
 return [...items,{label:name}]
}
