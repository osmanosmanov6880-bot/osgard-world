/** Single source of truth for the four portfolio case summaries.
 * Import directly from here on non-game routes to keep the 19-game catalog deferred. */
export const cases = [
 {id:'phantom',name:'PHANTOM',type:'Прототип',category:'Игровой клуб / операционный интерфейс',description:'Календарь, правила вместимости и сценарии управления бронированиями. Публичный кейс показывает интерфейс; работа сервера здесь не подтверждена.',href:'/development/phantom/',art:'/brand/cases/phantom-ui.jpg',visual:'screenshot'},
 {id:'tedes',name:'TEDES',type:'Демо',category:'Архитектура / предметный каталог',description:'Каталог дверей и материалов, подбор изделий и локальная проектная спецификация. Без оформления оплаченного заказа.',href:'/development/tedes/',art:'/brand/cases/tedes-ui.jpg',visual:'screenshot'},
 {id:'merakki',name:'MERAKKI',type:'Концепт',category:'Гастрономия / цифровой опыт',description:'Редакционная подача ресторанного бренда и сценарий знакомства с пространством. Коммерческий запуск не подтверждён.',href:'/development/merakki/',art:'/brand/cases/merakki-ui.jpg',visual:'screenshot'},
 {id:'essentia',name:'ESSENTIA',type:'Демо',category:'Commerce / витрина',description:'Каталог, избранное и локальная корзина. Приём платежей и реальных заказов не подключён.',href:'/development/essentia/',art:'/development/essentia/og.svg',visual:'preview'},
] as const
