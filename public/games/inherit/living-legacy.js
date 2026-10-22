/* INHERIT / THE LIVING LEGACY — progressive, save-safe presentation layer.
 * All game writes remain in the original INHERIT runtime. */
(() => {
  'use strict';
  const d = document;
  const $ = (selector, scope = d) => scope.querySelector(selector);
  const world = $('#world'), island = $('#island'), dock = $('.dock'), header = $('.app > header');
  if (!world || !island || !dock || !header || !window.InheritGame?.snapshot) return;

  const types = ['tree','stone','light','path','flower','arch','chime','moss','cairn','marker'];
  const names = {
    ru: {tree:'Дерево',stone:'Камень',light:'Фонарь',path:'Тропа',flower:'Цветы',arch:'Арка',chime:'Колокольчик',moss:'Мох',cairn:'Насыпь',marker:'Указатель'},
    en: {tree:'Tree',stone:'Stone',light:'Lantern',path:'Path',flower:'Flowers',arch:'Arch',chime:'Wind chime',moss:'Moss',cairn:'Cairn',marker:'Marker'},
    zh: {tree:'树木',stone:'石头',light:'灯笼',path:'小路',flower:'花朵',arch:'拱门',chime:'风铃',moss:'苔藓',cairn:'石堆',marker:'路标'}
  };
  const copy = {
    ru: {
      brand:'ОСТРОВ ЖИВОЙ ИСТОРИИ',headline:'Продолжи историю острова',
      hint:'Выбери предмет внизу и нажми на остров',nav:'Другие разделы',
      atlas:'Атлас',size:'А+ Текст',sizeDefault:'Обычный размер текста',
      sizeLarge:'Увеличенный размер текста',chapter:'ТВОЙ СЛЕД В ИСТОРИИ',
      steps:['Выбери предмет','Оставь след','Передай мир'],
      detail:['Нажми на карточку предмета','Нажми на остров, чтобы разместить','Используй золотую кнопку'],
      status:['Начни с предмета в нижней панели.','Покажи, где оставить выбранный предмет.','След сохранён в текущем ходе. Передай поколение, когда будешь готов.'],
      remaining:'Действий осталось',account:'Просмотр мира — редактирование зависит от прав',
      seeMore:'Атлас, история, настройки и дополнительные возможности',
      selection:'Выбрано',step:'ШАГ',of:'ИЗ',cancel:'Нажми Esc, чтобы закрыть меню'
    },
    en: {
      brand:'A LIVING ISLAND',headline:'Continue the island’s story',
      hint:'Choose an object below, then click the island',nav:'Explore',
      atlas:'Atlas',size:'A+ Text',sizeDefault:'Standard text size',
      sizeLarge:'Larger text',chapter:'YOUR TRACE IN HISTORY',
      steps:['Choose an object','Leave a trace','Pass the world'],
      detail:['Pick an object card below','Click the island to place it','Use the golden button'],
      status:['Start with an object in the toolbar.','Choose where to place your object.','Your trace is in this turn. Pass the generation when ready.'],
      remaining:'Actions remaining',account:'World viewer — editing depends on permissions',
      seeMore:'Atlas, history, settings and other features',
      selection:'Selected',step:'STEP',of:'OF',cancel:'Press Escape to close the menu'
    },
    zh: {
      brand:'生生不息的岛屿',headline:'延续这座岛屿的故事',
      hint:'先选择下方的物件，再点击岛屿',nav:'探索',
      atlas:'图鉴',size:'A+ 字体',sizeDefault:'标准字号',sizeLarge:'放大字体',
      chapter:'你留下的痕迹',steps:['选择物件','留下痕迹','传承世界'],
      detail:['点击下方的物件卡片','点击岛屿放置物件','使用金色按钮'],
      status:['先从下方选择一个物件。','在岛上选择放置位置。','痕迹已留在本回合。准备好后传承世代。'],
      remaining:'剩余操作',account:'世界预览：编辑权限由账号决定',
      seeMore:'图鉴、历史、设置和更多功能',selection:'已选择',
      step:'步骤',of:'共',cancel:'按 Escape 关闭菜单'
    }
  };
  const language = () => {
    const code = window.InheritUI?.getLanguage?.() || d.documentElement.lang?.slice(0,2) || 'ru';
    return copy[code] ? code : 'ru';
  };
  const L = () => copy[language()];
  const make = (tag, cls, value) => {
    const node=d.createElement(tag);
    if (cls) node.className=cls;
    if (value !== undefined) node.textContent=String(value);
    return node;
  };
  const icon = (name, cls='living-icon') => {
    const svg=d.createElementNS('http://www.w3.org/2000/svg','svg');
    svg.setAttribute('class',cls);
    svg.setAttribute('viewBox','0 0 120 140');
    svg.setAttribute('aria-hidden','true');
    svg.setAttribute('focusable','false');
    const use=d.createElementNS('http://www.w3.org/2000/svg','use');
    use.setAttribute('href','./living-legacy-sprites.svg#'+(types.includes(name)?name:'tree'));
    svg.append(use);
    return svg;
  };

  const params = new URLSearchParams(location.search);
  const account = () => params.get('mode')==='account' || !!window.InheritGame?.accountMode?.();
  const visibleGame = () => !account() && !d.body.classList.contains('replay-mode') &&
    !d.body.classList.contains('past') && $('#pass')?.getAttribute('aria-busy') !== 'true';
  const snapshot = () => {
    try { return window.InheritGame.snapshot(); }
    catch { return null; }
  };

  function init(){
    d.body.classList.add('living-legacy');
    let enlarged=false;
    try { enlarged=localStorage.getItem('inherit:living-text:v1')==='large'; } catch {}
    const sizeButton=make('button','living-font-toggle');
    sizeButton.type='button';
    header.append(sizeButton);
    function updateSize(){
      d.body.dataset.livingText=enlarged?'large':'default';
      sizeButton.textContent=L().size;
      sizeButton.setAttribute('aria-label',enlarged?L().sizeDefault:L().sizeLarge);
      sizeButton.setAttribute('aria-pressed',String(enlarged));
      sizeButton.title=sizeButton.getAttribute('aria-label');
    }
    sizeButton.addEventListener('click',()=>{
      enlarged=!enlarged;
      try { if(enlarged)localStorage.setItem('inherit:living-text:v1','large');
        else localStorage.removeItem('inherit:living-text:v1'); } catch {}
      updateSize();
    });

    const library=make('details','living-library');
    const summary=make('summary','living-library-toggle');
    summary.setAttribute('aria-label',L().seeMore);
    const menu=make('div','living-library-panel');
    menu.id='living-library-panel';
    library.append(summary,menu);
    header.append(library);
    // Preserve native buttons as visible, directly reachable controls. Moving
    // them into closed dropdowns made real game features inaccessible.
    // A slim, horizontally scrollable action rail keeps the island uncluttered.
    const actionRail=make('nav','living-actions-strip');
    actionRail.setAttribute('aria-label',L().seeMore);
    header.insertAdjacentElement('afterend',actionRail);
    const shortcuts=new Map();
    function organizeHeader(){
      for(const child of [...header.children]){
        if(child===library || child===sizeButton ||
          child.matches('.logo,.meta,.inherit-atlas-trigger'))continue;
        if(!child.matches('button,a'))continue;
        actionRail.append(child);
        const shortcut=make('button','living-shortcut',child.textContent.trim());
        shortcut.type='button';
        shortcut.addEventListener('click',()=>{
          library.open=false;
          child.click();
        });
        menu.append(shortcut);
        shortcuts.set(child,shortcut);
      }
    }
    organizeHeader();
    new MutationObserver(organizeHeader).observe(header,{childList:true});
    library.addEventListener('click',event=>{
      if(event.target.closest('.living-library-panel button, .living-library-panel a'))library.open=false;
    });
    d.addEventListener('click',event=>{
      if(library.open && !library.contains(event.target))library.open=false;
    });
    d.addEventListener('keydown',event=>{
      if(event.key==='Escape' && library.open){library.open=false;summary.focus();}
    });

    const journey=make('section','living-journey');
    journey.setAttribute('aria-label','Game steps');
    const left=make('div','living-journey-intro');
    const over=make('span','living-journey-overline');
    const title=make('strong','living-journey-title');
    left.append(over,title);
    const steps=make('div','living-journey-steps');
    const cards=Array.from({length:3},(_,i)=>{
      const card=make('div','living-step');
      const number=make('b','living-step-count',String(i+1));
      number.setAttribute('aria-hidden','true');
      const content=make('span','living-step-copy');
      const name=make('strong','living-step-name');
      const detail=make('small','living-step-detail');
      content.append(name,detail);card.append(number,content);
      steps.append(card);
      return {card,name,detail};
    });
    const progress=make('p','living-journey-status');
    progress.setAttribute('role','status');
    progress.setAttribute('aria-live','polite');
    journey.append(left,steps,progress);
    world.parentElement.insertBefore(journey,world);

    const hero=$('.world > .hero');
    const eyebrow=$('.eyebrow',hero||world);
    const hint=$('.world > .hint');
    const budgetSmall=$('.dock .turn small');
    const decor=make('div','living-island-decor');
    decor.setAttribute('aria-hidden','true');
    // Atmospheric scenery; not gameplay traces, not historical evidence.
    [
      ['tuft',18,50],['tuft',34,62],['tuft',73,46],['tuft',84,62],
      ['flower',22,42],['flower',65,24],['flower',75,65],
      ['rock',30,73],['rock',81,37],['grass',57,57],['grass',39,25]
    ].forEach(([kind,x,y])=>{
      const point=make('i','living-decor-'+kind);
      point.style.left=x+'%';point.style.top=y+'%';decor.append(point);
    });
    island.insertBefore(decor,$('#objects',island));

    const ghost=make('div','living-placement-preview');
    ghost.setAttribute('aria-hidden','true');
    ghost.append(icon('tree'));
    world.append(ghost);
    let chosen=false,previousGeneration=null,paintPending=false,step=1,chosenName='tree';
    const objects=$('#objects',island);

    function selectedName(){
      const element=$('.dock .tool.active');
      const code=element?.dataset.tool||element?.dataset.extra||'tree';
      return types.includes(code)?code:'tree';
    }
    function dressTools(){
      const list=[...dock.querySelectorAll('.tools .tool')];
      for(const tool of list){
        const kind=tool.dataset.tool||tool.dataset.extra;
        if(!types.includes(kind))continue;
        if(!tool.querySelector('.living-icon')){
          tool.replaceChildren(icon(kind),make('span','living-item-label'));
        }
        const label=$('.living-item-label',tool);
        if(label && label.textContent!==names[language()][kind])label.textContent=names[language()][kind];
        tool.setAttribute('aria-label',names[language()][kind]);
        tool.setAttribute('aria-pressed',String(tool.classList.contains('active')));
      }
      chosenName=selectedName();
    }
    function dressObjects(){
      if(!objects)return;
      let styled=0;
      for(const element of objects.children){
        if(styled>=560)break; // old sprites remain visible on extreme archives
        const kind=types.find(t=>element.classList.contains(t));
        if(!kind)continue;
        if(!element.hasAttribute('data-living-art')){
          element.append(icon(kind,'living-object-art'));
          element.dataset.livingArt='true';
        }
        element.setAttribute('title',names[language()][kind]);
        styled++;
      }
    }
    function sync(){
      const s=snapshot(),c=L();
      journey.hidden=account();
      if(previousGeneration!==null && s && previousGeneration!==s.generation)chosen=false;
      if(s && Number.isSafeInteger(s.generation))previousGeneration=s.generation;
      const pending=Array.isArray(s?.pending)?s.pending.length:0;
      const changes=Array.isArray(s?.changes)?s.changes.length:0;
      step = !visibleGame()?0:(pending>0||changes>0)?3:chosen?2:1;
      over.textContent=c.chapter;
      title.textContent=step?c.step+' '+step+' '+c.of+' 3':c.account;
      journey.setAttribute('aria-label',c.chapter);
      cards.forEach((entry,i)=>{
        entry.name.textContent=c.steps[i];
        entry.detail.textContent=c.detail[i];
        const current=step===i+1;
        entry.card.classList.toggle('is-current',current);
        if(current)entry.card.setAttribute('aria-current','step');
        else entry.card.removeAttribute('aria-current');
      });
      progress.textContent=step?c.status[step-1]:c.account;
      if(eyebrow)eyebrow.textContent=c.brand;
      // The original story headline is translated by InheritUI; do not overwrite it.
      if(hint)hint.textContent=c.hint;
      if(budgetSmall)budgetSmall.textContent=c.remaining;
      summary.textContent=c.nav;
      summary.setAttribute('aria-label',c.seeMore);
      actionRail.setAttribute('aria-label',c.seeMore);
      for(const [control,shortcut] of shortcuts){
        if(shortcut.textContent!==control.textContent.trim())shortcut.textContent=control.textContent.trim();
      }
      updateSize();
      dressTools();
      dressObjects();
    }
    function schedule(){
      if(paintPending)return;
      paintPending=true;
      queueMicrotask(()=>{paintPending=false;sync();});
    }

    // No synthetic placement: preview matches the original island boundary test.
    function preview(event){
      if(!visibleGame() || event.pointerType==='touch')return ghost.hidden=true;
      const element=event.target;
      if(!(element instanceof Element) || element.closest('button,a,[data-memory],.living-placement-preview'))return ghost.hidden=true;
      const area=island.getBoundingClientRect(),wr=world.getBoundingClientRect();
      if(!area.width||!area.height)return ghost.hidden=true;
      const x=(event.clientX-area.left)/area.width,y=(event.clientY-area.top)/area.height;
      const budget=Number($('#budget')?.textContent);
      if(x<.08||x>.91||y<.12||y>.77||!(budget>0))return ghost.hidden=true;
      ghost.hidden=false;
      ghost.style.left=event.clientX-wr.left+'px';
      ghost.style.top=event.clientY-wr.top+'px';
      const kind=selectedName();
      if(ghost.dataset.kind!==kind){
        ghost.replaceChildren(icon(kind));
        ghost.dataset.kind=kind;
      }
    }
    ghost.hidden=true;
    world.addEventListener('pointermove',preview,{passive:true});
    world.addEventListener('pointerleave',()=>{ghost.hidden=true;});
    world.addEventListener('click',()=>{ghost.hidden=true;schedule();},true);
    dock.addEventListener('click',event=>{
      const button=event.target.closest('button[data-tool],button[data-extra]');
      if(button){chosen=true;chosenName=selectedName();schedule();}
    });
    d.addEventListener('click',event=>{
      if(event.target.closest('[data-game-language]'))setTimeout(schedule,0);
    },true);
    if(objects)new MutationObserver(schedule).observe(objects,{childList:true});
    for(const id of ['#budget','#gen']){
      const target=$(id);
      if(target)new MutationObserver(schedule).observe(target,{childList:true,characterData:true,subtree:true});
    }
    const tools=$('.dock .tools');
    if(tools)new MutationObserver(schedule).observe(tools,{childList:true,subtree:true,characterData:true,attributes:true,attributeFilter:['class']});
    new MutationObserver(schedule).observe(d.documentElement,{attributes:true,attributeFilter:['lang']});
    const pass=$('#pass');
    if(pass)new MutationObserver(schedule).observe(pass,{attributes:true,attributeFilter:['aria-busy']});
    window.InheritLivingLegacy=Object.freeze({
      refresh:schedule,
      getCurrentStep:()=>step,
      getSelectedType:()=>selectedName(),
      getTextPreference:()=>enlarged?'large':'default'
    });
    sync();
  }
  if(d.readyState==='loading')d.addEventListener('DOMContentLoaded',init,{once:true});
  else init();
})();
