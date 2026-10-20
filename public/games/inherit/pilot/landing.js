/* INHERIT public pilot invitation. No consent, analytics, cookies, beacons or fetches. */
(()=>{
'use strict';
const translations={
ru:{
eyebrow:'ОТКРЫТЫЙ ДОБРОВОЛЬНЫЙ ПИЛОТ · INHERIT',
title:'Оставь след. Помоги создать будущее игры.',
lead:'INHERIT — тихий мир, который меняется благодаря решениям игроков. Оставь предмет на острове, заверши поколение и расскажи, стоит ли возвращаться.',
cta:'Играть и участвовать добровольно ↗',play:'Играть без исследования',
footnote:'Бесплатно. Исследование выключено по умолчанию. Можно играть без согласия.',
howEyebrow:'КАК ЭТО РАБОТАЕТ',howTitle:'Три шага — один реальный мир.',
step1Title:'Оставь след',step1Text:'Выбери дерево, фонарь или другой предмет и размести его на острове. Это настоящий ход, а не демонстрация кнопки.',
step2Title:'Передай поколение',step2Text:'Заверши ход. История мира меняется только после реального подтверждения; локальный и аккаунтный режимы отличаются.',
step3Title:'Поделись мнением — по желанию',step3Text:'В разделе «Наследие → Исследование» можно включить локальный журнал, заполнить опрос и самостоятельно экспортировать файл.',
trustEyebrow:'ПРИВАТНОСТЬ — ОСНОВА',trustTitle:'Только с твоего согласия.',
trustText:'До согласия новые исследовательские данные не записываются. После него события хранятся на устройстве. Файл не отправляется автоматически: ты решаешь, экспортировать ли его и кому передать.',
trustDetail:'Экспорт содержит случайный код участника, даты и типы действий — это псевдонимные данные, а не гарантированная анонимность. Не включает имена, координаты предметов и текст сообщений. Удаление в браузере не удаляет уже переданные кому-либо копии.',
point1:'Нет платных функций и списаний в исследовании',point2:'Нет штрафов за пропущенные дни',
point3:'Результаты D1/D7 нельзя считать статистикой всех посетителей',
point4:'Исследование можно отключить и удалить с устройства',
scheduleEyebrow:'НЕ НУЖНО ИГРАТЬ КАЖДЫЙ ДЕНЬ',scheduleTitle:'План добровольного участия',
day0:'День 0',day0Text:'Поиграй, пройди первые действия и при желании включи исследование.',
day1:'День 1',day1Text:'Если захочется — вернись. Пропуск не приводит к наказанию.',
day7:'День 7',day7Text:'Вернись, если игра интересна. При согласии можно вручную экспортировать отчёт.',
lastTitle:'Будущее мира зависит от настоящих решений.',
lastText:'Можно просто играть. Можно помочь улучшить игру. Оба выбора одинаково уважаются.',
ctaBottom:'Начать добровольный пилот ↗',footerGame:'Вернуться к игре',footerNote:'Никаких придуманных результатов удержания или оплат.'
},
en:{
eyebrow:'OPEN VOLUNTARY PILOT · INHERIT',title:'Leave a trace. Help shape the future of the game.',
lead:'INHERIT is a quiet world shaped by player decisions. Place a trace on the island, pass the generation, and tell us if the world is worth returning to.',
cta:'Play and optionally participate ↗',play:'Play without research',
footnote:'Free to play. Research is off by default. Consent is not required to play.',
howEyebrow:'HOW IT WORKS',howTitle:'Three steps. One evolving world.',
step1Title:'Leave a trace',step1Text:'Choose a tree, lantern or other object and place it on the island. This is real gameplay, not a simulated action.',
step2Title:'Pass a generation',step2Text:'Finish your turn. The world history changes only after the appropriate confirmation; local and account modes differ.',
step3Title:'Share feedback — only if you wish',step3Text:'In Legacy → Research, you may enable a local journal, answer a short survey and manually export a file.',
trustEyebrow:'PRIVACY BY DESIGN',trustTitle:'Only with your consent.',
trustText:'No new research log is created before consent. Afterwards, research events stay on your device. Nothing is automatically sent: you decide whether to export a report or share it.',
trustDetail:'An export contains a random participant code, dates and action types. These are pseudonymous, not guaranteed anonymous data. No names, object coordinates or message text. Deleting local records does not recall copies you have already shared.',
point1:'No payments or paid advantage in this study',point2:'No penalties for missed days',
point3:'D1/D7 from volunteers do not represent all website visitors',
point4:'Research can be disabled and erased from your device',
scheduleEyebrow:'NO DAILY COMMITMENT',scheduleTitle:'A voluntary participation timeline',
day0:'Day 0',day0Text:'Play a little, try the first actions and optionally enable research.',
day1:'Day 1',day1Text:'Come back only if you want to. Missing a day has no penalty.',
day7:'Day 7',day7Text:'Return if you enjoy the world. You may manually export a report if you opted in.',
lastTitle:'The next world is shaped by real choices.',
lastText:'You can just play. You can help improve the game. Both choices are equally welcome.',
ctaBottom:'Start the voluntary pilot ↗',footerGame:'Back to the game',footerNote:'No fabricated retention metrics or purchases.'
},
zh:{
eyebrow:'INHERIT · 自愿研究体验',title:'留下痕迹，一起塑造游戏的未来。',
lead:'INHERIT 是一个因玩家决定而变化的宁静世界。在岛上留下物件，传承世代，再告诉我们你是否愿意回来。',
cta:'开始游戏，自愿参加 ↗',play:'不参加研究，直接游玩',
footnote:'游戏免费。研究默认关闭，无需同意也可以游玩。',
howEyebrow:'参与方式',howTitle:'三个步骤，一个不断变化的世界。',
step1Title:'留下痕迹',step1Text:'选择树木、灯笼或其他物件，将它放在岛上。这是真实游戏操作，不是假演示。',
step2Title:'传承世代',step2Text:'结束回合。世界历史只会在相应确认后变化；本地模式和账号模式不同。',
step3Title:'自愿分享想法',step3Text:'在「传承 → 研究」中，可以开启本地日志、填写问卷并手动导出文件。',
trustEyebrow:'隐私优先',trustTitle:'只在你同意后。',
trustText:'未经同意不会创建研究日志。同意后，研究事件留在你的设备上，不会自动发送。是否导出和分享完全由你决定。',
trustDetail:'导出的文件包含随机参与者代码、日期和操作类型，属于假名数据，并非完全匿名。不包含姓名、物件坐标或消息内容。从浏览器删除记录不会删除你已分享的副本。',
point1:'研究不涉及支付或付费优势',point2:'错过一天没有惩罚',point3:'志愿者的 D1/D7 不代表所有访客',point4:'可以随时关闭并删除本地研究记录',
scheduleEyebrow:'不需要每天登录',scheduleTitle:'自愿参与的时间线',
day0:'第 0 天',day0Text:'体验游戏和最初的几个操作，可选择开启研究。',
day1:'第 1 天',day1Text:'愿意的话再回来，错过一天不会受罚。',
day7:'第 7 天',day7Text:'如果喜欢游戏，可以再回来。已同意研究的玩家可手动导出报告。',
lastTitle:'真正的选择让世界不断延续。',
lastText:'可以单纯游玩，也可以帮助改进。两种选择都受到尊重。',
ctaBottom:'开始自愿体验 ↗',footerGame:'返回游戏',footerNote:'不会虚构留存数据或购买行为。'
}
};
const supported=new Set(Object.keys(translations)),buttons=[...document.querySelectorAll('[data-lang]')];
function pick(){
 const requested=new URLSearchParams(location.search).get('lang');
 const browser=(navigator.language||'').toLowerCase();
 return supported.has(requested)?requested:browser.startsWith('zh')?'zh':browser.startsWith('ru')?'ru':'en';
}
function setLanguage(l,save){
 const lang=supported.has(l)?l:'ru',dict=translations[lang];
 document.documentElement.lang=lang;
 for(const element of document.querySelectorAll('[data-i18n]')){
  const k=element.dataset.i18n;if(k in dict)element.textContent=dict[k];
 }
 for(const b of buttons)b.setAttribute('aria-pressed',String(b.dataset.lang===lang));
 const url='/games/inherit/?lang='+lang;
 document.querySelector('#join').href=url+'&pilot=1';
 document.querySelector('#join-bottom').href=url+'&pilot=1';
 document.querySelector('#game').href=url;
 document.title='INHERIT — '+(lang==='en'?'Voluntary pilot':lang==='zh'?'自愿体验':'Добровольный пилот');
 if(save)try{const next=new URL(location.href);next.searchParams.set('lang',lang);history.replaceState(null,'',next)}catch{}
}
for(const b of buttons)b.addEventListener('click',()=>setLanguage(b.dataset.lang,true));
setLanguage(pick(),false);
})();


// Scope the optional offline worker to INHERIT only; research files are not cached.
if('serviceWorker' in navigator){
 window.addEventListener('load',()=>{
   navigator.serviceWorker.register('/games/inherit/sw.js',{scope:'/games/inherit/'}).catch(()=>{});
 },{once:true});
}
